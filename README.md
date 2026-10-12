# WuselWall — Family Organiser

A self-hosted family organiser: shared calendar, the children's school timetables, chores
with gamification, meal planning and a shopping list, used by every member of a household
on phones, tablets, a laptop and a wall-mounted kitchen display — whose standard screen is
a seven-day week board. Designed against a reference household of two adults and two
children (7 and 9); everything that differs between households is a setting with a
curated default ([21](specs/21-household-settings.md)).

Built as **native Flutter apps** for iOS, iPadOS and Android (plus a web build for the
laptop) on a **self-hosted Supabase** backend.

This repository holds **both the planning documents and the code**. `specs/` is the
specification; `app/`, `supabase/` and `infra/` hold the implementation.

## Status

| | |
|---|---|
| Phase | M0.0–M0.3 built; M1.1 shopping built, offline included. Next: M1.2 tasks, starting with household settings. M0.4 waits for the Apple and Google accounts ([13 — Roadmap](specs/13-roadmap.md)) |
| Started | 2026-10-11 |
| Decision set | Locked for v1 (see `specs/adr/`) |
| Origin | Specification carried over from BretApp; code starts from scratch |
| Latest change | 2026-10-11 — household settings with curated defaults ([21](specs/21-household-settings.md)); the one environment on the official compose stack ([ADR-013](specs/adr/ADR-013-one-self-hosted-environment.md#amendment-2026-10-11-the-official-compose-stack)) |

## Planned layout

```
app/               Flutter — iOS, Android and web; three UI registers, German l10n
supabase/          migrations (tables in `app`, views and functions in `api`, RLS),
                   Edge Functions, pgTAP tests, seed
infra/             the nginx site file and the backup scripts for the home server
scripts/           remote-stack, -migrate, -pgtap, -backup, -setup-token (the home server)
.github/workflows/ ci.yml, release-mobile.yml
specs/             the specification — read 01, 02 and 03 before writing code
```

Clients reach only the `api` schema; every write is one `api` function and one
transaction; the Flutter app holds no business rules. See
[03 — Architecture](specs/03-architecture.md#repository-layout).

## How to read these documents

Start with **01** and **02** to understand what is being built and why. Read **03**
before writing any code. The module documents (**05**–**07** and **15**) are the
specifications you hand to a coding session, one at a time.

| # | Document | What it answers |
|---|---|---|
| 00 | [Brief & Decisions](specs/00-brief-and-decisions.md) | The original request verbatim, every decision you made, and the three places this plan pushes back |
| 01 | [Vision & Scope](specs/01-vision-and-scope.md) | Why this exists, who uses it, what success looks like, what is explicitly out |
| 02 | [Requirements](specs/02-requirements.md) | Numbered functional and non-functional requirements, traceable to the original brief |
| 03 | [Architecture](specs/03-architecture.md) | System shape, technology stack, module boundaries, cross-cutting concerns |
| 04 | [Data Model](specs/04-data-model.md) | Entities, relationships, key invariants |
| 05 | [Calendar](specs/05-module-calendar.md) | A1 — events, recurrence, the outbound ICS feed, Outlook reality check |
| 06 | [Tasks & Gamification](specs/06-module-tasks.md) | A2 — chores, recurrence, points, rewards, streaks, badges |
| 07 | [Meals & Shopping](specs/07-module-meals-shopping.md) | A3 + A4 — meal plan, shopping list, the link between them, offline behaviour |
| 15 | [School Timetable & Presence](specs/15-module-school-timetable.md) | A5 — the Stundenplan as a pattern, presence for shift work and travel, the German glossary. *Read straight after 05.* |
| 08 | [Users, Auth & Permissions](specs/08-users-auth-permissions.md) | B1 — household model, device sessions, profile switching, guardian PIN |
| 09 | [Clients & UX](specs/09-clients-and-ux.md) | B2 — one Flutter app, three UI registers, **the kitchen week board**, platform constraints |
| 10 | [Deployment & Operations](specs/10-deployment-and-ops.md) | B3 — the one environment on the home server: Cloudflare, nginx, keys, backups, updates, costs |
| 11 | [Security & Privacy](specs/11-security-and-privacy.md) | Threat model and the controls that answer each threat |
| 12 | [MCP & Assistants](specs/12-mcp-and-assistants.md) | B4 — MCP server design, Siri via Shortcuts today |
| 13 | [Roadmap](specs/13-roadmap.md) | Milestones, per-module v1 scope cuts, rough effort |
| 14 | [Open Questions](specs/14-open-questions.md) | Decisions deliberately deferred, with the deadline for each |
| 16 | [Setup Plan](specs/16-setup-plan.md) | **The build order for M0**: tools and accounts, repository, local Supabase, app shell, identity, CI, mobile releases, deployment — with the workflows and the secrets inventory |
| 19 | [Security & Architecture Review](specs/19-security-and-architecture-review.md) | Findings of the 2026-10-11 review, what is fixed and what the operator still has to do |
| 17 | [Design System](specs/17-design-system.md) | Colour, type and form: the member palette (colour-blind-checked), presence treatments, night theme, three design directions, A "Küchentisch" chosen |
| 21 | [Household Settings](specs/21-household-settings.md) | The reference household, the settings model, the setup wizard and every curated default with its reasoning |
| 18 | [Testing Strategy](specs/18-testing-strategy.md) | The nine test layers from pgTAP to the family's devices: widget and golden matrices, Patrol on device, Playwright for the web build only, the manual release check, and where each runs |
| — | [Market Research](specs/market-research.md) | Family planners with meal planning in the German-speaking market: feature matrix, pros and cons, open-source and self-hosted options, implications for ADR-002 |
| — | [Design system mockup](specs/mockups/design-system.html) | The three directions on the same Monday, switchable between light, dark and night, with simulated colour-blindness |
| — | [Logo proposal](specs/mockups/logo.html) | Logo concepts (Familien-W, Wuselchen, Wuselpunkte) next to the ADR-012 icon, as app icons at real sizes, in dark and themed variants |
| — | [Kiosk mockup](specs/mockups/kiosk-week-board.html) | The kitchen display's week board, interactive and in German — the asset for agreeing the layout with the family before it is built |
| — | [Shopping capture mockup](specs/mockups/shopping-quick-add.html) | The three-second capture path: a tile picker over the learned catalogue, with the offline queue made visible |
| — | [Decision Records](specs/adr/README.md) | Eleven ADRs recording the choices made and the alternatives rejected |

## The decisions that shape everything else

1. **Own database, ICS feed outward.** Events live in WuselWall's own Postgres. Outlook
   and iPhone subscribe to a signed, read-only ICS URL. → [ADR-001](specs/adr/ADR-001-calendar-backbone.md)
2. **One self-built application**, not a set of stitched-together open-source services.
   → [ADR-002](specs/adr/ADR-002-build-vs-assemble.md)
3. **Flutter apps on a self-hosted Supabase**, with PostgreSQL as the domain core — an
   `api` schema of views and functions over RLS-protected tables. Supersedes the original
   TypeScript stack. → [ADR-010](specs/adr/ADR-010-flutter-and-self-hosted-supabase.md)
4. **Device sessions with tap-to-switch profiles**, guardian PIN for anything that
   moves points or deletes other people's data. → [ADR-004](specs/adr/ADR-004-identity-model.md)
5. **One self-hosted environment on the home server**, public at `wusel.example.org` through
   Cloudflare and nginx; further tenants, if any, on hosted Supabase. Supersedes the VPS
   plan. → [ADR-013](specs/adr/ADR-013-one-self-hosted-environment.md)
6. **Server-authoritative data**, with a narrow offline queue for the shopping list only —
   no general-purpose sync engine. → [ADR-006](specs/adr/ADR-006-offline-strategy.md)
7. **A remote MCP server** over Streamable HTTP with OAuth; Apple Shortcuts is the
   near-term Siri path. → [ADR-007](specs/adr/ADR-007-assistant-integration.md)
8. **The Stundenplan is a pattern, not sixty recurring events** — stored as a grid per
   term, projected into the calendar at read time, minus Ferien, plus per-date
   exceptions. → [ADR-008](specs/adr/ADR-008-school-timetable-model.md)
9. **Presence is an event kind**, so "Sabine arbeitet" and "Lukas ist in Berlin" reuse
   recurrence, overrides and the feed; what reaches the kitchen display is an explicit
   flag, never a heuristic. → [ADR-009](specs/adr/ADR-009-event-kinds-and-presence.md)
10. **Internal distribution only** — TestFlight and the Play internal track, fed by
    GitHub Actions and fastlane; no public store listing. → [ADR-011](specs/adr/ADR-011-native-distribution-and-ci-cd.md)
