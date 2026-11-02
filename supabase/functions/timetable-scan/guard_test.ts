import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1.0.13";
import { RequestError } from "../_shared/client.ts";
import { claimRefusal, MAX_BODY_BYTES, readBoundedBody } from "./guard.ts";

function post(
  body: BodyInit | null,
  headers: Record<string, string> = {},
): Request {
  return new Request("http://localhost/timetable-scan", {
    method: "POST",
    body,
    headers,
  });
}

Deno.test("readBoundedBody: a small JSON object is read", async () => {
  const body = await readBoundedBody(
    post(JSON.stringify({ image: "abc", mime: "image/png" })),
  );
  assertEquals(body.image, "abc");
  assertEquals(body.mime, "image/png");
});

Deno.test("readBoundedBody: a declared length above the limit is refused before reading", async () => {
  const err = await assertRejects(
    () =>
      readBoundedBody(
        post("{}", { "content-length": String(MAX_BODY_BYTES + 1) }),
        MAX_BODY_BYTES,
      ),
    RequestError,
  );
  assertEquals(err.status, 413);
  assertEquals(err.code, "image_too_large");
});

Deno.test("readBoundedBody: a streamed body stops at the limit instead of being buffered", async () => {
  // Chunks without a Content-Length, as a chunked upload arrives; the limit is hit in the third.
  let pulled = 0;
  const stream = new ReadableStream<Uint8Array>({
    pull(controller) {
      pulled++;
      if (pulled > 100) {
        controller.close();
        return;
      }
      controller.enqueue(new Uint8Array(1000).fill(0x20));
    },
  });
  const err = await assertRejects(
    () => readBoundedBody(post(stream), 2500),
    RequestError,
  );
  assertEquals(err.status, 413);
  assert(pulled <= 4, `the body was read beyond the limit: ${pulled} chunks`);
});

Deno.test("readBoundedBody: not JSON, and not an object, are 400", async () => {
  const notJson = await assertRejects(
    () => readBoundedBody(post("nope")),
    RequestError,
  );
  assertEquals(notJson.status, 400);
  assertEquals(notJson.code, "body_invalid");
  const list = await assertRejects(
    () => readBoundedBody(post("[1]")),
    RequestError,
  );
  assertEquals(list.status, 400);
  const none = await assertRejects(
    () => readBoundedBody(post(null)),
    RequestError,
  );
  assertEquals(none.status, 400);
});

Deno.test("claimRefusal: an allowed claim lets the scan through", () => {
  assertEquals(claimRefusal({ ok: true }), null);
});

Deno.test("claimRefusal: the per-account limit is a 429 with its own code", () => {
  const err = claimRefusal({ ok: false, reason: "rate_limited" });
  assert(err instanceof RequestError);
  assertEquals(err.status, 429);
  assertEquals(err.code, "scan_rate_limited");
  assertEquals(err.hint, "scan_rate_limited");
});

Deno.test("claimRefusal: anything else is refused, never let through", () => {
  for (
    const answer of [
      null,
      undefined,
      {},
      { ok: "true" },
      { ok: false },
      "ok",
      1,
    ]
  ) {
    const err = claimRefusal(answer);
    assert(
      err instanceof RequestError,
      `answer ${JSON.stringify(answer)} must be refused`,
    );
    assertEquals(err.status, 403);
  }
});
