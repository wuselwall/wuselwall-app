# Backup zurückspielen

Ein Backup ist erst etwas wert, wenn es sich zurückspielen lässt. Der Weg unten ist durchgespielt: Server installiert, Familie angelegt, gesichert, Server samt Daten gelöscht, neu installiert und zurückgespielt – danach war alles wieder da, und die Geräte blieben angemeldet. Probiert es einmal aus, solange nichts kaputt ist: auf einem zweiten Rechner oder in einer virtuellen Maschine.

## Zu Hause oder gemietet {#zu-hause}

Das Werkzeug `wuselwall` spielt eine Sicherung aus `wuselwall backup` auf einen **frisch installierten** Server zurück. Typische Fälle: Der alte Server ist kaputt, oder WuselWall zieht auf einen neuen Rechner um.

Du brauchst:

- eine Sicherung, eine Datei `db-….dump` aus dem Backup-Verzeichnis,
- die **`.env` des alten Servers** aus dem Passwort-Manager. Mit ihr bleiben alle Geräte angemeldet, denn Schlüssel, Passwörter und Adressen sind dieselben.

So geht es, auf dem neuen Server:

1. Lass eure Domain auf den neuen Server zeigen (DNS oder Portweiterleitung im Router).
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
Auf einem Server, auf dem schon eine Familie angelegt ist, weigert sich `restore`. Willst du wirklich einen älteren Stand zurückholen, setzt du `WW_RESTORE_OVER_DATA=yes` davor. Das Werkzeug sichert den jetzigen Stand dann zuerst.
:::

**Ohne die alte `.env`** geht es auch: Installiere ganz normal mit `--api` und `--web` und spiele die Sicherung zurück. Eure Daten sind dann wieder da, aber jedes Gerät muss sich neu anmelden oder neu verbunden werden.
