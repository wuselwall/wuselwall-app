# ADR-002 — One self-built application rather than composed open-source services

**Status:** Accepted · 2026-08-29

## Context

Mature self-hostable open-source tools exist for every module: Vikunja or Tasks.md for
chores, Mealie or Tandoor for recipes and meal planning, Grocy for shopping and
inventory, Nextcloud or Radicale for calendars. Assembling them behind a shared dashboard
would reach a working system considerably faster than building from scratch.

## Decision

Build one application containing all four modules, sharing a single data model and a
single user model.

## Alternatives considered

**Compose existing services with a custom dashboard.** Faster to a first working system
and each component is more capable than anything built here in a year. Rejected because
the requirements are precisely the ones composition handles badly: one identity across
all modules with children and guardians and a shared kiosk (B1); a points economy that
spans task completion, rewards and streaks; generating a shopping list from a meal plan
with provenance links back to the meal; and one MCP surface over everything (B4). Each of
those becomes a synchronisation problem between systems that were never designed to know
about each other. Operationally it is also five containers, five upgrade cycles, five
backup concerns and five auth configurations — a larger long-term burden than the one
being avoided.

**Hybrid: build the core, integrate an external recipe manager.** Tempting, because
recipe management is the least interesting part to build. Rejected because the
meal-plan-to-shopping-list link described in [07](../07-module-meals-shopping.md) is one
of the highest-value features, and it needs ingredients in the same database as the
shopping catalogue. Integrating across an API for that seam costs more than building the
thin recipe model actually required.

## Consequences

**Positive**

- One data model, one transaction boundary, one identity system, one UI language.
- Cross-module features — points from chores, shopping from meals, a unified assistant
  surface — are ordinary code rather than integration projects.
- Uniform quality: the children's register can be genuinely appropriate for a
  seven-year-old, which no assembled system would be.
- One thing to deploy, back up and upgrade.

**Negative**

- Substantially more work before anything is usable. Realistically 2–3 months of evenings
  to M1 (see [13](../13-roadmap.md)).
- Every feature the off-the-shelf tools have for free must be built or consciously
  skipped. The scope-cut lists in the module documents are what make this survivable.
- Sole maintainer. There is no upstream fixing bugs while you sleep.

**Accepted because** this is also a project you want to build, not merely one you want to
have — which changes the calculation on all three costs above.
