#!/usr/bin/env bash
# Builds the Flutter web app for the one environment and publishes it on the home server,
# where nginx serves it at https://wusel.example.org/ (specs/10#the-web-app).
# Self-contained: CanvasKit and fonts are served from our own origin, not Google's CDN
# (NFR-9). The swap is a rename, so a visitor never sees a half-copied build.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/flutter/bin:$PATH"
WEB=/srv/appdata/nginx/www/wuselwall

(cd app && flutter build web --release --no-web-resources-cdn \
  --dart-define-from-file=env/dev.json -o build/web-live)

stamp=$(date +%Y%m%d%H%M%S)
tar -C app/build/web-live -czf - . | ssh homeserver "mkdir -p $WEB.new-$stamp && tar -C $WEB.new-$stamp -xzf - \
  && { [ -d $WEB ] && mv $WEB $WEB.old-$stamp || true; } && mv $WEB.new-$stamp $WEB \
  && rm -rf $WEB.old-* && echo published $WEB"
