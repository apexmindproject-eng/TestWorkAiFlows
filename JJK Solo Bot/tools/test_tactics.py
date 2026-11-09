import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding='utf-8').read()
a = src.index('Tac = { track = setmetatable'); b = src.index('local function getAimPoint()')
core = src[a:b]
a2 = src.index('function tacConfirmed(t)'); b2 = src.index('function trySpecial(t, d2d)')
combat = src[a2:b2]
MOCK = r'''
math.clamp = function(x, lo, hi) if x < lo then return lo elseif x > hi then return hi end return x end
local V = {}
V.__index = function(v, k)
    if k == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
    if k == "Unit" then local m = math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z); return Vector3.new(v.X/m, v.Y/m, v.Z/m) end
    return V[k]
end
V.__add = function(a, b) return Vector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
V.__sub = function(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
V.__mul = function(a, b) if type(a) == "number" then a, b = b, a end return Vector3.new(a.X*b, a.Y*b, a.Z*b) end
V.__div = function(a, b) return Vector3.new(a.X/b, a.Y/b, a.Z/b) end
function V:Dot(o) return self.X*o.X + self.Y*o.Y + self.Z*o.Z end
function V:Lerp(o, t) return Vector3.new(self.X + (o.X-self.X)*t, self.Y + (o.Y-self.Y)*t, self.Z + (o.Z-self.Z)*t) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end }
CLOCK = 100
function tick() return CLOCK end
Config = { TacLead = true, TacLeadSpeed = 140, TacLeadMax = 0.7, TacLeadDist = 16, TacGuard = true, UseBlock = true,
           TacGuardTTC = 0.38, TacGuardReach = 6.5, TacGuardSpeed = 12, TacGuardHold = 0.55, TacGuardRest = 1.4,
           TacCombo = true, TacComboStep = 2, TacComboGap = 0.25, CastRefusalHold = 2.5, MemCreditWindow = 1.2,
           TacComboDelay = 0.14, TacFaceTravel = true, TacFaceDist = 14, TacFaceFlee = 10, TacMoveDamp = true, TacMoveDampFor = 0.2 }
Bot = { HitCandidates = {}, LastSkill = 0 }
Life = { tac = {} }
MEM = {}
MoveRules = { ["Sky Distortion"] = { min = 15, max = 70, prio = 3, code = 1 }, ["Blind Rage"] = { min = 0, max = 28, prio = 5, code = 2, cc = true },
              ["Turbulence"] = { min = 0, max = 20, prio = 4, code = 7 }, ["Jab"] = { min = 0, max = 12, prio = 4 }, ["Nuke"] = { min = 0, max = 30, prio = 2, heavy = true } }
DefaultRule = { min = 0, max = 40, prio = 9, code = 0 }
FriendlyGeom = { SkyDistortion = { s = "lane", cast = 0.4 } }
function senseMoveKey(n) return (n:gsub("[^%w]", "")) end
LOG = {}
function debugEvery(_, _, msg) LOG[#LOG + 1] = msg end
ME = { Name = "me", Parent = true, HRP = { Position = Vector3.new(0, 0, 0), CFrame = { LookVector = Vector3.new(0, 0, -1) } }, attrs = {} }
function ME:GetAttribute(k) return self.attrs[k] end
function getChar() return ME end
function getHRP(c) c = c or ME; return c.HRP end
function isAlive(c) return not c.dead end
function isStunned(c) c = c or ME; return c.stun == true end
function isRagdolled(c) c = c or ME; return c.rag == true end
function hasIFrames(c) return c.iframes == true end
function isAllyName() return false end
function isInSkill() return ME.inSkill == true end
function inOwnMove() return ME.inSkill == true end
function getHPPct(c) return (c and c.hp) or 100 end
READY = {}
function isSkillReady(svc) return READY[svc] ~= false end
USABLE = {}
function getUsableMoves() return USABLE end
function memMaxDpt() return 1 end
function memMaxChain() return 1 end
function memMoveWeight() return 1 end
function memChainWeight(name) return (CHAINW and CHAINW[name]) or 1 end
function memIsHardDud() return false end
function moveRange(e) return e.rule.min, e.rule.max end
function verticalTolerance() return 10 end
CAST = {}
function useSkill(svc) CAST[#CAST + 1] = svc; Bot.LastSkill = tick(); return true end
function mkChar(name, x, z, lookX, lookZ)
    local c = { Name = name, Parent = true, HRP = { Position = Vector3.new(x, 0, z), CFrame = { LookVector = Vector3.new(lookX, 0, lookZ) } }, attrs = {} }
    function c:GetAttribute(k) return self.attrs[k] end
    return c
end
'''
# the file's useSkill / helpers are locals there; in the test they are the globals above
TESTS = r'''
local fails, n = {}, 0
local function check(name, cond, detail)
    n = n + 1
    if not cond then fails[#fails + 1] = name .. (detail and (" -> " .. tostring(detail)) or "") end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.05) end

-- 1. kinematics: 20 studs/s along +X for one second at 60 fps
local runner = mkChar("runner", 0, 30, 0, -1)
for i = 1, 60 do
    CLOCK = CLOCK + 1/60
    runner.HRP.Position = Vector3.new(20 * i / 60, 0, 30)
    tacTrack(runner, CLOCK)
end
local v = tacVelocity(runner)
check("velocity converges to 20 on X", near(v.X, 20, 0.6) and near(v.Z, 0, 0.3), string.format("%.2f,%.2f", v.X, v.Z))
-- a teleport must not read as speed
CLOCK = CLOCK + 1/60; runner.HRP.Position = Vector3.new(2000, 0, 30); tacTrack(runner, CLOCK)
CLOCK = CLOCK + 0.05; tacTrack(runner, CLOCK)
check("teleport is not velocity", tacVelocity(runner).Magnitude < 25, tacVelocity(runner).Magnitude)
-- stale track reads as standing still
CLOCK = CLOCK + 1; check("stale track is zero", tacVelocity(runner).Magnitude == 0)

-- 2. prediction
local mover = mkChar("mover", 0, 40, 0, -1)
for i = 1, 30 do CLOCK = CLOCK + 1/60; mover.HRP.Position = Vector3.new(20 * i / 60, 0, 40); tacTrack(mover, CLOCK) end
local p = tacPredict(mover, 0.5)
check("predict 0.5 s ahead is about +10 on X", near(p.X - mover.HRP.Position.X, 10, 0.8), p.X - mover.HRP.Position.X)
check("prediction stays level", p.Y == 0)
local fast = mkChar("fast", 0, 40, 0, -1)
for i = 1, 30 do CLOCK = CLOCK + 1/60; fast.HRP.Position = Vector3.new(90 * i / 60, 0, 40); tacTrack(fast, CLOCK) end
local pf = tacPredict(fast, 0.7)
check("lead distance is capped at 16", near((pf - fast.HRP.Position).Magnitude, 16, 0.01), (pf - fast.HRP.Position).Magnitude)
check("predict nil char", tacPredict(nil, 0.3) == nil)

-- 3. lead time
check("ranged with known wind-up: 0.4 + 42/140 = 0.7", near(tacLeadTime("Sky Distortion", 42), 0.70, 0.001), tacLeadTime("Sky Distortion", 42))
check("ranged, unknown wind-up at 28: 0.35 + 0.2", near(tacLeadTime("Blind Rage", 28), 0.55, 0.001), tacLeadTime("Blind Rage", 28))
check("melee: wind-up only", near(tacLeadTime("Jab", 6), 0.15, 0.001), tacLeadTime("Jab", 6))
check("unknown move uses the default rule", tacLeadTime("Nobody Knows", 30) > 0.3)
check("lead time capped", tacLeadTime("Sky Distortion", 400) == 0.7)
Config.TacLead = false; check("lead off -> 0", tacLeadTime("Sky Distortion", 42) == 0); Config.TacLead = true

-- 4. contact prediction
local function approach(c, fromZ, speed, frames)
    for i = 1, frames do CLOCK = CLOCK + 1/60; c.HRP.Position = Vector3.new(0, 0, fromZ - speed * i / 60); tacTrack(c, CLOCK) end
end
local att = mkChar("attacker", 0, 30, 0, -1)       -- north of us, looking south at us
Bot.HitCandidates = { att }
approach(att, 30, 22, 30)                            -- now at z = 19, closing at 22
check("far runner: no block yet (ttc 0.57)", tacIncoming() == false)
approach(att, 19, 22, 14)                            -- z about 13.9 -> ttc (13.9-6.5)/22 = 0.34
local z = att.HRP.Position.Z
local fired = tacIncoming()
check("runner in contact window: block up", fired == true, "z=" .. z)
check("guard target is the attacker", Bot.DefendVs == att and Bot.PreGuardVs == att)
check("life counter", Life.tacGuard == 1)
CLOCK = CLOCK + 0.2; check("window persists without a swing", tacIncoming() == true)
CLOCK = CLOCK + 0.5; check("window over: rest, no re-trigger", tacIncoming() == false)
CLOCK = CLOCK + 1.5
att.HRP.Position = Vector3.new(0, 0, 30); Tac.track[att] = nil
approach(att, 30, 22, 44)
att.stun = true; check("stunned attacker is no threat", tacIncoming() == false); att.stun = false
Bot.PreGuardRestUntil = 0
local away = mkChar("leaver", 0, 10, 0, 1)
Bot.HitCandidates = { away }
for i = 1, 30 do CLOCK = CLOCK + 1/60; away.HRP.Position = Vector3.new(0, 0, 10 + 22 * i / 60); tacTrack(away, CLOCK) end
check("someone running away is no threat", tacIncoming() == false)
local walker = mkChar("walker", 0, 20, 0, -1)
Bot.HitCandidates = { walker }
approach(walker, 20, 16, 26)                         -- z about 13.07 -> ttc 0.41
check("walker at 13 studs: not yet", tacIncoming() == false, walker.HRP.Position.Z)
approach(walker, walker.HRP.Position.Z, 16, 5)       -- z about 11.7 -> ttc 0.33
check("walker at 11.7 studs: block", tacIncoming() == true, walker.HRP.Position.Z)
Bot.PreGuardUntil, Bot.PreGuardRestUntil = 0, 0
local back = mkChar("backturned", 0, 12, 0, 1)       -- moving toward us but facing away (knocked back at us)
Bot.HitCandidates = { back }
for i = 1, 30 do CLOCK = CLOCK + 1/60; back.HRP.Position = Vector3.new(0, 0, 20 - 22 * i / 60); tacTrack(back, CLOCK) end
check("flying at us backwards is not an attack", tacIncoming() == false)
-- our own stunned target does not make us block
local tgt = mkChar("target", 0, 20, 0, -1)
Bot.HitCandidates = { tgt }; Bot.Target = tgt
approach(tgt, 20, 22, 20); tgt.stun = true
check("own stunned target is not guarded against", tacIncoming() == false)
tgt.stun = false
Config.TacGuard = false; check("guard off", tacIncoming() == false); Config.TacGuard = true

-- 5. confirm
local victim = mkChar("victim", 0, 5, 0, -1)
check("free target: not confirmed", tacConfirmed(victim) == false)
victim.stun = true; check("stunned: confirmed", tacConfirmed(victim) == true and Bot.ConfirmSince ~= nil)
victim.rag = true; check("ragdolled: not confirmed", tacConfirmed(victim) == false and Bot.ConfirmSince == nil); victim.rag = false
victim.iframes = true; check("i-frames: not confirmed", tacConfirmed(victim) == false); victim.iframes = false

-- 6. chain choice
USABLE = { { name = "Sky Distortion", service = "SkyDistortionService", rule = MoveRules["Sky Distortion"] },
           { name = "Jab", service = "JabService", rule = MoveRules["Jab"] },
           { name = "Blind Rage", service = "BlindRageService", rule = MoveRules["Blind Rage"] },
           { name = "Nuke", service = "NukeService", rule = MoveRules["Nuke"] } }
tacConfirmed(victim); CLOCK = CLOCK + 0.1
ME.attrs.CurrentM1 = 1; CAST = {}
check("string only on hit 1: wait", tacComboExtend(victim, 5) == false and #CAST == 0)
ME.attrs.CurrentM1 = 2
check("hit 2 confirmed: chain", tacComboExtend(victim, 5) == true and CAST[1] == "JabService", CAST[1])
check("counter + context", Life.tacCombo == 1 and Bot.CastCtx == "confirm")
check("no second cast inside the gap", tacComboExtend(victim, 5) == false)
CLOCK = CLOCK + 0.3; READY.JabService = false; CAST = {}
check("next best when the quick one is down: control", tacComboExtend(victim, 5) == true and CAST[1] == "BlindRageService", CAST[1])
CLOCK = CLOCK + 0.3; READY.BlindRageService = false; victim.hp = 30; CAST = {}
check("low target: the heavy finishes", tacComboExtend(victim, 5) == true and CAST[1] == "NukeService", CAST[1])
CLOCK = CLOCK + 0.3; READY = {}; CHAINW = { ["Blind Rage"] = 3 }; victim.hp = 100; CAST = {}
check("a learned chain outranks the default order", tacComboExtend(victim, 5) == true and CAST[1] == "BlindRageService", CAST[1])
CLOCK = CLOCK + 0.3; CHAINW = nil; CAST = {}
check("out of every range: nothing", tacComboExtend(victim, 200) == false and #CAST == 0)
ME.inSkill = true; check("mid-move: nothing", tacComboExtend(victim, 5) == false); ME.inSkill = false
ME.attrs.CurrentM1 = nil; CLOCK = CLOCK + 0.3; CAST = {}
check("no M1 counter on this character: still chains", tacComboExtend(victim, 5) == true)
ME.attrs.CurrentM1 = 1; Bot.ConfirmSince = CLOCK - 0.6; CLOCK = CLOCK + 0.3; CAST = {}
check("someone else's stun is taken after half a second", tacComboExtend(victim, 5) == true)

-- 7. bookkeeping
tacBook("confirm", true, 12); tacBook("confirm", false, 0); tacBook("neutral", false, 0)
check("career tally", MEM.tactics.confirm.n == 2 and MEM.tactics.confirm.h == 1 and MEM.tactics.confirm.d == 12 and MEM.tactics.neutral.n == 1)
check("life tally", Life.tac.confirm.n == 2 and Life.tac.neutral.h == 0)
Bot.M1Active = true; ME.attrs.CurrentM1 = 1; tacM1Tick(); ME.attrs.CurrentM1 = 2; tacM1Tick(); tacM1Tick()
Bot.FrameDmgOut = 4; Bot.LastSkill = CLOCK - 5; tacM1Tick(); Bot.FrameDmgOut = 0
check("M1 swings and hits", Life.m1Swings == 2 and Life.m1Hits == 1 and Life.m1Dmg == 4 and MEM.tactics.m1.n == 2 and MEM.tactics.m1.d == 4,
      string.format("%s %s %s", tostring(Life.m1Swings), tostring(Life.m1Hits), tostring(MEM.tactics.m1.n)))
Bot.FrameDmgOut = 9; Bot.LastSkill = CLOCK; tacM1Tick(); Bot.FrameDmgOut = 0
check("damage right after a skill is not booked to M1", Life.m1Dmg == 4)
-- 6b. a chained cast waits for the basic attack to land
READY = {}; CHAINW = nil; victim.hp = 100; victim.stun = true; victim.rag = false
tacConfirmed(victim); Bot.ConfirmSince = CLOCK - 0.2; Bot.LastSkill = CLOCK - 5
ME.attrs.CurrentM1 = 3; Tac.m1StepAt = CLOCK - 0.05; CAST = {}
check("swing only just begun: wait", tacComboExtend(victim, 5) == false and #CAST == 0)
CLOCK = CLOCK + 0.12
check("swing landed: chain", tacComboExtend(victim, 5) == true and #CAST == 1)

-- 8. travel facing
local east, west, north = Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)
Bot.WalkActive = true; Bot.MoveDirPrev = east; Bot.MoveDirAt = CLOCK
Bot.State = "APPROACH_FAR"; Bot.Dist2D = 40
check("far approach: face the way we run", tacTravelDir() == east)
Bot.State = "ATTACK"; check("in the fight: body stays on the target", tacTravelDir() == nil)
Bot.State = "APPROACH"; Bot.Dist2D = 20; check("closing from 20: still running", tacTravelDir() == east)
Bot.Dist2D = 10; check("closing inside 14: square up", tacTravelDir() == nil)
Bot.State = "RETREAT"; Bot.Dist2D = 15; check("fleeing with room: turn and run", tacTravelDir() == east)
Bot.Dist2D = 6; check("fleeing with them on us: keep facing them", tacTravelDir() == nil)
Bot.State = "IDLE"; Bot.Dist2D = nil; check("roaming with no target: face travel", tacTravelDir() == east)
Bot.WalkActive = false; check("standing still: nothing to face", tacTravelDir() == nil); Bot.WalkActive = true
Bot.MoveDirAt = CLOCK - 1; check("mover not ticking: fall back", tacTravelDir() == nil); Bot.MoveDirAt = CLOCK
Config.TacFaceTravel = false; check("travel facing off", tacTravelDir() == nil); Config.TacFaceTravel = true

-- 9. reversal damping
Life.flipBy = {}; Life.tacDamped = 0
Bot.State = "APPROACH"; Bot.NavMode = "path"; Bot.MoveHeldDir = nil; Bot.MoveFlipSince = nil
local t0 = CLOCK
check("first direction is obeyed", tacDampDir(east, t0) == east)
check("same direction again", tacDampDir(east, t0 + 0.016) == east)
check("a reversal is held off at first", tacDampDir(west, t0 + 0.032) == east)
check("... and still at 0.1 s", tacDampDir(west, t0 + 0.13) == east)
check("... but obeyed once it has persisted 0.2 s", tacDampDir(west, t0 + 0.24) == west)
check("the source of the flip is recorded", Life.flipBy["APPROACH/path"] == 1 and Life.tacDamped == 2)
-- frame-by-frame alternation: the fighter keeps one heading instead of shuffling
Bot.MoveHeldDir = nil; Bot.MoveFlipSince = nil
local steady = true
for i = 0, 59 do
    local want = (i % 2 == 0) and east or west
    if tacDampDir(want, t0 + 1 + i / 60) ~= east then steady = false end
end
check("alternating goals: one steady heading for a full second", steady)
Bot.MoveHeldDir = nil; Bot.MoveFlipSince = nil
tacDampDir(east, t0 + 3)
check("a right-angle turn is not a reversal", tacDampDir(north, t0 + 3.016) == north)
tacDampDir(east, t0 + 4); Bot.State = "RETREAT"
check("a change of state turns at once", tacDampDir(west, t0 + 4.016) == west)
Bot.State = "REACT"; tacDampDir(east, t0 + 5)
check("a dodge is never delayed", tacDampDir(west, t0 + 5.016) == west)
Bot.State = "APPROACH"; tacDampDir(east, t0 + 6)
check("after a pause the old heading no longer binds", tacDampDir(west, t0 + 7) == west)
Config.TacMoveDamp = false; tacDampDir(east, t0 + 8)
check("damping off", tacDampDir(west, t0 + 8.016) == west); Config.TacMoveDamp = true

Life.moveN, Life.moveBack = 200, 30
local line = tacLifeSummary()
check("movement in the summary", line:find("backward 15%% of travel") ~= nil and line:find("mostly APPROACH/path") ~= nil, line)
check("summary formats", type(line) == "string" and line:find("confirm 1/2 hit 12 dmg") ~= nil and line:find("M1 2 swings 1 hits 4 dmg") ~= nil, line)
-- 10. the arena follows the map
check("a fight in the 1.85 city is inside the arena", mapOutOfArena(Vector3.new(1416, 7, 300)) == false)
check("the far edge of the city is inside", mapOutOfArena(Vector3.new(1663, 7, 929)) == false)
check("a domain 3500 studs off is outside", mapOutOfArena(Vector3.new(2030, -24, -3032)) == true)
check("centre is the mean of the spawns", near(mapArenaCentre().X, 1310, 0.01) and near(mapArenaCentre().Z, 550, 0.01))
SPAWNS = nil; ArenaRef.centre = nil; ArenaRef.at = 0
check("no spawn folder: falls back to the world origin", mapOutOfArena(Vector3.new(1416, 7, 300)) == true and mapOutOfArena(Vector3.new(300, 0, 300)) == false)
return n, fails, line, LOG
'''

KMOCK = r"""
function debug(msg) LOG[#LOG + 1] = msg end
Enum = { Material = { Air = "Air" } }
HUM = { FloorMaterial = "Ground", Jump = false }
function getHum() return HUM end
function getHP(c) return c.hpv end
function getInfo(c)
    c = c or ME
    return { FindFirstChild = function(_, k) return (c.info and c.info[k]) or nil end,
             GetAttribute = function(_, k) return nil end }
end
function senseBlocking(c) return c.blockAnim == true end
function senseMeleeSwing(c) return c.swing == true end
function getDist2D(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end
DangerByService = { FakeGrab = "grab", FakeAoe = "aoe" }
SPECIAL = nil
function getSpecialRule() return SPECIAL end
function isSpecialReady() return true end
function useSpecial() CAST[#CAST + 1] = "SPECIAL"; return true end
MEM.global = { moves = {} }
"""
KTESTS = r"""
function debug(msg) LOG[#LOG + 1] = msg end
local fails, n = {}, 0
local function check(name, cond, detail)
    n = n + 1
    if not cond then fails[#fails + 1] = name .. (detail and (" -> " .. tostring(detail)) or "") end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.02) end
local function reset()
    CLOCK = CLOCK + 10
    MEM.facts, MEM.tactics, MEM.global = {}, {}, { moves = {} }
    Know.seeded, Know.stT, Know.heldAt = nil, nil, {}
    Life = { tac = {}, dmg = 0, taken = 0 }
    Bot = { HitCandidates = {}, LastSkill = 0 }
    CAST, USABLE, READY, LOG = {}, {}, {}, {}
    HUM.FloorMaterial, HUM.Jump = "Ground", false
    ME.attrs, ME.stun, ME.rag, ME.inSkill = {}, nil, nil, nil
    ME.HRP.Position = Vector3.new(0, 0, 0)
end
local function entry(name, rule) rule = rule or MoveRules[name] or DefaultRule; return { name = name, service = name .. "Service", rule = rule } end
for k, v in pairs({ Know = true, KnowMinP = 0.2, KnowSureP = 0.45, KnowPriorWeight = 4, KnowSeedCap = 8, KnowProbe = true,
    KnowProbePerLife = 3, KnowProbeTries = 3, KnowProbeGap = 8, KnowCounter = true, KnowCounterReach = 10, KnowM1Hold = true,
    KnowFlankWindow = 0.9, KnowPullMin = 12, KnowReachSlack = 3, TacFinisher = "auto", TacFinisherTrials = 4, TacFinisherWindow = 4,
    TacComboStep = 4, TacComboPatience = 1.6, M1Range = 8, Sense = true }) do Config[k] = v end
MoveRules["Manji Kick"] = { min = 0, max = 12, prio = 4 }
MoveRules["Rapid Punches"] = { min = 0, max = 12, prio = 4 }
MoveRules["Twofold Kick"] = { min = 0, max = 12, prio = 4 }
MoveRules["Cursed Strikes"] = { min = 0, max = 14, prio = 4 }
MoveRules["Reversal Red"] = { min = 0, max = 40, prio = 3 }
MoveRules["Toad"] = { min = 0, max = 75, prio = 4 }
MoveRules["Fake Grab"] = { min = 0, max = 12, prio = 4 }
MoveRules["Mystery"] = { min = 0, max = 12, prio = 4 }
MoveRules["Far Shot"] = { min = 0, max = 80, prio = 4 }

-- the generated table carries what the research said
check("facts: Manji Kick is a counter", MoveFacts.ManjiKick and MoveFacts.ManjiKick.k == "counter" and MoveFacts.ManjiKick.cw == 0.6)
check("facts: Rapid Punches unblockable, misses the ground", MoveFacts.RapidPunches.ub == true and MoveFacts.RapidPunches.rag == false)
check("facts: Twofold Kick blockable, hits the ground", MoveFacts.TwofoldKick.ub == false and MoveFacts.TwofoldKick.rag == true)
check("facts: Toad deals nothing itself", MoveFacts.Toad.nd == true and MoveFacts.Toad.k == "pull")
local nFacts = 0; for _ in pairs(MoveFacts) do nFacts = nFacts + 1 end
check("facts: at least 170 moves researched", nFacts >= 170, nFacts)

-- families
reset()
local k, f, src = knowKind("Manji Kick"); check("kind: researched", k == "counter" and src == "researched")
k, f, src = knowKind("Fake Grab"); check("kind: from the game files", k == "grab" and src == "game files", k)
k, f, src = knowKind("Fake Aoe", { min = 0, max = 20 }); check("kind: aoe from files is around us", k == "aoe_self")
k, f, src = knowKind("Mystery"); check("kind: short reach reads as melee", k == "melee" and src == "range")
k, f, src = knowKind("Far Shot"); check("kind: long reach reads as a projectile", k == "projectile")
k = knowKind("Summoner", { min = 0, max = 30, summon = true }); check("kind: rule flag", k == "summon")
MEM.facts["Mystery"] = { n = 5, s = {}, mv = 70, mvN = 5 }
k, f, src = knowKind("Mystery"); check("kind: a move that carries us 14 studs is a rush", k == "rush" and src == "observed")

-- state of the target
reset()
local foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100
check("state: free", knowState(foe) == "free")
foe.info = { Block = true }; Know.stT = nil; check("state: block", knowState(foe) == "block")
check("state: cached within a frame", (function() foe.info = nil; return knowState(foe) end)() == "block")
CLOCK = CLOCK + 0.1; check("state: cache expires", knowState(foe) == "free")
foe.stun = true; Know.stT = nil; check("state: stun", knowState(foe) == "stun")
foe.rag = true; Know.stT = nil; check("state: ragdoll outranks stun", knowState(foe) == "rag")
foe.stun, foe.rag, foe.swing = nil, nil, true; Know.stT = nil; check("state: swing", knowState(foe) == "swing")
foe.swing = nil; foe.HRP.Position = Vector3.new(0, 9, -6); Know.stT = nil; check("state: air", knowState(foe) == "air")
foe.HRP.Position = Vector3.new(0, 0, -6); Know.stT = nil

-- belief
reset()
check("chance: melee on a free target starts at 0.35", near(knowChance("Mystery", "free"), 0.35))
check("chance: researched blockable into a block is near zero", knowChance("Twofold Kick", "block") < 0.06)
check("chance: researched unblockable into a block is good", knowChance("Rapid Punches", "block") > 0.6)
check("chance: Rapid Punches misses the ground", knowChance("Rapid Punches", "rag") < 0.06)
check("chance: Twofold Kick reaches the ground", knowChance("Twofold Kick", "rag") > 0.6)
MEM.facts["Twofold Kick"] = { n = 8, s = { block = { n = 8, h = 8 } } }
check("chance: eight measured hits overturn the research", knowChance("Twofold Kick", "block") > 0.5, knowChance("Twofold Kick", "block"))

-- seeding from the old career totals
reset()
MEM.global.moves["Reversal Red"] = { tries = 20, hits = 2, dmg = 20 }
MEM.global.moves["SPECIAL:Thing"] = { tries = 30, hits = 1 }
local p0 = knowChance("Reversal Red", "free")
check("seed: a 10% career move starts low on a free target", p0 < 0.2, p0)
check("seed: capped at KnowSeedCap casts", MEM.facts["Reversal Red"].s.free.n == 8)
check("seed: specials are not seeded", MEM.facts["SPECIAL:Thing"] == nil)
check("seed: the same move is still believed on a stunned target", knowChance("Reversal Red", "stun") > 0.7)

-- the gate
reset()
foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100
local ok, p, why = knowAllows(entry("Manji Kick"), foe, 6, "neutral")
check("gate: a counter is never picked as an attack", ok == false and why:find("counter"), why)
foe.info = { Block = true }; Know.stT = nil
ok, p, why = knowAllows(entry("Twofold Kick"), foe, 6, "neutral")
check("gate: blockable move withheld from a guard", ok == false and why:find("block"), why)
ok = knowAllows(entry("Rapid Punches"), foe, 6, "neutral"); check("gate: unblockable move allowed into a guard", ok == true)
foe.info = nil; foe.rag = true; Know.stT = nil
ok = knowAllows(entry("Rapid Punches"), foe, 6, "neutral"); check("gate: not thrown at a body on the ground", ok == false)
ok = knowAllows(entry("Twofold Kick"), foe, 6, "neutral"); check("gate: a ground hitter is", ok == true)
foe.rag = nil; Know.stT = nil
ok = knowAllows(entry("Twofold Kick"), foe, 6, "neutral"); check("gate: free target, ordinary move allowed", ok == true)
ok = knowAllows(entry("Buff", { min = 0, max = 99, selfBuff = true }), foe, 6, "neutral"); check("gate: buffs are not judged", ok == true)
Config.Know = false; foe.rag = true; Know.stT = nil
ok = knowAllows(entry("Rapid Punches"), foe, 6, "neutral"); check("gate: off means off", ok == true)
Config.Know = true; foe.rag = nil; Know.stT = nil
-- a target walking out of a short move's reach
CLOCK = CLOCK + 1
for i = 1, 30 do CLOCK = CLOCK + 1/60; foe.HRP.Position = Vector3.new(0, 0, -10 - 30 * i / 60); tacTrack(foe, CLOCK) end
ok, p, why = knowAllows(entry("Twofold Kick"), foe, 25, "neutral")
check("gate: target leaving a short move's reach", ok == false and why:find("leaving"), why)

-- probing: unknown move, unpromising state, asked a few times a life
reset()
foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100; foe.info = { Block = true }
local allowed = 0
for i = 1, 6 do
    CLOCK = CLOCK + 10; Know.stT = nil
    local okP = knowAllows(entry("Mystery"), foe, 6, "neutral")
    if okP then
        allowed = allowed + 1
        local pend = { move = "Mystery", target = foe, hp0 = 100, at = CLOCK, dist = 6 }
        knowStamp(pend, foe)
        check("probe: stamped as a probe " .. i, pend.probe == true and pend.ts == "block")
        knowBook(pend, 100)
    end
end
check("probe: at most three a life", allowed == 3, allowed)
check("probe: after three misses the question is closed", MEM.facts["Mystery"].s.block.n == 3 and knowChance("Mystery", "block") < 0.1)
foe.info = nil; Know.stT = nil
check("probe: researched answers are never probed", (function()
    foe.rag = true; Know.stT = nil; Life.knowProbes = 0; Bot.KnowProbeAt = 0
    return knowAllows(entry("Rapid Punches"), foe, 6, "neutral") end)() == false)

-- the recorder
reset()
foe = mkChar("foe", 0, -30, 0, 1); foe.hpv = 100
local pd = { move = "Far Shot", target = foe, hp0 = 100, at = CLOCK, dist = 30 }
knowStamp(pd, foe)
check("record: state and position stamped", pd.ts == "free" and pd.myPos ~= nil and pd.dirty == false)
knowWatch(pd, 0.2); check("record: no hit yet", pd.hitAt == nil)
foe.hpv = 88; knowWatch(pd, 0.5); check("record: first damage timed", pd.hitAt == 0.5)
foe.rag = true; knowWatch(pd, 0.85); check("record: what the hit left behind", pd.after == "rag")
ME.HRP.Position = Vector3.new(0, 0, -4); knowWatch(pd, 0.86)
knowBook(pd, 88)
local o = MEM.facts["Far Shot"]
check("record: booked under the state at cast", o.s.free.n == 1 and o.s.free.h == 1 and o.rg == 1 and o.rn == 1)
check("record: own displacement kept", near(o.mv, 4, 0.1))
ME.HRP.Position = Vector3.new(0, 0, 0)
-- a cast thrown while our own basic attack is in flight: damage in the first 0.22 s is not the skill's
reset()
foe = mkChar("foe", 0, -5, 0, 1); foe.hpv = 100; foe.stun = true
Tac.m1StepAt = CLOCK - 0.1; Bot.M1Active = true
pd = { move = "Twofold Kick", target = foe, hp0 = 100, at = CLOCK, dist = 5 }
knowStamp(pd, foe); check("record: dirty when an M1 is in flight", pd.dirty == true and pd.ts == "stun")
foe.hpv = 96; knowWatch(pd, 0.1); knowWatch(pd, 0.25)
check("record: the M1's damage is not the skill's", pd.hitAt == nil and pd.kBase == 96)
knowWatch(pd, 0.6); knowBook(pd, 96)
check("record: so the cast is booked as a miss", MEM.facts["Twofold Kick"].s.stun.h == 0 and MEM.facts["Twofold Kick"].s.stun.n == 1)
foe.hpv = 100; pd = { move = "Twofold Kick", target = foe, hp0 = 100, at = CLOCK, dist = 5 }
knowStamp(pd, foe); foe.hpv = 96; knowWatch(pd, 0.25); foe.hpv = 86; knowWatch(pd, 0.5); knowBook(pd, 86)
check("record: damage after the M1 window counts", MEM.facts["Twofold Kick"].s.stun.h == 1)
-- a move that deals nothing is judged by what it does
reset()
foe = mkChar("foe", 0, -40, 0, 1); foe.hpv = 100
ok = knowAllows(entry("Toad"), foe, 40, "neutral"); check("pull: allowed at range", ok == true)
ok, p, why = knowAllows(entry("Toad"), foe, 6, "neutral"); check("pull: pointless at arm's length", ok == false, why)
pd = { move = "Toad", target = foe, hp0 = 100, at = CLOCK, dist = 40 }
knowStamp(pd, foe); foe.stun = true; knowWatch(pd, 0.6); knowBook(pd, 100)
check("pull: a stun with no damage is a hit for it", MEM.facts["Toad"].s.free.h == 1)

-- timing: delay = 0.2 + d / 100
reset()
foe = mkChar("foe", 0, -30, 0, 1)
for _, dd in ipairs({ 10, 20, 30, 40, 50, 60 }) do
    foe.hpv = 100
    local q = { move = "Far Shot", target = foe, hp0 = 100, at = CLOCK, dist = dd }
    knowStamp(q, foe); foe.hpv = 90; knowWatch(q, 0.2 + dd / 100); knowBook(q, 90)
end
local mean, windup, speed = knowTiming("Far Shot")
check("timing: wind-up recovered", windup and near(windup, 0.2, 0.01), windup)
check("timing: speed recovered", speed and near(speed, 100, 1), speed)
Config.TacLeadMax = 2
check("timing: lead uses the measured line", near(tacLeadTime("Far Shot", 50), 0.7, 0.01), tacLeadTime("Far Shot", 50))
Config.TacLeadMax = 0.7
check("timing: three hits give a mean only", (function()
    MEM.facts["X"] = { n = 3, s = {}, rn = 3, rd = 30, rt = 0.9, rdd = 300, rdt = 9 }
    local m, w = knowTiming("X"); return near(m, 0.3) and w == nil end)())

-- roles
reset()
MEM.facts["Slam"] = { n = 5, s = {}, hn = 5, rg = 4, st = 1 }
MEM.facts["Hold"] = { n = 5, s = {}, hn = 5, rg = 0, st = 5 }
check("role: mostly leaves them down is an ender", knowRole("Slam") == "ender")
check("role: mostly leaves them held is an extender", knowRole("Hold") == "extender")

-- the chain waits for three basic hits, then prefers what keeps the target up
reset()
foe = mkChar("foe", 0, -5, 0, 1); foe.hpv = 100; foe.stun = true; foe.hp = 90
MoveRules["Slam"] = { min = 0, max = 12, prio = 4 }; MoveRules["Hold"] = { min = 0, max = 12, prio = 4 }
MEM.facts["Slam"] = { n = 5, s = {}, hn = 5, rg = 5 }; MEM.facts["Hold"] = { n = 5, s = {}, hn = 5, st = 5 }
USABLE = { entry("Slam"), entry("Hold"), entry("Manji Kick") }
Bot.Target = foe; Bot.DistY = 0; Bot.ConfirmSince = CLOCK - 0.3; Tac.m1StepAt = CLOCK - 0.3
ME.attrs.CurrentM1 = 2
check("chain: one hit out is not a string yet", tacComboExtend(foe, 5) == false and #CAST == 0)
ME.attrs.CurrentM1 = 3
check("chain: two out, still waiting", tacComboExtend(foe, 5) == false)
ME.attrs.CurrentM1 = 4
check("chain: three out, the skill goes", tacComboExtend(foe, 5) == true and CAST[1] == "HoldService", CAST[1])
CLOCK = CLOCK + 1; CAST = {}; ME.attrs.CurrentM1 = 2; Bot.ConfirmSince = CLOCK - 0.3; Tac.m1StepAt = CLOCK - 0.3
check("chain: out of arm's reach there is nothing to wait for", (function()
    MoveRules["Slam"].max = 40; MoveRules["Hold"].max = 40
    return tacComboExtend(foe, 25) end)() == true)
CLOCK = CLOCK + 1; CAST = {}; Bot.ConfirmSince = CLOCK - 2; Tac.m1StepAt = CLOCK - 1
check("chain: a string that stalls is not waited on for ever", tacComboExtend(foe, 5) == true)
check("chain: the counter is never part of it", (function() for _, c in ipairs(CAST) do if c == "Manji KickService" then return false end end return true end)())

-- counters go into swings
reset()
foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100; foe.swing = true
USABLE = { entry("Manji Kick"), entry("Twofold Kick") }
check("counter: thrown into a swing in reach", knowTryCounter(foe, CLOCK, false) == true and CAST[1] == "Manji KickService")
check("counter: no block over the stance", Bot.KnowCounterUntil > CLOCK and Bot.CastCtx == "counter")
check("counter: not twice in a row", knowTryCounter(foe, CLOCK + 0.5, false) == false)
reset(); USABLE = { entry("Manji Kick") }
Bot.BlockActive = true; check("counter: never from behind a raised block", knowTryCounter(foe, CLOCK, false) == false)
Bot.BlockActive = false; foe.HRP.Position = Vector3.new(0, 0, -20)
check("counter: not at somebody out of reach", knowTryCounter(foe, CLOCK, false) == false)
foe.HRP.Position = Vector3.new(0, 0, -6)
check("counter: a 0.6 s window is long enough to throw on a prediction", knowTryCounter(foe, CLOCK, true) == true)
reset(); MoveRules["Outburst"] = { min = 0, max = 12, prio = 4 }; USABLE = { entry("Outburst") }
check("counter: a 0.25 s window is not", knowTryCounter(foe, CLOCK, true) == false)
check("counter: but it is thrown into a seen swing", knowTryCounter(foe, CLOCK, false) == true)
reset(); USABLE = {}; SPECIAL = { name = "Door Guard", kind = "counter" }
check("counter: on the special key", knowTryCounter(foe, CLOCK, false) == true and CAST[1] == "SPECIAL")
SPECIAL = nil

-- the right tool for a guard and for the ground
reset()
foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100; Bot.DistY = 0
USABLE = { entry("Twofold Kick"), entry("Rapid Punches"), entry("Manji Kick") }
check("guard: the unblockable move is chosen", knowTryState(foe, 6, "block", "break") == true and CAST[1] == "Rapid PunchesService", CAST[1])
CLOCK = CLOCK + 2; CAST = {}
check("ground: the move that reaches the ground is chosen", knowTryState(foe, 6, "rag", "ground") == true and CAST[1] == "Twofold KickService", CAST[1])
CLOCK = CLOCK + 2; CAST = {}; USABLE = { entry("Cursed Strikes") }
check("guard: nothing suitable, nothing thrown", knowTryState(foe, 6, "block", "break") == false and #CAST == 0)
check("counts: one guard-break, one ground hit", Life.knowBreak == 1 and Life.knowGround == 1)

-- wasted swings
reset()
check("m1: kept from a body on the ground", knowM1Wasted(foe, "rag") == true)
check("m1: kept from a raised guard", knowM1Wasted(foe, "block") == true)
Bot.LastDodge = CLOCK - 0.3; check("m1: let go right after a side dash", knowM1Wasted(foe, "block") == false)
Bot.LastDodge = 0; ME.attrs.CurrentM1 = 4; check("m1: the fourth swing goes through a guard", knowM1Wasted(foe, "block") == false)
ME.attrs.CurrentM1 = nil; check("m1: free target, swing away", knowM1Wasted(foe, "free") == false)

-- the fourth hit
reset()
foe = mkChar("foe", 0, -5, 0, 1); foe.hpv = 100; foe.stun = true; Bot.Target = foe
check("finisher: untried, the first is tried", tacFinisherPick(foe) == "down")
MEM.tactics.fin = { down = { n = 4, net = 8 }, up = { n = 4, net = 40 }, flat = { n = 4, net = -12 } }
check("finisher: after the trials, what paid best", tacFinisherPick(foe) == "up")
foe.info = { Block = true }; check("finisher: against a guard, the one that cannot be blocked", tacFinisherPick(foe) == "down")
foe.info = nil
MEM.tactics.fin = nil; Config.TacFinisher = "down"
ME.attrs.CurrentM1 = 3; Tac.m1StepAt = CLOCK
check("finisher: nothing before the third hit is out", tacFinisher() == nil and Bot.FinMode == nil)
ME.attrs.CurrentM1 = 4; Tac.m1StepAt = CLOCK; Tac.m1Gap = 0.35
CLOCK = CLOCK + 0.1; check("finisher: the chain gets first refusal", tacFinisher() == nil and Bot.FinMode == nil)
CLOCK = CLOCK + 0.1; check("finisher: slam holds the swing and jumps", tacFinisher() == "hold" and Bot.FinMode == "down" and HUM.Jump == true)
HUM.FloorMaterial = "Air"; check("finisher: airborne, the swing is released", tacFinisher() == nil)
ME.attrs.CurrentM1 = 5; tacFinisherStep(4, 5)
check("finisher: thrown, outcome pending", Bot.FinPending ~= nil and Bot.FinPending.mode == "down" and Bot.FinMode == nil)
Life.dmg, Life.taken = 30, 10; CLOCK = CLOCK + 2; tacFinisherBook(); check("finisher: not booked early", Bot.FinPending ~= nil)
CLOCK = CLOCK + 2.1; tacFinisherBook()
check("finisher: net damage booked", MEM.tactics.fin.down.n == 1 and MEM.tactics.fin.down.net == 20 and Life.fin.down.n == 1)
-- launcher: waits for the swing to be due, then jumps on the same frame
reset(); foe.stun = true; Bot.Target = foe; Config.TacFinisher = "up"; HUM.FloorMaterial, HUM.Jump = "Ground", false
ME.attrs.CurrentM1 = 4; Tac.m1StepAt = CLOCK; Tac.m1Gap = 0.4
CLOCK = CLOCK + 0.22; check("launcher: held until the swing is due", tacFinisher() == "hold" and HUM.Jump == false)
CLOCK = CLOCK + 0.16; check("launcher: jump and swing together", tacFinisher() == nil and HUM.Jump == true and Bot.M1DirForce == "Up")
-- a string that times out is not a finisher
reset(); foe.stun = true; Bot.Target = foe; Config.TacFinisher = "down"; HUM.FloorMaterial = "Ground"
ME.attrs.CurrentM1 = 4; Tac.m1StepAt = CLOCK - 0.3; tacFinisher(); tacFinisherStep(4, 1)
check("finisher: a string that resets books nothing", Bot.FinPending == nil and Bot.FinMode == nil)
tacFinisherStep(2, 3); check("cadence: measured between swings", Tac.m1Gap ~= nil)
Config.TacFinisher = "off"; ME.attrs.CurrentM1 = 4; check("finisher: off is off", tacFinisher() == nil)
Config.TacFinisher = "auto"

-- a counter is booked against whoever swung, as a cast into a swing
reset()
foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100
local third = mkChar("third", 4, -4, 0, 1); third.hpv = 100
Bot.KnowCastVs = third
pd = { move = "Manji Kick", target = foe, hp0 = 100, at = CLOCK, dist = 6, ctx = "counter", key = "k" }
knowStamp(pd, foe)
check("counter book: aimed at the attacker", pd.target == third and pd.ts == "swing" and pd.key == nil)
third.hpv = 91; knowWatch(pd, 0.4); knowBook(pd, 91); knowBook(pd, 91)
check("counter book: once, as a hit into a swing", MEM.facts["Manji Kick"].s.swing.n == 1 and MEM.facts["Manji Kick"].s.swing.h == 1)

-- refusals that were not
reset()
Config.CastVerifyDelay = 0.4
check("late: ordinary moves are judged at 0.4 s", knowVerifyDelay("Heat Emission") == 0.4)
Bot.Refused = { HeatService = CLOCK + 5 }; Bot.RefusedN = { HeatService = 2 }
knowLateStamp("Heat Emission", "HeatService")
check("late: the hold on the move is lifted", Bot.Refused.HeatService == 0 and Bot.RefusedN.HeatService == 0 and Life.lateStamp == 1)
check("late: once is not a habit", knowVerifyDelay("Heat Emission") == 0.4)
knowLateStamp("Heat Emission", "HeatService")
check("late: twice, and it is given longer", knowVerifyDelay("Heat Emission") == 1.3)

-- report lines do not error and say what is known
reset()
foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100
pd = { move = "Rapid Punches", target = foe, hp0 = 100, at = CLOCK, dist = 6 }
knowStamp(pd, foe); foe.hpv = 85; knowWatch(pd, 0.4); knowBook(pd, 85); knowNoteCooldown("Rapid Punches", 15.2)
LOG = {}; knowLifeReport()
check("report: one KNOW line", #LOG == 1 and LOG[1]:find("KNOW Rapid Punches: melee %(researched, unblockable, misses the ground%)") ~= nil, LOG[1])
check("report: cooldown measured against listed", LOG[1]:find("cooldown 15.2 s %(listed 15%)") ~= nil, LOG[1])
knowGate(entry("Manji Kick"), foe, 6, "neutral")
local sumline = knowLifeSummary()
check("report: summary counts what was withheld", sumline:find("1 casts withheld %(mostly counter x1%)") ~= nil, sumline)
return n, fails, sumline, LOG
"""

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(MOCK)
lua.execute(KMOCK)
lua.execute(core)
lua.execute(combat)
a3 = src.index('ArenaRef = { at = 0, centre = nil }'); b3 = src.index('function mapOutOfArena(pos)'); b3 = src.index('\nend', b3) + 5
lua.execute('''
function debug() end
local function part(x, z) return { Position = Vector3.new(x, 5, z), IsA = function(_, c) return c == "BasePart" end } end
SPAWNS = { part(1300, 500), part(1400, 600), part(1200, 560), part(1340, 540) }
Workspace = { FindFirstChild = function(_, n) if n == "Spawns" and SPAWNS then return { GetDescendants = function() return SPAWNS end } end end }
Config.MapArenaRadius = 1000
''')
lua.execute(src[a3:b3])
n, fails, line, log = lua.execute(TESTS)
fails = list(fails.values())
print('%d checks, %d failed' % (n, len(fails)))
for f in fails: print('  FAIL:', f)
print('summary line:', line)
print('log lines emitted:'); [print('  ', l) for l in list(log.values())[:6]]
kn, kfails, kline, klog = lua.execute(KTESTS)
kfails = list(kfails.values())
print('knowledge: %d checks, %d failed' % (kn, len(kfails)))
for f in kfails: print('  FAIL:', f)
print('knowledge summary:', kline)
for l in list(klog.values())[:3]: print('  ', l)
sys.exit(1 if (fails or kfails) else 0)
