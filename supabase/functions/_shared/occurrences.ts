// RFC 5545 occurrence expansion for calendar events (specs/05 "Recurrence").
//
// Why it works in local wall-clock time: a recurring series is expanded in the
// event's own timezone (`event.timezone`), so a 07:00 series stays at 07:00 across
// DST changes. Instants are computed only at the end, per occurrence. All-day
// events are whole local dates: start is local midnight of the first day, end is
// local midnight of the day after the last.
//
// Pure module: no I/O, no Supabase client. Shared by the `occurrences` and
// `board-week` Edge Functions.
import { Temporal } from "npm:temporal-polyfill@0.3.0";
import rrulePkg from "npm:rrule@2.8.1";

// deno-lint-ignore no-explicit-any
const { RRule, Weekday } = rrulePkg as any;

export type EventRow = {
  id: string;
  calendar_id: string;
  title: string;
  description: string | null;
  location: string | null;
  kind: "appointment" | "presence";
  presence_state: string | null;
  status: "confirmed" | "tentative" | "cancelled";
  importance: "normal" | "key";
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
};

export type OverrideRow = {
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

export type Occurrence = {
  id: string;
  event_id: string;
  recurrence_id: string | null;
  calendar_id: string;
  title: string;
  location: string | null;
  description: string | null;
  kind: "appointment" | "presence";
  presence_state: string | null;
  status: "confirmed" | "tentative";
  importance: "normal" | "key";
  all_day: boolean;
  start: string;
  end: string;
  local_start_date: string;
  local_end_date: string;
  local_starts: string | null;
  local_ends: string | null;
  attendee_ids: string[];
  is_recurring: boolean;
  is_override: boolean;
  /** 'event': the household's own event (editable). 'imported': an external ICS feed (read-only). */
  source: "event" | "imported";
  /** The imported calendar's colour; null for the household's events (they take member colours). */
  colour_hex: string | null;
};

/** A row of api.external_occurrences (migrations/20261014150000_external_calendars.sql). */
export type ExternalOccurrenceRow = {
  id: string;
  calendar_id: string;
  calendar_name: string;
  colour_hex: string;
  member_ids: string[];
  show_on_board: boolean;
  uid: string;
  starts_at: string | null;
  ends_at: string | null;
  all_day: boolean;
  start_date: string | null;
  end_date: string | null;
  title: string;
  location: string | null;
};

/** Hard cap on occurrences emitted for one event in one call. */
const MAX_PER_EVENT = 1000;
const DAY_MS = 86_400_000;

// ---------------------------------------------------------------------------
// Date helpers ('YYYY-MM-DD' strings in and out)
// ---------------------------------------------------------------------------

export function addDays(date: string, n: number): string {
  return Temporal.PlainDate.from(date).add({ days: n }).toString();
}

function daysBetween(from: string, to: string): number {
  return Temporal.PlainDate.from(from).until(Temporal.PlainDate.from(to), {
    largestUnit: "days",
  }).days;
}

/** Epoch ms of local midnight of `date` in `tz` (exclusive end of a day, or start). */
function startOfDayMs(date: string, tz: string): number {
  return Temporal.PlainDate.from(date).toZonedDateTime(tz).epochMilliseconds;
}

function toLocal(ms: number, tz: string): Temporal.PlainDateTime {
  return Temporal.Instant.fromEpochMilliseconds(ms).toZonedDateTimeISO(tz)
    .toPlainDateTime();
}

function isoOf(ms: number): string {
  return new Date(ms).toISOString().replace(".000Z", "Z");
}

function hhmm(p: Temporal.PlainDateTime): string {
  return `${String(p.hour).padStart(2, "0")}:${
    String(p.minute).padStart(2, "0")
  }`;
}

/**
 * rrule runs in "floating" mode: a local wall-clock time is encoded as if it were
 * UTC, and the generated dates are read back the same way.
 */
function floatOf(p: Temporal.PlainDateTime): Date {
  return new Date(
    Date.UTC(
      p.year,
      p.month - 1,
      p.day,
      p.hour,
      p.minute,
      p.second,
      p.millisecond,
    ),
  );
}

function floatOfDate(date: string, h = 0, m = 0, s = 0): Date {
  const d = Temporal.PlainDate.from(date);
  return new Date(Date.UTC(d.year, d.month - 1, d.day, h, m, s));
}

function fromFloat(d: Date): Temporal.PlainDateTime {
  return Temporal.PlainDateTime.from({
    year: d.getUTCFullYear(),
    month: d.getUTCMonth() + 1,
    day: d.getUTCDate(),
    hour: d.getUTCHours(),
    minute: d.getUTCMinutes(),
    second: d.getUTCSeconds(),
    millisecond: d.getUTCMilliseconds(),
  });
}

// ---------------------------------------------------------------------------
// RRULE subset (contract: "Supported RRULE subset")
// ---------------------------------------------------------------------------

const DAY_CODES = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"];
const FREQS = ["DAILY", "WEEKLY", "MONTHLY", "YEARLY"] as const;
const KNOWN_KEYS = new Set([
  "FREQ",
  "INTERVAL",
  "COUNT",
  "UNTIL",
  "BYDAY",
  "BYMONTHDAY",
  "BYMONTH",
  "BYSETPOS",
  "WKST",
]);

export type ParsedRrule = {
  freq: (typeof FREQS)[number];
  interval: number;
  count: number | null;
  until: { kind: "date"; date: string } | { kind: "utc"; ms: number } | null;
  byday: { weekday: number; n: number | null }[] | null;
  bymonthday: number[] | null;
  bymonth: number[] | null;
  bysetpos: number[] | null;
  wkst: number;
};

function parseIntStrict(v: string): number | null {
  if (!/^[+-]?\d{1,4}$/.test(v)) return null;
  return Number(v);
}

function parseIntList(
  v: string,
  min: number,
  max: number,
  allowNegative: boolean,
): number[] | null {
  const out: number[] = [];
  for (const item of v.split(",")) {
    const n = parseIntStrict(item);
    if (n === null || n === 0) return null;
    if (n < min || n > max) return null;
    if (!allowNegative && n < 0) return null;
    out.push(n);
  }
  return out.length > 0 ? out : null;
}

/** Parses the subset; returns null for anything outside it or malformed. */
export function parseRrule(rrule: string): ParsedRrule | null {
  if (typeof rrule !== "string" || rrule.length === 0 || rrule.length > 500) {
    return null;
  }
  const parts = new Map<string, string>();
  for (const piece of rrule.split(";")) {
    const eq = piece.indexOf("=");
    if (eq <= 0) return null;
    const key = piece.slice(0, eq).trim().toUpperCase();
    const value = piece.slice(eq + 1).trim().toUpperCase();
    if (!KNOWN_KEYS.has(key) || parts.has(key) || value.length === 0) {
      return null;
    }
    parts.set(key, value);
  }

  const freq = parts.get("FREQ");
  if (!freq || !(FREQS as readonly string[]).includes(freq)) return null;
  const typedFreq = freq as ParsedRrule["freq"];

  let interval = 1;
  if (parts.has("INTERVAL")) {
    const n = parseIntStrict(parts.get("INTERVAL")!);
    if (n === null || n < 1 || n > 9999) return null;
    interval = n;
  }

  let count: number | null = null;
  if (parts.has("COUNT")) {
    const n = parseIntStrict(parts.get("COUNT")!);
    if (n === null || n < 1 || n > 100000) return null;
    count = n;
  }

  let until: ParsedRrule["until"] = null;
  if (parts.has("UNTIL")) {
    const raw = parts.get("UNTIL")!;
    const dateOnly = /^(\d{4})(\d{2})(\d{2})$/.exec(raw);
    const dateTime = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/.exec(raw);
    if (dateOnly) {
      const date = `${dateOnly[1]}-${dateOnly[2]}-${dateOnly[3]}`;
      if (!isValidDate(date)) return null;
      until = { kind: "date", date };
    } else if (dateTime) {
      const [, y, mo, d, h, mi, s] = dateTime;
      const ms = Date.UTC(+y, +mo - 1, +d, +h, +mi, +s);
      if (!Number.isFinite(ms) || !isValidDate(`${y}-${mo}-${d}`)) return null;
      until = { kind: "utc", ms };
    } else {
      return null;
    }
  }

  // RFC 5545: COUNT and UNTIL MUST NOT occur in the same rule.
  if (count !== null && until !== null) return null;

  let byday: ParsedRrule["byday"] = null;
  if (parts.has("BYDAY")) {
    const items: { weekday: number; n: number | null }[] = [];
    for (const item of parts.get("BYDAY")!.split(",")) {
      const m = /^([+-]?\d{1,2})?(MO|TU|WE|TH|FR|SA|SU)$/.exec(item);
      if (!m) return null;
      const weekday = DAY_CODES.indexOf(m[2]);
      let n: number | null = null;
      if (m[1] !== undefined) {
        // Ordinals are only meaningful for MONTHLY and YEARLY.
        if (typedFreq !== "MONTHLY" && typedFreq !== "YEARLY") return null;
        n = parseIntStrict(m[1]);
        const limit = typedFreq === "MONTHLY" ? 5 : 53;
        if (n === null || n === 0 || Math.abs(n) > limit) return null;
      }
      items.push({ weekday, n });
    }
    byday = items;
  }

  let bymonthday: number[] | null = null;
  if (parts.has("BYMONTHDAY")) {
    bymonthday = parseIntList(parts.get("BYMONTHDAY")!, -31, 31, true);
    if (!bymonthday) return null;
  }

  let bymonth: number[] | null = null;
  if (parts.has("BYMONTH")) {
    bymonth = parseIntList(parts.get("BYMONTH")!, 1, 12, false);
    if (!bymonth) return null;
  }

  let bysetpos: number[] | null = null;
  if (parts.has("BYSETPOS")) {
    bysetpos = parseIntList(parts.get("BYSETPOS")!, -366, 366, true);
    if (!bysetpos) return null;
  }

  let wkst = 0;
  if (parts.has("WKST")) {
    const idx = DAY_CODES.indexOf(parts.get("WKST")!);
    if (idx < 0) return null;
    wkst = idx;
  }

  return {
    freq: typedFreq,
    interval,
    count,
    until,
    byday,
    bymonthday,
    bymonth,
    bysetpos,
    wkst,
  };
}

function isValidDate(date: string): boolean {
  try {
    Temporal.PlainDate.from(date);
    return true;
  } catch {
    return false;
  }
}

/** True when the rule is inside the supported subset (contract "Supported RRULE subset"). */
export function validateRrule(rrule: string): boolean {
  return parseRrule(rrule) !== null;
}

/** Builds an rrule generator over floating local times. `until` is already local floating. */
function buildRule(p: ParsedRrule, dtstart: Date, untilFloat: Date | null) {
  const freq = {
    YEARLY: RRule.YEARLY,
    MONTHLY: RRule.MONTHLY,
    WEEKLY: RRule.WEEKLY,
    DAILY: RRule.DAILY,
  }[p.freq];
  const opts: Record<string, unknown> = {
    freq,
    interval: p.interval,
    wkst: p.wkst,
    dtstart,
  };
  if (p.count !== null) opts.count = p.count;
  if (untilFloat) opts.until = untilFloat;
  if (p.byday) {
    opts.byweekday = p.byday.map((b) =>
      b.n === null ? new Weekday(b.weekday) : new Weekday(b.weekday, b.n)
    );
  }
  if (p.bymonthday) opts.bymonthday = p.bymonthday;
  if (p.bymonth) opts.bymonth = p.bymonth;
  if (p.bysetpos) opts.bysetpos = p.bysetpos;
  return new RRule(opts);
}

// ---------------------------------------------------------------------------
// Expansion
// ---------------------------------------------------------------------------

/**
 * Occurrences of `events` that overlap the local-date window [from, to] in `tz`
 * (both inclusive), with `overrides` applied. Sorted by start instant, then all-day
 * first, then title.
 */
export function expand(
  events: EventRow[],
  overrides: OverrideRow[],
  from: string,
  to: string,
  tz: string,
): Occurrence[] {
  if (to < from) return [];
  const windowStart = startOfDayMs(from, tz);
  const windowEnd = startOfDayMs(addDays(to, 1), tz);

  const overridesByEvent = new Map<string, Map<number, OverrideRow>>();
  for (const o of overrides) {
    const ms = Date.parse(o.recurrence_id);
    if (!Number.isFinite(ms)) continue;
    let byMs = overridesByEvent.get(o.event_id);
    if (!byMs) {
      byMs = new Map();
      overridesByEvent.set(o.event_id, byMs);
    }
    byMs.set(ms, o);
  }

  const out: Occurrence[] = [];
  for (const ev of events) {
    if (ev.status === "cancelled") continue;
    out.push(
      ...expandEvent(
        ev,
        overridesByEvent.get(ev.id) ?? new Map(),
        windowStart,
        windowEnd,
      ),
    );
  }
  return out.sort(compareOccurrences);
}

/** The order every calendar read uses: start instant, all-day first, title, id. */
export function sortOccurrences(occurrences: Occurrence[]): Occurrence[] {
  return occurrences.sort(compareOccurrences);
}

function compareOccurrences(a: Occurrence, b: Occurrence): number {
  return (
    Date.parse(a.start) - Date.parse(b.start) ||
    Number(b.all_day) - Number(a.all_day) ||
    a.title.localeCompare(b.title, "de") ||
    a.id.localeCompare(b.id)
  );
}

function expandEvent(
  ev: EventRow,
  ovs: Map<number, OverrideRow>,
  windowStart: number,
  windowEnd: number,
): Occurrence[] {
  const tz = ev.timezone;
  const recurring = ev.rrule !== null || (ev.rdates?.length ?? 0) > 0;

  // Series start in local wall-clock time, plus the series' length.
  let dtStartMs: number;
  let dtLocal: Temporal.PlainDateTime;
  let durationMs = 0;
  let spanDays = 1;
  if (ev.is_all_day) {
    if (!ev.start_date || !ev.end_date) return [];
    spanDays = daysBetween(ev.start_date, ev.end_date) + 1;
    dtStartMs = startOfDayMs(ev.start_date, tz);
    dtLocal = Temporal.PlainDate.from(ev.start_date).toPlainDateTime();
  } else {
    if (!ev.starts_at || !ev.ends_at) return [];
    dtStartMs = Date.parse(ev.starts_at);
    durationMs = Date.parse(ev.ends_at) - dtStartMs;
    if (!(durationMs > 0)) return [];
    dtLocal = toLocal(dtStartMs, tz);
  }
  const seriesTime = dtLocal.toPlainTime();
  const dtKey = dtLocal.toString();

  // Candidate local starts keyed by local start (all-day: the date), deduplicated.
  const candidates = new Map<string, Temporal.PlainDateTime>();
  const keyOf = (p: Temporal.PlainDateTime) =>
    ev.is_all_day ? p.toPlainDate().toString() : p.toString();
  const add = (p: Temporal.PlainDateTime) => {
    const k = keyOf(p);
    if (!candidates.has(k)) candidates.set(k, p);
  };

  // RFC 5545: DTSTART is always the first occurrence, even if the rule would not produce it.
  add(dtLocal);
  for (const d of ev.rdates ?? []) {
    add(Temporal.PlainDate.from(d).toPlainDateTime(seriesTime));
  }

  if (ev.rrule !== null) {
    const parsed = parseRrule(ev.rrule);
    if (!parsed) return [];
    let untilFloat: Date | null = null;
    if (parsed.until?.kind === "date") {
      untilFloat = floatOfDate(parsed.until.date, 23, 59, 59);
    } else if (parsed.until?.kind === "utc") {
      untilFloat = floatOf(toLocal(parsed.until.ms, tz));
    }
    const rule = buildRule(parsed, floatOf(dtLocal), untilFloat);

    // Generate a little beyond the window so occurrences that started before it
    // but are still running inside it are found; the overlap check trims the rest.
    const padDays =
      (ev.is_all_day ? spanDays : Math.ceil(durationMs / DAY_MS)) + 2;
    const winFrom = toLocal(windowStart, tz).toPlainDate().toString();
    const winTo = toLocal(windowEnd, tz).toPlainDate().toString();
    const generated: Date[] = rule.between(
      floatOfDate(addDays(winFrom, -padDays)),
      floatOfDate(addDays(winTo, 2), 23, 59, 59),
      true,
    );
    for (const d of generated) add(fromFloat(d));

    // An override can move an occurrence from outside the window into it, so also
    // generate the neighbourhood of each overridden original.
    for (const o of ovs.values()) {
      const originalDate = toLocal(Date.parse(o.recurrence_id), tz)
        .toPlainDate().toString();
      const near: Date[] = rule.between(
        floatOfDate(addDays(originalDate, -1)),
        floatOfDate(addDays(originalDate, 1), 23, 59, 59),
        true,
      );
      for (const d of near) add(fromFloat(d));
    }
  }

  const exdates = new Set(ev.exdates ?? []);
  const out: Occurrence[] = [];
  for (
    const [key, local] of [...candidates.entries()].sort(([a], [b]) =>
      a.localeCompare(b)
    )
  ) {
    const localDate = local.toPlainDate().toString();
    if (exdates.has(localDate)) continue;

    // Base span of this occurrence.
    let startDate = localDate;
    let endDate = addDays(localDate, spanDays - 1);
    let startMs: number;
    let endMs: number;
    if (ev.is_all_day) {
      startMs = startOfDayMs(startDate, tz);
      endMs = startOfDayMs(addDays(endDate, 1), tz);
    } else {
      // The series' own start keeps its stored instant (exact even in a DST fold).
      startMs = key === dtKey
        ? dtStartMs
        : local.toZonedDateTime(tz, { disambiguation: "compatible" })
          .epochMilliseconds;
      endMs = startMs + durationMs;
    }

    // Original start instant: the identity an override refers to.
    const originalMs = startMs;
    const isRecurring = recurring;
    let title = ev.title;
    let location = ev.location;
    let status: "confirmed" | "tentative" = ev.status === "tentative"
      ? "tentative"
      : "confirmed";
    let isOverride = false;

    const o = isRecurring ? ovs.get(originalMs) : undefined;
    if (o) {
      if (o.is_cancelled || o.status === "cancelled") continue;
      isOverride = true;
      title = o.title ?? title;
      location = o.location ?? location;
      if (o.status === "confirmed" || o.status === "tentative") {
        status = o.status;
      }
      if (ev.is_all_day) {
        if (o.start_date !== null || o.end_date !== null) {
          const sd = o.start_date ?? startDate;
          const ed = o.end_date ??
            (o.start_date !== null ? addDays(sd, spanDays - 1) : endDate);
          if (ed >= sd) {
            startDate = sd;
            endDate = ed;
          }
        }
        startMs = startOfDayMs(startDate, tz);
        endMs = startOfDayMs(addDays(endDate, 1), tz);
      } else if (o.starts_at !== null || o.ends_at !== null) {
        const s = o.starts_at !== null ? Date.parse(o.starts_at) : startMs;
        const e = o.ends_at !== null
          ? Date.parse(o.ends_at)
          : o.starts_at !== null
          ? s + durationMs
          : endMs;
        if (e > s) {
          startMs = s;
          endMs = e;
        }
      }
    }

    const overlaps = startMs < windowEnd &&
      (endMs > windowStart || (startMs === endMs && startMs >= windowStart));
    if (!overlaps) continue;

    let localEndDate: string;
    let localStarts: string | null = null;
    let localEnds: string | null = null;
    if (ev.is_all_day) {
      localEndDate = endDate;
    } else {
      const s = toLocal(startMs, tz);
      const e = toLocal(endMs, tz);
      // Inclusive end date: a 23:30 to 00:00 event ends on the day it started.
      localEndDate = toLocal(endMs > startMs ? endMs - 1 : startMs, tz)
        .toPlainDate().toString();
      localStarts = hhmm(s);
      localEnds = hhmm(e);
      startDate = s.toPlainDate().toString();
    }

    out.push({
      id: `${ev.id}|${isRecurring ? isoOf(originalMs) : "single"}`,
      event_id: ev.id,
      recurrence_id: isRecurring ? isoOf(originalMs) : null,
      calendar_id: ev.calendar_id,
      title,
      location,
      description: ev.description,
      kind: ev.kind,
      presence_state: ev.presence_state,
      status,
      importance: ev.importance,
      all_day: ev.is_all_day,
      start: isoOf(startMs),
      end: isoOf(endMs),
      local_start_date: startDate,
      local_end_date: localEndDate,
      local_starts: localStarts,
      local_ends: localEnds,
      attendee_ids: ev.attendee_ids,
      is_recurring: isRecurring,
      is_override: isOverride,
      source: "event",
      colour_hex: null,
    });
    if (out.length >= MAX_PER_EVENT) break;
  }
  return out;
}

/**
 * One stored row of an imported calendar as an Occurrence: read-only, in the calendar's colour,
 * with the calendar's members. Times are local to the household's timezone `tz`. An imported
 * occurrence is a key appointment on the week board when its calendar shows on the board.
 */
export function importedOccurrence(row: ExternalOccurrenceRow, tz: string): Occurrence {
  let start: string;
  let end: string;
  let localStartDate: string;
  let localEndDate: string;
  let localStarts: string | null = null;
  let localEnds: string | null = null;
  if (row.all_day) {
    const sd = row.start_date ?? "";
    const ed = row.end_date ?? sd;
    start = isoOf(startOfDayMs(sd, tz));
    end = isoOf(startOfDayMs(addDays(ed, 1), tz));
    localStartDate = sd;
    localEndDate = ed;
  } else {
    const startMs = Date.parse(row.starts_at ?? "");
    const endMs = Date.parse(row.ends_at ?? "");
    start = isoOf(startMs);
    end = isoOf(endMs);
    const s = toLocal(startMs, tz);
    const e = toLocal(endMs, tz);
    localEndDate = toLocal(endMs > startMs ? endMs - 1 : startMs, tz).toPlainDate().toString();
    localStartDate = s.toPlainDate().toString();
    localStarts = hhmm(s);
    localEnds = hhmm(e);
  }
  return {
    id: `imported|${row.id}`,
    event_id: `${row.calendar_id}|${row.uid}`,
    recurrence_id: null,
    calendar_id: row.calendar_id,
    title: row.title,
    location: row.location,
    description: null,
    kind: "appointment",
    presence_state: null,
    status: "confirmed",
    importance: row.show_on_board ? "key" : "normal",
    all_day: row.all_day,
    start,
    end,
    local_start_date: localStartDate,
    local_end_date: localEndDate,
    local_starts: localStarts,
    local_ends: localEnds,
    attendee_ids: row.member_ids,
    is_recurring: false,
    is_override: false,
    source: "imported",
    colour_hex: row.colour_hex,
  };
}
