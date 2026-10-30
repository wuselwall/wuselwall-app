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
`diagnostics_only` mode remains read-only runner preflight.

## Sources

- [Android command tools archive and checksums](https://developer.android.com/studio#command-line-tools-only)
- [SDK package management and versioned command tools](https://developer.android.com/tools/sdkmanager)
- [AVD command-line management](https://developer.android.com/tools/avdmanager)
- [Google SDK repository metadata](https://dl.google.com/android/repository/repository2-3.xml)
- [Google ARM64 image metadata](https://dl.google.com/android/repository/sys-img/google_apis/sys-img2-3.xml)
- [Apple simulator runtime download/install commands](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components)
- [Apple automated accessibility audits](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:))
- [Android Accessibility Test Framework](https://github.com/google/Accessibility-Test-Framework-for-Android)
