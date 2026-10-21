import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import type { EventRow } from "./occurrences.ts";
import type {
  ExceptionRow,
  LessonRow,
  PeriodRow,
  SubjectRow,
} from "./school.ts";
import {
  answerChoreDone,
  answerChorePick,
  answerDay,
  answerMeals,
  answerPoints,
  answerPresence,
  answerSchool,
  answerShopping,
  findMember,
  fold,
  memberInText,
  type MemberRow,
  messagesFor,
  parseDay,
  parseShoppingText,
  pickChore,
  pickLang,
  resolveDay,
  type ShortcutContext,
  subjectInText,
  type TaskRow,
  whenOf,
  windowFor,
} from "./shortcuts.ts";

// Fixtures use the api views' shapes and the reference household's names (examples only).
// "Today" is Thursday 2026-10-15 in Europe/Berlin (UTC+2): tomorrow is Friday the 16th.

const DE = messagesFor("de");
const EN = messagesFor("en");
const TODAY = "2026-10-15";

const members: MemberRow[] = [
  member("thomas", "Thomas", "guardian", "adult"),
  member("julia", "Julia", "guardian", "adult"),
  member("emma", "Emma", "member", "child"),
  member("paul", "Paul", "member", "child"),
];

function member(
  id: string,
  name: string,
  role: "guardian" | "member",
  kind: "adult" | "child",
): MemberRow {
  return {
    id,
    display_name: name,
    role,
    kind,
    default_presence_state: null,
    default_presence_label: null,
  };
}

function event(id: string, extra: Partial<EventRow>): EventRow {
  return {
    id,
    calendar_id: "cal",
    title: id,
    description: null,
    location: null,
    kind: "appointment",
    presence_state: null,
    status: "confirmed",
    importance: "normal",
    is_all_day: false,
    starts_at: null,
    ends_at: null,
    start_date: null,
    end_date: null,
    timezone: "Europe/Berlin",
    rrule: null,
    rdates: null,
    exdates: null,
    attendee_ids: [],
    ...extra,
  };
}

function task(
  id: string,
  title: string,
  assigned: string | null,
  points = 2,
): TaskRow {
  return {
    id,
    title,
    points,
    due_on: TODAY,
    opens_on: TODAY,
    closes_on: TODAY,
    assigned_profile_id: assigned,
    requires_verification: false,
  };
}

function ctx(extra: Partial<ShortcutContext> = {}): ShortcutContext {
  return {
    holder: {
      profile_id: "thomas",
      display_name: "Thomas",
      role: "guardian",
      kind: "adult",
    },
    household: {
      name: "Huser",
      timezone: "Europe/Berlin",
      locale: "de-DE",
      today: TODAY,
      region: null,
    },
    window: { from: TODAY, to: TODAY },
    members,
    points: 0,
    lists: [{ id: "l1", name: "Supermarkt", is_default: true }],
    equipment_hint: true,
    ...extra,
  };
}

// ── dictation ──────────────────────────────────────────────────────────────────

Deno.test("shopping: amounts with a unit become the quantity, bare numbers the count", () => {
  assertEquals(parseShoppingText("2 Liter Milch und Eier"), [
    { name: "Milch", quantity: "2 l" },
    { name: "Eier" },
  ]);
  assertEquals(parseShoppingText("3 Äpfel, Brot"), [
    { name: "Äpfel", count: 3 },
    { name: "Brot" },
  ]);
  assertEquals(parseShoppingText("zwei Gurken"), [{
    name: "Gurken",
    count: 2,
  }]);
  assertEquals(parseShoppingText("500g Mehl"), [{
    name: "Mehl",
    quantity: "500 g",
  }]);
  assertEquals(parseShoppingText("1,5 kg Kartoffeln"), [{
    name: "Kartoffeln",
    quantity: "1,5 kg",
  }]);
  assertEquals(parseShoppingText("eine Packung Reis"), [{
    name: "Reis",
    quantity: "1 Packung",
  }]);
});

Deno.test("shopping: fillers, punctuation and English", () => {
  assertEquals(parseShoppingText("Bitte noch Butter."), [{ name: "Butter" }]);
  assertEquals(parseShoppingText("a dozen eggs and milk"), [
    { name: "Eggs", quantity: "1 dozen" },
    { name: "Milk" },
  ]);
  assertEquals(parseShoppingText("2 cans of tomatoes"), [{
    name: "Tomatoes",
    quantity: "2 cans",
  }]);
  assertEquals(parseShoppingText("Milch & Brot + Käse"), [{ name: "Milch" }, {
    name: "Brot",
  }, {
    name: "Käse",
  }]);
});

Deno.test("shopping: a word that only looks like a number stays the name", () => {
  // "Ein" alone is not an item with a count; "Eis" is not a number word.
  assertEquals(parseShoppingText("Eis"), [{ name: "Eis" }]);
  assertEquals(parseShoppingText("7 Up"), [{ name: "Up", count: 7 }]);
  assertEquals(parseShoppingText(""), []);
  assertEquals(parseShoppingText(" , und "), []);
});

Deno.test("shopping: at most twenty items", () => {
  const many = Array.from({ length: 25 }, (_, i) => `Ding${i}`).join(", ");
  assertEquals(parseShoppingText(many).length, 20);
});

Deno.test("shopping: the answer names what was filed, and the list when not the default", () => {
  const result = {
    status: "applied" as const,
    list: "Supermarkt",
    locale: "de-DE",
    items: [
      { id: "1", name: "Milch", merged: false, count: 1 },
      { id: "2", name: "Äpfel", merged: true, count: 3 },
    ],
  };
  assertEquals(
    answerShopping(result, [], true, DE).text,
    "Milch und Äpfel (3×) sind auf der Liste.",
  );
  assertEquals(
    answerShopping(
      { ...result, list: "Baumarkt", items: [result.items[0]] },
      [],
      false,
      DE,
    ).text,
    "Milch ist auf der Liste „Baumarkt“.",
  );
  assertEquals(
    answerShopping(result, [], true, EN).text,
    "Milch and Äpfel (3×) are on the list.",
  );
  // A replay carries no items: the sentence is built from what was sent.
  assertEquals(
    answerShopping(
      { status: "duplicate", list: "Supermarkt", locale: "de-DE" },
      [{ name: "Brot" }],
      true,
      DE,
    )
      .text,
    "Brot ist auf der Liste.",
  );
});

Deno.test("shortcuts understand French and Spanish dictated shopping and days", () => {
  assertEquals(parseShoppingText("deux litres de lait et trois pommes"), [
    { name: "Lait", quantity: "2 l" },
    { name: "Pommes", count: 3 },
  ]);
  assertEquals(
    parseShoppingText("dos litros de leche y una docena de huevos"),
    [
      { name: "Leche", quantity: "2 l" },
      { name: "Huevos", quantity: "1 docena" },
    ],
  );
  for (const text of ["aujourd’hui", "aujourd'hui", "hoy"]) {
    assertEquals(parseDay(text), { kind: "offset", days: 0 });
  }
  for (const text of ["demain", "mañana"]) {
    assertEquals(parseDay(text), { kind: "offset", days: 1 });
  }
  for (
    const text of [
      "après-demain",
      "pasado mañana",
      "¿Tiene Mia pasado mañana deporte?",
    ]
  ) {
    assertEquals(parseDay(text), { kind: "offset", days: 2 });
  }
  const fr = [
    "lundi",
    "mardi",
    "mercredi",
    "jeudi",
    "vendredi",
    "samedi",
    "dimanche",
  ];
  const es = [
    "lunes",
    "martes",
    "miércoles",
    "jueves",
    "viernes",
    "sábado",
    "domingo",
  ];
  for (const weekdays of [fr, es]) {
    weekdays.forEach((day, i) =>
      assertEquals(parseDay(day), { kind: "weekday", weekday: i + 1 })
    );
  }
});

// ── days and names ───────────────────────────────────────────────────────────────

Deno.test("days: words, weekdays and dates, in either language", () => {
  assertEquals(parseDay("morgen"), { kind: "offset", days: 1 });
  assertEquals(parseDay("Hat Mia morgen Sport?"), { kind: "offset", days: 1 });
  assertEquals(parseDay("übermorgen"), { kind: "offset", days: 2 });
  assertEquals(parseDay("the day after tomorrow"), { kind: "offset", days: 2 });
  assertEquals(parseDay("Freitag"), { kind: "weekday", weekday: 5 });
  assertEquals(parseDay("on Monday"), { kind: "weekday", weekday: 1 });
  assertEquals(parseDay("2026-10-20"), { kind: "date", date: "2026-10-20" });
  assertEquals(parseDay("2026-02-30"), null);
  assertEquals(parseDay("Wann ist Julia wieder da?"), null);
});

Deno.test("days: a weekday is the next one, today included", () => {
  assertEquals(
    resolveDay({ kind: "weekday", weekday: 4 }, TODAY),
    "2026-10-15",
  );
  assertEquals(
    resolveDay({ kind: "weekday", weekday: 5 }, TODAY),
    "2026-10-16",
  );
  assertEquals(
    resolveDay({ kind: "weekday", weekday: 1 }, TODAY),
    "2026-10-19",
  );
  assertEquals(windowFor({ kind: "weekday", weekday: 1 }), {
    from: null,
    days: 7,
  });
  assertEquals(windowFor({ kind: "offset", days: 1 }), { from: null, days: 2 });
  assertEquals(windowFor({ kind: "date", date: "2026-11-01" }), {
    from: "2026-11-01",
    days: 1,
  });
});

Deno.test("days: today, tomorrow, and a date written out", () => {
  assertEquals(whenOf(TODAY, TODAY, DE), "heute");
  assertEquals(whenOf("2026-10-16", TODAY, DE), "morgen");
  assertEquals(whenOf("2026-10-19", TODAY, DE), "am Montag, 19. Oktober");
  assertEquals(whenOf("2026-10-19", TODAY, EN), "on Monday 19 October");
});

Deno.test("names: folded, by prefix when unique, or found in a question", () => {
  assertEquals(fold("Spülmaschine Größe"), "spuelmaschine groesse");
  assertEquals(findMember(members, "emma")?.id, "emma");
  assertEquals(findMember(members, "Ju")?.id, "julia");
  const withEmil = [...members, member("emil", "Emil", "member", "child")];
  assertEquals(findMember(withEmil, "Em"), null); // Emma and Emil
  assertEquals(findMember(members, "Oma"), null);
  assertEquals(memberInText(members, "Hat Paul morgen Sport?")?.id, "paul");
  assertEquals(memberInText(members, "Wann ist julia wieder da"), members[1]);
  assertEquals(memberInText(members, "Was gibt es heute?"), null);
});

Deno.test("language: the parameter, then Accept-Language, then the household", () => {
  assertEquals(pickLang("en", "de-CH", "de-DE"), "en");
  assertEquals(pickLang(undefined, "fr-FR, en-US;q=0.8", "de-DE"), "fr");
  assertEquals(pickLang(undefined, null, "en-GB"), "en");
  assertEquals(pickLang("xx", "it", null), "de");
});

Deno.test("language: four languages, regional tags, quality ordering and German fallback", () => {
  assertEquals(pickLang(" ES-mx ", "fr", "de-DE"), "es");
  assertEquals(pickLang(undefined, null, "fr-FR"), "fr");
  assertEquals(pickLang(undefined, null, "es-ES"), "es");
  assertEquals(
    pickLang(undefined, "de;q=0.2, fr-CA;q=0.9, en;q=0.7", "es"),
    "fr",
  );
  assertEquals(pickLang(undefined, "fr;q=0, es;q=0.5", "de"), "es");
  assertEquals(pickLang(undefined, "fr;q=0.7, es;q=0.7", "de"), "fr");
  assertEquals(
    pickLang(undefined, "fr;q=invalid, es;q=1.1, en;q=0.6", "de"),
    "en",
  );
  assertEquals(pickLang(undefined, "*;q=0.8, it;q=1", "es-ES"), "es");
  assertEquals(pickLang(undefined, null, "it-IT"), "de");
});

Deno.test("French and Spanish shortcut catalogs render answers, errors and dates", () => {
  const fr = messagesFor("fr");
  const es = messagesFor("es");
  assertEquals(fr.locale, "fr-FR");
  assertEquals(es.locale, "es-ES");
  assertEquals(answerPoints(ctx({ points: 1 }), fr).text, "Tu as 1 point.");
  assertEquals(answerPoints(ctx({ points: 2 }), es).text, "Tienes 2 puntos.");
  assertEquals(
    answerDay(ctx(), TODAY, fr).text,
    "Rien au calendrier aujourd’hui.",
  );
  assertEquals(
    answerDay(ctx(), TODAY, es).text,
    "No hay nada en el calendario hoy.",
  );
  assertEquals(
    answerMeals(ctx(), TODAY, fr).text,
    "Aucun repas prévu aujourd’hui pour le moment.",
  );
  assertEquals(
    answerMeals(ctx(), TODAY, es).text,
    "Todavía no hay ninguna comida prevista hoy.",
  );
  assertEquals(
    fr.memberUnknown("X"),
    "Personne dans la famille ne s’appelle « X ».",
  );
  assertEquals(es.memberUnknown("X"), "Nadie en la familia se llama «X».");
  assertEquals(fr.joinList(["A", "B", "C"]), "A, B et C");
  assertEquals(es.joinList(["A", "B", "C"]), "A, B y C");
  assertEquals(whenOf("2026-10-19", TODAY, fr), "le lundi 19 octobre");
  assertEquals(whenOf("2026-10-19", TODAY, es), "el lunes, 19 de octubre");
  assertEquals(
    fr.schoolDay("Mia", fr.tomorrow, "08:00", "13:00", ["Maths"]),
    "Mia a école demain de 08:00 à 13:00 : Maths.",
  );
  assertEquals(
    es.presenceAwayUntil("Mia", es.state.away, es.tomorrow, "18:00"),
    "Mia está fuera y vuelve mañana a las 18:00.",
  );
});

Deno.test("French and Spanish multi-day presence does not repeat date prepositions", () => {
  const fr = messagesFor("fr");
  const es = messagesFor("es");
  assertEquals(
    fr.presenceAwayDays(
      "Mia",
      fr.state.travel,
      "vendredi 16 octobre",
      "demain",
    ),
    "Mia est en déplacement jusqu’au vendredi 16 octobre et revient demain.",
  );
  assertEquals(
    es.presenceAwayDays(
      "Mia",
      es.state.travel,
      "viernes, 16 de octubre",
      "mañana",
    ),
    "Mia está de viaje hasta el viernes, 16 de octubre y vuelve mañana.",
  );
  assertEquals(
    fr.presenceAwayDays(
      "Mia",
      fr.state.travel,
      "vendredi 16 octobre",
      "le lundi 19 octobre",
    ),
    "Mia est en déplacement jusqu’au vendredi 16 octobre et revient le lundi 19 octobre.",
  );
  assertEquals(
    es.presenceAwayDays(
      "Mia",
      es.state.travel,
      "viernes, 16 de octubre",
      "el lunes, 19 de octubre",
    ),
    "Mia está de viaje hasta el viernes, 16 de octubre y vuelve el lunes, 19 de octubre.",
  );
});

// ── chores ───────────────────────────────────────────────────────────────────────

Deno.test("chores: a spoken title finds the task; a tie is not guessed", () => {
  const c = ctx({
    tasks: [
      task("t1", "Spülmaschine ausräumen", "thomas"),
      task("t2", "Zimmer aufräumen", "thomas"),
      task("t3", "Zimmer saugen", "thomas"),
      task("t4", "Müll rausbringen", null),
      task("t5", "Pauls Aufgabe", "paul"),
    ],
  });
  const pick = pickChore(c, "Spülmaschine ist erledigt");
  assert(pick.kind === "task" && pick.task.id === "t1");
  const whole = pickChore(c, "Zimmer aufräumen");
  assert(whole.kind === "task" && whole.task.id === "t2");
  assertEquals(pickChore(c, "Zimmer").kind, "ambiguous");
  assertEquals(
    answerChorePick(pickChore(c, "Zimmer"), "Zimmer", DE).text,
    "„Zimmer“ passt zu mehreren Aufgaben: Zimmer aufräumen oder Zimmer saugen. Bitte genauer sagen, welche.",
  );
  // A guardian does not claim the unassigned one; someone else's is never offered.
  assertEquals(pickChore(c, "Müll").kind, "no_match");
  assertEquals(
    answerChorePick(pickChore(c, ""), "", DE).text,
    "Noch offen: Spülmaschine ausräumen, Zimmer aufräumen und Zimmer saugen.",
  );
});

Deno.test("chores: a member may claim an unassigned task; none open is said so", () => {
  const c = ctx({
    holder: {
      profile_id: "paul",
      display_name: "Paul",
      role: "member",
      kind: "child",
    },
    tasks: [task("t4", "Müll rausbringen", null)],
  });
  const pick = pickChore(c, "Müll");
  assert(pick.kind === "task" && pick.task.id === "t4");
  assertEquals(
    answerChorePick(pickChore(ctx({ tasks: [] }), "x"), "x", DE).text,
    "Heute ist keine Aufgabe mehr offen.",
  );
});

Deno.test("chores: done, credited or waiting for a guardian", () => {
  const done = {
    status: "done" as const,
    title: "Müll rausbringen",
    points: 2,
    requires_verification: false,
  };
  assertEquals(
    answerChoreDone({ ...done, points_credited: 2 }, DE).text,
    "Erledigt: Müll rausbringen. 2 Punkte dazu.",
  );
  assertEquals(
    answerChoreDone({
      ...done,
      points_credited: 0,
      requires_verification: true,
    }, DE).text,
    "Erledigt: Müll rausbringen. Die Punkte gibt es, sobald es bestätigt ist.",
  );
  assertEquals(
    answerChoreDone({ ...done, points_credited: 1 }, EN).text,
    "Done: Müll rausbringen. 1 point added.",
  );
});

Deno.test("points: singular and plural", () => {
  assertEquals(answerPoints(ctx({ points: 1 }), DE).text, "Du hast 1 Punkt.");
  assertEquals(
    answerPoints(ctx({ points: 42 }), EN).text,
    "You have 42 points.",
  );
});

// ── the day ──────────────────────────────────────────────────────────────────────

Deno.test("today: appointments with their people, the meals and my tasks; presence is left out", () => {
  const c = ctx({
    events: [
      event("Zahnarzt", {
        starts_at: "2026-10-15T06:30:00Z",
        ends_at: "2026-10-15T07:30:00Z",
        attendee_ids: ["emma"],
      }),
      event("Elternabend", {
        is_all_day: true,
        start_date: TODAY,
        end_date: TODAY,
      }),
      event("Schicht", {
        kind: "presence",
        presence_state: "working",
        starts_at: "2026-10-15T04:00:00Z",
        ends_at: "2026-10-15T12:00:00Z",
        attendee_ids: ["julia"],
      }),
      event("Morgen", {
        starts_at: "2026-10-16T06:30:00Z",
        ends_at: "2026-10-16T07:30:00Z",
      }),
    ],
    overrides: [],
    external: [],
    meals: [{
      on_date: TODAY,
      slot: "dinner",
      title: "Spaghetti",
      cook_profile_id: "julia",
      at_time: null,
    }],
    tasks: [
      task("t1", "Spülmaschine ausräumen", "thomas"),
      task("t4", "Müll rausbringen", null),
    ],
  });
  assertEquals(
    answerDay(c, TODAY, DE).text,
    "Heute: Elternabend (ganztägig) und 08:30 Zahnarzt (Emma). Essen heute: Abendessen: Spaghetti. " +
      "Deine Aufgaben: Spülmaschine ausräumen.",
  );
  assertEquals(
    answerDay(ctx({ events: [], meals: [], tasks: [] }), TODAY, EN).text,
    "Nothing on the calendar today.",
  );
  assertEquals(
    answerMeals(c, TODAY, DE).text,
    "Essen heute: Abendessen: Spaghetti. Julia kocht.",
  );
  assertEquals(
    answerMeals(ctx({ meals: [] }), "2026-10-16", DE).text,
    "Morgen ist noch kein Essen geplant.",
  );
});

// ── school ───────────────────────────────────────────────────────────────────────

function period(index: number, starts: string, ends: string): PeriodRow {
  return {
    id: `p${index}`,
    school_id: "s1",
    index,
    label: null,
    starts_at: `${starts}:00`,
    ends_at: `${ends}:00`,
    kind: "lesson",
  };
}

function subject(
  id: string,
  name: string,
  short: string,
  equipment: string | null = null,
): SubjectRow {
  return {
    id,
    name,
    short_name: short,
    tint: "blue",
    icon_key: null,
    equipment_note: equipment,
    notable_default: false,
  };
}

function lesson(
  id: string,
  weekday: number,
  periodIndex: number,
  subjectId: string,
): LessonRow {
  return {
    id,
    timetable_id: "tt",
    weekday,
    period_index: periodIndex,
    starts_at: null,
    ends_at: null,
    subject_id: subjectId,
    kind: "lesson",
    title: null,
    teacher: null,
    room: null,
    week_parity: "all",
    is_notable: false,
    note: null,
  };
}

const SUBJECTS = [
  subject("d", "Deutsch", "D"),
  subject("m", "Mathematik", "Ma"),
  subject("sp", "Sport", "Sp", "Sportsachen"),
];

function schoolCtx(exceptions: ExceptionRow[] = []) {
  return ctx({
    window: { from: TODAY, to: "2026-10-17" },
    school: {
      schools: [{
        id: "s1",
        name: "Schule",
        state_code: null,
        region_code: null,
        timezone: "Europe/Berlin",
        created_at: "2026-08-01T00:00:00Z",
      }],
      periods: [
        period(1, "08:00", "08:45"),
        period(2, "08:50", "09:35"),
        period(3, "09:55", "10:40"),
      ],
      terms: [{
        id: "term",
        school_id: "s1",
        name: "HS",
        starts_on: "2026-08-17",
        ends_on: "2027-01-31",
        ab_anchor_week: null,
        is_current: true,
      }],
      subjects: SUBJECTS,
      timetables: [{
        id: "tt",
        profile_id: "emma",
        school_id: "s1",
        term_id: "term",
        class_label: "3a",
        week_cycle: "weekly",
        valid_from: "2026-08-17",
        valid_to: null,
        source: "manual",
        source_ref: null,
        updated_at: "2026-08-01T00:00:00Z",
      }],
      lessons: [
        lesson("l1", 5, 1, "d"),
        lesson("l2", 5, 2, "m"),
        lesson("l3", 5, 3, "sp"),
      ],
      exceptions,
      holidays: [],
      public_feed: [],
    },
  });
}

Deno.test("school: has Emma Sport tomorrow, and the day with what to pack", () => {
  const c = schoolCtx();
  const emma = members[2];
  const sport = subjectInText(SUBJECTS, "Hat Emma morgen Sport?");
  assertEquals(sport?.id, "sp");
  assertEquals(
    answerSchool(c, emma, "2026-10-16", sport, DE).text,
    "Ja, Emma hat morgen Sport in der 3. Stunde (09:55–10:40).",
  );
  assertEquals(
    answerSchool(
      c,
      emma,
      "2026-10-16",
      { name: "Latein", short_name: null },
      DE,
    ).text,
    "Nein, Emma hat morgen kein Latein.",
  );
  assertEquals(
    answerSchool(c, emma, "2026-10-16", null, DE).text,
    "Emma hat morgen von 08:00 bis 10:40 Schule: Deutsch, Mathematik und Sport. Einpacken: Sportsachen.",
  );
  assertEquals(
    answerSchool(c, emma, "2026-10-16", sport, EN).text,
    "Yes, Emma has Sport tomorrow, period 3 (09:55–10:40).",
  );
});

Deno.test("school: a cancelled lesson, the weekend, and no timetable", () => {
  const c = schoolCtx([{
    id: "x1",
    timetable_id: "tt",
    on_date: "2026-10-16",
    period_index: 3,
    kind: "cancelled",
    subject_id: null,
    teacher: null,
    room: null,
    starts_at: null,
    ends_at: null,
    note: null,
    created_by_profile_id: "thomas",
  }]);
  const sport = SUBJECTS[2];
  assertEquals(
    answerSchool(c, members[2], "2026-10-16", sport, DE).text,
    "Sport fällt morgen für Emma aus.",
  );
  assertEquals(
    answerSchool(c, members[2], "2026-10-16", null, DE).text,
    "Emma hat morgen von 08:00 bis 09:35 Schule: Deutsch und Mathematik.",
  );
  assertEquals(
    answerSchool(c, members[2], "2026-10-17", null, DE).text,
    "Emma hat übermorgen keine Schule, es ist Wochenende.",
  );
  assertEquals(
    answerSchool(c, members[3], "2026-10-16", null, DE).text,
    "Für Paul ist kein Stundenplan eingetragen.",
  );
});

Deno.test("school: the equipment line follows the household setting", () => {
  const c = { ...schoolCtx(), equipment_hint: false };
  assertEquals(
    answerSchool(c, members[2], "2026-10-16", null, DE).text,
    "Emma hat morgen von 08:00 bis 10:40 Schule: Deutsch, Mathematik und Sport.",
  );
});

// ── presence ─────────────────────────────────────────────────────────────────────

const NOW = new Date("2026-10-15T08:00:00Z"); // 10:00 in Berlin

Deno.test("presence: away for days, back the day after the last one", () => {
  const c = ctx({
    window: { from: TODAY, to: "2026-11-13" },
    events: [
      event("Reise", {
        kind: "presence",
        presence_state: "travel",
        is_all_day: true,
        start_date: "2026-10-14",
        end_date: "2026-10-16",
        attendee_ids: ["julia"],
      }),
      // Straight on into a weekend away: one absence.
      event("Weg", {
        kind: "presence",
        presence_state: "away",
        is_all_day: true,
        start_date: "2026-10-17",
        end_date: "2026-10-17",
        attendee_ids: ["julia"],
      }),
    ],
    overrides: [],
    external: [],
  });
  assertEquals(
    answerPresence(c, members[1], NOW, DE).text,
    "Julia ist auf Reise bis Samstag, 17. Oktober und am Sonntag, 18. Oktober wieder da.",
  );
  assertEquals(
    answerPresence(c, members[1], NOW, EN).text,
    "Julia is travelling until Saturday 17 October and back on Sunday 18 October.",
  );
});

Deno.test("presence: at work until a time; otherwise here, with the next trip", () => {
  const c = ctx({
    window: { from: TODAY, to: "2026-11-13" },
    events: [
      event("Schicht", {
        kind: "presence",
        presence_state: "working",
        starts_at: "2026-10-15T04:00:00Z",
        ends_at: "2026-10-15T12:00:00Z",
        attendee_ids: ["julia"],
      }),
      event("Reise", {
        kind: "presence",
        presence_state: "travel",
        is_all_day: true,
        start_date: "2026-10-21",
        end_date: "2026-10-23",
        attendee_ids: ["thomas"],
      }),
    ],
    overrides: [],
    external: [],
  });
  assertEquals(
    answerPresence(c, members[1], NOW, DE).text,
    "Julia ist bei der Arbeit und heute um 14:00 wieder da.",
  );
  assertEquals(
    answerPresence(c, members[0], NOW, DE).text,
    "Thomas ist laut Kalender da. Als Nächstes: auf Reise von Mittwoch, 21. Oktober bis Freitag, 23. Oktober.",
  );
  assertEquals(
    answerPresence(c, members[2], NOW, EN).text,
    "Emma is here, according to the calendar.",
  );
});

Deno.test("presence: an all-day shift is today, not until the next free day", () => {
  const shifts = ["2026-10-15", "2026-10-16"].map((d) =>
    event(`Dienst ${d}`, {
      kind: "presence",
      presence_state: "working",
      is_all_day: true,
      start_date: d,
      end_date: d,
      attendee_ids: ["julia"],
    })
  );
  const c = ctx({
    window: { from: TODAY, to: "2026-11-13" },
    events: shifts,
    overrides: [],
    external: [],
  });
  assertEquals(
    answerPresence(c, members[1], NOW, DE).text,
    "Julia ist heute bei der Arbeit.",
  );
  assertEquals(
    answerPresence(c, members[1], NOW, EN).text,
    "Julia is at work today.",
  );
});
