# 19 — Security and architecture review

*2026-10-11, after M1.1 and ADR-013. Reviewed: the four migrations, the identity and
shopping code paths in the app, the nginx and Cloudflare setup, backups, CI. Method: read
every `SECURITY DEFINER` function and policy, probe the public URL from outside, and ask
of each control "what if the client is hostile?" — the anon key is in every app binary.*

Status: **Fixed** (in this commit), **Your action** (needs a change only the operator can
make), **Open** (decided to leave, or scheduled).

## Security findings

| # | Severity | Finding | Status |
|---|---|---|---|
| S1 | **Critical** — *resolved 2026-10-11, `/pg/` answers 404* | `/pg/…` on the public host — Kong's route to **pg-meta** — answered 200 to the internet with no key. pg-meta lists the schema and can execute SQL. The front forwarded `/` to Kong | **Fixed:** the front forwards exactly four prefixes and answers 404 elsewhere (today the release's Caddyfile). Re-test on any server: `curl -s -o /dev/null -w '%{http_code}' https://api.example.org/pg/tables` must print 404 |
| S2 | **Critical** — *resolved 2026-10-11: old secret key and service-role JWT rejected (401/403), new ones accepted* | The stack ran on the CLI's **default JWT secret and keys**, which are public. With them anyone can mint a `service_role` token | **Your action:** restart with the new `supabase/.env` (`scripts/remote-supabase.sh stop` / `start`). Re-test: the old publishable key must get 401 |
| S3 | High | After `db reset`, `seed.sql` re-creates the setup token `dev-setup`, which is in git; until the real household exists, anyone can claim it | **Open, mitigated:** `scripts/remote-setup-token.sh` and `server/wuselwall setup-token` replace it, and a release never runs the seed. Better still (next): move the dev token out of `seed.sql` into the CI/local start script, so a reset on a live server never creates it. *ADR-014 (step 9) turns the token into single-use founder codes, needed only in `code` mode; since 2026-10-30 the key also gates sign-up through the Before User Created hook (specs/20 "Claiming the server"), so a seeded key on a live server would let its holder create the first account, not only the family; the move out of `seed.sql` still applies* |
| S4 | Medium | Enrolment codes came from `random()`, a non-cryptographic PRNG | **Fixed:** `gen_random_bytes`, unbiased mapping (migration `…170000`) |
| S5 | Medium | The PIN step-up window was **device-wide**: after a guardian entered the PIN on the shared iPad, any acting profile named in a call during the next 15 minutes counted as verified | **Fixed:** the window records the verifying profile (`guardian_verified_profile`); `require_guardian` compares it. pgTAP covers it |
| S6 | Medium | Ten wrong PINs locked a guardian's PIN **for good, and nothing released it** — a child at the kiosk could lock every guardian out of step-up (the docs promised "released by a full guardian login"; the code had no such path) | **Fixed:** `api.guardian_set_pin` — only a guardian's own personal device (password + TOTP) can set a new PIN, which clears the lock. Settings → Security → Change PIN |
| S7 | Low | bcrypt cost 6 (the `gen_salt('bf')` default) for Auth users and PINs; GoTrue uses 10 | **Fixed:** Auth users 10, PINs 12 |
| S8 | Low | Android allowed cloud backup of app data | **Fixed:** `allowBackup="false"`, `usesCleartextTraffic="false"` |
| S9 | Medium | **No rate limiting at the edge.** Sign-in, `enrol_device` and the PIN are limited inside the stack only (GoTrue's per-IP limits; `enrol_attempt`) | **Your action:** a Cloudflare rate-limiting rule for `/auth/v1/token*` (e.g. 20 per minute per IP) and `/rest/v1/rpc/enrol_device`. **Not** Bot Fight Mode: it challenges API clients, which would break the apps. nginx could also use `limit_req` |
| S10 | Medium — *resolved 2026-10-11* | Postgres (54322, password `postgres`), Studio (54323, no login) and Mailpit (54324) are published by the CLI on **every interface of the host**. Anyone on the same network has the database | **Fixed:** the official compose stack replaced the CLI stack ([ADR-013 amendment](adr/ADR-013-self-hosted-compose-stack.md#amendment-2026-10-11-the-official-compose-stack)). Postgres listens on `127.0.0.1:54422` with its own password, the gateway on the Docker bridge address only, Studio sits behind a login (and is off in a release), no Mailpit |
| S11 | Low | A guardian PIN is six digits: if the database ever leaks, bcrypt cost does not save it (10⁶ guesses) | **Open:** pepper the hash with a key outside the database (Vault, or an Edge Function secret) when the first Edge Function arrives |
| S12 | Low | Every household member, children included, can read `api.audit_log` (including `diff`) | **Open:** restrict to guardians once there is a screen that shows it |
| S13 | Low | A revoked device's Realtime socket stays subscribed until it reconnects; REST/RPC are refused at once (`device_ok()` in every policy) | **Open:** the payload carries no data (only "refetch"), so nothing leaks; revocation could also `realtime.disconnect` |
| S14 | Info | Guardian password policy is a length check (≥ 10) in `setup_household` only | **Open:** `minimum_password_length` in `config.toml` and zxcvbn-style feedback in the wizard |
| S15 | Info | `api.devices` exposes `auth_session_id` to the household through a column grant | **Open:** replace the view's filter with a SQL function so the grant can go |
| S17 | Info | The gateway does not require the publishable key for REST: a request with an old or no key runs as `anon`, which reaches exactly `health`, `server_info` (constants for the front door, since 2026-10-14), `setup_household` (closed once a household exists) and `enrol_device` (needs a valid code). By design — the key ships in every app. `/rest/v1/` also listed those three names | **Fixed in the front:** `/rest/v1/` alone answers 404. **Since the compose stack:** the gateway itself refuses requests without a key (401) and the schema listing even with the publishable key (403) |
| S16 | Info | Cloudflare terminates TLS and so sees all traffic in clear (accepted in ADR-013) | Accepted |

**What held up.** Every `app` table has RLS enabled and forced; `anon` can call exactly
three functions; every `SECURITY DEFINER` function pins `search_path`; clients cannot write
any table; revocation takes effect on the next request; Realtime channels are scoped to the
household; the setup call closes for good. These are now asserted by pgTAP
(`040_catalogue.test.sql`), so a future migration cannot weaken them silently.

## Architecture findings

| # | Finding | Status |
|---|---|---|
| A1 | A migration runs straight against live data | **Fixed:** `scripts/remote-migrate.sh` and `server/wuselwall update` back up first, then migrate (and, from a checkout, run pgTAP), stopping at the first failure |
| A2 | The nightly backup script exists but nothing runs it yet | **Fixed 2026-10-14:** `server/wuselwall backup` from the host's cron (docs/server); restic off-site and the healthchecks ping are optional; `wuselwall restore` puts a dump back on a fresh install |
| A3 | The fold function exists twice (SQL and Dart) and drifted silently in other projects | **Fixed:** the same cases are asserted on both sides (`fold_test.dart`, `030_hardening`) |
| A4 | The RLS catalogue test was open since M0 | **Fixed:** `040_catalogue.test.sql` |
| A5 | CI's integration test had never passed (a Realtime cold-start race) and could run against a live database | **Fixed:** warm-up loop; the test refuses any host but localhost |
| A6 | Offline shopping is the one hard requirement and is not built | **Fixed 2026-10-12:** drift mirror and outbox, replayed through one idempotent `api.shopping_apply(p_actor, p_ops)`; every op carries a client `op_id`, new items and trips a client id; a replay is recognised per op, a bad op rejects only itself (specs/07#offline, pgTAP `050_shopping_outbox`) |
| A7 | `api.shopping_items` returns every list's open items and the app filters | Fine at household scale; revisit if lists grow past a few hundred rows |
| A8 | The CLI stack is a development tool serving live data | **Fixed 2026-10-11:** servers run the official self-hosting compose file ([ADR-013 amendment](adr/ADR-013-self-hosted-compose-stack.md#amendment-2026-10-11-the-official-compose-stack)) |
| A9 | No monitoring | **Open:** an uptime check on `/.well-known/wuselwall.json` and the backup ping (docs/server/extras) — twenty minutes with healthchecks.io or Uptime Kuma, which a NAS can host |
| A10 | The ICS feed and the MCP endpoint will be unauthenticated-by-JWT public routes | **Open (M1.3a / M2):** they will use the service role legitimately. Each gets its own nginx location, its own rate limit and a token hash lookup; never route `/functions/v1/*` blindly once they exist |
| A11 | Edge Functions cannot be deployed to a remote Docker host (bind mounts) | **Fixed by the compose stack:** `scripts/remote-stack.sh deploy` syncs `supabase/functions` into the stack's functions directory on the server |
| A12 | **The web build was blank.** The `passkeys` plugin initialises a JavaScript SDK at start-up and throws without it — found while taking the documentation's screenshots | **Fixed:** a no-op stand-in in `web/index.html`; passkeys on web stay unavailable until the SDK is self-hosted |
| A13 | Accessibility of the list: each row was announced as "Hinzugefügt von Emma, Bananen", and its checkbox was a separate node with no label | **Fixed:** the row is one checkbox named after the item; who added it is a hint |
| A14 | Usability, found in the screenshots: the enrolment code wrapped onto two lines at phone width; tile labels broke mid-word ("Toilettenpa‑pier"); the who-are-you bar showed only initials, so two members with the same initial looked alike; trips showed a bare number | **Fixed:** code on one line, single words shrink to fit, names under the avatars, "14 Artikel" |

## Order of work from here

*Revised 2026-10-11, after the compose stack replaced the CLI stack.*

1. By the operator: the backup job (A2), edge rate limits (S9), the uptime check (A9).
2. After two weeks on the compose stack: remove the CLI stack's Docker volumes
   (`supabase_db_wuselwall`, `supabase_storage_wuselwall`, `supabase_edge_runtime_wuselwall`).

## Second review — 2026-11-01, fixed 2026-11-02

*A second pass over the server architecture and the authentication flows, against main at
`5f2e23ab` (app v1.10.0, server 0.11.0), by reading the code only. The perimeter of the first
review held: RLS on every table, the hooks, the gateway's allow-list and the token material.
The findings are in the flows around it. The numbers F1–F30 are those of the review; the
fixes landed together in one change (migrations `20261102140000`–`20261102130000`, pgTAP
280–295).*

| # | Severity | Finding | Status |
|---|---|---|---|
| F1 | **High** | On a server with the Send Email Hook, both codes of an email change went to the *old* address, and `app.proven_email` then treated the new address as proven: a stranger could take an invitee's address and accept that invitation | **Fixed:** the hook mails each code to its own address; the proven address is recorded in `app.proven_address` when a confirmation or the second step of a change completes, and only that address counts |
| F2 | **High** on shared servers | supabase_flutter's `detectSessionInUri` was on: a link carrying someone else's tokens replaced the signed-in session | **Fixed:** off; the app's own link parser accepts only https links of the links site and refuses any link that carries session parameters |
| F3 | Medium | A co-guardian could remove another guardian's second factor, issue a reset code for them and redeem it, without a fresh sign-in and without the target noticing | **Fixed:** both need a sign-in of the last five minutes and `aal2` when the caller has a factor; the same guardian cannot do both to one person within a day; redeeming a code ends the target's sessions; the MFA reset sends a notice where the function can mail |
| F4 | Medium | Any device of the household could materialise task instances for any date and complete them: points for free | **Fixed:** `api.tasks_materialise` is service-role only; the Edge Function derives household and dates from the caller's schedule and the rule; a day the nightly job has closed cannot be ticked |
| F5 | Medium | The global brute-force buckets counted calls, not failures, so an anonymous script could lock pairing, invitations and resets for everyone; the per-client key was the first `X-Forwarded-For` entry, which a client chooses behind an nginx front | **Fixed:** failures only, per-client first, global caps sized for the code lengths; Envoy sets `X-WuselWall-Client-IP` itself; the docs say what an own front must send |
| F6 | Medium | A subscribed ICS feed with a never-matching RRULE burned minutes of CPU per event and, because the attempt was never recorded, stalled the hourly import for every household | **Fixed:** the occurrences module walks rules with a bounded engine (rrule.js stays as the test oracle), rules that cannot match are refused in SQL and TypeScript, feeds are capped, the attempt is written before the fetch with a backoff, and workers have CPU limits |
| F7 | Medium | The discovery document could carry any scheme or host, a changed address was adopted in the background, and links or codes connected without asking | **Fixed:** https only; a moved server is announced and reconnected only on request, after signing out; links and scans show the host and wait for confirmation; the credential screens show the server |
| F8 | Medium | `make-env.mjs` took keys over from an existing `.env` unchecked, so the CLI's public defaults could become a server's | **Fixed:** published values, placeholders, JWTs and short or uniform keys are refused; kept keys are printed as fingerprints; `.env.example` holds placeholders |
| F9 | Medium | Server releases had no checksum or signature and the updater ran the downloaded script | **Fixed:** `SHA256SUMS` signed with minisign, verified by `wuselwall update`/`verify` and cloud-init before anything is extracted; provenance attestation. **Your action:** generate the key pair, set the secret, pin the public key (release-checklist G9). Open: a release runner label that never runs PR jobs (G10) |
| F10 | Medium | Account deletion checked a recent sign-in but not `aal2` | **Fixed:** a TOTP-protected account must present `aal2` and a second-factor `amr` entry |
| F11 | Medium | ICS feed tokens outlived the guardian who made them | **Fixed:** revoked when the profile is retired or its account unlinked; the creator is shown |
| F12 | Low–Medium | On a server without mail the claim window was a race on the operator's address | **Fixed:** the no-code founding path needs the proven address or the client that claimed the key |
| F13 | Low–Medium | The PIN window on a shared device lasted 15 minutes and nothing ended it early | **Fixed:** five minutes on shared and kiosk devices; the app steps down on an avatar switch, the idle revert and when leaving the settings (`api.guardian_step_down`) |
| F14 | Low–Medium | `timetable-scan` accepted any Auth account | **Fixed:** a live household device, ten scans per ten minutes per account, bounded body, a pixel limit in the OCR container, which now sits on an internal network |
| F15 | Low | The PIN counter was written from a stale read | **Fixed:** row lock before bcrypt |
| F16 | Low | A child phone was a personal device whose profile could be made guardian without a password | **Fixed:** `app.guardian_ok` requires the device's Auth user to be the profile's own account; promotion and retirement revoke device-user phones |
| F17 | Low | Three places tested the role column instead of `require_guardian` | **Fixed** |
| F18 | Low | Closing a household left child-phone accounts behind | **Fixed:** device accounts are recognised by their marker address |
| F19 | Low | Account-level functions ignored `aal` | **Fixed:** `aal2` required when a factor exists; `my_account` answers without personal fields at `aal1` |
| F20 | Low | `setup_household` and `enrol_device` are still anon surface | **Open, mitigated:** both releases still ship the callers; `setup_household` is rate-limited and answers instead of raising. Revoke once the integration test uses the claim flow |
| F21 | Low | Reward overspend under parallel requests | **No change needed:** the profile row was already locked; pgTAP now asserts the balance logic |
| F22 | Low | Sign-up stayed open after the claim | **Fixed:** in code mode only an address with an open invitation, any address while a link-only invitation is open, or a live claim may sign up (`invitation_required`) |
| F23 | Low | A password change needed no fresh sign-in and kept other sessions | **Fixed** in the app (fresh sign-in, other devices signed out); GoTrue's re-authentication setting stays off because it cannot work without mail |
| F24 | Low | iOS Keychain class `unlocked` moved secrets with backups | **Fixed:** `first_unlock_this_device` |
| F25 | Low | No CSP on the web host; addresses in route queries | **Fixed:** CSP and headers in Caddy and `index.html`; addresses travel as router state |
| F26 | Low | Plaintext dumps, directory created before the umask; `restore` could drop on a failed count | **Fixed:** umask first, optional age or passphrase encryption, restore aborts on a failed count and always backs up first |
| F27 | Low | The hook mailed any `token` text | **Fixed:** digits, six to ten |
| F28 | Low | The docs suggested exposing the gateway on the LAN | **Fixed:** the docs keep the gateway on the bridge; a LAN bind is the last option with a firewall rule |
| F29 | Low | Feed tokens and `apikey` in the gateway's access log | **Fixed:** the log prints a sanitised path |
| F30 | Low | A short example setup key on the hosted path | **Fixed:** 16 characters minimum while no household exists; the docs show a generated key |

Not changed: `server_info.claimed` stays public (the app needs it); hosted projects without
Envoy fall back to the last public `X-Forwarded-For` entry; GoTrue's own per-IP limits still
read the first entry (upstream).
