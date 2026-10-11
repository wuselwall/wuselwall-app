#!/usr/bin/env bash
# The only way to change the one environment's database (specs/10#changing-the-database):
# dump first, apply the pending migrations, then run the pgTAP suite (rolled-back
# transactions, safe on live data). Stops at the first failure.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== 1/3 backup"
scripts/remote-backup.sh pre-migration
echo "== 2/3 migrations"
scripts/remote-migrations.sh
echo "== 3/3 pgTAP"
scripts/remote-pgtap.sh
