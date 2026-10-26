# 25 — Wusel: the family's companion

*Added 2026-10-24 with [ADR-020](adr/ADR-020-a-lighter-day.md). Built 2026-10-24: `app/lib/core/wusel/` (the drawing) and `app/lib/features/wusel/` (the family's Wusel, its settings and lines). [Wusel on the move](#wusel-on-the-move) added 2026-10-26 ([Q58](14-open-questions.md)).* Wusel is the
mascot chosen in [ADR-012](adr/ADR-012-product-name.md#logo-and-mascot) as *Wuselchen* and
renamed here. This document says who Wusel is, how it is drawn and moves, what it says, and
where it may and may not appear. The colour and motion rules it shares with the rest of the
app are in [26](26-colour-and-ambience.md); the build order is
[16, step 11](16-setup-plan.md#step-11--a-lighter-day-m15).

**Mockup:** [`specs/mockups/wusel-and-colour.html`](mockups/wusel-and-colour.html) shows the
poses, the outfits and the three shades.

## Who Wusel is

*Der Wusel* is what you call a small child who won't sit still. Wusel is the household's
small, round, busy companion. It lives in the kitchen and is pleased by what the family does.

- **It reacts and does not initiate.** Wusel shows up at moments the family created: a
  finished list, the morning, a birthday, an empty page waiting for its first entry. It never
  appears on a timer, never interrupts a task and never asks anyone to come back.
- **Its range is warm and stays positive:** calm, curious, happy, proud and sleepy. Sleepy
  is not sad. Wusel is never disappointed, hungry, ill, lonely, bored or cross. It cannot
  die, shrink or lose anything.
- **It praises what happened, not the person.** "Die Spülmaschine ist leer!" rather than
  "Du bist super!". Praise that informs does not undermine motivation the way an expected
  reward can ([ADR-020](adr/ADR-020-a-lighter-day.md#context)).
- **It belongs to everyone.** Its tufts are the family's colours, so it is nobody's
  character in particular. It never compares members and never takes sides.
- **It has no gender.** Copy uses its name and avoids pronouns. In German it is *der Wusel*,
  as in the word.

## The drawing

The reference drawing is [`specs/brand/wusel.svg`](brand/) on a 100 × 100 grid, renamed from
`wuselchen.svg` in step 11. It consists of these parts:

| Part | Drawn as | Colour |
|---|---|---|
| Body | The rounded drop of the reference path, squashed or stretched by the pose | `brand` of the shade. Light: Tanne `#2D6A4F`; dark: `#6CC79A`; night: the dark value mixed 72 % over the night ground, as member inks are ([17](17-design-system.md#member-colours)) |
| Tufts | One stroke per member, in board order, 1–6 tufts; more members show the first six | Each member's ink in the current shade. Before a household exists (the front door), swatches 1–4 |
| Eyes | White sclera, ink pupils; or a happy arc; or a closed arc | `#FFFFFF` and `ink`; at night the sclera is `#CDB994` |
| Cheeks | Two soft ellipses | `#FF85AE` at 60 % (the dark raspberry ink), in every shade |
| Mouth | The "w"; an open "w" for cheering; a small "o" for surprise | The shade's `bg` |
| Arms, feet | Two short rounded nubs each, hidden in *idle* and drawn only by poses that need them | `brand`, a step darker |

- On a shared or kiosk device the **acting member's tuft** is drawn first and slightly
  longer, and it wiggles when Wusel speaks to that member. That says "this is for you"
  without a name.
- **Minimum size 32 px.** Below that Wusel is not drawn at all, as with the logo
  ([ADR-012](adr/ADR-012-product-name.md#logo-and-mascot)). Common sizes are 48 (adult
  empty state), 96 (kid card, kiosk corner) and 160–240 (kid celebration).
- Wusel never replaces the logo on the app icon, the splash screen or a web title.

## Poses

Seven poses. Each one is a set of parameters, not a separate drawing (see [Implementation](#implementation)).

| Pose | Looks like | Used for | Motion (reduce-motion: the static look only) |
|---|---|---|---|
| `idle` | Eyes open, arms hidden | Default when present | Breathes (2 % squash, 3.2 s), blinks every 3–7 s |
| `wave` | One arm up, eyes open, slight lean | Greetings: the kid home, the wall's morning | Waves three times, then idle |
| `cheer` | Happy-arc eyes, open "w", both arms up, tufts flying | A finished list, a birthday, a goal reached | A jump with squash and stretch, a burst of confetti ([26](26-colour-and-ambience.md#celebrations)), back to idle in 1.2 s |
| `proud` | Holds up a gold star, coin or badge (`points`) | A reward redeemed, a badge earned | Lifts the object, a small glint |
| `peek` | The top half rising from the lower edge, eyes on the call to action | Empty states | Rises once on arrival; blinks |
| `think` | Eyes up and to the side, one arm at the chin, three dots | Waiting, loading, offline in kid and kiosk | Dots pulse; never longer than the wait |
| `sleep` | Closed-arc eyes, tufts drooping, body lower | The wall at night, the kid register after bedtime | A slow breath; a "z" fades in and out every 20 s |

A tap on Wusel in the kid register and on the wall gives one of three small reactions (a
giggle squash, a tuft spin, a blink-wink), chosen by where the finger lands, and three taps
in a row a wriggling giggle ([on the move](#wusel-on-the-move)). Tapping more often never
makes Wusel refuse or tell the child off.

## Outfits

A child can dress Wusel from the start. Nothing is earned, bought, rare or lost
([ADR-020, decision 5](adr/ADR-020-a-lighter-day.md#decision)).

- **Eight outfits:** Partyhut, Krone, Zauberhut, Blumenkranz, Sonnenbrille, Schal, Kopfhörer
  and Schleife. (A beanie was dropped while drawing: it hid the family's tufts.) Each is a small path set the painter draws on top of the body.
- **Own outfit.** `member.wusel_outfit` holds a member's choice. It shows wherever Wusel
  speaks to that member: their kid home, their phone, or the wall after they tap their
  avatar.
- **Occasion outfits** override the member's choice on the day itself, where
  [26's ambience](26-colour-and-ambience.md#ambience) is on: the Partyhut on a member's
  birthday. The wall otherwise shows Wusel
  without an outfit, because the wall belongs to everyone.

## Voice

Wusel's lines live in the ARB catalogues under `wusel*` keys, in all four languages
([09, Language](09-clients-and-ux.md#language)). The rules apply in every language:

1. **Short.** At most 8 words in the kid and kiosk registers, 12 in the adult one. One line
   at a time.
2. **No guilt, ever.** None of "you missed", "you forgot", "you haven't", "still", "again",
   "don't break your streak", "I'm sad" or "come back". A missed chore is a conversation
   between people, not a line for Wusel ([principle 3](01-vision-and-scope.md#principles)).
3. **No comparison.** No line names two members, ranks them, or counts one against another.
4. **Inform when praising.** Say what happened and what it did: "Alle Teller sind sauber. Danke!"
5. **"Wir" for the family, "du" for the one member addressed.** The adult register says
   "ihr" or speaks in the family's name.
6. **Written per language, not translated word for word.** Each language gets its own
   wordplay, or none. No irony, no pop culture, nothing a seven-year-old would misread.
7. **Three to five variants per moment,** rotated so the same line never appears twice in a
   row on one device.
8. **Wusel never speaks in a notification.** Reminders and the morning summary stay in the
   app's plain voice ([09, Realtime](09-clients-and-ux.md#realtime-and-notifications)). A
   mascot that pushes is how Duolingo's owl became a meme.

Examples. These are the tone to aim for, not the final catalogue:

| Moment | DE | EN |
|---|---|---|
| Kid home, morning | "Guten Morgen! Heute hast du Sport." | "Morning! You've got PE today." |
| Kid, last chore of the day done | "Alles erledigt. Das hat gut geklappt!" | "All done. That went really well!" |
| Kid, reward requested | "Abgeschickt! Jetzt entscheidet ein Erwachsener." | "Sent! A grown-up will decide." |
| Kid, badge | "Ein neues Abzeichen: Spülmaschinen-Profi!" | "A new badge: dishwasher pro!" |
| Kid, offline | "Moment, ich suche das Netz …" | "Hang on, looking for the internet…" |
| Empty shopping list | "Noch nichts auf der Liste. Tipp auf eine Kachel." | "Nothing on the list yet. Tap a tile." |
| Wall, morning | "Guten Morgen, ihr alle!" | "Good morning, everyone!" |
| Wall, a member's chores all done | "Jack hat heute alles geschafft!" (that member's own moment only) | "Jack's done everything for today!" |
| Wall, night | (no line; Wusel sleeps) | — |
| Birthday | "Olivia hat Geburtstag! 🎉" | "It's Olivia's birthday! 🎉" |

The empty states keep the texts of [20](20-onboarding.md#empty-states). Wusel adds the
picture and, where the text already names the action, says nothing more.

## Where Wusel appears

There is **one Wusel per screen at most**. Its entrance animates at most once per screen
visit, and a tap on its speech bubble hides the line for that moment.

| Register | Moment | Pose | Line |
|---|---|---|---|
| **kid** | Kid home, on opening | `wave` | Greeting plus the day's first useful fact (a lesson, a meal, a countdown) |
| | A single chore ticked | none: the points fly as in [06](06-module-tasks.md#screens) | — |
| | A chore ticked on *Mein Tag* (a lively Wusel) | Travels to the card and carries the points home ([on the move](#wusel-on-the-move)) | — |
| | The last of today's chores ticked | `cheer`, a high jump over the list ([on the move](#wusel-on-the-move)); the all-done card says the line without a second Wusel | Yes |
| | Reward requested; a badge earned in the last two days (on *Mein Tag* and *Punkte*, the badge sound once per badge while the app runs) | `proud`; on *Mein Tag* the greeting's Wusel holds up the star and the badge card shows a gold star, so the screen keeps one Wusel (fixed 2026-10-26) | Yes |
| | Empty states | `peek` | The module's empty text |
| | Waiting, offline | `think` | Only after 2 s |
| | The child's birthday, first open that day | `cheer` + Partyhut, full screen once | Yes |
| | After `device.night_hours` start | `sleep` in the header | — |
| **kiosk** | The first 30 minutes after night hours end | `wave` in the board's header corner | Morning greeting |
| | A member ticks their last chore of the day on the wall | Leaves the corner, `cheer` for 4 s beside their column, and goes back ([on the move](#wusel-on-the-move)) | That member's own moment |
| | Tischfrage during the meal ([27](27-family-rituals.md#tischfrage)) | `idle`, holding the card | The question |
| | A birthday | Partyhut all day, `cheer` once each hour on the hour (the wall's quietest loud moment) | Banner text |
| | Night hours | `sleep`, small, in the corner | — |
| | Offline ([09, Freshness](09-clients-and-ux.md#freshness-and-failure)) | `think` beside the freshness note | — |
| **adult** | Empty states | `peek`, 48 px, static unless `member.wusel = lively` | The module's empty text |
| | Today on a special day (a birthday, the first day of Ferien, the Wochenrückblick) | `wave` or `cheer` in a card at the top of Today; the birthday's `cheer` takes precedence over the Ferien `wave`, and either over the empty state's `peek`, so Today keeps one Wusel | Yes |
| | The shopping list is empty (decided 2026-10-24: a family that does not want Wusel there switches Wusel off) | `peek` over the empty list, below the tiles | The empty text; with tiles on the list "Noch nichts auf der Liste. Tipp auf eine Kachel." |
| | The getting-started card completed while Today is open (a card that loads already complete stays hidden, so it happens once) | `cheer`, until tapped away | Yes |

### Where Wusel never appears

- Any **capture flow**: the shopping tiles, their typeahead and quick add, the event and
  chore editors, the timetable grid, the scanner. That protects P6's three seconds. The
  empty shopping list below the tiles is an empty state, not the capture itself, so
  Wusel peeks there (decided 2026-10-24); it never stands among the tiles.
- **Errors, warnings, destructive confirmations, the PIN pad, sign-in, pairing, invitations
  and deletion.** A mascot beside "Familie löschen" is not funny.
- **Settings**, except the outfit picker and Wusel's own setting.
- **Notifications, widgets, the ICS feed, mail, Shortcuts and MCP responses.**
- **Over content, at rest.** Wusel takes its own space; it never rests on a band, a tile or
  a button. Travelling, it may cross them for a moment and sit on a card's edge for a
  visit, with touches passing through it ([on the move](#wusel-on-the-move)).

## Wusel on the move

*Decided 2026-10-26 ([Q58](14-open-questions.md)).* A lively Wusel in the kid register and
on the wall is not held to its box. When something happens it leaves its place, goes over
the screen to where it happened, and comes back. The aim is a character that seems to live
in the app, using what Flutter is good at: motion computed each frame from the finger, the
layout and the family's own events, not played from a file.

### The rules

- **One Wusel, one home.** Each screen that shows Wusel has one home: the greeting on
  *Mein Tag*, the corner of the wall's header. Wusel travels from there and back. While it
  is away its home keeps the empty space, so nothing on the screen shifts, and the line
  stays where it was as text. There is never a second Wusel on the screen while one is
  travelling.
- **It travels only for a moment.** Still reactive, never initiating
  ([Who Wusel is](#who-wusel-is)): a chore ticked, the last chore, a tap on Wusel, coming
  back to *Mein Tag*. Nothing on a timer, nothing to get attention.
- **The afterglow.** After a moment a lively Wusel stays awake for 30 s. Its eyes follow
  the finger, it glances about, and it hops on the spot now and then. Then it rests as
  before. A new moment starts the 30 s again. On the wall there is no afterglow beyond the
  tickles: Wusel stays in its corner and rests after 60 s, as before.
- **It may cross content, but it rests at home.** A visit to a card lasts at most 4 s.
  Wusel sits on the card's upper edge at the end away from its tick target. Touches pass
  through a travelling Wusel to whatever lies below it, so a child never has to wait for it.
- **Only between places that can be seen.** If the card or the home is scrolled out of
  view, or the screen changes during the trip, Wusel goes straight home (or is simply at
  home) and the moment is what it was without travel: the coin's flight.
- **Where it never travels:** the places Wusel never appears, at night (it sleeps), while
  it thinks (offline or waiting), and on adult screens. Quiet and off do not travel.
  Neither does anything under reduce motion or in still mode.
- **The budget is unchanged.** One celebration per moment ([26](26-colour-and-ambience.md#celebrations)).
  A tick while Wusel is away starts no second trip: that tick's coin flies to the balance
  as it did before Wusel could travel.

### The moments

| Register | Moment | What Wusel does |
|---|---|---|
| **kid** | A chore ticked on *Mein Tag* | Hops from home to the card as the tick pops. When the server credits the points, Wusel takes the coin, carries it home and drops it into the balance beside the greeting; then the afterglow. A chore without points (or one that waits for a check): Wusel looks at the card, happy, and hops home. When the server refuses the tick, Wusel hops home, without a reaction. The list keeps its order while Wusel is away, so the ticked card does not slide off under Wusel; done chores move to the end once Wusel is home. The coin grows out of Wusel's hand and shrinks into the pill |
| | The last chore of the day | Wusel goes to the all-done card (it appears above the list and pushes the ticked card down), then makes a high jump with the cheer; the confetti and *fertig* start with the jump, from Wusel. Then home. The all-done card says the line as text, without a second Wusel |
| | Back to *Mein Tag* from another tab | Hops in from the lower edge to its home in at most two big leaps: once per return, not on the first open (which waves) |
| | Tilting the phone or tablet in the hand | Wusel leans downhill, its tufts swing, its eyes look the way it would slide, and on a steep tilt it slides a little within its home. It never leaves its home for a tilt. Native iOS and Android only: not on the web, not on the wall |
| | A finger on the screen during the afterglow | The eyes follow the finger |
| **kid, kiosk** | Tapping Wusel | Tickles: where the finger lands decides the reaction (a tuft spins, the body giggles, near the eyes a wink). Three taps in a row give a wriggling giggle. Wusel never refuses and never tells anyone off. For a few seconds the eyes follow the finger. On the wall Wusel stays in its corner |
| **kiosk** | A member's last chore ticked on the wall's chore board | Wusel leaves the header corner and hops over the board to that member's column. It cheers there for 4 s in a space above the line (so the line never reflows), then hops back to the corner, and the space folds away. Nothing else takes Wusel out of its corner on the wall |

### The motion

All of this applies wherever Wusel moves, in its box too, so the in-place poses also gain
from it:

- **Springs, not curves, for the body.** Squash and stretch come from speed and landings,
  and Wusel leans into a sideways movement. These are the springs of
  [26](26-colour-and-ambience.md#motion) (`Tokens.springBouncy`).
- **The tufts follow through.** Each tuft lags behind the body, more the further it is from
  the middle, and settles with a small overshoot: a jump flicks them, a landing flops them.
- **The eyes glance.** Before a hop Wusel looks where it is going. On a visit it looks at
  the card. In the afterglow there are small glances between the blinks.
- **A hop** is a crouch, a flight on a gravity arc stretched along its path, a landing
  squash and a settle. A long way is several hops, never one long glide. Wusel's size
  blends from its home's to its target's on the way.
- **The coin** is a new prop (`WuselProp.coin`, the points gold), held up in one hand.

## Accessibility

- The drawing sits in `ExcludeSemantics`. A line is ordinary text in the screen's reading
  order, so a screen reader reads what Wusel says and skips the creature.
- A travelling Wusel is decoration too: it is never in the semantics tree, and nothing a
  screen reader user needs depends on a trip.
- **Reduce motion** ([26](26-colour-and-ambience.md#motion)) keeps Wusel at home and shows each pose's static look,
  with a 150 ms cross-fade at most and no confetti.
- Wusel never carries information that is not also in text. The cheer accompanies "Alles
  erledigt"; it does not replace it.
- **No reading aloud.** *Decided 2026-10-24 ([Q51](14-open-questions.md)).* Lines stay short
  enough for a slow reader, and the pose carries the mood without words.

## Settings

New rows in [21](21-household-settings.md#a-lighter-day):

| Key | Scope | Default | Values |
|---|---|---|---|
| `member.wusel` | member, self | `auto`: children `lively`, adults `quiet` | `auto` · `lively` · `quiet` (static, empty states and special days only) · `off` |
| `member.wusel_outfit` | member, self | none | none · one of the eight outfits |
| `device.wusel` | device (kiosk, shared) | `lively` | `lively` · `quiet` · `off`; a member's own setting wins while their profile is active |

`auto` is no choice of its own: on the wall a member on `auto` gets the wall's
`device.wusel`, so the corner Wusel stays when a grown-up taps their avatar; on a phone
and in the kid register `auto` means lively for children and quiet for adults.

## Implementation

The code lives in `app/lib/core/wusel/`.

- **`WuselLook`** is an immutable set of parameters: `eyeOpen` (0–1), `eyeShape` (`round`,
  `happy`, `closed`), `gaze` (offset), `mouth` (`w`, `wOpen`, `o`), `squash` (−0.15 to 0.15),
  `lift`, `tuftLift`, `tuftSway`, `armLeft` and `armRight` (angle or hidden), `feet` (bool),
  `prop` (`none`, `star`, `coin`, `badge`, `card`), `outfit`, and `peek` (0–1 visible
  height). `WuselLook.lerp` interpolates every field.
- **`WuselPose`** maps each of the seven poses to its key looks. A pose is a short list of
  `(look, duration)` steps plus an idle loop.
- **`WuselPainter`** (`CustomPainter`) draws a look from the reference paths on a 100 × 100
  grid, scaled to its size, with tuft colours and the shade passed in. It has no assets and no
  dependencies. `shouldRepaint` compares looks, so a still Wusel does not repaint.
- **`Wusel`** is the widget: `pose`, `size`, optional `line`, optional `outfit`. It reads
  the household's members for the tufts and the acting profile for the front tuft. It drives
  the steps with the spring motion of [26](26-colour-and-ambience.md#motion) and schedules
  blinks with a jittered timer. It stops every ticker when the route is not visible or the app
  is in the background, and it falls back to the static look under reduce motion.
- **`WuselLines`** picks a variant for a moment from the ARB catalogue, never the same twice
  in a row on one device while the app runs; `WuselLines.stable` picks by a seed for lines a
  stateless screen draws (the wall's). Under `flutter test` and in still mode it always takes
  the first variant.
- **`EmptyView`** (`core/ui/empty_view.dart`) draws whatever the app root provides through
  `EmptyIllustration`; the app installs a peeking Wusel there, so its 17 call sites get Wusel
  without knowing it, and `core/` stays free of features. `illustrated: false` leaves it out.
- **Still mode.** `StillMode.enabled` (`core/ui/motion.dart`) makes `motionAllowed` false
  everywhere: each pose's still look, no blink, no confetti, the first line variant. The demo
  build turns it on with `?still=1`, and `docs/tools/screenshots.mjs` always passes it, so
  Wusel never changes a screenshot from one run to the next.
- **Power on the wall.** The kiosk animates only for a moment and then rests: idle blinking
  stops after 60 s without a moment, and sleep breathing runs at a low frame rate (five
  frames a second from a timer, not the ticker, and none while the route is hidden). The
  acceptance check is CPU use on the wall tablet with the board idle for ten minutes, the
  same with Wusel on and off, written down in the release checklist.
- **Tests.** Goldens (`app/test/golden/`, the repository's first) for every pose in three
  shades, every outfit and one to six tufts; `test/core/wusel_test.dart` for still mode and the
  frames a pose draws. A widget test
  (`test/features/wusel_absent_test.dart`) that the capture routes, the shopping tiles
  and their typeahead and the PIN pad render no `Wusel`, and that the empty shopping
  list shows exactly one. A unit test that line rotation never
  repeats. The voice rules are a review checklist item for every ARB change under `wusel*`,
  because a word-list test cannot work across four languages.
- **Brand.** `specs/brand/wuselchen[-dark].svg` become `wusel[-dark].svg`, and
  `scripts/brand-assets.js` follows. A golden test draws the painter's `idle` at 100 px next to
  the SVG rendered by the docs, so the two stay the same character.

### On the move

- **`WuselRig`** (`core/wusel/wusel_rig.dart`) is the secondary motion: a damped spring per
  parameter (squash, lean, gaze, the tufts' lag) driven by the body's speed and
  acceleration. It is pure Dart with a fixed `step(dt)`, so a test can run it frame by
  frame without a widget. Once every spring is at rest it says so, and the ticker stops.
  `WuselLook` gains `lean`, `tuftLag` and the `coin` prop; their zero values draw exactly
  what was drawn before, so the goldens do not change.
- **`WuselHop`** (`core/wusel/wusel_travel.dart`) is one hop as a function of time: the
  crouch, the gravity arc between two points that may move during the flight (the target
  is read again every frame, so a list scrolling under Wusel is followed), the landing and
  the settle. A trip is a list of hops of at most five Wusel sizes each; the hop in from
  the lower edge is the one exception, at most two leaps however tall the screen.
- **`WuselStage`** (`core/wusel/wusel_stage.dart`) sits in `MaterialApp.builder`, above
  the navigator, so a trip can go over a dialog (the wall's chore board is one). It owns
  the one travelling Wusel, painted in an `IgnorePointer` with a `RepaintBoundary`, and
  the last finger position for the eyes, read by a translucent `Listener` that takes no
  touch. It draws frames only while a trip runs.
- **`WuselHome`** marks a home. It registers its box with the stage and shows its Wusel
  only while Wusel is not away. A **visit** (`WuselStage.of(context).visit(target, …)`)
  names a `GlobalKey` whose box is the target. The future completes when Wusel is home
  again, whether the trip ran or was skipped by the rules above.
- **Tilt** comes from `sensors_plus` (BSD-3-Clause). The accelerometer is subscribed only
  while *Mein Tag* shows a lively Wusel on native iOS or Android, at the UI interval and
  low-pass filtered, and it is dropped when the route is hidden or the app goes to the
  background. A change smaller than about 4° does not wake the ticker, so a tablet lying
  still costs nothing.
- **Tests.** The rig and the hop are unit tests: every spring comes to rest, a hop lands
  on its target, and a target that moves is followed. Widget tests check that a tick on
  *Mein Tag* sends Wusel to the card and home again, that the home is empty only while
  Wusel is away, and that quiet, still mode and reduce motion never travel.
  `wusel_absent_test` still holds, because no capture route has a home.

## How the trial judges Wusel

In M1.6's two weeks ([ADR-020, decision 8](adr/ADR-020-a-lighter-day.md#decision)):

- **Keep** if a child mentions Wusel or taps it unprompted, and no adult has switched it off.
- **Turn down** (the default to `quiet` on the wall) if anyone finds its movement distracting
  in the corner of their eye.
- **Remove a moment** that anyone calls annoying. One complaint is enough, because annoyance
  compounds.
- **On the move** (added 2026-10-26): keep the trips if a child laughs at or waits for one
  at least once. Keep the wall in its corner if anyone at the table notices a trip over
  the chore board more than the chore. Drop the carried coin if a child waits for Wusel
  to come back instead of ticking the next chore.
