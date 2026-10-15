"""Sandbox mode: a small web server inside the simulation.

The simulation itself runs on a computer (it needs the 15-million-synapse brain and MuJoCo); any
phone or browser on the same network connects to it and watches the fly live, and can poke it.
`flybox.py --live 8765` starts it; open http://<computer>:8765/ (the Android app does the same).

What it serves: /            the control page
                /stream.mjpg the chosen camera, as it is rendered (motion JPEG, no plugins)
                /state       what the fly is doing, as JSON
                /cmd         POST {"cmd": ...} -> queued, applied by the simulation at its next tick
"""
import io, json, queue, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import numpy as np
from PIL import Image, ImageDraw, ImageFont

try:
    FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
    FONT_B = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24)
except OSError:
    FONT = FONT_B = ImageFont.load_default()

LABELS = {"walk": "walking", "pause": "pausing", "wall": "following the wall", "feed": "FEEDING", "escape": "ESCAPE",
          "groom:front rub": "grooming: front legs", "groom:head groom": "grooming: head", "groom:hind rub": "grooming: hind legs",
          "approach": "walking up to the wall", "mount": "CLIMBING: rearing up", "climb": "CLIMBING the wall", "turnaround": "turning round on the wall",
          "descend": "walking down the wall", "takeoff": "TAKE-OFF (giant fibre)", "surface_takeoff": "TAKE-OFF from the wall", "flight": "FLYING",
          "landing": "landing", "touchdown": "landing", "land_wall": "flying to a wall", "grab_wall": "LANDING: wall", "land_ceiling": "flying up to the lid",
          "flip_ceiling": "LANDING: lid, the flip", "grab_ceiling": "LANDING: lid", "ceiling": "on the lid, upside down"}
CAMERAS = ["follow", "close", "overhead", "follow_b", "close_b"]

PAGE = r"""<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<title>Fly in a Box</title><style>
body{margin:0;background:#0b0b10;color:#e8e8f0;font-family:system-ui,sans-serif;-webkit-user-select:none;user-select:none}
#view{width:100%;display:block;background:#000}
#bar{padding:6px 10px;font-size:14px;color:#bbc}
#bar b{color:#8cf}
.row{display:flex;flex-wrap:wrap;gap:6px;padding:4px 8px}
button{flex:1 1 30%;padding:12px 6px;font-size:15px;border:0;border-radius:10px;background:#23233a;color:#e8e8f0}
button:active{background:#3a3a6a}
button.hot{background:#6a2a2a} button.on{background:#2a5a3a}
label{font-size:13px;color:#bbc;flex:1 1 100%}
input[type=range]{width:100%}
#over{width:100%;display:block;border-radius:8px}
.small{font-size:12px;color:#889;padding:0 10px 10px}
</style></head><body>
<img id="view" src="/stream.mjpg">
<div id="bar">connecting…</div>
<div class="row">
 <button class="hot" onclick="cmd('shadow')">shadow (loom)</button>
 <button class="hot" onclick="cmd('poke')">poke</button>
 <button class="hot" onclick="cmd('toss')">toss into the air</button>
 <button onclick="cmd('drop')">drop on its back</button>
 <button onclick="cmd('place',{where:'lid'})">put on the lid</button>
 <button onclick="cmd('place',{where:'wall'})">put on a wall</button>
 <button id="blind" onclick="toggle('blindfold')">blindfold</button>
 <button id="pause" onclick="toggle('pause')">pause</button>
 <button onclick="nextCam()">camera: <span id="cam">follow</span></button>
 <label>hunger <input type="range" min="0" max="100" value="90" id="hunger" onchange="cmd('hunger',{value:this.value/100})"></label>
 <label>tap the arena to move the food</label>
 <img id="over" src="/overhead.jpg" onclick="food(event)">
</div>
<div class="small">The fly is a real FlyWire brain (138,639 neurons) in a NeuroMechFly body. Sim time runs about 50x slower than the clock: every second you watch is 20 ms of fly time.</div>
<script>
const cams=["follow","close","overhead","follow_b","close_b"];let ci=0;const st={};
function cmd(c,extra){fetch('/cmd',{method:'POST',body:JSON.stringify(Object.assign({cmd:c},extra||{}))});}
function toggle(c){cmd(c);}
function nextCam(){ci=(ci+1)%cams.length;document.getElementById('cam').textContent=cams[ci];cmd('camera',{name:cams[ci]});}
function food(e){const r=e.target.getBoundingClientRect();const u=(e.clientX-r.left)/r.width,v=(e.clientY-r.top)/r.height;cmd('food',{u:u,v:v});}
async function poll(){try{const s=await (await fetch('/state')).json();Object.assign(st,s);
 document.getElementById('bar').innerHTML=`<b>${s.label}</b> &nbsp; t = ${s.t.toFixed(1)} s &nbsp; hunger ${(100*s.hunger).toFixed(0)}% &nbsp; ${s.speed.toFixed(3)}x realtime<br>`+
 `giant fibre ${s.rates.DNp01} Hz · turn DNa02 ${s.rates.DNa02} · proboscis MN9 ${s.rates.MN9} · reward PAM ${s.rates.PAMrw} · spikes/10ms ${s.spikes}<br>`+
 `take-offs ${s.events.takeoff} · wall landings ${s.events.wall_landing} · lid landings ${s.events.ceiling_landing} · meals ${s.events.feeding} · rightings ${s.events.righting}`;
 document.getElementById('blind').className=s.blindfold?'on':'';document.getElementById('pause').className=s.paused?'on':'';
 }catch(err){document.getElementById('bar').textContent='waiting for the simulation…';}
 setTimeout(poll,1000);}
poll();setInterval(()=>{document.getElementById('over').src='/overhead.jpg?'+Date.now();},2000);
</script></body></html>"""


class Live:
    """Shared between the simulation thread (which writes frames/state and pops commands) and the server threads."""
    def __init__(self, port):
        self.frame = None; self.overhead = None; self.state = {"label": "starting", "t": 0.0}; self.cmds = queue.Queue()
        self.paused = False; self.blindfold = False; self.camera = "follow"; self.version = 0; self.cv = threading.Condition()
        live = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *a): pass
            def _send(self, code, ctype, body):
                self.send_response(code); self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(body)))
                self.send_header("Access-Control-Allow-Origin", "*"); self.end_headers(); self.wfile.write(body)
            def do_GET(self):
                path = self.path.split("?")[0]
                if path == "/": self._send(200, "text/html; charset=utf-8", PAGE.encode())
                elif path == "/state": self._send(200, "application/json", json.dumps(dict(live.state, paused=live.paused, blindfold=live.blindfold, camera=live.camera)).encode())
                elif path == "/overhead.jpg": self._send(200, "image/jpeg", live.overhead or b"")
                elif path == "/frame.jpg": self._send(200, "image/jpeg", live.frame or b"")
                elif path == "/stream.mjpg":
                    self.send_response(200); self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=frame"); self.send_header("Cache-Control", "no-cache"); self.end_headers()
                    seen = -1
                    try:
                        while True:
                            with live.cv:
                                live.cv.wait_for(lambda: live.version != seen, timeout=2.0); seen = live.version; fr = live.frame
                            if fr is None: continue
                            self.wfile.write(b"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: " + str(len(fr)).encode() + b"\r\n\r\n" + fr + b"\r\n")
                    except (BrokenPipeError, ConnectionResetError): pass
                else: self._send(404, "text/plain", b"not found")
            def do_POST(self):
                n = int(self.headers.get("Content-Length", 0)); body = self.rfile.read(n) if n else b"{}"
                try: c = json.loads(body or b"{}")
                except ValueError: c = {}
                if self.path == "/cmd" and isinstance(c, dict) and "cmd" in c:
                    if c["cmd"] == "pause": live.paused = not live.paused
                    elif c["cmd"] == "blindfold": live.blindfold = not live.blindfold
                    elif c["cmd"] == "camera": live.camera = c.get("name") if c.get("name") in CAMERAS else live.camera
                    else: live.cmds.put(c)
                    self._send(200, "application/json", b'{"ok": true}')
                else: self._send(400, "application/json", b'{"ok": false}')
        self.server = ThreadingHTTPServer(("0.0.0.0", port), Handler); self.server.daemon_threads = True
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        print(f"[live] sandbox at http://0.0.0.0:{port}/  (open it on the phone with this computer's address)", flush=True)

    def pop_all(self):
        out = []
        while True:
            try: out.append(self.cmds.get_nowait())
            except queue.Empty: return out

    def publish(self, frames, state):
        """frames: {camera name: HxWx3 uint8}; the chosen one gets the HUD and becomes the stream frame."""
        self.state = state
        cam = self.camera if self.camera in frames else next(iter(frames))
        img = Image.fromarray(np.asarray(frames[cam])); d = ImageDraw.Draw(img)
        d.rectangle([0, 0, img.width, 30], fill=(0, 0, 0)); d.text((8, 3), state["label"], font=FONT_B, fill=(140, 200, 255) if "FLY" in state["label"] or "LAND" in state["label"] else (230, 230, 240))
        d.text((img.width - 150, 6), f"t = {state['t']:.1f} s", font=FONT, fill=(200, 200, 210))
        if state.get("paused"): d.text((img.width // 2 - 40, img.height // 2), "PAUSED", font=FONT_B, fill=(255, 220, 80))
        buf = io.BytesIO(); img.save(buf, "JPEG", quality=80)
        with self.cv:
            self.frame = buf.getvalue(); self.version += 1; self.cv.notify_all()
        if "overhead" in frames:
            ob = io.BytesIO(); Image.fromarray(np.asarray(frames["overhead"])).resize((320, 240)).save(ob, "JPEG", quality=70); self.overhead = ob.getvalue()
