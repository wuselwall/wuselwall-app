# 18 — Testing Strategy

How WuselWall is tested, from the database up to the family's real devices, and where
each kind of test runs. Extends the CI notes in [16](16-setup-plan.md#step-4--continuous-integration-m00) and
the distribution decisions in [ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md).

*Proposed 2026-10-11.* A MacBook Pro is now available, which settles
[Q35](14-open-questions.md): iOS Simulator, Xcode and local iOS builds are part of the
plan below.

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
| 1 | Database: RLS, `api` functions, error codes | pgTAP | `supabase/tests/` | Tag or by hand | Exists |
| 2 | Edge Functions: ICS, recurrence, projection | `deno test` | `supabase/functions/**` | Tag or by hand | When the first function lands |
| 3 | Dart unit: domain, error mapper, `Result` | `flutter test` | `app/test/core`, `…/domain` | Every PR | Exists |
| 4 | Widget: screens with fake repositories | `flutter test` | `app/test/features`, `app/test/app` | Every PR | Exists — extend (below) |
| 5 | Golden: pixels per locale × theme × form factor | `flutter test` + `matchesGoldenFile` | `app/test/golden` | Every PR | New |
| 6 | Repository integration: Dart repositories against a real stack | `flutter test --tags integration` | `app/test/integration` | Tag or by hand (`backend` job) | Exists |
| 7 | On-device E2E: the real app on a simulator, emulator or phone | `integration_test` + **Patrol** | `app/integration_test/` | Nightly (Android), before a release (iOS, devices) | New |
| 8 | Web smoke: the release web build in a browser | **Playwright** | `e2e/web/` | Tag or by hand | New, small |
| 9 | Manual device check: what automation cannot reach | Checklist | [`specs/release-checklist.md`](release-checklist.md) | Before promoting a TestFlight/Play build | New |

Note the naming: `app/test/integration/` stays the host-VM repository tests (layer 6).
Flutter's on-device tests go in `app/integration_test/` (layer 7), the directory the
tooling expects.

### Layer 4 — widget tests, extended

The fakes in `test/support/fakes.dart` already make screens testable without a backend.
Add one helper, `pumpWw(widget, {locale, register, brightness, size, textScale})`, and use
it to run each screen test across:

- **both locales** — German compounds are where overflow happens ("Einkaufslistenverlauf");
  a `RenderFlex overflowed` error fails the test by default;
- **every register the screen appears in** (adult, kid, kiosk);
- **text scale 2.0** for the adult and kid registers;
- the accessibility guidelines Flutter ships: `meetsGuideline(androidTapTargetGuideline)`,
  `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`.

Kiosk timing (the 60-second revert) is tested here with `tester.pump(Duration(seconds: 61))`,
never on a device.

### Layer 5 — goldens

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

### Layer 7 — on-device E2E with Patrol

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
  never the one environment, which holds the family's data (ADR-013). A handful of flows only.

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
so the same test runs in both locales.

Patrol needs a small native setup (an `ios/RunnerUITests` target and the Android test
runner in `build.gradle`). Pin the Patrol CLI version in `pubspec.yaml` and the setup docs,
as with the Supabase CLI.

### Layer 8 — Playwright, for the web build only

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
no hardware. Scope stays at 3–5 specs: the app loads in both locales, sign-in with
password + TOTP, passkey registration and sign-in, add a shopping item.

It runs in the `backend` job after the repository integration tests, against
`flutter build web --release` served locally — the same artefact that is deployed.

### Layer 9 — the manual device check

Some things only a real device on the home wifi can show. Before a TestFlight or Play
build is promoted to the family, run [`specs/release-checklist.md`](release-checklist.md)
(≈ 20 minutes) on the iPhone, the iPad and the Samsung:

- Passkeys with the real providers: iCloud Keychain (iPhone, iPad), Samsung Pass and
  Google Password Manager (Samsung).
- **Sign in with Apple** (iPhone natively; the Samsung through the web redirect) and
  **Sign in with Google** (Samsung natively; the iPhone too). Neither can be automated:
  both need a real account and the provider's own UI.
- **The timed walk-throughs (NFR-17):** J1, J2 and J3 with a stopwatch, by someone who has
  not seen the build. Write down the times and every hesitation. Universal links: an
  invitation link opens the app when installed and the landing page when not.
- Enrol by **scanning** the QR code with the camera.
- The auth deep link `ch.goomba.wuselwall://login-callback/` returns into the app.
- Realtime still arrives after the app was in the background for ten minutes — the
  Samsung's battery optimisation is the usual culprit.
- iPad: rotation, split view, and the kid register at arm's length.
- VoiceOver on one screen, TalkBack on one screen; system font size at maximum.
- Language switched on the device: German and English both show, nothing English leaks
  into the German UI.
- Later: push notifications (M1.6) and the kiosk pinned on the wall tablet.

## Where tests run

| When | Where | What |
|---|---|---|
| Every PR | GitHub Actions, `ubuntu-latest` (`ci.yml`) | Layers 3–5. |
| A tag `v*.*.*`, or "Run workflow" on a branch (always before a migration) | GitHub Actions, `ubuntu-latest` (`ci.yml`) | Layers 1–6 and 8. Target: under 10 minutes. |
| Nightly on `main` | GitHub Actions, `ubuntu-latest` with KVM, Android Emulator (`e2e.yml`) | Layer 7, hermetic and backed, on a phone AVD and a 10" tablet AVD |
| Before a release | The MacBook: `scripts/e2e.sh ios` | Layer 7 on iPhone and iPad simulators, then on the physical iPhone, iPad and Samsung over USB |
| Before promoting a build | The three devices, by hand | Layer 9 |

Why not iOS in CI: macOS runners bill at ten times the Linux rate, which would eat a
private repository's free minutes within a few nightly runs. The MacBook does that job
before each release, and a self-hosted runner on it can be added later if releases become
frequent.

**Device farms** (Firebase Test Lab, BrowserStack, AWS Device Farm) are not needed: four
users, four devices, and the family's own hardware already covers the real-device matrix.
Firebase Test Lab, which Patrol supports, is the fallback if an Android-model-specific
bug ever shows up; its free tier allows a few physical-device runs a day.

## Order of work

| Step | Work | Size |
|---|---|---|
| T1 | `pumpWw` helper; widget tests across locales, registers, text scale and a11y guidelines; first goldens and `update-goldens.sh` | 1–2 evenings |
| T2 | Patrol set up on iOS and Android; `test_ids.dart`; flows 3 and 5 hermetic, green on simulator, emulator and the three devices | 1 weekend |
| T3 | Backed flows 1, 2, 4, 6; `e2e.yml` nightly on the Android emulator | 1 weekend |
| T4 | Playwright web smoke with the virtual authenticator, added to the `backend` job | 1 evening |
| T5 | `specs/release-checklist.md`, used for the first TestFlight/Play build (M0.4, setup step 7) | 1 evening, with step 7 |

From then on, each new module comes with layers 1, 3, 4 and 6 in the same change, adds
goldens for the screens it introduces, and adds an on-device flow only for what crosses
the native boundary or the network.
