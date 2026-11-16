// OpenWeather (https://openweathermap.org), forecast and place search, with the family's own
// key (the free plan: 60 calls a minute, 1,000,000 a month; both APIs below are on it).
//
// Written on 2026-11-15 from the documentation in `docs`. NOT called live (no key): the
// fixtures follow the documented structure. The key travels as the `appid` query parameter,
// which is the API's only way; therefore no error of this file ever carries the URL (all
// failures are ProviderError codes, see ../http.ts).
//
// From 3-hour steps to days (the simplification)
// ----------------------------------------------
// `forecast` returns 40 steps of three hours (5 days). The step times are Unix UTC and
// `city.timezone` is the place's offset in seconds, so a step's local date is exact for the
// offset in force now. A day needs at least three steps (the first and last day are partial and
// are dropped when they have fewer); its maximum and minimum are those of `main.temp_max` and
// `main.temp_min` over its steps, precipitation is the sum of `rain.3h` and `snow.3h`, the
// probability is the highest `pop`, and the symbol comes from the condition ids (2xx storm,
// 6xx snow, 3xx and 5xx rain, 701 and 741 fog, 800 clear, 801-802 partly, 803-804 cloudy)
// through `dayCode` (weather.ts). Five days is all the free plan gives.
import {
  type Forecast,
  type ForecastDay,
  type LatLon,
  type Places,
  type Provider,
  type ProviderContext,
  ProviderError,
} from "../types.ts";
import { coord, fetchJson, query } from "../http.ts";
import { arr, dayCode, isNum, localDate, localHour, obj, round1, type Slice } from "../weather.ts";

/** The kind of weather a condition id stands for; null when it says nothing about the sky. */
export function conditionKind(id: number): Slice["kind"] | null {
  if (id >= 200 && id <= 232) return "storm";
  if (id >= 300 && id <= 531) return "rain";
  if (id >= 600 && id <= 622) return "snow";
  if (id === 701 || id === 741) return "fog";
  if (id === 800) return "clear";
  if (id === 801 || id === 802) return "partly";
  if (id === 803 || id === 804) return "cloudy";
  return null;
}

type Step = { date: string; slice: Slice; max: number; min: number; precip: number; pop: number | null };

export function parseForecast(json: unknown): Forecast {
  const body = obj(json);
  const list = arr(body.list);
  if (list.length === 0) throw new ProviderError("no_data");
  const offset = isNum(obj(body.city).timezone) ? obj(body.city).timezone as number : 0;

  const steps: Step[] = [];
  for (const raw of list) {
    const e = obj(raw);
    const main = obj(e.main);
    if (!isNum(e.dt) || !isNum(main.temp_max) || !isNum(main.temp_min)) {
      throw new ProviderError("bad_answer");
    }
    const weather = Array.isArray(e.weather) && e.weather.length > 0 ? obj(e.weather[0]) : {};
    const kind = isNum(weather.id) ? conditionKind(weather.id) : null;
    const rain = e.rain === undefined ? 0 : obj(e.rain)["3h"];
    const snow = e.snow === undefined ? 0 : obj(e.snow)["3h"];
    steps.push({
      date: localDate(e.dt, offset),
      slice: { kind: kind ?? "cloudy", localHour: localHour(e.dt, offset) },
      max: main.temp_max,
      min: main.temp_min,
      precip: (isNum(rain) ? rain : 0) + (isNum(snow) ? snow : 0),
      pop: isNum(e.pop) ? e.pop : null,
    });
  }

  const byDate = new Map<string, Step[]>();
  for (const s of steps) byDate.set(s.date, [...(byDate.get(s.date) ?? []), s]);
  const days: ForecastDay[] = [];
  for (const [date, group] of [...byDate].sort(([a], [b]) => a < b ? -1 : 1)) {
    if (group.length < 3) continue;
    const precip = group.reduce((sum, s) => sum + s.precip, 0);
    const day: ForecastDay = {
      date,
      tmax: round1(Math.max(...group.map((s) => s.max))),
      tmin: round1(Math.min(...group.map((s) => s.min))),
      precip_mm: round1(precip),
      code: dayCode(group.map((s) => s.slice), precip),
    };
    const pops = group.map((s) => s.pop).filter((p): p is number => p !== null);
    if (pops.length > 0) day.precip_prob = Math.min(100, Math.round(Math.max(...pops) * 100));
    days.push(day);
  }
  if (days.length === 0) throw new ProviderError("no_data");
  return { days };
}

async function forecast(q: LatLon, ctx: ProviderContext): Promise<Forecast> {
  const url = "https://api.openweathermap.org/data/2.5/forecast?" + query({
    lat: coord(q.lat),
    lon: coord(q.lon),
    units: "metric",
    appid: ctx.key ?? "",
  });
  return parseForecast(await fetchJson(ctx, url, {}, { keyed: true }));
}

export function parseGeocode(json: unknown, lang: string): Places {
  const places: Places["places"] = [];
  for (const raw of arr(json)) {
    const r = obj(raw);
    if (typeof r.name !== "string" || !isNum(r.lat) || !isNum(r.lon)) continue;
    const local = r.local_names === undefined ? {} : obj(r.local_names);
    const localised = local[lang];
    const place: Places["places"][number] = {
      name: typeof localised === "string" && localised !== "" ? localised : r.name,
      country: typeof r.country === "string" ? r.country.toUpperCase() : "",
      lat: r.lat,
      lon: r.lon,
    };
    if (typeof r.state === "string" && r.state !== "") place.admin = r.state;
    places.push(place);
  }
  return { places };
}

async function geocode(q: { q: string; lang: string }, ctx: ProviderContext): Promise<Places> {
  const url = "https://api.openweathermap.org/geo/1.0/direct?" +
    query({ q: q.q, limit: 5, appid: ctx.key ?? "" });
  return parseGeocode(await fetchJson(ctx, url, {}, { keyed: true }), q.lang);
}

export const openWeatherMap: Provider = {
  id: "openweathermap",
  name: "OpenWeather",
  homepage: "https://openweathermap.org",
  key_url: "https://home.openweathermap.org/api_keys",
  needs_key: true,
  cost: "free_key",
  receives: ["coordinates", "search_text"],
  attribution: "Weather data from OpenWeather (openweathermap.org), ODbL",
  hosts: ["api.openweathermap.org"],
  budget: { per_day: 300 },
  docs: [
    "https://openweathermap.org/forecast5 read 2026-11-15",
    "https://openweathermap.org/api/geocoding-api read 2026-11-15",
    "https://openweathermap.org/weather-conditions read 2026-11-15",
    "https://openweathermap.org/price (free plan limits) read 2026-11-15",
  ],
  forecast,
  geocode,
};
