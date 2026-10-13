#!/usr/bin/env bash
# Tries migrations that are not applied yet against the home server's database without
# keeping anything: for each test file, the new migrations and the test run in one
# transaction, and the test's own closing `rollback` undoes both. Use it before
# `remote-migrate.sh` to see a new migration pass the whole pgTAP suite.
#
#   scripts/remote-pgtap-dry.sh supabase/migrations/2026…_a.sql [more migrations…] [-- tests…]
#
# The migrations take their locks for the length of one test file (a second or two).
set -uo pipefail
cd "$(dirname "$0")/.."
export DOCKER_HOST=ssh://${WW_HOST:-homeserver}
DB=${DB_CONTAINER:-supabase-db}

migrations=()
while [[ $# -gt 0 && $1 != -- ]]; do migrations+=("$1"); shift; done
[[ ${1:-} == -- ]] && shift
tests=("$@")
[[ ${#tests[@]} -eq 0 ]] && tests=(supabase/tests/*.sql)

status=0
for f in "${tests[@]}"; do
  echo "# $f"
  out=$( (echo "create extension if not exists pgtap with schema extensions;"
          echo "set search_path to public, extensions; begin;"
          for m in "${migrations[@]}"; do cat "$m"; echo; done
          echo "set search_path to public, extensions;"
          cat "$f") \
    | docker exec -i "$DB" psql -U postgres -X -q -t -A -v ON_ERROR_STOP=0 2>&1) || true
  echo "$out" | grep -vE '^ok |^$|already a transaction in progress'
  if echo "$out" | grep -qE '^not ok|ERROR|Looks like you failed|Looks like you planned'; then status=1; fi
done
exit $status
