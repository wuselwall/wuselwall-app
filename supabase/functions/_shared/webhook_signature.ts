// Verifies the Standard Webhooks signature that Supabase Auth puts on its hook requests
// (the Send Email Hook, specs/10 §4). Supabase signs `${webhook-id}.${webhook-timestamp}.${body}`
// with HMAC-SHA256, keyed with the base64 part of the secret `v1,whsec_<base64>`, and sends
// the result as `webhook-signature: v1,<base64>` (several space-separated entries are allowed
// during key rotation). WebCrypto only, so no dependency.
//
// Replay: a request whose timestamp is more than five minutes away from now is refused. A
// captured request can be replayed within that window; the code it carries is valid for
// ten minutes anyway, so a replay mails the same code to the same address and nothing more.

export const TOLERANCE_SECONDS = 300;

const SECRET_PREFIX = "v1,whsec_";

export type VerifyResult =
  | { ok: true }
  | {
    ok: false;
    reason:
      | "missing_headers"
      | "bad_timestamp"
      | "timestamp_out_of_tolerance"
      | "bad_signature";
  };

/**
 * The HMAC key from `v1,whsec_<base64>`. Throws when the secret is not in that form: a
 * malformed secret is an operator error, not a request error, so the caller reports it as one.
 */
export function decodeSecret(secret: string): Uint8Array<ArrayBuffer> {
  if (!secret.startsWith(SECRET_PREFIX)) {
    throw new Error("the send-email hook secret must start with v1,whsec_");
  }
  const b64 = secret.slice(SECRET_PREFIX.length);
  let raw: string;
  try {
    raw = atob(b64);
  } catch {
    throw new Error(
      "the send-email hook secret is not valid base64 after v1,whsec_",
    );
  }
  const bytes = new Uint8Array(new ArrayBuffer(raw.length));
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  if (bytes.length === 0) {
    throw new Error("the send-email hook secret is empty");
  }
  return bytes;
}

function toBase64(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

/** Compares two strings without returning early at the first difference. */
export function constantTimeEquals(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  const n = Math.max(x.length, y.length);
  let diff = x.length ^ y.length;
  for (let i = 0; i < n; i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

/** The base64 HMAC-SHA256 of the signed content, keyed with the decoded secret. */
export async function sign(
  key: Uint8Array<ArrayBuffer>,
  id: string,
  timestamp: string,
  body: string,
): Promise<string> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    new TextEncoder().encode(`${id}.${timestamp}.${body}`),
  );
  return toBase64(new Uint8Array(mac));
}

/**
 * Checks the three Standard Webhooks headers against the raw request body.
 * `now` is in seconds since the epoch and exists so tests can pin the clock.
 */
export async function verifyWebhook(input: {
  secret: string;
  id: string | null;
  timestamp: string | null;
  signature: string | null;
  body: string;
  now?: number;
}): Promise<VerifyResult> {
  const { id, timestamp, signature, body } = input;
  if (!id || !timestamp || !signature) {
    return { ok: false, reason: "missing_headers" };
  }
  if (!/^\d+$/.test(timestamp)) return { ok: false, reason: "bad_timestamp" };

  const now = input.now ?? Math.floor(Date.now() / 1000);
  if (Math.abs(now - Number(timestamp)) > TOLERANCE_SECONDS) {
    return { ok: false, reason: "timestamp_out_of_tolerance" };
  }

  const key = decodeSecret(input.secret);
  const expected = await sign(key, id, timestamp, body);

  // Every entry is checked, and the match is accumulated rather than returned early.
  let matched = false;
  for (const entry of signature.split(" ")) {
    const comma = entry.indexOf(",");
    if (comma < 0) continue;
    const version = entry.slice(0, comma);
    const candidate = entry.slice(comma + 1);
    if (version === "v1" && constantTimeEquals(candidate, expected)) {
      matched = true;
    }
  }
  return matched ? { ok: true } : { ok: false, reason: "bad_signature" };
}
