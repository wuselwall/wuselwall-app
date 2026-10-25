import { assertEquals, assertNotEquals } from "jsr:@std/assert@1.0.13";
import {
  type BoardJson,
  type BusyRow,
  fillBoard,
  fillHolidays,
  fillMeals,
  fillSchool,
  fillUsual,
  holidaysBetween,
  type MealEntryRow,
  type MealInput,
  type MealJson,
  type MealSettings,
} from "./board.ts";
import type { HolidayFeedRow } from "./openholidays.ts";
import type { HolidayRow, SchoolDayJson, TimetableJson } from "./school.ts";
import { addDays, type Occurrence } from "./occurrences.ts";

// Monday 2026-10-12 .. Sunday 2026-10-18. Member ids are neutral on purpose.
const WEEK = "2026-10-12";

function occ(p: Partial<Occurrence> & { id: string }): Occurrence {
  return {
    event_id: p.id,
    recurrence_id: null,
    calendar_id: "c1",
    title: "Termin",
    location: null,
    description: null,
    kind: "appointment",
    presence_state: null,
    status: "confirmed",
    importance: "normal",
    all_day: false,
    start: "",
    end: "",
    local_start_date: "2026-10-14",
    local_end_date: "2026-10-14",
    local_starts: null,
    local_ends: null,
    attendee_ids: [],
    is_recurring: false,
    is_override: false,
    source: "event",
    colour_hex: null,
    ...p,
  };
}

function presence(
  p: Partial<Occurrence> & { id: string; presence_state: string },
): Occurrence {
  return occ({ kind: "presence", ...p });
}

function base(): BoardJson {
  return {
    week_start: WEEK,
    today: "2026-10-13",
    timezone: "Europe/Berlin",
    generated_at: "2026-10-13T08:00:00Z",
    settings: { day_parts: ["12:00", "17:00"], member_label: "name" },
    members: [{ id: "m1", display_name: "Erste", color: "#2E7D6B" }],
    presence: [],
    timetables: [{ member_id: "m2", periods: [] }],
    days: Array.from({ length: 7 }, (_, i) => ({
      date: addDays(WEEK, i),
      events: [],
      busy_until: [],
      school: [],
      meal: null,
    })),
    open_tasks: [{ member_id: "m1", count: 2 }],
    shopping_count: 3,
  };
}

function dayOf(board: BoardJson, date: string) {
  return board.days.find((d) => d.date === date)!;
}

Deno.test("a two-day travel band is clipped to the week and flagged at the edge", () => {
  const board = fillBoard(
    base(),
    [
      presence({
        id: "p1",
        presence_state: "travel",
        title: "Dienstreise Berlin",
        local_start_date: "2026-10-17",
        local_end_date: "2026-10-19",
        all_day: true,
        attendee_ids: ["m1"],
      }),
      presence({
        id: "p2",
        presence_state: "travel",
        local_start_date: "2026-10-14",
        local_end_date: "2026-10-15",
        all_day: true,
        attendee_ids: ["m1"],
      }),
    ],
    [],
  );
  assertEquals(board.presence[0], {
    id: "p1|m1",
    member_id: "m1",
    state: "travel",
    label: "Dienstreise Berlin",
    first_day: "2026-10-17",
    last_day: "2026-10-18",
    starts: null,
    ends: null,
    tentative: false,
    starts_before_week: false,
    ends_after_week: true,
  });
  assertEquals(board.presence[1].first_day, "2026-10-14");
  assertEquals(board.presence[1].last_day, "2026-10-15");
  assertEquals(board.presence[1].starts_before_week, false);
  assertEquals(board.presence[1].ends_after_week, false);
});

Deno.test("a presence that started last week is clipped to Monday and flagged", () => {
  const board = fillBoard(
    base(),
    [
      presence({
        id: "p1",
        presence_state: "away",
        local_start_date: "2026-10-08",
        local_end_date: "2026-10-13",
        all_day: true,
        attendee_ids: ["m1"],
      }),
    ],
    [],
  );
  assertEquals(board.presence.length, 1);
  assertEquals(board.presence[0].first_day, WEEK);
  assertEquals(board.presence[0].last_day, "2026-10-13");
  assertEquals(board.presence[0].starts_before_week, true);
  assertEquals(board.presence[0].ends_after_week, false);
});

Deno.test("a presence gets one band per attendee and none without attendees", () => {
  const board = fillBoard(
    base(),
    [
      presence({
        id: "p1",
        presence_state: "home_office",
        title: "Homeoffice",
        local_starts: "08:30",
        local_ends: "12:00",
        attendee_ids: ["m1", "m2"],
      }),
      presence({ id: "p2", presence_state: "off", attendee_ids: [] }),
    ],
    [],
  );
  assertEquals(
    board.presence.map((b) => [b.id, b.member_id, b.starts, b.ends]),
    [
      ["p1|m1", "m1", "08:30", "12:00"],
      ["p1|m2", "m2", "08:30", "12:00"],
    ],
  );
  assertEquals(board.presence[0].state, "home_office");
  assertEquals(board.presence[0].label, "Homeoffice");
});

Deno.test("a multi-day all-day appointment appears on each day it covers", () => {
  const board = fillBoard(
    base(),
    [
      occ({
        id: "e1",
        title: "Messe",
        all_day: true,
        local_start_date: "2026-10-14",
        local_end_date: "2026-10-16",
      }),
    ],
    [],
  );
  const onDays = board.days
    .filter((d) => d.events.some((e) => e.id === "e1"))
    .map((d) => d.date);
  assertEquals(onDays, ["2026-10-14", "2026-10-15", "2026-10-16"]);
  assertEquals(dayOf(board, "2026-10-15").events[0].starts, null);
  assertEquals(dayOf(board, "2026-10-15").events[0].ends, null);
});

Deno.test("a timed appointment is on its start day only, with its times", () => {
  const board = fillBoard(
    base(),
    [
      occ({
        id: "e1",
        title: "Konzert",
        location: "Stadthalle",
        local_start_date: "2026-10-14",
        local_end_date: "2026-10-15",
        local_starts: "22:00",
        local_ends: "01:00",
        attendee_ids: ["m1"],
      }),
    ],
    [],
  );
  assertEquals(dayOf(board, "2026-10-15").events, []);
  assertEquals(dayOf(board, "2026-10-14").events, [{
    id: "e1",
    title: "Konzert",
    location: "Stadthalle",
    starts: "22:00",
    ends: "01:00",
    attendee_ids: ["m1"],
    tentative: false,
    key: false,
  }]);
});

Deno.test("an imported calendar is on the board only when it shows there, as key appointments", () => {
  const imported = (id: string, show: boolean, title: string) =>
    occ({
      id,
      title,
      source: "imported",
      colour_hex: "#6D4C41",
      importance: show ? "key" : "normal",
      attendee_ids: [],
      local_start_date: "2026-10-14",
      local_end_date: "2026-10-14",
      all_day: true,
    });
  const board = fillBoard(
    base(),
    [
      imported("i-show", true, "Abfall"),
      imported("i-hidden", false, "Spielplan"),
    ],
    [],
  );
  assertEquals(dayOf(board, "2026-10-14").events.map((e) => [e.id, e.key]), [[
    "i-show",
    true,
  ]]);
});

Deno.test("the key and tentative flags come from importance and status", () => {
  const board = fillBoard(
    base(),
    [
      occ({
        id: "a",
        title: "Zahnarzt",
        importance: "key",
        status: "tentative",
        local_starts: "09:00",
        local_ends: "09:30",
      }),
      occ({
        id: "b",
        title: "Sport",
        local_starts: "10:00",
        local_ends: "11:00",
      }),
    ],
    [],
  );
  const [a, b] = dayOf(board, "2026-10-14").events;
  assertEquals(a.id, "a");
  assertEquals([a.key, a.tentative], [true, true]);
  assertEquals([b.key, b.tentative], [false, false]);
});

Deno.test("events sort all-day first, then start time, then title", () => {
  const board = fillBoard(
    base(),
    [
      occ({
        id: "1",
        title: "Zahn",
        local_starts: "14:00",
        local_ends: "15:00",
      }),
      occ({
        id: "2",
        title: "Bäcker",
        local_starts: "09:00",
        local_ends: "09:15",
      }),
      occ({
        id: "3",
        title: "Arzt",
        local_starts: "09:00",
        local_ends: "09:30",
      }),
      occ({ id: "4", title: "Ferien", all_day: true }),
    ],
    [],
  );
  assertEquals(
    dayOf(board, "2026-10-14").events.map((e) => e.title),
    ["Ferien", "Arzt", "Bäcker", "Zahn"],
  );
});

Deno.test("busy rows map to busy_until on their own date, as HH:MM", () => {
  const busy: BusyRow[] = [
    { profile_id: "m1", on_date: "2026-10-14", until: "17:00:00" },
    { profile_id: "m2", on_date: "2026-10-15", until: "15:30" },
  ];
  const board = fillBoard(base(), [], busy);
  assertEquals(dayOf(board, "2026-10-14").busy_until, [
    { member_id: "m1", until: "17:00" },
  ]);
  assertEquals(dayOf(board, "2026-10-15").busy_until, [
    { member_id: "m2", until: "15:30" },
  ]);
  assertEquals(dayOf(board, "2026-10-16").busy_until, []);
});

Deno.test("the untouched parts pass through and the input is not mutated", () => {
  const input = base();
  const snapshot = structuredClone(input);
  const board = fillBoard(
    input,
    [
      presence({
        id: "p1",
        presence_state: "travel",
        local_start_date: "2026-10-14",
        local_end_date: "2026-10-14",
        attendee_ids: ["m1"],
      }),
      occ({
        id: "e1",
        local_start_date: "2026-10-14",
        local_end_date: "2026-10-14",
      }),
    ],
    [{ profile_id: "m1", on_date: "2026-10-14", until: "17:00" }],
  );
  assertEquals(board.members, snapshot.members);
  assertEquals(board.settings, snapshot.settings);
  assertEquals(board.timetables, snapshot.timetables);
  assertEquals(board.open_tasks, snapshot.open_tasks);
  assertEquals(board.shopping_count, 3);
  assertEquals(board.today, snapshot.today);
  assertEquals(board.week_start, WEEK);
  assertEquals(
    board.days.map((d) => d.school),
    snapshot.days.map((d) => d.school),
  );
  assertEquals(board.days.map((d) => d.meal), snapshot.days.map((d) => d.meal));
  assertNotEquals(board, input);
  assertEquals(input, snapshot);
});

function schoolDay(date: string, member: string): SchoolDayJson {
  return {
    date,
    member_id: member,
    starts: "08:00",
    ends: "11:30",
    notable: [],
    care_until: null,
    care_label: null,
    free: null,
    holiday_name: null,
    lessons: [],
  };
}

const TIMETABLE: TimetableJson = {
  member_id: "m2",
  class_label: "2b",
  school_name: "Grundschule Musterweg",
  periods: [
    { index: 1, label: null, starts: "08:00", ends: "08:45", kind: "lesson" },
  ],
};

Deno.test("fillSchool puts each date's children into that day and replaces the timetables", () => {
  const input = base();
  const snapshot = structuredClone(input);
  const board = fillSchool(
    input,
    [
      schoolDay("2026-10-12", "m2"),
      schoolDay("2026-10-12", "m3"),
      schoolDay("2026-10-14", "m2"),
    ],
    [TIMETABLE],
  );
  assertEquals(board.timetables, [TIMETABLE]);
  assertEquals(dayOf(board, "2026-10-12").school, [
    schoolDay("2026-10-12", "m2"),
    schoolDay("2026-10-12", "m3"),
  ]);
  assertEquals(dayOf(board, "2026-10-13").school, []);
  assertEquals(dayOf(board, "2026-10-14").school, [
    schoolDay("2026-10-14", "m2"),
  ]);
  // The calendar parts pass through untouched and the input is not mutated.
  assertEquals(board.open_tasks, snapshot.open_tasks);
  assertEquals(board.shopping_count, 3);
  assertEquals(input, snapshot);
  assertNotEquals(board, input);
});

Deno.test("fillSchool with no school data leaves every day's school empty", () => {
  const board = fillSchool(base(), [], []);
  assertEquals(board.timetables, []);
  assertEquals(
    board.days.map((d) => d.school),
    Array.from({ length: 7 }, () => []),
  );
});

// ── the meal zone ────────────────────────────────────────────────────────────────

const MEAL_SETTINGS: MealSettings = {
  schoolDaySlot: "dinner",
  freeDaySlot: "lunch",
  awayMeansNotEating: true,
  careLunchCutoff: "14:00",
};

/** Member order is deliberately not alphabetical: "b", "a" and a child "c". */
const MEAL_MEMBERS: MealInput["members"] = [
  { id: "b", kind: "adult" },
  { id: "a", kind: "adult" },
  { id: "c", kind: "child" },
];

function meals(p: Partial<MealInput> = {}): BoardJson {
  return fillMeals(base(), {
    entries: [],
    settings: MEAL_SETTINGS,
    presence: [],
    schoolDays: [],
    members: MEAL_MEMBERS,
    ...p,
  });
}

function mealOf(board: BoardJson, date: string): MealJson {
  return dayOf(board, date).meal as MealJson;
}

function entry(
  p: Partial<MealEntryRow> & { on_date: string; slot: string },
): MealEntryRow {
  return {
    title: null,
    cook_profile_id: null,
    at_time: null,
    guests: 0,
    eating_overrides: null,
    ...p,
  };
}

function holiday(date: string, member: string): SchoolDayJson {
  return {
    ...schoolDay(date, member),
    starts: null,
    ends: null,
    free: "holiday",
    holiday_name: "Herbstferien",
  };
}

function careUntil(date: string, member: string, until: string): SchoolDayJson {
  return { ...schoolDay(date, member), care_until: until, care_label: "Hort" };
}

/** A timed away band for one member on one day, from `starts` to `ends`. */
function awayBand(
  date: string,
  member: string,
  starts: string,
  ends: string,
): Occurrence {
  return presence({
    id: `away-${date}-${member}`,
    presence_state: "away",
    local_start_date: date,
    local_end_date: date,
    local_starts: starts,
    local_ends: ends,
    attendee_ids: [member],
  });
}

Deno.test("school days take the school-day slot and weekends the free-day slot", () => {
  const board = meals();
  assertEquals(mealOf(board, "2026-10-12").slot, "dinner");
  assertEquals(mealOf(board, "2026-10-16").slot, "dinner");
  assertEquals(mealOf(board, "2026-10-17").slot, "lunch");
  assertEquals(mealOf(board, "2026-10-18").slot, "lunch");
});

Deno.test("a holiday weekday counts as a free day", () => {
  const board = meals({ schoolDays: [holiday("2026-10-14", "c")] });
  assertEquals(mealOf(board, "2026-10-14").slot, "lunch");
  assertEquals(mealOf(board, "2026-10-15").slot, "dinner");
});

Deno.test("an all-day travel band removes the member from that day's meal", () => {
  const travel = presence({
    id: "t1",
    presence_state: "travel",
    all_day: true,
    local_start_date: "2026-10-13",
    local_end_date: "2026-10-13",
    attendee_ids: ["a"],
  });
  const board = meals({ presence: [travel] });
  assertEquals(mealOf(board, "2026-10-13").eating, ["b", "c"]);
  assertEquals(mealOf(board, "2026-10-14").eating, ["b", "a", "c"]);
});

Deno.test("a timed away band removes from dinner at 18:30 but not from lunch", () => {
  const band = awayBand("2026-10-13", "a", "17:00", "22:00");
  const dinner = meals({ presence: [band] });
  assertEquals(mealOf(dinner, "2026-10-13").eating, ["b", "c"]);

  const lunch = meals({
    presence: [band],
    settings: { ...MEAL_SETTINGS, schoolDaySlot: "lunch" },
  });
  assertEquals(mealOf(lunch, "2026-10-13").eating, ["b", "a", "c"]);
});

Deno.test("a timed away band is judged at the entry's time when it has one", () => {
  const band = awayBand("2026-10-13", "a", "17:00", "22:00");
  const early = meals({
    presence: [band],
    entries: [
      entry({ on_date: "2026-10-13", slot: "dinner", at_time: "16:00:00" }),
    ],
  });
  assertEquals(mealOf(early, "2026-10-13").eating, ["b", "a", "c"]);
  assertEquals(mealOf(early, "2026-10-13").time, "16:00");

  const late = meals({
    presence: [band],
    entries: [
      entry({ on_date: "2026-10-13", slot: "dinner", at_time: "17:30:00" }),
    ],
  });
  assertEquals(mealOf(late, "2026-10-13").eating, ["b", "c"]);
});

Deno.test("awayMeansNotEating off keeps away members at the table", () => {
  const board = meals({
    presence: [awayBand("2026-10-13", "a", "17:00", "22:00")],
    settings: { ...MEAL_SETTINGS, awayMeansNotEating: false },
  });
  assertEquals(mealOf(board, "2026-10-13").eating, ["b", "a", "c"]);
});

Deno.test("a child in care past the cutoff is out of school-day lunch but in for dinner", () => {
  const schoolDays = [careUntil("2026-10-13", "c", "15:00")];
  const lunch = meals({
    schoolDays,
    settings: { ...MEAL_SETTINGS, schoolDaySlot: "lunch" },
  });
  assertEquals(mealOf(lunch, "2026-10-13").eating, ["b", "a"]);

  const dinner = meals({ schoolDays });
  assertEquals(mealOf(dinner, "2026-10-13").slot, "dinner");
  assertEquals(mealOf(dinner, "2026-10-13").eating, ["b", "a", "c"]);
});

Deno.test("care that ends by the cutoff keeps the child at school-day lunch", () => {
  const board = meals({
    schoolDays: [careUntil("2026-10-13", "c", "13:30")],
    settings: { ...MEAL_SETTINGS, schoolDaySlot: "lunch" },
  });
  assertEquals(mealOf(board, "2026-10-13").eating, ["b", "a", "c"]);
});

Deno.test("eating overrides add (true) and remove (false) on top of the rules", () => {
  const travel = presence({
    id: "t1",
    presence_state: "travel",
    all_day: true,
    local_start_date: "2026-10-13",
    local_end_date: "2026-10-13",
    attendee_ids: ["a"],
  });
  const board = meals({
    presence: [travel],
    entries: [
      entry({
        on_date: "2026-10-13",
        slot: "dinner",
        eating_overrides: { b: false, a: true, zz: true },
      }),
    ],
  });
  // "a" is away but overridden back in; "b" is removed; unknown ids are ignored.
  assertEquals(mealOf(board, "2026-10-13").eating, ["a", "c"]);

  const careOverride = meals({
    schoolDays: [careUntil("2026-10-13", "c", "15:00")],
    settings: { ...MEAL_SETTINGS, schoolDaySlot: "lunch" },
    entries: [
      entry({
        on_date: "2026-10-13",
        slot: "lunch",
        eating_overrides: { c: true },
      }),
    ],
  });
  assertEquals(mealOf(careOverride, "2026-10-13").eating, ["b", "a", "c"]);
});

Deno.test("the entry's title, cook, time, guests and the board's slot are carried", () => {
  const board = meals({
    entries: [
      entry({
        on_date: "2026-10-17",
        slot: "lunch",
        title: "Käsespätzle",
        cook_profile_id: "a",
        at_time: "12:30:00",
        guests: 2,
      }),
    ],
  });
  assertEquals(mealOf(board, "2026-10-17"), {
    slot: "lunch",
    time: "12:30",
    title: "Käsespätzle",
    cook_id: "a",
    eating: ["b", "a", "c"],
    guests: 2,
  });
});

Deno.test("days without an entry have no title, and entries of other slots are ignored", () => {
  const board = meals({
    entries: [
      // Saturday's dinner is not the free-day lunch the board shows.
      entry({ on_date: "2026-10-17", slot: "dinner", title: "Gulasch" }),
    ],
  });
  assertEquals(mealOf(board, "2026-10-17"), {
    slot: "lunch",
    time: null,
    title: null,
    cook_id: null,
    eating: ["b", "a", "c"],
    guests: 0,
  });
  assertEquals(mealOf(board, "2026-10-18"), {
    slot: "lunch",
    time: null,
    title: null,
    cook_id: null,
    eating: ["b", "a", "c"],
    guests: 0,
  });
});

Deno.test("eating follows the member order given, and the input is not mutated", () => {
  const input = base();
  const snapshot = structuredClone(input);
  const board = fillMeals(input, {
    entries: [],
    settings: MEAL_SETTINGS,
    presence: [],
    schoolDays: [],
    members: [
      { id: "c", kind: "child" },
      { id: "a", kind: "adult" },
      { id: "b", kind: "adult" },
    ],
  });
  assertEquals(mealOf(board, "2026-10-12").eating, ["c", "a", "b"]);
  assertEquals(input, snapshot);
});

// ── public holidays on the board (fillHolidays) and the meal slot they change ─────

const ASCENSION: HolidayFeedRow = {
  id: "feed-ch-auffahrt",
  country: "CH",
  kind: "public",
  starts_on: "2026-05-14",
  ends_on: "2026-05-14",
  names: { de: "Auffahrt", en: "Ascension Day" },
  nationwide: true,
  subdivisions: [],
};

const ZH_ONLY: HolidayFeedRow = {
  id: "feed-zh-sechselaeuten",
  country: "CH",
  kind: "public",
  starts_on: "2026-10-12",
  ends_on: "2026-10-12",
  names: { de: "Sechseläuten" },
  nationwide: false,
  subdivisions: ["CH-ZH"],
};

const OWN: HolidayRow = {
  id: "own-1",
  school_id: null,
  name: "Brückentag",
  starts_on: "2026-10-16",
  ends_on: "2026-10-16",
  kind: "public_holiday",
  source: "manual",
  source_url: null,
  feed_id: null,
};

function withHolidays(
  region: string | null,
  locale = "de-DE",
  holidays: HolidayRow[] = [],
  feed: HolidayFeedRow[] = [ASCENSION, ZH_ONLY],
): BoardJson {
  return fillHolidays(base(), holidays, feed, region, locale);
}

Deno.test("a region's public holiday marks its day, named in the household's language", () => {
  const feed = [{
    ...ASCENSION,
    starts_on: "2026-10-14",
    ends_on: "2026-10-14",
  }];
  const german = withHolidays("CH-ZH-ZH-ZH", "de-DE", [], feed);
  assertEquals(dayOf(german, "2026-10-14").holiday, {
    name: "Auffahrt",
    source: "region",
  });
  assertEquals(dayOf(german, "2026-10-13").holiday, null);
  const english = withHolidays("CH-ZH", "en-GB", [], feed);
  assertEquals(dayOf(english, "2026-10-14").holiday, {
    name: "Ascension Day",
    source: "region",
  });
});

Deno.test("a region's holiday is named in French and Spanish, German as the fallback", () => {
  const feed = [{
    ...ASCENSION,
    names: {
      de: "Auffahrt",
      en: "Ascension Day",
      fr: "Ascension",
      es: "Ascensión",
    },
    starts_on: "2026-10-14",
    ends_on: "2026-10-14",
  }];
  const french = withHolidays("CH-ZH", "fr-FR", [], feed);
  assertEquals(dayOf(french, "2026-10-14").holiday, {
    name: "Ascension",
    source: "region",
  });
  const spanish = withHolidays("CH-ZH", "es-ES", [], feed);
  assertEquals(dayOf(spanish, "2026-10-14").holiday, {
    name: "Ascensión",
    source: "region",
  });
  // An unsupported household language falls back to German.
  const italian = withHolidays("CH-ZH", "it-IT", [], feed);
  assertEquals(dayOf(italian, "2026-10-14").holiday, {
    name: "Auffahrt",
    source: "region",
  });
});

Deno.test("a canton-only holiday covers its region's municipalities, not another canton", () => {
  const inZh = withHolidays("CH-ZH-ZH-ZH");
  assertEquals(dayOf(inZh, "2026-10-12").holiday, {
    name: "Sechseläuten",
    source: "region",
  });
  const inAg = withHolidays("CH-AG");
  assertEquals(dayOf(inAg, "2026-10-12").holiday, null);
});

Deno.test("without a household region only the family's own holidays mark a day", () => {
  const board = withHolidays(null, "de-DE", [OWN]);
  assertEquals(dayOf(board, "2026-10-12").holiday, null);
  assertEquals(dayOf(board, "2026-10-16").holiday, {
    name: "Brückentag",
    source: "household",
  });
});

Deno.test("the family's own holiday row wins over the cache and carries its own name", () => {
  const feed = [{
    ...ASCENSION,
    starts_on: "2026-10-16",
    ends_on: "2026-10-16",
  }];
  const board = withHolidays("CH-ZH", "de-DE", [OWN], feed);
  assertEquals(dayOf(board, "2026-10-16").holiday, {
    name: "Brückentag",
    source: "household",
  });
});

Deno.test("a school's row for one school does not mark the household's day", () => {
  const schoolOnly: HolidayRow = { ...OWN, school_id: "school1" };
  const board = withHolidays(null, "de-DE", [schoolOnly]);
  assertEquals(dayOf(board, "2026-10-16").holiday, null);
});

Deno.test("holidaysBetween lists one holiday per date of a month view's window", () => {
  // Six weeks across the end of October; the own row and a canton holiday inside it,
  // Ascension in May outside it.
  const feed = [ASCENSION, ZH_ONLY, {
    ...ASCENSION,
    id: "feed-ch-allerheiligen",
    starts_on: "2026-11-01",
    ends_on: "2026-11-01",
    names: { de: "Allerheiligen", en: "All Saints' Day" },
  }];
  assertEquals(
    holidaysBetween("2026-09-28", "2026-11-08", [OWN], feed, "CH-ZH", "en-GB"),
    [
      { date: "2026-10-12", name: "Sechseläuten", source: "region" },
      { date: "2026-10-16", name: "Brückentag", source: "household" },
      { date: "2026-11-01", name: "All Saints' Day", source: "region" },
    ],
  );
  // Without a region only the family's own rows count.
  assertEquals(
    holidaysBetween("2026-10-01", "2026-10-31", [OWN], feed, null, "de-DE"),
    [{ date: "2026-10-16", name: "Brückentag", source: "household" }],
  );
});

Deno.test("a day without any holiday has null, and the input is not mutated", () => {
  const input = base();
  const snapshot = structuredClone(input);
  const board = fillHolidays(input, [], [ASCENSION], "CH-ZH", "de-DE");
  assertEquals(input, snapshot);
  assertEquals(board.days.every((d) => d.holiday === null), true);
});

Deno.test("a public holiday of the household's region is a free day for the meal zone", () => {
  const withHoliday = fillHolidays(
    base(),
    [],
    [{ ...ASCENSION, starts_on: "2026-10-14", ends_on: "2026-10-14" }],
    "CH-ZH",
    "de-DE",
  );
  const board = fillMeals(withHoliday, {
    entries: [],
    settings: MEAL_SETTINGS,
    presence: [],
    schoolDays: [],
    members: MEAL_MEMBERS,
  });
  assertEquals(mealOf(board, "2026-10-14").slot, "lunch");
  assertEquals(mealOf(board, "2026-10-13").slot, "dinner");
});

// ── the usual week ──────────────────────────────────────────────────────────────

Deno.test("fillUsual puts the board members' usual places on their weekdays, none on a holiday", () => {
  const withHoliday = fillHolidays(base(), [], [ASCENSION, ZH_ONLY], "CH-ZH", "de-DE");
  const input = structuredClone(withHoliday);
  const board = fillUsual(withHoliday, [
    {
      profile_id: "m1",
      anchor: null,
      slots: [1, 2, 3].map((weekday) => ({
        week: 0,
        weekday,
        position: 1,
        state: "home_office",
        label: null,
        starts: null,
        ends: null,
      })),
    },
    // Not a member of the board (left the family): never drawn.
    {
      profile_id: "gone",
      anchor: null,
      slots: [{ week: 0, weekday: 2, position: 1, state: "off", label: null, starts: null, ends: null }],
    },
  ]);
  // Monday 12 is Sechseläuten in Zürich.
  assertEquals(dayOf(board, "2026-10-12").usual, []);
  assertEquals(dayOf(board, "2026-10-13").usual, [
    { member_id: "m1", state: "home_office", label: null, starts: null, ends: null },
  ]);
  assertEquals(dayOf(board, "2026-10-15").usual, []);
  assertEquals(withHoliday, input);
});
