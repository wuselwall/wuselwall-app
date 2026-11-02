#!/usr/bin/env bash
# Backup of the WuselWall database, run ON the server (specs/10#backups): nightly from cron
# with `server/wuselwall backup`, on demand with scripts/remote-backup.sh.
#
# BACKUP_DIR (required) is where the dumps go. Optional settings in the file BACKUP_ENV
# (chmod 600):
#   RESTIC_REPOSITORY=b2:bucket:wuselwall   RESTIC_PASSWORD=...   (+ B2_ACCOUNT_ID/KEY, ...)
#   HEALTHCHECK_URL=https://hc-ping.com/<uuid>
#   BACKUP_AGE_RECIPIENT=age1...      encrypt each file to this age public key (needs `age`)
#   BACKUP_PASSPHRASE=...             or: encrypt each file with this passphrase (openssl)
#
# The dumps hold everything: password hashes, sessions, second-factor secrets, the jobs'
# secret. They are readable by their owner only, in a directory only the owner can enter, and
# with one of the two settings above they are encrypted as well, so that a backup share
# others can read shows nothing (security review 2026-11-01, F26). age is the better choice:
# its recipient key cannot decrypt, so the server holds nothing that opens old backups.
# Restoring an encrypted dump: docs/server/restore.
set -euo pipefail

# Before anything is created: files and directories for the owner only.
umask 077

DB=${DB_CONTAINER:-supabase-db}
OUT=${BACKUP_DIR:?set BACKUP_DIR}
KEEP_DAYS=${KEEP_DAYS:-14}
LABEL=${1:-nightly}
ENV_FILE=${BACKUP_ENV:-}
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then . "$ENV_FILE"; fi

if [ -n "${BACKUP_AGE_RECIPIENT:-}" ] && [ -n "${BACKUP_PASSPHRASE:-}" ]; then
  echo "backup: set BACKUP_AGE_RECIPIENT or BACKUP_PASSPHRASE, not both" >&2
  exit 2
fi
if [ -n "${BACKUP_AGE_RECIPIENT:-}" ] && ! command -v age > /dev/null; then
  echo "backup: BACKUP_AGE_RECIPIENT is set but age is not installed (apt install age)" >&2
  exit 2
fi

STAMP=$(date +%F-%H%M)
mkdir -p "$OUT"
# A directory made by an earlier version (or by hand) may be open to others: close it.
if [ -n "$(find "$OUT" -maxdepth 0 -perm /077)" ]; then
  chmod 700 "$OUT"
  echo "backup: $OUT was readable by others; it is now 0700"
fi

# encrypt <file>: replaces the file with its encrypted copy (.age or .enc) and prints the
# new name; without either setting it leaves the file as it is. It runs inside `$(…)`, where
# bash ignores `set -e`: the plain file is removed only after an explicit check.
encrypt() {
  local file=$1
  if [ -n "${BACKUP_AGE_RECIPIENT:-}" ]; then
    age -r "$BACKUP_AGE_RECIPIENT" -o "$file.age" "$file" && [ -s "$file.age" ] \
      || { echo "backup: age could not encrypt $file" >&2; exit 1; }
    rm -f "$file"
    echo "$file.age"
  elif [ -n "${BACKUP_PASSPHRASE:-}" ]; then
    # The passphrase reaches openssl through its environment, never its command line.
    WW_BACKUP_PASSPHRASE=$BACKUP_PASSPHRASE openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt \
      -pass env:WW_BACKUP_PASSPHRASE -in "$file" -out "$file.enc"
    # Decrypting it once proves the copy is complete and the passphrase is the one set.
    WW_BACKUP_PASSPHRASE=$BACKUP_PASSPHRASE openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
      -pass env:WW_BACKUP_PASSPHRASE -in "$file.enc" | cmp -s - "$file" \
      || { echo "backup: the encrypted copy of $file does not decrypt to it" >&2; exit 1; }
    rm -f "$file"
    echo "$file.enc"
  else
    echo "$file"
  fi
}

# Roles first (Supabase relies on its own roles), then the whole database incl. auth.
docker exec "$DB" pg_dumpall -U postgres --roles-only > "$OUT/roles-$STAMP-$LABEL.sql"
docker exec "$DB" pg_dump -U postgres --format=custom postgres > "$OUT/db-$STAMP-$LABEL.dump"
# A dump that pg_restore cannot list is not a backup.
docker exec -i "$DB" pg_restore --list < "$OUT/db-$STAMP-$LABEL.dump" > /dev/null
ROLES=$(encrypt "$OUT/roles-$STAMP-$LABEL.sql")
DUMP=$(encrypt "$OUT/db-$STAMP-$LABEL.dump")

# Plain and encrypted ones alike (db-….dump, .dump.age, .dump.enc).
find "$OUT" -maxdepth 1 -name 'db-*.dump*' -mtime +"$KEEP_DAYS" -delete
find "$OUT" -maxdepth 1 -name 'roles-*.sql*' -mtime +"$KEEP_DAYS" -delete

if [ -n "${RESTIC_REPOSITORY:-}" ]; then
  # restic from its image: nothing to install on the host. Client-side encrypted.
  docker run --rm -v "$OUT":/data:ro -v "$OUT/.restic-cache":/root/.cache/restic \
    -e RESTIC_REPOSITORY -e RESTIC_PASSWORD -e B2_ACCOUNT_ID -e B2_ACCOUNT_KEY \
    -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
    restic/restic:0.18.0 backup /data --exclude /data/.restic-cache --tag wuselwall
  docker run --rm -v "$OUT/.restic-cache":/root/.cache/restic \
    -e RESTIC_REPOSITORY -e RESTIC_PASSWORD -e B2_ACCOUNT_ID -e B2_ACCOUNT_KEY \
    -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
    restic/restic:0.18.0 forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --prune
fi

if [ -n "${HEALTHCHECK_URL:-}" ]; then
  curl -fsS -m 10 --retry 3 "$HEALTHCHECK_URL" > /dev/null
fi

echo "backup ok: $DUMP ($(du -h "$DUMP" | cut -f1)), roles: $(basename "$ROLES")"
