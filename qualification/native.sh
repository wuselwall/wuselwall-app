#!/usr/bin/env bash
# Synthetic-data rendering plus Android ATF and iOS XCTest platform audits.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'Native lane requires a macOS runner.' >&2; exit 1; }
output="$(pwd)/build/qualification/native"
deadline_script="$(pwd)/qualification/native/deadline.py"
run_deadline() {
  local seconds="$1" phase="$2"
  shift 2
  python3 "$deadline_script" "$seconds" "$phase" -- "$@"
}
run_logged_deadline() {
  local seconds="$1" phase="$2" log="$3" status=0
  shift 3
  printf 'NATIVE LOGGED PHASE BEGIN %s\n' "$phase" >&2
  run_deadline "$seconds" "$phase" "$@" > "$log" 2>&1 || status=$?
  printf 'NATIVE LOGGED PHASE END %s exit=%s log=%s\n' "$phase" "$status" "${log##*/}" >&2
  return "$status"
}
mkdir -p "$output"
platform=all
if [[ $# -gt 0 ]]; then
  case "$1" in
    ios-phone|ios-tablet|ios-phone-large|ios-tablet-large) platform=ios ;;
    android-phone|android-tablet|android-min-phone|android-phone-large|android-tablet-large) platform=android ;;
    *) echo 'Unknown native profile.' >&2; exit 1 ;;
  esac
fi
if [[ "$platform" == all || "$platform" == android ]]; then
  if [[ "$platform" == all ]]; then
    : "${QUALIFICATION_ANDROID_PHONE_AVD:?Set a pre-provisioned ARM64 phone AVD name}"
    : "${QUALIFICATION_ANDROID_MIN_PHONE_AVD:?Set a pre-provisioned ARM64 minimum-API phone AVD name}"
    : "${QUALIFICATION_ANDROID_TABLET_AVD:?Set a pre-provisioned ARM64 tablet AVD name}"
  else
    case "$1" in
      android-phone|android-phone-large) : "${QUALIFICATION_ANDROID_PHONE_AVD:?Set a pre-provisioned ARM64 phone AVD name}" ;;
      android-min-phone) : "${QUALIFICATION_ANDROID_MIN_PHONE_AVD:?Set a pre-provisioned ARM64 minimum-API phone AVD name}" ;;
      android-tablet|android-tablet-large) : "${QUALIFICATION_ANDROID_TABLET_AVD:?Set a pre-provisioned ARM64 tablet AVD name}" ;;
    esac
  fi
  : "${ANDROID_HOME:?Set ANDROID_HOME}"
  export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
  for tool in emulator adb java; do command -v "$tool" >/dev/null; done
  run_deadline 60 android-acceleration emulator -accel-check
fi
command -v flutter >/dev/null
if [[ "$platform" == all || "$platform" == ios ]]; then
  command -v xcrun >/dev/null
  if [[ "$platform" == all || "${QUALIFY_NATIVE_SMOKE:-false}" != true || "${QUALIFICATION_IOS_DIAGNOSTIC_RUNTIME_FALLBACK:-false}" != true ]]; then
    : "${QUALIFICATION_IOS_RUNTIME:?Set the pinned CoreSimulator runtime identifier}"
  fi
fi
bash_preflight_timeout=120
run_deadline "$bash_preflight_timeout" native-preflight bash qualification/native/preflight.sh build/qualification/native-preflight "$platform"
node qualification/generate-native.mjs --check
if [[ "$platform" == all || "$platform" == ios ]]; then
  run_deadline 30 xcode-version xcodebuild -version > "$output/xcode.txt"
fi
sw_vers -productVersion > "$output/macos.txt"
if [[ "$platform" == all || "$platform" == android ]]; then
  run_deadline 30 emulator-version emulator -version > "$output/emulator.txt" 2>&1
fi
run_deadline 60 flutter-version flutter --version --machine > "$output/flutter.json"
if [[ "$platform" == ios && "${QUALIFY_NATIVE_SMOKE:-false}" == true && "${QUALIFICATION_IOS_DIAGNOSTIC_RUNTIME_FALLBACK:-false}" == true ]]; then
  case "$1" in
    ios-phone|ios-phone-large) selected_ios_device_type="${QUALIFICATION_IOS_PHONE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-16}" ;;
    ios-tablet|ios-tablet-large) selected_ios_device_type="${QUALIFICATION_IOS_TABLET_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4-8GB}" ;;
  esac
  runtime_info=$(xcrun simctl list runtimes --json | node qualification/native/select-ios-runtime.mjs \
    "${QUALIFICATION_IOS_RUNTIME:-}" "$selected_ios_device_type")
  QUALIFICATION_IOS_RUNTIME=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["identifier"])' "$runtime_info")
  export QUALIFICATION_IOS_RUNTIME
  printf '%s\n' "$runtime_info" > "$output/diagnostic-runtime.json"
fi
simulator_id=''
emulator_pid=''
ios_project_backup=''
cleanup() {
  if [[ -n "$ios_project_backup" ]]; then
    cp "$ios_project_backup" app/ios/Runner.xcodeproj/project.pbxproj
    rm -f "$ios_project_backup" app/ios/Runner.xcodeproj/xcshareddata/xcschemes/QualificationAudits.xcscheme
    ios_project_backup=''
  fi
  if [[ -n "$simulator_id" ]]; then
    local owned_simulator="$simulator_id"
    simulator_id=''
    run_deadline 15 cleanup-ios-shutdown xcrun simctl shutdown "$owned_simulator" >/dev/null || true
    run_deadline 15 cleanup-ios-delete xcrun simctl delete "$owned_simulator" >/dev/null || true
  fi
  if [[ -n "$emulator_pid" ]]; then
    local owned_emulator="$emulator_pid"
    emulator_pid=''
    kill "$owned_emulator" >/dev/null 2>&1 || true
    wait "$owned_emulator" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
run_app() {
  local device_id="$1" target="$2" tablet="$3"
  mkdir -p "$output/$target"
  rm -f "$output/$target"/*.png "$output/$target/results.json" "$output/$target/audit.json"
  (cd app && QUALIFY_NATIVE_OUT="$output/$target" run_deadline 1200 "flutter-drive-$target" flutter drive --no-pub \
    --driver=test_driver/qualification.dart --target=integration_test/qualification_test.dart \
    --device-id="$device_id" --dart-define="QUALIFY_CANDIDATE_SHA=${QUALIFY_CANDIDATE_SHA:-}" --dart-define="QUALIFY_TABLET=$tablet" \
    --dart-define="QUALIFY_SMOKE=${QUALIFY_NATIVE_SMOKE:-false}") 2>&1 | tee "$output/$target/drive.log"
}
run_ios() {
  local kind="$1" device_type="$2" tablet="$3"
  mkdir -p "$output/ios-$kind"
  simulator_id=$(run_deadline 60 "ios-create-$kind" xcrun simctl create "qualification-$kind-$$" "$device_type" "$QUALIFICATION_IOS_RUNTIME")
  run_deadline 60 "ios-boot-$kind" xcrun simctl boot "$simulator_id"
  run_deadline 300 "ios-bootstatus-$kind" xcrun simctl bootstatus "$simulator_id" -b
  xcrun simctl status_bar "$simulator_id" override --time 09:41 --batteryState charged --batteryLevel 100 --wifiMode active --wifiBars 3 --dataNetwork wifi
  if [[ "$kind" == *-large ]]; then
    xcrun simctl ui "$simulator_id" content_size accessibility-extra-extra-extra-large
  fi
  local failed=0
  rm -rf "$output/ios-$kind/audits.xcresult"
  run_app "$simulator_id" "ios-$kind" "$tablet" || failed=1
  (cd app && run_deadline 1200 "flutter-build-ios-$kind" flutter build ios --simulator --debug --no-pub --target=qualification/native_main.dart \
    --dart-define="QUALIFY_CANDIDATE_SHA=${QUALIFY_CANDIDATE_SHA:-}" --dart-define="QUALIFY_TABLET=$tablet" --dart-define="QUALIFY_SMOKE=${QUALIFY_NATIVE_SMOKE:-false}") || return 1
  ios_project_backup=$(mktemp)
  cp app/ios/Runner.xcodeproj/project.pbxproj "$ios_project_backup"
  if [[ -n "${BUNDLE_GEMFILE:-}" ]]; then
    bundle exec ruby qualification/native/prepare-ios.rb
  else
    ruby qualification/native/prepare-ios.rb
  fi
  local audit_timeout=1800
  [[ "${QUALIFY_NATIVE_SMOKE:-false}" == true ]] && audit_timeout=600
  run_logged_deadline "$audit_timeout" "ios-xctest-$kind" "$output/ios-$kind/audits.log" xcodebuild test -workspace app/ios/Runner.xcworkspace -scheme QualificationAudits \
    -configuration Debug -destination "platform=iOS Simulator,id=$simulator_id" \
    -resultBundlePath "$output/ios-$kind/audits.xcresult" CODE_SIGNING_ALLOWED=NO || failed=1
  # The simulator shares the host loopback; preserve JSON even when XCTest fails.
  local data_path
  if data_path=$(run_deadline 60 "ios-report-container-$kind" xcrun simctl get_app_container "$simulator_id" ch.goomba.wuselwall data); then
    run_deadline 60 "ios-report-copy-$kind" cp "$data_path/tmp/native-audit.json" "$output/ios-$kind/audit.json" || failed=1
  else
    failed=1
  fi
  cp "$ios_project_backup" app/ios/Runner.xcodeproj/project.pbxproj
  rm -f "$ios_project_backup" app/ios/Runner.xcodeproj/xcshareddata/xcschemes/QualificationAudits.xcscheme
  ios_project_backup=''
  [[ "$failed" == 0 ]] || return 1
  run_deadline 15 "ios-shutdown-$kind" xcrun simctl shutdown "$simulator_id"
  run_deadline 15 "ios-delete-$kind" xcrun simctl delete "$simulator_id"
  simulator_id=''
}
run_android() {
  local kind="$1" avd="$2" tablet="$3"
  mkdir -p "$output/android-$kind"
  # Own one dedicated port; never stop someone else's running virtual device.
  run_deadline 60 android-adb-start-server adb start-server || return 1
  local state_status=0
  run_deadline 15 android-existing-emulator adb -s emulator-5580 get-state >/dev/null || state_status=$?
  if [[ "$state_status" == 0 ]]; then echo 'Emulator port 5580 is already in use.' >&2; return 1; fi
  if [[ "$state_status" != 1 ]]; then echo 'Could not determine whether the reserved emulator is in use.' >&2; return 1; fi
  printf 'NATIVE PHASE BEGIN android-emulator-%s\n' "$kind" >&2
  # $! must identify the forwarding Python process, rather than a function subshell.
  python3 "$deadline_script" 14400 "android-emulator-$kind" -- emulator -avd "$avd" -read-only -no-snapshot -no-window -no-audio -gpu swiftshader -port 5580 \
    > "$output/android-$kind-emulator.log" 2>&1 &
  emulator_pid=$!
  local booted=false boot_deadline=$((SECONDS + 360)) remaining probe_timeout boot_state
  while (( SECONDS < boot_deadline )); do
    kill -0 "$emulator_pid" || { echo 'Emulator exited during boot.' >&2; return 1; }
    remaining=$((boot_deadline - SECONDS))
    (( remaining > 0 )) || break
    probe_timeout=15
    (( remaining < probe_timeout )) && probe_timeout=$remaining
    boot_state=$(run_deadline "$probe_timeout" android-boot-getprop adb -s emulator-5580 shell getprop sys.boot_completed | tr -d '\r') || boot_state=''
    if [[ "$boot_state" == 1 ]]; then booted=true; break; fi
    remaining=$((boot_deadline - SECONDS))
    (( remaining > 0 )) && sleep "$((remaining < 2 ? remaining : 2))"
  done
  [[ "$booted" == true ]] || { echo 'Emulator boot timed out.' >&2; return 1; }
  run_deadline 30 android-font-scale adb -s emulator-5580 shell settings put system font_scale 1.0
  run_deadline 30 android-reset-density adb -s emulator-5580 shell wm density reset
  local expected_api actual_api
  expected_api=$(python3 - "$kind" <<'PY'
import json,sys
apis=[int(p['path'].split(';')[1].replace('android-','')) for p in json.load(open('qualification/native/toolchain.json'))['packages'] if p['path'].startswith('system-images;')]
print(min(apis) if sys.argv[1]=='min-phone' else max(apis))
PY
)
  actual_api=$(run_deadline 15 android-api-getprop adb -s emulator-5580 shell getprop ro.build.version.sdk | tr -d '\r')
  [[ "$actual_api" == "$expected_api" ]] || { echo 'AVD Android API differs from its qualification profile.' >&2; return 1; }
  if [[ "$kind" == *-large ]]; then
    run_deadline 30 android-large-font adb -s emulator-5580 shell settings put system font_scale 2.0
    local physical_density
    physical_density=$(run_deadline 30 android-density-probe adb -s emulator-5580 shell wm density | sed -n 's/Physical density: //p' | tr -d '\r')
    [[ "$physical_density" =~ ^[0-9]+$ ]] || return 1
    run_deadline 30 android-large-density adb -s emulator-5580 shell wm density "$((physical_density * 125 / 100))"
  fi
  run_deadline 30 android-keyboard-config adb -s emulator-5580 shell settings put secure show_ime_with_hard_keyboard 1
  run_deadline 30 android-demo-config adb -s emulator-5580 shell settings put global sysui_demo_allowed 1
  run_deadline 30 android-demo-clock adb -s emulator-5580 shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
  run_deadline 30 android-demo-battery adb -s emulator-5580 shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged true >/dev/null
  run_deadline 15 "android-fingerprint-getprop-$kind" adb -s emulator-5580 shell getprop ro.build.fingerprint > "$output/android-$kind/device.txt"
  run_deadline 15 "android-api-record-getprop-$kind" adb -s emulator-5580 shell getprop ro.build.version.sdk >> "$output/android-$kind/device.txt"
  run_deadline 30 android-density-record adb -s emulator-5580 shell wm density >> "$output/android-$kind/device.txt"
  local failed=0
  run_app emulator-5580 "android-$kind" "$tablet" || failed=1
  (cd app && run_deadline 1200 "flutter-build-android-$kind" flutter build apk --debug --no-pub --target=qualification/native_main.dart \
    --dart-define="QUALIFY_CANDIDATE_SHA=${QUALIFY_CANDIDATE_SHA:-}" --dart-define="QUALIFY_TABLET=$tablet" --dart-define="QUALIFY_SMOKE=${QUALIFY_NATIVE_SMOKE:-false}") || return 1
  (cd app/android && run_logged_deadline 1200 "gradle-android-audit-$kind" "$output/android-$kind/build-audits.log" ./gradlew app:assembleDebugAndroidTest) || return 1
  run_deadline 120 "adb-install-app-$kind" adb -s emulator-5580 install -r app/build/app/outputs/flutter-apk/app-debug.apk
  run_deadline 120 "adb-install-audit-$kind" adb -s emulator-5580 install -r app/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
  local audit_timeout=1800
  [[ "${QUALIFY_NATIVE_SMOKE:-false}" == true ]] && audit_timeout=600
  run_logged_deadline "$audit_timeout" "android-instrumentation-$kind" "$output/android-$kind/audits.log" adb -s emulator-5580 shell am instrument -w -r \
    -e class ch.goomba.wuselwall.QualificationAuditTest \
    ch.goomba.wuselwall.test/androidx.test.runner.AndroidJUnitRunner || failed=1
  # Instrumentation may exit zero with failures; the report parser fails closed.
  run_deadline 60 "android-report-pull-$kind" adb -s emulator-5580 exec-out run-as ch.goomba.wuselwall cat cache/native-audit.json \
    > "$output/android-$kind/audit.json" || failed=1
  [[ "$failed" == 0 ]] || return 1
  kill "$emulator_pid"
  wait "$emulator_pid" || true
  emulator_pid=''
}
if [[ $# == 0 ]]; then
  rm -f "$output/profiles.txt" "$output/visual.json" "$output/evidence.json" "$output/diagnostic-runtime.json"
  failed=0
  for profile in ios-phone ios-tablet android-phone android-tablet ios-phone-large ios-tablet-large android-phone-large android-tablet-large android-min-phone; do
    if bash "$0" "$profile"; then
      printf '%s: PASS\n' "$profile" >> "$output/profiles.txt"
    else
      printf '%s: FAIL\n' "$profile" >> "$output/profiles.txt"
      failed=1
    fi
  done
  node qualification/native/baseline.mjs || failed=1
  node qualification/native/report.mjs || failed=1
  exit "$failed"
fi
case "$1" in
  ios-phone) run_ios phone "${QUALIFICATION_IOS_PHONE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-16}" false ;;
  ios-phone-large) run_ios phone-large "${QUALIFICATION_IOS_PHONE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-16}" false ;;
  ios-tablet-large) run_ios tablet-large "${QUALIFICATION_IOS_TABLET_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4-8GB}" true ;;
  android-min-phone) run_android min-phone "$QUALIFICATION_ANDROID_MIN_PHONE_AVD" false ;;
  android-phone-large) run_android phone-large "$QUALIFICATION_ANDROID_PHONE_AVD" false ;;
  android-tablet-large) run_android tablet-large "$QUALIFICATION_ANDROID_TABLET_AVD" true ;;
  ios-tablet) run_ios tablet "${QUALIFICATION_IOS_TABLET_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4-8GB}" true ;;
  android-phone) run_android phone "$QUALIFICATION_ANDROID_PHONE_AVD" false ;;
  android-tablet) run_android tablet "$QUALIFICATION_ANDROID_TABLET_AVD" true ;;
  *) echo 'Unknown native profile.' >&2; exit 1 ;;
esac
