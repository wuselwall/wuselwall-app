# ADR-015 — Two flavours: WuselWall Cloud on hosted Supabase, and self-hosted

**Superseded 2026-10-13 by [ADR-018](ADR-018-self-hosted-only.md):** there is no WuselWall
Cloud; the store app has no default server and connects to any self-hosted one. Decisions 6
(public store listings) and 7 (no captcha) stand; decision 4's replay argument carries over
with the family's server in Cloud's place.

**Status:** Accepted · 2026-10-11 · Supersedes [ADR-013](ADR-013-one-self-hosted-environment.md)'s
"one environment" once the SaaS project exists (the rules for the home server stay);
amends [ADR-010](ADR-010-flutter-and-self-hosted-supabase.md),
[ADR-011](ADR-011-native-distribution-and-ci-cd.md) and
[ADR-014](ADR-014-self-service-onboarding.md); answers Q40, Q42 and Q44 in
[14](../14-open-questions.md)

**Amended 2026-10-13 by [ADR-017](ADR-017-wuselwall-app-domain.md):** the domain is decided — `wuselwall.app`; the family's homeserver stack is `api.wuselwall.app` (read it where this record says `wusel.example.org`).

## Context

ADR-014 opened sign-up to other families and left open where their households live
(Q40). On 2026-10-11 the user answered:

> When it comes to hosting there is the self-host flavor (which I personally do on my
> homeserver server for development and testing) but there should also be the option to use
> a SaaS via Supabase, which I will own as an account. If we will ever charge for that is
> another story.
>
> We will roll out the app in the Google and App Store once we have the Android dev
> account and Apple developer account. No captcha. Final public domain is not yet
> decided. For now we use wusel.example.org.

## Decision

1. **Two flavours from one codebase.** Everything in `supabase/` applies unchanged to
   both:
   - **WuselWall Cloud (SaaS):** one hosted Supabase project in the user's own Supabase
     organisation, region **Frankfurt (eu-central-1)**, on the **Pro plan** (Free projects
     pause when idle). All self-service households ([ADR-014](ADR-014-self-service-onboarding.md))
     live here. Whether it is ever charged for is out of scope here.
   - **Self-hosted:** the Supabase stack on anyone's own server. The user's homeserver stack
     is one, used for development and testing.
2. **The store apps connect to WuselWall Cloud by default.** Its URL and publishable key
   come from `app/env/cloud.json` (`--dart-define-from-file`, as every configuration
   does). Development builds keep `env/dev.json` (the homeserver stack).
3. **The same store app can use a self-hosted server.** The front door has a quiet
   "Eigener Server" entry. The founder of a self-hosted household types the server's
   address once. The app reads `https://‹host›/.well-known/wuselwall.json` (Supabase URL,
   publishable key, enabled sign-in methods, minimum app version) and remembers the
   server. Invitation and pairing links from a self-hosted household carry the server,
   so nobody else types it. The app shows the server's host on every sign-in screen that
   is not WuselWall Cloud.
4. **Native Apple and Google sign-in only against WuselWall Cloud.** The tokens they
   issue are addressed to *our* app identifiers, so any server that accepts them could
   also replay them to WuselWall Cloud and take over the person's account there. A custom
   server therefore gets **email code and password** in the app, plus Apple or Google
   **through the web redirect** only if its operator registered their own clients with
   Apple and Google. Their tokens are then addressed to the operator, not to us.
   Passkeys likewise only on WuselWall Cloud: the store app's associated domains cannot
   include a stranger's domain.
   **First-party servers are the exception.** A short list compiled into the app
   (`WW_FIRST_PARTY_HOSTS` in the env file: Cloud and `wusel.example.org`) names servers
   the user controls. They get native Apple/Google sign-in, and passkeys through the
   app's associated domains, like Cloud. The replay risk is the user's own server
   misbehaving towards the user's own Cloud, and that server already holds the family's
   data.
5. **Environments:**

   | Environment | Flavour | Purpose | Data |
   |---|---|---|---|
   | CI throwaway stack | self-hosted (CLI) | pgTAP, integration tests | none |
   | homeserver (`wusel.example.org`) | self-hosted, first-party | development, testing **and the family's household** ([Q46](../14-open-questions.md)) | the family's |
   | WuselWall Cloud | SaaS | every self-service household | strangers' |

   Migrations go CI → homeserver (`scripts/remote-migrate.sh`, as today) → Cloud
   (`supabase db push` against the linked project, after its own backup point). Edge
   Functions deploy to Cloud with `supabase functions deploy`, and to the home server with
   `scripts/remote-stack.sh deploy`.
6. **Distribution: public App Store and Google Play listings** once the developer
   accounts exist. This replaces internal-only distribution ([ADR-011](ADR-011-native-distribution-and-ci-cd.md))
   for the public app; TestFlight and the Play internal track remain the pre-release
   channels.
7. **No captcha**, on either flavour.
8. **Domain:** `wusel.example.org` for now; the final one is open ([Q45](../14-open-questions.md)).
   The **links domain** (universal links, landing pages, `/.well-known/`, privacy
   policy, deletion page) is a static site, separate from any backend, so that Cloud's
   links do not depend on the home server being up. It can stay on the homeserver nginx
   until Cloud goes live. From then on it runs on a static host (Cloudflare Pages), under
   `wusel.example.org` or the final domain.

## Alternatives considered

**SaaS only.** Simplest to support. Rejected: the user runs and wants to keep a
self-hosted flavour, and it is what keeps the most private option open to families who
want it.

**Separate self-hosted builds** (own bundle ID, own signing) for self-hosters, with the
store app fixed to Cloud. No server field and no token-relay question. Rejected: almost
no family can sign and distribute an iOS app, so the self-hosted flavour would exist
only on paper.

**Native Apple/Google sign-in on every server**, by publishing our client IDs for
self-hosters to configure. The smoothest for them. Rejected because of the token relay
in decision 4: a hostile server, or one that is merely compromised, could sign in to
Cloud as anyone who signed in to it.

**A Supabase project per household** (ADR-013's original idea). Rejected by ADR-014 for
self-service, and unchanged here.

**Hosting Cloud on the homeserver server.** No bill. Rejected: strangers' data and
availability in a family home, and the user chose hosted Supabase.

## Consequences

**Positive**

- Strangers' households live on managed infrastructure with backups, monitoring and
  upgrades that are not the user's evenings. The home server keeps only the family's
  household, next to development and testing.
- Edge Functions, the send-email hook and the account-deletion function deploy normally
  on Cloud with Supabase's own tooling.
- The self-hosted flavour stays real: the same store app, a typed address, email
  sign-in.

**Negative**

- **A bill:** Supabase Pro (≈ $25/month for the organisation, compute included for one
  small project), plus a custom domain add-on once the final domain is chosen (so that
  Apple's and Google's consent screens and the passkey relying party show our domain,
  not `‹ref›.supabase.co`). The ≈ €8/month of [10](../10-deployment-and-ops.md#costs) no
  longer covers the product. NFR-7 is per flavour from now on.
- **A US-headquartered processor** for Cloud's data. It is stored in Frankfurt, which
  meets NFR-8's EU residency, but it is the exposure ADR-010 avoided for this family. The
  family's own data stays on the homeserver stack ([Q46](../14-open-questions.md), decided
  2026-10-11).
  A DPA with Supabase is part of the opening gate.
- **Two schemas to keep in step**, and the store app must work against Cloud *and* any
  self-hosted server running the previous release. `min_app_version` in the discovery
  document is how a self-hosted server says "update first". Cloud is migrated first and
  self-hosters follow the release notes.
- **Self-hosted households get a plainer front door** (no native Apple/Google, no
  passkeys) unless their operator registers their own clients. This is documented in the
  self-hosting guide, not hidden.
- CLAUDE.md's "there is one environment" holds only until Cloud exists. From then on there
  are **two environments holding real data**, the family's on homeserver and strangers' on
  Cloud. Development and testing still happen next to the family's data, as ADR-013
  accepted, so the home server's safety rules stay for good. Cloud gets the same: no
  `db reset`, a backup point before `db push`, and never the integration test.

**Revisit if** Cloud's cost outgrows what the user wants to carry (that is when "if we
will ever charge" stops being another story), or if a self-hosted operator needs native
social sign-in badly enough to justify a per-server client registration flow.
