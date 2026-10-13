#!/usr/bin/env bash
# Receives a build of the user documentation (docs/) on the home server and publishes it,
# where nginx serves it at https://wuselwall.app/docs/ (alias .../wuselwall-docs/current/).
#
# It is the forced command of the CI deploy key in root's authorized_keys, so that key can
# do nothing but this, whatever command the client asks for:
#   command="/bin/bash /srv/appdata/wuselwall/bin/receive-docs.sh",restrict ssh-ed25519 AAAA… wuselwall-docs-deploy
# Input: the built site as a gzipped tar on stdin. Each build lands in its own folder and
# the "current" link is swapped with a rename, so a visitor never sees a half-copied site.
# The previous builds stay for a rollback: ln -sfn releases/<stamp> current.
set -euo pipefail
ROOT=/srv/appdata/nginx/www/wuselwall-docs
KEEP=3

stamp=$(date +%Y%m%d%H%M%S)
rel="$ROOT/releases/$stamp"
mkdir -p "$rel"
trap 'rm -rf "$rel"' ERR
tar -xzf - -C "$rel" --no-same-owner --no-same-permissions
[ -f "$rel/index.html" ] || { echo "no index.html in the upload, not published" >&2; exit 1; }
chmod -R u=rwX,go=rX "$rel"
trap - ERR

# Relative link: it resolves the same in this shell and in nginx's container (/config/www/…).
ln -sfn "releases/$stamp" "$ROOT/current.new"
mv -T "$ROOT/current.new" "$ROOT/current"
echo "published $rel"

# Keep the newest $KEEP builds.
ls -1d "$ROOT"/releases/*/ | sort | head -n -"$KEEP" | xargs -r rm -rf --
