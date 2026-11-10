# PR checks and release qualification: performance review

Reviewed 2026-11-10 against `main` at `0e19debc`. The measurements below record the pre-change baseline. The approved implementation
is recorded in the final section; required context names and repository settings stay unchanged.

## Evidence and method

Read all 14 registered Actions workflows (including GitHub-managed Dependabot and
CodeQL), workflow sources, the active main ruleset, commit checks/statuses on PR #224,
and 1,212 workflow-run records from 2026-10-11 through 2026-11-10. Collected job/step
metadata for 78 selected runs: the latest 12 successful PR runs of each main workflow,
recent failures/cancellations, all five recent PR-policy runs, 12 PR CodeQL runs and
selected non-PR runs. Successful PR samples cover November 3–10, depending on workflow.
Failures and cancellations are excluded from successful execution medians. Reruns use
the API's latest job attempt, not the sum of previous attempts.

Durations below are job execution time, excluding time before a job starts. Workflow
elapsed times include initial waiting and dependencies. A job's pre-start delay does not
by itself identify whether runner availability or a concurrency group caused the wait.
The backend's repository-wide concurrency group is confirmed in its source. Runner
inventory returned no repository-owned runners; organization fleet capacity/topology was
not established. Raw API/log data stays outside the repository; no runner names or
operator configuration are recorded here.

Representative evidence on one commit (`9cea1ffb`, PR #224):

- [ci run](https://github.com/wuselwall/wuselwall-app/actions/runs/42891265786)
- [backend-ci run](https://github.com/wuselwall/wuselwall-app/actions/runs/42891265825)
- [docs run](https://github.com/wuselwall/wuselwall-app/actions/runs/42891265966)
- [CodeQL run](https://github.com/wuselwall/wuselwall-app/actions/runs/42891259057)
- [active main ruleset](https://github.com/wuselwall/wuselwall-app/rules/25797386)

## What runs on a PR

| Check/job | Typical execution | Samples | Required for merge? | Finding |
|---|---:|---:|---|---|
| docs / build | 33m 04s; range 30m 18s–42m | 12 | No | Full demo build, every screenshot, docs validation/build/browser checks and two uploads |
| ci / app | 12m 46s; range 12m 11s–14m 09s | 12 | Yes: `app` | Mostly serialized Flutter tests, plus SDK restore and production web smoke build |
| backend-ci / backend | 7m 20s; range 6m 47s–7m 27s | 8 executed | Yes, through `required` | Provisioning costs more than SQL/integration test execution |
| backend-ci / edge-functions | 25s | 8 executed | Yes, through `required` | Cheap Deno tests; shares an overbroad detector with the full backend |
| ci / scripts | 36s | 12 | Yes: `scripts` | Most Node tests are cheap; the SMTP smoke accounts for about 19s |
| ci / audit | 12s | 12 | Yes: `audit` | OSV scan of Dart, npm and both Ruby lockfiles; inexpensive |
| triage / policy | 9s | 5 | Yes, its `pr-policy` commit status | Labels/milestones and PR policy; runs on PR metadata events too |
| CodeQL | Four parallel jobs: about 40s, 46s, 52s and 62s | 12 runs | No in the current main ruleset | About 1m 08s elapsed, 3m 20s summed runner time; GitHub-hosted |
| backend-ci / changes and required | 14s and 5s | 12 | `required` is required | Small control jobs currently wait for the self-hosted build fleet |

The five required contexts are `app`, `scripts`, `audit`, `required`, `pr-policy`.
`policy` is the Actions job that posts the separate `pr-policy` status. On the inspected
PR, check providers were GitHub Actions and GitHub Advanced Security; the additional
commit status was `pr-policy`. No separate third-party check appeared in that snapshot.

Median elapsed time was 14m 20s for ci, 9m 10s for backend-ci and 33m 16s for docs.
The backend waited a median 69s, maximum 8m 53s, after its detector completed in the
executed successful sample. Actual merge readiness depends on the slowest required
context, usually app here. Removing PR docs reduces the time until *all* checks finish
and resource use, but docs currently does not block merging.

### Docs: the largest avoidable PR cost

`npm run docs:screenshots` takes a median 31m 14s of the 33m 04s job, approximately 94%.
There are currently 60 captures × four languages × two themes = 480 PNGs. The command
also compiles the Flutter demo. This runs for virtually any `app/**` change, including
non-visual changes, and then runs again after a matching merge to main. The source
already acknowledges that a full run can outlast the interval between main merges.

The representative run uploaded a 64,003,499-byte docs site and a 61,098,478-byte
screenshot archive: about 119 MiB combined. The site already contains its screenshots,
so these overlap. Both have one-day retention. Uploading is only about eight seconds;
duplicate storage, rather than upload time, is the concern.

### App: preserve regressions, address startup and selection

Median steps:

| Step | Time |
|---|---:|
| Flutter test wrapper | 8m 40s |
| Flutter action / SDK cache restore | 1m 34s |
| Production web build | 58s |
| Chromium install/dependencies | 27s |
| Analysis | 21s |
| Explicit pub get | 12s |
| Server-discovery browser regression | 6s |

The workflow explicitly sets `FLUTTER_TEST_CONCURRENCY=1` because of observed tester
crashes. The wrapper reruns only a narrowly recognized process crash, once; ordinary
failures still fail. Increasing concurrency without diagnosing those crashes is not a
supported optimization.

In the representative log, tests span 171 files. Summed first-to-last test-log spans
inside each file are about 207s versus about 503s across the whole test sequence. This
suggests substantial loading/compilation/process overhead between files; it is not a
profiler measurement. The largest file, `board_detail_a11y_test.dart`, spans about 20s
between its first and last test records. Moving that matrix alone to releases would
save a small part of the 8m 40s suite, not several minutes.

The SDK cache hit still restored an approximately 1.6 GiB archive in about 94s. A pinned,
preinstalled SDK in the disposable runner image could remove repeated transfer; this
requires checking fleet provisioning, not simply disabling the cache. Keep release
build/evidence isolation and version pinning.

### Backend: broad selection, expensive provisioning

Median steps include 123s for pinned image preparation, 92s for Flutter setup, 35s for
initial stack start, 32s for reset, 26s for pgTAP, 37s for mail-enabled integration, 37s
for the no-mail restart and 14s for no-mail integration. SQL/integration test removal
would discard important coverage while leaving much provisioning cost intact.

The same detector starts Deno and the full backend for *every* `app/lib/` change,
including widgets and demo rendering. Split server/SQL selection from client-contract
selection and Deno selection. Preserve full SQL/RLS tests for migrations and backend
changes, and integration tests for relevant repositories, models, transport, auth/server
configuration and integration-test inputs. UI-only changes should not automatically run
all migrations and Edge Function tests. Unknown changes/diff failures must run the full
gate; detector changes need tests for each selected and skipped case.

The image helper already reuses locally present images. Repeated 123s preparation
therefore calls for examining disposable-runner image availability/cache persistence,
not adding a redundant inspect check. One representative npm cache restore emitted many
extraction warnings before the job continued; investigate cache path portability. One
log is not evidence that every restore is broken.

Keep the stack's repository-wide lock until independent Docker/ports/storage isolation
has been established. Tests must continue to use disposable data.

## Recommended allocation

| PR checks | Full pre-release qualification / publication |
|---|---|
| PR policy, relevant scripts, vulnerability audit, CodeQL | Exact-candidate complete security/audit checks |
| Format, analysis, localization and unit/widget regressions for app inputs | Complete Flutter suite, golden/contrast and visual/a11y matrices |
| SQL/RLS and backend integration for server/client-contract changes | All migrations, pgTAP, lint, mail and no-mail integration regardless of paths |
| Production browser regressions for web/bootstrap/storage/auth changes | Complete production build/browser smoke and native Android/iOS checks |
| Guide locale/link/shot-definition validation, targeted changed-screen captures | Full 480-image guide matrix before docs publication and before release |

Full native, visual, pixel-control and production qualification is already manual-only
in `qualify-candidate.yml`. Native tool preflight, store listing, hosted deployment and
release orchestration are also not per-PR jobs. Android/iOS and signed server publishing
are tag/manual workflows. These are not the cause of PR latency.

The full docs matrix should remain on main publication as well as release qualification:
this project publishes the family guide after merges, independently of app releases.
Moving it only to app releases would allow unverified guide screenshots to publish.
Keep manual/explicit full preview available for a PR that needs it. A fast PR guide
check needs a separate shot-*definition* check: the existing `docs:check` requires every
PNG and cannot simply run unchanged without the full matrix. Preserve all-language
strings, guide parity and captures for new/changed screens.

## Release sequencing must be explicit

Moving a check to a tag trigger does not make publication wait for it. Today
`scripts/release.mjs` dispatches ci, backend-ci and mobile release workflows independently.
The signing workflows gate on `qualification/promotion.mjs` and protected review. That
promotion reads full candidate-evidence for the exact commit; it does not wait for the
separately dispatched ci/backend workflows. Candidate evidence currently aggregates
Flutter, web, native and production, without a backend/docs job.

Before deferring a check to release-only, add it to an exact-SHA pre-release aggregate
that publication must require. Prefer extending candidate evidence and promotion
validation. Every required job must complete successfully before tagging/signing or
publishing; a dispatch request, pending job, skipped full matrix or approval alone is
not a passing check. Preserve artifact provenance, full comparison, protected review and
existing signing boundaries. This is a sequencing requirement for the proposed change,
not evidence that a failing release has been published.

## Implementation order

1. Split fast PR guide validation from full screenshot/publication work. This removes
   about 31 minutes of screenshot generation per affected PR run. Keep full main/manual
   validation and add an exact-candidate release dependency.
2. Add tested, job-level input classification for app/browser/backend/Deno work. Ordinary
   docs-only PRs currently still pay the full required app job; UI-only app PRs can avoid
   the approximately seven-minute backend execution and its serialized queue. Preserve
   the five required context names with always-reporting aggregators; skip only irrelevant
   work, not the required workflow itself.
3. Keep audit, scripts, triage and CodeQL on PRs. Together they are inexpensive compared
   with the builds and provide early feedback. Use GitHub-hosted runners for cheap
   detector/aggregate work if consistent with the fleet policy, so it cannot wait behind
   compilation and database jobs. Adjusting that policy is an explicit part of the PR.
4. Investigate the SDK archive transfer, npm restore warnings and pinned backend image
   availability. Then measure isolated Flutter shards, each retaining concurrency 1,
   only if the fleet has capacity. Do not promise a faster app job without measurements.
5. Re-measure execution, queue delay and failures after the changes. Keep a full manual
   run on a PR available; verify pure docs, UI-only, client-contract, migration, dependency
   and workflow changes, plus fail-open detector behavior and failed-job propagation.

Expected savings above are the cost of work removed from affected PR runs, not a
benchmark of an implementation. Full app PRs would still have a roughly 13-minute app
job until the separate app/setup optimization is demonstrated. Docs-only required
checks can become much shorter through input classification.

## Relevant GitHub behavior

Required workflows skipped by path filters can leave a PR pending; conditional job
skips and an `always()` aggregate need deliberate failure propagation. See
[GitHub's required-check guidance](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).

The shared backend queue is deliberate: `queue: max` allows up to 100 pending jobs,
whereas the default retains one pending job. See
[GitHub concurrency documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency).

CodeQL comes from repository default setup, rather than a committed YAML file; it runs
on PRs, protected/default-branch pushes and a weekly schedule. See
[GitHub's code-scanning setup documentation](https://docs.github.com/en/code-security/concepts/code-scanning/setup-types).

## Applied after review

- Fast PR guide validation now uses `docs:check:source` plus a VitePress build. Full
  screenshots/browser checks remain in main/manual publishing and candidate qualification.
  Only the site preview archive is uploaded, plus a small checksummed evidence report.
- A shared tested classifier selects Flutter, browser, database and Deno jobs. It includes
  external dictionary/SQL inputs read by Flutter tests, both sides of renames, unknown
  paths and diff failures. Manual/reusable/tag runs are full. Required `app`/`required`
  statuses use tested always-reporting aggregates; selected failures/cancellations/skips
  fail them. Existing scripts, audit, CodeQL and PR policy remain.
- Detectors, aggregates, audit and Deno run on GitHub-hosted Ubuntu. Docker/SMTP script
  checks remain on the build fleet because they need service images; their scheduling
  cost is not treated as a plain Node control job.
- Candidate evidence reuses quality, full backend and full docs workflows. Schema 3
  summary/promotion requires their success and exact-SHA complete guide evidence before
  tagging/signing. The strict Flutter/production jobs own app/browser work so quality-only
  reuse avoids duplication. The orchestrator no longer starts duplicate ci/backend runs
  alongside signing. Existing protected approval and baseline gates remain.
- SDK/image prewarming, cache-path repair and Flutter sharding remain provisioning/
  measurement follow-ups. No runner machines or caches were changed. Savings in this
  audit remain estimates until measured on the new GitHub runs.
