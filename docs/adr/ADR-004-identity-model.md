# ADR-004 — Device sessions with tap-to-switch profiles and a guardian PIN

**Status:** Accepted · 2026-08-29

## Context

Requirement B1 asks for one user per family member so that completions and events are
attributable. The household is two adults and two children aged 7 and 9, and the devices
include a shared kitchen wall display, shared children's iPads, parents' iPhones and a
work laptop. Conventional per-user login is hostile in exactly the situations this app is
for: standing at a wall display with wet hands, or a seven-year-old wanting to tick off a
chore.

## Decision

Two-layer identity:

1. **Device session** — long-lived (one year, rolling), per-device, established once at
   enrolment via a one-time code generated on an already-trusted device. Stored as an
   `httpOnly` cookie, hashed server-side, individually revocable.
2. **Active profile** — chosen by tapping an avatar on shared and kiosk devices; fixed on
   personal devices.

Guardian actions require a **6-digit PIN step-up**, valid for 15 minutes on that device.
Guardians additionally hold real accounts (passkey or password) for settings, setup and
device management.

## Alternatives considered

**Individual accounts with real logins for everyone.** Cryptographically honest
attribution. Rejected because it would not be used: the wall display becomes useless, and
a 7-year-old will not type a password to tick off a chore. An app that is technically
correct and unused is worse than one that is cooperatively correct and used daily.

**PIN for children, passkey for parents.** The security-conscious middle ground, and
initially the recommendation. Rejected by the user in favour of lower friction. The data
model still supports it (`profile.pin_hash` exists for every profile), so it is a settings
change rather than a rewrite if it becomes necessary.

## Consequences

**Positive**

- No password is ever typed on a wall display or a child's iPad.
- Switching who is acting takes under a second, which is the difference between a system
  used dozens of times a day and one used twice.
- Per-device tokens mean a lost iPad is a single revocation, not a household-wide reset.
- Personal devices are genuinely attributable, so adult actions in the audit log are
  trustworthy.

**Negative — the important one**

- **The application cannot prove who did anything on a shared device.** A child can act
  as a sibling, or claim a bonus task they did not do. There is no technical remedy, and
  the design should not imply otherwise: attribution here is cooperative bookkeeping, the
  same trust model as a chore chart on the fridge.

Mitigations, in the order they matter:

1. Guardian actions — approving redemptions, adjusting points, deleting others' events,
   managing members and devices — are gated behind the PIN. A child can misreport a
   chore; a child cannot mint points or cash out.
2. Every mutation records the acting profile *and* the device in an append-only audit log,
   and the kiosk board shows completions publicly as they happen. Quiet cheating is not
   really on offer.
3. `requires_verification` on high-value bonus tasks holds points until a guardian
   confirms.
4. The escalation path — a PIN on profile selection for one specific child — is a settings
   change away if it turns out to be needed.

**Revisit if** the points economy visibly stops being trusted by the children themselves.
That, rather than any abstract security concern, is the signal that matters.
