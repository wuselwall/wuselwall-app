# WuselWall friction audit (from code and specs)

Read on branch `feat/a-lighter-day` just before #123 merged, 2026-10-24.
Method: read-only. Code under `app/lib`, specs 09/14/20/21/24, German user docs under `docs/`.
No `.codegraph/` index exists in the worktree, so everything was read directly.
Paths are relative to `app/lib/` unless they start with `specs/`, `docs/` or `supabase/`.
Effort: S = under a day, M = a few days, L = a week or more. Impact: low / med / high.

Not verified (no device, no live server): visual layout, real timings, what `api.task_undo` allows
for another person or after a time (only the client side was read), and whether the OCR container
is on the target server.

---------------------------------------------------------------------------------------------

## 0. Cross-cutting findings

1. **Quick-add exists nowhere on Today.** `features/today/ui/today_section.dart` has no `fab`
   (HomeSection supports one, `features/home/application/home_section.dart:33`). Only
   Calendar has a FAB (`features/calendar/ui/calendar_section.dart:30-34`). Today shows an
   "add event" button only in the fully-empty state (`today_page.dart:283-297`).
2. **Pending approvals are invisible outside the Tasks tab.** Spec 14 line 48 promises "guardians
   see pending approvals as a notice on Today". `NoticeKind` has only `join` and `signIn`
   (`today/domain/notice.dart:2-9`). `approvalCountProvider` (`tasks/application/tasks_providers.dart:78`)
   is read only in `tasks_body.dart:20`, as a badge inside the tab bar. The bottom NavigationBar
   (`home/ui/register_home_page.dart:110-120`) has no badge. A kid's reward request or a chore
   awaiting a check reaches a parent only if the parent opens Tasks, then Freigaben.
3. **Settings that look real but do nothing.** `device.night_hours` is a *Basic* setting
   (`settings/ui/household_settings_page.dart:53`). Night is hard-coded 21:00-06:00
   (`app/theme/night.dart:6`, no reader of the key anywhere in `lib/`). `device.idle_revert_seconds`
   (Advanced, line 137) is not read either: `IdleReverter` defaults to 60 s
   (`identity/ui/acting_profile_bar.dart:148`) and `showBoardDetail` has a fixed 60 s
   (`board/ui/board_detail.dart:18`). `notify.task_verified` and `notify.redemption_request`
   ("A notification when ...", `setting_labels.dart:109-116`) have no consumer; spec 14 line 48
   says they are "not built". Docs `docs/settings/household.md:22` advertises them, and
   `docs/settings/household.md:7` lists "die Nachtzeit dieses Geräts" among the Basic settings.
4. **Pre-sign-in screens are not counted by the "smooth" metric.** NFR-17 and
   `test/journeys/onboarding_journeys_test.dart:132-193` assert at most 3 screens *after*
   sign-in. From a fresh install the founder actually sees 8 screens (see J1).
5. **Silent redirects eat intent.** Opening an invitation link while signed in with a household,
   and a pairing link while signed out, both fail with no message (J2, J1b).

---------------------------------------------------------------------------------------------

## J1. First run (parent, phone, store build)

### J1a. Founder on the phone

| # | Screen | What the person does | Code |
|---|---|---|---|
| 1 | S0 "Which server?" | Types the server address (or scans the install script's QR, with an OS camera prompt), taps Connect. Or "Try without a server". | `setup/ui/server_choice_page.dart:158-196`, `_connect` 87-109 |
| 2 | Front door | Taps "Continue with email". It is an `OutlinedButton`, visually weaker than a primary action. | `setup/ui/setup_page.dart:420-424` |
| 3 | E1 | Types the email, taps Continue. | `sign_in_page.dart:143-193` |
| 4 | E2 | Leaves for the mail app, reads 6 digits, comes back, types or autofills. The sixth digit auto-submits. There is no "open mail app" button. | `email_code_page.dart:421-439` |
| 5 | E3 | Chooses how to sign in next time (code vs password) and taps Continue. | `sign_in_choice_page.dart:551-577, 587-622` |
| 6 | H1 "New family" | Family name is prefilled from the account surname, name prefilled, colour defaulted, examples checkbox on. Person edits if needed and taps "Create family". In `code` mode without a setup link there is an extra founder-code field. | `household/ui/new_family_page.dart:81-85, 241-259, 285-305, 307-319` |
| 7 | H2 "Who else is in your family?" | Types kids' names, "Add person" per extra row, flips Kind/Adult if needed, taps Done. | `household/ui/members_page.dart:37, 146-165` |
| 8 | Today | Getting-started card on top. | `today/ui/today_page.dart:268-274` |

Count: 8 screens, about 6 button taps, and typing of server, email, 6 digits, names. Seven screens when the
server arrives by link or QR. The router enforces the order in `app/router.dart:146-189`.

Friction:
- **E3 is a forced decision on every new account** (`sign_in_choice_page.dart:541` defaults to `code`). It adds a screen
  to both J1 and J2 for a choice most people leave at the default. Fix: default to code silently and
  keep "set a password" in Settings (it already exists, `settings_page.dart` "Sign-in" section). Needs a
  spec 20 change, plus a change to `test/journeys/onboarding_journeys_test.dart`. Effort S, impact med.
- **No "open mail app" or paste button on E2.** Fix: `url_launcher` is already a dependency
  (`pubspec.yaml:43`); add a mail-app button. Effort S, impact low-med.
- **The primary front-door action is an OutlinedButton** (`setup_page.dart:420`) while "I have an invitation code" and the pairing link
  are TextButtons. Effort S, impact low.
- **H2 can duplicate H1's work.** Skip leaves the child chores of the examples uncreated
  (`members_page.dart:76` only calls `completeExamples()` when a child was added). After Skip the
  household has founder-only example chores and the Chores tab no longer offers the starter pack (it
  shows only when the list is empty, `tasks/ui/tasks_chores_tab.dart:31-40`). Effort S, impact low-med:
  re-offer the starter pack when children exist but have no chore.
- **Examples checkbox on H1 vs spec H2.** Spec 20 draws it on H2; the code has it on H1 (spec note at "J1" says so). Fine, just keep the drawing in sync.
- **`Skip` and `Done` do the same when no name is typed.** Low.

### J1b. Pairing the wall display

Parent's phone (`identity/ui/device_pair_page.dart`):
1. Getting-started item "Wall display" opens `devicePair?kind=wall_display` (`today/ui/getting_started_card.dart:171-179`),
   or Settings, then the "Connect device" button (`settings_page.dart` Devices section). From Settings the
   default kind is `kidTablet` (line 47), so a wall display needs an extra chip tap.
2. Scan (camera prompt on first use) or type the code (`_entry`, 211-236).
3. Review: kind chips, child dropdown for a child's phone, name prefilled, tap "Connect"
   (`_review`, 238-312).
4. First shared device only: set a 6-digit PIN twice, 12 digit taps (`PinSetupPage` 323-384).
5. Snackbar "approved".

About 3 taps plus the OS camera permission; 15 taps the first time.

Wall tablet (`setup/ui/pair_page.dart`, `setup/ui/first_run_page.dart`):
1. Install, then **S0 again: the server address must be typed or scanned on the tablet**
   (`server_choice_page.dart:158-196`). This breaks rule 3 of spec 20 ("Nobody types on a shared device")
   and the docs' promise "Die Wandanzeige verbindest du ohne Tippen von Code" (`docs/guide/wall.md`, "Verbinden").
   The only no-typing route is to scan the QR under Settings, Advanced, Server on a connected phone
   (`settings_page.dart:898`, `docs/guide/install.md`). It is hidden behind the Advanced switch.
2. Front door: the pairing entry is the third, quietest control (`setup_page.dart:449-453`). On a wall
   tablet it is the *only* relevant one.
3. P1 shows QR and code, polls every 2 s, renews itself (`pair_page.dart:32-37, 62-122`).
4. Greeting for 2 s (`pair_page.dart:39, 118`), then the one-time kiosk checklist (pin app, keep awake,
   power) and "Done" (`first_run_page.dart`), then the board.

Friction and fixes:
- **Server entry on the tablet.** Fix: show "Show this server to a new device" (QR) as a button inside
  `DevicePairPage` (entry state) and in the Devices section, outside Advanced. On the tablet, S0's scan button
  already accepts a server QR (`server_choice_page.dart:111-128`). Effort S, impact med-high.
- **Front door does not know it is on a tablet.** Fix: on a large landscape screen, or after a
  "This is a shared device" choice at S0, make "Connect family tablet or wall display" the primary
  action. Effort M, impact med.
- **Pairing link opened while the phone is signed out drops the code** (`app/link_host.dart:79`
  goes to Routes.setup, no message). Effort S, impact low.
- **The new wall's first screen is an empty board** with no hint that things are added on the phone. Effort S, impact low.
  (`board/ui/week_board_page.dart` has no empty-household state.)
- **The kiosk checklist is a text wall the installer reads once.** Fine, it is one-time.

### J1c. First useful screen

Today on a brand-new family:
- `NoticeCards`, `ProposalCards`, `GettingStartedCard`, `RitualCards`, then the agenda (`today_page.dart:268-282`).
- The card lists up to 4 open items, each with its own "Not needed" button (`getting_started_card.dart:35, 129-155`):
  invite partner, connect tablet, wall display, calendar feed, timetable. About 300 dp on a phone, so the
  agenda is below the fold on day 1, and permanently below it for a joined guardian (J2).
- Each row dismisses separately. There is no "hide the whole card".
- The empty-state `todayEmpty` "Nothing is planned for today yet. Enjoy the quiet." is shown *below* the card with one "New event" button.
- Seeded example chores are for the children; the founder's Today has no tasks (`todayAgendaProvider` filters to the acting profile, `today_providers.dart:93-98`).

Fixes: (a) cap the card at 2 open items on screens under ~700 dp, with a "N more" expander; (b) a single
"Hide for now" on the card header; (c) when nothing is planned, put "New event" and "Shopping list" as the two
buttons. Effort S, impact med.

---------------------------------------------------------------------------------------------

## J2. Second parent joins by invitation

### Inviter (guardian, personal device)

1. Getting-started "Invite partner" (or Settings, Members, "Invite adult"): `inviteAdultFlow` (`invitations/ui/invite_flow.dart:37-65`).
2. Dialog: **name required**, role segmented (default guardian), email optional (`invite_flow.dart:258-306`). The invitee can
   rename themselves at join (`join_invite_page.dart:200-206`), so the required name is a forced decision.
3. Result dialog: code, server, QR, hint. The primary (filled) button is **Done**; **Share** is a TextButton (`invite_flow.dart:187-206`).
   Sharing is the whole point of the dialog.

About 3 taps plus a typed name.

Bugs and friction:
- **The card's "Invite partner" always creates a new adult profile** (`getting_started_card.dart:166-169` calls
  `inviteAdultFlow` with no member; `supabase/migrations/20261015103000_invitations.sql:203-209` inserts a profile with no dedupe).
  A founder who typed their partner as "Adult" on H2 gets a second "Julia". Fix: when account-less adults
  exist, show them first as choices ("Julia" / "Someone else"). Effort S, impact med.
- Make **Share** the filled button and open the share sheet straight away after creating. Effort S, impact med.
- Pre-fill the name from the optional email local part, or make the name optional. Effort S, impact low.

### Invitee

Via link, app installed (`link_host.dart:71-76`; screens as in `test/journeys/onboarding_journeys_test.dart:198-258`):
1. Tap link, then **InviteCodePage** with the secret prefilled and auto-checked; banner shows household and inviter; tap "Continue to sign-in"
   (`invite_code_page.dart:60-136`). One extra screen with a tap even though the link is already valid.
2. E1: email, Continue. 3. E2: 6-digit code. 4. E3 sign-in choice (forced decision, see J1a).
5. Join confirmation "You are Julia in Familie X", name and colour editable, tap "Join" (`join_invite_page.dart:119-172, 193-243`).
6. Today.

5 screens and about 4 taps plus email and code; target in spec 20 is "at most 2 screens after sign-in", which holds only because E1-E3 are excluded.

What can go wrong, and what the app does:
- **App not installed:** the web page shows store buttons; after installing, the person must tap the link again (docs
  `docs/guide/setup.md` section 3: "öffne den Link danach noch einmal"). Designed (NFR-9), but it is the largest drop-off risk. A cheap
  mitigation is to show the code in large type on the landing page and, in the store app, a "Paste invitation" button on S0 (S0 already parses codes,
  `server_choice_page.dart:87-93`). Effort S, impact med.
- **Code only, no server:** must type `K7QM3XRP@host` (`serverLead`, `app_en.arb`); the landing page / share message names the server, but typos are likely. Effort S: add a
  "paste" button.
- **Expired, used or withdrawn:** `inviteNoLonger` "Ask the person who invited you for a new one." Good (`join_invite_page.dart:150-160`).
- **Dead end: already in a household.** Spec 20 says "Du bist schon in Familie X" plus "the way to leave it". Code: an invitation link opened
  by a device whose account already has a household is sent home silently (comment at `link_host.dart:75` plus `app/router.dart:433-442`:
  `Ready()` sends every setup path to home). This is precisely the second parent who first created their own empty family. No message, no leave button.
  Fix: in `_open`, if `Ready`, show a dialog "You are already in X. Leave it and join Y?" linking to `leave_family_tiles.dart`. Effort S, impact med-high.
  (`join_invite_page.dart:161-167` shows `inviteAlreadyIn` text only, with no action either.)
- **Email-matched path (H0)** works without a code (`invite_pending_page.dart:340-350`). Good, but the guardian must have typed the email.
- Mail delays: resend is gated for 60 s; spam hint only after the timer (`email_code_page.dart:457-476`). OK.

What the second parent sees first: Today with the same Getting-started card (`gettingStartedProvider` returns items for every guardian,
`today_providers.dart:21-30`), so a person who only came to read the calendar sees "Connect tablet", "Wall display", "Add the timetable" as their to-do list.
A member-role adult (au pair) gets no card. Fix: for a guardian who joined an existing household, show only the per-person items (reminders, PIN) and hide the household ones until a week has passed. Effort S-M, impact med.
The founder sees "Julia joined" as a notice card (`notice_cards.dart`), which is good.

---------------------------------------------------------------------------------------------

## J3. Fastest path to add an event, chore, meal, shopping item

Counts are taps after the app is open on Today, parent's phone, excluding typing.

| Item | Path | Taps | Notes |
|---|---|---|---|
| Event | Calendar tab, FAB "New event" (`calendar_section.dart:30`), type title, Save (`event_editor_page.dart` end) | 3 | Start defaults to the next full hour, 1 h, attendee = me (`event_editor_page.dart:105-118`). Another day: date picker modal (+2 taps), time picker (+2). |
| Chore | Tasks tab, **Chores** tab (3rd of 5), "New chore", type title, **pick at least one person**, Save | 5 | Editor is full screen with 11 controls (`task_editor.dart`). |
| Meal | Meals tab, tap a day card, tap a suggestion or type, Save (`meals/ui/meal_editor_sheet.dart`) | 3-4 | History-based suggestions "often/rare" are one tap. Good. |
| Shopping | Shopping tab, tap a tile (or type and Enter) | 2 | Tiles add on tap (`shopping_page.dart:748`); Enter adds the top hit (791-794). Best flow in the app. |

From Today: none of the four works directly. A Today shopping row appears only when the list is non-empty (`today_page.dart:344-357`). Event rows are not tappable (`today_page.dart:408-424`, no `onTap`), so correcting an event means Calendar tab, then find it.

From the wall (by design, spec 09 lines 242-261): only three writes exist: tick a chore, correct "isst mit", add to shopping.
Shopping from the wall: footer tap, tap tile = 2 taps (`board/ui/board_footer.dart:95-146`), but with nobody chosen the chore tick shows a snackbar that sits under the dialog (comment at `task_actions.dart:23`),
so the only cue is the label in the profile bar. Events, chores and meals cannot be added from the wall; nothing hands the intent to a phone.
(A Siri shortcut for shopping exists, but needs 5 manual steps and a key: `docs/settings/shortcuts.md`.)

Friction and fixes (ranked):
1. **Event editor ignores the viewed day.** `EventEditArgs.date` is documented ("A new event may name the tapped date", `calendar/ui/event_edit_args.dart:3-12`) and read
   (`event_editor_page.dart:111`), but **nothing ever passes it**: the only `EventEditArgs(...)` call (`calendar_tiles.dart:230`) is for editing. Viewing next Friday and pressing "New event" starts today.
   Fix: pass the calendar's selected day from the FAB. Effort S, impact med-high.
2. **A quick event is hidden from the wall.** The editor preselects the acting profile as the only attendee (`event_editor_page.dart:117`), and the household default
   `calendar.key_default = whole_family` (`supabase/migrations/20261013120000_household_settings.sql:66`, `calendar/ui/editor/event_draft.dart:255-269`) only marks an event as "key" when all active members attend. So the most common
   path (me, a quick title) yields an event the kitchen wall does not show unless the parent finds "Show on the kitchen display" (a switch below location, notes and tentative). The wall's "All events" toggle
   papers over it. Fix: show a live line under the attendee chips ("Not shown on the kitchen display"), with the toggle next to it; consider defaulting key to on when there is exactly one attendee. Effort S, impact med-high.
3. **Chore editor forces a decision.** Default assignment is `rotating` with an empty pool (`task_editor.dart:102-103`), so saving a title alone fails with "Pick at least one person" (124-133). Default repeat is "once" (line 94), which is rarely what a chore is. Fix: preselect all active children (or "open for anyone") and default to daily/weekly per `taskDefaults`. Effort S, impact high (this is the main setup action of the Tasks module).
4. **No quick-add on Today.** Add an extended FAB (event, chore, shopping item, meal) to `todaySection`. Effort M, impact high. Also: tapping an event row on Today should open the editor; tapping the shopping row should land with the keyboard ready. Effort S.
5. **Tasks has no FAB** and "New chore" sits in the third of five tabs (`tasks_body.dart:21-61`, `tasks_chores_tab.dart:44-56`). Effort S, impact med: FAB on the Today and Chores tabs.
6. **Meals on a phone starts at Monday** (`meals_page.dart` list of 7 `_DayCell`s with no scroll to today). Fix: scroll to today. Effort S, impact low-med.
7. **Event delete has a confirm dialog but no undo** (`event_editor_page.dart:_delete`); tasks and meals have snackbar undo. Effort S-M, impact low.

---------------------------------------------------------------------------------------------

## J4. A kid completes a chore and sees the reward

Kid tablet after pairing: kid welcome once (`first_run_page.dart`), then `KidHome` (`kid/ui/kid_home.dart`):
1. "Hi! Tap your name" picker (`kid_picker.dart`, tap 1). Nobody is chosen at start; **a chosen child never reverts on a kid tablet** (only the kiosk has `IdleReverter`, `register_home_page.dart:38-45`), so a sibling can tick as the previous child until someone taps the avatar bar.
2. "Mein Tag": greeting card with Wusel and balance, then new badge, week review, table question, then "My chores" (`kid_today_page.dart:73-93`). On a phone the first chore card is about 250 dp down; on a tablet it is in view.
3. Tap a chore card (tap 2): optimistic tick, coin flies to the balance pill, confetti and a cheer on the last chore, snackbar "done!" with Undo for 5 s (`kid_today_page.dart:200-265`).
4. Rewards: Points tab (tap 3), reward cards with a progress bar and "N more points", a big Ask button (tap 4) (`kid_points_page.dart:111-160`, `_RewardCard`).

This flow is good: 2 taps from open to reward feedback, undo, no red marks.

Friction:
- **Verification-required chore:** `pointsCredited` is 0, so no coin; card says "being checked" (`kid_today_page.dart:308`). The kid gets no later signal when the parent approves, and **the parent gets no signal that a check is waiting** (cross-cutting finding 2). The loop "kid ticks, parent never sees it" is the biggest reward-loop break. Fix: approvals card on Today plus a nav badge (S, high). Optionally a "+5 points!" notice on the kid's next Today view (S, med).
- **Rewards list has no empty state** (`kid_points_page.dart:112-130`): a family that declined the examples shows "Rewards" and nothing under it. Fix: one line "Ask a grown-up to add rewards" (S, low-med).
- **No cancel for a waiting reward request** (state only shows hourglass, `_RewardCard`). Effort S, impact low.
- **An accidental tick cannot be undone after the snackbar.** The adult list disables the button for a ticked task (`tasks/ui/tasks_today_tab.dart:206`), the wall passes `offerUndo: false` (`board/ui/details/task_board_detail.dart:296-305`), and `api.task_undo` is called only from the two snackbars (`task_actions.dart:90-105`, `kid_today_page.dart:267-286`). A wall mis-tap, the commonest one, is permanent unless the chore requires verification (then a guardian can decline). Fix: let a ticked card be tapped again to take the tick back (guardian or same actor, whatever the server allows). Effort M (check the server's `task_undo` rules), impact med.
- **Kid with no chores today** shows "You have no chores today." with no next step (`kid_today_page.dart:137-143`); fine.
- Dead end: Schedule tab, no children: "No child in the household yet." with no button (`school/ui/schedule_section.dart:65-67`). See J5.

---------------------------------------------------------------------------------------------

## J5. School timetable import (spec 24)

Photo path as built (paste path in brackets):
1. Getting-started "Add the timetable" (`getting_started_card.dart:173`) or Schedule tab setup card (`schedule_section.dart:45, 367-376`).
2. School page: school name + region (region prefilled from the household setting if one exists; H1 never asks, so usually the region picker: country, then state) and "Add school" (`school/ui/school_setup_page.dart:157-163, 339-465`). Then **the page stays on the school form** (bell times, terms, holidays, subjects sections all follow, lines 168-176).
3. "Next steps" card at top: a row per child without a timetable: row tap opens the **manual grid editor**, the trailing "Read in" text button opens the import (`school_setup_page.dart:190-240`).
4. Bottom sheet: "From text" / "From photo" (`timetable_import_menu.dart:72-100`; photo greyed out with a reason when the server has no OCR).
5. Photo: intro sheet and three sources (`timetable_scan.dart:75-110`), pick/shoot (2 taps), "being read" dialog, then preview (`timetable_import_page.dart`).
6. Preview: child (pre-chosen), school, term "(will be created)", grid, new-subject list with a create/take-as selector each, switch "create new subjects". "Apply" (`timetable_import_page.dart:480-647`).
7. After applying, the import pops back to wherever it was opened and shows a snackbar (`timetable_import_page.dart:_apply` end). From the school page that is the school form, not the timetable.

About 8-10 taps after the card, plus school name and region. [Paste: copy prompt, leave the app, photograph, hand to an assistant, copy the answer, return, paste, Read: 12+ steps across two apps.]

Friction and fixes:
- **The lead action is the slow one.** The Schedule tab's `_EnterCard` has the manual editor as the primary button and Import as a secondary outlined button (`schedule_section.dart:398-410`); spec 24's whole point is that import is the cheap path. In "Next steps" the row tap = manual, the small trailing text = import, which is ambiguous. Fix: make "Read in from a photo or PDF" the primary on both. Effort S, impact med.
- **Dead ends with no action:** `ScheduleBody` with school but no children shows "No child in the household yet." (`schedule_section.dart:65-67`); the import page without a child says "Add a child under Members first." (`timetable_import_page.dart:127-137`, an `EmptyView` without actions). Both should link to Settings, Members, add child. Effort S, impact med.
- **Photo of a timetable that reads no lessons** returns to the sheet with a snackbar, then the user must start again (`timetable_scan.dart:_busy`, error path). Effort S, impact low-med: offer "Try again" and "Enter by hand".
- **Many intermediate decisions on the preview** (per new subject create/take-as, child, school, switch). Defaults are sensible (scan preselects a same-group subject). OK.
- **After "Apply" the user does not see the timetable.** Fix: pop to the Schedule tab for that child (the code already selects the child: `selectedChildIdProvider.select(child.id)`). Effort S, impact low-med.
- **Docs vs code:** docs say "Tippe auf Schule einrichten" and "Schule anlegen"; strings are "Add school" (`app_en.arb` `schoolSetupCreate`). Minor, German catalogue not checked.
- **Written to the server in 5 separate calls, not atomically** (term, bell times, subjects, timetable, lessons: `timetable_import_page.dart:159-360`). A failure halfway leaves a term and subjects but no lessons. Spec 24 accepts this. Effort M if wanted, impact low.

---------------------------------------------------------------------------------------------

## J6. Daily glance: what comes first, is the important thing above the fold

### Adult Today (`today/ui/today_page.dart:268-282`)

Order today: notices, school proposals, getting-started card, rituals (birthday, Sunday review, table question during meals, next countdown, new meal wishes), then the agenda: events, my chores, the warm meal, shopping count.

Issues:
- On any day with a ritual card the agenda is pushed down; during the meal hour the table question appears above it. The agenda (the reason to open the app) should come first, rituals are enrichment. Fix: move `RitualCards` below `_Agenda` (birthday may stay on top). Effort S, impact med.
- Only my events and family-wide events are listed (`today_providers.dart:85-91`); a spouse's appointments, the kids' lessons and "who is where" are not on Today, only on the wall. The kids' school day is on its own tab. A one-line "Emma: school 8-13:15, Paul: free" strip would give the Today the glance the wall has. Effort M, impact med.
- Events and chores on Today are not actionable beyond ticking (no edit, no add).
- Tab state is remembered only in memory (`home/application/home_tab.dart`), so the app always opens on Today: good.
- A 6-destination bottom bar shows a label for the selected item only on phones (`register_home_page.dart:107-109`); the others are icons, with a tooltip. The meal and schedule icons are not self-explanatory for a new parent. Effort S, impact low: show labels, shorten them.

### Wall (`board/ui/week_board_view.dart`, `board_header.dart`)

The canvas is a fixed 7-column layout with no scrolling, so everything is "above the fold" by construction: header with clock, date, week number and the "Next" line; one row per member (who is where, school times); key appointments; the warm meal; a footer with open chores, countdowns and the shopping count.
- Good: next-up in the header, clock in 50 px type, today is highlighted.
- Only *key* events show (see J3, point 2). A family that never touches the switch sees an almost empty appointments zone. The "All events" toggle reverts by itself.
- The settings gear in the header opens the full Settings page as a pushed route (`board_header.dart:139-151`); **nothing returns the wall to the board afterwards.** `IdleReverter` wraps only the home route and only clears the acting profile (`acting_profile_bar.dart:166-173`); `showBoardDetail` dialogs close themselves after 60 s but the Settings page does not. A child poking the gear leaves the wall on Settings until someone presses back. Fix: pop to root on idle (or hide the gear on the kiosk behind a long-press). Effort S, impact med.
- A fresh household's wall shows empty cells without a pointer to the phone. Effort S, impact low.
- Offline handling is good (stale banner, last-updated time).

---------------------------------------------------------------------------------------------

## J7. Settings depth

Gear icon is on every home (adult app bar `register_home_page.dart:60-64`, kiosk header, kid top row). The Settings screen is one long list, in this order: Family (3 rows), Members (reorderable list), Devices (connect button, list), This device (reminders, language, appearance, getting started, versions, licences), then Advanced behind the app-bar chip (`settings/ui/settings_page.dart:105-300`).

| Task | Path | Taps |
|---|---|---|
| Language | gear, Language row, pick | 3 |
| Wusel off | gear, Household settings, scroll to "Mine", switch (`household_settings_page.dart:143-155` is the last section) | 3 + scroll |
| Region (holidays) | gear, Household settings, Region, 2-3 picker steps | 5 |
| Rename or recolour a member | gear, tap the member, edit | 3 |
| Connect a device | gear, scroll past the Members list, "Connect device" | 2 + scroll |
| Show server QR | gear, Advanced chip, scroll, Server section | 3 + scroll |
| Night hours | gear, Household settings, Device section, row (**does nothing**) | 4 |
| Restore the getting-started card | gear, "Getting started" | 2 |

Friction and fixes:
- The Members list expands in the middle and pushes "Devices" and everything under it down; "Connect device" is the second most common admin action. Fix: put Invite and Connect at the top as a two-button row. Effort S, impact med.
- Personal settings (Wusel, sounds, reminders) live inside the *household* settings page (section "Mine"), 3 taps deep and last. Fix: move them to "This device" on the main page. Effort S-M, impact med.
- Mixed navigation: `context.go` for sub-pages (`settings_page.dart:74-89`) with explicit Back handling, versus `context.push` elsewhere. Works, but each sub-page needs its own back override (`household_settings_page.dart` leading `BackButton`). Low.
- Dead settings (finding 3). Effort S to hide, M to wire; impact med because Basic promises a night-time control.
- The Advanced chip is a small `FilterChip` in the app bar (`settings_view_switch.dart`); "More settings" hint at the bottom of Basic. Fine.

---------------------------------------------------------------------------------------------

## Docs vs code

| Promise | Reality |
|---|---|
| Spec 14 l.48: guardians see pending approvals as a notice on Today | Not built; only a badge inside Tasks (finding 2) |
| `docs/settings/reminders.md:9`: morning summary includes "offene Belohnungen, die auf Freigabe warten" for guardians | `reminders/domain/reminder_plan.dart:82-111` counts events and chores only |
| `docs/settings/household.md:22`: notifications when a chore is confirmed or a reward requested | No consumer of `notify.task_verified` / `notify.redemption_request`; spec 14 says not built |
| `docs/settings/household.md:7` and spec 21: night hours are a per-device Basic setting | Hard-coded 21:00-06:00 (`app/theme/night.dart:6`) |
| Spec 21 l.241: `device.idle_revert_seconds` 30-300 s | Fixed 60 s (`board_detail.dart:18`, `acting_profile_bar.dart:148`) |
| Spec 20 J2: "Du bist schon in Familie X" and the way to leave it | Silent redirect to Today (`link_host.dart:75`, `router.dart:433-442`); text-only message at `join_invite_page.dart:161-167` |
| `EventEditArgs.date` "A new event may name the tapped date" | Never passed (`calendar_tiles.dart:230` is the only constructor call) |
| `docs/calendar/index.md:3`: "Der Kalender ist die Startseite der Erwachsenen" | Today is first and default (`home/application/home_tab.dart:6`) |
| `docs/guide/wall.md` "Verbinden": wall connects "ohne Tippen von Code" | True for the code, but S0 needs the server address typed or scanned on the tablet |
| Spec 20 "How smooth is checked": E2E asserts the screen count of J1 and J2 | Test asserts 3 and 2 screens *after* sign-in only (`onboarding_journeys_test.dart:192-193, 257-258`); S0, front door, E1, E2 (and E3) are outside the count |
| Spec 20 getting-started: passkey item | Not in `StartItem` (`today/domain/getting_started.dart`); spec says "when verified", so consistent |

Things checked and found to match: getting-started items and the 4-open cap, examples default on, H0 invitation-pending page, PIN deferred to the first shared device (G2), kiosk first-run checklist, wall allows exactly the three writes of spec 09, undo exists on adult and kid ticks, meal and shopping flows.

---------------------------------------------------------------------------------------------

## Ranked fix list (impact / effort)

| # | Fix | Effort | Impact | Where |
|---|---|---|---|---|
| 1 | Approvals card on Today and a badge on the Tasks nav icon (kid ticks and reward requests reach the parent) | S | high | `today/ui/notice_cards.dart`, `tasks/application/tasks_providers.dart:78`, `home/ui/register_home_page.dart:110` |
| 2 | Chore editor: preselect assignees (all children) and a sensible repeat | S | high | `tasks/ui/task_editor.dart:94-103, 124-133` |
| 3 | New event: use the viewed day, and surface "not shown on the wall" with its toggle | S | med-high | `calendar/ui/calendar_section.dart:30`, `calendar/ui/event_editor_page.dart:105-118`, `calendar/ui/editor/event_draft.dart:255` |
| 4 | Quick-add FAB on Today (event, chore, shopping, meal) | M | high | `today/ui/today_section.dart` |
| 5 | Invitation link while already in a household: explain and offer to leave | S | med-high | `app/link_host.dart:75`, `app/router.dart:433-442` |
| 6 | Drop E3 (default to code, keep password in Settings) | S | med | `setup/ui/sign_in_choice_page.dart`, `identity/application/sign_in_choice.dart`, spec 20 |
| 7 | Getting-started card: cap at 2 on phones, hide-all, hide household items from a joined guardian; "Invite partner" offers existing adults | S-M | med | `today/ui/getting_started_card.dart:35, 166-169`, `invitations/ui/invite_flow.dart:37-65` |
| 8 | Wall/tablet set-up without typing: "Show server QR" outside Advanced and a tablet-first front door | M | med-high | `setup/ui/setup_page.dart:420-453`, `identity/ui/device_pair_page.dart:211`, `settings/ui/settings_page.dart:898` |
| 9 | Take a tick back (wall and adult list), and settings not left open on the wall (pop to board on idle) | M | med | `tasks/application/task_actions.dart:25-88`, `tasks/ui/tasks_today_tab.dart:206`, `board/ui/details/task_board_detail.dart:296`, `home/ui/register_home_page.dart:38-45` |
| 10 | Remove or wire dead settings (`device.night_hours`, `device.idle_revert_seconds`, the two notify keys) and fix their docs | S | med | `settings/ui/household_settings_page.dart:46-60, 136-137, 150-152`, `docs/settings/household.md:7, 22` |
| 11 | Import as the lead action; no-child dead ends get a button; land on the timetable after Apply | S | med | `school/ui/schedule_section.dart:65-67, 398-410`, `school/ui/timetable_import_page.dart:127-137`, `school_setup_page.dart:190-240` |
| 12 | Today: agenda before rituals; one-line family overview (who is where, kids' school) | S-M | med | `today/ui/today_page.dart:268-282` |
| 13 | Share as the primary button in the invite result dialog | S | med | `invitations/ui/invite_flow.dart:187-206` |
| 14 | Settings: Invite and Connect at the top; personal settings out of the household page | S-M | med | `settings/ui/settings_page.dart:105-300`, `household_settings_page.dart:143-155` |
| 15 | Smaller: mail-app button on E2, paste button for invitation codes on S0, meals list scrolls to today, kid rewards empty state | S | low-med | `setup/ui/email_code_page.dart`, `setup/ui/server_choice_page.dart`, `meals/ui/meals_page.dart`, `kid/ui/kid_points_page.dart:112` |
