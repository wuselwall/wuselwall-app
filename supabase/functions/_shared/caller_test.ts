import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { amrOf, RECENT_SIGN_IN_SECONDS, signedInRecently } from "./caller.ts";

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
