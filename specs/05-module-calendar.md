# 05 — Module: Calendar (A1)

Implements FR-1.1 – FR-1.17. Decision context: [ADR-001](adr/ADR-001-calendar-backbone.md)
and [ADR-009](adr/ADR-009-event-kinds-and-presence.md).

The school timetable and the presence model added on 2026-08-30 are specified in
[15 — School Timetable & Presence](15-module-school-timetable.md); this document covers
what the calendar itself stores, renders and publishes.

## The shape of the decision

WuselWall owns the events. Its database is the single source of truth. Everything else —
Outlook on the work laptop, the iPhone calendar, a grandparent's Google Calendar —
**subscribes** to a read-only ICS feed.

This buys simplicity at a real price, and the price should be stated plainly:

| You get | You give up |
|---|---|
| One place where an event exists. No sync conflicts, ever. | Events can only be created and edited inside WuselWall. |
| No third-party API credentials, quotas, or deprecations to track. | Outlook shows changes with a delay of **3–24 hours**. |
| No family data at Google or Microsoft. | An event created in Outlook does not appear in WuselWall. |
| A feed URL is trivially revocable and can be filtered per subscriber. | Feed URLs are bearer credentials — anyone with the link reads the calendar. |

The Outlook refresh delay is the part worth internalising now: Microsoft does not
document a fixed interval, does not let you configure one, and does not offer a manual
refresh button for subscribed internet calendars. Reports cluster around 3–4 hours and
occasionally stretch to 24. **The ICS feed is an awareness channel, not a notification
channel.** Anything time-critical is delivered by push from WuselWall itself.

iOS Calendar is better behaved: subscribed calendars can be set to refresh as often as
every 15 minutes, and the phone is the device that actually needs to be current.

## Recurrence

Store RFC 5545 directly. Do not invent a recurrence format.

- `event.rrule` holds the rule string, e.g. `FREQ=WEEKLY;BYDAY=TU;UNTIL=20270701T000000Z`.
- `event.exdates` holds cancelled dates for simple skips.
- `event_override` holds a full modified occurrence, keyed by `recurrence_id` — the
  *original* start instant of the occurrence being overridden, exactly as ICS defines it.
- Expansion at read time via the `rrule` library, bounded to the requested window.
  Never materialise recurring occurrences into rows: the calendar has no equivalent of
  the task materialiser, because unlike tasks, occurrences carry no state.

**Timezone rule:** a weekly 07:00 event is stored with the household's zone (e.g.
`timezone = 'Europe/Berlin'`) and expanded in that zone, so it stays at 07:00 across the DST boundary. Storing only a UTC
instant and expanding in UTC shifts it by an hour every March and October. This is the
single bug most likely to make the family distrust the calendar.

**All-day rule:** stored as `DATE`, emitted as `VALUE=DATE` with a `DTEND` of the day
*after* the last day (ICS end dates are exclusive). Getting this wrong shows a birthday
on the wrong day in Outlook, which is exactly the kind of error that discredits the
whole system.

## What a calendar entry can be

Three things reach a calendar surface, and they behave differently on purpose:

| | Stored as | Rendered as | In the agenda? | Editable there? |
|---|---|---|---|---|
| **Appointment** | `event`, `kind='appointment'` | A block at its time, or an all-day chip | Yes | Yes |
| **Presence** | `event`, `kind='presence'` | A band across the day, behind everything else | No | Yes |
| **Lesson** | Projected from a `timetable` | A compact school-day span, or a grid cell | Only as the day's span | No — timetable actions only |

Keeping presence in the `event` table means recurrence, overrides, attendees, audit and
ICS emission are written once. Keeping lessons *out* of it means sixty weekly series never
have to be maintained by hand. Both decisions are argued in
[ADR-008](adr/ADR-008-school-timetable-model.md) and
[ADR-009](adr/ADR-009-event-kinds-and-presence.md).

### Flexible by construction

The requirement that arrived with A5 — *appointments should be flexible: regular for when
Sabine is working, ad hoc for when Lukas is travelling* — is met by three small things
rather than a new subsystem:

1. **`rdates`.** A series can be an explicit list of dates, not only a rule. The rota that
   arrives as a PDF each month is one series with fourteen `RDATE`s, entered by tapping
   days in a month grid.
2. **`status='tentative'`.** A trip that might happen is worth showing, dashed and at 60%
   opacity, and it travels into Outlook as `STATUS:TENTATIVE`.
3. **`event_override`.** Already there for recurrence; it is also what makes a swapped
   shift a two-tap change instead of a re-entry.

### Occurrence sources

`getOccurrences(window, filter)` is the single read path behind every view and the ICS
feed. It composes sources rather than querying one table:

```
events      → expand rrule + rdates − exdates, apply overrides      (editable)
school      → project timetables − holidays ± exceptions            (read-only)
imported    → cached external ICS, M2                               (read-only)
tasks       → due task instances, when the caller asks for them     (read-only)
```

Every source returns the same `Occurrence` shape: id, source, uid, title, start, end,
all-day flag, kind, member ids, colour, importance, editability. The views never learn
where an occurrence came from beyond that flag, which is why adding imported feeds later
is a source implementation rather than a UI change.

## Views

| View | Register | What it is for |
|---|---|---|
| Day / 3-day | adult | The detail, on a phone |
| Week | adult | Planning. Presence bands behind, appointments in front |
| **Week board** | kiosk | The kitchen's standard screen — [09](09-clients-and-ux.md#the-week-board) |
| Stundenplan grid | adult, kid | The timetable as a grid — [15](15-module-school-timetable.md#views) |
| Month | adult | Only where it earns its place: the rota editor and holidays |

The week board is a *composition* of this module, `school` and `meals`, and it is the
screen the household will look at most. Treat its query — seven days, key appointments,
presence, projected school days, meals with attendees — as a first-class read model with
its own test, not as four independent fetches the client stitches together.

## The ICS feed

### URL and authentication

```
GET https://api.wuselwall.app/ics/{token}.ics
```

- `token` is 32 random bytes, base64url-encoded. Only its hash is stored.
- One token per subscriber, with a human label ("Work laptop Outlook", "Oma").
- Each token carries a `filter`: which member's events, which calendars, which **kinds**,
  and how much school to include (`off` | `day` | `lessons`). The work-laptop token can
  exclude the children's chore-derived entries so the Outlook view stays professional.
- **New tokens default to appointments only**: presence off, school off. A child's daily
  whereabouts and an adult's shift pattern are the two things in this system most worth
  not sharing by accident. Turning them on is one checkbox and a deliberate act.
- A settings page lists tokens with `last_fetched_at` and a fetch count, and lets any
  one be revoked without disturbing the others.
- The endpoint is rate-limited, returns nothing but calendar data, and is excluded from
  every log that records full URLs. Treat the token as a password in a query string,
  because that is what it is.

### Response behaviour

- `Content-Type: text/calendar; charset=utf-8`
- `ETag` derived from the household's highest event revision plus the filter hash;
  honour `If-None-Match` and return `304`. Outlook polls whether or not anything
  changed; the 304 path should cost almost nothing.
- `Cache-Control: private, max-age=900`
- Emit `X-WR-CALNAME` and `X-WR-TIMEZONE` — Outlook and Apple both use them for the
  calendar's display name.
- Window the output: from 90 days in the past to 400 days ahead, plus all recurring
  series regardless of window. An unbounded feed grows until clients start truncating it.

### Correctness checklist for the generated file

These are the things that silently break subscribers:

- `UID` stable and globally unique per event — never regenerated on edit.
- `SEQUENCE` incremented on every modification.
- `DTSTAMP` present on every `VEVENT`.
- Lines folded at 75 octets; `,` `;` `\` and newlines escaped in text fields.
- `VTIMEZONE` components emitted for every timezone referenced.
- CRLF line endings. Yes, really.
- Cancelled occurrences as `EXDATE`, modified ones as a second `VEVENT` with
  `RECURRENCE-ID`.
- `RDATE` emitted alongside `RRULE` where a series uses both, so a rota reaches Outlook as
  one series rather than fourteen events.
- `STATUS` emitted for tentative and cancelled entries. A cancelled event must keep being
  emitted with `STATUS:CANCELLED` for a while — dropping it silently leaves it on the
  subscriber's calendar forever.
- Presence entries carry `TRANSP:TRANSPARENT` and a `X-WUSELWALL-KIND:presence` marker, so
  a subscriber's free/busy is not blocked by "Sabine arbeitet".
- Projected school days use deterministic UIDs (`schoolday-{profileId}-{date}@domain`) and
  a `SEQUENCE` derived from the timetable's `updated_at`. Random UIDs here mean a fresh
  set of ghosts in Outlook every time the feed is rendered.

Validate the output against a reference implementation in CI, and test against real
Outlook and real iOS at least once before declaring the module done. ICS is a format
where "it parses" and "it renders correctly in Outlook" are different claims.

## Subscribing — the actual steps

Worth writing into the household documentation, because these are done once and
forgotten:

**Outlook (work laptop, Microsoft 365 web or new Outlook):** Calendar → Add calendar →
Subscribe from web → paste the `https://…/ics/{token}.ics` URL → name it "Family" →
choose a colour. Note: the classic Outlook desktop client's *Internet Calendars* tab
also works and sometimes refreshes more eagerly, but the account-level web subscription
follows you across devices.

**iPhone / iPad:** Settings → Apps → Calendar → Accounts → Add Account → Other → Add
Subscribed Calendar → paste the URL. Then set the fetch interval under Fetch New Data.
Alternatively, tapping a `webcal://` link opens the same dialog directly — worth
generating that link form in the UI.

## Later: two-way for the phones

If read-only proves too limiting on the phones (creating an event has to happen in
WuselWall, which is fine at a desk and annoying on the move), the upgrade path is a
**CalDAV endpoint**, not a Google integration. Either implement CalDAV on top of the
existing event tables, or run Radicale alongside and treat one Radicale collection as a
writable inbox that WuselWall polls. Both are Phase 3 or later. Outlook is not part of
this path — it has no meaningful CalDAV support, which is precisely why the ICS feed
exists.

## Later: importing external calendars

Ferien (via the Bundesland feeds, see [15](15-module-school-timetable.md#holidays)),
sports fixtures and rubbish collection are all published as ICS. `calendar.kind = 'imported'` with a `source_url`, polled hourly by the
scheduled job (`pg_cron` → an Edge Function), rendered read-only in a distinct colour, and included in the outbound feed so
they reach Outlook too. Low effort, high perceived value — a good early Phase 2 item.

## v1 scope cut

**In:** create/edit/delete, all-day and timed, attendees, recurrence with overrides,
`rdates` rotas, presence entries with six states, tentative status, the key-appointment
flag, day/3-day/week views, the composed week board for the wall display, outbound feeds
with per-token filtering by member, calendar and kind, and revocation.

**Out:** imported feeds, CalDAV, invitations to people outside the household, attachments,
reminders that are not push notifications, free/busy queries and conflict detection,
natural-language event entry.
