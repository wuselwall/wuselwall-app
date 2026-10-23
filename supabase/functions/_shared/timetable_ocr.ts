// From OCR boxes to a timetable payload (specs/24 "Scanning"). Pure: the `timetable-scan`
// function hands over the lines an OCR service found on the photo (text and a box each),
// this finds the grid and names what sits in which cell. No model, no guessing beyond
// geometry: the weekday header gives the columns, the period labels on the left (or the
// rows the text falls into) give the rows, and every box lands in the nearest cell or is
// counted as unplaced, so the parent sees on the preview what was not read.
//
// The payload is the one the app's paste import reads (timetable_import.dart) and the
// server's proposal check accepts (app.proposal_check): names, never ids.

/** One line of text an OCR service found: its text and its box, 8 numbers (x1 y1 … x4 y4),
 *  normalised to 0..1 or in pixels; either works, the parser only compares. */
export type OcrLine = { text: string; box: number[]; score?: number };

export type ScanLesson = {
  day: number;
  period: number;
  subject: string;
  teacher?: string;
  room?: string;
};

export type ScanPeriod = { index: number; starts: string; ends: string };

export type ScanPayload = {
  format: "wuselwall-timetable/1";
  lessons: ScanLesson[];
  periods?: ScanPeriod[];
};

export type ScanResult = {
  payload: ScanPayload;
  /** Text pieces that landed in a cell. */
  placed: number;
  /** Text pieces that fit no column or row: the parent should look at the sheet. */
  unplaced: number;
  columns: number;
  rows: number;
};

type Line = {
  text: string;
  cx: number;
  cy: number;
  w: number;
  h: number;
  used: boolean;
};

// ── words ─────────────────────────────────────────────────────────────────────

const WEEKDAYS: Record<string, number> = {
  mo: 1,
  mon: 1,
  montag: 1,
  monday: 1,
  lu: 1,
  lun: 1,
  lundi: 1,
  lunes: 1,
  di: 2,
  die: 2,
  dienstag: 2,
  tu: 2,
  tue: 2,
  tues: 2,
  tuesday: 2,
  ma: 2,
  mar: 2,
  mardi: 2,
  martes: 2,
  mi: 3,
  mit: 3,
  mittwoch: 3,
  we: 3,
  wed: 3,
  wednesday: 3,
  me: 3,
  mer: 3,
  mercredi: 3,
  mie: 3,
  miercoles: 3,
  do: 4,
  don: 4,
  donnerstag: 4,
  th: 4,
  thu: 4,
  thur: 4,
  thurs: 4,
  thursday: 4,
  je: 4,
  jeu: 4,
  jeudi: 4,
  ju: 4,
  jue: 4,
  jueves: 4,
  fr: 5,
  fre: 5,
  freitag: 5,
  fri: 5,
  friday: 5,
  ve: 5,
  ven: 5,
  vendredi: 5,
  vi: 5,
  vie: 5,
  viernes: 5,
  sa: 6,
  sam: 6,
  samstag: 6,
  sat: 6,
  saturday: 6,
  samedi: 6,
  sab: 6,
  sabado: 6,
  so: 7,
  son: 7,
  sonntag: 7,
  su: 7,
  sun: 7,
  sunday: 7,
  dim: 7,
  dimanche: 7,
  dom: 7,
  domingo: 7,
};

/** Lowercase without accents. */
export function fold(text: string): string {
  return text.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/ß/g, "ss")
    .toLowerCase().trim();
}

/** The full names, for truncated ("Dinsd"), letter-spaced ("M ittw och") and misspelt
 *  ("Dinstag") headers: a real photograph rarely yields the exact word. */
const FULL_NAMES: [string, number][] = [
  ["montag", 1],
  ["dienstag", 2],
  ["mittwoch", 3],
  ["donnerstag", 4],
  ["freitag", 5],
  ["samstag", 6],
  ["sonntag", 7],
  ["monday", 1],
  ["tuesday", 2],
  ["wednesday", 3],
  ["thursday", 4],
  ["friday", 5],
  ["saturday", 6],
  ["sunday", 7],
  ["lundi", 1],
  ["mardi", 2],
  ["mercredi", 3],
  ["jeudi", 4],
  ["vendredi", 5],
  ["samedi", 6],
  ["dimanche", 7],
  ["lunes", 1],
  ["martes", 2],
  ["miercoles", 3],
  ["jueves", 4],
  ["viernes", 5],
  ["sabado", 6],
  ["domingo", 7],
  ["maandag", 1],
  ["dinsdag", 2],
  ["woensdag", 3],
  ["donderdag", 4],
  ["vrijdag", 5],
  ["zaterdag", 6],
  ["zondag", 7],
];

/** True when `a` and `b` differ by at most one edit (insert, delete or replace). */
function withinOneEdit(a: string, b: string): boolean {
  if (Math.abs(a.length - b.length) > 1) return false;
  let i = 0, j = 0, edits = 0;
  while (i < a.length && j < b.length) {
    if (a[i] === b[j]) {
      i++;
      j++;
      continue;
    }
    if (++edits > 1) return false;
    if (a.length > b.length) i++;
    else if (a.length < b.length) j++;
    else {
      i++;
      j++;
    }
  }
  return edits + (a.length - i) + (b.length - j) <= 1;
}

/** The weekday one folded token names: exact, else a prefix of a full name (three letters
 *  or more), else one edit away from a full name (five letters or more). Null when none or
 *  when the candidates disagree. */
function dayOfToken(token: string): number | null {
  if (token.length === 0) return null;
  const exact = WEEKDAYS[token];
  if (exact !== undefined) return exact;
  const days = new Set<number>();
  for (const [name, day] of FULL_NAMES) {
    if (token.length >= 3 && name.startsWith(token)) days.add(day);
    else if (token.length >= 5 && withinOneEdit(token, name)) days.add(day);
  }
  return days.size === 1 ? [...days][0] : null;
}

const SEPARATORS = /[\s.,:/()\[\]]+/;

/** The weekday a header cell names ("Mo", "Montag", "Mo. 12.10.", "Thu", "M ittw och"), else null. */
export function weekdayOf(text: string): number | null {
  const tokens = fold(text).split(SEPARATORS).filter((t) => t.length > 0);
  if (tokens.length === 0) return null;
  if (WEEKDAYS[tokens[0]] !== undefined) return WEEKDAYS[tokens[0]];
  // Letter-spaced print ("Mon tag", "D ien s tag"): the text without its spaces.
  if (tokens.length >= 2) {
    const compact = dayOfToken(tokens.join(""));
    if (compact !== null) return compact;
  }
  return dayOfToken(tokens[0]);
}

/** Every weekday named in one text with its character span, for a header the OCR returned
 *  as one box ("Maandag Dinsdag Woensdag Donderdag Vrijdag"). A letter-spaced single name
 *  is one entry over the whole text. */
export function weekdaysIn(
  text: string,
): { day: number; start: number; end: number }[] {
  const folded = fold(text);
  const out: { day: number; start: number; end: number }[] = [];
  for (const m of folded.matchAll(/[^\s.,:/()\[\]]+/g)) {
    const day = dayOfToken(m[0]);
    if (day !== null) {
      out.push({ day, start: m.index!, end: m.index! + m[0].length });
    }
  }
  if (out.length >= 2) {
    const days = out.map((o) => o.day);
    const ordered = days.every((d, i) => i === 0 || d > days[i - 1]);
    if (ordered) return out;
  }
  const single = weekdayOf(text);
  return single === null ? [] : [{ day: single, start: 0, end: folded.length }];
}

const CLOCK = /(\d{1,2})\s*[:.h]\s*(\d{2})/g;

/** Every clock time in the text, as "HH:MM". */
export function clocksOf(text: string): string[] {
  const out: string[] = [];
  for (const m of text.matchAll(CLOCK)) {
    const h = Number(m[1]);
    const min = Number(m[2]);
    if (h <= 23 && min <= 59) {
      out.push(`${String(h).padStart(2, "0")}:${String(min).padStart(2, "0")}`);
    }
  }
  return out;
}

/** The period index a row label names ("1", "1.", "1. Std", "3. Stunde"), else null. */
export function periodOf(text: string): number | null {
  // "08:00" and "8.50" are clocks, not periods: a dot or colon followed by digits is skipped.
  const m =
    /^\s*(\d{1,2})\s*(\.(?!\s*\d)|\)|:(?!\s*\d)|std|stunde|h\b|period|lesson|$)/i
      .exec(text) ??
      // "Stunde 3", "Std. 2", "Period 4", "Uur 1", "Hora 2", "Cours 3".
      /^\s*(?:stunde|std\.?|lektion|period|lesson|les|uur|hora|cours|h)\s*(\d{1,2})\s*$/i
        .exec(text);
  if (!m) return null;
  const n = Number(m[1]);
  return n >= 1 && n <= 15 ? n : null;
}

// ── geometry ──────────────────────────────────────────────────────────────────

function lineOf(l: OcrLine): Line | null {
  const text = l.text.trim();
  if (text.length === 0 || l.box.length < 8) return null;
  const xs = [l.box[0], l.box[2], l.box[4], l.box[6]];
  const ys = [l.box[1], l.box[3], l.box[5], l.box[7]];
  const x0 = Math.min(...xs),
    x1 = Math.max(...xs),
    y0 = Math.min(...ys),
    y1 = Math.max(...ys);
  return {
    text,
    cx: (x0 + x1) / 2,
    cy: (y0 + y1) / 2,
    w: x1 - x0,
    h: y1 - y0,
    used: false,
  };
}

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 === 1 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

/** Groups values into clusters whose neighbours lie within `gap`; sorted, as [centre, members]. */
function cluster<T>(
  items: T[],
  value: (t: T) => number,
  gap: number,
): { centre: number; members: T[] }[] {
  const sorted = [...items].sort((a, b) => value(a) - value(b));
  const out: { centre: number; members: T[] }[] = [];
  for (const item of sorted) {
    const last = out[out.length - 1];
    if (
      last && value(item) - value(last.members[last.members.length - 1]) <= gap
    ) {
      last.members.push(item);
      last.centre = last.members.reduce((s, m) => s + value(m), 0) /
        last.members.length;
    } else {
      out.push({ centre: value(item), members: [item] });
    }
  }
  return out;
}

type Column = { day: number; cx: number };
type Row = { index: number; cy: number };

/** The header: the horizontal band with the most distinct weekdays (at least three). A box
 *  that holds several weekday names is split along its width. Every box in the band is then
 *  out of the cells, so "(Langtag)" next to "Montag" does not become a first lesson. */
function findColumns(
  lines: Line[],
  h: number,
): { columns: Column[]; headerY: number } | null {
  const named: { l: Line; day: number; cx: number }[] = [];
  for (const l of lines) {
    const found = weekdaysIn(l.text);
    const len = Math.max(1, fold(l.text).length);
    for (const f of found) {
      const mid = found.length === 1 ? 0.5 : (f.start + f.end) / 2 / len;
      named.push({ l, day: f.day, cx: l.cx - l.w / 2 + l.w * mid });
    }
  }
  const bands = cluster(named, (x) => x.l.cy, h * 1.2);
  let best: typeof bands[number] | null = null;
  let bestDays = 0;
  for (const band of bands) {
    const days = new Set(band.members.map((m) => m.day));
    if (
      days.size > bestDays ||
      (days.size === bestDays && best && band.centre < best.centre)
    ) {
      best = band;
      bestDays = days.size;
    }
  }
  if (!best || bestDays < 3) return null;
  const columns: Column[] = [];
  const seen = new Set<number>();
  for (const m of [...best.members].sort((a, b) => a.cx - b.cx)) {
    if (seen.has(m.day)) continue;
    seen.add(m.day);
    m.l.used = true;
    columns.push({ day: m.day, cx: m.cx });
  }
  // A header is in weekday order left to right; a stray weekday elsewhere is noise.
  columns.sort((a, b) => a.cx - b.cx);
  for (let i = 1; i < columns.length; i++) {
    if (columns[i].day <= columns[i - 1].day) return null;
  }
  for (const l of lines) {
    if (Math.abs(l.cy - best.centre) <= h * 0.9) l.used = true;
  }
  return { columns: fillGaps(columns), headerY: best.centre };
}

/**
 * Weekdays the OCR missed between recognised ones ("Mo", "Do", "Sa" read, "Di", "Mi", "Fr"
 * garbled): when the distance per day step is even across the header, the missing days
 * get their columns at the interpolated positions. Nothing is added at the edges.
 */
function fillGaps(columns: Column[]): Column[] {
  if (columns.length < 3) return columns;
  const steps = columns.slice(1).map((c, i) =>
    (c.cx - columns[i].cx) / (c.day - columns[i].day)
  );
  const step = median(steps);
  if (!steps.every((s) => Math.abs(s - step) <= step * 0.25)) return columns;
  const out: Column[] = [];
  for (let i = 0; i < columns.length; i++) {
    out.push(columns[i]);
    const next = columns[i + 1];
    if (!next) break;
    for (let d = columns[i].day + 1; d < next.day; d++) {
      out.push({ day: d, cx: columns[i].cx + step * (d - columns[i].day) });
    }
  }
  return out;
}

/**
 * The rows: labels left of the first column ("1.", "08:00–08:45", both), else the bands the
 * cell texts form. Bell times on the labels become the payload's periods.
 */
function findRows(
  lines: Line[],
  columns: Column[],
  headerY: number,
  spacing: number,
  h: number,
): { rows: Row[]; periods: ScanPeriod[] } {
  // Labels may sit close to the first column on a narrow table: a third of a spacing.
  const leftEdge = columns[0].cx - spacing * 0.35;
  const labels = lines.filter((l) =>
    !l.used && l.cy > headerY + h / 2 && l.cx < leftEdge
  );
  const bands = cluster(labels, (l) => l.cy, h * 0.9);
  const rows: Row[] = [];
  const periods: ScanPeriod[] = [];
  let next = 1;
  for (const band of bands) {
    const texts = band.members.map((m) => m.text);
    const index = texts.map(periodOf).find((p) => p !== null) ?? null;
    const clocks = texts.flatMap(clocksOf);
    if (index === null && clocks.length === 0) continue;
    const idx = index ?? next;
    next = idx + 1;
    for (const m of band.members) m.used = true;
    rows.push({ index: idx, cy: band.centre });
    if (clocks.length >= 2 && !periods.some((p) => p.index === idx)) {
      periods.push({ index: idx, starts: clocks[0], ends: clocks[1] });
    }
  }
  if (rows.length > 0) return { rows, periods };

  // No labels: the cell texts themselves form the rows.
  const body = lines.filter((l) =>
    !l.used && l.cy > headerY + h / 2 && l.cx >= leftEdge
  );
  const rowBands = cluster(body, (l) => l.cy, h * 0.8);
  return {
    rows: rowBands.map((b, i) => ({ index: i + 1, cy: b.centre })),
    periods: [],
  };
}

// ── cells ─────────────────────────────────────────────────────────────────────

/** "Ma R12" → subject Ma, room R12; "Mathe Fr. Kurz" → subject Mathe, teacher Fr. Kurz. */
export function lessonOf(
  day: number,
  period: number,
  text: string,
): ScanLesson | null {
  // A name in parentheses is the teacher ("M rot (Hen)"), or the room when it has digits.
  const bracketed: string[] = [];
  const plain = text.replace(/\(([^()]{1,30})\)/g, (_, inner: string) => {
    bracketed.push(inner.trim());
    return " ";
  });
  const tokens = [
    ...plain.replace(/[|_]+/g, " ").split(/\s+/).filter((t) => t.length > 0),
    ...bracketed,
  ];
  if (tokens.length === 0) return null;
  const subject = tokens[0].replace(/[.,:;]+$/, "");
  if (subject.length === 0 || /^[-–—]+$/.test(subject)) return null;
  const rooms: string[] = [];
  const names: string[] = [];
  for (const t of tokens.slice(1)) {
    if (/\d/.test(t)) rooms.push(t);
    else names.push(t);
  }
  const out: ScanLesson = { day, period, subject: subject.slice(0, 60) };
  if (rooms.length > 0) out.room = rooms.join(" ").slice(0, 40);
  if (names.length > 0) out.teacher = names.join(" ").slice(0, 60);
  return out;
}

/**
 * The grid in the lines, or null when no weekday header was found (the photo shows no
 * timetable the parser can read).
 */
export function parseTimetableScan(input: OcrLine[]): ScanResult | null {
  const lines = input.map(lineOf).filter((l): l is Line => l !== null);
  if (lines.length < 4) return null;
  const h = median(lines.map((l) => l.h));
  const header = findColumns(lines, h);
  if (!header) return null;
  const { columns, headerY } = header;
  const gaps = columns.slice(1).map((c, i) => c.cx - columns[i].cx);
  const spacing = median(gaps);
  const { rows, periods } = findRows(lines, columns, headerY, spacing, h);
  if (rows.length === 0) return null;
  const rowGaps = rows.slice(1).map((r, i) => r.cy - rows[i].cy);
  const rowSpacing = rowGaps.length > 0 ? median(rowGaps) : h * 2;

  const cells = new Map<string, Line[]>();
  let placed = 0;
  let unplaced = 0;
  for (const l of lines) {
    if (l.used || l.cy <= headerY + h / 2) continue;
    let column: Column | null = null;
    for (const c of columns) {
      if (
        Math.abs(c.cx - l.cx) <= spacing * 0.6 &&
        (!column || Math.abs(c.cx - l.cx) < Math.abs(column.cx - l.cx))
      ) {
        column = c;
      }
    }
    let row: Row | null = null;
    for (const r of rows) {
      if (
        Math.abs(r.cy - l.cy) <= rowSpacing * 0.6 &&
        (!row || Math.abs(r.cy - l.cy) < Math.abs(row.cy - l.cy))
      ) {
        row = r;
      }
    }
    if (!column || !row) {
      unplaced++;
      continue;
    }
    placed++;
    const key = `${column.day}:${row.index}`;
    const list = cells.get(key) ?? [];
    list.push(l);
    cells.set(key, list);
  }

  const lessons: ScanLesson[] = [];
  for (const [key, members] of cells) {
    const [day, period] = key.split(":").map(Number);
    members.sort((
      a,
      b,
    ) => (Math.abs(a.cy - b.cy) > h / 2 ? a.cy - b.cy : a.cx - b.cx));
    const lesson = lessonOf(day, period, members.map((m) => m.text).join(" "));
    if (lesson) lessons.push(lesson);
  }
  lessons.sort((a, b) => a.day - b.day || a.period - b.period);
  if (lessons.length === 0) return null;

  const payload: ScanPayload = { format: "wuselwall-timetable/1", lessons };
  if (periods.length > 0) {
    payload.periods = periods.sort((a, b) => a.index - b.index);
  }
  return {
    payload,
    placed,
    unplaced,
    columns: columns.length,
    rows: rows.length,
  };
}
