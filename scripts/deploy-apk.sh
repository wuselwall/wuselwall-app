#!/usr/bin/env bash
# Publishes the newest APK from the release-android workflow on the server that hosts the
# download (WW_APK_DIR, served at WW_APK_URL; specs/10#the-android-app). Open that address
# on the tablet to install or update. Needs `gh` signed in to the repository.
set -euo pipefail
cd "$(dirname "$0")/.."
# The target server comes from scripts/remote.env (git-ignored; see remote.env.example).
[ -f scripts/remote.env ] && . scripts/remote.env
HOST=${WW_HOST:?set WW_HOST in scripts/remote.env}
DIR=${WW_APK_DIR:?set WW_APK_DIR in scripts/remote.env}
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
run=$(gh run list --repo "$REPO" --workflow release-android.yml --status success --limit 1 --json databaseId -q '.[0].databaseId')
[ -n "$run" ] || { echo "no successful release-android run yet" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
gh run download "$run" --repo "$REPO" --name wuselwall-apk --dir "$tmp"
ssh "$HOST" "mkdir -p '$DIR'"
scp -q "$tmp/wuselwall.apk" "$HOST:$DIR/wuselwall.apk.new"
ssh "$HOST" "mv '$DIR/wuselwall.apk.new' '$DIR/wuselwall.apk'"
echo "published run $run${WW_APK_URL:+: $WW_APK_URL}"
