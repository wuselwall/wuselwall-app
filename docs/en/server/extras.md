# Server extras

Everything on this page is **optional**. WuselWall runs without it. Each extra brings in another service that learns something about you, so take only what you really need.

Commands for a server at home run in the directory of the `wuselwall` tool ([Server at home](/en/server/home-server)).

## Email {#email}

**Not needed today.** WuselWall sends no email yet. Accounts are created through invitations, with an email address and a password, without a confirmation mail.

**Sign-in codes by email** come later. The server then needs an SMTP service, a provider that sends mail for it. A mailbox at your normal mail provider won't do; use a service for *transactional* mail, such as Scaleway Transactional Email in the EU (300 mails a month for free). The provider sees the email addresses and the codes. So that the mails don't land in spam, add the records the provider names to your domain (SPF, DKIM, DMARC).

**At home:** put `SMTP_HOST`, `SMTP_PORT` (usually `587`), `SMTP_USER`, `SMTP_PASS` and, as the sender, `SMTP_ADMIN_EMAIL` into `stack/.env`, in single quotes like the other values. Then:

```bash
./wuselwall compose up -d auth
```

**At Supabase:** **Authentication → Emails → SMTP Settings**, with the same details.

## Sign in with Apple and Google {#apple-and-google}

**Our advice: leave it out.** Email and password plus the two-factor code ([Security](/en/settings/security)) keep an account just as safe.

Technically it works on any server, but only through the sign-in window in the browser, with **your own** Apple and Google credentials:

- **Apple** requires a membership in the Apple Developer Program (USD 99 a year), a *Services ID* and a key. The secret made from them **expires every six months** and must be renewed, or signing in with Apple stops working.
- **Google** requires a Google Cloud project with an OAuth consent screen and an OAuth client of type *Web*.

The return address for both is `https://api.example.org/auth/v1/callback` (at Supabase `https://<project-id>.supabase.co/auth/v1/callback`). At home the values go into `stack/.env` (`APPLE_ENABLED`, `APPLE_CLIENT_IDS`, `APPLE_SECRET`, `GOOGLE_ENABLED`, `GOOGLE_CLIENT_IDS`, `GOOGLE_CLIENT_SECRET`, then `./wuselwall compose up -d auth`); at Supabase under **Authentication → Providers**. The app asks the server what it offers and shows the buttons by itself.

Signing in directly on the phone (without a browser window) and passkeys are not available on self-hosted servers: a sign-in token that Apple or Google issues for the app should never reach a server that could use it elsewhere.

## Public and school holidays {#holidays}

For the week board, the server fetches the public and school holidays of the countries you chose in the settings, once a week. The source is the free [OpenHolidays API](https://www.openholidaysapi.org/). The server sends only country codes, nothing about your family, and the apps never ask OpenHolidays themselves. If the server can't reach the internet, the holidays are missing; everything else keeps working.

## Off-site backup {#off-site-backup}

A backup on the same server helps after a mistake, but not after a fire, a theft or a dead disk. `wuselwall backup` can also copy every backup **encrypted** to cloud storage, with [restic](https://restic.net/), for example to Backblaze B2 or any S3 storage. The provider sees only encrypted data.

Create the file `backup.env` next to the tool (`chmod 600 backup.env`):

```bash
RESTIC_REPOSITORY=b2:<bucket>:wuselwall
RESTIC_PASSWORD=<a long password, also into the password manager>
B2_ACCOUNT_ID=<key id>
B2_ACCOUNT_KEY=<application key>
```

The first time, create the repository: `docker run --rm --env-file backup.env restic/restic:0.18.0 init`. From then on every `wuselwall backup` copies the backup there, the nightly one included.

Without the `RESTIC_PASSWORD`, the backups are worthless. Keep it in the password manager, next to `stack/.env`.

## Monitoring {#monitoring}

Otherwise nobody notices a backup that stopped six weeks ago. Two free services help:

- **[healthchecks.io](https://healthchecks.io/):** create a check and put its address into `backup.env` as `HEALTHCHECK_URL=https://hc-ping.com/…`. After every successful backup the tool reports there. If the report doesn't come, you get an email.
- **An uptime monitor** (for example Uptime Kuma on another device, or a free service) calls `https://api.example.org/.well-known/wuselwall.json`. If the server answers there, gateway, database and sign-in are running.
