# Running the fly on the phone itself

`FlyInABox.apk` (the `apk` release of this repository) is the whole thing. Install it on an arm64
phone (any recent Galaxy, including the Z Fold), open it, tap Start. The first start unpacks the
runtime the app carries (about 1.5 GB, a few minutes); after that the FlyWire brain loads in a
minute or two, the kernels compile, and the page appears. Nothing to install besides the app,
no terminal, no account. The app keeps running in the background with a notification; Stop ends
the simulation, Start begins a new fly.

What to expect: on a current phone a simulated second takes one to three minutes of compute, so
the fly moves in slow motion; the status line shows the ratio. `--phone` renders two cameras
instead of five and updates the eyes at 25 Hz, which is where the saving is. The whole brain is
still there: nothing is cut. It needs about 2 GB of RAM while running and 3.5 GB of storage.

## How it is put together

The simulation is the same Python code as on a computer. The app carries a complete Linux user
space for it and runs it the way a computer would, inside its own app directory:

- `build_runtime.sh` builds that user space in a plain Ubuntu 20.04 container (one per CPU
  architecture, in `.github/workflows/runtime.yml`): CPython 3.12 (python-build-standalone), the
  packages (numpy, numba, MuJoCo, flygym, ...), Mesa's software renderer, the FlyWire data and
  this project. It is exported as an xz tarball and attached to the `apk` release.
- `.github/workflows/apk.yml` puts the tarball inside the APK as `assets/runtime.bin` and builds
  one APK per architecture (arm64 for phones, x86_64 for the emulator test).
- The app (`android/`) unpacks the tarball into its files directory on first start, then its
  foreground service starts `flybox.py --live 8765 --phone` through the runtime's own glibc
  loader, and the activity shows the live page from `127.0.0.1:8765` in a WebView.
- `flyboot.c` is the small launcher the service actually starts. Android's app sandbox answers a
  few system calls with SIGSYS, which kills a normal process (that is "exit 159"). flyboot needs
  no libc; it installs a handler for SIGSYS, then maps python and glibc's loader into the same
  process and jumps to the loader, the way the kernel starts a dynamically linked program, so
  the handler is there from the loader's first system call. The handler translates the old
  x86_64 calls that glibc 2.31 still uses (open, stat, access, readlink, poll, select, ...) into
  their modern forms, which the sandbox allows, and answers anything else with ENOSYS, logging
  the call number to `files/fly.log` (`[sandbox] Android refused system call N`). (Running the
  loader "as a program" instead, `ld.so --library-path ... python`, trips a glibc 2.31 bug on
  aarch64 that leaves `getauxval` empty, on which LLVM aborts.)
- `seccomp_jail.c` reproduces that sandbox on a Linux machine; the runtime workflow runs the
  smoke test under it. `run_relocated.sh` runs an unpacked runtime from any path the way the app
  does, and `emulator_test.sh` installs the x86_64 APK in an Android emulator and waits for the
  page.

If the app shows "the simulation ended (exit N)", the last lines of `files/fly.log` are on the
status screen; the log is also readable with `adb shell run-as com.flyinabox.app cat files/fly.log`.
