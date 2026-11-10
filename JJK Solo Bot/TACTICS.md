# Tactics layer (v85 to v93)

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

## v88: the second press

Some moves are two presses. Tapped once they do nothing, and the bot only
ever tapped. The career memory has Transcend at 0 of 6.

The wiki says which moves, and the game's own controllers say where the
second press belongs:

| Move | Cue in the game files | What the bot does |
|---|---|---|
| Transcend | `TranscendService` Effects `Startup`: the user crouches | Presses again after the cue. Without it the user just stands up |
| Rupture | `RuptureService` Effects `SkillCheck`: flashes `Utils.Toji.ISOHUseTwice` on the blade for 0.5 s | Presses again inside the flash. A missed check makes the target block and push us away |
| Littering | `ReggieService` Effects `LitteringLand` hands over the receipt part | Waits until the target is within 10 studs of the receipt, then presses. After 5 s it presses anyway |
| Drone Strike | `DroneStrikeService` Effects `Aim` hands over a value and a remote | Steers the aim mark onto the target with the move vector, then presses. If steering makes the gap grow it turns the axes round |

How long after the cue to press is not written anywhere. Transcend and
Rupture each have three delays to try. Each is tried three times, then the
one that dealt the most damage is kept. The `KNOW` line shows the standing:

```
KNOW Transcend: rush (researched, unblockable, hits the ground) | ... | second press at 0.20 s: 4.0 dmg x3, 0.35 s: 12.0 dmg x3
```

The `LIFE END` line gains `second presses 4 of 5 (1 lost to a stun)`.

These moves are also given 1.4 s before a cast is judged refused, 2.8 s for
Drone Strike, because their cooldown starts when the move finishes.

Switch: `KnowSecondPress`. The session log line `second press: Transcend
hooked, Rupture hooked, Reggie hooked, DroneStrike hooked` says whether the
cues can be heard. Where one reads `absent` the bot presses blind.

## v89: how hits get in

Where the stun time in the v86 log came from:

| Source | Share |
|---|---|
| Enemy basic attacks | 47% |
| Not identified | 18% |
| Front-dash punches | 12% |
| Our own recovery after a cast | 7% |
| Skills | 16% |

Basic attacks and dash punches can all be blocked from the front. So the
question is not which move hit us but what we were doing when it did. The
log could not say. Now it can.

| Change | What it does | Switch |
|---|---|---|
| Hit ledger | Every hit that stuns us is written down with what we were doing: mid-swing, after a cast, closing in, block just dropped, through a raised block, hit from behind a block, just got up | `TacLedger` |
| Getting up, ours | The wiki says a player who gets up cannot be stunned by melee for half a second. For that half second the bot swings instead of blocking | `TacWake` |
| Getting up, theirs | For their half second the bot does not swing, guards their first attack and takes the turn. A new target state, `wake`, keeps melee casts out of that window | `TacWake` |
| Unblockable moves | The 59 moves the wiki lists as unblockable are now dodged, not blocked. Before, only 8 were known, and a move with no reaction history was blocked whatever it was | n/a |
| Awakening | It heals. Spent the moment the bar fills, the heal lands on full health. Now it waits for 70% health or less, a target that cannot answer, or 15 s with a full bar | `TacAwaken` |
| Domains | 1.25 s of hand signs that any hit cancels. Opened only with the target down or 22 studs off | `Know` |
| Held versions | Ultra Cannon, Blunt Cut, Earthquake and Granite Blast are different moves if the key is let go late. The bot always let go at once. Now it holds when the target is 14 studs off or on the ground, and keeps whichever of tap and hold has dealt more | `KnowHold` |
| After the fourth swing | 11 of 50 refused casts were sent right after it. No cast for 0.35 s | `TacCastGate` |
| Escape attempts | 95 tries, 19 escapes. A try made with no escape on offer locked out the next real one for 2 s. It now locks for 0.35 s, and does not start the after-escape routine | n/a |

New in the log:

```
hit taken: Todo:Melee1 from 5 studs, front | we were mid-swing (ATTACK)
| hits that got in: 14 (mid-swing 6, after a cast 3, closing in 2, block just dropped 2) | wake-up: swung through 2, guarded theirs 3, stunned while immune 0 | held casts 1, awakening waited 9s
```

How to read it next time:

- `mid-swing` high: we lose trades. Block the first swing more, swing less.
- `after a cast` high: raw casts are still being punished.
- `closing in` high: the approach is the problem, not the fight.
- `through a raised block` high: unblockable moves, or the block is late on the server.
- `block up, hit from behind` high: facing the wrong enemy while guarding.
- `stunned while immune` above zero: the wake-up research is wrong. The log also prints a `research check:` line.

## v90: openers, targets, tools

| Change | Why | Switch |
|---|---|---|
| Open with the front-dash punch | It is 12% of the stuns we take and the way opponents start strings on us. The bot only used it to run down somebody fleeing. It now opens with it from 11 to 18 studs: inside half the slide the punch knocks down, which starts nothing. Never into a guard, at a body on the ground or at somebody getting up | `TacDashOpen` |
| The dash request now carries its direction | The 1.85 client sends `Chase(airborne, "Front")`. The bot sent one argument | n/a |
| Awakened enemies are worth less as targets | An awakened moveset deals two to five times the damage of a base one. While we are in base form the score of an awakened enemy drops by 16, about half of what being attacked by them adds | `TacAwakeWeight` |
| Escapes go to the side | 64 of 95 escape tries went straight back, along the line of the attacker's next dash. They now go sideways, toward the middle of the arena | `TacEscapeSide` |

The life line gains `dash punches 4 (3 landed) | took 180 dmg`. Damage taken
was not in the line before, so damage dealt for each 1 taken can now be read
from one line.

Two tools were added for the next round:

- `tools/analyze_log.py <log>` prints the tables in this file from a log:
  kills and deaths, hit rates by kind of cast, where stun time came from, what
  we were doing when hits got in, refusals by move, finishers, second presses,
  every `KNOW` line. The test suite checks that the line the bot writes is the
  line the tool reads.
- `tools/lint_globals.py <script>` lists names the script reads but never
  defines. On 19,900 lines it finds two, both guarded executor functions.
  No call to a function that does not exist.

## v91: a regression found, and the reach of a basic attack

Putting the v85 and v86 logs side by side with the new analyser:

| Measure | v85 | v86 |
|---|---|---|
| Lives, minutes | 18, 38 | 10, 16 |
| Kills per life | 0.83 | 0.40 |
| Damage per second | 1.20 | 0.90 |
| Raw casts that landed | 32% | 21% |
| Basic attacks that landed | 44% | 31% |
| Backward share of travel | 60% on the far approach | 4% |

v86 fixed the walking and made the fighting worse. Ten lives is a small
sample and casts within one life are not independent, so this is not proof.
But both drops are large, about 2.6 and 3.0 standard errors if every cast is
counted on its own, and v86 contains a cause. It made the body face the way the feet go while covering ground.
Before it, the body was always on the target inside 50 studs, so every cast
left toward the target. After it, a cast thrown on the approach left along
the path. The lead-aim turned the body only for moving targets and long
moves.

| Change | What it does | Switch |
|---|---|---|
| Face what is thrown at | Every cast turns the body onto the target at once, and the body stays on the target for 0.6 s instead of swinging back to the path. This holds at any range | `TacFaceCast` |
| Swing facing the target | On the approach the body is snapped onto the target as the swing starts | n/a |
| Swing only in reach | On the approach the bot swung from 11 studs. A swing at air still moves the string along, so the fourth hit and its 2 s lockout were often spent before contact. It now swings inside the reach plus one stud, or when the gap will have closed in 0.2 s | `TacM1Slack` |
| Measure the reach | Every swing is booked by the distance it was thrown from and whether damage followed. The reach is the furthest 2-stud band where one swing in four still lands, once that band has eight swings. Until then it is 7 studs | `TacM1Probe` |
| Strings are not four hits for everybody | The research lists True Cannon's string as three hits and Head of the Hei's last hit as having no slam or launcher. Chaining, the last-hit choice and the after-string pause now ask how long this character's string is | n/a |
| Session line | After every life: kills, lives, damage dealt for each 1 taken, time stunned, and whether the life just ended was better or worse than the session before it | n/a |

New in the log:

```
SESSION: 3 kills, 5 lives in 9 min | dealt 1.12 for each 1 taken (this life 1.40) | stunned 34% of the time (this life 28%) | this life better than the session before it
| swings by distance: 2-4 10/10, 4-6 6/10, 6-8 1/10, 10-12 0/10; reach taken as 6 studs (measured) | casts turned onto the target 5 of 12
```

`casts turned onto the target 5 of 12` means five of twelve casts would have
left more than 30 degrees off the target without the turn. If that number is
high and raw casts land more often than 21%, the regression is confirmed and
fixed.

`tools/analyze_log.py old.txt new.txt` prints the before-and-after table.

v92 is v91 plus one guard on the chain. Waiting for three basic hits made
sense only while our own swings were still coming. If the string has not
moved for 0.6 s, because somebody else caused the stun or our swings are
locked out, the chain casts at once as it did before v87.

## v93: the older code, reviewed

Five reviewers each read one older subsystem against the real logs: target
choice and the state machine, mapping and navigation, defence and reactions,
the learning memory, and performance. A sixth then argued with all five,
re-checked their main claims in the code, ruled on where they collided with
each other or with v85 to v92, and returned one build list. All six reports
are in `review/`. `review/agreed.md` is the list.

What the challenger found that the five had missed:

| Measure, v86 log | Value |
|---|---|
| Basic swings thrown | 160 |
| Blocks raised | 385 |
| Lives with more blocks than swings | 9 of 10 |

The fighter hardly swings. Chaining needs three landed swings, so that caps
everything v85 to v92 added. Two old rules cause most of it and both are
fixed first.

| Built | What was wrong | Switch |
|---|---|---|
| No flanking on our own dry spells | "No damage for 2.5 s" counted as the target blocking. After an approach or a stun that is already true, so melee opened with swings off. 210 flank lines in 54 minutes; in about half the target was attacking | `FlankInferBlock` |
| One reaction per sighting | The reaction to an enemy skill was drawn afresh every frame, at random where a move had under 3 samples. Block went up one frame and down the next. 195 of the 219 blocks of 0.1 s or less came from this | `ReactLatch` |
| Nothing sent while stunned | Blocks and dashes were requested while down, refused, and still cost their rest timers | `ReactLatch` |
| A learned dodge has a direction | It used the last projectile's escape direction, or none | `ReactDodgeAim` |
| The dash punch is seen from 20 studs | It was looked for inside 12. Its slide is 20. 14 of 22 were first seen at the edge | `BlockChaseRange` |
| Routes only when something is in the way | The stuck timer ran while stunned or casting, which sent the next approach round by waypoints. 20 route calculations a minute, 32 of 35 with the target in plain sight | `PathLean` |
| A frame that wakes up late stops | A route calculation parks its frame for 0.28 s on average. The woken frame fired dashes and swings on old distances, and could restart movement with the bot off | `FrameStaleGuard` |
| Honest kills and deaths | Any target death was our kill, 5 of 19 within 5 s of picking the target. Deaths were booked to the target, which is nobody after an escape | `KillCredit` |
| Clean start to a life | The killer kept its full threat score into the next life. Pending casts, the reaction and the route also survived | n/a |
| Turn and run at once | Retreat kept the body on the pursuer inside 10 studs, at walking pace. Half of all deaths were failed retreats one or two cells away | `TacFaceFlee` |
| Recover after an escape | 8 of 9 escapes picked a new target within a quarter second, and all 11 lives that dropped under 25% health died, 20 s later at the median. Now no new fight is picked until 40% health or 20 s, unless somebody is within 30 studs or hitting us | `RecoverHold` |
| Old totals are not evidence for slow moves | Damage landing more than 0.9 s after a cast was never credited, so summons and multi-hit moves were scored as misses, and v87 seeded its beliefs from those scores. Summons, traps, placed moves and two-press moves are no longer seeded, and a seeded belief can now be re-tested | `KnowSeedSkip` |
| Steadier early weights | A move that lands 27% of the time shows 0 of 3 four times in ten, and was then ranked below a move never tried. A weight is pulled toward the middle until the move has 6 casts | `MemShrinkTries` |

Measurement added, so the next log can settle what this one could not:

```
| probe: blocks raised/accepted/absorbed 40/31/12 (accepted after 85 ms); state s ATTACK 31.0, APPROACH 22.4, ...; reversals between ATTACK>DEFEND x9, ...; swings in a skill 3 of 44; log flushes 12 (worst 9 ms) | path: 2 of 9 computes with the target in sight; stale frames 4; reactions latched 17
health: 23% | RETREAT | target Name 61% at 14 studs
hit taken: ... | block stopped by the 0.3 s rest after the last block, 0.12 s before
recover hold over: 20 s, health 22% to 36% (+0.70% a second)
```

How to read it:

- `raised/accepted/absorbed`: if accepted is far below raised, blocks are
  being refused. If absorbed is far below accepted, they are late or aimed
  wrong. This is the first direct measure of whether blocking works.
- `swings in a skill`: if most swings show it, the game marks us as busy
  while we attack and the swing sensor is blind exactly then.
- `state s`: where each life is spent. Swings per minute should rise well
  above the 10 of v86.
- `block stopped by`: names the timer or rule that kept a block from going up.

Left for the next log, each with the evidence that would settle it: extending
the reversal damper across states, blocking at low health, a stronger matchup
penalty, making the knowledge layer the only judge of a move, a wider credit
window, and character choice by results. `review/agreed.md` lists the
evidence each one needs.

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
- How long each held move must be held. The bot uses 1.4 s for Ultra Cannon,
  where 1.3 s is listed, and a guess for the other three. The tap and hold
  figures on the `KNOW` line show whether the hold did anything.
- Piercing Blood's held version. It needs a Convergence orb, which the bot
  does not track.
- Whether awakening can be started while stunned. The bot tries.
- Other two-press moves. Only the four in the v88 table are handled. The wiki
  says a second press during some wind-ups swaps the move for a weaker
  variant, so the second press is not sent anywhere it is not known to help.
- The right delay for each second press, until the bot has tried them.
- Whether the server moves the Drone Strike aim mark in the caster's own
  axes. The bot assumes so and reverses if the gap grows.
- Real projectile speeds, until the bot has measured each one.
- The research is second-hand and about 100 days old for most pages. The
  `research check:` lines are how errors in it will show.

## Tests

`tools/test_tactics.py` runs the code against mocked game objects: 76 checks
on kinematics, prediction, lead, contact, chaining, travel facing, reversal
damping and the arena, and 297 on knowledge and fight sense: families, target states, beliefs,
seeding, the gate, probes, the recorder, timing regression, counters,
guard-breaks, ground hits, held swings, the fourth hit, late cooldowns,
second presses, the hit ledger, getting up, awakening, domains, held
versions, dash openers, escape direction, string lengths, the session line
the measured reach of a basic attack, and the v93 review items: the reaction
latch, dodge direction, dash-punch range, late frames, kill credit, respawn
resets, the recover hold and seeding. It
needs Python with `lupa`:

```
python3 tools/test_tactics.py JJK_Solo_Bot.lua
```

`tools/gen_facts.py` rebuilds the `MoveFacts` table and the catalogue in the
reference from the JSON in `research/`.

The bot itself cannot be run here. Nothing above has been seen working in
Roblox yet.
