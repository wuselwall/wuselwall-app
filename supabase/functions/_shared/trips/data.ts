// What the `windows` action reads, always through the caller's client so RLS decides what is
// visible (ADR-010): the household's members and schools, the Ferien and public holidays of
// the range, and the calendar rows of the range, expanded in chunks the way the `occurrences`
// function does. Everything else about windows is pure (windows.ts).
import { Temporal } from "npm:temporal-polyfill@0.3.0";
import { holidaysBetween } from "../board.ts";
import { loadCalendar, MAX_WINDOW_DAYS } from "../calendar_data.ts";
import { RequestError, type userClient } from "../client.ts";
import type { HolidayFeedRow } from "../openholidays.ts";
import { addDays, type Occurrence, sortOccurrences } from "../occurrences.ts";
import {
  type HolidayRow,
  publicHolidayRows,
  type SchoolRow,
} from "../school.ts";
import { loadHousehold, loadPublicFeed } from "../school_data.ts";
import { parseWindowsRequest } from "./request.ts";
import {
  computeWindows,
  type HolidayInput,
  type Traveller,
  type Window,
} from "./windows.ts";

type Client = ReturnType<typeof userClient>;

/** Chunks of the calendar read at once. */
const CHUNKS_AT_ONCE = 3;

type MemberRow = { id: string; kind: "adult" | "child"; active: boolean };

export type TimetableSpan = {
  profile_id: string;
  school_id: string;
  valid_from: string;
  valid_to: string | null;
};

/** Today's date in a timezone ('YYYY-MM-DD'). */
export function todayIn(timezone: string, now: Date): string {
  return Temporal.Instant.fromEpochMilliseconds(now.getTime())
    .toZonedDateTimeISO(timezone).toPlainDate().toString();
}

/** `from`..`to` cut into inclusive ranges of at most `size` days. */
export function chunksOf(
  from: string,
  to: string,
  size = MAX_WINDOW_DAYS,
): { from: string; to: string }[] {
  const out: { from: string; to: string }[] = [];
  for (let a = from; a <= to; a = addDays(a, size)) {
    const b = addDays(a, size - 1);
    out.push({ from: a, to: b < to ? b : to });
  }
  return out;
}

/**
 * The school a child goes to: the timetable valid today (the latest start if several), else
 * the next one to start, else the latest that ended. null: the child has no timetable.
 */
export function schoolOf(
  profileId: string,
  timetables: TimetableSpan[],
  today: string,
): string | null {
  const own = timetables.filter((t) => t.profile_id === profileId);
  const pick = (rows: TimetableSpan[], latest: boolean) =>
    [...rows].sort((a, b) =>
      (latest ? -1 : 1) * a.valid_from.localeCompare(b.valid_from) ||
      a.school_id.localeCompare(b.school_id)
    )[0];
  const current = own.filter((t) =>
    t.valid_from <= today && (t.valid_to === null || t.valid_to >= today)
  );
  if (current.length > 0) return pick(current, true).school_id;
  const upcoming = own.filter((t) => t.valid_from > today);
  if (upcoming.length > 0) return pick(upcoming, false).school_id;
  return own.length > 0 ? pick(own, true).school_id : null;
}

/** Rows seen in several chunks (a row spanning two) once, in the calendar's order. */
export function mergeChunks(chunks: Occurrence[][]): Occurrence[] {
  const seen = new Map<string, Occurrence>();
  for (const chunk of chunks) {
    for (const occ of chunk) if (!seen.has(occ.id)) seen.set(occ.id, occ);
  }
  return sortOccurrences([...seen.values()]);
}

/** The rows of one query, or its error thrown. */
async function rows<T>(
  query: PromiseLike<{ data: unknown[] | null; error: unknown }>,
): Promise<T[]> {
  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as T[];
}

/**
 * The windows a request body asks for. The body is validated here, after the household's
 * timezone is known: the defaults (from today, 18 months) are relative to its today.
 */
export async function loadWindows(
  client: Client,
  body: Record<string, unknown>,
  now: Date,
): Promise<Window[]> {
  const [households, members] = await Promise.all([
    rows<{ timezone: string }>(client.from("household").select("timezone")),
    rows<MemberRow>(client.from("members").select("id, kind, active")),
  ]);
  const timezone = households[0]?.timezone ?? "UTC";
  const today = todayIn(timezone, now);
  const request = parseWindowsRequest(body, today);

  // The travellers: the ids named (all must be profiles of the household), else the active members.
  let chosen: MemberRow[];
  if (request.memberIds === null) {
    chosen = members.filter((m) => m.active);
  } else {
    const byId = new Map(members.map((m) => [m.id, m]));
    const unknown = request.memberIds.filter((id) => !byId.has(id));
    if (unknown.length > 0) {
      throw new RequestError(
        400,
        "invalid_request",
        "member_ids names a profile that is not in the household",
      );
    }
    chosen = request.memberIds.map((id) => byId.get(id)!);
  }

  // Nothing before today is a window; the range starts there.
  const lo = request.from > today ? request.from : today;
  if (lo > request.to) return [];

  const [timetables, schools, own, household] = await Promise.all([
    rows<TimetableSpan>(
      client.from("timetables")
        .select("profile_id, school_id, valid_from, valid_to"),
    ),
    rows<SchoolRow>(client.from("schools").select("*")),
    rows<HolidayRow>(
      client.from("school_holidays").select("*")
        .lte("starts_on", request.to).gte("ends_on", lo),
    ),
    loadHousehold(client),
  ]);
  const regions = [
    ...schools.map((s) => s.region_code),
    household.region,
  ].filter((r): r is string => r !== null);
  const feed: HolidayFeedRow[] = await loadPublicFeed(
    client,
    lo,
    request.to,
    regions,
  );

  const travellers: Traveller[] = chosen.map((m) => ({
    id: m.id,
    kind: m.kind,
    schoolId: m.kind === "child" ? schoolOf(m.id, timetables, today) : null,
  }));
  const holidays: HolidayInput[] = [
    ...own,
    ...publicHolidayRows(schools, feed, own, household.locale),
  ].map((h) => ({
    schoolId: h.school_id,
    name: h.name,
    startsOn: h.starts_on,
    endsOn: h.ends_on,
    kind: h.kind,
  }));
  const publicHolidays = holidaysBetween(
    lo,
    request.to,
    own,
    feed,
    household.region,
    household.locale,
  ).map((h) => ({ date: h.date, name: h.name }));

  const ranges = chunksOf(lo, request.to);
  const chunks: Occurrence[][] = [];
  for (let i = 0; i < ranges.length; i += CHUNKS_AT_ONCE) {
    const batch = await Promise.all(
      ranges.slice(i, i + CHUNKS_AT_ONCE).map((r) =>
        loadCalendar(client, r.from, r.to, timezone).then((c) => c.occurrences)
      ),
    );
    chunks.push(...batch);
  }

  return computeWindows({
    from: request.from,
    to: request.to,
    minDays: request.minDays,
    travellers,
    holidays,
    publicHolidays,
    occurrences: mergeChunks(chunks),
    today,
    ignoreTripId: request.tripId,
  });
}
