import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.13";
import { crc32, type ZipEntry, zipChunks } from "./zip.ts";

const encoder = new TextEncoder();
const decoder = new TextDecoder();

async function* chunks(...parts: string[]): AsyncGenerator<Uint8Array> {
  for (const part of parts) yield encoder.encode(part);
}

async function* list(...entries: ZipEntry[]): AsyncGenerator<ZipEntry> {
  yield* entries;
}

async function bytesOf(stream: AsyncIterable<Uint8Array>): Promise<Uint8Array> {
  const parts: Uint8Array[] = [];
  for await (const part of stream) parts.push(part);
  const all = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const part of parts) {
    all.set(part, at);
    at += part.length;
  }
  return all;
}

async function inflate(data: Uint8Array): Promise<Uint8Array> {
  const stream = ReadableStream.from([data]).pipeThrough(
    new DecompressionStream("deflate-raw") as unknown as TransformStream<Uint8Array, Uint8Array>,
  );
  return await bytesOf(stream);
}

type Read = { name: string; text: string; crc: number; flags: number; date: number };

/** Reads an archive the way unzip does: from the end, through the central directory. */
async function unzip(zip: Uint8Array): Promise<Read[]> {
  const view = new DataView(zip.buffer, zip.byteOffset, zip.byteLength);
  const end = zip.length - 22;
  assertEquals(view.getUint32(end, true), 0x06054b50, "end of central directory");
  const count = view.getUint16(end + 10, true);
  let at = view.getUint32(end + 16, true);
  assertEquals(at + view.getUint32(end + 12, true), end, "the directory ends where the end record starts");
  const files: Read[] = [];
  for (let i = 0; i < count; i++) {
    assertEquals(view.getUint32(at, true), 0x02014b50, "central header");
    const flags = view.getUint16(at + 8, true);
    const date = view.getUint16(at + 14, true);
    const crc = view.getUint32(at + 16, true);
    const compressed = view.getUint32(at + 20, true);
    const size = view.getUint32(at + 24, true);
    const nameLength = view.getUint16(at + 28, true);
    const local = view.getUint32(at + 42, true);
    const name = decoder.decode(zip.subarray(at + 46, at + 46 + nameLength));
    assertEquals(view.getUint32(local, true), 0x04034b50, `local header of ${name}`);
    const start = local + 30 + view.getUint16(local + 26, true) + view.getUint16(local + 28, true);
    const data = await inflate(zip.subarray(start, start + compressed));
    assertEquals(data.length, size, `size of ${name}`);
    assertEquals(crc32(data), crc, `CRC of ${name}`);
    const descriptor = start + compressed;
    assertEquals(view.getUint32(descriptor, true), 0x08074b50, `data descriptor of ${name}`);
    assertEquals(view.getUint32(descriptor + 4, true), crc, `descriptor CRC of ${name}`);
    files.push({ name, text: decoder.decode(data), crc, flags, date });
    at += 46 + nameLength;
  }
  return files;
}

Deno.test("crc32 matches the standard check value", () => {
  assertEquals(crc32(encoder.encode("123456789")), 0xcbf43926);
  assertEquals(crc32(encoder.encode("6789"), crc32(encoder.encode("12345"))), 0xcbf43926);
  assertEquals(crc32(new Uint8Array()), 0);
});

Deno.test("an archive holds every entry with its bytes, in order", async () => {
  const zip = await bytesOf(zipChunks(
    list(
      { name: "tables/profile.json", data: chunks("[\n", '{"a":1}', "\n]\n") },
      { name: "tables/empty.json", data: chunks() },
      { name: "Grüße.txt", data: chunks("Hallo ", "Welt") },
    ),
    new Date("2026-10-19T08:30:00Z"),
  ));
  const files = await unzip(zip);
  assertEquals(files.map((f) => [f.name, f.text]), [
    ["tables/profile.json", '[\n{"a":1}\n]\n'],
    ["tables/empty.json", ""],
    ["Grüße.txt", "Hallo Welt"],
  ]);
  assertEquals(files[0].flags & 0x0800, 0x0800, "names are marked UTF-8");
  assertEquals(files[0].date, ((2026 - 1980) << 9) | (10 << 5) | 19);
});

Deno.test("a large entry streams through and compresses", async () => {
  const row = JSON.stringify({ id: 1, title: "Elternabend", note: "x".repeat(200) });
  async function* rows(): AsyncGenerator<Uint8Array> {
    for (let i = 0; i < 2000; i++) yield encoder.encode(row + "\n");
  }
  const zip = await bytesOf(zipChunks(
    list({ name: "big.json", data: rows() }),
    new Date("2026-10-19T00:00:00Z"),
  ));
  const [file] = await unzip(zip);
  assertEquals(file.text.length, (row.length + 1) * 2000);
  assertEquals(zip.length < file.text.length / 10, true, "repetitive rows deflate well");
});

Deno.test("an archive with no entries is still a valid zip", async () => {
  const zip = await bytesOf(zipChunks(list(), new Date()));
  assertEquals(zip.length, 22);
  assertEquals(await unzip(zip), []);
});

Deno.test("a failing entry fails the stream instead of ending it as a whole zip", async () => {
  async function* broken(): AsyncGenerator<Uint8Array> {
    yield encoder.encode("[");
    throw new Error("page failed");
  }
  await assertRejects(
    () => bytesOf(zipChunks(list({ name: "a.json", data: broken() }), new Date())),
    Error,
    "page failed",
  );
});
