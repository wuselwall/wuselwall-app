# ADR-013 — Self-hosted Supabase on the official compose stack; no separate dev and prod

**Status:** Accepted · 2026-10-11 · Supersedes [ADR-005](ADR-005-hosting.md); amends
[ADR-010](ADR-010-flutter-and-self-hosted-supabase.md) and
[ADR-011](ADR-011-native-distribution-and-ci-cd.md) · Amended by
[ADR-014](ADR-014-self-service-onboarding.md) on 2026-10-11 (self-service households) ·
**Amended 2026-10-11:** the official self-hosting compose file instead of the CLI's stack —
see [Amendment](#amendment-2026-10-11-the-official-compose-stack) · Partly superseded by
[ADR-015](ADR-015-saas-and-self-hosted-flavours.md), which ADR-018 in turn replaced ·
**Amended 2026-10-13 by [ADR-018](ADR-018-self-hosted-only.md):** every household runs its
own server; this ADR describes what such a server is.

*Rewritten 2026-10-14 to describe servers in general; nothing here describes a particular
operator's machine.*

## Context

The plan so far had two landscapes: a development stack (the Supabase CLI's) and a
production stack on a rented VPS in Germany (ADR-005), deployed at M1.6 with its own
domain, Caddy, `deploy.yml` and `env/prod.json`.

On 2026-10-11 the user decided:

> For now we only build one tenant, not two (dev and prod) landscapes. […] Any further
> tenants might be run on the Supabase SaaS service itself.

## Decision

- **One landscape per server.** A WuselWall server is one self-hosted Supabase stack. There
  is no separate production stack, no VPS plan, no `deploy.yml` and no `env/prod.json`;
  the pilot household and development share the pilot's server.
- **Public entry:** a front with TLS that forwards the four API prefixes only, and a 404
  for everything else (today the release's Caddy layer).
- **Own secrets**, never the CLI's public defaults: whoever holds those holds the service
  role.
- **Disposable databases are not environments.** CI starts a throwaway stack for pgTAP and
  the Dart integration test. pgTAP may also run against a live server, because every test
  runs inside a transaction that is rolled back. The **integration test never runs against
  a live server**: it creates a household, devices and items, and revokes devices.
- **Backups protect the household's data**: a nightly dump on the server
  ([`infra/backup/`](../../infra/backup/)), and a dump before every migration.
- **Further tenants run on hosted Supabase (supabase.com)** if and when they exist.
  *Superseded by [ADR-014](ADR-014-self-service-onboarding.md) and then
  [ADR-018](ADR-018-self-hosted-only.md): every household runs its own server, which may be
  its own hosted Supabase project.*

### Keeping the code portable to hosted Supabase

Everything in `supabase/` must apply cleanly to a hosted project:

| Area | Status |
|---|---|
| `app`/`api` schemas, RLS, `security_invoker` views, `api` functions | Portable |
| Access-token hook (`pg-functions://postgres/app/custom_access_token_hook`) | Portable — hosted projects support Postgres hooks |
| Realtime private channels and the `realtime.messages` policy | Portable |
| `app.create_auth_user` writing `auth.users`/`auth.identities` directly | **To verify on a hosted project.** If refused, enrolment moves to an Edge Function using the Admin API, which the architecture rules already allow (service role, no user, a comment at each use) |
| `grant select on auth.mfa_factors to supabase_auth_admin` | Tolerated when refused (2026-10-14): Auth owns the table anyway |
| `pg_cron` and `pg_net` jobs (`infra/jobs/schedule.sql`) | Portable — available on hosted projects |
| Functions without a user (`ics`, `tasks-nightly`, `holidays-sync`, `server-info`) | `verify_jwt = false` per function in `config.toml`; the compose stack's router has the same list |
| Passkeys (Auth beta) | Depends on the hosted rollout at the time |

## Alternatives considered

**Keep the two-landscape plan (dev, plus production on a VPS).** It separates experiments
from live data, and it is what ADR-005 and ADR-011 described. Rejected for now: twice the
operations for one household, a second set of secrets and backups, and a deployment
pipeline before there is anything to deploy.

**A dedicated production stack next to the development stack.** A clean separation without
a rented server. Rejected for the same reason: two stacks to keep in step for one
household. It remains the first step back if one landscape starts to hurt.

**Hosted Supabase for the pilot too.** No operations at all. Rejected at the time for NFR-8
and cost; since ADR-018 it is one of the two ways any household can run its server.

## Consequences

**Positive**

- A server at home costs nothing beyond electricity and a domain.
- No `deploy.yml`, no second set of secrets, no second backup. A migration is applied once.
- Push, the ICS feed in Outlook and use outside the house are possible as soon as the apps
  exist, because the public URL exists from the start.

**Negative**

- **Development happens next to live data** on the pilot's server. Mitigations: a dump
  before every migration, `db reset` reserved for disposable stacks, migrations rehearsed
  in CI first, and the integration test kept off live servers.
- **Availability is the home's**: power cuts, ISP outages and hardware faults are downtime.
  Acceptable for a family organiser; the offline outbox covers the shop.
- **A proxy in front sees the traffic in clear**, if the operator uses one to hide the
  home address (Cloudflare and the like). The guide names the trade-off.

**Revisit if** a migration ever damages a household's data. The first step back is a
separate stack for development on the same machine.

## Amendment 2026-10-11: the official compose stack

**Decision (the user, answering S10 and A8 in [19](../19-security-and-architecture-review.md),
and the first condition of [Q40](../14-open-questions.md)):** servers move from the Supabase
CLI's stack to Supabase's **official self-hosting compose file**; experiments run on
throwaway stacks (CI, the laptop).

**Why.** The CLI stack publishes Postgres (password `postgres`), Studio (no login) and
Mailpit on every interface of its host, and `config.toml` cannot change that. The compose
file takes every secret from its own `.env` and leaves the ports to us. It also runs Edge
Functions from a directory on the server, which the CLI cannot do against a remote Docker
host (A11).

**As built**

| Area | CLI stack (before) | Compose stack |
|---|---|---|
| Definition | `supabase/config.toml`, `supabase start` over a remote `DOCKER_HOST` | [`infra/supabase/`](../../infra/supabase/): upstream `docker/` at commit `3fc8af38`, copied verbatim, plus `docker-compose.wuselwall.yml` (and since 2026-10-14 the lean and Caddy layers) |
| Images | Chosen by the pinned CLI | **The same tags**, pinned in our layer (Postgres 15.19, GoTrue 2.197, PostgREST 16.4, Realtime 2.140) — CI and every server agree |
| Gateway | Kong on `0.0.0.0:54321` | Envoy (upstream's default) on `172.17.0.1:54421`: reachable from a front on the host, not from the network |
| Postgres | `0.0.0.0:54322`, password `postgres` | `127.0.0.1:54422`, a 48-character password; no pooler |
| Studio, Mailpit | `0.0.0.0:54323` without login, `0.0.0.0:54324` | Studio behind the gateway with basic auth, by SSH tunnel only (off by default since 2026-10-14); no Mailpit |
| Secrets | `supabase/.env` → `config.toml` | The server's `.env` only (`make-env.mjs`): JWT secret and opaque keys kept when given, so installed apps keep working; an EC P-256 signing key, the HS256 secret still verified through the JWKS |
| Auth settings | `[auth]` in `config.toml` | The same values as GoTrue variables in our layer: sign-up off, TOTP, the access-token hook, refresh rotation, the CLI's rate limits; passkeys bound to the server's web host; minimum password length 10 (S14) |
| Migrations | `supabase migration up` through SSH tunnels | Each pending file in one transaction with its `schema_migrations` row, through `docker exec` (`scripts/remote-migrations.sh`, `server/wuselwall`) — no password leaves the server |

`supabase/config.toml` stays: it defines the throwaway stacks in CI and on the laptop. A
setting changed in one of the two definitions must be changed in the other.

**Revisit if** the compose file's upgrade path proves more painful than the CLI's.
