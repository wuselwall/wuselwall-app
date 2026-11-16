// POST {action: 'windows' | 'discover', …} → the trip planner's server-side logic (specs/30
// "Edge Functions"). Both actions act as the caller (ADR-010): RLS decides what is visible, so
// a revoked device gets a 403.
//
//   windows   when could the travellers go: time windows from the school Ferien and public
//             holidays, with the calendar's conflicts. Reads the database only, contacts nobody.
//   discover  where is it warm and dry: the bundled catalogue and the family's ideas, ranked.
//             The one action that may reach a provider, and only through the services runner,
//             which first asks the database whether this caller may (adults, no kiosk) and
//             refuses otherwise.
import {
  errorResponse,
  json,
  preflight,
  readBody,
  RequestError,
  requirePost,
  userClient,
} from "../_shared/client.ts";
import { openServices } from "../_shared/services/runner.ts";
import { ServiceError } from "../_shared/services/types.ts";
import { loadWindows } from "../_shared/trips/data.ts";
import { discover, type Idea } from "../_shared/trips/discover.ts";
import { parseDiscoverRequest } from "../_shared/trips/request.ts";

/** Climate fetches one discover request makes at most (the runner's budget may allow fewer). */
const FETCH_LIMIT = 6;

const SERVICE_STATUS: Record<ServiceError["code"], number> = {
  service_off: 409,
  service_key_missing: 409,
  service_limit: 429,
  service_failed: 502,
};

type TripRow = {
  id: string;
  title: string;
  destination_name: string | null;
  destination_key: string | null;
  country: string | null;
  lat: number | null;
  lon: number | null;
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const body = await readBody(req);
    switch (body.action) {
      case "windows":
        return await windows(req, body);
      case "discover":
        return await discoverPlaces(req, body);
      default:
        throw new RequestError(
          400,
          "invalid_request",
          "action must be windows or discover",
        );
    }
  } catch (err) {
    if (err instanceof ServiceError) {
      return errorResponse(
        new RequestError(SERVICE_STATUS[err.code], err.code, err.code),
      );
    }
    return errorResponse(err);
  }
});

async function windows(
  req: Request,
  body: Record<string, unknown>,
): Promise<Response> {
  const windows = await loadWindows(userClient(req), body, new Date());
  return json({ windows });
}

async function discoverPlaces(
  req: Request,
  body: Record<string, unknown>,
): Promise<Response> {
  const request = parseDiscoverRequest(body);
  // The door first: the database decides, as the caller, whether this caller may use a
  // service at all. Its refusal (403) passes through as the other functions' do.
  const services = await openServices(req, "climate", request.actorProfileId);

  const client = userClient(req);
  const [home, trips] = await Promise.all([
    client.from("trip_home").select("lat, lon").limit(1),
    client.from("trips")
      .select("id, title, destination_name, destination_key, country, lat, lon")
      .eq("stage", "idea")
      .not("lat", "is", null)
      .not("lon", "is", null),
  ]);
  if (home.error) throw home.error;
  if (trips.error) throw trips.error;
  const homeRow = (home.data as { lat: number; lon: number }[] | null)?.[0];
  const ideas: Idea[] = ((trips.data ?? []) as TripRow[]).map((t) => ({
    trip_id: t.id,
    name: t.destination_name !== null && t.destination_name !== ""
      ? t.destination_name
      : t.title,
    destination_key: t.destination_key,
    country: t.country,
    lat: Number(t.lat),
    lon: Number(t.lon),
  }));

  return json(
    await discover(
      {
        from: request.from,
        to: request.to,
        lang: request.lang,
        filters: request.filters,
        home: homeRow
          ? { lat: Number(homeRow.lat), lon: Number(homeRow.lon) }
          : null,
        ideas,
        fetchLimit: FETCH_LIMIT,
      },
      services,
    ),
  );
}
