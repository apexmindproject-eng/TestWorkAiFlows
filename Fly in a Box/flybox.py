"""A fly in a box.

Real FlyWire brain (every neuron, every synapse) wired to the NeuroMechFly physical body
inside a closed arena. The brain's sensory neurons are driven by the body's own senses
(compound eyes, antennal smell, taste, head bristles) and the brain's descending/motor
neurons drive the body. Everything in between is the real connectome.

Glue (things that are modelled, not measured), all documented in README:
  * photoreceptor transduction (brightness -> spike rate with adaptation)
  * retinotopic map (which photoreceptor neuron corresponds to which ommatidium)
  * odour plume (Gaussian around the food), smell/taste/touch transduction
  * the ventral nerve cord (not in the dataset): a walking pattern generator that
    descending neurons speed up, slow down, steer and reverse
"""
import argparse, json, os, time
import numpy as np
import mujoco as mj
import imageio

from flygym import Simulation
from flygym.anatomy import BodySegment, LEGS
from flygym.compose import FlatGroundWorld
from flygym.utils.math import Rotation3D
from flygym.vision.retina import Retina
from flygym_demo.complex_terrain import (HybridTurningController, HybridControllerObservation, LocomotionAction,
                                         PreprogrammedSteps, apply_locomotion_action, make_locomotion_fly, make_tripod_cpg_network)
from flygym.compose.fly.base_fly import ActuatorType
from fullfly import make_full_fly, FullBodyActions
from wings import add_flight, solve_base_stroke, Flight, AIR
from brain import Brain

p = argparse.ArgumentParser()
p.add_argument("--seconds", type=float, default=20.0)
p.add_argument("--out", default="out/run1")
p.add_argument("--base", type=float, default=0.5, help="baseline walking drive of the nerve-cord pattern generator")
p.add_argument("--seed", type=int, default=1)
p.add_argument("--spawn", type=float, nargs=3, default=None, help="x y yaw_deg")
p.add_argument("--demo-groom", type=float, default=0.0, help="debug: force a grooming bout for the first N seconds")
p.add_argument("--demo-fly", type=float, default=-1.0, help="force a take-off at this time (s)")
p.add_argument("--climb-p", type=float, default=0.6, help="probability that a fly meeting a wall head-on climbs it")
p.add_argument("--published-brain", action="store_true", help="use the published model without the antennal-lobe and sensory corrections")
p.add_argument("--turn-gain", type=float, default=100.0, help="Hz of DNa02 left-right difference that gives a full-strength turn")
args = p.parse_args()
os.makedirs(args.out + "/frames", exist_ok=True)

DT = 1e-4
CHUNK = 100               # brain/body steps per control tick (10 ms)
VISION_EVERY = 2          # ticks between eye updates (20 ms)
FRAME_EVERY = 3.3333      # ticks between video frames (30 fps)

# ----------------------------------------------------------------------------- brain
b = Brain("Drosophila_brain_model/Completeness_783.csv", "Drosophila_brain_model/Connectivity_783.parquet", "data/flywire_annotations_783.tsv")
if not args.published_brain:
    b.apply_biology_fixes()
a = b.ann
pos = a[["pos_x", "pos_y", "pos_z"]].to_numpy() * np.array([4, 4, 40]) / 1000.0
side = a["side"].to_numpy()
sc = a["super_class"].to_numpy()

# Photoreceptors -> ommatidia (retinotopic map by position: PC2 of the lamina/medulla sheet
# runs anterior->posterior, y runs dorsal->ventral in FlyWire coordinates)
retina = Retina()
cent = np.load("out/omm_centroids.npy")           # (721, 2) row, col in the eye image
omm_norm = np.stack([cent[:, 0] / retina.nrows, cent[:, 1] / retina.ncols], 1)
photo_idx, photo_omm, photo_eye, photo_cls = [], [], [], []
for eye, sname in enumerate(["left", "right"]):
    for ci, t in enumerate(["R1-6", "R7", "R8"]):
        idx = np.intersect1d(b.find(t), np.flatnonzero(side == sname))
        P = pos[idx] - pos[idx].mean(0)
        _, _, vt = np.linalg.svd(P, full_matrices=False)
        pc2 = P @ vt[1]
        if np.corrcoef(pc2, pos[idx, 2])[0, 1] < 0:   # make PC2 increase toward posterior (larger z)
            pc2 = -pc2
        u = np.argsort(np.argsort(pc2)) / (len(idx) - 1)            # 0 anterior .. 1 posterior
        v = np.argsort(np.argsort(pos[idx, 1])) / (len(idx) - 1)    # 0 dorsal .. 1 ventral
        # eye image: left eye medial at high columns, right eye medial at low columns
        lateral = (1 - omm_norm[:, 1]) if eye == 0 else omm_norm[:, 1]
        lat = (lateral - lateral.min()) / np.ptp(lateral)
        elev = (omm_norm[:, 0] - omm_norm[:, 0].min()) / np.ptp(omm_norm[:, 0])
        target = np.stack([lat, elev], 1)
        d = ((np.stack([u, v], 1)[:, None, :] - target[None, :, :]) ** 2).sum(-1)
        photo_idx.append(idx); photo_omm.append(d.argmin(1)); photo_eye.append(np.full(len(idx), eye)); photo_cls.append(np.full(len(idx), ci))
photo_idx = np.concatenate(photo_idx); photo_omm = np.concatenate(photo_omm); photo_eye = np.concatenate(photo_eye); photo_cls = np.concatenate(photo_cls)
# per-ommatidium colour from the raw eye images: mean RGB over each ommatidium's pixels
omm_ids = retina.ommatidia_id_map.ravel(); omm_px = retina.num_pixels_per_ommatidia.astype(float)
pale = retina.pale_type_mask.astype(bool)          # pale ommatidia sample blue, yellow ones sample green (R8p / R8y)
def eye_rgb(raw):                                   # raw: (2, H, W, 3) -> (2, 721, 3) in [0, 1]
    out = np.zeros((2, retina.num_ommatidia_per_eye, 3))
    for e in range(2):
        flat = raw[e].reshape(-1, 3).astype(float)
        for ch in range(3):
            out[e, :, ch] = np.bincount(omm_ids, weights=flat[:, ch], minlength=retina.num_ommatidia_per_eye + 1)[1:] / omm_px / 255.0
    return out
print(f"[map] {len(photo_idx)} photoreceptor neurons mapped onto 2 x {retina.num_ommatidia_per_eye} ommatidia")

# Visual projection neurons that carry known features from the optic lobe into the central brain
lc10a = (b.find("LC10a", "left"), b.find("LC10a", "right"))                       # small dark object -> pursuit / turning toward it
loom = (np.concatenate([b.find("LC4", "left"), b.find("LPLC2", "left")]), np.concatenate([b.find("LC4", "right"), b.find("LPLC2", "right")]))   # looming -> giant fibre escape
# black-object detection per eye, time-smoothed so a thin stripe does not flicker
dark_mass = np.zeros(2); dark_slow = np.zeros(2); vis_feat = np.zeros(4)
food_orn = np.flatnonzero(a["type"].isin(["ORN_DM1", "ORN_DM4", "ORN_VA2", "ORN_DM2"]).to_numpy())
food_orn_L = food_orn[side[food_orn] == "left"]; food_orn_R = food_orn[side[food_orn] == "right"]
sugar = np.flatnonzero(a["cell_sub_class"].isin(["sugar", "sugar/low_salt"]).to_numpy())
head_bristle = np.flatnonzero((a["cell_sub_class"].isin(["head bristle"]) | a["type"].isin(["BM_Ant"])).to_numpy())
head_bristle_L = head_bristle[side[head_bristle] == "left"]; head_bristle_R = head_bristle[side[head_bristle] == "right"]
mn9 = np.array([b.id2i[720575940660219265]])   # MN9, proboscis extension motor neuron (ID from Shiu et al. 2024)
groups = {k: (b.find(k, "left"), b.find(k, "right")) for k in ["DNa02", "DNa01", "DNp09", "MDN", "DNp01", "DNa03", "DNb01", "DNg12"]}
groups["MN9"] = (mn9, mn9)
# sweet-reward dopamine neurons (PAM-beta'2, PAM-gamma4, PAM-alpha1 subtypes; Burke 2012, Liu 2012, Yamagata 2015, Huetteroth 2015)
reward_pam = np.flatnonzero(a["type"].isin(["PAM02", "PAM07", "PAM08", "PAM11"]).to_numpy())
groups["PAMrw"] = (reward_pam[side[reward_pam] == "left"], reward_pam[side[reward_pam] == "right"])
print(f"[reward] {len(reward_pam)} sweet-reward dopamine neurons")
dn_all = np.flatnonzero(sc == "descending")
dn_L = dn_all[side[dn_all] == "left"]; dn_R = dn_all[side[dn_all] == "right"]
groups["DNpop"] = (dn_L, dn_R)
print(f"[readout] descending population: {len(dn_L)} left, {len(dn_R)} right")
print("[groups]", {k: (len(v[0]), len(v[1])) for k, v in groups.items()}, "food ORN", len(food_orn), "sugar", len(sugar), "head bristle", len(head_bristle))

# ----------------------------------------------------------------------------- body + box
fly = make_full_fly(adhesion_gain=400.0, name="fly")
add_flight(fly)                                   # wings get air to push on and 200 Hz motors (wings.py)
fly.add_vision()
follow = fly.add_tracking_camera(name="follow", pos_offset=(-3, -12, 12), rotation=Rotation3D("xyaxes", (1, 0, 0, 0, 0.72, 0.69)), fovy=42.0)
close = fly.add_tracking_camera(name="close", pos_offset=(2.4, -4.2, 2.0), rotation=Rotation3D("xyaxes", (0.87, 0.5, 0, -0.2, 0.35, 0.92)), fovy=38.0)   # close-up for feeding and grooming
# mirrored twins, used by the renderer when the primary camera would sit inside a wall
follow_b = fly.add_tracking_camera(name="follow_b", pos_offset=(3, 12, 12), rotation=Rotation3D("xyaxes", (-1, 0, 0, 0, -0.72, 0.69)), fovy=42.0)
close_b = fly.add_tracking_camera(name="close_b", pos_offset=(-2.4, 4.2, 2.0), rotation=Rotation3D("xyaxes", (-0.87, -0.5, 0, 0.2, -0.35, 0.92)), fovy=38.0)
world = FlatGroundWorld()
if not os.environ.get("FLY_NOAIR"): world.mjcf_root.option.density = AIR["density"]; world.mjcf_root.option.viscosity = AIR["viscosity"]   # air
rng = np.random.default_rng(args.seed)
start_yaw = rng.uniform(-np.pi, np.pi); start_xy = [0.0, 0.0]
if args.spawn:
    start_xy, start_yaw = args.spawn[:2], np.deg2rad(args.spawn[2])
world.add_fly(fly, [start_xy[0], start_xy[1], 0.5], Rotation3D("quat", [np.cos(start_yaw / 2), 0, 0, np.sin(start_yaw / 2)]))
wb = world.mjcf_root.worldbody
# the eye cameras skip geom group 2; put the legs there too so the fly does not watch its own legs
for g in world.mjcf_root.geoms:
    if g.name and g.name.startswith("fly/") and any(leg in g.name for leg in ("lf_", "lm_", "lh_", "rf_", "rm_", "rh_")):
        g.group = 2
H, W, T = 12.0, 30.0, 0.5
for name, p_, size in [("wall_n", [W, 0, H / 2], [T, W, H / 2]), ("wall_s", [-W, 0, H / 2], [T, W, H / 2]), ("wall_e", [0, -W, H / 2], [W, T, H / 2]), ("wall_w", [0, W, H / 2], [W, T, H / 2])]:
    wb.add_geom(name=name, type=mj.mjtGeom.mjGEOM_BOX, size=size, pos=p_, rgba=[0.86, 0.84, 0.80, 1])
wb.add_geom(name="stripe", type=mj.mjtGeom.mjGEOM_BOX, size=[0.05, 2.0, H / 2], pos=[W - T - 0.05, 6, H / 2], rgba=[0.05, 0.05, 0.05, 1], contype=0, conaffinity=0)
POST = np.array([12.0, -10.0]); FOOD = np.array([18.0, 8.0])
wb.add_geom(name="post", type=mj.mjtGeom.mjGEOM_CYLINDER, size=[0.8, 4, 0], pos=[POST[0], POST[1], 4], rgba=[0.1, 0.1, 0.1, 1])
wb.add_geom(name="food", type=mj.mjtGeom.mjGEOM_CYLINDER, size=[2.5, 0.05, 0], pos=[FOOD[0], FOOD[1], 0.05], rgba=[0.75, 0.35, 0.15, 1], contype=0, conaffinity=0)
wb.add_camera(name="overhead", pos=[0, 0, 95], quat=[1, 0, 0, 0], fovy=42)
spec = world.mjcf_root
all_ground = [pr.geomname1 for pr in spec.pairs if pr.geomname2 == "ground_plane"]
fly_geoms = [g for g in all_ground if not any(leg in g for leg in ("lf_", "lm_", "lh_", "rf_", "rm_", "rh_"))]
leg_wall_pairs = []
for obstacle in ["wall_n", "wall_s", "wall_e", "wall_w", "post"]:
    for g in all_ground:
        pr = spec.add_pair(); pr.geomname1 = g; pr.geomname2 = obstacle
        pr.solref = [0.002, 1.0]; pr.solimp = [0.95, 0.99, 0.001, 0.5, 2.0]; pr.margin = 0.2   # stiff wall
        pr.friction = [1.0, 1.0, 0.005, 0.0001, 0.0001]
        if g not in fly_geoms: leg_wall_pairs.append((g, obstacle))
all_geoms = {g.name for g in spec.geoms}
for g in ("fly/c_haustellum", "fly/c_rostrum", "fly/c_head"):
    if g in all_geoms:
        pr = spec.add_pair(); pr.geomname1 = g; pr.geomname2 = "food"; pr.solref = [0.002, 1.0]; pr.solimp = [0.95, 0.99, 0.001, 0.5, 2.0]   # the proboscis rests on the food surface
print(f"[box] {len(fly_geoms)} body parts collide with the walls and post:", fly_geoms)
sim = Simulation(world)
WBASE = solve_base_stroke(sim, fly, cache="wing_stroke.npz")     # the wing stroke, solved on this model's hinges (cached)
sim.set_renderer([follow, close, "overhead", follow_b, close_b], camera_res=(480, 640), playback_speed=1.0, output_fps=30, buffer_frames=True)

steps = PreprogrammedSteps()
BODY = FullBodyActions(fly, steps)
dof_order = BODY.leg_dofs                      # the walking controller drives the 42 active leg joints
net = make_tripod_cpg_network(timestep=sim.timestep, intrinsic_amplitude=1.0, coupling_strength=10.0, convergence_coef=20.0, seed=args.seed)
ctrl = HybridTurningController(timestep=sim.timestep, cpg_network=net, preprogrammed_steps=steps, output_dof_order=dof_order)
sim.reset(); ctrl.reset(seed=args.seed)
for _ in range(20000): net.step()                 # let the leg oscillators lock into the tripod pattern before the first step
sim.set_actuator_inputs("fly", ActuatorType.POSITION, BODY.stand); sim.set_leg_adhesion_states("fly", np.ones(6, dtype=bool))
sim.warmup()
segs = fly.get_bodysegs_order()
# joints for the proboscis, head, antennae and grooming postures
J = BODY.i
ROS, HAU, HEADP = J("c_head", "c_rostrum", "pitch"), J("c_rostrum", "c_haustellum", "pitch"), J("c_thorax", "c_head", "pitch")
ANT = [J("c_head", "l_pedicel", "pitch"), J("c_head", "r_pedicel", "pitch")]
WJ = {s_: {ax: J("c_thorax", f"{s_}_wing", ax) for ax in ("yaw", "pitch", "roll")} for s_ in "lr"}
flight = Flight(WBASE, DT)
ROOTJ = [j for j in range(sim.mj_model.njnt) if sim.mj_model.jnt_type[j] == mj.mjtJoint.mjJNT_FREE][0]; RQ = sim.mj_model.jnt_qposadr[ROOTJ]; RD = sim.mj_model.jnt_dofadr[ROOTJ]
FLIGHT_MODES = ("takeoff", "flight", "landing", "touchdown")
WING_ACT = np.array([i for i in range(sim.mj_model.nu) if "wing" in (mj.mj_id2name(sim.mj_model, mj.mjtObj.mjOBJ_ACTUATOR, i) or "")])
def wing_motors(flying):
    """Flight muscles are stiff (kp 350) only while flying; at rest the folded wings are held softly (kp 45), which keeps walking stable."""
    kp = 350.0 if flying else 45.0
    sim.mj_model.actuator_gainprm[WING_ACT, 0] = kp; sim.mj_model.actuator_biasprm[WING_ACT, 1] = -kp
wing_motors(False)
def LEG(side, joint, ax):
    p, c = {"coxa": ("c_thorax", f"{side}_coxa"), "troch": (f"{side}_coxa", f"{side}_trochanterfemur"), "tibia": (f"{side}_trochanterfemur", f"{side}_tibia")}[joint]
    return J(p, c, ax)
def groom_pose(kind, phase):
    """Joint targets (full vector) and adhesion for one grooming action, phase in [0, 1)."""
    a = BODY.stand.copy(); adh = np.ones(6, dtype=bool); w = np.sin(2 * np.pi * phase)
    if kind == "front rub":            # front legs together under the head, rubbing
        for sd in ("lf", "rf"):
            sg = 1 if sd == "lf" else -1
            a[LEG(sd, "coxa", "pitch")] -= np.radians(70); a[LEG(sd, "troch", "pitch")] += np.radians(60 + 15 * w * sg); a[LEG(sd, "tibia", "pitch")] -= np.radians(110 + 15 * w * sg)
        adh[[0, 3]] = False
    elif kind == "head groom":         # front legs sweep down over the eyes and antennae
        for sd in ("lf", "rf"):
            sg = 1 if sd == "lf" else -1
            a[LEG(sd, "coxa", "pitch")] -= np.radians(90); a[LEG(sd, "coxa", "roll")] += np.radians(20 * sg)
            a[LEG(sd, "troch", "pitch")] += np.radians(20 + 25 * w); a[LEG(sd, "tibia", "pitch")] -= np.radians(70 + 20 * w)
        a[HEADP] -= np.radians(20 + 8 * w); a[ANT[0]] -= np.radians(20 * w); a[ANT[1]] -= np.radians(20 * w)
        adh[[0, 3]] = False
    elif kind == "hind rub":           # hind legs rub each other under the abdomen
        for sd in ("lh", "rh"):
            sg = 1 if sd == "lh" else -1
            a[LEG(sd, "coxa", "pitch")] += np.radians(130); a[LEG(sd, "troch", "pitch")] -= np.radians(100 + 15 * w * sg); a[LEG(sd, "tibia", "pitch")] += np.radians(130 + 15 * w * sg)
        adh[[2, 5]] = False
    return a, adh
I_HEAD, I_THORAX = segs.index(BodySegment("c_head")), segs.index(BodySegment("c_thorax"))

# ----------------------------------------------------------------------------- wall climbing (nerve-cord level posture programme, see README)
leg_stand = steps.default_pose_by_dof_order(dof_order)
def LI(parent, child, axis):
    hits = [i for i, d_ in enumerate(dof_order) if d_.parent.name == parent and d_.child.name == child and d_.axis.value == axis]; assert len(hits) == 1, (parent, child, axis); return hits[0]
LEGD = {s_: {"Coxa": LI("c_thorax", f"{s_}_coxa", "pitch"), "Femur": LI(f"{s_}_coxa", f"{s_}_trochanterfemur", "pitch"), "Tibia": LI(f"{s_}_trochanterfemur", f"{s_}_tibia", "pitch")} for s_ in LEGS}
REAR = dict(fF=60, hF=-50, hC=40, mC=40, mF=20, mT=-20)      # rearing (deg): front legs extend, hind legs flex and swing forward, middle legs push
REACH = dict(Coxa=-40, Femur=-20, Tibia=30)                   # front-leg lift toward the wall; the tibia then sweeps forward until the foot meets the wall
HEXT, BLEND, CLIMB_DRIVE, SWEEP = -30.0, 1.5, 0.5, 120.0
NOSE_UP = float(os.environ.get("FLY_NOSE", 25.0))              # rearing target (deg); the posture is servoed to it, so it adapts to the body
if os.environ.get("FLY_REAR"): REAR.update(json.loads(os.environ["FLY_REAR"]))
if os.environ.get("FLY_REACH"): REACH.update(json.loads(os.environ["FLY_REACH"]))
SWEEP = float(os.environ.get("FLY_SWEEP", SWEEP))
print("[climb] REAR", REAR, "REACH", REACH, "SWEEP", SWEEP)
CLIMB_MODES = ("approach", "mount", "climb", "turnaround", "descend", "dismount")
def rear_pose(a, u):
    for s_ in ("lf", "rf"): a[LEGD[s_]["Femur"]] += np.radians(REAR["fF"]) * u
    for s_ in ("lh", "rh"): a[LEGD[s_]["Femur"]] += np.radians(REAR["hF"]) * u; a[LEGD[s_]["Coxa"]] += np.radians(REAR["hC"]) * u
    for s_ in ("lm", "rm"): a[LEGD[s_]["Coxa"]] += np.radians(REAR["mC"]) * u; a[LEGD[s_]["Femur"]] += np.radians(REAR["mF"]) * u; a[LEGD[s_]["Tibia"]] += np.radians(REAR["mT"]) * u
    return a
I_T5 = [segs.index(BodySegment(f"{l}_tarsus5")) for l in LEGS]
th_body = sim._internal_bodyids_by_fly["fly"][I_THORAX]
GNAME = [mj.mj_id2name(sim.mj_model, mj.mjtObj.mjOBJ_GEOM, i) or "" for i in range(sim.mj_model.ngeom)]
WALL_GIDS = {i for i, n in enumerate(GNAME) if n.split("/")[-1] in ("wall_n", "wall_s", "wall_e", "wall_w")}
print("[climb] wall geoms:", {GNAME[i]: i for i in WALL_GIDS})
_LEGS = ("lf_", "lm_", "lh_", "rf_", "rm_", "rh_"); _WALLS = ("wall_n", "wall_s", "wall_e", "wall_w", "post")
PAIR_LEGWALL = np.array([i for i in range(sim.mj_model.npair) if any(l in GNAME[sim.mj_model.pair_geom1[i]] + GNAME[sim.mj_model.pair_geom2[i]] for l in _LEGS) and any(w in GNAME[sim.mj_model.pair_geom1[i]] + GNAME[sim.mj_model.pair_geom2[i]] for w in _WALLS)], dtype=int)
print(f"[climb] {len(PAIR_LEGWALL)} leg-wall contact pairs, active only while climbing")
def leg_wall_contacts(on):
    """Legs touch the walls only while climbing. On the floor the walls are followed by the body and the head
    bristles, as before; leg-wall contacts there tip the fly over during wall following."""
    if os.environ.get("FLY_NOGATE"): on = True
    sim.mj_model.pair_margin[PAIR_LEGWALL] = 0.2 if on else -1.0          # a negative margin: the pair is never detected
leg_wall_contacts(False)
def legs_on_wall():
    out = set(); dd = sim.mj_data
    for c in range(dd.ncon):
        con = dd.contact[c]
        if con.geom1 in WALL_GIDS or con.geom2 in WALL_GIDS:
            other = GNAME[con.geom2 if con.geom1 in WALL_GIDS else con.geom1].split("/")[-1][:2]
            if other in LEGS: out.add(other)
    return out
def body_frame_obs():
    """Leg reflexes work relative to the body, not to gravity: 'height' is measured along the fly's own up axis."""
    obs = HybridControllerObservation.from_sim(sim, "fly")
    R = sim.mj_data.xmat[th_body].reshape(3, 3); up = R[:, 2]; pos_ = sim.get_body_positions("fly")
    obs.thorax_z = float(pos_[I_THORAX] @ up); obs.tarsus5_z = np.array([pos_[i] @ up for i in I_T5]); return obs
def mount_pose(inner, dt):
    """One physics step of the mounting programme: rear up, then plant each front foot on the wall (lift, sweep until touch, glue)."""
    inner.mount_t += dt; tt = inner.mount_t
    R_ = sim.mj_data.xmat[th_body].reshape(3, 3); nose = np.degrees(np.arcsin(np.clip(R_[2, 0], -1, 1)))
    inner.u0 = float(np.clip(inner.u0 + 2.5 * (NOSE_UP - nose) / NOSE_UP * dt, 0.0, 1.3))     # rear until the nose is up by NOSE_UP degrees, hold it there
    u0 = inner.u0
    a = rear_pose(leg_stand.copy(), u0); adh6 = np.ones(6, dtype=bool)
    on_wall = legs_on_wall() if tt > 0.4 else set()
    for n_, (nm, ia) in enumerate((("lf", 0), ("rf", 3))):
        t0 = 0.45 + 0.7 * n_
        u1 = float(np.clip((tt - t0) / 0.15, 0, 1))
        if tt >= t0 and inner.planted[nm] is None:
            inner.sweep[nm] = min(inner.sweep[nm] + dt / 0.5, 1.0) if tt > t0 + 0.17 else 0.0
            if nm in on_wall and tt > t0 + 0.2: inner.planted[nm] = inner.sweep[nm]
            elif tt > t0 + 0.65: inner.planted[nm] = -1.0                      # found no wall
            if inner.planted[nm] is not None:
                pp = sim.get_body_positions("fly"); R_ = sim.mj_data.xmat[th_body].reshape(3, 3)
                print(f"[climb]   {nm} {'planted' if inner.planted[nm] >= 0 else 'missed'} at sweep {inner.sweep[nm]:.2f}: tarsus {np.round(pp[I_T5[ia]], 2)} thorax {np.round(pp[I_THORAX], 2)} nose-up {np.degrees(np.arcsin(np.clip(R_[2, 0], -1, 1))):.0f} deg")
        sw = inner.sweep[nm] if inner.planted[nm] is None else max(0.0, inner.planted[nm])
        L = LEGD[nm]
        a[L["Coxa"]] += np.radians(REACH["Coxa"]) * u1; a[L["Femur"]] += np.radians(REACH["Femur"] - REAR["fF"] * u0) * u1
        a[L["Tibia"]] += np.radians(REACH["Tibia"]) * u1 - np.radians(SWEEP) * sw
        adh6[ia] = not (tt > t0 and inner.planted[nm] is None)
        inner.front_pose[nm] = (a[L["Coxa"]], a[L["Femur"]], a[L["Tibia"]])
    a = (1 - min(1.0, tt / 0.15)) * inner.last_legs + min(1.0, tt / 0.15) * a
    done = tt > 0.45 + 0.7 * 2 + 0.1
    return a, adh6, done
def climb_bias(inner):
    """Fade the mounting posture out while the gait takes over on the wall."""
    w = max(0.0, 1.0 - inner.climb_t / BLEND)
    bias = rear_pose(np.zeros_like(leg_stand), 1.0)
    for nm in ("lf", "rf"):
        for j_, v in zip(("Coxa", "Femur", "Tibia"), inner.front_pose[nm]): bias[LEGD[nm][j_]] = v - leg_stand[LEGD[nm][j_]]
    for s_ in ("lh", "rh"): bias[LEGD[s_]["Tibia"]] += np.radians(HEXT) * min(1.0, inner.climb_t / 0.5)
    return bias * w, w
I_TARSI = [segs.index(BodySegment(n)) for n in ("lf_tarsus5", "rf_tarsus5")]                 # front feet (tarsal sugar receptors)
G_HAU = mj.mj_name2id(sim.mj_model, mj.mjtObj.mjOBJ_GEOM, "fly/c_haustellum")                  # the proboscis tip (labellum)
FOOD_R, FOOD_TOP = 2.5, 0.1

# ----------------------------------------------------------------------------- behaviour layer
# Internal state and nerve-cord-level behaviour that the wiring-only model cannot produce, built from
# published fly behaviour (see README): walking bouts and pauses, spontaneous turns, wall following,
# odour-gradient turning scaled by hunger, feeding to satiety, blocked-leg reflex.
class Inner:
    def __init__(self, rng):
        self.rng = rng
        self.hunger = 0.9                 # 0 full .. 1 starved (a starved fly walks more and chases smell)
        self.mode = "walk"                # walk | pause | feed | wall | escape
        self.bout_t = rng.uniform(2.0, 6.0)   # time left in the current bout
        self.turn_bias = 0.0              # current spontaneous turn command (-1 left .. +1 right)
        self.turn_t = 0.0                 # time left in the current spontaneous turn
        self.wall_side = 0.0              # +1 wall on the right, -1 on the left
        self.odour_prev = 0.0
        self.search = 0.0                 # local-search intensity after losing the odour
        self.groom_kind = "front rub"; self.groom_t = 0.0; self.groom_phase = 0.0; self.dust = 0.0   # bristle contact builds "dust" that makes grooming likelier
        self.reward = 0.0                 # sugar reward being delivered right now (hunger x intake)
        self.memory = 0.0                 # appetitive memory of this food smell, built by reward paired with smell
        self.climb_block = 0.0; self.mount_t = 0.0; self.climb_t = 0.0; self.turn_dir = 1.0; self.mount_done = False
        self.flight_t = 0.0; self.yaw_cmd = 0.0; self.z_t = 5.0; self.v_t = 0.0; self.righting = False; self.down_t = 0.0; self.right_block = 0.0
        self.planted = {"lf": None, "rf": None}; self.sweep = {"lf": 0.0, "rf": 0.0}; self.front_pose = {}; self.last_legs = None
inner = Inner(rng)
odour_LR = np.zeros(2); heading = np.array([np.cos(np.radians(args.spawn[2] if args.spawn else 0.0)), np.sin(np.radians(args.spawn[2] if args.spawn else 0.0))])

# ----------------------------------------------------------------------------- loop
n_ticks = int(args.seconds / (CHUNK * DT))
rates = {k: np.zeros(2) for k in groups}          # smoothed Hz, [left, right]
TAU_RATE = 0.08
inputs_adapt = None
odour_adapt = np.zeros(2); touch_adapt = 0.0
log = {"t": [], "pose": [], "drive": [], "rates": {k: [] for k in groups}, "events": [], "inputs": [], "frames": []}
spike_frames = []                                 # per video frame: neuron ids that spiked
spikes_since_frame = []
events = {"feeding": 0, "startle": 0, "climb": 0, "fall": 0, "takeoff": 0, "crash": 0, "righting": 0}
next_frame = 0.0; frame_i = 0
t_wall = time.time()
print(f"[run] {args.seconds} s = {n_ticks} ticks")
for tick in range(n_ticks):
    t = tick * CHUNK * DT
    bp = sim.get_body_positions("fly")
    head, thorax = bp[I_HEAD], bp[I_THORAX]
    R_th = sim.mj_data.xmat[th_body].reshape(3, 3); up_z = float(R_th[2, 2]); fwd3 = R_th[:, 0]
    if up_z > 0.6:
        heading = HybridControllerObservation.from_sim(sim, "fly").fly_heading
    yaw = np.arctan2(heading[1], heading[0])
    head = thorax + 1.4 * np.array([heading[0], heading[1], 0.0])      # the face, in front of the thorax

    # --- senses -> sensory neurons
    if tick % VISION_EVERY == 0:
        rgb = eye_rgb(sim.get_raw_vision("fly"))             # (2, 721, 3)
        lum = 0.30 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]   # (2, 721): what R1-6 see
        colour = np.where(pale[None, :], rgb[..., 2], rgb[..., 1])             # R8: blue in pale ommatidia, green in yellow ones
        uv = rgb[..., 2]                                                        # R7 is a UV cell; the renderer has no UV, blue stands in
        inputs = np.stack([lum, uv, colour], 0)                                 # (class, eye, omm)
        if inputs_adapt is None:
            inputs_adapt = inputs.copy()
        inputs_adapt += (inputs - inputs_adapt) * (VISION_EVERY * CHUNK * DT / 0.2)
        rate = np.clip(40.0 * inputs + 160.0 * np.abs(inputs - inputs_adapt), 0, 200)   # Hz: sustained + transient, per class
        b.rates[photo_idx] = rate[photo_cls, photo_eye, photo_omm]
        # optic-lobe feature extraction (the spiking model cannot do this part itself)
        darkness = (lum < 0.08).sum(axis=1).astype(float)                          # ommatidia seeing a black object (floor squares ~0.25, legs ~0.3)
        dt_v = VISION_EVERY * CHUNK * DT
        dark_mass += (darkness - dark_mass) * (dt_v / 0.08)                          # 80 ms smoothing (photoreceptor + lamina dynamics)
        dark_slow += (dark_mass - dark_slow) * (dt_v / 0.4)                           # what the object looked like ~0.4 s ago
        for e in range(2):
            obj = float(np.clip(dark_mass[e] / 6.0, 0, 1))                            # a fly-sized dark object covers ~6 ommatidia
            expansion = (dark_mass[e] - dark_slow[e]) / (0.4 * (dark_slow[e] + 1.0))  # relative growth rate, 1/s
            lm = float(np.clip((expansion - 2.0) / 3.0, 0, 1)) if dark_slow[e] > 2.0 else 0.0   # looming: a seen object growing more than threefold per second
            b.rates[lc10a[e]] = 150.0 * obj
            b.rates[loom[e]] = 150.0 * lm
            vis_feat[e] = obj; vis_feat[2 + e] = lm
    d_food = np.linalg.norm(head[:2] - FOOD)
    odour = np.exp(-d_food ** 2 / (2 * 14.0 ** 2))
    leftv = np.array([-heading[1], heading[0]])
    for k, (antenna, idx) in enumerate(((head[:2] + 0.45 * leftv, food_orn_L), (head[:2] - 0.45 * leftv, food_orn_R))):
        c = np.exp(-np.linalg.norm(antenna - FOOD) ** 2 / (2 * 14.0 ** 2))
        odour_adapt[k] += (c - odour_adapt[k]) * (CHUNK * DT / 0.8)      # receptor adaptation, ~0.8 s
        b.rates[idx] = 60.0 * (0.3 * c + 0.7 * max(0.0, c - odour_adapt[k]))
        odour_LR[k] = c
    mouth = sim.mj_data.geom_xpos[G_HAU].copy(); mouth[2] -= sim.mj_model.geom_rbound[G_HAU]   # lowest point of the labellum
    mouth_on_food = np.linalg.norm(mouth[:2] - FOOD) < FOOD_R - 0.2 and mouth[2] < FOOD_TOP + 0.25     # labellum touching the sugar
    feet_on_food = any(np.linalg.norm(bp[i][:2] - FOOD) < FOOD_R for i in I_TARSI)                     # a front foot standing on the sugar
    tasting = mouth_on_food or feet_on_food                                                             # tarsal + labellar sugar receptors
    b.rates[sugar] = 100.0 if tasting else 0.0
    # nearest obstacle and which side of the head it is on
    walls = [(W - T - head[0], np.array([-1.0, 0.0])), (W - T + head[0], np.array([1.0, 0.0])), (W - T - head[1], np.array([0.0, -1.0])), (W - T + head[1], np.array([0.0, 1.0]))]
    to_post = POST - head[:2]; walls.append((np.linalg.norm(to_post) - 0.8, to_post / (np.linalg.norm(to_post) + 1e-9)))
    obst_i = int(np.argmin([w_[0] for w_ in walls])); obst_d, obst_dir = walls[obst_i]
    touching = obst_d < 1.4
    bearing_s = float(heading[0] * obst_dir[1] - heading[1] * obst_dir[0])        # +1 obstacle on the left, -1 on the right
    touch_adapt += ((1.0 if touching else 0.0) - touch_adapt) * (CHUNK * DT / 0.5)
    strength = 80.0 * (0.3 + 0.7 * max(0.0, 1.0 - touch_adapt)) if touching else 0.0
    b.rates[head_bristle_L] = strength * (0.5 + 0.5 * bearing_s)
    b.rates[head_bristle_R] = strength * (0.5 - 0.5 * bearing_s)

    # --- brain: 10 ms of every neuron
    st, si = b.run(CHUNK, seed=args.seed * 100000 + tick, max_spikes=3_000_000)
    spikes_since_frame.append(si)
    counts = np.bincount(si, minlength=b.N)
    alpha = CHUNK * DT / TAU_RATE
    for k, (l, r) in groups.items():
        inst = np.array([counts[l].mean() if len(l) else 0, counts[r].mean() if len(r) else 0]) / (CHUNK * DT)
        rates[k] += (inst - rates[k]) * alpha

    # --- descending neurons -> nerve cord pattern generator -> legs
    dt_c = CHUNK * DT
    popL, popR = rates["DNpop"]
    brain_turn = (popR - popL) / (popR + popL + 2.0)        # what the real brain says, left-right imbalance of all descending neurons
    fwd = 0.0; turn = brain_turn; back = 0.0
    feeding_now = False

    # hunger drives everything: a starved fly walks more, faster, and follows smell
    h = inner.hunger
    inner.bout_t -= dt_c
    inner.dust = min(1.0, inner.dust + (0.25 * dt_c if touching else 0.0)); inner.dust *= (1 - 0.02 * dt_c)
    if inner.mode in ("walk", "pause") and inner.bout_t <= 0:
        if inner.mode == "walk":
            if rng.random() < 0.45 + 0.5 * inner.dust + 0.3 * (1 - h):                      # flies groom in many of their pauses, more when full
                inner.mode = "groom"; inner.bout_t = rng.uniform(2.0, 4.0); inner.groom_kind = rng.choice(["front rub", "head groom", "hind rub"]); inner.groom_t = 0.0
            else:
                inner.mode = "pause"; inner.bout_t = rng.uniform(0.4, 1.5) * (1.5 - h)      # hungry flies pause less
        else:
            inner.mode = "walk"; inner.bout_t = rng.uniform(2.0, 8.0) * (0.5 + h)
    if args.demo_groom > 0 and t < args.demo_groom and inner.mode != "groom":
        inner.mode = "groom"; inner.bout_t = args.demo_groom - t; inner.groom_t = 0.0; inner.groom_kind = "front rub"
    if inner.mode == "groom" and args.demo_groom > 0 and t < args.demo_groom:
        inner.groom_kind = ["front rub", "head groom", "hind rub"][min(2, int(3 * t / args.demo_groom))]
    if inner.mode == "groom":
        if rates["DNg12"].mean() > 10: inner.groom_kind = "head groom"                       # the brain's antennal-grooming command neuron
        inner.groom_t += dt_c; inner.groom_phase = (inner.groom_phase + dt_c * 6.0) % 1.0   # ~6 Hz leg strokes
        if inner.groom_t > 1.2 and rng.random() < dt_c / 1.0:                                # switch action within a bout
            inner.groom_kind = rng.choice(["front rub", "head groom", "hind rub"]); inner.groom_t = 0.0
        if inner.bout_t <= 0:
            inner.mode = "walk"; inner.bout_t = rng.uniform(2.0, 8.0) * (0.5 + h); inner.dust *= 0.3
    elif rates["DNg12"].mean() > 10 and inner.mode in ("walk", "pause"):
        inner.mode = "groom"; inner.bout_t = rng.uniform(2.0, 4.0); inner.groom_kind = "head groom"; inner.groom_t = 0.0
    # spontaneous turns (saccade-like, roughly one every 1-2 s while walking)
    inner.turn_t -= dt_c
    if inner.turn_t <= 0:
        if rng.random() < dt_c / 1.5:
            inner.turn_bias = rng.choice([-1.0, 1.0]) * rng.uniform(0.3, 0.8); inner.turn_t = rng.uniform(0.2, 0.5)
        else:
            inner.turn_bias = 0.0
    # smell: turn toward the antenna that smells more food (bilateral comparison), scaled by hunger;
    # if the smell is fading, search harder (local search)
    od = odour_LR.mean()
    grad = (odour_LR[1] - odour_LR[0]) / (od + 0.02)          # +: right antenna smells more
    inner.search += (max(0.0, inner.odour_prev - od) * 40.0 - inner.search) * dt_c / 1.0
    inner.odour_prev = od
    odour_turn = np.clip(grad * 6.0, -1, 1) * min(1.0, h + 0.6 * inner.memory) * min(1.0, od * 4)   # hunger, or a learned food memory, drives smell-following
    # wall climbing: a fly that meets a wall head-on usually climbs it (flies spend much of their time on arena walls)
    inner.climb_block -= dt_c
    approach = -(heading[0] * obst_dir[0] + heading[1] * obst_dir[1]) if obst_i < 4 else 0.0
    if inner.mode in ("walk", "wall") and touching and approach > 0.6 and inner.climb_block <= 0 and up_z > 0.9:
        if rng.random() < args.climb_p:
            inner.mode = "approach"; inner.bout_t = 2.5; inner.climb_block = 8.0
        else:
            inner.climb_block = 3.0
    thorax_wall = W - T - max(abs(thorax[0]), abs(thorax[1]))                # thorax distance to the nearest wall face
    if inner.mode == "approach":
        if (thorax_wall < 1.0 and approach > 0.85) or inner.bout_t <= 0:
            if thorax_wall < 1.0:
                inner.mode = "mount"; inner.mount_t = 0.0; inner.u0 = 0.0; inner.planted = {"lf": None, "rf": None}; inner.sweep = {"lf": 0.0, "rf": 0.0}; events["climb"] += 1
                if inner.last_legs is None: inner.last_legs = leg_stand.copy()
            else:
                inner.mode = "wall"; inner.wall_side = 1.0 if bearing_s < 0 else -1.0; inner.bout_t = rng.uniform(1.0, 4.0)
    elif inner.mode == "mount":
        if inner.planted["lf"] == -1.0 and inner.planted["rf"] == -1.0:
            print(f"[climb] mount failed at t={t:.1f}: thorax {thorax_wall:.2f} mm from the wall, up={up_z:.2f}")
            inner.mode = "wall"; inner.wall_side = 1.0 if bearing_s < 0 else -1.0; inner.bout_t = rng.uniform(1.0, 4.0)   # no wall under the feet: give up
        elif inner.mount_done:
            print(f"[climb] mounted at t={t:.1f}: feet planted {inner.planted}, thorax {thorax_wall:.2f} mm from the wall, up={up_z:.2f}")
            inner.mode = "climb"; inner.climb_t = 0.0; inner.bout_t = rng.uniform(2.5, 6.0)
    elif inner.mode == "climb":
        inner.climb_t += dt_c
        if inner.bout_t <= 0 or thorax[2] > H - 3.0:
            inner.mode = "turnaround"; inner.turn_dir = rng.choice([-1.0, 1.0]); inner.bout_t = 4.0
    elif inner.mode == "turnaround" and getattr(inner, "turn_goal", "down") == "down":
        if fwd3[2] < -0.75 or inner.bout_t <= 0:
            inner.mode = "descend"; inner.bout_t = 20.0
    elif inner.mode == "descend":
        if thorax[2] < 3.0 or inner.bout_t <= 0:
            inner.mode = "turnaround"; inner.turn_dir = rng.choice([-1.0, 1.0]); inner.bout_t = 4.0; inner.turn_goal = "up"   # near the floor: turn and climb again (wall patrol)
    if inner.mode == "turnaround" and getattr(inner, "turn_goal", "down") == "up" and (fwd3[2] > 0.75 or inner.bout_t <= 0):
        inner.mode = "climb"; inner.climb_t = BLEND; inner.bout_t = rng.uniform(2.5, 6.0); inner.turn_goal = "down"
    if inner.mode in CLIMB_MODES and inner.mode != "approach" and (up_z < -0.5 or (thorax_wall > 2.5 and up_z < 0.5)):
        inner.mode = "walk"; inner.bout_t = 2.0; inner.climb_block = 10.0; events["fall"] += 1      # fell off
    # wall: a fly that meets a wall turns to run along it, and leaves it now and then
    if touching and inner.mode not in CLIMB_MODES + FLIGHT_MODES:
        if inner.mode != "wall":
            inner.mode = "wall"; inner.wall_side = 1.0 if bearing_s < 0 else -1.0; inner.bout_t = rng.uniform(1.0, 4.0)
    elif inner.mode == "wall" and inner.bout_t <= 0:
        inner.mode = "walk"; inner.bout_t = rng.uniform(2.0, 8.0)
    # food: the brain's own proboscis motor neuron (sugar -> MN9) says eat; eating fills the fly
    # sugar on the tarsi stops a hungry fly (a nerve-cord reflex); the brain's MN9 then extends the proboscis
    if inner.mode == "feed" and False:
        pass
    elif inner.mode == "feed":
        if tasting and h > 0.15:
            if mouth_on_food:
                feeding_now = True; inner.hunger = max(0.0, inner.hunger - 0.08 * dt_c)   # intake only while the labellum is on the sugar
        else:
            # after a meal a fly almost always grooms (post-feeding grooming), then wanders
            inner.mode = "groom"; inner.bout_t = rng.uniform(3.0, 6.0); inner.groom_kind = "front rub"; inner.groom_t = 0.0
    elif tasting and h > 0.15 and inner.mode not in ("escape",) + CLIMB_MODES + FLIGHT_MODES:
        inner.mode = "feed"; feeding_now = True
    # reward: a hungry fly eating sugar gets a dopamine burst in the real sweet-reward PAM neurons,
    # the way optogenetic reward experiments deliver it; it fades as the fly fills up (hunger gating)
    target = h if feeding_now else 0.0
    inner.reward += (target - inner.reward) * (dt_c / 0.3)
    b.rates[reward_pam] = 100.0 * inner.reward
    inner.memory = min(1.0, inner.memory + 0.12 * inner.reward * od * dt_c)                   # smell paired with reward -> food memory
    # escape: the brain's giant fibre fired on a looming object
    inner.gf_refractory = max(0.0, getattr(inner, "gf_refractory", 0.0) - dt_c)
    gf_now = rates["DNp01"].mean() > 40 and inner.gf_refractory <= 0
    if (gf_now or (0 <= args.demo_fly <= t < args.demo_fly + 0.02)) and inner.mode not in ("escape",) + CLIMB_MODES + FLIGHT_MODES:
        inner.gf_refractory = 3.0; events["startle"] += 1                                             # giant fibre habituates for a few seconds
        if up_z > 0.9:                                                                                # on the floor: the giant fibre's own output, take-off
            inner.mode = "takeoff"; inner.flight_t = 0.0; flight.reset(float(thorax[2])); inner.righting = False; events["takeoff"] += 1
        else:
            inner.mode = "escape"; inner.bout_t = 0.4
    if inner.mode in FLIGHT_MODES:
        inner.flight_t += dt_c
        if inner.mode == "takeoff" and inner.flight_t > 0.06:
            inner.mode = "flight"; inner.bout_t = 0.4 if inner.righting else rng.uniform(0.8, 1.6)
        elif inner.mode == "flight" and inner.bout_t <= 0:
            inner.mode = "landing"; inner.bout_t = 3.0
        elif inner.mode == "landing" and ((thorax[2] < 1.5 and up_z > 0.8) or inner.bout_t <= 0):
            inner.mode = "touchdown"; inner.bout_t = 0.1
        elif inner.mode == "touchdown" and inner.bout_t <= 0:
            inner.mode = "walk"; inner.bout_t = rng.uniform(1.0, 3.0); inner.righting = False
        if up_z < 0.3 and inner.mode != "takeoff" and not inner.righting:
            inner.mode = "walk"; inner.bout_t = 2.0; events["crash"] += 1; inner.righting = False
        # flight commands: height, forward speed, yaw from the brain's steering and from the walls ahead
        inner.z_t = (3.0 if inner.righting else 5.0) if inner.mode in ("takeoff", "flight") else 1.2
        inner.v_t = (0.0 if inner.righting else 25.0) if inner.mode == "flight" else 0.0
        yaw = 0.02 * brain_turn
        if obst_i < 4 and thorax_wall < 12.0 and approach > 0.0: yaw += -0.05 * np.sign(bearing_s) * (1.0 if thorax_wall < 8 else 0.6)   # wall ahead: turn away from it
        inner.yaw_cmd = float(np.clip(yaw, -0.06, 0.06))
    elif inner.mode == "escape":
        if inner.bout_t <= 0:
            inner.mode = "walk"; inner.bout_t = rng.uniform(2.0, 6.0)
    # righting: a fly on its side or back buzzes its wings; the flight stabiliser rolls it back onto its feet
    inner.down_t = inner.down_t + dt_c if (up_z < 0.5 and inner.mode not in FLIGHT_MODES + CLIMB_MODES) else 0.0
    if inner.down_t > 0.6 and inner.right_block <= 0:
        inner.mode = "takeoff"; inner.flight_t = 0.0; flight.reset(float(thorax[2])); inner.righting = True; inner.right_block = 3.0; events["righting"] += 1
    inner.right_block -= dt_c

    if inner.mode == "walk":
        fwd = (0.45 + 0.5 * h) * (1.0 - 0.6 * h * od)          # a hungry fly slows down in strong food smell (local search)
        turn = brain_turn + inner.turn_bias + odour_turn + inner.search * rng.uniform(-1, 1)
    elif inner.mode in ("pause", "groom"):
        fwd = 0.0; turn = 0.0
    elif inner.mode == "wall":
        fwd = 0.35 + 0.3 * h
        turn = brain_turn + 0.9 * (-inner.wall_side) * (1.0 if touching else 0.3) + odour_turn   # turn away from the wall, then run along it
        if touching and obst_d < -0.3:
            back = 0.6                                                                          # blocked: back off first
    elif inner.mode == "feed":
        fwd = 0.0 if mouth_on_food else 0.3; turn = 0.0                       # feet found sugar: creep forward until the mouth reaches it, then stop
        if feeding_now: events["feeding"] += 1
    elif inner.mode == "escape":
        fwd = -1.0; turn = 0.0
    elif inner.mode == "approach":
        fwd = 0.35; turn = 0.7 * bearing_s                                      # square up to the wall and walk into it (bearing_s > 0: wall on the right)
    elif inner.mode in ("mount", "dismount") or inner.mode in FLIGHT_MODES:
        fwd = 0.0; turn = 0.0
    elif inner.mode in ("climb", "descend"):
        fwd = CLIMB_DRIVE; turn = 0.3 * brain_turn
    elif inner.mode == "turnaround":
        fwd = 0.5; turn = 0.8 * inner.turn_dir
    turn = float(np.clip(turn, -1.0, 1.0))
    left, right = fwd + 1.0 * turn - back, fwd - 1.0 * turn - back
    drive = np.clip([left, right], -1.0, 1.2)
    if abs(drive[0]) < 0.08 and abs(drive[1]) < 0.08:
        drive = np.array([0.0, 0.0])
    probo = float(np.clip(rates["MN9"].mean() / 35.0, 0, 1))          # the brain's proboscis motor neuron extends the proboscis
    inner.probo = getattr(inner, "probo", 0.0) + (probo - getattr(inner, "probo", 0.0)) * (dt_c / 0.15)
    inner.mount_done = False
    leg_wall_contacts(inner.mode in CLIMB_MODES)
    wing_motors(inner.mode in FLIGHT_MODES)
    for _ in range(CHUNK):
        if inner.mode == "groom":
            full, adh = groom_pose(inner.groom_kind, inner.groom_phase)
        elif inner.mode == "mount":
            legs, adh, inner.mount_done = mount_pose(inner, DT)
            full = BODY.with_legs(legs)
        elif inner.mode == "dismount":
            full = BODY.stand.copy(); adh = np.array([1, 0, 0, 1, 0, 0], dtype=bool)
        elif inner.mode in FLIGHT_MODES:
            dd = sim.mj_data; Rb = dd.xmat[th_body].reshape(3, 3); vw = dd.qvel[RD:RD + 3]
            q = flight.step(Rb, float(dd.xpos[th_body][2]), float(vw[2]), float((Rb.T @ vw)[0]), inner.z_t, inner.v_t, inner.yaw_cmd, active=inner.mode != "touchdown", held=inner.mode == "takeoff")
            full = flight.blend(BODY.stand.copy(), BODY.stand, WJ, q)
            adh = np.ones(6, dtype=bool) if inner.mode in ("takeoff", "touchdown") else np.zeros(6, dtype=bool)
        elif inner.mode in ("climb", "descend", "turnaround"):
            action = ctrl.step(drive, body_frame_obs())
            legs = action.joint_angles.copy(); adh = action.adhesion_onoff.copy()
            bias, w_ = climb_bias(inner)
            legs += bias
            if w_ > 0.5: adh[[0, 3]] = True                                    # keep the front feet glued until the gait has taken over
            full = BODY.with_legs(legs)
        elif (drive != 0).any():
            action = ctrl.step(drive, body_frame_obs())
            full, adh = BODY.with_legs(action.joint_angles), action.adhesion_onoff
            inner.last_legs = action.joint_angles.copy()
        else:
            full, adh = BODY.stand.copy(), np.ones(6, dtype=bool)
        full[ROS] -= np.radians(75) * inner.probo; full[HAU] += np.radians(60) * inner.probo; full[HEADP] += np.radians(12) * inner.probo
        sim.set_actuator_inputs("fly", ActuatorType.POSITION, full); sim.set_leg_adhesion_states("fly", adh)
        sim.step()
        sim.render_as_needed()

    # --- log at 30 fps
    if tick >= next_frame:
        next_frame += FRAME_EVERY
        fr = sim.renderer.frames
        for key, v in fr.items():
            if len(v):
                imageio.imwrite(f"{args.out}/frames/{key.split('/')[-1]}_{frame_i:05d}.png", np.asarray(v[-1]))
                v.clear()
        spk = np.concatenate(spikes_since_frame) if spikes_since_frame else np.zeros(0, np.int32)
        spike_frames.append(np.unique(spk).astype(np.int32)); spikes_since_frame = []
        log["t"].append(t); log["pose"].append([float(thorax[0]), float(thorax[1]), float(yaw), float(thorax[2])]); log["drive"].append(drive.tolist())
        for k in groups:
            log["rates"][k].append(rates[k].tolist())
        log["inputs"].append([float(odour), bool(mouth_on_food), bool(touching), float(lum.mean()), float(vis_feat[0]), float(vis_feat[1]), float(vis_feat[2]), float(vis_feat[3])])
        log["events"].append(dict(events)); log["frames"].append(frame_i); log.setdefault("inner", []).append([inner.mode if inner.mode != "groom" else "groom:" + inner.groom_kind, float(inner.hunger), float(brain_turn), float(odour_turn), float(inner.turn_bias), float(inner.probo), float(inner.reward), float(inner.memory)])
        np.save(f"{args.out}/frames/eyes_{frame_i:05d}.npy", rgb.astype(np.float16))
        frame_i += 1
    if tick % 50 == 0:
        print(f"  t={t:5.1f}s  wall={time.time()-t_wall:6.0f}s  pos=({thorax[0]:5.1f},{thorax[1]:5.1f},{thorax[2]:4.1f}) up={up_z:.2f} yaw={np.degrees(yaw):5.0f}  drive={drive.round(2)} mode={inner.mode} hunger={inner.hunger:.2f} reward={inner.reward:.2f} memory={inner.memory:.2f}  "
              f"DNpop {rates['DNpop'].round(1)} DNa02 {rates['DNa02'].round(0)} DNp09 {rates['DNp09'].round(0)} MDN {rates['MDN'].round(0)} MN9 {rates['MN9'].mean():.0f}  odour={odour:.2f} obj={vis_feat[0]:.2f}/{vis_feat[1]:.2f} loom={vis_feat[2]:.2f}/{vis_feat[3]:.2f} touch={touching} head=({head[0]:.1f},{head[1]:.1f},{head[2]:.1f}) obst={obst_d:.1f}  spikes/10ms={len(si)}", flush=True)

np.savez_compressed(f"{args.out}/spikes.npz", **{f"f{i}": s for i, s in enumerate(spike_frames)})
json.dump(log, open(f"{args.out}/log.json", "w"))
np.save(f"{args.out}/soma_xy.npy", pos[:, [0, 1]]); np.save(f"{args.out}/super_class.npy", sc.astype(str))
json.dump({"reward dopamine": [reward_pam.tolist(), [255, 80, 200]], "giant fibre": [groups["DNp01"][0].tolist() + groups["DNp01"][1].tolist(), [255, 90, 60]], "MN9": [mn9.tolist(), [255, 255, 255]]}, open(f"{args.out}/highlight.json", "w"))
print(f"[done] {frame_i} frames in {time.time()-t_wall:.0f}s; events {events}")
