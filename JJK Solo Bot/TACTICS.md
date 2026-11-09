# Tactics layer (v85)

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

## What is not known

- Whether a skill cast between two basic attacks is always accepted. If the
  refusal line shows `ctx=confirm` often, raise `TacComboGap`.
- Whether every move can hit a target that is stunned but airborne.
- Real projectile speeds. One default (140 studs/s) stands in for all of them;
  a per-move `speed` in `MoveRules` overrides it.
- Whether blocking refuses casts. It is reported, not gated.

## Tests

`tools/test_tactics.py` runs the kinematics, prediction, lead, contact, confirm
and chain-choice code against mocked game objects (46 checks). It needs
Python with `lupa`:

```
python3 tools/test_tactics.py JJK_Solo_Bot.lua
```
