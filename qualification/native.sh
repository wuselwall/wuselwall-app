#!/usr/bin/env bash
# Synthetic-data Flutter rendering smoke only. Native platform audits remain open.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'Native lane requires a macOS runner.' >&2; exit 1; }
: "${QUALIFICATION_IOS_RUNTIME:?Set the pinned CoreSimulator runtime identifier}"
: "${QUALIFICATION_ANDROID_PHONE_AVD:?Set a pre-provisioned ARM64 phone AVD name}"
: "${QUALIFICATION_ANDROID_TABLET_AVD:?Set a pre-provisioned ARM64 tablet AVD name}"
export PATH="${ANDROID_HOME:?Set ANDROID_HOME}/emulator:$ANDROID_HOME/platform-tools:$PATH"
for tool in flutter xcrun emulator adb java; do command -v "$tool" >/dev/null; done
emulator -accel-check
node qualification/generate-native.mjs --check
output="$(pwd)/build/qualification/native"
mkdir -p "$output"
xcodebuild -version > "$output/xcode.txt"
emulator -version > "$output/emulator.txt" 2>&1
flutter --version --machine > "$output/flutter.json"
simulator_id=''
emulator_pid=''
cleanup() {
  if [[ -n "$simulator_id" ]]; then
    xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
    xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true
  fi
  if [[ -n "$emulator_pid" ]]; then
    kill "$emulator_pid" >/dev/null 2>&1 || true
    wait "$emulator_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM
run_app() {
  local device_id="$1" target="$2" tablet="$3"
  mkdir -p "$output/$target"
  (cd app && QUALIFY_NATIVE_OUT="$output/$target" flutter drive --no-pub \
    --driver=test_driver/qualification.dart --target=integration_test/qualification_test.dart \
    --device-id="$device_id" --dart-define="QUALIFY_TABLET=$tablet" \
    --dart-define="QUALIFY_SMOKE=${QUALIFY_NATIVE_SMOKE:-false}") 2>&1 | tee "$output/$target/drive.log"
}
run_ios() {
  local kind="$1" device_type="$2" tablet="$3"
  simulator_id=$(xcrun simctl create "qualification-$kind-$$" "$device_type" "$QUALIFICATION_IOS_RUNTIME")
  xcrun simctl boot "$simulator_id"
  xcrun simctl bootstatus "$simulator_id" -b
  run_app "$simulator_id" "ios-$kind" "$tablet"
  xcrun simctl shutdown "$simulator_id"
  xcrun simctl delete "$simulator_id"
  simulator_id=''
}
run_android() {
  local kind="$1" avd="$2" tablet="$3"
  # Own one dedicated port; never stop someone else's running virtual device.
  if adb -s emulator-5580 get-state >/dev/null 2>&1; then echo 'Emulator port 5580 is already in use.' >&2; exit 1; fi
  emulator -avd "$avd" -read-only -no-snapshot-save -no-window -no-audio -gpu swiftshader -port 5580 \
    > "$output/android-$kind-emulator.log" 2>&1 &
  emulator_pid=$!
  local booted=false
  for ((attempt=0; attempt<180; attempt++)); do
    kill -0 "$emulator_pid" || { echo 'Emulator exited during boot.' >&2; return 1; }
    if [[ "$(adb -s emulator-5580 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]]; then booted=true; break; fi
    sleep 2
  done
  [[ "$booted" == true ]] || { echo 'Emulator boot timed out.' >&2; return 1; }
  run_app emulator-5580 "android-$kind" "$tablet"
  kill "$emulator_pid"
  wait "$emulator_pid" || true
  emulator_pid=''
}
if [[ $# == 0 ]]; then
  failed=0
  for profile in ios-phone ios-tablet android-phone android-tablet; do
    if bash "$0" "$profile"; then
      printf '%s: PASS\n' "$profile" >> "$output/profiles.txt"
    else
      printf '%s: FAIL\n' "$profile" >> "$output/profiles.txt"
      failed=1
    fi
  done
  exit "$failed"
fi
case "$1" in
  ios-phone) run_ios phone "${QUALIFICATION_IOS_PHONE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-16}" false ;;
  ios-tablet) run_ios tablet "${QUALIFICATION_IOS_TABLET_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4-8GB}" true ;;
  android-phone) run_android phone "$QUALIFICATION_ANDROID_PHONE_AVD" false ;;
  android-tablet) run_android tablet "$QUALIFICATION_ANDROID_TABLET_AVD" true ;;
  *) echo 'Unknown native profile.' >&2; exit 1 ;;
esac
