import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1.0.13";
import {
  constantTimeEquals,
  decodeSecret,
  sign,
  verifyWebhook,
} from "./webhook_signature.ts";

// Known vector, computed independently with Node's crypto (HMAC-SHA256 over
// `${id}.${timestamp}.${body}`, keyed with the base64 part of the secret).
const SECRET = "v1,whsec_d3VzZWx3YWxsLWhvb2stdGVzdC1rZXktMDEyMzQ1Njc4OQ==";
const ID = "msg_2KWPBgLlAfxdpx2AI54pPJ85f4W";
const TS = "1767225600";
const BODY =
  '{"user":{"email":"anna@example.com"},"email_data":{"token":"123456","email_action_type":"magiclink"}}';
const SIG = "v1,V6r43WSLl2ccrOprveC2/Cq5H8evNM42mkQY1PnbXeo=";

const base = {
  secret: SECRET,
  id: ID,
  timestamp: TS,
  signature: SIG,
  body: BODY,
  now: Number(TS),
};

Deno.test("accepts the known vector", async () => {
  assertEquals(await verifyWebhook(base), { ok: true });
});

Deno.test("accepts when one of several space-separated signatures matches", async () => {
  const sig = `v1,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= ${SIG}`;
  assertEquals(await verifyWebhook({ ...base, signature: sig }), { ok: true });
});

Deno.test("refuses a changed body", async () => {
  assertEquals(
    await verifyWebhook({ ...base, body: BODY.replace("123456", "654321") }),
    { ok: false, reason: "bad_signature" },
  );
});

Deno.test("refuses a changed id or timestamp", async () => {
  assertEquals((await verifyWebhook({ ...base, id: "msg_other" })).ok, false);
  assertEquals(
    (await verifyWebhook({ ...base, timestamp: String(Number(TS) + 1) })).ok,
    false,
  );
});

Deno.test("refuses a signature from another secret", async () => {
  const other = "v1,whsec_" + btoa("a-different-key-entirely-here!!");
  assertEquals(
    await verifyWebhook({ ...base, secret: other }),
    { ok: false, reason: "bad_signature" },
  );
});

Deno.test("refuses a signature without the v1 version", async () => {
  const bare = SIG.slice("v1,".length);
  assertEquals((await verifyWebhook({ ...base, signature: bare })).ok, false);
  assertEquals(
    (await verifyWebhook({ ...base, signature: "v2," + SIG.slice(3) })).ok,
    false,
  );
});

Deno.test("refuses timestamps more than five minutes away, in either direction", async () => {
  const late = Number(TS) + 301;
  const early = Number(TS) - 301;
  assertEquals(
    await verifyWebhook({ ...base, now: late }),
    { ok: false, reason: "timestamp_out_of_tolerance" },
  );
  assertEquals(
    await verifyWebhook({ ...base, now: early }),
    { ok: false, reason: "timestamp_out_of_tolerance" },
  );
});

Deno.test("accepts a timestamp exactly at the five-minute edge", async () => {
  assertEquals(
    (await verifyWebhook({ ...base, now: Number(TS) + 300 })).ok,
    true,
  );
});

Deno.test("refuses missing headers and a non-numeric timestamp", async () => {
  assertEquals((await verifyWebhook({ ...base, id: null })).ok, false);
  assertEquals((await verifyWebhook({ ...base, timestamp: null })).ok, false);
  assertEquals((await verifyWebhook({ ...base, signature: null })).ok, false);
  assertEquals(
    await verifyWebhook({ ...base, timestamp: "12.5" }),
    { ok: false, reason: "bad_timestamp" },
  );
});

Deno.test("a malformed secret throws, so the caller reports an operator error", async () => {
  assertThrows(() => decodeSecret("whsec_AAAA"), Error, "v1,whsec_");
  assertThrows(() => decodeSecret("v1,whsec_!!!not-base64"), Error, "base64");
  assertThrows(() => decodeSecret("v1,whsec_"), Error, "empty");
});

Deno.test("sign produces the vector's signature", async () => {
  const key = decodeSecret(SECRET);
  assertEquals(await sign(key, ID, TS, BODY), SIG.slice("v1,".length));
});

Deno.test("constantTimeEquals compares whole strings and differing lengths", () => {
  assert(constantTimeEquals("abc", "abc"));
  assert(!constantTimeEquals("abc", "abd"));
  assert(!constantTimeEquals("abc", "abcd"));
  assert(!constantTimeEquals("", "a"));
});
