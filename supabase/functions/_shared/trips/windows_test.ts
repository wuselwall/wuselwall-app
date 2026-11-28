import { assertEquals } from "jsr:@std/assert@1.0.19";
import {
  type CalendarRow,
  computeWindows,
  type HolidayInput,
  MAX_CONFLICTS,
  MAX_WINDOWS,
  type Traveller,
  type WindowInput,
} from "./windows.ts";

// Neutral names. Calendar facts the expectations rest on (2027): Feb 1 is a Monday, Mar 26 a
// Friday, Mar 29 a Monday, May 5 a Wednesday, May 6 a Thursday, May 15 a Saturday, May 17 a
// Monday.

const S1 = "school-1";
const S2 = "school-2";

const mum: Traveller = { id: "mum", kind: "adult", schoolId: null };
const anna: Traveller = { id: "anna", kind: "child", schoolId: S1 };
const ben: Traveller = { id: "ben", kind: "child", schoolId: S2 };
const tiny: Traveller = { id: "tiny", kind: "child", schoolId: null };

function ferien(
  schoolId: string | null,
  name: string,
  startsOn: string,
  endsOn: string,
  kind: HolidayInput["kind"] = "holiday",
): HolidayInput {
  return { schoolId, name, startsOn, endsOn, kind };
}

function input(p: Partial<WindowInput>): WindowInput {
  return {
    from: "2027-01-01",
    to: "2027-06-30",
    minDays: 4,
    travellers: [mum, anna],
    holidays: [],
    publicHolidays: [],
    occurrences: [],
    today: "2026-11-15",
    ...p,
  };
}

function row(p: Partial<CalendarRow> & { id: string }): CalendarRow {
  return {
    event_id: p.id,
    title: "Termin",
    kind: "appointment",
    presence_state: null,
    status: "confirmed",
    local_start_date: "2027-02-10",
    local_end_date: "2027-02-10",
    attendee_ids: [],
    trip_id: null,
    ...p,
  };
}

const sportferien = ferien(S1, "Sportferien", "2027-02-01", "2027-02-12");

// ---------------------------------------------------------------- school children

Deno.test("a child's Ferien run is a window with the weekends that touch it", () => {
  const [w, ...rest] = computeWindows(input({ holidays: [sportferien] }));
  assertEquals(rest, []);
  // Sat Jan 30 .. Sun Feb 14: the Ferien (Mon Feb 1 .. Fri Feb 12) and both weekends.
  assertEquals(w.from, "2027-01-30");
  assertEquals(w.to, "2027-02-14");
  assertEquals(w.days, 16);
  assertEquals(w.name, "Sportferien");
  assertEquals(w.kind, "holidays");
  assertEquals(w.leave_days, 10);
  assertEquals(w.partial, []);
});

Deno.test("a public holiday leaves no leave day and a weekday does", () => {
  const [w] = computeWindows(input({
    holidays: [sportferien],
    publicHolidays: [{ date: "2027-02-03", name: "Feiertag" }],
  }));
  assertEquals(w.leave_days, 9);
});

Deno.test("Ferien of another school do not free the child's days", () => {
  const w = computeWindows(input({
    holidays: [ferien(S2, "Sportferien", "2027-02-01", "2027-02-12")],
  }));
  assertEquals(w, []);
});

Deno.test("a row without a school applies to every child", () => {
  const w = computeWindows(input({
    travellers: [ben],
    holidays: [ferien(null, "Frühling", "2027-04-12", "2027-04-23")],
  }));
  assertEquals(w.map((x) => [x.from, x.to, x.name]), [
    ["2027-04-10", "2027-04-25", "Frühling"],
  ]);
});

Deno.test("where the children's Ferien differ the window is what they share, the rest is partial", () => {
  const w = computeWindows(input({
    travellers: [mum, anna, ben],
    holidays: [
      sportferien,
      ferien(S2, "Sportferien Süd", "2027-02-08", "2027-02-19"),
    ],
  }));
  assertEquals(w.length, 1);
  // Anna is free from Sat Jan 30, Ben until Sun Feb 21; both from Sat Feb 6 (Ben's weekend).
  assertEquals([w[0].from, w[0].to, w[0].days], [
    "2027-02-06",
    "2027-02-14",
    9,
  ]);
  assertEquals(w[0].name, "Sportferien / Sportferien Süd");
  assertEquals(w[0].partial, [
    { profile_id: "anna", from: "2027-01-30", to: "2027-02-14" },
    { profile_id: "ben", from: "2027-02-06", to: "2027-02-21" },
  ]);
});

Deno.test("children whose Ferien do not meet have no window", () => {
  const w = computeWindows(input({
    travellers: [anna, ben],
    holidays: [
      ferien(S1, "A", "2027-02-01", "2027-02-05"),
      ferien(S2, "B", "2027-02-15", "2027-02-19"),
    ],
  }));
  assertEquals(w, []);
});

Deno.test("a child without a school never limits a window", () => {
  const w = computeWindows(input({
    travellers: [anna, tiny],
    holidays: [sportferien],
  }));
  assertEquals(w.map((x) => [x.from, x.to]), [["2027-01-30", "2027-02-14"]]);
  assertEquals(w[0].partial, []);
});

Deno.test("a run shorter than min_days is no window, and min_days can be lowered", () => {
  const holidays = [
    ferien(S1, "Brückentag", "2027-02-26", "2027-02-26", "closure_day"),
  ];
  assertEquals(computeWindows(input({ holidays })), []);
  const [w] = computeWindows(input({ holidays, minDays: 3 }));
  assertEquals([w.from, w.to, w.days, w.leave_days], [
    "2027-02-26",
    "2027-02-28",
    3,
    1,
  ]);
  // Closure days name the window when there is no Ferien.
  assertEquals(w.name, "Brückentag");
});

Deno.test("public holidays join a weekend into a school window and name it", () => {
  const [w] = computeWindows(input({
    publicHolidays: [
      { date: "2027-03-26", name: "Karfreitag" },
      { date: "2027-03-29", name: "Ostermontag" },
    ],
  }));
  assertEquals([w.from, w.to, w.days, w.leave_days], [
    "2027-03-26",
    "2027-03-29",
    4,
    0,
  ]);
  assertEquals(w.name, "Karfreitag / Ostermontag");
  assertEquals(w.kind, "holidays");
});

Deno.test("a household-wide public holiday row counts like the region's", () => {
  const [w] = computeWindows(input({
    holidays: [
      ferien(
        null,
        "Familienfest",
        "2027-03-26",
        "2027-03-26",
        "public_holiday",
      ),
      ferien(
        null,
        "Familienfest 2",
        "2027-03-29",
        "2027-03-29",
        "public_holiday",
      ),
    ],
  }));
  assertEquals([w.from, w.to, w.leave_days], ["2027-03-26", "2027-03-29", 0]);
});

Deno.test("a running window starts today, a past one is dropped", () => {
  const holidays = [sportferien];
  const [running] = computeWindows(input({ holidays, today: "2027-02-08" }));
  assertEquals([running.from, running.to, running.days], [
    "2027-02-08",
    "2027-02-14",
    7,
  ]);
  assertEquals(computeWindows(input({ holidays, today: "2027-02-15" })), []);
});

Deno.test("windows are clipped to the range asked for", () => {
  const [w] = computeWindows(input({
    holidays: [sportferien],
    from: "2027-02-03",
    to: "2027-02-09",
  }));
  assertEquals([w.from, w.to], ["2027-02-03", "2027-02-09"]);
});

Deno.test("windows come sorted by start", () => {
  const w = computeWindows(input({
    holidays: [
      ferien(S1, "Frühling", "2027-04-12", "2027-04-23"),
      sportferien,
    ],
  }));
  assertEquals(w.map((x) => x.name), ["Sportferien", "Frühling"]);
});

// ---------------------------------------------------------------- long weekends

Deno.test("long weekend: a Thursday holiday with its bridge day and the weekend", () => {
  const [w, ...rest] = computeWindows(input({
    travellers: [mum],
    publicHolidays: [{ date: "2027-05-06", name: "Auffahrt" }],
  }));
  assertEquals(rest, []);
  assertEquals([w.from, w.to, w.days], ["2027-05-06", "2027-05-09", 4]);
  assertEquals(w.kind, "long_weekend");
  assertEquals(w.name, "Auffahrt");
  // Friday is a working day the adults need; Thursday is the holiday.
  assertEquals(w.leave_days, 1);
});

Deno.test("long weekend: a Monday holiday makes a three-day weekend, too short for min_days 4", () => {
  const publicHolidays = [{ date: "2027-05-17", name: "Pfingstmontag" }];
  assertEquals(
    computeWindows(input({ travellers: [mum], publicHolidays })),
    [],
  );
  const [w] = computeWindows(input({
    travellers: [mum],
    publicHolidays,
    minDays: 3,
  }));
  assertEquals([w.from, w.to, w.days, w.leave_days], [
    "2027-05-15",
    "2027-05-17",
    3,
    0,
  ]);
});

Deno.test("long weekend: at most two bridge days in one window, both sides offered", () => {
  const w = computeWindows(input({
    travellers: [mum],
    publicHolidays: [{ date: "2027-05-05", name: "Mittwoch" }],
    minDays: 5,
  }));
  // Sat May 1 .. Wed May 5 (Mon, Tue bridged), and Wed May 5 .. Sun May 9 (Thu, Fri).
  assertEquals(w.map((x) => [x.from, x.to, x.days, x.leave_days]), [
    ["2027-05-01", "2027-05-05", 5, 2],
    ["2027-05-05", "2027-05-09", 5, 2],
  ]);
});

Deno.test("long weekend: a gap of three working days is not bridged", () => {
  const w = computeWindows(input({
    travellers: [mum],
    // Mon bridges to the weekend before; Wed to Fri (three working days) join no weekend.
    publicHolidays: [{ date: "2027-05-04", name: "Dienstag" }],
    minDays: 4,
  }));
  assertEquals(w.map((x) => [x.from, x.to]), [["2027-05-01", "2027-05-04"]]);
});

Deno.test("long weekend: a bare weekend is a window when min_days is 2", () => {
  const w = computeWindows(input({
    travellers: [mum],
    from: "2027-05-10",
    to: "2027-05-23",
    minDays: 2,
  }));
  assertEquals(w.map((x) => [x.from, x.to, x.name]), [
    ["2027-05-15", "2027-05-16", undefined],
    ["2027-05-22", "2027-05-23", undefined],
  ]);
});

Deno.test("long weekend: children without a school do not make it a school window", () => {
  const w = computeWindows(input({
    travellers: [mum, tiny],
    holidays: [sportferien],
    publicHolidays: [{ date: "2027-05-06", name: "Auffahrt" }],
  }));
  assertEquals(w.map((x) => [x.kind, x.from]), [[
    "long_weekend",
    "2027-05-06",
  ]]);
});

Deno.test("at most MAX_WINDOWS windows, the earliest", () => {
  const w = computeWindows(input({
    travellers: [mum],
    from: "2027-01-01",
    to: "2028-12-31",
    minDays: 2,
  }));
  assertEquals(w.length, MAX_WINDOWS);
  assertEquals(w[0].from, "2027-01-02");
});

// ---------------------------------------------------------------- conflicts

const feb = (p: Partial<WindowInput>) =>
  computeWindows(
    input({ holidays: [sportferien], travellers: [mum, anna], ...p }),
  )[0];

Deno.test("conflicts: appointments of travellers and blocking presence, by day", () => {
  const w = feb({
    occurrences: [
      row({
        id: "dentist",
        title: "Zahnarzt",
        local_start_date: "2027-02-10",
        local_end_date: "2027-02-10",
        attendee_ids: ["anna", "dad"],
      }),
      row({
        id: "work",
        title: "Arbeit",
        kind: "presence",
        presence_state: "working",
        local_start_date: "2027-02-04",
        local_end_date: "2027-02-04",
        attendee_ids: ["mum"],
      }),
      row({
        id: "tent",
        title: "Fest",
        status: "tentative",
        local_start_date: "2027-02-02",
        local_end_date: "2027-02-02",
      }),
    ],
  });
  assertEquals(w.conflicts, [
    {
      date: "2027-02-02",
      title: "Fest",
      event_id: "tent",
      kind: "appointment",
      profile_ids: ["mum", "anna"],
    },
    {
      date: "2027-02-04",
      title: "Arbeit",
      event_id: "work",
      kind: "presence",
      presence_state: "working",
      profile_ids: ["mum"],
    },
    {
      date: "2027-02-10",
      title: "Zahnarzt",
      event_id: "dentist",
      kind: "appointment",
      profile_ids: ["anna"],
    },
  ]);
});

Deno.test("conflicts: not for non-travellers, easy presence, rows outside, or presence without anyone", () => {
  const w = feb({
    occurrences: [
      row({ id: "dad", attendee_ids: ["dad"] }),
      row({
        id: "ho",
        kind: "presence",
        presence_state: "home_office",
        attendee_ids: ["mum"],
      }),
      row({
        id: "off",
        kind: "presence",
        presence_state: "off",
        attendee_ids: ["mum"],
      }),
      row({
        id: "nobody",
        kind: "presence",
        presence_state: "working",
        attendee_ids: [],
      }),
      row({
        id: "before",
        local_start_date: "2027-01-20",
        local_end_date: "2027-01-20",
      }),
      row({
        id: "after",
        local_start_date: "2027-02-15",
        local_end_date: "2027-02-15",
      }),
    ],
  });
  assertEquals(w.conflicts, []);
});

Deno.test("conflicts: every blocking state counts", () => {
  const w = feb({
    occurrences: ["working", "travel", "away", "childcare"].map((state) =>
      row({
        id: state,
        kind: "presence",
        presence_state: state,
        attendee_ids: ["mum"],
      })
    ),
  });
  assertEquals(w.conflicts.map((c) => c.presence_state), [
    "working",
    "travel",
    "away",
    "childcare",
  ]);
});

Deno.test("conflicts: a multi-day row is listed once, on its first day inside the window", () => {
  const w = feb({
    occurrences: [
      row({
        id: "camp",
        title: "Lager",
        local_start_date: "2027-01-25",
        local_end_date: "2027-02-03",
        attendee_ids: ["anna"],
      }),
    ],
  });
  assertEquals(w.conflicts.map((c) => [c.title, c.date]), [
    ["Lager", "2027-01-30"],
  ]);
});

Deno.test("conflicts: the trip's own calendar entry is ignored when the request names the trip", () => {
  const occurrences = [
    row({ id: "own", title: "Reise", trip_id: "trip-1" }),
    row({ id: "other", title: "Andere Reise", trip_id: "trip-2" }),
  ];
  assertEquals(feb({ occurrences }).conflicts.map((c) => c.event_id), [
    "own",
    "other",
  ]);
  assertEquals(
    feb({ occurrences, ignoreTripId: "trip-1" }).conflicts.map((c) =>
      c.event_id
    ),
    ["other"],
  );
});

Deno.test("conflicts: at most MAX_CONFLICTS a window, earliest days first", () => {
  const occurrences = Array.from({ length: 30 }, (_, i) =>
    row({
      id: `e${String(i).padStart(2, "0")}`,
      local_start_date: `2027-02-${String(14 - (i % 10)).padStart(2, "0")}`,
      local_end_date: `2027-02-${String(14 - (i % 10)).padStart(2, "0")}`,
    }));
  const w = feb({ occurrences });
  assertEquals(w.conflicts.length, MAX_CONFLICTS);
  assertEquals(w.conflicts[0].date, "2027-02-05");
  assertEquals(
    w.conflicts.map((c) => c.date),
    [...w.conflicts.map((c) => c.date)].sort(),
  );
});
