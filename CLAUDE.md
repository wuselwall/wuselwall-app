# CLAUDE.md

This repository holds both the planning documents and the code for WuselWall (see
[README.md](README.md)). `specs/` is the specification; `app/` (Flutter), `supabase/`
(migrations, Edge Functions, tests) and `infra/` hold the implementation. Setup-plan steps 3, 5,
6 and 8 are built (app shell, identity, online shopping list, the one environment) and M1.1
is built, offline outbox included. Onboarding (step 9, [specs/20](specs/20-onboarding.md),
ADR-014 and ADR-018 — self-hosted only, no WuselWall Cloud) is built, steps 9.1–9.7, except 7a
(any server chosen in the app), which lives on `feature/self-hosting-kit`. M0.4: the first
TestFlight build is uploaded; Android is an APK by hand until the Play account exists. Since
2026-10-13 the public hosts are `wuselwall.app`, `web.` and `api.` (ADR-017). Built on
`feature/regions-and-ux`, **migrations and functions not yet on the server**: households and
founder codes (H1/H2), email code sign-in (E1–E3), invitations, pairing of shared and wall
devices, leaving, deleting and restoring a family, account deletion, the second-factor reset,
localised mail, local reminders, "Alle Termine" on the wall, subscribed calendars in the ICS
feed, the QR scanner on `camera` and `zxing2`; before them regions and holidays (DE/AT/CH/LI),
several schools, the timetable's day operations, meal suggestions, the Today tab with the
getting-started card, the data export, subscribed ICS calendars (FR-1.9), household settings
(specs/21), the kiosk week board (specs/09), M1.3a calendar, M1.3b Stundenplan (the projection in
`supabase/functions/_shared/school.ts`), M1.2 tasks and points, M1.4 meals, and the kid register.
`scripts/local-pgtap` runs every migration and pgTAP suite on a throwaway local Postgres (no
Docker); `scripts/remote-pgtap-dry.sh` tries new migrations on the server inside a rolled-back
transaction. Next: apply the migrations (`scripts/remote-backup.sh` first, then
`scripts/remote-migrate.sh`), deploy the Edge Functions (`scripts/remote-stack.sh functions`),
schedule the jobs (`household-purge`, `calendar-import`, `holidays-sync`, `tasks-nightly`), set
`ENABLE_EMAIL_AUTOCONFIRM=false` on the existing server, then M1.6.

## Architecture rules

See [specs/03-architecture.md](specs/03-architecture.md),
[ADR-010](specs/adr/ADR-010-flutter-and-self-hosted-supabase.md) and
[ADR-013](specs/adr/ADR-013-one-self-hosted-environment.md).

- **There is one environment** today: the official compose stack (`infra/supabase`) on the home server (Unraid, `ssh unraid`),
  public at `https://api.wuselwall.app` ([ADR-017](specs/adr/ADR-017-wuselwall-app-domain.md);
  the web app is `https://web.wuselwall.app`, the website `https://wuselwall.app`, and
  `wusel.goomba.ch` is only a bridge for old app builds). The family's data lives there, next to development
  and testing (Q46), and it stays the only environment: **the project runs no hosted
  service** ([ADR-018](specs/adr/ADR-018-self-hosted-only.md)). Other families run their own
  server, and the store app connects to whichever server a household chooses. Before any migration
  run `scripts/remote-backup.sh`; never run `supabase db reset` against it; never run the
  Dart integration test against it (it creates households and revokes devices — CI and
  throwaway stacks only). Keys come from the git-ignored `supabase/.env`.
- `supabase/` is the server other families install (ADR-018): keep it portable to any
  Supabase stack, including an operator's own hosted project — no dependence on superuser
  rights or on self-hosted-only features without noting it in ADR-013. A migration that
  changes the app–server contract raises `api_version`; each app release supports the
  current and the previous one, so never assume every server runs the latest release.
- No household's server is hard-coded in the app either: the store app has no default
  backend. Native Apple/Google sign-in and passkeys only for `WW_FIRST_PARTY_HOSTS`.

- Tables live in the `app` schema and are never exposed. PostgREST exposes only `api`:
  `security_invoker` views for reads, one function per write use case.
- Every `api` write function starts with `app.actor(p_actor_profile_id)`, which
  establishes household, device, acting profile and origin — the SQL equivalent of an
  explicit actor context. It writes its audit row with `app.audit()` in the same
  transaction.
- Every `app` table has RLS enabled **and forced**, and every policy has pgTAP tests for
  the cross-household, revoked-device and unauthenticated cases. RLS is the perimeter:
  the anon key ships in the apps.
- Domain errors are raised with a stable code (`WW-<MODULE>-<NNN>`) and mapped to typed
  `Failure`s in the app's `core/errors.dart`; repositories return `Result<T, Failure>`.
- The Flutter app contains no business rules. Widgets call repositories; repositories
  call `api` views, `api` functions or Edge Functions — never a table.
- Edge Functions forward the caller's JWT. The service-role key is only for functions
  without a user (ICS, enrolment, jobs) and for the two account-administration functions
  of ADR-014 (`account-delete`, MFA reset), which verify the caller's JWT and act only on
  that caller (or, for the reset, a co-guardian), with a comment at each use. Two more,
  inside a user's request: `holidays-sync` verifies the member's JWT and writes only the
  public holiday cache; `calendar-import` verifies the guardian's JWT and stores only that
  one calendar.
- Migrations are forward-only and must stay compatible with the previous app release.
- **No household is hard-coded.** Anything one household would answer differently from
  another is a setting with a curated default ([specs/20](specs/21-household-settings.md)):
  a `setting_definition` row written by a migration, read through `api.settings`. Never
  assume the number of members, their ages, the region or the schools. Lukas, Sabine, Lotta
  and Hanna are the reference household — fine in examples, mockups, demo and seed data,
  never in logic or tests that would fail for another family.

## App conventions (`app/lib`)

- `app/` bootstrap, router, themes per UI register; `core/` shared plumbing (config,
  `Result`/`Failure` and the error mapper, `ApiClient`, secure session storage,
  connectivity, Realtime invalidations, l10n helpers, shared widgets);
  `features/<module>/{data,domain,ui}`. `features/system` is the reference feature.
- Widgets never call Supabase. A repository takes an `ApiClient`, calls `api` views and
  functions, and returns `Result<T>`; providers `unwrap()` it so `AsyncValue` carries
  the `Failure`. Render with `AsyncValueView`.
- Colours come from `app/theme/palette.dart` through `Theme.of(context).colorScheme` and
  `context.ww` (member colours, paper tints, points) — never a `Color` literal in a
  widget. Values and rules: [specs/17-design-system.md](specs/17-design-system.md).
- Configuration comes from `--dart-define-from-file=env/<name>.json` — never `dotenv`,
  never `kDebugMode` branches for URLs or keys.
- Developer-only screens are gated with `kDebugMode` and must not exist in release.
- Realtime callbacks receive the whole envelope: read `message['payload']['topic']`.
- pgTAP against the Unraid stack: `scripts/remote-pgtap.sh` (`supabase test db` cannot mount
  local files into a remote Docker host). Tests clear their own state inside a rolled-back
  transaction, so they pass on a database that already has data.
- Run `flutter analyze` and `flutter test` before finishing, and `scripts/remote-pgtap.sh`
  after backend changes. The integration tests (`flutter test test/integration
  --dart-define-from-file=env/ci.json`) run in CI on a throwaway stack, or locally against
  one (`npx supabase start` with Docker on the laptop) — never against the home server.
  The home server runs the official compose stack (`infra/supabase`), driven by
  `scripts/remote-stack.sh`; migrations go through `scripts/remote-migrate.sh` (see specs/10).

## Website (`website/`)

Astro site at `https://wuselwall.app/` ([ADR-016](specs/adr/ADR-016-public-website.md),
[ADR-017](specs/adr/ADR-017-wuselwall-app-domain.md)): marketing page, Impressum, Datenschutz,
German at `/` and English at `/en/`. The Flutter web app has its own host,
`https://web.wuselwall.app/` (`scripts/deploy-web.sh`). Every user-facing string lives in `website/src/i18n/index.ts` in **both** languages;
operator and legal data only in `website/src/config/site.ts` (`TODO` values fail
`LEGAL_STRICT=1` builds). No cookies, no third-party requests, no analytics. Deploy with
`scripts/remote-web.sh deploy`, independent of the Supabase stack. App screenshots on the
home page are WebP copies of the docs' shots (`npm run sync-screens` in `website/`, after
`npm run docs:screenshots`); the link-preview images come from `node scripts/og-image.mjs`.
The official App Store and Google Play badges (`public/badges/`, unmodified artwork) appear
only once `site.stores` holds the real listing URLs. The privacy policy describes every
third party the apps or the site talk to: a new SDK or outbound host updates it, in both
languages, in the same change. Check with
`cd website && npm run build`. When you add a page, add its route in both languages and its
`paths` entry so `hreflang` and the sitemap stay right.

**When a feature is finished or the next step changes, update the "Where we are" list in the
same change** — `status` in `website/src/i18n/index.ts`, both languages, states `fertig`/`done`,
`als Nächstes`/`up next`, `geplant`/`planned`. It is the public progress, written for
families: features they can use, not setup-plan steps or milestone numbers. Keep it in step
with the status line at the top of this file and the roadmap ([specs/13](specs/13-roadmap.md)).
The live site changes only after `scripts/remote-web.sh deploy`.

## End-user documentation (`docs/`)

VitePress site in German (root) and English (`/en/`), written for the family, not for
developers (the specification is `specs/`), published at `https://wuselwall.app/docs/` by
`.github/workflows/docs.yml` on every push to `main`. Screenshots come from the Flutter web
demo (`app/lib/main_demo.dart`, in-memory data) driven by Playwright
(`docs/tools/screenshots.mjs`): every shot in both languages and both themes (`name.png`,
`name-dark.png`). They are build output, not committed: `npm run docs:screenshots` makes
them locally. Pages show them with `<Shot name="…" alt="…" />` (add `wide` for tablet and
wall shots), never a plain `<img>`; `npm run docs:check` fails when a page uses a shot the
script does not take. `npm run docs:dev` previews, `npm run docs:build` checks links.
**When a screen or a label changes, update the matching page in both languages; a new
screen gets its shot in `screenshots.mjs`.** Playwright's Chromium needs
`sudo npx playwright install-deps chromium` once on the development machine.

## Localization

All user-facing text in the built application must exist in **both English and German**,
always. This is not optional and not deferred to a later milestone — it applies as soon as
any UI work starts. Never add a string in one language only.

- Shipped locales are `de` and `en` (NFR-14, see [specs/02-requirements.md](specs/02-requirements.md)).
  German is the default and the fallback for unsupported device locales.
- Code, comments and documentation stay in English — only user-facing strings are localized.
- Strings live in `app/l10n/app_en.arb` (template) and `app/l10n/app_de.arb`, generated with
  Flutter `gen-l10n` and read through `context.l10n` (see
  [specs/09-clients-and-ux.md](specs/09-clients-and-ux.md#language)). No literal string may land
  in a widget, even as a placeholder — add the key to both ARB files in the same change.
- This covers UI copy, error messages, notifications, ICS summaries, and the MCP and
  Shortcuts responses (see [specs/12-mcp-and-assistants.md](specs/12-mcp-and-assistants.md)) —
  anything a household member reads or hears from the app. Server-side strings live in
  `supabase/functions/_shared/`, one message file per language. iOS permission prompts live
  in `app/ios/Runner/{de,en}.lproj/InfoPlist.strings` (Info.plist keeps the German text).
