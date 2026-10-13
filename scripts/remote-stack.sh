#!/usr/bin/env bash
# The one environment's Supabase stack on the home server: Supabase's official
# self-hosting compose file plus infra/supabase/docker-compose.wuselwall.yml
# (ADR-013 amendment, specs/10).
#
#   scripts/remote-stack.sh init-env     create the server's .env once (refuses to overwrite)
#   scripts/remote-stack.sh set-env KEY  set one variable in the server's .env, value on stdin
#                                        (then `up -d auth` or whichever service reads it)
#   scripts/remote-stack.sh deploy       sync infra/supabase and supabase/functions, then up -d
#   scripts/remote-stack.sh functions    sync only supabase/functions and restart the Edge runtime
#   scripts/remote-stack.sh tunnel       127.0.0.1:54422 → Postgres, 127.0.0.1:54421 → gateway
#                                        (Studio at http://127.0.0.1:54421, DASHBOARD_* login)
#   scripts/remote-stack.sh <args>       any docker compose command: ps, logs -f auth, restart rest
#
# The .env lives only on the server (chmod 600). Keep a copy in the password manager: it
# holds the JWT secret and the signing key, and a restore without them strands every device.
set -euo pipefail
cd "$(dirname "$0")/.."
HOST=${WW_HOST:-homeserver}
DIR=${WW_STACK_DIR:-/srv/appdata/wuselwall/supabase}

case "${1:-}" in
  init-env)
    if ssh "$HOST" test -e "$DIR/.env"; then
      echo "$DIR/.env exists already; refusing to replace the stack's secrets" >&2
      exit 1
    fi
    ssh "$HOST" "mkdir -p '$DIR' && chmod 700 '$DIR'"
    node infra/supabase/make-env.mjs "${2:-supabase/.env}" \
      | ssh "$HOST" "umask 077 && cat > '$DIR/.env'"
    echo "wrote $HOST:$DIR/.env"
    ;;
  set-env)
    # The value comes on stdin, never as an argument: no secret in shell history or ps.
    #   node scripts/apple-client-secret.mjs … | scripts/remote-stack.sh set-env APPLE_SECRET
    key=${2:?usage: set-env KEY < value}
    [[ $key =~ ^[A-Z][A-Z0-9_]*$ ]] || { echo "not a variable name: $key" >&2; exit 2; }
    value=$(cat)
    [[ -n $value && $value != *"'"* && $value != *$'\n'* ]] \
      || { echo "the value must be one non-empty line without single quotes" >&2; exit 2; }
    printf '%s' "$value" | ssh "$HOST" "cd '$DIR' && test -e .env && umask 077 && v=\$(cat) \
      && { grep -v '^$key=' .env; printf '%s\n' \"$key='\$v'\"; } > .env.new && mv .env.new .env"
    echo "set $key in $HOST:$DIR/.env — apply with: scripts/remote-stack.sh up -d auth"
    ;;
  deploy)
    ssh "$HOST" test -e "$DIR/.env" || { echo "no .env on the server: run init-env first" >&2; exit 1; }
    # Excluded paths are never deleted by --delete: the database, uploads, Studio snippets.
    rsync -rlt --delete --chmod=D755,F644 \
      --exclude .env --exclude make-env.mjs \
      --exclude volumes/db/data/ --exclude volumes/storage/ --exclude volumes/snippets/ \
      --exclude volumes/functions/ \
      infra/supabase/ "$HOST:$DIR/"
    # Upstream's router (main/) next to our functions, one directory each.
    rsync -rlt --delete --chmod=D755,F644 \
      infra/supabase/volumes/functions/ $( [ -d supabase/functions ] && echo supabase/functions/ ) \
      "$HOST:$DIR/volumes/functions/"
    ssh "$HOST" "cd '$DIR' && docker compose up -d --remove-orphans && docker compose ps"
    ;;
  functions)
    # Edge Functions only: Postgres, Auth and the gateway are not touched.
    rsync -rlt --delete --chmod=D755,F644 \
      infra/supabase/volumes/functions/ $( [ -d supabase/functions ] && echo supabase/functions/ ) \
      "$HOST:$DIR/volumes/functions/"
    ssh "$HOST" "cd '$DIR' && docker compose restart functions"
    ;;
  tunnel)
    exec ssh -N -o ExitOnForwardFailure=yes \
      -L 54422:127.0.0.1:54422 -L 54421:172.17.0.1:54421 "$HOST"
    ;;
  "")
    sed -n '2,16p' "$0"
    ;;
  *)
    ssh -t "$HOST" "cd '$DIR' && docker compose $(printf '%q ' "$@")"
    ;;
esac
