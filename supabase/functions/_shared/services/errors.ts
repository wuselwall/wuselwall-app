// How the `services` and `trips` functions answer a failure: `{error: code}` with the status of
// specs/30 "Edge Functions", and the database's refusals passed through with their hint as the
// code (the shape the apps read, like account-delete's refusals).
import { errorResponse, json } from "../client.ts";
import { ServiceError, type ServiceErrorCode } from "./types.ts";

export const SERVICE_ERROR_STATUS: Record<ServiceErrorCode, number> = {
  service_off: 409,
  service_key_missing: 409,
  service_limit: 429,
  service_failed: 502,
};

/** A response for any error a services-using function can raise. */
export async function serviceErrorResponse(err: unknown): Promise<Response> {
  if (err instanceof ServiceError) {
    return json({ error: err.code }, SERVICE_ERROR_STATUS[err.code]);
  }
  const res = errorResponse(err);
  const body = await res.clone().json() as { code?: string; hint?: string | null };
  const error = res.status >= 500 ? "internal" : (body.hint ?? body.code ?? "refused");
  return json({ error, ...body }, res.status);
}
