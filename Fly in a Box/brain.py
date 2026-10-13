"""Whole-brain leaky integrate-and-fire simulation of the FlyWire v783 adult fly connectome.

Same neuron model and parameters as Shiu et al. 2024 (Nature), re-implemented in numba so a
closed loop with a body simulation is practical. Every one of the ~139k neurons and ~15M
synapses is simulated. Nothing is trained.
"""
import time
import numpy as np
import pandas as pd
from numba import njit

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


class Brain:
    def __init__(self, comp_path, con_path, ann_path=None, verbose=True):
        t0 = time.time()
        comp = pd.read_csv(comp_path, index_col=0)
        self.root_ids = comp.index.to_numpy().astype(np.int64)
        self.N = len(self.root_ids)
        self.id2i = {rid: i for i, rid in enumerate(self.root_ids)}

        con = pd.read_parquet(con_path, columns=["Presynaptic_Index", "Postsynaptic_Index", "Excitatory x Connectivity"])
        pre = con["Presynaptic_Index"].to_numpy().astype(np.int64)
        post = con["Postsynaptic_Index"].to_numpy().astype(np.int64)
        w = (con["Excitatory x Connectivity"].to_numpy() * W_SYN).astype(np.float32)
        order = np.argsort(pre, kind="stable")
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
        self.gbuf = np.zeros((D_STEPS, self.N), dtype=np.float32)
        self.refr = np.zeros(self.N, dtype=np.int32)
        self.rates = np.zeros(self.N, dtype=np.float32)   # Hz of Poisson drive per neuron
        self.wad = np.zeros(self.N, dtype=np.float32)     # adaptation variable (mV)
        self.adapt_b = 0.0                                 # mV added per spike; 0 = the published model
        self.step = 0

    def set_rates(self, idx, hz):
        self.rates[idx] = hz

    def clear_rates(self):
        self.rates[:] = 0

    def run(self, n_steps, seed=None, max_spikes=5_000_000):
        """Advance the brain. Returns (spike_step, spike_neuron) arrays for this chunk."""
        if seed is None:
            seed = self.step
        spk_t = np.empty(max_spikes, dtype=np.int32)
        spk_i = np.empty(max_spikes, dtype=np.int32)
        n = _run(n_steps, self.step, self.v, self.g, self.gbuf, self.refr, self.rates,
                 self.indptr, self.indices, self.weights, spk_t, spk_i, int(seed), self.wad, float(self.adapt_b))
        self.step += n_steps
        return spk_t[:n], spk_i[:n]


@njit(cache=True, fastmath=True)
def _run(n_steps, step0, v, g, gbuf, refr, rates, indptr, indices, weights, spk_t, spk_i, seed, wad, adapt_b):
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
            if v[i] > VTH:
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
