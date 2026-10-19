// POST → fills the public holiday cache from the OpenHolidays API (specs/21 and the
// holidays package; NFR-9: the apps never call that API themselves).
//
// Two modes, told apart by the request:
//
// - Scheduled (header `x-cron-secret`, no body): the weekly job of infra/cron/holidays-sync.sh.
//   Refreshes every country the cache knows (holiday_feed_sync, plus the countries of the
//   schools and household region overrides) whose cache is older than 7 days or missing.
//   Authenticated like tasks-nightly: the secret, compared in constant time, and nothing else.
//
// - On demand (user JWT, body `{country}`): the region picker of a household member. The
//   caller is verified with their own JWT and must be a member of a household with a live
//   device (api.members is row-level secured, so a row means exactly that). A stale country is
//   refreshed unless a refresh was attempted in the last 10 minutes. Responds with the cache's
//   counts: {country, fetched_at, regions, holidays}.
//
// The service role is used for the cache only: app.region, app.holiday_feed and
// app.holiday_feed_sync (through the service-role-only api.holiday_cache_* functions of
// supabase/migrations/20261014120000_regions_holidays.sql). The cache holds
// no household data; the countries of the overrides are read as codes only, and the
// service role never reads a household's own rows here.
import {
  errorResponse,
  json,
  preflight,
  readBody,
  RequestError,
  requirePost,
  serviceClient,
  userClient,
} from "../_shared/client.ts";
import {
  countriesFromRegions,
  fetchCountry,
  type FetchedCountry,
  type HolidayFeedRow,
  isCountry,
  OpenHolidaysError,
  type RegionRow,
  storableRegions,
  syncWindow,
} from "../_shared/openholidays.ts";

const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const RETRY_AFTER_MS = 10 * 60 * 1000;
const CHUNK_SIZE = 500;

/**
 * Compares two strings without leaking, through timing, where they first differ.
 * Copied from tasks-nightly (both functions guard a shared secret the same way).
 */
function constantTimeEquals(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  const n = Math.max(x.length, y.length);
  let diff = x.length ^ y.length;
  for (let i = 0; i < n; i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

function authorised(req: Request): boolean {
  const expected = Deno.env.get("CRON_SECRET");
  const given = req.headers.get("x-cron-secret");
  if (!expected || !given) return false;
  return constantTimeEquals(given, expected);
}

// deno-lint-ignore no-explicit-any
type Cache = any;

type CacheState = {
  fetched_at: string | null;
  regions: number;
  holidays: number;
};

type RefreshOutcome =
  | { status: "skipped" }
  | { status: "refreshed" }
  | { status: "failed"; code: string };

function isStale(fetchedAt: string | null, now: Date): boolean {
  if (fetchedAt === null) return true;
  const t = Date.parse(fetchedAt);
  return Number.isNaN(t) || now.getTime() - t > CACHE_TTL_MS;
}

function chunks<T>(rows: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < rows.length; i += size) {
    out.push(rows.slice(i, i + size));
  }
  return out;
}

async function readState(cache: Cache, country: string): Promise<CacheState> {
  const { data, error } = await cache.rpc("holiday_cache_state", {
    p_country: country,
  });
  if (error) throw error;
  const state = data as Partial<CacheState> | null;
  return {
    fetched_at: typeof state?.fetched_at === "string" ? state.fetched_at : null,
    regions: typeof state?.regions === "number" ? state.regions : 0,
    holidays: typeof state?.holidays === "number" ? state.holidays : 0,
  };
}

/**
 * Refreshes one country: claims the attempt, fetches the API, writes the cache and prunes
 * what the API no longer returns in the window. Nothing is written unless all three
 * requests succeeded, so a partial answer cannot prune the cache. A failure is recorded in
 * last_error and reported, never thrown, so the caller can go on with the next country.
 *
 * The claim is atomic: it succeeds only when no attempt is recorded after `retryBefore`.
 */
async function refresh(
  cache: Cache,
  country: string,
  now: Date,
  retryBefore: Date,
): Promise<RefreshOutcome> {
  const { data: claimed, error: claimError } = await cache.rpc(
    "holiday_cache_claim",
    {
      p_country: country,
      p_at: now.toISOString(),
      p_retry_before: retryBefore.toISOString(),
    },
  );
  if (claimError) throw claimError;
  if (claimed !== true) return { status: "skipped" };

  const window = syncWindow(now);
  let fetched: FetchedCountry;
  try {
    fetched = await fetchCountry(country, window);
  } catch (err) {
    const code = err instanceof OpenHolidaysError ? err.lastError : "internal";
    console.error("holidays-sync fetch failed:", country, code);
    await fail(cache, country, code);
    return { status: "failed", code };
  }

  const fetchedAt = now.toISOString();
  try {
    const storable = storableRegions(fetched.regions);
    if (storable.dropped > 0) {
      console.warn(
        "holidays-sync left out regions the cache cannot store:",
        country,
        storable.dropped,
      );
    }
    const regions = storable.rows.map((r: RegionRow) => ({
      ...r,
      fetched_at: fetchedAt,
    }));
    for (const part of chunks(regions, CHUNK_SIZE)) {
      const { error } = await cache.rpc("holiday_cache_put_regions", {
        p_rows: part,
      });
      if (error) throw error;
    }

    const holidays = [...fetched.publicHolidays, ...fetched.schoolHolidays]
      .map((h: HolidayFeedRow) => ({ ...h, fetched_at: fetchedAt }));
    for (const part of chunks(holidays, CHUNK_SIZE)) {
      const { error } = await cache.rpc("holiday_cache_put_holidays", {
        p_rows: part,
      });
      if (error) throw error;
    }

    // Corrections propagate: a holiday the API no longer returns is removed, per kind,
    // within the window. Rows outside the window are left alone.
    for (
      const [kind, rows] of [
        ["public", fetched.publicHolidays],
        ["school", fetched.schoolHolidays],
      ] as const
    ) {
      const { error } = await cache.rpc("holiday_cache_prune", {
        p_country: country,
        p_kind: kind,
        p_from: window.from,
        p_to: window.to,
        p_keep: rows.map((r) => r.id),
      });
      if (error) throw error;
    }

    const { error: finishError } = await cache.rpc("holiday_cache_finish", {
      p_country: country,
      p_fetched_at: fetchedAt,
      p_from: window.from,
      p_to: window.to,
    });
    if (finishError) throw finishError;
  } catch (err) {
    const code = typeof (err as { code?: unknown })?.code === "string"
      ? `db ${(err as { code: string }).code}`
      : "db";
    console.error("holidays-sync write failed:", country, code);
    await fail(cache, country, code);
    return { status: "failed", code };
  }
  return { status: "refreshed" };
}

/** Records a failure in last_error. Itself failing is logged, not thrown. */
async function fail(cache: Cache, country: string, code: string) {
  try {
    const { error } = await cache.rpc("holiday_cache_fail", {
      p_country: country,
      p_error: code,
    });
    if (error) throw error;
  } catch {
    console.error("holidays-sync could not record the failure:", country);
  }
}

/** The scheduled job: every country whose cache is stale, one after the other. */
async function scheduled(now: Date): Promise<Response> {
  // Service role: a scheduled job has no user. The secret is the only gate.
  const cache = serviceClient();
  const { data, error } = await cache.rpc("holiday_cache_countries");
  if (error) throw error;
  if (!Array.isArray(data)) {
    throw new Error("holiday_cache_countries: expected an array");
  }
  const countries = countriesFromRegions(data as string[]);

  const results: Array<{ country: string; status: string; code?: string }> = [];
  for (const country of countries) {
    try {
      const state = await readState(cache, country);
      if (!isStale(state.fetched_at, now)) {
        results.push({ country, status: "fresh" });
        continue;
      }
      // A scheduled run is not held back by a recent attempt: it claims unless the same
      // instant already did.
      const outcome = await refresh(cache, country, now, now);
      results.push(
        outcome.status === "failed"
          ? { country, status: "failed", code: outcome.code }
          : { country, status: outcome.status },
      );
    } catch (err) {
      // One country failing must not stop the others.
      const code = typeof (err as { code?: unknown })?.code === "string"
        ? (err as { code: string }).code
        : "internal";
      console.error("holidays-sync country failed:", country, code);
      results.push({ country, status: "failed", code });
    }
  }
  return json({ countries: countries.length, results });
}

function bearerToken(req: Request): string {
  const header = req.headers.get("Authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    throw new RequestError(401, "unauthorized", "missing bearer token");
  }
  return match[1];
}

/** The region picker's call: a household member asks for one country. */
async function onDemand(req: Request, now: Date): Promise<Response> {
  // userClient throws 401 without an Authorization header.
  const user = userClient(req);
  const { data: auth, error: authError } = await user.auth.getUser(
    bearerToken(req),
  );
  if (authError || !auth?.user) {
    throw new RequestError(401, "unauthorized", "sign in again");
  }
  // RLS scopes api.members to the caller's household and live device.
  const { data: members, error: memberError } = await user
    .from("members")
    .select("id")
    .eq("active", true)
    .limit(1);
  if (memberError) throw memberError;
  if (!Array.isArray(members) || members.length === 0) {
    throw new RequestError(
      403,
      "not_a_member",
      "no household member for this session",
    );
  }

  const body = await readBody(req);
  const country = body.country;
  if (!isCountry(country)) {
    throw new RequestError(
      400,
      "country_invalid",
      "country must be a two-letter ISO code",
      "country_invalid",
    );
  }

  // Service role: this writes the public cache only (see the header comment).
  const cache = serviceClient();
  let state = await readState(cache, country);
  if (isStale(state.fetched_at, now)) {
    const outcome = await refresh(
      cache,
      country,
      now,
      new Date(now.getTime() - RETRY_AFTER_MS),
    );
    if (outcome.status !== "skipped") {
      state = await readState(cache, country);
    }
  }
  if (state.fetched_at === null) {
    // Never fetched, and the refresh failed or was held back: nothing to show yet.
    throw new RequestError(
      503,
      "holidays_unavailable",
      "holiday data is not available yet",
    );
  }
  return json({
    country,
    fetched_at: state.fetched_at,
    regions: state.regions,
    holidays: state.holidays,
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const now = new Date();
    if (req.headers.has("x-cron-secret")) {
      if (!authorised(req)) {
        return new Response(null, { status: 401 });
      }
      return await scheduled(now);
    }
    return await onDemand(req, now);
  } catch (err) {
    return errorResponse(err);
  }
});
