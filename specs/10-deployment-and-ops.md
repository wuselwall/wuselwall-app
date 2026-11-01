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

## Three ways to run a server

| | Own hardware | A rented VPS (Hetzner, netcup, IONOS, Scaleway, OVHcloud, Infomaniak …) | Hosted Supabase |
|---|---|---|---|
| **Install** | A server release and `server/wuselwall install` | [`server/cloud-init.yaml`](../server/cloud-init.yaml) at the first boot: Docker from its signed repository, ufw (22, 80, 443), the release, `wuselwall install --caddy`; the result in a root-only `install.log` | The family's fork runs `.github/workflows/deploy-supabase.yml` on GitHub's runners |
| **Needs** | Docker with Compose v2, a domain, ports 80 and 443 | An account at an EU provider with cloud-init, Ubuntu 24.04 with 4 GB (8 GB with OCR), a domain | A Supabase account and a GitHub account |
| **Mail (optional)** | `wuselwall mail smtp` (any SMTP server, Gmail with an app password included) | The same | The `SMTP_*` or Scaleway secrets |
| **Front and TLS** | The release's Caddy layer, or the operator's own web server | The release's Caddy layer | Supabase's |
| **Jobs** | pg_cron in the database (`infra/jobs/schedule.sql`) | The same | The same, through the Management API |
| **Web app** | Served by the server (`stack/volumes/web`) | The same | Optional, on the fork's GitHub Pages |
| **Updates** | `wuselwall update <version>` | The same, over SSH; Ubuntu's unattended-upgrades for the system | Sync the fork, run the workflow again |
| **Guide** | [docs/server/home-server](../docs/server/home-server.md) | [docs/server/rented-server](../docs/server/rented-server.md) | [docs/server/supabase-cloud](../docs/server/supabase-cloud.md) |

A third way exists for developers: a checkout drives a server over SSH with
`scripts/remote-*.sh`, which read their target from the git-ignored `scripts/remote.env`
(template: `scripts/remote.env.example`).

## Costs

For a family; the project's own costs (developer accounts, the `wuselwall.app` domain for
website and docs) are not passed on.

| Item | At home | Rented VPS | Hosted Supabase |
|---|---|---|---|
| Server | Hardware already running: electricity | ≈ €4–8 / month for 2 vCPU and 4 GB (Hetzner adds €0.50 for IPv4; cheap sizes sell out) | Free plan to try (pauses after 7 days idle); Pro ≈ $25 / month |
| Domain | ≈ €1–2 / month | ≈ €1–2 / month | Not needed |
| TLS | Let's Encrypt through Caddy: €0 | Same | Included |
| Off-site backup copy (optional) | Backblaze B2 or any S3 store: €0.50 – €3.50 | Same; the provider's disk snapshots (≈ 20 %) are an addition, not a replacement | Pro's daily backups included |
| SMTP (optional, for email codes) | €0: a Gmail account with an app password, or a free tier (e.g. Scaleway TEM: 300 mails/month) | Same | Same |

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
the sign-in methods and `features`. A front of the server's own also
serves it at `/.well-known/wuselwall.json`. The app reads the `.well-known` path first,
then the function, so a hosted project's `https://<id>.supabase.co` is a complete address.

*Added 2026-10-24:* the function adds the features that depend on the stack's
configuration rather than its migrations (`timetable-scan` when `OCR_URL` is set; the app
greys the photo import out and says why where it is missing), and `server_version`, the
release from `WW_SERVER_VERSION`, which `wuselwall install` and `update` write into the
stack's `.env`. The app shows "App · Server · API" under Settings → Versions.

Native apps start from the cached discovery document and refresh it in the background.
Refreshed capabilities and server metadata update the running app without reconnecting
or signing the member out (2026-10-25). A changed server address or publishable key takes
effect on the next start; an incompatible server stops the app immediately.

Cache recovery (2026-10-25): native discovery also retries on foreground and network
recovery. Household data refetches after a successful Realtime subscription/rejoin and on
foreground/network recovery, covering broadcasts missed while disconnected. Member lists
observe member changes; calendar/school projections observe relevant settings and household
changes. Today refreshes its source caches and follows the local date across midnight.
Board responses from an earlier household generation are discarded, and shopping snapshot
refreshes are serialized with one coalesced follow-up so an old response cannot replace a
newer persisted mirror. These are repository regressions; native two-device qualification
remains part of the release checklist.

### The scheduled jobs

`tasks-nightly` (daily), `holidays-sync` (weekly) and `calendar-import` (hourly, the
households' subscribed calendars) authenticate with `x-cron-secret`.
[`infra/jobs/schedule.sql`](../infra/jobs/schedule.sql) schedules all three with pg_cron and
pg_net, the secret in the jobs' text (not in Vault, whose key does not survive a restore on
a new machine); `wuselwall install`, `update` and `restore` run it. A server
may instead call them from the host's cron (`infra/cron/*.sh`) — never both.

### 3. First household

Households are founded with a single-use **setup key** (`wuselwall setup-token`, or the
`WUSELWALL_SETUP_TOKEN` secret of the hosted workflow, compared in lower case); only its
hash is stored. After the first household the server is closed: one server, one household
([20, J1](20-onboarding.md#j1--start-a-family)). The development seed's `dev-setup` must
never exist on a live server; a release never runs the seed.

Since 2026-10-30 the key also gates sign-up ([20, Claiming the
server](20-onboarding.md#claiming-the-server)): while no household exists, Auth's Before
User Created hook creates an account only for the address that announced itself with the
key (`api.setup_claim`, anon, rate-limited like founder codes). The compose stack passes
`GOTRUE_HOOK_BEFORE_USER_CREATED_*` in `docker-compose.wuselwall.yml`, the hosted workflow
sets `hook_before_user_created_*` through `scripts/hosted-auth-config.mjs`, and the CLI
stack reads `[auth.hook.before_user_created]` (GoTrue 2.175 or newer). The discovery
document says `claimed: false` until the family exists, so the app's front door leads to
the claim.

The key is what the app's S1 ("Server einrichten") asks for, and H1 ("Neue Familie") only
when the address did not claim it there (a key from an older QR code), while
`household_creation` is `code`, the default
([20, J1](20-onboarding.md#household-creation-open-or-by-code)). An operator who deliberately
hosts a further family issues one more single-use code with
`scripts/remote-setup-token.sh --founder`; it never replaces a code. Failed keys are rate-limited
per client and globally (`app.founder_attempt`).

### 4. Sign-in and mail

Passwords work on every server, email codes on a server that sends mail; there are no
external sign-in providers (Sign in with Apple and Google were removed 2026-10-17). Passkeys
are offered only by a build that names its own server
([ADR-018](adr/ADR-018-self-hosted-only.md), amendment 2026-10-21).

**Mail is optional** (*built 2026-10-26*, [Q48](14-open-questions.md), issue #126). Auth
autoconfirms addresses exactly when no mail is configured (`ENABLE_EMAIL_AUTOCONFIRM`,
`mailer_autoconfirm` on hosted): `make-env.mjs`, `infra/supabase/mail-settings.sh` (behind
`wuselwall mail smtp|off|test`) and `scripts/hosted-auth-config.mjs` decide it the same way,
from SMTP or the send-email hook being set. `server-info` reads Auth's public
`/auth/v1/settings` and publishes `sign_in.email_code = !mailer_autoconfirm`, so the app
offers what the server does. Without mail: password sign-up (the app's E1 opens on a new
account), no invitation matched by address (`app.proven_email`: confirmed *and*
`confirmation_sent_at`, which an autoconfirmed sign-up never has), and a forgotten password
reset with a guardian's one-time code (`api.password_reset_create` / `_redeem`, 10 minutes,
single use, rate-limited) or the operator's (`wuselwall password <email>`). A server
installed before 2026-10-26 without mail keeps `ENABLE_EMAIL_AUTOCONFIRM=false`;
`wuselwall update` flags it and `wuselwall mail off` repairs it. With mail:

### Email setup

*Decided 2026-10-11 ([Q41](14-open-questions.md)), generalised 2026-10-14.* Sign-in codes
are the only mail WuselWall sends, apart from the "new sign-in" notice. With mail, email
confirmation is required (`ENABLE_EMAIL_AUTOCONFIRM=false`); without, see above. The
original setup policy was amended 2026-10-19 to one installation-selected language (ADR-010
and ADR-014). The recommendation:

| Topic | Recommendation | Why |
|---|---|---|
| Provider | A transactional-mail service in the EU, e.g. **Scaleway Transactional Email**; or, simplest, a mailbox with SMTP access such as **Gmail with an app password** (a separate account; about 500 mails a day). Not Outlook.com: it takes OAuth only | Transactional only, so its shared IPs are not dragged down by newsletters; free tier enough for a family; no branding footer. A mailbox needs no domain or DNS records |
| Sending domain | A domain or subdomain without mailboxes, with the SPF, DKIM and DMARC records the provider names; DMARC from `p=none` to `p=quarantine` after two clean weeks | Without SPF and DKIM the codes go to spam |
| Content | Plain text plus minimal HTML, no tracking; **the code in the subject** | Readable from the notification; tracking would contradict NFR-9 |
| Language | One installation choice: `MAIL_LANGUAGE=de|en|fr|es`, default German (`de`); subject, HTML and plain text monolingual, the same for hook and SMTP | Independent of device, household and recipient metadata; updates preserve the choice |
| Rate limits | Auth's email limit raised to fit, per-address resend at most every 60 s | Hosted Supabase's default limit is for testing and fails silently |

Check deliverability with a code to Gmail, Outlook.com, GMX and iCloud addresses before
relying on it, and after any DNS change.

**Selecting the email language:**

- New release installation: `./wuselwall install --api https://api.example.org --web https://web.example.org --language fr --caddy`.
  `--language` accepts `de`, `en`, `fr`, `es`; omit it for German. It configures email, not
  the app UI. On an installed release use `./wuselwall language fr`; only Auth/functions
  restart, with existing keys retained. Do not rerun installation or regenerate `.env`.
- Checkout installation: set `WW_MAIL_LANGUAGE` for `scripts/remote-stack.sh init-env`
  only; it seeds the stack's `MAIL_LANGUAGE` (default `de`). After deployment use
  `scripts/remote-stack.sh language fr` to change it. Changing the init variable alone
  does not change an existing installation.
- Both update paths keep an existing selection; legacy/unset installations become German.
  `MAIL_CODE_SUBJECT` is derived from the selected catalogue and normalized on update or
  language change. No key rotation or database migration is needed for this change.
- Hosted Supabase: select the required **language** choice in **deploy-supabase** (`de`
  default). Every run applies the chosen SMTP templates/subjects and the matching
  `MAIL_LANGUAGE` Edge secret. Re-select the intended language on later runs: the workflow
  input is not inferred from the device or the previously chosen value. Mail is optional
  there too (`scripts/hosted-auth-config.mjs`; *mandatory 2026-10-25 to 2026-10-26*):
  with the `SMTP_*` secrets (host, port, user, password, sender) or the Scaleway secrets
  (`SCW_SECRET_KEY`, `SCW_PROJECT_ID`, `MAIL_FROM`) for the send-email hook, whose
  Standard-Webhooks secret the run generates and sets on both sides, codes are mailed;
  without either, `mailer_autoconfirm` is on. Supabase's built-in mailer is never relied on:
  it delivers only to the account's own addresses.

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

The hook renders every mail using only `MAIL_LANGUAGE`, never sign-in `locale` or
recipient metadata. With the hook off, SMTP uses the same language's code templates in
`supabase/templates/{de,en,fr,es}/`, generated from the hook's renderer
(`deno run --allow-write supabase/functions/_shared/mail_templates_write.ts`; a test fails
when they drift). Root `supabase/templates/*.html` remains a monolingual German CLI
fallback, not a bilingual message. The HTML supports Outlook's Word engine: layout tables,
inline styles only, no images and no links; plain text carries the same message. Both
first signup (`confirmation`) and returning sign-in (`magic_link`) carry a six-digit code.
Compose fetches the selected templates from the internal-only `mail-templates` service
(no published port, independent of Caddy). Release installation/update/language change and
checkout deployment/language change copy the selected canonical files into the stack's
`volumes/mail-templates/`; a checkout used directly with Compose must copy its chosen
language's files to `infra/supabase/volumes/mail-templates/` as well. Hosted
`deploy-supabase` applies that language's contents/subjects through the Management API and
sets the same `MAIL_LANGUAGE` Edge secret, six digits and a 600-second lifetime, with
readback. It does not change the SMTP provider or switch off an existing hook.
A failed hook send remains a 5xx, not a retry through SMTP; the app reports that failure.
The function logs name the mail kind, locale and error code, never the address or code.

These two default templates deliberately contain no sign-in link. Enter the code in the
already-open app; do not start a second sign-in in a new tab. `signInWithOtp` uses GoTrue's
`confirmation` template for a new address and `magic_link` for a returning one even though
the app consumes a code in both cases. Previously sent link-only mail still points to Auth's
verification endpoint, which may redirect to `SITE_URL` with session/callback parameters;
changing the templates does not repair that callback or transfer a setup code to another
browser context. Redirect settings and other mail kinds (invitation, recovery, email change)
are not changed here. Request a fresh code after updating rather than reusing an old link.

Local regression checks (no operator environment, household data or real mail):
`node --test scripts/email-code-templates.test.mjs scripts/hosted-email-templates.test.mjs`
checks Compose, the actual release archive and hosted API payload/readback behavior;
`node scripts/email-code-smtp.smoke.mjs` starts isolated disposable Docker services, captures
signup and returning sign-in messages in Mailpit, and verifies each mailed OTP with GoTrue.
It reuses images already on the Docker host; when GHCR keeps answering `toomanyrequests`
it pulls the same pinned digest from ECR Public or Docker Hub (`scripts/image-pull.mjs`).
Any other pull error, and every failed assertion, still fails the run.
Backend CI does the same for the Supabase CLI's disposable stack before `supabase start`
(`scripts/backend-stack-images.mjs`); its pins must match the CLI's `supabase services`
versions, so a CLI bump updates them in the same change.


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
4. On an existing server with mail, keep `ENABLE_EMAIL_AUTOCONFIRM=false`; without mail it is `true` (`wuselwall mail off`).
5. Since 2026-10-17 (no Apple or Google sign-in): see [Retiring social sign-in on an existing server](#retiring-social-sign-in-on-an-existing-server); the update does it.

New environment variables, in the stack's `.env` (generated by `make-env.mjs` from the CI variables):

| Variable | Purpose |
|---|---|
| `SCW_SECRET_KEY`, `SCW_PROJECT_ID`, `SCW_REGION` | Scaleway Transactional Email. `SEND_EMAIL_HOOK_ENABLED` is true only when the first two are set; `SCW_REGION` defaults to `fr-par`. |
| `SEND_EMAIL_HOOK_SECRET` | The signing secret of the send-email hook (`v1,whsec_…`). Generated once. |

Founder codes for a new family come from `scripts/remote-setup-token.sh --founder` (see [20](20-onboarding.md), J1).



### Retiring social sign-in on an existing server

Sign in with Apple and Google were removed on 2026-10-17 (migration `20261017100000_drop_apple_token`
drops the stored Apple refresh tokens; account deletion no longer revokes at Apple). A server or
hosted project set up before still carries the old settings; the update removes them.

**Hold first.** A server whose families used Apple's *Hide My Email* is not updated until its
operator has confirmed that those accounts receive an email code at their relay address
(`…@privaterelay.appleid.com`), or that there are none. An account that cannot receive a code
cannot sign in again after its session ends.

| Server | Step | Effect |
|---|---|---|
| Compose, from a release | `wuselwall update` and `install --env` run `stack/retire-social-sign-in.sh` before Auth restarts | Removes `APPLE_ENABLED`, `APPLE_CLIENT_IDS`, `APPLE_SECRET`, `GOOGLE_ENABLED`, `GOOGLE_CLIENT_IDS`, `GOOGLE_CLIENT_SECRET`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_ID`, `APPLE_TOKEN_KEY` from `stack/.env`, and the native callback (`<scheme>://login-callback…`) from `ADDITIONAL_REDIRECT_URLS`; every other entry stays in its order. Prints names, never values. The functions directory is replaced as a whole, so `apple-token` goes |
| Compose, from a checkout | `scripts/remote-stack.sh deploy` runs the same script on the server | Same |
| Hosted Supabase | `deploy-supabase.yml`, step *Retire social sign-in* (`scripts/hosted-retire-social.mjs`) | A Management API update changes only the keys it names, so a project that once had providers on keeps them on. The step PATCHes Google and Apple off, their client IDs and secrets empty, manual linking off, and only the native callback out of `uri_allow_list`; deletes a still-deployed `apple-token` and the five `APPLE_*` Edge Function secrets; reads all of it back and fails if anything is left |

The compose overlay passes no `GOTRUE_EXTERNAL_*` variable, so leftover `.env` values could not
switch a provider on; the script removes them so no credential lingers.

**Check afterwards.** `curl -s -H "apikey: <publishable key>" https://<api>/auth/v1/settings`
shows `"apple": false` and `"google": false` under `external`. Compose: `grep -c login-callback
stack/.env` is `0`. Then a member who used Apple or Google signs in with an email code on a
second device while the first stays signed in; nobody signs out to test.

**Outside the repo, afterwards:** delete the Google OAuth clients that existed only for sign-in;
remove the Apple Services ID, the Sign in with Apple key and its client-secret reminder. Keep
the senders registered for Apple's relay while accounts with a relay address exist.

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
  in the family's fork, on GitHub's runners: `supabase db push`; the Data API (`api` only)
  through the Management API; `CRON_SECRET`, the project's publishable key
  (`WW_PUBLISHABLE_KEY`, read from the Management API), `WW_SERVER_VERSION` when the
  checkout is on a `server-v` tag, the mail values, and the functions (`verify_jwt` per
  function from `config.toml`; `scripts/no-user-functions.test.mjs` keeps that list equal
  to the compose router's `NO_USER_FUNCTIONS`); Auth through
  [`scripts/hosted-auth-config.mjs`](../scripts/hosted-auth-config.mjs) (sign-up **on**, as
  specs/20 needs since 2026-10-15; the access-token hook, TOTP, the compose overlay's
  limits, SMTP or the send-email hook, read back); the jobs and the setup token through the
  Management API's query endpoint; then a **verification**: the discovery document, each
  of the four jobs called with the cron secret (200, so none is missing from the
  `verify_jwt` list), four `cron.job` rows, sign-up on, and Auth's autoconfirm and the
  discovery document's `sign_in.email_code` matching the mail configured; optionally the web
  app on GitHub Pages.
- **Compatibility:** a migration that changes the app–server contract raises `api_version`
  in `api.server_info()`. Each app release supports the current and the previous one; a
  server can turn old apps away with `min_app_version`. Release numbers of the apps and
  the server are independent; the docs' server page shows which release speaks which API
  in a table the docs build reads from the release tags (`docs/.vitepress/theme/
  compat.data.mts`), so it cannot fall behind a release. An addition within one API
  version that an old server lacks is announced in `features`, not by a new API version.
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
   the known risks), and a first `server-v` tag. *2026-10-25, found by reading, not by the
   test:* the workflow switched sign-up off and `household-purge` lacked `verify_jwt =
   false`, both fixed; the workflow now verifies its own result. Still open on hosted: the
   Edge runtime's limits (2 s CPU, 150 s/400 s wall clock) against `calendar-import`'s 20
   feeds and the zip export, and whether a project with legacy keys disabled still passes
   usable `SUPABASE_ANON_KEY`/`SUPABASE_SERVICE_ROLE_KEY` values to the functions.
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
| The project's website | Independent pipeline in `wuselwall/wuselwall-website` | Its marketing container only |
| The user documentation | `.github/workflows/docs.yml`, GitHub Pages opt-in | Static Pages artifact; no server SSH credentials |

### The web app

Every server serves the web build of its own release; it finds the server at its own
origin's `/.well-known/wuselwall.json`, using the server address and publishable key set
during server installation. `scripts/deploy-web.sh` publishes the same backend-neutral
build from a checkout; it never reads `app/env/dev.json` or embeds a developer's backend.
The discovery document must be reachable through the web host's proxy, even when Auth
lives at another origin. Developer-only fixed-server builds remain available with
`flutter run --dart-define-from-file=env/dev.json`, not through the deployment helper.
The browser refreshes its own origin's discovery document before constructing clients,
including with a stored backend/key. Offline it may use that saved configuration; an
incompatible or invalid online document does not fall back to stale settings. When the
configured backend address changes, discard the old backend's saved authentication and
setup capability before connecting. A new valid setup link for this installation is
still retained. Native store apps keep their explicitly selected server behaviour.

### The Android app

Until the Play listing exists, `release-android.yml` builds a signed APK and
`scripts/deploy-apk.sh` publishes it at the address in `scripts/remote.env`.

### The user documentation

`docs/` stays with the app and is built on self-hosted Linux build runners,
for pull requests and `main` alike (Flutter demo, Playwright screenshots in all four
languages/both themes, VitePress with `DOCS_BASE=/`). The
prepared publisher uses a GitHub Pages artifact and OIDC with job-scoped `pages: write`
and `id-token: write`; it uses the build fleet rather than the production deploy runner and needs no SSH secrets.

Publishing stays disabled until `DOCS_PAGES_ENABLED=true` is set after the operator
makes the app repository public, configures Pages and `docs.wuselwall.app`, and
approves cutover. Until then the website server keeps the guide at `/docs/` as last
deployed. PR builds
never deploy. Old `wuselwall.app/docs/` content and app links must remain served until
the custom domain works; change them to path-preserving redirects only after verification.
See the [cutover checklist](website-and-docs-migration.md). No visibility, DNS, secret
or live-host changes are implied by the prepared workflow.

## Updates

| What | How | Cadence |
|---|---|---|
| Supabase images | Bump the pinned CLI in `package.json`, run CI, set the same tags in `docker-compose.wuselwall.yml`, release | Quarterly, or for a security fix |
| Upstream compose file | Copy `docker/` from a newer upstream commit into `infra/supabase/` (never edit it), note the commit in the layer's header, diff the rendered config | When an image bump needs it, or yearly |
| `pub`, npm, fastlane, GitHub Actions, Deno | Dependabot PRs, reviewed; `osv-scanner` in CI | Weekly PRs, merged monthly; security fixes at once |
| iOS signing certificate, Apple Developer Program | `fastlane match` renewal; renewal | Yearly |
| SMTP provider (if mail is on) | Deliverability check (`wuselwall mail test`); a Gmail app password stops working when the Google password changes | Quarterly, and after any DNS or password change |
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


### Self-hosted Actions runners (2026-10-22)

Every job uses a self-hosted runner: Linux jobs select `[self-hosted, Linux, build]`,
iOS selects `[self-hosted, macOS]`, and website deployment retains its dedicated
`[self-hosted, linux, wuselwall-deploy]` assignment in the separate repository.
This also applies to PRs, change detection, required checks, docs/Pages, Play uploads
and the manual hosted-Supabase installer. Forks must provide their own runner access.
Build runners need the toolchains used by their jobs, including Docker/Compose for the
backend and website checks and Chromium system dependencies for browser tests.
Backend runners must have a CI-only Docker daemon, never access to a family's live
stack. The backend job serializes its local stack and removes it after each run.
No changes to runner registration, billing, repository visibility or deployment settings
are implied; existing publishing gates and deployment secrets remain scoped to their jobs.
