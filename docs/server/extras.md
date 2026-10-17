# Extras für den Server

Alles auf dieser Seite außer dem **E-Mail-Versand** ist **freiwillig**. WuselWall läuft ohne. Jedes Extra bringt einen weiteren Dienst ins Spiel, der etwas über euch erfährt, also nehmt nur, was ihr wirklich braucht.

Die Befehle für einen Server zu Hause laufen im Verzeichnis des Werkzeugs `wuselwall` ([Server zu Hause](/server/home-server)).

## E-Mail {#e-mail}

**Zurzeit nötig.** Wer sich zum ersten Mal anmeldet, bestätigt seine Adresse mit einem **Code per Mail**. Erst danach kann man ein Passwort festlegen. Ohne Mail-Versand kommt der Code nie an, und niemand kann eine Familie anlegen oder einer beitreten. Ein Server ganz ohne Mail, mit Passwort von Anfang an, ist geplant.

Dafür braucht der Server einen SMTP-Dienst, also einen Anbieter, der Mails verschickt. Ein Postfach beim normalen Mailanbieter ist dafür ungeeignet. Nehmt einen Dienst für sogenannte *transaktionale* Mails, etwa Scaleway Transactional Email aus der EU (300 Mails im Monat gratis). Der Anbieter sieht die E-Mail-Adressen und die Codes. Damit die Mails nicht im Spam landen, trägst du bei deiner Domain die Einträge ein, die der Anbieter nennt (SPF, DKIM, DMARC).

**Zu Hause:** Trag in `stack/.env` die Werte `SMTP_HOST`, `SMTP_PORT` (meist `587`), `SMTP_USER`, `SMTP_PASS` und als Absender `SMTP_ADMIN_EMAIL` ein, in einfachen Anführungszeichen wie die anderen Werte. Dann:

```bash
./wuselwall compose up -d auth
```

**Bei Supabase:** **Authentication → Emails → SMTP Settings**, dieselben Angaben. Der eingebaute Mail-Versand von Supabase ist nur zum Ausprobieren gedacht und schickt nur wenige Mails pro Stunde.

## Apple-Zugang widerrufen (nur für ältere Konten) {#apple-widerruf}

Anmelden mit Apple und Google gibt es in WuselWall nicht mehr. Nur wenn auf eurem Server noch Konten aus der Zeit davor bestehen, braucht der Server Zugang bei Apple: Löscht jemand so ein Konto, widerruft WuselWall dort den Apple-Zugang. Dafür braucht der Server in `stack/.env` nur diese fünf Werte: `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_ID` und `APPLE_TOKEN_KEY`. Ohne sie kann der Server den Zugang bei Apple nicht widerrufen. Den Wert `APPLE_TOKEN_KEY` nie ändern: mit ihm sind die gespeicherten Apple-Tokens verschlüsselt.

Klappt der Widerruf nicht sofort (Apple nicht erreichbar, ein Wert fehlt), geht nichts verloren: Der Server merkt sich den offenen Widerruf und versucht es jede Nacht wieder. Das Konto ist schon gelöscht, bevor der Server Apple fragt; antwortet Apple nicht, wartet die Antwort höchstens ein paar Sekunden.

## Update von einer Version mit Apple- und Google-Anmeldung {#social-stilllegen}

**Erst prüfen, dann updaten.** Hat sich jemand bei euch mit Apple und **„E-Mail-Adresse verbergen“** angemeldet, lautet die Adresse seines Kontos `…@privaterelay.appleid.com`. Ein Code an diese Adresse kommt nur an, wenn eure Absenderadresse bei Apple für die Weiterleitung eingetragen ist. Klärt das vor dem Update. Kommt kein Code an, wartet mit dem Update: Sonst kann sich diese Person nach dem nächsten Abmelden nicht mehr anmelden.

**Was das Update von selbst erledigt:**

- **Zu Hause** (`wuselwall update`): Die alten Anmelde-Einstellungen für Apple und Google und die alte Rücksprungadresse der App verschwinden aus `stack/.env`. Die Anmeldung mit Apple, Google und das Verknüpfen von Konten sind ausgeschaltet, die alte Funktion `apple-token` ist weg. Die fünf Werte für den Widerruf bleiben.
- **Bei Supabase** (Workflow **deploy-supabase**): Der Schritt **Retire social sign-in** schaltet Apple, Google und das Verknüpfen ab, entfernt die alte Rücksprungadresse der App (andere Einträge, etwa für Einladungen, bleiben), löscht die Funktion `apple-token` und prüft danach beides. Schlägt etwas fehl, bricht der Workflow ab.

**Danach prüfen:** Wer sich früher mit Apple oder Google angemeldet hat, fordert auf einem **zweiten** Gerät einen Code per E-Mail an und meldet sich damit an. Das erste Gerät bleibt dabei angemeldet. Niemand soll sich zum Ausprobieren abmelden.

**Erst danach aufräumen**, bei Google und Apple:

- **Google:** Löscht nur die OAuth-Clients, die es allein für die WuselWall-Anmeldung gab. Das Google-Cloud-Projekt, die Play Console und alles, was andere Apps oder der Kalender nutzen, bleibt. Im Zweifel: behalten.
- **Apple:** Das halbjährliche Client-Secret für die Anmeldung braucht ihr nicht mehr. Den Schlüssel (`.p8`), die App ID, die Services ID und die eingetragenen Absender für die Weiterleitung **behaltet** ihr, solange es noch Konten mit Apple-Weiterleitung oder offene Widerrufe gibt und solange ihr ein Backup zurückspielen könntet, das noch Apple-Tokens enthält.

Die technischen Einzelheiten stehen in der Spezifikation (`specs/10`, „Retiring social sign-in“).

## Feiertage und Schulferien {#feiertage}

Für die Wochentafel holt der Server einmal pro Woche die Feiertage und Schulferien der Länder, die ihr in den Einstellungen gewählt habt. Die Quelle ist die freie [OpenHolidays API](https://www.openholidaysapi.org/). Der Server schickt dabei nur Ländercodes, nichts über eure Familie, und die Apps fragen OpenHolidays nie selbst. Kommt der Server nicht ins Internet, fehlen die Feiertage, alles andere läuft weiter.

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
