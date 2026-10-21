# Server extras

Everything on this page except **sending email** is **optional**. WuselWall runs without it. Each extra brings in another service that learns something about you, so take only what you really need.

Commands for a server at home run in the directory of the `wuselwall` tool ([Server at home](/en/server/home-server)).

## Email {#email}

**Needed for now.** Whoever signs in for the first time confirms their address with a **code by email**, and only then can set a password. Without sending email the code never arrives, and nobody can start or join a family. A server without any email, with a password from the start, is planned.

**Language of the emails:** during setup you choose one language — German, English, French or Spanish (default: German). That language is used for the subject and body of every sign-in and confirmation email, whatever the device language is. You can change it later with `./wuselwall language de|en|fr|es` ([Server at home](/en/server/home-server#email-language)).

For this the server needs an SMTP service, a provider that sends mail for it. A mailbox at your normal mail provider won't do; use a service for *transactional* mail, such as Scaleway Transactional Email in the EU (300 mails a month for free). The provider sees the email addresses and the codes. So that the mails don't land in spam, add the records the provider names to your domain (SPF, DKIM, DMARC).

**At home:** put `SMTP_HOST`, `SMTP_PORT` (usually `587`), `SMTP_USER`, `SMTP_PASS` and, as the sender, `SMTP_ADMIN_EMAIL` into `stack/.env`, in single quotes like the other values. Then:

```bash
./wuselwall compose up -d auth
```

**At Supabase:** **Authentication → Emails → SMTP Settings**, with the same details. Supabase's built-in email is meant for trying things out and sends only a few mails an hour.

The server release and the **deploy-supabase** workflow configure both the first confirmation email and later sign-in emails with a **six-digit code**, in the chosen email language. A Scaleway hook is not required. Enter the code in the app you already have open. If you only receive a link, update the server or rerun the workflow from the updated repository, then request a fresh code; an old email does not change.

## Updating from a version with Apple and Google sign-in {#retiring-social-sign-in}

Until October 2026 you could also sign in to WuselWall with Apple or Google. Anyone who did now signs in with an email code sent to their account's address. The account and the family stay the same.

**Check first, then update.** If someone signed in with Apple and **"Hide My Email"**, their account's address is `…@privaterelay.appleid.com`. A code sent there only arrives if your sender address is registered with Apple for forwarding. Sort that out before the update. If no code arrives, hold the update: otherwise that person cannot sign in again after their next sign-out.

**What the update does by itself:**

- **At home** (`wuselwall update`): every Apple and Google value (`APPLE_…`, `GOOGLE_CLIENT_…`) and the app's old return address leave `stack/.env`, and the old `apple-token` function is gone. The tool names what it removes, never the values.
- **At Supabase** (the **deploy-supabase** workflow): the step **Retire social sign-in** switches off Apple, Google and account linking, removes the app's old return address (other entries, such as those for invitations, stay), deletes the `apple-token` function and the `APPLE_…` secrets, and then checks all of it. If anything fails, the workflow stops.

**Check afterwards:** someone who used to sign in with Apple or Google asks for a code by email on a **second** device and signs in with it. The first device stays signed in. Nobody should sign out just to try it.

**Only then clean up**, at Google and Apple:

- **Google:** delete only the OAuth clients that existed just for WuselWall sign-in. The Google Cloud project, the Play Console and anything other apps use stay. When in doubt: keep it.
- **Apple:** you no longer need the Services ID, the Sign in with Apple key or the reminder for the six-monthly client secret. **Keep** the senders registered for forwarding as long as there are accounts with a `privaterelay` address.

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
