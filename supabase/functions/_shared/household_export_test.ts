import { assertEquals } from "jsr:@std/assert@1.0.13";
import {
  type ExportPage,
  exportEntries,
  exportFileName,
  type ExportStart,
} from "./household_export.ts";

const start: ExportStart = {
  format: "wuselwall-export",
  version: 2,
  exported_at: "2026-10-19T08:30:00Z",
  household: { name: "Familie" },
  tables: ["profile", "audit_log", "streak"],
};

/** Pages of two rows for each table in [rows], recording every request. */
function pager(rows: Record<string, unknown[]>) {
  const calls: [string, unknown][] = [];
  const fetchPage = (table: string, after: unknown): Promise<ExportPage> => {
    calls.push([table, after]);
    const all = rows[table] ?? [];
    const from = after === null ? 0 : (after as { i: number }).i + 1;
    const page = all.slice(from, from + 2);
    return Promise.resolve({
      rows: page,
      next: page.length === 2 ? { i: from + 1 } : null,
    });
  };
  return { calls, fetchPage };
}

async function files(source: ReturnType<typeof pager>): Promise<Record<string, string>> {
  const out: Record<string, string> = {};
  const decoder = new TextDecoder();
  for await (const entry of exportEntries(start, source.fetchPage)) {
    let text = "";
    for await (const chunk of entry.data) text += decoder.decode(chunk);
    out[entry.name] = text;
  }
  return out;
}

Deno.test("each table is a JSON array read page by page, one row per line", async () => {
  const source = pager({
    profile: [{ name: "A" }, { name: "B" }, { name: "C" }],
    audit_log: [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }],
  });
  const out = await files(source);

  assertEquals(Object.keys(out), [
    "tables/profile.json",
    "tables/audit_log.json",
    "tables/streak.json",
    "export.json",
  ]);
  assertEquals(out["tables/profile.json"], '[\n{"name":"A"},\n{"name":"B"},\n{"name":"C"}\n]\n');
  assertEquals(JSON.parse(out["tables/audit_log.json"]), [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }]);
  assertEquals(out["tables/streak.json"], "[]\n");
  assertEquals(source.calls, [
    ["profile", null],
    ["profile", { i: 1 }],
    ["audit_log", null],
    ["audit_log", { i: 1 }],
    ["audit_log", { i: 3 }],
    ["streak", null],
  ]);
});

Deno.test("export.json describes the export and counts every file's rows", async () => {
  const out = await files(pager({ profile: [{}, {}, {}], audit_log: [{}] }));
  assertEquals(JSON.parse(out["export.json"]), {
    format: "wuselwall-export",
    version: 2,
    exported_at: "2026-10-19T08:30:00Z",
    household: { name: "Familie" },
    tables: {
      profile: { file: "tables/profile.json", rows: 3 },
      audit_log: { file: "tables/audit_log.json", rows: 1 },
      streak: { file: "tables/streak.json", rows: 0 },
    },
  });
});

Deno.test("the file name carries the export's date", () => {
  assertEquals(exportFileName("2026-03-07T23:10:00Z"), "wuselwall-export-2026-03-07.zip");
});
