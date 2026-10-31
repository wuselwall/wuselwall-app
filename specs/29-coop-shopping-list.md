# 29 — Handing the list to the shop: the Coop Einkaufsliste connector

*Added 2026-10-31.* Builds on [07](07-module-meals-shopping.md) (the shopping list, its two
modes) and [11](11-security-and-privacy.md). Research done 2026-10-31 against coop.ch with
a guardian's own account; nothing here is documented or promised by Coop.

> **Built 2026-10-31 (first version), not yet run on a device against coop.ch.** The push
> logic is tested against a fake coop.ch; the WebView sheet, the sign-in and the real
> answers need the manual check under "Testing" before the first release that ships it.

## Why

In Switzerland, Coop's self-scanning handhelds (passabene) and the passabene app show the
customer's **Coop Einkaufsliste**: the list is written beforehand in the Coop app or on
coop.ch under the Supercard ID, appears on the scanner in the store, and items are ticked
there, on the scanner's screen or by scanning them. For a family that shops at Coop with
the scanner this is the one place where a second list wins over WuselWall's *Einkaufen*
page: the scanner is already in the hand, the phone stays in the pocket.

The wish is one tap in WuselWall that puts the open items on that Coop list.

## What was found

There is **no public API**, no developer portal and no partner programme for the Coop
list. What exists:

- **One list backend, two front ends.** The *Coop Einkaufsliste* (Coop app, coop.ch) and
  *WeNeed* (Coop's own stand-alone list app) share the same lists: one sharing code opens
  a list in both. The Coop list is the one passabene reads.
- **coop.ch's own list page** creates lists, adds free-text items and removes them with
  ordinary requests from the signed-in page. Checked 2026-10-31 with a guardian's own
  account: the same requests work from the page in a WebView. Without a session, the page
  signs in again through the Supercard ID by itself while that session lives.

The details (the calls, their answers, the session) are kept in the maintainers' private
notes; the code that relies on them is all in one file, `coop_protocol.dart`.

## Decisions

1. **The connector lives on the phone, never on the server.** The Coop session is the
   guardian's own, obtained by signing in to coop.ch inside the app, and stays on that
   device. The WuselWall server never sees a Supercard password, a cookie or a token, and
   nothing in the server release speaks to Coop. This is the same stance as
   [11](11-security-and-privacy.md): the family's server holds the family's data and no
   third-party credentials.
2. **One way, WuselWall stays the source of truth.** The push copies the open items *to*
   Coop. Ticks made on the scanner are not read back; the family finishes the trip in
   WuselWall as today (*Einkauf beenden*), or lets the open items roll over. Reading the
   Coop list back would need parsing rendered HTML and is not worth its fragility.
3. **A list of its own on the Coop side.** The push targets one Coop list named
   "WuselWall" (created on first use, its id remembered on the device). The family's other
   Coop lists are never touched. Each push makes that list equal to WuselWall's open items:
   entries the connector created earlier and that are no longer open are removed, new items
   are added. Nothing the family typed into that list by hand is removed, because only
   entries with a remembered id are.
4. **Off by default, adults only, marked as unofficial.** The settings row sits under
   *Einstellungen → Geräte → Dieses Gerät* on a personal phone (the sign-in lives in this
   phone's WebView); the button in the *Planen* bottom bar appears only once someone has
   signed in to Coop on that phone. Its description says in plain words that it uses the
   coop.ch website the way a browser does, that Coop does not support it, and that it may
   stop working after a change on coop.ch. The kid register and the wall display never show
   it.
5. **Generic items, not catalogue products.** Every item goes as free text (`productName`),
   with the generic catalogue icon when the first suggestion for the name matches it
   exactly; matching WuselWall's names to Coop's real products (barcodes, prices) is out of
   scope. The count travels in the name when above one ("2× Milch"); the note is appended
   in brackets.
6. **Fails soft, never blocks.** A push that cannot reach Coop, is not signed in, or gets an
   answer the connector does not understand ends in one line ("Coop-Liste nicht
   erreichbar") and changes nothing in WuselWall. The connector carries no retry queue: the
   next tap pushes again.
7. **Shared parts, one retailer.** The item labels, the plan and the link on the device
   (`retailer_handoff.dart`) know nothing about Coop; the Coop parts sit behind a small
   transport (`CoopTransport`) and one push (`CoopPush`). A second retailer (Migros has a
   list in its app too) would add its own push and reuse the rest. None is planned.
8. **Ask Coop in parallel.** Before the first release of the connector, Coop is asked
   through the WeNeed contact form whether a sanctioned way exists. A yes replaces the
   mechanism below; a no, or silence, does not stop the connector, but its wording stays
   "unofficial".

## The guardian's path

1. *Einstellungen → Geräte → Dieses Gerät → Coop-Einkaufsliste* (only on a personal phone,
   in the iOS and Android apps) explains the feature, what leaves the device and that it is
   not Coop's, and has one button, **Bei Coop anmelden**. It opens coop.ch's own sign-in page in a
   WebView inside the app (Supercard ID, with whatever second factor Coop asks for).
   The page is Coop's, unchanged; WuselWall reads nothing typed into it.
2. When the WebView lands on a coop.ch page that is signed in, the sheet closes and the
   settings page shows **Auf diesem Gerät verbunden** with the list name ("WuselWall"),
   how many items the last push left there, and **Coop trennen**.
3. In *Planen*, the bottom bar gains an icon button **An Coop senden** between the history
   and *Einkaufen gehen*. The tap opens the sheet with a progress panel over the page and
   ends in "14 Artikel auf der Coop-Liste «WuselWall»". The Coop app or scanner shows them
   under that list. A push with no open items empties that list.
4. Signed out or expired: the tap opens the sign-in sheet first, then pushes.

No automatic push: the family decides when the list is complete, and a push on every
change would hammer coop.ch and multiply the chance of being blocked.

## Mechanism

- **Requests run inside the WebView**, not from Dart's HTTP client. The connector loads the
  list page of the signed-in session and runs the calls from the page with the browser's
  own `fetch` and `credentials: 'include'`, through the WebView's JavaScript bridge. DataDome
  then sees a real browser with the cookies it issued; the connector never copies cookies
  out. (The replay from curl happened to work; the WebView path is the one that stays
  working.)
- **Dependency**: `webview_flutter` (iOS, Android; the only two platforms with the feature).
  The web build and the wall display have no WebView and show no connector.
- **The sheet** loads the list page. A page on another host (Supercard's sign-in, a
  captcha) is shown to the person; a coop.ch page is asked through the bridge whether it
  is signed in; not signed in, the sheet opens Coop's sign-in page once and then waits for the
  person. Signed in, a progress panel covers the page and the push runs. Only https
  navigations are allowed. The site's language follows the app (`de`, `fr`, `en`; Spanish
  reads it in English, Italian in Italian).
- **State on the device** (`flutter_secure_storage`): the Coop list id, the language the
  session was made in, and the map *WuselWall item id → Coop entry id* for the entries the
  connector created. Signing out deletes all three.
- **A push**, in order: (1) read from the page whether it is signed in;
  (2) make the stored list the active one and check it still exists: if it is not the
  stored one, that list was deleted on the Coop side and a new "WuselWall" list is created
  and set active; (3) remove remembered entries whose WuselWall item is gone, ticked or
  changed (a new count, name or note gives a new label); (4) for every open item without an
  entry, look up the generic catalogue for its picture and add it, taking the entry id
  from the answer; (5) keep the map. Each step updates the link on the device, so a push
  that stops half-way remembers what went across. Thirty new items are sixty requests,
  150 ms apart: the pace of a person clicking.
- **Sign-in lost half-way** (a reply that ended on another host, 401/403, or a fetch the
  page could not complete): the sheet shows the sign-in again and pushes once signed in.
- **Answers are checked, not trusted**: `success: true` and an entry id in the fragment.
  Anything else counts as failure for that item; the push reports "12 von 14" and keeps
  the map for the ones that worked.

## Privacy

The names and notes of the open items leave the family's server for Coop, under the
guardian's Coop account, each time the guardian taps the button. The settings text says
so. Nothing else is sent: no member names, no meal plan, no household id. The WuselWall
server logs nothing about it because it is not involved. [11](11-security-and-privacy.md)
gets a line under third parties when this is built.

## Not in scope, and why

- **Reading ticks back from the scanner**: HTML parsing of a page that changes with every
  coop.ch release; the trip is finished in WuselWall instead.
- **Real Coop products** (barcodes, prices, promotions): a different product, and the
  generic entries already appear on the scanner.
- **Server-side push, scheduled push**: would need Coop credentials on the server (decision
  1) and would run against DataDome without a browser.
- **WeNeed through Firebase**: a second account, unknown rules, no advantage over the
  coop.ch list that the scanner reads directly.
- **Other retailers**: the port exists for them, nothing more.

## Risks

- **Coop changes coop.ch.** The connector breaks silently or loudly. Mitigation: decision 6
  (fails soft), the "unofficial" wording, a manual check on the release checklist for each
  app release ("push three items, see them in the Coop app"). Every coop.ch detail is in
  one file, `coop_protocol.dart`.
- **DataDome blocks the WebView.** It is a real browser; the risk is low, and a block shows
  as a captcha page in the sign-in sheet, which the guardian can solve.
- **Coop has not approved it.** Decision 8 asks; if Coop objects, the connector is removed
  from the release. The open questions around it are kept in the maintainers' private
  notes.

## Open questions

- How long the WebView keeps the Supercard ID session (the silent sign-in covers the
  storefront session; iOS clears WebView cookies less predictably than Android).
- Whether the signed-in markers are absent on every page without a session (checked on the
  list page only).
- Whether DataDome treats Android's WebView user agent (it carries `wv`) like Chrome.
- Whether generic entries added with `productId` show the icon on the scanner as they do on
  the website.
- The quantity field of the "Refine" modal, if a count in the name proves clumsy.

## Code

| Part | File (`app/lib/features/shopping/`) |
|---|---|
| Labels, plan, the link on the device | `domain/retailer_handoff.dart` |
| Everything coop.ch-specific: paths, answers, the page bridge | `data/coop_protocol.dart` |
| The link in secure storage | `data/coop_handoff_store.dart` |
| The push | `application/coop_push.dart` |
| Supported, connected, available | `application/coop_handoff_providers.dart` |
| The WebView sheet and its transport | `ui/coop_sheet.dart` |
| The settings page | `ui/coop_settings_page.dart` |

## Testing

No automated test talks to coop.ch. `test/features/coop_handoff_test.dart` runs the push
against a fake coop.ch that answers like the real one (first push, nothing new, bought and
changed items, entries typed by hand, a deleted list, an expired session, refused items);
the widget tests replace the sheet with a fake launcher. The real connector is checked by
hand with a guardian's own account before each release that touches it (release
checklist O4): sign in, push three items, see them in the Coop app, tick one in WuselWall,
push again, see it gone.
