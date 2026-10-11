#!/usr/bin/env bash
# Runs infra/backup/backup.sh on the home server now (docs/10#changing-the-database).
# Usage: scripts/remote-backup.sh [label]   — e.g. before every migration.
set -euo pipefail
cd "$(dirname "$0")/.."
ssh homeserver 'bash -s' -- "${1:-manual}" < infra/backup/backup.sh
