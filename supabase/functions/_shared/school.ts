// The school timetable projection (specs/15 "Projection: from pattern to occurrences",
// contract school-contract.md "Projection"). Pure: the caller loads the api views
// (school_data.ts), this turns the weekly grid, the term's A/B pattern, the holidays and
// the dated exceptions into one day per child and date, in the shape of the week board's
// SchoolDay JSON (app/lib/features/board/domain/week_board.dart).
//
// The rules run in a fixed order, and the order matters: a holiday removes the grid
// before exceptions are read, so an 'extra' is the only thing that can add a lesson to
// a free day.
import { Temporal } from "npm:temporal-polyfill@0.3.0";
import { addDays } from "./occurrences.ts";
import {
  type HolidayFeedRow,
  holidayName,
  regionCovers,
} from "./openholidays.ts";

// ── view rows (api.* columns, household_id left out) ─────────────────────────────

export type SchoolRow = {
  id: string;
  name: string;
  state_code: string | null;
  /** The OpenHolidays region ("CH-ZH", "DE-BE"); public holidays apply from it. */
  region_code: string | null;
  timezone: string;
  created_at: string;
};

export type PeriodRow = {
  id: string;
  school_id: string;
  index: number;
  label: string | null;
  starts_at: string;
  ends_at: string;
  kind: "lesson" | "break";
};

export type TermRow = {
  id: string;
  school_id: string;
  name: string;
  starts_on: string;
  ends_on: string;
  ab_anchor_week: number | null;
  is_current: boolean;
};

export type SubjectRow = {
  id: string;
  name: string;
  short_name: string;
  tint: string;
  icon_key: string | null;
  equipment_note: string | null;
  notable_default: boolean;
};

export type TimetableRow = {
  id: string;
  profile_id: string;
  school_id: string;
  term_id: string;
  class_label: string | null;
  week_cycle: "weekly" | "ab";
  valid_from: string;
  valid_to: string | null;
  source: "manual" | "imported";
  source_ref: string | null;
  updated_at: string;
};

export type LessonRow = {
  id: string;
  timetable_id: string;
  weekday: number;
  period_index: number | null;
  starts_at: string | null;
  ends_at: string | null;
  subject_id: string | null;
  kind: "lesson" | "care" | "club";
  title: string | null;
  teacher: string | null;
  room: string | null;
  week_parity: "all" | "a" | "b";
  is_notable: boolean;
  note: string | null;
};

export type ExceptionRow = {
  id: string;
  timetable_id: string;
  on_date: string;
  period_index: number | null;
  kind: "cancelled" | "substituted" | "room_change" | "extra";
  subject_id: string | null;
  teacher: string | null;
  room: string | null;
  starts_at: string | null;
  ends_at: string | null;
  note: string | null;
  created_by_profile_id: string;
};

export type HolidayRow = {
  id: string;
  school_id: string | null;
  name: string;
  starts_on: string;
  ends_on: string;
  /** public_holiday: a Feiertag, from the region (api.holiday_feed) or imported by the family. */
  kind: "holiday" | "closure_day" | "public_holiday";
  source: "manual" | "imported";
  source_url: string | null;
  /** The holiday cache row it came from (api.holiday_feed id), when it has one. */
  feed_id: string | null;
};

export type SchoolData = {
  schools: SchoolRow[];
  periods: PeriodRow[];
  terms: TermRow[];
  subjects: SubjectRow[];
  timetables: TimetableRow[];
  lessons: LessonRow[];
  exceptions: ExceptionRow[];
  holidays: HolidayRow[];
};

// ── output (the board's JSON, plus `date` on a school day) ───────────────────────

export type LessonStatus =
  | "normal"
  | "cancelled"
  | "substituted"
  | "room_change"
  | "extra";

export type LessonJson = {
  period: number | null;
  starts: string;
  ends: string;
  subject: string;
  short: string | null;
  room: string | null;
  teacher: string | null;
  tint: string | null;
  kind: "lesson" | "care" | "club";
  status: LessonStatus;
  note: string | null;
  notable: boolean;
  equipment: string | null;
};

export type SchoolDayJson = {
  date: string;
  member_id: string;
  starts: string | null;
  ends: string | null;
  notable: string[];
  care_until: string | null;
  care_label: string | null;
  free: "weekend" | "holiday" | null;
  holiday_name: string | null;
  lessons: LessonJson[];
};

export type PeriodJson = {
  index: number;
  label: string | null;
  starts: string;
  ends: string;
  kind: "lesson" | "break";
};

export type TimetableJson = {
  member_id: string;
  class_label: string | null;
  school_name: string;
  periods: PeriodJson[];
};

/** The internal form of one lesson before exceptions are read: times resolved. */
type Entry = {
  /** The row the entry came from: a timetable lesson or an extra exception. */
  source: string | null;
  period: number | null;
  starts: string;
  ends: string;
  kind: "lesson" | "care" | "club";
  subject: SubjectRow | null;
  title: string | null;
  teacher: string | null;
  room: string | null;
  note: string | null;
  notable: boolean;
  status: LessonStatus;
};

/**
 * The school days of every child with a timetable, for each date in [from, to]
 * (inclusive). One entry per (date, member); a member with no timetable on a date has
 * no entry, which the board reads as "no school data at all".
 */
export function projectSchoolDays(
  data: SchoolData,
  from: string,
  to: string,
): SchoolDayJson[] {
  const out: SchoolDayJson[] = [];
  for (let date = from; date <= to; date = addDays(date, 1)) {
    for (const tt of activeTimetables(data, date)) {
      out.push(projectDay(data, tt, date));
    }
  }
  return out;
}

/**
 * The public holidays that cover each school's region, as holiday rows of that school (kind
 * public_holiday, feed_id set, the name in the household's language). A feed holiday the
 * household already has a row for (same feed_id, household-wide or for this school) is left
 * out: the family's row is the one the projection reads. Schools without a region get none.
 */
export function publicHolidayRows(
  schools: SchoolRow[],
  feed: HolidayFeedRow[],
  holidays: HolidayRow[],
  locale: string,
): HolidayRow[] {
  const out: HolidayRow[] = [];
  for (const school of schools) {
    if (school.region_code === null) continue;
    for (const f of feed) {
      if (f.kind !== "public") continue;
      if (
        !regionCovers(
          school.region_code,
          f.country,
          f.nationwide,
          f.subdivisions,
        )
      ) {
        continue;
      }
      const owned = holidays.some((h) =>
        h.feed_id === f.id &&
        (h.school_id === null || h.school_id === school.id)
      );
      const name = holidayName(f.names, locale);
      if (owned || name === "") continue;
      out.push({
        id: `feed:${f.id}:${school.id}`,
        school_id: school.id,
        name,
        starts_on: f.starts_on,
        ends_on: f.ends_on,
        kind: "public_holiday",
        source: "imported",
        source_url: null,
        feed_id: f.id,
      });
    }
  }
  return out;
}

/** The timetables valid on `on`, one per member, with their school's bell times. */
export function timetablesJson(data: SchoolData, on: string): TimetableJson[] {
  const schools = new Map(data.schools.map((s) => [s.id, s]));
  return activeTimetables(data, on).map((tt) => ({
    member_id: tt.profile_id,
    class_label: tt.class_label,
    school_name: schools.get(tt.school_id)?.name ?? "",
    periods: periodsOf(data, tt.school_id),
  }));
}

/**
 * 'a' or 'b' for a date within a term. The anchor is the Monday of ISO week
 * `ab_anchor_week` in the ISO year of the term's start; the week count from that Monday
 * decides the parity, so the alternation carries across year ends (2026 has 53 ISO
 * weeks, so week numbers alone would not). No anchor: every week is 'a'.
 */
export function abParity(term: TermRow, date: string): "a" | "b" {
  if (term.ab_anchor_week === null) return "a";
  const anchor = mondayOfIsoWeek(
    isoYearOf(term.starts_on),
    term.ab_anchor_week,
  );
  const days = anchor.until(mondayOf(date), { largestUnit: "days" }).days;
  return Math.floor(days / 7) % 2 === 0 ? "a" : "b";
}

// ── which timetables apply ───────────────────────────────────────────────────────

/**
 * One timetable per member valid on `date`: inside its term's range and its own
 * valid_from..valid_to. If two overlap, the one that started later wins, so a new
 * term's grid takes over on its first day. Sorted by member for a stable order.
 */
function activeTimetables(data: SchoolData, date: string): TimetableRow[] {
  const terms = new Map(data.terms.map((t) => [t.id, t]));
  const chosen = new Map<string, TimetableRow>();
  for (const tt of data.timetables) {
    const term = terms.get(tt.term_id);
    if (!term || date < term.starts_on || date > term.ends_on) continue;
    if (date < tt.valid_from) continue;
    if (tt.valid_to !== null && date > tt.valid_to) continue;
    const prev = chosen.get(tt.profile_id);
    if (
      !prev || tt.valid_from > prev.valid_from ||
      (tt.valid_from === prev.valid_from && tt.id > prev.id)
    ) {
      chosen.set(tt.profile_id, tt);
    }
  }
  return [...chosen.values()].sort((a, b) =>
    a.profile_id.localeCompare(b.profile_id)
  );
}

// ── one day ──────────────────────────────────────────────────────────────────────

function projectDay(
  data: SchoolData,
  tt: TimetableRow,
  date: string,
): SchoolDayJson {
  const weekday = Temporal.PlainDate.from(date).dayOfWeek;
  const subjects = new Map(data.subjects.map((s) => [s.id, s]));
  const term = data.terms.find((t) => t.id === tt.term_id)!;

  // 2. A holiday of this school (or of every school) covering the date.
  const holiday = data.holidays.find((h) =>
    (h.school_id === null || h.school_id === tt.school_id) &&
    h.starts_on <= date && date <= h.ends_on
  );
  const extras = data.exceptions
    .filter((x) =>
      x.timetable_id === tt.id && x.on_date === date && x.kind === "extra"
    )
    .sort((a, b) => a.id.localeCompare(b.id));
  const dayRows = data.lessons.filter((l) =>
    l.timetable_id === tt.id && l.weekday === weekday
  );

  const base = { date, member_id: tt.profile_id };
  if (holiday) {
    // Only an extra makes a holiday a school day; the grid does not run.
    const entries = extras.flatMap((x) =>
      extraEntry(data, tt.school_id, subjects, x)
    );
    if (entries.length === 0) {
      return {
        ...base,
        ...emptySpan(),
        free: "holiday",
        holiday_name: holiday.name,
        lessons: [],
      };
    }
    return dayFrom(base, entries);
  }

  // 2 (continued). Weekends are free unless the timetable has a lesson that weekday.
  if (weekday >= 6 && dayRows.length === 0 && extras.length === 0) {
    return {
      ...base,
      ...emptySpan(),
      free: "weekend",
      holiday_name: null,
      lessons: [],
    };
  }

  // 3. The grid of this weekday, filtered by the week's parity. A weekly timetable
  // ignores the parity values.
  const parity = abParity(term, date);
  const entries: Entry[] = [];
  for (const row of dayRows) {
    if (
      tt.week_cycle !== "weekly" && row.week_parity !== "all" &&
      row.week_parity !== parity
    ) {
      continue;
    }
    // 4. Times: the lesson's own override, else the school's lesson period.
    const times = row.starts_at !== null && row.ends_at !== null
      ? { starts: hhmm(row.starts_at), ends: hhmm(row.ends_at) }
      : periodTimes(data, tt.school_id, row.period_index);
    if (times === null) continue;
    entries.push({
      source: row.id,
      period: row.period_index,
      ...times,
      kind: row.kind,
      subject: subjectOf(subjects, row.subject_id),
      title: row.title,
      teacher: row.teacher,
      room: row.room,
      note: row.note,
      notable: row.is_notable,
      status: "normal",
    });
  }

  // 5. Exceptions of this date: cancel, rewrite, or add. Matched by period index.
  for (const x of data.exceptions) {
    if (x.timetable_id !== tt.id || x.on_date !== date) continue;
    if (x.kind === "extra") {
      entries.push(...extraEntry(data, tt.school_id, subjects, x));
      continue;
    }
    if (x.period_index === null) continue;
    for (const entry of entries) {
      if (entry.period !== x.period_index) continue;
      applyException(entry, x, subjects);
    }
  }

  return dayFrom(base, entries);
}

/** Applies one non-extra exception to a lesson. A cancellation is never undone. */
function applyException(
  entry: Entry,
  x: ExceptionRow,
  subjects: Map<string, SubjectRow>,
): void {
  if (x.kind === "cancelled") {
    entry.status = "cancelled";
  } else if (entry.status !== "cancelled") {
    entry.status = x.kind === "substituted" ? "substituted" : "room_change";
  }
  if (x.subject_id !== null) {
    entry.subject = subjectOf(subjects, x.subject_id);
  }
  if (x.teacher !== null) entry.teacher = x.teacher;
  if (x.room !== null) entry.room = x.room;
  if (x.note !== null) entry.note = x.note;
}

/**
 * An extra as a lesson. It needs a subject or the exception has no name to show, and
 * times from its period or its own starts/ends; otherwise it cannot be placed.
 */
function extraEntry(
  data: SchoolData,
  schoolId: string,
  subjects: Map<string, SubjectRow>,
  x: ExceptionRow,
): Entry[] {
  const subject = subjectOf(subjects, x.subject_id);
  if (subject === null) return [];
  const times = x.starts_at !== null && x.ends_at !== null
    ? { starts: hhmm(x.starts_at), ends: hhmm(x.ends_at) }
    : periodTimes(data, schoolId, x.period_index);
  if (times === null) return [];
  return [{
    source: x.id,
    period: x.period_index,
    ...times,
    kind: "lesson",
    subject,
    title: null,
    teacher: x.teacher,
    room: x.room,
    note: x.note,
    notable: subject.notable_default,
    status: "extra",
  }];
}

/**
 * Turns the day's entries into the SchoolDay JSON: the span, notable names, the care
 * row and the lessons in time order. Cancelled rows stay listed but count for nothing
 * else.
 */
function dayFrom(
  base: { date: string; member_id: string },
  entries: Entry[],
): SchoolDayJson {
  const lessons = entries
    .map(toLessonJson)
    .filter((l): l is LessonJson => l !== null)
    .sort(compareLessons);
  const live = lessons.filter((l) => l.status !== "cancelled");
  const school = live.filter((l) => l.kind === "lesson");
  const care = live.filter((l) => l.kind === "care");
  const latestCare = care.reduce<LessonJson | null>(
    (best, l) => (best === null || l.ends > best.ends ? l : best),
    null,
  );
  const notable = [
    ...new Set(live.filter((l) => l.notable).map((l) => l.subject)),
  ];
  return {
    ...base,
    starts: school.length > 0 ? school[0].starts : null,
    ends: school.length > 0 ? school[school.length - 1].ends : null,
    notable,
    care_until: latestCare?.ends ?? null,
    care_label: latestCare?.subject ?? null,
    free: null,
    holiday_name: null,
    lessons,
  };
}

/**
 * The timetable lesson or exception row each projected lesson came from, so the ICS feed
 * can give it a UID that survives edits. Kept beside the JSON, not in it: the board's
 * SchoolDay shape does not change.
 */
const lessonSources = new WeakMap<LessonJson, string>();

export function lessonSourceId(lesson: LessonJson): string | null {
  return lessonSources.get(lesson) ?? null;
}

function toLessonJson(entry: Entry): LessonJson | null {
  const cancelled = entry.status === "cancelled";
  // A care row is named by its title, a lesson by its subject (the title is the
  // fallback for a lesson without one).
  const name = entry.kind === "lesson"
    ? entry.subject?.name ?? entry.title
    : entry.title ?? entry.subject?.name ?? null;
  if (name === null) return null;
  const lesson: LessonJson = {
    period: entry.period,
    starts: entry.starts,
    ends: entry.ends,
    subject: name,
    short: entry.subject?.short_name ?? null,
    room: entry.room,
    teacher: entry.teacher,
    tint: entry.subject?.tint ?? null,
    kind: entry.kind,
    status: entry.status,
    note: entry.note,
    notable: !cancelled && entry.notable,
    equipment: cancelled ? null : entry.subject?.equipment_note ?? null,
  };
  if (entry.source !== null) lessonSources.set(lesson, entry.source);
  return lesson;
}

/** Start, then end, then period, then name: a stable reading order. */
function compareLessons(a: LessonJson, b: LessonJson): number {
  return a.starts.localeCompare(b.starts) ||
    a.ends.localeCompare(b.ends) ||
    (a.period ?? 0) - (b.period ?? 0) ||
    a.subject.localeCompare(b.subject, "de");
}

function emptySpan(): {
  starts: null;
  ends: null;
  notable: string[];
  care_until: null;
  care_label: null;
} {
  return {
    starts: null,
    ends: null,
    notable: [],
    care_until: null,
    care_label: null,
  };
}

// ── lookups ──────────────────────────────────────────────────────────────────────

/** The lesson period with this index, as "HH:MM" times; null when the grid has none. */
function periodTimes(
  data: SchoolData,
  schoolId: string,
  index: number | null,
): { starts: string; ends: string } | null {
  if (index === null) return null;
  const period = data.periods.find((p) =>
    p.school_id === schoolId && p.kind === "lesson" && p.index === index
  );
  return period
    ? { starts: hhmm(period.starts_at), ends: hhmm(period.ends_at) }
    : null;
}

function periodsOf(data: SchoolData, schoolId: string): PeriodJson[] {
  return data.periods
    .filter((p) => p.school_id === schoolId)
    .map((p) => ({
      index: p.index,
      label: p.label,
      starts: hhmm(p.starts_at),
      ends: hhmm(p.ends_at),
      kind: p.kind,
    }))
    .sort((a, b) => a.starts.localeCompare(b.starts));
}

function subjectOf(
  subjects: Map<string, SubjectRow>,
  id: string | null,
): SubjectRow | null {
  return id === null ? null : subjects.get(id) ?? null;
}

/** "08:00:00" (PostgREST's time) → "08:00", the board's `HH:MM`. */
function hhmm(time: string): string {
  return time.slice(0, 5);
}

// ── ISO week arithmetic ──────────────────────────────────────────────────────────

/** The ISO year of a date: the year of its week's Thursday. */
function isoYearOf(date: string): number {
  const d = Temporal.PlainDate.from(date);
  return d.add({ days: 4 - d.dayOfWeek }).year;
}

function mondayOf(date: string): Temporal.PlainDate {
  const d = Temporal.PlainDate.from(date);
  return d.subtract({ days: d.dayOfWeek - 1 });
}

/** The Monday of ISO week `week` of `year`: week 1 is the one holding 4 January. */
function mondayOfIsoWeek(year: number, week: number): Temporal.PlainDate {
  const jan4 = Temporal.PlainDate.from({ year, month: 1, day: 4 });
  const week1 = jan4.subtract({ days: jan4.dayOfWeek - 1 });
  return week1.add({ weeks: week - 1 });
}
