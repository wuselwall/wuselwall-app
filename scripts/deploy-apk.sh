#!/usr/bin/env bash
# Publishes the newest APK from the build-android workflow on the home server, at
# https://wuselwall.app/download/wuselwall.apk — open that on the tablet to install or
# update (specs/10#the-android-app). Needs `gh` signed in to the repository.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=wuselwall/wuselwall-app
run=$(gh run list --repo $REPO --workflow build-android.yml --status success --limit 1 --json databaseId -q '.[0].databaseId')
[ -n "$run" ] || { echo "no successful build-android run yet" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
gh run download "$run" --repo $REPO --name wuselwall-apk --dir "$tmp"
ssh homeserver 'mkdir -p /srv/appdata/nginx/www/wuselwall-download'
scp -q "$tmp/wuselwall.apk" homeserver:/srv/appdata/nginx/www/wuselwall-download/wuselwall.apk.new
ssh homeserver 'mv /srv/appdata/nginx/www/wuselwall-download/wuselwall.apk.new /srv/appdata/nginx/www/wuselwall-download/wuselwall.apk'
echo "published run $run: https://wuselwall.app/download/wuselwall.apk"
