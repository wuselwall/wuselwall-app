# WuselWall app

Flutter client (iOS, Android, web). Started from Supabase's `flutter-user-management`
example; see [ADR-010](../specs/adr/ADR-010-flutter-and-self-hosted-supabase.md).
Application/bundle ID and auth deep-link scheme: `ch.goomba.wuselwall`.

## Run

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json -d web-server --web-hostname localhost --web-port 3000
```

`env/dev.json` is git-ignored: copy `env/dev.example.json` and point it at your server
([ADR-013](../specs/adr/ADR-013-self-hosted-compose-stack.md)) — if that server holds a
family's data, develop with care. Without `SUPABASE_URL` (as in `env/store.json`) the app
asks for its server at the start ([ADR-018](../specs/adr/ADR-018-self-hosted-only.md)). `env/ci.json` points at a throwaway stack on `http://127.0.0.1:54321`
(`npm run db:start` with Docker on the laptop); the integration tests use only that.

## Layout

```
lib/
  main.dart                bootstrap: config check, Supabase init, ProviderScope
  app/                     app widget, router, theme (tokens, per-register ThemeData)
  core/                    config · error (Failure, Result, mapper) · supabase (ApiClient,
                           secure session storage) · connectivity · realtime · l10n · ui
  features/<module>/       data/ (repository) · domain/ (models) · application/ (providers) · ui/
    identity/              device + acting profile, PIN pad, tap-to-switch bar, guardian gate
    setup/                 splash, setup landing, household wizard, sign-in, enrol by code
    settings/              members, devices (enrolment code, revoke)
    shopping/              the shared list, live via Realtime
    system/                debug-only diagnostics (reference feature)
  l10n/generated/          gen-l10n output (committed)
l10n/app_en.arb, app_de.arb   every user-facing string, always both
env/                       dev.json, ci.json (public values only)
test/                      unit + widget tests; integration/ needs a running backend
```

## Checks

```bash
flutter analyze
flutter test
flutter test test/integration --dart-define-from-file=env/dev.json   # needs backend
```

First run on an empty database: open the app, "Set up a new household", setup token
`dev-setup`. Daily use: sign in, add members, create an enrolment code in Settings → Devices
and enter it on a second device.

```bash
```
