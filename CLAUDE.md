# CLAUDE.md

This repository holds both the planning documents and the code for WuselWall (see
[README.md](README.md)). `docs/` is the specification; `app/` (Flutter), `supabase/`
(migrations, Edge Functions, tests) and `infra/` hold the implementation. Setup-plan steps 3, 5 and 6 are built (app shell,
identity, online shopping list); continue from [docs/16-setup-plan.md](docs/16-setup-plan.md)
step 7, or deepen M1 modules.

## Architecture rules

See [docs/03-architecture.md](docs/03-architecture.md) and
[ADR-010](docs/adr/ADR-010-flutter-and-self-hosted-supabase.md).

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
  widget. Values and rules: [docs/17-design-system.md](docs/17-design-system.md).
- Configuration comes from `--dart-define-from-file=env/<name>.json` — never `dotenv`,
  never `kDebugMode` branches for URLs or keys.
- Developer-only screens are gated with `kDebugMode` and must not exist in release.
- Realtime callbacks receive the whole envelope: read `message['payload']['topic']`.
- pgTAP against the Unraid stack: `scripts/remote-pgtap.sh` (`supabase test db` cannot mount
  local files into a remote Docker host). Tests clear their own state inside a rolled-back
  transaction, so they pass on a database that already has data.
- Run `flutter analyze`, `flutter test` and (with a backend) `flutter test test/integration
  --dart-define-from-file=env/dev.json` before finishing. The Supabase stack may run on the
  Unraid Docker host: `scripts/remote-supabase.sh` (see `docs/16-setup-plan.md`).

## Localization

All user-facing text in the built application must exist in **both English and German**,
always. This is not optional and not deferred to a later milestone — it applies as soon as
any UI work starts. Never add a string in one language only.

- Shipped locales are `de` and `en` (NFR-14, see [docs/02-requirements.md](docs/02-requirements.md)).
  German is the default and the fallback for unsupported device locales.
- Code, comments and documentation stay in English — only user-facing strings are localized.
- Strings live in `app/l10n/app_en.arb` (template) and `app/l10n/app_de.arb`, generated with
  Flutter `gen-l10n` and read through `context.l10n` (see
  [docs/09-clients-and-ux.md](docs/09-clients-and-ux.md#language)). No literal string may land
  in a widget, even as a placeholder — add the key to both ARB files in the same change.
- This covers UI copy, error messages, notifications, ICS summaries, and the MCP and
  Shortcuts responses (see [docs/12-mcp-and-assistants.md](docs/12-mcp-and-assistants.md)) —
  anything a household member reads or hears from the app. Server-side strings live in
  `supabase/functions/_shared/`, one message file per language.
