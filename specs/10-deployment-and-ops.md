# 10 — Deployment & Operations (B3)

You said you have no deployment experience, so this is written as a path to follow
rather than a set of options to weigh. Decision context:
[ADR-013](adr/ADR-013-one-self-hosted-environment.md).

**The shape of it:** one environment. The Supabase stack runs on the home server (Unraid,
Docker) and is reached at `https://wusel.goomba.ch` through Cloudflare's proxy and the
home server's nginx. The family uses it, and development happens against it. A nightly
dump protects the data.

*Rewritten 2026-10-11 for ADR-013. The VPS, Caddy and `deploy.yml` of the previous
version are gone. The same day the stack moved from the Supabase CLI's to the
official self-hosting compose file ([ADR-013 amendment](adr/ADR-013-one-self-hosted-environment.md#amendment-2026-10-11-the-official-compose-stack)).*

*Since [ADR-015](adr/ADR-015-saas-and-self-hosted-flavours.md) (2026-10-11) there are two
flavours. This document's step-by-step path is the **self-hosted** one: the Unraid stack,
home to the family's household and to development and testing. **WuselWall Cloud**, the
hosted Supabase project that holds every self-service household, has
[its own section](#wuselwall-cloud).*

---

## Costs

| Item | Provider | ~Cost / month |
|---|---|---|
| Server | The home server, already running | €0 (electricity) |
| Domain `goomba.ch` | already owned | €0 extra |
| TLS and proxy | Cloudflare free plan | €0 |
| Apple Developer Program | Apple | €99 / year ≈ €8.25 |
| Google Play Console | Google | $25 once |
| Off-site copy of the backups (optional) | Backblaze B2 or similar | €0.50 – €3.50 |
| SMTP for sign-in codes ([Q41](14-open-questions.md)) | Scaleway Transactional Email | €0 up to 300 mails/month, then €0.25 per 1,000 |
| **Total, self-hosted flavour** | | **≈ €8 – 12 / month** |
| **WuselWall Cloud** ([ADR-015](adr/ADR-015-saas-and-self-hosted-flavours.md)) | Supabase Pro (organisation, one small project's compute included) | ≈ $25 |
| Cloud's custom domain, once [Q45](14-open-questions.md) is decided | Supabase add-on | ≈ $10 |
| Static links site (landing pages, `/.well-known/`) | Cloudflare Pages free plan | €0 |
| **Total with Cloud** | | **≈ €40 – 50 / month** |

Supabase's prices are as known on 2026-10-11. Check the pricing page before the project
is created.

## The path a request takes

```
 phone / laptop
   │ HTTPS
   ▼
 Cloudflare edge (proxied DNS record wusel.goomba.ch, TLS)
   │ HTTPS, Cloudflare origin certificate
   ▼
 router: TCP 443 → home server
   │
   ▼
 nginx (home server): only /auth/v1, /rest/v1, /realtime/v1, /functions/v1
   │                    + static: /.well-known/*, /i/*, /p/*, /privacy, /delete (ADR-014)
   │ HTTP, Docker bridge (172.17.0.1 — not reachable from the home network)
   ▼
 Envoy :54421 ─► Auth · PostgREST · Realtime · Edge runtime · Storage · (Studio, /pg/)
                    │
                    ▼
                 Postgres  (127.0.0.1:54422 on the server, for SSH tunnels only)
```

Only the gateway is forwarded, and only four of its prefixes. Nothing of the stack listens
on the home network: the gateway is bound to the Docker bridge address, Postgres to
`127.0.0.1`, and there is no pooler and no Mailpit. Studio sits behind the gateway with a
login and is reached by SSH tunnel (`scripts/remote-stack.sh tunnel`, then
`http://127.0.0.1:54421`).

## Step by step

### 1. DNS and nginx

- Cloudflare: a **proxied** (orange-cloud) record for `wusel.goomba.ch`, pointing at the
  same origin as the other subdomains. SSL mode **Full (strict)**, using the Cloudflare
  origin certificate nginx already holds.
- nginx: the site file in the repository,
  [`infra/nginx/wusel.goomba.ch.conf`](../infra/nginx/wusel.goomba.ch.conf), copied into
  the nginx container's site directory, then `nginx -t && nginx -s reload`. It forwards the
  four API prefixes and refuses everything else, including Studio and the `/pg/`
  metadata API.
- *Since [ADR-014](adr/ADR-014-self-service-onboarding.md):* nginx also serves a handful
  of **static files** from `infra/web/` (no proxying, no scripts):
  `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json` (universal
  links, App Links and passkeys), the bilingual landing pages for `/i/‹token›`
  (invitations) and `/p/‹code›` (pairing), the privacy policy, and the account-deletion
  page Google Play requires.

### 2. The stack and its secrets

The stack is Supabase's **official self-hosting compose file**, pinned to an upstream
commit and copied verbatim into [`infra/supabase/`](../infra/supabase/), plus our layer
`docker-compose.wuselwall.yml`. That layer pins the images to the versions the Supabase
CLI in `package.json` runs (so CI and the home server agree), carries the
`supabase/config.toml` auth settings as GoTrue variables, and narrows the ports. It runs
from `/mnt/cache/appdata/wuselwall/supabase` on the server — the cache path, not the
FUSE `/mnt/user` path, because Postgres should not write through `shfs`.

```bash
scripts/remote-stack.sh init-env      # once: writes the server's .env, refuses to overwrite
scripts/remote-stack.sh deploy        # sync infra/supabase + supabase/functions, up -d
scripts/remote-stack.sh ps            # any docker compose command: logs -f auth, restart rest
```

**The secrets live only in the server's `.env`** (`chmod 600`), generated by
`infra/supabase/make-env.mjs`. It keeps three values from `supabase/.env`, so the
installed apps keep working without a rebuild:

```
WW_JWT_SECRET       → JWT_SECRET (HS256; still verified, listed in the JWKS)
WW_PUBLISHABLE_KEY  → SUPABASE_PUBLISHABLE_KEY (compiled into the apps)
WW_SECRET_KEY       → SUPABASE_SECRET_KEY
```

and generates the rest: a strong Postgres password, an EC P-256 key pair that signs new
tokens, the services' own encryption keys and the Studio login. **Copy the server's `.env`
into the password manager**: without the JWT secret and the signing key a restored
database strands every device. Never regenerate it for a running stack.

`supabase/.env` and `config.toml` remain the definition of the *throwaway* stacks (CI,
`npx supabase start` on the laptop). A setting changed in one must be changed in the other.

`docker compose down` keeps the data (it lives in `volumes/db/data`). **Never delete that
directory or run `supabase db reset` against the home server.**

### 3. First household

*Rewritten 2026-10-11 for [ADR-014](adr/ADR-014-self-service-onboarding.md).* Households
are created from the app by any signed-in adult. While `household_creation` is `code` (the
default until the opening gate), creating one also needs a **founder code**:

```bash
scripts/remote-setup-token.sh       # prints a fresh single-use founder code, stores only its hash
```

The founder signs in on their phone (Apple, Google or email), enters the family name and
the code, and the rest follows [20, J1](20-onboarding.md#j1--start-a-family). Issue one code
per household you want to allow. The development seed's `dev-setup` must not exist on the
home server.

Switching to self-service is one statement, run only once the opening gate in
[13](13-roadmap.md#opening-to-other-households) is passed:

```sql
update app.instance_setting set household_creation = 'open';
```

### 4. Sign-in providers and mail

Needed before the onboarding flows work outside a throwaway stack. On the home server
every secret goes into the stack's `.env` and reaches GoTrue through
`docker-compose.wuselwall.yml` (`GOTRUE_EXTERNAL_APPLE_*`, `GOTRUE_EXTERNAL_GOOGLE_*`,
`SMTP_*`); for throwaway stacks the same values go into `supabase/.env` and are referenced
from `config.toml` as `env(...)`:

- **Apple:**
  - the App ID `ch.goomba.wuselwall` with the *Sign in with Apple* capability;
  - a **Services ID** for the web and Android redirect, with
    `https://‹domain›/auth/v1/callback` as its return URL;
  - a **Sign in with Apple key** (`.p8`).

  The client secret Supabase needs is a JWT signed with that key, and **it expires after
  at most six months**: regenerate it on the date in the table below.
- **Google:** a Google Cloud project with an OAuth consent screen (scopes `openid email
  profile`) and three OAuth clients: **Web** (its ID and secret go to Supabase, its ID is
  the `serverClientId` in the app), **iOS** (bundle ID; its reversed client ID becomes a
  URL scheme) and **Android** (package name and the SHA-1 of the Play app-signing key *and*
  of the debug key).
- **Email**: see [Email setup](#email-setup) below.

On WuselWall Cloud the same Apple and Google values are entered in the project's Auth
settings. Native sign-in works there and on the first-party Unraid stack (whose
`config.toml` carries the same client IDs). Other self-hosted servers offer email, plus
Apple and Google through the web redirect if their operator registers their own clients
([ADR-015](adr/ADR-015-saas-and-self-hosted-flavours.md), decision 4).

### Email setup

*Decided 2026-10-11 ([Q41](14-open-questions.md)).* Sign-in codes
are the only mail WuselWall sends, apart from the "new sign-in" notice. So the setup is
built for one thing: a six-digit code in the inbox within seconds, never in spam.

| Decision | Choice | Why |
|---|---|---|
| Provider | **Scaleway Transactional Email** (TEM) | EU company and data centres (Paris); transactional only, so its shared IPs are not dragged down by newsletter senders; 300 mails/month free, then €0.25 per 1,000; no branding footer; SMTP and an HTTP API |
| One Scaleway project per environment | **Cloud** and **Unraid**, each with its own domain and API key | A test run that sends a burst of mail, or a leaked dev key, cannot hurt Cloud's reputation; either key can be revoked alone |
| Sending domain | `goomba.ch` itself, verified in the Unraid project (2026-10-11); Cloud gets its own when it is set up, on the final domain once [Q45](14-open-questions.md) is decided | `goomba.ch` has no mailboxes, so its MX points at Scaleway's blackhole and its SPF names only Scaleway; a domain that receives personal mail would need a sending subdomain instead |
| Sender | `WuselWall <anmeldung@goomba.ch>`, Reply-To a read support address | A recognisable name in the inbox list; replies reach a person, which App Review and GDPR both expect |
| DNS (Cloudflare) | The SPF, DKIM and DMARC records Scaleway shows when the domain is added; DMARC starts at `p=none` with `rua` reports, moves to `p=quarantine` after two clean weeks | Without SPF and DKIM the codes go to spam; Gmail and Yahoo require SPF or DKIM from every sender and DMARC from bulk senders |
| Content | Plain text plus minimal HTML, no images, no tracking pixels, no link tracking (switched off in TEM). **Subject carries the code:** "123456 ist dein WuselWall-Code" / "123456 is your WuselWall code" | The code readable from the notification is the fastest path into the app; tracking would contradict NFR-9 |
| Language | Per recipient (`locale` from sign-in), via the send-email hook; bilingual GoTrue template where the hook is not running | The localisation rule in [CLAUDE.md](../CLAUDE.md) |
| How it is sent | **Cloud:** the send-email hook (Edge Function) calls TEM's HTTP API; the project's SMTP settings point at TEM as the fallback. **Unraid:** the same hook (the compose stack runs Edge Functions); GoTrue's SMTP as the fallback, through the stack's `.env`: `SMTP_HOST=smtp.tem.scaleway.com`, `SMTP_PORT=587` (STARTTLS), `SMTP_USER` = the Scaleway project ID, `SMTP_PASS` = the secret key of an IAM application whose only policy is Transactional Email on that project. Throwaway stacks keep Mailpit | One code path on both servers |
| Rate limits | Auth's email limit raised to fit (e.g. 60/hour per project) and per-address resend at most every 60 s | Hosted Supabase's default email limit is meant for testing and fails silently when reached |
| One provider, no pooling of free tiers | Scaleway alone; a second provider only as a failover, and only after a real outage | Every extra provider is another processor seeing addresses and codes (NFR-9), another SPF/DKIM setup, and splits the sending reputation — to save cents |
| Self-hosters | Bring their own SMTP; the self-hosting guide names TEM as one option | Their mail, their reputation |
| Throwaway stacks | Mailpit, as today | The integration tests read the code from it |

**Checks, before the first stranger signs up:** a code to a Gmail, an Outlook.com, a GMX
and an iCloud address. Each lands in the inbox and passes SPF, DKIM and DMARC (visible in
"show original"). Then quarterly, and after any DNS change ([Updates](#updates)).

---

## WuselWall Cloud

*Added 2026-10-11 ([ADR-015](adr/ADR-015-saas-and-self-hosted-flavours.md)).* Not created
yet. It goes live with the opening gate in [13](13-roadmap.md#opening-to-other-households).

- **Project:** in the user's own Supabase organisation, region **Frankfurt
  (eu-central-1)**, Pro plan. Supabase's DPA accepted for the organisation. MFA on every
  organisation member's Supabase login.
- **Configuration from the repository:** `supabase link --project-ref ‹ref›`, then
  migrations with `supabase db push` and functions with `supabase functions deploy`. Auth
  settings (providers, OTP, rate limits, hooks) follow `supabase/config.toml` and are
  checked in the dashboard after each change. Nothing is configured only by clicking.
- **Order of a change:** CI → Unraid (`scripts/remote-migrate.sh`) → Cloud. Cloud gets a
  manual backup point before `db push`, and never `db reset` or the integration test.
- **Backups:** Supabase's daily backups on Pro, plus point-in-time recovery once
  strangers depend on it. A weekly `pg_dump` from the project into the off-site restic
  repository makes sure the data never lives with one provider only.
- **The app:** store builds use `app/env/cloud.json` (URL and publishable key; public
  values only). Development builds keep `env/dev.json` (Unraid).
- **Links site:** the landing pages, `/.well-known/` files, privacy policy and deletion
  page move from the Unraid nginx to Cloudflare Pages when Cloud goes live, so that
  invitations to Cloud do not depend on the home server.
- **Self-hosted discovery:** each self-hosted server serves
  `/.well-known/wuselwall.json` (Supabase URL, publishable key, enabled sign-in methods,
  `min_app_version`). Cloud needs none, because it is compiled into the store app.

## Changing the database

There is no deployment pipeline: a migration is applied once, to the one environment.

```
feature branch ──PR──► ci.yml: every migration from zero on a throwaway stack,
                       pgTAP, Flutter tests, the integration test
      │ green
      ▼
scripts/remote-migrate.sh       — backup, pending migrations, pgTAP; stops at the first failure
```

pgTAP runs in rolled-back transactions, so it is safe on the live data.

Migrations are forward-only and must keep working with the previous app release, because
phones update on their own schedule.

---

## Backups

The one operational thing that genuinely matters. Everything else can be rebuilt from
git; the database cannot, and it holds the device and guardian accounts (the `auth`
schema) as well as the family's data.

[`infra/backup/backup.sh`](../infra/backup/backup.sh) runs **on the home server**,
nightly, from the Unraid *User Scripts* plugin (schedule: daily, e.g. 03:30):

- `pg_dumpall --roles-only` and a custom-format `pg_dump` of the whole database, written
  to `/mnt/user/backups/wuselwall/`, 14 days kept.
- If `RESTIC_REPOSITORY` is set in `/mnt/user/appdata/wuselwall/backup.env`, the dumps go to an
  encrypted off-site repository too (restic runs from its Docker image, so nothing is
  installed on Unraid).
- If `HEALTHCHECK_URL` is set, a ping to healthchecks.io afterwards. A backup that
  silently stopped six weeks ago is the normal failure mode; the ping is what tells you.

`scripts/remote-backup.sh` runs the same script on demand from the development machine.
Run it before every migration.

**Keep the stack's `.env` with the backups** (in the password manager): the JWT secret and
the signing key in it are what make restored device sessions valid. Restoring without
them means re-enrolling every device.

**Restore drill — do this once, in the first month, and note the date here.** An
untested backup is a hypothesis. [`infra/backup/restore-drill.sh`](../infra/backup/restore-drill.sh)
restores the latest dump into a scratch database next to the live one, counts rows in the
main tables, and drops the scratch database again. *(Run on the compose stack 2026-10-11,
empty database: 0 errors. Repeat once the family's data exists.)*

RPO 24 h, RTO a few hours (NFR-11). For a family organiser, losing at most one day is
acceptable; losing everything is not.

---

## Updates

| What | How | Cadence |
|---|---|---|
| Supabase images | Bump the pinned CLI in `package.json`, run CI; set the same image tags in `infra/supabase/docker-compose.wuselwall.yml`; back up; `scripts/remote-stack.sh deploy` | Quarterly, or for a security fix |
| Upstream compose file | Copy `docker/` from a newer upstream commit into `infra/supabase/` (never edit it), update the commit in the layer's header, diff the rendered config (`scripts/remote-stack.sh config`), deploy | When an image bump needs it, or yearly |
| Unraid, Docker | Unraid's own update path | As Unraid releases |
| nginx container, Cloudflare origin certificate | Container updates; the origin certificate is valid for up to 15 years | As needed |
| Flutter, `pub` and Deno dependencies | Dependabot PRs, reviewed | Weekly PRs, merged monthly |
| iOS signing certificate | `fastlane match` renewal | Yearly — calendar reminder |
| Apple Developer Program | Renewal | Yearly — lapsing removes TestFlight builds |
| **Sign in with Apple client secret** (a JWT from the `.p8` key) | Regenerate, put in the stack's `.env`, `scripts/remote-stack.sh up -d auth` | **Every six months at the latest** — calendar reminder; an expired secret breaks Apple sign-in on Android and the web |
| Google OAuth clients | Add the SHA-1 of any new signing key | When a signing key changes |
| SMTP provider | Check deliverability (a test code to Gmail, Outlook.com, GMX and iCloud; SPF/DKIM/DMARC pass) | Quarterly, and after any DNS change |
| Supabase Pro (Cloud) | Review usage and the invoice; Postgres and Auth upgrades are scheduled by Supabase, read their notices | Monthly glance |
| TestFlight builds | Any new release | Expire after 90 days — release at least quarterly |

Do **not** let a container auto-updater (Watchtower, Unraid's auto-update plugin) touch
the `supabase-*` containers. Automatic updates to a database container is how you find
out that a major version bump needed a migration, at 03:00, with no one awake.

---

## Monitoring

Keep it proportionate — this is a family app, not a service with an SLA.

- **healthchecks.io** free tier: the nightly backup ping, plus later a ping from a
  `pg_cron` job (via `pg_net`) so you learn if scheduled jobs have stopped.
- **Uptime monitoring** on `https://wusel.goomba.ch/auth/v1/health` with the publishable
  key as `apikey` header (the gateway answers 401 without it), alerting to email.
- **Logs**: `scripts/remote-stack.sh logs -f <service>` (auth, rest, realtime, db, …).
