# ADR-015 — Two flavours: WuselWall Cloud on hosted Supabase, and self-hosted

**Superseded 2026-10-13 by [ADR-018](ADR-018-self-hosted-only.md):** there is no WuselWall
Cloud; the store app has no default server and connects to any self-hosted one. Decisions 6
(public store listings) and 7 (no captcha) stand; decision 4's replay argument carries over
with the first-party servers in Cloud's place.

**Status:** Superseded · 2026-10-11 · amended [ADR-010](ADR-010-flutter-and-self-hosted-supabase.md),
[ADR-011](ADR-011-native-distribution-and-ci-cd.md) and
[ADR-014](ADR-014-self-service-onboarding.md); answered Q40, Q42 and Q44 in
[14](../14-open-questions.md) · *Condensed 2026-10-14 to what it decided; the full text
described one operator's server and is not kept in the repository.*

## Context

ADR-014 opened sign-up to other families and left open where their households live (Q40).
On 2026-10-11 the user answered:

> When it comes to hosting there is the self-host flavor […] but there should also be the
> option to use a SaaS via Supabase, which I will own as an account. If we will ever charge
> for that is another story. […] We will roll out the app in the Google and App Store once
> we have the Android dev account and Apple developer account. No captcha. […]

## Decision

1. **Two flavours from one codebase.** *WuselWall Cloud*: one hosted Supabase project in the
   user's own organisation (Frankfurt, Pro plan) holding every self-service household.
   *Self-hosted*: the Supabase stack on anyone's own server.
2. **The store apps connect to WuselWall Cloud by default**, from `app/env/cloud.json`.
3. **The same store app can use a self-hosted server** through a quiet "Eigener Server"
   entry and `https://‹host›/.well-known/wuselwall.json`; invitation and pairing links carry
   the server.
4. **Native Apple and Google sign-in and passkeys only against WuselWall Cloud** and a short
   list of first-party servers compiled into the app (`WW_FIRST_PARTY_HOSTS`). Tokens they
   issue are addressed to *our* app, so any server that accepted them could replay them to
   Cloud. Other servers get email code and password, plus Apple or Google through the web
   redirect with their operator's own clients.
5. **Environments:** CI's throwaway stack, the self-hosted stack used for development and
   testing, and Cloud for every self-service household; migrations CI → self-hosted → Cloud.
6. **Distribution: public App Store and Google Play listings** once the developer accounts
   exist; TestFlight and the Play internal track remain the pre-release channels.
7. **No captcha**, on either flavour.
8. **Domain:** a temporary address until the final one (decided in
   [ADR-017](ADR-017-wuselwall-app-domain.md)); the links site is static and separate from
   any backend.

## Alternatives considered

**SaaS only.** Rejected: a self-hosted flavour keeps the most private option open.

**Separate self-hosted builds** (own bundle ID, own signing). Rejected: almost no family can
sign and distribute an iOS app.

**Native Apple/Google sign-in on every server**, by publishing our client IDs. Rejected for
the replay in decision 4.

## Consequences (as they were)

- Cloud would have made the project a controller of strangers' data, with a bill, a DPA and
  uptime duties. [ADR-018](ADR-018-self-hosted-only.md) drops it for exactly that reason.
