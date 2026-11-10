import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding='utf-8').read()
a = src.index('Tac = { track = setmetatable'); b = src.index('local function getAimPoint()')
core = src[a:b]
a2 = src.index('function tacConfirmed(t)'); b2 = src.index('function trySpecial(t, d2d)')
combat = src[a2:b2]
a4 = src.index('Know.P2 = {'); b4 = src.index('-- ------------------------------------------------------------------ knowledge, acting on it')
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
function isAlive(c) c = c or ME; return not c.dead end
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
QUEUE, FIRED = {}, {}
task = { delay = function(d, f) QUEUE[#QUEUE + 1] = { at = CLOCK + d, f = f } end,
         spawn = function(f) SPAWNED = f end, wait = function() end }
function runQueue(dt)
    CLOCK = CLOCK + dt
    local keep = {}
    for _, q in ipairs(QUEUE) do if q.at <= CLOCK + 1e-9 then q.f() else keep[#keep + 1] = q end end
    QUEUE = keep
end
function fireRemote(svc, sig, value, extra) FIRED[#FIRED + 1] = svc .. "." .. sig end
function buildExtra() return nil end
function typeof(x) if type(x) == "table" and x.IsA then return "Instance" end return type(x) end
ULT, AWAKE = 0, false
function getUltMeter() return ULT end
function isAwakened() return AWAKE end
function isTargetFacingUs(c) return c.facing ~= false end
SPECIAL = nil
function getSpecialRule() return SPECIAL end
function isSpecialReady() return true end
function useSpecial() CAST[#CAST + 1] = "SPECIAL"; return true end
MEM.global = { moves = {} }
-- v93: reactions, carrying, and a path compute that can park the frame
DangerPlan = { grab = "away", pull = "block", beam = "dodge", rush = "block", aoe = "away", counter = "hold" }
PICKS, PICKN = {}, 0
function memBestReaction(move, fallback, kind) PICKN = PICKN + 1; return PICKS[PICKN] or fallback end
function senseHoldingThrowable() return ME.holding == true end
Enum.PathStatus = { Success = "Success" }
YIELD = false
PathfindingService = { CreatePath = function()
    return { Status = "Success",
             ComputeAsync = function() if YIELD then coroutine.yield() end end,
             GetWaypoints = function() return { { Position = Vector3.new(0, 0, 0) }, { Position = Vector3.new(0, 0, -10) } } end }
end }
function firstWaypointAhead() return 2 end
function clearPath() Bot.Path, Bot.PathPoints, Bot.PathIndex = nil, nil, 1 end
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
CLOCK = CLOCK + 1; CAST = {}; MoveRules["Slam"].max = 12; MoveRules["Hold"].max = 12
ME.attrs.CurrentM1 = 2; Bot.ConfirmSince = CLOCK - 0.9; Tac.m1StepAt = CLOCK - 0.7
check("chain: swings that stopped coming are not waited for", tacComboExtend(foe, 5) == true)
CLOCK = CLOCK + 1; CAST = {}; Bot.ConfirmSince = CLOCK - 0.9; Tac.m1StepAt = CLOCK - 0.2
check("chain: swings still coming are", tacComboExtend(foe, 5) == false)
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

-- the second press
reset(); QUEUE, FIRED = {}, {}
Config.KnowSecondPress, Config.KnowP2Trials, Config.Enabled = true, 3, true
ME.IsA = function() return true end
foe = mkChar("foe", 0, -8, 0, 1); foe.hpv = 100; Bot.Target = foe
check("p2: two-press moves are judged late, not refused early", knowVerifyDelay("Transcend") == 1.4 and knowVerifyDelay("Drone Strike") == 2.8)
check("p2: ordinary moves are not", knowVerifyDelay("Twofold Kick") == 0.4)
Know.p2Hooked = { TranscendService = true }
pd = { move = "Transcend", target = foe, hp0 = 100, at = CLOCK, dist = 8 }
knowStamp(pd, foe)
knowP2Cast("Transcend", "TranscendService", { Name = "Transcend" })
check("p2: armed on the cast, nothing pressed yet", Bot.P2Last ~= nil and #QUEUE == 0 and Life.p2Cast == 1)
local other = mkChar("other", 9, 9, 0, 1); other.IsA = function() return true end
knowP2Event("TranscendService", "Startup", other); check("p2: somebody else's crouch is not our cue", #QUEUE == 0)
knowP2Event("RuptureService", "Startup", ME); check("p2: another move's cue is not ours", #QUEUE == 0)
knowP2Event("TranscendService", "Startup", ME)
check("p2: our crouch schedules the press, first delay first", #QUEUE == 1 and pd.p2arm == 1 and near(QUEUE[1].at - CLOCK, 0.2, 0.001))
runQueue(0.1); check("p2: not before its time", #FIRED == 0)
runQueue(0.11); check("p2: pressed again", FIRED[1] == "TranscendService.Activated" and Life.p2Sent == 1)
knowP2Event("TranscendService", "Startup", ME); check("p2: once per cast", #QUEUE == 1)   -- only the release is queued
foe.hpv = 88; knowWatch(pd, 0.5); knowBook(pd, 88)
check("p2: the delay is credited with the damage", MEM.facts["Transcend"].p2[1].n == 1 and MEM.facts["Transcend"].p2[1].d == 12)
check("p2: the next cast tries the next delay", knowP2Pick("Transcend", Know.P2.Transcend) == 2)
MEM.facts["Transcend"].p2 = { { n = 3, d = 6 }, { n = 3, d = 36 }, { n = 3, d = 0 } }
check("p2: after the trials the best delay is kept", knowP2Pick("Transcend", Know.P2.Transcend) == 2)
-- knocked out of it before the second press
reset(); QUEUE, FIRED = {}, {}; Bot.Target = foe; Know.p2Hooked = { TranscendService = true }
knowP2Cast("Transcend", "TranscendService", { Name = "Transcend" }); knowP2Event("TranscendService", "Startup", ME)
ME.stun = true; runQueue(0.6)
check("p2: a stun before the press is counted, nothing is sent", #FIRED == 0 and Life.p2Lost == 1)
ME.stun = nil
-- no hook: press blind
reset(); QUEUE, FIRED = {}, {}; Bot.Target = foe; Know.p2Hooked = {}
knowP2Cast("Rupture", "RuptureService", { Name = "Rupture" })
check("p2: without the cue it presses blind", #QUEUE == 1)
runQueue(0.5); check("p2: blind press sent", FIRED[1] == "RuptureService.Activated")
-- switched off
reset(); QUEUE, FIRED = {}, {}; Config.KnowSecondPress = false
knowP2Cast("Transcend", "TranscendService", { Name = "Transcend" })
check("p2: off is off", Bot.P2Last == nil and #QUEUE == 0 and knowVerifyDelay("Transcend") == 0.4)
Config.KnowSecondPress = true
-- a move that has no second press
knowP2Cast("Twofold Kick", "TwofoldKickService", { Name = "Twofold Kick" }); check("p2: one-press moves are left alone", Bot.P2Last == nil)

-- the ledger: what we were doing when a hit got in
reset(); Config.TacLedger, Config.TacWake, Config.TacWakeWindow = true, true, 0.5
local atk = mkChar("atk", 0, -6, 0, 1)
Tac.lastState = "ATTACK"; Tac.m1StepAt = CLOCK - 0.2; Tac.selfWokeAt = 0
tacOpener(atk, "Todo:Melee1"); check("ledger: caught mid-swing", Life.open["mid-swing"] == 1 and Life.openN == 1)
Bot.BlockActive = true; tacOpener(atk, "Todo:Melee1"); check("ledger: through a raised block from the front", Life.open["through a raised block"] == 1)
atk.HRP.Position = Vector3.new(0, 0, 6); tacOpener(atk, "Todo:Melee1"); check("ledger: a block does not cover the back", Life.open["block up, hit from behind"] == 1)
Bot.BlockActive = false; Tac.m1StepAt = 0; Life.lastUsedAt = CLOCK - 0.5
tacOpener(atk, "Todo:SwiftKick"); check("ledger: punished after a cast", Life.open["after a cast"] == 1)
Life.lastUsedAt = 0; Tac.lastState = "APPROACH"; tacOpener(atk, "Todo:Chase"); check("ledger: caught closing in", Life.open["closing in"] == 1)
tacOpener(atk, "self:Ultra Cannon"); tacOpener(atk, "FF:ally:Blue"); check("ledger: our own recovery and friendly fire are not openers", Life.openN == 5)
Tac.selfWokeAt = CLOCK - 0.2; tacOpener(atk, "Todo:Melee2")
check("ledger: stunned by melee while listed as immune is flagged", Life.open["just got up"] == 1 and Life.wakeStunned == 1)
check("ledger: career totals kept", MEM.tactics.open["mid-swing"] == 1)
check("ledger: the life line names the worst", tacOpenerSummary():find("hits that got in: 6 %(") ~= nil, tacOpenerSummary())
Config.TacLedger = false; tacOpener(atk, "Todo:Melee1"); check("ledger: off is off", Life.openN == 6); Config.TacLedger = true

-- getting up
reset()
ME.rag = true; tacSelfTick(CLOCK); CLOCK = CLOCK + 0.5; ME.rag = nil; Bot.State = "ATTACK"; tacSelfTick(CLOCK)
check("wake: our own getting up is timed", Tac.selfWokeAt == CLOCK and Tac.lastState == "ATTACK")
foe = mkChar("foe", 0, -5, 0, 1); foe.hpv = 100; Bot.Target = foe; Bot.Dist2D = 5
check("wake: swing through while their melee cannot stun us", tacOwnWake(foe) == true and Life.wakeSwing == 1)
check("wake: counted once per getting up", tacOwnWake(foe) == true and Life.wakeSwing == 1)
Bot.Dist2D = 30; check("wake: not if nobody is in reach", tacOwnWake(foe) == false); Bot.Dist2D = 5
CLOCK = CLOCK + 0.6; check("wake: the window closes", tacOwnWake(foe) == false)
Bot.State = "CCED"; tacSelfTick(CLOCK); check("wake: the last active state is remembered through a stun", Tac.lastState == "ATTACK")
-- theirs
reset()
foe = mkChar("foe", 0, -5, 0, 1); foe.hpv = 100; foe.rag = true
tacTrack(foe, CLOCK); CLOCK = CLOCK + 0.1; tacTrack(foe, CLOCK)
check("wake: on the ground is still on the ground", knowState(foe) == "rag")
foe.rag = nil; CLOCK = CLOCK + 0.1; tacTrack(foe, CLOCK); Know.stT = nil
check("wake: just up is its own state", knowState(foe) == "wake")
check("wake: no swings into it", knowM1Wasted(foe, "wake") == true)
Config.KnowProbe = false
check("wake: melee is not thrown into it", knowAllows(entry("Twofold Kick"), foe, 5, "neutral") == false)
Config.KnowProbe = true
check("wake: their first swing is guarded", tacTheirWake(foe, 5, CLOCK) == true and Life.wakeGuard == 1)
check("wake: once, not every frame", tacTheirWake(foe, 5, CLOCK + 0.1) == false)
CLOCK = CLOCK + 0.6; Know.stT = nil; check("wake: half a second later they are fair game", knowState(foe) == "free")
Config.TacWake = false; foe.rag = true; tacTrack(foe, CLOCK); foe.rag = nil; CLOCK = CLOCK + 0.1; tacTrack(foe, CLOCK); Know.stT = nil
check("wake: off is off", knowState(foe) == "free" and tacOwnWake(foe) == false); Config.TacWake = true

-- awakening
reset(); Config.TacAwaken, Config.TacAwakenHP, Config.TacAwakenHold = true, 70, 15
foe = mkChar("foe", 0, -6, 0, 1); Bot.Target = foe; Bot.Dist2D = 6; ULT = 100
check("awaken: not at full health against a free target", tacAwakenWorth(100) == false)
check("awaken: when hurt", tacAwakenWorth(60) == true)
foe.stun = true; check("awaken: when the target cannot answer", tacAwakenWorth(100) == true); foe.stun = nil
CLOCK = CLOCK + 16; check("awaken: a bar held too long is spent", tacAwakenWorth(100) == true)
ULT = 0; tacSelfTick(CLOCK); check("awaken: the wait is counted", Bot.UltFullSince == nil and Life.ultWaited >= 15.9, Life.ultWaited)
Config.TacAwaken = false; check("awaken: off means at once", tacAwakenWorth(100) == true); Config.TacAwaken = true

-- domains
reset(); Config.KnowDomainDist = 22
MoveRules["Infinite Void"] = { min = 0, max = 40, prio = 2 }
foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100
check("domain: researched as one", (knowKind("Infinite Void")) == "domain")
local okD, _, whyD = knowAllows(entry("Infinite Void"), foe, 6, "neutral")
check("domain: not with a free enemy in reach", okD == false and whyD:find("domain") ~= nil, whyD)
check("domain: at a distance", knowAllows(entry("Infinite Void"), foe, 30, "neutral") == true)
foe.rag = true; Know.stT = nil; check("domain: with the target down", knowAllows(entry("Infinite Void"), foe, 6, "neutral") == true)

-- held versions
reset(); Config.KnowHold, Config.KnowHoldDist, Config.KnowHoldTrials = true, 14, 3
MoveRules["Ultra Cannon"] = { min = 0, max = 60, prio = 3 }
foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100
check("hold: moves without a held version are tapped", knowHoldFor("Twofold Kick", foe, 30) == nil and Bot.KnowHoldArm == nil)
check("hold: not with the target in our face", knowHoldFor("Ultra Cannon", foe, 6) == nil and Bot.KnowHoldArm == "tap")
check("hold: tried at a distance", knowHoldFor("Ultra Cannon", foe, 30) == 1.4 and Bot.KnowHoldArm == "hold" and Bot.HoldUntil > CLOCK)
check("hold: a held cast is not judged refused while it is held", knowVerifyDelay("Ultra Cannon") > 2.5)
pd = { move = "Ultra Cannon", target = foe, hp0 = 100, at = CLOCK, dist = 30 }
knowStamp(pd, foe); foe.hpv = 84; knowWatch(pd, 1.6); knowBook(pd, 84)
check("hold: the held arm is credited", MEM.facts["Ultra Cannon"].hold.hold.n == 1 and MEM.facts["Ultra Cannon"].hold.hold.d == 16)
MEM.facts["Ultra Cannon"].hold = { tap = { n = 3, d = 30 }, hold = { n = 3, d = 15 } }
check("hold: kept only if it deals more", knowHoldFor("Ultra Cannon", foe, 30) == nil and Bot.KnowHoldArm == "tap")
MEM.facts["Ultra Cannon"].hold = { tap = { n = 3, d = 30 }, hold = { n = 3, d = 48 } }
check("hold: and it is when it does", knowHoldFor("Ultra Cannon", foe, 30) == 1.4)
foe.rag = true; check("hold: a target on the ground is room enough", knowHoldFor("Ultra Cannon", foe, 6) == 1.4); foe.rag = nil
Config.KnowHold = false; check("hold: off is off", knowHoldFor("Ultra Cannon", foe, 30) == nil); Config.KnowHold = true
Bot.HoldUntil, Bot.HoldCastUntil = nil, nil

-- opening with the dash punch
reset(); Config.TacDashOpen, Config.TacDashMin, Config.TacDashMax, Config.TacDashCooldown = true, 11, 18, 6.2
foe = mkChar("foe", 0, -14, 0, 1); foe.hpv = 100; Bot.DistY = 0; Bot.Dist2D = 14
check("dash: opens from the middle of its reach", tacDashOpen(foe, 14, CLOCK) == true)
check("dash: not from so close that it knocks down", tacDashOpen(foe, 8, CLOCK) == false)
check("dash: not from out of reach", tacDashOpen(foe, 25, CLOCK) == false)
Bot.LastChase = CLOCK - 3; check("dash: not while it is on cooldown", tacDashOpen(foe, 14, CLOCK) == false); Bot.LastChase = 0
foe.info = { Block = true }; Know.stT = nil; check("dash: not into a guard", tacDashOpen(foe, 14, CLOCK) == false)
foe.info = nil; foe.rag = true; Know.stT = nil; check("dash: not at a body on the ground", tacDashOpen(foe, 14, CLOCK) == false)
foe.rag = nil; Know.stT = nil; foe.iframes = true; check("dash: not at somebody who cannot be hit", tacDashOpen(foe, 14, CLOCK) == false); foe.iframes = nil
Bot.DistY = 9; check("dash: not up or down a level", tacDashOpen(foe, 14, CLOCK) == false); Bot.DistY = 0
tacDashOpened(foe, CLOCK); check("dash: counted", Life.dashOpen == 1 and Bot.DashOpen ~= nil)
CLOCK = CLOCK + 0.1; tacDashOpenTick(CLOCK); check("dash: too early to judge", Bot.DashOpen ~= nil)
foe.HRP.Position = Vector3.new(0, 0, -5); foe.stun = true; CLOCK = CLOCK + 0.3; tacDashOpenTick(CLOCK)
check("dash: a stunned target beside us is a landed punch", Life.dashOpenHit == 1 and Bot.DashOpen == nil)
tacDashOpened(foe, CLOCK); foe.stun = nil; CLOCK = CLOCK + 1.2; tacDashOpenTick(CLOCK)
check("dash: a miss is just a miss", Life.dashOpenHit == 1 and Bot.DashOpen == nil and tacOpenSummary():find("dash punches 2 %(1 landed%)") ~= nil)

-- escaping to the side
reset(); Config.TacEscapeSide = true
local realCentre, realDir = mapArenaCentre, dashDirFor
dashDirFor = function(v) return v end
local hrp = { Position = Vector3.new(0, 0, 0) }
local from = { Position = Vector3.new(0, 0, -6) }           -- attacker in front of us
mapArenaCentre = function() return Vector3.new(50, 0, 0) end
local v1 = tacEscapeDir(hrp, from, "Back")
check("escape: sideways, toward the middle", v1.X > 0.5 and v1.Z > 0, string.format("%.2f,%.2f", v1.X, v1.Z))
mapArenaCentre = function() return Vector3.new(-50, 0, 0) end
local v2 = tacEscapeDir(hrp, from, "Back")
check("escape: the other side when the middle is there", v2.X < -0.5 and v2.Z > 0)
Config.TacEscapeSide = false; check("escape: off keeps the old direction", tacEscapeDir(hrp, from, "Back") == "Back")
Config.TacEscapeSide = true; mapArenaCentre, dashDirFor = realCentre, realDir

-- strings are not four hits for everybody
reset()
check("string: four hits unless told otherwise", (tacStringLen()) == 4 and select(2, tacStringLen()) == true)
ME.attrs.Moveset = "Ryu"; check("string: True Cannon's is three", (tacStringLen()) == 3)
foe = mkChar("foe", 0, -5, 0, 1); foe.hpv = 100; foe.stun = true; foe.hp = 90
USABLE = { entry("Twofold Kick") }; Bot.Target = foe; Bot.DistY = 0
Bot.ConfirmSince = CLOCK - 0.3; Tac.m1StepAt = CLOCK - 0.3
ME.attrs.CurrentM1 = 2; check("string: one out of three, wait", tacComboExtend(foe, 5) == false)
ME.attrs.CurrentM1 = 3; check("string: two out of three, cast before the last", tacComboExtend(foe, 5) == true)
Config.TacFinisher = "down"; HUM.FloorMaterial, HUM.Jump = "Ground", false; Tac.m1Gap = 0.35
ME.attrs.CurrentM1 = 3; Tac.m1StepAt = CLOCK - 0.25; Bot.FinMode = nil
check("string: the last hit of a three-hit string is the third", tacFinisher() == "hold" and Bot.FinMode == "down")
tacFinisherStep(3, 4); check("string: and it is booked when the counter moves past it", Bot.FinPending ~= nil)
ME.attrs.Moveset = "Naoya"; ME.attrs.CurrentM1 = 4; Tac.m1StepAt = CLOCK - 0.25; Bot.FinMode, Bot.FinPending = nil, nil; HUM.Jump = false
check("string: no jump for a last hit that comes one way only", tacFinisher() == nil and HUM.Jump == false and Bot.FinMode == nil)
ME.attrs.Moveset = nil; Config.TacFinisher = "auto"

-- the session line
reset(); Tac.session = nil; Bot.Kills = 2
Life.startAt = CLOCK - 100; Life.dmg, Life.taken, Life.stunned = 120, 100, 30
LOG = {}; tacSessionLine()
check("session: first life", #LOG == 1 and LOG[1]:find("SESSION: 0 kills, 1 lives") ~= nil and LOG[1]:find("dealt 1.20 for each 1 taken") ~= nil, LOG[1])
Bot.Kills = 3; Life.startAt = CLOCK - 50; Life.dmg, Life.taken, Life.stunned = 200, 80, 5
LOG = {}; tacSessionLine()
check("session: running totals and the trend", LOG[1]:find("SESSION: 1 kills, 2 lives") ~= nil and LOG[1]:find("dealt 1.78 for each 1 taken %(this life 2.50%)") ~= nil
    and LOG[1]:find("better than the session before it") ~= nil, LOG[1])

-- the reach of a basic attack, measured
reset(); Config.TacM1Probe, Config.TacM1Slack, Config.TacM1Lead, Config.M1Range = true, 1.0, 0.2, 7
Tac.m1Pending = {}
foe = mkChar("foe", 0, -5, 0, 1); foe.hpv = 100; Bot.Target = foe
check("reach: the default until measured", (tacM1Reach()) == 7 and select(2, tacM1Reach()) == false)
local function swing(dist, lands)
    Bot.Dist2D = dist; foe.hpv = 100; Know.stT = nil
    tacM1Swing(CLOCK); if lands then foe.hpv = 96 end
    CLOCK = CLOCK + 0.45; tacM1Resolve(CLOCK)
end
Bot.LastSkill = 0
for i = 1, 10 do swing(3, true) end
for i = 1, 10 do swing(5, i <= 6) end
for i = 1, 10 do swing(7, i <= 1) end
for i = 1, 10 do swing(10, false) end
check("reach: booked by distance", MEM.tactics.m1r["2"].n == 10 and MEM.tactics.m1r["4"].h == 6 and MEM.tactics.m1r["10"].h == 0)
check("reach: the furthest band that still lands one in four", (tacM1Reach()) == 6 and select(2, tacM1Reach()) == true)
check("reach: swing inside it", tacM1InReach(foe, 6.5) == true)
check("reach: not from where swings meet air", tacM1InReach(foe, 9) == false)
ME.HRP.AssemblyLinearVelocity = Vector3.new(0, 0, -20); foe.HRP.Position = Vector3.new(0, 0, -9)
check("reach: unless the gap is closing fast enough", tacM1InReach(foe, 9) == true)
ME.HRP.AssemblyLinearVelocity = nil
Bot.LastSkill = CLOCK; local before = MEM.tactics.m1r["2"].n; swing(3, true)
check("reach: a swing with a skill in the air is not booked", MEM.tactics.m1r["2"].n == before)
Bot.LastSkill = 0; foe.info = { Block = true }; swing(3, false); foe.info = nil
check("reach: a blocked swing says nothing about reach", MEM.tactics.m1r["2"].n == before)
check("reach: the life line shows the bands", tacM1ReachSummary():find("swings by distance: 2%-4 10/10, 4%-6 6/10, 6%-8 1/10, 10%-12 0/10; reach taken as 6 studs %(measured%)") ~= nil, tacM1ReachSummary())
Config.TacM1Probe = false; check("reach: off uses the default", (tacM1Reach()) == 7); Config.TacM1Probe = true

-- v93: one reaction per sighting of a move
do
    reset(); Config.ReactLatch, Config.ReactLatchGap, Config.ReactDodgeAim = true, 0.5, false
    local foeA, foeB = mkChar("foeA", 0, -6, 0, 1), mkChar("foeB", 4, -6, 0, 1)
    PICKS, PICKN = { "block", "away", "dodge", "hold", "away", "block" }, 0
    local r1 = tacReactPick(foeA, "Rush", "rush")
    CLOCK = CLOCK + 1/60; local r2 = tacReactPick(foeA, "Rush", "rush")
    CLOCK = CLOCK + 1/60; local r3 = tacReactPick(foeA, "Rush", "rush")
    check("latch: the same move on consecutive frames gets one answer", r1 == "block" and r2 == "block" and r3 == "block" and PICKN == 1,
        string.format("%s %s %s after %d draws", r1, r2, r3, PICKN))
    CLOCK = CLOCK + 0.3
    check("latch: a gap under half a second does not break it", tacReactPick(foeA, "Rush", "rush") == "block" and PICKN == 1)
    CLOCK = CLOCK + 1/60
    check("latch: a different move draws again", tacReactPick(foeA, "Beam", "beam") == "away" and PICKN == 2)
    CLOCK = CLOCK + 1/60
    check("latch: and that answer is kept in its turn", tacReactPick(foeA, "Beam", "beam") == "away" and PICKN == 2)
    CLOCK = CLOCK + 0.6
    check("latch: unseen for half a second, the next sighting draws again", tacReactPick(foeA, "Beam", "beam") == "dodge" and PICKN == 3)
    CLOCK = CLOCK + 1/60
    check("latch: the same move from somebody else is another sighting", tacReactPick(foeB, "Beam", "beam") == "hold" and PICKN == 4)
    check("latch: sightings are counted", Life.reactLatch == 4, Life.reactLatch)
    PICKS, PICKN = {}, 0
    CLOCK = CLOCK + 1
    check("latch: nothing learned falls back on the plan for the family", tacReactPick(foeB, "Grab", "grab") == "away" and tacReactPick(foeB, "Odd", nil) == "block")
    Config.ReactLatch = false; PICKN = 0
    tacReactPick(foeB, "Beam", "beam"); tacReactPick(foeB, "Beam", "beam")
    check("latch: off draws on every frame, as before", PICKN == 2)
    Config.ReactLatch = true
end

-- v93: a learned dodge has a direction
do
    reset(); Config.ReactDodgeAim = true
    local keepCentre = mapArenaCentre
    local foeA = mkChar("foeA", 0, -6, 0, 1)                        -- in front of us
    mapArenaCentre = function() return Vector3.new(50, 0, 0) end
    local sv, side = tacSideVec(ME.HRP, foeA.HRP)
    check("dodge: sideways from the attacker, toward the middle", sv.X > 0.9 and sv.Z > 0 and near(sv.Magnitude, 1, 0.001) and side == "right",
        string.format("%.2f,%.2f %s", sv.X, sv.Z, tostring(side)))
    mapArenaCentre = function() return Vector3.new(-50, 0, 0) end
    sv, side = tacSideVec(ME.HRP, foeA.HRP)
    check("dodge: the other side when the middle is there", sv.X < -0.9 and sv.Z > 0 and side == "left")
    check("dodge: no attacker, no direction", tacSideVec(ME.HRP, nil) == nil)
    PICKS, PICKN = { "dodge", "block" }, 0; LOG = {}
    check("dodge: latching a dodge sets where to", tacReactPick(foeA, "Beam", "beam") == "dodge" and Bot.ReactDir ~= nil and Bot.ReactDir.X < -0.9)
    check("dodge: the log line names the side", LOG[1] ~= nil and LOG[1]:find("dodge: Beam from foeA - stepping out to the left", 1, true) ~= nil, LOG[1])
    Bot.ReactDir = Vector3.new(0, 0, 1); CLOCK = CLOCK + 1/60; tacReactPick(foeA, "Beam", "beam")
    check("dodge: kept for the sighting, whatever wrote over it", Bot.ReactDir.X < -0.9)
    CLOCK = CLOCK + 1; Bot.ReactDir = Vector3.new(0, 0, 1)
    check("dodge: a block leaves the direction alone", tacReactPick(foeA, "Beam", "beam") == "block" and Bot.ReactDir.Z == 1)
    Config.ReactDodgeAim = false; PICKS, PICKN = { "dodge" }, 0; CLOCK = CLOCK + 1
    tacReactPick(foeA, "Beam", "beam"); check("dodge: off is off", Bot.ReactDir.Z == 1)
    Config.ReactDodgeAim = true; mapArenaCentre = keepCentre
end

-- v93: stunned or down, unless merely carrying something
do
    reset()
    check("helpless: free to act", tacHelpless() == false and tacRooted() == false)
    ME.stun = true; check("helpless: stunned", tacHelpless() == true and tacRooted() == true)
    ME.holding = true; check("helpless: carrying a throwable sets Stun and is not it", tacHelpless() == false and tacRooted() == false)
    ME.holding = nil; ME.stun = nil; ME.rag = true; check("helpless: on the ground", tacHelpless() == true and tacRooted() == true)
    ME.rag = nil; ME.inSkill = true
    check("helpless: in a move of our own we cannot walk but are not helpless", tacHelpless() == false and tacRooted() == true)
    ME.inSkill = nil
    -- the guard against somebody getting up keeps its half second
    Config.TacBlockMin, Config.TacWakeWindow = 0.3, 0.5
    Bot.BlockSince = CLOCK; check("keep: an ordinary block is kept 0.3 s", tacBlockKeepFor() == 0.3)
    Bot.WakeGuardAt = CLOCK; check("keep: the wake-up guard its whole window", tacBlockKeepFor() == 0.5)
    Bot.BlockSince = CLOCK + 2; check("keep: the next block is ordinary again", tacBlockKeepFor() == 0.3)
    Bot.BlockSince = Bot.WakeGuardAt; Config.ReactLatch = false; check("keep: off is off", tacBlockKeepFor() == 0.3)
    Config.ReactLatch = true
end

-- v93: the dash punch from further out
do
    reset(); Config.BlockChaseRange = 20
    local dasher = mkChar("dasher", 0, -18, 0, 1)                   -- 18 studs in front, looking straight at us
    check("chase: a dash aimed at us is seen from 18 studs", tacChaseSeen(dasher, "Chase", 18, 12) == true)
    check("chase: an ordinary swing is not", tacChaseSeen(dasher, "Melee1", 18, 12) == false)
    check("chase: nor a dash from beyond its slide", tacChaseSeen(dasher, "Chase", 21, 12) == false)
    dasher.HRP.CFrame.LookVector = Vector3.new(0.7071, 0, 0.7071)   -- 45 degrees off
    check("chase: nor a dash aimed past us", tacChaseSeen(dasher, "Chase", 18, 12) == false)
    dasher.HRP.CFrame.LookVector = Vector3.new(0.5, 0, 0.866)       -- 30 degrees off
    check("chase: 30 degrees off still counts", tacChaseSeen(dasher, "MeleeChase", 18, 12) == true)
    Config.BlockChaseRange = 0; check("chase: 0 switches it off", tacChaseSeen(dasher, "Chase", 18, 12) == false)
    Config.BlockChaseRange = 20
    Bot.DefendVsSince, Bot.DefendVsFarAt = CLOCK, CLOCK
    check("chase: a latch made far out is kept that far out", tacSwingKeep(12) == 20)
    Bot.DefendVsSince = CLOCK + 1; check("chase: the next latch is an ordinary one", tacSwingKeep(12) == 12)
    check("route: followed for 1.5 s once something was in the way", (function() Config.PathLean = true; return tacPathCommit() end)() == 1.5)
    check("route: three seconds with the switch off", (function() Config.PathLean, Config.PathCommit = false, 3; return tacPathCommit() end)() == 3)
    Config.PathLean = true
end

-- v93: the measurement pack
do
    reset(); Config.TacBlockProbe, Config.TacM1Probe = true, false
    Bot.State = "DEFEND"
    tacProbeBlockUp(CLOCK); CLOCK = CLOCK + 0.05; tacProbeTick(0.05)
    check("probe: a block not yet taken is pending", Life.pbRaised == 1 and (Life.pbAccepted or 0) == 0 and Bot.ProbeBlockAt ~= nil)
    ME.info = { Block = true }; CLOCK = CLOCK + 0.05; tacProbeTick(0.05)
    check("probe: our own Block inside 0.2 s is an accepted block", Life.pbAccepted == 1 and Bot.ProbeBlockAt == nil and near(Life.pbDelay, 0.1, 0.001))
    ME.info = nil; tacProbeBlockUp(CLOCK); CLOCK = CLOCK + 0.25; tacProbeTick(0.25)
    ME.info = { Block = true }; CLOCK = CLOCK + 0.05; tacProbeTick(0.05); ME.info = nil
    check("probe: one that shows after 0.2 s is not", Life.pbRaised == 2 and Life.pbAccepted == 1)
    tacProbeAbsorbed(); check("probe: a hit taken on the block is counted", Life.pbAbsorbed == 1)
    Bot.State = "ATTACK"; tacProbeTick(1.5)
    check("probe: seconds in each state", near(Life.stSec.DEFEND, 0.4, 0.001) and near(Life.stSec.ATTACK, 1.5, 0.001))
    tacProbeReversal("APPROACH", "DEFEND"); tacProbeReversal("APPROACH", "DEFEND"); tacProbeReversal("DEFEND", "APPROACH"); tacProbeReversal(nil, "ATTACK")
    check("probe: reversals by the two states they fell between", Life.revPair["APPROACH>DEFEND"] == 2 and Life.revPair["DEFEND>APPROACH"] == 1 and Life.revPair["?>ATTACK"] == 1)
    Tac.m1Step = nil; Bot.M1Active = true
    ME.attrs.CurrentM1 = 1; tacM1Tick(); ME.inSkill = true; ME.attrs.CurrentM1 = 2; tacM1Tick(); ME.inSkill = nil
    check("probe: swings thrown with our own InSkill set", Life.m1Swings == 2 and Life.pbSwingSkill == 1,
        string.format("%s of %s", tostring(Life.pbSwingSkill), tostring(Life.m1Swings)))
    local fullPct = getHPPct
    getHPPct = function(c) if c then return fullPct(c) end return 34 end
    LOG = {}; Bot.State = "RETREAT"; tacProbeTick(0.016); tacProbeTick(0.016)
    check("probe: our health is logged while under half", #LOG == 1 and LOG[1]:find("health: 34% | RETREAT | no target", 1, true) ~= nil, LOG[1])
    CLOCK = CLOCK + 2.1; tacProbeTick(0.016); check("probe: every two seconds", #LOG == 2)
    getHPPct = fullPct; CLOCK = CLOCK + 2.1; tacProbeTick(0.016); check("probe: not above half", #LOG == 2)
    Config.TacBlockProbe = false; tacProbeBlockUp(CLOCK); tacProbeAbsorbed(); tacProbeTick(1); tacProbeReversal("A", "B")
    check("probe: off counts nothing", Life.pbRaised == 2 and Life.pbAbsorbed == 1 and Life.revPair["A>B"] == nil and near(Life.stSec.RETREAT, 0.064, 0.001))
    Config.TacBlockProbe, Config.TacM1Probe = true, true
end

-- v93: what stopped a block is named on the hit line
do
    reset(); Config.TacBlockProbe, Config.TacLedger = true, true
    local hitter = mkChar("hitter", 0, -6, 0, 1)
    Tac.lastState = "ATTACK"; Tac.selfWokeAt = 0; Tac.m1StepAt = 0
    tacBlockGate("the 0.3 s rest after the last block"); CLOCK = CLOCK + 0.1
    LOG = {}; tacOpener(hitter, "Todo:Melee1")
    check("gate: named on the hit line", LOG[1]:find("| block stopped by the 0.3 s rest after the last block, 0.10 s before", 1, true) ~= nil, LOG[1])
    CLOCK = CLOCK + 1; LOG = {}; tacOpener(hitter, "Todo:Melee1")
    check("gate: an old gate is not blamed", LOG[1]:find("block stopped", 1, true) == nil, LOG[1])
    tacBlockGate("the rest after a dropped guard", CLOCK + 2.5); LOG = {}; tacOpener(hitter, "Todo:Melee1")
    check("gate: a timer says how long it had to run", LOG[1]:find("block stopped by the rest after a dropped guard (2.5 s more to run), 0.00 s before", 1, true) ~= nil, LOG[1])
    Bot.BlockActive = true; LOG = {}; tacOpener(hitter, "Todo:Melee1")
    check("gate: nothing stopped a block that was up", LOG[1]:find("block stopped", 1, true) == nil, LOG[1])
    Bot.BlockActive = false
end

-- v93: a frame parked in a path compute does not carry on when it comes back.
-- computePath and navigateTo are the file's own; the compute is a coroutine yield.
do
    reset(); Config.FrameStaleGuard = true
    Bot.FrameSeq, Bot.RunEpoch, Bot.PathSec, Bot.PathBusy = 0, 1, 0, false
    local dashed, walked, errs = 0, 0, {}
    navigateToInner = function(t, dest) computePath(dest); walked = walked + 1 end
    local function frame()
        local co = coroutine.create(function()
            local ok, err = pcall(function()
                Bot.FrameSeq = Bot.FrameSeq + 1
                navigateTo(nil, Vector3.new(0, 0, -40))
                dashed = dashed + 1                     -- what executeState does after navigateTo
            end)
            if not ok and not tacStaleCaught(err) then errs[#errs + 1] = tostring(err) end
        end)
        local okR, errR = coroutine.resume(co)
        if not okR then errs[#errs + 1] = tostring(errR) end
        return co
    end
    YIELD = false; frame()
    check("stale: a compute that does not park changes nothing", dashed == 1 and walked == 1 and (Life.staleFrames or 0) == 0 and #errs == 0, errs[1])
    Bot.PathPoints = nil
    YIELD = true; local parked = frame()
    check("stale: the frame is parked in the compute", coroutine.status(parked) == "suspended" and Bot.PathBusy == true and dashed == 1)
    YIELD = false; frame()
    check("stale: other frames run meanwhile", dashed == 2 and walked == 2 and Bot.PathBusy == true)
    coroutine.resume(parked)
    check("stale: back, it adopts the route it waited for", coroutine.status(parked) == "dead" and Bot.PathPoints ~= nil and Bot.PathBusy == false and walked == 3)
    check("stale: and stops there, no dash on old numbers", dashed == 2 and Life.staleFrames == 1 and #errs == 0 and Bot.PathSec == 0, errs[1])
    -- stopped and started again while parked
    YIELD = true; parked = frame()
    Bot.RunEpoch = Bot.RunEpoch + 1; Bot.PathBusy = true            -- the new run has a compute of its own in flight
    coroutine.resume(parked)
    check("stale: a frame of the last run touches nothing", Bot.PathBusy == true and walked == 3 and dashed == 2 and Life.staleFrames == 2 and #errs == 0, errs[1])
    Bot.PathBusy = false
    local realErr = pcall(function() tacEpochCheck(Bot.RunEpoch); tacFrameCheck(Bot.FrameSeq) end)
    check("stale: no change, no marker", realErr == true)
    check("stale: a real error is still an error", tacStaleCaught("attempt to index a nil value") == false and Life.staleFrames == 2)
    -- switched off: the old behaviour
    Config.FrameStaleGuard = false
    YIELD = true; parked = frame(); YIELD = false; frame(); coroutine.resume(parked)
    check("stale: off, the parked frame carries on as it used to", dashed == 4 and Life.staleFrames == 2 and #errs == 0, errs[1])
    Config.FrameStaleGuard = true; YIELD = false
end

-- v93: the new part of the life line
do
    reset(); Config.TacBlockProbe = true
    Life.pbRaised, Life.pbAccepted, Life.pbAbsorbed, Life.pbDelay = 12, 9, 4, 0.9
    Life.stSec = { ATTACK = 41.26, APPROACH = 30, CCED = 22.5 }
    Life.revPair = { ["APPROACH>DEFEND"] = 9, ["DEFEND>APPROACH"] = 7, ["ATTACK>REACT"] = 3, ["IDLE>IDLE"] = 1 }
    Life.pbSwingSkill, Life.m1Swings, Life.flushN, Life.flushMax = 12, 84, 31, 0.014
    Life.pathSeen, Life.pathN, Life.staleFrames, Life.reactLatch = 12, 20, 18, 7
    local pl = tacProbeSummary()
    check("life line: blocks raised, accepted, absorbed", pl:find("blocks raised/accepted/absorbed 12/9/4 (accepted after 100 ms);", 1, true) ~= nil, pl)
    check("life line: seconds per state, longest first", pl:find("state s ATTACK 41.3, APPROACH 30.0, CCED 22.5;", 1, true) ~= nil, pl)
    check("life line: the top three reversal pairs", pl:find("reversals between APPROACH>DEFEND x9, DEFEND>APPROACH x7, ATTACK>REACT x3;", 1, true) ~= nil, pl)
    check("life line: swings and flushes", pl:find("swings in a skill 12 of 84; log flushes 31 (worst 14 ms)", 1, true) ~= nil, pl)
    check("life line: path and frames", pl:find("| path: 12 of 20 computes with the target in sight; stale frames 18; reactions latched 7", 1, true) ~= nil, pl)
    Life = { tac = {} }
    check("life line: an empty life does not error", tacProbeSummary():find("blocks raised/accepted/absorbed 0/0/0 (accepted after 0 ms); state s none; reversals between none;", 1, true) ~= nil, tacProbeSummary())
    Config.TacBlockProbe = false
    check("life line: the probe says when it is off", tacProbeSummary():find("| probe: off | path: 0 of 0", 1, true) ~= nil, tacProbeSummary())
    Config.TacBlockProbe = true
end

-- honest books and clean starts (v93, second half)
reset(); Config.KillCredit, Config.KillCreditMin = true, 15
foe = mkChar("foe", 0, -6, 0, 1)
Bot.TargetDmg0 = 40; Life.dmg = 44
check("kill: a death we barely touched is not our kill", tacKillCredit(foe) == false)
Life.dmg = 70; check("kill: one we dealt real damage to is", tacKillCredit(foe) == true)
Config.KillCredit = false; Life.dmg = 40; check("kill: off counts everything", tacKillCredit(foe) == true); Config.KillCredit = true
local killer = mkChar("killer", 3, 3, 0, 1); Bot.Target = foe; Bot.Aggressor, Bot.AggressorAt = killer, CLOCK - 2
check("death: booked to whoever was hitting us", tacDeathBy() == killer)
Bot.AggressorAt = CLOCK - 20; check("death: not to an attacker from long ago", tacDeathBy() == foe)
Bot.Target = nil; Bot.AggressorAt = CLOCK - 1; check("death: with no target left, still the attacker", tacDeathBy() == killer)
Threat = { [foe] = 30, [killer] = 34 }; CLEARED = 0
memPendingClear = function() CLEARED = CLEARED + 1 end; clearPath = function() CLEARED = CLEARED + 10 end
Bot.ReactDir, Bot.ReactLatched, Bot.RecoverHold = Vector3.new(1, 0, 0), { move = "x" }, { at = 0, hp0 = 10 }
tacLifeReset()
check("respawn: threat, pending casts, the reaction and the route are dropped",
    next(Threat) == nil and CLEARED == 11 and Bot.ReactDir == nil and Bot.ReactLatched == nil and Bot.RecoverHold == nil)
-- the recover hold
reset(); Config.RecoverHold, Config.RecoverHoldHP, Config.RecoverHoldFor, Config.RecoverHoldDist = true, 40, 20, 30
local realHP, realHitter = getHPPct, hitterLive
MYHP = 22; getHPPct = function(c) if c then return c.hp or 100 end return MYHP end
hitterLive = function(c) return c.hitting == true end
check("hold: not in force until an escape", tacRecoverHold() == false)
tacRecoverStart(); check("hold: starts after an escape while hurt", tacRecoverHold() == true)
local farC, nearC, biterC = mkChar("far", 0, -60, 0, 1), mkChar("near", 0, -10, 0, 1), mkChar("biter", 0, -60, 0, 1); biterC.hitting = true
check("hold: no new fight at a distance", tacRecoverBars(farC, 60) == true)
check("hold: somebody close is still fought", tacRecoverBars(nearC, 10) == false)
check("hold: somebody hitting us is still fought", tacRecoverBars(biterC, 60) == false)
MYHP = 45; LOG = {}; check("hold: over once health is back", tacRecoverHold() == false and Bot.RecoverHold == nil)
check("hold: the rate of recovery is logged", #LOG == 1 and LOG[1]:find("recover hold over") ~= nil and LOG[1]:find("22%% to 45%%") ~= nil, LOG[1])
MYHP = 22; tacRecoverStart(); CLOCK = CLOCK + 21; check("hold: or once the time is up", tacRecoverHold() == false)
MYHP = 80; tacRecoverStart(); check("hold: not started at good health", Bot.RecoverHold == nil)
Config.RecoverHold = false; MYHP = 10; tacRecoverStart(); check("hold: off is off", Bot.RecoverHold == nil and tacRecoverBars(farC, 60) == false)
Config.RecoverHold = true; getHPPct, hitterLive = realHP, realHitter
-- seeds
reset(); Config.KnowSeedSkip = true
MoveRules["Nue"] = { min = 0, max = 60, prio = 3, summon = true }
MEM.global.moves["Transcend"] = { tries = 6, hits = 0 }
MEM.global.moves["Nue"] = { tries = 19, hits = 2 }
MEM.global.moves["Reversal Red"] = { tries = 20, hits = 2 }
knowChance("Reversal Red", "free")
check("seed: an ordinary move is still seeded", MEM.facts["Reversal Red"] ~= nil and MEM.facts["Reversal Red"].seeded == true)
check("seed: a two-press move the old build only tapped is not", MEM.facts["Transcend"] == nil)
check("seed: a summon whose damage comes late is not", MEM.facts["Nue"] == nil)
-- seeded evidence does not close a question: real casts do
foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100; Config.KnowProbe = true
local okS = knowAllows(entry("Reversal Red"), foe, 6, "neutral")
check("seed: a seeded low belief can still be probed", okS == true and Bot.KnowProbePending ~= nil)
for i = 1, 3 do
    local q = { move = "Reversal Red", target = foe, hp0 = 100, at = CLOCK, dist = 6 }
    knowStamp(q, foe); knowBook(q, 100)
end
Life.knowProbes, Bot.KnowProbeAt = 0, 0
check("seed: three real misses close it", knowAllows(entry("Reversal Red"), foe, 6, "neutral") == false)

-- what the v93 log measured (v94)
reset(); Config.RetreatHP, Config.GuardWhenLow, Config.PunishGuardLock = 25, true, 0.6
check("guard: allowed at low health", tacCanGuard(12) == true)
Config.GuardWhenLow = false; check("guard: unless switched back", tacCanGuard(12) == false and tacCanGuard(60) == true); Config.GuardWhenLow = true
Bot.PunishUntil = CLOCK + 3; check("guard: off while the punish itself goes out", tacCanGuard(60) == false)
CLOCK = CLOCK + 0.7; check("guard: back on for the rest of the punish window", tacCanGuard(60) == true)
Bot.PunishUntil = CLOCK + 2; check("guard: a new punish window locks it again", tacCanGuard(60) == false)
reset(); Config.TacSpacing, Config.TacSpaceTo, Config.M1Range, Config.TacM1Probe = true, 4.5, 7, true
check("spacing: six studs until measured", tacM1Good() == 6)
MEM.tactics = { m1r = { ["2"] = { n = 30, h = 18 }, ["4"] = { n = 42, h = 38 }, ["6"] = { n = 27, h = 12 }, ["12"] = { n = 28, h = 2 } } }
check("spacing: the good reach is where half the swings land", tacM1Good() == 6 and (tacM1Reach()) == 8)
WALKED = nil; walkTo = function(p) WALKED = p end
foe = mkChar("foe", 0, -8, 0, 1); foe.hpv = 100
check("spacing: steps in from the edge of reach", tacStepIn(foe, 8) == true and WALKED ~= nil and near(WALKED.Z, -3.5, 0.01))
WALKED = nil; check("spacing: stands when already close", tacStepIn(foe, 5) == false and WALKED == nil)
foe.rag = true; check("spacing: does not walk onto a body on the ground", tacStepIn(foe, 8) == false); foe.rag = nil
check("spacing: no swings at air", tacTooFar(12) == true and tacTooFar(8) == false)
Config.TacSpacing = false; check("spacing: off is off", tacStepIn(foe, 8) == false and not tacTooFar(12)); Config.TacSpacing = true
-- a raw cast up close needs a better chance
reset(); Config.KnowMinPClose, Config.KnowCloseDist, Config.KnowProbe = 0.4, 14, false
foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100
local okC, pC = knowAllows(entry("Twofold Kick"), foe, 6, "neutral")
check("close: an unproven raw cast is withheld in their reach", okC == false and near(pC, 0.35, 0.01), pC)
check("close: the same cast is allowed from range", knowAllows(entry("Reversal Red"), foe, 30, "neutral") == true)
MEM.facts["Twofold Kick"] = { n = 10, s = { free = { n = 10, h = 6, r = 10 } } }
check("close: a cast proven to land raw is still thrown", knowAllows(entry("Twofold Kick"), foe, 6, "neutral") == true)
MEM.facts["Twofold Kick"] = nil; foe.stun = true; Know.stT = nil
check("close: a chained cast is not held to it", knowAllows(entry("Twofold Kick"), foe, 6, "confirm") == true)
Config.KnowProbe = true

-- v95
reset(); Config.KnowMinPClose, Config.KnowCloseDist, Config.KnowContactClose, Config.KnowProbe = 0.45, 14, true, false
foe = mkChar("foe", 0, -18, 0, 1); foe.hpv = 100
MoveRules["Sacrilege"] = { min = 0, max = 20, prio = 4 }
check("contact: a rush thrown raw from 18 studs still ends in their reach", knowAllows(entry("Sacrilege"), foe, 18, "neutral") == false)
check("contact: a shot from 18 studs does not", knowAllows(entry("Reversal Red"), foe, 18, "neutral") == true)
foe.stun = true; Know.stT = nil; check("contact: the same rush chained is fine", knowAllows(entry("Sacrilege"), foe, 6, "confirm") == true)
Config.KnowProbe = true
reset(); Config.KnowCounterMinP = 0.5
foe = mkChar("foe", 0, -6, 0, 1); foe.hpv = 100; foe.swing = true; USABLE = { entry("Manji Kick") }
check("counter: thrown while unproven", knowTryCounter(foe, CLOCK, false) == true)
reset(); foe.swing = true; USABLE = { entry("Manji Kick") }; MEM.facts["Manji Kick"] = { n = 7, s = { swing = { n = 7, h = 1, r = 7 } } }
check("counter: not once it has been shown to fail (the block is better)", knowTryCounter(foe, CLOCK, false) == false)
MEM.facts["Manji Kick"] = { n = 11, s = { swing = { n = 11, h = 7, r = 11 } } }
check("counter: kept when it works", knowTryCounter(foe, CLOCK, false) == true)
reset(); Config.TacWakeBlock, Config.TacWakeBlockFor, Config.UseBlock = true, 0.45, true
local beside, away2 = mkChar("beside", 0, -6, 0, 1), mkChar("away", 0, -40, 0, 1)
Bot.HitCandidates = { away2 }; check("wake block: nobody beside us, nothing", tacWakeBlock(CLOCK) == false)
Bot.HitCandidates = { away2, beside }
check("wake block: somebody beside us, the guard window opens on them",
    tacWakeBlock(CLOCK) == true and Bot.PreGuardVs == beside and Bot.PreGuardUntil > CLOCK and Life.wakeBlock == 1)
check("wake block: the guard decision keeps it", tacIncoming() == true and Bot.DefendVs == beside)
beside.stun = true; Bot.PreGuardUntil = 0; check("wake block: not for somebody who cannot act", tacWakeBlock(CLOCK) == false); beside.stun = nil
Config.TacWakeBlock = false; check("wake block: off is off", tacWakeBlock(CLOCK) == false); Config.TacWakeBlock = true
ME.rag = true; tacSelfTick(CLOCK); ME.rag = nil; Bot.PreGuardUntil = 0; CLOCK = CLOCK + 0.5; tacSelfTick(CLOCK)
check("wake block: fires on getting up", Bot.PreGuardVs == beside and Bot.PreGuardUntil > CLOCK)

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
lua.execute(src[a4:b4])
lua.execute(combat)
# v93: the file's own computePath and the navigateTo wrapper, for the parked-frame test
a5 = src.index('function computePath(destination, goalKey)'); b5 = src.index('function followPath()')
a6 = src.index('function navigateTo(t, destination)'); b6 = src.index('\nend\n', a6) + 5
lua.execute(src[a5:b5]); lua.execute(src[a6:b6])
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
# round trip: the life line the bot writes must be the line the analyser reads
tail = lua.eval('''(function()
    Life = { tac = { confirm = { n = 5, h = 4, d = 40 }, neutral = { n = 8, h = 2, d = 18 }, punish = { n = 2, h = 1, d = 9 } },
        tacCombo = 5, tacGuard = 6, tacGuardHit = 3, tacPunish = 1, tacLead = 2, tacGated = 4, m1Swings = 30, m1Hits = 14, m1Dmg = 46,
        moveN = 100, moveBack = 3, tacDamped = 7, flipBy = { ["APPROACH/path"] = 5 }, tacBlockKept = 2,
        knowHeld = 11, knowWhy = { block = 6, rag = 2 }, knowProbes = 2, knowCounter = 1, knowBreak = 3, knowGround = 2, m1HeldSec = 4.4,
        fin = { down = { n = 2, net = 9 }, up = { n = 1, net = -4 } }, lateStamp = 1, p2Sent = 4, p2Cast = 5, p2Lost = 1,
        open = { ["mid-swing"] = 6, ["after a cast"] = 3, ["closing in"] = 2 }, openN = 11, wakeSwing = 2, wakeGuard = 3, wakeStunned = 0,
        holdCasts = 1, ultWaited = 9, dashOpen = 4, dashOpenHit = 3, taken = 180, castFaced = 12, castTurned = 5,
        pbRaised = 12, pbAccepted = 9, pbAbsorbed = 4, pbDelay = 0.9, pbSwingSkill = 7, flushN = 31, flushMax = 0.014,
        stSec = { ATTACK = 41.26, APPROACH = 30, CCED = 22.5 }, revPair = { ["APPROACH>DEFEND"] = 9, ["DEFEND>APPROACH"] = 7, ["ATTACK>REACT"] = 3, ["IDLE>IDLE"] = 1 },
        pathSeen = 12, pathN = 20, staleFrames = 18, reactLatch = 7 }
    Config.TacBlockProbe = true
    return tacLifeSummary() .. knowLifeSummary() .. tacOpenerSummary() .. tacOpenSummary() .. tacM1ReachSummary() .. tacProbeSummary()
end)()''')
import os, tempfile, importlib.util
spec = importlib.util.spec_from_file_location('analyze_log', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'analyze_log.py'))
al = importlib.util.module_from_spec(spec); spec.loader.exec_module(al)
with tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False) as fh:
    fh.write('[1] LIFE END: 200 dmg in 100s (2.0 dmg/s, 15 moves, 90% engaged, 5 blocks, 20s stunned) | Toji | stunned by: Todo:Melee1 x3, Todo:Chase x1 | ff: 0 | refused 2 (rolled back 2), burst 3/1, kite 0s' + tail + '\n')
    tmp = fh.name
r = al.analyse(tmp); os.unlink(tmp); S = r['S']
want = dict(held=11, probes=2, kcounters=1, breaks=3, ground=2, late=1, p2_sent=4, p2_cast=5, p2_lost=1, openN=11, wake_swing=2, wake_guard=3,
            hold_casts=1, dash=4, dash_hit=3, taken=180, cast_turned=5, cast_faced=12, confirm_h=4, confirm_n=5, neutral_n=8, m1_n=30, m1_h=14, combos=5, preguard=6, preguard_met=3, refused=2,
            blk_raised=12, blk_accepted=9, blk_absorbed=4, blk_delay_ms=100, swing_inskill=7, swing_probe_n=30, flushes=31, flush_worst=14,
            path_seen=12, path_n=20, stale=18, latched=7)
rt = [k for k, v in want.items() if S[k] != v]
if r['opens'].get('mid-swing') != 6 or r['fins']['down'][0] != 2 or r['stun_by'].get('front-dash punch') != 1: rt.append('categories')
if abs(r['state_sec'].get('ATTACK', 0) - 41.3) > 0.01 or r['state_sec'].get('CCED') != 22.5 or len(r['state_sec']) != 3: rt.append('state seconds')
if r['rev_pairs'].get('APPROACH>DEFEND') != 9 or r['rev_pairs'].get('ATTACK>REACT') != 3 or len(r['rev_pairs']) != 3: rt.append('reversal pairs')
print('analyser round trip: %d fields, %d wrong %s' % (len(want) + 3, len(rt), rt if rt else ''))
sys.exit(1 if (fails or kfails or rt) else 0)
