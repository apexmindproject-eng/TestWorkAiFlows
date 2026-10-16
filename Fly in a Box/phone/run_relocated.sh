#!/bin/bash
# Runs the fly from an unpacked runtime tree at any path, through the runtime's own glibc loader.
# This is exactly what the Android app does (in Kotlin); here it is used to test the runtime on a Linux machine.
#   run_relocated.sh <runtime dir> [flybox.py arguments...]
set -euo pipefail
RT=$(cd "$1" && pwd); shift
ARCH=$(uname -m)                      # aarch64 or x86_64
case "$ARCH" in aarch64) TRIPLE=aarch64-linux-gnu;; x86_64) TRIPLE=x86_64-linux-gnu;; *) echo "unsupported $ARCH"; exit 1;; esac
LD=$(ls "$RT/lib/$TRIPLE"/ld-2.*.so | head -1)   # the loader itself (the usual names are symlinks, some absolute)
PYHOME="$RT/opt/fly/python"; PYVER=$(basename "$(ls -d "$PYHOME"/lib/python3.* | head -1)")
mkdir -p "$RT/tmp/numba" "$RT/opt/fly/app/out"      # before LD_LIBRARY_PATH points this machine's tools at the runtime's glibc
cd "$RT/opt/fly/app"
export LD_LIBRARY_PATH="$PYHOME/lib:$RT/lib/$TRIPLE:$RT/usr/lib/$TRIPLE:$RT/lib:$RT/usr/lib"
export PYTHONHOME="$PYHOME" PYTHONPATH="$RT/opt/fly/venv/lib/$PYVER/site-packages" PYTHONNOUSERSITE=1
export HOME="$RT/root" TMPDIR="$RT/tmp" MUJOCO_GL=osmesa PYOPENGL_PLATFORM=osmesa LC_ALL=C.UTF-8
export PYGLFW_LIBRARY="$RT/opt/fly/libglfw.so"                 # see build_runtime.sh
export NUMBA_CACHE_DIR="$RT/tmp/numba" OMP_NUM_THREADS=${OMP_NUM_THREADS:-4} NUMBA_NUM_THREADS=${NUMBA_NUM_THREADS:-4}
# flyboot starts the loader with a SIGSYS handler already in place (Android refuses some system calls that way).
# FLY_WRAP (optional) is a command put in front, e.g. the seccomp jail; "--python ARGS" runs python itself instead of flybox.py.
if [ "${1:-}" = "--python" ]; then shift; exec ${FLY_WRAP:-} "$RT/opt/fly/flyboot" "$LD" --library-path "$LD_LIBRARY_PATH" "$PYHOME/bin/$PYVER" "$@"; fi
exec ${FLY_WRAP:-} "$RT/opt/fly/flyboot" "$LD" --library-path "$LD_LIBRARY_PATH" "$PYHOME/bin/$PYVER" flybox.py "$@"
