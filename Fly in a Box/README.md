# A Fly in a Box

A whole fruit-fly brain, every neuron and every synapse from the FlyWire connectome, wired to a
physical fly body and left alone in a closed arena with a drop of food, a dark post and a stripe
on one wall. We watch what it does.

Nothing here is trained. The brain is the real wiring diagram of one adult female
*Drosophila melanogaster* (FlyWire v783: 138,639 neurons, 15.1 million connections, with the sign
of every connection predicted from its neurotransmitter). The body is NeuroMechFly, a
physics model of the fly with real leg anatomy, simulated in MuJoCo.

## What is real and what is glue

Honesty matters more than the demo. This is the full list of what is measured data, what is a
published model, and what is a modelling decision made for this project.

**Real data**

- Every neuron, every connection, synapse counts and signs: FlyWire v783 (Dorkenwald et al.,
  Nature 2024; Schlegel et al., Nature 2024).
- Cell type labels and positions used to pick sensory, descending and motor neurons
  (flyconnectome/flywire_annotations).
- The body: NeuroMechFly v2 leg anatomy, joint ranges and compound-eye geometry (Wang-Chen et
  al., Nature Methods 2024).

**Published models**

- Neuron dynamics: leaky integrate-and-fire with the parameters of Shiu et al. (Nature 2024),
  which reproduced real experiments (sugar taste drives the proboscis motor neuron MN9). We
  re-implemented it in numba (`brain.py`) and checked it reproduces the published steering
  response: driving one eye's LC10a neurons makes the same-side DNa02 fire (95 Hz left, 0 right).
- Walking: the tripod-gait pattern generator with reflex corrections shipped with NeuroMechFly.

**Glue (our decisions)**

- *Photoreceptors.* The body's compound eyes render 721 ommatidia per eye in colour. Each of the
  10,582 photoreceptor neurons in the connectome is assigned to an ommatidium by position (anterior
  to posterior along the lamina, dorsal to ventral). R1-6 cells get the ommatidium's brightness,
  R8 cells get its colour channel (blue in pale ommatidia, green in yellow ones, as in the real
  retina), and R7 cells, which see ultraviolet in the real fly, get blue because the renderer has
  no UV. Each fires at 40 Hz x input plus 160 Hz x change-in-input with 200 ms adaptation. The real photoreceptor is a graded-potential cell
  and its neurotransmitter is not in the sign predictions, so, as the probes showed, light in this
  model stays in the optic lobe and does not reach the central brain. The eyes are on and the
  optic lobe lights up, but vision does not currently steer the fly.
- *Vision, features.* The spiking model cannot do the optic lobe's graded computations, so two
  known visual features are computed from the eye images and injected into the visual projection
  neurons that carry them in the real fly: a small dark object in an eye drives that eye's LC10a
  neurons (the real pursuit pathway; in the model it shifts the descending population toward that
  side), and a dark object whose apparent size grows faster than doubling per second drives
  LC4 and LPLC2 (the real looming pathway; in the model it fires the giant fibre).
- *Smell.* The food emits a Gaussian odour plume (14 mm wide). The olfactory receptor neurons of
  four glomeruli that respond to food odour in real flies (DM1, DM4, VA2, DM2) fire at up to
  120 Hz x concentration, each antenna sampling the plume where it actually is.
- *Taste.* When the head is within 3 mm of the food, the labellar sugar neurons fire at 100 Hz.
- *Touch.* When the head is within 1.2 mm of a wall or the post, head-bristle neurons fire at
  80 Hz.
- *Nerve cord.* The ventral nerve cord, where walking is generated, is not in the FlyWire dataset.
  It is replaced by the pattern generator, given a constant baseline drive of 0.5. Steering is the
  left-right imbalance of firing across all ~1,300 descending neurons (reading a single pair such as
  DNa02 made the fly spin, because that pair is lopsided in this model). DNp09 speeds walking up,
  MDN reverses, the giant fibre DNp01 triggers a backward startle, and the proboscis motor neuron
  MN9 stops the legs (feeding).
- *Walls.* The body model only collides through explicit contact pairs, so the walls and the post
  are made solid to the body segments but not to the feet (the adhesive feet would climb the wall
  and tip the fly over).
- Nothing else. No learning, no neuromodulation, no hunger state, no spontaneous activity: this
  brain is silent until a sense drives it.

## The behaviour layer

The wiring-only model reacts but does not want, explore, or get off a wall (see the findings
below). On top of the real brain there is therefore an explicit behaviour layer, written from
published fly behaviour and clearly separated in the video ("inner state"):

- *Hunger* (0 full, 1 starved). Starved flies walk more, pause less and follow food smell
  (octopamine / NPF / dopamine effects in the real fly). Feeding fills the fly up.
- *Walking bouts and pauses*, a few seconds each, and *spontaneous turns* roughly every 1 to 2
  seconds, as in free-walking flies.
- *Wall following*: a fly that meets a wall backs off if blocked, turns to run along it, and leaves
  it now and then (thigmotaxis in open-field arenas).
- *Odour turning*: turning toward the antenna that smells more food, scaled by hunger, with local
  search when the smell fades (bilateral olfactory comparison in walking flies).
- *Feeding*: sugar on the feet stops a hungry fly (a nerve-cord reflex); the proboscis is then
  extended in proportion to the real brain's MN9 proboscis motor neuron firing (the sugar-to-MN9
  circuit validated by Shiu et al.). The body is the fully jointed NeuroMechFly (`fullfly.py`):
  legs, head, proboscis, antennae, abdomen and wings are all actuated.
- *Grooming*: bouts during pauses (likelier after bristle contact with the walls, "dust"), and
  whenever the brain's antennal-grooming command neuron DNg12 fires. Three real actions, as
  postures tuned by eye (`pose_sheet.py`): front-leg rubbing, head and eye grooming with the front
  legs, hind-leg rubbing. Abdomen and wing grooming are not yet posed.
- *Escape*: only when the real brain's giant fibre fires on a looming object.

The real brain's own steering signal (left-right imbalance of all descending neurons) is added to
the turn command throughout. The video shows the three contributions separately.

## What fires when: reward, smell and the saturation problem (solved)

Measured in isolated probes (`brain.py`) and on the box runs:

- Taste is specific: the sugar neurons fire only while feeding, and the proboscis motor neuron
  MN9 goes to about 80 Hz for sugar alone.
- Sugar alone does not reach the PAM reward dopamine neurons (0 Hz). In the living fly that link
  depends on hunger-state neuromodulation, which a wiring-only model cannot express.
- **The saturation problem, as first found.** With the brain exactly as published, any food smell,
  even at 5 Hz on the receptor neurons, flipped the brain into one fixed state of about 10,400
  active neurons with the PAM dopamine neurons at 50-70 Hz and 75% of the mushroom-body Kenyon
  cells on, and the smell suppressed MN9 (77 -> 7 Hz). That is not a fly; it is a seizure.
- **The cause, in the wiring table.** Two things that the connectome annotation gets wrong for a
  spiking model:
  1. The antennal-lobe local neurons (`ALLN`, 429 cells). The real ones are GABAergic and
     glutamatergic, i.e. inhibitory, and they are the brakes of the olfactory system. The
     neurotransmitter predictions in FlyWire label 120 of them acetylcholine or serotonin, so the
     model treated the brakes as accelerators and the smell response ran away.
  2. Sensory neurons (`sensory`, `sensory_ascending`) received synaptic input from the brain. In the
     model this fed the runaway state back into the receptors. The real receptor neurons are driven
     by the stimulus, so their inputs are now stimulus-only.
- **The fix** (`Brain.apply_biology_fixes()`, on by default; `--published-brain` turns it off):
  every ALLN output is made inhibitory and the sensory neurons are clamped to their stimulus.
  Nothing else changes: same neurons, same synapse counts, same weights.
- **Result.** A faint smell now recruits 319 neurons instead of 10,405; 4% of Kenyon cells respond
  instead of 75% (real flies: 5-10%); MN9 keeps firing at about 80 Hz with smell present; the PAM
  reward neurons sit at about 1 Hz until driven. The LC10a -> DNa02 steering check is unchanged.
  In the box, spikes per 10 ms frame fell from about 12,000 to about 3,000.
- **Reward.** Feeding, escape, grooming and steering are driven by their real circuits, but
  "reward" is not something this brain produces on its own. It is delivered the way reward
  experiments deliver it in the lab: while a hungry fly eats, the behaviour layer drives the real
  sweet-reward dopamine neurons (PAM02, PAM07, PAM08, PAM11: the PAM-beta'2, gamma4 and alpha1
  subtypes of Burke 2012, Liu 2012, Yamagata 2015, Huetteroth 2015; 95 cells) at up to 100 Hz,
  scaled by hunger so the burst fades as the fly fills up. Those 95 cells are drawn in pink on the
  brain panel so you can see them light up during the meal. Everything downstream of them is the
  real wiring. Because the model cannot rewrite synapses, the memory consequence (a learned
  attraction to the food smell) is tracked in the behaviour layer as "food memory", built while
  reward and smell coincide.

## The male dataset, and why the nerve cord is still a stand-in

`cns.py` loads the complete male central nervous system (MaleCNS v1.0, Janelia 2026: 211,577
neurons, 25.6 million connections, brain plus ventral nerve cord) into the same neuron model. Two
things come out of it:

- The escape circuit is real end to end: driving the giant fibre fires the wing power-muscle motor
  neurons, as in the living fly.
- Walking does not. With the walking command neurons driven, about 40 of the 381 leg motor neurons
  switch on and stay on, extensors only, with no rhythm and no left-right difference, for forward,
  backward and turning commands alike. Leg sense-organ feedback and stronger synapses do not change
  this. Nearly any strong input (smell, a dark object, looming) collapses the model into the same
  state. So the nerve cord, simulated as identical simple neurons, carries no steering and no
  stepping, and the pattern generator remains the stand-in. That is a limit of the neuron model,
  not of the data.

## Files

```
brain.py     whole-brain LIF simulator (numba), loads FlyWire v783 connectivity + annotations
flybox.py    the closed loop: senses -> brain -> descending neurons -> legs, in the arena
cns.py       whole-CNS simulator for the male dataset (brain + nerve cord), used for the tests above
render.py    composes the video: body cameras, both eyes, brain activity, descending-neuron meters
```

## Running it

```sh
python -m venv venv && . venv/bin/activate
pip install numpy pandas pyarrow scipy numba imageio imageio-ffmpeg pillow flygym
git clone --depth 1 https://github.com/philshiu/Drosophila_brain_model.git   # contains Connectivity_783.parquet
mkdir -p data && curl -sL -o data/flywire_annotations_783.tsv \
  https://raw.githubusercontent.com/flyconnectome/flywire_annotations/main/supplemental_files/Supplemental_file1_neuron_annotations.tsv
MUJOCO_GL=osmesa python flybox.py --seconds 25 --out out/run1    # ~50 s of compute per simulated second
python render.py --run out/run1 --out out/fly_in_a_box.mp4
```

`flybox.py` expects `out/omm_centroids.npy` (ommatidia centroids in the eye image), produced by
reading `Retina().ommatidia_id_map` once; see the top of `render.py` for the same map.
