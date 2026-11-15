# Releasing during alpha, beta and live use

The current stage is **alpha**, selected by
[`qualification/release-policy.json`](../qualification/release-policy.json). Stage is
reviewed source configuration, not an optional dispatch input or inferred from a version
number. Unknown/missing stages fail. The release commit must belong to the default branch.

## Routine alpha release

1. Merge the change to `main`. Ordinary `ci` and `backend-ci` run there. CI covers
   formatting, analysis, unit/widget tests, dependency audit, script tests and the release
   web server-discovery/storage/shopping smoke. Backend CI covers Edge Functions, every
   migration and pgTAP, schema lint, and repository integration with and without mail on a
   disposable stack.
2. Use the existing `release` workflow on `main`: first dispatch with `dry_run=true`,
   then (only when asked to cut the release) with `dry_run=false`. It selects versions,
   runs the shared preflight before creating tags, starts the publishing workflows and
   rolls the milestone forward. Do not push release tags by hand. Manual Android/iOS
   builds remain available for a default-branch commit. A manual `upload=false` Android
   run still builds signed artifacts and uses the gate; iOS diagnostic modes stay independent.
3. Every publishing path calls `release-checks.yml`. Its plan waits for active ordinary
   CI at the exact SHA, reuses successful default-branch push/manual runs, and runs missing
   workflows through `workflow_call`. Fork/PR runs, different SHAs and similarly named
   workflows cannot supply evidence. A failed/cancelled check blocks release; rerun that
   check and then retry the release. An API error or wait timeout blocks release too.
4. Signing/building and existing distribution follow the shared gate. Alpha uses the
   `alpha-release` environment, without a qualification-review prerequisite. Server
   signing still uses its separate `server-release` environment. Checksums, minisign
   verification, provenance, locked dependencies, clean signing caches and existing
   credential protections remain. Android uploads use Play's internal track; iOS uses
   TestFlight. Publishing a server archive does not deploy it to a family's server.
5. Record the SHA/build, CI links and a focused smoke of the signed build on the device
   used by the alpha household: launch/connect, the changed journey, and any changed
   offline/resume behaviour. Record unresolved findings. This is alpha feedback, not a
   claim of full accessibility conformance or public-release readiness.

Ordinary CI no longer starts again just because a version tag is pushed. It runs on PRs,
`main` pushes and explicit dispatch, and is callable by the shared gate. PR checks may use
a different merge SHA; reuse never substitutes those results for the released commit.
The backend always runs in full on `main`, manual dispatch and release calls. Its PR
change detector remains. If multiple publishing workflows start before any standalone
CI exists, each may run missing checks; normally the `main` runs provide shared evidence.

### Environment credentials

Repository signing secrets still work. If Android/iOS signing secrets were scoped only
to `release-promotion`, also provision them in `alpha-release` before the first alpha
build; keep that environment limited to the intended release refs. Do not remove the
existing beta/live environment or its reviewer protections. Infrastructure may retain
additional approval rules on any signing environment; this policy does not edit GitHub
settings or relocate credentials. Release and candidate caches remain isolated.

## What repeats, and when

| Work | Alpha cadence | Beta/live cadence |
|---|---|---|
| Ordinary CI, security audit, disposable backend and web smoke | Each release SHA; reuse passing checks | Same |
| Signed-build smoke and changed-journey feedback | Each distributed alpha build | Each distributed candidate |
| Backup and isolated restore/migration checks (checklist section 3) | When migrating a live server; preserve backup-first rules | Same |
| Full Flutter/web/native qualification, baseline acceptance and physical accessibility review | Optional explicit diagnostic runs; findings remain open | Required on the exact release SHA |
| Protected `release-promotion` approval | Not a prerequisite of alpha qualification | Required before signing/publishing |
| Family trial, first-install timings, kiosk/performance acceptance | Milestone evidence; revisit affected findings | Complete before broader rollout; revisit affected evidence |
| Developer accounts, store/legal setup, signing keys, public website readiness | Installation/first-publication work | Must be complete and kept current, not recreated per patch |

The detailed [release checklist](release-checklist.md) remains the evidence inventory.
It does not require repeating the two-week trial or store-account setup for each alpha
patch. Local pgTAP is a diagnostic alternative while developing; a second local execution
of the same suites is not an additional release gate after disposable-backend CI passes.
Before live migrations, the existing backup/restore safeguards still apply.

The optional `candidate-evidence` workflow and native diagnostics remain available for
investigating a change during alpha. Capture/canonical/smoke evidence remains diagnostic;
it never becomes a full qualification verdict by virtue of the release stage.

## Entering beta or live

Change `stage` to `beta` (later `live`) in the policy file in a reviewed change. Before
tagging that commit, complete the deferred native audits, resolve findings and accept
immutable web/native baselines. Dispatch full comparison qualification for the resulting
default-branch SHA using the [qualification runbook](../qualification/README.md).

The shared gate then requires both ordinary CI/backend success **and** the existing strict
promotion guard: exact SHA, all Flutter/web/native/production jobs, full comparison,
verified baseline and summary artifact, plus a configured `release-promotion` environment
with required reviewers and administrator bypass disabled. Its publishing job waits for
that protected approval. Missing/expired evidence and diagnostic-only runs block release.
Any subsequent source change requires qualification of the new SHA. All exhaustive suites
and their fail-closed validators are retained.

## Public-progress handoff

The separate website repository owns public progress. Suggested matching DE/EN wording
for its next independently reviewed update (no website publication is implied here):

- DE: „WuselWall ist in der Alpha-Phase. Alpha-Builds durchlaufen die automatisierten
  App-, Sicherheits- und Backend-Prüfungen. Die vollständige Geräte- und
  Barrierefreiheitsqualifizierung bleibt Voraussetzung für Beta und öffentlichen Betrieb.“
- EN: “WuselWall is in alpha. Alpha builds pass automated app, security and backend
  checks. Full device and accessibility qualification remains required for beta and live use.”
