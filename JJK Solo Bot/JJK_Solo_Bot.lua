--[[
    JJK SOLO BOT -- the single-fighter build (JJK-SOLO-v83).

    One account, one fighter, no role. Everything the phone build did for the
    PC's team bridge is gone: the guard-account gate, the LAN bridge and its
    network self-test, the ally list, the four-kit whitelist, the team roles
    (GUARD / PEEL / SUPPORT / KITE / BREAK) and the formation code that read
    them. The bot picks its own targets and plays its own fights on any
    account that runs it.

    The graphics kill is gone too: nothing is forced to quality 1, no post
    effect is disabled, and 3D rendering is never switched off while the bot
    fights. The screen stays on. The one thermal lever a phone needs, an fps
    cap plus the quality floor, is a rune in the HUD ("Ember mode"), off by
    default.

    Nothing auto-starts. The Eye is opened from the HUD.
]]
do
    local Players = game:GetService("Players")
    local me = "?"
    pcall(function() me = Players.LocalPlayer.Name end)
    local ENV = (typeof(getgenv) == "function" and getgenv()) or _G
    local function say(m) print("[JJK-Solo] " .. me .. ": " .. tostring(m)) end

    if type(ENV.JJK_AUTOFIGHT_STOP) == "function" and not ENV.JJK_FORCE_RELOAD then
        say("hub already running in this client - not reloading")
        return
    end

    -- Executor paths read by the hub as it starts. JJK_Phone keeps the Knit
    -- remote lookup and the per-session file log (there is no readable client
    -- log on a phone executor, so the hub's own log is the only record).
    ENV.JJK_Phone = true
    ENV.JJK_FileLog = true
    ENV.JJK_LogFlushEvery = 20
    ENV.JJK_LogMaxLines = 3000
    ENV.JJK_LogMaxPending = 300
    ENV.JJK_ConfigOverride = {
        MemSaveEvery = 120,         -- the 0.8 MB memory need not be re-encoded every 45 s
        MapMaxCells = 500,
        HazardScanEvery = 0.10,     -- per-frame scans were sized for a PC
        ScoreEvery = 0.25,
        FrontierRays = 16,
        SwitchRespawnTimeout = 6,   -- a switch lands slower on a phone
        CastVerifyDelay = 0.5,
    }
    -- No kit whitelist: every character is in the rotation and the memory
    -- decides which ones are worth playing.
    ENV.JJK_CharAllow = nil
    ENV.JJK_TeamUrl = nil

    -- Anti-idle: Roblox kicks a client after 20 min without input; scripted
    -- movement does not count. A mouse nudge through VirtualUser does. No
    -- clicks (M2 is a move here) and no keys (every key is a move).
    if not ENV.JJK_ANTI_IDLE then
        ENV.JJK_ANTI_IDLE = true
        local vu = nil
        pcall(function() vu = game:GetService("VirtualUser") end)
        local nudges = 0
        local function nudge(why)
            if not vu then return end
            local ok = pcall(function()
                vu:CaptureController()
                vu:MoveMouse(Vector2.new(nudges % 2 == 0 and 3 or -3, 0))
            end)
            nudges = nudges + 1
            if ok and (nudges <= 2 or nudges % 10 == 0) then say("anti-idle: nudge #" .. nudges .. " (" .. why .. ")") end
        end
        if vu then
            pcall(function() Players.LocalPlayer.Idled:Connect(function() nudge("idled") end) end)
            task.spawn(function() while true do task.wait(300) nudge("timer") end end)
            say("anti-idle armed")
        else
            say("anti-idle: no VirtualUser on this executor - idle kick NOT prevented")
        end
    end

    say("loading the hub (JJK-SOLO-v83)")
end


































local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer









local ACCOUNT = "unknown"
do
    local ok, n = pcall(function() return LocalPlayer.Name end)
    if ok and type(n) == "string" and #n > 0 then
        ACCOUNT = (n:gsub("[^%w_%-]", "_"))
    end
end








local JJK_ENV = (typeof(getgenv) == "function" and getgenv()) or _G
if type(JJK_ENV.JJK_AUTOFIGHT_STOP) == "function" then
    pcall(JJK_ENV.JJK_AUTOFIGHT_STOP)
    JJK_ENV.JJK_AUTOFIGHT_STOP = nil
end


local BUILD_TAG = "JJK-SOLO-v83"

local NL = string.char(10)

















local LOG = {


    enabled = (type(JJK_ENV) == "table" and JJK_ENV.JJK_FileLog == true) or false,
    canWrite = false,
    name = "JJK_AutoFight_Log_" .. ACCOUNT .. ".txt",
    lines = {},
    pending = 0,
    lastFlush = 0,
    flushEvery = (type(JJK_ENV) == "table" and tonumber(JJK_ENV.JJK_LogFlushEvery)) or 2.0,
    maxPending = (type(JJK_ENV) == "table" and tonumber(JJK_ENV.JJK_LogMaxPending)) or 40,
    maxLines = (type(JJK_ENV) == "table" and tonumber(JJK_ENV.JJK_LogMaxLines)) or 4000,
    startClock = os.clock(),
    writes = 0,
}



local WRITEFILE = nil
do
    local ok, fn = pcall(function() return writefile end)
    if ok and type(fn) == "function" then
        WRITEFILE = fn
        LOG.canWrite = true
    end
end















LOG.started = os.date("%Y-%m-%d %H:%M:%S")
if type(JJK_ENV) == "table" and JJK_ENV.JJK_Phone == true and JJK_ENV.JJK_LogPerSession ~= false then
    local prefix = "JJK_AutoFight_Log_" .. ACCOUNT .. "_"
    LOG.name = prefix .. os.date("%Y%m%d_%H%M") .. ".txt"
    pcall(function()
        local lf, df = listfiles, delfile
        if type(lf) ~= "function" or type(df) ~= "function" then return end
        local okL, files = pcall(lf, "")
        if not okL or type(files) ~= "table" then okL, files = pcall(lf, ".") end
        if not okL or type(files) ~= "table" then return end
        local old = {}
        for _, path in ipairs(files) do
            path = tostring(path)
            local at = string.find(path, prefix, 1, true)
            local base = at and string.sub(path, at) or ""
            if at and base ~= LOG.name
               and string.match(base, "^%d%d%d%d%d%d%d%d_%d%d%d%d%.txt$", #prefix + 1) then
                table.insert(old, { base = base, path = path })
            end
        end
        table.sort(old, function(a, b) return a.base > b.base end)
        for i = 5, #old do
            if not pcall(df, old[i].base) then pcall(df, old[i].path) end
        end
    end)
end

local function logFlush(force)
    if not LOG.canWrite or not WRITEFILE then return end
    if LOG.pending == 0 then return end
    if not force and (os.clock() - LOG.lastFlush) < LOG.flushEvery
       and LOG.pending < LOG.maxPending then
        return
    end

    LOG.pending = 0
    LOG.lastFlush = os.clock()

    local header = table.concat({
        "=== JJK AUTO-FIGHT LOG ===", NL,
        "build: ", BUILD_TAG, NL,
        "started: ", LOG.started or os.date("%Y-%m-%d %H:%M:%S"), NL,
        "lines: ", tostring(#LOG.lines), NL, NL,
    })

    local ok, err = pcall(function()
        WRITEFILE(LOG.name, header .. table.concat(LOG.lines, NL) .. NL)
    end)

    if ok then
        LOG.writes = LOG.writes + 1
        LOG.failStreak = 0
    else


















        LOG.failStreak = (LOG.failStreak or 0) + 1
        LOG.lastFlush = os.clock() + math.min(LOG.failStreak * 5, 30)
        if LOG.failStreak == 1 or LOG.failStreak % 10 == 0 then
            print("[AutoFight] writefile failed (x" .. LOG.failStreak .. "), will retry: " .. tostring(err))
        end
    end
end

local function debug(msg)
    local line = string.format("[%7.2f] %s", os.clock() - LOG.startClock, tostring(msg))
    if LOG.enabled and LOG.canWrite then
        table.insert(LOG.lines, line)
        if #LOG.lines > LOG.maxLines then
            table.remove(LOG.lines, 1)
        end
        LOG.pending = LOG.pending + 1
        logFlush(false)
    else
        print("[AutoFight] " .. tostring(msg))
    end
end










local debugOnceAt = {}

local function debugEvery(key, interval, msg)
    local now = os.clock()
    local last = debugOnceAt[key]
    if last and (now - last) < (interval or 1.0) then return end
    debugOnceAt[key] = now
    debug(msg)
end



local function announce(msg)
    print("[AutoFight] " .. tostring(msg))
    if LOG.canWrite then
        table.insert(LOG.lines, "** " .. tostring(msg))
        LOG.pending = LOG.pending + 1
    end
end

debug("Script starting...")



debug(string.format("clock: tick-os.time = %.0f s", tick() - os.time()))



































local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = nil
local serviceCache = {}
local missingSignals = {}
local BackendMode = "none"


local function remotesRoot()
    local knitFolder = ReplicatedStorage:FindFirstChild("Knit")
    local knitModule = knitFolder and knitFolder:FindFirstChild("Knit")
    return knitModule and knitModule:FindFirstChild("Services") or nil
end








local function makeRemoteService(folder)
    local members = {}
    return setmetatable({}, {
        __index = function(_, key)
            local hit = members[key]
            if hit ~= nil then return hit or nil end

            local re = folder:FindFirstChild("RE")
            local ev = re and re:FindFirstChild(key)
            if ev and (ev:IsA("RemoteEvent") or ev:IsA("UnreliableRemoteEvent")) then
                local sig = {}
                function sig:Fire(...) ev:FireServer(...) end
                function sig:Connect(fn) return ev.OnClientEvent:Connect(fn) end
                members[key] = sig
                return sig
            end

            local rf = folder:FindFirstChild("RF")
            local fnInst = rf and rf:FindFirstChild(key)
            if fnInst and fnInst:IsA("RemoteFunction") then
                local f = function(_, ...) return fnInst:InvokeServer(...) end
                members[key] = f
                return f
            end

            members[key] = false
            return nil
        end,
    })
end

do
    local knitFolder = ReplicatedStorage:FindFirstChild("Knit")
    local knitModule = knitFolder and knitFolder:FindFirstChild("Knit")













    local wantKnit = type(JJK_ENV) == "table" and (JJK_ENV.JJK_Phone == true or JJK_ENV.JJK_PCKnit == true)

    if not wantKnit then


        local t0 = os.clock()
        while not remotesRoot() and os.clock() - t0 < 8 do task.wait(0.25) end
        debug("Backend: PC client - require(Knit) skipped (getgenv().JJK_PCKnit = true restores it)")
    elseif knitModule and knitModule:IsA("ModuleScript") then
        local ok, res = pcall(require, knitModule)
        if ok and type(res) == "table" and type(res.GetService) == "function" then
            Knit = res
            BackendMode = "knit"
            debug("Backend: Knit client acquired (live-or-copy is decided below)")
        else
            debug("Backend: require(Knit) failed -> " .. tostring(res))
        end
    else
        debug("Backend: ReplicatedStorage.Knit.Knit not found")
    end
end

if not Knit then
    if remotesRoot() then
        BackendMode = "remotes"
        debug("Backend: no Knit client; using direct remotes")
    else
        debug("FATAL: could not acquire Knit client or its Services folder.")
        return
    end
end



local function getService(serviceName)
    if not serviceName then return nil end

    local cached = serviceCache[serviceName]
    if cached ~= nil then
        return cached or nil
    end

    if BackendMode == "remotes" then
        local root = remotesRoot()
        local folder = root and root:FindFirstChild(serviceName)
        if folder then
            local svc = makeRemoteService(folder)
            serviceCache[serviceName] = svc
            return svc
        end
        serviceCache[serviceName] = false
        debug("No service folder: " .. serviceName)
        return nil
    end

    local ok, svc = pcall(function()
        return Knit.GetService(serviceName)
    end)

    if ok and type(svc) == "table" then
        serviceCache[serviceName] = svc
        return svc
    end

    serviceCache[serviceName] = false
    debug("No service: " .. serviceName .. " (" .. tostring(svc) .. ")")
    return nil
end


local function fireRemote(serviceName, signalName, ...)
    local svc = getService(serviceName)
    if not svc then return false end

    local sig = svc[signalName]
    if not sig or type(sig) ~= "table" or type(sig.Fire) ~= "function" then







        if signalName == "Deactivated" or signalName == "RightDeactivated" then return false end
        local k = serviceName .. "." .. signalName
        if not missingSignals[k] then
            missingSignals[k] = true
            debug("No signal (once): " .. k)
        end
        return false
    end

    local args = table.pack(...)
    local ok, err = pcall(function()
        sig:Fire(table.unpack(args, 1, args.n))
    end)
    if not ok then
        debug("Fire failed " .. serviceName .. "." .. signalName .. ": " .. tostring(err))
    end
    return ok
end









do
    local t0 = os.clock()
    local unstartedSince = nil
    local ready = false
    while BackendMode == "knit" and os.clock() - t0 < 15 do
        local ok, err = pcall(function() return Knit.GetService("MovementService") end)
        if ok then ready = true break end
        if string.find(tostring(err), "until Knit has been started", 1, true) then
            unstartedSince = unstartedSince or os.clock()
            if os.clock() - unstartedSince >= 4 then break end
        end
        task.wait(0.25)
    end
    if BackendMode == "knit" and not ready then
        if remotesRoot() then
            BackendMode = "remotes"
            serviceCache = {}
        else
            debug("Backend: Knit.GetService never worked and no Services folder exists")
        end
    end
    if BackendMode == "remotes" then
        pcall(announce, string.format(
            "backend: direct remotes after %.1fs (this executor's Knit copy never starts, so RE.<Signal>:FireServer is used)",
            os.clock() - t0))
    else
        debug("Backend ready after " .. string.format("%.1f", os.clock() - t0) .. "s (knit)")
    end
end


local function getMovesetService()
    local c = LocalPlayer.Character
    local name = c and c:GetAttribute("Moveset")
    return name and (name .. "Service") or nil
end
















local MovementController = nil








if BackendMode == "knit" then
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    if ps then
        for _, d in ipairs(ps:GetDescendants()) do
            if d:IsA("ModuleScript") and d.Name == "MovementController" then
                local ok, res = pcall(require, d)
                if ok and type(res) == "table" then
                    MovementController = res
                    debug("MovementController acquired (Parkour/LockOn available)")
                else
                    debug("MovementController require failed: " .. tostring(res))
                end
                break
            end
        end
    end
end
if not MovementController then
    debug("MovementController NOT available - Parkour/LockOn off; dash drives MovementForce itself")
end



local function callMC(method, ...)
    if not MovementController then return false end
    local f = MovementController[method]
    if type(f) ~= "function" then return false end

    local args = table.pack(...)
    local ok = pcall(function() f(MovementController, table.unpack(args, 1, args.n)) end)
    if ok then return true end
    return (pcall(function() f(table.unpack(args, 1, args.n)) end))
end

local function setLockOn(target)
    if MovementController then
        pcall(function() MovementController.LockOn = target end)
    end
end


local Config = {
    Enabled = false,

    M1Range = 7,
    CloseRange = 14,
    DashRange = 30,
    RetreatHP = 25,
    UltimateHP = 15,
    BlockHP = 50,
    SkillDelay = 0.3,
    DashCooldown = 1.6,
    DashSpeed = 150,
    DashTime = 0.35,
    DashDecay = 0.90,
    DodgeCooldown = 8.0,



    CloseDashMin = 12,
    FleeSpeed = 8,
    ChaseCooldown = 1.2,
    ChaseDashCooldown = 0.7,

    MinEscape = 14,
    EscapeHold = 1.2,
    AwakenRetry = 1.0,
    AwakenMaxTries = 4,
    AwakenBackoff = 45,

    PursuitRange = 30,
    PursuitPatience = 1.5,
    PunishWindow = 3.5,
    ReverseDashRange = 9,

    Memory = true,
    MemSaveEvery = 90,






    MemMaxOpponents = 150,
    MemPruneBySignal = true,



    AllyShareRange = 25,

    RangeClamp = true,
    RangeClampOver = 15,
    RangeClampUnder = 5,
    CastRollback = true,


    FairBooking = true,





    MemRangeMinWidth = 3,


    RangeEdgeProbe = true,

    ReactCap = 20,

    ReactCrowdWeight = 0.5,
    ReactShrink = 4,
    ReactRetestLeast = true,
    ChainNoSelf = true,

    MemOppMinTries = 8,


    KitLifeCap = 2,

    CharRecentLives = 8,
    CharRecentBlend = 0.5,


    DudParole = true,

    DudParoleLives = 10,
    ComboHold = true,




    ComboHoldMax = 5,
    ComboHoldTries = 8,
    ComboHoldRatio = 2,
    ComboHoldMinDpt = 2.0,
    ComboHoldMinHP = 40,
    MemCreditWindow = 0.9,
    MemMinSamples = 3,
    MemExploreBoost = 1.18,
    MemLearnBlock = 1.4,
    MemLearnPursuit = 0.6,

    MemCreditRange = 45,
    MemCreditGrace = 2.0,

    MemRecentLives = 8,
    MemExploreSwing = 0.25,
    ComboWindow = 3.0,
    ComboWeight = 0.45,
    ChainMinSamples = 4,
    SetupWeight = 0.6,
    SetupDiscount = 0.7,
    DudMinTries = 20,
    DudFraction = 0.25,
    DudHardTries = 40,
    DudHardFloor = 0.5,
    DudHitFloor = 0.08,

    EscFloorPenalty = 0.45,
    RetreatAllyPull = 0.6,
    RetreatAllyMinHP = 55,


    RetreatAllyRange = 150,
    CharPriorLives = 10,

    MemCreditMax = 2.6,
    MemCreditCap = 45,

    StallTau = 8.0,
    StallRateFloor = 0.35,
    StallRateFrac = 0.4,
    StallGrace = 10,
    AwareRange = 60,
    SeekRange = 600,






    FrontierRays = 24,
    CorridorTests = 8,
    LookaheadProbe = 45,
    FrontierProbe = 70,
    FrontierMinClear = 12,
    FrontierUnknownBonus = 2.2,
    NavStuckWindow = 2.5,
    NavStuckDist = 4,
    OutnumberedHP = 50,
    GangedHold = 4,

    MapMemory = true,
    MapCell = 24,
    MapLayer = 20,
    MapMinTime = 4,
    MapHotRate = 3.0,
    MapRichRate = 3.5,

    MapHuntRange = 320,

    MapMaxCells = 1400,
    MapDecayAfter = 900,
    MapDecayFactor = 0.6,

    MapRunSpeed = 20,

    MapShortcutEvery = 1.0,
    MapShortcutTests = 0,



    MapKeepEstimates = false,

    MapWriteEscapes = false,

    MapThinExpire = 900,





    MapSaveThin = false,


    HeapLineEvery = 60,
    DivineDogEvery = 0.5,

    MapPruneDecay = true,

    MapShortcutRange = 120,
    MapMaxDegree = 12,
    MapMaxLOS = 4,








    Sense = true,
    DebugSense = false,
    GrabEscapeWindow = 1.2,
    BlockSignalWindow = 1.2,
    BlockSpeedMinNorm = 10,
    BlockSpeedRatio = 0.45,
    HazardScanEvery = 0.07,
    HazardRange = 220,
    HazardLead = 1.3,
    HazardMargin = 7,
    HazardMaxScan = 120,
    ReactMargin = 12,
    ReactJudgeWindow = 1.1,
    ReactMinSamples = 3,
    ReactRetest = 0.08,

    AutoRestart = true,
    RestartDelay = 1,
    AutoCharacter = true,
    CharSwitchEveryLife = true,
    CharSwitchLives = 3,
    SwitchWaitMax = 22,
    CharMinLives = 3,

    CharMaxAttempts = 3,
    CharLockExpiry = 1800,
    SwitchRespawnTimeout = 4,
    WatchdogIdle = 10,
    ChangeSpamGuard = 2.5,
    SpawnCombatWindow = 14,
    WastedLifeAfter = 80,
    WastedLifeDamage = 25,
    WastedLifeEngaged = 0.3,
    WastedLifeRetry = 30,
    CharRetryChance = 0.2,





















    CharNoRepeat = 4,
    CharBias = 2.5,
    SwitchSettle = 1.2,





    CharChangeCooldown = 15,

    MemRangeMinSamples = 10,
    MemRangeMinBucket = 3,
    MemRangeMinRate = 0.22,
    RangeProbe = true,
    RangeProbeChance = 0.25,
    RangeProbeEvery = 2.5,
    RangeProbeMax = 70,

    AdoptWindow = 1.3,
    AdoptMinDamage = 4,
    AdoptMinSamples = 4,
    Throwables = true,
    ThrowablePickupRange = 34,
















    ThrowRetry = 0.8,
    ThrowJudge = 0.5,
    ThrowGiveUp = 4,
    PickupGap = 1.0,
    ThrowRange = 60,

    Threat = true,
    ThreatRange = 45,
    ThreatFallbackRange = 180,

    ThreatTau = 7.0,
    ThreatFloor = 8,
    ThreatSkillBias = 2.5,

    AggroMemory = 6,
    NemesisFloor = 12,
    FleeChaseStick = 2.5,
    FleeEscapedFor = 4,
    EnemyMinDamage = 4,
    EnemyMinSamples = 4,
    EnemyTrialWindow = 4,
    EnemyStartTrust = 2,
    EnemyMaxTrust = 5,
    ThreatLossRatio = 1.4,
    ThreatMinRate = 0.8,
    Roam = true,
    DebugMap = false,
    PlayersOnly = true,
    AttackSummons = false,

















    Allies = {},                -- solo: nobody is a friend




    IgnorePlayers = { "Beehrus" },













    Team = false,               -- solo: no bridge, no roles


    TeamSyncEvery = 0.4,
    TeamStaleAfter = 3.0,







    TeamSpread = true,
    TeamRingSlack = 4,
    TeamRingMinDist = 16,
    TeamFollowRadius = 22,
    TeamAvoidFriendlyFire = true,
    TeamBlastMargin = 4,

    TeamBlastWidth = 6,
    TeamBlastAoEWidth = 11,
    FFMeleeBigRadius = 12,

    AllyLaneHyst = 3,
    GuardWingAngle = 40,
    SkillDelayIntent = 0.6,
    CastVerifyDelay = 0.4,
    CastRefusalHold = 2.5,
    BuffRearm = 45,
    MeleeSkillFloor = 1.0,
    UseBurst = true,
    BurstCooldown = 2.0,
    BurstRange = 12,
    LevelGraceAbove = 2.5,
    LevelAirRange = 30,






    LevelEnterMargin = 3,
    LevelReenter = 1.5,
    LevelLaunchVel = 60,
    StunRangedWindow = 0.5,
    LevelHitterMax = 4,



    TeamFollowMaxDist = 300,


    TeamRejoinMaxDist = 400,


    MaxTargetDist3D = 1500,

    LevelHitterWindow = true,

    AdoptSwinger = true,
    AdoptSwingerWindow = 1.5,
    AdoptSwingerRange = 12,
    DefendDropRest = 3,

    DefendGangedGrace = 1.0,
    SwingIncludeChase = true,

    PerchSideOnce = true,
    PaceWindow = 3,
    PaceMinRevs = 4,


    SpreadAttack = true,
    SpreadAllyRange = 20,
    SpreadAngle = 100,
    SpreadRadius = 0,
    SpreadMinDist = 9,
    HoldSidestep = true,
    HoldSidestepWindow = 3,
    HoldSidestepDist = 6,
    HoldBudget = true,
    HoldBudgetPct = 35,
    HoldBudgetMin = 12,

    LearnDiscountKillers = { "111Beast111" },


    LearnDiscountIgnored = true,
    LearnDiscountWindow = 6,
    StrongChainBoost = 1.5,
    StrongChainSamples = 8,
    StrongChainRatio = 1.5,
    StrongHoldFactor = 1.3,

    StuckGoalProgress = true,
    StuckProgressDist = 3,
    StuckProgressWindow = 2.5,
    StuckRepeatWindow = 16,
    IdleUnpocket = true,
    IdleUnpocketEvery = 2.5,
    IdleUnpocketDist = 3.5,
    StuckArc = true,
    StuckArcLen = 10,
    StuckArcRays = 12,
    StuckArcRange = 14,
    DebrisAnyAnchored = true,
    DebrisMaxSizeNamed = 12,
    BreakWalls = true,
    BreakWallSeconds = 2.2,
    BreakWallHits = 4,
    BreakWallRepeat = 8,

    PostBurstRecover = 1.2,

    BurstRecoverHP = 70,
    BurstRecoverRange = 8,
    BurstRecoverStep = 0.65,

    BurstRecoverJitter = 35,
    SwingCastGate = 0.5,

    SwingCastMin = 0.4,
    SwingPunishWindow = 1.5,

    DefendCapRest = 0.3,

    DefendUnderRetreat = true,
    DefendKeepMax = 1.0,
    DefendKeepRange = 8,
    RejoinSprintClear = true,
    RejoinHostileGap = 15,
    RegroupYieldsToTarget = true,

    MapArenaRadius = 1000,

    MapTeleportDist = 200,
    MapTeleportTime = 1.0,
    BlankSlotSkip = true,

    RejoinDashGap = 66,
    RejoinDashEvery = 4,
    CharFloorRatio = 0.8,
    CharFloorLives = 10,
    CharBenchExplore = 0.10,
    AbandonHold = 1.5,
    InterceptDist = 60,
    HostilesNearRange = 35,
    TeamWingAngle = 70,
    LaneClearStep = 6,
    AllyBodyRadius = 2,
    AllyLaneMargin = 3,
    AllyLaneRange = 90,
    FFPredict = true,
    BlockMeleeRange = 12,




    BlockHold = 0.9,
    BlockHoldMax = 2.0,

    BlockStringGap = 0.5,
    DefendLatch = 0.6,

    DefendVsMax = 1.6,

    TeamBand = 4,
    RangeHyst = 2.5,
    RotDeadbandDeg = 4,
    RotMovingScale = 0.4,
    WalkStopRadius = 1.0,
    SprintCone = 0.55,


    BlockDuration = 0.35,

    BlockChance = 0.25,
    MaxStuckTime = 2.0,

    SmoothFacing = true,
    FaceLerp = 0.30,
    PathRefresh = 1.0,
    BlockCooldown = 1.1,
    BlockRange = 13,


    BodyLock = true,
    BodyLockRange = 50,
    BodyLockLerp = 0.35,
    Sprint = true,
    SprintMinDist = 12,

    MaxVertical = 6,
    LevelTolerance = 10,


    LevelGrace = 0.6,
    LevelBand = 4,


    VerticalRepos = 14,
    VerticalReposRange = 55,
    PerchDist = 6,
    PathFailLimit = 3,
    BlacklistRange = 120,
    TargetBlacklistTime = 8,

    UseSkills = true,
    SkillGapClose = 2.0,

    DebugM1 = false,
    DebugTrace = false,
    UseSpecial = true,
    SpecialCooldown = 6.0,
    SpecialHold = 0.9,
    UseBlock = true,
    UsePathfinding = true,
    DebugDash = false,
    DebugMoves = true,
    BlockDetectTime = 2.5,
    FlankTime = 3.0,
    FlankDist = 7,
    ProbeAhead = 6,
    FeelerLen = 14,
    FeelerMinClear = 9,
    DetourLen = 12,
    DetourHold = 1.5,
    RouteCommit = 3.0,
    WaypointSkip = 3,
    LeashDeadZone = 3,
    DodgeLatch = 0.8,
    DebrisPassThrough = true,
    DebrisRadius = 14,
    DebrisEvery = 0.5,
    DebrisMaxSize = 3,


    HopStallTime = 0.35,
    HopCooldown = 1.0,
    CornerPushOff = 3,
    PathCommit = 3,
    SkillPriority = {

    },




    ScoreRange      = 220,
    CrowdRange      = 55,
    AoEClusterRange = 22,
    ScoreEvery      = 0.15,
    SwitchRatio     = 1.25,
    SwitchAbs       = 12,
    SwitchHold      = 0.6,
    DropUnreachable = 2.5,
    ChaseGiveUpDist = 90,



    ChaseGiveUpTime = 20,
    ChaseProgress   = 8,
    ChaseBlacklist  = 45,
    MatchupMinDmg   = 300,
    ChaseCalm       = 15,
    ChaseCalmDist   = 90,
    BlinkMax        = 3,
    FarPathStep     = 60,
    FarPathLimit    = 5,

    FarPathBlacklist = 20,
    ThreatRef       = 40,
    DebugTarget     = true,
    W = {
        threat = 34, prox = 22, finish = 20, reach = 16,
        engage = 10, commit = 14, crowd = 18,
        matchup = 14,
    },
}







do
    local ov = type(JJK_ENV) == "table" and JJK_ENV.JJK_ConfigOverride or nil
    if type(ov) == "table" then
        local n = 0
        for k, v in pairs(ov) do Config[k] = v; n = n + 1 end
        if n > 0 then print("[AutoFight] config: " .. n .. " overrides from the launcher") end
    end
end
IsPhone = (type(JJK_ENV) == "table" and JJK_ENV.JJK_Phone == true) or false


local Bot = {
    State = "IDLE",
    Target = nil,
    TargetDist = 0,
    LastSkill = 0,
    LastDash = 0,
    LastOffense = 0,
    FrameDmgOut = 0,
    FrameDmgIn = 0,
    Cell = nil,
    CellClass = "NEUTRAL",
    Hostiles = 0,
    NearestHostile = nil,
    Outnumbered = false,
    Stalling = false,
    TeamFollowing = false,
    TeamFollowRadius = nil,
    FollowYieldUntil = 0,
    FollowWalk = false,
    RejoinDashAt = 0,
    RejoinSince = 0,
    RejoinFrom = 0,
    RejoinDashes = 0,
    GangedUntil = 0,
    RetreatAlly = nil,
    LastPos = nil,
    LastHurtAt = 0,
    Nearby = nil,
    ThreatChar = nil,
    ThreatScore = 0,
    Attackers = 0,
    HitCandidates = {},


    Losing = false,
    Aggressor = nil,
    AggressorAt = 0,
    AggressorDmg = 0,
    LastAggroSwitch = 0,
    Nemesis = nil,
    NemesisDmg = 0,
    DmgFrom = setmetatable({}, { __mode = "k" }),
    FleeingFrom = nil,
    FleeChaseFor = 0,
    FleeClearFor = 0,
    EnemySet = nil,
    EnemyBand = nil,
    Reacting = nil,
    ReactDir = nil,
    ReactMove = nil,
    ReactKind = nil,
    LastPickup = 0,
    LastPickupFire = 0,
    LastSenseScan = 0,
    LastProbe = 0,
    SeekChar = nil,
    SeekDist = nil,
    HuntWhy = nil,
    RoamLog = 0,
    EscapeGoal = nil,
    EscapeRoute = nil,
    EscapeStep = nil,
    EscapeVault = false,
    EscapeGoalAt = 0,
    HuntGoal = nil,
    HuntGoalAt = 0,
    LastBlock = 0,
    BlockActive = false,
    BlockHeld = false,
    BlockUntil = 0,
    BlockSince = 0,
    BlockReleasedAt = 0,
    BlockTarget = nil,
    DefendVs = nil,
    DefendVsUntil = 0,
    DefendVsSince = 0,
    DefendVsRest = 0,
    DefendVsSwinging = false,
    LastSwingAt = 0,
    LastSwinger = nil,
    PerchSide = nil,
    MoveDirPrev = nil,
    MoveDirAt = 0,
    RevBins = { 0, 0, 0, 0, 0, 0, 0 },

    RevBinId = 0,
    PaceFrom = nil,
    PaceFromAt = 0,
    PaceArmed = false,
    RegroupLogAt = 0,
    Refused = nil,
    UsedSkillsThisLife = nil,
    BurstAt = 0,
    AbandonUntil = 0,
    OffLevelSeen = setmetatable({}, { __mode = "k" }),
    FarPathTarget = nil,
    FarPathFails = 0,
    FarPathBest = 0,
    FarPathFailAt = 0,
    LastFFAt = 0,
    HostilesNear = 0,
    TeamOffLevelSince = nil,
    TeamOffLevelName = nil,
    KiteArrived = false,
    TeamClosing = nil,
    InterceptUntil = 0,
    InterceptDmg = 0,
    NilStamp = nil,
    LaneHold = nil,
    AllyLane = nil,
    AllyLaneAt = 0,
    ReactSoft = false,
    ReactPrevMelee = false,

    RecoverUntil = 0,
    RecoverMode = nil,
    RecoverDir = nil,
    RecoverSaid = false,
    DefendKeepVs = nil,
    DefendKept = false,
    BlockSwings = 0,
    SwingName = nil,
    InDomain = false,
    DomainAt = 0,
    DomainDmg0 = 0, DomainTaken0 = 0, DomainStun0 = 0,
    MapPrevPos = nil,
    MapPrevAt = 0,
    AllyLaneLatch = nil,
    ReactSoftPrev = false,
    LastReposition = 0,
    LastTargetSwitch = 0,
    StuckTime = 0,
    LastPos = Vector3.zero,
    M1Active = false,
    Path = nil,
    PathPoints = nil,
    PathIndex = 1,
    PathTargetPos = nil,
    LastPathCompute = 0,
    PathFails = 0,
    PathSec = 0,

    CamTaken = false,


    CamProbe = nil,

    HeapAt = 0,
    ProbeAt = 0,
    ProbeRing = nil,
    ProbeI = 0,
    DefendStrings = 0,
    DivineDogAt = 0,
    BadTargets = setmetatable({}, { __mode = "k" }),
    Dist2D = 0,
    DistY = 0,
    LastSpecial = 0,
    DashDir = nil,
    DashSpeed = 0,
    DashUntil = 0,
    LastDodge = 0,
    LastChase = 0,
    LastAwakenTry = 0,
    AwakenTries = 0,
    AwakenBlockUntil = 0,
    PursuitTime = 0,
    PursuitLastDist = nil,
    PunishUntil = 0,
    LastReverse = 0,
    EscapeDir = nil,
    EscapeUntil = 0,
    TargetHP = nil,
    TargetHPTime = 0,
    FlankUntil = 0,
    DivineDogActive = false,
    Plan = nil,
    UsedSkillsThisFight = {},
    Kills = 0,

    Scores           = {},
    Contender        = nil,
    ContenderSince   = 0,
    LastScoreAt      = 0,
    UnreachableSince = 0,
    TargetSince      = 0,
    Crowd            = {},
    ClusterCount     = 0,
    LockMode         = "AUTO",
    LockedName       = nil,
    StartTime = 0,
}


local function getChar()
    return LocalPlayer.Character
end

local function getHRP(c)
    c = c or getChar()
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
end

local function getHum(c)
    c = c or getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getInfo(c)
    c = c or getChar()
    return c and c:FindFirstChild("Info")
end

local function getHP(c)
    local h = getHum(c)
    return h and h.Health or 0
end

local function getMaxHP(c)
    local h = getHum(c)
    return h and h.MaxHealth or 1
end

local function getHPPct(c)
    return getHP(c) / getMaxHP(c) * 100
end

local function isAlive(c)
    c = c or getChar()
    local h = getHum(c)
    return h and h.Health > 0
end

local function getDist(a, b)
    return (a - b).Magnitude
end







local HUGE_DIST = 99999

local function getDist2D(a, b)
    if not a or not b then return HUGE_DIST end
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function getDistY(a, b)
    if not a or not b then return 0 end
    return a.Y - b.Y
end

local function getChars()
    local f = Workspace:FindFirstChild("Characters")
    return f and f:GetChildren() or {}
end

local function isStunned(c)
    c = c or getChar()
    local i = getInfo(c)
    if not i then return false end
    if i:GetAttribute("Stun") then return true end
    if i:FindFirstChild("Stun") then return true end
    return false
end

local function isInSkill(c)
    c = c or getChar()
    local i = getInfo(c)
    local s = i and i:FindFirstChild("InSkill")
    return s and s.Value or false
end
























local M1StepSeen = setmetatable({}, { __mode = "k" })

local function m1SteppedWithin(c, sec)
    local n = c:GetAttribute("CurrentM1")
    if n == nil then return false end
    local now = tick()
    local rec = M1StepSeen[c]
    if not rec then
        M1StepSeen[c] = { n = n, at = 0, polled = now }
        return false
    end
    if rec.n ~= n then
        rec.n = n


        if now - rec.polled < 0.5 then rec.at = now end
    end
    rec.polled = now
    return (now - rec.at) < sec
end

local function inOwnMove(c)
    c = c or getChar()
    local i = getInfo(c)
    if not (i and i:FindFirstChild("InSkill")) then return false end
    if senseMeleeSwing(c) then return false end
    if m1SteppedWithin(c, 0.35) then return false end
    return true
end

local function isRagdolled(c)
    c = c or getChar()
    local r = c and c:GetAttribute("Ragdoll")
    return r and r > 0 or false
end

local function isDowned(c)
    c = c or getChar()
    return not isAlive(c) or isStunned(c) or isRagdolled(c)
end

local function hasIFrames(c)
    c = c or getChar()
    local i = getInfo(c)
    return i and i:GetAttribute("IFrame") ~= nil
end


local function getAvailableMoves()
    local c = getChar()
    if not c then return {} end
    local ms = c:FindFirstChild("Moveset")
    if not ms then return {} end
    local inUlt = c:GetAttribute("InUlt") or false

    local moves = {}
    for _, v in ipairs(ms:GetChildren()) do
        if v:IsA("NumberValue") then
            local svc = v:GetAttribute("Service")
            local key = v:GetAttribute("Key")
            if svc and key then
                local awk = v:GetAttribute("AWK")
                local awk2 = v:GetAttribute("AWK2")
                if awk and inUlt then

                elseif awk2 and not inUlt then

                else
                    moves[svc] = { value = v, key = key, readyAt = v:GetAttribute("ReadyAt") }
                end
            end
        end
    end
    return moves
end

local function isSkillReady(serviceName)
    local moves = getAvailableMoves()
    local m = moves[serviceName]
    if not m then return false end
    if not m.readyAt then return true end
    return Workspace:GetServerTimeNow() >= m.readyAt
end

local function getUltMeter()
    return LocalPlayer:GetAttribute("Ultimate") or 0
end

local function isAwakened()
    local c = getChar()
    return c and c:GetAttribute("InUlt") or false
end




















local MoveRules = {

    ["Despair"] = { min = 0, max = 12, prio = 4, code = 0, cc = true },
    ["Shut Up!"] = { min = 0, max = 12, prio = 4, code = 1 },
    ["Eye Catching"] = { min = 0, max = 0, prio = 4, code = 0 },
    ["Sacrilege"] = { min = 0, max = 20, prio = 4, code = 0 },

    ["Piercing Blood"] = { min = 0, max = 30, prio = 3, code = 0 },
    ["Flowing Red Scale"] = { min = 0, max = 28, prio = 5, code = 1 },
    ["Supernova"] = { min = 0, max = 0, prio = 3, code = 0 },
    ["Blood Edge"] = { min = 0, max = 12, prio = 5, code = 0 },
    ["Slicing Exorcism"] = { min = 0, max = 28, prio = 5, code = 1 },
    ["Wing King"] = { min = 0, max = 28, prio = 5, code = 0 },
    ["Blood Rain"] = { min = 0, max = 35, prio = 2, code = 0, trap = true, heavy = true },
    ["Plasma Wave"] = { min = 0, max = 120, prio = 2, code = 0, heavy = true },

    ["Lapse Blue"] = { min = 0, max = 35, prio = 3, code = 2 },
    ["Reversal Red"] = { min = 0, max = 40, prio = 3, code = 0, cc = true },
    ["Rapid Punches"] = { min = 0, max = 12, prio = 4, code = 0 },
    ["Twofold Kick"] = { min = 0, max = 12, prio = 4, code = 0 },
    ["Lapse Blue MAX"] = { min = 15, max = 70, prio = 3, code = 1 },
    ["Reversal Red MAX"] = { min = 15, max = 70, prio = 3, code = 1 },
    ["Hollow Purple"] = { min = 0, max = 30, prio = 2, code = 1, heavy = true },
    ["Infinite Void"] = { min = 0, max = 30, prio = 2, code = 0, heavy = true },

    ["Kamehameha"] = { min = 15, max = 70, prio = 3, code = 1 },
    ["Ki Spam"] = { min = 15, max = 70, prio = 3, code = 1 },
    ["Staff Extend"] = { min = 15, max = 70, prio = 3, code = 1 },
    ["Staff Uppercut"] = { min = 0, max = 12, prio = 4, code = 0 },

    ["Reserve Balls"] = { min = 0, max = 45, prio = 3, code = 0, trap = true },
    ["Shutter Doors"] = { min = 0, max = 28, prio = 5, code = 2, cc = true },
    ["Rough Energy"] = { min = 0, max = 12, prio = 4, code = 1 },
    ["Fever Breaker"] = { min = 0, max = 28, prio = 5, code = 0 },
    ["Lucky Volley"] = { min = 0, max = 11, prio = 4, code = 0 },
    ["Lucky Rushdown"] = { min = 0, max = 28, prio = 5, code = 0 },
    ["Overwhelming Luck"] = { min = 0, max = 30, prio = 2, code = 0, heavy = true },
    ["Energy Surge"] = { min = 0, max = 25, prio = 4, code = 0, cc = true },

    ["Root Swarm"] = { min = 0, max = 50, prio = 3, code = 1, trap = true },
    ["Surging Thorns"] = { min = 0, max = 35, prio = 3, code = 1, trap = true },
    ["Bud Shot"] = { min = 0, max = 70, prio = 3, code = 0 },
    ["Defense Response"] = { min = 0, max = 12, prio = 7, code = 1, escape = true },
    ["Cursed Buds"] = { min = 0, max = 60, prio = 1, code = 0, trap = true, summon = true },
    ["Shining Sea of Growing Branches"] = { min = 0, max = 30, prio = 2, code = 0, heavy = true },
    ["Flower Field"] = { min = 15, max = 70, prio = 3, code = 2, trap = true },
    ["Root Rampage"] = { min = 0, max = 30, prio = 2, code = 1, heavy = true },

    ["Ambush"] = { min = 0, max = 20, prio = 5, code = 1 },
    ["Backstab"] = { min = 0, max = 12, prio = 5, code = 0, cc = true },
    ["Trip"] = { min = 0, max = 12, prio = 7, code = 0, cc = true, escape = true },
    ["Cheap Shot"] = { min = 0, max = 60, prio = 4, code = 0 },
    ["Ankle Cutter"] = { min = 0, max = 11, prio = 4, code = 0, cc = true },
    ["High Time"] = { min = 0, max = 28, prio = 5, code = 0, cc = true },
    ["Dirty Play"] = { min = 0, max = 30, prio = 2, code = 0, heavy = true },

    ["Strong Dismantle"] = { min = 0, max = 28, prio = 5, code = 0 },
    ["Open FURNACE"] = { min = 0, max = 11, prio = 4, code = 0 },
    ["Cleave Rush"] = { min = 0, max = 28, prio = 5, code = 0 },
    ["Kamutoke"] = { min = 0, max = 11, prio = 4, code = 0 },

    ["Extended Swings"] = { min = 0, max = 11, prio = 4, code = 0 },
    ["Justice Served"] = { min = 0, max = 12, prio = 4, code = 0, cc = true },
    ["Judgement's Reach"] = { min = 15, max = 70, prio = 3, code = 2 },
    ["Pressing Charges"] = { min = 0, max = 11, prio = 4, code = 0, cc = true },
    ["Execution"] = { min = 0, max = 11, prio = 4, code = 1 },
    ["Final Judgement"] = { min = 0, max = 11, prio = 4, code = 0 },
    ["Verdict"] = { min = 15, max = 70, prio = 3, code = 0 },
    ["Triple Sentence"] = { min = 0, max = 11, prio = 4, code = 0 },
    ["Grapple"] = { min = 0, max = 28, prio = 5, code = 2, cc = true },

    ["Cursed Strikes"] = { min = 0, max = 11, prio = 4, code = 1 },
    ["Crushing Blow"] = { min = 0, max = 12, prio = 4, code = 1 },
    ["Divergent Fist"] = { min = 0, max = 12, prio = 4, code = 0 },
    ["Manji Kick"] = { min = 0, max = 0, prio = 4, code = 0 },
    ["Dismantle"] = { min = 0, max = 28, prio = 5, code = 1 },
    ["Open"] = { min = 0, max = 11, prio = 4, code = 0 },
    ["Rush"] = { min = 0, max = 28, prio = 5, code = 0 },
    ["Malevolent Shrine"] = { min = 0, max = 30, prio = 2, code = 0, heavy = true },

    ["Festering Strikes"] = { min = 0, max = 12, prio = 5, code = 0 },
    ["Detach"] = { min = 0, max = 28, prio = 5, code = 1, cc = true },
    ["Chokehold"] = { min = 0, max = 28, prio = 5, code = 0, cc = true },
    ["Roach Swarm"] = { min = 0, max = 35, prio = 5, code = 1, trap = true },

    ["Crushing Jaws"] = { min = 0, max = 12, prio = 4, code = 0, cc = true },
    ["Clever"] = { min = 0, max = 25, prio = 7, code = 0, escape = true },
    ["Wing Throw"] = { min = 15, max = 70, prio = 3, code = 0 },
    ["Black Mucus"] = { min = 0, max = 60, prio = 4, code = 0, cc = true },

    ["Stockpile"] = { min = 0, max = 12, prio = 5, code = 1, cc = true },
    ["Soul Fire"] = { min = 15, max = 70, prio = 3, code = 0, cc = true },
    ["Focus Strike"] = { min = 0, max = 12, prio = 4, code = 0 },
    ["Body Repel"] = { min = 0, max = 25, prio = 7, code = 0, cc = true, escape = true },
    ["Idle Transfiguration"] = { min = 0, max = 12, prio = 0, code = 0, selfBuff = true },
    ["Body Disfigure"] = { min = 0, max = 28, prio = 5, code = 2 },
    ["Spike Wrath"] = { min = 0, max = 25, prio = 3, code = 0, trap = true },
    ["Embodiment of Self Perfection"] = { min = 0, max = 30, prio = 2, code = 0, heavy = true },
    ["Widespread Strikes"] = { min = 0, max = 11, prio = 4, code = 0 },
    ["Face Blitz"] = { min = 0, max = 28, prio = 5, code = 2 },
    ["Crushing Rushdown"] = { min = 0, max = 70, prio = 5, code = 2 },
    ["Head Splitter"] = { min = 0, max = 0, prio = 4, code = 0, cc = true },

    ["Divine Pummel"] = { min = 0, max = 11, prio = 4, code = 0 },
    ["Ground Pitch"] = { min = 15, max = 70, prio = 3, code = 0, cc = true },
    ["Earthquake"] = { min = 0, max = 30, prio = 2, code = 0, heavy = true },
    ["Takedown"] = { min = 0, max = 11, prio = 4, code = 2, cc = true },
    ["Adaptation"] = { min = 0, max = 0, prio = 0, code = 0, selfBuff = true },
    ["World Slash"] = { min = 0, max = 80, prio = 2, code = 0, heavy = true },

    ["Ultra Spin"] = { min = 0, max = 11, prio = 4, code = 0 },
    ["Boost On"] = { min = 0, max = 28, prio = 3, code = 0, cc = true },
    ["Ultra Cannon"] = { min = 15, max = 70, prio = 3, code = 0 },
    ["Heat Emission"] = { min = 0, max = 14, prio = 4, code = 0 },
    ["Miracle Cannon"] = { min = 0, max = 80, prio = 2, code = 0, heavy = true },
    ["Pigeon Viola"] = { min = 0, max = 250, prio = 1, code = 2, summon = true },
    ["Absolute Destruction"] = { min = 0, max = 30, prio = 2, code = 0, heavy = true },
    ["Technique Charge"] = { min = 0, max = 100, prio = 0, code = 2, selfBuff = true },
    ["Boost On OLD"] = { min = 0, max = 11, prio = 4, code = 0 },
    ["Ultra Cannon OLD"] = { min = 15, max = 70, prio = 3, code = 0 },

    ["Rabbit Escape"] = { min = 0, max = 40, prio = 7, code = 2, escape = true },
    ["Nue"] = { min = 0, max = 60, prio = 1, code = 2, trap = true, summon = true },
    ["Toad"] = { min = 0, max = 75, prio = 1, code = 2, trap = true, summon = true },
    ["Divine Dog: Totality"] = { min = 0, max = 60, prio = 1, code = 2, trap = true, summon = true },
    ["Max Elephant"] = { min = 0, max = 60, prio = 1, code = 0, trap = true, summon = true, heavy = true },
    ["Great Serpent"] = { min = 0, max = 60, prio = 1, code = 0, trap = true, summon = true },
    ["Shadow Swarm"] = { min = 0, max = 60, prio = 1, code = 0, trap = true, summon = true },
    ["Mahoraga"] = { min = 0, max = 60, prio = 1, code = 2, summon = true },

    ["Impetus Updraft"] = { min = 0, max = 12, prio = 5, code = 1 },
    ["Circling"] = { min = 0, max = 11, prio = 4, code = 1 },
    ["Gliding Flight"] = { min = 0, max = 28, prio = 5, code = 0 },
    ["Bird Control"] = { min = 0, max = 60, prio = 1, code = 5, trap = true, summon = true },

    ["Cleaving Whirlwind"] = { min = 0, max = 25, prio = 4, code = 0 },
    ["Severance Kick"] = { min = 0, max = 12, prio = 4, code = 4 },
    ["Blunt Cut"] = { min = 0, max = 34, prio = 4, code = 1 },
    ["Stabilize"] = { min = 0, max = 12, prio = 5, code = 0 },
    ["Ratio Breaker"] = { min = 0, max = 12, prio = 5, code = 0 },
    ["Sharpen"] = { min = 0, max = 14, prio = 4, code = 1 },
    ["Interrogate"] = { min = 0, max = 12, prio = 4, code = 0, cc = true },
    ["Collapse"] = { min = 0, max = 30, prio = 2, code = 1, heavy = true },

    ["Projection Breaker"] = { min = 0, max = 15, prio = 5, code = 0 },
    ["Bleedout"] = { min = 0, max = 12, prio = 4, code = 0, cc = true },
    ["Decisive Strike"] = { min = 0, max = 35, prio = 5, code = 2 },
    ["Cursory Impact"] = { min = 0, max = 28, prio = 5, code = 0, cc = true },
    ["Top Speed"] = { min = 0, max = 999, prio = 0, code = 0, selfBuff = true },
    ["Flash Freezing"] = { min = 0, max = 25, prio = 7, code = 0, cc = true, escape = true },
    ["Tendril Grab"] = { min = 0, max = 25, prio = 5, code = 2, cc = true },
    ["Time Cell Moon Palace"] = { min = 0, max = 30, prio = 2, code = 0, heavy = true },
    ["Decisive Strike OLD"] = { min = 0, max = 28, prio = 5, code = 0 },

    ["Gushing Wound"] = { min = 0, max = 95, prio = 3, code = 0 },
    ["Homerun"] = { min = 0, max = 12, prio = 5, code = 0 },
    ["Littering"] = { min = 15, max = 70, prio = 3, code = 0, trap = true },
    ["Coupon"] = { min = 0, max = 0, prio = 3, code = 0 },
    ["Piano Drop"] = { min = 15, max = 70, prio = 3, code = 3 },
    ["Garage Sale"] = { min = 0, max = 70, prio = 2, code = 0, trap = true, heavy = true },
    ["Blunt Trauma"] = { min = 0, max = 25, prio = 4, code = 0 },
    ["Fleche"] = { min = 0, max = 20, prio = 5, code = 0 },
    ["Drone Strike"] = { min = 0, max = 60, prio = 1, code = 0, trap = true, summon = true },
    ["Pole Vault"] = { min = 0, max = 25, prio = 7, code = 0, escape = true },

    ["Granite Blast"] = { min = 0, max = 5, prio = 3, code = 1 },
    ["Unsatisfied"] = { min = 0, max = 25, prio = 4, code = 0 },
    ["Second Helping"] = { min = 0, max = 70, prio = 5, code = 2 },
    ["Appetizer"] = { min = 0, max = 45, prio = 3, code = 0 },
    ["\"What are you after?\""] = { min = 0, max = 12, prio = 4, code = 1 },
    ["\"I had no idea...\""] = { min = 0, max = 12, prio = 4, code = 0 },
    ["\"This is what dessert is like!\""] = { min = 0, max = 11, prio = 4, code = 0 },
    ["\"You weren't invited.\""] = { min = 0, max = 30, prio = 2, code = 0, heavy = true },

    ["Swift Kick"] = { min = 0, max = 12, prio = 5, code = 6 },
    ["Brute Force"] = { min = 0, max = 12, prio = 4, code = 0 },
    ["Pebble Throw"] = { min = 0, max = 45, prio = 3, code = 0 },
    ["Elbow Drop"] = { min = 0, max = 12, prio = 4, code = 0 },
    ["Idol's Debut"] = { min = 0, max = 28, prio = 5, code = 0 },
    ["Climax Jumping"] = { min = 0, max = 40, prio = 5, code = 0 },
    ["Dreams"] = { min = 0, max = 12, prio = 2, code = 0, heavy = true },
    ["Brothers"] = { min = 0, max = 0, prio = 1, code = 0, summon = true },

    ["Blind Rage"] = { min = 0, max = 28, prio = 5, code = 2, cc = true },
    ["Sky Distortion"] = { min = 15, max = 70, prio = 3, code = 1 },
    ["Thin Ice Breaker"] = { min = 0, max = 28, prio = 5, code = 2, cc = true },

    ["Garuda Rebound"] = { min = 0, max = 28, prio = 5, code = 2 },
    ["Rising Rage"] = { min = 0, max = 12, prio = 4, code = 0 },
    ["Mass Breaker"] = { min = 0, max = 28, prio = 5, code = 1 },
    ["Garuda Stab"] = { min = 0, max = 11, prio = 4, code = 0 },

    ["Severing Path"] = { min = 0, max = 18, prio = 5, code = 4 },
    ["Resolute Slash"] = { min = 0, max = 25, prio = 4, code = 5 },
    ["Veilstep"] = { min = 0, max = 25, prio = 7, code = 1, escape = true },
    ["Second Wind"] = { min = 0, max = 20, prio = 0, code = 1, selfBuff = true },
    ["Outburst"] = { min = 0, max = 11, prio = 4, code = 1 },
    ["Revolve"] = { min = 0, max = 11, prio = 4, code = 1 },
    ["Rika Downslam"] = { min = 0, max = 12, prio = 4, code = 0 },
    ["Rika Launch"] = { min = 0, max = 28, prio = 5, code = 1 },
    ["Rika Slam"] = { min = 0, max = 12, prio = 4, code = 0 },
    ["Rika Haymaker"] = { min = 0, max = 10, prio = 4, code = 0 },
    ["Rika Grab"] = { min = 0, max = 60, prio = 1, code = 0, cc = true, summon = true },
    ["Rika Throw"] = { min = 0, max = 11, prio = 4, code = 0 },
    ["Rika Smash"] = { min = 0, max = 12, prio = 4, code = 0 },
    ["True Love Beam"] = { min = 0, max = 80, prio = 2, code = 0, heavy = true },
    ["Authentic Mutual Love"] = { min = 15, max = 70, prio = 3, code = 2 },
    ["Elbow Rush"] = { min = 0, max = 5, prio = 5, code = 0 },
    ["Copy"] = { min = 0, max = 11, prio = 4, code = 5 },
    ["Energy Ripple"] = { min = 0, max = 27, prio = 2, code = 0, heavy = true },
}

local DefaultRule = { min = 0, max = 40, prio = 9, code = 0 }



local HoardUlt = { Megumi = true }



local CharInfo = {
    Charles = { header = "ASPIRING MANGAKA", r = 255, g = 235, b = 235, ult = "Foresight" },
    Choso = { header = "BLOOD MANIPULATOR", r = 170, g = 75, b = 75, ult = "Duty as a Brother" },
    Gojo = { header = "HONORED ONE", r = 170, g = 255, b = 255, ult = "Six Eyes" },
    Goku = { header = "MONKEY KID", r = 255, g = 21, b = 52, ult = "Monkey" },
    Hakari = { header = "RESTLESS GAMBLER", r = 170, g = 255, b = 127, ult = "Idle Death Gamble" },
    Hanami = { header = "DISASTER PLANTS", r = 172, g = 203, b = 163, ult = "Unwrap" },
    Haruta = { header = "LUCKY COWARD", r = 167, g = 125, b = 203, ult = "Jawbreaker" },
    Heian = { header = "HEIAN", r = 255, g = 85, b = 0, ult = "Incomplete Shrine" },
    Hiromi = { header = "DEFENSE ATTORNEY", r = 115, g = 99, b = 77, ult = "Deadly Sentencing" },
    Itadori = { header = "VESSEL", r = 255, g = 155, b = 155, ult = "King of Curses" },
    Kurourushi = { header = "BLACK DEATH", r = 101, g = 35, b = 44, ult = "Parthenogenesis" },
    Locust = { header = "LOCUST", r = 170, g = 255, b = 127, ult = "Directed Poison" },
    Mahito = { header = "PERFECTION", r = 255, g = 170, b = 255, ult = "Essence of the Soul" },
    Mahoraga = { header = "MAHORAGA", r = 255, g = 255, b = 255, ult = "Ritual" },
    Mechamaru = { header = "PUPPET MASTER", r = 225, g = 10, b = 75, ult = "Absolute" },
    Megumi = { header = "TEN SHADOWS", r = 120, g = 120, b = 120, ult = "Insanity" },
    MeiMei = { header = "CROW CHARMER", r = 35, g = 40, b = 80, ult = "Bird Strike" },
    Mokou = { header = "IMMORTAL BLAZE", r = 255, g = 170, b = 0, ult = "Immortal Blaze" },
    Nanami = { header = "SALARYMAN", r = 94, g = 191, b = 255, ult = "Overtime" },
    Naoya = { header = "HEAD OF THE HEI", r = 128, g = 126, b = 255, ult = "Vengeance" },
    Reggie = { header = "REGISTER", r = 255, g = 255, b = 255, ult = "Con Artistry" },
    Ryu = { header = "TRUE CANNON", r = 170, g = 255, b = 255, ult = "Every Last Drop." },
    Todo = { header = "SWITCHER", r = 170, g = 255, b = 255, ult = "False Memories" },
    Uro = { header = "SKY ASSASSIN", r = 255, g = 165, b = 165, ult = "Temper" },
    Yuki = { header = "STAR RAGE", r = 170, g = 170, b = 255, ult = "Unrestricted Density" },
    Yuta = { header = "CURSED PARTNERS", r = 255, g = 170, b = 255, ult = "True Love" },
}
























local SpecialRules = {
    Gojo        = { name = "Limitless",            kind = "offense", min = 0,  max = 30 },
    Itadori     = { name = "Combat Instincts",     kind = "offense", min = 0,  max = 18 },
    Hakari      = { name = "Rhythm",               kind = "utility", min = 0,  max = 999 },
    Megumi      = { name = "Lurking Shadow",       kind = "offense", min = 0,  max = 35 },
    Mahoraga    = { name = "Adaptation Wheel",     kind = "utility", min = 0,  max = 999 },
    Mahito      = { name = "Self Transfiguration", kind = "avoid",   min = 0,  max = 999 },
    Choso       = { name = "Convergence",          kind = "offense", min = 10, max = 60 },
    Todo        = { name = "Boogie Woogie",        kind = "avoid",   min = 0,  max = 0 },
    Locust      = { name = "Fluttering Pounce",    kind = "offense", min = 0,  max = 25 },
    Hiromi      = { name = "No Escape",            kind = "offense", min = 0,  max = 30 },
    Yuki        = { name = "Mass Buildup",         kind = "utility", min = 0,  max = 999 },
    Heian       = { name = "Incantation",          kind = "utility", min = 0,  max = 999 },
    Yuta        = { name = "Rika",                 kind = "offense", min = 0,  max = 40 },
    Charles     = { name = "Clairvoyance",         kind = "utility", min = 0,  max = 999 },
    Mechamaru   = { name = "Energy Output",        kind = "utility", min = 0,  max = 999 },
    Naoya       = { name = "Projection Sorcery",   kind = "offense", min = 0,  max = 35 },
    Nanami      = { name = "Ratio Point",          kind = "utility", min = 0,  max = 999 },
    Goku        = { name = "Instant Transmission", kind = "offense", min = 15, max = 120 },
    Haruta      = { name = "Helping Hand",         kind = "utility", min = 0,  max = 999 },
    MeiMei      = { name = "Flock",                kind = "offense", min = 0,  max = 50 },


    Hanami      = { name = "Plant Guidance",       kind = "utility", min = 0,  max = 999 },
    Ryu         = { name = "Restyle",              kind = "utility", min = 0,  max = 999 },
    Kurourushi  = { name = "Earthen Insect Trance",kind = "offense", min = 0,  max = 30 },
    Reggie      = { name = "Discard",              kind = "avoid",   min = 0,  max = 0 },
    Uro         = { name = "none",                 kind = "avoid",   min = 0,  max = 0 },
}






















local UltGate = {
    Yuki = function(c)
        return c:GetAttribute("Dead") ~= nil and not c:GetAttribute("LastResort")
    end,
    Haruta = function(c)
        return c:GetAttribute("Sword") == nil
    end,
    MeiMei = function(c)
        local info = c:FindFirstChild("Info")
        local cr = info and info:FindFirstChild("ControlRemote")
        return cr ~= nil and cr:GetAttribute("Active") ~= nil
    end,
    Reggie = function(c)
        return c:GetAttribute("InUlt") ~= nil
    end,
    Uro = function(c)
        local m = c:GetAttribute("Ult2")
        return (c:GetAttribute("InUlt") and true or false) or (m == 100)
    end,
}

local UltNeedsInUlt = { Reggie = true, Uro = true }

CharServices = {
    Charles = true,
    Choso = true,
    Gojo = true,
    Goku = true,
    Hakari = true,
    Hanami = true,
    Haruta = true,
    Heian = true,
    Hiromi = true,
    Itadori = true,
    Kurourushi = true,
    Locust = true,
    Mahito = true,
    Mahoraga = true,
    Mechamaru = true,
    Megumi = true,
    MeiMei = true,
    Nanami = true,
    Naoya = true,
    Reggie = true,
    Ryu = true,
    Todo = true,
    Uro = true,
    Yuki = true,
    Yuta = true,
}


























local HttpService = game:GetService("HttpService")

MEM = {
    version = 4,
    opponents = {},
    global = { moves = {} },














    career = {
        lives = 0,
        dmg = 0,
        time = 0,
        best = 0,
        recent = {},
    },








    chains = {},



    stats = { clean = 0, dirty = 0 },












    reactions = {},


    blockFix = false,
    lockFix = false,
    retagFix = false,















    ranges = {},






    adopted = {},









    chars = {},
    locked = {},
    charFails = {},
    recentChars = {},
    throwMethod = nil,

















    enemyCombos = {},
    enemyOpens = {},
    enemyTrust = {},


    map = nil,
}


MapDirty = false

MemIO = {
    file = "JJK_AutoFight_Memory_" .. ACCOUNT .. ".json",
    legacy = "JJK_AutoFight_Memory.json",
    canRead = false,
    canWrite = false,
    loaded = false,
    lastSave = 0,
    dirty = false,
    sessionAt = os.time(),
}

do
    local okW, w = pcall(function() return writefile end)
    if okW and type(w) == "function" then MemIO.canWrite = true; MemIO.write = w end
    local okR, r = pcall(function() return readfile end)
    if okR and type(r) == "function" then MemIO.canRead = true; MemIO.read = r end
    local okI, i = pcall(function() return isfile end)
    if okI and type(i) == "function" then MemIO.isfile = i end
end


function memBlank()
    return {
        name = "?",
        seen = 0,


        kills = 0,
        deaths = 0,
        dmgDealt = 0,
        dmgTaken = 0,





        movesets = {},
        moves = {},
        dmgByRange = {},
        obs = {
            samples = 0,
            blocking = 0,
            chasing = 0,
            chaseChances = 0,
            inSkill = 0,
            distSum = 0,
        },
        lastSeen = 0,
    }
end

function memLoad()
    if MemIO.loaded then return end
    MemIO.loaded = true

    if not MemIO.canRead then
        debug("memory: no readfile - learning will not persist between sessions")
        return
    end


    local path = MemIO.file
    if MemIO.isfile then
        local ok, exists = pcall(MemIO.isfile, path)
        if ok and not exists then
            local okL, hasLegacy = pcall(MemIO.isfile, MemIO.legacy)
            if okL and hasLegacy then
                path = MemIO.legacy
                debug("memory: importing shared file " .. MemIO.legacy)
            else
                debug("memory: no file yet, starting fresh")
                return
            end
        end
    end

    local ok, raw = pcall(MemIO.read, path)
    if not ok or type(raw) ~= "string" or #raw < 2 then
        debug("memory: file unreadable, starting fresh")
        return
    end

    local okDec, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okDec or type(data) ~= "table" then
        debug("memory: file corrupt, starting fresh")
        return
    end



    if (data.version == MEM.version or data.version == 3)
       and type(data.opponents) == "table" then
        MEM.opponents = data.opponents
        MEM.global = (type(data.global) == "table") and data.global or { moves = {} }
        if type(MEM.global.moves) ~= "table" then MEM.global.moves = {} end

        if type(data.career) == "table" then
            MEM.career = data.career
            if type(MEM.career.recent) ~= "table" then MEM.career.recent = {} end
        end
        if type(data.chains) == "table" then MEM.chains = data.chains end
        if type(data.map) == "table" then MEM.map = data.map end
        if type(data.stats) == "table" then MEM.stats = data.stats end
        if type(data.reactions) == "table" then MEM.reactions = data.reactions end
        MEM.blockFix = data.blockFix and true or false
        MEM.lockFix = data.lockFix and true or false
        MEM.retagFix = data.retagFix and true or false
        MEM.recentFix = data.recentFix and true or false
        if type(data.ranges) == "table" then MEM.ranges = data.ranges end
        if type(data.adopted) == "table" then MEM.adopted = data.adopted end
        if type(data.chars) == "table" then MEM.chars = data.chars end
        if type(data.locked) == "table" then MEM.locked = data.locked end
        if type(data.charFails) == "table" then MEM.charFails = data.charFails end
        if type(data.recentChars) == "table" then MEM.recentChars = data.recentChars end
        if type(data.throwMethod) == "string" then MEM.throwMethod = data.throwMethod end
        if type(data.enemyCombos) == "table" then MEM.enemyCombos = data.enemyCombos end
        if type(data.enemyOpens) == "table" then MEM.enemyOpens = data.enemyOpens end
        if type(data.enemyTrust) == "table" then MEM.enemyTrust = data.enemyTrust end
        if type(MEM.stats) ~= "table" then MEM.stats = { clean = 0, dirty = 0 } end

        if data.version == 3 then
            debug("memory: migrated v3 file - move history kept, combos start empty")
        end
























        local converted = 0
        for name, v in pairs(MEM.locked) do
            if v == true then
                MEM.locked[name] = os.time() - Config.CharLockExpiry + 60
                converted = converted + 1
            end
        end
        if converted > 0 then
            debug(string.format("memory: %d permanent character locks converted to expiring", converted))
            MemIO.dirty = true
        end

        if not MEM.lockFix then
            local n = 0
            for _ in pairs(MEM.locked) do n = n + 1 end
            if n > 0 then
                MEM.locked = {}
                debug(string.format("memory: cleared %d bogus character locks (v49 timer bug)", n))
            end
            MEM.lockFix = true
            MemIO.dirty = true
        end







        if not MEM.retagFix then
            local n = 0
            for _, name in ipairs({ "Boost On", "Heat Emission", "Appetizer", "Unsatisfied", "Stabilize",
                                    "Reserve Balls", "Stockpile", "Sharpen", "Energy Surge" }) do
                if MEM.ranges and MEM.ranges[name] then MEM.ranges[name] = nil; n = n + 1 end
            end
            MEM.retagFix = true
            MemIO.dirty = true
            if n > 0 then debug(string.format("memory: reset the learned range of %d retagged moves", n)) end
        end











        if not MEM.recentFix then
            local kits, avg, cap = 0, memCareerAvg(), Config.KitLifeCap or 0
            local keep = Config.CharRecentLives or 8
            for _, L in ipairs((MEM.career and MEM.career.lifeLog) or {}) do
                local r = L.ch and MEM.chars[L.ch]
                if r and type(L.dmg) == "number" then
                    local v = L.dmg
                    if avg and cap > 0 then v = math.min(v, cap * avg) end
                    if not r.recent then r.recent = {}; kits = kits + 1 end
                    table.insert(r.recent, v)
                    while #r.recent > keep do table.remove(r.recent, 1) end
                end
            end
            MEM.recentFix = true
            MemIO.dirty = true
            debug(string.format("memory: kit recent windows seeded from the life log (%d kits)", kits))
        end

        if not MEM.blockFix then
            local fixed = 0
            for _, rec in pairs(MEM.opponents) do
                local o = rec.obs
                if o and (o.blocking or 0) > 0 then
                    o.blocking = 0
                    fixed = fixed + 1
                end
            end
            MEM.blockFix = true
            MemIO.dirty = true
            if fixed > 0 then
                debug(string.format(
                    "memory: cleared block counters on %d profiles (v44 detector was faulty)",
                    fixed))
            end
        end

        local n = 0
        for _ in pairs(MEM.opponents) do n = n + 1 end
        debug(string.format("memory: loaded %d opponent profiles", n))
    else
        debug("memory: schema " .. tostring(data.version) .. " != " .. MEM.version .. ", starting fresh")
    end
end















function memPrune()
    local n = 0
    for _ in pairs(MEM.opponents) do n = n + 1 end
    if n <= Config.MemMaxOpponents then return end

    local bySignal = Config.MemPruneBySignal
    local session = MemIO.sessionAt or 0
    local list = {}
    for k, v in pairs(MEM.opponents) do
        local seenAt = v.lastSeen or 0
        if not bySignal or seenAt < session then
            local traded = (v.dmgDealt or 0) + (v.dmgFrom or 0)
            table.insert(list, { k = k, t = seenAt, d = traded,
                z = (traded <= 0 and (v.seen or 0) <= 1) and 0 or 1 })
        end
    end
    if bySignal then
        table.sort(list, function(a, b)
            if a.z ~= b.z then return a.z < b.z end
            if a.d ~= b.d then return a.d < b.d end
            return a.t < b.t
        end)
    else
        table.sort(list, function(a, b) return a.t < b.t end)
    end

    local drop = math.min(#list, n - Config.MemMaxOpponents)
    local now = os.time()
    for i = 1, drop do
        local it = list[i]
        local rec = MEM.opponents[it.k]
        if i <= 5 and rec then
            debug(string.format("memory: pruned %s (seen %d, last %.1f d ago, %.0f traded)",
                tostring(rec.name), rec.seen or 0, (now - it.t) / 86400, it.d))
        end
        MEM.opponents[it.k] = nil
    end
    if drop > 5 then
        debug(string.format("memory: pruned %d profiles in all (%d not listed)", drop, drop - 5))
    end
end















function memRound(t)
    for k, v in pairs(t) do
        local ty = type(v)
        if ty == "number" then
            if v % 1 ~= 0 and v == v and v ~= math.huge and v ~= -math.huge then
                t[k] = math.floor(v * 100 + 0.5) / 100
            end
        elseif ty == "table" then
            memRound(v)
        end
    end
end












function memSave(force, why)
    if not MemIO.canWrite then return end
    if not MemIO.dirty and not MapDirty then return end
    if not force and (os.clock() - MemIO.lastSave) < Config.MemSaveEvery then return end

    local t0 = os.clock()
    MemIO.lastSave = t0
    MemIO.dirty = false
    MapDirty = false
    memPrune()
    if mapSnapshot then MEM.map = mapSnapshot() end

    local enc, wr, bytes = 0, 0, 0
    local ok, err = pcall(function()
        local payload = {
            version = MEM.version,
            opponents = MEM.opponents,
            global = MEM.global,
            career = MEM.career,
            chains = MEM.chains,
            map = MEM.map,
            stats = MEM.stats,
            reactions = MEM.reactions,
            blockFix = MEM.blockFix,
            lockFix = MEM.lockFix,




            retagFix = MEM.retagFix,
            recentFix = MEM.recentFix,
            ranges = MEM.ranges,
            adopted = MEM.adopted,
            chars = MEM.chars,
            locked = MEM.locked,
            charFails = MEM.charFails,
            recentChars = MEM.recentChars,
            throwMethod = MEM.throwMethod,
            enemyCombos = MEM.enemyCombos,
            enemyOpens = MEM.enemyOpens,
            enemyTrust = MEM.enemyTrust,
            savedAt = os.time(),
        }
        memRound(payload)
        local c1 = os.clock()
        local json = HttpService:JSONEncode(payload)
        local c2 = os.clock()
        MemIO.write(MemIO.file, json)
        enc, wr, bytes = c2 - c1, os.clock() - c2, #json
    end)
    if not ok then
        debug("memory: save failed - " .. tostring(err))
        return
    end
    local ms = (os.clock() - t0) * 1000
    Life.saves = (Life.saves or 0) + 1
    if ms > (Life.saveMax or 0) then Life.saveMax = ms end
    Life.saveKB = bytes / 1024
    debugEvery("mem-saved", 0.25, string.format("memory: saved %.0f KB in %.0f ms (%s) - encode %.0f, write %.0f",
        bytes / 1024, ms, why or (force and "forced" or "interval"), enc * 1000, wr * 1000))
end




function memKey(c)
    if not c then return nil end
    local p = Players:GetPlayerFromCharacter(c)
    if p then return "u" .. tostring(p.UserId) end
    return "n" .. c.Name
end

function memFor(c)
    local key = memKey(c)
    if not key then return nil, nil end

    local rec = MEM.opponents[key]
    if not rec then
        rec = memBlank()
        rec.name = c.Name
        rec.seen = 0



        rec.lastSeen = os.time()
        MEM.opponents[key] = rec
        MemIO.dirty = true
    end
    rec.name = c.Name
    return rec, key
end
















local function rangeBucket(d)
    local b = math.floor((d or 0) / 10)
    if b < 0 then b = 0 end
    if b > 7 then b = 7 end
    return tostring(b)
end

MemMaxRangeBucket = 4




function memObserve(t, d2d, dt, blocking)
    if not Config.Memory or not t then return end
    local rec = memFor(t)
    if not rec then return end




    rec.lastSeen = os.time()

    local o = rec.obs
    o.samples = (o.samples or 0) + 1
    o.distSum = (o.distSum or 0) + (d2d or 0)

    if blocking then o.blocking = (o.blocking or 0) + 1 end

    local i = getInfo(t)
    if i then
        if inOwnMove(t) or i:FindFirstChild("Dash") then
            o.inSkill = (o.inSkill or 0) + 1
        end
    end


    if Bot.State == "RETREAT" or Bot.State == "PUNISH" then
        o.chaseChances = (o.chaseChances or 0) + 1
        if (d2d or 99) < Config.PursuitRange then
            o.chasing = (o.chasing or 0) + 1
        end
    end




    MemIO.dirty = true
end






Life = {
    active = false,
    startAt = 0,
    dmg = 0,
    taken = 0,
    moves = 0,
    engaged = 0,
    blocks = 0,
    stunned = 0,
    rate = 0,
    inRate = 0,
}














function memRateTick(dt, dmgOut, hasTarget, inReach, dmgIn)
    if not Life.active then return end

    local tau = Config.StallTau
    Life.rate = Life.rate * math.exp(-(dt or 0.016) / tau) + (dmgOut or 0) / tau



    Life.inRate = Life.inRate * math.exp(-(dt or 0.016) / tau) + (dmgIn or 0) / tau

    if hasTarget and inReach then
        Life.engaged = Life.engaged + (dt or 0.016)
    end




    Life.frames = (Life.frames or 0) + 1
    if (dt or 0) > (Life.worstDt or 0) then Life.worstDt = dt end
    if Bot.State == "TEAMKITE" then Life.kiteSec = (Life.kiteSec or 0) + (dt or 0.016)
    elseif Bot.State == "RETREAT" then Life.retreatSec = (Life.retreatSec or 0) + (dt or 0.016)
    elseif Bot.State == "DEFEND" then Life.guardSec = (Life.guardSec or 0) + (dt or 0.016) end
    if not Life.char then
        local cc = getChar()
        Life.char = cc and cc:GetAttribute("Moveset") or nil
    end
    local stunNow = isStunned() or isRagdolled()
    if stunNow then




        if not Life.wasStunned then Life.stunSelf = false; memNoteStunStart() end
        if Life.stunSelf then
            Life.stunnedSelf = (Life.stunnedSelf or 0) + (dt or 0.016)
        else
            Life.stunned = Life.stunned + (dt or 0.016)
        end
    end
    Life.wasStunned = stunNow


    if (dmgIn or 0) > 0 and Bot.AllyLane and Bot.AllyLane.ally then
        Life.ffTaken = (Life.ffTaken or 0) + dmgIn
        debugEvery("fftaken", 2, string.format("ff? took %.0f inside %s's %s lane",
            dmgIn, tostring(Bot.AllyLane.ally), tostring(Bot.AllyLane.move)))
    end
end
















function memStallThreshold()
    local c = MEM.career
    if (c.time or 0) > 120 and (c.dmg or 0) > 0 then
        return math.max(Config.StallRateFloor,
                        (c.dmg / c.time) * Config.StallRateFrac)
    end
    return Config.StallRateFloor
end

function memIsStalling(hasTarget)
    if not Config.Memory or not hasTarget or not Life.active then return false end
    if (tick() - Life.startAt) < Config.StallGrace then return false end
    if Life.engaged < Config.StallGrace then return false end
    return Life.rate < memStallThreshold()
end

function memLifeRate() return Life.rate end
function memLifeInRate() return Life.inRate end
function memLifeEngaged()
    local dur = Life.active and (tick() - Life.startAt) or 0
    if dur < 1 then return 0 end
    return Life.engaged / dur
end

function memLifeStart()
    Life.active = true
    Life.startAt = tick()
    Life.dmg = 0
    Life.taken = 0
    Life.moves = 0
    Life.engaged = 0
    Life.blocks = 0
    Life.stunned = 0
    Life.rate = 0
    Life.inRate = 0
    Life.wasStunned = false
    Life.stunBy = {}
    Life.ffStuns = 0
    Life.ffTaken = 0
    Life.ffHolds = 0
    Life.refused = 0
    Life.bursts = 0
    Life.escapes = 0
    Life.frames = 0
    Life.worstDt = 0
    Life.dmgShared = 0

    Life.dmgFair = 0
    Life.unstamped = 0
    Life.reactJ = 0
    Life.reactK = 0
    Life.reactR = 0
    Life.sClean = 0
    Life.sShared = 0
    Life.sDirty = 0
    Bot.ComboHold = nil

    Life.attemptN = 0
    Life.holdN = 0
    Life.holdFreed = 0
    Life.sidesteps = 0
    Bot.LaneHeld = nil
    Bot.SidestepReq = nil
    Life.saves = 0
    Life.saveMax = 0
    Life.saveKB = 0
    Life.debrisSaid = false
    Life.cpuN = 0
    Life.cpuSum = 0
    Life.cpuMax = 0
    Life.cpu = { sense = 0, learn = 0, threat = 0, map = 0, state = 0, mem = 0, exec = 0, move = 0, rest = 0 }

    Life.pathN = 0
    Life.pathSum = 0
    Life.pathMax = 0
    Life.stunnedSelf = 0
    Life.stunSelf = false
    local st0 = MEM.stats or {}
    Life.stC0 = st0.clean or 0
    Life.stS0 = st0.shared or 0
    Life.stD0 = st0.dirty or 0
    Bot.DefendStrings = 0
    Bot.PathSec = 0
    Life.reversals = 0
    Life.kiteSec = 0
    Life.retreatSec = 0
    Life.char = nil
    Bot.UsedSkillsThisLife = {}
    Bot.NilStamp = nil
    Bot.InterceptUntil = 0
    Bot.InterceptDmg = 0


    Life.guardSec = 0
    Life.recoverN, Life.recoverDefend, Life.recoverAway = 0, 0, 0
    Life.domainSec = 0
    Life.punished = 0
    Life.blankSaid = nil
    Bot.RecoverUntil = 0
    Bot.InDomain = false
    Bot.MapPrevAt = 0
end










function memNoteStunStart()
    Life.stunBy = Life.stunBy or {}
    local key
    local lane = Bot.AllyLane
    if lane and lane.ally then
        key = "FF:" .. tostring(lane.ally) .. ":" .. tostring(lane.move)
        Life.ffStuns = (Life.ffStuns or 0) + 1
    else
        local h = getHRP()
        local who = Bot.Aggressor
        local wh = who and getHRP(who)













        local reach = Config.ThreatRange or 45
        if not (wh and h and (tick() - (Bot.AggressorAt or 0)) < (Config.AggroMemory or 6)
                and (wh.Position - h.Position).Magnitude <= reach) then
            who = nil
            local best
            for _, c in ipairs(Bot.HitCandidates or {}) do
                local ch = getHRP(c)
                if ch and h and not isAllyName(c.Name) then
                    local dd = (ch.Position - h.Position).Magnitude
                    if dd <= reach and (not best or dd < best) then best, who = dd, c end
                end
            end
        end
        if who then
            local set = who:GetAttribute("Moveset") or "?"


            local anim = senseStunMove(who)
            key = tostring(set) .. ":" .. tostring(anim or "?")
        elseif (tick() - (Bot.LastHurtAt or 0)) <= (Config.StunRangedWindow or 0.5) then
            key = "ranged:?"
        elseif inOwnMove() then





            key = "self:" .. tostring(Life.lastUsed or "?")
            Life.stunSelf = true
        else
            key = "?:?"












            local nearN, nearD = nil, nil
            if h then
                for _, pl in ipairs(Players:GetPlayers()) do
                    local pc = pl ~= LocalPlayer and pl.Character
                    local ph = pc and not isAllyName(pl.Name) and getHRP(pc)
                    if ph then
                        local dd = (ph.Position - h.Position).Magnitude
                        if not nearD or dd < nearD then nearN, nearD = pl.Name, dd end
                    end
                end
            end
            local lastAt = Life.lastUsedAt
            local castTxt = (lastAt and lastAt >= (Life.startAt or 0))
                            and string.format("%s %.1f s ago", tostring(Life.lastUsed), tick() - lastAt)
                            or "none this life"
            debugEvery("stun-unk", 5, string.format(
                "stun with nobody near: nearest %s, hurtAge %.1f s, inSkill=%s, ragdoll=%s, last cast %s",
                nearN and string.format("%s %.0f studs", nearN, nearD) or "none",
                tick() - (Bot.LastHurtAt or 0), tostring(inOwnMove()), tostring(isRagdolled()), castTxt))
        end
    end
    Life.stunBy[key] = (Life.stunBy[key] or 0) + 1



    if (Config.SwingPunishWindow or 0) > 0 and Life.lastUsed and Life.lastUsedAt
       and (tick() - Life.lastUsedAt) <= (Config.SwingPunishWindow or 1.5) then
        local g = MEM.global and MEM.global.moves and MEM.global.moves[Life.lastUsed]
        if g then g.pun = (g.pun or 0) + 1 end
        Life.punished = (Life.punished or 0) + 1
    end
end

function memStunBySummary()
    local rows = {}
    for k, n in pairs(Life.stunBy or {}) do table.insert(rows, { k = k, n = n }) end
    table.sort(rows, function(a, b) return a.n > b.n end)
    local parts = {}
    for i = 1, math.min(3, #rows) do
        table.insert(parts, string.format("%s x%d", rows[i].k, rows[i].n))
    end
    return #parts > 0 and table.concat(parts, ", ") or "-"
end


function memRecentAvg()
    local r = MEM.career.recent
    if not r or #r == 0 then return nil end
    local sum = 0
    for _, v in ipairs(r) do sum = sum + v end
    return sum / #r
end

function memCareerAvg()
    local c = MEM.career
    if (c.lives or 0) < 1 then return nil end
    return (c.dmg or 0) / c.lives
end





function memDeathDiscounted()
    local who = Bot.Aggressor
    local name = who and typeof(who) == "Instance" and who.Name or nil
    if not name or (tick() - (Bot.AggressorAt or 0)) > (Config.LearnDiscountWindow or 6) then return nil end
    local low = tostring(name):lower()
    for _, n in ipairs(Config.LearnDiscountKillers or {}) do
        if type(n) == "string" and n:lower() == low then return name end
    end
    if Config.LearnDiscountIgnored and type(isIgnoredName) == "function" and isIgnoredName(name) then return name end
    return nil
end

function memLifeEnd()
    if not Life.active then return end
    Life.active = false

    local dur = tick() - Life.startAt
    if dur < 3 then return end
    Life.discounted = memDeathDiscounted()

    local c = MEM.career









    local ch = getChar()
    local set = ch and ch:GetAttribute("Moveset")
    local kitBefore = set and memCharScore(set) or nil
    local kitDmg, avg = Life.dmg, memCareerAvg()
    if avg and (Config.KitLifeCap or 0) > 0 then kitDmg = math.min(Life.dmg, Config.KitLifeCap * avg) end
    c.lives = (c.lives or 0) + 1
    c.dmg = (c.dmg or 0) + Life.dmg
    c.time = (c.time or 0) + dur
    c.fdmg = (c.fdmg or 0) + (Life.dmgFair or 0)
    if Life.dmg > (c.best or 0) then c.best = Life.dmg end


    if set then
        local r = MEM.chars[set]
        if not r then r = { lives = 0, dmg = 0, time = 0, best = 0 }; MEM.chars[set] = r end
        if not (Life.discounted and r.lives > 0) then r.lives = r.lives + 1 end
        r.dmg = r.dmg + kitDmg
        r.time = r.time + dur
        r.fdmg = (r.fdmg or 0) + (Life.dmgFair or 0)
        if Life.dmg > (r.best or 0) then r.best = Life.dmg end
        r.recent = r.recent or {}
        if not Life.discounted then table.insert(r.recent, kitDmg) end
        while #r.recent > (Config.CharRecentLives or 8) do table.remove(r.recent, 1) end
    end
    local kitAfter = set and memCharScore(set) or nil

    c.recent = c.recent or {}
    table.insert(c.recent, Life.dmg)
    while #c.recent > Config.MemRecentLives do table.remove(c.recent, 1) end


    c.lifeLog = c.lifeLog or {}
    table.insert(c.lifeLog, { t = os.time(), ch = Life.char or set, dmg = math.floor(Life.dmg),
        dur = math.floor(dur), mv = Life.moves, st = math.floor(Life.stunned or 0), bl = Life.blocks or 0,
        eng = math.floor(100 * Life.engaged / math.max(1, dur)), rf = Life.refused or 0,
        bu = Life.bursts or 0, es = Life.escapes or 0, fps = math.floor((Life.frames or 0) / math.max(1, dur)) })
    while #c.lifeLog > 60 do table.remove(c.lifeLog, 1) end

    MemIO.dirty = true
    memSave(true, "death")

    local st = MEM.stats or {}
















    local cpu, frames = Life.cpu or {}, math.max(1, Life.cpuN or 0)
    local k1, k2, k3, v1, v2, v3 = "-", "-", "-", 0, 0, 0
    for k, v in pairs(cpu) do
        if v > v1 then k3, v3, k2, v2, k1, v1 = k2, v2, k1, v1, k, v
        elseif v > v2 then k3, v3, k2, v2 = k2, v2, k, v
        elseif v > v3 then k3, v3 = k, v end
    end
    local function count(tb)
        local n = 0
        if type(tb) == "table" then for _ in pairs(tb) do n = n + 1 end end
        return n
    end
    local okH, heap = pcall(collectgarbage, "count")
    if not okH or type(heap) ~= "number" then heap = -1 end
    local fx = Workspace:FindFirstChild("Effects")
    local tail = string.format(
        " | cpu %.2f ms/f (max %.0f) top: %s %.2f, %s %.2f, %s %.2f; guard %.1fs; recover %d (defend %d / away %d); domain %.0fs; punished %d; saves %d (max %.0f ms, %.0f KB); heap %.0f KB; effects %d; players %d; debris %d (touched %d); tables %d/%d/%d/%d/%d (Enemy/SpeedNorm/BadTargets/HitCandidates/SenseHooked)",
        (Life.cpuSum or 0) * 1000 / frames, (Life.cpuMax or 0) * 1000,
        k1, v1 * 1000 / frames, k2, v2 * 1000 / frames, k3, v3 * 1000 / frames,
        Life.guardSec or 0, Life.recoverN or 0, Life.recoverDefend or 0, Life.recoverAway or 0,
        Life.domainSec or 0, Life.punished or 0,
        Life.saves or 0, Life.saveMax or 0, Life.saveKB or 0,
        heap, fx and #fx:GetChildren() or 0, #Players:GetPlayers(),
        Bot.DebrisCount or 0, count(Bot.DebrisTouched),
        count(Enemy), count(SpeedNorm), count(Bot.BadTargets), count(Bot.HitCandidates), count(SenseHooked))



    local okI, inst = pcall(function() return #game:GetDescendants() end)
    tail = tail .. string.format(" | booked %d clean / %d shared / %d dirty | kit %s %.0f->%.0f | inst %d",
        Life.sClean or 0, Life.sShared or 0, Life.sDirty or 0,
        tostring(set or Life.char or "?"), kitBefore or 0, kitAfter or 0, (okI and type(inst) == "number") and inst or -1)




    tail = tail .. string.format(
        " | path %d computes (avg %.1f ms, max %.1f ms) | samples +%d/+%d/+%d | self-stun %.0fs | camProbe %s",
        Life.pathN or 0, (Life.pathSum or 0) * 1000 / math.max(1, Life.pathN or 0), (Life.pathMax or 0) * 1000,
        (st.clean or 0) - (Life.stC0 or 0), (st.shared or 0) - (Life.stS0 or 0), (st.dirty or 0) - (Life.stD0 or 0),
        Life.stunnedSelf or 0, tostring(Bot.CamProbe))
    tail = tail .. " | discounted " .. tostring(Life.discounted or "no")
    debug(string.format(
        "LIFE END: %.0f dmg in %.0fs (%.1f dmg/s, %d moves, %.0f%% engaged, %d blocks, %.0fs stunned) | %s | stunned by: %s | ff: %d held (holds %d/%d, freed %d, sidesteps %d), %.0f dmg + %d stuns in ally lanes | refused %d (rolled back %d), burst %d/%d, kite %.0fs, retreat %.0fs, revs %d, shared %.0f, fps %.0f (worst %.0f ms) | avg %.0f best %.0f over %d lives | samples %d clean / %d shared / %d dirty | fair %.0f | react %d judged / %d crowd / %d retests",
        Life.dmg, dur, Life.dmg / math.max(1, dur), Life.moves,
        (Life.engaged / math.max(1, dur)) * 100, Life.blocks or 0, Life.stunned or 0,
        tostring(Life.char or set or "?"),
        memStunBySummary(), Life.ffHolds or 0, Life.holdN or 0, Life.attemptN or 0, Life.holdFreed or 0, Life.sidesteps or 0,
        Life.ffTaken or 0, Life.ffStuns or 0,
        Life.refused or 0, Life.unstamped or 0, Life.bursts or 0, Life.escapes or 0, Life.kiteSec or 0, Life.retreatSec or 0,
        Life.reversals or 0, Life.dmgShared or 0, (Life.frames or 0) / math.max(1, dur), (Life.worstDt or 0) * 1000,
        memCareerAvg() or 0, c.best or 0, c.lives,
        st.clean or 0, st.shared or 0, st.dirty or 0, Life.dmgFair or 0, Life.reactJ or 0, Life.reactK or 0, Life.reactR or 0) .. tail)
end

function memLifeDmg() return Life.dmg end


dmgWatch = { targetHP = nil, ourHP = nil }










function memCanCredit(d2d)
    if (d2d or 999) > Config.MemCreditRange then return false end
    if (tick() - (Bot.LastOffense or 0)) > Config.MemCreditGrace then return false end
    return true
end

















function memAllyShare(t)
    if not t then return 0 end
    local th = getHRP(t)
    local range = Config.AllyShareRange or 25
    local plan = (type(teamPlan) == "function") and teamPlan() or nil
    local rows = plan and plan.allies
    local n = 0
    for _, name in ipairs(Config.Allies or {}) do
        if name ~= LocalPlayer.Name then
            local pl = Players:FindFirstChild(name)
            local c = pl and pl.Character
            local ah = c and getHRP(c)
            if ah then
                if th and getHP(c) > 0 and (ah.Position - th.Position).Magnitude <= range then n = n + 1 end
            elseif rows then
                for _, a in ipairs(rows) do
                    if a.name == name then
                        if a.target and a.target == t.Name then n = n + 1 end
                        break
                    end
                end
            end
        end
    end
    return n
end












function memNearTarget(t)
    if not t then return 0, 0 end
    local allies = memAllyShare(t)
    if not Config.FairBooking then return allies, allies end
    local th = getHRP(t)
    if not th then return allies, allies end
    local range = Config.AllyShareRange or 25
    local n = allies
    for _, pl in ipairs(Players:GetPlayers()) do
        local c = pl ~= LocalPlayer and pl.Character
        if c and c ~= t and not isAllyName(pl.Name) then
            local ph = getHRP(c)
            if ph and getHP(c) > 0 and (ph.Position - th.Position).Magnitude <= range then n = n + 1 end
        end
    end
    return n, allies
end

function memTrackDamage(t, d2d)
    Bot.FrameDmgOut, Bot.FrameDmgIn = 0, 0
    if not Config.Memory then return end


    local myHP = getHP()
    if dmgWatch.ourHP and myHP < dmgWatch.ourHP then
        local lost = dmgWatch.ourHP - myHP
        Life.taken = Life.taken + lost
        Bot.FrameDmgIn = lost
        if t then
            local rec = memFor(t)
            if rec then
                rec.dmgTaken = (rec.dmgTaken or 0) + lost
                MemIO.dirty = true
            end
        end
    end
    dmgWatch.ourHP = myHP

    if not t then
        dmgWatch.targetHP = nil
        return
    end

    local hp = getHP(t)
    if dmgWatch.targetHP and hp < dmgWatch.targetHP and memCanCredit(d2d) then
        local dealt = dmgWatch.targetHP - hp
        Life.dmg = Life.dmg + dealt
        Bot.FrameDmgOut = dealt







        local share, allies = memNearTarget(t)
        if allies > 0 then Life.dmgShared = (Life.dmgShared or 0) + dealt end
        Life.dmgFair = (Life.dmgFair or 0) + dealt / (share + 1)
        local rec = memFor(t)
        if rec then
            rec.dmgDealt = (rec.dmgDealt or 0) + dealt
            local b = rangeBucket(d2d)
            rec.dmgByRange[b] = (rec.dmgByRange[b] or 0) + dealt
            MemIO.dirty = true
        end
    end
    dmgWatch.targetHP = hp
end










pending = {}



lastMove, lastMoveAt = nil, 0


function memUnrecordUse(moveName, at)
    for idx = #pending, 1, -1 do
        local p = pending[idx]
        if p.move == moveName and math.abs((p.at or 0) - (at or -1)) < 0.05 then
            table.remove(pending, idx)
            Life.moves = math.max(0, (Life.moves or 1) - 1)





            local rolled = false
            if Config.CastRollback then
                if lastMove == moveName and math.abs((lastMoveAt or 0) - (p.at or 0)) < 0.05 then
                    lastMove, lastMoveAt = p.prevMove, p.prevMoveAt or 0
                    rolled = true
                end
                for j = 1, #pending do
                    local q = pending[j]
                    if q.prevMove == moveName and math.abs((q.prevMoveAt or 0) - (p.at or 0)) < 0.05 then



                        q.prev = (p.prevMove and ((q.at or 0) - (p.prevMoveAt or 0)) <= Config.ComboWindow)
                            and p.prevMove or nil
                        q.prevMove, q.prevMoveAt = p.prevMove, p.prevMoveAt
                        rolled = true
                    end
                end
            end
            return true, rolled
        end
    end
    return false
end

function memRecordUse(moveName, t, dist)
    if not Config.Memory or not moveName or not t then return end

    local prev = nil

    if lastMove and (tick() - lastMoveAt) <= Config.ComboWindow
       and not (Config.ChainNoSelf and lastMove == moveName) then
        prev = lastMove
    end


    local near, alone = 0, (Bot.Hostiles or 0) <= 1
    if Config.FairBooking then
        near = memNearTarget(t)
        alone = (near == 0)
    elseif alone then
        near = memAllyShare(t)
    end

    table.insert(pending, {
        move = moveName,
        prev = prev,
        target = t,
        key = memKey(t),
        hp0 = getHP(t),
        at = tick(),
        dist = dist,
        seen = 0,












        alone = alone,
        allies = near,

        prevMove = lastMove,
        prevMoveAt = lastMoveAt,
    })

    lastMove, lastMoveAt = moveName, tick()
    Life.moves = Life.moves + 1
end



function memLastMoveRaw()
    return lastMove, lastMoveAt
end


function memLastMove()
    if lastMove and (tick() - lastMoveAt) <= Config.ComboWindow then
        return lastMove
    end








    if type(teamLastMove) == "function" then
        local ok, mv = pcall(teamLastMove)
        if ok and mv then return mv end
    end
    return nil
end




local function bumpMove(tbl, moveName, hit, dmg, w)
    local m = tbl[moveName]
    if not m then
        m = { tries = 0, hits = 0, dmg = 0 }
        tbl[moveName] = m
    end
    w = w or 1
    m.tries = (m.tries or 0) + 1
    if hit then
        m.hits = (m.hits or 0) + w
        m.dmg = (m.dmg or 0) + (dmg or 0) * w
    end
end














function memResolve()
    if #pending == 0 then return end
    local now = tick()

    for idx = #pending, 1, -1 do
        local p = pending[idx]
        local elapsed = now - p.at

        if elapsed >= Config.MemCreditWindow then
            local alive = p.target and p.target.Parent
            local hp1 = alive and getHP(p.target) or 0
            local dmg = (p.hp0 or 0) - hp1

            local climbing = dmg > (p.seen or 0) + 0.5
            if climbing and elapsed < Config.MemCreditMax then
                p.seen = dmg
            else
                table.remove(pending, idx)

                dmg = math.min(dmg, Config.MemCreditCap)
                local hit = dmg > 0.5










                local fair = Config.FairBooking
                local clean = (fair or p.alone) and (Bot.Target == nil or Bot.Target == p.target)
                              and (alive or not fair)

                if clean then
                    local share = p.allies or 0
                    if alive then
                        local nowShare = fair and memNearTarget(p.target) or memAllyShare(p.target)
                        if nowShare > share then share = nowShare end
                    end
                    local w = fair and 1 / (share + 1) or 1
                    local rec = p.key and MEM.opponents[p.key]
                    if rec then bumpMove(rec.moves, p.move, hit, dmg, w) end
                    bumpMove(MEM.global.moves, p.move, hit, dmg, w)







                    if p.prev then
                        local row = MEM.chains[p.prev]
                        if not row then row = {}; MEM.chains[p.prev] = row end
                        bumpMove(row, p.move, hit, dmg, w)
                    end

                    if p.dist and (share == 0 or not fair) then memNoteRange(p.move, p.dist, hit) end
                    if hit then
                        local g = MEM.global.moves[p.move]
                        if g then g.fdmg = (g.fdmg or 0) + dmg / (share + 1) end
                    end
                    if share > 0 then
                        MEM.stats.shared = (MEM.stats.shared or 0) + 1
                        Life.sShared = (Life.sShared or 0) + 1
                    else
                        MEM.stats.clean = (MEM.stats.clean or 0) + 1
                        Life.sClean = (Life.sClean or 0) + 1
                    end
                else
                    MEM.stats.dirty = (MEM.stats.dirty or 0) + 1
                    Life.sDirty = (Life.sDirty or 0) + 1
                end

                MemIO.dirty = true
            end
        end
    end
end










function memExploreBoost()
    local base = Config.MemExploreBoost
    local recent, career = memRecentAvg(), memCareerAvg()
    if not recent or not career or career <= 0 then return base end

    local ratio = recent / career
    if ratio < 0.8 then
        return base + Config.MemExploreSwing
    elseif ratio > 1.2 then
        return math.max(1.0, base - Config.MemExploreSwing)
    end
    return base
end











function memChainStrong(opener, f)
    local row = opener and MEM.chains and MEM.chains[opener]
    local m = row and f and row[f]
    if not m or (m.tries or 0) <= 0 or (m.hits or m.tries or 0) < (Config.StrongChainSamples or 8) then return false end
    local g = MEM.global and MEM.global.moves and MEM.global.moves[f]
    local own = (g and (g.tries or 0) > 0) and (g.dmg or 0) / g.tries or 0
    return (m.dmg or 0) / m.tries >= (Config.StrongChainRatio or 1.5) * math.max(0.3, own)
end

function memChainWeight(moveName, maxChain)
    if not Config.Memory or not moveName then return 1 end

    local prev = memLastMove()

    if not prev or (Config.ChainNoSelf and prev == moveName) then return 1 end

    local row = MEM.chains[prev]
    local m = row and row[moveName]
    if not m or (m.tries or 0) < Config.ChainMinSamples then return 1 end
    if not maxChain or maxChain <= 0 then return 1 end

    local dpt = (m.dmg or 0) / m.tries
    local norm = math.clamp(dpt / maxChain, 0, 1)
    local w = 0.85 + Config.ComboWeight * norm

    if (Config.StrongChainBoost or 0) > 0 and memChainStrong(prev, moveName) then w = w * Config.StrongChainBoost end
    return w
end




















function memSetupValue(moveName)
    if not Config.Memory or not moveName then return 0 end
    local row = MEM.chains[moveName]
    if not row then return 0 end

    local best = 0


    for bname, m in pairs(row) do
        if (m.tries or 0) >= Config.ChainMinSamples and not (Config.ChainNoSelf and bname == moveName) then
            local dpt = (m.dmg or 0) / m.tries
            if dpt > best then best = dpt end
        end
    end
    return best * Config.SetupDiscount
end


function memMaxChain(entries)
    local prev = memLastMove()
    if not prev then return 0 end
    local row = MEM.chains[prev]
    if not row then return 0 end

    local best = 0
    for _, e in ipairs(entries) do
        local name = e.name or e
        local m = row[name]
        if m and (m.tries or 0) >= Config.ChainMinSamples and not (Config.ChainNoSelf and name == prev) then
            local dpt = (m.dmg or 0) / m.tries
            if dpt > best then best = dpt end
        end
    end
    return best
end


















function memBestFollowUp(opener)
    local row = MEM.chains[opener]
    if not row then return nil end
    local bestName, bestDpt = nil, 0
    for f, m in pairs(row) do
        if f ~= opener and (m.tries or 0) >= (Config.ComboHoldTries or 8) then
            local dpt = (m.dmg or 0) / m.tries
            local g = MEM.global.moves[f]
            local own = (g and (g.tries or 0) > 0) and (g.dmg or 0) / g.tries or 0
            if dpt >= (Config.ComboHoldMinDpt or 2) and dpt >= (Config.ComboHoldRatio or 2) * own
               and dpt > bestDpt then
                bestName, bestDpt = f, dpt
            end
        end
    end
    if not bestName then return nil end
    for _, m in pairs(getAvailableMoves()) do
        if m.value.Name == bestName then
            local left = m.readyAt and (m.readyAt - Workspace:GetServerTimeNow()) or 0
            return bestName, math.max(0, left)
        end
    end
    return nil
end

function memComboHold(opener, rule, t)
    if not Config.ComboHold or not Config.Memory or not t or not opener then return false end
    local hold = Bot.ComboHold
    if hold and hold.target ~= t then Bot.ComboHold = nil; return false end
    if rule and (rule.escape or rule.counter) then return false end
    if getHPPct() < (Config.ComboHoldMinHP or 40) then return false end
    if tick() - (Bot.LastSwingAt or 0) < 0.5 then return false end
    local f, left = memBestFollowUp(opener)

    local cap = Config.ComboHoldMax or 5
    if f and (Config.StrongHoldFactor or 0) > 0 and memChainStrong(opener, f) then cap = cap * Config.StrongHoldFactor end
    if not f or left <= 0 or left > cap then return false end
    if not hold or hold.opener ~= opener or tick() - hold.since > cap + 1 then
        Bot.ComboHold = { opener = opener, follow = f, target = t, since = tick() }
        debugEvery("combo:" .. tostring(opener), 2,
            string.format("combo: holding %s for %s (%.1fs)", tostring(opener), tostring(f), left))
    end
    return true
end







function memMoveStats(moveName, t)
    local function readFrom(tbl)
        local m = tbl and tbl[moveName]
        if not m or (m.tries or 0) == 0 then return nil end
        return { tries = m.tries, dpt = (m.dmg or 0) / m.tries, hit = (m.hits or 0) / m.tries }
    end

    local g = readFrom(MEM.global.moves)
    local o = nil
    if t then
        local rec = MEM.opponents[memKey(t) or ""]
        o = readFrom(rec and rec.moves)
    end

    local tries = math.max(o and o.tries or 0, g and g.tries or 0)


    local hit = (g and g.tries or 0) >= (o and o.tries or 0) and (g and g.hit) or (o and o.hit)
    local dpt
    if o and g then



        local m8 = Config.MemOppMinTries or 0
        local w = (m8 > 0) and math.clamp((o.tries - m8) / m8, 0, 1) or math.min(1, o.tries / 8)
        dpt = o.dpt * w + g.dpt * (1 - w)
    else
        dpt = (o and o.dpt) or (g and g.dpt) or nil
    end

    return dpt, tries, hit
end
















function memIsDud(moveName, maxDpt)
    if not Config.Memory or not moveName then return false end
    local dpt, tries, hit = memMoveStats(moveName, nil)
    if not dpt or tries < Config.DudMinTries then return false end












    local rule = memRangeRule(moveName)
    if rule and rule.kind == "utility" then return false end
    local utility = rule and (rule.cc or rule.trap or rule.selfBuff or rule.summon
                              or rule.escape or rule.counter or rule.grab)
    if not utility and hit and tries >= Config.DudHardTries
       and hit < (Config.DudHitFloor or 0.08) then
        return true, true
    end












    if tries >= Config.DudHardTries and dpt < Config.DudHardFloor then
        return true, true
    end

    if not maxDpt or maxDpt <= 0 then return false end
    return dpt < maxDpt * Config.DudFraction
end


function memIsHardDud(moveName)
    local _, hard = memIsDud(moveName, nil)
    return hard == true
end











function memDudParole(moveName, grant)
    if not Config.DudParole or not Config.Memory or not moveName then return false end
    local set = Life.char
    if not set then
        local c = getChar()
        set = c and c:GetAttribute("Moveset")
    end
    local kit = set and MEM.chars[set]
    local lives = kit and kit.lives or 0
    local m = MEM.global.moves[moveName]
    if not m then return false end
    if m.parole and (lives - m.parole) < (Config.DudParoleLives or 10) then return false end
    if grant then
        m.parole = lives
        MemIO.dirty = true
        debug(string.format("parole: %s (%d tries, %.2f dmg/try, kit life %d)", tostring(moveName),
            m.tries or 0, (m.dmg or 0) / math.max(1, m.tries or 0), lives))
    end
    return true
end



function memMoveWeight(moveName, t, maxDpt)
    if not Config.Memory or not moveName then return 1 end

    local dpt, tries = memMoveStats(moveName, t)

    if tries < Config.MemMinSamples or not dpt then
        return memExploreBoost()
    end
    if not maxDpt or maxDpt <= 0 then return 1 end

    local norm = math.clamp(dpt / maxDpt, 0, 1)
    return 0.55 + 0.9 * norm
end


function memMaxDpt(entries, t)
    local best = 0
    for _, e in ipairs(entries) do
        local dpt = memMoveStats(e.name or e, t)
        if dpt and dpt > best then best = dpt end
    end
    return best
end






PlanCache = { key = nil, at = 0, plan = nil }










function memMatchupPenalty(c)
    if not Config.Memory or not c then return 0 end
    local key = memKey(c)
    local rec = key and MEM.opponents[key]
    if not rec then return 0 end



    local dealt, taken = rec.dmgDealt or 0, rec.dmgFrom or 0
    local total = dealt + taken
    if taken <= 0 or total < (Config.MatchupMinDmg or 300) then return 0 end
    local pen = math.clamp((taken - dealt) / total, 0, 1)
    if pen > 0 and ((rec.deaths or 0) - (rec.kills or 0)) >= 2 then pen = math.min(1, pen + 0.25) end
    return pen
end

function memPlanFor(t)
    local blank = {
        blocky = 0, chaser = 0, aggressive = 0, avgDist = 0,
        bestRange = nil, flankEarly = false, punishEarly = false,
        closeHard = false, known = false, summary = "new opponent",
    }
    if not Config.Memory or not t then return blank end

    local key = memKey(t)
    if not key then return blank end


    if PlanCache.key == key and (tick() - PlanCache.at) < 1.0 and PlanCache.plan then
        return PlanCache.plan
    end

    local rec = MEM.opponents[key]
    if not rec then return blank end

    local o = rec.obs or {}
    local n = math.max(1, o.samples or 0)
    local plan = {
        blocky = (o.blocking or 0) / n,
        aggressive = (o.inSkill or 0) / n,
        avgDist = (o.distSum or 0) / n,
        chaser = (o.chaseChances or 0) > 20
                 and ((o.chasing or 0) / math.max(1, o.chaseChances)) or 0,
        known = (rec.seen or 0) > 0 and (o.samples or 0) > 60,
    }


    local bestB, bestV = nil, 0
    for b, v in pairs(rec.dmgByRange or {}) do

        if tonumber(b) and tonumber(b) <= MemMaxRangeBucket and v > bestV then
            bestB, bestV = b, v
        end
    end
    if bestB and bestV > 50 then
        plan.bestRange = tonumber(bestB) * 10 + 5
    end

    plan.flankEarly  = plan.known and plan.blocky > 0.25
    plan.punishEarly = plan.known and plan.chaser > 0.45
    plan.closeHard   = plan.known and plan.avgDist > 26

    local bits = {}
    if plan.flankEarly  then table.insert(bits, "turtle") end
    if plan.punishEarly then table.insert(bits, "chaser") end
    if plan.closeHard   then table.insert(bits, "camper") end
    if plan.aggressive > 0.35 then table.insert(bits, "aggressive") end
    if plan.bestRange then table.insert(bits, "best@" .. math.floor(plan.bestRange)) end

    plan.summary = (#bits > 0) and table.concat(bits, "/")
                   or (plan.known and "unremarkable" or "learning")

    PlanCache.key, PlanCache.at, PlanCache.plan = key, tick(), plan
    return plan
end


function memNewEncounter(t)
    if not Config.Memory or not t then return end
    local rec = memFor(t)
    if not rec then return end
    rec.seen = (rec.seen or 0) + 1
    rec.lastSeen = os.time()
    MemIO.dirty = true

    local plan = memPlanFor(t)
    debug(string.format("opponent %s: seen %dx, K/D %d/%d, dealt %.0f taken %.0f [%s]",
        rec.name, rec.seen, rec.kills or 0, rec.deaths or 0,
        rec.dmgDealt or 0, rec.dmgTaken or 0, plan.summary))
end

function memNoteKill(t)
    if not Config.Memory or not t then return end
    local rec = memFor(t)
    if rec then
        rec.kills = (rec.kills or 0) + 1





        MemIO.dirty = true
    end
end

function memNoteDeath(t)
    if not Config.Memory or not t then return end
    if memDeathDiscounted() then return end
    local rec = memFor(t)
    if rec then
        rec.deaths = (rec.deaths or 0) + 1



        MemIO.dirty = true
    end
end

memLoad()


ReactWatch = nil


function memReactStart(move, reaction)
    if not Config.Memory or not move or not reaction then return end
    ReactWatch = { move = move, reaction = reaction, at = tick(), hp0 = getHP(),
                   crowd = (Bot.Hostiles or 0) > 1 }
end


function memReactResolve()
    if not ReactWatch then return end
    if (tick() - ReactWatch.at) < Config.ReactJudgeWindow then return end






    local took = math.min(math.max(0, (ReactWatch.hp0 or 0) - getHP()), Config.ReactCap or 999)
    local row = MEM.reactions[ReactWatch.move]
    if not row then row = {}; MEM.reactions[ReactWatch.move] = row end

    local r = row[ReactWatch.reaction]
    if not r then r = { tries = 0, dmg = 0 }; row[ReactWatch.reaction] = r end
    local w = ReactWatch.crowd and (Config.ReactCrowdWeight or 1) or 1
    r.tries = r.tries + w
    r.dmg = r.dmg + took * w



    Life.reactJ = (Life.reactJ or 0) + 1
    if ReactWatch.crowd then Life.reactK = (Life.reactK or 0) + 1 end

    if Config.DebugSense then
        debug(string.format("reaction %s vs %s: took %.0f (avg %.1f over %d)",
            ReactWatch.reaction, ReactWatch.move, took, r.dmg / r.tries, r.tries))
    end

    ReactWatch = nil
    MemIO.dirty = true
end


















ReactOptions = {



    grab    = { "away", "dodge" },
    pull    = { "block", "away", "dodge" },
    beam    = { "dodge", "block", "away" },
    rush    = { "block", "dodge", "away" },
    aoe     = { "away", "dodge", "block" },
    counter = { "hold", "away" },
}


ReactPrefer = { Rush = "dodge", CleaveRush = "dodge", LuckyRushdown = "dodge" }

function memBestReaction(move, fallback, kind)
    if not Config.Memory or not move then return fallback end

    local row = MEM.reactions[move]
    local pref = ReactPrefer[move]
    if pref then
        local rec = row and row[pref]
        if not rec or (rec.tries or 0) < (Config.ReactMinSamples or 3) then return pref end
        fallback = pref
    end
    if not row then return fallback end

    local options = ReactOptions[kind or ""] or { fallback }








    if Unblockable[move] then
        local keep = {}
        for _, r in ipairs(options) do
            if r ~= "block" then table.insert(keep, r) end
        end
        if #keep > 0 then options = keep end
        if fallback == "block" then fallback = options[1] end
    end



    local untested = {}
    for _, r in ipairs(options) do
        local rec = row[r]
        if not rec or (rec.tries or 0) < Config.ReactMinSamples then
            table.insert(untested, r)
        end
    end
    if #untested > 0 then
        return untested[math.random(1, #untested)]
    end






    local sumD, sumT = 0, 0
    for _, r in ipairs(options) do
        local rec = row[r]
        if rec and (rec.tries or 0) > 0 then sumD, sumT = sumD + (rec.dmg or 0), sumT + rec.tries end
    end
    local rowMean, k = (sumT > 0) and sumD / sumT or 0, Config.ReactShrink or 0
    local best, bestAvg, least, leastN = nil, nil, nil, nil
    for _, r in ipairs(options) do
        local rec = row[r]
        if rec and (rec.tries or 0) > 0 then
            local avg = ((rec.dmg or 0) + rowMean * k) / (rec.tries + k)
            if not bestAvg or avg < bestAvg then best, bestAvg = r, avg end
            if not leastN or rec.tries < leastN then least, leastN = r, rec.tries end
        end
    end


    if best and math.random() < Config.ReactRetest then
        Life.reactR = (Life.reactR or 0) + 1
        if Config.ReactRetestLeast and least then return least end
        return options[math.random(1, #options)]
    end
    return best or fallback
end














local function rangeBucket5(d)
    local b = math.floor((d or 0) / 5)
    if b < 0 then b = 0 end
    if b > 15 then b = 15 end
    return tostring(b)
end

function memNoteRange(move, dist, hit)
    if not Config.Memory or not move or not dist then return end
    local row = MEM.ranges[move]
    if not row then row = {}; MEM.ranges[move] = row end

    local k = rangeBucket5(dist)
    local b = row[k]
    if not b then b = { tries = 0, hits = 0 }; row[k] = b end
    b.tries = b.tries + 1
    if hit then b.hits = b.hits + 1 end
    MemIO.dirty = true
end



function memLearnedRange(move)
    if not Config.Memory or not move then return nil end
    local row = MEM.ranges[move]
    if not row then return nil end

    local total, lo, hi = 0, nil, nil










    local q = MemIO.rangeQ
    if not q then q = {}; MemIO.rangeQ = q end
    for i = 0, 15 do q[i] = false end
    local bestB, bestH, bestR, bestT = nil, -1, -1, -1
    for k, b in pairs(row) do
        total = total + (b.tries or 0)
        local n = tonumber(k)
        if n and n >= 0 and n <= 15 then
            q[n] = b
            if memRangeQual(b) then
                local h, r = b.hits or 0, (b.hits or 0) / b.tries
                if h > bestH or (h == bestH and (r > bestR or (r == bestR and b.tries > bestT))) then
                    bestB, bestH, bestR, bestT = n, h, r, b.tries
                end
            end
        end
    end

    if total < Config.MemRangeMinSamples or not bestB then return nil end
    lo, hi = bestB, bestB
    while lo > 0 and memRangeQual(q[lo - 1]) do lo = lo - 1 end
    while hi < 15 and memRangeQual(q[hi + 1]) do hi = hi + 1 end

    local lowest, highest = 0, 200
    local rule = Config.RangeClamp and memRangeRule(move) or nil
    if rule and rule.min and rule.max then
        lowest = math.max(0, rule.min - (Config.RangeClampUnder or 5))
        highest = rule.max + (Config.RangeClampOver or 15)
    end
    local widened = false
    while hi - lo + 1 < (Config.MemRangeMinWidth or 1) do
        local dn, up = q[lo - 1], q[hi + 1]
        local canDn = lo > 0 and lo * 5 > lowest
        local canUp = hi < 14 and (hi + 1) * 5 < highest
        if not canDn and not canUp then break end
        if canDn and (not canUp or (dn and dn.hits or 0) >= (up and up.hits or 0)) then lo = lo - 1 else hi = hi + 1 end
        widened = true
    end

    local minStuds, maxStuds = lo * 5, (hi >= 15) and 200 or ((hi + 1) * 5)



















    if rule and rule.min and rule.max then
        if minStuds < lowest or maxStuds > highest then
            local rawLo, rawHi = minStuds, maxStuds
            minStuds = math.max(minStuds, lowest)
            maxStuds = math.min(maxStuds, highest)
            if maxStuds - minStuds < 5 then minStuds, maxStuds = lowest, highest end
            return minStuds, maxStuds, total, rawLo, rawHi, widened
        end
    end
    return minStuds, maxStuds, total, nil, nil, widened
end




function memRangeRule(move)
    local r = MoveRules[move]
    if r then return r end
    local byKey = MemIO.specialRules
    if not byKey then
        byKey = {}
        for _, sr in pairs(SpecialRules) do
            if type(sr) == "table" and sr.name then byKey["SPECIAL:" .. sr.name] = sr end
        end
        MemIO.specialRules = byKey
    end
    return byKey[move]
end



function memRangeQual(b)
    return (b and (b.tries or 0) >= Config.MemRangeMinBucket
            and (b.hits or 0) / b.tries >= Config.MemRangeMinRate) or false
end






function memRangeEdgeProbe(move, d2d)
    local lo, hi = memLearnedRange(move)
    if not lo then return true end
    if not Config.RangeEdgeProbe or not d2d then return false end
    if (hi - lo) < (Config.MemRangeMinWidth or 1) * 5 then return true end
    local row = MEM.ranges[move]
    local b
    if d2d < lo and d2d >= lo - 5 then
        b = row and row[tostring(math.floor(lo / 5) - 1)]
    elseif d2d > hi and d2d <= hi + 5 then
        b = row and row[tostring(math.floor(hi / 5))]
    else
        return false
    end
    return (not b) or (b.tries or 0) < Config.MemRangeMinBucket
end


pcall(function()
    local n, clamped, widened = 0, 0, 0
    for move in pairs(MEM.ranges or {}) do
        local lo, hi, _, rawLo, rawHi, wide = memLearnedRange(move)
        if lo then
            n = n + 1
            if wide then widened = widened + 1 end
            if rawLo then
                clamped = clamped + 1
                local r = memRangeRule(move)
                debug(string.format("memory: learned range of %s %d-%d clamped to %d-%d (rule %d-%d)",
                    tostring(move), rawLo, rawHi, lo, hi, r and r.min or -1, r and r.max or -1))
            end
        end
    end
    debug(string.format("memory: learned envelopes %d, clamped %d, widened %d%s", n, clamped, widened,
        Config.RangeClamp and "" or " (RangeClamp off)"))
end)











UnknownPending = {}

function memNoteUnknownMove(moveKey, char)
    if not Config.Memory or not moveKey then return end



    if CharServices[moveKey] then return end
    local known = MEM.adopted[moveKey]
    if known and known.kind then return end


    for _, p in ipairs(UnknownPending) do
        if p.move == moveKey then return end
    end

    table.insert(UnknownPending, { move = moveKey, at = tick(), hp0 = getHP() })
    if #UnknownPending > 12 then table.remove(UnknownPending, 1) end
end

function memResolveUnknown()
    if #UnknownPending == 0 then return end
    local now = tick()

    for i = #UnknownPending, 1, -1 do
        local p = UnknownPending[i]
        if (now - p.at) >= Config.AdoptWindow then
            table.remove(UnknownPending, i)

            local took = math.max(0, (p.hp0 or 0) - getHP())
            if took >= Config.AdoptMinDamage then
                local a = MEM.adopted[p.move]
                if not a then a = { hits = 0, dmg = 0 }; MEM.adopted[p.move] = a end
                a.hits = (a.hits or 0) + 1
                a.dmg = (a.dmg or 0) + took

                if not a.kind and a.hits >= Config.AdoptMinSamples then


                    a.kind = "rush"
                    debug(string.format(
                        "adopted %s as a threat (%d hits, %.0f avg damage) -> will react",
                        p.move, a.hits, a.dmg / a.hits))
                end
                MemIO.dirty = true
            end
        end
    end
end

function memAdoptedKind(moveKey)
    local a = moveKey and MEM.adopted[moveKey]
    return a and a.kind or nil
end


function memCharLives(name)
    local r = name and MEM.chars[name]
    return r and (r.lives or 0) or 0
end















function memCharScore(name)
    local r = name and MEM.chars[name]
    if not r or (r.lives or 0) < 1 then return nil end

    local careerAvg = memCareerAvg() or 0
    local k = Config.CharPriorLives
    local all = (r.dmg + careerAvg * k) / (r.lives + k)




    local b, rec = Config.CharRecentBlend or 0, r.recent
    if b <= 0 or type(rec) ~= "table" or #rec == 0 then return all, all, all end
    local sum = 0
    for _, v in ipairs(rec) do sum = sum + v end
    local last = (sum + careerAvg * k) / (#rec + k)
    return all * (1 - b) + last * b, all, last
end




























function memCharFails(name)
    local f = name and MEM.charFails[name]
    return f and (f.n or 0) or 0
end

function memNoteCharFail(name)
    if not name then return end
    local f = MEM.charFails[name]
    if not f then f = { n = 0, last = 0 }; MEM.charFails[name] = f end
    f.n = (f.n or 0) + 1
    f.last = os.time()
    MemIO.dirty = true
    return f.n
end

function memClearCharFail(name)
    if name and MEM.charFails[name] then
        MEM.charFails[name] = nil
        MemIO.dirty = true
    end
end


function memCharBackoff(name)
    local n = memCharFails(name)
    if n == 0 then return 0 end
    return Config.CharLockExpiry * math.min(2 ^ (n - 1), 32)
end

function memCharRested(name)
    local f = name and MEM.charFails[name]
    if not f then return true end
    return (os.time() - (f.last or 0)) > memCharBackoff(name)
end

function memCharLocked(name)
    if not name then return false end



    if memCharLives(name) > 0 then return false end

    local at = MEM.locked[name]
    if not at then return false end
    if type(at) ~= "number" then return true end

    if (os.time() - at) > Config.CharLockExpiry then
        MEM.locked[name] = nil
        MemIO.dirty = true
        return false
    end
    return true
end

function memLockChar(name)
    if not name then return end
    MEM.locked[name] = os.time()
    MemIO.dirty = true
end


function memClearLocks()
    local n = 0
    for _ in pairs(MEM.locked) do n = n + 1 end
    MEM.locked = {}
    MemIO.dirty = true
    return n
end


function memCharReport()
    local rows = {}
    for n, r in pairs(MEM.chars) do
        if (r.lives or 0) > 0 then
            table.insert(rows, { n = n, avg = r.dmg / r.lives, lives = r.lives })
        end
    end
    table.sort(rows, function(a, b) return a.avg > b.avg end)

    local out = {}
    for i = 1, math.min(6, #rows) do
        table.insert(out, string.format("%s %.0f(%d)", rows[i].n, rows[i].avg, rows[i].lives))
    end
    return table.concat(out, "  ")
end















function memRecentChars()
    return MEM.recentChars or {}
end



function memNoteCharPlayed(name)
    if not name then return end
    MEM.recentChars = MEM.recentChars or {}


    for i = #MEM.recentChars, 1, -1 do
        if MEM.recentChars[i] == name then table.remove(MEM.recentChars, i) end
    end

    table.insert(MEM.recentChars, name)
    while #MEM.recentChars > Config.CharNoRepeat do
        table.remove(MEM.recentChars, 1)
    end
    MemIO.dirty = true
end











function memNoteEnemyCombo(moveset, seq, dmg, band, angle)
    if not Config.Memory or not moveset or dmg <= 0 then return end

    if seq then
        local row = MEM.enemyCombos[moveset]
        if not row then row = {}; MEM.enemyCombos[moveset] = row end
        local e = row[seq]
        if not e then e = { n = 0, dmg = 0 }; row[seq] = e end
        e.n = e.n + 1
        e.dmg = e.dmg + dmg
    end

    if band then
        local key = band .. "|" .. (angle or "front")
        local row = MEM.enemyOpens[moveset]
        if not row then row = {}; MEM.enemyOpens[moveset] = row end
        local e = row[key]
        if not e then e = { n = 0, dmg = 0 }; row[key] = e end
        e.n = e.n + 1
        e.dmg = e.dmg + dmg
    end
    MemIO.dirty = true
end


function memEnemyWorstCombo(moveset)
    local row = moveset and MEM.enemyCombos[moveset]
    if not row then return nil end
    local best, bestAvg = nil, 0
    for seq, e in pairs(row) do
        if (e.n or 0) >= Config.EnemyMinSamples then
            local avg = e.dmg / e.n
            if avg > bestAvg then best, bestAvg = seq, avg end
        end
    end
    return best, bestAvg
end








function memEnemyWorstBand(moveset)
    local row = moveset and MEM.enemyOpens[moveset]
    if not row then return nil end

    local tally = {}
    for key, e in pairs(row) do
        local band = string.match(key, "^([^|]+)")
        if band then
            local t = tally[band]
            if not t then t = { n = 0, dmg = 0 }; tally[band] = t end
            t.n = t.n + (e.n or 0)
            t.dmg = t.dmg + (e.dmg or 0)
        end
    end

    local best, bestAvg, total = nil, 0, 0
    for band, t in pairs(tally) do
        total = total + t.n
        local avg = t.dmg / math.max(1, t.n)
        if avg > bestAvg then best, bestAvg = band, avg end
    end
    if total < Config.EnemyMinSamples then return nil end
    return best, bestAvg
end

function memEnemyReport(moveset)
    local combo, cAvg = memEnemyWorstCombo(moveset)
    local band, bAvg = memEnemyWorstBand(moveset)
    local bits = {}
    if combo then table.insert(bits, combo .. " " .. string.format("%.0f", cAvg)) end
    if band then table.insert(bits, "worst at " .. band .. " studs") end
    return table.concat(bits, ", ")
end
















EnemyTrial = nil

function memEnemyTrialStart(moveset, what)
    if not Config.Memory or not moveset then return end
    if EnemyTrial then return end
    EnemyTrial = {
        set = moveset,
        what = what,
        at = tick(),
        hp0 = getHP(),
    }
end

function memEnemyTrialResolve()
    local tr = EnemyTrial
    if not tr then return end
    if (tick() - tr.at) < Config.EnemyTrialWindow then return end
    EnemyTrial = nil

    local took = math.max(0, (tr.hp0 or 0) - getHP())

    local row = MEM.enemyOpens[tr.set]
    if not row then return end






    local expect = 0
    local n = 0
    for _, e in pairs(row) do
        expect = expect + (e.dmg or 0)
        n = n + (e.n or 0)
    end
    expect = expect / math.max(1, n)

    local rec = MEM.enemyTrust[tr.set]
    if not rec then rec = { trust = Config.EnemyStartTrust }; MEM.enemyTrust[tr.set] = rec end

    if took <= expect then
        rec.trust = math.min(Config.EnemyMaxTrust, rec.trust + 1)
    else
        rec.trust = rec.trust - 1
        debug(string.format("%s: avoiding their band cost %.0f vs %.0f expected - trust %d",
            tr.set, took, expect, rec.trust))

        if rec.trust <= 0 then





            debug(tr.set .. ": lesson disproven, discarding and re-learning")
            MEM.enemyOpens[tr.set] = nil
            MEM.enemyCombos[tr.set] = nil
            MEM.enemyTrust[tr.set] = nil
        end
    end
    MemIO.dirty = true
end


function memEnemyTrusted(moveset)
    if not moveset then return false end
    local rec = MEM.enemyTrust[moveset]
    if not rec then return true end
    return (rec.trust or 0) > 0
end






































MAP = {
    cells = {},
    links = {},
    escapes = {},
}








function mapKey(pos)
    if not pos then return nil end
    local gx = math.floor(pos.X / Config.MapCell)
    local gy = math.floor(pos.Y / Config.MapLayer)
    local gz = math.floor(pos.Z / Config.MapCell)
    return gx .. ":" .. gy .. ":" .. gz, gx, gy, gz
end

function mapCenter(cell)
    return Vector3.new(
        (cell.x + 0.5) * Config.MapCell,
        (cell.y + 0.5) * Config.MapLayer,
        (cell.z + 0.5) * Config.MapCell)
end

function mapGet(key, gx, gy, gz)
    local c = MAP.cells[key]
    if not c then
        c = { x = gx, y = gy, z = gz,
              t = 0, dOut = 0, dIn = 0, deaths = 0,
              dens = 0, n = 0, last = 0 }
        MAP.cells[key] = c
    end
    return c
end








function mapDecay(c, now)
    if c.last == 0 then return end
    local gap = now - c.last
    if gap < Config.MapDecayAfter then return end

    local steps = math.min(6, math.floor(gap / Config.MapDecayAfter))
    local f = Config.MapDecayFactor ^ steps
    c.t, c.dOut, c.dIn = c.t * f, c.dOut * f, c.dIn * f
    c.dens, c.n = c.dens * f, c.n * f







end


lastCellKey = nil
cellEnteredAt = nil




function mapOutOfArena(pos)
    local r = Config.MapArenaRadius or 0
    return r > 0 and pos ~= nil and (pos.X * pos.X + pos.Z * pos.Z) > r * r
end




function mapDomainNote(inside)
    Bot.InDomain = inside
    if inside then
        Bot.DomainAt, Bot.DomainDmg0, Bot.DomainTaken0, Bot.DomainStun0 = tick(), Life.dmg or 0, Life.taken or 0, Life.stunned or 0
        local allies, hostiles = 0, 0
        for _, pl in ipairs(Players:GetPlayers()) do
            local pc = pl ~= LocalPlayer and pl.Character
            local ph = pc and getHRP(pc)
            if ph and mapOutOfArena(ph.Position) then
                if isAllyName(pl.Name) then allies = allies + 1 else hostiles = hostiles + 1 end
            end
        end
        debug(string.format("domain: entered at hp %.0f%%, %d allies / %d hostiles inside, target %s",
            getHPPct(), allies, hostiles, tostring(Bot.Target and Bot.Target.Name or "-")))
    else
        local sec = tick() - (Bot.DomainAt or tick())
        Life.domainSec = (Life.domainSec or 0) + sec
        debug(string.format("domain: %.0f s inside, dealt %.0f took %.0f, stunned %.0f s", sec,
            (Life.dmg or 0) - (Bot.DomainDmg0 or 0), (Life.taken or 0) - (Bot.DomainTaken0 or 0),
            (Life.stunned or 0) - (Bot.DomainStun0 or 0)))
    end
end







function mapObserve(pos, dt, hostiles, dmgOut, dmgIn)
    if not Config.MapMemory or not pos then return end




    local out = mapOutOfArena(pos)
    if out ~= (Bot.InDomain == true) then mapDomainNote(out) end
    local pv, pa, tk = Bot.MapPrevPos, Bot.MapPrevAt or 0, tick()
    Bot.MapPrevPos, Bot.MapPrevAt = pos, tk
    if pv and (tk - pa) < (Config.MapTeleportTime or 1) and (pos - pv).Magnitude > (Config.MapTeleportDist or 200) then
        debugEvery("teleport", 2, string.format("teleported %.0f studs in %.2f s%s: cell chain cut, not linked",
            (pos - pv).Magnitude, tk - pa, out and " (out of the arena)" or ""))
        lastCellKey = nil
        if Escape.active then Escape.tele = true end
    end
    if out then lastCellKey = nil; return end

    local key, gx, gy, gz = mapKey(pos)
    if not key then return end

    local now = os.time()
    local c = mapGet(key, gx, gy, gz)
    mapDecay(c, now)

    c.t = c.t + (dt or 0.016)
    c.dOut = c.dOut + (dmgOut or 0)
    c.dIn = c.dIn + (dmgIn or 0)
    c.dens = c.dens + (hostiles or 0)
    c.n = c.n + 1
    c.last = now










    if lastCellKey and lastCellKey ~= key then
        local cost = math.clamp(now - (cellEnteredAt or now), 0.2, 12)

        local function link(a, b, c)
            local row = MAP.links[a]
            if not row then row = {}; MAP.links[a] = row end

            local e = row[b]

            if type(e) == "number" then e = { n = e, t = e * 1.5 } end
            if not e then

















                local deg, victim, vEst, vCost = 0, nil, false, -1
                for k, x in pairs(row) do
                    deg = deg + 1
                    if type(x) == "table" and (x.n or 0) < 2 then
                        local xe = x.est == true
                        local xc = x.t or 0
                        if (xe and not vEst) or (xe == vEst and xc > vCost) then
                            victim, vEst, vCost = k, xe, xc
                        end
                    end
                end
                if deg >= Config.MapMaxDegree and victim then
                    row[victim] = nil
                    if Config.DebugMap then
                        debugEvery("map-evict", 10, string.format(
                            "map: %s edge %s -> %s made room for a walked road",
                            vEst and "estimated" or "once-walked", a, victim))
                    end
                end
                e = { n = 0, t = 0 }
            end

            e.n = (e.n or 0) + 1
            e.t = (e.t or 0) + c



            e.est = nil
            row[b] = e
        end

        link(lastCellKey, key, cost)


        link(key, lastCellKey, cost)
    end

    if lastCellKey ~= key then
        lastCellKey = key
        cellEnteredAt = now
    end

    MapDirty = true
end


function mapRates(c)
    local t = math.max(0.5, c.t or 0)
    return (c.dIn or 0) / t,
           (c.dOut or 0) / t,
           (c.dens or 0) / math.max(1, c.n or 1)
end

function mapClassify(c)
    if not c or (c.t or 0) < Config.MapMinTime then return "NEUTRAL" end

    local heat, yield, dens = mapRates(c)

    if (c.deaths or 0) >= 2 or heat > Config.MapHotRate then return "HOT" end
    if yield > Config.MapRichRate and heat < Config.MapHotRate * 0.6 then return "RICH" end
    if dens < 0.3 and heat < 0.4 and yield < 0.4 then return "DEAD" end
    return "NEUTRAL"
end

function mapHere(pos)
    local key = mapKey(pos)
    return key and MAP.cells[key] or nil, key
end




















local shortcutAt = 0

function mapDiscoverShortcuts(pos)
    if not Config.MapMemory or not pos then return end


    if (Config.MapShortcutTests or 0) <= 0 then return end
    if (tick() - shortcutAt) < Config.MapShortcutEvery then return end
    shortcutAt = tick()

    local hereKey = mapKey(pos)
    if not hereKey then return end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { getChar() }









    local row0 = MAP.links[hereKey]
    local degree, guesses = 0, 0
    if row0 then
        for _, e0 in pairs(row0) do
            degree = degree + 1
            if type(e0) == "table" and e0.est then guesses = guesses + 1 end
        end
    end












    if guesses >= Config.MapMaxLOS or degree >= Config.MapMaxDegree then return end

    local added, tested = 0, 0
    for key, c in pairs(MAP.cells) do
        if tested >= Config.MapShortcutTests then break end
        if guesses + added >= Config.MapMaxLOS or degree + added >= Config.MapMaxDegree then break end
        if key ~= hereKey then
            local row = MAP.links[hereKey]
            if not (row and row[key]) then
                local center = mapCenter(c)
                local delta = center - pos
                local dist = delta.Magnitude

                if dist > Config.MapCell and dist < Config.MapShortcutRange then
                    tested = tested + 1
                    local hit = Workspace:Raycast(pos, delta, params)
                    if not hit then









                        local guess = dist / Config.MapRunSpeed
                        local a = MAP.links[hereKey]
                        if not a then a = {}; MAP.links[hereKey] = a end
                        a[key] = { n = 1, t = guess, est = true }







                        local b = MAP.links[key]
                        if not b then b = {}; MAP.links[key] = b end
                        local far, farGuesses = 0, 0
                        for _, fe in pairs(b) do
                            far = far + 1
                            if type(fe) == "table" and fe.est then farGuesses = farGuesses + 1 end
                        end





                        if farGuesses < Config.MapMaxLOS and far < Config.MapMaxDegree and not b[hereKey] then
                            b[hereKey] = { n = 1, t = guess, est = true }
                        end

                        added = added + 1
                        MapDirty = true
                    end
                end
            end
        end
    end

    if added > 0 and Config.DebugMap then
        debug(string.format("map: found %d shortcuts from %s", added, hereKey))
    end
end

















function mapDirIndex(dir)
    local a = math.atan2(dir.Z, dir.X)
    local n = Config.FrontierRays
    return (math.floor((a + math.pi) / (2 * math.pi) * n) % n) + 1
end

function mapOpenDirections(pos)
    local out = {}
    if not pos then return out end

    local char = getChar()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }

    local n = Config.FrontierRays
    local origin = pos + Vector3.new(0, 1.5, 0)
    local hereKey = mapKey(pos)
    local cell = hereKey and MAP.cells[hereKey]

    for i = 0, n - 1 do
        local ang = (i / n) * math.pi * 2
        local dir = Vector3.new(math.cos(ang), 0.06, math.sin(ang)).Unit
        local hit = Workspace:Raycast(origin, dir * Config.FrontierProbe, params)
        local clear = hit and (hit.Position - origin).Magnitude or Config.FrontierProbe







        local lowHit = Workspace:Raycast(pos + Vector3.new(0, 0.6, 0),
                                         dir * Config.FrontierProbe, params)
        if lowHit then
            local lowClear = (lowHit.Position - pos).Magnitude
            if lowClear < clear then clear = lowClear end
        end







        local idx = mapDirIndex(dir)
        local blocked = cell and cell.blocked and cell.blocked[tostring(idx)] or 0
        local penalty = 1 / (1 + blocked * 1.5)

        table.insert(out, {
            dir = dir,
            clear = clear,
            score = clear * penalty,
            idx = idx,
            blocked = blocked,
        })
    end

    table.sort(out, function(a, b) return a.score > b.score end)
    return out
end


function mapNoteBlocked(pos, dir)
    if not Config.MapMemory or not pos or not dir then return end
    local key, gx, gy, gz = mapKey(pos)
    if not key then return end

    local c = mapGet(key, gx, gy, gz)
    c.blocked = c.blocked or {}
    local k = tostring(mapDirIndex(dir))
    c.blocked[k] = (c.blocked[k] or 0) + 1
    c.last = os.time()
    MapDirty = true

    if Config.DebugMap then
        debug(string.format("map: direction %s from %s blocked (%d)", k, key, c.blocked[k]))
    end
end













function mapFrontier(pos)
    if not pos then return nil end

    local dirs = mapOpenDirections(pos)
    local best, bestScore = nil, 0

    for _, d in ipairs(dirs) do
        if d.clear >= Config.FrontierMinClear then

            local reach = math.max(Config.FrontierMinClear, d.clear - 6)
            local goal = pos + d.dir * reach

            local gk = mapKey(goal)
            local gc = gk and MAP.cells[gk]
            local score = d.score

            if not gc or (gc.t or 0) < Config.MapMinTime then
                score = score * Config.FrontierUnknownBonus
            else
                local heat = select(1, mapRates(gc))
                score = score / (1 + heat)
                if mapClassify(gc) == "HOT" then score = score * 0.4 end
            end

            if score > bestScore then best, bestScore = goal, score end
        end
    end

    return best
end







function mapBestHunt(pos)
    if not Config.MapMemory or not pos then return nil end

    local hereKey = mapKey(pos)
    local best, bestScore = nil, 0
    for key, c in pairs(MAP.cells) do
        if key ~= hereKey and (c.t or 0) >= Config.MapMinTime then
            local center = mapCenter(c)
            local d = (center - pos).Magnitude
            if d > Config.MapCell and d <= Config.MapHuntRange then
                local heat, yield, dens = mapRates(c)
                local class = mapClassify(c)



                local score = (yield + dens * 0.5) / (1 + heat)
                if class == "HOT" then score = score * 0.35 end
                if class == "DEAD" then score = score * 0.15 end
                score = score / (1 + d / Config.MapHuntRange)

                if score > bestScore then best, bestScore = c, score end
            end
        end
    end

    if not best or bestScore < 0.15 then return nil end
    return mapCenter(best), mapClassify(best)
end


Escape = { active = false, fromKey = nil, at = 0, hp0 = 0, fromPos = nil, tele = false }

function mapEscapeStart(pos)
    if not Config.MapMemory then return end
    if Escape.active then return end
    if mapOutOfArena(pos) then return end
    Escape.active = true
    Escape.fromPos, Escape.tele = pos, false
    Escape.fromKey = mapKey(pos)
    Escape.at = tick()
    Escape.hp0 = getHPPct()
end



function mapEscapeEnd(pos, success)
    if not Config.MapMemory or not Escape.active then return end
    Escape.active = false

    local fromKey = Escape.fromKey
    local toKey = mapKey(pos)



    if Escape.tele or mapOutOfArena(pos) then
        debug(string.format("escape %s -> %s: teleported (%.0f studs in %.1f s)", tostring(fromKey), tostring(toKey),
            Escape.fromPos and (pos - Escape.fromPos).Magnitude or 0, tick() - (Escape.at or tick())))
        return
    end
    if not fromKey or not toKey or fromKey == toKey then return end








    if not Config.MapWriteEscapes then
        debug(string.format("escape %s -> %s: %s", fromKey, toKey, success and "clean" or "failed"))
        return
    end

    local row = MAP.escapes[fromKey]
    if not row then row = {}; MAP.escapes[fromKey] = row end

    local rec = row[toKey]
    if not rec then rec = { tries = 0, wins = 0 }; row[toKey] = rec end
    rec.tries = rec.tries + 1
    if success then rec.wins = rec.wins + 1 end















    local dc = MAP.cells[toKey]
    if dc then
        dc.escTries = (dc.escTries or 0) + 1
        if success then dc.escWins = (dc.escWins or 0) + 1 end
    end

    MapDirty = true
    debug(string.format("escape %s -> %s: %s (%d/%d here)",
        fromKey, toKey, success and "clean" or "failed", rec.wins, rec.tries))
end

function mapNoteDeath(pos)
    if not Config.MapMemory or not pos then return end



    if Bot.InDomain then mapDomainNote(false) end
    if mapOutOfArena(pos) then
        if Escape.active then mapEscapeEnd(pos, false) end
        debug(string.format("died out of the arena (cell %s, %.0f studs out): not booked",
            tostring(mapKey(pos)), math.sqrt(pos.X * pos.X + pos.Z * pos.Z)))
        return
    end
    local key, gx, gy, gz = mapKey(pos)
    if not key then return end
    local c = mapGet(key, gx, gy, gz)

    if not memDeathDiscounted() then c.deaths = (c.deaths or 0) + 1 end
    c.last = os.time()
    MapDirty = true


    if Escape.active then mapEscapeEnd(pos, false) end
    debug(string.format("died in cell %s (%d deaths here) -> marked HOT", key, c.deaths))
end



























function mapTrimDegree()
    local trimmed = 0
    for a, row in pairs(MAP.links) do
        local deg, guesses = 0, 0
        for _, e in pairs(row) do
            deg = deg + 1
            if type(e) == "table" and e.est and (e.n or 0) < 2 then guesses = guesses + 1 end
        end

        if deg > Config.MapMaxDegree or guesses > Config.MapMaxLOS then
            local list = {}
            for b, e in pairs(row) do
                local cost = 1.5
                local walked = 1
                if type(e) == "table" and (e.n or 0) > 0 then
                    cost = (e.t or 0) / e.n
                    walked = (e.n >= 2 or not e.est) and 1 or 0
                end
                table.insert(list, { b = b, e = e, cost = cost, m = walked })
            end
            table.sort(list, function(x, y)
                if x.m ~= y.m then return x.m > y.m end
                return x.cost < y.cost
            end)
            local keep, kept, keptGuesses = {}, 0, 0
            for i = 1, #list do
                local it = list[i]
                if kept >= Config.MapMaxDegree then break end
                if it.m == 1 or keptGuesses < Config.MapMaxLOS then
                    keep[it.b] = it.e
                    kept = kept + 1
                    if it.m == 0 then keptGuesses = keptGuesses + 1 end
                end
            end
            MAP.links[a] = keep
            trimmed = trimmed + (#list - kept)
        end
    end
    if trimmed > 0 then
        debug(string.format("map: trimmed %d surplus edges", trimmed))
        MapDirty = true
    end
end








function mapDropEstimates()
    local n = 0
    for a, row in pairs(MAP.links) do
        if type(row) == "table" then
            for b, e in pairs(row) do
                if type(e) == "table" and e.est and (e.n or 0) < 2 then
                    row[b] = nil
                    n = n + 1
                end
            end
            if next(row) == nil then MAP.links[a] = nil end
        end
    end
    return n
end

















function mapPrune()
    if not Config.MapKeepEstimates then
        local est = mapDropEstimates()
        if est > 0 then
            debug(string.format("map: dropped %d line-of-sight estimates (MapKeepEstimates off)", est))
        end
    end
    mapTrimDegree()

    local now = os.time()
    local expire = Config.MapThinExpire or 0
    local minT = Config.MapMinTime or 4
    local drop, thin, n = {}, 0, 0
    for k, c in pairs(MAP.cells) do
        n = n + 1
        if expire > 0 and (c.t or 0) < minT and (c.deaths or 0) == 0
           and not (type(c.blocked) == "table" and next(c.blocked) ~= nil)
           and now - (c.last or 0) > expire then
            drop[k] = true
            thin = thin + 1
        end
    end

    local ranked = math.max(0, n - thin - Config.MapMaxCells)
    if ranked > 0 then
        local decay = Config.MapPruneDecay
        local f, after = Config.MapDecayFactor or 0.6, Config.MapDecayAfter or 900
        local list = {}
        for k, c in pairs(MAP.cells) do
            if not drop[k] then

                local t = c.t or 0
                if decay and (c.last or 0) > 0 then
                    local steps = math.min(6, math.floor(math.max(0, now - c.last) / after))
                    if steps > 0 then t = t * f ^ steps end
                end
                table.insert(list, { k = k, v = t + (c.deaths or 0) * 30, last = c.last or 0 })
            end
        end
        table.sort(list, function(a, b)
            if a.v ~= b.v then return a.v < b.v end
            return a.last < b.last
        end)
        for i = 1, ranked do drop[list[i].k] = true end
    end

    if thin + ranked == 0 then return end
    for k in pairs(drop) do
        MAP.cells[k] = nil
        MAP.links[k] = nil
        MAP.escapes[k] = nil
    end
    for _, row in pairs(MAP.links) do
        for b in pairs(row) do
            if drop[b] then row[b] = nil end
        end
    end
    for _, row in pairs(MAP.escapes) do
        for b in pairs(row) do
            if drop[b] then row[b] = nil end
        end
    end
    debug(string.format("map: pruned %d cells (%d thin and unvisited > %d min, %d by tenure)",
        thin + ranked, thin, math.floor(expire / 60), ranked))
end

function mapStats()
    local counts = { HOT = 0, RICH = 0, DEAD = 0, NEUTRAL = 0 }
    local n, links = 0, 0
    for _, c in pairs(MAP.cells) do
        n = n + 1
        counts[mapClassify(c)] = counts[mapClassify(c)] + 1
    end
    for _, row in pairs(MAP.links) do
        for _ in pairs(row) do links = links + 1 end
    end
    return n, counts, links
end







function mapSnapshot()
    mapPrune()


    if Config.MapSaveThin then
        return { cells = MAP.cells, links = MAP.links,
                 escapes = Config.MapWriteEscapes and MAP.escapes or nil }
    end











    local minT = Config.MapMinTime or 4
    local cells, links, kept, thin, nl = {}, {}, 0, 0, 0
    for k, c in pairs(MAP.cells) do
        if (c.t or 0) >= minT or (c.deaths or 0) > 0
           or (type(c.blocked) == "table" and next(c.blocked) ~= nil) then
            cells[k] = c
            kept = kept + 1
        else
            thin = thin + 1
        end
    end
    for a, row in pairs(MAP.links) do
        if cells[a] then
            local out = nil
            for b, e in pairs(row) do
                if cells[b] then
                    if not out then out = {} end
                    out[b] = e
                    nl = nl + 1
                end
            end
            if out then links[a] = out end
        end
    end
    debugEvery("map-save", 60, string.format("map: saved %d cells / %d links, %d thin cells left out", kept, nl, thin))
    return { cells = cells, links = links,
             escapes = Config.MapWriteEscapes and MAP.escapes or nil }
end

do
    local m = MEM.map
    if type(m) == "table" then
        MAP.cells = type(m.cells) == "table" and m.cells or {}
        MAP.links = type(m.links) == "table" and m.links or {}
        MAP.escapes = type(m.escapes) == "table" and m.escapes or {}










        local legacy = 0
        for _, row in pairs(MAP.links) do
            for _, e in pairs(row) do
                if type(e) == "table" and e.est == nil and (e.n or 0) == 1 then
                    local t = e.t or 0
                    if t ~= 0.2 and t % 1 ~= 0 then e.est = true; legacy = legacy + 1 end
                end
            end
        end

        local estDropped = (not Config.MapKeepEstimates) and mapDropEstimates() or 0
        local n, counts, links = mapStats()
        debug(string.format(
            "map: loaded %d cells (%d hot, %d rich, %d dead) and %d routes",
            n, counts.HOT, counts.RICH, counts.DEAD, links))
        if estDropped > 0 then
            debug(string.format("map: dropped %d line-of-sight estimates (MapKeepEstimates off)", estDropped))
        end
        if legacy > 0 then
            debug(string.format("map: flagged %d legacy line-of-sight estimates (n == 1, fractional cost)", legacy))
        end
    end
end












NavWatch = { pos = nil, at = 0, goal = nil, jumped = false }

function mapNavProgress(pos, goal)
    if not pos then return true end

    local now = tick()


    if goal ~= NavWatch.goal then
        NavWatch.goal = goal
        NavWatch.pos = pos
        NavWatch.at = now
        NavWatch.jumped = false
        return true
    end

    if not goal then return true end

    if not NavWatch.pos then
        NavWatch.pos = pos; NavWatch.at = now
        return true
    end

    local moved = (pos - NavWatch.pos).Magnitude
    if moved >= Config.NavStuckDist then
        NavWatch.pos = pos
        NavWatch.at = now
        NavWatch.jumped = false
        return true
    end

    local stalledFor = now - NavWatch.at
    if stalledFor < Config.NavStuckWindow then return true end


    if not NavWatch.jumped then
        NavWatch.jumped = true
        NavWatch.at = now - Config.NavStuckWindow * 0.5
        local hum = getHum()
        if hum then hum.Jump = true end
        if Config.DebugMap then debug("nav: no progress, jumping") end
        return true
    end

    local dir = goal - pos
    if dir.Magnitude > 0.1 then mapNoteBlocked(pos, dir.Unit) end

    NavWatch.goal = nil
    NavWatch.pos = nil
    NavWatch.jumped = false
    if Config.DebugMap then
        debug(string.format("nav: stuck %.1fs, abandoning goal", stalledFor))
    end
    return false
end






























local BODY = 2.6
local CHEST = 3.0
local KNEE = 0.8

local function rayLen(from, dir, dist, params)
    local hit = Workspace:Raycast(from, dir * dist, params)
    return hit and (hit.Position - from).Magnitude or dist
end







function mapCorridor(pos, dir, dist, params)
    local side = Vector3.new(-dir.Z, 0, dir.X)
    if side.Magnitude < 0.1 then side = Vector3.new(1, 0, 0) end
    side = side.Unit * BODY

    local chest = math.huge
    local knee = math.huge
    for _, off in ipairs({ -1, 0, 1 }) do
        local o = pos + side * off
        chest = math.min(chest, rayLen(o + Vector3.new(0, CHEST, 0), dir, dist, params))
        knee  = math.min(knee,  rayLen(o + Vector3.new(0, KNEE, 0), dir, dist, params))
    end










    local vault = false
    if knee < chest - 2 and knee < dist then
        local top = pos + dir * (knee + BODY) + Vector3.new(0, 6, 0)
        local down = Workspace:Raycast(top, Vector3.new(0, -8, 0), params)
        if down then
            local rise = down.Position.Y - pos.Y


            if rise > 0.5 and rise <= 5.5 then vault = true end
        end
    end

    return (vault and chest or math.min(chest, knee)), vault
end













function mapLookahead(pos, dir, reach, params)
    local ahead = pos + dir * math.max(6, reach * 0.8) + Vector3.new(0, CHEST, 0)
    local total, n = 0, 0
    for i = 0, 4 do
        local a = (i / 5) * math.pi * 2
        local d = Vector3.new(math.cos(a), 0, math.sin(a))
        total = total + rayLen(ahead, d, Config.LookaheadProbe, params)
        n = n + 1
    end
    return total / math.max(1, n)
end










function pickOpenRetreat(pos, threatPos)
    if not pos then return nil, false end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { getChar() }

    local away = threatPos and (pos - threatPos) or nil
    away = (away and away.Magnitude > 0.1) and away.Unit or nil

    local hereKey = mapKey(pos)
    local hereCell = hereKey and MAP.cells[hereKey]



























    local allyDir, allyD, allyHP, allyCrowd = nil, (Config.RetreatAllyRange or 150), 0, 0
    local pull = Config.RetreatAllyPull or 0.6
    Bot.RetreatAlly = nil
    if pull > 0 then
        local minHP = math.max(Config.RetreatAllyMinHP or 55, getHPPct() + 10)
        for _, n in ipairs(Config.Allies or {}) do
            local p = Players:FindFirstChild(n)
            local c = (p and p ~= LocalPlayer) and p.Character or nil
            local ah = (c and isAlive(c)) and getHRP(c) or nil
            if ah then
                local hpp = getHPPct(c)
                local d = getDist2D(pos, ah.Position)
                if hpp > minHP and d > 8 and d < allyD
                   and math.abs(getDistY(pos, ah.Position)) <= (Config.LevelTolerance or 10) then




                    local crowd = 0
                    for _, q in ipairs(Players:GetPlayers()) do
                        local qc = (q ~= LocalPlayer) and q.Character or nil
                        if qc and qc ~= c and isAlive(qc) and not isAllyName(q.Name)
                           and not (q.Team ~= nil and q.Team == LocalPlayer.Team) then
                            local qh = (not isIgnoredName(q.Name)) and getHRP(qc) or nil
                            if qh and (qh.Position - ah.Position).Magnitude < (Config.HostilesNearRange or 35) then
                                crowd = crowd + 1
                            end
                        end
                    end
                    local v = Vector3.new(ah.Position.X - pos.X, 0, ah.Position.Z - pos.Z)
                    if crowd <= (Bot.HostilesNear or 0) and v.Magnitude > 0.1 then
                        allyDir, allyD, allyHP, allyCrowd = v.Unit, d, hpp, crowd
                        Bot.RetreatAlly = n
                    end
                end
            end
        end
    end
    if allyDir then
        debugEvery("retreatally", 3, string.format("retreat: leaning toward %s (%.0f studs, %.0f%% hp, %d hostiles near them)",
            tostring(Bot.RetreatAlly), allyD, allyHP, allyCrowd))
    end






    local rough = {}
    for i = 0, Config.FrontierRays - 1 do
        local a = (i / Config.FrontierRays) * math.pi * 2
        local dir = Vector3.new(math.cos(a), 0, math.sin(a))

        local score = 1
        if away then
            local align = dir:Dot(away)
            if align < -0.35 then score = 0 else score = 0.6 + align end
        end



        if score > 0 and allyDir then
            score = score * (1 + pull * math.max(0, dir:Dot(allyDir)))
        end

        if score > 0 then
            local d = rayLen(pos + Vector3.new(0, CHEST, 0), dir,
                             Config.FrontierProbe, params)
            table.insert(rough, { dir = dir, idx = i, rough = d, bias = score })
        end
    end

    table.sort(rough, function(a, b)
        return a.rough * a.bias > b.rough * b.bias
    end)

    local best, bestScore, bestVault = nil, 0, false
    local tested = 0
    for _, c in ipairs(rough) do
        if tested >= Config.CorridorTests then break end
        tested = tested + 1

        local clear, vault = mapCorridor(pos, c.dir, Config.FrontierProbe, params)
        if clear >= Config.MinEscape then
            local score = clear * c.bias


            score = score * (1 + mapLookahead(pos, c.dir, clear, params)
                                 / Config.LookaheadProbe)


            if hereCell and hereCell.blocked
               and hereCell.blocked[tostring(c.idx)] then
                score = score * 0.2
            end


            local target = pos + c.dir * math.min(clear - 4, 34)
            local tc = MAP.cells[mapKey(target)]
            if tc then
                local cls = mapClassify(tc)
                if cls == "HOT" then score = score * 0.25
                elseif cls == "DEAD" then score = score * 1.4 end
                if hereCell and tc.y ~= hereCell.y then
                    score = score * Config.EscFloorPenalty
                end
            end


            if vault then score = score * 0.8 end

            if score > bestScore then
                best, bestScore, bestVault = target, score, vault
            end
        end
    end

    return best, bestVault
end



























Threat = {}








function threatAttribute(dmgIn, myPos, candidates)
    if not Config.Threat then return end
    if not dmgIn or dmgIn <= 0 or not myPos then return end
    if not candidates or #candidates == 0 then return end

    local weights, total = {}, 0
    for _, c in ipairs(candidates) do
        local h = getHRP(c)
        if h then
            local d = (h.Position - myPos).Magnitude
            if d <= Config.ThreatRange then

                local w = 1 / (d + 6)



                local i = getInfo(c)
                if i then
                    if inOwnMove(c) or i:FindFirstChild("Dash") then
                        w = w * Config.ThreatSkillBias
                    end
                end

                weights[c] = w
                total = total + w
            end
        end
    end






    if total <= 0 then
        for _, c in ipairs(candidates) do
            local h = getHRP(c)
            if h then
                local d = (h.Position - myPos).Magnitude
                if d <= Config.ThreatFallbackRange then
                    local w = 1 / (d + 6)
                    weights[c] = w
                    total = total + w
                end
            end
        end
    end

    if total <= 0 then
        debugEvery("unattributed", 5, string.format(
            "%.0f damage from nobody we can see", dmgIn))
        return
    end





















    local topAny, topAnyW, nextAny, nextAnyW = nil, 0, nil, 0
    for c, w in pairs(weights) do
        if w > topAnyW then
            nextAny, nextAnyW = topAny, topAnyW
            topAny, topAnyW = c, w
        elseif w > nextAnyW then
            nextAny, nextAnyW = c, w
        end
    end
    if topAny and isAllyName(topAny.Name) then
        Life.ffTaken = (Life.ffTaken or 0) + dmgIn
        debugEvery("fftaken", 2, string.format("ff? took %.0f, likeliest source %s (team-mate) %.0f%%; next %s",
            dmgIn, topAny.Name, 100 * topAnyW / total,
            nextAny and string.format("%s (%s) %.0f%%", nextAny.Name,
                isAllyName(nextAny.Name) and "team-mate" or "enemy", 100 * nextAnyW / total) or "none"))


        Bot.LastFFAt = tick()
        return
    end
    for c, w in pairs(weights) do
        if isAllyName(c.Name) then total = total - w; weights[c] = nil end
    end
    if total <= 0 then return end

    local top, topW = nil, 0
    for c, w in pairs(weights) do
        local t = Threat[c]
        if not t then t = { dmg = 0, last = 0 }; Threat[c] = t end
        t.dmg = t.dmg + dmgIn * (w / total)
        t.last = tick()

        if w > topW then top, topW = c, w end
    end

    if top then
        Bot.Aggressor = top
        Bot.AggressorAt = tick()
        Bot.AggressorDmg = (Bot.AggressorDmg or 0) + dmgIn



        if Config.Memory then
            local arec = memFor(top)
            if arec then
                arec.dmgFrom = (arec.dmgFrom or 0) + dmgIn
                MemIO.dirty = true
            end
        end
































        if Bot.BadTargets and Bot.BadTargets[top] then
            local topH = getHRP(top)
            if topH and math.abs(getDistY(myPos, topH.Position)) > (Config.LevelTolerance or 10) then
                debugEvery("stillbad", 5, string.format("%s is hitting us from off our level - still written off", top.Name))
            else
                Bot.BadTargets[top] = nil
                debug(top.Name .. " is hitting us - no longer written off")
            end
        end

        Bot.DmgFrom = Bot.DmgFrom or setmetatable({}, { __mode = "k" })
        Bot.DmgFrom[top] = (Bot.DmgFrom[top] or 0) + dmgIn

        local theirs = Bot.DmgFrom[top]
        if theirs >= Config.NemesisFloor
           and theirs >= (Bot.NemesisDmg or 0) then
            if Bot.Nemesis ~= top then
                debug(string.format("%s is the fight now (%.0f damage to us)",
                    top.Name, theirs))
            end
            Bot.Nemesis = top
            Bot.NemesisDmg = theirs
        end
    end
end






function threatDecay(dt)
    if not Config.Threat then return end
    local f = math.exp(-(dt or 0.016) / Config.ThreatTau)
    for c, t in pairs(Threat) do
        t.dmg = t.dmg * f
        if t.dmg < 0.5 or not c.Parent then Threat[c] = nil end
    end
end


function threatPrimary()
    if not Config.Threat then return nil, 0 end
    local best, bestScore = nil, 0
    for c, t in pairs(Threat) do
        if c.Parent and t.dmg > bestScore then best, bestScore = c, t.dmg end
    end
    if bestScore < Config.ThreatFloor then return nil, bestScore end
    return best, bestScore
end



function threatAttackers()
    if not Config.Threat then return 0 end
    local n = 0
    for c, t in pairs(Threat) do
        if c.Parent and t.dmg >= Config.ThreatFloor then n = n + 1 end
    end
    return n
end

function threatOf(c)
    local t = c and Threat[c]
    return t and t.dmg or 0
end










function threatLosing()
    local out, inc = memLifeRate(), memLifeInRate()
    if inc < Config.ThreatMinRate then return false end
    return inc > out * Config.ThreatLossRatio
end









local function isAirborne()
    local hum = getHum()
    return hum ~= nil and hum.FloorMaterial == Enum.Material.Air
end

local function getMoveVector()
    local hum = getHum()
    return (hum and hum.MoveDirection) or Vector3.zero
end


local function getAimPoint()
    local h = getHRP()
    local t = Bot.Target
    if t then
        local th = getHRP(t)
        if th then return th.Position end
    end
    return h and (h.Position + h.CFrame.LookVector * 40) or Vector3.zero
end

local function buildExtra(moveName)
    local rule = MoveRules[moveName] or DefaultRule
    local code = rule.code or 0

    if code == 1 then return isAirborne() end
    if code == 2 then return Bot.Target end
    if code == 3 then return getAimPoint() end
    if code == 4 then return getMoveVector() end
    if code == 5 then
        return { isAirborne(), Bot.Target, getAimPoint(), getMoveVector() }
    end
    if code == 6 then
        local i = getInfo()
        return { isAirborne(), i ~= nil and i:FindFirstChild("InDash") ~= nil,
                 i ~= nil and i:FindFirstChild("InRoll") ~= nil }
    end
    return false
end
















local m1Thread = nil
local lastM1Log = 0

local function m1Direction()
    local hum = getHum()
    if not hum then return nil end

    local c = getChar()
    local set = c and c:GetAttribute("Moveset")
    local airborne = hum.FloorMaterial == Enum.Material.Air
    local jumping = hum.Jump

    if set == "Hanami" then

        if jumping then return "Up" end
        if airborne then return "Down" end
        return nil
    end

    if airborne then return "Down" end
    if jumping then return "Up" end
    return nil
end



local function fireM1Once(dryRun)
    local c = getChar()
    if not c then return "no-char" end

    local dir = m1Direction()
    local target = Bot.Target


    local crow = rawget(_G, "Crow")
    if crow and typeof(crow) == "Instance" then
        if dryRun then return "crow" end
        local ok = pcall(function() crow:FireServer(true) end)
        if ok then return "crow" end
    end

    local info = getInfo(c)


    local item = info and info:FindFirstChild("Item")
    if item and item:FindFirstChild("M1") then
        if dryRun then return "item" end
        if fireRemote("ItemService", "M1", dir, target) then return "item" end
    end











    if info and info:FindFirstChild("DomainClash") then
        if dryRun then return "domainclash" end
        if fireRemote("DomainService", "Activated", dir) then return "domainclash" end
    end


    if c:FindFirstChild("CustomM1") or c:GetAttribute("CustomM1") then
        if dryRun then return "custom" end
        if fireRemote("CustomService", "Melee", target) then return "custom" end
    end


    local svc = getMovesetService()
    if not svc then return "no-service" end
    if dryRun then

        return svc .. (getRemote and "" or "") ..
               (getService(svc) and " [resolved]" or " [NO SERVICE]")
    end
    if fireRemote(svc, "Activated", dir, target) then return svc end
    return "FAILED:" .. svc
end















local m1Accum = 0
local m1Fires = 0
local m1LastReport = 0

local function startM1()
    Bot.M1Active = true
end

local function stopM1()
    Bot.M1Active = false
end


local function tickM1(dt)
    if not Bot.M1Active or not Config.Enabled then
        m1Accum = 0
        return
    end

    m1Accum = m1Accum + (dt or 0.016)
    if m1Accum < 0.025 then return end
    m1Accum = 0

    local ok, res = pcall(fireM1Once)
    if ok then
        m1Fires = m1Fires + 1
        Bot.LastOffense = tick()
        if Config.DebugM1 and tick() - m1LastReport > 1.0 then
            m1LastReport = tick()
            debug(string.format("M1 %d/s branch=%s dir=%s tgt=%s",
                m1Fires, tostring(res), tostring(m1Direction()),
                tostring(Bot.Target and Bot.Target.Name)))
            m1Fires = 0
        end
    else

        if tick() - m1LastReport > 1.0 then
            m1LastReport = tick()
            debug("M1 ERROR (recovering): " .. tostring(res))
        end
    end
end


local function useSkill(serviceName)
    local moves = getAvailableMoves()
    local m = moves[serviceName]
    if not m then return false end



    if Bot.Refused and (tick() - (Bot.Refused[serviceName] or 0)) < (Config.CastRefusalHold or 2.5) then return false end

    local moveValue = m.value



    if Config.BlankSlotSkip and moveValue.Name == "-" then
        Life.blankSaid = Life.blankSaid or {}
        if not Life.blankSaid[serviceName] then
            Life.blankSaid[serviceName] = true
            debug("slot blank: " .. tostring(serviceName))
        end
        return false
    end
















    if type(allyInBlast) == "function" and allyInBlast(moveValue.Name, serviceName) then
        return false
    end

    stopM1()
    local extra = buildExtra(moveValue.Name)


    fireRemote(serviceName, "Activated", moveValue, extra)


    task.delay(0.1, function()
        fireRemote(serviceName, "Deactivated", moveValue, extra)
    end)

    Bot.LastSkill = tick()
    local offenseBefore = Bot.LastOffense
    Bot.LastOffense = tick()
    local offenseAt = Bot.LastOffense
    Bot.UsedSkillsThisFight[serviceName] = tick()
    Bot.UsedSkillsThisLife = Bot.UsedSkillsThisLife or {}
    Bot.UsedSkillsThisLife[serviceName] = tick()
    local castAt = tick()
    memRecordUse(moveValue.Name, Bot.Target, Bot.Dist2D)







    Bot.Refused = Bot.Refused or {}
    Bot.Refused[serviceName] = castAt - (Config.CastRefusalHold or 2.5) + (Config.CastVerifyDelay or 0.4)







    local before, beforeUse = moveValue:GetAttribute("ReadyAt"), moveValue:GetAttribute("LastUse")
    task.delay(Config.CastVerifyDelay or 0.4, function()
        local ok, after, afterUse = pcall(function()
            return moveValue:GetAttribute("ReadyAt"), moveValue:GetAttribute("LastUse")
        end)
        if not ok then return end
        if after == before and afterUse == beforeUse and not inOwnMove() then


            if after == nil and afterUse == nil then
                Bot.NilStamp = Bot.NilStamp or {}
                Bot.NilStamp[serviceName] = (Bot.NilStamp[serviceName] or 0) + 1
                if Bot.NilStamp[serviceName] > 3 then return end
            end
            Bot.Refused = Bot.Refused or {}
            Bot.Refused[serviceName] = tick()
            Life.refused = (Life.refused or 0) + 1




            local _, rolled = memUnrecordUse(moveValue.Name, castAt)
            if Config.CastRollback and Bot.LastOffense == offenseAt then
                Bot.LastOffense = offenseBefore or 0
                rolled = true
            end
            if rolled then Life.unstamped = (Life.unstamped or 0) + 1 end

            if Bot.UsedSkillsThisLife then Bot.UsedSkillsThisLife[serviceName] = nil end
            Bot.UsedSkillsThisFight[serviceName] = nil
            debugEvery("refused:" .. serviceName, 5, "refused: " .. moveValue.Name .. " (no stamp moved)")
        end
    end)
    debug("Used: " .. moveValue.Name .. " [" .. serviceName .. "]")

    Life.lastUsed, Life.lastUsedAt = moveValue.Name, tick()
    return true
end










local function canChase()
    local i = getInfo()
    if i and i:FindFirstChild("DisableChase") then return false end
    if isStunned() or isRagdolled() then return false end
    return tick() - (Bot.LastChase or 0) > Config.ChaseCooldown
end

local function useChase()
    if not canChase() then return false end
    local svc = getMovesetService()
    if not svc then return false end

    Bot.LastChase = tick()
    local ok = fireRemote(svc, "Chase", isAirborne())
    if ok and Config.DebugDash then
        debug("chase fired (air=" .. tostring(isAirborne()) .. ")")
    end
    return ok
end







local function getSpecialRule()
    local c = getChar()
    local set = c and c:GetAttribute("Moveset")
    return set and SpecialRules[set] or nil, set
end

local function isSpecialReady()
    local c = getChar()
    if not c then return false end











    if tick() - (Bot.LastSpecial or 0) < Config.SpecialCooldown then
        return false
    end

    local cd = c:GetAttribute("M2_CD")
    local last = c:GetAttribute("LastM2")
    if type(cd) == "number" and type(last) == "number" and cd > 0 and last > 0 then
        if Workspace:GetServerTimeNow() < (last + cd) then return false end
    end

    return true
end


local function doParkour()
    local c = getChar()
    local h = getHRP()
    local hu = getHum()
    if not (c and h and hu) then return false end
    return callMC("Parkour", c, h, hu)
end

local function useSpecial()
    local rule, set = getSpecialRule()
    if not rule or rule.kind == "avoid" then return false end




    if rule.kind == "offense" and type(allyInBlast) == "function"
       and FriendlyGeom[senseMoveKey(rule.name)] and allyInBlast(rule.name, nil) then
        return false
    end

    local svc = getMovesetService()
    if not svc then return false end



    Bot.LastSpecial = tick()

    local ok
    if set == "Todo" then
        ok = fireRemote(svc, "RightActivated", Bot.Target)
    elseif set == "Naoya" or set == "Hanami" then
        ok = fireRemote(svc, "RightActivated", getAimPoint(), Bot.Target)
    elseif set == "MeiMei" then
        ok = fireRemote(svc, "RightActivated", getMoveVector())
    else
        ok = fireRemote(svc, "RightActivated", Bot.Target)
    end

    if not ok then return false end


    local holdFor = (rule.kind == "hold") and Config.SpecialHold or 0.12
    task.delay(holdFor, function()
        fireRemote(svc, "RightDeactivated")
    end)




    Bot.LastSkill = tick()
    Bot.LastOffense = tick()
    memRecordUse("SPECIAL:" .. rule.name, Bot.Target, Bot.Dist2D)
    debug("Special: " .. rule.name .. " (" .. rule.kind .. ")")


    Life.lastUsed, Life.lastUsedAt = rule.name, tick()
    return true
end








































function dashVector(dir)
    local h = getHRP()
    if not h then return nil end
    local cf = h.CFrame
    if dir == "Front" then return cf.LookVector end
    if dir == "Back"  then return -cf.LookVector end
    if dir == "Left"  then return -cf.RightVector end
    if dir == "Right" then return cf.RightVector end
    return cf.LookVector
end

function getMovementForce()
    local h = getHRP()
    if not h then return nil end
    local mf = h:FindFirstChild("MovementForce")
    if mf and mf:IsA("BodyVelocity") then return mf end

    for _, d in ipairs(h:GetChildren()) do
        if d:IsA("BodyVelocity") then return d end
    end
    return nil
end

local function dash(dir)



    if tick() - (Bot.LastDash or 0) < Config.DashCooldown then return false end

    local h = getHRP()
    local p0 = h and h.Position
    if not h then return false end

    Bot.LastDash = tick()


    local sent = fireRemote("MovementService", "Dash", dir)


    local vec = dashVector(dir)
    if vec then
        Bot.DashDir = vec
        Bot.DashSpeed = Config.DashSpeed
        Bot.DashUntil = tick() + Config.DashTime
    end

    if Config.DebugDash and p0 then
        task.delay(0.4, function()
            local h2 = getHRP()
            if not h2 then return end
            debug(string.format("dash %s sent=%s moved=%.1f",
                tostring(dir), tostring(sent), (h2.Position - p0).Magnitude))
        end)
    end
    return true
end


function tickDash()
    if not Bot.DashUntil or tick() > Bot.DashUntil then
        Bot.DashDir = nil
        return
    end
    if not Bot.DashDir then return end

    local mf = getMovementForce()
    if not mf then return end


    Bot.DashSpeed = Bot.DashSpeed * Config.DashDecay
    mf.Velocity = Vector3.new(
        Bot.DashDir.X * Bot.DashSpeed,
        mf.Velocity.Y,
        Bot.DashDir.Z * Bot.DashSpeed)
end




function dashDirFor(vec)
    local h = getHRP()
    if not h or not vec then return "Back" end
    local flat = Vector3.new(vec.X, 0, vec.Z)
    if flat.Magnitude < 0.05 then return "Back" end
    flat = flat.Unit
    local cf = h.CFrame
    local best, bestDot = "Back", -math.huge
    local opts = {
        Front = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z),
        Back  = Vector3.new(-cf.LookVector.X, 0, -cf.LookVector.Z),
        Right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z),
        Left  = Vector3.new(-cf.RightVector.X, 0, -cf.RightVector.Z),
    }
    for name, v in pairs(opts) do
        if v.Magnitude > 0.05 then
            local d = v.Unit:Dot(flat)
            if d > bestDot then best, bestDot = name, d end
        end
    end
    return best
end











function tryBurst()
    if not Config.UseBurst then return false end
    local now = tick()
    if now - (Bot.BurstAt or 0) < (Config.BurstCooldown or 2) then return false end
    if not (isStunned() or isRagdolled()) then return false end
    local c, i = getChar(), getInfo()
    if not c or not i then return false end
    if i:FindFirstChild("Wakeup") or i:GetAttribute("Wakeup") then return false end
    local fe = i:FindFirstChild("ForceEsc")
    local can = (i:FindFirstChild("Knockback") ~= nil)
             or (c:GetAttribute("Burst") and not i:GetAttribute("Burst"))
             or (fe ~= nil and fe.Value == true)
    if not can then return false end
    local h = getHRP()
    if not h then return false end
    local from = Bot.Aggressor and getHRP(Bot.Aggressor)
    if not from or (from.Position - h.Position).Magnitude > (Config.BurstRange or 12) then
        from = nil
        local best





        for _, e in ipairs(Bot.HitCandidates or {}) do
            local eh = getHRP(e)
            if eh and not isAllyName(e.Name) then
                local dd = (eh.Position - h.Position).Magnitude
                if dd <= (Config.BurstRange or 12) and (not best or dd < best) then best, from = dd, eh end
            end
        end
    end
    if not from then return false end
    local away = Vector3.new(h.Position.X - from.Position.X, 0, h.Position.Z - from.Position.Z)
    if away.Magnitude < 0.1 then away = Vector3.new(-h.CFrame.LookVector.X, 0, -h.CFrame.LookVector.Z) end
    local dir = dashDirFor(away)
    Bot.BurstAt = now
    Life.bursts = (Life.bursts or 0) + 1



    if (Config.PostBurstRecover or 0) > 0 and (from.Position - h.Position).Magnitude <= (Config.BurstRecoverRange or 8)
       and getHPPct() < (Config.BurstRecoverHP or 70) then
        local u = away.Unit
        local a = math.rad((math.random() * 2 - 1) * (Config.BurstRecoverJitter or 35))
        Bot.RecoverDir = Vector3.new(u.X * math.cos(a) - u.Z * math.sin(a), 0, u.X * math.sin(a) + u.Z * math.cos(a))
        Bot.RecoverMode = (math.random() < (Config.BurstRecoverStep or 0.65)) and "away" or "hold"
        Bot.RecoverUntil = now + (Config.PostBurstRecover or 1.2)
        Bot.RecoverSaid = false
    end
    fireRemote("MovementService", "Dash", dir, true)
    debugEvery("burst", 2, string.format("burst: escape %s (enemy %.0f studs)", dir, (from.Position - h.Position).Magnitude))
    return true
end

function dashWorld(vec)
    local h = getHRP()
    if not h or not vec then return false end
    local flat = Vector3.new(vec.X, 0, vec.Z)
    if flat.Magnitude < 0.05 then return false end
    flat = flat.Unit

    local cf = h.CFrame
    local best, bestDot = "Front", -math.huge
    local opts = {
        Front = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z),
        Back  = Vector3.new(-cf.LookVector.X, 0, -cf.LookVector.Z),
        Right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z),
        Left  = Vector3.new(-cf.RightVector.X, 0, -cf.RightVector.Z),
    }
    for name, v in pairs(opts) do
        if v.Magnitude > 0.05 then
            local d = v.Unit:Dot(flat)
            if d > bestDot then best, bestDot = name, d end
        end
    end
    return dash(best)
end

function dashToward()  dash("Front") end

function dashSideways()
    if math.random() < 0.5 then dash("Left") else dash("Right") end
end














function releaseBlock()
    if not Bot.BlockActive then return end


    if Bot.BlockHeld then
        debugEvery("defendheld", 0.2, string.format("DEFEND held %.1f s, swings %d",
            tick() - (Bot.BlockSince or tick()), Bot.BlockSwings or 0))
    end
    Bot.BlockSwings, Bot.SwingName = 0, nil
    Bot.BlockActive = false
    Bot.BlockHeld = false
    Bot.BlockUntil = 0
    Bot.BlockReleasedAt = tick()
    fireRemote("BlockService", "Deactivated")
end






function guardTarget()
    return (Bot.State == "DEFEND" and Bot.DefendVs) or Bot.Target
end

function doBlock(hold)
    local now = tick()
    local dur = hold or Config.BlockDuration


    if hold and now - (Bot.BlockReleasedAt or 0) < (Config.DefendCapRest or 0.3) then return end
    if Bot.BlockActive then
        if hold then
            local cap = (Bot.BlockSince or now) + (Config.BlockHoldMax or 2.0)
            Bot.BlockUntil = math.min(math.max(Bot.BlockUntil or 0, now + dur), cap)
            Bot.BlockHeld = true
        end
        return
    end
    stopM1()
    Life.blocks = (Life.blocks or 0) + 1
    local vs = guardTarget()
    fireRemote("BlockService", "Activated", vs)
    Bot.BlockTarget = vs
    Bot.BlockActive = true
    Bot.BlockHeld = hold ~= nil
    Bot.BlockSince = now
    Bot.BlockUntil = now + dur
    Bot.LastBlock = now
    task.spawn(function()
        while Bot.BlockActive and tick() < (Bot.BlockUntil or 0) do
            task.wait(0.05)
        end
        if Bot.BlockActive then releaseBlock() end
    end)
end




function doUltimate()
    stopM1()
    local svc = getMovesetService()
    if not svc then return end
    fireRemote(svc, "Ultimate")
    debug("Triggered awakening")
end



DangerByService = {

    AuthenticMutualLove =       "aoe",
    BloodRain =                 "aoe",
    BruteForce =                "aoe",
    Chant =                     "aoe",
    Collapse =                  "aoe",
    CursedBuds =                "aoe",
    Domain =                    "aoe",
    Dreams =                    "aoe",
    EarthenTrance =             "aoe",
    Earthquake =                "aoe",
    EmbodimentofSelfPerfection = "aoe",
    EnergyRipple =              "aoe",
    FlashFreezing =             "aoe",
    FlowerField =               "aoe",
    HeatEmission =              "aoe",
    IdleDeathGamble =           "aoe",
    InfiniteVoid =              "aoe",
    Kamutoke =                  "aoe",
    Littering =                 "aoe",
    MalevolantShrine =          "aoe",
    MalevolentShrine =          "aoe",
    MaxElephant =               "aoe",
    Outburst =                  "aoe",
    Parthenogenesis =           "aoe",
    PianoDrop =                 "aoe",
    RabbitEscape =              "aoe",
    RoachSwarm =                "aoe",
    RootRampage =               "aoe",
    RootSwarm =                 "aoe",
    ShiningSeaofGrowingBranches = "aoe",
    ShortVoid =                 "aoe",
    ShutterDoor =               "aoe",
    TimeCellMoonPalace =        "aoe",
    WidespreadStrikes =         "aoe",

    Appetizer =                 "beam",
    BlackMucus =                "beam",
    Bleedout =                  "beam",
    BudShot =                   "beam",
    CheapShot =                 "beam",
    Cleave =                    "beam",
    CursedSpeech =              "beam",
    Dismantle =                 "beam",
    DroneStrike =               "beam",
    FlameArrow =                "beam",
    GarageSale =                "beam",
    GarudaRebound =             "beam",
    GraniteBlast =              "beam",
    GroundPitch =               "beam",
    GushingWound =              "beam",
    HollowPurple =              "beam",
    Kamehameha =                "beam",
    KiSpam =                    "beam",
    LoveBeam =                  "beam",
    MiracleCannon =             "beam",
    Nue =                       "beam",
    Open =                      "beam",
    OpenFURNACE =               "beam",
    PebbleThrow =               "beam",
    PiercingBlood =             "beam",
    PigeonViola =               "beam",
    PlasmaWave =                "beam",
    RedScale =                  "beam",
    ReserveBall =               "beam",
    ReserveBalls =              "beam",
    ReversalRed =               "beam",
    ReversalRedMAX =            "beam",
    ReversalRedMax =            "beam",
    SkyDistortion =             "beam",
    SlicingExorcism =           "beam",
    SoulFire =                  "beam",
    Soulfire =                  "beam",
    Stinger =                   "beam",
    StrongDismantle =           "beam",
    SurgingThorns =             "beam",
    TechniqueCharge =           "beam",
    TripleSentence =            "beam",
    TrueLoveBeam =              "beam",
    UltraCannon =               "beam",
    WorldSlash =                "beam",

    Adaptation =                "counter",
    Brothers =                  "counter",
    Counter =                   "counter",
    DefenseResponse =           "counter",
    Empower =                   "counter",
    EyeCatching =               "counter",
    HeadSplitter =              "counter",
    Instincts =                 "counter",
    ManjiKick =                 "counter",
    Parry =                     "counter",
    Recovery =                  "counter",
    Revolve =                   "counter",
    SelfPerfection =            "counter",
    Supernova =                 "counter",
    SupernovaCounter =          "counter",
    Wakeup =                    "counter",

    Backstab =                  "grab",
    BlindRage =                 "grab",
    BloodEdge =                 "grab",
    BodyDisfigure =             "grab",
    BoostOn =                   "grab",
    Bounding =                  "grab",
    Chokehold =                 "grab",
    Circling =                  "grab",
    CrushingBlow =              "grab",
    CrushingJaws =              "grab",
    DeadlySentence =            "grab",
    DivinePummel =              "grab",
    Eat =                       "grab",
    FaceBlitz =                 "grab",
    ForceGrab =                 "grab",
    Grapple =                   "grab",
    HeartPiercer =              "grab",
    Homerun =                   "grab",
    IdleTransfiguration =       "grab",
    Ihadnoidea =                "grab",
    Interrogate =               "grab",
    JudgeReach =                "grab",
    JusticeServed =             "grab",
    LuckyRushdown =             "grab",
    PuppetBarrage =             "grab",
    RapidPunches =              "grab",
    RikaDownslam =              "grab",
    RikaGrab =                  "grab",
    RikaSlam =                  "grab",
    ShutUp =                    "grab",
    ShutterDoors =              "grab",
    SnapChomp =                 "grab",
    SpikeWrath =                "grab",
    Stabilize =                 "grab",
    Takedown =                  "grab",
    TendrilGrab =               "grab",
    Trip =                      "grab",
    Verdict =                   "grab",
    WingThrow =                 "grab",

    BirdCall =                  "pull",
    BirdControl =               "pull",
    Convergence =               "pull",
    CrushingRushdown =          "pull",
    Detach =                    "pull",
    DivineDog =                 "pull",
    DivineDogTotality =         "pull",
    ExtendSwing =               "pull",
    Flock =                     "pull",
    GavelThrow =                "pull",
    GrapplePull =               "pull",
    ImpetusUpdraft =            "pull",
    LapseBlue =                 "pull",
    LapseBlueMAX =              "pull",
    LapseBlueMax =              "pull",
    Murmurate =                 "pull",
    Toad =                      "pull",

    AbsoluteDestruction =       "rush",
    Acceleration =              "rush",
    Ambush =                    "rush",
    BluntCut =                  "rush",
    BluntTrauma =               "rush",
    BodyRepel =                 "rush",
    CleaveRush =                "rush",
    CleavingWhirl =             "rush",
    CleavingWhirlwind =         "rush",
    Clever =                    "rush",
    ClimaxJump =                "rush",
    ClimaxJumping =             "rush",
    CursedStrikes =             "rush",
    CursoryImpact =             "rush",
    DecisiveStrike =            "rush",
    Despair =                   "rush",
    DivergentFist =             "rush",
    ElbowBeatdown =             "rush",
    ElbowDrop =                 "rush",
    ElbowRush =                 "rush",
    EnergySurge =               "rush",
    Execution =                 "rush",
    FesteringStrikes =          "rush",
    FeverBreaker =              "rush",
    FinalJudgement =            "rush",
    Fleche =                    "rush",
    Flicker =                   "rush",
    FlowingRedScale =           "rush",
    FocusStrike =               "rush",
    GarudaStab =                "rush",
    GreatSerpent =              "rush",
    LuckyVolley =               "rush",
    MassBreaker =               "rush",
    OverLuck =                  "rush",
    OverwhelmingLuck =          "rush",
    PoleVault =                 "rush",
    PressingCharges =           "rush",
    ProjectionBreaker =         "rush",
    RatioBreaker =              "rush",
    ResoluteSlash =             "rush",
    ResoluteSwing =             "rush",
    RikaLaunch =                "rush",
    RikaThrow =                 "rush",
    RisingRage =                "rush",
    RoughEnergy =               "rush",
    RunSlash =                  "rush",
    Rush =                      "grab",
    Sacrilege =                 "rush",
    Sacrilegious =              "rush",
    SecondHelping =             "rush",
    SecondWind =                "rush",
    SeveranceKick =             "rush",
    SeveringPath =              "rush",
    ShadowSwarm =               "rush",
    Sharpen =                   "rush",
    SpeedCrash =                "rush",
    Stockpile =                 "rush",
    SwiftKick =                 "rush",
    ThinIceBreaker =            "rush",
    Thisiswhatdessertislike =   "rush",
    TopSpeed =                  "rush",
    TwofoldKick =               "rush",
    UltraSpin =                 "rush",
    Unsatisfied =               "rush",
    Veilstep =                  "rush",
    WingKing =                  "rush",
}


Unblockable = {
    Rush = true,
    CleaveRush = true,
    LuckyRushdown = true,
    Despair = true,
    RapidPunches = true,
    TwofoldKick = true,
    LuckyVolley = true,
    WorldSlash = true,
}
















































DangerPlan = {
    grab    = "away",
    pull    = "block",
    beam    = "dodge",
    rush    = "block",
    aoe     = "away",
    counter = "hold",
}











DangerWindow = {
    grab = 0.9, pull = 1.1, beam = 1.0, rush = 1.0, aoe = 2.0, counter = 2.2,
    block = 0,
}












TelegraphPhase = {
    Startup = true, Start = true, Windup = true, Charge = true, Create = true,
    Morph = true, Spin = true, Weave = true, Throw = true, Fire = true,
    Stab = true, Grab = true, Launch = true, Dash = true, Flick = true,
    Crack = true, Red = true, CurseBuild = true, Zwoosh = true, Interp = true,
    Chase = true, Dialog = true, Barrage = true, Summon = true, Empower = true,
}

LandedPhase = {
    Hit = true, Hit1 = true, Hit2 = true, Hit3 = true, FinalHit = true,
    ChaseHit = true, BlackFlashHit = true, Explode = true, Die = true,
    Crush = true, Victim = true, Impact = true,
}














Enemy = setmetatable({}, { __mode = "k" })
SenseHooked = {}
Sensed = { grabbedAt = 0, hitAt = 0, lastHazard = nil }



local function charOf(v)
    if typeof(v) ~= "Instance" then return nil end
    if v:IsA("Player") then return v.Character end
    if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") then return v end
    if v:IsA("BasePart") then
        local p = v.Parent
        if p and p:IsA("Model") and p:FindFirstChild("HumanoidRootPart") then return p end
    end
    return nil
end










local function noteEnemyMove(char, serviceName, effectName)
    if not char or char == getChar() then return end


    local moveKey = string.gsub(serviceName or "", "Service$", "")
    local kind = DangerByService[moveKey] or memAdoptedKind(moveKey)
    if not kind then


        memNoteUnknownMove(moveKey, char)
        return
    end


    local phase = string.match(effectName or "", "^([^%.]+)") or effectName or ""

    if LandedPhase[phase] then

        local e = Enemy[char]
        if e then e.landedAt = tick() end
        return
    end

    if not TelegraphPhase[phase] then return end




















    local prevEntry = Enemy[char]
    local prevMove = nil
    if prevEntry and prevEntry.move and prevEntry.move ~= moveKey
       and (tick() - (prevEntry.at or 0)) < Config.ComboWindow then
        prevMove = prevEntry.move
    end

    Enemy[char] = { move = moveKey, prev = prevMove, kind = kind,
                    at = tick(), phase = phase }

    if Config.DebugSense then
        debug(string.format("sense: %s started %s (%s) [%s]",
            char.Name, moveKey, kind, phase))
    end
end







function senseWatch(char)
    if not Config.Sense or not char then return end

    local function hook(name)
        if not name or SenseHooked[name] then return end
        SenseHooked[name] = true
        local ok, svc = pcall(function() return getService(name) end)
        if not ok or not svc then return end
        local sig = svc.Effects
        if not sig then return end
        pcall(function()
            sig:Connect(function(effectName, a1, a2, a3)
                if type(effectName) ~= "string" then return end
                local who = charOf(a1) or charOf(a2) or charOf(a3)
                noteEnemyMove(who, name, effectName)










                if Config.DebugSense then
                    local base = string.match(effectName, "^([^%.]+)") or effectName
                    local mk = string.gsub(name, "Service$", "")
                    debugEvery("fx:" .. name .. ":" .. base, 30,
                        string.format("fx %s.%s attributed=%s move=%s kind=%s",
                            name, base, tostring(who ~= nil), mk,
                            tostring(DangerByService[mk] or "-")))
                end
            end)
        end)
    end

    local set = char:GetAttribute("Moveset")
    if set then hook(set .. "Service") end

    local ms = char:FindFirstChild("Moveset")
    if ms then
        for _, mv in ipairs(ms:GetChildren()) do
            hook(mv:GetAttribute("Service"))
        end
    end
end






function senseHookCount()
    local n = 0
    for _ in pairs(SenseHooked) do n = n + 1 end
    return n
end

function senseInit()
    if not Config.Sense then return end

    local ok, handi = pcall(function() return getService("HandicapService") end)
    if ok and handi then
        pcall(function()
            handi.Effects:Connect(function(p1, name, p3)
                if name == "Grab" then

                    local me = getHRP()
                    if me and p3 == me then
                        Sensed.grabbedAt = tick()
                        if Config.DebugSense then debug("sense: WE ARE GRABBED") end
                    end
                elseif name == "IFrames" then
                    local c = charOf(p3)
                    if c and c ~= getChar() then
                        Enemy[c] = { move = "IFrames", kind = "counter", at = tick() }
                    end
                end
            end)
        end)
        pcall(function()
            handi.Hit:Connect(function(char)
                if char == getChar() then Sensed.hitAt = tick() end
            end)
        end)
    end


    local okB, blk = pcall(function() return getService("BlockService") end)
    if okB and blk then
        pcall(function()
            blk.Effects:Connect(function(char)
                local c = charOf(char) or char
                if c and c ~= getChar() then
                    local e = Enemy[c] or {}
                    e.blockedAt = tick()





                    Enemy[c] = e
                end
            end)
        end)
    end


    local okM, mov = pcall(function() return getService("MovementService") end)
    if okM and mov then
        pcall(function()
            mov.Effects:Connect(function(...)
                local args = table.pack(...)
                local p1, name = args[1], args[2]
                local c = charOf(p1)
                if c and c ~= getChar() and (name == "Dash" or name == "Grab") then
                    local e = Enemy[c] or {}
                    e.dashedAt = tick()
                    Enemy[c] = e
                end


                local isEsc, ours = false, false
                for k = 1, args.n do
                    local v = args[k]
                    if v == "Escape" then isEsc = true end
                    if v == getChar() or v == LocalPlayer then ours = true end
                end
                if isEsc and ours then Life.escapes = (Life.escapes or 0) + 1 end
            end)
        end)
    end

    debug("sense: status receivers connected")
end


function senseGrabbed()
    return (tick() - (Sensed.grabbedAt or 0)) < Config.GrabEscapeWindow
end


function senseThreatMove(char)





    if char and AnimMapReady then
        local move = senseAnimMove(char)
        if move then
            local kind = DangerByService[move] or memAdoptedKind(move)
            if kind then return move, kind end
        end
    end

    local e = char and Enemy[char]
    if not e or not e.kind then return nil end
    local w = DangerWindow[e.kind] or 1.0
    if (tick() - (e.at or 0)) > w then return nil end
    return e.move, e.kind
end

























SpeedNorm = setmetatable({}, { __mode = "k" })

function senseBlocking(char)
    if not char then return false end


    local e = Enemy[char]
    if e and e.blockedAt and (tick() - e.blockedAt) < Config.BlockSignalWindow then
        return true
    end

    local hum = getHum(char)
    if not hum then return false end

    local ws = hum.WalkSpeed
    if not ws or ws <= 0 then return false end

    local norm = SpeedNorm[char] or 0
    if ws > norm then
        SpeedNorm[char] = ws
        norm = ws
    end


    if norm < Config.BlockSpeedMinNorm then return false end
    if ws > norm * Config.BlockSpeedRatio then return false end


    local info = char:FindFirstChild("Info")
    if info then
        if info:FindFirstChild("InSkill") or info:FindFirstChild("Stun")
           or info:FindFirstChild("Knockback") or info:FindFirstChild("Wakeup") then
            return false
        end
    end
    return true
end





function senseMoveKey(name)
    return (string.gsub(name or "", "[^%w]", ""))
end













local hazardAt = 0
local hazardCache = nil






function senseHazard(pos)
    if not Config.Sense or not pos then return nil end
    if (tick() - hazardAt) < Config.HazardScanEvery then return hazardCache end
    hazardAt = tick()
    hazardCache = nil

    local best, bestUrgency = nil, 0

    local function consider(part)
        if not part:IsA("BasePart") then return end


        local bcf = part:GetAttribute("BeamStartCFrame")
        local blen = part:GetAttribute("BeamLength")
        if bcf and blen then
            local origin = bcf.Position
            local dir = bcf.LookVector
            local width = (part:GetAttribute("Width")
                           or part:GetAttribute("MaxWidth")
                           or part:GetAttribute("TargetWidth") or 8)

            local rel = pos - origin
            local along = rel:Dot(dir)
            if along > -10 and along < blen + 10 then
                local lateral = (rel - dir * along).Magnitude
                if lateral < width * 0.5 + Config.HazardMargin then

                    local side = rel - dir * along
                    local escape = (side.Magnitude > 0.1)
                                   and side.Unit
                                   or dir:Cross(Vector3.new(0, 1, 0)).Unit
                    local urgency = 3 / (1 + lateral)
                    if urgency > bestUrgency then
                        best, bestUrgency = { kind = "beam", dir = escape, dist = lateral }, urgency
                    end
                end
            end
            return
        end


        local speed = part:GetAttribute("Speed")
        local vel = part:GetAttribute("Velocity")
        local move = nil
        if vel and typeof(vel) == "Vector3" and vel.Magnitude > 1 then
            move = vel
        elseif speed and speed > 1 then
            move = part.CFrame.LookVector * speed
        end
        if not move then return end

        local rel = pos - part.Position
        local dist = rel.Magnitude
        if dist > Config.HazardRange then return end

        local mdir = move.Unit
        local closing = -rel.Unit:Dot(mdir)
        if closing < 0.55 then return end

        local tti = dist / move.Magnitude
        if tti > Config.HazardLead then return end


        local along = (-rel):Dot(mdir)
        local miss = ((-rel) - mdir * along).Magnitude
        if miss > Config.HazardMargin + 4 then return end

        local side = mdir:Cross(Vector3.new(0, 1, 0))
        if side.Magnitude < 0.1 then side = Vector3.new(1, 0, 0) end

        local pick = (rel:Dot(side) >= 0) and side.Unit or -side.Unit
        local urgency = 2 / (0.15 + tti)
        if urgency > bestUrgency then
            best, bestUrgency = { kind = "projectile", dir = pick, tti = tti }, urgency
        end
    end

    for _, folder in ipairs({ Workspace:FindFirstChild("Bullets"),
                              Workspace:FindFirstChild("Effects") }) do
        if folder then
            local n = 0
            for _, child in ipairs(folder:GetChildren()) do
                n = n + 1
                if n > Config.HazardMaxScan then break end
                pcall(consider, child)
                if child:IsA("Model") then
                    for _, sub in ipairs(child:GetChildren()) do
                        pcall(consider, sub)
                    end
                end
            end
        end
    end

    hazardCache = best
    return best
end




























function senseHoldingThrowable()
    local info = getInfo()
    if not info then return false end
    local th = info:FindFirstChild("Throwable")
    return th ~= nil and th:IsA("ObjectValue") and th.Value ~= nil
        and not th:GetAttribute("Stored")
end

function senseHoldingTool()
    local info = getInfo()
    return info ~= nil and info:FindFirstChild("Item") ~= nil
end


function senseHoldingItem()
    return senseHoldingThrowable() or senseHoldingTool()
end

function senseThrowable(pos)
    if not Config.Throwables or not pos then return nil end

    local info = getInfo()
    if info and info:FindFirstChild("NoThrowable") then return nil end
    if senseHoldingItem() then return nil end

    local map = Workspace:FindFirstChild("Map")
    local dest = map and map:FindFirstChild("Destructible")
    local folder = dest and dest:FindFirstChild("Throwable")
    if not folder then return nil end










    local best, bestD = nil, Config.ThrowablePickupRange
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m.PrimaryPart
           and not m:GetAttribute("B") and not m:GetAttribute("Hold") then
            local d = (m.PrimaryPart.Position - pos).Magnitude
            if d < bestD then best, bestD = m, d end
        end
    end
    return best, bestD
end







function sensePickUp(model)
    if not model then return false end
    if tick() - (Bot.LastPickupFire or 0) < Config.PickupGap then return false end
    Bot.LastPickupFire = tick()
    return fireRemote("MovementService", "Throwable", model)
end
























function itemHeld()
    local c = getChar()
    if not c then return "no character" end
    local info = c:FindFirstChild("Info")
    if not info then return "no Info" end

    local out = {}
    for _, ch in ipairs(info:GetChildren()) do
        local v = ""
        if ch:IsA("ObjectValue") then
            v = "=" .. tostring(ch.Value and ch.Value.Name or "nil")
        end
        table.insert(out, ch.Name .. v)
    end
    return "Info{" .. table.concat(out, ",") .. "}"
end



function itemScan(radius)
    local h = getHRP()
    if not h then announce("no character"); return {} end

    local map = Workspace:FindFirstChild("Map")
    local dest = map and map:FindFirstChild("Destructible")
    debug("ITEM scan: Map=" .. tostring(map ~= nil) ..
          " Destructible=" .. tostring(dest ~= nil))

    if dest then
        local kids = {}
        for _, ch in ipairs(dest:GetChildren()) do
            table.insert(kids, ch.Name .. "(" .. #ch:GetChildren() .. ")")
        end
        debug("ITEM Destructible children: " .. table.concat(kids, " "))
        announce("Destructible: " .. table.concat(kids, " "))
    end

    local found = {}
    if not dest then return found end

    local n = 0
    for _, ch in ipairs(dest:GetDescendants()) do
        local pos = nil
        if ch:IsA("Model") and ch.PrimaryPart then
            pos = ch.PrimaryPart.Position
        elseif ch:IsA("BasePart") then
            pos = ch.Position
        end





        if pos and ch:IsA("Model") then
            local d = (pos - h.Position).Magnitude
            if d <= (radius or 140) then
                table.insert(found, { inst = ch, dist = d })
                n = n + 1
                if n > 60 then break end
            end
        end
    end

    table.sort(found, function(a, b) return a.dist < b.dist end)
    debug("ITEM found " .. #found .. " objects within " .. (radius or 140))
    for i = 1, math.min(#found, 12) do
        debug(string.format("ITEM   %.0fst %s", found[i].dist,
                            found[i].inst:GetFullName()))
    end
    announce(#found .. " objects near - see log")
    return found
end

ItemPicked = nil

function itemPickup()
    local found = itemScan(60)
    if #found == 0 then announce("nothing nearby"); return end

    ItemPicked = found[1].inst
    debug("ITEM before pickup: " .. itemHeld())
    debug("ITEM pickup: " .. ItemPicked:GetFullName())
    announce("pickup " .. ItemPicked.Name)

    fireRemote("MovementService", "Throwable", ItemPicked)
    task.delay(0.8, function()
        debug("ITEM after pickup: " .. itemHeld())
        announce("held: " .. itemHeld())
    end)
end

local function itemAfter(label)
    task.delay(0.9, function()
        local now = itemHeld()
        debug("ITEM after " .. label .. ": " .. now)

        announce((senseHoldingItem() and "STILL HOLDING after " or "RELEASED by ")
                 .. label)
    end)
end

function itemThrowM1()
    debug("ITEM before M1: " .. itemHeld())
    local h = getHRP()
    fireRemote("ItemService", "M1",
        h and h.CFrame.LookVector or Vector3.new(0, 0, -1), Bot.Target)
    itemAfter("M1")
end

function itemThrowM2()
    debug("ITEM before M2: " .. itemHeld())
    fireRemote("ItemService", "M2")
    itemAfter("M2")
end

function itemRefire()





    local model = senseHeldModel() or ItemPicked
    debug("ITEM before re-fire: " .. itemHeld() ..
          " model=" .. tostring(model and model.Name))
    announce("re-fire on " .. tostring(model and model.Name or "nothing"))
    fireRemote("MovementService", "Throwable", model)
    itemAfter("re-fire")
end

function itemDrop()
    debug("ITEM before drop: " .. itemHeld())
    fireRemote("ItemService", "Drop")
    itemAfter("drop")
end



















ThrowMethods = { "Throwable", "ItemM1", "ItemM2", "ItemDrop" }
ThrowState = { at = 0, idx = 1, tryingSince = 0, tries = 0 }

function senseHeldModel()
    local info = getInfo()
    local th = info and info:FindFirstChild("Throwable")
    if th and th:IsA("ObjectValue") then return th.Value end
    return nil
end

local function throwWith(method, dir, target, model)
    if method == "ItemM1" then
        return fireRemote("ItemService", "M1", dir, target)
    elseif method == "Throwable" then
        return model and fireRemote("MovementService", "Throwable", model)
    elseif method == "ItemM2" then
        return fireRemote("ItemService", "M2")
    elseif method == "ItemDrop" then
        return fireRemote("ItemService", "Drop")
    end
    return false
end








function senseThrowHeld(target)
    if not senseHoldingThrowable() then
        ThrowState.tryingSince = 0
        ThrowState.tries = 0
        return false
    end

    local now = tick()
    if now - ThrowState.at < Config.ThrowRetry then return false end

    local model = senseHeldModel()
    local h = getHRP()
    local dir = h and h.CFrame.LookVector or Vector3.new(0, 0, -1)













    if not MEM.throwMethod then
        MEM.throwMethod = "Throwable"
        MemIO.dirty = true
    end

    local known = MEM.throwMethod
    if known then
        ThrowState.at = now
        ThrowState.tries = (ThrowState.tries or 0) + 1






        if ThrowState.tries > Config.ThrowGiveUp then
            debug("throw: " .. known .. " is not releasing it - searching again")
            MEM.throwMethod = nil
            ThrowState.tries = 0
            ThrowState.tryingSince = 0
        end

        return throwWith(known, dir, target, model)
    end

    if ThrowState.tryingSince == 0 then
        ThrowState.tryingSince = now
        ThrowState.idx = 1
    end

    local method = ThrowMethods[ThrowState.idx]
    ThrowState.at = now
    ThrowState.idx = ThrowState.idx + 1
    if ThrowState.idx > #ThrowMethods then ThrowState.idx = 1 end

    debug("throw: trying " .. method .. " on " ..
          tostring(model and model.Name or "?"))
    throwWith(method, dir, target, model)









    task.delay(Config.ThrowJudge, function()
        if not senseHoldingItem() and not MEM.throwMethod then
            MEM.throwMethod = method
            MemIO.dirty = true
            debug("throw: " .. method .. " works - remembered")
            announce("throw method learned: " .. method)
        end
    end)
    return true
end










function senseNoteIncoming(dmg)
    if not Config.Sense or not dmg or dmg < Config.EnemyMinDamage then return end

    local who, moveset, victimMove, confidence = senseAttacker()









    if confidence ~= "certain" or not moveset then
        MEM.stats.unattributed = (MEM.stats.unattributed or 0) + 1
        return
    end






    local theirMove = senseAnimMove(who)
    local e = Enemy[who]
    local seq = nil
    if theirMove and e and e.move and e.move ~= theirMove then
        seq = e.move .. ">" .. theirMove
    elseif theirMove then
        seq = theirMove
    elseif victimMove then
        seq = victimMove
    end

    local band, angle = nil, nil
    local h, th = getHRP(), getHRP(who)
    if h and th then
        local d = (th.Position - h.Position).Magnitude
        local lo = math.floor(d / 15) * 15
        band = lo .. "-" .. (lo + 14)

        local toThem = th.Position - h.Position
        if toThem.Magnitude > 0.1 then
            angle = (h.CFrame.LookVector:Dot(toThem.Unit) < -0.2) and "behind" or "front"
        end
    end

    memNoteEnemyCombo(moveset, seq, dmg, band, angle)
    MEM.stats.attributed = (MEM.stats.attributed or 0) + 1
end






















AnimMap = {}
AnimMapReady = false

function senseBuildAnimMap()
    if AnimMapReady then return end

    local root = ReplicatedStorage:FindFirstChild("Animations")
    if not root then debug("anim: no ReplicatedStorage.Animations"); return end

    local n = 0
    for _, charFolder in ipairs(root:GetChildren()) do
        for _, inst in ipairs(charFolder:GetDescendants()) do
            if inst:IsA("Animation") and inst.AnimationId ~= "" then
                AnimMap[inst.AnimationId] = { set = charFolder.Name, move = inst.Name }
                n = n + 1
            end
        end
    end

    AnimMapReady = true
    debug(string.format("anim: indexed %d animations across %d characters",
        n, #root:GetChildren()))
end



function senseAnimMove(char)
    if not AnimMapReady or not char then return nil end
    local hum = getHum(char)
    if not hum then return nil end


    local ok, tracks = pcall(playingTracks, hum)
    if not ok or not tracks then return nil end




    local swingMove, swingSet = nil, nil
    for _, tr in ipairs(tracks) do
        local anim = tr.Animation
        local rec = anim and AnimMap[anim.AnimationId]
        if rec then
            if string.match(tostring(rec.move), "^Melee%d") then
                if not swingMove then swingMove, swingSet = rec.move, rec.set end
            else
                return rec.move, rec.set
            end
        end
    end
    return swingMove, swingSet
end


















SwingAnimNames = {
    Chase = true, Up = true, Down = true,
    MeleeChase = true, SwordChase = true,
    Melee3_2 = true,
}





function playingTracks(hum)
    local a = hum:FindFirstChildOfClass("Animator")
    return a and a:GetPlayingAnimationTracks() or hum:GetPlayingAnimationTracks()
end

function senseIsSwingAnim(nm)
    if SwingAnimNames[nm] then







        if nm == "Chase" and not Config.SwingIncludeChase then return false end
        return true
    end

    if string.find(nm, "Victim", 1, true) then return false end
    return string.match(nm, "^Melee%d") ~= nil or string.match(nm, "^Chase%a+") ~= nil
end






function senseMeleeSwing(char)
    if not AnimMapReady or not char then return false end
    local hum = getHum(char)
    if not hum then return false end
    local ok, tracks = pcall(playingTracks, hum)
    if not ok or not tracks then return false end
    for _, tr in ipairs(tracks) do
        local anim = tr.Animation
        local rec = anim and AnimMap[anim.AnimationId]
        if rec then
            local nm = tostring(rec.move)
            if senseIsSwingAnim(nm) then return true, nm end
        end
    end
    return false
end













StunAnimNoise = {
    Nanami2 = true, Nanami = true, Land = true, Idle = true, Roll = true,
    Walk = true, Run = true, Jump = true, Fall = true, Climb = true,
}

function senseStunMove(char)
    if not AnimMapReady or not char then return nil end
    local hum = getHum(char)
    if not hum then return nil end
    local ok, tracks = pcall(playingTracks, hum)
    if not ok or not tracks then return nil end
    local bestMove, bestSet, bestRank = nil, nil, -1
    for _, tr in ipairs(tracks) do
        local anim = tr.Animation
        local rec = anim and AnimMap[anim.AnimationId]
        if rec then
            local nm = tostring(rec.move)
            local rank
            if senseIsSwingAnim(nm) then
                rank = 3
            elseif StunAnimNoise[nm] or nm == tostring(rec.set)
                   or string.find(nm, "Victim", 1, true) or string.match(nm, "^Hit%d") then



                rank = 0
            elseif string.match(nm, "^Dash%a+") or string.match(nm, "^Wakeup") then
                rank = 1
            else
                rank = 2
            end
            if rank > bestRank then bestMove, bestSet, bestRank = nm, rec.set, rank end
        end
    end
    return bestMove, bestSet
end







function senseVictimMove()
    local move, set = senseAnimMove(getChar())
    if not move then return nil end
    if string.find(move, "Victim") or string.find(move, "Hit") then
        return move, set
    end
    return nil
end









function senseAttacker()
    local vMove, vSet = senseVictimMove()
    if vSet then

        local found, count = nil, 0
        for _, c in ipairs(Bot.Nearby or {}) do
            if c:GetAttribute("Moveset") == vSet then
                found = c
                count = count + 1
            end
        end
        if count == 1 then return found, vSet, vMove, "certain" end
        if count > 1 then return nil, vSet, vMove, "ambiguous" end
    end


    if Bot.Aggressor then
        return Bot.Aggressor, Bot.Aggressor:GetAttribute("Moveset"), nil, "guess"
    end
    return nil, nil, nil, "none"
end






















local OWNER_FIELDS = { "Owner", "User", "Friend", "Master", "Summoner" }










local SUMMON_PATTERNS = {
    "Roach", "Insect", "Bug", "Worm", "Locust",
    "Divine", "Dog", "Nue", "Toad", "Elephant",
    "Serpent", "Rabbit", "Shadow", "Mahoraga",
    "Rika", "Copy",
    "Bird", "Crow", "Pigeon",
    "Puppet", "Drone",
    "Clone", "Frame", "NPC",
    "Brother", "Idol",
    "Root", "Branch", "Flower", "Bud",
    "Egg", "Swarm", "Hand",
}








local soloAnnounced = false
local function soloServer()
    local alone = #Players:GetPlayers() <= 1
    if alone and not soloAnnounced then
        soloAnnounced = true
        pcall(announce, "solo server: targeting dummies/NPCs too")
    elseif not alone then
        soloAnnounced = false
    end
    return alone
end

local function isLikelySummon(c)
    local n = c.Name
    for _, pat in ipairs(SUMMON_PATTERNS) do
        if n:find(pat) then return true end
    end

    if not Players:GetPlayerFromCharacter(c) and not c:GetAttribute("Moveset") then
        return true
    end
    return false
end

local function resolveOwner(c)
    for _, field in ipairs(OWNER_FIELDS) do
        local ov = c:FindFirstChild(field)
        if ov and ov:IsA("ObjectValue") and ov.Value then return ov.Value end
        local attr = c:GetAttribute(field)
        if typeof(attr) == "Instance" then return attr end
    end
    local info = c:FindFirstChild("Info")
    if info then
        for _, field in ipairs(OWNER_FIELDS) do
            local ov = info:FindFirstChild(field)
            if ov and ov:IsA("ObjectValue") and ov.Value then return ov.Value end
        end
    end
    return nil
end

local function isOwnedByUs(c)
    local me = getChar()
    if not me then return false end

    local owner = resolveOwner(c)
    if owner then
        if owner == me then return true end
        if owner == LocalPlayer then return true end

        if owner:IsA("Model") and Players:GetPlayerFromCharacter(owner) == LocalPlayer then
            return true
        end
    end
    return false
end

local function isOurClone(c)
    local me = getChar()
    if not me then return false end


    if c.Name == "FrameNPC" then return true end
    local info = c:FindFirstChild("Info")
    if info and info:FindFirstChild("FrameNPC") then return true end



    local myset = me:GetAttribute("Moveset")
    if myset and c:GetAttribute("Moveset") == myset then
        if c:FindFirstChild("MoveReveal", true) then return true end
        for _, d in ipairs(c:GetChildren()) do
            if d.Name == "MoveReveal" then return true end
        end
    end

    return false
end










local AllySet = {}
for _, n in ipairs(Config.Allies or {}) do
    if type(n) == "string" then AllySet[n:lower()] = true end
end

local function isAlly(name)
    if not name then return false end
    return AllySet[tostring(name):lower()] == true
end

function isAllyName(name) return isAlly(name) end



function allyReachable(myH, ah, maxDist)
    if not (myH and ah) then return false end
    if math.abs(getDistY(myH.Position, ah.Position)) > ((Config.LevelTolerance or 10) + (Config.LevelBand or 4)) then
        return false
    end
    return getDist2D(myH.Position, ah.Position) <= maxDist
end



local IgnoreSet = {}
for _, n in ipairs(Config.IgnorePlayers or {}) do
    if type(n) == "string" then IgnoreSet[n:lower()] = true end
end
local function isIgnoredPlayer(name)
    if not name then return false end
    return IgnoreSet[tostring(name):lower()] == true
end

function isIgnoredName(name) return isIgnoredPlayer(name) end



local function allyChars()
    local out = {}
    local h = getHRP()
    local myPos = h and h.Position
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and isAlly(pl.Name) and pl.Character and isAlive(pl.Character) then
            local ah = getHRP(pl.Character)
            if ah then
                table.insert(out, {
                    player = pl, char = pl.Character, hrp = ah,
                    hp = getHPPct(pl.Character),
                    dist = myPos and getDist(myPos, ah.Position) or 9999,
                })
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end




























FriendlyGeom = {

    GraniteBlast   = { s = "lane", w = 12, len = 80, pierce = true, cast = 0.9 },
    Appetizer      = { s = "lane", w = 12, len = 70, pierce = true, cast = 0.4 },
    SecondHelping  = { s = "impact", r = 10, w = 6, cast = 0.6 },
    Youwerentinvited = { s = "lane", w = 10, len = 60, cast = 1.0 },
    WerentInvited  = { s = "lane", w = 10, len = 60, cast = 1.0 },

    BudShot        = { s = "lane", w = 6, len = 70, cast = 0.4 },
    RootSwarm      = { s = "lane", w = 10, len = 50, cast = 0.6 },
    SurgingThorns  = { s = "ring", r = 8, cast = 0.5 },
    FlowerField    = { s = "impact", r = 16, w = 8, cast = 1.0 },
    FlowerBeam     = { s = "lane", w = 14, len = 90, pierce = true, cast = 1.2 },
    RootRampage    = { s = "lane", w = 16, len = 45, cast = 1.0 },
    ShiningSeaofGrowingBranches = { s = "ring", r = 30, cast = 1.5 },
    CursedBuds     = { s = "impact", r = 8, cast = 0.6 },

    BirdControl    = { s = "lane", w = 6, len = 70, cast = 0.5 },
    Murmurate      = { s = "lane", w = 8, len = 60, cast = 0.6 },
    Circling       = { s = "impact", r = 10, cast = 0.8 },
    ImpetusUpdraft = { s = "impact", r = 8, cast = 0.4 },
    Flock          = { s = "impact", r = 8, w = 6, cast = 0.5 },

    BlackMucus     = { s = "lane", w = 6, len = 60, cast = 0.4 },
    RoachSwarm     = { s = "impact", r = 10, w = 6, cast = 0.6 },
    Detach         = { s = "lane", w = 5, len = 40, cast = 0.4 },
    EarthenTrance  = { s = "ring", r = 10, cast = 0.8 },
    Parthenogenesis = { s = "ring", r = 10, cast = 0.8 },

    UltraCannon    = { s = "lane", w = 8, len = 60, cast = 0.6 },
    MiracleCannon  = { s = "lane", w = 10, len = 80, pierce = true, cast = 1.0 },
    HeatEmission   = { s = "ring", r = 10, cast = 0.8 },
    UltraSpin      = { s = "impact", r = 8, w = 6, cast = 0.4 },
    BoostOn        = { s = "lane", w = 6, len = 30, cast = 0.3 },
    AbsoluteDestruction = { s = "ring", r = 20, cast = 1.0 },

    JudgementsReach = { s = "lane", w = 6, len = 40, cast = 0.4 },
    Verdict        = { s = "lane", w = 8, len = 60, cast = 0.6 },
    ExtendedSwings = { s = "ring", r = 8, cast = 0.4 },
    PressingCharges = { s = "lane", w = 6, len = 30, cast = 0.3 },
    FinalJudgement = { s = "lane", w = 8, len = 40, cast = 0.8 },

    LapseBlue      = { s = "impact", r = 14, cast = 0.6 },
    LapseBlueMAX   = { s = "impact", r = 18, cast = 1.0 },
    ReversalRed    = { s = "impact", r = 12, w = 8, cast = 0.6 },
    ReversalRedMAX = { s = "impact", r = 14, w = 10, cast = 1.0 },
    HollowPurple   = { s = "lane", w = 16, len = 90, pierce = true, cast = 1.2 },
    InfiniteVoid   = { s = "ring", r = 30, cast = 1.5 },
    ShortVoid      = { s = "ring", r = 16, cast = 1.0 },

    RikaSmash      = { s = "impact", r = 8, cast = 0.5 },
    RikaLaunch     = { s = "lane", w = 6, len = 28, cast = 0.3 },
    CursedSpeech   = { s = "lane", w = 14, len = 30, cast = 0.5 },
    LoveBeam       = { s = "lane", w = 30, len = 90, pierce = true, cast = 1.5 },
    RikaLoveBeam   = { s = "lane", w = 30, len = 90, pierce = true, cast = 1.5 },
    Outburst       = { s = "ring", r = 10, cast = 0.6 },
    EnergyRipple   = { s = "ring", r = 14, cast = 0.8 },
    SeveringPath   = { s = "lane", w = 8, len = 30, cast = 0.4 },
    AuthenticMutualLove = { s = "ring", r = 30, cast = 1.5 },

    PebbleThrow    = { s = "lane", w = 5, len = 50, cast = 0.4 },
    BruteForce     = { s = "ring", r = 8, cast = 0.5 },
    ClimaxJumping  = { s = "impact", r = 10, cast = 0.6 },
    IdolsDebut     = { s = "lane", w = 6, len = 28, cast = 0.3 },
    ElbowDrop      = { s = "impact", r = 6, cast = 0.4 },
    Dreams         = { s = "ring", r = 14, cast = 1.0 },

    SoulFire       = { s = "lane", w = 6, len = 60, cast = 0.5 },
    Soulfire       = { s = "lane", w = 6, len = 60, cast = 0.5 },
    BodyRepel      = { s = "lane", w = 6, len = 30, cast = 0.4 },
    WidespreadStrikes = { s = "ring", r = 10, cast = 0.5 },
    CrushingRushdown = { s = "lane", w = 6, len = 30, cast = 0.3 },
    EmbodimentofSelfPerfection = { s = "ring", r = 30, cast = 1.5 },

    PiercingBlood  = { s = "lane", w = 6, len = 60, pierce = true, cast = 0.6 },
    PlasmaWave     = { s = "lane", w = 14, len = 120, pierce = true, cast = 1.2 },
    BloodRain      = { s = "impact", r = 15, cast = 1.0 },
    FlowingRedScale = { s = "lane", w = 6, len = 30, cast = 0.3 },
    SlicingExorcism = { s = "lane", w = 8, len = 30, cast = 0.4 },
    WingKing       = { s = "lane", w = 6, len = 30, cast = 0.3 },
    Supernova      = { s = "ring", r = 10, cast = 0.5 },

    Nue            = { s = "impact", r = 8, w = 6, cast = 0.6 },
    Toad           = { s = "impact", r = 8, cast = 0.5 },
    MaxElephant    = { s = "impact", r = 16, cast = 1.0 },
    RabbitEscape   = { s = "ring", r = 10, cast = 0.5 },
    ShadowSwarm    = { s = "ring", r = 10, cast = 0.6 },

    Kamehameha     = { s = "lane", w = 14, len = 90, pierce = true, cast = 1.2 },
    KiSpam         = { s = "lane", w = 8, len = 70, cast = 0.6 },
    StaffExtend    = { s = "lane", w = 6, len = 40, cast = 0.4 },

    Dismantle      = { s = "lane", w = 8, len = 40, cast = 0.5 },
    Cleave         = { s = "lane", w = 8, len = 30, cast = 0.4 },
    FlameArrow     = { s = "lane", w = 8, len = 80, cast = 1.0 },
    MalevolentShrine = { s = "ring", r = 30, cast = 1.5 },
    MalevolantShrine = { s = "ring", r = 30, cast = 1.5 },
    Rush           = { s = "lane", w = 6, len = 28, cast = 0.3 },
    StrongDismantle = { s = "lane", w = 10, len = 40, cast = 0.5 },
    CleaveRush     = { s = "lane", w = 8, len = 30, cast = 0.4 },
    Kamutoke       = { s = "impact", r = 12, cast = 0.6 },
    OpenFURNACE    = { s = "lane", w = 12, len = 60, pierce = true, cast = 1.0 },

    ShutterDoors   = { s = "impact", r = 10, cast = 0.5 },
    LuckyVolley    = { s = "lane", w = 6, len = 30, cast = 0.4 },
    FeverBreaker   = { s = "lane", w = 6, len = 28, cast = 0.3 },
    OverwhelmingLuck = { s = "ring", r = 12, cast = 0.8 },
    IdleDeathGamble = { s = "ring", r = 30, cast = 1.5 },

    Collapse       = { s = "impact", r = 15, cast = 1.0 },
    Bleedout       = { s = "lane", w = 8, len = 40, cast = 0.5 },
    FlashFreezing  = { s = "ring", r = 14, cast = 0.8 },
    TendrilGrab    = { s = "lane", w = 6, len = 30, cast = 0.4 },
    DecisiveStrike = { s = "lane", w = 6, len = 28, cast = 0.3 },
    TimeCellMoonPalace = { s = "ring", r = 30, cast = 1.5 },
    CheapShot      = { s = "lane", w = 6, len = 60, cast = 0.5 },
    Ambush         = { s = "lane", w = 6, len = 25, cast = 0.3 },
    DirtyPlay      = { s = "ring", r = 14, cast = 0.8 },
    GarudaRebound  = { s = "lane", w = 6, len = 40, cast = 0.4 },
    GarudaStab     = { s = "lane", w = 6, len = 12, cast = 0.3 },
    MassBreaker    = { s = "impact", r = 12, cast = 0.8 },
    RisingStar     = { s = "impact", r = 10, cast = 0.6 },
    SkyDistortion  = { s = "lane", w = 6, len = 30, cast = 0.4 },
    ThinIceBreaker = { s = "impact", r = 12, cast = 0.8 },
    GarageSale     = { s = "impact", r = 12, w = 6, cast = 0.8 },
    PianoDrop      = { s = "impact", r = 12, cast = 0.8 },
    Littering      = { s = "ring", r = 10, cast = 0.6 },
    Fleche         = { s = "lane", w = 6, len = 25, cast = 0.3 },
    Sacrilege      = { s = "lane", w = 6, len = 25, cast = 0.3 },
    ShutUp         = { s = "lane", w = 6, len = 15, cast = 0.3 },
    Domain         = { s = "ring", r = 30, cast = 1.5 },
}



FFCanon = {
    Soulfire = "SoulFire", MalevolantShrine = "MalevolentShrine",
    RikaLoveBeam = "LoveBeam", Youwerentinvited = "WerentInvited",
    ReversalRedMax = "ReversalRedMAX", LapseBlueMax = "LapseBlueMAX",
}


FFAnimAlias = {
    RedScale = "FlowingRedScale", RedScaleAir = "FlowingRedScale",
    JudgeReach = "JudgementsReach", JudgeReach2 = "JudgementsReach",
    OverLuck = "OverwhelmingLuck", ExtendSwing = "ExtendedSwings",
    ClimaxJump = "ClimaxJumping", IdolDebut = "IdolsDebut",
    Sacrilegious = "Sacrilege", YutaBeam = "LoveBeam",
    NotInvited = "WerentInvited",
    SlaughterDemon = "MalevolentShrine", MoonPalace = "TimeCellMoonPalace",
    DrillSplit = "CrushingRushdown",
}









function ffShapeFor(moveName, svcKey)
    local rule = (moveName and MoveRules[moveName]) or DefaultRule or {}
    local key = svcKey or senseMoveKey(moveName)
    local g = FriendlyGeom[key] or (moveName and FriendlyGeom[senseMoveKey(moveName)]) or nil
    if g then return g, rule, key end
    if rule.selfBuff or rule.summon or rule.escape then return nil, rule, key end
    local kind = DangerByService[key]

    if kind == "grab" or kind == "counter" then return nil, rule, key end
    local reach = rule.max or 0
    local _, learnedMax = memLearnedRange(moveName)
    if learnedMax and learnedMax < 200 and learnedMax > reach then reach = learnedMax end




    if not moveName and kind ~= "beam" and kind ~= "aoe" and kind ~= "rush" and kind ~= "pull" then
        return nil, rule, key
    end

    if kind ~= "beam" and kind ~= "aoe" and reach <= (Config.M1Range or 7) + 5 then return nil, rule, key end
    if kind == "beam" then return { s = "lane", w = 8, len = math.max(reach, 60), cast = 0.6 }, rule, key end
    if kind == "aoe" then return { s = "impact", r = Config.TeamBlastAoEWidth or 11, cast = 0.8, guess = true }, rule, key end
    if kind == "rush" then return { s = "lane", w = 6, len = math.max(math.min(reach, 40), 12), cast = 0.3 }, rule, key end
    if kind == "pull" then return { s = "impact", r = 8, cast = 0.5, guess = true }, rule, key end
    if reach <= 0 then return nil, rule, key end
    return { s = "lane", w = Config.TeamBlastWidth or 6, len = reach + (Config.TeamBlastMargin or 4), cast = 0.3 }, rule, key
end














function allyInBlast(moveName, serviceName)
    if not Config.TeamAvoidFriendlyFire then return false end
    local svcKey = serviceName and (string.gsub(serviceName, "Service$", "")) or nil
    local g, rule = ffShapeFor(moveName, svcKey)
    if not g or g.s == "none" then return false end


    local ask = Bot.FFAskAt or {}
    Bot.FFAskAt = ask
    local askKey = moveName or svcKey or "?"
    if tick() - (ask[askKey] or 0) > 0.5 then
        ask[askKey] = tick()
        Life.attemptN = (Life.attemptN or 0) + 1
    end

    local h = getHRP()
    if not h then return false end
    local myPos = h.Position
    local th = Bot.Target and getHRP(Bot.Target)
    local aim = th and th.Position or nil


    local look = Vector3.new(h.CFrame.LookVector.X, 0, h.CFrame.LookVector.Z)
    local axis = aim and Vector3.new(aim.X - myPos.X, 0, aim.Z - myPos.Z) or look
    if axis.Magnitude < 0.5 then axis = look end
    if axis.Magnitude < 0.05 then return false end
    axis = axis.Unit
    local up = Vector3.new(0, 1, 0)
    local body = Config.AllyBodyRadius or 2
    local cast = Config.FFPredict and (g.cast or 0.5) or 0
    local tgtDist = aim and (Vector3.new(aim.X - myPos.X, 0, aim.Z - myPos.Z)).Magnitude or nil





    local melee = tgtDist ~= nil and tgtDist <= (Config.M1Range or 7) + 2
    local bigR = Config.FFMeleeBigRadius or 12

    for _, a in ipairs(allyChars()) do
        local ap = a.hrp.Position
        local av = a.hrp.AssemblyLinearVelocity
        local onTgt = aim ~= nil and (Vector3.new(ap.X - aim.X, 0, ap.Z - aim.Z)).Magnitude <= (Config.M1Range or 7) + 2
        local shared = melee and onTgt
        local spots = { ap }
        if cast > 0 and av and av.Magnitude > 2 then
            spots[2] = ap + Vector3.new(av.X, 0, av.Z) * cast
        end
        for si, p in ipairs(spots) do
            local why = nil
            local rel = p - myPos
            local flat = Vector3.new(rel.X, 0, rel.Z)
            local dy = math.abs(rel.Y)
            if g.s == "ring" then
                local dd = flat.Magnitude
                if not (shared and not g.guess and (g.r or 12) < bigR) and dd <= (g.r or 12) + body and dy <= 8 then
                    why = string.format("%.0f studs away, inside the %d-stud ring", dd, g.r or 12)
                end
            else
                local along = flat:Dot(axis)
                local sidev = flat - axis * along
                local perp = sidev.Magnitude
                if g.s == "impact" then
                    local centre = aim or (myPos + axis * math.min(rule.max or 20, 40))
                    local dc = (Vector3.new(p.X - centre.X, 0, p.Z - centre.Z)).Magnitude
                    if not (shared and not g.guess and (g.r or 11) < bigR) and dc <= (g.r or 11) + body and dy <= 8 then
                        why = string.format("%.0f studs from the impact (radius %d)", dc, g.r or 11)
                    end
                end
                if not why and g.w then
                    local len = g.len or (rule.max or 0)


                    if tgtDist and not g.pierce then
                        len = math.min(len, tgtDist + (Config.TeamBlastMargin or 4))
                    end
                    local halfW = g.w * 0.5 + ((shared and not g.pierce) and 0 or body)
                    if along > -1 and along <= len and perp <= halfW and dy <= 8 then
                        why = string.format("%.0f studs out, %.1f off the line", along, perp)
                    end
                end
                if why then
                    local sideSign = sidev:Dot(axis:Cross(up))
                    Bot.LaneHold = { at = tick(), ally = a.player.Name, move = moveName,
                                     side = (sideSign >= 0) and 1 or -1, axis = axis }
                end
            end



            if why and Config.HoldBudget and (si == 2 or g.s == "ring")
               and (Life.attemptN or 0) >= (Config.HoldBudgetMin or 12)
               and (Life.holdN or 0) >= (Life.attemptN or 0) * ((Config.HoldBudgetPct or 35) / 100) then
                Life.holdFreed = (Life.holdFreed or 0) + 1
                debugEvery("holdbudget", 4, string.format("hold budget spent (%d/%d held): %s fires, %s is only %s",
                    Life.holdN or 0, Life.attemptN or 0, tostring(moveName), a.player.Name,
                    (si == 2) and "heading into it" or "in the ring"))
                why = nil
            end
            if why then


                local held = Bot.FFHeldAt or {}
                Bot.FFHeldAt = held
                if tick() - (held[moveName] or 0) > 0.5 then
                    held[moveName] = tick()
                    Life.ffHolds = (Life.ffHolds or 0) + 1
                    Life.holdN = (Life.holdN or 0) + 1




                    if Config.HoldSidestep and g.s == "lane" and si == 1 and Bot.LaneHold then
                        local ls = Bot.LaneHeld
                        if ls and ls.move == moveName and ls.ally == a.player.Name
                           and tick() - (ls.at or 0) <= (Config.HoldSidestepWindow or 3) then
                            Bot.SidestepReq = { at = tick(), ally = a.player.Name, move = moveName,
                                                side = Bot.LaneHold.side, axis = Bot.LaneHold.axis }
                            Bot.LaneHeld = nil
                        else
                            Bot.LaneHeld = { at = tick(), move = moveName, ally = a.player.Name }
                        end
                    end
                end
                debugEvery("ff:" .. tostring(moveName), 4, string.format("holding %s - %s is in the way: %s%s",
                    tostring(moveName), a.player.Name, why, (si == 2) and " (where they are heading)" or ""))
                return true
            end
        end
    end
    return false
end


















function senseAllyLane(pos)
    if not Config.TeamAvoidFriendlyFire or not pos then return nil end
    local now = tick()
    if now - (Bot.AllyLaneAt or 0) < (Config.HazardScanEvery or 0.07) then return Bot.AllyLane end
    Bot.AllyLaneAt = now
    local best, bestUrg = nil, 0
    local margin = Config.AllyLaneMargin or 3
    local body = Config.AllyBodyRadius or 2
    local hyst = Config.AllyLaneHyst or 3
    local up = Vector3.new(0, 1, 0)
    local myTgt = Bot.Target and Bot.Target.Name or nil
    local th = Bot.Target and getHRP(Bot.Target)
    local inMelee = th ~= nil and (getDist2D(pos, th.Position) or 99) <= (Config.M1Range or 7) + 2
    local seen = Bot.AllyCastSeen or {}
    Bot.AllyCastSeen = seen
    local latches = Bot.AllyLaneLatch or {}
    Bot.AllyLaneLatch = latches
    local present = {}
    for _, a in ipairs(allyChars()) do
        local name = a.player.Name
        present[name] = true
        if a.dist <= (Config.AllyLaneRange or 90) then
            local key = nil
            local e = Enemy[a.char]
            local mv = senseAnimMove(a.char)
            if mv then
                mv = FFAnimAlias[mv] or mv
                if FriendlyGeom[mv] or DangerByService[mv] then key = mv end
            end
            if not key then
                local k = e and e.kind or ""


                if e and e.move and (FriendlyGeom[e.move] or k == "beam" or k == "aoe" or k == "rush" or k == "pull")
                   and (now - (e.at or 0)) <= (DangerWindow[k] or 1.0) then
                    key = e.move
                end
            end
            if key then key = FFCanon[key] or key end
            local g = key and ffShapeFor(nil, key) or nil










            if g then
                local rec = seen[name]
                if not rec or rec.key ~= key then
                    rec = { key = key, since = now }
                    seen[name] = rec
                end
                if e and (e.at or 0) > rec.since + 0.25 and (now - e.at) < 0.5 then rec.since = e.at end
                if now - rec.since > (g.cast or 0.5) + 1.0 then g = nil end
            else
                seen[name] = nil
            end

            if not g then latches[name] = nil end
            if g and g.s ~= "none" then
                local ah = a.hrp
                local origin = ah.Position
                local tname = teamAllyTarget(name)
                local tp = tname and Players:FindFirstChild(tname)
                local tc = tp and tp.Character
                local tth = tc and getHRP(tc)
                local aimP = tth and tth.Position or nil
                local axis = aimP and Vector3.new(aimP.X - origin.X, 0, aimP.Z - origin.Z) or nil
                if not axis or axis.Magnitude < 0.5 then
                    axis = Vector3.new(ah.CFrame.LookVector.X, 0, ah.CFrame.LookVector.Z)
                end
                if axis.Magnitude > 0.05 then
                    axis = axis.Unit
                    local latch = latches[name]
                    if latch and latch.move ~= key then latch = nil; latches[name] = nil end






                    local m = latch and latch.m
                             or ((inMelee and tname ~= nil and tname == myTgt) and 0 or margin)
                    local rel = pos - origin
                    local flat = Vector3.new(rel.X, 0, rel.Z)
                    local along = flat:Dot(axis)
                    local sidev = flat - axis * along
                    local perp = sidev.Magnitude
                    local dist, thr, dir = nil, nil, nil
                    if math.abs(rel.Y) <= 8 then
                        if g.s == "ring" then
                            local dd = flat.Magnitude
                            dist, thr = dd, (g.r or 12) + body + m
                            dir = (dd > 0.1) and flat.Unit or axis
                        else
                            if g.w and along > -3 and along <= (g.len or 30) then
                                dist, thr = perp, g.w * 0.5 + body + m
                                dir = (perp > 0.1) and sidev.Unit or axis:Cross(up).Unit
                            end
                            if g.s == "impact" and (not dist or dist > thr) then
                                local centre = aimP or (origin + axis * 20)
                                local rc = Vector3.new(pos.X - centre.X, 0, pos.Z - centre.Z)
                                local rt = (g.r or 11) + body + m
                                if rc.Magnitude <= rt + hyst then
                                    dist, thr = rc.Magnitude, rt
                                    dir = (rc.Magnitude > 0.1) and rc.Unit or axis:Cross(up).Unit
                                end
                            end
                        end
                    end
                    if dist then











                        local hit, hold = false, false
                        if dist <= thr then
                            hit = true
                            if not latch then latches[name] = { move = key, m = m } end
                        elseif latch and dist <= thr + hyst then
                            hit, hold = true, true
                        elseif latch then
                            latches[name] = nil
                        end
                        if hit then
                            local urg = 3 / (1 + dist)
                            if urg > bestUrg then
                                best, bestUrg = { kind = "allylane", dir = dir, dist = dist, hold = hold,
                                                  ally = name, move = key, shape = g.s }, urg
                            end
                        end
                    end
                end
            end
        end
    end

    for n in pairs(seen) do if not present[n] then seen[n] = nil end end
    for n in pairs(latches) do if not present[n] then latches[n] = nil end end
    Bot.AllyLane = best
    return best
end

local function isValidTarget(c)
    if c == getChar() then return false end
    if not isAlive(c) then return false end
    if hasIFrames(c) then return false end


    if isOwnedByUs(c) then return false end
    if isOurClone(c) then return false end
    if c:GetAttribute("HitboxNPC") and resolveOwner(c) == getChar() then return false end

    local isPlayer = Players:GetPlayerFromCharacter(c) ~= nil



    if Config.PlayersOnly and not isPlayer and not soloServer() then return false end



    if not isPlayer and not Config.AttackSummons and not soloServer() and isLikelySummon(c) then
        return false
    end



    local bad = Bot.BadTargets[c]
    if bad and tick() - bad < Config.TargetBlacklistTime then return false end

    local p = Players:GetPlayerFromCharacter(c)
    if p and LocalPlayer.Team and p.Team == LocalPlayer.Team then
        return false
    end





    if p and isAlly(p.Name) then return false end




    if p and isIgnoredPlayer(p.Name) then
        local fresh = Bot.Aggressor == c and (tick() - (Bot.AggressorAt or 0)) < (Config.AggroMemory or 6)
        if not fresh then return false end
    end

    local i = getInfo(c)
    if i and i:GetAttribute("Friendly") then return false end

















    local far = Config.MaxTargetDist3D or 1500
    if far > 0 then
        local ch, mh = getHRP(c), getHRP()
        if ch and mh then
            local dd = (ch.Position - mh.Position).Magnitude
            if dd > far then
                if c == Bot.Target and ch.Position.Magnitude > mh.Position.Magnitude then
                    Bot.BadTargets[c] = tick()
                    debugEvery("far3d", 5, string.format("%s is %.0f studs away (another space) - dropped", c.Name, dd))
                end
                return false
            end
        end
    end

    return true
end



function isTargetAttacking(t)
    if not t then return false end


    return inOwnMove(t)
end

function isTargetFacingUs(t)
    local h = getHRP()
    local th = getHRP(t)
    if not h or not th then return false end
    local toUs = (h.Position - th.Position).Unit
    return toUs:Dot(th.CFrame.LookVector) > 0.35
end












function trackTargetHP(t)
    if not t then
        Bot.TargetHP = nil
        return
    end
    local hp = getHP(t)
    if Bot.TargetHP == nil or hp < Bot.TargetHP then
        Bot.TargetHP = hp
        Bot.TargetHPTime = tick()
    end
end

function isTargetBlocking(t)
    if not t then return false end


    local i = getInfo(t)
    if i then
        if i:FindFirstChild("Block") or i:FindFirstChild("Blocking") then return true end
        if i:GetAttribute("Block") or i:GetAttribute("Blocking") then return true end
    end









    if Config.Sense and senseBlocking(t) then return true end


    if not Bot.M1Active then return false end
    if Bot.TargetHPTime == 0 then return false end








    if Config.Sense and senseBlocking(t) then return true end



    local window = Config.BlockDetectTime
    if Bot.Plan and Bot.Plan.flankEarly then
        window = window / Config.MemLearnBlock
    end
    return (tick() - Bot.TargetHPTime) > window
end












local function updatePursuit(t, d2d, dt)
    if not t then
        Bot.PursuitTime = 0
        Bot.PursuitLastDist = nil
        return
    end

    local prev = Bot.PursuitLastDist
    Bot.PursuitLastDist = d2d


    if Bot.State ~= "RETREAT" then
        Bot.PursuitTime = math.max(0, (Bot.PursuitTime or 0) - (dt or 0.016))
        return
    end

    if prev and d2d <= prev + 0.05 and d2d < Config.PursuitRange then

        Bot.PursuitTime = (Bot.PursuitTime or 0) + (dt or 0.016)
    else
        Bot.PursuitTime = math.max(0, (Bot.PursuitTime or 0) - (dt or 0.016) * 2)
    end
end

local function isBeingChased()
    return (Bot.PursuitTime or 0) > Config.PursuitPatience
end



local function targetIsCommitted(t)
    if not t then return false end
    local i = getInfo(t)
    if not i then return false end
    if i:FindFirstChild("InDash") then return true end
    if i:FindFirstChild("Dash") then return true end
    if i:FindFirstChild("InSkill") then return true end
    local s = i:FindFirstChild("InSkill")
    if s and s.Value then return true end
    return false
end


function getFlankPos(t)
    local th = getHRP(t)
    if not th then return nil end
    return th.Position - th.CFrame.LookVector * Config.FlankDist
end

function countNearbyEnemies(range)
    local h = getHRP()
    if not h then return 0 end
    local count = 0
    for _, c in ipairs(getChars()) do
        if isValidTarget(c) then
            local th = getHRP(c)
            if th and getDist(h.Position, th.Position) < range then
                count = count + 1
            end
        end
    end
    return count
end


local PathfindingService = game:GetService("PathfindingService")






function faceTarget(t, force)
    if not Config.SmoothFacing and not force then return end
    local h = getHRP()
    local th = getHRP(t)
    if not h or not th then return end
    if isInSkill() then return end




    if Bot.BodyLocked then return end

    local pos = h.Position
    local tPos = th.Position
    local flat = Vector3.new(tPos.X, pos.Y, tPos.Z)
    local to = flat - pos
    if to.Magnitude < 0.1 then return end



    local dot = h.CFrame.LookVector:Dot(to.Unit)
    if dot >= math.cos(math.rad(Config.RotDeadbandDeg or 4)) then return end


    local lerp = Config.FaceLerp
    if getMoveVector().Magnitude > 0.1 then lerp = lerp * (Config.RotMovingScale or 0.4) end

    local goal = CFrame.lookAt(pos, flat)
    h.CFrame = h.CFrame:Lerp(goal, lerp)
end































MOVE_BIND = "JJK_AutoFight_Move"
moveBound = false





camProbe = true

function releaseCamera()
    if not Bot.CamTaken then return end
    Bot.CamTaken = false
    local cam = Workspace.CurrentCamera
    if not cam then return end
    pcall(function()
        cam.CameraType = Enum.CameraType.Custom
        local hum = getHum()
        if hum then cam.CameraSubject = hum end
    end)
    debug("camera: released")
end



























local function paceNote(now, h, goal, reversed)
    local win = Config.PaceWindow or 3
    local bins = Bot.RevBins
    local id = math.floor(now * 6 / win)
    local last = Bot.RevBinId or 0
    if id - last >= 7 or id < last then
        for k = 1, 7 do bins[k] = 0 end
    else
        for k = last + 1, id do bins[k % 7 + 1] = 0 end
    end
    Bot.RevBinId = id
    local n = 0
    for k = 1, 7 do n = n + bins[k] end
    if reversed then
        Life.reversals = (Life.reversals or 0) + 1


        if n == 0 or not Bot.PaceFrom or (not Bot.PaceArmed and now - (Bot.PaceFromAt or 0) > win) then
            Bot.PaceFrom, Bot.PaceFromAt = h.Position, now
        end
        local slot = id % 7 + 1
        bins[slot] = bins[slot] + 1
        n = n + 1
        if n >= (Config.PaceMinRevs or 4) then Bot.PaceArmed = true end
    end
    if not Bot.PaceArmed or not Bot.PaceFrom or now - (Bot.PaceFromAt or now) < win then return end


    local from, fromAt = Bot.PaceFrom, Bot.PaceFromAt
    for k = 1, 7 do bins[k] = 0 end
    Bot.PaceArmed, Bot.PaceFrom = false, nil
    if n < (Config.PaceMinRevs or 4) then return end
    local th = Bot.Target and getHRP(Bot.Target)
    local lead = Bot.TeamFollow and Players:FindFirstChild(Bot.TeamFollow)
    local lh = lead and lead.Character and getHRP(lead.Character)
    debugEvery("pacing", 1, string.format(
        "pacing: %.1f rev/s (%d in %.0fs), moved %.0f in %.1fs | state=%s role=%s follow=%s mode=%s wp=%s stuck=%.1f los=%s probe=%s tgt=%.0f lead=%.0f run=%s",
        n / win, n, win, getDist2D(h.Position, from) or 0, now - fromAt,
        tostring(Bot.State), tostring(Bot.TeamRole),
        tostring(Bot.TeamFollowing), tostring(Bot.NavMode), tostring(Bot.PathIndex), Bot.StuckTime or 0,
        tostring(Bot.Target and hasLineOfSight(Bot.Target)), tostring(goal ~= nil and probeBlocked(h.Position, goal)),
        th and (getDist2D(h.Position, th.Position) or -1) or -1,
        lh and (getDist2D(h.Position, lh.Position) or -1) or -1,
        tostring(Bot.TeamRunTo)))
end

function moveStep()
    Bot.MoveStepAt = tick()
    local hum, h = getHum(), getHRP()
    if not hum or not h then return end



    local goal = Bot.WalkGoal
    local to = goal and Vector3.new(goal.X - h.Position.X, 0, goal.Z - h.Position.Z) or nil
    if not to or to.Magnitude < (Config.WalkStopRadius or 1.0) then
        if Bot.WalkActive then
            hum:Move(Vector3.zero, false)
            Bot.WalkActive = false
        end
        return
    end
    local dir = to.Unit
    hum:Move(dir, false)
    Bot.WalkActive = true

    local prevDir, nowM = Bot.MoveDirPrev, Bot.MoveStepAt
    if prevDir and nowM - (Bot.MoveDirAt or 0) < 0.5 and dir:Dot(prevDir) < -0.5
       and Bot.State ~= "CCED" and Bot.State ~= "DEAD" then





        Bot.RevPending = (Bot.RevPending or 0) + 1
        Bot.RevGoal = goal
    end
    Bot.MoveDirPrev, Bot.MoveDirAt = dir, nowM
    local cam = Workspace.CurrentCamera
    if cam then
        if cam.CameraType ~= Enum.CameraType.Scriptable then
            cam.CameraType = Enum.CameraType.Scriptable
        end

        local lv = h.CFrame.LookVector
        local face = Vector3.new(lv.X, 0, lv.Z)
        face = face.Magnitude > 0.05 and face.Unit or dir
        cam.CFrame = CFrame.lookAt(h.Position - face * 10 + Vector3.new(0, 5, 0), h.Position + face * 6)
        Bot.CamTaken = true
    end


    Bot.CamProbe = (camProbe ~= nil)
end

function bindMover()
    if moveBound then return end
    moveBound = true
    Bot.MoveStepAt = tick()
    RunService:BindToRenderStep(MOVE_BIND, Enum.RenderPriority.Input.Value + 1, moveStep)
end

function unbindMover()
    Bot.WalkGoal = nil
    Bot.WalkActive = false
    if moveBound then
        moveBound = false
        pcall(function() RunService:UnbindFromRenderStep(MOVE_BIND) end)
    end
    local hum = getHum()
    if hum then pcall(function() hum:Move(Vector3.zero, false) end) end
    releaseCamera()
end





moverWarned = false
function tickMover()
    local goal = Bot.WalkGoal
    if not goal or not moveBound then return end
    if tick() - (Bot.MoveStepAt or 0) < 0.5 then return end
    local hum = getHum()
    if hum then hum:MoveTo(goal) end
    local hh = getHRP()
    if hh then
        Bot.WalkActive = (getDist2D(hh.Position, goal) or 0) >= (Config.WalkStopRadius or 1.0)
    end
    if not moverWarned then
        moverWarned = true
        debug("mover: render step not ticking - falling back to MoveTo (no sprint)")
    end
end







function walkTo(pos)
    local h = getHRP()
    local now = tick()




    if Bot.DetourGoal and now < (Bot.DetourUntil or 0) and pos ~= Bot.DetourGoal then
        if h and (getDist2D(h.Position, Bot.DetourGoal) or 0) > 2 then
            pos = Bot.DetourGoal
        else
            Bot.DetourGoal = nil
        end
    end
    Bot.WalkGoal = pos
    bindMover()
end

function stopWalking()
    Bot.Path = nil
    Bot.WalkGoal = nil
    Bot.DetourGoal = nil
    local hum = getHum()
    if hum and Bot.WalkActive then
        pcall(function() hum:Move(Vector3.zero, false) end)
        Bot.WalkActive = false
    end
end




local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Include



pcall(function() losParams.RespectCanCollide = true end)

function refreshLosFilter()
    local list = {}




    for _, n in ipairs({ "Map", "Domains", "Terrain" }) do
        local f = Workspace:FindFirstChild(n)
        if f then table.insert(list, f) end
    end
    losParams.FilterDescendantsInstances = list
end
refreshLosFilter()

function hasLineOfSight(t)
    local h = getHRP()
    local th = getHRP(t)
    if not h or not th then return false end
    local dir = th.Position - h.Position
    local hit = Workspace:Raycast(h.Position, dir, losParams)
    return hit == nil
end











function probeBlocked(fromPos, toPos)
    local flat = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
    if flat.Magnitude < 0.5 then return false end
    local len = math.min(Config.ProbeAhead or 6, flat.Magnitude)
    local origin = fromPos + Vector3.new(0, 0.5, 0)
    local hit = Workspace:Raycast(origin, flat.Unit * len, losParams)

    if hit == nil or hit.Normal.Y >= 0.5 then return false end




    local d1 = (hit.Position - origin).Magnitude
    local up = Vector3.new(0, 3, 0)
    local hit2 = Workspace:Raycast(origin + up, flat.Unit * len, losParams)
    if hit2 == nil then return false end
    local d2 = (hit2.Position - origin - up).Magnitude
    return d2 <= d1 + 1.5
end



function probeLowHigh(fromPos, dir)
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude < 0.05 then return false, false end
    flat = flat.Unit * 6
    local function steep(hit) return hit ~= nil and hit.Normal.Y < 0.5 end
    local oLow, oHigh = fromPos + Vector3.new(0, -1.5, 0), fromPos + Vector3.new(0, 3.5, 0)
    local hLow  = Workspace:Raycast(oLow,  flat, losParams)
    local hHigh = Workspace:Raycast(oHigh, flat, losParams)
    local low  = steep(hLow)
    local high = steep(hHigh)




    if low and high then
        local dl = (hLow.Position - oLow).Magnitude
        local dh = (hHigh.Position - oHigh).Magnitude
        if dh > dl + 1.5 then high = false end
    end
    return low, high, hLow, hHigh
end


function describeHit(hit)
    if not hit or not hit.Instance then return "nothing" end
    local p = hit.Instance
    local sz = p:IsA("BasePart") and p.Size or Vector3.zero
    return string.format("%s [%.0fx%.0fx%.0f%s]", p:GetFullName(), sz.X, sz.Y, sz.Z,
        (p:IsA("BasePart") and p.Anchored) and "" or " loose")
end





function sidestepGoal(t, goal)
    local req = Bot.SidestepReq
    if not (Config.HoldSidestep and req) then return nil end
    local st = Bot.State
    if st ~= "APPROACH" and st ~= "APPROACH_FAR" and st ~= "CHASE" and st ~= "LEVEL" then Bot.SidestepReq = nil return nil end
    local h = getHRP()
    if not (h and req.axis) then Bot.SidestepReq = nil return nil end
    local myPos, now = h.Position, tick()
    if not req.goal then
        local dist = Config.HoldSidestepDist or 6
        local perp = req.axis:Cross(Vector3.new(0, 1, 0)) * (-(req.side or 1))
        local hit = Workspace:Raycast(myPos, perp * (dist + 2), losParams)
        if hit then
            local other = Workspace:Raycast(myPos, -perp * (dist + 2), losParams)
            perp = other and perp * 0.5 or -perp
        end
        req.goal = myPos + perp * dist
        req.until_ = now + 1.5
        Life.sidesteps = (Life.sidesteps or 0) + 1
        debugEvery("sidestep", 2, string.format("sidestep %.0f studs off %s's lane (%s held twice for them)",
            dist, tostring(req.ally), tostring(req.move)))
    end
    if now < (req.until_ or 0) and getDist2D(myPos, req.goal) > 1.5 then
        return Vector3.new(req.goal.X, goal and goal.Y or myPos.Y, req.goal.Z)
    end
    Bot.SidestepReq = nil
    return nil
end

function openSide(h)
    local r = h.CFrame.RightVector
    local function clearance(v)
        local hit = Workspace:Raycast(h.Position, v * 12, losParams)
        return hit and (hit.Position - h.Position).Magnitude or 12
    end
    local cr, cl = clearance(r), clearance(-r)
    if math.abs(cr - cl) < 1 then return (math.random() < 0.5) and r or -r end
    return (cr > cl) and r or -r
end







function targetIsFleeing(t)
    local h = getHRP()
    local th = getHRP(t)
    if not h or not th then return false end

    local away = Vector3.new(th.Position.X - h.Position.X, 0, th.Position.Z - h.Position.Z)
    if away.Magnitude < 1 then return false end
    away = away.Unit


    local vel = th.AssemblyLinearVelocity
    local flatVel = Vector3.new(vel.X, 0, vel.Z)
    local recede = flatVel:Dot(away)


    local look = Vector3.new(th.CFrame.LookVector.X, 0, th.CFrame.LookVector.Z)
    local backTurned = look.Magnitude > 0.05 and look.Unit:Dot(away) > 0.35

    return recede > Config.FleeSpeed and backTurned
end




function clearPath()
    Bot.Path = nil
    Bot.PathPoints = nil
    Bot.PathIndex = 1
end




function firstWaypointAhead(pts, pos)
    local skip = Config.WaypointSkip or 3
    local firstFar = nil
    for i = 2, #pts do
        local p = pts[i].Position
        local to = Vector3.new(p.X - pos.X, 0, p.Z - pos.Z)
        if to.Magnitude >= skip then
            firstFar = firstFar or i



            local prev = pts[i - 1].Position
            local inc = Vector3.new(p.X - prev.X, 0, p.Z - prev.Z)
            local passed = inc.Magnitude >= 0.5 and (-to):Dot(inc) > 0
            if not passed then
                if i == firstFar then return i end

                local hit = Workspace:Raycast(pos + Vector3.new(0, 0.5, 0), p - pos, losParams)
                return hit == nil and i or firstFar
            end
        end
    end
    return firstFar or #pts
end



















function computePath(destination, goalKey)
    goalKey = goalKey or destination
    local h = getHRP()
    if not h then return false end
    if Bot.PathBusy then return Bot.PathPoints ~= nil end

    Bot.PathBusy = true
    Bot.LastPathCompute = tick()





    local t0 = os.clock()
    local ok, path = pcall(function()
        local pth = PathfindingService:CreatePath({
            AgentRadius = 3,
            AgentHeight = 6,
            AgentCanJump = true,
            AgentMaxSlope = 45,
        })
        pth:ComputeAsync(h.Position, destination)
        return pth
    end)
    Bot.PathBusy = false
    do
        local sec = os.clock() - t0
        Bot.PathSec = (Bot.PathSec or 0) + sec
        Life.pathN = (Life.pathN or 0) + 1
        Life.pathSum = (Life.pathSum or 0) + sec
        if sec > (Life.pathMax or 0) then Life.pathMax = sec end
    end







    local keep = Bot.PathPoints and Bot.PathIndex and Bot.PathIndex <= #Bot.PathPoints
    if not ok or not path or path.Status ~= Enum.PathStatus.Success then
        if not keep then clearPath() end
        return false
    end

    local pts = path:GetWaypoints()
    if #pts < 2 then
        if not keep then clearPath() end
        return false
    end

    local h2 = getHRP()
    local pos = h2 and h2.Position or h.Position
    local newIdx = firstWaypointAhead(pts, pos)



    local cur = Bot.PathPoints


    local sameGoal = Bot.PathGoal ~= nil
                     and (Vector3.new(goalKey.X - Bot.PathGoal.X, 0, goalKey.Z - Bot.PathGoal.Z)).Magnitude <= 12
    if cur and sameGoal and Bot.PathIndex and Bot.PathIndex <= #cur
       and (tick() - (Bot.PathAdoptedAt or 0)) < (Config.RouteCommit or 3) then
        local cw, nw = cur[Bot.PathIndex].Position, pts[newIdx].Position
        local a = Vector3.new(cw.X - pos.X, 0, cw.Z - pos.Z)
        local b = Vector3.new(nw.X - pos.X, 0, nw.Z - pos.Z)
        if a.Magnitude > 1 and b.Magnitude > 1 and a.Unit:Dot(b.Unit) < 0 then
            debugEvery("routekeep", 3, "new route reverses the current one - keeping the current route")
            return true
        end
    end

    Bot.Path = path
    Bot.PathPoints = pts
    Bot.PathIndex = newIdx
    Bot.PathAdoptedAt = tick()
    Bot.PathGoal = goalKey
    return true
end


function followPath()
    local pts = Bot.PathPoints
    local h = getHRP()
    if not pts or not h then return false end

    if Bot.PathIndex > #pts then
        clearPath()
        return false
    end

    local wp = pts[Bot.PathIndex]
    local flatDist = (Vector3.new(wp.Position.X, h.Position.Y, wp.Position.Z) - h.Position).Magnitude

    if flatDist < 4 then
        Bot.PathIndex = Bot.PathIndex + 1
        if Bot.PathIndex > #pts then
            clearPath()
            return false
        end
        wp = pts[Bot.PathIndex]
    end

    if wp.Action == Enum.PathWaypointAction.Jump then
        local hum = getHum()
        if hum then hum.Jump = true end
    end





    Bot.NavMode = "path"
    local goal = wp.Position
    local flat = Vector3.new(goal.X - h.Position.X, 0, goal.Z - h.Position.Z)
    if flat.Magnitude > 1.5 then
        local hit = Workspace:Raycast(h.Position + Vector3.new(0, 0.5, 0), flat, losParams)
        if hit and hit.Normal.Y < 0.5 then
            local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
            if n.Magnitude > 0.1 then
                n = n.Unit




                local depth = (hit.Position - goal):Dot(n)
                goal = goal + n * (depth + (Config.CornerPushOff or 3))
                Bot.NavMode = "corner"
            end
        end
    end
    walkTo(goal)
    return true
end















function steerAround(destination)
    local h = getHRP()
    if not h then return false end
    local pos = h.Position
    local to = Vector3.new(destination.X - pos.X, 0, destination.Z - pos.Z)
    if to.Magnitude < 0.5 then return false end
    local fwd = to.Unit
    local right = Vector3.new(-fwd.Z, 0, fwd.X)
    local len = Config.FeelerLen or 14
    local need = Config.FeelerMinClear or 9
    local function clearance(dir)
        local c = len
        for _, dy in ipairs({ 0.5, -1.5 }) do
            local hit = Workspace:Raycast(pos + Vector3.new(0, dy, 0), dir * len, losParams)
            if hit and hit.Normal.Y < 0.5 then
                local d = (hit.Position - pos).Magnitude
                if d < c then c = d end
            end
        end
        return c
    end

    local best, bestDir = 0, nil
    for _, deg in ipairs({ 35, -35, 70, -70, 105, -105, 140, -140 }) do
        local a = math.rad(deg)
        local dir = (fwd * math.cos(a) + right * math.sin(a)).Unit
        local c = clearance(dir)
        if c >= need then best, bestDir = c, dir break end
        if c > best then best, bestDir = c, dir end
    end




    local run = math.min(Config.DetourLen or 12, best - 2)
    if not bestDir or run < 3 then return false end
    Bot.DetourGoal = pos + bestDir * run
    Bot.DetourUntil = tick() + (Config.DetourHold or 1.5)
    Bot.NavMode = "detour"
    walkTo(Bot.DetourGoal)
    return true
end


function walkOrSteer(destination)
    local h = getHRP()
    if h and probeBlocked(h.Position, destination) and steerAround(destination) then return end
    Bot.NavMode = "straight"
    walkTo(destination)
end











function leashGoal(destination)
    Bot.Leashed = false
    if not Bot.TeamFollow then return destination end


    local st = Bot.State
    if st ~= "APPROACH" and st ~= "APPROACH_FAR" and st ~= "CHASE" and st ~= "LEVEL" then return destination end
    local lead = Players:FindFirstChild(Bot.TeamFollow)
    local lh = lead and lead.Character and getHRP(lead.Character)
    if not lh then return destination end
    local lp = lh.Position
    local off = Vector3.new(destination.X - lp.X, 0, destination.Z - lp.Z)
    local edge = (Bot.TeamFollowRadius or Config.TeamFollowRadius or 22) - (Config.TeamBand or 4) - 2
    if off.Magnitude <= edge + 2 then return destination end
    Bot.NavMode = "leash"
    Bot.Leashed = true









    local dirL = off.Unit
    local side = teamWingSide()
    if side ~= 0 then
        local tgt = Bot.Target and getHRP(Bot.Target)
        local base = tgt and Vector3.new(tgt.Position.X - lp.X, 0, tgt.Position.Z - lp.Z) or off
        if base.Magnitude > 1 then
            local ang = (Bot.TeamRole == "GUARD") and (Config.GuardWingAngle or 40) or (Config.TeamWingAngle or 70)
            dirL = rotFlat(base.Unit, -side * ang)
        end
    end
    local pt = Vector3.new(lp.X, destination.Y, lp.Z) + dirL * edge


    if Bot.LeashPoint and (getDist2D(pt, Bot.LeashPoint) or 99) < (Config.LeashDeadZone or 3) then
        return Bot.LeashPoint
    end
    Bot.LeashPoint = pt
    return pt
end




function spreadGoal(t, goal)
    if not Config.SpreadAttack then return goal end
    local st = Bot.State
    if st ~= "APPROACH" and st ~= "APPROACH_FAR" and st ~= "CHASE" and st ~= "LEVEL" then return goal end
    local h, th = getHRP(), t and getHRP(t)
    if not (h and th and goal) then return goal end
    local myPos, tp = h.Position, th.Position
    local toT = Vector3.new(tp.X - myPos.X, 0, tp.Z - myPos.Z)
    if toT.Magnitude <= (Config.SpreadMinDist or 9) then return goal end
    local bearings = {}
    for _, a in ipairs(allyChars()) do
        local v = Vector3.new(a.hrp.Position.X - tp.X, 0, a.hrp.Position.Z - tp.Z)
        if v.Magnitude > 0.5 and v.Magnitude <= (Config.SpreadAllyRange or 20) then bearings[#bearings + 1] = v.Unit end
    end
    if #bearings == 0 then return goal end
    local ours = -toT.Unit
    local best, bestGap = nil, -1
    for _, deg in ipairs({ 0, Config.SpreadAngle or 100, -(Config.SpreadAngle or 100) }) do
        local b, gap = rotFlat(ours, deg), 999
        for _, ab in ipairs(bearings) do gap = math.min(gap, math.deg(math.acos(math.clamp(b:Dot(ab), -1, 1)))) end
        if gap > bestGap + 1 then best, bestGap = (deg ~= 0) and b or nil, gap end
    end
    if not best then return goal end
    local r = Config.SpreadRadius or 0
    if r <= 0 then r = Config.M1Range or 7 end
    debugEvery("spread", 3, string.format("spread: %d team-mate(s) on %s, going round to the clear side (gap %.0f deg)",
        #bearings, tostring(t and t.Name or "?"), bestGap))
    return Vector3.new(tp.X + best.X * r, goal.Y, tp.Z + best.Z * r)
end

function navigateTo(t, destination)
    local now = tick()
    if t == Bot.Target then destination = leashGoal(destination) else Bot.Leashed = false end
    if t == Bot.Target then
        destination = sidestepGoal(t, destination) or spreadGoal(t, destination)
    end




    if Bot.DetourGoal and now < (Bot.DetourUntil or 0) then
        local hd = getHRP()
        if hd and (getDist2D(hd.Position, Bot.DetourGoal) or 0) > 2 then
            walkTo(Bot.DetourGoal)
            return
        end
    end
    Bot.DetourGoal = nil

    local clear = hasLineOfSight(t)







    local h0 = getHRP()
    if h0 and (getDist2D(h0.Position, destination) or 0) < 5 then
        clearPath()
        walkTo(destination)
        return
    end
    local blockedNow = (not clear) or Bot.StuckTime >= 0.5
                       or (h0 ~= nil and probeBlocked(h0.Position, destination))
    if blockedNow then
        Bot.PathCommitUntil = math.max(Bot.PathCommitUntil or 0, now + (Config.PathCommit or 3))
    elseif now > (Bot.PathCommitUntil or 0) then
        clearPath()
        Bot.NavMode = "straight"
        walkTo(destination)
        return
    end

    if not Config.UsePathfinding then
        walkOrSteer(destination)
        local hum = getHum()
        if hum and Bot.StuckTime > 1.0 and tick() - (Bot.LastHop or 0) > (Config.HopCooldown or 1.0) then Bot.LastHop = tick(); hum.Jump = true end
        return
    end

    if Bot.PathBusy then
        if not followPath() then walkOrSteer(destination) end
        return
    end

    local needNew = (not Bot.PathPoints)
        or (now - (Bot.LastPathCompute or 0) > Config.PathRefresh)
        or (Bot.PathTargetPos and (Bot.PathTargetPos - destination).Magnitude > 12)

    if needNew then
        Bot.PathTargetPos = destination
        if not computePath(destination) then



            if now - (Bot.LastPathFailAt or 0) > (Config.PathRefresh or 1) * 0.9 then
                Bot.PathFails = Bot.PathFails + 1
                Bot.LastPathFailAt = now
            end


















            local far = false
            if t then
                local h2 = getHRP()
                local th2 = getHRP(t)
                far = h2 and th2
                      and (th2.Position - h2.Position).Magnitude > Config.BlacklistRange
            end

            if far then
                Bot.PathFails = 0








                local h3 = getHRP()
                local flat = h3 and Vector3.new(destination.X - h3.Position.X, 0, destination.Z - h3.Position.Z)
                if h3 and flat and flat.Magnitude > 1 then
                    local stone = h3.Position + flat.Unit * (Config.FarPathStep or 60)
                    if computePath(stone, destination) then
                        Bot.PathTargetPos = destination
                        Bot.LastPathCompute = now
                        debugEvery("farpath", 5, string.format(
                            "%s is far (%.0f studs) - pathing via a stepping stone", t.Name, flat.Magnitude))
                        followPath()
                        return
                    end
                end























                local ownWalk = t == Bot.Target and Bot.State ~= "RETREAT" and not Bot.Leashed
                                and not Bot.TeamFollowing
                                and Bot.TeamRole ~= "SUPPORT" and Bot.TeamRole ~= "PEEL" and Bot.TeamRole ~= "GUARD"
                if ownWalk and now - (Bot.FarPathFailAt or 0) >= (Config.PathRefresh or 1) * 0.9 then
                    Bot.FarPathFailAt = now
                    local hh0, tth0 = getHRP(), getHRP(t)
                    local dNow = (hh0 and tth0) and (tth0.Position - hh0.Position).Magnitude or nil
                    if Bot.FarPathTarget ~= t then
                        Bot.FarPathTarget, Bot.FarPathFails, Bot.FarPathBest = t, 0, dNow or math.huge
                    end
                    if dNow and dNow < (Bot.FarPathBest or dNow) - (Config.ChaseProgress or 8) then
                        Bot.FarPathBest, Bot.FarPathFails = dNow, 0
                    else
                        Bot.FarPathFails = (Bot.FarPathFails or 0) + 1
                    end
                    if Bot.FarPathFails >= (Config.FarPathLimit or 5) then
                        Bot.BadTargets[t] = now + (Config.FarPathBlacklist or 20) - (Config.TargetBlacklistTime or 8)
                        debug(string.format("%s is unpathable at %.0f studs and not closing (%d failures) - written off for %ds",
                            t.Name, dNow or -1, Bot.FarPathFails, Config.FarPathBlacklist or 20))
                        Bot.FarPathTarget, Bot.FarPathFails = nil, 0
                        Bot.ChaseDroppedAt = now
                        Bot.Target = nil
                        Bot.Contender = nil
                        Bot.ChaseTarget = nil
                        Bot.UsedSkillsThisFight = {}
                        stopWalking()
                        return
                    end
                end
                clearPath()
                walkOrSteer(destination)
                local hh, tth = getHRP(), getHRP(t)
                debugEvery("farpath", 5, string.format(
                    "%s too far to path (%.0f studs) - walking instead", tostring(t and t.Name),
                    (hh and tth) and (tth.Position - hh.Position).Magnitude or -1))
                return
            end

            if Bot.PathFails >= Config.PathFailLimit and t then
                Bot.PathFails = 0








                if t ~= Bot.Target then
                    clearPath()
                    walkOrSteer(destination)
                    return
                end
                Bot.BadTargets[t] = tick()
                Bot.Target = nil
                debugEvery("blacklist:" .. t.Name, 5,
                    "Unreachable, blacklisting: " .. t.Name)
                stopWalking()
                return
            end





            if not followPath() then walkOrSteer(destination) end
            local hum = getHum()
            if hum and Bot.StuckTime > 1.0 and tick() - (Bot.LastHop or 0) > (Config.HopCooldown or 1.0) then Bot.LastHop = tick(); hum.Jump = true end
            return
        else
            Bot.PathFails = 0
        end
    end

    if not followPath() then
        walkOrSteer(destination)
    end
end



















local bodyConn = nil
local bodyLocked = false



local lastLockTarget = nil
local function updateNativeLock()
    if Bot.Target ~= lastLockTarget then
        lastLockTarget = Bot.Target
        setLockOn(Bot.Target)
    end
end

local function releaseBody()
    Bot.BodyLocked = false
    if not bodyLocked then return end
    bodyLocked = false
    local hum = getHum()
    if hum then hum.AutoRotate = true end
end

local function bodyLockStep()
    if not Config.Enabled or not Config.BodyLock then releaseBody() return end
    local h, hum = getHRP(), getHum()
    if not (h and hum) then bodyLocked = false return end



    local t = guardTarget()
    local th = (t and isAlive(t)) and getHRP(t) or nil
    if not th then releaseBody() return end

    local pos = h.Position
    local flat = Vector3.new(th.Position.X, pos.Y, th.Position.Z)
    local d = (flat - pos).Magnitude
    if d < 0.5 or d > Config.BodyLockRange then releaseBody() return end






    if Bot.FollowWalk then releaseBody() return end


    if isInSkill() or isRagdolled() or senseGrabbed() then return end

    bodyLocked = true
    Bot.BodyLocked = true
    if hum.AutoRotate then hum.AutoRotate = false end





    local to = flat - pos
    local dot = h.CFrame.LookVector:Dot(to.Unit)
    if dot >= math.cos(math.rad(Config.RotDeadbandDeg or 4)) then return end

    local lerp = Config.BodyLockLerp
    if getMoveVector().Magnitude > 0.1 then lerp = lerp * (Config.RotMovingScale or 0.4) end

    local goal = CFrame.lookAt(pos, flat)
    h.CFrame = h.CFrame:Lerp(goal, lerp)
end

local function startBodyLock()
    if bodyConn then return end
    bodyConn = RunService.Heartbeat:Connect(function()
        local ok, err = pcall(bodyLockStep)
        if not ok then debugEvery("bodylock-err", 10, "body lock: " .. tostring(err)) end
    end)
end

local function stopBodyLock()
    if bodyConn then
        bodyConn:Disconnect()
        bodyConn = nil
    end
    releaseBody()
end


























SPRINT_STATES = { APPROACH = true, APPROACH_FAR = true, RETREAT = true,
                        CHASE = true, TEAMKITE = true }


function setSprintKey(down)
    down = down and true or false
    Bot.SprintHeld = down
    local c = getChar()
    if not c then return end
    local cur = c:GetAttribute("Sprint") and true or false
    if cur ~= down then
        pcall(function() c:SetAttribute("Sprint", down) end)
    end
end

function applySprint()
    local hum = getHum()
    if not hum then return end
    if not Config.Sprint then
        setSprintKey(false)
        return
    end


    local info = getInfo()
    if info and info:FindFirstChild("NoSprint") then
        setSprintKey(false)
        return
    end

    local md = getMoveVector()
    local moving = md.Magnitude > 0.1
    local st = Bot.State


    local inMelee = Bot.TargetDist and Bot.TargetDist < Config.SprintMinDist
                    and st ~= "RETREAT" and st ~= "TEAMKITE" and not Bot.FollowWalk




    local h = getHRP()
    local coneDot = 0
    if moving and h then
        local lv = h.CFrame.LookVector
        local face = Vector3.new(lv.X, 0, lv.Z)
        if face.Magnitude > 0.05 then coneDot = face.Unit:Dot(md.Unit) end
    end
    local inCone = coneDot >= (Config.SprintCone or 0.55)

    local want = moving and inCone
                 and (SPRINT_STATES[st] or Bot.TeamFollow ~= nil or Bot.TeamRunTo ~= nil)
                 and not inMelee
                 and not (isStunned() or isRagdolled() or isInSkill())

    setSprintKey(want)


    if moving and (SPRINT_STATES[st] or Bot.TeamFollow ~= nil or Bot.TeamRunTo ~= nil) then
        local v = h and h.AssemblyLinearVelocity or Vector3.zero
        local c = getChar()
        debugEvery("sprintstat", 10, string.format(
            "sprint: want=%s cone=%.2f attr=%s walk=%.1f speed=%.1f state=%s",
            tostring(want), coneDot, tostring(c and c:GetAttribute("Sprint")), hum.WalkSpeed,
            Vector3.new(v.X, 0, v.Z).Magnitude, tostring(st)))
    end
end


function checkDivineDog()
    local c = getChar()
    if not c then return false end




    local every = Config.DivineDogEvery or 0.5
    if every > 0 then
        local nowT = tick()
        if nowT - (Bot.DivineDogAt or 0) < every then return Bot.DivineDogActive end
        Bot.DivineDogAt = nowT
        local ms = c:FindFirstChild("Moveset")
        if not (ms and ms:FindFirstChild("Divine Dog: Totality")) then return false end
    end
    for _, rootName in ipairs({ "Effects", "Characters" }) do
        local root = Workspace:FindFirstChild(rootName)
        if root then
            for _, obj in ipairs(root:GetChildren()) do
                if obj:IsA("Model") and (obj.Name:match("Divine") or obj.Name:match("Dog")) then
                    local owner = obj:FindFirstChild("Owner")
                    if owner and owner.Value == c then return true end
                    if obj:GetAttribute("Owner") == c then return true end
                end
            end
        end
    end
    return false
end






function castGate(rule, name)
    if rule.cc or rule.counter or rule.escape then return nil end
    local key = senseMoveKey(name)
    local g = FriendlyGeom[key]
    local cast = g and g.cast
    if not cast then
        local kind = DangerByService[key]
        cast = (kind == "beam" and 0.6) or (kind == "aoe" and 0.8) or (kind == "pull" and 0.5) or 0
    end
    if cast >= (Config.SwingCastMin or 0.4) then return cast end
    return nil
end

function getUsableMoves()
    local moves = getAvailableMoves()
    local list = {}
    for service, m in pairs(moves) do
        local rule = MoveRules[m.value.Name] or DefaultRule
        table.insert(list, {
            service = service,
            name = m.value.Name,
            rule = rule,
        })
    end
    table.sort(list, function(a, b)
        if a.rule.prio == b.rule.prio then return a.name < b.name end
        return a.rule.prio < b.rule.prio
    end)
    return list
end






function moveRange(entry)
    local lo, hi = memLearnedRange(entry.name)
    if lo then return lo, hi, true end
    return entry.rule.min, entry.rule.max, false
end










function verticalTolerance(rule)
    local reach = rule.max or 20
    return math.clamp(reach * 0.3, 8, 26)
end

function shouldUseMove(entry, t, d2d)
    local rule = entry.rule
    if not isSkillReady(entry.service) then return false end









    local dy = math.abs(Bot.DistY or 0)
    if dy > verticalTolerance(rule) then return false end

    local hp = getHPPct()
    local enemies = countNearbyEnemies(25)
    local now = tick()


    if rule.summon then


        local last = (Bot.UsedSkillsThisLife or {})[entry.service]
        if last and now - last < 18 then return false end
        if entry.name == "Divine Dog: Totality" and Bot.DivineDogActive then
            return false
        end
        return d2d <= (select(2, moveRange(entry)))
    end


    if rule.selfBuff then
        local last = (Bot.UsedSkillsThisLife or {})[entry.service]
        return (not last) or (now - last > (Config.BuffRearm or 45))
    end


    if rule.escape then
        if hp > 40 and enemies < 3 then return false end
        return d2d <= (select(2, moveRange(entry)))
    end


    if rule.heavy then
        local lo, hi = moveRange(entry)
        if d2d < lo or d2d > hi then return false end
        if isDowned(t) then return true end
        if enemies >= 2 then return true end
        if getHPPct(t) < 35 then return true end
        return false
    end

    local lo, hi = moveRange(entry)
    return d2d >= lo and d2d <= hi
end
















local function canAwaken()
    local c = getChar()
    if not c then return false end

    if tick() < (Bot.AwakenBlockUntil or 0) then return false end

    local set = c:GetAttribute("Moveset")
    local info = getInfo(c)


    if info and info:GetAttribute("Ult") then return false end



    if not (set and UltNeedsInUlt[set]) then
        if c:GetAttribute("InUlt") then return false end
    end

    local gate = set and UltGate[set]
    if gate then
        local ok, res = pcall(gate, c)
        if not ok or not res then return false end
    end

    return true
end

local function shouldAwakenNow(hp)
    if not canAwaken() then return false end

    local c = getChar()
    local set = c and c:GetAttribute("Moveset")
    if set and HoardUlt[set] then
        return hp < Config.UltimateHP or countNearbyEnemies(20) >= 3
    end
    return true
end











function useBestMove(t, intent)
    if not Config.UseSkills then return false end
    if not t then return false end
    if inOwnMove() then return false end
    if tick() - Bot.LastSkill < (Config.SkillDelayIntent or Config.SkillDelay) then return false end

    local h, th = getHRP(), getHRP(t)
    local d2d = getDist2D(h and h.Position, th and th.Position)


    if intent ~= "escape" and tick() < (Bot.RecoverUntil or 0) then return false end


    local swingLive = (Config.SwingCastGate or 0) > 0 and (tick() - (Bot.LastSwingAt or 0)) < (Config.SwingCastGate or 0.5)
    local usable = getUsableMoves()
    local maxDpt = memMaxDpt(usable, t)
    local maxChain = memMaxChain(usable)

    local best, bestScore = nil, -1
    for _, e in ipairs(usable) do
        local r = e.rule




        local lo, hi = moveRange(e)
        local okKind = not (r.selfBuff or r.summon) or (intent == "trap" and r.trap)
        if okKind and swingLive and castGate(r, e.name) then okKind = false end
        if okKind and isSkillReady(e.service) and d2d >= lo and d2d <= hi
           and not memIsHardDud(e.name)
           and not (Bot.Refused and (tick() - (Bot.Refused[e.service] or 0)) < (Config.CastRefusalHold or 2.5)) then
            local score = -1
            if intent == "escape" and r.escape then score = 100
            elseif intent == "escape" and d2d < 20 then score = 20
            elseif intent == "counter" and not r.summon and not r.selfBuff and d2d <= 30 then
                score = 60 - r.prio
            elseif intent == "ranged" and r.max >= 45 then score = 70 - r.prio
            elseif intent == "heavy" and r.heavy then score = 90

            elseif intent == "cc" and r.cc then score = 100 - r.prio
            elseif intent == "trap" and r.trap then score = 95 - r.prio
            elseif intent == "punish" then


                if r.cc then score = 100
                elseif r.heavy then score = 80
                elseif d2d <= 14 then score = 40 - r.prio
                end
            end
            if score > 0 then
                score = score * memMoveWeight(e.name, t, maxDpt)
                         * memChainWeight(e.name, maxChain)
                if memIsDud(e.name, maxDpt) then score = score * 0.15 end
            end
            if score > bestScore then best, bestScore = e, score end
        end
    end

    if best then return useSkill(best.service) end
    return false
end



function trySpecial(t, d2d)
    if not Config.UseSpecial then return false end
    if inOwnMove() then return false end


    if tick() - Bot.LastSkill < Config.SkillDelay then return false end
    if not isSpecialReady() then return false end

    local rule = getSpecialRule()
    if not rule or rule.kind == "avoid" then return false end

    local key = "SPECIAL:" .. tostring(rule.name)
    local paroled = false
    if memIsHardDud(key) then

        if not memDudParole(key, false) then return false end
        paroled = true
    end
    if not t then return false end

    if memComboHold(key, nil, t) then return false end
    if rule.kind ~= "utility" then
        local lo, hi = memLearnedRange(key)
        lo, hi = lo or rule.min, hi or rule.max
        if d2d < lo or d2d > hi then return false end
    elseif (d2d or 999) > (Config.AwareRange or 60) then


        return false
    end
    if useSpecial() then
        if paroled then memDudParole(key, true) end
        return true
    end
    return false
end

function tryUseSkill(t, d)
    if not Config.UseSkills then return false end
    local now = tick()
    if now - Bot.LastSkill < Config.SkillDelay then return false end
    if inOwnMove() then return false end
    if not t then return false end


    local d2d = getDist2D(getHRP() and getHRP().Position, getHRP(t) and getHRP(t).Position)
    if not d2d then return false end

    if now < (Bot.RecoverUntil or 0) then return false end

    local swingLive = (Config.SwingCastGate or 0) > 0 and (now - (Bot.LastSwingAt or 0)) < (Config.SwingCastGate or 0.5)






    local cands = {}
    local usable = getUsableMoves()
    for _, entry in ipairs(usable) do
        if shouldUseMove(entry, t, d2d) then
            if swingLive and castGate(entry.rule, entry.name) then
                debugEvery("castgate", 3, string.format("cast held: %s (%.1f s cast) into a live string",
                    entry.name, castGate(entry.rule, entry.name)))
            else
                table.insert(cands, { e = entry })
            end
        end
    end









    if Config.DudParole and now - (Bot.ParoleScanAt or 0) > Config.RangeProbeEvery then
        Bot.ParoleScanAt = now
        for _, entry in ipairs(usable) do
            local rule = entry.rule
            if not rule.cc and not rule.escape and not rule.summon and not rule.selfBuff
               and d2d >= (rule.min or 0) and d2d <= (rule.max or 0)
               and isSkillReady(entry.service) and memIsHardDud(entry.name)
               and memDudParole(entry.name, false) and useSkill(entry.service) then
                memDudParole(entry.name, true)
                Bot.LastSkill = now
                return true
            end
        end
    end



    local maxDpt = memMaxDpt((function()
        local names = {}
        for _, c in ipairs(cands) do table.insert(names, c.e) end
        return names
    end)(), t)























    if #cands == 0 and Config.RangeProbe and not swingLive
       and now - (Bot.LastProbe or 0) > Config.RangeProbeEvery
       and d2d <= Config.RangeProbeMax then
        local probes = {}
        for _, entry in ipairs(getUsableMoves()) do
            local rule = entry.rule
            if isSkillReady(entry.service) and not rule.summon and not rule.selfBuff
               and not rule.escape and memRangeEdgeProbe(entry.name, d2d)
               and not memIsHardDud(entry.name) and not rule.cc
               and d2d <= (rule.max or 40) + 15 then
                table.insert(probes, entry)
            end
        end
        if #probes > 0 and math.random() < Config.RangeProbeChance then
            local pick = probes[math.random(1, #probes)]
            Bot.LastProbe = now
            if useSkill(pick.service) then
                if Config.DebugSense then
                    debug(string.format("probing %s at %.0f studs (table says %d-%d)",
                        pick.name, d2d, pick.rule.min, pick.rule.max))
                end
                Bot.LastSkill = now
                return true
            end
        end
    end

    local names = {}
    for _, c in ipairs(cands) do table.insert(names, c.e) end
    local maxChain = memMaxChain(names)





    local live = {}
    for _, c in ipairs(cands) do
        if not memIsDud(c.e.name, maxDpt) then table.insert(live, c) end
    end
    if #live > 0 then cands = live end






    local keep = {}
    for _, c in ipairs(cands) do
        if not memIsHardDud(c.e.name) then table.insert(keep, c) end
    end
    cands = keep





    if d2d <= Config.M1Range + 2 then
        local strong = {}
        for _, c in ipairs(cands) do
            local r = c.e.rule
            local dpt, tries = memMoveStats(c.e.name, t)
            if r.cc or r.heavy or r.grab or r.trap or r.counter or r.escape or r.summon
               or not dpt or (tries or 0) < math.max(8, Config.MemMinSamples)
               or dpt >= (Config.MeleeSkillFloor or 1.0) then
                table.insert(strong, c)
            end
        end
        cands = strong
    end

    for _, c in ipairs(cands) do






        local setup = memSetupValue(c.e.name)
        local setupBonus = 1
        if maxDpt and maxDpt > 0 and setup > 0 then
            setupBonus = 1 + math.clamp(setup / maxDpt, 0, 1) * Config.SetupWeight
        end

        c.score = (10 - c.e.rule.prio)
                  * memMoveWeight(c.e.name, t, maxDpt)
                  * memChainWeight(c.e.name, maxChain)
                  * setupBonus
    end
    table.sort(cands, function(a, b) return a.score > b.score end)

    for _, c in ipairs(cands) do
        local entry = c.e

        if not memComboHold(entry.name, entry.rule, t) then



            if useSkill(entry.service) then return true end
        end
    end

    return false
end

























function senseSwingerNear(range)


    Bot.DefendVsSwinging = false
    if not Config.UseBlock or not AnimMapReady then Bot.DefendVs = nil; return nil end
    if isInSkill() then Bot.DefendVs = nil; return nil end
    local now = tick()
    local h = getHRP()
    if not h then Bot.DefendVs = nil; return nil end
    local myPos = h.Position

    local cur = Bot.DefendVs
    if cur then
        local ch = cur.Parent and getHRP(cur)
        local capAt = (Bot.DefendVsSince or now) + (Config.DefendVsMax or 1.6)

        if ch and now < (Bot.DefendVsUntil or 0) and now < capAt
           and (ch.Position - myPos).Magnitude <= range + 3 then
            local sw, nm = false, nil
            if isTargetFacingUs(cur) then sw, nm = senseMeleeSwing(cur) end
            if sw then
                Bot.DefendVsSwinging = true
                Bot.LastSwingAt = now
                Bot.LastSwinger = cur
                Bot.DefendVsUntil = now + (Config.DefendLatch or 0.6)

                if nm ~= Bot.SwingName then Bot.BlockSwings = (Bot.BlockSwings or 0) + 1 end
            end
            Bot.SwingName = sw and nm or nil
            return cur
        end


        Bot.DefendVs = nil
        if now >= capAt then Bot.DefendVsRest = now + (Config.DefendCapRest or 0.3) end
    end
    if now < (Bot.DefendVsRest or 0) then return nil end





    if not Bot.BlockActive and now - (Bot.BlockReleasedAt or 0) < (Config.DefendCapRest or 0.3) then return nil end

    local best, bestD, bestSwing = nil, range, nil
    local me = getChar()
    for _, c in ipairs(Bot.HitCandidates or {}) do
        if c ~= me and c.Parent then
            local ch = getHRP(c)
            local dd = ch and (ch.Position - myPos).Magnitude
            if dd and dd < bestD and isAlive(c) then
                local p = Players:GetPlayerFromCharacter(c)


                local friend = p and (isAlly(p.Name)
                                      or (p.Team ~= nil and p.Team == LocalPlayer.Team)
                                      or (isIgnoredPlayer(p.Name) and Bot.Aggressor ~= c))
                if not friend and isTargetFacingUs(c) then
                    local sw, nm = senseMeleeSwing(c)
                    if sw then best, bestD, bestSwing = c, dd, nm end
                end
            end
        end
    end
    if best then
        Bot.DefendVs = best
        Bot.DefendVsSince = now
        Bot.DefendVsUntil = now + (Config.DefendLatch or 0.6)
        Bot.DefendVsSwinging = true
        Bot.LastSwingAt = now
        Bot.LastSwinger = best
        Bot.BlockSwings, Bot.SwingName = (Bot.BlockSwings or 0) + 1, bestSwing






        Bot.DefendStrings = (Bot.DefendStrings or 0) + 1
        debugEvery("defend:" .. best.Name, 0.2, string.format("DEFEND: %s (%s:%s) swinging at us from %.0f studs%s | latch %d",
            best.Name, tostring(best:GetAttribute("Moveset")), tostring(bestSwing), bestD,
            best ~= Bot.Target and " - not our target" or "", Bot.DefendStrings))
    end
    return best
end







function shouldBlock(t, d)
    if not t then return false end
    if isInSkill() then return false end
    if d > Config.BlockRange then return false end

    local facing = isTargetFacingUs(t)







    if facing and d <= (Config.BlockMeleeRange or 12) and senseMeleeSwing(t)
       and (Bot.BlockActive or (tick() - (Bot.BlockReleasedAt or 0)) > (Config.DefendCapRest or 0.3)) then
        return true
    end








    if Bot.BlockActive and Bot.BlockHeld and tick() < (Bot.BlockUntil or 0) and d <= Config.BlockRange
       and Bot.BlockTarget == t then
        return true
    end

    if tick() - Bot.LastBlock < Config.BlockCooldown then return false end

    local incoming = isTargetAttacking(t)
    local hp = getHPPct()


    if incoming and facing then return true end


    if countNearbyEnemies(14) >= 2 and facing and math.random() < 0.5 * (Bot.FrameDelta or 0.016) then
        return true
    end




    if hp < Config.BlockHP and facing and math.random() < Config.BlockChance * (Bot.FrameDelta or 0.016) then
        return true
    end

    return false
end








local FF_LOCOMOTION = {
    idle = true, walk = true, run = true, jump = true, fall = true, climb = true,
}


function ffAnimMove(c)
    local mv = senseAnimMove(c)
    if not mv then return nil end
    if string.find(mv, "Victim") or string.find(mv, "Hit") then return nil end
    if FF_LOCOMOTION[string.lower(mv)] then return nil end
    return mv
end



function ffBuildCrowd(myPos)
    Bot.Crowd = {}
    if not myPos then return end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and isValidTarget(pl.Character) then
            local ch = getHRP(pl.Character)
            if ch and getDist2D(ch.Position, myPos) <= Config.CrowdRange then
                table.insert(Bot.Crowd, pl.Character)
            end
        end
    end
end

function scoreCandidate(c, myPos)
    local ch = getHRP(c)
    if not ch then return nil end

    local d = getDist(myPos, ch.Position)
    if d > Config.ScoreRange then return nil end

    local d2d = getDist2D(myPos, ch.Position)
    local dy  = math.abs(getDistY(myPos, ch.Position))















































    local liveWin = Config.LevelHitterWindow and (Config.LevelHitterMax or 4) or nil
    local live = hitterLive(c, liveWin) and d2d <= (Config.AwareRange or 60)
    if dy > (Config.LevelTolerance or 10) then
        if Bot.OffLevelSeen then Bot.OffLevelSeen[c] = tick() end
        if c == Bot.Target then
            Bot.TargetOffLevelSince = Bot.TargetOffLevelSince or tick()



            local above = getDistY(myPos, ch.Position) < 0
            local grace = (above and d2d <= (Config.LevelAirRange or 30)) and (Config.LevelGraceAbove or 2.5)
                          or (Config.LevelGrace or 0.6)
            if tick() - Bot.TargetOffLevelSince > grace then
                if live and (tick() - Bot.TargetOffLevelSince) <= (Config.LevelHitterMax or 4) then
                    debugEvery("offlevel-hitter", 5, string.format("%s is %.0f studs %s us but hitting us - keeping them",
                        c.Name, dy, above and "above" or "below"))
                else
                    if live then
                        Bot.BadTargets[c] = tick()
                        debugEvery("offlevel-cap", 5, string.format("%s has hit us from %.0f studs %s for %.0fs - unreachable, written off for %ds",
                            c.Name, dy, above and "above" or "below", tick() - Bot.TargetOffLevelSince,
                            Config.TargetBlacklistTime or 8))
                    end


                    local agg, why = Bot.Aggressor, "no aggressor"
                    if live then
                        why = "written off"
                    elseif agg == c then
                        local ago = tick() - (Bot.AggressorAt or 0)
                        if ago < (liveWin or 3) and d2d > (Config.AwareRange or 60) then
                            why = string.format("hitting us from %.0f studs out", d2d)
                        else
                            why = string.format("no hit for %.1fs", ago)
                        end
                    elseif agg then
                        why = "aggressor now " .. tostring(agg.Name)
                    end
                    debugEvery("offlevel", 3, string.format("%s is %.0f studs %s us - not our level, dropping (%s)",
                        c.Name, dy, above and "above" or "below", why))
                    return nil
                end
            end
        elseif not live then
            return nil
        end
    elseif c == Bot.Target then
        Bot.TargetOffLevelSince = nil
    elseif not live and not levelEntryOk(c, ch, dy) then
        return nil
    end



    if c ~= Bot.Target and Bot.ChaseDroppedAt
       and (tick() - Bot.ChaseDroppedAt) < (Config.ChaseCalm or 15)
       and d2d > (Config.ChaseCalmDist or 90) then
        return nil
    end

    local W = Config.W
    local terms = {}


    terms.threat = math.clamp(threatOf(c) / Config.ThreatRef, 0, 1)


    local proxScale = math.max(Config.CrowdRange or 55, 1)
    terms.prox = math.clamp(1 - (d2d / proxScale), 0, 1)


    local hp = getHPPct(c)
    terms.finish = math.clamp((100 - hp) / 100, 0, 1) ^ 1.6


    local los = hasLineOfSight(c) and 1 or 0
    local heightOK = (dy <= Config.VerticalRepos) and 1 or (dy <= 30 and 0.35 or 0)
    terms.reach = (los * 0.55) + (heightOK * 0.45)


    local facing = 0
    local toUs = myPos - ch.Position
    if toUs.Magnitude > 0.1 then
        local dot = toUs.Unit:Dot(ch.CFrame.LookVector)
        facing = math.clamp((dot - 0.2) / 0.8, 0, 1)
    end
    local moving = 0
    local mv = ffAnimMove(c)
    if mv then
        local rule = MoveRules[mv] or DefaultRule
        local reach = (rule.max or 40)
        moving = (d2d <= reach + 12) and 1 or 0.15
    elseif isInSkill(c) then
        moving = 0.7
    end
    terms.engage = math.max(facing, moving)


    local friends = 0
    for _, o in ipairs(Bot.Crowd) do
        if o ~= c then
            local oh = getHRP(o)
            if oh and getDist2D(oh.Position, ch.Position) <= Config.AoEClusterRange then
                friends = friends + 1
            end
        end
    end
    terms.crowd = math.clamp(friends / 3, 0, 1)


    terms.matchup = memMatchupPenalty(c)

    local score =
          W.threat * terms.threat
        + W.prox   * terms.prox
        + W.finish * terms.finish
        + W.reach  * terms.reach
        + W.engage * terms.engage
        - W.crowd  * terms.crowd
        - (W.matchup or 0) * terms.matchup

    if c == Bot.Target then
        score = score + W.commit
    end


    local best, bestV = "weak", 0
    for _, k in ipairs({ "threat", "prox", "finish", "reach", "engage" }) do
        local contrib = W[k] * terms[k]
        if contrib > bestV then bestV, best = contrib, k end
    end

    return {
        char = c, name = c.Name, score = score,
        dist = d, d2d = d2d, hp = hp,
        why = best, terms = terms, friends = friends,
    }
end

function rankTargets()
    local myH = getHRP()
    if not myH then return {} end
    local myPos = myH.Position

    local list = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and isValidTarget(pl.Character) then
            local s = scoreCandidate(pl.Character, myPos)
            if s then table.insert(list, s) end
        end
    end
    if not Config.PlayersOnly or soloServer() then
        for _, c in ipairs(getChars()) do
            if not Players:GetPlayerFromCharacter(c) and isValidTarget(c) then
                local s = scoreCandidate(c, myPos)
                if s then table.insert(list, s) end
            end
        end
    end

    table.sort(list, function(a, b) return a.score > b.score end)
    return list
end




















local Team = { plan = nil, lastSync = 0, fails = 0, started = false }



-- Solo build: the team bridge (teamPost / teamReport / teamStart) is gone.
-- teamPlan() below always answers nil, so no role, formation or follow
-- logic ever engages and the bot fights alone.

function teamPlan()
    if not Config.Team or not Team.plan then return nil end
    if tick() - Team.lastSync > Config.TeamStaleAfter then return nil end
    return Team.plan
end




function teamLastMove()
    local p = teamPlan()
    return p and p.teamLastMove or nil
end














function rotFlat(v, deg)
    local r = math.rad(deg)
    local c, sn = math.cos(r), math.sin(r)
    return Vector3.new(v.X * c - v.Z * sn, 0, v.X * sn + v.Z * c)
end







function teamWingSide()
    local p = teamPlan()
    if not (p and Config.TeamSpread and Bot.TeamFollow) then return 0 end



    local w = tonumber(p.wing)
    if w and w ~= 0 then return (w < 0) and -1 or 1 end

    local names = { LocalPlayer.Name }
    for _, a in ipairs(p.allies or {}) do
        if a.name and a.name ~= Bot.TeamFollow and a.name ~= LocalPlayer.Name then
            table.insert(names, a.name)
        end
    end
    table.sort(names)
    local rank = 0
    for i, n in ipairs(names) do
        if n == LocalPlayer.Name then rank = i - 1 end
    end
    return (rank % 2 == 0) and -1 or 1
end


function teamAllyTarget(name)
    local p = teamPlan()
    if not (p and p.allies) then return nil end
    for _, a in ipairs(p.allies) do
        if a.name == name then return a.target end
    end
    return nil
end





















function teamApproachPoint(targetPos, myPos)
    local p = teamPlan()
    if not (p and Config.TeamSpread and (p.of or 1) > 1) then return targetPos end
    local close = myPos ~= nil and getDist2D(myPos, targetPos) <= Config.TeamRingMinDist
    local goal = targetPos
    local side = teamWingSide()
    if side ~= 0 then
        local lead = Players:FindFirstChild(Bot.TeamFollow)
        local lh = lead and lead.Character and getHRP(lead.Character)
        if lh then
            local axis = Vector3.new(targetPos.X - lh.Position.X, 0, targetPos.Z - lh.Position.Z)
            if axis.Magnitude > 1 then




                local r = close and math.max(Config.M1Range - 2, 3) or (Config.M1Range + Config.TeamRingSlack)
                local ang = (Bot.TeamRole == "GUARD") and (Config.GuardWingAngle or 40) or (Config.TeamWingAngle or 70)
                local back = rotFlat(-axis.Unit, side * ang)
                goal = targetPos + back * r
            end
        end
    end



    local hold = Bot.LaneHold
    if hold and hold.axis and Bot.State == "APPROACH_FAR" and (tick() - (hold.at or 0)) < 1.5 then
        if not hold.goal and myPos then
            local perp = hold.axis:Cross(Vector3.new(0, 1, 0))
            hold.goal = myPos + perp * (-hold.side) * (Config.LaneClearStep or 6) + hold.axis * 3
        end
        if hold.goal and myPos and getDist2D(myPos, hold.goal) > 1.5 then return hold.goal end
    end
    return goal
end




local function setTarget(c, now, why)
    now = now or tick()
    if Bot.Target ~= c then
        Bot.UsedSkillsThisFight = {}
        Bot.TargetOffLevelSince = nil
        Bot.AbandonUntil = 0
        Bot.FlankUntil = 0
        Bot.TargetHP = nil
        Bot.TargetHPTime = now
        Bot.TargetSince = now
        Bot.LastTargetSwitch = now
        if c then memNewEncounter(c) end
    end
    Bot.Target = c
    Bot.Contender = nil
    Bot.ContenderSince = 0
    Bot.UnreachableSince = 0
    if c and why and Config.DebugTarget then debug(why) end
end





function targetBlinking(c)
    if c == nil or not isAlive(c) or not hasIFrames(c) then return false end





    local now = tick()
    if Bot.BlinkTarget ~= c or (now - (Bot.BlinkLast or 0)) > 1 then
        Bot.BlinkTarget, Bot.BlinkSince = c, now
    end
    Bot.BlinkLast = now
    return (now - Bot.BlinkSince) < (Config.BlinkMax or 3)
end

















function hitterLive(c, window)
    if not c or Bot.Aggressor ~= c then return false end
    local now = tick()
    if (now - (Bot.AggressorAt or 0)) >= (window or 3) and now >= (Bot.InterceptUntil or 0) then return false end
    local bad = Bot.BadTargets[c]
    if bad and (now - bad) < (Config.TargetBlacklistTime or 8) then return false end
    return isAlive(c) and not isAllyName(c.Name)
end




function levelEntryOk(c, ch, dy)
    if dy > (Config.LevelTolerance or 10) - (Config.LevelEnterMargin or 3) then return false end
    local seen = Bot.OffLevelSeen and Bot.OffLevelSeen[c]
    if seen and (tick() - seen) < (Config.LevelReenter or 1.5) then return false end
    local vmax = Config.LevelLaunchVel or 60
    if vmax > 0 and ch and math.abs(ch.AssemblyLinearVelocity.Y) > vmax then return false end
    return true
end






















function hitterToAdopt(now)
    now = now or tick()
    local h = getHRP()
    if not h then return nil end














    local sw = Bot.LastSwinger
    if Config.AdoptSwinger and sw and sw.Parent
       and (now - (Bot.LastSwingAt or 0)) < (Config.AdoptSwingerWindow or 1.5)
       and isAlive(sw) and not isAllyName(sw.Name) then
        local sp = Players:GetPlayerFromCharacter(sw)
        local sbad = Bot.BadTargets[sw]
        local sh = getHRP(sw)
        local sd = sh and getDist2D(h.Position, sh.Position)
        if sd and sd <= (Config.AdoptSwingerRange or 12)
           and not (sp and isIgnoredPlayer(sp.Name))
           and not (sbad and (now - sbad) < (Config.TargetBlacklistTime or 8))
           and isTargetFacingUs(sw) then
            Bot.Aggressor, Bot.AggressorAt = sw, now
            debugEvery("swingadopt", 3, string.format("%s is swinging at us (%.0f studs) - taking them", sw.Name, sd))
            return sw
        end
    end
    if (now - (Bot.LastHurtAt or 0)) > 2 then return nil end
    local agg = Bot.Aggressor
    if agg and hitterLive(agg) then
        local ah = getHRP(agg)
        if ah and getDist2D(h.Position, ah.Position) <= (Config.AwareRange or 60) then return agg end
        return nil
    end
    if (Bot.LastFFAt or 0) >= (Bot.LastHurtAt or 0) then return nil end
    local best, bestD = nil, Config.ThreatRange or 45
    for _, c in ipairs(Bot.HitCandidates or {}) do
        if c ~= agg and isAlive(c) and not isAllyName(c.Name) then
            local p = Players:GetPlayerFromCharacter(c)
            local bad = Bot.BadTargets[c]
            if not (p and isIgnoredPlayer(p.Name))
               and not (bad and (now - bad) < (Config.TargetBlacklistTime or 8))
               and (isValidTarget(c) or hasIFrames(c)) then
                local ch = getHRP(c)
                local dd = ch and getDist2D(h.Position, ch.Position)
                if dd and dd < bestD and isTargetFacingUs(c)
                   and (threatOf(c) > 0 or inOwnMove(c) or hasIFrames(c) or senseMeleeSwing(c)) then
                    best, bestD = c, dd
                end
            end
        end
    end
    if best then
        Bot.Aggressor, Bot.AggressorAt = best, now
        debugEvery("hitterguess", 3, string.format("%s is the likeliest hitter (facing us, %.0f studs) - taking them", best.Name, bestD))
    end
    return best
end

local function updateTarget()
    local now = tick()

    local myH = getHRP()
    ffBuildCrowd(myH and myH.Position)

    local scoreDue = (now - (Bot.LastScoreAt or 0)) >= Config.ScoreEvery


    if Bot.LockMode == "MANUAL" and Bot.LockedName then
        local pl = Players:FindFirstChild(Bot.LockedName)
        local c = pl and pl.Character
        if c and isValidTarget(c) then
            if Bot.Target ~= c then setTarget(c, now); debug("LOCKED onto " .. Bot.LockedName) end
            if scoreDue then Bot.LastScoreAt = now; Bot.Scores = rankTargets() end
            return
        else
            debug("lock target " .. tostring(Bot.LockedName) .. " is gone - back to AUTO")
            Bot.LockMode = "AUTO"; Bot.LockedName = nil
            Bot.Target = nil; Bot.Contender = nil
        end
    end







































    local ownTarget = Bot.TeamRole ~= "SUPPORT" and Bot.TeamRole ~= "PEEL" and Bot.TeamRole ~= "GUARD"
                      and not Bot.TeamFollowing
    if Bot.Target and Bot.State ~= "TEAMKITE" and ownTarget then
        local ch, th = getHRP(), getHRP(Bot.Target)
        if ch and th then
            local d = getDist2D(ch.Position, th.Position)
            if Bot.ChaseTarget ~= Bot.Target then
                Bot.ChaseTarget, Bot.ChaseSince, Bot.ChaseBest, Bot.ChaseDmg = Bot.Target, now, d, Life.dmg
            else
                if d < (Bot.ChaseBest or d) - (Config.ChaseProgress or 8) then
                    Bot.ChaseBest, Bot.ChaseSince = d, now
                end



                local traded = Life.dmg > (Bot.ChaseDmg or 0)
                               or (Bot.Aggressor == Bot.Target and Bot.AggressorAt and now - Bot.AggressorAt < 2)
                if traded then Bot.ChaseDmg, Bot.ChaseSince, Bot.ChaseBest = Life.dmg, now, d end
                if d > (Config.ChaseGiveUpDist or 90)
                   and now - (Bot.ChaseSince or now) > (Config.ChaseGiveUpTime or 12) then


                    Bot.BadTargets[Bot.Target] = now + (Config.ChaseBlacklist or 45)
                                                     - (Config.TargetBlacklistTime or 8)
                    debug(string.format("chase stalled: %s at %.0f studs, no progress for %.0fs - dropping them for %ds",
                        Bot.Target.Name, d, now - Bot.ChaseSince, Config.ChaseBlacklist or 45))
                    Bot.Target = nil
                    Bot.Contender = nil
                    Bot.ChaseTarget = nil
                    Bot.ChaseDroppedAt = now
                    Bot.UsedSkillsThisFight = {}
                end
            end
        end
    else
        Bot.ChaseTarget = nil
    end

    local tp = teamPlan()



    if not tp then Bot.TeamRole, Bot.TeamRunTo, Bot.TeamFollow, Bot.TeamFollowing, Bot.TeamFollowRadius = nil, nil, nil, false, nil end
    if not tp then Bot.KiteArrived, Bot.TeamClosing, Bot.InterceptUntil, Bot.InterceptDmg = false, nil, 0, 0 end
    if tp then
        Bot.TeamRole    = tp.role
        if tp.role ~= "KITE" then Bot.KiteArrived = false end
        Bot.TeamRunTo   = tp.regroupTo
        Bot.TeamNearAlly = tp.nearestAlly
        Bot.TeamFollow   = tp.followAlly

        Bot.TeamFollowRadius = tonumber(tp.followRadius) or nil


















        if tp.role == "KITE" then
            Bot.TeamRunTo = tp.roleTarget or tp.regroupTo




            if not Bot.KiteArrived then
                if Bot.Target then setTarget(nil, now, tp.role:lower() .. ": " .. tostring(tp.roleWhy)) end
                if scoreDue then Bot.LastScoreAt = now; Bot.Scores = rankTargets() end
                return
            end
        end










        local want = (tp.role ~= "KITE") and tp.roleTarget or nil




        local agg = Bot.Aggressor
        local aggBad = agg and Bot.BadTargets[agg]
                       and (tick() - Bot.BadTargets[agg]) < Config.TargetBlacklistTime



        local aggOk = agg and agg.Name and not isAlly(agg.Name) and not aggBad
                      and (isValidTarget(agg) or (isAlive(agg) and hasIFrames(agg)))


        if aggOk and Bot.Target == agg and Life.dmg > (Bot.InterceptDmg or 0) then
            Bot.InterceptUntil = tick() + 3
        end
        Bot.InterceptDmg = Life.dmg
        local aggLive = aggOk and ((tick() - (Bot.AggressorAt or 0)) < 3
                                   or tick() < (Bot.InterceptUntil or 0))


        if want and aggLive and agg.Name ~= want then
            local wpl = Players:FindFirstChild(want)
            local wh = wpl and wpl.Character and getHRP(wpl.Character)
            local mh = getHRP()
            if wh and mh and getDist2D(mh.Position, wh.Position) > (Config.InterceptDist or 60) then
                debugEvery("intercept", 4, string.format("intercept: %s is on us while %s is %.0f studs out",
                    agg.Name, want, getDist2D(mh.Position, wh.Position)))
                want = agg.Name
            end
        end
        if want then
            local fpl = Players:FindFirstChild(want)
            local fc = fpl and fpl.Character
            local fcBad = fc and Bot.BadTargets[fc]
                          and (tick() - Bot.BadTargets[fc]) < Config.TargetBlacklistTime
            local fcOk = fc and (isValidTarget(fc)
                          or (targetBlinking(fc) and not fcBad and not (fpl and isAlly(fpl.Name))))


            local fcLevelOk = true
            do
                local myH3, fH3 = getHRP(), fc and getHRP(fc)
                if myH3 and fH3 then
                    local dyT = getDistY(myH3.Position, fH3.Position)
                    if math.abs(dyT) > (Config.LevelTolerance or 10) then
                        if Bot.OffLevelSeen then Bot.OffLevelSeen[fc] = tick() end

                        if Bot.TeamOffLevelName ~= want then Bot.TeamOffLevelSince, Bot.TeamOffLevelName = nil, want end
                        Bot.TeamOffLevelSince = Bot.TeamOffLevelSince or tick()
                        local near = getDist2D(myH3.Position, fH3.Position) <= (Config.LevelAirRange or 30)
                        local grace = (dyT < 0 and near) and (Config.LevelGraceAbove or 2.5) or (Config.LevelGrace or 0.6)
                        if tick() - Bot.TeamOffLevelSince > grace then fcLevelOk = false end



                        if not fcLevelOk and hitterLive(fc)
                           and getDist2D(myH3.Position, fH3.Position) <= (Config.AwareRange or 60) then
                            fcLevelOk = true
                        end
                    else
                        Bot.TeamOffLevelSince = nil





                        if fc ~= Bot.Target and not hitterLive(fc) and not levelEntryOk(fc, fH3, math.abs(dyT)) then
                            fcLevelOk = false
                        end
                    end
                end
            end
            if not fcLevelOk then fcOk = false end





            local farCut = Config.MaxTargetDist3D or 1500
            if fc and farCut > 0 then
                local myH5, fH5 = getHRP(), getHRP(fc)
                local fd = (myH5 and fH5) and (fH5.Position - myH5.Position).Magnitude
                if fd and fd > farCut then
                    fcOk, fcLevelOk = false, false
                    local fbad = Bot.BadTargets[fc]
                    if fH5.Position.Magnitude > myH5.Position.Magnitude
                       and not (fbad and (tick() - fbad) < Config.TargetBlacklistTime) then
                        Bot.BadTargets[fc] = tick()
                        debugEvery("far3d", 5, string.format("%s is %.0f studs away (another space) - dropped", fc.Name, fd))
                    end
                end
            end
            if fcOk then
                local myH2, fH = getHRP(), getHRP(fc)

















                if myH2 and fH and getDist(myH2.Position, fH.Position) <= Config.SeekRange then
                    if Bot.Target ~= fc then
                        setTarget(fc, now, string.format("team %s: %s",
                            tostring(tp.role), tostring(tp.roleWhy)))
                    end
                    if scoreDue then Bot.LastScoreAt = now; Bot.Scores = rankTargets() end
                    return
                end
            end





















            local peelBad = Bot.BadTargets[fc]
                            and (tick() - Bot.BadTargets[fc]) < Config.TargetBlacklistTime
            if tp.role == "PEEL" and fc and isAlive(fc)
               and not (fpl and isAlly(fpl.Name)) and not peelBad and fcLevelOk then
                if Bot.Target ~= fc then
                    setTarget(fc, now, "peel hold: " .. tostring(tp.roleWhy))
                end
                if scoreDue then Bot.LastScoreAt = now; Bot.Scores = rankTargets() end
                return
            end
        end
    end





    if Bot.Target and not isValidTarget(Bot.Target) and not targetBlinking(Bot.Target)
       and not hitterLive(Bot.Target) then
        if not isAlive(Bot.Target) then
            Bot.Kills = Bot.Kills + 1
            memNoteKill(Bot.Target)
            debug("Kill! Total: " .. Bot.Kills)
        end
        Bot.Target = nil
        Bot.Contender = nil
        Bot.UnreachableSince = 0
        Bot.UsedSkillsThisFight = {}
    end

    if not scoreDue then return end
    Bot.LastScoreAt = now

    local ranked = rankTargets()
    Bot.Scores = ranked

    if #ranked == 0 then


        if targetBlinking(Bot.Target) then return end







        local hitter = hitterToAdopt(now)
        if hitter then
            if Bot.Target ~= hitter then
                setTarget(hitter, now, string.format("hitter: %s (nobody else to pick)", hitter.Name))
            end
            return
        end
        if Bot.Target then debug("no valid targets") end
        Bot.Target = nil; Bot.Contender = nil
        return
    end

    local top = ranked[1]



    if not Bot.Target or (not isValidTarget(Bot.Target) and not targetBlinking(Bot.Target)) then
        setTarget(top.char, now, string.format(
            "target: %s (%.0f, %s)", top.name, top.score, top.why))
        return
    end


    local holder = nil
    for _, s in ipairs(ranked) do
        if s.char == Bot.Target then holder = s break end
    end
    if not holder then
        if targetBlinking(Bot.Target) then return end


        if hitterLive(Bot.Target) and not isValidTarget(Bot.Target) then return end
        setTarget(top.char, now, string.format(
            "re-acquire: %s (%.0f, %s)", top.name, top.score, top.why))
        return
    end


    local unreachable = (holder.terms.reach < 0.35)
    if unreachable and (Bot.Attackers or 0) > 0 then
        if (Bot.UnreachableSince or 0) == 0 then
            Bot.UnreachableSince = now
        elseif now - Bot.UnreachableSince > Config.DropUnreachable then
            local alt = nil
            for _, s in ipairs(ranked) do
                if s.char ~= Bot.Target and s.terms.reach >= 0.5 then alt = s break end
            end
            if alt then
                debug(string.format("cannot reach %s while %d on us -> %s",
                    holder.name, Bot.Attackers or 0, alt.name))
                setTarget(alt.char, now)
                return
            end
        end
    else
        Bot.UnreachableSince = 0
    end

    if top.char == Bot.Target then
        Bot.Contender = nil
        return
    end


    local need = math.max(holder.score * Config.SwitchRatio,
                          holder.score + Config.SwitchAbs)
    if top.score > need then
        if Bot.Contender ~= top.char then
            Bot.Contender = top.char
            Bot.ContenderSince = now
        elseif now - (Bot.ContenderSince or 0) >= Config.SwitchHold then
            setTarget(top.char, now, string.format(
                "switch: %s (%.0f) -> %s (%.0f, %s)",
                holder.name, holder.score, top.name, top.score, top.why))
        end
    else
        Bot.Contender = nil
    end
end


local function updateState()
    if not isAlive() then
        Bot.State = "DEAD"
        stopM1()
        return
    end




    local prev = Bot.State


    if prev ~= "REACT" then Bot.ReactPrevMelee = false end
    local inMeleeState = (prev == "ATTACK" or prev == "FLANK" or prev == "DEFEND")
                         or (prev == "REACT" and Bot.ReactPrevMelee == true)
    local leaveMargin = inMeleeState and (Config.RangeHyst or 0) or 0

    local hp = getHPPct()

    updateTarget()














    if Bot.TeamRole == "KITE" and Bot.TeamRunTo and not Bot.KiteArrived then
        Bot.State = "TEAMKITE"
        stopM1()
        return
    end











    if Bot.TeamRole == "BREAK" then
        Bot.State = "RETREAT"
        stopM1()
        return
    end

    local t = Bot.Target
    local d = 0
    if t then
        local _h = getHRP()
        local _th = getHRP(t)
        if _h and _th then d = getDist(_h.Position, _th.Position) end
    end














    Bot.Reacting = nil
    Bot.ReactMove = nil
    Bot.ReactSoft = false

    if senseGrabbed() then
        Bot.State = "REACT"
        Bot.Reacting = "grabbed"
        Bot.ReactPrevMelee = inMeleeState
        return
    end

    local myH = getHRP()
    local haz = myH and senseHazard(myH.Position)


    local alane = myH and senseAllyLane(myH.Position) or nil
    if not haz and alane then
        haz = alane
        Bot.ReactSoft = true
        debugEvery("allylane", 2, string.format("clearing %s's %s (%s, %.1f studs in)",
            tostring(alane.ally), tostring(alane.move), tostring(alane.shape), alane.dist or 0))
    elseif haz then
        Bot.ReactSoft = false
    end
    if haz then
        Bot.State = "REACT"
        Bot.Reacting = "dodge"
        Bot.ReactPrevMelee = inMeleeState




        local nd = haz.dir


        local sameKind = (Bot.ReactSoft == Bot.ReactSoftPrev)
        if sameKind and Bot.ReactDir and (tick() - (Bot.ReactDirAt or 0)) < (Config.DodgeLatch or 0.8)
           and nd and nd:Dot(Bot.ReactDir) < 0 then
            nd = Bot.ReactDir
        end
        if nd ~= Bot.ReactDir then Bot.ReactDirAt = tick() end
        Bot.ReactDir = nd
        Bot.ReactSoftPrev = Bot.ReactSoft
        return
    end

    if t then
        local move, kind = senseThreatMove(t)















        if move then
            local rule = MoveRules[move] or DefaultRule
            local reach = (rule.max or 40) + Config.ReactMargin
            local dy = math.abs(Bot.DistY or 0)






            local farDist = Bot.Dist2D or d or 0
            if farDist > reach or dy > reach * 0.5 then
                move = nil
                if Config.DebugSense then
                    debugEvery("farmove:" .. tostring(kind), 4, string.format(
                        "ignoring their %s - reaches %.0f, we are %.0f away",
                        tostring(kind), reach, farDist))
                end
            end
        end

        if move then
            Bot.State = "REACT"
            Bot.ReactPrevMelee = inMeleeState
            Bot.Reacting = memBestReaction(move, DangerPlan[kind] or "block", kind)
            Bot.ReactMove = move
            Bot.ReactKind = kind
            return
        end
    end

    if not t then
        if Bot.State ~= "IDLE" then
            stopM1()
            stopWalking()
        end
        Bot.State = "IDLE"
        Bot.Target = nil


















        if Config.MapMemory and Config.Roam then
            local h2 = getHRP()
            if h2 then
                local goal, why = nil, nil








                if Bot.SeekChar and Bot.SeekChar.Parent
                   and (Bot.Attackers or 0) == 0 then
                    local sh = getHRP(Bot.SeekChar)
                    if sh then goal, why = sh.Position, "seek" end
                end

                if not goal and tick() > (Bot.HuntGoalAt or 0) then
                    Bot.HuntGoalAt = tick() + 4
                    Bot.HuntGoal = mapBestHunt(h2.Position)
                    if not Bot.HuntGoal then
                        Bot.HuntGoal = mapFrontier(h2.Position)
                        Bot.HuntWhy = "explore"
                    else
                        Bot.HuntWhy = "roam"
                    end
                end

                if not goal and Bot.HuntGoal then
                    goal, why = Bot.HuntGoal, Bot.HuntWhy
                end

                if goal then

                    if not mapNavProgress(h2.Position, goal) then
                        Bot.HuntGoal = nil
                        Bot.HuntGoalAt = 0
                        stopWalking()
                    elseif (h2.Position - goal).Magnitude > Config.MapCell then






                        walkTo(goal)

                        if Config.DebugMap and tick() - (Bot.RoamLog or 0) > 3 then
                            Bot.RoamLog = tick()
                            debug(string.format("%s -> %.0f studs away",
                                tostring(why), (goal - h2.Position).Magnitude))
                        end
                    else
                        Bot.HuntGoal = nil
                        Bot.HuntGoalAt = 0
                    end
                end
            end
        end
        return
    end



    Bot.Target = t
    Bot.TargetDist = d
    trackTargetHP(t)


    Bot.Plan = memPlanFor(t)






    local set = t and t:GetAttribute("Moveset")
    if set ~= Bot.EnemySet then
        Bot.EnemySet = set
        Bot.EnemyBand = memEnemyWorstBand(set)
        local rep = set and memEnemyReport(set)
        if rep and rep ~= "" then
            debugEvery("kit:" .. tostring(set), 8, set .. " vs us: " .. rep)
        end
    end


    if isAwakened() and (Bot.AwakenTries or 0) > 0 then
        Bot.AwakenTries = 0
    end

    local h = getHRP()
    if h then





















        if Bot.WalkGoal and Bot.WalkActive then
            local gd = getDist2D(h.Position, Bot.WalkGoal) or 0
            if Bot.StuckRef and (getDist2D(h.Position, Bot.StuckRef) or 0) < 1.5 then
                Bot.StuckTime = Bot.StuckTime + (Bot.FrameDelta or 0.016)
            elseif Config.StuckGoalProgress and Bot.GoalRefDist
                   and tick() - (Bot.GoalRefAt or 0) > (Config.StuckProgressWindow or 2.5)
                   and gd > Bot.GoalRefDist - (Config.StuckProgressDist or 3) then



                Bot.StuckTime = Bot.StuckTime + (Bot.FrameDelta or 0.016)
                Bot.StuckRef = h.Position
            else
                Bot.StuckTime = 0
                Bot.StuckRef = h.Position
            end


            if not Bot.GoalRefDist or not Bot.GoalRefGoal
               or (getDist2D(Bot.GoalRefGoal, Bot.WalkGoal) or 0) > 4
               or gd <= Bot.GoalRefDist - (Config.StuckProgressDist or 3) then
                Bot.GoalRefGoal = Bot.WalkGoal
                Bot.GoalRefDist = gd
                Bot.GoalRefAt = tick()
            end
        else
            Bot.StuckTime = 0
            Bot.StuckRef = h.Position
            Bot.GoalRefDist = nil
        end
    end


    local h0, th0 = getHRP(), getHRP(t)
    local d2d = getDist2D(h0 and h0.Position, th0 and th0.Position) or d
    local dy  = getDistY(h0 and h0.Position, th0 and th0.Position)
    Bot.Dist2D = d2d
    Bot.DistY = dy










    if Bot.Outnumbered and Bot.Losing and hp < Config.OutnumberedHP
       and not (getUltMeter() >= 100) and not (Bot.TeamRole == "KITE" and Bot.KiteArrived) then




        if tick() >= (Bot.GangedUntil or 0) then
            debugEvery("ganged", 3.0, string.format("ganged: %d attackers, taking %.1f/s vs dealing %.1f/s -> out",
                Bot.Attackers or 0, memLifeInRate(), memLifeRate()))
        end
        Bot.GangedUntil = tick() + (Config.GangedHold or 4)
    end































    local canGuard = hp >= Config.RetreatHP and tick() >= (Bot.PunishUntil or 0)
                     and tick() >= (Bot.GangedUntil or 0) + (Config.DefendGangedGrace or 1.0)










    if canGuard then Bot.DefendKeepVs = Bot.DefendVs; Bot.DefendKept = false end
    local keepVs = nil
    if not canGuard and Config.DefendUnderRetreat and Bot.DefendVs and Bot.DefendVs == Bot.DefendKeepVs
       and hp < Config.RetreatHP and tick() >= (Bot.PunishUntil or 0)
       and tick() >= (Bot.GangedUntil or 0) + (Config.DefendGangedGrace or 1.0)
       and tick() - (Bot.DefendVsSince or 0) < (Config.DefendKeepMax or 1.0) then
        local kh = Bot.DefendVs.Parent and getHRP(Bot.DefendVs)
        if kh and h0 and (getDist2D(h0.Position, kh.Position) or 99) <= (Config.DefendKeepRange or 8)
           and isTargetFacingUs(Bot.DefendVs) then
            keepVs = Bot.DefendVs
            Bot.DefendKept = true
        end
    end
    if not canGuard and Bot.DefendVs and not keepVs then
        local why
        if hp < Config.RetreatHP then
            if Bot.DefendKept then
                why = string.format("held to the string end (%.1f s at hp %.0f%%)", tick() - (Bot.DefendVsSince or 0), hp)
            else
                why = string.format("at hp %.0f%% < RetreatHP %.0f%%", hp, Config.RetreatHP)
            end
        elseif tick() < (Bot.PunishUntil or 0) then
            why = "punishing"
        elseif tick() < (Bot.GangedUntil or 0) then
            why = "in the ganged hold"
        else
            why = "just out of the ganged hold"
        end
        debugEvery("defend-run", 3, string.format("DEFEND dropped: %s swinging but we are %s - not stopping to block",
            tostring(Bot.DefendVs.Name), why))
        Bot.DefendVsRest = math.max(Bot.DefendVsRest or 0, tick() + (Config.DefendDropRest or 3))
        Bot.DefendVs = nil
        Bot.DefendVsSwinging = false
    end








    if math.abs(dy) > Config.VerticalRepos and d2d < Config.VerticalReposRange then
        Bot.State = "LEVEL"
    elseif math.abs(dy) > Config.MaxVertical and d2d < Config.PerchDist then


        Bot.State = "PERCHED"





        if prev ~= "PERCHED" or not Bot.PerchSide then
            Bot.PerchSide = (math.random() < 0.5) and 1 or -1
        end
        stopM1()
    elseif not isAwakened() and getUltMeter() >= 100 and shouldAwakenNow(hp) then
        Bot.State = "AWAKEN"
        stopM1()
    elseif Config.Throwables and senseHoldingThrowable() then
















        Bot.State = "THROW"
    elseif isStunned() or isRagdolled() then
        Bot.State = "CCED"
        stopM1()
    elseif canGuard and tick() < (Bot.RecoverUntil or 0) then











        if senseSwingerNear(Config.BlockRange or 13) or Bot.RecoverMode == "hold" then
            Bot.DefendKeepVs = Bot.DefendVs
            Bot.State = "DEFEND"
        else
            Bot.State = "REACT"
            Bot.Reacting = "recover"
            Bot.ReactPrevMelee = inMeleeState
        end
        stopM1()
        if not Bot.RecoverSaid then
            Bot.RecoverSaid = true
            Life.recoverN = (Life.recoverN or 0) + 1
            if Bot.State == "DEFEND" then Life.recoverDefend = (Life.recoverDefend or 0) + 1
            else Life.recoverAway = (Life.recoverAway or 0) + 1 end
            local who = Bot.DefendVs or t
            debugEvery("recover", 0.5, string.format("recover: %.1f s after the burst, %s vs %s (%.0f studs)",
                tick() - (Bot.BurstAt or 0), Bot.State == "DEFEND" and "guard" or "away",
                tostring(who and who.Name or "?"), Bot.Dist2D or 0))
        end
    elseif (canGuard or keepVs) and senseSwingerNear(Config.BlockMeleeRange or 12) then

















        if canGuard then Bot.DefendKeepVs = Bot.DefendVs end
        Bot.State = "DEFEND"
        stopM1()
    elseif tick() < (Bot.PunishUntil or 0) then
        Bot.State = "PUNISH"
    elseif hp < Config.RetreatHP
           and ((Bot.Plan and Bot.Plan.punishEarly
                 and (Bot.PursuitTime or 0) > Config.PursuitPatience * Config.MemLearnPursuit)
                or isBeingChased()) then

        Bot.PunishUntil = tick() + Config.PunishWindow
        Bot.PursuitTime = 0
        Bot.State = "PUNISH"
        debug("retreat failed, pursuer will not break off -> punishing")








    elseif tick() < (Bot.GangedUntil or 0)
           and not (getUltMeter() >= 100) and not (Bot.TeamRole == "KITE" and Bot.KiteArrived) then

























        Bot.State = "RETREAT"
        stopM1()


    elseif hp < Config.RetreatHP and not (getUltMeter() >= 100) and not (Bot.TeamRole == "KITE" and Bot.KiteArrived) then
        Bot.State = "RETREAT"
        stopM1()
    elseif Bot.Stalling and d2d > Config.M1Range and hp > Config.RetreatHP then







        if Config.DebugMap then
            debugEvery("stall", 3.0, string.format("STALLING (%.1f dmg/s) -> forcing commit", memLifeRate()))
        end
        Bot.State = "APPROACH"
    elseif targetIsFleeing(t) and d2d > Config.M1Range and d2d < 90 then

        Bot.State = "CHASE"
        stopM1()
    elseif d2d > Config.DashRange + ((prev == "APPROACH") and (Config.RangeHyst or 0) or 0) then
        Bot.State = "APPROACH_FAR"
        stopM1()
    elseif d2d > Config.M1Range + leaveMargin or math.abs(dy) > Config.MaxVertical then
        Bot.State = "APPROACH"
        stopM1()
    elseif tick() < Bot.FlankUntil then
        Bot.State = "FLANK"
        stopM1()
    elseif isTargetBlocking(t) and d2d < 14 then

        Bot.FlankUntil = tick() + Config.FlankTime; Bot.FlankDashed = false
        Bot.State = "FLANK"
        stopM1()
        debugEvery("flank", 2.0, "Target blocking -> flanking")
    elseif shouldBlock(t, d) then
        Bot.State = "DEFEND"
        stopM1()
    else
        Bot.State = "ATTACK"
    end
end

local function executeState()





    if Bot.BlockActive and Bot.BlockHeld then
        local mismatch = Bot.BlockTarget ~= guardTarget()
        if mismatch or (Bot.State ~= "DEFEND" and not (Bot.State == "REACT" and Bot.Reacting == "block")) then




            local swapped = mismatch and Bot.State == "DEFEND"
            releaseBlock()
            if swapped then Bot.BlockReleasedAt = 0 end
        end
    end


    tryBurst()

    Bot.FollowWalk = false









    if Bot.TeamRunTo and not (Bot.TeamRole == "KITE" and Bot.KiteArrived) then
        local ally = Players:FindFirstChild(Bot.TeamRunTo)
        local ac   = ally and ally.Character
        local ah   = ac and getHRP(ac)
        local h0   = getHRP()


        if ah and h0 and not allyReachable(h0, ah, Config.TeamFollowMaxDist or 300) then
            ah = nil
        end
        if ah and h0 then
            local kiting = (Bot.State == "TEAMKITE")


            local gap = getDist2D(h0.Position, ah.Position)
            local band = Config.TeamBand or 4
            if gap > Config.TeamRingMinDist then Bot.TeamClosing = true
            elseif gap < Config.TeamRingMinDist - band then Bot.TeamClosing = false end
            if kiting and Bot.TeamClosing == false then Bot.KiteArrived = true end



















            if Bot.TeamClosing and not (Bot.TeamFollowing and not kiting)
               and (kiting or not Bot.Target or not Config.RegroupYieldsToTarget) then



                if not kiting and tick() - (Bot.RegroupLogAt or 0) >= 5 then
                    Bot.RegroupLogAt = tick()
                    debugEvery("regroup", 5, string.format("regroup: closing on %s (%.0f studs)", ally.Name, gap))
                end
                navigateTo(ac, ah.Position)

                if kiting and hasLineOfSight(ac) then dashToward() end
            elseif kiting then
                stopWalking()
            end















            if kiting then return end
        elseif Bot.State == "TEAMKITE" then



            Bot.State = "RETREAT"
        end
    end













    if not Bot.TeamFollow then Bot.TeamFollowing, Bot.FollowYieldUntil, Bot.RejoinSince = false, 0, 0 end
    if Bot.TeamFollow and Bot.State ~= "TEAMKITE" then



        local leadName = Bot.TeamFollow
        local lead = Players:FindFirstChild(leadName)
        local lc = lead and lead.Character
        local lh = lc and getHRP(lc)
        local h2 = getHRP()
        if not (lh and h2) then Bot.TeamFollowing = false end










        if lh and h2 and not allyReachable(h2, lh, Config.TeamRejoinMaxDist or 400) then
            Bot.TeamFollowing = false
            lh = nil
        end
        if lh and h2 then



            local gap = getDist2D(h2.Position, lh.Position)
            local band = Config.TeamBand or 4
            local fr = Bot.TeamFollowRadius or Config.TeamFollowRadius
            if gap > fr then Bot.TeamFollowing = true
            elseif gap < fr - band then
                Bot.TeamFollowing = false



                if (Bot.RejoinSince or 0) > 0 then
                    debugEvery("rejoin", 1, string.format("rejoin: with %s after %.1fs (%.0f studs, %d dashes)",
                        tostring(leadName), tick() - Bot.RejoinSince, Bot.RejoinFrom or 0, Bot.RejoinDashes or 0))
                    Bot.RejoinSince = 0
                end
            end



















            local now0 = tick()
            local st0 = Bot.State
            local fighting = st0 == "REACT" or st0 == "DEFEND" or st0 == "ATTACK" or st0 == "FLANK"
                             or st0 == "PUNISH" or st0 == "RETREAT" or st0 == "CCED"
            local ah0 = Bot.Aggressor and Bot.Target == Bot.Aggressor and getHRP(Bot.Aggressor)
            local underFire = ah0 and (now0 - (Bot.AggressorAt or 0)) < 3
                              and getDist2D(h2.Position, ah0.Position) < Config.DashRange





            if not underFire and Bot.TeamFollowing and Config.RejoinSprintClear and (Config.RejoinHostileGap or 0) > 0 then
                for _, c in ipairs(Bot.HitCandidates or {}) do
                    local ch = c.Parent and getHRP(c)
                    local cd = ch and getDist2D(h2.Position, ch.Position)
                    if cd and cd <= (Config.RejoinHostileGap or 15) and not isAllyName(c.Name) then
                        underFire = true
                        debugEvery("rejoinheld", 3, string.format("rejoin held: %s at %.0f studs", c.Name, cd))
                        break
                    end
                end
            end
            if fighting or underFire then Bot.FollowYieldUntil = now0 + 1 end
            if Bot.TeamFollowing and not (fighting or underFire or now0 < (Bot.FollowYieldUntil or 0)) then
                Bot.FollowWalk = true
                navigateTo(lc, lh.Position)




















                if gap > (Config.RejoinDashGap or 66) then
                    if (Bot.RejoinSince or 0) == 0 then
                        Bot.RejoinSince, Bot.RejoinFrom, Bot.RejoinDashes = now0, gap, 0
                        debugEvery("rejoinstart", 1, string.format("rejoin: %s is %.0f studs out - running",
                            tostring(leadName), gap))
                    end
                    local every = Config.RejoinDashEvery or 4
                    if Bot.NavMode == "straight" and now0 - (Bot.RejoinDashAt or 0) >= every
                       and not (isStunned() or isRagdolled() or isInSkill()) then
                        local lv = h2.CFrame.LookVector
                        local face = Vector3.new(lv.X, 0, lv.Z)
                        local to = Vector3.new(lh.Position.X - h2.Position.X, 0, lh.Position.Z - h2.Position.Z)
                        if face.Magnitude > 0.05 and to.Magnitude > 1
                           and face.Unit:Dot(to.Unit) >= 0.85 and hasLineOfSight(lc) then
                            Bot.RejoinDashAt = now0
                            local ld = Bot.LastDash
                            dashToward()
                            if Bot.LastDash ~= ld then Bot.RejoinDashes = (Bot.RejoinDashes or 0) + 1 end
                        else

                            Bot.RejoinDashAt = now0 - every + 0.5
                        end
                    end
                end
                return
            end
        end
    end

    local t = Bot.Target
    if not t then









        if Bot.TeamNearAlly then
            local ally = Players:FindFirstChild(Bot.TeamNearAlly)
            local ac = ally and ally.Character
            local ah = ac and getHRP(ac)
            local h1 = getHRP()
            if ah and h1 and not allyReachable(h1, ah, Config.TeamFollowMaxDist or 300) then
                ah = nil
            end
            if ah and h1 then
                local gap = getDist2D(h1.Position, ah.Position)
                local band = Config.TeamBand or 4
                if gap > Config.TeamRingMinDist then Bot.TeamDrifting = true
                elseif gap < Config.TeamRingMinDist - band then Bot.TeamDrifting = false end
                if Bot.TeamDrifting then navigateTo(ac, ah.Position) end
            end
        end
        return
    end

    local h = getHRP()
    local th = getHRP(t)
    if not h or not th then return end

    local d = getDist(h.Position, th.Position)
    local d2d = getDist2D(h.Position, th.Position)
    local dy = getDistY(h.Position, th.Position)
    local now = tick()

    if not isAlive(t) then
        Bot.Kills = Bot.Kills + 1
        memNoteKill(t)
        debug("Kill! Total: " .. Bot.Kills)
        Bot.Target = nil
        Bot.UsedSkillsThisFight = {}
        stopM1()
        return
    end

    if Bot.State == "IDLE" or Bot.State == "DEAD" or Bot.State == "CCED" then
        return
    end

    if Bot.State == "FLANK" then



        if tryUseSkill(t, d) then
            Bot.FlankUntil = 0
            return
        end

        local fp = getFlankPos(t)


        if fp and probeBlocked(h.Position, fp) then
            local th0 = getHRP(t)
            if th0 then
                local r0 = th0.CFrame.RightVector
                local found = nil
                for _, alt in ipairs({ th0.Position + r0 * Config.FlankDist,
                                       th0.Position - r0 * Config.FlankDist }) do
                    if not probeBlocked(h.Position, alt) then found = alt break end
                end



                fp = found or th0.Position
            end
        end
        if fp then
            navigateTo(t, fp)


            local th2 = getHRP(t)
            if th2 then
                local toUs = (h.Position - th2.Position)
                if toUs.Magnitude > 0.1 then
                    local behind = toUs.Unit:Dot(th2.CFrame.LookVector) < -0.3
                    if behind and (getDist2D(h.Position, th2.Position) or 99) < 9 then
                        Bot.FlankUntil = 0
                        Bot.TargetHPTime = tick()
                    end
                end
            end
        end





        if fp and not Bot.FlankDashed and now - Bot.LastDash > Config.DashCooldown then
            Bot.FlankDashed = true
            local side = (fp - h.Position):Dot(h.CFrame.RightVector)
            if math.abs(side) < 0.5 then
                dashWorld(openSide(h))
            else
                dash(side >= 0 and "Right" or "Left")
            end
        end
        return
    end

    if Bot.State == "PUNISH" then

















        faceTarget(t, true)
        stopWalking()


        if useBestMove(t, "trap") then return end


        if targetIsCommitted(t) and d2d < 16 then
            if Config.UseBlock and (now - Bot.LastBlock) > Config.BlockCooldown then
                doBlock()
            end
            if useBestMove(t, "punish") then return end
        end


        if d2d < Config.ReverseDashRange
           and (now - (Bot.LastReverse or 0)) > 4.0 then
            Bot.LastReverse = now
            if dashToward() then
                Bot.FlankUntil = now + 1.2
                return
            end
        end


        if useBestMove(t, "cc") then return end
        if useBestMove(t, "heavy") then return end
        trySpecial(t, d2d)
        tryUseSkill(t, d)

        if not isInSkill() then startM1() end
        return
    end

    if Bot.State == "CHASE" then






        faceTarget(t, true)


        if not Bot.Leashed and useChase() then return end


        if hasLineOfSight(t) and (now - Bot.LastDash) > Config.ChaseDashCooldown and not Bot.Leashed then
            Bot.LastDash = 0
            dashToward()
        end


        trySpecial(t, d2d)
        tryUseSkill(t, d)

        navigateTo(t, th.Position)
        return
    end

    if Bot.State == "PERCHED" then



        local side = Bot.PerchSide
        if not (Config.PerchSideOnce and side) then
            side = (math.random() < 0.5) and 1 or -1
            if Config.PerchSideOnce then Bot.PerchSide = side end
        end
        local away = h.CFrame.RightVector * side
        local goal = h.Position + away * 12 - Vector3.new(0, 0, 0)
        walkTo(goal)
        if now - Bot.LastDash > Config.DashCooldown then
            dashSideways()
        end
        clearPath()
        return
    end

    if Bot.State == "AWAKEN" then









        stopWalking()

        if (now - (Bot.LastAwakenTry or 0)) > Config.AwakenRetry then
            Bot.LastAwakenTry = now
            Bot.AwakenTries = (Bot.AwakenTries or 0) + 1
            doUltimate()

            if Bot.AwakenTries >= Config.AwakenMaxTries then

                Bot.AwakenBlockUntil = now + Config.AwakenBackoff
                Bot.AwakenTries = 0
                debug(string.format("awakening refused %dx - backing off %.0fs, resuming combat",
                    Config.AwakenMaxTries, Config.AwakenBackoff))
            end
        end


        if d2d <= Config.M1Range + 2 and not isInSkill() then
            startM1()
        end
        return
    end


    if Bot.State == "THROW" then














        stopM1()
        faceTarget(t, true)

        if d2d and d2d > Config.ThrowRange then

            navigateTo(t, th.Position)
        else
            stopWalking()
        end

        if not isStunned() then
            senseThrowHeld(t)
        end
        return
    end

    if Bot.State == "LEVEL" then





        stopM1()
        if th then
            navigateTo(t, th.Position)
            local hum = getHum()

            if hum and (Bot.DistY or 0) > 0 and d2d < 12 then hum.Jump = true end
        end
        if Config.DebugTrace then
            debugEvery("level", 3, string.format(
                "wrong level: %.0f studs of height, %.0f across - repositioning",
                math.abs(Bot.DistY or 0), d2d or 0))
        end
        return
    end

    if Bot.State == "REACT" then
        local r = Bot.Reacting

        if r == "grabbed" then






            local hum = getHum()
            if hum then hum.Jump = true end
            useBestMove(t, "escape")
            return
        end

        if r == "dodge" then


            local dir = Bot.ReactDir
            local h2 = getHRP()
            if Bot.ReactSoft and Bot.AllyLane and Bot.AllyLane.hold then


                stopWalking()
                if t then faceTarget(t, true) end
            elseif dir and h2 then

                if not Bot.ReactSoft then dashWorld(dir) end
                walkTo(h2.Position + dir * (Bot.ReactSoft and 12 or 18))
            end
            if Bot.ReactMove then memReactStart(Bot.ReactMove, "dodge") end
            return
        end

        if r == "block" then


            if Bot.BlockActive then
                doBlock(Config.BlockHold or 0.9)
            elseif tick() - (Bot.LastBlock or 0) > Config.BlockCooldown then
                doBlock(Config.BlockHold or 0.9)
            end


            if not Bot.BlockActive and tick() - (Bot.LastBlock or 0) > Config.BlockDuration then
                doBlock()
            end
            faceTarget(t, true)
            if Bot.ReactMove and Bot.BlockActive then memReactStart(Bot.ReactMove, "block") end
            return
        end

        if r == "recover" then


            local h2 = getHRP()
            if h2 and Bot.RecoverDir then walkTo(h2.Position + Bot.RecoverDir * 24) end
            return
        end

        if r == "away" then


            local th2 = t and getHRP(t)
            local h2 = getHRP()
            if th2 and h2 then
                local awayV = h2.Position - th2.Position
                if awayV.Magnitude > 0.1 then
                    awayV = awayV.Unit
                    dashWorld(awayV)
                    walkTo(h2.Position + awayV * 24)
                end
            end
            if Bot.ReactMove then memReactStart(Bot.ReactMove, "away") end
            return
        end

        if r == "hold" then





            stopM1()
            faceTarget(t, true)
            if Bot.ReactMove then memReactStart(Bot.ReactMove, "hold") end
            return
        end
    end

    if Bot.State == "RETREAT" then













        mapEscapeStart(h.Position)

        if (Bot.PursuitTime or 0) > 0.6 then useBestMove(t, "trap") end



        local needAim = (not Bot.EscapeStep) or now > (Bot.EscapeUntil or 0)

        if Bot.EscapeStep and not mapNavProgress(h.Position, Bot.EscapeStep) then






            needAim = true
            if Config.DebugMap then
                debugEvery("retreatblock", 2, "retreat blocked -> re-aiming")
            end
        end

        if needAim then
            Bot.EscapeStep, Bot.EscapeVault = pickOpenRetreat(h.Position, th.Position)
            Bot.EscapeUntil = now + Config.EscapeHold
        end

        if Bot.EscapeStep then
            walkTo(Bot.EscapeStep)
            local dir = Bot.EscapeStep - h.Position
            if dir.Magnitude > 0.1 then dashWorld(dir.Unit) end






            if Bot.EscapeVault then
                local hum = getHum()
                if hum then hum.Jump = true end
            end


            if (d2d or 0) > Config.PursuitRange then
                mapEscapeEnd(h.Position, true)
            end
        else




            local awayDir = (h.Position - th.Position)
            awayDir = awayDir.Magnitude > 0.1 and awayDir.Unit or h.CFrame.LookVector
            navigateTo(t, h.Position + awayDir * 40)
            if Config.DebugMap then
                debugEvery("boxedin", 3, "no open direction - pathing out")
            end
        end

        if now - Bot.LastSkill > Config.SkillDelay then
            useBestMove(t, "escape")
        end
        return
    end

    if Bot.State == "DEFEND" then
        stopWalking()



        local dv = Bot.DefendVs or t
        local swinging
        if Bot.DefendVs then
            swinging = Bot.DefendVsSwinging
        else
            local sw, nm = senseMeleeSwing(t)
            swinging = sw and isTargetFacingUs(t)
            if swinging and nm ~= Bot.SwingName then Bot.BlockSwings = (Bot.BlockSwings or 0) + 1 end
            Bot.SwingName = swinging and nm or nil
        end





        local recoverHold = not swinging and Bot.RecoverMode == "hold" and now < (Bot.RecoverUntil or 0)
        if swinging then
            Bot.LastSwingAt = now
            Bot.LastSwinger = dv
            doBlock(Config.BlockHold or 0.9)
        elseif recoverHold then
            doBlock(Config.BlockHold or 0.9)
        end
        if Bot.BlockActive and Bot.BlockHeld then
            if isTargetAttacking(dv) then





                Bot.BlockHeld = false
                Bot.BlockUntil = math.min(Bot.BlockUntil or now, now + Config.BlockDuration)
            elseif now - (Bot.LastSwingAt or 0) > (Config.BlockStringGap or 0.5) and not recoverHold then

                releaseBlock()
            else

                faceTarget(dv, true)
                return
            end
        end
        if now - Bot.LastBlock > 0.7 and now - (Bot.BlockReleasedAt or 0) > 0.6 then
            doBlock()
        end


        if not swinging and now - Bot.LastSkill > Config.SkillDelay then
            useBestMove(dv, "counter")
        end
        return
    end

    if Bot.State == "APPROACH" or Bot.State == "APPROACH_FAR" then

        if Config.Throwables and t and tick() - (Bot.LastPickup or 0) > 2.5 then
            local hp2 = getHRP()
            if hp2 and not senseHoldingItem() then
                local model = senseThrowable(hp2.Position)
                if model then
                    Bot.LastPickup = tick()
                    sensePickUp(model)
                    if Config.DebugSense then
                        debug("picked up " .. model.Name .. " while closing")
                    end
                end
            end
        end
    end

    if Bot.State == "APPROACH_FAR" then
        if now - Bot.LastSkill > Config.SkillDelay then
            if useBestMove(t, "ranged") then return end
        end



        local closeMin = (Bot.Plan and Bot.Plan.closeHard)
                         and (Config.CloseDashMin * 0.6) or Config.CloseDashMin







        if (Bot.Attackers or 0) > 0 and Bot.Losing and d2d > Config.AwareRange then








            if Bot.Aggressor and Bot.Aggressor ~= t and Bot.Aggressor.Name
               and ((now - (Bot.AggressorAt or 0)) < 3 or now < (Bot.InterceptUntil or 0))
               and not isAlly(Bot.Aggressor.Name)
               and (isValidTarget(Bot.Aggressor) or targetBlinking(Bot.Aggressor)) then
                debugEvery("abandon", 3.0, string.format("approach abandoned: %s on us while %.0f studs out -> fighting them",
                    Bot.Aggressor.Name, d2d))


                Bot.InterceptUntil = now + 3
                setTarget(Bot.Aggressor, now, "abandon: fighting the hitter")
                Bot.AbandonUntil = 0
                return
            end

















            if now >= (Bot.AbandonUntil or 0) then
                Bot.AbandonUntil = now + (Config.AbandonHold or 1.5)
                local guess = hitterToAdopt(now)
                if guess and guess ~= t then
                    debugEvery("abandon-hitter", 3.0, string.format("approach abandoned: %d on us while %.0f studs out -> %s is the hitter",
                        Bot.Attackers, d2d, guess.Name))
                    Bot.InterceptUntil = now + 3
                    setTarget(guess, now, "abandon: fighting the likeliest hitter")
                    Bot.AbandonUntil = 0
                    return
                elseif Bot.Aggressor == t and (now - (Bot.AggressorAt or 0)) < 3 then



                    debugEvery("abandon", 3.0, string.format("closing on the hitter (%.0f studs, hit us %.1f s ago)",
                        d2d, now - (Bot.AggressorAt or 0)))
                else
                    debugEvery("abandon", 3.0, string.format("approach abandoned: %d on us while %.0f studs out (no hitter to take)",
                        Bot.Attackers, d2d))
                end
            end
        end

        if hasLineOfSight(t) and d2d > closeMin and not Bot.Leashed then
            dashToward()
        end










        local navProgress = mapNavProgress(h.Position, th.Position)
        if Bot.WalkActive and not Bot.Leashed and not navProgress then
            local open = mapOpenDirections(h.Position)
            local pick = open[1]
            if pick and pick.clear >= Config.FrontierMinClear then
                walkTo(h.Position + pick.dir * math.min(pick.clear - 4, 30))
                if Config.DebugMap then
                    debug(string.format("approach blocked -> detouring (clear %.0f)", pick.clear))
                end
                return
            end
        end



        navigateTo(t, teamApproachPoint(th.Position, h.Position))
        return
    end

    if Bot.State == "APPROACH" then




























        if Bot.EnemyBand and d2d and memEnemyTrusted(Bot.EnemySet) then
            local lo = tonumber(string.match(Bot.EnemyBand, "^(%d+)"))
            if lo and d2d >= lo and d2d <= lo + 14 then
                memEnemyTrialStart(Bot.EnemySet, "band")
                if d2d > Config.M1Range + 6 then
                    navigateTo(t, th.Position)
                    return
                end
            end
        end

        local pref = Bot.Plan and Bot.Plan.bestRange
        if pref and pref >= 20 and pref <= 40 and not Bot.Stalling
           and d2d >= pref - 5 and d2d <= pref + 12 then
            faceTarget(t, true)
            stopWalking()
            trySpecial(t, d2d)
            if not useBestMove(t, "ranged") then
                tryUseSkill(t, d)
            end
            return
        end

        trySpecial(t, d2d)
        tryUseSkill(t, d)


        if d2d > Config.CloseDashMin and hasLineOfSight(t) and not Bot.Leashed then
            dashToward()
        end

        if d2d <= Config.M1Range + 4 and math.abs(dy) <= Config.MaxVertical then
            startM1()
        end



        local h3 = getHRP()
        navigateTo(t, teamApproachPoint(th.Position, h3 and h3.Position))
        if hasLineOfSight(t) and d > Config.CloseRange and not Bot.Leashed
           and now - Bot.LastDash > Config.DashCooldown * 1.5 then
            dashToward()
        end
        return
    end

    if Bot.State == "ATTACK" then





        if Config.Throwables and senseHoldingItem() then
            senseThrowHeld(t)
        end

















        if Config.Throwables and t and tick() - (Bot.LastPickup or 0) > 1.5 then
            local h3 = getHRP()
            if h3 and not senseHoldingItem() then
                local model = senseThrowable(h3.Position)
                if model then
                    Bot.LastPickup = tick()
                    if sensePickUp(model) and Config.DebugSense then
                        debug("picked up " .. model.Name .. " to throw")
                    end
                end
            end
        end

        faceTarget(t, true)
        stopWalking()














        local inMelee = d2d <= Config.M1Range + 2
        local skillGap = inMelee and Config.SkillGapClose or Config.SkillDelay










        trySpecial(t, d2d)





        local canSkill = (now - Bot.LastSkill) >= skillGap
        if canSkill then
            tryUseSkill(t, d)
        end



        if not isInSkill() then
            startM1()
        end









        local wantsToClose = d2d > Config.CloseDashMin
        local dodgeReady = (now - (Bot.LastDodge or 0)) > Config.DodgeCooldown

        if not wantsToClose and dodgeReady and math.random() < 0.5 then
            Bot.LastDodge = now
            stopM1()
            if dash(math.random() < 0.5 and "Left" or "Right") then
                task.delay(0.35, function()
                    if Bot.State == "ATTACK" then startM1() end
                end)
            else
                startM1()
            end
        end
        return
    end
end
















function restoreDebrisOne(p)
    local touched = Bot.DebrisTouched
    local rec = touched and touched[p]
    if rec then
        if type(rec) == "table" then
            for _, c in ipairs(rec) do pcall(function() c:Disconnect() end) end
        end
        touched[p] = nil
    end
    pcall(function()
        if p.Parent then
            p.CanCollide = true
            local m = p:FindFirstChild("JJK_PassThrough")
            if m then m:Destroy() end
        end
    end)
end




function pruneDebris()
    local touched = Bot.DebrisTouched
    if not touched then return end
    local maxDim = Config.DebrisMaxSize or 3
    for p, rec in pairs(touched) do
        local ok, spent = pcall(function()
            local sz = p.Size



            if type(rec) == "table" and rec.named then
                return (not p.Parent) or math.abs(p.Position.Y) > 1e5
                       or math.max(sz.X, sz.Y, sz.Z) > (Config.DebrisMaxSizeNamed or 12)
                       or (rec.pos ~= nil and (p.Position - rec.pos).Magnitude > 2)
            end
            return (not p.Parent) or p.Anchored or math.abs(p.Position.Y) > 1e5
                   or math.max(sz.X, sz.Y, sz.Z) > maxDim
        end)
        if not ok or spent then restoreDebrisOne(p) end
    end
end

function sweepDebris()
    pruneDebris()
    if not Config.DebrisPassThrough then return end
    local now = tick()
    if now - (Bot.DebrisSweepAt or 0) < (Config.DebrisEvery or 0.5) then return end
    Bot.DebrisSweepAt = now
    local h = getHRP()
    if not h then return end
    local touched = Bot.DebrisTouched
    if not touched then touched = {}; Bot.DebrisTouched = touched end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { getChar() }
    local ok, parts = pcall(function()
        return Workspace:GetPartBoundsInRadius(h.Position, Config.DebrisRadius or 14, params)
    end)
    if not ok or not parts then return end

    local maxLoose = Config.DebrisMaxSize or 3



    local mapData = Config.DebrisAnyAnchored and Workspace:FindFirstChild("Map")
    mapData = mapData and mapData:FindFirstChild("Data") or nil
    for _, p in ipairs(parts) do
        local named = false
        if Config.DebrisAnyAnchored and p:IsA("BasePart") then
            named = p.Name == "DebreeRef" or (mapData ~= nil and p:IsDescendantOf(mapData))
            if named and (p.Position.Y + p.Size.Y * 0.5) < h.Position.Y - 2 then named = false end
        end
        if p:IsA("BasePart") and p.CanCollide and (not p.Anchored or named) and not touched[p] then
            local sz = p.Size
            if math.max(sz.X, sz.Y, sz.Z) <= (named and (Config.DebrisMaxSizeNamed or 12) or maxLoose) then
                local model = p:FindFirstAncestorOfClass("Model")
                local isChar = model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
                if not isChar then



                    local conns = {}
                    pcall(function()
                        conns[#conns + 1] = p:GetPropertyChangedSignal("Anchored"):Connect(function()
                            if p.Anchored then restoreDebrisOne(p) end
                        end)
                        conns[#conns + 1] = p.AncestryChanged:Connect(function()
                            if not p.Parent then restoreDebrisOne(p) end
                        end)
                    end)
                    if named then
                        conns.named = true
                        if p.Anchored then conns.pos = p.Position end
                    end
                    touched[p] = conns
                    pcall(function()
                        p.CanCollide = false
                        local m = Instance.new("PathfindingModifier")
                        m.Name = "JJK_PassThrough"
                        m.PassThrough = true
                        m.Parent = p
                    end)
                    Bot.DebrisCount = (Bot.DebrisCount or 0) + 1



                    if not Life.debrisSaid then
                        Life.debrisSaid = true
                        debug(string.format("debris: passing through %s (%d so far)",
                            describeHit({ Instance = p }), Bot.DebrisCount))
                    end
                end
            end
        end
    end












    pruneDebris()
end



function restoreDebrisAll()
    local roots = {}
    local map = Workspace:FindFirstChild("Map")
    local data = map and map:FindFirstChild("Data")
    if data then table.insert(roots, data) end
    local n = 0
    for _, root in ipairs(roots) do
        for _, m in ipairs(root:GetDescendants()) do
            if m.Name == "JJK_PassThrough" and m:IsA("PathfindingModifier") then
                local p = m.Parent
                pcall(function()
                    if p and p:IsA("BasePart") then p.CanCollide = true end
                    m:Destroy()
                end)
                n = n + 1
            end
        end
    end
    if n > 0 then debug(string.format("debris: restored collision on %d parts left from an earlier run", n)) end
end

function restoreDebris()
    restoreDebrisAll()
    local touched = Bot.DebrisTouched
    if not touched then return end
    for p in pairs(touched) do
        local rec = touched[p]
        if type(rec) == "table" then
            for _, c in ipairs(rec) do pcall(function() c:Disconnect() end) end
        end
        pcall(function()
            if p.Parent then
                p.CanCollide = true
                local m = p:FindFirstChild("JJK_PassThrough")
                if m then m:Destroy() end
            end
        end)
    end
    Bot.DebrisTouched = nil
end








function hopReflex()
    if not Bot.WalkActive or not Bot.WalkGoal then return end
    local st = Bot.State
    if st == "ATTACK" or st == "DEFEND" or st == "CCED" or st == "REACT"
       or st == "DEAD" or st == "IDLE" or st == "PUNISH" or st == "THROW" then
        return
    end
    local h, hum = getHRP(), getHum()
    if not h or not hum then return end
    if isInSkill() or isStunned() or isRagdolled() then return end
    local now = tick()
    local v = h.AssemblyLinearVelocity
    local md = hum.MoveDirection



    if md.Magnitude < 0.5 or math.abs(v.Y) > 2 then return end
    if (Bot.StuckTime or 0) < (Config.HopStallTime or 0.35) then Bot.HopBurst = 0 return end
    if now - (Bot.LastHop or 0) < (Config.HopCooldown or 1.0) then return end
    local low, high, lowHit = probeLowHigh(h.Position, md)
    if low and not high and lowHit then



        local dl = (lowHit.Position - (h.Position + Vector3.new(0, -1.5, 0))).Magnitude



        if (Bot.StuckTime or 0) < 0.05 then Bot.HopBurst = 0 end
        if dl <= 2.5 and (Bot.HopBurst or 0) < 2 then
            Bot.LastHop = now
            Bot.HopBurst = (Bot.HopBurst or 0) + 1
            hum.Jump = true
            debugEvery("hop", 2, "hop: low obstacle ahead - " .. describeHit(lowHit))
        end
    end
end




local function stuckArc(h, goal, side)
    local pos = h.Position
    local to = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
    local lv = h.CFrame.LookVector
    local fwd = (to.Magnitude > 0.5) and to.Unit or Vector3.new(lv.X, 0, lv.Z).Unit
    local right = Vector3.new(-fwd.Z, 0, fwd.X)
    local n = Config.StuckArcRays or 12
    local len = Config.StuckArcRange or 14
    local best, bestDir, bestClear = -1, nil, 0
    for i = 0, n - 1 do
        local a = (i / n) * math.pi * 2
        local dir = Vector3.new(math.cos(a), 0, math.sin(a))
        local clear = len
        for _, dy in ipairs({ 0.5, -1.5 }) do
            local hit = Workspace:Raycast(pos + Vector3.new(0, dy, 0), dir * len, losParams)
            if hit and hit.Normal.Y < 0.5 then
                local d = (hit.Position - pos).Magnitude
                if d < clear then clear = d end
            end
        end
        local score = clear * (0.5 + 0.5 * dir:Dot(fwd))
        if dir:Dot(right) * side < 0 then score = score * 0.6 end
        if clear >= 4 and score > best then best, bestDir, bestClear = score, dir, clear end
    end
    if not bestDir then return false end
    local run = math.min(Config.StuckArcLen or 10, bestClear - 2)
    if run < 3 then return false end
    local arcGoal = pos + bestDir * run
    Bot.DetourGoal = arcGoal
    Bot.DetourUntil = tick() + (Config.DetourHold or 1.5) + 1
    Bot.NavMode = "detour"
    Bot.PathCommitUntil = tick() + (Config.PathCommit or 3) + 2
    walkTo(arcGoal)
    debugEvery("arc", 2, string.format("arc: side=%s clear=%.0f run=%.0f", (side > 0) and "L" or "R", bestClear, run))
    return true
end






local function breakWall(h, hit)
    local p = hit and hit.Instance
    if not p then return false end
    local map = Workspace:FindFirstChild("Map")
    local destr = map and map:FindFirstChild("Destructible")
    if not destr or not p:IsDescendantOf(destr) then return false end
    local thr = destr:FindFirstChild("Throwable")
    if thr and p:IsDescendantOf(thr) then return false end
    local now = tick()
    if Bot.BreakWallPart == p and now - (Bot.BreakWallAt or 0) < (Config.BreakWallRepeat or 8) then return false end
    Bot.BreakWallPart, Bot.BreakWallAt = p, now
    Bot.BreakWallUntil = now + (Config.BreakWallSeconds or 2.2)
    pcall(function()
        local flat = Vector3.new(hit.Position.X, h.Position.Y, hit.Position.Z)
        if (flat - h.Position).Magnitude > 0.1 then h.CFrame = CFrame.lookAt(h.Position, flat) end
    end)
    startM1()
    debugEvery("wall", 2, string.format("wall: %d M1 swings at %s", Config.BreakWallHits or 4, describeHit(hit)))
    return true
end

local function handleStuck()



    if Bot.BreakWallUntil then
        local bp = Bot.BreakWallPart
        if Bot.State == "ATTACK" then
            Bot.BreakWallUntil = nil
        elseif tick() > Bot.BreakWallUntil or not bp or not bp.Parent then
            Bot.BreakWallUntil = nil
            stopM1()
        else
            startM1()
        end
    end

    if not Bot.WalkGoal then return end
    local st = Bot.State
    if st == "ATTACK" or st == "DEFEND" or st == "PUNISH" or st == "CCED"
       or st == "REACT" or st == "IDLE" or st == "DEAD" or st == "THROW" then
        return
    end
    if Bot.StuckTime > Config.MaxStuckTime then
        local now = tick()
        local h = getHRP()
        local hum = getHum()


        Bot.StuckCount = ((now - (Bot.LastStuckAt or 0)) < (Config.StuckRepeatWindow or 10)) and math.min((Bot.StuckCount or 0) + 1, 5) or 1
        Bot.LastStuckAt = now


        local low, high, lowHit, highHit = false, false, nil, nil
        if h and hum then
            local md = hum.MoveDirection
            if md.Magnitude < 0.05 then md = h.CFrame.LookVector end
            low, high, lowHit, highHit = probeLowHigh(h.Position, md)
        end
        if low and not high then
            if hum then hum.Jump = true end
            doParkour()
        end



        clearPath()
        Bot.LastPathCompute = 0
        Bot.PathCommitUntil = now + (Config.PathCommit or 3) + 2







        local what = (low and not high) and "jump" or "re-plan"



        if Config.BreakWalls and h and (lowHit or highHit) and breakWall(h, lowHit or highHit) then
            what = "break wall"
        elseif Bot.StuckCount >= 4 and h then
            dashWorld(-h.CFrame.LookVector)
            doParkour()
            what = "back out + parkour"
        elseif Bot.StuckCount >= 3 and h then
            dashWorld(openSide(h))
            if hum then hum.Jump = true end
            what = "dash to open side"
        elseif Config.StuckArc and h and Bot.WalkGoal and (Bot.StuckCount >= 2 or (not low and not high)) then
            Bot.ArcSide = -(Bot.ArcSide or -1)
            if stuckArc(h, Bot.WalkGoal, Bot.ArcSide) then
                what = (Bot.ArcSide > 0) and "arc left" or "arc right"
            elseif Bot.StuckCount >= 2 and steerAround(Bot.WalkGoal) then
                what = "detour"
            end
        elseif Bot.StuckCount >= 2 and h and Bot.WalkGoal then
            if steerAround(Bot.WalkGoal) then what = "detour" end
        end
        debugEvery("stuck", 2, string.format("stuck (%d): low=%s high=%s -> %s | in the way: %s",
            Bot.StuckCount, tostring(low), tostring(high), what, describeHit(lowHit or highHit)))
        Bot.StuckTime = 0
        Bot.GoalRefDist = nil
    end
end






local function idleUnpocket()
    if not Config.IdleUnpocket then return end
    if Bot.State ~= "IDLE" then Bot.UnpocketAt = nil return end
    local now = tick()
    if now - (Bot.UnpocketAt or 0) < (Config.IdleUnpocketEvery or 2.5) then return end
    Bot.UnpocketAt = now
    if Bot.WalkGoal and Bot.WalkActive then return end
    local h = getHRP()
    if not h then return end
    local pos = h.Position
    local near, dist = 0, Config.IdleUnpocketDist or 3.5
    for i = 0, 7 do
        local a = i * math.pi / 4
        local dir = Vector3.new(math.cos(a), 0, math.sin(a))
        local hit = Workspace:Raycast(pos + Vector3.new(0, 0.5, 0), dir * dist, losParams)
        if hit and hit.Normal.Y < 0.5 then near = near + 1 end
    end
    if near < 2 then return end
    local side = (math.random() < 0.5) and 1 or -1
    if stuckArc(h, pos + h.CFrame.LookVector * 5, side) then
        debugEvery("unpocket", 5, string.format("unpocket: %d walls within %.0f studs while idle - walking out", near, dist))
    end
end








local lastTrace = 0

local function traceDecision()
    if not Config.DebugTrace then return end
    if tick() - lastTrace < 1.0 then return end
    lastTrace = tick()

    local t = Bot.Target
    local d2d = Bot.Dist2D or -1
    local inMelee = d2d <= Config.M1Range + 2
    local sinceSkill = (Bot.LastSkill or 0) > 0 and (tick() - Bot.LastSkill) or 999
    local gap = inMelee and Config.SkillGapClose or Config.SkillDelay


    local ready, blocked = {}, {}
    for _, e in ipairs(getUsableMoves()) do
        local r = e.rule
        local rdy = isSkillReady(e.service)
        local inRange = d2d >= r.min and d2d <= r.max
        if rdy and inRange then
            table.insert(ready, e.name)
        elseif rdy and not inRange then
            table.insert(blocked, string.format("%s(range %d-%d)", e.name, r.min, r.max))
        end
    end

    debug(string.format(
        "TRACE st=%s d=%.1f y=%.1f melee=%s | M1=%s inSkill=%s stun=%s rag=%s | skillGap %.1f/%.1f | flank=%s",
        tostring(Bot.State), d2d, Bot.DistY or 0, tostring(inMelee),
        tostring(Bot.M1Active), tostring(isInSkill()), tostring(isStunned()),
        tostring(isRagdolled()), sinceSkill, gap,
        tostring(tick() < (Bot.FlankUntil or 0))))

    debug("TRACE ready-in-range: " .. (#ready > 0 and table.concat(ready, ", ") or "NONE"))
    if #blocked > 0 then
        debug("TRACE ready-out-of-range: " .. table.concat(blocked, ", "))
    end
    if t then
        debug(string.format("TRACE tgt=%s hp=%.0f%% lastDmg=%.1fs ago blocking=%s",
            t.Name, getHPPct(t), tick() - (Bot.TargetHPTime or tick()),
            tostring(isTargetBlocking(t))))
    end
end


local connection
local function startBot()
    pcall(restoreDebrisAll)
    AutoState.wantOn = true
    memLifeStart()










    if connection then
        connection:Disconnect()
        connection = nil
    end












    if AutoState.pendingChar or AutoState.queued then
        debug("manual start - dropping the in-flight swap, will swap on next death")
        AutoState.pendingChar = nil
        AutoState.queued = nil
        AutoState.waitingSince = nil
    end

    Config.Enabled = true
    Bot.StartTime = tick()
    Bot.LastPos = getHRP() and getHRP().Position or Vector3.zero
    Bot.State = "IDLE"
    startBodyLock()




    if Config.DebugMoves then
        local c = getChar()
        local kit = tostring(c and c:GetAttribute("Moveset"))
        debug("Moveset: " .. kit
              .. " | InUlt: " .. tostring(c and c:GetAttribute("InUlt")))




        AutoState.kitDumped = AutoState.kitDumped or {}
        if not AutoState.kitDumped[kit] then
            local any = false
            for _, e in ipairs(getUsableMoves()) do
                any = true
                local matched = (MoveRules[e.name] ~= nil) and "rule" or "DEFAULT"
                debug(string.format("  move '%s' svc=%s range=%d-%d prio=%d [%s]",
                    e.name, e.service, e.rule.min, e.rule.max, e.rule.prio, matched))
            end
            if not any then debug("  (no usable moves found!)") else AutoState.kitDumped[kit] = true end
            debug("  M1 branch would be: " .. tostring(fireM1Once(true)))
            local srule, sset = getSpecialRule()
            if srule then
                debug(string.format("  special '%s' kind=%s range=%d-%d",
                    srule.name, srule.kind, srule.min, srule.max))
            else
                debug("  special: none mapped for " .. tostring(sset))
            end
        end
    end

    debug("=== BOT STARTED ===")

    connection = RunService.Heartbeat:Connect(function(dt)
        local ok, err = pcall(function()
            Bot.FrameDelta = dt or 0.016









            local cpu, ck = Life.cpu, os.clock()
            if not cpu then
                cpu = { sense = 0, learn = 0, threat = 0, map = 0, state = 0, mem = 0, exec = 0, move = 0, rest = 0 }
                Life.cpu = cpu
            end
            local ck0 = ck



            do
                local pend = Bot.RevPending or 0
                if pend > 0 or Bot.PaceArmed then
                    local hh = getHRP()
                    if hh then
                        local nowR = tick()
                        if pend > 0 then
                            Bot.RevPending = 0
                            for _ = 1, pend do paceNote(nowR, hh, Bot.RevGoal or Bot.WalkGoal, true) end
                        elseif nowR - (Bot.PaceFromAt or 0) >= (Config.PaceWindow or 3) then
                            paceNote(nowR, hh, Bot.WalkGoal, false)
                        end
                    end
                end
            end










            local myHRP = getHRP()
            local myPos = myHRP and myHRP.Position
            if myPos then Bot.LastPos = myPos end

            if myPos then
                local hostiles, nearest = 0, nil
                local hostilesNear = 0
                local seekChar, seekDist = nil, nil
                local nearby = {}
                local hitters = {}
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= LocalPlayer and pl.Character then
                        local ph = getHRP(pl.Character)















                        if ph then
                            local pd = (ph.Position - myPos).Magnitude
                            if pd <= Config.ThreatRange then
                                table.insert(hitters, pl.Character)
                            end
                        end

                        if ph and isValidTarget(pl.Character) then
                            local pd = (ph.Position - myPos).Magnitude
                            if pd <= Config.ThreatRange then
                                table.insert(nearby, pl.Character)
                            end
                            if pd < Config.AwareRange then
                                hostiles = hostiles + 1
                                if not nearest or pd < nearest then nearest = pd end
                            end
                            if pd < (Config.HostilesNearRange or 35) then hostilesNear = hostilesNear + 1 end






                            if pd < Config.SeekRange and (not seekDist or pd < seekDist) then
                                seekChar, seekDist = pl.Character, pd
                            end
                        end
                    end
                end
                Bot.Hostiles = hostiles
                Bot.HostilesNear = hostilesNear
                Bot.NearestHostile = nearest
                Bot.Nearby = nearby
                Bot.HitCandidates = hitters
                Bot.SeekChar = seekChar
                Bot.SeekDist = seekDist
            end
            do local c = os.clock(); cpu.sense = cpu.sense + (c - ck); ck = c end



            memTrackDamage(Bot.Target, Bot.Dist2D)
            if (Bot.FrameDmgIn or 0) > 0 then
                Bot.LastHurtAt = tick()
                senseNoteIncoming(Bot.FrameDmgIn)
            end

            memRateTick(Bot.FrameDelta, Bot.FrameDmgOut,
                        Bot.Target ~= nil,
                        (Bot.Dist2D or 999) < Config.AwareRange,
                        Bot.FrameDmgIn)
            Bot.Stalling = memIsStalling(Bot.Target ~= nil)












            if Config.Sense and tick() - (Bot.LastSenseScan or 0) > 2 then
                Bot.LastSenseScan = tick()
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= LocalPlayer and pl.Character then
                        senseWatch(pl.Character)
                    end
                end
            end
            memReactResolve()
            memEnemyTrialResolve()
            memResolveUnknown()
            do local c = os.clock(); cpu.learn = cpu.learn + (c - ck); ck = c end











            if Bot.State == "RETREAT" and Bot.Target then
                if Bot.FleeingFrom ~= Bot.Target then
                    Bot.FleeingFrom = Bot.Target
                    Bot.FleeChaseFor = 0
                    Bot.FleeClearFor = 0
                end

                if (Bot.Dist2D or 999) < Config.PursuitRange then
                    Bot.FleeChaseFor = (Bot.FleeChaseFor or 0) + Bot.FrameDelta
                    Bot.FleeClearFor = 0
                else
                    Bot.FleeClearFor = (Bot.FleeClearFor or 0) + Bot.FrameDelta
                end


                if (Bot.FleeChaseFor or 0) > Config.FleeChaseStick then
                    Bot.Aggressor = Bot.FleeingFrom
                    Bot.AggressorAt = tick()
                    debugEvery("chased", 4, string.format(
                        "%s has chased us %.1fs - engaging them",
                        Bot.FleeingFrom.Name, Bot.FleeChaseFor))
                    Bot.FleeChaseFor = 0
                end


                if (Bot.FleeClearFor or 0) > Config.FleeEscapedFor then
                    debugEvery("escaped", 4,
                        "escaped " .. Bot.FleeingFrom.Name .. " - finding someone else")
                    Bot.BadTargets[Bot.FleeingFrom] = tick()
                    if Bot.Aggressor == Bot.FleeingFrom then Bot.Aggressor = nil end
                    Bot.Target = nil
                    Bot.FleeingFrom = nil
                    Bot.FleeClearFor = 0
                end
            elseif Bot.State ~= "RETREAT" then
                Bot.FleeingFrom = nil
            end

            threatDecay(Bot.FrameDelta)
            if myPos and Bot.FrameDmgIn > 0 then
                threatAttribute(Bot.FrameDmgIn, myPos, Bot.HitCandidates)
            end
            Bot.ThreatChar, Bot.ThreatScore = threatPrimary()
            Bot.Attackers = threatAttackers()
            Bot.Losing = threatLosing()



            Bot.Outnumbered = Bot.Attackers >= 2
            do local c = os.clock(); cpu.threat = cpu.threat + (c - ck); ck = c end

            if myPos then
                mapObserve(myPos, Bot.FrameDelta, Bot.Hostiles,
                           Bot.FrameDmgOut, Bot.FrameDmgIn)
                mapDiscoverShortcuts(myPos)

                local cell, cellKey = mapHere(myPos)
                Bot.Cell = cellKey
                Bot.CellClass = cell and mapClassify(cell) or "NEUTRAL"
            end

            do local c = os.clock(); cpu.map = cpu.map + (c - ck); ck = c end
            updateState()
            updatePursuit(Bot.Target, Bot.Dist2D, Bot.FrameDelta)
            do local c = os.clock(); cpu.state = cpu.state + (c - ck); ck = c end
            memObserve(Bot.Target, Bot.Dist2D, Bot.FrameDelta,
                       Bot.Target ~= nil and isTargetBlocking(Bot.Target) or false)
            memResolve()
            memSave(false)
            do local c = os.clock(); cpu.mem = cpu.mem + (c - ck); ck = c end
            executeState()
            do


                local c, ps = os.clock(), Bot.PathSec or 0
                Bot.PathSec = 0
                cpu.exec = cpu.exec + (c - ck) - ps
                ck0 = ck0 + ps
                ck = c
            end
            handleStuck()
            idleUnpocket()
            tickMover()
            sweepDebris()
            hopReflex()
            applySprint()
            updateNativeLock()
            do local c = os.clock(); cpu.move = cpu.move + (c - ck); ck = c end
            tickM1(dt)
            tickDash()
            traceDecision()
            logFlush(false)
            Bot.DivineDogActive = checkDivineDog()
            do
                local c = os.clock()
                cpu.rest = cpu.rest + (c - ck)
                local frame = c - ck0
                Life.cpuN = (Life.cpuN or 0) + 1
                Life.cpuSum = (Life.cpuSum or 0) + frame
                if frame > (Life.cpuMax or 0) then Life.cpuMax = frame end
            end
        end)
        if not ok then
            debug("ERROR: " .. tostring(err))
        end
    end)
end

local function stopBot()




    if type(setSprintKey) == "function" then pcall(setSprintKey, false) end
    Config.Enabled = false
    if connection then
        connection:Disconnect()
        connection = nil
    end
    stopM1()
    stopWalking()
    unbindMover()
    stopBodyLock()
    memSave(true, "stop")
    logFlush(true)
    if LOG.canWrite and LOG.enabled then
        announce("log saved: " .. LOG.name .. " (" .. #LOG.lines .. " lines)")
    end
    setLockOn(nil)
    lastLockTarget = nil
    local hum = getHum()
    if hum then hum.WalkSpeed = 16 end
    Bot.State = "IDLE"
    Bot.Target = nil
    Bot.TeamFollowing = false
    Bot.TeamFollowRadius = nil
    Bot.FollowYieldUntil = 0
    Bot.FollowWalk = false
    Bot.RejoinDashAt = 0
    Bot.RejoinSince = 0
    Bot.GangedUntil = 0
    Bot.RetreatAlly = nil
    Bot.ChaseTarget = nil
    Bot.DetourGoal = nil
    Bot.Leashed = false
    Bot.LeashPoint = nil
    Bot.PathBusy = false
    Bot.LaneHold = nil
    Bot.AllyLane = nil
    Bot.AllyCastSeen = nil
    Bot.AllyLaneLatch = nil
    Bot.AbandonUntil = 0
    Bot.TeamOffLevelSince = nil
    Bot.TeamOffLevelName = nil
    Bot.KiteArrived = false
    Bot.TeamClosing = nil
    Bot.InterceptUntil = 0
    Bot.InterceptDmg = 0
    Bot.FarPathTarget, Bot.FarPathFails, Bot.FarPathBest, Bot.FarPathFailAt = nil, 0, 0, 0
    Bot.LastFFAt = 0
    Bot.HostilesNear = 0
    Bot.Hostiles = 0
    Bot.BurstAt = 0
    Bot.Refused = nil
    Bot.AllyLaneAt = 0
    Bot.ReactSoft = false
    Bot.ReactPrevMelee = false
    Bot.FFHeldAt = nil
    if Bot.BlockActive then releaseBlock() end
    Bot.DefendVs = nil
    Bot.DefendVsUntil = 0
    Bot.DefendVsSince = 0
    Bot.DefendVsRest = 0
    Bot.DefendVsSwinging = false
    Bot.MoveDirPrev = nil
    Bot.PaceFrom = nil
    Bot.PaceArmed = false
    Bot.RevPending, Bot.RevGoal = 0, nil
    Bot.PerchSide = nil
    Bot.LastSwinger = nil
    Bot.RecoverUntil, Bot.RecoverMode, Bot.RecoverDir = 0, nil, nil
    Bot.DefendKeepVs, Bot.DefendKept = nil, false
    Bot.BlockSwings, Bot.SwingName = 0, nil
    Bot.InDomain, Bot.MapPrevPos, Bot.MapPrevAt = false, nil, 0
    Bot.TargetOffLevelSince = nil
    restoreDebris()
    Bot.UsedSkillsThisFight = {}
    AutoState.wastedAt = -999
    AutoState.wastedBackoffUntil = 0
    debug("=== BOT STOPPED ===")
end


AutoStartBot = startBot
AutoStopBot = stopBot





















CharPool = {
    "Gojo", "Itadori", "Hakari", "Megumi", "Mahito", "Choso", "Todo",
    "Hiromi", "Yuta", "Mechamaru", "Naoya", "Nanami", "Hanami", "Ryu",
    "Reggie", "Locust", "Yuki", "Charles", "Haruta", "MeiMei",
    "Kurourushi", "Uro",
}


















local CharAvoid = {
    Haruta = true,

    Hakari = true,

    Uro = true,


}



function charAllowed(n)
    return true   -- solo: no whitelist, no per-account denies; memory decides
end

local function charAvailable()
    local pool = {}
    for _, n in ipairs(CharPool) do
        if not CharAvoid[n] and not memCharLocked(n) and charAllowed(n) then table.insert(pool, n) end
    end







    if #pool <= 1 then
        local cleared = memClearLocks()
        if cleared > 0 then
            debug(string.format("all characters were locked - cleared %d and retrying", cleared))
            pool = {}


            for _, n in ipairs(CharPool) do
                if not CharAvoid[n] and charAllowed(n) then table.insert(pool, n) end
            end
        end
    end

    if Workspace:GetAttribute("AllowOP") then
        if not memCharLocked("Heian") then table.insert(pool, "Heian") end
        if not memCharLocked("Goku") then table.insert(pool, "Goku") end
    end
    if LocalPlayer:GetAttribute("Goku") and not memCharLocked("Goku") then
        table.insert(pool, "Goku")
    end
    if LocalPlayer:GetAttribute("Mokou") and not memCharLocked("Mokou") then
        table.insert(pool, "Mokou")
    end
    return pool
end

AutoState = {
    wantOn = false,
    pendingChar = nil,
    pendingAt = 0,
    lastSwitch = 0,
    livesOnChar = 0,
    attempts = 0,
    switching = false,
    lastChangeAt = -999,
    lastFireAt = -999,
    queued = nil,
    queuedWhy = nil,
    needSwitch = false,
    waitingSince = nil,
    idleSince = nil,
    spawnedAt = 0,
    spawnHP = 0,
    wastedAt = -999,
    wastedBackoffUntil = 0,
}










function autoPickChar()
    local pool = charAvailable()
    if #pool == 0 then return nil end

    local current = getChar() and getChar():GetAttribute("Moveset")














    local function candidates(historyDepth)
        local out = {}
        local recent = memRecentChars()
        for _, n in ipairs(pool) do
            local blocked = (n == current)
            if not blocked and historyDepth > 0 then
                for i = math.max(1, #recent - historyDepth + 1), #recent do
                    if recent[i] == n then blocked = true break end
                end
            end


            if not blocked and memCharFails(n) >= (Config.CharMaxAttempts or 3) and not memCharRested(n) then
                blocked = true
            end
            if not blocked then table.insert(out, n) end
        end
        return out
    end

    local cands = candidates(Config.CharNoRepeat)
    local depth = Config.CharNoRepeat
    while #cands == 0 and depth > 0 do
        depth = depth - 1
        cands = candidates(depth)
    end
    if #cands == 0 then return nil end







    local untried, rested = {}, {}
    for _, n in ipairs(cands) do
        if memCharLives(n) < Config.CharMinLives then
            if memCharFails(n) == 0 then
                table.insert(untried, n)
            elseif memCharRested(n) then
                table.insert(rested, n)
            end
        end
    end
    if #untried > 0 then
        return untried[math.random(1, #untried)], "untried"
    end
    if #rested > 0 and math.random() < Config.CharRetryChance then
        local pick = rested[math.random(1, #rested)]
        return pick, string.format("retry after %d failures", memCharFails(pick))
    end







    local best, bestScore = nil, -1
    local weights, total = {}, 0
    local careerAvg = memCareerAvg() or 0
    local benched = {}
    for _, n in ipairs(cands) do
        local sc = memCharScore(n) or 0



        if careerAvg > 0 and memCharLives(n) >= (Config.CharFloorLives or 10)
           and sc < (Config.CharFloorRatio or 0.8) * careerAvg then
            table.insert(benched, n)
            sc = 0
        end
        if sc > bestScore then best, bestScore = n, sc end
        weights[n] = sc
        total = total + sc
    end
    if #benched > 0 then
        debugEvery("bench", 20, "benched: " .. table.concat(benched, ", "))

        if math.random() < (Config.CharBenchExplore or 0.10) then
            return benched[math.random(1, #benched)], "bench explore"
        end
    end
    if total <= 0 then
        local pick = cands[math.random(1, #cands)]
        return pick, "no scores yet"
    end


    local pow, sum = {}, 0
    for n, w in pairs(weights) do
        local v = (w / bestScore) ^ Config.CharBias
        pow[n] = v
        sum = sum + v
    end

    local roll = math.random() * sum
    for _, n in ipairs(cands) do
        roll = roll - (pow[n] or 0)
        if roll <= 0 then

            local _, a, l = memCharScore(n)
            return n, string.format("scored %.0f: all %.0f, last %.0f", weights[n] or 0, a or 0, l or 0)
        end
    end
    local _, a, l = memCharScore(best)
    return best, string.format("best, scored %.0f: all %.0f, last %.0f", bestScore, a or 0, l or 0)
end

















function autoCanChange()

    local sinceFire = tick() - (AutoState.lastFireAt or -999)
    if sinceFire < Config.ChangeSpamGuard then
        return false, Config.CharChangeCooldown - (Config.ChangeSpamGuard - sinceFire)
    end

    local since = tick() - (AutoState.lastChangeAt or -999)
    return since >= Config.CharChangeCooldown, since
end

function autoRequestChar(name, why)
    if not name then return false end

    local ready, since = autoCanChange()
    if not ready then




        local wait = Config.CharChangeCooldown - since
        debug(string.format("change to %s deferred %.1fs (cooldown)", name, wait))
        AutoState.queued = name
        AutoState.queuedWhy = why

        task.delay(wait + 0.3, function()
            if AutoState.queued == name then
                AutoState.queued = nil
                autoRequestChar(name, AutoState.queuedWhy or why)
            end
        end)









        task.delay(wait + Config.SwitchRespawnTimeout + 2, function()
            if AutoState.queued == name then
                debug("queued change to " .. name .. " never fired - clearing")
                AutoState.queued = nil
                AutoState.needSwitch = false
            end
        end)
        return false
    end

    AutoState.pendingChar = name
    AutoState.pendingAt = tick()
    AutoState.lastFireAt = tick()
    AutoState.attempts = (AutoState.attempts or 0) + 1


    AutoState.switching = true

    debug(string.format("switching to %s (%s) - forces a respawn", name, tostring(why)))
    local sent = fireRemote("JoinService", "Change", name)








    task.delay(Config.SwitchRespawnTimeout, function()
        if AutoState.pendingChar ~= name then return end






        if autoHitSinceSpawn() then
            debug(string.format("%s refused while in combat - not counting it against them", name))
            AutoState.pendingChar = nil
            AutoState.attempts = 0
            AutoState.needSwitch = false



            AutoState.wastedBackoffUntil = tick() + Config.WastedLifeRetry
            if AutoState.wantOn and not Config.Enabled and isAlive() then
                AutoStartBot()
            end
            return
        end

        memNoteCharFail(name)
        AutoState.wastedBackoffUntil = tick() + Config.WastedLifeRetry
        debug(string.format("%s produced no respawn in %ds - failure %d, backing off",
            name, Config.SwitchRespawnTimeout, memCharFails(name)))

        AutoState.pendingChar = nil
        AutoState.attempts = 0


        if AutoState.needSwitch and AutoState.wantOn then
            local alt, why2 = autoPickChar()
            if alt and alt ~= name then
                autoRequestChar(alt, why2 or "after failure")
                return
            end
            AutoState.needSwitch = false
        end
        if AutoState.wantOn and not Config.Enabled and isAlive() then
            debug("no swap available - fighting as " ..
                  tostring(getChar() and getChar():GetAttribute("Moveset")))
            AutoStartBot()
        end
    end)

    return sent
end


function autoIsSwitching()
    if not AutoState.switching then return false end

    if tick() - AutoState.pendingAt > 12 then
        AutoState.switching = false
        return false
    end
    return true
end













function autoVerifyChar(char)
    if not AutoState.pendingChar then return end

    local set = char and char:GetAttribute("Moveset")
    if not set then
        for _ = 1, 8 do
            task.wait(0.25)
            set = char and char:GetAttribute("Moveset")
            if set then break end
        end
    end
    if not set then
        debug("verify: no Moveset attribute yet, leaving " ..
              tostring(AutoState.pendingChar) .. " pending")
        return
    end

    if set == AutoState.pendingChar then
        debug("now playing " .. set)
        AutoState.lastChangeAt = tick()
        memClearCharFail(set)
        memNoteCharPlayed(set)
        AutoState.pendingChar = nil
        AutoState.attempts = 0
        AutoState.livesOnChar = 0
        return
    end

    if (AutoState.attempts or 0) >= Config.CharMaxAttempts then






        memLockChar(AutoState.pendingChar)
        debug(string.format(
            "%s did not apply after %d spaced attempts (still %s) - shelved for %d min",
            AutoState.pendingChar, AutoState.attempts, tostring(set),
            math.floor(Config.CharLockExpiry / 60)))
        AutoState.pendingChar = nil
        AutoState.attempts = 0
    else
        local want = AutoState.pendingChar
        debug(string.format("%s did not take (got %s), retrying after the cooldown",
            want, tostring(set)))
        autoRequestChar(want, "retry")
    end
end


function autoSwitchNow()
    local pick, why = autoPickChar()
    if not pick then
        announce("no other character available")
        return false
    end
    announce("swapping to " .. pick)
    AutoState.livesOnChar = 0
    return autoRequestChar(pick, why or "manual")
end











function autoOnDeath()
    if not AutoState.wantOn then return end



    if autoIsSwitching() then return end

    AutoState.livesOnChar = (AutoState.livesOnChar or 0) + 1

    if not Config.AutoCharacter then return end
    if Config.CharSwitchEveryLife
       or AutoState.livesOnChar >= Config.CharSwitchLives then
        AutoState.needSwitch = true
    end
end















































function autoHitWithin(sec)
    local hitAt = math.max(Sensed.hitAt or 0, Bot.LastHurtAt or 0)
    return hitAt > 0 and (tick() - hitAt) < sec
end

function autoHitSinceSpawn()
    local spawnAt = AutoState.spawnedAt or 0
    if spawnAt <= 0 then return false end

    local hitAt = math.max(Sensed.hitAt or 0, Bot.LastHurtAt or 0)
    if hitAt > spawnAt then return true end


    local hp = getHP()
    if hp and (AutoState.spawnHP or 0) > 0 and hp < (AutoState.spawnHP - 1) then
        return true
    end
    return false
end

function autoOnSpawn(char)
    AutoState.switching = false

    local was = AutoState.pendingChar
    autoVerifyChar(char)


    if was and not AutoState.pendingChar then
        AutoState.needSwitch = false
        AutoState.waitingSince = nil
    end

    if not Config.AutoRestart or not AutoState.wantOn then return end


    if AutoState.needSwitch and not AutoState.pendingChar and not AutoState.queued then
        local pick, why = autoPickChar()
        if pick then
            AutoState.waitingSince = tick()






            task.delay(Config.SwitchSettle, function()
                if not (AutoState.needSwitch and not AutoState.pendingChar
                        and not AutoState.queued) then return end









                if autoHitSinceSpawn() then
                    debug("hit during spawn - combat lock, skipping the swap")
                    AutoState.needSwitch = false
                    if AutoState.wantOn and not Config.Enabled and isAlive() then
                        AutoStartBot()
                    end
                    return
                end

                autoRequestChar(pick, why or "new life")
            end)
            return
        end

        AutoState.needSwitch = false
    end






    if AutoState.pendingChar or AutoState.queued then
        if not AutoState.waitingSince then AutoState.waitingSince = tick() end

        task.delay(Config.SwitchWaitMax, function()
            if not AutoState.wantOn or Config.Enabled then return end
            if not isAlive() then return end
            if AutoState.pendingChar or AutoState.queued then
                debug("switch still not landed - starting anyway")
                AutoState.needSwitch = false
                AutoState.pendingChar = nil
                AutoState.queued = nil
                AutoStartBot()
            end
        end)
        return
    end


    task.delay(Config.RestartDelay, function()
        if not AutoState.wantOn then return end
        if Config.Enabled then return end
        if not isAlive() then return end
        if AutoState.pendingChar or AutoState.queued then return end


        local waited = 0
        while waited < 3 do
            local ms = char and char:FindFirstChild("Moveset")
            if ms and #ms:GetChildren() > 0 then break end
            task.wait(0.25)
            waited = waited + 0.25
        end
        if not AutoState.wantOn or Config.Enabled or not isAlive() then return end
        if AutoState.pendingChar or AutoState.queued then return end

        debug("starting as " .. tostring(char and char:GetAttribute("Moveset")))
        AutoStartBot()
    end)
end













function autoCheckWastedLife()
    if not Config.AutoCharacter or not AutoState.wantOn then return end
    if not Config.Enabled or not isAlive() then return end
    if AutoState.pendingChar or AutoState.queued then return end





    if (AutoState.spawnedAt or 0) <= 0 then return end

    local lifeFor = tick() - (AutoState.spawnedAt or tick())
    if lifeFor < Config.WastedLifeAfter then return end

    if memLifeDmg() > Config.WastedLifeDamage then return end
    if memLifeEngaged() > Config.WastedLifeEngaged then return end
















    if tick() - (AutoState.wastedAt or -999) < Config.WastedLifeRetry then return end
    if tick() < (AutoState.wastedBackoffUntil or 0) then return end
    if autoHitWithin(Config.SpawnCombatWindow) then return end

    debug(string.format(
        "life going nowhere: %.0fs, %.0f damage, %.0f%% engaged - respawning",
        lifeFor, memLifeDmg(), memLifeEngaged() * 100))

    AutoState.wastedAt = tick()
    local pick, why = autoPickChar()
    if pick then
        AutoState.needSwitch = false
        autoRequestChar(pick, why or "wasted life")
    end
end































local function logSnapshot()
    debug("=== state at logging start ===")
    debug(string.format("sense: %d effect services hooked | Sense=%s Threat=%s",
        senseHookCount(), tostring(Config.Sense), tostring(Config.Threat)))

    local n, counts, links = mapStats()
    debug(string.format("map: %d cells (%dH/%dR/%dD), %d roads",
        n, counts.HOT, counts.RICH, counts.DEAD, links))

    local c = MEM.career
    debug(string.format("career: %d lives, avg %.0f, best %.0f | stall threshold %.2f dmg/s",
        c.lives or 0, (c.lives or 0) > 0 and (c.dmg / c.lives) or 0,
        c.best or 0, memStallThreshold()))

    local st = MEM.stats or {}

    local tot = (st.clean or 0) + (st.shared or 0) + (st.dirty or 0)
    debug(string.format("samples: %d clean / %d shared / %d dirty (%d%% booked)",
        st.clean or 0, st.shared or 0, st.dirty or 0,
        tot > 0 and math.floor(((st.clean or 0) + (st.shared or 0)) / tot * 100) or 0))
    local rep = memCharReport()
    if rep ~= "" then debug("characters (dmg/life): " .. rep) end
    debug("=== end snapshot ===")
end



local FF_HUD_REFRESH = nil
local function updateUI()
    if type(FF_HUD_REFRESH) == "function" then pcall(FF_HUD_REFRESH) end
end

















function heapLine()
    local every = Config.HeapLineEvery or 60
    if every <= 0 then return end
    local nowC = os.clock()
    if nowC - (Bot.ProbeAt or 0) >= 1 then
        Bot.ProbeAt = nowC
        local t0 = os.clock()
        for _ = 1, 2000 do local _ = os.clock() end
        local ring = Bot.ProbeRing
        if not ring then ring = {}; Bot.ProbeRing = ring end
        local i = (Bot.ProbeI or 0) % 60 + 1
        ring[i] = (os.clock() - t0) * 1e6
        Bot.ProbeI = i
    end
    if nowC - (Bot.HeapAt or 0) < every then return end
    Bot.HeapAt = nowC
    local function count(tb)
        local n, dead = 0, 0
        if type(tb) == "table" then
            for k in pairs(tb) do
                n = n + 1
                if typeof(k) == "Instance" and k.Parent == nil then dead = dead + 1 end
            end
        end
        return n, dead
    end
    local okH, heap = pcall(collectgarbage, "count")
    if not okH or type(heap) ~= "number" then heap = -1 end
    local probe, ring = -1, Bot.ProbeRing
    if ring and #ring > 0 then
        local tmp = {}
        for i = 1, #ring do tmp[i] = ring[i] end
        table.sort(tmp)
        probe = tmp[math.ceil(#tmp / 2)]
    end
    local eN, eD = count(Enemy)
    local fx = Workspace:FindFirstChild("Effects")
    debugEvery("heap", every, string.format(
        "heap %.0f KB | ours: Enemy %d (dead %d) SpeedNorm %d SenseHooked %d Threat %d DmgFrom %d BadTargets %d pending %d opponents %d debugOnceAt %d | fx %d players %d | probe %.0f us",
        heap, eN, eD, (count(SpeedNorm)), (count(SenseHooked)), (count(Threat)), (count(Bot.DmgFrom)),
        (count(Bot.BadTargets)), #pending, (count(MEM.opponents)), (count(debugOnceAt)),
        fx and #fx:GetChildren() or 0, #Players:GetPlayers(), probe))
end

task.spawn(function()
    while task.wait(0.2) do
        pcall(function()
            if AutoState.wantOn and not Config.Enabled and isAlive() then
                if AutoState.pendingChar or AutoState.queued then
                    AutoState.idleSince = nil
                else
                    AutoState.idleSince = AutoState.idleSince or os.clock()
                    if os.clock() - AutoState.idleSince > Config.WatchdogIdle then
                        AutoState.idleSince = nil
                        debug("watchdog: should be running but is not - starting")
                        pcall(startBot)
                    end
                end
            else
                AutoState.idleSince = nil
            end
        end)
        pcall(autoCheckWastedLife)
        pcall(heapLine)
    end
end)









-- ============================================================================
--  THE EYE  --  HUD
--
--  Obsidian, ember and ash. A single black slab with a lidless eye set in the
--  top of it: dark and half-shut while the bot sleeps, open and burning while
--  it fights, flaring crimson when the fighter is hurt. Embers drift up the
--  face of the slab. Two dominions (skins): Barad-dur, ember on obsidian, and
--  Minas Morgul, witch-light on black stone.
--
--  Everything is built from Roblox GUI instances only (no asset ids): frames,
--  gradients, strokes and tweens, so it draws the same on every executor.
-- ============================================================================

local FF_ENV = (typeof(getgenv) == "function" and getgenv()) or _G
local FF_THEME_FILE = "JJK_EyeTheme.txt"
local TweenService = game:GetService("TweenService")

local Theme = {
    name  = "baraddur",
    order = { "baraddur", "morgul" },
    conns = nil,
    rebuild = nil,
    reopenSettings = nil,
}

Theme.defs = {
    baraddur = {
        label   = "Barad-dur",
        bg      = Color3.fromRGB(7, 5, 5),        -- obsidian
        bg2     = Color3.fromRGB(15, 10, 9),      -- the slab, lit from above
        bg3     = Color3.fromRGB(28, 18, 15),     -- raised stone
        txt     = Color3.fromRGB(216, 198, 170),  -- bone
        dim     = Color3.fromRGB(116, 96, 80),    -- ash
        accent  = Color3.fromRGB(255, 118, 20),   -- ember
        accent2 = Color3.fromRGB(255, 214, 96),   -- molten core
        good    = Color3.fromRGB(255, 140, 36),
        bad     = Color3.fromRGB(172, 22, 26),    -- dried blood
        ink     = Color3.fromRGB(5, 3, 3),
        stroke  = Color3.fromRGB(74, 38, 18),
        rule    = Color3.fromRGB(64, 34, 18),
        aura    = Color3.fromRGB(52, 18, 8),
        font    = Enum.Font.Garamond,
        fontB   = Enum.Font.Antique,
        fontM   = Enum.Font.Code,
        title   = "B A R A D - D Û R",
        sub     = "the eye is upon them",
        awake   = "A W A K E N   T H E   E Y E",
        sleep   = "C L O S E   T H E   E Y E",
        idle    = "the eye sleeps",
        marked  = "T H E   M A R K E D",
        release = "R E L E A S E   T H E   M A R K",
        runes   = "R U N E S",
    },

    morgul = {
        label   = "Minas Morgul",
        bg      = Color3.fromRGB(4, 7, 6),
        bg2     = Color3.fromRGB(8, 14, 12),
        bg3     = Color3.fromRGB(13, 26, 22),
        txt     = Color3.fromRGB(188, 212, 198),
        dim     = Color3.fromRGB(80, 110, 98),
        accent  = Color3.fromRGB(110, 255, 170),  -- witch-light
        accent2 = Color3.fromRGB(214, 255, 230),
        good    = Color3.fromRGB(110, 255, 170),
        bad     = Color3.fromRGB(150, 36, 90),
        ink     = Color3.fromRGB(3, 5, 4),
        stroke  = Color3.fromRGB(22, 64, 48),
        rule    = Color3.fromRGB(20, 54, 42),
        aura    = Color3.fromRGB(8, 46, 32),
        font    = Enum.Font.Garamond,
        fontB   = Enum.Font.Antique,
        fontM   = Enum.Font.Code,
        title   = "M I N A S   M O R G U L",
        sub     = "the dead do not sleep",
        awake   = "R A I S E   T H E   D E A D",
        sleep   = "L E T   T H E M   R E S T",
        idle    = "the tower is silent",
        marked  = "T H E   D O O M E D",
        release = "R E L E A S E   T H E   M A R K",
        runes   = "R U N E S",
    },
}

function Theme.p()
    local d = Theme.defs[Theme.name]
    if d == nil then return Theme.defs.baraddur end
    return d
end

function Theme.dropConns()
    local c = Theme.conns
    Theme.conns = nil
    if type(c) ~= "table" then return end
    for _, conn in ipairs(c) do
        pcall(function() conn:Disconnect() end)
    end
end

function Theme.set(name, quiet)
    if Theme.defs[name] == nil then return false end
    Theme.name = name
    pcall(function() rawset(FF_ENV, "__JJK_EYE_THEME", name) end)
    if type(writefile) == "function" then pcall(writefile, FF_THEME_FILE, name) end
    if type(Theme.rebuild) == "function" then
        Theme.dropConns()
        local ok, err = pcall(Theme.rebuild)
        if not ok then
            debug("[theme] rebuild failed: " .. tostring(err))
            return false
        end
    end
    if not quiet then debug("[theme] " .. tostring(Theme.p().label)) end
    return true
end

function Theme.cycle()
    local at = 1
    for i, n in ipairs(Theme.order) do
        if n == Theme.name then at = i end
    end
    local nxt = Theme.order[at + 1]
    if nxt == nil then nxt = Theme.order[1] end
    return Theme.set(nxt)
end

do
    local saved = rawget(FF_ENV, "__JJK_EYE_THEME")
    if type(saved) ~= "string" and type(readfile) == "function" and type(isfile) == "function" then
        local okE, exists = pcall(isfile, FF_THEME_FILE)
        if okE and exists then
            local ok, raw = pcall(readfile, FF_THEME_FILE)
            if ok and type(raw) == "string" then saved = raw end
        end
    end
    if type(saved) == "string" and Theme.defs[saved] ~= nil then
        Theme.name = saved
    end
end

-- Ember mode: the one thermal lever a phone needs, kept as a rune instead of
-- being forced at load. Quality floor + fps cap on, everything back off.
Config.EmberMode = false
local function applyEmberMode(on)
    pcall(function()
        local ugs = UserSettings():GetService("UserGameSettings")
        ugs.SavedQualityLevel = on and Enum.SavedQualitySetting.QualityLevel1
                                   or Enum.SavedQualitySetting.Automatic
    end)
    pcall(function()
        if typeof(setfpscap) == "function" then
            setfpscap(on and (tonumber(FF_ENV.JJK_PhoneFpsCap) or 30) or 0)
        end
    end)
end

do
    local function buildHUD()

        local TP      = Theme.p()
        local BG      = TP.bg
        local BG2     = TP.bg2
        local BG3     = TP.bg3
        local TXT     = TP.txt
        local DIM     = TP.dim
        local ACCENT  = TP.accent
        local ACCENT2 = TP.accent2
        local GOOD    = TP.good
        local BAD     = TP.bad
        local INK     = TP.ink
        local FONT    = TP.font
        local FONTB   = TP.fontB
        local FONTM   = TP.fontM

        local PANEL_W, PANEL_H = 320, 424

        local function mk(class, props)
            local o = Instance.new(class)
            for k, v in pairs(props) do
                if k ~= "Parent" then o[k] = v end
            end
            if props.Parent then o.Parent = props.Parent end
            return o
        end

        local function corner(o, r)
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, r or 4)
            c.Parent = o
            return c
        end

        local function pill(o)
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(1, 0)
            c.Parent = o
            return c
        end

        local function stroke(o, colour, thick, trans)
            return mk("UIStroke", {
                Color = colour, Thickness = thick or 1, Transparency = trans or 0,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o,
            })
        end

        local function gradient(o, c1, c2, rotation, t1, t2)
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, c1),
                ColorSequenceKeypoint.new(1, c2),
            })
            if t1 or t2 then
                g.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, t1 or 0),
                    NumberSequenceKeypoint.new(1, t2 or 0),
                })
            end
            g.Rotation = rotation or 90
            g.Parent = o
            return g
        end

        -- A hairline that burns in the middle and dies at both ends.
        local function rule(y, parent, w, x)
            local r = mk("Frame", {
                Size = UDim2.new(0, w or (PANEL_W - 40), 0, 1),
                Position = UDim2.new(0, x or 20, 0, y),
                BackgroundColor3 = ACCENT, BorderSizePixel = 0, ZIndex = 52, Parent = parent or nil,
            })
            local g = Instance.new("UIGradient")
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 0.35),
                NumberSequenceKeypoint.new(1, 1),
            })
            g.Rotation = 0
            g.Parent = r
            return r
        end

        local function tween(o, t, props, style, dir)
            local ok, tw = pcall(function()
                return TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Sine,
                    dir or Enum.EasingDirection.InOut), props)
            end)
            if ok and tw then tw:Play() end
            return ok and tw or nil
        end

        local function short(s, n)
            s = tostring(s or "?")
            if #s > n then return string.sub(s, 1, n - 1) .. "." end
            return s
        end

        local function fmtClock(sec)
            sec = math.max(0, math.floor(tonumber(sec) or 0))
            return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
        end

        local function nameOf(char, fallback)
            if not char then return fallback or "?" end
            local ok, plr = pcall(function() return Players:GetPlayerFromCharacter(char) end)
            if ok and plr then return plr.Name end
            if fallback then return fallback end
            local ok2, n = pcall(function() return char.Name end)
            if ok2 and n then return n end
            return "?"
        end

        local function numOf(fn, arg)
            local ok, v = pcall(fn, arg)
            if ok and type(v) == "number" then return v end
            return 0
        end

        -- ------------------------------------------------------------ parent
        local parentTarget = nil
        local okCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
        if okCore and coreGui then parentTarget = coreGui end
        if typeof(gethui) == "function" then
            local okHui, hidden = pcall(gethui)
            if okHui and hidden then parentTarget = hidden end
        end
        if not parentTarget then
            parentTarget = LocalPlayer:WaitForChild("PlayerGui")
        end

        pcall(function()
            for _, child in ipairs(parentTarget:GetChildren()) do
                if child:IsA("ScreenGui") and (child:GetAttribute("EyeHUD") or child:GetAttribute("FocusFightHUD")) then
                    child:Destroy()
                end
            end
        end)

        local gui = mk("ScreenGui", {
            Name = "EYE_" .. tostring(math.random(100000, 999999)), ResetOnSpawn = false,
            IgnoreGuiInset = true, DisplayOrder = 999,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
        pcall(function() gui:SetAttribute("EyeHUD", true) end)
        gui.Parent = parentTarget

        local conns = {}
        Theme.conns = conns
        local function bind(signal, fn)
            local c = signal:Connect(fn)
            table.insert(conns, c)
            return c
        end

        -- ------------------------------------------------------------- slab
        local panel = mk("Frame", {
            Name = "Slab", Size = UDim2.new(0, PANEL_W, 0, PANEL_H),
            Position = UDim2.new(0, 18, 0, 70), BackgroundColor3 = BG2, BorderSizePixel = 0,
            ZIndex = 50, Parent = gui,
        })
        corner(panel, 5)
        gradient(panel, BG2, BG, 90)
        stroke(panel, TP.stroke, 1, 0)

        -- Fit the slab to a short phone screen: scale down, never up.
        local scale = mk("UIScale", { Scale = 1, Parent = panel })
        local function fitScale()
            local ok, vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
            if not ok or not vp then return end
            local s = math.clamp((vp.Y - 24) / (PANEL_H + 12), 0.62, 1)
            scale.Scale = s
        end
        fitScale()
        pcall(function()
            bind(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fitScale)
        end)

        -- Halo: two rings of ember outside the slab, fading as they widen.
        local halo1 = mk("Frame", {
            Size = UDim2.new(1, 4, 1, 4), Position = UDim2.new(0, -2, 0, -2),
            BackgroundTransparency = 1, ZIndex = 49, Parent = panel,
        })
        corner(halo1, 7)
        local haloStroke1 = stroke(halo1, ACCENT, 2, 0.78)
        local halo2 = mk("Frame", {
            Size = UDim2.new(1, 14, 1, 14), Position = UDim2.new(0, -7, 0, -7),
            BackgroundTransparency = 1, ZIndex = 49, Parent = panel,
        })
        corner(halo2, 10)
        local haloStroke2 = stroke(halo2, ACCENT, 8, 0.94)

        -- The inlay: a second, fainter line a few pixels inside the edge, the
        -- way a forged plate is chased along its border.
        local inlay = mk("Frame", {
            Size = UDim2.new(1, -8, 1, -8), Position = UDim2.new(0, 4, 0, 4),
            BackgroundTransparency = 1, ZIndex = 51, Parent = panel,
        })
        corner(inlay, 3)
        stroke(inlay, ACCENT, 1, 0.82)

        -- Embers: a handful of motes drifting up the face of the slab.
        local emberField = mk("Frame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            ClipsDescendants = true, ZIndex = 51, Parent = panel,
        })
        corner(emberField, 5)
        local motes = {}
        for i = 1, 9 do
            local m = mk("Frame", {
                Size = UDim2.new(0, 2, 0, 2), Position = UDim2.new(math.random(), 0, 1.05, 0),
                BackgroundColor3 = (i % 3 == 0) and ACCENT2 or ACCENT, BorderSizePixel = 0,
                BackgroundTransparency = 1, ZIndex = 51, Parent = emberField,
            })
            pill(m)
            motes[i] = m
        end

        -- ------------------------------------------------------------ header
        local header = mk("Frame", {
            Name = "Header", Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1,
            Active = true, ZIndex = 52, Parent = panel,
        })

        local titleLbl = mk("TextLabel", {
            Size = UDim2.new(0, 210, 0, 20), Position = UDim2.new(0, 16, 0, 10),
            BackgroundTransparency = 1, Font = FONTB, Text = TP.title,
            TextSize = 15, TextColor3 = ACCENT2, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 53, Parent = header,
        })
        gradient(titleLbl, ACCENT2, ACCENT, 0)
        local subLbl = mk("TextLabel", {
            Size = UDim2.new(0, 210, 0, 14), Position = UDim2.new(0, 17, 0, 29),
            BackgroundTransparency = 1, Font = FONT, Text = TP.sub,
            TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 53, Parent = header,
        })

        local function headerBtn(x, glyph, colour)
            local b = mk("TextButton", {
                Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, x, 0, 12),
                BackgroundColor3 = BG3, BorderSizePixel = 0, AutoButtonColor = true,
                Font = FONTB, Text = glyph, TextSize = 14, TextColor3 = colour,
                ZIndex = 53, Parent = header,
            })
            corner(b, 3)
            stroke(b, TP.stroke, 1, 0.2)
            return b
        end
        local gearBtn  = headerBtn(-100, "◆", ACCENT)
        local minBtn   = headerBtn(-70,  "—", TXT)
        local closeBtn = headerBtn(-40,  "×", BAD)

        rule(50, panel, PANEL_W - 32, 16)

        -- --------------------------------------------------------------- eye
        -- A lidless eye: a horizontal lens of fire with a black slit. It sits
        -- half-shut while the bot sleeps and opens when it wakes.
        local EYE_W, EYE_OPEN, EYE_SHUT = 132, 32, 5
        local eyeZone = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 54), Position = UDim2.new(0, 0, 0, 52),
            BackgroundTransparency = 1, ZIndex = 52, Parent = panel,
        })
        local eyeGlow = mk("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, EYE_W + 40, 0, EYE_OPEN + 14),
            Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = ACCENT,
            BackgroundTransparency = 0.86, BorderSizePixel = 0, ZIndex = 52, Parent = eyeZone,
        })
        pill(eyeGlow)
        do
            local g = Instance.new("UIGradient")
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 0),
                NumberSequenceKeypoint.new(1, 1),
            })
            g.Rotation = 0
            g.Parent = eyeGlow
        end
        local eye = mk("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, EYE_W, 0, EYE_SHUT),
            Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0, ZIndex = 53, Parent = eyeZone,
        })
        pill(eye)
        local eyeGrad = Instance.new("UIGradient")
        local function eyeColours(hot)
            local edge = hot and BAD or Color3.fromRGB(40, 8, 4)
            local mid  = hot and ACCENT2 or ACCENT
            local core = hot and Color3.new(1, 1, 1) or ACCENT2
            eyeGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,    edge),
                ColorSequenceKeypoint.new(0.3,  mid),
                ColorSequenceKeypoint.new(0.5,  core),
                ColorSequenceKeypoint.new(0.7,  mid),
                ColorSequenceKeypoint.new(1,    edge),
            })
        end
        eyeColours(false)
        eyeGrad.Rotation = 0
        eyeGrad.Parent = eye
        local eyeStroke = stroke(eye, ACCENT, 1, 0.35)
        local slit = mk("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 9, 1, -4),
            Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = INK,
            BorderSizePixel = 0, ZIndex = 54, Parent = eye,
        })
        pill(slit)
        -- The eye's whisper, right of the lens: what it is doing in one word.
        local eyeWord = mk("TextLabel", {
            Size = UDim2.new(0, 84, 0, 54), Position = UDim2.new(1, -96, 0, 0),
            BackgroundTransparency = 1, Font = FONT, Text = TP.idle, TextWrapped = true,
            TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 53, Parent = eyeZone,
        })

        -- ----------------------------------------------------------- drag
        local dragging, dragInput, dragStart, dragOrigin = false, nil, nil, nil

        bind(header.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                dragOrigin = panel.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)

        bind(header.InputChanged, function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)

        bind(UserInputService.InputChanged, function(input)
            if dragging and input == dragInput and dragStart and dragOrigin then
                local delta = input.Position - dragStart
                panel.Position = UDim2.new(
                    dragOrigin.X.Scale, dragOrigin.X.Offset + delta.X,
                    dragOrigin.Y.Scale, dragOrigin.Y.Offset + delta.Y
                )
            end
        end)

        -- ------------------------------------------------------ the command
        local startBtn = mk("TextButton", {
            Size = UDim2.new(0, PANEL_W - 32, 0, 40), Position = UDim2.new(0, 16, 0, 108),
            BackgroundColor3 = BG3, BorderSizePixel = 0, AutoButtonColor = true,
            Font = FONTB, Text = TP.awake, TextSize = 13, TextColor3 = ACCENT2,
            ZIndex = 52, Parent = panel,
        })
        corner(startBtn, 3)
        local startGrad = gradient(startBtn, TP.aura, BG3, 0)
        startGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   TP.aura),
            ColorSequenceKeypoint.new(0.5, BG3),
            ColorSequenceKeypoint.new(1,   TP.aura),
        })
        local startStroke = stroke(startBtn, ACCENT, 1, 0.25)

        local lastToggle = 0
        local function toggleBot()
            if os.clock() - lastToggle < 0.35 then return end
            lastToggle = os.clock()
            if Config.Enabled then AutoState.wantOn = false end
            local ok, err = pcall(function()
                if Config.Enabled then stopBot() else startBot() end
            end)
            if not ok then debug("start/stop failed: " .. tostring(err)) end
        end
        startBtn.MouseButton1Click:Connect(toggleBot)

        -- --------------------------------------------------- vitality / wrath
        local function barLabel(x, text, align)
            return mk("TextLabel", {
                Size = UDim2.new(0, 140, 0, 10), Position = UDim2.new(0, x, 0, 154),
                BackgroundTransparency = 1, Font = FONTB, Text = text, TextSize = 9,
                TextColor3 = DIM, TextXAlignment = align, ZIndex = 52, Parent = panel,
            })
        end
        barLabel(16, "V I T A L I T Y", Enum.TextXAlignment.Left)
        barLabel(PANEL_W - 156, "W R A T H", Enum.TextXAlignment.Right)

        local function bar(x, w, colour)
            local track = mk("Frame", {
                Size = UDim2.new(0, w, 0, 4), Position = UDim2.new(0, x, 0, 166),
                BackgroundColor3 = BG3, BorderSizePixel = 0, ZIndex = 52, Parent = panel,
            })
            pill(track)
            stroke(track, TP.stroke, 1, 0.4)
            local fill = mk("Frame", {
                Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = colour,
                BorderSizePixel = 0, ZIndex = 53, Parent = track,
            })
            pill(fill)
            gradient(fill, colour, ACCENT2, 0)
            return track, fill
        end
        local _, hpFill = bar(16, 140, ACCENT)
        local _, ultFill = bar(PANEL_W - 156, 140, ACCENT2)

        rule(178, panel)

        -- ------------------------------------------------------------ status
        local function line(y, size, colour, font, h)
            return mk("TextLabel", {
                Size = UDim2.new(0, PANEL_W - 32, 0, h or 16), Position = UDim2.new(0, 16, 0, y),
                BackgroundTransparency = 1, Font = font or FONTM, Text = "", TextSize = size,
                TextColor3 = colour, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52,
                TextTruncate = Enum.TextTruncate.AtEnd, Parent = panel,
            })
        end
        local lineState  = line(182, 14, TXT, FONTB)
        local lineTarget = line(198, 14, TXT, FONT)
        local lineLock   = line(214, 13, DIM, FONT)

        rule(232, panel)

        local lineChar   = line(236, 13, ACCENT, FONT)
        local lineMem    = line(251, 11, DIM)
        local lineMap    = line(266, 11, DIM)
        local lineDetail = line(281, 11, DIM)

        rule(298, panel)

        -- -------------------------------------------------------- the marked
        mk("TextLabel", {
            Size = UDim2.new(0, 160, 0, 12), Position = UDim2.new(0, 16, 0, 302),
            BackgroundTransparency = 1, Font = FONTB, Text = TP.marked, TextSize = 9,
            TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52, Parent = panel,
        })
        mk("TextLabel", {
            Size = UDim2.new(0, 140, 0, 12), Position = UDim2.new(1, -156, 0, 302),
            BackgroundTransparency = 1, Font = FONT, Text = "tap a name to brand it", TextSize = 11,
            TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 52, Parent = panel,
        })

        local rows, rowSubs, rowData, rowMarks = {}, {}, {}, {}
        for i = 1, 3 do
            local row = mk("TextButton", {
                Size = UDim2.new(0, PANEL_W - 32, 0, 24), Position = UDim2.new(0, 16, 0, 290 + i * 26),
                BackgroundColor3 = BG3, BackgroundTransparency = 0.35, BorderSizePixel = 0,
                AutoButtonColor = true, Font = FONT, Text = "", TextSize = 14, TextColor3 = TXT,
                TextXAlignment = Enum.TextXAlignment.Left, Visible = false, ZIndex = 52,
                Parent = panel,
            })
            corner(row, 3)
            mk("UIPadding", { PaddingLeft = UDim.new(0, 12), Parent = row })
            local mark = mk("Frame", {
                Size = UDim2.new(0, 3, 1, -6), Position = UDim2.new(0, -12, 0, 3),
                BackgroundColor3 = ACCENT, BorderSizePixel = 0, Visible = false, ZIndex = 53, Parent = row,
            })
            pill(mark)

            local sub = mk("TextLabel", {
                Size = UDim2.new(0, 150, 1, 0), Position = UDim2.new(1, -162, 0, 0),
                BackgroundTransparency = 1, Font = FONTM, Text = "", TextSize = 11,
                TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 53,
                Parent = row,
            })

            row.MouseButton1Click:Connect(function()
                pcall(function()
                    local d = rowData[i]
                    if not d or not d.char then return end
                    local nm = nameOf(d.char, d.name)
                    if Bot.LockMode == "MANUAL" and Bot.LockedName == nm then
                        Bot.LockMode = "AUTO"
                        Bot.LockedName = nil
                        debug("[HUD] mark released (" .. tostring(nm) .. ")")
                    else
                        Bot.LockMode = "MANUAL"
                        Bot.LockedName = nm
                        debug("[HUD] branded -> " .. tostring(nm))
                    end
                end)
            end)

            rows[i] = row
            rowSubs[i] = sub
            rowMarks[i] = mark
        end

        local clearBtn = mk("TextButton", {
            Size = UDim2.new(0, PANEL_W - 32, 0, 20), Position = UDim2.new(0, 16, 0, 396),
            BackgroundColor3 = BG3, BorderSizePixel = 0, AutoButtonColor = true,
            Font = FONTB, Text = TP.release, TextSize = 9,
            TextColor3 = ACCENT, Visible = false, ZIndex = 52, Parent = panel,
        })
        corner(clearBtn, 3)
        stroke(clearBtn, ACCENT, 1, 0.6)
        clearBtn.MouseButton1Click:Connect(function()
            pcall(function()
                Bot.LockMode = "AUTO"
                Bot.LockedName = nil
                debug("[HUD] mark released")
            end)
        end)

        -- ------------------------------------------------------------- runes
        local settings = mk("ScrollingFrame", {
            Size = UDim2.new(1, -8, 1, -58), Position = UDim2.new(0, 4, 0, 54),
            BackgroundColor3 = BG, BackgroundTransparency = 0.04, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = ACCENT,
            CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false, ZIndex = 60, Parent = panel,
        })
        corner(settings, 3)
        mk("TextLabel", {
            Size = UDim2.new(1, -24, 0, 14), Position = UDim2.new(0, 12, 0, 6),
            BackgroundTransparency = 1, Font = FONTB, Text = TP.runes, TextSize = 10,
            TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 61, Parent = settings,
        })

        local ROWS = {
            { theme = true, label = "Dominion" },

            { key = "EmberMode",   label = "Ember mode (fps cap, low quality)",
              on = function(v) applyEmberMode(v); announce(v and "ember mode: fps capped, quality floored" or "ember mode off") end },

            { key = "BodyLock",    label = "Body lock-on",
              on = function(v) if not v then releaseBody() end end },
            { key = "UseSkills",   label = "Use skills" },
            { key = "UseSpecial",  label = "Use special" },
            { key = "UseBlock",    label = "Use block" },
            { key = "PlayersOnly", label = "Players only",
              on = function() Bot.Target = nil end },
            { key = "Sprint",      label = "Sprint",
              on = function(v) if not v then local hum = getHum(); if hum then hum.WalkSpeed = 16 end end end },
            { key = "UsePathfinding", label = "Pathfinding" },

            { key = "Memory",      label = "Memory (learning)",
              on = function(v)
                  if v then announce("memory on -> " .. MemIO.file)
                  else memSave(true); announce("memory off (saved)") end
              end },
            { key = "MapMemory",   label = "Map memory",
              on = function(v)
                  if v then
                      local n, counts, links = mapStats()
                      announce(string.format("map on: %d cells, %d hot, %d rich, %d routes",
                          n, counts.HOT, counts.RICH, links))
                  else announce("map off") end
              end },
            { key = "Sense",       label = "Sense opponent moves",
              on = function(v)
                  announce(v and ("sense on: " .. senseHookCount() .. " services hooked") or "sense off")
              end },

            { key = "AutoRestart", label = "Auto restart + swap",
              on = function(v)
                  Config.AutoCharacter = v
                  if v then
                      announce("auto: restart on death + character swap")
                      local rep = memCharReport()
                      if rep ~= "" then announce("best so far: " .. rep) end
                  else announce("auto off") end
              end },
            { key = "CharSwitchEveryLife", label = "New character every life",
              on = function(v) announce(v and "new character every life" or "swap every few lives") end },
            { fn = function()
                  local ready, since = autoCanChange()
                  if not ready then
                      announce(string.format("change on cooldown - %.0fs left",
                          Config.CharChangeCooldown - since))
                      return
                  end
                  autoSwitchNow()
              end, label = "SWAP CHARACTER NOW" },

            { fn = function() itemScan(140) end,               label = "ITEM: scan nearby" },
            { fn = itemPickup,                                 label = "ITEM: pick up nearest" },
            { fn = function() announce("held: " .. itemHeld()); senseThrowHeld(Bot.Target) end,
                                                                label = "ITEM: throw (auto)" },
            { fn = itemThrowM1,                                label = "ITEM: throw (M1)" },
            { fn = itemThrowM2,                                label = "ITEM: throw (M2)" },
            { fn = itemRefire,                                 label = "ITEM: re-fire throwable" },
            { fn = itemDrop,                                   label = "ITEM: drop" },

            { key = "DebugTarget", label = "Debug: target picks" },
            { key = "DebugDash",   label = "Debug: log everything",
              on = function(v)
                  Config.DebugMoves = v; Config.DebugM1 = v; Config.DebugTrace = v
                  Config.DebugSense = v; Config.DebugMap = v
                  LOG.enabled = v
                  if v then
                      if LOG.canWrite then
                          announce("logging to " .. LOG.name)
                          pcall(logSnapshot)
                          logFlush(true)
                      else
                          announce("no writefile in this executor - logging to console")
                      end
                  else
                      logFlush(true)
                      if LOG.canWrite then
                          announce("log saved: " .. LOG.name .. " (" .. #LOG.lines .. " lines)")
                      end
                  end
              end },
        }

        local pills = {}
        local function syncPills()
            for i = 1, #ROWS do
                local p, def = pills[i], ROWS[i]
                if p and def then
                    if def.theme then
                        p.Text = string.upper(tostring(Theme.p().label))
                        p.BackgroundColor3 = TP.aura
                        p.TextColor3 = ACCENT2
                    elseif def.key then
                        local on = Config[def.key] and true or false
                        p.Text = on and "LIT" or "DARK"
                        p.BackgroundColor3 = on and ACCENT or BG3
                        p.TextColor3 = on and INK or DIM
                    end
                end
            end
        end

        local ROW_TOP = 24
        for i, def in ipairs(ROWS) do
            local row = mk("TextButton", {
                Size = UDim2.new(1, -20, 0, 28),
                Position = UDim2.new(0, 8, 0, ROW_TOP + (i - 1) * 30), BackgroundColor3 = BG2,
                BorderSizePixel = 0, AutoButtonColor = true, Text = "", ZIndex = 61,
                Parent = settings,
            })
            corner(row, 3)
            stroke(row, TP.stroke, 1, 0.5)

            mk("TextLabel", {
                Size = UDim2.new(1, -90, 1, 0), Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1, Font = def.fn and FONTB or FONT, Text = def.label,
                TextSize = def.fn and 10 or 13, TextColor3 = def.fn and ACCENT or TXT,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 62, Parent = row,
            })

            if not def.fn then
                local p = mk("TextLabel", {
                    Size = UDim2.new(0, 64, 0, 16), Position = UDim2.new(1, -72, 0.5, -8),
                    BackgroundColor3 = BG3, BorderSizePixel = 0, Font = FONTB,
                    Text = "DARK", TextSize = 9, TextColor3 = DIM, ZIndex = 62, Parent = row,
                })
                corner(p, 2)
                pills[i] = p
            end

            local last = 0
            row.MouseButton1Click:Connect(function()
                if os.clock() - last < 0.3 then return end
                last = os.clock()
                pcall(function()
                    if def.theme then
                        Theme.reopenSettings = true
                        task.defer(function() pcall(Theme.cycle) end)
                        return
                    end
                    if def.fn then
                        local ok, err = pcall(def.fn)
                        if not ok then debug(def.label .. " failed: " .. tostring(err)) end
                        return
                    end
                    Config[def.key] = not Config[def.key]
                    if def.on then
                        local ok, err = pcall(def.on, Config[def.key])
                        if not ok then debug(def.label .. " failed: " .. tostring(err)) end
                    end
                    debug(string.format("[HUD] %s = %s", def.key, tostring(Config[def.key])))
                    syncPills()
                end)
            end)
        end
        settings.CanvasSize = UDim2.new(0, 0, 0, ROW_TOP + #ROWS * 30 + 8)
        syncPills()

        gearBtn.MouseButton1Click:Connect(function()
            pcall(function()
                settings.Visible = not settings.Visible
                if settings.Visible then syncPills() end
            end)
        end)

        if Theme.reopenSettings then
            Theme.reopenSettings = nil
            settings.Visible = true
        end

        -- ------------------------------------------------- the sleeping eye
        -- Minimised: the slab is gone and only the eye remains, with a word.
        local pillBtn = mk("TextButton", {
            Size = UDim2.new(0, 150, 0, 40), Position = panel.Position, BackgroundColor3 = BG2,
            BorderSizePixel = 0, AutoButtonColor = true, Font = FONTB,
            Text = "", TextSize = 10, TextColor3 = ACCENT, Visible = false, ZIndex = 50,
            Parent = gui,
        })
        corner(pillBtn, 4)
        gradient(pillBtn, BG2, BG, 90)
        stroke(pillBtn, ACCENT, 1, 0.45)
        local miniEye = mk("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, 34, 0, 8),
            Position = UDim2.new(0, 10, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0, ZIndex = 51, Parent = pillBtn,
        })
        pill(miniEye)
        do
            local g = Instance.new("UIGradient")
            g.Color = eyeGrad.Color
            g.Rotation = 0
            g.Parent = miniEye
        end
        local miniSlit = mk("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 3, 1, -2),
            Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = INK,
            BorderSizePixel = 0, ZIndex = 52, Parent = miniEye,
        })
        pill(miniSlit)
        local miniText = mk("TextLabel", {
            Size = UDim2.new(1, -56, 1, 0), Position = UDim2.new(0, 50, 0, 0),
            BackgroundTransparency = 1, Font = FONTB, Text = "", TextSize = 10,
            TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = pillBtn,
        })

        minBtn.MouseButton1Click:Connect(function()
            pcall(function()
                pillBtn.Position = panel.Position
                settings.Visible = false
                panel.Visible = false
                pillBtn.Visible = true
            end)
        end)
        pillBtn.MouseButton1Click:Connect(function()
            pcall(function()
                panel.Position = pillBtn.Position
                pillBtn.Visible = false
                panel.Visible = true
            end)
        end)

        closeBtn.MouseButton1Click:Connect(function()
            pcall(function()
                for _, c in ipairs(conns) do
                    pcall(function() c:Disconnect() end)
                end
                gui:Destroy()
                debug("[HUD] closed")
            end)
        end)

        -- --------------------------------------------------------- the pulse
        -- The eye breathes: slow and dim asleep, quick and bright awake. The
        -- halo breathes with it. Tweens, not per-frame work: a phone budget.
        local eyeOpen, eyeHot = false, false
        task.spawn(function()
            local phase = false
            while gui and gui.Parent do
                phase = not phase
                local period = eyeOpen and (eyeHot and 0.55 or 1.1) or 2.6
                local glowT  = eyeOpen and (phase and 0.72 or 0.86) or (phase and 0.90 or 0.96)
                local haloT  = eyeOpen and (phase and 0.60 or 0.80) or (phase and 0.80 or 0.90)
                local grow   = eyeOpen and (phase and 18 or 0) or (phase and 6 or 0)
                tween(eyeGlow, period, {
                    BackgroundTransparency = glowT,
                    Size = UDim2.new(0, EYE_W + 40 + grow, 0, (eyeOpen and EYE_OPEN or EYE_SHUT) + 14 + grow / 2),
                })
                tween(haloStroke1, period, { Transparency = haloT })
                tween(haloStroke2, period, { Transparency = eyeOpen and (phase and 0.86 or 0.94) or 0.95 })
                tween(eyeStroke,   period, { Transparency = eyeOpen and (phase and 0 or 0.4) or 0.6 })
                task.wait(period)
            end
        end)

        -- Embers rise. Each mote climbs the slab at its own pace and is lit
        -- again at the bottom; a sleeping eye lets most of them die out.
        task.spawn(function()
            local i = 0
            while gui and gui.Parent do
                i = i % #motes + 1
                local m = motes[i]
                if eyeOpen or math.random() < 0.3 then
                    local dur = 3 + math.random() * 4
                    local x = 0.08 + math.random() * 0.84
                    m.Position = UDim2.new(x, 0, 1.02, 0)
                    m.Size = UDim2.new(0, 2 + math.random(0, 1), 0, 2 + math.random(0, 1))
                    m.BackgroundTransparency = 0.15
                    tween(m, dur, {
                        Position = UDim2.new(x + (math.random() - 0.5) * 0.12, 0, -0.05, 0),
                        BackgroundTransparency = 1,
                    }, Enum.EasingStyle.Linear)
                end
                task.wait(eyeOpen and 0.5 or 1.4)
            end
        end)

        local function setEye(open, hot)
            if open == eyeOpen and hot == eyeHot then return end
            eyeOpen, eyeHot = open, hot
            eyeColours(hot)
            pcall(function() miniEye.UIGradient.Color = eyeGrad.Color end)
            tween(eye, 0.6, { Size = UDim2.new(0, EYE_W, 0, open and EYE_OPEN or EYE_SHUT) },
                Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            tween(slit, 0.6, { Size = UDim2.new(0, hot and 5 or 9, 1, -4) })
            tween(miniEye, 0.6, { Size = UDim2.new(0, 34, 0, open and 14 or 5) })
        end

        -- ----------------------------------------------------------- refresh
        local function refresh()
            local running = Config.Enabled and true or false
            local hpPct = math.floor(getHPPct() or 0)
            local hurt = running and hpPct > 0 and hpPct < (Config.RetreatHP or 35)

            setEye(running, hurt)

            startBtn.Text = running and TP.sleep or TP.awake
            startBtn.TextColor3 = running and TXT or ACCENT2
            startStroke.Color = running and BAD or ACCENT
            startGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,   running and BAD or TP.aura),
                ColorSequenceKeypoint.new(0.5, running and TP.aura or BG3),
                ColorSequenceKeypoint.new(1,   running and BAD or TP.aura),
            })

            local up = 0
            if running and (tonumber(Bot.StartTime) or 0) > 0 then
                up = tick() - Bot.StartTime
            end
            local kills = math.floor(tonumber(Bot.Kills) or 0)
            lineState.Text = string.format("%s     %s     %d %s",
                string.upper(tostring(Bot.State or "?")), fmtClock(up), kills, "slain")

            local t = Bot.Target
            if t and t.Parent then
                lineTarget.Text = string.format("the eye sees  %s     %d st     %d%%",
                    short(nameOf(t), 14),
                    math.floor(tonumber(Bot.Dist2D) or 0),
                    math.floor(numOf(getHPPct, t)))
                lineTarget.TextColor3 = TXT
                eyeWord.Text = running and ("it sees " .. short(nameOf(t), 10)) or TP.idle
                eyeWord.TextColor3 = running and ACCENT or DIM
            else
                lineTarget.Text = running and "the eye searches" or "the eye sees nothing"
                lineTarget.TextColor3 = DIM
                eyeWord.Text = running and (hurt and "it bleeds" or "it searches") or TP.idle
                eyeWord.TextColor3 = running and (hurt and BAD or DIM) or DIM
            end
            if hurt then eyeWord.Text = "it bleeds"; eyeWord.TextColor3 = BAD end

            local manual = (Bot.LockMode == "MANUAL") and Bot.LockedName ~= nil
            if manual then
                lineLock.Text = "branded:  " .. short(Bot.LockedName, 18)
                lineLock.TextColor3 = ACCENT
            else
                lineLock.Text = "will:  its own"
                lineLock.TextColor3 = DIM
            end
            clearBtn.Visible = manual

            -- bars
            hpFill.Size = UDim2.new(math.clamp(hpPct / 100, 0, 1), 0, 1, 0)
            hpFill.BackgroundColor3 = hurt and BAD or ACCENT
            local ult = math.clamp((tonumber(getUltMeter()) or 0) / 100, 0, 1)
            ultFill.Size = UDim2.new(isAwakened() and 1 or ult, 0, 1, 0)

            local c = getChar()
            local set = c and c:GetAttribute("Moveset")
            local info = set and CharInfo[set]
            if info then
                lineChar.Text = string.format("%s  ·  %s%s     %s",
                    tostring(set), tostring(info.header),
                    isAwakened() and ("  [" .. tostring(info.ult) .. "]") or "",
                    isAwakened() and "AWAKENED" or ("wrath " .. math.floor(getUltMeter()) .. "%"))
                lineChar.TextColor3 = Color3.fromRGB(info.r, info.g, info.b)
            else
                lineChar.Text = string.format("%s     hp %d%%",
                    tostring(set or "no vessel"), hpPct)
                lineChar.TextColor3 = ACCENT
            end

            if Config.Memory then
                local st = MEM.stats or {}
                local booked = (st.clean or 0) + (st.shared or 0)
                local total = booked + (st.dirty or 0)
                lineMem.Text = string.format("dmg %.0f  out %.1f/s in %.1f/s%s | thr %s | %d%% clean",
                    memLifeDmg(), memLifeRate(), memLifeInRate(),
                    Bot.Losing and " LOSING" or "",
                    (Bot.ThreatChar and string.format("%s %.0f",
                        string.sub(Bot.ThreatChar.Name, 1, 8), Bot.ThreatScore or 0)) or "-",
                    total > 0 and math.floor(booked / total * 100) or 0)
            else
                lineMem.Text = "memory: dark"
            end

            if Config.MapMemory then
                local n, counts, links = mapStats()
                local intent = ""
                if Bot.State == "IDLE" then
                    if Bot.SeekChar then intent = string.format(" seek %.0f", Bot.SeekDist or 0)
                    elseif Bot.HuntGoal then intent = " " .. tostring(Bot.HuntWhy or "roam")
                    else intent = " no route" end
                end
                lineMap.Text = string.format("map %s | %dc %dH/%dR/%dD %dr | %d near%s%s%s",
                    Bot.CellClass or "-", n, counts.HOT, counts.RICH, counts.DEAD, links,
                    Bot.Hostiles or 0,
                    (Bot.Attackers or 0) >= 2 and " GANGED" or "",
                    Bot.Stalling and " STALL" or "",
                    intent)
            else
                lineMap.Text = "map: dark"
            end

            local srule = getSpecialRule()
            local sp = srule and (srule.kind == "avoid" and "sp:-" or
                       ("sp:" .. (isSpecialReady() and "RDY" or "cd"))) or "sp:-"
            local logTxt = (LOG.enabled and LOG.canWrite) and ("  LOG " .. #LOG.lines .. "L") or ""
            lineDetail.Text = string.format("d%d y%+d  mv:%d  %s%s",
                math.floor(Bot.Dist2D or 0), math.floor(Bot.DistY or 0),
                #getUsableMoves(), sp, logTxt)

            local scores = Bot.Scores or {}
            for i = 1, 3 do
                local d = scores[i]
                rowData[i] = d
                local row, sub, mark = rows[i], rowSubs[i], rowMarks[i]
                if d then
                    local nm = nameOf(d.char, d.name)
                    local locked = manual and Bot.LockedName == nm
                    row.Visible = true
                    row.Text = string.format("%s%s", locked and "† " or "", short(nm, 13))
                    sub.Text = string.format("%d  %s",
                        math.floor(tonumber(d.score) or 0), tostring(d.why or "-"))
                    local isTarget = d.char == Bot.Target
                    mark.Visible = isTarget
                    if isTarget then
                        row.BackgroundColor3 = TP.aura
                        row.BackgroundTransparency = 0
                        row.TextColor3 = ACCENT2
                        sub.TextColor3 = ACCENT
                    else
                        row.BackgroundColor3 = BG3
                        row.BackgroundTransparency = 0.35
                        row.TextColor3 = TXT
                        sub.TextColor3 = DIM
                    end
                else
                    row.Visible = false
                end
            end

            if pillBtn.Visible then
                miniText.Text = string.format("%s  ·  %d slain",
                    string.upper(tostring(Bot.State or "?")), kills)
            end
        end

        FF_HUD_REFRESH = refresh

        task.spawn(function()
            local lastErr = 0
            while true do
                task.wait(0.15)
                if not gui or not gui.Parent then break end
                local ok, err = pcall(refresh)
                if not ok and tick() - lastErr > 5 then
                    lastErr = tick()
                    pcall(debug, "[HUD] refresh error: " .. tostring(err))
                end
            end
        end)

        bind(UserInputService.InputBegan, function(input, gameProcessedEvent)
            if gameProcessedEvent then return end
            if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.F5 then
                toggleBot()
            elseif input.KeyCode == Enum.KeyCode.RightShift then
                pcall(function()
                    Bot.LockMode = "AUTO"
                    Bot.LockedName = nil
                    debug("[HUD] mark released (RightShift)")
                end)
            end
        end)

        -- Arrive: the slab fades up out of black rather than popping in.
        pcall(function()
            panel.BackgroundTransparency = 1
            for _, d in ipairs(panel:GetDescendants()) do
                if d:IsA("GuiObject") and d.Visible then
                    d:SetAttribute("EyeFade", d.BackgroundTransparency)
                    d.BackgroundTransparency = 1
                    if d:IsA("TextLabel") or d:IsA("TextButton") then
                        d:SetAttribute("EyeFadeT", d.TextTransparency)
                        d.TextTransparency = 1
                    end
                end
            end
            tween(panel, 0.9, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            for _, d in ipairs(panel:GetDescendants()) do
                if d:IsA("GuiObject") and d:GetAttribute("EyeFade") ~= nil then
                    local props = { BackgroundTransparency = d:GetAttribute("EyeFade") }
                    if d:GetAttribute("EyeFadeT") ~= nil then props.TextTransparency = d:GetAttribute("EyeFadeT") end
                    tween(d, 0.9, props, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                end
            end
        end)

        pcall(refresh)
    end

    Theme.rebuild = buildHUD
    local okB, errB = pcall(buildHUD)
    if not okB then
        debug("[HUD] build failed (engine still running): " .. tostring(errB))
        pcall(announce, "HUD failed to build - bot still runs; see log")
    end
end

announce("The Eye HUD on v83 - RightCtrl toggles, tap a name to brand it, Runes > Dominion to change skin")















local lastDeathAt = 0

local function onDeath(char, source)
    if tick() - lastDeathAt < 3 then return end
    lastDeathAt = tick()




    if autoIsSwitching() then







        if (Life.moves or 0) == 0 and (Life.dmg or 0) == 0
           and (tick() - (Life.startAt or 0)) < (Config.SwitchWaitMax + Config.SwitchRespawnTimeout + 2) then
            Life.active = false
            debug("respawn was a character switch - life discarded (no fighting)")
        else
            debug("respawn was a character switch, not a death")
            memLifeEnd()
        end
        return
    end

    local h = char and char:FindFirstChild("HumanoidRootPart")
    local pos = (h and h.Position) or Bot.LastPos
    if pos then
        mapNoteDeath(pos)
    else
        debug("death: no position available, not recorded")
    end




    memNoteDeath(Bot.Target)
    memLifeEnd()
    autoOnDeath()
    memSave(true, "death")
    logFlush(true)

    if Config.Enabled then stopBot(); updateUI() end
end

local function hookDeath(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Died:Connect(function() onDeath(char, "Died") end)
    end
end







LocalPlayer.CharacterAdded:Connect(function(char)





    AutoState.spawnedAt = tick()
    AutoState.spawnHP = 0

    AutoState.wastedAt = -999
    AutoState.wastedBackoffUntil = 0






    Bot.DmgFrom = setmetatable({}, { __mode = "k" })
    Bot.Nemesis = nil
    Bot.NemesisDmg = 0


    Bot.GangedUntil = 0
    Bot.RejoinSince = 0

    memLifeStart()
    hookDeath(char)

    task.delay(0.4, function()

        AutoState.spawnHP = getHP() or 0
    end)

    task.delay(0.5, function() autoOnSpawn(char) end)
end)


hookDeath(LocalPlayer.Character)










AutoState.spawnedAt = tick()
AutoState.spawnHP = getHP() or 0

LocalPlayer.CharacterRemoving:Connect(function(char)
    onDeath(char, "Removing")
end)



task.spawn(senseBuildAnimMap)
senseInit()
updateUI()
announce("=== READY - THE EYE SLEEPS. OPEN IT FROM THE HUD ===")
announce("### BUILD " .. BUILD_TAG .. " ###")
announce(LOG.canWrite and ("file logging ready -> " .. LOG.name)
                       or "no writefile - DEBUG prints to console")



JJK_ENV.JJK_AUTOFIGHT_STOP = function()
    pcall(stopBot)
    pcall(function()
        if type(Theme) == "table" and type(Theme.conns) == "table" then
            for _, c in ipairs(Theme.conns) do pcall(function() c:Disconnect() end) end
            Theme.conns = {}
        end
    end)
end

