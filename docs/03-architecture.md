# 03 — Architecture

## System shape

A **modular monolith**: one deployable web application containing all four domain
modules, plus a second small process for the MCP server, both talking to one
PostgreSQL database. A reverse proxy terminates TLS in front of them.

```
                     Internet (443 only)
                            │
                   ┌────────▼────────┐
                   │      Caddy      │  automatic TLS, security headers,
                   │  reverse proxy  │  rate limiting, static asset caching
                   └────┬───────┬────┘
                        │       │
          home.example.de     mcp.home.example.de
                        │       │
        ┌───────────────▼──┐  ┌─▼──────────────────┐
        │   apps/web       │  │   apps/mcp         │
        │   SvelteKit      │  │   MCP server       │
        │  ─────────────   │  │  Streamable HTTP   │
        │  UI (3 registers)│  │  OAuth 2.1         │
        │  /api  REST      │  │  read + write tools│
        │  /ics  feeds     │  └─────────┬──────────┘
        │  /events SSE     │            │
        │  web push        │            │
        └────────┬─────────┘            │
                 │                      │
                 └──────┬───────────────┘
                        │  imports
                ┌───────▼─────────┐
                │ packages/core   │  domain logic, Drizzle schema,
                │                 │  service functions, validation,
                │                 │  audit logging, authorisation
                └───────┬─────────┘
                        │
                ┌───────▼─────────┐        ┌──────────────────┐
                │  PostgreSQL 18  │◄───────┤ apps/worker      │
                │  (Docker net    │        │ pg-boss jobs:    │
                │   only, never   │        │ materialise      │
                │   exposed)      │        │ tasks, streaks,  │
                └───────┬─────────┘        │ reminders, feeds │
                        │                  └──────────────────┘
                ┌───────▼─────────┐
                │ nightly pg_dump │──► restic ──► off-site object storage (encrypted)
                └─────────────────┘
```

### Why a monolith and not services

Four modules that constantly reference each other — a meal generates shopping items, a
task appears on the calendar, a completed chore moves a point balance — would spend all
their time doing distributed transactions. One process, one database, one transaction
boundary. Deployment is `docker compose up -d`. See [ADR-002](adr/ADR-002-build-vs-assemble.md).

The MCP server is a separate process only because it has a different lifecycle and a
different authentication model; it shares the same `packages/core` and the same database
connection, so business rules are never duplicated.

## Technology stack

| Layer | Choice | Reasoning |
|---|---|---|
| Language | **TypeScript** (strict) | User decision. One language for UI, API, jobs and MCP server. |
| Frontend + BFF | **SvelteKit 2 / Svelte 5** | Small bundles matter on a cheap wall tablet; one file-based router for pages *and* API endpoints; a single `adapter-node` build that drops straight into a container. Fewer moving parts than the Next.js App Router for a solo maintainer. |
| Styling | **Tailwind CSS** + a small component set | The three UI registers are largely a matter of spacing and type scale — trivial with design tokens, tedious without. |
| Database | **PostgreSQL 18** | Recurrence maths, ledgers, `LISTEN/NOTIFY`, JSONB where useful, and a job queue — all in one dependency. |
| Query layer | **Drizzle ORM** | SQL-shaped, fully typed, migrations as plain SQL you can read. Avoids the "what query did the ORM just run" problem. |
| Validation | **Zod v4** | One schema per boundary, reused for API input, MCP tool schemas (JSON Schema 2020-12) and form validation. |
| Auth | **Better Auth** | Actively maintained self-hosted auth for TypeScript, with passkey and OIDC-provider plugins. Lucia, the previous default, was deprecated in 2025. The device-session and PIN layer sits on top as custom code. |
| Background jobs | **pg-boss** | Postgres-backed queue: no Redis, no extra container, jobs survive restarts and are visible in SQL. |
| Realtime | **Server-Sent Events** over `LISTEN/NOTIFY` | One-directional updates are all this app needs. SSE traverses proxies cleanly and reconnects on its own; WebSockets would be a bidirectional solution to a unidirectional problem. |
| Push notifications | **Web Push (VAPID)** via `web-push` | The only push channel available to an iOS PWA, and it is enough. |
| Recurrence | **`rrule`** | RFC 5545 is not a wheel worth reinventing; it is also exactly what the ICS feed must emit. |
| ICS generation | **`ical-generator`** | Correct escaping, folding and timezone handling. |
| MCP | **`@modelcontextprotocol/sdk`** (TypeScript) | Spec revision `2026-07-28`: stateless, Streamable HTTP, hardened OAuth. |
| Tests | **Vitest** (unit + integration) · **Playwright** (end-to-end) | Integration tests run against a throwaway Postgres in Docker — recurrence and ledger logic must be tested against the real database. |
| Container | **Docker Compose** | See [10](10-deployment-and-ops.md). |

### If you would rather use Next.js

Everything above holds except the frontend framework. Substitute Next.js 15+ with the
App Router, `next/server` route handlers for the API, and the standalone output mode
for Docker. You gain the largest ecosystem and the best AI code-generation coverage;
you pay in bundle size on the wall tablet and in framework surface area to keep in your
head. It is a defensible choice — just make it once and record it in [ADR-003](adr/ADR-003-technology-stack.md).

## Repository layout

A pnpm workspace monorepo:

```
goombawall/
├─ apps/
│  ├─ web/                  SvelteKit — UI, REST API, ICS feeds, SSE, push
│  ├─ mcp/                  MCP server (Streamable HTTP + OAuth)
│  └─ worker/               pg-boss job runner
├─ packages/
│  ├─ core/                 domain services, Drizzle schema + migrations,
│  │                        authorisation, audit log, Zod schemas
│  └─ ui/                   shared Svelte components and design tokens
├─ infra/
│  ├─ docker-compose.yml
│  ├─ Caddyfile
│  └─ backup/
└─ docs/                    copied from this planning folder once code starts
```

**The rule that keeps this maintainable:** `apps/*` may not contain business logic and
may not import Drizzle directly. They translate transport (HTTP request, MCP tool call,
scheduled job) into calls on `packages/core` services and translate the result back.
Every service function takes an explicit `ActorContext` (see below).

## Module boundaries

Inside `packages/core`, one folder per bounded context:

| Module | Owns | May read from | Never touches |
|---|---|---|---|
| `identity` | household, members, devices, sessions, PINs, audit log | — | anything |
| `calendar` | calendars, events, occurrences, feed tokens, the composed occurrence read model | `identity`, `school` (read-only, for projection) | tasks, meals |
| `school` | schools, bell times, terms, subjects, timetables, lessons, exceptions, holidays | `identity` | calendar, tasks, meals, shopping |
| `tasks` | task definitions, instances, points ledger, rewards, streaks, badges | `identity` | calendar, meals |
| `meals` | recipes, ingredients, meal plan entries | `identity` | tasks |
| `shopping` | lists, items, catalogue, store layouts | `identity`, `meals` (read-only, for generation) | tasks, calendar |

`school` is a *source*, not a peer: it never writes an event and never learns that a
calendar exists. `calendar.getOccurrences()` asks it for projected lessons for a window
and merges them with expanded events (see [05](05-module-calendar.md#occurrence-sources)).
The same seam takes imported ICS feeds in M2 and task due dates whenever they are wanted,
which is the reason to build it as composition rather than as a special case for school.

Cross-module effects go through **domain events**, not direct calls. "Meal plan
generated shopping items" is `meals` emitting `MealPlanCommitted` and `shopping`
subscribing. In v1 this is an in-process event bus with synchronous handlers inside the
same database transaction — not a message broker. It costs almost nothing now and means
the modules can be understood independently later.

## Cross-cutting concerns

### Actor context

Every service function's first parameter:

```ts
type ActorContext = {
  householdId: HouseholdId;
  actorProfileId: ProfileId;      // who is acting
  deviceId: DeviceId | null;      // null for jobs
  origin: 'ui' | 'api' | 'mcp' | 'shortcut' | 'job';
  guardianVerifiedUntil: Date | null;  // set by a successful PIN step-up
  onBehalfOf?: { principal: string; assistant: string };  // MCP/assistant calls
};
```

This single object drives authorisation, audit logging and assistant attribution.
Because it is a required parameter rather than ambient state, it is impossible to write
a service function that forgets who is calling it.

### Authorisation

Three layers, deliberately redundant:

1. **Household scoping.** Every table carries `household_id`. Every query filters on it,
   enforced by a repository helper rather than by discipline.
2. **Role and step-up checks** in the service layer: a guardian action throws unless
   `guardianVerifiedUntil` is in the future.
3. **PostgreSQL row-level security** as defence in depth, using a session variable set
   per transaction. With one household this is nearly free; it means an SQL-injection
   bug in one endpoint cannot read another household's data — and more usefully today,
   it catches missing `WHERE household_id` clauses in development.

### Audit log

Append-only, one row per mutation: actor, device, origin, entity type and id, action,
JSON diff, timestamp. Written inside the same transaction as the mutation. This is what
makes the points economy defensible ("I did do the dishes!") and what makes assistant
actions reviewable.

### Time and timezones

- Store all instants as `timestamptz` (UTC).
- Store the household timezone once (`Europe/Berlin`) and each recurring event's own
  IANA timezone, because a 07:00 recurring alarm must stay at 07:00 across a DST change.
- All-day events are stored as a date, never as a midnight timestamp. This is the single
  most common source of off-by-one-day bugs in calendar code.
- Never compute "today" on the client for anything that gets written.

### Error handling

Domain errors are typed values, not thrown strings: `Result<T, DomainError>` at service
boundaries, with HTTP status mapping in one place per app. The UI is written on the
assumption that any request can fail and any device can be offline.

### Observability

Structured JSON logs to stdout, collected by Docker. One self-hosted uptime check and
a nightly backup-success ping. No external APM — see NFR-9. If error tracking becomes
necessary, self-host GlitchTip rather than adopting a SaaS.

## Key data flows

### Adding a shopping item from a phone in a shop, offline

1. UI writes the item to IndexedDB and renders it immediately (optimistic).
2. A mutation record goes into an outbox queue with a client-generated UUID.
3. On reconnect, the service worker drains the outbox to `POST /api/shopping/items`,
   sending the client UUID as an idempotency key.
4. The server upserts by that key, so a retried request cannot create a duplicate.
5. Postgres `NOTIFY` → SSE → every other connected device updates.

### Ticking off a chore on the wall tablet

1. Tap avatar → active profile set for this interaction (device session already valid).
2. Tap task → `POST /api/tasks/instances/:id/complete` with the active profile.
3. Service: mark complete, append a point-ledger entry, recompute the streak, write the
   audit row, emit `TaskCompleted` — all in one transaction.
4. `NOTIFY` → SSE → the child's iPad shows the new balance; a badge animation fires if
   `BadgeAwarded` was emitted.

### The kitchen display rendering a week

1. The kiosk requests `GET /api/board/week?from=…` — **one** endpoint, not four.
2. `packages/core` composes it in a single transaction: expanded events filtered to
   `importance='key'` and `kind='presence'`, projected school days from `school`, meal
   entries with their attendees, and per-member open-task counts.
3. The response is shaped exactly as the board renders it — seven day objects, each with
   the same four zones — so the client does no merging and no date arithmetic. A wall
   display that computes "which lessons fall on Wednesday" in the browser is a wall
   display that will be subtly wrong twice a year, at the DST boundaries.
4. SSE pushes an invalidation on any change to an event, timetable, holiday, meal entry or
   task instance; the board refetches the whole week, because it is small and merging
   deltas on a device nobody debugs is not worth the risk.

### Outlook seeing a new family event

1. Event created in the UI → stored in Postgres.
2. Outlook requests `GET /ics/{token}.ics` on its own schedule (every 3–24 hours).
3. The endpoint renders the subscriber's filtered event set, honours `If-None-Match`
   with an ETag derived from the household's latest event revision, and returns 304 when
   nothing changed.
4. The event appears in Outlook — eventually. Anything urgent goes out as a web push in
   parallel, because the ICS path is not a notification channel. See [05](05-module-calendar.md).
