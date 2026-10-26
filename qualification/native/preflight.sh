#!/usr/bin/env bash
# Read-only diagnostics: no simulator creation, SDK installation, secrets or signing.
set -uo pipefail
output="${1:-build/qualification/native-preflight}"
mkdir -p "$output"
[[ "$(uname -s)" == Darwin ]] || { echo 'Native preflight requires macOS.' >&2; exit 1; }
failed=0
probe() {
  local name="$1"
  shift
  if "$@" > "$output/$name" 2>&1; then return 0; fi
  failed=1
  echo "Unavailable probe: $name" >&2
}
probe process-architecture.txt uname -m
(sysctl -n hw.optional.arm64 || true) > "$output/apple-silicon.txt" 2>&1
(sysctl -n sysctl.proc_translated || true) > "$output/rosetta.txt" 2>&1
probe macos.txt sw_vers -productVersion
probe xcode.txt xcodebuild -version
probe runtimes.json xcrun simctl list runtimes --json
probe device-types.json xcrun simctl list devicetypes --json
probe flutter.json flutter --version --machine
probe java.txt java -version
if [[ -n "${ANDROID_HOME:-}" ]]; then
  probe avds.txt "$ANDROID_HOME/emulator/emulator" -list-avds
  probe android-acceleration.txt "$ANDROID_HOME/emulator/emulator" -accel-check
else
  echo 'ANDROID_HOME is not configured.' > "$output/android-sdk.txt"
  failed=1
fi
if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" == 1 && "$(uname -m)" != arm64 ]]; then
  echo 'Runner is translated under Rosetta. Install/run the arm64 Actions runner and arm64 Flutter/JDK/Android SDK.' >&2
  failed=1
fi
exit "$failed"
