#!/usr/bin/env bash
# Load known persisted CI settings as data; never source/eval an environment file.
set -euo pipefail
mode="${1:-full}"
[[ "$mode" == full || "$mode" == diagnostic ]] || { echo 'Native tool loader mode must be full or diagnostic.' >&2; exit 1; }
export QUALIFICATION_TOOLS_MODE="$mode"
: "${QUALIFICATION_TOOLS_ROOT:=${RUNNER_TOOL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}}/wuselwall-qualification}"
export QUALIFICATION_TOOLS_ROOT
python3 - <<'PY'
import os,pathlib,re,stat
root=pathlib.Path(os.environ['QUALIFICATION_TOOLS_ROOT'])
if not root.is_absolute() or any(c in str(root) for c in '\r\n'): raise SystemExit('Invalid dedicated tools root')
all_settings=['ANDROID_HOME','ANDROID_AVD_HOME','QUALIFICATION_ANDROID_PHONE_AVD','QUALIFICATION_ANDROID_TABLET_AVD','QUALIFICATION_ANDROID_MIN_PHONE_AVD','QUALIFICATION_IOS_RUNTIME']
required=[] if os.environ.get('QUALIFICATION_TOOLS_MODE') == 'diagnostic' else all_settings
known=all_settings+['QUALIFICATION_IOS_VERSION','QUALIFICATION_IOS_BUILD']
def validate(key,value):
 if not value or any(c in value for c in '\r\n'): raise SystemExit(f'Invalid native tools value: {key}')
 if key in ['ANDROID_HOME','ANDROID_AVD_HOME']:
  if not pathlib.Path(value).is_absolute(): raise SystemExit(f'Native tool directory must be absolute: {key}')
 elif key=='QUALIFICATION_IOS_RUNTIME':
  if not re.fullmatch(r'com[.]apple[.]CoreSimulator[.]SimRuntime[.]iOS-[0-9-]+',value): raise SystemExit('Invalid pinned iOS runtime identifier')
 elif key=='QUALIFICATION_IOS_VERSION':
  if not re.fullmatch(r'[0-9]+(?:[.][0-9]+)*',value): raise SystemExit('Invalid pinned iOS version')
 elif key=='QUALIFICATION_IOS_BUILD':
  if not re.fullmatch(r'[A-Za-z0-9]+',value): raise SystemExit('Invalid pinned iOS build')
 elif not re.fullmatch(r'[A-Za-z0-9_.-]+',value): raise SystemExit(f'Invalid AVD name: {key}')
file=root/'environment.env'
saved={}
if file.exists():
 if not (root/'.wuselwall-qualification').is_file(): raise SystemExit('Persistent tools directory has no provisioning ownership marker')
 if file.is_symlink() or root.resolve() not in file.resolve().parents: raise SystemExit('Unsafe persistent environment file')
 info=file.stat()
 if info.st_uid!=os.getuid() or info.st_mode & 0o022: raise SystemExit('Persistent environment file must be owned by the runner and not writable by others')
 for line in file.read_text().splitlines():
  if not line: continue
  if '=' not in line: raise SystemExit('Malformed persistent environment line')
  key,value=line.split('=',1)
  if key not in known or key in saved: raise SystemExit('Unknown or repeated persistent environment key')
  validate(key,value)
  if key in ['ANDROID_HOME','ANDROID_AVD_HOME'] and root.resolve() not in pathlib.Path(value).resolve().parents: raise SystemExit('Persisted Android paths must stay inside the dedicated tools root')
  saved[key]=value
settings={key:os.environ.get(key) or saved.get(key) for key in known}
for key in required:
 if not settings[key]: raise SystemExit(f'Missing native tools setting: {key}; provision the dedicated CI tools or configure it explicitly')
for key,value in settings.items():
 if value: validate(key,value)
lines=f'QUALIFICATION_TOOLS_ROOT={root}\n'+''.join(f'{key}={value}\n' for key,value in settings.items() if value)
if os.environ.get('GITHUB_ENV'):
 with open(os.environ['GITHUB_ENV'],'a') as output: output.write(lines)
print('Native tool settings loaded; explicit nonempty CI variables take precedence.')
PY
