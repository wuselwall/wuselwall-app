#!/usr/bin/env bash
# Nightly backup of the WuselWall database, run ON the home server (specs/10#backups).
# homeserver: User Scripts plugin, schedule daily. On demand: scripts/remote-backup.sh.
#
# Optional settings in /srv/appdata/wuselwall/backup.env (chmod 600):
#   (not on /boot: the flash drive is often exported over SMB)
#   RESTIC_REPOSITORY=b2:bucket:wuselwall   RESTIC_PASSWORD=...   (+ B2_ACCOUNT_ID/KEY, ...)
#   HEALTHCHECK_URL=https://hc-ping.com/<uuid>
set -euo pipefail

DB=${DB_CONTAINER:-supabase_db_wuselwall}
OUT=${BACKUP_DIR:-/srv/backups/wuselwall}
KEEP_DAYS=${KEEP_DAYS:-14}
LABEL=${1:-nightly}
ENV_FILE=/srv/appdata/wuselwall/backup.env
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

STAMP=$(date +%F-%H%M)
mkdir -p "$OUT"
umask 077

# Roles first (Supabase relies on its own roles), then the whole database incl. auth.
docker exec "$DB" pg_dumpall -U postgres --roles-only > "$OUT/roles-$STAMP-$LABEL.sql"
docker exec "$DB" pg_dump -U postgres --format=custom postgres > "$OUT/db-$STAMP-$LABEL.dump"
# A dump that pg_restore cannot list is not a backup.
docker exec -i "$DB" pg_restore --list < "$OUT/db-$STAMP-$LABEL.dump" > /dev/null

find "$OUT" -name 'db-*.dump' -mtime +"$KEEP_DAYS" -delete
find "$OUT" -name 'roles-*.sql' -mtime +"$KEEP_DAYS" -delete

if [ -n "${RESTIC_REPOSITORY:-}" ]; then
  # restic from its image: nothing to install on homeserver. Client-side encrypted.
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

echo "backup ok: $OUT/db-$STAMP-$LABEL.dump ($(du -h "$OUT/db-$STAMP-$LABEL.dump" | cut -f1))"
