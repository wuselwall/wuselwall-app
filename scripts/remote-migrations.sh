#!/usr/bin/env bash
# Applies the pending supabase/migrations to the home server's database the way
# `supabase migration up` does: each file in one transaction, together with its row in
# supabase_migrations.schema_migrations. Streamed through `docker exec`, so no database
# password leaves the server. Called by scripts/remote-migrate.sh, which dumps first.
set -euo pipefail
cd "$(dirname "$0")/.."
HOST=${WW_HOST:-homeserver}
DB=${DB_CONTAINER:-supabase-db}

psql() { ssh "$HOST" "docker exec -i $DB psql -U postgres -X -q -t -A -v ON_ERROR_STOP=1 $(printf '%q ' "$@")"; }

psql > /dev/null <<'SQL'
create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations (
  version text primary key, statements text[], name text);
SQL
applied=$(psql -c 'select version from supabase_migrations.schema_migrations' < /dev/null)

pending=0
for f in supabase/migrations/*.sql; do
  base=$(basename "$f" .sql)
  version=${base%%_*}
  name=${base#*_}
  grep -qx "$version" <<< "$applied" && continue
  pending=1
  echo "applying $base"
  { echo 'begin;'
    cat "$f"
    printf "\ninsert into supabase_migrations.schema_migrations (version, name) values ('%s', '%s');\n" "$version" "$name"
    echo 'commit;'
  } | psql > /dev/null
done
[ "$pending" = 1 ] || echo "no pending migrations"
