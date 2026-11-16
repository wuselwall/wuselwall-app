// openrouteservice (https://openrouteservice.org, HeiGIT), driving routes and place search, with
// the family's own free key.
//
// Written on 2026-11-15 from the documentation in `docs`. NOT called with a key; a keyless
// call confirmed only that the gateway wants the key in the `Authorization` header ("401
// Authorization field missing"; a wrong key answers 403). The key therefore goes in that header
// and never into the URL.
//
// Route: `GET /v2/directions/driving-car?start=lon,lat&end=lon,lat` returns GeoJSON whose first
// feature has `properties.summary.distance` (metres) and `.duration` (seconds); the JSON form
// (`routes[0].summary`) is read too. No route, or a point it cannot snap to a road, is
// 404 or error code 2009/2010 (no_data). Hosted limit: 6,000 km (error 2004 beyond it, treated
// as no_data).
//
// Geocode: `GET /geocode/search?text=&size=` (a Pelias instance) returns GeoJSON features with
// `geometry.coordinates` [lon, lat] and `properties` `name`, `label`, `country_a` (ISO alpha-3,
// converted), `region`/`macroregion`. Pelias takes no language parameter that this file relies
// on, so `lang` is not sent. The plans page did not show the free quotas; `per_day: 200`
// is a courtesy ceiling well below the 40 requests a minute and 2,000 a day the hosted free
// plan is generally described with (not verified).
import {
  type LatLon,
  type Places,
  type Provider,
  type ProviderContext,
  ProviderError,
  type Route,
  type RouteQuery,
} from "../types.ts";
import { coord, fetchJson, query } from "../http.ts";
import { alpha2 } from "../countries.ts";
import { arr, isNum, obj, round1 } from "../weather.ts";

const HOST = "https://api.openrouteservice.org";

const lonLat = (p: LatLon) => `${coord(p.lon)},${coord(p.lat)}`;

export function parseRoute(json: unknown): Route {
  const body = obj(json);
  let summary: unknown;
  if (Array.isArray(body.features)) {
    if (body.features.length === 0) throw new ProviderError("no_data");
    summary = obj(obj(body.features[0]).properties).summary;
  } else if (Array.isArray(body.routes)) {
    if (body.routes.length === 0) throw new ProviderError("no_data");
    summary = obj(body.routes[0]).summary;
  } else {
    throw new ProviderError("bad_answer");
  }
  const s = obj(summary);
  if (!isNum(s.distance) || !isNum(s.duration)) throw new ProviderError("bad_answer");
  return { km: round1(s.distance / 1000), minutes: Math.round(s.duration / 60) };
}

async function route(q: RouteQuery, ctx: ProviderContext): Promise<Route> {
  const url = `${HOST}/v2/directions/driving-car?` +
    query({ start: lonLat(q.from), end: lonLat(q.to) }).replace(/%2C/g, ",");
  try {
    return parseRoute(
      await fetchJson(ctx, url, {
        headers: {
          "Authorization": ctx.key ?? "",
          "Accept": "application/geo+json, application/json",
        },
      }, { keyed: true, noData: [404] }),
    );
  } catch (err) {
    // 2009 "route could not be found", 2010 "point was not found", 2004 "exceeds the limit"
    // arrive as 400 or 404 with an error code; fetchJson reports them as http_400.
    if (err instanceof ProviderError && err.code === "http_400") throw new ProviderError("no_data");
    throw err;
  }
}

export function parseGeocode(json: unknown): Places {
  const features = arr(obj(json).features);
  const places: Places["places"] = [];
  for (const raw of features) {
    const f = obj(raw);
    const coords = obj(f.geometry).coordinates;
    const p = obj(f.properties);
    if (!Array.isArray(coords) || !isNum(coords[0]) || !isNum(coords[1])) continue;
    const name = typeof p.name === "string" && p.name !== ""
      ? p.name
      : typeof p.label === "string" ? p.label.split(",")[0].trim() : "";
    if (name === "") continue;
    const place: Places["places"][number] = {
      name,
      country: alpha2(p.country_a),
      lat: coords[1],
      lon: coords[0],
    };
    const admin = [p.region, p.macroregion].find((v) => typeof v === "string" && v !== "");
    if (typeof admin === "string") place.admin = admin;
    places.push(place);
  }
  return { places };
}

async function geocode(q: { q: string; lang: string }, ctx: ProviderContext): Promise<Places> {
  const url = `${HOST}/geocode/search?` + query({ text: q.q, size: 5 });
  return parseGeocode(
    await fetchJson(ctx, url, {
      headers: { "Authorization": ctx.key ?? "", "Accept": "application/json" },
    }, { keyed: true }),
  );
}

export const openRouteService: Provider = {
  id: "openrouteservice",
  name: "openrouteservice",
  homepage: "https://openrouteservice.org",
  key_url: "https://account.heigit.org/signup",
  needs_key: true,
  cost: "free_key",
  receives: ["coordinates", "search_text", "home_coordinates"],
  attribution: "Routing by openrouteservice.org (HeiGIT), data © OpenStreetMap contributors",
  hosts: ["api.openrouteservice.org"],
  budget: { per_day: 200 },
  docs: [
    "https://giscience.github.io/openrouteservice/api-reference/endpoints/directions/requests-and-return-types read 2026-11-15",
    "https://giscience.github.io/openrouteservice/api-reference/endpoints/geocoder/ read 2026-11-15",
    "https://giscience.github.io/openrouteservice/api-reference/error-codes read 2026-11-15",
    "https://giscience.github.io/openrouteservice/hosted-api-restrictions read 2026-11-15",
    "https://raw.githubusercontent.com/pelias/documentation/master/response.md (feature properties) read 2026-11-15",
  ],
  route,
  geocode,
};
