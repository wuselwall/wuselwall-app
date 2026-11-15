// OpenStreetMap Nominatim (https://nominatim.openstreetmap.org), place search, no key.
//
// Written on 2026-11-15 from the documentation in `docs`; checked against a live answer
// (fixtures/nominatim_geocode.json). Usage policy: at most one request a second for the whole
// application (the plug-in spaces its calls by MIN_GAP_MS inside one process; several server
// processes are not coordinated, so `per_day` stays small), an identifying User-Agent (set by
// the runner's fetch), no autocomplete (the apps send a finished search, never a keystroke),
// cache the answers (the runner keeps them 90 days), show the attribution. Data under ODbL.
import { type Places, type Provider, type ProviderContext, ProviderError } from "../types.ts";
import { fetchJson, query } from "../http.ts";
import { arr, isNum, obj } from "../weather.ts";

/** The policy's "absolute maximum of 1 request per second", with a little room. */
export const spacing = { minGapMs: 1100 };

let last = 0;
let chain: Promise<void> = Promise.resolve();

/** Waits until the previous call is at least minGapMs old; calls queue in order. */
async function throttle(signal: AbortSignal): Promise<void> {
  const turn = chain.then(async () => {
    const wait = last + spacing.minGapMs - Date.now();
    if (wait > 0) await new Promise((resolve) => setTimeout(resolve, wait));
    last = Date.now();
  });
  chain = turn.catch(() => {});
  await turn;
  if (signal.aborted) throw new ProviderError("timeout");
}

export function parseGeocode(json: unknown): Places {
  const places: Places["places"] = [];
  for (const raw of arr(json)) {
    const r = obj(raw);
    const lat = Number(r.lat);
    const lon = Number(r.lon);
    if (!isNum(lat) || !isNum(lon) || typeof r.lat !== "string") continue;
    const address = r.address === undefined ? {} : obj(r.address);
    const display = typeof r.display_name === "string" ? r.display_name.split(",")[0].trim() : "";
    const name = typeof r.name === "string" && r.name !== "" ? r.name : display;
    if (name === "") continue;
    const place: Places["places"][number] = {
      name,
      country: typeof address.country_code === "string" ? address.country_code.toUpperCase() : "",
      lat,
      lon,
    };
    const admin = [address.state, address.region, address.county].find((v) =>
      typeof v === "string" && v !== ""
    );
    if (typeof admin === "string") place.admin = admin;
    places.push(place);
  }
  return { places };
}

async function geocode(q: { q: string; lang: string }, ctx: ProviderContext): Promise<Places> {
  await throttle(ctx.signal);
  const url = "https://nominatim.openstreetmap.org/search?" + query({
    q: q.q,
    format: "jsonv2",
    addressdetails: 1,
    limit: 5,
    "accept-language": q.lang,
  });
  return parseGeocode(await fetchJson(ctx, url));
}

export const nominatim: Provider = {
  id: "nominatim",
  name: "OpenStreetMap Nominatim",
  homepage: "https://nominatim.openstreetmap.org",
  key_url: null,
  needs_key: false,
  cost: "free",
  receives: ["search_text"],
  attribution: "Data © OpenStreetMap contributors (ODbL)",
  hosts: ["nominatim.openstreetmap.org"],
  budget: { per_day: 100 },
  docs: [
    "https://operations.osmfoundation.org/policies/nominatim/ read 2026-11-15",
    "https://nominatim.org/release-docs/latest/api/Search/ read 2026-11-15",
  ],
  geocode,
};

