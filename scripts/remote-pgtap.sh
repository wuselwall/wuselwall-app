#!/usr/bin/env bash
# Runs supabase/tests/*.sql against the database of a server's compose stack.
# Each test runs in a rolled-back transaction, so this is safe on live data. The
# files are streamed through `docker exec`, so nothing is mounted and no password is needed.
set -euo pipefail
cd "$(dirname "$0")/.."
# The target server comes from scripts/remote.env (git-ignored; see remote.env.example).
[ -f scripts/remote.env ] && . scripts/remote.env
export DOCKER_HOST=ssh://${WW_HOST:?set WW_HOST in scripts/remote.env}
DB=${DB_CONTAINER:-supabase-db}
status=0
for f in supabase/tests/*.sql; do
  echo "# $f"
  out=$( (echo "create extension if not exists pgtap with schema extensions; set search_path to public, extensions;"; cat "$f") \
    | docker exec -i "$DB" psql -U postgres -X -q -t -A -v ON_ERROR_STOP=0 2>&1) || true
  echo "$out"
  if echo "$out" | grep -qE '^not ok|^psql:.*ERROR|Looks like you failed|Looks like you planned'; then status=1; fi
done
exit $status
