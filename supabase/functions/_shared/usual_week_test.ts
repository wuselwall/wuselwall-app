import { assertEquals } from "jsr:@std/assert@1.0.13";
import { abWeekOf, isoWeekday, usualDay, usualOn, type UsualSlotRow, type UsualWeekRow } from "./usual_week.ts";

const slot = (p: Partial<UsualSlotRow> & { weekday: number; state: string }): UsualSlotRow => ({
  week: 0,
  position: 1,
  label: null,
  starts: null,
  ends: null,
  ...p,
});

Deno.test("ISO weekdays run from Monday 1 to Sunday 7", () => {
  assertEquals(isoWeekday("2026-10-19"), 1);
  assertEquals(isoWeekday("2026-10-24"), 6);
  assertEquals(isoWeekday("2026-10-25"), 7);
});

Deno.test("without an anchor every week is week A", () => {
  assertEquals(abWeekOf(null, "2026-10-19"), 0);
  assertEquals(abWeekOf(null, "2026-10-26"), 0);
});

Deno.test("weeks alternate from the anchor, before it too", () => {
  const anchor = "2026-10-19";
  assertEquals(abWeekOf(anchor, "2026-10-19"), 0);
  assertEquals(abWeekOf(anchor, "2026-10-25"), 0, "the anchor's Sunday is still week A");
  assertEquals(abWeekOf(anchor, "2026-10-26"), 1);
  assertEquals(abWeekOf(anchor, "2026-11-02"), 0);
  assertEquals(abWeekOf(anchor, "2026-10-12"), 1, "the week before the anchor is B");
  assertEquals(abWeekOf(anchor, "2026-10-05"), 0);
});

Deno.test("alternating weeks do not slip across a week 53", () => {
  // 2026 has an ISO week 53 (28 Dec); calendar-week parity would make KW 53 and KW 1 both odd.
  const anchor = "2026-12-21"; // KW 52, week A
  assertEquals(abWeekOf(anchor, "2026-12-28"), 1); // KW 53
  assertEquals(abWeekOf(anchor, "2027-01-04"), 0); // KW 1
  assertEquals(abWeekOf(anchor, "2027-01-11"), 1); // KW 2
});

Deno.test("a day's places come from its weekday and week, in slot order", () => {
  const week: UsualWeekRow = {
    profile_id: "a",
    anchor: "2026-10-19",
    slots: [
      slot({ weekday: 1, state: "home_office", position: 2, starts: "13:00", ends: "17:00" }),
      slot({ weekday: 1, state: "working", position: 1, starts: "08:00", ends: "12:00", label: "Büro" }),
      slot({ weekday: 1, week: 1, state: "off" }),
      slot({ weekday: 2, state: "home_office" }),
    ],
  };
  assertEquals(usualOn(week, "2026-10-19").map((s) => s.state), ["working", "home_office"]);
  assertEquals(usualOn(week, "2026-10-26").map((s) => s.state), ["off"]);
  assertEquals(usualOn(week, "2026-10-20").map((s) => s.state), ["home_office"]);
  assertEquals(usualOn(week, "2026-10-27"), [], "week B has no Tuesday");
  assertEquals(usualOn(week, "2026-10-24"), [], "nothing on a free weekend");
  const unanchored = { ...week, anchor: null };
  assertEquals(
    usualOn(unanchored, "2026-10-26").map((s) => s.state),
    ["working", "home_office"],
    "without an anchor a kept week B is never used",
  );
});

Deno.test("a board day lists every member's places in member order, and none on a holiday", () => {
  const weeks: UsualWeekRow[] = [
    { profile_id: "b", anchor: null, slots: [slot({ weekday: 1, state: "working", label: "Dienst" })] },
    { profile_id: "a", anchor: null, slots: [slot({ weekday: 1, state: "home_office" })] },
    { profile_id: "gone", anchor: null, slots: [slot({ weekday: 1, state: "off" })] },
  ];
  assertEquals(usualDay(weeks, ["a", "b"], "2026-10-19", false), [
    { member_id: "a", state: "home_office", label: null, starts: null, ends: null },
    { member_id: "b", state: "working", label: "Dienst", starts: null, ends: null },
  ]);
  assertEquals(usualDay(weeks, ["a", "b"], "2026-10-19", true), []);
});
