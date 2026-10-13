// POST (no body) → {households, results}. The nightly task job (specs/06): for every
// household, materialise the next 14 days of task instances, then close yesterday in
// the household's own timezone (expire open instances, settle streaks and jokers,
// evaluate badges). Both writes are idempotent, so a re-run is harmless.
//
// Authentication: a scheduled job has no user, so this function uses the service-role
// client (serviceClient) and is protected by the shared secret in header `x-cron-secret`,
// which must equal the function's CRON_SECRET (compared in constant time). Anything else
// is a 401 with no body. The service role is only used for the two service_role
// functions: tasks_schedule_all and tasks_close_day.
//
// Scheduling: infra/cron/tasks-nightly.sh, run at 03:00 by homeserver's User Scripts plugin,
// POSTs here through the gateway on the Docker bridge with the secret from a root-only
// file. The router lets this function through without a user JWT (NO_USER_FUNCTIONS in
// infra/supabase/volumes/functions/main/index.ts); the secret is the only way in.
// Run it once a day. Re-running is safe: materialising is keyed, and the day close is
// recorded in app.tasks_day_closed.
import {
  errorResponse,
  json,
  requirePost,
  serviceClient,
} from "../_shared/client.ts";
import { addDays } from "../_shared/occurrences.ts";
import { dueDates, type TaskSchedule } from "../_shared/tasks.ts";

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

type HouseholdResult =
  | {
    household_id: string;
    ok: true;
    created: number;
    closed: unknown;
  }
  | { household_id: string; ok: false; code: string };

/** One household: materialise, then close yesterday. Throws on any database error. */
async function runHousehold(
  // deno-lint-ignore no-explicit-any
  client: any,
  schedule: TaskSchedule,
): Promise<{ created: number; closed: unknown }> {
  const { data: created, error: writeError } = await client.rpc(
    "tasks_materialise",
    { p_household: schedule.household_id, p_due: dueDates(schedule) },
  );
  if (writeError) throw writeError;

  const yesterday = addDays(schedule.today, -1);
  const { data: closed, error: closeError } = await client.rpc(
    "tasks_close_day",
    { p_household: schedule.household_id, p_day: yesterday },
  );
  if (closeError) throw closeError;

  return { created: (created as { created: number }).created, closed };
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
    // Service role: a scheduled job has no user. tasks_schedule_all is service_role
    // only, and tasks_close_day is too; the secret above is the only gate.
    const client = serviceClient();
    const { data, error } = await client.rpc("tasks_schedule_all");
    if (error) throw error;
    if (!Array.isArray(data)) {
      throw new Error("tasks_schedule_all: expected an array");
    }

    const results: HouseholdResult[] = [];
    for (const schedule of data as TaskSchedule[]) {
      // One household failing must not stop the others: record it and go on.
      try {
        const done = await runHousehold(client, schedule);
        results.push({
          household_id: schedule.household_id,
          ok: true,
          ...done,
        });
      } catch (err) {
        const code = typeof (err as { code?: unknown })?.code === "string"
          ? (err as { code: string }).code
          : "internal";
        console.error(
          "tasks-nightly household failed:",
          schedule.household_id,
          code,
        );
        results.push({ household_id: schedule.household_id, ok: false, code });
      }
    }
    return json({ households: results.length, results });
  } catch (err) {
    return errorResponse(err);
  }
});
