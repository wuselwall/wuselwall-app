// Shared by the weather plug-ins: the seven answer codes, number helpers and the reading of
// untrusted JSON. Pure.
import type { WeatherCode } from "./types.ts";
import { ProviderError } from "./types.ts";

export const round1 = (n: number): number => Math.round(n * 10) / 10;

export const isNum = (v: unknown): v is number => typeof v === "number" && Number.isFinite(v);

/** A JSON object, or a bad_answer. */
export function obj(v: unknown): Record<string, unknown> {
  if (v === null || typeof v !== "object" || Array.isArray(v)) {
    throw new ProviderError("bad_answer");
  }
  return v as Record<string, unknown>;
}

/** A JSON array, or a bad_answer. */
export function arr(v: unknown): unknown[] {
  if (!Array.isArray(v)) throw new ProviderError("bad_answer");
  return v;
}

/** WMO weather interpretation code (Open-Meteo's `weather_code`) to the seven answer codes. */
export function wmoToCode(code: number): WeatherCode | null {
  if (code === 0 || code === 1) return "clear";
  if (code === 2) return "partly";
  if (code === 3) return "cloudy";
  if (code === 45 || code === 48) return "fog";
  if ((code >= 51 && code <= 57) || (code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
    return "rain";
  }
  if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
  if (code >= 95 && code <= 99) return "storm";
  return null;
}

/** What one slice of a day (three or six hours) says, for providers that report slices. */
export type Slice = {
  kind: "clear" | "partly" | "cloudy" | "fog" | "rain" | "snow" | "storm";
  /** Hours of the day the slice starts at, in the place's (approximate) local time. */
  localHour: number;
};

/**
 * One day's code from its slices: a thunderstorm anywhere wins; with at least 1 mm of
 * precipitation the day is snow (if any slice was snow) or rain; fog if any slice was fog;
 * otherwise the average cloudiness of the daytime slices (06-18 local; all slices when none
 * falls there) decides between clear, partly and cloudy.
 */
export function dayCode(slices: Slice[], precipMm: number): WeatherCode {
  if (slices.some((s) => s.kind === "storm")) return "storm";
  if (precipMm >= 1) {
    if (slices.some((s) => s.kind === "snow")) return "snow";
    if (slices.some((s) => s.kind === "rain")) return "rain";
  }
  if (slices.some((s) => s.kind === "fog")) return "fog";
  const rank = (k: Slice["kind"]) => k === "clear" ? 0 : k === "partly" ? 1 : 2;
  const day = slices.filter((s) => s.localHour >= 6 && s.localHour < 18);
  const use = day.length > 0 ? day : slices;
  const mean = use.reduce((sum, s) => sum + rank(s.kind), 0) / use.length;
  return mean < 0.5 ? "clear" : mean < 1.5 ? "partly" : "cloudy";
}

/** YYYY-MM-DD of a Unix time (seconds) shifted by an offset in seconds. */
export function localDate(unixSeconds: number, offsetSeconds: number): string {
  return new Date((unixSeconds + offsetSeconds) * 1000).toISOString().slice(0, 10);
}

/** The hour of day (0-23) of a Unix time shifted by an offset. */
export function localHour(unixSeconds: number, offsetSeconds: number): number {
  return new Date((unixSeconds + offsetSeconds) * 1000).getUTCHours();
}

/** Great-circle distance in kilometres. */
export function haversineKm(a: { lat: number; lon: number }, b: { lat: number; lon: number }): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}
