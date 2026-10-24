# ADR-020 — A lighter day: joy as a product goal, Wusel, colour layers and family rituals

**Status:** Accepted · 2026-10-24 · Built 2026-10-24 on `feat/a-lighter-day`, see the [amendment](#amendment-2026-10-24-built) · Amends [ADR-012](ADR-012-product-name.md)
(the mascot is renamed *Wusel* and given poses and a voice) and
[01](../01-vision-and-scope.md) (a fourth property of the vision, a seventh principle, a
seventh success criterion); extends [17](../17-design-system.md) without reopening
[Q39](../14-open-questions.md); moves [23 R1.5](../23-roadmap-after-alpha.md#r1--learn-from-the-alpha)
(birthdays) forward; opens Q51–Q57 (Q51–Q54 decided the same day).

## Context

By the Alpha, every module answers its question efficiently, and the result reads as
clinical. On 2026-10-24 the user wrote:

> Currently the Wuselwall app is a little "clinical" and not really joyful. Its all about
> efficiency and helping families reduce their mental load, which is great. But it should
> also enlighten adults and kids and make their day better.

The research for this decision (2026-10-24, three research passes) found the following.
They are associations from mostly correlational studies, used here as design input, not as
promises:

- **Routines and rituals are different things** (Fiese et al. 2002, a review of 32 studies).
  A routine says *what needs to be done*; a ritual says *who we are*. Both are associated with
  children's well-being and family satisfaction. WuselWall is strong on routines and has no
  rituals at all. That gap is the "clinical" feeling.
- **Expected, contingent, tangible rewards can undermine intrinsic motivation** (Deci,
  Koestner & Ryan 1999, contested in size by Cameron & Pierce). Informational praise and
  unexpected celebration do not. The points economy stays as designed, so the new joy must
  not be another currency.
- **Mascots work when they react to moments and fail when they interrupt** (Clippy) or
  guilt-trip (Duolingo's reminder persona). Finch keeps its pet from ever dying because that
  "can be too anxiety-inducing". The persona effect of pedagogical agents is small but positive.
- **Joy can come from colour and form without breaking wayfinding**: colour on large shapes,
  not on text; decoration that carries no meaning; the chrome stays calm and the moments are
  loud.

## Decision

1. **The mission gains a fourth property: the day should feel lighter, not only tidier.**
   [01](../01-vision-and-scope.md) records it beside capture, the glanceable wall and the
   visible week, with a seventh principle (*joy without levers*) and a seventh success
   criterion.
2. **The mascot is called Wusel** (was *Wuselchen*). The design of ADR-012 concept B stays:
   the round Tanne-green body, four tufts in the family's colours, the "w" mouth. Wusel gets
   arms and feet that appear only in poses, seven poses, a voice guide and appearance rules
   per register: [25](../25-wusel.md).
3. **Wusel appears in every register, scaled to it.** In the kid register it is lively,
   animated and speaks. On the wall it is ambient: a morning wave, sleepy at night, and a
   cheer when a chore is done. In the adult register it is rare, small and quiet, and a member
   can switch it off. It never appears in a capture flow, never interrupts and never speaks
   in a notification.
4. **Wusel is drawn in code**: a `CustomPainter` driven by a pose model, recoloured at runtime
   from member colours and the shade. It has no Rive, no Lottie, no native dependency and no
   build-time download. The SVG in `specs/brand/` stays the reference drawing for the website
   and the docs.
5. **No unlocks.** A child may dress Wusel (a hat, a scarf, glasses) from the start, with no
   currency, no scarcity and nothing to lose. Wusel never gets hungry, sad, ill or lonely.
6. **Colour: direction A plus layers ("A+")**: [26](../26-colour-and-ambience.md). The
   verified palette, the member-colour rule and AA in all three shades stay. Added: a pale
   band per module (paper, so allowed any hue), decorative colours for illustration only,
   time-of-day and seasonal ambience on the wall, celebration motion with springs and
   confetti, and a sound set. The kid register adopts direction B's outlines and offset
   shadows. [17](../17-design-system.md) named that "the obvious next step".
7. **Five rituals**: [27](../27-family-rituals.md). They are the *Tischfrage*
   (a question at the table during the meal), the *Wochenrückblick* (a look back at the week on
   Sunday), *Familientraditionen* (named recurring rituals on the board), *Vorfreude*
   (countdowns) and the *Wunschessen* (each child's meal wish, once a week). Birthdays
   ([23 R1.5](../23-roadmap-after-alpha.md)) are built with them because countdowns need them.
8. **All of it is built before M1.6** as step 11 of [16](../16-setup-plan.md#step-11--a-lighter-day-m15).
   The two-week trial of M1.6 then judges each part against the criteria its spec
   names, and a part that fails them is switched off by default or removed. It is not tuned
   until it passes.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Only the visual layer and Wusel before M1.6, the rituals in R1 | Recommended in the conversation, because it follows [P7](../23-roadmap-after-alpha.md#the-test-every-item-passes) (build against observed use). The user chose to have the whole package in the Alpha so that the pilot family judges the app as it is meant to feel. The cost is a later Alpha and features built on spec. Decision 8's keep-or-kill criteria are the mitigation |
| Reopen Q39 for a bolder direction (Material 3 Expressive or similar) | M3 Expressive is not in Flutter's SDK (umbrella issue flutter/flutter#168813, open at P3); community ports are unvetted. A new direction would also repeat the contrast and colour-vision search. Its useful parts, spring motion and a few shapes, are taken directly |
| Rive for Wusel | Richer state machines. But the editor is proprietary (the free tier shows a splash), `rive_native` downloads prebuilt native libraries at build time, the web runtime loads WASM from Rive's CDN unless self-hosted (P2), and the 0.13 → 0.14 upgrade broke the API. It is the way back if code-drawn motion proves too stiff |
| Lottie for Wusel | No state machine, so poses become separate files stitched together in code. It also needs After Effects or a paid tool to author |
| Outfits earned with points or badges | The overjustification risk: a currency for cosmetics is a second reward loop aimed at children |
| A pet Wusel that needs care | Guilt by design (Habitica, Tamagotchi); violates [principle 3](../01-vision-and-scope.md#principles) |
| *Lichtblick* board (good news of the week), *Danke / High five*, *Heimliche Helfer* (secret kindness missions) | Offered on 2026-10-24 and not chosen. The first two drift toward chat (P8). Recorded in [27](../27-family-rituals.md#considered-and-not-chosen) so that they are not proposed again without a reason from use |
| A mood check-in for children, kids' drawings on the wall, BeReal-style prompts, jokes of the day | Rejected by the research: monitoring a child's feelings, photo storage (P8), nagging. See [23, not on the roadmap](../23-roadmap-after-alpha.md#not-on-the-roadmap-and-why) |

## Consequences

- [16](../16-setup-plan.md) gains step 11. It runs after step 10 and before M1.6, adding
  roughly five to seven weekends to the Alpha.
- The Wusel lines and every ritual's text cost translation in four languages
  ([NFR-14](../02-requirements.md)). The question deck is the largest single writing job in the
  app so far. It ships in DE and EN only, and the Tischfrage stays hidden on FR and ES devices
  until those decks exist. That is a recorded exception to P9 for one content catalogue
  ([Q53](../14-open-questions.md)), decided 2026-10-24.
- New data: `profile.birthday` (already in [04](../04-data-model.md)), `event.icon_key`,
  `event.countdown`, `event.tradition`, `meal_wish`, `meal_plan_entry.wished_by_profile_id`,
  and `table_question`. Each write path goes through an `api` function with `app.actor()` and
  an audit row. The contract change raises `api_version`.
- New settings in [21](../21-household-settings.md#a-lighter-day): the rituals are
  household settings with curated defaults, and Wusel's presence is per member and per device.
- The brand files are renamed `wusel[-dark].svg`, and `scripts/brand-assets.js` follows.
  `specs/mockups/logo.html` keeps the old name as a historical record.
- The theme test (`test/app/theme_test.dart`) grows to cover the new bands, decorative
  colours and sky stops, so new decoration cannot break AA.

## Amendment 2026-10-24: built

M1.6 was largely done when the build began, so step 11 ran after it rather than before, and
the user asked for everything in one branch. What was built differs from the decision in
these places, each recorded in its spec:

- **`api_version` stays 1.** Every change is additive, as the repository's convention for
  this case says: columns with defaults, new tables, view columns at the end, new functions,
  `api.member_update` with a last parameter that has a default, and `api.event_save` with the
  same signature (the original moved to `app.event_save_core` and is wrapped).
- **Countdowns are computed in the app** from the occurrences it already reads, not in
  `api.board_week`. The board's events and meals carry `tradition`, `icon_key` and `wished_by`
  only when set.
- **Settings are one row per switch** with existing types. The occasions are seven rows
  (`ambience.*`), the Tischfrage windows are two `time_range` rows, and hidden questions are
  rows of `app.table_question`, not a setting. A default that depends on who or where is the
  enum value `auto`.
- **Still mode** (`?still=1` in the demo build) holds every animation and fixes Wusel's words
  for screenshots; the docs' screenshot tool always passes it.
- **Not built yet:** the planner's one-tap suggestion of a tradition's meal, the Ferien ribbon
  text in the sky, and the module illustrations in the bands. (Wusel's `proud` for a badge
  earned and its cheer when the getting-started card is completed followed the same day.)

