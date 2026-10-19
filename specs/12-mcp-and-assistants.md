# 12 — MCP & Assistant Integration (B4)

Implements FR-6.1 – FR-6.6. Decision context: [ADR-007](adr/ADR-007-assistant-integration.md);
both endpoints run as Supabase Edge Functions since [ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md).

Two separate things, on different timelines:

- **Today: Siri**, via Apple Shortcuts calling a REST endpoint. Works now, needs no
  native Siri code in the app, and about an hour of work.
- **Now and later: MCP**, so Claude or any other MCP-speaking assistant can read and act
  on family data on your behalf.

---

## Part 1 — Siri today, via Shortcuts

> **Built 2026-10-16 on `feature/shortcuts`, not yet on the server:** the `shortcuts` Edge
> Function, `app.shortcut_token` with Settings → Erweitert → Apps und KI-Assistenten (named "Siri und Kurzbefehle" until 2026-10-19), and every shortcut below
> except "Wann ist …" for a member's baseline (only presence entries are read). The contract is
> under [The endpoint as built](#the-endpoint-as-built); the family's guide is
> `docs/settings/shortcuts.md`.

Apple's Shortcuts app has a **Get Contents of URL** action that performs authenticated
HTTP requests, and any shortcut can be triggered by a spoken phrase. That is the whole
mechanism. The native app could register App Intents — with Swift code alongside
Flutter — but it does not need to: the shortcut talks to the API directly. App Intents
remain an M3+ option if a spoken phrase stops being enough.

**"Hey Siri, Einkaufsliste"**

1. Ask for Input (text) → "Was brauchst du?"
2. Get Contents of URL
   - `POST https://api.example.org/functions/v1/shortcuts/shopping`
   - Header `Authorization: Bearer <shortcut token>`
   - JSON body `{ "text": <Provided Input>, "id": <UUID> }`
3. Show Result → "Auf der Liste."

The server parses `text` leniently — "2 Liter Milch" yields quantity 2, unit `l`, item
"Milch" — and matches against the catalogue. Deliberately forgiving: this is dictated
speech, and rejecting an ambiguous item is worse than filing it imperfectly.

**Shortcuts worth building:** add to shopping list · what's on today · what's for dinner ·
mark a chore done · how many points do I have · **"Hat Mia morgen Sport?"** · **"Wann ist
Julia wieder da?"** — the last two are the questions actually asked out loud in this
household, which is a better selection criterion than what is easy to build.

**Security:** a dedicated token type, one per person, scoped to a small set of endpoints,
issued from settings and revocable there. The token lives in the shortcut on the device
(and syncs through iCloud, which is worth knowing). These tokens can add and read; they
cannot delete, cannot adjust points, and cannot manage anything.

Share the shortcut to each family member's phone via an iCloud link with their own token
substituted.

### The endpoint as built

*Added 2026-10-16.* `POST|GET <server>/functions/v1/shortcuts/<action>`, the key in
`Authorization: Bearer wws_…` (never in the URL). Parameters come from the query or a JSON body.
The answer is `text/plain` — one or two sentences for Show Result and Speak Text — or, with
`Accept: application/json` or `format=json`, `{ "text": …, …facts }`. The language is `lang`,
else Accept-Language, else the household's locale; the wording lives in
`_shared/shortcuts_de.ts` and `shortcuts_en.ts`.

| Action | Method | Parameters | Reads or writes |
|---|---|---|---|
| `shopping` | POST | `text` (dictation), `list?` (a list's name), `id?` (UUID: a replay is a no-op) | adds through `app.shopping_do_add`; amounts with a unit become the quantity, bare numbers the count |
| `today` | GET, POST | `day?` | appointments, meals and the holder's own tasks of the day |
| `meals` | GET, POST | `day?` | the day's meals and who cooks |
| `points` | GET, POST | – | the holder's balance |
| `chore` | POST | `text` | ticks one of the holder's open tasks (or an unassigned one a member may claim) through `app.tasks_do_complete`; a tie is asked back, no text lists them |
| `school` | GET, POST | `text` (the question) or `member?`, `subject?`; `day?` (default tomorrow) | the projected school day; weekends and holidays answered as such; the equipment line follows `school.equipment_hint` |
| `presence` | GET, POST | `text` or `member?` | presence entries of the next 30 days: away until when, or here and the next trip |

`day` is `heute`/`today`, `morgen`/`tomorrow`, `übermorgen`, a weekday (the next one, today
included) or `YYYY-MM-DD`; in a question the first such word counts. Names and subjects are
found in the question as whole words, folded like `app.fold`. No member named means the holder.

Server side: `api.shortcut_context(token, parts, from, days)` returns the rows of the api views
the app reads (events, overrides, imported occurrences, busy-until, the school projection's
rows and public holidays, meal entries, the holder's open tasks) narrowed to the key's
household, so `occurrences.ts` and `school.ts` run on them unchanged;
`api.shortcut_shopping_add` and `api.shortcut_task_complete` write. All three are executable by
the service role only and start with `app.shortcut_actor(token)`, which yields an actor with
origin and device class `shortcut`. Status codes: 401 for a key that does not work (unknown,
revoked, holder gone — one answer for all), 429 at the daily cap of 100 writes, 400/404 for
what the sentence then explains.

---

## Part 2 — the MCP server

> **Built 2026-10-16 on `feature/mcp-read` (phase 2, `family:read`), not yet on the server:** the
> `mcp` Edge Function at `<server>/functions/v1/mcp`, dual-era (revision `2026-07-28` with
> `server/discover`, per-request `_meta`, header validation, `resultType` and cache hints; the
> `initialize` handshake of `2025-03-26` to `2025-11-25` for clients not yet on the new
> revision), written by hand without the SDK: a stateless JSON-only server is small. All nine
> read tools below and the four resources. **Authorisation is the interim of
> [Q15](14-open-questions.md):** a per-person *assistant key* (`wwa_…`, adults only, issued
> in Settings → Erweitert → Apps und KI-Assistenten) as a bearer token instead of OAuth 2.1. Supabase Auth's
> OAuth 2.1 server is in public beta and runs self-hosted, but needs a login and consent screen
> on every family's server and a hook change for OAuth sessions; it comes with phase 3 and the
> write scopes. The key's actor has origin `mcp` and device class `assistant`, and
> `app.key_actor` refuses every write for it. Not built: per-grant rate limits at the proxy
> (reads are counted per key, not capped) and the guardian feed of assistant actions (there are
> no assistant actions yet).

### Protocol baseline

Target spec revision **`2026-07-28`**, the largest revision since MCP launched:

- **Stateless.** The `initialize`/`initialized` handshake and `Mcp-Session-Id` are gone,
  so any request can be served by any instance. For a single container this is mostly a
  simplification: no session store, no affinity.
- **Streamable HTTP** transport, with `Mcp-Method` and `Mcp-Name` headers so a proxy can
  route without reading bodies.
- **Hardened OAuth**: issuer validation per RFC 9207, OpenID Connect `application_type`
  declarations, explicit refresh-token guidance.
- Roots, Sampling and Logging are **deprecated** under a 12-month lifecycle policy —
  do not build on them.
- Extensions framework, including MCP Apps for server-rendered UI. Interesting later
  (a shopping list rendered inside an assistant), not v1.

Verify the final published spec and the TypeScript SDK's support level when you start
this module; it landed recently enough that SDK coverage is worth checking rather than
assuming. The server is an Edge Function (Deno), so also check that the SDK runs there —
a stateless protocol suits a function runtime well.

### Deployment and authorisation

```
https://<mcp host>/mcp              Streamable HTTP → nginx → the mcp Edge Function
```

WuselWall acts as the OAuth 2.1 authorisation server. Supabase Auth has been gaining
OAuth 2.1 server capabilities; confirm that the self-hosted version covers MCP's
requirements before committing ([Q15](14-open-questions.md)). The function forwards the
resulting user token to Postgres, so RLS and the `api` functions apply to assistant calls
exactly as to app calls. Flow: authorization code
with PKCE, a consent screen that names the assistant and the scopes, refresh tokens, and
a settings page listing active grants with a revoke button next to each.

**Scopes:**

| Scope | Grants |
|---|---|
| `family:read` | Agenda, tasks, meal plan, shopping list, point balances |
| `shopping:write` | Add and tick shopping items |
| `tasks:write` | Complete tasks, create one-off tasks |
| `calendar:write` | Create and update events |

`family:read` is the default. Each write scope is granted explicitly and separately.
There is no `*:delete` scope in v1 (FR-6.6) — an assistant that misunderstands "clear the
list" should not be able to act on it.

### Tools

Coarse-grained and verb-shaped. An assistant works far better with ten tools that match
intentions than forty that match database tables.

**Read**

| Tool | Arguments | Returns |
|---|---|---|
| `get_agenda` | `dateRange`, `member?` | Events and due tasks, resolved to names |
| `list_tasks` | `member?`, `status?`, `dateRange?` | Task instances with points and due dates |
| `get_meal_plan` | `dateRange` | Meals per date and slot, with cook |
| `get_shopping_list` | `listName?` | Open items, grouped by category |
| `get_points` | `member` | Balance, recent ledger entries, active streaks |
| `find_recipe` | `query` | Matching recipes with ingredients |
| `get_timetable` | `member`, `date` or `dateRange` | Lessons with times, rooms and any Entfall/Vertretung; Ferien answered as such |
| `get_presence` | `dateRange`, `member?` | Who is working, away or travelling, and who is at home |
| `get_week_board` | `weekOf?` | The wall display's week, as structured data — the single best "what's going on?" answer |

**Write**

| Tool | Arguments | Notes |
|---|---|---|
| `add_shopping_items` | `items[]`, `listName?` | Accepts natural phrasing; idempotent via a client-supplied key |
| `complete_task` | `taskId`, `member` | Fails clearly if already complete |
| `create_task` | `title`, `dueOn?`, `assignee?`, `points?` | One-off tasks only; no recurrence over MCP |
| `create_event` | `title`, `start`, `end`, `attendees?` | Times resolved in the household timezone |
| `set_meal` | `date`, `slot`, `description` or `recipeId` | Overwrites the slot |

**Resources** for cheap read-only context:
`family://agenda/today` · `family://shopping/current` · `family://meals/week` · `family://members`

**Design rules**

- Annotate correctly: `readOnlyHint`, `destructiveHint`, `idempotentHint`. Clients
  surface these to users, and getting them wrong erodes the consent model.
- Every tool takes an explicit `member` where the acting person is ambiguous. Never let
  the assistant guess who completed a chore.
- **Lessons are read-only over MCP, permanently.** There is no `set_lesson` and no
  `cancel_lesson`: an assistant that misunderstands "Mathe fällt aus" should not be able
  to rewrite a term's timetable. Entering a Vertretung takes two taps in the app.
- `create_event` sets `kind='appointment'` and `importance='normal'` always. Deciding what
  belongs on the kitchen wall is a human decision, and an assistant that could set it
  would eventually fill the display.
- Return **both** structured content and a short human-readable summary. The structured
  form is what an agent chains on; the text is what the user sees.
- Never expose bare UUIDs without a label. `{"id": "0192…", "title": "Empty the
  dishwasher"}` — an assistant that can only see the id will hallucinate names.
- Errors are informative and actionable: "No task named 'bins' due today; did you mean
  'Take out the bins', due tomorrow?"

### Attribution and audit

Every MCP call reaches the `api` functions with `origin = 'mcp'` and
`on_behalf_of = { principal, assistant }`, which `app.actor()` records ([03](03-architecture.md#the-acting-profile--actorcontext-in-sql)). The audit log therefore distinguishes "Papa ticked this off" from "Claude
ticked this off on Papa's behalf", and the UI can show a small assistant marker. When you
later find an event you do not remember creating, this is the difference between a mystery
and an answer.

### Rate limiting and safety

- Per-grant rate limits at the proxy.
- A daily cap on write operations per grant — an agent in a loop should hit a ceiling
  before it fills the shopping list with three hundred entries.
- `create_event` refuses to create more than a handful of events in one call.
- A guardian-visible feed of assistant actions in settings, filterable from the audit log.

---

## Rough sequencing

| Phase | Deliverable |
|---|---|
| Phase 1 | Shortcuts endpoints and tokens — a few hours, and immediately useful |
| Phase 2 | MCP server with `family:read` only. Safe to expose, genuinely handy for "what's on this week?" |
| Phase 3 | `shopping:write` and `tasks:write`, with the consent screen and grant management |
| Phase 4 | `calendar:write`; consider MCP Apps for an interactive shopping list inside the assistant |
