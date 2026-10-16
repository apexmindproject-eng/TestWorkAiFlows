"""Whole-brain leaky integrate-and-fire simulation of the FlyWire v783 adult fly connectome.

Same neuron model and parameters as Shiu et al. 2024 (Nature), re-implemented in numba so a
closed loop with a body simulation is practical. Every one of the ~139k neurons and ~15M
synapses is simulated. Nothing is trained.
"""
import os, time
import numpy as np
import pandas as pd
from numba import njit, prange

DT = 0.1e-3           # s
V0 = -52.0            # mV resting / reset
VTH = -45.0           # mV threshold
T_MBR = 20e-3         # s membrane time constant
TAU = 5e-3            # s synaptic time constant
T_RFC = 2.2e-3        # s refractory
T_DLY = 1.8e-3        # s synaptic delay
W_SYN = 0.275         # mV per synapse
F_POI = 250           # Poisson input weight factor (w_syn * f_poi added straight to v)
ADAPT_TAU = 0.3       # s, decay of spike-frequency adaptation (0 = off)

D_STEPS = int(round(T_DLY / DT))
R_STEPS = int(round(T_RFC / DT))
A_M = np.exp(-DT / T_MBR)
A_S = np.exp(-DT / TAU)
# exact solution of dv/dt = (v0 - v + g)/t_mbr with g decaying exponentially
G_COEF = (A_S - A_M) / (1.0 - T_MBR / TAU)
A_W = np.exp(-DT / ADAPT_TAU)


def step_constants(dt):
    """Per-step constants of the exact integration for timestep dt: [dt, A_M, A_S, A_W, G_COEF, refractory steps], delay steps."""
    a_m, a_s = np.exp(-dt / T_MBR), np.exp(-dt / TAU)
    prm = np.array([dt, a_m, a_s, np.exp(-dt / ADAPT_TAU), (a_s - a_m) / (1.0 - T_MBR / TAU), round(T_RFC / dt)], dtype=np.float64)
    return prm, int(round(T_DLY / dt))


class Brain:
    def __init__(self, comp_path, con_path, ann_path=None, verbose=True, dt=DT):
        """dt: integration timestep (default 0.1 ms, as published). The integration is exact for constant input over a
        step, so a larger step changes only spike-time resolution (and delays/refractory periods are rounded to it)."""
        t0 = time.time()
        self.dt = float(dt); self.prm, self.d_steps = step_constants(self.dt)
        comp = pd.read_csv(comp_path, index_col=0)
        self.root_ids = comp.index.to_numpy().astype(np.int64)
        self.N = len(self.root_ids)
        self.id2i = {rid: i for i, rid in enumerate(self.root_ids)}

        con = pd.read_parquet(con_path, columns=["Presynaptic_Index", "Postsynaptic_Index", "Excitatory x Connectivity"])
        pre = con["Presynaptic_Index"].to_numpy().astype(np.int64)
        post = con["Postsynaptic_Index"].to_numpy().astype(np.int64)
        w = (con["Excitatory x Connectivity"].to_numpy() * W_SYN).astype(np.float32)
        order = np.lexsort((post, pre))                    # by presynaptic neuron, then by target (lets threads deliver spikes to disjoint target ranges)
        pre, post, w = pre[order], post[order], w[order]
        self.indptr = np.zeros(self.N + 1, dtype=np.int64)
        np.add.at(self.indptr, pre + 1, 1)
        self.indptr = np.cumsum(self.indptr)
        self.indices = post.astype(np.int32)
        self.weights = w
        self.n_syn = len(w)

        self.ann = None
        if ann_path:
            ann = pd.read_csv(ann_path, sep="\t", low_memory=False,
                              usecols=["root_id", "cell_type", "hemibrain_type", "side", "super_class", "cell_class", "cell_sub_class", "top_nt",
                                       "soma_x", "soma_y", "soma_z", "pos_x", "pos_y", "pos_z"])
            ann = ann.set_index("root_id").reindex(self.root_ids)
            ann["type"] = ann.cell_type.fillna(ann.hemibrain_type).fillna("")
            ann["side"] = ann.side.fillna("center")
            self.ann = ann

        self.vth = np.full(self.N, VTH, dtype=np.float32)   # per-neuron spike threshold (mV)
        self.reset()
        if verbose:
            print(f"[brain] {self.N} neurons, {self.n_syn} connections, loaded in {time.time()-t0:.1f}s")

    # ----- neuron lookup -------------------------------------------------
    def find(self, cell_type, side=None):
        """Indices of neurons whose type matches (exact or prefix like 'LC10a') and side."""
        a = self.ann
        m = (a["type"] == cell_type) | a["type"].str.startswith(cell_type + "_")
        if side:
            m &= a["side"] == side
        return np.flatnonzero(m.to_numpy())

    # ----- state -----------------------------------------------------------
    def reset(self):
        self.v = np.full(self.N, V0, dtype=np.float32)
        self.g = np.zeros(self.N, dtype=np.float32)
        self.gbuf = np.zeros((self.N, self.d_steps), dtype=np.float32)   # synaptic input on its way: each neuron's D delay slots side by side
        self.refr = np.zeros(self.N, dtype=np.int32)
        self.rates = np.zeros(self.N, dtype=np.float32)   # Hz of Poisson drive per neuron
        self.wad = np.zeros(self.N, dtype=np.float32)     # adaptation variable (mV)
        self.adapt_b = 0.0                                 # mV added per spike; 0 = the published model
        self.step = 0
        self.pnext = np.full(self.N, NEVER, dtype=np.int64)  # steps until each neuron's next Poisson input

    def apply_biology_fixes(self, verbose=True):
        """Two corrections to the wiring-only model, both from established fly physiology:
        1. Sensory neurons spike from their own stimulus only (central feedback modulates their
           release, it does not make them fire).
        2. Antennal-lobe local interneurons are inhibitory (GABA / glutamate). The transmitter
           predictions label a third of them cholinergic or serotonergic, which turns the antennal
           lobe into a runaway excitatory loop that floods the whole brain on any smell."""
        sc = self.ann["super_class"].fillna("").to_numpy(); cls = self.ann["cell_class"].fillna("").to_numpy()
        self.clamp_inputs(np.flatnonzero(np.isin(sc, ["sensory", "sensory_ascending"])))
        alln = np.flatnonzero(cls == "ALLN")
        rows = np.repeat(np.arange(self.N), np.diff(self.indptr))
        out = np.isin(rows, alln); self.weights[out] = -np.abs(self.weights[out])
        if verbose:
            print(f"[brain] biology fixes: sensory neurons stimulus-only; {len(alln)} antennal-lobe local neurons set inhibitory")

    def clamp_inputs(self, idx):
        """Zero every synapse onto these neurons: they fire from their own stimulus only (sensory neurons)."""
        mask = np.zeros(self.N, dtype=bool); mask[idx] = True
        self.weights[mask[self.indices]] = 0.0

    def set_rates(self, idx, hz):
        self.rates[idx] = hz

    def clear_rates(self):
        self.rates[:] = 0

    def run(self, n_steps, seed=None, max_spikes=5_000_000, reference=False, rates=None):
        """Advance the brain. Returns (spike_step, spike_neuron) arrays for this chunk (not sorted by time).

        Same model as the published one, computed in blocks: a spike reaches its targets T_DLY (1.8 ms, 18 steps
        of 0.1 ms) later, so within that many steps every neuron evolves on its own. Each block integrates all neurons in
        parallel (one contiguous range per thread, every neuron's state kept in registers for the whole
        block); the block's spikes are then delivered into the delay buffer, to arrive 18 steps after they
        were fired, exactly as in the step-by-step version. Poisson inputs are drawn as event times
        (geometric waiting times; rates are constant within a call) instead of a coin flip per step.
        reference=True runs the original step-by-step kernel instead (for checking). rates: the Poisson input
        rates for this call (default: self.rates); pass a copy when the caller keeps writing self.rates while
        this runs in another thread."""
        rates = self.rates if rates is None else rates
        if seed is None:
            seed = self.step
        if reference:
            spk_t = np.empty(max_spikes, dtype=np.int32); spk_i = np.empty(max_spikes, dtype=np.int32)
            n = _run(n_steps, self.step, self.v, self.g, self.gbuf.T, self.refr, rates,
                     self.indptr, self.indices, self.weights, spk_t, spk_i, int(seed), self.wad, float(self.adapt_b), self.vth, self.prm)
            self.step += n_steps
            return spk_t[:n], spk_i[:n]
        nch = _chunks()
        nthr = _threads()
        if getattr(self, "_seg_for", None) != nthr:          # each neuron's synapses, split by target range: one range per thread
            bounds = np.linspace(0, self.N, nthr + 1).astype(np.int64)
            self._seg = _segments(self.indptr, self.indices, bounds); self._seg_for = nthr
        cap = max(4096, max_spikes // nch)
        if getattr(self, "_bufs_for", None) != (nch, cap, max_spikes):    # spike buffers, reused from call to call
            self._bufs = (np.empty((nch, cap), dtype=np.int32), np.empty((nch, cap), dtype=np.int32),
                          np.empty(max_spikes, dtype=np.int32), np.empty(max_spikes, dtype=np.int32))
            self._bufs_for = (nch, cap, max_spikes)
        spk_t, spk_i, out_t, out_i = self._bufs
        n = _run_blocks(n_steps, self.step, self.v, self.g, self.gbuf, self.refr, rates, self.pnext,
                        self._seg, self.indices, self.weights, spk_t, spk_i, out_t, out_i, int(seed),
                        self.wad, float(self.adapt_b), self.vth, self.prm)
        self.step += n_steps
        return out_t[:n].copy(), out_i[:n].copy()


NEVER = np.int64(1) << 62
W_POI = W_SYN * F_POI


def _threads():
    import numba
    return numba.get_num_threads()


def _chunks():
    """Work units per block: several per thread, handed out one at a time, so that fast and slow cores
    (a phone has both kinds) share the work evenly."""
    import numba
    try: numba.set_parallel_chunksize(1)
    except Exception: pass
    return 8 * numba.get_num_threads()


@njit(cache=True)
def _segments(indptr, indices, bounds):
    """seg[i, r] .. seg[i, r + 1]: the synapses of neuron i whose targets lie in range r (rows are sorted by target)."""
    N = indptr.shape[0] - 1; R = bounds.shape[0] - 1
    seg = np.empty((N, R + 1), dtype=np.int64)
    for i in range(N):
        k = indptr[i]; e = indptr[i + 1]
        seg[i, 0] = k
        for r in range(1, R):
            while k < e and indices[k] < bounds[r]:
                k += 1
            seg[i, r] = k
        seg[i, R] = e
    return seg


@njit(cache=True, fastmath=True, parallel=True, nogil=True)
def _run_blocks(n_steps, step0, v, g, gbuf, refr, rates, pnext, seg, indices, weights, spk_t, spk_i, out_t, out_i, seed, wad, adapt_b, vth, prm):
    DT, A_M, A_S, A_W, G_COEF = prm[0], prm[1], prm[2], prm[3], prm[4]
    R_STEPS = int(prm[5])
    N = v.shape[0]
    D = gbuf.shape[1]
    nch = spk_t.shape[0]; cap = spk_t.shape[1]
    CH = (N + nch - 1) // nch
    cnt = np.zeros(nch, dtype=np.int64)
    # Poisson inputs: the rates hold for this whole call, so draw each driven neuron's next input time afresh
    # (memoryless, so this is exact); sensory neurons driven by a stimulus have no refractory period
    for c in prange(nch):
        np.random.seed(seed * 7919 + c)
        for i in range(c * CH, min(N, (c + 1) * CH)):
            p = rates[i] * DT
            if p > 0.0:
                pnext[i] = int(np.log(1.0 - np.random.random()) / np.log1p(-min(p, 0.999)))
            else:
                pnext[i] = NEVER
    nout = 0
    s0 = 0
    while s0 < n_steps:
        nb = min(D, n_steps - s0)            # a block never reaches the slot its own spikes are written to
        t0 = step0 + s0
        slot0 = t0 % D
        for c in prange(nch):
            k = 0
            for i in range(c * CH, min(N, (c + 1) * CH)):
                vi = v[i]; gi = g[i]; wi = wad[i]; ri = refr[i]; pn = pnext[i]
                buf = gbuf[i]
                if vi == V0 and gi == 0.0 and wi == 0.0 and ri == 0 and pn == NEVER:
                    # at rest: nothing changes unless input arrives during this block
                    quiet = True
                    sl = slot0
                    for s in range(nb):
                        if buf[sl] != 0.0:
                            quiet = False
                            break
                        sl += 1
                        if sl == D:
                            sl = 0
                    if quiet:
                        continue
                th = vth[i]
                p = rates[i] * DT
                sl = slot0
                if p > 0.0:                          # a stimulus-driven (sensory) neuron: Poisson input, no refractory period
                    lq = np.log1p(-min(p, 0.999))
                    for s in range(nb):
                        gi += buf[sl]
                        buf[sl] = 0.0
                        kick = 0.0
                        if pn == 0:
                            kick = W_POI
                            pn = int(np.log(1.0 - np.random.random()) / lq)
                        else:
                            pn -= 1
                        if ri > 0:
                            ri -= 1
                            vi += kick
                        else:
                            vi = V0 + (vi - V0) * A_M + (gi - wi) * G_COEF + kick
                            gi *= A_S
                            wi *= A_W
                        if vi > th:
                            vi = V0; gi = 0.0; wi += adapt_b; ri = 0
                            if k < cap:
                                spk_t[c, k] = t0 + s; spk_i[c, k] = i; k += 1
                        sl += 1
                        if sl == D:
                            sl = 0
                else:                                # every other neuron: synaptic input only
                    for s in range(nb):
                        gi += buf[sl]
                        buf[sl] = 0.0
                        if ri > 0:
                            ri -= 1
                        else:
                            vi = V0 + (vi - V0) * A_M + (gi - wi) * G_COEF
                            gi *= A_S
                            wi *= A_W
                            if vi > th:
                                vi = V0; gi = 0.0; wi += adapt_b; ri = R_STEPS
                                if k < cap:
                                    spk_t[c, k] = t0 + s; spk_i[c, k] = i; k += 1
                        sl += 1
                        if sl == D:
                            sl = 0
                # back to exact rest once the deviations are far below anything that matters (0.1 uV, 0.01 uV of drive)
                if abs(vi - V0) < 1e-4 and abs(gi) < 1e-5 and abs(wi) < 1e-5:
                    vi = V0; gi = 0.0; wi = 0.0
                v[i] = vi; g[i] = gi; wad[i] = wi; refr[i] = ri; pnext[i] = pn
            cnt[c] = k
        # deliver this block's spikes, each D steps after it was fired; every thread handles its own target range
        R = seg.shape[1] - 1
        for r in prange(R):
            for c in range(nch):
                for j in range(cnt[c]):
                    i = spk_i[c, j]
                    slot = spk_t[c, j] % D
                    for kk in range(seg[i, r], seg[i, r + 1]):
                        gbuf[indices[kk], slot] += weights[kk]
        for c in range(nch):
            for j in range(cnt[c]):
                if nout < out_t.shape[0]:
                    out_t[nout] = spk_t[c, j]; out_i[nout] = spk_i[c, j]; nout += 1
        s0 += nb
    return nout


@njit(cache=True, fastmath=True)
def _run(          # the original step-by-step kernel, kept for checking (run(reference=True))
        n_steps, step0, v, g, gbuf, refr, rates, indptr, indices, weights, spk_t, spk_i, seed, wad, adapt_b, vth, prm):
    DT, A_M, A_S, A_W, G_COEF = prm[0], prm[1], prm[2], prm[3], prm[4]
    R_STEPS = int(prm[5])
    np.random.seed(seed)
    N = v.shape[0]
    D = gbuf.shape[0]
    p_poi = rates * DT
    w_poi = W_SYN * F_POI
    nspk = 0
    for s in range(n_steps):
        t = step0 + s
        slot = t % D
        # deliver delayed synaptic input
        row = gbuf[slot]
        for i in range(N):
            if row[i] != 0.0:
                g[i] += row[i]
                row[i] = 0.0
        # integrate + detect spikes
        dslot = (t + D) % D  # == slot: contributions arriving in D steps
        for i in range(N):
            if refr[i] > 0:
                refr[i] -= 1
                if p_poi[i] > 0.0 and np.random.random() < p_poi[i]:
                    v[i] += w_poi
                else:
                    continue
            else:
                gi = g[i]
                v[i] = V0 + (v[i] - V0) * A_M + (gi - wad[i]) * G_COEF
                g[i] = gi * A_S
                wad[i] *= A_W
                if p_poi[i] > 0.0 and np.random.random() < p_poi[i]:
                    v[i] += w_poi
            if v[i] > vth[i]:
                v[i] = V0
                g[i] = 0.0
                wad[i] += adapt_b
                refr[i] = 0 if p_poi[i] > 0.0 else R_STEPS
                if nspk < spk_t.shape[0]:
                    spk_t[nspk] = t
                    spk_i[nspk] = i
                    nspk += 1
                for k in range(indptr[i], indptr[i + 1]):
                    gbuf[dslot, indices[k]] += weights[k]
    return nspk
