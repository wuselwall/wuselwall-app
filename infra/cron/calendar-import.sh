#!/usr/bin/env bash
# The hourly import of external calendars (supabase/functions/calendar-import, FR-1.9), for a
# server that schedules it from the host's cron instead of pg_cron (infra/jobs/schedule.sql;
# never both): fetches the ICS feeds the households subscribed to (sports fixtures, bin
# collection, school events) whose last attempt is more than 55 minutes old, at most 20 per
# run. Cron: `0 * * * *`.
#
# SECRET_FILE holds the same value as CRON_SECRET in the stack's .env (root-only). The call
# stays on the host: the gateway listens on the Docker bridge. The feeds themselves are
# fetched from the internet by the function, never by this script.
set -euo pipefail
SECRET_FILE=${SECRET_FILE:?set SECRET_FILE to the file holding CRON_SECRET}
URL=${URL:-http://172.17.0.1:54421/functions/v1/calendar-import}

secret=$(cat "$SECRET_FILE")
# --fail-with-body: a 401 or 500 makes the cron log show the reason and exits non-zero.
# Twenty feeds at 15 seconds each is the worst case, hence the longer timeout.
curl -sS --fail-with-body --max-time 900 -X POST \
  -H "x-cron-secret: $secret" -H 'content-type: application/json' --data '{}' "$URL"
echo
