// Opt-in services (ADR-022, specs/30 "Services"): the contract between a provider plug-in,
// the runner that asks the household's providers in order, and the functions that use it
// (`services`, `trips`).
//
// A provider is one file in ./providers/ that exports a `Provider`. It declares what it can do
// and implements those capabilities with the injected `fetch`; it never reads the environment,
// the database or a host a household typed. The runner owns the household's choice, the keys,
// the cache and the call budgets.

export type Capability = "climate" | "forecast" | "geocode" | "route" | "map";

export const CAPABILITIES: readonly Capability[] = ["climate", "forecast", "geocode", "route", "map"];

/** What a provider is sent. Shown to the guardian before the provider is switched on. */
export type Receives = "coordinates" | "search_text" | "home_coordinates";

export type Cost = "free" | "free_key" | "paid_key";

export type LatLon = { lat: number; lon: number };

// ---------------------------------------------------------------- answers

/** One month of what is typical at a place. Temperatures in °C, one decimal at most. */
export type ClimateMonth = {
  month: number; // 1–12
  tmax: number; // mean daily maximum
  tmin: number; // mean daily minimum
  rain_days?: number; // days with at least 1 mm
  precip_mm?: number;
  sun_hours?: number; // mean hours of sunshine a day
  sea?: number; // sea surface temperature; only where the provider has it for this point
};

/** Twelve months, month 1 first. */
export type Climate = { months: ClimateMonth[] };

export type WeatherCode = "clear" | "partly" | "cloudy" | "fog" | "rain" | "snow" | "storm";

export type ForecastDay = {
  date: string; // YYYY-MM-DD, the place's own date
  tmax: number;
  tmin: number;
  precip_mm: number;
  precip_prob?: number; // 0–100
  code: WeatherCode;
};

export type Forecast = { days: ForecastDay[] };

export type Place = {
  name: string;
  country: string; // ISO 3166-1 alpha-2, upper case; '' when unknown
  admin?: string; // region or state, for telling two places of one name apart
  lat: number;
  lon: number;
};

export type Places = { places: Place[] };

export type Route = { km: number; minutes: number };

export type MapImage = { image_base64: string; mime: string };

// ---------------------------------------------------------------- questions

export type ClimateQuery = LatLon;
export type ForecastQuery = LatLon;
export type GeocodeQuery = { q: string; lang: string };
export type RouteQuery = { from: LatLon; to: LatLon };
export type MapQuery = LatLon & { zoom: number; width: number; height: number };

export type QueryOf = {
  climate: ClimateQuery;
  forecast: ForecastQuery;
  geocode: GeocodeQuery;
  route: RouteQuery;
  map: MapQuery;
};

export type AnswerOf = {
  climate: Climate;
  forecast: Forecast;
  geocode: Places;
  route: Route;
  map: MapImage;
};

// ---------------------------------------------------------------- a provider

/** What a plug-in gets for one call. `key` is null for a provider that needs none. */
export type ProviderContext = {
  key: string | null;
  fetch: typeof fetch;
  /** Aborts the call; the runner sets a timeout. */
  signal: AbortSignal;
};

/**
 * A provider's failure with a short code that may be stored and shown: `http_<status>`,
 * `timeout`, `unauthorized` (the key was refused), `quota`, `bad_answer`, `no_data` (the
 * provider has nothing for this point; the next provider is asked, nothing is recorded as an
 * error).
 */
export class ProviderError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "ProviderError";
  }
}

export type Provider = {
  /** ^[a-z0-9-]{2,40}$, the value stored in app.service_provider.provider. */
  id: string;
  /** The provider's own name; not translated. */
  name: string;
  homepage: string;
  /** Where a family gets a key; null when none is needed. */
  key_url: string | null;
  needs_key: boolean;
  cost: Cost;
  receives: Receives[];
  /** The line the provider's terms ask to be shown with its data. */
  attribution: string;
  /** Every host this file contacts. Https only. The runner refuses any other. */
  hosts: string[];
  /** Polite ceilings the runner enforces: calls a day per household, climate fetches an hour per server. */
  budget: { per_day: number; climate_per_hour?: number };
  /** The documentation pages this file was written from, with the date they were read. */
  docs: string[];

  climate?: (q: ClimateQuery, ctx: ProviderContext) => Promise<Climate>;
  forecast?: (q: ForecastQuery, ctx: ProviderContext) => Promise<Forecast>;
  geocode?: (q: GeocodeQuery, ctx: ProviderContext) => Promise<Places>;
  route?: (q: RouteQuery, ctx: ProviderContext) => Promise<Route>;
  map?: (q: MapQuery, ctx: ProviderContext) => Promise<MapImage>;
  /** One small real call that proves the key works; defaults to the first capability with a fixed query. */
  test?: (ctx: ProviderContext) => Promise<void>;
};

/** The capabilities a provider implements. */
export function capabilitiesOf(p: Provider): Capability[] {
  return CAPABILITIES.filter((c) => typeof p[c] === "function");
}

// ---------------------------------------------------------------- the runner

/** Why the runner has no answer. The functions turn these into `{error: code}`. */
export type ServiceErrorCode =
  | "service_off" // no enabled provider offers the capability
  | "service_key_missing" // the only candidates need a key that is not stored
  | "service_limit" // every candidate is at its ceiling
  | "service_failed"; // every candidate failed

export class ServiceError extends Error {
  constructor(readonly code: ServiceErrorCode) {
    super(code);
    this.name = "ServiceError";
  }
}

export type Answer<C extends Capability> = {
  data: AnswerOf[C];
  provider: string;
  attribution: string;
  /** True when the answer came from app.service_cache and no provider was contacted. */
  cached: boolean;
};

/**
 * Asks the household's providers. Built once per request by `openServices` (./runner.ts) after
 * `api.service_request` ran as the caller; a function that only holds a `Services` cannot
 * contact a provider for a caller the database refused.
 */
export type Services = {
  /** The enabled providers of the household that offer the capability, in the household's order. */
  offers(capability: Capability): string[];
  /** Throws ServiceError. */
  ask<C extends Capability>(capability: C, query: QueryOf[C]): Promise<Answer<C>>;
  /**
   * Cached answers only, for many questions at once (discovery): no provider is contacted.
   * The result has one entry per query, null where nothing is cached.
   */
  cached<C extends Capability>(capability: C, queries: QueryOf[C][]): Promise<(Answer<C> | null)[]>;
  /**
   * How many more climate fetches the first offering provider's hourly budget allows now;
   * 0 when no provider offers climate.
   */
  climateBudget(): Promise<number>;
};

/** The cache key of a question: coordinates rounded to two decimals, text folded. */
export function cacheKey<C extends Capability>(capability: C, provider: string, query: QueryOf[C]): string {
  const r = (n: number) => (Math.round(n * 100) / 100).toFixed(2);
  const at = (p: LatLon) => `${r(p.lat)},${r(p.lon)}`;
  switch (capability) {
    case "climate":
    case "forecast":
      return `${capability}:${provider}:${at(query as LatLon)}`;
    case "geocode": {
      const g = query as GeocodeQuery;
      return `geocode:${provider}:${g.lang}:${g.q.trim().toLowerCase().replace(/\s+/g, " ")}`;
    }
    case "route": {
      const q = query as RouteQuery;
      return `route:${provider}:${at(q.from)}>${at(q.to)}`;
    }
    default: {
      const m = query as MapQuery;
      return `map:${provider}:${at(m)}:${m.zoom}:${m.width}x${m.height}`;
    }
  }
}

/** Seconds an answer is kept (specs/30 "Services"). */
export const CACHE_TTL_SECONDS: Record<Capability, number> = {
  climate: 5 * 365 * 24 * 3600,
  geocode: 90 * 24 * 3600,
  route: 30 * 24 * 3600,
  map: 30 * 24 * 3600,
  forecast: 3 * 3600,
};
