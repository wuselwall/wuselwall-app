import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { addDays, type EventRow } from "./occurrences.ts";
import { familyServer, type McpContext, TOOLS } from "./mcp_family.ts";
import type { LessonRow, PeriodRow, SubjectRow } from "./school.ts";
import type { MemberRow } from "./shortcuts.ts";

// Fixtures use the api views' shapes and the reference household's names (examples only).
// "Today" is Thursday 2026-10-15 in Europe/Berlin; the week runs Monday 12 to Sunday 18.
const TODAY = "2026-10-15";

function member(
  id: string,
  name: string,
  kind: "adult" | "child",
  baseline: string | null = null,
): MemberRow {
  return {
    id,
    display_name: name,
    role: kind === "adult" ? "guardian" : "member",
    kind,
    default_presence_state: baseline,
    default_presence_label: null,
  };
}

const MEMBERS = [
  member("lukas", "Lukas", "adult", "home_office"),
  member("sabine", "Sabine", "adult"),
  member("lotta", "Lotta", "child"),
];

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

const period = (i: number, s: string, e: string): PeriodRow => ({
  id: `p${i}`,
  school_id: "s1",
  index: i,
  label: null,
  starts_at: `${s}:00`,
  ends_at: `${e}:00`,
  kind: "lesson",
});
const subject = (id: string, name: string, equipment: string | null = null): SubjectRow => ({
  id,
  name,
  short_name: name.slice(0, 2),
  tint: "blue",
  icon_key: null,
  equipment_note: equipment,
  notable_default: false,
});
const lesson = (id: string, weekday: number, index: number, subjectId: string): LessonRow => ({
  id,
  timetable_id: "tt",
  weekday,
  period_index: index,
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
});

/** Everything of the household, whatever is asked; the window as the database computes it. */
function rows(from: string, days: number): McpContext {
  return {
    holder: { profile_id: "lukas", display_name: "Lukas", role: "guardian", kind: "adult" },
    household: { name: "Huser", timezone: "Europe/Berlin", locale: "de-DE", today: TODAY, region: null },
    window: { from, to: addDays(from, days - 1) },
    members: MEMBERS,
    points: 12,
    lists: [
      { id: "l1", name: "Supermarkt", is_default: true },
      { id: "l2", name: "Baumarkt", is_default: false },
    ],
    equipment_hint: true,
    events: [
      event("Zahnarzt", {
        starts_at: "2026-10-15T06:30:00Z",
        ends_at: "2026-10-15T07:30:00Z",
        attendee_ids: ["lotta"],
      }),
      event("Elternabend", { is_all_day: true, start_date: "2026-10-16", end_date: "2026-10-16" }),
      event("Reise", {
        kind: "presence",
        presence_state: "travel",
        is_all_day: true,
        start_date: "2026-10-15",
        end_date: "2026-10-16",
        attendee_ids: ["sabine"],
      }),
    ],
    overrides: [],
    external: [],
    meals: [
      { on_date: TODAY, slot: "dinner", title: "Spaghetti", cook_profile_id: "sabine", at_time: null },
    ],
    tasks_all: [
      {
        id: "t1",
        title: "Spülmaschine ausräumen",
        points: 3,
        due_on: TODAY,
        opens_on: TODAY,
        closes_on: TODAY,
        assigned_profile_id: "lotta",
        requires_verification: false,
        status: "open",
        completed_by_profile_id: null,
        completed_at: null,
      },
      {
        id: "t2",
        title: "Müll rausbringen",
        points: 2,
        due_on: TODAY,
        opens_on: TODAY,
        closes_on: TODAY,
        assigned_profile_id: "lukas",
        requires_verification: false,
        status: "done",
        completed_by_profile_id: "lukas",
        completed_at: "2026-10-15T07:00:00Z",
      },
    ],
    shopping_items: [
      {
        id: "i1",
        name: "Milch",
        quantity: "2 l",
        count: 1,
        list_id: "l1",
        category_id: "c-dairy",
        added_by: "sabine",
      },
      {
        id: "i2",
        name: "Äpfel",
        quantity: null,
        count: 3,
        list_id: "l1",
        category_id: "c-produce",
        added_by: null,
      },
      {
        id: "i3",
        name: "Schrauben",
        quantity: null,
        count: 1,
        list_id: "l2",
        category_id: null,
        added_by: null,
      },
    ],
    shopping_categories: [
      { id: "c-produce", list_id: "l1", key: "produce", name: null, sort_order: 0 },
      { id: "c-dairy", list_id: "l1", key: "dairy", name: null, sort_order: 20 },
    ],
    balances: [{ profile_id: "lotta", balance: 42 }, { profile_id: "lukas", balance: 0 }],
    ledger: [{
      profile_id: "lotta",
      occurred_at: "2026-10-14T16:00:00Z",
      amount: 3,
      reason: "task",
      note: null,
    }],
    streaks: [{ profile_id: "lotta", title: "Spülmaschine ausräumen", current_length: 4, longest_length: 9 }],
    recipes: [
      { id: "r1", title: "Spaghetti Bolognese", description: null, servings_default: 4, tags: ["Pasta"] },
      { id: "r2", title: "Zucchini-Lasagne", description: null, servings_default: 4, tags: null },
    ],
    ingredients: [
      { recipe_id: "r1", position: 1, raw_name: "Hackfleisch", quantity: 500, unit: "g", note: null },
      { recipe_id: "r2", position: 1, raw_name: "Zucchini", quantity: 2, unit: null, note: null },
    ],
    school: {
      schools: [{
        id: "s1",
        name: "Schule",
        state_code: null,
        region_code: null,
        timezone: "Europe/Berlin",
        created_at: "2026-08-01T00:00:00Z",
      }],
      periods: [period(1, "08:00", "08:45"), period(2, "08:50", "09:35")],
      terms: [{
        id: "term",
        school_id: "s1",
        name: "HS",
        starts_on: "2026-08-17",
        ends_on: "2027-01-31",
        ab_anchor_week: null,
        is_current: true,
      }],
      subjects: [subject("d", "Deutsch"), subject("sp", "Sport", "Sportsachen")],
      timetables: [{
        id: "tt",
        profile_id: "lotta",
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
      lessons: [lesson("l1", 4, 1, "d"), lesson("l2", 4, 2, "sp"), lesson("l3", 5, 1, "d")],
      exceptions: [],
      holidays: [],
      public_feed: [],
    },
  };
}

function serverFor(lang: "de" | "en" = "de") {
  const calls: { parts: string[]; from: string | null; days: number }[] = [];
  const server = familyServer(
    (parts, from, days) => {
      calls.push({ parts, from, days });
      return Promise.resolve(rows(from ?? TODAY, days));
    },
    () => lang,
    "test",
  );
  return { server, calls };
}

// deno-lint-ignore no-explicit-any
type Any = any;

Deno.test("tools: read-only, sorted, each with a schema", () => {
  assertEquals(TOOLS.map((t) => t.name), [...TOOLS.map((t) => t.name)].sort());
  for (const t of TOOLS) {
    assertEquals(t.annotations.readOnlyHint, true);
    assertEquals(t.annotations.destructiveHint, false);
    assertEquals((t.inputSchema as Any).type, "object");
  }
});

Deno.test("agenda: appointments with names, tasks due with their assignee", async () => {
  const { server, calls } = serverFor();
  const r = await server.callTool("get_agenda", { from: TODAY, to: "2026-10-16" });
  assertEquals(calls[0], { parts: ["calendar", "tasks_all"], from: TODAY, days: 2 });
  assertEquals(
    r.text,
    "Do., 15.10.: 08:30 Zahnarzt (Lotta) · Aufgaben: Spülmaschine ausräumen (Lotta)\nFr., 16.10.: Elternabend",
  );
  const day = (r.structured as Any).days[0];
  assertEquals(day.appointments[0].members, [{ id: "lotta", name: "Lotta" }]);
  assertEquals(day.tasks_due[0].assignee, { id: "lotta", name: "Lotta" });
});

Deno.test("agenda: an unknown member or a bad date is a tool error the assistant can act on", async () => {
  const { server } = serverFor();
  const who = await server.callTool("get_agenda", { member: "Oma" });
  assert(who.isError);
  assertEquals(who.text, "Niemand in der Familie heißt „Oma“. (Lukas, Sabine, Lotta)");
  const when = await serverFor("en").server.callTool("get_agenda", { from: "15.10.2026" });
  assert(when.isError);
  assertEquals(when.text, 'from must be a date as YYYY-MM-DD, not "15.10.2026".');
  const long = await server.callTool("get_agenda", { from: "2026-10-01", to: "2026-12-31" });
  assert(long.isError);
  const old = familyServer(
    () => Promise.reject({ code: "22023", hint: "window_invalid" }),
    () => "en",
    "test",
  );
  const past = await old.callTool("get_week_board", { weekOf: "2026-01-05" });
  assert(past.isError);
  assert(past.text.startsWith("Please give a range"));
});

Deno.test("tasks: open by default, done on request, by member", async () => {
  const { server } = serverFor();
  const open = await server.callTool("list_tasks", {});
  assertEquals((open.structured as Any).tasks.map((t: Any) => t.id), ["t1"]);
  assertEquals(open.text, "Spülmaschine ausräumen – Lotta – fällig Do., 15.10. – offen – 3 Punkte");
  const done = await server.callTool("list_tasks", { status: "done", member: "lukas" });
  assertEquals((done.structured as Any).tasks[0].completed_by, { id: "lukas", name: "Lukas" });
  assert((await server.callTool("list_tasks", { status: "later" })).isError);
});

Deno.test("meals: per day, with the cook", async () => {
  const r = await serverFor("en").server.callTool("get_meal_plan", {});
  assertEquals(r.text, "Thu, 15 Oct: Dinner: Spaghetti (Sabine)");
  assertEquals((r.structured as Any).days.length, 7);
});

Deno.test("shopping: grouped by the store's categories, the default list unless named", async () => {
  const { server } = serverFor();
  const r = await server.callTool("get_shopping_list", {});
  assertEquals(r.text, "Supermarkt: 2 offen\nObst & Gemüse: Äpfel 3×\nMilch & Käse: Milch (2 l)");
  assertEquals((r.structured as Any).groups[1].items[0].added_by, { id: "sabine", name: "Sabine" });
  const other = await server.callTool("get_shopping_list", { list: "baumarkt" });
  assertEquals(other.text, "Baumarkt: 1 offen\nSonstiges: Schrauben");
  const empty = familyServer(
    (parts, from, days) => Promise.resolve({ ...rows(from ?? TODAY, days), lists: [] }),
    () => "de",
    "test",
  );
  assertEquals(
    (await empty.callTool("get_shopping_list", {})).text,
    "Noch keine Einkaufsliste: sie entsteht mit dem ersten Artikel.",
  );
  const none = await server.callTool("get_shopping_list", { list: "Apotheke" });
  assert(none.isError);
  assertEquals(none.text, "Eine Liste „Apotheke“ gibt es nicht. (Supermarkt, Baumarkt)");
});

Deno.test("points: balance, recent ledger and streaks; the holder by default", async () => {
  const { server } = serverFor();
  const lotta = await server.callTool("get_points", { member: "Lotta" });
  assertEquals(lotta.text, "Lotta hat 42 Punkte.\n+3 Aufgabe\nSpülmaschine ausräumen: 4-mal in Folge");
  const me = await server.callTool("get_points", {});
  assertEquals((me.structured as Any).member, { id: "lukas", name: "Lukas" });
});

Deno.test("recipes: by title, tag or ingredient", async () => {
  const { server } = serverFor();
  const r = await server.callTool("find_recipe", { query: "zucchini" });
  assertEquals(r.text, "1 Rezept:\nZucchini-Lasagne: 2 Zucchini");
  assertEquals((await server.callTool("find_recipe", { query: "pasta" })).structured, {
    query: "pasta",
    recipes: [{
      id: "r1",
      title: "Spaghetti Bolognese",
      description: null,
      servings: 4,
      tags: ["Pasta"],
      ingredients: [{ name: "Hackfleisch", quantity: 500, unit: "g", note: null }],
    }],
  });
  assertEquals(
    (await server.callTool("find_recipe", { query: "Curry" })).text,
    "Kein Rezept passt zu „Curry“.",
  );
});

Deno.test("timetable: a child's day with what to pack; a member is required", async () => {
  const { server } = serverFor();
  const r = await server.callTool("get_timetable", { member: "Lotta" });
  assertEquals(r.text, "Lotta\nDo., 15.10.: 08:00–09:35 Deutsch, Sport Einpacken: Sportsachen.");
  assertEquals((r.structured as Any).days[0].lessons[1].subject, "Sport");
  assert((await server.callTool("get_timetable", {})).isError);
  assertEquals(
    (await server.callTool("get_timetable", { member: "Lukas" })).text,
    "Für Lukas ist kein Stundenplan eingetragen.",
  );
});

Deno.test("presence: entries first, the usual state otherwise", async () => {
  const { server } = serverFor();
  const r = await server.callTool("get_presence", { from: TODAY, to: TODAY });
  assertEquals(r.text, "Do., 15.10.: Lukas im Homeoffice (üblicherweise); Sabine auf Reise");
});

Deno.test("week board: the week from Monday, today marked", async () => {
  const { server, calls } = serverFor();
  const r = await server.callTool("get_week_board", {});
  // A light read for today, then the week from Monday.
  assertEquals(calls.map((c) => [c.from, c.days]), [[null, 1], ["2026-10-12", 7]]);
  const s = r.structured as Any;
  assertEquals(s.week_start, "2026-10-12");
  assertEquals(s.days[3].today, true);
  assertEquals(s.days[3].presence[0].member, { id: "sabine", name: "Sabine" });
  assert(
    r.text.includes(
      "Do., 15.10.: 08:30 Zahnarzt (Lotta) · Sabine auf Reise · Lotta: 08:00–09:35 Deutsch, Sport",
    ),
  );
});

Deno.test("resources: the members and today's agenda as JSON", async () => {
  const { server } = serverFor();
  const members = await server.readResource("family://members");
  assertEquals(JSON.parse(members!.text).members[2], {
    id: "lotta",
    name: "Lotta",
    role: "member",
    child: true,
  });
  const today = await server.readResource("family://agenda/today");
  assertEquals(JSON.parse(today!.text).days.length, 1);
  assertEquals(await server.readResource("family://nothing"), null);
});
