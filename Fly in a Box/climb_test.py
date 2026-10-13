"""Body-only test: can the walking gait carry the fly up a wall if the reflexes work in the body frame?"""
import numpy as np, mujoco as mj, imageio, sys
from flygym import Simulation
from flygym.anatomy import BodySegment, LEGS
from flygym.compose import FlatGroundWorld
from flygym.utils.math import Rotation3D
from flygym_demo.complex_terrain import (HybridTurningController, HybridControllerObservation, LocomotionAction, PreprogrammedSteps, apply_locomotion_action, make_locomotion_fly, make_tripod_cpg_network)

adh = float(sys.argv[1]) if len(sys.argv) > 1 else 40.0
fly = make_locomotion_fly(name="fly", add_adhesion=True, adhesion_gain=adh, colorize=True)
cam = fly.add_tracking_camera(name="side", pos_offset=(-2, -14, 6), rotation=Rotation3D("xyaxes", (1, 0, 0, 0, 0.3, 0.95)), fovy=45.0)
world = FlatGroundWorld(); world.add_fly(fly, [0, 0, 0.5], Rotation3D("quat", [1, 0, 0, 0]))
spec = world.mjcf_root; wb = spec.worldbody
wb.add_geom(name="wall", type=mj.mjtGeom.mjGEOM_BOX, size=[0.5, 20, 15], pos=[7, 0, 15], rgba=[0.86, 0.84, 0.80, 1])
for pr in [p for p in spec.pairs if p.geomname2 == "ground_plane"]:
    q = spec.add_pair(); q.geomname1 = pr.geomname1; q.geomname2 = "wall"
    q.solref = [0.002, 1.0]; q.solimp = [0.95, 0.99, 0.001, 0.5, 2.0]; q.margin = 0.2
    q.friction = [1.0, 1.0, 0.005, 0.0001, 0.0001]
sim = Simulation(world); sim.set_renderer([cam], camera_res=(480, 640), playback_speed=1.0, output_fps=30)
steps = PreprogrammedSteps(); dofs = fly.get_actuated_jointdofs_order("position")
net = make_tripod_cpg_network(timestep=sim.timestep, intrinsic_amplitude=1.0, coupling_strength=10.0, convergence_coef=20.0, seed=0)
ctrl = HybridTurningController(timestep=sim.timestep, cpg_network=net, preprogrammed_steps=steps, output_dof_order=dofs)
sim.reset(); ctrl.reset(seed=0)
apply_locomotion_action(sim, "fly", LocomotionAction(joint_angles=steps.default_pose_by_dof_order(dofs), adhesion_onoff=np.ones(6, dtype=bool))); sim.warmup()
segs = fly.get_bodysegs_order(); i_th = segs.index(BodySegment("c_thorax")); i_t5 = [segs.index(BodySegment(f"{l}_tarsus5")) for l in LEGS]
th_body = sim._internal_bodyids_by_fly["fly"][i_th]

def body_frame_obs():
    """Same as HybridControllerObservation.from_sim but 'height' is measured along the fly's own up axis."""
    obs = HybridControllerObservation.from_sim(sim, "fly")
    R = sim.mj_data.xmat[th_body].reshape(3, 3); up = R[:, 2]
    pos = sim.get_body_positions("fly")
    obs.thorax_z = float(pos[i_th] @ up); obs.tarsus5_z = np.array([pos[i] @ up for i in i_t5])
    return obs

frames = sim.renderer.frames
for k in range(30000):
    apply_locomotion_action(sim, "fly", ctrl.step(np.array([1.0, 1.0]), body_frame_obs())); sim.step(); sim.render_as_needed()
    if k % 5000 == 0:
        p = sim.get_body_positions("fly")[i_th]; R = sim.mj_data.xmat[th_body].reshape(3, 3)
        print(f"t={k*1e-4:4.1f}s thorax=({p[0]:5.1f},{p[1]:5.1f},{p[2]:5.1f}) pitch={np.degrees(np.arcsin(-R[2,0])):6.1f} up·z={R[2,2]:5.2f}", flush=True)
for key, v in frames.items():
    for i in [30, 60, 89]:
        if i < len(v): imageio.imwrite(f"out/climb_{int(adh)}_{i}.png", np.asarray(v[i]))
print("saved frames", len(list(frames.values())[0]))
