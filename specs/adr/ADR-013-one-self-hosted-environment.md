# ADR-013 — One self-hosted environment on the home server; further tenants on hosted Supabase

**Status:** Accepted · 2026-10-11 · Supersedes [ADR-005](ADR-005-hosting.md); amends
[ADR-010](ADR-010-flutter-and-self-hosted-supabase.md) and
[ADR-011](ADR-011-native-distribution-and-ci-cd.md)

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
  ([`infra/nginx/wusel.example.org.conf`](../../infra/nginx/wusel.example.org.conf)).
  Caddy is dropped.
- **The stack stays the Supabase CLI's** (`supabase start`, driven remotely through
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
  and when they exist. This reverses ADR-010's rejection of the hosted service *for other
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
- **The CLI stack is a development tool.** It publishes Postgres (54322, password
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
