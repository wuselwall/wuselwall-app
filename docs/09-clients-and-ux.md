# 09 — Clients & User Experience (B2)

Implements NFR-1 – NFR-5, NFR-13, NFR-14 and FR-5.4.

## One application, three registers

There is one PWA. It presents itself in three registers, chosen by the **device's**
configuration (`device.ui_register`), not by screen width. A child's iPad and a parent's
laptop can be the same physical size and still need different interfaces.

| Register | Devices | Character |
|---|---|---|
| **adult** | Laptop browser, parents' iPhones | Dense. Full navigation, keyboard shortcuts, bulk editing, all administrative screens. This is where planning happens. |
| **kid** | Children's iPads | Large. Icons before words, four or five destinations maximum, no destructive actions, generous animation and feedback. |
| **kiosk** | Wall display | Glanceable. A read-first **week board**, no navigation chrome, huge type, tap-to-act on a small set of things, auto-revert to home after 60 s. |

Responsive layout still applies within each register — the adult register must work on a
phone — but the register itself is a device property.

## Screens by register

**adult**
- Today (agenda + tasks + tonight's meal + list count)
- Calendar: day / 3-day / week, presence bands, the rota month-grid editor
- Stundenplan: the grid per child, exceptions, terms, bell times, holidays
- Tasks: my tasks, family board, definitions admin, approvals
- Meals: week grid, recipes
- Shopping: list, catalogue, stores
- Settings: members, devices, feed tokens, rewards, assistants, audit log, school and
  subjects

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

**Mockup:** [`docs/mockups/kiosk-week-board.html`](mockups/kiosk-week-board.html) —
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

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ Mittwoch, 2. September · 17:42     KW 36     ● Als Nächstes: 18:30 Chili sin Carne  │
├──────────┬─────────┬─────────╥─────────╥─────────┬─────────┬────────┬──────────────┤
│  KW 36   │ Mo 31.8.│ Di 1.9. ║ Mi 2.9. ║ Do 3.9. │ Fr 4.9. │ Sa 5.9.│ So 6.9.      │
│          │         │         ║  HEUTE  ║         │         │        │              │
├──────────┴─────────┴─────────╨─────────╨─────────┴─────────┴────────┴──────────────┤
│ WER IST WO · Schulzeit + Besonderes · blass = Grundzustand, kräftig = Abweichung    │
├──────────┼─────────┼─────────╥─────────╥─────────┬─────────┬────────┬──────────────┤
│ ● Lotta  │ 8–14:25 │ 8–14:25 ║ 8–14:25 ║ 8–14:25 │ 8–13:35 │  frei  │  frei        │
│    9     │         │ FreiDay ║ Sport   ║ Sport   │ Sport   │        │              │
│ ● Hanna  │ 8–11:30 │ 8–12:45 ║ 8–11:30 ║ 8–12:45 │ 8–11:30 │  frei  │  frei        │
│    7     │Hort 15  │Hort 15  ║Schwimmen║Hort 15  │         │        │              │
│ ● Sabine │ DIENST  │·zu Hause║ DIENST  ║·zu Hause│·zu Hause│·zu Haus│·zu Hause     │
│          │8:30–14  │         ║8:30–14  ║         │         │        │              │
│ ● Lukas  │·Homeoff.│BÜRO HH  ║·Homeoff.║◀── Dienstreise Berlin ──▶│·Homeoff.│      │
├──────────┼─────────┼─────────╨─────────╨─────────┼─────────┼────────┼──────────────┤
│ TERMINE · Punkte = wer betroffen ist · gestrichelt = noch nicht sicher              │
├──────────┼─────────┼─────────╥─────────╥─────────┼─────────┼────────┼──────────────┤
│ Vormittag│10:00    │         ║         ║         │         │10:00   │11:00         │
│ bis 12   │Heizung ●│         ║         ║         │         │Turnier●●│Oma+Opa ●●●● │
│ Nachmit. │15:00    │14:30    ║16:00    ║15:30    │         │16:00   │              │
│ 12–17    │Turnen  ●│Zahnarzt●║Turnen  ●║Klavier ●│         │Grillen?│              │
│ Abend    │         │         ║19:30    ║         │18:00    │        │              │
│ ab 17    │         │         ║Elternab●║         │Kino  ●●●│        │              │
├──────────┼─────────┼─────────╨─────────╨─────────┼─────────┼────────┼──────────────┤
│ WARMES ESSEN · voller Punkt = isst mit · offener Punkt = nicht da                   │
├──────────┼─────────┼─────────╥─────────╥─────────┼─────────┼────────┼──────────────┤
│ eine     │ABEND    │ABEND    ║ABEND    ║ABEND    │ABEND    │MITTAG  │MITTAG        │
│ warme    │Kürbis-  │Nudel-   ║Chili    ║Fisch-   │Flamm-   │Pesto   │Braten        │
│ Mahlzeit │suppe    │auflauf  ║sin Carne║stäbchen │kuchen   │        │              │
│          │●●●● Sab │●●●● Luk ║●●●● Sab ║●●●○ Sab │●●●○ Sab │●○○● Luk│●●●● +2 Gäste │
├──────────┴─────────┴─────────╨─────────╨─────────┴─────────┴────────┴──────────────┤
│ Heute offen: Lotta 2 · Hanna 1 · Sabine 1    Einkaufsliste 7   aktualisiert vor 4 s │
└────────────────────────────────────────────────────────────────────────────────────┘
```

### The zones

| Zone | Height | Contents | Source |
|---|---|---|---|
| **Header** | 1 line | Full date, clock, calendar week, freshness marker | — |
| **Wer ist wo** | 4 rows, one per member, always in the same order | Children: the school-day span from the Stundenplan, plus the lessons worth knowing about the evening before (Sport, Schwimmen, FreiDay) and the Hort end time — never the individual subjects. Adults: the **deviation** from their baseline, as a filled band; the baseline itself stays a quiet muted chip, and under either a "Termine bis 17:00" line (FR-1.19) saying when that person is out of meetings. Bands span multiple columns where they span multiple days. | [15](15-module-school-timetable.md) |
| **Termine** | 3 fixed bands — Vormittag (< 12:00), Nachmittag (12–17), Abend (≥ 17:00) — 2 slots each, then "+n weitere" | Key appointments only (`importance='key'`), time above title, and a **dot per attendee** in their member colour at the right edge; four dots means the whole family. Day parts rather than a time axis: a wall display is read for "which afternoon is full", not for "what happens at 14:15". | [05](05-module-calendar.md) |
| **Warmes Essen** | 1 row | One warm meal a day — Mittag at the weekend, Abend on school days, with the slot named in the cell. Under it, one dot per member, filled when they are eating, hollow when not, plus who is cooking (as a name, not an icon) and a guest count. | [07](07-module-meals-shopping.md) |
| **Footer** | 1 line | Open tasks per member, shopping-list count, night-mode indicator | [06](06-module-tasks.md) |

**Why the dot row matters.** "Wer isst mit?" is the single most-asked question in this
household's afternoon, and it is answerable from the presence and school data the system
already holds: `travel` or `away` over the meal slot means not eating; Hort past 14:00
means the child is out. The dots are therefore mostly correct without anyone touching
them, and tapping the zone corrects a day in two taps. A multi-select that must be filled
in by hand would be empty by week three.

**Why only the deviation is loud.** Lukas works from home most days and Sabine is at home
on the days she is not on Dienst; drawing that as four filled bands a day would make the
zone one solid block of colour in which the Tuesday office day and the two-day Dienstreise
disappear. So each member carries a **baseline** (`profile.default_presence`), rendered as
a muted chip, and only what departs from it gets a band. This also halves what has to be
entered: "Mo + Mi Dienst" is one series, and nothing at all is entered for a normal day.

**Why the school zone stays short.** Seven Stunden × two children is a grey rectangle at
two metres. The wall carries the span plus what has to be packed the evening before; the
full grid is one tap away and lives on the children's iPads.

### Today, and the rest of the week

- Today's column is wider, brighter and bordered; the other six are legible but recede.
- A **"jetzt / als Nächstes"** line under the header names the next thing to happen today
  with a countdown ("in 25 Min: Zahnarzt, Mia"). This is the one piece of urgency the
  board carries; everything else is context.
- Past days this week are dimmed rather than removed. Monday still explains why the
  laundry basket is full.
- The week rolls over at a configurable point at the weekend (leaning: Saturday 12:00,
  Q23) so that Sunday evening's planning session is looking at the week it is planning.

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

### Touch behaviour

Tapping is a shortcut into detail, never into editing — the wall display is the wrong
place to type, and a mis-tap while cooking must not be able to change data.

| Tap | Opens | Reverts |
|---|---|---|
| A day column | That day in full: every appointment, both children's lessons, both meals | 60 s |
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

- Live via SSE; a full refetch every 5 minutes as a belt-and-braces measure, because a
  wall display that has silently stopped updating is worse than one that is obviously
  offline.
- A subtle "aktualisiert vor 4 s" in the header, which turns into "zuletzt aktualisiert
  17:05" and a muted banner when the connection is lost. The last good board stays on
  screen (FR-8.10).
- Night variant from 21:00: dark ground, reduced contrast, meals and tomorrow's first
  appointment emphasised, everything else calmed down.

## PWA

- Web app manifest: `display: standalone`, portrait and landscape, maskable icons,
  `theme_color` matching the app chrome.
- Service worker: precache the application shell, stale-while-revalidate for data reads,
  and the shopping outbox described in [07](07-module-meals-shopping.md).
- Installability verified on real hardware before v1 is called done — an iOS PWA that
  "should work" and one that does are different things.

### iOS reality, current as of 2026

These constrain the design and are not negotiable:

| Constraint | Consequence for GoombaWall |
|---|---|
| No install prompt; the user must tap Share → Add to Home Screen | Ship a short illustrated instruction card, shown once per iOS device. Nobody discovers this by themselves. |
| Web push works **only after** the PWA is on the home screen, and needs a permission prompt triggered by a user gesture | Ask for notification permission from an explicit "Turn on reminders" button inside the app, never on first load. Do this **after** add-to-home-screen, or the request silently fails. |
| Web push **does** work in the EU. Apple's 2024 plan to remove home-screen web apps there was reversed. | No fallback plan needed on this point. |
| No Background Sync, no Periodic Background Sync, no Background Fetch | Every reminder is a server-side push. Never schedule anything client-side. The shopping outbox drains on next open, not in the background — so show pending state honestly. |
| Storage is evicted under pressure and after long disuse | IndexedDB is a cache. The outbox is the only irreplaceable thing in it; drain it eagerly. Request persistent storage where available, but do not rely on the grant. |
| Badging API works on iOS 16.4+ | Use it for the open-task count. Cheap, and genuinely nice on a home screen. |

Nothing here forces a native app. Revisit only if you later want Siri App Intents,
Lock Screen widgets, or Live Activities — see [12](12-mcp-and-assistants.md) for why
Shortcuts covers the Siri case without them.

## The wall display

The hardware is a decision worth making early because it constrains the UI.

| Option | Pros | Cons |
|---|---|---|
| **Cheap Android tablet + Fully Kiosk Browser** *(recommended)* | Real kiosk mode, scheduled screen on/off, motion-wake, remote admin, auto-restart, brightness control. €120–180 all in. | Another Android device to keep patched. |
| Old iPad in Guided Access | Free if you have one; excellent screen | Guided Access is a poor kiosk mode: no scheduled wake, no motion detection, awkward recovery after a reboot. Also the 7-day storage-eviction rule bites if it sits unused. |
| Raspberry Pi + touchscreen + Chromium kiosk | Fully controllable, cheap to run | Fiddly to build, mediocre touch panels at this price, one more Linux box to maintain |

Whatever the hardware, the kiosk register needs: no scrollbars, no browser chrome, a
polled or SSE-driven refresh so it is never stale, a dark variant after 21:00, and
resilience to losing the network — a wall display showing a Chrome error page is worse
than one showing yesterday's slightly stale plan.

**Landscape, and at least 1280×800.** The week board needs seven columns plus a row label
gutter; below roughly that width the weekend has to collapse (degradation rule 4) and the
board starts losing what makes it useful. Check the panel's actual resolution before
ordering, not the marketing diagonal — cheap 10" tablets in this price range are often
1280×800, which works, and occasionally 1024×600, which does not.

## Realtime and notifications

- **SSE** (`/events`) delivers live updates while a client is open. Auto-reconnect with
  backoff; on reconnect, refetch rather than replaying missed messages.
- **Web Push (VAPID)** for anything that must reach a closed app:
  - morning summary of today's tasks and events (per member, configurable time)
  - an event starting in N minutes
  - a reward redemption awaiting guardian approval
  - a task verified and points credited
- Each member controls their own notification set. Default to few: the fastest way to
  train a family to ignore an app is to notify them about everything in week one.

## Design system

- **Member colour is the primary wayfinding device.** Each person has a colour used
  consistently across calendar, tasks and board. Always paired with an initial or avatar,
  because colour alone fails for colour-blind viewers and at a distance (NFR-13).
- Type scale steps up per register: base 14–16 px adult, 18–20 px kid, 24–32 px kiosk.
- Touch targets: 44 px adult, 56 px kid and kiosk.
- Contrast WCAG AA minimum; the kitchen is bright in the morning and dim at night, so a
  dark variant is not cosmetic.
- Icons carry meaning for the 7-year-old, so pick one coherent set and use it for chores,
  categories and rewards consistently.
- Motion: brief and purposeful — the points-fly-to-balance animation on task completion
  is doing real motivational work and deserves care.
- **Presence needs a second channel besides colour.** Six states on four members is more
  than colour can carry, so each state has a fill treatment as well: solid (arbeitet),
  hatched (Homeoffice), arrow-ended (Dienstreise), outlined (frei). Verified in greyscale
  before it ships (NFR-13).
- **Subjects get an icon each**, chosen from the same set as chores and categories. The
  seven-year-old reads 🏃 long before he reads "Sport", and the icon is what survives being
  seen from two metres.
- Nothing in the kiosk register is smaller than 24 px (NFR-16). If a zone does not fit at
  that size, it loses content, not type size.

## Language

German UI, English code and documentation (NFR-14). Put an i18n layer in from day one
(`svelte-i18n` or equivalent) with German as the only shipped locale. Retrofitting i18n
into a finished UI is tedious; adding a second locale to a prepared one is trivial. It
also keeps user-facing strings out of components, which makes them easier to review for
tone — and tone matters when the reader is seven.
