#!/bin/bash
# Builds the self-contained runtime the Android app carries: an Ubuntu file tree with Python, MuJoCo, numba,
# flygym, the FlyWire brain data and this project, for one CPU architecture. Runs inside a plain Ubuntu
# container (see .github/workflows/runtime.yml); the result is exported as a tarball and later unpacked by
# the app into its own storage, where it is executed through glibc's loader (no root, no terminal).
set -euo pipefail
SRC=${1:-/src}                     # the repository checkout, mounted into the container
# Base: Ubuntu 20.04, deliberately. Its glibc (2.31) predates the clone3 and rseq system calls that newer glibc
# uses at start-up and that Android's app sandbox kills with SIGSYS. Python itself is a relocatable CPython 3.12
# build from python-build-standalone (astral-sh), which runs on any glibc from 2.17 up.
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git libosmesa6 libgl1 libglu1-mesa libegl1 libglvnd0 libgomp1 libstdc++6 \
    libffi7 libssl1.1 zlib1g libbz2-1.0 liblzma5 libsqlite3-0 libncursesw6 libreadline8 libuuid1
ARCH=$(uname -m)
if [ -z "${PBS_URL:-}" ]; then      # normally handed in by the workflow (the API is rate-limited from inside the container)
    PBS_URL=$(curl -sL https://api.github.com/repos/astral-sh/python-build-standalone/releases/latest \
        | grep -o "https://[^\"]*cpython-3\.12\.[0-9]*+[0-9]*-${ARCH}-unknown-linux-gnu-install_only\.tar\.gz" | head -1 || true)
fi
[ -n "$PBS_URL" ] || { echo "no CPython build URL"; exit 1; }
echo "python: $PBS_URL"
mkdir -p /opt/fly && curl -sL "$PBS_URL" | tar -xzf - -C /opt/fly          # -> /opt/fly/python
mkdir -p /opt/fly && cd /opt/fly
# the project (code and small data only)
rm -rf app && mkdir app
(cd "$SRC/Fly in a Box" && tar --exclude=android --exclude=videos --exclude=phone --exclude=out --exclude=venv --exclude=__pycache__ -cf - .) | tar -xf - -C app
# python and the packages
/opt/fly/python/bin/python3.12 -m venv venv
. venv/bin/activate
pip install --no-cache-dir --upgrade pip
pip install --no-cache-dir --prefer-binary numpy pandas pyarrow scipy numba imageio imageio-ffmpeg pillow flygym==2.1.0
# the brain: FlyWire v783 connectivity (Shiu et al.) and the neuron annotations
cd app
git clone --depth 1 https://github.com/philshiu/Drosophila_brain_model.git
rm -rf Drosophila_brain_model/.git Drosophila_brain_model/*630*
mkdir -p data out
curl -sL -o data/flywire_annotations_783.tsv \
    https://raw.githubusercontent.com/flyconnectome/flywire_annotations/main/supplemental_files/Supplemental_file1_neuron_annotations.tsv
cp omm_centroids.npy out/
# smoke test in place: the whole loop for a third of a second (loads the brain, compiles the kernels, renders)
MUJOCO_GL=osmesa python flybox.py --seconds 0.3 --phone --out out/smoke 2>&1 | tail -5
rm -rf out/smoke
# slim down: the app carries all of this inside the APK
apt-get install -y --no-install-recommends binutils
find /opt/fly/venv /opt/fly/python /usr/lib -xdev \( -name "*.so" -o -name "*.so.*" \) -type f -exec strip --strip-unneeded {} + 2>/dev/null || true
apt-get purge -y binutils; apt-get autoremove -y; apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/* /usr/share/doc /usr/share/man /usr/share/info /usr/share/locale /usr/share/i18n /root/.cache
rm -rf /opt/fly/python/lib/python3*/test /opt/fly/python/lib/python3*/idlelib /opt/fly/python/lib/python3*/tkinter /opt/fly/python/lib/python3*/turtledemo /opt/fly/python/lib/python3*/ensurepip /opt/fly/python/lib/python3*/site-packages/pip /opt/fly/python/share
rm -rf /opt/fly/venv/lib/python3*/site-packages/pip /opt/fly/venv/lib/python3*/site-packages/setuptools
find / -xdev -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true
# the kernels compile again on first start on the phone; the caches would be for this machine's CPU anyway
MUJOCO_GL=osmesa python -c "import flygym, mujoco, numba, pandas, pyarrow, platform; print('imports ok after slimming; glibc', platform.libc_ver())"
echo "runtime built: $(du -sh / --exclude=proc --exclude=sys --exclude=dev 2>/dev/null | cut -f1)"
