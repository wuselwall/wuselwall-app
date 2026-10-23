import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import {
  clocksOf,
  lessonOf,
  type OcrLine,
  parseTimetableScan,
  periodOf,
  weekdayOf,
  weekdaysIn,
} from "./timetable_ocr.ts";

/** A box around a centre, as an OCR service would draw it (normalised coordinates). */
function at(text: string, cx: number, cy: number, w = 0.06, h = 0.03): OcrLine {
  const x0 = cx - w / 2, x1 = cx + w / 2, y0 = cy - h / 2, y1 = cy + h / 2;
  return { text, box: [x0, y0, x1, y0, x1, y1, x0, y1], score: 0.9 };
}

const COLS = [0.3, 0.45, 0.6, 0.75, 0.9];
const DAYS = ["Mo", "Di", "Mi", "Do", "Fr"];

/** The sheet of the reference household: numbered rows, four periods, a few extras. */
function sheet(): OcrLine[] {
  const lines: OcrLine[] = [at("Stundenplan 3b", 0.5, 0.05, 0.3)];
  DAYS.forEach((d, i) => lines.push(at(d, COLS[i], 0.15)));
  const rows = [0.3, 0.42, 0.54, 0.66];
  rows.forEach((y, i) => lines.push(at(`${i + 1}.`, 0.1, y, 0.03)));
  const grid = [
    ["Ma", "D", "Ma", "SU", "Ma"],
    ["D", "Ma", "Sp", "D", "E"],
    ["Mu", "Ku", "Sp", "Ma", "D"],
    ["SU", "Rel", "Ma", "E", null],
  ];
  grid.forEach((row, r) =>
    row.forEach((cell, c) => {
      if (cell) lines.push(at(cell, COLS[c], rows[r]));
    })
  );
  // A room under Monday's first subject, and a teacher next to Friday's second.
  lines.push(at("R12", COLS[0], 0.3 + 0.025, 0.05, 0.02));
  lines.push(at("Fr. Kurz", COLS[4] + 0.03, 0.42, 0.05));
  // Noise far below the grid.
  lines.push(at("Schulleitung", 0.5, 0.95, 0.2));
  return lines;
}

Deno.test("words: weekdays, periods and clocks", () => {
  assertEquals(weekdayOf("Mo"), 1);
  assertEquals(weekdayOf("Mittwoch"), 3);
  assertEquals(weekdayOf("Do. 15.10."), 4);
  assertEquals(weekdayOf("mié"), 3);
  assertEquals(weekdayOf("Ma"), 2); // French "mardi" in a header; in a cell it is a subject
  assertEquals(weekdayOf("Mathe"), null);
  // What real sheets yield: letter-spaced print, a typo, a truncated column, Dutch.
  assertEquals(weekdayOf("M ittw och"), 3);
  assertEquals(weekdayOf("D ien s tag"), 2);
  assertEquals(weekdayOf("Mon tag"), 1);
  assertEquals(weekdayOf("Dinstag"), 2);
  assertEquals(weekdayOf("Dinsd"), 2);
  assertEquals(weekdayOf("Vrijda"), 5);
  assertEquals(weekdayOf("Montag (Langtag)"), 1);
  assertEquals(weekdayOf("Musik"), null);
  assertEquals(weekdayOf("Sport"), null);
  assertEquals(
    weekdaysIn("Maandag Dinsdag Woensdag Donderdag Vrijdag").map((w) => w.day),
    [1, 2, 3, 4, 5],
  );
  assertEquals(weekdaysIn("Mon tag").length, 1);
  assertEquals(periodOf("Stunde 3"), 3);
  assertEquals(periodOf("Std. 2"), 2);
  assertEquals(periodOf("1. Std"), 1);
  assertEquals(periodOf("1."), 1);
  assertEquals(periodOf("3. Stunde"), 3);
  assertEquals(periodOf("12"), 12);
  assertEquals(periodOf("R12"), null);
  assertEquals(clocksOf("08:00 - 08:45"), ["08:00", "08:45"]);
  assertEquals(clocksOf("8.50–9.35 Uhr"), ["08:50", "09:35"]);
});

Deno.test("a cell's text becomes subject, room and teacher", () => {
  assertEquals(lessonOf(1, 1, "Ma R12"), {
    day: 1,
    period: 1,
    subject: "Ma",
    room: "R12",
  });
  assertEquals(lessonOf(5, 2, "E Fr. Kurz"), {
    day: 5,
    period: 2,
    subject: "E",
    teacher: "Fr. Kurz",
  });
  assertEquals(lessonOf(1, 1, "—"), null);
  assertEquals(lessonOf(1, 1, "M rot (Hen)"), {
    day: 1,
    period: 1,
    subject: "M",
    teacher: "rot Hen",
  });
  assertEquals(lessonOf(1, 1, "Mrot(Hen)"), {
    day: 1,
    period: 1,
    subject: "Mrot",
    teacher: "Hen",
  });
  assertEquals(lessonOf(1, 1, "Sp. Halle 2"), {
    day: 1,
    period: 1,
    subject: "Sp",
    room: "2",
    teacher: "Halle",
  });
});

Deno.test("the reference sheet: columns from the header, rows from the labels", () => {
  const result = parseTimetableScan(sheet());
  assert(result);
  assertEquals(result.columns, 5);
  assertEquals(result.rows, 4);
  assertEquals(result.unplaced, 1, "the footer fits no row");
  assertEquals(result.payload.lessons.length, 19);
  const mo1 = result.payload.lessons.find((l) => l.day === 1 && l.period === 1);
  assertEquals(mo1, { day: 1, period: 1, subject: "Ma", room: "R12" });
  const fr2 = result.payload.lessons.find((l) => l.day === 5 && l.period === 2);
  assertEquals(fr2, { day: 5, period: 2, subject: "E", teacher: "Fr. Kurz" });
  assertEquals(
    result.payload.lessons.find((l) => l.day === 5 && l.period === 4),
    undefined,
  );
  assertEquals(result.payload.periods, undefined);
});

Deno.test("bell times on the labels become periods, and rows without numbers count up", () => {
  const lines: OcrLine[] = [];
  DAYS.forEach((d, i) => lines.push(at(d, COLS[i], 0.15)));
  const rows = [0.3, 0.42, 0.54];
  const times = ["08:00-08:45", "08:50-09:35", "09:55-10:40"];
  rows.forEach((y, i) => {
    lines.push(at(times[i], 0.1, y, 0.1));
    lines.push(at("Ma", COLS[0], y));
  });
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.payload.periods, [
    { index: 1, starts: "08:00", ends: "08:45" },
    { index: 2, starts: "08:50", ends: "09:35" },
    { index: 3, starts: "09:55", ends: "10:40" },
  ]);
  assertEquals(result.payload.lessons.map((l) => l.period), [1, 2, 3]);
});

Deno.test("without labels the cell texts form the rows", () => {
  const lines: OcrLine[] = [];
  DAYS.forEach((d, i) => lines.push(at(d, COLS[i], 0.15)));
  for (const y of [0.3, 0.42]) {
    lines.push(at("Ma", COLS[0], y));
    lines.push(at("D", COLS[2], y + 0.005));
  }
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.rows, 2);
  assertEquals(
    result.payload.lessons.map((l) => `${l.day}:${l.period}:${l.subject}`),
    [
      "1:1:Ma",
      "1:2:Ma",
      "3:1:D",
      "3:2:D",
    ],
  );
});

Deno.test("no weekday header, no timetable", () => {
  assertEquals(
    parseTimetableScan([
      at("Einkaufsliste", 0.5, 0.1),
      at("Milch", 0.5, 0.2),
      at("Brot", 0.5, 0.3),
      at("Eier", 0.5, 0.4),
    ]),
    null,
  );
  assertEquals(parseTimetableScan([]), null);
});

Deno.test("a header in English and a stray weekday elsewhere", () => {
  const lines: OcrLine[] = [];
  ["Mon", "Tue", "Wed", "Thu", "Fri"].forEach((d, i) =>
    lines.push(at(d, COLS[i], 0.15))
  );
  lines.push(at("1", 0.1, 0.3, 0.03));
  lines.push(at("Maths", COLS[0], 0.3));
  lines.push(at("Fri", 0.5, 0.8)); // a note "Fri: no school" below the grid
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.columns, 5);
  assertEquals(result.payload.lessons, [{
    day: 1,
    period: 1,
    subject: "Maths",
  }]);
});

Deno.test("a header the OCR returned as one box is split into columns", () => {
  const lines: OcrLine[] = [
    at("Maandag Dinsdag Woensdag Donderdag Vrijdag", 0.6, 0.15, 0.7),
  ];
  const cols = [0.32, 0.46, 0.6, 0.74, 0.88];
  lines.push(at("1", 0.1, 0.3, 0.03));
  cols.forEach((cx, i) =>
    lines.push(at(["ges", "anw", "wis", "ne", "ma"][i], cx, 0.3))
  );
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.columns, 5);
  assertEquals(result.unplaced, 0);
  assertEquals(
    result.payload.lessons.map((l) => `${l.day}:${l.subject}`),
    ["1:ges", "2:anw", "3:wis", "4:ne", "5:ma"],
  );
});

Deno.test("header-band text next to a weekday is no lesson; 'Stunde n' labels give rows", () => {
  const lines: OcrLine[] = [];
  DAYS.forEach((d, i) => lines.push(at(d, COLS[i], 0.15)));
  lines.push(at("(Langtag)", COLS[0] + 0.04, 0.15, 0.05));
  lines.push(at("Stunde 1", 0.1, 0.3, 0.08));
  lines.push(at("Stunde 2", 0.1, 0.42, 0.08));
  lines.push(at("Ma", COLS[0], 0.3));
  lines.push(at("D", COLS[0], 0.42));
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.rows, 2);
  assertEquals(result.payload.lessons, [
    { day: 1, period: 1, subject: "Ma" },
    { day: 1, period: 2, subject: "D" },
  ]);
});

Deno.test("weekdays the OCR garbled are inferred from an even header spacing", () => {
  const lines: OcrLine[] = [];
  // Mo, Do and Sa read; Di, Mi and Fr came back as noise.
  [
    ["Mo", 0.3],
    ["D:[S1", 0.42],
    ["M:ES]", 0.54],
    ["Do", 0.66],
    ["FrIS]", 0.78],
    ["Sa", 0.9],
  ].forEach(
    ([d, cx]) => lines.push(at(d as string, cx as number, 0.15)),
  );
  lines.push(at("1", 0.1, 0.3, 0.03));
  [0.3, 0.42, 0.54, 0.66, 0.78, 0.9].forEach((cx, i) =>
    lines.push(at(["E", "D", "Ge", "M", "Ch", "Rel"][i], cx, 0.3))
  );
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.columns, 6);
  assertEquals(result.payload.lessons.map((l) => `${l.day}:${l.subject}`), [
    "1:E",
    "2:D",
    "3:Ge",
    "4:M",
    "5:Ch",
    "6:Rel",
  ]);
});
