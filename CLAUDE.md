# CLAUDE.md

This repository holds both the planning documents and the code for GoombaWall (see
[README.md](README.md)). `docs/` is the specification; `apps/`, `packages/` and `infra/`
will hold the implementation (not yet started — begin at M0.0 in
[docs/13-roadmap.md](docs/13-roadmap.md)).

## Architecture rules

- `apps/*` may not contain business logic and may not import Drizzle directly. They
  translate transport into calls on `packages/core` services. See
  [docs/03-architecture.md](docs/03-architecture.md#repository-layout).
- Every service function takes an explicit `ActorContext` as its first parameter.
- Every domain query is household-scoped through the `scoped()` helper, never by hand.
- Domain errors are `Result<T, DomainError>` values, not thrown strings.
- Every read and write goes through `withHousehold()`, which stamps the household onto
  the transaction so Postgres' row-level security policies can see it. A query outside
  it carries no household and the policies wave it through.

## Localization

All user-facing text in the built application must be in German. This is not optional
and not deferred to a later milestone — it applies as soon as any UI work starts.

- German is the only shipped locale (NFR-14, see [docs/02-requirements.md](docs/02-requirements.md)).
- Code, comments and documentation stay in English — only user-facing strings are German.
- Build the i18n layer in from the first component (`svelte-i18n` or equivalent, per
  [docs/09-clients-and-ux.md](docs/09-clients-and-ux.md#language)) rather than hardcoding
  German strings inline. No user-facing string should land in a component untranslated,
  even as a placeholder — retrofitting i18n later is tedious; adding a second locale to a
  prepared setup is trivial.
- This covers UI copy, error messages, notifications, emails, and the MCP assistant
  responses (see [docs/12-mcp-and-assistants.md](docs/12-mcp-and-assistants.md)) — anything
  a household member reads or hears from the app.
