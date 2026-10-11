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
| S1 | **Critical** — *resolved 2026-10-11, `/pg/` answers 404* | `https://wusel.goomba.ch/pg/…` — Kong's route to **pg-meta** — answered 200 to the internet with no key. pg-meta lists the schema and can execute SQL. The nginx site file forwarded `/` to Kong | **Your action:** deploy `infra/nginx/wusel.goomba.ch.conf` (four prefixes, 404 elsewhere). Re-test: `curl -s -o /dev/null -w '%{http_code}' https://wusel.goomba.ch/pg/tables` must print 404 |
| S2 | **Critical** — *resolved 2026-10-11: old secret key and service-role JWT rejected (401/403), new ones accepted* | The stack ran on the CLI's **default JWT secret and keys**, which are public. With them anyone can mint a `service_role` token | **Your action:** restart with the new `supabase/.env` (`scripts/remote-supabase.sh stop` / `start`). Re-test: the old publishable key must get 401 |
| S3 | High | After `db reset`, `seed.sql` re-creates the setup token `dev-setup`, which is in git; until the real household exists, anyone can claim it | **Open, mitigated:** `scripts/remote-setup-token.sh` replaces it; specs/10 and the M1.6 checklist say to run it immediately after any reset. Better still (next): move the dev token out of `seed.sql` into the CI/local start script, so a reset on the home server never creates it |
| S4 | Medium | Enrolment codes came from `random()`, a non-cryptographic PRNG | **Fixed:** `gen_random_bytes`, unbiased mapping (migration `…170000`) |
| S5 | Medium | The PIN step-up window was **device-wide**: after a guardian entered the PIN on the shared iPad, any acting profile named in a call during the next 15 minutes counted as verified | **Fixed:** the window records the verifying profile (`guardian_verified_profile`); `require_guardian` compares it. pgTAP covers it |
| S6 | Medium | Ten wrong PINs locked a guardian's PIN **for good, and nothing released it** — a child at the kiosk could lock every guardian out of step-up (the docs promised "released by a full guardian login"; the code had no such path) | **Fixed:** `api.guardian_set_pin` — only a guardian's own personal device (password + TOTP) can set a new PIN, which clears the lock. Settings → Security → Change PIN |
| S7 | Low | bcrypt cost 6 (the `gen_salt('bf')` default) for Auth users and PINs; GoTrue uses 10 | **Fixed:** Auth users 10, PINs 12 |
| S8 | Low | Android allowed cloud backup of app data | **Fixed:** `allowBackup="false"`, `usesCleartextTraffic="false"` |
| S9 | Medium | **No rate limiting at the edge.** Sign-in, `enrol_device` and the PIN are limited inside the stack only (GoTrue's per-IP limits; `enrol_attempt`) | **Your action:** a Cloudflare rate-limiting rule for `/auth/v1/token*` (e.g. 20 per minute per IP) and `/rest/v1/rpc/enrol_device`. **Not** Bot Fight Mode: it challenges API clients, which would break the apps. nginx could also use `limit_req` |
| S10 | Medium | Postgres (54322, password `postgres`), Studio (54323, no login) and Mailpit (54324) are published by the CLI on **every interface of the home server**. Anyone on the home wifi — a guest, a compromised IoT device — has the database | **Open:** put the server on a trusted VLAN or restrict those ports with Unraid's firewall to the admin's machine. They are not forwarded to the internet. Changing the DB password needs a custom compose file (the escape hatch in ADR-013) |
| S11 | Low | A guardian PIN is six digits: if the database ever leaks, bcrypt cost does not save it (10⁶ guesses) | **Open:** pepper the hash with a key outside the database (Vault, or an Edge Function secret) when the first Edge Function arrives |
| S12 | Low | Every household member, children included, can read `api.audit_log` (including `diff`) | **Open:** restrict to guardians once there is a screen that shows it |
| S13 | Low | A revoked device's Realtime socket stays subscribed until it reconnects; REST/RPC are refused at once (`device_ok()` in every policy) | **Open:** the payload carries no data (only "refetch"), so nothing leaks; revocation could also `realtime.disconnect` |
| S14 | Info | Guardian password policy is a length check (≥ 10) in `setup_household` only | **Open:** `minimum_password_length` in `config.toml` and zxcvbn-style feedback in the wizard |
| S15 | Info | `api.devices` exposes `auth_session_id` to the household through a column grant | **Open:** replace the view's filter with a SQL function so the grant can go |
| S17 | Info | The gateway does not require the publishable key for REST: a request with an old or no key runs as `anon`, which reaches exactly `health`, `setup_household` (closed once a household exists) and `enrol_device` (needs a valid code). By design — the key ships in every app. `/rest/v1/` also listed those three names | **Fixed in `infra/nginx`:** `location = /rest/v1/` answers 404. **Your action:** redeploy the site file |
| S16 | Info | Cloudflare terminates TLS and so sees all traffic in clear (accepted in ADR-013) | Accepted |

**What held up.** Every `app` table has RLS enabled and forced; `anon` can call exactly
three functions; every `SECURITY DEFINER` function pins `search_path`; clients cannot write
any table; revocation takes effect on the next request; Realtime channels are scoped to the
household; the setup call closes for good. These are now asserted by pgTAP
(`040_catalogue.test.sql`), so a future migration cannot weaken them silently.

## Architecture findings

| # | Finding | Status |
|---|---|---|
| A1 | One environment means a bad migration reaches the family at once | **Fixed:** `scripts/remote-migrate.sh` is the only path — dump, `migration up`, pgTAP — and stops at the first failure |
| A2 | The nightly backup script exists but nothing runs it yet | **Your action:** install `infra/backup/backup.sh` as an Unraid *User Scripts* job (daily 03:30); set `HEALTHCHECK_URL` and, when chosen, the restic repository in `/mnt/user/appdata/wuselwall/backup.env` |
| A3 | The fold function exists twice (SQL and Dart) and drifted silently in other projects | **Fixed:** the same cases are asserted on both sides (`fold_test.dart`, `030_hardening`) |
| A4 | The RLS catalogue test was open since M0 | **Fixed:** `040_catalogue.test.sql` |
| A5 | CI's integration test had never passed (a Realtime cold-start race) and could run against the family's database | **Fixed:** warm-up loop; the test refuses any host but localhost |
| A6 | Offline shopping is the one hard requirement and is not built | **Next:** drift mirror + outbox, replayed through one idempotent `api.shopping_apply(p_actor, p_ops jsonb)`. Every write the outbox can carry needs a client-generated id; today `add_item` merges by name, which is already idempotent for the common double-send, but toggle and finish are not |
| A7 | `api.shopping_items` returns every list's open items and the app filters | Fine at household scale; revisit if lists grow past a few hundred rows |
| A8 | The CLI stack is a development tool serving a family | **Open (ADR-013):** the first step back is the official self-hosting compose file with its own secrets and no published database port. Do it before the family depends on the app daily (M1.6), or sooner if S10 cannot be solved on the network |
| A9 | No monitoring | **Open:** an uptime check on `/auth/v1/health` and the backup ping (specs/10) — twenty minutes with healthchecks.io or Uptime Kuma, which Unraid can host |
| A10 | The ICS feed and the MCP endpoint will be unauthenticated-by-JWT public routes | **Open (M1.3a / M2):** they will use the service role legitimately. Each gets its own nginx location, its own rate limit and a token hash lookup; never route `/functions/v1/*` blindly once they exist |
| A11 | Edge Functions cannot be deployed to a remote Docker host (bind mounts) | **Open:** matters at M1.3a. Either run the CLI on the Unraid box itself, or sync `supabase/functions` to it and bind-mount there |
| A12 | **The web build was blank.** The `passkeys` plugin initialises a JavaScript SDK at start-up and throws without it — found while taking the documentation's screenshots | **Fixed:** a no-op stand-in in `web/index.html`; passkeys on web stay unavailable until the SDK is self-hosted |
| A13 | Accessibility of the list: each row was announced as "Hinzugefügt von Lotta, Bananen", and its checkbox was a separate node with no label | **Fixed:** the row is one checkbox named after the item; who added it is a hint |
| A14 | Usability, found in the screenshots: the enrolment code wrapped onto two lines at phone width; tile labels broke mid-word ("Toilettenpa‑pier"); the who-are-you bar showed only initials, so Lukas and Lotta were both "L"; trips showed a bare number | **Fixed:** code on one line, single words shrink to fit, names under the avatars, "14 Artikel" |

## Order of work from here

1. **Today, by the operator:** S1, S2 (nginx + restart), then A2 (backup job).
2. Edge rate limits (S9) and the network question (S10).
3. The offline outbox (A6) — the largest remaining M1.1 item.
4. The second-stack escape hatch (A8) before M1.6, unless the home network is trusted.
