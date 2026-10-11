#!/usr/bin/env bash
# Runs supabase/tests/*.sql against the Supabase DB on the homeserver Docker host.
# `supabase test db` bind-mounts the test files into a container, which cannot see local
# files when Docker is remote, so the files are streamed through `docker exec` instead.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH" DOCKER_HOST=ssh://homeserver
status=0
for f in supabase/tests/*.sql; do
  echo "# $f"
  out=$( (echo "create extension if not exists pgtap with schema extensions; set search_path to public, extensions;"; cat "$f") \
    | docker exec -i supabase_db_wuselwall psql -U postgres -X -q -t -A -v ON_ERROR_STOP=0 2>&1) || true
  echo "$out"
  if echo "$out" | grep -qE '^not ok|^psql:.*ERROR|Looks like you failed|Looks like you planned'; then status=1; fi
done
exit $status
