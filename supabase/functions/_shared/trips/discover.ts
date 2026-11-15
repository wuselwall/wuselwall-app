// Discovery (specs/30 "Discovery"): where is it warm and dry in a window, and how far is it?
//
// Candidates are the bundled catalogue plus the family's own ideas that have coordinates.
// Pure logic around an injected `Services` (../services/types.ts): the only way it reaches a
// provider is `services.ask`, which the runner has already opened for this caller, and it
// asks within the budget the runner reports. Climate is cached for years, so the answer fills
// up over a few requests: `pending` says how many candidates still wait for their values.
import {
  type Answer,
  type Climate,
  type ClimateMonth,
  ServiceError,
  type Services,
} from "../services/types.ts";
import { DESTINATIONS, type Lang, type Tag } from "./destinations.ts";

/** The most places one answer lists. */
export const MAX_PLACES = 80;
/** "Little rain": rain days a month (scaled to 30 days) up to this, else precipitation up to DRY_MM. */
export const DRY_RAIN_DAYS = 6;
export const DRY_MM = 50;
/** A window longer than this reads only its first days for the climate. */
export const MAX_CLIMATE_DAYS = 62;

export type Effort = "near" | "car" | "short" | "medium" | "long";

/** Upper bounds in km of each band but the last (specs/30: an estimate from the great circle). */
export const EFFORT_LIMITS: readonly [Effort, number][] = [
  ["near", 300],
  ["car", 800],
  ["short", 1500],
  ["medium", 4000],
];

const EFFORT_ORDER: readonly Effort[] = [
  "near",
  "car",
  "short",
  "medium",
  "long",
];

export type Filters = {
  temp_min?: number;
  temp_max?: number;
  dry?: boolean;
  sea_min?: number;
  tags?: Tag[];
  effort?: Effort;
};

/** A family idea with coordinates (api.trips rows where lat and lon are set). */
export type Idea = {
  trip_id: string;
  name: string;
  /** The catalogue key the idea was picked from, if any: the idea then replaces that entry. */
  destination_key: string | null;
  country: string | null;
  lat: number;
  lon: number;
};

export type DiscoverInput = {
  /** The window, inclusive 'YYYY-MM-DD'. */
  from: string;
  to: string;
  lang: Lang;
  filters: Filters;
  home: { lat: number; lon: number } | null;
  ideas: Idea[];
  /** The most climate fetches this call may make (the runner's budget caps it further). */
  fetchLimit: number;
};

export type WindowClimate = {
  tmax: number;
  tmin: number;
  rain_days?: number;
  sun_hours?: number;
  sea?: number;
};

export type DiscoveredPlace = {
  key?: string;
  trip_id?: string;
  name: string;
  country: string;
  lat: number;
  lon: number;
  tags: Tag[];
  km?: number;
  effort?: Effort;
  climate?: WindowClimate;
  fits: "yes" | "no" | "unknown";
};

export type DiscoverResult = {
  places: DiscoveredPlace[];
  pending: number;
  provider?: string;
  attribution?: string;
};

// ---------------------------------------------------------------- distance

const EARTH_RADIUS_KM = 6371;

/** The great-circle distance in km (haversine). */
export function distanceKm(
  a: { lat: number; lon: number },
  b: { lat: number; lon: number },
): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function effortOf(km: number): Effort {
  for (const [band, limit] of EFFORT_LIMITS) if (km <= limit) return band;
  return "long";
}

// ---------------------------------------------------------------- the window's climate

/** The days of each month the window touches, at most its first MAX_CLIMATE_DAYS days. */
export function monthDays(
  from: string,
  to: string,
): { month: number; days: number; monthLength: number }[] {
  const start = Date.parse(`${from}T00:00:00Z`);
  const end = Date.parse(`${to}T00:00:00Z`);
  const out: { month: number; days: number; monthLength: number }[] = [];
  if (!(end >= start)) return out;
  const total = Math.min(
    Math.round((end - start) / 86_400_000) + 1,
    MAX_CLIMATE_DAYS,
  );
  for (let i = 0; i < total; i++) {
    const day = new Date(start + i * 86_400_000);
    const month = day.getUTCMonth() + 1;
    const last = out[out.length - 1];
    if (last && last.month === month) {
      last.days++;
    } else {
      const monthLength = new Date(Date.UTC(day.getUTCFullYear(), month, 0))
        .getUTCDate();
      out.push({ month, days: 1, monthLength });
    }
  }
  return out;
}

type Weighted = WindowClimate & { precip30?: number };

const round1 = (n: number) => Math.round(n * 10) / 10;

/**
 * The climate of the window: the mean over its months weighted by the window's days in each.
 * Rain days and precipitation are scaled to 30 days (a month's own length differs). A field a
 * month lacks is averaged over the months that have it.
 */
export function windowClimate(
  climate: Climate,
  from: string,
  to: string,
): Weighted | null {
  const months = monthDays(from, to);
  const sums = new Map<string, { sum: number; weight: number }>();
  const add = (field: string, value: number | undefined, weight: number) => {
    if (typeof value !== "number" || !Number.isFinite(value)) return;
    const s = sums.get(field) ?? { sum: 0, weight: 0 };
    s.sum += value * weight;
    s.weight += weight;
    sums.set(field, s);
  };
  for (const { month, days, monthLength } of months) {
    const m: ClimateMonth | undefined = climate.months.find((c) =>
      c.month === month
    );
    if (!m) continue;
    const per30 = 30 / monthLength;
    add("tmax", m.tmax, days);
    add("tmin", m.tmin, days);
    add(
      "rain_days",
      m.rain_days === undefined ? undefined : m.rain_days * per30,
      days,
    );
    add(
      "precip30",
      m.precip_mm === undefined ? undefined : m.precip_mm * per30,
      days,
    );
    add("sun_hours", m.sun_hours, days);
    add("sea", m.sea, days);
  }
  const mean = (field: string) => {
    const s = sums.get(field);
    return s === undefined ? undefined : round1(s.sum / s.weight);
  };
  const tmax = mean("tmax");
  const tmin = mean("tmin");
  if (tmax === undefined || tmin === undefined) return null;
  const out: Weighted = { tmax, tmin };
  for (const field of ["rain_days", "sun_hours", "sea", "precip30"] as const) {
    const v = mean(field);
    if (v !== undefined) out[field] = v;
  }
  return out;
}

// ---------------------------------------------------------------- fit

/** Does the climate suit the filters? 'unknown' where a filter is set and the value missing. */
export function fitsFilters(
  filters: Filters,
  climate: Weighted | null,
): "yes" | "no" | "unknown" {
  let unknown = false;
  if (filters.temp_min !== undefined) {
    if (climate === null) unknown = true;
    else if (climate.tmax < filters.temp_min) return "no";
  }
  if (filters.temp_max !== undefined) {
    if (climate === null) unknown = true;
    else if (climate.tmax > filters.temp_max) return "no";
  }
  if (filters.dry === true) {
    if (climate === null) unknown = true;
    else if (climate.rain_days !== undefined) {
      if (climate.rain_days > DRY_RAIN_DAYS) return "no";
    } else if (climate.precip30 !== undefined) {
      if (climate.precip30 > DRY_MM) return "no";
    } else unknown = true;
  }
  if (filters.sea_min !== undefined) {
    if (climate === null || climate.sea === undefined) unknown = true;
    else if (climate.sea < filters.sea_min) return "no";
  }
  return unknown ? "unknown" : "yes";
}

// ---------------------------------------------------------------- candidates

type Candidate = {
  key?: string;
  trip_id?: string;
  name: string;
  country: string;
  lat: number;
  lon: number;
  tags: Tag[];
  km?: number;
  effort?: Effort;
};

/** The catalogue in `lang` and the ideas; an idea picked from the catalogue replaces its entry. */
export function candidates(
  lang: Lang,
  ideas: Idea[],
  home: { lat: number; lon: number } | null,
): Candidate[] {
  const out: Candidate[] = [];
  const replaced = new Map<string, Idea>();
  const loose: Idea[] = [];
  const catalogueKeys = new Set(DESTINATIONS.map((d) => d.key));
  for (const idea of ideas) {
    const key = idea.destination_key;
    if (key !== null && catalogueKeys.has(key) && !replaced.has(key)) {
      replaced.set(key, idea);
    } else loose.push(idea);
  }
  for (const d of DESTINATIONS) {
    const idea = replaced.get(d.key);
    out.push(
      idea
        ? {
          key: d.key,
          trip_id: idea.trip_id,
          name: idea.name,
          country: d.country,
          lat: idea.lat,
          lon: idea.lon,
          tags: d.tags,
        }
        : {
          key: d.key,
          name: d.names[lang],
          country: d.country,
          lat: d.lat,
          lon: d.lon,
          tags: d.tags,
        },
    );
  }
  for (const idea of loose) {
    out.push({
      trip_id: idea.trip_id,
      name: idea.name,
      country: idea.country ?? "",
      lat: idea.lat,
      lon: idea.lon,
      tags: [],
    });
  }
  if (home !== null) {
    for (const c of out) {
      c.km = Math.round(distanceKm(home, c) / 10) * 10;
      c.effort = effortOf(c.km);
    }
  }
  return out;
}

/**
 * The family's own ideas first, then nearer, then by name. An idea is what the family already
 * wants: it gets its climate values first and is never pushed out of a capped answer by the
 * bundled catalogue (found by the first run against a real stack, 2026-11-15).
 */
function byIdeaThenDistanceThenName(lang: string) {
  return (a: Candidate, b: Candidate) =>
    Number(b.trip_id !== undefined) - Number(a.trip_id !== undefined) ||
    (a.km ?? Infinity) - (b.km ?? Infinity) ||
    a.name.localeCompare(b.name, lang);
}

// ---------------------------------------------------------------- discover

export async function discover(
  input: DiscoverInput,
  services: Services,
): Promise<DiscoverResult> {
  const { filters } = input;
  const wantedTags = filters.tags ?? [];
  const maxEffort = filters.effort !== undefined && input.home !== null
    ? EFFORT_ORDER.indexOf(filters.effort)
    : -1;

  // The cheap filters first: they decide which places are worth a climate value.
  const pool = candidates(input.lang, input.ideas, input.home).filter((c) =>
    wantedTags.every((t) => c.tags.includes(t)) &&
    (maxEffort < 0 || EFFORT_ORDER.indexOf(c.effort!) <= maxEffort)
  );

  const climates = new Map<Candidate, Climate>();
  const providers: string[] = [];
  const attributions: string[] = [];
  const note = (answer: Answer<"climate">) => {
    if (!providers.includes(answer.provider)) providers.push(answer.provider);
    if (!attributions.includes(answer.attribution)) {
      attributions.push(answer.attribution);
    }
  };

  if (services.offers("climate").length > 0 && pool.length > 0) {
    const cached = await services.cached(
      "climate",
      pool.map((c) => ({ lat: c.lat, lon: c.lon })),
    );
    pool.forEach((c, i) => {
      const answer = cached[i];
      if (answer) {
        climates.set(c, answer.data);
        note(answer);
      }
    });

    const missing = pool.filter((c) => !climates.has(c)).sort(
      byIdeaThenDistanceThenName(input.lang),
    );
    const budget = Math.max(
      0,
      Math.min(
        input.fetchLimit,
        missing.length > 0 ? await services.climateBudget() : 0,
      ),
    );
    for (const c of missing.slice(0, budget)) {
      try {
        const answer = await services.ask("climate", {
          lat: c.lat,
          lon: c.lon,
        });
        climates.set(c, answer.data);
        note(answer);
      } catch (err) {
        if (!(err instanceof ServiceError)) throw err;
        // This place stays unknown. Off or at the ceiling: the next ones would fail the same.
        if (err.code === "service_limit" || err.code === "service_off") break;
      }
    }
  }

  const places: DiscoveredPlace[] = [];
  let pending = 0;
  for (const c of pool) {
    const climate = climates.get(c);
    if (climate === undefined && services.offers("climate").length > 0) {
      pending++;
    }
    const weighted = climate === undefined
      ? null
      : windowClimate(climate, input.from, input.to);
    const fits = fitsFilters(filters, weighted);
    if (fits === "no") continue;
    const { key, trip_id, name, country, lat, lon, tags, km, effort } = c;
    places.push({
      ...(key === undefined ? {} : { key }),
      ...(trip_id === undefined ? {} : { trip_id }),
      name,
      country,
      lat,
      lon,
      tags,
      ...(km === undefined ? {} : { km, effort }),
      ...(weighted === null ? {} : {
        climate: {
          tmax: weighted.tmax,
          tmin: weighted.tmin,
          ...(weighted.rain_days === undefined
            ? {}
            : { rain_days: weighted.rain_days }),
          ...(weighted.sun_hours === undefined
            ? {}
            : { sun_hours: weighted.sun_hours }),
          ...(weighted.sea === undefined ? {} : { sea: weighted.sea }),
        },
      }),
      fits,
    });
  }

  places.sort((a, b) =>
    Number(b.fits === "yes") - Number(a.fits === "yes") ||
    Number(b.trip_id !== undefined) - Number(a.trip_id !== undefined) ||
    (a.km ?? Infinity) - (b.km ?? Infinity) ||
    a.name.localeCompare(b.name, input.lang)
  );

  return {
    places: places.slice(0, MAX_PLACES),
    pending,
    ...(providers.length === 0 ? {} : {
      provider: providers[0],
      attribution: attributions.join(" · "),
    }),
  };
}
