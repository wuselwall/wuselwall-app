# 08 — Users, Authentication & Permissions (B1)

Implements FR-5.1 – FR-5.9. Decision context: [ADR-004](adr/ADR-004-identity-model.md).

## Two layers of identity

The chosen model separates two questions that most apps conflate:

- **Which device is this?** Answered once, at enrolment, and then persistent for months.
- **Who is acting right now?** Answered by tapping an avatar, in under a second.

```
  Device session  (long-lived, httpOnly cookie, revocable)
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
  across the kitchen), hashed with **Argon2id**, per-profile.
- On success, `guardianVerifiedUntil = now + 15 min`, stored server-side against the
  device session — never in a client-readable cookie.
- Rate limiting: exponential backoff after 3 failures, hard lock after 10, unlockable
  only by a full guardian login (passkey or password). Failures are logged with the
  device.
- The PIN is entered on a dedicated numeric pad with no on-screen echo of the digits.

The 15-minute window means a parent setting up next month's chores does not re-enter the
PIN forty times, while a wall display left unattended returns to a safe state quickly.

## Guardian accounts

Guardians additionally have a real account (Better Auth) with:

- **Passkey (WebAuthn)** as the primary method — Face ID on the iPhone, Touch ID or
  Windows Hello on the laptop. No password to phish, no password to type.
- **Email + password** as the fallback and recovery path, with Argon2id hashing.
- No email-magic-link flow in v1: it adds an outbound mail dependency for a system with
  two adult users who both own their devices.

Guardian login is required for: initial household setup, the settings area, device
enrolment, and unlocking a locked PIN. Day-to-day use never asks for it.

## Device enrolment

No password is ever typed on the wall display or a child's iPad. Instead:

1. On an already-trusted device, a guardian opens Settings → Devices → Add device.
2. GoombaWall generates a one-time code (8 characters) and a QR code, valid for 10 minutes,
   single use.
3. On the new device, open the app → "Set up this device" → scan or type the code.
4. The guardian names the device and picks its class and UI register.
5. The server issues a device token: a random 32-byte secret, stored hashed, delivered as
   an `httpOnly; Secure; SameSite=Lax` cookie with a one-year expiry and rolling renewal
   on use.

Settings → Devices lists every device with its label, class, last-seen time and register,
and offers **Revoke** on each. Revocation is immediate: the token hash is cleared and
the next request from that device gets a 401 and the enrolment screen. This is the
answer to a lost iPad, and it is the reason device tokens are per-device rather than a
shared household secret.

## Session and token summary

| Credential | Lifetime | Storage | Revocation |
|---|---|---|---|
| Device token | 1 year, rolling | `httpOnly` cookie; hash in DB | Per device, from settings |
| Guardian session | 30 days | Better Auth session cookie | Per session |
| Guardian PIN elevation | 15 minutes | Server-side, keyed to device session | Automatic |
| Calendar feed token | Until revoked | URL (bearer); hash in DB | Per token |
| MCP OAuth access token | 1 hour | Client-held | Per grant |
| MCP refresh token | 30 days | Client-held | Per grant |
| Shortcuts API token | Until revoked | iOS Keychain via Shortcuts | Per token |

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
and a JSON diff. Written in the same transaction as the change; `UPDATE` and `DELETE`
are revoked on the table for the application role.

Guardians get a filterable view. In practice it will be consulted for exactly two things:
settling a dispute about who did which chore, and checking what an AI assistant did after
you gave it write access. Both are enough to justify it.

## Bootstrapping a new household

1. First run with an empty database shows a setup wizard.
2. Create the household: name, timezone `Europe/Berlin`, locale `de-DE`.
3. Create the first guardian: email, password, then immediately register a passkey.
4. Set that guardian's PIN.
5. Add the remaining members: name, colour, avatar, role.
6. The current browser becomes the first enrolled device.
7. Optionally seed defaults: a category set for the shopping list, five starter chores,
   three rewards. Good seed data is the difference between a system that gets used in
   week one and one that sits empty waiting to be configured.
