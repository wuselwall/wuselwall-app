// Finding appointments by what they say (FR-10.2, specs/05 "Finding an appointment").
//
// Pure: the `search` function loads the caller's rows and hands them here. The matching is
// the app's own (app/lib/core/text/search.dart): folded words, every one of which has to be
// found, the title before the place before the note. What comes back are occurrences in
// the shape the `occurrences` function answers with, so the app draws them as it draws any.
import {
  addDays,
  type EventRow,
  expand,
  type ExternalOccurrenceRow,
  importedOccurrence,
  type Occurrence,
  type OverrideRow,
} from "./occurrences.ts";

/** A shorter query finds too much to be an answer. */
export const MIN_QUERY_LENGTH = 2;
export const MAX_QUERY_LENGTH = 80;
/** Results per side (coming, past) when the caller names no limit, and the most it may ask for. */
export const DEFAULT_LIMIT = 30;
export const MAX_LIMIT = 100;
/**
 * How far a series is walked forwards and backwards from today. More than a year, so a
 * yearly date (a birthday, a tradition) always has its next one inside.
 */
export const SERIES_DAYS = 400;

/** One-off events have no horizon: they are found wherever they are. */
const FIRST_DAY = "1900-01-01";
const LAST_DAY = "2999-12-31";

export type SearchResult = {
  /** Still running or yet to come, the soonest first. */
  upcoming: Occurrence[];
  /** Over, the latest first. */
  past: Occurrence[];
  /** Whether either side was cut at the limit. */
  more: boolean;
};

/** The same folding as app.fold in SQL: lower case, umlauts spelled out, accents dropped. */
export function fold(text: string): string {
  return text
    // Composed first, so an umlaut typed as a letter and a mark is still an umlaut.
    .normalize("NFC")
    .replace(/[äÄ]/g, "ae").replace(/[öÖ]/g, "oe").replace(/[üÜ]/g, "ue")
    .replace(/ß/g, "ss")
    .normalize("NFD").replace(/[̀-ͯ]/g, "")
    .toLowerCase();
}

/** The folded words of a typed query. */
export function searchTerms(query: string): string[] {
  return fold(query.trim()).split(/\s+/).filter((term) => term !== "");
}

/** 0: `field` starts with `term`; 1: one of its words does; 2: it is inside a word. */
function kindOf(term: string, field: string): number | null {
  const at = field.indexOf(term);
  if (at < 0) return null;
  if (at === 0) return 0;
  return field.split(/[^a-z0-9]+/).some((word) => word.startsWith(term))
    ? 1
    : 2;
}

/**
 * How well `fields` answer `terms`, lower is better; null when a term is in none of them.
 * An earlier field beats a later one, and within a field its beginning beats the start of
 * a word, which beats the middle of one.
 */
export function searchRank(
  terms: string[],
  fields: (string | null | undefined)[],
): number | null {
  if (terms.length === 0) return null;
  // A missing field keeps its place: a note is a note whether or not there is a place.
  const folded = fields.map((f) => typeof f === "string" ? fold(f.trim()) : "");
  let total = 0;
  for (const term of terms) {
    let best: number | null = null;
    for (let i = 0; i < folded.length; i++) {
      const kind = folded[i] === "" ? null : kindOf(term, folded[i]);
      if (kind === null) continue;
      const score = i * 3 + kind;
      if (best === null || score < best) best = score;
      if (kind === 0) break;
    }
    if (best === null) return null;
    total += best;
  }
  return total;
}

const rankOf = (terms: string[], occ: Occurrence) =>
  searchRank(terms, [occ.title, occ.location, occ.description]);

/** Whether every term is in the title: those answers come before a match in a note. */
const inTitle = (terms: string[], occ: Occurrence) =>
  searchRank(terms, [occ.title]) !== null;

/**
 * The appointments that answer `query`, as seen on the local date `today` in `tz`.
 *
 * - A one-off event is found at any date.
 * - A series is one answer: its next date that matches, or the last one if none is to come
 *   (within SERIES_DAYS either way). A single date of a series that was renamed or moved
 *   elsewhere is matched by what it says itself, so "Turnier" finds the one training that
 *   became a tournament and not the others.
 * - An imported appointment (a subscribed calendar, already expanded when it was stored)
 *   is one answer per source event, by the same rule.
 * - Cancelled events and cancelled dates are never found.
 */
export function searchOccurrences(input: {
  query: string;
  events: EventRow[];
  overrides: OverrideRow[];
  external: ExternalOccurrenceRow[];
  today: string;
  tz: string;
  limit?: number;
}): SearchResult {
  const { events, overrides, external, today, tz } = input;
  const limit = Math.min(Math.max(input.limit ?? DEFAULT_LIMIT, 1), MAX_LIMIT);
  const terms = searchTerms(input.query);
  if (terms.length === 0) return { upcoming: [], past: [], more: false };

  // An override that says something of its own can make its date match where the series
  // does not, so its series is looked at too; the occurrences decide.
  const worded = new Set(
    overrides
      .filter((o) =>
        !o.is_cancelled && (o.title !== null || o.location !== null)
      )
      .map((o) => o.event_id),
  );
  const candidates = events.filter((ev) =>
    ev.status !== "cancelled" &&
    (worded.has(ev.id) ||
      searchRank(terms, [ev.title, ev.location, ev.description]) !== null)
  );
  const isSeries = (ev: EventRow) =>
    ev.rrule !== null || (ev.rdates?.length ?? 0) > 0;
  const singles = candidates.filter((ev) => !isSeries(ev));
  const series = candidates.filter(isSeries);
  const ids = new Set(candidates.map((ev) => ev.id));
  const own = overrides.filter((o) => ids.has(o.event_id));
  const matches = (occ: Occurrence) => rankOf(terms, occ) !== null;

  const found: Occurrence[] = expand(singles, own, FIRST_DAY, LAST_DAY, tz)
    .filter(matches);

  // Ascending by start, so the first coming and the last past one are at the ends.
  const coming = expand(series, own, today, addDays(today, SERIES_DAYS), tz)
    .filter(matches);
  const gone = expand(
    series,
    own,
    addDays(today, -SERIES_DAYS),
    addDays(today, -1),
    tz,
  )
    .filter(matches);
  found.push(...onePerSource(coming, gone));

  const imported = external
    .filter((row) => searchRank(terms, [row.title, row.location]) !== null)
    .map((row) => importedOccurrence(row, tz))
    .sort((a, b) => Date.parse(a.start) - Date.parse(b.start));
  found.push(...onePerSource(
    imported.filter((occ) => occ.local_end_date >= today),
    imported.filter((occ) => occ.local_end_date < today),
  ));

  const byTitleThen = (direction: 1 | -1) => (a: Occurrence, b: Occurrence) =>
    Number(inTitle(terms, b)) - Number(inTitle(terms, a)) ||
    direction * (Date.parse(a.start) - Date.parse(b.start)) ||
    a.title.localeCompare(b.title, "de") ||
    a.id.localeCompare(b.id);
  const upcoming = found
    .filter((occ) => occ.local_end_date >= today)
    .sort(byTitleThen(1));
  const past = found
    .filter((occ) => occ.local_end_date < today)
    .sort(byTitleThen(-1));
  return {
    upcoming: upcoming.slice(0, limit),
    past: past.slice(0, limit),
    more: upcoming.length > limit || past.length > limit,
  };
}

/**
 * One occurrence per source event (`event_id`): the first of `coming`, or for a source with
 * none to come the last of `gone`. Both lists ascending by start.
 */
function onePerSource(coming: Occurrence[], gone: Occurrence[]): Occurrence[] {
  const picked = new Map<string, Occurrence>();
  for (const occ of coming) {
    if (!picked.has(occ.event_id)) picked.set(occ.event_id, occ);
  }
  const last = new Map<string, Occurrence>();
  for (const occ of gone) {
    if (!picked.has(occ.event_id)) last.set(occ.event_id, occ);
  }
  return [...picked.values(), ...last.values()];
}
