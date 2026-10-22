// The family:read tools and resources of the `mcp` function (specs/12 "Tools"): coarse,
// verb-shaped reads over the same context the shortcuts use (api.mcp_context), so the
// occurrence expansion and the school projection are the app's own. Plus the one write an
// assistant gets (specs/24 "Proposals"): propose_timetable stores a payload a guardian
// reviews in the app; nothing of the household changes until that review.
//
// Design rules from specs/12: read-only annotations; every id comes with a name; both a short
// human summary (in the household's language, mcp_de.ts / mcp_en.ts) and structured content;
// a bad argument is an informative tool error the assistant can act on, not a protocol error.
import { holidayOn } from "./board.ts";
import { addDays, type Occurrence } from "./occurrences.ts";
import type { ResourceDef, Server, ToolDef, ToolResult } from "./mcp.ts";
import { MCP_DE } from "./mcp_de.ts";
import { MCP_EN } from "./mcp_en.ts";
import { MCP_FR } from "./mcp_fr.ts";
import { MCP_ES } from "./mcp_es.ts";
import {
  findMember,
  fold,
  type Lang,
  type MemberRow,
  messagesFor,
  occurrencesOf,
  type PresenceState,
  schoolDaysOf,
  type ShortcutContext,
  type ShortcutMessages,
  type TaskRow,
} from "./shortcuts.ts";
import { usualOn, type UsualWeekRow } from "./usual_week.ts";

// ── the context of an assistant key ────────────────────────────────────────────────

export type TaskInstanceRow = TaskRow & {
  status: "open" | "done" | "verified" | "skipped" | "expired";
  completed_by_profile_id: string | null;
  completed_at: string | null;
};

export type McpContext = ShortcutContext & {
  /** The part 'usual': the active members' usual weeks (api.usual_weeks). */
  usual_weeks?: UsualWeekRow[];
  tasks_all?: TaskInstanceRow[];
  shopping_items?: {
    id: string;
    name: string;
    quantity: string | null;
    count: number;
    list_id: string;
    category_id: string | null;
    added_by: string | null;
  }[];
  shopping_categories?: {
    id: string;
    list_id: string;
    key: string | null;
    name: string | null;
    sort_order: number;
  }[];
  balances?: { profile_id: string; balance: number }[];
  ledger?: {
    profile_id: string;
    occurred_at: string;
    amount: number;
    reason: string;
    note: string | null;
  }[];
  streaks?: {
    profile_id: string;
    title: string | null;
    current_length: number;
    longest_length: number;
  }[];
  recipes?: {
    id: string;
    title: string;
    description: string | null;
    servings_default: number | null;
    tags: string[] | null;
  }[];
  ingredients?: {
    recipe_id: string;
    position: number;
    raw_name: string;
    quantity: number | null;
    unit: string | null;
    note: string | null;
  }[];
};

/** Loads a context: the parts, the first day (null: the household's today) and the days. */
export type Load = (
  parts: string[],
  from: string | null,
  days: number,
) => Promise<McpContext>;

/**
 * Stores a proposal for the key's household (api.mcp_propose): the kind, the payload of
 * specs/24, a one-line summary and the client's idempotency key. Rejects with the
 * database's `{hint}`: proposal_invalid, proposal_limit.
 */
export type Propose = (
  kind: string,
  payload: unknown,
  summary: string | null,
  clientKey: string | null,
) => Promise<{ id: string; created: boolean }>;

// ── the wording ─────────────────────────────────────────────────────────────────

export interface McpMessages {
  /** "Fr., 16.10." / "Fri 16 Oct". */
  day(date: string): string;
  noAppointments: string;
  tasks: string;
  anyone: string;
  taskStatus: Record<TaskInstanceRow["status"], string>;
  points(n: number): string;
  due(date: string): string;
  noTasks: string;
  noMeals: string;
  guests(n: number): string;
  shopping(list: string, n: number): string;
  /** No list exists yet (a family's lists are made with its first item). */
  noList: string;
  category: Record<string, string>;
  balance(name: string, n: number): string;
  ledgerReason: Record<string, string>;
  streak(title: string, n: number): string;
  recipes(n: number): string;
  noRecipe(query: string): string;
  lessonStatus: Record<
    "cancelled" | "substituted" | "room_change" | "extra",
    string
  >;
  weekend: string;
  schoolFree(holiday: string | null): string;
  baseline: string;
  nobodyAway: string;
  week(from: string): string;
  windowInvalid: string;
  memberRequired: string;
  dateInvalid(key: string, value: string): string;
  notText(key: string): string;
  statusInvalid: string;
  queryRequired: string;
  /** "Proposal stored: Emma's timetable, 24 lessons. A parent reviews it in WuselWall." */
  proposed(name: string, n: number): string;
  proposeInvalid: string;
  proposeLimit: string;
  proposeUnavailable: string;
  lessonsRequired: string;
}

export function mcpMessagesFor(lang: Lang): McpMessages {
  return ({ de: MCP_DE, en: MCP_EN, fr: MCP_FR, es: MCP_ES })[lang];
}

// ── definitions ─────────────────────────────────────────────────────────────────

const READ_ONLY = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
};
/** A proposal is a write, but a reversible one: nothing exists until a guardian applies it. */
const PROPOSE = {
  readOnlyHint: false,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
};
const DATE = {
  type: "string",
  format: "date",
  description: "YYYY-MM-DD, in the household's time zone",
};
const MEMBER = {
  type: "string",
  description: "A family member's name, as the family writes it",
};

function tool(
  name: string,
  title: string,
  description: string,
  properties: Record<string, unknown>,
  required: string[] = [],
  annotations: Record<string, unknown> = READ_ONLY,
): ToolDef {
  return {
    name,
    title,
    description,
    inputSchema: {
      type: "object",
      properties,
      required,
      additionalProperties: false,
    },
    annotations: { title, ...annotations },
  };
}

const CLOCK = { type: "string", description: "HH:MM, 24 hours" };
const LESSON = {
  type: "object",
  properties: {
    day: {
      type: ["integer", "string"],
      description:
        "Weekday: 1-7 (Monday = 1) or a name such as 'Mo', 'Montag', 'Thu'",
    },
    period: {
      type: ["integer", "string"],
      description: "The lesson's number on the sheet, 1 = first lesson",
    },
    starts: { ...CLOCK, description: "Start time, instead of a period" },
    ends: { ...CLOCK, description: "End time, with starts" },
    subject: {
      type: "string",
      description: "The short code on the sheet, e.g. 'Ma'",
    },
    name: {
      type: "string",
      description: "The subject's full name, if known, e.g. 'Mathematik'",
    },
    teacher: { type: "string" },
    room: { type: "string" },
    week: {
      type: "string",
      enum: ["a", "b"],
      description: "Only for A/B weeks",
    },
  },
  required: ["day", "subject"],
  additionalProperties: false,
};

// Sorted by name: a deterministic order lets clients cache the list (2026-07-28).
export const TOOLS: ToolDef[] = [
  tool(
    "find_recipe",
    "Find a recipe",
    "Recipes of the family whose title, tags or ingredients match the query, with their ingredients.",
    {
      query: {
        type: "string",
        description: "Words to look for, e.g. 'Lasagne' or 'Zucchini'",
      },
    },
    ["query"],
  ),
  tool(
    "get_agenda",
    "Agenda",
    "The family's appointments and the tasks due, day by day, with who is involved. Defaults to today and the next six days; at most 62 days.",
    {
      from: DATE,
      to: DATE,
      member: {
        ...MEMBER,
        description: "Only this member's appointments (and the whole family's)",
      },
    },
  ),
  tool(
    "get_meal_plan",
    "Meal plan",
    "Planned meals per day and slot, with who cooks. Defaults to today and the next six days.",
    {
      from: DATE,
      to: DATE,
    },
  ),
  tool(
    "get_points",
    "Points",
    "A member's point balance, the last 30 days of the ledger and their streaks. Defaults to the key's holder.",
    {
      member: MEMBER,
    },
  ),
  tool(
    "get_presence",
    "Who is home",
    "Who is working, travelling, away or in childcare on each day, from the calendar's presence entries and each member's usual week (none on a public holiday). Defaults to today and the next six days.",
    { from: DATE, to: DATE, member: MEMBER },
  ),
  tool(
    "get_shopping_list",
    "Shopping list",
    "The open items of a shopping list, grouped by category. Defaults to the family's default list.",
    {
      list: {
        type: "string",
        description: "The list's name, e.g. 'Supermarkt'",
      },
    },
  ),
  tool(
    "get_timetable",
    "School timetable",
    "A child's school day(s): lessons with times and rooms, cancellations and substitutions, holidays answered as such, and what to pack. Defaults to today.",
    {
      member: { ...MEMBER, description: "The child's name" },
      date: DATE,
      from: DATE,
      to: DATE,
    },
    ["member"],
  ),
  tool(
    "get_week_board",
    "Week board",
    "The kitchen wall's week as data: per day the appointments, who is away, each child's school day, the meals and the open tasks. The best single answer to 'what is going on?'.",
    {
      weekOf: {
        ...DATE,
        description:
          "Any day of the week wanted (YYYY-MM-DD); defaults to this week",
      },
    },
  ),
  tool(
    "list_tasks",
    "Tasks",
    "Task instances with points, due dates and status. Defaults to the open ones of today and the next six days.",
    {
      member: MEMBER,
      status: {
        type: "string",
        enum: ["open", "done", "all"],
        description: "Default: open",
      },
      from: DATE,
      to: DATE,
    },
  ),
  tool(
    "propose_timetable",
    "Propose a timetable",
    "Hands the family a child's school timetable read from a sheet or a photo, as a proposal. Nothing changes: a parent reviews it in the app, sees every lesson and subject it would create, and applies or discards it. Use the short subject codes as the sheet shows them; the app matches them to the family's subjects.",
    {
      member: { ...MEMBER, description: "The child's name" },
      lessons: { type: "array", items: LESSON, minItems: 1, maxItems: 200 },
      class: {
        type: "string",
        description: "The class, e.g. '3b', if on the sheet",
      },
      school: {
        type: "string",
        description: "The school's name, if on the sheet",
      },
      week_cycle: {
        type: "string",
        enum: ["weekly", "ab"],
        description: "'ab' when the sheet alternates A and B weeks",
      },
      periods: {
        type: "array",
        description: "The bell times on the sheet, if shown",
        items: {
          type: "object",
          properties: {
            index: { type: "integer" },
            starts: CLOCK,
            ends: CLOCK,
          },
          required: ["index", "starts", "ends"],
          additionalProperties: false,
        },
        maxItems: 15,
      },
      care: {
        type: "array",
        description:
          "After-school care (Hort) or clubs: name, weekdays and times",
        items: {
          type: "object",
          properties: {
            title: { type: "string" },
            days: { type: "array", items: { type: ["integer", "string"] } },
            starts: CLOCK,
            ends: CLOCK,
          },
          required: ["title", "days", "starts", "ends"],
          additionalProperties: false,
        },
        maxItems: 10,
      },
      client_key: {
        type: "string",
        description:
          "Any id of your own for this proposal; sending it again returns the same proposal instead of a second one",
      },
    },
    ["member", "lessons"],
    PROPOSE,
  ),
];

export const RESOURCES: ResourceDef[] = [
  {
    uri: "family://agenda/today",
    name: "agenda-today",
    title: "Today",
    description: "Today's appointments and tasks",
    mimeType: "application/json",
  },
  {
    uri: "family://meals/week",
    name: "meals-week",
    title: "Meals this week",
    description: "The meal plan of today and the next six days",
    mimeType: "application/json",
  },
  {
    uri: "family://members",
    name: "members",
    title: "Family members",
    description:
      "The family's members with their ids, roles and whether they are children",
    mimeType: "application/json",
  },
  {
    uri: "family://shopping/current",
    name: "shopping-current",
    title: "Shopping list",
    description: "The default shopping list's open items",
    mimeType: "application/json",
  },
];

export const INSTRUCTIONS =
  "WuselWall is one family's organiser: calendar, presence, school timetables, tasks with points, " +
  "meals and shopping. This connection reads; the one thing it can hand in is a proposal " +
  "(propose_timetable), which a parent reviews in the app before anything changes. It cannot add, " +
  "change or delete anything else. Dates are YYYY-MM-DD in the family's time zone. Refer to people " +
  "by the names the tools return, and ask rather than guess when a name is ambiguous. get_week_board " +
  "answers 'what is going on this week' in one call.";

// ── helpers ─────────────────────────────────────────────────────────────────────

/**
 * A tool error the assistant reads and can act on (specs/12: informative and actionable), worded
 * once the language is known.
 */
class ToolError extends Error {
  constructor(readonly say: (m: McpMessages, sc: ShortcutMessages) => string) {
    super("tool error");
  }
}

const ISO = /^\d{4}-\d{2}-\d{2}$/;

function dateArg(args: Record<string, unknown>, key: string): string | null {
  const v = args[key];
  if (v === undefined || v === null || v === "") return null;
  if (
    typeof v !== "string" || !ISO.test(v) ||
    new Date(`${v}T00:00:00Z`).toISOString().slice(0, 10) !== v
  ) {
    throw new ToolError((m) => m.dateInvalid(key, JSON.stringify(v)));
  }
  return v;
}

function stringArg(args: Record<string, unknown>, key: string): string | null {
  const v = args[key];
  if (v === undefined || v === null) return null;
  if (typeof v !== "string") throw new ToolError((m) => m.notText(key));
  return v.trim() === "" ? null : v.trim();
}

function daysBetween(from: string, to: string): number {
  return (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) /
      86_400_000 + 1;
}

function datesOf(from: string, to: string): string[] {
  const out: string[] = [];
  for (let d = from; d <= to; d = addDays(d, 1)) out.push(d);
  return out;
}

/** The ISO weekday's Monday on or before a date. */
function mondayOf(date: string): string {
  const wd = new Date(`${date}T00:00:00Z`).getUTCDay();
  return addDays(date, -((wd + 6) % 7));
}

type Ref = { id: string; name: string };

function ref(ctx: McpContext, id: string | null): Ref | null {
  if (id === null) return null;
  const m = ctx.members.find((x) => x.id === id);
  return { id, name: m?.display_name ?? "?" };
}

function member(ctx: McpContext, name: string | null): MemberRow | null {
  if (name === null) return null;
  const found = findMember(ctx.members, name);
  if (!found) {
    const names = ctx.members.map((x) => x.display_name).join(", ");
    throw new ToolError((_, sc) => `${sc.memberUnknown(name)} (${names})`);
  }
  return found;
}

// ── the family server ─────────────────────────────────────────────────────────────

/**
 * The MCP server for one request: `load` reads the key's context, `lang` picks the language of
 * the summaries once the household's locale is known.
 */
export function familyServer(
  loadRows: Load,
  lang: (locale: string | null) => Lang,
  version: string,
  propose?: Propose,
): Server {
  // The household's locale once a context was read: the language of the summaries and errors.
  let locale: string | null = null;
  const load: Load = async (parts, from, days) => {
    let ctx: McpContext;
    try {
      ctx = await loadRows(parts, from, days);
    } catch (err) {
      // The database refuses a window that starts more than a week back: the assistant's to fix.
      if ((err as { hint?: unknown } | null)?.hint === "window_invalid") {
        throw new ToolError((m) => m.windowInvalid);
      }
      throw err;
    }
    locale = ctx.household.locale;
    return ctx;
  };

  /** Loads [from, to] (either may be missing): explicit days, or from today. */
  async function loadWindow(
    parts: string[],
    args: Record<string, unknown>,
    defaultDays = 7,
  ) {
    const from = dateArg(args, "from");
    const to = dateArg(args, "to");
    if (from && to && (to < from || daysBetween(from, to) > 62)) {
      throw new ToolError((m) => m.windowInvalid);
    }
    // Without a start the window starts today, which only the server knows: load enough, clip.
    const ctx = await load(
      parts,
      from,
      from && to ? daysBetween(from, to) : to ? 62 : defaultDays,
    );
    const last = to ?? ctx.window.to;
    if (last < ctx.window.from) throw new ToolError((m) => m.windowInvalid);
    return {
      ctx,
      from: ctx.window.from,
      to: last < ctx.window.to ? last : ctx.window.to,
    };
  }

  function words(ctx: McpContext) {
    const l = lang(ctx.household.locale);
    return { m: mcpMessagesFor(l), sc: messagesFor(l) };
  }

  function appointmentsOn(
    ctx: McpContext,
    occ: Occurrence[],
    date: string,
    only: MemberRow | null,
  ) {
    return occ
      .filter((o) =>
        o.kind === "appointment" && o.local_start_date <= date &&
        o.local_end_date >= date &&
        (only === null || o.attendee_ids.length === 0 ||
          o.attendee_ids.includes(only.id))
      )
      .map((o) => ({
        title: o.title,
        all_day: o.all_day,
        starts: o.local_start_date === date ? o.local_starts : null,
        ends: o.local_end_date === date ? o.local_ends : null,
        location: o.location,
        tentative: o.status === "tentative",
        key: o.importance === "key",
        imported: o.source === "imported",
        members: o.attendee_ids.map((id) => ref(ctx, id)!),
      }));
  }

  function appointmentText(
    a: ReturnType<typeof appointmentsOn>[number],
  ): string {
    const who = a.members.length > 0
      ? ` (${a.members.map((x) => x.name).join(", ")})`
      : "";
    return a.all_day || !a.starts
      ? `${a.title}${who}`
      : `${a.starts} ${a.title}${who}`;
  }

  function taskData(ctx: McpContext, t: TaskInstanceRow) {
    return {
      id: t.id,
      title: t.title,
      assignee: ref(ctx, t.assigned_profile_id),
      due_on: t.due_on,
      status: t.status,
      points: t.points,
    };
  }

  function presenceOn(
    ctx: McpContext,
    occ: Occurrence[],
    date: string,
    only: MemberRow | null,
    sc: ShortcutMessages,
  ) {
    const out: {
      member: Ref;
      state: string;
      label: string;
      from: string | null;
      until: string | null;
      usual: boolean;
    }[] = [];
    for (const mem of ctx.members) {
      if (only && mem.id !== only.id) continue;
      const entries = occ.filter((o) =>
        o.kind === "presence" && o.attendee_ids.includes(mem.id) &&
        o.local_start_date <= date &&
        o.local_end_date >= date
      );
      for (const o of entries) {
        out.push({
          member: { id: mem.id, name: mem.display_name },
          state: o.presence_state!,
          label: sc.state[o.presence_state as PresenceState] ??
            o.presence_state!,
          from: o.all_day || o.local_start_date !== date
            ? null
            : o.local_starts,
          until: o.all_day || o.local_end_date !== date ? null : o.local_ends,
          usual: false,
        });
      }
      if (entries.length > 0) continue;
      for (const place of usualPlaces(ctx, mem, date)) {
        out.push({
          member: { id: mem.id, name: mem.display_name },
          state: place.state,
          label: place.label ?? sc.state[place.state as PresenceState] ??
            place.state,
          from: place.starts,
          until: place.ends,
          usual: true,
        });
      }
    }
    return out;
  }

  /**
   * A member's usual places on a date: from the usual week when the context carries it
   * (none on a public holiday), else the single baseline of a context without it.
   */
  function usualPlaces(ctx: McpContext, mem: MemberRow, date: string) {
    if (ctx.usual_weeks) {
      const week = ctx.usual_weeks.find((w) => w.profile_id === mem.id);
      if (!week) return [];
      const holiday = holidayOn(
        date,
        ctx.school?.holidays ?? [],
        ctx.school?.public_feed ?? [],
        ctx.household.region,
        ctx.household.locale,
      );
      return holiday ? [] : usualOn(week, date);
    }
    if (!mem.default_presence_state) return [];
    return [{
      state: mem.default_presence_state,
      label: mem.default_presence_label,
      starts: null as string | null,
      ends: null as string | null,
    }];
  }

  function schoolOf(ctx: McpContext, date: string, child: MemberRow | null) {
    return schoolDaysOf(ctx)
      .filter((d) =>
        d.date === date && (child === null || d.member_id === child.id)
      )
      .map((d) => ({
        member: ref(ctx, d.member_id)!,
        date: d.date,
        free: d.free,
        holiday: d.holiday_name,
        starts: d.starts,
        ends: d.ends,
        care_until: d.care_until,
        lessons: d.lessons.map((l) => ({
          period: l.period,
          starts: l.starts,
          ends: l.ends,
          subject: l.subject,
          kind: l.kind,
          status: l.status,
          room: l.room,
          teacher: l.teacher,
          note: l.note,
        })),
        equipment: ctx.equipment_hint
          ? [
            ...new Set(
              d.lessons.filter((l) => l.status !== "cancelled" && l.equipment)
                .map((l) => l.equipment!),
            ),
          ]
          : [],
      }));
  }

  function schoolText(
    s: ReturnType<typeof schoolOf>[number],
    m: McpMessages,
    sc: ShortcutMessages,
  ): string {
    if (s.free === "weekend") return m.weekend;
    if (s.free === "holiday") return m.schoolFree(s.holiday);
    const lessons = s.lessons
      .filter((l) => l.kind === "lesson")
      .map((
        l,
      ) => (l.status === "normal"
        ? l.subject
        : `${l.subject} (${m.lessonStatus[l.status]})`)
      );
    const head = s.starts && s.ends ? `${s.starts}–${s.ends} ` : "";
    const pack = s.equipment.length > 0 ? ` ${sc.equipment(s.equipment)}` : "";
    return `${head}${lessons.join(", ")}${pack}`.trim();
  }

  function mealsOf(ctx: McpContext, date: string) {
    const order = ["breakfast", "lunch", "dinner", "snack"];
    return (ctx.meals ?? [])
      .filter((x) => x.on_date === date)
      .sort((a, b) => order.indexOf(a.slot) - order.indexOf(b.slot))
      .map((x) => ({
        slot: x.slot,
        title: x.title,
        cook: ref(ctx, x.cook_profile_id),
        at: x.at_time,
        guests: (x as { guests?: number }).guests ?? 0,
      }));
  }

  function mealText(
    x: ReturnType<typeof mealsOf>[number],
    m: McpMessages,
    sc: ShortcutMessages,
  ): string {
    const slot = sc.slot[x.slot as keyof ShortcutMessages["slot"]] ?? x.slot;
    const cook = x.cook ? ` (${x.cook.name})` : "";
    const guests = x.guests > 0 ? ` ${m.guests(x.guests)}` : "";
    return `${slot}: ${x.title ?? "?"}${cook}${guests}`;
  }

  // ── the tools ──

  const tools: Record<
    string,
    (args: Record<string, unknown>) => Promise<ToolResult>
  > = {
    get_agenda: (args) => agenda(args, 7),
  };

  /** The agenda of [from, to], or of `defaultDays` from today. */
  async function agenda(
    args: Record<string, unknown>,
    defaultDays: number,
  ): Promise<ToolResult> {
    const { ctx, from, to } = await loadWindow(
      ["calendar", "tasks_all"],
      args,
      defaultDays,
    );
    const { m } = words(ctx);
    const only = member(ctx, stringArg(args, "member"));
    const occ = occurrencesOf(ctx);
    const days = datesOf(from, to).map((date) => ({
      date,
      appointments: appointmentsOn(ctx, occ, date, only),
      tasks_due: (ctx.tasks_all ?? [])
        .filter((t) =>
          t.due_on === date && t.status === "open" &&
          (only === null || t.assigned_profile_id === only.id ||
            t.assigned_profile_id === null)
        )
        .map((t) => taskData(ctx, t)),
    }));
    const lines = days.map((d) => {
      const ap = d.appointments.length > 0
        ? d.appointments.map((a) => appointmentText(a)).join("; ")
        : m.noAppointments;
      const tasks = d.tasks_due.length > 0
        ? ` · ${m.tasks}: ${
          d.tasks_due.map((t) => `${t.title} (${t.assignee?.name ?? m.anyone})`)
            .join(", ")
        }`
        : "";
      return `${m.day(d.date)}: ${ap}${tasks}`;
    });
    return {
      text: lines.join("\n"),
      structured: { from, to, member: only ? ref(ctx, only.id) : null, days },
    };
  }

  const more: Record<
    string,
    (args: Record<string, unknown>) => Promise<ToolResult>
  > = {
    async list_tasks(args) {
      const { ctx, from, to } = await loadWindow(["tasks_all"], args);
      const { m } = words(ctx);
      const only = member(ctx, stringArg(args, "member"));
      const status = stringArg(args, "status") ?? "open";
      if (!["open", "done", "all"].includes(status)) {
        throw new ToolError((m) => m.statusInvalid);
      }
      const tasks = (ctx.tasks_all ?? [])
        .filter((t) => t.due_on >= from && t.due_on <= to)
        .filter((t) => only === null || t.assigned_profile_id === only.id)
        .filter((t) =>
          status === "all" ||
          (status === "open"
            ? t.status === "open"
            : t.status === "done" || t.status === "verified")
        )
        .map((t) => ({
          ...taskData(ctx, t),
          completed_by: ref(ctx, t.completed_by_profile_id),
        }));
      const text = tasks.length === 0 ? m.noTasks : tasks
        .map((t) =>
          `${t.title} – ${t.assignee?.name ?? m.anyone} – ${
            m.due(m.day(t.due_on))
          } – ${m.taskStatus[t.status]} – ${m.points(t.points)}`
        )
        .join("\n");
      return { text, structured: { from, to, status, tasks } };
    },

    async get_meal_plan(args) {
      const { ctx, from, to } = await loadWindow(["meals"], args);
      const { m, sc } = words(ctx);
      const days = datesOf(from, to).map((date) => ({
        date,
        meals: mealsOf(ctx, date),
      }));
      const lines = days
        .filter((d) => d.meals.length > 0)
        .map((d) =>
          `${m.day(d.date)}: ${
            d.meals.map((x) => mealText(x, m, sc)).join("; ")
          }`
        );
      return {
        text: lines.length > 0 ? lines.join("\n") : m.noMeals,
        structured: { from, to, days },
      };
    },

    async get_shopping_list(args) {
      const ctx = await load(["shopping"], null, 1);
      const { m } = words(ctx);
      const wanted = stringArg(args, "list");
      if (wanted === null && ctx.lists.length === 0) {
        return { text: m.noList, structured: { list: null, groups: [] } };
      }
      const list = wanted === null
        ? ctx.lists.find((l) => l.is_default) ?? ctx.lists[0]
        : ctx.lists.find((l) => fold(l.name) === fold(wanted));
      if (!list) {
        const names = ctx.lists.map((l) => l.name).join(", ");
        throw new ToolError((_, s) =>
          `${s.listUnknown(wanted ?? "")} (${names})`
        );
      }
      const categories = (ctx.shopping_categories ?? []).filter((c) =>
        c.list_id === list.id
      );
      const items = (ctx.shopping_items ?? []).filter((i) =>
        i.list_id === list.id
      );
      const nameOf = (c: { key: string | null; name: string | null }) =>
        c.name ?? (c.key ? m.category[c.key] ?? c.key : m.category.other);
      const groups = [
        ...categories.map((c) => ({
          category: nameOf(c),
          items: items.filter((i) => i.category_id === c.id),
        })),
        {
          category: m.category.other,
          items: items.filter((i) =>
            !categories.some((c) => c.id === i.category_id)
          ),
        },
      ]
        .filter((g) => g.items.length > 0)
        .map((g) => ({
          category: g.category,
          items: g.items.map((i) => ({
            id: i.id,
            name: i.name,
            quantity: i.quantity,
            count: i.count,
            added_by: ref(ctx, i.added_by),
          })),
        }));
      const itemText = (
        i: { name: string; quantity: string | null; count: number },
      ) =>
        `${i.name}${i.quantity ? ` (${i.quantity})` : ""}${
          i.count > 1 ? ` ${i.count}×` : ""
        }`;
      const text = [
        m.shopping(list.name, items.length),
        ...groups.map((g) =>
          `${g.category}: ${g.items.map(itemText).join(", ")}`
        ),
      ].join("\n");
      return {
        text,
        structured: { list: { id: list.id, name: list.name }, groups },
      };
    },

    async get_points(args) {
      const ctx = await load(["points"], null, 1);
      const { m } = words(ctx);
      const who = member(ctx, stringArg(args, "member")) ??
        ctx.members.find((x) => x.id === ctx.holder.profile_id)!;
      const balance =
        (ctx.balances ?? []).find((b) => b.profile_id === who.id)?.balance ?? 0;
      const ledger = (ctx.ledger ?? []).filter((l) => l.profile_id === who.id)
        .slice(0, 20).map((l) => ({
          at: l.occurred_at,
          amount: l.amount,
          reason: l.reason,
          note: l.note,
        }));
      const streaks = (ctx.streaks ?? [])
        .filter((s) => s.profile_id === who.id && s.current_length > 0)
        .map((s) => ({
          task: s.title,
          current: s.current_length,
          longest: s.longest_length,
        }));
      const lines = [m.balance(who.display_name, balance)];
      if (ledger.length > 0) {
        lines.push(
          ledger.slice(0, 5).map((l) =>
            `${l.amount > 0 ? "+" : ""}${l.amount} ${
              m.ledgerReason[l.reason] ?? l.reason
            }${l.note ? ` (${l.note})` : ""}`
          ).join(", "),
        );
      }
      for (const s of streaks) lines.push(m.streak(s.task ?? "?", s.current));
      return {
        text: lines.join("\n"),
        structured: { member: ref(ctx, who.id), balance, ledger, streaks },
      };
    },

    async find_recipe(args) {
      const query = stringArg(args, "query");
      if (query === null) throw new ToolError((m) => m.queryRequired);
      const ctx = await load(["recipes"], null, 1);
      const { m } = words(ctx);
      const terms = fold(query).split(/\s+/).filter((t) => t !== "");
      const matches = (ctx.recipes ?? [])
        .map((r) => {
          const ingredients = (ctx.ingredients ?? []).filter((i) =>
            i.recipe_id === r.id
          );
          const hay = fold(
            [r.title, ...(r.tags ?? []), ...ingredients.map((i) => i.raw_name)]
              .join(" "),
          );
          return {
            r,
            ingredients,
            score: terms.filter((t) => hay.includes(t)).length,
          };
        })
        .filter((x) => x.score === terms.length)
        .slice(0, 10)
        .map(({ r, ingredients }) => ({
          id: r.id,
          title: r.title,
          description: r.description,
          servings: r.servings_default,
          tags: r.tags ?? [],
          ingredients: ingredients.map((i) => ({
            name: i.raw_name,
            quantity: i.quantity,
            unit: i.unit,
            note: i.note,
          })),
        }));
      const text = matches.length === 0 ? m.noRecipe(query) : [
        m.recipes(matches.length),
        ...matches.map((r) =>
          r.ingredients.length === 0
            ? r.title
            : `${r.title}: ${
              r.ingredients.map((i) =>
                [i.quantity, i.unit, i.name].filter((x) =>
                  x !== null && x !== ""
                ).join(" ")
              ).join(", ")
            }`
        ),
      ].join("\n");
      return { text, structured: { query, recipes: matches } };
    },

    async get_timetable(args) {
      const date = dateArg(args, "date");
      const { ctx, from, to } = date
        ? await loadWindow(["school"], { from: date, to: date })
        : await loadWindow(["school"], args, 1);
      const { m, sc } = words(ctx);
      const name = stringArg(args, "member");
      if (name === null) throw new ToolError((x) => x.memberRequired);
      const child = member(ctx, name)!;
      const days = datesOf(from, to).flatMap((d) => schoolOf(ctx, d, child));
      if (days.length === 0) {
        return {
          text: sc.noTimetable(child.display_name),
          structured: { member: ref(ctx, child.id), days: [] },
        };
      }
      const text = days.map((d) => `${m.day(d.date)}: ${schoolText(d, m, sc)}`)
        .join("\n");
      return {
        text: `${child.display_name}\n${text}`,
        structured: { member: ref(ctx, child.id), days },
      };
    },

    async get_presence(args) {
      const { ctx, from, to } = await loadWindow([
        "calendar",
        "school",
        "usual",
      ], args);
      const { m, sc } = words(ctx);
      const only = member(ctx, stringArg(args, "member"));
      const occ = occurrencesOf(ctx);
      const days = datesOf(from, to).map((date) => ({
        date,
        members: presenceOn(ctx, occ, date, only, sc),
      }));
      const lines = days.map((d) => {
        const parts = d.members.map((p) =>
          `${p.member.name} ${p.label}${
            p.from || p.until ? ` ${p.from ?? ""}–${p.until ?? ""}` : ""
          }${p.usual ? ` (${m.baseline})` : ""}`
        );
        return `${m.day(d.date)}: ${
          parts.length > 0 ? parts.join("; ") : m.nobodyAway
        }`;
      });
      return { text: lines.join("\n"), structured: { from, to, days } };
    },

    async get_week_board(args) {
      const weekOf = dateArg(args, "weekOf");
      // This week's Monday needs the household's today: a light read first when no day is given.
      const anchor = weekOf ?? (await load([], null, 1)).household.today;
      const monday = mondayOf(anchor);
      const ctx = await load(
        ["calendar", "school", "meals", "tasks_all"],
        monday,
        7,
      );
      const { m, sc } = words(ctx);
      const occ = occurrencesOf(ctx);
      const days = datesOf(monday, addDays(monday, 6)).map((date) => ({
        date,
        today: date === ctx.household.today,
        appointments: appointmentsOn(ctx, occ, date, null),
        presence: presenceOn(ctx, occ, date, null, sc).filter((p) => !p.usual),
        school: schoolOf(ctx, date, null),
        meals: mealsOf(ctx, date),
        open_tasks: (ctx.tasks_all ?? [])
          .filter((t) => t.due_on === date && t.status === "open")
          .map((t) => taskData(ctx, t)),
      }));
      const lines = days.map((d) => {
        const parts = [
          d.appointments.length > 0
            ? d.appointments.map((a) => appointmentText(a)).join("; ")
            : m.noAppointments,
          ...d.presence.map((p) => `${p.member.name} ${p.label}`),
          ...d.school.filter((s) => s.free !== "weekend").map((s) =>
            `${s.member.name}: ${schoolText(s, m, sc)}`
          ),
          ...d.meals.map((x) => mealText(x, m, sc)),
          ...(d.open_tasks.length > 0
            ? [`${m.tasks}: ${d.open_tasks.map((t) => t.title).join(", ")}`]
            : []),
        ];
        return `${m.day(d.date)}: ${parts.join(" · ")}`;
      });
      return {
        text: [m.week(m.day(monday)), ...lines].join("\n"),
        structured: {
          week_start: monday,
          today: ctx.household.today,
          members: ctx.members.map((x) => ref(ctx, x.id)),
          days,
        },
      };
    },
  };
  Object.assign(tools, more);

  tools.propose_timetable = async (args) => {
    if (!propose) throw new ToolError((m) => m.proposeUnavailable);
    const name = stringArg(args, "member");
    if (name === null) throw new ToolError((m) => m.memberRequired);
    const base = await load([], null, 1);
    const child = member(base, name)!;
    const lessons = args.lessons;
    if (!Array.isArray(lessons) || lessons.length === 0) {
      throw new ToolError((m) => m.lessonsRequired);
    }
    const payload: Record<string, unknown> = {
      format: "wuselwall-timetable/1",
      member: child.display_name,
      lessons,
    };
    for (const key of ["class", "school", "week_cycle", "periods", "care"]) {
      if (args[key] !== undefined && args[key] !== null) {
        payload[key] = args[key];
      }
    }
    const { m } = words(base);
    const summary =
      m.proposed(child.display_name, lessons.length).split(/[.。]/)[0];
    let out: { id: string; created: boolean };
    try {
      out = await propose(
        "timetable",
        payload,
        summary,
        stringArg(args, "client_key"),
      );
    } catch (err) {
      const hint = (err as { hint?: unknown } | null)?.hint;
      if (hint === "proposal_invalid") {
        throw new ToolError((m) => m.proposeInvalid);
      }
      if (hint === "proposal_limit") throw new ToolError((m) => m.proposeLimit);
      throw err;
    }
    return {
      text: m.proposed(child.display_name, lessons.length),
      structured: {
        proposal_id: out.id,
        created: out.created,
        member: { id: child.id, name: child.display_name },
        lessons: lessons.length,
      },
    };
  };

  return {
    info: { name: "wuselwall", version },
    instructions: INSTRUCTIONS,
    tools: TOOLS,
    resources: RESOURCES,
    async callTool(name, args) {
      try {
        return await tools[name](args);
      } catch (err) {
        if (!(err instanceof ToolError)) throw err;
        const l = lang(locale);
        const text = err.say(mcpMessagesFor(l), messagesFor(l));
        return { text, structured: { error: text }, isError: true };
      }
    },
    async readResource(uri) {
      const json = (r: ToolResult) => ({
        mimeType: "application/json",
        text: JSON.stringify(r.structured),
      });
      switch (uri) {
        case "family://agenda/today":
          return json(await agenda({}, 1));
        case "family://meals/week":
          return json(await tools.get_meal_plan({}));
        case "family://shopping/current":
          return json(await tools.get_shopping_list({}));
        case "family://members": {
          const ctx = await load([], null, 1);
          return {
            mimeType: "application/json",
            text: JSON.stringify({
              household: ctx.household.name,
              members: ctx.members.map((x) => ({
                id: x.id,
                name: x.display_name,
                role: x.role,
                child: x.kind === "child",
              })),
            }),
          };
        }
        default:
          return null;
      }
    },
  };
}
