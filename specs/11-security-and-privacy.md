# 11 — Security & Privacy

You asked for the app to be well implemented security-wise and for the data not to be
harvestable by an assortment of services. Both are achievable at this scale; the way to
get there is to be specific about what you are defending against.

## Threat model

**Assets, in order of what it would cost to lose them:** the family's whereabouts and
routines (the calendar, and since 2026-08-30 the presence entries that say who is away
overnight), the children's data (now including school, class and a term's timetable), the
shopping and meal history (a detailed picture of household life), and the server itself as
a resource someone else could use. *Since [ADR-014](adr/ADR-014-self-service-onboarding.md)
(2026-10-11):* **other families' data**, all of the above for households the operator does
not know. Losing that costs more than losing one's own, legally and otherwise.

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
| T4 | Credential stuffing against an adult account; a phished email code | Likely to be attempted, cheap to defeat. |
| T5 | Supply-chain compromise of a dependency — a `pub` or Deno package, a container image, a CI action | Real and rising; the hardest one on this list. |
| T6 | Data loss through disk failure, a bad migration, or `DROP TABLE` at 23:00 | The most likely damaging event of all. |
| T7 | Silent data harvesting by embedded third parties (analytics, fonts, CDNs, error trackers) | Certain, if you let them in. Entirely preventable. |
| T8 | A child escalating to guardian rights | Low stakes, moderate likelihood, worth a speed bump. |
| T9 | **A missing or wrong RLS policy** — the anon key is in every app binary, so anyone who extracts it can call the API directly *(added 2026-10-11, [ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md))* | The most likely way data leaks from this stack. |
| T10 | Leaked signing material — the iOS certificate, the Android upload key, the App Store Connect API key | Low likelihood, high annoyance: someone could ship a build under your name. |
| T11 | **Abuse of the open front door** — scripted sign-ups, email-code floods at someone else's address, guessing invitation or pairing codes, talking a guardian into approving a stranger's pairing request *(added 2026-10-11, ADR-014)* | Certain once sign-up is public; cheap to contain. |

**Out of scope**, stated so effort is not wasted: a targeted attacker with a specific
interest in this household, a state actor, physical seizure of the server, and malicious
insiders. If a threat model does not exclude anything it is not a threat model.

## Controls

### T1 — internet-facing exposure

*Revised 2026-10-11 for the home server ([ADR-013](adr/ADR-013-one-self-hosted-environment.md)).*

- **Only 443 is forwarded** from the router, to nginx. The DNS record is proxied by
  Cloudflare, so the home address is not published in DNS.
- **nginx forwards exactly four API prefixes** to the gateway, on `api.wuselwall.app`
  (and, until old app builds are gone, on `wusel.goomba.ch`)
  ([`infra/nginx/wuselwall.app.conf`](../infra/nginx/wuselwall.app.conf)); Studio, the
  `/pg/` metadata API and everything else answer 404.
- **Postgres (127.0.0.1:54422) and Studio (behind the gateway, reached by SSH tunnel) are never forwarded or proxied.**
  The CLI stack publishes them on the home network only; anyone on the home wifi can reach
  them, which is accepted for a household network and must not be extended.
- **Anonymous users are disabled; public sign-up is enabled for adults** (since
  ADR-014). A new account has no household claim and therefore reads and writes nothing
  (RLS), and it can create a household only in the instance's `household_creation` mode
  (T11).
- **Never run with the CLI's default keys.** `auth.jwt_secret`, `auth.publishable_key` and
  `auth.secret_key` come from the git-ignored `supabase/.env`. The defaults are public;
  with them, anyone holds the service role.
- **Founder codes are random and single use** (`scripts/remote-setup-token.sh`); the
  seed's `dev-setup` is in git and must never exist on the home server (S3 in
  [19](19-security-and-architecture-review.md)).
- Cloudflare terminates TLS with modern defaults; set *Always Use HTTPS* and HSTS in its
  dashboard. Between Cloudflare and nginx: the origin certificate, SSL mode Full (strict).
- Supabase's images are used as published, pinned through the Supabase CLI version in
  `package.json`; nothing is built on the server, and no auto-updater touches them.

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

- **Most adults have no password at all.** Apple, Google and email codes leave nothing
  to stuff. Passwords that exist are at least 10 characters, with a strength meter in the
  app (S14 in [19](19-security-and-architecture-review.md)).
- **TOTP is optional**, never part of sign-up (ADR-014: Apple and Google enforce their
  own second factors; a mandatory one locks out a sole guardian who loses a phone).
  Passkeys are offered from the getting-started card once verified on hardware.
- Email codes: 6 digits, 10 minutes, single use, a resend at most every 60 s, and
  verification attempts rate-limited per IP by Supabase Auth. The mail says what the code
  is for, in the recipient's language, and that nobody from WuselWall will ever ask for it.
- A new sign-in on an account notifies its other devices.
- Supabase Auth's rate limits on sign-in, plus a rate limit at nginx or Cloudflare; PINs hashed with
  bcrypt, with exponential backoff per profile.
- PIN lockout after 10 failures, released only by a full guardian login.
- Generic error messages on login. No "unknown email" hints. The email step behaves the
  same for registered and unregistered addresses (a code is sent either way), so it
  cannot be used to probe who has an account.
- The native apps send bearer tokens, so there are no cookies to steal and no CSRF
  surface. The web build keeps its session in browser storage, which makes a strict CSP
  the guard against script injection there.

### T5 — supply chain

- Lockfiles committed (`pubspec.lock`, both `package-lock.json`, `Gemfile.lock`, and
  `deno.lock` once there are Edge Functions); CI installs exactly what they say
  (`flutter pub get --enforce-lockfile`, `npm ci`), and the release jobs do so before any
  signing secret is in reach.
- Keep the dependency count deliberately low. Every package is a party you have invited
  into your family's data — and in a Flutter app, every plugin is native code too.
- `osv-scanner` over every lockfile in CI (`ci.yml`, job `audit`); accepted advisories
  sit in `osv-scanner.toml` with a reason and an expiry. Dependabot PRs
  (`.github/dependabot.yml`, with a seven-day cooldown) reviewed rather than auto-merged.
- Container images pinned by digest, not by floating tag (the website's Node image is;
  the Supabase images are still pinned by exact tag, following the CLI); GitHub Actions
  pinned by commit SHA with the version as a comment; the Gradle wrapper by checksum.
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
| Google Analytics / Plausible Cloud | Nothing. You have four users and you know all of them. *(Still nothing with other families: onboarding is measured by timed walk-throughs, [20](20-onboarding.md#how-smooth-is-checked).)* |
| A deferred-deep-link or attribution SDK so invitations survive installation | The invitation code and the email match ([20, J2](20-onboarding.md#j2--join-a-family)). |
| A captcha on sign-up | None, decided 2026-10-11 ([Q44](14-open-questions.md)): rate limits, `code` mode until the gate, and the empty-account clean-up. |
| Open and click tracking in sign-in mail | Switched off at the mail provider; plain text plus minimal HTML ([10](10-deployment-and-ops.md#email-setup)). |

**Accepted since ADR-014**, each only for those who use it: **Apple** and **Google** as
sign-in providers (they learn that the person signs in to WuselWall; scopes are
`email`/`name`/`profile` only), and **one SMTP provider** ([Q41](14-open-questions.md);
decided: Scaleway, EU), which sees email addresses and sign-in codes and nothing from
the household. *(ADR-015's Supabase Inc. as Cloud's processor is gone with Cloud, [ADR-018](adr/ADR-018-self-hosted-only.md).)*
**Since ADR-018**, the store app carries **Google's iOS sign-in library** for the family's
server. Its privacy manifest declares device ID and usage data for analytics (Google's,
not tracking), and the privacy policy and store labels say so. Apple's sign-in is part of
iOS and adds no code.
**Found 2026-10-13, fixed 2026-10-14:** the Android QR scanner used `mobile_scanner`, which bundles Google's **ML Kit** and sent device, app and performance data with a per-installation identifier to Google. The scanner now uses the `camera` plugin and the pure-Dart `zxing2` decoder on every platform, so no vendor SDK reads the camera image ([Q49](14-open-questions.md)).
| A holiday import from a public API ([15](15-module-school-timetable.md#holidays)) | Fetched by the server only, with the host pinned in configuration and the result cached in the database. The browser never contacts it, and a failed fetch keeps the last good data (hand-entered holidays always work) rather than raising an error. Built 2026-10-14: the host is `openholidaysapi.org`, see the outbound list below. |
| An external map or weather widget | If you want weather on the wall display, proxy it server-side so the app never contacts a third party directly, and cache aggressively. |
| Avatar images from Gravatar | Local uploads or generated initials. |

For the web build, enforce it with `Content-Security-Policy: default-src 'self'`. For
the native apps, enforce it in review: the app talks to exactly one host, and a new
outbound host in a pull request is a question to answer, not a detail. A policy that is a
mechanism survives temptation on a Friday evening.

### Outbound calendar subscriptions

Added 2026-10-14 with FR-1.9. A guardian types the address of a calendar (a club's fixture list,
the bin collection), and the server fetches it. That makes the server a fetcher of arbitrary
addresses, which is the classic server-side request forgery risk, so `_shared/safe_fetch.ts`
enforces, on the first address and on every redirect:

- **https only** (`webcal://` is rewritten to `https://` when the address is saved);
- **public addresses only**: a host that resolves to a private, loopback, link-local or
  otherwise reserved address is refused, IPv4 and IPv6;
- **redirects are followed by hand**, each hop checked again, at most three;
- **15 seconds** in total, **2 MB** of body, and the answer must be an iCalendar document.

Residual risk, stated plainly: the address is resolved once for the check and again by the
HTTP client, so a hostile DNS server that answers differently the second time (DNS rebinding)
could still reach an internal address. Closing it fully needs a connection pinned to the checked
address, which the runtime does not offer yet. The address is chosen by a guardian, which limits
who could do this, but does not prevent it.

The requests carry the User-Agent `WuselWall calendar-import (+https://wuselwall.app)`, and the
third party sees the server's IP address and the request time, like any HTTPS request. Nothing about
the household is sent, except what is in the address the family typed.

Who may read the address: only guardians. The subscription list that every live device of the
household reads (`api.external_calendars`) carries the host name only (`url_host`). The full address
comes from `api.external_calendar_url`, which refuses children's devices, kiosks, revoked devices and
other households, and writes no audit row. The household export, which is guardian-only, includes it.

Outbound connections from the server should be enumerable on one hand: Let's Encrypt,
the container registry, the backup target, APNs and FCM (for push), the OS package
mirrors, and since ADR-014 the SMTP provider and Apple's and Google's token endpoints. Added
2026-10-14: the calendar addresses that guardians subscribe to (see above), chosen by the family,
and `openholidaysapi.org` for the holiday cache.

Added 2026-10-14: `openholidaysapi.org` (OpenHolidays, the public holiday dataset). The server
calls it weekly (`holidays-sync`) and when a member picks a country in the app. The request
carries only the country codes, date ranges and the server's own IP address, like any HTTPS
request; nothing about the household, its members, its schools or its region choice is sent.
The results are cached as public reference data.

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
  Functions that have no user (ICS, enrolment, jobs) and by `account-delete` and the MFA
  reset (ADR-014), which need the Auth Admin API and act only on the verified caller or
  their co-guardian; each such use commented; it is
  never in CI, never in the app and never on a laptop.

### T11 — the open front door

*Added 2026-10-11 ([ADR-014](adr/ADR-014-self-service-onboarding.md)).*

- **`code` mode until the opening gate.** Strangers can sign up, but cannot create a
  household without a founder code. An account with no household costs one row and
  reaches nothing. Accounts that never join or create a household are deleted after 30
  days by a job.
- **Rate limits in three places:** Supabase Auth's own (`[auth.rate_limit]`: email sends,
  verifications, sign-ins per IP), Cloudflare rules for `/auth/v1/otp`, `/auth/v1/token*`
  and the anon RPCs (S9 in [19](19-security-and-architecture-review.md)), and the
  attempt log that already guards `enrol_device`, extended to `invitation_preview` and
  `pairing_start`.
- **Invitations:** a 128-bit token in the link, an 8-character code with attempt
  limits, 7 days, single use, revocable. Accepting notifies every guardian, and the
  audit log records inviter and invitee. An invitation never reveals more than the
  household's name and the inviter's first name.
- **Pairing:** the display code alone grants nothing. Binding needs a guardian's approval
  from a personal device, and collecting the credentials needs the secret held only by
  the requesting device. The approval screen repeats the code and warns against
  approving a device that is not in front of you. That is the one social-engineering
  path, and it ends in a shared device a guardian can see and revoke in Geräte.
- **Other servers cannot harvest the family's sign-ins** ([ADR-018](adr/ADR-018-self-hosted-only.md),
  decision 6; first argued for Cloud in ADR-015). The store app uses native Apple and
  Google sign-in, whose ID tokens are addressed to our app, only against the first-party
  servers compiled into the app (the user's Unraid stack). Against any other server it
  offers email and the operator's own redirect clients. A hostile server therefore never
  receives a token that the family's server would accept. The app shows the server's host
  on every sign-in screen.
- **Cross-household isolation is now about strangers.** The pgTAP cross-household cases
  (T9) are release-blocking, and the catalogue test pins the exact list of
  anon-callable functions.

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
  public by design. Review `env/dev.json` before each release.
- **No raw HTML.** Flutter does not interpret HTML by default; do not add a widget that
  does without a comment explaining why the content is safe.
- **Uploads** (avatars, recipe photos, if Storage is ever enabled): validate the magic
  bytes rather than the extension, cap the size, and store them in a private bucket with
  RLS on `storage.objects`.
- **Rate limit** sign-in, PIN entry, enrolment, feed fetches and the MCP endpoint — at
  nginx or Cloudflare, and in the function where it is a domain rule (PIN backoff).

## Privacy and legal

- **GDPR does not apply** to processing carried out by a natural person in the course of
  a purely personal or household activity (Art. 2(2)(c)). A family organiser used only by
  your own household is squarely inside that exemption. This stops being true the moment
  you let another family use it — at which point you become a controller with all the
  obligations that follow. It is worth knowing exactly where that line is before you
  generously offer an account to a friend.
- **With self-service ([ADR-014](adr/ADR-014-self-service-onboarding.md)) that line is
  the opening gate** ([13](13-roadmap.md#opening-to-other-households)). Before it,
  households other than this one exist only by founder code, given to people the operator
  knows. From it, the operator is a controller and needs:
  - a privacy policy (linked from the front door, the landing pages and the stores);
  - a record of processing (Art. 30);
  - processor agreements with the SMTP provider and Cloudflare (the links site);
  - deletion and export in the app (FR-5.16);
  - a 72-hour breach procedure (Art. 33);
  - a contact address that is read.

  Children never sign up and never have accounts: their data is entered by their parents,
  which keeps Art. 8 (a child's own consent) out of the picture but not the duty of care
  below.
- **Children's data** deserves care independent of any legal duty. Collect the minimum:
  a name, a colour, an avatar. No location tracking, no photographs of children reachable
  from the internet, no behavioural data leaving the server. Their chore history is a
  detailed record of a child's daily life; it should never exist anywhere but your own
  database and your encrypted backups.
- **Deletion**: a proper "delete member" that removes their profile and anonymises rather
  than orphans their historical rows. Worth building once, while the model is small.

## Pre-launch checklist

- [ ] Router forwards 443 only; Postgres, Studio and Mailpit not reachable from outside the home
- [ ] nginx answers 404 outside the four API prefixes
- [ ] Anonymous users disabled; `household_creation` is `code`; the stack runs on its own keys, not the CLI defaults
- [ ] No `dev-setup` founder code on the home server; the family's own founder code used and consumed
- [ ] Sign-in with Apple, Google, email code and password each tested on a real device; the
      email-code mail arrives (not in spam) in both languages
- [ ] A stranger's fresh account sees nothing: one manual probe of `api` with its token
- [ ] Invitation and pairing tested end to end, including an expired and a withdrawn invitation
- [ ] Account deletion tested, including Apple token revocation
- [ ] RLS catalogue test and every policy test green against the live schema
- [ ] TLS working; HSTS and Always Use HTTPS on in Cloudflare
- [ ] Content-Security-Policy set, and verified to break nothing
- [ ] No third-party origin contacted by the web build (network tab, clear cache) or the
      apps (a proxy such as mitmproxy on the LAN for one session)
- [ ] `supabase/.env` mode 600, not in git; a copy in the password manager
- [ ] Nightly backup running, dead-man's switch configured
- [ ] **A restore performed successfully at least once** — date: ____________
- [ ] Device revocation tested from a second device
- [ ] Feed token revocation tested against a real Outlook subscription
- [ ] PIN lockout tested
- [ ] `osv-scanner` clean, or every finding consciously accepted
- [ ] Signing material and its passphrases in the password manager
- [ ] Audit log written for a sample of every mutation type
