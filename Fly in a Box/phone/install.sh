#!/data/data/com.termux/files/usr/bin/bash
# Fly in a Box on the phone itself. Run this once inside Termux (https://f-droid.org/packages/com.termux/).
#
# It installs a small Ubuntu (proot-distro), Python with MuJoCo, numba and flygym for arm64, the FlyWire
# brain data (about 400 MB) and this project, so the whole simulation (real brain, real body) runs on
# the phone. Needs about 3 GB of storage and 4 GB of free RAM while running. Expect 1 to 3 minutes of
# compute per simulated second on a current phone. Every step skips what is already done, so if it
# stops (slow mirror, screen off), just run it again.
step() { echo; echo "==> $*"; }
fail() { echo; echo "!! $*"; echo "!! Run this installer again once that is sorted; it continues where it stopped."; exit 1; }

step "Termux itself up to date (proot-distro needs the current Termux Python; a half-upgraded Termux fails with 'python3.14: bad interpreter')"
yes | pkg upgrade -y -o Dpkg::Options::="--force-confnew" || fail "Termux could not upgrade its packages. If the mirror is slow, run: termux-change-repo (pick a mirror group near you) and run this again."

step "Termux packages (proot-distro, git)"
yes | pkg install -y proot-distro git curl python || true
command -v proot-distro >/dev/null || fail "proot-distro did not install. Try: pkg update && pkg install proot-distro"
proot-distro list >/dev/null 2>&1 || fail "proot-distro does not run ($(head -1 "$(command -v proot-distro)")). Run: pkg upgrade && pkg install python, then this installer again."

step "Ubuntu for the phone (a 40 MB download the first time)"
ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu"
if [ ! -d "$ROOTFS/root" ]; then
    proot-distro install ubuntu || fail "Ubuntu did not install (see the error above; usually the download). Check the connection and run again."
fi
[ -d "$ROOTFS/root" ] || fail "Ubuntu's files are not where proot-distro puts them ($ROOTFS). Run: proot-distro list"

step "The run script (~/fly.sh)"
cat > "$HOME/fly.sh" <<'RUN'
#!/data/data/com.termux/files/usr/bin/bash
# Starts the simulation on this phone and serves it at http://127.0.0.1:8765 (the Fly in a Box app, or any browser).
termux-wake-lock 2>/dev/null || true
exec proot-distro login ubuntu -- bash -c 'cd "/root/TestWorkAiFlows/Fly in a Box" && . venv/bin/activate && MUJOCO_GL=osmesa OMP_NUM_THREADS=4 NUMBA_NUM_THREADS=4 python flybox.py --live 8765 --phone --out out/phone'
RUN
chmod +x "$HOME/fly.sh"

step "Inside Ubuntu: Python, MuJoCo, the brain data, the project (10 to 20 minutes, depends on the connection)"
cat > "$HOME/fly_setup_inside.sh" <<'INNER'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y python3 python3-venv python3-pip git curl libosmesa6 libgl1 libglu1-mesa libegl1 ffmpeg
cd /root
if [ ! -d TestWorkAiFlows ]; then
  echo "--- the project"
  git clone --depth 1 -b claude/tanae-stuff-hhwfq6 https://github.com/apexmindproject-eng/TestWorkAiFlows.git
else
  (cd TestWorkAiFlows && git pull -q || true)
fi
cd "/root/TestWorkAiFlows/Fly in a Box"
[ -d venv ] || python3 -m venv venv
. venv/bin/activate
pip install -q --upgrade pip
echo "--- Python packages (MuJoCo, numba, flygym...)"
pip install --prefer-binary numpy pandas pyarrow scipy numba imageio imageio-ffmpeg pillow flygym==2.1.0
echo "--- the FlyWire brain (400 MB, public)"
[ -d Drosophila_brain_model ] || git clone --depth 1 https://github.com/philshiu/Drosophila_brain_model.git
mkdir -p data out
[ -s data/flywire_annotations_783.tsv ] || curl -L -o data/flywire_annotations_783.tsv \
  https://raw.githubusercontent.com/flyconnectome/flywire_annotations/main/supplemental_files/Supplemental_file1_neuron_annotations.tsv
cp -n omm_centroids.npy out/
python -c "import mujoco, numba, flygym; print('MuJoCo', mujoco.__version__, 'numba', numba.__version__, 'flygym ok')"
echo; echo "Installed."
INNER
proot-distro login ubuntu --bind "$HOME/fly_setup_inside.sh:/root/fly_setup_inside.sh" -- bash /root/fly_setup_inside.sh \
    || fail "The setup inside Ubuntu stopped (see above)."

echo
echo "Done. Start the fly with:   bash ~/fly.sh"
echo "then open the Fly in a Box app (This phone), or http://127.0.0.1:8765 in the browser. The brain takes about a minute to load."
