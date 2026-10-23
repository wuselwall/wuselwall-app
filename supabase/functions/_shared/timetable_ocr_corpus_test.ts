// The public sheets of the corpus (Wikimedia Commons: German, Dutch, English, French and
// Spanish timetables), as the OCR service read them, with the grid the parser finds in each.
// A tuning that changes a sheet's grid fails here, so no sheet is lost in silence. The
// expectations are the parser's reading at the time they were written: when a change reads a
// sheet better, update them deliberately (specs/24 "Recognition roadmap", step 7).
import { assertEquals } from "jsr:@std/assert@1.0.13";
import { type OcrLine, parseTimetableScan } from "./timetable_ocr.ts";

type Expected = {
  language: string;
  columns: number;
  rows: number;
  lessons: number;
  named: number;
  periods: number;
  care: number;
} | null;

const dir = new URL("./fixtures/timetables/", import.meta.url);
const expected: Record<string, Expected> = JSON.parse(
  await Deno.readTextFile(new URL("expected.json", dir)),
);

for (const [file, want] of Object.entries(expected)) {
  Deno.test(`corpus: ${file}`, async () => {
    const lines: OcrLine[] = JSON.parse(
      await Deno.readTextFile(new URL(file, dir)),
    );
    const read = parseTimetableScan(lines, {
      languages: [want?.language ?? "de"],
    });
    if (want === null) {
      assertEquals(read, null);
      return;
    }
    assertEquals(read !== null, true, "a grid is found");
    assertEquals(
      {
        language: want.language,
        columns: read!.columns,
        rows: read!.rows,
        lessons: read!.payload.lessons.length,
        named: read!.payload.lessons.filter((l) => l.name).length,
        periods: read!.payload.periods?.length ?? 0,
        care: read!.payload.care?.length ?? 0,
      },
      want,
    );
  });
}
