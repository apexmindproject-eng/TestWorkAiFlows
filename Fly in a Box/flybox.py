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
from flygym.anatomy import BodySegment
from flygym.compose import FlatGroundWorld
from flygym.utils.math import Rotation3D
from flygym.vision.retina import Retina
from flygym_demo.complex_terrain import (HybridTurningController, HybridControllerObservation, LocomotionAction,
                                         PreprogrammedSteps, apply_locomotion_action, make_locomotion_fly, make_tripod_cpg_network)
from brain import Brain

p = argparse.ArgumentParser()
p.add_argument("--seconds", type=float, default=20.0)
p.add_argument("--out", default="out/run1")
p.add_argument("--base", type=float, default=0.5, help="baseline walking drive of the nerve-cord pattern generator")
p.add_argument("--seed", type=int, default=1)
p.add_argument("--spawn", type=float, nargs=3, default=None, help="x y yaw_deg")
p.add_argument("--turn-gain", type=float, default=100.0, help="Hz of DNa02 left-right difference that gives a full-strength turn")
args = p.parse_args()
os.makedirs(args.out + "/frames", exist_ok=True)

DT = 1e-4
CHUNK = 100               # brain/body steps per control tick (10 ms)
VISION_EVERY = 2          # ticks between eye updates (20 ms)
FRAME_EVERY = 3.3333      # ticks between video frames (30 fps)

# ----------------------------------------------------------------------------- brain
b = Brain("Drosophila_brain_model/Completeness_783.csv", "Drosophila_brain_model/Connectivity_783.parquet", "data/flywire_annotations_783.tsv")
a = b.ann
pos = a[["pos_x", "pos_y", "pos_z"]].to_numpy() * np.array([4, 4, 40]) / 1000.0
side = a["side"].to_numpy()
sc = a["super_class"].to_numpy()

# Photoreceptors -> ommatidia (retinotopic map by position: PC2 of the lamina/medulla sheet
# runs anterior->posterior, y runs dorsal->ventral in FlyWire coordinates)
retina = Retina()
cent = np.load("out/omm_centroids.npy")           # (721, 2) row, col in the eye image
omm_norm = np.stack([cent[:, 0] / retina.nrows, cent[:, 1] / retina.ncols], 1)
photo_idx, photo_omm, photo_eye = [], [], []
for eye, sname in enumerate(["left", "right"]):
    for t in ["R1-6", "R7", "R8"]:
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
        photo_idx.append(idx); photo_omm.append(d.argmin(1)); photo_eye.append(np.full(len(idx), eye))
photo_idx = np.concatenate(photo_idx); photo_omm = np.concatenate(photo_omm); photo_eye = np.concatenate(photo_eye)
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
groups = {k: (b.find(k, "left"), b.find(k, "right")) for k in ["DNa02", "DNa01", "DNp09", "MDN", "DNp01", "DNa03", "DNb01", "aDN1", "aDN2"]}
groups["MN9"] = (mn9, mn9)
dn_all = np.flatnonzero(sc == "descending")
dn_L = dn_all[side[dn_all] == "left"]; dn_R = dn_all[side[dn_all] == "right"]
groups["DNpop"] = (dn_L, dn_R)
print(f"[readout] descending population: {len(dn_L)} left, {len(dn_R)} right")
print("[groups]", {k: (len(v[0]), len(v[1])) for k, v in groups.items()}, "food ORN", len(food_orn), "sugar", len(sugar), "head bristle", len(head_bristle))

# ----------------------------------------------------------------------------- body + box
fly = make_locomotion_fly(name="fly", add_adhesion=True, colorize=True)
fly.add_vision()
follow = fly.add_tracking_camera(name="follow", pos_offset=(-3, -12, 12), rotation=Rotation3D("xyaxes", (1, 0, 0, 0, 0.72, 0.69)), fovy=42.0)
world = FlatGroundWorld()
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
fly_geoms = [pr.geomname1 for pr in spec.pairs if pr.geomname2 == "ground_plane" and not any(leg in pr.geomname1 for leg in ("lf_", "lm_", "lh_", "rf_", "rm_", "rh_"))]
for obstacle in ["wall_n", "wall_s", "wall_e", "wall_w", "post"]:
    for g in fly_geoms:
        pr = spec.add_pair(); pr.geomname1 = g; pr.geomname2 = obstacle
        pr.solref = [0.002, 1.0]; pr.solimp = [0.95, 0.99, 0.001, 0.5, 2.0]; pr.margin = 0.2   # stiff wall
print(f"[box] {len(fly_geoms)} body parts collide with the walls and post:", fly_geoms)
sim = Simulation(world)
sim.set_renderer([follow, "overhead"], camera_res=(480, 640), playback_speed=1.0, output_fps=30, buffer_frames=True)

steps = PreprogrammedSteps()
dof_order = fly.get_actuated_jointdofs_order("position")
net = make_tripod_cpg_network(timestep=sim.timestep, intrinsic_amplitude=1.0, coupling_strength=10.0, convergence_coef=20.0, seed=args.seed)
ctrl = HybridTurningController(timestep=sim.timestep, cpg_network=net, preprogrammed_steps=steps, output_dof_order=dof_order)
sim.reset(); ctrl.reset(seed=args.seed)
apply_locomotion_action(sim, "fly", LocomotionAction(joint_angles=steps.default_pose_by_dof_order(dof_order), adhesion_onoff=np.ones(6, dtype=bool)))
sim.warmup()
segs = fly.get_bodysegs_order()
I_HEAD, I_THORAX = segs.index(BodySegment("c_head")), segs.index(BodySegment("c_thorax"))

# ----------------------------------------------------------------------------- loop
n_ticks = int(args.seconds / (CHUNK * DT))
rates = {k: np.zeros(2) for k in groups}          # smoothed Hz, [left, right]
TAU_RATE = 0.08
lum_adapt = None
odour_adapt = np.zeros(2); touch_adapt = 0.0
log = {"t": [], "pose": [], "drive": [], "rates": {k: [] for k in groups}, "events": [], "inputs": [], "frames": []}
spike_frames = []                                 # per video frame: neuron ids that spiked
spikes_since_frame = []
events = {"feeding": 0, "startle": 0}
next_frame = 0.0; frame_i = 0
t_wall = time.time()
print(f"[run] {args.seconds} s = {n_ticks} ticks")
for tick in range(n_ticks):
    t = tick * CHUNK * DT
    bp = sim.get_body_positions("fly")
    head, thorax = bp[I_HEAD], bp[I_THORAX]
    heading = HybridControllerObservation.from_sim(sim, "fly").fly_heading
    yaw = np.arctan2(heading[1], heading[0])
    head = thorax + 1.4 * np.array([heading[0], heading[1], 0.0])      # the face, in front of the thorax

    # --- senses -> sensory neurons
    if tick % VISION_EVERY == 0:
        ro = sim.get_ommatidia_readouts("fly")              # (2, 721, 2)
        lum = ro.max(axis=2)                                 # (2, 721) in [0, 1]
        if lum_adapt is None:
            lum_adapt = lum.copy()
        change = np.abs(lum - lum_adapt)
        lum_adapt += (lum - lum_adapt) * (VISION_EVERY * CHUNK * DT / 0.2)
        rate = np.clip(40.0 * lum + 160.0 * change, 0, 200)  # Hz: sustained + transient
        b.rates[photo_idx] = rate[photo_eye, photo_omm]
        # optic-lobe feature extraction (the spiking model cannot do this part itself)
        darkness = (lum < 0.08).sum(axis=1).astype(float)                          # ommatidia seeing a black object (floor squares ~0.25, legs ~0.3)
        dt_v = VISION_EVERY * CHUNK * DT
        dark_mass += (darkness - dark_mass) * (dt_v / 0.08)                          # 80 ms smoothing (photoreceptor + lamina dynamics)
        dark_slow += (dark_mass - dark_slow) * (dt_v / 0.4)                           # what the object looked like ~0.4 s ago
        for e in range(2):
            obj = float(np.clip(dark_mass[e] / 6.0, 0, 1))                            # a fly-sized dark object covers ~6 ommatidia
            expansion = (dark_mass[e] - dark_slow[e]) / (0.4 * (dark_slow[e] + 1.0))  # relative growth rate, 1/s
            lm = float(np.clip((expansion - 1.0) / 2.0, 0, 1)) if dark_slow[e] > 2.0 else 0.0   # looming: a seen object more than doubling per second
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
    tasting = d_food < 3.0
    b.rates[sugar] = 100.0 if tasting else 0.0
    # nearest obstacle and which side of the head it is on
    walls = [(W - T - head[0], np.array([-1.0, 0.0])), (W - T + head[0], np.array([1.0, 0.0])), (W - T - head[1], np.array([0.0, -1.0])), (W - T + head[1], np.array([0.0, 1.0]))]
    to_post = POST - head[:2]; walls.append((np.linalg.norm(to_post) - 0.8, to_post / (np.linalg.norm(to_post) + 1e-9)))
    obst_d, obst_dir = min(walls, key=lambda w: w[0])
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
    fwd = args.base + 0.5 * min(rates["DNp09"].mean() / 50.0, 1.5)
    popL, popR = rates["DNpop"]
    turn = (popR - popL) / (popR + popL + 2.0)        # fraction of left-right imbalance across all descending neurons
    back = min(rates["MDN"].mean() / 40.0, 1.5)
    left, right = fwd + 1.0 * turn - back, fwd - 1.0 * turn - back
    if rates["MN9"].mean() > 30:           # proboscis motor neuron firing hard (sugar gives ~40 Hz, vision spill-over ~15): feeding, stand still
        left = right = 0.0; events["feeding"] += 1
    if rates["DNp01"].mean() > 20:         # giant fibre: startle, back off
        left = right = -1.0; events["startle"] += 1
    drive = np.clip([left, right], -1.0, 1.2)
    if abs(drive[0]) < 0.08 and abs(drive[1]) < 0.08:
        drive = np.array([0.0, 0.0])
    for _ in range(CHUNK):
        if (drive != 0).any():
            action = ctrl.step(drive, HybridControllerObservation.from_sim(sim, "fly"))
        else:
            action = LocomotionAction(joint_angles=steps.default_pose_by_dof_order(dof_order), adhesion_onoff=np.ones(6, dtype=bool))
        apply_locomotion_action(sim, "fly", action)
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
        log["t"].append(t); log["pose"].append([float(thorax[0]), float(thorax[1]), float(yaw)]); log["drive"].append(drive.tolist())
        for k in groups:
            log["rates"][k].append(rates[k].tolist())
        log["inputs"].append([float(odour), bool(tasting), bool(touching), float(lum.mean()), float(vis_feat[0]), float(vis_feat[1]), float(vis_feat[2]), float(vis_feat[3])])
        log["events"].append(dict(events)); log["frames"].append(frame_i)
        np.save(f"{args.out}/frames/eyes_{frame_i:05d}.npy", lum.astype(np.float16))
        frame_i += 1
    if tick % 50 == 0:
        print(f"  t={t:5.1f}s  wall={time.time()-t_wall:6.0f}s  pos=({thorax[0]:5.1f},{thorax[1]:5.1f}) yaw={np.degrees(yaw):5.0f}  drive={drive.round(2)}  "
              f"DNpop {rates['DNpop'].round(1)} DNa02 {rates['DNa02'].round(0)} DNp09 {rates['DNp09'].round(0)} MDN {rates['MDN'].round(0)} MN9 {rates['MN9'].mean():.0f}  odour={odour:.2f} obj={vis_feat[0]:.2f}/{vis_feat[1]:.2f} loom={vis_feat[2]:.2f}/{vis_feat[3]:.2f} touch={touching} head=({head[0]:.1f},{head[1]:.1f},{head[2]:.1f}) obst={obst_d:.1f}  spikes/10ms={len(si)}", flush=True)

np.savez_compressed(f"{args.out}/spikes.npz", **{f"f{i}": s for i, s in enumerate(spike_frames)})
json.dump(log, open(f"{args.out}/log.json", "w"))
np.save(f"{args.out}/soma_xy.npy", pos[:, [0, 1]]); np.save(f"{args.out}/super_class.npy", sc.astype(str))
print(f"[done] {frame_i} frames in {time.time()-t_wall:.0f}s; events {events}")
