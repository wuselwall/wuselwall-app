# 20 — Onboarding

*Added 2026-10-11.* Implements FR-5.6, FR-5.8 and FR-5.10 – FR-5.18, measured by NFR-17.
Decision context: [ADR-014](adr/ADR-014-self-service-onboarding.md). The identity model
underneath (device sessions, tap-to-switch, the guardian PIN) is unchanged and lives in
[08](08-users-auth-permissions.md); this document is about how people and devices get
*into* it.

Onboarding is where a family app is won or lost. A household decides in the first ten
minutes whether this is "the new thing we use" or "the thing Papa installed", and the
second adult decides it in the first sixty seconds. Everything below is ordered by that.

## Six rules

1. **One door for adults.** Signing up and signing in are the same screen and the same
   flow. Nobody has to know whether they already have an account.
2. **Ask only what cannot be inferred or deferred.**
   *Inferred:* timezone and language (from the device), the person's name (from Apple or
   Google), their colour (the next free one in the palette), the device's name ("Daniels
   iPhone"). *Deferred:* the guardian PIN (until the first shared device exists), avatars,
   birthdays, presence baselines, a second factor, a passkey, push permission.
3. **Nobody types on a shared device.** Not a password, not a code, not a name. The wall
   display and the children's iPads are set up from a parent's phone.
4. **Every path ends inside the household**, never on an empty screen: a new household
   lands on Today with a few examples and the getting-started card.
5. **No dead ends.** Lost the invitation link? Use the code. No camera? Type the code on
   the phone. Forgot the password? The email code is the reset. A code expired while
   you were looking at it? It renews itself.
6. **No tours, carousels or coach marks.** One getting-started card and empty states
   that each name one action. A tour explains an app; a good first screen does not need
   one.

## Who arrives, on what

| | Journey | Who | Device | Target (NFR-17) |
|---|---|---|---|---|
| J1 | **Start a family** | The first adult | Their own phone or laptop | ≤ 3 screens after sign-in, ≤ 90 s with Apple/Google, no typing beyond names |
| J2 | **Join a family** | An invited adult (the other parent, a grandparent, an au pair) | Their own phone | ≤ 2 screens after sign-in, ≤ 60 s from tapping the link |
| J3 | **Connect a shared device** | A guardian, holding their phone | Wall display, children's iPad, a family tablet | Zero typing on the shared device, ≤ 30 s of the guardian's time |
| J4 | **Come back** | Any adult with an account | A new or reset phone, the laptop | Sign-in, then straight to Today |
| J5 | **A child's own phone** | A guardian, for a child | The child's phone | As J3; the phone is bound to that child |
| J6 | **Leave** | Any adult | Their phone | Account or household deleted from inside the app |

Children never have accounts, email addresses or passwords. They exist as profiles that
guardians create, and they act through shared devices (or their own paired phone).

## The front door

What every device shows before it belongs to a household:

```
┌──────────────────────────────────────┐
│              (mascot)                │
│             WuselWall                │
│   Der Familienplan für die Küchenwand│
│                                      │
│  ┌────────────────────────────────┐  │
│  │ A Mit Apple fortfahren         │  │   ← first on iOS and iPadOS
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ G Mit Google fortfahren        │  │   ← first on Android and the web
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ ✉ Mit E-Mail fortfahren        │  │
│  └────────────────────────────────┘  │
│                                      │
│  ───────────────── oder ──────────── │
│  Familien-Tablet oder Wanddisplay    │
│  verbinden →                         │
│                                      │
│  Ich habe einen Einladungscode       │
│  Datenschutz · Server ändern         │
└──────────────────────────────────────┘
```

- The three sign-in buttons serve sign-up and sign-in alike.
- The Apple and Google buttons follow those companies' branding rules (shape, logo,
  black/white for Apple). Those are the only colours in the app not taken from the
  design system. They live in `palette.dart` as brand tokens like every other colour.
- **"Familien-Tablet oder Wanddisplay verbinden"** is the shared-device path (J3). It is
  deliberately secondary: the phone in someone's hand is almost always their own.
- **"Ich habe einen Einladungscode"** takes a typed or scanned invitation code (J2 when
  the link was lost or the app was installed afterwards), keeps it, and returns here.
- Offline: the buttons are disabled under a "Keine Verbindung" banner, so nothing fails
  later with an error.
- **"Server ändern"** replaces ADR-015's "Eigener Server" (2026-10-13, [ADR-018](adr/ADR-018-self-hosted-only.md)):
  the server is chosen before the front door ([below](#choosing-the-server)), whose header
  shows its host; this quiet link corrects a wrong choice.
- **Until the rest of step 9 is built** ([16](16-setup-plan.md#step-9--onboarding-m10)),
  the M0.1 paths stand where their replacements will, so the layout does not change twice:
  "Mit E-Mail fortfahren" opens email + password sign-in until E1 replaces it; below
  "oder", "Dieses Gerät mit Code einrichten" (the guardian-generated code) stands where
  "verbinden" (9.4) will; and "Neuen Haushalt einrichten" (the founder wizard with its
  setup token) comes last, until H1 after sign-in (9.2) takes its place. There is no
  separate "Als Erziehungsberechtigter anmelden": every adult sign-in is in the top group.

### With Apple

- **iOS/iPadOS:** native sheet (`sign_in_with_apple`), then
  `signInWithIdToken(provider: apple, idToken, nonce)`. **Android and web:** Supabase's
  OAuth redirect, returning through `ch.goomba.wuselwall://login-callback/` (the web
  build returns to its own origin).
- Scopes `name` and `email`. Apple sends the name **only on the first authorisation**,
  so the app writes it into the user's metadata immediately. It prefills J1 and J2 from
  there.
- "Hide My Email" relay addresses work like any other address. They only defeat the
  automatic invitation match (J2), so the code path covers them.
- Cancelling the sheet returns to the front door without a message. Cancelling is a
  choice, not an error.

### With Google

- **Android and iOS:** native (`google_sign_in`), then
  `signInWithIdToken(provider: google, idToken)`. **Web:** Supabase's OAuth redirect.
- Scopes `openid email profile` only. WuselWall never asks Google for calendar or
  contacts access ([ADR-001](adr/ADR-001-calendar-backbone.md)).

### With email

```
 E1  E-Mail-Adresse  [______________]           E2  Code aus der E-Mail
     [ Weiter ]                                     [_][_][_][_][_][_]
     Ich habe ein Passwort ›                        Kein Code? Erneut senden (in 60 s)
                                                    Andere E-Mail-Adresse
```

- **E1 → E2 is the default and covers sign-up, sign-in and the forgotten password.**
  `signInWithOtp(email, shouldCreateUser: true, data: {locale})` sends a **6-digit
  code**, valid 10 minutes. E2 accepts paste and the platform's one-time-code autofill,
  and submits itself on the sixth digit.
- **A code, not a magic link.** Links open in whatever browser the mail app chooses,
  often on a different device from the one being set up, and they do not work on a
  laptop where the mail is read on the phone. A code works everywhere.
- **"Ich habe ein Passwort"** reveals a password field on E1 for accounts that have one.
  A wrong combination says "E-Mail oder Passwort stimmt nicht", never which of the two,
  and offers "Stattdessen Code per E-Mail". That is the whole password-reset flow:
  sign in with a code, then set a new password in Settings.
- **New accounts choose how to sign in next time (E3)**, once, directly after their first
  code:

  ```
  E3  Wie möchtest du dich künftig anmelden?
      (•) Mit Code per E-Mail — nichts zu merken
      ( ) Mit Passwort          [______________]  (min. 10 Zeichen, Stärke-Anzeige)
      ( ) Mit Face ID / Fingerabdruck (Passkey)   ← only once passkeys are verified
      [ Weiter ]
  ```

  This is how "sign up with a password" works: the address is verified by the code
  *before* a password exists. That means no unconfirmed accounts, no confirmation-link
  round trip, and no way to probe which addresses are registered, because E1 behaves
  the same for every address.
- No code after 60 s: E2 shows "Schau im Spam-Ordner nach", the resend button and
  "Andere Methode wählen".

### Choosing the server

*Rewritten 2026-10-13 ([ADR-018](adr/ADR-018-self-hosted-only.md); was "On a self-hosted
server" under ADR-015).* There is no WuselWall Cloud, and the store app has **no default
server**. On first start, before the front door, it asks for one, unless it was opened from
an invitation or pairing link, which carries the server:

```
 S0  Mit welchem Server verbindest du WuselWall?
     [ QR-Code des Servers scannen ]
     Adresse  [familie.example.org      ]  [ Weiter ]
     Ich habe eine Einladung (Link oder Code)
     Ohne Server ausprobieren ›
```

- **Invited people never see S0.** Invitation and pairing links carry the server in the
  fragment, `https://wuselwall.app/i/#‹token›@‹host›` (the same for `/p/`). The links site
  therefore never sees the token or the address (ADR-018, decision 8). Only someone who
  types an invitation code instead of tapping the link types the server too, and the
  inviter's share message and screen name it next to the code.
- **The founder** scans the QR code that the server's install script printed, or types the
  address. The app fetches `https://‹host›/.well-known/wuselwall.json`. If the file is
  missing, if the server is outside the app's `api_version` window, or if the server needs a
  newer app (`min_app_version`), the message says exactly which. The app then remembers the
  server, and the front door shows its host under the logo until someone is signed in.
- **"Ohne Server ausprobieren"** opens the in-memory demo with the reference household.
  Nothing leaves the device. App Review uses it too, because no server of ours takes
  strangers.
- **Sign-in methods** are what the server's discovery document lists:
  - always email and password;
  - an email code if the operator configured SMTP (servers without it:
    [Q48](14-open-questions.md));
  - Apple and Google through the web redirect, if the operator registered their own
    clients with Apple and Google.

  Native Apple and Google sign-in and passkeys appear only on the first-party servers
  compiled into the app (`WW_FIRST_PARTY_HOSTS`: `api.wuselwall.app`, the family's homeserver
  stack). Otherwise a hostile server could replay tokens addressed to our app to the
  family's server (ADR-018, decision 6). The front door simply shows fewer buttons. It never
  shows a button that will fail.

### Several ways into one account

The same verified email from Google and from an email code is **one account**: Supabase
Auth links the identities automatically. In **Einstellungen → Konto → Anmeldung** an
adult sees their methods (Apple, Google, email code, password, passkeys), adds another
(manual identity linking, which also covers an Apple relay address), sets or changes a
password, and removes any method but the last.

A personal device is bound to its Auth session ([08](08-users-auth-permissions.md)), and
Supabase answers a link with a *new* session. The app therefore links through the native
sheet only, keeps its own session, signs the new one out at once and refreshes. On the web,
and for Apple on Android, Settings says to link from the phone app instead.

## J1 — Start a family

```
 Front door ─► [E1 ─► E2 ─► E3] ─┬─► H1 Neue Familie ─► H2 Wer gehört dazu? ─► Today
                                 │
                                 └─► H0 Einladung wartet ─► J2   (instead of H1, only if
                                                                 an invitation matches
                                                                 this email)
```

**H0 — a waiting invitation.** If an open invitation names this account's verified email,
H0 replaces H1: "Sabine hat dich zu *Familie Huser* eingeladen" with **Beitreten** (J2)
and **Eigene Familie anlegen**. This prevents the classic failure where the second parent
creates a second, empty household.

**H1 — "Neue Familie"**, one screen:

| Field | Prefill | Notes |
|---|---|---|
| Familienname | "Familie ‹family name›" from Apple/Google, else empty | Required. With Apple or Google it is usually prefilled, and the screen needs only a tap |
| Dein Name | Given name from Apple/Google | Editable |
| Deine Farbe | The first palette colour | A row of swatches; the choice is visible at once in the app bar |
| — | "Zeitzone Europa/Berlin · Sprache Deutsch — von deinem Gerät · Ändern" | One quiet line; changed in Settings later |
| Gründungscode | — | **Only while household creation is in `code` mode** (see [below](#household-creation-open-or-by-code)) |

At the bottom: "Ich wurde eingeladen" for anyone who arrived here by mistake.

**H2 — "Wer gehört noch zu euch?"**

```
  ● Daniel (du)                       Erwachsen
  ● [Lotta_______]          [ Kind | Erwachsen ]
  ● [Hanna_______]          [ Kind | Erwachsen ]
  + Person hinzufügen

  [✓] Mit Beispielen starten — 5 Aufgaben, 3 Belohnungen
  [ Fertig ]                          Überspringen
```

- A name and *Kind/Erwachsen* per row. *Kind* is `kind = child`, `role = member`;
  *Erwachsen* is `kind = adult`, `role = guardian`, which the invitation can still
  change (an au pair joins as an adult `member`).
  Each person gets the next free palette colour, shown as the dot, changeable later.
  Avatars, birthdays and baselines come later, where they are used.
- **Examples are on by default**, because a task board with nothing on it teaches
  nothing. They are ordinary rows the family edits or deletes. The default shopping list
  "Supermarkt" and its categories are always created: they are structure, not examples.
- Adults added here are *not* invited yet. Inviting is one tap from the getting-started
  card, once the founder has seen the app.

**Then:** this phone becomes the founder's **personal device**, silently, named from the
profile and the model ("Daniels iPhone", en "Daniel's iPhone"; renamed in Settings). The
"name this device" page of M0.1 leaves the flow. The app opens on **Today** with the
getting-started card.

### Household creation: open, or by code

One instance setting, `household_creation`:

- **`open`**: any signed-in adult without a household can create one. Self-service.
- **`code`**: creating a household also needs a single-use **Gründungscode** (founder
  code) issued by the operator: `scripts/remote-setup-token.sh --founder` adds one code
  while households exist (the first one, the old setup token, comes from the script
  without the flag). Joining by invitation and pairing devices work as in
  `open`.

The instance starts in **`code`** and switches to `open` only when the opening gate in
[13](13-roadmap.md#opening-to-other-households) is passed. Until then a stranger who
signs up gets an account that can do nothing but wait for an invitation. That costs one
row, and nothing in it is reachable through RLS.

## J2 — Join a family

**Inviting (a guardian, on their phone).** From the getting-started card, or
Einstellungen → Mitglieder → a person → **Einladen** (or **Erwachsene Person einladen**,
which creates the profile on the way):

| Choice | Default |
|---|---|
| Role | *Erziehungsberechtigt* (guardian); *Mitglied* for an au pair or a grandparent who should tick tasks but not approve rewards |
| Their email address | Optional. If given, the invitation is matched to it automatically (H0), and no link is needed |

The result is one invitation with three equivalent forms:

- a **link** `https://wuselwall.app/i/‹token›` (128-bit token; `?s=‹host›` added for a
  self-hosted household), handed to the share sheet with
  a ready message in the inviter's language ("Komm zu Familie Huser in WuselWall: ‹link›
  — oder gib in der App den Code K7QM‑3XRP ein.");
- an **8-character code** (`K7QM-3XRP`, the enrolment alphabet without look-alikes);
- a **QR code** on screen, for when the person is standing in the same kitchen.

Valid **7 days**, single use, revocable. A device code lives 10 minutes because it is used
on the spot; an invitation travels through a messenger and is opened tomorrow evening.
Open invitations show under Mitglieder as "Eingeladen · bis 18.10." with **Erneut teilen**
and **Zurückziehen**.

**Accepting (the invitee).**

1. **App installed:** the link is a universal link / Android App Link and opens the app
   at the front door with a banner: "Daniel hat dich zu *Familie Huser* eingeladen". The
   banner text comes from `api.invitation_preview`, which shows the household's name and
   the inviter's first name, and nothing else.
2. **App not installed:** the link opens a small bilingual landing page with the store
   buttons and the code in large type. After installing, "Ich habe einen
   Einladungscode" on the front door. No third-party deferred-deep-link service is used
   (NFR-9). The code or the email match does that job.
3. **The invitation names their email:** they just sign in; H0 appears on its own.

After sign-in, one confirmation screen — **"Du bist Sabine in Familie Huser"** — with the
name and colour the inviter chose, both editable, and **Beitreten**. The phone becomes
their personal device; they land on Today. Every guardian gets a notice ("Sabine ist
beigetreten"), and the audit log records who invited whom. A guardian invitation is a
bearer credential to guardian rights, and that visibility is its counterweight.

An account that already belongs to a household cannot accept a second one (one household
per account, [Q43](14-open-questions.md)). It sees "Du bist schon in *Familie X*" and
the way to leave it.

## J3 — Connect a shared device

*Replaces the M0.1 enrolment flow (guardian generates a code, the code is typed on the new
device). The pairing runs the other way round: the new device shows a code and the
guardian's phone approves it.*

```
   NEW DEVICE (wall tablet)                     GUARDIAN'S PHONE
   ────────────────────────                     ─────────────────
   Front door → "verbinden"
   P1  ┌─────────────┐
       │  ▄▄ ▄ ▄▄▄   │   K7QM-3XRP                Getting-started card or
       │  QR code    │   "Öffne WuselWall auf     Einstellungen → Geräte → Gerät verbinden
       └─────────────┘    deinem Handy und        → scan (or type K7QM-3XRP)
       polls every 2 s    scanne diesen Code"     (or the phone's own camera: the QR is
                                                   the link https://wuselwall.app/p/K7QM3XRP)
                                                  G1  Was ist das für ein Gerät?
                                                      ▣ Wanddisplay
                                                      ▣ Kinder-Tablet
                                                      ▣ Tablet für alle
                                                      ▣ Handy eines Kindes → which child
                                                      Name: [Wanddisplay Küche]
                                                  G2  (first time only) Eltern-PIN festlegen
                                                  [ Verbinden ]
   "Verbunden mit Familie Huser ✓"   ◄──────────
   → kiosk tips / "Wer bist du?" / child's day
```

| G1 choice | `class` | `ui_register` | Bound profile |
|---|---|---|---|
| Wanddisplay | `kiosk` | `kiosk` | — |
| Kinder-Tablet | `shared` | `kid` | — |
| Tablet für alle | `shared` | `adult` | — |
| Handy eines Kindes (J5) | `personal` | `kid` | the chosen child |

- **The display code grants nothing on its own.** Only an approval by a guardian, from a
  personal device, binds the request to a household. Only the device that holds the
  request's secret can collect the credentials. An observed code is useless, unlike the
  M0.1 code, which anyone who read it within ten minutes could redeem. The approval
  screen repeats the code and says "Nur bestätigen, wenn du dieses Gerät vor dir siehst."
- **The code renews itself** while P1 is open (10-minute lifetime, a fresh code shortly
  before expiry), so a tablet left on P1 never ends up on an error.
- **G2 — the PIN, deferred until it means something.** The guardian PIN exists to unlock
  guardian actions on shared devices. A household without one needs no PIN, so J1 does
  not ask for it. The first time a guardian connects a shared or kiosk device, G2 asks
  them to set it (twice, on the numeric pad).
- **What the new device shows next:**
  - *Wanddisplay:* a one-time **kiosk checklist** on the tablet itself (pin the app or
    set it as the home app, keep the screen on, power at the wall), each item with the
    steps for that platform. Then the week board.
  - *Kinder-Tablet:* the mascot explains the avatar row once ("Tipp auf dein Bild, dann
    weiß WuselWall, wer du bist"), then the kid home.
  - *Handy eines Kindes:* that child's day.
- **The old way stays for one release** (`api.enrol_device` and its code entry), so an
  app that has not updated can still enrol. Then it goes (migrations stay compatible
  with the previous release, [16](16-setup-plan.md)).

## J4 — Come back

- **New or reset phone:** sign in with any linked method. The account already has a
  household, so a personal device is created silently and Today opens. The account's
  other devices get a notice ("Neu angemeldet: Daniels iPhone"), and Settings → Geräte
  lists the old phone for revocation.
- **Forgot the password:** sign in with an email code; set a new one in Settings.
- **Second factor (TOTP), if switched on:** the code page follows sign-in as today.
  **Lost the authenticator?** Another guardian removes the factor from their own phone
  (Einstellungen → Mitglieder → person → *Zwei-Faktor zurücksetzen*, a guardian action,
  audited). A household with a single guardian is told so when enabling TOTP, and is
  pointed at a passkey or a second guardian as the backup. Without either, recovery is a
  support request to the operator.

## J6 — Leave

Required by the App Store (guideline 5.1.1(v)) and Google Play, and the right thing
anyway.

| Action | Where, by whom | Effect |
|---|---|---|
| **Konto löschen** | Einstellungen → Konto; any adult; recent sign-in (≤ 5 min, else sign in again) | The Auth user and all its sessions are deleted; its personal devices are revoked. The **profile stays** as a non-account family member, with its history, unless also removed. Sign in with Apple tokens are revoked with Apple. The last guardian *with an account* cannot do this while other members exist: they delete the household or hand over first |
| **Familie verlassen** | Einstellungen → Konto; any adult who is not the last guardian | The account is unlinked from the profile; the account remains and can start or join another family |
| **Familie löschen** | Einstellungen → Familie; a guardian on a personal device; recent sign-in; type the family's name | Every device is signed out at once and the household is marked deleted. **Purged after 14 days** by a job; until then any of its guardians can sign in and choose *Wiederherstellen*. Backups age out within their retention, which the privacy policy states |
| **Daten exportieren** | Einstellungen → Familie; guardian on a personal device | A JSON file of the household's data (GDPR Art. 20). Built 2026-10-14: secrets (PIN and password hashes, token hashes, Auth ids) and technical bookkeeping are left out, devices appear by label only. Required before the opening gate, not before |

Google Play additionally requires a **web page** explaining how to request deletion. It
lives on the same small site as the invitation landing page.

## The getting-started card

Shown on Today in the adult register only, never on the kid or kiosk registers. Every
item is **derived from data**, not ticked by hand. "Kinder-Tablet verbinden" is done
because a shared device exists, so the card is right on every adult's phone, whoever did
the work.

| Item | Shown when | Done when | Scope |
|---|---|---|---|
| Partner einladen | Fewer than two adult accounts | A second adult account exists (shows "Eingeladen" while pending) | Household |
| Kinder-Tablet verbinden | A child profile exists | A `shared` device exists | Household |
| Wanddisplay einrichten | Always | A `kiosk` device exists | Household |
| Eltern-PIN festlegen | A shared/kiosk device exists | This guardian has a PIN | Per guardian |
| Erinnerungen einschalten | Push is built | This device has a push token | Per device |
| Kalender abonnieren (Outlook, iPhone) | The ICS feed is built (M1.3a) | A feed token exists | Household |
| Schneller anmelden mit Passkey | Passkeys verified on this platform | The account has a passkey | Per account |
| Stundenplan eintragen | A child profile exists | A school and a timetable exist (added 2026-10-14) | Household |

*Built 2026-10-14 on `feature/regions-and-ux`, not yet on the server:* the card with the
items above except reminders and passkey, which wait for their features. Stundenplan
eintragen is the extra item: a family with a child in school wants the timetable in the
calendar, and the card says so in the adult's words.

- Progress counts every shown item, done or open ("2 von 6"). At most four open items are
  listed at a time; done items stay in the list. Each item can be dismissed ("Brauchen wir
  nicht"). The household-wide items are dismissed for everyone; "Eltern-PIN festlegen" only
  for the guardian who dismissed it. The card disappears when everything shown is done or
  dismissed, and returns from Einstellungen → Erste Schritte, which restores every dismissal
  of the household and of that guardian.
- Items appear only when their feature exists, so the card grows with the roadmap.
- Only a guardian on a personal or shared device sees the card; members and kiosks get none.
- The push-permission rule from [09](09-clients-and-ux.md) holds: the system prompt
  appears only after a tap on *Erinnerungen einschalten*, never at first launch.

## Empty states

Each module's empty state names **one** action, with the mascot, in the register's
voice. For example, the empty shopping list says "Noch nichts auf der Liste. Tipp auf
eine Kachel." and the empty task board says "Noch keine Aufgaben. Leg die erste an —
oder nimm eine von den Beispielen." These are written with the module, in both
languages, and reviewed in the screenshots ([docs](../docs/)).

## Failures and interruptions

| Situation | What the person sees |
|---|---|
| Apple/Google sheet cancelled | The front door again, no message |
| Apple/Google error | "Das hat nicht geklappt. Versuch es nochmal oder nimm die E-Mail." |
| Wrong email code | "Der Code stimmt nicht." The field clears; after five wrong codes: "Fordere einen neuen Code an." |
| Expired email code | "Der Code ist abgelaufen." with **Neuen Code senden** directly under it |
| Invitation expired, used or withdrawn | "Diese Einladung gilt nicht mehr. Bitte ‹Daniel› um eine neue." |
| Signed up, closed the app before H1 | The next launch opens H1 with whatever was typed (a local draft) |
| Household creation in `code` mode, no code | "Neue Familien gibt es gerade nur mit Gründungscode." plus "Ich wurde eingeladen" |
| Pairing request approved but the tablet went offline | The tablet collects its credentials on its next poll, within the request's lifetime; otherwise the guardian sees it unconnected in Geräte and repeats J3 |
| A device revoked while in use | The front door, as today ([08](08-users-auth-permissions.md#device-pairing)) |

## Copy for the key screens

Both languages, always ([CLAUDE.md](../CLAUDE.md)). These are the reference texts; the ARB
files are the source of truth once built.

| Key (indicative) | Deutsch | English |
|---|---|---|
| `doorTagline` | Der Familienplan für die Küchenwand | The family plan for the kitchen wall |
| `doorApple` | Mit Apple fortfahren | Continue with Apple |
| `doorGoogle` | Mit Google fortfahren | Continue with Google |
| `doorEmail` | Mit E-Mail fortfahren | Continue with email |
| `doorPairDevice` | Familien-Tablet oder Wanddisplay verbinden | Connect a family tablet or wall display |
| `doorInviteCode` | Ich habe einen Einladungscode | I have an invitation code |
| `emailCodeTitle` | Code aus der E-Mail | Code from the email |
| `emailHavePassword` | Ich habe ein Passwort | I have a password |
| `emailWrongCredentials` | E-Mail oder Passwort stimmt nicht. | Email or password is incorrect. |
| `signInMethodTitle` | Wie möchtest du dich künftig anmelden? | How would you like to sign in next time? |
| `signInMethodCode` | Mit Code per E-Mail — nichts zu merken | With a code by email — nothing to remember |
| `householdNewTitle` | Neue Familie | New family |
| `householdMembersTitle` | Wer gehört noch zu euch? | Who else is in your family? |
| `householdSeedExamples` | Mit Beispielen starten — 5 Aufgaben, 3 Belohnungen | Start with examples — 5 tasks, 3 rewards |
| `inviteBanner` | {inviter} hat dich zu {household} eingeladen | {inviter} invited you to {household} |
| `inviteShareMessage` | Komm zu {household} in WuselWall: {link} — oder gib in der App den Code {code} ein. | Join {household} on WuselWall: {link} — or enter the code {code} in the app. |
| `joinConfirmTitle` | Du bist {name} in {household} | You are {name} in {household} |
| `pairShowTitle` | Öffne WuselWall auf deinem Handy und scanne diesen Code | Open WuselWall on your phone and scan this code |
| `pairApproveWarning` | Nur bestätigen, wenn du dieses Gerät vor dir siehst. | Only confirm if you can see this device in front of you. |
| `pairConnected` | Verbunden mit {household} | Connected to {household} |
| `gettingStartedTitle` | Erste Schritte | Getting started |

Auth emails (the code, the "new sign-in" notice) are server-side text and follow the same
rule. See [Email](#email) below.

## Server side

Indicative. Migrations, functions and policies follow the rules in
[03](03-architecture.md) and are specified in [16, step 9](16-setup-plan.md#step-9--onboarding-m10).

**Supabase Auth configuration.**
- `enable_signup = true`, `enable_anonymous_sign_ins = false`, `enable_manual_linking = true`.
- `[auth.email]`: `otp_length = 6`, `otp_expiry = 600`, `max_frequency = "60s"`.
- `[auth.external.apple]` and `[auth.external.google]` enabled on the home server. Other servers enable them only with their operator's own clients (redirect only, [ADR-018](adr/ADR-018-self-hosted-only.md)).
  Client IDs list the web client *and* the native app identifiers. Secrets come from the
  stack's `.env` ([10 §4](10-deployment-and-ops.md#4-sign-in-providers-and-mail)). CLI stacks
  keep them off: CI has no clients, and neither provider redirects to 127.0.0.1.
- `[auth.rate_limit]` set deliberately: email sends, verifications and sign-ins per IP.
  These come on top of the Cloudflare rules (S9 in [19](19-security-and-architecture-review.md)).
- `[auth.email.smtp]` pointing at the provider chosen in [Q41](14-open-questions.md).

**A new account has no household and therefore sees nothing.** The access-token hook adds
`household_id` only for a profile linked to the account (personal device) or an enrolled
device. RLS needs no change to be safe against a fresh stranger.

**Tables** (see [04](04-data-model.md#identity)): `invitation`, `pairing_request`,
`getting_started_dismissal`, `instance_setting`; `setup_token` keeps its name and becomes
the founder codes; `household` gains `created_by_profile_id` and `deleted_at`.

**Functions** (`api`, one per use case; anon-callable ones marked ◦):

| Function | Who | Does |
|---|---|---|
| `my_account` (view) | signed-in | Has a household? Pending invitations for the verified email(s)? Household-creation mode |
| `household_create(name, display_name, colour, timezone, locale, founder_code?, seed_examples)` | signed-in, no household | Household, own guardian profile, seeds, and this session as a personal device, in one transaction |
| `household_add_members(actor, members jsonb)` | guardian | H2's rows |
| `invitation_create / _revoke` | guardian | Returns link token and code once; stores hashes |
| ◦ `invitation_preview(token_or_code)` | anyone, rate-limited | Household name and inviter's first name, or "not valid" |
| `invitation_accept(token_or_code \| invitation_id)` | signed-in, no household | Links the account to the profile, registers the personal device, notifies guardians |
| ◦ `pairing_start()` | anyone, rate-limited per IP | Request id, secret, display code, expiry |
| ◦ `pairing_poll(request_id, secret)` | the requesting device | `pending` · `approved` with one-time credentials (as `enrol_device` returns them today) · `expired` |
| `pairing_approve(actor, code, label, class, register, profile?)` | guardian, personal device | Binds the request; refuses expired or claimed ones |
| `getting_started` (view) / `getting_started_dismiss(actor, key)` | adult | The card |
| `account_leave`, `household_delete(actor, confirm_name)`, `household_restore` | as in J6 | |
| `account-delete` (Edge Function) | signed-in | Deletes the Auth user with the Admin API and revokes the Apple token: outbound HTTP, so not SQL |
| `guardian_reset_mfa(actor, profile)` | guardian, personal device | Removes another guardian's TOTP factor (Admin API in an Edge Function; see ADR-013's portability note) |

After this step, anon can call `health`, `invitation_preview`, `pairing_start` and
`pairing_poll`, plus `enrol_device` for one release. `setup_household` goes. The catalogue
test (`040_catalogue.test.sql`) is updated to exactly this list.

**Apple token revocation** needs Apple's refresh token, which `signInWithIdToken` does not
keep. On first sign-in with Apple, the app passes Apple's authorisation code to a small
Edge Function. The function exchanges it for a refresh token and stores it encrypted
against the user. `account-delete` uses it to call Apple's revoke endpoint.

### Email

Every email the system sends is localised. A Supabase **send-email hook** (an Edge Function
reading the message files in `supabase/functions/_shared/`) renders the code mail and the
"new sign-in" notice in the language the app passed as `locale` at sign-in, and sends it
through Scaleway Transactional Email ([Q41](14-open-questions.md); the setup, sender and
subject line are in [10](10-deployment-and-ops.md#email-setup)). This runs on the homeserver stack
and on every server release (other operators send through their own provider), because the compose stack runs Edge Functions ([A11](19-security-and-architecture-review.md),
fixed). **On self-hosted stacks without the hook**, the GoTrue template is used instead,
with German and English in the same mail, German first.

### Universal links and the landing pages

`https://wuselwall.app/i/‹token›` (invitations), `/p/‹code›` (pairing, so the phone's own
camera works) and `/.well-known/apple-app-site-association` plus `assetlinks.json` (also
needed by passkeys) form the **links site**. It is static and belongs to no backend. Nginx on the homeserver server serves it on
`wuselwall.app`, beside the website ([ADR-017](adr/ADR-017-wuselwall-app-domain.md)). Every
server's invitations use it. The token and the server travel in the fragment, so the site
never receives them ([ADR-018](adr/ADR-018-self-hosted-only.md), decision 8). The landing
page reads the fragment in the browser, and the app gets the whole URL. The
landing pages are bilingual, script-free HTML: what this is, the store buttons, the code
in large type, and a link to the privacy policy. The deletion-request page (Play) sits
alongside.

## How "smooth" is checked

There is no analytics (NFR-9), so the targets in NFR-17 are checked by hand and by test:

- **The release checklist** times J1, J2 and J3 with a stopwatch on real devices, done by
  someone who has not seen the build, and records the times and every hesitation.
- **The E2E suite** ([18](18-testing-strategy.md)) asserts the screen count of J1 and J2.
  A pull request that adds a screen to either fails, and adding one becomes a decision
  rather than an accident.

## Not in onboarding v1

Facebook, Microsoft, GitHub or any other provider; SMS codes (cost, and phone numbers
with a third party); magic links (see [above](#with-email)); *(a "look around first" mode is in since ADR-018: "Ohne Server ausprobieren")*; accounts for
children; several households per account ([Q43](14-open-questions.md)); importing from
other family apps (Cozi, FamCal), which would make switching easier but belongs in M3 at
the earliest.
