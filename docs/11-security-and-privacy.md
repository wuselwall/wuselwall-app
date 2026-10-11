# 11 — Security & Privacy

You asked for the app to be well implemented security-wise and for the data not to be
harvestable by an assortment of services. Both are achievable at this scale; the way to
get there is to be specific about what you are defending against.

## Threat model

**Assets, in order of what it would cost to lose them:** the family's whereabouts and
routines (the calendar, and since 2026-08-30 the presence entries that say who is away
overnight), the children's data (now including school, class and a term's timetable), the
shopping and meal history (a detailed picture of household life), and the server itself as
a resource someone else could use.

The A5 addition raised the value of the first two assets materially. A calendar says a
family has a dentist appointment; a timetable plus presence bands says which child is at
which school between which hours and which adult is not at home that week. Nothing about
the controls below changes — but the defaults do, in [T2](#t2--feed-tokens).

**In scope:**

| # | Threat | Realistic? |
|---|---|---|
| T1 | Automated scanning and exploitation of a known CVE in an exposed service | Constantly. This is the baseline of running anything on the public internet. |
| T2 | A leaked ICS feed URL (pasted into a support ticket, synced to a third-party calendar service, in a browser history on a shared machine) | Plausible. Bearer URLs leak. |
| T3 | A lost or stolen device holding a year-long device session | Plausible. Children lose iPads. |
| T4 | Credential stuffing against a guardian account | Likely to be attempted, cheap to defeat. |
| T5 | Supply-chain compromise of a dependency — a `pub` or Deno package, a container image, a CI action | Real and rising; the hardest one on this list. |
| T6 | Data loss through disk failure, a bad migration, or `DROP TABLE` at 23:00 | The most likely damaging event of all. |
| T7 | Silent data harvesting by embedded third parties (analytics, fonts, CDNs, error trackers) | Certain, if you let them in. Entirely preventable. |
| T8 | A child escalating to guardian rights | Low stakes, moderate likelihood, worth a speed bump. |
| T9 | **A missing or wrong RLS policy** — the anon key is in every app binary, so anyone who extracts it can call the API directly *(added 2026-10-11, [ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md))* | The most likely way data leaks from this stack. |
| T10 | Leaked signing material — the iOS certificate, the Android upload key, the App Store Connect API key | Low likelihood, high annoyance: someone could ship a build under your name. |

**Out of scope**, stated so effort is not wasted: a targeted attacker with a specific
interest in this household, a state actor, physical seizure of the server, and malicious
insiders. If a threat model does not exclude anything it is not a threat model.

## Controls

### T1 — internet-facing exposure

- Only ports 80 and 443 open. SSH restricted by `ufw`; consider moving SSH behind
  **Tailscale** and closing 22 entirely — a genuine improvement for roughly twenty
  minutes of work.
- **Postgres has no published port** on any public interface; the pooler is bound to
  `127.0.0.1` and reached from CI only through an SSH tunnel.
- **Studio and Kong's dashboard routes are never routed by Caddy.** Studio is reached
  through `ssh -L` only. Caddy forwards exactly four API prefixes plus the feed path
  ([10](10-deployment-and-ops.md#6-caddyfile)); everything else is the static web build.
- **Public sign-up and anonymous users are disabled** in Supabase Auth. Accounts exist
  only because the setup wizard, a guardian or the enrolment function created them.
- **Never run with the upstream example keys.** `JWT_SECRET`, the anon and service-role
  keys, and every password in `.env` are generated fresh for production.
- `unattended-upgrades` for OS patches; monthly image pulls; `fail2ban` on SSH.
- Caddy terminates TLS with modern defaults and HSTS. No legacy protocol support to
  configure, because there is none.
- Supabase's images are used as published, pinned by digest; nothing is built on the
  server.

### T2 — feed tokens

- 256 bits of entropy per token; only the hash is stored.
- One token per subscriber, individually revocable, with `last_fetched_at` and a fetch
  count visible in settings so an unexpectedly busy token is noticeable.
- Feed responses contain calendar data only — never a member list, never household
  settings, never anything that would help an attacker elsewhere.
- Feed URLs are excluded from access logs and never appear in error messages.
- Per-token rate limiting at the proxy.
- Optional and cheap: an expiry date on tokens issued to third parties.
- **New tokens exclude presence and school entries by default** (FR-1.17, FR-7.13). A
  leaked feed then discloses appointments — bad enough — rather than a minor's daily
  timetable, class and school, and which adult is away from the house on which nights.
  That combination is the most sensitive thing this system will ever hold, and the
  default should reflect it. Including it is a checkbox with a warning next to it.

### T3 — device loss

- Every device is its own Auth user. Revoking one affects nothing else.
- Settings → Devices shows last-seen times, which is how you notice a device you forgot
  about.
- A shared or kiosk device holds **no** guardian rights: the PIN elevation is server-side
  and expires in 15 minutes, so a stolen iPad grants a child's view and nothing more.
- Revocation is effective on the very next request, because every RLS policy checks
  `device.revoked_at` rather than trusting a still-valid JWT.
- Device sessions live in the Keychain or Android Keystore-backed storage, not in plain
  app files.
- Consider auto-revoking a device unseen for 180 days.

### T4 — account attacks

- TOTP as a mandatory second factor on guardian accounts; passkeys as the primary
  credential if Supabase Auth supports them when M0.1 is built.
- Supabase Auth's rate limits on sign-in, plus a rate limit at Caddy; PINs hashed with
  bcrypt, with exponential backoff per profile.
- PIN lockout after 10 failures, released only by a full guardian login.
- Generic error messages on login. No "unknown email" hints.
- The native apps send bearer tokens, so there are no cookies to steal and no CSRF
  surface. The web build keeps its session in browser storage, which makes a strict CSP
  the guard against script injection there.

### T5 — supply chain

- Lockfiles committed (`pubspec.lock`, `deno.lock`); CI installs exactly what they say.
- Keep the dependency count deliberately low. Every package is a party you have invited
  into your family's data — and in a Flutter app, every plugin is native code too.
- `osv-scanner` over both lockfiles in CI; Dependabot PRs reviewed rather than
  auto-merged.
- Container images pinned by digest, not by floating tag; GitHub Actions pinned by
  version (by commit SHA for anything outside GitHub's and Supabase's own).
- No analytics, crash-reporting or ad SDK in the app, ever — they are the most common
  supply-chain leak in mobile apps.

### T6 — data loss

Covered in [10](10-deployment-and-ops.md): nightly encrypted off-site backups, a
dead-man's-switch ping, and a **tested** restore. Additionally: take a manual dump
immediately before every migration, and read every generated migration before applying
it. `restic` encrypts client-side, so the backup provider stores ciphertext only.

### T7 — third parties (the "data not harvested" requirement)

This is where a self-hosted app usually leaks, quietly, through convenience:

| Tempting | Instead |
|---|---|
| Google Fonts | Self-host WOFF2 files. Also faster. |
| A CDN for a JS library, Google Fonts in Flutter web | Bundle it; ship fonts as assets. |
| Sentry / Crashlytics / PostHog / Firebase Analytics | Nothing in v1. TestFlight and Play Console already report crashes. Self-host GlitchTip later if you must. |
| Google Analytics / Plausible Cloud | Nothing. You have four users and you know all of them. |
| A Ferien import from a public API ([15](15-module-school-timetable.md#holidays)) | Fetched by a scheduled Edge Function, server-side only, with the host pinned in configuration and the result cached in the database. The browser never contacts it, and a failed fetch degrades to hand-entered holidays rather than to an error. |
| An external map or weather widget | If you want weather on the wall display, proxy it server-side so the app never contacts a third party directly, and cache aggressively. |
| Avatar images from Gravatar | Local uploads or generated initials. |

For the web build, enforce it with `Content-Security-Policy: default-src 'self'`. For
the native apps, enforce it in review: the app talks to exactly one host, and a new
outbound host in a pull request is a question to answer, not a detail. A policy that is a
mechanism survives temptation on a Friday evening.

Outbound connections from the server should be enumerable on one hand: Let's Encrypt,
the container registry, the backup target, APNs and FCM (for push), and the OS package
mirrors.

### T8 — a curious nine-year-old

- Guardian actions behind a 6-digit PIN, entered on a keypad with no visible echo.
- Enter it out of sight where practical; assume it will eventually be observed anyway.
- The audit log means escalation is at worst noticed. That is a proportionate response
  to a proportionate threat.

### T9 — the RLS perimeter

With Supabase, row-level security is not defence in depth; it is the perimeter.

- **Clients can reach only the `api` schema.** Tables in `app` are not exposed, so a
  forgotten policy on a table is not directly reachable — but a view or function on top of
  it is, which is why both layers are tested.
- **Every `app` table has RLS enabled and forced**, enforced by a catalogue test in CI
  that fails the build when a new table forgets.
- **Every policy has a pgTAP test** for the cross-household case, the revoked-device case
  and the unauthenticated case.
- `api` views are `security_invoker`; `api` functions run as a role without `BYPASSRLS`,
  so neither silently widens access.
- The **service-role key** exists only in the server's `.env`. It is used by the Edge
  Functions that have no user (ICS, enrolment, jobs), each such use commented; it is
  never in CI, never in the app and never on a laptop.

### T10 — signing material

- iOS certificates live encrypted in a private `fastlane match` repository; the
  passphrase is in GitHub secrets and the password manager only.
- The Android upload key is enrolled in Play App Signing, so a leaked or lost upload key
  can be reset by Google without losing the app.
- The App Store Connect API key has the narrowest role that can upload builds.

## Application-level practice

- **Validate at every boundary.** `api` functions check their arguments and rely on
  `CHECK` constraints and enums underneath; Edge Functions validate request bodies with
  Zod before touching anything. Never pass a raw JSON body into SQL.
- **No dynamic SQL from strings.** Where PL/pgSQL needs `EXECUTE`, parameters go through
  `USING` and identifiers through `format('%I')` — never concatenation.
- **Household scoping is RLS's job**, and RLS is tested (T9). No query relies on a
  hand-written `WHERE household_id`.
- **Authorisation in the database, never in the UI.** Hiding a button is a courtesy; the
  check happens in the `api` function and the policy, always.
- **No secrets in the app.** Only the Supabase URL and anon key are compiled in, both
  public by design. Review `env/prod.json` before each release.
- **No raw HTML.** Flutter does not interpret HTML by default; do not add a widget that
  does without a comment explaining why the content is safe.
- **Uploads** (avatars, recipe photos, if Storage is ever enabled): validate the magic
  bytes rather than the extension, cap the size, and store them in a private bucket with
  RLS on `storage.objects`.
- **Rate limit** sign-in, PIN entry, enrolment, feed fetches and the MCP endpoint — at
  Caddy, and in the function where it is a domain rule (PIN backoff).

## Privacy and legal

- **GDPR does not apply** to processing carried out by a natural person in the course of
  a purely personal or household activity (Art. 2(2)(c)). A family organiser used only by
  your own household is squarely inside that exemption. This stops being true the moment
  you let another family use it — at which point you become a controller with all the
  obligations that follow. It is worth knowing exactly where that line is before you
  generously offer an account to a friend.
- **Children's data** deserves care independent of any legal duty. Collect the minimum:
  a name, a colour, an avatar. No location tracking, no photographs of children reachable
  from the internet, no behavioural data leaving the server. Their chore history is a
  detailed record of a child's daily life; it should never exist anywhere but your own
  database and your encrypted backups.
- **Deletion**: a proper "delete member" that removes their profile and anonymises rather
  than orphans their historical rows. Worth building once, while the model is small.

## Pre-launch checklist

- [ ] SSH: keys only, root login disabled, `ufw` active
- [ ] Postgres not reachable from outside the server; Studio and Kong dashboards not routed
- [ ] Public sign-up and anonymous users disabled; no upstream example key in `.env`
- [ ] RLS catalogue test and every policy test green against the production schema
- [ ] TLS working; HSTS present
- [ ] Content-Security-Policy set, and verified to break nothing
- [ ] No third-party origin contacted by the web build (network tab, clear cache) or the
      apps (a proxy such as mitmproxy on the LAN for one session)
- [ ] Every secret in `.env`, mode 600, not in git; a copy in the password manager
- [ ] Nightly backup running, dead-man's switch configured
- [ ] **A restore performed successfully at least once** — date: ____________
- [ ] Device revocation tested from a second device
- [ ] Feed token revocation tested against a real Outlook subscription
- [ ] PIN lockout tested
- [ ] `osv-scanner` clean, or every finding consciously accepted
- [ ] Signing material and its passphrases in the password manager
- [ ] Audit log written for a sample of every mutation type
