// /functions/v1/shortcuts/<action> → Siri and Apple Shortcuts (specs/12 "Part 1", FR-6.5).
//
//   POST shopping   {text, list?, id?}          add dictated items to a list
//   GET  today      ?day=                       the day: appointments, meals, my tasks
//   GET  meals      ?day=                       what is for lunch and dinner, who cooks
//   GET  points                                 my points
//   POST chore      {text}                      tick one of my open tasks (no text: list them)
//   GET  school     ?member=&day=&subject= | ?text=   "Hat Mia morgen Sport?"
//   GET  presence   ?member= | ?text=           "Wann ist Julia wieder da?"
//
// Every parameter may come in the query or in a JSON body. The token is the Authorization
// header ("Bearer wws_…"), never the URL, so it stays out of logs. The answer is plain text
// for Show Result and Speak, or JSON ({text, …}) with `Accept: application/json` or format=json.
// The language is `lang`, else Accept-Language, else the household's.
//
// No user is signed in: a shortcut has its token only, so this function uses the service-role
// client. That is safe because every api.shortcut_* function starts from the token, acts as its
// holder only, and returns only the token's household (migrations/20261016110000_shortcuts.sql).
import { serviceClient } from "../_shared/client.ts";
import {
  type Answer,
  answerChoreDone,
  answerChorePick,
  answerDay,
  answerMeals,
  answerPoints,
  answerPresence,
  answerSchool,
  answerShopping,
  type ChoreResult,
  type DaySpec,
  findMember,
  type Lang,
  memberInText,
  messagesFor,
  parseDay,
  parseShoppingText,
  pickChore,
  pickLang,
  resolveDay,
  type ShoppingResult,
  type ShortcutContext,
  type ShortcutMessages,
  subjectInText,
  windowFor,
} from "../_shared/shortcuts.ts";

type Params = Record<string, string>;

/** A refusal with its status and the sentence the shortcut shows. */
class Refusal extends Error {
  constructor(readonly status: number, readonly text: (m: ShortcutMessages) => string) {
    super("refused");
  }
}

const TOKEN = /^wws_[A-Za-z0-9_-]{20,200}$/;

function tokenOf(req: Request): string | null {
  const match = /^Bearer\s+(\S+)$/i.exec(req.headers.get("Authorization") ?? "");
  return match && TOKEN.test(match[1]) ? match[1] : null;
}

/** The action is the path segment after "shortcuts", whatever prefix the gateway kept. */
function actionOf(pathname: string): string {
  const parts = pathname.split("/").filter((p) => p !== "");
  const at = parts.lastIndexOf("shortcuts");
  return (at >= 0 ? parts[at + 1] : parts[parts.length - 1]) ?? "";
}

/** Query parameters, overlaid by a JSON body's string, number and boolean values. */
async function paramsOf(req: Request, url: URL): Promise<Params> {
  const params: Params = Object.fromEntries(url.searchParams);
  if (req.method === "POST" && (req.headers.get("Content-Type") ?? "").includes("json")) {
    try {
      const body = await req.json();
      if (body && typeof body === "object" && !Array.isArray(body)) {
        for (const [k, v] of Object.entries(body)) {
          if (["string", "number", "boolean"].includes(typeof v)) params[k] = String(v);
        }
      }
    } catch {
      // An unreadable body is the same as none: the action says what it misses.
    }
  }
  return params;
}

function wantsJson(req: Request, params: Params): boolean {
  return params.format === "json" || (req.headers.get("Accept") ?? "").includes("application/json");
}

function reply(answer: Answer, status: number, json: boolean): Response {
  return json
    ? new Response(JSON.stringify({ text: answer.text, ...answer.data }), {
      status,
      headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
    })
    : new Response(answer.text, {
      status,
      headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" },
    });
}

/** The database's refusals, by hint; anything else is a failure. Never logs the token. */
function refusalOf(err: unknown, params: Params): Refusal {
  if (err instanceof Refusal) return err;
  const hint = (err as { hint?: unknown } | null)?.hint;
  switch (hint) {
    case "shortcut_token_invalid":
      return new Refusal(401, (m) => m.tokenInvalid);
    case "shortcut_rate_limited":
      return new Refusal(429, (m) => m.rateLimited);
    case "list_not_found":
      return new Refusal(404, (m) => m.listUnknown(params.list ?? ""));
    case "window_invalid":
      return new Refusal(400, (m) => m.dayInvalid(params.day ?? ""));
    case "items_invalid":
      return new Refusal(400, (m) => m.textRequired);
  }
  console.error("shortcuts failed with", (err as { code?: unknown } | null)?.code ?? "no code");
  return new Refusal(500, (m) => m.failed);
}

async function rpc<T>(name: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await serviceClient().rpc(name, args);
  if (error) throw error;
  return data as T;
}

function context(token: string, parts: string[], from: string | null, days: number) {
  return rpc<ShortcutContext>("shortcut_context", {
    p_token: token,
    p_parts: parts,
    p_from: from,
    p_days: days,
  });
}

/** The day asked for: `day` (a word or a date), else the question's day word, else `fallback`. */
function daySpec(params: Params, fallback: DaySpec): DaySpec {
  if (params.day !== undefined && params.day.trim() !== "") {
    const spec = parseDay(params.day);
    if (!spec) throw new Refusal(400, (m) => m.dayInvalid(params.day));
    return spec;
  }
  return parseDay(params.text ?? "") ?? fallback;
}

/** One request: its token, parameters, clock and language preference. */
type Call = {
  token: string;
  params: Params;
  now: Date;
  /** The answer's language once the household's locale is known (pickLang). */
  lang: (householdLocale: string | null) => Lang;
};

type Handler = (call: Call) => Promise<Answer>;

const HANDLERS: Record<string, { methods: string[]; run: Handler }> = {
  shopping: {
    methods: ["POST"],
    run: async ({ token, params, lang }) => {
      const items = parseShoppingText(params.text ?? "");
      if (items.length === 0) throw new Refusal(400, (m) => m.textRequired);
      const id = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(params.id ?? "")
        ? params.id
        : null;
      const list = params.list?.trim() || null;
      const result = await rpc<ShoppingResult>("shortcut_shopping_add", {
        p_token: token,
        p_items: items,
        p_list: list,
        p_op_id: id,
      });
      return answerShopping(result, items, list === null, messagesFor(lang(result.locale)));
    },
  },
  today: {
    methods: ["GET", "POST"],
    run: async ({ token, params, lang }) => {
      const spec = daySpec(params, { kind: "offset", days: 0 });
      const w = windowFor(spec);
      const ctx = await context(token, ["calendar", "meals", "tasks"], w.from, w.days);
      const m = messagesFor(lang(ctx.household.locale));
      return answerDay(ctx, resolveDay(spec, ctx.household.today), m);
    },
  },
  meals: {
    methods: ["GET", "POST"],
    run: async ({ token, params, lang }) => {
      const spec = daySpec(params, { kind: "offset", days: 0 });
      const w = windowFor(spec);
      const ctx = await context(token, ["meals"], w.from, w.days);
      const m = messagesFor(lang(ctx.household.locale));
      return answerMeals(ctx, resolveDay(spec, ctx.household.today), m);
    },
  },
  points: {
    methods: ["GET", "POST"],
    run: async ({ token, lang }) => {
      const ctx = await context(token, [], null, 1);
      return answerPoints(ctx, messagesFor(lang(ctx.household.locale)));
    },
  },
  chore: {
    methods: ["POST"],
    run: async ({ token, params, lang }) => {
      const ctx = await context(token, ["tasks"], null, 1);
      const m = messagesFor(lang(ctx.household.locale));
      const text = params.text ?? "";
      const pick = pickChore(ctx, text);
      if (pick.kind !== "task") return answerChorePick(pick, text, m);
      const result = await rpc<ChoreResult>("shortcut_task_complete", {
        p_token: token,
        p_instance_id: pick.task.id,
      });
      return answerChoreDone(result, m);
    },
  },
  school: {
    methods: ["GET", "POST"],
    run: async ({ token, params, lang }) => {
      // School questions are mostly asked the evening before: tomorrow unless a day is named.
      const spec = daySpec(params, { kind: "offset", days: 1 });
      const w = windowFor(spec);
      const ctx = await context(token, ["school"], w.from, w.days);
      const m = messagesFor(lang(ctx.household.locale));
      const subjects = ctx.school?.subjects ?? [];
      // A subject the household does not have is still answered: "Nein, … kein Latein."
      const named = params.subject?.trim();
      const subject = named
        ? subjectInText(subjects, named) ?? { name: named, short_name: null }
        : subjectInText(subjects, params.text ?? "");
      return answerSchool(ctx, memberOf(ctx, params), resolveDay(spec, ctx.household.today), subject, m);
    },
  },
  presence: {
    methods: ["GET", "POST"],
    run: async ({ token, params, now, lang }) => {
      // Today and the four weeks after: enough for "back on Saturday" and "next trip".
      const ctx = await context(token, ["calendar"], null, 30);
      return answerPresence(ctx, memberOf(ctx, params), now, messagesFor(lang(ctx.household.locale)));
    },
  },
};

/** The member named by `member`, else in the question; the holder when neither names one. */
function memberOf(ctx: ShortcutContext, params: Params) {
  const named = params.member?.trim();
  if (named) {
    const found = findMember(ctx.members, named);
    if (!found) throw new Refusal(404, (m) => m.memberUnknown(named));
    return found;
  }
  const inText = memberInText(ctx.members, params.text ?? "");
  if (inText) return inText;
  const holder = ctx.members.find((x) => x.id === ctx.holder.profile_id);
  if (!holder) throw new Refusal(400, (m) => m.memberRequired);
  return holder;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const url = new URL(req.url);
  const params = await paramsOf(req, url);
  const json = wantsJson(req, params);
  const acceptLanguage = req.headers.get("Accept-Language");
  const lang = (householdLocale: string | null) => pickLang(params.lang, acceptLanguage, householdLocale);
  // Refusals come before the household is known, or instead of it: the request's language.
  const m = messagesFor(lang(null));

  const handler = HANDLERS[actionOf(url.pathname)];
  if (!handler) return reply({ text: m.unknownAction, data: {} }, 404, json);
  if (!handler.methods.includes(req.method)) {
    return reply({ text: m.unknownAction, data: {} }, 405, json);
  }
  const token = tokenOf(req);
  if (token === null) return reply({ text: m.tokenInvalid, data: {} }, 401, json);

  try {
    return reply(await handler.run({ token, params, now: new Date(), lang }), 200, json);
  } catch (err) {
    const refusal = refusalOf(err, params);
    return reply({ text: refusal.text(m), data: { error: refusal.status } }, refusal.status, json);
  }
});
