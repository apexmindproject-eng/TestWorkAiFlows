"""Body-only test: placed directly on a vertical wall, facing up, can the fly hold on and walk upward?"""
import numpy as np, mujoco as mj, imageio, sys
from flygym import Simulation
from flygym.anatomy import BodySegment, LEGS
from flygym.compose import FlatGroundWorld
from flygym.utils.math import Rotation3D
from flygym_demo.complex_terrain import (CPGController, HybridTurningController, HybridControllerObservation, LocomotionAction, PreprogrammedSteps, apply_locomotion_action, make_locomotion_fly, make_tripod_cpg_network)
from scipy.spatial.transform import Rotation as Rot
adh = float(sys.argv[1]) if len(sys.argv) > 1 else 40.0
fly = make_locomotion_fly(name="fly", add_adhesion=True, adhesion_gain=adh, colorize=True)
cam = fly.add_tracking_camera(name="side", pos_offset=(-2, -14, 6), rotation=Rotation3D("xyaxes", (1, 0, 0, 0, 0.3, 0.95)), fovy=45.0)
world = FlatGroundWorld()
# fly body x axis -> world +z (up the wall), body z (up) -> world -x (away from the wall at x = +0.0)
q = Rot.from_matrix(np.array([[0, 0, -1], [0, 1, 0], [1, 0, 0]])).as_quat()   # columns: body x->(0,0,1) up the wall, y->(0,1,0), z (body up)->(-1,0,0) away from the wall
world.add_fly(fly, [float(sys.argv[2]) if len(sys.argv) > 2 else -0.2, 0, 6.0], Rotation3D("quat", [q[3], q[0], q[1], q[2]]))
spec = world.mjcf_root; wb = spec.worldbody
wb.add_geom(name="wall", type=mj.mjtGeom.mjGEOM_BOX, size=[0.5, 20, 20], pos=[0.5, 0, 20], rgba=[0.86, 0.84, 0.80, 1])
for pr in [p for p in spec.pairs if p.geomname2 == "ground_plane"]:
    q2 = spec.add_pair(); q2.geomname1 = pr.geomname1; q2.geomname2 = "wall"
    q2.solref = [0.002, 1.0]; q2.solimp = [0.95, 0.99, 0.001, 0.5, 2.0]; q2.margin = 0.2; q2.friction = [1.0, 1.0, 0.005, 0.0001, 0.0001]
sim = Simulation(world)
gscale = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
sim.mj_model.opt.gravity[:] = sim.mj_model.opt.gravity * gscale
print("gravity", sim.mj_model.opt.gravity)
sim.set_renderer([cam], camera_res=(480, 640), playback_speed=1.0, output_fps=30)
steps = PreprogrammedSteps(); dofs = fly.get_actuated_jointdofs_order("position")
net = make_tripod_cpg_network(timestep=sim.timestep, intrinsic_amplitude=1.0, coupling_strength=10.0, convergence_coef=20.0, seed=0)
PLAIN = len(sys.argv) > 4 and sys.argv[4] == "plain"
ctrl = CPGController(cpg_network=net, preprogrammed_steps=steps, output_dof_order=dofs) if PLAIN else HybridTurningController(timestep=sim.timestep, cpg_network=net, preprogrammed_steps=steps, output_dof_order=dofs)
sim.reset()
if not PLAIN: ctrl.reset(seed=0)
apply_locomotion_action(sim, "fly", LocomotionAction(joint_angles=steps.default_pose_by_dof_order(dofs), adhesion_onoff=np.ones(6, dtype=bool)))
segs = fly.get_bodysegs_order(); i_th = segs.index(BodySegment("c_thorax")); i_t5 = [segs.index(BodySegment(f"{l}_tarsus5")) for l in LEGS]
th_body = sim._internal_bodyids_by_fly["fly"][i_th]
def body_frame_obs():
    obs = HybridControllerObservation.from_sim(sim, "fly")
    R = sim.mj_data.xmat[th_body].reshape(3, 3); up = R[:, 2]; pos = sim.get_body_positions("fly")
    obs.thorax_z = float(pos[i_th] @ up); obs.tarsus5_z = np.array([pos[i] @ up for i in i_t5]); return obs
p0 = sim.get_body_positions("fly"); print("before settle: thorax x=%.2f  tarsus x=%s" % (p0[i_th][0], np.round([p0[i][0] for i in i_t5], 2)))
for k in range(500): sim.step()   # settle onto the wall
p0 = sim.get_body_positions("fly"); print("after settle:  thorax x=%.2f z=%.2f  tarsus x=%s" % (p0[i_th][0], p0[i_th][2], np.round([p0[i][0] for i in i_t5], 2)))
for k in range(20000):
    amp = min(1.0, 0.05 + k * 1e-4 / 1.0)   # ramp the gait in over 1 s instead of lurching
    if PLAIN:
        net.intrinsic_amps[:] = amp; act = ctrl.step()
    else:
        act = ctrl.step(np.array([amp, amp]), body_frame_obs())
    apply_locomotion_action(sim, "fly", act); sim.step(); sim.render_as_needed()
    if k % 4000 == 0:
        p = sim.get_body_positions("fly")[i_th]; R = sim.mj_data.xmat[th_body].reshape(3, 3)
        print(f"adh={adh:.0f} g={gscale} t={k*1e-4:4.1f}s thorax=({p[0]:5.1f},{p[1]:5.1f},{p[2]:5.1f}) belly-to-wall={-R[0,2]:5.2f} heading-up={R[2,0]:5.2f}", flush=True)
v = list(sim.renderer.frames.values())[0]
for i in [10, 59]:
    if i < len(v): imageio.imwrite(f"out/onwall_{int(adh)}_{i}.png", np.asarray(v[i]))
