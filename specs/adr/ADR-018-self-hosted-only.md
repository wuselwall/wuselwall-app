# ADR-018 — Self-hosted only: the app connects to any WuselWall server, and there is no WuselWall Cloud

**Status:** Accepted · 2026-10-13 · Supersedes [ADR-015](ADR-015-saas-and-self-hosted-flavours.md)
except its decisions 6 (public store listings) and 7 (no captcha), which stand; amends
[ADR-013](ADR-013-one-self-hosted-environment.md) (its "one environment" holds for good),
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
keep them for the family's own server only.

Most of the separation already exists. The app talks only to `api` views, `api` functions,
Edge Functions, Supabase Auth and Realtime, never to a table. Its backend is two values in
an env file. `supabase/` deploys unchanged to any Supabase stack. ADR-015 had already
specified the discovery document and the server field. What was missing is a store app
with **no** default backend, and a project that runs no service for other families.

## Decision

1. **The project runs no service that holds another family's data.** It publishes the
   app (App Store, Google Play), the server (this repository's `supabase/`, the compose
   stack in `infra/`, a matching web build), the website and the documentation. The only
   backend it runs is the family's own (`api.wuselwall.app`, the homeserver stack). That
   server stays in `code` mode for good: nobody founds a household there without a
   founder code from its operator, and it is not offered to anyone.

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
   - **native Apple and Google, and passkeys:** only on the first-party hosts compiled into
     the app (`WW_FIRST_PARTY_HOSTS`: `api.wuselwall.app`, and `wusel.example.org` while the
     bridge lives). The reason is ADR-015's decision 4, with the family's server in
     Cloud's place: an ID token addressed to our app, handed to a hostile server, could be
     replayed to the family's server. Passkeys also need the server's domain in the app's
     associated domains. The user decided on 2026-10-13 to keep native sign-in for the
     family. The store app therefore contains Google's sign-in library, and the privacy
     policy names it (see Consequences).

7. **Each server serves its own web app,** the build of the same release, so it can never
   be out of step with its database. The compose stack gets a static container for it.
   `web.wuselwall.app` is the family server's web app, as today, and the public website
   no longer links to it. The project runs no web app that connects to arbitrary servers.

8. **The links site stays on the home server** (`wuselwall.app`, [ADR-017](ADR-017-wuselwall-app-domain.md)).
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
   with a NAS, not for a developer. Templates for homeserver Community Apps, Umbrel or YunoHost
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
because of the replay in decision 6. A hostile server could sign in as its users on the
family's server, or on any other server that accepted our IDs.

**No Apple and Google at all.** This would be the simplest option, and the store app would ship no Google
library. Considered and not chosen (user, 2026-10-13): the family keeps the convenience on
its own server. Revisit if the store privacy label or App Review makes it a burden.

**A backend-neutral API, so that other implementations could serve the app.** Rejected.
Re-implementing PostgREST, GoTrue and Realtime semantics is a protocol project with no
audience. Portability across Supabase hosting already covers "any backend" for families.

**One central web app (`web.wuselwall.app`) that connects to any server.** Rejected:
version skew with every server, and the project's host in every family's path.

## Consequences

**Positive**

- No other family's data ever sits on the project's infrastructure. The privacy policy
  covers the website, the apps, the stores and the sign-in providers, and it says plainly
  that the app's data goes to the server the household chose. Each operator is the
  controller for their own server.
- No Supabase bill. The ≈ €8–12/month of [10](../10-deployment-and-ops.md#costs) is the
  whole cost again (NFR-7), and there is one environment holding real data, as in ADR-013.
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
- **The store app carries Google's iOS sign-in library** for one family's server. Its
  privacy manifest declares name, email, user ID, device ID and usage data. Device ID and
  usage data are declared for analytics (Google's), and none of it for tracking. Apple's
  sign-in is part of iOS and adds nothing. The App Store privacy label and Google's Data
  safety form must reflect this, and the privacy policy says it.

**Revisit if** families who cannot run a server ask for hosting in numbers. The answer
would then be a third party that runs servers (a co-operative, an association), not the
project. Revisit also if the Google library outweighs the convenience it buys one family.
