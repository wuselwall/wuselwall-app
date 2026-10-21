# Release checklist — pilot household and first builds

This checklist decides whether a candidate build and server are fit for the pilot household
(M1.6, [13 — Roadmap](13-roadmap.md)), and which checks have only been planned. It is
executable: each item says what to run or look at, what passes, and where the evidence goes.
It was written at base `43ac2e5` (2026-10-17). It records no results. Every Result field is
`NOT RUN` until someone runs the check and writes the evidence.

**Base history and the CI matrix.** At base `43ac2e5`, `ci.yml` ran the `app` and `website`
jobs on every pull request and the `backend` job only on a tag or a manual run, and no CI step
ran the Deno tests. That is history, not the current state. The candidate branch adds
`.github/workflows/backend-ci.yml` and moves the backend and Edge Function jobs into it; the
CI matrix in section 2 describes the candidate. Which workflow ran on a given commit is read
from that commit's CI run, not from this file.

Testing layers and where they run: [18 — Testing strategy](18-testing-strategy.md). Operator
commands and the server stack: [10 — Deployment and operations](10-deployment-and-ops.md).

## 0. Rules for this checklist

**Status words.** Each item ends `PASS`, `FAIL`, `NOT RUN` or `N/A` (with the reason). A `PASS`
without an Evidence entry counts as `NOT RUN`. A check that could not be run is `NOT RUN`, never
`PASS`. Nothing in the repository is evidence of a deployed state, a device behaviour or a
provider's behaviour by itself.

**Automatable or manual.** Each item is marked:

- `CI`: runs in a GitHub Actions workflow (`ci.yml`, or `backend-ci.yml` for the backend and
  Edge Function gate) on the trigger the matrix in section 2 gives.
- `Local`: a command someone runs by hand (not in CI).
- `Manual`: needs a person, a device, a provider's own interface or a stopwatch. Automation
  cannot replace these.

**Unknown is not failed.** A fact the repository cannot show (a server's state, a provider's
setting, a device's behaviour) is `NOT RUN`, with the reason written next to it. `FAIL` needs an
observed failing result, and "missing" needs an observed absence. Do not infer either from the
absence of evidence.

**Non-destructive safeguards. These apply to every item.**

1. Never run `supabase db reset`, `wuselwall restore`, or `flutter test test/integration` against
   a server that holds a family's data. ([ADR-013](adr/ADR-013-self-hosted-compose-stack.md))
2. Never clear, delete or reset a family's live data as a test step, and never tell a tester to
   do it. Whether any development data is removed from a server is the operator's written
   decision, taken after B1 and B2 pass. It is not a step of this checklist.
3. The daily `household-purge` and the account deletion remove data for real. Do not invoke the
   purge or a deletion by hand on a live server. Only read its state (S4).
4. Restores are tested only in an isolated target (a separate host or compose project). The
   `restore-drill.sh` on a live host creates a scratch database next to the live one. It is a
   weaker check and does not satisfy B2.
5. Do not create synthetic households on the pilot server. Test with the family's own accounts.
   A test artefact (a feed token, a test calendar entry, a test device) is created for one check,
   recorded, and removed by that same check.
6. Migrations are forward-only. A live migration runs only after B1 and B2 pass on the same day.
7. Record variable names and results only. Never write a key, token, password, session, feed
   address with a token, or a host name, SSH alias or machine name into this file or into
   Evidence. Use `<pilot-server>`, `<candidate-sha>` and similar placeholders.
8. The timed walk-throughs (section 5) are run by someone who has not seen the build.

## 1. Candidate record

Fill in before any other section. One record per run.

| Field | Value |
|---|---|
| Candidate commit (SHA of the checkout that produced the builds) | |
| Git tag, if any | |
| App build: iOS (TestFlight build number), Android (APK or AAB version code) | |
| Server release or compose ref (`server/wuselwall` version, or the commit of `infra/`) | |
| `api_version` the candidate app expects and the value `api.server_info()` returns (base `43ac2e5`: `api_version` 1, from migration `20261014200000_server_info.sql`) | |
| Latest migration in `supabase/migrations` at the candidate (base `43ac2e5`: `20261015105000_jobs_skip_deleted.sql`) | |
| Pilot server label (placeholder only, e.g. `<pilot-server>`) | |
| Tester(s) and date | |
| Run summary (PASS / FAIL / NOT RUN counts) | |

## 2. Automated and local gates on the candidate commit

CI matrix at the candidate (the trigger decides what runs; a skipped job is not a pass):

| Workflow and job | Pull request | Tag `v*.*.*` or manual run | Runner |
|---|---|---|---|
| `ci.yml` `app` (analyse, tests, format; web build) | Yes; the web build step is skipped | Yes, with the web build | GitHub-hosted for a PR; self-hosted build fleet for a tag or manual run |
| `wuselwall-website` CI (build, strict legal, SSR/SEO smoke) | Yes | Yes | In the separate website repository (ADR-019) |
| `ci.yml` `audit` (osv-scanner) | Yes | Yes | As `app` |
| `backend-ci.yml` `changes` (reads `git diff` only) | Always | Always treated as backend-sensitive | GitHub-hosted |
| `backend-ci.yml` `edge-functions` (Deno tests) | Only when `changes` finds a backend-sensitive path | Yes | GitHub-hosted for a PR; self-hosted for a tag or manual run |
| `backend-ci.yml` `backend` (throwaway Supabase stack, pgTAP, Flutter integration) | Only when `changes` finds a backend-sensitive path | Yes | GitHub-hosted |
| `backend-ci.yml` `required` (aggregate) | Always | Always | GitHub-hosted |

The backend-sensitive paths are listed in the `pattern` of `backend-ci.yml`'s `changes` job:
`supabase/`, the npm and Deno lockfiles, `backend-ci.yml`, `app/test/integration/`, `app/lib/`,
`app/pubspec.yaml`, `app/pubspec.lock`, `app/env/ci.json` and `app/dart_test.yaml`. Branch
protection should require the check named `backend-ci / required`, not `functions` (the name
in an older plan). The exact check name GitHub shows for it is not verified until a real run.

| ID | Check | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| A1 | `app` job: `flutter analyze --fatal-infos`, `flutter test` (includes the DE/EN/FR/ES ARB, placeholder and native-permission parity tests, the screen-count tests in `app/test/journeys/` and the widget tests) and a format check | CI | The job is green on the candidate SHA | NOT RUN | CI run link |
| A2 | Website CI in `wuselwall/wuselwall-website` (build, SSR/SEO smoke) | CI | Green on the website commit that is live with the release. Placeholders in the Impressum are allowed here; the website's deploy refuses them | NOT RUN | CI run link |
| A3 | `audit` job: `osv-scanner` over the lockfiles | CI | Green, or each finding listed in `osv-scanner.toml` with its reason and expiry | NOT RUN | CI run link |
| A4 | `backend` job in `backend-ci.yml`: `supabase db reset` on a throwaway stack, `supabase test db`, `supabase db lint --level warning`, `flutter test test/integration` | CI. Always on a tag or a manual run. On a pull request only when `changes` finds a backend-sensitive path; a skipped run is not evidence for the migrations | Green on the candidate SHA, with `backend-ci / required` green. Required before a migration goes to any live server | NOT RUN | CI run link |
| A5 | Local pgTAP over every migration and suite: `cd scripts/local-pgtap && npm ci && node run.mjs` | Local | Exit 0; no `not ok` in the output | NOT RUN | command, exit code, output file |
| A6 | Edge Function unit tests: `deno test supabase/functions/ --allow-env --allow-read --node-modules-dir=none --lock=deno.lock --frozen` | CI, the `edge-functions` job of `backend-ci.yml`, with the same trigger rule as A4 (Deno 2.5.6, `--frozen` on `deno.lock`). At base `43ac2e5` no CI step ran them | Green on the candidate SHA. A local run is a second record, not a substitute | NOT RUN | CI run link; or Deno version, command, output file |
| A7 | Documentation: `npm run docs:check` and `npm run docs:build` in the repository root | Local | Both exit 0. `docs:check` needs the screenshots from `npm run docs:screenshots` present in `docs/public/screenshots/` | NOT RUN | command, exit code |
| A8 | Website build with legal and link strictness: `LEGAL_STRICT=1 LINKS_STRICT=1 npm run build` in `wuselwall/wuselwall-website` | Local, before a website deploy | Fails while a `TODO` value remains. Record which fields still fail. Do not fill a value in to pass | NOT RUN | command, output of the failing fields |

## 3. Backup, migration and restore

Run in this order. Stop at the first FAIL.

| ID | Check | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| B1 | Backup taken on the pilot server immediately before any migration: `scripts/remote-backup.sh <label>` (runs `infra/backup/backup.sh` on the server) | Manual | A dump file with today's timestamp exists in the backup directory. If `HEALTHCHECK_URL` is set, its dead-man ping arrived. Record the file name and time, not the directory's host | NOT RUN | dump file name, timestamp, ping time |
| B2 | Restore of that dump into an isolated target, never the live stack: a separate host or compose project, with its own `scripts/remote.env` | Manual | `pg_restore` reports no errors, or every error is explained in the record. Row counts of `households`, `profiles`, `events` and `shopping_items` match the live counts taken at dump time. Those counts are read only | NOT RUN | target label, pg_restore error count, count table |
| B3 | Migration dry run on the isolated target only: `scripts/remote-migrate.sh` with a `remote.env` that names that target | Manual | Every file in `supabase/migrations` up to the candidate is in `supabase_migrations.schema_migrations`, with no error | NOT RUN | migration list, command output |
| B4 | Live migration (only if the operator decides to migrate the pilot server) | Manual | Runs after B1 and B2 on the same day. `remote-migrate.sh` dumps first. Forward-only. Record the migration list before and after | NOT RUN | dump used, before and after lists |
| B5 | Restore drill on the real data, with the date written down (M1.6) | Manual | B2 passed with real data in the isolated target. The date is written in the record | NOT RUN | date, target label |
| B6 | `api_version` check: `api.server_info()` on the pilot server returns the value the candidate app expects | Manual, read only | Equal to the candidate app's supported window. The app's previous release is still supported (AGENTS.md, compatibility rule) | NOT RUN | value returned |

## 4. Server, jobs and mail

Read-only checks, with one exception: S6 sends one sign-in code to a real mailbox, which is the
only item in this section that changes anything. Nothing here calls an administrative or action
endpoint, and nothing here uses a family's credentials or a cron secret.

| ID | Check | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| S1 | Every Edge Function directory in `supabase/functions` at the candidate SHA is deployed (enumerate afresh, excluding `_shared`; main also includes `shortcuts`, `mcp` and `household-export`). Original 14-function baseline (`apple-token` was removed on 2026-10-17 and is no longer expected): `account-delete`, `apple-token`, `board-week`, `calendar-import`, `holidays-sync`, `household-purge`, `ics`, `mfa-reset`, `occurrences`, `school-week`, `send-email`, `server-info`, `tasks-materialise`, `tasks-nightly`. Step 1, deployment metadata: the function list from the hosting provider's own CLI or console, or a read-only listing of the functions directory on the server. Step 2, probes with no credentials: an `OPTIONS` request (or the `GET` that `server-info` and `ics` take), with no body, no `Authorization` header and no `x-cron-secret` header. Never probe with a real token, a family's feed address or a cron secret | Manual, read only | Step 1 lists every discovered candidate function, including `shortcuts` and `mcp`, at the candidate's version; these two token endpoints are checked by metadata only, never with a real key. Step 2 gives the expected class: a preflight answer (2xx) for `account-delete`, `board-week`, `calendar-import`, `holidays-sync`, `household-export`, `mfa-reset`, `occurrences`, `school-week` and `tasks-materialise`; 200 JSON for `server-info`; a 4xx with no calendar content for `ics`; 401 for `household-purge` and `tasks-nightly`, which check the cron secret before any work. `send-email` is a mail-hook endpoint and is checked by metadata only (S6); it is not probed. If the function list cannot be read, the result is `NOT RUN` with the reason, not `FAIL` | NOT RUN | function list (names and versions), status code per probe |
| S2 | The four scheduled jobs exist, through exactly one mechanism: pg_cron (`infra/jobs/schedule.sql`, query `cron.job` where `jobname like 'wuselwall-%'`) or host cron (`infra/cron/*.sh`). Expected schedules: `wuselwall-tasks-nightly` `0 1 * * *`, `wuselwall-holidays-sync` `0 3 * * 1`, `wuselwall-calendar-import` `0 * * * *`, `wuselwall-household-purge` `0 2 * * *` | Manual, read only | All four present and active. Not both mechanisms. Whether this server has them is an operator fact: if it cannot be read, `NOT RUN` | NOT RUN | query output (job names and schedules only) |
| S3 | Recent job runs succeeded: `cron.job_run_details` for the last 7 days (or the host cron log) | Manual, read only | Every job ran on schedule and its last run succeeded. `holidays-sync` is weekly, so check its last week | NOT RUN | status and times per job |
| S4 | Before the next `household-purge` run, nothing the family wants is pending deletion | Manual, read only | Deleted households (`deleted_at` set) are listed. Each one is confirmed as intended by the family, or the purge is held by the operator's decision. The purge removes families deleted more than 14 days ago | NOT RUN | list of deleted household labels and dates, with the family's answer |
| S5 | `ENABLE_EMAIL_AUTOCONFIRM=false` in the stack's environment (`make-env.mjs` default; [10](10-deployment-and-ops.md#4-sign-in-providers-and-mail)) | Manual, read only | The variable is `false`. Record the name and the value only if it is `false`; do not print the environment | NOT RUN | variable name and value |
| S6 | Mail delivery: a sign-in code sent to a real mailbox of a family member arrives, through the configured provider (Scaleway Transactional Email, Q41). **The one item here that sends mail.** The tester asks for the code; nothing else is sent | Manual. Sends one email | The code arrives. Record the delay (send to receipt) and the sending domain. SPF, DKIM and DMARC pass for the sending subdomain ([10](10-deployment-and-ops.md#email-setup)) | NOT RUN | delay, mail headers' authentication results, no code in the record |
| S7 | No-mail limitation: a server without a mail provider cannot complete the email-code sign-in, and sign-up without mail is not built (Q48 is open). Apple and Google sign-in were removed (2026-10-17) and a password is only chosen after a first code, so such a server offers no sign-in for a new adult | Manual | If the pilot server has mail (S6 passed), this is `N/A` for the pilot. If it does not, the pilot cannot use email sign-in and the pilot is blocked until it does | NOT RUN | which applies, and why |
| S8 | Off-site backup and dead-man's switch: a recent off-site copy (restic, Q14) and a recent `HEALTHCHECK_URL` ping | Manual, read only | Both current. Record the time of the last of each | NOT RUN | times |

## 5. Onboarding timings (NFR-17) and links

The timings are measured with a stopwatch by a tester who has not seen the build. Record each
hesitation, not only the total. The screen count follows the journey test's definition
(`app/test/journeys/`); a count above the limit is a FAIL even if the time is met.

| ID | Check | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| T1 | J1: start a family with Apple or Google, on the candidate app, on a clean install | Manual | At most 3 screens after sign-in, and at most 90 s. Typed: names only | NOT RUN | time, screen count, hesitations |
| T2 | J2: join by invitation link, with the app installed | Manual | At most 2 screens after sign-in, and at most 60 s | NOT RUN | time, screen count, hesitations |
| T3 | J3: connect a shared device by pairing (nothing typed on the device) | Manual | At most 30 s of a guardian's time. Nothing typed on the shared device | NOT RUN | time, hesitations |
| T4 | J1 with the email code: time from the code request to Today, with the mail delay recorded apart from the app's own time | Manual | The app's part meets T1's limit; the mail delay is recorded, not counted against NFR-17 | NOT RUN | app time, mail delay |
| L1 | iOS universal links: `https://<domain>/.well-known/apple-app-site-association` is served as JSON, and the signed build's Associated Domains entitlement includes `applinks:` for the same domain | Manual, read only for the file; the entitlement is read from the signed build | The file answers with a JSON content type and lists the app ID. The entitlement matches the server | NOT RUN | response headers, entitlement value |
| L2 | Android App Links: `/.well-known/assetlinks.json` lists the SHA-256 of the signing key that signed the candidate APK or AAB | Manual | The fingerprint equals the candidate's signing certificate. At `43ac2e5`, the website's `src/config/site.ts` (now in `wuselwall/wuselwall-website`) holds `TODO` values for both signing fingerprints, so this check cannot pass until the operator supplies the real values. Do not put a placeholder in the file | NOT RUN | fingerprint (public), comparison result |
| L3 | Invitation link opens the app when it is installed, on iPhone and on an Android phone | Manual | The app opens at the invitation. Screenshot | NOT RUN | screenshot paths |
| L4 | Invitation link opens the `/i/` landing page when the app is not installed | Manual | The DE/EN landing page loads; record the device language and any locale redirect behavior | NOT RUN | screenshot paths |
| L5 | Pairing link (`/p/`) behaves as L3 and L4 | Manual | As L3 and L4 | NOT RUN | screenshot paths |
| L6 | The auth return URL `ch.goomba.wuselwall://login-callback/` returns into the app after sign-in with the provider | Manual | The app is in front, signed in | NOT RUN | screenshot path |

## 6. Shopping: offline replay and realtime

Two enrolled devices, both belonging to the family, and the family's own list. Use a scratch
item named for the check and tick it off at the end, so the list is left as it was.

| ID | Check | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| O1 | Realtime: an item added on device A appears on device B without a reload | Manual; the realtime path is covered by the repository integration test (`app/test/integration/identity_shopping_integration_test.dart`) under CI A4 | B shows it within 5 s | NOT RUN | timing, screenshot |
| O2 | Offline outbox: on A, with the network off, add one item and tick one. Both show the pending mark and the banner. Restore the network | Manual. The outbox rules are covered by `shopping_outbox_model_test`, `shopping_sync_test` and pgTAP `050_shopping_outbox` | Both changes reach the server and show on B. No duplicate items | NOT RUN | screenshots before and after |
| O3 | Background: A in the background for 10 minutes, then a change from B | Manual | A shows the change when it returns to the foreground. On Samsung, check battery optimisation if it does not | NOT RUN | timing, device model |

## 7. Calendar: recurrence, DST, all-day, and real subscriptions

Subscriptions are checked with the family's real Outlook and iOS Calendar. The renderer's tests
are not evidence of what those clients display.

| ID | Check | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| C1 | Recurrence with an override: a weekly rota with one changed occurrence shows correctly on the week board and in the ICS feed | Manual; expansion is covered by `occurrences_test.ts` (Local, A6) and pgTAP `080_calendar` | Board and feed show the same occurrences | NOT RUN | screenshot, feed excerpt without the token |
| C2 | DST: a daily event at 09:00 that spans the autumn change on Sunday 25 October 2026 (Europe/Berlin) stays at 09:00 local in the app, in the feed and in both subscribing clients | Manual | 09:00 local on both sides of the change | NOT RUN | screenshots |
| C3 | All-day and multi-day events show as all-day in the app and in the feed, without a shift to the previous or next day | Manual | No shift in any of the three views | NOT RUN | screenshots |
| C4 | Real Outlook subscription: the feed URL subscribed in Outlook shows the family's events and, with `subscribed` on for the token, the imported calendars | Manual | Events appear. Record the observed delay. The documented delay is 3–24 h ([05](05-module-calendar.md)) | NOT RUN | delay, screenshots |
| C5 | Real iOS Calendar subscription, with the same token filter | Manual | Events appear, including imported calendars when `subscribed` is on. Record the refresh behaviour | NOT RUN | screenshots |
| C6 | Token revocation: create one token for this check, subscribe, revoke it, confirm the subscription stops (404) | Manual | The feed answers 404 after revocation. The test token is the only one revoked | NOT RUN | response code, time |
| C7 | Imported calendar fetch: "Jetzt aktualisieren" on one of the family's own subscribed calendars updates its occurrences | Manual | The occurrences change. Only that calendar is fetched | NOT RUN | time, screenshot |

## 8. Boundaries: guardian, child and kiosk

Automated coverage (CI, A1 and A4): `app/test/features/kid_ui_test.dart`,
`app/test/features/external_calendar_test.dart`, and the pgTAP suites for the cross-household and
revoked-device cases. The checks below are the on-device counterparts.

| ID | Check | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| P1 | A child's device cannot change anything in the household, and cannot reach a guardian-only view. Reading settings is allowed: the Einstellungen screen is readable by the whole household, and every change goes through the guardian gate (`app/lib/features/settings/ui/settings_page.dart:42-43`; the kid home's settings button, `app/lib/features/kid/ui/kid_home.dart:72`, opens it). Specs/09 lists no settings destination for the kid register; that list is the kid's own destinations, not a settings ban. On the child's device, try: add a member, add or revoke a device, change the guardian PIN, create or revoke a feed token, add an external calendar, delete or leave the family. Pass when each is refused or asks for a guardian PIN, and the full feed address (with its token) is not displayed on that device. Opening the settings screen and reading it is not a failure | Manual | Each attempt refused or PIN-gated; no full feed address shown; read-only settings opened without error | NOT RUN | screenshot of each attempt |
| P2 | The wall display (kiosk) cannot change settings, calendars or addresses without a guardian's PIN or step-up | Manual | Refused or redirected | NOT RUN | screenshot |
| P3 | A revoked device is refused. Use a test device that the family agrees to revoke; revoke it, then check it cannot read | Manual | Refused after revocation. Re-enrol the test device afterwards, or leave it revoked | NOT RUN | response, screenshot |
| P4 | Cross-household refusal | Local only, on the isolated target (creates a second household, so never on the pilot server). Covered by pgTAP | Refused | NOT RUN | pgTAP output reference |

## 9. Local notifications

Personal phones only. Pushes are not built ([14](14-open-questions.md), Q38 and Q47).

| ID | Check | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| N1 | The OS permission prompt does not appear at first launch. It appears after a tap on "Erinnerungen einschalten" (iOS and Android) | Manual | Prompt only after the tap | NOT RUN | screenshots |
| N2 | The morning summary arrives at the household's configured time (default 07:00, Q13), and an event reminder arrives before a timed event | Manual | Both arrive within a minute of the scheduled time | NOT RUN | time sent and received |
| N3 | After an event's time is changed, the old reminder is gone and a new one is set | Manual | Only the new reminder fires | NOT RUN | notification list |
| N4 | With permission denied, the app still works, and the settings explain how to turn reminders on | Manual | No crash, no repeated prompt | NOT RUN | screenshot |
| N5 | After a device reboot, check whether reminders still fire. Record what happens; do not assume | Manual | Recorded either way | NOT RUN | observed result |

## 10. Accessibility and languages

| ID | Check | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| X1 | VoiceOver on iPhone on one screen (Today): labels read in the expected order | Manual | Every control is announced | NOT RUN | notes |
| X2 | TalkBack on an Android phone on one screen (Today) | Manual | As X1 | NOT RUN | notes |
| X3 | System font size at maximum on Today, shopping, the adult board and the kid register: no clipped or overlapping text | Manual | None | NOT RUN | screenshots |
| X4 | Device language German, English, French, Spanish and one unsupported locale: no string from another application language leaks, unsupported falls back to German | Manual | None | NOT RUN | screenshots |
| X5 | DE/EN/FR/ES app/server messages and native permission prompts are in parity | CI, A1 (ARB and catalogue parity tests) | Green | NOT RUN | CI run link |
| X6 | Email hook and SMTP send subject/HTML/plain in only `MAIL_LANGUAGE` (test each of `de`, `en`, `fr`, `es`, plus legacy/unset → German) and preserve the selection across update/language change | CI + manual | No recipient-locale override; keys unchanged | NOT RUN | CI run link, mail samples |

## 11. Tablets and the wall display

| ID | Check | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| K1 | iPad: rotation and split view on the adult register. The kid register is readable at arm's length | Manual | No layout break | NOT RUN | screenshots |
| K2 | Wall display mounted in the kitchen, the app pinned in kiosk mode, the week board shown, and the 60-second revert back to the board after an interaction | Manual | Board visible from the usual standing place. The revert happens | NOT RUN | photo path, timing |
| K3 | The wall display recovers after a power cut and a network restart: the app starts pinned again | Manual | Starts without a keyboard | NOT RUN | observed result |

## 12. Pilot outcome (two weeks)

Kept by the operator outside the repository, as a dated log. No analytics are used.

| ID | Check | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| Q1 | Each member of the pilot household uses the app on each of 14 consecutive days. The reference household in [21](21-household-settings.md#the-reference-household) (two adults and two children) is an example only; the pilot household is judged by its own members | Manual, from the log | Every member, every day | NOT RUN | the log, by day and member |
| Q2 | Nobody asks the operator to fix anything during the two weeks. Each request is logged as a ticket | Manual | Zero outstanding requests at the end. Requests that are not fixed are recorded as FAIL | NOT RUN | ticket list |
| Q3 | Nightly dumps: one per night for the 14 days (B1 schedule), with the dead-man ping for each | Manual, read only | 14 of 14 nights | NOT RUN | ping log summary |

## 13. Public-release gates (separate from the pilot)

These gates open the store listings and the invitation of other households. They are not
complete at `43ac2e5`, and this checklist does not mark them complete.

| ID | Gate | Mode | Pass when | Result | Evidence |
|---|---|---|---|---|---|
| G1 | Apple developer account and App Store listing, privacy labels | Manual | Listing live in review or on sale, with labels filled in honestly | NOT RUN | listing link |
| G2 | Google Play account, listing and Data safety form (the Play account was still waiting at the M0.4 date) | Manual | Account active, listing and form filled in | NOT RUN | console status |
| G3 | Android signing fingerprints in `src/config/site.ts` of `wuselwall/wuselwall-website` (upload key and Play app signing key) | Manual | Both real values set, with L2 passing | NOT RUN | commit reference |
| G4 | Store URLs in `site.stores`, which show the badges only when set | Manual | The real listing URLs | NOT RUN | commit reference |
| G5 | Legal fields in `src/config/site.ts` of `wuselwall/wuselwall-website`: no `TODO` left in a field that shows on the site (A8) | Local | A8 passes. Filled-in facts are not changed to pass it | NOT RUN | A8 output |
| G6 | Sending domain verified and deliverability checked (Q41, S6) | Manual | Verified | NOT RUN | provider status |
| G7 | App Review reviewers can use the demo mode without a server | Manual | Demo mode works from a clean install | NOT RUN | review notes |
| G8 | Abuse controls on: rate limits at the front and in Auth, clean-up of empty accounts, the attempt logs ([11](11-security-and-privacy.md)) | Manual, read only | Configured and observed | NOT RUN | configuration check |

## Run record

| Item | Result | Evidence reference |
|---|---|---|
| Candidate record (section 1) | | |
| Automated gates (section 2) | | |
| Backup, migration, restore (section 3) | | |
| Server, jobs, mail (section 4) | | |
| Timings and links (section 5) | | |
| Shopping (section 6) | | |
| Calendar (section 7) | | |
| Boundaries (section 8) | | |
| Notifications (section 9) | | |
| Accessibility and languages (section 10) | | |
| Tablets and wall display (section 11) | | |
| Pilot outcome (section 12) | | |
| Public-release gates (section 13) | | |

A run is complete when each section has a result for every item, and every PASS has evidence.
Blocked items stay `NOT RUN` with the reason written next to them.
