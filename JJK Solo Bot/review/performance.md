# Performance review: JJK_Solo_Bot.lua

7 logs, 53 lives; nothing was run in the game.

## 1. Loops
- Main loop: one `RunService.Heartbeat` connection (16959), body in `pcall`, unthrottled. Order: per-player sense pass, learning, threat, map, `updateState`, `memSave`, `executeState` (remotes leave here), movement, `tickM1`, `tickDash`, `logFlush`.
- Others: body lock on Heartbeat (12489), mover on `BindToRenderStep` (11586), a 0.2 s watchdog loop (18299). HUD: body aura on RenderStepped (19228), bars every 0.1 s (19082), eye and edge aura on timed tweens; GPU cost unmeasured.
- Throttles: hazard 0.07 s, ranking 0.15 s, debris 0.5 s; swing sensing has none. Script cost: 2.09 ms per frame at 51 fps.
- **Q1.** Swing start to block request: one Heartbeat interval (17 to 23 ms) plus the work before `doBlock` (2 ms, worst 8 to 24): 25 ms normally, 45 ms on a heavy frame, the whole frame on each life's worst one (median 98 ms). The 0.2 s loop is not involved. Deliberate waits: 0.3 s after a block release, 0.15 s with no target.

## 2. Findings

**1. A path compute suspends the frame; the resumed frame acts on old state.**
`ComputeAsync` (11900) yields in the frame thread: 2,192 computes, 8.1% of life time suspended. On resume the frame (a) finishes `navigateTo`, whose `walkTo` calls `bindMover` even after `stopBot`, so the mover restarts with the bot off; (b) runs the code after the call with pre-yield `t, d, now`: `dashToward()` (16298), `useBestMove(t,"escape")` (16032); (c) repeats the loop tail (17206), `tickM1(dt)` included. A second compute in one frame (12278) likely explains the `cpu max` of 204 to 487 ms in 6 lives.
Other yields: only `doParkour` (8521), into game code, unknown. `InvokeServer` (420) is never called; `task.wait` and `WaitForChild` run in their own threads; `writefile` and `JSONEncode` block (1 to 14 ms), not yield.
Change: `Bot.FrameSeq += 1` at the top of the frame; `Bot.RunEpoch += 1` in `startBot` and `stopBot`. In `computePath`, `error(STALE, 0)` after the pcall if the epoch changed. Rename `navigateTo` to `navigateToInner`; the new `navigateTo` calls it and, if `FrameSeq` moved, sets `Bot.PathSec = 0` and raises `STALE`. The handler ignores `err == STALE`.
Risk: code after `navigateTo` waits one frame. Check: no `cpu max` above 30.

**2. File writes sit in front of the action.**
`debug()` flushes inline (304), rewriting the whole log (60 to 203 KB). Replaying the flush rule on the log timestamps, 17 to 20% of flushes fall inside a `debug()` call, up to 16 per session on the "DEFEND: …" line (13616), which precedes `doBlock`. `memSave(false)` (17194) runs before `executeState`: 3 to 17 ms. Flush cost is unmeasured; the memory file takes 1 to 14 ms.
Change: delete line 304; add `pcall(logFlush, false)` to the 0.2 s loop; move `memSave(false)` after `tickDash()`; `appendfile` only the new lines when it exists. Check: add `flush N (max ms)` to LIFE END.
Risk: `appendfile` varies by executor; fall back to the rewrite.

**3. Every player is validated twice a frame.**
`isValidTarget` runs for all players in the sense pass (17043) and again in `ffBuildCrowd` (13708). `sense` is 0.57 ms/frame; the second pass is an estimated 0.4 to 0.5 ms of `state` (0.65).
Change (about 0.5 ms/frame less): the sense pass fills `Bot.ValidHRP[char] = hrp`; `ffBuildCrowd` and the player loop of `rankTargets` read it.
Risk: a mid-frame blacklist shows one frame late. Check: `state` near 0.25.

**4. `pruneDebris` runs every frame.** `sweepDebris` calls it before its throttle (16471). Fit, 38 lives listing `move`: move = 0.32 + 0.00078 × touched ms/frame, so 0.16 to 0.39 ms at 200 to 500 parts. Change: delete line 16471; 16556 and the per-part connections remain. Risk: collision restored up to 0.5 s later. Check: `move` near 0.3.

**5. Same-frame recomputation.** `isSkillReady` (1803) rebuilds `getAvailableMoves()` per call; `shouldUseMove` (12709) and `shouldBlock` (13668) count enemies before knowing they need to; `playingTracks` (10261) is read up to five times a frame. `exec` reaches 0.55 ms/frame over a life. Change: cache the first and last per `FrameSeq` and character; count only in the escape and heavy branches, last at 13668. Risk: none.

**6. Quiet deaths.** (a) `startBot` sets `Config.Enabled = true` (16918) before connecting (16959); a throw between leaves no loop, and the watchdog only acts when `Enabled` is false. (b) `pcall(startBot)` (18311) and the other pcalls of the 0.2 s loop drop errors unlogged. No `ERROR` line exists in the logs: hypothetical. Change: stamp `Bot.LoopOkAt` after each good frame; restart when `Enabled`, alive and stale over 3 s; log swallowed errors through `debugEvery`.

## 3. Found sound
- **Q3.** No script-side growth: script time per frame is flat within sessions, per-character tables are weak-keyed, the log is capped, HUD bars are destroyed with their fighter.
- `tacTrack`, `tacM1Tick`, `knowScan`, `knowState`, `tacFinisher`: a few property reads each.
- **Q5.** Yes: `#game:GetDescendants()` at every life end (3385), 114,000 instances, inside a 40 to 80 ms log gap. The bot is dead then; log it every tenth life.

## 4. Could not determine
- Why fps falls within 5 of 6 sessions (v86: 53 to 47) while script time is flat: the CPU probe slows 15 to 34% in three, suggesting heat. Test a session with Aura and MordorBars off.
- Who retains dead enemy characters (154 after 44 min); not this script's tables.
- Each life's 58 to 137 ms worst frame: log its time and state.
