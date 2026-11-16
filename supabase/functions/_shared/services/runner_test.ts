import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { makeServices, normaliseQuery, type CacheRow, type ChainEntry, type ServiceDb } from "./runner.ts";
import {
  CACHE_TTL_SECONDS,
  cacheKey,
  type Capability,
  type Forecast,
  type Provider,
  ProviderError,
  ServiceError,
} from "./types.ts";

const NOW = new Date("2026-11-15T12:00:00Z");
const DAY: Forecast = {
  days: [{ date: "2026-11-16", tmax: 20, tmin: 10, precip_mm: 0, code: "clear" }],
};
const AT = { lat: 39.5712, lon: 2.6498 };
const ROUNDED = { lat: 39.57, lon: 2.65 };

/** A provider with a forecast that runs `run`, and a call counter. */
function fake(
  id: string,
  run: (q: { lat: number; lon: number }, key: string | null) => Promise<Forecast> | Forecast = () => DAY,
  extra: Partial<Provider> = {},
): Provider & { calls: number } {
  const p: Provider & { calls: number } = {
    id,
    name: id,
    homepage: "https://example.org",
    key_url: null,
    needs_key: false,
    cost: "free",
    receives: ["coordinates"],
    attribution: `by ${id}`,
    hosts: ["api.example.org"],
    budget: { per_day: 10 },
    docs: [],
    calls: 0,
    forecast: (q, ctx) => {
      p.calls++;
      return Promise.resolve(run(q, ctx.key));
    },
    ...extra,
  };
  return p;
}

type Recorded = {
  reports: [string, boolean, string | null][];
  puts: { key: string; capability: Capability; provider: string; payload: unknown; ttl: number }[];
  secretReads: number;
  getKeys: string[][];
};

function fakeDb(
  opts: {
    secrets?: Record<string, string>;
    cache?: Record<string, CacheRow>;
    recent?: number;
    /** Fetches counted per window length in seconds; wins over `recent`. */
    recentBy?: Record<number, number>;
    reportFails?: boolean;
  } = {},
): ServiceDb & Recorded {
  const rec: Recorded = { reports: [], puts: [], secretReads: 0, getKeys: [] };
  return Object.assign(rec, {
    secrets() {
      rec.secretReads++;
      return Promise.resolve(opts.secrets ?? {});
    },
    report(provider: string, ok: boolean, error: string | null) {
      rec.reports.push([provider, ok, error]);
      return opts.reportFails ? Promise.reject(new Error("db down")) : Promise.resolve(null);
    },
    cacheGet(keys: string[]) {
      rec.getKeys.push(keys);
      const out: Record<string, CacheRow> = {};
      for (const k of keys) if (opts.cache?.[k]) out[k] = opts.cache[k];
      return Promise.resolve(out);
    },
    cachePut(key: string, capability: Capability, provider: string, payload: unknown, ttl: number) {
      rec.puts.push({ key, capability, provider, payload, ttl });
      return Promise.resolve();
    },
    cacheRecent(_provider: string, _capability: Capability, seconds: number) {
      return Promise.resolve(opts.recentBy?.[seconds] ?? opts.recent ?? 0);
    },
  });
}

const entry = (provider: string, has_key = false, calls_today = 0): ChainEntry => ({
  provider,
  has_key,
  calls_today,
});

function runnerOf(
  providers: Provider[],
  chain: ChainEntry[],
  db: ServiceDb,
  extra: { fetch?: typeof fetch; timeoutMs?: number } = {},
) {
  return makeServices({
    household: "h1",
    chain,
    registry: providers,
    db,
    fetch: extra.fetch ?? (() => Promise.reject(new Error("no network in tests"))),
    now: () => NOW,
    timeoutMs: extra.timeoutMs,
  });
}

async function codeOf(p: Promise<unknown>): Promise<string> {
  try {
    await p;
  } catch (err) {
    if (err instanceof ServiceError) return err.code;
    throw err;
  }
  throw new Error("expected a ServiceError");
}

// ---------------------------------------------------------------- order, cache, reporting

Deno.test("ask: the first provider of the household's order answers, the others are not asked", async () => {
  const a = fake("aaa");
  const b = fake("bbb");
  const db = fakeDb();
  const s = runnerOf([b, a], [entry("aaa"), entry("bbb")], db);
  const answer = await s.ask("forecast", AT);
  assertEquals(answer, { data: DAY, provider: "aaa", attribution: "by aaa", cached: false });
  assertEquals([a.calls, b.calls], [1, 0]);
  assertEquals(db.reports, [["aaa", true, null]]);
});

Deno.test("ask: the answer is cached under the rounded question with the capability's lifetime", async () => {
  const db = fakeDb();
  await runnerOf([fake("aaa")], [entry("aaa")], db).ask("forecast", AT);
  assertEquals(db.puts.length, 1);
  assertEquals(db.puts[0].key, cacheKey("forecast", "aaa", ROUNDED));
  assertEquals(db.puts[0].key, "forecast:aaa:39.57,2.65");
  assertEquals(db.puts[0].ttl, CACHE_TTL_SECONDS.forecast);
  assertEquals(db.puts[0].provider, "aaa");
});

Deno.test("ask: coordinates are rounded to two decimals before the provider sees them", async () => {
  let seen: unknown = null;
  const a = fake("aaa", (q) => {
    seen = q;
    return DAY;
  });
  await runnerOf([a], [entry("aaa")], fakeDb()).ask("forecast", AT);
  assertEquals(seen, ROUNDED);
});

Deno.test("normaliseQuery: routes, text and maps", () => {
  assertEquals(
    normaliseQuery("route", { from: { lat: 1.234, lon: 2.345 }, to: { lat: -3.456, lon: 4.567 } }),
    { from: { lat: 1.23, lon: 2.35 }, to: { lat: -3.46, lon: 4.57 } },
  );
  assertEquals(normaliseQuery("geocode", { q: "  Santa   Cruz ", lang: "de" }), { q: "Santa Cruz", lang: "de" });
  assertEquals(
    normaliseQuery("map", { lat: 1.234, lon: 2.345, zoom: 9, width: 300, height: 200 }),
    { lat: 1.23, lon: 2.35, zoom: 9, width: 300, height: 200 },
  );
});

Deno.test("ask: a cached answer is returned without a provider call and without a report", async () => {
  const a = fake("aaa");
  const key = cacheKey("forecast", "aaa", ROUNDED);
  const db = fakeDb({
    cache: { [key]: { payload: DAY, provider: "aaa", fetched_at: "2026-11-15T11:00:00Z" } },
  });
  const answer = await runnerOf([a], [entry("aaa")], db).ask("forecast", AT);
  assertEquals(answer.cached, true);
  assertEquals(answer.data, DAY);
  assertEquals(a.calls, 0);
  assertEquals(db.reports, []);
  assertEquals(db.puts, []);
});

Deno.test("ask: a cache row older than the capability's lifetime is not used", async () => {
  const a = fake("aaa");
  const key = cacheKey("forecast", "aaa", ROUNDED);
  const db = fakeDb({
    cache: { [key]: { payload: DAY, provider: "aaa", fetched_at: "2026-11-15T08:00:00Z" } }, // 4 h > 3 h
  });
  const answer = await runnerOf([a], [entry("aaa")], db).ask("forecast", AT);
  assertEquals(answer.cached, false);
  assertEquals(a.calls, 1);
});

Deno.test("ask: an earlier provider is asked first; a later one's cache entry answers only after it fails", async () => {
  // The first provider is asked first when it has no cache entry; only when it fails does the
  // second one's cache entry answer.
  const a = fake("aaa", () => {
    throw new ProviderError("http_500");
  });
  const b = fake("bbb");
  const db = fakeDb({
    cache: {
      [cacheKey("forecast", "bbb", ROUNDED)]: {
        payload: DAY,
        provider: "bbb",
        fetched_at: "2026-11-15T11:30:00Z",
      },
    },
  });
  const answer = await runnerOf([a, b], [entry("aaa"), entry("bbb")], db).ask("forecast", AT);
  assertEquals([answer.provider, answer.cached, a.calls, b.calls], ["bbb", true, 1, 0]);
});

Deno.test("ask: a failure falls through to the next provider and is reported with its code", async () => {
  const a = fake("aaa", () => {
    throw new ProviderError("http_503");
  });
  const b = fake("bbb");
  const db = fakeDb();
  const answer = await runnerOf([a, b], [entry("aaa"), entry("bbb")], db).ask("forecast", AT);
  assertEquals(answer.provider, "bbb");
  assertEquals(db.reports, [["aaa", false, "http_503"], ["bbb", true, null]]);
});

Deno.test("ask: a plug-in that throws something unexpected is reported as bad_answer, nothing leaks", async () => {
  const a = fake("aaa", () => {
    throw new TypeError("Cannot read properties of undefined (reading 'x') https://x/?appid=SECRET1234");
  });
  const db = fakeDb();
  const code = await codeOf(runnerOf([a], [entry("aaa")], db).ask("forecast", AT));
  assertEquals(code, "service_failed");
  assertEquals(db.reports, [["aaa", false, "bad_answer"]]);
});

Deno.test("ask: no_data is reported as a good call, the next provider is asked", async () => {
  const a = fake("aaa", () => {
    throw new ProviderError("no_data");
  });
  const b = fake("bbb");
  const db = fakeDb();
  const answer = await runnerOf([a, b], [entry("aaa"), entry("bbb")], db).ask("forecast", AT);
  assertEquals(answer.provider, "bbb");
  assertEquals(db.reports, [["aaa", true, null], ["bbb", true, null]]);
});

Deno.test("ask: when every provider has no data the error is service_failed", async () => {
  const a = fake("aaa", () => {
    throw new ProviderError("no_data");
  });
  assertEquals(await codeOf(runnerOf([a], [entry("aaa")], fakeDb()).ask("forecast", AT)), "service_failed");
});

Deno.test("ask: a failing report does not stop the answer", async () => {
  const answer = await runnerOf([fake("aaa")], [entry("aaa")], fakeDb({ reportFails: true })).ask("forecast", AT);
  assertEquals(answer.provider, "aaa");
});

// ---------------------------------------------------------------- off, keys, limits

Deno.test("ask: service_off when no enabled provider offers the capability", async () => {
  const a = fake("aaa");
  assertEquals(await codeOf(runnerOf([a], [entry("aaa")], fakeDb()).ask("climate", AT)), "service_off");
  assertEquals(await codeOf(runnerOf([a], [], fakeDb()).ask("forecast", AT)), "service_off");
  // A provider in the chain that this server does not know is ignored.
  assertEquals(await codeOf(runnerOf([a], [entry("zzz")], fakeDb()).ask("forecast", AT)), "service_off");
});

Deno.test("offers: the enabled providers that have the capability, in the household's order", () => {
  const a = fake("aaa");
  const b = fake("bbb", undefined, { geocode: () => Promise.resolve({ places: [] }) });
  const s = runnerOf([a, b], [entry("bbb"), entry("aaa")], fakeDb());
  assertEquals(s.offers("forecast"), ["bbb", "aaa"]);
  assertEquals(s.offers("geocode"), ["bbb"]);
  assertEquals(s.offers("map"), []);
});

Deno.test("ask: a provider that needs a key and has none is skipped; the secrets are not read", async () => {
  const a = fake("aaa", undefined, { needs_key: true });
  const b = fake("bbb");
  const db = fakeDb();
  const answer = await runnerOf([a, b], [entry("aaa", false), entry("bbb")], db).ask("forecast", AT);
  assertEquals([answer.provider, a.calls, db.secretReads], ["bbb", 0, 0]);
  assertEquals(
    await codeOf(runnerOf([a], [entry("aaa", false)], fakeDb()).ask("forecast", AT)),
    "service_key_missing",
  );
});

Deno.test("ask: a key flagged as present but absent from the secrets counts as missing", async () => {
  const a = fake("aaa", undefined, { needs_key: true });
  const code = await codeOf(runnerOf([a], [entry("aaa", true)], fakeDb({ secrets: {} })).ask("forecast", AT));
  assertEquals(code, "service_key_missing");
  assertEquals(a.calls, 0);
});

Deno.test("secrets: read lazily, once, and only for a provider that needs a key", async () => {
  const keyless = fake("aaa");
  const keyed = fake("bbb", (_q, key) => ({ days: [{ ...DAY.days[0], tmax: key === "the-key-1234" ? 21 : 0 }] }), {
    needs_key: true,
  });

  const db1 = fakeDb({ secrets: { bbb: "the-key-1234" } });
  const s1 = runnerOf([keyless, keyed], [entry("aaa"), entry("bbb", true)], db1);
  await s1.ask("forecast", AT);
  assertEquals(db1.secretReads, 0); // the keyless provider answered

  const db2 = fakeDb({ secrets: { bbb: "the-key-1234" } });
  const s2 = runnerOf([keyed], [entry("bbb", true)], db2);
  const first = await s2.ask("forecast", AT);
  await s2.ask("forecast", { lat: 10, lon: 10 });
  assertEquals((first.data as Forecast).days[0].tmax, 21); // the plug-in got the key
  assertEquals(db2.secretReads, 1);
});

Deno.test("ask: a provider at its daily ceiling is skipped; the next one answers", async () => {
  const a = fake("aaa", undefined, { budget: { per_day: 5 } });
  const b = fake("bbb");
  const db = fakeDb();
  const answer = await runnerOf([a, b], [entry("aaa", false, 5), entry("bbb")], db).ask("forecast", AT);
  assertEquals([answer.provider, a.calls], ["bbb", 0]);
  assertEquals(
    await codeOf(runnerOf([a], [entry("aaa", false, 5)], fakeDb()).ask("forecast", AT)),
    "service_limit",
  );
});

Deno.test("ask: the calls of this request count against the ceiling", async () => {
  const a = fake("aaa", undefined, { budget: { per_day: 2 } });
  const s = runnerOf([a], [entry("aaa", false, 1)], fakeDb());
  await s.ask("forecast", { lat: 1, lon: 1 });
  assertEquals(await codeOf(s.ask("forecast", { lat: 2, lon: 2 })), "service_limit");
});

Deno.test("ask: climate waits for the hourly budget of the provider", async () => {
  const climate = () => Promise.resolve({ months: [] });
  const a = fake("aaa", undefined, { climate, budget: { per_day: 50, climate_per_hour: 2 } });
  assertEquals(
    await codeOf(runnerOf([a], [entry("aaa")], fakeDb({ recent: 2 })).ask("climate", AT)),
    "service_limit",
  );
  assertEquals((await runnerOf([a], [entry("aaa")], fakeDb({ recent: 1 })).ask("climate", AT)).provider, "aaa");
});

Deno.test("climate: the minute's, the hour's and the day's ceiling each hold, the tightest wins", async () => {
  const climate = () => Promise.resolve({ months: [] });
  const budget = { per_day: 500, climate_per_minute: 3, climate_per_hour: 20, climate_per_day: 48 };
  const a = fake("aaa", undefined, { climate, budget });
  const left = (recentBy: Record<number, number>) => runnerOf([a], [entry("aaa")], fakeDb({ recentBy })).climateBudget();
  assertEquals(await left({ 60: 0, 3600: 0, 86400: 0 }), 3);
  assertEquals(await left({ 60: 2, 3600: 5, 86400: 5 }), 1);
  assertEquals(await left({ 60: 0, 3600: 19, 86400: 30 }), 1);
  assertEquals(await left({ 60: 0, 3600: 0, 86400: 48 }), 0);
  assertEquals(
    await codeOf(runnerOf([a], [entry("aaa")], fakeDb({ recentBy: { 60: 3, 3600: 3, 86400: 3 } })).ask("climate", AT)),
    "service_limit",
  );
});

Deno.test("climateBudget: what the first offering provider still allows this hour", async () => {
  const climate = () => Promise.resolve({ months: [] });
  const a = fake("aaa", undefined, { climate, budget: { per_day: 50, climate_per_hour: 5 } });
  assertEquals(await runnerOf([a], [entry("aaa")], fakeDb({ recent: 2 })).climateBudget(), 3);
  assertEquals(await runnerOf([a], [entry("aaa")], fakeDb({ recent: 9 })).climateBudget(), 0);
  assertEquals(await runnerOf([a], [entry("aaa", false, 48)], fakeDb()).climateBudget(), 2); // the day's ceiling
  assertEquals(await runnerOf([fake("bbb")], [entry("bbb")], fakeDb()).climateBudget(), 0); // no climate
  const keyed = fake("kkk", undefined, { climate, needs_key: true, budget: { per_day: 50, climate_per_hour: 5 } });
  assertEquals(await runnerOf([keyed], [entry("kkk", false)], fakeDb()).climateBudget(), 0);
});

Deno.test("ask: the error names failed before limit before key_missing", async () => {
  const failing = fake("fff", () => {
    throw new ProviderError("http_500");
  });
  const full = fake("ccc", undefined, { budget: { per_day: 1 } });
  const keyed = fake("kkk", undefined, { needs_key: true });
  const chain = [entry("kkk", false), entry("ccc", false, 1), entry("fff")];
  assertEquals(await codeOf(runnerOf([keyed, full, failing], chain, fakeDb()).ask("forecast", AT)), "service_failed");
  assertEquals(
    await codeOf(runnerOf([keyed, full], chain.slice(0, 2), fakeDb()).ask("forecast", AT)),
    "service_limit",
  );
  assertEquals(await codeOf(runnerOf([keyed], chain.slice(0, 1), fakeDb()).ask("forecast", AT)), "service_key_missing");
});

// ---------------------------------------------------------------- the guarded fetch inside the runner

Deno.test("ask: a plug-in that reaches for another host fails with forbidden_host and nothing is sent", async () => {
  let sent = 0;
  const evil = fake("aaa", undefined, {
    forecast: async (_q, ctx) => {
      await ctx.fetch("https://evil.example.net/steal");
      return DAY;
    },
  });
  const db = fakeDb();
  const s = runnerOf([evil], [entry("aaa")], db, {
    fetch: () => {
      sent++;
      return Promise.resolve(new Response("{}"));
    },
  });
  assertEquals(await codeOf(s.ask("forecast", AT)), "service_failed");
  assertEquals(db.reports, [["aaa", false, "forbidden_host"]]);
  assertEquals(sent, 0);
});

Deno.test("ask: a key in the URL never reaches a report, an error or the cache", async () => {
  const KEY = "sk-very-secret-key-0001";
  const p = fake("aaa", undefined, {
    needs_key: true,
    forecast: async (_q, ctx) => {
      await ctx.fetch(`https://api.example.org/forecast?appid=${ctx.key}`);
      return DAY;
    },
  });
  const db = fakeDb({ secrets: { aaa: KEY } });
  const s = runnerOf([p], [entry("aaa", true)], db, {
    // The transport error of a real fetch names the URL, key included.
    fetch: (url) => Promise.reject(new TypeError(`error sending request for url (${url})`)),
  });
  let thrown: unknown;
  try {
    await s.ask("forecast", AT);
  } catch (err) {
    thrown = err;
  }
  assert(thrown instanceof ServiceError);
  assertEquals(JSON.stringify([db.reports, db.puts, String(thrown), (thrown as Error).stack]).includes(KEY), false);
  assertEquals(db.reports, [["aaa", false, "unreachable"]]);
});

Deno.test("ask: an answer that contains the key is not cached or returned", async () => {
  const KEY = "sk-very-secret-key-0002";
  const p = fake("aaa", (_q, key) => ({ days: [{ ...DAY.days[0], date: `x${key}` }] }), { needs_key: true });
  const db = fakeDb({ secrets: { aaa: KEY } });
  assertEquals(await codeOf(runnerOf([p], [entry("aaa", true)], db).ask("forecast", AT)), "service_failed");
  assertEquals(db.puts, []);
  assertEquals(db.reports, [["aaa", false, "bad_answer"]]);
});

Deno.test("ask: a call that outlasts the timeout is reported as timeout", async () => {
  const slow = fake("aaa", undefined, {
    forecast: (_q, ctx) =>
      new Promise((_resolve, reject) => {
        ctx.signal.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")));
      }),
  });
  const db = fakeDb();
  const s = runnerOf([slow], [entry("aaa")], db, { timeoutMs: 20 });
  assertEquals(await codeOf(s.ask("forecast", AT)), "service_failed");
  assertEquals(db.reports, [["aaa", false, "timeout"]]);
});

// ---------------------------------------------------------------- cached()

Deno.test("cached: one cache read for many questions; nothing is contacted", async () => {
  const a = fake("aaa");
  const hit = { payload: DAY, provider: "aaa", fetched_at: "2026-11-15T11:00:00Z" };
  const db = fakeDb({ cache: { [cacheKey("forecast", "aaa", { lat: 1, lon: 1 })]: hit } });
  const s = runnerOf([a], [entry("aaa")], db);
  const out = await s.cached("forecast", [{ lat: 1.001, lon: 0.999 }, { lat: 2, lon: 2 }]);
  assertEquals(out[0], { data: DAY, provider: "aaa", attribution: "by aaa", cached: true });
  assertEquals(out[1], null);
  assertEquals(db.getKeys.length, 1);
  assertEquals(a.calls, 0);
  assertEquals(db.reports, []);
});

Deno.test("cached: nulls when no provider offers it", async () => {
  const s = runnerOf([fake("aaa")], [entry("aaa")], fakeDb());
  assertEquals(await s.cached("climate", [AT, AT]), [null, null]);
});

// ---------------------------------------------------------------- test()

Deno.test("test: a working provider answers ok and the call is reported", async () => {
  const a = fake("aaa");
  const db = fakeDb();
  assertEquals(await runnerOf([a], [entry("aaa")], db).test("aaa"), { ok: true });
  assertEquals(db.reports, [["aaa", true, null]]);
});

Deno.test("test: the plug-in's own test is used, and its failure is reported with the code", async () => {
  const a = fake("aaa", undefined, {
    needs_key: true,
    test: () => Promise.reject(new ProviderError("unauthorized")),
  });
  const db = fakeDb({ secrets: { aaa: "the-key-1234" } });
  assertEquals(await runnerOf([a], [entry("aaa", true)], db).test("aaa"), { ok: false, error: "unauthorized" });
  assertEquals(db.reports, [["aaa", false, "unauthorized"]]);
  assertEquals(a.calls, 0);
});

Deno.test("test: a provider that is off or lacks its key is refused without a call", async () => {
  const a = fake("aaa", undefined, { needs_key: true });
  const s = runnerOf([a], [entry("aaa", false)], fakeDb());
  assertEquals(await s.test("aaa"), { ok: false, error: "service_key_missing" });
  assertEquals(await s.test("bbb"), { ok: false, error: "service_off" });
  assertEquals(a.calls, 0);
});
