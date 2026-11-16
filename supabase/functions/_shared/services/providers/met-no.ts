// MET Norway Locationforecast 2.0 (https://api.met.no), forecast only, no key.
//
// Written on 2026-11-15 from the documentation in `docs`; the parsing was checked against a
// live answer (fixtures/met-no_forecast.json). Terms: an identifying User-Agent on every
// request (the runner's fetch sets the module's own, see ../http.ts), at most 4 decimals in
// the coordinates (two are sent), no repeating of identical requests within 30 minutes
// (Nordic) or 3 hours (elsewhere; the runner caches a forecast for 3 hours), data under
// CC BY 4.0 with credit.
//
// From timeseries to days (the simplification)
// --------------------------------------------
// The answer is a list of UTC time points, hourly for the first days and every six hours
// after that, each with `next_6_hours` (symbol, `air_temperature_max/min`, precipitation)
// when it is available. A day is built from the NON-OVERLAPPING six-hour blocks that start at
// 00, 06, 12 and 18 UTC. The answer carries no time zone, so the place's local date is
// estimated from the longitude (one hour per 15 degrees, rounded): a block belongs to the
// date its estimated local start falls on. Daylight saving and political zones are ignored,
// so a block can be assigned to the neighbouring date at most a couple of hours off the real
// boundary. A day needs at least two blocks (the first day is usually the rest of today, the
// last one is dropped when only one block is left); its maximum and minimum are those of its
// blocks, precipitation is their sum, and the symbol is chosen by `dayCode` (weather.ts).
// No precipitation probability is offered by this API in the `complete` format.
import {
  type Forecast,
  type ForecastDay,
  type LatLon,
  type Provider,
  type ProviderContext,
  ProviderError,
} from "../types.ts";
import { coord, fetchJson, query } from "../http.ts";
import { arr, dayCode, isNum, obj, round1, type Slice } from "../weather.ts";

/** The kind of weather a MET symbol code stands for; null for one we do not know. */
export function symbolKind(code: string): Slice["kind"] | null {
  const s = code.replace(/_(day|night|polartwilight)$/, "");
  if (s.includes("thunder")) return "storm";
  if (s.includes("snow") || s.includes("sleet")) return "snow";
  if (s.includes("rain")) return "rain";
  if (s === "fog") return "fog";
  if (s === "clearsky" || s === "fair") return "clear";
  if (s === "partlycloudy") return "partly";
  if (s === "cloudy") return "cloudy";
  return null;
}

type Block = {
  date: string;
  localHour: number;
  tmax: number;
  tmin: number;
  precip: number;
  kind: Slice["kind"];
};

export function parseForecast(json: unknown, lon: number): Forecast {
  const props = obj(obj(json).properties);
  const series = arr(props.timeseries);
  if (series.length === 0) throw new ProviderError("no_data");
  const offsetH = Math.round(lon / 15);

  const blocks: Block[] = [];
  for (const raw of series) {
    const entry = obj(raw);
    if (typeof entry.time !== "string") throw new ProviderError("bad_answer");
    const t = Date.parse(entry.time);
    if (!Number.isFinite(t)) throw new ProviderError("bad_answer");
    const start = new Date(t);
    if (start.getUTCHours() % 6 !== 0 || start.getUTCMinutes() !== 0) continue;
    const next = obj(entry.data).next_6_hours;
    if (next === undefined) continue;
    const b = obj(next);
    const details = obj(b.details);
    const symbol = obj(b.summary).symbol_code;
    const kind = typeof symbol === "string" ? symbolKind(symbol) : null;
    if (kind === null || !isNum(details.air_temperature_max) || !isNum(details.air_temperature_min)) {
      continue;
    }
    const local = new Date(t + offsetH * 3600_000);
    blocks.push({
      date: local.toISOString().slice(0, 10),
      localHour: local.getUTCHours(),
      tmax: details.air_temperature_max,
      tmin: details.air_temperature_min,
      precip: isNum(details.precipitation_amount) ? details.precipitation_amount : 0,
      kind,
    });
  }

  const byDate = new Map<string, Block[]>();
  for (const b of blocks) byDate.set(b.date, [...(byDate.get(b.date) ?? []), b]);
  const days: ForecastDay[] = [];
  for (const [date, list] of [...byDate].sort(([a], [b]) => a < b ? -1 : 1)) {
    if (list.length < 2) continue;
    const precip = list.reduce((s, b) => s + b.precip, 0);
    days.push({
      date,
      tmax: round1(Math.max(...list.map((b) => b.tmax))),
      tmin: round1(Math.min(...list.map((b) => b.tmin))),
      precip_mm: round1(precip),
      code: dayCode(list, precip),
    });
  }
  if (days.length === 0) throw new ProviderError("no_data");
  return { days };
}

async function forecast(q: LatLon, ctx: ProviderContext): Promise<Forecast> {
  const url = "https://api.met.no/weatherapi/locationforecast/2.0/complete?" +
    query({ lat: coord(q.lat), lon: coord(q.lon) });
  return parseForecast(await fetchJson(ctx, url), q.lon);
}

export const metNo: Provider = {
  id: "met-no",
  name: "MET Norway",
  homepage: "https://api.met.no",
  key_url: null,
  needs_key: false,
  cost: "free",
  receives: ["coordinates"],
  attribution: "Weather data from MET Norway (api.met.no), CC BY 4.0",
  hosts: ["api.met.no"],
  budget: { per_day: 100 },
  docs: [
    "https://api.met.no/weatherapi/locationforecast/2.0/documentation read 2026-11-15",
    "https://developer.yr.no/doc/TermsOfService/ read 2026-11-15",
    "https://raw.githubusercontent.com/metno/weathericons/main/weather/legend.csv (symbol codes) read 2026-11-15",
  ],
  forecast,
};
