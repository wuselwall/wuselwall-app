// The OpenHolidays API (https://openholidaysapi.org, data under the ODbL): the regions and
// the public and school holidays of a country, as rows of the public cache tables
// app.region, app.holiday_feed and app.holiday_feed_sync (specs/21 and the holidays
// package). The apps never call this API; holidays-sync fills the cache and the apps
// read it through api views, so no household ever talks to a third party (NFR-9).
//
// Everything here is pure except fetchCountry, which takes the fetch implementation as a
// parameter so the tests can replace the network.

export type HolidayKind = "public" | "school";

/** A row of app.region, without fetched_at (the sync stamps it when it writes). */
export type RegionRow = {
  code: string;
  country: string;
  parent_code: string | null;
  level: 1 | 2 | 3 | 4;
  category: string;
  short_name: string;
  names: Record<string, string>;
};

/** A row of app.holiday_feed, without fetched_at. */
export type HolidayFeedRow = {
  id: string;
  country: string;
  kind: HolidayKind;
  starts_on: string;
  ends_on: string;
  names: Record<string, string>;
  nationwide: boolean;
  subdivisions: string[];
};

export type SyncWindow = { from: string; to: string };

export type FetchedCountry = {
  country: string;
  regions: RegionRow[];
  publicHolidays: HolidayFeedRow[];
  schoolHolidays: HolidayFeedRow[];
};

/**
 * A failed request or an unusable answer. `reason` is a stable word for the cache's
 * last_error column ("http", "timeout", "network", "invalid_json", "invalid_shape");
 * `status` is the HTTP status when there was one. The URL is never part of it.
 */
export class OpenHolidaysError extends Error {
  constructor(
    readonly reason: string,
    readonly status: number | null = null,
  ) {
    super(
      status === null
        ? `openholidays: ${reason}`
        : `openholidays: ${reason} (${status})`,
    );
    this.name = "OpenHolidaysError";
  }

  /** The text stored in holiday_feed_sync.last_error, e.g. "http 503". */
  get lastError(): string {
    return this.status === null ? this.reason : `${this.reason} ${this.status}`;
  }
}

const BASE_URL = "https://openholidaysapi.org";
const TIMEOUT_MS = 15000;
const USER_AGENT = "WuselWall holidays-sync (+https://wuselwall.app)";
const COUNTRY = /^[A-Z]{2}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const MAX_LEVEL = 4;

type JsonObject = Record<string, unknown>;

function isObject(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function invalidShape(): never {
  throw new OpenHolidaysError("invalid_shape");
}

/** True for a two-letter ISO 3166 country code as the API expects it (e.g. "CH"). */
export function isCountry(value: unknown): value is string {
  return typeof value === "string" && COUNTRY.test(value);
}

/** The language-keyed names of a node, lower-case keys; the first text per language wins. */
function namesOf(entries: unknown): Record<string, string> {
  const names: Record<string, string> = {};
  if (!Array.isArray(entries)) return names;
  for (const entry of entries) {
    if (!isObject(entry)) continue;
    const language = entry.language;
    const text = entry.text;
    if (typeof language !== "string" || typeof text !== "string") continue;
    const key = language.toLowerCase();
    if (!(key in names)) names[key] = text;
  }
  return names;
}

/**
 * The subdivision trees of a country (GET /Subdivisions) as flat region rows. Level is the
 * depth, the roots being level 1; parent_code is the parent's code, null at the top.
 * Category is the first category text (e.g. "Kanton", "Bezirk", "Gemeinde").
 */
export function flattenSubdivisions(
  country: string,
  json: unknown,
): RegionRow[] {
  if (!Array.isArray(json)) invalidShape();
  const rows: RegionRow[] = [];

  const walk = (nodes: unknown[], depth: number, parent: string | null) => {
    if (depth > MAX_LEVEL) invalidShape();
    for (const node of nodes) {
      if (!isObject(node) || typeof node.code !== "string") invalidShape();
      const category =
        Array.isArray(node.category) && node.category.length > 0 &&
          isObject(node.category[0]) &&
          typeof node.category[0].text === "string"
          ? node.category[0].text
          : "";
      rows.push({
        code: node.code,
        country,
        parent_code: parent,
        level: depth as RegionRow["level"],
        category,
        short_name: typeof node.shortName === "string" ? node.shortName : "",
        names: namesOf(node.name),
      });
      if (node.children !== undefined) {
        if (!Array.isArray(node.children)) invalidShape();
        walk(node.children, depth + 1, node.code);
      }
    }
  };

  walk(json, 1, null);
  return rows;
}

/**
 * The codes the cache can store: the check on app.region.code (20261019100000). OpenHolidays
 * writes some codes with umlauts (AT-KÄ, CH-BE-SL-RÜ).
 */
const REGION_CODE = /^[A-Z]{2}(-[A-Z0-9ÄÖÜ]{1,6}){1,4}$/;

/**
 * The rows the cache can store, and how many it cannot: a code outside the cache's pattern
 * (a character the check does not know yet) or a level that is not the code's depth. One odd
 * code must not fail the whole country's write; it is left out, and the sync logs the count.
 */
export function storableRegions(
  rows: RegionRow[],
): { rows: RegionRow[]; dropped: number } {
  const kept = rows.filter((r) =>
    REGION_CODE.test(r.code) &&
    r.code.split("-")[0] === r.country &&
    r.code.split("-").length - 1 === r.level
  );
  return { rows: kept, dropped: rows.length - kept.length };
}

/**
 * The public or school holidays of a country (GET /PublicHolidays, /SchoolHolidays) as
 * feed rows. Entries without an id or with a missing or malformed date are skipped. The
 * kind comes from the endpoint asked, not from the entry's type (the public endpoint also
 * returns "Optional" days, which stay public).
 */
export function parseHolidays(
  country: string,
  kind: HolidayKind,
  json: unknown,
): HolidayFeedRow[] {
  if (!Array.isArray(json)) invalidShape();
  const rows: HolidayFeedRow[] = [];
  for (const entry of json) {
    if (!isObject(entry)) continue;
    const { id, startDate, endDate } = entry;
    if (typeof id !== "string" || id === "") continue;
    if (typeof startDate !== "string" || !DATE.test(startDate)) continue;
    if (typeof endDate !== "string" || !DATE.test(endDate)) continue;
    const subdivisions: string[] = [];
    if (Array.isArray(entry.subdivisions)) {
      for (const s of entry.subdivisions) {
        if (isObject(s) && typeof s.code === "string") {
          subdivisions.push(s.code);
        }
      }
    }
    rows.push({
      id,
      country,
      kind,
      starts_on: startDate,
      ends_on: endDate,
      names: namesOf(entry.name),
      nationwide: entry.nationwide === true,
      subdivisions,
    });
  }
  return rows;
}

/**
 * The window a sync asks for: 1 January of the previous year to 31 December of the next
 * year, three years in all (the API accepts at most three). Years are taken in UTC so the
 * window does not depend on the server's timezone.
 */
export function syncWindow(today: Date): SyncWindow {
  const year = today.getUTCFullYear();
  return { from: `${year - 1}-01-01`, to: `${year + 1}-12-31` };
}

/** The URL of one endpoint, query parameters in the API's own names. */
export function endpointUrl(
  path: "Subdivisions" | "PublicHolidays" | "SchoolHolidays",
  country: string,
  window?: SyncWindow,
): string {
  const url = new URL(`${BASE_URL}/${path}`);
  url.searchParams.set("countryIsoCode", country);
  if (window) {
    url.searchParams.set("validFrom", window.from);
    url.searchParams.set("validTo", window.to);
  }
  return url.toString();
}

async function getJson(
  fetchImpl: typeof fetch,
  url: string,
): Promise<unknown> {
  let response: Response;
  try {
    response = await fetchImpl(url, {
      headers: {
        Accept: "application/json",
        "User-Agent": USER_AGENT,
      },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (err) {
    const name = (err as { name?: unknown })?.name;
    throw new OpenHolidaysError(
      name === "TimeoutError" || name === "AbortError" ? "timeout" : "network",
    );
  }
  if (!response.ok) {
    // Drain the body so the connection can be reused; its content is not needed.
    await response.body?.cancel();
    throw new OpenHolidaysError("http", response.status);
  }
  try {
    return await response.json();
  } catch {
    throw new OpenHolidaysError("invalid_json");
  }
}

/**
 * Fetches a country's regions, public and school holidays for the window. The three
 * requests run in parallel; if any fails the whole country fails (the caller then writes
 * nothing, so a partial answer can never prune the cache).
 */
export async function fetchCountry(
  country: string,
  window: SyncWindow,
  fetchImpl: typeof fetch = fetch,
): Promise<FetchedCountry> {
  if (!isCountry(country)) throw new OpenHolidaysError("invalid_country");
  const [subdivisions, publicJson, schoolJson] = await Promise.all([
    getJson(fetchImpl, endpointUrl("Subdivisions", country)),
    getJson(fetchImpl, endpointUrl("PublicHolidays", country, window)),
    getJson(fetchImpl, endpointUrl("SchoolHolidays", country, window)),
  ]);
  return {
    country,
    regions: flattenSubdivisions(country, subdivisions),
    publicHolidays: parseHolidays(country, "public", publicJson),
    schoolHolidays: parseHolidays(country, "school", schoolJson),
  };
}

/**
 * The distinct countries behind a list of region codes ("CH-ZH" → "CH"), valid ones only,
 * sorted. Codes without a valid country prefix are dropped.
 */
export function countriesFromRegions(codes: string[]): string[] {
  const found = new Set<string>();
  for (const code of codes) {
    if (typeof code !== "string") continue;
    const prefix = code.split("-")[0];
    if (isCountry(prefix)) found.add(prefix);
  }
  return [...found].sort();
}

/**
 * Does a holiday of `country` (nationwide, or for these subdivisions) apply to `region`?
 * The same rule as app.region_covers in SQL: the same country, and either nationwide or the
 * region equals a subdivision code or starts with it and a dash ("CH-ZH" covers
 * "CH-ZH-ZH-ZH", "CH-AG" does not cover "CH-AGX").
 */
export function regionCovers(
  region: string,
  country: string,
  nationwide: boolean,
  subdivisions: string[],
): boolean {
  if (region.split("-")[0] !== country) return false;
  if (nationwide) return true;
  return subdivisions.some((s) => region === s || region.startsWith(`${s}-`));
}

/**
 * The name of a holiday in a language: the language of the locale ("de-DE" → "de"), else
 * German, else the first name there is. "" when the holiday has no names at all.
 */
export function holidayName(
  names: Record<string, string>,
  lang: string,
): string {
  const base = lang.split(/[-_]/)[0].toLowerCase();
  return names[base] ?? names.de ?? Object.values(names)[0] ?? "";
}
