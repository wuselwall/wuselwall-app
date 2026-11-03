#!/usr/bin/env python3
"""Run one native-tool phase with a bounded process-group lifetime."""
import math
import os
import signal
import subprocess
import sys
import time

TERM_GRACE_SECONDS = 5


def stop_group(process, sig=signal.SIGTERM):
    try:
        os.killpg(process.pid, sig)
    except ProcessLookupError:
        return
    deadline = time.monotonic() + TERM_GRACE_SECONDS
    while time.monotonic() < deadline:
        try:
            os.killpg(process.pid, 0)
        except ProcessLookupError:
            break
        process.poll()
        time.sleep(0.01)
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    try:
        process.wait(timeout=TERM_GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        print('NATIVE PHASE CLEANUP INCOMPLETE: child did not exit after SIGKILL', file=sys.stderr, flush=True)


def main(argv):
    if len(argv) < 4 or argv[2] != '--':
        print('Usage: deadline.py <positive-seconds> <phase-name> -- <command> [args...]', file=sys.stderr)
        return 2
    try:
        timeout = float(argv[0])
    except ValueError:
        print('Phase timeout must be a finite positive number.', file=sys.stderr)
        return 2
    phase = argv[1]
    command = argv[3:]
    if not math.isfinite(timeout) or timeout <= 0:
        print('Phase timeout must be a finite positive number.', file=sys.stderr)
        return 2
    if not phase or any(ch in phase for ch in '\r\n') or not command:
        print('Phase name and command are required.', file=sys.stderr)
        return 2

    print(f'NATIVE PHASE BEGIN {phase} timeout={timeout:g}s', file=sys.stderr, flush=True)
    received_signal = []
    process = None

    def forward(sig, _frame):
        if not received_signal:
            received_signal.append(sig)
        if process is None:
            return
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            pass

    previous_handlers = {sig: signal.signal(sig, forward) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        try:
            process = subprocess.Popen(command, start_new_session=True)
        except OSError as error:
            print(f'NATIVE PHASE START FAILED {phase}: {error.strerror}', file=sys.stderr, flush=True)
            return 127
        expires = time.monotonic() + timeout
        while True:
            if received_signal:
                stop_group(process)
                return 128 + received_signal[0]
            remaining = expires - time.monotonic()
            if remaining <= 0:
                print(f'NATIVE PHASE TIMEOUT {phase} after {timeout:g}s', file=sys.stderr, flush=True)
                stop_group(process)
                return 124
            try:
                return_code = process.wait(timeout=min(remaining, 0.05))
                exit_code = return_code if return_code >= 0 else 128 + -return_code
                print(f'NATIVE PHASE END {phase} exit={exit_code}', file=sys.stderr, flush=True)
                return exit_code
            except subprocess.TimeoutExpired:
                continue
    finally:
        for sig, handler in previous_handlers.items():
            signal.signal(sig, handler)
        if process is not None and process.poll() is None:
            stop_group(process)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
