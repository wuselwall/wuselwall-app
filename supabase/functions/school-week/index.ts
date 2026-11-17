// POST {from, to} → the school days of the caller's children for a window of local
// dates (at most 62), the timetables valid on `from` and the one-off things to bring
// dated in the window (`pack`, specs/15; also for a child without a timetable). Acts as
// the caller, so RLS applies (ADR-010).
import {
  errorResponse,
  json,
  preflight,
  readBody,
  requirePost,
  userClient,
} from "../_shared/client.ts";
import { checkWindow } from "../_shared/calendar_data.ts";
import { projectSchoolDays, timetablesJson } from "../_shared/school.ts";
import { loadSchoolData } from "../_shared/school_data.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const client = userClient(req);
    const body = await readBody(req);
    const { from, to } = checkWindow(body.from, body.to);
    const data = await loadSchoolData(client, from, to);
    return json({
      timetables: timetablesJson(data, from),
      days: projectSchoolDays(data, from, to),
      pack: data.packItems,
    });
  } catch (err) {
    return errorResponse(err);
  }
});
