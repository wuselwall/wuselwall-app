# ADR-017 — The domain wuselwall.app: website, web app and API on their own hosts

**Status:** Accepted · 2026-10-13 · Decides [Q45](../14-open-questions.md) · Supersedes the
"same origin" part of [ADR-016](ADR-016-public-website.md) and the public address in
[ADR-013](ADR-013-one-self-hosted-environment.md)

## Context

Everything lived under `https://wusel.goomba.ch`, a subdomain of the user's private domain:
the website at `/`, the Flutter web app at `/app/`, the documentation at `/docs/`, the APK
at `/download/` and the API under four prefixes. [Q45](../14-open-questions.md) asked which
domain other families see, and had to be answered before passkeys, invitation links,
universal links or App Links bind to one. On 2026-10-13 the user bought **`wuselwall.app`**
(Cloudflare DNS, records for the apex, `web.` and `api.` proxied to the home server) and
asked for three hosts:

| Host | Serves |
|---|---|
| `wuselwall.app` | The website (landing page, Impressum, Datenschutz, de/en), `/docs/` (user documentation), `/download/` (the Android APK); later the links site of [ADR-014](ADR-014-self-service-onboarding.md): `/.well-known/`, `/i/`, `/p/` |
| `web.wuselwall.app` | The Flutter web app, at the root (`--base-href /`) |
| `api.wuselwall.app` | The Supabase gateway of the home server's stack: only `/auth/v1/`, `/rest/v1/`, `/realtime/v1/`, `/functions/v1/`; everything else 404 |

## Decision

- **Three hosts, one nginx site file**,
  [`infra/nginx/wuselwall.app.conf`](../../infra/nginx/wuselwall.app.conf). TLS is a
  Cloudflare origin certificate for `wuselwall.app` and `*.wuselwall.app`, SSL mode
  **Full (strict)**, as for `goomba.ch`. The routes and the containers behind them do not
  change.
- **The web app and the API are different origins.** The gateway's CORS policy already
  allows any origin on the app's routes (only Studio's `/pg/`, which nginx never forwards,
  is restricted). The app sends its publishable key and the user's JWT as headers, never
  cookies, so no credentialed CORS is involved.
- **GoTrue:** `API_EXTERNAL_URL=https://api.wuselwall.app/auth/v1` (also the JWT issuer and
  the OAuth callback base), `SITE_URL=https://web.wuselwall.app/`,
  `https://web.wuselwall.app/**` in the redirect allow-list. The Apple Services ID and the
  Google web client must name `https://api.wuselwall.app/auth/v1/callback` as their return
  URL.
- **Passkeys bind to the registrable domain:** RP ID `wuselwall.app`, origin
  `https://web.wuselwall.app`. The website serves `/.well-known/apple-app-site-association`
  and `/.well-known/assetlinks.json` from the apex, so the native apps can use the same
  passkeys once their associated domains (`webcredentials:wuselwall.app`) are set up. No
  passkey existed when the RP ID moved (checked 2026-10-13), so nothing was lost.
- **Q45 is decided: `wuselwall.app`** is the domain other families see: invitation and
  pairing links (`https://wuselwall.app/i/…`, `/p/…`), universal links and App Links, the
  passkey RP ID, the sender domain of WuselWall Cloud's mail. WuselWall Cloud's API gets its
  own subdomain of `wuselwall.app` when Cloud is created; which name (and whether the
  family's server keeps `api.`) is decided then. *(2026-10-13, [ADR-018](ADR-018-self-hosted-only.md):
  there will be no Cloud; `api.` stays the family's server.)*
- **The old address stays as a bridge.** `wusel.goomba.ch` still forwards the four API
  prefixes, because the APK and the TestFlight builds installed today carry it; its pages,
  `/app/`, `/docs/` and `/download/` answer `301` to their new homes. The bridge is removed
  once every installed app is a build with `api.wuselwall.app` — a release on both
  platforms and a check of the gateway's log for requests with the old `Host`.
- **Unchanged:** the application and bundle ID `ch.goomba.wuselwall` and its deep-link
  scheme ([ADR-012](ADR-012-product-name.md)) — they are permanent once a store record
  exists; the mail sender of the home server, `goomba.ch`, verified with Scaleway, until a
  sending domain on `wuselwall.app` is set up.

## Alternatives considered

**Everything on `wuselwall.app` under paths, as on `wusel.goomba.ch`** ([ADR-016](ADR-016-public-website.md)).
One origin, no CORS, a host-only passkey RP ID. Rejected by the user: separate hosts keep
the website, the web app and the API apart for Cloudflare rules, caching and a later
move of any one of them (the website to Cloudflare Pages, the API to WuselWall Cloud),
and `api.` makes the backend's address obvious for self-hosters' documentation.

**Redirect the old API prefixes instead of forwarding them.** Simpler, but Dart's HTTP
client does not follow redirects for `POST`, and WebSockets never follow them: the
installed apps would break until updated.

## Consequences

- **The web app starts signed out once.** Browser storage belongs to an origin, so a
  browser that used `wusel.goomba.ch/app/` has no session on `web.wuselwall.app`: sign in
  or enrol that device again. The native apps keep their session across the update (the
  session is stored under a fixed key, not one derived from the URL).
- Native builds made before this change keep working through the bridge; builds after it
  use `api.wuselwall.app` (`app/env/dev.json`).
- Access tokens issued after the change carry the new issuer; nothing in the stack checks
  it, and refresh tokens stay valid.
- Deploys (`scripts/deploy-web.sh` builds with `--base-href /`) and documentation updated:
  [10](../10-deployment-and-ops.md), [16](../16-setup-plan.md), [03](../03-architecture.md).
