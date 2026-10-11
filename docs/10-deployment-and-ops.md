# 10 — Deployment & Operations (B3)

You said you have no deployment experience, so this is written as a path to follow
rather than a set of options to weigh. Decision context: [ADR-005](adr/ADR-005-hosting.md).

**The shape of it:** one small virtual server in a German data centre, running the
self-hosted Supabase stack under Docker Compose, with Caddy in front of it obtaining TLS
certificates by itself and serving the Flutter web build, and an encrypted nightly backup
to a second location.

*Revised 2026-10-11 for self-hosted Supabase ([ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md)).
Steps 1–4 are unchanged; the server is one size larger, and steps 5–8, shipping, backups
and updates are new. The CI/CD side is in [16](16-setup-plan.md).*

---

## Costs

| Item | Provider | ~Cost / month |
|---|---|---|
| Server: shared vCPU, **8 GB RAM**, 80 GB disk (Hetzner CX32 or its current equivalent, Nürnberg or Falkenstein) | Hetzner Cloud | ≈ €7–8 net |
| IPv4 address | Hetzner | ~€0.60 |
| Domain (e.g. `.de`) | any registrar | ~€1 (≈ €10–15/year) |
| Off-site encrypted backups (a few GB) | Backblaze B2 or Hetzner Storage Box | €0.50 – €3.50 |
| Uptime monitoring | healthchecks.io free tier | €0 |
| **Hosting subtotal** | | **≈ €9 – 13 / month** |
| Apple Developer Program | Apple | €99 / year ≈ €8.25 |
| Google Play Console | Google | $25 once |
| **Total** | | **≈ €18 – 21 / month** |

This no longer fits the original €10 target; NFR-7 is revised and the decision is the
user's ([Q36](14-open-questions.md)). Hetzner renames and reprices its server types from
time to time, so verify the type and price at purchase.

**Why 8 GB.** Self-hosted Supabase is about a dozen containers — Postgres, Kong, Auth,
PostgREST, Realtime, the Edge runtime, Storage, the pooler, Studio, the metadata service —
and runs uncomfortably in 4 GB once Postgres has a sensible `shared_buffers`. Trimming
the optional services (step 5) helps; it does not make a 4 GB box comfortable.

## Step by step

### 1. Domain

Buy a domain, or use a subdomain of one you own. You need two names:

```
home.example.de       → the web build, the Supabase API, the ICS feeds
mcp.home.example.de   → the MCP server (M2)
```

Point both at the server's IPv4 (`A`) and IPv6 (`AAAA`) addresses once you have them.
Set the TTL low (300 s) while you are setting things up.

### 2. Create the server

In the Hetzner Cloud console: new project → new server → location **Nürnberg** or
**Falkenstein** → image **Ubuntu 24.04 LTS** → type **CX32** (8 GB) → **add your SSH public
key** → create.

Generate a key first if you have none:

```bash
ssh-keygen -t ed25519 -C "wuselwall"
```

Never enable password authentication. An SSH port on the public internet sees login
attempts within minutes of existing; keys make that traffic irrelevant rather than
merely unlikely.

### 3. Harden the base system

Log in as root once, then:

```bash
# create a non-root user with sudo
adduser --disabled-password --gecos "" wuselwall
usermod -aG sudo wuselwall
mkdir -p /home/wuselwall/.ssh
cp /root/.ssh/authorized_keys /home/wuselwall/.ssh/
chown -R wuselwall:wuselwall /home/wuselwall/.ssh
chmod 700 /home/wuselwall/.ssh && chmod 600 /home/wuselwall/.ssh/authorized_keys

# SSH: keys only, no root login
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

# firewall
ufw default deny incoming && ufw default allow outgoing
ufw allow OpenSSH && ufw allow 80/tcp && ufw allow 443/tcp
ufw --force enable

# automatic security updates + brute-force protection
apt update && apt install -y unattended-upgrades fail2ban
dpkg-reconfigure -plow unattended-upgrades
systemctl enable --now fail2ban
```

Open a **second** terminal and confirm you can log in as `wuselwall` before closing the
first. Locking yourself out of a fresh server is a rite of passage worth skipping.

### 4. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker wuselwall
# log out and back in for the group to take effect
```

### 5. The Supabase stack

Start from Supabase's official self-hosting setup — the `docker/` directory of the
`supabase/supabase` repository — **not** from a blog post. The repository's
`infra/supabase/` holds a pinned, trimmed copy ([16](16-setup-plan.md#step-8--production-stack-and-deployment-m03-deployed-at-m16)),
and that copy is what goes onto the server:

```bash
sudo mkdir -p /opt/wuselwall && sudo chown wuselwall: /opt/wuselwall
cd /opt/wuselwall
git clone --depth 1 https://github.com/<you>/WuselWall.git src   # or rsync from CI
cp -r src/infra/supabase ./supabase
cp src/infra/Caddyfile ./Caddyfile
```

What the trimmed copy changes from upstream, and why:

| Change | Why |
|---|---|
| Every image pinned by digest | An update is a decision, never a side effect of a restart |
| Analytics (Logflare) and Vector removed | The heaviest optional services; Docker's own logs suffice at this scale. Studio's log explorer stops working, which is acceptable |
| Image proxy removed | No image transformations needed |
| Storage kept, unused until avatars or recipe photos | Cheap to keep, awkward to add later |
| The pooler's ports bound to `127.0.0.1` | Upstream publishes Postgres on every interface. Here it is reachable only from the server itself, and from CI through an SSH tunnel |
| Kong's ports bound to `127.0.0.1` | Only Caddy talks to Kong |
| Studio not routed anywhere | Reached with `ssh -L 3000:localhost:3000`, never from the internet |
| Caddy added as a service, the only container with public ports | One place for TLS, headers and the path allow-list |

**No port other than Caddy's 80 and 443 is published to the outside.** An exposed
Postgres port or an exposed Studio is the most common way a self-hosted Supabase is
compromised.

### 6. Caddyfile

`/opt/wuselwall/Caddyfile`:

```caddyfile
{
    email you@example.de
}

home.example.de {
    encode zstd gzip
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options    "nosniff"
        X-Frame-Options           "DENY"
        Referrer-Policy           "strict-origin-when-cross-origin"
        Permissions-Policy        "geolocation=(), microphone=(), camera=()"
        -Server
    }

    # The Supabase API: these four prefixes and nothing else.
    # Kong's dashboard and pg-meta routes are simply never proxied.
    @api path /auth/v1/* /rest/v1/* /realtime/v1/* /functions/v1/*
    handle @api {
        reverse_proxy kong:8000
    }

    # Calendar feeds: /ics/<token>.ics → the ics Edge Function
    handle_path /ics/* {
        rewrite * /functions/v1/ics{path}
        reverse_proxy kong:8000
    }

    # Everything else: the Flutter web build (mounted at /srv/web)
    handle {
        root * /srv/web
        try_files {path} /index.html
        file_server
    }
}
```

The `handle` blocks are mutually exclusive, so a request is either API, feed or web build
— never two of them. Storage is not routed until it is actually used; add `/storage/v1/*` to `@api` then. The MCP host
is added in M2. A Content-Security-Policy for the web build belongs here as well, written
once the build exists so it can be strict rather than aspirational (NFR-9). Note that
Flutter web needs `'wasm-unsafe-eval'` for its renderer.

### 7. Secrets

`/opt/wuselwall/supabase/.env`, `chmod 600`, owned by `wuselwall`, **never in git**.
Generate every value fresh for production, following the self-hosting guide's section on
securing the stack:

```
POSTGRES_PASSWORD=<openssl rand -base64 32>
JWT_SECRET=<openssl rand -base64 48>          # at least 32 characters
ANON_KEY=<JWT signed with JWT_SECRET, role anon>
SERVICE_ROLE_KEY=<JWT signed with JWT_SECRET, role service_role>
DASHBOARD_USERNAME=…  DASHBOARD_PASSWORD=…     # Studio, behind the SSH tunnel anyway
SECRET_KEY_BASE=<openssl rand -base64 48>
VAULT_ENC_KEY=<32 characters>
SITE_URL=https://home.example.de
API_EXTERNAL_URL=https://home.example.de
SUPABASE_PUBLIC_URL=https://home.example.de
ENABLE_EMAIL_SIGNUP=false                      # no public sign-up, ever
ENABLE_ANONYMOUS_USERS=false
```

**Never deploy with the example keys** from the upstream `.env.example`: they are
public, and anyone holding them holds your service role. Changing `JWT_SECRET` later
invalidates every device session, so set it once, store it in the password manager, and
leave it alone.

### 8. First launch

```bash
cd /opt/wuselwall/supabase
docker compose pull
docker compose up -d
docker compose ps                       # every service healthy
```

Then, from the development machine or CI: apply the migrations through the tunnel
(`supabase db push`), sync the Edge Functions, publish the web build (all three are what
`deploy.yml` does, [16](16-setup-plan.md#step-8--production-stack-and-deployment-m03-deployed-at-m16)),
and run the setup wizard from [08](08-users-auth-permissions.md) with the one-time setup
token.

---

## Building and shipping code

Nothing is built on the server. GitHub Actions tests every change, and on approval:

```
push to main  → deploy.yml (approval)
  → backup → migrations through an SSH tunnel → Edge Functions synced
  → web build published → health check
tag vX.Y.Z    → release-mobile.yml
  → Android App Bundle to the Play internal track, iOS build to TestFlight
```

The full pipeline, its secrets and its rollback story are in [16](16-setup-plan.md#cicd-at-a-glance).
The deploy key is restricted to the `wuselwall` user and used only by that workflow.

Migrations are forward-only and must keep working with the previous app release, because
phones update on their own schedule. Always back up immediately before applying them —
`deploy.yml` does it for you, and does it first.

---

## Backups

The one operational thing that genuinely matters. Everything else can be rebuilt from
git; the database cannot — and with Supabase it holds the device and guardian accounts
(the `auth` schema) as well as the family's data.

**Nightly**, via a cron entry on the host:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd /opt/wuselwall/supabase
STAMP=$(date +%F)
OUT=/var/backups/wuselwall
# roles first (Supabase relies on its own roles), then the whole database incl. auth
docker compose exec -T db pg_dumpall -U postgres --roles-only > $OUT/roles-$STAMP.sql
docker compose exec -T db pg_dump -U postgres --format=custom postgres > $OUT/db-$STAMP.dump
restic -r "$RESTIC_REPOSITORY" backup $OUT /opt/wuselwall/supabase/.env \
  /opt/wuselwall/supabase/volumes/storage
restic forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --prune
curl -fsS -m 10 "https://hc-ping.com/<uuid>"     # dead-man's switch
find $OUT -name '*.dump' -mtime +3 -delete
find $OUT -name 'roles-*.sql' -mtime +3 -delete
```

- **restic** encrypts client-side, so the backup target never sees plaintext family data.
  Target: Backblaze B2, or a Hetzner Storage Box if you prefer to keep everything in
  Germany.
- The **`.env` is part of the backup** because the `JWT_SECRET` in it is what makes the
  restored device sessions valid. Restoring the data without it means re-enrolling every
  device.
- The **healthchecks.io ping** is what turns this from a backup script into a backup
  system. A backup that silently stopped six weeks ago is the normal failure mode, and
  the only defence is being told when a run does not happen.
- Retention: 7 daily, 5 weekly, 12 monthly. A few hundred MB at most.

**Restore drill — do this once, in the first month, and note the date here.** An
untested backup is a hypothesis. `infra/backup/restore-drill.sh` restores the latest
snapshot into a fresh, local Supabase stack (the Supabase CLI's, on the development
machine), runs the pgTAP suite against it and counts rows in the main tables. Doing the
drill before a risky release doubles as a migration rehearsal against real data.

RPO 24 h, RTO ~4 h (NFR-11). For a family calendar, losing at most one day is acceptable;
losing everything is not.

---

## Updates

| What | How | Cadence |
|---|---|---|
| Ubuntu security patches | `unattended-upgrades` | Automatic |
| Kernel reboots | `needrestart`, or reboot after patch Tuesday | Monthly |
| Supabase images | Re-copy the upstream compose, diff against `infra/supabase/`, re-pin digests, PR through CI, deploy after a backup | Quarterly, or for a security fix |
| Caddy image | Re-pin, deploy | Quarterly |
| Flutter, `pub` and Deno dependencies | Dependabot PRs, reviewed | Weekly PRs, merged monthly |
| Postgres major version | Only as part of a Supabase upgrade that requires it — dump, restore into the new version, test, switch | Rarely, deliberately |
| iOS signing certificate | `fastlane match` renewal | Yearly — calendar reminder |
| Apple Developer Program | Renewal | Yearly — lapsing removes TestFlight builds |
| TestFlight builds | Any new release | Expire after 90 days — release at least quarterly |

Do **not** run Watchtower for unattended container updates on this stack. Automatic
updates to a database container is how you find out that a major version bump needed a
migration, at 03:00, with no one awake.

---

## Monitoring

Keep it proportionate — this is a family app, not a service with an SLA.

- **healthchecks.io** free tier: nightly backup ping, plus a ping from a `pg_cron` job
  (via `pg_net`) so you learn if scheduled jobs have stopped.
- **Uptime monitoring** on `https://home.example.de/functions/v1/health`, alerting to
  email.
- **Logs**: Docker's json-file driver with rotation (`max-size: 10m`, `max-file: 3`).
  `docker compose logs` is a sufficient investigation tool at this scale.
- **Disk**: a weekly cron that emails if the volume exceeds 80%. Postgres plus images
  will not fill 80 GB for years, but an unrotated log file will.

---

## The simpler alternative, honestly assessed

**Coolify** is a self-hosted PaaS you install on the same VPS: a web UI that handles
Docker deployments, TLS, environment variables, databases and scheduled backups, with
git-push deploys.

Coolify also ships a one-click Supabase template, which makes it more tempting with this
stack than with the previous one.

**For:** it removes most of steps 5–8 and gives you a dashboard, which genuinely helps if
Docker Compose feels opaque. **Against:** it is a substantial extra system running as
root on your server, it becomes the thing you have to keep patched and understand when it
misbehaves, and you learn less about what is actually happening.

The recommendation is to start with plain Compose. It is roughly one extra evening of
work, the resulting stack is a pinned compose file you have read line by line, and when
something breaks at an inconvenient moment you will be debugging your own configuration
rather than someone else's abstraction over it. If after a month the operational side is
consistently the part that stalls progress, Coolify is a reasonable retreat, and nothing
in the architecture prevents it.
