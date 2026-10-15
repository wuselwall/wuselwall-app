#!/usr/bin/env bash
# Builds the Flutter web app for the server named in app/env/dev.json and publishes it in
# WW_WEB_DIR on WW_HOST, where a web server serves it (specs/10#the-web-app). Servers
# installed from a release serve the release's own web build instead.
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
  --dart-define-from-file=env/dev.json -o build/web-live)

stamp=$(date +%Y%m%d%H%M%S)
tar -C app/build/web-live -czf - . | ssh "$HOST" "mkdir -p $WEB.new-$stamp && tar -C $WEB.new-$stamp -xzf - \
  && { [ -d $WEB ] && mv $WEB $WEB.old-$stamp || true; } && mv $WEB.new-$stamp $WEB \
  && rm -rf $WEB.old-* && echo published $WEB"
