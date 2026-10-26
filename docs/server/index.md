# Eigener Server: Überblick

WuselWall ist kein Online-Dienst. Jede Familie hat **ihren eigenen Server**, und die App spricht nur mit diesem. Dort liegen eure Termine, Aufgaben und Listen. Wir sehen sie nie, und wir betreiben keinen Server für andere Familien.

Diese Seiten sind für die Person, die den Server einrichtet. Programmieren musst du nicht. Für einen gemieteten Server brauchst du eine Domain und einmal SSH, um das Ergebnis zu lesen. Für einen Server zu Hause solltest du dich mit SSH und Docker etwas auskennen.

::: warning Stand Oktober 2026
- **Geht:** einen Server bei einem Anbieter wie Hetzner oder zu Hause einrichten. Die App fragt beim ersten Start, mit welchem Server sie sich verbinden soll, und kann auch ohne Server eine Beispielfamilie zeigen.
- **Noch nicht:** WuselWall steht noch nicht öffentlich im **App Store** und bei **Google Play**. Bis dahin benutzt ihr die **Web-App** im Browser, am Handy auch als Symbol auf dem Home-Bildschirm.
- **Funktioniert:** Einladungslinks. **Noch nicht:** Push-Benachrichtigungen.
:::

## Ein Server, eine Familie

Ein WuselWall-Server gehört genau **einem Haushalt**. Wenn die erste Familie angelegt ist, kann niemand eine zweite anlegen. Wollen Freunde auch WuselWall, richten sie einen eigenen Server ein.

## Zwei Wege

| | [Gemietet](/server/rented-server) | [Zu Hause](/server/home-server) |
|---|---|---|
| **Was ihr braucht** | Ein Konto bei einem europäischen Anbieter wie Hetzner und eine Domain | Einen Rechner, der dauernd läuft (NAS, Mini-PC) mit Docker und eine eigene Domain |
| **Einrichten** | Eine Datei beim Anlegen des Servers einfügen und zwei DNS-Einträge setzen, etwa 15 Minuten | Ein Befehl auf dem Server, dazu Domain und Router einrichten |
| **Wo die Daten liegen** | Bei einem europäischen Anbieter eurer Wahl, auf eurem eigenen Server | Auf eurem eigenen Gerät |
| **Kosten** | Grob 6–25 € im Monat, dazu die Domain | Strom und Domain, etwa 1–2 € im Monat |
| **Updates und Backups** | Du selbst, mit je einem Befehl per SSH; das System hält sich selbst aktuell | Du selbst, mit je einem Befehl |

Die Preise sind grobe Werte zur Orientierung, Stand Oktober 2026, keine Angebote; es gilt die aktuelle Preisliste des Anbieters. WuselWall ist unabhängig und mit Hetzner und den anderen hier genannten Anbietern nicht verbunden.

Unser Rat: Wer schon ein NAS oder einen Heimserver mit Docker betreibt, nimmt den **Server zu Hause**. Wer die Daten in Europa und unter eigener Kontrolle will, ohne ein Gerät zu Hause, mietet einen **Server bei Hetzner & Co.** Ein Umzug später ist möglich ([Backup zurückspielen](/server/restore)).

## Was ihr braucht und was nicht

So wenig wie möglich ist Pflicht. Alles in der zweiten Tabelle könnt ihr weglassen oder später nachrüsten.

### Pflicht

| Was | Wozu |
|---|---|
| **Ein Server** mit dem Docker-Stack von WuselWall, gemietet oder zu Hause | Datenbank, Anmeldung, Live-Aktualisierung und die Server-Funktionen von WuselWall |
| **HTTPS** | Die Apps sprechen nur verschlüsselt mit dem Server. Das Zertifikat holt der mitgelieferte Webserver Caddy automatisch |
| **Regelmäßige Aufträge** | Sie legen jede Nacht die Aufgaben der nächsten 14 Tage an und schließen den Vortag ab, holen einmal pro Woche die Feiertage und stündlich die Kalender von außen. Sie laufen in der Datenbank selbst, die Installation richtet sie ein |
| **Ein Backup** | Die Datenbank ist das Einzige, was sich nicht neu aufbauen lässt |

### Optional

| Was | Ohne das |
|---|---|
| **E-Mail** | Alle melden sich mit E-Mail-Adresse und Passwort an, ein vergessenes Passwort setzt ein Erziehungsberechtigter zurück. Mit E-Mail (ein Gmail-Konto reicht) kommen Anmelde-Codes per Mail ([E-Mail](/server/email)) |
| **Die Web-App** | Nur nötig, solange die Apps nicht in den Stores sind, oder für den Laptop. Der Server liefert sie mit |
| **Feiertage und Schulferien** | Der Server holt sie einmal pro Woche bei [OpenHolidays](https://www.openholidaysapi.org/) und schickt dabei nur Ländercodes. Ohne Internetzugang des Servers fehlen sie auf der Wochentafel ([Extras](/server/extras#feiertage)) |
| **Kalender von außen** | Abonniert ihr Kalender von Vereinen oder der Gemeinde, holt der Server sie stündlich von den Adressen, die ihr eingetragen habt. Ohne Abos ruft er nichts ab |
| **Geteilter Familienkalender in Outlook, Google und iPhone** | Funktioniert nur, wenn der Server aus dem Internet erreichbar ist |
| **Passkeys** | Gibt es auf selbst betriebenen Servern nicht. Alle melden sich mit Passwort an, gern mit Zwei-Faktor-Code |
| **Backup außer Haus, Überwachung** | Siehe [Extras](/server/extras#backup-ausser-haus) |

WuselWall braucht **keine** Konten bei Google, Apple, Firebase oder einem Analysedienst und kein Captcha.

## Wie es danach weitergeht

Wenn der Server läuft, öffnest du die App und gibst die Adresse des Servers ein. Mit dem **Einrichtungs-Token** gründest du dann die Familie ([Neue Familie anlegen](/guide/setup#_3-neue-familie-anlegen-nur-einmal)). Danach verbindest du die anderen Geräte: Der QR-Code unter **Einstellungen → Gerät hinzufügen** enthält den Server gleich mit ([Anmelden und verbinden](/guide/setup)).
