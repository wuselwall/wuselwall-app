# Backup zurückspielen

Ein Backup ist erst etwas wert, wenn es sich zurückspielen lässt. Der Weg unten ist durchgespielt: Server installiert, Familie angelegt, gesichert, Server samt Daten gelöscht, neu installiert und zurückgespielt – danach war alles wieder da, und die Geräte blieben angemeldet. Probiert es einmal aus, solange nichts kaputt ist: auf einem zweiten Rechner oder in einer virtuellen Maschine.

## Zu Hause {#zu-hause}

Das Werkzeug `wuselwall` spielt eine Sicherung aus `wuselwall backup` auf einen **frisch installierten** Server zurück. Typische Fälle: Der alte Server ist kaputt, oder WuselWall zieht auf einen neuen Rechner um.

Du brauchst:

- eine Sicherung, eine Datei `db-….dump` aus dem Backup-Verzeichnis,
- die **`.env` des alten Servers** aus dem Passwort-Manager. Mit ihr bleiben alle Geräte angemeldet, denn Schlüssel, Passwörter und Adressen sind dieselben.

So geht es, auf dem neuen Server:

1. Lass die Namen `api.` und `web.` auf den neuen Server zeigen (DNS oder Portweiterleitung im Router).
2. Entpacke dieselbe oder eine neuere WuselWall-Version wie beim [Installieren](/server/home-server#_1-installieren) und installiere mit der alten `.env`:

   ```bash
   ./wuselwall install --env /pfad/zur/alten.env
   ```

   Die Adressen und `--caddy` stecken in der alten Datei; das Werkzeug fragt nicht danach.
3. Spiele die Sicherung zurück:

   ```bash
   ./wuselwall restore /pfad/zu/db-2026-10-14-0330-nightly.dump
   ```

   Das Werkzeug hält alle Dienste außer der Datenbank an, ersetzt die Datenbank durch die Sicherung, startet alles wieder, spielt Änderungen neuerer Versionen ein und plant die nächtlichen Aufträge neu. Zum Schluss zählt es Familien, Mitglieder, Geräte und Konten.
4. Öffne die App auf einem Handy: Sie sollte ohne neue Anmeldung weiterlaufen.

::: warning Auf einen Server mit Daten
Auf einem Server, auf dem schon eine Familie angelegt ist, weigert sich `restore`. Willst du wirklich einen älteren Stand zurückholen, setzt du `WW_RESTORE_OVER_DATA=yes` davor.
:::

Bevor es etwas ersetzt, sichert das Werkzeug immer den jetzigen Stand (`db-…-before-restore.dump`), auch auf einem leeren Server. Kann es nicht feststellen, ob eine Familie da ist, oder scheitert diese Sicherung, bricht es ab, ohne etwas zu ändern.

**Ohne die alte `.env`** geht es auch: Installiere ganz normal mit `--api` und `--web` und spiele die Sicherung zurück. Eure Daten sind dann wieder da, aber jedes Gerät muss sich neu anmelden oder neu verbunden werden.

### Verschlüsselte Sicherungen {#verschluesselt}

Eine Sicherung enthält alles, auch Passwort-Hashes und die Geheimnisse der Zwei-Faktor-Codes. Das Werkzeug legt sie nur für den Besitzer lesbar in ein Verzeichnis, das nur er öffnen kann. Liegen die Sicherungen auf einer Freigabe, die andere im Netz lesen, oder willst du sie zusätzlich schützen, verschlüsselt es jede Datei, wenn in der `backup.env` neben dem Werkzeug (`chmod 600`) eine dieser Zeilen steht:

```bash
# Empfohlen: mit age (apt install age). Der Server kennt nur den öffentlichen Schlüssel.
BACKUP_AGE_RECIPIENT=age1…
# Oder mit einer langen Passphrase (openssl, ist schon da):
BACKUP_PASSPHRASE='…'
```

Den Schlüssel für age erzeugst du einmal auf deinem Laptop mit `age-keygen -o wuselwall-backup.key`; die Zeile `public key: age1…` gehört in die `backup.env`, die Datei `wuselwall-backup.key` in den Passwort-Manager und **nicht** auf den Server. Die Passphrase gehört ebenfalls in den Passwort-Manager. Ohne Schlüssel oder Passphrase ist eine verschlüsselte Sicherung wertlos.

Die Sicherungen heißen dann `db-….dump.age` oder `db-….dump.enc`. Zum Zurückspielen entschlüsselst du sie zuerst und gibst `restore` die entschlüsselte Datei:

```bash
age -d -i /pfad/zu/wuselwall-backup.key -o db-2026-10-14-0330-nightly.dump db-2026-10-14-0330-nightly.dump.age
# oder, mit der Passphrase (openssl fragt danach):
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in db-2026-10-14-0330-nightly.dump.enc -out db-2026-10-14-0330-nightly.dump
```

Lösche die entschlüsselte Datei danach wieder. Die Probe-Wiederherstellung (`infra/backup/restore-drill.sh`) liest verschlüsselte Sicherungen direkt, mit `BACKUP_PASSPHRASE` oder mit `BACKUP_AGE_IDENTITY=/pfad/zu/wuselwall-backup.key`.

## Bei Supabase {#bei-supabase}

- **Mit Pro:** Im Dashboard unter **Database → Backups** wählst du einen der letzten 7 Tage und spielst ihn zurück. Das Projekt ist dabei ein paar Minuten nicht erreichbar.
- **Eigene Kopie:** Mit der Supabase-CLI ziehst du etwa einmal im Monat eine Kopie auf deinen Rechner. Wie das geht und wie du sie zurückspielst, beschreibt Supabase unter [Backup and Restore using the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore). Leg die Dateien verschlüsselt ab, denn sie enthalten alles.

Ein Umzug zwischen Supabase und einem Server zu Hause ist mit diesen Kopien möglich, aber noch nicht als Schritt-für-Schritt-Anleitung beschrieben.
