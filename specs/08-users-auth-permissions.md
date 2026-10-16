# 08 — Users, Authentication & Permissions (B1)

Implements FR-5.1 – FR-5.18. Decision context: [ADR-004](adr/ADR-004-identity-model.md);
mechanism on Supabase Auth: [ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md#identity-on-supabase-auth)
(revised 2026-10-11 — the model is unchanged, the plumbing is new); sign-up, invitations
and pairing: [ADR-014](adr/ADR-014-self-service-onboarding.md), with the experience in
[20 — Onboarding](20-onboarding.md).

## Two layers of identity

The chosen model separates two questions that most apps conflate:

- **Which device is this?** Answered once, at pairing or sign-in, and then persistent for months.
- **Who is acting right now?** Answered by tapping an avatar, in under a second.

```
  Device session  (shared/kiosk: one Supabase Auth user per device;
                   personal: a session of the adult's own account;
                   refresh token in the platform's secure storage; revocable)
        │
        ├── class: personal → active profile is fixed (Papa's iPhone)
        ├── class: shared   → active profile chosen by tapping (kids' iPad)
        └── class: kiosk    → no active profile until someone taps (wall display)
                              reverts to "nobody" after 60 s idle
```

Guardian actions sit on a third layer: a **PIN step-up** that grants elevated rights on
that device for a short window.

## Say the trade-off out loud

Tap-to-switch means **the app cannot prove who did anything.** A nine-year-old can tap
his sister's avatar and tick off her chores, or his own, twice, or claim a bonus task he
did not do. There is no cryptographic answer to this, and the design should not pretend
otherwise.

This is very probably the right call anyway: password prompts on a kitchen wall display
are how family software dies. But it changes what the system is. **Attribution here is
cooperative bookkeeping, not authentication.** It records what people say they did so
everyone can see the same picture — the same trust model as a chore chart on the fridge,
which has worked in households for a century.

Four mitigations make that trust model workable rather than naive:

1. **Everything is visible.** The audit log records the acting profile *and* the device
   for every mutation, and the family board shows completions as they happen. Quiet
   cheating is not really available; the wall display announces it.
2. **The valuable actions are gated.** Approving a redemption, adjusting points, deleting
   another person's event and changing member settings all require a guardian PIN. A
   child can misreport a chore; a child cannot mint points or cash out.
3. **`requires_verification`** exists for the small set of tasks where the temptation is
   worth the friction. Use it on high-value bonus tasks only.
4. **Personal devices are honest by construction.** A parent's iPhone is `class='personal'`
   with a fixed profile, so adult actions are genuinely attributable, which is what
   matters for the audit trail.

If it later turns out that one child systematically games it, the escalation path exists
and is cheap: flip that child's iPad to a 4-digit PIN on profile selection. The data
model already supports it (`profile.pin_hash` is there for everyone), so this is a
settings change, not a rewrite.

## Roles

Two, and resist adding a third.

| Role | Can | Cannot |
|---|---|---|
| `guardian` | Everything, including all guardian actions after a PIN step-up | — |
| `member` | Create and edit their own events, complete tasks, add and tick shopping items, edit the meal plan, request redemptions | Approve redemptions, adjust points, manage members or devices, delete other people's events, revoke feed tokens, change household settings |

**Guardian actions** — the complete list, kept in one place in code:

```
approve/decline a reward redemption      manage reward catalogue
verify a task completion                 manage task definitions
create a manual point adjustment         manage members and roles
delete another profile's event           enrol or revoke a device
create or revoke a calendar feed token   change household settings
grant or revoke MCP/assistant access     view the full audit log
```

## Guardian PIN step-up

- 6 digits (4 is too few once a child has watched you enter it a hundred times from
  across the kitchen), hashed with bcrypt via `pgcrypto`, per-profile. (Argon2id was the
  plan on Node; inside Postgres bcrypt is what is available, and for a million-value
  space the lockout below, not the hash, is what protects the PIN.)
- On success, `device.guardian_verified_until = now() + 15 min`, stored server-side on
  the device row — never in a claim or anywhere the client could set it.
- Rate limiting: exponential backoff after 3 failures, hard lock after 10, unlockable
  only by a full guardian login. Failures are logged with the device.
- The PIN is entered on a dedicated numeric pad with no on-screen echo of the digits.

The 15-minute window means a parent setting up next month's chores does not re-enter the
PIN forty times, while a wall display left unattended returns to a safe state quickly.

## Adult accounts

*Rewritten 2026-10-11 for [ADR-014](adr/ADR-014-self-service-onboarding.md).* Every adult
who uses their own phone or the laptop has a **Supabase Auth** account, linked to their
profile (`profile.auth_user_id`, one household per account). Children never have one.

- **Ways in:** Sign in with Apple, Sign in with Google, an email **one-time code**, or
  email and **password** (chosen after the first code, so the address is always
  verified). One account can carry several of these. Passkeys can be added in Settings
  once they are verified on hardware. The flows are in [20](20-onboarding.md#the-front-door).
- **Public sign-up is on**, for adults. A fresh account has no household and therefore
  sees nothing: the access-token hook adds no household claim, and RLS shows an empty
  world. It can create a household (subject to the instance's
  [`household_creation` mode](20-onboarding.md#household-creation-open-or-by-code)) or
  accept an invitation.
- **A second factor (TOTP, Supabase MFA, `aal2`) is optional** per account and never part
  of sign-up. When it is on, the access-token hook withholds the household claims until
  the session is `aal2`, as built in M0.1. Another guardian can reset it.
- **Roles come from the profile, not the account.** An invitation says whether the adult
  joins as `guardian` or `member`; an au pair can have an account and still not approve
  rewards.

An adult's phone is enrolled simply by signing in: it becomes a `personal` device bound to
their profile, named automatically ("Daniels iPhone"). On a personal device a guardian
needs no PIN: the account sign-in is the stronger proof. A full sign-in on a personal
device (at `aal2` where TOTP is on) is required for: creating or deleting the household,
inviting adults, approving a device pairing, setting or resetting a PIN, and deleting the
account. Day-to-day use never asks for it.

## Device pairing

> **Built 2026-10-15 on `feature/regions-and-ux`, not yet on the server.** Pairing replaces code enrolment as the way a shared or kiosk device joins (see [20](20-onboarding.md#j3--connect-a-shared-device)). The device kinds are `wall_display` (kiosk register), `kid_tablet` (shared, kid register), `family_tablet` (shared, adult register) and `child_phone` (personal device bound to a child's profile). A guardian's personal phone approves the request and picks the kind; the approval creates the device's Auth user. The enrolment code stays for one release for devices on an older app.

No password and no code is ever typed on the wall display or a child's iPad. *Revised
2026-10-11 ([ADR-014](adr/ADR-014-self-service-onboarding.md)): the new device shows the
code and a parent's phone approves it, which reverses M0.1's direction.* Step by step in
[20, J3](20-onboarding.md#j3--connect-a-shared-device):

1. On the new device, install the app ([ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md))
   → "Familien-Tablet oder Wanddisplay verbinden". It shows a QR code and an 8-character
   code (`api.pairing_start`, ten minutes, renewed automatically while shown) and polls.
2. A guardian scans it with WuselWall on their **personal** device, or with the phone's
   camera, which follows the link into the app. Typing the code also works.
3. On the phone, the guardian picks what the device is (wall display, children's tablet,
   tablet for everyone, a child's own phone) and its name. That sets class, UI register
   and, for a child's phone, the bound profile. The first time, they also set their PIN.
4. `api.pairing_approve` binds the request. The new device's next poll, which carries the
   request's secret, collects a dedicated Auth user's credentials, signs in once and
   keeps only the session: refresh token in the Keychain (iOS) or Keystore-backed storage
   (Android), renewed by Supabase on use.

The display code alone grants nothing; the guardian's approval and the device's secret
are both needed. M0.1's direction (code generated on the phone, typed on the device) is
kept for one release so that older apps can still enrol, then removed.

Settings → Devices lists every device with its label, class, last-seen time and register,
and offers **Revoke** on each. Revocation is immediate: `device.revoked_at` is set, which
every RLS policy checks, and the device's Auth user is signed out everywhere so its refresh
token stops working. The next request from that device returns nothing, and the app falls
back to the front door. This is the
answer to a lost iPad, and it is the reason device tokens are per-device rather than a
shared household secret.

## Session and token summary

| Credential | Lifetime | Storage | Revocation |
|---|---|---|---|
| Device session (Supabase refresh token) | Rolling; expires after 180 days of inactivity | Platform secure storage | Per device, from settings |
| Access token (JWT, carries household and device) | 1 hour | App memory | Ineffective within seconds anyway: RLS checks `device.revoked_at` |
| Adult account session (personal device) | Rolling, as above | Platform secure storage | Per device, from settings; all at once by deleting the account |
| Email one-time code | 10 minutes, single use | The person's mailbox | Superseded by the next code |
| Invitation (link token and code) | 7 days, single use | Hash in DB | Withdrawn from Members |
| Pairing request | 10 minutes; its secret only on the requesting device | Hashes in DB | Expires |
| Guardian PIN elevation | 15 minutes | Server-side, on the device row | Automatic |
| Calendar feed token | Until revoked | URL (bearer); hash in DB | Per token |
| MCP OAuth access token | 1 hour | Client-held | Per grant |
| MCP refresh token | 30 days | Client-held | Per grant |
| Shortcuts key (`wws_…`) | Until revoked, or until its holder leaves | The Shortcuts app (synced by iCloud); hash in DB | Per key |

On the **web build** (the laptop), the session lives in browser storage instead of a
platform keystore — one more reason the laptop is a `personal` device with a fixed adult
profile, and is never left signed in on a machine others use.

## Profile switching UX

- **Shared and kiosk devices:** a persistent avatar row along one edge. Tap to become
  that person; the accent colour of the whole interface changes to theirs, so "who am I
  right now" is answerable from two metres away without reading.
- **Kiosk:** after 60 seconds of inactivity, revert to no active profile and return to
  the family dashboard. Nobody stays logged in as the last person to walk past.
- **Personal devices:** no avatar row at all. The profile is fixed and the UI does not
  waste space implying otherwise.

## Audit log

Every mutation, one row: `occurred_at`, `actor_profile_id`, `device_id`, `origin`
(`ui` | `api` | `mcp` | `shortcut` | `job`), `on_behalf_of`, entity type and id, action,
and a JSON diff. Written by `app.audit()` in the same transaction as the change; no role
holds `UPDATE` or `DELETE` on the table.

Guardians get a filterable view. In practice it will be consulted for exactly two things:
settling a dispute about who did which chore, and checking what an AI assistant did after
you gave it write access. Both are enough to justify it.

## Bootstrapping a new household

*Rewritten 2026-10-11 ([ADR-014](adr/ADR-014-self-service-onboarding.md)); the setup
wizard and its one-time token are replaced.* A household starts when an adult signs in
on their own phone and creates it ([20, J1](20-onboarding.md#j1--start-a-family)):

1. Sign in: Apple, Google or email.
2. **Neue Familie**: family name, own name and colour, mostly prefilled. Timezone and
   locale come from the device. While the instance is in `code` mode, a single-use
   founder code from the operator is also required.
3. **Wer gehört noch zu euch?**: names and *child/adult* for the others. Colours are
   assigned automatically, and starter examples are on by default.
4. The phone becomes the founder's personal device, and Today opens with the
   getting-started card: invite the partner, connect the children's tablet and the wall
   display, set the PIN when the first shared device arrives.

Seed data still matters as much as it did: a category set and the default list for
shopping (always), five starter chores, three rewards and four badges (unless switched
off) — the curated starter content of [21](21-household-settings.md#household-creation).
Every other behaviour starts at its curated default; nothing else is asked.
Good seed data is the difference between a system that gets used in week one and one that
sits empty waiting to be configured.
