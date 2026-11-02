// Who is calling an account Edge Function (specs/20 J6, "Konto löschen"; specs/10 §4). The
// caller's JWT is verified with Auth (getUser), and the sign-in methods it records (`amr`) and
// its assurance level (`aal`) are read from the same token, so a recent re-authentication and
// the second factor can be checked (security review 2026-11-01, F3 and F10).
import type { User } from "npm:@supabase/supabase-js@2.75.0";
import { RequestError, userClient } from "./client.ts";

/** The bearer token of the request. */
export function bearerToken(req: Request): string {
  const header = req.headers.get("Authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    throw new RequestError(401, "unauthorized", "missing bearer token");
  }
  return match[1];
}

/**
 * The verified caller: Auth confirms the token, and the user is returned with the token it
 * arrived in. A token Auth does not accept is a 401.
 */
export async function verifiedCaller(
  req: Request,
): Promise<{ user: User; token: string }> {
  const client = userClient(req);
  const token = bearerToken(req);
  const { data, error } = await client.auth.getUser(token);
  if (error || !data?.user) {
    throw new RequestError(401, "unauthorized", "sign in again");
  }
  return { user: data.user, token };
}

/** One entry of the `amr` claim: a method the session was signed in with, and when (Unix s). */
export type AmrEntry = { method: string; timestamp: number };

/** The `amr` claim of a JWT, without verifying it (use only after Auth verified the token). */
export function amrOf(token: string): AmrEntry[] {
  const payload = token.split(".")[1];
  if (!payload) return [];
  try {
    const b64 = payload.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(payload.length / 4) * 4, "=");
    const claims = JSON.parse(atob(b64)) as { amr?: unknown };
    if (!Array.isArray(claims.amr)) return [];
    return claims.amr.filter((e): e is AmrEntry =>
      typeof e === "object" && e !== null &&
      typeof (e as AmrEntry).method === "string" &&
      typeof (e as AmrEntry).timestamp === "number"
    );
  } catch {
    return [];
  }
}

/** The `amr` methods that are a sign-in of their own (GoTrue's first factors). */
export const FIRST_FACTOR_METHODS: ReadonlySet<string> = new Set([
  "password",
  "otp",
  "magiclink",
  "recovery",
  "invite",
  "email/signup",
  "oauth",
  "sso/saml",
  "anonymous",
  "passkey",
  "web3",
]);

/**
 * Whether the session signed in within `maxAgeSeconds` of `now`: some first-factor `amr`
 * entry is newer than that. A refreshed session keeps the original entries, so only a fresh
 * sign-in counts; a second-factor step (`totp`, `mfa/*`) does not, since a stolen session
 * could enrol and prove a factor of its own (the second factor is checked separately).
 */
export function signedInRecently(
  amr: AmrEntry[],
  now: Date,
  maxAgeSeconds: number,
): boolean {
  const cutoff = now.getTime() / 1000 - maxAgeSeconds;
  return amr.some((e) => FIRST_FACTOR_METHODS.has(e.method) && e.timestamp > cutoff);
}

/** How long a sign-in counts as recent for account deletion (specs/20: 5 minutes). */
export const RECENT_SIGN_IN_SECONDS = 5 * 60;

/** A claim of the JWT, without verifying it (use only after Auth verified the token). */
export function claimOf(token: string, name: string): unknown {
  const payload = token.split(".")[1];
  if (!payload) return undefined;
  try {
    const b64 = payload.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(payload.length / 4) * 4, "=");
    return (JSON.parse(atob(b64)) as Record<string, unknown>)[name];
  } catch {
    return undefined;
  }
}

/** The `aal` claim: 'aal2' once the second factor was proven in this session, else 'aal1'. */
export function aalOf(token: string): "aal1" | "aal2" {
  return claimOf(token, "aal") === "aal2" ? "aal2" : "aal1";
}

/** Whether the account has a verified TOTP factor (Auth's /user lists the factors). */
export function hasVerifiedTotp(user: User): boolean {
  return (user.factors ?? []).some((f) =>
    f.factor_type === "totp" && f.status === "verified"
  );
}

/** The `amr` methods that are a second factor. */
const SECOND_FACTOR_METHODS = new Set(["totp", "mfa/totp", "mfa/phone", "webauthn"]);

/** Whether the session proved a second factor at some point (an `amr` entry says so). */
export function secondFactorProven(amr: AmrEntry[]): boolean {
  return amr.some((e) => SECOND_FACTOR_METHODS.has(e.method));
}

/**
 * Why a sensitive account action must wait, or null when it may go ahead: `reauth_required`
 * when no sign-in method is younger than `maxAgeSeconds`; `mfa_required` when the account has
 * a verified authenticator but this session is not aal2 with a second-factor entry. A fresh
 * sign-in starts a new session at aal1, so with an authenticator it always passes the
 * challenge again before the retry: the second factor is as fresh as the password.
 */
export function stepUpRefusal(
  user: User,
  token: string,
  now: Date,
  maxAgeSeconds: number = RECENT_SIGN_IN_SECONDS,
): "reauth_required" | "mfa_required" | null {
  const amr = amrOf(token);
  if (!signedInRecently(amr, now, maxAgeSeconds)) return "reauth_required";
  if (hasVerifiedTotp(user) && (aalOf(token) !== "aal2" || !secondFactorProven(amr))) {
    return "mfa_required";
  }
  return null;
}
