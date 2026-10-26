# Gemieteter Server (Hetzner & Co.)

Der Mittelweg zwischen Supabase und dem Rechner zu Hause: Ihr mietet einen kleinen Linux-Server bei einem europäischen Anbieter, und WuselWall richtet sich beim ersten Start selbst ein. Ihr braucht keinen Rechner, der zu Hause dauernd läuft, keine offenen Ports im Router und keine Konten bei GitHub oder Supabase. Die Daten liegen bei einem Anbieter eurer Wahl in Europa, auf einem Server, der nur euch gehört.

Technisch ist das derselbe Docker-Stack wie [zu Hause](/server/home-server). Alles, was dort steht (App verbinden, Backups, Updates, E-Mail-Sprache, Befehle), gilt auch hier. Diese Seite beschreibt nur, wie der Server zu euch kommt.

## Was du brauchst

- Ein Konto bei einem Anbieter mit **cloud-init** (unten eine Auswahl); so ein Server kostet grob **6–25 € im Monat** (Stand Oktober 2026).
- Eine **Domain** mit zwei Namen, `api.` und `web.`, etwa 1–2 € im Monat.
- Einen **SSH-Schlüssel** auf deinem Laptop (`ssh-keygen`, wenn du noch keinen hast).
- Freiwillig: ein **Mail-Konto** für Anmelde-Codes per Mail, ein Gmail-Konto reicht ([E-Mail](/server/email)). Ohne melden sich alle mit Passwort an.

## Anbieter

Die drei in der Tabelle sind europäische Firmen mit Rechenzentren in Europa; jede bietet einen Auftragsverarbeitungsvertrag nach DSGVO und beim Anlegen eines Servers ein Feld für die cloud-init-Datei. Für WuselWall reichen **2 vCPU und 4 GB Arbeitsspeicher**, mit [Texterkennung](/server/extras#texterkennung) 8 GB.

::: info Unabhängig, Preise nur zur Orientierung
WuselWall ist mit keiner der hier genannten Firmen verbunden, wird von keiner gesponsert oder unterstützt und bekommt nichts dafür, dass sie hier stehen; die Links sind gewöhnliche Links, keine Affiliate-Links. Die Liste ist eine Auswahl ohne Reihenfolge, keine Rangliste und nicht vollständig. Die Preisspanne ist ein grober Wert zur Orientierung, Stand Oktober 2026, und kein Angebot; Preise ändern sich und sind je nach Anbieter mit oder ohne Mehrwertsteuer angegeben. Es gelten allein die Preisliste und die Bedingungen des Anbieters. Produkt- und Firmennamen sind Marken ihrer Inhaber.
:::

| Anbieter | Sitz, Rechenzentren | Passende Größe | Feld für die Datei |
|---|---|---|---|
| [Hetzner Cloud](https://www.hetzner.com/cloud) | Deutschland; Falkenstein, Nürnberg, Helsinki | CX23 (2 vCPU, 4 GB); wenn ausverkauft, CPX22 | **Cloud config**; die Anleitung unten |
| [Scaleway](https://www.scaleway.com/) | Frankreich; Paris, Amsterdam, Warschau | DEV1-M (3 vCPU, 4 GB), öffentliche IPv4 extra | **Cloud-init**; praktisch, wenn ihr dort schon den Mail-Versand habt |
| [IONOS](https://www.ionos.de/) | Deutschland; Rechenzentrum in der EU wählen | Cloud Server mit 4 GB | **Cloud-Init User Data** unter den erweiterten Optionen; dokumentiert für den Cloud Server, nicht für den VPS |

**Kosten:** grob **6–25 € im Monat** für einen passenden Server, je nach Anbieter, Größe und Mehrwertsteuer, dazu die Domain (Stand Oktober 2026). Die günstigsten Größen sind zeitweise ausverkauft (bei Hetzner am 25. Oktober 2026 die ganze günstigste Reihe); die nächste Größe kostet etwa das Dreifache. Es gilt die Preisliste des Anbieters.

**Ohne cloud-init-Feld:** [netcup](https://www.netcup.com/), [OVHcloud](https://www.ovhcloud.com/) und [Infomaniak](https://www.infomaniak.com/) (Schweiz, Genf; Schweizer Datenschutzrecht) vermieten ebenfalls passende Server in Europa, dokumentieren aber kein solches Feld. Dort legst du einen Server mit Ubuntu an und installierst per SSH genau wie [zu Hause](/server/home-server).

**Wo liegen die Daten?** Auf eurem eigenen Server beim Anbieter. Er stellt Hardware, Strom und Netz; wie jeder Hoster käme er technisch an die Maschine heran, und sein Auftragsverarbeitungsvertrag verbietet ihm, eure Daten zu nutzen. Die Verbindungen zu euren Geräten sind verschlüsselt, und eure Datenbank liest nur WuselWall. Anders als Supabase Inc. (USA) ist der Anbieter eine europäische Firma und unterliegt europäischem Recht, Infomaniak schweizerischem.

## Bei Hetzner Schritt für Schritt

Die Anleitung zeigt Hetzner, weil die Konsole ein einfaches Feld für cloud-config hat; das ist keine Empfehlung gegenüber den anderen. Masken und Knopfnamen: Stand Oktober 2026, sie können sich ändern.

1. **Datei vorbereiten.** Öffne [`server/cloud-init.yaml`](https://github.com/wuselwall/wuselwall-app/blob/main/server/cloud-init.yaml) auf GitHub, kopiere den Inhalt in einen Texteditor und ändere die eine mit `CHANGE` markierte Zeile: die Release-Version aus den [Releases](https://github.com/wuselwall/wuselwall-app/releases), deine beiden Adressen und die E-Mail-Sprache (`de`, `en`, `fr` oder `es`).
2. **Projekt und Schlüssel.** In der [Hetzner Cloud Console](https://console.hetzner.cloud/) ein Projekt anlegen, etwa „WuselWall“, und unter **Security → SSH keys** deinen öffentlichen SSH-Schlüssel eintragen.
3. **Server anlegen.** **Add server**: Standort Falkenstein, Nürnberg oder Helsinki; Image **Ubuntu 24.04**; Typ **CX23** (2 vCPU, 4 GB) unter Cost-Optimized, oder **CPX22** unter Regular Performance, wenn er ausverkauft ist; Netz IPv4 und IPv6; dein SSH-Schlüssel; eine Hetzner-Firewall kannst du zusätzlich anlegen, die Datei richtet ohnehin eine auf dem Server ein; ganz unten im Feld **Cloud config** den vorbereiteten Inhalt einfügen. Name zum Beispiel `wuselwall`. Dann **Create & Buy now**.
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
