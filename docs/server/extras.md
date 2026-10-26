# Extras für den Server

Alles auf dieser Seite ist **freiwillig**. WuselWall läuft ohne. Jedes Extra bringt einen weiteren Dienst ins Spiel, der etwas über euch erfährt, also nehmt nur, was ihr wirklich braucht.

Die Befehle für einen Server zu Hause laufen im Verzeichnis des Werkzeugs `wuselwall` ([Server zu Hause](/server/home-server)).

## E-Mail {#e-mail}

E-Mail ist freiwillig: Ohne melden sich alle mit Passwort an. Wie der Server die Anmelde-Codes per Mail verschickt, auch über Gmail, steht auf einer eigenen Seite: [E-Mail](/server/email).

## Update von einer Version mit Apple- und Google-Anmeldung {#social-stilllegen}

Bis Oktober 2026 konnte man sich bei WuselWall auch mit Apple oder Google anmelden. Wer das tat, meldet sich jetzt mit einem Code per E-Mail an die Adresse seines Kontos an. Konto und Familie bleiben dieselben.

**Erst prüfen, dann updaten.** Hat sich jemand bei euch mit Apple und **„E-Mail-Adresse verbergen“** angemeldet, lautet die Adresse seines Kontos `…@privaterelay.appleid.com`. Ein Code an diese Adresse kommt nur an, wenn eure Absenderadresse bei Apple für die Weiterleitung eingetragen ist. Klärt das vor dem Update. Kommt kein Code an, wartet mit dem Update: Sonst kann sich diese Person nach dem nächsten Abmelden nicht mehr anmelden.

**Was das Update von selbst erledigt:** Mit `wuselwall update` verschwinden alle Werte für Apple und Google (`APPLE_…`, `GOOGLE_CLIENT_…`) und die alte Rücksprungadresse der App aus `stack/.env`, die alte Funktion `apple-token` ist weg. Das Werkzeug nennt dabei nur die Namen, nie die Werte.

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
