#!/usr/bin/env bash
# Run the Supabase CLI against the Docker daemon on the Unraid server (ssh host "unraid").
# Usage: scripts/remote-supabase.sh start|stop|status|db reset|...
# Opens SSH port forwards so 127.0.0.1:54321-54324 reach the remote stack, because the
# CLI connects to the database on localhost even when DOCKER_HOST is remote.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH" DOCKER_HOST=ssh://unraid
if ! ss -ltn | grep -q '127.0.0.1:54322'; then
  ssh -f -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
    -L 54321:127.0.0.1:54321 -L 54322:127.0.0.1:54322 \
    -L 54323:127.0.0.1:54323 -L 54324:127.0.0.1:54324 unraid
fi
exec npx supabase "$@"
