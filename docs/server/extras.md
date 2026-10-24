# Extras für den Server

Alles auf dieser Seite außer dem **E-Mail-Versand** ist **freiwillig**. WuselWall läuft ohne. Jedes Extra bringt einen weiteren Dienst ins Spiel, der etwas über euch erfährt, also nehmt nur, was ihr wirklich braucht.

Die Befehle für einen Server zu Hause laufen im Verzeichnis des Werkzeugs `wuselwall` ([Server zu Hause](/server/home-server)).

## E-Mail {#e-mail}

**Zurzeit nötig.** Wer sich zum ersten Mal anmeldet, bestätigt seine Adresse mit einem **Code per Mail**. Erst danach kann man ein Passwort festlegen. Ohne Mail-Versand kommt der Code nie an, und niemand kann eine Familie anlegen oder einer beitreten. Ein Server ganz ohne Mail, mit Passwort von Anfang an, ist geplant.

**Sprache der E-Mails:** Beim Einrichten wählst du eine einzige Sprache — Deutsch, Englisch, Französisch oder Spanisch (Standard: Deutsch). Diese Sprache gilt für Betreff und Text jeder Anmelde- und Bestätigungsmail, unabhängig von der Gerätesprache. Ändern kannst du sie später mit `./wuselwall language de|en|fr|es` ([Server zu Hause](/server/home-server#email-sprache)).

Dafür braucht der Server einen SMTP-Dienst, also einen Anbieter, der Mails verschickt. Ein Postfach beim normalen Mailanbieter ist dafür ungeeignet. Nehmt einen Dienst für sogenannte *transaktionale* Mails, etwa Scaleway Transactional Email aus der EU (300 Mails im Monat gratis). Der Anbieter sieht die E-Mail-Adressen und die Codes. Damit die Mails nicht im Spam landen, trägst du bei deiner Domain die Einträge ein, die der Anbieter nennt (SPF, DKIM, DMARC).

**Zu Hause:** Trag in `stack/.env` die Werte `SMTP_HOST`, `SMTP_PORT` (meist `587`), `SMTP_USER`, `SMTP_PASS` und als Absender `SMTP_ADMIN_EMAIL` ein, in einfachen Anführungszeichen wie die anderen Werte. Dann:

Ein Server mit Mailversand setzt `ENABLE_EMAIL_AUTOCONFIRM=false` in `stack/.env`.

```bash
./wuselwall compose up -d auth
```

**Bei Supabase:** **Authentication → Emails → SMTP Settings**, dieselben Angaben. Der eingebaute Mail-Versand von Supabase ist nur zum Ausprobieren gedacht und schickt nur wenige Mails pro Stunde.

Die Server-Version und der Workflow **deploy-supabase** richten sowohl die erste Bestätigungsmail als auch spätere Anmeldemails mit einem **sechsstelligen Code** in der gewählten E-Mail-Sprache ein. Ein Scaleway-Hook ist dafür nicht nötig. Gib den Code in der bereits geöffneten App ein. Kommt nur ein Link an, aktualisiere den Server oder starte den Workflow aus dem aktualisierten Repository erneut und fordere danach einen neuen Code an; eine alte Mail ändert sich nicht.

## Update von einer Version mit Apple- und Google-Anmeldung {#social-stilllegen}

Bis Oktober 2026 konnte man sich bei WuselWall auch mit Apple oder Google anmelden. Wer das tat, meldet sich jetzt mit einem Code per E-Mail an die Adresse seines Kontos an. Konto und Familie bleiben dieselben.

**Erst prüfen, dann updaten.** Hat sich jemand bei euch mit Apple und **„E-Mail-Adresse verbergen“** angemeldet, lautet die Adresse seines Kontos `…@privaterelay.appleid.com`. Ein Code an diese Adresse kommt nur an, wenn eure Absenderadresse bei Apple für die Weiterleitung eingetragen ist. Klärt das vor dem Update. Kommt kein Code an, wartet mit dem Update: Sonst kann sich diese Person nach dem nächsten Abmelden nicht mehr anmelden.

**Was das Update von selbst erledigt:**

- **Zu Hause** (`wuselwall update`): Alle Werte für Apple und Google (`APPLE_…`, `GOOGLE_CLIENT_…`) und die alte Rücksprungadresse der App verschwinden aus `stack/.env`, die alte Funktion `apple-token` ist weg. Das Werkzeug nennt dabei nur die Namen, nie die Werte.
- **Bei Supabase** (Workflow **deploy-supabase**): Der Schritt **Retire social sign-in** schaltet Apple, Google und das Verknüpfen von Konten ab, entfernt die alte Rücksprungadresse der App (andere Einträge, etwa für Einladungen, bleiben), löscht die Funktion `apple-token` und die `APPLE_…`-Secrets und prüft danach alles. Schlägt etwas fehl, bricht der Workflow ab.

**Danach prüfen:** Wer sich früher mit Apple oder Google angemeldet hat, fordert auf einem **zweiten** Gerät einen Code per E-Mail an und meldet sich damit an. Das erste Gerät bleibt dabei angemeldet. Niemand soll sich zum Ausprobieren abmelden.

**Erst danach aufräumen**, bei Google und Apple:

- **Google:** Löscht nur die OAuth-Clients, die es allein für die WuselWall-Anmeldung gab. Das Google-Cloud-Projekt, die Play Console und alles, was andere Apps nutzen, bleibt. Im Zweifel: behalten.
- **Apple:** Die Services ID, den Schlüssel für Sign in with Apple und die Erinnerung an das halbjährliche Client-Secret braucht ihr nicht mehr. Die eingetragenen Absender für die Weiterleitung **behaltet** ihr, solange es Konten mit einer `privaterelay`-Adresse gibt.

## Feiertage und Schulferien {#feiertage}

Für die Wochentafel holt der Server einmal pro Woche die Feiertage und Schulferien der Länder, die ihr in den Einstellungen gewählt habt. Die Quelle ist die freie [OpenHolidays API](https://www.openholidaysapi.org/). Der Server schickt dabei nur Ländercodes, nichts über eure Familie, und die Apps fragen OpenHolidays nie selbst. Kommt der Server nicht ins Internet, fehlen die Feiertage, alles andere läuft weiter.

## Texterkennung für Stundenpläne {#texterkennung}

Mit der Texterkennung kann die App einen fotografierten Stundenplan oder die PDF-Datei der Schule einlesen ([Stundenplan einlesen](/school/#stundenplan-einlesen)); bei einer PDF-Datei liest der Container den Text direkt, ein eingescanntes PDF liest er wie ein Foto. Sie ist ein eigener Container im Stack, der nur auf der Rechenleistung eures Servers läuft: Das Foto geht vom Handy an euren Server, der Container liest den Text, und nichts davon verlässt das Haus. Er braucht kein Internet, keine Grafikkarte und etwa 1 GB Arbeitsspeicher; auf einem kleinen Heimserver dauert ein Blatt einige Sekunden.

Einrichten, im Ordner des Stacks:

1. In die `.env` eine Zeile `OCR_URL=http://ocr:9003/ocr` eintragen.
2. Den Container bauen und starten: `docker compose --profile ocr up -d --build`. Beim ersten Bau lädt er die Erkennungsmodelle (etwa 20 MB) herunter; danach läuft er ohne Internet.
3. Die Funktionen neu starten, damit sie die Adresse kennen: `docker compose restart functions`.

Danach bietet die App unter **Einlesen…** den Punkt **Foto scannen** an. Ohne diese Zeile fehlt er nicht, aber die App sagt, dass der Server keine Texterkennung hat. Die Erkennung nutzt RapidOCR mit den PP-OCR-Modellen von PaddleOCR (beides Apache-2.0, derselbe Unterbau, den auch die Fotoverwaltung Immich für ihre Texterkennung verwendet).

Mit dem Bild schickt die App ihre Sprache und die Namen und Kürzel eurer Fächer. So liest der Server eure Wörter als eure Fächer. Die Funktion nimmt Fotos (JPEG, PNG, WebP, HEIC) und PDF-Dateien bis 6 MB an, speichert nichts und schreibt kein Bild ins Protokoll. Was der Server vom Blatt liest und wo seine Grenzen sind, steht unter [Stundenplan einlesen](/school/#stundenplan-einlesen).

## Backup außer Haus {#backup-ausser-haus}

Ein Backup auf demselben Server hilft bei einem Fehler, aber nicht bei einem Brand, einem Diebstahl oder einer kaputten Platte. `wuselwall backup` kann jede Sicherung zusätzlich **verschlüsselt** in einen Cloud-Speicher kopieren, mit [restic](https://restic.net/), z. B. zu Backblaze B2 oder einem S3-Speicher. Der Anbieter sieht nur verschlüsselte Daten.

Lege neben dem Werkzeug die Datei `backup.env` an (`chmod 600 backup.env`):

```bash
RESTIC_REPOSITORY=b2:<bucket>:wuselwall
RESTIC_PASSWORD=<ein langes Passwort, auch in den Passwort-Manager>
B2_ACCOUNT_ID=<key id>
B2_ACCOUNT_KEY=<application key>
```

Beim ersten Mal legst du das Repository an: `docker run --rm --env-file backup.env restic/restic:0.18.0 init`. Danach kopiert jedes `wuselwall backup` die Sicherung dorthin, auch das nächtliche.

Ohne das `RESTIC_PASSWORD` sind die Sicherungen wertlos. Leg es zusammen mit `stack/.env` in den Passwort-Manager.

## Überwachung {#uberwachung}

Ein Backup, das seit sechs Wochen nicht mehr läuft, fällt sonst niemandem auf. Zwei Gratis-Dienste helfen:

- **[healthchecks.io](https://healthchecks.io/):** Leg einen Check an und schreib seine Adresse als `HEALTHCHECK_URL=https://hc-ping.com/…` in die `backup.env`. Nach jedem erfolgreichen Backup meldet sich das Werkzeug dort. Bleibt die Meldung aus, bekommst du eine Mail.
- **Ein Uptime-Monitor** (z. B. Uptime Kuma auf einem anderen Gerät oder ein Gratis-Dienst) ruft `https://api.example.org/.well-known/wuselwall.json` auf. Antwortet der Server dort, laufen Gateway, Datenbank und Anmeldung.
