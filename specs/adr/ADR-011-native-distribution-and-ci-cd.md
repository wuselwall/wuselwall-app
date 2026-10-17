# ADR-011 — Native app distribution and the CI/CD pipeline

**Status:** Accepted · 2026-10-11 · Follows from [ADR-010](ADR-010-flutter-and-self-hosted-supabase.md) ·
Amended by [ADR-013](ADR-013-self-hosted-compose-stack.md): one self-hosted stack, no `deploy.yml` ·
Amended by [ADR-014](ADR-014-self-service-onboarding.md): opening the app to other
households needs public distribution (TestFlight public link or the App Store, Play open
testing or production), decided in [Q42](../14-open-questions.md) · Amended by
[ADR-015](ADR-015-saas-and-self-hosted-flavours.md): **public App Store and Google Play
listings** once the developer accounts exist; store builds use `env/cloud.json`

**Amended 2026-10-17 ([00](../00-brief-and-decisions.md#2026-10-17--social-sign-in-removed)):** the auth deep link `ch.goomba.wuselwall://login-callback/` below is no longer in `Info.plist`, the Android manifest or the Supabase redirect URLs: it served social sign-in, which was removed. The identifier stands.

## Context

A PWA is distributed by visiting a URL. Native apps are not: every build for an iPhone or
iPad must be signed with an Apple certificate and delivered through a channel Apple
permits, and Android builds must be signed and installed. This app has exactly four
users and must never appear in a public store listing (01, out of scope:
commercialisation). The developer works on Windows/WSL; whether a Mac is available is
open ([Q35](../14-open-questions.md)).

## Decision

### Application identity

*Amended 2026-10-11.* The application ID on Android and the bundle ID on iOS are both
**`ch.goomba.wuselwall`** (see [ADR-010](ADR-010-flutter-and-self-hosted-supabase.md#starting-point-and-identifiers)).
They replace the placeholder `de.<domain>.wuselwall` used in earlier drafts and the
starter's `com.example.*` values. Consequences for this pipeline:

- One identifier on both platforms: the App Store Connect app record, the Google Play
  Console app, the `fastlane match` provisioning profiles (`match` type `appstore`, app
  identifier `ch.goomba.wuselwall`) and the Android upload keystore all refer to it.
- It cannot be changed after the first upload to either store, which is why it was fixed
  before any record was created.
- The auth deep link `ch.goomba.wuselwall://login-callback/` is registered in the iOS
  `Info.plist` URL types and the Android manifest intent filter, and allow-listed in the
  Supabase redirect URLs (`additional_redirect_urls` in `supabase/config.toml`).
- Marketing and build metadata: display name `WuselWall`; the iOS `RunnerTests` target
  uses `ch.goomba.wuselwall.RunnerTests`.
- Release builds must run `flutter gen-l10n` (implicit in `flutter build`) and CI fails
  on any message missing from either `app_en.arb` or `app_de.arb`.

### Distribution

| Platform | Channel | Why |
|---|---|---|
| **iOS / iPadOS** | **TestFlight**, internal testing, via the **Apple Developer Program** | The only route that installs on a family member's device without a cable or a Mac, updates itself, and needs no App Review for internal testers. Builds expire after 90 days, which a release every few weeks makes irrelevant. |
| **Android** (wall tablet, any Android phone) | **Google Play internal testing track** | Automatic updates on the wall tablet without touching it, no review for internal tracks, a one-time registration fee. A signed APK attached to a GitHub Release remains the fallback. |
| **Laptop browser** | The Flutter **web build**, served as static files by each server | Nothing to install. |

Fallback for iOS if TestFlight proves awkward for the children's accounts: **Ad Hoc**
distribution to the registered UDIDs of the household's devices, installed from a web page. Decided in [Q37](../14-open-questions.md) once both are tried on a real iPad.

### CI/CD on GitHub Actions

Two workflows, one responsibility each (`deploy.yml` was dropped by ADR-013: migrations
are applied to a server by script, after a backup). Detail in [16](../16-setup-plan.md#cicd-at-a-glance).

| Workflow | Trigger | Does |
|---|---|---|
| `ci.yml` | Every pull request: the fast checks. A tag `v*.*.*`, or "Run workflow" on a branch: everything | Pull requests: Flutter format, analyse, unit and widget tests. Tag or by hand, additionally: web build; `supabase start` → apply every migration from zero → pgTAP tests (RLS included) → schema lint; Deno format, lint and test for Edge Functions; dependency audit |
| `release-ios.yml` | A tag `v*.*.*` | iOS (macOS runner): `fastlane match` for signing → `flutter build ipa` → TestFlight |
| `release-android.yml` | A tag `v*.*.*` | Android: signed App Bundle → Play internal track (until then a signed APK and the App Bundle for a manual upload) |

- **Signing material never lives on a laptop alone.** iOS certificates and profiles live
  encrypted in a private repository managed by `fastlane match`; the Android upload
  keystore is stored base64-encoded as a GitHub secret and in the password manager.
- **Versions come from the tag** (`v1.4.0` → `1.4.0`) and build numbers from the CI run
  number, so they always increase.
- **iOS builds only run on tags**, never on pull requests: macOS runner minutes on a
  private repository are billed at ten times the Linux rate and the free allowance
  covers roughly ten iOS builds a month.
- **No staging environment.** One landscape per server (ADR-013). Migrations are instead
  rehearsed in CI against an empty database on every pull request and, before risky
  releases, against last night's restored backup (the restore drill doing double duty).

## Alternatives considered

**Public App Store / Play Store listing.** Rejected: review overhead, a privacy policy
and store metadata for an app with four users, and a public footprint for a family's
private system.

**Free Apple provisioning (no developer programme).** Builds expire after seven days and
need Xcode on a Mac connected to each device. Unworkable for children's iPads.

**Sideloaded APK only, for Android.** Free and simple, but every update means touching
the wall tablet, and Google's developer-verification requirement for sideloaded apps on
certified devices is being rolled out. The Play internal track removes both problems for
a one-time fee.

**Codemagic or Bitrise instead of GitHub Actions.** Purpose-built for Flutter, with
generous free macOS minutes. Not rejected — the fallback if GitHub's macOS minutes run
short — but keeping CI next to the code and the existing GitHub decision (Q3) is simpler
to start.

**Building iOS locally on a Mac with fastlane.** Fastest feedback, no minutes consumed.
Complements CI rather than replacing it, if a Mac is available (Q35).

## Consequences

**Positive**

- Pushing a tag puts a new build on every family device without anyone touching a
  cable, and the wall tablet updates itself.
- Database changes cannot reach production without passing the same migrations and RLS
  tests in CI first.
- Every secret has one documented home and a backup in the password manager.

**Negative**

- **Recurring cost**: the Apple Developer Program is €99 a year, roughly €8 a month on its
  own. With no rented server (ADR-013) the total stays inside the original €10/month
  target ([Q36](../14-open-questions.md)).
- **iOS without a Mac is CI-only**: no simulator, no Xcode debugger. iOS-specific bugs
  are diagnosed from logs and TestFlight crash reports. A borrowed or second-hand Mac
  mini is the remedy if this hurts.
- **More moving parts at release**: certificates expire yearly, the Play upload key must
  never be lost, TestFlight builds lapse after 90 days. Each is a calendar reminder,
  listed in [10](../10-deployment-and-ops.md#updates).
- Apple and Google become parties to the build and update process — not to a household's
  data, which stays on its own server.
