import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.13";
import { RequestError } from "../client.ts";
import { parseDiscoverRequest, parseWindowsRequest } from "./request.ts";

const TODAY = "2026-11-15";
const ID = "0f6b2c1e-3a4d-4e5f-8a9b-1c2d3e4f5a6b";

function refused(fn: () => unknown, needle?: string) {
  const err = assertThrows(fn, RequestError);
  assertEquals(err.status, 400);
  assertEquals(err.code, "invalid_request");
  if (needle) assertEquals(err.message.includes(needle), true, err.message);
}

Deno.test("windows: defaults are today, 18 months, 4 days, everyone", () => {
  assertEquals(parseWindowsRequest({ action: "windows" }, TODAY), {
    from: "2026-11-15",
    to: "2028-05-15",
    minDays: 4,
    memberIds: null,
    tripId: null,
  });
});

Deno.test("windows: the given values are taken, member ids deduplicated", () => {
  assertEquals(
    parseWindowsRequest(
      {
        from: "2027-01-01",
        to: "2027-03-31",
        min_days: 7,
        member_ids: [ID, ID],
        trip_id: ID,
      },
      TODAY,
    ),
    {
      from: "2027-01-01",
      to: "2027-03-31",
      minDays: 7,
      memberIds: [ID],
      tripId: ID,
    },
  );
  // A lone `from` still gets the 18 months after it.
  assertEquals(
    parseWindowsRequest({ from: "2027-01-31" }, TODAY).to,
    "2028-07-31",
  );
});

Deno.test("windows: the range is at most 24 months and from <= to", () => {
  assertEquals(
    parseWindowsRequest({ from: "2026-11-15", to: "2028-11-15" }, TODAY).to,
    "2028-11-15",
  );
  refused(() =>
    parseWindowsRequest({ from: "2026-11-15", to: "2028-11-16" }, TODAY)
  );
  refused(() =>
    parseWindowsRequest({ from: "2027-02-02", to: "2027-02-01" }, TODAY)
  );
  // A default `to` before a late `from`.
  refused(() => parseWindowsRequest({ to: "2026-01-01" }, TODAY), "before");
});

Deno.test("windows: dates, min_days, member ids and trip id are checked", () => {
  refused(() => parseWindowsRequest({ from: "2027-02-30" }, TODAY), "from");
  refused(() => parseWindowsRequest({ from: "15.11.2026" }, TODAY));
  refused(() => parseWindowsRequest({ to: 20270101 }, TODAY));
  refused(() => parseWindowsRequest({ min_days: 1 }, TODAY));
  refused(() => parseWindowsRequest({ min_days: 31 }, TODAY));
  refused(() => parseWindowsRequest({ min_days: 4.5 }, TODAY));
  refused(() => parseWindowsRequest({ min_days: "4" }, TODAY));
  refused(() => parseWindowsRequest({ member_ids: [] }, TODAY));
  refused(() => parseWindowsRequest({ member_ids: "x" }, TODAY));
  refused(() => parseWindowsRequest({ member_ids: ["nope"] }, TODAY));
  refused(() => parseWindowsRequest({ trip_id: "nope" }, TODAY));
});

Deno.test("discover: from and to are required, lang defaults to en", () => {
  refused(() => parseDiscoverRequest({}));
  refused(() => parseDiscoverRequest({ from: "2027-07-01" }));
  assertEquals(
    parseDiscoverRequest({ from: "2027-07-01", to: "2027-07-14" }),
    {
      from: "2027-07-01",
      to: "2027-07-14",
      lang: "en",
      filters: {},
      actorProfileId: null,
    },
  );
});

Deno.test("discover: a full request", () => {
  assertEquals(
    parseDiscoverRequest({
      from: "2027-07-01",
      to: "2027-07-14",
      lang: "fr",
      actor_profile_id: ID,
      filters: {
        temp_min: 24,
        temp_max: 34.5,
        dry: true,
        sea_min: 22,
        tags: ["sea", "island", "sea"],
        effort: "short",
      },
    }),
    {
      from: "2027-07-01",
      to: "2027-07-14",
      lang: "fr",
      actorProfileId: ID,
      filters: {
        temp_min: 24,
        temp_max: 34.5,
        dry: true,
        sea_min: 22,
        tags: ["sea", "island"],
        effort: "short",
      },
    },
  );
});

Deno.test("discover: strict about languages, numbers, tags and efforts", () => {
  const base = { from: "2027-07-01", to: "2027-07-14" };
  refused(() => parseDiscoverRequest({ ...base, lang: "it" }), "lang");
  refused(() => parseDiscoverRequest({ ...base, lang: "de-CH" }));
  refused(() => parseDiscoverRequest({ ...base, filters: [] }));
  refused(() => parseDiscoverRequest({ ...base, filters: { temp_min: "24" } }));
  refused(() => parseDiscoverRequest({ ...base, filters: { temp_min: 99 } }));
  refused(() => parseDiscoverRequest({ ...base, filters: { temp_max: null } }));
  refused(() => parseDiscoverRequest({ ...base, filters: { sea_min: -1 } }));
  refused(() => parseDiscoverRequest({ ...base, filters: { dry: "yes" } }));
  refused(() =>
    parseDiscoverRequest({ ...base, filters: { tags: ["beach"] } })
  );
  refused(() => parseDiscoverRequest({ ...base, filters: { tags: "sea" } }));
  refused(() => parseDiscoverRequest({ ...base, filters: { effort: "far" } }));
  refused(() => parseDiscoverRequest({ ...base, actor_profile_id: 7 }));
  refused(() => parseDiscoverRequest({ from: "2027-07-14", to: "2027-07-01" }));
  refused(() => parseDiscoverRequest({ from: "2027-07-01", to: "2030-07-01" }));
});
