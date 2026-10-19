import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1.0.13";
import {
  type EventRow,
  expand,
  type ExternalOccurrenceRow,
  importedOccurrence,
  type OverrideRow,
  sortOccurrences,
  validateRrule,
} from "./occurrences.ts";

const TZ = "Europe/Berlin";
const HOUSEHOLD = "Europe/Berlin";

function ev(p: Partial<EventRow> & { id?: string }): EventRow {
  return {
    id: p.id ?? "e1",
    calendar_id: "c1",
    title: "Turnen",
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

/** Timed event from a Berlin wall-clock span (CET/CEST resolved by the instant). */
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

const dates = (occ: { local_start_date: string }[]) =>
  occ.map((o) => o.local_start_date);

Deno.test("single timed event inside the window", () => {
  const occ = expand(
    [timed({}, "2026-10-14T14:00:00Z", "2026-10-14T15:00:00Z")],
    [],
    "2026-10-14",
    "2026-10-14",
    HOUSEHOLD,
  );
  assertEquals(occ.length, 1);
  assertEquals(occ[0].id, "e1|single");
  assertEquals(occ[0].recurrence_id, null);
  assertEquals(occ[0].start, "2026-10-14T14:00:00Z");
  assertEquals(occ[0].end, "2026-10-14T15:00:00Z");
  assertEquals(occ[0].local_starts, "16:00");
  assertEquals(occ[0].local_ends, "17:00");
  assertEquals(occ[0].local_start_date, "2026-10-14");
  assertEquals(occ[0].local_end_date, "2026-10-14");
  assertEquals(occ[0].is_recurring, false);
  assertEquals(occ[0].is_override, false);
});

Deno.test("single timed event outside the window is not emitted", () => {
  const occ = expand(
    [timed({}, "2026-10-14T14:00:00Z", "2026-10-14T15:00:00Z")],
    [],
    "2026-10-15",
    "2026-10-16",
    HOUSEHOLD,
  );
  assertEquals(occ.length, 0);
});

Deno.test("window edges: overlap counts, touching at the edge does not", () => {
  // 13th 23:00 to 14th 01:00 overlaps the 14th.
  const overlapping = timed(
    { id: "a" },
    "2026-10-13T21:00:00Z",
    "2026-10-13T23:00:00Z",
  );
  // 13th 22:00 to 14th 00:00 ends exactly at the window start: excluded.
  const touching = timed(
    { id: "b" },
    "2026-10-13T20:00:00Z",
    "2026-10-13T22:00:00Z",
  );
  const occ = expand(
    [overlapping, touching],
    [],
    "2026-10-14",
    "2026-10-14",
    HOUSEHOLD,
  );
  assertEquals(occ.map((o) => o.event_id), ["a"]);
  assertEquals(occ[0].local_start_date, "2026-10-13");
  assertEquals(occ[0].local_end_date, "2026-10-14");
});

Deno.test("weekly 07:00 Berlin series stays at 07:00 across both DST changes", () => {
  // Sundays from 2026-03-01; DST starts 2026-03-29 and ends 2026-10-25.
  const series = timed(
    { rrule: "FREQ=WEEKLY" },
    "2026-03-01T06:00:00Z", // 07:00 CET
    "2026-03-01T07:00:00Z",
  );
  const occ = expand([series], [], "2026-03-01", "2026-10-31", HOUSEHOLD);
  assert(occ.length >= 34, `expected ~35 Sundays, got ${occ.length}`);
  for (const o of occ) {
    assertEquals(o.local_starts, "07:00", o.local_start_date);
    assertEquals(o.local_ends, "08:00", o.local_start_date);
  }
  const byDate = new Map(occ.map((o) => [o.local_start_date, o]));
  // Before the spring change: CET, 07:00 local = 06:00Z.
  assertEquals(byDate.get("2026-03-22")?.start, "2026-03-22T06:00:00Z");
  // After the spring change: CEST, 07:00 local = 05:00Z.
  assertEquals(byDate.get("2026-03-29")?.start, "2026-03-29T05:00:00Z");
  assertEquals(byDate.get("2026-10-18")?.start, "2026-10-18T05:00:00Z");
  // After the autumn change: CET again, 06:00Z.
  assertEquals(byDate.get("2026-10-25")?.start, "2026-10-25T06:00:00Z");
});

Deno.test("event 23:30 to 00:30 shows on both days", () => {
  const late = timed(
    { rrule: null },
    "2026-10-14T21:30:00Z",
    "2026-10-14T22:30:00Z",
  );
  const day1 = expand([late], [], "2026-10-14", "2026-10-14", HOUSEHOLD);
  const day2 = expand([late], [], "2026-10-15", "2026-10-15", HOUSEHOLD);
  const day3 = expand([late], [], "2026-10-16", "2026-10-16", HOUSEHOLD);
  assertEquals(day1.length, 1);
  assertEquals(day2.length, 1);
  assertEquals(day3.length, 0);
  // Crossing midnight: 23:30 to 00:30 local.
  const crossing = timed(
    { id: "x" },
    "2026-10-14T21:30:00Z",
    "2026-10-14T22:30:00Z",
  );
  const cross =
    expand([crossing], [], "2026-10-14", "2026-10-14", HOUSEHOLD)[0];
  assertEquals(cross.local_starts, "23:30");
  assertEquals(cross.local_ends, "00:30");
  assertEquals(cross.local_start_date, "2026-10-14");
  assertEquals(cross.local_end_date, "2026-10-15");
});

Deno.test("all-day single day (birthday): local midnights, inclusive end date", () => {
  const birthday = allDay({ title: "Geburtstag" }, "2026-10-20", "2026-10-20");
  const occ = expand([birthday], [], "2026-10-20", "2026-10-20", HOUSEHOLD);
  assertEquals(occ.length, 1);
  assertEquals(occ[0].all_day, true);
  assertEquals(occ[0].start, "2026-10-19T22:00:00Z"); // 00:00 CEST
  assertEquals(occ[0].end, "2026-10-20T22:00:00Z"); // 00:00 on the 21st, CEST
  assertEquals(occ[0].local_start_date, "2026-10-20");
  assertEquals(occ[0].local_end_date, "2026-10-20");
  assertEquals(occ[0].local_starts, null);
  assertEquals(occ[0].local_ends, null);
});

Deno.test("3-day all-day trip overlapping the window start is included", () => {
  const trip = allDay({ title: "Reise" }, "2026-10-10", "2026-10-12");
  const occ = expand([trip], [], "2026-10-12", "2026-10-14", HOUSEHOLD);
  assertEquals(occ.length, 1);
  assertEquals(occ[0].start, "2026-10-09T22:00:00Z");
  assertEquals(occ[0].end, "2026-10-12T22:00:00Z"); // midnight after the 12th
  assertEquals(occ[0].local_start_date, "2026-10-10");
  assertEquals(occ[0].local_end_date, "2026-10-12");
  // Window starting on the day after the trip's last day: excluded.
  assertEquals(
    expand([trip], [], "2026-10-13", "2026-10-14", HOUSEHOLD).length,
    0,
  );
});

Deno.test("FREQ=WEEKLY;BYDAY=MO,WE;INTERVAL=2 alternates weeks", () => {
  // Monday 2026-10-05 is DTSTART; weeks of 5th and 19th, not the 12th.
  const series = timed(
    { rrule: "FREQ=WEEKLY;BYDAY=MO,WE;INTERVAL=2" },
    "2026-10-05T08:00:00Z",
    "2026-10-05T09:00:00Z",
  );
  const occ = expand([series], [], "2026-10-01", "2026-10-31", HOUSEHOLD);
  assertEquals(dates(occ), [
    "2026-10-05",
    "2026-10-07",
    "2026-10-19",
    "2026-10-21",
  ]);
});

Deno.test("DTSTART is included even when it does not match BYDAY", () => {
  // Tuesday 2026-10-06 is DTSTART; rule is Mon/Wed weekly.
  const series = timed(
    { rrule: "FREQ=WEEKLY;BYDAY=MO,WE" },
    "2026-10-06T08:00:00Z",
    "2026-10-06T09:00:00Z",
  );
  const occ = expand([series], [], "2026-10-05", "2026-10-12", HOUSEHOLD);
  assertEquals(dates(occ), ["2026-10-06", "2026-10-07", "2026-10-12"]);
});

Deno.test("COUNT=3 stops after three occurrences, counted from DTSTART", () => {
  const series = timed(
    { rrule: "FREQ=WEEKLY;BYDAY=MO;COUNT=3" },
    "2026-10-05T08:00:00Z",
    "2026-10-05T09:00:00Z",
  );
  assertEquals(
    dates(expand([series], [], "2026-10-01", "2026-11-30", HOUSEHOLD)),
    [
      "2026-10-05",
      "2026-10-12",
      "2026-10-19",
    ],
  );
  assertEquals(
    expand([series], [], "2026-10-20", "2026-11-30", HOUSEHOLD).length,
    0,
  );
});

Deno.test("UNTIL date-only is inclusive of that local date", () => {
  const series = timed(
    { rrule: "FREQ=DAILY;UNTIL=20261016" },
    "2026-10-14T08:00:00Z",
    "2026-10-14T09:00:00Z",
  );
  const occ = expand([series], [], "2026-10-01", "2026-10-31", HOUSEHOLD);
  assertEquals(dates(occ), ["2026-10-14", "2026-10-15", "2026-10-16"]);
});

Deno.test("UTC UNTIL is converted to the event's local time", () => {
  // 2026-10-16T06:00Z is 08:00 CEST on the 16th, before that day's 10:00 occurrence: it is excluded.
  const series = timed(
    { rrule: "FREQ=DAILY;UNTIL=20261016T060000Z" },
    "2026-10-14T08:00:00Z",
    "2026-10-14T09:00:00Z",
  );
  assertEquals(
    dates(expand([series], [], "2026-10-01", "2026-10-31", HOUSEHOLD)),
    [
      "2026-10-14",
      "2026-10-15",
    ],
  );
});

Deno.test("MONTHLY BYMONTHDAY=31 skips short months", () => {
  const series = allDay(
    { rrule: "FREQ=MONTHLY;BYMONTHDAY=31" },
    "2026-01-31",
    "2026-01-31",
  );
  const occ = expand([series], [], "2026-01-01", "2026-12-31", HOUSEHOLD);
  assertEquals(dates(occ), [
    "2026-01-31",
    "2026-03-31",
    "2026-05-31",
    "2026-07-31",
    "2026-08-31",
    "2026-10-31",
    "2026-12-31",
  ]);
});

Deno.test("MONTHLY BYDAY=-1FR is the last Friday of each month", () => {
  const series = timed(
    { rrule: "FREQ=MONTHLY;BYDAY=-1FR" },
    "2026-01-30T08:00:00Z",
    "2026-01-30T09:00:00Z",
  );
  const occ = expand([series], [], "2026-01-01", "2026-03-31", HOUSEHOLD);
  assertEquals(dates(occ), ["2026-01-30", "2026-02-27", "2026-03-27"]);
});

Deno.test("rdates-only rota yields exactly those dates with recurrence_id set", () => {
  const rota = timed(
    { rdates: ["2026-10-03", "2026-10-10", "2026-10-17"] },
    "2026-10-03T05:00:00Z",
    "2026-10-03T13:00:00Z",
  );
  const occ = expand([rota], [], "2026-10-01", "2026-10-31", HOUSEHOLD);
  assertEquals(dates(occ), ["2026-10-03", "2026-10-10", "2026-10-17"]);
  for (const o of occ) {
    assertEquals(o.local_starts, "07:00");
    assertEquals(o.is_recurring, true);
    assert(o.recurrence_id !== null);
  }
  assertEquals(occ[1].recurrence_id, "2026-10-10T05:00:00Z");
  assertEquals(occ[1].id, "e1|2026-10-10T05:00:00Z");
});

Deno.test("exdates remove one occurrence by local start date", () => {
  const series = timed(
    { rrule: "FREQ=WEEKLY", exdates: ["2026-10-12"] },
    "2026-10-05T08:00:00Z",
    "2026-10-05T09:00:00Z",
  );
  const occ = expand([series], [], "2026-10-01", "2026-10-19", HOUSEHOLD);
  assertEquals(dates(occ), ["2026-10-05", "2026-10-19"]);
});

Deno.test("override moves an occurrence by two hours; another cancels one", () => {
  const series = timed(
    { rrule: "FREQ=WEEKLY" },
    "2026-10-05T08:00:00Z",
    "2026-10-05T09:00:00Z",
  );
  const overrides = [
    ov({
      event_id: "e1",
      recurrence_id: "2026-10-12T08:00:00Z",
      starts_at: "2026-10-12T10:00:00Z",
      ends_at: "2026-10-12T11:00:00Z",
    }),
    ov({
      event_id: "e1",
      recurrence_id: "2026-10-19T08:00:00Z",
      is_cancelled: true,
    }),
  ];
  const moved = expand(
    [series],
    overrides,
    "2026-10-12",
    "2026-10-12",
    HOUSEHOLD,
  );
  assertEquals(moved.length, 1);
  assertEquals(moved[0].is_override, true);
  assertEquals(moved[0].local_starts, "12:00");
  assertEquals(moved[0].local_ends, "13:00");
  assertEquals(moved[0].recurrence_id, "2026-10-12T08:00:00Z");
  assertEquals(moved[0].start, "2026-10-12T10:00:00Z");

  const all = expand(
    [series],
    overrides,
    "2026-10-05",
    "2026-10-26",
    HOUSEHOLD,
  );
  assertEquals(dates(all), ["2026-10-05", "2026-10-12", "2026-10-26"]);
});

Deno.test("override moving an occurrence out of the window removes it", () => {
  const series = timed(
    { rrule: "FREQ=WEEKLY" },
    "2026-10-05T08:00:00Z",
    "2026-10-05T09:00:00Z",
  );
  const overrides = [
    ov({
      event_id: "e1",
      recurrence_id: "2026-10-12T08:00:00Z",
      starts_at: "2026-10-20T08:00:00Z",
      ends_at: "2026-10-20T09:00:00Z",
    }),
  ];
  assertEquals(
    expand([series], overrides, "2026-10-12", "2026-10-12", HOUSEHOLD).length,
    0,
  );
  const later = expand(
    [series],
    overrides,
    "2026-10-20",
    "2026-10-20",
    HOUSEHOLD,
  );
  assertEquals(later.length, 1);
  assertEquals(later[0].is_override, true);
});

Deno.test("override moving an occurrence into the window adds it", () => {
  const series = timed(
    { rrule: "FREQ=WEEKLY" },
    "2026-10-05T08:00:00Z",
    "2026-10-05T09:00:00Z",
  );
  const overrides = [
    ov({
      event_id: "e1",
      recurrence_id: "2026-10-12T08:00:00Z",
      starts_at: "2026-10-07T08:00:00Z",
      ends_at: "2026-10-07T09:00:00Z",
    }),
  ];
  const occ = expand(
    [series],
    overrides,
    "2026-10-07",
    "2026-10-07",
    HOUSEHOLD,
  );
  assertEquals(occ.length, 1);
  assertEquals(occ[0].is_override, true);
  assertEquals(occ[0].recurrence_id, "2026-10-12T08:00:00Z");
});

Deno.test("status cancelled emits nothing (event and override)", () => {
  const cancelled = timed(
    { status: "cancelled" },
    "2026-10-14T14:00:00Z",
    "2026-10-14T15:00:00Z",
  );
  assertEquals(
    expand([cancelled], [], "2026-10-14", "2026-10-14", HOUSEHOLD).length,
    0,
  );

  const series = timed(
    { rrule: "FREQ=WEEKLY" },
    "2026-10-05T08:00:00Z",
    "2026-10-05T09:00:00Z",
  );
  const overrides = [
    ov({
      event_id: "e1",
      recurrence_id: "2026-10-12T08:00:00Z",
      status: "cancelled",
    }),
  ];
  assertEquals(
    dates(expand([series], overrides, "2026-10-01", "2026-10-19", HOUSEHOLD)),
    [
      "2026-10-05",
      "2026-10-19",
    ],
  );
});

Deno.test("validateRrule accepts the subset and rejects the rest", () => {
  for (
    const ok of [
      "FREQ=WEEKLY;BYDAY=MO,WE;INTERVAL=2",
      "FREQ=MONTHLY;BYDAY=-1FR",
      "FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=1",
      "FREQ=DAILY;COUNT=5",
      "FREQ=DAILY;UNTIL=20270701T000000Z",
      "FREQ=DAILY;UNTIL=20270701",
      "FREQ=MONTHLY;BYSETPOS=-1;BYDAY=MO,TU,WE,TH,FR;WKST=MO",
    ]
  ) {
    assert(validateRrule(ok), ok);
  }
  for (
    const bad of [
      "FREQ=HOURLY",
      "FREQ=DAILY;BYHOUR=7",
      "BYDAY=MO",
      "garbage",
      "",
      "FREQ=WEEKLY;BYDAY=1MO",
      "FREQ=WEEKLY;INTERVAL=0",
      "FREQ=MONTHLY;BYMONTHDAY=0",
      "FREQ=DAILY;COUNT=3;UNTIL=20270101",
      "FREQ=DAILY;FREQ=WEEKLY",
      "FREQ=DAILY;UNTIL=20271340",
    ]
  ) {
    assertFalse(validateRrule(bad), bad);
  }
});

Deno.test("results are sorted by start, all-day first, then title", () => {
  const events = [
    timed(
      { id: "z", title: "Zahnarzt" },
      "2026-10-14T05:00:00Z",
      "2026-10-14T06:00:00Z",
    ),
    timed(
      { id: "a", title: "Arzt" },
      "2026-10-14T06:00:00Z",
      "2026-10-14T07:00:00Z",
    ),
    timed(
      { id: "b", title: "Abholen" },
      "2026-10-14T06:00:00Z",
      "2026-10-14T07:00:00Z",
    ),
    allDay({ id: "g", title: "Geburtstag" }, "2026-10-14", "2026-10-14"),
  ];
  const occ = expand(events, [], "2026-10-14", "2026-10-14", HOUSEHOLD);
  assertEquals(occ.map((o) => o.title), [
    "Geburtstag",
    "Zahnarzt",
    "Abholen",
    "Arzt",
  ]);
});

Deno.test("presence events keep kind and presence_state", () => {
  const homeOffice = timed(
    { kind: "presence", presence_state: "home_office", title: "Homeoffice" },
    "2026-10-14T07:00:00Z",
    "2026-10-14T15:00:00Z",
  );
  const [occ] = expand([homeOffice], [], "2026-10-14", "2026-10-14", HOUSEHOLD);
  assertEquals(occ.kind, "presence");
  assertEquals(occ.presence_state, "home_office");
});

Deno.test("window is interpreted in the household timezone", () => {
  // 01:00 Berlin on the 14th is 19:00 New York on the 13th.
  const late = timed({}, "2026-10-13T23:00:00Z", "2026-10-14T00:00:00Z");
  assertEquals(
    expand([late], [], "2026-10-13", "2026-10-13", "America/New_York").length,
    1,
  );
  assertEquals(
    expand([late], [], "2026-10-14", "2026-10-14", "America/New_York").length,
    0,
  );
});

function imported(p: Partial<ExternalOccurrenceRow>): ExternalOccurrenceRow {
  return {
    id: "row-1",
    calendar_id: "cal-fussball",
    calendar_name: "Fussball",
    colour_hex: "#1E88E5",
    member_ids: ["emma"],
    show_on_board: false,
    uid: "match-1@club",
    starts_at: "2026-10-17T13:00:00Z",
    ends_at: "2026-10-17T14:50:00Z",
    all_day: false,
    start_date: null,
    end_date: null,
    title: "FC Stern - FC Mond",
    location: "Sportplatz",
    ...p,
  };
}

Deno.test("imported: a timed row is read-only, in the calendar's colour, with its members", () => {
  const occ = importedOccurrence(imported({}), TZ);
  assertEquals(occ.source, "imported");
  assertEquals(occ.colour_hex, "#1E88E5");
  assertEquals(occ.id, "imported|row-1");
  assertEquals(occ.event_id, "cal-fussball|match-1@club");
  assertEquals(occ.calendar_id, "cal-fussball");
  assertEquals(occ.attendee_ids, ["emma"]);
  assertEquals(occ.start, "2026-10-17T13:00:00Z");
  assertEquals(occ.end, "2026-10-17T14:50:00Z");
  assertEquals(occ.local_start_date, "2026-10-17");
  assertEquals(occ.local_starts, "15:00");
  assertEquals(occ.local_ends, "16:50");
  assertEquals(occ.kind, "appointment");
  assertEquals(occ.importance, "normal");
  assertEquals(occ.is_recurring, false);
  assertEquals(occ.location, "Sportplatz");
});

Deno.test("imported: a calendar on the board makes its rows key appointments", () => {
  assertEquals(importedOccurrence(imported({ show_on_board: true }), TZ).importance, "key");
});

Deno.test("imported: an all-day row keeps its inclusive dates, the instants are local midnights", () => {
  const occ = importedOccurrence(
    imported({
      all_day: true,
      starts_at: null,
      ends_at: null,
      start_date: "2026-10-20",
      end_date: "2026-10-22",
      title: "Sperrung",
      member_ids: [],
    }),
    TZ,
  );
  assertEquals(occ.all_day, true);
  assertEquals(occ.local_start_date, "2026-10-20");
  assertEquals(occ.local_end_date, "2026-10-22");
  assertEquals(occ.start, "2026-10-19T22:00:00Z", "Berlin midnight in summer time");
  assertEquals(occ.end, "2026-10-22T22:00:00Z", "midnight of 23 October, still summer time");
  assertEquals(occ.local_starts, null);
  assertEquals(occ.attendee_ids, []);
});

Deno.test("events are source 'event' with no colour of their own", () => {
  const [occ] = expand([ev({ id: "e1", starts_at: "2026-10-14T10:00:00Z", ends_at: "2026-10-14T11:00:00Z", is_all_day: false })], [], "2026-10-14", "2026-10-14", TZ);
  assertEquals(occ.source, "event");
  assertEquals(occ.colour_hex, null);
});

Deno.test("sortOccurrences merges events and imported rows by start, all-day first", () => {
  const event = expand(
    [ev({ id: "e1", title: "Zahnarzt", starts_at: "2026-10-14T16:00:00Z", ends_at: "2026-10-14T17:00:00Z", is_all_day: false })],
    [],
    "2026-10-14",
    "2026-10-14",
    TZ,
  );
  const rows = [
    importedOccurrence(imported({ id: "a", title: "Abfall", all_day: true, starts_at: null, ends_at: null, start_date: "2026-10-14", end_date: "2026-10-14" }), TZ),
    importedOccurrence(imported({ id: "b", title: "Spiel", starts_at: "2026-10-14T10:00:00Z", ends_at: "2026-10-14T11:00:00Z" }), TZ),
  ];
  assertEquals(sortOccurrences([...event, ...rows]).map((o) => o.title), ["Abfall", "Spiel", "Zahnarzt"]);
});
