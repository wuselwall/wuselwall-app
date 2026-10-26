# A rented server (Hetzner and others)

The middle way between Supabase and a machine at home: you rent a small Linux server from a European provider, and WuselWall sets itself up at the first boot. You need no machine running at home, no open ports in your router, and no accounts at GitHub or Supabase. The data lives with a provider of your choice in Europe, on a server that is yours alone.

Technically this is the same Docker stack as [at home](/en/server/home-server). Everything on that page (connecting the app, backups, updates, the email language, the commands) applies here too. This page only describes how the server comes to you.

## What you need

- An account with a provider that offers **cloud-init** (a selection below); such a server costs roughly **€6–25 a month** (as of October 2026).
- A **domain** with two names, `api.` and `web.`, about €1–2 a month.
- An **SSH key** on your laptop (`ssh-keygen` if you have none yet).
- A **mail provider** for the sign-in codes, as for every WuselWall server ([Extras](/en/server/extras#email)).

## Providers

The three in the table are European companies with data centres in Europe; each offers a GDPR data-processing agreement and, when you create a server, a field for the cloud-init file. WuselWall needs **2 vCPU and 4 GB of memory**, 8 GB with [text recognition](/en/server/extras#text-recognition).

::: info Independent, prices for reference only
WuselWall is not affiliated with, sponsored or endorsed by any of the companies named on this page, and gets nothing for naming them; the links are plain links, not affiliate links. The list is a selection in no particular order, not a ranking and not complete. The price range is a rough figure for reference, as of October 2026, and not an offer; prices change, and depending on the provider they are shown with or without VAT. Only the provider's own price list and terms count. Product and company names are trademarks of their owners.
:::

| Provider | Seat, data centres | Fitting size | Field for the file |
|---|---|---|---|
| [Hetzner Cloud](https://www.hetzner.com/cloud) | Germany; Falkenstein, Nuremberg, Helsinki | CX23 (2 vCPU, 4 GB); when it is sold out, CPX22 | **Cloud config**; the guide below |
| [Scaleway](https://www.scaleway.com/) | France; Paris, Amsterdam, Warsaw | DEV1-M (3 vCPU, 4 GB), public IPv4 extra | **Cloud-init**; handy if your mail already goes through Scaleway |
| [IONOS](https://www.ionos.com/) | Germany; choose a data centre in the EU | Cloud Server with 4 GB | **Cloud-Init User Data** under the advanced options; documented for the Cloud Server, not for the VPS |

**Cost:** roughly **€6–25 a month** for a fitting server, depending on provider, size and VAT, plus the domain (as of October 2026). The cheapest sizes are sold out at times (at Hetzner, the whole cheapest line on 25 October 2026); the next size up costs about three times as much. The provider's price list counts.

**Without a cloud-init field:** [netcup](https://www.netcup.com/), [OVHcloud](https://www.ovhcloud.com/) and [Infomaniak](https://www.infomaniak.com/) (Switzerland, Geneva; Swiss data-protection law) also rent fitting servers in Europe but document no such field. There you create a server with Ubuntu and install over SSH exactly as [at home](/en/server/home-server).

**Where does the data live?** On your own server at the provider. The provider supplies hardware, power and network; like any host it could technically reach the machine, and its data-processing agreement forbids it to use your data. The connections to your devices are encrypted, and only WuselWall reads your database. Unlike Supabase Inc. (USA), the provider is a European company subject to European law, Swiss law for Infomaniak.

## At Hetzner, step by step

This guide shows Hetzner because its console has a plain field for cloud-config; it is not a recommendation over the others. Screens and button names are as of October 2026 and may change.

1. **Prepare the file.** Open [`server/cloud-init.yaml`](https://github.com/wuselwall/wuselwall-app/blob/main/server/cloud-init.yaml) on GitHub, copy its content into a text editor and change the one line marked `CHANGE`: the release version from the [releases](https://github.com/wuselwall/wuselwall-app/releases), your two addresses and the email language (`de`, `en`, `fr` or `es`).
2. **Project and key.** In the [Hetzner Cloud Console](https://console.hetzner.cloud/), create a project, say "WuselWall", and add your public SSH key under **Security → SSH keys**.
3. **Create the server.** **Add server**: location Falkenstein, Nuremberg or Helsinki; image **Ubuntu 24.04**; type **CX23** (2 vCPU, 4 GB) under Cost-Optimized, or **CPX22** under Regular Performance if it is sold out; network IPv4 and IPv6; your SSH key; a Hetzner firewall is optional, the file sets one up on the server anyway; at the bottom, paste the prepared content into **Cloud config**. Name it `wuselwall`, for example. Then **Create & Buy now**.
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
