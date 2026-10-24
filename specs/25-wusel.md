# 25 — Wusel: the family's companion

*Added 2026-10-24 with [ADR-020](adr/ADR-020-a-lighter-day.md). Built 2026-10-24: `app/lib/core/wusel/` (the drawing) and `app/lib/features/wusel/` (the family's Wusel, its settings and lines).* Wusel is the
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

A tap on Wusel in the kid register gives one of three small reactions (a giggle squash, a
tuft spin, a blink-wink). Tapping more often never makes Wusel refuse or tell the child off.

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
| | The last of today's chores ticked | `cheer` | Yes |
| | Reward requested; a badge earned in the last two days (on *Mein Tag* and *Punkte*, the badge sound once per badge while the app runs) | `proud` | Yes |
| | Empty states | `peek` | The module's empty text |
| | Waiting, offline | `think` | Only after 2 s |
| | The child's birthday, first open that day | `cheer` + Partyhut, full screen once | Yes |
| | After `device.night_hours` start | `sleep` in the header | — |
| **kiosk** | The first 30 minutes after night hours end | `wave` in the board's header corner | Morning greeting |
| | A member ticks their last chore of the day on the wall | `cheer` for 4 s beside their column | That member's own moment |
| | Tischfrage during the meal ([27](27-family-rituals.md#tischfrage)) | `idle`, holding the card | The question |
| | A birthday | Partyhut all day, `cheer` once each hour on the hour (the wall's quietest loud moment) | Banner text |
| | Night hours | `sleep`, small, in the corner | — |
| | Offline ([09, Freshness](09-clients-and-ux.md#freshness-and-failure)) | `think` beside the freshness note | — |
| **adult** | Empty states | `peek`, 48 px, static unless `member.wusel = lively` | The module's empty text |
| | Today on a special day (a birthday, the first day of Ferien, the Wochenrückblick) | `wave` or `cheer` in the Today header | Yes |
| | The getting-started card completed while Today is open (a card that loads already complete stays hidden, so it happens once) | `cheer`, until tapped away | Yes |

### Where Wusel never appears

- Any **capture flow**: the shopping tiles and quick add, the event and chore editors, the
  timetable grid, the scanner. That protects P6's three seconds.
- **Errors, warnings, destructive confirmations, the PIN pad, sign-in, pairing, invitations
  and deletion.** A mascot beside "Familie löschen" is not funny.
- **Settings**, except the outfit picker and Wusel's own setting.
- **Notifications, widgets, the ICS feed, mail, Shortcuts and MCP responses.**
- **Over content.** Wusel takes its own space; it never covers a band, a tile or a button.

## Accessibility

- The drawing sits in `ExcludeSemantics`. A line is ordinary text in the screen's reading
  order, so a screen reader reads what Wusel says and skips the creature.
- **Reduce motion** ([26](26-colour-and-ambience.md#motion)) shows each pose's static look,
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
  stops after 60 s without a moment, and sleep breathing runs at a low frame rate. The
  acceptance check is CPU use on the wall tablet with the board idle for ten minutes, the
  same with Wusel on and off, written down in the release checklist.
- **Tests.** Goldens (`app/test/golden/`, the repository's first) for every pose in three
  shades, every outfit and one to six tufts; `test/core/wusel_test.dart` for still mode and the
  frames a pose draws. A widget test that the
  capture routes and the PIN pad render no `Wusel`. A unit test that line rotation never
  repeats. The voice rules are a review checklist item for every ARB change under `wusel*`,
  because a word-list test cannot work across four languages.
- **Brand.** `specs/brand/wuselchen[-dark].svg` become `wusel[-dark].svg`, and
  `scripts/brand-assets.js` follows. A golden test draws the painter's `idle` at 100 px next to
  the SVG rendered by the docs, so the two stay the same character.

## How the trial judges Wusel

In M1.6's two weeks ([ADR-020, decision 8](adr/ADR-020-a-lighter-day.md#decision)):

- **Keep** if a child mentions Wusel or taps it unprompted, and no adult has switched it off.
- **Turn down** (the default to `quiet` on the wall) if anyone finds its movement distracting
  in the corner of their eye.
- **Remove a moment** that anyone calls annoying. One complaint is enough, because annoyance
  compounds.
