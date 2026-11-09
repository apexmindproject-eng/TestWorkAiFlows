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
--  THE EYE  --  HUD (overlay build)
--
--  No panel. Three things sit over the game:
--    * the Eye: a small lidless eye at the top of the screen, breathing a
--      soft halo while the bot pilots, dim and still while it sleeps. Drag it
--      anywhere; tap it to open the menu.
--    * the readout: three lines under the eye saying what the bot is doing,
--      who it is on, and why. Hidden while the menu is open.
--    * the aura: a glow around the edge of the whole screen in the dominion's
--      colour while the bot is piloting, like a browser tab under remote
--      control. Red-shifted and quicker when the fighter is bleeding.
--  The menu is a plain serif list on the left with a glowing marker on the
--  chosen line, no box behind it.
--
--  Two dominions: Barad-dur (ember) and Minas Morgul (witch-light). The eye
--  itself is a PNG embedded below and written to the executor workspace on
--  first use, so it draws without any Roblox asset id; executors without
--  getcustomasset get a vector stand-in.
-- ============================================================================

local FF_ENV = (typeof(getgenv) == "function" and getgenv()) or _G
local FF_THEME_FILE = "JJK_EyeTheme.txt"
local TweenService = game:GetService("TweenService")

local Theme = {
    name  = "baraddur",
    order = { "baraddur", "morgul" },
    conns = nil,
    rebuild = nil,
    reopenMenu = nil,
}

Theme.defs = {
    baraddur = {
        label   = "Barad-dur",
        txt     = Color3.fromRGB(236, 226, 210),
        dim     = Color3.fromRGB(170, 150, 130),
        accent  = Color3.fromRGB(255, 92, 20),     -- ember
        accent2 = Color3.fromRGB(255, 214, 96),    -- molten
        bad     = Color3.fromRGB(230, 30, 30),
        ink     = Color3.fromRGB(8, 4, 3),
        font    = Enum.Font.Garamond,
        fontM   = Enum.Font.Code,
        title   = "BARAD-DÛR",
        sub     = "the eye is upon them",
        awake   = "Awaken the Eye",
        sleep   = "Close the Eye",
        idle    = "the eye sleeps",
    },
    morgul = {
        label   = "Minas Morgul",
        txt     = Color3.fromRGB(220, 240, 228),
        dim     = Color3.fromRGB(130, 170, 150),
        accent  = Color3.fromRGB(70, 255, 110),    -- witch-light
        accent2 = Color3.fromRGB(200, 255, 220),
        bad     = Color3.fromRGB(230, 30, 30),
        ink     = Color3.fromRGB(3, 8, 5),
        font    = Enum.Font.Garamond,
        fontM   = Enum.Font.Code,
        title   = "MINAS MORGUL",
        sub     = "the dead do not sleep",
        awake   = "Raise the Dead",
        sleep   = "Let Them Rest",
        idle    = "the tower is silent",
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

-- ------------------------------------------------------------- the eye png
-- 192x192 RGBA, one per dominion. Written to the workspace as
-- JJK_Eye_<dominion>.png on first use and loaded through getcustomasset.
local EYE_PNG = {
    baraddur = "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",
    morgul   = "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",
}

local function b64decode(s)
    if typeof(crypt) == "table" and type(crypt.base64decode) == "function" then
        local ok, r = pcall(crypt.base64decode, s)
        if ok and type(r) == "string" and #r > 0 then return r end
    end
    if type(base64_decode) == "function" then
        local ok, r = pcall(base64_decode, s)
        if ok and type(r) == "string" and #r > 0 then return r end
    end
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local index = {}
    for i = 1, 64 do index[string.sub(alphabet, i, i)] = i - 1 end
    s = string.gsub(s, "[^%w%+/=]", "")
    local out, n, bits, nb = {}, 0, 0, 0
    for i = 1, #s do
        local c = string.sub(s, i, i)
        if c == "=" then break end
        bits = bits * 64 + index[c]
        nb = nb + 6
        if nb >= 8 then
            nb = nb - 8
            local div = 2 ^ nb
            n = n + 1
            out[n] = string.char(math.floor(bits / div) % 256)
            bits = bits % div
        end
    end
    return table.concat(out)
end

local function eyeAsset(skin)
    local cache = rawget(FF_ENV, "__JJK_EYE_ASSETS")
    if type(cache) ~= "table" then cache = {}; rawset(FF_ENV, "__JJK_EYE_ASSETS", cache) end
    if cache[skin] ~= nil then return cache[skin] or nil end
    local id = false
    pcall(function()
        if type(writefile) ~= "function" or type(getcustomasset) ~= "function" then return end
        local file = "JJK_Eye_" .. skin .. ".png"
        local have = false
        if type(isfile) == "function" then
            local okF, ex = pcall(isfile, file)
            have = okF and ex == true
        end
        if not have then writefile(file, b64decode(EYE_PNG[skin] or "")) end
        local got = getcustomasset(file)
        if type(got) == "string" and #got > 0 then id = got end
    end)
    cache[skin] = id
    return id or nil
end

-- Ember mode: the one thermal lever a phone needs, kept as a menu line
-- instead of being forced at load. Quality floor + fps cap on, back off.
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

-- What the state machine is doing, in words a person would use.
local STATE_WORD = {
    IDLE = "Watching", APPROACH = "Closing in", ATTACK = "Striking", CHASE = "Hunting",
    RETREAT = "Withdrawing", DEFEND = "Guarding", FLANK = "Circling", PUNISH = "Punishing",
    REACT = "Reacting", CCED = "Stunned", THROW = "Throwing", AWAKEN = "Awakening",
    DEAD = "Fallen", LEVEL = "Climbing", PERCHED = "Perched", TEAMKITE = "Kiting",
}

do
    local function buildHUD()

        local TP      = Theme.p()
        local TXT     = TP.txt
        local DIM     = TP.dim
        local ACCENT  = TP.accent
        local ACCENT2 = TP.accent2
        local BAD     = TP.bad
        local INK     = TP.ink
        local FONT    = TP.font
        local FONTM   = TP.fontM

        local function mk(class, props)
            local o = Instance.new(class)
            for k, v in pairs(props) do
                if k ~= "Parent" then o[k] = v end
            end
            if props.Parent then o.Parent = props.Parent end
            return o
        end
        local function round(o, r)
            local c = Instance.new("UICorner")
            c.CornerRadius = r and UDim.new(0, r) or UDim.new(1, 0)
            c.Parent = o
            return c
        end
        local function stroke(o, colour, thick, trans)
            return mk("UIStroke", {
                Color = colour, Thickness = thick or 1, Transparency = trans or 0,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o,
            })
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
        -- Text drawn straight over the game needs a dark edge to stay legible.
        local function text(props)
            props.BackgroundTransparency = 1
            props.Font = props.Font or FONT
            props.TextStrokeColor3 = INK
            props.TextStrokeTransparency = props.TextStrokeTransparency or 0.55
            props.TextTruncate = props.TextTruncate or Enum.TextTruncate.AtEnd
            return mk("TextLabel", props)
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

        -- Drag by a handle; a press that barely moves counts as a tap.
        local function draggable(handle, target, onTap)
            local dragging, startPos, origin, moved = false, nil, nil, false
            bind(handle.InputBegan, function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                   and input.UserInputType ~= Enum.UserInputType.Touch then return end
                dragging, moved = true, false
                startPos, origin = input.Position, target.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        if not moved and onTap then pcall(onTap) end
                    end
                end)
            end)
            bind(UserInputService.InputChanged, function(input)
                if not dragging or not startPos then return end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement
                   and input.UserInputType ~= Enum.UserInputType.Touch then return end
                local delta = input.Position - startPos
                if delta.Magnitude > 6 then moved = true end
                if moved then
                    target.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X,
                                                origin.Y.Scale, origin.Y.Offset + delta.Y)
                end
            end)
        end

        -- -------------------------------------------------------------- aura
        -- Five nested frames, each inset by its own stroke width so the glow
        -- lands just inside the screen edge, fainter as it reaches inward.
        local AURA = { { 6, 0.40 }, { 14, 0.58 }, { 26, 0.72 }, { 42, 0.84 }, { 64, 0.92 } }
        local auraRoot = mk("Frame", {
            Name = "Aura", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            Visible = false, ZIndex = 1, Parent = gui,
        })
        local auraStrokes = {}
        for i, def in ipairs(AURA) do
            local t = def[1]
            local f = mk("Frame", {
                Size = UDim2.new(1, -2 * t, 1, -2 * t), Position = UDim2.new(0, t, 0, t),
                BackgroundTransparency = 1, ZIndex = 1, Parent = auraRoot,
            })
            round(f, 18 + t)
            auraStrokes[i] = stroke(f, ACCENT, t, 1)
        end

        -- --------------------------------------------------------------- eye
        local EYE = 48
        local eyeRoot = mk("Frame", {
            Name = "Eye", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 96, 0, 96),
            Position = UDim2.new(0.5, 0, 0, 4), BackgroundTransparency = 1, ZIndex = 10,
            Parent = gui,
        })
        local halo2 = mk("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, EYE + 44, 0, EYE + 44), BackgroundColor3 = ACCENT,
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10, Parent = eyeRoot,
        })
        round(halo2)
        local halo1 = mk("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, EYE + 18, 0, EYE + 18), BackgroundColor3 = ACCENT,
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 11, Parent = eyeRoot,
        })
        round(halo1)
        local ring = stroke(halo1, ACCENT2, 1, 1)

        local eyeImg = nil
        local asset = eyeAsset(Theme.name)
        if asset then
            eyeImg = mk("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, EYE, 0, EYE), BackgroundTransparency = 1,
                Image = asset, ScaleType = Enum.ScaleType.Fit, ZIndex = 12, Parent = eyeRoot,
            })
        else
            -- Vector stand-in: a disc of fire with a black slit.
            eyeImg = mk("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, EYE, 0, EYE), BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0, ZIndex = 12, Parent = eyeRoot,
            })
            round(eyeImg)
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, BAD), ColorSequenceKeypoint.new(0.35, ACCENT),
                ColorSequenceKeypoint.new(0.5, ACCENT2), ColorSequenceKeypoint.new(0.65, ACCENT),
                ColorSequenceKeypoint.new(1, BAD),
            })
            g.Parent = eyeImg
            local slit = mk("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 7, 1, -8), BackgroundColor3 = INK, BorderSizePixel = 0,
                ZIndex = 13, Parent = eyeImg,
            })
            round(slit)
        end
        local function setEyeTint(c, t)
            pcall(function()
                if eyeImg:IsA("ImageLabel") then
                    eyeImg.ImageColor3 = c
                    eyeImg.ImageTransparency = t
                else
                    eyeImg.BackgroundColor3 = c
                    eyeImg.BackgroundTransparency = t
                end
            end)
        end

        -- A transparent button over the eye: the drag handle and the menu tap.
        local eyeTap = mk("TextButton", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, ZIndex = 14, Parent = eyeRoot,
        })

        -- ----------------------------------------------------------- readout
        local readout = mk("Frame", {
            AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 380, 0, 96),
            Position = UDim2.new(0.5, 0, 1, -6), BackgroundTransparency = 1, ZIndex = 10,
            Parent = eyeRoot,
        })
        local l1 = text({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 0),
            Text = "", TextSize = 24, TextColor3 = ACCENT2, ZIndex = 11, Parent = readout })
        local l2 = text({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 26),
            Text = "", TextSize = 17, TextColor3 = TXT, ZIndex = 11, Parent = readout })
        local l3 = text({ Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 46),
            Text = "", TextSize = 15, TextColor3 = DIM, ZIndex = 11, Parent = readout })
        local l4 = text({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 66),
            Text = "", TextSize = 11, TextColor3 = DIM, Font = FONTM, ZIndex = 11, Parent = readout })

        -- -------------------------------------------------------------- menu
        local MENU_W = 300
        local menu = mk("Frame", {
            Name = "Menu", AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, MENU_W, 1, -40),
            Position = UDim2.new(0, 28, 0.5, 0), BackgroundTransparency = 1, Visible = false,
            ZIndex = 20, Parent = gui,
        })
        local mTitle = text({ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 0),
            Text = TP.title, TextSize = 30, TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left,
            TextStrokeTransparency = 0.4, Active = true, ZIndex = 21, Parent = menu })
        local mSub = text({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 1, 0, 33),
            Text = TP.sub, TextSize = 14, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 21, Parent = menu })
        -- the diamond rule under the title
        local mRule = mk("Frame", {
            Size = UDim2.new(0, 200, 0, 1), Position = UDim2.new(0, 0, 0, 56),
            BackgroundColor3 = ACCENT, BorderSizePixel = 0, ZIndex = 21, Parent = menu,
        })
        do
            local g = Instance.new("UIGradient")
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1),
            })
            g.Parent = mRule
        end
        local mDiamond = mk("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 7, 0, 7),
            Position = UDim2.new(0, 60, 0, 56), Rotation = 45, BackgroundColor3 = ACCENT2,
            BorderSizePixel = 0, ZIndex = 22, Parent = menu,
        })

        local list = mk("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, -66), Position = UDim2.new(0, 0, 0, 66),
            BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
            ScrollBarImageColor3 = ACCENT, ScrollBarImageTransparency = 0.5,
            CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 21, Parent = menu,
        })

        local function setMenu(open)
            menu.Visible = open
            readout.Visible = not open
        end
        draggable(eyeTap, eyeRoot, function() setMenu(not menu.Visible) end)
        draggable(mTitle, menu, nil)

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

        local function brand(i)
            local d = (Bot.Scores or {})[i]
            if not d or not d.char then return end
            local nm = nameOf(d.char, d.name)
            if Bot.LockMode == "MANUAL" and Bot.LockedName == nm then
                Bot.LockMode = "AUTO"; Bot.LockedName = nil
                debug("[HUD] mark released (" .. tostring(nm) .. ")")
            else
                Bot.LockMode = "MANUAL"; Bot.LockedName = nm
                debug("[HUD] branded -> " .. tostring(nm))
            end
        end

        -- Every line of the menu. `section` is a dim heading; `key` toggles a
        -- Config flag and shows its state; `fn` runs once; `dyn` is a target.
        local ROWS = {
            { section = "Command" },
            { fn = toggleBot, label = function() return Config.Enabled and TP.sleep or TP.awake end, hot = true },
            { theme = true,        label = "Dominion" },
            { key = "EmberMode",   label = "Ember mode",
              on = function(v) applyEmberMode(v); announce(v and "ember mode: fps capped, quality floored" or "ember mode off") end },
            { fn = function() setMenu(false) end, label = "Resume" },

            { section = "The Marked" },
            { dyn = 1, fn = function() brand(1) end },
            { dyn = 2, fn = function() brand(2) end },
            { dyn = 3, fn = function() brand(3) end },
            { fn = function() Bot.LockMode = "AUTO"; Bot.LockedName = nil; debug("[HUD] mark released") end,
              label = "Release the mark", onlyWhen = function() return Bot.LockMode == "MANUAL" and Bot.LockedName ~= nil end },

            { section = "Runes" },
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
            { key = "Memory",      label = "Memory",
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
            { key = "AutoRestart", label = "Auto restart and swap",
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
              end, label = "Swap character now" },

            { section = "Items" },
            { fn = function() itemScan(140) end,               label = "Scan nearby" },
            { fn = itemPickup,                                 label = "Pick up nearest" },
            { fn = function() announce("held: " .. itemHeld()); senseThrowHeld(Bot.Target) end,
                                                                label = "Throw (auto)" },
            { fn = itemThrowM1,                                label = "Throw (M1)" },
            { fn = itemThrowM2,                                label = "Throw (M2)" },
            { fn = itemRefire,                                 label = "Re-fire throwable" },
            { fn = itemDrop,                                   label = "Drop" },

            { section = "Debug" },
            { key = "DebugTarget", label = "Target picks" },
            { key = "DebugDash",   label = "Log everything",
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
            { fn = function()
                  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
                  gui:Destroy()
                  debug("[HUD] closed")
              end, label = "Quit the HUD" },
        }

        local ROW_H, SEC_H = 30, 26
        local items = {}
        local selected = 2
        local function layout()
            local y = 0
            for i, def in ipairs(ROWS) do
                local it = items[i]
                local show = true
                if def.onlyWhen then show = def.onlyWhen() and true or false end
                if def.dyn then show = (Bot.Scores or {})[def.dyn] ~= nil end
                it.frame.Visible = show
                if show then
                    it.frame.Position = UDim2.new(0, 0, 0, y)
                    y = y + (def.section and SEC_H or ROW_H)
                end
            end
            list.CanvasSize = UDim2.new(0, 0, 0, y + 8)
        end

        for i, def in ipairs(ROWS) do
            if def.section then
                local f = mk("Frame", { Size = UDim2.new(1, 0, 0, SEC_H), BackgroundTransparency = 1, ZIndex = 21, Parent = list })
                text({ Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 2, 0, 4), Text = string.upper(def.section),
                    TextSize = 11, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Bottom, ZIndex = 22, Parent = f })
                items[i] = { frame = f }
            else
                local row = mk("TextButton", {
                    Size = UDim2.new(1, 0, 0, ROW_H), BackgroundTransparency = 1, Text = "",
                    AutoButtonColor = false, ZIndex = 21, Parent = list,
                })
                -- the marker: a soft bar that fades to the right, and a diamond
                local hl = mk("Frame", {
                    Size = UDim2.new(1, -8, 0, ROW_H - 6), Position = UDim2.new(0, 8, 0, 3),
                    BackgroundColor3 = ACCENT, BorderSizePixel = 0, Visible = false, ZIndex = 21, Parent = row,
                })
                round(hl, 8)
                do
                    local g = Instance.new("UIGradient")
                    g.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.6, 0.6),
                        NumberSequenceKeypoint.new(1, 1),
                    })
                    g.Parent = hl
                end
                local hlStroke = stroke(hl, ACCENT2, 1, 0.7)
                local dia = mk("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 8, 0, 8),
                    Position = UDim2.new(0, 2, 0.5, 0), Rotation = 45, BackgroundColor3 = ACCENT2,
                    BorderSizePixel = 0, Visible = false, ZIndex = 23, Parent = row,
                })
                local lbl = text({
                    Size = UDim2.new(1, -90, 1, 0), Position = UDim2.new(0, 20, 0, 0),
                    Text = "", TextSize = 18, TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 22, Parent = row,
                })
                local val = text({
                    Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(1, -78, 0, 0),
                    Text = "", TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 22, Parent = row,
                })
                items[i] = { frame = row, hl = hl, hlStroke = hlStroke, dia = dia, lbl = lbl, val = val }

                local last = 0
                row.MouseButton1Click:Connect(function()
                    if os.clock() - last < 0.25 then return end
                    last = os.clock()
                    selected = i
                    pcall(function()
                        if def.theme then
                            Theme.reopenMenu = true
                            task.defer(function() pcall(Theme.cycle) end)
                            return
                        end
                        if def.fn then
                            local ok, err = pcall(def.fn)
                            if not ok then debug(tostring(def.label) .. " failed: " .. tostring(err)) end
                            return
                        end
                        if def.key then
                            Config[def.key] = not Config[def.key]
                            if def.on then
                                local ok, err = pcall(def.on, Config[def.key])
                                if not ok then debug(def.label .. " failed: " .. tostring(err)) end
                            end
                            debug(string.format("[HUD] %s = %s", def.key, tostring(Config[def.key])))
                        end
                    end)
                end)
            end
        end

        local function syncMenu()
            local manual = (Bot.LockMode == "MANUAL") and Bot.LockedName ~= nil
            for i, def in ipairs(ROWS) do
                local it = items[i]
                if not def.section then
                    local isSel = (i == selected)
                    it.hl.Visible = isSel
                    it.dia.Visible = isSel
                    it.lbl.TextColor3 = isSel and ACCENT2 or (def.hot and ACCENT or TXT)
                    it.lbl.TextStrokeTransparency = isSel and 0.3 or 0.55
                    local label = def.label
                    if type(label) == "function" then label = label() end
                    if def.dyn then
                        local d = (Bot.Scores or {})[def.dyn]
                        if d then
                            local nm = nameOf(d.char, d.name)
                            local branded = manual and Bot.LockedName == nm
                            label = (branded and "† " or "") .. short(nm, 16)
                            it.val.Text = string.format("%d · %s", math.floor(tonumber(d.score) or 0), short(d.why or "-", 10))
                            it.val.TextColor3 = (d.char == Bot.Target) and ACCENT or DIM
                        else
                            label = ""
                            it.val.Text = ""
                        end
                    elseif def.theme then
                        it.val.Text = tostring(Theme.p().label)
                        it.val.TextColor3 = ACCENT
                    elseif def.key then
                        local on = Config[def.key] and true or false
                        it.val.Text = on and "on" or "off"
                        it.val.TextColor3 = on and ACCENT or DIM
                    else
                        it.val.Text = ""
                    end
                    it.lbl.Text = tostring(label or "")
                end
            end
            layout()
        end

        if Theme.reopenMenu then
            Theme.reopenMenu = nil
            setMenu(true)
        end

        -- ------------------------------------------------------------- pulse
        local eyeOpen, eyeHot = nil, nil
        task.spawn(function()
            local phase = false
            while gui and gui.Parent do
                phase = not phase
                local period = eyeOpen and (eyeHot and 0.5 or 1.4) or 3.0
                if eyeOpen then
                    tween(halo1, period, { BackgroundTransparency = phase and 0.72 or 0.86,
                        Size = UDim2.new(0, EYE + (phase and 26 or 18), 0, EYE + (phase and 26 or 18)) })
                    tween(halo2, period, { BackgroundTransparency = phase and 0.88 or 0.95,
                        Size = UDim2.new(0, EYE + (phase and 60 or 44), 0, EYE + (phase and 60 or 44)) })
                    tween(ring, period, { Transparency = phase and 0.35 or 0.75 })
                    for i, def in ipairs(AURA) do
                        tween(auraStrokes[i], period, { Transparency = def[2] + (phase and -0.08 or 0.06) })
                    end
                else
                    tween(halo1, period, { BackgroundTransparency = phase and 0.93 or 0.97,
                        Size = UDim2.new(0, EYE + 14, 0, EYE + 14) })
                    tween(halo2, period, { BackgroundTransparency = 1 })
                    tween(ring, period, { Transparency = 1 })
                end
                task.wait(period)
            end
        end)

        local function setEye(open, hot)
            if open == eyeOpen and hot == eyeHot then return end
            eyeOpen, eyeHot = open, hot
            local col = hot and BAD or ACCENT
            halo1.BackgroundColor3 = col
            halo2.BackgroundColor3 = col
            for i = 1, #auraStrokes do auraStrokes[i].Color = col end
            if open then
                auraRoot.Visible = true
                setEyeTint(hot and Color3.new(1, 0.85, 0.85) or Color3.new(1, 1, 1), 0)
            else
                for i = 1, #auraStrokes do tween(auraStrokes[i], 0.8, { Transparency = 1 }) end
                task.delay(0.85, function() if not eyeOpen then auraRoot.Visible = false end end)
                setEyeTint(Color3.fromRGB(150, 140, 135), 0.35)
            end
        end

        -- ----------------------------------------------------------- refresh
        local function refresh()
            local running = Config.Enabled and true or false
            local hpPct = math.floor(getHPPct() or 0)
            local hurt = running and hpPct > 0 and hpPct < (Config.RetreatHP or 25)
            setEye(running, hurt)

            local st = tostring(Bot.State or "IDLE")
            local stunned = false
            pcall(function() stunned = isStunned() or isRagdolled() or isDowned() end)
            local kills = math.floor(tonumber(Bot.Kills) or 0)
            local up = (running and (tonumber(Bot.StartTime) or 0) > 0) and (tick() - Bot.StartTime) or 0
            local manual = (Bot.LockMode == "MANUAL") and Bot.LockedName ~= nil

            if not running then
                l1.Text = TP.idle
                l1.TextColor3 = DIM
                l2.Text = "tap the eye"
                l2.TextColor3 = DIM
                l3.Text = ""
            else
                local word = stunned and "Stunned" or (STATE_WORD[st] or st)
                if hurt then word = word .. "  ·  bleeding" end
                l1.Text = word
                l1.TextColor3 = hurt and BAD or ACCENT2

                local t = Bot.Target
                if t and t.Parent then
                    l2.Text = string.format("%s   ·   %d st   ·   %d%%",
                        short(nameOf(t), 16), math.floor(tonumber(Bot.Dist2D) or 0), math.floor(numOf(getHPPct, t)))
                    l2.TextColor3 = TXT
                else
                    local why = (st == "IDLE") and (Bot.SeekChar and string.format("seeking, %.0f st", Bot.SeekDist or 0)
                        or (Bot.HuntGoal and tostring(Bot.HuntWhy or "roaming")) or "no one in sight") or "no target"
                    l2.Text = why
                    l2.TextColor3 = DIM
                end

                local parts = {}
                if manual then parts[#parts + 1] = "branded " .. short(Bot.LockedName, 12) end
                local top = (Bot.Scores or {})[1]
                if top and top.why and top.char == Bot.Target then parts[#parts + 1] = tostring(top.why) end
                local plan = Bot.Plan
                if type(plan) == "table" then
                    if plan.flankEarly then parts[#parts + 1] = "flank early" end
                    if plan.punishEarly then parts[#parts + 1] = "punish early" end
                    if plan.closeHard then parts[#parts + 1] = "close hard" end
                    if tonumber(plan.bestRange) then parts[#parts + 1] = string.format("range %.0f", plan.bestRange) end
                end
                if Bot.Losing then parts[#parts + 1] = "losing" end
                if (Bot.Attackers or 0) >= 2 then parts[#parts + 1] = "ganged" end
                if isAwakened() then parts[#parts + 1] = "awakened" end
                l3.Text = table.concat(parts, "   ·   ")
            end

            local c = getChar()
            local set = c and c:GetAttribute("Moveset")
            l4.Text = string.format("%s  ·  %d slain  ·  %s  ·  hp %d%%  ·  wrath %d%%",
                tostring(set or "no vessel"), kills, fmtClock(up), hpPct, math.floor(getUltMeter() or 0))

            if menu.Visible then syncMenu() end
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
            elseif input.KeyCode == Enum.KeyCode.Insert then
                setMenu(not menu.Visible)
            end
        end)

        syncMenu()
        pcall(refresh)

        -- Arrive: the eye and its words fade in from nothing.
        pcall(function()
            if eyeImg:IsA("ImageLabel") then
                local target = eyeImg.ImageTransparency
                eyeImg.ImageTransparency = 1
                tween(eyeImg, 1.4, { ImageTransparency = target }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            for _, l in ipairs({ l1, l2, l3, l4 }) do
                l.TextTransparency = 1
                tween(l, 1.4, { TextTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
        end)
    end

    Theme.rebuild = buildHUD
    local okB, errB = pcall(buildHUD)
    if not okB then
        debug("[HUD] build failed (engine still running): " .. tostring(errB))
        pcall(announce, "HUD failed to build - bot still runs; see log")
    end
end

announce("The Eye HUD on v83 - tap the eye for the menu, RightCtrl/F5 toggles, Insert opens the menu, RightShift releases the mark")















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

