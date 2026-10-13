// POST {} → {created}. Creates the task instances of the caller's household for the
// next 14 days (specs/06). The app calls it after saving a recurring definition. The
// schedule and the write both run as the caller, so RLS and api.tasks_materialise
// (p_household must be the caller's household) decide what may change.
import {
  errorResponse,
  json,
  preflight,
  requirePost,
  userClient,
} from "../_shared/client.ts";
import { dueDates, type TaskSchedule } from "../_shared/tasks.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const client = userClient(req);

    const { data, error } = await client.rpc("tasks_schedule");
    if (error) throw error;
    const schedule = data as TaskSchedule;

    const { data: result, error: writeError } = await client.rpc(
      "tasks_materialise",
      {
        p_household: schedule.household_id,
        p_due: dueDates(schedule),
      },
    );
    if (writeError) throw writeError;
    const { created } = result as { created: number };
    return json({ created });
  } catch (err) {
    return errorResponse(err);
  }
});
