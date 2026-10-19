import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1.0.13";
import {
  countriesFromRegions,
  endpointUrl,
  fetchCountry,
  flattenSubdivisions,
  isCountry,
  holidayName,
  OpenHolidaysError,
  parseHolidays,
  regionCovers,
  type RegionRow,
  storableRegions,
  syncWindow,
} from "./openholidays.ts";

// Fixtures are trimmed real answers of openholidaysapi.org (probed in 2026-10):
// fixtures/subdivisions_ch.json (Aargau with two municipalities of its district),
// fixtures/public_ch.json (three public days), fixtures/school_de.json (two school
// holidays with subdivisions).

async function fixture(name: string): Promise<unknown> {
  return JSON.parse(
    await Deno.readTextFile(new URL(`./fixtures/${name}`, import.meta.url)),
  );
}

const WINDOW = { from: "2025-01-01", to: "2027-12-31" };

// ------------------------------------------------------------------ flattenSubdivisions

Deno.test("flattenSubdivisions: levels, parent codes and categories follow the tree", async () => {
  const rows = flattenSubdivisions("CH", await fixture("subdivisions_ch.json"));
  assertEquals(rows.map((r) => [r.code, r.level, r.parent_code]), [
    ["CH-AG", 1, null],
    ["CH-AG-ZZ", 2, "CH-AG"],
    ["CH-AG-ZZ-TE", 3, "CH-AG-ZZ"],
    ["CH-AG-ZZ-BO", 3, "CH-AG-ZZ"],
  ]);
  assertEquals(rows[0].category, "Kanton");
  assertEquals(rows[1].category, "Bezirk");
  assertEquals(rows[2].category, "Gemeinde");
  assertEquals(rows[0].short_name, "AG");
  assertEquals(rows[0].country, "CH");
});

Deno.test("flattenSubdivisions: names keyed by lower-case language, first text wins", async () => {
  const rows = flattenSubdivisions("CH", await fixture("subdivisions_ch.json"));
  assertEquals(rows[0].names.de, "Aargau");
  assertEquals(rows[0].names.fr, "Argovie");
  assertEquals(rows[0].names.en, "Aargau");
  assertEquals(
    Object.keys(rows[0].names).every((k) => k === k.toLowerCase()),
    true,
  );
  assertEquals(rows[1].names, { de: "Zurzach" });
});

Deno.test("flattenSubdivisions: a node without names or categories gets empty values", () => {
  const rows = flattenSubdivisions("DE", [{ code: "DE-BY", shortName: "BY" }]);
  assertEquals(rows, [{
    code: "DE-BY",
    country: "DE",
    parent_code: null,
    level: 1,
    category: "",
    short_name: "BY",
    names: {},
  }]);
});

Deno.test("flattenSubdivisions: an empty list is no regions", () => {
  assertEquals(flattenSubdivisions("DE", []), []);
});

Deno.test("flattenSubdivisions: rejects a non-array, a node without code and a fifth level", () => {
  assertThrowsShape(() => flattenSubdivisions("CH", { code: "CH-AG" }));
  assertThrowsShape(() => flattenSubdivisions("CH", [{ shortName: "AG" }]));
  assertThrowsShape(() =>
    flattenSubdivisions("CH", [{ code: "A", children: "x" }])
  );
  const deep = {
    code: "L1",
    children: [{
      code: "L2",
      children: [{
        code: "L3",
        children: [{ code: "L4", children: [{ code: "L5" }] }],
      }],
    }],
  };
  assertThrowsShape(() => flattenSubdivisions("CH", [deep]));
});

Deno.test("flattenSubdivisions: four levels are allowed", () => {
  const deep = {
    code: "L1",
    children: [{
      code: "L2",
      children: [{ code: "L3", children: [{ code: "L4" }] }],
    }],
  };
  const rows = flattenSubdivisions("CH", [deep]);
  assertEquals(rows.map((r) => r.level), [1, 2, 3, 4]);
});

// ------------------------------------------------------------------ storableRegions

function region(code: string, level: number, country = "CH"): RegionRow {
  return {
    code,
    country,
    parent_code: null,
    level: level as RegionRow["level"],
    category: "",
    short_name: "",
    names: {},
  };
}

Deno.test("storableRegions: keeps the codes with umlauts that OpenHolidays sends", () => {
  const rows = [
    region("AT-KÄ", 1, "AT"),
    region("AT-NÖ", 1, "AT"),
    region("CH-BE", 1),
    region("CH-BE-SL-RÜ", 3),
    region("DE-BY", 1, "DE"),
  ];
  assertEquals(storableRegions(rows), { rows, dropped: 0 });
});

Deno.test("storableRegions: leaves out a code the cache would refuse, not the country", () => {
  const { rows, dropped } = storableRegions([
    region("CH-VD", 1),
    region("CH-VD-LÉ", 2), // a character the check does not know
    region("CH-vd", 1), // lower case
    region("CH-VD-LA", 3), // level is not the depth
    region("DE-BY", 1), // another country
  ]);
  assertEquals(rows.map((r) => r.code), ["CH-VD"]);
  assertEquals(dropped, 4);
});

Deno.test("storableRegions: the Swiss fixture is storable as it is", async () => {
  const rows = flattenSubdivisions("CH", await fixture("subdivisions_ch.json"));
  assertEquals(storableRegions(rows).dropped, 0);
});

function assertThrowsShape(fn: () => unknown) {
  let thrown: unknown = null;
  try {
    fn();
  } catch (err) {
    thrown = err;
  }
  assert(thrown instanceof OpenHolidaysError, "expected an OpenHolidaysError");
  assertEquals((thrown as OpenHolidaysError).reason, "invalid_shape");
}

// ------------------------------------------------------------------ parseHolidays

Deno.test("parseHolidays: public days from the fixture", async () => {
  const rows = parseHolidays("CH", "public", await fixture("public_ch.json"));
  assertEquals(rows.length, 3);
  assertEquals(rows[0], {
    id: rows[0].id,
    country: "CH",
    kind: "public",
    starts_on: "2026-01-01",
    ends_on: "2026-01-01",
    names: {
      de: "Neujahrstag",
      fr: "Nouvel an",
      it: "Capodanno",
      en: "New Year's Day",
    },
    nationwide: true,
    subdivisions: [],
  });
  assertEquals(rows[1].nationwide, false);
  assert(rows[1].subdivisions.includes("CH-LU"));
  assertEquals(rows[1].subdivisions.length, 3);
});

Deno.test("parseHolidays: the endpoint's kind, not the entry's type, sets the kind", async () => {
  const json = await fixture("public_ch.json") as unknown[];
  // The third fixture entry is the API's "Optional" type; it stays a public row.
  const rows = parseHolidays("CH", "public", json);
  assertEquals(rows.map((r) => r.kind), ["public", "public", "public"]);
});

Deno.test("parseHolidays: school holidays with subdivision codes", async () => {
  const rows = parseHolidays("DE", "school", await fixture("school_de.json"));
  assertEquals(rows.length, 2);
  assertEquals(
    rows.every((r) => r.kind === "school" && r.country === "DE"),
    true,
  );
  assertEquals(rows[0].subdivisions, ["DE-HH"]);
  assertEquals(rows[0].nationwide, false);
  assertEquals(rows[0].names.de, "Weihnachtsferien");
});

Deno.test("parseHolidays: skips entries without id or with missing or malformed dates", () => {
  const rows = parseHolidays("CH", "public", [
    {
      id: "ok",
      startDate: "2026-04-20",
      endDate: "2026-04-20",
      name: [],
      nationwide: true,
    },
    { startDate: "2026-04-21", endDate: "2026-04-21", name: [] },
    { id: "no-start", endDate: "2026-04-21", name: [] },
    { id: "no-end", startDate: "2026-04-21", name: [] },
    {
      id: "bad-date",
      startDate: "20.04.2026",
      endDate: "2026-04-20",
      name: [],
    },
    { id: "", startDate: "2026-04-21", endDate: "2026-04-21", name: [] },
    "not an object",
    null,
  ]);
  assertEquals(rows.map((r) => r.id), ["ok"]);
});

Deno.test("parseHolidays: missing optional fields default; subdivisions drop malformed items", () => {
  const [row] = parseHolidays("CH", "school", [{
    id: "x",
    startDate: "2026-07-01",
    endDate: "2026-08-14",
    subdivisions: [{ code: "CH-ZH" }, { shortName: "no code" }, 7],
  }]);
  assertEquals(row.nationwide, false);
  assertEquals(row.names, {});
  assertEquals(row.subdivisions, ["CH-ZH"]);
});

Deno.test("parseHolidays: an empty list is no holidays; a non-array is invalid", () => {
  assertEquals(parseHolidays("CH", "public", []), []);
  let thrown: unknown = null;
  try {
    parseHolidays("CH", "public", { error: "nope" });
  } catch (err) {
    thrown = err;
  }
  assert(thrown instanceof OpenHolidaysError);
  assertEquals((thrown as OpenHolidaysError).reason, "invalid_shape");
});

// ------------------------------------------------------------------ window and URLs

Deno.test("syncWindow: previous year to next year, three years", () => {
  assertEquals(syncWindow(new Date("2026-10-14T12:00:00Z")), {
    from: "2025-01-01",
    to: "2027-12-31",
  });
});

Deno.test("syncWindow: uses UTC years at the boundary", () => {
  assertEquals(syncWindow(new Date("2026-12-31T23:30:00Z")), {
    from: "2025-01-01",
    to: "2027-12-31",
  });
  assertEquals(syncWindow(new Date("2027-01-01T00:30:00Z")), {
    from: "2026-01-01",
    to: "2028-12-31",
  });
});

Deno.test("endpointUrl: query parameters in the API's names", () => {
  assertEquals(
    endpointUrl("Subdivisions", "CH"),
    "https://openholidaysapi.org/Subdivisions?countryIsoCode=CH",
  );
  assertEquals(
    endpointUrl("PublicHolidays", "CH", WINDOW),
    "https://openholidaysapi.org/PublicHolidays?countryIsoCode=CH&validFrom=2025-01-01&validTo=2027-12-31",
  );
  assertEquals(
    endpointUrl("SchoolHolidays", "DE", WINDOW),
    "https://openholidaysapi.org/SchoolHolidays?countryIsoCode=DE&validFrom=2025-01-01&validTo=2027-12-31",
  );
});

// ------------------------------------------------------------------ fetchCountry

type Call = { url: string; init: RequestInit | undefined };

/** A fake fetch answering by path; records every call. */
function fakeFetch(
  answers: Record<string, () => Response | Promise<Response>>,
): { fetch: typeof fetch; calls: Call[] } {
  const calls: Call[] = [];
  const impl = (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    calls.push({ url, init });
    const path = new URL(url).pathname.slice(1);
    const answer = answers[path];
    if (!answer) {
      return Promise.resolve(new Response("missing", { status: 404 }));
    }
    return Promise.resolve(answer());
  };
  return { fetch: impl as typeof fetch, calls };
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.test("fetchCountry: three requests with the window, headers and a timeout", async () => {
  const subs = await fixture("subdivisions_ch.json");
  const pub = await fixture("public_ch.json");
  const school = await fixture("school_de.json");
  const { fetch: fake, calls } = fakeFetch({
    Subdivisions: () => jsonResponse(subs),
    PublicHolidays: () => jsonResponse(pub),
    SchoolHolidays: () => jsonResponse(school),
  });

  const result = await fetchCountry("CH", WINDOW, fake);

  assertEquals(calls.map((c) => c.url).sort(), [
    "https://openholidaysapi.org/PublicHolidays?countryIsoCode=CH&validFrom=2025-01-01&validTo=2027-12-31",
    "https://openholidaysapi.org/SchoolHolidays?countryIsoCode=CH&validFrom=2025-01-01&validTo=2027-12-31",
    "https://openholidaysapi.org/Subdivisions?countryIsoCode=CH",
  ]);
  for (const call of calls) {
    const headers = call.init?.headers as Record<string, string>;
    assertEquals(headers.Accept, "application/json");
    assertEquals(
      headers["User-Agent"],
      "WuselWall holidays-sync (+https://wuselwall.app)",
    );
    assert(
      call.init?.signal instanceof AbortSignal,
      "every request carries a timeout signal",
    );
  }
  assertEquals(result.country, "CH");
  assertEquals(result.regions.length, 4);
  assertEquals(result.publicHolidays.length, 3);
  // The fake answers the school request with the DE fixture whatever the country is.
  assertEquals(result.schoolHolidays.length, 2);
  assertEquals(result.schoolHolidays[0].kind, "school");
});

Deno.test("fetchCountry: a school answer maps to school rows", async () => {
  const { fetch: fake } = fakeFetch({
    Subdivisions: () => jsonResponse([]),
    PublicHolidays: () => jsonResponse([]),
    SchoolHolidays: async () => jsonResponse(await fixture("school_de.json")),
  });
  const result = await fetchCountry("DE", WINDOW, fake);
  assertEquals(result.schoolHolidays.length, 2);
  assertEquals(result.schoolHolidays[0].kind, "school");
});

Deno.test("fetchCountry: a non-2xx answer is an http error with the status", async () => {
  const { fetch: fake } = fakeFetch({
    Subdivisions: () => jsonResponse([]),
    PublicHolidays: () => new Response("busy", { status: 503 }),
    SchoolHolidays: () => jsonResponse([]),
  });
  const err = await assertRejects(
    () => fetchCountry("CH", WINDOW, fake),
    OpenHolidaysError,
  );
  assertEquals(err.reason, "http");
  assertEquals(err.status, 503);
  assertEquals(err.lastError, "http 503");
});

Deno.test("fetchCountry: invalid JSON is an invalid_json error", async () => {
  const { fetch: fake } = fakeFetch({
    Subdivisions: () => new Response("<html>", { status: 200 }),
    PublicHolidays: () => jsonResponse([]),
    SchoolHolidays: () => jsonResponse([]),
  });
  const err = await assertRejects(
    () => fetchCountry("CH", WINDOW, fake),
    OpenHolidaysError,
  );
  assertEquals(err.reason, "invalid_json");
  assertEquals(err.lastError, "invalid_json");
});

Deno.test("fetchCountry: a valid JSON answer of the wrong shape is invalid_shape", async () => {
  const { fetch: fake } = fakeFetch({
    Subdivisions: () => jsonResponse({ not: "a list" }),
    PublicHolidays: () => jsonResponse([]),
    SchoolHolidays: () => jsonResponse([]),
  });
  const err = await assertRejects(
    () => fetchCountry("CH", WINDOW, fake),
    OpenHolidaysError,
  );
  assertEquals(err.reason, "invalid_shape");
});

Deno.test("fetchCountry: a network failure and a timeout are distinct errors", async () => {
  const network = (() => {
    throw new TypeError("connection reset");
  }) as typeof fetch;
  const e1 = await assertRejects(
    () => fetchCountry("CH", WINDOW, network),
    OpenHolidaysError,
  );
  assertEquals(e1.reason, "network");

  const timeout = (() => {
    throw new DOMException("timed out", "TimeoutError");
  }) as typeof fetch;
  const e2 = await assertRejects(
    () => fetchCountry("CH", WINDOW, timeout),
    OpenHolidaysError,
  );
  assertEquals(e2.reason, "timeout");
});

Deno.test("fetchCountry: a bad country is refused before any request", async () => {
  const { fetch: fake, calls } = fakeFetch({});
  for (const bad of ["ch", "CHE", "C", "", "C1", "CH-AG"]) {
    await assertRejects(
      () => fetchCountry(bad, WINDOW, fake),
      OpenHolidaysError,
    );
  }
  assertEquals(calls.length, 0);
});

// ------------------------------------------------------------------ countries

Deno.test("isCountry: two upper-case ASCII letters only", () => {
  assertEquals(isCountry("CH"), true);
  assertEquals(isCountry("DE"), true);
  assertEquals(isCountry("ch"), false);
  assertEquals(isCountry("CHE"), false);
  assertEquals(isCountry("C2"), false);
  assertEquals(isCountry(null), false);
  assertEquals(isCountry(["CH"]), false);
});

Deno.test("countriesFromRegions: distinct, sorted, valid prefixes only", () => {
  assertEquals(
    countriesFromRegions([
      "CH-ZH",
      "DE-BY",
      "CH-AG-ZZ",
      "DE-BE",
      "nonsense",
      "",
      "xx-YY",
      "AT",
    ]),
    ["AT", "CH", "DE"],
  );
});

Deno.test("countriesFromRegions: no codes, no countries", () => {
  assertEquals(countriesFromRegions([]), []);
});

// ------------------------------------------------------------------ regionCovers

Deno.test("regionCovers: a nationwide holiday covers every region of its country", () => {
  assertEquals(regionCovers("DE-BY", "DE", true, []), true);
  assertEquals(regionCovers("CH-ZH-ZH-ZH", "CH", true, []), true);
});

Deno.test("regionCovers: a nationwide holiday does not cover another country", () => {
  assertEquals(regionCovers("AT-9", "CH", true, []), false);
});

Deno.test("regionCovers: a canton covers the districts and municipalities in it", () => {
  assertEquals(regionCovers("CH-ZH-ZH-ZH", "CH", false, ["CH-ZH"]), true);
  assertEquals(regionCovers("CH-ZH-ZH", "CH", false, ["CH-ZH"]), true);
  assertEquals(regionCovers("CH-ZH", "CH", false, ["CH-ZH"]), true);
});

Deno.test("regionCovers: a municipality does not cover its canton", () => {
  assertEquals(regionCovers("CH-ZH", "CH", false, ["CH-ZH-ZH-ZH"]), false);
});

Deno.test("regionCovers: the boundary is a dash, so CH-AG does not cover CH-AGX", () => {
  assertEquals(regionCovers("CH-AGX", "CH", false, ["CH-AG"]), false);
  assertEquals(regionCovers("CH-AG-ZZ", "CH", false, ["CH-AG"]), true);
});

Deno.test("regionCovers: not nationwide and no subdivisions covers nothing", () => {
  assertEquals(regionCovers("CH-ZH", "CH", false, []), false);
});

// ------------------------------------------------------------------ holidayName

Deno.test("holidayName: the locale's language, then German, then the first name", () => {
  const names = { de: "Auffahrt", fr: "Ascension", en: "Ascension Day" };
  assertEquals(holidayName(names, "de-DE"), "Auffahrt");
  assertEquals(holidayName(names, "en-GB"), "Ascension Day");
  assertEquals(holidayName(names, "fr_CH"), "Ascension");
  assertEquals(holidayName(names, "it-IT"), "Auffahrt");
  assertEquals(holidayName({ fr: "Ascension" }, "it-IT"), "Ascension");
});

Deno.test("holidayName: no names is the empty text", () => {
  assertEquals(holidayName({}, "de-DE"), "");
});
