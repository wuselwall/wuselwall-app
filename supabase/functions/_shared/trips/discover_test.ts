import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import {
  type Answer,
  type Capability,
  type Climate,
  type ClimateMonth,
  ServiceError,
  type ServiceErrorCode,
  type Services,
} from "../services/types.ts";
import { DESTINATIONS, type Tag } from "./destinations.ts";
import {
  discover,
  type DiscoverInput,
  distanceKm,
  effortOf,
  type Filters,
  fitsFilters,
  MAX_PLACES,
  monthDays,
  windowClimate,
} from "./discover.ts";

// ---------------------------------------------------------------- a fake Services

const at = (q: { lat: number; lon: number }) =>
  `${q.lat.toFixed(2)},${q.lon.toFixed(2)}`;

/** Twelve months, each from `f(month)`. */
function year(f: (month: number) => Partial<ClimateMonth>): Climate {
  return {
    months: Array.from({ length: 12 }, (_, i) => ({
      month: i + 1,
      tmax: 20,
      tmin: 10,
      ...f(i + 1),
    })),
  };
}

type Fake = Services & {
  asked: string[];
  budgetCalls: number;
  /** Climate known to the cache, by "lat,lon". */
  cache: Map<string, Climate>;
};

function fake(p: {
  offers?: string[];
  budget?: number;
  /** What a fetch returns for a place; default a mild year. */
  climateOf?: (key: string) => Climate;
  /** Failures by "lat,lon". */
  fail?: Map<string, ServiceErrorCode>;
  provider?: string;
  attribution?: string;
}): Fake {
  const provider = p.provider ?? "test-provider";
  const attribution = p.attribution ?? "Weather data by Test";
  const f: Fake = {
    asked: [],
    budgetCalls: 0,
    cache: new Map(),
    offers: (c: Capability) => c === "climate" ? (p.offers ?? [provider]) : [],
    // deno-lint-ignore require-await
    async ask(capability, query) {
      assertEquals(capability, "climate");
      const key = at(query as { lat: number; lon: number });
      f.asked.push(key);
      const code = p.fail?.get(key);
      if (code) throw new ServiceError(code);
      const data = (p.climateOf ?? (() => year(() => ({}))))(key);
      f.cache.set(key, data);
      return { data, provider, attribution, cached: false } as Answer<
        typeof capability
      >;
    },
    // deno-lint-ignore require-await
    async cached(_capability, queries) {
      return queries.map((q) => {
        const data = f.cache.get(at(q as { lat: number; lon: number }));
        return data
          ? { data, provider, attribution, cached: true } as Answer<
            typeof _capability
          >
          : null;
      });
    },
    // deno-lint-ignore require-await
    async climateBudget() {
      f.budgetCalls++;
      return p.budget ?? 0;
    },
  };
  return f;
}

function input(p: Partial<DiscoverInput>): DiscoverInput {
  return {
    from: "2027-07-10",
    to: "2027-07-20",
    lang: "de",
    filters: {},
    home: null,
    ideas: [],
    fetchLimit: 6,
    ...p,
  };
}

/** Zurich, as the home place of the distance tests. */
const ZURICH = { lat: 47.37, lon: 8.54 };

/** A tag filter that leaves a handful of places. */
const SMALL: Tag[] = ["island", "north"];
const smallPool = DESTINATIONS.filter((d) =>
  SMALL.every((t) => d.tags.includes(t))
);

// ---------------------------------------------------------------- distance and effort

Deno.test("distance: great circle, effort bands at 300, 800, 1500 and 4000 km", () => {
  // Zurich to Paris is about 490 km by the great circle.
  const paris = DESTINATIONS.find((d) => d.key === "paris")!;
  const km = distanceKm(ZURICH, paris);
  assert(km > 470 && km < 510, String(km));
  assertEquals(distanceKm(ZURICH, ZURICH), 0);
  assertEquals(
    [300, 301, 800, 801, 1500, 1501, 4000, 4001].map(effortOf),
    ["near", "car", "car", "short", "short", "medium", "medium", "long"],
  );
});

Deno.test("a place has km rounded to ten and its effort band when a home is set", async () => {
  const r = await discover(
    input({ home: ZURICH, filters: { tags: ["city"] } }),
    fake({ offers: [] }),
  );
  const paris = r.places.find((p) => p.key === "paris")!;
  assertEquals(paris.km! % 10, 0);
  assertEquals(paris.effort, "car");
  const tokyo = r.places.find((p) => p.key === "tokyo")!;
  assertEquals(tokyo.effort, "long");
});

Deno.test("without a home there is no km, no effort, and an effort filter is ignored", async () => {
  const r = await discover(
    input({ filters: { effort: "near", tags: SMALL } }),
    fake({ offers: [] }),
  );
  assertEquals(r.places.length, smallPool.length);
  for (const p of r.places) {
    assertEquals(p.km, undefined);
    assertEquals(p.effort, undefined);
  }
});

Deno.test("the effort filter means at most this band", async () => {
  const r = await discover(
    input({ home: ZURICH, filters: { effort: "car" } }),
    fake({ offers: [] }),
  );
  const efforts = new Set(r.places.map((p) => p.effort));
  assertEquals(efforts, new Set(["near", "car"]));
  assert(r.places.some((p) => p.key === "ticino"));
  assert(!r.places.some((p) => p.key === "mallorca"));
});

Deno.test("tags: a place must have all of them", async () => {
  const r = await discover(
    input({ filters: { tags: ["sea", "island"] } }),
    fake({ offers: [] }),
  );
  assert(r.places.length > 10);
  for (const p of r.places) {
    assert(p.tags.includes("sea") && p.tags.includes("island"), p.name);
  }
  assert(!r.places.some((p) => p.key === "paris"));
});

Deno.test("names come in the asked language", async () => {
  const de = await discover(
    input({ lang: "de", filters: { tags: SMALL } }),
    fake({ offers: [] }),
  );
  const fr = await discover(
    input({ lang: "fr", filters: { tags: SMALL } }),
    fake({ offers: [] }),
  );
  assert(de.places.some((p) => p.name === "Färöer"));
  assert(fr.places.some((p) => p.name === "Îles Féroé"));
});

// ---------------------------------------------------------------- the window's climate

Deno.test("monthDays: the days of each month the window touches", () => {
  assertEquals(monthDays("2027-07-25", "2027-08-08"), [
    { month: 7, days: 7, monthLength: 31 },
    { month: 8, days: 8, monthLength: 31 },
  ]);
  assertEquals(monthDays("2027-02-10", "2027-02-12"), [
    { month: 2, days: 3, monthLength: 28 },
  ]);
  assertEquals(monthDays("2028-02-10", "2028-02-12")[0].monthLength, 29);
  assertEquals(monthDays("2027-12-30", "2028-01-02"), [
    { month: 12, days: 2, monthLength: 31 },
    { month: 1, days: 2, monthLength: 31 },
  ]);
  assertEquals(monthDays("2027-03-05", "2027-03-01"), []);
});

Deno.test("monthDays: a window longer than 62 days reads its first 62 days", () => {
  const m = monthDays("2027-06-01", "2027-12-31");
  assertEquals(m.reduce((n, x) => n + x.days, 0), 62);
  assertEquals(m.map((x) => [x.month, x.days]), [[6, 30], [7, 31], [8, 1]]);
});

Deno.test("windowClimate: mean over the months weighted by days, one decimal", () => {
  const climate = year((m) => ({
    tmax: m === 7 ? 30 : 20,
    tmin: m === 7 ? 18 : 10,
    sea: m === 7 ? 24 : undefined,
    sun_hours: m === 8 ? 9 : undefined,
  }));
  const c = windowClimate(climate, "2027-07-25", "2027-08-08")!;
  // July 7 days at 30, August 8 days at 20: (210 + 160) / 15 = 24.666…
  assertEquals(c.tmax, 24.7);
  assertEquals(c.tmin, 13.7);
  // A value only one month has is the mean of that month alone.
  assertEquals(c.sea, 24);
  assertEquals(c.sun_hours, 9);
  assertEquals(c.rain_days, undefined);
});

Deno.test("windowClimate: rain days and precipitation are scaled to 30 days", () => {
  const climate = year((m) => (m === 2 ? { rain_days: 8, precip_mm: 56 } : {}));
  const c = windowClimate(climate, "2027-02-01", "2027-02-10")!;
  // February has 28 days: 8 * 30 / 28 = 8.57; 56 * 30 / 28 = 60.
  assertEquals(c.rain_days, 8.6);
  assertEquals(c.precip30, 60);
});

// ---------------------------------------------------------------- fits

Deno.test("fits: temperature, rain, sea against the window's values", () => {
  const warm = { tmax: 28, tmin: 18, rain_days: 3, sea: 23 };
  const f = (filters: Filters, c: Parameters<typeof fitsFilters>[1] = warm) =>
    fitsFilters(filters, c);
  assertEquals(f({}), "yes");
  assertEquals(f({ temp_min: 28 }), "yes");
  assertEquals(f({ temp_min: 29 }), "no");
  assertEquals(f({ temp_max: 28 }), "yes");
  assertEquals(f({ temp_max: 27 }), "no");
  assertEquals(f({ dry: true }), "yes");
  assertEquals(f({ dry: true }, { ...warm, rain_days: 7 }), "no");
  assertEquals(f({ dry: true }, { ...warm, rain_days: 6 }), "yes");
  assertEquals(f({ sea_min: 23 }), "yes");
  assertEquals(f({ sea_min: 24 }), "no");
  assertEquals(
    f({ temp_min: 20, temp_max: 30, dry: true, sea_min: 20 }),
    "yes",
  );
});

Deno.test("fits: rain days missing falls back to precipitation, else unknown", () => {
  const base = { tmax: 20, tmin: 10 };
  assertEquals(fitsFilters({ dry: true }, { ...base, precip30: 50 }), "yes");
  assertEquals(fitsFilters({ dry: true }, { ...base, precip30: 51 }), "no");
  assertEquals(fitsFilters({ dry: true }, base), "unknown");
});

Deno.test("fits: a filter whose value is missing is unknown, a violated one still wins", () => {
  const dry = { tmax: 20, tmin: 10 };
  assertEquals(fitsFilters({ sea_min: 20 }, dry), "unknown");
  assertEquals(fitsFilters({ temp_min: 25, sea_min: 20 }, dry), "no");
  assertEquals(fitsFilters({ temp_min: 15 }, null), "unknown");
  assertEquals(fitsFilters({}, null), "yes");
});

// ---------------------------------------------------------------- discover with climate

Deno.test("no provider: tags and distance only, filters on climate leave places unknown", async () => {
  const services = fake({ offers: [] });
  const r = await discover(
    input({ home: ZURICH, filters: { tags: SMALL, temp_min: 20 } }),
    services,
  );
  assertEquals(r.pending, 0);
  assertEquals(r.provider, undefined);
  assertEquals(r.attribution, undefined);
  assertEquals(r.places.length, smallPool.length);
  for (const p of r.places) {
    assertEquals(p.fits, "unknown");
    assertEquals(p.climate, undefined);
  }
  assertEquals(services.asked, []);
  // Nearest first.
  const kms = r.places.map((p) => p.km!);
  assertEquals(kms, [...kms].sort((a, b) => a - b));
  // Without climate filters nothing is in doubt.
  const plain = await discover(input({ filters: { tags: SMALL } }), services);
  for (const p of plain.places) assertEquals(p.fits, "yes");
});

Deno.test("climate is fetched nearest first within min(fetchLimit, budget); the rest is pending", async () => {
  const services = fake({ budget: 3 });
  const r = await discover(
    input({ home: ZURICH, filters: { tags: SMALL }, fetchLimit: 6 }),
    services,
  );
  assertEquals(services.asked.length, 3);
  const nearest = smallPool
    .map((d) => ({ d, km: distanceKm(ZURICH, d) }))
    .sort((a, b) => a.km - b.km)
    .slice(0, 3)
    .map(({ d }) => at(d));
  assertEquals(services.asked, nearest);
  assertEquals(r.pending, smallPool.length - 3);
  assertEquals(r.provider, "test-provider");
  assertEquals(r.attribution, "Weather data by Test");
  assertEquals(r.places.filter((p) => p.climate !== undefined).length, 3);
});

Deno.test("fetchLimit caps the fetches when the budget is larger", async () => {
  const services = fake({ budget: 50 });
  const r = await discover(
    input({ home: ZURICH, filters: { tags: SMALL }, fetchLimit: 2 }),
    services,
  );
  assertEquals(services.asked.length, 2);
  assertEquals(r.pending, smallPool.length - 2);
});

Deno.test("cached places are not fetched again; a second call finishes the rest", async () => {
  const services = fake({ budget: 4 });
  const run = () =>
    discover(
      input({ home: ZURICH, filters: { tags: SMALL }, fetchLimit: 4 }),
      services,
    );
  const first = await run();
  const second = await run();
  assertEquals(new Set(services.asked).size, services.asked.length);
  assertEquals(first.pending, smallPool.length - 4);
  assertEquals(second.pending, Math.max(0, smallPool.length - 8));
  const third = await run();
  assertEquals(third.pending, 0);
  assertEquals(services.asked.length, smallPool.length);
});

Deno.test("a budget of zero fetches nothing and everything missing is pending", async () => {
  const services = fake({ budget: 0 });
  const r = await discover(input({ filters: { tags: SMALL } }), services);
  assertEquals(services.asked, []);
  assertEquals(r.pending, smallPool.length);
  assertEquals(r.provider, undefined);
});

Deno.test("no fetch is attempted, and the budget not asked, when everything is cached", async () => {
  const services = fake({ budget: 9 });
  for (const d of smallPool) services.cache.set(at(d), year(() => ({})));
  const r = await discover(input({ filters: { tags: SMALL } }), services);
  assertEquals(services.asked, []);
  assertEquals(services.budgetCalls, 0);
  assertEquals(r.pending, 0);
  assertEquals(r.provider, "test-provider");
});

Deno.test("one failed place stays unknown and the next is still fetched", async () => {
  const nearestFirst = smallPool
    .map((d) => ({ d, km: distanceKm(ZURICH, d) }))
    .sort((a, b) => a.km - b.km)
    .map(({ d }) => d);
  const services = fake({
    budget: 3,
    fail: new Map([[at(nearestFirst[0]), "service_failed" as const]]),
  });
  const r = await discover(
    input({ home: ZURICH, filters: { tags: SMALL } }),
    services,
  );
  assertEquals(services.asked.length, 3);
  const failed = r.places.find((p) => p.name === nearestFirst[0].names.de)!;
  assertEquals(failed.climate, undefined);
  // The failure used one of the three fetches.
  assertEquals(r.places.filter((p) => p.climate !== undefined).length, 2);
  assertEquals(r.pending, smallPool.length - 2);
});

Deno.test("service_limit and service_off stop the fetching", async () => {
  for (const code of ["service_limit", "service_off"] as const) {
    const first = smallPool
      .map((d) => ({ d, km: distanceKm(ZURICH, d) }))
      .sort((a, b) => a.km - b.km)[1].d;
    const services = fake({
      budget: 6,
      fail: new Map([[at(first), code]]),
    });
    const r = await discover(
      input({ home: ZURICH, filters: { tags: SMALL } }),
      services,
    );
    // The nearest worked, the second hit the limit, nothing after it was asked.
    assertEquals(services.asked.length, 2, code);
    assertEquals(r.pending, smallPool.length - 1, code);
  }
});

Deno.test("an error that is not a ServiceError is not swallowed", async () => {
  const services = fake({ budget: 1 });
  services.ask = () => Promise.reject(new Error("boom"));
  let thrown: unknown = null;
  try {
    await discover(input({ filters: { tags: SMALL } }), services);
  } catch (err) {
    thrown = err;
  }
  assert(thrown instanceof Error && thrown.message === "boom");
});

Deno.test("places that do not fit are left out, the others listed yes first then by km", async () => {
  // Only the island north of Zurich are in the pool; make half of them cold.
  const cold = new Set(smallPool.filter((_, i) => i % 2 === 0).map(at));
  const services = fake({
    budget: 50,
    climateOf: (key) => year(() => ({ tmax: cold.has(key) ? 5 : 25 })),
  });
  const r = await discover(
    input({
      home: ZURICH,
      filters: { tags: SMALL, temp_min: 20 },
      fetchLimit: 50,
    }),
    services,
  );
  const warm = smallPool.filter((d) => !cold.has(at(d)));
  assertEquals(r.places.length, warm.length);
  for (const p of r.places) {
    assertEquals(p.fits, "yes");
    assertEquals(p.climate?.tmax, 25);
  }
  const kms = r.places.map((p) => p.km!);
  assertEquals(kms, [...kms].sort((a, b) => a - b));
  assertEquals(r.pending, 0);
});

Deno.test("yes before unknown, then nearer, unknown distances last", async () => {
  const [a, b, c] = smallPool
    .map((d) => ({ d, km: distanceKm(ZURICH, d) }))
    .sort((x, y) => x.km - y.km)
    .map(({ d }) => d);
  const services = fake({ budget: 0 });
  // Only the third-nearest has a (suitable) climate cached.
  services.cache.set(at(c), year(() => ({ tmax: 30 })));
  const r = await discover(
    input({ home: ZURICH, filters: { tags: SMALL, temp_min: 20 } }),
    services,
  );
  assertEquals(r.places[0].fits, "yes");
  assertEquals(r.places[0].name, c.names.de);
  assertEquals(r.places[1].name, a.names.de);
  assertEquals(r.places[2].name, b.names.de);
  assertEquals(r.places[1].fits, "unknown");

  // Without a home there is no distance: the order is by name.
  const noHome = await discover(
    input({ filters: { tags: SMALL } }),
    fake({ offers: [] }),
  );
  const names = noHome.places.map((p) => p.name);
  assertEquals(names, [...names].sort((x, y) => x.localeCompare(y, "de")));
});

Deno.test("the answer is capped at MAX_PLACES", async () => {
  const r = await discover(input({}), fake({ offers: [] }));
  assertEquals(r.places.length, MAX_PLACES);
  assert(DESTINATIONS.length > MAX_PLACES);
});

Deno.test("the window's months decide the climate shown", async () => {
  const services = fake({
    budget: 50,
    climateOf: () =>
      year((m) => ({ tmax: m === 7 ? 32 : 12, rain_days: m === 7 ? 2 : 14 })),
  });
  const july = await discover(
    input({
      filters: { tags: ["north", "island"], temp_min: 25, dry: true },
      from: "2027-07-05",
      to: "2027-07-15",
    }),
    services,
  );
  assertEquals(july.places.length, smallPool.length);
  assertEquals(july.places[0].climate, { tmax: 32, tmin: 10, rain_days: 1.9 });
  const march = await discover(
    input({
      filters: { tags: ["north", "island"], temp_min: 25 },
      from: "2027-03-05",
      to: "2027-03-15",
    }),
    services,
  );
  assertEquals(march.places, []);
});

// ---------------------------------------------------------------- ideas

Deno.test("an idea picked from the catalogue replaces its entry: one row with key and trip_id", async () => {
  const r = await discover(
    input({
      filters: { tags: ["sea", "island"] },
      ideas: [{
        trip_id: "t1",
        name: "Insel mit Oma",
        destination_key: "mallorca",
        country: "ES",
        lat: 39.57,
        lon: 2.65,
      }],
    }),
    fake({ offers: [] }),
  );
  const rows = r.places.filter((p) => p.key === "mallorca");
  assertEquals(rows.length, 1);
  assertEquals(rows[0].trip_id, "t1");
  assertEquals(rows[0].name, "Insel mit Oma");
  assertEquals([rows[0].lat, rows[0].lon], [39.57, 2.65]);
  assertEquals(rows[0].tags, ["sea", "island"]);
  assertEquals(r.places.filter((p) => p.trip_id !== undefined).length, 1);
});

Deno.test("an idea without a catalogue key is its own row, without tags", async () => {
  const idea = {
    trip_id: "t2",
    name: "Hütte bei Oma",
    destination_key: null,
    country: null,
    lat: 46.9,
    lon: 7.4,
  };
  const all = await discover(
    input({ ideas: [idea], home: ZURICH }),
    fake({ offers: [] }),
  );
  const row = all.places.find((p) => p.trip_id === "t2")!;
  assertEquals(row.key, undefined);
  assertEquals(row.tags, []);
  assertEquals(row.country, "");
  assertEquals(row.effort, "near");
  // A tag filter leaves it out: it has none.
  const tagged = await discover(
    input({ ideas: [idea], filters: { tags: ["mountains"] } }),
    fake({ offers: [] }),
  );
  assert(!tagged.places.some((p) => p.trip_id === "t2"));
});

Deno.test("an idea's own coordinates are the ones asked for", async () => {
  const services = fake({ budget: 5 });
  const r = await discover(
    input({
      ideas: [{
        trip_id: "t3",
        name: "Irgendwo",
        destination_key: null,
        country: "NO",
        lat: 70.12,
        lon: 25.5,
      }],
      home: { lat: 70.0, lon: 25.0 },
    }),
    services,
  );
  // It is the nearest place to this home, so it is fetched first.
  assertEquals(services.asked[0], "70.12,25.50");
  assertEquals(r.places.find((p) => p.trip_id === "t3")?.climate?.tmax, 20);
});
