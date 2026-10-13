// POST {from, to} → the household's occurrences and busy_until in that window.
// Expansion runs here, never in SQL or the app (specs/05). Acts as the caller: RLS
// decides what is visible, so a revoked device gets a 403.
import {
  errorResponse,
  json,
  preflight,
  readBody,
  requirePost,
  userClient,
} from "../_shared/client.ts";
import { checkWindow, loadCalendar } from "../_shared/calendar_data.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const client = userClient(req);
    const body = await readBody(req);
    const { from, to } = checkWindow(body.from, body.to);

    // The household's timezone has no api view of its own. api.board_week carries it
    // as `timezone`, so that is the source; the week it builds is discarded.
    const { data: base, error } = await client.rpc("board_week", {
      p_week_start: from,
    });
    if (error) throw error;
    const timezone = String((base as { timezone: unknown }).timezone);

    const calendar = await loadCalendar(client, from, to, timezone);
    return json({
      timezone,
      occurrences: calendar.occurrences,
      busy_until: calendar.busy_until,
    });
  } catch (err) {
    return errorResponse(err);
  }
});
