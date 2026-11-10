# Target choice and state machine: review

Sources: v85 log (18 deaths), v86 log (10 deaths), saved memory, code. Nothing was run in the game.

## 1. How it works

- `updateTarget` (14262) rescores every 0.15 s. `scoreCandidate` (13717): hitting us 34, close 22, low health 20, reachable 16, facing us 10, minus crowd 18 and matchup 14; current target +14. A challenger needs 25% and 12 points more for 0.6 s.
- `updateState` (14687) order: DEAD, REACT (grab, hazard, target's move), IDLE, LEVEL, PERCHED, AWAKEN, THROW, CCED, recover, DEFEND, PUNISH, "retreat failed" PUNISH, RETREAT (ganged), RETREAT (health under 25%), APPROACH (stalling), CHASE, APPROACH_FAR, APPROACH, FLANK, DEFEND, ATTACK.
- Retreat starts at 25% health, or under 50% with two attackers while losing.

**Deaths (28):** 18 lost a 1v1 to its own target, 4 outnumbered, 4 after breaking away, then re-engaging or being caught, 1 to a third party, 1 unknown. 17 of 27 fully logged lives had no kill. Target choice is not the main killer; lost duels and low-health behaviour are.

## 2. Findings, ranked

**1. It escapes, then walks straight back in.**
Evidence: 9 "escaped" lines in 6 lives; 8 picked a new target within 0.25 s (17151 clears the target, 14622 takes the top score); death followed 10 to 62 s later every time. v85 life 16 "escaped" two bystanders 4 s apart, because RETREAT runs from `Bot.Target`, not from the hitter. v86 life 8 was in APPROACH six seconds after 19% health. 11 lives logged health under 25%; all died, median 20 s later.
Change (`Config.RecoverHold`): latch `Bot.LowLatch` under `RetreatHP`; clear at `ReengageHP = 45` or after 25 s. While latched, `updateTarget` keeps only candidates within 30 studs or `hitterLive`; line 15272 tests `hp < RetreatHP or Bot.LowLatch`; the IDLE branch (14896) walks `pickOpenRetreat` away from `Bot.SeekChar`.
Effect: the next fight starts near 45% health, not 20%. Risk: idle time; regeneration speed is unknown. Check: seconds from the first under-25% line to death.

**2. FLANK fires on our own dry spells.**
`isTargetBlocking` (11274 to 11292) calls a target "blocking" when our basic attack is on and its health has not dropped for 2.5 s. After an approach or stun that is already true, so melee starts in FLANK (attack off, up to 3 s), not ATTACK.
Evidence: 210 "Target blocking" lines in 54 minutes; in 109 the target itself was logged swinging or closing within 3 s. v86: 61 flank lines against 160 swings.
Change (`Config.FlankInferBlock = false`): drop the timer rule, or start its clock at melee contact and skip it while `senseMeleeSwing(t)`. Log which detector fired and flank seconds per life.
Effect: more strings started. Risk: swinging into real guards, which the v87 block state already covers. Which detector fires is not logged, so the share is a guess.

**3. Matchup memory is too weak and too late.**
`memMatchupPenalty` (4170) returns 0 until 300 damage is traded; weight 14. Evidence: 29 of 108 picks went to opponents already recorded as losing matchups; 10 of those picks ended in death (34%) against 8 of 52 for unknown opponents (15%). ZXCH_4RY (2 deaths, 26 dealt, 271 taken) still scores 0.
Change: `MatchupMinDmg = 100`; penalty at least 0.5 when deaths exceed kills and taken exceeds dealt; `W.matchup = 26`.
Risk: fewer targets. Check: rerun `/tmp/claude-0/-home-user-TestWorkAiFlows/81564497-591f-51e4-8b1c-557807f81542/scratchpad/review/tgt_tools/rematch.py`.

**4. Kills and deaths are booked wrongly.**
Any target death counts as our kill (14578, 15623): 5 of 19 came within 5 s of picking the target; keysontheboard is a kill with 0 damage dealt. Deaths go to `Bot.Target` (19958), which is nil after an escape: UhhhSmthGuh has 0 deaths after killing us.
Change (`Config.KillCredit`): store `Life.dmg` in `setTarget`; credit a kill only above 15 damage; book deaths to `Bot.Aggressor` if it hit within 6 s.
Effect: honest scores, correct input for finding 3.

**5. Under 25% it stops blocking and never turns.**
`canGuard` (15090) is false: 15 "not stopping to block" lines at low health. "Chased us 2.5 s - engaging them" (17141) only sets the aggressor; "retreat failed" fired once in 28 lives.
Change (`Config.DefendEnterUnderRetreat`): allow guard when the swinger is within 8 studs and facing; set `PunishUntil` in the chased block. This is a guess; compare low-health survival times.

**6. Smaller bugs, from reading.**
- `Threat` is never cleared on death, and the loop is stopped so it does not decay: the killer keeps up to +34 at respawn. Clear it in `memLifeStart`.
- A full bar blocks both RETREAT branches (15242, 15272) even when `canAwaken()` is false.
- A manual lock ends on the target's first invulnerable frame (14274).
- "Approach abandoned" adopts a hitter without a level check (16141), who is dropped a second later.
- LEVEL (AUTO) is only reachable during the 0.6 to 4 s off-level grace. TEAMKITE, BREAK and the leash are unreachable in solo.

## 3. Sound

Switching: 15 switches in 54 minutes, none from score flicker; 9 went to the player attacking it, who then killed it. Chase give-up never needed. Third-party deaths are rare.

## 4. Not determined

- Health at commit and the target's health: neither is logged, so "fight on or leave" at 25% cannot be settled.
- Whether "ganged" counts bystanders (damage is split among everyone within 45 studs).
- How often stalling forces APPROACH and skips the abandon check.
- How far away picked targets are: proximity and crowd terms are blind beyond 55 studs.
