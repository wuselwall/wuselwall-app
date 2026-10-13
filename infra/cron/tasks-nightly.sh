#!/usr/bin/env bash
# The nightly task job (specs/06): materialises the next 14 days of chores and closes
# yesterday (expiry, streaks with jokers, badges). Runs on the home server at 03:00 from
# Unraid's User Scripts plugin (schedule "Custom", cron `0 3 * * *`); see specs/10.
#
# The secret lives in a root-only file next to the stack and is the same value as
# CRON_SECRET in the stack's .env. The call stays on the host: the gateway listens on the
# Docker bridge (172.17.0.1:54421) and nothing leaves the machine.
set -euo pipefail
SECRET_FILE=${SECRET_FILE:-/mnt/cache/appdata/wuselwall/cron-secret}
URL=${URL:-http://172.17.0.1:54421/functions/v1/tasks-nightly}

secret=$(cat "$SECRET_FILE")
# --fail-with-body: a 401 or 500 makes the User Scripts log show the reason and exits non-zero.
curl -sS --fail-with-body --max-time 120 -X POST \
  -H "x-cron-secret: $secret" -H 'content-type: application/json' --data '{}' "$URL"
echo
