# Eigener Server: Überblick

WuselWall ist kein Online-Dienst. Jede Familie hat **ihren eigenen Server**, und die App spricht nur mit diesem. Dort liegen eure Termine, Aufgaben und Listen. Wir sehen sie nie, und wir betreiben keinen Server für andere Familien.

Diese Seiten sind für die Person, die den Server einrichtet. Programmieren musst du nicht. Für den Weg über Supabase reicht ein Browser. Für einen Server zu Hause solltest du dich mit SSH und Docker etwas auskennen.

::: warning Stand Oktober 2026
- **Geht:** einen Server bei Supabase oder zu Hause einrichten. Die App fragt beim ersten Start, mit welchem Server sie sich verbinden soll, und kann auch ohne Server eine Beispielfamilie zeigen.
- **Noch nicht:** WuselWall steht noch nicht öffentlich im **App Store** und bei **Google Play**. Bis dahin benutzt ihr die **Web-App** im Browser, am Handy auch als Symbol auf dem Home-Bildschirm.
- **Noch nicht:** Einladungslinks und Push-Benachrichtigungen.
:::

## Ein Server, eine Familie

Ein WuselWall-Server gehört genau **einem Haushalt**. Wenn die erste Familie angelegt ist, kann niemand eine zweite anlegen. Wollen Freunde auch WuselWall, richten sie einen eigenen Server ein. Bei Supabase ist das einfach ein zweites Projekt.

## Zwei Wege

| | [Bei Supabase](/server/supabase-cloud) | [Zu Hause](/server/home-server) |
|---|---|---|
| **Was ihr braucht** | Ein Konto bei Supabase und eines bei GitHub, sonst nichts | Einen Rechner, der dauernd läuft (NAS, Mini-PC, gemieteter Server) mit Docker, und eine eigene Domain |
| **Einrichten** | Im Browser, etwa 20 Minuten | Ein Befehl auf dem Server, dazu Domain und Router einrichten |
| **Wo die Daten liegen** | Bei Supabase Inc. (USA) in einem Rechenzentrum eurer Wahl, z. B. Frankfurt oder Zürich | Auf eurem eigenen Gerät |
| **Kosten** | Gratis zum Ausprobieren, für den Alltag etwa 25 US-Dollar im Monat | Strom und Domain, etwa 1–2 € im Monat |
| **Updates und Backups** | Supabase pflegt den Server, und ab dem Pro-Abo macht es tägliche Backups. Neue WuselWall-Versionen spielst du mit einem Klick ein | Du selbst, mit je einem Befehl |

Unser Rat: Wer schon ein NAS oder einen Heimserver mit Docker betreibt, nimmt den **Server zu Hause**. Alle anderen fangen mit **Supabase** an. Ein Umzug später ist möglich ([Backup zurückspielen](/server/restore)).

## Was ihr braucht und was nicht

So wenig wie möglich ist Pflicht. Alles in der zweiten Tabelle könnt ihr weglassen oder später nachrüsten.

### Pflicht

| Was | Wozu |
|---|---|
| **Ein Supabase-Server**: ein Projekt bei Supabase oder der Docker-Stack zu Hause | Datenbank, Anmeldung, Live-Aktualisierung und die Server-Funktionen von WuselWall |
| **HTTPS** | Die Apps sprechen nur verschlüsselt mit dem Server. Supabase hat es schon, zu Hause holt es der mitgelieferte Webserver Caddy automatisch |
| **Regelmäßige Aufträge** | Sie legen jede Nacht die Aufgaben der nächsten 14 Tage an und schließen den Vortag ab, holen einmal pro Woche die Feiertage und stündlich die Kalender von außen. Sie laufen in der Datenbank selbst, die Installation richtet sie ein |
| **Ein Backup** | Die Datenbank ist das Einzige, was sich nicht neu aufbauen lässt |

### Optional

| Was | Ohne das |
|---|---|
| **Die Web-App** | Nur nötig, solange die Apps nicht in den Stores sind, oder für den Laptop. Zu Hause liefert der Server sie mit, bei Supabase veröffentlicht sie GitHub für euch |
| **E-Mail-Versand (SMTP)** | WuselWall verschickt heute **keine** E-Mails. Konten entstehen mit E-Mail-Adresse und Passwort direkt in der App, ohne Bestätigungsmail ([Extras](/server/extras#e-mail)) |
| **Anmelden mit Apple oder Google** | Alle melden sich mit E-Mail und Passwort an. Lässt sich nachrüsten, aber mit viel Aufwand ([Extras](/server/extras#anmelden-mit-apple-und-google)) |
| **Feiertage und Schulferien** | Der Server holt sie einmal pro Woche bei [OpenHolidays](https://www.openholidaysapi.org/) und schickt dabei nur Ländercodes. Ohne Internetzugang des Servers fehlen sie auf der Wochentafel ([Extras](/server/extras#feiertage)) |
| **Kalender von außen** | Abonniert ihr Kalender von Vereinen oder der Gemeinde, holt der Server sie stündlich von den Adressen, die ihr eingetragen habt. Ohne Abos ruft er nichts ab |
| **Geteilter Familienkalender in Outlook, Google und iPhone** | Funktioniert nur, wenn der Server aus dem Internet erreichbar ist |
| **Passkeys** | Gibt es auf selbst betriebenen Servern nicht. Alle melden sich mit Passwort an, gern mit Zwei-Faktor-Code |
| **Backup außer Haus, Überwachung** | Siehe [Extras](/server/extras#backup-ausser-haus) |

WuselWall braucht **keine** Konten bei Google, Apple, Firebase oder einem Analysedienst und kein Captcha.

## Wie es danach weitergeht

Wenn der Server läuft, öffnest du die App und gibst die Adresse des Servers ein. Bei Supabase reicht die Projekt-ID. Mit dem **Einrichtungs-Token** gründest du dann die Familie ([Neue Familie anlegen](/guide/setup#_3-neue-familie-anlegen-nur-einmal)). Danach verbindest du die anderen Geräte: Der QR-Code unter **Einstellungen → Gerät hinzufügen** enthält den Server gleich mit ([Anmelden und verbinden](/guide/setup)).
