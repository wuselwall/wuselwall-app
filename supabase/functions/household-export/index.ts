// POST {actor} → the household's data as a zip file (FR-5.16, GDPR Art. 20; specs/20 J6):
// export.json describes the export, tables/<table>.json holds each table's rows. The rows are
// read page by page and deflated as they stream out, so a household with years of data needs
// the memory of one page, and no statement runs long. Acts as the caller: the database lets
// only a guardian on a personal device export, and checks that again on every page.
import {
  CORS_HEADERS,
  errorResponse,
  preflight,
  readBody,
  RequestError,
  requirePost,
  userClient,
} from "../_shared/client.ts";
import {
  type ExportPage,
  type ExportStart,
  exportEntries,
  exportFileName,
  PAGE_SIZE,
} from "../_shared/household_export.ts";
import { zipChunks } from "../_shared/zip.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const client = userClient(req);
    const body = await readBody(req);
    const actor = body.actor ?? null;
    if (actor !== null && (typeof actor !== "string" || !UUID.test(actor))) {
      throw new RequestError(400, "body_invalid", "actor must be a profile id or null");
    }

    // Checks the caller and writes the audit row before a single byte goes out.
    const { data, error } = await client.rpc("household_export_begin", { p_actor: actor });
    if (error) throw error;
    const start = data as ExportStart;

    const fetchPage = async (table: string, after: unknown): Promise<ExportPage> => {
      const { data, error } = await client.rpc("household_export_page", {
        p_actor: actor,
        p_table: table,
        p_after: after,
        p_limit: PAGE_SIZE,
      });
      if (error) throw error;
      return data as ExportPage;
    };

    // The 200 is sent before the first page is read. A failure after that breaks the stream
    // off: the app sees an incomplete download, never a zip that looks whole.
    const chunks = zipChunks(exportEntries(start, fetchPage), new Date(start.exported_at));
    return new Response(ReadableStream.from(logged(chunks)), {
      headers: {
        ...CORS_HEADERS,
        // The app's functions client hands back the bytes only for this type.
        "Content-Type": "application/octet-stream",
        "Content-Disposition": `attachment; filename="${exportFileName(start.exported_at)}"`,
      },
    });
  } catch (err) {
    return errorResponse(err);
  }
});

/** Passes the chunks through, logging why the stream broke off (never a token or a row). */
async function* logged(chunks: AsyncGenerator<Uint8Array>): AsyncGenerator<Uint8Array> {
  try {
    yield* chunks;
  } catch (err) {
    const pg = err as { code?: unknown } | null;
    console.error(
      "household export broke off:",
      typeof pg?.code === "string" ? pg.code : err instanceof Error ? err.name : typeof err,
    );
    throw err;
  }
}
