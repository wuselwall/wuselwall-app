# 17 — Design System: Colour, Type and Form

Implements NFR-13, NFR-16, FR-1.8, FR-1.12, FR-4.10 and FR-7.3. Extends the rules in
[09 — Design system](09-clients-and-ux.md#design-system) with concrete values.

*Decided 2026-10-11: **direction A "Küchentisch"** in every register ([Q39](14-open-questions.md)).
Implemented in `app/lib/app/theme/` — `palette.dart` holds every value below, and
`test/app/theme_test.dart` re-checks each contrast pair. The member palette, presence
treatments and accessibility rules were never part of the choice.*

*Extended 2026-10-24 by [26 — Colour, ambience, celebration](26-colour-and-ambience.md)
(direction A+, [ADR-020](adr/ADR-020-a-lighter-day.md)): module bands, decoration, the wall's
day phases, the kid register's sticker skin, springs and sound. Nothing below changes.*

*Extended 2026-11-15 (issue #280): testers found the colours dire, the dark ones most of all.
The neutrals became **themes** a device chooses from, two light and four dark
([Themes](#themes)); the dark tints, bands and decoration gained colour; the light brand green
became fresher. The member inks, the presence treatments, the rules below and the night theme
did not change.*

**Mockup:** [`specs/mockups/design-system.html`](mockups/design-system.html). Switch
between the directions, the light, dark and night themes, and four simulated kinds of
colour vision. It is the record of the 2026-10-11 choice and shows the neutrals of that
day, not the themes of 2026-11-15; the member inks in it are today's.

## What the palette has to do

The palette was derived from five constraints, not from taste:

1. **People are ink, things are paper.** A member's colour is a saturated *ink*: a
   band, a dot, an avatar ring, the accent while that person is active. Subjects,
   shopping categories and chores get pale *paper* tints with one shared dark ink. A
   seven-year-old can then tell "this is my sister's" from "this is Mathe" without anyone
   explaining the rule.
2. **Green means done, and nobody is green.** Green is reserved for the brand and for
   success (a ticked task, an approved reward). If a member could pick green, their
   tasks would look already finished.
3. **No member is red.** Red is reserved for destructive and error states, which the kid
   register does not even have.
4. **Colour-vision-safe in the order it is handed out.** Each member colour was checked
   against the others under normal vision, protanopia, deuteranopia and tritanopia, in
   light and dark. The method is described in the [method](#method) section.
5. **AA everywhere, in every theme.** Every text and ink token reaches 4.5:1 on
   every surface it can appear on: paper, surface, sunken surface and its own tint.

## Member colours

Eight swatches, offered in this order by the member picker. There is no free colour
choice, because a free choice cannot be guaranteed to pass AA or to stay distinguishable.
`profile.colour_hex` stores the swatch's light ink, and the app resolves it to the
swatch (`MemberPalette.resolve`); a value that matches no swatch snaps to the nearest.
No migration was needed.

| # | Key | Name (de) | Light ink | Dark ink | Light tint | Dark tint | Reference household |
|---|---|---|---|---|---|---|---|
| 1 | `violet` | Violett | `#7B3FE4` | `#C3A6FF` | `#EDE4FB` | `#433959` | Olivia |
| 2 | `petrol` | Petrol | `#08737F` | `#4FCBD6` | `#DCEBED` | `#12484D` | Jack |
| 3 | `amber` | Bernstein | `#9A5300` | `#F0A84E` | `#F1E7DB` | `#533A1D` | Sarah |
| 4 | `raspberry` | Himbeere | `#C2255C` | `#FF85AE` | `#F6E0E8` | `#58333E` | David |
| 5 | `cocoa` | Kakao | `#7A4A2A` | `#D9A684` | `#ECE6E1` | `#4A3C33` | a fifth member or guests |
| 6 | `ocean` | Ozean | `#1A4FA8` | `#86B4FF` | `#DFE6F3` | `#2E405D` | — |
| 7 | `mustard` | Senf | `#736200` | `#E3C83A` | `#EBE9DB` | `#47401B` | — |
| 8 | `orchid` | Orchidee | `#A0309E` | `#F08AE8` | `#F2E2F1` | `#50354E` | — |

- New members get the swatches in this order as they are added, so every household starts
  with the most separable set. The first four are the colours the kiosk mockup already uses, kept because they are
  also the **most separable set of four** the search found. The worst pair is violet
  against petrol under deuteranopia in dark mode, at ΔE<sub>OK</sub> 5.9.
- Swatch 5 keeps five members distinct (worst case ΔE<sub>OK</sub> 4.0). From the sixth
  member on, some pairs merge for a colour-blind viewer (violet and ocean, under
  protanopia). The picker says so in a single line under the swatches, and the initial
  or avatar does the identifying. That is required anyway by FR-1.8.
- Light inks take white text (≥ 5.1:1); dark inks take the theme's ground (≥ 7.3:1 on
  each of the four). Ink on its own tint is ≥ 4.5:1 in light and in dark.
- The dark tints were recoloured on 2026-11-15 (lightness 0.37, chroma 0.055 in OKLCH, at
  the ink's hue) so they read as the member's colour and not as grey. The inks did not move,
  so the colour-vision search below still holds.
- **Night** (kiosk, 21:00–06:00): the dark ink mixed 72 % over the night ground. Every
  value stays ≥ 4.9:1 but loses its glow.

## Themes

A **theme** is the set of neutrals of one shade. A device chooses one light and one dark
theme (Settings → Appearance, and once on a personal device's first arrival at home:
[20](20-onboarding.md#the-first-look)); which of the two is on screen follows the device's
appearance (light, dark or as the OS says). The choice is per device, like the appearance.

| Theme | Shade | Idea |
|---|---|---|
| **Frisch** *(standard)* | light | Cool, minty white paper |
| **Sonnig** | light | Sunny cream paper, warm brown-black ink |
| **Blaue Stunde** *(standard)* | dark | An evening-blue ground with warm, lamp-lit ink |
| **Schiefer** | dark | A cool grey ground, the quietest |
| **Pflaume** | dark | A dusk-violet ground |
| **Kakao** | dark | A warm brown ground: the kitchen table by lamp light |
| Night | night | The kiosk's own, not a choice |

Three rules keep six themes as safe as two were:

1. **A theme changes the neutrals only**: ground, surface, sunken, line, outline, the three
   inks, and the two tints without a hue of their own (`stone` paper and the Settings band,
   which lean toward the ground). Member inks and tints, paper tints, module bands,
   decoration, brand and semantics belong to the *shade* and are the same in each of its
   themes. So the colour-vision checks of the member palette hold for all of them.
2. **Every theme passes every check.** `test/app/theme_test.dart` runs the whole contrast
   list for each theme: text, member inks, brand, controls, tints, bands, decoration, skies.
   A theme that fails one is not offered.
3. **No theme competes with a meaning.** No ground is green (done) or red (danger).

The standard themes are what a device shows until someone chooses, what the splash screen
takes, and what the guide's screenshots show. Today's values before 2026-11-15 (ground
`#F7F4EE` / `#14171A`, brand `#2D6A4F` / `#6CC79A`) are not kept as a theme.

## Neutrals, brand and semantics (direction A)

The light themes:

| Token | Frisch | Sonnig | Use |
|---|---|---|---|
| `bg` | `#F5F9F5` | `#FFF6DA` | Page ground |
| `surface` | `#FFFFFF` | `#FFFFFF` | Cards, sheets, the board's today column |
| `sunken` | `#E9F0E9` | `#FCECC1` | Bands, wells, past days |
| `line` | `#D4DCD4` | `#E4D4AC` | Hairlines, card borders |
| `outline` | `#7E828A` | `#8B7D73` | A control's resting edge, ≥ 3:1 (WCAG 1.4.11) |
| `ink` | `#1C1F23` | `#2A1F17` | Text |
| `ink-2` | `#4A5058` | `#5C4C40` | Secondary text |
| `ink-3` | `#656B75` | `#77675A` | Captions, "aktualisiert vor 4 s" — still ≥ 4.5:1 |
| `stone` paper | `#E0E7E0` | `#F0E5CC` | The paper tint without a hue |
| Settings band | `#E5ECE5` | `#F6EACD` | The `stein` band |

The dark themes and night:

| Token | Blaue Stunde | Schiefer | Pflaume | Kakao | Night |
|---|---|---|---|---|---|
| `bg` | `#151D33` | `#191F25` | `#251929` | `#271B15` | `#0B0A09` |
| `surface` | `#1E2841` | `#232A30` | `#312335` | `#33261E` | `#15130F` |
| `sunken` | `#0E1528` | `#12171C` | `#1C111F` | `#1D130E` | `#080706` |
| `line` | `#333F5D` | `#394148` | `#49394E` | `#4C3C33` | `#2B261F` |
| `outline` | `#75809C` | `#7A8188` | `#897A8E` | `#8C7D75` | `#71654F` |
| `ink` | `#F2EEE6` | `#F2EEE6` | `#F2EEE6` | `#F4EEE1` | `#CDB994` |
| `ink-2` | `#C8C4BC` | `#C8C4BC` | `#C8C4BC` | `#C9C3B7` | `#A8977A` |
| `ink-3` | `#A39F98` | `#A39F98` | `#A39F98` | `#A59F94` | `#938366` |
| `stone` paper | `#303A52` | `#353B42` | `#423547` | `#443730` | `#2C2A26` |
| Settings band | `#273352` | `#2D353D` | `#3E2D43` | `#403027` | none |

The dark grounds sit at OKLCH lightness 0.235 with a visible hue, the surface 0.045 above
and the sunken 0.035 below, so nothing is black and a card stands off the page; the old
dark ground was 0.20 with next to no hue.

Brand and semantics, per shade:

| Token | Light | Dark | Night | Use |
|---|---|---|---|---|
| `brand` ("Tanne") | `#177148` | `#6DD6A2` | `#E0A458` | No-profile accent, primary buttons, success |
| `on-brand` | `#FFFFFF` | `#09281B` | `#1E1406` | |
| `brand-tint` | `#D1F3DF` | `#1B4A34` | `#2A2013` | Selected rows, success containers |
| `on-brand-tint` | `#0B3A27` | `#C0EED4` | `#E8C590` | |
| `danger` | `#B3261E` | `#FF8A80` | — | Destructive actions, errors. Adult register only |
| `warning` | `#8A5A00` on `#FCEFD2` | `#E9B949` on `#4E3D16` | — | Always with an icon; amber is also a member hue |
| `points` ("Punkte-Gold") | `#F2B705` / text `#3E2A00` | same | same | Point coins, the balance, badges |

- The light brand is a fresher green than the brand mark's Tanne `#2D6A4F`, which the
  icon, the logo, Wusel's body and the mails keep. It is as dark as it is because brand
  text also stands on tinted tiles: `#177148` reaches 4.6:1 on the darkest of them (the
  lilac paper), and a lighter green did not.
- There is no *info* blue. Neutral `ink-2` with an icon does that job, which keeps blue
  free for the member palette.
- The night theme is not a dimmed dark theme: it switches to warm amber on near-black,
  with contrast reduced to about 10:1 instead of 15:1, so that a lit wall in a dark
  kitchen does not glare (specs/09).
- When a profile becomes active on a shared or kiosk device, `primary` becomes that
  member's ink (specs/08). With no profile active, `primary` is `brand`.

### Subject and category tints ("paper")

| Key | Light | Dark | Night | Typical subject |
|---|---|---|---|---|
| `blue` | `#DCE8FA` | `#283B57` | `#1D2A3D` | Mathe |
| `rose` | `#F9DDE3` | `#562B37` | `#3A1F26` | Deutsch |
| `lilac` | `#E6DEFA` | `#3D3454` | `#2A2140` | Englisch |
| `leaf` | `#DCEFD8` | `#274229` | `#1F3220` | Sachunterricht |
| `peach` | `#FCE2CA` | `#54301C` | `#3D2817` | Sport |
| `lemon` | `#F6ECB6` | `#4D3603` | `#373011` | Musik |
| `mint` | `#D2EEEA` | `#0D443F` | `#173431` | Kunst |
| `stone` | per theme | per theme | `#2C2A26` | Religion / Ethik |

Text on every tint is `ink` (≥ 12.4:1 light, ≥ 9.5:1 dark). The dark tints sit only
about 1.25:1 from the surface, so tiles also get a 1 px `line` border. The tint is
decoration; the subject is identified by its **icon** (FR-7.3). The night values are the
dark tints of before 2026-11-15: quieter, so a tile does not glow on the wall at night.
The warm dark tints lean toward amber and rust (`lemon` at hue 82, `peach` at 48): a dark
yellow at its own hue reads as olive.

## Presence treatments

Six states, six treatments, each readable in greyscale (NFR-13, ADR-009). `C` is the
member ink, `T` its tint.

| State | Treatment | Second channel |
|---|---|---|
| `working` | Solid `C`, text in `on-C` | Fill weight |
| `home_office` | 45° stripes of `C` over `T`, 6 px period, text in `ink` | Hatch |
| `travel` | Solid `C` with a chevron-shaped leading end and a ✈ glyph | Shape and glyph |
| `away` | `T` fill, 2 px **dashed** `C` border | Dashed edge |
| `off` | No fill, 1.5 px solid `C` outline, text in `ink-3` | Empty, quiet |
| `childcare` | Dot grid of `C` over `T`, with a child glyph | Dots and glyph |

The baseline chip (specs/09, "only the deviation is loud") is `sunken` with `ink-2` text
and a 6 px dot in `C`. It is never a band.

## Typography

All typefaces are self-hosted as assets (NFR-9). None comes from a font CDN at runtime.

| Role | Face | Why |
|---|---|---|
| UI, all registers | **Atkinson Hyperlegible Next** (OFL) | Drawn by the Braille Institute for legibility: distinct `I l 1`, `O 0`, open apertures. It suits a seven-year-old learning to read and a wall read from 2.5 m. Full German coverage, seven weights |
| Kiosk week board: day names, times, numbers | **Barlow Semi Condensed** (OFL), tabular figures | Seven columns at 24 px minimum need a narrow face; the mockup already uses it |

Scale (base × ratio 1.2, rounded): adult base 15 → 12 / 15 / 18 / 22 / 26 / 32; kid base
19 → 16 / 19 / 23 / 28 / 34 / 40; kiosk base 28 → 24 / 28 / 34 / 40 / 48 / 56. These
values match `UiRegister.baseFontSize` and `minFontSize`.

## Icons

There are two sets, each used for one job only, as specs/09 asks ("one coherent set"):

- **Interface icons: Phosphor** (MIT). These are navigation, actions and status. Use the
  *Regular* weight in the adult register, *Bold* in kid and kiosk, and *Fill* for the
  selected state. Package `phosphor_flutter`, bundled.
- **Content icons: Fluent Emoji Flat** (MIT), self-hosted, rendered to PNG at three pixel
  ratios by `scripts/emoji-pictures.mjs` (no SVG renderer in the app). These are chores,
  shopping catalogue items, subjects, rewards and badges. The set is colourful and
  friendly, has a picture for nearly every grocery and school subject, and stays
  readable at 2 m. It supplies the `icon_key` for `catalog_item`, `subject`,
  `task_definition` and `reward`.

The **logo** (Wuselpunkte) and the **mascot** (Wusel, called Wuselchen until 2026-10-24) are
neither: they are brand assets in [specs/brand/](brand/), with their rules in
[ADR-012](adr/ADR-012-product-name.md#logo-and-mascot) and [25](25-wusel.md). Wusel is drawn
only from member colours and `brand`, so it follows the theme like everything else.

## Shape, depth and motion

| Token | Adult | Kid | Kiosk |
|---|---|---|---|
| Radius: controls and cards | 10 | 18 | 14 |
| Radius: chips and bands | 999 (pill) | 999 | 8 (bands must meet across days) |
| Border | 1 px `line` | 2 px `line` | 1 px `line` |
| Elevation | None. Borders separate, shadows only on sheets and dialogs | Same | None |
| Touch target | 44 | 56 | 56 |

A selected segment (`SegmentedButton`) or chip is `brand-tint` (the acting member's tint under `forMember`) with AA text, set once in `AppTheme` and never `sunken`, which is invisible on the page; a selected segment's label is also bold, so the cue is not colour alone.

A segment label is never broken inside a word. Where the labels of a row of segments do not each fit their segment on one line (a narrow phone, a larger text size), the row becomes a wrapping row of chips with the same choices (`_EnumChoice` in the settings, *added 2026-10-26*).

**Clarified 2026-10-17 (A6, `t_da411148`):** targets are actual non-overlapping
hit areas in logical pixels, minimum width **and** height, after visual density,
padding and layout constraints. A nominal `minimumSize` of 56 is not sufficient if
the resulting target is 52. Retain 56×56 for kid and kiosk controls; do not waive
NFR-13 to match current code. A compact decorative band may sit inside a larger
56×56 target; if adjacent bands cannot have separate non-overlapping targets,
use the existing containing row/cell detail action rather than tiny independent
buttons. Keep meaningful band labels in the container's semantics and retain
access to their full detail. Coordinate board actions with A1 (`t_39e3e9d5`).

A row that scrolls sideways (list chips, a scrollable tab bar, the wall's tile strip)
fades out at the edge where more lies beyond it (`EdgeFade` in `core/ui`), so a chip cut at
the edge reads as "scroll for more"; a control beside the row (the list pencil) sits
outside it and never over a chip.

### Who is here

The dock that asks who is acting and the button that lets them go
([09](09-clients-and-ux.md#who-is-here)) are the app's one floating surface without an
outline. Fill `sunken` (`surfaceContainer`); corners 40 for the dock, a full pill for the
button; the edge is the surface's own colour blurred outwards (14 blur, 3 spread), so it
fades into whatever page lies under it; a wide, faint shadow (32 blur, 10 down, 22 % of
the scheme's shadow) lifts it. 12 around it, 12 above and below the avatars, 24 at the
dock's ends. The avatars keep their inks; the chosen person's ring is gone, because only
one person is shown once someone is chosen.

### Choosing a time

*Added 2026-11-14 (issue #241), after a family called Material's clock dial "weird".* A time of
day is always asked the same way: `showTimeWheel` (`core/ui/time_wheel.dart`), a sheet from the
bottom with an hour wheel and a minute wheel, the chosen row on a `sunken` band. No clock dial
and no switch between hours and minutes; `showTimePicker` is not used anywhere (a test checks).

- The minutes move in steps of five. **Jede Minute** shows all sixty, and a time that is on no
  step opens that way, so no saved minute is ever rounded by opening the sheet.
- Hours and minutes each go round; neither carries into the other.
- 24 hours, except in English on a device set to 12 hours, where a third wheel chooses AM or PM:
  the same rule (`clockIs24Hour`) as the texts that show a time. The settings store and show
  24-hour times and ask for them that way.
- The sheet is named after its field (*Beginn*, *Ende*) where the field has a name, else *Uhrzeit*.
- A screen reader hears each wheel as one adjustable value ("Stunde, 14"), as the platforms' own
  pickers are. With a keyboard the hours have the focus: digits type the time ("0730"), the
  arrows step, Tab changes the wheel and Enter takes the time. A mouse turns a wheel by its
  scroll wheel, by dragging or by a click on a row.
- A row is as tall as its number at the current text size and never under 44; a short screen
  shows three rows instead of five.

Compared before choosing (the owner chose the wheels): Material's dial opened in its keyboard
mode, a grid of hour and minute buttons, and a typed field with a list of quarter hours.

The 24 px kiosk minimum, system text scaling and rendered contrast acceptance are
clarified in [09 — Degradation rules](09-clients-and-ux.md#degradation-rules).

Motion: 150 ms standard, 250 ms emphasised, both `easeOutCubic`. The points fly to the
balance in 600 ms along a curve, with a coin-count tick. All of it follows the system's
reduce-motion setting.

## Words for people

*Decided 2026-11-04.* One word per person in each language, everywhere people read: the app, mail and
the family guide. Code, the database and these specs keep `guardian`, `member`, `child` and `adult`.

| | de | en | fr | es |
|---|---|---|---|---|
| `guardian` | Eltern, ein Elternteil | parents, a parent | parents, un parent | padres, madre o padre |
| `kind = child` | Kind, Kinder | child, children | enfant, enfants | niño, niños |
| Adult `member` (au pair, grandparent) | Weitere:r Erwachsene:r | other adult | autre adulte | otro adulto |
| To a child, about who decides | deine Eltern | your parents | tes parents | tus padres |

*Member* (Mitglied, membre, miembro) means everyone in the family and nothing else; *adult* is the
kind of person, not the one who decides. Settings a child mostly uses say *children*, even though
the rule behind them also covers other adults (`calendar.members_edit_own_events`,
`school.members_report_changes`). Help text says what a setting does, and gives advice a family can
use; never a remark for the makers. `app/test/l10n_test.dart` checks the words it can.

## The three directions

The member palette, presence, icons and rules above are fixed. The directions differ
in ground, brand accent, shape and typeface, which together set how much of the kid
register's energy reaches the shared shell.

| | **A — Küchentisch** *(chosen)* | **B — Pausenhof** | **C — Fjord** |
|---|---|---|---|
| Idea | A calm, warm kitchen table that the members' colours bring to life | A schoolyard sticker book: sunny, chunky, playful | Nordic quiet: cool, airy, very restrained |
| Ground | Warm paper `#F7F4EE` | Sunny cream `#FFF8E7` | Cool fog `#EEF2F5` |
| Brand | Tanne green `#2D6A4F` | Sonnengelb `#F2B705`, used as a fill with 2 px ink outlines | Slate blue `#2F5D8A` |
| Shape | 10 / 18 radius, hairlines | 20 / 28 radius, 2 px ink outlines, offset "sticker" shadows | 6 radius, hairlines, lots of air |
| Type | Atkinson Hyperlegible Next | Fredoka headings + Nunito body | Figtree |
| Strengths | Grown-up enough for the laptop, warm enough for the iPads; the member colours stay the loudest thing on screen, which is the wayfinding rule; continuous with the existing mockups | Kids love it on sight; the outlines make every object read clearly at a distance | Most restful on the wall at night; the most "designed" look |
| Weaknesses | The least immediately exciting for a 7-year-old | Tiring on the adult laptop; yellow on cream is 1.7:1, so the outline must always be there; Fredoka is less legible than Atkinson for early readers | Slate brand sits close to the ocean member; cool greys make the kitchen feel like an office; pale grounds weaken the member bands |

**Decided: A, in every register.** The kid register differs only by the register
tokens it already has (larger type, 56 px targets, radius 18). Borrowing B's outlines and
sticker shadows for the kid register was considered and not adopted. It remains the
obvious next step if the children find A too plain. *Adopted 2026-10-24 for the kid
register only ([26](26-colour-and-ambience.md#the-kid-registers-sticker-skin)).*

## Flutter mapping

As implemented:

- `AppTheme.look(register, look)` builds the `ColorScheme` **explicitly** from
  `palette.dart` rather than with `ColorScheme.fromSeed`, because the seed's tonal
  algorithm would not reproduce the values verified here. `AppTheme.build(register,
  shade)` is the same for the shade's standard theme. `surface` is the paper ground,
  and cards use `surfaceContainerLow`, which is white in light.
- `Look` is a theme: `frisch | sonnig | blaueStunde | schiefer | pflaume | kakao | night`,
  each with its `shade`. `Palette.look(look)` gives its neutrals; `Look.standard(shade)`
  the theme a device starts with. `looksProvider` (`app/theme/appearance.dart`) keeps the
  device's light and dark theme in its secure storage beside the appearance, and whether
  the choice was offered once.
- `WwColors` (a `ThemeExtension`, read with `context.ww`) carries what Material has no
  slot for: `ink2`/`ink3`, `sunken`, `line`, success, warning, points, member colours
  (`context.ww.member(member.color)` → ink, onInk, tint), paper tints, and `qrInk` /
  `qrPaper` for QR codes (`core/ui/qr_code_view.dart`): the theme's own text pair with
  the darker side as ink, since scanners need dark on light — `ink` on `surface` in
  light, `bg` on `ink` in dark and night, so a code never glares at night. It carries the
  device's `look`, and painters that need a theme's colours (the sky, the module
  pictures, Wusel's mouth) take that.
- `Shade` is `light | dark | night`. Night is a third `ThemeData`, used by the kiosk
  register from 21:00 to 06:00 (`nightProvider`, which rebuilds at each boundary)
  regardless of the OS setting or the device's appearance.
- Light or dark follows the OS by default. Each device can fix it to light or dark under
  Settings → Appearance (`appearanceProvider` in `app/theme/appearance.dart`, kept in
  the device's secure storage, not on the server: it is a per-device preference like
  the OS setting it overrides). The same sheet offers the themes of light and of dark
  (`features/settings/ui/look_chooser.dart`); a tap applies at once, to the page behind
  the sheet too. A free colour choice is still not offered: a theme is in the list only
  because it passes every check.
- On shared and kiosk devices, `AppTheme.forMember` swaps `primary` to the acting
  member's ink. This happens in one `Theme` wrapper in `MaterialApp.builder`, not in
  widgets.
- Fonts are bundled under `app/assets/fonts/` with their OFL licences, which
  `registerFontLicenses()` adds to the licence page. Glyphs they lack (arrows, emoji,
  other scripts) come from the system fonts on phones. The web app fetches a Noto
  fallback shard only when text needs one, and only from its own origin:
  `scripts/web-font-fallback.sh` copies every shard Flutter can ask for into the build,
  pinned in `scripts/web-font-fallback.lock` (NFR-9: never from Google's CDN). Noto Sans
  Symbols stays under `app/assets/fonts/`, not bundled, as the widget tests' fallback; its
  pinned upstream source and checksums travel beside it.
- Fluent Emoji is in use for shopping tiles, chores, rewards and badges; subjects still
  use Material icons. Not yet done: Phosphor (it arrives with the first screen that
  needs it), presence painters (M1.3), and the member colour picker (M0.1).

## Method

Contrast is WCAG 2.x relative luminance. Distinguishability is the Euclidean distance in
OKLab (×100) after simulating protanopia, deuteranopia and tritanopia with the Machado
2009 full-severity matrices. Every pair was checked in both themes, and a set is scored
by its single worst pair. Values below about 3 merge on screen. All 14 candidates passed
AA before scoring. The search showed that no set of six or more keeps every pair
apart, which is why initials are part of the design and not a fallback.

