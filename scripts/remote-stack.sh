#!/usr/bin/env bash
# A server's Supabase stack, driven over SSH from a checkout: Supabase's official
# self-hosting compose file plus infra/supabase/docker-compose.wuselwall.yml (specs/10).
# A server installed from a release uses server/wuselwall instead.
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
# The target server comes from scripts/remote.env (git-ignored; see remote.env.example).
[ -f scripts/remote.env ] && . scripts/remote.env
HOST=${WW_HOST:?set WW_HOST in scripts/remote.env}
DIR=${WW_STACK_DIR:?set WW_STACK_DIR in scripts/remote.env}

case "${1:-}" in
  init-env)
    if ssh "$HOST" test -e "$DIR/.env"; then
      echo "$DIR/.env exists already; refusing to replace the stack's secrets" >&2
      exit 1
    fi
    ssh "$HOST" "mkdir -p '$DIR' && chmod 700 '$DIR'"
    # The server's addresses come from the environment (WW_API_URL, WW_WEB_URL, optional
    # WW_RP_ID), never from this file; a release installs with server/wuselwall instead.
    : "${WW_API_URL:?set WW_API_URL=https://api.<your domain>}" "${WW_WEB_URL:?set WW_WEB_URL=https://web.<your domain>}"
    node infra/supabase/make-env.mjs "${2:-supabase/.env}" \
      --api "$WW_API_URL" --web "$WW_WEB_URL" ${WW_RP_ID:+--rp-id "$WW_RP_ID"} --studio \
      | ssh "$HOST" "umask 077 && cat > '$DIR/.env'"
    echo "wrote $HOST:$DIR/.env"
    ;;
  set-env)
    # The value comes on stdin, never as an argument: no secret in shell history or ps.
    #   pass show wuselwall/scaleway | scripts/remote-stack.sh set-env SCW_SECRET_KEY
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
      --exclude volumes/functions/ --exclude volumes/web/ --exclude volumes/mail-templates/ \
      infra/supabase/ "$HOST:$DIR/"
    # Upstream's router (main/) next to our functions, one directory each.
    rsync -rlt --delete --chmod=D755,F644 \
      infra/supabase/volumes/functions/ $( [ -d supabase/functions ] && echo supabase/functions/ ) \
      "$HOST:$DIR/volumes/functions/"
    # SMTP fallback: raw Go templates served only on the Compose network.
    rsync -rlt --delete --chmod=D755,F644 supabase/templates/ "$HOST:$DIR/volumes/mail-templates/"
    # Before Auth restarts: the old social sign-in values leave the .env (specs/10).
    ssh "$HOST" "cd '$DIR' && sh retire-social-sign-in.sh .env"
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
