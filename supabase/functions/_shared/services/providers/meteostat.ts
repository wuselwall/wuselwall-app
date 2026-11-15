// Meteostat (https://meteostat.net), climate normals for a point, with the family's own key.
//
// Written on 2026-11-15 from the documentation in `docs`. NOT called live (no key); the
// fixture follows the documented structure. The documented JSON API is served through
// RapidAPI: `GET https://meteostat.p.rapidapi.com/point/normals?lat=&lon=` with the headers
// `x-rapidapi-host` and `x-rapidapi-key` (the key never goes into the URL). `data` holds one
// object per month (`month`, `tavg`, `tmin`, `tmax`, `prcp` in mm, `tsun` in minutes a month,
// `start` and `end` of the reference period); with several periods in the answer the one that
// ends latest and has all twelve months is used. The free plan has a hard limit of 500
// requests a month: `per_day: 15` keeps one household under it.
//
// Not offered by this API: rain days (omitted). Sunshine is `tsun` / 60 / days of the month.
// Data licence CC BY 4.0, credit "Meteostat and its data providers".
import {
  type Climate,
  type ClimateMonth,
  type LatLon,
  type Provider,
  type ProviderContext,
  ProviderError,
} from "../types.ts";
import { coord, fetchJson, query } from "../http.ts";
import { arr, isNum, obj, round1 } from "../weather.ts";

const DAYS_IN_MONTH = [31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

export function parseNormals(json: unknown): Climate {
  const data = arr(obj(json).data);
  if (data.length === 0) throw new ProviderError("no_data");

  // Group by reference period; rows without a period belong to one unnamed period.
  const periods = new Map<string, { end: number; rows: Record<string, unknown>[] }>();
  for (const raw of data) {
    const r = obj(raw);
    const key = `${r.start ?? ""}-${r.end ?? ""}`;
    const p = periods.get(key) ?? { end: isNum(r.end) ? r.end : 0, rows: [] };
    p.rows.push(r);
    periods.set(key, p);
  }
  const candidates = [...periods.values()].sort((a, b) => b.end - a.end);

  for (const p of candidates) {
    const months: ClimateMonth[] = [];
    for (let m = 1; m <= 12; m++) {
      const r = p.rows.find((row) => row.month === m);
      if (!r || !isNum(r.tmax) || !isNum(r.tmin)) break;
      const month: ClimateMonth = { month: m, tmax: round1(r.tmax), tmin: round1(r.tmin) };
      if (isNum(r.prcp)) month.precip_mm = Math.round(r.prcp);
      if (isNum(r.tsun)) month.sun_hours = round1(r.tsun / 60 / DAYS_IN_MONTH[m - 1]);
      months.push(month);
    }
    if (months.length === 12) return { months };
  }
  // Rows came, but not twelve usable months: no station data for this point.
  throw new ProviderError("no_data");
}

async function climate(q: LatLon, ctx: ProviderContext): Promise<Climate> {
  const url = "https://meteostat.p.rapidapi.com/point/normals?" +
    query({ lat: coord(q.lat), lon: coord(q.lon) });
  const json = await fetchJson(ctx, url, {
    headers: {
      "x-rapidapi-host": "meteostat.p.rapidapi.com",
      "x-rapidapi-key": ctx.key ?? "",
      "Accept": "application/json",
    },
  }, { keyed: true });
  return parseNormals(json);
}

export const meteostat: Provider = {
  id: "meteostat",
  name: "Meteostat",
  homepage: "https://meteostat.net",
  key_url: "https://rapidapi.com/meteostat/api/meteostat",
  needs_key: true,
  cost: "free_key",
  receives: ["coordinates"],
  attribution: "Source: Meteostat (meteostat.net) and its data providers, CC BY 4.0",
  hosts: ["meteostat.p.rapidapi.com"],
  budget: { per_day: 15, climate_per_hour: 5 },
  docs: [
    "https://dev.meteostat.net/api (RapidAPI host, authentication, errors, 500 requests a month) read 2026-11-15",
    "https://dev.meteostat.net/api/point/normals (endpoint, parameters, response fields) read 2026-11-15",
    "https://dev.meteostat.net/license (CC BY 4.0, credit) read 2026-11-15",
  ],
  climate,
};
