# Server extras

Everything on this page except **sending email** is **optional**. WuselWall runs without it. Each extra brings in another service that learns something about you, so take only what you really need.

Commands for a server at home run in the directory of the `wuselwall` tool ([Server at home](/en/server/home-server)).

## Email {#email}

**Needed for now.** Whoever signs in for the first time confirms their address with a **code by email**, and only then can set a password. Without sending email the code never arrives, and nobody can start or join a family. A server without any email, with a password from the start, is planned.

For this the server needs an SMTP service, a provider that sends mail for it. A mailbox at your normal mail provider won't do; use a service for *transactional* mail, such as Scaleway Transactional Email in the EU (300 mails a month for free). The provider sees the email addresses and the codes. So that the mails don't land in spam, add the records the provider names to your domain (SPF, DKIM, DMARC).

**At home:** put `SMTP_HOST`, `SMTP_PORT` (usually `587`), `SMTP_USER`, `SMTP_PASS` and, as the sender, `SMTP_ADMIN_EMAIL` into `stack/.env`, in single quotes like the other values. Then:

```bash
./wuselwall compose up -d auth
```

**At Supabase:** **Authentication → Emails → SMTP Settings**, with the same details. Supabase's built-in email is meant for trying things out and sends only a few mails an hour.

## Revoking Apple access (accounts from before, only) {#apple-revocation}

WuselWall no longer offers sign-in with Apple or Google. Only if your server still has accounts from before that change does it need access to Apple: when such an account is deleted, WuselWall revokes its Apple access there. For that the server needs just these five values in `stack/.env`: `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_ID` and `APPLE_TOKEN_KEY`. Without them the server cannot revoke access at Apple. Never change `APPLE_TOKEN_KEY`: the stored Apple tokens are encrypted with it.

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
