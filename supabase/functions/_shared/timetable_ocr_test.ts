import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import {
  clocksOf,
  labelClocks,
  lessonOf,
  type OcrLine,
  parseTimetableScan,
  periodOf,
  vocabOf,
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
  // Subject codes that look like a French two-letter weekday are subjects.
  assertEquals(weekdayOf("Ma"), null);
  assertEquals(weekdayOf("Me"), null);
  assertEquals(weekdayOf("mar."), 2);
  // A child's hand, read by the OCR with two letters wrong.
  assertEquals(weekdayOf("Pornerstag"), 4);
  assertEquals(weekdayOf("Pierstag"), 2);
  assertEquals(weekdayOf("Freizeit"), null);
  // Sachunterricht and Werken are subjects, not Sunday and Wednesday.
  assertEquals(weekdayOf("SU"), null);
  assertEquals(weekdayOf("We"), null);
  assertEquals(weekdayOf("Wed"), 3);
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
  assertEquals(periodOf("1. Semester GES tc"), null);
  assertEquals(periodOf("1. Klasse"), null);
  assertEquals(periodOf("Lektion 2"), 2);
  assertEquals(clocksOf("08:00 - 08:45"), ["08:00", "08:45"]);
  assertEquals(clocksOf("8.50–9.35 Uhr"), ["08:50", "09:35"]);
  assertEquals(clocksOf("8 00 - 8 45"), ["08:00", "08:45"]);
  assertEquals(clocksOf("Raum 124"), []);
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
  lines.push(at("2", 0.1, 0.42, 0.03));
  lines.push(at("English", COLS[0], 0.42));
  lines.push(at("Fri", 0.5, 0.8)); // a note "Fri: no school" below the grid
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.columns, 5);
  assertEquals(result.payload.lessons, [
    { day: 1, period: 1, subject: "Maths" },
    { day: 1, period: 2, subject: "English" },
  ]);
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
  lines.push(at("2", 0.1, 0.42, 0.03));
  lines.push(at("nl", cols[0], 0.42));
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.columns, 5);
  assertEquals(result.unplaced, 0);
  assertEquals(
    result.payload.lessons.map((l) => `${l.day}:${l.subject}`),
    ["1:ges", "1:nl", "2:anw", "3:wis", "4:ne", "5:ma"],
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
  lines.push(at("2", 0.1, 0.42, 0.03));
  lines.push(at("F", 0.3, 0.42));
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.columns, 6);
  assertEquals(result.payload.lessons.map((l) => `${l.day}:${l.subject}`), [
    "1:E",
    "1:F",
    "2:D",
    "3:Ge",
    "4:M",
    "5:Ch",
    "6:Rel",
  ]);
});

Deno.test("left-aligned sheets keep a cell's right-hand teacher code in its own column", () => {
  // Headers and subjects start at the cell's left edge; the teacher code sits at its right,
  // closer to the next header's centre than to its own.
  const lefts = [0.2, 0.36, 0.52, 0.68, 0.84];
  const lines: OcrLine[] = [];
  DAYS.forEach((d, i) => lines.push(at(d, lefts[i] + 0.02, 0.15, 0.04)));
  lines.push(at("1", 0.1, 0.3, 0.03));
  lefts.forEach((x, i) => {
    lines.push(at(["MAT", "DEU", "ENG", "FRA", "NMG"][i], x + 0.04, 0.3, 0.06));
    lines.push(
      at(["kob", "mhe", "skn", "mhe", "ata"][i], x + 0.125, 0.3, 0.04),
    );
  });
  lines.push(at("2", 0.1, 0.42, 0.03));
  lines.push(at("RZG", lefts[0] + 0.04, 0.42, 0.06));
  lines.push(at("skn", lefts[0] + 0.125, 0.42, 0.04));
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.unplaced, 0);
  assertEquals(
    result.payload.lessons.map((l) => `${l.day}:${l.subject}/${l.teacher}`),
    [
      "1:MAT/kob",
      "1:RZG/skn",
      "2:DEU/mhe",
      "3:ENG/skn",
      "4:FRA/mhe",
      "5:NMG/ata",
    ],
  );
});

Deno.test("days down the left and periods across the top: the grid is read turned", () => {
  // A school diary page: MON. to FRI. in a column, 1 to 4 along the top.
  const lines: OcrLine[] = [];
  const periods = [0.3, 0.45, 0.6, 0.75];
  periods.forEach((x, i) => lines.push(at(String(i + 1), x, 0.1, 0.03)));
  const days = ["MON.", "TUES.", "WED.", "THUR.", "FRI."];
  const rows = [0.25, 0.4, 0.55, 0.7, 0.85];
  days.forEach((d, i) => lines.push(at(d, 0.1, rows[i], 0.08)));
  const grid = [
    ["Maths", "Eng", "Phys", "Art"],
    ["Eng", "Maths", "Bio", ""],
    ["Phys", "Chem", "Maths", "PE"],
    ["Hist", "Eng", "", "Maths"],
    ["Maths", "Geo", "Eng", "Music"],
  ];
  grid.forEach((row, r) =>
    row.forEach((cell, c) => cell && lines.push(at(cell, periods[c], rows[r])))
  );
  const result = parseTimetableScan(lines);
  assert(result);
  assert(result.transposed);
  assertEquals(result.columns, 5);
  assertEquals(result.rows, 4);
  assertEquals(result.unplaced, 0);
  assertEquals(
    result.payload.lessons.find((l) => l.day === 2 && l.period === 3),
    {
      day: 2,
      period: 3,
      subject: "Bio",
    },
  );
  assertEquals(
    result.payload.lessons.filter((l) => l.day === 5).map((l) => l.subject),
    ["Maths", "Geo", "Eng", "Music"],
  );
});

Deno.test("a weekday list with one row of text is a rota or a menu, not a timetable", () => {
  // Seven weekday names down the left, one pharmacy name next to each.
  const lines: OcrLine[] = [];
  [
    "Montag",
    "Dienstag",
    "Mittwoch",
    "Donnerstag",
    "Freitag",
    "Samstag",
    "Sonntag",
  ].forEach((d, i) => {
    lines.push(at(d, 0.2, 0.2 + i * 0.1, 0.12));
    lines.push(at(`Apotheke ${i + 1}`, 0.6, 0.2 + i * 0.1, 0.2));
  });
  assertEquals(parseTimetableScan(lines), null);
});

Deno.test("rows a hair below the header stay rows, and Ma is Mathe", () => {
  // Large print: the row pitch is barely above the text height, and every cell says Ma.
  const lines: OcrLine[] = [];
  DAYS.forEach((d, i) => lines.push(at(d, COLS[i], 0.15, 0.08, 0.05)));
  const rows = [0.21, 0.27, 0.33];
  rows.forEach((y, i) => {
    lines.push(at(`${i + 1}.`, 0.1, y, 0.04, 0.05));
    COLS.forEach((cx) => lines.push(at("Ma", cx, y, 0.06, 0.05)));
  });
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.transposed, false);
  assertEquals(result.columns, 5);
  assertEquals(result.rows, 3);
  assertEquals(result.unplaced, 0);
  assertEquals(result.payload.lessons.length, 15);
});

Deno.test("a photo taken sideways the other way round: days run upwards", () => {
  // Freitag at the top, Montag at the bottom, each day's lessons to its right.
  const lines: OcrLine[] = [];
  const ys = [0.2, 0.35, 0.5, 0.65, 0.8];
  ["Freitag", "Donnerstag", "Mittwoch", "Dienstag", "Montag"].forEach((d, i) =>
    lines.push(at(d, 0.15, ys[i], 0.1))
  );
  const periods = [0.35, 0.5, 0.65, 0.8];
  periods.forEach((x, i) => lines.push(at(String(i + 1), x, 0.1, 0.03)));
  ys.forEach((y, r) =>
    periods.forEach((x, c) =>
      lines.push(at(["D", "Ma", "E", "Sp"][(r + c) % 4], x, y))
    )
  );
  const result = parseTimetableScan(lines);
  assert(result);
  assert(result.transposed);
  assertEquals(result.columns, 5);
  assertEquals(result.rows, 4);
  assertEquals(result.unplaced, 0);
  // Montag is the bottom row; its first lesson is D at the first period.
  assertEquals(
    result.payload.lessons.find((l) => l.day === 1 && l.period === 1)?.subject,
    "D",
  );
  assertEquals(
    result.payload.lessons.find((l) => l.day === 5 && l.period === 1)?.subject,
    "D",
  );
  assertEquals(
    result.payload.lessons.find((l) => l.day === 5 && l.period === 2)?.subject,
    "Ma",
  );
});

/** [lines] rotated by [degrees] about the picture's centre, quads and all, as a tilted
 *  photo would present them. */
function rotated(lines: OcrLine[], degrees: number): OcrLine[] {
  const a = (degrees * Math.PI) / 180;
  const c = Math.cos(a), s = Math.sin(a);
  return lines.map((l) => {
    const box: number[] = [];
    for (let i = 0; i < 8; i += 2) {
      const x = l.box[i] - 0.5, y = l.box[i + 1] - 0.5;
      box.push(x * c - y * s + 0.5, x * s + y * c + 0.5);
    }
    return { ...l, box };
  });
}

Deno.test("a tilted photo is read level: the reference sheet at 12 degrees, and at 90", () => {
  const level = parseTimetableScan(sheet())!;
  for (const degrees of [12, -8, 90]) {
    const result = parseTimetableScan(rotated(sheet(), degrees));
    assert(result, `${degrees} degrees`);
    assertEquals(result.columns, 5, `${degrees} degrees`);
    assertEquals(result.rows, 4, `${degrees} degrees`);
    assertEquals(
      result.payload.lessons,
      level.payload.lessons,
      `${degrees} degrees`,
    );
  }
});

Deno.test("row numbers and bare clock labels in two columns give one row per period", () => {
  const lines: OcrLine[] = [];
  DAYS.forEach((d, i) => lines.push(at(d, COLS[i], 0.15)));
  const rows = [0.3, 0.42, 0.54];
  const clocks = [["800", "845"], ["850", "935"], ["955", "1040"]];
  rows.forEach((y, i) => {
    lines.push(at(`${i + 1}.`, 0.06, y, 0.03));
    lines.push(at(clocks[i][0], 0.13, y - 0.02, 0.04));
    lines.push(at(clocks[i][1], 0.13, y + 0.02, 0.04));
    lines.push(at("Ma", COLS[0], y));
  });
  const result = parseTimetableScan(lines);
  assert(result);
  assertEquals(result.rows, 3);
  assertEquals(result.unplaced, 0);
  assertEquals(result.payload.periods, [
    { index: 1, starts: "08:00", ends: "08:45" },
    { index: 2, starts: "08:50", ends: "09:35" },
    { index: 3, starts: "09:55", ends: "10:40" },
  ]);
  assertEquals(labelClocks("1040"), ["10:40"]);
  assertEquals(labelClocks("2500"), []);
  assertEquals(labelClocks("08:00 - 08:45"), ["08:00", "08:45"]);
});

Deno.test("the family's language and subjects steer the words", () => {
  const de = vocabOf({
    languages: ["de-CH"],
    subjects: ["Mar", "Ven", "SU", "Fr"],
  });
  // German short forms only: the French "mar." is no Tuesday here, "Fr" stays Freitag.
  assertEquals(weekdayOf("mar.", de), null);
  assertEquals(weekdayOf("Fr", de), 5);
  assertEquals(weekdayOf("Mo", de), 1);
  // Full names of every language still match by prefix: a French sheet in a German family.
  assertEquals(weekdayOf("lun.", de), 1);
  assertEquals(weekdayOf("mercredi", de), 3);
  // A subject of the family is never a weekday by guess ("Ven" is close to vendredi).
  assertEquals(weekdayOf("Ven", de), null);
  assertEquals(weekdayOf("Ven", vocabOf({ languages: ["fr"] })), 5);
  // Unknown languages fall back to every short form.
  assertEquals(weekdayOf("mar", vocabOf({ languages: ["xx"] })), 2);
  // The reference sheet reads the same with hints.
  const plain = parseTimetableScan(sheet())!;
  const hinted = parseTimetableScan(sheet(), {
    languages: ["de"],
    subjects: ["Ma", "D", "Sp", "SU", "E"],
  })!;
  assertEquals(hinted.payload.lessons, plain.payload.lessons);
});
