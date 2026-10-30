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

**Mockup:** [`specs/mockups/design-system.html`](mockups/design-system.html). Switch
between the directions, the light, dark and night themes, and four simulated kinds of
colour vision.

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
5. **AA everywhere, in all three themes.** Every text and ink token reaches 4.5:1 on
   every surface it can appear on: paper, surface, sunken surface and its own tint.

## Member colours

Eight swatches, offered in this order by the member picker. There is no free colour
choice, because a free choice cannot be guaranteed to pass AA or to stay distinguishable.
`profile.colour_hex` stores the swatch's light ink, and the app resolves it to the
swatch (`MemberPalette.resolve`); a value that matches no swatch snaps to the nearest.
No migration was needed.

| # | Key | Name (de) | Light ink | Dark ink | Light tint | Dark tint | Reference household |
|---|---|---|---|---|---|---|---|
| 1 | `violet` | Violett | `#7B3FE4` | `#C3A6FF` | `#EDE4FB` | `#3D3B50` | Olivia |
| 2 | `petrol` | Petrol | `#08737F` | `#4FCBD6` | `#DCEBED` | `#264248` | Jack |
| 3 | `amber` | Bernstein | `#9A5300` | `#F0A84E` | `#F1E7DB` | `#463B2C` | Sarah |
| 4 | `raspberry` | Himbeere | `#C2255C` | `#FF85AE` | `#F6E0E8` | `#493440` | David |
| 5 | `cocoa` | Kakao | `#7A4A2A` | `#D9A684` | `#ECE6E1` | `#423B37` | a fifth member or guests |
| 6 | `ocean` | Ozean | `#1A4FA8` | `#86B4FF` | `#DFE6F3` | `#313E50` | — |
| 7 | `mustard` | Senf | `#736200` | `#E3C83A` | `#EBE9DB` | `#444228` | — |
| 8 | `orchid` | Orchidee | `#A0309E` | `#F08AE8` | `#F2E2F1` | `#46354B` | — |

- New members get the swatches in this order as they are added, so every household starts
  with the most separable set. The first four are the colours the kiosk mockup already uses, kept because they are
  also the **most separable set of four** the search found. The worst pair is violet
  against petrol under deuteranopia in dark mode, at ΔE<sub>OK</sub> 5.9.
- Swatch 5 keeps five members distinct (worst case ΔE<sub>OK</sub> 4.0). From the sixth
  member on, some pairs merge for a colour-blind viewer (violet and ocean, under
  protanopia). The picker says so in a single line under the swatches, and the initial
  or avatar does the identifying. That is required anyway by FR-1.8.
- Light inks take white text (≥ 5.1:1); dark inks take the dark ground `#14171A`
  (≥ 7.9:1). Ink on its own tint is ≥ 4.5:1 in both themes.
- **Night** (kiosk, 21:00–06:00): the dark ink mixed 72 % over the night ground. Every
  value stays ≥ 4.9:1 but loses its glow.

## Neutrals, brand and semantics (direction A)

| Token | Light | Dark | Night | Use |
|---|---|---|---|---|
| `bg` | `#F7F4EE` | `#14171A` | `#0B0A09` | Page ground |
| `surface` | `#FFFFFF` | `#1C2024` | `#15130F` | Cards, sheets, the board's today column |
| `sunken` | `#EFEBE3` | `#101315` | `#080706` | Bands, wells, past days |
| `line` | `#DDD8CF` | `#2E343A` | `#26221C` | Hairlines, card borders |
| `ink` | `#1C1F23` | `#ECE8E1` | `#CDB994` | Text |
| `ink-2` | `#4A5058` | `#B5B2AB` | `#A8977A` | Secondary text |
| `ink-3` | `#656B75` | `#8E8B85` | `#938366` | Captions, "aktualisiert vor 4 s" — still ≥ 4.5:1 |
| `brand` ("Tanne") | `#2D6A4F` | `#6CC79A` | `#E0A458` | No-profile accent, primary buttons, success |
| `on-brand` | `#FFFFFF` | `#0C2A1D` | `#1E1406` | |
| `brand-tint` | `#DCEBE2` | `#1D3A2C` | `#2A2013` | Selected rows, success containers |
| `danger` | `#B3261E` | `#FF8A80` | — | Destructive actions, errors. Adult register only |
| `warning` | `#8A5A00` on `#FCEFD2` | `#E9B949` | — | Always with an icon; amber is also a member hue |
| `points` ("Punkte-Gold") | `#F2B705` / text `#3E2A00` | same | same | Point coins, the balance, badges |

- The neutrals lean warm, toward the kitchen, and match the existing mockups.
- There is no *info* blue. Neutral `ink-2` with an icon does that job, which keeps blue
  free for the member palette.
- The night theme is not a dimmed dark theme: it switches to warm amber on near-black,
  with contrast reduced to about 10:1 instead of 15:1, so that a lit wall in a dark
  kitchen does not glare (specs/09).
- When a profile becomes active on a shared or kiosk device, `primary` becomes that
  member's ink (specs/08). With no profile active, `primary` is `brand`.

### Subject and category tints ("paper")

| Key | Light | Dark | Typical subject |
|---|---|---|---|
| `blue` | `#DCE8FA` | `#1D2A3D` | Mathe |
| `rose` | `#F9DDE3` | `#3A1F26` | Deutsch |
| `lilac` | `#E6DEFA` | `#2A2140` | Englisch |
| `leaf` | `#DCEFD8` | `#1F3220` | Sachunterricht |
| `peach` | `#FCE2CA` | `#3D2817` | Sport |
| `lemon` | `#F6ECB6` | `#373011` | Musik |
| `mint` | `#D2EEEA` | `#173431` | Kunst |
| `stone` | `#E8E4DC` | `#2C2A26` | Religion / Ethik |

Text on every tint is `ink` (≥ 12.7:1 light, ≥ 10.8:1 dark). The dark tints sit only
about 1.2:1 from the surface, so tiles also get a 1 px `line` border. The tint is
decoration; the subject is identified by its **icon** (FR-7.3).

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

The 24 px kiosk minimum, system text scaling and rendered contrast acceptance are
clarified in [09 — Degradation rules](09-clients-and-ux.md#degradation-rules).

Motion: 150 ms standard, 250 ms emphasised, both `easeOutCubic`. The points fly to the
balance in 600 ms along a curve, with a coin-count tick. All of it follows the system's
reduce-motion setting.

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

- `AppTheme.build(register, shade)` builds the `ColorScheme` **explicitly** from
  `palette.dart` rather than with `ColorScheme.fromSeed`, because the seed's tonal
  algorithm would not reproduce the values verified here. The old seed `#2E7D6B` was
  4.49:1 on paper, just below AA; `brand` is `#2D6A4F`. `surface` is the paper ground,
  and cards use `surfaceContainerLow`, which is white.
- `WwColors` (a `ThemeExtension`, read with `context.ww`) carries what Material has no
  slot for: `ink2`/`ink3`, `sunken`, `line`, success, warning, points, member colours
  (`context.ww.member(member.color)` → ink, onInk, tint), paper tints, and `qrInk` /
  `qrPaper` for QR codes (`core/ui/qr_code_view.dart`): the shade's own text pair with
  the darker side as ink, since scanners need dark on light — `ink` on `surface` in
  light, `bg` on `ink` in dark and night, so a code never glares at night.
- `Shade` is `light | dark | night`. Night is a third `ThemeData`, used by the kiosk
  register from 21:00 to 06:00 (`nightProvider`, which rebuilds at each boundary)
  regardless of the OS setting or the device's appearance.
- Light or dark follows the OS by default. Each device can fix it to light or dark under
  Settings → Appearance (`appearanceProvider` in `app/theme/appearance.dart`, kept in
  the device's secure storage, not on the server: it is a per-device preference like
  the OS setting it overrides). Further colour schemes are not offered; the palette's
  contrast and colour-vision checks hold for the light, dark and night values only.
- On shared and kiosk devices, `AppTheme.forMember` swaps `primary` to the acting
  member's ink. This happens in one `Theme` wrapper in `MaterialApp.builder`, not in
  widgets.
- Fonts are bundled under `app/assets/fonts/` with their OFL licences, which
  `registerFontLicenses()` adds to the licence page.
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

