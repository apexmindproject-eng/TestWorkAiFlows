# Mapping and navigation review

Nothing was run in the game. Counts: v85 log (18 lives), v86 log (10 lives, 974 s alive).

## 1. How it works

- `mapObserve` (17178) books time, damage, crowding, deaths and links into 24-stud cells every frame.
- Three readers: idle roaming (14896), retreat direction (`pickOpenRetreat` 6246), a progress watchdog (`mapNavProgress`).
- States set `Bot.WalkGoal`; `moveStep` walks to it through `tacDampDir`; `tacTravelDir` turns the body to match.
- `navigateTo` walks straight unless sight is blocked, a 6-stud probe hits, or `StuckTime` reaches 0.5 s. Then it pathfinds for at least 3 s.
- `handleStuck` jumps, arcs or breaks a wall after 2 s.
- LEVEL paths to a target over 14 studs up or down; scoring drops such targets within 2.5 s.

## 2. Findings, ranked

**1. Paths are walked with nothing in the way, and recomputed every second.**
- Evidence: 330 computes in v86 (20 a minute), 844 in v85. 32 of 35 path-mode pacing lines read `los=true probe=false`. Nine of ten v86 lives name `APPROACH/path` or `APPROACH_FAR/path` as the top source of opposing directions.
- Causes: `StuckTime` (14999) accrues while stunned or casting, because CCED returns (15633) leaving `WalkGoal` set; that sets `blockedNow` (12201). A new path is asked for every `PathRefresh` (1.0 s) or 12 studs of goal movement (12225). `stopWalking` clears `Bot.Path`, which nothing reads, so old `PathPoints` are followed during the next compute.
- Change, flag `PathLean`: no accrual when `isStunned() or isRagdolled() or isInSkill()`; `stopWalking` calls `clearPath()`; `PathRefresh` 2.5; `PathCommit` 1.5.
- Effect: straighter closing, fewer hits on the way in. Risk: one extra compute at real corners. Check: computes per minute; add "computes with target in sight" to the life line.

**2. Each compute parks the frame that asked, which later finishes stale.**
- Evidence: `ComputeAsync` (11900) yields inside the Heartbeat handler. Average 277 ms, worst 1310 ms; a frame was parked for 91 s, 9% of v86.
- On resume (read from code) it runs `followPath` over newer goals, the APPROACH `dashToward()` with the old distance (16298), the LEVEL jump (15856), the RETREAT cast (16031), then `handleStuck` to `tickDash` a second time. After death or Stop, `walkTo` re-binds the mover and camera.
- Change, flag `PathAsync`: compute inside `task.spawn`; `navigateTo` treats "pending" like the `PathBusy` branch (12219); failure counting (12234 to 12378) reads a stored result next frame; drop the result if `Bot.PathEpoch` changed (bump in `stopBot`, `setTarget`).
- Effect: no stray dashes or goals. Risk: counting "pending" as failure would blacklist targets. Check: mocked yield test in `tools/test_tactics.py`.

**3. The reversal damper is bypassed where reversals happen.**
- Evidence: 0.55 reversals a second in v85, 0.61 in v86 with the damper. It held at least 58 events; 596 got through. `tacDampDir` (6886) resets on every state change and exempts REACT.
- 80 of 94 pacing lines follow a DEFEND of 0.1 s or less, or a burst escape, within 3.6 s (40% of all windows do).
- Pacing lines print the state three seconds later, not the cause. Of the 11 REACT lines, 7 are one step out and back (intended), 4 are jitter.
- Change, flag `TacMoveDampAcross`: drop `st == Bot.MoveHeldState`; exempt entering REACT and RETREAT only. Record state and mode at the reversal; print the top three.
- Effect: in a close fight the bot commits to one direction. Risk: 0.2 s late turning back. Check: `revs` per life.

**4. Retreat walks backwards.**
- Evidence: `tacTravelDir` (6868) turns the body only beyond 10 studs (`TacFaceFlee`); retreats start in melee. 5 of 10 RETREAT samples: body off travel, walk speed 13.7 or less against 19.7. Five of eleven retreats ended in death one or two cells away, half of all deaths.
- RETREAT never blocks, so facing buys nothing; casts turn the body themselves.
- Change: `TacFaceFlee = 0`. Effect: more retreats reach 30 studs. Risk: ten samples. Check: clean against failed escapes.

**5. Map memory changes almost nothing.**
- Evidence: idle 14 s of 1075 s, and seeking the nearest player comes first. Retreat 44 s. Saved map: 86 cells, median 6.5 s each, 17 of 80 KB.
- Never read: `links` (164), `Bot.CellClass`. Never true: `deaths >= 2` (0 cells, though the log says "marked HOT"); `blocked` (0 cells).
- `mapNavProgress` cannot fire: exact equality on a moving goal (6084); RETREAT re-aims every 1.2 s inside a 2.5 s window. `pickOpenRetreat` (6377) reads `blocked` by ray number, `mapNoteBlocked` writes `mapDirIndex`: 165 degrees apart.
- Change, flag `MapLinks = false` (skip 5280 to 5343); stop classifying every frame; fix or delete the watchdog. Do not build fight-quality or pinning on 6 s cells: walls need live rays.
- Effect on winning: none. Check: file size.

**6. Smaller bugs.**
- `if dashToward()` (15719): returns nothing, branch dead.
- LEVEL and PERCHED are tested before CCED (15144).
- "reversals held off" counts frames (6896).
- Not reset on respawn: `PathPoints`, `lastCellKey`, `EscapeStep`.

## 3. Sound

- Stuck handling: 6 events in 54 minutes, all "nothing in the way" (cause 1); none in v86.
- Debris pass-through, arena centring (10 of 10 deaths booked), backward travel 4%.
- Map CPU is never in the top three.

## 4. Not determined

- Which pair of states makes the jitter.
- The share of computes made with the target in sight.
- Which route is right in "new route reverses" (59 lines).
- Cornering against walls; time in LEVEL and PERCHED.
