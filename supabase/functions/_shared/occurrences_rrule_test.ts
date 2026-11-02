// The RRULE walk of occurrences.ts against rrule.js, the engine it replaced (security review
// 2026-11-01, F6). rrule.js is the reference for the semantics of the supported subset; the
// walk must give the same dates for every rule, DTSTART and window of this corpus. The corpus
// is a hand-written list of the rules families write, plus rules drawn from a seeded generator
// so that unusual combinations (negative month days, BYSETPOS, WKST, long intervals) are
// covered too. Rules the parser refuses are not compared: rrule.js would walk some of them to
// the year 9999, which is the reason the walk exists.
import { assertEquals } from "jsr:@std/assert@1.0.13";
import { Temporal } from "npm:temporal-polyfill@0.3.0";
import rrulePkg from "npm:rrule@2.8.1";
import { parseRrule, untilLocal, walkRule } from "./occurrences.ts";

// deno-lint-ignore no-explicit-any
const { RRule, Weekday } = rrulePkg as any;

const DAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"];

/** rrule.js in floating mode: local wall-clock time encoded as UTC. */
function floatOf(p: Temporal.PlainDateTime): Date {
  return new Date(Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second));
}

function reference(rrule: string, dtstart: Temporal.PlainDateTime, after: string, before: string, tz = "UTC"): string[] {
  const p = parseRrule(rrule)!;
  const freq = { YEARLY: RRule.YEARLY, MONTHLY: RRule.MONTHLY, WEEKLY: RRule.WEEKLY, DAILY: RRule.DAILY }[p.freq];
  const opts: Record<string, unknown> = { freq, interval: p.interval, wkst: p.wkst, dtstart: floatOf(dtstart) };
  if (p.count !== null) opts.count = p.count;
  const until = untilLocal(p, tz);
  if (until) opts.until = floatOf(until);
  if (p.byday) opts.byweekday = p.byday.map((b) => b.n === null ? new Weekday(b.weekday) : new Weekday(b.weekday, b.n));
  if (p.bymonthday) opts.bymonthday = p.bymonthday;
  if (p.bymonth) opts.bymonth = p.bymonth;
  if (p.bysetpos) opts.bysetpos = p.bysetpos;
  const a = Temporal.PlainDate.from(after);
  const b = Temporal.PlainDate.from(before);
  const dates = (new RRule(opts).between(
    new Date(Date.UTC(a.year, a.month - 1, a.day)),
    new Date(Date.UTC(b.year, b.month - 1, b.day, 23, 59, 59)),
    true,
  ) as Date[]).map((d) => d.toISOString().slice(0, 19));
  // rrule.js repeats a day two BYSETPOS positions both pick (it compares Date objects by
  // reference when it de-duplicates); the walk emits a day once.
  return [...new Set(dates)];
}

function walk(rrule: string, dtstart: Temporal.PlainDateTime, after: string, before: string, tz = "UTC"): string[] {
  const p = parseRrule(rrule)!;
  return walkRule(p, dtstart, untilLocal(p, tz), after, before).map((d) => d.toString().slice(0, 19));
}

const CORPUS = [
  "FREQ=DAILY",
  "FREQ=DAILY;INTERVAL=3",
  "FREQ=DAILY;COUNT=10",
  "FREQ=DAILY;UNTIL=20260315",
  "FREQ=DAILY;UNTIL=20260315T080000Z",
  "FREQ=DAILY;BYDAY=MO,WE,FR",
  "FREQ=DAILY;BYMONTH=2;BYMONTHDAY=29",
  "FREQ=DAILY;BYMONTHDAY=-1",
  "FREQ=WEEKLY",
  "FREQ=WEEKLY;BYDAY=MO,WE",
  "FREQ=WEEKLY;INTERVAL=2;BYDAY=TU",
  "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,SU;WKST=SU",
  "FREQ=WEEKLY;INTERVAL=3;BYDAY=SA,SU;WKST=MO",
  "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1",
  "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=1,3",
  "FREQ=WEEKLY;COUNT=5;BYDAY=FR",
  "FREQ=WEEKLY;BYDAY=MO;BYMONTH=1,7",
  "FREQ=MONTHLY",
  "FREQ=MONTHLY;BYMONTHDAY=15",
  "FREQ=MONTHLY;BYMONTHDAY=31",
  "FREQ=MONTHLY;BYMONTHDAY=-1",
  "FREQ=MONTHLY;BYMONTHDAY=1,15,-1",
  "FREQ=MONTHLY;BYDAY=-1FR",
  "FREQ=MONTHLY;BYDAY=1MO",
  "FREQ=MONTHLY;BYDAY=2TU,4TU",
  "FREQ=MONTHLY;BYDAY=5SA",
  "FREQ=MONTHLY;BYDAY=MO;BYSETPOS=-1",
  "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=1",
  "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-2",
  "FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=10",
  "FREQ=MONTHLY;INTERVAL=3",
  "FREQ=MONTHLY;BYMONTH=3,6,9,12;BYMONTHDAY=1",
  "FREQ=MONTHLY;COUNT=4;BYDAY=-1SU",
  "FREQ=YEARLY",
  "FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=24",
  "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29",
  "FREQ=YEARLY;BYDAY=1MO;BYMONTH=9",
  "FREQ=YEARLY;BYDAY=-1SU;BYMONTH=3,10",
  "FREQ=YEARLY;BYDAY=20MO",
  "FREQ=YEARLY;BYDAY=MO;BYMONTH=1;BYSETPOS=-1",
  "FREQ=YEARLY;BYMONTHDAY=13;BYDAY=FR",
  "FREQ=YEARLY;INTERVAL=2",
  "FREQ=YEARLY;INTERVAL=4;BYMONTH=2;BYMONTHDAY=29",
  "FREQ=YEARLY;BYMONTH=1,4,7,10;BYMONTHDAY=1;BYSETPOS=2",
  // Review 2026-11-02: intervals above twelve, read years after DTSTART; BYMONTH alone with
  // BYSETPOS (DTSTART's day in each listed month); mixed plain and n-th weekdays.
  "FREQ=DAILY;INTERVAL=45",
  "FREQ=WEEKLY;INTERVAL=26;BYDAY=TU",
  "FREQ=MONTHLY;INTERVAL=18;BYMONTHDAY=5",
  "FREQ=MONTHLY;INTERVAL=14;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1",
  "FREQ=YEARLY;INTERVAL=3",
  "FREQ=YEARLY;BYMONTH=1,7;BYSETPOS=2",
  "FREQ=YEARLY;BYMONTH=3,6,9;BYSETPOS=-1",
  "FREQ=MONTHLY;BYDAY=MO,1MO",
  "FREQ=YEARLY;BYDAY=MO,TU,-1TU",
];

const STARTS = [
  "2026-01-30T09:00:00",
  "2026-03-29T02:30:00", // in the DST gap of Central Europe, as a wall-clock time
  "2026-10-25T02:30:00", // in its fold
  "2025-12-31T23:30:00",
  "2024-02-29T07:15:00",
  "2026-03-01T00:00:00",
  "2026-10-25T02:30:00",
  "2019-06-15T18:00:00",
  "2026-02-01T12:00:00",
];

const WINDOWS: [string, string][] = [
  ["2026-01-01", "2026-03-31"],
  ["2026-03-01", "2026-03-01"],
  ["2026-10-20", "2027-01-05"],
  ["2028-02-01", "2028-03-15"],
  ["2025-01-01", "2025-01-31"],
  ["2031-01-01", "2031-12-31"],
  ["2040-06-01", "2040-06-30"],
];

Deno.test("walk: the corpus agrees with rrule.js for every DTSTART and window", () => {
  let compared = 0;
  for (const rule of CORPUS) {
    for (const start of STARTS) {
      const dtstart = Temporal.PlainDateTime.from(start);
      for (const [after, before] of WINDOWS) {
        assertEquals(walk(rule, dtstart, after, before), reference(rule, dtstart, after, before), `${rule} from ${start} in ${after}..${before}`);
        compared++;
      }
    }
  }
  assertEquals(compared, CORPUS.length * STARTS.length * WINDOWS.length);
});

Deno.test("walk: a UTC UNTIL is read in the series' own zone, as rrule.js reads it after conversion", () => {
  // 2026-03-29T00:30Z is 01:30 in Berlin before the clocks go forward and 02:30 after
  // Zurich's spring (the same instant); 2026-10-25T00:30Z is 02:30 CEST in the fold.
  const rules = [
    "FREQ=DAILY;UNTIL=20260329T003000Z",
    "FREQ=DAILY;UNTIL=20261025T003000Z",
    "FREQ=WEEKLY;BYDAY=SU;UNTIL=20261025T013000Z",
    "FREQ=DAILY;UNTIL=20260315T080000Z",
  ];
  for (const tz of ["Europe/Berlin", "America/New_York", "Asia/Kolkata"]) {
    for (const rule of rules) {
      for (const start of ["2026-03-20T01:30:00", "2026-03-29T02:30:00", "2026-10-18T02:30:00", "2026-10-25T02:30:00"]) {
        const dtstart = Temporal.PlainDateTime.from(start);
        assertEquals(walk(rule, dtstart, "2026-03-01", "2026-11-30", tz), reference(rule, dtstart, "2026-03-01", "2026-11-30", tz), `${rule} from ${start} in ${tz}`);
      }
    }
  }
});

/** A small deterministic generator (xorshift), so a failure names a reproducible rule. */
function rng(seed: number): () => number {
  let x = seed || 1;
  return () => {
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    return (x >>> 0) / 4294967296;
  };
}

function generate(next: () => number): string {
  const pick = <T>(items: T[]) => items[Math.floor(next() * items.length)];
  const some = <T>(items: T[], max: number) => {
    const n = 1 + Math.floor(next() * max);
    const out = new Set<T>();
    for (let i = 0; i < n; i++) out.add(pick(items));
    return [...out];
  };
  const freq = pick(["DAILY", "WEEKLY", "MONTHLY", "YEARLY"]);
  const parts = [`FREQ=${freq}`];
  if (next() < 0.3) parts.push(`INTERVAL=${pick([1, 2, 3, 5, 12])}`);
  const end = next();
  if (end < 0.2) parts.push(`COUNT=${pick([1, 3, 8, 30])}`);
  else if (end < 0.4) parts.push(`UNTIL=${pick(["20260215", "20261231", "20270601T100000Z"])}`);
  if (next() < 0.5) {
    const ordinal = (freq === "MONTHLY" || freq === "YEARLY") && next() < 0.4;
    const nths = freq === "MONTHLY" ? [1, 2, 3, 4, 5, -1, -2] : [1, 2, 10, 26, 53, -1, -5];
    const days = some(DAYS, 3).map((d) => ordinal ? `${pick(nths)}${d}` : d);
    parts.push(`BYDAY=${days.join(",")}`);
  }
  if (next() < 0.35) parts.push(`BYMONTHDAY=${some([1, 2, 10, 15, 28, 29, 30, 31, -1, -2, -15, -31], 3).join(",")}`);
  if (next() < 0.3) parts.push(`BYMONTH=${some([1, 2, 3, 4, 6, 7, 9, 11, 12], 3).join(",")}`);
  if (next() < 0.25) parts.push(`BYSETPOS=${some([1, 2, 3, -1, -2], 2).join(",")}`);
  if (next() < 0.2) parts.push(`WKST=${pick(DAYS)}`);
  return parts.join(";");
}

Deno.test("walk: generated rules agree with rrule.js", () => {
  const next = rng(20261101);
  let compared = 0;
  let refused = 0;
  const dtstart = Temporal.PlainDateTime.from("2026-01-14T10:30:00");
  for (let i = 0; i < 400; i++) {
    const rule = generate(next);
    if (parseRrule(rule) === null) {
      refused++;
      continue;
    }
    for (const [after, before] of [["2026-01-01", "2026-04-30"], ["2027-06-01", "2027-06-30"]]) {
      assertEquals(walk(rule, dtstart, after, before), reference(rule, dtstart, after, before), `${rule} in ${after}..${before}`);
      compared++;
    }
  }
  // The generator writes unusual rules; most are inside the subset and were compared.
  assertEquals(compared > 400, true, `${compared} comparisons, ${refused} refused`);
});
