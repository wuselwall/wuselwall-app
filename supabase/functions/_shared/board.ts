// Fills the calendar parts of the week board (specs/09 "The week board"): presence
// bands, the day's appointments and the "Termine bis" times. Pure: the caller loads
// the occurrences and busy rows, this only shapes them into the WeekBoard JSON that
// app/lib/features/board/domain/week_board.dart reads.
import { addDays, type Occurrence } from "./occurrences.ts";
import {
  type HolidayFeedRow,
  holidayName,
  regionCovers,
} from "./openholidays.ts";
import type { HolidayRow, SchoolDayJson, TimetableJson } from "./school.ts";
import { usualDay, type UsualJson, type UsualWeekRow } from "./usual_week.ts";

/** A row of `api.busy_until` (profile_id, on_date, until). */
export type BusyRow = { profile_id: string; on_date: string; until: string };

export type PresenceBandJson = {
  id: string;
  member_id: string;
  state: string;
  label: string;
  first_day: string;
  last_day: string;
  starts: string | null;
  ends: string | null;
  tentative: boolean;
  starts_before_week: boolean;
  ends_after_week: boolean;
};

export type BoardEventJson = {
  id: string;
  title: string;
  location: string | null;
  starts: string | null;
  ends: string | null;
  attendee_ids: string[];
  tentative: boolean;
  key: boolean;
  /** Only when set (specs/27): a family tradition, and the event's content icon. */
  tradition?: true;
  icon_key?: string;
};

export type BusyUntilJson = { member_id: string; until: string };

/** A public holiday on a day: from the household's own rows, or the region's cache. */
export type DayHolidayJson = {
  name: string;
  source: "region" | "household";
};

export type BoardDayJson = {
  date: string;
  events: BoardEventJson[];
  busy_until: BusyUntilJson[];
  school?: SchoolDayJson[];
  /** null on an ordinary day; absent from servers before public holidays. */
  holiday?: DayHolidayJson | null;
  /** Each member's usual places; absent from servers before the usual week (issue #81). */
  usual?: UsualJson[];
  [key: string]: unknown;
};

/** The `api.board_week` result; the untouched parts pass through as they are. */
export type BoardJson = {
  week_start: string;
  timezone?: string;
  days: BoardDayJson[];
  presence: PresenceBandJson[];
  [key: string]: unknown;
};

/**
 * Returns a new board with `presence`, `days[].events` and `days[].busy_until` filled.
 * `base` is not mutated. `occurrences` should cover the board's week; occurrences
 * outside it are ignored for presence and simply never match a day.
 */
export function fillBoard(
  base: BoardJson,
  occurrences: Occurrence[],
  busy: BusyRow[],
): BoardJson {
  const weekStart = base.week_start;
  const weekEnd = addDays(weekStart, 6);

  const presence: PresenceBandJson[] = [];
  const appointments: Occurrence[] = [];
  for (const occ of occurrences) {
    if (occ.kind === "presence") {
      presence.push(...bandsOf(occ, weekStart, weekEnd));
    } else if (occ.source === "imported" && occ.importance !== "key") {
      // An imported calendar reaches the board only when it is set to show there, and then as
      // key appointments (specs/09, FR-1.9). Its other occurrences stay in the calendar only.
      continue;
    } else {
      appointments.push(occ);
    }
  }

  const days = base.days.map((day) => ({
    ...day,
    events: eventsOn(appointments, day.date),
    busy_until: busy
      .filter((row) => row.on_date === day.date)
      .map((row) => ({ member_id: row.profile_id, until: hhmm(row.until) })),
  }));

  return { ...base, presence, days };
}

/**
 * Returns a new board whose every day has `holiday` filled: the household's own public
 * holiday row covering the day (source household) first, else the cache's public holiday
 * covering the household's region (source region, named in the household's language).
 * `base` is not mutated.
 */
export function fillHolidays(
  base: BoardJson,
  holidays: HolidayRow[],
  feed: HolidayFeedRow[],
  region: string | null,
  locale: string,
): BoardJson {
  return {
    ...base,
    days: base.days.map((day) => ({
      ...day,
      holiday: holidayOn(day.date, holidays, feed, region, locale),
    })),
  };
}

/**
 * Returns a new board whose every day has `usual` filled from the members' usual weeks
 * (usual_week.ts), in the board's member order. Call it after fillHolidays: a public
 * holiday has no usual place. `base` is not mutated.
 */
export function fillUsual(base: BoardJson, weeks: UsualWeekRow[]): BoardJson {
  const memberIds = ((base.members ?? []) as { id: string }[]).map((m) => m.id);
  return {
    ...base,
    days: base.days.map((day) => ({
      ...day,
      usual: usualDay(weeks, memberIds, day.date, day.holiday != null),
    })),
  };
}

/** The public holiday of a date (see fillHolidays), also for callers outside the board. */
export function holidayOn(
  date: string,
  holidays: HolidayRow[],
  feed: HolidayFeedRow[],
  region: string | null,
  locale: string,
): DayHolidayJson | null {
  const own = holidays.find((h) =>
    h.school_id === null && h.kind === "public_holiday" &&
    h.starts_on <= date && date <= h.ends_on
  );
  if (own) return { name: own.name, source: "household" };
  if (region === null) return null;
  for (const f of feed) {
    if (f.kind !== "public" || date < f.starts_on || date > f.ends_on) continue;
    if (!regionCovers(region, f.country, f.nationwide, f.subdivisions)) {
      continue;
    }
    const name = holidayName(f.names, locale);
    if (name !== "") return { name, source: "region" };
  }
  return null;
}

/** A public holiday on one date of a window, for the calendar's month view. */
export type DatedHolidayJson = DayHolidayJson & { date: string };

/**
 * The public holidays of the local dates `from`..`to` (inclusive), one entry per date
 * that has one, by the rule of holidayOn: the family's own row first, else the region's.
 */
export function holidaysBetween(
  from: string,
  to: string,
  holidays: HolidayRow[],
  feed: HolidayFeedRow[],
  region: string | null,
  locale: string,
): DatedHolidayJson[] {
  const out: DatedHolidayJson[] = [];
  for (let date = from; date <= to; date = addDays(date, 1)) {
    const holiday = holidayOn(date, holidays, feed, region, locale);
    if (holiday) out.push({ date, ...holiday });
  }
  return out;
}

/**
 * Returns a new board with `timetables` and each day's `school` filled from the school
 * projection (school.ts). `days` is the projected school days of the board's week, one
 * per child with a timetable; a day with none keeps an empty list, which the board
 * reads as "no school data at all". `base` is not mutated.
 */
export function fillSchool(
  base: BoardJson,
  days: SchoolDayJson[],
  timetables: TimetableJson[],
): BoardJson {
  return {
    ...base,
    timetables,
    days: base.days.map((day) => ({
      ...day,
      school: days.filter((s) => s.date === day.date),
    })),
  };
}

/** One band per attendee, clipped to the week and flagged where it continues. */
function bandsOf(
  occ: Occurrence,
  weekStart: string,
  weekEnd: string,
): PresenceBandJson[] {
  const state = occ.presence_state;
  if (state === null || occ.attendee_ids.length === 0) return [];

  const firstDay = maxOf(occ.local_start_date, weekStart);
  const lastDay = minOf(occ.local_end_date, weekEnd);
  if (firstDay > lastDay) return [];

  // Times only mean something on a band that lies on one day; a multi-day or
  // all-day band is drawn as days.
  const oneDay = !occ.all_day && occ.local_start_date === occ.local_end_date;

  return occ.attendee_ids.map((memberId) => ({
    id: `${occ.id}|${memberId}`,
    member_id: memberId,
    state,
    label: occ.title,
    first_day: firstDay,
    last_day: lastDay,
    starts: oneDay ? occ.local_starts : null,
    ends: oneDay ? occ.local_ends : null,
    tentative: occ.status === "tentative",
    starts_before_week: occ.local_start_date < weekStart,
    ends_after_week: occ.local_end_date > weekEnd,
  }));
}

/**
 * The appointments of one day. An all-day event is on every day it covers; a timed
 * event is on its local start date only, with its times.
 */
function eventsOn(appointments: Occurrence[], date: string): BoardEventJson[] {
  const out: BoardEventJson[] = [];
  for (const occ of appointments) {
    const onStartDay = occ.local_start_date === date;
    const covers = occ.all_day
      ? occ.local_start_date <= date && date <= occ.local_end_date
      : onStartDay;
    if (!covers) continue;
    const timed = !occ.all_day && onStartDay;
    out.push({
      id: occ.id,
      title: occ.title,
      location: occ.location,
      starts: timed ? occ.local_starts : null,
      ends: timed ? occ.local_ends : null,
      attendee_ids: occ.attendee_ids,
      tentative: occ.status === "tentative",
      key: occ.importance === "key",
      ...(occ.tradition ? { tradition: true as const } : {}),
      ...(occ.icon_key ? { icon_key: occ.icon_key } : {}),
    });
  }
  return out.sort(compareEvents);
}

/** All-day first, then by start time, then title, then id for a stable order. */
function compareEvents(a: BoardEventJson, b: BoardEventJson): number {
  const allDayA = a.starts === null ? 0 : 1;
  const allDayB = b.starts === null ? 0 : 1;
  return (
    allDayA - allDayB ||
    (a.starts ?? "").localeCompare(b.starts ?? "") ||
    a.title.localeCompare(b.title, "de") ||
    a.id.localeCompare(b.id)
  );
}

/** "17:00:00" → "17:00" (the board's `HH:MM`). */
function hhmm(until: string): string {
  return until.slice(0, 5);
}

function maxOf(a: string, b: string): string {
  return a > b ? a : b;
}

function minOf(a: string, b: string): string {
  return a < b ? a : b;
}

// ── the meal zone (specs/09 "The week board", contract "The board's meal zone") ──

/** The household settings the meal zone reads (specs/21 "Meals (M1.4)"). */
export type MealSettings = {
  schoolDaySlot: MealSlotName;
  freeDaySlot: MealSlotName;
  awayMeansNotEating: boolean;
  /** "HH:MM": a child whose care runs past this is out of school-day lunch. */
  careLunchCutoff: string;
};

export type MealSlotName = "lunch" | "dinner";

/** The columns of `api.meal_plan_entries` the board reads. */
export type MealEntryRow = {
  on_date: string;
  slot: string;
  title: string | null;
  cook_profile_id: string | null;
  at_time: string | null;
  guests: number;
  eating_overrides: Record<string, boolean> | null;
  /** A child's meal wish (specs/27); absent before 20261024110000. */
  wished_by_profile_id?: string | null;
};

/** The members the eating rule walks, in household order. */
export type MealMember = { id: string; kind: string };

export type MealInput = {
  /** The week's meal entries (any slots; only the board's warm slot is used). */
  entries: MealEntryRow[];
  settings: MealSettings;
  /** The week's occurrences; only the presence ones matter here. */
  presence: Occurrence[];
  /** The projected school days of the week, one per child with a timetable. */
  schoolDays: SchoolDayJson[];
  members: MealMember[];
};

/** `days[i].meal` of the board (the BoardMeal read model). */
export type MealJson = {
  slot: MealSlotName;
  time: string | null;
  title: string | null;
  cook_id: string | null;
  eating: string[];
  guests: number;
  /** Only when the meal is someone's wish (specs/27). */
  wished_by?: string;
};

/** Where a meal without a set time falls for the presence and care rules. */
const DEFAULT_MEAL_TIME: Record<MealSlotName, string> = {
  lunch: "12:30",
  dinner: "18:30",
};

/** Presence states that take a member away from the table. */
const AWAY_STATES = new Set(["travel", "away"]);

/**
 * Returns a new board whose every day has `meal` filled. The slot is dinner on a school
 * day (Mon–Fri, not a holiday for a child with a timetable) and the free-day slot
 * otherwise. Eating is every member, minus those away at the meal time (when the setting
 * says so) and, at school-day lunch, children in care past the cutoff; then the entry's
 * eating_overrides apply (true adds, false removes). `base` is not mutated.
 */
export function fillMeals(base: BoardJson, input: MealInput): BoardJson {
  const { entries, settings, schoolDays, members } = input;
  const away = input.presence.filter((o) =>
    o.kind === "presence" &&
    o.presence_state !== null &&
    AWAY_STATES.has(o.presence_state)
  );

  return {
    ...base,
    days: base.days.map((day) => {
      const date = day.date;
      // A public holiday of the household's region is a free day too, for everyone.
      const school = day.holiday == null && isSchoolDay(date, schoolDays);
      const slot = school ? settings.schoolDaySlot : settings.freeDaySlot;
      const entry = entries.find((e) => e.on_date === date && e.slot === slot);
      const time = entry?.at_time ? hhmm(entry.at_time) : null;
      const mealTime = time ?? DEFAULT_MEAL_TIME[slot];

      const eating = new Set<string>();
      for (const member of members) {
        if (
          settings.awayMeansNotEating &&
          away.some((o) =>
            o.attendee_ids.includes(member.id) && coversTime(o, date, mealTime)
          )
        ) {
          continue;
        }
        if (
          school && slot === "lunch" && member.kind === "child" &&
          schoolDays.some((s) =>
            s.member_id === member.id && s.date === date &&
            s.care_until !== null && s.care_until > settings.careLunchCutoff
          )
        ) {
          continue;
        }
        eating.add(member.id);
      }
      const known = new Set(members.map((m) => m.id));
      for (const [id, value] of Object.entries(entry?.eating_overrides ?? {})) {
        if (!known.has(id)) continue;
        if (value) eating.add(id);
        else eating.delete(id);
      }

      const meal: MealJson = {
        slot,
        time,
        title: entry?.title ?? null,
        cook_id: entry?.cook_profile_id ?? null,
        eating: members.filter((m) => eating.has(m.id)).map((m) => m.id),
        guests: entry?.guests ?? 0,
        ...(entry?.wished_by_profile_id
          ? { wished_by: entry.wished_by_profile_id }
          : {}),
      };
      return { ...day, meal };
    }),
  };
}

/**
 * Mon–Fri, and no child with a timetable has a holiday that day (no timetables: Mon–Fri).
 * The caller also treats a public holiday of the household's region as a free day.
 */
function isSchoolDay(date: string, schoolDays: SchoolDayJson[]): boolean {
  const weekday = new Date(`${date}T00:00:00Z`).getUTCDay();
  if (weekday === 0 || weekday === 6) return false;
  return !schoolDays.some((s) => s.date === date && s.free === "holiday");
}

/**
 * Whether an occurrence is under way at local time `time` ("HH:MM") on `date`. All-day
 * bands cover the whole day; a timed band covers its times on its first and last day
 * and the whole of the days between.
 */
function coversTime(occ: Occurrence, date: string, time: string): boolean {
  if (date < occ.local_start_date || date > occ.local_end_date) return false;
  if (occ.all_day || occ.local_starts === null) return true;
  const from = date === occ.local_start_date ? hhmm(occ.local_starts) : "00:00";
  const to = date === occ.local_end_date && occ.local_ends !== null
    ? hhmm(occ.local_ends)
    : "24:00";
  return from <= time && time < to;
}
