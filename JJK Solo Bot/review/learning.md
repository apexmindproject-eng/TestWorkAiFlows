# Learning memory review

## 1. How it works
- `memRecordUse` (3610) queues a cast with the target's HP. After 0.9 s `memResolve` (3727) books the HP lost as its damage (hit: over 0.5; weight: 1/(players within 25 studs + 1)) into `MEM.global.moves`, chains and ranges. `knowBook` (7403) books it into `MEM.facts` by target state.
- Choosers multiply `memMoveWeight` (0.55 to 1.45, damage per try against the kit's best) by `memChainWeight` and `knowWeight` (0.3 to 2.4). `knowGate` withholds under 20%.
- `memLifeEnd` (3281) adds life damage to `MEM.chars`; `autoPickChar` (17450) picks the next kit.
- Newest file: 706 casts over 106 moves, 31 lives. Median 5 casts a move; 4 moves have 20, 1 has 40.

## 2. Findings

**F1. Damage later than 0.9 s after a cast is never credited, in either layer.**
- Evidence: line 3740 compares damage with the previous frame, so a cast resolves on the first quiet frame; `MemCreditMax` (2.6) never applies. The script's own functions run offline under mocks (`/tmp/claude-0/-home-user-TestWorkAiFlows/81564497-591f-51e4-8b1c-557807f81542/scratchpad/learn_scripts/harness.py`): four 5-damage hits at 0.3 to 1.5 s book 10 of 20; a 30-damage hit at 1.2 s books a miss in both tables. `knowSeed` run on the file withholds 8 moves from free targets, including Megumi's 3 summons and both two-press moves the old build only tapped. Seeded beliefs count 4 or more casts and probes need under 3 (7273), so they are never re-measured.
- Change: set `p.seenAt` when damage grows. Resolve at `MemCreditMax`, or after `MemCreditWindow` once `now-p.seenAt>=MemCreditQuiet` (0.5; 0 restores today). Summon, trap, aoe_point and `Know.P2` moves wait `MemCreditMax`; `knowSeed` skips them; probes ignore seeded counts. Effect: slow and multi-hit moves stop being withheld on false evidence. Risk: longer windows admit foreign damage (F2). Check: the harness books 20 and 30; `KNOW` landing times above 0.9 s.

**F2. A "hit" is any HP loss on the target.**
- Evidence: the counters read 532 clean, 174 shared, 6 dirty, but clean only means no third player nearby. Specials the script now classes as utility or avoid (132 casts) book hits 21% of the time; melee, rush and projectile 37%. Roughly half of booked hits may be background (estimate). Two casts in flight each book the whole drop: Bird Control and Murmurate both show 30.98 damage. Shared casts add a fraction of a hit but a whole try.
- Change (`MemM1Subtract`): in `knowScan`, add `Bot.FrameDmgOut` to `p.m1` when a basic swing started after `p.at` and under 0.4 s ago; subtract it in `memResolve`, `knowWatch`, `knowBook`. A new cast sets `q.cut=hp0` on older pendings for that target. `bumpMove` adds `w` to tries. Effect: buffs and feints stop looking like attacks. Risk: under-credits a skill landing with a swing. Check: those specials fall toward 0 hits.

**F3. The layers double-count, and each vetoes alone.**
- Where: `tryUseSkill` 13492, `useBestMove` 12864, `tacComboExtend` 12936 and `knowTryState` 13241 multiply the old weight (raw hit rate x damage) by the new hit chance. Hard duds are dropped at 12842, 12927, 13457. `trySpecial` (198 of 706 casts) uses the old layer only.
- Evidence: on a stunned target `knowWeight` is 2.0 to 2.4 for every family, so the chain pick rests on raw-cast history; against chance-on-stun x listed damage it differs in 9 of 18 kits. Neither file holds a hard dud, so that conflict is latent; today's veto is the new gate (F1).
- Change (`KnowAuthoritative`): `memMoveWeight` returns `clamp(dph/10, 0.6, 1.6)`, `dph=(g.dmg+3*(listed or 8))/(g.hits+3)`; `memIsDud` returns false except for `SPECIAL:` keys. No data is dropped. Effect: about 3.6 more damage per chained cast where the pick changes. Risk: listed damage is second-hand. Check: `tools/test_tactics.py` stubs every `mem*` function; add cases.

**F4. Weights are trusted from 3 casts.**
- Evidence: a 27% move shows 0 of 3 with probability 39%; it then sits at 0.55, below an untried move's 1.18. The order is not noise: between the two independent files (77 and 31 lives) the within-kit order of damage per try agrees in 43 of 53 pairs.
- Change: `dpt=(dmg+k*kitMean)/(tries+k)` in `memMoveStats`, `MemShrinkTries=6`. Risk: low. Check: nothing at 0.55 under 8 tries.

**F5. Character choice is a blind rotation; kit scores are noise.**
- Evidence: all 29 switches in the v85 and v86 logs say "untried": each kit needs 3 lives (60; the file has 31), and the current and last 4 kits are barred. Afterwards the best kit gets about 8% against 5.6% uniform. Pooled life logs (89 lives, 20 kits): no kit effect on damage per life (permutation p=0.36). `KitLifeCap` booked Itadori's 198 life as 68.
- Change (`CharBandit`): `CharMinLives=1`, `CharNoRepeat=2`; pick the largest `m+gauss()*0.9*avg/sqrt(lives+1)`, `m=(fdmg+avg)/(lives+1)`. Effect: none provable now; every kit stays in play and a real difference can show. Check: reasons other than "untried".

**F6. Bugs.**
- `pun` (3234), `fdmg` and opponent `movesets` are saved, never read. `pun` counts 489 stuns within 1.5 s of 508 casts.
- `pending` survives `memLifeStart`: a last cast is booked after respawn.
- Refused casts verified after 0.9 s (7484) stay booked as misses.
- `recentFix` duplicated lives in 15 of 18 kits. Discounted lives add damage but no life (3314).
- No counter decays.

## 3. Sound
Load/save symmetry, pruning at 150 opponents, string bucket keys, division guards, save cost (under 20 ms).

## 4. Not determined
Whether summon damage really lands after 0.9 s. How background splits between basic attacks, summons and bystanders. Whether kits truly differ. Any effect in the game: nothing was run there.
