#!/usr/bin/env bash
# The hourly import of external calendars (supabase/functions/calendar-import, FR-1.9): fetches
# the ICS feeds the households subscribed to (sports fixtures, bin collection, school events)
# whose last attempt is more than 55 minutes old, at most 20 per run. Runs on the home server
# from Unraid's User Scripts plugin (schedule "Custom", cron `0 * * * *`, every hour on the
# hour); see specs/10.
#
# The secret lives in a root-only file next to the stack and is the same value as
# CRON_SECRET in the stack's .env. The call stays on the host: the gateway listens on the
# Docker bridge (172.17.0.1:54421). The feeds themselves are fetched from the internet by the
# function, never by this script.
set -euo pipefail
SECRET_FILE=${SECRET_FILE:-/mnt/cache/appdata/wuselwall/cron-secret}
URL=${URL:-http://172.17.0.1:54421/functions/v1/calendar-import}

secret=$(cat "$SECRET_FILE")
# --fail-with-body: a 401 or 500 makes the User Scripts log show the reason and exits non-zero.
# Twenty feeds at 15 seconds each is the worst case, hence the longer timeout.
curl -sS --fail-with-body --max-time 900 -X POST \
  -H "x-cron-secret: $secret" -H 'content-type: application/json' --data '{}' "$URL"
echo
