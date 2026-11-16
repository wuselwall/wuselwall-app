// Google Maps Platform (https://developers.google.com/maps), place search, driving route and a
// static map picture, with the family's own key (paid after the monthly credit).
//
// Written on 2026-11-15 from the documentation in `docs`. NOT called (no key). The Geocoding
// and Static Maps APIs take the key as the `key` query parameter (their only way), so no error
// of this file carries a URL (all failures are ProviderError codes, see ../http.ts); the Routes
// API takes it in the `X-Goog-Api-Key` header.
//
// Route: the Routes API `computeRoutes` (the Distance Matrix API is the older, legacy way) with
// the field mask `routes.distanceMeters,routes.duration`, `travelMode: DRIVE` and no routing
// preference (the default is the cheapest tier; traffic-aware routing is billed higher).
// `duration` is a string like "165s". An answer without `routes` means no route (no_data).
//
// Map: the Static Maps API, 100-640 pixels a side at scale 1, PNG, a red marker at the centre;
// the picture carries Google's own logo. `per_day: 100` is a cost ceiling for the family's own
// key, not a quota of Google's.
import {
  type LatLon,
  type MapImage,
  type MapQuery,
  type Places,
  type Provider,
  type ProviderContext,
  ProviderError,
  type Route,
  type RouteQuery,
} from "../types.ts";
import { coord, fetchBytes, fetchJson, query, toBase64 } from "../http.ts";
import { arr, isNum, obj, round1 } from "../weather.ts";

export function parseGeocode(json: unknown): Places {
  const body = obj(json);
  switch (body.status) {
    case "OK":
      break;
    case "ZERO_RESULTS":
      return { places: [] };
    case "OVER_QUERY_LIMIT":
    case "OVER_DAILY_LIMIT":
      throw new ProviderError("quota");
    case "REQUEST_DENIED":
      throw new ProviderError("unauthorized");
    case "UNKNOWN_ERROR":
      throw new ProviderError("http_500");
    default:
      throw new ProviderError("bad_answer");
  }
  const places: Places["places"] = [];
  for (const raw of arr(body.results).slice(0, 5)) {
    const r = obj(raw);
    const loc = obj(obj(r.geometry).location);
    if (!isNum(loc.lat) || !isNum(loc.lng)) continue;
    const components = Array.isArray(r.address_components) ? r.address_components.map(obj) : [];
    const typed = (type: string) =>
      components.find((c) => Array.isArray(c.types) && c.types.includes(type));
    const first = components[0]?.long_name;
    const name = typeof first === "string" && first !== ""
      ? first
      : typeof r.formatted_address === "string" ? r.formatted_address.split(",")[0].trim() : "";
    if (name === "") continue;
    const country = typed("country")?.short_name;
    const place: Places["places"][number] = {
      name,
      country: typeof country === "string" ? country.toUpperCase() : "",
      lat: loc.lat,
      lon: loc.lng,
    };
    const admin = typed("administrative_area_level_1")?.long_name;
    if (typeof admin === "string" && admin !== "") place.admin = admin;
    places.push(place);
  }
  return { places };
}

async function geocode(q: { q: string; lang: string }, ctx: ProviderContext): Promise<Places> {
  const url = "https://maps.googleapis.com/maps/api/geocode/json?" +
    query({ address: q.q, language: q.lang, key: ctx.key ?? "" });
  return parseGeocode(await fetchJson(ctx, url, {}, { keyed: true }));
}

export function parseRoute(json: unknown): Route {
  const routes = obj(json).routes;
  if (routes === undefined) throw new ProviderError("no_data");
  const list = arr(routes);
  if (list.length === 0) throw new ProviderError("no_data");
  const r = obj(list[0]);
  const seconds = typeof r.duration === "string" ? /^(\d+(?:\.\d+)?)s$/.exec(r.duration) : null;
  if (!isNum(r.distanceMeters) || seconds === null) throw new ProviderError("bad_answer");
  return { km: round1(r.distanceMeters / 1000), minutes: Math.round(Number(seconds[1]) / 60) };
}

async function route(q: RouteQuery, ctx: ProviderContext): Promise<Route> {
  const point = (p: LatLon) => ({
    location: { latLng: { latitude: Number(coord(p.lat)), longitude: Number(coord(p.lon)) } },
  });
  return parseRoute(
    await fetchJson(ctx, "https://routes.googleapis.com/directions/v2:computeRoutes", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": ctx.key ?? "",
        "X-Goog-FieldMask": "routes.distanceMeters,routes.duration",
      },
      body: JSON.stringify({
        origin: point(q.from),
        destination: point(q.to),
        travelMode: "DRIVE",
      }),
    }, { keyed: true }),
  );
}

const PNG_SIGNATURE = [0x89, 0x50, 0x4e, 0x47];

async function map(q: MapQuery, ctx: ProviderContext): Promise<MapImage> {
  const at = `${coord(q.lat)},${coord(q.lon)}`;
  const url = "https://maps.googleapis.com/maps/api/staticmap?" + query({
    center: at,
    zoom: q.zoom,
    size: `${q.width}x${q.height}`,
    scale: 1,
    format: "png",
    maptype: "roadmap",
    markers: `color:red|${at}`,
    key: ctx.key ?? "",
  });
  const { bytes } = await fetchBytes(ctx, url, { keyed: true });
  if (bytes.length < 8 || !PNG_SIGNATURE.every((b, i) => bytes[i] === b)) {
    throw new ProviderError("bad_answer");
  }
  return { image_base64: toBase64(bytes), mime: "image/png" };
}

export const google: Provider = {
  id: "google",
  name: "Google Maps Platform",
  homepage: "https://mapsplatform.google.com",
  key_url: "https://console.cloud.google.com/google/maps-apis/credentials",
  needs_key: true,
  cost: "paid_key",
  receives: ["coordinates", "search_text", "home_coordinates"],
  attribution: "Map data © Google",
  hosts: ["maps.googleapis.com", "routes.googleapis.com"],
  budget: { per_day: 100 },
  docs: [
    "https://developers.google.com/maps/documentation/geocoding/requests-geocoding read 2026-11-15",
    "https://developers.google.com/maps/documentation/routes/compute_route_directions read 2026-11-15",
    "https://developers.google.com/maps/documentation/maps-static/start read 2026-11-15",
  ],
  geocode,
  route,
  map,
};
