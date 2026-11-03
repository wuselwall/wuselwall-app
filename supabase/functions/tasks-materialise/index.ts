// POST {} → {created}. Creates the task instances of the caller's household for the
// next 14 days (specs/06). The app calls it after saving a recurring definition.
//
// The due days are the server's, never the client's (security review 2026-11-01, F4): the
// schedule is read as the caller (PostgREST verifies the JWT, and api.tasks_schedule answers
// only for a live device of the caller's household), the rules are expanded here with the
// shared code, and the write goes through the service role, as tasks-nightly does. The
// service role is used for that one call only, with the household the caller's own schedule
// named and the due days this expander produced; api.tasks_materialise refuses any other
// role, so a device cannot materialise days of its own choosing.
import {
  errorResponse,
  json,
  preflight,
  RequestError,
  requirePost,
  serviceClient,
  userClient,
} from "../_shared/client.ts";
import { dueDates, type TaskSchedule } from "../_shared/tasks.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);

    // As the caller: a stranger's account or a revoked device gets no schedule and stops here.
    const { data, error } = await userClient(req).rpc("tasks_schedule");
    if (error) throw error;
    const schedule = data as TaskSchedule | null;
    if (!schedule?.household_id) {
      throw new RequestError(403, "forbidden", "no household");
    }

    // Service role: the only caller api.tasks_materialise accepts. The household and the
    // due days come from the lines above, not from the request body.
    const { data: result, error: writeError } = await serviceClient().rpc(
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
