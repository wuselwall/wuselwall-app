// From OCR boxes to a timetable payload (specs/24 "Scanning"). Pure: the `timetable-scan`
// function hands over the lines an OCR service found on the photo (text and a box each),
// this finds the grid and names what sits in which cell. No model, no guessing beyond
// geometry: the weekday header gives the columns, the period labels on the left (or the
// rows the text falls into) give the rows, and every box lands in the nearest cell or is
// counted as unplaced, so the parent sees on the preview what was not read.
//
// The payload is the one the app's paste import reads (timetable_import.dart) and the
// server's proposal check accepts (app.proposal_check): names, never ids.

import { AMBIGUOUS, BREAKS, CARE_GROUP, SUBJECTS } from "./school_subjects.ts";

/** One line of text an OCR service found: its text and its box, 8 numbers (x1 y1 … x4 y4),
 *  normalised to 0..1 or in pixels; either works, the parser only compares. */
export type OcrLine = { text: string; box: number[]; score?: number };

export type ScanLesson = {
  day: number;
  period: number;
  /** The word on the sheet ("SU"), or the family's own word it snapped to. */
  subject: string;
  /** The full name, when the family's language knows the word ("Sachunterricht"). */
  name?: string;
  teacher?: string;
  room?: string;
  /** The week the cell is marked with ("A", "Q2", "B-Woche"). */
  parity?: "a" | "b";
  /** The family's subject of the same group when the word matched none of the family's
   *  ("HSU" with the family's "SU"): the preview offers it instead of a new subject. */
  like?: string;
};

export type ScanPeriod = { index: number; starts: string; ends: string };

/** A care row (Hort, Mittagstisch, périscolaire): the cells of that word, with the row's
 *  clock times. */
export type ScanCare = {
  title: string;
  days: number[];
  starts: string;
  ends: string;
};

export type ScanPayload = {
  format: "wuselwall-timetable/1";
  lessons: ScanLesson[];
  periods?: ScanPeriod[];
  care?: ScanCare[];
};

export type ScanResult = {
  payload: ScanPayload;
  /** The sheet had its days down the left and its periods across the top. */
  transposed: boolean;
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
  /** The text's direction in radians, (-π/2, π/2]: 0 is level, a phone photo tilts it. */
  angle: number;
  /** The quad's edges: along the text and across it, whatever the tilt. */
  along: number;
  across: number;
  used: boolean;
};

// ── words ─────────────────────────────────────────────────────────────────────

/** What the family tells the scan: its language(s) and its subjects (short names and names). */
export type ScanHints = {
  languages?: string[];
  /** The family's subject words, flat (short names and names). */
  subjects?: string[];
  /** The family's subjects with their remembered aliases: the words a sheet used for them
   *  before. When sent, a cell with any of a subject's words gets the subject's short name. */
  subjectList?: { short: string; name: string; aliases?: string[] }[];
};

/** The short weekday forms per language. A family's sheet is read with its own language's
 *  forms, since short codes collide across languages (German "Ma" is Mathe, French "ma." is
 *  mardi); the full names of every language stay matchable by prefix. */
const SHORT_FORMS: Record<string, Record<string, number>> = {
  de: {
    mo: 1,
    mon: 1,
    montag: 1,
    di: 2,
    die: 2,
    dienstag: 2,
    mi: 3,
    mit: 3,
    mittwoch: 3,
    do: 4,
    don: 4,
    donnerstag: 4,
    fr: 5,
    fre: 5,
    freitag: 5,
    sa: 6,
    sam: 6,
    samstag: 6,
    so: 7,
    son: 7,
    sonntag: 7,
  },
  en: {
    mon: 1,
    monday: 1,
    tu: 2,
    tue: 2,
    tues: 2,
    tuesday: 2,
    wed: 3,
    wednesday: 3,
    th: 4,
    thu: 4,
    thur: 4,
    thurs: 4,
    thursday: 4,
    fri: 5,
    friday: 5,
    sat: 6,
    saturday: 6,
    sun: 7,
    sunday: 7,
  },
  fr: {
    lun: 1,
    lundi: 1,
    mar: 2,
    mardi: 2,
    mer: 3,
    mercredi: 3,
    jeu: 4,
    jeudi: 4,
    ven: 5,
    vendredi: 5,
    sam: 6,
    samedi: 6,
    dim: 7,
    dimanche: 7,
  },
  es: {
    lun: 1,
    lunes: 1,
    mar: 2,
    martes: 2,
    mie: 3,
    miercoles: 3,
    ju: 4,
    jue: 4,
    jueves: 4,
    vi: 5,
    vie: 5,
    viernes: 5,
    sab: 6,
    sabado: 6,
    dom: 7,
    domingo: 7,
  },
  nl: {
    maandag: 1,
    dinsdag: 2,
    woensdag: 3,
    donderdag: 4,
    vrijdag: 5,
    zaterdag: 6,
    zondag: 7,
  },
};

/** Short forms that count only when the family named the language: Spanish sheets print
 *  "Lu Ma Mi Ju Vi", but "Ma" is Mathe on every German sheet and "Mi" its Medien und
 *  Informatik, so without a language these stay subjects. */
const EXPLICIT_SHORT_FORMS: Record<string, Record<string, number>> = {
  es: { lu: 1, ma: 2, mi: 3 },
};

/** The words one scan is read with. */
type Vocab = {
  /** The short weekday forms of the family's language(s). */
  short: Record<string, number>;
  /** Every subject word, the family's and the language's: never a weekday by guess. */
  known: Set<string>;
  /** The family's own words, by key: the word the payload names the subject by (the
   *  subject's short name when the family's list was sent, else the word as spelt). */
  family: Map<string, string>;
  /** The language's subject names by the key of a code or of the name itself. */
  names: Map<string, string>;
  /** The language's subject groups by the same keys. */
  groups: Map<string, string>;
  /** The family's subjects (short names) per group, when the family's list was sent. */
  familyGroups: Map<string, string[]>;
  /** The longest subject word, in tokens, so a cell "Natur, Mensch, Gesellschaft" is one. */
  maxTokens: number;
};

/** The key a subject word is matched by: folded, punctuation gone, one space between words. */
export function subjectKey(text: string): string {
  return fold(text).replace(/[.,:;'’"!?]+/g, " ").replace(/\s+/g, " ").trim();
}

/** The vocabulary for [hints]: the short weekday forms of the named languages (every
 *  language when none is named or known), the family's subjects, and the subject words of the
 *  named languages (specs/research/school-subjects). Without a known language no code gets a
 *  name, since "Ma" is Mathematik in German and Mathématiques in French. */
export function vocabOf(hints?: ScanHints): Vocab {
  const asked = (hints?.languages ?? [])
    .map((l) => l.toLowerCase().split(/[-_]/)[0])
    .filter((l) => l in SHORT_FORMS || l in SUBJECTS);
  const languages = asked.length > 0 ? [...new Set(asked)] : [];
  const short: Record<string, number> = {};
  for (
    const language of languages.length > 0
      ? languages
      : Object.keys(SHORT_FORMS)
  ) {
    Object.assign(short, SHORT_FORMS[language] ?? {});
  }
  for (const language of languages) {
    Object.assign(short, EXPLICIT_SHORT_FORMS[language] ?? {});
  }
  const known = new Set<string>();
  const names = new Map<string, string>();
  const groups = new Map<string, string>();
  const clashing = new Set<string>();
  const groupClashing = new Set<string>();
  let maxTokens = 1;
  const wordLists = languages.length > 0 ? languages : Object.keys(SUBJECTS);
  for (const language of wordLists) {
    for (const entry of SUBJECTS[language] ?? []) {
      for (const word of [entry.name, ...entry.codes]) {
        const key = subjectKey(word);
        known.add(key);
        maxTokens = Math.max(maxTokens, key.split(" ").length);
        if (languages.length === 0) continue;
        const seen = names.get(key);
        if (seen !== undefined && seen !== entry.name) clashing.add(key);
        else names.set(key, entry.name);
        const group = groups.get(key);
        if (group !== undefined && group !== entry.group) {
          groupClashing.add(key);
        } else groups.set(key, entry.group);
      }
    }
    for (const code of AMBIGUOUS[language] ?? []) {
      known.add(subjectKey(code));
      clashing.add(subjectKey(code));
      groupClashing.add(subjectKey(code));
    }
  }
  for (const key of clashing) names.delete(key);
  for (const key of groupClashing) groups.delete(key);

  // The family's words. With the list, every word of a subject (short name, name, the
  // aliases a sheet used before) names the subject by its short name.
  const family = new Map<string, string>();
  const familyGroups = new Map<string, string[]>();
  const list = hints?.subjectList;
  if (list !== undefined && list.length > 0) {
    for (const subject of list) {
      const short = subject.short.trim();
      if (short.length === 0) continue;
      const words = [short, subject.name, ...(subject.aliases ?? [])];
      let group: string | undefined;
      for (const word of words) {
        const key = subjectKey(word);
        if (key.length === 0) continue;
        known.add(key);
        if (!family.has(key)) family.set(key, short);
        group ??= groups.get(key);
      }
      if (group !== undefined) {
        const members = familyGroups.get(group) ?? [];
        if (!members.includes(short)) members.push(short);
        familyGroups.set(group, members);
      }
    }
  } else {
    for (const word of hints?.subjects ?? []) {
      const key = subjectKey(word);
      if (key.length === 0) continue;
      known.add(key);
      if (!family.has(key)) family.set(key, word.trim());
    }
  }
  for (const key of family.keys()) {
    maxTokens = Math.max(maxTokens, key.split(" ").length);
  }
  return { short, known, family, names, groups, familyGroups, maxTokens };
}

const BREAK_KEYS = new Set(BREAKS.map(subjectKey));

const DEFAULT_VOCAB: Vocab = vocabOf();

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

/** The Levenshtein distance of two short words, capped at `max` + 1. */
function editDistance(a: string, b: string, max: number): number {
  if (Math.abs(a.length - b.length) > max) return max + 1;
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

/** The weekday one folded token names: exact, else a prefix of a full name (three letters
 *  or more), else one edit away from a full name of five letters or more, or two edits away
 *  from one of eight or more ("Pornerstag", "Pierstag" in a child's hand). Null when none or
 *  when the candidates disagree. */
function dayOfToken(
  token: string,
  vocab: Vocab = DEFAULT_VOCAB,
): number | null {
  if (token.length === 0) return null;
  const exact = vocab.short[token];
  if (exact !== undefined) return exact;
  // A subject word (the family's, or the language's): no guessing by prefix or edit
  // distance from here.
  if (vocab.known.has(token)) return null;
  const days = new Set<number>();
  for (const [name, day] of FULL_NAMES) {
    if (token.length >= 3 && name.startsWith(token)) days.add(day);
    else if (
      token.length >= 5 &&
      editDistance(token, name, 2) <=
        (token.length >= 8 && name.length >= 8 ? 2 : 1)
    ) {
      days.add(day);
    }
  }
  return days.size === 1 ? [...days][0] : null;
}

const SEPARATORS = /[\s.,:/()\[\]]+/;

/** The weekday a header cell names ("Mo", "Montag", "Mo. 12.10.", "Thu", "M ittw och"), else null. */
export function weekdayOf(
  text: string,
  vocab: Vocab = DEFAULT_VOCAB,
): number | null {
  const tokens = fold(text).split(SEPARATORS).filter((t) => t.length > 0);
  if (tokens.length === 0) return null;
  if (vocab.short[tokens[0]] !== undefined) return vocab.short[tokens[0]];
  // Letter-spaced print ("Mon tag", "D ien s tag"): the text without its spaces.
  if (tokens.length >= 2) {
    const compact = dayOfToken(tokens.join(""), vocab);
    if (compact !== null) return compact;
  }
  return dayOfToken(tokens[0], vocab);
}

/** Every weekday named in one text with its character span, for a header the OCR returned
 *  as one box ("Maandag Dinsdag Woensdag Donderdag Vrijdag"). A letter-spaced single name
 *  is one entry over the whole text. */
export function weekdaysIn(
  text: string,
  vocab: Vocab = DEFAULT_VOCAB,
): { day: number; start: number; end: number }[] {
  const folded = fold(text);
  const out: { day: number; start: number; end: number }[] = [];
  for (const m of folded.matchAll(/[^\s.,:/()\[\]]+/g)) {
    const day = dayOfToken(m[0], vocab);
    if (day !== null) {
      out.push({ day, start: m.index!, end: m.index! + m[0].length });
    }
  }
  if (out.length >= 2) {
    const days = out.map((o) => o.day);
    const ordered = days.every((d, i) => i === 0 || d > days[i - 1]);
    if (ordered) return out;
  }
  const single = weekdayOf(text, vocab);
  return single === null ? [] : [{ day: single, start: 0, end: folded.length }];
}

// "08:00", "8.50", "8h00", and the "8 00" of a PDF whose dot came as a rectangle of its own.
const CLOCK = /(\d{1,2})(?:\s*[:.h]\s*|\s)(\d{2})(?!\d)/g;

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

/** The clocks a row label shows: "08:00 - 08:45", and the bare "800" or "1040" of a sheet
 *  that drops the colon (or an OCR that lost it). Only for labels: a cell's "124" is a room. */
export function labelClocks(text: string): string[] {
  const out = clocksOf(text);
  if (out.length > 0) return out;
  for (const m of text.matchAll(/(?<!\d)(\d{3,4})(?!\d)/g)) {
    const digits = m[1];
    const h = Number(digits.slice(0, digits.length - 2));
    const min = Number(digits.slice(-2));
    // A school day: a bare "124" is a room or a fragment, not 01:24.
    if (h >= 6 && h <= 19 && min <= 59) {
      out.push(`${String(h).padStart(2, "0")}:${String(min).padStart(2, "0")}`);
    }
  }
  return out;
}

/** The period index a row label names ("1", "1.", "1. Std", "3. Stunde"), else null. */
export function periodOf(text: string): number | null {
  // The whole text, so that "1. Semester GES tc" in a remark is no label. "08:00" and
  // "8.50" are clocks, not periods: a dot or colon followed by digits is skipped.
  const m =
    /^\s*(\d{1,2})\s*(?:\.(?!\s*\d)|\))?\s*(?:std\.?|stunde|lektion|period|lesson|les|uur|hora|cours|h\b)?\s*$/i
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
  // The quad's first edge runs along the text; its length and the next edge's are the
  // text's own width and height, whatever the tilt. The bounding box only centres it.
  let angle = Math.atan2(ys[1] - ys[0], xs[1] - xs[0]);
  if (angle > Math.PI / 2) angle -= Math.PI;
  if (angle <= -Math.PI / 2) angle += Math.PI;
  const along = Math.hypot(xs[1] - xs[0], ys[1] - ys[0]);
  const across = Math.hypot(xs[2] - xs[1], ys[2] - ys[1]);
  // Sizes along the picture's axes here; the text's own sizes once the sheet is read level
  // (straighten), since the OCR does not always start a quad at the same corner.
  return {
    text,
    cx: (x0 + x1) / 2,
    cy: (y0 + y1) / 2,
    w: x1 - x0,
    h: y1 - y0,
    angle,
    along: along > 0 ? along : x1 - x0,
    across: across > 0 ? across : y1 - y0,
    used: false,
  };
}

/**
 * How much the sheet tilts: the median direction of its words (boxes clearly wider than
 * tall). A phone photo is rarely level, and a sheet photographed sideways reads at ±90°.
 */
function skewOf(lines: Line[]): number {
  const words = lines.filter((l) => l.along > l.across * 1.5);
  if (words.length < 3) return 0;
  const angles = words.map((l) => l.angle).sort((a, b) => a - b);
  return angles[Math.floor(angles.length / 2)];
}

/** The lines turned by -tilt about the origin, so that their text runs level, each with its
 *  text's own length and height (a quad the OCR started at another corner has them swapped). */
function straighten(lines: Line[], tilt: number): Line[] {
  const c = Math.cos(tilt), si = Math.sin(tilt);
  return lines.map((l) => {
    let off = l.angle - tilt;
    if (off > Math.PI / 2) off -= Math.PI;
    if (off <= -Math.PI / 2) off += Math.PI;
    const level = Math.abs(off) < Math.PI / 4;
    return {
      ...l,
      cx: l.cx * c + l.cy * si,
      cy: -l.cx * si + l.cy * c,
      w: level ? l.along : l.across,
      h: level ? l.across : l.along,
      angle: 0,
      used: false,
    };
  });
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

/** A weekday column: the header text's centre and its left edge. Cells are assigned by
 *  boundaries halfway between neighbouring left edges, so a sheet that left-aligns its
 *  text (Excel, Untis) keeps a cell's right-hand teacher code in its own column. */
type Column = { day: number; cx: number; left: number };
type Row = { index: number; cy: number };

/** The header: the horizontal band with the most distinct weekdays (at least three). A box
 *  that holds several weekday names is split along its width. Every box in the band is then
 *  out of the cells, so "(Langtag)" next to "Montag" does not become a first lesson. */
function findColumns(
  lines: Line[],
  h: number,
  vocab: Vocab,
): { columns: Column[]; headerY: number } | null {
  const named: { l: Line; day: number; cx: number; left: number }[] = [];
  for (const l of lines) {
    const found = weekdaysIn(l.text, vocab);
    const len = Math.max(1, fold(l.text).length);
    for (const f of found) {
      const mid = found.length === 1 ? 0.5 : (f.start + f.end) / 2 / len;
      const x0 = l.cx - l.w / 2;
      const start = found.length === 1 ? 0 : f.start / len;
      named.push({ l, day: f.day, cx: x0 + l.w * mid, left: x0 + l.w * start });
    }
  }
  // One line of text: a row pitch barely above the text height must not join the band.
  // One line of text first: a row pitch barely above the text height must not join the band.
  // A header the OCR read a little unevenly gets a second, looser try.
  let best: { centre: number; members: typeof named } | null = null;
  let bestDays = 0;
  for (const gap of [0.6, 1.2]) {
    for (const band of cluster(named, (x) => x.l.cy, h * gap)) {
      const days = new Set(band.members.map((m) => m.day));
      if (
        days.size > bestDays ||
        (days.size === bestDays && best && band.centre < best.centre)
      ) {
        best = band;
        bestDays = days.size;
      }
    }
    if (bestDays >= 3) break;
  }
  if (!best || bestDays < 3) return null;
  const columns: Column[] = [];
  const seen = new Set<number>();
  for (const m of [...best.members].sort((a, b) => a.cx - b.cx)) {
    if (seen.has(m.day)) continue;
    seen.add(m.day);
    m.l.used = true;
    columns.push({ day: m.day, cx: m.cx, left: m.left });
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
 * Where each column begins and ends: from just before a header's left edge to just before
 * the next header's. A sheet that left-aligns its text (Excel, Untis) starts its cell text
 * at the header's left edge and may put a teacher code at the cell's right, which a
 * boundary halfway between the headers would hand to the next column. A sheet that centres
 * its text keeps every box's middle at the cell's middle, which lies inside these bounds
 * as well, so one rule serves both.
 */
function columnBounds(
  columns: Column[],
  spacing: number,
): { from: number; to: number }[] {
  const margin = spacing * 0.05;
  return columns.map((c, i) => ({
    from: i === 0 ? c.left - spacing * 0.5 : c.left - margin,
    to: i === columns.length - 1
      ? c.left + spacing * 0.95
      : columns[i + 1].left - margin,
  }));
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
      const shift = step * (d - columns[i].day);
      out.push({
        day: d,
        cx: columns[i].cx + shift,
        left: columns[i].left + shift,
      });
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
  const rightEdge = columns[columns.length - 1].cx + spacing * 0.6;
  const labels = lines.filter((l) =>
    !l.used && l.cy > headerY + h / 2 && (l.cx < leftEdge || l.cx > rightEdge)
  );
  // Numbered labels define the rows; the clocks next to them become the bell times. Two
  // label columns (number, times) interleave, so clustering them together would chain the
  // rows into one. Without numbers, the clocks define the rows.
  const numbered = labels.filter((l) => periodOf(l.text) !== null);
  const clocked = labels.filter((l) => labelClocks(l.text).length > 0);
  const numberBands = cluster(numbered, (l) => l.cy, h * 0.6);
  const clockBands = cluster(clocked, (l) => l.cy, h * 0.9);
  // The numbers are the sheet's own when they mark at least two rows and the clocks are
  // not more than two per row (start above, end below). Otherwise whichever kind marks
  // more rows wins, so a stray "1." in a remark cannot hide a column of bell times.
  const byNumber = numberBands.length >= 2
    ? clockBands.length <= numberBands.length * 2
    : numberBands.length >= clockBands.length;
  const bands = byNumber ? numberBands : clockBands;
  const rows: Row[] = [];
  const periods: ScanPeriod[] = [];
  let next = 1;
  for (const band of bands) {
    const index = byNumber
      ? band.members.map((m) => periodOf(m.text)).find((p) => p !== null) ??
        null
      : null;
    const idx = index ?? next;
    next = idx + 1;
    for (const m of band.members) m.used = true;
    const near = clocked.filter((c) =>
      !c.used && Math.abs(c.cy - band.centre) <= h
    );
    const clocks = [...band.members, ...near].flatMap((m) =>
      labelClocks(m.text)
    );
    for (const c of near) c.used = true;
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

/** "Ma R12" → subject Ma, room R12; "Mathe Fr. Kurz" → subject Mathe, teacher Fr. Kurz.
 *  With a vocabulary: "Natur, Mensch, Gesellschaft" is one subject, "SU" is named
 *  Sachunterricht, "Sachunterrlcht" snaps to the family's "Sachunterricht", and "Pause" is
 *  no lesson. */
export function lessonOf(
  day: number,
  period: number,
  text: string,
  vocab: Vocab = DEFAULT_VOCAB,
): ScanLesson | null {
  return cellOf(day, period, text, vocab)?.lesson ?? null;
}

/** A week marker on a cell: "A", "B", "Q1"/"Q2" (quinzaine), "S1"/"S2", "A-Woche". */
function parityOf(token: string): "a" | "b" | null {
  const m = token.match(/^(?:([ab])(?:-?woche)?|[qs]([12]))$/i);
  if (!m) return null;
  if (m[1]) return m[1].toLowerCase() as "a" | "b";
  return m[2] === "1" ? "a" : "b";
}

/** The lesson of one cell, with the group of its subject when the language knows it. */
function cellOf(
  day: number,
  period: number,
  text: string,
  vocab: Vocab,
): { lesson: ScanLesson; group?: string } | null {
  // A name in parentheses is the teacher ("M rot (Hen)"), or the room when it has digits
  // or is a word in capitals ("(GIMNÀS)", "(AULA)").
  const bracketed: string[] = [];
  const plain = text.replace(/\(([^()]{1,30})\)/g, (_, inner: string) => {
    bracketed.push(inner.trim());
    return " ";
  });
  let words = plain.replace(/[|_]+/g, " ").split(/\s+/).filter((t) =>
    t.length > 0
  );
  if (words.length === 0 && bracketed.length === 0) return null;
  if (BREAK_KEYS.has(subjectKey(words.join(" ")))) return null;

  // A week marker before the subject ("B Ma") or after it ("Ma A R12").
  let parity: "a" | "b" | null = null;
  if (words.length >= 2) {
    const leading = parityOf(words[0]);
    if (leading !== null) {
      parity = leading;
      words = words.slice(1);
    }
  }
  const tokens = [...words, ...bracketed];
  if (tokens.length === 0) return null;

  // The subject: the longest run of leading words that is a known subject, else the first.
  let take = 1;
  let subject = "";
  let name: string | undefined;
  let key = "";
  let own = false;
  // A family word the OCR split at a line break ("Mathe matik") beats the language's
  // reading of its first piece.
  const joined = joinWrapped(words, vocab);
  if (joined !== null && joined.own) {
    subject = joined.word;
    name = joined.name;
    own = true;
    take = joined.take;
    key = subjectKey(joined.name ?? joined.word);
  }
  for (let n = Math.min(vocab.maxTokens, words.length); n >= 1; n--) {
    if (subject.length > 0) break;
    const k = subjectKey(words.slice(0, n).join(" "));
    const word = vocab.family.get(k);
    if (word !== undefined) {
      take = n;
      subject = word;
      name = vocab.names.get(k);
      key = k;
      own = true;
      break;
    }
    const named = vocab.names.get(k);
    if (named !== undefined || (n > 1 && vocab.known.has(k))) {
      take = n;
      subject = words.slice(0, n).join(" ").replace(/[.,:;]+$/, "");
      name = named;
      key = k;
      break;
    }
  }
  if (subject.length === 0) {
    subject = tokens[0].replace(/[.,:;]+$/, "");
    if (subject.length === 0 || /^[-–—]+$/.test(subject)) return null;
    key = subjectKey(subject);
    const snapped = snapSubject(key, vocab);
    if (snapped !== null) {
      subject = snapped.word;
      name = snapped.name;
      own = snapped.own;
      key = subjectKey(snapped.name ?? snapped.word);
    } else {
      // "E1", "F3": the code with a level behind it keeps its name.
      const level = subject.match(/^([A-Za-zÄÖÜäöüß]{1,4})\d$/);
      if (level) {
        const base = subjectKey(level[1]);
        name = vocab.names.get(base);
        if (name !== undefined) key = base;
      }
      // A word wrapped over two boxes ("Sachunter richt", "Program ación"): joined, when
      // the join is a word of the language, or one edit from it.
      if (joined !== null) {
        subject = joined.word;
        name = joined.name;
        own = joined.own;
        take = joined.take;
        key = subjectKey(joined.name ?? joined.word);
      }
    }
  }
  const rooms: string[] = [];
  const names: string[] = [];
  for (const t of tokens.slice(take)) {
    const marker = parity === null ? parityOf(t) : null;
    if (marker !== null) parity = marker;
    else if (/\d/.test(t)) rooms.push(t);
    else if (bracketed.includes(t) && /^[A-ZÄÖÜÀ-Ý]{4,}$/.test(t)) {
      rooms.push(t);
    } else names.push(t);
  }
  const lesson: ScanLesson = { day, period, subject: subject.slice(0, 60) };
  if (name !== undefined && name !== lesson.subject) lesson.name = name;
  if (rooms.length > 0) lesson.room = rooms.join(" ").slice(0, 40);
  if (names.length > 0) lesson.teacher = names.join(" ").slice(0, 60);
  if (parity !== null) lesson.parity = parity;
  const group = key.length > 0 ? vocab.groups.get(key) : undefined;
  if (!own && group !== undefined) {
    const members = vocab.familyGroups.get(group);
    if (members !== undefined && members.length === 1) lesson.like = members[0];
  }
  return { lesson, group };
}

type Snap = { word: string; name?: string; own: boolean };

/** Two or three leading words that are one word of the family's or of the language when
 *  joined, or one edit from it: the OCR split "Sachunterricht" at a line break. */
function joinWrapped(
  words: string[],
  vocab: Vocab,
): (Snap & { take: number }) | null {
  for (let n = Math.min(3, words.length); n >= 2; n--) {
    const parts = words.slice(0, n);
    if (!parts.every((w) => /^[\p{L}-]+$/u.test(w))) continue;
    const compact = parts.join("");
    const key = subjectKey(compact);
    if (key.length < 6) continue;
    const word = vocab.family.get(key);
    if (word !== undefined) {
      return { word, name: vocab.names.get(key), own: true, take: n };
    }
    const named = vocab.names.get(key);
    if (named !== undefined) {
      return { word: compact, name: named, own: false, take: n };
    }
    const snapped = key.length >= 7 ? snapSubject(key, vocab, 1) : null;
    if (snapped !== null) return { ...snapped, take: n };
  }
  return null;
}

/** The family's word or the language's name that [key] almost is: one edit away for five
 *  letters or more, two for nine or more. The family's words come first. Null when none, or
 *  when two candidates are equally close. */
function snapSubject(
  key: string,
  vocab: Vocab,
  atMost = 2,
): Snap | null {
  if (key.length < 5) return null;
  const max = Math.min(atMost, key.length >= 9 ? 2 : 1);
  const own: [string, Snap][] = [];
  for (const [candidate, word] of vocab.family) {
    own.push([candidate, {
      word,
      name: vocab.names.get(candidate),
      own: true,
    }]);
  }
  const named: [string, Snap][] = [];
  for (const [candidate, name] of vocab.names) {
    if (candidate === subjectKey(name)) {
      named.push([candidate, { word: name, name, own: false }]);
    }
  }
  return nearest(key, own, max) ?? nearest(key, named, max);
}

/** The candidate nearest to [key] within [max] edits; null when none or when two tie. */
function nearest(
  key: string,
  candidates: [string, Snap][],
  max: number,
): Snap | null {
  let best: Snap | null = null;
  let bestDistance = max + 1;
  let tied = false;
  for (const [candidate, snap] of candidates) {
    if (candidate.length < 5) continue;
    const distance = editDistance(key, candidate, max);
    if (distance > max) continue;
    if (distance < bestDistance) {
      best = snap;
      bestDistance = distance;
      tied = false;
    } else if (
      distance === bestDistance && best !== null && best.word !== snap.word
    ) {
      tied = true;
    }
  }
  return tied ? null : best;
}

/**
 * The grid in the lines, or null when no weekday header was found (the photo shows no
 * timetable the parser can read).
 */
export function parseTimetableScan(
  input: OcrLine[],
  hints?: ScanHints,
): ScanResult | null {
  const lines = input.map(lineOf).filter((l): l is Line => l !== null);
  if (lines.length < 4) return null;
  const vocab = vocabOf(hints);
  // A tilted photo is read level first; the raw boxes are the fallback.
  const tilt = skewOf(lines);
  const sets = Math.abs(tilt) > 0.015
    ? [straighten(lines, tilt), lines]
    : [lines];
  for (const set of sets) {
    const result = readAnyWay(set, vocab);
    if (result) return result;
  }
  return null;
}

/**
 * The four ways a sheet can lie: upright; turned, as a diary page or a hand-drawn sheet runs
 * the days down the left and the periods across the top; and each of them mirrored, as a photo
 * taken sideways the other way round or upside down runs the days backwards. Each is the same
 * grid under a swap or a mirror of the axes; the first plausible reading wins.
 */
function readAnyWay(lines: Line[], vocab: Vocab): ScanResult | null {
  const variants: [boolean, (l: Line) => Line][] = [
    [false, (l) => ({ ...l })],
    [true, (l) => ({ ...l, cx: l.cy, cy: l.cx, w: l.h, h: l.w })],
    [false, (l) => ({ ...l, cx: -l.cx })],
    [true, (l) => ({ ...l, cx: -l.cy, cy: l.cx, w: l.h, h: l.w })],
  ];
  for (const [transposed, map] of variants) {
    const result = parseGrid(
      lines.map((l) => ({ ...map(l), used: false })),
      vocab,
    );
    if (!result) continue;
    const read = { ...result, transposed };
    if (plausible(read)) return read;
  }
  return null;
}

/**
 * A grid a family could mean: at least two periods (three when the sheet was read turned,
 * where a one-row list of weekdays is a menu or a rota, not a timetable), at most four text
 * pieces per cell (a whole-school master plan packs dozens into what looks like one cell),
 * and a turned reading that placed more than it dropped.
 */
function plausible(r: ScanResult): boolean {
  if (r.rows < (r.transposed ? 3 : 2)) return false;
  if (r.placed > r.rows * r.columns * 4) return false;
  // A grid that leaves most of the text outside is a photo of something else.
  if (r.unplaced > r.placed * (r.transposed ? 1 : 1.5)) return false;
  return true;
}

/**
 * The legend many sheets print under or beside the grid: a code and its name in one box
 * ("MAT Mathematik", "GES tx Textiles Gestalten") or in two boxes on one line ("BSP ..",
 * "Bewegung und Sport"). Only codes that stand in a cell count, and only text no cell or
 * label took. The lines read are marked used, so they no longer count as unplaced.
 */
function readLegend(
  lines: Line[],
  h: number,
  codes: Set<string>,
): { names: Map<string, string>; consumed: number } {
  const names = new Map<string, string>();
  let consumed = 0;
  const trim = (t: string) => t.replace(/^[\s.:=–-]+|[\s.:=–-]+$/g, "");
  const isName = (t: string) =>
    /[a-zäöüàâéèêëîïôùûüç]{3}/i.test(t) && t.length <= 60 &&
    !codes.has(subjectKey(t));
  const free = lines.filter((l) => !l.used);
  for (const l of free) {
    if (l.used) continue;
    const text = trim(l.text);
    const words = text.split(/\s+/).filter((w) => w.length > 0);
    // Code and name in one box.
    let hit = false;
    for (let n = Math.min(2, words.length - 1); n >= 1; n--) {
      const code = subjectKey(words.slice(0, n).join(" "));
      const rest = trim(words.slice(n).join(" "));
      if (codes.has(code) && !names.has(code) && isName(rest)) {
        names.set(code, rest);
        l.used = true;
        consumed++;
        hit = true;
        break;
      }
    }
    if (hit) continue;
    // The code alone, its name in the next box to the right on the same line.
    const code = subjectKey(text);
    if (text.length > 12 || !codes.has(code) || names.has(code)) continue;
    // Legend lines sit closer than their boxes are tall: the box on the same baseline
    // wins over one on the line below.
    let next: Line | null = null;
    for (const r of free) {
      if (r === l || r.used || Math.abs(r.cy - l.cy) > h * 0.6) continue;
      const gap = (r.cx - r.w / 2) - (l.cx + l.w / 2);
      if (gap < -h * 0.5 || gap > h * 8) continue;
      if (
        next === null ||
        Math.abs(r.cy - l.cy) < Math.abs(next.cy - l.cy) - h * 0.2 ||
        (Math.abs(Math.abs(r.cy - l.cy) - Math.abs(next.cy - l.cy)) <=
            h * 0.2 &&
          r.cx < next.cx)
      ) next = r;
    }
    if (next === null) continue;
    const rest = trim(next.text);
    if (!isName(rest)) continue;
    // In a two-column legend the box belongs to the code nearest to its left.
    const nearer = free.some((c) =>
      c !== l && c !== next && !c.used &&
      Math.abs(c.cy - l.cy) <= h * 0.6 && c.cx > l.cx && c.cx < next!.cx &&
      trim(c.text).length <= 12 && codes.has(subjectKey(trim(c.text)))
    );
    if (nearer) continue;
    names.set(code, rest);
    l.used = true;
    next.used = true;
    consumed += 2;
  }
  return { names, consumed };
}

function parseGrid(input: Line[], vocab: Vocab): ScanResult | null {
  const lines = input.map((l) => ({ ...l, used: false }));
  const h = median(lines.map((l) => l.h));
  const header = findColumns(lines, h, vocab);
  if (!header) return null;
  const { columns, headerY } = header;
  const gaps = columns.slice(1).map((c, i) => c.cx - columns[i].cx);
  const spacing = median(gaps);
  const { rows, periods } = findRows(lines, columns, headerY, spacing, h);
  if (rows.length === 0) return null;
  const rowGaps = rows.slice(1).map((r, i) => r.cy - rows[i].cy);
  const rowSpacing = rowGaps.length > 0 ? median(rowGaps) : h * 2;

  const bounds = columnBounds(columns, spacing);
  const cells = new Map<string, Line[]>();
  let placed = 0;
  let unplaced = 0;
  for (const l of lines) {
    if (l.used || l.cy <= headerY + h / 2) continue;
    let column: Column | null = null;
    for (let i = 0; i < columns.length; i++) {
      if (l.cx >= bounds[i].from && l.cx < bounds[i].to) {
        column = columns[i];
        break;
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
    l.used = true;
    const key = `${column.day}:${row.index}`;
    const list = cells.get(key) ?? [];
    list.push(l);
    cells.set(key, list);
  }

  const lessons: ScanLesson[] = [];
  const care = new Map<string, ScanCare>();
  const byIndex = new Map(periods.map((p) => [p.index, p]));
  for (const [key, members] of cells) {
    const [day, period] = key.split(":").map(Number);
    members.sort((
      a,
      b,
    ) => (Math.abs(a.cy - b.cy) > h / 2 ? a.cy - b.cy : a.cx - b.cx));
    const cell = cellOf(
      day,
      period,
      members.map((m) => m.text).join(" "),
      vocab,
    );
    if (!cell) continue;
    // A care word on a row with clock times is a care row, not a lesson (specs/15).
    const times = byIndex.get(period);
    if (cell.group === CARE_GROUP && times !== undefined) {
      const title = cell.lesson.name ?? cell.lesson.subject;
      const id = `${subjectKey(title)}|${times.starts}|${times.ends}`;
      const row = care.get(id) ??
        { title, days: [], starts: times.starts, ends: times.ends };
      if (!row.days.includes(day)) row.days.push(day);
      care.set(id, row);
      continue;
    }
    lessons.push(cell.lesson);
  }
  lessons.sort((a, b) => a.day - b.day || a.period - b.period);
  if (lessons.length === 0) return null;

  // The sheet's own legend ("MAT Mathematik" under the grid) names the codes for certain.
  const legend = readLegend(
    lines,
    h,
    new Set(lessons.map((l) => subjectKey(l.subject))),
  );
  unplaced -= legend.consumed;
  for (const lesson of lessons) {
    const read = legend.names.get(subjectKey(lesson.subject));
    if (read === undefined) continue;
    // The legend as printed, unless the language knows the word it almost is
    // ("BMewegung und Sport").
    const snapped = snapSubject(subjectKey(read), vocab);
    const name = snapped === null ? read : snapped.name ?? snapped.word;
    if (subjectKey(name) !== subjectKey(lesson.subject)) lesson.name = name;
  }

  const payload: ScanPayload = { format: "wuselwall-timetable/1", lessons };
  if (periods.length > 0) {
    payload.periods = periods.sort((a, b) => a.index - b.index);
  }
  if (care.size > 0) {
    payload.care = [...care.values()].map((c) => ({
      ...c,
      days: c.days.sort((a, b) => a - b),
    }));
  }
  return {
    payload,
    placed,
    unplaced,
    columns: columns.length,
    rows: rows.length,
    transposed: false,
  };
}
