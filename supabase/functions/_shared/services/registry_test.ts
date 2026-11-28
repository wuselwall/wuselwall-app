import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1.0.19";
import { catalogue, findProvider, PROVIDERS } from "./registry.ts";
import { CACHE_TTL_SECONDS, cacheKey, capabilitiesOf, CAPABILITIES } from "./types.ts";
import { serviceErrorResponse, SERVICE_ERROR_STATUS } from "./errors.ts";
import { RequestError } from "../client.ts";
import { ServiceError } from "./types.ts";

Deno.test("registry: the providers of specs/30 with their capabilities and keys", () => {
  const table = Object.fromEntries(PROVIDERS.map((p) => [p.id, [p.needs_key, capabilitiesOf(p)]]));
  assertEquals(table, {
    "open-meteo": [false, ["climate", "forecast", "geocode"]],
    "met-no": [false, ["forecast"]],
    "nominatim": [false, ["geocode"]],
    "openweathermap": [true, ["forecast", "geocode"]],
    "meteostat": [true, ["climate"]],
    "openrouteservice": [true, ["geocode", "route"]],
    "google": [true, ["geocode", "route", "map"]],
  });
});

Deno.test("registry: every provider is well formed", () => {
  const ids = new Set<string>();
  for (const p of PROVIDERS) {
    assert(/^[a-z0-9-]{2,40}$/.test(p.id), p.id);
    assert(!ids.has(p.id));
    ids.add(p.id);
    assert(p.name !== "" && p.attribution !== "", p.id);
    assert(p.homepage.startsWith("https://"));
    assertEquals(p.needs_key, p.cost !== "free", p.id);
    assertEquals(p.key_url === null, !p.needs_key, p.id);
    if (p.key_url !== null) assert(p.key_url.startsWith("https://"));
    assert(p.hosts.length > 0);
    for (const h of p.hosts) assert(/^[a-z0-9.-]+\.[a-z]{2,}$/.test(h) && !h.includes("/"), `${p.id} ${h}`);
    assert(p.budget.per_day > 0 && p.budget.per_day <= 1000, p.id);
    assert(p.receives.length > 0);
    // The documentation it was written from, with the day it was read.
    assert(p.docs.length > 0 && p.docs.every((d) => d.startsWith("https://") && d.includes("2026-11-15")), p.id);
    for (const c of capabilitiesOf(p)) assert(CAPABILITIES.includes(c));
    // A provider that does climate says how often it may fetch it.
    if (p.climate) assert(p.budget.climate_per_hour !== undefined && p.budget.climate_per_hour > 0, p.id);
    // Route and geocoding providers that take the home place say so.
    if (p.route) assert(p.receives.includes("home_coordinates"), p.id);
    if (p.geocode) assert(p.receives.includes("search_text"), p.id);
  }
});

Deno.test("catalogue: the answer's shape", () => {
  const { providers } = catalogue();
  assertEquals(providers.length, PROVIDERS.length);
  assertEquals(Object.keys(providers[0]).sort(), [
    "attribution",
    "capabilities",
    "cost",
    "homepage",
    "id",
    "key_url",
    "name",
    "needs_key",
    "receives",
  ]);
  const google = providers.find((p) => p.id === "google")!;
  assertEquals(google.cost, "paid_key");
  assertEquals(google.capabilities, ["geocode", "route", "map"]);
  assertEquals(findProvider("google"), PROVIDERS.find((p) => p.id === "google"));
  assertEquals(findProvider("nope"), undefined);
  // The catalogue holds no function and nothing that is not JSON.
  assertEquals(JSON.parse(JSON.stringify(providers)), providers);
});

Deno.test("cacheKey: rounded coordinates, folded text, one key per provider and question", () => {
  assertEquals(cacheKey("forecast", "open-meteo", { lat: 39.5712, lon: 2.6498 }), "forecast:open-meteo:39.57,2.65");
  assertEquals(cacheKey("climate", "meteostat", { lat: -33.8999, lon: 151.2001 }), "climate:meteostat:-33.90,151.20");
  assertEquals(cacheKey("geocode", "nominatim", { q: "  Santa   CRUZ ", lang: "es" }), "geocode:nominatim:es:santa cruz");
  assertEquals(
    cacheKey("route", "google", { from: { lat: 1.234, lon: 2.345 }, to: { lat: 3, lon: 4 } }),
    "route:google:1.23,2.35>3.00,4.00",
  );
  assertEquals(cacheKey("map", "google", { lat: 1, lon: 2, zoom: 9, width: 300, height: 200 }), "map:google:1.00,2.00:9:300x200");
  assertNotEquals(cacheKey("forecast", "met-no", { lat: 1, lon: 1 }), cacheKey("forecast", "open-meteo", { lat: 1, lon: 1 }));
  assertNotEquals(cacheKey("geocode", "nominatim", { q: "a", lang: "de" }), cacheKey("geocode", "nominatim", { q: "a", lang: "en" }));
});

Deno.test("cache lifetimes: the specification's", () => {
  const day = 24 * 3600;
  assertEquals(CACHE_TTL_SECONDS, { climate: 5 * 365 * day, geocode: 90 * day, route: 30 * day, map: 30 * day, forecast: 3 * 3600 });
});

Deno.test("serviceErrorResponse: the statuses of the specification, the database's hint as the code", async () => {
  assertEquals(SERVICE_ERROR_STATUS, { service_off: 409, service_key_missing: 409, service_limit: 429, service_failed: 502 });
  for (const [code, status] of Object.entries(SERVICE_ERROR_STATUS)) {
    const res = await serviceErrorResponse(new ServiceError(code as keyof typeof SERVICE_ERROR_STATUS));
    assertEquals([res.status, await res.json()], [status, { error: code }]);
  }
  const refused = await serviceErrorResponse(new RequestError(403, "adults_only", "WW-AUTH adults only", "adults_only"));
  assertEquals(refused.status, 403);
  assertEquals((await refused.json()).error, "adults_only");
  const invalid = await serviceErrorResponse(new RequestError(400, "invalid_request", "lat must be a number", "invalid_request"));
  assertEquals([invalid.status, (await invalid.json()).error], [400, "invalid_request"]);
  const pg = await serviceErrorResponse({ code: "42501", message: "WW-AUTH guardian required", hint: "guardian_required" });
  assertEquals([pg.status, (await pg.json()).error], [403, "guardian_required"]);
  const boom = await serviceErrorResponse(new Error("secret detail"));
  assertEquals(boom.status, 500);
  assertEquals(await boom.json(), { error: "internal", code: "internal", message: "internal error", hint: null });
});
