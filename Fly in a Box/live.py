"""Sandbox mode: a small web server inside the simulation.

`flybox.py --live 8765` starts it; open http://<machine>:8765/ (the Android app opens it on the phone itself).
The page draws the fly in 3D in the browser (WebGL, three.js) from the body poses the simulation streams, so
the phone's graphics chip does the drawing and the motion is smooth at the screen's frame rate, interpolated
between simulation frames. Next to it: the whole brain lighting up as neurons spike, the key neurons' firing
rates, and both compound eyes as the fly sees through them (ommatidium by ommatidium).

What it serves: /              the page
                /three.min.js  three.js (MIT licence, web/three.LICENSE)
                /scene.json    the static scene: geoms, meshes, materials (once)
                /scene.bin     mesh vertices, normals and faces; cube textures (once)
                /brain.bin     neuron positions (frontal view) and classes (once)
                /eyes.json     ommatidium layout (once)
                /feed?after=N  everything newer than record N, as one binary blob (long poll): body poses
                               (every 10 ms of fly time), spikes, eye images, state
                /state         the latest state as JSON
                /cmd           POST {"cmd": ...} -> queued, applied by the simulation at its next tick
"""
import json, os, queue, struct, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))

LABELS = {"walk": "walking", "pause": "pausing", "wall": "following the wall", "feed": "FEEDING", "escape": "ESCAPE",
          "groom:front rub": "grooming: front legs", "groom:head groom": "grooming: head", "groom:hind rub": "grooming: hind legs",
          "approach": "walking up to the wall", "mount": "CLIMBING: rearing up", "climb": "CLIMBING the wall", "turnaround": "turning round on the wall",
          "descend": "walking down the wall", "takeoff": "TAKE-OFF (giant fibre)", "surface_takeoff": "TAKE-OFF from the wall", "flight": "FLYING",
          "landing": "landing", "touchdown": "landing", "land_wall": "flying to a wall", "grab_wall": "LANDING: wall", "land_ceiling": "flying up to the lid",
          "flip_ceiling": "LANDING: lid, the flip", "grab_ceiling": "LANDING: lid", "ceiling": "on the lid, upside down"}

REC_POSE, REC_SPIKES, REC_EYES, REC_STATE = 1, 2, 3, 4


def export_scene(m, mj):
    """The visible part of the MuJoCo model, for the browser: which geoms to draw, their shapes, colours and
    cube textures, and which of them move (their poses then come in the feed)."""
    name = lambda i: mj.mj_id2name(m, mj.mjtObj.mjOBJ_GEOM, i) or f"g{i}"
    geoms, dyn = [], []
    for i in range(m.ngeom):
        if m.geom_group[i] not in (0, 2):
            continue                                            # collision-only and marker geoms
        mat = int(m.geom_matid[i])
        rgba = (m.mat_rgba[mat] if mat >= 0 else m.geom_rgba[i]).tolist()
        if rgba[3] <= 0:
            continue                                            # invisible (the glass lid, wing air surfaces)
        tex = int(m.mat_texid[mat][1]) if mat >= 0 else -1      # role 1: rgb texture
        moving = m.geom_bodyid[i] != 0 or name(i) == "food"
        g = {"i": i, "name": name(i), "type": int(m.geom_type[i]), "size": m.geom_size[i].tolist(), "rgba": rgba,
             "mesh": int(m.geom_dataid[i]) if m.geom_type[i] == mj.mjtGeom.mjGEOM_MESH else -1, "tex": tex,
             "dyn": len(dyn) if moving else -1, "pos": m.geom_pos[i].tolist(), "quat": m.geom_quat[i].tolist()}
        if moving:
            dyn.append(i)
        geoms.append(g)
    used = sorted({g["mesh"] for g in geoms if g["mesh"] >= 0})
    blobs, meshes, off = [], {}, 0
    for k in used:
        va, vn, fa, fn = m.mesh_vertadr[k], m.mesh_vertnum[k], m.mesh_faceadr[k], m.mesh_facenum[k]
        v = m.mesh_vert[va:va + vn].astype(np.float32).tobytes()
        n = m.mesh_normal[m.mesh_normaladr[k]:m.mesh_normaladr[k] + vn].astype(np.float32).tobytes()
        f = m.mesh_face[fa:fa + fn].astype(np.uint32).tobytes()
        meshes[k] = {"v": off, "n": off + len(v), "f": off + len(v) + len(n), "nv": int(vn), "nf": int(fn)}
        blobs += [v, n, f]; off += len(v) + len(n) + len(f)
    textures = {}
    for t in sorted({g["tex"] for g in geoms if g["tex"] >= 0}):
        w, h, c = int(m.tex_width[t]), int(m.tex_height[t]), int(m.tex_nchannel[t])
        data = m.tex_data[m.tex_adr[t]:m.tex_adr[t] + w * h * c].astype(np.uint8)
        if c == 3:
            data = np.concatenate([data.reshape(-1, 3), np.full((w * h, 1), 255, np.uint8)], 1).ravel()
        textures[t] = {"o": off, "w": w, "h": h, "type": int(m.tex_type[t])}
        b = data.tobytes(); blobs.append(b); off += len(b)
    plane = next((g for g in geoms if g["type"] == 0), None)
    meta = {"geoms": geoms, "meshes": {str(k): v for k, v in meshes.items()}, "textures": {str(k): v for k, v in textures.items()},
            "ndyn": len(dyn), "floor_square": float(2 * plane["size"][0] / m.mat_texrepeat[m.geom_matid[plane["i"]]][0] / 2) if plane else 4.0}
    return meta, b"".join(blobs), np.array(dyn, dtype=np.int64)


class Live:
    """Shared between the simulation thread (which publishes and pops commands) and the server threads."""
    def __init__(self, port, host="0.0.0.0"):
        self.state = {"label": "starting", "t": 0.0}; self.cmds = queue.Queue()
        self.paused = False; self.blindfold = False
        self.scene_json = b"{}"; self.scene_bin = b""; self.brain_bin = b""; self.eyes_json = b"{}"
        self.records = []; self.seq = 0; self.cv = threading.Condition()
        try:
            self.three = open(os.path.join(HERE, "web", "three.min.js"), "rb").read()
        except OSError:
            self.three = b"document.body.innerHTML='three.min.js is missing next to live.py (web/)';"
        live = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"                       # keep-alive: the page polls the feed continuously
            def log_message(self, *a): pass
            def _send(self, code, ctype, body, cache=False):
                self.send_response(code); self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(body)))
                self.send_header("Cache-Control", "max-age=86400" if cache else "no-store"); self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers(); self.wfile.write(body)
            def do_GET(self):
                path, _, query = self.path.partition("?")
                try:
                    if path == "/": self._send(200, "text/html; charset=utf-8", PAGE.encode())
                    elif path == "/three.min.js": self._send(200, "application/javascript", live.three, cache=True)
                    elif path == "/scene.json": self._send(200, "application/json", live.scene_json)
                    elif path == "/scene.bin": self._send(200, "application/octet-stream", live.scene_bin)
                    elif path == "/brain.bin": self._send(200, "application/octet-stream", live.brain_bin)
                    elif path == "/eyes.json": self._send(200, "application/json", live.eyes_json)
                    elif path == "/state": self._send(200, "application/json", json.dumps(dict(live.state, paused=live.paused, blindfold=live.blindfold)).encode())
                    elif path == "/feed":
                        after = int(dict(kv.split("=", 1) for kv in query.split("&") if "=" in kv).get("after", "-1"))
                        self._send(200, "application/octet-stream", live.feed(after))
                    else: self._send(404, "text/plain", b"not found")
                except (BrokenPipeError, ConnectionResetError):
                    pass
            def do_POST(self):
                n = int(self.headers.get("Content-Length", 0)); body = self.rfile.read(n) if n else b"{}"
                try: c = json.loads(body or b"{}")
                except ValueError: c = {}
                if self.path == "/cmd" and isinstance(c, dict) and "cmd" in c:
                    if c["cmd"] == "pause": live.paused = not live.paused
                    elif c["cmd"] == "blindfold": live.blindfold = not live.blindfold
                    else: live.cmds.put(c)
                    self._send(200, "application/json", b'{"ok": true}')
                else: self._send(400, "application/json", b'{"ok": false}')
        self.server = ThreadingHTTPServer((host, port), Handler); self.server.daemon_threads = True
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        print(f"[live] sandbox at http://{host}:{port}/" + ("  (open it on the phone with this computer's address)" if host == "0.0.0.0" else ""), flush=True)

    # ----- static data, set once by the simulation
    def set_scene(self, m, mj):
        meta, blob, self.dyn = export_scene(m, mj)
        self.scene_json = json.dumps(meta).encode(); self.scene_bin = blob
        print(f"[live] scene: {len(meta['geoms'])} geoms ({meta['ndyn']} moving), {len(meta['meshes'])} meshes, {len(blob) / 1e6:.1f} MB", flush=True)

    def set_brain(self, xy, cls, class_names, highlights):
        """xy: (N, 2) in [0, 1] (frontal view, y down); cls: (N,) small ints into class_names."""
        hdr = json.dumps({"n": int(len(xy)), "classes": class_names, "highlights": highlights}).encode()
        self.brain_bin = struct.pack("<I", len(hdr)) + hdr + xy.astype(np.float32).tobytes() + cls.astype(np.uint8).tobytes()

    def set_eyes(self, centroids, pale, size):
        self.eyes_json = json.dumps({"xy": np.asarray(centroids).round(2).tolist(), "pale": np.asarray(pale).astype(int).tolist(), "size": list(size)}).encode()

    # ----- the feed
    def _push(self, kind, payload):
        with self.cv:
            self.seq += 1
            self.records.append((self.seq, struct.pack("<BII", kind, self.seq, len(payload)) + payload))
            if len(self.records) > 600: del self.records[:100]
            self.cv.notify_all()

    def push_pose(self, t, data):
        """Every moving geom's position and orientation: data.geom_xpos / geom_xmat rows of self.dyn."""
        p = np.concatenate([data.geom_xpos[self.dyn], data.geom_xmat[self.dyn]], 1).astype(np.float32)
        self._push(REC_POSE, struct.pack("<d", t) + p.tobytes())

    def push_spikes(self, t, ids):
        self._push(REC_SPIKES, struct.pack("<d", t) + np.asarray(ids, dtype=np.uint32).tobytes())

    def push_eyes(self, t, rgb):
        self._push(REC_EYES, struct.pack("<d", t) + np.clip(np.asarray(rgb) * 255, 0, 255).astype(np.uint8).tobytes())

    def push_state(self, state):
        self.state = state
        self._push(REC_STATE, json.dumps(dict(state, paused=self.paused, blindfold=self.blindfold)).encode())

    def feed(self, after):
        with self.cv:
            if not self.records or self.records[-1][0] <= after:
                self.cv.wait(timeout=1.0)
            out = [r for s, r in self.records if s > after]
        return b"".join(out)

    def pop_all(self):
        out = []
        while True:
            try: out.append(self.cmds.get_nowait())
            except queue.Empty: return out


PAGE = r"""<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<title>Fly in a Box</title>
<style>
:root{--bg:#0b0b10;--panel:#14141d;--fg:#e8e8f0;--dim:#9a9ab0;--acc:#8cf}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font-family:system-ui,sans-serif;-webkit-user-select:none;user-select:none;overflow-x:hidden}
#wrap{display:flex;flex-direction:column;min-height:100vh}
#v3{position:relative;width:100%;height:56vh;background:#000;touch-action:none}
#v3 canvas{width:100%;height:100%;display:block}
#hud{position:absolute;left:0;right:0;top:0;padding:6px 10px;background:linear-gradient(#000c,#0000);pointer-events:none;font-size:15px}
#hud b{font-size:18px}
#hud .r{float:right;color:var(--dim)}
#camrow{position:absolute;right:8px;bottom:8px;display:flex;gap:6px}
#camrow button{padding:6px 10px;font-size:13px;border-radius:8px;background:#0008;color:#fff;border:1px solid #fff3}
#camrow button.on{background:#2a5a8acc}
#panels{display:grid;grid-template-columns:3fr 2fr;gap:6px;padding:6px}
.card{background:var(--panel);border-radius:10px;padding:6px 8px;min-width:0}
.card h3{margin:0 0 4px;font-size:12px;font-weight:600;color:var(--dim);letter-spacing:.02em}
#brain{width:100%;aspect-ratio:2/1;display:block;border-radius:6px;background:#000}
.eyes{display:flex;gap:4px}
.eyes canvas{flex:1;width:50%;aspect-ratio:450/512;background:#000;border-radius:6px}
#bars{display:grid;grid-template-columns:auto 1fr 1fr auto;gap:2px 6px;font-size:12px;align-items:center}
.bar{height:9px;background:#22223a;border-radius:4px;overflow:hidden}
.bar i{display:block;height:100%;background:var(--acc);width:0}
.bar.l{direction:rtl}
.num{color:var(--dim);font-variant-numeric:tabular-nums;text-align:right;min-width:3.2em}
#legend{font-size:11px;color:var(--dim);margin-top:3px;line-height:1.5}
#legend span{display:inline-block;width:8px;height:8px;border-radius:2px;margin:0 3px 0 8px}
.row{display:flex;flex-wrap:wrap;gap:6px;padding:0 6px 6px}
.row button{flex:1 1 30%;padding:11px 6px;font-size:14px;border:0;border-radius:10px;background:#23233a;color:var(--fg)}
.row button:active{background:#3a3a6a}
.row button.hot{background:#6a2a2a} .row button.on{background:#2a5a3a}
.row label{font-size:13px;color:var(--dim);flex:1 1 100%;padding:2px 4px}
input[type=range]{width:100%}
.small{font-size:12px;color:#889;padding:0 10px 12px}
@media (orientation:landscape) and (min-width:900px){
 #wrap{flex-direction:row;flex-wrap:wrap}
 #v3{width:62%;height:100vh}
 #side{width:38%;height:100vh;overflow-y:auto}
 #panels{grid-template-columns:1fr}
}
</style></head><body>
<div id="wrap">
<div id="v3"><div id="hud"><span class="r" id="clock">connecting…</span><b id="label">loading the fly…</b><br><span id="sub"></span></div>
 <div id="camrow"><button data-c="follow" class="on">follow</button><button data-c="side">side</button><button data-c="top">top</button><button data-c="free">free</button></div></div>
<div id="side">
<div id="panels">
 <div class="card"><h3>BRAIN · 138,639 neurons · each dot one neuron, lit when it spikes</h3><canvas id="brain" width="720" height="360"></canvas><div id="legend"></div></div>
 <div class="card"><h3>WHAT IT SEES · 721 ommatidia per eye</h3><div class="eyes"><canvas id="eyeL" width="225" height="256"></canvas><canvas id="eyeR" width="225" height="256"></canvas></div>
  <h3 style="margin-top:8px">KEY NEURONS · left / right, spikes per second</h3><div id="bars"></div></div>
</div>
<div class="row">
 <button class="hot" onclick="cmd('shadow')">shadow (loom)</button>
 <button class="hot" onclick="cmd('poke')">poke</button>
 <button class="hot" onclick="cmd('toss')">toss into the air</button>
 <button onclick="cmd('drop')">drop on its back</button>
 <button onclick="cmd('place',{where:'lid'})">put on the lid</button>
 <button onclick="cmd('place',{where:'wall'})">put on a wall</button>
 <button id="blind" onclick="cmd('blindfold')">blindfold</button>
 <button id="pause" onclick="cmd('pause')">pause</button>
 <label>hunger <input type="range" min="0" max="100" value="90" id="hunger" onchange="cmd('hunger',{value:this.value/100})"></label>
 <label>double-tap the floor to move the food</label>
</div>
<div class="small" id="foot">A real FlyWire connectome (every neuron and synapse) in a NeuroMechFly body, simulated on this device.</div>
</div></div>
<script src="/three.min.js"></script>
<script>
"use strict";
const $=id=>document.getElementById(id);
function cmd(c,extra){fetch('/cmd',{method:'POST',body:JSON.stringify(Object.assign({cmd:c},extra||{}))});}

// ------------------------------------------------------------------ 3D scene
const box=$('v3');
// ?quality=high (the PC app): full-resolution drawing, soft real-time shadows, finer brain and eye panels
const HQ=new URLSearchParams(location.search).get('quality')==='high';
const renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'});
renderer.setPixelRatio(HQ?Math.min(window.devicePixelRatio||1,3):Math.min(window.devicePixelRatio||1,2));
if(HQ){renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;}
box.insertBefore(renderer.domElement,box.firstChild);
const scene=new THREE.Scene(); scene.background=new THREE.Color(0x1a1a22);
const camera=new THREE.PerspectiveCamera(42,1,0.2,600); camera.up.set(0,0,1);
scene.add(new THREE.HemisphereLight(0xffffff,0x404050,0.75));
const sun=new THREE.DirectionalLight(0xffffff,HQ?0.7:0.55); sun.position.set(-30,-40,90); scene.add(sun);
if(HQ){sun.castShadow=true;sun.shadow.mapSize.set(4096,4096);const sc=sun.shadow.camera;sc.left=-48;sc.right=48;sc.top=48;sc.bottom=-48;sc.near=1;sc.far=260;sun.shadow.bias=-0.0004;sun.shadow.radius=3;}
function resize(){const w=box.clientWidth,h=box.clientHeight;renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();}
window.addEventListener('resize',resize);

// MuJoCo cube textures on meshes without UVs: sampled by direction from the mesh centre, as MuJoCo does
const cubeShader={
 vertexShader:`varying vec3 vObj;varying vec3 vN;void main(){vObj=position;vN=normalize(normalMatrix*normal);gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}`,
 fragmentShader:`uniform sampler2D tex;uniform vec3 L;varying vec3 vObj;varying vec3 vN;
 vec2 cubeUV(vec3 d){vec3 a=abs(d);float face;vec2 uv;
  if(a.x>=a.y&&a.x>=a.z){face=d.x>0.?0.:1.;uv=vec2(d.x>0.?-d.y:d.y,-d.z)/a.x;}
  else if(a.y>=a.z){face=d.y>0.?2.:3.;uv=vec2(d.x,d.y>0.?d.z:-d.z)/a.y;}
  else{face=d.z>0.?4.:5.;uv=vec2(d.z>0.?d.x:-d.x,-d.y)/a.z;}
  uv=uv*0.5+0.5;return vec2(uv.x,(face+uv.y)/6.0);}
 void main(){vec3 c=texture2D(tex,cubeUV(normalize(vObj))).rgb;float d=max(dot(normalize(vN),L),0.0);gl_FragColor=vec4(c*(0.45+0.65*d),1.0);}`
};
const geomObjs=[]; let nDyn=0; let fly=null;
async function loadScene(){
 const meta=await (await fetch('/scene.json')).json();
 const bin=await (await fetch('/scene.bin')).arrayBuffer();
 nDyn=meta.ndyn;
 const texCache={};
 function cubeTex(id){if(texCache[id])return texCache[id];const t=meta.textures[id];
  const tx=new THREE.DataTexture(new Uint8Array(bin,t.o,t.w*t.h*4),t.w,t.h,THREE.RGBAFormat);tx.needsUpdate=true;tx.magFilter=THREE.LinearFilter;tx.flipY=false;
  return texCache[id]=tx;}
 const geoCache={};
 function meshGeo(k){if(geoCache[k])return geoCache[k];const M=meta.meshes[k];const g=new THREE.BufferGeometry();
  g.setAttribute('position',new THREE.BufferAttribute(new Float32Array(bin,M.v,M.nv*3),3));
  g.setAttribute('normal',new THREE.BufferAttribute(new Float32Array(bin,M.n,M.nv*3),3));
  g.setIndex(new THREE.BufferAttribute(new Uint32Array(bin,M.f,M.nf*3),1));return geoCache[k]=g;}
 const Ldir=new THREE.Vector3(-0.3,-0.4,0.86).normalize();
 for(const g of meta.geoms){
  let geo=null,mat=null;const col=new THREE.Color(g.rgba[0],g.rgba[1],g.rgba[2]);
  const trans=g.rgba[3]<0.99;
  if(g.type===7){geo=meshGeo(g.mesh);
   if(g.tex>=0&&meta.textures[g.tex].type===1){mat=new THREE.ShaderMaterial({uniforms:{tex:{value:cubeTex(g.tex)},L:{value:Ldir}},vertexShader:cubeShader.vertexShader,fragmentShader:cubeShader.fragmentShader});}
   else mat=new THREE.MeshLambertMaterial({color:col,transparent:trans,opacity:g.rgba[3],side:trans?THREE.DoubleSide:THREE.FrontSide,depthWrite:!trans});}
  else if(g.type===6){geo=new THREE.BoxGeometry(2*g.size[0],2*g.size[1],2*g.size[2]);mat=new THREE.MeshLambertMaterial({color:col});}
  else if(g.type===5){geo=new THREE.CylinderGeometry(g.size[0],g.size[0],2*g.size[1],40);geo.rotateX(Math.PI/2);mat=new THREE.MeshLambertMaterial({color:col});}
  else if(g.type===3){geo=new THREE.CapsuleGeometry?new THREE.CapsuleGeometry(g.size[0],2*g.size[1],6,12):new THREE.CylinderGeometry(g.size[0],g.size[0],2*g.size[1],12);geo.rotateX(Math.PI/2);mat=new THREE.MeshLambertMaterial({color:col});}
  else if(g.type===2){geo=new THREE.SphereGeometry(g.size[0],16,12);mat=new THREE.MeshLambertMaterial({color:col});}
  else if(g.type===4){geo=new THREE.SphereGeometry(1,16,12);geo.scale(g.size[0],g.size[1],g.size[2]);mat=new THREE.MeshLambertMaterial({color:col});}
  else if(g.type===0){ // the floor: the same checker as the simulation's
   const c=document.createElement('canvas');c.width=c.height=64;const x=c.getContext('2d');x.fillStyle='#8a8a8a';x.fillRect(0,0,64,64);x.fillStyle='#5a5a5a';x.fillRect(0,0,32,32);x.fillRect(32,32,32,32);
   const t=new THREE.CanvasTexture(c);t.wrapS=t.wrapT=THREE.RepeatWrapping;const span=120;t.repeat.set(span/(2*meta.floor_square),span/(2*meta.floor_square));t.anisotropy=4;
   geo=new THREE.PlaneGeometry(span,span);mat=new THREE.MeshLambertMaterial({map:t});}
  if(!geo)continue;
  const o=new THREE.Mesh(geo,mat);o.matrixAutoUpdate=false;
  if(HQ){o.castShadow=g.type!==0;o.receiveShadow=g.type===0||g.type===6||g.type===5;}
  if(trans)o.renderOrder=2;
  if(g.dyn<0){o.position.set(g.pos[0],g.pos[1],g.pos[2]);o.quaternion.set(g.quat[1],g.quat[2],g.quat[3],g.quat[0]);o.updateMatrix();}
  o.userData.dyn=g.dyn;scene.add(o);if(g.dyn>=0)geomObjs[g.dyn]=o;if(g.name==='fly/c_thorax')fly=g.dyn;
 }
 resize();
}

// ------------------------------------------------------------------ playback: a smooth clock running a little behind the simulation
const poses=[];           // {t, a: Float32Array(ndyn*12)}
let playT=null,lastWall=null,simRate=1.0,lastArrivalT=null,lastArrivalWall=null;
const LAG=0.12;           // seconds of fly time held back, so there is always a next frame to interpolate towards
const _m=new THREE.Matrix4(),_q1=new THREE.Quaternion(),_q2=new THREE.Quaternion(),_p1=new THREE.Vector3(),_p2=new THREE.Vector3(),_s=new THREE.Vector3(1,1,1);
function setPose(o,a,b,u,k){
 const i=k*12;
 _p1.set(a[i],a[i+1],a[i+2]);
 _m.set(a[i+3],a[i+4],a[i+5],0,a[i+6],a[i+7],a[i+8],0,a[i+9],a[i+10],a[i+11],0,0,0,0,1);_q1.setFromRotationMatrix(_m);
 if(b&&u>0){_p2.set(b[i],b[i+1],b[i+2]);_m.set(b[i+3],b[i+4],b[i+5],0,b[i+6],b[i+7],b[i+8],0,b[i+9],b[i+10],b[i+11],0,0,0,0,1);_q2.setFromRotationMatrix(_m);
  _p1.lerp(_p2,u);_q1.slerp(_q2,u);}
 o.matrix.compose(_p1,_q1,_s);
}
const target=new THREE.Vector3(),camPos=new THREE.Vector3();let targetSet=false;let camMode='follow',orbit={az:-1.2,el:0.75,r:22};
function animate(){
 requestAnimationFrame(animate);
 const now=performance.now()/1000;
 if(poses.length){
  const newest=poses[poses.length-1].t;
  if(playT===null){playT=newest-LAG;lastWall=now;}
  const dw=Math.min(0.1,now-lastWall);lastWall=now;
  // advance at the simulation's own pace, and drift gently towards newest-LAG (no jumps, no stalls)
  const err=(newest-LAG)-playT;
  playT+=dw*simRate+err*Math.min(1,dw*1.5);
  while(poses.length>2&&poses[1].t<=playT)poses.shift();
  const a=poses[0],b=poses.length>1?poses[1]:null;
  const u=b?Math.max(0,Math.min(1,(playT-a.t)/Math.max(1e-6,b.t-a.t))):0;
  for(let k=0;k<nDyn;k++){const o=geomObjs[k];if(o)setPose(o,a.a,b?b.a:null,u,k);}
  if(fly!==null&&geomObjs[fly]){const e=geomObjs[fly].matrix.elements;_p1.set(e[12],e[13],e[14]);if(!targetSet){target.copy(_p1);targetSet=true;}else target.lerp(_p1,Math.min(1,dw*6));}
 }
 // cameras look at the fly from the side of the box's centre and never leave the box (a wall would block the view)
 const cx=-target.x,cy=-target.y,cl=Math.hypot(cx,cy);const ux=cl>3?cx/cl:0,uy=cl>3?cy/cl:-1;
 if(camMode==='follow'){camPos.set(target.x+ux*11,target.y+uy*11,Math.min(28,target.z+9));}
 else if(camMode==='side'){camPos.set(target.x+ux*7-uy*2,target.y+uy*7+ux*2,Math.min(28.5,target.z+1.5));}
 else if(camMode==='top'){camPos.set(0,-0.01,92);}
 else{camPos.set(target.x+orbit.r*Math.cos(orbit.el)*Math.cos(orbit.az),target.y+orbit.r*Math.cos(orbit.el)*Math.sin(orbit.az),target.z+orbit.r*Math.sin(orbit.el));}
 if(camMode!=='top'){camPos.x=Math.max(-28.6,Math.min(28.6,camPos.x));camPos.y=Math.max(-28.6,Math.min(28.6,camPos.y));camPos.z=Math.max(0.4,Math.min(29.6,camPos.z));}
 camera.position.lerp(camPos,camMode==='free'?0.5:0.06);camera.lookAt(camMode==='top'?_p2.set(0,0,0):target);
 renderer.render(scene,camera);
}
document.querySelectorAll('#camrow button').forEach(b=>b.onclick=()=>{camMode=b.dataset.c;document.querySelectorAll('#camrow button').forEach(x=>x.classList.toggle('on',x===b));});
// touch: one finger orbits (switches to free), two fingers zoom; double tap on the floor moves the food
let touches={},lastTap=0;
box.addEventListener('pointerdown',e=>{touches[e.pointerId]={x:e.clientX,y:e.clientY};
 const now=Date.now();if(now-lastTap<300)placeFood(e);lastTap=now;});
box.addEventListener('pointermove',e=>{const t=touches[e.pointerId];if(!t)return;const ids=Object.keys(touches);
 if(ids.length===1){if(camMode!=='free'){camMode='free';document.querySelectorAll('#camrow button').forEach(x=>x.classList.toggle('on',x.dataset.c==='free'));}
  orbit.az-=(e.clientX-t.x)*0.008;orbit.el=Math.max(-0.2,Math.min(1.5,orbit.el+(e.clientY-t.y)*0.006));}
 else if(ids.length===2){const o=touches[ids[0]==e.pointerId?ids[1]:ids[0]];const d0=Math.hypot(t.x-o.x,t.y-o.y),d1=Math.hypot(e.clientX-o.x,e.clientY-o.y);if(d0>0)orbit.r=Math.max(3,Math.min(120,orbit.r*d0/d1));}
 t.x=e.clientX;t.y=e.clientY;});
['pointerup','pointercancel','pointerleave'].forEach(n=>box.addEventListener(n,e=>{delete touches[e.pointerId];}));
box.addEventListener('wheel',e=>{orbit.r=Math.max(3,Math.min(120,orbit.r*(e.deltaY>0?1.1:0.9)));e.preventDefault();},{passive:false});
function placeFood(e){const r=renderer.domElement.getBoundingClientRect();const v=new THREE.Vector2(((e.clientX-r.left)/r.width)*2-1,-((e.clientY-r.top)/r.height)*2+1);
 const ray=new THREE.Raycaster();ray.setFromCamera(v,camera);const o=ray.ray.origin,d=ray.ray.direction;if(Math.abs(d.z)<1e-6)return;const s=-o.z/d.z;if(s<0)return;
 cmd('food',{x:o.x+s*d.x,y:o.y+s*d.y});}

// ------------------------------------------------------------------ brain panel
const bc=$('brain');if(HQ){bc.width=1200;bc.height=600;['eyeL','eyeR'].forEach(id=>{$(id).width=450;$(id).height=512;});}
const bx=bc.getContext('2d');let BN=0,bxy=null,bcls=null,bpix=null,heat=null,base=null,classes=[],palette=[];
const PAL={'sensory':[90,220,255],'optic':[70,120,255],'visual_projection':[120,160,255],'visual_centrifugal':[120,160,255],'central':[255,236,180],'descending':[255,150,60],'ascending':[120,255,140],'motor':[255,70,70],'endocrine':[230,120,255],'sensory_ascending':[90,220,255],'other':[200,200,200]};
async function loadBrain(){
 const buf=await (await fetch('/brain.bin')).arrayBuffer();const hl=new DataView(buf).getUint32(0,true);
 const hdr=JSON.parse(new TextDecoder().decode(new Uint8Array(buf,4,hl)));BN=hdr.n;classes=hdr.classes;
 const o=4+hl;bxy=new Float32Array(buf.slice(o,o+BN*8));bcls=new Uint8Array(buf,o+BN*8,BN);
 palette=classes.map(c=>PAL[c]||PAL.other);
 const W=bc.width,H=bc.height;bpix=new Int32Array(BN);heat=new Float32Array(W*H*3);base=new Float32Array(W*H);
 for(let i=0;i<BN;i++){if(bxy[2*i]<0){bpix[i]=-1;continue;}const x=Math.min(W-1,Math.max(0,Math.round(bxy[2*i]*(W-1)))),y=Math.min(H-1,Math.max(0,Math.round(bxy[2*i+1]*(H-1))));bpix[i]=y*W+x;base[y*W+x]+=1;}
 $('legend').innerHTML=['sensory','optic','central','descending','ascending','motor'].filter(c=>classes.includes(c)).map(c=>`<span style="background:rgb(${PAL[c]})"></span>${c}`).join('');
 drawBrain();
}
let brainImg=null;
function spikesIn(ids){if(!bpix)return;for(let k=0;k<ids.length;k++){const i=ids[k];if(i>=BN||bpix[i]<0)continue;const p=bpix[i]*3,c=palette[bcls[i]];heat[p]+=c[0];heat[p+1]+=c[1];heat[p+2]+=c[2];}}
let brainTick=0;
function drawBrain(){
 requestAnimationFrame(drawBrain);if(!bpix||(brainTick++&1))return;      // about 30 redraws a second is plenty for the glow
 const W=bc.width,H=bc.height;if(!brainImg)brainImg=bx.createImageData(W,H);const d=brainImg.data;
 for(let q=0,p=0;q<W*H;q++,p+=3){const b0=Math.min(60,base[q]*7);
  d[4*q]=Math.min(255,b0*0.55+heat[p]);d[4*q+1]=Math.min(255,b0*0.6+heat[p+1]);d[4*q+2]=Math.min(255,b0+heat[p+2]);d[4*q+3]=255;
  heat[p]*=0.7;heat[p+1]*=0.7;heat[p+2]*=0.7;}
 bx.putImageData(brainImg,0,0);
}

// ------------------------------------------------------------------ eyes: each ommatidium a hexagon in its own colour
let eyeXY=null,eyeSize=[512,450];const ecx=[$('eyeL').getContext('2d'),$('eyeR').getContext('2d')];
async function loadEyes(){const e=await (await fetch('/eyes.json')).json();eyeXY=e.xy;eyeSize=e.size;}
function drawEyes(rgb){if(!eyeXY)return;const n=eyeXY.length;
 for(let e=0;e<2;e++){const c=ecx[e],W=c.canvas.width,H=c.canvas.height,sx=W/eyeSize[1],sy=H/eyeSize[0],r=8.6*sx;c.fillStyle='#000';c.fillRect(0,0,W,H);
  for(let k=0;k<n;k++){const o=(e*n+k)*3;c.fillStyle=`rgb(${rgb[o]},${rgb[o+1]},${rgb[o+2]})`;const x=eyeXY[k][1]*sx,y=eyeXY[k][0]*sy;
   c.beginPath();for(let j=0;j<6;j++){const a=Math.PI/6+j*Math.PI/3;c.lineTo(x+r*Math.cos(a),y+r*Math.sin(a));}c.fill();}}}

// ------------------------------------------------------------------ bars and labels
const BARS=[['giant fibre (escape)','DNp01',150],['turning DNa02','DNa02',150],['walking DNs (all)','DNpop',40],['backward MDN','MDN',150],['proboscis MN9','MN9',100],['reward dopamine','PAMrw',60],
 ['smell (antennae)','odour',1],['looming','loom',1],['dark object','obj',1],['touch (head)','touch',80]];
$('bars').innerHTML=BARS.map((b,i)=>`<span>${b[0]}</span><div class="bar l"><i id="bl${i}"></i></div><div class="bar"><i id="br${i}"></i></div><span class="num" id="bn${i}"></span>`).join('');
function showState(s){
 $('label').textContent=s.label;
 const rt=s.speed>0?(s.speed>=0.95?'real time':(s.speed.toFixed(2)+'× real time')):'';
 $('clock').textContent=`t = ${s.t.toFixed(1)} s · ${rt}`;
 $('sub').textContent=`hunger ${(100*s.hunger).toFixed(0)}% · ${s.spikes_per_s?Math.round(s.spikes_per_s/1000)+'k spikes/s':''} · take-offs ${s.events.takeoff} · landings ${s.events.wall_landing+s.events.ceiling_landing} · fed ${(s.events.feeding/100).toFixed(1)} s`;
 BARS.forEach((b,i)=>{const v=s.bars&&s.bars[b[1]];if(!v)return;$('bl'+i).style.width=Math.min(100,100*v[0]/b[2])+'%';$('br'+i).style.width=Math.min(100,100*v[1]/b[2])+'%';
  $('bn'+i).textContent=b[2]===1?'':Math.round(v[0])+'/'+Math.round(v[1]);});
 $('blind').className=s.blindfold?'on':'';$('pause').className=s.paused?'on':'';
}

// ------------------------------------------------------------------ the feed
let after=-1;
async function pump(){
 for(;;){
  try{
   const buf=await (await fetch('/feed?after='+after)).arrayBuffer();const dv=new DataView(buf);let o=0;
   while(o+9<=buf.byteLength){const kind=dv.getUint8(o),seq=dv.getUint32(o+1,true),len=dv.getUint32(o+5,true);const p=o+9;o=p+len;after=seq;
    if(kind===1){const t=dv.getFloat64(p,true);const a=new Float32Array(buf.slice(p+8,p+len));
     if(lastArrivalT!==null&&t>lastArrivalT){const w=performance.now()/1000;const r=(t-lastArrivalT)/Math.max(1e-3,w-lastArrivalWall);simRate=0.97*simRate+0.03*Math.min(1.2,r);lastArrivalWall=w;}
     else if(lastArrivalT===null||t<lastArrivalT-1){lastArrivalWall=performance.now()/1000;if(t<(lastArrivalT||0)-1){poses.length=0;playT=null;}}
     lastArrivalT=t;poses.push({t:t,a:a});if(poses.length>400)poses.splice(0,poses.length-400);}
    else if(kind===2){spikesIn(new Uint32Array(buf.slice(p+8,p+len)));}
    else if(kind===3){drawEyes(new Uint8Array(buf,p+8,len-8));}
    else if(kind===4){showState(JSON.parse(new TextDecoder().decode(new Uint8Array(buf,p,len))));}
   }
  }catch(err){$('label').textContent='waiting for the simulation…';await new Promise(r=>setTimeout(r,1000));}
 }
}
(async()=>{try{await loadScene();}catch(e){$('label').textContent='scene: '+e;}loadBrain();loadEyes();pump();animate();})();
</script></body></html>"""
