# 07 — Modules: Meal Plan (A3) & Shopping List (A4)

Two modules in one document because the interesting part is the seam between them.

---

# Meal Plan (A3)

Implements FR-3.1 – FR-3.9.

## Deliberate minimalism

The failure mode of family meal planners is that they become recipe managers. Recipe
management is a large, satisfying problem to build and a small one to have. What this
household needs is an answer to "what are we eating on Thursday" that everyone can see.

So: **free text is a first-class citizen.** A meal plan entry with `free_text = "Pizza"`
is complete and valid. Recipes are an optional enrichment that unlock quantity-accurate
shopping generation. If recipes are mandatory, the plan will not get filled in, and an
empty meal plan is worse than a scribbled note on the fridge.

## Model

```
meal_plan_entry: (date, slot) ──▶ recipe  OR  free text
                 + servings, who cooks, who's eating
```

Slots are breakfast, lunch, dinner, snack. Most households only ever fill dinner; the
others cost nothing to have and stay collapsed in the UI until used.

`cook_profile_id` is the quietly useful field: it turns the meal plan into a fairness
instrument and, later, into an automatic calendar entry ("Papa cooks Thursday").

`attendee_profile_ids` was a "should have" (FR-3.3) until the wall display's week board
made it structural: the meal zone shows who is eating at home, so the field is now `M`
and needs a defaulting rule rather than an empty multi-select nobody fills in.

## Views

- **Week grid** (laptop, adult register): seven columns, editable inline, drag a meal to
  another day. This is where planning actually happens, once a week, on a real keyboard.
  A column keeps at least 176 px, so a dish of one long word ("Fischstäbchen") never
  breaks: seven columns from about 1260 px, four over two rows (Monday to Thursday,
  Friday to Sunday) on a tablet, one day per row on a phone.
- **Meal zone of the week board** (wall display): the bottom band of every day column,
  seven days at once — **one warm meal per day** (Mittag at the weekend, Abend on school
  days, with the slot named in the cell) plus, per member, whether they are eating at home
  (FR-8.4). The household eats one cooked meal a day; showing four slots on the wall would
  be three rows of "Hort" and "Schulbrot". Read-only, and the reason `attendee_profile_ids` and `cook_profile_id` are
  worth filling in: on the wall they answer "wie viele koche ich heute?" without anyone
  asking. See [09](09-clients-and-ux.md#the-week-board).
  **Defaulting rule:** everyone is eating at home unless something says otherwise. A
  presence entry of `travel` or `away` that covers the meal's slot flips that member to
  "not eating" automatically, and the child whose Stundenplan has Hort past 14:00 is
  automatically out for Mittagessen. Both defaults are overridable per meal — the point
  is that the common case needs no input at all. The rule itself, the cutoff and which
  meal is the warm one are household settings ([21](21-household-settings.md#meals-m14)).
- **Recipe detail** (tablet): ingredients scaled to the planned servings, steps in large
  type — the tablet is propped against the toaster while someone cooks.

## Capture: the tile picker

*Added 2026-09-02. Mockup: [`specs/mockups/shopping-quick-add.html`](mockups/shopping-quick-add.html)
— published at https://claude.ai/code/artifact/bad8116b-8bfc-424a-b045-2e8b58f83e3a*

FR-4.1 asks for three seconds. A text field with an autocomplete dropdown does not get
there one-handed in front of an open fridge, because it demands typing before it offers
anything. The picker inverts that, in the shape people already know from choosing an emoji:

- **Recents and frequents first, before any input.** Both come straight out of
  `catalog_item.last_purchased_at` and `purchase_count`; nobody curates a list of favourites.
  A household buys the same thirty things, and those thirty should cost one tap.
- **Typing narrows the tiles** rather than building a dropdown. Matching is deliberately
  forgiving — case, umlauts and aliases all fold together, so `klopapier` finds
  Toilettenpapier, `passata` finds passierte Tomaten. Prefix beats word-start beats
  substring, ties broken by purchase count.
- **`Enter` adds the top hit**, for the times someone does have a keyboard.
- **A "… neu anlegen" tile** closes the loop: an unknown name is added as free text and
  enters the catalogue on purchase, so it is an ordinary tile next time.
- **Quantity without a field.** Tap again for 2 ×, the small − takes one off. Anything more
  precise ("500 g Hackfleisch") is a long-press, or dictation via Shortcuts, which parses
  quantities anyway ([12](12-mcp-and-assistants.md)).
- **A swipe takes an item off** (adults only, [09](09-clients-and-ux.md#gestures)). It
  leaves the list at once; the `count −n` op is queued only once the 5 s **Rückgängig**
  has passed, so an undo never has to rebuild the item, who added it or its meals. The
  long press's dialog has **Entfernen** for the same, without a swipe.
- **The list itself is a drawer**, not a separate screen: what is already on it stays
  visible without leaving capture.
- **Offline is the normal case, not the error case.** Newly captured items show a
  "wartet" state until the outbox drains ([ADR-006](adr/ADR-006-offline-strategy.md)); iOS
  cannot send in the background, so the pending state is shown honestly rather than implied
  away.

### Settled on 2026-09-02

| Question | Decision | Consequence |
|---|---|---|
| Tiles with a picture, or a text list? | **Tiles**, four per row | Every `catalog_item` gets an `icon_key`, which the server picks from its name (`app.catalog_icon_for`, in all four application languages (DE/EN/FR/ES); a name it does not know shows its category's icon). The pictures are a bundled icon set (Fluent Emoji Flat, MIT, as specs/17 decides; `scripts/emoji-pictures.mjs`), never product photos — those would mean an outbound request per tile, which NFR-9 rules out |
| May the children add items? | **Yes**, on the same screen as everyone else | No kid mode on this path. Each row shows a dot in the adder's colour (FR-4.10), which settles "who put Gummibärchen on the list" without a rule |
| One list or several? | **Several** — the starter set is Supermarkt, Drogerie, Baumarkt; households rename, add and remove lists ([21](21-household-settings.md#shopping)) | FR-4.8 rises from `C` to `M` and moves into M1.1. Each list offers only its own categories, so the Baumarkt list never suggests bananas. Supermarkt is `is_default` |
| How do quantities work? | **Long press → free text** | No numeric field on the fast path. Tap counts up (2 ×, 3 ×); a long press opens one text field for "Bio", "500 g", "Dose", "E14 warmweiß". Parsed into quantity and unit only where unambiguous, kept verbatim regardless (FR-4.9) |

### On the wall

The same picker runs on the kitchen display, reached from the footer's shopping count
(FR-8.12), with two deliberate differences: the tiles are bigger, and **there is no search
field** — nobody types on a wall, so what the wall offers is recents, frequents and
categories, and anything else comes from a phone. It writes to the default list only.

Together with ticking a task and correcting who is eating, this is the third and last
mutation the kiosk allows.

The children can use this before they can spell — which is the argument for tiles over a
text field on its own, and the reason each item records who added it.

## Recipes

`recipe` + `recipe_ingredient`. Ingredients hold a `raw_name`, an optional quantity and
unit, and an optional `catalog_item_id` link. That link is what makes shopping generation
accurate; without it, generation still works but falls back to string matching.

Scaling: `servings` on the plan entry versus `servings_default` on the recipe gives a
ratio applied to every quantity. Round sensibly — nobody buys 1.33 onions. Round up to
sane purchase units and note the residue.

**Not in v1:** nutrition data, photos beyond one image, step timers, shopping by
supermarket availability, meal-plan templates, AI meal suggestion. FR-3.8 (suggest from
history, "not cooked in 60 days") is the highest-value follow-up and needs no AI at all —
just a query.

---

# Shopping List (A4)

Implements FR-4.1 – FR-4.8. This is the module the family will touch most often, and the
only one with a hard offline requirement.

## The three-second rule

FR-4.1 says an item must be capturable in under three seconds. Everything below follows
from it.

- A single always-focused input at the top of the list. Type, press enter, it is added.
  No modal, no category picker, no quantity field in the way.
- Autocomplete from `catalog_item`, ranked by purchase frequency and recency, using a
  trigram index. Typing "mil" offers "Milch" as the first suggestion by the third
  keystroke.
- Category and default unit are inferred from the matched catalogue entry. The user is
  never asked; they can correct it afterwards if they care, and they usually will not.
- A "recent items" grid of the twenty most-bought items as tappable chips — for the wall
  display and for the children, tapping beats typing.
- No confirmation, no toast that steals focus. The item appears in the list and the input
  is ready for the next one.

Anything that adds a step here costs more than it looks like it does, because it is paid
several times a day, usually while doing something else.

## Shopping in the store

- Items grouped by category; categories ordered by `store_section_order` for the selected
  store, so the list reads in walking order. Setting this up once per store takes five
  minutes and removes most of the backtracking from a shopping trip.
- Tick targets at least 56 px tall — this is used one-handed, with a trolley, in a coat.
- Ticking moves the item to a collapsed "in the trolley" section with an undo, rather
  than removing it. An accidental tick must be recoverable without thought.
- A "finish shopping" action archives everything ticked: status `bought`, catalogue
  counters incremented, list cleared. Archived items are the training data for
  autocomplete.

### Two modes (2026-10-31, reworked the same day)

The list has two explicit modes on the adult and the children's register; the wall keeps
its single combined view and has no control. The reason is space and the right controls
for each situation: at home the screen is for putting things on the list, in the aisle it
is for ticking them. There is no switch on the list: planning is the tab, the shopping
trip is a page of its own.

- **Plan** ("Planen") is the normal shopping tab inside the home shell (app bar and bottom
  navigation stay). The list chips, the search field and the tile grid (at most 30% of the
  screen height, between 112 and 240 px), and the items by category in walking order as
  plain rows with the item's picture instead of a checkbox. A tap opens the item sheet
  (below), a swipe removes it (adults), "−" lowers a count. Ticked items stay in the
  collapsed trolley, where a tap un-ticks, so nothing is hidden from someone planning
  while another is in the store. The bottom bar has the history and "Einkaufen gehen",
  which sets the mode to Shop and pushes the trip route.
- **Shop** ("Einkaufen") is the route `/shopping/trip` (`ShoppingTripPage`), outside the
  home shell like the other full-screen pages: no app bar and no bottom navigation until
  the mode is left ([09](09-clients-and-ux.md)). A slim top row names the list and its open
  count ("Supermarkt · 5"); then the tick rows of the section above, with the 800 ms
  settle, the trolley and the end-of-trip celebration unchanged, and without "−". The
  bottom bar is `[Hinzufügen] [Planen] [Einkauf beenden]`: "Hinzufügen" opens the same
  picker as Plan in a bottom sheet that stays open for several items (on screens under
  400 px it is an icon button with a tooltip, so three controls fit); "Planen" sets the
  mode back to Plan and pops; "Einkauf beenden" confirms, finishes and then does the same.
  The system back and the swipe back also set the mode to Plan.
- The last mode is **kept on the device** (secure storage, `plan` | `shop`; the demo and the
  tests use a memory store). When the shopping tab builds while the stored mode is Shop and
  the trip page is not already open, it pushes the trip once, so a phone closed in the
  store reopens into the trip. No heuristic on ticked items any more. The wall never
  pushes.

**The item sheet** replaces the edit dialog: a modal bottom sheet opened by a tap on a plain
row (Plan) and by a long press on any row. Its title is the item's name (with the meal icon
and "Für: …" lines for an item from the meal plan); a stepper `[−] n [+]` with 48 px
targets (56 on the children's register) changes the count at once through the outbox
(`count` ops, offline-capable), "−" stops at 1 (taking an item off is "Entfernen", adults
only); the note (`maxLength` 40) is saved on "Fertig" or when the sheet closes; the
category is a horizontally scrolling row of chips ("Ohne Kategorie", then the list's
categories in walking order) and a tap saves at once.

**Quantities** show as a bold "2×" pill (primary container) right after the name in both
row kinds when `count > 1`; the subtitle carries only the note. The pill is excluded from
semantics; the row's semantics value carries "2 ×" and the pending state.

Categories are also set automatically: when the catalogue knows no category for a new item,
the server infers one from its name by a word list (German and English) and flags the item
(`category_auto`, `shopping_apply` and the item view carry it; the catalogue entry carries
the same flag), and a supermarket list is seeded with a `snacks` category between `pantry`
and `frozen`. While the flag is set the item sheet says "Kategorie automatisch aus dem
Namen gewählt"; any category chosen by a person clears it (the outbox projection does the
same locally). An app talking to an older server reads a missing flag as false.

**Pinned tiles.** Anyone with a connection can pin a catalogue tile from its
long-press menu ("Kachel anheften" / "Anheften aufheben", `shopping_catalog_pin`,
online-only like rename and forget). Pinned tiles come first in the picker, most bought
first and then by name, ahead of the recent/frequent ranking; with a query a pinned match
ranks above others of the same score. A pinned tile shows a small pin.

## Offline — the one place it is non-negotiable

Supermarket connectivity is unreliable, and a shopping list that fails in a shop is
worthless. This module, and only this module, gets full offline support
([ADR-006](adr/ADR-006-offline-strategy.md)).

**Mechanism** *(built 2026-10-12)*:

1. The app keeps the server's last state mirrored in a local SQLite database (drift):
   the open items, lists, categories and catalogue, as the JSON the `api` views return.
2. Every item change is appended to an **outbox** table first. An op carries a
   client-generated UUIDv7 `op_id` and the acting profile at the moment it was made (a
   shared tablet queues several people's changes). A new item also gets its id on the
   device, so ticking an item added offline needs no round trip.
3. The UI renders the mirror with the outbox replayed on top (`projectShopping`, one pure
   function with the server's rules), so it is identical online and offline. Items touched
   by a pending op are marked "wartet".
4. The outbox drains in order to `api.shopping_apply(p_actor, p_ops)` on every change,
   when the network returns, on app resume and on a `shopping` invalidation; failed sends
   retry after 2, 5, 15, 30 and 60 seconds. The server records each `op_id` once
   (`app.shopping_op`), so a resent batch — the response was lost, the app was killed
   mid-request — comes back as `duplicate` and changes nothing.
5. The function returns a status per op and the household's open items; those replace the
   mirror's, and every reported op leaves the outbox.

| Op | Effect | Idempotent because |
|---|---|---|
| `add` | New item under the client's id, or +1 on an open item of the same folded name (then the client id becomes an alias of it) | `op_id`; an existing id is skipped |
| `check` | Sets ticked or unticked — absolute, not a toggle | It is absolute |
| `count` | ±n; at zero the item is removed | `op_id` |
| `spec`, `category` | The free-text note, the category | They are absolute |
| `finish` | Ends the trip under a client-generated trip id | `op_id`; an existing trip is skipped |

Lists, the default list and history stay online-only: they are rare, and none of them is
done in the aisle.

**Outcomes per op:** `applied`; `duplicate` (seen before); `skipped`, when there is
nothing left to act on — the item was removed or bought meanwhile, the tombstone wins;
`rejected`, with its domain code (a category deleted meanwhile, a profile no longer in the
household). A rejected op affects only itself and is reported once as a message; the rest of
the batch goes through, so one bad op can never block the outbox behind it.

**Conflict handling**, in ascending order of interest:

- *Two people add the same item.* Whichever add reaches the server second merges into the
  first: one entry, "2 ×", and the second device's id keeps working as an alias.
- *Two people tick the same item.* Idempotent. Last writer records `checked_by`; nobody
  notices or cares.
- *One person edits a quantity while another ticks it.* Different fields, no conflict.
- *Two people change the same field.* The op that reaches the server last wins. The order
  is the server's arrival order, not device clocks, which drift; for a shopping list that is
  the honest choice, and it is what everyone sees on the next refresh.
- *One person deletes while another edits.* Tombstone wins. The editor sees it vanish on
  sync. Acceptable for a shopping list; it would not be for a bank ledger.

**The web build** (the laptop) keeps the mirror and outbox in memory: the laptop is online,
a reload refetches, and an unsent change survives a dropped request but not a closed tab.
The phones and tablets keep both in SQLite across restarts.

Important limitation to design around: **iOS gives no reliable background execution.**
The outbox may not drain while the app is closed; it drains when the app is next resumed
with a connection (Android may drain it earlier via a background job, but nothing relies
on that). So the UI shows unsynced state honestly — a banner "3 Änderungen warten aufs Senden"
and a mark on each waiting item — rather than pretending everything is saved.

Native storage is not evicted the way Safari's was, but the local database is still a
cache, never the store of record. The outbox is the only thing in it that is not
reconstructible from the server, so keep it small and drain it eagerly.

## Live updates

While online, a trigger broadcasts `shopping:changed` over Supabase Realtime and every
connected device refetches within a couple of seconds (FR-4.6). Two people shopping in different aisles is a real
use case and one of the moments the app visibly earns its keep.

---

# The seam: meal plan → shopping list

The feature that makes both modules worth more than the sum of their parts.

**Flow:** in the week grid, select a date range → "Generate shopping list" → a preview
appears → adjust → commit.

**What generation does:**

1. Collect ingredients from every recipe-linked entry in the range, scaled by servings.
2. Aggregate by `catalog_item_id` where linked, by normalised name otherwise, converting
   within a dimension (500 g + 0.5 kg = 1 kg; ml and l; pieces stay pieces). Never
   convert across dimensions.
3. Present a **preview with checkboxes**, pre-unchecking staples ("salt", "olive oil")
   that the household almost certainly has. Which items are staples is learned from a
   flag on `catalog_item`.
4. On commit, create `shopping_item` rows with `source_meal_plan_entry_id` set, and stamp
   `shopping_generated_at` on the entries so a second run does not duplicate them.
5. In the list, generated items show a small icon; tapping it reveals "for Thursday's
   lasagne" (FR-3.7). This is what makes it safe to delete something from the list —
   you can see what you are about to leave out.

**The preview step is mandatory, not optional.** Fully automatic generation dumps thirty
items including four kinds of flour into the list, the human has to weed it, and after
two attempts the feature is never used again. The preview is the difference between a
feature that works and one that is technically present.
