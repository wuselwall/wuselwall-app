#!/usr/bin/env bash
# The website (website/) on the home server: its own compose project (infra/web), apart
# from the Supabase stack and the Flutter web app, so each updates on its own (specs/10).
#
#   scripts/remote-web.sh deploy     sync website/ and infra/web, build the image on the server,
#                                    up -d. Refuses to ship placeholders in the Impressum.
#   scripts/remote-web.sh deploy --draft
#                                    same, but allows placeholders (legal pages are noindex)
#   scripts/remote-web.sh <args>     any docker compose command: ps, logs -f site, restart site
#
# Roll back by redeploying an earlier commit; the previous image stays as a layer cache.
set -euo pipefail
cd "$(dirname "$0")/.."
HOST=${WW_HOST:-homeserver}
DIR=${WW_WEB_DIR:-/srv/appdata/wuselwall/web}

case "${1:-}" in
  deploy)
    strict=1; [ "${2:-}" = "--draft" ] && strict=0
    ssh "$HOST" "mkdir -p '$DIR/site'"
    rsync -rlt --delete --chmod=D755,F644 infra/web/docker-compose.yml "$HOST:$DIR/docker-compose.yml"
    rsync -rlt --delete --chmod=D755,F644 \
      --exclude node_modules --exclude dist --exclude .astro \
      website/ "$HOST:$DIR/site/"
    ssh "$HOST" "cd '$DIR' && LEGAL_STRICT=$strict docker compose up -d --build --remove-orphans && docker compose ps"
    ;;
  "")
    sed -n '2,11p' "$0"
    ;;
  *)
    ssh -t "$HOST" "cd '$DIR' && docker compose $(printf '%q ' "$@")"
    ;;
esac
