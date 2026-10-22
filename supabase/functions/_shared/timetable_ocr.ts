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

/** The weekday a header cell names ("Mo", "Montag", "Mo. 12.10.", "Thu"), else null. */
export function weekdayOf(text: string): number | null {
  const first = fold(text).split(/[\s.,:/]+/).find((t) => t.length > 0);
  if (!first) return null;
  return WEEKDAYS[first] ?? null;
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

/** The header: the horizontal band with the most distinct weekdays (at least three). */
function findColumns(
  lines: Line[],
  h: number,
): { columns: Column[]; headerY: number } | null {
  const named = lines.map((l) => ({ l, day: weekdayOf(l.text) })).filter((x) =>
    x.day !== null
  );
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
  for (const m of [...best.members].sort((a, b) => a.l.cx - b.l.cx)) {
    if (seen.has(m.day!)) continue;
    seen.add(m.day!);
    m.l.used = true;
    columns.push({ day: m.day!, cx: m.l.cx });
  }
  // A header is in weekday order left to right; a stray weekday elsewhere is noise.
  columns.sort((a, b) => a.cx - b.cx);
  for (let i = 1; i < columns.length; i++) {
    if (columns[i].day <= columns[i - 1].day) return null;
  }
  return { columns, headerY: best.centre };
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
  const leftEdge = columns[0].cx - spacing / 2;
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
    if (clocks.length >= 2) {
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
  const tokens = text.replace(/[|_]+/g, " ").split(/\s+/).filter((t) =>
    t.length > 0
  );
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
