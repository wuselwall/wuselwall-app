// Loads the calendar rows for a window of local dates and expands them. Shared by the
// `occurrences` and `board-week` functions, so both see the same events and overrides.
import {
  type BusyRow,
  type DatedHolidayJson,
  holidaysBetween,
} from "./board.ts";
import { RequestError, type userClient } from "./client.ts";
import {
  addDays,
  type EventRow,
  expand,
  type ExternalOccurrenceRow,
  importedOccurrence,
  type Occurrence,
  type OverrideRow,
  sortOccurrences,
} from "./occurrences.ts";
import type { HolidayRow } from "./school.ts";
import { loadHousehold, loadPublicFeed } from "./school_data.ts";

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
 * The occurrences of every event and imported calendar that can fall in [from, to] (both
 * inclusive local dates in `timezone`) and the busy_until rows of those dates.
 *
 * The SQL filter only narrows the rows: recurring and rdate series always come back,
 * everything else only when its own dates or instants touch the window. Instants are
 * widened by a day on each side so a timezone never drops an event; `expand` clips.
 * Imported occurrences (api.external_occurrences, already expanded) are read by the same
 * window and kept when their local dates touch it. Sorted as one list.
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

  const { data: externalData, error: externalError } = await client
    .from("external_occurrences")
    .select("*")
    .or([
      `and(starts_at.lt.${instantsTo},ends_at.gt.${instantsFrom})`,
      `and(start_date.lte.${to},end_date.gte.${from})`,
    ].join(","));
  if (externalError) throw externalError;
  const imported = ((externalData ?? []) as ExternalOccurrenceRow[])
    .map((row) => importedOccurrence(row, timezone))
    .filter((occ) => occ.local_start_date <= to && occ.local_end_date >= from);

  const { data: busyData, error: busyError } = await client
    .from("busy_until")
    .select("profile_id, on_date, until")
    .gte("on_date", from)
    .lte("on_date", to);
  if (busyError) throw busyError;

  return {
    occurrences: sortOccurrences([
      ...expand(events, overrides, from, to, timezone),
      ...imported,
    ]),
    busy_until: (busyData ?? []) as BusyRow[],
  };
}

/**
 * The public holidays of the local dates `from`..`to`, for the calendar's month view:
 * the family's own household-wide rows (api.school_holidays, kind public_holiday) and the
 * region's cache rows, named in the household's language, as the week board names them.
 */
export async function loadPublicHolidays(
  client: Client,
  from: string,
  to: string,
): Promise<DatedHolidayJson[]> {
  const [household, own] = await Promise.all([
    loadHousehold(client),
    client.from("school_holidays").select("*")
      .eq("kind", "public_holiday")
      .is("school_id", null)
      .lte("starts_on", to).gte("ends_on", from),
  ]);
  if (own.error) throw own.error;
  const feed = household.region === null
    ? []
    : await loadPublicFeed(client, from, to, [household.region]);
  return holidaysBetween(
    from,
    to,
    (own.data ?? []) as HolidayRow[],
    feed,
    household.region,
    household.locale,
  );
}
