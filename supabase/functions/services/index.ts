// POST {action, ...} → opt-in services for the household's own providers (ADR-022, specs/30
// "Edge Functions"): `catalogue`, `test`, `geocode`, `forecast`, `climate`, `route`, `map`.
//
// The caller is verified by Auth, then by the database as the caller (`api.service_request`:
// adult, no kiosk, the household's device; a guardian for `test`). Only after that does the
// service role read the family's keys and the shared cache (see _shared/services/runner.ts,
// the documented exception of the same kind as calendar-import). Coordinates are rounded to
// two decimals before any provider sees them. Errors are `{error: code}`.
import {
  json,
  preflight,
  readBody,
  RequestError,
  requirePost,
} from "../_shared/client.ts";
import { verifiedCaller } from "../_shared/caller.ts";
import { serviceErrorResponse } from "../_shared/services/errors.ts";
import { catalogue, findProvider } from "../_shared/services/registry.ts";
import { openServices } from "../_shared/services/runner.ts";
import type { LatLon } from "../_shared/services/types.ts";

const invalid = (message: string) => new RequestError(400, "invalid_request", message, "invalid_request");

/** A finite number within [min, max]. */
function num(value: unknown, name: string, min: number, max: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    throw invalid(`${name} must be a number from ${min} to ${max}`);
  }
  return value;
}

function integer(value: unknown, name: string, min: number, max: number, fallback?: number): number {
  if (value === undefined && fallback !== undefined) return fallback;
  const n = num(value, name, min, max);
  if (!Number.isInteger(n)) throw invalid(`${name} must be a whole number`);
  return n;
}

function latLon(lat: unknown, lon: unknown, name = ""): LatLon {
  return {
    lat: num(lat, `${name}lat`, -90, 90),
    lon: num(lon, `${name}lon`, -180, 180),
  };
}

function place(value: unknown, name: string): LatLon {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw invalid(`${name} must be {lat, lon}`);
  }
  const p = value as Record<string, unknown>;
  return latLon(p.lat, p.lon, `${name}.`);
}

const LANGS = ["de", "en", "fr", "es"];

function actorOf(body: Record<string, unknown>): string | null {
  const a = body.actor_profile_id;
  if (a === undefined || a === null) return null;
  if (typeof a !== "string" || !/^[0-9a-f-]{36}$/i.test(a)) {
    throw invalid("actor_profile_id must be a uuid");
  }
  return a;
}

async function handle(req: Request): Promise<Response> {
  requirePost(req);
  await verifiedCaller(req); // 401 for a token Auth does not accept
  const body = await readBody(req);
  const action = body.action;

  if (action === "catalogue") return json(catalogue());

  const actor = actorOf(body);

  switch (action) {
    case "test": {
      const id = body.provider;
      if (typeof id !== "string" || !findProvider(id)) throw invalid("provider is unknown");
      const services = await openServices(req, null, actor);
      return json(await services.test(id));
    }
    case "geocode": {
      const q = typeof body.q === "string" ? body.q.trim() : "";
      if (q.length < 2 || q.length > 120) throw invalid("q must be 2 to 120 characters");
      const lang = body.lang === undefined ? "en" : body.lang;
      if (typeof lang !== "string" || !LANGS.includes(lang)) throw invalid("lang must be de, en, fr or es");
      const services = await openServices(req, "geocode", actor);
      const a = await services.ask("geocode", { q, lang });
      return json({ places: a.data.places, provider: a.provider, attribution: a.attribution });
    }
    case "forecast": {
      const at = latLon(body.lat, body.lon);
      const services = await openServices(req, "forecast", actor);
      const a = await services.ask("forecast", at);
      return json({ days: a.data.days, provider: a.provider, attribution: a.attribution });
    }
    case "climate": {
      const at = latLon(body.lat, body.lon);
      const services = await openServices(req, "climate", actor);
      const a = await services.ask("climate", at);
      return json({ months: a.data.months, provider: a.provider, attribution: a.attribution });
    }
    case "route": {
      const from = place(body.from, "from");
      const to = place(body.to, "to");
      const services = await openServices(req, "route", actor);
      const a = await services.ask("route", { from, to });
      return json({ km: a.data.km, minutes: a.data.minutes, provider: a.provider, attribution: a.attribution });
    }
    case "map": {
      const at = latLon(body.lat, body.lon);
      const zoom = integer(body.zoom, "zoom", 1, 16, 9);
      const width = integer(body.width, "width", 100, 640);
      const height = integer(body.height, "height", 100, 640);
      const services = await openServices(req, "map", actor);
      const a = await services.ask("map", { ...at, zoom, width, height });
      return json({
        image_base64: a.data.image_base64,
        mime: a.data.mime,
        provider: a.provider,
        attribution: a.attribution,
      });
    }
    default:
      throw invalid("action is unknown");
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    return await handle(req);
  } catch (err) {
    return await serviceErrorResponse(err);
  }
});
