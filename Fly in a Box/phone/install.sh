#!/data/data/com.termux/files/usr/bin/bash
# Fly in a Box on the phone itself. Run this once inside Termux (https://f-droid.org/packages/com.termux/).
#
# It installs a small Ubuntu (proot-distro), Python with MuJoCo, numba and flygym for arm64, the FlyWire
# brain data (about 400 MB) and this project, so the whole simulation (real brain, real body) runs on
# the phone. Needs about 3 GB of storage and 4 GB of free RAM while running. Expect 1 to 3 minutes of
# compute per simulated second on a current phone.
set -e
pkg update -y && pkg install -y proot-distro git wget
proot-distro install ubuntu 2>/dev/null || true
ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu"
cat > "$ROOTFS/root/fly_setup_inside.sh" <<'INNER'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y python3 python3-venv python3-pip git curl libosmesa6 libgl1 libglu1-mesa libegl1 ffmpeg
cd /root
if [ ! -d TestWorkAiFlows ]; then
  echo; echo "Cloning the project (GitHub asks for your user name and a personal access token):"
  git clone --depth 1 -b claude/tanae-stuff-hhwfq6 https://github.com/apexmindproject-eng/TestWorkAiFlows.git
fi
cd "/root/TestWorkAiFlows/Fly in a Box"
[ -d venv ] || python3 -m venv venv
. venv/bin/activate
pip install --upgrade pip
pip install numpy pandas pyarrow scipy numba imageio imageio-ffmpeg pillow flygym==2.1.0
[ -d Drosophila_brain_model ] || git clone --depth 1 https://github.com/philshiu/Drosophila_brain_model.git
mkdir -p data out
[ -f data/flywire_annotations_783.tsv ] || curl -sL -o data/flywire_annotations_783.tsv \
  https://raw.githubusercontent.com/flyconnectome/flywire_annotations/main/supplemental_files/Supplemental_file1_neuron_annotations.tsv
cp -n omm_centroids.npy out/
echo; echo "Installed. Start the fly with:  bash ~/fly.sh   (then open the app, or http://127.0.0.1:8765 in the browser)"
INNER
proot-distro login ubuntu -- bash /root/fly_setup_inside.sh
cat > "$HOME/fly.sh" <<'RUN'
#!/data/data/com.termux/files/usr/bin/bash
# Starts the simulation on this phone and serves it at http://127.0.0.1:8765 (the Fly in a Box app, or any browser).
termux-wake-lock 2>/dev/null || true
exec proot-distro login ubuntu -- bash -c 'cd "/root/TestWorkAiFlows/Fly in a Box" && . venv/bin/activate && MUJOCO_GL=osmesa OMP_NUM_THREADS=4 NUMBA_NUM_THREADS=4 python flybox.py --live 8765 --phone --out out/phone'
RUN
chmod +x "$HOME/fly.sh"
echo; echo "Done. Run:  bash ~/fly.sh"
