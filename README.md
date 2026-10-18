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
| Phase | Built in code: M0.0–M0.3; the M0.4 pipeline (first TestFlight upload 2026-10-12; first Play internal release done, the Play upload from CI written); M1.0 onboarding, steps 1–9 (sign-in with email codes and passwords only); M1.1–M1.4; the M1.5 week board; the Q47 local reminders. Built is not deployed: no server's state is verified, and no pilot evidence is recorded. Next: M1.6 pilot validation with the [release checklist](specs/release-checklist.md); store and signing gates are separate. Status and history: [13 — Roadmap](specs/13-roadmap.md#current-status-2026-10-17-base-43ac2e5) |
| Started | 2026-10-11 |
| Decision set | Locked for v1 (see `specs/adr/`) |
| Origin | Specification carried over from BretApp; code starts from scratch |
| Latest change | 2026-10-14 — every family's own server: the store app chooses its server, a server release with an installer, hosted Supabase without tools ([ADR-018](specs/adr/ADR-018-self-hosted-only.md#amendment-2026-10-14-built), [the guide](docs/server/index.md)). Before: 2026-10-13 — the domain `wuselwall.app` for the website ([ADR-017](specs/adr/ADR-017-wuselwall-app-domain.md)). Before: 2026-10-11 — household settings with curated defaults ([21](specs/21-household-settings.md)); the official compose stack ([ADR-013](specs/adr/ADR-013-self-hosted-compose-stack.md#amendment-2026-10-11-the-official-compose-stack)) |

## Planned layout

```
app/               Flutter — iOS, Android and web; three UI registers, German l10n
supabase/          migrations (tables in `app`, views and functions in `api`, RLS),
                   Edge Functions, pgTAP tests, seed
docs/              VitePress family documentation (de/en), prepared for GitHub Pages
infra/             the compose stack and its layers, jobs, backups
server/            the operator's tool in a server release: install, update, backup, restore
scripts/           release builder; remote-* to drive a server over SSH from a checkout
.github/workflows/ ci.yml, release-ios.yml, release-android.yml
specs/             the specification — read 01, 02 and 03 before writing code
```

Clients reach only the `api` schema; every write is one `api` function and one
transaction; the Flutter app holds no business rules. See
[03 — Architecture](specs/03-architecture.md#repository-layout).

## How to read these documents

The marketing website and its CI/CD live separately in
[`wuselwall/wuselwall-website`](https://github.com/wuselwall/wuselwall-website).
Documentation source stays here. Its intended GitHub Pages address is
`https://docs.wuselwall.app/`; hosting activation is separate from merging this change.
See the [migration and cutover plan](specs/website-and-docs-migration.md) for prerequisites,
existing-link preservation and rollback. This split does not change repository visibility.

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
| 10 | [Deployment & Operations](specs/10-deployment-and-ops.md) | B3 — running a server: the stack, keys, backups, updates, server releases |
| 11 | [Security & Privacy](specs/11-security-and-privacy.md) | Threat model and the controls that answer each threat |
| 12 | [MCP & Assistants](specs/12-mcp-and-assistants.md) | B4 — MCP server design, Siri via Shortcuts today |
| 13 | [Roadmap](specs/13-roadmap.md) | Milestones, per-module v1 scope cuts, rough effort |
| 14 | [Open Questions](specs/14-open-questions.md) | Decisions deliberately deferred, with the deadline for each |
| 23 | [Roadmap after the Alpha](specs/23-roadmap-after-alpha.md) | What follows M1.6, in four phases, each item checked against the principles; and what is deliberately not on it |
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
5. **Self-hosted only**: the project runs no service that holds a family's data. Every
   household runs its own server, at home or as its own hosted Supabase project, and the
   store app connects to whichever one it chooses.
   → [ADR-013](specs/adr/ADR-013-self-hosted-compose-stack.md), [ADR-017](specs/adr/ADR-017-wuselwall-app-domain.md), [ADR-018](specs/adr/ADR-018-self-hosted-only.md)
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
10. **Public App Store and Google Play listings**, fed by GitHub Actions and fastlane;
    TestFlight and the Play internal track stay as pre-release channels.
    → [ADR-011](specs/adr/ADR-011-native-distribution-and-ci-cd.md), [ADR-018](specs/adr/ADR-018-self-hosted-only.md)

## Licence

WuselWall is licensed under the [Apache License, Version 2.0](LICENSE). Contributions are
accepted under the same licence (section 5). The name and the logo are not licensed for
other products (section 6). Third-party material in the repository keeps its own terms;
[NOTICE](NOTICE) lists it.
