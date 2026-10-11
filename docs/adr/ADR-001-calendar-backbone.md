# ADR-001 — Own database as the calendar source of truth, ICS feed outward

**Status:** Accepted · 2026-08-29

## Context

Requirement A1 asks for a family calendar that can also be seen in other environments —
specifically Outlook on a work laptop. Four backbones were available: an own CalDAV
server, Google Calendar via its API, Apple iCloud, or an own database publishing an ICS
feed. The interoperability requirement and the "no unnecessary third-party access to our
data" requirement pull in opposite directions, and Outlook is the awkward client in every
scenario: it has no meaningful CalDAV support, so the only universal path into it is a
subscribed internet calendar.

## Decision

Events live in GoombaWall's PostgreSQL database, which is the single source of truth.
GoombaWall publishes signed, unguessable, read-only ICS feeds. Outlook, iOS Calendar and any
other subscriber consume those feeds. No inbound sync in v1.

## Alternatives considered

**Google Calendar as backbone.** Best Outlook and iPhone experience, zero calendar code
to write. Rejected because it places the family's complete schedule with Google, adds an
OAuth integration with quotas and deprecations to maintain, and makes an external service
a hard dependency of the app's core feature.

**Apple iCloud.** Good fit for the iPhones and iPads, reachable over CalDAV. Rejected
because Outlook can still only subscribe read-only, so it does not actually solve the
requirement that motivated the choice — and it adds an Apple dependency in exchange.

**Own CalDAV server (Radicale, Baïkal).** Full data ownership plus two-way sync with iOS.
Rejected for v1 because Outlook remains read-only regardless, CalDAV is substantially
more protocol surface to implement or operate correctly, and it introduces a second data
store to keep consistent with the application's own. It stays the natural upgrade path.

## Consequences

**Positive**

- One place where an event exists. No sync conflicts, no duplicate events, no ghosts.
- No third-party API credentials, quotas, rate limits or deprecation cycles.
- Feed tokens are per-subscriber, filterable and independently revocable — the work
  laptop can subscribe to a view that excludes the children's chores.
- Full control over the data model, so events can reference members, tasks and meals
  natively.

**Negative**

- Events can only be created and edited inside GoombaWall. Creating one from the phone means
  opening the app rather than the native calendar.
- **Outlook refreshes subscribed calendars every 3–24 hours**, not configurably, with no
  manual refresh. The feed is an awareness channel; anything urgent goes out as web push.
- Feed URLs are bearer credentials. Mitigated by 256-bit tokens, per-subscriber issuance,
  revocation and rate limiting — but a leaked URL exposes calendar data until revoked.
- Implementing RFC 5545 correctly (folding, escaping, `VTIMEZONE`, `RECURRENCE-ID`,
  exclusive all-day `DTEND`) is genuinely fiddly and must be tested against real clients.

**Revisit if** phone-side event creation proves too annoying in practice — the answer
then is a CalDAV endpoint over the same tables, not a Google integration.
