# 10 — Deployment & Operations (B3)

You said you have no deployment experience, so this is written as a path to follow
rather than a set of options to weigh. Decision context:
[ADR-013](adr/ADR-013-one-self-hosted-environment.md).

**The shape of it:** one environment. The Supabase stack runs on the home server (Unraid,
Docker) and is reached at `https://wusel.goomba.ch` through Cloudflare's proxy and the
home server's nginx. The family uses it, and development happens against it. A nightly
dump protects the data.

*Rewritten 2026-10-11 for ADR-013. The VPS, Caddy and `deploy.yml` of the previous
version are gone. Further tenants, if any, would get their own hosted Supabase project
instead (see ADR-013).*

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
| SMTP for sign-in codes ([Q41](14-open-questions.md)) | An EU provider's free tier | €0 at household scale |
| **Total** | | **≈ €8 – 12 / month** |

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
   │ HTTP, LAN
   ▼
 Kong :54321 ─► Auth · PostgREST · Realtime · Edge runtime · Storage
                    │
                    ▼
                 Postgres
```

Only Kong is forwarded. Postgres (54322), Studio (54323) and Mailpit (54324) are
published by the CLI stack on the home network and **must never be forwarded or proxied**.

## Step by step

### 1. DNS and nginx

- Cloudflare: a **proxied** (orange-cloud) record for `wusel.goomba.ch`, pointing at the
  same origin as the other subdomains. SSL mode **Full (strict)**, using the Cloudflare
  origin certificate nginx already holds.
- nginx: the site file in the repository,
  [`infra/nginx/wusel.goomba.ch.conf`](../infra/nginx/wusel.goomba.ch.conf), copied into
  the nginx container's site directory, then `nginx -t && nginx -s reload`. It forwards the
  four API prefixes and refuses everything else, including Kong's dashboard and the
  `/pg/` metadata API.
- *Since [ADR-014](adr/ADR-014-self-service-onboarding.md):* nginx also serves a handful
  of **static files** from `infra/web/` (no proxying, no scripts):
  `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json` (universal
  links, App Links and passkeys), the bilingual landing pages for `/i/‹token›`
  (invitations) and `/p/‹code›` (pairing), the privacy policy, and the account-deletion
  page Google Play requires.

### 2. The stack and its secrets

The stack is the Supabase CLI's, started from the development machine against the home
server's Docker daemon:

```bash
scripts/remote-supabase.sh start -x imgproxy,logflare,vector,supavisor
```

It reads its keys from `supabase/.env` (git-ignored, `chmod 600`), referenced from
`supabase/config.toml`:

```
WW_JWT_SECRET=<64 random characters>
WW_PUBLISHABLE_KEY=sb_publishable_<random>
WW_SECRET_KEY=sb_secret_<random>
```

`supabase/.env.example` lists the names. **Never run the stack with the CLI's defaults
while it is reachable**: they are public, and anyone holding them holds the service role.
Changing `WW_JWT_SECRET` later signs out every device, so set it once, store the file in
the password manager, and leave it alone. The publishable key is not a secret — it is
compiled into every app (`app/env/dev.json`) — but the secret key and the JWT secret
never leave `supabase/.env` and the password manager.

`scripts/remote-supabase.sh stop` keeps the data. **`supabase db reset` destroys it** and
is never run against the home server.

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

Needed before the onboarding flows work outside a throwaway stack. All secrets go into
`supabase/.env` and are referenced from `config.toml` as `env(...)`:

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
- **SMTP** ([Q41](14-open-questions.md)): host, user and password in `[auth.email.smtp]`.
  On `goomba.ch` (or the final domain, [Q45](14-open-questions.md)) publish SPF, DKIM and
  DMARC for the provider, or the codes land in spam. Mailpit stays the sink on throwaway
  stacks.

---

## Changing the database

There is no deployment pipeline: a migration is applied once, to the one environment.

```
feature branch ──PR──► ci.yml: every migration from zero on a throwaway stack,
                       pgTAP, Flutter tests, the integration test
      │ green
      ▼
scripts/remote-migrate.sh       — backup, `migration up`, pgTAP; stops at the first failure
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

**Keep `supabase/.env` with the backups** (in the password manager): the JWT secret in it
is what makes restored device sessions valid. Restoring without it means re-enrolling
every device.

**Restore drill — do this once, in the first month, and note the date here.** An
untested backup is a hypothesis. [`infra/backup/restore-drill.sh`](../infra/backup/restore-drill.sh)
restores the latest dump into a scratch database next to the live one, counts rows in the
main tables, and drops the scratch database again.

RPO 24 h, RTO a few hours (NFR-11). For a family organiser, losing at most one day is
acceptable; losing everything is not.

---

## Updates

| What | How | Cadence |
|---|---|---|
| Supabase images | Bump the pinned CLI in `package.json`, run CI, back up, restart the stack | Quarterly, or for a security fix |
| Unraid, Docker | Unraid's own update path | As Unraid releases |
| nginx container, Cloudflare origin certificate | Container updates; the origin certificate is valid for up to 15 years | As needed |
| Flutter, `pub` and Deno dependencies | Dependabot PRs, reviewed | Weekly PRs, merged monthly |
| iOS signing certificate | `fastlane match` renewal | Yearly — calendar reminder |
| Apple Developer Program | Renewal | Yearly — lapsing removes TestFlight builds |
| **Sign in with Apple client secret** (a JWT from the `.p8` key) | Regenerate, put in `supabase/.env`, restart Auth | **Every six months at the latest** — calendar reminder; an expired secret breaks Apple sign-in on Android and the web |
| Google OAuth clients | Add the SHA-1 of any new signing key | When a signing key changes |
| SMTP provider | Check deliverability (a test code to a Gmail and an Outlook address) | Quarterly, and after any DNS change |
| TestFlight builds | Any new release | Expire after 90 days — release at least quarterly |

Do **not** let a container auto-updater (Watchtower, Unraid's auto-update plugin) touch
the `supabase_*` containers. Automatic updates to a database container is how you find
out that a major version bump needed a migration, at 03:00, with no one awake.

---

## Monitoring

Keep it proportionate — this is a family app, not a service with an SLA.

- **healthchecks.io** free tier: the nightly backup ping, plus later a ping from a
  `pg_cron` job (via `pg_net`) so you learn if scheduled jobs have stopped.
- **Uptime monitoring** on `https://wusel.goomba.ch/auth/v1/health`, alerting to email.
- **Logs**: `docker logs supabase_<service>_wuselwall` on the home server.
