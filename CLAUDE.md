# CLAUDE.md

This repository holds both the planning documents and the code for WuselWall (see
[README.md](README.md)). `specs/` is the specification; `app/` (Flutter), `supabase/`
(migrations, Edge Functions, tests) and `infra/` hold the implementation. Setup-plan steps 3, 5,
6 and 8 are built (app shell, identity, online shopping list, the one environment) and M1.1
is built except the offline outbox. Next: the outbox; step 7 once the Apple and Google accounts
exist.

## Architecture rules

See [specs/03-architecture.md](specs/03-architecture.md),
[ADR-010](specs/adr/ADR-010-flutter-and-self-hosted-supabase.md) and
[ADR-013](specs/adr/ADR-013-one-self-hosted-environment.md).

- **There is one environment**: the CLI stack on the home server (homeserver, `ssh homeserver`),
  public at `https://wusel.example.org`. The family's data lives there. Before any migration
  run `scripts/remote-backup.sh`; never run `supabase db reset` against it; never run the
  Dart integration test against it (it creates households and revokes devices — CI and
  throwaway stacks only). Keys come from the git-ignored `supabase/.env`.
- Keep `supabase/` portable to hosted Supabase (further tenants, ADR-013): no dependence on
  superuser rights or on self-hosted-only features without noting it in ADR-013.

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
  without a user (ICS, enrolment, jobs), with a comment at each use.
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
- pgTAP against the homeserver stack: `scripts/remote-pgtap.sh` (`supabase test db` cannot mount
  local files into a remote Docker host). Tests clear their own state inside a rolled-back
  transaction, so they pass on a database that already has data.
- Run `flutter analyze` and `flutter test` before finishing, and `scripts/remote-pgtap.sh`
  after backend changes. The integration tests (`flutter test test/integration
  --dart-define-from-file=env/ci.json`) run in CI on a throwaway stack, or locally against
  one (`npx supabase start` with Docker on the laptop) — never against the home server.
  The home server runs the official compose stack (`infra/supabase`), driven by
  `scripts/remote-stack.sh`; migrations go through `scripts/remote-migrate.sh` (see specs/10).

## End-user documentation (`docs/`)

VitePress site in German (root) and English (`/en/`), written for the family, not for
developers (the specification is `specs/`). Screenshots come from the Flutter web demo
(`app/lib/main_demo.dart`, in-memory data) driven by Playwright: `npm run docs:screenshots`
regenerates every image in both languages; `npm run docs:dev` previews, `npm run docs:build`
checks links. **When a screen or a label changes, update the matching page in both
languages and regenerate the screenshots.** Playwright's Chromium needs
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
  `supabase/functions/_shared/`, one message file per language.
