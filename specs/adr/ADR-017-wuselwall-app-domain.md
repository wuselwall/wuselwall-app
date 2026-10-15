# ADR-017 — The domain wuselwall.app for the website, the docs and the links

**Status:** Accepted · 2026-10-13 · Decides [Q45](../14-open-questions.md) · Supersedes the
"same origin" part of [ADR-016](ADR-016-public-website.md) · *Rewritten 2026-10-14 to
describe only what the project itself serves; servers live on their operators' domains
([ADR-018](ADR-018-self-hosted-only.md)).*

## Context

The website, the documentation and the Android download lived under a temporary address.
[Q45](../14-open-questions.md) asked which domain other families see, and had to be answered
before passkeys, invitation links, universal links or App Links bind to one. On 2026-10-13
the user bought **`wuselwall.app`**.

## Decision

- **`wuselwall.app` is the project's address:** the website (landing page, Impressum,
  Datenschutz, de/en), `/docs/` (user documentation), `/download/` (the Android APK until
  the Play listing), and the links site of [ADR-014](ADR-014-self-service-onboarding.md):
  `/.well-known/`, `/i/`, `/p/`.
- **Q45 is decided: `wuselwall.app`** is the domain families see in invitation and pairing
  links (`https://wuselwall.app/i/…`, `/p/…`), universal links and App Links. Since ADR-018
  those links carry their server in the fragment, so the site never learns it.
- **Passkeys bind to the registrable domain** `wuselwall.app` on first-party servers; the
  website serves `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json`
  from the apex, so the native apps can use the same passkeys once their associated domains
  (`webcredentials:wuselwall.app`) are set up.
- **Servers are not on this domain.** Each server lives on its operator's domain, or a
  hosted project's `<id>.supabase.co`, and serves its own web app.
- **Unchanged:** the application and bundle ID `ch.goomba.wuselwall` and its deep-link
  scheme ([ADR-012](ADR-012-product-name.md)) — permanent once a store record exists.

## Alternatives considered

**Everything under paths of one host** ([ADR-016](ADR-016-public-website.md)). One origin,
no CORS. Rejected: separate hosts keep the website and any web app apart for caching and a
later move of either.

## Consequences

- The web app and the API are different origins wherever a server uses two hosts. The
  gateway's CORS policy allows any origin on the app's routes; the app sends its publishable
  key and the user's JWT as headers, never cookies, so no credentialed CORS is involved.
- A browser keeps a web app's session per origin: moving a web app to a new host signs its
  browsers out once. The native apps keep theirs (the session is stored under a fixed key).
