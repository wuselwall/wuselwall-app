// The services runner (ADR-023, specs/30 "Services"): asks the household's providers in the
// household's order and returns the first answer. The Edge Functions `services` and `trips` get
// a `Services` from `openServices` and nothing else, so no provider is contacted for a caller
// the database refused.
//
// The one use of the service-role key with a user in the request (like calendar-import):
// `api.service_request` runs AS THE CALLER first (adult, no kiosk, device and household, the
// guardian for a null capability); only when it succeeded does the service role read the keys
// (`service_secrets`), count the call (`service_report`) and read and write the shared cache.
//
// Everything stateful is injected into `makeServices` (database, fetch, clock), so the tests
// run without a network or a database; `openServices` wires the real ones.
//
// When no provider answers, the error is the most specific reason that was seen, in this order:
// `service_failed` (some provider was really asked and failed, or had no data), then
// `service_limit` (a ceiling stopped it; trying later helps), then `service_key_missing` (a
// setup problem the guardian can fix). `service_off` only when no enabled provider offers the
// capability at all.
import { RequestError, serviceClient, userClient } from "../client.ts";
import { CALL_TIMEOUT_MS, guardedFetch, MAX_BODY_BYTES, MAX_IMAGE_BYTES } from "./http.ts";
import { findProvider, PROVIDERS } from "./registry.ts";
import {
  type Answer,
  type AnswerOf,
  CACHE_TTL_SECONDS,
  cacheKey,
  type Capability,
  type ClimateQuery,
  type ForecastQuery,
  type GeocodeQuery,
  type LatLon,
  type MapQuery,
  type Provider,
  type ProviderContext,
  ProviderError,
  type QueryOf,
  type RouteQuery,
  ServiceError,
  type ServiceErrorCode,
  type Services,
} from "./types.ts";

// ---------------------------------------------------------------- the injected pieces

/** One enabled provider of the household, as `api.service_request` lists them. */
export type ChainEntry = { provider: string; has_key: boolean; calls_today: number };

export type CacheRow = { payload: unknown; provider: string; fetched_at: string };

/** The service-role side: every call is one of the service-only `api.service_*` functions. */
export type ServiceDb = {
  /** `{provider: key}` of the household's enabled providers. */
  secrets(): Promise<Record<string, string>>;
  /** Counts the call and records its outcome; the new count of today, or null when unknown. */
  report(provider: string, ok: boolean, error: string | null): Promise<number | null>;
  cacheGet(keys: string[]): Promise<Record<string, CacheRow>>;
  cachePut(
    key: string,
    capability: Capability,
    provider: string,
    payload: unknown,
    ttlSeconds: number,
  ): Promise<void>;
  /** Cache rows the provider wrote for the capability in the last `seconds`. */
  cacheRecent(provider: string, capability: Capability, seconds: number): Promise<number>;
};

export type RunnerDeps = {
  household: string;
  /** The household's enabled providers, in its order. */
  chain: ChainEntry[];
  registry: readonly Provider[];
  db: ServiceDb;
  fetch: typeof fetch;
  now: () => Date;
  /** Per provider call; defaults to CALL_TIMEOUT_MS. */
  timeoutMs?: number;
};

/** A `Services` that can also run the guardian's "test this provider". */
export type ServicesRunner = Services & {
  test(providerId: string): Promise<{ ok: true } | { ok: false; error: string }>;
};

// ---------------------------------------------------------------- queries

const round2 = (n: number) => Math.round(n * 100) / 100;
const point = (p: LatLon): LatLon => ({ lat: round2(p.lat), lon: round2(p.lon) });

/**
 * The question as a provider may see it (ADR-023: as little as the question needs):
 * coordinates to two decimals (home and route points included), search text trimmed and
 * single-spaced. The cache key is built from the same.
 */
export function normaliseQuery<C extends Capability>(capability: C, query: QueryOf[C]): QueryOf[C] {
  switch (capability) {
    case "climate":
    case "forecast":
      return point(query as ClimateQuery | ForecastQuery) as QueryOf[C];
    case "geocode": {
      const g = query as GeocodeQuery;
      return { q: g.q.trim().replace(/\s+/g, " "), lang: g.lang } as QueryOf[C];
    }
    case "route": {
      const r = query as RouteQuery;
      return { from: point(r.from), to: point(r.to) } as QueryOf[C];
    }
    default: {
      const m = query as MapQuery;
      return { ...point(m), zoom: m.zoom, width: m.width, height: m.height } as QueryOf[C];
    }
  }
}

// ---------------------------------------------------------------- the runner

function failureCode(err: unknown): string {
  if (err instanceof ProviderError) {
    return /^[a-z0-9_]{1,40}$/.test(err.code) ? err.code : "bad_answer";
  }
  if (err instanceof Error && (err.name === "AbortError" || err.name === "TimeoutError")) {
    return "timeout";
  }
  // Anything else is a plug-in reading an answer it did not expect. The message is not kept:
  // it could name the URL, which for some providers carries the key.
  return "bad_answer";
}

/** Fixed small questions for the guardian's test, the cheapest capability first. */
const TEST_ORDER: Capability[] = ["geocode", "forecast", "route", "climate", "map"];
const PALMA: LatLon = { lat: 39.57, lon: 2.65 };
const TEST_QUERY: { [C in Capability]: QueryOf[C] } = {
  geocode: { q: "Lisbon", lang: "en" },
  forecast: PALMA,
  route: { from: PALMA, to: { lat: 39.7, lon: 2.9 } },
  climate: PALMA,
  map: { ...PALMA, zoom: 9, width: 100, height: 100 },
};

export function makeServices(deps: RunnerDeps): ServicesRunner {
  const { chain, db, registry } = deps;
  const timeoutMs = deps.timeoutMs ?? CALL_TIMEOUT_MS;
  const calls = new Map(chain.map((c) => [c.provider, c.calls_today]));
  let secrets: Promise<Record<string, string>> | null = null;

  /** The household's providers that offer the capability, in the household's order. */
  const candidates = (capability: Capability) =>
    chain.flatMap((entry) => {
      const provider = findProvider(entry.provider, registry);
      return provider && typeof provider[capability] === "function" ? [{ entry, provider }] : [];
    });

  /** Read once, and only when a provider that needs a key is about to be called. */
  /**
   * How many more climate fetches the provider's own budgets allow now. The fetches of the
   * last minute, hour and day are counted from the cache, which is the server's and not one
   * household's: a keyless provider limits the server's address. If the count cannot be
   * read, nothing is allowed.
   */
  const climateLeft = async (provider: Provider): Promise<number> => {
    const windows: [number | undefined, number][] = [
      [provider.budget.climate_per_minute, 60],
      [provider.budget.climate_per_hour, 3600],
      [provider.budget.climate_per_day, 86400],
    ];
    let left = Infinity;
    for (const [max, seconds] of windows) {
      if (max === undefined) continue;
      const recent = await db.cacheRecent(provider.id, "climate", seconds).catch(() => Infinity);
      left = Math.min(left, max - recent);
    }
    return left;
  };

  const keyOf = async (provider: Provider): Promise<string | null> => {
    if (!provider.needs_key) return null;
    secrets ??= db.secrets();
    const all = await secrets;
    const key = all[provider.id];
    return typeof key === "string" && key !== "" ? key : null;
  };

  const countCall = async (provider: Provider, ok: boolean, code: string | null) => {
    const before = calls.get(provider.id) ?? 0;
    calls.set(provider.id, before + 1);
    try {
      const today = await db.report(provider.id, ok, code);
      if (typeof today === "number") calls.set(provider.id, today);
    } catch {
      // The count is bookkeeping; the answer stands.
    }
  };

  /** Calls one plug-in with the guarded fetch and a timeout. Never returns a key. */
  const callProvider = async <C extends Capability>(
    provider: Provider,
    capability: C,
    query: QueryOf[C],
    key: string | null,
  ): Promise<{ data: AnswerOf[C] } | { code: string }> => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const ctx: ProviderContext = {
        key,
        fetch: guardedFetch(provider, deps.fetch, capability === "map" ? MAX_IMAGE_BYTES : MAX_BODY_BYTES),
        signal: controller.signal,
      };
      const fn = provider[capability] as unknown as (q: QueryOf[C], c: ProviderContext) => Promise<AnswerOf[C]>;
      const data = await fn.call(provider, query, ctx);
      // A plug-in bug must not put the household's key into the shared cache.
      if (key !== null && key.length >= 8 && JSON.stringify(data).includes(key)) {
        return { code: "bad_answer" };
      }
      return { data };
    } catch (err) {
      return { code: failureCode(err) };
    } finally {
      clearTimeout(timer);
    }
  };

  const fresh = (row: CacheRow | undefined, capability: Capability): AnswerOf[Capability] | null => {
    if (!row || row.payload === null || typeof row.payload !== "object") return null;
    const age = deps.now().getTime() - Date.parse(row.fetched_at);
    if (!Number.isFinite(age) || age > CACHE_TTL_SECONDS[capability] * 1000) return null;
    return row.payload as AnswerOf[Capability];
  };

  const safeCacheGet = async (keys: string[]): Promise<Record<string, CacheRow>> => {
    const out: Record<string, CacheRow> = {};
    for (let i = 0; i < keys.length; i += 200) {
      try {
        Object.assign(out, await db.cacheGet(keys.slice(i, i + 200)));
      } catch {
        // A cache that does not answer is a cache without entries.
      }
    }
    return out;
  };

  const runner: ServicesRunner = {
    offers: (capability) => candidates(capability).map((c) => c.provider.id),

    async ask<C extends Capability>(capability: C, rawQuery: QueryOf[C]): Promise<Answer<C>> {
      const query = normaliseQuery(capability, rawQuery);
      const list = candidates(capability);
      if (list.length === 0) throw new ServiceError("service_off");

      const keys = list.map(({ provider }) => cacheKey(capability, provider.id, query));
      const hits = await safeCacheGet(keys);

      let failed = false;
      let limited = false;
      for (let i = 0; i < list.length; i++) {
        const { entry, provider } = list[i];

        const cachedData = fresh(hits[keys[i]], capability);
        if (cachedData !== null) {
          return {
            data: cachedData as AnswerOf[C],
            provider: provider.id,
            attribution: provider.attribution,
            cached: true,
          };
        }
        if (provider.needs_key && !entry.has_key) {
          continue; // the weakest reason: service_key_missing, if nothing else is seen
        }
        if ((calls.get(provider.id) ?? 0) >= provider.budget.per_day) {
          limited = true;
          continue;
        }
        if (capability === "climate" && (await climateLeft(provider)) <= 0) {
          limited = true;
          continue;
        }
        const key = await keyOf(provider);
        if (provider.needs_key && key === null) {
          continue; // the weakest reason: service_key_missing, if nothing else is seen
        }

        const outcome = await callProvider(provider, capability, query, key);
        if ("code" in outcome) {
          // "No data for this point" is an answer, not a fault; the next provider is asked.
          await countCall(provider, outcome.code === "no_data", outcome.code === "no_data" ? null : outcome.code);
          failed = true;
          continue;
        }
        await countCall(provider, true, null);
        try {
          await db.cachePut(keys[i], capability, provider.id, outcome.data, CACHE_TTL_SECONDS[capability]);
        } catch {
          // The answer is good without the cache.
        }
        return { data: outcome.data, provider: provider.id, attribution: provider.attribution, cached: false };
      }
      const code: ServiceErrorCode = failed ? "service_failed" : limited ? "service_limit" : "service_key_missing";
      throw new ServiceError(code);
    },

    async cached<C extends Capability>(capability: C, queries: QueryOf[C][]): Promise<(Answer<C> | null)[]> {
      const list = candidates(capability);
      if (list.length === 0 || queries.length === 0) return queries.map(() => null);
      const normalised = queries.map((q) => normaliseQuery(capability, q));
      const keyRows = normalised.map((q) => list.map(({ provider }) => cacheKey(capability, provider.id, q)));
      const hits = await safeCacheGet(keyRows.flat());
      return keyRows.map((rowKeys) => {
        for (let i = 0; i < list.length; i++) {
          const data = fresh(hits[rowKeys[i]], capability);
          if (data !== null) {
            const { provider } = list[i];
            return {
              data: data as AnswerOf[C],
              provider: provider.id,
              attribution: provider.attribution,
              cached: true,
            };
          }
        }
        return null;
      });
    },

    async climateBudget(): Promise<number> {
      const first = candidates("climate")[0];
      if (!first) return 0;
      const { entry, provider } = first;
      if (provider.needs_key && !entry.has_key) return 0;
      const left = Math.min(provider.budget.per_day - (calls.get(provider.id) ?? 0), await climateLeft(provider));
      return Math.max(0, Number.isFinite(left) ? left : 0);
    },

    async test(providerId) {
      const entry = chain.find((c) => c.provider === providerId);
      const provider = findProvider(providerId, registry);
      if (!entry || !provider) return { ok: false, error: "service_off" };
      if (provider.needs_key && !entry.has_key) return { ok: false, error: "service_key_missing" };
      if ((calls.get(provider.id) ?? 0) >= provider.budget.per_day) return { ok: false, error: "service_limit" };
      const key = await keyOf(provider);
      if (provider.needs_key && key === null) return { ok: false, error: "service_key_missing" };

      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      let code: string | null = null;
      try {
        const ctx: ProviderContext = {
          key,
          fetch: guardedFetch(provider, deps.fetch, MAX_IMAGE_BYTES),
          signal: controller.signal,
        };
        if (provider.test) {
          await provider.test(ctx);
        } else {
          const capability = TEST_ORDER.find((c) => typeof provider[c] === "function");
          if (!capability) throw new ProviderError("bad_answer");
          const fn = provider[capability] as unknown as (q: unknown, c: ProviderContext) => Promise<unknown>;
          await fn.call(provider, TEST_QUERY[capability], ctx);
        }
      } catch (err) {
        code = failureCode(err);
      } finally {
        clearTimeout(timer);
      }
      // Nothing for the test point still proves the key and the host work.
      const ok = code === null || code === "no_data";
      await countCall(provider, ok, ok ? null : code);
      return ok ? { ok: true } : { ok: false, error: code ?? "bad_answer" };
    },
  };
  return runner;
}

// ---------------------------------------------------------------- the real wiring

/** Refusals of `api.service_request` that travel as 403, and the one that is a 400. */
const FORBIDDEN_HINTS = new Set(["adults_only", "kiosk_forbidden", "guardian_required", "device_revoked"]);

function refusalOf(error: { message?: unknown; hint?: unknown }): unknown {
  const hint = typeof error.hint === "string" ? error.hint : null;
  const message = typeof error.message === "string" ? error.message : "refused";
  if (hint === "service_invalid") return new RequestError(400, "service_invalid", message, hint);
  if (hint !== null && FORBIDDEN_HINTS.has(hint)) return new RequestError(403, hint, message, hint);
  return error;
}

/** `api.service_request` answered; the shape the runner relies on. */
function chainOf(data: unknown): { household: string; chain: ChainEntry[] } {
  const d = data as { household_id?: unknown; providers?: unknown } | null;
  if (!d || typeof d.household_id !== "string" || !Array.isArray(d.providers)) {
    throw new Error("service_request answered with an unexpected shape");
  }
  const chain: ChainEntry[] = [];
  for (const p of d.providers) {
    const e = p as { provider?: unknown; has_key?: unknown; calls_today?: unknown };
    if (typeof e.provider !== "string") continue;
    chain.push({
      provider: e.provider,
      has_key: e.has_key === true,
      calls_today: typeof e.calls_today === "number" ? e.calls_today : 0,
    });
  }
  return { household: d.household_id, chain };
}

/**
 * The service-role database access of one request. The client is made on first use, after the
 * caller was verified by `service_request`.
 */
function realDb(household: string): ServiceDb {
  let client: ReturnType<typeof serviceClient> | null = null;
  const svc = () => (client ??= serviceClient());
  return {
    async secrets() {
      const { data, error } = await svc().rpc("service_secrets", { p_household: household });
      if (error) throw error;
      return (data ?? {}) as Record<string, string>;
    },
    async report(provider, ok, error) {
      const { data, error: err } = await svc().rpc("service_report", {
        p_household: household,
        p_provider: provider,
        p_ok: ok,
        p_error: error,
      });
      if (err) throw err;
      const today = (data as { calls_today?: unknown } | null)?.calls_today;
      return typeof today === "number" ? today : null;
    },
    async cacheGet(keys) {
      const { data, error } = await svc().rpc("service_cache_get", { p_keys: keys });
      if (error) throw error;
      return (data ?? {}) as Record<string, CacheRow>;
    },
    async cachePut(key, capability, provider, payload, ttlSeconds) {
      const { error } = await svc().rpc("service_cache_put", {
        p_key: key,
        p_capability: capability,
        p_provider: provider,
        p_payload: payload,
        p_ttl_seconds: ttlSeconds,
      });
      if (error) throw error;
    },
    async cacheRecent(provider, capability, seconds) {
      const { data, error } = await svc().rpc("service_cache_recent", {
        p_provider: provider,
        p_capability: capability,
        p_seconds: seconds,
      });
      if (error) throw error;
      return typeof data === "number" ? data : 0;
    },
  };
}

/**
 * Verifies the caller with the database (`api.service_request`, as the caller: adult, no kiosk,
 * the household's device, and a guardian for a null capability) and returns the runner for that
 * household. Throws the refusal (a RequestError 403/400 with the hint, or the database error).
 */
export async function openServices(
  req: Request,
  capability: Capability | null,
  actorProfileId: string | null,
): Promise<ServicesRunner> {
  const user = userClient(req);
  const { data, error } = await user.rpc("service_request", {
    p_actor: actorProfileId,
    p_capability: capability,
  });
  if (error) throw refusalOf(error);
  const { household, chain } = chainOf(data);
  return makeServices({
    household,
    chain,
    registry: PROVIDERS,
    db: realDb(household),
    fetch: globalThis.fetch.bind(globalThis),
    now: () => new Date(),
  });
}
