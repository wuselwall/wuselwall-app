// POST (no body) → {households, device_accounts}. The daily purge of deleted families
// (specs/20 J6): a family deleted more than 14 days ago is removed with its rows, and the
// Auth users of its shared and kiosk devices go with it. Adult accounts are never touched.
//
// Authentication: a scheduled job has no user, so this function uses the service-role client
// (serviceClient) and is protected by the shared secret in header `x-cron-secret`, compared in
// constant time. Anything else is a 401 with no body. The service role is only used for
// api.household_purge_due and the Apple revocation obligations (api.apple_revocation_due and
// _record, which settle the open revocations of already deleted accounts); all three check the
// role themselves as well.
//
// Scheduling: pg_cron (infra/jobs/schedule.sql) or infra/cron/household-purge.sh, daily, POSTs
// here through the gateway on the Docker bridge with the secret from a root-only file. The
// router lets this function through without a user JWT (NO_USER_FUNCTIONS in
// infra/supabase/volumes/functions/main/index.ts); the secret is the only way in. Re-running
// is harmless: a purged family is simply no longer due.
import {
  errorResponse,
  json,
  requirePost,
  serviceClient,
} from "../_shared/client.ts";
import { appleConfig } from "../_shared/apple.ts";
import { rpcRevocationStore, settleRevocations } from "../_shared/apple_revocation.ts";

/**
 * Compares two strings without leaking, through timing, where they first differ.
 * Length differences are folded into the result rather than returned early.
 */
function constantTimeEquals(a: string, b: string): boolean {
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

function authorised(req: Request): boolean {
  const expected = Deno.env.get("CRON_SECRET");
  const given = req.headers.get("x-cron-secret");
  if (!expected || !given) return false;
  return constantTimeEquals(given, expected);
}

Deno.serve(async (req: Request): Promise<Response> => {
  try {
    requirePost(req);
  } catch (err) {
    return errorResponse(err);
  }
  if (!authorised(req)) {
    return new Response(null, { status: 401 });
  }

  try {
    // Service role: a scheduled job has no user. api.household_purge_due is service_role only.
    const client = serviceClient();
    const { data, error } = await client.rpc("household_purge_due");
    if (error) throw error;
    const counts = (data ?? {}) as {
      households?: number;
      device_accounts?: number;
    };
    console.log(
      "household-purge:",
      counts.households ?? 0,
      "families,",
      counts.device_accounts ?? 0,
      "device accounts",
    );
    // Apple revocations still open from deleted accounts (specs/22 item 6): retried here, once
    // a day. A failure is kept for tomorrow and never fails the purge.
    let apple: { revoked: number; kept: number; unconfigured: boolean } | null = null;
    try {
      const outcome = await settleRevocations(rpcRevocationStore(client), appleConfig());
      apple = { revoked: outcome.revoked, kept: outcome.kept, unconfigured: outcome.unconfigured && outcome.tried > 0 };
      if (outcome.tried > 0) {
        console.log(
          "household-purge: Apple revocations",
          outcome.revoked,
          "revoked,",
          outcome.kept,
          outcome.unconfigured ? "kept (Apple values missing)" : "kept for retry",
        );
      }
    } catch {
      console.error("household-purge: Apple revocations not tried");
    }
    return json({
      households: counts.households ?? 0,
      device_accounts: counts.device_accounts ?? 0,
      apple_revocations: apple,
    });
  } catch (err) {
    return errorResponse(err);
  }
});
