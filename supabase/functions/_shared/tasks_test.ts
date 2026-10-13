import { assertEquals } from "jsr:@std/assert@1.0.13";
import {
  dueDates,
  HORIZON_DAYS,
  matchesRule,
  type TaskSchedule,
} from "./tasks.ts";

// 2026-10-13 is a Tuesday. The horizon is 2026-10-13 .. 2026-10-26 (14 days).
const TODAY = "2026-10-13";
const LAST = "2026-10-26";

function schedule(
  definitions: TaskSchedule["definitions"],
  today = TODAY,
): TaskSchedule {
  return {
    household_id: "h1",
    timezone: "Europe/Berlin",
    today,
    definitions,
  };
}

function dates(s: TaskSchedule, id = "d1"): string[] {
  return dueDates(s).filter((d) => d.definition_id === id).map((d) => d.due_on);
}

Deno.test("horizon is fourteen days, today and today + 13 inclusive", () => {
  assertEquals(HORIZON_DAYS, 13);
});

Deno.test("daily series from today fills the whole horizon", () => {
  const got = dates(schedule([
    { id: "d1", rrule: "FREQ=DAILY", starts_on: TODAY, window_days: 1 },
  ]));
  assertEquals(got.length, 14);
  assertEquals(got[0], TODAY);
  assertEquals(got[13], LAST);
});

Deno.test("nothing beyond today + 13", () => {
  const got = dates(schedule([
    { id: "d1", rrule: "FREQ=DAILY", starts_on: "2026-09-01", window_days: 1 },
  ]));
  assertEquals(got.at(-1), LAST);
  assertEquals(got.includes("2026-10-27"), false);
});

Deno.test("weekly BYDAY=SA gives the Saturdays in the horizon", () => {
  const got = dates(schedule([
    {
      id: "d1",
      rrule: "FREQ=WEEKLY;BYDAY=SA",
      starts_on: "2026-10-01",
      window_days: 1,
    },
  ]));
  assertEquals(got, ["2026-10-17", "2026-10-24"]);
});

Deno.test("every two weeks keeps the phase of starts_on", () => {
  const got = dates(schedule([
    {
      id: "d1",
      rrule: "FREQ=WEEKLY;INTERVAL=2",
      starts_on: "2026-10-06",
      window_days: 1,
    },
  ]));
  assertEquals(got, ["2026-10-20"]);
});

Deno.test("monthly BYMONTHDAY lands once in the horizon", () => {
  const got = dates(schedule([
    {
      id: "d1",
      rrule: "FREQ=MONTHLY;BYMONTHDAY=20",
      starts_on: "2026-09-01",
      window_days: 1,
    },
  ]));
  assertEquals(got, ["2026-10-20"]);
});

Deno.test("COUNT exhausted inside the horizon ends the series", () => {
  // Occurrences: 10-12 and 10-13. Only the second is due today or later.
  const got = dates(schedule([
    {
      id: "d1",
      rrule: "FREQ=DAILY;COUNT=2",
      starts_on: "2026-10-12",
      window_days: 1,
    },
  ]));
  assertEquals(got, [TODAY]);
});

Deno.test("COUNT exhausted before today yields nothing", () => {
  const got = dates(schedule([
    {
      id: "d1",
      rrule: "FREQ=DAILY;COUNT=3",
      starts_on: "2026-10-01",
      window_days: 1,
    },
  ]));
  assertEquals(got, []);
});

Deno.test("starts_on in the future: no date before it", () => {
  const got = dates(schedule([
    { id: "d1", rrule: "FREQ=DAILY", starts_on: "2026-10-20", window_days: 1 },
  ]));
  assertEquals(got, [
    "2026-10-20",
    "2026-10-21",
    "2026-10-22",
    "2026-10-23",
    "2026-10-24",
    "2026-10-25",
    "2026-10-26",
  ]);
});

Deno.test("UNTIL in the past yields nothing", () => {
  const got = dates(schedule([
    {
      id: "d1",
      rrule: "FREQ=DAILY;UNTIL=20260901T000000Z",
      starts_on: "2026-08-01",
      window_days: 1,
    },
  ]));
  assertEquals(got, []);
});

Deno.test("UNTIL in the horizon stops the series there", () => {
  const got = dates(schedule([
    {
      id: "d1",
      rrule: "FREQ=DAILY;UNTIL=20261015",
      starts_on: TODAY,
      window_days: 1,
    },
  ]));
  assertEquals(got, ["2026-10-13", "2026-10-14", "2026-10-15"]);
});

Deno.test("one-off definition (no rrule) is due on starts_on only", () => {
  const inside = dueDates(schedule([
    { id: "d1", rrule: null, starts_on: "2026-10-16", window_days: 1 },
  ]));
  assertEquals(inside, [{ definition_id: "d1", due_on: "2026-10-16" }]);

  const outside = dueDates(schedule([
    { id: "d1", rrule: null, starts_on: "2026-11-30", window_days: 1 },
  ]));
  assertEquals(outside, []);
});

Deno.test("malformed rrule yields nothing instead of throwing", () => {
  const got = dueDates(schedule([
    { id: "d1", rrule: "FREQ=HOURLY", starts_on: TODAY, window_days: 1 },
  ]));
  assertEquals(got, []);
});

Deno.test("output is sorted by due date, then definition id", () => {
  const got = dueDates(schedule([
    {
      id: "b",
      rrule: "FREQ=WEEKLY;BYDAY=SA",
      starts_on: "2026-10-10",
      window_days: 1,
    },
    {
      id: "a",
      rrule: "FREQ=WEEKLY;BYDAY=SA",
      starts_on: "2026-10-10",
      window_days: 1,
    },
    { id: "c", rrule: "FREQ=DAILY;COUNT=2", starts_on: TODAY, window_days: 1 },
  ]));
  assertEquals(got, [
    { definition_id: "c", due_on: "2026-10-13" },
    { definition_id: "c", due_on: "2026-10-14" },
    { definition_id: "a", due_on: "2026-10-17" },
    { definition_id: "b", due_on: "2026-10-17" },
    { definition_id: "a", due_on: "2026-10-24" },
    { definition_id: "b", due_on: "2026-10-24" },
  ]);
});

Deno.test("empty schedule yields nothing", () => {
  assertEquals(dueDates(schedule([])), []);
});

Deno.test("a chore's first day counts only when the rule matches it", () => {
  // 2026-10-13 is a Tuesday: a Saturday chore created then is first due on the 17th.
  const due = dueDates({
    household_id: "h",
    timezone: "Europe/Berlin",
    today: "2026-10-13",
    definitions: [{
      id: "sat",
      rrule: "FREQ=WEEKLY;BYDAY=SA",
      starts_on: "2026-10-13",
      window_days: 1,
    }],
  });
  assertEquals(due.map((d) => d.due_on), ["2026-10-17", "2026-10-24"]);
});

Deno.test("matchesRule handles weekdays, month days and ordinals", () => {
  assertEquals(matchesRule("2026-10-17", "FREQ=WEEKLY;BYDAY=SA"), true);
  assertEquals(matchesRule("2026-10-13", "FREQ=WEEKLY;BYDAY=SA,SU"), false);
  assertEquals(matchesRule("2026-10-31", "FREQ=MONTHLY;BYMONTHDAY=-1"), true);
  assertEquals(matchesRule("2026-10-30", "FREQ=MONTHLY;BYDAY=-1FR"), true);
  assertEquals(matchesRule("2026-10-23", "FREQ=MONTHLY;BYDAY=-1FR"), false);
  assertEquals(matchesRule("2026-10-14", "FREQ=MONTHLY;BYDAY=2WE"), true);
  assertEquals(matchesRule("2026-10-13", "FREQ=DAILY"), true);
});
