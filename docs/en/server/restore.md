# Restoring a backup

A backup is only worth something once it can be restored. The way below has been run through: server installed, family created, backed up, server deleted with all its data, installed again and restored — everything came back, and the devices stayed signed in. Try it once while nothing is broken: on a second machine or in a virtual machine.

## At home or rented {#at-home}

The `wuselwall` tool restores a backup made by `wuselwall backup` onto a **freshly installed** server. Typical cases: the old server is broken, or WuselWall moves to a new machine.

You need:

- a backup, a `db-….dump` file from the backup directory,
- the **old server's `.env`** from the password manager. With it every device stays signed in, because keys, passwords and addresses are the same.

On the new server:

1. Point your domain at the new server (DNS, or port forwarding in the router).
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
On a server that already has a family, `restore` refuses. If you really want an earlier state back, put `WW_RESTORE_OVER_DATA=yes` in front; the tool then backs up the current state first.
:::

**Without the old `.env`** it works too: install normally with `--api` and `--web` and restore the backup. Your data is back, but every device has to sign in or be connected again.
