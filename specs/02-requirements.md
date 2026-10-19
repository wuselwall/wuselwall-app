# 02 — Requirements

Numbered so that code, tests and later decisions can reference them. The **Origin**
column traces each requirement back to the original brief (A1–A4, B1–B4) or marks it
as derived (`D`) during planning.

Priority: **M** = must have in v1 · **S** = should have · **C** = could have · **W** = won't have in v1.

---

## FR-1 Calendar (A1)

| ID | Requirement | Prio | Origin |
|---|---|---|---|
| FR-1.1 | Create, edit and delete events with title, start, end, all-day flag, location, notes | M | A1 |
| FR-1.2 | Assign an event to one or more household members; unassigned events count as "whole family" | M | A1 |
| FR-1.3 | Recurring events using RFC 5545 `RRULE`, with per-occurrence overrides and exclusions | M | A1 |
| FR-1.4 | Day, 3-day and week views; a week board optimised for the wall display (see FR-8) | M | A1 |
| FR-1.5 | Publish a signed, unguessable, read-only ICS feed URL that Outlook and iOS Calendar can subscribe to | M | A1 |
| FR-1.6 | Issue separate feed tokens per subscriber (work laptop, phone, grandparents) and revoke any one of them independently | M | D |
| FR-1.7 | Filter a feed by member, so the work-laptop subscription can exclude the children's chores | S | D |
| FR-1.8 | Colour-code events by member with an additional non-colour cue (icon/initial) for accessibility | S | D |
| FR-1.9 | Import external read-only ICS feeds (sports club, bin collection) as overlay calendars, polled hourly | C | D |
| FR-1.10 | Two-way sync with Outlook or Google Calendar | W | — |
| FR-1.11 | Two event kinds: `appointment` and `presence` (Anwesenheit/Abwesenheit); presence renders as a day band, never as a timeline block or agenda item | M | late |
| FR-1.12 | Presence states — arbeitet, Homeoffice, Dienstreise, auswärts, frei, Betreuung — each with a distinct non-colour treatment | M | late |
| FR-1.13 | Maintain a repeating presence pattern (Dienstplan) either by recurrence rule *or* by an explicit set of dates (`RDATE`) picked in a month grid | M | late |
| FR-1.14 | Change or drop a single occurrence of any series — a swapped shift, a cancelled lesson — without touching the series | M | A1, late |
| FR-1.15 | Tentative status for unconfirmed plans, visually distinct and emitted as `STATUS:TENTATIVE` | S | late |
| FR-1.16 | Mark an event as a key appointment ("auf dem Küchendisplay zeigen"); default on for whole-family events | M | late |
| FR-1.17 | Feed tokens filter by event kind, so a subscription can exclude presence and school entries | S | late |
| FR-1.18 | Each member has a **baseline presence**, a usual week (issue #81): where they normally are on each weekday, optionally in up to three time slots a day and in alternating weeks A/B. Only deviations from it are entered and only deviations are emphasised on the week board | M | late |
| FR-1.19 | A day may carry a **busy-until** time per member ("Termine bis 17:00"), shown under their state. Maintained by hand in v1; derivable later from an imported work calendar | S | late |

## FR-2 Tasks & Gamification (A2)

| ID | Requirement | Prio | Origin |
|---|---|---|---|
| FR-2.1 | Define recurring household chores with a schedule (daily, weekly, every N days, specific weekdays) | M | A2 |
| FR-2.2 | Create one-off tasks with an optional due date | M | A2 |
| FR-2.3 | Assignment policies: fixed person, rotating between named people, open to anyone, or one copy per person | M | A2 |
| FR-2.4 | Mark a task complete as the acting profile; record who completed it and when | M | A2, B1 |
| FR-2.5 | Distinguish mandatory duties from optional bonus tasks | M | A2 |
| FR-2.6 | Award points on completion; maintain an append-only point ledger per member | M | A2 |
| FR-2.7 | Define rewards with a point cost; children request redemption, a guardian approves | M | A2 |
| FR-2.8 | Streaks for recurring duties, with a configurable number of "joker" days per period | M | A2 |
| FR-2.9 | Badges awarded automatically for defined achievements | S | A2 |
| FR-2.10 | Optional parent verification before points are credited, per task definition | S | D |
| FR-2.11 | Never assign negative points or display a failure state to a child | M | D |
| FR-2.12 | Sibling leaderboard | W | D — deliberately excluded, see [06](06-module-tasks.md) |

## FR-3 Meal Plan (A3)

| ID | Requirement | Prio | Origin |
|---|---|---|---|
| FR-3.1 | Assign a meal to a date and slot (breakfast, lunch, dinner, snack) as free text | M | A3 |
| FR-3.2 | Optionally link a meal to a stored recipe | M | A3 |
| FR-3.3 | Record who is cooking and who is eating at home | M | A3, late — the week board depends on it (FR-8.4) |
| FR-3.4 | Weekly meal-plan view, editable on the laptop; the meal zone of the wall display's week board is the same data | M | A3 |
| FR-3.5 | Store recipes with ingredients (name, quantity, unit) and free-text steps | M | A3 |
| FR-3.6 | Generate shopping items from the meal plan for a chosen date range, aggregating quantities | M | A3, A4 |
| FR-3.7 | Show, for any generated shopping item, which meal put it there | S | D |
| FR-3.8 | Suggest meals from history ("what did we eat this month?", "not cooked in 60 days") | C | D |
| FR-3.9 | Import a recipe from a URL via schema.org JSON-LD | C | D |

## FR-4 Shopping List (A4)

| ID | Requirement | Prio | Origin |
|---|---|---|---|
| FR-4.1 | Add an item in under three seconds from any device: a **tile picker** over the learned catalogue — recents and frequents first, a forgiving typeahead narrowing them, one tap to add — with a "neu anlegen" tile for anything the catalogue does not know | M | A4 |
| FR-4.2 | Quantity and unit are optional; a bare name is a valid item. Tapping a tile again increments the quantity — no numeric field on the capture path | M | D |
| FR-4.3 | Tick items off while shopping, with a large touch target and an undo | M | A4 |
| FR-4.4 | Group items by category and sort those categories in the walking order of a chosen store | S | D |
| FR-4.5 | Full offline operation: add, tick and edit with no connectivity, syncing on reconnect | M | A4, B2 |
| FR-4.6 | Multiple people shopping simultaneously see each other's ticks within seconds when online | S | D |
| FR-4.7 | Completed shopping is archived rather than deleted, feeding the autocomplete catalogue | M | D |
| FR-4.8 | Several lists, each offering only the catalogue categories that belong to it; **one is the default** and the only one the wall display opens. Starter set: Supermarkt (default), Drogerie, Baumarkt ([21](21-household-settings.md#shopping)) | M |
| FR-4.9 | A free-text specification per item ("Bio", "500 g", "Dose", "E14 warmweiß"), entered by long-pressing a tile; the server splits it into quantity and unit only where that is unambiguous | M | late |
| FR-4.10 | Every item records who added it, shown in the list as a dot in that member's colour. Children add items on the same screen as everyone else — no separate kid mode | M | late |

## FR-5 Users & Identity (B1)

| ID | Requirement | Prio | Origin |
|---|---|---|---|
| FR-5.1 | One profile per household member with a name, avatar and colour | M | B1 |
| FR-5.2 | Two roles: guardian (adult) and member (child) | M | B1 |
| FR-5.3 | A device holds a long-lived session; the acting profile is switched by tapping an avatar | M | B1, user decision |
| FR-5.4 | Devices are classified as personal (single fixed profile) or shared (profile switching enabled) | M | D |
| FR-5.5 | Guardian-only actions require a PIN step-up, valid for a short window on that device | M | D |
| FR-5.6 | Connect a shared device by **pairing**: the new device shows a code and QR, a guardian approves it on their personal device and chooses its kind there; nothing is typed on the shared device *(revised 2026-10-11, was: a code generated on a trusted device and typed on the new one)* | M | D, [20](20-onboarding.md#j3--connect-a-shared-device) |
| FR-5.7 | List all enrolled devices and revoke any of them remotely | M | D |
| FR-5.8 | Adults authenticate with **an email one-time code, or email and password**; passkeys as an optional extra. One screen serves sign-up and sign-in *(revised 2026-10-17, was: also Sign in with Apple and Google; revised 2026-10-11, was: passkey or password, accounts created by the setup wizard)* | M | D, user 2026-10-11 |
| FR-5.9 | Append-only audit log of every mutation: actor profile, device, timestamp, before/after | M | D |
| FR-5.10 | Public sign-up for adults; a new account sees nothing until it creates or joins a household. Children never have accounts | M | user 2026-10-11 |
| FR-5.11 | A signed-in adult without a household creates one with a family name; timezone and locale come from the device. Household creation is `open` or requires a single-use founder code (`code`), per instance | M | user 2026-10-11 |
| FR-5.12 | A guardian invites another adult by link, code or QR, bound to a profile and a role, valid 7 days, single use, revocable; an invitation naming an email is offered automatically to that verified address | M | D |
| FR-5.13 | One account can hold several sign-in methods; adults add and remove them in Settings, never the last one | S | D |
| FR-5.14 | Account recovery without the operator: an email code replaces a forgotten password; a guardian can reset another guardian's second factor | M | D |
| FR-5.15 | A second factor (TOTP) is optional per account and never part of sign-up | M | D |
| FR-5.16 | Delete one's account, leave the household, delete the household (restorable for 14 days) and export its data, from inside the app | M | App Store 5.1.1(v), Play, GDPR |
| FR-5.17 | A getting-started card on the adult Today screen, shared by the household and derived from data (invite partner, connect tablet and wall display, set PIN, reminders, feed, passkey) | S | D |
| FR-5.18 | The guardian PIN is asked for when the first shared or kiosk device is connected, not during household creation | M | D |
| FR-5.19 | The store app has **no default server**: a household's server is chosen by an invitation or pairing link, the server's QR code or its typed address (discovery via `/.well-known/wuselwall.json`), and a demo mode works without one. Native Apple/Google sign-in and passkeys are offered on the first-party servers named at build time (`WW_FIRST_PARTY_HOSTS`) only | M | user 2026-10-13, [ADR-018](adr/ADR-018-self-hosted-only.md) (was: Cloud by default, ADR-015) |
| FR-5.20 | Every household-specific behaviour is a **setting with a curated default**: guardians change it in Einstellungen, see whether it still is the default, and reset it; household creation asks nothing beyond [20, J1](20-onboarding.md#j1--start-a-family), and its starter examples are the curated starter content ([21](21-household-settings.md)) | M | late, 2026-10-11 |

## FR-6 Assistant Integration (B4)

*Scheduled for M2 ([13](13-roadmap.md)). The pilot launch (M1.6) ships without it, so "M"
here means "before v1 is called done", not "before the household uses it".*

| ID | Requirement | Prio | Origin |
|---|---|---|---|
| FR-6.1 | An MCP server exposing read tools for agenda, tasks, meals and the shopping list | M | B4 |
| FR-6.2 | MCP write tools for adding shopping items, completing tasks and creating events | M | B4 |
| FR-6.3 | Every assistant action is attributed to a human principal and flagged as assistant-initiated in the audit log | M | D |
| FR-6.4 | Read and write scopes are separate; write access is granted explicitly | M | D |
| FR-6.5 | Siri support today via Apple Shortcuts calling a token-authenticated REST endpoint | M | B4 |
| FR-6.6 | Destructive tools (delete event, delete task, adjust points) are not exposed over MCP in v1 | M | D |


## FR-7 School Timetable — Stundenplan (A5)

Added 2026-08-30. Specified in [15](15-module-school-timetable.md); decision context in
[ADR-008](adr/ADR-008-school-timetable-model.md).

| ID | Requirement | Prio | Origin |
|---|---|---|---|
| FR-7.1 | Define a school with its bell times (Stundenraster) and its terms (Halbjahre) | M | late |
| FR-7.2 | Maintain one weekly timetable per child per term as an editable grid: weekday × Stunde → Fach, Lehrkraft, Raum | M | late |
| FR-7.3 | Subjects carry a colour **and** an icon, legible for an early reader and at two metres | M | late |
| FR-7.4 | Support A/B weeks (Doppelwochen), derived from an anchor week — no per-week table | S | late |
| FR-7.5 | Timetable rows may be lessons, after-school care (Hort/Betreuung) or clubs (AG) | M | late |
| FR-7.6 | Per-date exceptions: Entfall, Vertretung, Raumänderung, Zusatzstunde | M | late |
| FR-7.7 | School holidays and closure days (Ferien, bewegliche Ferientage) suppress lessons on those dates | M | late |
| FR-7.8 | The timetable is projected into calendar, agenda, kid views and the week board as read-only occurrences; no event rows are written for lessons | M | late |
| FR-7.9 | Import a Bundesland's Ferien from a public feed, fetched server-side and cached | C | late |
| FR-7.10 | Stundenplan grid view with today's column and the current or next lesson marked; Ferien weeks shown as one band | M | late |
| FR-7.11 | Copy a timetable from the previous term or from a sibling | S | late |
| FR-7.12 | Equipment reminders derived from tomorrow's subjects ("Morgen brauchst du: Sportsachen") | C | late |
| FR-7.13 | The ICS feed carries the school day collapsed to one block per child per day, configurable per token and off by default | S | late |
| FR-7.14 | Automatic import from a school portal (WebUntis, IServ, Schulmanager) | W | — |

## FR-8 Wall Display — the week board (B2)

Added 2026-08-30. The kitchen display's standard view. Specified in
[09](09-clients-and-ux.md#the-week-board); decision context in
[ADR-009](adr/ADR-009-event-kinds-and-presence.md).

| ID | Requirement | Prio | Origin |
|---|---|---|---|
| FR-8.1 | The default kiosk screen is a **seven-day week board**, not a today dashboard | M | late |
| FR-8.2 | Each day column carries the same fixed zones in the same order: wer ist wo (school + presence), Termine, warmes Essen | M | late |
| FR-8.3 | The school zone shows each child's school-day span plus notable lessons only (Sport, Schwimmen, FreiDay, excursions) — never individual subjects; the full grid is one tap away | M | late |
| FR-8.3a | Tapping a child opens the **Stundenplan detail**: numbered Stunden with bell times down the side, weekdays across the top, today marked, Entfall struck, Vertretung labelled, and tomorrow's equipment line | M | late |
| FR-8.3b | Key appointments are grouped into three fixed day parts — Vormittag, Nachmittag, Abend — rather than placed on a time axis, with one dot per attendee in their member colour | M | late |
| FR-8.4 | The meal zone is a fixed area per day showing **one warm meal** (Mittag at weekends, Abend on school days), who is cooking, and per member whether they are eating at home | M | late |
| FR-8.5 | Today's column is visually dominant, with a "jetzt / als Nächstes" line | M | late |
| FR-8.6 | The board never scrolls: overflow degrades to an aggregate ("+3 weitere"), never to a cut-off column | M | late |
| FR-8.7 | The displayed week rolls over to the coming week at a configurable point in the weekend | S | late |
| FR-8.8 | Tapping a day or a member opens detail — full day, full Stundenplan, that person's tasks — and reverts after 60 s | M | late, FR-5.3 |
| FR-8.9 | A footer strip retains today's operational numbers: open tasks per member, shopping-list count | S | late |
| FR-8.10 | Offline or stale data is shown honestly with a last-updated marker; never an error screen | M | late, NFR-6 |
| FR-8.11 | A night variant after 21:00, and a "alle Termine zeigen" tap for the case where a key flag was forgotten | S | late |
| FR-8.12 | The footer's shopping count opens the same tile capture as the phone — larger tiles, categories, and **no search field**, because nobody types on a wall. It always writes to the default list (FR-4.8) | M | late |

---

## Non-functional requirements

| ID | Requirement | Target | Origin |
|---|---|---|---|
| NFR-1 | **Multi-device** — works on iPhone, iPad, desktop browser and a wall tablet from one codebase | One Flutter codebase: native iOS/iPadOS and Android apps plus a web build; all four device classes verified before v1 is called done | B2 |
| NFR-2 | **Installability** — a native app on every phone, iPad and the wall tablet, updated without touching the device *(revised 2026-10-11, was: PWA add-to-home-screen)* | The App Store and Google Play ([Q42](14-open-questions.md)), with TestFlight and the Play testing tracks before each release, verified on a real device of each kind ([ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md)) | B2 |
| NFR-3 | **Performance** — the week board on a low-end wall tablet | Cold start to a rendered board < 3 s, refresh after a change < 1 s, on the household LAN | D |
| NFR-4 | **Interaction latency** — ticking an item feels instant | Optimistic UI, < 100 ms perceived | D |
| NFR-5 | **Live updates** — a change on one device appears on the others | < 3 s while online | FR-4.6 |
| NFR-6 | **Availability** — self-hosted, single node, no HA | ~99% is fine; scheduled downtime acceptable | B3 |
| NFR-7 | **Cost** — total recurring spend | Hosting ≤ €13 / month, plus the Apple Developer Program (€99 / year). *Proposed 2026-10-11 — the native apps and a larger server for Supabase break the original ≤ €10 target; confirm in [Q36](14-open-questions.md)* *Since [ADR-018](adr/ADR-018-self-hosted-only.md) (2026-10-13): no hosted flavour, so ≈ €8–12/month is the whole cost ([10](10-deployment-and-ops.md#costs)); every other household's server is its operator's cost* | B3 |
| NFR-8 | **Data residency** — all data stored in Germany or the EU | Hard requirement for what the project ships and recommends (EU regions, EU mail providers). Each household's data lives wherever its operator runs the server ([ADR-018](adr/ADR-018-self-hosted-only.md)) | B3 |
| NFR-9 | **Third-party exposure** — outbound connections from server and client | Zero analytics, zero external fonts, zero CDN, zero error-reporting or crash-reporting SDKs in the app. Push via APNs/FCM and distribution via Apple/Google are the accepted exceptions, and carry no data beyond the notification itself (v1 sends no push at all: its reminders are local, [Q47](14-open-questions.md)). *Since 2026-10-11 ([ADR-014](adr/ADR-014-self-service-onboarding.md)):* one SMTP provider for sign-in codes is also accepted (Sign in with Apple/Google was too, until 2026-10-17). No deferred-deep-link, attribution or captcha service | B3 |
| NFR-10 | **Transport security** — HTTPS everywhere, HSTS, modern TLS only | Enforced by the reverse proxy | B3 |
| NFR-11 | **Backups** — nightly, encrypted, off-site, with a tested restore | RPO 24 h, RTO 4 h | D |
| NFR-12 | **Patching** — OS and dependency updates | Unattended OS security updates; dependency review monthly | B3 |
| NFR-13 | **Accessibility** — usable by a child from about six and readable across a kitchen | Touch targets ≥ 56 px in kid and kiosk modes; WCAG AA contrast; never colour alone | D |
| NFR-14 | **Localisation** — German and English UI, English codebase and documentation | i18n structure in place from day one; every string shipped in both German and English, German the default; school vocabulary fixed once in the catalogue ([15](15-module-school-timetable.md#german-glossary)) | D |
| NFR-15 | **Maintainability** — a solo developer must be able to return after two months away | One database as the domain core, typed at every layer (Dart, SQL, TypeScript), every rule and policy covered by a test, ADRs kept current | D |
| NFR-16 | **Wall-display legibility** — the week board is read from across the kitchen | Readable at 2.5 m; no text below 24 px in the kiosk register; seven days fit without scrolling on a 10–15" landscape screen | late |
| NFR-17 | **Onboarding effort** *(added 2026-10-11)* | Start a family: ≤ 3 screens after sign-in, ≤ 90 s from the email code. Join by invitation: ≤ 2 screens after sign-in, ≤ 60 s. Connect a shared device: no typing on it, ≤ 30 s of a guardian's time. Never ask for what can be inferred or deferred. Checked by timed walk-throughs and screen-count tests, not analytics ([20](20-onboarding.md#how-smooth-is-checked)) | user 2026-10-11 |

## Constraints inherited from the platform

These are not choices; they are facts to design around. Detail in [09](09-clients-and-ux.md).
*Revised 2026-10-11 for native apps; the PWA constraints that stood here no longer apply.*

- iOS gives apps **no reliable background execution**. A reminder is either handed to the
  OS in advance as a local notification, from data the app already holds (v1, Q47), or
  pushed by a server; never a timer inside the app. The shopping outbox drains on resume
  rather than in the background.
- **Notifications need a one-time permission**; a push would also travel through Apple's
  and Google's push services.
- **Every iOS build must be signed** and distributed through an Apple channel; TestFlight
  builds expire after 90 days. An Apple Developer Program membership is a hard
  prerequisite.
- **The anon key ships inside every app.** Row-level security, not obscurity, is what
  protects the data.
- **Outlook refreshes subscribed ICS calendars every 3–24 hours**, is not configurable,
  and offers no manual refresh. This bounds what FR-1.5 can promise.
