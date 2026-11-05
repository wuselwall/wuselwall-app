# Specification guide

These documents describe product decisions, architecture and implementation plans.
For instructions on using WuselWall, read the [family guide](https://docs.wuselwall.app/en/).
For a local demo and checks, start with the [app README](../app/README.md).

## Start here

1. Read [Vision & Scope](01-vision-and-scope.md) and [Requirements](02-requirements.md)
   to understand the product and its boundaries.
2. Read [Architecture](03-architecture.md) before changing code, then the specification
   for the module you are working on.
3. Check the [roadmap](13-roadmap.md), [build plan](16-setup-plan.md) and
   [release checklist](release-checklist.md) to distinguish implementation from release evidence.
4. Consult the [decision records](adr/README.md) when choices appear to conflict.
   Superseded records preserve history; they do not define current behaviour.

MCP and AI assistant work is [on hold](deferred/mcp-and-ai-assistants.md).
The retained designs describe compatibility and possible future work. Siri via Apple
Shortcuts and timetable text/photo import remain in scope.

## Document index

| # | Document | What it answers |
|---|---|---|
| 00 | [Brief & Decisions](00-brief-and-decisions.md) | Original brief, recorded decisions and trade-offs |
| 01 | [Vision & Scope](01-vision-and-scope.md) | Why this exists, who uses it, what success looks like, what is explicitly out |
| 02 | [Requirements](02-requirements.md) | Numbered functional and non-functional requirements, traceable to the original brief |
| 03 | [Architecture](03-architecture.md) | System shape, technology stack, module boundaries, cross-cutting concerns |
| 04 | [Data Model](04-data-model.md) | Entities, relationships, key invariants |
| 05 | [Calendar](05-module-calendar.md) | A1 — events, recurrence, the outbound ICS feed, Outlook reality check |
| 06 | [Tasks & Gamification](06-module-tasks.md) | A2 — chores, recurrence, points, rewards, streaks, badges |
| 07 | [Meals & Shopping](07-module-meals-shopping.md) | A3 + A4 — meal plan, shopping list, the link between them, offline behaviour |
| 15 | [School Timetable & Presence](15-module-school-timetable.md) | A5 — the Stundenplan as a pattern, presence for shift work and travel, the German glossary. *Read straight after 05.* |
| 08 | [Users, Auth & Permissions](08-users-auth-permissions.md) | B1 — household model, device sessions, profile switching, guardian PIN |
| 09 | [Clients & UX](09-clients-and-ux.md) | B2 — one Flutter app, three UI registers, **the kitchen week board**, platform constraints |
| 10 | [Deployment & Operations](10-deployment-and-ops.md) | B3 — running a server: the stack, keys, backups, updates, server releases |
| 11 | [Security & Privacy](11-security-and-privacy.md) | Threat model and the controls that answer each threat |
| 12 | [MCP & Assistants](12-mcp-and-assistants.md) | B4 — Siri via Shortcuts; MCP/AI assistants on hold |
| 13 | [Roadmap](13-roadmap.md) | Four outcomes, current implementation status and release gates |
| 14 | [Open Questions](14-open-questions.md) | Decisions deliberately deferred, with the deadline for each |
| 23 | [Roadmap after the Alpha](23-roadmap-after-alpha.md) | Candidates chosen from real use, principles and deliberate exclusions |
| 25 | [Wusel](25-wusel.md) | The family's companion: who Wusel is, the drawing, seven poses, outfits, the voice rules, where it appears and never appears |
| 26 | [Colour, ambience, celebration](26-colour-and-ambience.md) | Direction A+: module bands, decoration, the wall's day phases and occasions, celebrations, springs, sound and haptics |
| 27 | [Family rituals](27-family-rituals.md) | Tischfrage, Wochenrückblick, traditions, Vorfreude and Wunschessen, with birthdays, and how the trial judges each |
| 28 | [Event templates](28-event-templates.md) | Built-in, saved and history-based event starters |
| 29 | [Local matching](29-local-matching.md) | Shared dictionary, matching layers and household corrections |
| 24 | [School setup without typing](24-school-import.md) | Fewer required facts, timetable text/photo import and preview; assistant proposals on hold |
| 16 | [Setup Plan](16-setup-plan.md) | Remaining work in grouped slices; completed setup and CI/signing recipes kept as reference |
| 19 | [Security & Architecture Review](19-security-and-architecture-review.md) | Findings of the 2026-10-11 review, what is fixed and what the operator still has to do |
| 17 | [Design System](17-design-system.md) | Colour, type and form: the member palette (colour-blind-checked), presence treatments, night theme, three design directions, A "Küchentisch" chosen |
| 21 | [Household Settings](21-household-settings.md) | The reference household, the settings model, the setup wizard and every curated default with its reasoning |
| 18 | [Testing Strategy](18-testing-strategy.md) | The nine test layers from pgTAP to the family's devices: widget and golden matrices, Patrol on device, Playwright for the web build only, the manual release check, and where each runs |
| — | [Design system mockup](mockups/design-system.html) | The three directions on the same Monday, switchable between light, dark and night, with simulated colour-blindness |
| — | [Logo proposal](mockups/logo.html) | Logo concepts (Familien-W, Wuselchen, Wuselpunkte) next to the ADR-012 icon, as app icons at real sizes, in dark and themed variants |
| — | [Wusel and colour mockup](mockups/wusel-and-colour.html) | Wusel's poses and outfits, the module bands, the decoration, the wall's day phases and the kid sticker cards, in light and dark |
| — | [Kiosk mockup](mockups/kiosk-week-board.html) | The kitchen display's week board, interactive and in German — the asset for agreeing the layout with the family before it is built |
| — | [Shopping capture mockup](mockups/shopping-quick-add.html) | The three-second capture path: a tile picker over the learned catalogue, with the offline queue made visible |
| — | [Decision Records](adr/README.md) | Choices made and alternatives rejected |

