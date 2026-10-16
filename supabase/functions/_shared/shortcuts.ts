// Siri via Apple Shortcuts (specs/12 "Part 1", FR-6.5): the pure half of the `shortcuts`
// function. It reads dictation ("2 Liter Milch und Eier"), finds people and subjects in a
// spoken question ("Hat Mia morgen Sport?"), and writes the answers a shortcut shows or speaks.
//
// Pure: no I/O, no clock — `now` and the context (api.shortcut_context) come in as arguments.
// The context's rows have the api views' shape, so occurrence expansion and the school
// projection run on them unchanged. The wording lives in shortcuts_de.ts and shortcuts_en.ts,
// which both satisfy ShortcutMessages, so a sentence cannot exist in one language only.
import {
  addDays,
  type EventRow,
  expand,
  type ExternalOccurrenceRow,
  importedOccurrence,
  type Occurrence,
  type OverrideRow,
  sortOccurrences,
} from "./occurrences.ts";
import type { HolidayFeedRow } from "./openholidays.ts";
import {
  type ExceptionRow,
  type HolidayRow,
  type LessonJson,
  type LessonRow,
  type PeriodRow,
  projectSchoolDays,
  publicHolidayRows,
  type SchoolData,
  type SchoolDayJson,
  type SchoolRow,
  type SubjectRow,
  type TermRow,
  type TimetableRow,
} from "./school.ts";
import { SHORTCUTS_DE } from "./shortcuts_de.ts";
import { SHORTCUTS_EN } from "./shortcuts_en.ts";

// ── the context (api.shortcut_context) ────────────────────────────────────────────

export type Lang = "de" | "en";

export type MemberRow = {
  id: string;
  display_name: string;
  role: "guardian" | "member";
  kind: "adult" | "child";
  default_presence_state: string | null;
  default_presence_label: string | null;
};

export type TaskRow = {
  id: string;
  title: string;
  points: number;
  due_on: string;
  opens_on: string;
  closes_on: string;
  assigned_profile_id: string | null;
  requires_verification: boolean;
};

export type MealRow = {
  on_date: string;
  slot: string;
  title: string | null;
  cook_profile_id: string | null;
  at_time: string | null;
};

export type ListRow = { id: string; name: string; is_default: boolean };

export type SchoolRows = {
  schools: SchoolRow[];
  periods: PeriodRow[];
  terms: TermRow[];
  subjects: SubjectRow[];
  timetables: TimetableRow[];
  lessons: LessonRow[];
  exceptions: ExceptionRow[];
  holidays: HolidayRow[];
  public_feed: HolidayFeedRow[];
};

export type ShortcutContext = {
  holder: {
    profile_id: string;
    display_name: string;
    role: string;
    kind: string;
  };
  household: {
    name: string;
    timezone: string;
    locale: string;
    today: string;
    region: string | null;
  };
  window: { from: string; to: string };
  members: MemberRow[];
  points: number;
  lists: ListRow[];
  equipment_hint: boolean;
  events?: EventRow[];
  overrides?: OverrideRow[];
  external?: ExternalOccurrenceRow[];
  school?: SchoolRows;
  meals?: MealRow[];
  tasks?: TaskRow[];
};

/** What a shortcut gets back: a sentence to show or speak, and the facts behind it. */
export type Answer = { text: string; data: Record<string, unknown> };

// ── the wording ───────────────────────────────────────────────────────────────────

export type PresenceState =
  | "working"
  | "home_office"
  | "travel"
  | "away"
  | "off"
  | "childcare";

/** The wording of one language. shortcuts_de.ts and shortcuts_en.ts both satisfy this. */
export interface ShortcutMessages {
  /** The BCP 47 locale dates are written in. */
  locale: string;
  today: string;
  tomorrow: string;
  dayAfterTomorrow: string;
  /** "am Freitag, 18. Oktober" — `date` is the weekday and date already written out. */
  onDate(date: string): string;
  /** "a, b und c". */
  joinList(items: string[]): string;

  tokenInvalid: string;
  rateLimited: string;
  unknownAction: string;
  failed: string;
  textRequired: string;
  memberRequired: string;
  memberUnknown(name: string): string;
  listUnknown(name: string): string;
  dayInvalid(value: string): string;

  /** `names` are the items as filed ("Äpfel (3×)"); `list` is null for the default list. */
  shoppingAdded(names: string[], list: string | null): string;

  noEvents(when: string): string;
  events(when: string, items: string[]): string;
  allDay: string;
  slot: Record<"breakfast" | "lunch" | "dinner" | "snack", string>;
  noMeals(when: string): string;
  meals(when: string, items: string[]): string;
  cooks(name: string): string;
  yourChores(titles: string[]): string;

  points(n: number): string;

  choreDone(title: string, points: number): string;
  choreAwaitsCheck(title: string): string;
  choreNoneOpen: string;
  choreOpen(titles: string[]): string;
  choreNoMatch(text: string, open: string[]): string;
  choreAmbiguous(text: string, candidates: string[]): string;

  noTimetable(name: string): string;
  weekend(name: string, when: string): string;
  holiday(name: string, when: string, holiday: string | null): string;
  schoolDay(name: string, when: string, from: string, to: string, subjects: string[]): string;
  noLessons(name: string, when: string): string;
  equipment(items: string[]): string;
  hasSubject(name: string, when: string, subject: string, period: number | null, time: string): string;
  hasNotSubject(name: string, when: string, subject: string): string;
  subjectCancelled(name: string, when: string, subject: string): string;

  state: Record<PresenceState, string>;
  presenceHere(name: string): string;
  /** Away for whole days: the last day away and the day of return, both written out. */
  presenceAwayDays(name: string, state: string, lastDay: string, back: string): string;
  /** Away until a time: `when` is today/tomorrow/on…, `time` "18:00". */
  presenceAwayUntil(name: string, state: string, when: string, time: string): string;
  /** Away for the whole of today, home in the evening (an all-day shift). */
  presenceToday(name: string, state: string): string;
  presenceNext(state: string, from: string, to: string): string;
}

export function messagesFor(lang: Lang): ShortcutMessages {
  return lang === "en" ? SHORTCUTS_EN : SHORTCUTS_DE;
}

/**
 * The language of the answer: an explicit `lang` ("de", "en-GB"), else the first supported
 * language of Accept-Language, else the household's locale, else German (NFR-14).
 */
export function pickLang(
  param: unknown,
  acceptLanguage: string | null,
  householdLocale: string | null,
): Lang {
  const of = (tag: string): Lang | null => {
    const primary = tag.trim().toLowerCase().split(/[-_;]/)[0];
    return primary === "de" || primary === "en" ? primary : null;
  };
  if (typeof param === "string" && of(param)) return of(param)!;
  for (const part of (acceptLanguage ?? "").split(",")) {
    const lang = of(part);
    if (lang) return lang;
  }
  return (householdLocale && of(householdLocale)) || "de";
}

// ── text helpers ──────────────────────────────────────────────────────────────────

/** The same folding as app.fold in SQL: lower case, umlauts spelled out, accents dropped. */
export function fold(text: string): string {
  return text
    .replace(/[äÄ]/g, "ae").replace(/[öÖ]/g, "oe").replace(/[üÜ]/g, "ue")
    .replace(/ß/g, "ss")
    .normalize("NFD").replace(/[̀-ͯ]/g, "")
    .toLowerCase();
}

/** The folded words of a text: letters and digits only. */
function words(text: string): string[] {
  return fold(text).split(/[^\p{L}\p{N}]+/u).filter((w) => w !== "");
}

/** Does `needle` (one or more words) occur in `hay` as whole words? */
function containsWords(hay: string[], needle: string[]): boolean {
  if (needle.length === 0 || needle.length > hay.length) return false;
  for (let i = 0; i + needle.length <= hay.length; i++) {
    if (needle.every((w, j) => hay[i + j] === w)) return true;
  }
  return false;
}

// ── dictation → shopping items ────────────────────────────────────────────────────

export type ShoppingItem = { name: string; quantity?: string; count?: number };

const NUMBER_WORDS: Record<string, number> = {
  ein: 1,
  eine: 1,
  einen: 1,
  einem: 1,
  einer: 1,
  eins: 1,
  zwei: 2,
  drei: 3,
  vier: 4,
  fuenf: 5,
  sechs: 6,
  sieben: 7,
  acht: 8,
  neun: 9,
  zehn: 10,
  zwoelf: 12,
  a: 1,
  an: 1,
  one: 1,
  two: 2,
  three: 3,
  four: 4,
  five: 5,
  six: 6,
  seven: 7,
  eight: 8,
  nine: 9,
  ten: 10,
  twelve: 12,
};

// Spoken units → how they are written on the list. Folded keys.
const UNITS: Record<string, string> = {
  l: "l",
  liter: "l",
  litre: "l",
  liters: "l",
  litres: "l",
  ml: "ml",
  milliliter: "ml",
  g: "g",
  gramm: "g",
  gram: "g",
  grams: "g",
  gramme: "g",
  kg: "kg",
  kilo: "kg",
  kilos: "kg",
  kilogramm: "kg",
  kilogram: "kg",
  kilograms: "kg",
  pfund: "Pfund",
  packung: "Packung",
  packungen: "Packungen",
  pack: "Pack",
  packs: "Packs",
  packet: "Packet",
  packets: "Packets",
  paket: "Paket",
  pakete: "Pakete",
  dose: "Dose",
  dosen: "Dosen",
  can: "can",
  cans: "cans",
  tin: "tin",
  tins: "tins",
  flasche: "Flasche",
  flaschen: "Flaschen",
  bottle: "bottle",
  bottles: "bottles",
  becher: "Becher",
  glas: "Glas",
  glaeser: "Gläser",
  jar: "jar",
  jars: "jars",
  bund: "Bund",
  bunch: "bunch",
  bunches: "bunches",
  stueck: "Stück",
  piece: "piece",
  pieces: "pieces",
  tafel: "Tafel",
  tafeln: "Tafeln",
  netz: "Netz",
  beutel: "Beutel",
  bag: "bag",
  bags: "bags",
  dozen: "dozen",
  dutzend: "Dutzend",
};

// Words that add nothing when they open an item ("Bitte Milch", "noch Eier", "some milk").
const FILLERS = new Set(["bitte", "noch", "auch", "etwas", "some", "please", "more", "also"]);

/** The most items one call adds (api.shortcut_shopping_add takes 20). */
export const MAX_ITEMS = 20;

/**
 * Items from dictated text: split at commas (not a decimal comma), semicolons, new lines,
 * "und"/"and", "&" and "+";
 * a leading number or number word with a unit becomes the quantity ("2 Liter Milch" → Milch,
 * "2 l"), a bare number becomes the count ("3 Äpfel" → Äpfel, 3×). Deliberately forgiving:
 * dictated speech files imperfectly rather than not at all (specs/12).
 */
export function parseShoppingText(text: string): ShoppingItem[] {
  const parts = text
    .split(/(?<!\d),|,(?!\d)|[;\n]+|\s+(?:und|and|sowie)\s+|\s*&\s*|\s*\+\s*/i)
    .map((p) => p.trim().replace(/[.!?]+$/, "").trim())
    .filter((p) => p !== "");
  const items: ShoppingItem[] = [];
  for (const part of parts) {
    const item = parseItem(part);
    if (item) items.push(item);
    if (items.length === MAX_ITEMS) break;
  }
  return items;
}

function parseItem(part: string): ShoppingItem | null {
  const tokens = part.split(/\s+/).filter((t) => t !== "");
  while (tokens.length > 1 && FILLERS.has(fold(tokens[0]))) tokens.shift();
  if (tokens.length < 2) return finish(tokens, null, null);
  const first = tokens[0];

  // "2l Milch", "500g Mehl": the unit glued to the number.
  const glued = /^(\d+(?:[.,]\d+)?)([a-zA-Z]+)$/.exec(first);
  if (glued && fold(glued[2]) in UNITS) {
    return finish(tokens.slice(1), `${glued[1]} ${UNITS[fold(glued[2])]}`, null);
  }

  // "2", "2,5", "2x", "zwei", "a".
  const numeric = /^(\d+(?:[.,]\d+)?)(?:x|×)?$/i.exec(first);
  const amount = numeric
    ? numeric[1]
    : fold(first) in NUMBER_WORDS
    ? String(NUMBER_WORDS[fold(first)])
    : null;
  if (amount === null) return finish(tokens, null, null);

  const rest = tokens.slice(1);
  if (rest.length > 1 && fold(rest[0]) in UNITS) {
    const unit = UNITS[fold(rest[0])];
    const name = rest.slice(1);
    if (name.length > 1 && ["of", "von"].includes(fold(name[0]))) name.shift();
    return finish(name, `${amount} ${unit}`, null);
  }
  const n = Number(amount.replace(",", "."));
  return Number.isInteger(n) && n >= 1 && n <= 99 ? finish(rest, null, n) : finish(rest, amount, null);
}

function finish(
  tokens: string[],
  quantity: string | null,
  count: number | null,
): ShoppingItem | null {
  const name = tokens.join(" ").trim().slice(0, 120);
  if (name === "") return null;
  const item: ShoppingItem = {
    name: name.charAt(0).toLocaleUpperCase("de") + name.slice(1),
  };
  if (quantity !== null) item.quantity = quantity;
  if (count !== null && count > 1) item.count = count;
  return item;
}

// ── days ──────────────────────────────────────────────────────────────────────────

/** A day as asked for, before the household's "today" is known. */
export type DaySpec =
  | { kind: "offset"; days: number }
  | { kind: "weekday"; weekday: number } // ISO: 1 = Monday … 7 = Sunday
  | { kind: "date"; date: string };

const DAY_WORDS: Record<string, DaySpec> = {
  heute: { kind: "offset", days: 0 },
  today: { kind: "offset", days: 0 },
  morgen: { kind: "offset", days: 1 },
  tomorrow: { kind: "offset", days: 1 },
  uebermorgen: { kind: "offset", days: 2 },
};

const WEEKDAYS: Record<string, number> = {
  montag: 1,
  dienstag: 2,
  mittwoch: 3,
  donnerstag: 4,
  freitag: 5,
  samstag: 6,
  sonnabend: 6,
  sonntag: 7,
  monday: 1,
  tuesday: 2,
  wednesday: 3,
  thursday: 4,
  friday: 5,
  saturday: 6,
  sunday: 7,
};

/**
 * The day a parameter or a question names: "heute", "morgen", "übermorgen", a weekday (the
 * next one, today included) or YYYY-MM-DD. Null when nothing in it names a day. In a sentence
 * the first day word wins ("Hat Mia morgen Sport?"); "day after tomorrow" is read whole.
 */
export function parseDay(text: string): DaySpec | null {
  const trimmed = text.trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
    const ok = new Date(`${trimmed}T00:00:00Z`).toISOString().slice(0, 10) === trimmed;
    return ok ? { kind: "date", date: trimmed } : null;
  }
  const ws = words(trimmed);
  if (containsWords(ws, ["day", "after", "tomorrow"])) return { kind: "offset", days: 2 };
  for (const w of ws) {
    if (w in DAY_WORDS) return DAY_WORDS[w];
    if (w in WEEKDAYS) return { kind: "weekday", weekday: WEEKDAYS[w] };
  }
  return null;
}

/** The window the context must load for a day: [from (null = today), days]. */
export function windowFor(spec: DaySpec): { from: string | null; days: number } {
  switch (spec.kind) {
    case "offset":
      return { from: null, days: spec.days + 1 };
    case "weekday":
      return { from: null, days: 7 };
    case "date":
      return { from: spec.date, days: 1 };
  }
}

/** The ISO weekday of a date (1 = Monday). */
function isoWeekday(date: string): number {
  const d = new Date(`${date}T00:00:00Z`).getUTCDay();
  return d === 0 ? 7 : d;
}

/** The date a spec names, given the household's today. */
export function resolveDay(spec: DaySpec, today: string): string {
  switch (spec.kind) {
    case "offset":
      return addDays(today, spec.days);
    case "weekday":
      return addDays(today, (spec.weekday - isoWeekday(today) + 7) % 7);
    case "date":
      return spec.date;
  }
}

/** "heute", "morgen", "übermorgen" or "am Freitag, 18. Oktober". */
export function whenOf(date: string, today: string, m: ShortcutMessages): string {
  if (date === today) return m.today;
  if (date === addDays(today, 1)) return m.tomorrow;
  if (date === addDays(today, 2)) return m.dayAfterTomorrow;
  return m.onDate(longDate(date, m));
}

/** "Freitag, 18. Oktober" / "Friday 18 October", in the language's own order. */
export function longDate(date: string, m: ShortcutMessages): string {
  return new Date(`${date}T12:00:00Z`).toLocaleDateString(m.locale, {
    weekday: "long",
    day: "numeric",
    month: "long",
    timeZone: "UTC",
  });
}

// ── people ────────────────────────────────────────────────────────────────────────

/**
 * The member a name means: the same name folded, else the only one it starts, else null.
 * "lotta" finds Lotta, "Lo" finds her when nobody else starts so.
 */
export function findMember(members: MemberRow[], name: string): MemberRow | null {
  const q = fold(name.trim());
  if (q === "") return null;
  const exact = members.filter((m) => fold(m.display_name) === q);
  if (exact.length === 1) return exact[0];
  const prefix = members.filter((m) => fold(m.display_name).startsWith(q));
  return prefix.length === 1 ? prefix[0] : null;
}

/** The member a question names as a word ("Hat Mia morgen Sport?"); the longest name wins. */
export function memberInText(members: MemberRow[], text: string): MemberRow | null {
  const ws = words(text);
  const found = members
    .filter((m) => containsWords(ws, words(m.display_name)))
    .sort((a, b) => words(b.display_name).length - words(a.display_name).length);
  return found[0] ?? null;
}

function nameOf(ctx: ShortcutContext, id: string | null): string | null {
  return ctx.members.find((m) => m.id === id)?.display_name ?? null;
}

// ── shopping ──────────────────────────────────────────────────────────────────────

export type ShoppingResult = {
  status: "applied" | "duplicate";
  list: string;
  /** The household's locale, for the answer's language. */
  locale: string;
  items?: { id: string; name: string; merged: boolean; count: number }[];
};

export function answerShopping(
  result: ShoppingResult,
  sent: ShoppingItem[],
  defaultList: boolean,
  m: ShortcutMessages,
): Answer {
  // A replay has no items of its own; the sentence is the one the first call gave.
  const names = (result.items ?? sent.map((s) => ({ name: s.name, count: s.count ?? 1 })))
    .map((i) => (i.count > 1 ? `${i.name} (${i.count}×)` : i.name));
  return {
    text: m.shoppingAdded(names, defaultList ? null : result.list),
    data: { list: result.list, status: result.status, items: result.items ?? [] },
  };
}

// ── the day ───────────────────────────────────────────────────────────────────────

/** Every occurrence of the context's window, the household's events and imported ones. */
export function occurrencesOf(ctx: ShortcutContext): Occurrence[] {
  const tz = ctx.household.timezone;
  const { from, to } = ctx.window;
  const imported = (ctx.external ?? [])
    .map((row) => importedOccurrence(row, tz))
    .filter((o) => o.local_start_date <= to && o.local_end_date >= from);
  return sortOccurrences([
    ...expand(ctx.events ?? [], ctx.overrides ?? [], from, to, tz),
    ...imported,
  ]);
}

function onDay(o: Occurrence, date: string): boolean {
  return o.local_start_date <= date && o.local_end_date >= date;
}

/** "08:00 Zahnarzt (Lotta)", "Elternabend (ganztägig)". Whole-family events name nobody. */
function eventLine(ctx: ShortcutContext, o: Occurrence, date: string, m: ShortcutMessages): string {
  const who = o.attendee_ids.length > 0 && o.attendee_ids.length < ctx.members.length
    ? o.attendee_ids.map((id) => nameOf(ctx, id)).filter((n): n is string => n !== null)
    : [];
  const people = who.length > 0 ? ` (${m.joinList(who)})` : "";
  if (o.all_day) return `${o.title}${people} (${m.allDay})`;
  // A timed event that began on an earlier day shows no start time.
  return o.local_start_date === date && o.local_starts
    ? `${o.local_starts} ${o.title}${people}`
    : `${o.title}${people}`;
}

function mealLine(meal: MealRow, m: ShortcutMessages): string {
  const slot = m.slot[meal.slot as keyof ShortcutMessages["slot"]] ?? meal.slot;
  return `${slot}: ${meal.title ?? "?"}`;
}

function mealsOn(ctx: ShortcutContext, date: string): MealRow[] {
  const order = ["breakfast", "lunch", "dinner", "snack"];
  return (ctx.meals ?? [])
    .filter((x) => x.on_date === date && x.title !== null)
    .sort((a, b) => order.indexOf(a.slot) - order.indexOf(b.slot));
}

/** The holder's own open chores of a day (the unassigned ones are not "yours" yet). */
function choresOn(ctx: ShortcutContext, date: string): TaskRow[] {
  return (ctx.tasks ?? []).filter((t) =>
    t.assigned_profile_id === ctx.holder.profile_id && t.opens_on <= date && t.closes_on >= date
  );
}

/** "What's on today": the appointments, the meals and the holder's chores of one day. */
export function answerDay(ctx: ShortcutContext, date: string, m: ShortcutMessages): Answer {
  const when = whenOf(date, ctx.household.today, m);
  const events = occurrencesOf(ctx).filter((o) => o.kind === "appointment" && onDay(o, date));
  const meals = mealsOn(ctx, date);
  const chores = choresOn(ctx, date);
  const sentences = [
    events.length === 0 ? m.noEvents(when) : m.events(when, events.map((o) => eventLine(ctx, o, date, m))),
  ];
  if (meals.length > 0) sentences.push(m.meals(when, meals.map((x) => mealLine(x, m))));
  if (chores.length > 0) sentences.push(m.yourChores(chores.map((t) => t.title)));
  return {
    text: sentences.join(" "),
    data: {
      date,
      events: events.map((o) => ({
        title: o.title,
        all_day: o.all_day,
        starts: o.local_starts,
        ends: o.local_ends,
        members: o.attendee_ids.map((id) => nameOf(ctx, id)).filter((n) => n !== null),
      })),
      meals: meals.map((x) => ({ slot: x.slot, title: x.title, cook: nameOf(ctx, x.cook_profile_id) })),
      chores: chores.map((t) => ({ id: t.id, title: t.title, points: t.points })),
    },
  };
}

/** "What's for dinner": the meals of one day, with who cooks. */
export function answerMeals(ctx: ShortcutContext, date: string, m: ShortcutMessages): Answer {
  const when = whenOf(date, ctx.household.today, m);
  const meals = mealsOn(ctx, date);
  if (meals.length === 0) return { text: m.noMeals(when), data: { date, meals: [] } };
  const sentences = [m.meals(when, meals.map((x) => mealLine(x, m)))];
  const cooks = [...new Set(meals.map((x) => nameOf(ctx, x.cook_profile_id)).filter((n) => n !== null))];
  for (const cook of cooks) sentences.push(m.cooks(cook!));
  return {
    text: sentences.join(" "),
    data: {
      date,
      meals: meals.map((x) => ({
        slot: x.slot,
        title: x.title,
        cook: nameOf(ctx, x.cook_profile_id),
        at: x.at_time,
      })),
    },
  };
}

export function answerPoints(ctx: ShortcutContext, m: ShortcutMessages): Answer {
  return {
    text: m.points(ctx.points),
    data: { member: ctx.holder.display_name, points: ctx.points },
  };
}

// ── chores ────────────────────────────────────────────────────────────────────────

export type ChorePick =
  | { kind: "task"; task: TaskRow }
  | { kind: "none_open" }
  | { kind: "list"; open: TaskRow[] }
  | { kind: "no_match"; open: TaskRow[] }
  | { kind: "ambiguous"; candidates: TaskRow[] };

/** The chores the holder can tick today: their own, and unassigned ones a member may claim. */
export function tickableChores(ctx: ShortcutContext): TaskRow[] {
  const today = ctx.household.today;
  return (ctx.tasks ?? []).filter((t) =>
    t.opens_on <= today && t.closes_on >= today &&
    (t.assigned_profile_id === ctx.holder.profile_id ||
      (t.assigned_profile_id === null && ctx.holder.role === "member"))
  );
}

/**
 * The chore a spoken name means. Every word of the title in the text wins first ("Spülmaschine
 * ausräumen ist erledigt"), then the most words in common; a tie is ambiguous rather than a
 * guess (specs/12: never let the assistant guess). No text lists the open chores.
 */
export function pickChore(ctx: ShortcutContext, text: string): ChorePick {
  const open = tickableChores(ctx);
  if (open.length === 0) return { kind: "none_open" };
  const said = words(text);
  if (said.length === 0) return { kind: "list", open };

  const whole = open.filter((t) => containsWords(said, words(t.title)));
  if (whole.length === 1) return { kind: "task", task: whole[0] };

  const scored = open
    .map((t) => {
      const title = words(t.title);
      // A word matches whole or as the start of a longer one ("Spülmaschine" ~ "spuel").
      const hits = title.filter((w) =>
        said.some((s) =>
          s === w || (s.length >= 4 && (w.startsWith(s) || s.startsWith(w)))
        )
      ).length;
      return { t, hits };
    })
    .filter((x) => x.hits > 0)
    .sort((a, b) => b.hits - a.hits);
  if (scored.length === 0) return { kind: "no_match", open };
  const best = scored.filter((x) => x.hits === scored[0].hits).map((x) => x.t);
  return best.length === 1 ? { kind: "task", task: best[0] } : { kind: "ambiguous", candidates: best };
}

export function answerChorePick(pick: ChorePick, text: string, m: ShortcutMessages): Answer {
  switch (pick.kind) {
    case "none_open":
      return { text: m.choreNoneOpen, data: { open: [] } };
    case "list":
      return { text: m.choreOpen(pick.open.map((t) => t.title)), data: { open: pick.open.map(choreData) } };
    case "no_match":
      return {
        text: m.choreNoMatch(text.trim(), pick.open.map((t) => t.title)),
        data: { open: pick.open.map(choreData) },
      };
    case "ambiguous":
      return {
        text: m.choreAmbiguous(text.trim(), pick.candidates.map((t) => t.title)),
        data: { candidates: pick.candidates.map(choreData) },
      };
    case "task":
      throw new Error("a picked task is answered after it is ticked");
  }
}

function choreData(t: TaskRow) {
  return { id: t.id, title: t.title, points: t.points, due_on: t.due_on };
}

export type ChoreResult = {
  status: "done" | "verified";
  points_credited: number;
  title: string;
  points: number;
  requires_verification: boolean;
};

export function answerChoreDone(result: ChoreResult, m: ShortcutMessages): Answer {
  const text = result.requires_verification && result.status === "done" && result.points_credited === 0
    ? m.choreAwaitsCheck(result.title)
    : m.choreDone(result.title, result.points_credited);
  return { text, data: result as unknown as Record<string, unknown> };
}

// ── school ────────────────────────────────────────────────────────────────────────

/** The projection's input from the context: the household's holidays plus the public ones. */
export function schoolDataOf(ctx: ShortcutContext): SchoolData {
  const s = ctx.school!;
  return {
    schools: s.schools,
    periods: s.periods,
    terms: s.terms,
    subjects: s.subjects,
    timetables: s.timetables,
    lessons: s.lessons,
    exceptions: s.exceptions,
    holidays: [
      ...s.holidays,
      ...publicHolidayRows(s.schools, s.public_feed, s.holidays, ctx.household.locale),
    ],
  };
}

export function schoolDaysOf(ctx: ShortcutContext): SchoolDayJson[] {
  return projectSchoolDays(schoolDataOf(ctx), ctx.window.from, ctx.window.to);
}

/** The subject a question names ("Sport", "Mathe"), from the household's subjects. */
export function subjectInText(subjects: SubjectRow[], text: string): SubjectRow | null {
  const ws = words(text);
  const named = subjects.filter((s) =>
    containsWords(ws, words(s.name)) || (s.short_name !== null && containsWords(ws, words(s.short_name)))
  );
  return named.sort((a, b) => words(b.name).length - words(a.name).length)[0] ?? null;
}

function lessonIs(lesson: LessonJson, subject: { name: string; short_name: string | null }): boolean {
  return fold(lesson.subject) === fold(subject.name) ||
    (subject.short_name !== null && lesson.short !== null && fold(lesson.short) === fold(subject.short_name));
}

/** Equipment of the lessons that take place, each once (the board's rule, week_board.dart). */
function equipmentOf(day: SchoolDayJson): string[] {
  return [
    ...new Set(
      day.lessons
        .filter((l) => l.status !== "cancelled" && l.equipment !== null)
        .map((l) => l.equipment!),
    ),
  ];
}

/**
 * "Hat Mia morgen Sport?" (with a subject) or "Was hat Mia morgen?" (without): the member's
 * projected school day. Weekends, holidays and days without a timetable are answered as such.
 */
export function answerSchool(
  ctx: ShortcutContext,
  member: MemberRow,
  date: string,
  subject: { name: string; short_name: string | null } | null,
  m: ShortcutMessages,
): Answer {
  const when = whenOf(date, ctx.household.today, m);
  const name = member.display_name;
  const day = schoolDaysOf(ctx).find((d) => d.member_id === member.id && d.date === date);
  const base = { member: name, date };
  if (!day) return { text: m.noTimetable(name), data: { ...base, school: false } };
  if (day.free === "weekend") return { text: m.weekend(name, when), data: { ...base, free: "weekend" } };
  if (day.free === "holiday") {
    return {
      text: m.holiday(name, when, day.holiday_name),
      data: { ...base, free: "holiday", holiday: day.holiday_name },
    };
  }

  const lessons = day.lessons.filter((l) => l.kind === "lesson");
  const data = {
    ...base,
    starts: day.starts,
    ends: day.ends,
    lessons: day.lessons.map((l) => ({
      period: l.period,
      starts: l.starts,
      ends: l.ends,
      subject: l.subject,
      status: l.status,
      room: l.room,
    })),
    equipment: ctx.equipment_hint ? equipmentOf(day) : [],
  };

  if (subject !== null) {
    const matching = lessons.filter((l) => lessonIs(l, subject));
    const held = matching.filter((l) => l.status !== "cancelled");
    if (held.length > 0) {
      const first = held[0];
      return {
        text: m.hasSubject(name, when, subject.name, first.period, `${first.starts}–${first.ends}`),
        data: { ...data, subject: subject.name, has_subject: true },
      };
    }
    if (matching.length > 0) {
      return {
        text: m.subjectCancelled(name, when, subject.name),
        data: { ...data, subject: subject.name, has_subject: false, cancelled: true },
      };
    }
    return {
      text: m.hasNotSubject(name, when, subject.name),
      data: { ...data, subject: subject.name, has_subject: false },
    };
  }

  const held = lessons.filter((l) => l.status !== "cancelled");
  if (held.length === 0 || day.starts === null || day.ends === null) {
    return { text: m.noLessons(name, when), data };
  }
  const subjects = [...new Set(held.map((l) => l.subject))];
  const sentences = [m.schoolDay(name, when, day.starts, day.ends, subjects)];
  if (data.equipment.length > 0) sentences.push(m.equipment(data.equipment));
  return { text: sentences.join(" "), data };
}

// ── presence ──────────────────────────────────────────────────────────────────────

// The states in which a person is not at home (specs/05 presence; Homeoffice and Frei are at
// home). Travel and away last nights and are joined into one absence; work and childcare end
// the same day.
const AWAY_STATES = new Set(["travel", "away", "working", "childcare"]);
const OVERNIGHT_STATES = new Set(["travel", "away"]);

/**
 * "Wann ist Sabine wieder da?": the member's presence now and next. Away for nights (travel,
 * away) is answered with the day of return, joining back-to-back entries; a shift or childcare
 * until a time with that time, or as "today" when it fills the day. Otherwise the member is
 * here, and the next trip in the window is named. `now` is an instant; the window starts today.
 */
export function answerPresence(
  ctx: ShortcutContext,
  member: MemberRow,
  now: Date,
  m: ShortcutMessages,
): Answer {
  const today = ctx.household.today;
  const name = member.display_name;
  const nowMs = now.getTime();
  const own = occurrencesOf(ctx).filter((o) =>
    o.kind === "presence" && o.presence_state !== null && AWAY_STATES.has(o.presence_state) &&
    o.attendee_ids.includes(member.id)
  );
  const covers = (o: Occurrence, ms: number) => Date.parse(o.start) <= ms && ms < Date.parse(o.end);
  // A trip wins over a shift on the same day: it is the longer absence.
  const current = own.find((o) => covers(o, nowMs) && OVERNIGHT_STATES.has(o.presence_state!)) ??
    own.find((o) => covers(o, nowMs));
  const stateOf = (o: Occurrence) => m.state[o.presence_state as PresenceState] ?? o.presence_state!;

  if (current && OVERNIGHT_STATES.has(current.presence_state!)) {
    // Join trips that follow without a gap: Tuesday's trip and Wednesday's day away are one absence.
    let endMs = Date.parse(current.end);
    let last = current;
    for (;;) {
      const next = own.find((o) =>
        o !== last && OVERNIGHT_STATES.has(o.presence_state!) && Date.parse(o.start) <= endMs &&
        Date.parse(o.end) > endMs
      );
      if (!next) break;
      endMs = Date.parse(next.end);
      last = next;
    }
    const data = {
      member: name,
      here: false,
      state: current.presence_state,
      until: new Date(endMs).toISOString(),
    };
    return {
      text: last.all_day
        ? m.presenceAwayDays(
          name,
          stateOf(current),
          longDate(last.local_end_date, m),
          whenOf(addDays(last.local_end_date, 1), today, m),
        )
        : m.presenceAwayUntil(
          name,
          stateOf(current),
          whenOf(last.local_end_date, today, m),
          last.local_ends ?? "",
        ),
      data,
    };
  }
  if (current) {
    const data = { member: name, here: false, state: current.presence_state, until: current.end };
    return {
      text: current.all_day ? m.presenceToday(name, stateOf(current)) : m.presenceAwayUntil(
        name,
        stateOf(current),
        whenOf(current.local_end_date, today, m),
        current.local_ends ?? "",
      ),
      data,
    };
  }

  const sentences = [m.presenceHere(name)];
  const next = own.find((o) => Date.parse(o.start) > nowMs && OVERNIGHT_STATES.has(o.presence_state!));
  if (next) {
    sentences.push(
      m.presenceNext(stateOf(next), longDate(next.local_start_date, m), longDate(next.local_end_date, m)),
    );
  }
  return {
    text: sentences.join(" "),
    data: {
      member: name,
      here: true,
      next: next
        ? { state: next.presence_state, from: next.local_start_date, to: next.local_end_date }
        : null,
    },
  };
}
