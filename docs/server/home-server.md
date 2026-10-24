# Server zu Hause einrichten

So läuft WuselWall auf eurem eigenen Gerät, etwa auf einem NAS, einem Mini-PC oder einem gemieteten Server. Ein **Server-Release** enthält alles: den Docker-Stack von Supabase, die WuselWall-Teile, die Web-App und das Werkzeug `wuselwall`, das installiert, aktualisiert und sichert.

In den Beispielen heißt eure Domain `example.org`. Der Server ist unter `api.example.org` erreichbar, die Web-App unter `web.example.org`. Setze überall deine eigenen Adressen ein.

## Was du brauchst

- Einen Rechner mit **Linux, Docker und Docker Compose v2** (`docker compose version` antwortet), der dauernd läuft: Debian, Ubuntu oder ein NAS, das Docker Compose kann.
- **4 GB Arbeitsspeicher** für WuselWall und **10 GB** freien Platz. Getestet ist WuselWall auf x86-64. ARM-Geräte wie ein Raspberry Pi 5 sollten gehen, sind aber nicht erprobt.
- Einen Zugang zur Kommandozeile des Servers (SSH), mit einem Benutzer, der `docker` aufrufen darf.
- Eine **Domain** mit zwei Namen, `api.` und `web.`, die auf die öffentliche IP-Adresse eures Anschlusses zeigen. Ändert sich die IP-Adresse oft, hilft ein DynDNS-Dienst.
- Im Router eine Weiterleitung von **TCP 80 und 443** auf den Server.

::: details Ohne offene Ports?
- **Cloudflare Tunnel:** Ein kleines Programm auf dem Server (`cloudflared`) baut die Verbindung zu Cloudflare selbst auf, und du öffnest keinen Port. Cloudflare entschlüsselt dabei den Verkehr und kann ihn sehen. Installiere dann ohne `--caddy` und leite den Tunnel weiter, wie unter „Eigener Webserver statt Caddy“ beschrieben.
- **Nur im VPN** (Tailscale, WireGuard): Der Server bleibt unsichtbar aus dem Internet. Dafür braucht jedes Gerät das VPN, auch das Küchen-Tablet, und der **geteilte Familienkalender** in Outlook und Google funktioniert nicht.
:::

## 1. Installieren

Auf dem Server, in einem Verzeichnis deiner Wahl, am besten auf einer schnellen Platte (SSD). Die neueste Version steht unter [Releases](https://github.com/wuselwall/wuselwall-app/releases). Hier ist es `1.0.0`:

```bash
curl -fsSL https://github.com/wuselwall/wuselwall-app/releases/download/server-v1.0.0/wuselwall-server-1.0.0.tar.gz | tar xz
cd wuselwall
./wuselwall install --api https://api.example.org --web https://web.example.org --language fr --caddy
```

`--language` wählt die **E-Mail-Sprache** (`de`, `en`, `fr` oder `es`, Standard `de`); es ändert nicht die Sprache der App. Das dauert beim ersten Mal ein paar Minuten, weil Docker einige Gigabyte an Images lädt. Das Werkzeug

- erzeugt alle Schlüssel und Passwörter (`stack/.env`),
- startet den Stack, mit **Caddy**, der für beide Adressen Zertifikate von Let's Encrypt holt,
- richtet die Datenbank ein und plant die nächtlichen Aufträge,
- und zeigt zum Schluss die Adresse des Servers sowie einen **Einrichtungslink mit QR-Code**, der den einmaligen Einrichtungscode enthält.

Mehr ist auf dem Server nicht nötig: kein Cronjob für WuselWall, kein Node.js, kein eigener Webserver.

::: danger stack/.env in den Passwort-Manager, sofort
`stack/.env` enthält die Schlüssel, mit denen jedes Gerät angemeldet ist. Ohne sie nützt ein Backup wenig: Nach einer Wiederherstellung müsstet ihr jedes Gerät neu verbinden. Kopiere die Datei in den Passwort-Manager. Erzeuge sie für einen laufenden Server **nie neu**.
:::

::: details Noch kein Release da?
Solange es kein Release gibt, baust du es auf einem Laptop selbst. Du brauchst dafür `git`, `rsync` und Flutter für die Web-App:

```bash
git clone https://github.com/wuselwall/wuselwall-app.git && cd wuselwall-app
scripts/build-server-release.sh 0.1.0              # ohne Flutter: --skip-web
scp dist/wuselwall-server-0.1.0.tar.gz server:     # dann auf dem Server: tar xzf …
```
:::

## 2. Die App verbinden

Die Web-App unter `https://web.example.org` liest die Serveradresse aus eurer
Installation. Du musst dafür keine Adresse oder Schlüssel in die App einbauen.
Beim Laden übernimmt sie die aktuelle Konfiguration, auch wenn der Browser noch
eine alte Serveradresse gespeichert hat. Offline nutzt sie die letzte gespeicherte
Konfiguration. Bei einer geänderten Serveradresse meldest du dich erneut an.

Öffne den Einrichtungslink aus der Installation im Browser oder scanne den zugehörigen
QR-Code. Er enthält den Server und den Einrichtungscode. WuselWall merkt sich den
Code während der E-Mail-Anmeldung, damit du ihn unter **Neue Familie** nicht noch
einmal eingeben musst ([Neue Familie anlegen](/guide/setup#_2-neue-familie-anlegen)).

Du kannst den Server weiterhin von Hand unter **Mit welchem Server?** als
`api.example.org` eintragen. Ein QR-Code, der nur die Serveradresse enthält — etwa
aus einer älteren Installation — überträgt aber keinen Einrichtungscode. In diesem
Fall gibst du den Code aus der Installation einmal unter **Neue Familie** ein.

Einen neuen Einrichtungscode gibt `./wuselwall setup-token`, solange noch keine
Familie angelegt ist. Veröffentliche den Code und den Einrichtungslink nicht.

## 3. Backups

Eine Zeile in der Crontab des Servers (`crontab -e`, oder die Zeitplanung deines NAS) sichert jede Nacht die ganze Datenbank:

```txt
30 3 * * * BACKUP_DIR=/srv/backups/wuselwall /pfad/zu/wuselwall/wuselwall backup nightly
```

Das Werkzeug prüft jede Sicherung und behält sie 14 Tage. Ohne `BACKUP_DIR` landen sie in `backups/` neben dem Werkzeug. Besser ist eine andere Platte als die der Datenbank. Wie die Sicherungen zusätzlich aus dem Haus kommen, steht in den [Extras](/server/extras#backup-ausser-haus), wie du eine zurückspielst, unter [Backup zurückspielen](/server/restore).

## E-Mail-Sprache ändern {#email-sprache}

```bash
./wuselwall language en
```

Erlaubt sind `de`, `en`, `fr` und `es`. Das Werkzeug schreibt `MAIL_LANGUAGE` in `stack/.env`, wählt passende Betreffzeilen und Mail-Vorlagen und startet nur Anmeldung und Funktionen neu. Bestehende Schlüssel bleiben erhalten, und die gewählte Sprache bleibt bei späteren Updates bestehen. Ältere Installationen ohne Angabe gelten als deutschsprachig. Für einen Server aus einem Repository-Checkout änderst du die Sprache nach dem Deployment mit `scripts/remote-stack.sh language en`.

## Updates

```bash
./wuselwall update 1.1.0
```

Das Werkzeug sichert zuerst die Datenbank, lädt die neue Version, startet den Stack neu und spielt die Datenbank-Änderungen ein. Server, Web-App und nächtliche Aufträge sind danach auf demselben Stand.

Kommst du von einer Version mit Anmeldung über Apple oder Google? Lies zuerst [Update von einer Version mit Apple- und Google-Anmeldung](/server/extras#social-stilllegen).

### Welche App zu welchem Server passt {#kompatibilitaet}

Die App prüft beim Verbinden selbst, ob sie zu deinem Server passt, und sagt dir, wenn die App oder der Server ein Update braucht. Jede App versteht die Schnittstelle ihres Servers und die eine davor; der Server nennt außerdem die älteste App, mit der er noch arbeitet. Was gerade läuft, zeigt die App unter **Einstellungen → Versionen**, zum Beispiel „App 1.1.0 · Server 0.3.0 · Schnittstelle 1“. Ab Server 0.3.0 nennt der Server dort seine Version; die Texterkennung bietet die App nur an, wenn der Server sie eingerichtet hat.

<CompatTable />

::: warning Kein automatisches Update für den Stack
Lass keinen Auto-Updater (Watchtower, die automatischen Container-Updates eines NAS) an die Container von WuselWall. Updates kommen mit `wuselwall update`, in einer geprüften Kombination.
:::

## Nützliche Befehle

| Befehl | Was er tut |
|---|---|
| `./wuselwall status` | Zeigt, ob alle Dienste laufen |
| `./wuselwall logs auth` | Protokolle eines Dienstes (`db`, `auth`, `rest`, `realtime`, `functions`, `caddy`) |
| `./wuselwall backup` | Sichert jetzt |
| `./wuselwall setup-token` | Neues Einrichtungs-Token, solange es keine Familie gibt |
| `./wuselwall compose …` | Jeder Docker-Compose-Befehl für den Stack |

Die Verwaltungsoberfläche von Supabase (Studio) ist abgeschaltet. Wer sie will, installiert mit `--studio` und öffnet sie über einen SSH-Tunnel: `ssh -L 54421:172.17.0.1:54421 server`, dann `http://127.0.0.1:54421`. Benutzer und Passwort stehen in `stack/.env` unter `DASHBOARD_USERNAME` und `DASHBOARD_PASSWORD`.

## Eigener Webserver statt Caddy

Läuft auf dem Server schon ein Webserver (nginx, Traefik, der Nginx Proxy Manager), installierst du ohne `--caddy`. Der Stack lauscht dann nur auf `172.17.0.1:54421`, der Adresse von Docker. Dein Webserver braucht:

- für `api.example.org` die Pfade `/auth/v1/`, `/rest/v1/`, `/realtime/v1/` (mit WebSockets) und `/functions/v1/` an `http://172.17.0.1:54421`, dazu `/.well-known/wuselwall.json` an `http://172.17.0.1:54421/functions/v1/server-info`. Alles andere beantwortet er mit 404, auch `/rest/v1/` ohne weiteren Pfad.
- für `web.example.org` die Dateien aus `stack/volumes/web`, unbekannte Pfade auf `index.html`, und dieselbe Weiterleitung für `/.well-known/wuselwall.json`.

Als Vorlage dient `stack/volumes/caddy/Caddyfile`. Läuft dein Webserver auf einem anderen Gerät, trägst du in `stack/.env` als `GATEWAY_BIND` eine Adresse ein, die er erreicht, und startest mit `./wuselwall compose up -d` neu.
