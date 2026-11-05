# WuselWall — Family Organiser

WuselWall brings the family calendar, school timetables, tasks, meals and shopping
list together on phones, tablets, computers and a kitchen wall display.

The clients use Flutter for iOS, iPadOS, Android and the web. Each family runs its
own Supabase backend, at home, on a rented server or in its own hosted Supabase
project. The project runs no service that stores family data.

## Get started

- **Use WuselWall:** read the [family guide](https://docs.wuselwall.app/en/), available
  in [German](https://docs.wuselwall.app/), [English](https://docs.wuselwall.app/en/),
  [French](https://docs.wuselwall.app/fr/) and [Spanish](https://docs.wuselwall.app/es/).
- **Set up a family server:** choose an [installation route](https://docs.wuselwall.app/en/server/),
  then follow [signing in and connecting](https://docs.wuselwall.app/en/guide/setup).
- **Explore the screens:** take the [visual tour](https://docs.wuselwall.app/en/#a-look-at-the-app),
  or run the local demo below.
- **Contribute:** read [AGENTS.md](AGENTS.md), the [app README](app/README.md) and
  the [specification guide](specs/README.md).

## Project status

Core features are implemented: shopping with an offline queue, tasks and points,
calendar and school timetables, meals, onboarding, household settings and the wall
board. Local reminders, Apple Shortcuts and timetable text/photo import are built too.

**WuselWall is preparing for a family Alpha.** Native-device qualification, the
two-week family trial and public store readiness remain open. Screenshots and demo
checks demonstrate the interface; they do not establish release readiness. See the
[release checklist](specs/release-checklist.md) and
[qualification record](https://github.com/wuselwall/wuselwall-app/issues/117).

| Order | Milestone | Status |
|---|---|---|
| 1 | Everyday essentials: remaining setup, approval and offline-wall journeys | In progress |
| 2 | A lighter day: Wusel, colour, ambience, birthdays and family rituals | Implemented |
| 3 | Family Alpha: qualify real devices, use for two weeks, address findings | Next, after the remaining essentials and qualification |
| 4 | Ready for other families: safe releases, independent setup and store readiness | After the Alpha |

The [roadmap](specs/13-roadmap.md) defines these outcomes; the
[build plan](specs/16-setup-plan.md) lists remaining work. Later candidates belong in
[After the Alpha](specs/23-roadmap-after-alpha.md). MCP and AI assistant work is
[on hold](specs/deferred/mcp-and-ai-assistants.md); the backend is retained for compatibility.
No release dates are promised.

## Run a local demo

With the Flutter SDK installed, run from the repository root:

```bash
cd app
flutter pub get
flutter run -d chrome -t lib/main_demo.dart
```

The demo uses sample data in memory and needs no backend or account. Changes disappear
when it restarts. See the [app README](app/README.md) for device views, server-connected
development and checks.

## Repository map

| Directory | Contents |
|---|---|
| [app/](app/) | Flutter clients, shared UI, localisation and tests |
| [supabase/](supabase/) | Forward-only migrations, Edge Functions, pgTAP tests and local seed data |
| [server/](server/) | Server release tool: install, update, backup and restore |
| [infra/](infra/) | Compose stack, scheduled jobs and backup configuration |
| [docs/](docs/) | Family guide in DE/EN/FR/ES, built with VitePress |
| [specs/](specs/README.md) | Product specifications, architecture and decision records |
| [dictionary/](dictionary/README.md) | Shared matching dictionary and acceptance examples |
| [scripts/](scripts/) | Build, release and operator tooling |
| [.github/workflows/](.github/workflows/) | App, server and documentation CI/CD |

The family guide is published from this repository at
[docs.wuselwall.app](https://docs.wuselwall.app/). The marketing site, legal pages and
store-link landing pages live in the separate private `wuselwall/wuselwall-website`
repository. App and guide work does not require access to it.

## Work on the family guide

From the repository root, with Node.js and Flutter installed:

```bash
npm ci
npx playwright install chromium
npm run docs:screenshots
npm run docs:check
npm run docs:build
npm run docs:dev
```

On Linux, Chromium may also need system dependencies; see
[the screenshot instructions](docs/tools/README.md). Screenshots come from the local
Flutter demo in all four languages and both themes. They are generated output.
Use `<Shot name="…" alt="…" />` in guide pages and update all four languages together.

## Licence

WuselWall is licensed under the [Apache License, Version 2.0](LICENSE). Contributions
use the same licence. The licence does not grant permission to use the WuselWall name
or logo for other products. [NOTICE](NOTICE) lists third-party material and its terms.
