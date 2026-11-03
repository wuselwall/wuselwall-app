// The gate of the timetable scan (security review 2026-11-01, F14): how much a request may
// carry before it is read whole, and what the database's answer to "may this account scan
// now?" (api.timetable_scan_claim) means for the caller. Pure, so it is tested without a
// server; index.ts wires it in.
import { RequestError } from "../_shared/client.ts";

/** A 6 MB picture is 8 MB of base64; the hints (languages, subjects) are a few hundred KB. */
export const MAX_BODY_BYTES = 9 * 1024 * 1024;

function tooLarge(): RequestError {
  return new RequestError(
    413,
    "image_too_large",
    "the request is larger than the picture limit allows",
  );
}

/**
 * The request body as a JSON object, read in chunks and refused as soon as it exceeds `max`
 * bytes: a declared Content-Length above the limit is refused before anything is read, and a
 * body without one (chunked) stops at the limit instead of being buffered whole.
 */
export async function readBoundedBody(
  req: Request,
  max: number = MAX_BODY_BYTES,
): Promise<Record<string, unknown>> {
  const declared = req.headers.get("content-length");
  if (declared !== null && /^\d+$/.test(declared) && Number(declared) > max) {
    throw tooLarge();
  }
  if (!req.body) {
    throw new RequestError(400, "body_invalid", "request body must be JSON");
  }
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > max) {
      await reader.cancel();
      throw tooLarge();
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  let body: unknown;
  try {
    body = JSON.parse(new TextDecoder().decode(bytes));
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

/**
 * What api.timetable_scan_claim answered, as the error to send, or null when the scan may go
 * ahead. The function raises (42501, mapped to 403 by errorResponse) for an account that is
 * not a live household device; a result `{ok: false, reason}` is the per-account limit, a 429.
 * Anything else is a server that does not know the function yet: refused, never let through.
 */
export function claimRefusal(answer: unknown): RequestError | null {
  const a = answer as { ok?: unknown; reason?: unknown } | null;
  if (a !== null && typeof a === "object" && a.ok === true) return null;
  if (
    a !== null && typeof a === "object" && a.ok === false &&
    a.reason === "rate_limited"
  ) {
    return new RequestError(
      429,
      "scan_rate_limited",
      "at most ten scans in ten minutes",
      "scan_rate_limited",
    );
  }
  return new RequestError(
    403,
    "unauthorized",
    "the server did not allow the scan",
  );
}
