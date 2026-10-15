# ADR-018 — Self-hosted only: the app connects to any WuselWall server, and there is no WuselWall Cloud

**Status:** Accepted · 2026-10-13 · Built 2026-10-14, see the [amendment](#amendment-2026-10-14-built) (decision 8's links and decision 10 are open) · Supersedes [ADR-015](ADR-015-saas-and-self-hosted-flavours.md)
except its decisions 6 (public store listings) and 7 (no captcha), which stand; amends
[ADR-013](ADR-013-self-hosted-compose-stack.md) (one landscape per server),
[ADR-014](ADR-014-self-service-onboarding.md) (households live on self-hosted servers only),
[ADR-016](ADR-016-public-website.md) and [ADR-017](ADR-017-wuselwall-app-domain.md) (the links
site stays where it is); answers [Q40](../14-open-questions.md) anew and opens Q47 and Q48

## Context

ADR-015 planned two flavours: *WuselWall Cloud*, a hosted Supabase project in the user's
account and the store app's default, and self-hosted servers reached through "Eigener
Server". Cloud was never created. On 2026-10-13 the user wrote:

> Also in general I think we should refrain from using a hosted variant of the app.
> Is it possible to separate the frontend from the backend in a way, that the
> frontend/app can be plugged into ANY self-hosted backend? So ONLY self-hosted. No
> hosted SaaS from our side?

Asked how native Apple and Google sign-in should behave without Cloud, the user chose to
keep them for first-party servers only.

Most of the separation already exists. The app talks only to `api` views, `api` functions,
Edge Functions, Supabase Auth and Realtime, never to a table. Its backend is two values in
an env file. `supabase/` deploys unchanged to any Supabase stack. ADR-015 had already
specified the discovery document and the server field. What was missing is a store app
with **no** default backend, and a project that runs no service for other families.

## Decision

1. **The project runs no service that holds another family's data.** It publishes the
   app (App Store, Google Play), the server (this repository's `supabase/`, the compose
   stack in `infra/`, a matching web build), the website and the documentation. It offers
   no server to anyone.

2. **"Any self-hosted backend" means any Supabase stack that runs a WuselWall server
   release.** That can be one's own hardware, a rented VPS, or one's own Supabase project.
   The portability rule (no superuser rights, no self-hosted-only features without a
   note in ADR-013) stays, because operators who choose hosted Supabase for *their*
   household are self-hosting in this sense. The contract between app and server is the
   `api` schema, the Edge Functions, Supabase Auth and Realtime, and the discovery
   document. It is not a protocol for a different backend to re-implement.

3. **The store app has no default server.** The front door asks which server to use,
   and offers three ways to answer:
   - **open an invitation or pairing link.** The link carries the server, so whoever is
     invited never types it;
   - **scan the server's QR code.** The install script prints it, and a guardian's
     Settings shows it;
   - **type the address.**

   The app reads `https://‹host›/.well-known/wuselwall.json`: Supabase URL, publishable
   key, `api_version`, `min_app_version`, the enabled sign-in methods, the
   household-creation mode and a `features` list. It keeps one server per installation.
   A device belongs to one household anyway. Changing the server signs out and clears
   the local cache and outbox. Development builds keep `env/dev.json` and may skip the
   question.

4. **A demo mode on the front door** ("Ohne Server ausprobieren"): the in-memory demo
   (`main_demo.dart`) with the reference household. It lets a family see WuselWall before
   anyone installs a server. It is also what App Review uses, because no server of ours
   may take strangers (decision 1). Demo data never leaves the device.

5. **Apps and servers update independently, so compatibility is a rule, not luck.** The
   server's `api_version` is an integer, raised by any migration that changes the
   contract. Each app release supports the current `api_version` **and the one before
   it**, and it hides what a server lacks through `features`. A server outside that
   window gets a plain message ("Dieser Server braucht ein Update auf WuselWall ‹x›"), and
   `min_app_version` works the other way round. CI runs the integration test against the
   previous server release as well as the current one. The forward-only, previous-app-
   compatible migration rule in CLAUDE.md stays.

6. **Sign-in is per server, from its discovery document:**
   - **always:** email and password, invitations and device pairing;
   - **email code:** when the operator configured SMTP. A server without it creates
     accounts with a password and an unconfirmed address. Founder codes and invitations
     are what keep strangers out there ([Q48](../14-open-questions.md));
   - **Apple and Google through the web redirect:** when the operator registered their own
     clients. Those tokens are addressed to the operator, not to us;
   - **native Apple and Google, and passkeys:** only on the first-party hosts named at
     build time (`WW_FIRST_PARTY_HOSTS`, a CI secret). The reason is ADR-015's decision
     4: an ID token addressed to our app, handed to a hostile server, could be replayed to
     a first-party server. Passkeys also need the server's domain in the app's associated
     domains. The user decided on 2026-10-13 to keep native sign-in for first-party
     servers. The store app therefore contains Google's sign-in library, and the privacy
     policy names it (see Consequences).

7. **Each server serves its own web app,** the build of the same release, so it can never
   be out of step with its database. The compose stack serves it. The public website does
   not link to any server's web app, and the project runs no web app that connects to
   arbitrary servers.

8. **The links site stays on `wuselwall.app`** ([ADR-017](ADR-017-wuselwall-app-domain.md)).
   The move to Cloudflare Pages existed only for Cloud. Because the site now carries
   links to servers it does not run, **secrets and server addresses travel in the
   fragment**: `https://wuselwall.app/i/#‹token›@‹host›` (the same for `/p/`). Browsers do
   not send the fragment, so the token and the address stay out of the website's logs and
   out of Cloudflare. The landing page reads the fragment in the browser, and the app
   receives the whole URL as a universal link or App Link.

9. **A server release is a product.** Each tagged release on GitHub ships the migrations,
   the Edge Functions, the web build, the compose override and the operator scripts
   (install, migrate with a backup point, update, show the QR code). These generalise
   today's `scripts/remote-*.sh`. The self-hosting guide in `docs/` is written for a parent
   with a NAS, not for a developer. Templates for NAS app stores, Umbrel or YunoHost
   come later, if families ask.

10. **Push notifications** (M1.6) need an answer before they are built
    ([Q47](../14-open-questions.md)). APNs and FCM accept pushes only from holders of
    the app's credentials, which are the project's, not an operator's.

## Alternatives considered

**Keep ADR-015's Cloud.** This would give the smoothest start for families without a server.
Rejected by the user. It also makes the project a controller of strangers' data: a DPA,
a record of processing, a breach procedure, uptime duties and a monthly bill. None of that
fits a family project.

**Separate app builds per operator.** These would need no server field and raise no token
question. Rejected, as in ADR-015: almost no family can sign and distribute an iOS app.

**Native Apple and Google for every server, by publishing our client IDs.** Rejected
because of the replay in decision 6. A hostile server could sign in as its users on any
other server that accepted our IDs.

**No Apple and Google at all.** This would be the simplest option, and the store app would ship no Google
library. Considered and not chosen (user, 2026-10-13): first-party servers keep the
convenience. Revisit if the store privacy label or App Review makes it a burden.

**A backend-neutral API, so that other implementations could serve the app.** Rejected.
Re-implementing PostgREST, GoTrue and Realtime semantics is a protocol project with no
audience. Portability across Supabase hosting already covers "any backend" for families.

**One central web app that connects to any server.** Rejected:
version skew with every server, and the project's host in every family's path.

## Consequences

**Positive**

- No other family's data ever sits on the project's infrastructure. The privacy policy
  covers the website, the apps, the stores and the sign-in providers, and it says plainly
  that the app's data goes to the server the household chose. Each operator is the
  controller for their own server.
- No Supabase bill. The ≈ €8–12/month of [10](../10-deployment-and-ops.md#costs) is the
  whole cost again (NFR-7).
- The opening gate in [13](../13-roadmap.md) no longer opens an instance. It becomes "the
  self-hosting kit is ready for other families".

**Negative**

- **A family needs a server**, or a friend with one. That narrows the audience a great
  deal. The install script, the QR code and the guide carry the onboarding that Cloud
  would have made invisible.
- **Version skew is permanent.** Store apps update on their own, while servers update when
  their operators get round to it. Decision 5 costs a second integration run in CI and
  discipline in every contract change.
- **The front door gets a step** (which server?) for everyone who does not arrive through
  a link.
- **Most servers have plainer sign-in:** email and password, plus a code if their operator
  set up mail.
- **Push needs its own answer** (Q47). Every option is either a small service the project
  runs, or weaker notifications.
- **The store app carries Google's iOS sign-in library** for the first-party servers. Its
  privacy manifest declares name, email, user ID, device ID and usage data. Device ID and
  usage data are declared for analytics (Google's), and none of it for tracking. Apple's
  sign-in is part of iOS and adds nothing. The App Store privacy label and Google's Data
  safety form must reflect this, and the privacy policy says it.

**Revisit if** families who cannot run a server ask for hosting in numbers. The answer
would then be a third party that runs servers (a co-operative, an association), not the
project. Revisit also if the Google library outweighs the convenience it buys one family.

## Amendment 2026-10-14: built

What exists now, decision by decision, and where it differs from the text above.

- **3 (no default server).** The discovery document is built by the Edge Function
  `server-info` (`supabase/functions/_shared/server_info.ts`) from `api.server_info()` and
  Auth's public settings, so **every** server serves it at `/functions/v1/server-info`,
  needing no file and no domain of its own. `/.well-known/wuselwall.json` is a proxy rewrite
  to that function wherever a server has a front of its own (the Caddy layer, nginx). The app
  tries the `.well-known` path first, then the function (`core/server/server_discovery.dart`).
  This is what makes a hosted Supabase project a complete server: the address
  `https://<id>.supabase.co`, or just the 20-letter project ID, is all a family types. The
  server's QR code is in Settings → Server and on the web front door ("Continue on your
  phone"); the enrolment QR carries `server=` too, so a fresh device joins with one scan.
  The chosen server lives in secure storage (`ServerStore`); Settings → Change server (a
  guardian action) empties the local store and signs the device out. A build with
  `SUPABASE_URL` (development) never asks. A store build that finds a session but no stored
  server, because it was updated from a build with a server compiled in, keeps the first
  first-party host.
- **4 (demo).** Built: "Try it without a server" runs the docs' in-memory household
  (`lib/demo/demo_overrides.dart`) under a banner with a way out.
- **5 (compatibility).** `api.server_info()` returns `api_version` 1 and `min_app_version`
  1.0.0. The app checks both when a server is chosen and again in the background at every
  start, and stops with a plain message at a server outside its window. Not built yet: the CI
  run against the previous server release.
- **6 (sign-in per server).** The discovery document reports Apple and Google from Auth's
  settings; the app offers them through the server's redirect. The native sheets and
  passkeys need the server's host in `WW_FIRST_PARTY_HOSTS`, a build-time define that CI
  supplies from a repository secret (masked in the public logs); no committed file names a host.
- **7 (each server serves its web app).** A server release carries one web build without a
  server; it reads the discovery document at its own origin, and asks otherwise. The Caddy
  layer serves it next to the API.
- **8 (links with the server in the fragment).** Only the parsing exists: the app reads
  `…/p/#CODE@host` and `…/i/#…@host` when typed or scanned. Universal links and App Links,
  their `.well-known` files and the landing pages are open; they need the store listings'
  signing details.
- **9 (a server release is a product).** `scripts/build-server-release.sh`, published by
  `.github/workflows/server-release.yml` on a tag `server-v<version>`. Inside: the stack
  (Supabase's compose file, WuselWall's layer, a lean layer that switches off Storage,
  imgproxy, Studio and meta, an optional Caddy layer), the functions, the migrations, the web
  build and `server/wuselwall`, which installs (secrets from a portable `make-env.mjs`, the
  jobs, a setup token), updates with a backup first, backs up and restores. The scheduled jobs run
  inside the database with pg_cron and pg_net (`infra/jobs/schedule.sql`), so a server needs
  no host cron.
- **New: hosted Supabase without tools.** `.github/workflows/deploy-supabase.yml` runs in a
  family's fork with their own secrets: migrations, Data API and Auth settings through the
  Management API, functions, the jobs, the setup token, and optionally the web app on the
  fork's GitHub Pages. The project still runs nothing (decision 1).
- **10 (push).** Open, as before.

**Considered and not taken:** an installer inside the app that creates the family's Supabase
project through Supabase's OAuth and Management API. Supabase's OAuth apps need a client
secret, which only a service run by the project could keep, against decision 1. Revisit if
Supabase offers public (PKCE-only) clients. Managed hosts that run the Supabase stack for a
customer, some of them in the EU, can serve a WuselWall server like any Supabase stack; none
is tested, and the docs name none.

**Release order:** the store builds switch to `app/env/store.json` (no server) only after the
first-party servers serve `server-info`; otherwise an updated device finds no discovery
document and has to be pointed at its server by hand.

