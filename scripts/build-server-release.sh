#!/usr/bin/env bash
# Packs a server release (ADR-018, decision 9): everything a WuselWall server needs, for
# server/wuselwall to install or update from. Run by .github/workflows/server-release.yml
# on a tag server-v<version>, or by hand.
#
#   scripts/build-server-release.sh <version> [--skip-web]
#     → dist/wuselwall-server-<version>.tar.gz
#
# The web app inside is built without a server (no SUPABASE_URL): it finds its server at
# its own origin's /.well-known/wuselwall.json, so one build serves every server.
set -euo pipefail
cd "$(dirname "$0")/.."
version=${1:?usage: build-server-release.sh <version> [--skip-web]}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 1.2.3" >&2; exit 2; }

out=dist/wuselwall-server-$version
rm -rf "$out" && mkdir -p "$out"
root=$out/wuselwall
mkdir -p "$root"/{stack,migrations,jobs,backup}

cp server/wuselwall "$root/wuselwall"
echo "$version" > "$root/VERSION"
rsync -a \
  --exclude .env --exclude '.env.*' \
  --exclude volumes/db/data/ --exclude volumes/storage/ --exclude volumes/snippets/ \
  --exclude volumes/functions/ --exclude volumes/web/ \
  infra/supabase/ "$root/stack/"
mkdir -p "$root/stack/volumes/functions" "$root/stack/volumes/web"
# Upstream's router (main/) next to WuselWall's functions, as the stack mounts them.
rsync -a infra/supabase/volumes/functions/ supabase/functions/ "$root/stack/volumes/functions/"
rsync -a supabase/templates/ "$root/stack/volumes/mail-templates/"
cp supabase/migrations/*.sql "$root/migrations/"
cp infra/jobs/schedule.sql "$root/jobs/"
cp infra/backup/backup.sh "$root/backup/"

if [[ ${2:-} != --skip-web ]]; then
  (cd app && flutter build web --release --no-web-resources-cdn --base-href / \
    --dart-define=ENV=release -o build/web-release)
  rsync -a app/build/web-release/ "$root/stack/volumes/web/"
fi

tar -C "$out" -czf "dist/wuselwall-server-$version.tar.gz" wuselwall
rm -rf "$out"
echo "dist/wuselwall-server-$version.tar.gz"
