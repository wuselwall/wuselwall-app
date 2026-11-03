#!/usr/bin/env python3
"""Emit safe, read-only metadata about the dedicated native tools cache."""
import json
import os
import pathlib
import stat
import sys


def access(path, kind='directory'):
    try:
        info = path.stat()
        if kind == 'file' and not stat.S_ISREG(info.st_mode):
            return {'exists': False, 'readable': False, 'error': 'not_regular'}
        if kind == 'directory' and not stat.S_ISDIR(info.st_mode):
            return {'exists': False, 'readable': False, 'error': 'not_directory'}
        return {'exists': True, 'readable': os.access(path, os.R_OK)}
    except OSError as exc:
        return {'exists': False, 'readable': False, 'error': f'errno_{exc.errno}'}


def within(path, root):
    try:
        return path.is_absolute() and path.resolve().is_relative_to(root.resolve())
    except (OSError, RuntimeError):
        return False


def main():
    configured = os.environ.get('QUALIFICATION_TOOLS_ROOT')
    if configured:
        root = pathlib.Path(configured)
        root_label = 'configured'
    else:
        cache = os.environ.get('XDG_CACHE_HOME') or str(pathlib.Path.home() / '.cache')
        root = pathlib.Path(cache) / 'wuselwall-qualification'
        root_label = 'default'

    # Only inspect this dedicated cache root and its known, immediate children.
    root_state = access(root)
    root_state['label'] = root_label
    result = {'tools_root': root_state}
    if not root.is_absolute():
        result['tools_root']['error'] = 'not_absolute'
        print(json.dumps(result, sort_keys=True))
        return

    marker = root / '.wuselwall-qualification'
    envfile = root / 'environment.env'
    marker_state = access(marker, 'file')
    if marker.is_symlink():
        marker_state = {'exists': True, 'readable': False, 'error': 'symlink'}
    result['ownership_marker'] = marker_state
    env_state = access(envfile, 'file')
    if envfile.is_symlink():
        env_state = {'exists': True, 'readable': False, 'error': 'symlink'}
    try:
        info = envfile.lstat()
        env_state['owner_matches_process'] = info.st_uid == os.getuid()
        env_state['permission_mode'] = format(stat.S_IMODE(info.st_mode), '04o')
    except OSError as exc:
        env_state['owner_matches_process'] = False
        env_state['permission_mode'] = None
        env_state.setdefault('error', f'errno_{exc.errno}')
    result['environment_file'] = env_state

    # Read only the two path settings needed to probe known files. Never emit values.
    values = {}
    if env_state.get('readable') and not envfile.is_symlink():
        try:
            for line in envfile.read_text().splitlines():
                key, sep, value = line.partition('=')
                if sep and key in ('ANDROID_HOME', 'ANDROID_AVD_HOME') and key not in values:
                    values[key] = value
        except OSError as exc:
            result['environment_file']['readable'] = False
            result['environment_file']['error'] = f'errno_{exc.errno}'

    sdk = os.environ.get('ANDROID_HOME') or values.get('ANDROID_HOME') or str(root / 'android-sdk')
    avd = os.environ.get('ANDROID_AVD_HOME') or values.get('ANDROID_AVD_HOME') or str(root / 'avd')
    for key, path in (('android_sdk', sdk), ('avd_directory', avd)):
        if not path:
            result[key] = {'exists': False, 'readable': False, 'error': 'not_configured'}
            continue
        candidate = pathlib.Path(path)
        if not within(candidate, root):
            result[key] = {'exists': False, 'readable': False, 'error': 'outside_tools_root'}
            continue
        result[key] = access(candidate)
        if key == 'android_sdk':
            adb = candidate / 'platform-tools' / 'adb'
            result['adb'] = access(adb, 'file')

    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        # Keep diagnostics useful without exposing exception text or paths.
        err = getattr(exc, 'errno', None)
        print(json.dumps({'diagnostic_error': f'errno_{err}' if err else 'probe_error'}, sort_keys=True))
