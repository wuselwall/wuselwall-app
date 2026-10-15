#!/usr/bin/env bash
# The weekly holiday cache refresh (supabase/functions/holidays-sync, specs/21), for a server
# that schedules it from the host's cron instead of pg_cron (infra/jobs/schedule.sql; never
# both): fetches the regions and public and school holidays of every country the
# households use from the OpenHolidays API, for the previous, current and next year. Only
# countries whose cache is older than 7 days are fetched, so a weekly run is the normal
# cadence. Cron: `0 4 * * 1` (Mondays, after the nightly task job).
#
# SECRET_FILE holds the same value as CRON_SECRET in the stack's .env (root-only). The call
# stays on the host: the gateway listens on the Docker bridge and nothing leaves the machine.
set -euo pipefail
SECRET_FILE=${SECRET_FILE:?set SECRET_FILE to the file holding CRON_SECRET}
URL=${URL:-http://172.17.0.1:54421/functions/v1/holidays-sync}

secret=$(cat "$SECRET_FILE")
# --fail-with-body: a 401 or 500 makes the cron log show the reason and exits non-zero.
curl -sS --fail-with-body --max-time 300 -X POST \
  -H "x-cron-secret: $secret" -H 'content-type: application/json' --data '{}' "$URL"
echo
