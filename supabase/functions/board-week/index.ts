// POST {week_start?} → the kiosk week board (specs/09). The base comes from
// api.board_week; presence, the day's appointments and busy_until are filled from the
// week's occurrences, the timetables and school days from the school projection, and the
// meal zone from the week's meal plan entries. Acts as the caller, so RLS applies
// (ADR-010).
import {
  errorResponse,
  json,
  preflight,
  readBody,
  requirePost,
  userClient,
} from "../_shared/client.ts";
import {
  type BoardJson,
  fillBoard,
  fillMeals,
  fillSchool,
  type MealMember,
} from "../_shared/board.ts";
import { checkDay, loadCalendar } from "../_shared/calendar_data.ts";
import { addDays } from "../_shared/occurrences.ts";
import { projectSchoolDays, timetablesJson } from "../_shared/school.ts";
import { loadSchoolData } from "../_shared/school_data.ts";
import { loadMeals } from "../_shared/meals_data.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const client = userClient(req);
    const body = await readBody(req);
    const weekStart = body.week_start == null
      ? null
      : checkDay(body.week_start, "week_invalid");

    const { data, error } = await client.rpc("board_week", {
      p_week_start: weekStart,
    });
    if (error) throw error;
    const base = data as BoardJson;

    const weekEnd = addDays(base.week_start, 6);
    const [calendar, school, meals] = await Promise.all([
      loadCalendar(client, base.week_start, weekEnd, String(base.timezone)),
      loadSchoolData(client, base.week_start, weekEnd),
      loadMeals(client, base.week_start, weekEnd),
    ]);
    const schoolDays = projectSchoolDays(school, base.week_start, weekEnd);
    const withCalendar = fillBoard(
      base,
      calendar.occurrences,
      calendar.busy_until,
    );
    const withSchool = fillSchool(
      withCalendar,
      schoolDays,
      timetablesJson(school, base.week_start),
    );
    return json(
      fillMeals(withSchool, {
        entries: meals.entries,
        settings: meals.settings,
        presence: calendar.occurrences,
        schoolDays,
        members: base.members as MealMember[],
      }),
    );
  } catch (err) {
    return errorResponse(err);
  }
});
