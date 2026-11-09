# Tactics layer (v85 to v87)

The decision core changed in v85. This file says why, what the new rules are,
and how to tell from a log whether they work.

## Why

Five logs of v83/v84 (25 lives, 49 minutes) and the memory file (77 career
lives) were measured before anything was changed.

| Measure | Value |
|---|---|
| Time spent stunned | 46% of every life |
| Damage dealt for each 1 taken | 0.67 |
| Skill hit rate | 29% |
| Casts followed by getting hit | 87% |
| Casts chained within 0.6 s of the previous one | 3% |
| Blocks dropped within 0.1 s | 51% |
| Casts the server refused | 19% |
| Damage not credited to any move | 56% |
| Median tries the learner had per move | 8 |

None of that belongs to one moveset. The machine threw single skills at
opponents who were free to block, blocked only after seeing the swing, aimed at
where the target stood, and learned from a sample too thin to mean anything.

## The rules

All of them read only what every character exposes the same way
(`HumanoidRootPart`, `Info.Stun`, the `Ragdoll` attribute, `CurrentM1`), so
they apply to every moveset, including ones added later.

| Rule | What it does | Switch |
|---|---|---|
| Chain off a landed hit | A target stunned on its feet cannot block or move. The moment that is true and our own string has reached its second hit, a skill is cast with no waiting. Quick close moves first, control next, the heavy move when it would finish; learned chain and damage weights sort within that | `TacCombo` |
| Hold skills for a hit | In melee with no hit confirmed, the gap between raw casts goes from 2 s to 4 s. Basic attacks keep going | `TacDiscipline` |
| Block before the swing | Every nearby fighter's velocity is tracked. Someone facing us, closing at 12 studs/s or more, who will be within 6.5 studs inside 0.38 s gets a block raised now. It waits 0.55 s for the swing, then drops, and cannot fire again for 1.4 s | `TacGuard` |
| Counter a blocked string | A block that absorbed at least one swing and held 0.25 s opens a 1.1 s punish window | `TacPunish` (seconds, 0 = off) |
| Lead the target | Aim point and facing use position + velocity x (wind-up + distance / projectile speed), capped at 0.7 s and 16 studs. Applies to moves with 25 studs of reach or more | `TacLead` |
| No casts while stunned | A cast thrown while stunned or ragdolled is not sent | `TacCastGate` |
| Prefer the vulnerable | A fighter already stunned or down within 30 studs scores higher as a target | `TacVulnWeight` |

Also fixed: since game 1.85 a dead body is moved out of the arena before the
death handler runs, so no death position had been recorded since the update.
The last position while alive is used now. Basic attacks are counted for the
first time.

All switches are under **Tactics** in the HUD menu. The numbers are in `Config`.

## Reading a log

Every `LIFE END` line ends with a tactics segment:

```
| tactics: confirm 9/11 hit 96 dmg; neutral 3/12 hit 21 dmg; punish 2/3 hit 18 dmg;
  combos 11; pre-guards 14 (6 met a swing), counters 4; lead-aimed 7; gated 3;
  M1 84 swings 31 hits 122 dmg
```

| Field | Meaning | What good looks like |
|---|---|---|
| `confirm h/n` | casts chained off a confirmed hit, and how many landed | hit rate well above `neutral` |
| `neutral h/n` | raw casts | fewer than before, and no worse a hit rate |
| `punish h/n` | casts thrown in a punish window | |
| `combos` | chained casts sent | several per life |
| `pre-guards a (b met a swing)` | predicted blocks, and how many were actually swung at | if `b` is a small share of `a`, the trigger is too eager: raise `TacGuardSpeed` or lower `TacGuardTTC` |
| `counters` | punish windows opened by a held block | |
| `lead-aimed` | casts turned onto a predicted position | |
| `gated` | casts withheld because we could not act | |
| `M1 swings / hits / dmg` | basic attacks | the share of total damage that was invisible before |

New lines while fighting:

```
combo: Blind Rage off a confirmed hit (M1 step 2, stun held 0.31 s, 5 studs)
guard: Holycow506 closing at 23 studs/s from 14 studs, contact in 0.33 s - block up
refused: Turbulence (no stamp moved | at cast: m1=2 dash=false blk=false/1.20 tstun=false trag=true d=9 ctx=neutral)
```

The refusal line now carries the state at the moment of the cast. A pattern
there (always `trag=true`, always shortly after a block) is the next gate.

The figures to compare with the table at the top: stunned share of life,
damage dealt against taken, `DEFEND held` times, and refused casts.

## v86: what the first v85 log showed, and what changed

One v85 log (18 lives, 38 minutes, 14 different characters) against the v83/v84 baseline:

| Measure | Before | v85 |
|---|---|---|
| Damage dealt for each 1 taken | 0.67 | 0.88 |
| Damage per second | 1.00 | 1.20 |
| Time spent stunned | 46% | 41% |
| Hit rate of casts chained off a confirmed hit | n/a | 80% (16 of 20) |
| Hit rate of raw casts | 29% | 32% (139 of 435) |
| Predicted blocks that met a swing | n/a | 34% (18 of 53) |
| Casts refused | 19% | 27% |
| Blocks lasting 0.1 s or less | 51% | 64% |
| Share of far-approach time spent moving backwards | not measured | 60% |

The principle holds: a cast chained off a confirmed hit lands 80% of the time
against 32% raw. It just fires far too rarely (20 times in 38 minutes).

What v86 changes because of it:

| Finding | Cause | Change | Switch |
|---|---|---|---|
| Walking backwards on the far approach | Inside 50 studs the body was locked onto the target while the feet followed a path. Beyond that the game's lock-on leaves rotation camera-relative, and the bot's camera sits behind its own facing, so the facing never turned. Either way no sprint | The body faces the travel direction until within 14 studs of the target, and when fleeing with 10 studs of room | `TacFaceTravel` |
| Shuffling on the spot, up to 9 reversals a second | Two parts of the machine asking for opposite directions on alternate frames | A direction that reverses the last one must be asked for 0.2 s without a break before it is obeyed. The state and navigation mode that asked are counted | `TacMoveDamp` |
| "died out of the arena" on every death | The arena was a 1000-stud circle round the world origin. The 1.85 city is 1100 to 1700 studs from it, so the bot believed it was in a domain for whole lives and recorded no cell, route or death since the map changed | The arena is centred on `Workspace.Spawns` | n/a |
| Blocks of 0.0 s, repeating every 0.4 s | The decision that raised them was gone on the next frame | A raised block stays up at least 0.3 s. Nothing is cast or swung from behind it. Dodges and grab escapes are not delayed | `TacBlockKeep` |
| A third of chained casts refused, most at the instant our second hit began | Cast sent before the basic attack had landed | Chaining waits 0.14 s after our hit counter moves | `TacComboDelay` |
| Summons and resource moves refused over and over | They wait on something the client cannot see | Each refusal in a row doubles how long that move is left alone, up to eight times; a success resets it | n/a |

New in the `LIFE END` line:

```
| movement: backward 6% of travel; 14 reversals held off (mostly APPROACH/path x9); blocks kept up 11
```

`backward` should be near zero now; it was 60% on the far approach. `mostly
STATE/mode` names where the opposing directions come from, which is what to
fix at the source next.

## v87: knowing what the moves are

One v86 log (10 lives, 16 minutes) and the career memory behind it:

| Measure | v86 |
|---|---|
| Kills and deaths | 4 and 10 |
| Time spent stunned | 43% |
| Backward share of travel | 1% to 7%, was 60% |
| Raw casts that landed | 21% (38 of 177) |
| Casts chained off a confirmed hit | 4 of 5 landed, 5 in 16 minutes |
| Casts refused | 28% |
| Basic attacks that landed | 31% (49 of 160) |
| Blocks lasting 0.1 s or less | 62% |
| Counters that landed, career | 0 of 12 |
| Moves with 12 or more tries that land half the time | none |

Movement was fixed. Casting was not. The machine knew how far each move
reaches and nothing about what it is for, so it threw counters at people who
were not attacking, blockable moves into raised guards and everything at
bodies on the ground.

### What was researched

Five research passes over the game's wiki and guides produced 274 move
entries and 90 mechanics facts. The files are in `research/`, each entry with
its source. Every page fetch was refused by this session's network settings,
so all of it was read from search extracts, not from the pages. Treat it as
second-hand. That is why v87 also measures everything itself.

The mechanics that changed the design:

| Fact | Source | What the bot does with it |
|---|---|---|
| A basic string is four hits. Each landed hit stuns for about 0.75 s. The fourth puts the target on the ground and locks basic attacks for 2 s | wiki, Controls and Mechanics | The chain waits for three hits, then casts. It used to cast after one |
| Wiki combos read "3 M1s, skill, 3 M1s, skill, 4 M1s" | wiki, Sky Bender | Same |
| The fourth hit thrown while falling cannot be blocked and reaches a body on the ground. Thrown while rising it launches and keeps the target down longest | wiki, Controls and Mechanics. The game's own client sends "Down" when airborne and "Up" when jump is held | The fourth hit is chosen on purpose: see `TacFinisher` |
| A blocked basic attack costs the attacker double the recovery | wiki | No basic attacks into a raised guard |
| A guard covers 170 degrees in front. Hits from behind go through. Side dash then attack is the listed way | wiki, Techs | After a side dash, basic attacks are allowed for 0.9 s |
| Whether a move can be blocked and whether it reaches a body on the ground are tagged per move, not per kind of move | wiki, per-character pages | `MoveFacts`: 179 of the bot's 203 moves carry what the wiki says |
| Counters only do something if the user is hit inside a short window, 0.25 s to 1.1 s by move | wiki, per-character pages | Counters are thrown by the guard into a swing, never picked as an attack |
| Most specials do no damage: teleports, feints, marks, charges, stances | wiki, per-character pages | Specials re-classed. Feints are not thrown raw, teleports close gaps, charges wait for distance |
| Guides agree: do not throw skills raw, confirm them off basic attacks | games.gg, gamesving, bloxodes | Already the v85 principle. Now enforced by the measured chance to land |

### How a cast is judged

Every move has a family: melee, rush, projectile, beam, around-us, at-a-point,
grab, counter, pull, summon. The family comes from the research when there is
any, otherwise from the game's own files, otherwise from what the bot has seen
the move do.

The target is always in one of six states: free, blocking, stunned, on the
ground, mid-swing, in the air.

For each move and each state the bot keeps a belief about the chance to land.
The research is the starting belief, worth four casts. Researched block and
ground tags are worth seven. Every cast the bot makes is added on top, so
twelve measured casts outweigh the research three to one. The old career
totals went in as evidence about free targets, capped at eight casts.

A cast is withheld when that chance is below 20% (`KnowMinP`). Against the
real career memory, 9 of the 37 moves with six or more tries are now withheld
from a free target and still allowed on a stunned one.

### What changes

| Finding | Change | Switch |
|---|---|---|
| Counters thrown raw, 0 of 12 | Thrown only into a seen swing in reach, or on a predicted contact if the window is 0.6 s or longer. Never from behind a block that is already up | `KnowCounter` |
| Blockable moves into guards | Withheld. A move known to go through a guard is thrown on purpose | `Know` |
| Everything thrown at bodies on the ground | Withheld. A move known to reach the ground is thrown on purpose | `Know` |
| Basic attacks at guards and at bodies on the ground | Held. The swing counter and the 2 s lockout are kept for when they count | `KnowM1Hold` |
| Chain cast after the first hit | Waits for three. The neutral chooser no longer casts while a string is landing | `TacComboStep` |
| A random side step in the middle of a landing string | Not while a hit is confirmed | n/a |
| The fourth hit was whatever the feet happened to be doing | Chosen: falling, rising or flat. Each is tried four times, then the one with the best damage dealt minus taken over the next 4 s is used | `TacFinisher` |
| Specials thrown as attacks, 21% | Re-classed from the research | n/a |
| Blocks of one frame in the reacting state | The 0.3 s minimum now holds there too, except when dodging or grabbed | `TacBlockKeep` |
| Refusals counted for moves that start their cooldown late | A refused cast is looked at again 0.9 s later. A move seen starting late twice is judged at 1.3 s from then on | n/a |
| Moves that deal nothing by design marked as duds | Judged by whether the target ends up stunned or down | n/a |

### Probing

The bot checks its own knowledge on every run.

- Every cast is booked under the state the target was in when it was thrown.
- The time from cast to first damage is recorded. Six clean hits spread over
  a dozen studs give a least-squares line, delay = wind-up + distance / speed.
  That line replaces the default 140 studs/s when leading a target.
- Cooldowns are read from the game's own stamps and set against the listed ones.
- What a hit leaves behind is recorded: target held or target down. A move
  that mostly holds goes first in a chain, one that mostly floors goes last.
- How far a move carries us is recorded. A move with no research that carries
  us ten studs is treated as a rush.
- Up to three times a life, a move with no research and fewer than three tries
  in a state is thrown anyway. The log says `probe:` and `probe result:`.
- When measurements contradict the research the log says `research check:`.

### Reading the new lines

```
KNOW Rapid Punches: melee (researched, unblockable, misses the ground) | this life 2/3 | career free 3/9, stun 4/5, block 2/3 | lands 0.41 s after the cast | cooldown 15.2 s (listed 15) | after a hit: down 0, held 5 of 9
```

One line per move used in the life. `career` is hits over casts by target
state. A move with `free 1/10, stun 5/6` is a combo move, not an opener.

```
| knowledge: 14 casts withheld (mostly block x8), 2 probes, 1 counters, 3 guard-breaks, 2 ground hits, M1 held off 6s, finishers down x2 (net +9), up x1 (net -4), 1 refusals that were not
```

What to look for in the next log:

| Measure | v86 | Should become |
|---|---|---|
| Raw casts that landed | 21% | higher, on fewer casts |
| Chained casts | 5 in 16 minutes | several a life |
| Basic attacks that landed | 31% | higher |
| Counters | 0 of 12 | some landing, all booked under `swing` |
| Blocks of 0.1 s or less | 62% | well under half |
| Casts refused | 28% | lower once late starters are known |

## What is not known

- Whether a skill cast between two basic attacks is always accepted. If the
  refusal line shows `ctx=confirm` often, raise `TacComboGap`.
- Whether the server takes the fourth hit's direction from the client or
  works it out from our vertical speed. The bot does both: it is really in the
  air for the falling hit and really jumping for the rising one. The finisher
  counts in the log will show whether they differ.
- Whether the game lets us jump in the middle of a string. If it does not,
  the falling hit comes out flat and is booked as flat.
- Whether a counter thrown the instant a swing is seen is early enough for
  the 0.25 s windows.
- Held and two-press versions of moves. The bot taps. The research lists the
  held versions of Ultra Cannon, Piercing Blood, Blunt Cut, Earthquake and
  Granite Blast as stronger or unblockable, and Transcend as needing a second
  press. None of that is used yet.
- Real projectile speeds, until the bot has measured each one.
- The research is second-hand and about 100 days old for most pages. The
  `research check:` lines are how errors in it will show.

## Tests

`tools/test_tactics.py` runs the code against mocked game objects: 76 checks
on kinematics, prediction, lead, contact, chaining, travel facing, reversal
damping and the arena, and 112 on knowledge: families, target states, beliefs,
seeding, the gate, probes, the recorder, timing regression, counters,
guard-breaks, ground hits, held swings, the fourth hit and late cooldowns. It
needs Python with `lupa`:

```
python3 tools/test_tactics.py JJK_Solo_Bot.lua
```

`tools/gen_facts.py` rebuilds the `MoveFacts` table and the catalogue in the
reference from the JSON in `research/`.

The bot itself cannot be run here. Nothing above has been seen working in
Roblox yet.
