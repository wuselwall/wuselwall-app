# Accessibility and UI qualification for release candidates

*Design agreed in outline 2026-10-25; the initial evidence suite is built in this branch.
Native runner validation and complete qualification remain open.*

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

The [initial evidence suite](../qualification/README.md) implements the shared inventory,
fixed Dart clock, Flutter matrix/detectors, browser screenshot/semantic comparison and
axe-core checks, integrity-checked baseline bundles, initial native rendering captures,
and the manually dispatched `candidate-evidence` workflow. It covers 25 initial states;
37 routes are explicitly pending in the inventory. Its summary always reports
`qualified: false`. Local Linux validation and its findings are recorded in the PR.

Native ATF/XCTest audits, complete state coverage, real-device and production-entry-point
checks, durable baseline review and release-promotion enforcement remain open. Existing
release uploads are not gated by this first slice. The native harness uses Flutter's SDK
`integration_test` initially; adoption of Patrol for system interactions follows the
native adapter proof below. Native behavior has not been validated on the Mac yet.

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

Introduce a versioned screen/state inventory with stable identifiers. Each entry names
its route or entry action, register, fixture, required states, supported configurations,
expected ready marker and assertions. Include dialogs, sheets, menus and scrolled content;
one picture of a screen's initial viewport is insufficient. Give exclusions a reason.

Inventory all currently shipped modules: server choice and onboarding; Today; shopping
and history; calendars and event templates/editors; school and timetable imports; tasks
and points; meals and recipes; kid and kiosk views; rituals; and every settings group,
including Basic and Advanced. Retained, hidden MCP/AI functionality is outside this UI
inventory and remains on hold. Developer-only screens are excluded from release coverage.

Fixtures cover populated, empty, loading, error, validation, offline/pending and permission
states where applicable, plus long names, large households and dense calendar/list data.
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

Share fixture and state definitions with documentation capture where practical. The
qualification runner must assert the destination state before comparing its screenshot;
a failed navigation must not produce a plausible picture of the previous screen. Keep
approved qualification baselines separate from uncommitted documentation image exports.

Sources: [Playwright visual comparisons](https://playwright.dev/docs/test-snapshots) and
[accessibility testing](https://playwright.dev/docs/accessibility-testing).

### Android and iOS: focused native evidence

Use pinned Patrol tooling for shared Dart journeys that cross the native boundary, plus
small native audit adapters. Prove compatibility with the repository's pinned Flutter
version before expanding coverage. Current Patrol documentation uses `$.platform` and
`patrol_test/`; do not copy the older specs/18 examples without checking their version.
Keep direct Playwright tests for the browser matrix and visual reports; a unified Patrol
web route is optional, rather than a prerequisite for native coverage.

For Android, audit the actual exported accessibility nodes using Google's Accessibility
Test Framework (ATF), with screenshot data where supported. Flutter exposes virtual
descendants, so first prove that the adapter visits their labels, bounds and actions.
An Espresso check of the native `FlutterView` alone is insufficient evidence. For iOS,
add XCTest `performAccessibilityAudit` at named checkpoints and save the `.xcresult` bundle.
The audit API needs a supported iOS runtime (introduced in iOS 17); older supported
runtimes still need applicable alternative checks and manual evidence.

Before trusting either adapter, inject a known bad target or missing label and a known
contrast failure into isolated test fixtures and require the appropriate checks to fail.
Record unsupported audit capabilities explicitly. The adapters must not invent successful
contrast measurements for elements they cannot inspect.

Native journeys cover server choice/sign-in, profile changes, Today, shopping and offline
restart, an event editor, kid/kiosk navigation, settings, a modal with the software keyboard,
and permission denied/granted paths. Capture named visual checkpoints on phone and tablet,
including Android edge-to-edge and iOS safe areas. Check notification and lifecycle behavior
where simulation supports it; retain the physical-device checklist for the remainder.

Use a separate hermetic test entry point with provider overrides for most visual states.
Also run a smaller set against a disposable backend and exercise the production entry
point. A fake-data build proves rendering of the real widgets, not authentication, plugin
wiring or the behavior of the distributable binary. Test launch controls and fixture
repositories must not enter the shipped production entry point.

Sources: [Patrol platform automation](https://patrol.leancode.co/documentation/native/overview),
[Google ATF](https://github.com/google/Accessibility-Test-Framework-for-Android) and
[Apple's automated accessibility audits](https://developer.apple.com/videos/play/wwdc2023/10035/).

## Resolution and configuration matrix

Express sizes in logical pixels/points and record physical resolution and device pixel
ratio separately. Testing a 1080-pixel phone at an incorrect logical width gives misleading
layout evidence. The initial profiles below are proposals, refined after inventory and
the first measured run.

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

Keep separate baseline namespaces for Flutter/Linux, web/browser/OS and native
platform/runtime/device. Never compare an Android screenshot to an iOS screenshot or a
Linux browser capture to a Mac baseline. Measure repeatability before enabling a small,
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

Implement a manually dispatched `qualify-candidate.yml` accepting a full candidate SHA
and approved baseline ID. Resolve and validate the SHA once; every job checks out that
SHA and verifies it. No job may silently check out the branch's later head. Initially
restrict runs to commits on the trusted release branch. Use timeouts and explicit runner
preflight failures; unavailable devices are `NOT RUN`, never a passing empty job.

The workflow runs existing candidate CI/backend checks, Flutter qualification, browser
qualification, Android and iOS qualification, then a final aggregate job. Run Android and
iOS sequentially on the Mac; Linux work can proceed in parallel. Backend-connected tests
use only a disposable stack with synthetic data. A Mac must not depend on Linux's
`localhost`: define a job-scoped reachable test endpoint or run a separate disposable stack
for the native lane. Store connection details in ephemeral CI state and clean up afterward.

Collect JUnit/JSON, screenshots and diffs, accessibility findings with element locations,
browser traces, native logs and `.xcresult` even on failure. The final report records
candidate and baseline SHAs/checksums, toolchain versions, device profiles, inventory
version, expected/executed counts, every result, narrow accepted exceptions with owner and
expiry, and the CI run URL. Missing required results, unexpected skips, expired exceptions,
unreviewed changes or failed uploads of required evidence prevent qualification.

Add a promotion gate to **both** mobile release workflows and the relevant server/web
release path. The gate verifies the successful aggregate workflow run and that the release
commit, baseline and build configuration match its evidence. It must also apply to manual
release dispatch; checking for an arbitrary green job name is insufficient. The workflow
must actually enforce these dependencies; independent workflows triggered by the same
tag do not wait for each other automatically.

Build distributables once where possible and promote the tested artifacts, recording
their digests. Simulator and instrumented test builds differ from store artifacts: record
that distinction, and retain signed-build smoke testing on physical devices before final
promotion. If rebuilding is required, record the exact inputs and perform the artifact
smoke again; matching source SHA alone does not establish binary identity. Any source
change after qualification requires a new run. Manual VoiceOver/TalkBack and physical
device evidence remains part of the promotion checklist.

## Implementation sequence and completion evidence

| Slice | Deliverable | Completion evidence |
|---|---|---|
| 1 | Inventory, deterministic fixtures/clock, capture environment and one screen through all three platforms; native audit adapters | Repeatable screenshots; known failures detected; actual virtual accessibility nodes inspected; all four locales render |
| 2 | Whole-app Flutter accessibility/layout matrix and web visual/semantic suite; baseline review tooling | Every inventory entry accounted for; deliberate regressions in an untouched screen, text contrast, target size, semantics and overflow block qualification |
| 3 | Focused native phone/tablet matrices and platform journeys | Successful Android/iOS runner runs, keyboard/safe-area/text-size evidence, native reports and recorded unsupported capabilities |
| 4 | Manual candidate workflow, durable approved baselines and enforced promotion dependencies | An unqualified SHA, a changed SHA, missing native evidence and an unapproved visual diff all block upload; a qualified candidate can promote |
| 5 | Initial baseline review, physical-device acceptance and operational tuning | Reviewed reports and checklist evidence; measured runtime, disk use and flake rate; documented baseline recovery/update procedure |

Keep early implementation runs informative until the inventory and baseline have been
reviewed; then make the complete gate blocking. Label that transition explicitly. Tests
must be able to fail usefully before the first candidate is described as qualified.
Do not retry away application failures. A narrow infrastructure retry preserves the first
failure and marks the report as flaky; unresolved flakes cannot count as clean evidence.

Estimate duration only after the vertical slice and case count are measured. The initial
goal is predictable unattended candidate qualification, not a promised minute budget.
If the Mac becomes the critical path, move Android to a proven KVM runner or add a second
native runner without changing baseline identities. Revisit cloud real-device coverage
only when device-specific failures or supported-version gaps justify it.
