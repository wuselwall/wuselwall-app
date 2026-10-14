# 03 — Architecture

*Rewritten 2026-10-11 for Flutter clients on a self-hosted Supabase backend —
[ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md). The TypeScript/SvelteKit
architecture it replaces is recorded in [ADR-003](adr/ADR-003-technology-stack.md).*

## System shape

**One Flutter codebase** producing native apps for iOS/iPadOS and Android plus a web
build, talking to **one self-hosted Supabase stack** on the home server
([ADR-013](adr/ADR-013-one-self-hosted-environment.md)). PostgreSQL is the domain core:
tables, rules, authorisation and audit all live in it. A small number of Edge Functions
handle what SQL does badly. Cloudflare terminates TLS at the edge, and the home server's
nginx forwards only the API paths.

```
   iPhones · iPads            wall tablet (Android)          laptop browser
   Flutter iOS app            Flutter Android app            Flutter web build
          │                          │                              │
          └──────────────┬───────────┴──────────────────────────────┘
                         │ HTTPS 443 only
                ┌────────▼─────────┐
                │ Cloudflare proxy │  TLS at the edge, hides the home address
                └────────┬─────────┘
                         │ HTTPS (origin certificate), router → home server
                ┌────────▼─────────┐
                │      nginx       │  path allow-list, WebSocket upgrade
                └───┬──────────┬───┘
api.wuselwall.app │          │  MCP host (M2)
   /auth/v1 /rest/v1│          │
   /realtime/v1     │          │
   /functions/v1    │          │
   /ics/* (M1.3a)   │          │
                ┌───▼──────────▼───┐
                │  Kong (gateway)  │  Supabase's API gateway, key checks
                └─┬────┬────┬────┬─┘
                  │    │    │    │
        ┌─────────▼┐ ┌─▼────┴──┐ ┌▼──────────┐ ┌──────────────────┐
        │  Auth    │ │PostgREST│ │ Realtime  │ │  Edge Functions  │
        │ (GoTrue) │ │ api.*   │ │ broadcast │ │  (Deno, TS)      │
        │ devices, │ │ views + │ │ household │ │  board-week, ics,│
        │ guardians│ │ RPC     │ │ channels  │ │  enrol-device …  │
        └────┬─────┘ └────┬────┘ └─────┬─────┘ └────────┬─────────┘
             └────────────┴───────┬────┴────────────────┘
                         ┌────────▼─────────┐
                         │   PostgreSQL     │  schema app: tables + RLS
                         │  (Supabase image)│  schema api: views + functions
                         │  Docker net only │  pg_cron · pg_net · pgcrypto
                         └────────┬─────────┘
                         ┌────────▼─────────┐
                         │ nightly pg_dump  │──► restic ──► off-site storage (encrypted)
                         └──────────────────┘

   Studio (admin UI) runs on the server but is never proxied by nginx —
   reachable only on the home network.
```

### Why the database is the core

Four modules that constantly reference each other — a meal generates shopping items, a
chore moves a point balance — need one transaction boundary. In the TypeScript plan that
boundary was a service layer in `packages/core`. With Supabase the natural boundary is
PostgreSQL itself: **one `api` function call is one transaction**, and everything that
must happen together happens inside it. See
[ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md#decision) for the alternatives.

The client is deliberately thin. It renders, caches and — for the shopping list only —
queues. It holds no business rules.

## Technology stack

| Layer | Choice | Reasoning |
|---|---|---|
| Client | **Flutter** (stable, pinned) | User decision. One codebase for iOS, iPadOS, Android and web; native rendering on a cheap wall tablet; real push and kiosk mode. |
| State and navigation | **Riverpod** · **go_router** | The most common pairing in current Flutter code; compile-time-safe providers; declarative routes that can switch per UI register. |
| Models | **freezed** + `json_serializable` | Immutable value types and JSON mapping without hand-written boilerplate. |
| Offline store | **drift** (SQLite) | The shopping list's mirror and outbox ([07](07-module-meals-shopping.md#offline--the-one-place-it-is-non-negotiable)). Typed queries, migrations, reactive streams. |
| Secrets on device | `flutter_secure_storage` | Keychain on iOS, Keystore-backed on Android — where the device session lives. |
| Localisation | Flutter **gen-l10n**, ARB files | German and English, always both (NFR-14); generated, type-safe message accessors. |
| Backend platform | **Supabase, self-hosted only**: the Unraid stack for the family, and any household's own stack (or own Supabase project) for everyone else | User decision. Auth, a REST layer, realtime and functions around PostgreSQL. `supabase/` is the server release other families install; the store app has no default backend ([ADR-018](adr/ADR-018-self-hosted-only.md), replacing ADR-015's Cloud). |
| Database | **PostgreSQL** (the version Supabase's image ships — pin the tag) | Recurrence ranges, ledgers, arrays, `pg_trgm` for shopping capture, `pg_cron` for jobs. |
| Domain logic | **SQL and PL/pgSQL** in the `api` schema | Transactional writes, guardian checks and audit in one place. |
| Authorisation | **Row-level security**, forced on every table | The primary control: the anon key ships in every app. |
| Auth | **Supabase Auth** (GoTrue) + a custom access-token hook | Adult accounts (Sign in with Apple, Google, email code, password; [ADR-014](adr/ADR-014-self-service-onboarding.md)) and per-device users; household and device in the JWT. A send-email hook localises auth mail. |
| Composed reads, public endpoints | **Supabase Edge Functions** (Deno, TypeScript) | RFC 5545 via `rrule`, the timetable projection, ICS output via `ical-generator`, device enrolment, the send-email hook, account deletion with Apple token revocation; later MCP and Shortcuts. |
| Background jobs | **pg_cron**, with **pg_net** to invoke Edge Functions | No worker container. Jobs and their history are visible in SQL. |
| Realtime | **Supabase Realtime**, broadcast from triggers on a private per-household channel | Invalidations, not data: the client refetches. |
| Push | **FCM** (Android) and **APNs** (iOS), sent from an Edge Function | Native push channels; provider choice is [Q38](14-open-questions.md). |
| Tests | Dart `test`/`flutter_test` · **pgTAP** via `supabase test db` · `deno test` | Domain rules and RLS are tested against a real database, always. |
| CI/CD | **GitHub Actions**, **fastlane** for signing and upload | [ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md), [16](16-setup-plan.md). |

## Repository layout

```
wuselwall/
├─ app/                        Flutter — iOS, Android, web
│  ├─ lib/
│  │  ├─ main.dart
│  │  ├─ app/                  bootstrap, router, theme per UI register, l10n wiring
│  │  ├─ core/                 Supabase client, device session, acting profile,
│  │  │                        error mapping, realtime, connectivity
│  │  └─ features/
│  │     ├─ setup/  devices/  shopping/  tasks/  calendar/  school/  meals/  board/
│  │     │   each: data/ (repository: api views + RPC)  domain/ (models)  ui/
│  ├─ l10n/app_en.arb  app_de.arb   every user-facing string, in both languages
│  ├─ test/                    unit and widget tests
│  ├─ integration_test/        on-device flows (later)
│  ├─ env/                     dev.json (api.wuselwall.app), ci.json — --dart-define-from-file
│  ├─ android/  ios/  web/     platform shells; fastlane/ inside android/ and ios/
├─ supabase/
│  ├─ config.toml              local stack configuration (Supabase CLI)
│  ├─ migrations/              timestamped plain SQL — schema, RLS, api functions
│  ├─ functions/
│  │  ├─ _shared/              recurrence, timetable projection, auth, German strings
│  │  ├─ enrol-device/  board-week/  ics/  health/
│  │  └─ (later) push-send/  materialise-tasks/  shortcuts/  mcp/
│  ├─ tests/                   pgTAP: one file per module, RLS tests for every table
│  └─ seed.sql                 a development household
├─ infra/
│  ├─ nginx/                   the wuselwall.app site file for the home server's nginx
│  ├─ web/                     compose project for the website container (ADR-016)
│  └─ backup/                  backup.sh, restore-drill.sh (run on the home server)
├─ website/                    Astro site: landing page, Impressum, Datenschutz (ADR-016)
├─ scripts/                    remote-web / remote-stack / -migrate / -pgtap / -backup / -setup-token
├─ .github/workflows/          ci.yml, release-mobile.yml
├─ specs/                      the specification (this folder)
└─ docs/                       the end-user documentation (VitePress)
```

**The rules that keep this maintainable:**

- **PostgREST exposes only the `api` schema.** Tables live in `app` and are unreachable
  from any client. Reads go through `api` views declared `security_invoker`, so the
  caller's RLS applies; writes go through `api` functions.
- **One write use case, one `api` function.** `api.complete_task(p_actor, p_instance)`,
  not an UPDATE from Dart. The function validates, mutates, writes the audit row and
  emits the realtime invalidation in one transaction.
- **The Flutter app contains no business rules.** Feature repositories translate between
  Dart models and `api` calls; widgets never call Supabase directly.
- **Edge Functions never bypass RLS for user requests.** They forward the caller's JWT.
  The service-role key is used only by functions with no user (ICS, enrolment, jobs)
  and by the account-administration functions of [ADR-014](adr/ADR-014-self-service-onboarding.md)
  (`account-delete`, MFA reset), which verify the caller's JWT before acting on that one account,
  and each such use is commented with why. Added 2026-10-14: the on-demand holiday cache
  refresh (`holidays-sync`, called with a member's JWT when a country is picked) uses the
  service role only to write the public holiday cache, which holds no household data
  ([15](15-module-school-timetable.md#holidays)).
- **Public reference data** (regions and holiday feed rows, see [04](04-data-model.md#holiday-reference-data))
  is readable by any session on a live device and by nobody else; a revoked device reads nothing.
  Nothing household-specific lives there, and only the holiday sync writes it.

## Module boundaries

The same six bounded contexts as before, now expressed as groups of tables, views and
functions in the database (prefixed by module: `app.shopping_item`,
`api.shopping_add_item`) plus the matching `features/` folder in the app:

| Module | Owns | May read from | Never touches |
|---|---|---|---|
| `identity` | household, members, devices, PINs, audit log | — | anything |
| `calendar` | calendars, events, occurrences, feed tokens, the composed occurrence read model | `identity`, `school` (read-only, for projection) | tasks, meals |
| `school` | schools, bell times, terms, subjects, timetables, lessons, exceptions, holidays | `identity` | calendar, tasks, meals, shopping |
| `tasks` | task definitions, instances, points ledger, rewards, streaks, badges | `identity` | calendar, meals |
| `meals` | recipes, ingredients, meal plan entries | `identity` | tasks |
| `shopping` | lists, items, catalogue, store layouts | `identity`, `meals` (read-only, for generation) | tasks, calendar |

`school` is a *source*, not a peer: it never writes an event and never learns that a
calendar exists. The calendar's occurrence read model (an Edge Function using the shared
recurrence code) asks it for projected lessons for a window and merges them with expanded
events (see [05](05-module-calendar.md#occurrence-sources)). The same seam takes imported
ICS feeds in M2.

Cross-module effects stay inside one transaction: "meal plan generated shopping items" is
`api.meals_commit_plan` calling the shopping module's internal function
(`app.shopping_add_generated`), not a client making two calls. Internal functions live in
`app` and are not callable from outside.

## Cross-cutting concerns

### The acting profile — ActorContext in SQL

Every `api` write function establishes who is acting before it does anything else:

```sql
-- first line of every api write function
v_actor := app.actor(p_actor_profile_id);   -- raises if not usable on this device
```

`app.actor()` reads the JWT claims — `household_id`, `device_id`, `device_class` — set by
the access-token hook, then:

- on a `personal` device, ignores the parameter and uses the device's bound profile;
- on a `shared` or `kiosk` device, checks that the requested profile belongs to the
  household and is active;
- refuses outright if the device has been revoked;
- returns a record with household, profile, device, `origin` and
  `guardian_verified_until`, which the rest of the function uses for checks and audit.

`origin` is `ui` for app calls; Edge Functions acting for Shortcuts, MCP or jobs pass
`shortcut`, `mcp` or `job` along with `on_behalf_of`. Because the actor is the first thing
established and the audit row needs it, it is impossible to write a mutation that forgets
who is calling.

### Authorisation

Three layers, and since ADR-010 the database ones carry the weight:

1. **Row-level security on every `app` table**, with `FORCE ROW LEVEL SECURITY` so it
   also binds the role that owns the `api` functions. Every policy checks the JWT's
   household and that the calling device is not revoked. RLS is the control that stands
   between the public anon key and the family's data.
2. **Role and step-up checks** inside `api` functions: `app.require_guardian(v_actor)`
   raises unless `guardian_verified_until` is in the future or the caller is a guardian
   on their own personal device.
3. **Schema exposure**: only `api` is reachable; `app`, `auth` and everything else are not
   in PostgREST's exposed schemas, and Studio is never published.

Hiding a button in Flutter is a courtesy, never a control.

### The service-role key

Added 2026-10-14, so that the exceptions have one place to point to. The service-role key is
used by Edge Functions that have no user (ICS feeds, enrolment, jobs such as `holidays-sync`'s
weekly run), and by the two account-administration functions of ADR-014. The one exception
inside a user request is the on-demand holiday cache refresh: it verifies the member's JWT,
and the service role writes only the public cache. Each use names its reason in a comment.

### Audit log

Append-only, one row per mutation: actor, device, origin, entity type and id, action,
JSON diff, timestamp. Written by `app.audit()` inside the same transaction as the
mutation. No role has `UPDATE` or `DELETE` on the table.

### Time and timezones

- Store all instants as `timestamptz` (UTC).
- Store the household timezone once (`household.timezone`, e.g. `Europe/Berlin`) and each recurring event's own
  IANA timezone, because a 07:00 recurring alarm must stay at 07:00 across a DST change.
- All-day events are stored as a date, never as a midnight timestamp. This is the single
  most common source of off-by-one-day bugs in calendar code.
- Never compute "today" on the client for anything that gets written. `api` functions use
  `now() at time zone household.timezone`.

### Error handling

`api` functions raise domain errors with a stable code as the message (`WW-SHOP-001`)
and any parameters as JSON in `DETAIL`; unexpected errors keep their native `SQLSTATE`.
The app maps codes to
typed failures in one place (`core/errors.dart`) and failures to German messages through
ARB — never by showing a database message to a family member. Repository methods return
a `Result<T, Failure>`; widgets are written on the assumption that any call can fail and
any device can be offline.

### Observability

Structured logs from every container to Docker's json-file driver with rotation. One
uptime check on `/functions/v1/health` and a nightly backup ping. No external APM and no
crash-reporting SDK in the app (NFR-9) — iOS crash reports come from TestFlight, Android
ones from Play Console's vitals, both already part of the distribution path. If error
tracking becomes necessary, self-host GlitchTip.

## Key data flows

### Adding a shopping item from a phone in a shop, offline

1. The repository writes the item to the local drift database and the UI shows it
   immediately (optimistic).
2. An outbox row is written with a client-generated UUIDv7.
3. When connectivity returns — or the app resumes — the outbox drains in order to
   `api.shopping_apply(p_actor, p_ops)`, the client UUIDs serving as idempotency keys.
4. The function upserts by those keys, so a replayed batch cannot duplicate anything,
   and returns the authoritative rows, which replace the local ones.
5. A trigger broadcasts `shopping:changed` on the household channel; every other open
   client refetches the list.

### Ticking off a chore on the wall tablet

1. Tap avatar → acting profile set in app state for this interaction.
2. Tap task → `api.complete_task(p_actor, p_instance_id)`.
3. In one transaction: mark complete, append the point-ledger entry, recompute the
   streak, award any badge, write the audit row, broadcast `tasks:changed`.
4. The child's iPad refetches and shows the new balance; the badge animation fires if
   the function returned an awarded badge.

### The kitchen display rendering a week

1. The kiosk calls the `board-week` Edge Function with its JWT — **one** call, not four.
2. The function reads events, presence, timetable, holidays, meals and open-task counts
   through `api` views (RLS applies), expands recurrences and projects school days with
   the shared `_shared/` code, and composes the result.
3. The response is shaped exactly as the board renders it — seven day objects, each with
   the same four zones — so the client does no merging and no date arithmetic. A wall
   display that computes "which lessons fall on Wednesday" on the device is one that will
   be subtly wrong twice a year, at the DST boundaries.
4. Any change to an event, timetable, holiday, meal or task broadcasts `board:changed`;
   the board refetches the whole week, plus a full refetch every five minutes as a belt
   and braces.

### Outlook seeing a new family event

1. Event created in the app → `api.calendar_save_event` → stored.
2. Outlook requests `GET /ics/{token}.ics` on its own schedule (every 3–24 hours). nginx
   rewrites it to the `ics` Edge Function.
3. The function looks the token up by hash with the service role, renders the
   subscriber's filtered event set, and honours `If-None-Match` with an ETag derived from
   the household's latest event revision.
4. The event appears in Outlook — eventually. Anything urgent goes out as a push in
   parallel, because the ICS path is not a notification channel. See [05](05-module-calendar.md).
