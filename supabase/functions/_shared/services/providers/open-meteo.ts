// Open-Meteo (https://open-meteo.com): forecast, place search and climate, no key.
//
// Written on 2026-11-15 from the documentation listed in `docs`; the answers were checked
// against live calls (fixtures/open-meteo_*.json). Terms: the free API is for non-commercial use
// (private or non-profit use without subscriptions or advertising qualifies), data under
// CC BY 4.0, attribution required.
//
// Climate recipe and its cost (the reason for `budget.climate_per_hour`)
// ----------------------------------------------------------------------
// Open-Meteo has a "climate" API of CMIP6 projections; those are not normals and each request
// weighs ~1,800 calls on its docs page. Normals are instead built from the archive (ERA5
// reanalysis, `archive-api`): daily maximum and minimum temperature, precipitation sum and
// sunshine duration for the last FOUR full calendar years, folded into twelve monthly means
// (mean daily maximum and minimum; rain days = days with at least 1 mm, averaged per year;
// mean monthly precipitation; mean daily sunshine hours). Four years is a short normal, but
// it is the recent climate, and it keeps the request small.
//
// Weighting (pricing page and the maintainers' note "Weather Data for Multiple Locations At
// Once"): a request counts as nLocations x max(days / 14, 1) x max(variables / 10, 1) calls
// (the pricing page prints the 14-day / 10-variable thresholds; the blog post prints the same
// formula without the floor of 1). Limits of the free tier: 600 calls a minute, 5,000 an
// hour, 10,000 a day, 300,000 a month.
//   archive: 1,461 days, 4 variables  ->  105 calls (42 without the variable floor)
//   marine : 731 days, 1 variable     ->   53 calls (6 without the variable floor)
//   one climate fetch                 -> at most 158 calls (48 without the floors)
// The three ceilings follow from the three limits, each with room for the household's
// forecasts and place searches, which share the server's address:
//   climate_per_minute  3  ->   474 of   600 calls
//   climate_per_hour   20  -> 3,160 of 5,000 calls
//   climate_per_day    48  -> 7,584 of 10,000 calls
// Discovery therefore fills slowly the first time (three places a minute, twenty an hour) and
// is instant afterwards: the answers are cached for five years, for every household of the
// server. `per_day: 300` bounds one household's own calls (a climate fetch, a forecast or a
// place search each count as one).
//
// Sea temperature: the Marine API (`marine-api`) has `sea_surface_temperature` hourly (no
// daily aggregate). Its archive reaches back only to 2023 (a call for 2021 or 2022 returns
// null values; 2025 has a gap of a few days in January and February), so ONE extra request
// for the last two full years gives about 17,500 hourly values, folded into monthly means
// (the sea changes slowly from year to year; two years are enough for a family's decision). The point is snapped to the nearest sea cell; an answer whose cell is more
// than 50 km from the place, or that is all null (inland), gives no `sea`. The marine call is
// optional: if it fails, the climate is returned without `sea`.
import {
  type Climate,
  type ClimateMonth,
  type Forecast,
  type ForecastDay,
  type LatLon,
  type Places,
  type Provider,
  type ProviderContext,
  ProviderError,
} from "../types.ts";
import { coord, fetchJson, query } from "../http.ts";
import { arr, haversineKm, isNum, obj, round1, wmoToCode } from "../weather.ts";

const HOSTS = [
  "api.open-meteo.com",
  "geocoding-api.open-meteo.com",
  "archive-api.open-meteo.com",
  "marine-api.open-meteo.com",
];

/** Years of daily data behind the monthly means. */
export const CLIMATE_YEARS = 4;
/** Years of hourly sea values: the marine archive starts in 2023, two years keep the call small. */
export const SEA_YEARS = 2;
/** A month needs at least this many days (or hours, for the sea) to be reported. */
const MIN_DAYS_PER_MONTH = 20;
const MIN_HOURS_PER_MONTH = 48;

// ---------------------------------------------------------------- forecast

export function parseForecast(json: unknown): Forecast {
  const daily = obj(obj(json).daily);
  const time = arr(daily.time);
  const tmax = arr(daily.temperature_2m_max);
  const tmin = arr(daily.temperature_2m_min);
  const precip = daily.precipitation_sum === undefined ? [] : arr(daily.precipitation_sum);
  const prob = daily.precipitation_probability_max === undefined
    ? []
    : arr(daily.precipitation_probability_max);
  const codes = arr(daily.weather_code);
  if (time.length === 0) throw new ProviderError("no_data");
  if (tmax.length !== time.length || tmin.length !== time.length || codes.length !== time.length) {
    throw new ProviderError("bad_answer");
  }

  const days: ForecastDay[] = [];
  for (let i = 0; i < time.length; i++) {
    const date = time[i];
    const code = isNum(codes[i]) ? wmoToCode(codes[i] as number) : null;
    if (typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      throw new ProviderError("bad_answer");
    }
    if (!isNum(tmax[i]) || !isNum(tmin[i]) || code === null) continue; // a day without values
    const day: ForecastDay = {
      date,
      tmax: round1(tmax[i] as number),
      tmin: round1(tmin[i] as number),
      precip_mm: isNum(precip[i]) ? round1(precip[i] as number) : 0,
      code,
    };
    if (isNum(prob[i])) day.precip_prob = Math.min(100, Math.max(0, Math.round(prob[i] as number)));
    days.push(day);
  }
  if (days.length === 0) throw new ProviderError("no_data");
  return { days };
}

async function forecast(q: LatLon, ctx: ProviderContext): Promise<Forecast> {
  const url = "https://api.open-meteo.com/v1/forecast?" + query({
    latitude: coord(q.lat),
    longitude: coord(q.lon),
    daily: "temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,weather_code",
    timezone: "auto",
    forecast_days: 16,
  });
  return parseForecast(await fetchJson(ctx, url));
}

// ---------------------------------------------------------------- geocode

export function parseGeocode(json: unknown): Places {
  const body = obj(json);
  // With no match the API leaves `results` out altogether.
  if (body.results === undefined) return { places: [] };
  const places: Places["places"] = [];
  for (const raw of arr(body.results)) {
    const r = obj(raw);
    if (typeof r.name !== "string" || !isNum(r.latitude) || !isNum(r.longitude)) continue;
    const place: Places["places"][number] = {
      name: r.name,
      country: typeof r.country_code === "string" ? r.country_code.toUpperCase() : "",
      lat: r.latitude,
      lon: r.longitude,
    };
    if (typeof r.admin1 === "string" && r.admin1 !== "") place.admin = r.admin1;
    places.push(place);
  }
  return { places };
}

async function geocode(q: { q: string; lang: string }, ctx: ProviderContext): Promise<Places> {
  const url = "https://geocoding-api.open-meteo.com/v1/search?" +
    query({ name: q.q, count: 5, language: q.lang, format: "json" });
  return parseGeocode(await fetchJson(ctx, url));
}

// ---------------------------------------------------------------- climate

type Acc = {
  tmaxSum: number;
  tmaxN: number;
  tminSum: number;
  tminN: number;
  days: number;
  rainDays: number;
  precipSum: number;
  sunSum: number;
  sunN: number;
  years: Set<string>;
};

function emptyAcc(): Acc {
  return {
    tmaxSum: 0,
    tmaxN: 0,
    tminSum: 0,
    tminN: 0,
    days: 0,
    rainDays: 0,
    precipSum: 0,
    sunSum: 0,
    sunN: 0,
    years: new Set(),
  };
}

/** Twelve monthly means from the archive's daily answer. */
export function parseClimate(json: unknown): Climate {
  const daily = obj(obj(json).daily);
  const time = arr(daily.time);
  if (time.length === 0) throw new ProviderError("no_data");
  const tmax = arr(daily.temperature_2m_max);
  const tmin = arr(daily.temperature_2m_min);
  const precip = arr(daily.precipitation_sum);
  const sun = arr(daily.sunshine_duration);
  if ([tmax, tmin, precip, sun].some((a) => a.length !== time.length)) {
    throw new ProviderError("bad_answer");
  }

  const acc: Acc[] = Array.from({ length: 12 }, emptyAcc);
  let usable = 0;
  for (let i = 0; i < time.length; i++) {
    const date = time[i];
    if (typeof date !== "string" || !/^\d{4}-(0[1-9]|1[0-2])-\d{2}$/.test(date)) {
      throw new ProviderError("bad_answer");
    }
    const a = acc[Number(date.slice(5, 7)) - 1];
    if (isNum(tmax[i]) && isNum(tmin[i])) {
      a.tmaxSum += tmax[i] as number;
      a.tmaxN++;
      a.tminSum += tmin[i] as number;
      a.tminN++;
      a.days++;
      a.years.add(date.slice(0, 4));
      usable++;
    }
    if (isNum(precip[i])) {
      a.precipSum += precip[i] as number;
      if ((precip[i] as number) >= 1) a.rainDays++;
    }
    if (isNum(sun[i])) {
      a.sunSum += sun[i] as number;
      a.sunN++;
    }
  }
  if (usable === 0) throw new ProviderError("no_data");

  const months: ClimateMonth[] = [];
  for (let m = 0; m < 12; m++) {
    const a = acc[m];
    if (a.days < MIN_DAYS_PER_MONTH) throw new ProviderError("bad_answer");
    const years = a.years.size;
    const month: ClimateMonth = {
      month: m + 1,
      tmax: round1(a.tmaxSum / a.tmaxN),
      tmin: round1(a.tminSum / a.tminN),
      rain_days: round1(a.rainDays / years),
      precip_mm: Math.round(a.precipSum / years),
    };
    if (a.sunN >= MIN_DAYS_PER_MONTH) month.sun_hours = round1(a.sunSum / a.sunN / 3600);
    months.push(month);
  }
  return { months };
}

/** Monthly mean sea surface temperature (index 0 = January); null where too few values. */
export function parseSea(json: unknown, at: LatLon): (number | null)[] | null {
  const body = obj(json);
  if (isNum(body.latitude) && isNum(body.longitude)) {
    if (haversineKm(at, { lat: body.latitude, lon: body.longitude }) > 50) return null;
  }
  const hourly = obj(body.hourly);
  const time = arr(hourly.time);
  const sst = arr(hourly.sea_surface_temperature);
  if (sst.length !== time.length) throw new ProviderError("bad_answer");
  const sum = new Array<number>(12).fill(0);
  const n = new Array<number>(12).fill(0);
  for (let i = 0; i < time.length; i++) {
    const t = time[i];
    const v = sst[i];
    if (!isNum(t) || !isNum(v)) continue; // `timeformat=unixtime`; null where the sea has no value
    const m = new Date(t * 1000).getUTCMonth();
    sum[m] += v;
    n[m]++;
  }
  if (n.every((c) => c === 0)) return null; // inland: the grid has no sea value
  return sum.map((s, m) => n[m] >= MIN_HOURS_PER_MONTH ? round1(s / n[m]) : null);
}

/** The last full calendar year, and the first of the five before it ends. */
export function climateYears(now: Date): { first: number; last: number } {
  const last = now.getUTCFullYear() - 1;
  return { first: last - CLIMATE_YEARS + 1, last };
}

async function climate(q: LatLon, ctx: ProviderContext): Promise<Climate> {
  const { first, last } = climateYears(new Date());
  const at = { latitude: coord(q.lat), longitude: coord(q.lon) };
  const archive = fetchJson(
    ctx,
    "https://archive-api.open-meteo.com/v1/archive?" + query({
      ...at,
      start_date: `${first}-01-01`,
      end_date: `${last}-12-31`,
      daily: "temperature_2m_max,temperature_2m_min,precipitation_sum,sunshine_duration",
      timezone: "auto",
    }),
  );
  const marine = fetchJson(
    ctx,
    "https://marine-api.open-meteo.com/v1/marine?" + query({
      ...at,
      hourly: "sea_surface_temperature",
      start_date: `${last - SEA_YEARS + 1}-01-01`,
      end_date: `${last}-12-31`,
      timeformat: "unixtime",
    }),
  ).then((j) => parseSea(j, q)).catch(() => null); // the sea is optional

  let result: Climate;
  try {
    result = parseClimate(await archive);
  } catch (err) {
    await marine; // let the second request settle; its outcome does not matter
    throw err;
  }
  const sea = await marine;
  if (sea) {
    for (const m of result.months) {
      const v = sea[m.month - 1];
      if (v !== null) m.sea = v;
    }
  }
  return result;
}

// ---------------------------------------------------------------- the provider

export const openMeteo: Provider = {
  id: "open-meteo",
  name: "Open-Meteo",
  homepage: "https://open-meteo.com",
  key_url: null,
  needs_key: false,
  cost: "free",
  receives: ["coordinates", "search_text"],
  attribution: "Weather data by Open-Meteo.com (CC BY 4.0)",
  hosts: HOSTS,
  budget: { per_day: 300, climate_per_minute: 3, climate_per_hour: 20, climate_per_day: 48 },
  docs: [
    "https://open-meteo.com/en/docs (forecast API, WMO codes) read 2026-11-15",
    "https://open-meteo.com/en/docs/geocoding-api read 2026-11-15",
    "https://open-meteo.com/en/docs/historical-weather-api read 2026-11-15",
    "https://open-meteo.com/en/docs/marine-weather-api read 2026-11-15",
    "https://open-meteo.com/en/pricing (limits, call weighting) read 2026-11-15",
    "https://open-meteo.com/en/terms (non-commercial use, CC BY 4.0) read 2026-11-15",
    "https://openmeteo.substack.com/p/weather-data-for-multiple-locations (weighting formula) read 2026-11-15",
  ],
  forecast,
  geocode,
  climate,
  // The cheapest real call; the default would be the heavy climate fetch.
  test: async (ctx) => {
    await geocode({ q: "Lisbon", lang: "en" }, ctx);
  },
};
