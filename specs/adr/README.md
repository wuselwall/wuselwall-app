# Architecture Decision Records

Short records of the decisions that constrain everything else, kept so that a future
session — yours or an AI's — can see not just what was chosen but what was rejected and
why. When a decision changes, add a new ADR that supersedes the old one rather than
editing it. The value is in the trail.

| # | Decision | Status |
|---|---|---|
| [001](ADR-001-calendar-backbone.md) | Own database as calendar source of truth, ICS feed outward | Accepted |
| [002](ADR-002-build-vs-assemble.md) | One self-built application rather than composed open-source services | Accepted |
| [003](ADR-003-technology-stack.md) | TypeScript end to end: SvelteKit, Drizzle, PostgreSQL | Superseded by 010 |
| [004](ADR-004-identity-model.md) | Device sessions with tap-to-switch profiles and a guardian PIN | Accepted, amended by 010 and 014 |
| [005](ADR-005-hosting.md) | Self-hosted on a German VPS with Docker Compose and Caddy | Superseded by 013 |
| [006](ADR-006-offline-strategy.md) | Server-authoritative data; an offline queue for the shopping list only | Accepted, amended by 010 |
| [007](ADR-007-assistant-integration.md) | Remote MCP server over Streamable HTTP; Shortcuts for Siri today | Accepted, amended by 010 |
| [008](ADR-008-school-timetable-model.md) | Stundenplan as a projected pattern, not stored events | Accepted |
| [009](ADR-009-event-kinds-and-presence.md) | Presence as an event kind; the week board driven by an explicit flag | Accepted |
| [010](ADR-010-flutter-and-self-hosted-supabase.md) | Flutter clients on a self-hosted Supabase backend | Accepted, amended by 012, 013, 014, 015 and 018 |
| [011](ADR-011-native-distribution-and-ci-cd.md) | Native app distribution (TestFlight, Play internal) and the CI/CD pipeline | Accepted, amended by 012, 013, 014 and 015 |
| [012](ADR-012-product-name.md) | Product name WuselWall, its identifiers, logo and mascot | Accepted |
| [013](ADR-013-self-hosted-compose-stack.md) | Self-hosted Supabase on the official compose stack; no separate dev and prod | Accepted, amended by 014, 017 and 018 |
| [014](ADR-014-self-service-onboarding.md) | Self-service households; adults sign in with email (Apple and Google removed 2026-10-17); devices pair from a parent's phone | Accepted, amended by 015, 017 and 018, and on 2026-10-17 |
| [015](ADR-015-saas-and-self-hosted-flavours.md) | Two flavours: WuselWall Cloud on hosted Supabase, and self-hosted; public store listings | Superseded by 018 (store listings and no captcha stand) |
| [016](ADR-016-public-website.md) | A public website at the root (Astro, own compose project); the Flutter web app moves to /app/ | Accepted, superseded in part by 017, amended by 018 |
| [017](ADR-017-wuselwall-app-domain.md) | The domain wuselwall.app for the website, the docs and the links | Accepted |
| [018](ADR-018-self-hosted-only.md) | Self-hosted only: the store app connects to any WuselWall server; no WuselWall Cloud | Accepted, built 2026-10-14 |

Format: Context · Decision · Alternatives considered · Consequences.
