# Defence and reactions review

Script v92; logs v85 and v86, so v87 onward is unmeasured. Nothing was run.

## 1. How it works

Each Heartbeat runs `updateState` (14687) then `executeState` (15314), so sensing and acting share a frame. Priority: grabbed, hazard dodge, REACT to the target's sensed skill, four positional states, CCED, DEFEND on a seen swing (`senseSwingerNear`: Melee or Chase animation, within 12 studs, facing us), DEFEND on predicted contact, PUNISH, then movement and ATTACK. The top of `executeState` drops a held block once the state stops wanting it.

Timing (Q2): animations are polled every frame and an ungated block leaves the same frame, at most 18 to 20 ms after the track reaches our client. `BlockCooldown` does not gate swing blocks.

## 2. Findings, ranked

**1. REACT re-picks its reaction every frame, even while we are stunned: the one-frame block (Q1, Q5).**
- Cause: `memBestReaction` is called per frame (14852). Any option under 3 samples gives a random pick (4411), otherwise an 8% retest roll (4436). One frame picks block (15906-15914), the next picks something else and 15322 releases it. REACT is tested above CCED (14811 vs 15180) and `doBlock` has no stun check. v87's 0.3 s keep exempts dodge and CCED, so the cause remains.
- Evidence, v86: 263 of 356 `DEFEND held` lines follow no `DEFEND:` or `guard:` line and count no swing; only REACT/block (v92 code) does that. 195 lasted 0.1 s or less, 89% of all such blocks. They come 0.4 s apart (83 of 145 gaps), matching the re-raise at 15913; five sit between the escape attempts at 90.00 and 92.00, while we were down. 198 retests against 112 judged reactions.
- Change (`ReactLatch`): pick once per sighting and keep it until the move is unseen for 0.5 s. Skip the hazard and threat branches, and `doBlock`, while stunned or ragdolled.
- Effect: about three quarters of block requests go, each with its 0.3 s no-hold rest (8875). Risk: carrying a throwable sets `Stun`; exclude it. Check: blocks of 0.1 s or less under 30%.

**2. A front-dash punch is only looked for inside 12 studs.**
- Evidence: the slide is 20 studs. 14 of 22 `Chase` latches (v85: 27 of 36) were first seen at 10 to 12 studs, the edge of `BlockMeleeRange`. At the logged 41 to 54 studs/s that loses 150 to 200 ms. The block lasted 0.2 s or less in 10 of 22. Dash punches are 12% of stuns.
- Change: `BlockChaseRange = 22` for Chase names at 13587 and 13554, with facing dot 0.8 or more beyond 12 studs.
- Risk: guarding a dash aimed elsewhere. Check: Chase latch distances reach 13 to 20.

**3. Nothing measures whether a block worked.**
- Evidence: `swings` counts animation names seen, and the counter window opens on it (8840). 22 of 81 swing-met blocks dropped within 0.15 s; punish casts landed 5 of 15.
- The game fires `BlockService.Effects` on an absorbed hit and adds `Info.Block` to a blocker (reference 669, 1795); the script ignores both for itself (9462).
- Change (`TacBlockProbe`): count accepted (`Info.Block` within 0.2 s) and absorbed in `LIFE END`; open `TacPunish` only after an absorb; name the gate that stopped a block in the `hit taken` line.
- Risk: assumes the signal fires for us too. Check: the counts show blocks late, refused or working.

**4. Reaction learning scores the wrong window and cannot converge (Q4).**
- Evidence: `memReactStart` resets `at` and `hp0` every frame (4296), so the score is HP lost in the 1.1 s after the reaction's last frame. Memory: 266.5 samples over 69 moves, median 2; 67 of 128 cells average zero; block 1.43, away 1.34, dodge 1.26 HP.
- Change: start once per latch; add `ReactStunCost = 14` when a stun starts in the window; book by family too (`"@rush"`) and use the family's best while a move is under-sampled (`ReactFamilyPool`).
- Effect: 18 cells to fill, not 200. Risk: families hide exceptions. Check: replay the JSON.

**5. A learned dodge has no direction.**
- Code only: `Bot.ReactDir` is set in the hazard branch alone (14806) and never cleared, even on respawn. A dodge chosen for a move (beams, unblockables since v89) follows the last projectile's escape vector, or does nothing, and is still booked as a dodge (15885-15897).
- Change (`ReactDodgeAim`): on latching dodge, set `ReactDir` sideways from the attacker as `tacEscapeDir` does. Check: a `test_tactics.py` case.

**6. Smaller faults.**
- 15132: each counter window ends in the 3 s `DefendDropRest`. The earliest latch after the 10 logged drops came at 3.41 s, but no knockdown followed within 3 s.
- 15719: `if dashToward() then` never passes; `dashToward` (8811) returns nothing.
- 16365: the wake-up guard asks 0.5 s; 15322 releases it at 0.3 s.

## 3. Examined and found sound

- Facing (Q3): the body lock turns to `DefendVs` (12451). Memory `enemyOpens` has 30 of 31 attributed hits from the front; 2 of 69 latches were on a non-target.
- Respawn: `stopBot` clears guard state; other timers expire.

## 4. Not determined

- Whether a same-frame block beats the first hit: wind-up and network delay are unknown.
- Whether `Info.InSkill.Value` is true during our own swings. If so, 13542, 12976 and 13631 blind the guard whenever we attack.
- Whether `dash()` moves us: `tickDash` looks under HumanoidRootPart, the reference (1785) says Torso.
- Time spent in REACT (not logged).
