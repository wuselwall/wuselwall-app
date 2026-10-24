// RFC 5545 rendering of a household's calendar feed (specs/05 "The ICS feed").
//
// Pure: takes the JSON that `api.ics_feed` returns and gives back the .ics text. No I/O.
// Times are written in the event's own zone (TZID) so a 07:00 series stays at 07:00
// across DST, and every referenced zone gets a VTIMEZONE built from its real transitions.
import { Temporal } from "npm:temporal-polyfill@0.3.0";
import { pickLang } from "./locale.ts";
import { ICS_DE } from "./ics_de.ts";
import { ICS_EN } from "./ics_en.ts";
import { ICS_FR } from "./ics_fr.ts";
import { ICS_ES } from "./ics_es.ts";
import {
  type LessonJson,
  lessonSourceId,
  projectSchoolDays,
  type SchoolData,
  type SchoolDayJson,
  type TimetableRow,
} from "./school.ts";

export type FeedEvent = {
  id: string;
  calendar_id: string;
  title: string;
  description: string | null;
  location: string | null;
  kind: "appointment" | "presence";
  presence_state: string | null;
  status: string;
  importance: string;
  is_all_day: boolean;
  starts_at: string | null;
  ends_at: string | null;
  start_date: string | null;
  end_date: string | null;
  timezone: string;
  rrule: string | null;
  rdates: string[] | null;
  exdates: string[] | null;
  attendee_ids: string[];
  uid: string | null;
  sequence: number;
  created_at: string;
  updated_at: string;
  deleted: boolean;
};

export type FeedOverride = {
  event_id: string;
  recurrence_id: string;
  is_cancelled: boolean;
  title: string | null;
  starts_at: string | null;
  ends_at: string | null;
  start_date: string | null;
  end_date: string | null;
  location: string | null;
  status: string | null;
};

export type IcsFeed = {
  household: { name: string; timezone: string; locale?: string | null };
  filter?: unknown;
  revision: number;
  events: FeedEvent[];
  overrides: FeedOverride[];
  attendees: Record<string, string>;
  /** Present when the token asks for school days ("day" or "lessons"); absent when "off". */
  school?: SchoolData;
  /** The children named in the school rows: profile id → display name. */
  members?: Record<string, string>;
  /** Imported occurrences (FR-1.9). Present only when the token is subscribed; see subscribedOccurrences. */
  external?: ExternalOccurrence[];
  /** The active members' birthdays (specs/27); absent on servers before 20261025100000. See feedBirthdays. */
  birthdays?: FeedBirthday[];
};

/** A member's birthday, as api.ics_feed sends it. */
export type FeedBirthday = {
  profile_id: string;
  name: string;
  /** The birth date, `YYYY-MM-DD`. */
  birthday: string;
};

/** One occurrence of an imported calendar, as api.ics_feed sends it. The raw UID never leaves the database. */
export type ExternalOccurrence = {
  calendar_id: string;
  /** SHA-256 hex of the source UID, for the stable UID of the feed's VEVENT. */
  uid_hash: string;
  /** The calendar's members; empty = the whole family. */
  member_ids: string[];
  starts_at: string | null;
  ends_at: string | null;
  all_day: boolean;
  start_date: string | null;
  end_date: string | null;
  title: string;
  location: string | null;
};

export type RenderOptions = {
  now: Date;
  /** Domain for a fallback UID, used only if an event has none. */
  host: string;
};

const CRLF = "\r\n";

/** Escapes a TEXT value (RFC 5545 3.3.11). The backslash goes first. */
export function escapeText(value: string): string {
  return value
    .replace(/\\/g, "\\\\")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,")
    .replace(/\r\n|\r|\n/g, "\\n");
}

function utf8Octets(codePoint: number): number {
  if (codePoint < 0x80) return 1;
  if (codePoint < 0x800) return 2;
  if (codePoint < 0x10000) return 3;
  return 4;
}

/**
 * Folds one content line to 75 octets. Counts UTF-8 bytes and never splits a
 * character; a continuation line starts with one space and carries 74 octets.
 */
export function foldLine(line: string): string {
  const parts: string[] = [];
  let current = "";
  let octets = 0;
  let limit = 75;
  for (const ch of line) {
    const n = utf8Octets(ch.codePointAt(0) ?? 0);
    if (octets + n > limit) {
      parts.push(current);
      current = "";
      octets = 0;
      limit = 74;
    }
    current += ch;
    octets += n;
  }
  parts.push(current);
  return parts.join(CRLF + " ");
}

const pad = (n: number, width = 2) => String(n).padStart(width, "0");

type Fields = {
  year: number;
  month: number;
  day: number;
  hour?: number;
  minute?: number;
  second?: number;
};

function ymd(f: Fields): string {
  return `${pad(f.year, 4)}${pad(f.month)}${pad(f.day)}`;
}

function ymdhms(f: Fields): string {
  return `${ymd(f)}T${pad(f.hour ?? 0)}${pad(f.minute ?? 0)}${
    pad(f.second ?? 0)
  }`;
}

/** UTC form with the trailing Z, for DTSTAMP, CREATED and LAST-MODIFIED. */
function utcStamp(instant: Temporal.Instant): string {
  return `${ymdhms(instant.toZonedDateTimeISO("UTC"))}Z`;
}

/** ±HHMM, or ±HHMMSS when the offset has seconds (historic local mean time). */
function fmtOffset(seconds: number): string {
  const sign = seconds < 0 ? "-" : "+";
  const a = Math.abs(seconds);
  const hh = pad(Math.floor(a / 3600));
  const mm = pad(Math.floor((a % 3600) / 60));
  const ss = a % 60 ? pad(a % 60) : "";
  return `${sign}${hh}${mm}${ss}`;
}

function offsetSeconds(zdt: Temporal.ZonedDateTime): number {
  return Math.round(zdt.offsetNanoseconds / 1e9);
}

function zonedAt(ms: number, tz: string): Temporal.ZonedDateTime {
  return Temporal.Instant.fromEpochMilliseconds(ms).toZonedDateTimeISO(tz);
}

function localFromEpoch(ms: number, offset: number): Temporal.ZonedDateTime {
  return zonedAt(ms + offset * 1000, "UTC");
}

type Component = {
  kind: "STANDARD" | "DAYLIGHT";
  start: string;
  from: number;
  to: number;
};

/**
 * VTIMEZONE components for one zone, one per real transition between the two
 * years (inclusive). A transition is DAYLIGHT when the offset it moves to is
 * above the year's standard offset, the lower of January's and July's offsets.
 * A zone without transitions yields one STANDARD component.
 */
function zoneComponents(
  tz: string,
  fromYear: number,
  toYear: number,
): Component[] {
  const standardOffset = (year: number) =>
    Math.min(
      offsetSeconds(zonedAt(Date.UTC(year, 0, 1), tz)),
      offsetSeconds(zonedAt(Date.UTC(year, 6, 1), tz)),
    );
  const kindFor = (offset: number, year: number): Component["kind"] =>
    offset > standardOffset(year) ? "DAYLIGHT" : "STANDARD";

  const first = zonedAt(Date.UTC(fromYear, 0, 1), tz);
  const endMs = Date.UTC(toYear + 1, 0, 1);
  const initial = offsetSeconds(first);
  const components: Component[] = [{
    kind: kindFor(initial, fromYear),
    start: ymdhms(first),
    from: initial,
    to: initial,
  }];

  let lastOffset = initial;
  let next = first.getTimeZoneTransition("next");
  while (next !== null && next.epochMilliseconds < endMs) {
    const offset = offsetSeconds(next);
    // DTSTART is local wall-clock time as it was before the transition (RFC 5545 3.6.1).
    const before = localFromEpoch(next.epochMilliseconds, lastOffset);
    components.push({
      kind: kindFor(offset, next.year),
      start: ymdhms(before),
      from: lastOffset,
      to: offset,
    });
    lastOffset = offset;
    next = next.getTimeZoneTransition("next");
  }
  return components;
}

function vtimezone(tz: string, fromYear: number, toYear: number): string[] {
  const lines = ["BEGIN:VTIMEZONE", `TZID:${tz}`];
  for (const c of zoneComponents(tz, fromYear, toYear)) {
    lines.push(
      `BEGIN:${c.kind}`,
      `DTSTART:${c.start}`,
      `TZOFFSETFROM:${fmtOffset(c.from)}`,
      `TZOFFSETTO:${fmtOffset(c.to)}`,
      `END:${c.kind}`,
    );
  }
  lines.push("END:VTIMEZONE");
  return lines;
}

/** Years the VTIMEZONE data must cover: every event, override and rdate, plus now and a year ahead. */
function yearSpan(feed: IcsFeed, now: Date): { from: number; to: number } {
  const yearOf = (ms: number) => zonedAt(ms, "UTC").year;
  const nowYear = yearOf(now.getTime());
  let from = nowYear;
  let to = Math.max(nowYear + 1, yearOf(now.getTime() + 400 * 86_400_000) + 1);
  const widen = (y: number) => {
    from = Math.min(from, y);
    to = Math.max(to, y + 1);
  };
  const instantYear = (s: string | null) =>
    s === null ? null : yearOf(Temporal.Instant.from(s).epochMilliseconds);
  const dateYear = (s: string | null) =>
    s === null ? null : Temporal.PlainDate.from(s).year;

  for (const ev of feed.events) {
    for (const y of [instantYear(ev.starts_at), dateYear(ev.start_date)]) {
      if (y !== null) widen(y);
    }
    for (const y of [instantYear(ev.ends_at), dateYear(ev.end_date)]) {
      if (y !== null) widen(y);
    }
    for (const d of [...(ev.rdates ?? []), ...(ev.exdates ?? [])]) {
      widen(Temporal.PlainDate.from(d).year);
    }
    if (ev.rrule !== null) {
      // A series without UNTIL runs on; five years of zone data is what the feed can know.
      const until = /UNTIL=(\d{4})/.exec(ev.rrule);
      widen(until ? Number(until[1]) : nowYear + 5);
    }
  }
  for (const o of feed.overrides) {
    const y = instantYear(o.recurrence_id);
    if (y !== null) widen(y);
  }
  if (feed.school) {
    const w = schoolWindow(now, feed.household.timezone);
    widen(Temporal.PlainDate.from(w.from).year);
    widen(Temporal.PlainDate.from(w.to).year);
  }
  return { from, to };
}

export interface IcsMessages {
  school: string;
  /** A birthday's summary; `{name}` is the member's name. No age, so the series never changes. */
  birthday: string;
  withAttendees: string;
  lessonStatus: Record<Exclude<LessonJson["status"], "normal">, string>;
  presence: Record<
    "working" | "home_office" | "travel" | "away" | "off" | "childcare",
    string
  >;
}

type Ctx = {
  feed: IcsFeed;
  host: string;
  dtstamp: string;
  messages: IcsMessages;
};

function attendeeNames(ctx: Ctx, ids: string[]): string[] {
  return ids
    .map((id) => ctx.feed.attendees[id])
    .filter((name): name is string => typeof name === "string" && name !== "");
}

function statusOf(status: string | null | undefined): string {
  if (status === "tentative") return "TENTATIVE";
  if (status === "cancelled") return "CANCELLED";
  return "CONFIRMED";
}

/** Text lines shared by the series VEVENT and each modified occurrence. */
function commonProps(
  ctx: Ctx,
  ev: FeedEvent,
  title: string,
  location: string | null,
  status: string,
): string[] {
  const names = attendeeNames(ctx, ev.attendee_ids);
  const isPresence = ev.kind === "presence";
  const state = ev.presence_state;
  const base = title ||
    (state && ctx.messages.presence[state as keyof IcsMessages["presence"]]) ||
    state || "";
  const summary = isPresence && names.length > 0
    ? `${names.join(", ")}: ${base}`
    : base;

  const attendeeLine = names.length > 0
    ? `${ctx.messages.withAttendees}: ${names.join(", ")}`
    : null;
  const description = [ev.description, attendeeLine]
    .filter((s): s is string => typeof s === "string" && s !== "")
    .join("\n");

  const lines = [
    `UID:${escapeText(ev.uid ?? `${ev.id}@${ctx.host}`)}`,
    `DTSTAMP:${ctx.dtstamp}`,
    `SEQUENCE:${ev.sequence}`,
    `CREATED:${utcStamp(Temporal.Instant.from(ev.created_at))}`,
    `LAST-MODIFIED:${utcStamp(Temporal.Instant.from(ev.updated_at))}`,
    `SUMMARY:${escapeText(summary)}`,
  ];
  if (description !== "") lines.push(`DESCRIPTION:${escapeText(description)}`);
  if (location) lines.push(`LOCATION:${escapeText(location)}`);
  lines.push(`STATUS:${status}`);
  if (isPresence) {
    lines.push("TRANSP:TRANSPARENT", "X-WUSELWALL-KIND:presence");
  } else {
    lines.push("TRANSP:OPAQUE");
  }
  return lines;
}

/** Time of a series or of one modified occurrence, as DTSTART/DTEND lines. */
function timeLines(
  tz: string,
  allDay: boolean,
  start: Temporal.PlainDate | Temporal.ZonedDateTime,
  end: Temporal.PlainDate | Temporal.ZonedDateTime | null,
): string[] {
  if (allDay) {
    const s = start as Temporal.PlainDate;
    // ICS end dates are exclusive: DTEND is the day after the last day.
    const e = (end as Temporal.PlainDate | null) ?? s;
    return [
      `DTSTART;VALUE=DATE:${ymd(s)}`,
      `DTEND;VALUE=DATE:${ymd(e.add({ days: 1 }))}`,
    ];
  }
  const s = start as Temporal.ZonedDateTime;
  const lines = [`DTSTART;TZID=${tz}:${ymdhms(s)}`];
  if (end !== null) {
    lines.push(`DTEND;TZID=${tz}:${ymdhms(end as Temporal.ZonedDateTime)}`);
  }
  return lines;
}

/** One RDATE/EXDATE value: a date for all-day series, local date-time at the series' time otherwise. */
function valueOf(
  allDay: boolean,
  date: Temporal.PlainDate,
  time: Temporal.PlainTime | null,
): string {
  return allDay || time === null
    ? ymd(date)
    : ymdhms(date.toPlainDateTime(time));
}

function listLine(
  name: string,
  tz: string,
  allDay: boolean,
  values: string[],
): string | null {
  if (values.length === 0) return null;
  const unique = [...new Set(values)].sort();
  const param = allDay ? ";VALUE=DATE" : `;TZID=${tz}`;
  return `${name}${param}:${unique.join(",")}`;
}

function renderSeries(
  ctx: Ctx,
  ev: FeedEvent,
  overrides: FeedOverride[],
): string[] {
  const tz = ev.timezone;
  const allDay = ev.is_all_day;
  let start: Temporal.PlainDate | Temporal.ZonedDateTime;
  let end: Temporal.PlainDate | Temporal.ZonedDateTime | null;
  let time: Temporal.PlainTime | null = null;
  if (allDay) {
    start = Temporal.PlainDate.from(ev.start_date ?? "");
    end = Temporal.PlainDate.from(ev.end_date ?? ev.start_date ?? "");
  } else {
    start = Temporal.Instant.from(ev.starts_at ?? "").toZonedDateTimeISO(tz);
    end = ev.ends_at
      ? Temporal.Instant.from(ev.ends_at).toZonedDateTimeISO(tz)
      : null;
    time = start.toPlainTime();
  }

  // Cancelled occurrences are EXDATEs: the explicit ones and the cancelled overrides.
  const exdates = (ev.exdates ?? []).map((d) =>
    valueOf(allDay, Temporal.PlainDate.from(d), time)
  );
  for (const o of overrides) {
    if (!o.is_cancelled) continue;
    const at = Temporal.Instant.from(o.recurrence_id).toZonedDateTimeISO(tz);
    exdates.push(
      allDay ? ymd(at.toPlainDate()) : ymdhms(at.toPlainDateTime()),
    );
  }

  const rdates = (ev.rdates ?? []).map((d) =>
    valueOf(allDay, Temporal.PlainDate.from(d), time)
  );

  const lines = [
    "BEGIN:VEVENT",
    ...timeLines(tz, allDay, start, end),
    ...commonProps(
      ctx,
      ev,
      ev.title,
      ev.location,
      ev.deleted ? "CANCELLED" : statusOf(ev.status),
    ),
  ];
  if (ev.rrule) lines.push(`RRULE:${ev.rrule}`);
  const rdateLine = listLine("RDATE", tz, allDay, rdates);
  if (rdateLine) lines.push(rdateLine);
  const exdateLine = listLine("EXDATE", tz, allDay, exdates);
  if (exdateLine) lines.push(exdateLine);
  lines.push("END:VEVENT");
  return lines;
}

/** A modified occurrence: the same UID, RECURRENCE-ID of the original start, the changed fields. */
function renderOverride(
  ctx: Ctx,
  ev: FeedEvent,
  o: FeedOverride,
): string[] {
  const tz = ev.timezone;
  const original = Temporal.Instant.from(o.recurrence_id).toZonedDateTimeISO(
    tz,
  );
  const allDay = ev.is_all_day;

  let timing: string[];
  if (allDay) {
    const seriesStart = Temporal.PlainDate.from(ev.start_date ?? "");
    const seriesEnd = Temporal.PlainDate.from(
      ev.end_date ?? ev.start_date ?? "",
    );
    const span = seriesStart.until(seriesEnd).days;
    const start = o.start_date
      ? Temporal.PlainDate.from(o.start_date)
      : original.toPlainDate();
    const end = o.end_date
      ? Temporal.PlainDate.from(o.end_date)
      : start.add({ days: span });
    timing = timeLines(tz, true, start, end);
    timing.unshift(`RECURRENCE-ID;VALUE=DATE:${ymd(original.toPlainDate())}`);
  } else {
    const seriesStart = Temporal.Instant.from(ev.starts_at ?? "");
    const seriesEnd = Temporal.Instant.from(ev.ends_at ?? ev.starts_at ?? "");
    const duration = seriesEnd.epochMilliseconds -
      seriesStart.epochMilliseconds;
    const start = o.starts_at
      ? Temporal.Instant.from(o.starts_at).toZonedDateTimeISO(tz)
      : original;
    const end = o.ends_at
      ? Temporal.Instant.from(o.ends_at).toZonedDateTimeISO(tz)
      : start.add({ milliseconds: duration });
    timing = timeLines(tz, false, start, end);
    timing.unshift(
      `RECURRENCE-ID;TZID=${tz}:${ymdhms(original.toPlainDateTime())}`,
    );
  }

  const status = ev.deleted ? "CANCELLED" : statusOf(o.status ?? ev.status);
  return [
    "BEGIN:VEVENT",
    ...timing,
    ...commonProps(
      ctx,
      ev,
      o.title ?? ev.title,
      o.location ?? ev.location,
      status,
    ),
    "END:VEVENT",
  ];
}

// ── imported calendars (FR-1.9, specs/05 "Later: importing external calendars") ──

/**
 * The imported occurrences a token gets. None unless the filter says `subscribed`. A token that
 * names no profiles gets every calendar; otherwise a calendar with no members (the whole family)
 * and a calendar whose members overlap the named profiles, as the household's own events.
 */
export function subscribedOccurrences(feed: IcsFeed): ExternalOccurrence[] {
  const filter = feed.filter as
    | { subscribed?: unknown; profile_ids?: unknown }
    | null
    | undefined;
  if (filter?.subscribed !== true) return [];
  const named = Array.isArray(filter.profile_ids)
    ? filter.profile_ids.filter((id): id is string => typeof id === "string")
    : [];
  return (feed.external ?? []).filter((o) =>
    named.length === 0 ||
    o.member_ids.length === 0 ||
    o.member_ids.some((id) => named.includes(id))
  );
}

/**
 * One imported occurrence: a plain, read-only VEVENT. The UID is stable for the occurrence (its
 * calendar, the hash of the source UID and the start), so a subscriber's calendar app updates in
 * place. A timed occurrence is written in UTC, so it needs no VTIMEZONE.
 */
function externalVEvent(o: ExternalOccurrence, dtstamp: string): string[] {
  let key: string;
  let timing: string[];
  if (o.all_day) {
    const start = Temporal.PlainDate.from(o.start_date ?? "");
    const end = Temporal.PlainDate.from(o.end_date ?? o.start_date ?? "");
    key = ymd(start);
    // ICS end dates are exclusive: DTEND is the day after the last day.
    timing = [
      `DTSTART;VALUE=DATE:${ymd(start)}`,
      `DTEND;VALUE=DATE:${ymd(end.add({ days: 1 }))}`,
    ];
  } else {
    const start = Temporal.Instant.from(o.starts_at ?? "");
    const end = o.ends_at ? Temporal.Instant.from(o.ends_at) : start;
    // YYYYMMDDTHHMM in UTC: the same instant gives the same UID.
    key = ymdhms(start.toZonedDateTimeISO("UTC")).slice(0, 13);
    timing = [`DTSTART:${utcStamp(start)}`, `DTEND:${utcStamp(end)}`];
  }
  const uid = `ext-${o.calendar_id}-${o.uid_hash}-${key}@wuselwall.app`;
  const lines = [
    "BEGIN:VEVENT",
    `UID:${escapeText(uid)}`,
    `DTSTAMP:${dtstamp}`,
    ...timing,
    `SUMMARY:${escapeText(o.title)}`,
  ];
  if (o.location) lines.push(`LOCATION:${escapeText(o.location)}`);
  lines.push("STATUS:CONFIRMED", "TRANSP:OPAQUE", "END:VEVENT");
  return lines;
}

// ── birthdays (specs/27 "Birthdays") ─────────────────────────────────────────────

/**
 * The birthdays a token gets: those of the members it names (all when it names none), and none
 * when the token is narrowed to presence entries or to particular calendars, neither of which a
 * birthday belongs to.
 */
export function feedBirthdays(feed: IcsFeed): FeedBirthday[] {
  const filter = feed.filter as
    | { profile_ids?: unknown; kinds?: unknown; calendar_ids?: unknown }
    | null
    | undefined;
  const strings = (v: unknown): string[] | null =>
    Array.isArray(v)
      ? v.filter((x): x is string => typeof x === "string")
      : null;
  const kinds = strings(filter?.kinds);
  if (kinds !== null && !kinds.includes("appointment")) return [];
  if ((strings(filter?.calendar_ids) ?? []).length > 0) return [];
  const named = strings(filter?.profile_ids) ?? [];
  return (feed.birthdays ?? []).filter((b) =>
    named.length === 0 || named.includes(b.profile_id)
  );
}

/**
 * One birthday: a yearly all-day VEVENT from the birth date, with a UID per member, so a
 * subscriber's calendar keeps one series that does not change from year to year. A birthday on
 * 29 February falls on the 60th day of the year: 29 February in a leap year, 1 March otherwise,
 * as in the app.
 */
function birthdayVEvent(ctx: Ctx, b: FeedBirthday): string[] {
  const start = Temporal.PlainDate.from(b.birthday);
  const leapDay = start.month === 2 && start.day === 29;
  return [
    "BEGIN:VEVENT",
    `UID:${escapeText(`birthday-${b.profile_id}@wuselwall.app`)}`,
    `DTSTAMP:${ctx.dtstamp}`,
    `DTSTART;VALUE=DATE:${ymd(start)}`,
    `DTEND;VALUE=DATE:${ymd(start.add({ days: 1 }))}`,
    leapDay ? "RRULE:FREQ=YEARLY;BYYEARDAY=60" : "RRULE:FREQ=YEARLY",
    `SUMMARY:${escapeText(ctx.messages.birthday.replace("{name}", b.name))}`,
    "STATUS:CONFIRMED",
    "TRANSP:TRANSPARENT",
    "X-WUSELWALL-KIND:birthday",
    "END:VEVENT",
  ];
}

// ── school days (specs/15 "What goes into the ICS feed") ─────────────────────────

/** The projection window: 30 days back and 120 ahead of today in the household's zone. */
function schoolWindow(
  now: Date,
  tz: string,
): { from: string; to: string } {
  const today = Temporal.Instant.fromEpochMilliseconds(now.getTime())
    .toZonedDateTimeISO(tz).toPlainDate();
  return {
    from: today.subtract({ days: 30 }).toString(),
    to: today.add({ days: 120 }).toString(),
  };
}

/** `day` (one block per child per school day) or `lessons` (every lesson). */
function schoolMode(feed: IcsFeed): "day" | "lessons" {
  const filter = feed.filter as { school?: unknown } | null | undefined;
  return filter?.school === "lessons" ? "lessons" : "day";
}

/** The label of a lesson that differs from the grid, in the household's language. */
function statusLabel(
  status: LessonJson["status"],
  messages: IcsMessages,
): string | null {
  return status === "normal" ? null : messages.lessonStatus[status];
}

/** SEQUENCE from the newest edit of a child's timetables: minutes since the epoch, so it grows with edits. */
function scheduleSequence(rows: TimetableRow[]): number {
  const newest = Math.max(
    ...rows.map((r) => Temporal.Instant.from(r.updated_at).epochMilliseconds),
  );
  return Math.floor(Math.floor(newest / 1000) / 60) % 2147483647;
}

/** The compact form of a date and of "HH:MM", for DTSTART and UID. */
const compactDate = (date: string) => date.replaceAll("-", "");
const localStamp = (date: string, hhmm: string) =>
  `${compactDate(date)}T${hhmm.replace(":", "")}00`;

type SchoolEvent = { zone: string; lines: string[] };

/**
 * The school VEVENTs of the feed. Days come from the same projection the app uses, so the
 * calendar cannot disagree with the board. A child's zone is the one of the school of their
 * most recent timetable. Free days, holidays and days with nothing left to show emit nothing.
 */
function schoolEvents(ctx: Ctx, now: Date): SchoolEvent[] {
  const school = ctx.feed.school;
  if (!school) return [];
  const window = schoolWindow(now, ctx.feed.household.timezone);
  const days = projectSchoolDays(school, window.from, window.to);
  const mode = schoolMode(ctx.feed);

  const timetablesOf = new Map<string, TimetableRow[]>();
  for (const tt of school.timetables) {
    timetablesOf.set(tt.profile_id, [
      ...(timetablesOf.get(tt.profile_id) ?? []),
      tt,
    ]);
  }
  const zoneOf = (memberId: string): string => {
    const rows = timetablesOf.get(memberId) ?? [];
    const latest =
      [...rows].sort((a, b) =>
        b.valid_from.localeCompare(a.valid_from) || b.id.localeCompare(a.id)
      )[0];
    const found = school.schools.find((s) => s.id === latest?.school_id);
    return found?.timezone ?? ctx.feed.household.timezone;
  };
  const nameOf = (memberId: string): string =>
    ctx.feed.members?.[memberId] ?? "";
  const dtstamp = ctx.dtstamp;
  const withName = (memberId: string, text: string) => {
    const name = nameOf(memberId);
    return name === "" ? text : `${name}: ${text}`;
  };

  const out: SchoolEvent[] = [];
  for (const day of days) {
    if (day.starts === null || day.ends === null) continue;
    const zone = zoneOf(day.member_id);
    const rows = timetablesOf.get(day.member_id) ?? [];
    const seq = scheduleSequence(rows);
    const modified = utcStamp(Temporal.Instant.fromEpochMilliseconds(
      Math.max(
        ...rows.map((r) =>
          Temporal.Instant.from(r.updated_at).epochMilliseconds
        ),
      ),
    ));
    if (mode === "day") {
      out.push({
        zone,
        lines: schoolDayVEvent(
          ctx,
          day,
          zone,
          seq,
          modified,
          dtstamp,
          withName,
        ),
      });
    } else {
      for (const lesson of day.lessons) {
        out.push({
          zone,
          lines: schoolLessonVEvent(
            ctx,
            day,
            lesson,
            zone,
            seq,
            modified,
            dtstamp,
            withName,
          ),
        });
      }
    }
  }
  return out;
}

function schoolDayVEvent(
  ctx: Ctx,
  day: SchoolDayJson,
  zone: string,
  seq: number,
  modified: string,
  dtstamp: string,
  withName: (memberId: string, text: string) => string,
): string[] {
  // One line per lesson, cancellations and substitutions included: "1. Ma · 2. D (Entfall)".
  const parts = day.lessons.map((l) => {
    const label = l.period === null ? "" : `${l.period}. `;
    const note = statusLabel(l.status, ctx.messages);
    return `${label}${l.short ?? l.subject}${note ? ` (${note})` : ""}`;
  });
  const summary = withName(day.member_id, ctx.messages.school);
  const lines = [
    "BEGIN:VEVENT",
    `DTSTART;TZID=${zone}:${localStamp(day.date, day.starts!)}`,
    `DTEND;TZID=${zone}:${localStamp(day.date, day.ends!)}`,
    `UID:${
      escapeText(
        `schoolday-${day.member_id}-${compactDate(day.date)}@wuselwall.app`,
      )
    }`,
    `DTSTAMP:${dtstamp}`,
    `SEQUENCE:${seq}`,
    `LAST-MODIFIED:${modified}`,
    `SUMMARY:${escapeText(summary)}`,
  ];
  if (parts.length > 0) {
    lines.push(`DESCRIPTION:${escapeText(parts.join(" · "))}`);
  }
  lines.push(
    "STATUS:CONFIRMED",
    "TRANSP:TRANSPARENT",
    "X-WUSELWALL-KIND:school",
    "END:VEVENT",
  );
  return lines;
}

function schoolLessonVEvent(
  ctx: Ctx,
  day: SchoolDayJson,
  lesson: LessonJson,
  zone: string,
  seq: number,
  modified: string,
  dtstamp: string,
  withName: (memberId: string, text: string) => string,
): string[] {
  const cancelled = lesson.status === "cancelled";
  // A row keeps its UID through edits; the date makes each occurrence its own event.
  const source = lessonSourceId(lesson) ?? `${day.member_id}-${lesson.period}`;
  const uid = `lesson-${source}-${compactDate(day.date)}@wuselwall.app`;
  const note = statusLabel(lesson.status, ctx.messages);
  const description = [
    note,
    lesson.teacher,
    lesson.note,
  ].filter((s): s is string => typeof s === "string" && s !== "").join(" · ");
  const lines = [
    "BEGIN:VEVENT",
    `DTSTART;TZID=${zone}:${localStamp(day.date, lesson.starts)}`,
    `DTEND;TZID=${zone}:${localStamp(day.date, lesson.ends)}`,
    `UID:${escapeText(uid)}`,
    `DTSTAMP:${dtstamp}`,
    `SEQUENCE:${seq}`,
    `LAST-MODIFIED:${modified}`,
    `SUMMARY:${escapeText(withName(day.member_id, lesson.subject))}`,
  ];
  if (lesson.room) lines.push(`LOCATION:${escapeText(lesson.room)}`);
  if (description !== "") lines.push(`DESCRIPTION:${escapeText(description)}`);
  lines.push(
    `STATUS:${cancelled ? "CANCELLED" : "CONFIRMED"}`,
    "TRANSP:TRANSPARENT",
    "X-WUSELWALL-KIND:school",
    "END:VEVENT",
  );
  return lines;
}

/** Renders the feed as RFC 5545 text: CRLF line endings, folded at 75 octets. */
export function renderIcs(feed: IcsFeed, opts: RenderOptions): string {
  const ctx: Ctx = {
    feed,
    host: opts.host,
    dtstamp: utcStamp(
      Temporal.Instant.fromEpochMilliseconds(opts.now.getTime()),
    ),
    messages: ({ de: ICS_DE, en: ICS_EN, fr: ICS_FR, es: ICS_ES })[
      pickLang(undefined, null, feed.household.locale ?? null)
    ],
  };
  const school = schoolEvents(ctx, opts.now);

  const lines = [
    "BEGIN:VCALENDAR",
    "PRODID:-//WuselWall//Calendar//DE",
    "VERSION:2.0",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    `X-WR-CALNAME:${escapeText(feed.household.name)}`,
    `X-WR-TIMEZONE:${feed.household.timezone}`,
  ];

  const zones = new Set<string>();
  for (const ev of feed.events) {
    if (!ev.is_all_day) zones.add(ev.timezone);
  }
  for (const e of school) zones.add(e.zone);
  if (zones.size > 0) {
    const { from, to } = yearSpan(feed, opts.now);
    for (const tz of [...zones].sort()) {
      lines.push(...vtimezone(tz, from, to));
    }
  }

  const overridesByEvent = new Map<string, FeedOverride[]>();
  for (const o of feed.overrides) {
    const list = overridesByEvent.get(o.event_id) ?? [];
    list.push(o);
    overridesByEvent.set(o.event_id, list);
  }

  for (const ev of feed.events) {
    const overrides = overridesByEvent.get(ev.id) ?? [];
    lines.push(...renderSeries(ctx, ev, overrides));
    for (const o of overrides) {
      if (o.is_cancelled) continue;
      lines.push(...renderOverride(ctx, ev, o));
    }
  }

  for (const b of feedBirthdays(feed)) lines.push(...birthdayVEvent(ctx, b));
  for (const e of school) lines.push(...e.lines);
  for (const o of subscribedOccurrences(feed)) {
    lines.push(...externalVEvent(o, ctx.dtstamp));
  }

  lines.push("END:VCALENDAR");
  return lines.map(foldLine).join(CRLF) + CRLF;
}
