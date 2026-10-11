# WuselWall app

Flutter client (iOS, Android, web). Started from Supabase's `flutter-user-management`
example; see [ADR-010](../docs/adr/ADR-010-flutter-and-self-hosted-supabase.md).
Application/bundle ID and auth deep-link scheme: `ch.wuselwall.app`.

## Run

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json -d web-server --web-hostname localhost --web-port 3000
```

`env/dev.json` points at `http://127.0.0.1:54321`. Start the backend from the repo root
with `npm run db:start`, or against the homeserver Docker host with `npm run remote:start`
(it opens the SSH tunnel that makes that address work). On a phone, change `SUPABASE_URL`
to the backend's LAN address.

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
