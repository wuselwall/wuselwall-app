// POST /functions/v1/timetable-scan → a timetable payload read from a photo (specs/24
// "Scanning"). The app sends the picture; this function hands it to the family's own OCR
// service (OCR_URL, an optional container of the stack: infra/ocr) and turns the text boxes
// it gets back into the grid (_shared/timetable_ocr.ts). Nothing is stored: the answer goes
// back to the caller, who reviews it on the import preview and applies it with their own
// writes. No third party is contacted (NFR-9); without OCR_URL the answer says so.
//
// The caller is a signed-in member: the JWT is verified with Auth. Reading a sheet changes
// nothing, so no guardian check here; applying it needs a guardian, in the app's own writes.
//
// Body: {image: <base64>, mime: "image/jpeg" | "image/png" | "image/webp"}. At most 6 MB.
// Answer: {payload, placed, unplaced, columns, rows, lines}.
// Errors (code, HTTP): ocr_not_configured 503, image_invalid 400, image_too_large 413,
// ocr_failed 502, scan_nothing_found 422.
import { verifiedCaller } from "../_shared/caller.ts";
import {
  errorResponse,
  json,
  preflight,
  readBody,
  RequestError,
  requirePost,
} from "../_shared/client.ts";
import { type OcrLine, parseTimetableScan } from "../_shared/timetable_ocr.ts";

const MAX_IMAGE_BYTES = 6 * 1024 * 1024;
const OCR_TIMEOUT_MS = 60_000;
const MAX_LINES = 2000;
const MIMES = new Set(["image/jpeg", "image/png", "image/webp"]);

/** The OCR service's answer: `{lines: [{text, box, score}]}` (infra/ocr/server.py). */
function linesOf(data: unknown): OcrLine[] {
  const lines = (data as { lines?: unknown } | null)?.lines;
  if (!Array.isArray(lines)) {
    throw new RequestError(
      502,
      "ocr_failed",
      "the OCR service answered without lines",
    );
  }
  const out: OcrLine[] = [];
  for (const l of lines.slice(0, MAX_LINES)) {
    const text = (l as { text?: unknown })?.text;
    const box = (l as { box?: unknown })?.box;
    const score = (l as { score?: unknown })?.score;
    if (typeof text !== "string" || !Array.isArray(box) || box.length < 8) {
      continue;
    }
    if (!box.every((n) => typeof n === "number" && Number.isFinite(n))) {
      continue;
    }
    out.push({
      text,
      box: box as number[],
      score: typeof score === "number" ? score : undefined,
    });
  }
  return out;
}

/** Posts the picture to the OCR service as multipart form data. */
export async function recognise(
  url: string,
  image: Uint8Array,
  mime: string,
): Promise<OcrLine[]> {
  const form = new FormData();
  form.append(
    "image",
    new Blob([new Uint8Array(image)], { type: mime }),
    "sheet",
  );
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), OCR_TIMEOUT_MS);
  let response: Response;
  try {
    response = await fetch(url, {
      method: "POST",
      body: form,
      signal: controller.signal,
    });
  } catch {
    throw new RequestError(502, "ocr_failed", "the OCR service did not answer");
  } finally {
    clearTimeout(timer);
  }
  if (!response.ok) {
    throw new RequestError(
      502,
      "ocr_failed",
      `the OCR service answered ${response.status}`,
    );
  }
  let data: unknown;
  try {
    data = await response.json();
  } catch {
    throw new RequestError(
      502,
      "ocr_failed",
      "the OCR service answered no JSON",
    );
  }
  return linesOf(data);
}

function decodeImage(
  body: Record<string, unknown>,
): { image: Uint8Array; mime: string } {
  const mime = typeof body.mime === "string" ? body.mime : "image/jpeg";
  if (!MIMES.has(mime)) {
    throw new RequestError(
      400,
      "image_invalid",
      "mime must be jpeg, png or webp",
    );
  }
  const encoded = body.image;
  if (typeof encoded !== "string" || encoded.length === 0) {
    throw new RequestError(400, "image_invalid", "image must be base64 text");
  }
  // 4 base64 characters carry 3 bytes; refuse before decoding what is clearly too big.
  if (encoded.length > MAX_IMAGE_BYTES * 4 / 3 + 4) {
    throw new RequestError(
      413,
      "image_too_large",
      "the picture is larger than 6 MB",
    );
  }
  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(atob(encoded), (c) => c.charCodeAt(0));
  } catch {
    throw new RequestError(400, "image_invalid", "image is not base64");
  }
  if (bytes.length > MAX_IMAGE_BYTES) {
    throw new RequestError(
      413,
      "image_too_large",
      "the picture is larger than 6 MB",
    );
  }
  return { image: bytes, mime };
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    await verifiedCaller(req);
    const url = Deno.env.get("OCR_URL");
    if (!url) {
      throw new RequestError(
        503,
        "ocr_not_configured",
        "this server has no OCR service",
        "ocr_not_configured",
      );
    }
    const { image, mime } = decodeImage(await readBody(req));
    const lines = await recognise(url, image, mime);
    const result = parseTimetableScan(lines);
    if (!result) {
      throw new RequestError(
        422,
        "scan_nothing_found",
        "no timetable grid in the picture",
        "scan_nothing_found",
      );
    }
    return json({ ...result, lines: lines.length });
  } catch (err) {
    return errorResponse(err);
  }
});
