# Restoring a backup

A backup is only worth something once it can be restored. The way below has been run through: server installed, family created, backed up, server deleted with all its data, installed again and restored — everything came back, and the devices stayed signed in. Try it once while nothing is broken: on a second machine or in a virtual machine.

## At home {#at-home}

The `wuselwall` tool restores a backup made by `wuselwall backup` onto a **freshly installed** server. Typical cases: the old server is broken, or WuselWall moves to a new machine.

You need:

- a backup, a `db-….dump` file from the backup directory,
- the **old server's `.env`** from the password manager. With it every device stays signed in, because keys, passwords and addresses are the same.

On the new server:

1. Point the names `api.` and `web.` at the new server (DNS, or port forwarding in the router).
2. Unpack the same or a newer WuselWall version as when [installing](/en/server/home-server#_1-installing), and install with the old `.env`:

   ```bash
   ./wuselwall install --env /path/to/old.env
   ```

   The addresses and `--caddy` are in the old file; the tool doesn't ask for them.
3. Restore the backup:

   ```bash
   ./wuselwall restore /path/to/db-2026-10-14-0330-nightly.dump
   ```

   The tool stops every service but the database, replaces the database with the backup, starts everything again, applies the changes of newer versions and schedules the nightly jobs again. Finally it counts families, members, devices and accounts.
4. Open the app on a phone: it should carry on without signing in again.

::: warning Onto a server with data
On a server that already has a family, `restore` refuses. If you really want an earlier state back, put `WW_RESTORE_OVER_DATA=yes` in front.
:::

Before it replaces anything, the tool always backs up the current state (`db-…-before-restore.dump`), on an empty server too. If it cannot tell whether a family is there, or that backup fails, it stops without changing anything.

**Without the old `.env`** it works too: install normally with `--api` and `--web` and restore the backup. Your data is back, but every device has to sign in or be connected again.

### Encrypted backups {#encrypted}

A backup holds everything, password hashes and the secrets of two-factor codes included. The tool makes it readable by its owner only, in a directory only the owner can open. If the backups sit on a share others on the network can read, or you want them protected anyway, it encrypts every file when the `backup.env` next to the tool (`chmod 600`) holds one of these lines:

```bash
# Recommended: with age (apt install age). The server only knows the public key.
BACKUP_AGE_RECIPIENT=age1…
# Or with a long passphrase (openssl, already there):
BACKUP_PASSPHRASE='…'
```

Make the age key once on your laptop with `age-keygen -o wuselwall-backup.key`; the line `public key: age1…` goes into `backup.env`, the file `wuselwall-backup.key` into the password manager and **not** onto the server. The passphrase belongs in the password manager too. Without the key or the passphrase an encrypted backup is worthless.

The backups are then called `db-….dump.age` or `db-….dump.enc`. To restore one, decrypt it first and give `restore` the decrypted file:

```bash
age -d -i /path/to/wuselwall-backup.key -o db-2026-10-14-0330-nightly.dump db-2026-10-14-0330-nightly.dump.age
# or, with the passphrase (openssl asks for it):
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in db-2026-10-14-0330-nightly.dump.enc -out db-2026-10-14-0330-nightly.dump
```

Delete the decrypted file afterwards. The restore drill (`infra/backup/restore-drill.sh`) reads encrypted backups directly, with `BACKUP_PASSPHRASE` or with `BACKUP_AGE_IDENTITY=/path/to/wuselwall-backup.key`.

## At Supabase {#at-supabase}

- **On Pro:** in the dashboard under **Database → Backups**, pick one of the last 7 days and restore it. The project is unreachable for a few minutes.
- **A copy of your own:** with the Supabase CLI, pull a copy to your computer about once a month. Supabase explains how, and how to restore it, in [Backup and Restore using the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore). Store the files encrypted: they contain everything.

Moving between Supabase and a server at home is possible with these copies, but there is no step-by-step guide for it.
