# ADR-010 — Flutter clients on a self-hosted Supabase backend

**Status:** Accepted · 2026-10-11 · Supersedes [ADR-003](ADR-003-technology-stack.md);
amends [ADR-004](ADR-004-identity-model.md), [ADR-005](ADR-005-hosting.md),
[ADR-006](ADR-006-offline-strategy.md) and [ADR-007](ADR-007-assistant-integration.md)
in their implementation, not in their intent. Amended by
[ADR-013](ADR-013-self-hosted-compose-stack.md) (one self-hosted stack, no separate dev
and prod; further tenants on hosted Supabase) and [ADR-014](ADR-014-self-service-onboarding.md)
(public sign-up for adults, self-service households, device pairing) and
[ADR-015](ADR-015-saas-and-self-hosted-flavours.md) (a hosted *WuselWall Cloud* next to the
self-hosted flavour).

**Amended 2026-10-17 ([00](../00-brief-and-decisions.md#2026-10-17--social-sign-in-removed)):** the auth deep link `ch.goomba.wuselwall://login-callback/` below is no longer registered in the apps or allow-listed in `additional_redirect_urls`: it served social sign-in, which was removed. The identifier `ch.goomba.wuselwall` stands.

## Context

ADR-003 chose TypeScript end to end: a SvelteKit PWA, Drizzle, Better Auth and pg-boss on
plain PostgreSQL. On 2026-10-11 the user changed two things:

- The clients are to be **native apps on Android and iOS**, built from one Flutter
  codebase, rather than a PWA.
- The backend is to be **Supabase, self-hosted in Docker**, rather than a hand-built
  Node application server.

Neither change touches the problem being solved — the vision, the modules, the
requirements and the household are unchanged. What changes is where the code lives and
which parts are bought rather than built.

ADR-005 had rejected "Supabase or Firebase" outright, but the objection was to the
**hosted** service: family data held by a US cloud provider. Self-hosting removes that
objection completely. Supabase's Docker stack runs on the same German VPS, the data never
leaves it, and no Supabase-the-company service is contacted at runtime. *(Since
[ADR-013](ADR-013-self-hosted-compose-stack.md): a server at home instead of a VPS.)*

## Decision

### Clients

- **Flutter** (current stable, pinned) for **iOS/iPadOS, Android and web** from one
  codebase. Native builds for the parents' iPhones, the children's iPads and the wall
  tablet; the web build serves the work-laptop browser.
- `supabase_flutter` as the only backend client. **Riverpod** for state, **go_router** for
  navigation, **freezed**/`json_serializable` for models, **drift** (SQLite) for the
  shopping list's offline mirror and outbox, `flutter_secure_storage` for the device
  session, Flutter's own `gen-l10n` with ARB files for German and English.

### Starting point and identifiers

*Added 2026-10-11, after the first scaffold.*

- **The app started from Supabase's official starter**, `examples/user-management/
  flutter-user-management` (the Flutter starter in Supabase's library). It was
  sparse-cloned, then adapted: the Flutter app lives in `app/`, the starter's Supabase
  project (`config.toml`, migrations, seed) in the root `supabase/`, as the repository
  layout in [03](../03-architecture.md#repository-layout) prescribes. Dart package name
  `wuselwall`.
- **The starter is scaffolding, not architecture.** Its `public.profiles` table, direct
  table access from the client and `avatars` bucket contradict the decision below
  (tables in `app`, clients only touch `api`). They exist to prove the wiring — magic-link
  sign-in, a round trip to the database — and are replaced by the setup-plan migrations
  ([16](../16-setup-plan.md)). Do not build features on them.
- **Application ID, bundle ID and URL scheme are all `ch.goomba.wuselwall`** (chosen by the
  user on 2026-10-11, replacing `ch.wuselwall.app` before any store record existed): Android
  `applicationId`/`namespace` and Kotlin package, iOS `PRODUCT_BUNDLE_IDENTIFIER`, and the
  auth deep link `ch.goomba.wuselwall://login-callback/`, which is also listed in
  `supabase/config.toml` under `additional_redirect_urls`. The identifier is permanent
  once an app is registered with Apple and Google, so it is fixed now, before the first
  store record exists. Display name: `WuselWall`.
- **Configuration** is `--dart-define-from-file=env/<name>.json` (`dev.json`, git-ignored, for a
  development build's server, `ci.json` for CI's throwaway stack, `store.json` for store
  builds without a server; no `prod.json`, see ADR-013 and ADR-018), holding only public values: `ENV`, `SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`. The starter's `flutter_dotenv` and `.env` were removed. The
  client is initialised with `publishableKey` (the starter's `anonKey` is deprecated in
  `supabase_flutter`), the default PostgREST schema `api`, and the session persisted in
  `flutter_secure_storage`.
- **The starter's demo pages and migration are already gone**: `supabase/migrations`
  starts with the `app`/`api` schemas and `api.health()`; public sign-up is disabled and
  only `api` is exposed in `supabase/config.toml`.

### Localisation: English and German, always both

*Amended 2026-10-11 — this replaces "German only" in the original decision and in
NFR-14.*

- **Two locales are shipped: German (`de`) and English (`en`).** Every user-facing string
  is written in both, in the same change that introduces it. A string with only one
  translation is incomplete work.
- **German is the default.** `supportedLocales` lists `de` first, so any device locale
  that is neither falls back to German; the app follows the device language otherwise.
- Flutter `gen-l10n`: `app/l10n/app_en.arb` (template, carries the `@key` descriptions)
  and `app/l10n/app_de.arb`, configured in `app/l10n.yaml`, generated into
  `app/lib/l10n/generated/` and committed. Widgets read strings through
  `context.l10n`; no literal is shown to a user.
- The same rule applies to server-produced text (push notifications, ICS summaries,
  MCP and Shortcuts responses): one message file per language in
  `supabase/functions/_shared/`, language chosen from the recipient's profile.
- Code, comments and documentation remain English.

### Backend

The **database is the domain core.** What `packages/core` was to the TypeScript plan,
PostgreSQL itself now is:

| Concern | Where it lives |
|---|---|
| Tables | Schema `app` — never exposed through the API |
| Reads | Schema `api` — `security_invoker` views, so RLS applies to the caller |
| Writes | Schema `api` — one Postgres function per use case, one transaction per call |
| Authorisation | Row-level security on every `app` table, `FORCE`d so it binds the function owner too, plus explicit guardian checks inside write functions |
| Audit | Written by every `api` write function, in the same transaction |
| Composed reads that need RFC 5545 recurrence | **Edge Functions** (Deno, TypeScript, `rrule`) called with the user's JWT, so RLS still applies |
| Public non-JWT endpoints | Edge Functions: ICS feed, device enrolment; later Shortcuts and MCP |
| Scheduled jobs | `pg_cron` for SQL jobs; `pg_cron` + `pg_net` invoking an Edge Function for the rest |
| Live updates | Supabase **Realtime** broadcast on a private per-household channel, sent from database triggers |
| Identity | Supabase **Auth** (GoTrue), with the device-session model layered on top — see below |
| File storage | Supabase Storage, only if and when avatars or recipe photos need it |

PostgREST exposes **only** the `api` schema. A client cannot address a table, so a client
cannot bypass a business rule — the same guarantee the old "apps may not import Drizzle"
rule gave, now enforced by configuration instead of by code review.

### Identity on Supabase Auth

ADR-004's two-layer model is kept exactly; only the mechanism changes.

- **Public sign-up is disabled.** No one can create an account from outside.
  *Reversed by [ADR-014](ADR-014-self-service-onboarding.md): adults sign up with Apple,
  Google, an email code or a password; a new account sees nothing until it creates or
  joins a household.*
- **Guardians** are Supabase Auth users (email + password, TOTP as the second factor;
  passkeys if Supabase Auth offers them when M0.1 is built), created by the setup wizard.
  *Since ADR-014: they create their own account; the setup wizard and its token give way
  to household creation in `code` or `open` mode.*
  A guardian's own phone is signed in as that guardian — a `personal` device.
- **Shared and kiosk devices** are enrolled with the one-time code from ADR-004. The
  `enrol-device` Edge Function validates the code, creates a dedicated Auth user for that
  device and returns its session. The device keeps its refresh token in the platform's
  secure storage and never sees a password.
- A **custom access-token hook** adds `household_id`, `device_id` and `device_class` to
  every JWT, so RLS policies read them without a lookup.
- **Revocation** sets `device.revoked_at` and signs the Auth user out everywhere. Every RLS
  policy also checks that the calling device is not revoked, so a revoked device loses
  access on its very next request, not at token expiry.
- **The acting profile** on shared and kiosk devices is an explicit parameter of every
  `api` write function, validated against the household — the SQL equivalent of
  ADR-003's `ActorContext`.
- **The guardian PIN** is checked by an `api` function (bcrypt via `pgcrypto`; the
  lockout, not the hash, is the real control for a six-digit PIN) and sets
  `guardian_verified_until` on the device row, server-side.

### Implementation notes (M0.1/M0.2, 2026-10-11)

Where the first implementation departs from, or narrows, the decision above:

- **Setup, enrolment and revocation are SQL, not Edge Functions.** `api.setup_household`,
  `api.enrol_device` and `api.devices_revoke` are `SECURITY DEFINER` functions. They create
  Auth users by writing `auth.users`/`auth.identities` directly (`app.create_auth_user`) and
  revoke by deleting the user's `auth.sessions`. Reason: one transaction per call, no extra
  runtime, and Edge Functions cannot be served from a remote Docker host (their source is
  bind-mounted). The Edge Function route stays open for what SQL does badly.
- **A new device receives throwaway credentials once.** `enrol_device` returns an
  email/password for the device's Auth user; the app signs in once and keeps only the
  session. The device never has a password a human knows, but it does briefly hold one,
  which is a small step back from "never sees a password".
- **Setup is guarded by `app.setup_token`**, a hashed one-time token (dev seed: `dev-setup`;
  production prints a random one at deploy time) and closes permanently once a household
  exists.
- **Personal devices are per phone** (migration `…150000`). A personal `app.device` row is
  bound to an Auth *session* (`auth_session_id`); shared and kiosk devices still own their
  Auth user. After a guardian signs in on a phone the session has no device yet, so the app
  shows "name this device" and calls `api.register_personal_device`, then refreshes the
  session so the token carries the claims. The access-token hook matches a personal device
  by the `session_id` claim. Revoking a phone deletes only that session; signing out marks
  the device revoked first (`api.device_sign_out`) so the list stays tidy. `api.setup_household`
  no longer creates a device.
- **TOTP is enforced by the access-token hook.** A guardian with a verified TOTP factor gets
  no `household_id`/`device_id` claims until the session is `aal2`, so at `aal1` RLS shows
  nothing and every write is refused — the check is server-side, not just a screen in the
  app. The app routes to a code page while `getAuthenticatorAssuranceLevel()` says
  `aal1 → aal2`. TOTP is optional per guardian (Settings → Security). Enrolment happens
  with Auth's own MFA API; the QR code is drawn from the `otpauth://` URI on the device.
- **Enrolment rate limiting:** `api.enrol_device` logs failed attempts in
  `app.enrol_attempt` and refuses after 5 failures per client (`X-Forwarded-For`, else one
  shared bucket) or 30 overall in 10 minutes. It now *returns* `{ok:false, reason}` instead
  of raising, because a raise would roll the attempt log back.
- **QR code for enrolment:** the enrolment dialog shows `wuselwall://enrol?code=…`; the new
  device scans it (`mobile_scanner`) or the code is typed. Parsing accepts only the exact
  scheme or an 8-character code.
- **Passkeys (Supabase beta) are wired but unverified on hardware.** Auth `v2.197` has them
  behind `passkeys_enabled` (on in `config.toml`, RP id `localhost` for local web). The app
  registers one in Settings → Security and offers "Sign in with passkey", through
  `supabase_flutter` and the `passkeys` plugin. A real ceremony needs an authenticator and,
  on phones, the platform association with the production domain (iOS Associated Domains,
  Android Digital Asset Links, the web SDK script) — none of which exists before M1.6, so
  the flow has not been exercised. Treat it as a skeleton.
- **Still open:** guardians created after setup (only members can be added in Settings;
  *answered by ADR-014's invitations*);
  per-IP rate limiting is only as good as the proxy's `X-Forwarded-For`.
- **RLS caveat:** in Supabase the `postgres` role carries `BYPASSRLS`, so `FORCE ROW LEVEL
  SECURITY` does not bind the function owner. Every `api` write function therefore
  establishes the actor (`app.actor`) and filters by household explicitly; RLS protects the
  views clients read. pgTAP covers the cross-household and revoked-device cases.
- **Realtime:** `app.broadcast()` sends an empty-payload `invalidate` event on the private
  channel `household:<id>`; `realtime.messages` has a select policy limiting listeners to
  their own non-revoked household. The Dart callback receives the whole envelope
  (`message['payload']['topic']`).

## Alternatives considered

**Keep ADR-003 and wrap the PWA with Capacitor for the stores.** The least rework, and it
would produce store-installable apps. Rejected because the user wants native apps and a
Flutter codebase, and because a wrapped PWA inherits WebView limitations on the very
devices — a cheap wall tablet and children's iPads — where native rendering matters most.

**Flutter on the planned TypeScript backend.** Keeps the hand-built server and its typed
service layer. Rejected: the user chose Supabase, and the custom server's main jobs —
auth, a REST layer, realtime, a job runner — are exactly what Supabase provides already.

**Hosted Supabase (supabase.com).** Least operational work. Rejected for the same reason
ADR-005 gave: it puts a household's data with a US-headquartered provider (NFR-8).
*Amended by ADR-013 and ADR-018:* not the project's choice, but a household may choose its
own hosted project — so `supabase/` must stay portable to a hosted project.

**Firebase / Appwrite / PocketBase.** Firebase is not self-hostable. Appwrite is, but its
document model gives up the relational data, `rrule`-style range queries and the
ledger maths this design relies on. PocketBase is SQLite-based and lightweight, but has no
row-level security, no `pg_cron` and a much smaller ecosystem for Flutter. Supabase keeps
PostgreSQL — the strongest part of the original plan.

**Domain logic in Edge Functions rather than in Postgres functions.** Familiar
TypeScript, easier to unit-test. Rejected for writes: an Edge Function talking through
PostgREST cannot wrap "complete a task, credit the points, update the streak, write the
audit row" in one transaction, and opening a direct database connection from each
function bypasses the pooling and RLS the rest of the stack relies on. Edge Functions are
kept for what SQL does badly: RFC 5545 expansion, the timetable projection, ICS output
and outbound HTTP.

**Direct table access from the client with RLS.** Supabase's default style, and less SQL
to write. Rejected because business rules would scatter across client code, policies and
triggers; one `api` function per use case keeps them in one reviewable place.

**PowerSync or Supabase-native offline sync.** Rejected for the reasons in
[ADR-006](ADR-006-offline-strategy.md), which still hold: offline is needed for one
module, and a bespoke outbox for one module is smaller than a sync engine for all of them.

## Consequences

**Positive**

- Native apps on every device, with real push, a real kiosk mode on Android, no storage
  eviction and no "add to home screen" instructions.
- Auth, realtime, a REST layer and scheduled jobs come out of the box, reducing the
  backend code to schema, policies, functions and a few Edge Functions.
- PostgreSQL remains the source of truth, so the data model in [04](../04-data-model.md),
  the RLS design and the backup story all carry over.
- Supabase's CLI runs the identical stack locally (`supabase start`), so local, CI and
  production run the same images.

**Negative**

- **Three languages instead of one:** Dart in the app, SQL/PL/pgSQL for the domain,
  TypeScript (Deno) in Edge Functions. Types no longer flow automatically from schema to
  UI; Dart models are written by hand and pinned by tests.
- **Domain logic in PL/pgSQL** is less pleasant to write and refactor than TypeScript, and
  it must be tested with pgTAP against a real database. That was already true of the
  ledger and RLS; it is now true of all of it.
- **RLS becomes the primary authorisation layer**, not defence in depth. The anon key is
  in every app binary by design, so a missing policy is an open door. Every table ships
  with policy tests, without exception.
- **A heavier server.** Self-hosted Supabase is about a dozen containers and wants about
  8 GB of RAM. *(Since 2026-10-14 the lean layer switches off what WuselWall does not use.)*
- **Self-hosted Supabase lags the hosted product** and is upgraded by pulling new pinned
  images and following its changelog. Budget a quarterly upgrade evening.
- **Native distribution costs money and time** — see [ADR-011](ADR-011-native-distribution-and-ci-cd.md).

**Revisit if** PL/pgSQL becomes the bottleneck to progress. The escape hatch is a small
TypeScript service connecting to the same Postgres for writes; nothing in this decision
prevents adding one later.

## Amendment (2026-10-15): the QR scanner (Q49)

The app's QR scanner moved from `mobile_scanner` to the `camera` plugin plus `zxing2`, a Dart port of ZXing that decodes on the device. Reason: `mobile_scanner` uses Google's ML Kit on Android, which reports device, app and performance data to Google. The decision and its reasons are in [14](../14-open-questions.md) (Q49); the privacy policy no longer names ML Kit.
