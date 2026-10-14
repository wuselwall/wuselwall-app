#!/usr/bin/env bash
# The weekly holiday cache refresh (supabase/functions/holidays-sync, specs/21): fetches
# the regions and public and school holidays of every country the households use from the
# OpenHolidays API, for the previous, current and next year. Only countries whose cache is
# older than 7 days are fetched, so a weekly run is the normal cadence. Runs on the home
# server from Unraid's User Scripts plugin (schedule "Custom", cron `0 4 * * 1`, Mondays at
# 04:00, after the nightly task job); see specs/10.
#
# The secret lives in a root-only file next to the stack and is the same value as
# CRON_SECRET in the stack's .env. The call stays on the host: the gateway listens on the
# Docker bridge (172.17.0.1:54421) and nothing leaves the machine.
set -euo pipefail
SECRET_FILE=${SECRET_FILE:-/mnt/cache/appdata/wuselwall/cron-secret}
URL=${URL:-http://172.17.0.1:54421/functions/v1/holidays-sync}

secret=$(cat "$SECRET_FILE")
# --fail-with-body: a 401 or 500 makes the User Scripts log show the reason and exits non-zero.
curl -sS --fail-with-body --max-time 300 -X POST \
  -H "x-cron-secret: $secret" -H 'content-type: application/json' --data '{}' "$URL"
echo
