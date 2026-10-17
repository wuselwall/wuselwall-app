// Revoking Apple's access when an account is deleted (specs/20 J6): the client-secret JWT Apple
// asks for, the token revocation, and the AES-GCM decryption of the refresh token in
// app.apple_token.
//
// Sign in with Apple has been removed: no new token is stored. Accounts that signed in with
// Apple before that may still have one, and account-delete revokes it so the app's access to
// the Apple ID ends with the account (App Store Review Guideline 5.1.1(v)). Without the Apple
// environment (see appleConfig) nothing here runs.
//
// Pure apart from the injected `fetch` and the WebCrypto calls: the tests pass a fake fetch and
// a generated key pair. The key material comes from the environment; nothing here is logged.
//
// The client secret is signed with the Sign in with Apple key (.p8, ES256). Apple accepts at
// most six months.

export const APPLE_AUD = "https://appleid.apple.com";
export const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";
export const CLIENT_SECRET_MAX_SECONDS = 180 * 24 * 60 * 60;

export class AppleError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "AppleError";
  }
}

export type AppleConfig = {
  teamId: string;
  keyId: string;
  /** The PKCS#8 PEM of the .p8 key. */
  privateKeyPem: string;
  /** The client the tokens were issued to (the app's bundle id). */
  clientId: string;
  /** 32 random bytes, base64. Encrypted the refresh token at rest. */
  tokenKey: string;
};

/** The configuration, or null when any Apple value is missing (then nothing is revoked). */
export function appleConfig(env: (name: string) => string | undefined = (n) => Deno.env.get(n)): AppleConfig | null {
  const teamId = env("APPLE_TEAM_ID")?.trim();
  const keyId = env("APPLE_KEY_ID")?.trim();
  const privateKey = env("APPLE_PRIVATE_KEY")?.trim();
  const clientId = env("APPLE_CLIENT_ID")?.trim();
  const tokenKey = env("APPLE_TOKEN_KEY")?.trim();
  if (!teamId || !keyId || !privateKey || !clientId || !tokenKey) return null;
  // Env files often carry the PEM's line breaks as literal "\n".
  return {
    teamId,
    keyId,
    privateKeyPem: privateKey.replace(/\\n/g, "\n"),
    clientId,
    tokenKey,
  };
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64Decode(b64: string): Uint8Array<ArrayBuffer> {
  const binary = atob(b64);
  const out = new Uint8Array(new ArrayBuffer(binary.length));
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
}

/** The DER bytes of a PEM block (any label). */
export function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  try {
    if (body) return base64Decode(body);
  } catch {
    // Not base64: fall through to the same refusal as an empty key.
  }
  throw new AppleError("apple_key_invalid");
}

/**
 * The client-secret JWT: ES256, header kid = key id, claims iss = team, sub = client id,
 * aud = https://appleid.apple.com, iat and exp (at most six months ahead).
 */
export async function appleClientSecret(
  config: Pick<AppleConfig, "teamId" | "keyId" | "privateKeyPem" | "clientId">,
  now: Date = new Date(),
  lifetimeSeconds: number = CLIENT_SECRET_MAX_SECONDS,
): Promise<string> {
  const lifetime = Math.min(lifetimeSeconds, CLIENT_SECRET_MAX_SECONDS);
  const iat = Math.floor(now.getTime() / 1000);
  const enc = new TextEncoder();
  const header = base64UrlEncode(enc.encode(JSON.stringify({ alg: "ES256", kid: config.keyId, typ: "JWT" })));
  const claims = base64UrlEncode(enc.encode(JSON.stringify({
    iss: config.teamId,
    iat,
    exp: iat + lifetime,
    aud: APPLE_AUD,
    sub: config.clientId,
  })));
  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey(
      "pkcs8",
      pemToDer(config.privateKeyPem),
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"],
    );
  } catch {
    throw new AppleError("apple_key_invalid");
  }
  // WebCrypto returns the raw r||s signature, which is what a JWT carries.
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    enc.encode(`${header}.${claims}`),
  );
  return `${header}.${claims}.${base64UrlEncode(new Uint8Array(signature))}`;
}

export type AppleFetch = typeof fetch;

type Form = Record<string, string>;

async function postForm(url: string, form: Form, fetchFn: AppleFetch): Promise<Record<string, unknown>> {
  let response: Response;
  try {
    response = await fetchFn(url, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
      body: new URLSearchParams(form).toString(),
    });
  } catch {
    throw new AppleError("unreachable");
  }
  let json: Record<string, unknown> = {};
  try {
    json = (await response.json()) as Record<string, unknown>;
  } catch {
    // An empty body is fine for the revoke endpoint.
  }
  if (!response.ok) throw new AppleError(`http_${response.status}`);
  return json;
}

/** Revokes a refresh token at Apple, so the app's access to the Apple account ends. */
export async function revokeRefreshToken(
  refreshToken: string,
  secret: { clientId: string; clientSecret: string },
  fetchFn: AppleFetch = fetch,
): Promise<void> {
  await postForm(APPLE_REVOKE_URL, {
    client_id: secret.clientId,
    client_secret: secret.clientSecret,
    token: refreshToken,
    token_type_hint: "refresh_token",
  }, fetchFn);
}

// ------------------------------------------------------------------ encryption at rest

async function aesKey(keyB64: string): Promise<CryptoKey> {
  const raw = base64Decode(keyB64);
  if (raw.length !== 32) throw new AppleError("token_key_invalid");
  return await crypto.subtle.importKey("raw", raw, { name: "AES-GCM" }, false, ["encrypt", "decrypt"]);
}

/** AES-256-GCM with a random 12-byte IV. Returns base64(iv | ciphertext): the form the removed
 * apple-token function stored, kept so the tests can make what decryptToken reads. */
export async function encryptToken(plain: string, keyB64: string): Promise<string> {
  const key = await aesKey(keyB64);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipher = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(plain)),
  );
  const out = new Uint8Array(new ArrayBuffer(iv.length + cipher.length));
  out.set(iv, 0);
  out.set(cipher, iv.length);
  let binary = "";
  for (const b of out) binary += String.fromCharCode(b);
  return btoa(binary);
}

/** The inverse of encryptToken. Throws when the key is wrong or the data was altered. */
export async function decryptToken(encB64: string, keyB64: string): Promise<string> {
  const key = await aesKey(keyB64);
  const data = base64Decode(encB64);
  if (data.length <= 12) throw new AppleError("token_invalid");
  const plain = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: data.slice(0, 12) },
    key,
    data.slice(12),
  );
  return new TextDecoder().decode(plain);
}
