# ADR-007 — Remote MCP server over Streamable HTTP; Apple Shortcuts for Siri today

**Status:** Accepted · 2026-08-29 · Amended by [ADR-010](ADR-010-flutter-and-self-hosted-supabase.md) on 2026-10-11 — both endpoints become Edge Functions; the OAuth server question moves from Better Auth to Supabase Auth

## Context

Requirement B4 asks that Siri, or a future AI assistant, be able to interact with the
app. These are two different problems with two different timelines. Siri cannot be
extended by a PWA — App Intents require a native app — while MCP is the emerging standard
for AI assistants and is a natural fit for a self-hosted service.

## Decision

**Near term:** expose a small set of token-authenticated REST endpoints designed for
Apple Shortcuts. A shortcut using *Get Contents of URL*, triggered by a spoken phrase,
gives working Siri integration with no App Store involvement, no developer account and
about an hour of work.

**Ongoing:** build a remote MCP server at `mcp.home.example.de` targeting spec revision
`2026-07-28` — stateless, Streamable HTTP, OAuth 2.1 with PKCE — with separate read and
write scopes and no delete tools in v1.

## Alternatives considered

**A native iOS app for App Intents.** Proper Siri integration, Lock Screen widgets, Live
Activities. Rejected for v1: it means a second codebase, an Apple Developer account, a
build and distribution process, and a great deal of work for a capability that Shortcuts
approximates well enough. Revisit only if a specific interaction genuinely requires it.

**stdio MCP transport with a local bridge.** Simpler — no OAuth, no public endpoint.
Rejected because it only works on a machine that can reach the database or run a local
process, which excludes phones and any hosted assistant. A remote server is what makes
the capability actually available.

**A static API key for MCP instead of OAuth.** Much less work. Rejected as the end state
because scoping, consent and per-grant revocation are exactly what you want when granting
an AI assistant write access to your family's calendar. Acceptable as an interim for
read-only access if Better Auth's OIDC provider turns out not to cover the spec's
requirements ([Q15](../14-open-questions.md)).

## Consequences

**Positive**

- Something useful works within hours: "Hey Siri, Einkaufsliste" is the single highest-
  value assistant interaction in the whole system, and it needs no MCP at all.
- The MCP server rides on the same `packages/core` services, so business rules and
  authorisation are never duplicated or bypassed.
- Read-only MCP is safe to enable early, which means real experience with the surface
  before any write scope exists.
- Every assistant action is attributed in the audit log with both the assistant and the
  human principal.

**Negative**

- Shortcuts tokens are bearer credentials living in the Shortcuts app and syncing through
  iCloud. Scoped narrowly, individually revocable, and unable to delete anything — but a
  real exposure worth understanding.
- The MCP specification changed substantially in the 2026-07-28 revision, deprecating
  Roots, Sampling and Logging on a 12-month clock. Expect to track the spec; verify SDK
  coverage before starting the module rather than assuming it.
- OAuth as an authorisation server is the largest single piece of work in this area. It
  is deferred to M2/M3 precisely so it does not block anything else.

**Revisit** the native-app question if Apple makes App Intents reachable from web apps,
or if the household's use of Siri outgrows what a spoken-phrase shortcut can express.
