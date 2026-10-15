#!/usr/bin/env bash
# Runs infra/backup/backup.sh on the server now (specs/10#changing-the-database).
# Usage: scripts/remote-backup.sh [label]   — e.g. before every migration.
set -euo pipefail
cd "$(dirname "$0")/.."
# The target server comes from scripts/remote.env (git-ignored; see remote.env.example).
[ -f scripts/remote.env ] && . scripts/remote.env
HOST=${WW_HOST:?set WW_HOST in scripts/remote.env}
ssh "$HOST" "BACKUP_DIR='${WW_BACKUP_DIR:?set WW_BACKUP_DIR in scripts/remote.env}' bash -s" -- "${1:-manual}" \
  < infra/backup/backup.sh
