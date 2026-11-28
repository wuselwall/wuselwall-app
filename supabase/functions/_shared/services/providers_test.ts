// Every plug-in against recorded answers (providers/fixtures/). The keyless providers' fixtures
// are live answers of 2026-11-15 (Open-Meteo's climate and sea ones thinned to fewer years and
// days); the keyed providers' fixtures are written from the structures their documentation
// shows, since no key was available. The fetch is always a fake that answers by URL and goes
// through guardedFetch, so a plug-in that uses a host it did not declare fails here.
import { assert, assertEquals } from "jsr:@std/assert@1.0.19";
import { guardedFetch } from "./http.ts";
import { alpha2 } from "./countries.ts";
import { PROVIDERS } from "./registry.ts";
import { google } from "./providers/google.ts";
import { metNo, parseForecast as parseMet, symbolKind } from "./providers/met-no.ts";
import { meteostat } from "./providers/meteostat.ts";
import { nominatim, spacing } from "./providers/nominatim.ts";
import { openMeteo, parseClimate, parseSea, climateYears } from "./providers/open-meteo.ts";
import { openRouteService } from "./providers/openrouteservice.ts";
import { conditionKind, openWeatherMap } from "./providers/openweathermap.ts";
import { dayCode, wmoToCode } from "./weather.ts";
import { type Provider, type ProviderContext, ProviderError } from "./types.ts";

spacing.minGapMs = 0; // the tests do not wait for Nominatim's one request a second

async function fixture(name: string): Promise<unknown> {
  return JSON.parse(await Deno.readTextFile(new URL(`./providers/fixtures/${name}`, import.meta.url)));
}

type Seen = { url: string; init: RequestInit };
type Reply = { status?: number; body?: unknown; bytes?: Uint8Array; headers?: Record<string, string> };

/** A context whose fetch answers by the first matching URL fragment and records every request. */
function ctxFor(
  provider: Provider,
  replies: Record<string, Reply>,
  key: string | null = null,
): { ctx: ProviderContext; seen: Seen[] } {
  const seen: Seen[] = [];
  const base = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    seen.push({ url, init: init ?? {} });
    const hit = Object.entries(replies).find(([fragment]) => url.includes(fragment));
    if (!hit) return Promise.reject(new Error(`unexpected request ${url}`));
    const r = hit[1];
    const body = r.bytes ?? (typeof r.body === "string" ? r.body : JSON.stringify(r.body ?? {}));
    return Promise.resolve(new Response(body as BodyInit, { status: r.status ?? 200, headers: r.headers }));
  }) as typeof fetch;
  return {
    ctx: { key, fetch: guardedFetch(provider, base), signal: new AbortController().signal },
    seen,
  };
}

async function codeOf(p: Promise<unknown>): Promise<string> {
  try {
    await p;
  } catch (err) {
    if (err instanceof ProviderError) return err.code;
    throw err;
  }
  throw new Error("expected a ProviderError");
}

const PALMA = { lat: 39.57, lon: 2.65 };
const CODES = ["clear", "partly", "cloudy", "fog", "rain", "snow", "storm"];

// ---------------------------------------------------------------- shared helpers

Deno.test("wmoToCode: the WMO table maps onto the seven codes", () => {
  const expect: Record<number, string | null> = {
    0: "clear", 1: "clear", 2: "partly", 3: "cloudy", 45: "fog", 48: "fog", 51: "rain", 57: "rain",
    61: "rain", 67: "rain", 71: "snow", 77: "snow", 80: "rain", 82: "rain", 85: "snow", 86: "snow",
    95: "storm", 96: "storm", 99: "storm", 4: null, 100: null,
  };
  for (const [code, kind] of Object.entries(expect)) assertEquals(wmoToCode(Number(code)), kind, code);
});

Deno.test("dayCode: storm, snow, rain, fog and the cloud average", () => {
  const s = (kind: "clear" | "partly" | "cloudy" | "fog" | "rain" | "snow" | "storm", localHour = 12) => ({ kind, localHour });
  assertEquals(dayCode([s("clear"), s("storm")], 0), "storm");
  assertEquals(dayCode([s("rain"), s("snow")], 3), "snow");
  assertEquals(dayCode([s("rain"), s("cloudy")], 3), "rain");
  assertEquals(dayCode([s("rain"), s("clear")], 0.4), "partly"); // drizzle under 1 mm is a cloud question
  assertEquals(dayCode([s("fog"), s("clear")], 0), "fog");
  assertEquals(dayCode([s("clear"), s("clear", 0)], 0), "clear");
  assertEquals(dayCode([s("cloudy", 3), s("clear", 9), s("clear", 13)], 0), "clear"); // night slices count less
  assertEquals(dayCode([s("cloudy"), s("cloudy")], 0), "cloudy");
});

Deno.test("alpha2: three-letter codes to two-letter ones", () => {
  assertEquals([alpha2("PRT"), alpha2("deu"), alpha2("XXX"), alpha2(undefined)], ["PT", "DE", "", ""]);
});

// ---------------------------------------------------------------- open-meteo

Deno.test("open-meteo forecast: 16 days from the live fixture", async () => {
  const { ctx, seen } = ctxFor(openMeteo, { "api.open-meteo.com/v1/forecast": { body: await fixture("open-meteo_forecast.json") } });
  const { days } = await openMeteo.forecast!({ lat: 39.57, lon: 2.65 }, ctx);
  assertEquals(days.length, 16);
  assertEquals(days[0], { date: "2026-11-15", tmax: 21, tmin: 16.2, precip_mm: 0, precip_prob: 3, code: "cloudy" });
  assertEquals(days[9].code, "rain"); // WMO 53, moderate drizzle
  assertEquals(days[9].precip_mm, 9.4);
  for (const d of days) {
    assert(CODES.includes(d.code));
    assert(d.tmax >= d.tmin);
    assert(/^\d{4}-\d{2}-\d{2}$/.test(d.date));
  }
  const url = new URL(seen[0].url);
  assertEquals(url.searchParams.get("latitude"), "39.57");
  assertEquals(url.searchParams.get("forecast_days"), "16");
  assertEquals(url.searchParams.get("timezone"), "auto");
});

Deno.test("open-meteo forecast: empty, malformed and refused answers", async () => {
  const ask = (reply: Reply) => openMeteo.forecast!(PALMA, ctxFor(openMeteo, { "/v1/forecast": reply }).ctx);
  assertEquals(await codeOf(ask({ body: { daily: { time: [], temperature_2m_max: [], temperature_2m_min: [], weather_code: [] } } })), "no_data");
  assertEquals(await codeOf(ask({ body: { error: true, reason: "x" } })), "bad_answer");
  assertEquals(await codeOf(ask({ body: [] })), "bad_answer");
  assertEquals(await codeOf(ask({ body: { daily: { time: ["2026-11-15"], temperature_2m_max: [1, 2], temperature_2m_min: [1], weather_code: [1] } } })), "bad_answer");
  assertEquals(await codeOf(ask({ body: "<html>", status: 200 })), "bad_answer");
  assertEquals(await codeOf(ask({ status: 429 })), "quota");
  assertEquals(await codeOf(ask({ status: 400, body: { error: true } })), "http_400");
  assertEquals(await codeOf(ask({ status: 403 })), "http_403"); // keyless: not "unauthorized"
});

Deno.test("open-meteo geocode: Lisbon with country and region, and no results", async () => {
  const replies = { "geocoding-api.open-meteo.com": { body: await fixture("open-meteo_geocode.json") } };
  const { ctx, seen } = ctxFor(openMeteo, replies);
  const { places } = await openMeteo.geocode!({ q: "Lisbon", lang: "de" }, ctx);
  assertEquals(places[0], { name: "Lisbon", country: "PT", admin: "Lisbon District", lat: 38.72509, lon: -9.1498 });
  assertEquals(places.length, 4);
  assertEquals(new URL(seen[0].url).searchParams.get("language"), "de");
  assertEquals(new URL(seen[0].url).searchParams.get("name"), "Lisbon");
  const none = ctxFor(openMeteo, { "geocoding-api": { body: { generationtime_ms: 0.3 } } }).ctx;
  assertEquals(await openMeteo.geocode!({ q: "Zzzzzz", lang: "en" }, none), { places: [] });
  const bad = ctxFor(openMeteo, { "geocoding-api": { body: { results: "x" } } }).ctx;
  assertEquals(await codeOf(openMeteo.geocode!({ q: "Zz", lang: "en" }, bad)), "bad_answer");
});

Deno.test("open-meteo climate: twelve months from the archive (Palma, 2024-2025) and the sea", async () => {
  const replies = {
    "archive-api.open-meteo.com": { body: await fixture("open-meteo_climate.json") },
    "marine-api.open-meteo.com": { body: await fixture("open-meteo_sea.json") },
  };
  const { ctx, seen } = ctxFor(openMeteo, replies);
  const { months } = await openMeteo.climate!({ lat: 39.5712, lon: 2.6498 }, ctx);
  assertEquals(months.map((m) => m.month), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
  const jul = months[6];
  assert(jul.tmax > 28 && jul.tmax < 36, `July tmax ${jul.tmax}`);
  assert(jul.tmin > 18 && jul.tmin < 26);
  assert(jul.rain_days! >= 0 && jul.rain_days! < 6);
  assert(jul.sun_hours! > 9 && jul.sun_hours! <= 14.5, `July sun ${jul.sun_hours}`);
  assert(jul.sea! > 23 && jul.sea! < 29, `July sea ${jul.sea}`);
  const jan = months[0];
  assert(jan.tmax > 10 && jan.tmax < 19);
  assert(jan.sea! > 13 && jan.sea! < 17, `January sea ${jan.sea}`);
  for (const m of months) assert(m.tmax > m.tmin && m.precip_mm! >= 0);

  // The recipe: two requests, rounded coordinates, last full years, one hourly variable for the sea.
  assertEquals(seen.length, 2);
  const archive = new URL(seen.find((s) => s.url.includes("archive-api"))!.url);
  const { first, last } = climateYears(new Date());
  assertEquals(archive.searchParams.get("start_date"), `${first}-01-01`);
  assertEquals(archive.searchParams.get("end_date"), `${last}-12-31`);
  assertEquals(archive.searchParams.get("latitude"), "39.5712");
  assertEquals(archive.searchParams.get("daily"), "temperature_2m_max,temperature_2m_min,precipitation_sum,sunshine_duration");
  const marine = new URL(seen.find((s) => s.url.includes("marine-api"))!.url);
  assertEquals(marine.searchParams.get("hourly"), "sea_surface_temperature");
  assertEquals(marine.searchParams.get("timeformat"), "unixtime");
  assert(Number(marine.searchParams.get("start_date")!.slice(0, 4)) >= 2023);
});

Deno.test("open-meteo climate: the sea is optional, the archive is not", async () => {
  const archive = await fixture("open-meteo_climate.json");
  const without = async (marine: Reply) => {
    const { ctx } = ctxFor(openMeteo, { "archive-api": { body: archive }, "marine-api": marine });
    return (await openMeteo.climate!(PALMA, ctx)).months;
  };
  for (const marine of [{ status: 503 }, { body: { hourly: { time: [], sea_surface_temperature: [] } } }, { body: "x" }]) {
    assert((await without(marine)).every((m) => m.sea === undefined));
  }
  const { ctx } = ctxFor(openMeteo, { "archive-api": { status: 429 }, "marine-api": { body: {} } });
  assertEquals(await codeOf(openMeteo.climate!(PALMA, ctx)), "quota");
  const empty = ctxFor(openMeteo, { "archive-api": { body: { daily: { time: [] } } }, "marine-api": { body: {} } }).ctx;
  assertEquals(await codeOf(openMeteo.climate!(PALMA, empty)), "no_data");
});

/** One year of days, every month 28 long, with values that make the means easy to check. */
function syntheticYear(year: number) {
  const daily = { time: [] as string[], temperature_2m_max: [] as number[], temperature_2m_min: [] as number[], precipitation_sum: [] as number[], sunshine_duration: [] as number[] };
  for (let m = 1; m <= 12; m++) {
    for (let d = 1; d <= 28; d++) {
      daily.time.push(`${year}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`);
      daily.temperature_2m_max.push(m + (d % 2));
      daily.temperature_2m_min.push(m - 5);
      daily.precipitation_sum.push(d % 2 === 0 ? 2 : 0.4);
      daily.sunshine_duration.push(7200);
    }
  }
  return daily;
}

Deno.test("open-meteo climate: the monthly means, rain days and sums are computed as documented", () => {
  const a = syntheticYear(2024);
  const b = syntheticYear(2025);
  const daily = {
    time: [...a.time, ...b.time],
    temperature_2m_max: [...a.temperature_2m_max, ...b.temperature_2m_max],
    temperature_2m_min: [...a.temperature_2m_min, ...b.temperature_2m_min],
    precipitation_sum: [...a.precipitation_sum, ...b.precipitation_sum],
    sunshine_duration: [...a.sunshine_duration, ...b.sunshine_duration],
  };
  const { months } = parseClimate({ daily });
  // March: tmax alternates 3 and 4 (mean 3.5), tmin -2, 14 rain days (2 mm) of 28 a year,
  // 14 x 2 + 14 x 0.4 = 33.6 mm a month, 2 hours of sun a day.
  assertEquals(months[2], { month: 3, tmax: 3.5, tmin: -2, rain_days: 14, precip_mm: 34, sun_hours: 2 });
});

Deno.test("open-meteo climate: a month with too few days is a bad answer, nulls are skipped", () => {
  const y = syntheticYear(2025);
  const cut = { ...y, time: y.time.slice(0, 300) };
  const short = Object.fromEntries(Object.entries(cut).map(([k, v]) => [k, (v as unknown[]).slice(0, 300)]));
  assertEquals(((): string => {
    try {
      parseClimate({ daily: short });
    } catch (e) {
      return (e as ProviderError).code;
    }
    return "none";
  })(), "bad_answer");
  const withNull = { ...y, temperature_2m_max: y.temperature_2m_max.map((v, i) => (i === 0 ? null : v)) };
  assertEquals(parseClimate({ daily: withNull }).months.length, 12);
});

Deno.test("open-meteo parseSea: far grid cells and inland points give no sea", async () => {
  const sea = await fixture("open-meteo_sea.json");
  assert(parseSea(sea, PALMA)!.every((v) => v !== null));
  assertEquals(parseSea(sea, { lat: 48.1, lon: 11.5 }), null); // 1,000 km from the cell it was snapped to
  assertEquals(parseSea({ latitude: 48.1, longitude: 11.5, hourly: { time: [1, 2], sea_surface_temperature: [null, null] } }, { lat: 48.1, lon: 11.5 }), null);
});

Deno.test("open-meteo: the climate recipe's cost stays inside the documented free limits", () => {
  // 4 years of daily values (1,461 days) and 2 years of hourly sea values (731 days), with the
  // pessimistic weighting of the pricing page (a floor of 1 on both factors). Each ceiling
  // leaves a fifth of the limit to the household's forecasts and place searches.
  const archiveCalls = Math.max(1461 / 14, 1) * Math.max(4 / 10, 1);
  const marineCalls = Math.max(731 / 14, 1) * Math.max(1 / 10, 1);
  const perFetch = archiveCalls + marineCalls;
  const { climate_per_minute, climate_per_hour, climate_per_day } = openMeteo.budget;
  assert(climate_per_minute !== undefined && climate_per_hour !== undefined && climate_per_day !== undefined);
  assert(perFetch * climate_per_minute <= 600 * 0.8, `${perFetch * climate_per_minute} calls a minute`);
  assert(perFetch * climate_per_hour <= 5000 * 0.8, `${perFetch * climate_per_hour} calls an hour`);
  assert(perFetch * climate_per_day <= 10_000 * 0.8, `${perFetch * climate_per_day} calls a day`);
});

Deno.test("open-meteo: the test call is the small geocode", async () => {
  const { ctx, seen } = ctxFor(openMeteo, { "geocoding-api": { body: await fixture("open-meteo_geocode.json") } });
  await openMeteo.test!(ctx);
  assertEquals(seen.length, 1);
});

// ---------------------------------------------------------------- met-no

Deno.test("met-no: symbol codes map onto the answer codes", () => {
  const expect: Record<string, string | null> = {
    clearsky_day: "clear", fair_night: "clear", partlycloudy_polartwilight: "partly", cloudy: "cloudy", fog: "fog",
    lightrain: "rain", heavyrainshowers_day: "rain", sleet: "snow", lightsnowshowers_night: "snow",
    rainandthunder: "storm", heavysnowshowersandthunder_day: "storm", mystery: null,
  };
  for (const [code, kind] of Object.entries(expect)) assertEquals(symbolKind(code), kind, code);
});

Deno.test("met-no forecast: days from the live fixture's six-hour blocks", async () => {
  const { ctx, seen } = ctxFor(metNo, { "api.met.no/weatherapi/locationforecast/2.0/complete": { body: await fixture("met-no_forecast.json") } });
  const { days } = await metNo.forecast!(PALMA, ctx);
  assert(days.length >= 8, `${days.length} days`);
  assertEquals(days[0].date, "2026-11-15"); // the rest of the day of the request
  const dates = days.map((d) => d.date);
  assertEquals(dates, [...dates].sort());
  assertEquals(new Set(dates).size, dates.length);
  for (const d of days) {
    assert(d.tmax >= d.tmin);
    assert(d.precip_mm >= 0);
    assert(CODES.includes(d.code));
    assertEquals(d.precip_prob, undefined);
  }
  // Fixture: 2026-11-18 00-06Z is light rain, 1.9 mm in the 06-12 block.
  assert(days.some((d) => d.code === "rain"));
  const url = new URL(seen[0].url);
  assertEquals([url.searchParams.get("lat"), url.searchParams.get("lon")], ["39.57", "2.65"]);
  assertEquals(new Headers(seen[0].init.headers).get("user-agent")?.includes("WuselWall"), true);
});

function block(time: string, symbol: string, max: number, min: number, precip: number) {
  return {
    time,
    data: {
      instant: { details: { air_temperature: (max + min) / 2 } },
      next_6_hours: { summary: { symbol_code: symbol }, details: { air_temperature_max: max, air_temperature_min: min, precipitation_amount: precip } },
    },
  };
}

Deno.test("met-no forecast: a day is its 00/06/12/18 blocks, in the longitude's local date", () => {
  const series = [
    block("2026-11-16T00:00:00Z", "clearsky_night", 8, 5, 0),
    block("2026-11-16T01:00:00Z", "clearsky_night", 99, -99, 9), // an hourly point inside a block: ignored
    block("2026-11-16T06:00:00Z", "clearsky_day", 14, 6, 0),
    block("2026-11-16T12:00:00Z", "partlycloudy_day", 18, 12, 0.2),
    block("2026-11-16T18:00:00Z", "lightrain", 15, 10, 1.6),
    block("2026-11-17T00:00:00Z", "cloudy", 12, 9, 0),
  ];
  const days = parseMet({ properties: { timeseries: series } }, 0).days;
  assertEquals(days, [{ date: "2026-11-16", tmax: 18, tmin: 5, precip_mm: 1.8, code: "rain" }]); // 17th has one block: dropped
  // Longitude 150 east is +10 h: the 00Z, 06Z and 12Z blocks start at 10:00, 16:00 and 22:00 on
  // the 16th, the 18Z and next 00Z blocks at 04:00 and 10:00 on the 17th.
  const east = parseMet({ properties: { timeseries: series } }, 150).days;
  assertEquals(east, [
    { date: "2026-11-16", tmax: 18, tmin: 5, precip_mm: 0.2, code: "clear" }, // the daytime blocks (10:00, 16:00) are clear
    { date: "2026-11-17", tmax: 15, tmin: 9, precip_mm: 1.6, code: "rain" },
  ]);
});

Deno.test("met-no forecast: empty, malformed, refused", async () => {
  const ask = (reply: Reply) => metNo.forecast!(PALMA, ctxFor(metNo, { "locationforecast": reply }).ctx);
  assertEquals(await codeOf(ask({ body: { properties: { timeseries: [] } } })), "no_data");
  assertEquals(await codeOf(ask({ body: { properties: { timeseries: [{ time: "x" }] } } })), "bad_answer");
  assertEquals(await codeOf(ask({ body: {} })), "bad_answer");
  assertEquals(await codeOf(ask({ status: 403 })), "http_403"); // a banned User-Agent, not a key
  assertEquals(await codeOf(ask({ status: 429 })), "quota");
});

// ---------------------------------------------------------------- nominatim

Deno.test("nominatim geocode: the live Lisbon answer", async () => {
  const { ctx, seen } = ctxFor(nominatim, { "nominatim.openstreetmap.org/search": { body: await fixture("nominatim_geocode.json") } });
  const { places } = await nominatim.geocode!({ q: "Lisbon", lang: "fr" }, ctx);
  assertEquals(places[0], { name: "Lisbon", country: "PT", admin: "Lisbon", lat: 38.7077507, lon: -9.1365919 });
  assertEquals(places[2].admin, "Iowa");
  assertEquals(places[2].country, "US");
  const url = new URL(seen[0].url);
  assertEquals(url.searchParams.get("format"), "jsonv2");
  assertEquals(url.searchParams.get("accept-language"), "fr");
  assertEquals(url.searchParams.get("limit"), "5");
});

Deno.test("nominatim geocode: nothing found, bad rows, malformed, refused", async () => {
  const ask = (reply: Reply) => nominatim.geocode!({ q: "x", lang: "en" }, ctxFor(nominatim, { "/search": reply }).ctx);
  assertEquals(await ask({ body: [] }), { places: [] });
  assertEquals(await ask({ body: [{ lat: "x", lon: "1", name: "A" }, { lat: "1", lon: "2" }, { lat: "1.5", lon: "2.5", display_name: "Foo, Bar" }] }), {
    places: [{ name: "Foo", country: "", lat: 1.5, lon: 2.5 }],
  });
  assertEquals(await codeOf(ask({ body: { error: "x" } })), "bad_answer");
  assertEquals(await codeOf(ask({ status: 429 })), "quota");
  assertEquals(await codeOf(ask({ status: 403 })), "http_403");
});

Deno.test("nominatim: calls are spaced by the policy's one a second", async () => {
  spacing.minGapMs = 60;
  try {
    const { ctx } = ctxFor(nominatim, { "/search": { body: [] } });
    const t0 = Date.now();
    await Promise.all([1, 2, 3].map(() => nominatim.geocode!({ q: "x", lang: "en" }, ctx)));
    assert(Date.now() - t0 >= 110, `took ${Date.now() - t0} ms`);
  } finally {
    spacing.minGapMs = 0;
  }
});

// ---------------------------------------------------------------- openweathermap

Deno.test("openweathermap: condition ids map onto the answer codes", () => {
  const expect: Record<number, string | null> = { 211: "storm", 301: "rain", 502: "rain", 601: "snow", 741: "fog", 721: null, 800: "clear", 801: "partly", 803: "cloudy" };
  for (const [id, kind] of Object.entries(expect)) assertEquals(conditionKind(Number(id)), kind, id);
});

Deno.test("openweathermap forecast: 3-hour steps become days in the city's own offset", async () => {
  const KEY = "owm-test-key-123456";
  const { ctx, seen } = ctxFor(openWeatherMap, { "data/2.5/forecast": { body: await fixture("openweathermap_forecast.json") } }, KEY);
  const { days } = await openWeatherMap.forecast!({ lat: 38.72, lon: -9.14 }, ctx);
  assertEquals(days.map((d) => d.date), ["2026-11-15", "2026-11-16", "2026-11-17", "2026-11-18", "2026-11-19", "2026-11-20"]);
  const by = Object.fromEntries(days.map((d) => [d.date, d]));
  assertEquals(by["2026-11-16"].code, "partly");
  assertEquals(by["2026-11-17"].code, "rain");
  assertEquals(by["2026-11-17"].precip_mm, 6.3);
  assertEquals(by["2026-11-17"].precip_prob, 80);
  assertEquals(by["2026-11-18"].code, "cloudy");
  assertEquals(by["2026-11-19"].code, "fog");
  assertEquals(by["2026-11-20"].code, "snow");
  assertEquals(by["2026-11-16"].precip_prob, 10);
  const url = new URL(seen[0].url);
  assertEquals(url.searchParams.get("appid"), KEY);
  assertEquals(url.searchParams.get("units"), "metric");
});

Deno.test("openweathermap: 401 is unauthorized, 429 quota, and the key is not in the error", async () => {
  const KEY = "owm-test-key-123456";
  for (const [status, code] of [[401, "unauthorized"], [429, "quota"], [500, "http_500"]] as const) {
    const { ctx } = ctxFor(openWeatherMap, { "data/2.5": { status, body: { cod: status, message: `Invalid API key ${KEY}` } } }, KEY);
    try {
      await openWeatherMap.forecast!(PALMA, ctx);
      throw new Error("expected an error");
    } catch (err) {
      assert(err instanceof ProviderError);
      assertEquals(err.code, code);
      assertEquals((String(err) + err.stack).includes(KEY), false);
    }
  }
});

Deno.test("openweathermap forecast: empty and malformed answers", async () => {
  const ask = (body: unknown) => openWeatherMap.forecast!(PALMA, ctxFor(openWeatherMap, { "/forecast": { body } }, "k").ctx);
  assertEquals(await codeOf(ask({ cod: "200", list: [] })), "no_data");
  assertEquals(await codeOf(ask({ cod: "200", list: [{ dt: 1 }] })), "bad_answer");
  assertEquals(await codeOf(ask({ cod: "200" })), "bad_answer");
  assertEquals(await codeOf(ask("x")), "bad_answer");
});

Deno.test("openweathermap geocode: the language's local name, the state as admin", async () => {
  const { ctx, seen } = ctxFor(openWeatherMap, { "geo/1.0/direct": { body: await fixture("openweathermap_geocode.json") } }, "k");
  const de = await openWeatherMap.geocode!({ q: "London", lang: "fr" }, ctx);
  assertEquals(de.places[0], { name: "Londres", country: "GB", admin: "England", lat: 51.5073219, lon: -0.1276474 });
  assertEquals(de.places[1].name, "London");
  assertEquals(new URL(seen[0].url).searchParams.get("q"), "London");
  const none = ctxFor(openWeatherMap, { "geo/1.0": { body: [] } }, "k").ctx;
  assertEquals(await openWeatherMap.geocode!({ q: "Zzz", lang: "en" }, none), { places: [] });
  const bad = ctxFor(openWeatherMap, { "geo/1.0": { body: { cod: "400" } } }, "k").ctx;
  assertEquals(await codeOf(openWeatherMap.geocode!({ q: "Zzz", lang: "en" }, bad)), "bad_answer");
});

// ---------------------------------------------------------------- meteostat

Deno.test("meteostat climate: the latest reference period, sunshine per day, key in a header only", async () => {
  const KEY = "rapid-key-abcdef123456";
  const { ctx, seen } = ctxFor(meteostat, { "meteostat.p.rapidapi.com/point/normals": { body: await fixture("meteostat_climate.json") } }, KEY);
  const { months } = await meteostat.climate!({ lat: 52.52, lon: 13.41 }, ctx);
  assertEquals(months.length, 12);
  assertEquals(months[0], { month: 1, tmax: -1.3, tmin: -6.3, precip_mm: 51, sun_hours: 1.3 }); // not the 1961-1990 period
  assertEquals(months[6].tmax, 23.2);
  assertEquals(seen[0].url.includes(KEY), false);
  const headers = new Headers(seen[0].init.headers);
  assertEquals(headers.get("x-rapidapi-key"), KEY);
  assertEquals(headers.get("x-rapidapi-host"), "meteostat.p.rapidapi.com");
  assertEquals(new URL(seen[0].url).searchParams.get("lat"), "52.52");
});

Deno.test("meteostat climate: no data, partial data, malformed, refused", async () => {
  const ask = (reply: Reply) => meteostat.climate!(PALMA, ctxFor(meteostat, { "/point/normals": reply }, "k").ctx);
  const rows = ((await fixture("meteostat_climate.json")) as { data: Record<string, unknown>[] }).data.filter((r) => r.start === 1991);
  assertEquals(await codeOf(ask({ body: { meta: {}, data: [] } })), "no_data");
  assertEquals(await codeOf(ask({ body: { data: rows.slice(0, 11) } })), "no_data");
  assertEquals(await codeOf(ask({ body: { data: rows.map((r) => ({ ...r, tmax: null })) } })), "no_data");
  assertEquals(await codeOf(ask({ body: { meta: {} } })), "bad_answer");
  assertEquals(await codeOf(ask({ status: 401 })), "unauthorized");
  assertEquals(await codeOf(ask({ status: 403 })), "unauthorized");
  assertEquals(await codeOf(ask({ status: 429 })), "quota");
});

// ---------------------------------------------------------------- openrouteservice

Deno.test("openrouteservice route: GeoJSON summary, lon,lat order, key in the header", async () => {
  const KEY = "ors-key-0123456789";
  const { ctx, seen } = ctxFor(openRouteService, { "v2/directions/driving-car": { body: await fixture("openrouteservice_route.json") } }, KEY);
  const route = await openRouteService.route!({ from: { lat: 39.57, lon: 2.65 }, to: { lat: 39.7, lon: 2.9 } }, ctx);
  assertEquals(route, { km: 24.5, minutes: 29 });
  assertEquals(seen[0].url.includes(KEY), false);
  assertEquals(new Headers(seen[0].init.headers).get("authorization"), KEY);
  assertEquals(new URL(seen[0].url).searchParams.get("start"), "2.65,39.57");
  assertEquals(new URL(seen[0].url).searchParams.get("end"), "2.9,39.7");
});

Deno.test("openrouteservice route: the JSON form, no route, malformed, refused", async () => {
  const ask = (reply: Reply) => openRouteService.route!({ from: PALMA, to: PALMA }, ctxFor(openRouteService, { "/directions/": reply }, "k").ctx);
  assertEquals(await ask({ body: { routes: [{ summary: { distance: 1500, duration: 90 } }] } }), { km: 1.5, minutes: 2 });
  assertEquals(await codeOf(ask({ body: { routes: [] } })), "no_data");
  assertEquals(await codeOf(ask({ body: { features: [] } })), "no_data");
  assertEquals(await codeOf(ask({ status: 404, body: { error: { code: 2010 } } })), "no_data");
  assertEquals(await codeOf(ask({ status: 400, body: { error: { code: 2004 } } })), "no_data");
  assertEquals(await codeOf(ask({ body: { features: [{ properties: {} }] } })), "bad_answer");
  assertEquals(await codeOf(ask({ body: { nothing: 1 } })), "bad_answer");
  assertEquals(await codeOf(ask({ status: 401 })), "unauthorized");
  assertEquals(await codeOf(ask({ status: 403, body: { error: "Access to this API has been disallowed" } })), "unauthorized");
  assertEquals(await codeOf(ask({ status: 429 })), "quota");
  assertEquals(await codeOf(ask({ status: 503 })), "http_503");
});

Deno.test("openrouteservice geocode: Pelias features with alpha-3 countries", async () => {
  const { ctx, seen } = ctxFor(openRouteService, { "geocode/search": { body: await fixture("openrouteservice_geocode.json") } }, "k");
  const { places } = await openRouteService.geocode!({ q: "Lisbon", lang: "en" }, ctx);
  assertEquals(places[0], { name: "Lisbon", country: "PT", admin: "Lisbon", lat: 38.7077507, lon: -9.1365919 });
  assertEquals(places[1], { name: "Lisbon", country: "US", admin: "North Dakota", lat: 46.4416, lon: -97.6812 });
  assertEquals(new URL(seen[0].url).searchParams.get("text"), "Lisbon");
  const none = ctxFor(openRouteService, { "geocode": { body: { type: "FeatureCollection", features: [] } } }, "k").ctx;
  assertEquals(await openRouteService.geocode!({ q: "Zzz", lang: "en" }, none), { places: [] });
  const bad = ctxFor(openRouteService, { "geocode": { body: { error: "x" } } }, "k").ctx;
  assertEquals(await codeOf(openRouteService.geocode!({ q: "Zzz", lang: "en" }, bad)), "bad_answer");
});

// ---------------------------------------------------------------- google

Deno.test("google geocode: the documented result shape and every status", async () => {
  const KEY = "AIza-test-key-0000000";
  const { ctx, seen } = ctxFor(google, { "maps/api/geocode/json": { body: await fixture("google_geocode.json") } }, KEY);
  const { places } = await google.geocode!({ q: "Lisbon", lang: "de" }, ctx);
  assertEquals(places, [{ name: "Lisbon", country: "PT", admin: "Lisbon", lat: 38.7222524, lon: -9.1393366 }]);
  assertEquals(new URL(seen[0].url).searchParams.get("language"), "de");

  const ask = (body: unknown, status = 200) => google.geocode!({ q: "x", lang: "en" }, ctxFor(google, { "geocode": { body, status } }, KEY).ctx);
  assertEquals(await ask({ status: "ZERO_RESULTS", results: [] }), { places: [] });
  assertEquals(await codeOf(ask({ status: "OVER_QUERY_LIMIT" })), "quota");
  assertEquals(await codeOf(ask({ status: "REQUEST_DENIED", error_message: `key ${KEY} is invalid` })), "unauthorized");
  assertEquals(await codeOf(ask({ status: "UNKNOWN_ERROR" })), "http_500");
  assertEquals(await codeOf(ask({ status: "INVALID_REQUEST" })), "bad_answer");
  assertEquals(await codeOf(ask({})), "bad_answer");
  assertEquals(await codeOf(ask({}, 403)), "unauthorized");
  assertEquals(await codeOf(ask({}, 429)), "quota");
});

Deno.test("google route: Routes API with a minimal field mask, key in a header", async () => {
  const KEY = "AIza-test-key-0000000";
  const { ctx, seen } = ctxFor(google, { "routes.googleapis.com/directions/v2:computeRoutes": { body: await fixture("google_route.json") } }, KEY);
  const route = await google.route!({ from: { lat: 39.57, lon: 2.65 }, to: { lat: 39.7, lon: 2.9 } }, ctx);
  assertEquals(route, { km: 24.5, minutes: 29 });
  const { url, init } = seen[0];
  assertEquals(url.includes(KEY), false);
  assertEquals(init.method, "POST");
  const headers = new Headers(init.headers);
  assertEquals(headers.get("x-goog-api-key"), KEY);
  assertEquals(headers.get("x-goog-fieldmask"), "routes.distanceMeters,routes.duration");
  const body = JSON.parse(String(init.body));
  assertEquals(body.origin.location.latLng, { latitude: 39.57, longitude: 2.65 });
  assertEquals(body.travelMode, "DRIVE");
  assertEquals(body.routingPreference, undefined); // the cheapest tier

  const ask = (reply: Reply) => google.route!({ from: PALMA, to: PALMA }, ctxFor(google, { "computeRoutes": reply }, KEY).ctx);
  assertEquals(await codeOf(ask({ body: {} })), "no_data");
  assertEquals(await codeOf(ask({ body: { routes: [] } })), "no_data");
  assertEquals(await codeOf(ask({ body: { routes: [{ distanceMeters: 5 }] } })), "bad_answer");
  assertEquals(await codeOf(ask({ body: { routes: [{ distanceMeters: 5, duration: "soon" }] } })), "bad_answer");
  assertEquals(await codeOf(ask({ status: 403, body: { error: { status: "PERMISSION_DENIED" } } })), "unauthorized");
  assertEquals(await codeOf(ask({ status: 429 })), "quota");
});

Deno.test("google map: a PNG becomes base64, anything else is a bad answer; no URL in errors", async () => {
  const KEY = "AIza-test-key-0000000";
  const png = Uint8Array.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3, 4]);
  const q = { lat: 39.57, lon: 2.65, zoom: 9, width: 300, height: 200 };
  const { ctx, seen } = ctxFor(google, { "maps/api/staticmap": { bytes: png, headers: { "content-type": "image/png" } } }, KEY);
  const image = await google.map!(q, ctx);
  assertEquals(image.mime, "image/png");
  assertEquals([...Uint8Array.from(atob(image.image_base64), (c) => c.charCodeAt(0))], [...png]);
  const url = new URL(seen[0].url);
  assertEquals([url.searchParams.get("center"), url.searchParams.get("zoom"), url.searchParams.get("size")], ["39.57,2.65", "9", "300x200"]);
  assertEquals(url.searchParams.get("key"), KEY);

  const ask = (reply: Reply) => google.map!(q, ctxFor(google, { "staticmap": reply }, KEY).ctx);
  assertEquals(await codeOf(ask({ bytes: new TextEncoder().encode("<html>nope</html>") })), "bad_answer");
  for (const status of [403, 400, 500]) {
    try {
      await ask({ status });
      throw new Error("expected an error");
    } catch (err) {
      assert(err instanceof ProviderError);
      assertEquals((String(err) + err.stack).includes(KEY), false);
    }
  }
  assertEquals(await codeOf(ask({ status: 403 })), "unauthorized");
});

Deno.test("google map: a picture over 6 MB is refused", async () => {
  const q = { lat: 1, lon: 1, zoom: 9, width: 300, height: 200 };
  const base = (() => Promise.resolve(new Response("x", { headers: { "content-length": String(7 * 1024 * 1024) } }))) as typeof fetch;
  const ctx = { key: "k", fetch: guardedFetch(google, base, 6 * 1024 * 1024), signal: new AbortController().signal };
  assertEquals(await codeOf(google.map!(q, ctx)), "too_large");
});

// ---------------------------------------------------------------- every plug-in

Deno.test("every plug-in only reaches its declared hosts (an undeclared one fails as forbidden_host)", async () => {
  // A fetch that answers anything with an empty object: parsing fails, but only after the host check.
  for (const provider of PROVIDERS) {
    const seen: string[] = [];
    const base = ((input: string | URL | Request) => {
      seen.push(new URL(String(input)).hostname);
      return Promise.resolve(new Response("{}"));
    }) as typeof fetch;
    const ctx = { key: "k-0123456789", fetch: guardedFetch(provider, base), signal: new AbortController().signal };
    const queries = {
      climate: PALMA,
      forecast: PALMA,
      geocode: { q: "Lisbon", lang: "en" },
      route: { from: PALMA, to: PALMA },
      map: { ...PALMA, zoom: 9, width: 300, height: 200 },
    } as const;
    for (const [cap, q] of Object.entries(queries)) {
      const fn = provider[cap as keyof typeof queries] as ((q: unknown, c: ProviderContext) => Promise<unknown>) | undefined;
      if (!fn) continue;
      try {
        await fn.call(provider, q, ctx);
      } catch (err) {
        assert(err instanceof ProviderError, `${provider.id} ${cap}: ${err}`);
        assert(err.code !== "forbidden_host", `${provider.id} ${cap} reached a host it did not declare`);
      }
    }
    assert(seen.length > 0, provider.id);
    for (const h of seen) assert(provider.hosts.includes(h), `${provider.id} called ${h}`);
  }
});
