# Candidate evidence suite

This is the first implementation of the
[qualification design](../specs/accessibility-and-ui-qualification.md). It collects
evidence; it cannot issue a qualified verdict yet. The inventory contains 25 states and
explicit pending routes. Native platform audits, baseline review, physical-device review,
production-entry-point smoke and promotion enforcement remain open. The manual workflow
is named **candidate-evidence** to preserve that distinction.

## What runs

- Flutter: real fonts, four locales, Android/iOS widget adaptations, light/dark and kiosk
  night, semantics, labels, target sizes and rendered text contrast. The responsive tier
  adds relevant widths, 599/600/601 boundaries and 100/200% text. No path-based selection.
- Browser: the release-compiled synthetic-data entry point; stable screenshots and ARIA
  snapshots; axe-core DOM/ARIA checks; console/page errors; blocked external requests.
  Chromium runs the broad matrix. Firefox/WebKit can run focused compatibility checks.
- Native: initial synthetic-data Flutter rendering captures on iPhone/iPad simulators
  and Android phone/tablet emulators, sequentially on macOS. These are not native ATF or
  XCTest accessibility audits, system-dialog tests or store-binary checks.
- Detector tests: deliberately bad contrast, a small unlabeled action and an unlabeled
  HTML button must be detected. Baseline integrity tests reject altered/missing/extra files
  and a mismatched capture environment. Inventory validation rejects unaccounted routes.

Expanded tests live outside `app/test/` and are never discovered by ordinary `flutter
test`. The new workflow has only `workflow_dispatch`; existing CI/release workflows are
not changed. Its source commit must be on the repository's default branch, so the first
native workflow run follows merge. Local runs can exercise the branch before merge.

## Run locally

From the repository root, install locked npm packages and resolve app dependencies with
the pinned Flutter SDK. No backend or credentials are required.

```sh
npm ci
cd app
flutter pub get --enforce-lockfile
cd ..
npm run qualify:check
cd app
flutter test --no-pub qualification_test --dart-define=QUALIFY_MATRIX=smoke
cd ..
npm run qualify:build-web
npx playwright install chromium
QUALIFY_MODE=capture QUALIFY_MATRIX=smoke npm run qualify:web
```

Profiles are `smoke`, `canonical`, `responsive` and `full`. Workflow choices omit the
standalone responsive tier; `full` includes it. Canonical coverage has 204 browser cases
and 408 Flutter cases, before detector tests. The full browser matrix has 852 cases; the
Flutter responsive tier also crosses text scaling and widget platforms. Native's smoke
profile uses German/light, and its full profile uses all four locales/light/dark.

Browser output is under `build/qualification/web/` (HTML report, JSON and failure traces),
and unapproved screenshots/semantics under `build/qualification/capture/`. Flutter findings
are in `build/qualification/flutter/<profile>/results.json`. Failing rules fail their tests; no
existing findings are suppressed. The first runs are expected to expose current UI issues.
Flutter's histogram-based contrast checker can misread image/text regions: review those
findings against the pixels instead of weakening the threshold globally. axe's DOM colour
rule is explicitly unsupported for the canvas; its report records that limitation.

For optional browser compatibility coverage:

```sh
npx playwright install firefox webkit
QUALIFY_BROWSERS=chromium,firefox,webkit QUALIFY_MODE=capture QUALIFY_MATRIX=canonical npm run qualify:web
```

The fixture has its own entry point and fixed Dart clock. It does not use production
storage or connect to a server. Keep qualifications separate from docs image exports and
from the production entry point. When extending the inventory, regenerate its native
subset with `node qualification/generate-native.mjs`; `qualify:check` detects stale output.

## Review and compare a baseline

Run the full intended capture profile on a fixed Linux environment. Inspect destinations,
images, accessibility findings and coverage. A capture with missing states cannot qualify
the complete inventory. Resolve findings before accepting a release; a screenshot approval
does not waive an accessibility failure.

After review, explicitly seal a **copy** of the capture directory with the exact source
commit. Sealing records file digests and the capture environment; it does not approve it.
Review the manifest and its digest separately. Keep the approved digest in version control.

```sh
node qualification/baseline.mjs seal /tmp/reviewed-baseline <full-source-sha>
QUALIFY_BASELINE_DIR=/tmp/reviewed-baseline \
QUALIFY_BASELINE_SHA256=<reviewed-manifest-sha256> \
QUALIFY_MODE=compare QUALIFY_MATRIX=canonical npm run qualify:web
```

Comparison verifies the manifest and every snapshot before launching the browser, then
checks screenshots and semantics with a measured perceptual threshold of 0.04 and zero
pixels allowed above that threshold. The repeatability probe found only emoji resampling
noise (maximum RGB channel delta 9/255); `npm run qualify:pixel-controls` proves that this
noise passes and a real colour change still fails. Semantic files use `-aria.yml`, matching
Playwright’s snapshot-name normalization. An absent snapshot
fails; normal comparisons never create or update approved images. Changing the toolchain,
OS, renderer or inventory needs a separately reviewed baseline migration. Local captures
are not interchangeable with a different runner's environment.

The workflow can load `web-baseline.zip` from a separately published `ui-baseline-*` GitHub
Release. The archive root contains `manifest.json` and browser directories such as
`chromium/`; zip the contents rather than a parent directory. The workflow verifies the
reviewed manifest digest supplied with dispatch. Publication is a separate operator action;
this suite never publishes or approves baselines automatically. Retain approved bundles
and accepted evidence durably; ordinary Actions artifacts expire after 30 days.

## Provision the native runner

Use a native macOS Actions runner with Xcode, a pinned iOS Simulator runtime, CocoaPods,
Android command-line SDK/emulator, platform tools and ARM64 system images. Use CI-only
AVDs with no family accounts or data. Install the
Android SDK/platforms required by `app/android/`. The workflow supplies Flutter, Node and
Java; it does not install virtual devices, change machine settings or use signing secrets.

Set repository variables after inspecting `xcrun simctl list runtimes`, `xcrun simctl list
devicetypes` and `emulator -list-avds` on the runner:

| Variable | Meaning |
|---|---|
| `QUALIFICATION_IOS_RUNTIME` | Exact available CoreSimulator runtime identifier |
| `QUALIFICATION_IOS_PHONE_TYPE` | Optional phone type; defaults to iPhone 16 |
| `QUALIFICATION_IOS_TABLET_TYPE` | Optional tablet type; defaults to 11-inch iPad Pro M4 |
| `QUALIFICATION_ANDROID_PHONE_AVD` | Pre-provisioned ARM64 phone AVD |
| `QUALIFICATION_ANDROID_TABLET_AVD` | Pre-provisioned ARM64 tablet AVD |

The runner environment needs `ANDROID_HOME`. The script checks acceleration, creates
disposable iOS devices, uses Android read-only AVDs on a dedicated unused port, and cleans
up only its own devices/processes. It tries every profile and preserves failures. The
profile type/runtime/image are part of evidence; upgrading them requires review.

Run `bash qualification/native.sh` with the same variables for local diagnosis. A single
profile such as `bash qualification/native.sh android-phone` is also available. Do not run
this lane in a Mac container. Linux KVM runner provisioning is optional future work.

Native device behavior has not been validated from the Linux development environment.
The first PR records Linux findings; record the first real Mac run separately. The workflow summary always reports `qualified: false`
while the remaining gates are open. Existing release upload paths are not gated yet.
