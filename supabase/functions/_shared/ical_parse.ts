// Parses an imported ICS feed (RFC 5545 VEVENTs) and expands it into the rows the server stores
// in app.external_occurrence (FR-1.9, specs/05 "Later: importing external calendars").
//
// The recurrence engine is not written again here: a VEVENT becomes an EventRow (and its
// RECURRENCE-ID children OverrideRows) and goes through `expand()` of occurrences.ts, the same
// code the household's own events use. What this module adds is the ICS side: content lines
// (folding, escaping, quoted parameters), DATE / DATE-TIME / TZID / UTC / floating times, DURATION,
// EXDATE, RDATE, STATUS, and the window and caps of an import.
//
// Decisions the feed cannot make for us:
// - A time with no zone (floating) and an unknown or Windows zone name ("W. Europe Standard
//   Time") is read in the household's timezone.
// - A timed VEVENT with neither DTEND nor DURATION lasts one hour (RFC: zero; a zero-length
//   event would not show on the calendar).
// - An RRULE outside the supported subset (occurrences.ts) is dropped, so only the first
//   occurrence of that series is kept, and counted in `unsupported`.
// - RDATE values become single occurrences of their own, so a date-time RDATE needs no special
//   series support; EXDATE removes the matching local date from the series and from RDATEs.
// - Overrides (RECURRENCE-ID) apply to a series with an RRULE, as the household's events do.
//   A RECURRENCE-ID child of a single event (no RRULE) replaces that event, and a child with no
//   master at all is shown as a single occurrence.
//
// Pure: no I/O. The caller passes the text, the household timezone and the clock.
import { Temporal } from "npm:temporal-polyfill@0.3.0";
import {
  addDays,
  type EventRow,
  expand,
  type OverrideRow,
  validateRrule,
} from "./occurrences.ts";

/** Calendar days kept before today, and after today, in one import. */
export const IMPORT_PAST_DAYS = 30;
export const IMPORT_FUTURE_DAYS = 400;
/** At most this many stored rows per calendar; the earliest are kept. */
export const MAX_IMPORT_ROWS = 5000;
/** A timed VEVENT without an end lasts this long. */
const DEFAULT_DURATION_MS = 60 * 60 * 1000;
const DAY_MS = 86_400_000;

/** One stored occurrence, as api.external_calendar_store takes it. */
export type ExternalRow = {
  uid: string;
  starts_at: string | null;
  ends_at: string | null;
  all_day: boolean;
  start_date: string | null;
  end_date: string | null;
  title: string;
  location: string | null;
};

export type ExpandResult = {
  rows: ExternalRow[];
  /** VEVENTs with a usable DTSTART (and UID), before expansion. */
  events: number;
  /** VEVENTs or RECURRENCE-IDs that could not be read. */
  skipped: number;
  /** Series whose RRULE is outside the supported subset (first occurrence only). */
  unsupported: number;
  /** True when more than MAX_IMPORT_ROWS occurrences fell in the window; the earliest are kept. */
  truncated: boolean;
};

export class IcsError extends Error {
  constructor(readonly code: "not_ics") {
    super(code);
    this.name = "IcsError";
  }
}

// ---------------------------------------------------------------- content lines

export type ContentLine = {
  name: string;
  params: Record<string, string>;
  value: string;
};

/** The logical lines of a feed: CRLF or LF, with folded continuation lines joined. */
export function unfoldLines(text: string): string[] {
  const out: string[] = [];
  for (const line of text.replace(/^\u{FEFF}/u, "").split(/\r\n|\n|\r/)) {
    if (line === "") continue; // blank lines carry nothing in an iCalendar file
    if ((line.startsWith(" ") || line.startsWith("\t")) && out.length > 0) {
      out[out.length - 1] += line.slice(1);
    } else {
      out.push(line);
    }
  }
  return out;
}

/** Index of the first colon outside double quotes, or -1. */
function valueColon(line: string): number {
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') quoted = !quoted;
    else if (ch === ":" && !quoted) return i;
  }
  return -1;
}

/** Splits on a separator outside double quotes. */
function splitOutsideQuotes(text: string, sep: string): string[] {
  const out: string[] = [];
  let quoted = false;
  let start = 0;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === '"') quoted = !quoted;
    else if (ch === sep && !quoted) {
      out.push(text.slice(start, i));
      start = i + 1;
    }
  }
  out.push(text.slice(start));
  return out;
}

/** `NAME;PARAM=value;PARAM="quoted:value":VALUE` as name, parameters and the raw value. */
export function parseContentLine(line: string): ContentLine | null {
  const colon = valueColon(line);
  if (colon <= 0) return null;
  const [name, ...rest] = splitOutsideQuotes(line.slice(0, colon), ";");
  const params: Record<string, string> = {};
  for (const piece of rest) {
    const eq = piece.indexOf("=");
    if (eq <= 0) continue;
    const key = piece.slice(0, eq).trim().toUpperCase();
    let value = piece.slice(eq + 1).trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.slice(1, -1);
    }
    params[key] = value;
  }
  return {
    name: name.trim().toUpperCase(),
    params,
    value: line.slice(colon + 1),
  };
}

/** TEXT values: \\ \; \, \n and \N are unescaped. */
export function unescapeText(value: string): string {
  return value.replace(/\\([\\;,nN])/g, (_, ch: string) => (ch === "n" || ch === "N" ? "\n" : ch));
}

// ---------------------------------------------------------------- times

/**
 * A DTSTART-like value as written: a date, a local date-time (floating, or in TZID), or a UTC
 * date-time. `time` is HH:MM:SS for the date-time kinds.
 */
export type RawTime =
  | { kind: "date"; date: string; time: null; tzid: null }
  | { kind: "floating"; date: string; time: string; tzid: null }
  | { kind: "utc"; date: string; time: string; tzid: null }
  | { kind: "tzid"; date: string; time: string; tzid: string };

const zoneCache = new Map<string, string | null>();

/** The zone name when Temporal knows it, else null (Windows names and paths are unknown). */
function knownZone(name: string): string | null {
  if (!zoneCache.has(name)) {
    let ok = true;
    try {
      Temporal.PlainDate.from("2000-01-01").toZonedDateTime(name);
    } catch {
      ok = false;
    }
    zoneCache.set(name, ok ? name : null);
  }
  return zoneCache.get(name) ?? null;
}

function validDate(y: string, m: string, d: string): string | null {
  const date = `${y}-${m}-${d}`;
  try {
    Temporal.PlainDate.from(date);
    return date;
  } catch {
    return null;
  }
}

/** One value of a DATE, DATE-TIME or PERIOD-free date-time property; null when malformed. */
export function parseRawTime(value: string, params: Record<string, string>): RawTime | null {
  const v = value.trim();
  const dateOnly = /^(\d{4})(\d{2})(\d{2})$/.exec(v);
  if (dateOnly) {
    const date = validDate(dateOnly[1], dateOnly[2], dateOnly[3]);
    return date ? { kind: "date", date, time: null, tzid: null } : null;
  }
  if ((params.VALUE ?? "").toUpperCase() === "DATE") return null;
  const dt = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})?(Z)?$/i.exec(v);
  if (!dt) return null;
  const date = validDate(dt[1], dt[2], dt[3]);
  if (!date) return null;
  const hh = Number(dt[4]);
  const mm = Number(dt[5]);
  const ss = dt[6] === undefined ? 0 : Number(dt[6]);
  if (hh > 23 || mm > 59 || ss > 60) return null;
  const time = `${dt[4]}:${dt[5]}:${String(Math.min(ss, 59)).padStart(2, "0")}`;
  if (dt[7]) return { kind: "utc", date, time, tzid: null };
  if (params.TZID) {
    return { kind: "tzid", date, time, tzid: params.TZID.replace(/^\//, "") };
  }
  return { kind: "floating", date, time, tzid: null };
}

/** The zone of a time: UTC, its TZID when known, else the household's. Dates use the household's. */
function zoneOf(t: RawTime, householdTz: string): string {
  if (t.kind === "utc") return "UTC";
  if (t.kind === "tzid") return knownZone(t.tzid) ?? householdTz;
  return householdTz;
}

/** Epoch ms of a time in `zone` (UTC times ignore the zone). */
function instantOf(t: RawTime, zone: string): number {
  if (t.kind === "utc") return Date.parse(`${t.date}T${t.time}Z`);
  if (t.kind === "date") return Temporal.PlainDate.from(t.date).toZonedDateTime(zone).epochMilliseconds;
  return Temporal.PlainDateTime.from(`${t.date}T${t.time}`)
    .toZonedDateTime(zone, { disambiguation: "compatible" }).epochMilliseconds;
}

function localDateOf(ms: number, zone: string): string {
  return Temporal.Instant.fromEpochMilliseconds(ms).toZonedDateTimeISO(zone).toPlainDate().toString();
}

function isoOf(ms: number): string {
  return new Date(ms).toISOString().replace(".000Z", "Z");
}

/** DURATION: PnW, or [+-]PnDTnHnMnS, in milliseconds; null when not understood. */
export function parseDuration(value: string | undefined): number | null {
  if (!value) return null;
  const m = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(value.trim());
  if (!m || value.trim().endsWith("T")) return null;
  const parts = [m[2], m[3], m[4], m[5], m[6]];
  if (parts.every((p) => p === undefined)) return null;
  const n = (i: number) => (m[i] === undefined ? 0 : Number(m[i]));
  const ms = n(2) * 7 * DAY_MS + n(3) * DAY_MS + n(4) * 3_600_000 + n(5) * 60_000 + n(6) * 1000;
  return m[1] === "-" ? -ms : ms;
}

// ---------------------------------------------------------------- VEVENTs

export type VEvent = {
  uid: string;
  summary: string;
  location: string | null;
  status: string | null;
  dtstart: RawTime;
  dtend: RawTime | null;
  duration: number | null;
  rrule: string | null;
  exdates: RawTime[];
  rdates: RawTime[];
  recurrenceId: RawTime | null;
};

/** The values of a multi-valued property (comma separated, outside quotes). */
function valuesOf(line: ContentLine): string[] {
  return line.value.split(",").map((v) => v.trim()).filter((v) => v !== "");
}

function toVEvent(props: ContentLine[]): VEvent | null {
  const first = (name: string) => props.find((p) => p.name === name);
  const uid = first("UID")?.value.trim();
  if (!uid) return null;
  const startProp = first("DTSTART");
  const ridProp = first("RECURRENCE-ID");
  const recurrenceId = ridProp ? parseRawTime(ridProp.value, ridProp.params) : null;
  let dtstart = startProp ? parseRawTime(startProp.value, startProp.params) : null;
  // A cancelled occurrence may omit DTSTART: its RECURRENCE-ID says which one it is.
  if (!dtstart && recurrenceId && first("STATUS")?.value.trim().toUpperCase() === "CANCELLED") {
    dtstart = recurrenceId;
  }
  if (!dtstart) return null;

  const endProp = first("DTEND");
  const dtend = endProp ? parseRawTime(endProp.value, endProp.params) : null;
  const durProp = first("DURATION");
  const exdates: RawTime[] = [];
  const rdates: RawTime[] = [];
  for (const p of props.filter((x) => x.name === "EXDATE")) {
    for (const v of valuesOf(p)) {
      const t = parseRawTime(v, p.params);
      if (t) exdates.push(t);
    }
  }
  for (const p of props.filter((x) => x.name === "RDATE")) {
    for (const v of valuesOf(p)) {
      // A PERIOD value (start/end) contributes its start; the length is the event's own.
      const t = parseRawTime(v.split("/")[0], p.params);
      if (t) rdates.push(t);
    }
  }

  return {
    uid,
    summary: unescapeText(first("SUMMARY")?.value ?? ""),
    location: unescapeText(first("LOCATION")?.value ?? "").trim() || null,
    status: first("STATUS")?.value.trim().toUpperCase() ?? null,
    dtstart,
    dtend,
    duration: parseDuration(durProp?.value),
    rrule: first("RRULE")?.value.trim() || null,
    exdates,
    rdates,
    recurrenceId,
  };
}

/**
 * The VEVENTs of a feed. Properties of nested components (VALARM) are ignored. A VEVENT without
 * UID or a readable DTSTART is counted in `skipped`. Throws IcsError("not_ics") when the text has
 * no BEGIN:VCALENDAR.
 */
export function parseVEvents(text: string): { events: VEvent[]; skipped: number } {
  const lines = unfoldLines(text);
  if (!lines.some((l) => l.trim().toUpperCase() === "BEGIN:VCALENDAR")) {
    throw new IcsError("not_ics");
  }
  const events: VEvent[] = [];
  let skipped = 0;
  const stack: string[] = [];
  let props: ContentLine[] | null = null;
  for (const line of lines) {
    const parsed = parseContentLine(line);
    if (!parsed) continue;
    if (parsed.name === "BEGIN") {
      const component = parsed.value.trim().toUpperCase();
      stack.push(component);
      if (component === "VEVENT") props = [];
      continue;
    }
    if (parsed.name === "END") {
      const component = stack.pop();
      if (component === "VEVENT" && props !== null) {
        const event = toVEvent(props);
        if (event) events.push(event);
        else skipped++;
        props = null;
      }
      continue;
    }
    if (props !== null && stack[stack.length - 1] === "VEVENT") props.push(parsed);
  }
  return { events, skipped };
}

// ---------------------------------------------------------------- the import window

/** The local-date window of one import: 30 days back, 400 days ahead, in the household's zone. */
export function importWindow(now: Date, householdTz: string): { from: string; to: string } {
  const today = Temporal.Instant.fromEpochMilliseconds(now.getTime())
    .toZonedDateTimeISO(householdTz).toPlainDate().toString();
  return {
    from: addDays(today, -IMPORT_PAST_DAYS),
    to: addDays(today, IMPORT_FUTURE_DAYS),
  };
}

// ---------------------------------------------------------------- expansion

type Span = {
  starts_at: string | null;
  ends_at: string | null;
  start_date: string | null;
  end_date: string | null;
  durationMs: number;
  spanDays: number;
};

/**
 * The stored span of a VEVENT: instants for a timed event, inclusive dates for an all-day one
 * (DTEND of an all-day event is exclusive, so one day is taken off it).
 */
function spanOf(v: VEvent, allDay: boolean, zone: string, householdTz: string): Span {
  if (allDay) {
    const startDate = v.dtstart.date;
    let endDate = startDate;
    if (v.dtend && v.dtend.kind === "date") {
      endDate = addDays(v.dtend.date, -1);
    } else if (v.duration !== null && v.duration > 0) {
      endDate = addDays(startDate, Math.max(1, Math.round(v.duration / DAY_MS)) - 1);
    }
    if (endDate < startDate) endDate = startDate;
    return {
      starts_at: null,
      ends_at: null,
      start_date: startDate,
      end_date: endDate,
      durationMs: 0,
      spanDays: daysBetween(startDate, endDate) + 1,
    };
  }
  const s = instantOf(v.dtstart, zone);
  let e: number;
  if (v.dtend && v.dtend.kind !== "date") {
    e = instantOf(v.dtend, zoneOf(v.dtend, householdTz));
  } else if (v.duration !== null && v.duration > 0) {
    e = s + v.duration;
  } else {
    e = s + DEFAULT_DURATION_MS;
  }
  if (e <= s) e = s + DEFAULT_DURATION_MS;
  return {
    starts_at: isoOf(s),
    ends_at: isoOf(e),
    start_date: null,
    end_date: null,
    durationMs: e - s,
    spanDays: 1,
  };
}

function daysBetween(from: string, to: string): number {
  return Temporal.PlainDate.from(from).until(Temporal.PlainDate.from(to), { largestUnit: "days" }).days;
}

function eventRow(
  id: string,
  v: VEvent,
  span: Span,
  zone: string,
  calendarId: string,
  rrule: string | null,
  exdates: string[],
): EventRow {
  return {
    id,
    calendar_id: calendarId,
    title: v.summary.trim() || v.uid,
    description: null,
    location: v.location,
    kind: "appointment",
    presence_state: null,
    status: v.status === "TENTATIVE" ? "tentative" : "confirmed",
    importance: "normal",
    is_all_day: span.start_date !== null,
    starts_at: span.starts_at,
    ends_at: span.ends_at,
    start_date: span.start_date,
    end_date: span.end_date,
    timezone: zone,
    rrule,
    rdates: null,
    exdates: exdates.length > 0 ? exdates : null,
    attendee_ids: [],
  };
}

/**
 * Expands a feed into the rows to store: every occurrence that overlaps the window of the
 * household's timezone, de-duplicated, sorted, and capped at MAX_IMPORT_ROWS. `calendarId` is
 * only a label for the EventRows (the rows stored carry no calendar; the store function adds it).
 */
export function expandIcs(
  text: string,
  opts: { householdTz: string; from: string; to: string; calendarId?: string },
): ExpandResult {
  const { events: vevents, skipped: parseSkipped } = parseVEvents(text);
  let skipped = parseSkipped;
  let unsupported = 0;
  const calendarId = opts.calendarId ?? "calendar";
  const tz = opts.householdTz;

  const masters = vevents.filter((v) => v.recurrenceId === null);
  const children = vevents.filter((v) => v.recurrenceId !== null);
  const eventRows: EventRow[] = [];
  const overrideRows: OverrideRow[] = [];
  const uidOf = new Map<string, string>();
  const masterOf = new Map<string, { id: string; allDay: boolean; zone: string; recurring: boolean }>();
  const cancelledUids = new Set<string>();

  masters.forEach((v, index) => {
    if (v.status === "CANCELLED") {
      cancelledUids.add(v.uid);
      return;
    }
    // A single event that its organiser moved arrives as a RECURRENCE-ID child and no rule: the
    // children are the event now, so the original is not stored (they are handled below).
    if (v.rrule === null && children.some((c) => c.uid === v.uid)) return;
    const id = `${index}|${v.uid}`;
    const allDay = v.dtstart.kind === "date";
    const zone = allDay ? tz : zoneOf(v.dtstart, tz);
    const span = spanOf(v, allDay, zone, tz);
    let rrule = v.rrule;
    if (rrule !== null && !validateRrule(rrule)) {
      unsupported++;
      rrule = null;
    }
    const exdates = v.exdates.map((t) => (t.kind === "date" ? t.date : localDateOf(instantOf(t, zoneOf(t, tz)), zone)));
    eventRows.push(eventRow(id, v, span, zone, calendarId, rrule, exdates));
    uidOf.set(id, v.uid);
    masterOf.set(v.uid, { id, allDay, zone, recurring: rrule !== null });

    // RDATE values: single occurrences of their own, unless EXDATE removes that day.
    v.rdates.forEach((t, k) => {
      const at = t.kind === "date" ? null : instantOf(t, zoneOf(t, tz));
      const day = t.kind === "date" ? t.date : localDateOf(at as number, zone);
      if (exdates.includes(day)) return;
      let rspan: Span;
      if (allDay) {
        const date = t.kind === "date" ? t.date : day;
        rspan = {
          starts_at: null,
          ends_at: null,
          start_date: date,
          end_date: addDays(date, span.spanDays - 1),
          durationMs: 0,
          spanDays: span.spanDays,
        };
      } else {
        const s = at as number;
        rspan = {
          starts_at: isoOf(s),
          ends_at: isoOf(s + (span.durationMs || DEFAULT_DURATION_MS)),
          start_date: null,
          end_date: null,
          durationMs: span.durationMs,
          spanDays: 1,
        };
      }
      const rid = `${id}|rdate${k}`;
      eventRows.push(eventRow(rid, v, rspan, zone, calendarId, null, []));
      uidOf.set(rid, v.uid);
    });
  });

  // Overrides: a RECURRENCE-ID child of a series; a child with no series stands alone.
  for (const child of children) {
    // A cancelled series hides its overrides too.
    if (cancelledUids.has(child.uid)) continue;
    const master = masterOf.get(child.uid);
    if (master) {
      const rid = child.recurrenceId as RawTime;
      const allDay = master.allDay;
      if (allDay !== (child.dtstart.kind === "date") || (rid.kind === "date") !== allDay) {
        skipped++;
        continue;
      }
      if (!master.recurring) continue; // overrides apply to a series with a rule
      // A floating RECURRENCE-ID is read in the series' own zone, as its DTSTART is.
      const originalMs = allDay
        ? instantOf({ kind: "date", date: rid.date, time: null, tzid: null }, master.zone)
        : instantOf(rid, rid.kind === "tzid" ? zoneOf(rid, tz) : master.zone);
      const span = spanOf(child, allDay, master.zone, tz);
      overrideRows.push({
        event_id: master.id,
        recurrence_id: isoOf(originalMs),
        is_cancelled: child.status === "CANCELLED",
        title: child.summary.trim() || null,
        starts_at: span.starts_at,
        ends_at: span.ends_at,
        start_date: span.start_date,
        end_date: span.end_date,
        location: child.location,
        status: child.status === "TENTATIVE" ? "tentative" : child.status === "CONFIRMED" ? "confirmed" : null,
      });
    } else {
      // An occurrence moved or added without its series: shown on its own.
      if (child.status === "CANCELLED") continue;
      const allDay = child.dtstart.kind === "date";
      const zone = allDay ? tz : zoneOf(child.dtstart, tz);
      const id = `orphan|${eventRows.length}|${child.uid}`;
      eventRows.push(eventRow(id, child, spanOf(child, allDay, zone, tz), zone, calendarId, null, []));
      uidOf.set(id, child.uid);
    }
  }

  const occurrences = expand(eventRows, overrideRows, opts.from, opts.to, tz);

  const seen = new Set<string>();
  const rows: ExternalRow[] = [];
  for (const occ of occurrences) {
    const uid = uidOf.get(occ.event_id) ?? occ.event_id;
    const row: ExternalRow = occ.all_day
      ? {
        uid: uid.slice(0, 500),
        starts_at: null,
        ends_at: null,
        all_day: true,
        start_date: occ.local_start_date,
        end_date: occ.local_end_date,
        title: occ.title.slice(0, 200),
        location: occ.location ? occ.location.slice(0, 200) : null,
      }
      : {
        uid: uid.slice(0, 500),
        starts_at: occ.start,
        ends_at: occ.end,
        all_day: false,
        start_date: null,
        end_date: null,
        title: occ.title.slice(0, 200),
        location: occ.location ? occ.location.slice(0, 200) : null,
      };
    const key = `${uid}|${row.starts_at ?? row.start_date}|${row.ends_at ?? row.end_date}`;
    if (seen.has(key)) continue;
    seen.add(key);
    rows.push(row);
  }

  rows.sort((a, b) => {
    const sa = a.starts_at ?? `${a.start_date}T00:00:00Z`;
    const sb = b.starts_at ?? `${b.start_date}T00:00:00Z`;
    return sa < sb ? -1 : sa > sb ? 1 : a.uid.localeCompare(b.uid);
  });
  const truncated = rows.length > MAX_IMPORT_ROWS;
  return {
    rows: truncated ? rows.slice(0, MAX_IMPORT_ROWS) : rows,
    events: vevents.length,
    skipped,
    unsupported,
    truncated,
  };
}
