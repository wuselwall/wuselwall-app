// Fetch and re-expand a subscribed calendar. Separate from the HTTP entry point so
// rolling-window and timezone cache behaviour can be tested without a running stack.
import { expandIcs, IcsError, importWindow } from "./ical_parse.ts";
import { FetchError, fetchFeed, type FetchResult } from "./safe_fetch.ts";

export type Calendar = {
  id: string;
  url: string;
  etag: string | null;
  timezone: string;
};

export type Outcome =
  | {
    status: "refreshed";
    rows: number;
    skipped: number;
    unsupported: number;
    truncated: boolean;
    /** VEVENTs, overrides, RDATEs and EXDATEs dropped by the feed caps (ical_parse.ts). */
    capped: number;
  }
  | { status: "failed"; code: string };

/** Records a failed attempt. Itself failing is logged, not thrown. */
// deno-lint-ignore no-explicit-any
export async function fail(svc: any, id: string, code: string): Promise<void> {
  try {
    const { error } = await svc.rpc("external_calendar_fail", {
      p_id: id,
      p_error: code,
    });
    if (error) throw error;
  } catch {
    console.error("calendar-import could not record the failure:", id);
  }
}

/**
 * One full fetch and its store: expand the current window and hand the rows to the database,
 * which replaces the stored rows only when they differ (`rows_hash`). Returns the outcome;
 * never throws for a feed's own problem.
 *
 * The attempt is recorded (api.external_calendar_begin) before anything is fetched, so a
 * worker the runtime stops mid-way leaves a trace: the next run sees the attempt, counts it
 * as a failure, and api.external_calendar_due moves on to the other calendars instead of
 * starting with this one again every hour (security review 2026-11-01, F6).
 */
// deno-lint-ignore no-explicit-any
export async function importCalendar(
  svc: any,
  cal: Calendar,
  now: Date,
  fetch: typeof fetchFeed = fetchFeed,
): Promise<Outcome> {
  const { error: beginError } = await svc.rpc("external_calendar_begin", { p_id: cal.id });
  if (beginError) {
    // Without the record nothing is fetched: the database is the thing that is not answering.
    console.error("calendar-import could not record the attempt:", cal.id, beginError.code ?? "");
    return { status: "failed", code: "db" };
  }

  let fetched: FetchResult;
  try {
    // Cached occurrences depend on today's window and the household timezone, not
    // only the source bytes. Without a retained source body, a 304 cannot rebuild
    // them. Always fetch the bounded feed; source validators alone are insufficient.
    fetched = await fetch(cal.url, {});
  } catch (err) {
    const code = err instanceof FetchError ? err.code : "internal";
    if (code === "internal") {
      console.error("calendar-import fetch failed:", cal.id);
    }
    await fail(svc, cal.id, code);
    return { status: "failed", code };
  }

  // Nothing was asked conditionally, so a 304 is the feed misbehaving: a failure, not a result.
  if (fetched.kind === "not_modified") {
    await fail(svc, cal.id, "http_304");
    return { status: "failed", code: "http_304" };
  }

  let expanded: ReturnType<typeof expandIcs>;
  try {
    const window = importWindow(now, cal.timezone);
    expanded = expandIcs(fetched.body, {
      householdTz: cal.timezone,
      from: window.from,
      to: window.to,
      calendarId: cal.id,
    });
  } catch (err) {
    const code = err instanceof IcsError ? "not_ics" : "internal";
    if (code === "internal") {
      console.error("calendar-import expansion failed:", cal.id);
    }
    await fail(svc, cal.id, code);
    return { status: "failed", code };
  }

  const { error } = await svc.rpc("external_calendar_store", {
    p_id: cal.id,
    p_rows: expanded.rows,
    p_etag: fetched.etag,
  });
  if (error) {
    console.error("calendar-import store failed:", cal.id, error.code ?? "");
    await fail(svc, cal.id, "db");
    return { status: "failed", code: "db" };
  }
  return {
    status: "refreshed",
    rows: expanded.rows.length,
    skipped: expanded.skipped,
    unsupported: expanded.unsupported,
    truncated: expanded.truncated,
    capped: expanded.capped,
  };
}
