import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import {
  abParity,
  type ExceptionRow,
  type HolidayRow,
  type LessonRow,
  type PeriodRow,
  projectSchoolDays,
  publicHolidayRows,
  type SchoolData,
  type SchoolDayJson,
  type SchoolRow,
  type SubjectRow,
  type TimetableRow,
  timetablesJson,
} from "./school.ts";
import type { HolidayFeedRow } from "./openholidays.ts";

// Fixtures use the api views' shapes ('HH:MM:SS' times, 'YYYY-MM-DD' dates) and
// neutral names. Dates: 2026-09-07 is the Monday of ISO week 37 (the anchor week);
// 2026-10-12 is Monday of week 42, five weeks after it. Expectations are computed by
// hand in the comments.

const SCHOOL = "school1";
const TERM = "term1";
const KID = "kid1";
const KID2 = "kid2";
const TT = "tt-kid1";
const TT2 = "tt-kid2";

function period(
  index: number,
  kind: "lesson" | "break",
  starts: string,
  ends: string,
): PeriodRow {
  return {
    id: `p-${kind}-${index}`,
    school_id: SCHOOL,
    index,
    label: null,
    starts_at: `${starts}:00`,
    ends_at: `${ends}:00`,
    kind,
  };
}

// Bell times as the school's template: 45-minute lessons, 5-minute and 20-minute breaks.
const PERIODS: PeriodRow[] = [
  period(1, "lesson", "08:00", "08:45"),
  period(1, "break", "08:45", "08:50"),
  period(2, "lesson", "08:50", "09:35"),
  period(2, "break", "09:35", "09:55"),
  period(3, "lesson", "09:55", "10:40"),
  period(3, "break", "10:40", "10:45"),
  period(4, "lesson", "10:45", "11:30"),
  period(4, "break", "11:30", "11:50"),
  period(5, "lesson", "11:50", "12:35"),
  period(5, "break", "12:35", "12:40"),
  period(6, "lesson", "12:40", "13:25"),
];

function subject(
  id: string,
  name: string,
  short: string,
  tint: string,
  extra: Partial<SubjectRow> = {},
): SubjectRow {
  return {
    id,
    name,
    short_name: short,
    tint,
    icon_key: null,
    equipment_note: null,
    notable_default: false,
    ...extra,
  };
}

const SUBJECTS: SubjectRow[] = [
  subject("deutsch", "Deutsch", "D", "rose"),
  subject("mathe", "Mathematik", "Ma", "blue"),
  subject("sport", "Sport", "Sp", "peach", {
    equipment_note: "Sportsachen",
    notable_default: true,
  }),
  subject("musik", "Musik", "Mu", "lemon"),
  subject("schwimmen", "Schwimmen", "Sw", "peach", {
    equipment_note: "Schwimmsachen",
    notable_default: true,
  }),
];

function lesson(
  id: string,
  weekday: number,
  subjectId: string | null,
  extra: Partial<LessonRow> = {},
): LessonRow {
  return {
    id,
    timetable_id: TT,
    weekday,
    period_index: null,
    starts_at: null,
    ends_at: null,
    subject_id: subjectId,
    kind: "lesson",
    title: null,
    teacher: null,
    room: null,
    week_parity: "all",
    is_notable: false,
    note: null,
    ...extra,
  };
}

function timetable(
  id: string,
  profile: string,
  extra: Partial<TimetableRow> = {},
): TimetableRow {
  return {
    id,
    profile_id: profile,
    school_id: SCHOOL,
    term_id: TERM,
    class_label: "2b",
    week_cycle: "weekly",
    valid_from: "2026-09-01",
    valid_to: null,
    source: "manual",
    source_ref: null,
    updated_at: "2026-09-01T00:00:00Z",
    ...extra,
  };
}

function exception(
  id: string,
  onDate: string,
  kind: ExceptionRow["kind"],
  extra: Partial<ExceptionRow> = {},
): ExceptionRow {
  return {
    id,
    timetable_id: TT,
    on_date: onDate,
    period_index: null,
    kind,
    subject_id: null,
    teacher: null,
    room: null,
    starts_at: null,
    ends_at: null,
    note: null,
    created_by_profile_id: KID,
    ...extra,
  };
}

function holiday(
  id: string,
  name: string,
  startsOn: string,
  endsOn: string,
  schoolId: string | null = SCHOOL,
): HolidayRow {
  return {
    id,
    school_id: schoolId,
    name,
    starts_on: startsOn,
    ends_on: endsOn,
    kind: "holiday",
    source: "manual",
    source_url: null,
    feed_id: null,
  };
}

/** The base household: one school, one term, one child with Mon–Fri p1 and p2. */
function data(over: Partial<SchoolData> = {}): SchoolData {
  const weekdayLessons: LessonRow[] = [1, 2, 3, 4, 5].flatMap((wd) => [
    lesson(`mo${wd}`, wd, "mathe", { period_index: 1 }),
    lesson(`de${wd}`, wd, "deutsch", { period_index: 2 }),
  ]);
  return {
    schools: [{
      id: SCHOOL,
      name: "Grundschule Musterweg",
      state_code: "DE-BE",
      region_code: "DE-BE",
      timezone: "Europe/Berlin",
      created_at: "2026-09-01T00:00:00Z",
    }],
    periods: PERIODS,
    terms: [{
      id: TERM,
      school_id: SCHOOL,
      name: "Herbst 2026",
      starts_on: "2026-09-01",
      ends_on: "2027-01-31",
      ab_anchor_week: 37,
      is_current: true,
    }],
    subjects: SUBJECTS,
    timetables: [timetable(TT, KID)],
    lessons: weekdayLessons,
    exceptions: [],
    holidays: [],
    ...over,
  };
}

/** The one school day of a child on a date; fails the test when there is none. */
function dayOf(
  d: SchoolData,
  date: string,
  member = KID,
): SchoolDayJson {
  const found = projectSchoolDays(d, date, date).find((x) =>
    x.member_id === member
  );
  assert(found, `no school day for ${member} on ${date}`);
  return found;
}

// Monday 2026-10-12 .. Friday 2026-10-16, Saturday 17, Sunday 18.
const MON = "2026-10-12";
const TUE = "2026-10-13";
const WED = "2026-10-14";
const THU = "2026-10-15";
const FRI = "2026-10-16";
const SAT = "2026-10-17";
const SUN = "2026-10-18";

Deno.test("a plain week Mon–Fri takes its times from the periods", () => {
  const week = projectSchoolDays(data(), MON, FRI).filter(
    (d) => d.member_id === KID,
  );
  assertEquals(week.map((d) => d.date), [MON, TUE, WED, THU, FRI]);
  for (const day of week) {
    assertEquals(day.starts, "08:00");
    assertEquals(day.ends, "09:35");
    assertEquals(day.free, null);
    assertEquals(day.holiday_name, null);
  }
  assertEquals(dayOf(data(), MON).lessons, [
    {
      period: 1,
      starts: "08:00",
      ends: "08:45",
      subject: "Mathematik",
      short: "Ma",
      room: null,
      teacher: null,
      tint: "blue",
      kind: "lesson",
      status: "normal",
      note: null,
      notable: false,
      equipment: null,
    },
    {
      period: 2,
      starts: "08:50",
      ends: "09:35",
      subject: "Deutsch",
      short: "D",
      room: null,
      teacher: null,
      tint: "rose",
      kind: "lesson",
      status: "normal",
      note: null,
      notable: false,
      equipment: null,
    },
  ]);
});

Deno.test("a care row (Hort) feeds care_until and is not in starts or ends", () => {
  const d = data({
    lessons: [
      lesson("mo1", 1, "mathe", { period_index: 1 }),
      lesson("hort1", 1, null, {
        period_index: null,
        starts_at: "13:30:00",
        ends_at: "16:30:00",
        kind: "care",
        title: "Hort",
      }),
    ],
  });
  const day = dayOf(d, MON);
  assertEquals(day.starts, "08:00");
  assertEquals(day.ends, "08:45");
  assertEquals(day.care_until, "16:30");
  assertEquals(day.care_label, "Hort");
  const care = day.lessons.find((l) => l.kind === "care");
  assertEquals(care?.starts, "13:30");
  assertEquals(care?.ends, "16:30");
  assertEquals(care?.subject, "Hort");
  assertEquals(care?.short, null);
  assertEquals(care?.tint, null);
  assertEquals(care?.period, null);
});

Deno.test("a holiday covering two days is free 'holiday' with its name and no lessons", () => {
  const d = data({ holidays: [holiday("h1", "Herbstferien", MON, TUE)] });
  for (const date of [MON, TUE]) {
    const day = dayOf(d, date);
    assertEquals(day.free, "holiday");
    assertEquals(day.holiday_name, "Herbstferien");
    assertEquals(day.lessons, []);
    assertEquals(day.starts, null);
    assertEquals(day.ends, null);
  }
  const wed = dayOf(d, WED);
  assertEquals(wed.free, null);
  assertEquals(wed.starts, "08:00");
});

Deno.test("an 'extra' on a holiday makes that day a school day with the extra lesson", () => {
  const d = data({
    holidays: [holiday("h1", "Herbstferien", MON, TUE)],
    exceptions: [exception("x1", TUE, "extra", {
      period_index: 2,
      subject_id: "deutsch",
      note: "Nachschreibtermin",
    })],
  });
  const tue = dayOf(d, TUE);
  assertEquals(tue.free, null);
  assertEquals(tue.holiday_name, null);
  assertEquals(tue.starts, "08:50");
  assertEquals(tue.ends, "09:35");
  assertEquals(tue.lessons.length, 1);
  assertEquals(tue.lessons[0].status, "extra");
  assertEquals(tue.lessons[0].subject, "Deutsch");
  assertEquals(tue.lessons[0].note, "Nachschreibtermin");
  // The other holiday day stays a holiday.
  assertEquals(dayOf(d, MON).free, "holiday");
});

Deno.test("a holiday on a Saturday is 'holiday', not 'weekend'", () => {
  const d = data({ holidays: [holiday("h1", "Ferien", SAT, SAT)] });
  assertEquals(dayOf(d, SAT).free, "holiday");
});

Deno.test("a Saturday and a Sunday without lessons are free 'weekend'", () => {
  const d = data();
  for (const date of [SAT, SUN]) {
    const day = dayOf(d, date);
    assertEquals(day.free, "weekend");
    assertEquals(day.lessons, []);
    assertEquals(day.starts, null);
  }
});

Deno.test("a Saturday lesson shows, and the Sunday stays free", () => {
  const d = data({
    lessons: [lesson("sa1", 6, "sport", { period_index: 1 })],
  });
  const sat = dayOf(d, SAT);
  assertEquals(sat.free, null);
  assertEquals(sat.starts, "08:00");
  assertEquals(sat.lessons.map((l) => l.subject), ["Sport"]);
  assertEquals(dayOf(d, SUN).free, "weekend");
});

Deno.test("A/B lessons alternate by week from the anchor, across the ISO year end", () => {
  // Anchor: week 37 of 2026 = Monday 2026-09-07, an 'a' week.
  // Weeks since the anchor (days/7): 09-07 → 0 'a'; 09-14 → 1 'b'; 10-12 → 5 'b';
  // 12-21 → 15 'b'; 12-28 → 16 'a' (2026 has 53 ISO weeks, so week-number parity
  // would break here); 2027-01-04 → 17 'b'; 2027-01-11 → 18 'a'.
  const d = data({
    timetables: [timetable(TT, KID, { week_cycle: "ab" })],
    lessons: [
      lesson("mo-a", 1, "mathe", { period_index: 1, week_parity: "a" }),
      lesson("de-b", 1, "deutsch", { period_index: 2, week_parity: "b" }),
    ],
  });
  const expected: [string, string[]][] = [
    ["2026-09-07", ["Mathematik"]],
    ["2026-09-14", ["Deutsch"]],
    ["2026-10-12", ["Deutsch"]],
    ["2026-12-21", ["Deutsch"]],
    ["2026-12-28", ["Mathematik"]],
    ["2027-01-04", ["Deutsch"]],
    ["2027-01-11", ["Mathematik"]],
  ];
  for (const [date, subjects] of expected) {
    assertEquals(
      dayOf(d, date).lessons.map((l) => l.subject),
      subjects,
      date,
    );
  }
});

Deno.test("abParity reads the anchor from the ISO year of the term start", () => {
  const term = data().terms[0];
  assertEquals(abParity(term, "2026-09-07"), "a");
  assertEquals(abParity(term, "2026-10-12"), "b");
  assertEquals(abParity(term, "2026-12-28"), "a");
  assertEquals(abParity(term, "2027-01-04"), "b");
  assertEquals(abParity({ ...term, ab_anchor_week: null }, "2026-10-12"), "a");
});

Deno.test("week_cycle 'weekly' ignores the parity values", () => {
  const d = data({
    lessons: [
      lesson("mo-a", 1, "mathe", { period_index: 1, week_parity: "a" }),
      lesson("de-b", 1, "deutsch", { period_index: 2, week_parity: "b" }),
    ],
  });
  assertEquals(dayOf(d, MON).lessons.length, 2);
});

Deno.test("a timetable's valid_from and valid_to clip its days", () => {
  const d = data({
    timetables: [timetable(TT, KID, {
      valid_from: "2026-10-13",
      valid_to: "2026-10-14",
    })],
  });
  const dates = projectSchoolDays(d, MON, FRI).map((x) => x.date);
  assertEquals(dates, [TUE, WED]);
});

Deno.test("the term's range clips the timetable", () => {
  const base = data();
  const d = data({
    terms: [{ ...base.terms[0], ends_on: WED }],
  });
  const dates = projectSchoolDays(d, MON, SUN).map((x) => x.date);
  assertEquals(dates, [MON, TUE, WED]);
});

Deno.test("timetablesJson only lists timetables valid on the date", () => {
  const d = data({
    timetables: [timetable(TT, KID, { valid_from: "2026-10-13" })],
  });
  assertEquals(timetablesJson(d, MON), []);
  assertEquals(timetablesJson(d, TUE).map((t) => t.member_id), [KID]);
});

Deno.test("two children with two timetables get their own days and classes", () => {
  const d = data({
    timetables: [
      timetable(TT, KID),
      timetable(TT2, KID2, { class_label: "4a" }),
    ],
    lessons: [
      lesson("k1-mo", 1, "mathe", { period_index: 1 }),
      lesson("k2-mo", 1, "musik", { period_index: 3, timetable_id: TT2 }),
    ],
  });
  const monday = projectSchoolDays(d, MON, MON);
  assertEquals(monday.map((x) => x.member_id), [KID, KID2]);
  assertEquals(monday[0].starts, "08:00");
  assertEquals(monday[1].starts, "09:55");
  assertEquals(monday[1].lessons.map((l) => l.subject), ["Musik"]);
  assertEquals(
    timetablesJson(d, MON).map((t) => [t.member_id, t.class_label]),
    [[KID, "2b"], [KID2, "4a"]],
  );
});

Deno.test("a cancelled lesson stays listed but leaves starts, ends, notable and equipment", () => {
  const d = data({
    lessons: [
      lesson("mo1", 1, "mathe", { period_index: 1 }),
      lesson("sp3", 1, "sport", { period_index: 3, is_notable: true }),
    ],
    exceptions: [exception("x1", MON, "cancelled", { period_index: 3 })],
  });
  const day = dayOf(d, MON);
  assertEquals(day.ends, "08:45", "cancelling the last lesson shortens ends");
  assertEquals(day.notable, []);
  assertEquals(day.lessons.length, 2);
  const sport = day.lessons.find((l) => l.period === 3);
  assertEquals(sport?.status, "cancelled");
  assertEquals(sport?.notable, false);
  assertEquals(sport?.equipment, null);
});

Deno.test("a substituted lesson takes the new subject, teacher and note", () => {
  const d = data({
    lessons: [
      lesson("mo1", 1, "mathe", { period_index: 1, teacher: "Frau Klein" }),
    ],
    exceptions: [exception("x1", MON, "substituted", {
      period_index: 1,
      subject_id: "deutsch",
      teacher: "Herr Berg",
      note: "Vertretung",
    })],
  });
  const [lessonRow] = dayOf(d, MON).lessons;
  assertEquals(lessonRow.status, "substituted");
  assertEquals(lessonRow.subject, "Deutsch");
  assertEquals(lessonRow.short, "D");
  assertEquals(lessonRow.tint, "rose");
  assertEquals(lessonRow.teacher, "Herr Berg");
  assertEquals(lessonRow.note, "Vertretung");
});

Deno.test("a room change rewrites the room and keeps the subject", () => {
  const d = data({
    lessons: [lesson("mo1", 1, "mathe", { period_index: 1, room: "R1" })],
    exceptions: [exception("x1", MON, "room_change", {
      period_index: 1,
      room: "Aula",
    })],
  });
  const [lessonRow] = dayOf(d, MON).lessons;
  assertEquals(lessonRow.status, "room_change");
  assertEquals(lessonRow.room, "Aula");
  assertEquals(lessonRow.subject, "Mathematik");
});

Deno.test("notable names are unique and in time order", () => {
  const d = data({
    lessons: [
      lesson("sw1", 1, "schwimmen", { period_index: 1, is_notable: true }),
      lesson("sp2", 1, "sport", { period_index: 2, is_notable: true }),
      lesson("sp3", 1, "sport", { period_index: 3, is_notable: true }),
    ],
  });
  assertEquals(dayOf(d, MON).notable, ["Schwimmen", "Sport"]);
});

Deno.test("equipment comes from the subject", () => {
  const d = data({
    lessons: [
      lesson("sp1", 1, "sport", { period_index: 1 }),
      lesson("sw2", 1, "schwimmen", { period_index: 2 }),
      lesson("mo3", 1, "mathe", { period_index: 3 }),
    ],
  });
  const equipment = dayOf(d, MON).lessons.map((l) => l.equipment);
  assertEquals(equipment, ["Sportsachen", "Schwimmsachen", null]);
});

Deno.test("lessons are sorted by start, whatever their order in the grid", () => {
  const d = data({
    lessons: [
      lesson("hort", 1, null, {
        starts_at: "13:30:00",
        ends_at: "16:30:00",
        kind: "care",
        title: "Hort",
      }),
      lesson("mo3", 1, "mathe", { period_index: 3 }),
      lesson("mo1", 1, "deutsch", { period_index: 1 }),
    ],
  });
  assertEquals(dayOf(d, MON).lessons.map((l) => l.starts), [
    "08:00",
    "09:55",
    "13:30",
  ]);
});

Deno.test("a weekday with a timetable but no lessons has no span and is not free", () => {
  const d = data({
    lessons: [lesson("mo1", 1, "mathe", { period_index: 1 })],
  });
  const day = dayOf(d, WED);
  assertEquals(day.starts, null);
  assertEquals(day.ends, null);
  assertEquals(day.free, null);
  assertEquals(day.lessons, []);
});

Deno.test("timetablesJson lists the periods sorted, with breaks", () => {
  const [tt] = timetablesJson(data(), MON);
  assertEquals(tt.member_id, KID);
  assertEquals(tt.class_label, "2b");
  assertEquals(tt.school_name, "Grundschule Musterweg");
  assertEquals(tt.periods.length, 11);
  assertEquals(tt.periods.slice(0, 3), [
    { index: 1, label: null, starts: "08:00", ends: "08:45", kind: "lesson" },
    { index: 1, label: null, starts: "08:45", ends: "08:50", kind: "break" },
    { index: 2, label: null, starts: "08:50", ends: "09:35", kind: "lesson" },
  ]);
  const starts = tt.periods.map((p) => p.starts);
  assertEquals(starts, [...starts].sort());
});

Deno.test("the day and lesson keys are exactly the contract's", () => {
  const day = dayOf(data(), MON);
  assertEquals(Object.keys(day).sort(), [
    "care_label",
    "care_until",
    "date",
    "ends",
    "free",
    "holiday_name",
    "lessons",
    "member_id",
    "notable",
    "starts",
  ]);
  assertEquals(Object.keys(day.lessons[0]).sort(), [
    "ends",
    "equipment",
    "kind",
    "notable",
    "note",
    "period",
    "room",
    "short",
    "starts",
    "status",
    "subject",
    "teacher",
    "tint",
  ]);
});

// ── public holidays from the region (publicHolidayRows, the cache rows of api.holiday_feed) ──

function feedRow(p: Partial<HolidayFeedRow> & { id: string }): HolidayFeedRow {
  return {
    country: "CH",
    kind: "public",
    starts_on: MON,
    ends_on: MON,
    names: { de: "Auffahrt", en: "Ascension Day" },
    nationwide: true,
    subdivisions: [],
    ...p,
  };
}

function school(id: string, regionCode: string | null): SchoolRow {
  return {
    id,
    name: id,
    state_code: null,
    region_code: regionCode,
    timezone: "Europe/Berlin",
    created_at: "2026-09-01T00:00:00Z",
  };
}

Deno.test("a public holiday covering the school's region is a school holiday of that school", () => {
  const rows = publicHolidayRows(
    [school(SCHOOL, "CH-ZH-ZH-ZH")],
    [feedRow({ id: "f-auffahrt" })],
    [],
    "de-DE",
  );
  assertEquals(rows, [{
    id: `feed:f-auffahrt:${SCHOOL}`,
    school_id: SCHOOL,
    name: "Auffahrt",
    starts_on: MON,
    ends_on: MON,
    kind: "public_holiday",
    source: "imported",
    source_url: null,
    feed_id: "f-auffahrt",
  }]);
});

Deno.test("the school's region decides: another canton's holiday does not reach it", () => {
  const rows = publicHolidayRows(
    [school(SCHOOL, "CH-AG")],
    [feedRow({ id: "f-zh", nationwide: false, subdivisions: ["CH-ZH"] })],
    [],
    "de-DE",
  );
  assertEquals(rows, []);
});

Deno.test("a school without a region gets no public holidays", () => {
  assertEquals(
    publicHolidayRows(
      [school(SCHOOL, null)],
      [feedRow({ id: "f" })],
      [],
      "de-DE",
    ),
    [],
  );
});

Deno.test("the name follows the household's language, German when there is none", () => {
  const feed = [
    feedRow({ id: "f", names: { de: "Auffahrt", en: "Ascension Day" } }),
  ];
  assertEquals(
    publicHolidayRows([school(SCHOOL, "CH")], feed, [], "en-GB")[0].name,
    "Ascension Day",
  );
  assertEquals(
    publicHolidayRows([school(SCHOOL, "CH")], feed, [], "it-IT")[0].name,
    "Auffahrt",
  );
});

Deno.test("a school's public holiday is named in French and Spanish too", () => {
  const feed = [
    feedRow({
      id: "f",
      names: {
        de: "Auffahrt",
        en: "Ascension Day",
        fr: "Ascension",
        es: "Ascensión",
      },
    }),
  ];
  assertEquals(
    publicHolidayRows([school(SCHOOL, "CH")], feed, [], "fr-FR")[0].name,
    "Ascension",
  );
  assertEquals(
    publicHolidayRows([school(SCHOOL, "CH")], feed, [], "es-ES")[0].name,
    "Ascensión",
  );
  // A regional tag of an unsupported language falls back to German.
  assertEquals(
    publicHolidayRows([school(SCHOOL, "CH")], feed, [], "it-IT")[0].name,
    "Auffahrt",
  );
});

Deno.test("a public holiday in French or Spanish frees the school day with that name", () => {
  const feed = feedRow({
    id: "f-auffahrt",
    names: {
      de: "Auffahrt",
      en: "Ascension Day",
      fr: "Ascension",
      es: "Ascensión",
    },
    starts_on: TUE,
    ends_on: TUE,
  });
  for (
    const [locale, name] of [["fr-FR", "Ascension"], [
      "es-ES",
      "Ascensión",
    ]] as const
  ) {
    const d = data({
      holidays: publicHolidayRows(
        [school(SCHOOL, "CH-ZH")],
        [feed],
        [],
        locale,
      ),
    });
    const tue = dayOf(d, TUE);
    assertEquals(tue.free, "holiday");
    assertEquals(tue.holiday_name, name);
    assertEquals(tue.lessons, []);
  }
});

Deno.test("a holiday the family already has for this feed id is not duplicated", () => {
  const family: HolidayRow = {
    ...holiday("h-own", "Auffahrt (eigener Name)", MON, MON, null),
    kind: "public_holiday",
    source: "imported",
    feed_id: "f",
  };
  assertEquals(
    publicHolidayRows(
      [school(SCHOOL, "CH")],
      [feedRow({ id: "f" })],
      [family],
      "de-DE",
    ),
    [],
  );
});

Deno.test("a family row for one school skips only that school's copy of the feed holiday", () => {
  const schoolB = "school2";
  const family: HolidayRow = {
    ...holiday("h-own", "Auffahrt", MON, MON, SCHOOL),
    kind: "public_holiday",
    source: "imported",
    feed_id: "f",
  };
  const rows = publicHolidayRows(
    [school(SCHOOL, "CH"), school(schoolB, "CH")],
    [feedRow({ id: "f" })],
    [family],
    "de-DE",
  );
  assertEquals(rows.map((r) => r.school_id), [schoolB]);
});

Deno.test("a public holiday from the region frees the school day in the projection", () => {
  const feed = feedRow({ id: "f-auffahrt", starts_on: TUE, ends_on: TUE });
  const d = data({
    holidays: publicHolidayRows([school(SCHOOL, "CH-ZH")], [feed], [], "de-DE"),
  });
  const tue = dayOf(d, TUE);
  assertEquals(tue.free, "holiday");
  assertEquals(tue.holiday_name, "Auffahrt");
  assertEquals(tue.lessons, []);
  assertEquals(dayOf(d, WED).free, null);
});
