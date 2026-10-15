#!/usr/bin/env bash
# The nightly task job (specs/06), for a server that schedules it from the host's cron
# instead of pg_cron (infra/jobs/schedule.sql; never both): materialises the next 14 days
# of chores and closes yesterday (expiry, streaks with jokers, badges). Cron: `0 3 * * *`.
#
# SECRET_FILE holds the same value as CRON_SECRET in the stack's .env (root-only). The call
# stays on the host: the gateway listens on the Docker bridge and nothing leaves the machine.
set -euo pipefail
SECRET_FILE=${SECRET_FILE:?set SECRET_FILE to the file holding CRON_SECRET}
URL=${URL:-http://172.17.0.1:54421/functions/v1/tasks-nightly}

secret=$(cat "$SECRET_FILE")
# --fail-with-body: a 401 or 500 makes the cron log show the reason and exits non-zero.
curl -sS --fail-with-body --max-time 120 -X POST \
  -H "x-cron-secret: $secret" -H 'content-type: application/json' --data '{}' "$URL"
echo
