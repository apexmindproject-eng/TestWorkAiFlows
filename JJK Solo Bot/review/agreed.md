# Agreed build list (v92)

Nothing was run in the game. Every claim kept below was re-read in the code; the main counts were re-run on the v85 and v86 logs.

## Missed by all five

The fighter hardly swings. v86 `LIFE END` lines: 160 basic swings against 385 blocks in 974 s alive, more blocks than swings in 9 of 10 lives. Chaining needs three landed swings, so this caps everything v85 to v92 added. Items 1 and 2 are the two old rules that visibly cause it. Time per state is not logged, so nobody could size it; item 3 adds that.

## BUILD NOW

**1. No flanking on our own dry spells** (targeting 2; conflict d). `isTargetBlocking` 11274-11292: skip the timer rule unless `Config.FlankInferBlock` (default `false`). The rule is true whenever nothing landed for 2.5 s, so melee opens in FLANK with swings off (15300); it also books "turtle" (17192, 4228), which shortens its own window. Real signals (11257-11271) still flank. No conflict with v87: `knowBlocking` (7159) never used the timer. Name the detector in the flank line. Check: swings per minute above 10; flank lines per minute below 3.7 (both v86).

**2. Latch the reaction** (defence 1, 4; conflict a). 14849-14856: call `memBestReaction` once per target and move, reuse until unseen 0.5 s, re-pick when the move changes (keeps the v89 unblockable filter). REACT 15866-15957: while stunned or ragdolled, not holding a throwable, send no block or dash and book no reaction. `memReactStart` 4294: never restart a running watch. 15322: let the wake guard run its 0.5 s. `Config.ReactLatch = true`. Correction: do not skip the REACT branches while stunned; that reroutes through LEVEL, PERCHED and AWAKEN, which sit above CCED. The v86/v87 keep stays as a floor. Check: blocks of 0.1 s or less under 30% (was 62%; 195 of those 219 blocks were source-less REACT blocks).

**3. Measurement pack** (defence 3), log only, `Config.TacBlockProbe = true`. 9460: count `BlockService.Effects` on ourselves (absorbed) and own `Info.Block` within 0.2 s of `doBlock` (accepted). 2961: seconds per state. 11554: state pair at each reversal. Own health every 2 s under 50%. Flush count and worst ms. Share of our swings with `InSkill` true. The `hit taken` line names the gate that stopped a block. Check: `LIFE END` shows `blocks raised/accepted/absorbed` and `state s`.

**4. Straight-line approach** (mapping 1). 14999: no `StuckTime` accrual while stunned, ragdolled or in a skill. `stopWalking` 11646 calls `clearPath()` (`Bot.Path` is never read). `PathCommit` 1.5. `Config.PathLean = true`. Correction: `PathRefresh` stays 1.0; it also times failure counting (12234, 12313). Check: computes per minute under 10 (was 20); path-mode pacing lines with `los=true probe=false` (32 of 35) gone.

**5. Drop the resumed frame** (performance 1; conflict f). `Bot.FrameSeq` at 16961, `Bot.RunEpoch` in `startBot`/`stopBot`. `computePath` 11903: if the epoch changed, raise `STALE` before touching `PathBusy`. Wrap `navigateTo`: raise `STALE` if `FrameSeq` moved. 17228 ignores it and counts. `Config.FrameStaleGuard = true`. Chosen over mapping 2 because failure counting and blacklisting (12234-12378) stay untouched. Check: mocked yielding compute in `tools/test_tactics.py`; no `dashToward` after resume; `stale frames N` in `LIFE END`.

**6. Aim the learned dodge** (defence 5). At the latch, a "dodge" sets `Bot.ReactDir` sideways from the attacker toward the arena centre, the vector form of `tacEscapeDir` 8017. Today the v89 unblockable dodge uses the last projectile's direction or nothing (14806 is the only writer). `Config.ReactDodgeAim = true`. Check: test case; `dodge:` line with side.

**7. See the dash punch sooner** (defence 2). `senseSwingerNear` 13554, 13587: Chase names latch out to `Config.BlockChaseRange = 20` (0 = off) with facing dot 0.8 beyond 12 studs. 20, not 22: the slide is 20. Check: Chase latch distances reach 13 to 20 (14 of 22 sat at 10 to 12); absorbed count from item 3.

**8. Honest kills and deaths** (targeting 4). `setTarget` 14098 stores `Life.dmg`; 14578 and 15623 credit a kill only above `Config.KillCreditMin = 15`; 19958 books the death to `Bot.Aggressor` if it hit within 6 s. Keep the `Kill!` line text for `analyze_log.py`. Check: no kill with 0 dealt.

**9. Respawn resets**, no flag. `memLifeStart` 3030: clear `Threat`, `pending` casts, `ReactDir`, the reaction latch, `EscapeStep`, path points. Check: no `target:` pick citing threat in the first second of a life.

**10. Turn and run** (mapping 4; conflict c). `TacFaceFlee = 0`. Verified: inside 10 studs the body stays on the pursuer, the sprint cone (12576) fails, and 5 of 10 v86 RETREAT samples read a negative cone at walk speed 13.7 or less. The v91 lesson concerns things aimed at the target; RETREAT swings nothing and 6863 already yields to casts. Check: RETREAT `sprint:` lines show `want=true`.

**11. Seeds** (learning F1, part). `knowSeed` 7200 skips `Know.P2` moves and summon, trap and point families: old builds only tapped the first, and the 0.9 s window may close before the others land. Do it before the first v87+ run saves seeds. `Config.KnowSeedSkip = true`. Check: harness shows no seeded entry for Transcend.

**12. Shrink early weights** (learning F4). In `memMoveWeight` 4140 only: pull `norm` toward 0.5 with `Config.MemShrinkTries = 6`. Check: test, no weight 0.55 under 8 tries.

## BUILD WITH CHANGES

- **Targeting 1** (conflict g). The logs show health rising: 21 to 25% in 5.8 s, 19 to 21% in 16.6 s, 33 to 34% in 0.4 s; the reference only says a server `Health` script exists. So regeneration is real but slow. Build the latch only after an "escaped" line (17151): no new target beyond 30 studs unless it hits us, IDLE walks away from `SeekChar`, until 40% or 20 s. `Config.RecoverHold = true`. Do not stretch RETREAT to 45%. Check: a `recover:` line giving health gained per second, which settles the rate.
- **Learning F1 + F2** (conflict e): one change, never apart. First book in shadow: log what the longer window and the swing subtraction would have recorded, change no belief.
- **Defence 3**, punish only after an absorb: after item 3 proves the signal fires for us.
- **Performance 2**: after item 3 shows flush ms.

## LEAVE FOR NOW

- **Mapping 3** (conflict b): the damper is a v86 suspect and the reviewer could not name the state pair. Needs item 3's pairs showing one pair above half, and a v91 log with raw casts back above 21%.
- **Targeting 5**: needs absorbed blocks above half of swing-met blocks. It also contradicts item 10.
- **Targeting 3**: needs `rematch.py` on a log with item 8's booking.
- **Learning F3**: after F1 + F2; needs a test showing chained damage rises.
- **Learning F5**: needs a kit effect at p below 0.05.
- **Mapping 5, performance 3, 4, 5**: no effect on winning; needs script time above 4 ms a frame.
- **Performance 6**: needs one swallowed error in a log.
- **Dead branch 15719**: leave dead; fixing it adds a 1.2 s FLANK after every punish dash.
- **`DefendDropRest` 15132**: needs hits within 3 s of "DEFEND dropped: punishing".
- **Other small bugs** (targeting 6, mapping 6, learning F6; defence 4's stun cost and family pooling): each needs one logged occurrence, or a memory replay for pooling.

## DISAGREEMENTS

- Defence 1: gate the sends, not the branches (item 2).
- Mapping 2: `task.spawn` rewrites blacklist accounting; `STALE` does not.
- Mapping 1: `PathRefresh` 2.5 would slow blacklisting 2.5 times.
- Mapping 3: extends an unproven v86 change.
- Targeting 1: from the first low frame it costs fights; after an escape it costs at most 20 s.
- Targeting 5 against mapping 4: cannot both hold; running wins until blocks are shown to absorb.
- Learning F3 against F4: same number; F4 is three lines, F3 changes every chooser.
- Learning F1 alone: item 1 raises swing damage, which a 2.6 s window would credit to casts.

## ORDER OF WORK

1. `isTargetBlocking`, 2961, LIFE END text: items 1, 3.
2. `updateState` 14849, REACT 15866, 15322, `memReactStart`, `senseInit`, `senseSwingerNear`: items 2, 6, 7.
3. Frame handler, `computePath`, `navigateTo`, `stopWalking`, 14999: items 4, 5.
4. `setTarget`, `updateTarget`, `onDeath`, `memLifeStart`: items 8, 9.
5. Config and learning: items 10, 11, 12.
6. `tools/test_tactics.py` cases and `analyze_log.py` fields for every new line.
