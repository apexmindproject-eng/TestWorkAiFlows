"""Body-only: proboscis extension, head/antenna motion, front-leg and hind-leg grooming postures."""
import numpy as np, imageio, sys
from flygym import Simulation
from flygym.anatomy import BodySegment
from flygym.compose import FlatGroundWorld
from flygym.compose.fly.base_fly import ActuatorType
from flygym.utils.math import Rotation3D
from flygym_demo.complex_terrain import PreprogrammedSteps
from fullfly import make_full_fly, FullBodyActions
fly = make_full_fly()
cam = fly.add_tracking_camera(name="close", pos_offset=(2.5, -5.0, 2.2), rotation=Rotation3D("xyaxes", (1, 0.45, 0, -0.15, 0.35, 0.92)), fovy=40.0)
world = FlatGroundWorld(); world.add_fly(fly, [0, 0, 0.5], Rotation3D("quat", [1, 0, 0, 0]))
sim = Simulation(world); sim.set_renderer([cam], camera_res=(480, 640), playback_speed=1.0, output_fps=30)
steps = PreprogrammedSteps(); A = FullBodyActions(fly, steps)
print("actuated DOFs:", A.n, "leg DOFs:", len(A.leg_idx))
sim.reset(); sim.set_actuator_inputs("fly", ActuatorType.POSITION, A.stand); sim.set_leg_adhesion_states("fly", np.ones(6, dtype=bool)); sim.warmup()
D = lambda p, c, ax: A.i(p, c, ax)
ROS, HAU = D("c_head", "c_rostrum", "pitch"), D("c_rostrum", "c_haustellum", "pitch")
HEADP, HEADY = D("c_thorax", "c_head", "pitch"), D("c_thorax", "c_head", "yaw")
ANT = [D("c_head", s + "_pedicel", "pitch") for s in "lr"]
ABD = [D(p, c, "pitch") for p, c in [("c_thorax", "c_abdomen12"), ("c_abdomen12", "c_abdomen3"), ("c_abdomen3", "c_abdomen4"), ("c_abdomen4", "c_abdomen5")]]
def leg(side, joint, ax):
    return {"coxa": D("c_thorax", f"{side}_coxa", ax), "troch": D(f"{side}_coxa", f"{side}_trochanterfemur", ax), "tibia": D(f"{side}_trochanterfemur", f"{side}_tibia", ax), "tarsus": D(f"{side}_tibia", f"{side}_tarsus1", ax)}[joint]
sign = {"ros": float(sys.argv[1]) if len(sys.argv) > 1 else 1.0}
phases = [("stand", 0.5), ("proboscis", 1.5), ("front-leg grooming", 2.0), ("hind-leg grooming", 2.0)]
t = 0.0; snaps = {}
frames = sim.renderer.frames
for name, dur in phases:
    t0 = t
    while t < t0 + dur:
        a = A.stand.copy(); u = (t - t0) / dur
        if name == "proboscis":
            e = np.sin(np.pi * u)                                   # extend and retract
            a[ROS] += sign["ros"] * np.radians(45) * e; a[HAU] += sign["ros"] * np.radians(50) * e
            a[HEADP] += np.radians(15) * e
        elif name == "front-leg grooming":
            w = np.sin(2 * np.pi * 6 * (t - t0))                     # 6 Hz sweeps
            for s in ("lf", "rf"):
                a[leg(s, "coxa", "pitch")] -= np.radians(45)       # swing the front legs forward/up
                a[leg(s, "troch", "pitch")] += np.radians(35 + 20 * w)
                a[leg(s, "tibia", "pitch")] -= np.radians(60 + 25 * w)
            a[HEADP] -= np.radians(20); a[ANT[0]] -= np.radians(25 * w); a[ANT[1]] += np.radians(25 * w)
        elif name == "hind-leg grooming":
            w = np.sin(2 * np.pi * 5 * (t - t0))
            for s in ("lh", "rh"):
                a[leg(s, "coxa", "pitch")] += np.radians(30)
                a[leg(s, "troch", "pitch")] += np.radians(25 + 20 * w)
                a[leg(s, "tibia", "pitch")] -= np.radians(50 + 20 * w)
            for k, j in enumerate(ABD):
                a[j] -= np.radians(12) * (1 + 0.3 * w)
        sim.set_actuator_inputs("fly", ActuatorType.POSITION, a)
        adh = np.ones(6, dtype=bool)
        if name == "front-leg grooming": adh[[0, 3]] = False
        if name == "hind-leg grooming": adh[[2, 5]] = False
        sim.set_leg_adhesion_states("fly", adh); sim.step(); sim.render_as_needed(); t += sim.timestep
    v = list(frames.values())[0]; snaps[name] = len(v) - 1 if name != "proboscis" else len(v) - int(0.75 * 30)
    p = sim.get_body_positions("fly")[fly.get_bodysegs_order().index(BodySegment("c_thorax"))]
    print(f"after {name:20s} thorax z={p[2]:.2f}")
v = list(frames.values())[0]
for name, i in snaps.items():
    imageio.imwrite(f"out/groom_{name.split()[0]}.png", np.asarray(v[max(0, i)]))
print("saved", list(snaps))
