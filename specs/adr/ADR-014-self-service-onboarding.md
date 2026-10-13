# ADR-014 — Self-service households; adults sign in with Apple, Google or email

**Status:** Accepted · 2026-10-11 · Amends [ADR-004](ADR-004-identity-model.md) (adult
accounts, device enrolment), [ADR-010](ADR-010-flutter-and-self-hosted-supabase.md#identity-on-supabase-auth)
(public sign-up), [ADR-011](ADR-011-native-distribution-and-ci-cd.md) (public
distribution before opening) and [ADR-013](ADR-013-one-self-hosted-environment.md)
(further tenants); reverses the multi-tenancy non-goal in [01](../01-vision-and-scope.md).
The experience is specified in [20 — Onboarding](../20-onboarding.md). Amended by
[ADR-015](ADR-015-saas-and-self-hosted-flavours.md) on 2026-10-11: households live on
*WuselWall Cloud* or a self-hosted server; native Apple/Google sign-in only on Cloud; no
captcha; public store listings.

**Amended 2026-10-13 by [ADR-017](ADR-017-wuselwall-app-domain.md):** the links domain is decided — `wuselwall.app` ([Q45](../14-open-questions.md)).

## Context

M0.1 built onboarding for exactly one household run by its own developer:

- a setup token printed on the server and typed into the app;
- an email address and a password for each guardian, created by the wizard;
- no public sign-up and no outbound mail;
- shared devices enrolled with a code generated on a parent's phone and typed on the new
  device.

That fits a developer-operator. For anyone else it is a wall, and even in this household
it has rough edges. The second parent needs an account someone else created with a
password someone else chose. A lost password can only be recovered in Studio on the home
network (the gap noted in [13](../13-roadmap.md#m16-launch)). The PIN is asked for
before anyone knows what it is for.

On 2026-10-11 the user asked:

> Check all specs about the onboarding experience and iterate on it and improve it, so
> it is as smooth as possible. Include these social login providers: Apple & Google (no
> Facebook, etc). Allow email signup flow with one time passwords, but also allow normal
> passwords, etc.

and, asked whether sign-up means "invited adults of this household" or "any family can
create its own household", chose **self-service households**.

## Decision

1. **Public sign-up for adults.** Four ways in, and no others:
   - **Sign in with Apple**: native on iOS/iPadOS, OAuth redirect elsewhere.
   - **Sign in with Google**: native on Android and iOS, OAuth redirect on the web; scopes
     `openid email profile` only.
   - **Email with a 6-digit one-time code**: sign-up, sign-in and password reset in one
     flow.
   - **Email and password**: chosen right after the first code, so every password belongs
     to a verified address.

   Passkeys remain an optional extra in Settings. No Facebook, Microsoft, SMS or magic
   links. Sign-up and sign-in are one screen.
2. **Any adult without a household can create one**, behind an instance setting:
   - `household_creation = 'code'` (the default) also requires a single-use founder code
     from the operator, which is the setup token, generalised;
   - `'open'` is self-service.

   The switch is flipped when the opening gate in
   [13](../13-roadmap.md#opening-to-other-households) is passed. One household per account
   in v1.
3. **Other adults join by invitation**: a link, an 8-character code or a QR code, bound
   to a profile and a role, valid 7 days, single use, revocable. If the inviter gives the
   invitee's email, the invitation is matched to that verified address automatically.
   Every guardian is notified when someone joins.
4. **Shared devices pair the other way round.** The new device shows a code and a QR; a
   guardian approves it on their phone and chooses its kind there. The display code alone
   grants nothing: the guardian's approval binds it, and only the requesting device's
   secret collects the credentials. The M0.1 code entry stays for one release, then goes.
5. **Defer everything deferrable.** Timezone, language, names, colours and device names
   are inferred. The guardian PIN is set when the first shared device is connected.
   Avatars, a second factor, passkeys and push permission come from a household-shared,
   data-derived getting-started card, never from a tour.
6. **A second factor is optional and never part of sign-up.** Apple and Google accounts
   bring their own; an email-code account is as strong as its mailbox. TOTP stays
   available in Settings. A co-guardian can reset another guardian's factor.
7. **Leaving is built in**: delete account, leave household, delete household (14-day
   restore window) and export data, all from inside the app. Apple tokens are revoked on
   deletion.
8. **All households share one Supabase project.** Isolation is the RLS that already scopes
   every row by `household_id` and is already tested for the cross-household case. This
   replaces ADR-013's "one hosted project per further tenant", which cannot work with
   self-service. *Where* that one project runs is [Q40](../14-open-questions.md).
   *Answered by [ADR-015](ADR-015-saas-and-self-hosted-flavours.md): WuselWall Cloud, a
   hosted Supabase project in the user's account. Self-hosted servers each hold their own
   households and are reached from the same app.*
9. **Auth email is localised** through a send-email hook (with a bilingual template on
   self-hosted stacks that do not run Edge Functions). Its SMTP provider is [Q41](../14-open-questions.md)
   (decided: Scaleway Transactional Email).

## Alternatives considered

**Invited adults only, one household per deployment.** Everything in this ADR except
self-service: social login, email codes, invitations and pairing for this family, with
the setup token kept. Smaller and keeps the vision's non-goal. Not chosen: the user
wants other families to be able to start on their own. It survives as the `code` mode,
which is exactly this until the gate opens.

**One Supabase project per household (ADR-013's plan).** The strongest isolation, and
no shared database to get wrong. Rejected for self-service: a project per sign-up cannot
be created from inside an app, and the app ships with one backend URL. The
cross-household RLS tests carry the isolation instead, as they were written to.

**Magic links instead of codes.** One tap instead of six digits, and Supabase's default.
Rejected because the link opens in the mail app's browser, often on another device, and
cannot sign in the laptop when the mail is read on the phone. Codes work everywhere and
can be autofilled.

**Passwordless only (no passwords).** Fewer flows and no password storage. Rejected: the
user asked for passwords, some adults expect them, and App Review needs a demo account it
can sign in to without access to an inbox.

**Password at sign-up with a confirmation link (Supabase's default sign-up).** It creates
an unconfirmed account and needs a second round trip through the mailbox. Its error
behaviour either leaks which addresses are registered or confuses people who already
have an account. Rejected for "code first, then choose a password".

**Mandatory TOTP for guardians** (as [11](../11-security-and-privacy.md) used to say). It
adds a third app to every guardian's onboarding, it duplicates what Apple and Google
already enforce, and a lost authenticator locks out a sole guardian. Rejected as a
default; offered as an option.

**Keep enrolment codes typed on the new device.** Already built. Rejected because it puts
typing on the one device where nobody should type, and because a code read over a
shoulder can be redeemed by anyone within ten minutes. Reverse pairing fixes both.

**A third-party deferred-deep-link service** (Branch, Adjust, Firebase Dynamic Links'
successors) so that an invitation survives installation. Rejected under NFR-9. The email
match and the typed code cover the same ground without a tracker.

**Captcha on sign-up (hCaptcha, Turnstile).** Supported by Supabase Auth, and the usual
answer to sign-up abuse. Deferred ([Q44](../14-open-questions.md)): it is a third party in
the sign-up path (NFR-9), awkward in native apps, and rate limits plus `code` mode are
enough until abuse is observed. *Rejected outright by the user on 2026-10-11.*

## Consequences

**Positive**

- A family can start in under two minutes without anyone touching a server. The second
  parent joins in under one. The wall display and the children's iPads are set up
  without typing on them.
- Account recovery exists without the operator: the email code resets a password, and a
  co-guardian resets a lost second factor. This closes the M1.6 recovery gap.
- The setup token stops being a secret in a seed file (S3 in [19](../19-security-and-architecture-review.md)):
  in `code` mode a founder code is single use and issued on demand.
- This household benefits first: it is set up at M1.6 through the same flow every other
  family will use, so that flow is exercised by real people before strangers see it.

**Negative**

- **The app is no longer only this household's.** Once open, the operator is a data
  controller under GDPR for other families' data, children's data included, with a
  privacy policy, records of processing, processor agreements, deletion and export, and
  breach duties ([11](../11-security-and-privacy.md#privacy-and-legal)). The household
  exemption the plan relied on ends at the gate.
- **The vision's simplification is gone.** "Do not leave room for multi-tenancy" was
  deliberate. The data model always carried `household_id` and RLS always scoped by it,
  so the queries do not change. What changes is that a cross-household bug becomes a
  breach of a stranger's data, so the cross-household tests become release-blocking in
  every sense.
- **Three more parties**, for adults who choose them: Apple and Google learn that the
  person uses WuselWall, and an SMTP provider sees email addresses and codes. These are
  accepted exceptions to NFR-9, listed in [11](../11-security-and-privacy.md#t7--third-parties-the-data-not-harvested-requirement).
- **More moving parts to operate:**
  - the Apple client secret is a JWT that **expires every six months** and must be
    regenerated;
  - the Google OAuth clients;
  - SMTP with SPF, DKIM and DMARC;
  - static files and landing pages on the domain;
  - rate limits that matter now.
- **Public distribution becomes necessary** before strangers can install the app.
  TestFlight internal testing and the Play internal track do not reach them
  ([Q42](../14-open-questions.md)), which reverses the "no public store listing" non-goal
  at the gate. *Decided by ADR-015: public App Store and Google Play listings.*
- **The domain becomes hard to change.** Universal links, the passkey relying-party ID
  and every invitation link are bound to it. Pick the final domain before the gate
  ([Q45](../14-open-questions.md); `wusel.example.org` until then).
- `app.create_auth_user`, which writes the `auth` schema directly, now serves pairing as
  well as enrolment. Its portability caveat in ADR-013 applies twice.
- **A narrow exception to the service-role rule** ([03](../03-architecture.md)):
  `account-delete` and the MFA reset need the Auth Admin API although they have a user.
  They verify the caller's JWT first and act only on that account (or, for the reset, on
  a co-guardian of the same household), and each use is commented.

**Revisit if** a stranger's household is ever exposed to another household (stop
sign-ups at once, `code` mode). Also revisit if the operator does not want to carry the
controller's duties: the gate is the point to decide, and `code` mode is the permanent
fallback.
