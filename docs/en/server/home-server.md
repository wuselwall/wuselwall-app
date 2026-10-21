# Setting up a server at home

This is how WuselWall runs on your own device, for example a NAS, a mini PC or a rented server. A **server release** contains everything: Supabase's Docker stack, the WuselWall parts, the web app and the `wuselwall` tool that installs, updates and backs up.

In the examples your domain is `example.org`. The server is reached at `api.example.org` and the web app at `web.example.org`. Use your own addresses everywhere.

## What you need

- A machine with **Linux, Docker and Docker Compose v2** (`docker compose version` answers) that runs all the time: Debian, Ubuntu, or a NAS that can run Docker Compose.
- **4 GB of memory** for WuselWall and **10 GB** of free space. WuselWall is tested on x86-64. ARM devices such as a Raspberry Pi 5 should work but are untested.
- Access to the server's command line (SSH), as a user who may run `docker`.
- A **domain** with two names, `api.` and `web.`, pointing at your connection's public IP address. If that address changes often, a dynamic DNS service helps.
- In the router, forwarding of **TCP 80 and 443** to the server.

::: details No open ports?
- **Cloudflare Tunnel:** a small program on the server (`cloudflared`) connects out to Cloudflare, and you open no port. Cloudflare decrypts the traffic on the way and can see it. Then install without `--caddy` and point the tunnel at the stack as described under "Your own web server instead of Caddy".
- **VPN only** (Tailscale, WireGuard): the server stays invisible from the internet. In exchange every device needs the VPN, the kitchen tablet too, and the **shared family calendar** in Outlook and Google doesn't work.
:::

## 1. Installing

On the server, in a directory of your choice, ideally on a fast disk (SSD). The newest version is listed under [Releases](https://github.com/wuselwall/wuselwall-app/releases); here it is `1.0.0`:

```bash
curl -fsSL https://github.com/wuselwall/wuselwall-app/releases/download/server-v1.0.0/wuselwall-server-1.0.0.tar.gz | tar xz
cd wuselwall
./wuselwall install --api https://api.example.org --web https://web.example.org --language fr --caddy
```

`--language` chooses the **email language** (`de`, `en`, `fr` or `es`, default `de`); it does not change the app's language. The first time this takes a few minutes, because Docker downloads several gigabytes of images. The tool

- generates every key and password (`stack/.env`),
- starts the stack, with **Caddy**, which fetches Let's Encrypt certificates for both addresses,
- sets up the database and schedules the nightly jobs,
- and finally shows the server address and a **setup link with a QR code**, carrying the one-time setup code.

Nothing more is needed on the server: no cron job for WuselWall, no Node.js, no web server of your own.

::: danger stack/.env into the password manager, right away
`stack/.env` holds the keys every device is signed in with. Without it a backup is of little use: after a restore you would have to connect every device again. Copy the file into the password manager. **Never** generate it again for a running server.
:::

::: details No release yet?
Until there is a release, you build one on a laptop. You need `git`, `rsync`, and Flutter for the web app:

```bash
git clone https://github.com/wuselwall/wuselwall-app.git && cd wuselwall-app
scripts/build-server-release.sh 0.1.0              # without Flutter: --skip-web
scp dist/wuselwall-server-0.1.0.tar.gz server:     # then on the server: tar xzf …
```
:::

## 2. Connecting the app

The web app at `https://web.example.org` reads the server address from your
installation. You do not build an address or key into the app.
On loading, it uses the current configuration even if the browser has saved an
old server address. Offline, it uses the last saved configuration. If the server
address has changed, sign in again.

Open the setup link printed by the installation in your browser, or scan its QR
code. It contains both the server and the setup code. WuselWall remembers the
code during email sign-in so you do not enter it again on **New family**
([Creating a new family](/en/guide/setup#_2-creating-a-new-family)).

You can still type `api.example.org` into **Which server?**. A QR code containing
only the server address, for example from an older installation, does not carry a
setup code. In that case, enter the code from the installation once on **New family**.

`./wuselwall setup-token` gives a new setup code as long as no family exists yet.
Do not publish the code or the setup link.

## 3. Backups

One line in the server's crontab (`crontab -e`, or your NAS's task scheduler) backs up the whole database every night:

```txt
30 3 * * * BACKUP_DIR=/srv/backups/wuselwall /path/to/wuselwall/wuselwall backup nightly
```

The tool checks every backup and keeps 14 days. Without `BACKUP_DIR` they go to `backups/` next to the tool; a different disk than the database's is better. How to get the backups out of the house as well is in the [Extras](/en/server/extras#off-site-backup), how to restore one under [Restoring a backup](/en/server/restore).

## Changing the email language {#email-language}

```bash
./wuselwall language en
```

`de`, `en`, `fr` and `es` are allowed. The tool writes `MAIL_LANGUAGE` to `stack/.env`, selects the matching subjects and mail templates and restarts only sign-in and functions. Existing keys are kept, and the chosen language survives later updates. Older installations without a value count as German. For a server installed from a repository checkout, change it after deployment with `scripts/remote-stack.sh language en`.

## Updates

```bash
./wuselwall update 1.1.0
```

The tool backs up the database first, downloads the new version, restarts the stack and applies the database changes. Server, web app and nightly jobs are then on the same version.

Coming from a version with sign-in through Apple or Google? Read [Updating from a version with Apple and Google sign-in](/en/server/extras#retiring-social-sign-in) first.

::: warning No automatic updates for the stack
Keep every auto-updater (Watchtower, a NAS's automatic container updates) away from WuselWall's containers. Updates come with `wuselwall update`, in a tested combination.
:::

## Useful commands

| Command | What it does |
|---|---|
| `./wuselwall status` | Shows whether every service is running |
| `./wuselwall logs auth` | One service's logs (`db`, `auth`, `rest`, `realtime`, `functions`, `caddy`) |
| `./wuselwall backup` | Backs up now |
| `./wuselwall setup-token` | A new setup token, as long as there is no family |
| `./wuselwall compose …` | Any Docker Compose command for the stack |

Supabase's admin interface (Studio) is switched off. If you want it, install with `--studio` and open it through an SSH tunnel: `ssh -L 54421:172.17.0.1:54421 server`, then `http://127.0.0.1:54421`. User and password are in `stack/.env` under `DASHBOARD_USERNAME` and `DASHBOARD_PASSWORD`.

## Your own web server instead of Caddy

If the server already runs a web server (nginx, Traefik, Nginx Proxy Manager), install without `--caddy`. The stack then listens only on `172.17.0.1:54421`, Docker's address. Your web server needs:

- for `api.example.org`, the paths `/auth/v1/`, `/rest/v1/`, `/realtime/v1/` (with WebSockets) and `/functions/v1/` to `http://172.17.0.1:54421`, plus `/.well-known/wuselwall.json` to `http://172.17.0.1:54421/functions/v1/server-info`. Everything else gets a 404, `/rest/v1/` without a further path included.
- for `web.example.org`, the files from `stack/volumes/web`, unknown paths to `index.html`, and the same forwarding for `/.well-known/wuselwall.json`.

`stack/volumes/caddy/Caddyfile` serves as a template. If your web server runs on another device, set `GATEWAY_BIND` in `stack/.env` to an address it can reach, and restart with `./wuselwall compose up -d`.
