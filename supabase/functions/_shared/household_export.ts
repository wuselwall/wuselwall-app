// The household export as zip entries (FR-5.16, GDPR Art. 20; specs/20 J6). The database
// hands out one page of one table at a time (api.household_export_page); each table becomes
// tables/<table>.json, a JSON array with one row per line, and export.json describes the
// export and counts the rows of each file. Only one page is held at a time, so years of data
// stream through in the memory of a page.
import type { ZipEntry } from "./zip.ts";

/** What api.household_export_begin returns. */
export type ExportStart = {
  format: string;
  version: number;
  exported_at: string;
  household: unknown;
  tables: string[];
};

/** One page of api.household_export_page: rows, and the cursor of the next page or null. */
export type ExportPage = { rows: unknown[]; next: unknown };

export type FetchPage = (table: string, after: unknown) => Promise<ExportPage>;

/** Rows per page: about a megabyte of audit rows, well inside any statement timeout. */
export const PAGE_SIZE = 2000;

/** `wuselwall-export-YYYY-MM-DD.zip` for the UTC date of [exportedAt]. */
export function exportFileName(exportedAt: string): string {
  return `wuselwall-export-${new Date(exportedAt).toISOString().slice(0, 10)}.zip`;
}

/** The zip entries of an export: one file per table, then export.json. */
export async function* exportEntries(
  start: ExportStart,
  fetchPage: FetchPage,
): AsyncGenerator<ZipEntry> {
  const files: Record<string, { file: string; rows: number }> = {};
  for (const table of start.tables) {
    const file = `tables/${table}.json`;
    files[table] = { file, rows: 0 };
    yield {
      name: file,
      data: tableJson(table, fetchPage, (rows) => files[table].rows = rows),
    };
  }
  // The zip writer reads each entry's data before it asks for the next entry, so the counts
  // are complete here.
  const description = {
    format: start.format,
    version: start.version,
    exported_at: start.exported_at,
    household: start.household,
    tables: files,
  };
  yield { name: "export.json", data: once(JSON.stringify(description, null, 2) + "\n") };
}

/** One table as a JSON array, one row per line, read page by page. */
async function* tableJson(
  table: string,
  fetchPage: FetchPage,
  counted: (rows: number) => void,
): AsyncGenerator<Uint8Array> {
  const encoder = new TextEncoder();
  let rows = 0;
  let after: unknown = null;
  yield encoder.encode("[");
  do {
    const page = await fetchPage(table, after);
    if (page.rows.length > 0) {
      const lines = page.rows.map((row) => JSON.stringify(row)).join(",\n");
      yield encoder.encode((rows === 0 ? "\n" : ",\n") + lines);
      rows += page.rows.length;
    }
    after = page.next ?? null;
  } while (after !== null);
  yield encoder.encode(rows === 0 ? "]\n" : "\n]\n");
  counted(rows);
}

async function* once(text: string): AsyncGenerator<Uint8Array> {
  yield new TextEncoder().encode(text);
}
