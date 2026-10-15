#!/usr/bin/env bash
# The daily purge of deleted families (specs/20 J6): removes the families deleted more than
# 14 days ago, and the Auth users of their shared and kiosk devices. For a server that schedules
# its jobs from the host's cron instead of pg_cron (infra/jobs/schedule.sql; never both).
# Cron: `0 4 * * *`.
#
# SECRET_FILE holds the same value as CRON_SECRET in the stack's .env (root-only). The call
# stays on the host: the gateway listens on the Docker bridge and nothing leaves the machine.
set -euo pipefail
SECRET_FILE=${SECRET_FILE:?set SECRET_FILE to the file holding CRON_SECRET}
URL=${URL:-http://172.17.0.1:54421/functions/v1/household-purge}

secret=$(cat "$SECRET_FILE")
# --fail-with-body: a 401 or 500 makes the User Scripts log show the reason and exits non-zero.
curl -sS --fail-with-body --max-time 120 -X POST \
  -H "x-cron-secret: $secret" -H 'content-type: application/json' --data '{}' "$URL"
echo
