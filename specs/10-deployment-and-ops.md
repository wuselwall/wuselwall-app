# 10 — Deployment & Operations (B3)

You said you have no deployment experience, so this is written as a path to follow
rather than a set of options to weigh. Decision context:
[ADR-013](adr/ADR-013-one-self-hosted-environment.md).

**The shape of it:** one environment. The Supabase stack runs on the home server (homeserver,
Docker) and is reached at `https://wusel.example.org` through Cloudflare's proxy and the
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
| Domain `example.org` | already owned | €0 extra |
| TLS and proxy | Cloudflare free plan | €0 |
| Apple Developer Program | Apple | €99 / year ≈ €8.25 |
| Google Play Console | Google | $25 once |
| Off-site copy of the backups (optional) | Backblaze B2 or similar | €0.50 – €3.50 |
| **Total** | | **≈ €8 – 12 / month** |

## The path a request takes

```
 phone / laptop
   │ HTTPS
   ▼
 Cloudflare edge (proxied DNS record wusel.example.org, TLS)
   │ HTTPS, Cloudflare origin certificate
   ▼
 router: TCP 443 → home server
   │
   ▼
 nginx (home server): only /auth/v1, /rest/v1, /realtime/v1, /functions/v1
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

- Cloudflare: a **proxied** (orange-cloud) record for `wusel.example.org`, pointing at the
  same origin as the other subdomains. SSL mode **Full (strict)**, using the Cloudflare
  origin certificate nginx already holds.
- nginx: the site file in the repository,
  [`infra/nginx/wusel.example.org.conf`](../infra/nginx/wusel.example.org.conf), copied into
  the nginx container's site directory, then `nginx -t && nginx -s reload`. It forwards the
  four API prefixes and refuses everything else, including Kong's dashboard and the
  `/pg/` metadata API.

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

Setup is guarded by a one-time token (ADR-010 implementation notes). The development seed
creates the token `dev-setup`; before the family sets up its real household, replace it
with a random one:

```bash
scripts/remote-setup-token.sh       # prints a fresh token once, stores only its hash
```

Then open the app, choose "set up a new household" and enter the token. Setup closes for
good once a household exists.

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
nightly, from the homeserver *User Scripts* plugin (schedule: daily, e.g. 03:30):

- `pg_dumpall --roles-only` and a custom-format `pg_dump` of the whole database, written
  to `/srv/backups/wuselwall/`, 14 days kept.
- If `RESTIC_REPOSITORY` is set in `/boot/config/wuselwall-backup.env`, the dumps go to an
  encrypted off-site repository too (restic runs from its Docker image, so nothing is
  installed on homeserver).
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
| homeserver, Docker | homeserver's own update path | As homeserver releases |
| nginx container, Cloudflare origin certificate | Container updates; the origin certificate is valid for up to 15 years | As needed |
| Flutter, `pub` and Deno dependencies | Dependabot PRs, reviewed | Weekly PRs, merged monthly |
| iOS signing certificate | `fastlane match` renewal | Yearly — calendar reminder |
| Apple Developer Program | Renewal | Yearly — lapsing removes TestFlight builds |
| TestFlight builds | Any new release | Expire after 90 days — release at least quarterly |

Do **not** let a container auto-updater (Watchtower, homeserver's auto-update plugin) touch
the `supabase_*` containers. Automatic updates to a database container is how you find
out that a major version bump needed a migration, at 03:00, with no one awake.

---

## Monitoring

Keep it proportionate — this is a family app, not a service with an SLA.

- **healthchecks.io** free tier: the nightly backup ping, plus later a ping from a
  `pg_cron` job (via `pg_net`) so you learn if scheduled jobs have stopped.
- **Uptime monitoring** on `https://wusel.example.org/auth/v1/health`, alerting to email.
- **Logs**: `docker logs supabase_<service>_wuselwall` on the home server.
