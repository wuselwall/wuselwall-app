# AGENTS.md

This repository holds both the planning documents and the code for WuselWall (see
[README.md](README.md)). `specs/` is the specification; `app/` (Flutter), `supabase/`
(migrations, Edge Functions, tests), `infra/` and `server/` hold the implementation.
Setup-plan steps 3, 5, 6 and 8 are built (app shell, identity, online shopping list, the
compose stack) and M1.1 is built, offline outbox included. Onboarding (step 9,
[specs/20](specs/20-onboarding.md), ADR-014 and ADR-018 — self-hosted only, no WuselWall
Cloud) is built: email codes and passwords (E1–E3), households and founder
codes (H1/H2), invitations and pairing (links carry the server and open the app as universal
links and App Links), the join and new-sign-in notices on Today, leaving, deleting and
restoring a family, account deletion and the second-factor reset, localised mail
(`send-email` hook), and ADR-018's server choice: the store app asks for its server
(discovery through the `server-info` function), a server release with `server/wuselwall`
(`server/cloud-init.yaml` installs it on a rented VPS at the first boot), and
`deploy-supabase.yml` for a family's own hosted project (Auth through
`scripts/hosted-auth-config.mjs`, the run verifies its result), and mail is optional (2026-10-26, Q48: without SMTP
Auth autoconfirms, `server-info` says `sign_in.email_code: false`, the app signs up with a password, invitations match
only `app.proven_email`, a guardian's one-time code or `wuselwall password` resets a password; `wuselwall mail` sets up
any SMTP server, Gmail included), and the setup key claims the server (2026-10-30, specs/20 "Claiming the
server": S1 `ClaimPage` checks the key and announces the founder's address with `api.setup_claim`; the Before
User Created hook `app.before_user_created_hook` refuses every other sign-up while no household exists; H1
asks for no key after a claim; the key stays on the device). The onboarding journeys J1–J3 are
integration tests (CI's backend job) and screen-count tests (`app/test/journeys`). Built besides: household settings
(specs/21), the kiosk week board (specs/09) with "Alle Termine", M1.3a calendar (events,
presence, recurrence expanded in Edge Functions, the ICS feed with tokens, and since 2026-10-24 a read-only month view), M1.3b Stundenplan
(the projection in `supabase/functions/_shared/school.ts`), M1.2 tasks and points, M1.4 meals,
the kid register; regions to any depth and holidays (DE/AT/CH/LI from OpenHolidays, fetched
by the server: public holidays automatic, Ferien imported), several schools, the timetable's
day operations, meal suggestions, the Today tab with the getting-started card, the data
export, subscribed ICS calendars (FR-1.9: `calendar-import`, read-only occurrences in their
own tables, optionally in the outbound feed), local reminders (Q47), the QR scanner on
`camera` and `zxing2` (Q49), Siri via Apple Shortcuts (M2, specs/12 Part 1: per-person keys
in `app.shortcut_token`, the `shortcuts` function),
the evening packing reminder (FR-7.12, `notify.packing_reminder`), and the usual week
(issue #81, specs/15 "The baseline": a usual place per weekday, up to three time slots a
day and alternating weeks A/B), event templates ([specs/28](specs/28-event-templates.md), 2026-10-25: Neuer Termin opens tiles, built-in, saved and suggested from the family's history by counting in SQL, migration `20261025150000`, pgTAP 245), and the school import of [specs/24](specs/24-school-import.md)
(2026-10-22): the proposed term, subjects from the cell, the paste import with its preview,
the retained proposal backend (`app.proposal`, `api.mcp_propose`, `propose_timetable`),
and the photo scan (`timetable-scan` with the optional `ocr` container, RapidOCR on the CPU),
and step 10's slices 1–3 (2026-10-23): members editable (name, colour, avatar picture, kind,
role, order by dragging, "Nicht mehr dabei"), the family (name, time zone, locale) and devices
(rename, last active) on their own pages, and the shopping structure (lists renamed and
removed, categories added, renamed, ordered and removed, catalogue tiles renamed and
forgotten), each page with the Basic/Advanced switch of specs/21.
The shopping list has two modes since 2026-10-31 ([specs/07](specs/07-module-meals-shopping.md)
"Two modes"): Planen in the tab, Einkaufen as a full-screen trip page without the app bar and the
navigation, the last mode kept on the device, the item sheet with a count stepper, pinned tiles,
a seeded `snacks` category, and a category inferred from a new item's name by the server's word
list (`app.shopping_category_for`, marked `category_auto` until a person changes it; the lists
grow in issue #197).
Local matching ([specs/29](specs/29-local-matching.md), ADR-021, 2026-10-31): one dictionary
source in `dictionary/*.txt` (six tags incl. de-CH/de-AT) rendered by `scripts/dictionary.mjs`
into `app/assets/matching/dictionary.json` (CI runs `check`) and, on demand, SQL `values`; the
layered pure-Dart matcher and the shared quantity parser live in `app/lib/core/matching/`, the
acceptance corpus in `dictionary/corpus.txt`. Feature 1 (shopping) is in: `dictionary.mjs sql` writes
`supabase/migrations/*_match_words.sql` (table `app.match_word`, the newest file pinned to the render
by the node test), `app.match_dictionary` runs the same layers in plpgsql and feeds
`catalog_icon_for`, `meal_icon_for` (triggers now, no generated columns) and
`catalog_category_keys_for`; `@name` blocks carry categories without a picture; the picker's
`rankTiles` falls back to the matcher and the "Neu" tile shows the matched picture; a person's
category choice is remembered per household in `app.match_correction` (Einstellungen > Einkaufen >
Gelernte Wörter, Advanced, guardians forget).
A restart without network (step 10.6, issue #128, 2026-11-10): reads given a `cacheKey` in
`ApiClient` keep their last good JSON answer in a second drift database
(`app/lib/core/cache/`, ADR-006's read cache) and fall back to it on a network failure only:
the device's own record, the board week and the kid day. The wall's header and the
`StaleStrip` on the kid and adult homes say since when (FR-8.10). Read-only: every write
except the shopping outbox still needs the server.
MCP and AI assistant work is **on hold** (2026-10-24), removed from the app UI and active
milestones. The backend, keys and proposal data are retained for compatibility; existing
MCP clients are not disabled. Siri/automations, structured timetable text import and the
server's photo/PDF scan remain. Resume only by an explicit product decision; see
[the deferred-work record](specs/deferred/mcp-and-ai-assistants.md) and
[specs/23](specs/23-roadmap-after-alpha.md#on-hold--mcp-and-ai-assistants).
The current language scope is DE/EN/FR/ES throughout the app and server responses, with
one installation-selected email language (NFR-14); release evidence remains a separate gate.
`scripts/local-pgtap` runs every migration and pgTAP suite on a throwaway local Postgres (no
Docker). The server runs four scheduled jobs: `tasks-nightly`,
`holidays-sync` (weekly), `calendar-import` (hourly) and `household-purge` (daily). Next: follow the four milestones in
[specs/13](specs/13-roadmap.md): (1) everyday essentials, the remaining journey gaps of
[step 10](specs/16-setup-plan.md#step-10--journey-gaps-before-launch-m15); (2) a lighter day,
[step 11](specs/16-setup-plan.md#step-11--a-lighter-day-m15), built 2026-10-24: Wusel drawn in code
(`app/lib/core/wusel/`, goldens in `app/test/golden/`; since 2026-10-26 also on the move in the kid register and on the wall: `WuselStage`, `WuselRig`, tilt through `sensors_plus`, specs/25), module bands, the wall's sky, occasions and pixel shift,
celebrations with synthesised sounds (`scripts/sound-effects.mjs`), birthdays, Vorfreude, traditions,
Wunschessen, the Tischfrage (decks by age in `app/assets/table_questions/`) and the Wochenrückblick
(migrations `20261024100000`/`20261024110000`, pgTAP 235); screenshots hold still with `?still=1`; (3) qualify the candidate, run the
two-week family Alpha and act on its findings; (4) safe releases and readiness for other
families. Steps 10.1–10.3 and the release-checklist document are built; checklist evidence
is still open. The former M2/R1–R4 lists are no longer separate schedules; later candidates
live in [specs/23](specs/23-roadmap-after-alpha.md). Merged migrations and functions reach a live server after a backup
(`scripts/remote-backup.sh` first); a server with mail sets `ENABLE_EMAIL_AUTOCONFIRM=false`, one without sets it
`true` (`wuselwall mail` checks which).
Onboarding journey finish (#129, 2026-11-10): H1 saves local name/colour/examples drafts
per server and account, clears them on success/sign-out/invitation, and excludes codes.
A sole guardian account sees a TOTP recovery warning before enrolment; Today counts OS
notification permission as a completed step. The adult register uses a rail from 840
logical pixels and preserves the selected tab through Settings Back and resizing.
Passkeys default off pending native verification (`ENABLE_PASSKEYS` is verification-only,
fixed-server builds). Legacy wizard/enrolment retirement stays conditional in #221;
website deletion/progress work is tracked separately in wuselwall-website#17. Native and
publication evidence remain release gates; see specs/release-checklist.md's #129 review.
The second security review ([specs/19](specs/19-security-and-architecture-review.md) "Second
review", fixed 2026-11-02) hardened the flows around the perimeter: the Send Email Hook mails each
email-change code to its own address and `app.proven_address` records what was proven; links never
plant a session and a server is confirmed before the app connects; guardian resets and account
deletion need a fresh sign-in and `aal2`; task instances are materialised by the server only; rate
buckets count failures with a client key Envoy sets; recurrence rules are walked by a bounded
engine; server releases are signed (minisign) and verified by `wuselwall update`.

**Never describe a particular operator's server in a committed file** — not a host, path,
SSH alias, machine or the fact that someone runs one. Placeholders (`example.org`) in
committed files; real values in git-ignored files (`scripts/remote.env`,
`app/env/dev.json`, `CLAUDE.local.md`) or CI variables and secrets.

## Development workflow

The whole process is in [CONTRIBUTING.md](CONTRIBUTING.md); these are the rules an agent
follows without being asked.

- **Never commit to `main` or push to it.** It is protected (pull request, required checks,
  squash only, no administrator bypass). Work in a branch, in its own worktree under
  `.worktrees/` when another checkout is in use.
- **A feature or a fix needs an issue in a release milestone before the code.** Find the
  issue or create it (`gh issue create --label enhancement --milestone v1.12.0`, or `bug`),
  with the outcome and acceptance checkboxes. Milestones are releases (`v<app version>`);
  the open one with the lowest version is the next release
  (`gh api repos/{owner}/{repo}/milestones --jq '.[].title'`). If the right release is not
  yours to choose, create the issue without one (it gets `needs-triage`) and ask.
  Documentation, chores, CI and dependency changes need no issue.
- **Name the branch by type**: `feat/<issue>-<slug>`, `fix/<issue>-<slug>`, `docs/…`,
  `chore/…`, `ci/…`. The prefix sets the pull request's type label, and the label sorts the
  release notes.
- **Open a pull request with the template**: a plain-sentence title without a prefix (it
  becomes the commit on `main` and a line of the release notes), `Closes #<issue>` for a
  feature or a fix, and what was run under "How it was checked". Do not set labels or the
  milestone by hand: the `triage` workflow takes them from the branch and the issue.
- **All five required checks must pass**: `app`, `scripts`, `audit` (ci), `required`
  (backend-ci) and `pr-policy` (the issue and milestone rule). Read a failing check and fix
  its cause; never weaken a check, a ruleset or [scripts/github-settings.sh](scripts/github-settings.sh)
  to get a change through. `gh pr merge --squash --auto` merges when they pass; merge only
  when the owner asked for the merge.
- **CI selects work by inputs** (`scripts/ci-changes.mjs`): docs-only PRs skip Flutter,
  UI-only changes skip database integration, and unknown paths/diff failures run full.
  Keep the five required names above; `app` and `required` always report and reject
  failed/cancelled/skipped selected work. Detectors, aggregates, audit and Deno run on
  GitHub-hosted runners; Flutter and Docker/SMTP jobs stay on the build fleet.
  Guide PRs run `npm run docs:check:source` and build without screenshots; main/manual
  docs and candidate qualification run the complete four-language/light-dark matrix.
  Schema 3 qualification requires quality, backend and guide evidence for the exact
  SHA before signing; regenerate older artifacts. Candidate quality-only reuse skips
  duplicate app work because strict Flutter and production jobs already own it.
- **A release is cut by the `release` workflow**, never by pushing tags by hand:
  `gh workflow run release.yml -f dry_run=true` prints the plan, `-f dry_run=false` creates
  the tags `v<app>` and `server-v<server>`, the GitHub releases with generated notes, starts
  the gated builds and rolls the milestone over. Cut a release only on the owner's request.
  Release tags are never moved or deleted; a bad release is followed by a patch release.
- A new workflow pins its actions to commits, declares `permissions`, and keeps write tokens
  and secrets away from jobs that run a pull request's code. Repository settings change in
  `scripts/github-settings.sh` and `.github/rulesets/`, then on GitHub by running the script.

## Architecture rules

See [specs/03-architecture.md](specs/03-architecture.md),
[ADR-010](specs/adr/ADR-010-flutter-and-self-hosted-supabase.md) and
[ADR-013](specs/adr/ADR-013-self-hosted-compose-stack.md).

- **The project runs no hosted service** ([ADR-018](specs/adr/ADR-018-self-hosted-only.md)):
  every family runs its own server, and the store app connects to whichever server a
  household chooses. A live server holds a family's data: before any migration back it up;
  never run `supabase db reset` against it; never run the Dart integration test against it
  (it creates households and revokes devices — CI and throwaway stacks only). Keys come
  from the git-ignored `supabase/.env`.
- `supabase/` is the server other families install (ADR-018): keep it portable to any
  Supabase stack, including an operator's own hosted project — no dependence on superuser
  rights or on self-hosted-only features without noting it in ADR-013. A migration that
  changes the app–server contract raises `api_version`; each app release supports the
  current and the previous one, so never assume every server runs the latest release.
- No household's server is hard-coded in the app either: the store app has no default
  backend, and the project runs no server of its own. Passkeys only in builds that name their own server.

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
  without a user (ICS, Shortcuts, MCP, enrolment, jobs) and for the two account-administration functions
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
- pgTAP against a server's compose stack: `scripts/remote-pgtap.sh` (`supabase test db`
  cannot mount local files into a remote Docker host). Tests clear their own state inside a rolled-back
  transaction, so they pass on a database that already has data.
- Run `flutter analyze` and `flutter test` before finishing, and `scripts/remote-pgtap.sh`
  after backend changes. The integration tests (`flutter test test/integration
  --dart-define-from-file=env/ci.json`) run in CI on a throwaway stack, or locally against
  one (`npx supabase start` with Docker on the laptop) — never against a live server.
  A server from a checkout runs the official compose stack (`infra/supabase`), driven by
  `scripts/remote-stack.sh`, with migrations through `scripts/remote-migrate.sh`; a server
  from a release is driven by `server/wuselwall` (see specs/10).

## Marketing website (separate repository)

The private `wuselwall/wuselwall-website` repository owns the Astro marketing site,
legal pages, well-known app-link files, screenshots and independent website CI/CD.
This app repository does not build or deploy it. See
[ADR-019](specs/adr/ADR-019-website-repository-and-docs-pages.md) and the
[cutover plan](specs/website-and-docs-migration.md).

When a feature or next step changes, update this repository's status and roadmap,
and coordinate a separate bilingual public-progress change in the website repository.
Do not require access to the private marketing repository to build or contribute to the
app/backend/docs. Export screenshots from this repository explicitly; the marketing
repository keeps its own committed copies and never checks out private app source in CI.

## End-user documentation (`docs/`)

VitePress site in German (root), English (`/en/`), French (`/fr/`) and Spanish (`/es/`),
written for the family, not for developers (the specification is `specs/`).
`.github/workflows/docs.yml` publishes at `https://docs.wuselwall.app/` from this public
repository. Actions Pages, the custom domain and HTTPS are enabled;
`DOCS_PAGES_ENABLED=true`. The first deployment and live checks passed 2026-10-24
(see [cutover status](specs/website-and-docs-migration.md#activation-status--2026-10-24)).
The website's links and privacy text switch together in its own repository. Keep the old
`wuselwall.app/docs/` links working for older app releases; their path- and query-preserving
redirects are a separate operator change. Screenshots come from the Flutter web
demo (`app/lib/main_demo.dart`, in-memory data) driven by Playwright
(`docs/tools/screenshots.mjs`): every shot in all four languages and both themes (`name.png`,
`name-dark.png`). They are build output, not committed: `npm run docs:screenshots` makes
them locally. Pages show them with `<Shot name="…" alt="…" />` (add `wide` for tablet and
wall shots), never a plain `<img>`; `npm run docs:check` fails when a page uses a shot the
script does not take. `npm run docs:check:source` validates capture definitions without PNGs for fast PRs;
`npm run docs:dev` previews, `npm run docs:build` checks links. Main/manual docs and release
qualification still generate and validate every screenshot before publication.
**When a screen or a label changes, update the matching page in all four languages; a new
screen gets its shot in `screenshots.mjs`.** Playwright's Chromium needs
`sudo npx playwright install-deps chromium` once on the development machine.

## Localization

All user-facing application and server-response text must exist in **German, English,
French and Spanish**, in the same change. This is not deferred to a later milestone.
The family guide now covers DE/EN/FR/ES; marketing/legal translations in the separate website
repository now cover DE/EN/FR/ES (issue #6, publication separately gated).

- Shipped locales are `de`, `en`, `fr` and `es` (NFR-14, see [specs/02-requirements.md](specs/02-requirements.md)).
  The app follows the device language, including regional variants; unsupported languages
  fall back to German. New families store `de-DE`, `en-GB`, `fr-FR` or `es-ES` accordingly.
- Code, comments and developer documentation stay in English; family guides cover DE/EN/FR/ES.
- Strings live in `app/l10n/app_en.arb` (template) and `app/l10n/app_{de,fr,es}.arb`, generated with
  Flutter `gen-l10n` and read through `context.l10n` (see
  [specs/09-clients-and-ux.md](specs/09-clients-and-ux.md#language)). No literal string may land
  in a widget, even as a placeholder — add the key to all four ARB files in the same change.
  Test key/placeholder parity, ICU formatting and locale resolution; check FR/ES layouts
  and native permission prompts, not just generated files.
- This covers UI copy, error messages, notifications, ICS summaries, and the MCP and
  Shortcuts responses (see [specs/12-mcp-and-assistants.md](specs/12-mcp-and-assistants.md)) —
  anything a household member reads or hears from the app. Server-side strings live in
  `supabase/functions/_shared/`, one message file per language. iOS permission prompts live
  in `app/ios/Runner/{de,en,fr,es}.lproj/InfoPlist.strings` (Info.plist keeps the German text).
- Email is the exception to device/household language selection: every message uses only
  the installation's `MAIL_LANGUAGE` (`de|en|fr|es`, German when unset), including its subject
  and both body parts. Hook and SMTP templates must agree; never derive mail language from
  recipient metadata. Install/update/language-change tests must preserve keys and the
  selected language. See [specs/10](specs/10-deployment-and-ops.md#email-setup).
- FR/ES app privacy/legal links deliberately fall back to existing English website pages.
  Keep this fallback until the separate website release publishes its localized legal pages.
  Both the explicit website export and default family-guide screenshot matrix cover all four locales.
