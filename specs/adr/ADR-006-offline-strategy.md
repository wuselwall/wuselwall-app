# ADR-006 — Server-authoritative data, with an offline queue for the shopping list only

**Status:** Accepted · 2026-08-29 · Mechanism amended by [ADR-010](ADR-010-flutter-and-self-hosted-supabase.md) on 2026-10-11 — the decision stands; IndexedDB and the service worker become drift (SQLite) in the Flutter app, SSE becomes Supabase Realtime

## Context

The shopping list must work in a supermarket, where connectivity is unreliable — and a
shopping list that fails in a shop is worthless. Meanwhile 2026 offers several mature-ish
sync engines (Zero, ElectricSQL, PowerSync, TanStack DB, LiveStore) that make an entire
application local-first. The temptation is to adopt one and get offline everywhere.

## Decision

The server is authoritative for all data. Clients read through a stale-while-revalidate
cache and receive live updates over SSE.

**One exception:** the shopping list is fully offline-capable via an IndexedDB mirror and
an outbox queue with client-generated UUIDs as idempotency keys, reconciled on reconnect
with field-level last-write-wins.

No general-purpose sync engine.

## Alternatives considered

**Adopt a sync engine for the whole app.** Offline everywhere, optimistic updates for
free, real-time collaboration built in. Rejected for three reasons. First, the category
is still churning: ElectricSQL's approach draws sharp criticism from practitioners,
Triplit lost its commercial backing in 2025, LiveStore's model suits single-user data
better than shared household data, and Zero — the current favourite — is young. Adopting
any of them is a bet on someone else's roadmap for a system meant to run unattended for
years. Second, they are architecturally invasive: the data model, the authorisation model
and the deployment all bend around them, and backing one out later is close to a rewrite.
Third, the requirement does not exist. Nobody plans meals in a tunnel or approves reward
redemptions on a train. The calendar, tasks and meal plan need to be *fast*, which a cache
and optimistic UI deliver, not *offline*.

**CRDTs (Yjs or Automerge) for the shopping list.** Principled conflict resolution.
Rejected as disproportionate: the actual conflicts are two people adding the same item
(merge by name) and two people ticking the same item (idempotent). A field-level
last-write-wins with tombstones handles the real cases in a fraction of the code and with
none of the debugging difficulty.

**No offline support at all.** Rejected. A1–A4 aside, the shopping list is the module
that will be used most, in the one place where the network is worst.

## Consequences

**Positive**

- Almost the whole application is a conventional server-authoritative web app — easy to
  reason about, easy to debug, easy to return to after two months away.
- One small, well-understood piece of offline machinery, in the one place it earns its
  keep, with clearly enumerated conflict cases.
- No dependency on a young sync framework's continued existence.
- Idempotency keys make retries safe, which matters far beyond offline use.

**Negative**

- No offline access to the calendar or tasks. If this bites — a family member repeatedly
  wanting the agenda with no signal — the answer is to extend the read cache, not to
  adopt a sync engine.
- The outbox is bespoke code that must be tested properly: retries, ordering, partial
  failures, and the reconciliation path. Budget for that in M1.1.
- **iOS has no Background Sync**, so the outbox drains only when the app is next opened
  with a connection. The UI must show pending state honestly rather than implying that
  everything is saved.

**As built (2026-10-12).** drift on the phones and tablets, with a codeless schema of two
tables (the server snapshot as JSON, and the outbox); memory in the web build, where the
laptop is online and a reload refetches. "Field-level last-write-wins" became the server's
arrival order per op, not device clocks: ops are absolute where they can be (`check`,
`spec`, `category`), counted once by their `op_id` where they cannot (`count`, `add`), and a
removed item is a tombstone for every later op. Details in
[07](../07-module-meals-shopping.md#offline--the-one-place-it-is-non-negotiable).

**Revisit if** a second genuinely offline-first module appears. One is a feature; three
would be an argument for an engine.
