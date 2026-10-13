# ADR-013 — One self-hosted environment on the home server; further tenants on hosted Supabase

**Status:** Accepted · 2026-10-11 · Supersedes [ADR-005](ADR-005-hosting.md); amends
[ADR-010](ADR-010-flutter-and-self-hosted-supabase.md) and
[ADR-011](ADR-011-native-distribution-and-ci-cd.md) · Amended by
[ADR-014](ADR-014-self-service-onboarding.md) on 2026-10-11: self-service households share
**one** project instead of one project per tenant · **Amended 2026-10-11:** the one
environment runs Supabase's official self-hosting compose file instead of the CLI's stack —
see [Amendment](#amendment-2026-10-11-the-official-compose-stack) · Superseded in part by
[ADR-015](ADR-015-saas-and-self-hosted-flavours.md) on 2026-10-11: once *WuselWall Cloud*
(hosted Supabase) exists it holds every self-service household; this stack stays the
family's home and the self-hosted flavour for development and testing. Its safety rules stay

**Amended 2026-10-13 by [ADR-017](ADR-017-wuselwall-app-domain.md):** the public address is now `wuselwall.app` (website), `web.wuselwall.app` (web app) and `api.wuselwall.app` (API); `wusel.example.org` below is the address of the time, kept as a bridge for old app builds.

## Context

The plan so far had two landscapes: a development stack (the Supabase CLI's, on the
laptop or the home server) and a production stack on a rented VPS in Germany (ADR-005),
deployed at M1.6 with its own domain, Caddy, `deploy.yml` and `env/prod.json`.

On 2026-10-11 the user decided:

> For now we only build one tenant, not two (dev and prod) landscapes. We run the dev
> environment self-hosted on the private server. Any further tenants might be run on the
> Supabase SaaS service itself.

By then the home server (homeserver, 32 cores, 62 GB RAM, Docker) was already running the
Supabase stack, and `wusel.example.org` already reached it through Cloudflare's proxy and
the user's own nginx.

## Decision

- **One environment.** The Supabase stack on the home server is the only one. The family
  uses it, and development happens against it. There is no separate production stack, no
  VPS, no `deploy.yml` and no `env/prod.json`.
- **Public entry:** `https://wusel.example.org` → Cloudflare (proxied record, TLS at the
  edge) → the user's nginx on the home server (Cloudflare origin certificate) → Kong on
  port 54321. nginx forwards the four API prefixes only
  ([`infra/nginx/wusel.example.org.conf`](../../infra/nginx/wuselwall.app.conf)).
  Caddy is dropped.
- *(Superseded by the amendment below.)* **The stack stays the Supabase CLI's** (`supabase start`, driven remotely through
  `scripts/remote-supabase.sh`), with **its own secrets**: `auth.jwt_secret`,
  `auth.publishable_key` and `auth.secret_key` in `supabase/config.toml` read from the
  git-ignored `supabase/.env`. The CLI's defaults are public, and anyone who has them
  holds the service role.
- **Disposable databases are not environments.** CI starts a throwaway stack on the
  GitHub runner for pgTAP and the Dart integration test. pgTAP may also run against the
  home server, because every test runs inside a transaction that is rolled back. The
  **integration test never runs against the home server**: it creates a household,
  devices and items, and revokes devices.
- **Backups protect the family's data**: a nightly dump on the server
  ([`infra/backup/`](../../infra/backup/)), and a manual dump before every migration.
- **Further tenants run on hosted Supabase (supabase.com)**, one project per tenant, if
  and when they exist. *Superseded by [ADR-014](ADR-014-self-service-onboarding.md): with
  self-service sign-up all households share one project, isolated by RLS.* This reverses ADR-010's rejection of the hosted service *for other
  households*. Each household's data stays wherever that household chooses. This family's
  data stays on the home server.

### Keeping the code portable to hosted Supabase

Everything in `supabase/` must apply cleanly to a hosted project. What holds today, and
what has to be checked before a second tenant:

| Area | Status |
|---|---|
| `app`/`api` schemas, RLS, `security_invoker` views, `api` functions | Portable |
| Access-token hook (`pg-functions://postgres/app/custom_access_token_hook`) | Portable — hosted projects support Postgres hooks |
| Realtime private channels and the `realtime.messages` policy | Portable |
| `app.create_auth_user` writing `auth.users`/`auth.identities` directly | **To verify.** Hosted projects restrict the `auth` schema; enrolment may have to move to an Edge Function using the Admin API, which the architecture rules already allow (service role, no user, a comment at each use) |
| `pg_cron` jobs (M1.2 materialiser) | Portable — available on hosted projects |
| Passkeys (Auth beta) | Depends on the hosted rollout at the time |

## Alternatives considered

**Keep the two-landscape plan (dev at home, production on a Hetzner VPS).** It separates
experiments from the family's data, and it is what ADR-005 and ADR-011 described.
Rejected by the user for now: twice the operations for one household, a second set of
secrets and backups, and a deployment pipeline before there is anything to deploy.

**A dedicated production stack on the home server, next to the dev stack.** It keeps a
clean separation, needs no rented server, and was ready to build from the official
self-hosting compose file. Rejected for the same reason: two stacks to keep in step for
one household. It remains the first step back if one environment starts to hurt (see
*Revisit if*).

**Hosted Supabase for this family too.** No operations at all. Rejected: the reason
behind ADR-010 still applies to this household's data (NFR-8), and the home server
already exists.

## Consequences

**Positive**

- No rented server: hosting costs nothing beyond electricity and the domain the user
  already owns. With the Apple programme the total is ≈ €8/month (NFR-7, Q36).
- No `deploy.yml`, no second set of secrets, no second backup. A migration is applied
  once, where the family uses it.
- Push, the ICS feed in Outlook and use outside the house are possible as soon as the
  apps exist, because the public URL already exists. They no longer wait for M1.6.

**Negative**

- **Development happens next to the family's data.** A bad migration or a careless
  `supabase db reset` reaches the household directly. Mitigations: a dump before every
  migration (`scripts/remote-backup.sh`), `db reset` reserved for disposable stacks,
  migrations rehearsed in CI first, and the integration test kept off the home server.
- *(Resolved by the amendment below.)* **The CLI stack is a development tool.** It publishes Postgres (54322, password
  `postgres`), Studio (54323, no login) and Mailpit (54324) on the home network. Only
  Kong is forwarded to the internet, so they are reachable only inside the house. Keep it
  that way: never forward those ports, and keep Studio off any nginx host.
- **A CLI upgrade upgrades the stack.** `npx supabase` is pinned in `package.json`; a
  version bump is a deliberate change with a backup first, never a side effect.
- **Availability is the home's**: power cuts, ISP outages and hardware faults are
  downtime. Acceptable for a family organiser; the offline outbox covers the shop.
- **Cloudflare sees the traffic in clear** at its edge. That is a third party in the path
  that ADR-005 avoided. Accepted: the alternative was exposing the home IP directly.

**Revisit if** a migration ever damages the household's data, or a second household
appears. The first step back is a separate stack on the same server (the official
self-hosting compose file, own secrets), with this one returning to a development
sandbox.

## Amendment 2026-10-11: the official compose stack

**Decision (the user, answering S10 and A8 in [19](../19-security-and-architecture-review.md),
and the first condition of [Q40](../14-open-questions.md)):** the one environment moves
from the Supabase CLI's stack to Supabase's **official self-hosting compose file**. It
stays **one** environment: the compose stack replaces the CLI stack on the home server,
and experiments run on throwaway stacks (CI, the laptop).

**Why.** The CLI stack publishes Postgres (password `postgres`), Studio (no login) and
Mailpit on every interface of the home server, and `config.toml` cannot change that. The
compose file takes every secret from its own `.env` and leaves the ports to us. It also
runs Edge Functions from a directory on the server, which the CLI cannot do against a
remote Docker host (A11). And it is the stack Q40 needs before anyone else's household
could live on it, wherever that ends up running.

**As built**

| Area | CLI stack (before) | Compose stack |
|---|---|---|
| Definition | `supabase/config.toml`, `supabase start` over `DOCKER_HOST=ssh://homeserver` | [`infra/supabase/`](../../infra/supabase/): upstream `docker/` at commit `3fc8af38`, copied verbatim, plus `docker-compose.wuselwall.yml`; run from `/srv/appdata/wuselwall/supabase` by `scripts/remote-stack.sh` |
| Images | Chosen by the pinned CLI | **The same tags**, pinned in our layer (Postgres 15.19, GoTrue 2.197, PostgREST 16.4, Realtime 2.140) — CI and the home server agree |
| Gateway | Kong on `0.0.0.0:54321` | Envoy (upstream's default) on `172.17.0.1:54421`: reachable from the nginx container, not from the home network |
| Postgres | `0.0.0.0:54322`, password `postgres` | `127.0.0.1:54422`, a 48-character password; no pooler |
| Studio, Mailpit | `0.0.0.0:54323` without login, `0.0.0.0:54324` | Studio behind the gateway with basic auth, by SSH tunnel only; no Mailpit |
| Secrets | `supabase/.env` → `config.toml` | The server's `.env` only (`make-env.mjs`, `init-env`): JWT secret and opaque keys **kept**, so the installed apps work without a rebuild; new EC P-256 signing key, the old HS256 secret still verified through the JWKS |
| Auth settings | `[auth]` in `config.toml` | The same values as GoTrue variables in our layer: sign-up off, TOTP, the access-token hook, refresh rotation, the CLI's rate limits; passkeys bound to `wusel.example.org` instead of `localhost`; minimum password length 10 (S14) |
| Migrations | `supabase migration up` through SSH tunnels | `scripts/remote-migrations.sh`: each pending file in one transaction with its `schema_migrations` row, through `docker exec` — no password leaves the server |
| pgTAP, backups, setup token | `docker exec supabase_db_wuselwall` | The same scripts against `supabase-db` |

**Data.** Not carried over, by the user's choice: the CLI stack held only development data
(one test household, 30 devices from testing). The new database got the six migrations,
pgTAP passed (85 tests), and the family's household is set up fresh with a new setup token.
Devices enrolled on the CLI stack fall back to the enrolment screen.

`supabase/config.toml` stays: it defines the throwaway stacks in CI and on the laptop. A
setting changed in one of the two definitions must be changed in the other.

**Rollback**, while the CLI stack's Docker volumes still exist: point nginx back at
`192.0.2.4:54321` and run `DOCKER_HOST=ssh://homeserver npx supabase start`. The volumes are
removed once the compose stack has run for two weeks without needing it.

**Revisit if** the compose file's upgrade path proves more painful than the CLI's.
