// RFC 5545 occurrence expansion for calendar events (specs/05 "Recurrence").
//
// Why it works in local wall-clock time: a recurring series is expanded in the
// event's own timezone (`event.timezone`), so a 07:00 series stays at 07:00 across
// DST changes. Instants are computed only at the end, per occurrence. All-day
// events are whole local dates: start is local midnight of the first day, end is
// local midnight of the day after the last.
//
// The recurrence walk is this module's own (see "RRULE walk" below) so that every step it
// takes is counted: a rule that never matches, such as FREQ=DAILY;BYMONTH=2;BYMONTHDAY=30,
// made the previous engine step day by day to the year 9999 (about five seconds of CPU per
// event; security review 2026-11-01, F6). The walk only ever looks at the periods that can
// reach the requested window, and it stops after a fixed number of them. rrule.js stays the
// reference the differential test compares against.
//
// Pure module: no I/O, no Supabase client. Shared by the `occurrences` and
// `board-week` Edge Functions.
import { Temporal } from "npm:temporal-polyfill@0.3.0";

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
  /** A lighter day (specs/27): absent on servers before 20261024110000. */
  icon_key?: string | null;
  countdown?: boolean;
  tradition?: boolean;
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
  /** The event's content icon, "Darauf freuen wir uns" and the family tradition (specs/27). */
  icon_key?: string | null;
  countdown?: boolean;
  tradition?: boolean;
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
/** No series starts before this year: an earlier DTSTART is not walked (F6). */
export const RRULE_MIN_YEAR = 1900;
/**
 * Candidate periods (days, weeks, months or years) one walk examines at most. A series that
 * starts in 1900 and is read in 2100 is 73,000 daily periods; the cap is above that, so it
 * only ever stops a walk that no real calendar needs (F6).
 */
export const MAX_WALK_PERIODS = 100_000;
/** INTERVAL and COUNT above these are refused; the SQL check allows the same values. */
export const MAX_INTERVAL = 999;
export const MAX_COUNT = 9999;
const DAY_MS = 86_400_000;
/** The most days a month can have, January first. February counts the leap day. */
const MONTH_MAX_DAYS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

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

/** Days since 1970-01-01 of a 'YYYY-MM-DD' date (the walk's integer form). */
function ordinalOfDate(date: string): number {
  const d = Temporal.PlainDate.from(date);
  return ordinalOf(d.year, d.month, d.day);
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
    if (n === null || n < 1 || n > MAX_INTERVAL) return null;
    interval = n;
  }

  let count: number | null = null;
  if (parts.has("COUNT")) {
    const n = parseIntStrict(parts.get("COUNT")!);
    if (n === null || n < 1 || n > MAX_COUNT) return null;
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

  // Rules that can never match are refused here, and by app.rrule_valid in SQL with the same
  // conditions, rather than walked for nothing (F6). A BYMONTHDAY that none of the listed
  // months has (Feb 30, Apr 31, -31 in June); BYDAY mixing plain and n-th weekdays whose
  // weekdays never coincide (MO,1TU: the first Tuesday is never a Monday; MO,1MO is fine);
  // a BYSETPOS beyond the largest set a period can hold.
  if (bymonthday) {
    const months = bymonth ?? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    const feasible = months.some((m) =>
      bymonthday.some((d) => Math.abs(d) <= MONTH_MAX_DAYS[m - 1])
    );
    if (!feasible) return null;
  }
  if (byday) {
    const plainDays = new Set(byday.filter((b) => b.n === null).map((b) => b.weekday));
    const ordinals = byday.filter((b) => b.n !== null);
    if (plainDays.size > 0 && ordinals.length > 0 && !ordinals.some((b) => plainDays.has(b.weekday))) {
      return null;
    }
  }
  if (bysetpos) {
    const largest = maxSetSize(typedFreq, byday, bymonthday, bymonth);
    if (bysetpos.some((pos) => Math.abs(pos) > largest)) return null;
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

/**
 * An upper bound of the number of days one period of the rule can select, before BYSETPOS.
 * Over-estimating is harmless (the walk is bounded anyway); under-estimating would refuse a
 * rule that matches, so every bound here is the loosest true one.
 */
function maxSetSize(
  freq: ParsedRrule["freq"],
  byday: ParsedRrule["byday"],
  bymonthday: ParsedRrule["bymonthday"],
  bymonth: ParsedRrule["bymonth"],
): number {
  const months = bymonth ? bymonth.length : 12;
  // With n-th weekdays among the BYDAY entries, each of them selects at most one day per
  // range, and plain entries only filter those further.
  const ordinals = byday ? byday.filter((b) => b.n !== null).length : 0;
  const plain = byday ? byday.length - ordinals : 0;
  switch (freq) {
    case "DAILY":
      return 1;
    case "WEEKLY":
      return byday ? byday.length : 1;
    case "MONTHLY": {
      if (!byday && !bymonthday) return 1; // the day of DTSTART
      let n = 31;
      if (byday) n = Math.min(n, ordinals > 0 ? ordinals : 5 * plain);
      if (bymonthday) n = Math.min(n, bymonthday.length);
      return n;
    }
    case "YEARLY": {
      // DTSTART's day in each listed month, or in DTSTART's own month.
      if (!byday && !bymonthday) return bymonth ? bymonth.length : 1;
      let n = 366;
      if (byday) {
        n = Math.min(
          n,
          ordinals > 0
            ? (bymonth ? ordinals * months : ordinals)
            : (bymonth ? 5 * plain * months : 53 * plain),
        );
      }
      if (bymonthday) n = Math.min(n, bymonthday.length * months);
      return n;
    }
  }
}

// ---------------------------------------------------------------------------
// RRULE walk
// ---------------------------------------------------------------------------
//
// The semantics are those of python-dateutil and rrule.js for the supported subset: a series
// is a sequence of periods (days, weeks, months, years) from DTSTART, every INTERVAL-th one
// taken; the days of a period are filtered by BYMONTH, BYDAY (plain weekdays, or the n-th
// weekday of the month or year), BYMONTHDAY (negative counts from the end of the month);
// BYSETPOS then picks positions in the filtered list; dates before DTSTART are dropped;
// COUNT and UNTIL end the series. A rule with neither BYDAY nor BYMONTHDAY takes DTSTART's
// day (MONTHLY), month and day (YEARLY) or weekday (WEEKLY).
//
// What differs from rrule.js is the bound: a rule without COUNT starts at the first period
// that can reach the requested days, every walk ends with the last period that can, and no
// walk examines more than MAX_WALK_PERIODS periods. Dates are integers (days since
// 1970-01-01) until they are emitted; Temporal objects only exist for the results.

/** Days since 1970-01-01 of a proleptic Gregorian date (Howard Hinnant's algorithm). */
function ordinalOf(y: number, m: number, d: number): number {
  const yy = m <= 2 ? y - 1 : y;
  const era = Math.floor(yy / 400);
  const yoe = yy - era * 400;
  const doy = Math.floor((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1;
  const doe = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
  return era * 146097 + doe - 719468;
}

/** The inverse of ordinalOf. */
function civilOf(z: number): { y: number; m: number; d: number } {
  const zz = z + 719468;
  const era = Math.floor(zz / 146097);
  const doe = zz - era * 146097;
  const yoe = Math.floor((doe - Math.floor(doe / 1460) + Math.floor(doe / 36524) - Math.floor(doe / 146096)) / 365);
  const doy = doe - (365 * yoe + Math.floor(yoe / 4) - Math.floor(yoe / 100));
  const mp = Math.floor((5 * doy + 2) / 153);
  const d = doy - Math.floor((153 * mp + 2) / 5) + 1;
  const m = mp < 10 ? mp + 3 : mp - 9;
  return { y: yoe + era * 400 + (m <= 2 ? 1 : 0), m, d };
}

/** 0 = Monday … 6 = Sunday (1970-01-01 was a Thursday). */
function weekdayOf(ordinal: number): number {
  return (((ordinal + 3) % 7) + 7) % 7;
}

function daysInMonth(y: number, m: number): number {
  if (m === 2) return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0 ? 29 : 28;
  return MONTH_MAX_DAYS[m - 1];
}

/** The filters of a rule with the DTSTART defaults applied, in integer form. */
type Filters = {
  months: Set<number> | null;
  weekdays: Set<number> | null;
  /** The n-th weekday entries (n never 0). */
  nth: { weekday: number; n: number }[] | null;
  monthdays: Set<number> | null;
  negMonthdays: Set<number> | null;
};

function filtersOf(p: ParsedRrule, start: { y: number; m: number; d: number }): Filters {
  let byday = p.byday;
  let bymonthday = p.bymonthday;
  let bymonth = p.bymonth;
  if (!byday && !bymonthday) {
    if (p.freq === "YEARLY") {
      bymonth = bymonth ?? [start.m];
      bymonthday = [start.d];
    } else if (p.freq === "MONTHLY") {
      bymonthday = [start.d];
    } else if (p.freq === "WEEKLY") {
      byday = [{ weekday: weekdayOf(ordinalOf(start.y, start.m, start.d)), n: null }];
    }
  }
  const plain = byday?.filter((b) => b.n === null) ?? [];
  const nth = byday?.filter((b) => b.n !== null) as { weekday: number; n: number }[] | undefined;
  return {
    months: bymonth ? new Set(bymonth) : null,
    weekdays: plain.length > 0 ? new Set(plain.map((b) => b.weekday)) : null,
    nth: nth && nth.length > 0 ? nth : null,
    monthdays: bymonthday ? new Set(bymonthday.filter((d) => d > 0)) : null,
    negMonthdays: bymonthday ? new Set(bymonthday.filter((d) => d < 0)) : null,
  };
}

/** The ordinals of the n-th weekdays inside [first, last], as rrule's nwdaymask. */
function nthWeekdays(
  nth: { weekday: number; n: number }[],
  first: number,
  last: number,
  into: Set<number>,
): void {
  for (const { weekday, n } of nth) {
    let i: number;
    if (n > 0) {
      i = first + ((weekday - weekdayOf(first) + 7) % 7) + (n - 1) * 7;
    } else {
      i = last - ((weekdayOf(last) - weekday + 7) % 7) + (n + 1) * 7;
    }
    if (i >= first && i <= last) into.add(i);
  }
}

type Period = { from: number; to: number };

/** The k-th period of the series whose first day is `s` (an ordinal), both ends inclusive. */
function periodOf(p: ParsedRrule, s: number, start: { y: number; m: number }, k: number): Period {
  switch (p.freq) {
    case "DAILY": {
      const day = s + k * p.interval;
      return { from: day, to: day };
    }
    case "WEEKLY": {
      // The first period runs from DTSTART to the end of its week (WKST starts a week); the
      // later ones are whole weeks, every INTERVAL-th from the start of DTSTART's week.
      const weekStart = s - ((weekdayOf(s) - p.wkst + 7) % 7);
      if (k === 0) return { from: s, to: weekStart + 6 };
      const from = weekStart + 7 * k * p.interval;
      return { from, to: from + 6 };
    }
    case "MONTHLY": {
      const idx = start.y * 12 + (start.m - 1) + k * p.interval;
      const y = Math.floor(idx / 12);
      const m = idx - y * 12 + 1;
      const from = ordinalOf(y, m, 1);
      return { from, to: from + daysInMonth(y, m) - 1 };
    }
    case "YEARLY": {
      const y = start.y + k * p.interval;
      return { from: ordinalOf(y, 1, 1), to: ordinalOf(y, 12, 31) };
    }
  }
}

/** The first period index whose last day can reach `after` (0 when DTSTART is after it). */
function firstPeriodReaching(
  p: ParsedRrule,
  s: number,
  start: { y: number; m: number },
  after: number,
): number {
  let k: number;
  switch (p.freq) {
    case "DAILY":
      k = Math.ceil((after - s) / p.interval);
      break;
    case "WEEKLY": {
      const weekStart = s - ((weekdayOf(s) - p.wkst + 7) % 7);
      k = Math.ceil((after - (weekStart + 6)) / (7 * p.interval));
      break;
    }
    case "MONTHLY": {
      const a = civilOf(after);
      k = Math.ceil(((a.y * 12 + a.m - 1) - (start.y * 12 + start.m - 1)) / p.interval);
      break;
    }
    case "YEARLY":
      k = Math.ceil((civilOf(after).y - start.y) / p.interval);
      break;
  }
  return Math.max(0, k);
}

/** The days of one period that pass the filters and BYSETPOS, ascending. */
function selectDays(p: ParsedRrule, f: Filters, period: Period): number[] {
  // The n-th weekday ranges: the month (MONTHLY), each listed month or the year (YEARLY).
  let nth: Set<number> | null = null;
  if (f.nth) {
    nth = new Set();
    if (p.freq === "YEARLY" && f.months) {
      const y = civilOf(period.from).y;
      for (const m of f.months) {
        const first = ordinalOf(y, m, 1);
        nthWeekdays(f.nth, first, first + daysInMonth(y, m) - 1, nth);
      }
    } else {
      nthWeekdays(f.nth, period.from, period.to, nth);
    }
  }
  const days: number[] = [];
  let c = civilOf(period.from);
  let dim = daysInMonth(c.y, c.m);
  for (let day = period.from; day <= period.to; day++) {
    if (c.d > dim) {
      c = civilOf(day);
      dim = daysInMonth(c.y, c.m);
    }
    const ok = (!f.months || f.months.has(c.m)) &&
      (!f.weekdays || f.weekdays.has(weekdayOf(day))) &&
      (!nth || nth.has(day)) &&
      (!f.monthdays || f.monthdays.has(c.d) || f.negMonthdays!.has(c.d - dim - 1));
    if (ok) days.push(day);
    c.d++;
  }
  if (!p.bysetpos || days.length === 0) return days;
  const picked = new Set<number>();
  for (const pos of p.bysetpos) {
    // A negative position past the start of the list is the first day, as rrule.js reads it
    // (its `slice(pos)[0]`); python-dateutil would skip it. The reference's reading is kept,
    // since it is what the apps have shown so far.
    const i = pos > 0 ? pos - 1 : Math.max(0, days.length + pos);
    if (i < days.length) picked.add(days[i]);
  }
  return [...picked].sort((a, b) => a - b);
}

/** A local date-time as the walk compares it: the day's ordinal and the time within it. */
type Mark = { day: number; time: Temporal.PlainTime };

function markOf(dt: Temporal.PlainDateTime): Mark {
  return { day: ordinalOf(dt.year, dt.month, dt.day), time: dt.toPlainTime() };
}

/**
 * A walk budget shared by every event of one expansion (an imported feed): the days the
 * walks may still examine, and the number of events whose series were skipped or cut short
 * once it had run out. Days rather than periods, because a yearly period is 366 of them.
 */
export type WalkBudget = { days: number; events: number };

/**
 * The ordinals of the series' days inside [after, before] (ordinals, inclusive). `until` is
 * the rule's UNTIL as a local date-time, already converted by the caller. COUNT rules walk
 * from DTSTART because the count has to be taken; all others start at the first period that
 * can reach `after`. Never more than MAX_WALK_PERIODS periods, never a DTSTART before
 * RRULE_MIN_YEAR, and never past the budget when one is given.
 */
function walkOrdinals(
  p: ParsedRrule,
  dtstart: Temporal.PlainDateTime,
  until: Temporal.PlainDateTime | null,
  after: number,
  before: number,
  budget?: WalkBudget,
): number[] {
  const out: number[] = [];
  if (dtstart.year < RRULE_MIN_YEAR || before < after) return out;
  const startMark = markOf(dtstart);
  const untilMark = until ? markOf(until) : null;
  // Every candidate carries DTSTART's time, so UNTIL cuts at a day, or within the UNTIL day
  // when the series' time is later than UNTIL's.
  const lastDay = untilMark === null
    ? Infinity
    : untilMark.day - (Temporal.PlainTime.compare(startMark.time, untilMark.time) > 0 ? 1 : 0);
  const start = civilOf(startMark.day);
  const f = filtersOf(p, start);
  let remaining = p.count;
  let k = p.count === null ? firstPeriodReaching(p, startMark.day, start, after) : 0;
  for (let steps = 0; steps < MAX_WALK_PERIODS; steps++, k++) {
    const period = periodOf(p, startMark.day, start, k);
    if (period.from > before) break;
    if (budget) {
      if (budget.days <= 0) break;
      budget.days -= period.to - period.from + 1;
    }
    for (const day of selectDays(p, f, period)) {
      if (day < startMark.day) continue;
      if (day > lastDay) return out;
      if (day >= after && day <= before) out.push(day);
      if (remaining !== null && --remaining === 0) return out;
    }
  }
  return out;
}

/**
 * The series' dates on the local days `after`..`before` ('YYYY-MM-DD', inclusive), each at
 * DTSTART's time, ascending. The public face of the walk, for the tests and the callers
 * that need dates rather than occurrences.
 */
export function walkRule(
  p: ParsedRrule,
  dtstart: Temporal.PlainDateTime,
  until: Temporal.PlainDateTime | null,
  after: string,
  before: string,
): Temporal.PlainDateTime[] {
  const a = Temporal.PlainDate.from(after);
  const b = Temporal.PlainDate.from(before);
  const time = dtstart.toPlainTime();
  return walkOrdinals(p, dtstart, until, ordinalOf(a.year, a.month, a.day), ordinalOf(b.year, b.month, b.day))
    .map((day) => {
      const c = civilOf(day);
      return Temporal.PlainDate.from({ year: c.y, month: c.m, day: c.d }).toPlainDateTime(time);
    });
}

/** The rule's UNTIL as a local date-time of the series' zone (null without UNTIL). */
export function untilLocal(p: ParsedRrule, tz: string): Temporal.PlainDateTime | null {
  if (p.until?.kind === "date") {
    return Temporal.PlainDate.from(p.until.date).toPlainDateTime({ hour: 23, minute: 59, second: 59 });
  }
  if (p.until?.kind === "utc") return toLocal(p.until.ms, tz);
  return null;
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
  budget?: WalkBudget,
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
        budget,
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
  budget?: WalkBudget,
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

  // A rule the parser refuses (outside the subset, or one that can never match) is not
  // walked: the event keeps its first date, as an imported one does. A rule the walk budget
  // has no room for is not walked either, and the event is counted on the budget.
  const parsed = ev.rrule !== null ? parseRrule(ev.rrule) : null;
  if (parsed) {
    const until = untilLocal(parsed, tz);
    const time = dtLocal.toPlainTime();

    // Generate a little beyond the window so occurrences that started before it
    // but are still running inside it are found; the overlap check trims the rest.
    const padDays =
      (ev.is_all_day ? spanDays : Math.ceil(durationMs / DAY_MS)) + 2;
    const winFrom = toLocal(windowStart, tz).toPlainDate().toString();
    const winTo = toLocal(windowEnd, tz).toPlainDate().toString();
    const ranges: [number, number][] = [
      [ordinalOfDate(addDays(winFrom, -padDays)), ordinalOfDate(addDays(winTo, 2))],
    ];

    // An override can move an occurrence from outside the window into it, so also
    // generate the neighbourhood of each overridden original.
    for (const o of ovs.values()) {
      const original = ordinalOfDate(
        toLocal(Date.parse(o.recurrence_id), tz).toPlainDate().toString(),
      );
      ranges.push([original - 1, original + 1]);
    }

    // Each range is a walk of its own, each under the cap, so an override far from the
    // window cannot use up the window's walk. A COUNT rule has to be walked from DTSTART
    // whatever the range, so it takes one walk over the whole span and keeps the days
    // inside one of the ranges.
    const walks: [number, number][] = parsed.count === null ? ranges : [[
      Math.min(...ranges.map((r) => r[0])),
      Math.max(...ranges.map((r) => r[1])),
    ]];
    for (const [after, before] of walks) {
      if (budget && budget.days <= 0) break;
      for (const day of walkOrdinals(parsed, dtLocal, until, after, before, budget)) {
        if (!ranges.some(([a, b]) => day >= a && day <= b)) continue;
        const c = civilOf(day);
        add(Temporal.PlainDate.from({ year: c.y, month: c.m, day: c.d }).toPlainDateTime(time));
      }
    }
    if (budget && budget.days <= 0) budget.events++;
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
      icon_key: ev.icon_key ?? null,
      countdown: ev.countdown ?? false,
      tradition: ev.tradition ?? false,
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
export function importedOccurrence(
  row: ExternalOccurrenceRow,
  tz: string,
): Occurrence {
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
    localEndDate = toLocal(endMs > startMs ? endMs - 1 : startMs, tz)
      .toPlainDate().toString();
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
