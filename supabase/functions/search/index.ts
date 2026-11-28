// POST {query, limit?} → {today, timezone, upcoming, past, more}: the household's
// appointments that say what was typed (FR-10.2, specs/05 "Finding an appointment").
//
// Acts as the caller: RLS decides which events and imported calendars are read, so a
// revoked device gets a 403 and nobody finds another family's appointment. The matching
// and the expansion of series run here (specs/05: never in SQL or the app). A family's
// calendar is small, so the function reads the caller's events and matches them itself;
// nothing is indexed and nothing about a search is stored or logged.
import { Temporal } from "npm:temporal-polyfill@0.3.0";
import {
  errorResponse,
  json,
  preflight,
  readBody,
  RequestError,
  requirePost,
  userClient,
} from "../_shared/client.ts";
import type {
  EventRow,
  ExternalOccurrenceRow,
  OverrideRow,
} from "../_shared/occurrences.ts";
import {
  DEFAULT_LIMIT,
  MAX_LIMIT,
  MAX_QUERY_LENGTH,
  MIN_QUERY_LENGTH,
  searchOccurrences,
} from "../_shared/search.ts";

type Client = ReturnType<typeof userClient>;

/** PostgREST answers with at most this many rows a request (PGRST_DB_MAX_ROWS). */
const PAGE = 1000;
/** No more pages than this per view: a calendar beyond it is searched in part. */
const MAX_PAGES = 10;

/** Every row of `view` the caller may read, page by page in a stable order. */
async function readAll<T>(
  client: Client,
  view: string,
  order: string[],
): Promise<T[]> {
  const rows: T[] = [];
  for (let page = 0; page < MAX_PAGES; page++) {
    let query = client.from(view).select("*");
    for (const column of order) query = query.order(column);
    const { data, error } = await query.range(
      page * PAGE,
      (page + 1) * PAGE - 1,
    );
    if (error) throw error;
    rows.push(...((data ?? []) as T[]));
    if ((data ?? []).length < PAGE) break;
  }
  return rows;
}

function checkQuery(value: unknown): string {
  const query = typeof value === "string" ? value.trim() : "";
  if (query.length < MIN_QUERY_LENGTH || query.length > MAX_QUERY_LENGTH) {
    throw new RequestError(
      400,
      "query_invalid",
      `query must have ${MIN_QUERY_LENGTH} to ${MAX_QUERY_LENGTH} characters`,
    );
  }
  return query;
}

function checkLimit(value: unknown): number {
  if (value === undefined || value === null) return DEFAULT_LIMIT;
  if (
    typeof value !== "number" || !Number.isInteger(value) || value < 1 ||
    value > MAX_LIMIT
  ) {
    throw new RequestError(
      400,
      "limit_invalid",
      `limit must be a whole number from 1 to ${MAX_LIMIT}`,
    );
  }
  return value;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const client = userClient(req);
    const body = await readBody(req);
    const query = checkQuery(body.query);
    const limit = checkLimit(body.limit);

    // The household's timezone has no api view of its own; api.board_week carries it
    // (as the `occurrences` function reads it). The week it builds is discarded.
    const now = Temporal.Now.instant();
    const { data: base, error } = await client.rpc("board_week", {
      p_week_start: now.toZonedDateTimeISO("UTC").toPlainDate().toString(),
    });
    if (error) throw error;
    const timezone = String((base as { timezone: unknown }).timezone);
    const today = now.toZonedDateTimeISO(timezone).toPlainDate().toString();

    const [events, overrides, external] = await Promise.all([
      readAll<EventRow>(client, "events", ["id"]),
      // Every changed date: a cancelled or moved one changes which date is a series' next.
      readAll<OverrideRow>(client, "event_overrides", [
        "event_id",
        "recurrence_id",
      ]),
      readAll<ExternalOccurrenceRow>(client, "external_occurrences", ["id"]),
    ]);

    return json({
      today,
      timezone,
      ...searchOccurrences({
        query,
        events,
        overrides,
        external,
        today,
        tz: timezone,
        limit,
      }),
    });
  } catch (err) {
    return errorResponse(err);
  }
});
