import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1.0.13";
import type {
  EventRow,
  ExternalOccurrenceRow,
  OverrideRow,
} from "./occurrences.ts";
import {
  DEFAULT_LIMIT,
  fold,
  MAX_LIMIT,
  searchOccurrences,
  searchRank,
  searchTerms,
} from "./search.ts";

const TZ = "Europe/Berlin";
const TODAY = "2026-11-28";

function ev(p: Partial<EventRow> & { id?: string }): EventRow {
  return {
    id: p.id ?? "e1",
    calendar_id: "c1",
    title: "Termin",
    description: null,
    location: null,
    kind: "appointment",
    presence_state: null,
    status: "confirmed",
    importance: "normal",
    is_all_day: false,
    starts_at: null,
    ends_at: null,
    start_date: null,
    end_date: null,
    timezone: TZ,
    rrule: null,
    rdates: null,
    exdates: null,
    attendee_ids: [],
    ...p,
  };
}

/** A timed event from two instants. */
function timed(
  p: Partial<EventRow> & { id?: string },
  start: string,
  end: string,
): EventRow {
  return ev({ ...p, starts_at: start, ends_at: end, is_all_day: false });
}

function allDay(
  p: Partial<EventRow> & { id?: string },
  start: string,
  end: string,
): EventRow {
  return ev({ ...p, start_date: start, end_date: end, is_all_day: true });
}

/** A one-hour event at 10:00 UTC on `day`. */
function oneOff(p: Partial<EventRow> & { id?: string }, day: string) {
  return timed(p, `${day}T10:00:00Z`, `${day}T11:00:00Z`);
}

function ov(
  p: Partial<OverrideRow> & { event_id: string; recurrence_id: string },
): OverrideRow {
  return {
    is_cancelled: false,
    title: null,
    starts_at: null,
    ends_at: null,
    start_date: null,
    end_date: null,
    location: null,
    status: null,
    ...p,
  };
}

function imported(
  p: Partial<ExternalOccurrenceRow> & { id: string },
  day: string,
): ExternalOccurrenceRow {
  return {
    calendar_id: "cal-1",
    calendar_name: "Schule",
    colour_hex: "#3366cc",
    member_ids: [],
    show_on_board: true,
    uid: "uid-1",
    starts_at: `${day}T08:00:00Z`,
    ends_at: `${day}T09:00:00Z`,
    all_day: false,
    start_date: null,
    end_date: null,
    title: "Elternabend",
    location: null,
    ...p,
  };
}

function search(
  query: string,
  events: EventRow[],
  extra: {
    overrides?: OverrideRow[];
    external?: ExternalOccurrenceRow[];
    limit?: number;
  } = {},
) {
  return searchOccurrences({
    query,
    events,
    overrides: extra.overrides ?? [],
    external: extra.external ?? [],
    today: TODAY,
    tz: TZ,
    limit: extra.limit,
  });
}

const dates = (occ: { local_start_date: string }[]) =>
  occ.map((o) => o.local_start_date);

/** A weekly Wednesday 17:00 (Berlin) series that began in June 2026. */
const weeklyTraining = (p: Partial<EventRow> = {}) =>
  timed(
    { id: "training", title: "Training", rrule: "FREQ=WEEKLY", ...p },
    "2026-06-03T15:00:00Z",
    "2026-06-03T16:00:00Z",
  );

// ---------------------------------------------------------------------------
// fold and searchTerms
// ---------------------------------------------------------------------------

Deno.test("fold lower-cases and spells umlauts out", () => {
  assertEquals(fold("Käse"), "kaese");
  assertEquals(fold("KÄSE"), "kaese");
  assertEquals(fold("Öl und Übung"), "oel und uebung");
});

Deno.test("fold turns ß into ss", () => {
  assertEquals(fold("Straße"), "strasse");
  assertEquals(fold("Fußball"), "fussball");
});

Deno.test("fold drops accents", () => {
  assertEquals(fold("café"), "cafe");
  assertEquals(fold("Crème brûlée"), "creme brulee");
  assertEquals(fold("Ñandú"), "nandu");
});

Deno.test("a query with umlauts finds its spelled-out form and the other way round", () => {
  assertEquals(searchTerms("Käse"), searchTerms("kaese"));
  assertEquals(searchTerms("café"), searchTerms("CAFE"));
  assertEquals(searchTerms("Straße"), ["strasse"]);
});

Deno.test("searchTerms splits on whitespace and ignores the edges", () => {
  assertEquals(searchTerms("  Zahn   Arzt \n"), ["zahn", "arzt"]);
});

Deno.test("a blank query has no terms", () => {
  assertEquals(searchTerms(""), []);
  assertEquals(searchTerms("   \t "), []);
});

// ---------------------------------------------------------------------------
// searchRank
// ---------------------------------------------------------------------------

Deno.test("searchRank is null when a term is in no field", () => {
  assertEquals(searchRank(["arzt", "kino"], ["Arzttermin", "Praxis"]), null);
  assertEquals(searchRank(["kino"], ["Arzttermin", null, undefined]), null);
});

Deno.test("searchRank is null without terms", () => {
  assertEquals(searchRank([], ["Arzttermin"]), null);
});

Deno.test("searchRank prefers the title's start to a word's start to the middle of a word", () => {
  const prefix = searchRank(["arzt"], ["Arzttermin"]);
  const wordStart = searchRank(["arzt"], ["Termin beim Arzt"]);
  const inside = searchRank(["arzt"], ["Zahnarzt"]);
  assert(prefix !== null && wordStart !== null && inside !== null);
  assert(prefix < wordStart, "title prefix beats word start");
  assert(wordStart < inside, "word start beats inside a word");
});

Deno.test("searchRank still finds a term inside a word", () => {
  assert(searchRank(["arzt"], ["Zahnarzt"]) !== null);
});

Deno.test("searchRank folds the fields as well", () => {
  assert(searchRank(["kaese"], ["Käsefondue"]) !== null);
  assertEquals(
    searchRank(["strasse"], ["Straße 5"]),
    searchRank(["strasse"], ["Strasse 5"]),
  );
});

Deno.test("searchRank prefers an earlier field to a later one", () => {
  const inTitle = searchRank(["park"], ["Park", "Park", "Park"]);
  const inLocation = searchRank(["park"], ["Termin", "Park", "Notiz"]);
  const inDescription = searchRank(["park"], ["Termin", "Ort", "Park"]);
  assert(inTitle !== null && inLocation !== null && inDescription !== null);
  assert(inTitle < inLocation, "title beats location");
  assert(inLocation < inDescription, "location beats description");
});

Deno.test("searchRank takes the best field of each term", () => {
  // A weaker kind in an earlier field loses to a better kind in the same field only,
  // so the title's start is found first.
  assertEquals(
    searchRank(["park"], ["Park und Spiel", "Im Park"]),
    searchRank(["park"], ["Park und Spiel"]),
  );
});

Deno.test("searchRank needs every term, which may be in different fields", () => {
  const split = searchRank(["zahn", "praxis"], ["Zahnarzt", "Praxis Mai"]);
  assert(split !== null);
  assertEquals(searchRank(["zahn", "praxis"], ["Zahnarzt", "Rathaus"]), null);
  // Both in the title ranks better than the same words split over two fields.
  const together = searchRank(["zahn", "arzt"], ["Zahnarzt Praxis"]);
  assert(together !== null);
  assert(together < split);
});

Deno.test("searchRank ignores empty and missing fields", () => {
  assert(searchRank(["kino"], [null, "", "  ", "Kino"]) !== null);
});

// ---------------------------------------------------------------------------
// searchOccurrences: one-off events
// ---------------------------------------------------------------------------

Deno.test("a blank query finds nothing", () => {
  const events = [oneOff({ title: "Zahnarzt" }, "2026-12-10")];
  for (const query of ["", "   ", "\n\t"]) {
    assertEquals(search(query, events), {
      upcoming: [],
      past: [],
      more: false,
    });
  }
});

Deno.test("a query that matches nothing finds nothing", () => {
  const result = search("kino", [oneOff({ title: "Zahnarzt" }, "2026-12-10")]);
  assertEquals(result, { upcoming: [], past: [], more: false });
});

Deno.test("a one-off event far in the past is found, in past", () => {
  const result = search("zahnarzt", [
    oneOff({ id: "old", title: "Zahnarzt" }, "2021-03-10"),
  ]);
  assertEquals(result.upcoming, []);
  assertEquals(result.past.map((o) => o.event_id), ["old"]);
  assertEquals(result.past[0].local_start_date, "2021-03-10");
  assertEquals(result.more, false);
});

Deno.test("a one-off event far in the future is found, in upcoming", () => {
  const result = search("zahnarzt", [
    oneOff({ id: "far", title: "Zahnarzt" }, "2031-05-02"),
  ]);
  assertEquals(result.past, []);
  assertEquals(result.upcoming.map((o) => o.event_id), ["far"]);
  assertEquals(result.upcoming[0].local_start_date, "2031-05-02");
  assertFalse(result.upcoming[0].is_recurring);
});

Deno.test("an event today is upcoming, one of yesterday is past", () => {
  const result = search("arzt", [
    oneOff({ id: "today", title: "Arzt heute" }, TODAY),
    oneOff({ id: "yesterday", title: "Arzt gestern" }, "2026-11-27"),
  ]);
  assertEquals(result.upcoming.map((o) => o.event_id), ["today"]);
  assertEquals(result.past.map((o) => o.event_id), ["yesterday"]);
});

Deno.test("an all-day event that began before today and runs on is upcoming", () => {
  const result = search("ferien", [
    allDay({ id: "holiday", title: "Ferien" }, "2026-11-25", "2026-12-02"),
  ]);
  assertEquals(result.upcoming.map((o) => o.event_id), ["holiday"]);
  assertEquals(result.past, []);
});

Deno.test("a match on the title is found regardless of case and umlauts", () => {
  const result = search("KAESE", [
    oneOff({ id: "e", title: "Käsefondue" }, "2026-12-12"),
  ]);
  assertEquals(result.upcoming.map((o) => o.event_id), ["e"]);
});

Deno.test("an event is found by its location", () => {
  const result = search("cafe", [
    oneOff(
      { id: "e", title: "Treffen", location: "Café Central" },
      "2026-12-12",
    ),
    oneOff(
      { id: "other", title: "Treffen", location: "Rathaus" },
      "2026-12-13",
    ),
  ]);
  assertEquals(result.upcoming.map((o) => o.event_id), ["e"]);
  assertEquals(result.upcoming[0].location, "Café Central");
});

Deno.test("an event is found by its description", () => {
  const result = search("geschenk", [
    oneOff(
      { id: "e", title: "Feier", description: "Geschenk mitbringen" },
      "2026-12-12",
    ),
    oneOff({ id: "other", title: "Feier" }, "2026-12-13"),
  ]);
  assertEquals(result.upcoming.map((o) => o.event_id), ["e"]);
  assertEquals(result.upcoming[0].description, "Geschenk mitbringen");
});

Deno.test("every term has to be found, in the title, location or description", () => {
  const events = [
    oneOff(
      { id: "both", title: "Zahnarzt", location: "Praxis Mai" },
      "2026-12-10",
    ),
    oneOff({ id: "one", title: "Zahnarzt", location: "Rathaus" }, "2026-12-11"),
  ];
  assertEquals(
    search("zahn praxis", events).upcoming.map((o) => o.event_id),
    ["both"],
  );
});

Deno.test("a cancelled event is never found", () => {
  const result = search("zahnarzt", [
    oneOff(
      { id: "gone", title: "Zahnarzt", status: "cancelled" },
      "2026-12-10",
    ),
    oneOff({ id: "old", title: "Zahnarzt", status: "cancelled" }, "2021-03-10"),
    weeklyTraining({ id: "series", title: "Zahnarzt", status: "cancelled" }),
  ]);
  assertEquals(result, { upcoming: [], past: [], more: false });
});

Deno.test("a tentative event is found", () => {
  const result = search("zahnarzt", [
    oneOff(
      { id: "maybe", title: "Zahnarzt", status: "tentative" },
      "2026-12-10",
    ),
  ]);
  assertEquals(result.upcoming.map((o) => o.event_id), ["maybe"]);
  assertEquals(result.upcoming[0].status, "tentative");
});

// ---------------------------------------------------------------------------
// searchOccurrences: series
// ---------------------------------------------------------------------------

Deno.test("a weekly series is one result: its next date", () => {
  const result = search("training", [weeklyTraining()]);
  assertEquals(result.upcoming.length, 1);
  assertEquals(result.past, []);
  const [next] = result.upcoming;
  assertEquals(next.event_id, "training");
  assertEquals(next.local_start_date, "2026-12-02");
  assertEquals(next.local_starts, "17:00");
  assert(next.is_recurring);
  assertFalse(next.is_override);
  assertEquals(result.more, false);
});

Deno.test("a series whose next date is today is found today", () => {
  const result = search("training", [
    // A Saturday series: 2026-11-28 is the one to come.
    timed(
      { id: "sat", title: "Training", rrule: "FREQ=WEEKLY" },
      "2026-06-06T15:00:00Z",
      "2026-06-06T16:00:00Z",
    ),
  ]);
  assertEquals(dates(result.upcoming), ["2026-11-28"]);
});

Deno.test("a series that ended is one result in past: its last date", () => {
  const result = search("training", [
    weeklyTraining({ rrule: "FREQ=WEEKLY;UNTIL=20261112T000000Z" }),
  ]);
  assertEquals(result.upcoming, []);
  assertEquals(result.past.length, 1);
  assertEquals(result.past[0].local_start_date, "2026-11-11");
  assert(result.past[0].is_recurring);
});

Deno.test("a series that ended more than a year ago is not found", () => {
  const result = search("training", [
    timed(
      {
        id: "old",
        title: "Training",
        rrule: "FREQ=WEEKLY;UNTIL=20250301T000000Z",
      },
      "2025-01-01T15:00:00Z",
      "2025-01-01T16:00:00Z",
    ),
  ]);
  assertEquals(result, { upcoming: [], past: [], more: false });
});

Deno.test("a yearly all-day series has its next date found", () => {
  const result = search("geburtstag", [
    allDay(
      {
        id: "birthday",
        title: "Geburtstag Oma",
        rrule: "FREQ=YEARLY",
      },
      "2015-03-15",
      "2015-03-15",
    ),
  ]);
  assertEquals(result.past, []);
  assertEquals(result.upcoming.length, 1);
  const [next] = result.upcoming;
  assertEquals(next.local_start_date, "2027-03-15");
  assert(next.all_day);
  assert(next.is_recurring);
});

Deno.test("a rdates-only series is one result too", () => {
  const result = search("kurs", [
    timed(
      { id: "course", title: "Kurs", rdates: ["2026-12-10", "2026-12-17"] },
      "2026-12-03T15:00:00Z",
      "2026-12-03T16:00:00Z",
    ),
  ]);
  assertEquals(dates(result.upcoming), ["2026-12-03"]);
  assertEquals(result.past, []);
});

// ---------------------------------------------------------------------------
// searchOccurrences: overrides
// ---------------------------------------------------------------------------

Deno.test("a renamed date of a series is found by its new name, and only that date", () => {
  const training = weeklyTraining();
  const renamed = ov({
    event_id: "training",
    recurrence_id: "2026-12-02T16:00:00Z",
    title: "Turnier",
  });

  const found = search("turnier", [training], { overrides: [renamed] });
  assertEquals(found.past, []);
  assertEquals(found.upcoming.length, 1);
  assertEquals(found.upcoming[0].title, "Turnier");
  assertEquals(found.upcoming[0].local_start_date, "2026-12-02");
  assert(found.upcoming[0].is_override);
  assert(found.upcoming[0].is_recurring);
});

Deno.test("a renamed next date is not the series' next one for the old name", () => {
  const training = weeklyTraining();
  const renamed = ov({
    event_id: "training",
    recurrence_id: "2026-12-02T16:00:00Z",
    title: "Turnier",
  });

  const found = search("training", [training], { overrides: [renamed] });
  assertEquals(found.upcoming.length, 1);
  assertEquals(found.upcoming[0].title, "Training");
  assertEquals(found.upcoming[0].local_start_date, "2026-12-09");
  assertFalse(found.upcoming[0].is_override);
});

Deno.test("a date given a new location is found by it", () => {
  const moved = ov({
    event_id: "training",
    recurrence_id: "2026-12-09T16:00:00Z",
    location: "Schwimmhalle",
  });
  const found = search("schwimmhalle", [weeklyTraining()], {
    overrides: [moved],
  });
  assertEquals(dates(found.upcoming), ["2026-12-09"]);
  assertEquals(found.upcoming[0].location, "Schwimmhalle");
});

Deno.test("a cancelled next date makes the date after the result", () => {
  const cancelled = ov({
    event_id: "training",
    recurrence_id: "2026-12-02T16:00:00Z",
    is_cancelled: true,
  });
  const found = search("training", [weeklyTraining()], {
    overrides: [cancelled],
  });
  assertEquals(dates(found.upcoming), ["2026-12-09"]);
  assertEquals(found.past, []);
});

Deno.test("an override of another series does not make a series match", () => {
  const found = search("turnier", [weeklyTraining()], {
    overrides: [
      ov({
        event_id: "someone-else",
        recurrence_id: "2026-12-02T16:00:00Z",
        title: "Turnier",
      }),
    ],
  });
  assertEquals(found, { upcoming: [], past: [], more: false });
});

Deno.test("an all-day date of a series can be renamed by its override", () => {
  const birthday = allDay(
    { id: "birthday", title: "Geburtstag", rrule: "FREQ=YEARLY" },
    "2015-03-15",
    "2015-03-15",
  );
  // The all-day instance is identified by the start of its local day: 15 March 2027 is
  // CET, so midnight Berlin is 23:00 UTC the evening before.
  const renamed = ov({
    event_id: "birthday",
    recurrence_id: "2027-03-14T23:00:00Z",
    title: "Grosse Feier",
  });
  const found = search("feier", [birthday], { overrides: [renamed] });
  assertEquals(found.upcoming.length, 1);
  assertEquals(found.upcoming[0].local_start_date, "2027-03-15");
  assertEquals(found.upcoming[0].title, "Grosse Feier");
  assert(found.upcoming[0].is_override);
});

// ---------------------------------------------------------------------------
// searchOccurrences: imported appointments
// ---------------------------------------------------------------------------

Deno.test("imported rows of one source collapse to the next one", () => {
  const rows = [
    imported({ id: "r1" }, "2026-11-10"),
    imported({ id: "r2" }, "2026-12-05"),
    imported({ id: "r3" }, "2026-12-12"),
    imported({ id: "r4" }, "2027-01-09"),
  ];
  const found = search("elternabend", [], { external: rows });
  assertEquals(found.past, []);
  assertEquals(found.upcoming.length, 1);
  const [next] = found.upcoming;
  assertEquals(next.source, "imported");
  assertEquals(next.id, "imported|r2");
  assertEquals(next.event_id, "cal-1|uid-1");
  assertEquals(next.local_start_date, "2026-12-05");
});

Deno.test("imported rows of a source that is over collapse to the last one", () => {
  const rows = [
    imported({ id: "r3" }, "2026-10-20"),
    imported({ id: "r1" }, "2026-09-01"),
    imported({ id: "r2" }, "2026-10-01"),
  ];
  const found = search("elternabend", [], { external: rows });
  assertEquals(found.upcoming, []);
  assertEquals(found.past.map((o) => o.id), ["imported|r3"]);
  assertEquals(found.past[0].source, "imported");
});

Deno.test("imported rows of different sources stay separate results", () => {
  const rows = [
    imported({ id: "a1", uid: "uid-a" }, "2026-12-05"),
    imported({ id: "a2", uid: "uid-a" }, "2026-12-12"),
    imported({ id: "b1", uid: "uid-b" }, "2026-12-08"),
    imported({ id: "c1", uid: "uid-a", calendar_id: "cal-2" }, "2026-12-20"),
  ];
  const found = search("elternabend", [], { external: rows });
  assertEquals(found.upcoming.map((o) => o.id), [
    "imported|a1",
    "imported|b1",
    "imported|c1",
  ]);
});

Deno.test("an imported appointment is found by its location, not by a description", () => {
  const rows = [
    imported(
      { id: "r1", title: "Schulfest", location: "Turnhalle" },
      "2026-12-05",
    ),
  ];
  assertEquals(
    search("turnhalle", [], { external: rows }).upcoming.map((o) => o.id),
    ["imported|r1"],
  );
  assertEquals(search("lehrer", [], { external: rows }).upcoming, []);
});

Deno.test("an imported all-day appointment is found", () => {
  const rows = [
    imported(
      {
        id: "r1",
        title: "Schulfrei",
        all_day: true,
        starts_at: null,
        ends_at: null,
        start_date: "2026-12-07",
        end_date: "2026-12-07",
      },
      "2026-12-07",
    ),
  ];
  const found = search("schulfrei", [], { external: rows });
  assertEquals(dates(found.upcoming), ["2026-12-07"]);
  assert(found.upcoming[0].all_day);
});

// ---------------------------------------------------------------------------
// searchOccurrences: order and limit
// ---------------------------------------------------------------------------

Deno.test("upcoming: a title that has every term comes first, then the soonest", () => {
  const events = [
    // Only in the location: later than the title matches although it is soonest.
    oneOff(
      { id: "place", title: "Kurs", location: "Schwimmen Halle" },
      "2026-12-01",
    ),
    oneOff({ id: "late", title: "Schwimmen Kurs" }, "2026-12-20"),
    oneOff({ id: "soon", title: "Kurs im Schwimmen" }, "2026-12-10"),
    oneOff(
      { id: "note", title: "Kurs", description: "Schwimmen" },
      "2026-12-02",
    ),
  ];
  const found = search("schwimmen kurs", events);
  assertEquals(found.upcoming.map((o) => o.event_id), [
    "soon",
    "late",
    "place",
    "note",
  ]);
});

Deno.test("upcoming: equally good matches come soonest first", () => {
  const events = [
    oneOff({ id: "c", title: "Kino" }, "2027-02-01"),
    oneOff({ id: "a", title: "Kino" }, "2026-12-01"),
    oneOff({ id: "b", title: "Kino" }, "2026-12-15"),
  ];
  assertEquals(
    search("kino", events).upcoming.map((o) => o.event_id),
    ["a", "b", "c"],
  );
});

Deno.test("past: a title that has every term comes first, then the latest", () => {
  const events = [
    oneOff({ id: "old", title: "Kino" }, "2024-05-05"),
    oneOff({ id: "recent", title: "Kino" }, "2026-10-01"),
    oneOff({ id: "place", title: "Film", location: "Kino" }, "2026-11-20"),
    oneOff({ id: "mid", title: "Kino" }, "2025-06-01"),
  ];
  assertEquals(
    search("kino", events).past.map((o) => o.event_id),
    ["recent", "mid", "old", "place"],
  );
});

Deno.test("past: the latest comes first", () => {
  const events = [
    oneOff({ id: "a", title: "Kino" }, "2025-06-01"),
    oneOff({ id: "b", title: "Kino" }, "2026-10-01"),
    oneOff({ id: "c", title: "Kino" }, "2026-01-01"),
  ];
  assertEquals(
    search("kino", events).past.map((o) => o.event_id),
    ["b", "c", "a"],
  );
});

Deno.test("upcoming and past are returned together", () => {
  const events = [
    oneOff({ id: "next", title: "Kino" }, "2026-12-05"),
    oneOff({ id: "last", title: "Kino" }, "2026-11-05"),
  ];
  const found = search("kino", events);
  assertEquals(found.upcoming.map((o) => o.event_id), ["next"]);
  assertEquals(found.past.map((o) => o.event_id), ["last"]);
  assertEquals(found.more, false);
});

Deno.test("a series, a one-off and an imported row for one query are ordered together", () => {
  const found = search("training", [
    weeklyTraining(),
    oneOff({ id: "extra", title: "Training Camp" }, "2026-12-01"),
  ], {
    external: [
      imported({ id: "r1", title: "Training Elternabend" }, "2026-12-03"),
    ],
  });
  assertEquals(found.upcoming.map((o) => o.event_id), [
    "extra",
    "training",
    "cal-1|uid-1",
  ]);
});

function manyOneOffs(count: number, from: string, direction: 1 | -1) {
  const start = Date.parse(`${from}T00:00:00Z`);
  return Array.from({ length: count }, (_, i) => {
    const day = new Date(start + direction * i * 86_400_000)
      .toISOString().slice(0, 10);
    return oneOff({ id: `e${i}`, title: "Kino" }, day);
  });
}

Deno.test("limit cuts the upcoming side and sets more", () => {
  const events = manyOneOffs(5, "2026-12-01", 1);
  const found = search("kino", events, { limit: 2 });
  assertEquals(found.upcoming.map((o) => o.event_id), ["e0", "e1"]);
  assertEquals(found.past, []);
  assert(found.more);
});

Deno.test("limit cuts the past side and sets more", () => {
  const events = manyOneOffs(5, "2026-11-20", -1);
  const found = search("kino", events, { limit: 3 });
  assertEquals(found.past.map((o) => o.event_id), ["e0", "e1", "e2"]);
  assertEquals(found.upcoming, []);
  assert(found.more);
});

Deno.test("limit applies to each side", () => {
  const events = [
    ...manyOneOffs(3, "2026-12-01", 1),
    ...manyOneOffs(3, "2026-11-20", -1).map((e) => ({ ...e, id: `p${e.id}` })),
  ];
  const found = search("kino", events, { limit: 2 });
  assertEquals(found.upcoming.length, 2);
  assertEquals(found.past.length, 2);
  assert(found.more);
});

Deno.test("more stays false when a side has exactly limit results", () => {
  const events = manyOneOffs(2, "2026-12-01", 1);
  const found = search("kino", events, { limit: 2 });
  assertEquals(found.upcoming.length, 2);
  assertFalse(found.more);
});

Deno.test("without a limit the default applies", () => {
  const events = manyOneOffs(DEFAULT_LIMIT + 5, "2026-12-01", 1);
  const found = search("kino", events);
  assertEquals(found.upcoming.length, DEFAULT_LIMIT);
  assert(found.more);
});

Deno.test("exactly the default number of results is not more", () => {
  const found = search("kino", manyOneOffs(DEFAULT_LIMIT, "2026-12-01", 1));
  assertEquals(found.upcoming.length, DEFAULT_LIMIT);
  assertFalse(found.more);
});

Deno.test("a limit below one or above the maximum is clamped", () => {
  const events = manyOneOffs(MAX_LIMIT + 5, "2026-12-01", 1);
  assertEquals(search("kino", events, { limit: 0 }).upcoming.length, 1);
  const found = search("kino", events, { limit: MAX_LIMIT + 500 });
  assertEquals(found.upcoming.length, MAX_LIMIT);
  assert(found.more);
});
