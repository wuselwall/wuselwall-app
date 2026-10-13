// Loads the calendar rows for a window of local dates and expands them. Shared by the
// `occurrences` and `board-week` functions, so both see the same events and overrides.
import type { BusyRow } from "./board.ts";
import { RequestError, type userClient } from "./client.ts";
import {
  addDays,
  type EventRow,
  expand,
  type Occurrence,
  type OverrideRow,
} from "./occurrences.ts";

/** The most local days one call may expand. */
export const MAX_WINDOW_DAYS = 62;

type Client = ReturnType<typeof userClient>;

/** A 'YYYY-MM-DD' calendar date, or a 400 with `code`. */
export function checkDay(value: unknown, code: string): string {
  const ok = typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value) &&
    new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) === value;
  if (!ok) {
    throw new RequestError(400, code, `not a calendar date: ${String(value)}`);
  }
  return value as string;
}

/** Inclusive `from`..`to` in local dates, at most MAX_WINDOW_DAYS long. */
export function checkWindow(
  from: unknown,
  to: unknown,
): { from: string; to: string } {
  const f = checkDay(from, "window_invalid");
  const t = checkDay(to, "window_invalid");
  const days = (Date.parse(`${t}T00:00:00Z`) - Date.parse(`${f}T00:00:00Z`)) /
      86_400_000 + 1;
  if (days < 1) {
    throw new RequestError(400, "window_invalid", "to is before from");
  }
  if (days > MAX_WINDOW_DAYS) {
    throw new RequestError(
      400,
      "window_invalid",
      `window longer than ${MAX_WINDOW_DAYS} days`,
    );
  }
  return { from: f, to: t };
}

/**
 * The occurrences of every event that can fall in [from, to] (both inclusive local
 * dates in `timezone`) and the busy_until rows of those dates.
 *
 * The SQL filter only narrows the rows: recurring and rdate series always come back,
 * everything else only when its own dates or instants touch the window. Instants are
 * widened by a day on each side so a timezone never drops an event; `expand` clips.
 */
export async function loadCalendar(
  client: Client,
  from: string,
  to: string,
  timezone: string,
): Promise<{ occurrences: Occurrence[]; busy_until: BusyRow[] }> {
  const instantsFrom = `${addDays(from, -1)}T00:00:00Z`;
  const instantsTo = `${addDays(to, 2)}T00:00:00Z`;
  const { data: eventData, error: eventError } = await client
    .from("events")
    .select("*")
    .or([
      "rrule.not.is.null",
      "rdates.not.is.null",
      `and(start_date.lte.${to},end_date.gte.${from})`,
      `and(starts_at.lt.${instantsTo},ends_at.gt.${instantsFrom})`,
    ].join(","));
  if (eventError) throw eventError;
  const events = (eventData ?? []) as EventRow[];

  let overrides: OverrideRow[] = [];
  if (events.length > 0) {
    const { data, error } = await client
      .from("event_overrides")
      .select("*")
      .in("event_id", events.map((e) => e.id));
    if (error) throw error;
    overrides = (data ?? []) as OverrideRow[];
  }

  const { data: busyData, error: busyError } = await client
    .from("busy_until")
    .select("profile_id, on_date, until")
    .gte("on_date", from)
    .lte("on_date", to);
  if (busyError) throw busyError;

  return {
    occurrences: expand(events, overrides, from, to, timezone),
    busy_until: (busyData ?? []) as BusyRow[],
  };
}
