import { assert, assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1.0.13";
import {
  APPLE_REVOKE_URL,
  appleClientSecret,
  appleConfig,
  AppleError,
  decryptToken,
  encryptToken,
  pemToDer,
  revokeRefreshToken,
} from "./apple.ts";

/** A fresh P-256 key pair, the private half as PKCS#8 PEM (like an Apple .p8 file). */
async function keyPair() {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let b64 = "";
  for (const b of pkcs8) b64 += String.fromCharCode(b);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(b64).match(/.{1,64}/g)!.join("\n")}\n-----END PRIVATE KEY-----\n`;
  return { pem, publicKey: pair.publicKey };
}

function b64urlDecode(s: string): Uint8Array<ArrayBuffer> {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(s.length / 4) * 4, "=");
  return new Uint8Array(Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)).buffer);
}

const KEY_B64 = btoa(String.fromCharCode(...new Uint8Array(32).map((_, i) => i + 1)));

type Call = { url: string; init: RequestInit };

function fakeFetch(status: number, body: unknown) {
  const calls: Call[] = [];
  const fn = (async (input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(input), init: init ?? {} });
    return new Response(typeof body === "string" ? body : JSON.stringify(body), { status });
  }) as typeof fetch;
  return { fn, calls };
}

Deno.test("client secret: ES256 header, claims and a signature that verifies", async () => {
  const { pem, publicKey } = await keyPair();
  const now = new Date("2026-10-15T10:00:00Z");
  const jwt = await appleClientSecret({
    teamId: "TEAM123456",
    keyId: "KEY1234567",
    privateKeyPem: pem,
    clientId: "ch.goomba.wuselwall",
  }, now);

  const [h, c, s] = jwt.split(".");
  const header = JSON.parse(new TextDecoder().decode(b64urlDecode(h)));
  const claims = JSON.parse(new TextDecoder().decode(b64urlDecode(c)));
  assertEquals(header, { alg: "ES256", kid: "KEY1234567", typ: "JWT" });
  assertEquals(claims.iss, "TEAM123456");
  assertEquals(claims.sub, "ch.goomba.wuselwall");
  assertEquals(claims.aud, "https://appleid.apple.com");
  assertEquals(claims.iat, Math.floor(now.getTime() / 1000));
  assertEquals(claims.exp - claims.iat, 180 * 24 * 60 * 60);

  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    publicKey,
    b64urlDecode(s),
    new TextEncoder().encode(`${h}.${c}`),
  );
  assert(valid, "the signature verifies with the public key");
});

Deno.test("client secret: a longer lifetime is capped at six months", async () => {
  const { pem } = await keyPair();
  const jwt = await appleClientSecret(
    { teamId: "T", keyId: "K", privateKeyPem: pem, clientId: "c" },
    new Date(), 10 * 365 * 24 * 3600,
  );
  const claims = JSON.parse(new TextDecoder().decode(b64urlDecode(jwt.split(".")[1])));
  assertEquals(claims.exp - claims.iat, 180 * 24 * 60 * 60);
});

Deno.test("client secret: a key with escaped line breaks from an env file still works", async () => {
  const { pem, publicKey } = await keyPair();
  const env = {
    APPLE_TEAM_ID: "T", APPLE_KEY_ID: "K", APPLE_CLIENT_ID: "c", APPLE_TOKEN_KEY: KEY_B64,
    APPLE_PRIVATE_KEY: pem.replace(/\n/g, "\\n"),
  };
  const config = appleConfig((n) => env[n as keyof typeof env]);
  assert(config);
  const jwt = await appleClientSecret(config);
  const [h, c, s] = jwt.split(".");
  assert(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, publicKey, b64urlDecode(s),
    new TextEncoder().encode(`${h}.${c}`)));
});

Deno.test("client secret: a malformed key is refused", async () => {
  await assertRejects(
    () => appleClientSecret({ teamId: "T", keyId: "K", privateKeyPem: "not a key", clientId: "c" }),
    AppleError,
  );
  assertEquals(pemToDer("-----BEGIN PRIVATE KEY-----\nAA==\n-----END PRIVATE KEY-----"), new Uint8Array([0]));
  assertThrows(() => pemToDer("-----BEGIN PRIVATE KEY-----\n-----END PRIVATE KEY-----"), AppleError);
});

Deno.test("config: null unless every Apple value is set", () => {
  const full = {
    APPLE_TEAM_ID: "T", APPLE_KEY_ID: "K", APPLE_PRIVATE_KEY: "k", APPLE_CLIENT_ID: "c", APPLE_TOKEN_KEY: KEY_B64,
  };
  const get = (env: Record<string, string>) => (n: string) => env[n];
  assert(appleConfig(get(full)));
  for (const name of Object.keys(full)) {
    const partial = { ...full, [name]: "" };
    assertEquals(appleConfig(get(partial)), null, `missing ${name}`);
  }
  assertEquals(appleConfig(get({})), null);
});

Deno.test("revoke: the form body, with the refresh token hint", async () => {
  const { fn, calls } = fakeFetch(200, "");
  await revokeRefreshToken("r-9", { clientId: "c", clientSecret: "s" }, fn);
  assertEquals(calls[0].url, APPLE_REVOKE_URL);
  const body = new URLSearchParams(calls[0].init.body as string);
  assertEquals(body.get("token"), "r-9");
  assertEquals(body.get("token_type_hint"), "refresh_token");
  assertEquals(body.get("client_secret"), "s");
});

Deno.test("revoke: Apple's refusal is an error the caller can log", async () => {
  const { fn } = fakeFetch(400, { error: "invalid_client" });
  await assertRejects(
    () => revokeRefreshToken("r", { clientId: "c", clientSecret: "s" }, fn),
    AppleError,
    "http_400",
  );
  const down = (async () => {
    throw new TypeError("network down");
  }) as typeof fetch;
  await assertRejects(
    () => revokeRefreshToken("r", { clientId: "c", clientSecret: "s" }, down),
    AppleError,
    "unreachable",
  );
});

Deno.test("encryption: AES-GCM round trip, with a fresh IV each time", async () => {
  const a = await encryptToken("refresh-secret", KEY_B64);
  const b = await encryptToken("refresh-secret", KEY_B64);
  assert(a !== b, "the IV differs, so the ciphertext differs");
  assertEquals(await decryptToken(a, KEY_B64), "refresh-secret");
  assertEquals(atob(a).length, 12 + "refresh-secret".length + 16);
});

Deno.test("encryption: the wrong key or altered data is refused", async () => {
  const enc = await encryptToken("refresh-secret", KEY_B64);
  const otherKey = btoa(String.fromCharCode(...new Uint8Array(32).fill(7)));
  await assertRejects(() => decryptToken(enc, otherKey));
  const bytes = Uint8Array.from(atob(enc), (c) => c.charCodeAt(0));
  bytes[bytes.length - 1] ^= 1;
  const tampered = btoa(String.fromCharCode(...bytes));
  await assertRejects(() => decryptToken(tampered, KEY_B64));
});

Deno.test("encryption: a key that is not 32 bytes is refused", async () => {
  const short = btoa("short");
  await assertRejects(() => encryptToken("x", short), AppleError, "token_key_invalid");
});
