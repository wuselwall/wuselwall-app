# WuselWall app

Flutter client for iOS, iPadOS, Android and the web. Read the repository's
[contribution rules](../AGENTS.md) and [architecture](../specs/03-architecture.md)
before changing code. The application/bundle ID is `ch.goomba.wuselwall`.

## Explore without a server

Run these commands from `app/`, with the Flutter SDK installed:

```bash
flutter pub get
flutter run -d chrome -t lib/main_demo.dart
```

The demo uses in-memory sample data. It needs no backend or account, and changes
disappear when it restarts. Choose a view with a URL query, for example
`?scenario=kiosk&still=1` for the wall display with animations held still.

| `scenario` | Starting view |
|---|---|
| `adult` (default) | Adult's Today page |
| `kid` | Children's profile chooser |
| `kiosk` | Kitchen week board |
| `setup` | Sign-in and device connection |
| `newfamily` | New family form |
| `noschool` | Adult view before the first school is set up |
| `server` | Server selection |

For a native demo, choose the view at launch:

```bash
flutter run -t lib/main_demo.dart --dart-define=DEMO_SCENARIO=kid
```

## Connect to a development backend

Copy `env/dev.example.json` to the git-ignored `env/dev.json` and enter the URL and
publishable key of a development server. Then run:

```bash
flutter run --dart-define-from-file=env/dev.json -d web-server --web-hostname localhost --web-port 3000
```

Without a configured URL, as in `env/store.json`, the app asks for its server at
first start. No household's backend is built into the store app.

For a throwaway local stack, run `npm ci` and `npm run db:start` from the repository
root, with Docker running. From `app/`, use `env/ci.json`, which points to
`http://127.0.0.1:54321`. The local development seed provides the setup key
`dev-setup`: enter it under **I have the setup key**, then sign in and create the family.
That key is for the seeded local database only.

## Checks

From `app/`:

```bash
flutter analyze
flutter test
```

Backend integration tests create households and revoke devices. Run them **only
against a throwaway stack**, after starting it as described above:

```bash
flutter test test/integration --dart-define-from-file=env/ci.json
```

Never point these tests at a server holding family data. See the
[testing strategy](../specs/18-testing-strategy.md) for backend and device checks.

## Layout

```text
lib/
  app/                     bootstrap, router and per-register themes
  core/                    configuration, API client, errors, connectivity, l10n, shared UI
  features/<module>/       data/, domain/, application/ providers, ui/
  demo/                    in-memory repositories and sample data
  l10n/generated/          generated localisation output (committed)
l10n/app_{en,de,fr,es}.arb  user-facing strings in all four languages
env/                       build configuration; dev.json is git-ignored
test/                      unit, widget, golden and journey tests
test/integration/          backend integration tests; throwaway stack only
```

Widgets call repositories through providers. Repositories use the `api` schema or
Edge Functions and return typed results. Domain rules live on the server.

## Screenshots and guide

The [screenshot workflow](../docs/tools/README.md) captures this demo for the family
guide. Update the corresponding guide pages in DE/EN/FR/ES when a screen or label changes.
