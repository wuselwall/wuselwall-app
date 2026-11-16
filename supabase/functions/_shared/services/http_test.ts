import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import {
  coord,
  fetchBytes,
  fetchJson,
  guardedFetch,
  MAX_BODY_BYTES,
  query,
  statusCode,
  toBase64,
  USER_AGENT,
} from "./http.ts";
import { ProviderError, type ProviderContext } from "./types.ts";

const PROVIDER = { hosts: ["api.example.org"] };

function recorder(response: () => Response = () => new Response("{}")) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fake = ((input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(input), init: init ?? {} });
    return Promise.resolve(response());
  }) as typeof fetch;
  return { fake, calls };
}

async function codeOf(p: Promise<unknown>): Promise<string> {
  try {
    await p;
  } catch (err) {
    if (err instanceof ProviderError) return err.code;
    throw err;
  }
  throw new Error("expected a ProviderError");
}

const ctxOf = (fetch: typeof globalThis.fetch, key: string | null = null): ProviderContext => ({
  key,
  fetch,
  signal: new AbortController().signal,
});

Deno.test("guardedFetch: a host that is not declared is refused and nothing is sent", async () => {
  const { fake, calls } = recorder();
  const f = guardedFetch(PROVIDER, fake);
  for (
    const url of [
      "https://evil.example.net/x",
      "https://api.example.org.evil.net/x",
      "https://sub.api.example.org/x",
      "http://api.example.org/x", // not https
      "https://user:pw@api.example.org/x", // credentials in the URL
      "https://api.example.org:8443/x", // another port
      "ftp://api.example.org/x",
      "not a url",
    ]
  ) {
    assertEquals(await codeOf(f(url)), "forbidden_host", url);
  }
  assertEquals(calls.length, 0);
});

Deno.test("guardedFetch: a declared host is reached with no redirects, no credentials and our User-Agent", async () => {
  const { fake, calls } = recorder();
  const f = guardedFetch(PROVIDER, fake);
  await f("https://API.example.org/v1?x=1", { headers: { Cookie: "a=b", "X-Test": "1" } });
  assertEquals(calls.length, 1);
  const { url, init } = calls[0];
  assertEquals(url, "https://api.example.org/v1?x=1");
  assertEquals(init.redirect, "error");
  assertEquals(init.credentials, "omit");
  const headers = new Headers(init.headers);
  assertEquals(headers.get("user-agent"), USER_AGENT);
  assertEquals(headers.get("cookie"), null);
  assertEquals(headers.get("x-test"), "1");
});

Deno.test("guardedFetch: a provider may set its own User-Agent header", async () => {
  const { fake, calls } = recorder();
  await guardedFetch(PROVIDER, fake)("https://api.example.org/", { headers: { "User-Agent": "x/1" } });
  assertEquals(new Headers(calls[0].init.headers).get("user-agent"), "x/1");
});

Deno.test("guardedFetch: a redirect is an error, whatever the transport says, and the URL is not in it", async () => {
  const f = guardedFetch(
    PROVIDER,
    (() => Promise.reject(new TypeError("redirect from https://api.example.org/?appid=SECRET to elsewhere"))) as typeof fetch,
  );
  try {
    await f("https://api.example.org/?appid=SECRET");
  } catch (err) {
    assert(err instanceof ProviderError);
    assertEquals(err.code, "unreachable");
    assertEquals((String(err) + (err.stack ?? "")).includes("SECRET"), false);
    return;
  }
  throw new Error("expected an error");
});

Deno.test("guardedFetch: an aborted call is a timeout", async () => {
  const abortFetch = (() => Promise.reject(new DOMException("aborted", "AbortError"))) as typeof fetch;
  assertEquals(await codeOf(guardedFetch(PROVIDER, abortFetch)("https://api.example.org/")), "timeout");
});

Deno.test("guardedFetch: a body over the cap is refused, declared or not", async () => {
  const big = new Uint8Array(1000);
  const declared = guardedFetch(PROVIDER, recorder(() => new Response(big, { headers: { "content-length": "1000" } })).fake, 500);
  assertEquals(await codeOf(declared("https://api.example.org/")), "too_large");

  // No content-length: the stream is counted.
  const stream = () =>
    new Response(
      new ReadableStream({
        start(c) {
          c.enqueue(new Uint8Array(400));
          c.enqueue(new Uint8Array(400));
          c.close();
        },
      }),
    );
  assertEquals(await codeOf(guardedFetch(PROVIDER, recorder(stream).fake, 500)("https://api.example.org/")), "too_large");

  const ok = await guardedFetch(PROVIDER, recorder(() => new Response("ok")).fake, 500)("https://api.example.org/");
  assertEquals(await ok.text(), "ok");
});

Deno.test("guardedFetch: the default cap is 2 MB", () => {
  assertEquals(MAX_BODY_BYTES, 2 * 1024 * 1024);
});

Deno.test("guardedFetch: bodiless statuses come through", async () => {
  const f = guardedFetch(PROVIDER, recorder(() => new Response(null, { status: 204 })).fake);
  assertEquals((await f("https://api.example.org/")).status, 204);
});

Deno.test("statusCode: keys, quota, no data, anything else", () => {
  assertEquals(statusCode(200), null);
  assertEquals(statusCode(401, { keyed: true }), "unauthorized");
  assertEquals(statusCode(403, { keyed: true }), "unauthorized");
  assertEquals(statusCode(401), "http_401");
  assertEquals(statusCode(429), "quota");
  assertEquals(statusCode(404, { noData: [404] }), "no_data");
  assertEquals(statusCode(404), "http_404");
  assertEquals(statusCode(500, { keyed: true }), "http_500");
});

Deno.test("fetchJson: parses, maps statuses and refuses a body that is not JSON", async () => {
  const answer = (body: string, status = 200) => ctxOf(recorder(() => new Response(body, { status })).fake);
  assertEquals(await fetchJson(answer('{"a":1}'), "https://x/"), { a: 1 });
  assertEquals(await codeOf(fetchJson(answer("nope"), "https://x/")), "bad_answer");
  assertEquals(await codeOf(fetchJson(answer("{}", 429), "https://x/")), "quota");
  assertEquals(await codeOf(fetchJson(answer("{}", 401), "https://x/", {}, { keyed: true })), "unauthorized");
  assertEquals(await codeOf(fetchJson(answer("{}", 502), "https://x/")), "http_502");
});

Deno.test("fetchBytes: the bytes and the content type", async () => {
  const ctx = ctxOf(recorder(() => new Response(new Uint8Array([1, 2, 3]), { headers: { "content-type": "image/png" } })).fake);
  const out = await fetchBytes(ctx, "https://x/");
  assertEquals([...out.bytes], [1, 2, 3]);
  assertEquals(out.contentType, "image/png");
});

Deno.test("toBase64: large input, no stack overflow, round trip", () => {
  const bytes = new Uint8Array(300_000).map((_, i) => i % 251);
  const back = Uint8Array.from(atob(toBase64(bytes)), (c) => c.charCodeAt(0));
  assertEquals(back.length, bytes.length);
  assertEquals(back[299_999], bytes[299_999]);
});

Deno.test("coord and query: four decimals at most, nothing hand-escaped", () => {
  assertEquals(coord(39.571234), "39.5712");
  assertEquals(coord(-2.6), "-2.6");
  assertEquals(query({ q: "São Paulo & co", n: 5 }), "q=S%C3%A3o+Paulo+%26+co&n=5");
});
