"""Fly in a Box for Windows: starts the simulation and opens the live view in its own window.

Installed layout:  <install dir>\launcher.pyw      this file (run with python\pythonw.exe, no console)
                   <install dir>\python\           CPython 3.12 with numpy, numba, MuJoCo, flygym, ...
                   <install dir>\app\              flybox.py and the rest of the project, the FlyWire data

Two modes:
  standard (default)  the published brain (every neuron, 0.1 ms steps), full-resolution eyes rendered by the graphics
                      chip, the body at 0.25 ms on the ground (tested to behave exactly as at 0.1 ms) and 0.1 ms in
                      flight; the brain runs alongside the body on the other cores.
  --full              every physics step at 0.1 ms and the brain strictly before the body, as in the videos.
"""
import os, sys, subprocess, threading, time, socket, urllib.request, webbrowser, shutil
import tkinter as tk
from tkinter import ttk

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, "app")
PY = os.path.join(HERE, "python", "python.exe")
FULL = "--full" in sys.argv
DATA = os.path.join(os.environ.get("LOCALAPPDATA", HERE), "FlyInABox")
os.makedirs(DATA, exist_ok=True)
LOG = os.path.join(DATA, "fly.log")


def free_port(preferred=8765):
    for p in [preferred] + list(range(8766, 8800)):
        with socket.socket() as s:
            try:
                s.bind(("127.0.0.1", p)); return p
            except OSError:
                continue
    return preferred


PORT = free_port()
URL = f"http://127.0.0.1:{PORT}/?quality=high"
CORES = os.cpu_count() or 4


class App:
    def __init__(self):
        self.proc = None; self.viewer = None; self.ready = False; self.closing = False
        self.root = tk.Tk(); self.root.title("Fly in a Box"); self.root.geometry("640x380"); self.root.configure(bg="#0b0b10")
        self.root.protocol("WM_DELETE_WINDOW", self.quit)
        st = ttk.Style(); st.theme_use("clam")
        st.configure("TButton", padding=8, font=("Segoe UI", 11)); st.configure("TLabel", background="#0b0b10", foreground="#e8e8f0")
        ttk.Label(self.root, text="Fly in a Box", font=("Segoe UI", 18, "bold")).pack(anchor="w", padx=16, pady=(14, 0))
        ttk.Label(self.root, text=("full physics: every step at 0.1 ms" if FULL else "standard: published brain, full-resolution eyes")
                  + f"  ·  {CORES} cores", font=("Segoe UI", 10)).pack(anchor="w", padx=16)
        self.status = ttk.Label(self.root, text="starting…", font=("Segoe UI", 12)); self.status.pack(anchor="w", padx=16, pady=(12, 4))
        self.bar = ttk.Progressbar(self.root, mode="indeterminate"); self.bar.pack(fill="x", padx=16); self.bar.start(12)
        self.logbox = tk.Text(self.root, height=8, bg="#14141d", fg="#9a9ab0", relief="flat", font=("Consolas", 9)); self.logbox.pack(fill="both", expand=True, padx=16, pady=10)
        row = tk.Frame(self.root, bg="#0b0b10"); row.pack(fill="x", padx=16, pady=(0, 14))
        self.open_btn = ttk.Button(row, text="Open the live view", command=self.open_viewer, state="disabled"); self.open_btn.pack(side="left")
        ttk.Button(row, text="Quit", command=self.quit).pack(side="right")
        self.start()
        self.root.after(1000, self.poll)

    def say(self, text):
        self.status.configure(text=text)

    def log(self, line):
        self.logbox.insert("end", line + "\n"); self.logbox.see("end")
        if int(self.logbox.index("end-1c").split(".")[0]) > 400: self.logbox.delete("1.0", "100.0")

    def start(self):
        env = dict(os.environ)
        threads = str(max(2, CORES - 1))                                   # one core stays free for the body (physics)
        env.update({"PYTHONUNBUFFERED": "1", "NUMBA_CACHE_DIR": os.path.join(DATA, "numba"), "NUMBA_NUM_THREADS": threads,
                    "OMP_NUM_THREADS": threads, "OPENBLAS_NUM_THREADS": "1", "JE_ARROW_MALLOC_CONF": "background_thread:false"})
        env.pop("MUJOCO_GL", None)                                         # Windows: the graphics chip (WGL) renders the eyes
        args = [PY, "flybox.py", "--live", str(PORT), "--host", "127.0.0.1", "--out", "out/live"]
        args += ["--pipeline", "0"] if FULL else ["--pipeline", "1", "--phys-dt", "2.5e-4", "--ctrl-dt", "1e-3"]
        self.logf = open(LOG, "w", encoding="utf-8", errors="replace")
        self.proc = subprocess.Popen(args, cwd=APP, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                     encoding="utf-8", errors="replace", creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        threading.Thread(target=self.read_output, daemon=True).start()
        self.say("loading the brain: 138,639 neurons, 15 million synapses…")

    def read_output(self):
        for line in self.proc.stdout:
            line = line.rstrip(); self.logf.write(line + "\n"); self.logf.flush()
            if not line.strip().startswith("t="):
                self.root.after(0, self.log, line[:160])
            if line.startswith("[brain]"): self.root.after(0, self.say, "building the body and the box…")
            elif line.startswith("[map]"): self.root.after(0, self.say, "wiring the eyes to the brain…")
            elif line.startswith("[run]"): self.root.after(0, self.say, "compiling the brain for this computer (first start only, about a minute)…")

    def poll(self):
        if self.closing: return
        if self.proc and self.proc.poll() is not None:
            self.bar.stop(); self.say(f"the simulation stopped (exit {self.proc.returncode}); the log is in {LOG}")
            return
        if not self.ready:
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/state", timeout=1) as r:
                    if b'"t"' in r.read():
                        self.ready = True; self.bar.stop(); self.bar.configure(mode="determinate", value=100)
                        self.say("running. The live view is open; close it any time and reopen it here.")
                        self.open_btn.configure(state="normal"); self.open_viewer()
            except Exception:
                pass
        self.root.after(1000, self.poll)

    def open_viewer(self):
        """Edge (on every Windows 10 and 11) or Chrome in app mode: a plain window, drawn by the graphics chip."""
        if self.viewer and self.viewer.poll() is None: return
        cands = [os.path.join(os.environ.get(v, ""), *p) for v in ("ProgramFiles(x86)", "ProgramFiles", "LOCALAPPDATA")
                 for p in (("Microsoft", "Edge", "Application", "msedge.exe"), ("Google", "Chrome", "Application", "chrome.exe"))]
        exe = next((c for c in cands if os.path.isfile(c)), None) or shutil.which("msedge") or shutil.which("chrome")
        if exe:
            prof = os.path.join(DATA, "viewer")
            self.viewer = subprocess.Popen([exe, f"--app={URL}", "--window-size=1600,1000", f"--user-data-dir={prof}",
                                            "--no-first-run", "--no-default-browser-check", "--ignore-gpu-blocklist"])
        else:
            webbrowser.open(URL)

    def quit(self):
        self.closing = True
        for p in (self.viewer, self.proc):
            try:
                if p and p.poll() is None: p.terminate()
            except Exception:
                pass
        self.root.destroy()


if __name__ == "__main__":
    App().root.mainloop()
