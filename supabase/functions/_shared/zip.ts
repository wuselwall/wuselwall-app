// A zip file written as a stream (PKWARE APPNOTE 6.3): each entry is deflated as its bytes
// arrive, and its CRC and sizes follow the data in a data descriptor, so nothing is held in
// memory but the central directory. The deflating is the runtime's CompressionStream.
// No Zip64: an entry or an archive beyond 4 GiB is refused rather than written wrong.

/** One file in the archive: its path and its bytes, read once, in order. */
export type ZipEntry = { name: string; data: AsyncIterable<Uint8Array> };

const LIMIT = 0xffffffff;
// Bit 3: sizes and CRC follow the data; bit 11: the name is UTF-8.
const FLAGS = 0x0808;
const DEFLATE = 8;
const VERSION = 20;

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

/** The CRC-32 of [data], continuing from [crc] (the CRC of the bytes before it). */
export function crc32(data: Uint8Array, crc = 0): number {
  let c = ~crc;
  for (let i = 0; i < data.length; i++) {
    c = CRC_TABLE[(c ^ data[i]) & 0xff] ^ (c >>> 8);
  }
  return ~c >>> 0;
}

/** MS-DOS date and time of [when], in UTC (zip has no time zone). */
function dosDateTime(when: Date): { date: number; time: number } {
  const year = Math.max(when.getUTCFullYear(), 1980);
  return {
    date: ((year - 1980) << 9) | ((when.getUTCMonth() + 1) << 5) | when.getUTCDate(),
    time: (when.getUTCHours() << 11) | (when.getUTCMinutes() << 5) | (when.getUTCSeconds() >> 1),
  };
}

function record(size: number, fill: (view: DataView) => void): Uint8Array {
  const bytes = new Uint8Array(size);
  fill(new DataView(bytes.buffer));
  return bytes;
}

/**
 * The archive of [entries], chunk by chunk; an entry's data is read only when its turn comes.
 * [modified] stamps every entry.
 */
export async function* zipChunks(
  entries: AsyncIterable<ZipEntry>,
  modified: Date,
): AsyncGenerator<Uint8Array> {
  const { date, time } = dosDateTime(modified);
  const encoder = new TextEncoder();
  const central: Uint8Array[] = [];
  let offset = 0;

  for await (const entry of entries) {
    const name = encoder.encode(entry.name);
    const local = record(30 + name.length, (v) => {
      v.setUint32(0, 0x04034b50, true);
      v.setUint16(4, VERSION, true);
      v.setUint16(6, FLAGS, true);
      v.setUint16(8, DEFLATE, true);
      v.setUint16(10, time, true);
      v.setUint16(12, date, true);
      // CRC and sizes (14–25) stay zero: the data descriptor carries them.
      v.setUint16(26, name.length, true);
    });
    local.set(name, 30);
    yield local;

    let crc = 0;
    let size = 0;
    let compressed = 0;
    const input = ReadableStream.from((async function* () {
      for await (const chunk of entry.data) {
        crc = crc32(chunk, crc);
        size += chunk.length;
        yield chunk;
      }
    })());
    const deflated = input.pipeThrough(
      new CompressionStream("deflate-raw") as unknown as TransformStream<Uint8Array, Uint8Array>,
    );
    for await (const chunk of deflated) {
      compressed += chunk.length;
      yield chunk;
    }
    if (size > LIMIT || compressed > LIMIT || offset > LIMIT) {
      throw new Error(`zip entry ${entry.name} is beyond 4 GiB`);
    }

    yield record(16, (v) => {
      v.setUint32(0, 0x08074b50, true);
      v.setUint32(4, crc, true);
      v.setUint32(8, compressed, true);
      v.setUint32(12, size, true);
    });

    const header = record(46 + name.length, (v) => {
      v.setUint32(0, 0x02014b50, true);
      v.setUint16(4, VERSION, true);
      v.setUint16(6, VERSION, true);
      v.setUint16(8, FLAGS, true);
      v.setUint16(10, DEFLATE, true);
      v.setUint16(12, time, true);
      v.setUint16(14, date, true);
      v.setUint32(16, crc, true);
      v.setUint32(20, compressed, true);
      v.setUint32(24, size, true);
      v.setUint16(28, name.length, true);
      v.setUint32(42, offset, true);
    });
    header.set(name, 46);
    central.push(header);
    offset += local.length + compressed + 16;
  }

  if (offset > LIMIT || central.length > 0xffff) {
    throw new Error("zip archive is beyond 4 GiB or 65535 entries");
  }
  let directory = 0;
  for (const header of central) {
    directory += header.length;
    yield header;
  }
  yield record(22, (v) => {
    v.setUint32(0, 0x06054b50, true);
    v.setUint16(8, central.length, true);
    v.setUint16(10, central.length, true);
    v.setUint32(12, directory, true);
    v.setUint32(16, offset, true);
  });
}
