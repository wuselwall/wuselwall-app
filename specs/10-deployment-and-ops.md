# 10 — Deployment & Operations (B3)

How a WuselWall server is built, installed and run, for anyone who operates one. The
project runs no service that holds a family's data ([ADR-018](adr/ADR-018-self-hosted-only.md)):
every household has its own server. The step-by-step guide for families is
[`docs/server/`](../docs/server/index.md); this document is the reference behind it.
Decision context: [ADR-013](adr/ADR-013-self-hosted-compose-stack.md) (the compose stack)
and [ADR-018](adr/ADR-018-self-hosted-only.md) (self-hosted only, built 2026-10-14).

*Rewritten 2026-10-14: this document describes servers in general. Nothing in the
repository describes a particular operator's server; such notes live outside it.*

---

## Two ways to run a server

| | Own hardware (or a VPS) | Hosted Supabase |
|---|---|---|
| **Install** | A server release and `server/wuselwall install` | The family's fork runs `.github/workflows/deploy-supabase.yml` |
| **Needs** | Docker with Compose v2, a domain, ports 80 and 443 | A Supabase account and a GitHub account |
| **Front and TLS** | The release's Caddy layer, or the operator's own web server | Supabase's |
| **Jobs** | pg_cron in the database (`infra/jobs/schedule.sql`) | The same, through the Management API |
| **Web app** | Served by the server (`stack/volumes/web`) | Optional, on the fork's GitHub Pages |
| **Updates** | `wuselwall update <version>` | Sync the fork, run the workflow again |

A third way exists for developers: a checkout drives a server over SSH with
`scripts/remote-*.sh`, which read their target from the git-ignored `scripts/remote.env`
(template: `scripts/remote.env.example`).

## Costs

For a family; the project's own costs (developer accounts, the `wuselwall.app` domain for
website and docs) are not passed on.

| Item | At home | Hosted Supabase |
|---|---|---|
| Server | Hardware already running: electricity | Free plan to try (pauses after 7 days idle); Pro ≈ $25 / month |
| Domain | ≈ €1–2 / month | Not needed |
| TLS | Let's Encrypt through Caddy: €0 | Included |
| Off-site backup copy (optional) | Backblaze B2 or any S3 store: €0.50 – €3.50 | Pro's daily backups included |
| SMTP (optional, for email codes) | Free tiers suffice (e.g. Scaleway TEM: 300 mails/month) | Same |

## The path a request takes (own hardware)

```
 phone / laptop
   │ HTTPS
   ▼
 router: TCP 80/443 → the server
   ▼
 Caddy (docker-compose.caddy.yml) — or the operator's own web server
   │  api.example.org  /auth/v1, /rest/v1, /realtime/v1, /functions/v1 → gateway;
   │                   /.well-known/wuselwall.json → /functions/v1/server-info; else 404
   │  web.example.org  the release's web app (static), the same discovery document
   │ HTTP on the Docker network (or 172.17.0.1:54421 from a front on the host)
   ▼
 Envoy gateway ─► Auth · PostgREST · Realtime · Edge runtime
                    │
                    ▼
                 Postgres  (127.0.0.1:54422 on the server, for SSH tunnels only)
```

Only four API prefixes and the discovery document leave the server. The gateway is bound
to the Docker bridge address, Postgres to `127.0.0.1`; there is no pooler and no Mailpit.
Studio and postgres-meta are off by default (`COMPOSE_PROFILES=studio` turns them on) and
are reached through an SSH tunnel only.

## The stack

The stack is Supabase's **official self-hosting compose file**, pinned to an upstream
commit and copied verbatim into [`infra/supabase/`](../infra/supabase/), plus WuselWall's
layers:

- `docker-compose.wuselwall.yml`: image versions equal to the pinned Supabase CLI's (so CI
  and every server agree), `supabase/config.toml`'s auth settings as GoTrue variables, the
  ports narrowed, `CRON_SECRET` for the functions;
- `docker-compose.lean.yml`: Storage and imgproxy off (WuselWall stores no files), Studio
  and meta behind the `studio` profile;
- `docker-compose.caddy.yml` with `volumes/caddy/Caddyfile`: the optional front.

`COMPOSE_FILE` in the server's `.env` lists the layers in use.

### 2. The stack and its secrets

**The secrets live only in the server's `.env`** (`chmod 600`), written once by
[`infra/supabase/make-env.mjs`](../infra/supabase/make-env.mjs): the addresses
(`--api`, `--web`), a strong Postgres password, an EC P-256 key pair that signs new
tokens, the opaque publishable and secret keys, the JWT secret, `CRON_SECRET`, the
services' own encryption keys and the Studio login. Keys already in a `supabase/.env` are
kept, so a server can move without stranding its devices. **The operator copies the
`.env` into a password manager**: with it, a restored database keeps every device signed
in (tested 2026-10-14); without the JWT secret and the keys every device must sign in again. Never regenerate it for a running server.

`docker compose down` keeps the data (`volumes/db/data`). **Never delete that directory
or run `supabase db reset` against a live server.**

### Discovery

Every server serves the discovery document through the Edge Function `server-info`
(`supabase/functions/_shared/server_info.ts`): its public address, the publishable key,
`api_version` and `min_app_version` from `api.server_info()`, the household-creation mode,
Apple and Google as Auth reports them, and `features`. A front of the server's own also
serves it at `/.well-known/wuselwall.json`. The app reads the `.well-known` path first,
then the function, so a hosted project's `https://<id>.supabase.co` is a complete address.

### The scheduled jobs

`tasks-nightly` (daily), `holidays-sync` (weekly) and `calendar-import` (hourly, the
households' subscribed calendars) authenticate with `x-cron-secret`.
[`infra/jobs/schedule.sql`](../infra/jobs/schedule.sql) schedules all three with pg_cron and
pg_net, the secret in the jobs' text (not in Vault, whose key does not survive a restore on
a new machine); `wuselwall install`, `update` and `restore` run it. A server
may instead call them from the host's cron (`infra/cron/*.sh`) — never both.

### 3. First household

Households are founded with a single-use **setup token** (`wuselwall setup-token`, or the
`WUSELWALL_SETUP_TOKEN` secret of the hosted workflow); only its hash is stored. After the
first household the server is closed: one server, one household
([20, J1](20-onboarding.md#j1--start-a-family)). The development seed's `dev-setup` must
never exist on a live server; a release never runs the seed.

The token is what the app's H1 ("Neue Familie", after sign-in) asks for as the
**Gründungscode** while `household_creation` is `code`, the default
([20, J1](20-onboarding.md#household-creation-open-or-by-code)). An operator who deliberately
hosts a further family issues one more single-use code with
`scripts/remote-setup-token.sh --founder`; it never replaces a code. Failed codes are rate-limited
per client and globally (`app.founder_attempt`).

### 4. Sign-in and mail

Email code and password work on every server. Sign-in with Apple and Google was removed on 2026-10-17 ([00](00-brief-and-decisions.md)): no server configures an external provider.

Passkeys are offered only for servers in the build's `WW_FIRST_PARTY_HOSTS` (a CI secret), as [ADR-018](adr/ADR-018-self-hosted-only.md) decision 6 requires.

### Email setup

*Decided 2026-10-11 ([Q41](14-open-questions.md)), generalised 2026-10-14.* Sign-in codes
are the only mail WuselWall will send, apart from the "new sign-in" notice; nothing sends
mail yet (accounts are created with confirmed addresses). The recommendation for an
operator who wants it:

| Topic | Recommendation | Why |
|---|---|---|
| Provider | A transactional-mail service in the EU, e.g. **Scaleway Transactional Email** | Transactional only, so its shared IPs are not dragged down by newsletters; free tier enough for a family; no branding footer |
| Sending domain | A domain or subdomain without mailboxes, with the SPF, DKIM and DMARC records the provider names; DMARC from `p=none` to `p=quarantine` after two clean weeks | Without SPF and DKIM the codes go to spam |
| Content | Plain text plus minimal HTML, no tracking; **the code in the subject** | Readable from the notification; tracking would contradict NFR-9 |
| Language | Per recipient (`locale` from sign-in), through the send-email hook; a bilingual GoTrue template where the hook is not running | The localisation rule |
| Rate limits | Auth's email limit raised to fit, per-address resend at most every 60 s | Hosted Supabase's default limit is for testing and fails silently |

Check deliverability with a code to Gmail, Outlook.com, GMX and iCloud addresses before
relying on it, and after any DNS change.

**Switching the hook on** (built 2026-10-15):

1. In the provider (e.g. a Scaleway project), add the sending domain, publish the SPF, DKIM and DMARC
   records it shows in your DNS, and wait for the domain check to pass.
2. Create an IAM application whose only policy is Transactional Email on that project, and
   note its secret key and the project ID.
3. Put the values into the stack's `.env` with `scripts/remote-stack.sh set-env`, never on the
   command line: `SCW_SECRET_KEY`, `SCW_PROJECT_ID`, and if they differ from the defaults
   `SCW_REGION` (`fr-par`), `MAIL_FROM` (an address on the sending domain) and `MAIL_FROM_NAME`
   (`WuselWall`). A new stack gets them from `supabase/.env` through `make-env.mjs`, which
   also generates `SEND_EMAIL_HOOK_SECRET` (`v1,whsec_…`, shared by GoTrue and the functions
   container) and sets `SEND_EMAIL_HOOK_ENABLED=true` and `SEND_EMAIL_HOOK_URI` when the
   Scaleway values are present.
4. Set `SEND_EMAIL_HOOK_ENABLED=true` and `SEND_EMAIL_HOOK_URI=https://<api>/functions/v1/send-email`
   (if step 3 did not), deploy the function with `scripts/remote-stack.sh functions`, then
   `scripts/remote-stack.sh up -d auth`. The address must be HTTPS: GoTrue refuses a plain-http
   hook address other than localhost and then does not start at all, hook on or off.
5. Check with a code to a Gmail, an Outlook.com, a GMX and an iCloud address, as below.

The hook is the only path that renders the mails in the recipient's language. Stacks that run
without it (the hook off, or a self-hoster's own SMTP) send GoTrue's own mails, in English;
`supabase/templates/` holds the bilingual wording for the CLI's `config.toml`, and the compose
stack has no static host from which GoTrue could load it. A failed send is a 5xx to GoTrue,
which the app reports as a failed sign-in, so a provider outage is visible to the user rather
than silent. The function's logs name the mail kind, the locale and the error code, never the
address or the code.


---

## The onboarding release (built 2026-10-15)

Order on a server, for the migrations and functions of the onboarding release:

1. `scripts/remote-backup.sh`, then `scripts/remote-pgtap-dry.sh` for the new migrations.
2. `scripts/remote-migrate.sh`, then `scripts/remote-stack.sh functions` to deploy the Edge Functions (`household-purge`, `account-delete`, `send-email`, `mfa-reset`, `calendar-import`, `holidays-sync`, `tasks-nightly` and the rest).
3. Schedule the jobs, with pg_cron (`infra/jobs/schedule.sql`, run by `server/wuselwall`) or from the host's cron (`infra/cron/*.sh`, never both), each with the stack's `CRON_SECRET`:
   - `household-purge.sh`, daily at 04:00 (`0 4 * * *`): removes families deleted more than 14 days ago;
   - `calendar-import.sh`, hourly;
   - `holidays-sync.sh`, weekly;
   - `tasks-nightly.sh`, daily at 03:00 (`0 3 * * *`).
4. On an existing server, set `ENABLE_EMAIL_AUTOCONFIRM=false` in the stack's environment (the default in `make-env.mjs`).
5. Keep `APPLE_TOKEN_KEY` as it is: it decrypts the Apple refresh tokens still stored for accounts created before sign-in with Apple was removed, and changing it makes them unreadable.

New environment variables, in the stack's `.env` (generated by `make-env.mjs` from the CI variables):

| Variable | Purpose |
|---|---|
| `WW_APPLE_TEAM_ID`, `WW_APPLE_KEY_ID`, `WW_APPLE_PRIVATE_KEY`, `WW_APPLE_BUNDLE_ID` | Only for revoking Apple access of accounts created before sign-in with Apple was removed. Read by the stack as `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_ID`. |
| `APPLE_TOKEN_KEY` | Encrypts the stored Apple refresh tokens of those accounts. Generated once; never changes. |
| `SCW_SECRET_KEY`, `SCW_PROJECT_ID`, `SCW_REGION` | Scaleway Transactional Email. `SEND_EMAIL_HOOK_ENABLED` is true only when the first two are set; `SCW_REGION` defaults to `fr-par`. |
| `SEND_EMAIL_HOOK_SECRET` | The signing secret of the send-email hook (`v1,whsec_…`). Generated once. |

Founder codes for a new family come from `scripts/remote-setup-token.sh --founder` (see [20](20-onboarding.md), J1).


## Other families' servers

*Replaces "WuselWall Cloud" (ADR-015) since [ADR-018](adr/ADR-018-self-hosted-only.md);
built 2026-10-14.* The project ships a **server release**, not a service.

- **A release** is a Git tag `server-v<version>`;
  [`server-release.yml`](../.github/workflows/server-release.yml) runs
  [`scripts/build-server-release.sh`](../scripts/build-server-release.sh) and attaches
  `wuselwall-server-<version>.tar.gz`: the stack with its layers, the Edge Functions, the
  migrations, the job schedule, the backup script, a web build without a server, and
  [`server/wuselwall`](../server/wuselwall).
- **`wuselwall`** runs on the server: `install` (secrets through `make-env.mjs` in a Node
  container when the host has no Node, stack, migrations, jobs, a setup token, the
  server's address and QR code), `update` (backup first, then the new release), `backup`,
  `restore`, `setup-token`, `status`, `logs`, `compose`.
- **Hosted Supabase:** [`deploy-supabase.yml`](../.github/workflows/deploy-supabase.yml)
  in the family's fork: `supabase db push`; the Data API (`api` only) and Auth (the
  access-token hook, sign-up off, TOTP) through the Management API; `CRON_SECRET` and the
  functions (`verify_jwt` per function from `config.toml`); the jobs and the setup token
  through the Management API's query endpoint; optionally the web app on GitHub Pages.
- **Compatibility:** a migration that changes the app–server contract raises `api_version`
  in `api.server_info()`. Each app release supports the current and the previous one; a
  server can turn old apps away with `min_app_version`.
- **Support boundary:** the guide in `docs/` and GitHub issues. The project never sees,
  backs up or restores a household's data.

### What another family needs, and what is left (2026-10-14)

**Mandatory:** a Supabase stack (Postgres with `pgcrypto`, `pg_cron` and `pg_net`; Auth with
the custom access-token hook; PostgREST exposing only `api`; Realtime; the Edge runtime),
HTTPS, the three scheduled jobs, a backup. **Optional:** the web app (until the store
listings), SMTP; outbound calls
only to OpenHolidays and to the calendar feeds a household subscribed to (besides Deno's
npm/jsr downloads, which the `deno-cache` volume keeps); off-site backup, monitoring. **Not needed:** Storage, imgproxy, Studio,
meta, any analytics, captcha.

**Left to do:**

1. A smoke test of `deploy-supabase.yml` on a scratch hosted project, on Postgres 17 (the
   direct `auth.users` inserts of ADR-013 and the now tolerant `auth.mfa_factors` grant are
   the known risks), and a first `server-v` tag.
2. CI: the integration test against the previous server release (ADR-018, decision 5).
3. Universal links and App Links for `/i/` and `/p/` (decision 8).
4. Moving between hosted Supabase and a home server, written up in the guide.

## WuselWall Cloud

Dropped 2026-10-13 ([ADR-018](adr/ADR-018-self-hosted-only.md)); see ADR-015 for what it was.

## Changing the database

```
feature branch ──"Run workflow"──► ci.yml: every migration from zero on a throwaway stack,
                                   pgTAP, Flutter tests, the integration test
      │ green
      ▼
a release:   wuselwall update <version>     — backup, new stack, pending migrations, jobs
a checkout:  scripts/remote-migrate.sh      — backup, pending migrations, pgTAP
```

A pull request runs only the fast checks; the backend job runs on a tag or by hand. Locally,
`scripts/local-pgtap` runs every migration and suite on a throwaway Postgres without
Docker; `scripts/remote-pgtap-dry.sh` tries new migrations on a server inside a rolled-back
transaction. Migrations are forward-only and must keep working with the previous app
release, because phones update on their own schedule.

---

## Backups

The one operational thing that genuinely matters. Everything else can be rebuilt from a
release; the database cannot, and it holds the accounts (the `auth` schema) as well as
the household's data.

- [`infra/backup/backup.sh`](../infra/backup/backup.sh), run by `wuselwall backup` (from
  the host's cron, nightly) or `scripts/remote-backup.sh`: `pg_dumpall --roles-only` and a
  custom-format `pg_dump` of the whole database into `BACKUP_DIR`, checked with
  `pg_restore --list`, 14 days kept.
- With `RESTIC_REPOSITORY` in the `BACKUP_ENV` file, the dumps also go to an encrypted
  off-site repository (restic from its Docker image). With `HEALTHCHECK_URL`, a ping after
  each success: a backup that silently stopped six weeks ago is the normal failure mode.
- **Keep the server's `.env` with the backups**: its JWT secret and keys are what make a
  restored database work with the existing devices. Supabase Vault's key is *not* in it
  (it lives in the `db-config` volume), so WuselWall keeps nothing in Vault.
- **Restore:** `wuselwall restore <dump>` on a server installed with the old `.env`
  (`install --env`): it stops everything but Postgres, recreates the database from the
  archive as `supabase_admin`, starts the stack, applies newer migrations and reschedules
  the jobs ([guide](../docs/server/restore.md)). *Tested end to end 2026-10-14: install,
  a household through the API, backup, the whole stack and its volumes deleted, a new
  install with the old `.env`, restore — 0 `pg_restore` errors, the data back, the old
  refresh token still valid, the nightly job answering 200; then `wuselwall update`.*
- **Restore drill:** [`infra/backup/restore-drill.sh`](../infra/backup/restore-drill.sh)
  restores the newest dump into a scratch database next to the live one and counts rows.
  *(First run 2026-10-11 on test data: 0 errors.)*

Hosted Supabase: Pro's daily backups (7 days), plus an occasional own copy with the CLI.

RPO 24 h, RTO a few hours (NFR-11).

---

## Updating one part

| Part | How | Touches |
|---|---|---|
| A server from a release | `wuselwall update <version>` | Backup, stack, functions, web app, migrations, jobs |
| Edge Functions from a checkout | `scripts/remote-stack.sh functions` | The Edge runtime only |
| One service | `docker compose up -d --no-deps auth` after editing `.env` | That container only |
| Database schema from a checkout | `scripts/remote-migrate.sh` | Postgres |
| The project's website | `scripts/remote-web.sh deploy` to its host (`scripts/remote.env`) | The website container (`infra/web`) |
| The user documentation | `.github/workflows/docs.yml` on every push to `main` | Static files, see below |

### The web app

Every server serves the web build of its own release; it finds the server at its own
origin. A developer's build for a fixed server comes from `scripts/deploy-web.sh` with the
git-ignored `app/env/dev.json`.

### The Android app

Until the Play listing exists, `release-android.yml` builds a signed APK and
`scripts/deploy-apk.sh` publishes it at the address in `scripts/remote.env`.

### The user documentation

`docs/` is built on GitHub's machines (the Flutter web demo, Playwright screenshots in both
languages and themes, VitePress with `DOCS_BASE=/docs/`). The deploy job runs on a
self-hosted runner (label `wuselwall-deploy`) that holds no access of its own: it pipes the
site over SSH to `DOCS_DEPLOY_TARGET` with a key that may run only the receiving script (a
forced `command=`), and the host key is pinned (`DOCS_DEPLOY_KNOWN_HOSTS`).

## Updates

| What | How | Cadence |
|---|---|---|
| Supabase images | Bump the pinned CLI in `package.json`, run CI, set the same tags in `docker-compose.wuselwall.yml`, release | Quarterly, or for a security fix |
| Upstream compose file | Copy `docker/` from a newer upstream commit into `infra/supabase/` (never edit it), note the commit in the layer's header, diff the rendered config | When an image bump needs it, or yearly |
| `pub`, npm, fastlane, GitHub Actions, Deno | Dependabot PRs, reviewed; `osv-scanner` in CI | Weekly PRs, merged monthly; security fixes at once |
| iOS signing certificate, Apple Developer Program | `fastlane match` renewal; renewal | Yearly |
| SMTP provider | Deliverability check | Quarterly, and after any DNS change |
| TestFlight builds | Any new release | Expire after 90 days |

Do **not** let a container auto-updater (Watchtower, a NAS's automatic updates) touch the
stack's containers: a database major version bump needs a migration.

---

## Monitoring

Keep it proportionate — this is a family app, not a service with an SLA.

- **healthchecks.io** free tier: the backup ping (`HEALTHCHECK_URL`).
- **Uptime monitoring** on `https://<server>/.well-known/wuselwall.json`: an answer means
  gateway, functions, PostgREST and Auth are up.
- **Logs**: `wuselwall logs <service>` or `docker compose logs -f <service>`.
