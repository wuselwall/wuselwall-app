# Native candidate runner

Use an ARM64 macOS Actions runner with Xcode. Keep the runner labels, installation
paths and selected runtime identifiers in repository/organization variables; never
commit an operator's machine details. Run one native job at a time using the shared
`native-qualification-devices` concurrency group.

The qualification job selects the repository's Flutter version and JDK 17 with
Actions. It does not rely on an interactive shell's PATH, the machine's default
Java version, signing certificates or a configured backend. Run `npm ci --include=dev`
before the native scripts: PNG comparison uses the locked `sharp` dependency.
The app's `flutter.config.enable-swift-package-manager: false` keeps plugin builds
on its existing CocoaPods integration. A mixed SPM/Pods graph can build the app
through Flutter yet fail to resolve Flutter headers when XCTest builds the workspace.
Migrate the project as a whole before changing this setting; do not alter a runner's
global Flutter configuration to work around it.

Main execution phases emit begin/end markers and have deadlines. ADB startup and
state checks fail promptly; Android boot has a six-minute wall limit. Flutter
build/drive and Gradle phases allow twenty minutes, while native auditing allows
ten minutes for smoke or thirty for full coverage. Timeout exits with status 124
and retains available logs/evidence. Cancellation forwards to owned process groups
and exits; cleanup targets only the simulator ID and emulator process created by
that run. It does not kill a shared ADB server or personal devices.

For a complete local setup sequence, use [the copyable setup commands](setup-commands.md).

## Inspect before installing

The manual native preflight workflow only inspects the installed tools, CPU
architecture, simulator runtimes, AVDs and acceleration. It does not create devices,
install SDKs or sign/publish an application. Every probe is written even when a
prior tool is unavailable. An `X64` Actions label does not establish whether a
process is translated: compare `uname -m`, `hw.optional.arm64` and
`sysctl.proc_translated` in the artifact.

## Review the installation plan

```bash
bash qualification/native/provision.sh --dry-run
```

The default performs no downloads or filesystem writes. It prints the dedicated
SDK/AVD directories, exact package revisions and disk requirement. It works on
Linux for review; installation requires native ARM64 macOS.

`toolchain.json` pins the ARM64 command-tools archive and its SHA-256, Android API
36 (the current Flutter target), minimum API 24, build tools, NDK, CMake, emulator,
platform tools and both Google APIs ARM64 images. The installer skips matching
packages. It rejects installed or newly offered revisions that differ from the
pins; it never runs `sdkmanager --update`. Review a pin change and recapture the
native baseline when updating the toolchain.

The default free-space floor is 100 GiB for runtime archives, expanded SDKs, three
AVDs, Xcode builds and evidence. `QUALIFICATION_MIN_FREE_GIB` accepts 30..500; the
installer checks the existing parent filesystem before creating its directory.
It never deletes old caches, personal AVDs, simulator runtimes or other projects to
make room. Check free space again after installation before a full matrix.

## Apply once to a dedicated CI directory

The selected Xcode and its license/first-launch components must already be ready.
Choose a simulator runtime supported by that Xcode in Settings → Components, and
confirm it supports the simulator device types used by the matrix. Defaults are
`com.apple.CoreSimulator.SimDeviceType.iPhone-16` and
`com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4-8GB`; the full matrix
needs a runtime that supports both. If `QUALIFICATION_IOS_PHONE_TYPE` or
`QUALIFICATION_IOS_TABLET_TYPE` is set, use those device types instead. Check the
`supportedDeviceTypes` in `xcrun simctl list runtimes --json`, then record the
runtime's exact version, Apple build and CoreSimulator identifier as CI variables.
The script has no floating `latest` iOS fallback and never switches Xcode or accepts
its license.

Set these installation inputs in the operator's CI configuration:

| Variable | Purpose |
| --- | --- |
| `QUALIFICATION_TOOLS_ROOT` | Absolute dedicated directory; default is `wuselwall-qualification` under the runner tools/cache directory. |
| `JAVA_HOME` | JDK 17 selected by `actions/setup-java`. |
| `QUALIFICATION_IOS_VERSION` | Exact supported iOS simulator version. |
| `QUALIFICATION_IOS_BUILD` | Exact Apple runtime build, passed to `xcodebuild -buildVersion`. |
| `QUALIFICATION_IOS_RUNTIME` | Matching `com.apple.CoreSimulator.SimRuntime.iOS-…` identifier. |
| `QUALIFICATION_ACCEPT_ANDROID_LICENSES` | Set `true` only after the operator has reviewed and accepted Google's SDK licenses. Otherwise preaccept licenses interactively; unattended installation does not accept them. |

```bash
bash qualification/native/provision.sh --apply
```

The script uses Google's HTTPS archive, verifies its published SHA-256 before
unpacking, and downloads only stable, explicitly pinned SDK packages. It creates
three CI-only ARM64 AVDs: phone/tablet for API 36 and a minimum-API phone for API 24.
An existing CI AVD must match its ABI, image and hardware profile; the script never
force-replaces it. Native tests boot read-only, cold-started AVD copies and create
and delete their own iOS simulators.

For iOS, the script calls Apple's supported
`xcodebuild -downloadPlatform iOS -buildVersion … -architectureVariant arm64` only
if the pinned runtime is absent, then verifies the installed version/build. No
`sudo`, all-platform download, signing or store upload occurs.

On success, `$QUALIFICATION_TOOLS_ROOT/environment.env` contains the dedicated
`ANDROID_HOME`, `ANDROID_AVD_HOME` and the three `QUALIFICATION_ANDROID_*_AVD`
variables. In Actions, these are also appended to `GITHUB_ENV` for subsequent
steps. It does not modify shell startup files. Outside Actions, load the file into
the process environment using the operator's usual environment-management method;
do not check it into the repository. Preserve the same dedicated paths in later
qualification jobs.

## Candidate evidence

`bash qualification/native.sh` executes nine sequential profiles: iOS and Android
phone/tablet, the same four with enlarged native text, and the Android minimum-API
phone. Android enlarged profiles also raise display density by 25%. Large-text
results fail if the observed text scaling did not increase to at least 150%.

Each profile captures actual Flutter PNGs, then runs its native auditor against
Flutter's exported native semantics: Android ATF receives UiAutomation
`AccessibilityNodeInfo` trees, and iOS XCTest runs
`performAccessibilityAudit(for: .all)`. A deliberately bad control must be rejected;
native input must update a Flutter text field. Missing virtual semantics, lost
cases, subprocess failures, framework errors, detector misses or missing PNGs fail
the evidence. ATF `NOT_RUN` checks remain visible in the report; Flutter contrast
checks remain a separate required layer.

iOS findings retain the issue element's label, type, bounds and debug description;
the semantic snapshot also records bounds. Inspect those before changing a target
or assigning a label. With the pinned Flutter version, a label around a scroll
view labels a separate parent, and a label inside `buildViewport` can attach to
the first row instead of the generated native scroll container. These findings
remain open. Do not merge an entire list to quiet an audit: its controls must
remain independently discoverable and actionable. Merge a checkbox row only when
its name, state and action belong to that one control. See Flutter's
[Semantics API](https://api.flutter.dev/flutter/widgets/Semantics-class.html).

## Explicitly reviewed framework findings

No exceptions are enabled by default. The first supported review kind is an iOS
element-description finding for an unnamed `FlutterSemanticsScrollView`. Other
missing names, small targets, findings without element identity, Android findings,
detector/input failures, framework errors and failed subprocesses remain blocking.
Do not approve an application defect as a framework false positive.

Native XCTest/instrumentation collection checks execution, case accounting,
framework errors and detector controls. Accessibility errors still set each raw
case's `passed` value to false. The report, rather than the collector's exit status
alone, enforces accessibility findings and any explicitly approved adjudications.
Both the raw report and the applied review records remain in the evidence.

After a complete full native collection, the report writes
`native-review-candidates.json` alongside the evidence. These entries have
`disposition: pending`, no reviewer and no rationale. They cannot authorize
anything. Incomplete collection and smoke diagnostics cannot generate an eligible
review bundle.

To prepare a review:

1. Inspect the raw finding, its PNG and native semantic snapshot. Perform the
   relevant VoiceOver/device check and establish why it is a framework false
   positive. Keep the capture and its native manifest as review evidence.
2. Create a separate `native-review.json` with exactly these root fields:
   `schemaVersion: 1`, `kind: native-accessibility-reviews`, `candidateSha` and
   `entries`. Copy only individually reviewed entries from the candidate file.
   Change their disposition to `framework-false-positive`; supply a meaningful
   `rationale`, `reviewer` and ISO-8601 `reviewedAt`. Leave all fingerprints intact.
3. Publish that file as the `native-review.json` asset of a separate
   `a11y-review-*` GitHub Release, as an explicit operator action. Record its exact
   SHA-256 (`shasum -a 256 native-review.json`). Publication is not approval.
4. Dispatch a **full comparison** for that same candidate, supplying `review_tag`
   and `review_sha256` as well as the approved web/native baselines. The
   `review_approval` job requires approval through the existing protected
   `release-promotion` environment before the native job can apply the bundle.
   Its required reviewers and disabled administrator bypass are verified.

Each entry binds the full candidate SHA, device profile and case, complete native
environment fingerprint, exact PNG bytes, semantic snapshot and finding identity
(including type, label and bounds). Only the volatile native debug description is
excluded from the issue fingerprint. Source, toolchain, layout, pixels, semantics
or finding changes invalidate the entry. Unused, duplicate, malformed, wildcard,
pending or stale entries fail closed; a review cannot carry over to another commit.

The final summary records the approved manifest digest and applied record IDs.
Promotion verifies that digest against the protected review job's outputs. The
normal protected release approval is still required afterwards, and the automatic
summary continues to say `qualified: false`. No current finding has been approved
by implementing this mechanism.

`QUALIFY_MODE=capture` produces `build/qualification/native/capture` for review.
Capture never approves a release. After review, seal the bundle with its source
commit:

```bash
node qualification/native/baseline.mjs seal build/qualification/native/capture FULL_SOURCE_SHA
```

Publish the reviewed bundle separately using the baseline process in the main
qualification runbook. Native and web baselines have separate manifest digests.
For comparison, set `QUALIFY_MODE=compare`, `QUALIFY_NATIVE_BASELINE_DIR` and
`QUALIFY_NATIVE_BASELINE_SHA256`. Verification rejects altered manifests/files,
missing/extra snapshots, symlinks that escape the bundle and changed environment
fingerprints. It compares decoded RGBA pixels exactly and normalized native
semantics exactly. No native pixel tolerance is assumed before raster noise is
measured on the actual runner. The fingerprint includes Flutter, Xcode, macOS,
runtime build, Android image, display geometry, density, text scale and inventory.

Automated native implementation does not establish actual runner validation.
Retain the first execution's logs, `.xcresult`, PNGs, native audit findings and
summary. Physical VoiceOver/TalkBack, iOS Display Zoom, permission prompts and
interaction comfort still require the release checklist's device review.

The `release-ios` workflow's manual `native_smoke_only` mode selects `both`, `ios` or
`android` and runs only the corresponding phone profiles (`ios-phone` and/or
`android-phone`) with smoke cases. It uploads a short-lived diagnostic artifact and does
not run baseline comparison or release promotion. Its
`diagnostic.json` records `INCOMPLETE` even when both profiles pass; the
non-selected native profiles and all remaining candidate gates are still required for
qualification. An iOS-only run needs no Android SDK or JDK. If its configured iOS runtime
does not support the selected device, the diagnostic may use the newest already-installed
available runtime whose `supportedDeviceTypes` includes it. It records the selected
device type, runtime identifier, version, build and fallback reason in `diagnostic-runtime.json`.
It does not install runtimes, system images or accept licenses. The separate
`diagnostics_only` mode remains read-only runner preflight. Its `device-tools`
preflight mode records `WORKFLOW_BOOTSTRAP_REQUIRED` and the pinned Flutter version
when Flutter is absent, because the native workflow bootstraps Flutter before use.
It still fails when required Android SDK, AVD or acceleration checks fail. The
default preflight mode remains strict and requires Flutter to be on `PATH`.

## Sources

- [Android command tools archive and checksums](https://developer.android.com/studio#command-line-tools-only)
- [SDK package management and versioned command tools](https://developer.android.com/tools/sdkmanager)
- [AVD command-line management](https://developer.android.com/tools/avdmanager)
- [Google SDK repository metadata](https://dl.google.com/android/repository/repository2-3.xml)
- [Google ARM64 image metadata](https://dl.google.com/android/repository/sys-img/google_apis/sys-img2-3.xml)
- [Apple simulator runtime download/install commands](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components)
- [Apple automated accessibility audits](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:))
- [Android Accessibility Test Framework](https://github.com/google/Accessibility-Test-Framework-for-Android)
