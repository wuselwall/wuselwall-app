# 09 — Clients & User Experience (B2)

Implements NFR-1 – NFR-5, NFR-13, NFR-14 and FR-5.4. How people and devices get into
the app (sign-up, invitations, pairing, the getting-started card) is
[20 — Onboarding](20-onboarding.md).

## One application, three registers

There is one Flutter app — native on iOS, iPadOS and Android, plus a web build for the
laptop ([ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md)). It presents itself in three registers, chosen by the **device's**
configuration (`device.ui_register`), not by screen width. A child's iPad and a parent's
laptop can be the same physical size and still need different interfaces.

| Register | Devices | Character |
|---|---|---|
| **adult** | Laptop browser (web build), parents' iPhones | Dense. Full navigation and all administrative screens; a navigation rail on wide screens ([16, step 10.11](16-setup-plan.md#step-10--journey-gaps-before-launch-m15)). This is where planning happens. Keyboard shortcuts and bulk editing are M3. |
| **kid** | Children's iPads | Large. Icons before words, four or five destinations maximum, no destructive actions, generous animation and feedback. |
| **kiosk** | Wall display | Glanceable. A read-first **week board**, no navigation chrome, huge type, tap-to-act on a small set of things, auto-revert to home after 60 s. |

Responsive layout still applies within each register — the adult register must work on a
phone — but the register itself is a device property.

Before a device belongs to a household it shows the **front door**
([20](20-onboarding.md#the-front-door)), the same on every device: continue with Apple,
Google or email, or connect this device as a family tablet or wall display. The register
is decided by what happens there: an adult's sign-in gives `adult`, and the pairing choice
on the parent's phone gives `kid` or `kiosk`.

## Screens by register

**adult**
- Today (agenda + tasks + tonight's meal + list count)
- Calendar: day / 3-day / week, presence bands, the rota month-grid editor
- Stundenplan: the grid per child, exceptions, terms, bell times, holidays
- Tasks: my tasks, family board, definitions admin, approvals
- Meals: week grid, recipes
- Shopping: list, catalogue, stores
- Settings: account and sign-in methods; members (edit, order, invite) and invitations;
  devices (connect, rename, revoke); the family (name, timezone, export, delete); household
  settings, presence baselines, feed tokens, subscribed calendars, reminders, getting
  started. Rewards live under Tasks, school and subjects under Stundenplan. The member,
  family and device editing is [16, step 10.1–10.2](16-setup-plan.md#step-10--journey-gaps-before-launch-m15);
  assistants and the audit log are M2.

**kid**
- My day (my tasks + today's meal + my events + today's lessons)
- Mein Stundenplan (the week's grid, today's lessons as large cards)
- My points (balance, reward shop, badges, streaks)
- Shopping (add + tick — children are surprisingly good at this)
- Family (who is doing what today)

**kiosk**
- The **week board** (below): the standard screen, seven days at once.
- Tap-through detail: one day in full, one child's Stundenplan, one member's tasks.
  Everything reverts to the week board after 60 s.

## The week board

*Added 2026-08-30 (FR-8.1 – FR-8.11). This replaces the earlier "today dashboard" as the
kiosk's standard screen.*

**Mockup:** [`specs/mockups/kiosk-week-board.html`](mockups/kiosk-week-board.html) —
interactive, German, with a Tag/Nacht toggle and working tap-through; published at
https://claude.ai/code/artifact/748ae563-53fa-4645-8c9a-302d42011e76. Built to be argued with before anything is coded: it carries the
five decisions the family has to make (Q23, Q25–Q27 in [14](14-open-questions.md)) as
questions on the page.

The kitchen screen answers a different question from a phone. A phone is asked "what is
next?"; the kitchen is asked **"what does this week look like?"** — usually by someone
standing with a coffee on Sunday evening or a school bag on Tuesday morning. So the
standard view is seven days wide, and today is merely the loudest column, not the only
one.

### The rule that makes it readable

**Every day column contains the same zones, in the same order, at the same height.** The
eye learns the geometry once and then reads by position rather than by searching. A column
that reflows because Wednesday happens to be busy destroys that, so zones keep their band
even when empty — an empty meal zone says "nothing planned", which is itself information.

The board below shows the reference household
([21](21-household-settings.md#the-reference-household)): two children, two adults. Another
household gets one row per member, and the time boundaries, rollover and night hours are
household settings with these values as defaults.

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ Mittwoch, 2. September · 17:42     KW 36     ● Als Nächstes: 18:30 Chili sin Carne  │
├──────────┬─────────┬─────────╥─────────╥─────────┬─────────┬────────┬──────────────┤
│  KW 36   │ Mo 31.8.│ Di 1.9. ║ Mi 2.9. ║ Do 3.9. │ Fr 4.9. │ Sa 5.9.│ So 6.9.      │
│          │         │         ║  HEUTE  ║         │         │        │              │
├──────────┴─────────┴─────────╨─────────╨─────────┴─────────┴────────┴──────────────┤
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
├──────────┼─────────┼─────────╥─────────╥─────────┬─────────┬────────┬──────────────┤
│ ● Lotta  │ 8–14:25 │ 8–14:25 ║ 8–14:25 ║ 8–14:25 │ 8–13:35 │  frei  │  frei        │
│    9     │         │ FreiDay ║ Sport   ║ Sport   │ Sport   │        │              │
│ ● Hanna  │ 8–11:30 │ 8–12:45 ║ 8–11:30 ║ 8–12:45 │ 8–11:30 │  frei  │  frei        │
│    7     │Hort 15  │Hort 15  ║Schwimmen║Hort 15  │         │        │              │
│ ● Sabine │ DIENST  │·zu Hause║ DIENST  ║·zu Hause│·zu Hause│·zu Haus│·zu Hause     │
│          │8:30–14  │         ║8:30–14  ║         │         │        │              │
│ ● Lukas  │·Homeoff.│BÜRO HH  ║·Homeoff.║◀── Dienstreise Berlin ──▶│·Homeoff.│      │
├──────────┼─────────┼─────────╨─────────╨─────────┼─────────┼────────┼──────────────┤
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
├──────────┼─────────┼─────────╥─────────╥─────────┼─────────┼────────┼──────────────┤
│ Vormittag│10:00    │         ║         ║         │         │10:00   │11:00         │
│          │Heizung ●│         ║         ║         │         │Turnier●●│Oma+Opa ●●●● │
│ Nachmit. │15:00    │14:30    ║16:00    ║15:30    │         │16:00   │              │
│          │Turnen  ●│Zahnarzt●║Turnen  ●║Klavier ●│         │Grillen?│              │
│ Abend    │         │         ║19:30    ║         │18:00    │        │              │
│          │         │         ║Elternab●║         │Kino  ●●●│        │              │
├──────────┼─────────┼─────────╨─────────╨─────────┼─────────┼────────┼──────────────┤
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
├──────────┼─────────┼─────────╥─────────╥─────────┼─────────┼────────┼──────────────┤
│ Warmes   │ABEND    │ABEND    ║ABEND    ║ABEND    │ABEND    │MITTAG  │MITTAG        │
│ Essen    │Kürbis-  │Nudel-   ║Chili    ║Fisch-   │Flamm-   │Pesto   │Braten        │
│          │suppe    │auflauf  ║sin Carne║stäbchen │kuchen   │        │              │
│          │●●●● Sab │●●●● Luk ║●●●● Sab ║●●●○ Sab │●●●○ Sab │●○○● Luk│●●●● +2 Gäste │
├──────────┴─────────┴─────────╨─────────╨─────────┴─────────┴────────┴──────────────┤
│ Heute offen: Lotta 2 · Hanna 1 · Sabine 1    Einkaufsliste 7                       │
└────────────────────────────────────────────────────────────────────────────────────┘
```

### The zones

| Zone | Height | Contents | Source |
|---|---|---|---|
| **Header** | 1 line | Full date, clock, calendar week, the next-up line; the freshness marker only once the board is out of date | — |
| **Wer ist wo** | One row per member, always in the household's member order (`profile.sort_order`) | Children: the school-day span from the Stundenplan, plus the lessons worth knowing about the evening before (Sport, Schwimmen, FreiDay) and the Hort end time — never the individual subjects. Adults: the **deviation** from their baseline, as a filled band; the baseline itself stays a quiet muted chip, and under either a "Termine bis 17:00" line (FR-1.19) saying when that person is out of meetings. Bands span multiple columns where they span multiple days. | [15](15-module-school-timetable.md) |
| **Termine** | 3 fixed bands — Vormittag (< 12:00), Nachmittag (12–17), Abend (≥ 17:00) — 2 slots each, then "+n weitere" | Key appointments only (`importance='key'`), time above title, and a **dot per attendee** in their member colour at the right edge; four dots means the whole family. Day parts rather than a time axis: a wall display is read for "which afternoon is full", not for "what happens at 14:15". | [05](05-module-calendar.md) |
| **Warmes Essen** | 1 row | One warm meal a day — Mittag at the weekend, Abend on school days, with the slot named in the cell. Under it, one dot per member, filled when they are eating, hollow when not, plus who is cooking (as a name, not an icon) and a guest count. | [07](07-module-meals-shopping.md) |
| **Footer** | 1 line | Open tasks per member, shopping-list count, night-mode indicator | [06](06-module-tasks.md) |

**Why the zones carry no titles.** Narrow sunken bands separate the zones; the gutter
names every row — a member, a day part, "Warmes Essen" — so a title band over each zone
said nothing new, and its legend ("blass = Grundzustand", "Punkte = wer betroffen ist")
is learned once and then only costs height. *(Changed 2026-10-15: the three caption bands
with their legends took the room the zones needed for their two-line layouts at
1280×800. The legends live in the user documentation.)*

**Why the dot row matters.** "Wer isst mit?" is the single most-asked question in a
family's afternoon, and it is answerable from the presence and school data the system
already holds: `travel` or `away` over the meal slot means not eating; Hort past the care cutoff
(`meals.care_lunch_cutoff`, default 14:00) means the child is out for lunch. The dots are therefore mostly correct without anyone touching
them, and tapping the zone corrects a day in two taps. A multi-select that must be filled
in by hand would be empty by week three.

**Why only the deviation is loud.** In the reference household Lukas works from home most
days and Sabine is at home on the days she is not on Dienst; drawing that as a filled band
per member per day would make the
zone one solid block of colour in which the Tuesday office day and the two-day Dienstreise
disappear. So each member carries a **baseline** (`profile.default_presence`), rendered as
a muted chip, and only what departs from it gets a band. This also halves what has to be
entered: "Mo + Mi Dienst" is one series, and nothing at all is entered for a normal day.

**Why the school zone stays short.** Seven Stunden per child is a grey rectangle at
two metres. The wall carries the span plus what has to be packed the evening before; the
full grid is one tap away and lives on the children's iPads.

### Today, and the rest of the week

- Today's column is wider, brighter and bordered; the other six are legible but recede.
- A **"jetzt / als Nächstes"** line under the header names the next thing to happen today
  with a countdown ("in 25 Min: Zahnarzt, Mia"). This is the one piece of urgency the
  board carries; everything else is context.
- Past days this week are dimmed rather than removed. Monday still explains why the
  laundry basket is full.
- The week rolls over at a configurable point at the weekend (`board.rollover`, default
  Saturday 12:00, Q26) so that Sunday evening's planning session is looking at the week it is planning.

### Considered and rejected: merging the zones

The obvious criticism of the layout above is that it splits one thought in two. Lukas is
in the Homeoffice row and the Heizungswartung is in the Vormittag band, three centimetres
apart, and the reader has to join them — even though the appointment is only possible
*because* of the presence.

Two merged layouts were built and compared on screen ([mockup](mockups/kiosk-week-board.html)):

- **Person rows own their appointments.** One zone; each row carries a person's state and
  their appointments together, plus an "Alle" row for whole-family items. Reads beautifully
  per person; loses the sweep across the family that answers "which afternoon is full".
- **Person × day part.** Each day column split into three narrow strips, the presence drawn
  as a bar across the strips it covers and appointments sitting on it. Answers both
  questions and shows the Homeoffice/Heizung relationship literally — but at seven days the
  strips are too narrow for a title at 24 px.

**Decided 2026-09-02: keep them separate.** The week board is read first for "which
afternoon is full" and only then for "what is one person's day", and the split layout is
the only one of the three that keeps full-width titles at kiosk type sizes. The joining
work the reader has to do is real but small, and the `busy_until` line ("Termine bis
17:00") does most of it: it says in the presence zone what the appointments in fact imply.
A third rejected option — folding presence into the three day-part bands — would print
"Homeoffice" three times a day and still not answer "where is Hanna".

### Degradation rules

The board must never scroll and never break its geometry. In order:

1. Truncate long titles to one line with an ellipsis; the tap-through has the full text.
2. Beyond three appointments in a day, show two and "+2 weitere".
3. Beyond two presence bands for one person in a day, show the longest and a "+1".
4. On a narrow screen, the weekend collapses into one half-width column.
5. Never drop a zone. An empty zone is a statement; a missing zone is a bug.

**Accessibility decision, 2026-10-17 (A6/A7, `t_da411148`).** The 24 logical-pixel
minimum applies to all kiosk text, including initials, captions, counts and band
labels, after any fitting or transforms. Truncate at that minimum; do not shrink
text below it. Full labels remain available in the existing tap-through detail and
semantic names. Keep overflow counts readable and preserve each zone's purpose.

Respect system text scaling, including 200%, in all registers. Do not clamp or
replace the kiosk's text scaler to make the board fit. At larger text sizes, show
fewer summaries using the degradation rules above, while keeping the seven-day
geometry, all zones, readable overflow indicators and access to full detail. The
reference acceptance viewport is 1280×800 logical pixels in landscape, with the
reference household, in German and English. No RenderFlex overflow, overlapping
text or clipped controls is acceptable at 100%, 150% or 200%. This does not claim
that every appointment title fits in full on the board.

Past days and the night variant may recede through backgrounds, borders and visual
emphasis, not by making their information unreadable. Do not apply a fixed opacity
to an entire content subtree. Keep rendered text at **at least 4.5:1** against its
actual composited background in light, dark and night, including past days and
multi-day bands. This retains specs/17's existing stricter text-token rule rather
than relaxing large kiosk text to the WCAG AA 3:1 allowance. Night lowers glare,
not the acceptance threshold.

### Touch behaviour

Tapping is a shortcut into detail, never into editing — the wall display is the wrong
place to type, and a mis-tap while cooking must not be able to change data.

| Tap | Opens | Reverts |
|---|---|---|
| A day column | That day in full: every appointment, every child's lessons, every meal | 60 s |
| A child's row | That child's **Stundenplan for the week** — the paper timetable's own shape: numbered Stunden down the left with their bell times, weekdays across the top, today's column marked, Entfall struck through, Vertretung labelled, and a "morgen einpacken" line at the bottom | 60 s |
| An adult's row | That person's week: baseline, deviations, their appointments and what they are cooking | 60 s |
| The meal zone | The week's meal plan; two taps to correct who is eating | 60 s |
| A day's school cell (the `8:00–14:25`) | **That child's school day**: every Stunde with its bell times, subject and room, the long breaks between them, what is already over, plus Vertretung and Entfall in place — and the full week grid underneath with that day's column raised | 60 s |
| The footer's task count | The family task board, where a chore can be ticked as the tapped profile | 60 s |
| The footer's shopping count | The **tile picker** — recents, frequents and categories, no search field, writing to the default list (FR-8.12, [07](07-module-meals-shopping.md#on-the-wall)) | 60 s |
| Anywhere, after an avatar tap | The acting profile is set for that interaction only ([08](08-users-auth-permissions.md)) | 60 s |

Three mutations are reachable from the kiosk in v1, and only three: ticking a task,
correcting the "isst mit" dots, and adding something to the shopping list. Everything else
is read-only by design — the wall is where you find out what is true, not where you change
it.

### Freshness and failure

- Live via Supabase Realtime invalidations; a full refetch every 5 minutes as a belt-and-braces measure, because a
  wall display that has silently stopped updating is worse than one that is obviously
  offline.
- A live board says nothing about its freshness. When the connection is lost, or no
  refresh has succeeded for two refetch intervals, the header shows "zuletzt aktualisiert
  17:05", and a lost connection adds a muted banner. The last good board stays on screen
  (FR-8.10). *(Changed 2026-10-15: the permanent "aktualisiert vor 4 s" was dropped — on a
  board that is always current it was only noise, and it crowded the next-up line.)*
- Night variant from 21:00 (`device.night_hours`, per kiosk, default 21:00–06:00): dark ground, reduced contrast, meals and tomorrow's first
  appointment emphasised, everything else calmed down.

## Platforms and distribution

*Rewritten 2026-10-11: native apps replace the PWA. The constraints that shaped the old
section — no install prompt, push only from the home screen, no background sync, storage
eviction — no longer apply to the phones, iPads or wall tablet.*

| Device | Build | Arrives via |
|---|---|---|
| Parents' iPhones, children's iPads | Flutter iOS app | TestFlight ([ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md)) |
| Wall tablet, any Android phone | Flutter Android app | Play internal testing track |
| Work laptop | Flutter web build | The household's own server, which serves the web build of its release ([10](10-deployment-and-ops.md)) |

### Native reality, current as of 2026

These still constrain the design:

| Constraint | Consequence for WuselWall |
|---|---|
| iOS gives apps **no reliable background execution**; background fetch is opportunistic and often skipped | A reminder is handed to the OS ahead of time as a local notification, planned from data the app already holds and replaced whenever it changes (Q47), or pushed by a server; never a timer inside the app. Whatever needs a server event to happen first (a reward request) is a notice on Today instead, until a relay exists. The shopping outbox drains when the app resumes or connectivity returns, so pending state is still shown honestly. |
| Notifications need **permission**, asked once; a refusal is hard to undo | Ask from an explicit "Erinnerungen einschalten" button (an item on the getting-started card, [20](20-onboarding.md#the-getting-started-card)), never at first launch. |
| Push would travel through **Apple (APNs)** and, on Android, **Google (FCM)**, with the project's credentials (ADR-018) | Not in v1 (Q47). If a relay is built: payloads carry as little as the notification needs, nothing that would not be fine on a lock screen; provider choice [Q38](14-open-questions.md). |
| **TestFlight builds expire** after 90 days | Release at least quarterly; the pipeline makes that a tag. |
| The **web build** is a Flutter canvas, not HTML: a larger first download, no browser find-in-page, weaker screen-reader support than native | Acceptable for one adult on a laptop. The web build is the adult register only; it is never the kiosk and never a child's device. |
| iOS **App Intents, widgets and Live Activities** are now possible, but need native Swift alongside Flutter | Not in v1. Shortcuts still covers Siri ([12](12-mcp-and-assistants.md)); a widget for the open-task count is a natural M3 candidate. |

The app badge (open-task count) is available natively on both platforms and replaces the
Badging API plan.

## The wall display

> **Built 2026-10-15.** The wall shows only the appointments marked for the kitchen unless "Alle Termine" is ticked (FR-8.11): every day column then shows all its appointments. The kiosk reverts the switch to key-only when it goes idle. A newly paired wall display shows a one-time checklist (keep the app pinned, keep the screen on, leave it plugged in), and a kids' tablet a welcome screen.

The hardware is a decision worth making early because it constrains the UI.

| Option | Pros | Cons |
|---|---|---|
| **Cheap Android tablet running the WuselWall app pinned in kiosk mode** *(recommended)* | The native app, updated automatically from the Play internal track. Android's lock-task (screen pinning) keeps it in the foreground; the app keeps the screen on and dims for the night variant, and set as the tablet's home app it is what appears after a reboot. €120–180. | Scheduled screen-off and motion wake are no longer provided by a kiosk browser — the app does the dimming itself, and true screen-off needs device-owner provisioning or a smart plug. Another Android device to keep patched. |
| Android tablet + Fully Kiosk Browser showing the **web build** | Fully Kiosk's remote admin, motion wake and scheduling | The kiosk then runs the Flutter web build, which is heavier on a cheap tablet than the native app, and loses native push and offline. A fallback, not the plan. |
| Old iPad in Guided Access, running the iOS app | Free if you have one; excellent screen | Guided Access is a poor kiosk mode: no scheduled wake, awkward recovery after a reboot, and a TestFlight build that lapses after 90 days without a release. |

Whatever the hardware, the kiosk register needs: no scrollbars, no system chrome, a
realtime-driven refresh with a periodic fallback so it is never stale, a dark variant after 21:00, and
resilience to losing the network — a wall display showing an error screen is worse
than one showing yesterday's slightly stale plan.

**Landscape, and at least 1280×800.** The week board needs seven columns plus a row label
gutter; below roughly that width the weekend has to collapse (degradation rule 4) and the
board starts losing what makes it useful. Check the panel's actual resolution before
ordering, not the marketing diagonal — cheap 10" tablets in this price range are often
1280×800, which works, and occasionally 1024×600, which does not.

## Realtime and notifications

> **Built 2026-10-15.** Notifications are local only (Q47): on personal phones the app schedules a morning summary (default 07:00, the day's appointments and tasks, and the first appointment) and, if switched on, a reminder before each appointment. Settings are per person (Einstellungen → Erinnerungen). Nothing is sent to a server or a third party. Kiosk and kids' devices have no reminders.

- **Supabase Realtime** delivers live updates while the app is open: database triggers
  broadcast small invalidation messages (`board:changed`, `shopping:changed`) on a
  private per-household channel, and the client refetches. On reconnect, refetch rather
  than replaying missed messages.
- **What must reach a closed app**, and how v1 does it without push (Q47):
  - morning summary of today's tasks and events (per member, configurable time) — a local
    notification;
  - an event starting in N minutes — a local notification;
  - a reward redemption awaiting guardian approval — a notice on Today, the count on the
    Tasks tab and in the next morning summary ([16, step 10.5](16-setup-plan.md#step-10--journey-gaps-before-launch-m15));
  - a task verified and points credited — seen in the kid views the next time they open.

  A native push (APNs, FCM, through a relay the project would run) comes only if families
  miss these in practice.
- Each member controls their own notification set. Default to few: the fastest way to
  train a family to ignore an app is to notify them about everything in week one. The
  defaults — morning summary at 07:00 on, everything else off — are in
  [21](21-household-settings.md#notifications).
- **Local reminders** (built 2026-10-14, [14 Q47](14-open-questions.md)): Android and iOS schedule the morning summary and the event reminders on the phone itself, for the acting member on a personal device only, never on shared or kiosk devices. They are planned seven days ahead from data the app already has and replaced whenever it changes. Nothing leaves the device, and the system prompt appears only after a tap on *Erinnerungen einschalten*.
- The web build gets realtime but no push; the laptop has Outlook for that.

## Design system

Concrete values — palette, typefaces, icon sets, shape and motion tokens — are in
[17 — Design System](17-design-system.md); the rules below are what they implement.

- **Member colour is the primary wayfinding device.** Each person has a colour used
  consistently across calendar, tasks and board. Always paired with an initial or avatar,
  because colour alone fails for colour-blind viewers and at a distance (NFR-13).
- Type scale steps up per register: base 14–16 px adult, 18–20 px kid, 24–32 px kiosk.
- Touch targets: 44 px adult, 56 px kid and kiosk.
- Contrast WCAG AA minimum; the kitchen is bright in the morning and dim at night, so a
  dark variant is not cosmetic.
- Icons carry meaning for children who are still learning to read, so pick one coherent set and use it for chores,
  categories and rewards consistently.
- Motion: brief and purposeful — the points-fly-to-balance animation on task completion
  is doing real motivational work and deserves care.
- **Presence needs a second channel besides colour.** Six states across a household's
  members is more than colour can carry, so each state has a fill treatment as well: solid (arbeitet),
  hatched (Homeoffice), arrow-ended (Dienstreise), outlined (frei). Verified in greyscale
  before it ships (NFR-13).
- **Subjects get an icon each**, chosen from the same set as chores and categories. A
  first-grader reads 🏃 long before "Sport", and the icon is what survives being
  seen from two metres.
- Nothing in the kiosk register is smaller than 24 px (NFR-16). If a zone does not fit at
  that size, it loses content, not type size.

## Language

German and English UI, English code and documentation (NFR-14). Flutter's `gen-l10n` with
`app/l10n/app_en.arb` and `app/l10n/app_de.arb` from the first widget — every string is
always written in both, German is the default locale — and CI failing on any message
missing from either file. Retrofitting i18n into a finished UI is tedious. It also keeps user-facing strings
out of widgets, which makes them easier to review for tone — and tone matters when the
reader is seven. Strings produced on the server — push notifications, ICS summaries, MCP
and Shortcuts responses — live in one message file per language (German, English) in
`supabase/functions/_shared/`.
