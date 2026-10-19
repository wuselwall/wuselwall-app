#!/usr/bin/env bash
# Builds the backend-neutral Flutter web app and publishes it in WW_WEB_DIR on WW_HOST
# (specs/10#the-web-app). Like a server release, it discovers the setup-configured server
# and publishable key at its own origin's /.well-known/wuselwall.json. Developer env files
# must never become deployment inputs.
# Self-contained: CanvasKit and fonts are served from our own origin, not Google's CDN
# (NFR-9). The swap is a rename, so a visitor never sees a half-copied build.
set -euo pipefail
cd "$(dirname "$0")/.."
# The target server comes from scripts/remote.env (git-ignored; see remote.env.example).
[ -f scripts/remote.env ] && . scripts/remote.env
HOST=${WW_HOST:?set WW_HOST in scripts/remote.env}
WEB=${WW_WEB_DIR:?set WW_WEB_DIR in scripts/remote.env}
export PATH="$HOME/flutter/bin:$PATH"

(cd app && flutter build web --release --no-web-resources-cdn --base-href / \
  --dart-define=ENV=release -o build/web-live)

stamp=$(date +%Y%m%d%H%M%S)
tar -C app/build/web-live -czf - . | ssh "$HOST" "mkdir -p $WEB.new-$stamp && tar -C $WEB.new-$stamp -xzf - \
  && { [ -d $WEB ] && mv $WEB $WEB.old-$stamp || true; } && mv $WEB.new-$stamp $WEB \
  && rm -rf $WEB.old-* && echo published $WEB"
