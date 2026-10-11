#!/usr/bin/env bash
# CI only: writes the upload keystore and android/key.properties from secrets
# (ANDROID_KEYSTORE_B64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD).
# Both files are git-ignored. The keystore's original lives in the password manager.
set -euo pipefail
cd "$(dirname "$0")/../android"
: "${ANDROID_KEYSTORE_B64:?missing}" "${ANDROID_KEYSTORE_PASSWORD:?missing}" "${ANDROID_KEY_ALIAS:?missing}" "${ANDROID_KEY_PASSWORD:?missing}"
umask 077
echo "$ANDROID_KEYSTORE_B64" | base64 -d > upload.jks
cat > key.properties <<PROPS
storeFile=upload.jks
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
keyPassword=$ANDROID_KEY_PASSWORD
PROPS
