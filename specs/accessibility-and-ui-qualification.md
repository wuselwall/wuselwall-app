# Accessibility and UI qualification for release candidates

*Updated 2026-10-26. The candidate workflow, broad Flutter/web inventory, native audit
adapters, reviewed-baseline comparison and release-promotion enforcement are implemented.
Native runtime execution, successful qualification and human acceptance remain open.*

The candidate must preserve the usability and appearance of the whole app, including
screens whose source did not change. Qualification runs on an explicitly selected commit,
on local runners, before that commit can be promoted. This extends
[18 — Testing strategy](18-testing-strategy.md) and supplies the implementation plan for
the accessibility portion of the [release checklist](release-checklist.md).

## Decisions and current state

The selected route is broad Flutter and web coverage, focused native Android and iOS
coverage, and an explicit manual qualification run. Use Linux for the broad matrix and a
native macOS runner for both mobile platforms, initially one virtual device at a time.
No paid device cloud is needed initially. The expanded suite has no pull-request, ordinary
push or nightly trigger. Existing fast CI checks continue to run as they do today.

The [candidate suite](../qualification/README.md) implements a shared 72-state inventory,
fixed Dart clock, bundled fonts, Flutter matrix/detectors, browser screenshot/semantic
comparison, axe-core checks and integrity-checked web/native baseline bundles. Every release
route is represented; the legacy settings redirect and developer-only diagnostics page have
explicit exclusions checked against production router code. The canonical matrix contains
580 browser and 1,160 Flutter cases; the full browser matrix contains 2,512 cases. All states
run regardless of which source paths changed. Route coverage does not imply exhaustive
coverage of every modal, permission outcome or backend-connected journey.

Native Android ATF and iOS XCTest audit adapters, virtual accessibility-node inspection,
known-failure/keyboard controls, phone/tablet and enlarged-text profiles, and native PNG and
semantic comparisons are implemented. Android app/instrumentation APKs compile; the iOS
project generator has been validated. These are implementation checks, not successful native
device runs. Real runtime execution and reviewed native baseline acceptance remain open.
Native platform interaction uses dedicated adapters and a test-only Flutter checkpoint
bridge; Patrol is not a current dependency.

The manually dispatched workflow also builds/exercises the production web entry point with
intercepted APIs. Android, iOS and server releases containing the web archive require
successful evidence for the exact release commit and approval of the protected
`release-promotion` environment. Capture, incomplete, skipped or failing runs cannot promote.
The final summary becomes `READY_FOR_REVIEW` only after all automatic requirements pass and
continues to report `qualified: false`; baseline acceptance and physical-device review are
human gates. Real backend authentication, signed-store-binary smoke and the rest of the
release checklist remain separate requirements. Operator-run deployment utilities are not
publishing-workflow qualification gates.

Local validation rendered all 180 direct fixtures in DE/EN/FR/ES and executed the earlier 70-state,
8,760-case Flutter matrix. Large-text layout and touch-target fixes were verified in a
672-case responsive rerun with no framework, label or target-size findings. Contrast findings
remain visible and blocking while attribution continues. The ordinary suite passed 1,574
tests with seven intentionally unconfigured backend integration tests skipped; the separate
disposable-backend CI job supplies their coverage. No qualified candidate or approved native
baseline is established by these local checks.

Existing palette/focused accessibility tests and illustration goldens continue in normal
CI. The older schedules and tooling examples in specs/18 are historical proposals; the
proposed nightly Android run is superseded by this candidate-only plan.

## Acceptance standard and its limits

Use WCAG 2.2 AA as the web acceptance target and apply the corresponding principles to
the native app, alongside the platform guidelines and WuselWall's stronger register rules.
The test report maps requirements to automated checks, manual checks and uncovered cases;
it does not call a green automated run a conformance certification.

| Concern | Automated checks | Human qualification |
|---|---|---|
| Text contrast | Approved foreground/background pairs; rendered Flutter text; native audits where measurable. At least 4.5:1 for ordinary text and 3:1 for qualifying large text | Text over gradients, images and complex custom painting where automated attribution is uncertain |
| Controls and focus | At least 3:1 for visual information necessary to identify controls and states against adjacent colours; keyboard focus visibility and reachability | Meaning and visibility of unusual states |
| Colour dependence | Text/icon/shape and semantic state assertions for members, completion, warnings and selection; grayscale and colour-vision simulation review sheets | Review protanopia, deuteranopia and tritanopia simulations; establish that meaning survives without colour |
| Interaction targets | Flutter's Android 48 dp / iOS 44 pt guidelines, and larger existing kid/kiosk targets | Reachability and comfort on physical devices |
| Text and layout | Text scaling, reflow, clipping, scrolling, safe areas, keyboard insets, rotation and breakpoint checks | Comfortable reading at kiosk distance and actual device display settings |
| Assistive technology | Accessible name, role, value, state and actions; focus traversal, modal focus and focus restoration | VoiceOver and TalkBack journeys, reading order, announcements and pronunciation |
| Motion and alternatives | Reduced motion, reduced animation, no flashing, accessible alternatives to dragging, and visual equivalents for essential audio | Native Reduce Motion and the complete experience with assistive technology |

Disabled controls and decorative graphics have different contrast requirements; encode
exceptions by their purpose rather than lowering the threshold for an entire screen.
Colour-distance metrics and simulations help review; neither proves that colours convey
their intended meaning. Assert the redundant cue itself.

Sources: [WCAG 2.2](https://www.w3.org/TR/WCAG22/) and
[Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing).

## One inventory, several test layers

The versioned screen/state inventory has stable identifiers, real destination widget types,
routes, registers, fixtures, supported configurations and expected ready conditions. Direct
fixtures compose production widgets under in-memory providers; the production entry point
never imports their controls. Add dialogs, sheets, menus and scrolled checkpoints as explicit
states when extending a journey; one initial viewport does not establish every interaction.
Exclusions require a reason and are checked against the corresponding production route
redirect or developer-only guard.

Inventory all currently shipped modules: server choice and onboarding; Today; shopping
and history; calendars and event templates/editors; school and timetable imports; tasks
and points; meals and recipes; kid and kiosk views; rituals; and every settings group,
including Basic and Advanced. Retained, hidden MCP/AI functionality is outside this UI
inventory and remains on hold. Developer-only screens are excluded from release coverage.

The current fixtures cover populated pages plus selected empty, error, offline, resend and
calendar-month states. Continue extending individual journeys with validation, pending,
permission, loading and modal checkpoints, long names, large households and dense lists.
State changes such as selecting a member or checking an item receive behavioral assertions
as well as visual checks. Fixture sizes are test cases, never assumptions in app logic.
The report lists expected and executed inventory entries; missing coverage fails the gate.
Route changes must update the inventory or record an explicit exclusion.

### Flutter: the broad accessibility and layout matrix

Reuse the repository fakes and existing app pumping helpers. Enable semantics and run
`textContrastGuideline`, `labeledTapTargetGuideline` and the appropriate platform target
guideline. Exercise both Android and iOS widget adaptations on Linux; an iOS widget variant
does not count as an iOS Simulator run. Add precise assertions for semantic states and
actions, keyboard traversal, focus, scrolling and layout.

Extend palette coverage to every permitted colour pairing and interaction state, including
focus, selection, error, member accents, paper tints and alpha-composited backgrounds.
Test representative rendered components as well as tokens. Flutter's text contrast
checker estimates colours from rendered pixels and semantics: complex backgrounds,
custom painting and missing semantic text need additional assertions or review. A screen
with no auditable text or controls must not silently appear to have complete coverage.

Use bundled fonts for rendered contrast checks and text goldens. Keep the expanded tests
in a directory explicitly selected by qualification, outside default `flutter test`
discovery; otherwise a candidate-only suite would accidentally run on every PR. Existing
fast accessibility and illustration tests stay in the ordinary suite.

### Web: visual regression and browser accessibility

Use Playwright Test for approved screenshots, semantic/ARIA snapshots, keyboard journeys,
and browser console/page errors. Chromium runs the broad visual matrix. Firefox and
WebKit run a smaller compatibility matrix across DE/EN/FR/ES. Browser support failures
remain visible in the report. Playwright WebKit does not replace native iOS Safari tests.

Enable Flutter semantics before locating accessible elements. Assert that a known screen
heading and interactive elements are exposed before auditing. Add axe-core checks for
applicable DOM/ARIA rules and record incomplete checks. Flutter paints the UI into canvas;
DOM colour checks alone cannot validate the colours of the painted text or controls.
Use the Flutter layer and native audits for that coverage, with explicit custom-paint tests
for important non-text visuals.

The implementation retains the initial axe report. Scroll-clipped target-size findings get
a real-input checkpoint: the same DOM element must become fully visible inside all clipping
ancestors and pass a fresh audit. Replacement nodes, inaccessible scroll regions and true
size failures cannot pass this check. Other axe findings remain blocking throughout.

Share fixture and state definitions with documentation capture where practical. The
qualification runner must assert the destination state before comparing its screenshot;
a failed navigation must not produce a plausible picture of the previous screen. Keep
approved qualification baselines separate from uncommitted documentation image exports.

Sources: [Playwright visual comparisons](https://playwright.dev/docs/test-snapshots) and
[accessibility testing](https://playwright.dev/docs/accessibility-testing).

### Android and iOS: focused native evidence

The native lane uses Flutter SDK `integration_test` for rendering captures and separate
Android/iOS audit adapters for exported platform nodes. A test-only checkpoint bridge
mounts the same synthetic-data fixtures and records their semantic tree, framework errors
and display metrics. Android instrumentation visits the accessibility hierarchy through
UI Automator/ATF; iOS XCTest invokes `performAccessibilityAudit`. Both have detector and
keyboard checkpoints before their results can count. Keep fixture controls and native audit
adapters outside the production application entry point. Patrol can be evaluated for future
system-dialog journeys; it is not required to run the implemented lane.

For Android, audit the actual exported accessibility nodes using Google's Accessibility
Test Framework (ATF), with screenshot data where supported. Flutter exposes virtual
descendants, so first prove that the adapter visits their labels, bounds and actions.
An Espresso check of the native `FlutterView` alone is insufficient evidence. For iOS,
add XCTest `performAccessibilityAudit` at named checkpoints and save the `.xcresult` bundle.
The audit API needs a supported iOS runtime (introduced in iOS 17); older supported
runtimes still need applicable alternative checks and manual evidence.

The adapters include isolated bad-control and keyboard checkpoints and require meaningful
exported Flutter nodes. Missing nodes or failed detector controls fail aggregation. ATF can
mark contrast `NOT_RUN` for virtual nodes, which cannot replace the required Flutter contrast
check; reports must not invent measurements for elements the platform cannot inspect.

Native's focused inventory covers server choice, Today, shopping, calendar, settings and
kid/kiosk surfaces across phone/tablet and four locales in light/dark. Enlarged-text profiles
check iOS accessibility text size and Android 200% font with increased display density. A
keyboard checkpoint requires a real software keyboard to open without fixture framework
errors. It is not evidence for every production permission dialog or authenticated journey.
Retain notification/lifecycle, Display Zoom, VoiceOver/TalkBack and signed-build smoke in the
physical-device checklist.

The separate production web lane compiles `lib/main.dart` in release mode and exercises
server discovery, encrypted-storage migration and shopping with intercepted APIs. Real
backend-connected integration tests belong to the disposable-backend CI lane, never a
family's live server. Fixture rendering and simulator audits do not establish production
authentication or signed distributable behavior.

Sources: [Patrol platform automation](https://patrol.leancode.co/documentation/native/overview),
[Google ATF](https://github.com/google/Accessibility-Test-Framework-for-Android) and
[Apple's automated accessibility audits](https://developer.apple.com/videos/play/wwdc2023/10035/).

## Resolution and configuration matrix

Express sizes in logical pixels/points and record physical resolution and device pixel
ratio separately. Testing a 1080-pixel phone at an incorrect logical width gives misleading
layout evidence. The inventory and native profile definitions are the executable coverage
contract; the table below also records broader manual/compatibility acceptance targets.

| Layer or concern | Required configurations |
|---|---|
| Canonical screen/state visuals | All inventory entries, DE/EN/FR/ES, light/dark, one primary size per applicable register; night for kiosk and relevant shared components |
| Responsive layouts | Every screen, all four languages, relevant narrow phone 320/360, normal phone 390, tablet 768/820, landscape tablet/wall 1280×800 and desktop/wall 1920×1080 profiles; use explicit heights and record them |
| Breakpoint boundaries | Derive from actual layout code; test below, at and above each boundary, including calendar widths 599/600/601; combine with text scaling where layout uses scaled width |
| Text and display accessibility | 1× and 2× text for adult/kid screens, selected worst cases at the largest supported native text size/nonlinear scaling; real browser zoom/reflow; bold text, high contrast and reduced motion on representative components and journeys |
| Window constraints | Portrait/landscape, narrow tablet split view, keyboard visible, safe-area insets, and scroll to the final control |
| Native Android | Phone and tablet on a pinned current supported API; a focused compatibility run on the minimum supported API, with all four locales represented |
| Native iOS | iPhone and iPad on a pinned current supported runtime; focused minimum-supported-version evidence where a compatible runtime/device is available, with all four locales represented |

Do not multiply every dimension blindly. Canonical visual coverage crosses locales and
themes; responsive coverage crosses locales and relevant sizes; stress tests combine
known risky dimensions. Native checks focus on platform differences and essential flows.
Publish the actual generated case count and excluded combinations before the run.
All native languages get real runs; only checking translation-file parity is insufficient.

## Stable baselines and unintended-change detection

Run the entire inventory for every candidate, regardless of changed paths. A change to a
shared theme, font, localization or component can break an untouched feature. Combine
visual comparison with semantics and behavior checks: pixels alone cannot detect a lost
button action or inaccessible control that still looks correct.

Pin Flutter, fonts, browser revisions, OS/runtime/system images, emulator renderer and
capture settings. Use a fixed application clock, locale, timezone, seeded fixture data,
image content and scroll position. Browser clock mocking alone does not establish that
compiled Dart time is frozen. Wait for fonts, images and an explicit ready condition;
avoid using arbitrary sleeps as a correctness signal. Reset storage and providers between
cases. Freeze motion for still screenshots, and test animation/reduced-motion behavior
separately so the screenshot mode cannot conceal a runtime defect.

Keep separate baseline namespaces for web/browser/OS and native platform/runtime/device;
existing Flutter illustration goldens retain their own Linux environment. Never compare an
Android screenshot to an iOS screenshot or a Linux browser capture to a Mac baseline. Measure repeatability before enabling a small,
documented tolerance. Mask only specific nondeterministic system regions, such as a status
bar; do not mask application text or apply a broad percentage tolerance to hide noise.

The approved baseline is an immutable, reviewed version, initially bootstrapped from a
known-good commit and then associated with a qualified release. Candidate output never
becomes its own baseline automatically. Initially store approved PNG bundles as dedicated
GitHub Release assets under `ui-baseline-*` tags, with their manifest and SHA-256 checksums
reviewed in Git. Use a distinct tag prefix so baseline publication does not trigger mobile
or server releases. Treat bundles as immutable, verify their checksums on every download,
and retain a backup; an asset replaced through GitHub's interface must fail verification.
Candidate reports remain Actions artifacts, with a durable copy of accepted release
evidence. Actions artifacts alone are not durable baseline storage because they expire.
Reconsider Git/LFS or another versioned store if the first measured bundle warrants it.

Review expected/actual/diff images and semantic changes in a browsable HTML report. An
intentional change lists the affected inventory IDs and reason in a reviewed change
manifest. Changes outside those IDs remain failures; changing a shared component may
legitimately require reviewing many IDs. Approving a visual change cannot waive an
accessibility failure. Removed snapshots and newly uncovered states require review too.
If a baseline or manifest is committed after testing, qualify the resulting new commit.

## Runner layout

| Runner | Work | Constraints |
|---|---|---|
| Linux build fleet | Flutter qualification, pinned Playwright browsers, report generation, disposable backend | Fixed capture environment; no production data or signing credentials |
| Native macOS | Android ARM64 emulator and iOS Simulator, one at a time initially | Pinned Xcode/runtime and Android images; power, awake availability and disk space; exclusive access to virtual devices during the job |
| Optional Linux emulator runner | Android moved off the Mac if it becomes a bottleneck | Usable `/dev/kvm`, matching CPU/system-image architecture, permissions and successful acceleration preflight |

A native Apple Silicon Mac can run all three platforms if a single machine is preferred;
that makes it the shared bottleneck and requires its own web baseline namespace. Keeping
the broad matrix on Linux preserves its capture environment and leaves the Mac available
for native builds. Do not run the emulator lane inside Docker on the Mac. Linux containers
can be considered only after verifying the actual KVM device mapping and accelerated
emulator boot; nested VM runners are a separate
constraint and should not be assumed to work. No KVM change is needed for the selected
initial Mac-native route. Check `emulator -accel-check`, an AVD cold boot and a Flutter
render before assigning any optional Linux emulator runner its capability label.

Use generic capability labels in workflows, and keep operator machine details outside
committed files. Serialize native test jobs across workflows that could use the same
runner. Use unique temporary device/data directories and guaranteed cleanup. Qualification
does not need distribution signing secrets. Keep its account and keychain separate from
release signing, and run candidate code only from trusted refs on self-hosted machines.

Source: [Android Emulator acceleration](https://developer.android.com/studio/run/emulator-acceleration).

## Candidate-only orchestration and promotion

The manually dispatched `qualify-candidate.yml` accepts the full candidate SHA, profile,
capture/comparison mode, reviewed baseline release tag and separate web/native manifest
digests. Dispatch from the default branch and supply its head captured at dispatch; preparation
requires the input SHA to equal the immutable event SHA before any candidate code executes.
Every job checks out that commit. A branch advancing later does not alter the candidate.
Historical/branch commits can be tested locally but cannot authorize promotion through this
workflow. Only reviewed default-branch code runs on persistent self-hosted runners.

The workflow runs ordinary Flutter checks, the expanded Flutter matrix, web qualification,
Android/iOS qualification and the production web smoke, then aggregates their artifacts.
Android and iOS profiles execute sequentially on native macOS; Linux jobs can run in parallel.
Unavailable tools/devices and missing reports fail; they never count as empty successful
jobs. Existing backend CI/checklist requirements remain independent of synthetic UI capture.
No candidate fixture contacts a live family server.

Collect JSON, screenshots/semantic snapshots and diffs, browser traces, native logs and
`.xcresult` even on failure. The aggregate validates complete expected case IDs, successful
jobs, matching candidate SHAs, reviewed baseline checksums, native detectors/audits and
production-entry evidence. It rejects partial/capture profiles, failed/skipped/flaky browser
cases, missing native profiles, unexpected result IDs and pending routes. Artifact names
include the workflow run attempt so evidence from a rerun cannot mix with an earlier attempt.

Android, iOS and server publishing workflows containing the web archive now depend on a
read-only promotion guard. It verifies the exact release SHA, qualification workflow source,
repository/default branch, explicit dispatch event, successful full comparison and
`READY_FOR_REVIEW` summary. It checks the summary artifact's run/attempt, expiration and
SHA-256 before accepting its contents. A green check with an arbitrary matching job name
cannot authorize release. Both tag and manual publishing paths use the guard.

Publishing additionally requires the `release-promotion` GitHub environment, at least one
required reviewer and administrator bypass disabled. The guard rejects absent or weaker
protection. The protected publishing/signing job waits for human review of baseline changes
and physical-device evidence. `summary.json` retains `qualified: false` even when automatic
evidence passes: `READY_FOR_REVIEW` invites acceptance, not an automated conformance claim.
Operator-run local deployment utilities and independent documentation/marketing releases
remain outside these project publishing workflows.

Build distributables once where possible and promote the tested artifacts, recording
their digests. Simulator and instrumented test builds differ from store artifacts: record
that distinction, and retain signed-build smoke testing on physical devices before final
promotion. If rebuilding is required, record the exact inputs and perform the artifact
smoke again; matching source SHA alone does not establish binary identity. Any source
change after qualification requires a new run. Manual VoiceOver/TalkBack and physical
device evidence remains part of the promotion checklist.

## Implementation sequence and completion evidence

| Slice | Implemented result | Remaining completion evidence |
|---|---|---|
| 1 | Shared inventory/clock, real-widget fixtures, Flutter/web detectors, native adapters | Actual native runtime node/detector results and repeatability measurements |
| 2 | 72 states account for release routes; whole-inventory Flutter and web PNG/semantic comparison; baseline integrity tooling | Resolve reported accessibility findings and review initial web/native baselines; extend modal/permission checkpoints with their journeys |
| 3 | Nine native phone/tablet, enlarged-text and Android minimum-API profiles; keyboard checkpoint and native report checks | Successful Android/iOS runtime runs, platform logs and physical-device behavior |
| 4 | Manual exact-commit workflow, strict evidence aggregation, verified artifact provenance and protected app/server promotion dependencies | Successful full comparison followed by protected reviewer acceptance; implementation rejects missing evidence now |
| 5 | Baseline review/runbook and fail-closed promotion protocol | Initial acceptance, VoiceOver/TalkBack and signed-device checklist; measured duration, resource use and flake rate |

The publishing gate is blocking now: missing native execution or reviewed baselines prevent
promotion. Capture runs remain useful diagnostic evidence but cannot authorize a release.
Complete baseline review, native runtime validation and physical-device acceptance before
describing any candidate as qualified.
Do not retry away application failures. A narrow infrastructure retry preserves the first
failure and marks the report as flaky; unresolved flakes cannot count as clean evidence.

Estimate duration only after the vertical slice and case count are measured. The initial
goal is predictable unattended candidate qualification, not a promised minute budget.
If the Mac becomes the critical path, move Android to a proven KVM runner or add a second
native runner without changing baseline identities. Revisit cloud real-device coverage
only when device-specific failures or supported-version gaps justify it.
