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
the controls below changes — but the defaults do, in [T2](#t2-feed-tokens).

**In scope:**

| # | Threat | Realistic? |
|---|---|---|
| T1 | Automated scanning and exploitation of a known CVE in an exposed service | Constantly. This is the baseline of running anything on the public internet. |
| T2 | A leaked ICS feed URL (pasted into a support ticket, synced to a third-party calendar service, in a browser history on a shared machine) | Plausible. Bearer URLs leak. |
| T3 | A lost or stolen device holding a year-long device session | Plausible. Children lose iPads. |
| T4 | Credential stuffing against a guardian account | Likely to be attempted, cheap to defeat. |
| T5 | Supply-chain compromise of an npm dependency | Real and rising; the hardest one on this list. |
| T6 | Data loss through disk failure, a bad migration, or `DROP TABLE` at 23:00 | The most likely damaging event of all. |
| T7 | Silent data harvesting by embedded third parties (analytics, fonts, CDNs, error trackers) | Certain, if you let them in. Entirely preventable. |
| T8 | A child escalating to guardian rights | Low stakes, moderate likelihood, worth a speed bump. |

**Out of scope**, stated so effort is not wasted: a targeted attacker with a specific
interest in this household, a state actor, physical seizure of the server, and malicious
insiders. If a threat model does not exclude anything it is not a threat model.

## Controls

### T1 — internet-facing exposure

- Only ports 80 and 443 open. SSH restricted by `ufw`; consider moving SSH behind
  **Tailscale** and closing 22 entirely — a genuine improvement for roughly twenty
  minutes of work.
- **Postgres has no published port.** It is reachable only from the Docker network.
- `unattended-upgrades` for OS patches; monthly image pulls; `fail2ban` on SSH.
- Caddy terminates TLS with modern defaults and HSTS. No legacy protocol support to
  configure, because there is none.
- A minimal container image (distroless or alpine), running as a non-root user, with no
  shell in the production image.

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

- Every device has its own token. Revoking one affects nothing else.
- Settings → Devices shows last-seen times, which is how you notice a device you forgot
  about.
- A shared or kiosk device holds **no** guardian rights: the PIN elevation is server-side
  and expires in 15 minutes, so a stolen iPad grants a child's view and nothing more.
- Consider auto-revoking a device unseen for 180 days.

### T4 — account attacks

- Passkeys as the primary guardian credential: nothing phishable, nothing to stuff.
- Argon2id for passwords and PINs, with per-account rate limiting and exponential
  backoff.
- PIN lockout after 10 failures, released only by a full guardian login.
- Generic error messages on login. No "unknown email" hints.
- Sessions are `httpOnly`, `Secure`, `SameSite=Lax`; CSRF tokens on state-changing
  form posts.

### T5 — supply chain

- A lockfile, committed, with `npm ci` / `pnpm install --frozen-lockfile` in CI.
- Keep the dependency count deliberately low. Every package is a party you have invited
  into your family's data.
- `npm audit` (or `osv-scanner`) in CI; Renovate PRs reviewed rather than auto-merged.
- Pin base images by digest, not by floating tag.
- A strict Content-Security-Policy limits what a compromised front-end dependency can
  exfiltrate — which is one more reason to self-host every asset.

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
| A CDN for a JS library | Bundle it. |
| Sentry / LogRocket / PostHog | Nothing in v1. Self-host GlitchTip later if you must. |
| Google Analytics / Plausible Cloud | Nothing. You have four users and you know all of them. |
| A Ferien import from a public API ([15](15-module-school-timetable.md#holidays)) | Fetched by the worker, server-side only, with the host pinned in configuration and the result cached in the database. The browser never contacts it, and a failed fetch degrades to hand-entered holidays rather than to an error. |
| An external map or weather widget | If you want weather on the wall display, proxy it server-side so browsers never contact a third party directly, and cache aggressively. |
| Avatar images from Gravatar | Local uploads or generated initials. |

Enforce it with `Content-Security-Policy: default-src 'self'`. A CSP that blocks
third-party origins converts a policy into a mechanism, and mechanisms survive
temptation on a Friday evening.

Outbound connections from the server should be enumerable on one hand: Let's Encrypt,
the container registry, the backup target, Apple's and Google's push endpoints (for web
push), and the OS package mirrors.

### T8 — a curious nine-year-old

- Guardian actions behind a 6-digit PIN, entered on a keypad with no visible echo.
- Enter it out of sight where practical; assume it will eventually be observed anyway.
- The audit log means escalation is at worst noticed. That is a proportionate response
  to a proportionate threat.

## Application-level practice

- **Validate at every boundary** with Zod: HTTP handlers, MCP tool inputs, job payloads.
  Parse into typed values; never pass raw request bodies into service functions.
- **Parameterised queries only.** Drizzle does this by default; the risk is the one hand-
  written query someone adds later under time pressure.
- **Household scoping is a repository concern**, not a per-query discipline, with
  PostgreSQL row-level security behind it as a second net.
- **Authorisation in the service layer, never in the UI.** Hiding a button is a courtesy;
  the check happens server-side, always.
- **No secrets in the client bundle.** Only `PUBLIC_` prefixed variables cross that line,
  and review what they are before each release.
- **Escape on output.** Svelte escapes by default; the danger is `{@html}`. Treat every
  use of it as requiring a comment explaining why it is safe.
- **Uploads** (avatars, recipe photos): validate the magic bytes rather than the
  extension, re-encode server-side, cap the size, and serve from a path that cannot
  execute anything.
- **Rate limit** login, PIN entry, feed fetches and the MCP endpoint at the proxy.

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
- [ ] Postgres not reachable from outside the Docker network
- [ ] TLS working on both hostnames; HSTS present
- [ ] Content-Security-Policy set, and verified to break nothing
- [ ] No third-party origin loaded by any page (check the network tab with a clear cache)
- [ ] Every secret in `.env`, mode 600, not in git; a copy in the password manager
- [ ] Nightly backup running, dead-man's switch configured
- [ ] **A restore performed successfully at least once** — date: ____________
- [ ] Device revocation tested from a second device
- [ ] Feed token revocation tested against a real Outlook subscription
- [ ] PIN lockout tested
- [ ] `npm audit` clean, or every finding consciously accepted
- [ ] Audit log written for a sample of every mutation type
