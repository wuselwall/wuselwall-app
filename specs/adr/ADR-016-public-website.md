# ADR-016 — A public website at the root; the Flutter web app moves to /app/

**Status:** Accepted · 2026-10-12 · Amends [ADR-013](ADR-013-one-self-hosted-environment.md)
(what nginx serves) and [ADR-014](ADR-014-self-service-onboarding.md) (the "links site")

## Context

`https://wusel.example.org/` was the Flutter web app. With public store listings
([ADR-015](ADR-015-saas-and-self-hosted-flavours.md)) the address needs a front door: a
marketing page that explains the product and sends visitors to the App Store, Google Play
or the web app, the legal pages stores and Swiss/German law require (Impressum,
privacy policy), and a link to the open-source repository. It has to be found by search
engines, so the content must be in the HTML the server sends.

## Decision

- **A separate website**, `website/`: Astro (v5) with the Node standalone adapter.
  Content pages are prerendered to HTML at build time and served by a small Node server in
  a container; `/healthz/` is rendered per request. German at `/`, English at `/en/`, with
  `hreflang`, canonical URLs, a sitemap, `robots.txt`, Open Graph tags and JSON-LD. No
  cookies, no third-party requests, no analytics (T7 in [11](../11-security-and-privacy.md)).
- **Same origin, new layout.** The site is `/`; the Flutter web app is `/app/` (built with
  `--base-href /app/`). One origin keeps passkeys (RP ID `wusel.example.org`) and the API
  prefixes untouched. `/#/route` links from before the move are forwarded to `/app/#/route`
  by a line on the landing page. GoTrue's `SITE_URL` becomes `https://wusel.example.org/app/`.
- **Its own compose project**, `infra/web`, beside `infra/supabase`. nginx proxies `/` to the
  container on the Docker bridge (`172.17.0.1:54480`), like the Supabase gateway.
- **Operator data in one file**, `website/src/config/site.ts`. A deploy
  (`scripts/remote-web.sh deploy`) builds with `LEGAL_STRICT=1`, which fails while any
  Impressum value is a `TODO`; until then the legal pages are `noindex`.
- **Store badges point at assumed listing URLs** until the apps are published.

## Alternatives considered

**The web app on a subdomain.** Cleanest separation, but a new origin: passkey origins,
CORS and redirect URLs change, and DNS, certificate and nginx need another host.

**Next.js or SvelteKit.** Both server-render, but ship more runtime for a page that is
almost entirely static. Astro sends no JavaScript the page does not need.

**Static files from nginx only** (like the planned `/i/` pages). Simplest to run, but the
user asked for server-side rendering and a container that can grow dynamic routes
(invitation landing pages, the deletion page) without another service.

**Cloudflare Pages.** [10](../10-deployment-and-ops.md) already plans to move the links
site there when Cloud goes live. The container keeps that option open: the build output in
`dist/client` is plain static files.

## Consequences

- Installed copies of the web app and bookmarks at `/` land on the landing page; the hash
  forward covers deep links, everything else is one tap on *Open web app*.
- Four things now deploy independently, each with its own script: the Supabase stack
  (`remote-stack.sh`), single services of it, the Edge Functions (`remote-stack.sh functions`),
  the Flutter web app (`deploy-web.sh`) and the website (`remote-web.sh`). See
  [10](../10-deployment-and-ops.md#updating-one-part).
- The privacy policy text is a sound starting point, not legal advice. Have it reviewed
  before the stores are opened to strangers.
