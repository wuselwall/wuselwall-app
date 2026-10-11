# 00 — Original Brief & Decisions Taken

Kept verbatim so that a later session — or a later you — can tell what was asked for from
what was inferred.

## The brief, as given (2026-08-29, in German)

> **Scope**
>
> **A** Tagesplanung für die Familie mit:
> **A1** Familienkalender (Anzeigen eines Familienkalenders, der auch in anderen
> Umgebungen verwendet werden kann (z.B. von meinem Outlook auf dem Arbeitslaptop))
> **A2** Aufgabenverwaltung – z.B. für wiederkehrende Aufgaben im Haushalt, aber auch für
> Sonderaufgaben. Gerne mit Gamification, Pflichtaufgaben oder ähnlichem.
> **A3** Essensplan: Damit wir planen können, wann es was zu essen gibt.
> **A4** Einkaufsliste: Damit man jederzeit aufschreiben kann, wenn man etwas braucht und
> dann im Supermarkt die Liste abarbeiten kann.
>
> **B** Generelle Wünsche
> **B1** User – jedes Familienmitglied soll einen eigenen Nutzer haben, damit man Aufgaben
> als erledigt markieren kann, Termine einstellen kann.
> **B2** Multi-Device: Es sollte funktionieren, dass die App auf einem Notebook (z.B. im
> Browser) funktioniert, aber auch auf einem iPad (der Kinder) oder einem iPhone (der
> Eltern) oder einem einfachen Touch-Display / Tablet.
> **B3** Deployment: Ich habe keine Erfahrung, wie man eine solche App am besten deployt.
> Es wäre okay, wenn dafür auch kleinere Kosten benötigt werden. Ich will die App aber
> nicht für andere kommerzialisieren – dennoch wäre es super, wenn die App in Sachen
> Sicherheit gut umgesetzt wäre und die Daten nicht unnötig von vielen Diensten
> abgegriffen werden können.
> **B4** MCP-Anbindung: Idealerweise gibt es auch die Möglichkeit, dass z.B. Siri oder in
> Zukunft ein AI-Assistant mit der App interagieren kann.
>
> Ziel ist eine Dokumentation des Vorhabens, gerne auch auf Englisch, damit ich dann
> später Code erstellen kann. Ggfs. kommen später weitere Anforderungen dazu.
>
> *(This folder is for planning only; coding, deployment and everything technical happens
> separately.)*

## Decisions taken by the user

| Question | Answer | Recorded in |
|---|---|---|
| Calendar backbone | **Own database with an outbound ICS feed** | [ADR-001](adr/ADR-001-calendar-backbone.md) |
| Build vs. assemble | **Build one application from scratch** | [ADR-002](adr/ADR-002-build-vs-assemble.md) |
| Hosting | **Small VPS in Germany** — with the note "I'll need more guidance here" | [ADR-005](adr/ADR-005-hosting.md), [10](10-deployment-and-ops.md) |
| Technology | **TypeScript end to end** | [ADR-003](adr/ADR-003-technology-stack.md) |
| Household | **2 adults, 2 children aged 7 and 9** | [01](01-vision-and-scope.md) |
| Login model | **Device session with tap-to-switch profiles** | [ADR-004](adr/ADR-004-identity-model.md) |
| Gamification | **Points with redeemable rewards, plus streaks and badges** | [06](06-module-tasks.md) |
| Devices | **Parents' iPhones, children's iPads, laptop browser, fixed wall display** | [09](09-clients-and-ux.md) |
| First release | **All four modules at once** | [13](13-roadmap.md) |
| Stundenplan and presence (added 2026-08-30) | **In v1**, because the kitchen display depends on both | [15](15-module-school-timetable.md) |
| The kitchen display's standard view | **A seven-day week board**, not a today dashboard | [09](09-clients-and-ux.md#the-week-board) |

## Where the plan pushes back

Three places where the documentation recommends something other than the obvious reading
of the brief. Each is argued in full at the link; flagged here so they are not missed.

1. **Tap-to-switch profiles cannot prove who did anything** on a shared device. The plan
   accepts the choice — password prompts on a kitchen display are how family software dies
   — but treats attribution as cooperative bookkeeping and gates every action that moves
   points behind a guardian PIN. → [ADR-004](adr/ADR-004-identity-model.md)
2. **"All four modules at once" needs a walking skeleton in front of it.** Milestone 0
   ships one thin slice to production in the first fortnight so that TLS, auth, the PWA
   and deployment are proven before four modules of domain logic land on top.
   → [13](13-roadmap.md)
3. **Outlook will lag by 3–24 hours.** This is a Microsoft limitation on subscribed
   internet calendars with no configuration and no manual refresh. The ICS feed is an
   awareness channel; anything time-critical goes out as a web push instead.
   → [05](05-module-calendar.md)

## Later additions

The brief notes that further requirements may follow. Add them to
[02 — Requirements](02-requirements.md) with a new ID and an origin of `late`, and record
the date here.

### 2026-08-30 — A5: Stundenplan, flexible appointments, and the kitchen's standard view

> I want to add another key feature, basically a special version of views the calendar:
> Adding school schedule (Stundenplan) for the kids. Appointments in general should be
> flexible, e.g. regular to maintain when Sabine is working or flexible to show when Lukas
> is travelling for work.
>
> The standard view in the kitchen (kiosk style) should contain the Stundenplan, main
> appointments in the week.

Three distinct requirements, and they were treated as three:

| Ask | Answer | Where |
|---|---|---|
| The children's Stundenplan | A first-class **timetable pattern** — weekday × Stunde → Fach, term-bound, minus Ferien, plus per-date exceptions — projected into the calendar rather than stored as sixty recurring events | [15](15-module-school-timetable.md), [ADR-008](adr/ADR-008-school-timetable-model.md), FR-7.x |
| Flexible appointments: regular for Sabine's work, ad hoc for Lukas's travel | A second event **kind**, `presence`, in the same table: rotas as `RRULE` *or* an explicit `RDATE` set tapped into a month grid, travel as a plain span with a `tentative` status | [05](05-module-calendar.md#what-a-calendar-entry-can-be), [ADR-009](adr/ADR-009-event-kinds-and-presence.md), FR-1.11–1.17 |
| The kitchen's standard view | The kiosk's default screen is now a **seven-day week board** with four fixed zones per day, not the today dashboard originally planned | [09](09-clients-and-ux.md#the-week-board), FR-8.x |

**What this cost.** Roughly a month on M1 (see [13](13-roadmap.md#effort)), most of it in
the projection function and the week board. **What it changed elsewhere:** `event` gained
five columns, feed tokens gained a kind filter and now default to appointments only,
"who is eating at home" was promoted from `S` to `M` because the meal zone depends on it,
and the security model's most sensitive asset is no longer the calendar but a child's
timetable combined with an adult's absence pattern ([11](11-security-and-privacy.md)).

**Naming note.** The examples throughout the documents use the household's own names:
*Lukas* and *Sabine* for the adults, *Lotta* (9) and *Hanna* (7) for the children.

**Refined 2026-09-02, from the first review of the mockup:** the wall carries only each
child's school-day span and the lessons worth packing for, with the full Stundenplan one
tap away (FR-8.3a); key appointments sit in three fixed day parts rather than on a time
axis, with a dot per attendee (FR-8.3b); the meal zone shows one warm meal a day; and each
adult gained a **baseline presence** so that only deviations are entered and only
deviations are emphasised (FR-1.18). Lotta's timetable in the mockup is the real one from
the class's paper plan.
