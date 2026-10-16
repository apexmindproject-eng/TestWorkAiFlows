# A Fly in a Box

A whole fruit-fly brain, every neuron and every synapse from the FlyWire connectome, wired to a
physical fly body and left alone in a closed arena (60 x 60 x 30 mm, with a glass lid) with a drop
of food, a dark post and a stripe on one wall. We watch what it does.

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
- *Walls and lid.* The body model only collides through explicit contact pairs, so the walls, the
  post and the invisible lid are made solid to the body segments. The feet touch them only while
  the fly is climbing, flying or landing (on the floor the adhesive feet would catch on the wall
  during wall following and tip the fly over).
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
- *Wall climbing*: a fly that meets a wall head-on usually climbs it (flies spend much of their
  time on arena walls), patrols it, and leaves it the way flies do: turns head-down and flies off.
  See the next section for what it took.
- *Take-off and flight*: when the real brain's giant fibre fires on a looming object and the fly
  is on the floor, it takes off, flies for a second or two at a height of its own choosing, anywhere
  up to the lid (held level and at height by a haltere-level stabiliser, steered by the brain's
  descending imbalance and away from walls), then lands where it was going: on the floor on its
  feet, on a wall feet first, or upside down on the lid after the flip real flies do. From a wall or
  the lid it later takes off again. A fly left on its side or back buzzes its wings to right itself,
  and one knocked off a wall catches itself in the air. See "Flight" below.

The real brain's own steering signal (left-right imbalance of all descending neurons) is added to
the turn command throughout. The video shows the three contributions separately.

## Wall climbing: what it took

Three things, all measured rather than guessed:

1. **The gait had to be born in step.** The leg oscillators (the CPG that stands in for the nerve
   cord) start from random phases and take about a second to lock into the tripod pattern. On the
   floor nobody notices; on a wall the first unlocked step releases five feet at once and the fly
   drops. Every run now warms the oscillators up before the first step. With that one change a fly
   placed on a vertical wall walks straight up it at about 8 mm/s.
2. **Adhesion in proportion.** The pulvilli are MuJoCo adhesion actuators on the last tarsal
   segment, as in NeuroMechFly. 40 (the walking default) and 120 let go on a wall; 400 holds and
   climbs, and is used on the floor as well. The leg reflexes (height correction, stumbling) are
   computed in the fly's own frame, not against gravity, so the same walking controller works on
   any surface.
3. **Getting from the floor onto the wall.** The stepping gait alone never climbs: it holds a fixed
   body height and just stops against anything in front, even a 45-degree fillet. What works is the
   sequence flies actually use, written as a nerve-cord posture programme on top of the gait:
   square up to the wall and walk into it until the head touches; rear up (a posture servo holds
   the nose 25 degrees up, so the programme adapts to the body); lift one front leg, sweep it
   forward until the foot touches the wall, glue it; the same with the other; then let the gait
   take over while the mounting posture fades out over 1.5 s. The body pitches from 25 to 85
   degrees in a quarter of a second, the middle and hind feet find the wall, and the fly climbs
   (about 3 mm/s in the box, with the full body). Near the top it turns round and walks down.

Not solved: the walking step back onto the floor. Walking down head-first ends with the head
against the floor and the body vertical; every dismount tried (let go and tip, plant the front feet
on the floor first, turn sideways at the base) ends with the fly on its back. So a fly that has
climbed patrols the wall (up, turn, down, turn) and leaves it as real flies mostly do: it turns
head-down and flies off (a fly that does fall lands on its feet, or rights itself with a wing buzz;
see "Flight"). Also not modelled: climbing the post.

## Flight: what it took

The wings are real bodies with real hinges in NeuroMechFly, but they have no air to push on. Flight
is added in `wings.py`, every number measured on this model:

1. **Air.** MuJoCo's ellipsoid fluid model, as in the flybody flight model: a thin ellipsoid on
   each wing (0.55 x 1.2 mm, placed at 0.6 of the wing length where flapping lift centres), air
   density 1.28e-6 g/mm^3, viscosity 1.85e-5. The quasi-steady lift coefficient is doubled
   (leading-edge-vortex regime, Dickinson 1999); without that the wings make about a fifth of the
   fly's weight.
2. **The stroke.** Solved by inverse kinematics on the model's own three-axis wing hinges: a
   horizontal stroke of +-70 degrees at 200 Hz with a 55-degree angle of attack that flips at each
   reversal, continuous in joint space. Measured with the body held: 11.7 uN of lift against a
   weight of 10.05 uN, mirror-symmetric to within 0.1 uN. Two model details mattered: the walking
   model's wing hinge damping (0.06) would need 120 times the motor force at 200 Hz, so the flight
   muscles are stiffer (kp 350) only while flying; and the lift must be read against the true centre
   of mass, 0.8 mm behind the thorax origin, otherwise the trim is wrong.
3. **Staying up.** Flapping flight is unstable in pitch within tens of milliseconds, as in the real
   insect. The stabiliser (the job of the halteres and the wing steering muscles) uses: stroke
   amplitude for lift and height; a wing-pitch offset for body pitch (measured 32,000 rad/s^2 per
   radian of offset); left/right amplitude asymmetry for roll; opposite wing-yaw offsets for yaw.
   Attitude signals are averaged over about a wingbeat, which turned out to be essential: the raw
   signals carry the 200 Hz body wobble and the damping term then pumps the instability. Forward
   speed is set by the pitch target. Measured: altitude held within 0.2 mm, pitch within a few
   degrees, for the full test flights.
4. **Any attitude.** The stabiliser recovers from any orientation, which is what makes everything
   below possible: the attitude angles are unwrapped so an inverted fly reads 180 degrees rather
   than dithering at the wrap, far from level the wings give full torque, and roll is corrected
   before pitch. Measured, released with no speed: upside down at 26 mm it is upright in 10 ms and
   loses 13 mm; on its side or nose-down at 14 mm it loses about 1 mm; nose-up (as when a fly lets
   go of a wall facing up) is the worst case and needs 18 mm, which is why a fly leaves a wall
   facing down. On the floor, on its back, it rights itself in 25 ms with a wing buzz and all legs
   stretched out (the wings alone cannot do it).
5. **Landing on a wall.** The fly flies level at the wall with its front legs out. Whichever foot
   touches first is glued, and a glued leg then moves from its reaching pose to its standing pose,
   which pulls the body round onto the wall; the free legs find the wall as the body arrives, and
   the climbing gait takes over. Measured: contact to six feet on the wall in 0.4 s, climbing at
   4 mm/s within a second. An earlier version that pitched up before the wall, as real flies do,
   bounced off: the tilted stroke brakes at 8 m/s^2 and the fly backs away before any foot touches.
6. **Landing on the lid.** Flies land on ceilings with a rapid body flip just below the surface,
   legs out, and catch it with their feet (Liu, Chen and Chang 2019). The same works here, and the
   numbers set it: the feet reach 1.4 mm beyond the thorax with the legs down and out, 2.2 mm with
   the legs straight down, and a flip takes 16 ms, during which gravity takes 160 mm/s off the
   climb. So the fly climbs hard at the lid (0.4 g), starts a roll at 2.8 mm below it with the
   straight-down landing gear, brakes the roll in its second half, stops the wings, and arrives
   inverted 1.5 mm under the glass with the feet touching. The feet stick only once the body is
   past 90 degrees (gluing earlier pins the fly half way), then the same chin-up as on the wall
   settles it: six feet in 0.5 s, walking upside down at 4.5 mm/s a second after that. A pitch
   flip (nose-up, the other manoeuvre real flies use) is three times slower on this model and is
   not used. Not every attempt succeeds: in about one landing in three the feet of one side catch
   first and the fly hangs from them without getting the others up, or the first steps of the
   upside-down gait let go; it then drops, rolls upright in the air and lands on the floor. The
   same happens to real flies. In the box the leg reflexes are reset at each landing and the
   gait is eased in over 0.3 s; gluing all feet during that time made it worse (a glued leg that
   the gait is lifting stretches, and jolts the body when released).
7. **Leaving a surface.** From a wall the fly turns head-down, lets go and flies off; from the lid
   it lets go, falls upside down and rolls upright (13 mm of the 28 mm available).
8. **In the box.** The giant fibre's output on the floor is now the real one, a take-off: wings spin
   up for 60 ms while the feet hold, then the feet let go and the stabiliser flies the fly, steered
   by the brain and away from walls, at a height drawn for each flight between 4 mm and the lid.
   Where it lands is drawn too: the floor (45%), a wall at a height between 8 and 22 mm (30%), the
   lid (25%). In flight the fly steers away from every wall that is near and ahead and slows down
   near them; one that is still pressed against a wall by its own thrust (it happens leaving a
   wall or the lid next to a corner) tries to grab it, and usually slides down onto its feet.

Not modelled: the jump that starts a real escape take-off (the legs let go instead), the 60 ms
of wing spin-up is an estimate, and the wingbeat is not visible at 30 frames per second. The
landings and the flip are scripted at the level of a nerve-cord motor programme, like the wall
mount: the real brain decides when to fly and where to steer, not how to land.

## What fires when: reward, smell and the saturation problem (solved)

Measured in isolated probes (`brain.py`) and on the box runs:

- Taste is specific: the sugar neurons fire only while feeding, and the proboscis motor neuron
  MN9 goes to about 80 Hz for sugar alone. Taste is sensed where a fly senses it: the sugar
  receptor neurons fire when a front foot stands on the food (tarsal receptors) or the labellum
  touches it. A foot on the sugar stops the fly and it creeps forward until its mouth is over the
  food; intake and reward happen only while the proboscis tip is actually on the surface, and the
  proboscis is a physical body that rests on the food disc rather than passing through it.
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
flybox.py    the closed loop: senses -> brain -> descending neurons -> legs and wings, in the arena
fullfly.py   the fully jointed NeuroMechFly body (legs, head, proboscis, antennae, abdomen, wings)
wings.py     flight: air on the wings, the wingbeat (solved once, cached in wing_stroke.npz), the stabiliser and the landing flip
cns.py       whole-CNS simulator for the male dataset (brain + nerve cord), used for the tests above
render.py    composes the video: body cameras, both eyes, brain activity, descending-neuron meters
live.py      sandbox mode: the web server that streams the fly to a browser or the Android app and takes its commands
android/     the Android app (a full-screen window onto the live page)
```

## Sandbox mode and the phone app

The simulation can be watched and poked from a phone, and can even run on one (see
`phone/README.md`; it is slow there). Start it in sandbox mode:

```sh
MUJOCO_GL=osmesa python flybox.py --live 8765
```

It runs until stopped and serves a page at `http://<that computer>:8765/` for any browser on the
same network, with the chosen camera streamed as it is rendered (about 50 times slower than the
clock: a second of watching is 20 ms of fly time). The Android app in `android/` is that page in a
full-screen window; it asks once whether the fly runs on this phone or on a computer at some
address (long-press Back to change it). The
`Android APK` workflow in `.github/workflows/apk.yml` builds it on every push and attaches
`FlyInABox.apk` to the `apk` release of the repository.

What the page lets you do (all of it is the experimenter's hand, not the fly's brain; what the fly
does about it is the brain's):

- *shadow*: a shadow sweeps over the box: the looming neurons fire and the giant fibre decides.
- *poke*: a flick of a finger (15 uN sideways for 10 ms).
- *toss into the air* and *drop on its back*: the fly is lifted 10 mm and released, upright with a
  take-off, or upside down so it lands on its back and rights itself.
- *put on the lid* / *put on a wall*: placed there by hand, it walks on, and leaves when it chooses.
- *blindfold*: the eyes see uniform grey (no looming, no dark objects).
- *hunger* slider and *tap the overhead view to move the food*.
- *pause*, and a choice of cameras.

`live.py` is the whole server (motion JPEG stream, a JSON state line, a command queue applied by
the simulation at its next 10 ms tick).

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

`flybox.py` expects `out/omm_centroids.npy` (ommatidia centroids in the eye image); copy the
`omm_centroids.npy` in this folder there. To run the whole thing on an Android phone instead of a
computer, see `phone/README.md` (Termux; the same code, one to three minutes per simulated second).
