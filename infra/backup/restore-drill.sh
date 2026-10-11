#!/usr/bin/env bash
# Restore drill, run ON the home server (specs/10#backups): restores the newest dump into a
# scratch database next to the live one, counts rows in the main tables, drops it again.
# The live database is only read. Usage: restore-drill.sh [dump-file]
set -euo pipefail

DB=${DB_CONTAINER:-supabase-db}
OUT=${BACKUP_DIR:-/mnt/user/backups/wuselwall}
DUMP=${1:-$(ls -t "$OUT"/db-*.dump | head -1)}
SCRATCH=restore_drill

echo "restoring $DUMP into $SCRATCH"
# -i only where input is given explicitly: the script itself may arrive on stdin (ssh bash -s).
sql() { docker exec "$DB" psql -U postgres -X -q -v ON_ERROR_STOP=1 -c "$1" < /dev/null; }

sql "drop database if exists $SCRATCH"
sql "create database $SCRATCH"
trap 'sql "drop database if exists $SCRATCH"' EXIT

# Roles already exist in this cluster, so only the database is restored. supabase_admin is
# the superuser here (Supabase's postgres role is not); objects keep their owners.
docker exec -i "$DB" pg_restore -U supabase_admin --dbname="$SCRATCH" \
  < "$DUMP" 2> "$OUT/restore-drill.log" || true
echo "pg_restore errors: $(grep -c '^pg_restore: error' "$OUT/restore-drill.log" || true) (details in $OUT/restore-drill.log)"

docker exec "$DB" psql -U supabase_admin -X -q -t -A -F ' ' -d "$SCRATCH" -c "
  select 'households', count(*) from app.household
  union all select 'profiles', count(*) from app.profile
  union all select 'devices', count(*) from app.device
  union all select 'auth users', count(*) from auth.users
  union all select 'shopping items', count(*) from app.shopping_item
  union all select 'audit rows', count(*) from app.audit_log" < /dev/null
echo "restore drill done — write the date into specs/10#backups"
