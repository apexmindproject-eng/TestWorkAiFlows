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
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(MOCK)
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
