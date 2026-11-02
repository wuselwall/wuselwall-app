#!/usr/bin/env bash
# Restore drill, run ON the server (specs/10#backups): restores the newest dump into a
# scratch database next to the live one, counts rows in the main tables, drops it again.
# The live database is only read. Usage: restore-drill.sh [dump-file]
#
# Encrypted dumps (backup.sh with BACKUP_PASSPHRASE or BACKUP_AGE_RECIPIENT) are decrypted on
# the way into pg_restore, never onto the disk: .enc with BACKUP_PASSPHRASE, .age with the
# identity file named by BACKUP_AGE_IDENTITY (both may come from BACKUP_ENV).
set -euo pipefail
umask 077

DB=${DB_CONTAINER:-supabase-db}
OUT=${BACKUP_DIR:?set BACKUP_DIR}
ENV_FILE=${BACKUP_ENV:-}
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then . "$ENV_FILE"; fi
# ls fails when one of the three patterns matches nothing, which is the usual case.
DUMP=${1:-$({ ls -t "$OUT"/db-*.dump "$OUT"/db-*.dump.enc "$OUT"/db-*.dump.age 2> /dev/null || true; } | head -1)}
[ -n "$DUMP" ] || { echo "no db-*.dump in $OUT" >&2; exit 1; }
SCRATCH=restore_drill

# The dump on stdout, decrypted when it is encrypted.
read_dump() {
  case $DUMP in
    *.enc)
      WW_BACKUP_PASSPHRASE=${BACKUP_PASSPHRASE:?set BACKUP_PASSPHRASE to read $DUMP} \
        openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -pass env:WW_BACKUP_PASSPHRASE -in "$DUMP" ;;
    *.age) age -d -i "${BACKUP_AGE_IDENTITY:?set BACKUP_AGE_IDENTITY to the age identity file for $DUMP}" "$DUMP" ;;
    *) cat "$DUMP" ;;
  esac
}

echo "restoring $DUMP into $SCRATCH"
# -i only where input is given explicitly: the script itself may arrive on stdin (ssh bash -s).
sql() { docker exec "$DB" psql -U postgres -X -q -v ON_ERROR_STOP=1 -c "$1" < /dev/null; }

sql "drop database if exists $SCRATCH"
sql "create database $SCRATCH"
trap 'sql "drop database if exists $SCRATCH"' EXIT

# Roles already exist in this cluster, so only the database is restored. supabase_admin is
# the superuser here (Supabase's postgres role is not); objects keep their owners.
read_dump | docker exec -i "$DB" pg_restore -U supabase_admin --dbname="$SCRATCH" \
  2> "$OUT/restore-drill.log" || true
echo "pg_restore errors: $(grep -c '^pg_restore: error' "$OUT/restore-drill.log" || true) (details in $OUT/restore-drill.log)"

docker exec "$DB" psql -U supabase_admin -X -q -t -A -F ' ' -d "$SCRATCH" -c "
  select 'households', count(*) from app.household
  union all select 'profiles', count(*) from app.profile
  union all select 'devices', count(*) from app.device
  union all select 'auth users', count(*) from auth.users
  union all select 'shopping items', count(*) from app.shopping_item
  union all select 'audit rows', count(*) from app.audit_log" < /dev/null
echo "restore drill done — write the date into specs/10#backups"
