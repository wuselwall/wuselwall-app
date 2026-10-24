# 26 — Colour, ambience, celebration: direction A+

*Added 2026-10-24 with [ADR-020](adr/ADR-020-a-lighter-day.md). Not built.* This extends
[17 — Design system](17-design-system.md) and changes none of its verified values. Direction
A "Küchentisch" stays. Its member palette, presence treatments and AA rules stay. This
document adds four layers on top: colour by module, decoration, ambience on the wall, and
celebration (motion, sound and haptics). The mascot that uses them is [25](25-wusel.md).

**Mockup:** [`specs/mockups/wusel-and-colour.html`](mockups/wusel-and-colour.html) shows the
module bands, the decoration, the wall's four phases and the kid sticker cards in light and
dark.

## What stays, what is added

| Stays (17) | Added (here) |
|---|---|
| People are ink, things are paper | **Modules are paper too**: each gets a pale band, so any hue is allowed |
| Green means done, and nobody is green | Decoration may use a soft green (mint), never as a state and never with a tick |
| No member is red | No module or decoration is red either. Coral is the closest, and it is pale |
| Member colours are the loudest thing on screen | Bands and decoration stay below member chroma; a member chip on a band still wins |
| AA everywhere in all three shades | Every new text pair is checked, and `ink-3` is not allowed on a band (see below) |
| The night theme's warm amber | The wall's night phase *is* the night theme; decoration is off at night |

The rule that ties it together: **colour goes on large shapes, never on text.** Text stays
`ink` or `ink-2`. Meaning stays with icons and labels. Decoration means nothing, so a colour-blind
viewer loses nothing.

## Module bands

Each module's top-level screen gets a **header band**: a full-width area behind the title,
the week or day switcher and the module's illustration. The rest of the screen keeps `bg` and
white cards. On the wall, the bands appear only in tap-through details, because the week board
keeps its own zones.

| Module | Key | Light band | Dark band | Illustration (Fluent Emoji, large, cropped) |
|---|---|---|---|---|
| Heute | `sonne` | `#FFF0C2` | `#3A3216` | The day-phase sky (see [Ambience](#ambience)) |
| Kalender | `himmel` | `#DCEBFF` | `#1B2B40` | 🗓️ |
| Aufgaben | `koralle` | `#FFE1D6` | `#3D2420` | 🧹 ⭐ |
| Essen | `aprikose` | `#FFE5C7` | `#3B2A18` | 🍲 |
| Einkauf | `minze` | `#D5F2E6` | `#173429` | 🧺 |
| Stundenplan | `flieder` | `#EEE8FF` | `#2A2342` | 🎒 |
| Einstellungen | `stein` | `#ECE8E0` | `#26282B` | none (settings stay calm) |

Contrast, checked 2026-10-24 with the WCAG 2.x formula of [17's method](17-design-system.md#method):

| Pair | Light, worst band | Dark, worst band |
|---|---|---|
| `ink` on band | 13.4:1 (koralle) | 10.4:1 (sonne) |
| `ink-2` on band | 6.6:1 (koralle) | 6.0:1 (sonne) |
| `ink-3` on band | **4.3:1, fails** | **3.8:1, fails** |
| Any member ink on band, as text | 4.51:1 (on koralle; flieder was lightened from `#EAE2FF`, where petrol reached only 4.46:1) | 5.6:1 (raspberry on sonne) |

So **`ink-3` is never used on a band.** Captions there use `ink-2`. Night has no bands: the
night theme stays as it is.

- **The band follows the module, not the member.** On a shared device the acting member's
  ink still becomes `primary` ([17](17-design-system.md#flutter-mapping)). The band does not
  change.
- **The kid register keeps the same bands**, so a child learns "yellow is my day, coral is
  my tasks". There they are taller, with Wusel standing in them ([25](25-wusel.md#where-wusel-appears)).
- **Navigation.** The selected destination's indicator takes the module's band colour instead
  of the neutral one, so the bottom bar and the rail turn colourful without any extra element.

## Decoration

Six decorative colours exist for illustration only. They fill blobs behind empty-state
scenes, the confetti, the Wochenrückblick's cards ([27](27-family-rituals.md#wochenrückblick))
and the sticker shadows of the kid register. Text may sit on them only in `ink` (light shade)
or the dark ground `#14171A` (dark shade).

| Key | Light | Dark | `ink` on light | `#14171A` on dark |
|---|---|---|---|---|
| `sun` | `#FFC94D` | `#C9A23E` | 10.8:1 | 7.5:1 |
| `sky` | `#8EC5FF` | `#6E9BCB` | 9.1:1 | 6.2:1 |
| `coral` | `#FF9F85` | `#CC8370` | 8.3:1 | 6.0:1 |
| `apricot` | `#FFB570` | `#B7834F` | 9.5:1 | 5.5:1 |
| `mint` | `#7FD8B5` | `#4E9A7E` | 9.8:1 | 5.4:1 |
| `lilac` | `#B9A3FF` | `#9585D4` | 7.7:1 | 5.6:1 |

Against the page ground they sit at 1.4–2.0:1. That is deliberate: they are soft shapes, not
borders, and nothing depends on seeing their edge.

**A screen shows at most two decorative colours.** The eight member inks, `brand` and
`points` already make a lot of colour. A third decorative hue turns a family's screen into
confetti.

## The kid register's sticker skin

Direction B's form, without B's colours ([17, the three directions](17-design-system.md#the-three-directions)):

| Token | Kid (new) | Was |
|---|---|---|
| Card border | 2 px `ink` at 85 % (dark: `line` at full) | 2 px `line` |
| Card shadow | Offset 0 / 4 px, no blur, in the card's module decorative colour at 60 % | none |
| Radius, cards and controls | 22 | 18 |
| Pressed state | The card moves 3 px down and the shadow shrinks to 1 px (a spring, see [Motion](#motion)) | Ripple only |
| Task card, done | Fills with `brand-tint`; the tick pops in on a spring | Strike-through |

The offset shadow makes every card read as an object that can be pressed, which matters most
to the seven-year-old. It is limited to the kid register because it tires the eye on a laptop.
That is why B lost in [Q39](14-open-questions.md).

## Ambience

On the **wall**, and in the **Today header** of the other registers, the time and the date
change the look. Everything is computed on the device from the clock, the household's region
and its holidays, with no network. It changes decoration only, never layout or content.

### Day phases

| Phase | From–to | Sky (top → bottom) | Notes |
|---|---|---|---|
| Morgen | night end (`device.night_hours`, default 06:00) – 10:00 | `#FFD9B8` → `#FFF3E4` | Peach dawn, a low sun |
| Tag | 10:00 – the second `board.day_parts` time (default 17:00) | `#CFE6FF` → `#F2F8FF` | Pale sky, two clouds |
| Abend | 17:00 – night start (default 21:00) | `#FFC9A8` → `#EBD9F2` | Dusk; the sun sets in the band during the hour before night |
| Nacht | Night hours | The night theme of 17; a sky `#0B0A09` → `#1A1630` with a few dim stars, only in the kiosk header | Decoration off; Wusel sleeps |

Text over the sky is `ink` (≥ 11.2:1 on every stop) or `ink-2` (≥ 5.5:1). Member inks over
the dusk stop drop to 3.8:1, so **member colours never sit directly on the sky**. They stay on
the board's opaque cards. In the dark shade the sky uses the dark band `#3A3216` with the same
sun and moon shapes, and no gradient.

The sky is one gradient plus three vector layers (sun or moon, clouds, a hill silhouette in
the `sonne` band colour), recoloured per phase. The phase changes with a 30 s cross-fade. It
never jumps while someone is looking.

### Seasons and occasions

A catalogue of date rules in the app (`app/lib/core/ambience/occasions.dart`). Every
occasion has its own switch under *Erweitert*, and its default comes from the household's
country ([Settings](#settings), [defaults per country](#defaults-per-country)):

| Occasion | When | What changes |
|---|---|---|
| Season | Spring Mar–May, summer Jun–Aug, autumn Sep–Nov, winter Dec–Feb (northern hemisphere; Q52) | One small layer in the sky: blossoms, sun rays, leaves, snowflakes. Wusel's Mütze und Schal on the wall in winter |
| Birthday | A member's `birthday` ([27](27-family-rituals.md#birthdays)) | Bunting in that member's ink across the board's header, the Partyhut, a banner "Olivia hat Geburtstag!" |
| Ferien | The first and last day of imported or hand-entered Ferien | A ribbon "Ferien!" / "Morgen ist wieder Schule" in the day header |
| Advent | The four Sundays before 24 December through the 24th | A candle row in the header; one more lit each Advent Sunday |
| Ostern | Easter Sunday ± 2 days, **computed for each year**: Western Easter with the Gregorian computus, Orthodox Easter with the Julian computus converted to the Gregorian calendar. The two coincide in some years and are up to five weeks apart in others | Eggs in the hill layer |
| Silvester / Neujahr | 31 Dec – 1 Jan | Small fireworks in the night sky (static under reduce motion) |

#### Defaults per country

*Decided 2026-10-24 ([Q52](14-open-questions.md)).* Every rule is computed on the device from
the date alone, with no table to download. The country is the first part of
`household.region`.

| Country of the region | On by default | Off by default |
|---|---|---|
| Every country | Season, birthday, Ferien | Silvester / Neujahr |
| DE, AT, CH, LI, and the other countries whose public Easter holiday follows the Western date (FR, ES, IT, NL, BE, LU, PL, CZ, …) | Advent, Ostern (Western) | Ostern (Orthodox) |
| GR, CY, RO, BG, RS, ME, MK, and the other countries whose public Easter holiday follows the Orthodox date | Ostern (Orthodox) | Advent, Ostern (Western) |
| A region without a country default | Only the "every country" row | Everything else |

- The rule for picking a column is the public-holiday data the server already imports from
  OpenHolidays: whichever Easter date the region's own public holidays use. A new country
  then needs no code, only the table above when it differs.
- **A household can turn on both Easters**, for a family that keeps both. They show the same
  eggs; on a year when the dates coincide, the eggs show once.
- **Further occasions** that follow other calendars (Ramadan and Eid al-Fitr, Hanukkah,
  Diwali, Nouruz) need bundled date tables or a lunar computation. They are not in step 11.
  The catalogue is built as data so that each one is a small addition when a family asks for
  it (P7).

### Protecting the wall

- **Burn-in.** The wall tablet may be OLED ([Q54](14-open-questions.md)). The operating
  systems' own burn-in protection covers their status bars and always-on clocks, not a
  full-screen app that shows the same header for months. So the app shifts the whole board by
  up to 2 px every 10 minutes (`device.pixel_shift`, an on-device setting under *Erweitert*, on
  by default for the kiosk register because it costs nothing on LCD). The night sky has no
  static bright pixels.
- **Nothing moves at two metres except the clock** and a moment that just happened (a cheer,
  a birthday cheer on the hour). The sky's cross-fade is too slow to notice.
- **No sound at night**, ever.

## Celebrations

| Moment | Register | What happens | Duration |
|---|---|---|---|
| One chore ticked | kid, kiosk | The tick pops on a spring; the points fly into the balance with a coin tick ([06](06-module-tasks.md#screens)); a light haptic | 600 ms |
| The last chore of the day | kid, kiosk | Wusel `cheer` with confetti in the family's member inks plus `points` gold; a medium haptic; the *fertig* sound | 1.2 s |
| A reward redeemed, a badge earned | kid | Wusel `proud`; the badge grows in from the centre on a spring; the *badge* sound | 1.2 s |
| A birthday, first open that day | kid | Full-screen confetti behind Wusel with the Partyhut; the *badge* sound | 2 s, tap to skip |
| A shopping trip finished (the last item ticked) | adult | A small burst over the list, a light haptic; no sound in a shop | 600 ms |
| The Wochenrückblick opened | all | The cards slide in one after another on springs | 250 ms each |

- **Confetti** is a small `CustomPainter` (about 40 particles, under 150 lines) in
  `core/ui/confetti.dart`, not a package, so the colours stay under the palette's control. If
  writing it proves to be more than an evening's work, `flutter_confetti` (MIT, pure Dart) is
  the fallback.
- **The budget is one celebration per moment.** A chore ticked on the wall while the last-chore
  cheer runs does not start a second burst.
- **Celebrate completions only, never their absence.** There is nothing for an unfinished day,
  not even a neutral "maybe tomorrow".

## Motion

17's durations stay: 150 ms standard, 250 ms emphasised, `easeOutCubic`. Added:

- **Two springs** for presses, pops and Wusel: `Tokens.springSnappy` (stiffness 600,
  damping ratio 0.7) for press and tick, and `Tokens.springBouncy` (stiffness 300, damping
  ratio 0.5) for Wusel's jumps and the badge. Flutter's own `SpringSimulation` is enough. The
  `motor` package (MIT) is optional and not needed.
- **One motion check**, `motionAllowed(context)` in `core/ui/motion.dart`. Every animation in
  this document asks it, and today's direct calls to `MediaQuery.disableAnimationsOf` move
  behind it. It must also honour iOS *Reduce Motion*. Whether that sets `disableAnimations` in
  current Flutter is unverified ([Q55](14-open-questions.md)), so step 11 starts with a test
  on a real iPad.
- When motion is not allowed, springs snap to their end, confetti and Wusel's motion are
  skipped, and the static pose and the text carry the moment.

## Sound and haptics

- **Four sounds**, bundled and each under 1 s and 30 KB: *tick* (a chore ticked), *fertig* (the
  last chore), *badge* (a reward or a badge), and *coin* (points arriving). They are written for
  the project or taken from CC0 sources, with each file's origin recorded in `NOTICE`
  ([Q56](14-open-questions.md)).
- **Playback** uses a small player package (`audioplayers`, MIT, is the candidate), measured
  for latency on the kids' tablets before it is accepted. A *tick* that arrives 300 ms late
  feels broken.
- **When sound plays.** `member.completion_sound` (existing, default on) governs the acting
  member's sounds. `device.sounds` (new) can silence a device. Never at night, never in the
  adult register except the shopping-trip haptic, and never on the wall unless the device
  allows it. The system's silent switch is respected.
- **Haptics** use `HapticFeedback` from Flutter's services library, with no package:
  `lightImpact` on a tick, `mediumImpact` on the last chore. Phones and tablets without a motor
  ignore them.

## Settings

New rows in [21](21-household-settings.md#a-lighter-day):

| Key | Scope | Default | Values |
|---|---|---|---|
| `ambience.occasions` | household, under *Erweitert* | by country, see [defaults per country](#defaults-per-country) | one switch per occasion |
| `ambience.sky` | device | on | on · off (a plain band instead of the sky) |
| `device.sounds` | device | kiosk off, other devices on | on · off |
| `device.pixel_shift` | device, under *Erweitert* | kiosk on, other devices off | on · off |

## Flutter mapping

- `palette.dart` gains `ModuleBand` (seven keys × light/dark), `Decor` (six keys ×
  light/dark) and `SkyPhase` (four phases × gradient stops). `WwColors` exposes
  `context.ww.band(Module.tasks)` and `context.ww.decor(Decor.sun)`.
- A `ModuleScaffold` (or a `ModuleHeader` sliver) draws the band, the illustration and an
  optional Wusel. Each module's top screen adopts it once. No widget picks band colours itself.
- `ambienceProvider` (Riverpod) combines the clock (rebuilding at phase boundaries, like
  `nightProvider`), the household's region, holidays, birthdays and `ambience.occasions` into
  an `Ambience` value (phase, season, today's occasions). The sky painter and Wusel's outfit
  read it.
- `test/app/theme_test.dart` gains every pair in this document: text on bands, text on
  decoration, text on every sky stop, and member inks on bands. The `ink-3`-on-band ban is
  enforced by a lint-style test over `ModuleHeader`'s text styles.

## How the trial judges the colour

- **Keep** if nobody in the pilot household asks for the old look and the children can name
  a module by its colour.
- **Tone down** the kid sticker skin (shadow off) if the nine-year-old calls it babyish. That
  is the age where it most likely tips.
- **Turn off** `ambience.sky` on the wall by default if anyone finds it distracting from two
  metres.
