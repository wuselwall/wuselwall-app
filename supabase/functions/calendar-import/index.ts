// Imports the external ICS calendars of a household (FR-1.9, specs/05 "Later: importing external
// calendars"). The server fetches every feed; the apps never do (NFR-9).
//
// Two modes, told apart by the request:
//
// - Scheduled (header `x-cron-secret`, no body): the hourly job of infra/jobs/schedule.sql
//   (or infra/cron/calendar-import.sh from the host's cron).
//   Fetches up to 20 calendars that are active and were last attempted more than 55 minutes ago
//   (api.external_calendar_due), oldest attempt first. Authenticated like holidays-sync: the
//   secret, compared in constant time, and nothing else.
//
// - On demand (user JWT, body `{calendar_id, actor_profile_id?}`): a guardian asks for one
//   calendar now. The caller is verified with their own JWT, and the guard is the database's:
//   api.external_calendar_refresh_request runs as the caller (app.actor, the guardian check, the
//   household's RLS), so a member, a child, a kiosk or another household gets its refusal from
//   there. Only then does the service role read the calendar's URL and write the result, through
//   the service-only api.external_calendar_* functions. A calendar fetched less than five minutes
//   ago is not fetched again; the answer says so.
//
// Every fetch goes through _shared/safe_fetch.ts (https only, public addresses only, redirects
// re-checked, 15 s, 2 MB). Full reads re-expand the current window and timezone.
// A failure is stored in last_error as a short code and answered, never thrown to
// the scheduler, so one broken feed does not stop the others.
import {
  errorResponse,
  json,
  preflight,
  readBody,
  RequestError,
  requirePost,
  serviceClient,
  userClient,
} from "../_shared/client.ts";
import {
  type Calendar,
  fail,
  importCalendar,
  type Outcome,
} from "../_shared/calendar_import.ts";

/** The scheduled job takes this many calendars per run at most. */
const MAX_PER_RUN = 20;
/** An on-demand fetch is refused (answered from the stored state) this soon after the last attempt. */
const RECENT_MS = 5 * 60 * 1000;

/**
 * Compares two strings without leaking, through timing, where they first differ.
 * Copied from holidays-sync and tasks-nightly (all three guard a shared secret the same way).
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

function bearerToken(req: Request): string {
  const header = req.headers.get("Authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    throw new RequestError(401, "unauthorized", "missing bearer token");
  }
  return match[1];
}

/** The scheduled job: the calendars that are due, one after the other. */
async function scheduled(now: Date): Promise<Response> {
  // Service role: a scheduled job has no user. The secret is the only gate.
  const svc = serviceClient();
  const { data, error } = await svc.rpc("external_calendar_due", {
    p_max: MAX_PER_RUN,
  });
  if (error) throw error;
  const due = Array.isArray(data) ? (data as Calendar[]) : [];

  const results: Array<{ id: string } & Outcome> = [];
  for (const cal of due) {
    try {
      results.push({ id: cal.id, ...(await importCalendar(svc, cal, now)) });
    } catch {
      // One calendar failing must not stop the others.
      console.error("calendar-import calendar failed:", cal.id);
      await fail(svc, cal.id, "internal");
      results.push({ id: cal.id, status: "failed", code: "internal" });
    }
  }
  return json({ calendars: due.length, results });
}

/** The guardian's "fetch now" for one calendar. */
async function onDemand(req: Request, now: Date): Promise<Response> {
  // userClient throws 401 without an Authorization header.
  const user = userClient(req);
  const { data: auth, error: authError } = await user.auth.getUser(
    bearerToken(req),
  );
  if (authError || !auth?.user) {
    throw new RequestError(401, "unauthorized", "sign in again");
  }

  const body = await readBody(req);
  const calendarId = body.calendar_id;
  if (typeof calendarId !== "string" || !/^[0-9a-f-]{36}$/i.test(calendarId)) {
    throw new RequestError(
      400,
      "calendar_invalid",
      "calendar_id must be a uuid",
      "external_calendar_invalid",
    );
  }
  const actor = typeof body.actor_profile_id === "string"
    ? body.actor_profile_id
    : null;

  // Acting as the caller: the guardian gate, the device and the household are the database's.
  const { data: gate, error: gateError } = await user.rpc(
    "external_calendar_refresh_request",
    {
      p_actor: actor,
      p_id: calendarId,
    },
  );
  if (gateError) throw gateError;
  const state = gate as {
    id: string;
    active: boolean;
    last_fetched_at: string | null;
    last_error: string | null;
  };
  if (!state.active) {
    throw new RequestError(
      409,
      "calendar_inactive",
      "the calendar is switched off",
      "external_calendar_inactive",
    );
  }
  if (
    state.last_fetched_at &&
    now.getTime() - Date.parse(state.last_fetched_at) < RECENT_MS
  ) {
    return json({
      calendar_id: calendarId,
      status: "recent",
      last_fetched_at: state.last_fetched_at,
      last_error: state.last_error,
    });
  }

  // Service role: the calendar's URL and etag, then the store. The guard above has passed.
  const svc = serviceClient();
  const { data: row, error: getError } = await svc.rpc(
    "external_calendar_get",
    { p_id: calendarId },
  );
  if (getError) throw getError;
  const cal = row as Calendar & { active: boolean };
  const outcome = await importCalendar(svc, cal, now);
  return json({ calendar_id: calendarId, ...outcome });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const now = new Date();
    if (req.headers.has("x-cron-secret")) {
      if (!authorised(req)) {
        return new Response(null, { status: 401 });
      }
      return await scheduled(now);
    }
    return await onDemand(req, now);
  } catch (err) {
    return errorResponse(err);
  }
});
