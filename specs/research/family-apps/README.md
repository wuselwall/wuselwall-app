# Family apps: what users want, where friction is, and the FR/ES table questions

Research of 2026-10-24, in five parts kept beside this file. It follows
[market-research.md](../../market-research.md) (competitors, 2026-10-11) and was read against
specs 01, 09, 13, 20, 23, 24 and ADR-020. Each part says what it could not reach; the limits
below apply to the whole.

| Part | Question | Method |
|---|---|---|
| [market-wishes.md](market-wishes.md) | What else do users of family apps ask for or complain about? | ~30,400 App Store reviews of 38 apps (US, GB, DE, AT, CH, FR, ES), GitHub issues by reactions, Home Assistant threads |
| [ux-friction-patterns.md](ux-friction-patterns.md) | How do family apps reduce friction, and why are they abandoned? | HCI papers (CHI/CSCW), NN/g, Baymard, RCTs, product practice; graded A/B/C |
| [friction-audit.md](friction-audit.md) | Where is WuselWall's own friction? | Read-only audit of the code and specs for seven journeys, with file references |
| [table-questions-fr.md](table-questions-fr.md) | How should a French Tischfrage deck read? | Parenting sources, public-domain *devinettes* (Rolland 1877/78, Sébillot 1881), register and regional words |
| [table-questions-es.md](table-questions-es.md) | How should a Spanish deck read, and when do Spanish families eat? | Parenting and paediatric sources, traditional *adivinanzas*, peninsular vs neutral Spanish |

## Limits

- **Reddit was not reachable**, so nothing comes from r/Parenting, r/selfhosted and the like.
  Google Play reviews were not scraped. Review counts are *mentions* (praise mixed in), so
  they show what people talk about, not demand.
- Several papers would not load; the UX part marks the findings it took from abstracts only.
- The FR and ES decks were written without a native speaker. Their notes list the questions
  the writer was least sure of; the app ships a 50-question selection that leaves those out.

## What came out of it

**Quick fixes** (built on `fix/friction-quick-wins`): pending approvals on Today and a Tasks
badge (#127); a new event starts on the day being viewed and says whether the wall will show
it; a chore saves with only a title; an invitation opened while already in a family explains
itself; "Invite partner" offers an adult already added; settings that do nothing are hidden;
three guide pages that promised more than the app does.

**Decisions opened as issues** (two or three parts agree on each):

1. #141 The second parent's first minutes: land on what is theirs, keep the invitation through the
   install, no account wall before value.
2. #142 Fast capture: a quick-add on Today, then home-screen widgets for Today and shopping.
3. #143 Notifications as two daily digests, with immediate alerts only for what concerns the reader.
4. #144 Setting up the wall without typing on it.
5. #145 Kids' routines: picture checklists for morning and evening, one completion, no per-step points.
6. #146 Events from a school letter or a forwarded mail, reviewed before saving (extends spec 24).
7. #147 Two homes: a per-child week A/B pattern.

**Declined because they conflict with the principles** (market-wishes.md section on
conflicts): a pocket-money ledger tied to points, a pet that must be fed, leaderboards,
penalties, location sharing, chat, photo proof, screen-time enforcement. The pocket-money
ledger has strong demand and could get its own decision card, kept apart from points.

## Table questions FR and ES

- The drafts of 150 are [table-questions-fr-draft.json](table-questions-fr-draft.json) and
  [table-questions-es-draft.json](table-questions-es-draft.json). The app ships 50 of each in
  `app/assets/table_questions/{fr,es}.json`, a third of every (category, deck) group of the
  DE deck, chosen to leave out every question the notes flag and every riddle whose
  tradition could not be traced (ES keeps only the five riddles with a source opened).
- **Meal windows follow the region.** The defaults 11:30–13:30 and 17:30–19:30 miss both
  meals in Spain (comida about 14:00–15:30, cena about 21:00) and most French dinners (INSEE
  time-use data: dinner between about 18:50 and 21:30, peak at 20:00). The server now holds
  per-country defaults: ES lunch 13:30–15:30 and dinner 20:00–22:00, FR dinner 19:00–21:00.
- Not done: a Latin-American Spanish variant, and Catalan, Basque and Galician decks, which
  would have to be written fresh because the riddles' rhymes do not carry over.
