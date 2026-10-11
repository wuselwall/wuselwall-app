# 10 — Deployment & Operations (B3)

You said you have no deployment experience, so this is written as a path to follow
rather than a set of options to weigh. Decision context: [ADR-005](adr/ADR-005-hosting.md).

**The shape of it:** one small virtual server in a German data centre, running four
containers managed by Docker Compose, with a reverse proxy that obtains TLS certificates
by itself and an encrypted nightly backup to a second location.

---

## Costs

| Item | Provider | ~Cost / month |
|---|---|---|
| Server: 2 vCPU, 4 GB RAM, 40 GB NVMe (Hetzner CX22, Nürnberg or Falkenstein) | Hetzner Cloud | €4.35 net |
| IPv4 address | Hetzner | ~€0.60 |
| Domain (e.g. `.de`) | any registrar | ~€1 (≈ €10–15/year) |
| Off-site encrypted backups (a few GB) | Backblaze B2 or Hetzner Storage Box | €0.50 – €3.50 |
| Uptime monitoring | healthchecks.io free tier | €0 |
| **Total** | | **≈ €7 – 9 / month** |

Comfortably inside the €10 target (NFR-7). Prices are gross-of-VAT-dependent and
Hetzner adjusted its cloud pricing during 2026, so verify at purchase.

A CX22 is generously specified for four users. Do not start smaller: 2 GB of RAM makes
Node builds and Postgres coexist badly, and the €2 saved is not worth the afternoon.

---

## Step by step

### 1. Domain

Buy a domain, or use a subdomain of one you own. You need two names:

```
home.example.de       → the app
mcp.home.example.de   → the MCP server
```

Point both at the server's IPv4 (`A`) and IPv6 (`AAAA`) addresses once you have them.
Set the TTL low (300 s) while you are setting things up.

### 2. Create the server

In the Hetzner Cloud console: new project → new server → location **Nürnberg** or
**Falkenstein** → image **Ubuntu 24.04 LTS** → type **CX22** → **add your SSH public
key** → create.

Generate a key first if you have none:

```bash
ssh-keygen -t ed25519 -C "goombawall"
```

Never enable password authentication. An SSH port on the public internet sees login
attempts within minutes of existing; keys make that traffic irrelevant rather than
merely unlikely.

### 3. Harden the base system

Log in as root once, then:

```bash
# create a non-root user with sudo
adduser --disabled-password --gecos "" goombawall
usermod -aG sudo goombawall
mkdir -p /home/goombawall/.ssh
cp /root/.ssh/authorized_keys /home/goombawall/.ssh/
chown -R goombawall:goombawall /home/goombawall/.ssh
chmod 700 /home/goombawall/.ssh && chmod 600 /home/goombawall/.ssh/authorized_keys

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

Open a **second** terminal and confirm you can log in as `goombawall` before closing the
first. Locking yourself out of a fresh server is a rite of passage worth skipping.

### 4. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker goombawall
# log out and back in for the group to take effect
```

### 5. Compose file

`/opt/goombawall/docker-compose.yml`:

```yaml
services:
  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    ports: ["80:80", "443:443", "443:443/udp"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on: [web, mcp]

  web:
    image: ghcr.io/<you>/goombawall-web:${TAG:-latest}
    restart: unless-stopped
    env_file: .env
    depends_on:
      db: { condition: service_healthy }
    expose: ["3000"]

  mcp:
    image: ghcr.io/<you>/goombawall-mcp:${TAG:-latest}
    restart: unless-stopped
    env_file: .env
    depends_on:
      db: { condition: service_healthy }
    expose: ["3001"]

  worker:
    image: ghcr.io/<you>/goombawall-worker:${TAG:-latest}
    restart: unless-stopped
    env_file: .env
    depends_on:
      db: { condition: service_healthy }

  db:
    image: postgres:18-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: goombawall
      POSTGRES_USER: goombawall
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U goombawall"]
      interval: 10s
      timeout: 5s
      retries: 5
    # deliberately no ports: — Postgres is reachable only on the Docker network

volumes:
  pgdata:
  caddy_data:
  caddy_config:
```

The absent `ports:` on `db` is the single most important line in this file, precisely
because it is not there. An exposed Postgres port is the most common way a hobby
deployment is compromised.

### 6. Caddyfile

`/opt/goombawall/Caddyfile`:

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
    reverse_proxy web:3000
}

mcp.home.example.de {
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        -Server
    }
    reverse_proxy mcp:3001
}
```

Caddy obtains and renews Let's Encrypt certificates automatically, with no cron job and
no certbot. That is the whole reason it is here rather than nginx.

A Content-Security-Policy header belongs here too, but write it once the app exists so
you can make it strict rather than aspirational. Aim for `default-src 'self'` with no
`unsafe-inline`, which self-hosted fonts and assets make achievable (NFR-9).

### 7. Secrets

`/opt/goombawall/.env`, `chmod 600`, owned by `goombawall`, **never in git**:

```
POSTGRES_PASSWORD=<openssl rand -base64 32>
DATABASE_URL=postgres://goombawall:<same>@db:5432/goombawall
AUTH_SECRET=<openssl rand -base64 32>
VAPID_PUBLIC_KEY=…
VAPID_PRIVATE_KEY=…
PUBLIC_BASE_URL=https://home.example.de
```

Generate VAPID keys once with `npx web-push generate-vapid-keys`. Losing the private key
invalidates every push subscription, so it goes in your password manager as well as on
the server.

### 8. First launch

```bash
cd /opt/goombawall
docker compose pull
docker compose up -d
docker compose logs -f web
```

Then open `https://home.example.de` and run the setup wizard from
[08](08-users-auth-permissions.md).

---

## Building and shipping code

Build images in **GitHub Actions**, not on the server. A CX22 can build a Node
application, but slowly, and a build that exhausts memory while the family is using the
app is an avoidable indignity.

```
push to main
  → GitHub Actions: install, typecheck, test, build 3 images
  → push to ghcr.io
  → SSH to the server: docker compose pull && docker compose up -d
```

Use a deploy key restricted to that one action. Tag images with the commit SHA and point
`TAG` at it, so rolling back is `TAG=<previous-sha> docker compose up -d` rather than an
archaeology exercise.

Database migrations run from an init container or as a one-shot `docker compose run`
before the new `web` starts. Drizzle emits plain SQL migrations; read them before
applying. Always take a backup immediately before a migration — see below.

---

## Backups

The one operational thing that genuinely matters. Everything else can be rebuilt from
git; the database cannot.

**Nightly**, via a cron entry on the host:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd /opt/goombawall
STAMP=$(date +%F)
docker compose exec -T db pg_dump -U goombawall --format=custom goombawall \
  > /var/backups/goombawall/db-$STAMP.dump
restic -r "$RESTIC_REPOSITORY" backup /var/backups/goombawall /opt/goombawall/.env
restic forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --prune
curl -fsS -m 10 "https://hc-ping.com/<uuid>"     # dead-man's switch
find /var/backups/goombawall -name '*.dump' -mtime +3 -delete
```

- **restic** encrypts client-side, so the backup target never sees plaintext family data.
  Target: Backblaze B2, or a Hetzner Storage Box if you prefer to keep everything in
  Germany.
- The **healthchecks.io ping** is what turns this from a backup script into a backup
  system. A backup that silently stopped six weeks ago is the normal failure mode, and
  the only defence is being told when a run does not happen.
- Retention: 7 daily, 5 weekly, 12 monthly. A few hundred MB at most.

**Restore drill — do this once, in the first month, and note the date here.** An
untested backup is a hypothesis.

```bash
restic restore latest --target /tmp/restore
docker compose exec -T db psql -U goombawall -c 'DROP DATABASE IF EXISTS goombawall_test;'
docker compose exec -T db createdb -U goombawall goombawall_test
docker compose exec -T db pg_restore -U goombawall -d goombawall_test < /tmp/restore/.../db-*.dump
```

RPO 24 h, RTO ~4 h (NFR-11). For a family calendar, losing at most one day is acceptable;
losing everything is not.

---

## Updates

| What | How | Cadence |
|---|---|---|
| Ubuntu security patches | `unattended-upgrades` | Automatic |
| Kernel reboots | `needrestart`, or reboot after patch Tuesday | Monthly |
| Container base images | `docker compose pull && up -d` | Monthly |
| npm dependencies | Renovate or Dependabot PRs, reviewed | Weekly PRs, merged monthly |
| Postgres major version | Deliberate, with a dump/restore and a tested rollback | Yearly at most |

Do **not** run Watchtower for unattended container updates on this stack. Automatic
updates to a database container is how you find out that a major version bump needed a
migration, at 03:00, with no one awake.

---

## Monitoring

Keep it proportionate — this is a family app, not a service with an SLA.

- **healthchecks.io** free tier: nightly backup ping, plus a ping from the worker so you
  learn if scheduled jobs have stopped.
- **Uptime monitoring** on `https://home.example.de/health`, alerting to email.
- **Logs**: Docker's json-file driver with rotation (`max-size: 10m`, `max-file: 3`).
  `docker compose logs` is a sufficient investigation tool at this scale.
- **Disk**: a weekly cron that emails if the volume exceeds 80%. Postgres plus images
  will not fill 40 GB for years, but an unrotated log file will.

---

## The simpler alternative, honestly assessed

**Coolify** is a self-hosted PaaS you install on the same VPS: a web UI that handles
Docker deployments, TLS, environment variables, databases and scheduled backups, with
git-push deploys.

**For:** it removes most of steps 5–8 and gives you a dashboard, which genuinely helps if
Docker Compose feels opaque. **Against:** it is a substantial extra system running as
root on your server, it becomes the thing you have to keep patched and understand when it
misbehaves, and you learn less about what is actually happening.

The recommendation is to start with plain Compose. It is roughly one extra evening of
work, the resulting stack is about 60 lines of YAML you fully understand, and when
something breaks at an inconvenient moment you will be debugging your own configuration
rather than someone else's abstraction over it. If after a month the operational side is
consistently the part that stalls progress, Coolify is a reasonable retreat, and nothing
in the architecture prevents it.
