# Your own server: overview

WuselWall is not an online service. Every family has **its own server**, and the app talks only to that server. That is where your appointments, tasks and lists live. We never see them, and we run no server for other families.

These pages are for the person who sets up the server. You don't need to program. The Supabase way needs nothing but a browser. For a server at home you should be somewhat at home with SSH and Docker.

::: warning Status, October 2026
- **Works:** setting up a server at Supabase or at home. At its first start the app asks which server to connect to, and it can show an example family without any server.
- **Not yet:** WuselWall is not publicly in the **App Store** or on **Google Play** yet. Until it is, you use the **web app** in the browser, on a phone also as an icon on the home screen.
- **Not yet:** invitation links and push notifications.
:::

## One server, one family

A WuselWall server belongs to exactly **one household**. Once the first family exists, nobody can create a second one. If friends want WuselWall too, they set up a server of their own. At Supabase, that is simply a second project.

## Two ways

| | [At Supabase](/en/server/supabase-cloud) | [At home](/en/server/home-server) |
|---|---|---|
| **What you need** | An account at Supabase and one at GitHub, nothing else | A machine that runs all the time (NAS, mini PC, rented server) with Docker, and a domain of your own |
| **Setting up** | In the browser, about 20 minutes | One command on the server, plus the domain and the router |
| **Where the data lives** | With Supabase Inc. (USA), in a data centre you choose, e.g. Frankfurt or Zurich | On your own device |
| **Cost** | Free to try, about USD 25 a month for everyday use | Electricity and the domain, about €1–2 a month |
| **Updates and backups** | Supabase maintains the server and, on Pro, backs up daily. New WuselWall versions take one click | You, one command each |

Our advice: if you already run a NAS or a home server with Docker, choose the **server at home**. Everyone else starts with **Supabase**. Moving later is possible ([Restoring a backup](/en/server/restore)).

## What you need and what you don't

As little as possible is required. Everything in the second table can be left out or added later.

### Required

| What | What for |
|---|---|
| **A Supabase server**: a project at Supabase, or the Docker stack at home | Database, sign-in, live updates and WuselWall's server functions |
| **HTTPS** | The apps talk to the server only over an encrypted connection. Supabase has it already; at home, the bundled web server Caddy fetches it automatically |
| **Scheduled jobs** | Every night they create the next 14 days of tasks and close the previous day; once a week they fetch the holidays, and every hour the subscribed calendars. They run inside the database; the installation sets them up |
| **A backup** | The database is the one thing that cannot be rebuilt |

### Optional

| What | Without it |
|---|---|
| **The web app** | Only needed until the apps are in the stores, or for the laptop. At home the server brings it along; at Supabase, GitHub publishes it for you |
| **Sending email (SMTP)** | WuselWall sends **no** email today. Accounts are created in the app with an email address and a password, without a confirmation mail ([Extras](/en/server/extras#email)) |
| **Sign in with Apple or Google** | Everyone signs in with email and password. Can be added, but it takes a lot of work ([Extras](/en/server/extras#apple-and-google)) |
| **Public and school holidays** | The server fetches them once a week from [OpenHolidays](https://www.openholidaysapi.org/), sending only country codes. Without internet access on the server, they are missing from the week board ([Extras](/en/server/extras#holidays)) |
| **Subscribed calendars** | If you subscribe to club or town calendars, the server fetches them every hour from the addresses you entered. Without subscriptions it fetches nothing |
| **Calendar subscriptions for Outlook, Google and iPhone** | Work only if the server can be reached from the internet |
| **Passkeys** | Not available on self-hosted servers. Everyone signs in with a password, ideally with a two-factor code |
| **Off-site backup, monitoring** | See [Extras](/en/server/extras#off-site-backup) |

WuselWall needs **no** accounts with Google, Apple, Firebase or an analytics service, and no captcha.

## What comes next

Once the server runs, open the app and enter the server's address; for Supabase, the project ID is enough. Then you found the family with the **setup token** ([Start a new family](/en/guide/setup#_3-start-a-new-family-once)). After that you connect the other devices: the QR code under **Settings → Add device** carries the server too ([Signing in and connecting](/en/guide/setup)).
