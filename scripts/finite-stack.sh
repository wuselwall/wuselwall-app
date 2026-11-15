#!/usr/bin/env bash
# Runs a command with a finite stack limit, for `flutter test`:
#
#   scripts/finite-stack.sh flutter test …
#
# flutter_tester dies of SIGSEGV at random when it runs with an unlimited stack limit
# (`ulimit -s unlimited`, which some container hosts hand to every process). `flutter test`
# starts the tester with the Dart VM's profiler on, and the profiler interrupts the main
# thread a thousand times a second to walk its native stack by frame pointers. Native code
# built without frame pointers leaves arbitrary values in that register, so the walker
# follows a frame pointer only inside the thread's stack. It takes the stack's bounds from
# pthread_getattr_np, and for the main thread glibc derives the size from the stack limit:
# with no limit, the "stack" is everything between the stack's top and the mapping below
# it, tens of terabytes of mostly unmapped address space that begins at the end of the heap.
# An arbitrary value that points there passes the check and is read, and the tester dies.
#
# With a limit the bounds are the real stack and the same value is refused. Only an
# unlimited soft limit is lowered; a limit somebody set stays.
set -euo pipefail
if [ "$(ulimit -S -s)" = unlimited ]; then ulimit -S -s 8192; fi
exec "$@"
