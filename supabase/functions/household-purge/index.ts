// POST (no body) → {households, device_accounts}. The daily purge of deleted families
// (specs/20 J6): a family deleted more than 14 days ago is removed with its rows, and the
// Auth users of its shared and kiosk devices go with it. Adult accounts are never touched.
//
// Authentication: a scheduled job has no user, so this function uses the service-role client
// (serviceClient) and is protected by the shared secret in header `x-cron-secret`, compared in
// constant time. Anything else is a 401 with no body. The service role is only used for
// api.household_purge_due, which checks the role itself as well.
//
// Scheduling: infra/cron/household-purge.sh, run daily by Unraid's User Scripts plugin, POSTs
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
    return json({
      households: counts.households ?? 0,
      device_accounts: counts.device_accounts ?? 0,
    });
  } catch (err) {
    return errorResponse(err);
  }
});
