import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { type Calendar, importCalendar } from "./calendar_import.ts";
import { type FetchOptions, type FetchResult } from "./safe_fetch.ts";

const CAL: Calendar = {
  id: "11111111-1111-4111-8111-111111111111",
  url: "https://calendar.example.org/feed.ics",
  etag: '"unchanged"',
  timezone: "Europe/Berlin",
};
const SOURCE = [
  "BEGIN:VCALENDAR",
  "VERSION:2.0",
  "BEGIN:VEVENT",
  "UID:weekly@example.org",
  "DTSTART:20261026T090000",
  "DTEND:20261026T100000",
  "RRULE:FREQ=WEEKLY;BYDAY=MO",
  "SUMMARY:Weekly",
  "END:VEVENT",
  "END:VCALENDAR",
].join("\r\n");

type Row = { starts_at: string; start_date: string };
function fixture() {
  const stores: Array<{ p_rows: Row[] }> = [];
  const failures: string[] = [];
  const svc = {
    rpc(name: string, args: Record<string, unknown>) {
      if (name === "external_calendar_store") {
        stores.push(args as { p_rows: Row[] });
      }
      if (name === "external_calendar_fail") {
        failures.push(args.p_error as string);
      }
      return Promise.resolve({ error: null });
    },
  };
  const fetch = (
    _url: string,
    opts: FetchOptions = {},
  ): Promise<FetchResult> => {
    assertEquals(
      opts.etag,
      undefined,
      "do not let a source ETag freeze derived occurrences",
    );
    return Promise.resolve({ kind: "ok", body: SOURCE, etag: CAL.etag });
  };
  return { svc, fetch, stores, failures };
}

Deno.test("calendar import: an unchanged feed extends the rolling horizon", async () => {
  const f = fixture();
  const first = await importCalendar(
    f.svc,
    CAL,
    new Date("2026-10-25T12:00:00Z"),
    f.fetch,
  );
  const later = await importCalendar(
    f.svc,
    CAL,
    new Date("2027-10-25T12:00:00Z"),
    f.fetch,
  );
  assertEquals(first.status, "refreshed");
  assertEquals(later.status, "refreshed");
  const last = (rows: Row[]) => rows.map((r) => r.starts_at).sort().at(-1)!;
  assert(last(f.stores[1].p_rows) > last(f.stores[0].p_rows));
});

Deno.test("calendar import: unchanged floating events are re-expanded in a new household zone", async () => {
  const f = fixture();
  const now = new Date("2026-10-25T12:00:00Z");
  await importCalendar(f.svc, CAL, now, f.fetch);
  await importCalendar(
    f.svc,
    { ...CAL, timezone: "America/New_York" },
    now,
    f.fetch,
  );
  assert(f.stores[0].p_rows[0].starts_at !== f.stores[1].p_rows[0].starts_at);
});

Deno.test("calendar import: an unsolicited 304 preserves rows and records a failure", async () => {
  const f = fixture();
  const result = await importCalendar(
    f.svc,
    CAL,
    new Date(),
    () => Promise.resolve({ kind: "not_modified", etag: CAL.etag }),
  );
  assertEquals(result, { status: "failed", code: "http_304" });
  assertEquals(f.stores.length, 0);
  assertEquals(f.failures, ["http_304"]);
});
