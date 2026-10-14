"""Flight for the full-body fly: wing aerodynamics (MuJoCo ellipsoid fluid model), a measured wing stroke found by
inverse kinematics on the model's own wing hinges, and a haltere-level stabiliser (nerve-cord glue, see README).

Numbers below were measured on this model (wing_force.py / flight_test*.py):
  - fluid ellipsoid at 1.6 x the wing mesh centre (0.6 of the wing length, where flapping lift centres)
  - Kutta lift coefficient 2.0 (leading-edge-vortex regime, Dickinson 1999), air density 1.28e-6 g/mm^3
  - stroke +-70 deg at 200 Hz, angle of attack 55 deg: 11.7 uN lift vs 10.05 uN weight
  - pitch: wing-pitch offset -> nose-up acceleration 32000 rad/s^2 per rad; roll: amplitude asymmetry
  - yaw: opposite wing-yaw offsets, +0.08 rad turns right at several hundred deg/s
"""
import itertools, os
import numpy as np, mujoco as mj
AIR = dict(density=1.28e-6, viscosity=1.85e-5)
N_PHASE, F_BEAT, AMP, AOA = 40, 200.0, np.radians(70), np.radians(55)
WING_POS = {"l": (-0.107, 0.959, 0.115), "r": (-0.107, -0.959, 0.115)}
WING_QUAT = {"l": (0.586, 0.54, -0.434, 0.421), "r": (0.586, -0.54, -0.434, -0.421)}

def add_flight(fly, kp_wing=350.0, kutta=2.0, centre=1.6):
    """Give the fly's wings air to push on, and motors that can beat at 200 Hz."""
    for side in "lr":
        g = fly.mjcf_root.body(f"{side}_wing").add_geom(name=f"{side}_wing_fluid", type=mj.mjtGeom.mjGEOM_ELLIPSOID, size=[0.01, 0.55, 1.2],
                                                       pos=list(np.array(WING_POS[side]) * centre), quat=list(WING_QUAT[side]), contype=0, conaffinity=0, mass=0.0, rgba=[0, 0, 0, 0])
        g.fluid_ellipsoid = True; g.fluid_coefs[3] = kutta
    for a in fly.mjcf_root.actuators:
        if "wing" in a.name: a.gainprm[0] = kp_wing; a.biasprm[1] = -kp_wing; a.forcerange[:] = [-500, 500]

def solve_base_stroke(sim, fly, cache="wing_stroke.npz", verbose=True):
    """Joint-space wing trajectories (N_PHASE x 3 per wing) for a horizontal stroke with a flipping angle of attack,
    solved by inverse kinematics on the compiled model (instant forward kinematics, no dynamics)."""
    if os.path.exists(cache):
        z = np.load(cache); return {"l": z["l"], "r": z["r"]}
    m, d = sim.mj_model, sim.mj_data
    from flygym.anatomy import BodySegment
    segs = fly.get_bodysegs_order(); th_body = sim._internal_bodyids_by_fly["fly"][segs.index(BodySegment("c_thorax"))]
    J = {s: {ax: mj.mj_name2id(m, mj.mjtObj.mjOBJ_JOINT, f"fly/c_thorax-{s}_wing-{ax}") for ax in ("yaw", "pitch", "roll")} for s in "lr"}
    gid = {s: mj.mj_name2id(m, mj.mjtObj.mjOBJ_GEOM, f"fly/{s}_wing") for s in "lr"}
    LOCAL = {}
    for s in "lr":
        mid = m.geom_dataid[gid[s]]; V = m.mesh_vert[m.mesh_vertadr[mid]:m.mesh_vertadr[mid] + m.mesh_vertnum[mid]]
        tip = V[np.linalg.norm(V, axis=1).argmax()]; span = tip / np.linalg.norm(tip)
        c = V.mean(0); _, _, Vt = np.linalg.svd(V - c, full_matrices=False); chord = Vt[1] - (Vt[1] @ span) * span; chord /= np.linalg.norm(chord)
        LOCAL[s] = (span, chord)
    q0 = d.qpos.copy()
    def fk(s, yaw, pitch, roll):
        d.qpos[:] = q0
        for ax, v in zip(("yaw", "pitch", "roll"), (yaw, pitch, roll)): d.qpos[m.jnt_qposadr[J[s][ax]]] = v
        mj.mj_kinematics(m, d); Rt = d.xmat[th_body].reshape(3, 3); Rg = d.geom_xmat[gid[s]].reshape(3, 3)
        return Rt.T @ (Rg @ LOCAL[s][0]), Rt.T @ (Rg @ LOCAL[s][1])
    _, cl = fk("l", 0, 0, 0); _, cr = fk("r", 0, 0, 0)
    if np.sign(cl[1]) == np.sign(cr[1]): LOCAL["r"] = (LOCAL["r"][0], -LOCAL["r"][1])       # mirror-consistent chord sign
    grid = np.linspace(-np.pi, np.pi, 37); G = np.array(list(itertools.product(grid, grid, grid)))
    def refine(s, start, span_d, chord_d, step=0.35, iters=40):
        best = np.array(start, float); sp, ch = fk(s, *best); bc = (1 - sp @ span_d) + 0.6 * (1 - ch @ chord_d)
        for _ in range(iters):
            improved = False
            for dq in itertools.product((-1, 0, 1), repeat=3):
                if dq == (0, 0, 0): continue
                cand = best + step * np.array(dq); sp, ch = fk(s, *cand); c = (1 - sp @ span_d) + 0.6 * (1 - ch @ chord_d)
                if c < bc - 1e-7: best, bc, improved = cand, c, True
            if not improved: step *= 0.5
        return best
    wrap = lambda x: (x + np.pi) % (2 * np.pi) - np.pi
    out = {}
    for s, side in (("l", 1), ("r", -1)):
        if verbose: print(f"[wings] solving the {s} wing stroke ...", flush=True)
        SP = np.zeros((len(G), 3)); CH = np.zeros((len(G), 3))
        for i, (y, p, r) in enumerate(G): SP[i], CH[i] = fk(s, y, p, r)
        tr = []
        for k in range(N_PHASE):
            w = 2 * np.pi * k / N_PHASE; phi = AMP * np.sin(w); g = np.tanh(np.cos(w) / 0.35)
            span_d = np.array([np.sin(phi), side * np.cos(phi), 0.0]); tangent = np.array([np.cos(phi), -side * np.sin(phi), 0.0])
            chord_d = np.cos(AOA) * g * tangent + np.sin(AOA) * np.array([0, 0, 1.0]) * (0.3 + 0.7 * abs(g)) + np.array([0, 0, 1.0]) * (1 - abs(g)); chord_d /= np.linalg.norm(chord_d)
            start = G[int(np.argmin((1 - SP @ span_d) + 0.6 * (1 - CH @ chord_d)))] if k == 0 else tr[-1]
            best = refine(s, start, span_d, chord_d)
            if k > 0: best = tr[-1] + wrap(best - tr[-1])
            tr.append(best)
        out[s] = np.array(tr)
    d.qpos[:] = q0; mj.mj_forward(m, d)
    np.savez(cache, l=out["l"], r=out["r"]); return out

class Flight:
    """Wing commands for stable flight: amplitude for lift, wing-pitch offset for body pitch, left/right amplitude
    asymmetry for roll, opposite wing-yaw offsets for yaw. Attitude signals are averaged over ~2 ms (haltere-like)."""
    G_P, G_R = 32000.0, 94000.0
    PK, PD, RK, RD = (float(os.environ.get(k, v)) for k, v in (("FLY_PK", 4000.0), ("FLY_PD", 400.0), ("FLY_RK", 40000.0), ("FLY_RD", 600.0)))
    def __init__(self, base, dt):
        self.base = base; self.mean = {s: base[s].mean(0) for s in "lr"}; self.dt = dt; self.reset(0.0)
    def reset(self, z, R=None):
        self.t = 0.0; self.thf = 0.0; self.phf = 0.0
        if R is not None:
            up = R.T @ np.array([0.0, 0.0, 1.0]); self.thf = float(np.arctan2(up[0], up[2])); self.phf = float(np.arctan2(up[1], up[2]))
        self.thf = self.thf; self.dth = 0.0; self.dph = 0.0; self.th_prev = None; self.ph_prev = None
        self.ip = 0.0; self.zf = z; self.vzf = 0.0; self.sc = 0.9; self.ramp = 0.0; self.off_p = 0.0; self.eps = 0.0; self.off_y = 0.0; self.theta_t = 0.0; self.wbuf = []
    W_P, W_R = (float(os.environ.get(k, v)) for k, v in (("FLY_WP", 25.0), ("FLY_WR", 40.0)))      # rate limits (rad/s)
    K2P, K2R = (float(os.environ.get(k, v)) for k, v in (("FLY_K2P", 150.0), ("FLY_K2R", 250.0)))   # rate-loop gains (1/s)
    def step(self, R, z, vz, v_fwd, z_t, v_t, yaw_cmd, active=True, held=False, pitch_t=None, roll_t=0.0, lift=1.0, omega=None, roll_ctrl=True, fast_off=False, flip=None):
        """R: thorax rotation (world<-body), z/vz: height and vertical speed, v_fwd: body-forward speed.
        Returns {side: (yaw, pitch, roll)} wing joint targets. held: body still on its legs (no attitude integral).
        pitch_t / roll_t: attitude targets (rad, nose-up / left-side-up); pitch_t None = set by the speed loop."""
        dt = self.dt; self.t += dt; filt = 0.05
        up = R.T @ np.array([0.0, 0.0, 1.0])                                                  # world up in the body frame
        theta = float(np.arctan2(up[0], up[2])); phi = float(np.arctan2(up[1], up[2]))       # nose-up, left-up; full range (an inverted fly reads 180 deg)
        wrap = lambda x: (x + np.pi) % (2 * np.pi) - np.pi
        theta = self.thf + wrap(theta - self.thf); phi = self.phf + wrap(phi - self.phf)       # continuous angles (no jump at +-180)
        self.thf += (theta - self.thf) * filt; self.phf += (phi - self.phf) * filt
        if self.th_prev is not None:
            self.dth += ((self.thf - self.th_prev) / dt - self.dth) * filt; self.dph += ((self.phf - self.ph_prev) / dt - self.dph) * filt
        self.th_prev, self.ph_prev = self.thf, self.phf
        self.theta_t = float(np.clip(-0.012 * (v_t - v_fwd), -0.3, 0.3)) if pitch_t is None else float(pitch_t)   # nose down to speed up, nose up to slow
        err = wrap(self.thf - self.theta_t); perr = wrap(self.phf - roll_t)
        if abs(perr) > 2.6: perr = 2.6 * np.sign(perr if perr != 0 else 1.0)                 # upside down: pick a side and commit
        if not held: self.ip += err * dt
        if omega is not None:                                                                  # body rates from the halteres, averaged over one wingbeat
            self.wbuf.append(np.asarray(omega, float)); self.wbuf = self.wbuf[-50:]; w = np.mean(self.wbuf, axis=0)   # exactly one wingbeat: removes the 200 Hz body wobble
            rate_p, rate_r = -float(w[1]), float(w[0])                                         # omega = root free-joint angular velocity (thorax frame): nose-up = -w_y, left-up = +w_x (calibrated)
            self.rate_p, self.rate_r = rate_p, rate_r
        else:
            rate_p, rate_r = self.dth, self.dph
        # cascaded: a bounded rotation rate toward the target, then a rate loop
        des_p = float(np.clip(-self.PK / self.PD * err, -self.W_P, self.W_P)); des_r = float(np.clip(-self.RK / self.RD * perr, -self.W_R, self.W_R))

        # plain proportional-derivative loops on wingbeat-averaged angles (the cascaded rate loop was less stable in hover)
        RF = float(os.environ.get("FLY_RF", 1.0))
        self.off_p = float(np.clip(-(4000 * err + 400 * self.dth) / self.G_P - 0.5 * self.ip, -0.35, 0.3))
        if abs(err) > 1.0: self.off_p = -0.35 if err > 0 else 0.3                               # far off: full torque toward level (no braking yet)
        if abs(perr) > 1.0: self.off_p = float(np.clip(-0.5 * self.ip, -0.35, 0.3))             # roll first
        self.eps = float(np.clip(-RF * (4000 * perr + 400 * self.dph) / self.G_R, -0.25, 0.25))
        if abs(perr) > 1.0: self.eps = -0.25 if perr > 0 else 0.25                               # far off: full roll torque
        if not roll_ctrl: self.eps = 0.0
        self.off_y = float(np.clip(yaw_cmd, -0.06, 0.06))
        self.zf += (z - self.zf) * 0.02; self.vzf += (vz - self.vzf) * 0.02
        tilt = float(np.clip(up[2], -1, 1))                                                   # cos of the attitude error
        hover = lift * (0.92 + 0.10 * (z_t - self.zf) - 0.012 * self.vzf)
        if tilt < 0.0: sc_t, slew = 1.0, 0.01                                                 # upside down: beat hard anyway, the roll torque needs the stroke
        else: sc_t, slew = float(np.clip(hover + 0.3 * (1.0 - tilt) / 1.0, 0.75, 1.2)), 0.01     # tilted: more lift, smoothly
        if flip:
            # the landing flip (Liu, Chen & Chang 2019): full torque over the first 90 degrees, full brake over the second,
            # so the body arrives inverted with little spin; flip_done once it is past 90 and no longer turning that way
            w = np.asarray(omega, float) if omega is not None else np.zeros(3); rate_p, rate_r = -float(w[1]), float(w[0])
            self.ip = 0.0; self.off_y = 0.0; first_half = up[2] > 0.0
            if flip == "pitch": self.eps = 0.0; self.off_p = -0.35 if first_half else (0.3 if rate_p < 0 else 0.0); self.flip_done = (not first_half) and rate_p >= 0   # nose-down somersault (nose-up torque is weaker)
            else: self.off_p = 0.0; self.eps = -0.25 if first_half else (0.25 if rate_r < 0 else 0.0); self.flip_done = (not first_half) and rate_r >= 0
            sc_t = 1.0
        else: self.flip_done = False
        self.sc += float(np.clip(sc_t - self.sc, -slew, slew))
        self.ramp = float(np.clip(self.ramp + (dt / 0.02 if active else -dt / (0.01 if fast_off else 0.05)), 0.0, 1.0))   # fast_off: the stroke stops within 10 ms (landing)
        ph = (self.t * F_BEAT * N_PHASE) % N_PHASE; i0 = int(ph); i1 = (i0 + 1) % N_PHASE; u = ph - i0
        out = {}
        for s, sgn in (("l", 1), ("r", -1)):
            q = self.base[s][i0] * (1 - u) + self.base[s][i1] * u; qm = self.mean[s]
            q = qm + self.sc * (1 + sgn * self.eps) * (q - qm) + np.array([sgn * self.off_y, self.off_p, 0.0])
            out[s] = q
        return out
    def blend(self, targets, rest, idx, q):
        """Write wing targets q into the full joint-target vector, blended by the ramp with the resting wing pose."""
        for s in "lr":
            for j, ax in enumerate(("yaw", "pitch", "roll")):
                targets[idx[s][ax]] = rest[idx[s][ax]] * (1 - self.ramp) + q[s][j] * self.ramp
        return targets
