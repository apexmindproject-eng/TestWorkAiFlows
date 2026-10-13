"""Whole-CNS leaky integrate-and-fire simulation of the MaleCNS v1.0 connectome (Janelia, 2026):
brain + ventral nerve cord of one adult male fly. Same neuron model as brain.py (Shiu et al. 2024
parameters); synapse sign from the per-neuron consensus neurotransmitter prediction."""
import time
import numpy as np
import pandas as pd
import pyarrow.feather as F
from brain import _run, V0, D_STEPS, W_SYN

INHIBITORY = {"gaba", "glutamate", "histamine"}

class CNS:
    def __init__(self, folder="malecns", verbose=True):
        t0 = time.time()
        ann = F.read_table(f"{folder}/body-annotations-male-cns-v1.0-minconf-0.5.feather").to_pandas()
        nt = F.read_table(f"{folder}/body-neurotransmitters-male-cns-v1.0.feather", columns=["body", "consensus_nt"]).to_pandas().drop_duplicates("body")
        con = F.read_table(f"{folder}/connectome-weights-male-cns-v1.0-minconf-0.5-traced-only.feather", columns=["body_pre", "body_post", "weight"]).to_pandas()
        bodies = np.unique(np.concatenate([con.body_pre.to_numpy(), con.body_post.to_numpy(), ann.bodyId.to_numpy()]))
        self.body_ids = bodies.astype(np.int64)
        self.N = len(bodies)
        self.id2i = pd.Series(np.arange(self.N), index=self.body_ids)
        self.ann = ann.set_index("bodyId").reindex(self.body_ids)
        self.ann["nt"] = nt.set_index("body").consensus_nt.reindex(self.body_ids).fillna("unknown").to_numpy()
        self.ann["side"] = self.ann.somaSide.fillna("?").to_numpy()
        self.ann["type"] = self.ann["type"].fillna("").to_numpy()
        sign = np.where(self.ann["nt"].isin(INHIBITORY).to_numpy(), -1.0, 1.0).astype(np.float32)
        pre = self.id2i.loc[con.body_pre.to_numpy()].to_numpy()
        post = self.id2i.loc[con.body_post.to_numpy()].to_numpy()
        w = (con.weight.to_numpy().astype(np.float32) * sign[pre] * W_SYN).astype(np.float32)
        order = np.argsort(pre, kind="stable"); pre, post, w = pre[order], post[order], w[order]
        self.indptr = np.zeros(self.N + 1, dtype=np.int64); np.add.at(self.indptr, pre + 1, 1); self.indptr = np.cumsum(self.indptr)
        self.indices = post.astype(np.int32); self.weights = w; self.n_syn = len(w)
        self.reset()
        if verbose:
            print(f"[cns] {self.N} neurons, {self.n_syn} connections, {(sign < 0).mean()*100:.0f}% inhibitory, loaded in {time.time()-t0:.0f}s")

    def find(self, cell_type, side=None):
        m = (self.ann["type"] == cell_type) | self.ann["type"].str.startswith(cell_type + "_")
        if side: m &= self.ann["side"] == side
        return np.flatnonzero(m.to_numpy())

    def reset(self):
        self.v = np.full(self.N, V0, dtype=np.float32); self.g = np.zeros(self.N, dtype=np.float32)
        self.gbuf = np.zeros((D_STEPS, self.N), dtype=np.float32); self.refr = np.zeros(self.N, dtype=np.int32)
        self.rates = np.zeros(self.N, dtype=np.float32); self.step = 0

    def set_rates(self, idx, hz): self.rates[idx] = hz

    def run(self, n_steps, seed=None, max_spikes=10_000_000):
        if seed is None: seed = self.step
        spk_t = np.empty(max_spikes, dtype=np.int32); spk_i = np.empty(max_spikes, dtype=np.int32)
        n = _run(n_steps, self.step, self.v, self.g, self.gbuf, self.refr, self.rates, self.indptr, self.indices, self.weights, spk_t, spk_i, int(seed))
        self.step += n_steps
        return spk_t[:n], spk_i[:n]
