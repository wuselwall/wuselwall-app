import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import type { User } from "npm:@supabase/supabase-js@2.75.0";
import {
  aalOf,
  amrOf,
  hasVerifiedTotp,
  RECENT_SIGN_IN_SECONDS,
  secondFactorProven,
  signedInRecently,
  stepUpRefusal,
} from "./caller.ts";

function jwtWith(claims: unknown): string {
  const enc = (o: unknown) => btoa(JSON.stringify(o)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `${enc({ alg: "HS256" })}.${enc(claims)}.sig`;
}

Deno.test("amr: the entries of the token, malformed ones dropped", () => {
  const token = jwtWith({
    amr: [
      { method: "password", timestamp: 100 },
      { method: 5, timestamp: 1 },
      { method: "otp" },
      "junk",
      { method: "oauth", timestamp: 200 },
    ],
  });
  assertEquals(amrOf(token), [
    { method: "password", timestamp: 100 },
    { method: "oauth", timestamp: 200 },
  ]);
});

Deno.test("amr: no claim, or no token, is an empty list", () => {
  assertEquals(amrOf(jwtWith({ sub: "x" })), []);
  assertEquals(amrOf("not-a-jwt"), []);
  assertEquals(amrOf("a.%%%.c"), []);
});

Deno.test("recent sign-in: within five minutes counts, older does not", () => {
  const now = new Date("2026-10-15T10:00:00Z");
  const t = now.getTime() / 1000;
  assert(signedInRecently([{ method: "otp", timestamp: t - 60 }], now, RECENT_SIGN_IN_SECONDS));
  assert(!signedInRecently([{ method: "otp", timestamp: t - 6 * 60 }], now, RECENT_SIGN_IN_SECONDS));
  assert(!signedInRecently([], now, RECENT_SIGN_IN_SECONDS));
});

Deno.test("recent sign-in: one fresh method among older ones is enough", () => {
  const now = new Date("2026-10-15T10:00:00Z");
  const t = now.getTime() / 1000;
  assert(signedInRecently([
    { method: "password", timestamp: t - 3600 },
    { method: "oauth", timestamp: t - 30 },
  ], now, RECENT_SIGN_IN_SECONDS));
});

/** A user as Auth's /user returns it, with or without a verified authenticator. */
function userWith(factors: Array<{ factor_type: string; status: string }>): User {
  return {
    id: "5f1c0e8a-0000-4000-8000-000000000001",
    aud: "authenticated",
    app_metadata: {},
    user_metadata: {},
    created_at: "2026-10-01T00:00:00Z",
    factors: factors.map((f, i) => ({
      id: `f${i}`,
      friendly_name: "x",
      factor_type: f.factor_type,
      status: f.status,
      created_at: "2026-10-01T00:00:00Z",
      updated_at: "2026-10-01T00:00:00Z",
    })),
  } as unknown as User;
}

Deno.test("aal: aal2 only when the claim says so", () => {
  assertEquals(aalOf(jwtWith({ aal: "aal2" })), "aal2");
  assertEquals(aalOf(jwtWith({ aal: "aal1" })), "aal1");
  assertEquals(aalOf(jwtWith({})), "aal1");
  assertEquals(aalOf("junk"), "aal1");
});

Deno.test("a verified TOTP factor counts, an unverified or other one does not", () => {
  assert(hasVerifiedTotp(userWith([{ factor_type: "totp", status: "verified" }])));
  assert(!hasVerifiedTotp(userWith([{ factor_type: "totp", status: "unverified" }])));
  assert(!hasVerifiedTotp(userWith([{ factor_type: "phone", status: "verified" }])));
  assert(!hasVerifiedTotp(userWith([])));
  assert(!hasVerifiedTotp({ ...userWith([]), factors: undefined } as User));
  assert(secondFactorProven([{ method: "totp", timestamp: 1 }]));
  assert(!secondFactorProven([{ method: "password", timestamp: 1 }]));
});

Deno.test("step-up (F10): a stale sign-in is reauth_required, before anything else", () => {
  const now = new Date("2026-10-15T10:00:00Z");
  const t = now.getTime() / 1000;
  const withTotp = userWith([{ factor_type: "totp", status: "verified" }]);
  const stale = jwtWith({ aal: "aal2", amr: [{ method: "password", timestamp: t - 3600 }, { method: "totp", timestamp: t - 3500 }] });
  assertEquals(stepUpRefusal(withTotp, stale, now), "reauth_required");
  assertEquals(stepUpRefusal(userWith([]), stale, now), "reauth_required");
});

Deno.test("step-up (F10): with an authenticator, aal1 or no second-factor entry is mfa_required", () => {
  const now = new Date("2026-10-15T10:00:00Z");
  const t = now.getTime() / 1000;
  const withTotp = userWith([{ factor_type: "totp", status: "verified" }]);
  const passwordOnly = jwtWith({ aal: "aal1", amr: [{ method: "password", timestamp: t - 30 }] });
  assertEquals(stepUpRefusal(withTotp, passwordOnly, now), "mfa_required");
  const aal2ButNoEntry = jwtWith({ aal: "aal2", amr: [{ method: "password", timestamp: t - 30 }] });
  assertEquals(stepUpRefusal(withTotp, aal2ButNoEntry, now), "mfa_required");
  const entryButAal1 = jwtWith({ aal: "aal1", amr: [{ method: "password", timestamp: t - 30 }, { method: "totp", timestamp: t - 20 }] });
  assertEquals(stepUpRefusal(withTotp, entryButAal1, now), "mfa_required");
  const proven = jwtWith({ aal: "aal2", amr: [{ method: "password", timestamp: t - 30 }, { method: "totp", timestamp: t - 20 }] });
  assertEquals(stepUpRefusal(withTotp, proven, now), null);
});

Deno.test("recent sign-in: a fresh second-factor entry alone does not count", () => {
  const now = new Date("2026-10-15T10:00:00Z");
  const t = now.getTime() / 1000;
  assert(!signedInRecently([
    { method: "password", timestamp: t - 3600 },
    { method: "totp", timestamp: t - 30 },
  ], now, RECENT_SIGN_IN_SECONDS));
  assert(!signedInRecently([{ method: "mfa/totp", timestamp: t - 30 }], now, RECENT_SIGN_IN_SECONDS));
  assert(!signedInRecently([{ method: "token_refresh", timestamp: t - 30 }], now, RECENT_SIGN_IN_SECONDS));
  // A stolen aal1 session that enrolled an authenticator of its own is still refused.
  const withTotp = userWith([{ factor_type: "totp", status: "verified" }]);
  const enrolled = jwtWith({ aal: "aal2", amr: [{ method: "password", timestamp: t - 3600 }, { method: "totp", timestamp: t - 20 }] });
  assertEquals(stepUpRefusal(withTotp, enrolled, now), "reauth_required");
});

Deno.test("step-up: without an authenticator a fresh password sign-in at aal1 is enough", () => {
  const now = new Date("2026-10-15T10:00:00Z");
  const t = now.getTime() / 1000;
  const fresh = jwtWith({ aal: "aal1", amr: [{ method: "otp", timestamp: t - 30 }] });
  assertEquals(stepUpRefusal(userWith([]), fresh, now), null);
});
