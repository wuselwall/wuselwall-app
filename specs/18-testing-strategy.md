# 18 — Testing Strategy

How WuselWall is tested, from the database up to the family's real devices, and where
each kind of test runs. Extends the CI notes in [16](16-setup-plan.md#step-4--continuous-integration-m00) and
the distribution decisions in [ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md).

**Candidate qualification implementation (2026-10-26):**
[Accessibility and UI qualification](accessibility-and-ui-qualification.md) and the
[runbook](../qualification/README.md) describe the manual candidate-only suite. Its
72-state inventory accounts for every release route, with verified redirect/developer-only
exclusions. Expanded Flutter guidelines, Playwright pixel/semantic comparisons, native
ATF/XCTest adapters, large-text/keyboard controls and production web-entry smoke are built.
Approved web/native baselines and physical-device review are required; native runtime
execution and existing accessibility findings still need resolution. Android, iOS and server
publishing enforce successful full comparison evidence for the exact commit, then protected
human approval. Capture/partial/skipped runs cannot promote. Existing fast CI retains its
schedule. This supersedes the older nightly/per-PR expansion proposals below.

*Proposed 2026-10-11.* A MacBook Pro is now available, which settles
[Q35](14-open-questions.md): iOS Simulator, Xcode and local iOS builds are part of the
plan below.

> **Status 2026-10-17 (base `43ac2e5`, candidate branch noted where it differs).** Layers 1, 3, 4 and 6 exist. Layer 2 has Deno tests
> beside the functions (`supabase/functions/_shared/*_test.ts`). At the base no CI step ran them, because `ci.yml` had no Deno step. The candidate
> adds an `edge-functions` job to `.github/workflows/backend-ci.yml`; no CI run of it is recorded in this file. Layers 5, 7 and 8 are not built: `app/test/golden`, `app/integration_test/`,
> `e2e/web/`, `scripts/e2e.sh` and `.github/workflows/e2e.yml` do not exist at that commit. Layer 9
> is [release-checklist.md](release-checklist.md), added with this status. This document records
> no device run and no live-server result.

## Devices on hand

| Device | Stands in for | Used for |
|---|---|---|
| MacBook Pro | The developer machine for iOS and Android | iOS Simulator (iPhone and iPad sizes), Android Emulator (phone and a 10" tablet for the kiosk), local iOS builds, `fastlane match` |
| iPhone | An adult's or older child's phone | On-device E2E over USB, TestFlight smoke |
| iPad | A child's device (kid register) | On-device E2E over USB, TestFlight smoke, rotation and split view |
| Samsung Android phone | Every Android phone, and the wall tablet until it is bought | On-device E2E over USB, Play internal-track smoke, Samsung-specific behaviour (One UI battery optimisation, Samsung Pass as passkey provider) |
| WSL laptop | — | Stays the backend and Linux-golden machine; no change |

## The layers

Most confidence comes from the cheap layers. Each layer tests what only it can see, and
nothing is tested twice at an expensive layer if a cheap one already covers it.

| # | Layer | Tool | Lives in | Runs | Status |
|---|---|---|---|---|---|
| 1 | Database: RLS, `api` functions, error codes | pgTAP | `supabase/tests/` | Tag or manual run always; pull request when backend-sensitive paths change (`backend-ci.yml`, candidate) | Exists |
| 2 | Edge Functions: ICS, recurrence, projection | `deno test` | `supabase/functions/**` | Same trigger as layer 1 (`edge-functions` job, `backend-ci.yml`, candidate) | Exists as `_shared/*_test.ts`; at the base no CI step ran it. Candidate adds the CI job; no run recorded here |
| 3 | Dart unit: domain, error mapper, `Result` | `flutter test` | `app/test/core`, `…/domain` | Every PR | Exists |
| 4 | Widget: screens with fake repositories | `flutter test` | `app/test/features`, `app/test/app` | Every PR | Exists; the extension below (`pumpWw`, guideline checks) is not built |
| 5 | Golden: pixels per locale × theme × form factor | `flutter test` + `matchesGoldenFile` | `app/test/golden` | Every PR | Started 2026-10-24: Wusel's poses, outfits and tufts (shapes only, no text) |
| 6 | Repository integration: Dart repositories against a real stack | `flutter test --tags integration` | `app/test/integration` | Tag or manual run always; pull request when backend-sensitive paths change (`backend` job of `backend-ci.yml`, candidate) | Exists |
| 7 | Native rendering and exported accessibility nodes | Flutter `integration_test`, Android ATF, iOS XCTest | `app/integration_test/`, `app/qualification/native_main.dart`, `qualification/native/` | Explicit candidate dispatch only | Adapters and required profiles built; Android app/test APKs compile; native runtime evidence open. Patrol is not installed |
| 8 | Web visual/semantic regression and release-entry smoke | **Playwright**, axe-core | `qualification/web/`, `qualification/production-smoke.mjs` | Explicit candidate dispatch only | Built; 580 canonical / 2,512 full fixture cases, plus production entry with intercepted APIs. Approved baseline acceptance remains open |
| 9 | Manual device check: what automation cannot reach | Checklist | [`specs/release-checklist.md`](release-checklist.md) | Before promoting a TestFlight/Play build | Added 2026-10-17; manual, no results recorded in the repository |

Note the naming: `app/test/integration/` stays the host-VM repository tests (layer 6).
Flutter's on-device tests go in `app/integration_test/` (layer 7), the directory the
tooling expects.

### Layer 4 — widget tests, extended

*Status 2026-10-17:* `app/test/features` and `app/test/app` exist. `pumpWw` and the guideline checks are not in `app/test` at `43ac2e5`; the list below is the plan.

The fakes in `test/support/fakes.dart` already make screens testable without a backend.
Add one helper, `pumpWw(widget, {locale, register, brightness, size, textScale})`, and use
it to run each screen test across:

- **all four locales** (`de`, `en`, `fr`, `es`) — German compounds and longer Romance
  strings are where overflow happens ("Einkaufslistenverlauf", French negatives);
  a `RenderFlex overflowed` error fails the test by default; include regional and unsupported
  locale fallback resolution in the locale tests.
- **every register the screen appears in** (adult, kid, kiosk);
- **text scale 2.0** for the adult and kid registers;
- the accessibility guidelines Flutter ships: `meetsGuideline(androidTapTargetGuideline)`,
  `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`.

Kiosk timing (the 60-second revert) is tested here with `tester.pump(Duration(seconds: 61))`,
never on a device.

**The clock.** A test never depends on when the suite runs. `baseOverrides` pins `nowProvider`
to `testNow()` (today at 10:30, outside the table question's meals, the look-back's Sunday
evening and the wall's night) unless the test names its own `now`. A test that builds "today"
into its data (a birthday, tonight's meal) takes it from `testNow()`, not `DateTime.now()`.
`flutter test --dart-define=WW_PROBE_SHIFT=<days>` moves `testNow()` by whole days, to check
that the suite passes on every weekday.

### Layer 5 — goldens

*Status 2026-10-17: not built.* No golden images or `update-goldens.sh` exist.

Screenshots compared pixel-for-pixel, for the screens whose look is the requirement: the
kiosk week board, the shopping list and tile picker, the acting-profile bar with member
colours, the setup and enrolment screens.

- Matrix per screen: `de` + `en` × light + dark (+ night for kiosk) × one size per
  register (phone 390×844, iPad 820×1180, kiosk tablet 1280×800). Roughly 6–10 images per
  screen; resist adding more.
- Fonts are bundled, so text renders real glyphs. Goldens are still platform-sensitive:
  **generate and compare on Linux only** (CI and WSL). On the Mac, update them through
  `scripts/update-goldens.sh`, which runs `flutter test --update-goldens test/golden` in
  the CI's Linux image under Docker.
- Tag them `golden` so `flutter test -x golden` stays available for a quick local loop.

### Layer 7 — native audits and future system journeys

*Status 2026-10-26:* the candidate lane has Flutter rendering captures, native ATF/XCTest
adapters, bad-control/keyboard checkpoints, phone/tablet and enlarged-text profiles, native
PNG/semantic baselines and strict result aggregation. Runtime/device execution is still
required; compilation and project-generation checks alone do not pass this layer.

The following Patrol proposal is historical future system-journey work, not the implemented
adapter or its schedule. The host-level repository and screen-count tests remain in
`app/test/integration/` and `app/test/journeys/` (J1–J3).

`integration_test` alone drives only Flutter widgets. It cannot accept the camera
permission dialog, toggle wifi, open a notification or press the system back button.
**Patrol** (LeanCode) adds native automation to the same Dart tests, runs on iOS
Simulator, Android Emulator and physical devices over USB, and reuses `fakes.dart` and
the repositories. It is the choice over Maestro (YAML, a second toolchain, no access to
the fakes) and Appium (heavy, slow, built for teams with a device lab).

Two modes, selected by `--dart-define-from-file`:

- **Hermetic** (`env/e2e-fake.json`): providers overridden with fakes. Fast, no network,
  deterministic. Most flows run this way.
- **Backed** (`env/ci.json`): a throwaway stack (CI, or `supabase start` on the laptop) —
  never a live server, which holds a family's data (ADR-013). A handful of flows only.

First flows:

1. First run → household setup → guardian signed in (backed). *From step 9
   ([20](20-onboarding.md)):* **J1**, front door → email code (read from Mailpit) → H1 → H2
   → Today, asserting **the number of screens** (NFR-17), so adding a step to onboarding
   fails a test and becomes a decision.
2. Enrol a second device by **typed code** — the QR path needs a camera, which simulators
   do not have; the scanner is a manual check (layer 9). *From step 9:* **J3**, pairing,
   with the test's side-channel client approving as the guardian.
2a. **J2** (backed): an invitation created by the side-channel guardian, accepted by code
   on the device under test after an email-code sign-up; screen count asserted. Plus the
   failure paths (expired invitation, wrong email code) in hermetic mode.
3. Shopping: add, tick, finish a list; history shows it (hermetic).
4. **Realtime across devices** (backed): the test's own Dart `ApiClient`, signed in as a
   second device, adds an item; the UI on the device under test must show it within five
   seconds. One phone plus a side-channel client proves the realtime path without driving
   two devices at once.
5. Acting-profile switch changes the accent colour and the register (hermetic).
6. Offline: Patrol turns off wifi; an item added and one ticked show at once with the
   "wartet" mark and the pending banner, and both reach the server when wifi returns
   (backed). The outbox's rules are covered below that, without a device: the projection
   and both stores in `shopping_outbox_model_test`, the drain, replay and rejection paths
   in `shopping_sync_test`, and `050_shopping_outbox` in pgTAP.

Selectors are `ValueKey`s from a single `core/testing/test_ids.dart`, never localized text,
so the same test runs in all four locales.

Patrol needs a small native setup (an `ios/RunnerUITests` target and the Android test
runner in `build.gradle`). Pin the Patrol CLI version in `pubspec.yaml` and the setup docs,
as with the Supabase CLI.

### Layer 8 — Playwright, for the web build only

*Status 2026-10-26:* `qualification/web/` contains the candidate fixture matrix with
Playwright PNG/ARIA comparisons, axe-core, hermetic-request and browser-error assertions.
`qualification/production-smoke.mjs` builds `lib/main.dart` and exercises intercepted-API
browser journeys. The virtual-authenticator proposal below remains separate work; it is
not established by fixture screenshot coverage.

Yes, Playwright still works, but within limits. Flutter web paints to a `<canvas>`
(CanvasKit or skwasm; the HTML renderer is gone), so there is no DOM text to find.
What Playwright can see is Flutter's **semantics tree**, which the engine mirrors as
`<flt-semantics>` elements with ARIA roles once accessibility is enabled. Hence:

- The web build enables semantics at start-up (`SemanticsBinding.instance.ensureSemantics()`),
  which also helps real screen-reader users of the laptop build.
- The few elements Playwright touches get `Semantics(identifier: TestIds.x)`, which the
  web engine renders as the `flt-semantics-identifier` attribute. The same identifier
  becomes the accessibility identifier on iOS and the resource ID on Android, so it
  serves any native tool later.
- Playwright is **not** the mobile test tool. It cannot drive the iOS or Android app.

Where it earns its place: it is the only layer that can test the **passkey ceremony
automatically**. Chromium's virtual authenticator (`WebAuthn.addVirtualAuthenticator`
over a CDP session) registers and signs in with a passkey against the real stack, with
no hardware. Scope stays at 3–5 specs: the app loads in each supported locale with German fallback, sign-in with
password + TOTP, passkey registration and sign-in, add a shopping item. Also cover mail
language selection for hook and SMTP independently of device locale.

It runs in the `backend` job after the repository integration tests, against
`flutter build web --release` served locally — the same artefact that is deployed.

### Layer 9 — the manual device check

Some things only a real device on the home wifi can show. Before a TestFlight or Play
build is promoted to the family, run [`specs/release-checklist.md`](release-checklist.md)
(≈ 20 minutes) on the iPhone, the iPad and the Samsung:

- Passkeys with the real providers: iCloud Keychain (iPhone, iPad), Samsung Pass and
  Google Password Manager (Samsung).
- **The timed walk-throughs (NFR-17):** J1, J2 and J3 with a stopwatch, by someone who has
  not seen the build. Write down the times and every hesitation. Universal links: an
  invitation link opens the app when installed and the landing page when not.
- Enrol by **scanning** the QR code with the camera.
- Realtime still arrives after the app was in the background for ten minutes — the
  Samsung's battery optimisation is the usual culprit.
- iPad: rotation, split view, and the kid register at arm's length.
- VoiceOver on one screen, TalkBack on one screen; system font size at maximum.
- Language switched on the device: DE/EN/FR/ES each show, nothing from another locale
  leaks; unsupported locales fall back to German.
- Push notifications are not built (Q38, Q47), so they are not a check for the pilot. The kiosk pinned on the wall tablet is a pilot check ([release checklist](release-checklist.md)).

## Where tests run

| When | Where | What |
|---|---|---|
| Every PR | Existing `ci.yml` app/audit jobs on the build fleet | Ordinary Dart/widget tests, existing focused accessibility tests and illustration goldens |
| Backend-sensitive PR, backend tag or manual run | Existing `backend-ci.yml` jobs and required aggregate | pgTAP, Edge Functions and backend-connected Dart tests on disposable data; skipped backend jobs are not execution evidence |
| Explicit candidate dispatch | `qualify-candidate.yml` on Linux | Ordinary checks, expanded Flutter matrix, browser comparison, production release-entry smoke and aggregate report; no changed-path selection |
| Same explicit candidate dispatch | Native macOS, serialized device use | Android ATF and iOS XCTest, native rendering/semantics, required phone/tablet, enlarged-text and compatibility profiles |
| Tag or manual app/server publication | Release workflow qualification guard, then protected `release-promotion` environment | Exact-commit full comparison and integrity-checked evidence, followed by human acceptance before publishing/signing |
| Before protected release acceptance | Physical devices, by hand | VoiceOver/TalkBack, native display settings, signed-build smoke and the remaining release checklist |

The expanded suite has no nightly, ordinary push or PR trigger. Device provisioning and
read-only preflight have separate manual runbooks. Compilation and an available runner do
not count as native execution evidence. If moving Android to Linux later, establish KVM
acceleration and a separate capture environment before enabling that runner capability.
A paid device cloud is not required for the selected local-runner approach.

## Order of work

*Historical proposal (2026-10-17):* T1–T4 below describe the original implementation order,
not current status or a remaining schedule. The candidate-only implementation and open
runtime/baseline/manual evidence are tracked in
[Accessibility and UI qualification](accessibility-and-ui-qualification.md). The release
checklist records evidence separately; repository implementation alone does not mark it PASS.

| Step | Work | Size |
|---|---|---|
| T1 | `pumpWw` helper; widget tests across DE/EN/FR/ES locales, registers, text scale and a11y guidelines; first goldens and `update-goldens.sh` | 1–2 evenings |
| T2 | Patrol set up on iOS and Android; `test_ids.dart`; flows 3 and 5 hermetic, green on simulator, emulator and the three devices | 1 weekend |
| T3 | Backed flows 1, 2, 4, 6; `e2e.yml` nightly on the Android emulator | 1 weekend |
| T4 | Playwright web smoke with the virtual authenticator, added to the `backend` job | 1 evening |
| T5 | `specs/release-checklist.md`, used for the first TestFlight/Play build (M0.4, setup step 7) | 1 evening, with step 7 |

From then on, each new module comes with layers 1, 3, 4 and 6 in the same change, adds
goldens for the screens it introduces, and adds an on-device flow only for what crosses
the native boundary or the network.

## Localized family guide

`npm run docs:check` checks FR/ES page and screenshot-reference parity with the English
guide, declared capture names and all four locales’ light/dark PNGs. `npm run docs:build`
checks internal links. `DOCS_BASE=/docs/ npm run docs:build` also verifies the retained
marketing-site mount; `npm run docs:browser` exercises navigation, local search, screenshot
locales and themes against that local build. CI exports all locales and checks every home page.
