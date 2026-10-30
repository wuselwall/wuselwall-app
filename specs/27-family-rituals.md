# 27 — Family rituals: Tischfrage, Wochenrückblick, traditions, Vorfreude, Wunschessen

*Added 2026-10-24 with [ADR-020](adr/ADR-020-a-lighter-day.md). Built 2026-10-24: migration
`20261024110000_lighter_day_rituals.sql` (pgTAP 235) and `app/lib/features/rituals/`.* Builds on
[05](05-module-calendar.md) (events), [07](07-module-meals-shopping.md) (the meal plan),
[06](06-module-tasks.md) (tasks and points) and the week board of [09](09-clients-and-ux.md#the-week-board).
Wusel's part in each ritual is in [25](25-wusel.md); the colours and celebrations are in
[26](26-colour-and-ambience.md).

## Why rituals

A **routine** says what needs to be done. A **ritual** says who we are (Fiese et al. 2002).
WuselWall already carries a family's routines: the chores, the timetable, the shopping. This
document adds a few small rituals: moments that repeat, that the family recognises, and that
mean something beyond getting things done. The research behind the choice is summarised in
[ADR-020](adr/ADR-020-a-lighter-day.md#context). It is mostly correlational, so no screen
promises that a ritual makes anyone happier.

## Rules every ritual follows

1. **A ritual is never a chore.** It creates no task, earns no points, keeps no streak and
   has no "missed" state. Skipping it leaves no trace.
2. **No counts between people.** Nothing here ranks, compares or totals one member against
   another ([principle 3](01-vision-and-scope.md#principles), P3).
3. **No notification.** A ritual appears where the family already looks: the wall, Today
   and the kid home. It never pushes.
4. **A household setting with a curated default** (P5), each switchable on its own under
   Einstellungen → Familie → *Rituale*.
5. **Attributable** (P4). Every write is an `api` function with `app.actor()` and an audit
   row. What is only shown and never written, such as the table question, stores nothing.
6. **Four languages** (P9). Every text is complete in DE/EN/FR/ES in the same change. The
   Tischfrage's FR and ES decks are smaller than the DE and EN ones ([below](#tischfrage)).

## Birthdays

The prerequisite of Vorfreude and of the birthday ambience. This is
[23 R1.5](23-roadmap-after-alpha.md#r1--learn-from-the-alpha) and [Q50](14-open-questions.md),
moved forward: **a field on the profile** (`profile.birthday DATE NULL`, already in
[04](04-data-model.md#identity), not yet migrated).

- A guardian sets it on the member page of [16, step 10.1](16-setup-plan.md#step-10--journey-gaps-before-launch-m15).
  `api.member_update` gains `p_birthday`, and members may set their own. The wall sets no
  one's: `api.member_update` refuses a kiosk (`20261025100000`), and the member page there only
  shows. "Nicht mehr dabei" clears the birthday.
- It is projected like a public holiday, as a read-only occurrence: "Olivia wird 10" on the
  board's day header, in the month view, on the kid home and in the ICS feed. *Built:* the
  countdown says the age ("Paul wird 8 · noch 3× schlafen", `ageOn` in `countdown.dart`), and the
  ICS feed has one yearly all-day event per member (`RRULE:FREQ=YEARLY`, a UID per profile, no
  age so the series never changes, 29 February on the year's 60th day as in the app) for the
  token's members, not in a presence-only or calendar-narrowed feed. The board's day header
  shows "Paul wird 8" with a cake under the date (`weekBirthdaysProvider`), with `ambience.birthdays`
  on, and grows to its second line as for a holiday; a holiday on the same day follows after " · ".
  The month view (2026-10-24, [05](05-module-calendar.md#views)) shows them with a cake and
  the age too, always: it is information, `ambience.birthdays` only governs the decoration.
- On the day: [26's](26-colour-and-ambience.md#seasons-and-occasions) bunting in the member's
  ink, Wusel's Partyhut, and a one-time cheer on that child's own device.
- Grandparents and friends stay yearly events, as 23 decided. A yearly event can be marked
  for Vorfreude like any other.

## Vorfreude

Looking forward is half the fun, and "wie oft muss ich noch schlafen?" is a question the wall
can answer before anyone asks it (the vision's third property).

**What gets a countdown**

| Source | Automatic | Example |
|---|---|---|
| A member's birthday | Yes | 🎂 "Olivias Geburtstag: noch 3× schlafen" |
| The first day of Ferien | Yes, with `ambience.occasions` Ferien on | 🏖️ "Herbstferien: noch 5× schlafen" |
| An adult coming back from `travel` lasting two nights or more | Yes, with `rituals.countdown_return` on | ✈️ "Papa ist in 2× schlafen zurück" |
| Any event a member marks *Darauf freuen wir uns* | Marked by hand: `event.countdown` | 🦁 "Zoo: noch 9 Tage" |

The wording uses the member labels the household already uses on the board
([21](21-household-settings.md#household-and-members)).

**Where it shows**

- **Wall:** a *Vorfreude* strip in the board's footer with the nearest countdowns, as many as
  fit (one or two), each an icon, a short title and the count ([Q57](14-open-questions.md),
  decided: the header's middle is the Tischfrage's during the meal; Vorfreude and the
  Rückblick tile live in the footer).
- **Kid home:** "Worauf ich mich freue". These are the countdowns the child attends, plus the
  whole-family ones.
- **Adult Today:** one line with the nearest countdown, only within the horizon.

**How it counts**

- From `rituals.countdown_days` (default 14) days before. Up to 7 days the kid register and the
  wall count **nights** ("noch 3× schlafen"); beyond 7 days they say "noch 9 Tage", and the
  adult register always says "in 3 Tagen".
- The day before says "Morgen!" and the day itself "Heute!", with Wusel's `wave`. After that
  the countdown is gone. There is no "vorbei". *Built:* on the wall the header's corner Wusel
  waves when the nearest countdown is tomorrow or today, since a second Wusel beside the footer
  strip would break [25's](25-wusel.md#where-wusel-appears) one Wusel per screen. The kid home
  (its greeting holds the screen's Wusel) and Today (its birthday card, the getting-started
  cheer and the empty state may hold it) add none.

**Data.** `event.countdown BOOLEAN DEFAULT false` and `event.icon_key TEXT NULL` (one of the 20
pictures of the `events` set, `assets/emoji/events/`). Both travel in `api.event_save`'s JSON.
Members who may edit their own events (`calendar.members_edit_own_events`) may mark them. A
presence entry carries none of the flags: `api.event_save` refuses them (`20261025100000`); the
way home counts down by itself. The
countdowns are **computed in the app** (`features/rituals/domain/countdown.dart`) from the
occurrences of the horizon, the members' birthdays and the school holidays it already reads;
the occurrences carry `icon_key`, `countdown` and `tradition`.

## Familientraditionen

The family's own recurring rituals, by name: Spieleabend, Pizza-Freitag, Sonntagsfrühstück.

- **A tradition is a recurring event** with `event.tradition = true`, an icon and the whole
  family attending by default. It is created from a starter set or from scratch, in
  Kalender → *Neue Tradition*. The starters are Spieleabend 🎲, Pizza-Freitag 🍕, Filmabend 🎬,
  Sonntagsfrühstück 🥐, Vorlesezeit 📖 and Ausflugstag 🥾. Each language has its own set, and
  the starters are a localised catalogue like the chore examples. *Built:* a small button above
  the calendar's *Neuer Termin* (only where the server announces `lighter-day`) opens the six and
  *Eigene Tradition*; a choice opens the ordinary editor with a weekly whole-family tradition
  filled in (`calendar/domain/tradition_starters.dart`: Spieleabend Friday 19:00, Pizza-Freitag
  Friday 18:00 with "Pizza" for dinner, Filmabend Saturday 19:00, Sonntagsfrühstück Sunday 9:00,
  Vorlesezeit Wednesday 19:00, Ausflugstag Sunday all day), starting on the day in view or later.
  Nothing is saved until the editor saves.
- **On the board** a tradition always shows: it is implicitly `key`, drawn as a ribbon
  in the `lemon` paper tint with its icon, unlike an appointment's band. On its day, Wusel's
  morning line on the wall and the kid home's first fact may name it ("Heute ist Spieleabend!";
  *built* for the wall, moment `wallTradition`, from `todayTraditionProvider`).
- **Skipping one week** is an ordinary exception date (`exdates`). It simply does not show.
  Nothing records that a tradition did not happen.
- **A meal tradition** (Pizza-Freitag) may carry a meal: `tradition_meal(event_id, slot,
  recipe_id NULL, free_text NULL)`; the editor takes a few words and lunch or dinner. On the
  tradition's day, while that meal is empty, the planner offers it as a chip; one tap plans it
  with `api.meal_set`. Nothing is planned by itself, and the board shows only planned meals, as
  today.
- Traditions reach the ICS feed like any other event.

## Wunschessen

Once a week each child picks a meal, which gives children a voice in the plan.

- **Who wishes:** `meals.wishes` (default *children*; also *everyone* or *off*), at most
  `meals.wishes_per_week` (default 1) open wish each.
- **Kid home:** a card "Dein Wunschessen diese Woche". It opens a picker with the family's
  recipes (with their pictures), the meals cooked most often recently (the source of the meal
  suggestions, FR-3.8), or an icon plus a few typed words. The wish can be changed until it is
  planned. *Built (migration `20261025130000`, pgTAP 239):* "Oft bei uns" first (the meal
  editor's `suggestMeals`), then every recipe with a search from seven recipes on, then a few
  words with a picture to choose. Recipes have no picture of their own: `app.meal_icon_for`
  picks one of the app's dish pictures (the `meals` set, 35 Fluent Emoji) from a name in DE,
  EN, FR and ES, kept in generated columns `recipe.icon_key` and `meal_plan_entry.icon_key`
  and shown by `api.recipes` and `api.meal_history`; a wish without a chosen picture gets one
  from its words. The tray's chips show the picture.
- **Guardians** see a *Wünsche* tray at the top of the meal planner's week: "Olivia:
  Pfannkuchen 🥞 · Jack: Pizza 🍕". Placing a wish on a day and slot plans it. A new wish also
  appears as a quiet card on Today, among the pending items of
  [16, step 10](16-setup-plan.md#step-10--journey-gaps-before-launch-m15), not as a push.
- **Once planned,** the meal carries a star and the wisher's dot ("Wunsch von Olivia") in the
  plan and on the board. The child's card says "Dein Wunsch gibt es am Donnerstag!", which is
  a small Vorfreude of its own. A recipe wish feeds the shopping list like any planned recipe.
- **A wish not planned that week** stays in the tray into the next week, marked "von letzter
  Woche". It counts as that child's open wish. *Built:* `api.meal_wishes` says `earlier_week`
  (made or last changed before this household week's Monday) and `wished_on`; a wish older
  than a week before that reads "von vor ein paar Wochen". **Ageing** (*decided 2026-10-24*,
  the spec was silent): an open wish not planned within four weeks (28 days) of being made
  leaves the view and no longer counts toward `meals.wishes_per_week`. Its row stays as it
  is, no job runs for it, and nothing records that it was not cooked; the child simply wishes
  again. Four weeks is a constant, not a setting, until a family asks for another.
- **Grown-ups wishing.** With `meals.wishes` *everyone*, the tray offers the grown-up at the
  planner "Selbst wünschen" (at the limit "Meinen Wunsch ändern"), the same picker. The server
  decides who may wish; the app only offers it. The words *abgelehnt*, *rejected* and their
  equivalents do not exist in this feature. A guardian may remove a wish (audited); the child's
  card simply invites a new one. Why a wish did not happen is a conversation between people.
- **Data:**

  ```
  meal_wish
    id, household_id, profile_id,
    recipe_id NULL, free_text NULL, icon_key NULL,       -- recipe_id or free_text
    status ENUM('open','planned','withdrawn'),
    meal_plan_entry_id NULL, created_at

  meal_plan_entry
    + wished_by_profile_id NULL
  ```

  The API is `api.meal_wish_set(actor, recipe_id, free_text, icon_key)`, which creates a wish or,
  once the actor has `meals.wishes_per_week` open ones, replaces their newest; `api.meal_wish_withdraw(actor, wish)` (the wisher, or a
  guardian); `api.meal_wish_plan(actor, wish, on_date, slot)` (whoever may edit the meal plan),
  which creates the entry and links it; and the view `api.meal_wishes`. Invariant: at most
  `meals.wishes_per_week` open wishes per member. pgTAP covers that invariant, the
  member-edits-only-their-own rule, and the cross-household, revoked-device and
  unauthenticated cases.

## Tischfrage

A question for the table during the meal, answered aloud, with nothing recorded.

- **When:** during the warm meal's window. `rituals.table_question` is *warm meal* (default,
  following `meals.warm_meal.school_day` and `.free_day`), *every main meal* or *off*.
  `rituals.table_question.lunch` and `.dinner` set the windows (11:30–13:30, 17:30–19:30). A
  meal does not have to be planned.
- **The windows follow the country.** *Added 2026-10-24.* Those defaults miss both meals in
  Spain (comida about 14:00–15:30, cena about 21:00) and most French dinners (between about
  18:50 and 21:30, most often 20:00, per INSEE's time-use surveys). The country of
  `household.region` picks a default from `app.setting_country_default` (migration
  `20261024150000_setting_country_defaults.sql`, pgTAP 240): Spain 13:30–15:30 and
  20:00–22:00, France dinner 19:00–21:00. `api.settings` reports it as the default, and a
  reset returns to it; a household without a region keeps the catalogue's.
- **Where:**
  - On the **wall**, a card in the board header for the window. Wusel holds it, the question
    is set at kiosk size 34 on one line, or down to 24 on two when it is long, so the header
    keeps its height and the rows under it do not move during the meal; a riddle's answer
    takes the question's place while it is open. An *Andere Frage ↻* button has a 56 px
    target. The week stays visible.
  - On the **kid home**, the same card.
  - On **Today**, a dismissible card.
- **The same question everywhere.** Each household walks its own fixed shuffle of the deck,
  seeded by its id, one question per meal window. So every device shows the same question, and
  no question repeats before the deck is through. *Andere Frage* steps forward on that device
  only. A shared "next" would be a write per tap, and the family can just say "nimm die
  nächste".
- **The deck:** about 150 questions in German and English and 50 in French and Spanish, in
  `app/assets/table_questions/{de,en,fr,es}.json`, with stable ids and categories:
  - *Quatsch*: "Wenn unser Kühlschrank sprechen könnte, was würde er sagen?"
  - *Heute*: "Was war heute das Lustigste?"
  - *Stell dir vor*
  - *Erinnerungen*: "Welcher Ausflug war der schönste?"
  - *Wir*: "Was können wir als Familie richtig gut?"
  - *Rätsel*: a short riddle, with the answer behind a tap
  - *Danke*: used sparingly, at most one in ten
  
  `rituals.table_question_deck` chooses *Familie* (default, fine for a five-year-old) or
  *Ältere* (adds questions for 8+). Each language's deck is **written in that language**, not
  translated, and none is copied from a commercial card game.
- **FR and ES with 50 questions each.** *Decided 2026-10-24 ([Q53](14-open-questions.md)),
  changed the same day.* The French and Spanish decks were researched and drafted at 150
  questions each, without a native reviewer. The app ships 50 of each: a third of every
  (category, deck) group of the German deck, leaving out every question the drafts' notes
  flag as unsure and every riddle whose tradition could not be traced. The drafts and notes
  are kept in the maintainers' private notes. A
  household walks through 50 questions in about seven weeks of warm meals before one comes
  back; a later change can add from the drafts without changing the existing ids.
- **The family's own questions:** `table_question(id, household_id, text, created_by_profile_id,
  created_at)`, written with `api.table_question_add` and `_remove`. Any member may add one; a
  guardian or the author removes it. Own questions mix into the shuffle and show "Frage von
  Jack". A guardian can hide any bundled question (`api.table_question_hide`): a row of
  `table_question` with `hidden_key` instead of `text`.
- **Nothing about the answers is stored.** Who answered, what they said and whether the
  question was used at all are never recorded.

## Wochenrückblick

A look back on Sunday at what *we* did.

- **When:** `rituals.week_review` sets when it opens (default Sunday 16:00; any weekday and
  time, or *off*); it stays until 10:00 the next morning.
- **Where:**
  - On **Today** and the **kid home**, a card "Unsere Woche ✨".
  - On the **wall**, a tile in the board header that opens a full-screen story as a
    tap-through detail. It returns to the board after `device.idle_revert_seconds`, like every
    detail. It never rotates in by itself, because the board must show the week (P6).
- **The story** is five cards that slide in one after another ([26](26-colour-and-ambience.md#celebrations)).
  *Built as a tap-through story:* one card fills the page, a tap on the right or a swipe or
  the arrow key goes on, the left third goes back, a progress bar of segments shows where one
  is, a close button and Escape close it, and going on from the last card closes it (on the
  wall it returns to the week). A card with nothing to say is left out. Screen readers hear
  "Karte 2 von 4"; under reduced motion a card replaces the one before without sliding. The
  wall's tile opens the same story at kiosk sizes with 56 px targets. Nothing advances by
  itself.
  1. **"Das haben wir zusammen geschafft"**: the family's chores done this week as one number,
     the family's. There is no per-member split.
  2. **"Jede und jeder hatte einen Moment"**: exactly **one highlight per active member**, in
     board order. It is picked by priority: a badge earned, a streak reaching a multiple of
     7, a reward redeemed, a wish meal eaten, all of their chores done on some day, a
     tradition or key event they attended (*built in the app:* recurring events are expanded
     only in the Edge Functions, so `api.week_review` cannot see them; the story reads the
     week's occurrences anyway, and `withEventHighlights` puts a tradition or key event the
     member attended, begun by today and not cancelled, in place of a plain fact: cooked,
     helped or "here"; a tradition without attendees is the whole family's). The fallback is a plain fact of their week that is
     always true and never a judgement ("Sarah war drei Tage unterwegs ✈️", "Jack hatte
     fünf Schultage 🎒"). Everyone gets one line; nobody gets two; nobody's line is a number
     compared with another's.
  3. **"Lecker"**: the meals of the week, with ⭐ for wishes and ✨ for a recipe cooked for the
     first time.
  4. **"Unsere Traditionen"**: the traditions that happened.
  5. **"Nächste Woche freuen wir uns auf …"**: the three nearest countdowns, and Wusel's `cheer`.
- **Never in the story:** anyone's points balance, a chore not done, a missed streak, or a
  comparison. A member's own points stay on their own screens.
- **Data:** no new table. A read function, `api.week_review(p_week_start)`, returns the
  story as JSON. It is computed in SQL from task instances, the ledger, badges, the meal plan,
  wishes and events (traditions, countdowns and the board's expansion), so the wall and the
  phones show the same story. `family:read` in MCP may gain it later.

## Data and contract, together

| Change | Kind |
|---|---|
| `profile.birthday` | Column (in 04 already); `api.member_update` gains it; projected occurrences |
| `event.countdown`, `event.icon_key`, `event.tradition` | Columns; event create and update gain them |
| `tradition_meal` | Table, written with the tradition's event |
| `meal_wish`, `meal_plan_entry.wished_by_profile_id` | Table and column; `api.meal_wish_*` |
| `recipe.icon_key`, `meal_plan_entry.icon_key` (generated); `api.meal_wishes` gains `wished_on`, `earlier_week` | Columns at the end, additive (`20261025130000`) |
| `table_question` | Table; `api.table_question_add` and `_remove` |
| The board's events gain `tradition` and `icon_key`, its meals `wished_by`, each only when set | Read model, additive |
| `api.week_review` | New read function |
| Settings rows of [21](21-household-settings.md#a-lighter-day) | Catalogue migration |

All of it is additive, so `api_version` stays 1 (the repository's convention). The previous app release keeps working: it ignores
the new fields, and a tradition looks like a recurring event to it. The data export
(`export-zip`) includes the new tables, and household deletion removes them.

## Considered and not chosen

Offered on 2026-10-24 and left out by the user. Each would come back only with a reason
from use (P7):

| Idea | Why it is not here | What would bring it back |
|---|---|---|
| *Lichtblick* board: anyone posts a short good thing of the week | Drifts toward chat (P8); a daily prompt would turn gratitude into a chore | The family asks for a way to keep good moments of the week |
| *Danke* / *High five* between members | Same drift, and counts would invite comparison | The children ask to thank each other in the app |
| *Heimliche Helfer*: secret kindness missions | Awkward missions, a content catalogue in four languages, and the temptation to attach points | The Tischfrage proves the family enjoys prompts |

The ideas the research rejected (a mood check-in, children's drawings on the wall,
BeReal-style prompts, a helpfulness leaderboard, a pet that needs care) are recorded in
[23](23-roadmap-after-alpha.md#not-on-the-roadmap-and-why).

## How the trial judges the rituals

There is no telemetry (P2), so the evidence is the pilot household's own word (R1.1's
feedback) and the audit rows that exist anyway.

| Ritual | Keep if, after two weeks | Otherwise |
|---|---|---|
| Tischfrage | The family used it at three meals or more | Default *off*; the deck stays for families who want it |
| Wochenrückblick | Someone opened it on each of the two Sundays | Default *off* on the wall; the Today card stays |
| Traditions | The family entered at least one | Keep (it costs nothing unused), but drop the starter prompt |
| Vorfreude | A child refers to a countdown ("noch 2× schlafen") | Keep only the automatic birthday and Ferien sources |
| Wunschessen | Each child wished at least once and at least one wish was cooked | Default *off*, and ask why |
