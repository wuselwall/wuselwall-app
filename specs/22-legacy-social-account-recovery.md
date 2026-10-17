# Legacy social-account recovery and retirement gate

Product decision for t_7d6fcf63, following the 2026-10-17 removal decision in
[00](00-brief-and-decisions.md). This is a policy and acceptance specification, not
proof that migration works. It does not restore social login as a supported feature.

## Decision: preserve identity; prove mail access before disabling providers

No account, identity, profile, membership or family data is deleted or recreated to
complete this change. No bulk email rewrite, guessed real email address, removal and
re-invitation, automatic identity linking or administrator-issued password is an
approved recovery mechanism. A family invitation is not proof of ownership of an Auth
account. Preserve existing sessions; do not force sign-out as a migration step.

The supported replacement for a legacy Google-only or Apple-only account is a fresh
email code to the **existing account address**, authenticating the same Auth user and
existing profile. Password setup/reset is subsequent functionality, not a workaround
for undeliverable mail. An already working password or passkey may permit access but
is not sufficient migration evidence while account deletion still needs email reauth.

- Reachable real address: verify the code flow on the pinned released Auth version
  with an existing provider-only identity, not a newly created email user. Do not claim
  recovery based on upstream master source. A failed lookup/code must not silently
  create a replacement account and strand the old profile.
- Apple private relay address: keep that address. The Apple developer-account owner
  must retain the relevant relay configuration and register/authenticate the actual
  outbound mail sources according to Apple's requirements; the user must retain
  forwarding. Registration alone is not delivery proof. The user can find the relay
  address in their Apple account's Sign in with Apple settings; do not ask them to
  substitute their ordinary Apple ID email address.
- Signed-out user: enter the existing real or relay address on the same server and
  request a code. The flow must restore the same user/profile without a prior app
  session or access to the removed provider callback. If delivery/forwarding cannot
  be restored, keep the affected server's upgrade on hold. Do not bypass ownership
  checks or promise an admin email-change tool that has not been designed and tested.
- Signed-in user: do not assume session survival proves future access. Explain the
  changed sign-in method before any voluntary sign-out. Verify fresh email access
  independently without deliberately invalidating their last working session.
- Stale-auth deletion: preserve the five-minute freshness rule and existing guardian
  safeguards. A fresh code must reauthenticate the same user before deletion retries
  once. Cancellation, wrong/expired code and mail failure must leave the account and
  household untouched. An unreachable relay therefore also blocks deletion readiness;
  do not remove freshness checks to make deletion appear to work.

If a user cannot recover their relay or has lost their mailbox, the release gate stays
closed for that server. A different identity-recovery/email-change mechanism would
need a separate security-reviewed product decision and implementation. This decision
chooses delay over an unverified account takeover or destructive workaround.

## Credential and external-client retirement

Disabling sign-in endpoints is distinct from destroying external credentials.

1. Disable Google/Apple authorization, ID-token sign-in and manual linking in running
   Auth configuration (including upgrades of hosted projects). Clear only obsolete
   OAuth callback allow-list entries; retain invitation/pairing destinations required
   by retained journeys. Explicitly retire deployed `apple-token`, not just its source.
2. Dedicated Google sign-in OAuth clients/secrets and unused callback registrations
   may be retired after disabled-entry-point and recovery tests pass, provided no
   other application uses them. Do not delete the Google project, Play publishing
   credentials, Calendar integration or unrelated API clients.
3. Remove Apple login-only configuration such as the GoTrue pre-generated login
   client secret and SDK settings. Do **not** revoke the underlying Apple signing key,
   delete an issuing App ID/Services ID or disable relay merely because sign-in is off.
   Any issuing client/key that legacy tokens or relay delivery still depend on stays.
   Unknown/shared dependencies mean retain and investigate, not delete.
4. Retain the account-delete revocation path, encrypted legacy tokens and the exact
   runtime variables `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`,
   `APPLE_CLIENT_ID`, `APPLE_TOKEN_KEY`. Preserve existing `APPLE_TOKEN_KEY`; changing
   it makes stored ciphertext unusable. Repository/operator aliases must continue to
   map to these runtime names; do not confuse login client secrets with these values.
5. Retirement requires explicit operator evidence that no remaining account needs
   relay delivery and all retained Apple tokens, including pending failed revocations,
   have been successfully revoked or otherwise conclusively resolved. A zero table
   count after cascading deletion is not evidence of successful revocation. Existing
   backups and their restore procedure must account for legacy tokens; do not casually
   destroy keys needed by a supported restore. No fixed date or automatic key deletion.
6. Candidate b0882e7 deletes the Auth user before attempting Apple revoke, logs
   decryption/revoke failures, and silently skips revocation with incomplete config.
   This does not prove revocation completed. The implementer must preserve a secure,
   retryable revocation obligation across failures (without blocking the user's
   account-deletion request on Apple's availability), or report this criterion FAIL.
   Never put plaintext refresh tokens in logs, reports or client responses.

## Required evidence before release

Implementation: existing remediation card t_7f156359, same draft PR #63. Incorporate
this policy, link the dated specs/00 amendment and update family/operator guidance in
German and English. Do not introduce a new account-recovery subsystem in this card.
Independent runtime verification: t_6ab1585e; fresh independent review: t_6ff81ad8;
operator relay attestation: t_99a9f4ed; final gate: t_73c0d66b.

On a disposable stack with pinned GoTrue v2.197.0 (or the exact explicitly changed
candidate pin), seed synthetic Google-only, Apple-real-email and Apple-relay-address
identities with existing profiles/memberships. Use the actual Auth/mail path, not
mocked repository success. Record exact candidate SHA, image version and commands.

- Exercise an upgrade from enabled provider configuration as well as fresh startup.
- Sign out synthetic users, receive and verify OTP, and assert the same user UUID,
  profile and memberships before/after; no duplicate user and no data loss.
- Test password setup/reset, existing password login, refresh of an existing session,
  retained J1/J2/J3 journeys and cross-account isolation.
- Test stale-auth deletion with fresh code, cancellation, wrong/expired code and
  unavailable mail. Assert no mutation before successful reauth and guardian checks.
- Exercise revocation success, missing configuration, decryption failure and upstream
  unavailability using a controlled Apple transport. Verify retained retry obligations;
  this is protocol/failure-handling evidence, not a claim of real Apple acceptance.
- Exercise former authorize, ID-token and linking endpoints and old callback URLs;
  none may start or complete social sign-in. Verify obsolete deployed function removal.
- Exercise relay-address routing to disposable mail and a failed-mail case. Mailpit
  can prove the application's handling of a relay-shaped address, **not** delivery
  through Apple's real relay. Say this explicitly in the report.

Separate operator pre-deployment gate: obtain a non-sensitive attestation that this
server has no affected relay accounts, or confirm controlled delivery through the
actual Apple relay and a usable fresh-code path for affected account owners. Agents
must not inspect a live household or collect addresses/tokens to provide this evidence.
If that attestation/evidence is unavailable, deployment stays on hold even if all
synthetic tests pass. No requirement to use real provider credentials in disposable QA.

## Evidence available at decision time

- Reviewed candidate identified by tasks as b0882e7 + docs 82a74f4, combined tree
  651cb214bfac782307215ce1b07cbfa693f0fb9d. This task inspected the named source commits;
  it did not execute Auth recovery, real relay delivery or account deletion.
- t_f851c0f6 reported 55 focused tests and a demo build passing, but explicitly did not
  test a disposable Auth/mail stack or legacy recovery. That result is not release proof.
- Source inspection of b0882e7 shows email-only stale-auth deletion and best-effort Apple
  revocation. Runtime recovery and failure-safe revocation remain acceptance work.
- Apple guidance: [configure private email relay service](https://developer.apple.com/help/account/capabilities/configure-private-email-relay-service)
  and [communicating using the relay](https://developer.apple.com/documentation/signinwithapple/communicating-using-the-private-email-relay-service).
  Official search excerpts confirm outbound-domain registration is required; page
  extraction was unavailable. Neither source proves this server's mail is deliverable.

Verdict: policy decided; release readiness **NOT PROVEN**. No live data accessed,
external credentials changed, code committed, PR merged or server deployed by this task.
