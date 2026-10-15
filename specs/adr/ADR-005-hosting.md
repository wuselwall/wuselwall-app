# ADR-005 — Self-hosted on a German VPS with Docker Compose and Caddy

**Status:** Superseded by [ADR-013](ADR-013-self-hosted-compose-stack.md) on 2026-10-11 — one self-hosted stack, no VPS. Previously: Accepted · 2026-08-29 · Amended by [ADR-010](ADR-010-flutter-and-self-hosted-supabase.md) on 2026-10-11 — the VPS, Compose and Caddy stand; the containers are now the self-hosted Supabase stack on a larger server, and the rejection of Supabase below applied to its hosted service

## Context

Requirement B3: small running costs acceptable, no commercialisation, good security, and
data not unnecessarily exposed to third-party services. The user has no deployment
experience and asked for guidance rather than options. The app must be reachable from a
work laptop and from phones outside the home.

## Decision

A single small VPS in a German data centre (Hetzner Cloud CX22, Nürnberg or Falkenstein),
running Docker Compose with four containers — Caddy, the SvelteKit app, the MCP server, a
worker — plus PostgreSQL, with nightly `restic`-encrypted off-site backups. Caddy handles
TLS automatically. Images are built in GitHub Actions and pulled on deploy.

## Alternatives considered

**Managed PaaS (Fly.io, Railway, Render).** Least operational work: git push, TLS and a
managed database included. Rejected because it costs meaningfully more at this size, the
data sits with a US-headquartered provider even when the region is European, and the
whole point of B3 is to reduce the number of parties with access. It also teaches you
nothing transferable.

**Home server (Raspberry Pi or NAS).** Maximum data ownership, no monthly fee. Rejected
because external reachability requires Tailscale or a Cloudflare tunnel (which either
adds a third party or complicates the Outlook ICS subscription from a corporate network),
domestic upstream bandwidth is poor, and power cuts, ISP address changes and hardware
failure all become your problem. For a system the family is meant to depend on daily, a
data centre is the more reliable choice at €5 a month.

**Supabase or Firebase backend.** Fastest route to working multi-device auth and realtime.
Rejected outright: it puts a complete record of a family's daily life, including two
children's, with a US cloud provider, which contradicts the explicit requirement.

**Coolify on the same VPS.** A self-hosted PaaS layer giving a deployment UI. Not
rejected, but not the starting point — see [10](../10-deployment-and-ops.md) for the
reasoning. Plain Compose is roughly one extra evening and leaves you understanding your
own stack.

## Consequences

**Positive**

- ~€7–9/month all in, inside the €10 target.
- All data in Germany, under one provider you have a contract with.
- Docker Compose is about 60 lines of YAML that you fully understand — and portable to
  any other VPS if Hetzner ever disappoints.
- Caddy makes TLS a non-event: no certbot, no renewal cron, no expired-certificate
  incident on a Sunday.
- Postgres is not exposed to the internet at all.

**Negative**

- You are the operations team: patching, backups, restores and 03:00 incidents.
  [10](../10-deployment-and-ops.md) exists to make that a checklist rather than a
  research project.
- Single node, no redundancy. A failed hypervisor means downtime until you restore. For a
  family calendar this is acceptable; it should be a conscious acceptance.
- Backups are the whole safety net, which is why the restore drill is a launch-blocking
  checklist item and not a good intention.

**Revisit if** operations consistently becomes the thing that stalls development. Coolify
on the same box is the retreat, and nothing in the architecture prevents it.
