#!/usr/bin/env bash
# Read-only diagnostics: no simulator creation, SDK installation, secrets or signing.
set -uo pipefail
output="${1:-build/qualification/native-preflight}"
platform="${2:-all}"
mkdir -p "$output"
[[ "$(uname -s)" == Darwin ]] || { echo 'Native preflight requires macOS.' >&2; exit 1; }
[[ "$platform" == all || "$platform" == ios || "$platform" == android ]] || { echo 'Native preflight platform must be all, ios or android.' >&2; exit 1; }
# This is supplemental metadata only. It never supplies settings to the probes or
# turns a missing tool into a passing check.
if command -v python3 >/dev/null 2>&1; then
  python3 "$(dirname "$0")/tool-state.py" > "$output/native-tools-state.json" 2>/dev/null || true
fi
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
probe flutter.json flutter --version --machine
if [[ "$platform" == all || "$platform" == ios ]]; then
  probe xcode.txt xcodebuild -version
  probe runtimes.json xcrun simctl list runtimes --json
  probe device-types.json xcrun simctl list devicetypes --json
fi
if [[ "$platform" == all || "$platform" == android ]]; then
  probe java.txt java -version
  if [[ -n "${ANDROID_HOME:-}" ]]; then
    probe avds.txt "$ANDROID_HOME/emulator/emulator" -list-avds
    probe android-acceleration.txt "$ANDROID_HOME/emulator/emulator" -accel-check
  else
    echo 'ANDROID_HOME is not configured.' > "$output/android-sdk.txt"
    failed=1
  fi
fi
if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" == 1 && "$(uname -m)" != arm64 ]]; then
  echo 'Runner is translated under Rosetta; run the arm64 Actions runner and native toolchain.' >&2
  failed=1
fi
exit "$failed"
