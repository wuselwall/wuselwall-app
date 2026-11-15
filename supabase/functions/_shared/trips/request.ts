// Validation of the `trips` function's bodies (specs/30 "Edge Functions"). Pure: a body in,
// a typed request or a 400 `invalid_request` out. Dates are 'YYYY-MM-DD', numbers are finite
// and in sane ranges, tags and efforts come from the known sets.
import { Temporal } from "npm:temporal-polyfill@0.3.0";
import { checkDay } from "../calendar_data.ts";
import { RequestError } from "../client.ts";
import { type Lang, LANGS, type Tag, TAGS } from "./destinations.ts";
import { type Effort, type Filters } from "./discover.ts";

export const INVALID = "invalid_request";
/** How far ahead windows are computed unless the request says otherwise. */
export const DEFAULT_MONTHS = 18;
/** The longest range a request may ask for. */
export const MAX_MONTHS = 24;
export const DEFAULT_MIN_DAYS = 4;
export const MAX_MEMBERS = 50;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EFFORTS: readonly Effort[] = ["near", "car", "short", "medium", "long"];

function invalid(message: string): RequestError {
  return new RequestError(400, INVALID, message);
}

function day(value: unknown, name: string): string {
  try {
    return checkDay(value, INVALID);
  } catch {
    throw invalid(`${name} must be a date YYYY-MM-DD`);
  }
}

function uuid(value: unknown, name: string): string {
  if (typeof value !== "string" || !UUID.test(value)) {
    throw invalid(`${name} must be a uuid`);
  }
  return value;
}

function number(
  value: unknown,
  name: string,
  min: number,
  max: number,
): number {
  if (
    typeof value !== "number" || !Number.isFinite(value) || value < min ||
    value > max
  ) {
    throw invalid(`${name} must be a number from ${min} to ${max}`);
  }
  return value;
}

/** A date range: from <= to, at most MAX_MONTHS long. */
function range(from: string, to: string): void {
  if (to < from) throw invalid("to is before from");
  const limit = Temporal.PlainDate.from(from).add({ months: MAX_MONTHS })
    .toString();
  if (to > limit) {
    throw invalid(`the range is longer than ${MAX_MONTHS} months`);
  }
}

export type WindowsRequest = {
  from: string;
  to: string;
  minDays: number;
  /** null: every active member. */
  memberIds: string[] | null;
  tripId: string | null;
};

export function parseWindowsRequest(
  body: Record<string, unknown>,
  today: string,
): WindowsRequest {
  const from = body.from === undefined ? today : day(body.from, "from");
  const to = body.to === undefined
    ? Temporal.PlainDate.from(from).add({ months: DEFAULT_MONTHS }).toString()
    : day(body.to, "to");
  range(from, to);

  let minDays = DEFAULT_MIN_DAYS;
  if (body.min_days !== undefined) {
    minDays = number(body.min_days, "min_days", 2, 30);
    if (!Number.isInteger(minDays)) {
      throw invalid("min_days must be a whole number");
    }
  }

  let memberIds: string[] | null = null;
  if (body.member_ids !== undefined) {
    const ids = body.member_ids;
    if (!Array.isArray(ids) || ids.length === 0 || ids.length > MAX_MEMBERS) {
      throw invalid(`member_ids must list 1 to ${MAX_MEMBERS} profile ids`);
    }
    memberIds = [...new Set(ids.map((id) => uuid(id, "member_ids")))];
  }

  const tripId = body.trip_id === undefined || body.trip_id === null
    ? null
    : uuid(body.trip_id, "trip_id");
  return { from, to, minDays, memberIds, tripId };
}

export type DiscoverRequest = {
  from: string;
  to: string;
  lang: Lang;
  filters: Filters;
  actorProfileId: string | null;
};

export function parseDiscoverRequest(
  body: Record<string, unknown>,
): DiscoverRequest {
  if (body.from === undefined || body.to === undefined) {
    throw invalid("from and to are required");
  }
  const from = day(body.from, "from");
  const to = day(body.to, "to");
  range(from, to);

  let lang: Lang = "en";
  if (body.lang !== undefined) {
    if (!LANGS.includes(body.lang as Lang)) {
      throw invalid(`lang must be one of ${LANGS.join(", ")}`);
    }
    lang = body.lang as Lang;
  }

  const raw = body.filters ?? {};
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    throw invalid("filters must be an object");
  }
  const f = raw as Record<string, unknown>;
  const filters: Filters = {};
  if (f.temp_min !== undefined) {
    filters.temp_min = number(f.temp_min, "temp_min", -60, 60);
  }
  if (f.temp_max !== undefined) {
    filters.temp_max = number(f.temp_max, "temp_max", -60, 60);
  }
  if (f.sea_min !== undefined) {
    filters.sea_min = number(f.sea_min, "sea_min", 0, 40);
  }
  if (f.dry !== undefined) {
    if (typeof f.dry !== "boolean") throw invalid("dry must be true or false");
    filters.dry = f.dry;
  }
  if (f.tags !== undefined) {
    if (
      !Array.isArray(f.tags) || f.tags.length > TAGS.length ||
      !f.tags.every((t) => TAGS.includes(t as Tag))
    ) {
      throw invalid(`tags must be from ${TAGS.join(", ")}`);
    }
    filters.tags = [...new Set(f.tags as Tag[])];
  }
  if (f.effort !== undefined) {
    if (!EFFORTS.includes(f.effort as Effort)) {
      throw invalid(`effort must be one of ${EFFORTS.join(", ")}`);
    }
    filters.effort = f.effort as Effort;
  }

  const actorProfileId = body.actor_profile_id === undefined ||
      body.actor_profile_id === null
    ? null
    : uuid(body.actor_profile_id, "actor_profile_id");
  return { from, to, lang, filters, actorProfileId };
}
