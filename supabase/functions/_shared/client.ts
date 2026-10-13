// Request plumbing shared by the calendar Edge Functions: the caller-scoped Supabase
// client, JSON and CORS responses, and the mapping from database errors to HTTP.
//
// The client forwards the caller's JWT, so every read runs under RLS as that caller
// (ADR-010). The one exception is serviceClient(), for functions without a user.
import { createClient } from "npm:@supabase/supabase-js@2.75.0";

export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** An error the function raises itself; `code` is a stable, app-readable string. */
export class RequestError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly hint: string | null = null,
  ) {
    super(message);
    this.name = "RequestError";
  }
}

/**
 * A Supabase client that acts as the caller, reading the `api` schema.
 * Throws a 401 RequestError when the request carries no Authorization header.
 */
export function userClient(req: Request) {
  const authorization = req.headers.get("Authorization");
  if (!authorization) {
    throw new RequestError(401, "unauthorized", "missing Authorization header");
  }
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anonKey) {
    throw new Error("SUPABASE_URL and SUPABASE_ANON_KEY must be set");
  }
  return createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    db: { schema: "api" },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/**
 * A service-role client reading the `api` schema. Only for functions without a user:
 * the ICS feed, where a calendar app subscribes with a token and no session. Such a
 * function must act only on what its own input authorises (api.ics_feed returns just
 * that token's data). Never use it where the caller's JWT is available: use userClient.
 */
export function serviceClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set");
  }
  return createClient(url, serviceKey, {
    db: { schema: "api" },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function requirePost(req: Request): void {
  if (req.method !== "POST") {
    throw new RequestError(405, "method_not_allowed", "use POST");
  }
}

/** The request body as a JSON object; anything else is a 400. */
export async function readBody(req: Request): Promise<Record<string, unknown>> {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    throw new RequestError(400, "body_invalid", "request body must be JSON");
  }
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new RequestError(
      400,
      "body_invalid",
      "request body must be an object",
    );
  }
  return body as Record<string, unknown>;
}

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/** Answer an OPTIONS preflight. */
export function preflight(): Response {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

// SQLSTATE → HTTP status. Anything else from PostgREST is a server error.
const STATUS_BY_SQLSTATE: Record<string, number> = {
  "22023": 400, // invalid_parameter_value: raised by the api functions' validation
  "P0002": 400, // no_data_found
  "42501": 403, // insufficient_privilege: revoked device, not a guardian, …
};

/**
 * Maps any error to a JSON body `{code, message, hint}` and an HTTP status.
 * `code` is the PostgREST SQLSTATE for database errors (the message keeps the
 * `WW-<MODULE>-<NNN>` code), or the RequestError's own code. Never logs tokens.
 */
export function errorResponse(err: unknown): Response {
  if (err instanceof RequestError) {
    return json(
      { code: err.code, message: err.message, hint: err.hint },
      err.status,
    );
  }
  const pg = err as
    | { code?: unknown; message?: unknown; hint?: unknown }
    | null;
  if (
    pg !== null &&
    typeof pg === "object" &&
    typeof pg.code === "string" &&
    /^([0-9A-Z]{5}|PGRST\d+)$/.test(pg.code) &&
    typeof pg.message === "string"
  ) {
    return json(
      {
        code: pg.code,
        message: pg.message,
        hint: typeof pg.hint === "string" ? pg.hint : null,
      },
      STATUS_BY_SQLSTATE[pg.code] ?? 500,
    );
  }
  console.error(
    "unhandled error:",
    err instanceof Error ? err.name : typeof err,
  );
  return json({ code: "internal", message: "internal error", hint: null }, 500);
}
