# Running the fly on the phone itself

The simulation is the same code everywhere: a Python process with the FlyWire brain (numba) and
the NeuroMechFly body (MuJoCo). Every package in it ships arm64 Linux wheels, so it runs on an
Android phone inside Termux's Ubuntu. Tested requirements: ~2 GB of RAM while running, ~3 GB of
storage, arm64 (any recent Galaxy, including the Z Fold).

1. Install Termux from F-Droid (the Play Store build is out of date).
2. In Termux: `curl -sL https://raw.githubusercontent.com/apexmindproject-eng/TestWorkAiFlows/claude/tanae-stuff-hhwfq6/Fly%20in%20a%20Box/phone/install.sh | bash`
   (or copy `install.sh` over and `bash install.sh`). Everything it fetches is public: this
   repository, the FlyWire data and the packages. Takes 10 to 20 minutes.
3. Start the fly: `bash ~/fly.sh`. The brain loads in about a minute.
4. Open the Fly in a Box app and choose "this phone" (it connects to 127.0.0.1:8765), or open that
   address in the browser. Keep Termux running in the background (it takes a wake lock).

What to expect: on a current phone a simulated second takes one to three minutes of compute, so
the fly moves in slow motion; the status line shows the ratio. `--phone` renders two cameras
instead of five and updates the eyes at 25 Hz, which is where the saving is. The whole brain is
still there: nothing is cut.

If a step fails, run the same command again: every step skips what is already there.
