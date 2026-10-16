"""Render candidate postures (proboscis, front-leg grooming, hind-leg grooming) side by side."""
import numpy as np, imageio
from PIL import Image, ImageDraw
from flygym import Simulation
from flygym.compose import FlatGroundWorld
from flygym.compose.fly.base_fly import ActuatorType
from flygym.utils.math import Rotation3D
from flygym_demo.complex_terrain import PreprogrammedSteps
from fullfly import make_full_fly, FullBodyActions

fly = make_full_fly()
head_cam = fly.add_tracking_camera(name="head", pos_offset=(3.2, -2.6, 1.0), rotation=Rotation3D("xyaxes", (0.6, 0.8, 0, -0.25, 0.19, 0.95)), fovy=35.0)
side_cam = fly.add_tracking_camera(name="side", pos_offset=(0.5, -6.0, 2.5), rotation=Rotation3D("xyaxes", (1, 0, 0, 0, 0.4, 0.92)), fovy=40.0)
world = FlatGroundWorld(); world.add_fly(fly, [0, 0, 0.5], Rotation3D("quat", [1, 0, 0, 0]))
sim = Simulation(world); sim.set_renderer([head_cam, side_cam], camera_res=(360, 480), playback_speed=1.0, output_fps=30)
steps = PreprogrammedSteps(); A = FullBodyActions(fly, steps)
D = A.i
ROS, HAU = D("c_head", "c_rostrum", "pitch"), D("c_rostrum", "c_haustellum", "pitch")
ROSY, HAUY = D("c_head", "c_rostrum", "yaw"), D("c_rostrum", "c_haustellum", "yaw")
ROSR, HAUR = D("c_head", "c_rostrum", "roll"), D("c_rostrum", "c_haustellum", "roll")
HEADP = D("c_thorax", "c_head", "pitch")
ABD = [D(p, c, "pitch") for p, c in [("c_thorax", "c_abdomen12"), ("c_abdomen12", "c_abdomen3"), ("c_abdomen3", "c_abdomen4"), ("c_abdomen4", "c_abdomen5")]]
def leg(side, joint, ax):
    p, c = {"coxa": ("c_thorax", f"{side}_coxa"), "troch": (f"{side}_coxa", f"{side}_trochanterfemur"), "tibia": (f"{side}_trochanterfemur", f"{side}_tibia"), "tarsus": (f"{side}_tibia", f"{side}_tarsus1")}[joint]
    return D(p, c, ax)

def hold(a, adh, secs=0.6):
    for _ in range(int(secs / sim.timestep)):
        sim.set_actuator_inputs("fly", ActuatorType.POSITION, a); sim.set_leg_adhesion_states("fly", adh); sim.step()
    sim.renderer.reset(); sim.render_as_needed()
    return {k: np.asarray(v[-1]) for k, v in sim.renderer.frames.items()}

variants = []
for k, (cy, cp, cr, tp, tib, ab) in enumerate([(60, 60, 0, -60, 100, -30), (-60, 60, 0, -60, 100, -30), (90, 30, 0, -90, 130, -30), (-90, 30, 0, -90, 130, -30), (60, 90, 60, -90, 120, -35), (-60, 90, -60, -90, 120, -35), (0, 40, 0, -120, 150, -40), (45, 120, 0, -120, 150, -40)]):
    a = A.stand.copy()
    for s in ("lh", "rh"):
        sg = 1 if s == "lh" else -1
        a[leg(s, "coxa", "yaw")] += np.radians(cy * sg); a[leg(s, "coxa", "pitch")] += np.radians(cp); a[leg(s, "coxa", "roll")] += np.radians(cr * sg)
        a[leg(s, "troch", "pitch")] += np.radians(tp); a[leg(s, "tibia", "pitch")] += np.radians(tib)
    for j in ABD: a[j] += np.radians(ab)
    adh = np.ones(6, bool); adh[[2, 5]] = False
    variants.append((f"H{k} cy{cy} cp{cp} cr{cr} tp{tp} ti{tib}", a, adh, "side"))

sim.reset(); sim.set_actuator_inputs("fly", ActuatorType.POSITION, A.stand); sim.set_leg_adhesion_states("fly", np.ones(6, bool)); sim.warmup()
tiles = []
for label, a, adh, cam in variants:
    sim.reset(); sim.set_actuator_inputs("fly", ActuatorType.POSITION, A.stand); sim.set_leg_adhesion_states("fly", np.ones(6, bool)); sim.warmup()
    fr = hold(a, adh)
    img = Image.fromarray(fr["fly/" + cam]); ImageDraw.Draw(img).text((6, 6), label, fill=(255, 255, 0)); tiles.append(img)
cols = 4; rows = (len(tiles) + cols - 1) // cols
sheet = Image.new("RGB", (cols * 480, rows * 360))
for i, t in enumerate(tiles): sheet.paste(t, ((i % cols) * 480, (i // cols) * 360))
sheet.save("out/pose_sheet3.png"); print("saved", len(tiles), "tiles")
