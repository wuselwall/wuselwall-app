# Gemieteter Server (Hetzner & Co.)

Der Mittelweg zwischen Supabase und dem Rechner zu Hause: Ihr mietet einen kleinen Linux-Server bei einem europäischen Anbieter, und WuselWall richtet sich beim ersten Start selbst ein. Ihr braucht keinen Rechner, der zu Hause dauernd läuft, keine offenen Ports im Router und keine Konten bei GitHub oder Supabase. Die Daten liegen bei einem Anbieter eurer Wahl in Europa, auf einem Server, der nur euch gehört.

Technisch ist das derselbe Docker-Stack wie [zu Hause](/server/home-server). Alles, was dort steht (App verbinden, Backups, Updates, E-Mail-Sprache, Befehle), gilt auch hier. Diese Seite beschreibt nur, wie der Server zu euch kommt.

## Was du brauchst

- Ein Konto bei einem Anbieter mit **cloud-init** (unten eine Auswahl); so ein Server kostet etwa **4–8 € im Monat**.
- Eine **Domain** mit zwei Namen, `api.` und `web.`, etwa 1–2 € im Monat.
- Einen **SSH-Schlüssel** auf deinem Laptop (`ssh-keygen`, wenn du noch keinen hast).
- Einen **Mail-Anbieter** für die Anmelde-Codes, wie bei jedem WuselWall-Server ([Extras](/server/extras#e-mail)).

## Anbieter

Alle hier sind europäische Firmen mit Rechenzentren in Europa und einem Auftragsverarbeitungsvertrag nach DSGVO in ihren Vertragsunterlagen. Preise und Verfügbarkeit ändern sich; prüfe sie beim Anbieter. Für WuselWall reichen **2 vCPU und 4 GB Arbeitsspeicher**, mit [Texterkennung](/server/extras#texterkennung) 8 GB.

| Anbieter | Sitz, Rechenzentren | Passende Größe | Anmerkung |
|---|---|---|---|
| [Hetzner Cloud](https://www.hetzner.com/cloud) | Deutschland; Falkenstein, Nürnberg, Helsinki | 2 vCPU, 4 GB, ab etwa 4–6 €, dazu 0,50 € für eine IPv4-Adresse | Die Anleitung unten. Die günstigen Größen sind zeitweise ausverkauft |
| [netcup](https://www.netcup.com/) | Deutschland; Nürnberg, Wien | VPS mit 4 GB, etwa 4–6 € | Günstig; auf die Vertragslaufzeit achten |
| [IONOS](https://www.ionos.de/) | Deutschland | VPS mit 4 GB, etwa 5–8 € | |
| [Scaleway](https://www.scaleway.com/) | Frankreich; Paris, Amsterdam, Warschau | DEV1-M oder vergleichbar, etwa 8 € | Praktisch, wenn ihr dort schon den Mail-Versand habt |
| [OVHcloud](https://www.ovhcloud.com/) | Frankreich; Gravelines, Straßburg u. a. | VPS mit 4 GB, etwa 5–7 € | |
| [Infomaniak](https://www.infomaniak.com/) | Schweiz; Genf | VPS oder Public Cloud mit 4 GB, etwa 6–10 € | Schweizer Datenschutzrecht |

**Wo liegen die Daten?** Auf eurem eigenen Server beim Anbieter. Er stellt Hardware, Strom und Netz und sieht die verschlüsselte Verbindung, nicht ihren Inhalt; eure Datenbank liest nur WuselWall. Anders als bei Supabase ist der Anbieter eine europäische Firma, und nur europäisches Recht gilt.

## Bei Hetzner Schritt für Schritt

1. **Datei vorbereiten.** Öffne [`server/cloud-init.yaml`](https://github.com/wuselwall/wuselwall-app/blob/main/server/cloud-init.yaml) auf GitHub, kopiere den Inhalt in einen Texteditor und ändere die eine mit `CHANGE` markierte Zeile: die Release-Version aus den [Releases](https://github.com/wuselwall/wuselwall-app/releases), deine beiden Adressen und die E-Mail-Sprache (`de`, `en`, `fr` oder `es`).
2. **Projekt und Schlüssel.** In der [Hetzner Cloud Console](https://console.hetzner.cloud/) ein Projekt anlegen, etwa „WuselWall“, und unter **Security → SSH keys** deinen öffentlichen SSH-Schlüssel eintragen.
3. **Server anlegen.** **Add server**: Standort Falkenstein, Nürnberg oder Helsinki; Image **Ubuntu 24.04**; Typ ein geteilter Server mit **4 GB**; Netz IPv4 und IPv6; dein SSH-Schlüssel; eine Hetzner-Firewall kannst du zusätzlich anlegen, die Datei richtet ohnehin eine auf dem Server ein; ganz unten im Feld **Cloud config** den vorbereiteten Inhalt einfügen. Name zum Beispiel `wuselwall`. Dann **Create & Buy now**.
4. **DNS.** Die Console zeigt die IPv4-Adresse des neuen Servers sofort. Trage bei deinem Domain-Anbieter zwei A-Einträge ein, `api` und `web`, auf diese Adresse (gern dazu AAAA-Einträge mit der IPv6-Adresse). Caddy versucht es so lange, bis die Namen stimmen.
5. **Ergebnis lesen.** Nach 5–10 Minuten:

   ```bash
   ssh root@<ip> cat /srv/wuselwall/install.log
   ```

   Dort stehen die Serveradresse, der Einrichtungslink mit QR-Code und der einmalige Einrichtungscode. Kopiere `/srv/wuselwall/stack/.env` sofort in den Passwort-Manager ([warum](/server/home-server#_1-installieren)).
6. **Weiter wie zu Hause:** [App verbinden](/server/home-server#_2-die-app-verbinden) und [Backup](/server/home-server#_3-backups) einrichten, dazu gleich ein [Backup außer Haus](/server/extras#backup-ausser-haus), denn ein gemieteter Server hat nur eine Platte. Hetzners eigene Backups (etwa 20 % Aufpreis) sichern die ganze Festplatte und sind eine gute Ergänzung, ersetzen das WuselWall-Backup aber nicht.

Bei anderen Anbietern heißt das Feld **User data**, **Cloud-init** oder **Startskript**; die Schritte sind dieselben.

## Im Alltag

Die Befehle laufen per SSH im Verzeichnis `/srv/wuselwall`, wie [zu Hause](/server/home-server#nutzliche-befehle):

| | Befehl |
|---|---|
| Update auf eine neue Version | `./wuselwall update 1.1.0` |
| Backup jetzt | `./wuselwall backup` |
| Läuft alles? | `./wuselwall status` |

Ubuntu spielt Sicherheitsupdates von selbst ein. Nach einem Kernel-Update startest du den Server einmal neu (`reboot`); der Stack kommt danach von selbst wieder hoch.

## Umzug

Vom gemieteten Server nach Hause oder zurück: Backup ziehen, am neuen Ort mit der alten `stack/.env` installieren und das Backup zurückspielen ([Backup zurückspielen](/server/restore)). Bleiben die Adressen gleich, bleiben alle Geräte angemeldet.
