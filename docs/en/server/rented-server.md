# A rented server (Hetzner and others)

The middle way between Supabase and a machine at home: you rent a small Linux server from a European provider, and WuselWall sets itself up at the first boot. You need no machine running at home, no open ports in your router, and no accounts at GitHub or Supabase. The data lives with a provider of your choice in Europe, on a server that is yours alone.

Technically this is the same Docker stack as [at home](/en/server/home-server). Everything on that page (connecting the app, backups, updates, the email language, the commands) applies here too. This page only describes how the server comes to you.

## What you need

- An account with a provider that offers **cloud-init** (a selection below); such a server costs about **€4–8 a month**.
- A **domain** with two names, `api.` and `web.`, about €1–2 a month.
- An **SSH key** on your laptop (`ssh-keygen` if you have none yet).
- A **mail provider** for the sign-in codes, as for every WuselWall server ([Extras](/en/server/extras#email)).

## Providers

All of these are European companies with data centres in Europe and a GDPR data-processing agreement in their contract documents. Prices and availability change; check them with the provider. WuselWall needs **2 vCPU and 4 GB of memory**, 8 GB with [text recognition](/en/server/extras#text-recognition).

| Provider | Seat, data centres | Fitting size | Note |
|---|---|---|---|
| [Hetzner Cloud](https://www.hetzner.com/cloud) | Germany; Falkenstein, Nuremberg, Helsinki | 2 vCPU, 4 GB, from about €4–6, plus €0.50 for an IPv4 address | The guide below. The cheap sizes are sold out at times |
| [netcup](https://www.netcup.com/) | Germany; Nuremberg, Vienna | VPS with 4 GB, about €4–6 | Cheap; mind the contract term |
| [IONOS](https://www.ionos.com/) | Germany | VPS with 4 GB, about €5–8 | |
| [Scaleway](https://www.scaleway.com/) | France; Paris, Amsterdam, Warsaw | DEV1-M or similar, about €8 | Handy if your mail already goes through Scaleway |
| [OVHcloud](https://www.ovhcloud.com/) | France; Gravelines, Strasbourg and others | VPS with 4 GB, about €5–7 | |
| [Infomaniak](https://www.infomaniak.com/) | Switzerland; Geneva | VPS or Public Cloud with 4 GB, about €6–10 | Swiss data-protection law |

**Where does the data live?** On your own server at the provider. The provider supplies hardware, power and network and sees the encrypted connection, not its content; only WuselWall reads your database. Unlike Supabase, the provider is a European company, and only European law applies.

## At Hetzner, step by step

1. **Prepare the file.** Open [`server/cloud-init.yaml`](https://github.com/wuselwall/wuselwall-app/blob/main/server/cloud-init.yaml) on GitHub, copy its content into a text editor and change the one line marked `CHANGE`: the release version from the [releases](https://github.com/wuselwall/wuselwall-app/releases), your two addresses and the email language (`de`, `en`, `fr` or `es`).
2. **Project and key.** In the [Hetzner Cloud Console](https://console.hetzner.cloud/), create a project, say "WuselWall", and add your public SSH key under **Security → SSH keys**.
3. **Create the server.** **Add server**: location Falkenstein, Nuremberg or Helsinki; image **Ubuntu 24.04**; type a shared server with **4 GB**; network IPv4 and IPv6; your SSH key; a Hetzner firewall is optional, the file sets one up on the server anyway; at the bottom, paste the prepared content into **Cloud config**. Name it `wuselwall`, for example. Then **Create & Buy now**.
4. **DNS.** The console shows the new server's IPv4 address right away. At your domain provider, add two A records, `api` and `web`, pointing at it (and AAAA records with the IPv6 address if you like). Caddy keeps trying until the names resolve.
5. **Read the result.** After 5–10 minutes:

   ```bash
   ssh root@<ip> cat /srv/wuselwall/install.log
   ```

   It shows the server address, the setup link with its QR code and the one-time setup code. Copy `/srv/wuselwall/stack/.env` into your password manager right away ([why](/en/server/home-server#_1-installing)).
6. **Continue as at home:** [connect the app](/en/server/home-server#_2-connecting-the-app) and set up the [backup](/en/server/home-server#_3-backups), plus an [off-site backup](/en/server/extras#off-site-backup) from the start, because a rented server has one disk. Hetzner's own backups (about 20 % extra) snapshot the whole disk and are a good addition, but they do not replace WuselWall's backup.

At other providers the field is called **User data**, **Cloud-init** or **Startup script**; the steps are the same.

## Day to day

The commands run over SSH in `/srv/wuselwall`, as [at home](/en/server/home-server#useful-commands):

| | Command |
|---|---|
| Update to a new version | `./wuselwall update 1.1.0` |
| Back up now | `./wuselwall backup` |
| Is everything running? | `./wuselwall status` |

Ubuntu installs security updates by itself. After a kernel update, reboot the server once (`reboot`); the stack comes back up on its own.

## Moving

From the rented server to home or back: take a backup, install at the new place with the old `stack/.env`, restore the backup ([Restoring a backup](/en/server/restore)). If the addresses stay the same, every device stays signed in.
