import { assertEquals } from "jsr:@std/assert@1.0.13";
import type { Occurrence } from "../occurrences.ts";
import {
  chunksOf,
  mergeChunks,
  schoolOf,
  type TimetableSpan,
  todayIn,
} from "./data.ts";

Deno.test("todayIn: the date in the household's timezone, not UTC's", () => {
  const lateEvening = new Date("2026-11-14T23:30:00Z");
  assertEquals(todayIn("UTC", lateEvening), "2026-11-14");
  assertEquals(todayIn("Europe/Zurich", lateEvening), "2026-11-15");
  assertEquals(todayIn("America/New_York", lateEvening), "2026-11-14");
});

Deno.test("chunksOf: inclusive ranges of at most 62 days, covering the range exactly", () => {
  assertEquals(chunksOf("2027-01-01", "2027-01-10"), [
    { from: "2027-01-01", to: "2027-01-10" },
  ]);
  const chunks = chunksOf("2027-01-01", "2027-06-30");
  assertEquals(chunks[0], { from: "2027-01-01", to: "2027-03-03" });
  assertEquals(chunks[1].from, "2027-03-04");
  assertEquals(chunks[chunks.length - 1].to, "2027-06-30");
  let days = 0;
  for (const c of chunks) {
    const n = (Date.parse(c.to) - Date.parse(c.from)) / 86_400_000 + 1;
    days += n;
    assertEquals(n <= 62, true);
  }
  assertEquals(days, 181);
  assertEquals(chunksOf("2027-01-01", "2027-03-03").length, 1);
  assertEquals(chunksOf("2027-01-01", "2027-03-04").length, 2);
});

const span = (
  profile: string,
  school: string,
  from: string,
  to: string | null,
): TimetableSpan => ({
  profile_id: profile,
  school_id: school,
  valid_from: from,
  valid_to: to,
});

Deno.test("schoolOf: the timetable valid today, else the next, else the last, else none", () => {
  const t = [
    span("a", "old", "2025-08-01", "2026-07-15"),
    span("a", "now", "2026-08-10", null),
    span("a", "later", "2027-08-10", null),
    span("b", "ended", "2024-08-01", "2025-07-01"),
    span("b", "ended-more-recent", "2025-08-01", "2026-07-01"),
    span("c", "future", "2027-08-01", null),
    span("c", "future-too", "2028-08-01", null),
  ];
  assertEquals(schoolOf("a", t, "2026-11-15"), "now");
  assertEquals(schoolOf("b", t, "2026-11-15"), "ended-more-recent");
  assertEquals(schoolOf("c", t, "2026-11-15"), "future");
  assertEquals(schoolOf("d", t, "2026-11-15"), null);
});

function occ(id: string, start: string): Occurrence {
  return {
    id,
    event_id: id,
    recurrence_id: null,
    calendar_id: "c",
    title: id,
    location: null,
    description: null,
    kind: "appointment",
    presence_state: null,
    status: "confirmed",
    importance: "normal",
    all_day: false,
    start,
    end: start,
    local_start_date: start.slice(0, 10),
    local_end_date: start.slice(0, 10),
    local_starts: null,
    local_ends: null,
    attendee_ids: [],
    is_recurring: false,
    is_override: false,
    source: "event",
    colour_hex: null,
    trip_id: null,
  };
}

Deno.test("mergeChunks: a row seen in two chunks is kept once, all in calendar order", () => {
  const camp = occ("camp|single", "2027-03-02T08:00:00Z");
  const merged = mergeChunks([
    [occ("a|single", "2027-03-01T08:00:00Z"), camp],
    [camp, occ("b|single", "2027-03-05T08:00:00Z")],
  ]);
  assertEquals(merged.map((o) => o.id), [
    "a|single",
    "camp|single",
    "b|single",
  ]);
});
