#!/bin/sh
# Retires social sign-in in an existing compose stack's .env (specs/22, items 1 and 3).
#
#   sh retire-social-sign-in.sh <stack>/.env
#
# Run by server/wuselwall update and scripts/remote-stack.sh deploy before the stack starts;
# harmless to run again. Servers set up before the removal have, in their .env:
#   - the Google and Apple login settings (APPLE_ENABLED, APPLE_CLIENT_IDS, APPLE_SECRET — the
#     GoTrue Apple client-secret JWT —, GOOGLE_ENABLED, GOOGLE_CLIENT_IDS, GOOGLE_CLIENT_SECRET).
#     Nothing reads them any more; they are removed so no login credential lingers.
#   - the native apps' OAuth callback in ADDITIONAL_REDIRECT_URLS (Auth's redirect allow-list).
#     Only that entry is removed; the web app's own entry and any other destination an
#     operator added (invitation, pairing) stay, e-mail links need them.
# Kept, on purpose: APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, APPLE_CLIENT_ID and
# APPLE_TOKEN_KEY. account-delete needs them to revoke the Apple tokens of accounts from before
# the removal, and the stored tokens can only be read with this APPLE_TOKEN_KEY.
#
# Prints the names of what it changed, never a value. The file keeps its permissions (600).
set -eu
env_file=${1:?usage: retire-social-sign-in.sh <.env>}
[ -f "$env_file" ] || { echo "no such file: $env_file" >&2; exit 1; }

tmp="$env_file.retire.$$"
trap 'rm -f "$tmp"' EXIT
umask 077
awk -v q="'" '
  BEGIN { split("APPLE_ENABLED APPLE_CLIENT_IDS APPLE_SECRET GOOGLE_ENABLED GOOGLE_CLIENT_IDS GOOGLE_CLIENT_SECRET", gone, " ")
          for (i in gone) drop[gone[i]] = 1 }
  {
    key = $0; sub(/=.*/, "", key)
    if (key in drop) { print "  removed " key > "/dev/stderr"; next }
    if (key == "ADDITIONAL_REDIRECT_URLS") {
      value = substr($0, length(key) + 2)
      quote = ""
      if (substr(value, 1, 1) == q && substr(value, length(value), 1) == q) { quote = q; value = substr(value, 2, length(value) - 2) }
      n = split(value, parts, ","); kept = ""
      for (i = 1; i <= n; i++) {
        # Only the native OAuth callback (<scheme>://login-callback…) goes; invitation,
        # pairing and any other destination stays (specs/22 item 1).
        entry = parts[i]; gsub(/^[ \t]+|[ \t]+$/, "", entry)
        if (entry ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\/login-callback([\/?#].*)?$/) { changed = 1; continue }
        kept = kept (kept == "" ? "" : ",") parts[i]
      }
      if (changed) print "  removed the native OAuth callback from ADDITIONAL_REDIRECT_URLS" > "/dev/stderr"
      print key "=" quote kept quote
      next
    }
    print
  }
' "$env_file" > "$tmp"
if cmp -s "$tmp" "$env_file"; then
  echo "  social sign-in: nothing left to retire" >&2
else
  # Same permissions as before (normally 600): copy over, do not replace the inode.
  cat "$tmp" > "$env_file"
fi
