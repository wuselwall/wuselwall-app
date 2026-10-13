import {
  assert,
  assertEquals,
  assertFalse,
  assertMatch,
} from "jsr:@std/assert@1.0.13";
import ICALPkg from "npm:ical.js@2.2.1";
import { Temporal } from "npm:temporal-polyfill@0.3.0";
import {
  type FeedEvent,
  type FeedOverride,
  foldLine,
  type IcsFeed,
  renderIcs,
} from "./ics.ts";
import type { SchoolData } from "./school.ts";

// deno-lint-ignore no-explicit-any
const ICAL = (ICALPkg as any).default ?? ICALPkg;

const NOW = new Date("2026-10-13T10:00:00Z");
const HOST = "wuselwall.app";

function event(over: Partial<FeedEvent>): FeedEvent {
  return {
    id: "e1",
    calendar_id: "c1",
    title: "Turnen",
    description: null,
    location: null,
    kind: "appointment",
    presence_state: null,
    status: "confirmed",
    importance: "normal",
    is_all_day: false,
    starts_at: "2026-10-13T05:00:00Z",
    ends_at: "2026-10-13T06:00:00Z",
    start_date: null,
    end_date: null,
    timezone: "Europe/Berlin",
    rrule: null,
    rdates: null,
    exdates: null,
    attendee_ids: [],
    uid: "e1-uid@wuselwall.app",
    sequence: 0,
    created_at: "2026-10-01T08:00:00Z",
    updated_at: "2026-10-12T09:30:00Z",
    deleted: false,
    ...over,
  };
}

function feed(over: Partial<IcsFeed>): IcsFeed {
  return {
    household: {
      name: "Familie Huser",
      timezone: "Europe/Berlin",
      locale: "de",
    },
    revision: 1,
    events: [],
    overrides: [],
    attendees: {},
    ...over,
  };
}

function render(f: IcsFeed): string {
  return renderIcs(f, { now: NOW, host: HOST });
}

/** The physical lines of the output, CRLF removed and folds joined back. */
function unfolded(text: string): string[] {
  return text.replace(/\r\n /g, "").split("\r\n").filter((l) => l !== "");
}

/** Each VEVENT as its list of unfolded property lines. */
function veventBlocks(text: string): string[][] {
  const blocks: string[][] = [];
  let current: string[] | null = null;
  for (const line of unfolded(text)) {
    if (line === "BEGIN:VEVENT") current = [];
    else if (line === "END:VEVENT") {
      blocks.push(current ?? []);
      current = null;
    } else if (current) current.push(line);
  }
  return blocks;
}

function lineStartingWith(lines: string[], prefix: string): string | undefined {
  return lines.find((l) => l.startsWith(prefix));
}

const weeklySeries = event({
  id: "w1",
  uid: "turnen@wuselwall.app",
  sequence: 3,
  rrule: "FREQ=WEEKLY;BYDAY=TU;UNTIL=20270701T000000Z",
  rdates: ["2026-11-03"],
  exdates: ["2026-10-20"],
  attendee_ids: ["lotta"],
  description: "Halle 2",
  location: "Sporthalle",
});

const weeklyOverrides: FeedOverride[] = [
  {
    event_id: "w1",
    recurrence_id: "2026-10-27T06:00:00Z", // 07:00 Berlin, after the DST change
    is_cancelled: true,
    title: null,
    starts_at: null,
    ends_at: null,
    start_date: null,
    end_date: null,
    location: null,
    status: null,
  },
  {
    event_id: "w1",
    recurrence_id: "2026-11-10T06:00:00Z",
    is_cancelled: false,
    title: "Turnen (später)",
    starts_at: "2026-11-10T07:00:00Z",
    ends_at: "2026-11-10T08:00:00Z",
    start_date: null,
    end_date: null,
    location: "Halle 1",
    status: null,
  },
];

const allDay = event({
  id: "a1",
  uid: "urlaub@wuselwall.app",
  title: "Urlaub",
  is_all_day: true,
  starts_at: null,
  ends_at: null,
  start_date: "2026-10-20",
  end_date: "2026-10-22",
});

Deno.test("every line ends with CRLF and none exceeds 75 octets", () => {
  const title =
    "Übungsstunde für die Größeren Kinder der Grundschule Lindenhof 🎉 Trikots nicht vergessen, bitte Äpfel";
  const out = render(feed({
    events: [
      event({
        title,
        description: "Zürich: Öffnungszeiten änderten sich 🎉🎉🎉 ".repeat(8),
      }),
    ],
  }));
  assert(out.endsWith("\r\n"));
  assertFalse(out.replace(/\r\n/g, "").includes("\n"));
  const enc = new TextEncoder();
  for (const line of out.split("\r\n")) {
    assert(enc.encode(line).length <= 75, `line too long: ${line}`);
  }
  // Folding loses nothing: the unfolded SUMMARY is the full title.
  assert(unfolded(out).includes(`SUMMARY:${title.replace(/,/g, "\\,")}`));
});

Deno.test("foldLine never splits a multi-byte character", () => {
  const folded = foldLine("ä".repeat(60));
  for (const part of folded.split("\r\n")) {
    assert(new TextEncoder().encode(part).length <= 75);
    assertFalse(part.includes("�"));
  }
  assertEquals(folded.replace(/\r\n /g, ""), "ä".repeat(60));
});

Deno.test("text escaping of comma, semicolon, backslash and newline", () => {
  const out = render(feed({
    events: [event({ title: "Essen, Trinken; Sport\\Halle\nZeile 2" })],
  }));
  assert(
    unfolded(out).includes(
      "SUMMARY:Essen\\, Trinken\\; Sport\\\\Halle\\nZeile 2",
    ),
  );
});

Deno.test("timed weekly series: TZID local times, RDATE, EXDATE from exdates and cancelled overrides, both VTIMEZONE components", () => {
  const out = render(
    feed({ events: [weeklySeries], overrides: weeklyOverrides }),
  );
  const lines = unfolded(out);

  assert(lines.includes("DTSTART;TZID=Europe/Berlin:20261013T070000"));
  assert(lines.includes("DTEND;TZID=Europe/Berlin:20261013T080000"));
  assert(lines.includes("RRULE:FREQ=WEEKLY;BYDAY=TU;UNTIL=20270701T000000Z"));
  assert(lines.includes("RDATE;TZID=Europe/Berlin:20261103T070000"));
  // The explicit exdate and the cancelled override, in local time.
  assert(
    lines.includes("EXDATE;TZID=Europe/Berlin:20261020T070000,20261027T070000"),
  );

  // VTIMEZONE with both components, transitions in local time before each change.
  const start = lines.indexOf("BEGIN:VTIMEZONE");
  const end = lines.indexOf("END:VTIMEZONE");
  assert(start >= 0 && end > start);
  const tz = lines.slice(start, end);
  assert(tz.includes("BEGIN:DAYLIGHT"));
  assert(tz.includes("BEGIN:STANDARD"));
  assert(tz.includes("DTSTART:20260329T020000"));
  assert(tz.includes("DTSTART:20261025T030000"));
  assert(tz.includes("TZOFFSETFROM:+0100"));
  assert(tz.includes("TZOFFSETTO:+0200"));
  assert(tz.includes("TZOFFSETFROM:+0200"));
  assert(tz.includes("TZOFFSETTO:+0100"));

  // Series plus one modified occurrence; the cancelled one has no VEVENT.
  const blocks = veventBlocks(out);
  assertEquals(blocks.length, 2);
  const modified = blocks[1];
  assertEquals(lineStartingWith(modified, "UID:"), "UID:turnen@wuselwall.app");
  assert(modified.includes("RECURRENCE-ID;TZID=Europe/Berlin:20261110T070000"));
  assert(modified.includes("DTSTART;TZID=Europe/Berlin:20261110T080000"));
  assert(modified.includes("SUMMARY:Turnen (später)"));
  assert(modified.includes("LOCATION:Halle 1"));
  assertFalse(modified.some((l) => l.startsWith("RRULE")));
});

Deno.test("all-day event: VALUE=DATE and DTEND the day after the last day", () => {
  const out = render(feed({ events: [allDay] }));
  const lines = unfolded(out);
  assert(lines.includes("DTSTART;VALUE=DATE:20261020"));
  assert(lines.includes("DTEND;VALUE=DATE:20261023"));
  assertFalse(lines.some((l) => l.startsWith("BEGIN:VTIMEZONE")));
});

Deno.test("a modified override is a second VEVENT with the same UID and RECURRENCE-ID", () => {
  const out = render(
    feed({ events: [weeklySeries], overrides: [weeklyOverrides[1]] }),
  );
  const blocks = veventBlocks(out);
  assertEquals(blocks.length, 2);
  assertEquals(
    lineStartingWith(blocks[0], "UID:"),
    lineStartingWith(blocks[1], "UID:"),
  );
  assert(lineStartingWith(blocks[1], "RECURRENCE-ID") !== undefined);
  assertEquals(lineStartingWith(blocks[0], "RECURRENCE-ID"), undefined);
});

Deno.test("tentative event has STATUS:TENTATIVE", () => {
  const out = render(feed({ events: [event({ status: "tentative" })] }));
  assert(unfolded(out).includes("STATUS:TENTATIVE"));
});

Deno.test("deleted event has STATUS:CANCELLED", () => {
  const out = render(feed({ events: [event({ deleted: true })] }));
  assert(unfolded(out).includes("STATUS:CANCELLED"));
});

Deno.test("presence: transparent, kind marker, name prefix, no attendee lines", () => {
  const out = render(feed({
    events: [event({
      id: "p1",
      kind: "presence",
      presence_state: "work",
      title: "Dienst",
      starts_at: "2026-10-13T06:00:00Z",
      ends_at: "2026-10-13T14:00:00Z",
      attendee_ids: ["sabine"],
      uid: "presence-1@wuselwall.app",
    })],
    attendees: { sabine: "Sabine" },
  }));
  const block = veventBlocks(out)[0];
  assert(block.includes("TRANSP:TRANSPARENT"));
  assert(block.includes("X-WUSELWALL-KIND:presence"));
  assert(block.includes("SUMMARY:Sabine: Dienst"));
  assertFalse(out.includes("ATTENDEE"));
});

Deno.test("DTSTAMP on every VEVENT; UID and SEQUENCE carried through", () => {
  const out = render(feed({
    events: [
      weeklySeries,
      allDay,
      event({ id: "x", uid: "x@wuselwall.app", sequence: 7 }),
    ],
    overrides: weeklyOverrides,
  }));
  const blocks = veventBlocks(out);
  assertEquals(blocks.length, 4);
  for (const block of blocks) {
    assertMatch(
      lineStartingWith(block, "DTSTAMP:") ?? "",
      /^DTSTAMP:\d{8}T\d{6}Z$/,
    );
  }
  assertEquals(
    lineStartingWith(blocks[0], "DTSTAMP:"),
    "DTSTAMP:20261013T100000Z",
  );
  assert(blocks[0].includes("SEQUENCE:3"));
  const x = blocks.find((b) => b.includes("UID:x@wuselwall.app"));
  assert(x?.includes("SEQUENCE:7"));
});

Deno.test("attendee names in DESCRIPTION, German and English, and no ATTENDEE lines", () => {
  const withNames = event({
    attendee_ids: ["lotta", "hanna"],
    description: "Bring Wasser",
  });
  const attendees = { lotta: "Lotta", hanna: "Hanna" };

  const de = render(feed({ events: [withNames], attendees }));
  assert(
    unfolded(de).includes("DESCRIPTION:Bring Wasser\\nMit: Lotta\\, Hanna"),
  );
  assertFalse(de.includes("ATTENDEE"));

  const en = render(feed({
    events: [withNames],
    attendees,
    household: { name: "Family", timezone: "Europe/Berlin", locale: "en-GB" },
  }));
  assert(
    unfolded(en).includes("DESCRIPTION:Bring Wasser\\nWith: Lotta\\, Hanna"),
  );
  assertFalse(en.includes("ATTENDEE"));
});

Deno.test("UTC zone has no transitions and gets one STANDARD component", () => {
  const out = render(feed({
    household: { name: "UTC", timezone: "UTC", locale: "en" },
    events: [
      event({
        timezone: "UTC",
        starts_at: "2026-10-13T07:00:00Z",
        ends_at: "2026-10-13T08:00:00Z",
      }),
    ],
  }));
  const lines = unfolded(out);
  const start = lines.indexOf("BEGIN:VTIMEZONE");
  const end = lines.indexOf("END:VTIMEZONE");
  const tz = lines.slice(start, end);
  assertEquals(tz.filter((l) => l === "BEGIN:STANDARD").length, 1);
  assertFalse(tz.includes("BEGIN:DAYLIGHT"));
  assert(lines.includes("DTSTART;TZID=UTC:20261013T070000"));
});

Deno.test("reference parser (ical.js) reads the expected events and times", () => {
  const out = render(feed({
    events: [weeklySeries, allDay],
    overrides: weeklyOverrides,
  }));
  const root = new ICAL.Component(ICAL.parse(out));
  assertEquals(root.name, "vcalendar");
  const vevents = root.getAllSubcomponents("vevent");
  // The series, its modified occurrence, and the all-day event.
  assertEquals(vevents.length, 3);

  const series = vevents.find((
    v: { getFirstPropertyValue(n: string): unknown },
  ) =>
    v.getFirstPropertyValue("uid") === "turnen@wuselwall.app" &&
    v.getFirstPropertyValue("recurrence-id") === null
  );
  const seriesStart = series.getFirstPropertyValue("dtstart");
  assertEquals(seriesStart.hour, 7);
  assertEquals(seriesStart.minute, 0);
  assertEquals(seriesStart.isDate, false);

  const holiday = vevents.find((
    v: { getFirstPropertyValue(n: string): unknown },
  ) => v.getFirstPropertyValue("uid") === "urlaub@wuselwall.app");
  const holidayStart = holiday.getFirstPropertyValue("dtstart");
  const holidayEnd = holiday.getFirstPropertyValue("dtend");
  assertEquals(holidayStart.isDate, true);
  assertEquals(holidayStart.toString(), "2026-10-20");
  assertEquals(holidayEnd.toString(), "2026-10-23");
});

// ── school days ──────────────────────────────────────────────────────────────────

const LOTTA = "11111111-1111-4111-8111-111111111111";

/** One child's grid, Tuesdays only (weekday 2): two lessons, in a term that covers the window. */
function schoolData(over: Partial<SchoolData> = {}): SchoolData {
  return {
    schools: [{
      id: "s1",
      name: "Grundschule am Park",
      state_code: "DE-BE",
      timezone: "Europe/Berlin",
      created_at: "2026-09-01T00:00:00Z",
    }],
    periods: [
      {
        id: "p1",
        school_id: "s1",
        index: 1,
        label: null,
        starts_at: "08:00:00",
        ends_at: "08:45:00",
        kind: "lesson",
      },
      {
        id: "p2",
        school_id: "s1",
        index: 2,
        label: null,
        starts_at: "08:50:00",
        ends_at: "09:35:00",
        kind: "lesson",
      },
    ],
    terms: [{
      id: "t1",
      school_id: "s1",
      name: "Herbst",
      starts_on: "2026-01-01",
      ends_on: "2027-12-31",
      ab_anchor_week: null,
      is_current: true,
    }],
    subjects: [
      {
        id: "sj1",
        name: "Mathematik",
        short_name: "Ma",
        tint: "blue",
        icon_key: null,
        equipment_note: null,
        notable_default: false,
      },
      {
        id: "sj2",
        name: "Deutsch",
        short_name: "D",
        tint: "rose",
        icon_key: null,
        equipment_note: null,
        notable_default: false,
      },
    ],
    timetables: [{
      id: "tt1",
      profile_id: LOTTA,
      school_id: "s1",
      term_id: "t1",
      class_label: "2b",
      week_cycle: "weekly",
      valid_from: "2026-01-01",
      valid_to: null,
      source: "manual",
      source_ref: null,
      updated_at: "2026-10-12T09:30:00Z",
    }],
    lessons: [
      {
        id: "l1",
        timetable_id: "tt1",
        weekday: 2,
        period_index: 1,
        starts_at: null,
        ends_at: null,
        subject_id: "sj1",
        kind: "lesson",
        title: null,
        teacher: "Frau Berg",
        room: "R1",
        week_parity: "all",
        is_notable: false,
        note: null,
      },
      {
        id: "l2",
        timetable_id: "tt1",
        weekday: 2,
        period_index: 2,
        starts_at: null,
        ends_at: null,
        subject_id: "sj2",
        kind: "lesson",
        title: null,
        teacher: null,
        room: "R2",
        week_parity: "all",
        is_notable: false,
        note: "Lesebuch mitbringen",
      },
    ],
    exceptions: [],
    holidays: [],
    ...over,
  };
}

function schoolFeed(
  mode: "day" | "lessons" | null,
  school: SchoolData | undefined = schoolData(),
  over: Partial<IcsFeed> = {},
): IcsFeed {
  return feed({
    filter: {
      profile_ids: [],
      calendar_ids: [],
      kinds: ["appointment"],
      school: mode ?? "off",
    },
    school,
    members: { [LOTTA]: "Lotta" },
    ...over,
  });
}

/** The school VEVENTs (the ones marked X-WUSELWALL-KIND:school), as property lines. */
function schoolBlocks(text: string): string[][] {
  return veventBlocks(text).filter((b) =>
    b.includes("X-WUSELWALL-KIND:school")
  );
}

/** Tuesdays in the projection window around NOW (Berlin date 2026-10-13): 30 days back, 120 ahead. */
function tuesdaysInWindow(): number {
  const today = Temporal.PlainDate.from("2026-10-13");
  let count = 0;
  for (
    let d = today.subtract({ days: 30 });
    Temporal.PlainDate.compare(d, today.add({ days: 120 })) <= 0;
    d = d.add({ days: 1 })
  ) {
    if (d.dayOfWeek === 2) count++;
  }
  return count;
}

Deno.test("day mode: one VEVENT per child per school day, lessons in the description", () => {
  const out = render(schoolFeed("day"));
  const blocks = schoolBlocks(out);
  assertEquals(blocks.length, tuesdaysInWindow());

  const day = blocks.find((b) =>
    b.includes(`UID:schoolday-${LOTTA}-20261013@wuselwall.app`)
  );
  assert(day, "the Tuesday of NOW has a school day");
  assertEquals(
    lineStartingWith(day, "DTSTART;TZID=Europe/Berlin:"),
    "DTSTART;TZID=Europe/Berlin:20261013T080000",
  );
  assertEquals(
    lineStartingWith(day, "DTEND;TZID=Europe/Berlin:"),
    "DTEND;TZID=Europe/Berlin:20261013T093500",
  );
  assertEquals(lineStartingWith(day, "SUMMARY:"), "SUMMARY:Lotta: Schule");
  assertEquals(
    lineStartingWith(day, "DESCRIPTION:"),
    "DESCRIPTION:1. Ma · 2. D",
  );
  assertEquals(lineStartingWith(day, "TRANSP:"), "TRANSP:TRANSPARENT");
  assert(
    out.includes("BEGIN:VTIMEZONE\r\nTZID:Europe/Berlin"),
    "the school zone has a VTIMEZONE",
  );
});

Deno.test("day mode: Entfall and Vertretung are noted in the description", () => {
  const data = schoolData({
    exceptions: [
      {
        id: "x1",
        timetable_id: "tt1",
        on_date: "2026-10-13",
        period_index: 2,
        kind: "cancelled",
        subject_id: null,
        teacher: null,
        room: null,
        starts_at: null,
        ends_at: null,
        note: null,
        created_by_profile_id: LOTTA,
      },
      {
        id: "x2",
        timetable_id: "tt1",
        on_date: "2026-10-13",
        period_index: 1,
        kind: "substituted",
        subject_id: null,
        teacher: "Herr Kuhn",
        room: null,
        starts_at: null,
        ends_at: null,
        note: null,
        created_by_profile_id: LOTTA,
      },
    ],
  });
  const out = render(schoolFeed("day", data));
  const day = schoolBlocks(out).find((b) =>
    b.includes(`UID:schoolday-${LOTTA}-20261013@wuselwall.app`)
  );
  assertEquals(
    lineStartingWith(day ?? [], "DESCRIPTION:"),
    "DESCRIPTION:1. Ma (Vertretung) · 2. D (Entfall)",
  );
  assertEquals(
    lineStartingWith(day ?? [], "DTEND;TZID=Europe/Berlin:"),
    "DTEND;TZID=Europe/Berlin:20261013T084500",
  );
});

Deno.test("holidays and weekends emit nothing", () => {
  const data = schoolData({
    holidays: [{
      id: "h1",
      school_id: "s1",
      name: "Herbstferien",
      starts_on: "2026-10-12",
      ends_on: "2026-10-16",
      kind: "holiday",
      source: "manual",
      source_url: null,
    }],
  });
  const out = render(schoolFeed("day", data));
  assert(
    !out.includes(`schoolday-${LOTTA}-20261013`),
    "no school day in the holiday",
  );
  assert(
    !out.includes(`schoolday-${LOTTA}-20261014`),
    "no school day in the holiday",
  );
  assertEquals(
    schoolBlocks(out).length,
    tuesdaysInWindow() - 1,
    "one Tuesday less than the window holds",
  );
});

Deno.test("UIDs are the same across renders; SEQUENCE follows the timetable's updated_at", () => {
  const uids = (text: string) =>
    schoolBlocks(text).map((b) => lineStartingWith(b, "UID:") ?? "").sort();
  const first = uids(render(schoolFeed("day")));
  const later = uids(renderIcs(schoolFeed("day"), {
    now: new Date(NOW.getTime() + 86_400_000),
    host: HOST,
  }));
  assertEquals(first, later);

  const seqOf = (text: string) => {
    const block = schoolBlocks(text).find((b) =>
      b.includes(`UID:schoolday-${LOTTA}-20261013@wuselwall.app`)
    );
    return lineStartingWith(block ?? [], "SEQUENCE:");
  };
  const minutes = (iso: string) => Math.floor(Date.parse(iso) / 60_000);
  assertEquals(
    seqOf(render(schoolFeed("day"))),
    `SEQUENCE:${minutes("2026-10-12T09:30:00Z")}`,
  );

  const edited = schoolData();
  edited.timetables[0].updated_at = "2026-10-12T10:31:00Z";
  assertEquals(
    seqOf(render(schoolFeed("day", edited))),
    `SEQUENCE:${minutes("2026-10-12T10:31:00Z")}`,
  );
});

Deno.test("lessons mode: one VEVENT per lesson with the room; a cancelled lesson is STATUS:CANCELLED", () => {
  const data = schoolData({
    exceptions: [{
      id: "x1",
      timetable_id: "tt1",
      on_date: "2026-10-13",
      period_index: 2,
      kind: "cancelled",
      subject_id: null,
      teacher: null,
      room: null,
      starts_at: null,
      ends_at: null,
      note: null,
      created_by_profile_id: LOTTA,
    }],
  });
  const out = render(schoolFeed("lessons", data));
  const blocks = schoolBlocks(out);
  assertEquals(blocks.length, 2 * tuesdaysInWindow());

  const math = blocks.find((b) =>
    b.includes(`UID:lesson-l1-20261013@wuselwall.app`)
  );
  assert(math, "lesson l1 has its UID");
  assertEquals(lineStartingWith(math, "SUMMARY:"), "SUMMARY:Lotta: Mathematik");
  assertEquals(lineStartingWith(math, "LOCATION:"), "LOCATION:R1");
  assertEquals(lineStartingWith(math, "STATUS:"), "STATUS:CONFIRMED");

  const german = blocks.find((b) =>
    b.includes(`UID:lesson-l2-20261013@wuselwall.app`)
  );
  assertEquals(lineStartingWith(german ?? [], "STATUS:"), "STATUS:CANCELLED");
  assertEquals(
    lineStartingWith(german ?? [], "DESCRIPTION:"),
    "DESCRIPTION:Entfall · Lesebuch mitbringen",
  );
});

Deno.test("English household: School and Cancelled", () => {
  const data = schoolData({
    exceptions: [{
      id: "x1",
      timetable_id: "tt1",
      on_date: "2026-10-13",
      period_index: 2,
      kind: "cancelled",
      subject_id: null,
      teacher: null,
      room: null,
      starts_at: null,
      ends_at: null,
      note: null,
      created_by_profile_id: LOTTA,
    }],
  });
  const en = (f: IcsFeed) =>
    renderIcs(
      { ...f, household: { ...f.household, locale: "en-GB" } },
      { now: NOW, host: HOST },
    );
  const day = schoolBlocks(en(schoolFeed("day", data))).find((b) =>
    b.includes(`UID:schoolday-${LOTTA}-20261013@wuselwall.app`)
  );
  assertEquals(
    lineStartingWith(day ?? [], "SUMMARY:"),
    "SUMMARY:Lotta: School",
  );
  assertEquals(
    lineStartingWith(day ?? [], "DESCRIPTION:"),
    "DESCRIPTION:1. Ma · 2. D (Cancelled)",
  );
});

Deno.test("off, or no school rows in the feed: no school events and no school zone", () => {
  const withoutSchool = feed({ members: { [LOTTA]: "Lotta" } });
  for (
    const out of [
      render(withoutSchool),
      render(feed({ filter: { school: "off" } })),
    ]
  ) {
    assertEquals(schoolBlocks(out).length, 0);
    assertFalse(out.includes("Schule"));
    assertFalse(out.includes("TZID=Europe/Berlin:2026"));
  }
});

Deno.test("school output is deterministic, CRLF and at most 75 octets per line", () => {
  const long = schoolData();
  long.lessons[1].note =
    "Bitte Sportsachen, Turnbeutel und Lesebuch mitbringen; danke für die Hilfe beim Packen am Abend";
  const a = render(schoolFeed("lessons", long));
  assertEquals(a, render(schoolFeed("lessons", long)));
  assert(a.endsWith("\r\n"));
  for (const line of a.split("\r\n").filter((l) => l !== "")) {
    assert(
      new TextEncoder().encode(line).length <= 75,
      `line too long: ${line}`,
    );
  }
  assertEquals(schoolBlocks(a).length, 2 * tuesdaysInWindow());
});

Deno.test("reference parser (ical.js) reads the school events", () => {
  const out = render(schoolFeed("day"));
  const root = new ICAL.Component(ICAL.parse(out));
  const school = root.getAllSubcomponents("vevent").filter((
    v: { getFirstPropertyValue(n: string): unknown },
  ) => v.getFirstPropertyValue("x-wuselwall-kind") === "school");
  assertEquals(school.length, tuesdaysInWindow());
  const start = school[0].getFirstPropertyValue("dtstart");
  assertEquals(start.isDate, false);
});
