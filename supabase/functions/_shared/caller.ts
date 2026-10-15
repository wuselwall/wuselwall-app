// Who is calling an account Edge Function (specs/20 J6, "Konto löschen"; specs/10 §4). The
// caller's JWT is verified with Auth (getUser), and the sign-in methods it records (`amr`) are
// read from the same token, so a recent re-authentication can be checked.
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

/**
 * Whether the session signed in within `maxAgeSeconds` of `now`: some `amr` entry is newer
 * than that. A refreshed session keeps the original entries, so only a fresh sign-in counts.
 */
export function signedInRecently(
  amr: AmrEntry[],
  now: Date,
  maxAgeSeconds: number,
): boolean {
  const cutoff = now.getTime() / 1000 - maxAgeSeconds;
  return amr.some((e) => e.timestamp > cutoff);
}

/** How long a sign-in counts as recent for account deletion (specs/20: 5 minutes). */
export const RECENT_SIGN_IN_SECONDS = 5 * 60;
