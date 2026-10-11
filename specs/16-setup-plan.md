# 16 — Basic Setup Plan: from empty repository to a release pipeline

*Added 2026-10-11 with the move to Flutter and self-hosted Supabase
([ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md),
[ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md)); step 8 rewritten the same day
for one environment on the home server ([ADR-013](adr/ADR-013-one-self-hosted-environment.md)). This is the build order for
milestone M0 in [13](13-roadmap.md): everything that has to exist before the first
module is worth building.*

The goal of M0 is not features. It is to prove every layer end to end with the thinnest
possible content: a Flutter app on a real iPhone, iPad and Android tablet, talking to
Supabase, enrolled as a device, writing one table under RLS, with CI checking every
change and a tag producing installable builds. Once that works, every module after it is
"more of the same".

## Overview

| Step | Milestone | Delivers | Rough effort |
|---|---|---|---|
| 0 | — | Tools installed, accounts applied for | 1 evening + waiting for Apple and Google |
| 1 | M0.0 | Repository skeleton, conventions, Dependabot | 1 evening |
| 2 | M0.0 | Local Supabase, first migration, RLS and pgTAP harness | 1–2 evenings |
| 3 | M0.0 | Flutter app shell: three registers, German l10n, health check | 1–2 evenings |
| 4 | M0.0 | `ci.yml`: every pull request tested | 1 evening |
| 5 | M0.1 | Identity: setup wizard, guardian accounts, device enrolment, tap-to-switch, PIN | 1 weekend |
| 6 | M0.2 | The shopping list, online only — the first real feature | 1–2 evenings |
| 7 | M0.4 | `release-mobile.yml`: a tag puts builds on the family's devices | 1 weekend |
| 8 | M0.3 | The one environment ([ADR-013](adr/ADR-013-one-self-hosted-environment.md)): own keys, nginx allow-list, backups | 1 evening |

Steps 1–4 can be done in a single long weekend. Step 7 waits on the Apple and Google
accounts from step 0, which is why those are applied for first.

---

## Step 0 — Tools and accounts

### On the development machine (Windows + WSL2 Ubuntu)

| Tool | Purpose | Note |
|---|---|---|
| Flutter SDK (stable) | The app | Install inside WSL; the exact version is pinned in `app/pubspec.yaml` and read by CI |
| Android SDK + platform tools | Android builds, `adb` | Command-line tools inside WSL are enough; Android Studio on Windows is optional |
| Docker Desktop with WSL2 integration | Local Supabase | Docker Engine inside WSL works as well |
| Supabase CLI | Local stack, migrations, tests | Pin the version; CI uses the same one |
| Deno 2 | Edge Function lint, format, tests | Same major version as Supabase's edge runtime |
| `gh` | GitHub from the terminal | Already installed and authenticated |
| A physical Android device | Running the app | Use wireless debugging (`adb pair` / `adb connect`) — USB and the Android emulator are both awkward from WSL2 |

*Since [ADR-013](adr/ADR-013-one-self-hosted-environment.md) the stack runs on the home
server and phones reach it at `https://wusel.example.org`, so the two WSL traps below only
matter for a throwaway stack on the laptop.*

Two WSL-specific traps worth solving on day one:

- **Reaching WSL from the LAN.** Phones on the home wifi must reach Supabase running in
  WSL. Turn on mirrored networking (`networkingMode=mirrored` in `%UserProfile%\.wslconfig`,
  Windows 11) and allow ports 54321 (Supabase API) and 8080 (the web build) through the
  Windows firewall for the private network profile.
- **A stable address.** Give the laptop a DHCP reservation on the router, so the dev
  build's backend address does not change under the phones.

**No Mac?** Then iOS builds happen only in CI (step 7) and the iPhone and iPad run
TestFlight builds rather than debug builds. That works, but there is no iOS simulator
and no Xcode debugger. See [Q35](14-open-questions.md).

### Accounts — apply now, they take days

| Account | Needed for | Cost | Lead time |
|---|---|---|---|
| **Apple Developer Program** (individual) | Any iOS build on a real device beyond seven days; TestFlight | €99 / year | Usually 1–2 days, occasionally longer with identity checks |
| **App Store Connect**: the app record, bundle ID `ch.goomba.wuselwall`, an **API key** (App Manager role) | Uploads from CI without a password or 2FA prompt | — | Minutes, after the programme is active |
| **Google Play Console** (personal) | Internal testing track for the wall tablet and Android phones | $25 once | Identity verification can take several days |
| **Second private GitHub repository** `wuselwall-certificates` | `fastlane match` storage for iOS signing | — | Minutes |
| Domain `example.org` and Cloudflare | The public URL `wusel.example.org` | already owned | in place |
| Firebase project | Android push via FCM — not needed until push is built, and only if [Q38](14-open-questions.md) settles on FCM | free | Minutes |

---

## Step 1 — Repository skeleton (M0.0)

1. Create the layout from [03](03-architecture.md#repository-layout): `app/`, `supabase/`,
   `infra/`, `.github/workflows/`, `specs/`, `docs/`.
2. `.gitignore` covering Flutter (`build/`, `.dart_tool/`), Supabase (`supabase/.temp/`,
   `.branches/`), environment files (`.env`, `*.env` except `*.env.example`), signing
   material (`*.jks`, `*.keystore`, `*.p8`, `*.mobileprovision`, `key.properties`).
3. `.editorconfig`, and a `Makefile` (or `justfile`) as the single place for commands:
   `make up` (Supabase start), `make reset` (re-apply migrations and seed), `make test`
   (all three test suites), `make app` (run the dev flavour), `make check` (everything CI
   runs).
4. `.github/dependabot.yml` for `pub` (in `app/`), `github-actions`, and `docker`
   (in `infra/`), weekly, grouped, never auto-merged.
5. Branch protection on `main`: pull request required, `ci` must pass, linear history.
   Work happens on short-lived branches and is squash-merged.
6. Update `README.md` with the run instructions as soon as they are true, not before.

**Done when** a fresh clone and `make check` do something meaningful, even if it is only
"no tests yet".

---

## Step 2 — Local backend (M0.0)

1. `supabase init`. In `supabase/config.toml`:
   - `[api] schemas = ["api"]` — PostgREST exposes the `api` schema and nothing else.
   - `[auth] enable_signup = false`, anonymous sign-ins off, `jwt_expiry = 3600`,
     refresh-token rotation on, `site_url` set to the dev web build.
   - `[auth.hook.custom_access_token]` pointing at `app.custom_access_token_hook`
     (written in step 5; leave it disabled until then).
   - `[db] major_version` matching the image production will run.
2. **First migration** — the foundations every later migration builds on:
   - schemas `app` and `api`; extensions `pgcrypto`, `pg_trgm`, `pg_cron`, `pg_net`,
     `pgtap` (tests only);
   - `app.household`, `app.profile`, `app.device`, `app.device_enrolment_code`,
     `app.audit_entry` from [04](04-data-model.md#identity);
   - `ALTER TABLE … ENABLE ROW LEVEL SECURITY` **and** `FORCE ROW LEVEL SECURITY` on each;
   - helper functions `app.jwt_household()`, `app.jwt_device()`, `app.actor()`,
     `app.require_guardian()`, `app.audit()`;
   - grants: `authenticated` gets `USAGE` on `api` only; `app` is granted to no client
     role; `UPDATE`/`DELETE` on `app.audit_entry` granted to no one.
3. **The pgTAP harness**, `supabase/tests/`: a helper that impersonates a device (sets
   `request.jwt.claims` and the `authenticated` role), and the first tests:
   - an unauthenticated caller sees nothing in any `api` view;
   - a device from household A cannot see household B (seed two households in tests);
   - a revoked device sees nothing;
   - every table in `app` has RLS enabled and forced — a **catalogue test** that queries
     `pg_class` and fails when a new table forgets it. This one test is worth more than
     any other in the repository.
4. `supabase/seed.sql`: the development household — Lukas, Sabine, Lotta, Hanna — and
   one device of each class.
5. A `health` Edge Function returning `{ ok: true, db: <round-trip ms> }`, and the
   `_shared/` folder with Deno's `deno.json`, formatter and linter settings.

**Done when** `supabase db reset && supabase test db` is green and
`curl localhost:54321/functions/v1/health` answers.

---

## Step 3 — Flutter app shell (M0.0)

1. The shell already exists in `app/`, started from Supabase's Flutter starter and renamed
   (package `wuselwall`, application/bundle ID `ch.goomba.wuselwall` — see
   [ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md#starting-point-and-identifiers)).
   Remove the starter's `profiles` demo pages and migration as the real schema lands.
2. Pin the Flutter version in `pubspec.yaml` (`environment: flutter: x.y.z`); enable
   `flutter_lints` plus stricter rules (`strict-casts`, `strict-raw-types`).
3. Dependencies: `supabase_flutter`, `flutter_riverpod` (+ generator), `go_router`,
   `freezed`/`json_serializable`, `flutter_secure_storage`, `intl` and
   `flutter_localizations`. Add `drift` in step 6, not before.
4. **Configuration per environment** with `--dart-define-from-file`:
   `env/dev.json` (the one environment, `https://wusel.example.org`, and its publishable
   key) and `env/ci.json` (CI's throwaway stack); no `prod.json`
   ([ADR-013](adr/ADR-013-one-self-hosted-environment.md)). No `if (kDebugMode)` branches
   for configuration. The publishable key is public by design; nothing else secret goes
   in either file.
5. **Platform networking for a local stack**: iOS `NSAppTransportSecurity →
   NSAllowsLocalNetworking` and an Android network-security config permitting cleartext
   to the private address range, for a throwaway stack on the laptop. The one
   environment is HTTPS (`wusel.example.org`).
6. **Localisation from the first widget**: `app/l10n.yaml` with `app/l10n/app_en.arb`
   (template) and `app/l10n/app_de.arb`, both locales supported with German first, and
   `untranslated-messages-file` so CI can fail on a string missing from either. No string literal is ever shown to a user (see `CLAUDE.md`).
7. **Three registers**: a `UiRegister` enum (`adult`, `kid`, `kiosk`) read from the
   device record, three `ThemeData` variants built from shared tokens (type scales and
   touch targets from [09](09-clients-and-ux.md#design-system)), and one router whose
   home route differs per register. Before enrolment, every device shows the setup screen.
8. **Core plumbing**: Supabase initialisation with the session persisted in secure
   storage, a connectivity provider, the error-code → `Failure` mapping, and a Realtime
   helper that joins `household:<id>` and exposes invalidation streams.
9. A debug-only "System" page calling `health` — the first proof that a phone reaches the
   laptop's Supabase.

**Done when** the dev build runs on the Android device and in the browser, shows German
text, and the System page reports the database round-trip.

---

## Step 4 — Continuous integration (M0.0)

`.github/workflows/ci.yml`, triggered on pull requests and pushes to `main`. Three
parallel jobs, each one fast enough to wait for.

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
permissions:
  contents: read

jobs:
  app:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: app } }
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version-file: app/pubspec.yaml, cache: true }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: dart format --output=none --set-exit-if-changed lib test
      - run: flutter analyze --fatal-infos
      - run: flutter gen-l10n && test ! -s untranslated.json
      - run: flutter test --coverage
      - run: flutter build web --release --dart-define-from-file=env/ci.json

  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
        with: { version: <pinned> }
      - run: supabase start -x studio,imgproxy,logflare,vector
      - run: supabase db reset          # every migration from zero, plus seed
      - run: supabase test db           # pgTAP, RLS catalogue test included
      - run: supabase db lint --level warning
      - run: supabase db diff --schema app,api --exit-code   # migrations match schema

  functions:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: supabase/functions } }
    steps:
      - uses: actions/checkout@v4
      - uses: denoland/setup-deno@v2
        with: { deno-version: <pinned> }
      - run: deno fmt --check && deno lint
      - run: deno test --allow-env --allow-read   # recurrence and projection suites

  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: google/osv-scanner-action/osv-scanner-action@v2
        with: { scan-args: "--lockfile=app/pubspec.lock --lockfile=supabase/functions/deno.lock" }
```

Notes:

- The exact action versions and the `supabase db diff` flags are checked against current
  documentation when the file is written; the shape above is what matters.
- **Integration tests against the database** (Dart repositories calling a running local
  Supabase) are added to the `backend` job in step 6, once there is a repository worth
  testing. **On-device UI tests** (`integration_test` on an Android emulator) are
  expensive in CI; run them nightly or before a release, not on every pull request.
- Required status checks on `main`: `app`, `backend`, `functions`.

**Done when** a pull request that breaks a migration, an RLS test, a missing German
string or the formatting is blocked.

---

## Step 5 — Identity (M0.1)

> **Built 2026-10-11** (SQL instead of Edge Functions for setup/enrolment/revoke; per-phone
> devices, TOTP, QR enrolment and rate limiting added; passkeys wired but waiting on the
> production domain) — see
> [ADR-010 implementation notes](adr/ADR-010-flutter-and-self-hosted-supabase.md#implementation-notes-m01m02-2026-10-11).

The model is [08](08-users-auth-permissions.md); the Supabase mechanics are
[ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md#identity-on-supabase-auth).

1. **Access-token hook** `app.custom_access_token_hook(event jsonb)`: looks up the device
   (or the guardian's personal device) for the Auth user and adds `household_id`,
   `device_id`, `device_class`, `profile_id` (personal devices only) to the claims. Grant
   it to `supabase_auth_admin` only. Enable it in `config.toml`.
2. **Setup wizard** — the `setup` Edge Function, callable only while no household exists,
   guarded by a one-time setup token printed at deploy time (never an open endpoint):
   household → first guardian (Auth user via the admin API, email + password) → PIN →
   remaining members → this device enrolled as the guardian's personal device.
3. **Device enrolment**:
   - `api.devices_create_enrolment_code(p_actor)` — guardian only; stores the code's hash,
     ten minutes, single use; returns the code and a QR payload.
   - `enrol-device` Edge Function — validates and consumes the code, creates an Auth user
     for the device, inserts the `app.device` row (label, class, register, bound profile),
     signs the user in and returns the session. Rate-limited.
   - The app stores the session in secure storage; Supabase refreshes it from then on.
4. **Tap-to-switch**: an acting-profile provider, the avatar row for `shared` and `kiosk`
   devices, the 60-second revert on kiosk, and every repository passing the acting
   profile into `api` calls.
5. **Guardian PIN**: `api.guardian_verify_pin(p_profile, p_pin)` — bcrypt compare,
   failure counter with backoff, lock after ten, sets `device.guardian_verified_until`.
   The numeric pad with no echo in the app.
6. **Revocation**: `api.devices_revoke(p_actor, p_device)` sets `revoked_at`; the
   `revoke-device` Edge Function signs that Auth user out. The app treats a 401/403 from
   a revoked device by wiping its session and showing enrolment.
7. **Guardian account features**: TOTP enrolment for the second factor (done). Passkeys
   (Supabase Auth beta): the code is in; now that the domain exists, set
   `[auth.webauthn] rp_id`/`rp_origins` to `wusel.example.org`, add iOS Associated Domains
   (`webcredentials:<domain>`), publish `/.well-known/assetlinks.json` for Android and the
   `passkeys` web SDK script in `web/index.html`, then test on a real device.
8. Tests: pgTAP for every function and policy (including "a member cannot create an
   enrolment code", "a PIN elevation expires"), Deno tests for `enrol-device`, widget
   tests for the avatar row and the PIN pad.

**Done when** a second phone is enrolled from the first with a code, a kiosk device
switches profile by tap and reverts, a PIN unlocks a guardian action for fifteen minutes,
and revoking a device locks it out on its next request.

---

## Step 6 — The shopping list, online only (M0.2)

> **Built 2026-10-11**, including the integration test (`app/test/integration`) and its CI step.

The first real feature, deliberately thin — just enough to exercise every layer:

- `app.shopping_list`, `app.shopping_item` with RLS; `api.shopping_items` view;
  `api.shopping_add_item`, `api.shopping_toggle_item`, `api.shopping_finish` — each
  writing audit and broadcasting `shopping:changed`.
- The list screen in the adult and kid registers: add, tick, finish.
- Realtime: a second device sees the change within a couple of seconds (NFR-5).
- Dart integration tests for the repository against the local Supabase, added to CI.

The offline outbox, tile picker and catalogue are M1.1 — not here.

**Done when** both parents' phones and the laptop share one list in real time over the
home network.

---

## Step 7 — Mobile release pipeline (M0.4)

*New with the move to native apps.* A PWA reached the iPhones by URL; native builds have
to be signed and distributed, and without a Mac this pipeline is the **only** way onto
the iPhones and iPads. That is why it comes before production rather than after it.

### Signing, once

- **iOS**: `fastlane match init` with git storage in the private `wuselwall-certificates`
  repository, then `fastlane match appstore` to create the distribution certificate and
  profile. The encryption passphrase goes in the password manager and into GitHub
  secrets — nowhere else. CI authenticates to App Store Connect with the API key, never
  an Apple ID password.
- **Android**: generate the upload keystore with `keytool`, store it base64-encoded as a
  GitHub secret and in the password manager, and enrol in **Play App Signing** so losing
  the upload key is recoverable. `android/key.properties` is written by CI at build time
  and is in `.gitignore`.
- **The first Android upload is manual.** Play Console requires the very first App Bundle
  to be uploaded through its web UI; CI takes over from the second.

### The workflow

`.github/workflows/release-mobile.yml`, triggered by a tag `v*.*.*`:

```yaml
name: release-mobile
on:
  push:
    tags: ["v*.*.*"]
permissions:
  contents: write   # to attach the APK to the GitHub Release

jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: "17" }
      - uses: subosito/flutter-action@v2
        with: { flutter-version-file: app/pubspec.yaml, cache: true }
      - run: ./app/tool/write_android_signing.sh     # keystore + key.properties from secrets
        env: { ANDROID_KEYSTORE_B64: ..., ANDROID_KEYSTORE_PASSWORD: ..., ... }
      - run: >
          flutter build appbundle --release
          --build-name=${GITHUB_REF_NAME#v} --build-number=${{ github.run_number }}
          --dart-define-from-file=env/dev.json
        working-directory: app
      - run: bundle exec fastlane android internal   # upload_to_play_store, track: internal
        working-directory: app/android
        env: { PLAY_SERVICE_ACCOUNT_JSON: ... }

  ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version-file: app/pubspec.yaml, cache: true }
      - run: >
          flutter build ios --release --no-codesign
          --build-name=${GITHUB_REF_NAME#v} --build-number=${{ github.run_number }}
          --dart-define-from-file=env/dev.json
        working-directory: app
      - run: bundle exec fastlane ios beta   # match(readonly) → build_app → upload_to_testflight
        working-directory: app/ios
        env: { MATCH_PASSWORD: ..., MATCH_GIT_BASIC_AUTHORIZATION: ..., ASC_KEY_ID: ..., ... }
```

Each platform's `Fastfile` holds two or three short lanes; the workflow stays thin, so a
release can also be run from a Mac with the same lanes if one becomes available.

### Server address

Releases are built with `env/dev.json`, the one environment at `https://wusel.example.org`
([ADR-013](adr/ADR-013-one-self-hosted-environment.md)). It is reachable from anywhere over
HTTPS, so the apps need no cleartext exception and work outside the home wifi too.

### Getting it onto the devices

- **iPhones and iPads**: each family member's Apple account is added in App Store Connect
  as an internal tester; they install the TestFlight app once and receive every build
  from then on. Verify early that the children's accounts can be added
  ([Q37](14-open-questions.md)); if not, Ad Hoc distribution to the iPads' UDIDs is the
  fallback.
- **Wall tablet and Android phones**: join the internal testing track by email; Play
  updates the app automatically.

**Done when** pushing a tag puts a new build on an iPhone, an iPad and the Android tablet
without anyone touching a cable.

---

## Step 8 — The one environment: secrets, proxy, backups (M0.3)

> **Built 2026-10-11** ([ADR-013](adr/ADR-013-one-self-hosted-environment.md)). It replaces
> the earlier plan of a production VPS, Caddy and `deploy.yml`. The operating guide is
> [10](10-deployment-and-ops.md).

1. **Own keys** for the CLI stack on the home server: `auth.jwt_secret`,
   `auth.publishable_key` and `auth.secret_key` in `supabase/config.toml`, read from the
   git-ignored `supabase/.env` (`supabase/.env.example` lists the names). CI writes the
   CLI's public defaults into its own throwaway `supabase/.env`.
2. **Public entry**: Cloudflare proxied record `wusel.example.org` → the home server's nginx
   with [`infra/nginx/wusel.example.org.conf`](../infra/nginx/wusel.example.org.conf): the four
   API prefixes to Kong on 54321, everything else 404.
3. **Backups**: [`infra/backup/backup.sh`](../infra/backup/backup.sh) nightly on the server
   (homeserver User Scripts), optional restic off-site and healthchecks ping;
   `scripts/remote-backup.sh` on demand; [`infra/backup/restore-drill.sh`](../infra/backup/restore-drill.sh)
   restores into a scratch database and counts rows.
4. **Setup token**: `scripts/remote-setup-token.sh` replaces the seed's `dev-setup` with a
   random token before the family sets up its household.
5. **Changing the database**: CI first, then `scripts/remote-backup.sh` →
   `scripts/remote-supabase.sh migration up` → `scripts/remote-pgtap.sh`. No deploy
   workflow: GitHub's runners cannot reach the home network, and one environment does not
   need one.

**Done when** the public URL answers only on the API prefixes, the stack runs on its own
keys, and the restore drill has restored a nightly dump once. *(Restore drill first run
2026-10-11, on test data: 0 errors.)*

---

## CI/CD at a glance

```
 feature branch ──PR──► ci.yml ─────────────── app · backend · functions · audit
                         │ green + review
                         ▼
                       main ──► by hand: backup → migration up → pgTAP (specs/10)
                         │
                         │ tag vX.Y.Z
                         ▼
                 release-mobile.yml ── Android AAB → Play internal track
                                    └─ iOS IPA     → TestFlight
```

- **Trunk-based**: short branches, squash merges, `main` always applicable to the one
  environment.
- **One version for everything**: the tag. Mobile builds report version and build number.
- **Backend before apps**: migrations must stay backwards-compatible with the previous
  app release, because phones update on their own schedule. Add columns and functions
  first, ship the app that uses them, remove old ones a release later.

### Secrets inventory

Every secret has exactly one home in CI or on the server, and a copy in the password
manager.

| Secret | Lives in | Used by |
|---|---|---|
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | GitHub secrets | iOS upload, match |
| `MATCH_PASSWORD`, `MATCH_GIT_BASIC_AUTHORIZATION` | GitHub secrets | iOS signing |
| `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | GitHub secrets | Android signing |
| `PLAY_SERVICE_ACCOUNT_JSON` | GitHub secrets | Play upload |
| `WW_JWT_SECRET`, `WW_SECRET_KEY` | `supabase/.env` on the development machine | the Supabase stack (CLI) |
| `RESTIC_PASSWORD`, backup-target credentials, healthchecks URL | `/srv/appdata/wuselwall/backup.env` on the server | backups |
| Cloudflare origin certificate and key | nginx container on the server | TLS between Cloudflare and nginx |
| Push credentials (APNs key, FCM service account) | Edge Function secrets | `push-send` |

The **publishable key** (`WW_PUBLISHABLE_KEY`) is not a secret — it is compiled into every
app via `app/env/dev.json` — and the **secret key never leaves `supabase/.env`**: not in
CI, not in the app, not in a shell history.

---

## Risks to watch in M0

| Risk | Sign | Response |
|---|---|---|
| Apple or Google account verification stalls | Step 7 blocked | Steps 1–6 and 8 do not depend on it; Android sideloading of a debug APK keeps the trial going |
| No Mac makes iOS problems opaque | A TestFlight build crashes on launch with nothing in the logs | TestFlight crash reports; a borrowed Mac for one evening; Codemagic's build logs as a second opinion |
| ~~WSL networking fights the LAN trial~~ | — | Resolved by ADR-013: the stack runs on the home server, reached over HTTPS |
| PL/pgSQL slows feature work | Simple functions take an evening each | Write the first three carefully as templates; generate the rest from them; revisit the escape hatch in ADR-010 |
| macOS CI minutes run out | Billing warning | iOS builds only on tags already; Codemagic's free tier as an overflow |
| Self-hosted Supabase upgrade breaks something | Containers fail after `pull` | Images pinned by digest; upgrades only deliberately, after a backup, following the self-hosting changelog |
