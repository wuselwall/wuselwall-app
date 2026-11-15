import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { DESTINATIONS, LANGS, TAGS } from "./destinations.ts";

// [south, north, west, east] of each country the catalogue uses, rounded outwards. A box
// catches a wrong sign or a swapped pair; it does not prove a place is where it should be.
const BOX: Record<string, [number, number, number, number]> = {
  AE: [22.6, 26.1, 51.5, 56.4],
  AL: [39.6, 42.7, 19.2, 21.1],
  AT: [46.3, 49.1, 9.5, 17.2],
  AU: [-44, -10, 113, 154],
  BE: [49.5, 51.6, 2.5, 6.5],
  BG: [41.2, 44.3, 22.3, 28.7],
  BR: [-34, 5.3, -74, -34.8],
  CA: [41.6, 83.2, -141.1, -52.5],
  CH: [45.8, 47.9, 5.9, 10.5],
  CR: [8.0, 11.3, -86.0, -82.5],
  CU: [19.8, 23.3, -85.0, -74.1],
  CV: [14.7, 17.3, -25.4, -22.6],
  CY: [34.5, 35.8, 32.2, 34.7],
  CZ: [48.5, 51.1, 12.0, 18.9],
  DE: [47.2, 55.1, 5.8, 15.1],
  DK: [54.5, 57.8, 8.0, 15.2],
  DO: [17.5, 19.95, -72.1, -68.3],
  EE: [57.5, 59.8, 21.7, 28.3],
  EG: [21.9, 31.7, 24.6, 36.9],
  ES: [27.5, 43.9, -18.5, 4.5],
  FI: [59.7, 70.2, 19.0, 31.6],
  FO: [61.3, 62.4, -7.7, -6.2],
  FR: [41.3, 51.2, -5.2, 9.6],
  GB: [49.8, 60.9, -8.7, 1.8],
  GR: [34.8, 41.8, 19.3, 28.3],
  HR: [42.3, 46.6, 13.4, 19.5],
  HU: [45.7, 48.6, 16.0, 22.9],
  ID: [-11.1, 6.1, 95, 141],
  IE: [51.3, 55.5, -10.7, -5.9],
  IN: [6.5, 35.7, 68, 97.5],
  IS: [63.2, 66.6, -24.6, -13.4],
  IT: [35.5, 47.1, 6.6, 18.6],
  JP: [24, 46, 122.9, 146],
  LK: [5.9, 9.9, 79.5, 82.0],
  LV: [55.6, 58.1, 20.9, 28.3],
  MA: [27.6, 35.9, -13.2, -1.0],
  ME: [41.8, 43.6, 18.4, 20.4],
  MT: [35.7, 36.2, 14.1, 14.7],
  MU: [-20.6, -19.9, 57.3, 57.9],
  MV: [-0.7, 7.2, 72.6, 73.8],
  MX: [14.5, 32.8, -118.5, -86.5],
  NA: [-29.0, -16.9, 11.7, 25.3],
  NL: [50.7, 53.6, 3.3, 7.3],
  NO: [57.9, 71.3, 4.4, 31.2],
  NZ: [-47.5, -34, 166, 178.6],
  OM: [16.6, 26.4, 52, 59.9],
  PL: [49.0, 54.9, 14.1, 24.2],
  PT: [32.3, 42.2, -31.5, -6.1],
  SC: [-10.3, -3.7, 46.2, 56.3],
  SE: [55.3, 69.1, 10.9, 24.2],
  SG: [1.1, 1.5, 103.6, 104.1],
  SI: [45.4, 46.9, 13.3, 16.6],
  SK: [47.7, 49.7, 16.8, 22.6],
  TH: [5.6, 20.5, 97.3, 105.7],
  TN: [30.2, 37.6, 7.5, 11.6],
  TR: [35.8, 42.2, 25.6, 44.9],
  TZ: [-11.8, -1.0, 29.3, 40.5],
  US: [18.5, 72, -170, -66.5],
  VN: [8.4, 23.4, 102.1, 109.5],
  ZA: [-35.0, -22.1, 16.4, 32.9],
};

Deno.test("the catalogue has 120 to 200 places with unique keys", () => {
  assert(DESTINATIONS.length >= 120 && DESTINATIONS.length <= 200);
  const keys = DESTINATIONS.map((d) => d.key);
  assertEquals(new Set(keys).size, keys.length);
  for (const key of keys) assert(/^[a-z0-9_-]{1,60}$/.test(key), key);
});

Deno.test("every place has four names, a country, tags and two-decimal coordinates", () => {
  for (const d of DESTINATIONS) {
    for (const lang of LANGS) {
      assert(d.names[lang].trim() !== "", `${d.key} has no ${lang} name`);
    }
    assertEquals(Object.keys(d.names).sort(), [...LANGS].sort());
    assert(/^[A-Z]{2}$/.test(d.country), d.key);
    assert(d.tags.length >= 1, d.key);
    assertEquals(new Set(d.tags).size, d.tags.length, d.key);
    for (const tag of d.tags) assert(TAGS.includes(tag), `${d.key}: ${tag}`);
    assert(d.lat >= -90 && d.lat <= 90 && d.lon >= -180 && d.lon <= 180, d.key);
    for (const n of [d.lat, d.lon]) {
      assertEquals(Math.round(n * 100) / 100, n, `${d.key}: ${n}`);
    }
  }
});

Deno.test("every place lies inside its country's bounding box", () => {
  for (const d of DESTINATIONS) {
    const box = BOX[d.country];
    assert(box !== undefined, `${d.key}: no box for ${d.country}`);
    const [south, north, west, east] = box;
    assert(
      d.lat >= south && d.lat <= north && d.lon >= west && d.lon <= east,
      `${d.key} (${d.lat}, ${d.lon}) is outside ${d.country}`,
    );
  }
});

Deno.test("the boxes are for countries the catalogue uses", () => {
  const used = new Set(DESTINATIONS.map((d) => d.country));
  for (const code of Object.keys(BOX)) {
    assert(used.has(code), `unused box ${code}`);
  }
});

Deno.test("island and sea places carry the tags a filter expects", () => {
  const byKey = new Map(DESTINATIONS.map((d) => [d.key, d]));
  assertEquals(byKey.get("mallorca")?.tags, ["sea", "island"]);
  assert(byKey.get("ticino")?.tags.includes("lake"));
  assert(byKey.get("bali")?.tags.includes("long_haul"));
  // The near long-haul classics are not "long_haul" tagged: they count as medium.
  for (
    const key of [
      "hurghada",
      "marrakech",
      "turkish_riviera",
      "dubai",
      "tenerife",
    ]
  ) {
    assert(!byKey.get(key)?.tags.includes("long_haul"), key);
  }
});

Deno.test("the German names of the examples in the spec are in the catalogue", () => {
  const de = DESTINATIONS.map((d) => d.names.de);
  for (
    const name of [
      "Mallorca",
      "Sardinien",
      "Kreta",
      "Tessin",
      "Südtirol",
      "Toskana",
      "Algarve",
      "Bretagne",
      "Sylt",
      "Rügen",
      "Gardasee",
      "Bodensee",
      "Engadin",
      "Salzkammergut",
      "Dalmatien",
      "Madeira",
      "Azoren",
      "Zypern",
      "Paris",
      "London",
      "Rom",
      "Wien",
      "Kopenhagen",
      "Lissabon",
      "Amsterdam",
      "Prag",
      "Lofoten",
      "Island",
      "Lappland",
      "Malediven",
      "Kuba",
      "Kapstadt",
      "Tokio",
    ]
  ) {
    assert(de.includes(name), `missing ${name}`);
  }
});
