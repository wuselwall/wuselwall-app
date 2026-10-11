# ADR-003 — TypeScript end to end: SvelteKit, Drizzle, PostgreSQL

**Status:** Superseded by [ADR-010](ADR-010-flutter-and-self-hosted-supabase.md) on 2026-10-11 · was Accepted 2026-08-29, framework choice confirmed 2026-08-30

## Context

One developer, working evenings, building a PWA that must run well on a cheap wall
tablet, a self-hosted server, background jobs and an MCP endpoint. TypeScript end to end
was chosen up front, which settles the language but not the framework.

## Decision

- **SvelteKit 2 / Svelte 5** for the UI and the HTTP layer, built with `adapter-node`
- **PostgreSQL 18** as the only datastore
- **Drizzle ORM** for typed, SQL-shaped queries and readable migrations
- **Better Auth** for guardian accounts, passkeys and sessions
- **pg-boss** for background jobs, backed by the same Postgres
- **Zod v4** for validation at every boundary
- **Tailwind CSS** for styling across the three UI registers
- **Vitest** and **Playwright** for tests

## Alternatives considered

**Next.js instead of SvelteKit.** The largest ecosystem, the best-covered framework in AI
code generation, and more example code for everything. Rejected as the default because
the App Router's surface area — server components, caching semantics, the client/server
boundary — is a lot of framework to hold in your head for a solo evening project, and
because bundle size matters on a low-end always-on wall display. This is a close call and
a defensible reversal: nothing in the architecture outside `apps/web` depends on it. Make
the call once, before M0, and record it.

**Prisma instead of Drizzle.** More mature tooling and a nicer studio. Rejected for the
opaque query generation and the heavier runtime; Drizzle's SQL-shaped API keeps you close
to what the database actually does, which matters for the recurrence and ledger queries.

**Auth.js, or rolling your own.** Auth.js is awkward outside Next.js and awkward to
extend with a device-session model. Rolling your own is how people end up with subtly
broken session handling. Better Auth is actively maintained, self-hosted-first and has
passkey and OIDC plugins; Lucia, the previous community default, was deprecated in 2025.

**SQLite instead of PostgreSQL.** Genuinely tempting at four users: one file, trivial
backups, no container. Rejected for `LISTEN/NOTIFY` (which powers SSE), `pg_trgm` (which
powers the three-second shopping capture), pg-boss, and range and array types used
throughout the model. Postgres in a container is not the burden it once was.

**Redis for queues and pub/sub.** Rejected as an unnecessary second datastore. Postgres
does both adequately at this scale, and every component removed is one fewer thing to
patch and back up.

**A sync engine (Zero, ElectricSQL, TanStack DB, LiveStore).** Rejected — see
[ADR-006](ADR-006-offline-strategy.md).

## Consequences

**Positive**

- One language and one type system from database schema to MCP tool definitions. A Zod
  schema defines the API contract, the form validation and the MCP tool's JSON Schema.
- Small client bundles, which the wall display will thank you for.
- A single `docker compose up` runs the whole stack: two application containers, a worker
  and Postgres.
- Migrations are plain SQL you can read before applying to your family's data.

**Negative**

- Fewer Svelte examples than React ones, and marginally weaker AI code-generation
  coverage — relevant given the plan to generate code later.
- Better Auth is younger than the alternatives; expect to write the device-session and
  PIN layer yourself on top of it (which was always true regardless of the library).
- pg-boss puts job load on the same Postgres instance. Irrelevant at four users, worth
  remembering if the workload ever changes character.
