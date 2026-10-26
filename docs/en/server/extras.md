# Server extras

Everything on this page is **optional**. WuselWall runs without it. Each extra brings in another service that learns something about you, so take only what you really need.

Commands for a server at home run in the directory of the `wuselwall` tool ([Server at home](/en/server/home-server)).

## Email {#email}

Email is optional: without it, everyone signs in with a password. How to send the sign-in codes by email, Gmail included, is on its own page: [Email](/en/server/email).

## Updating from a version with Apple and Google sign-in {#retiring-social-sign-in}

Until October 2026 you could also sign in to WuselWall with Apple or Google. Anyone who did now signs in with an email code sent to their account's address. The account and the family stay the same.

**Check first, then update.** If someone signed in with Apple and **"Hide My Email"**, their account's address is `…@privaterelay.appleid.com`. A code sent there only arrives if your sender address is registered with Apple for forwarding. Sort that out before the update. If no code arrives, hold the update: otherwise that person cannot sign in again after their next sign-out.

**What the update does by itself:** with `wuselwall update`, every Apple and Google value (`APPLE_…`, `GOOGLE_CLIENT_…`) and the app's old return address leave `stack/.env`, and the old `apple-token` function is gone. The tool names what it removes, never the values.

**Check afterwards:** someone who used to sign in with Apple or Google asks for a code by email on a **second** device and signs in with it. The first device stays signed in. Nobody should sign out just to try it.

**Only then clean up**, at Google and Apple:

- **Google:** delete only the OAuth clients that existed just for WuselWall sign-in. The Google Cloud project, the Play Console and anything other apps use stay. When in doubt: keep it.
- **Apple:** you no longer need the Services ID, the Sign in with Apple key or the reminder for the six-monthly client secret. **Keep** the senders registered for forwarding as long as there are accounts with a `privaterelay` address.

## Public and school holidays {#holidays}

For the week board, the server fetches the public and school holidays of the countries you chose in the settings, once a week. The source is the free [OpenHolidays API](https://www.openholidaysapi.org/). The server sends only country codes, nothing about your family, and the apps never ask OpenHolidays themselves. If the server can't reach the internet, the holidays are missing; everything else keeps working.

## Text recognition for timetables {#text-recognition}

With text recognition the app can read in a photographed timetable or the school's PDF ([Reading in a timetable](/en/school/#reading-in-a-timetable)); a PDF's text is read directly, a scanned PDF like a photo. It is a container of its own in the stack that runs on your server's CPU only: the photo goes from the phone to your server, the container reads the text, and none of it leaves the house. It needs no internet, no graphics card and about 1 GB of memory; on a small home server a sheet takes a few seconds.

To set it up, in the stack's folder:

1. Add the line `OCR_URL=http://ocr:9003/ocr` to the `.env`.
2. Build and start the container: `docker compose --profile ocr up -d --build`. The first build downloads the recognition models (about 20 MB); after that it runs without internet.
3. Restart the functions so they know the address: `docker compose restart functions`.

The app then offers **Scan a photo** under **Read in…**. Without that line the entry is still there, but the app says the server has no text recognition. Recognition uses RapidOCR with PaddleOCR's PP-OCR models (both Apache-2.0, the same stack the photo manager Immich uses for its text recognition).

With the picture, the app sends its language and the names and short names of your subjects. That way the server reads your words as your subjects. The function accepts photos (JPEG, PNG, WebP, HEIC) and PDF files up to 6 MB, keeps nothing and writes no picture to the log. What the server reads from a sheet, and where it stops, is under [Reading in a timetable](/en/school/#reading-in-a-timetable).

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
