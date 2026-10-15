import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1.0.13";
import {
  expandIcs,
  type ExternalRow,
  IcsError,
  importWindow,
  MAX_IMPORT_ROWS,
  parseContentLine,
  parseDuration,
  parseVEvents,
  unescapeText,
  unfoldLines,
} from "./ical_parse.ts";

const TZ = "Europe/Berlin";
// A window that covers the fixtures of October and November 2026.
const WIDE = { householdTz: TZ, from: "2026-09-15", to: "2026-11-30" };

/** Joins lines with CRLF, the form most calendar servers send. */
const crlf = (lines: string[]) => lines.join("\r\n") + "\r\n";
const lf = (lines: string[]) => lines.join("\n") + "\n";

const CLUB = [
  "BEGIN:VCALENDAR",
  "VERSION:2.0",
  "PRODID:-//Fussballverband//Spielplan//DE",
  "X-WR-CALNAME:Spielplan U12",
  "BEGIN:VEVENT",
  "UID:match-1@club.example.org",
  "DTSTAMP:20261001T100000Z",
  "DTSTART;TZID=Europe/Berlin:20261017T150000",
  "DTEND;TZID=Europe/Berlin:20261017T165000",
  "SUMMARY:FC Stern U12 - FC Mond U12",
  "LOCATION:Sportplatz Mühle\\, Hauptfeld",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "UID:match-2@club.example.org",
  "DTSTART;TZID=America/New_York:20261024T100000",
  "DTEND;TZID=America/New_York:20261024T113000",
  "SUMMARY:Auswärts\\; Turnier",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "UID:match-3@club.example.org",
  "DTSTART;TZID=Mars/Olympus_Mons:20261031T100000",
  "DURATION:PT1H30M",
  "SUMMARY:Unbekannte Zeitzone",
  "END:VEVENT",
  "END:VCALENDAR",
];

const BINS = [
  "BEGIN:VCALENDAR",
  "VERSION:2.0",
  "BEGIN:VEVENT",
  "UID:papier-20261015@bins.example.ch",
  "DTSTART;VALUE=DATE:20261015",
  "DTEND;VALUE=DATE:20261016",
  "SUMMARY:Papier",
  "BEGIN:VALARM",
  "ACTION:DISPLAY",
  "DESCRIPTION:Erinnerung",
  "SUMMARY:Erinnerung an die Papierabfuhr",
  "TRIGGER:-PT12H",
  "END:VALARM",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "UID:restmuell-20261022@bins.example.ch",
  "DTSTART;VALUE=DATE:20261022",
  "DTEND;VALUE=DATE:20261023",
  "SUMMARY:Restmüll",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "UID:baustelle@bins.example.ch",
  "DTSTART;VALUE=DATE:20261020",
  "DTEND;VALUE=DATE:20261023",
  "SUMMARY:Sperrung Sammelstelle",
  "END:VEVENT",
  "END:VCALENDAR",
];

const TRAINING = [
  "BEGIN:VCALENDAR",
  "BEGIN:VEVENT",
  "UID:training@club.example.org",
  "DTSTART;TZID=Europe/Berlin:20261005T170000",
  "DTEND;TZID=Europe/Berlin:20261005T180000",
  "RRULE:FREQ=WEEKLY;BYDAY=MO",
  "EXDATE;TZID=Europe/Berlin:20261019T170000",
  "SUMMARY:Training",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "UID:training@club.example.org",
  "RECURRENCE-ID;TZID=Europe/Berlin:20261012T170000",
  "DTSTART;TZID=Europe/Berlin:20261012T180000",
  "DTEND;TZID=Europe/Berlin:20261012T190000",
  "SUMMARY:Training (verschoben)",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "UID:training@club.example.org",
  "RECURRENCE-ID;TZID=Europe/Berlin:20261026T170000",
  "DTSTART;TZID=Europe/Berlin:20261026T170000",
  "STATUS:CANCELLED",
  "SUMMARY:Training",
  "END:VEVENT",
  "END:VCALENDAR",
];

const byTitle = (rows: ExternalRow[], title: string) => rows.filter((r) => r.title === title);
const startsOf = (rows: ExternalRow[]) => rows.map((r) => r.starts_at);

// ---------------------------------------------------------------- content lines

Deno.test("unfold: CRLF and LF are both line ends, and folded lines join", () => {
  assertEquals(unfoldLines("A:1\r\nB:2\r\n"), ["A:1", "B:2"]);
  assertEquals(unfoldLines("A:1\nB:2\n"), ["A:1", "B:2"]);
  // Exactly one leading space or tab is the fold; anything after it is content.
  assertEquals(unfoldLines("SUMMARY:Sehr langer Titel für\r\n  den Kalender\r\n\tmit Umbruch\r\n"), [
    "SUMMARY:Sehr langer Titel für den Kalender" + "mit Umbruch",
  ]);
});

Deno.test("unfold: a leading byte order mark is dropped", () => {
  assertEquals(unfoldLines("﻿BEGIN:VCALENDAR\r\n"), ["BEGIN:VCALENDAR"]);
});

Deno.test("content line: quoted parameters may hold colons and semicolons", () => {
  const line = parseContentLine('DTSTART;TZID="Europe/Berlin";X-FOO="a:b;c":20261017T150000');
  assertEquals(line?.name, "DTSTART");
  assertEquals(line?.params, { TZID: "Europe/Berlin", "X-FOO": "a:b;c" });
  assertEquals(line?.value, "20261017T150000");
});

Deno.test("content line: a line without a name or colon is not a property", () => {
  assertEquals(parseContentLine("no colon here"), null);
  assertEquals(parseContentLine(":value"), null);
});

Deno.test("text: escaped commas, semicolons, backslashes and newlines are unescaped", () => {
  assertEquals(unescapeText("Raum 1\\, 2. OG\\; Eingang\\nHinten"), "Raum 1, 2. OG; Eingang\nHinten");
  assertEquals(unescapeText("A\\\\B\\NC"), "A\\B\nC");
  assertEquals(unescapeText("kein Escape"), "kein Escape");
});

Deno.test("duration: weeks, days, hours, minutes and seconds; sign; malformed text", () => {
  assertEquals(parseDuration("PT1H30M"), 90 * 60_000);
  assertEquals(parseDuration("P1D"), 86_400_000);
  assertEquals(parseDuration("P2W"), 14 * 86_400_000);
  assertEquals(parseDuration("-PT15M"), -15 * 60_000);
  assertEquals(parseDuration("PT45S"), 45_000);
  assertEquals(parseDuration("PT"), null);
  assertEquals(parseDuration("P1DT"), null);
  assertEquals(parseDuration("1H"), null);
  assertEquals(parseDuration(undefined), null);
});

// ---------------------------------------------------------------- parsing

Deno.test("parse: a feed without BEGIN:VCALENDAR is not an ICS document", () => {
  assertThrows(() => parseVEvents("<html>404</html>"), IcsError);
  try {
    parseVEvents("Hello");
  } catch (err) {
    assertEquals((err as IcsError).code, "not_ics");
  }
});

Deno.test("parse: a VEVENT without UID or DTSTART is counted as skipped", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "DTSTART:20261017T150000Z",
    "SUMMARY:ohne UID",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:kaputt@x",
    "DTSTART:2026-10-17",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:ok@x",
    "DTSTART:20261017T150000Z",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  const { events, skipped } = parseVEvents(feed);
  assertEquals(events.map((e) => e.uid), ["ok@x"]);
  assertEquals(skipped, 2);
});

Deno.test("parse: VALARM properties do not leak into the event", () => {
  const { events } = parseVEvents(crlf(BINS));
  assertEquals(events[0].summary, "Papier");
});

// ---------------------------------------------------------------- the club fixture (TZID, escapes)

Deno.test("club: TZID times are converted in their zone and escapes are read", () => {
  const { rows, skipped, unsupported, truncated } = expandIcs(crlf(CLUB), WIDE);
  assertEquals(skipped, 0);
  assertEquals(unsupported, 0);
  assertEquals(truncated, false);
  assertEquals(rows.length, 3);

  const [m1] = byTitle(rows, "FC Stern U12 - FC Mond U12");
  assertEquals(m1.starts_at, "2026-10-17T13:00:00Z", "Berlin 15:00 in summer time");
  assertEquals(m1.ends_at, "2026-10-17T14:50:00Z");
  assertEquals(m1.location, "Sportplatz Mühle, Hauptfeld");
  assertEquals(m1.all_day, false);
  assertEquals(m1.uid, "match-1@club.example.org");

  const [m2] = byTitle(rows, "Auswärts; Turnier");
  assertEquals(m2.starts_at, "2026-10-24T14:00:00Z", "New York 10:00 in daylight time");
  assertEquals(m2.ends_at, "2026-10-24T15:30:00Z");
});

Deno.test("club: an unknown TZID falls back to the household's timezone, DURATION is used", () => {
  const { rows } = expandIcs(crlf(CLUB), WIDE);
  const [m3] = byTitle(rows, "Unbekannte Zeitzone");
  assertEquals(m3.starts_at, "2026-10-31T09:00:00Z", "Berlin, winter time from 25 October");
  assertEquals(m3.ends_at, "2026-10-31T10:30:00Z");
});

// ---------------------------------------------------------------- all-day events (bins)

Deno.test("bins: all-day events keep their dates; DTEND (exclusive) becomes an inclusive end date", () => {
  const { rows } = expandIcs(crlf(BINS), WIDE);
  const [papier] = byTitle(rows, "Papier");
  assertEquals(papier.all_day, true);
  assertEquals(papier.start_date, "2026-10-15");
  assertEquals(papier.end_date, "2026-10-15", "one day: the exclusive end is the next day");
  assertEquals(papier.starts_at, null);
  assertEquals(papier.ends_at, null);

  const [baustelle] = byTitle(rows, "Sperrung Sammelstelle");
  assertEquals(baustelle.start_date, "2026-10-20");
  assertEquals(baustelle.end_date, "2026-10-22", "three days, the last one inclusive");
});

Deno.test("bins: the VALARM's SUMMARY is not the event's title", () => {
  const { rows } = expandIcs(crlf(BINS), WIDE);
  assertEquals(rows.some((r) => r.title.startsWith("Erinnerung")), false);
  assertEquals(rows.length, 3);
});

// ---------------------------------------------------------------- series, EXDATE and overrides

Deno.test("series: a weekly rule with EXDATE and RECURRENCE-ID overrides, across the DST change", () => {
  const { rows } = expandIcs(crlf(TRAINING), { householdTz: TZ, from: "2026-10-01", to: "2026-10-31" });
  // Monday 5 October at 17:00 (summer time); 12 October moved to 18:00; 19 October is an EXDATE
  // and 26 October is cancelled by its override, so neither has a row.
  assertEquals(startsOf(rows), ["2026-10-05T15:00:00Z", "2026-10-12T16:00:00Z"]);
  assertEquals(rows[1].title, "Training (verschoben)");
});

Deno.test("series: after the clocks go back, a 17:00 series is at 16:00 UTC", () => {
  const { rows } = expandIcs(crlf(TRAINING), { householdTz: TZ, from: "2026-11-01", to: "2026-11-30" });
  assertEquals(startsOf(rows), ["2026-11-02T16:00:00Z", "2026-11-09T16:00:00Z", "2026-11-16T16:00:00Z", "2026-11-23T16:00:00Z", "2026-11-30T16:00:00Z"]);
});

Deno.test("series: EXDATE and the cancelled override each remove exactly their occurrence", () => {
  // The window holds only the excluded Monday (19) and the cancelled one (26).
  const { rows } = expandIcs(crlf(TRAINING), { householdTz: TZ, from: "2026-10-18", to: "2026-10-27" });
  assertEquals(rows, []);
  // The same series a week earlier still has its 19th-free neighbours (the 12th is moved).
  const earlier = expandIcs(crlf(TRAINING), { householdTz: TZ, from: "2026-10-10", to: "2026-10-18" });
  assertEquals(startsOf(earlier.rows), ["2026-10-12T16:00:00Z"]);
});

// ---------------------------------------------------------------- RDATE, cancelled, unsupported rules

Deno.test("rdate: additional dates are single occurrences of the series' length", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:sonder@x",
    "DTSTART;TZID=Europe/Berlin:20261003T090000",
    "DTEND;TZID=Europe/Berlin:20261003T100000",
    "RDATE;TZID=Europe/Berlin:20261010T090000,20261017T090000",
    "SUMMARY:Sondertermin",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  const { rows } = expandIcs(feed, WIDE);
  assertEquals(startsOf(rows), ["2026-10-03T07:00:00Z", "2026-10-10T07:00:00Z", "2026-10-17T07:00:00Z"]);
  assertEquals(rows.every((r) => r.ends_at !== null), true);
});

Deno.test("cancelled: a cancelled event is not stored", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:cancelled@x",
    "DTSTART:20261020T100000Z",
    "DTEND:20261020T110000Z",
    "STATUS:CANCELLED",
    "SUMMARY:Abgesagt",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  assertEquals(expandIcs(feed, WIDE).rows, []);
});

Deno.test("cancelled: a cancelled series hides its overrides as well", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:gone@x",
    "DTSTART;TZID=Europe/Berlin:20261005T170000",
    "RRULE:FREQ=WEEKLY",
    "STATUS:CANCELLED",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:gone@x",
    "RECURRENCE-ID;TZID=Europe/Berlin:20261012T170000",
    "DTSTART;TZID=Europe/Berlin:20261012T180000",
    "SUMMARY:Verschoben",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  assertEquals(expandIcs(feed, WIDE).rows, []);
});

Deno.test("moved single event: a RECURRENCE-ID child replaces the original, which is not stored", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:arzt@x",
    "DTSTART;TZID=Europe/Berlin:20261020T100000",
    "DTEND;TZID=Europe/Berlin:20261020T110000",
    "SUMMARY:Arzt",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:arzt@x",
    "RECURRENCE-ID;TZID=Europe/Berlin:20261020T100000",
    "DTSTART;TZID=Europe/Berlin:20261021T140000",
    "DTEND;TZID=Europe/Berlin:20261021T150000",
    "SUMMARY:Arzt (verschoben)",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  const { rows } = expandIcs(feed, WIDE);
  assertEquals(rows.map((r) => [r.title, r.starts_at]), [["Arzt (verschoben)", "2026-10-21T12:00:00Z"]]);
});

Deno.test("moved single event: a cancelled RECURRENCE-ID child removes it", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:abgesagt@x",
    "DTSTART;TZID=Europe/Berlin:20261020T100000",
    "DTEND;TZID=Europe/Berlin:20261020T110000",
    "SUMMARY:Termin",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:abgesagt@x",
    "RECURRENCE-ID;TZID=Europe/Berlin:20261020T100000",
    "STATUS:CANCELLED",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  assertEquals(expandIcs(feed, WIDE).rows, []);
});

Deno.test("rules: a rule outside the supported subset keeps only the first occurrence", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:seltsam@x",
    "DTSTART;TZID=Europe/Berlin:20261005T170000",
    "DTEND;TZID=Europe/Berlin:20261005T180000",
    "RRULE:FREQ=HOURLY;INTERVAL=2",
    "SUMMARY:Stündlich",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  const result = expandIcs(feed, WIDE);
  assertEquals(result.unsupported, 1);
  assertEquals(startsOf(result.rows), ["2026-10-05T15:00:00Z"]);
});

Deno.test("timed event without DTEND or DURATION lasts one hour", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:ohne-ende@x",
    "DTSTART:20261020T100000Z",
    "SUMMARY:Ohne Ende",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  const [row] = expandIcs(feed, WIDE).rows;
  assertEquals(row.starts_at, "2026-10-20T10:00:00Z");
  assertEquals(row.ends_at, "2026-10-20T11:00:00Z");
});

// ---------------------------------------------------------------- times, folding, line ends

Deno.test("times: UTC is exact; floating times are read in the household's timezone", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:utc@x",
    "DTSTART:20261102T120000Z",
    "DTEND:20261102T130000Z",
    "SUMMARY:UTC",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:floating@x",
    "DTSTART:20261102T120000",
    "DTEND:20261102T130000",
    "SUMMARY:Floating",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  const { rows } = expandIcs(feed, { householdTz: TZ, from: "2026-11-01", to: "2026-11-03" });
  assertEquals(byTitle(rows, "UTC")[0].starts_at, "2026-11-02T12:00:00Z");
  assertEquals(byTitle(rows, "Floating")[0].starts_at, "2026-11-02T11:00:00Z", "Berlin, winter time");
});

Deno.test("folded lines and escapes survive the whole pipeline", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:falt@x",
    "DTSTART:20261021T080000Z",
    "DTEND:20261021T090000Z",
    "SUMMARY:Sehr langer Titel für",
    "  den Kalender mit Umbruch",
    "LOCATION:Raum 1\\, 2. OG\\; Eingang\\nHinten",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  const [row] = expandIcs(feed, WIDE).rows;
  assertEquals(row.title, "Sehr langer Titel für den Kalender mit Umbruch");
  assertEquals(row.location, "Raum 1, 2. OG; Eingang\nHinten");
});

Deno.test("line ends: CRLF and LF give the same rows", () => {
  const a = expandIcs(crlf(CLUB), WIDE).rows;
  const b = expandIcs(lf(CLUB), WIDE).rows;
  assertEquals(a, b);
  assertEquals(a.length, 3);
});

// ---------------------------------------------------------------- window, de-duplication, cap

Deno.test("window: occurrences outside the window are not stored", () => {
  const { rows } = expandIcs(crlf(BINS), { householdTz: TZ, from: "2026-10-16", to: "2026-10-21" });
  assertEquals(rows.map((r) => r.title).sort(), ["Sperrung Sammelstelle"]);
});

Deno.test("window: the import window is 30 days back and 400 days ahead in the household's zone", () => {
  // 00:30 on 15 October in Berlin is still 14 October in UTC.
  assertEquals(importWindow(new Date("2026-10-14T22:30:00Z"), TZ), { from: "2026-09-15", to: "2027-11-19" });
  assertEquals(importWindow(new Date("2026-10-14T12:00:00Z"), TZ), { from: "2026-09-14", to: "2027-11-18" });
});

Deno.test("cap: at most 5000 rows, the earliest kept, and truncated is reported", () => {
  const lines = ["BEGIN:VCALENDAR"];
  for (let i = 0; i < 6; i++) {
    lines.push(
      "BEGIN:VEVENT",
      `UID:serie-${i}@x`,
      `DTSTART;TZID=Europe/Berlin:2025010${i + 1}T100000`,
      "DTEND;TZID=Europe/Berlin:20250101T110000",
      "RRULE:FREQ=DAILY;COUNT=1000",
      "SUMMARY:Serie",
      "END:VEVENT",
    );
  }
  lines.push("END:VCALENDAR");
  const result = expandIcs(crlf(lines), { householdTz: TZ, from: "2024-01-01", to: "2027-12-31" });
  assertEquals(MAX_IMPORT_ROWS, 5000);
  assertEquals(result.rows.length, 5000);
  assertEquals(result.truncated, true);
  // Sorted: the first rows are the earliest starts.
  assert(result.rows[0].starts_at! <= result.rows[4999].starts_at!);
});

Deno.test("de-duplication: an RDATE that repeats a series date is stored once", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:dup@x",
    "DTSTART;TZID=Europe/Berlin:20261005T170000",
    "DTEND;TZID=Europe/Berlin:20261005T180000",
    "RRULE:FREQ=WEEKLY;COUNT=2",
    "RDATE;TZID=Europe/Berlin:20261005T170000",
    "SUMMARY:Doppelt",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  assertEquals(startsOf(expandIcs(feed, WIDE).rows), ["2026-10-05T15:00:00Z", "2026-10-12T15:00:00Z"]);
});

Deno.test("all-day series: a weekly all-day rule keeps its dates", () => {
  const feed = crlf([
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:muell@x",
    "DTSTART;VALUE=DATE:20261005",
    "DTEND;VALUE=DATE:20261006",
    "RRULE:FREQ=WEEKLY;BYDAY=MO",
    "EXDATE;VALUE=DATE:20261012",
    "SUMMARY:Gelber Sack",
    "END:VEVENT",
    "END:VCALENDAR",
  ]);
  const { rows } = expandIcs(feed, { householdTz: TZ, from: "2026-10-01", to: "2026-10-31" });
  assertEquals(rows.map((r) => r.start_date), ["2026-10-05", "2026-10-19", "2026-10-26"]);
  assertEquals(rows.every((r) => r.all_day && r.end_date === r.start_date), true);
});
