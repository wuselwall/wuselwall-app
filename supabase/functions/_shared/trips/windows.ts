// Time windows for a family trip (specs/30 "Time windows"): when could the travellers go?
//
// Pure: the `trips` function loads the household's rows as the caller and hands them over;
// nothing here reads a database, a clock or a provider. Dates are 'YYYY-MM-DD' strings in the
// household's own calendar; day arithmetic is on whole days counted from 1970-01-01.
//
// A day is free for a child when the child has no school: a weekend, a public holiday, or a
// closure day or Ferien row of the child's school (a row without a school applies to every
// school). A child without a school is free every day. When at least one travelling child has
// a school, a window is a maximal run of days that are free for all of those children. When
// none has, the windows are the long weekends: weekends joined with public holidays and at
// most two bridge days between them.
import type { Occurrence } from "../occurrences.ts";

/** The longest answer: later windows are dropped, the list is sorted by start. */
export const MAX_WINDOWS = 60;
/** The most conflicts one window lists. */
export const MAX_CONFLICTS = 20;
/** Working days a long weekend may bridge between a public holiday and a weekend. */
export const MAX_BRIDGE_DAYS = 2;

const DAY_MS = 86_400_000;

export type Traveller = {
  id: string;
  kind: "adult" | "child";
  /** The child's school (from the timetable), or null: free every day. */
  schoolId: string | null;
};

export type HolidayInput = {
  /** null: applies to every school (a household-wide row). */
  schoolId: string | null;
  name: string;
  startsOn: string;
  endsOn: string;
  kind: "holiday" | "closure_day" | "public_holiday";
};

export type PublicHoliday = { date: string; name: string };

/** The part of an expanded calendar row the windows need. */
export type CalendarRow = Pick<
  Occurrence,
  | "id"
  | "event_id"
  | "title"
  | "kind"
  | "presence_state"
  | "status"
  | "local_start_date"
  | "local_end_date"
  | "attendee_ids"
  | "trip_id"
>;

export type WindowInput = {
  from: string;
  to: string;
  minDays: number;
  travellers: Traveller[];
  holidays: HolidayInput[];
  publicHolidays: PublicHoliday[];
  occurrences: CalendarRow[];
  today: string;
  /** A trip whose own calendar entry is no conflict (the trip being planned). */
  ignoreTripId?: string | null;
};

export type Conflict = {
  date: string;
  title: string;
  event_id: string;
  kind: "appointment" | "presence";
  presence_state?: string;
  profile_ids: string[];
};

export type Window = {
  from: string;
  to: string;
  days: number;
  name?: string;
  kind: "holidays" | "long_weekend";
  leave_days: number;
  partial: { profile_id: string; from: string; to: string }[];
  conflicts: Conflict[];
};

/** Presence states that keep a traveller from leaving (home_office and off do not). */
const BLOCKING_PRESENCE = new Set(["working", "travel", "away", "childcare"]);

function dayIndex(date: string): number {
  return Math.round(Date.parse(`${date}T00:00:00Z`) / DAY_MS);
}

function dateOf(index: number): string {
  return new Date(index * DAY_MS).toISOString().slice(0, 10);
}

/** 0 = Monday … 6 = Sunday (1970-01-01 was a Thursday). */
function weekdayOf(index: number): number {
  return (((index + 3) % 7) + 7) % 7;
}

function isWeekend(index: number): boolean {
  return weekdayOf(index) >= 5;
}

function distinct(names: string[]): string | undefined {
  const seen = [...new Set(names.filter((n) => n !== ""))];
  return seen.length === 0 ? undefined : seen.join(" / ");
}

/** The windows of `from`..`to` for the travellers, sorted by start, at most MAX_WINDOWS. */
export function computeWindows(input: WindowInput): Window[] {
  const lo = Math.max(dayIndex(input.from), dayIndex(input.today));
  const hi = dayIndex(input.to);
  if (lo > hi) return [];
  const count = hi - lo + 1;
  const at = (index: number) => index - lo;

  // The household's public holidays by day: the region's, and any household-wide row of
  // the family's own.
  const publicNames = new Map<number, string[]>();
  const addPublic = (index: number, name: string) => {
    if (index < lo || index > hi) return;
    const names = publicNames.get(index) ?? [];
    if (!names.includes(name)) names.push(name);
    publicNames.set(index, names);
  };
  for (const h of input.publicHolidays) addPublic(dayIndex(h.date), h.name);
  for (const h of input.holidays) {
    if (h.kind !== "public_holiday" || h.schoolId !== null) continue;
    for (let i = dayIndex(h.startsOn); i <= dayIndex(h.endsOn); i++) {
      addPublic(i, h.name);
    }
  }

  const off = new Uint8Array(count); // weekend or public holiday
  for (let i = lo; i <= hi; i++) {
    if (isWeekend(i) || publicNames.has(i)) off[at(i)] = 1;
  }

  const travellerIds = input.travellers.map((t) => t.id);
  const schoolChildren = input.travellers.filter((t) =>
    t.kind === "child" && t.schoolId !== null
  );

  const finish = (
    first: number,
    last: number,
    kind: Window["kind"],
    name: string | undefined,
    partial: Window["partial"],
  ): Window => {
    let leave = 0;
    for (let i = first; i <= last; i++) {
      if (!isWeekend(i) && !publicNames.has(i)) leave++;
    }
    return {
      from: dateOf(first),
      to: dateOf(last),
      days: last - first + 1,
      ...(name === undefined ? {} : { name }),
      kind,
      leave_days: leave,
      partial,
      conflicts: [],
    };
  };

  let windows: { window: Window; first: number; last: number }[] = [];

  if (schoolChildren.length > 0) {
    // Free days per child.
    const freeByChild = new Map<string, Uint8Array>();
    for (const child of schoolChildren) {
      const free = Uint8Array.from(off);
      for (const h of input.holidays) {
        if (h.schoolId !== null && h.schoolId !== child.schoolId) continue;
        const a = Math.max(dayIndex(h.startsOn), lo);
        const b = Math.min(dayIndex(h.endsOn), hi);
        for (let i = a; i <= b; i++) free[at(i)] = 1;
      }
      freeByChild.set(child.id, free);
    }
    const common = new Uint8Array(count).fill(1);
    for (const free of freeByChild.values()) {
      for (let i = 0; i < count; i++) common[i] &= free[i];
    }
    const schools = new Set(schoolChildren.map((c) => c.schoolId));

    for (let i = 0; i < count; i++) {
      if (!common[i]) continue;
      let j = i;
      while (j + 1 < count && common[j + 1]) j++;
      const first = lo + i;
      const last = lo + j;
      i = j;
      if (last - first + 1 < input.minDays) continue;

      // Where the children's Ferien differ, the days only some have.
      const partial: Window["partial"] = [];
      for (const child of schoolChildren) {
        const free = freeByChild.get(child.id)!;
        let a = at(first);
        let b = at(last);
        while (a > 0 && free[a - 1]) a--;
        while (b < count - 1 && free[b + 1]) b++;
        if (a < at(first) || b > at(last)) {
          partial.push({
            profile_id: child.id,
            from: dateOf(lo + a),
            to: dateOf(lo + b),
          });
        }
      }

      // The Ferien the run lies in; failing that closure days, failing that holidays.
      const touching = input.holidays
        .filter((h) =>
          (h.schoolId === null || schools.has(h.schoolId)) &&
          dayIndex(h.startsOn) <= last && dayIndex(h.endsOn) >= first &&
          dayIndex(h.endsOn) >= dayIndex(h.startsOn)
        )
        .sort((a, b) =>
          a.startsOn.localeCompare(b.startsOn) || a.name.localeCompare(b.name)
        );
      const namesOf = (kind: HolidayInput["kind"]) =>
        distinct(touching.filter((h) => h.kind === kind).map((h) => h.name));
      let name = namesOf("holiday") ?? namesOf("closure_day");
      if (name === undefined) {
        const names: string[] = [];
        for (let d = first; d <= last; d++) {
          names.push(...(publicNames.get(d) ?? []));
        }
        name = distinct(names);
      }
      windows.push({
        window: finish(first, last, "holidays", name, partial),
        first,
        last,
      });
    }
  } else {
    // Long weekends: the runs of weekend and public holiday, chained over bridge days.
    const runs: { first: number; last: number }[] = [];
    for (let i = 0; i < count; i++) {
      if (!off[i]) continue;
      let j = i;
      while (j + 1 < count && off[j + 1]) j++;
      runs.push({ first: lo + i, last: lo + j });
      i = j;
    }
    const chains: { first: number; last: number }[] = [];
    for (let a = 0; a < runs.length; a++) {
      let b = a;
      let bridge = 0;
      while (b + 1 < runs.length) {
        const gap = runs[b + 1].first - runs[b].last - 1;
        if (gap > MAX_BRIDGE_DAYS || bridge + gap > MAX_BRIDGE_DAYS) break;
        bridge += gap;
        b++;
      }
      chains.push({ first: runs[a].first, last: runs[b].last });
    }
    // A chain inside another is the same long weekend with fewer days.
    const kept = chains.filter((c, k) =>
      !chains.some((o, m) =>
        m !== k && o.first <= c.first && o.last >= c.last &&
        (o.first < c.first || o.last > c.last || m < k)
      )
    );
    for (const c of kept) {
      if (c.last - c.first + 1 < input.minDays) continue;
      const names: string[] = [];
      for (let d = c.first; d <= c.last; d++) {
        names.push(...(publicNames.get(d) ?? []));
      }
      windows.push({
        window: finish(c.first, c.last, "long_weekend", distinct(names), []),
        first: c.first,
        last: c.last,
      });
    }
  }

  windows.sort((a, b) => a.first - b.first || a.last - b.last);
  windows = windows.slice(0, MAX_WINDOWS);

  const relevant = conflictRows(input, travellerIds);
  return windows.map(({ window, first, last }) => ({
    ...window,
    conflicts: conflictsIn(relevant, dateOf(first), dateOf(last)),
  }));
}

type ConflictRow = { row: CalendarRow; profileIds: string[] };

/**
 * The calendar rows that can keep a traveller from leaving: appointments (confirmed or
 * tentative) and presence entries of a blocking state, that concern a traveller. An
 * appointment without attendees is the whole family's; a presence entry without attendees
 * belongs to nobody (the board draws none either).
 */
function conflictRows(
  input: WindowInput,
  travellerIds: string[],
): ConflictRow[] {
  const travelling = new Set(travellerIds);
  const out: ConflictRow[] = [];
  for (const row of input.occurrences) {
    if (input.ignoreTripId && row.trip_id === input.ignoreTripId) continue;
    if (row.kind === "presence") {
      if (
        row.presence_state === null ||
        !BLOCKING_PRESENCE.has(row.presence_state)
      ) continue;
      if (row.attendee_ids.length === 0) continue;
    }
    const profileIds = row.attendee_ids.length === 0
      ? travellerIds
      : row.attendee_ids.filter((id) => travelling.has(id));
    if (profileIds.length === 0) continue;
    out.push({ row, profileIds });
  }
  return out;
}

function conflictsIn(
  rows: ConflictRow[],
  from: string,
  to: string,
): Conflict[] {
  const found = rows
    .filter(({ row }) =>
      row.local_start_date <= to && row.local_end_date >= from
    )
    .map(({ row, profileIds }): Conflict => ({
      date: row.local_start_date > from ? row.local_start_date : from,
      title: row.title,
      event_id: row.event_id,
      kind: row.kind,
      ...(row.kind === "presence" && row.presence_state !== null
        ? { presence_state: row.presence_state }
        : {}),
      profile_ids: profileIds,
    }));
  // Sorted by date; the calendar's own order breaks ties (the sort is stable).
  found.sort((a, b) => a.date.localeCompare(b.date));
  return found.slice(0, MAX_CONFLICTS);
}
