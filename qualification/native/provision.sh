#!/usr/bin/env bash
# Dedicated native CI setup. Default prints an offline plan and changes nothing.
set -euo pipefail
cd "$(dirname "$0")/../.."
mode="${1:---dry-run}"
[[ $# -le 1 && ( "$mode" == --dry-run || "$mode" == --apply ) ]] || {
  echo 'Usage: bash qualification/native/provision.sh [--dry-run|--apply]' >&2; exit 2;
}
: "${QUALIFICATION_TOOLS_ROOT:=${RUNNER_TOOL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}}/wuselwall-qualification}"
: "${QUALIFICATION_MIN_FREE_GIB:=100}"
: "${QUALIFICATION_IOS_VERSION:=}"
: "${QUALIFICATION_IOS_BUILD:=}"
: "${QUALIFICATION_IOS_RUNTIME:=}"
: "${QUALIFICATION_ACCEPT_ANDROID_LICENSES:=false}"
export QUALIFICATION_TOOLS_ROOT QUALIFICATION_MIN_FREE_GIB QUALIFICATION_IOS_VERSION QUALIFICATION_IOS_BUILD QUALIFICATION_IOS_RUNTIME
export ANDROID_HOME="$QUALIFICATION_TOOLS_ROOT/android-sdk"
export ANDROID_AVD_HOME="$QUALIFICATION_TOOLS_ROOT/avd"
config=qualification/native/toolchain.json
python3 - "$config" "$mode" <<'PY'
import json, os, pathlib, re, shutil, sys
config = json.load(open(sys.argv[1]))
root = pathlib.Path(os.environ['QUALIFICATION_TOOLS_ROOT'])
if not root.is_absolute() or '\n' in str(root) or '\r' in str(root): raise SystemExit('Use an absolute dedicated tools directory without newlines')
minimum = os.environ['QUALIFICATION_MIN_FREE_GIB']
if not minimum.isdigit() or not 30 <= int(minimum) <= 500: raise SystemExit('Free-space requirement must be 30..500 GiB')
for name in ['QUALIFICATION_IOS_VERSION','QUALIFICATION_IOS_BUILD']:
 value = os.environ[name]
 if value and not re.fullmatch(r'[A-Za-z0-9.]+',value): raise SystemExit('Invalid pinned iOS version/build')
runtime=os.environ['QUALIFICATION_IOS_RUNTIME']
if runtime and not re.fullmatch(r'com[.]apple[.]CoreSimulator[.]SimRuntime[.]iOS-[0-9-]+',runtime): raise SystemExit('Invalid pinned iOS runtime identifier')
ancestor=root
while not ancestor.exists(): ancestor=ancestor.parent
free=shutil.disk_usage(ancestor).free/1024**3
print(f'Free disk: {free:.1f} GiB; required floor: {minimum} GiB')
print(f'Dedicated SDK: {root / "android-sdk"}')
print(f'Dedicated AVDs: {root / "avd"}')
print(f'Command tools archive: {config["commandLineTools"]["archive"]} (SHA-256 verified)')
for package in config['packages']: print(f'Ensure {package["path"]} exactly revision {package["revision"]}')
for avd in config['avds']: print(f'Ensure CI AVD {avd["name"]}, {avd["device"]}, {avd["image"]}')
print('iOS: explicit QUALIFICATION_IOS_VERSION, QUALIFICATION_IOS_BUILD and QUALIFICATION_IOS_RUNTIME required for --apply')
print('No Xcode license acceptance, sudo, shell-profile changes, personal AVD deletion, signing or publication.')
if sys.argv[2]=='--apply' and free < int(minimum): raise SystemExit('Insufficient free disk space; nothing installed')
PY
[[ "$mode" == --apply ]] || exit 0
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || { echo 'Apply requires native ARM64 macOS.' >&2; exit 1; }
: "${JAVA_HOME:?Use the workflow setup-java step to select a JDK 17 installation}"
: "${QUALIFICATION_IOS_VERSION:?Pin the exact iOS runtime version}"
: "${QUALIFICATION_IOS_BUILD:?Pin the exact Apple runtime build}"
: "${QUALIFICATION_IOS_RUNTIME:?Pin the CoreSimulator runtime identifier}"
for tool in python3 curl unzip shasum xcodebuild xcrun; do command -v "$tool" >/dev/null; done
java_version=$("$JAVA_HOME/bin/java" -version 2>&1)
[[ "$java_version" == *'version "17.'* ]] || { echo 'JDK 17 required.' >&2; exit 1; }
# Require a dedicated directory so an existing personal SDK/AVD tree is never adopted.
if [[ -d "$QUALIFICATION_TOOLS_ROOT" && ! -f "$QUALIFICATION_TOOLS_ROOT/.wuselwall-qualification" ]]; then
  [[ -z "$(ls -A "$QUALIFICATION_TOOLS_ROOT")" ]] || { echo 'Tools directory is not an owned empty CI directory.' >&2; exit 1; }
fi
mkdir -p "$QUALIFICATION_TOOLS_ROOT" "$ANDROID_HOME/cmdline-tools" "$ANDROID_AVD_HOME"
touch "$QUALIFICATION_TOOLS_ROOT/.wuselwall-qualification"
scratch=$(mktemp -d "$QUALIFICATION_TOOLS_ROOT/provision-XXXXXX")
trap 'rm -rf "$scratch"' EXIT INT TERM
read_config() { python3 -c 'import json,sys; value=json.load(open(sys.argv[1])); print(value["commandLineTools"][sys.argv[2]])' "$config" "$1"; }
build=$(read_config build)
archive=$(read_config archive)
archive_sha=$(read_config sha256)
tools="$ANDROID_HOME/cmdline-tools/$build"
if [[ ! -x "$tools/bin/sdkmanager" ]]; then
  [[ ! -e "$tools" ]] || { echo 'Partial command-tools install exists; inspect it before retrying.' >&2; exit 1; }
  curl --fail --location --retry 3 --connect-timeout 20 --max-time 1800 \
    "https://dl.google.com/android/repository/$archive" -o "$scratch/tools.zip"
  printf '%s  %s\n' "$archive_sha" "$scratch/tools.zip" | shasum -a 256 -c -
  unzip -q "$scratch/tools.zip" -d "$scratch/unpacked"
  mv "$scratch/unpacked/cmdline-tools" "$tools"
fi
export PATH="$JAVA_HOME/bin:$tools/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
python3 - "$tools/source.properties" "$(read_config revision)" <<'PY'
import pathlib,sys
props=dict(line.split('=',1) for line in pathlib.Path(sys.argv[1]).read_text().splitlines() if '=' in line)
assert props.get('Pkg.Revision','').strip()==sys.argv[2], 'Command-tools version differs from pin'
PY
sdkmanager="$tools/bin/sdkmanager"
if [[ "$QUALIFICATION_ACCEPT_ANDROID_LICENSES" == true ]]; then
  # Explicit operator opt-in; bounded answers avoid an unbounded yes process.
  answers=$(printf 'y\n%.0s' {1..100})
  "$sdkmanager" --sdk_root="$ANDROID_HOME" --licenses <<< "$answers"
fi
"$sdkmanager" --sdk_root="$ANDROID_HOME" --list --channel=0 > "$scratch/packages.txt"
python3 - "$config" "$ANDROID_HOME" "$scratch/packages.txt" > "$scratch/install.tsv" <<'PY'
import json,pathlib,sys
config=json.load(open(sys.argv[1])); sdk=pathlib.Path(sys.argv[2]); listing=pathlib.Path(sys.argv[3]).read_text()
for p in config['packages']:
 props=sdk/p['directory']/'source.properties'
 if props.exists():
  values=dict(line.split('=',1) for line in props.read_text().splitlines() if '=' in line)
  if values.get('Pkg.Revision','').strip()!=p['revision']: raise SystemExit(f'Installed SDK pin differs: {p["path"]}; inspect dedicated tools directory')
  continue
 versions=[line.split('|')[1].strip() for line in listing.splitlines() if len(line.split('|'))>1 and line.split('|')[0].strip()==p['path']]
 if p['revision'] not in versions: raise SystemExit(f'Pinned package revision no longer offered: {p["path"]} r{p["revision"]}; review toolchain pins')
 print(f'{p["path"]}\t{p["directory"]}\t{p["revision"]}')
PY
while IFS=$'\t' read -r package directory revision; do
  "$sdkmanager" --sdk_root="$ANDROID_HOME" --install "$package" --channel=0 </dev/null
  python3 - "$ANDROID_HOME/$directory/source.properties" "$revision" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); values=dict(line.split('=',1) for line in p.read_text().splitlines() if '=' in line)
assert values.get('Pkg.Revision','').strip()==sys.argv[2], f'Installed package revision differs: {p.parent.name}'
PY
done < "$scratch/install.tsv"
python3 - "$config" <<'PY' > "$scratch/avds.tsv"
import json,sys
for avd in json.load(open(sys.argv[1]))['avds']: print('\t'.join(avd[k] for k in ['name','device','image']))
PY
while IFS=$'\t' read -r name device image; do
  if [[ -f "$ANDROID_AVD_HOME/$name.avd/config.ini" ]]; then
    python3 - "$ANDROID_AVD_HOME/$name.avd/config.ini" "$image" "$device" <<'PY'
import pathlib,sys
props=dict(line.split('=',1) for line in pathlib.Path(sys.argv[1]).read_text().splitlines() if '=' in line)
assert props.get('abi.type')=='arm64-v8a', 'Existing CI AVD ABI differs'
assert props.get('image.sysdir.1','').rstrip('/')==sys.argv[2].replace(';','/'), 'Existing CI AVD image differs'
assert props.get('hw.device.name')==sys.argv[3], 'Existing CI AVD hardware profile differs'
PY
    continue
  fi
  printf 'no\n' | "$tools/bin/avdmanager" create avd --name "$name" --package "$image" --device "$device" --path "$ANDROID_AVD_HOME/$name.avd"
done < "$scratch/avds.tsv"
# Xcode and its license/first-launch setup are managed outside this script.
xcrun simctl list runtimes --json > "$scratch/runtimes.json"
if ! python3 - "$scratch/runtimes.json" <<'PY'
import json,os,sys
r=next((r for r in json.load(open(sys.argv[1]))['runtimes'] if r['identifier']==os.environ['QUALIFICATION_IOS_RUNTIME'] and r.get('isAvailable')),None)
if r is None: sys.exit(1)
if r.get('version')!=os.environ['QUALIFICATION_IOS_VERSION'] or r.get('buildversion')!=os.environ['QUALIFICATION_IOS_BUILD']: raise SystemExit('Installed iOS runtime differs from pinned version/build')
PY
then
  xcodebuild -downloadPlatform iOS -buildVersion "$QUALIFICATION_IOS_BUILD" -architectureVariant arm64
fi
xcrun simctl list runtimes --json | python3 -c 'import json,os,sys; r=next((r for r in json.load(sys.stdin)["runtimes"] if r["identifier"]==os.environ["QUALIFICATION_IOS_RUNTIME"] and r.get("isAvailable")),None); assert r and r["version"]==os.environ["QUALIFICATION_IOS_VERSION"] and r["buildversion"]==os.environ["QUALIFICATION_IOS_BUILD"], "Pinned iOS runtime missing after install"'
"$ANDROID_HOME/emulator/emulator" -accel-check
# Publish process-local settings for following Actions steps; no shell profiles change.
environment_file="$QUALIFICATION_TOOLS_ROOT/environment.env"
{
  printf 'ANDROID_HOME=%s\nANDROID_AVD_HOME=%s\n' "$ANDROID_HOME" "$ANDROID_AVD_HOME"
  printf 'QUALIFICATION_ANDROID_PHONE_AVD=ww-qualification-phone-api36\n'
  printf 'QUALIFICATION_ANDROID_TABLET_AVD=ww-qualification-tablet-api36\n'
  printf 'QUALIFICATION_ANDROID_MIN_PHONE_AVD=ww-qualification-phone-api24\n'
  printf 'QUALIFICATION_IOS_RUNTIME=%s\nQUALIFICATION_IOS_VERSION=%s\nQUALIFICATION_IOS_BUILD=%s\n' \
    "$QUALIFICATION_IOS_RUNTIME" "$QUALIFICATION_IOS_VERSION" "$QUALIFICATION_IOS_BUILD"
} > "$environment_file"
chmod 600 "$environment_file"
if [[ -n "${GITHUB_ENV:-}" ]]; then cat "$environment_file" >> "$GITHUB_ENV"; fi
printf 'Provisioned dedicated native tools. Environment: %s\n' "$environment_file"
