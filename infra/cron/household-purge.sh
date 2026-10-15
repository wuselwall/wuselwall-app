#!/usr/bin/env bash
# The daily purge of deleted families (specs/20 J6): removes the families deleted more than
# 14 days ago, and the Auth users of their shared and kiosk devices. Runs on the home server
# at 04:00 from Unraid's User Scripts plugin (schedule "Custom", cron `0 4 * * *`); see specs/10.
#
# The secret lives in a root-only file next to the stack and is the same value as
# CRON_SECRET in the stack's .env. The call stays on the host: the gateway listens on the
# Docker bridge (172.17.0.1:54421) and nothing leaves the machine.
set -euo pipefail
SECRET_FILE=${SECRET_FILE:-/mnt/cache/appdata/wuselwall/cron-secret}
URL=${URL:-http://172.17.0.1:54421/functions/v1/household-purge}

secret=$(cat "$SECRET_FILE")
# --fail-with-body: a 401 or 500 makes the User Scripts log show the reason and exits non-zero.
curl -sS --fail-with-body --max-time 120 -X POST \
  -H "x-cron-secret: $secret" -H 'content-type: application/json' --data '{}' "$URL"
echo
