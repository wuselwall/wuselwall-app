import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { APPLE_REVOKE_URL, type AppleConfig, encryptToken } from "./apple.ts";
import { type RevocationRow, type RevocationStore, settleRevocations } from "./apple_revocation.ts";

// The controlled Apple transport of specs/22: fake fetches stand in for Apple, so these tests
// show the failure handling and the kept obligations, not that Apple accepts a real token.

const KEY_B64 = btoa(String.fromCharCode(...new Uint8Array(32).map((_, i) => i + 1)));
const OTHER_KEY_B64 = btoa(String.fromCharCode(...new Uint8Array(32).map((_, i) => 200 - i)));

async function config(): Promise<AppleConfig> {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let b64 = "";
  for (const b of pkcs8) b64 += String.fromCharCode(b);
  const label = "PRIVATE KEY";
  return {
    teamId: "TEAM123456",
    keyId: "KEY1234567",
    privateKeyPem: `-----BEGIN ${label}-----\n${btoa(b64)}\n-----END ${label}-----\n`,
    clientId: "ch.goomba.wuselwall",
    tokenKey: KEY_B64,
  };
}

/** An in-memory app.apple_revocation with the two functions' semantics. */
function store(rows: RevocationRow[]) {
  const table = new Map(rows.map((r) => [r.id, { ...r, last_error: null as string | null }]));
  const calls: { id: string; error: string | null }[] = [];
  const s: RevocationStore = {
    due: (_user?: string) => Promise.resolve([...table.values()].map(({ id, refresh_token_enc, attempts }) => ({ id, refresh_token_enc, attempts }))),
    record: (id, error) => {
      calls.push({ id, error });
      const row = table.get(id);
      if (row && error === null) table.delete(id);
      else if (row) {
        row.attempts++;
        row.last_error = error;
      }
      return Promise.resolve();
    },
  };
  return { s, table, calls };
}

function apple(status: number | "down") {
  const bodies: string[] = [];
  const fn = (async (input: string | URL | Request, init?: RequestInit) => {
    assertEquals(String(input), APPLE_REVOKE_URL);
    bodies.push(String(init?.body ?? ""));
    if (status === "down") throw new TypeError("connection refused");
    return new Response(status === 200 ? "" : JSON.stringify({ error: "x" }), { status });
  }) as typeof fetch;
  return { fn, bodies };
}

async function row(id: string, plain: string, key = KEY_B64): Promise<RevocationRow> {
  return { id, refresh_token_enc: await encryptToken(plain, key), attempts: 0 };
}

Deno.test("success: the token is revoked at Apple and the obligation removed", async () => {
  const { s, table, calls } = store([await row("r1", "refresh-1")]);
  const a = apple(200);
  const out = await settleRevocations(s, await config(), { fetchFn: a.fn });
  assertEquals(out, { tried: 1, revoked: 1, kept: 0, unconfigured: false });
  assertEquals(table.size, 0);
  assertEquals(calls, [{ id: "r1", error: null }]);
  const form = new URLSearchParams(a.bodies[0]);
  assertEquals(form.get("token"), "refresh-1");
  assertEquals(form.get("token_type_hint"), "refresh_token");
  assertEquals(form.get("client_id"), "ch.goomba.wuselwall");
});

Deno.test("missing configuration: nothing is sent and every obligation is kept", async () => {
  const { s, table } = store([await row("r1", "a"), await row("r2", "b")]);
  const a = apple(200);
  const out = await settleRevocations(s, null, { fetchFn: a.fn });
  assertEquals(out, { tried: 2, revoked: 0, kept: 2, unconfigured: true });
  assertEquals(a.bodies.length, 0);
  assertEquals(table.size, 2);
  assertEquals(table.get("r1")?.last_error, "config_missing");
});

Deno.test("decryption failure: kept with decrypt_failed, the others still go", async () => {
  const { s, table } = store([await row("bad", "x", OTHER_KEY_B64), await row("good", "y")]);
  const a = apple(200);
  const out = await settleRevocations(s, await config(), { fetchFn: a.fn });
  assertEquals(out, { tried: 2, revoked: 1, kept: 1, unconfigured: false });
  assertEquals([...table.keys()], ["bad"]);
  assertEquals(table.get("bad")?.last_error, "decrypt_failed");
  assertEquals(table.get("bad")?.attempts, 1);
});

Deno.test("Apple unreachable: kept with unreachable, ready for the next attempt", async () => {
  const { s, table } = store([await row("r1", "refresh-1")]);
  const out = await settleRevocations(s, await config(), { fetchFn: apple("down").fn });
  assertEquals(out.kept, 1);
  assertEquals(table.get("r1")?.last_error, "unreachable");
  assert(table.get("r1")?.refresh_token_enc, "the encrypted token is still there");
});

Deno.test("Apple answers with an error: kept with the status code", async () => {
  const { s, table } = store([await row("r1", "refresh-1")]);
  const out = await settleRevocations(s, await config(), { fetchFn: apple(503).fn });
  assertEquals(out.kept, 1);
  assertEquals(table.get("r1")?.last_error, "http_503");
});

Deno.test("an invalid signing key: kept, nothing sent", async () => {
  const { s, table } = store([await row("r1", "refresh-1")]);
  const a = apple(200);
  const cfg = { ...(await config()), privateKeyPem: "not a key" };
  const out = await settleRevocations(s, cfg, { fetchFn: a.fn });
  assertEquals(out.kept, 1);
  assertEquals(a.bodies.length, 0);
  assertEquals(table.get("r1")?.last_error, "apple_key_invalid");
});

Deno.test("a retry after a failure succeeds and removes the obligation", async () => {
  const { s, table } = store([await row("r1", "refresh-1")]);
  const cfg = await config();
  await settleRevocations(s, cfg, { fetchFn: apple("down").fn });
  assertEquals(table.get("r1")?.attempts, 1);
  const out = await settleRevocations(s, cfg, { fetchFn: apple(200).fn });
  assertEquals(out.revoked, 1);
  assertEquals(table.size, 0);
});

Deno.test("nothing due: no call to Apple", async () => {
  const { s } = store([]);
  const a = apple(200);
  const out = await settleRevocations(s, await config(), { fetchFn: a.fn });
  assertEquals(out, { tried: 0, revoked: 0, kept: 0, unconfigured: false });
  assertEquals(a.bodies.length, 0);
});

Deno.test("reason codes never carry the token", async () => {
  const { s, calls } = store([await row("r1", "secret-refresh-token")]);
  await settleRevocations(s, await config(), { fetchFn: apple(400).fn });
  for (const c of calls) assert(!String(c.error).includes("secret-refresh-token"));
});
