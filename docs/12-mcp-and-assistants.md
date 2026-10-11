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

Apple's Shortcuts app has a **Get Contents of URL** action that performs authenticated
HTTP requests, and any shortcut can be triggered by a spoken phrase. That is the whole
mechanism. The native app could register App Intents — with Swift code alongside
Flutter — but it does not need to: the shortcut talks to the API directly. App Intents
remain an M3+ option if a spoken phrase stops being enough.

**"Hey Siri, Einkaufsliste"**

1. Ask for Input (text) → "Was brauchst du?"
2. Get Contents of URL
   - `POST https://home.example.de/functions/v1/shortcuts/shopping/add`
   - Header `Authorization: Bearer <shortcut token>`
   - JSON body `{ "text": <Provided Input>, "clientUuid": <UUID> }`
3. Show Result → "Auf der Liste."

The server parses `text` leniently — "2 Liter Milch" yields quantity 2, unit `l`, item
"Milch" — and matches against the catalogue. Deliberately forgiving: this is dictated
speech, and rejecting an ambiguous item is worse than filing it imperfectly.

**Shortcuts worth building:** add to shopping list · what's on today · what's for dinner ·
mark a chore done · how many points do I have · **"Hat Mia morgen Sport?"** · **"Wann ist
Sabine wieder da?"** — the last two are the questions actually asked out loud in this
household, which is a better selection criterion than what is easy to build.

**Security:** a dedicated token type, one per person, scoped to a small set of endpoints,
issued from settings and revocable there. The token lives in the shortcut on the device
(and syncs through iCloud, which is worth knowing). These tokens can add and read; they
cannot delete, cannot adjust points, and cannot manage anything.

Share the shortcut to each family member's phone via an iCloud link with their own token
substituted.

---

## Part 2 — the MCP server

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
https://mcp.home.example.de/mcp     Streamable HTTP → Caddy → the mcp Edge Function
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
