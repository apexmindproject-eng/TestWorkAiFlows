# Client Script Dump — Reverse-Engineering Reference (Client/Server Boundary)

*Covers game versions 1.82 (script dump, §1–§16) and 1.85 (place file, §17 and Appendix C). §18 is public-source research on move behaviour, second-hand and marked as such.*

Source: `ScriptDump.zip` (573 decompiled Lua files) plus supplement `missing_deps.zip` (155 files, of which **13 are new scripts**; the other 142 are re-dumps of files already in the first archive — deduped by content), extracted 2026-09-08 from the client of one Roblox fighting game (JJK-style "Shenanigans" clone; version string `1.82 — THE NOTHING UPDATE`; dev group 16357742; test place 9164905432). Everything below is derived only from this client dump. Anything the server owns (damage, cooldown numbers, unlock rules, hit validation, mode rules) is marked **n/a (server)** with whatever indirect evidence exists.

**Second source — place file, 1.85.** `shanin.rbxl`: a binary place file saved with UniversalSynSaveInstance from the same game at version string `1.85 — THE HALLOWEEN UPDATE` (dumping player `SmartzyMan`, playing `Uro`). 71,665 instances in 201 classes; 962 scripts carry decompiled source (917 ModuleScript, 32 Script, 13 LocalScript; 7.9 MB). Unlike `ScriptDump.zip` it keeps the instance tree, so GUI layout, attributes, asset folder names and — most usefully — the whole `ReplicatedStorage.Knit.Knit.Services` remote tree are read directly instead of inferred. **§17** is the 1.82 → 1.85 delta; **Appendix C** is the full service/remote register. §1–§16 still describe 1.82 unless a line is marked **(1.85)**.

How to read: §1–§4 are the global picture (architecture, boundary, state markers, game data). §5 is the per-character reference. §6–§12 cover core systems, GUI/shop, admin, anti-cheat, camera, libraries. §13 is the consolidated ID register, §14 open questions, §15 coverage. Appendix A is the per-file catalogue (every one of the 586 unique files appears exactly once, either there or in the dupe/stub tables of §1).

---

## 1. Dump facts, dedupe, gaps

| Metric | Value |
|---|---|
| Files in zip | 573 (all `.lua`, single folder, filename = instance path with `_` separators; real path in the 8-line header) |
| Byte-identical duplicates | 0 |
| Content duplicates after stripping comments/whitespace | 4 groups (Knit `_Index` one-line re-exports: `Signal` ×3 (comm/component/input), `Signal` ×2 (streamable/timer), `Trove` ×2 (component/input), `Promise` ×2 (comm/component)) — documented once in §12/Appendix A, never re-described |
| "failed to get script bytecode" stubs (server `Script`s, no client bytecode) | 17 — `Health` ×12 (root, `Aaqwert112233A/Health`, `StarterPlayer/StarterCharacterScripts/Health`, and one per live character under `Workspace/Characters/{Alva270, Erikplase325, Martel12346, SmartzyMan, animegod123l, gamerbombast, itsKMSVR, tackierambow, theplasmaguy7}`), root `Animate`, root `Script`, root `LocalScript`, `Workspace/Map/Core/the most blatant ad ever/Part/AL2_TP`, `Workspace/Map/Destructible/Model/Ads/MoneyDestroyer5000` |
| Obfuscated (Luraph/Owl-Fuscator VM, unreadable) | 2 — `AntiCheatController` (115 KB), root `CameraController` (210 KB) |
| Readable game code | 554 files (+13 from supplement = 567) |
| Supplement `missing_deps.zip` | 155 files in 29 search-strategy folders (`NAME_*`, `DEEP_*`, `KW_*`, `P_*`), 60 unique contents, 47 already in the main dump, **13 new**: `ToolController`, `MovementController`, `HandicapController`, `JoinController`, `EmoteController`, `BeamController`, `Modules/KeybindIcons`, `PlayerModule` root, `ControlModule`, `CameraModule`, `MouseLockController`, and two skill controllers absent from the first dump: `Hiromi/Awake/FinalJudgementController`, `Todo/Base/ElbowDropController`. Header format differs (2-line `-- path / -- type`); paths are `StarterPlayer/StarterPlayerScripts/...` (template copies) except `CameraModule` (runtime copy under `Players/SmartzyMan`). |
| Dump was taken from player `SmartzyMan` (`Players/SmartzyMan/PlayerScripts/...`); 9 other players were present (Health stubs) |

**Runtime findings (§16).** A later pass tested this client against the live
server across roughly 300 lives. §16 records what was measured rather than
read, including several things the dump alone gets wrong: `MovementService.Throwable`
is a toggle rather than a pickup, `ReplicatedStorage.Animations` is a usable
runtime index of what every player is doing, and `JoinService.Change` forces a
respawn with three silent failure modes. Where §16 and the sections above
disagree, §16 is the one that was tested.

**1.85 delta (§17).** A place file of the next major update was read in November 2026. Three things in it change what a client has to do: respawning is now manual (`JoinService.Respawn`, §17.2), a 26th character `Toji` exists (§5 "Toji", §17.5), and `ToolController` gained a seventh skill-argument code (§17.3).

**Coverage gaps closed by the supplement.** The five controllers the first dump only referenced (`ToolController`, `JoinController`, `EmoteController`, `HandicapController`, `MovementController`) plus `BeamController`, `KeybindIcons` and the PlayerModule root/`ControlModule`/`CameraModule`/`MouseLockController` are now present and analysed (§6.9–6.12, Appendix A.10). **Still absent:** TopbarPlus root `Icon`, `FastCastRedux.TypeDefinitions`, `Modules.BuilderFX` (creator-clash visual runtime), `EmoteController.Effects` child module, the `ReplicatedStorage.Keybind` loader (so **default key codes** are still unknown — only action names are), the `CopyController.SelectRemote` wiring detail, `Yuta` `Rika` effects module, and all GUI/Animations/Utils/Sounds instances. Server code remains entirely out of scope.

---

## 2. Architecture (prose)

**Framework.** The client is a Knit (sleitnick, ~1.5.x) application. `PlayerScripts/KnitRunClient` calls `Knit.AddControllersDeep(PlayerScripts.Controllers)` then `Knit.Start({ServicePromises=false})`, and activates the Cmdr admin console on F2 / `;`. 210 controllers are defined (`Knit.CreateController{Name=...}`) and exactly 210 distinct Knit services are fetched with `Knit.GetService("<X>Service")` — one service per controller, same base name. Services live under `ReplicatedStorage.Knit.Services.<Name>/{RF,RE,RP}` (sleitnick comm 1.0.1); the client's `ClientComm` wraps `RF` children as RemoteFunctions (`Service:Method()`), `RE` as RemoteSignals (`Service.Signal:Connect / :Fire`) and `RP` as RemoteProperties.

**Controller taxonomy.**

| Group | Count | Role |
|---|---|---|
| `Controllers/Moveset/<Char>/...` | 196 | One *character controller* per character (`GojoController`, `MahitoController`, …: M1 hit FX, chase hits, awakening cinematics, skins) plus one *skill controller* per move (`LapseBlueController`, …). Some folders are split `Base`/`Awake`/`Rika`/`Archive`. |
| `Controllers/Character/*` | 6 (+5 supplement) | `AntiCheatController` (obfuscated), `JoinController/*` menus: Inventory, Nep (radio NPC), Rules, Settings, UpdateLog; supplement adds `ToolController` (input router), `MovementController`, `JoinController` (menus + position replication), `EmoteController`, and `Combat/HandicapController`, `BeamController` |
| `Controllers/Combat/HitboxController` | 1 | Client-side sphere hitbox (see §3) |
| `FXController`, `DomainController`, `ItemController`, `DebugController`, `DiscordController(+Client)` | 6 | Shared VFX/SFX API, domain clash cinematics, item FX, creator/admin panel, Discord Rich Presence stub |
| `Controllers/RankedController/*` | 3 | `RouletteController`, `FinalShowdownController`, `NightParadeController` (game modes; use a custom `Start()` lifecycle) |

**The universal skill-controller pattern.** Every moveset controller is a *renderer*: it builds a table `{EffectName = function(...) end}` and connects `Service.Effects:Connect(function(name, ...) tbl[name](...) end)`. `Effects` is a server→client RemoteSignal; the server decides *what happened* (hit, grab, finisher, dialogue) and the client only draws it (clones templates from `ReplicatedStorage.Utils.<Char>.<Move>`, plays `ReplicatedStorage.Sounds.<Char>.<Move>` through `FXController:PlaySound`, shakes the camera via `CameraShaker.CurrentShaker:Shake(Presets.X)`, spawns blood via `BloodyZee`). Input handling is *not* in these controllers (`UserInputService` is required and discarded in almost every file). Most skill files therefore contain zero client→server traffic; the ones that do are enumerated in §3.

**Where the server *asks the client* for authority.** Two S→C signals hand the client a per-use `RemoteEvent` instance and expect an answer: `HitboxService.Hitbox(char, offsetCF, diameter, remote, lifetime?)` (generic) and per-character `XService.Hitbox(inst, char, remote)` (Gojo, Mokou, Mokou2, PuppetBarrage, Kurourushi, Mahito, Uro, Revolve, CursedStrikes). The client runs `HitboxController:SphereHitbox` in a 25–50 ms loop and fires the resulting character list back. Several other effects pass a remote purely for aim/landing/choice streams (see §3 table). `ReplicatedStorage.Remotes.GetClient(remote)` is the generic "send me your camera CFrame" query. All of these are **client-authoritative**: nothing in the dump validates them client-side, and the server-side checks are not visible.

**Replicated data layout referenced.** `ReplicatedStorage.{Knit, CmdrClient, Modules, Utils (VFX templates per char), Sounds (per char), Animations (per char, see §4.9), Remotes (GetClient, Message, Request, ForceFun, TTS, UpdateActivity…), Keybind (InputAction/InputBinding tree with Keyboard/Gamepad children)}`. Workspace: `Characters` (all player models live here, not under `workspace` root — the hitbox OverlapParams include only this folder), `Effects` (+`Blood`, `Bolt`, `Crows`, `Music`, `WaitAmbience`), `Domains`, `Bullets`, `Spawns`, `Map` (+`Destructible`, `Core`, `Data` = PartCache pool). `SoundService` groups: `Effect`, `Music`, `Music2`, `Voice`, `Taunt`. GUI roots: `PlayerGui.Main` (HUD; `Controls`, `Controls.Ultimate.Time`, `FPS`), `Menus` (`Group.{Inventory,Rules,Settings,Logs,Private}`, `Preset.*`, `Notif`), `Roulette`, `Ranked`, `Emotes`, `Miracles` (Mechamaru), `Adaptation` (Mahoraga), `DomainFade`.

**Globals.** `_G.Settings` (server-persisted settings blob, pushed as Zstd-compressed JSON via `JoinService.Setting("Batch", buffer)`), `_G.LocalSettings` (session-only "Fun" toggles), `_G.SettingUpdate.<key>` BindableEvents, `_G.MapParams` (shared RaycastParams for map geometry; 50 uses), `_G.GroupId = 16357742`, `_G.MVP_PLAYING`, `_G.Crow`, `_G.Shift`, `_G.TutorialIcon`, `_G.WorkshopIcon`. VFX gates: `_G.Settings.Flash` (58 uses: impact frames / colour-correction flashes), `Gore` (21), `DesPHY` (16), `DesVFX`, `DesINT`, `ScreenShake`, `SENS`, `UIS`, `Outfit`.

**Client-side movement.** Beyond remotes, many effects set the *local* character's velocity/CFrame directly on server-created movers (BodyVelocity/BodyGyro/AlignPosition) or on the HRP itself: dashes (WingKing, RedScale, SwiftKick, BoostOn, IdleTransfiguration, WingThrow), flights (Locust, Uro, BirdControl, Goku Nimbus, Mokou3 fireball), teleports (Todo swap, Gojo `CamFix`), pulls (Yuki BlackHole), and aim parts for beams (`Aerial`, `AutoRotate`). Because Roblox replicates the local character's physics from the owning client, these are all server-trusting paths even without a remote.

**Input layer (ToolController).** `ReplicatedStorage.Keybind.Combat.<Action>` objects (`Melee`, `Block`, `Special`, `Awaken`, `Drop Item`, `Shift Lock`, `Lock On`, `Dash`, `Emote`, `Skill 1..9`) expose `.Pressed/.Released`. Moves are **NumberValues under `char.Moveset`** created by the server, with attributes `Key` (hotbar slot 1–9), `Service` (Knit service name), `AWK` (hidden while `InUlt`), `AWK2` (only while `InUlt`), `LastUse`, `ReadyAt` (server-clock cooldown end), `SkipTo`, `Paused`, `Tag`, `Tip`, `Seal`. `Skill N` → `ReturnKey(N)` picks the first `char.Moveset` child with matching `Key` that passes the AWK/AWK2 filter → `Knit.GetService(Service).Activated:Fire(moveValue, extra)`; awakening therefore *remaps* a slot by having a base and an AWK2 value share the same `Key`. `Melee` loops at 40 Hz firing `<Moveset>Service.Activated(dir, GetTarget())`; `Special` → `RightActivated`, `Awaken` → `Ultimate/Deultimate`, `Block` → `BlockService.Activated(target)`. **There is no client-side cooldown, stun or state gate before any of these fires** — cooldown bars are display-only, driven by `ReadyAt` vs `workspace:GetServerTimeNow()`.

**Movement & physics ownership (MovementController / HandicapController).** The client sets `Humanoid.WalkSpeed`/`JumpPower` every Stepped (sprint ×1.375 of `StarterPlayer.CharacterWalkSpeed`, HP penalty ≤3, stun 0.1, block 4/6) and forces `HRP.Anchored=false`; dashes (`MovementService.Dash:Fire(dir)`) apply a local BodyVelocity immediately with a purely local 2 s / 0.45 s cooldown; parkour (vault/dive/slide/climb/wall-bounce) is decided entirely by client raycasts and reported with an argument-less `MovementService.Parkour:Fire()`. Server-applied knockback, grabs, ragdoll and status effects arrive as `HandicapService.Effects` and are *realised on the victim's own client* (`Swing` sets a server-made BodyVelocity's velocity every frame from a local vector; `Grab` `PivotTo`s the victim each Heartbeat).

**Position replication (JoinController).** Every `Stepped` the client sends `AntiCheatService.Camera:Fire(camPos24bit×3, hrpCFrame15B, char, NaN)`; the server rebroadcasts `{[playerName] = hrpBuf15}` and each client lerps *other* players' HRPs to those CFrames over 0.05 s (snap >15 studs). So other players' root positions are driven by this custom 15-byte stream and a player's own position is **client-reported**; whatever validation the "AntiCheat" service does is server-side and invisible. `AntiCheatService.Teleport(char, cfBuf, token)` is the server's corrective teleport, acked with `Teleport:Fire(token)`.

**Obfuscated modules.** `AntiCheatController` and the root-level `CameraController` are Luraph-family VMs (§10, §11). Their remotes, checks and APIs are not recoverable statically; every plaintext claim in this document about anti-cheat is therefore about what is *not* protected.

---

## 2.5 Knit: bootstrap, package layout, controller loading and the full controller registry

### 2.5.1 Bootstrap sequence (`Players/<you>/PlayerScripts/KnitRunClient`, LocalScript — runtime copy of `StarterPlayer/StarterPlayerScripts/KnitRunClient`)

```lua
local Knit = require(game.ReplicatedStorage.Knit.Knit)            -- 1. no wait: direct index
Knit.AddControllersDeep(script.Parent:WaitForChild("Controllers")) -- 2. waits for PlayerScripts.Controllers, then require()s every ModuleScript descendant, synchronously
Knit.Start({ ServicePromises = false }):catch(warn)                 -- 3. NOT awaited; returns a Promise
print("Loaded Knit on client!")
require(game.ReplicatedStorage:WaitForChild("CmdrClient")):SetActivationKeys({ Enum.KeyCode.F2, Enum.KeyCode.Semicolon })
-- then: HidePlayer hide-list (UserIds 1241352401 / 31070091 / 174332536 → Player.Parent = nil every Stepped)
```

| Step | What happens | Waits? | Failure mode |
|---|---|---|---|
| `require(ReplicatedStorage.Knit.Knit)` | `Knit/Knit` checks `RunService:IsServer()`; on the client it `:Destroy()`s the `KnitServer` child (if `IsRunning`) and returns `require(script.KnitClient)` | No (`ReplicatedStorage.Knit` is static content, already replicated) | Would error if `Knit` folder missing — never observed |
| `AddControllersDeep(Controllers)` | `for _, m in folder:GetDescendants() do if m:IsA("ModuleScript") then require(m) end end` — order = `GetDescendants()` (depth-first, instance order). Each module's top level runs `Knit.CreateController{Name=...}` which asserts the name is a unique non-empty string and stores it in the registry table | Only the initial `WaitForChild("Controllers")` | Any controller that errors or yields at module top level stalls/aborts the *whole* load (nothing is pcall-wrapped). `AntiCheatController`'s VM runs here too |
| `Knit.Start(opts)` | Sets `ServicePromises=false` (merged over defaults `{ServicePromises=true, Middleware=nil, PerServiceMiddleware={}}`), flips `started=true`, then: **phase 1** every controller's `KnitInit` wrapped in a Promise, run concurrently, `Promise.all`; **phase 2** every `KnitStart` via `task.spawn`; then fires the internal `OnStart` BindableEvent and `task.defer`-destroys it | `KnitInit`s that call `GetService` block on the service folder (below) | `:catch(warn)` prints a single failure; the LocalScript keeps running. `Start` twice → rejected Promise "Knit already started" |
| `Knit.GetService(name)` | Cached per name. First call: `script.Parent:WaitForChild("Services")` (= `ReplicatedStorage.Knit.Services`, created at runtime by `KnitServer`). Then `ClientComm.new(Services, usePromise=false, name)` → `Services:WaitForChild(name, 60)` (comm `Util.WaitForChildTimeout = 60`), asserts if nil. `BuildObject()` then `FindFirstChild`s `RF`/`RE`/`RP` and wraps each child: `RF` → plain blocking `InvokeServer` method (`ServicePromises=false`), `RE` → `ClientRemoteSignal` (`:Fire`, `:Connect`), `RP` → `ClientRemoteProperty` | Yes, up to 60 s per service | "Cannot call GetService until Knit has been started" if before `Start`; "Could not find namespace for ClientComm" after 60 s |
| `Knit.GetController(name)` | Registry lookup; errors `Could not find controller "X"` if absent (after `Start`) or asserts if before | No | — |
| `Knit.OnStart()` | Resolved Promise if started, else `Promise.fromEvent(startedEvent)` | — | Unused by any dumped script |

**Not done anywhere:** re-parenting Knit or controllers to `nil`, `require`-ing Knit from a `nil`-parented copy, `pcall` around controller loading, `Knit.OnStart()` gating, or waiting on `Knit.Start()`'s promise. The only `Parent = nil` in the client is the HidePlayer loop on `Player` objects.

### 2.5.2 Every path Knit is loaded from

| `require(...)` expression | Sites | Resolved instance |
|---|---|---|
| `game.ReplicatedStorage.Knit.Knit` | 223 (KnitRunClient, all 218 controllers, `Settings/Controls/Auto Use`, `Settings/Controls/Keybinds`, `Settings/General/Awakening Outfit`, `Modules/KeybindIcons`) | `ReplicatedStorage/Knit/Knit` → `…/Knit/KnitClient` |
| `<ReplicatedStorage alias>.Knit.Knit` | 1 | same |
| `<ReplicatedStorage alias>.Knit.Trove` | 6 (controllers using Trove directly) | `ReplicatedStorage/Knit/Trove` → `_Index/sleitnick_trove@1.1.0/trove` |
| `script.KnitClient` / `script.KnitServer` | 1 / 1 | inside `Knit/Knit` (client/server switch) |
| `script.Parent.Parent.Promise` / `.Comm` | inside `KnitClient` (`Util = script.Parent.Parent`) | `Knit/Promise` → `_Index/evaera_promise@4.0.0/promise`; `Knit/Comm` → `_Index/sleitnick_comm@1.0.1/comm` |

Non-controller modules that call `GetController("ToolController")` do so lazily inside callbacks (settings toggles, icon refresh), which is the only reason they don't trip the "until Knit has been started" assert.

### 2.5.3 Package tree (`ReplicatedStorage/Knit`, wally layout)

```
ReplicatedStorage/Knit
├─ Knit  (module: IsServer switch)          ├─ Comm, Promise, Signal, Trove, Option, Component,
│  └─ KnitClient  (170 lines, stock ~1.5.x) │  EnumList, Input, Streamable, TableUtil, Timer   ← 1-line re-exports
├─ Services/  ← runtime-only, made by KnitServer; NOT in dump. 210 × <Name>Service/{RF,RE,RP}
└─ _Index/
   ├─ evaera_promise@4.0.0/promise (+init.spec)
   ├─ sleitnick_comm@1.0.1/comm/{Util, Client/{ClientComm, ClientRemoteSignal, ClientRemoteProperty}, Server/{ServerComm, RemoteSignal, RemoteProperty}} + Option/Promise/Signal shims
   ├─ sleitnick_signal@2.0.1, sleitnick_trove@1.1.0, sleitnick_option@1.0.5, sleitnick_symbol@2.0.1,
   │  sleitnick_table-util@1.2.1, sleitnick_enum-list@2.1.0, sleitnick_component@2.4.8 (+Promise/Signal/Symbol/Trove shims)
   ├─ sleitnick_input@2.3.0/input/{Gamepad, Keyboard, Mouse, PreferredInput, Touch} (+Signal/Trove shims)
   ├─ sleitnick_timer@1.1.2/timer (+Signal shim → requires missing sleitnick_signal@1.5.0)
   └─ sleitnick_streamable@1.2.4/streamable/{Streamable, StreamableUtil} (+Signal/Trove shims → missing signal@1.5.0 / trove@0.4.2)
```

Comm constants that matter: `DefaultCommFolderName = "__comm__"` (unused — Knit passes the service name), `WaitForChildTimeout = 60`. `Knit.Streamable`/`Knit.Timer` would error on require (broken `_Index` deps) but nothing in the client requires them. 13 `*.spec` TestEZ files ship to the client as dead weight.

### 2.5.4 Controller folder layout (`PlayerScripts/Controllers`, 218 controllers + 2 helper modules)

| Folder | Count | Contents |
|---|---|---|
| `Controllers/` (root) | 6 | `BeamController`, `DebugController`, `DomainController`, `FXController`, `ItemController`, `DiscordController` (folder with child `DiscordClient` helper module — also `require`d by `AddControllersDeep` because it is a ModuleScript descendant; it returns a plain table, not a controller) |
| `Controllers/Character/` | 5 + `JoinController/` | `AntiCheatController` (obfuscated), `EmoteController`, `JoinController`, `MovementController`, `ToolController`; subfolder `JoinController/` with `InventoryController`, `NepController`, `RulesController`, `SettingsController`, `UpdateLogController` |
| `Controllers/Combat/` | 2 | `HitboxController`, `HandicapController` |
| `Controllers/RankedController/` | 3 | `RouletteController`, `FinalShowdownController`, `NightParadeController` |
| `Controllers/Moveset/<Char>/` | 198 | 25 character folders (+ `Custom/`, `Heian/`). Sub-splits: `Gojo/{Base,Awake,Gojo}`, `Choso/{Base,Awake,Choso}`, `Yuta/{Base,Awake,Rika}`, `Hanami/{Base,Awake}`, `Hiromi/{Base,Awake}`, `Itadori/{Base,Awake}`, `Mechamaru/{Base,Awake}`, `Nanami/{Base,Awake}`, `Naoya/{Base,Awake}`, `Todo/{Base,Awake}`, `Custom/{Mokou…, Archive/}` — folder names carry no semantics for Knit; `AddControllersDeep` flattens everything |

Every one of the 218 named controllers defines **both** `KnitInit` and `KnitStart` (some empty). The uniform body shape is: top-level `require(Knit)`, grab Roblox services, `CreateController{Name}`; `KnitInit` = `GetService("<X>Service")` + `GetController("FXController"/"HitboxController"/…)` into upvalues; `KnitStart` = build the `Effects` handler table and `Service.Effects:Connect(...)`. Dependencies are therefore resolved *after* all `CreateController` calls, so load order inside `AddControllersDeep` is irrelevant — except for the four modules that do work at module top level: `SettingsController` (creates `_G.Settings/LocalSettings/SettingUpdate`), `MovementController` (`_G.Shift`, `_G.MapParams`), `ToolController` (creates the `Selected` ObjectValue), `HitboxController` (connects `Remotes.GetClient.OnClientEvent` immediately).

Controller dependency fan-in (`GetController` callers): `FXController` 213, `HitboxController` 92, `ToolController` 39, `MokouController` 10, `HandicapController` 5, `JoinController` 4, `KurourushiController` 4, `MovementController` 2, `UpdateLogController` 1, `EmoteController` 1, `CopyController` 1, `CharlesController` 1. Controllers with more than one service: `ToolController` (Block, Custom, Emote, Item, Join, Movement + lazy per-moveset via `GetToolService`), `MovementController` (Movement, Item, Achievement), `HandicapController` (Handicap, Block, Custom), `JoinController` (Join, AntiCheat), `SettingsController` (Join, Achievement), `RouletteController` (Roulette, Achievement), `DebugController` (Debug, Build), `FXController` (Debree, Domain), `DecisiveStrikeController` (DecisiveStrike, DecisiveStrike2).

**Lifecycle oddities.** The three `RankedController/*` modules define an extra `Start()` method (round UI, spectate, kit pick) in addition to `KnitStart` — but **no dumped code ever calls `:Start()` on them** (no `GetController("RouletteController")` anywhere), so the mode UI is either driven by an undumped script/GUI LocalScript or from inside one of the two obfuscated VMs. `DiscordController` is an empty shell whose only effect is `require(script.DiscordClient)`. The root-level obfuscated `CameraController` is **not** under `Controllers` and is not a Knit controller (returns `true`); its loader is unknown.

### 2.5.5 Full controller registry

Generated from source. Path is relative to `PlayerScripts/` (supplement files came from `StarterPlayer/StarterPlayerScripts/`, same tree). "S→C signals connected" lists Knit RemoteSignals other than `Effects` that the controller connects to (nearly every controller also connects `Service.Effects`). FireServer/InvokeServer counts are raw call sites.

| # | Path (under PlayerScripts) | Knit name | Lines | Services (`GetService`) | Controllers (`GetController`) | Init | Start | S→C signals connected | FireServer / InvokeServer |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `Controllers/BeamController` | `BeamController` | 170 | BeamService | FXController, ToolController | ✓ | KnitStart | Effects | 3 / 0 |
| 2 | `Controllers/Character/AntiCheatController` | `(obfuscated)` | 2593 | — | — | — | — | — | 0 / 0 |
| 3 | `Controllers/Character/EmoteController` | `EmoteController` | 234 | EmoteService | FXController | ✓ | KnitStart | Effects, Equip, JumpRequest | 0 / 0 |
| 4 | `Controllers/Character/JoinController` | `JoinController` | 766 | AntiCheatService, JoinService | UpdateLogController | ✓ | KnitStart | Camera, Reset, Talk, Teleport | 2 / 0 |
| 5 | `Controllers/Character/JoinController/InventoryController` | `InventoryController` | 346 | EmoteService | EmoteController, FXController | ✓ | KnitStart | ChangeInv, ChangeSkin | 0 / 0 |
| 6 | `Controllers/Character/JoinController/NepController` | `NepController` | 136 | NepService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 7 | `Controllers/Character/JoinController/RulesController` | `RulesController` | 100 | JoinService | FXController | ✓ | KnitStart | — | 0 / 0 |
| 8 | `Controllers/Character/JoinController/SettingsController` | `SettingsController` | 376 | AchievementService, JoinService | FXController, ToolController | ✓ | KnitStart | Give, Setting | 0 / 0 |
| 9 | `Controllers/Character/JoinController/UpdateLogController` | `UpdateLogController` | 240 | — | FXController | ✓ | KnitStart | — | 0 / 0 |
| 10 | `Controllers/Character/MovementController` | `MovementController` | 1100 | AchievementService, ItemService, MovementService | FXController, HandicapController, ToolController | ✓ | KnitStart | Effects, ResetDash, Throwable | 0 / 0 |
| 11 | `Controllers/Character/ToolController` | `ToolController` | 1428 | BlockService, CustomService, EmoteService, ItemService, JoinService, MovementService | CopyController, HandicapController, MovementController | ✓ | KnitStart | MobileLayout | 1 / 0 |
| 12 | `Controllers/Combat/HandicapController` | `HandicapController` | 979 | BlockService, CustomService, HandicapService | FXController, ToolController | ✓ | KnitStart | Effects, FX, FX2, Hit, LOOK, PARTICLE, PARTICLE2, SFX, SFX2 | 0 / 0 |
| 13 | `Controllers/Combat/HitboxController` | `HitboxController` | 77 | HitboxService | — | ✓ | KnitStart | Hitbox | 2 / 0 |
| 14 | `Controllers/DebugController` | `DebugController` | 517 | BuildService, DebugService | FXController | ✓ | KnitStart | Debug, Update | 1 / 0 |
| 15 | `Controllers/DiscordController` | `DiscordController` | 22 | — | — | ✓ | KnitStart | — | 0 / 0 |
| 16 | `Controllers/DiscordController/DiscordClient` | `(none)` | 47 | — | — | — | — | — | 1 / 0 |
| 17 | `Controllers/DomainController` | `DomainController` | 759 | DomainService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 18 | `Controllers/FXController` | `FXController` | 1211 | DebreeService, DomainService | — | ✓ | KnitStart | CFix, Create, Domain, Physics, PreRender, Prop, Sound | 0 / 0 |
| 19 | `Controllers/ItemController` | `ItemController` | 770 | ItemService | CharlesController, FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 20 | `Controllers/Moveset/Charles/CharlesController` | `CharlesController` | 686 | CharlesService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 21 | `Controllers/Moveset/Charles/DespairController` | `DespairController` | 198 | DespairService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 22 | `Controllers/Moveset/Charles/EyeCatchController` | `EyeCatchController` | 77 | EyeCatchService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 23 | `Controllers/Moveset/Charles/SacrilegiousController` | `SacrilegiousController` | 189 | SacrilegiousService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 24 | `Controllers/Moveset/Charles/ShutUpController` | `ShutUpController` | 171 | ShutUpService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 25 | `Controllers/Moveset/Choso/Awake/BloodRainController` | `BloodRainController` | 157 | BloodRainService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 26 | `Controllers/Moveset/Choso/Awake/PlasmaWaveController` | `PlasmaWaveController` | 307 | PlasmaWaveService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 27 | `Controllers/Moveset/Choso/Awake/SlicingExorcismController` | `SlicingExorcismController` | 224 | SlicingExorcismService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 28 | `Controllers/Moveset/Choso/Awake/WingKingController` | `WingKingController` | 322 | WingKingService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 29 | `Controllers/Moveset/Choso/Base/BloodEdgeController` | `BloodEdgeController` | 143 | BloodEdgeService | FXController, HitboxController | ✓ | KnitStart | Effects | 1 / 0 |
| 30 | `Controllers/Moveset/Choso/Base/PiercingBloodController` | `PiercingBloodController` | 146 | PiercingBloodService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 31 | `Controllers/Moveset/Choso/Base/RedScaleController` | `RedScaleController` | 206 | RedScaleService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 32 | `Controllers/Moveset/Choso/Base/SupernovaController` | `SupernovaController` | 158 | SupernovaService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 33 | `Controllers/Moveset/Choso/ChosoController` | `ChosoController` | 332 | ChosoService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 34 | `Controllers/Moveset/Custom/Archive/BoostOn2Controller` | `BoostOn2Controller` | 290 | BoostOn2Service | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 35 | `Controllers/Moveset/Custom/Archive/GrappleController` | `GrappleController` | 200 | GrappleService | FXController, JoinController | ✓ | KnitStart | Effects | 0 / 0 |
| 36 | `Controllers/Moveset/Custom/Archive/PuppetBarrageController` | `PuppetBarrageController` | 265 | PuppetBarrageService | FXController, HitboxController | ✓ | KnitStart | Effects, Hitbox | 1 / 0 |
| 37 | `Controllers/Moveset/Custom/Archive/UltraCannon2Controller` | `UltraCannon2Controller` | 314 | UltraCannon2Service | FXController, HitboxController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 38 | `Controllers/Moveset/Custom/ChaosController` | `ChaosController` | 259 | ChaosService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 39 | `Controllers/Moveset/Custom/Mokou/Mokou1Controller` | `Mokou1Controller` | 124 | Mokou1Service | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 40 | `Controllers/Moveset/Custom/Mokou/Mokou2Controller` | `Mokou2Controller` | 161 | Mokou2Service | FXController, HitboxController | ✓ | KnitStart | Effects, Hitbox | 1 / 0 |
| 41 | `Controllers/Moveset/Custom/Mokou/Mokou3Controller` | `Mokou3Controller` | 179 | Mokou3Service | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 42 | `Controllers/Moveset/Custom/Mokou/Mokou4Controller` | `Mokou4Controller` | 163 | Mokou4Service | FXController, HitboxController, ToolController | ✓ | KnitStart | Effects | 2 / 0 |
| 43 | `Controllers/Moveset/Custom/Mokou/MokouController` | `MokouController` | 785 | MokouService | FXController, HitboxController | ✓ | KnitStart | Effects, Hitbox | 1 / 0 |
| 44 | `Controllers/Moveset/Gojo/Awake/HollowPurpleController` | `HollowPurpleController` | 224 | HollowPurpleService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 45 | `Controllers/Moveset/Gojo/Awake/LapseBlueMaxController` | `LapseBlueMaxController` | 339 | LapseBlueMaxService | FXController, ToolController | ✓ | KnitStart | Debree, Effects | 0 / 0 |
| 46 | `Controllers/Moveset/Gojo/Awake/ReversalRedMaxController` | `ReversalRedMaxController` | 301 | ReversalRedMaxService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 47 | `Controllers/Moveset/Gojo/Base/LapseBlueController` | `LapseBlueController` | 318 | LapseBlueService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 48 | `Controllers/Moveset/Gojo/Base/RapidPunchesController` | `RapidPunchesController` | 100 | RapidPunchesService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 49 | `Controllers/Moveset/Gojo/Base/ReversalRedController` | `ReversalRedController` | 110 | ReversalRedService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 50 | `Controllers/Moveset/Gojo/GojoController` | `GojoController` | 376 | GojoService | FXController, HitboxController | ✓ | KnitStart | Effects, Hitbox | 1 / 0 |
| 51 | `Controllers/Moveset/Goku/Base/KamehamehaController` | `KamehamehaController` | 207 | KamehamehaService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 52 | `Controllers/Moveset/Goku/Base/KiSpamController` | `KiSpamController` | 92 | KiSpamService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 53 | `Controllers/Moveset/Goku/Base/StaffExtendController` | `StaffExtendController` | 144 | StaffExtendService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 54 | `Controllers/Moveset/Goku/Base/StaffUppercutController` | `StaffUppercutController` | 84 | StaffUppercutService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 55 | `Controllers/Moveset/Goku/GokuController` | `GokuController` | 526 | GokuService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 56 | `Controllers/Moveset/Hakari/Awake/EnergySurgeController` | `EnergySurgeController` | 166 | EnergySurgeService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 57 | `Controllers/Moveset/Hakari/Awake/LuckyRushdownController` | `LuckyRushdownController` | 178 | LuckyRushdownService | FXController, HitboxController, JoinController | ✓ | KnitStart | Effects | 0 / 0 |
| 58 | `Controllers/Moveset/Hakari/Awake/LuckyVolleyController` | `LuckyVolleyController` | 160 | LuckyVolleyService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 59 | `Controllers/Moveset/Hakari/Awake/OverLuckController` | `OverLuckController` | 163 | OverLuckService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 60 | `Controllers/Moveset/Hakari/Base/FeverBreakerController` | `FeverBreakerController` | 175 | FeverBreakerService | FXController | ✓ | KnitStart | — | 0 / 0 |
| 61 | `Controllers/Moveset/Hakari/Base/ReserveBallController` | `ReserveBallController` | 185 | ReserveBallService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 62 | `Controllers/Moveset/Hakari/Base/RoughEnergyController` | `RoughEnergyController` | 156 | RoughEnergyService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 63 | `Controllers/Moveset/Hakari/Base/ShutterDoorsController` | `ShutterDoorController` | 179 | ShutterDoorService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 64 | `Controllers/Moveset/Hanami/Awake/CursedBudsController` | `CursedBudsController` | 231 | CursedBudsService | FXController, ToolController | ✓ | KnitStart | Effects | 1 / 0 |
| 65 | `Controllers/Moveset/Hanami/Awake/FlowerBeamController` | `FlowerBeamController` | 262 | FlowerBeamService | FXController, MokouController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 66 | `Controllers/Moveset/Hanami/Awake/FlowerFieldController` | `FlowerFieldController` | 388 | FlowerFieldService | FXController, ToolController | ✓ | KnitStart | Effects, PreRender | 0 / 0 |
| 67 | `Controllers/Moveset/Hanami/Awake/RootRampageController` | `RootRampageController` | 626 | RootRampageService | FXController | ✓ | KnitStart | Effects | 1 / 0 |
| 68 | `Controllers/Moveset/Hanami/Base/BudShotController` | `BudShotController` | 83 | BudShotService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 69 | `Controllers/Moveset/Hanami/Base/DefenseResponseController` | `DefenseResponseController` | 361 | DefenseResponseService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 70 | `Controllers/Moveset/Hanami/Base/RootSwarmController` | `RootSwarmController` | 222 | RootSwarmService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 71 | `Controllers/Moveset/Hanami/Base/SurgingThornsController` | `SurgingThornsController` | 242 | SurgingThornsService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 72 | `Controllers/Moveset/Hanami/HanamiController` | `HanamiController` | 727 | HanamiService | FXController, HitboxController, MokouController | ✓ | KnitStart | Effects, PreRender | 0 / 0 |
| 73 | `Controllers/Moveset/Haruta/Base/AmbushController` | `StingerController` | 139 | AmbushService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 74 | `Controllers/Moveset/Haruta/Base/BackstabController` | `BackstabController` | 169 | BackstabService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 75 | `Controllers/Moveset/Haruta/Base/CheapShotController` | `CheapShotController` | 129 | CheapShotService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 76 | `Controllers/Moveset/Haruta/Base/TripController` | `TripController` | 79 | TripService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 77 | `Controllers/Moveset/Haruta/Hand/AnkleCutterController` | `AnkleCutterController` | 153 | AnkleCutterService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 78 | `Controllers/Moveset/Haruta/Hand/HighTimeController` | `HighTimeController` | 75 | HighTimeService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 79 | `Controllers/Moveset/Haruta/HarutaController` | `HarutaController` | 537 | HarutaService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 80 | `Controllers/Moveset/Heian/CleaveRushController` | `CleaveRushController` | 283 | CleaveRushService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 81 | `Controllers/Moveset/Heian/DismantleV2Controller` | `DismantleV2Controller` | 239 | DismantleV2Service | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 82 | `Controllers/Moveset/Heian/FurnaceArrowController` | `FurnaceArrowController` | 284 | FurnaceArrowService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 83 | `Controllers/Moveset/Heian/KamutokeController` | `KamutokeController` | 126 | KamutokeService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 84 | `Controllers/Moveset/Hiromi/Awake/ExecutionController` | `ExecutionController` | 297 | ExecutionService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 85 | `Controllers/Moveset/Hiromi/Awake/FinalJudgementController` | `FinalJudgementController` | 352 | FinalJudgementService | FXController, ToolController | ✓ | KnitStart | Effects | 3 / 0 |
| 86 | `Controllers/Moveset/Hiromi/Awake/TripleSentenceController` | `TripleSentenceController` | 273 | TripleSentenceService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 87 | `Controllers/Moveset/Hiromi/Awake/VerdictController` | `VerdictController` | 232 | VerdictService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 88 | `Controllers/Moveset/Hiromi/Base/ExtendSwingController` | `ExtendSwingController` | 180 | ExtendSwingService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 89 | `Controllers/Moveset/Hiromi/Base/JudgeReachController` | `JudgeReachController` | 79 | JudgeReachService | FXController, HitboxController, JoinController | ✓ | KnitStart | — | 0 / 0 |
| 90 | `Controllers/Moveset/Hiromi/Base/PressingChargesController` | `PressingChargesController` | 115 | PressingChargesService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 91 | `Controllers/Moveset/Hiromi/HiromiController` | `HiromiController` | 1119 | HiromiService | FXController, HitboxController | ✓ | KnitStart | Effects | 1 / 0 |
| 92 | `Controllers/Moveset/Itadori/Awake/DismantleController` | `DismantleController` | 322 | DismantleService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 93 | `Controllers/Moveset/Itadori/Awake/FlameArrowController` | `FlameArrowController` | 184 | FlameArrowService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 94 | `Controllers/Moveset/Itadori/Awake/RushController` | `RushController` | 185 | RushService | FXController, JoinController | ✓ | KnitStart | Effects | 0 / 0 |
| 95 | `Controllers/Moveset/Itadori/Base/CrushingBlowController` | `CrushingBlowController` | 113 | CrushingBlowService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 96 | `Controllers/Moveset/Itadori/Base/CursedStrikesController` | `CursedStrikesController` | 266 | CursedStrikesService | FXController, HitboxController | ✓ | KnitStart | Effects, Hitbox | 1 / 0 |
| 97 | `Controllers/Moveset/Itadori/Base/DivergentFistController` | `DivergentFistController` | 514 | DivergentFistService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 98 | `Controllers/Moveset/Itadori/Base/ManjiKickController` | `ManjiKickController` | 225 | ManjiKickService | FXController, MokouController | ✓ | KnitStart | Effects | 0 / 0 |
| 99 | `Controllers/Moveset/Itadori/ItadoriController` | `ItadoriController` | 433 | ItadoriService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 100 | `Controllers/Moveset/Kurourushi/Base/ChokeholdController` | `ChokeholdController` | 149 | ChokeholdService | FXController, KurourushiController | ✓ | KnitStart | Effects | 0 / 0 |
| 101 | `Controllers/Moveset/Kurourushi/Base/DetachController` | `DetachController` | 325 | DetachService | FXController, KurourushiController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 102 | `Controllers/Moveset/Kurourushi/Base/FesteringStrikesController` | `FesteringStrikesController` | 641 | FesteringStrikesService | FXController, KurourushiController | ✓ | KnitStart | Effects | 0 / 0 |
| 103 | `Controllers/Moveset/Kurourushi/Base/RoachSwarmController` | `RoachSwarmController` | 297 | RoachSwarmService | FXController, KurourushiController | ✓ | KnitStart | Effects, PreRender | 0 / 0 |
| 104 | `Controllers/Moveset/Kurourushi/KurourushiController` | `KurourushiController` | 1118 | KurourushiService | FXController, HitboxController, ToolController | ✓ | KnitStart | Effects, Hitbox, PreRender | 1 / 0 |
| 105 | `Controllers/Moveset/Locust/BlackMucusController` | `BlackMucusController` | 108 | BlackMucusService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 106 | `Controllers/Moveset/Locust/CleverController` | `CleverController` | 127 | CleverService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 107 | `Controllers/Moveset/Locust/CrushJawController` | `CrusshJawController` | 154 | CrushJawService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 108 | `Controllers/Moveset/Locust/LocustController` | `LocustController` | 262 | LocustService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 109 | `Controllers/Moveset/Locust/WingThrowController` | `WingThrowController` | 150 | WingThrowService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 110 | `Controllers/Moveset/Mahito/Awake/CrushingRushdownController` | `CrushingRushdownController` | 193 | CrushingRushdownService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 111 | `Controllers/Moveset/Mahito/Awake/FaceBlitzController` | `FaceBlitzController` | 250 | FaceBlitzService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 112 | `Controllers/Moveset/Mahito/Awake/HeadSplitterController` | `HeadSplitterController` | 164 | HeadSplitterService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 113 | `Controllers/Moveset/Mahito/Awake/WideSPStrikeController` | `WideSPStrikeController` | 220 | WideSPStrikesService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 114 | `Controllers/Moveset/Mahito/Base/BodyRepelController` | `BodyRepelController` | 265 | BodyRepelService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 115 | `Controllers/Moveset/Mahito/Base/FocusStrikeController` | `FocusStrikeController` | 407 | FocusStrikeService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 116 | `Controllers/Moveset/Mahito/Base/SoulfireController` | `SoulfireController` | 141 | SoulfireService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 117 | `Controllers/Moveset/Mahito/Base/StockpileController` | `StockpileController` | 214 | StockpileService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 118 | `Controllers/Moveset/Mahito/MahitoController` | `MahitoController` | 1077 | MahitoService | FXController, HitboxController, ToolController | ✓ | KnitStart | Effects, Hitbox | 2 / 0 |
| 119 | `Controllers/Moveset/Mahito/PreAwk/BodyDisfigureController` | `BodyDisfigureController` | 481 | BodyDisfigureService | FXController, HitboxController | ✓ | KnitStart | Effects | 1 / 0 |
| 120 | `Controllers/Moveset/Mahito/PreAwk/IdleTransfigurationController` | `IdleTransfigurationController` | 413 | IdleTransfigurationService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 121 | `Controllers/Moveset/Mahito/PreAwk/SpikeWrathController` | `SpikeWrathController` | 230 | SpikeWrathService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 122 | `Controllers/Moveset/Mechamaru/Awake/AbsoluteDestructionController` | `AbsoluteDestructionController` | 158 | AbsoluteDestructionService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 123 | `Controllers/Moveset/Mechamaru/Awake/MiracleCannonController` | `MiracleCannonController` | 212 | MiracleCannonService | FXController, HitboxController | ✓ | KnitStart | Debree, Effects | 0 / 0 |
| 124 | `Controllers/Moveset/Mechamaru/Awake/PigeonViolaController` | `PigeonViolaController` | 148 | PigeonViolaService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 125 | `Controllers/Moveset/Mechamaru/Awake/TechniqueChargeController` | `TechniqueChargeController` | 269 | TechniqueChargeService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 126 | `Controllers/Moveset/Mechamaru/Base/BoostOnController` | `BoostOnController` | 197 | BoostOnService | FXController, HitboxController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 127 | `Controllers/Moveset/Mechamaru/Base/HeatEmissionController` | `HeatEmissionController` | 197 | HeatEmissionService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 128 | `Controllers/Moveset/Mechamaru/Base/UltraCannonController` | `UltraCannonController` | 272 | UltraCannonService | FXController, ToolController | ✓ | KnitStart | Effects | 1 / 0 |
| 129 | `Controllers/Moveset/Mechamaru/Base/UltraSpinController` | `UltraSpinController` | 378 | UltraSpinService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 130 | `Controllers/Moveset/Mechamaru/MechamaruController` | `MechamaruController` | 599 | MechamaruService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 131 | `Controllers/Moveset/Megumi/Awake/GreatSerpentController` | `GreatSerpentController` | 290 | GreatSerpentService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 132 | `Controllers/Moveset/Megumi/Awake/MahoragaUseController` | `MahoragaUseController` | 335 | MahoragaUseService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 133 | `Controllers/Moveset/Megumi/Awake/MaxElephantController` | `MaxElephantController` | 140 | MaxElephantService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 134 | `Controllers/Moveset/Megumi/Awake/ShadowSwarmController` | `ShadowSwarmController` | 399 | ShadowSwarmService | FXController, HitboxController, MovementController | ✓ | KnitStart | Effects | 0 / 0 |
| 135 | `Controllers/Moveset/Megumi/Base/DivineDogController` | `DivineDogController` | 191 | DivineDogService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 136 | `Controllers/Moveset/Megumi/Base/NueController` | `NueController` | 213 | NueService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 137 | `Controllers/Moveset/Megumi/Base/RabbitEscapeController` | `RabbitEscapeController` | 206 | RabbitEscapeService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 138 | `Controllers/Moveset/Megumi/Base/ToadController` | `ToadController` | 287 | ToadService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 139 | `Controllers/Moveset/Megumi/Mahoraga/AdaptationController` | `AdaptationController` | 411 | AdaptationService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 140 | `Controllers/Moveset/Megumi/Mahoraga/DivinePummelController` | `DivinePummelController` | 98 | DivinePummelService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 141 | `Controllers/Moveset/Megumi/Mahoraga/EarthquakeController` | `EarthquakeController` | 127 | EarthquakeService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 142 | `Controllers/Moveset/Megumi/Mahoraga/GroundPitchController` | `GroundPitchController` | 170 | GroundPitchService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 143 | `Controllers/Moveset/Megumi/MegumiController` | `MegumiController` | 237 | MegumiService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 144 | `Controllers/Moveset/MeiMei/Base/BirdControlController` | `BirdControlController` | 191 | BirdControlService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 145 | `Controllers/Moveset/MeiMei/Base/CirclingController` | `CirclingController` | 739 | CirclingService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 146 | `Controllers/Moveset/MeiMei/Base/ImpetusUpdraftController` | `ImpetusUpdraftController` | 303 | ImpetusUpdraftService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 147 | `Controllers/Moveset/MeiMei/Base/MurmurateController` | `MurmurateController` | 411 | MurmurateService | FXController | ✓ | KnitStart | Effects | 1 / 0 |
| 148 | `Controllers/Moveset/MeiMei/MeiMeiController` | `MeiMeiController` | 458 | MeiMeiService | FXController, HitboxController, ToolController | ✓ | KnitStart | Effects | 1 / 0 |
| 149 | `Controllers/Moveset/Nanami/Awake/CollapseController` | `CollapseController` | 360 | CollapseService | FXController, HandicapController, HitboxController | ✓ | KnitStart | Effects | 1 / 0 |
| 150 | `Controllers/Moveset/Nanami/Awake/InterrogateController` | `InterrogateController` | 362 | InterrogateService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 151 | `Controllers/Moveset/Nanami/Awake/SharpenController` | `SharpenController` | 283 | SharpenService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 152 | `Controllers/Moveset/Nanami/Base/CleavingWhirlController` | `CleavingWhirlController` | 255 | CleavingWhirlService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 153 | `Controllers/Moveset/Nanami/Base/SeveranceKickController` | `SeveranceKickController` | 196 | SeveranceKickService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 154 | `Controllers/Moveset/Nanami/Base/StabilizeController` | `StabilizeController` | 127 | StabilizeService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 155 | `Controllers/Moveset/Nanami/NanamiController` | `NanamiController` | 473 | NanamiService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 156 | `Controllers/Moveset/Naoya/Awake/FlashFreezingController` | `FlashFreezingController` | 108 | FlashFreezingService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 157 | `Controllers/Moveset/Naoya/Awake/TendrilGrabController` | `TendrilGrabController` | 193 | TendrilGrabService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 158 | `Controllers/Moveset/Naoya/Awake/TopSpeedController` | `TopSpeedController` | 266 | TopSpeedService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 159 | `Controllers/Moveset/Naoya/Base/BleedoutController` | `BleedoutController` | 204 | BleedoutService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 160 | `Controllers/Moveset/Naoya/Base/CursoryImpactController` | `CursoryImpactController` | 272 | CursoryImpactService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 161 | `Controllers/Moveset/Naoya/Base/DecisiveStrikeController` | `DecisiveStrikeController` | 483 | DecisiveStrike2Service, DecisiveStrikeService | FXController, HandicapController | ✓ | KnitStart | Effects | 0 / 0 |
| 162 | `Controllers/Moveset/Naoya/Base/ProjectionBreakerController` | `ProjectionBreakerController` | 137 | ProjectionBreakerService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 163 | `Controllers/Moveset/Naoya/NaoyaController` | `NaoyaController` | 859 | NaoyaService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 164 | `Controllers/Moveset/Reggie/Awake/ArsonController` | `ArsonController` | 108 | ArsonService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 165 | `Controllers/Moveset/Reggie/Awake/BigMovesController` | `BigMovesController` | 93 | BigMovesService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 166 | `Controllers/Moveset/Reggie/Awake/MayhemController` | `MayhemController` | 131 | MayhemService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 167 | `Controllers/Moveset/Reggie/Base/BluntTraumaController` | `BluntTraumaController` | 183 | BluntTraumaService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 168 | `Controllers/Moveset/Reggie/Base/DroneStrikeController` | `DroneStrikeController` | 160 | DroneStrikeService | FXController, HitboxController | ✓ | KnitStart | Effects | 1 / 0 |
| 169 | `Controllers/Moveset/Reggie/Base/FlecheController` | `FlecheController` | 194 | FlecheService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 170 | `Controllers/Moveset/Reggie/Base/GarageSaleController` | `GarageSaleController` | 159 | GarageSaleService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 171 | `Controllers/Moveset/Reggie/Base/GushingWoundController` | `GushingWoundController` | 116 | GushingWoundService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 172 | `Controllers/Moveset/Reggie/Base/HomerunController` | `HomerunController` | 189 | HomerunService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 173 | `Controllers/Moveset/Reggie/Base/PianoDropController` | `PianoDropController` | 181 | PianoDropService | FXController, HitboxController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 174 | `Controllers/Moveset/Reggie/Base/PoleVaultController` | `PoleVaultController` | 142 | PoleVaultService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 175 | `Controllers/Moveset/Reggie/Base/SpeedCrashController` | `SpeedCrashController` | 177 | SpeedCrashService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 176 | `Controllers/Moveset/Reggie/ReggieController` | `ReggieController` | 383 | ReggieService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 177 | `Controllers/Moveset/Ryu/Awake/HadNoIdeaController` | `HadNoIdeaController` | 160 | HadNoIdeaService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 178 | `Controllers/Moveset/Ryu/Awake/WerentInvitedController` | `WerentInvitedController` | 242 | WerentInvitedService | FXController, MokouController | ✓ | KnitStart | Effects | 0 / 0 |
| 179 | `Controllers/Moveset/Ryu/Awake/WhatAreYouAfterController` | `WhatAreYouAfterController` | 175 | WhatAreYouAfterService | FXController, MokouController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 180 | `Controllers/Moveset/Ryu/Base/AppetizerController` | `AppetizerController` | 114 | AppetizerService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 181 | `Controllers/Moveset/Ryu/Base/GraniteBlastController` | `GraniteBlastController` | 192 | GraniteBlastService | FXController, MokouController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 182 | `Controllers/Moveset/Ryu/Base/SecondHelpingController` | `SecondHelpingController` | 180 | SecondHelpingService | FXController, MokouController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 183 | `Controllers/Moveset/Ryu/Base/UnsatisfiedController` | `UnsatisfiedController` | 207 | UnsatisfiedService | FXController, MokouController | ✓ | KnitStart | Effects | 0 / 0 |
| 184 | `Controllers/Moveset/Todo/Awake/BrothersController` | `BrothersController` | 216 | BrothersService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 185 | `Controllers/Moveset/Todo/Awake/ClimaxJumpController` | `ClimaxJumpController` | 361 | ClimaxJumpService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 186 | `Controllers/Moveset/Todo/Awake/DreamsController` | `DreamsController` | 179 | DreamsService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 187 | `Controllers/Moveset/Todo/Awake/IdolDebutController` | `IdolDebutController` | 259 | IdolDebutService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 188 | `Controllers/Moveset/Todo/Base/BruteForceController` | `BruteForceController` | 182 | BruteForceService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 189 | `Controllers/Moveset/Todo/Base/ElbowDropController` | `ElbowDropController` | 428 | ElbowDropService | FXController, HandicapController | ✓ | KnitStart | Effects | 0 / 0 |
| 190 | `Controllers/Moveset/Todo/Base/PebbleThrowController` | `PebbleThrowController` | 101 | PebbleThrowService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 191 | `Controllers/Moveset/Todo/Base/SwiftKickController` | `SwiftKickController` | 260 | SwiftKickService | FXController, HitboxController, ToolController | ✓ | KnitStart | Effects | 1 / 0 |
| 192 | `Controllers/Moveset/Todo/TodoController` | `TodoController` | 556 | TodoService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 193 | `Controllers/Moveset/Uro/BlindRageController` | `BlindRageController` | 212 | BlindRageService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 194 | `Controllers/Moveset/Uro/SkyDistortionController` | `SkyDistortionController` | 191 | SkyDistortionService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 195 | `Controllers/Moveset/Uro/ThinIceBreakerController` | `ThinIceBreakerController` | 221 | ThinIceBreakerService | FXController, MokouController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 196 | `Controllers/Moveset/Uro/UroController` | `UroController` | 654 | UroService | FXController, HitboxController, MokouController | ✓ | KnitStart | Effects, Hitbox | 1 / 0 |
| 197 | `Controllers/Moveset/Yuki/GarudaReboundController` | `GarudaReboundController` | 353 | GarudaReboundService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 198 | `Controllers/Moveset/Yuki/GarudaStabController` | `GarudaStabController` | 237 | GarudaStabService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 199 | `Controllers/Moveset/Yuki/MassBreakerController` | `MassBreakerController` | 142 | MassBreakerService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 200 | `Controllers/Moveset/Yuki/RisingRageController` | `RisingRageController` | 287 | RisingRageService | FXController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 201 | `Controllers/Moveset/Yuki/YukiController` | `YukiController` | 629 | YukiService | FXController, HitboxController | ✓ | KnitStart | Debree, Effects | 0 / 0 |
| 202 | `Controllers/Moveset/Yuta/Awake/CopyController` | `CopyController` | 341 | CopyService | FXController, HitboxController, ToolController | ✓ | KnitStart | — | 3 / 0 |
| 203 | `Controllers/Moveset/Yuta/Awake/ElbowRushController` | `ElbowRushController` | 152 | ElbowRushService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 204 | `Controllers/Moveset/Yuta/Awake/LoveBeamController` | `LoveBeamController` | 207 | LoveBeamService | FXController, HitboxController | ✓ | KnitStart | — | 0 / 0 |
| 205 | `Controllers/Moveset/Yuta/Base/OutburstController` | `OutburstController` | 393 | OutburstService | FXController, HitboxController, ToolController | ✓ | KnitStart | Effects | 0 / 0 |
| 206 | `Controllers/Moveset/Yuta/Base/ResoluteSlashController` | `ResoluteSlashController` | 565 | ResoluteSlashService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 207 | `Controllers/Moveset/Yuta/Base/RevolveController` | `RevolveController` | 141 | RevolveService | FXController, HitboxController | ✓ | KnitStart | Effects, Hitbox | 1 / 0 |
| 208 | `Controllers/Moveset/Yuta/Base/SeveringPathController` | `SeveringPathController` | 124 | SeveringPathService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 209 | `Controllers/Moveset/Yuta/Base/VeilstepController` | `VeilstepController` | 225 | VeilstepService | FXController | ✓ | KnitStart | Effects | 1 / 0 |
| 210 | `Controllers/Moveset/Yuta/Rika/RikaDownslamController` | `RikaDownslamController` | 135 | RikaDownslamService | FXController, HitboxController | ✓ | KnitStart | — | 0 / 0 |
| 211 | `Controllers/Moveset/Yuta/Rika/RikaGrabController` | `RikaGrabController` | 53 | RikaGrabService | FXController, HitboxController | ✓ | KnitStart | — | 0 / 0 |
| 212 | `Controllers/Moveset/Yuta/Rika/RikaHaymakerController` | `RikaHaymakerController` | 48 | RikaHaymakerService | FXController, HitboxController | ✓ | KnitStart | — | 0 / 0 |
| 213 | `Controllers/Moveset/Yuta/Rika/RikaLaunchController` | `RikaLaunchController` | 70 | RikaLaunchService | FXController, HitboxController | ✓ | KnitStart | — | 0 / 0 |
| 214 | `Controllers/Moveset/Yuta/Rika/RikaLoveBeamController` | `RikaLoveBeamController` | 397 | RikaLoveBeamService | FXController, HitboxController | ✓ | KnitStart | — | 0 / 0 |
| 215 | `Controllers/Moveset/Yuta/Rika/RikaSlamController` | `RikaSlamController` | 73 | RikaSlamService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 216 | `Controllers/Moveset/Yuta/Rika/RikaThrowController` | `RikaThrowController` | 101 | RikaThrowService | FXController, HitboxController | ✓ | KnitStart | — | 1 / 0 |
| 217 | `Controllers/Moveset/Yuta/YutaController` | `YutaController` | 425 | YutaService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 218 | `Controllers/RankedController/FinalShowdownController` | `FinalShowdownController` | 230 | FinalShowdownService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 219 | `Controllers/RankedController/NightParadeController` | `NightParadeController` | 47 | NightParadeService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 220 | `Controllers/RankedController/RouletteController` | `RouletteController` | 765 | AchievementService, RouletteService | FXController | ✓ | KnitStart | Effects | 2 / 0 |

---

## 3. Client/server boundary — consolidated

### 3.1 Traffic classes

| Class | Mechanism | Count in dump | Trust |
|---|---|---|---|
| S→C effect dispatch | `XService.Effects(name, ...)` | 210 services (every controller) | server-authoritative rendering |
| S→C auxiliary signals | `XService.Hitbox`, `.Debree`, `DebreeService.{Sound,Create,Physics,Prop,Domain}`, `DomainService.CFix`, `DebugService.{Debug,Update}`, `EmoteService.{ChangeInv,ChangeSkin}`, `JoinService.Setting`, `Remotes.{GetClient,Message,Request,ForceFun}`, `CmdrEvent` | — | — |
| C→S skill/input signals (`Service.X:Fire`) | `<Moveset>Service.Activated/Deactivated/RightActivated/RightDeactivated/Ultimate/Deultimate/Chase`, `BlockService.Activated/Deactivated`, `MovementService.Dash/Parkour/Throwable`, `ItemService.M1/M2/Drop/Dash`, `CustomService.Awaken/Melee/Special/Chase`, `DomainService.Activated`, `ItadoriService.UltimateEnchain`, `EmoteService.Emote/EmoteEnd`, `AntiCheatService.Camera/Teleport`, `JoinService.Change/Talk/Reset/MobileLayout` | ToolController, MovementController, EmoteController, JoinController | server must gate cooldown/state — client does not |
| C→S Knit signals (menus/admin) | `DebugService.Debug/Unban/Update`, `JoinService.Setting/AcceptRules/MobileLayout`, `AchievementService.Give`, `RouletteService.Spectate`, `EmoteService.Equip/ChangeInv/ChangeMVP/ChangeSkin`, `GamepadService.{LeftDown,LeftUp,RightDown,RightUp,MiddleDown,MiddleUp,Moved,Scrolled,Changed}` | 19 distinct | server validates (n/a) |
| C→S raw `FireServer` | 42 call sites in 35 files; mostly on *per-use RemoteEvents handed over by the server inside an Effects payload* | 42 | see 3.2 |
| C→S `InvokeServer` | `CmdrFunction` (admin console), `Remotes.TTS` (text→syllables), Knit `RF` wrappers | 10 | — |

### 3.2 Client-authoritative reports (the exploit surface)

| # | Report | Fired by | Payload | Server hint |
|---|---|---|---|---|
| 1 | **Generic hit list** | `HitboxController` on `HitboxService.Hitbox` | `remote:FireServer({charModel,...})` every 25 ms while any HRP is inside the sphere; no dedupe, no LOS, no team/dead/iframe filter | server must dedupe/validate — not visible |
| 2 | Gojo M1/skill hits | `GojoController` (`GojoService.Hitbox`) | `(hits\|nil, hrpCFrame)`; sphere ⌀10 @ (0,-1,-3) | — |
| 3 | Mokou hits | `MokouController` | `(hits\|nil, hrpCFrame)`; ⌀8 @ (0,0,-4) | — |
| 4 | Mokou2 dive | `Mokou2Controller` | `(hits\|false, groundPos\|nil)` | — |
| 5 | Puppet Barrage | `PuppetBarrageController` | `(hits\|nil, hrpCFrame)`, excludes Owner/User/Friend | — |
| 6 | Cursed Strikes | `CursedStrikesController` | `(hits, rayPos\|nil)`; ⌀12 @ (0,-5,-5) | — |
| 7 | Kurourushi | `KurourushiController` | `(hits\|nil, hrpCFrame)` | — |
| 8 | Mahito | `MahitoController` | `(hits, hrpCFrame)`; continuous mode every 50 ms | — |
| 9 | Uro | `UroController` | `(hits\|nil, hrpCFrame)`; ⌀10 @ (0,-1,-3) | — |
| 10 | Yuta Revolve | `RevolveController` | `(hits\|false, groundPos\|nil)`; ⌀8 @ (0,-5,-5) | — |
| 11 | Camera CFrame | `HitboxController` on `Remotes.GetClient` | `replyRemote:FireServer(camera.CFrame)` | used for aim |
| 12 | Landing/impact points (client raycast decides where a slam lands) | BloodEdge `Dash`, Nanami Collapse `Leap` (pos, normal, hrpPos), Murmurate `Flight` (pos, normal), Veilstep `DiveHitbox` (pos, normal) | Vector3s | — |
| 13 | Aim streams (per frame) | Mokou4 `Startup` (target Model or Vector3), CursedBuds `Appear`, RootRampage `Roots` (camera LookVector), UltraCannon `Start`, MeiMei `CrowUltimate`, SwiftKick `UpdateCamera` (3×f16 buffer), RikaThrow `TrackCamera`, DroneStrike `Aim` (move vector), Rika `Remote` (MoveDirection) | aim/steer | low risk |
| 14 | Choices / inputs | Hiromi `Opening` choice 1–3, Copy wheel `FireServer(techniqueName)`, BodyDisfigure mash (`UnreliableRemoteEvent`), Roulette Kit `FireServer(vowIndex)` | discrete | server should validate options |
| 15 | **Achievements** | `SettingsController`, `RouletteController` | `AchievementService.Give:Fire("Space Shenanigans")`, `("Betavision", true)`, `("Poor Performance")` — client decides it earned them | exploitable if trusted |
| 16 | Crow spectator position | `RouletteController` | `CrowUpd:FireServer(cframe)` every Heartbeat | cosmetic |
| 18 | **Own HRP CFrame stream** | `JoinController` → `AntiCheatService.Camera` every Stepped | 15-byte buffer (pos×100 as 24-bit, euler×1000 as i16) + camera pos; rebroadcast verbatim to other clients | server validation invisible — position is client-reported |
| 19 | **Skill activation payloads** | `ToolController` | `Activated(moveValue, extra)` — `extra` = client-computed airborne bool (code 1), target Model (2), aim Vector3 (3), move vector (4), tuples (5/6); M1 `dir` "Up"/"Down"; Deactivated carries `<X>Controller.ToolDeactivate()` result (e.g. PianoDrop mouse target) | aerial/aim variants spoofable |
| 20 | **No client cooldown/state gate** | `ToolController` | any move value with a `Service` attr can be fired at any time; M1 40 Hz; custom `USE` 2 Hz | server must own cooldown/stun |
| 21 | **WalkSpeed / JumpPower / Anchored** | `MovementController` | set locally every Stepped; `HRP.Anchored=false` forced | classic speed-hack surface |
| 22 | **Parkour** | `MovementController` | `MovementService.Parkour:Fire()` after local raycast decision + local BodyVelocity | fully trusted |
| 23 | **Dash** | `MovementController` | `MovementService.Dash:Fire(dir[, escape])` with 2 s / 0.45 s *local* cooldown; physics applied before any server ack; `ResetDash` S→C refunds | server CD unknown |
| 24 | **Knockback / grab realisation** | `HandicapController` | server BodyVelocity's `.Velocity` written each frame by victim client; `ClearForce` callable; Grab = client `PivotTo` | victim can nullify |
| 25 | **QTE mash** | `BeamController` (beam clash), `FinalJudgementController` | expected key chosen *locally at random*; `remote:FireServer(true)` on success, `()` on miss; mobile path can never miss | spammable |
| 26 | Achievement | `MovementController` | `AchievementService.Give:Fire("Committed to the peace")` after 300 s team emote | adds to #15 |
| 27 | Throwable pick | `ToolController` | `MovementService.Throwable:Fire(model)` — proximity checked client-side only | — |
| 28 | Client-set attributes the server may read (`Sprint`, `Movement`, `Info.InDash` also client-created) | `KamehamehaFinished`, `CloudEnabled`, `Disabled` (boosters), `Info.*` writes | — | unknown |

Not client-authoritative (server-gated, cannot be judged from client): all `DebugService`/Cmdr admin traffic, `EmoteService` equips, settings, rules acceptance.

### 3.3 Per-slice remotes tables

The per-slice tables (every remote seen, direction, decoded args) follow verbatim from the analysis passes.

#### 3.3.A — Movesets A (Charles, Choso, Custom, Gojo, Goku)

| Remote / Service.Method | Direction | Fired by (file) | Args decoded | Client-auth? |
|---|---|---|---|---|
| `<X>Service.Effects` (all 36 services: CharlesService, DespairService, EyeCatchService, SacrilegiousService, ShutUpService, BloodRainService, PlasmaWaveService, SlicingExorcismService, WingKingService, BloodEdgeService, PiercingBloodService, RedScaleService, SupernovaService, ChosoService, BoostOn2Service, ChaosService, GrappleService, Mokou1-4Service, MokouService, PuppetBarrageService, UltraCannon2Service, HollowPurpleService, LapseBlueMaxService, ReversalRedMaxService, LapseBlueService, RapidPunchesService, ReversalRedService, GojoService, KamehamehaService, KiSpamService, StaffExtendService, StaffUppercutService, GokuService) | S→C | every file | `(effectName: string, ...)` — see per-file key lists | n/a |
| `MokouService.Hitbox` | S→C | MokouController | `(inst, char, remote)` — starts client hit loop | — |
| `remote:FireServer(hits, hrpCFrame)` (from MokouService.Hitbox) | C→S | MokouController | `hits: {Model}|nil` from `SphereHitbox(char, CF(0,0,-4), 8)`, `hrpCFrame` | **YES** |
| `Mokou2Service.Hitbox` | S→C | Mokou2Controller | `(inst, char, remote)` | — |
| `remote:FireServer(hits, groundPos)` (from Mokou2Service.Hitbox) | C→S | Mokou2Controller | `hits: {Model}|false`, `groundPos: Vector3|nil` | **YES** (hits + landing) |
| `PuppetBarrageService.Hitbox` | S→C | PuppetBarrageController | `(inst, puppetChar, remote)` | — |
| `remote:FireServer(hits, hrpCFrame)` (from PuppetBarrageService.Hitbox) | C→S | PuppetBarrageController | `hits: {Model}|nil` (excludes Owner/User/Friend), `hrpCFrame` | **YES** |
| `GojoService.Hitbox` | S→C | GojoController | `(inst, char, remote)` | — |
| `remote:FireServer(hits, hrpCFrame)` (from GojoService.Hitbox) | C→S | GojoController | `hits: {Model}|nil` from `SphereHitbox(char, CF(0,-1,-3), 10)`, `hrpCFrame` | **YES** |
| `landRemote:FireServer(pos)` (BloodEdge `Dash` arg 3) | C→S | BloodEdgeController | `pos: Vector3` landing point after client ground raycast | Position-auth (no hits) |
| `aimRemote:FireServer(target)` (Mokou4 `Startup` arg 2) | C→S | Mokou4Controller | `target: Model` (lock-on via `ToolController:GetTarget(100)`) or `Vector3` (mouse raycast ≤300) every 0.02 s | Aim-auth (no hits) |
| `LapseBlueMaxService.Debree` | S→C | LapseBlueMaxController | `(partDataList: {{pos, orientation, color, material, size}}, attachment)` | — |

No `Service:Method()` RemoteFunction calls and no `ReplicatedStorage.Remotes.*` usage in this slice. Client-side self-movement (not remotes but trust-relevant): WingKing `Dash` (bodyMover.Velocity), RedScale `Launch` (hrp.Velocity), BoostOn2 `BoostEnabled` (BodyVelocity), Chaos `Melee` (hrp.CFrame lerp), Grapple `Jump` (bodyPos/hrp), Mokou3 `Pillar` (ctrlPart.Position by move vector), Gojo `CamFix` (hrp.CFrame = server cframe), Goku `Chase` (hrp orientation), Kamehameha/KiSpam `AutoRotate` (aimPart.CFrame), UltraCannon2/HollowPurple/LapseBlueMax/ReversalRedMax `Aerial` (BodyGyro + aimPart.Position).

#### 3.3.B — Movesets B (Hakari, Hanami, Haruta, Heian, Hiromi, Itadori)

| Remote / Service.Method | Direction | Fired by (file) | Args decoded | Client-auth? |
|---|---|---|---|---|
| `<X>Service.Effects` (RemoteSignal) — all 43 services | S→C | every controller | `(effectName, ...)` | — |
| `CursedStrikesService.Hitbox` (RemoteSignal) | S→C | CursedStrikesController | `(projectilePart, attackerChar, reportRemote)` | — |
| `reportRemote:FireServer(hits, rayPos)` (RemoteEvent passed via Hitbox) | C→S | CursedStrikesController | `hits` = `SphereHitbox(char, CFrame(0,-5,-5), 12)` result table; `rayPos` = Vector3 wall-hit or nil | **YES (hit report)** |
| `aimRemote:FireServer(pos)` (from `Appear`) | C→S, 50Hz | CursedBudsController | `pos` = locked target PrimaryPart.Position or `GetMouseTarget(300)` | Client-auth aim |
| `steerRemote:FireServer(lookVec)` (from `Roots`) | C→S, per frame | RootRampageController | camera `CFrame.LookVector` | Client-auth steering |
| `rootsRemote.OnClientEvent` | S→C | RootRampageController | `("PB", lookVec)` = camera pushback; `(cf, moveCam, rootId)` = spawn root segment | — |
| `surfRemote.OnClientEvent` | S→C | RootRampageController | `("Surf", cf)`, `("WoodenBall", ballPart, {chars})`, `("Spikes", ballPart, {{char, groundPos, dir, len}})`, `("DestroyWoodenBall", ballPart)` | — |
| `choiceRemote:FireServer(n)` (from `Opening`) | C→S | HiromiController | `n` = 1 Denial / 2 Silence / 3 Confess | Client-auth choice (game input) |
| `choiceRemote.OnClientEvent` | S→C | HiromiController | `(dialogCategory, chosen, correct, failIdx, hp, speakerChar)` | — |

No `Knit Service:Method()` RemoteFunction calls in this slice; no `ReplicatedStorage.Remotes.*` usage.

#### 3.3.C — Movesets C (Kurourushi, Locust, Mahito, Mechamaru, Megumi, MeiMei)

| Remote / Service.Method | Direction | Fired by (file) | Args decoded | Client-auth? |
|---|---|---|---|---|
| `KurourushiService.Effects` | S→C | KurourushiController | (effectName, ...) see keys above | – |
| `KurourushiService.Hitbox` | S→C | KurourushiController | (startObj w/ NumberValue, char, remoteEvent) | – |
| `<remoteEvent from Hitbox>:FireServer` | C→S | KurourushiController | (hitsTable or nil, HRP.CFrame) | **YES** |
| `ChokeholdService.Effects` / `DetachService.Effects` / `FesteringStrikesService.Effects` / `RoachSwarmService.Effects` | S→C | respective controllers | (name, ...) | – |
| `LocustService.Effects`, `BlackMucusService.Effects`, `CleverService.Effects`, `CrushJawService.Effects`, `WingThrowService.Effects` | S→C | Locust controllers | (name, ...) | – |
| `MahitoService.Effects` | S→C | MahitoController | (name, ...) | – |
| `MahitoService.Hitbox` | S→C | MahitoController | (startObj, char, remoteEvent, continuousBool) | – |
| `<remoteEvent from Hitbox>:FireServer` | C→S | MahitoController | (hitsTable, HRP.CFrame) — repeated every 0.05s in continuous mode | **YES** |
| `BodyDisfigureService.Effects` | S→C | BodyDisfigureController | (name, ...) | – |
| `<gui>.UnreliableRemoteEvent:FireServer()` | C→S | BodyDisfigureController (`Grab`) | no args; one per Jump press (mash escape) | input only |
| `BodyRepelService/CrushingRushdownService/FaceBlitzService/FocusStrikeService/HeadSplitterService/IdleTransfigurationService/SoulfireService/SpikeWrathService/StockpileService/WideSPStrikesService .Effects` | S→C | Mahito skill controllers | (name, ...) | – |
| `MechamaruService.Effects` | S→C | MechamaruController | (name, ...) | – |
| `AbsoluteDestructionService/BoostOnService/HeatEmissionService/PigeonViolaService/TechniqueChargeService/UltraSpinService .Effects` | S→C | Mechamaru controllers | (name, ...) | – |
| `MiracleCannonService.Effects` | S→C | MiracleCannonController | (name, ...) | – |
| `MiracleCannonService.Debree` | S→C | MiracleCannonController | (debrisTupleList `{pos,orient,color,material,size}`, containerInstance w/ attr `WorldPosition`) | – |
| `UltraCannonService.Effects` | S→C | UltraCannonController | (name, ...) | – |
| `<remote passed in UltraCannon Start>:FireServer` | C→S | UltraCannonController | (mouseTargetVector3 ≤75 studs) per frame | aim stream (client-chosen target point) |
| `MegumiService.Effects` | S→C | MegumiController | (name, ...) | – |
| `AdaptationService/DivineDogService/DivinePummelService/EarthquakeService/GreatSerpentService/GroundPitchService/MahoragaUseService/MaxElephantService/NueService/RabbitEscapeService/ShadowSwarmService/ToadService .Effects` | S→C | Megumi controllers | (name, ...) | – |
| `MaxElephantController:ToolDeactivate()` | (local API) | MaxElephantController | returns `GetMouseTarget(75)` — presumably relayed by ToolController to server | client-chosen placement |
| `MeiMeiService.Effects` | S→C | MeiMeiController | (name, ...) | – |
| `<remote passed in CrowUltimate>:FireServer` | C→S | MeiMeiController | (Vector3 camPos + camLook*100) per frame while crow `InControl` | aim stream |
| `BirdControlService/CirclingService/ImpetusUpdraftService .Effects` | S→C | MeiMei controllers | (name, ...) | – |
| `MurmurateService.Effects` | S→C | MurmurateController | (name, ...) | – |
| `<remote passed in Murmurate Flight>:FireServer` | C→S | MurmurateController | (landingPosition Vector3, surfaceNormal Vector3) once | **partial** — client decides where glide lands |

Client-side movement authority worth flagging (no remote, but client sets its own physics on server-created movers): Detach `Aerial` (proj position), Locust `Flight` (HRP CFrame + mover pos), WingThrow `Dash` (mover pos), IdleTransfiguration `Dash` (mover Velocity 200→50), GreatSerpent `Spawn` (aim part pos), BirdControl `Flight` (mover Velocity), Murmurate `Flight` (mover Velocity arc), ShadowSwarm `Dash` (clone Humanoid:Move), Nue/BodyDisfigure `Jump` (BodyPosition).

#### 3.3.D — Movesets D (Nanami, Naoya, Reggie, Ryu)

| Remote / Service.Method | Dir | Fired by | Args decoded | Client-auth? |
|---|---|---|---|---|
| `CleavingWhirlService.Effects` | S→C | CleavingWhirlController | (name, ...) | – |
| `CollapseService.Effects` | S→C | CollapseController | (name, ...) | – |
| **RemoteEvent passed in `Collapse.Leap` arg 3** | C→S | CollapseController | `FireServer(rayHitPosition: Vector3, rayNormal: Vector3, hrpPosition: Vector3)` — fired once when client raycast (`_G.MapParams`, 10 studs along velocity) hits, ≥0.3s after leap start | **Yes — client picks slam landing point** |
| `InterrogateService.Effects` | S→C | InterrogateController | (name, ...) | – |
| `NanamiService.Effects` | S→C | NanamiController | (name, ...); SpawnRatio passes Player, BillboardGui, BoolValue, duration, serverTime | – |
| `SeveranceKickService.Effects` | S→C | SeveranceKickController | | – |
| `SharpenService.Effects` | S→C | SharpenController | | – |
| `StabilizeService.Effects` | S→C | StabilizeController | | – |
| `FlashFreezingService.Effects` | S→C | FlashFreezingController | | – |
| `TendrilGrabService.Effects` | S→C | TendrilGrabController | | – |
| `TopSpeedService.Effects` | S→C | TopSpeedController | Fly passes BodyPosition part w/ `Speed` attr (client moves it) | – (client positions own BodyPosition target; server owns Speed) |
| `BleedoutService.Effects` | S→C | BleedoutController | | – |
| `CursoryImpactService.Effects` | S→C | CursoryImpactController | | – |
| `DecisiveStrikeService.Effects`, `DecisiveStrike2Service.Effects` | S→C | DecisiveStrikeController | both routed to one handler table | – |
| `ProjectionBreakerService.Effects` | S→C | ProjectionBreakerController | | – |
| `NaoyaService.Effects` | S→C | NaoyaController | | – |
| `ArsonService.Effects` | S→C | ArsonController | | – |
| `BigMovesService.Effects` | S→C | BigMovesController | | – |
| `BluntTraumaService.Effects` | S→C | BluntTraumaController | Align passes BodyPosition (client positions it) | – |
| `DroneStrikeService.Effects` | S→C | DroneStrikeController | Aim passes ValueBase (`Fired`,`Aim` attrs) + RemoteEvent | – |
| **RemoteEvent passed in `DroneStrike.Aim` arg 3** | C→S | DroneStrikeController | `FireServer(moveVector: Vector3)` every frame from `ControlModule:GetMoveVector()` | No (input only) |
| `FlecheService.Effects` | S→C | FlecheController | | – |
| `GarageSaleService.Effects` | S→C | GarageSaleController | | – |
| `GushingWoundService.Effects` | S→C | GushingWoundController | | – |
| `HomerunService.Effects` | S→C | HomerunController | | – |
| `MayhemService.Effects` | S→C | MayhemController | | – |
| `PianoDropService.Effects` | S→C | PianoDropController | Hitbox passes BoolValue | – |
| `PianoDropController.ToolDeactivate()` | (local API, likely consumed by ToolController → server) | PianoDropController | returns `GetMouseTarget(75)` Vector3 | Indirect: client-chosen target position |
| `PoleVaultService.Effects` | S→C | PoleVaultController | | – |
| `ReggieService.Effects` | S→C | ReggieController | | – |
| `SpeedCrashService.Effects` | S→C | SpeedCrashController | | – |
| `HadNoIdeaService.Effects` | S→C | HadNoIdeaController | | – |
| `WerentInvitedService.Effects` | S→C | WerentInvitedController | Crunch passes array of `{pos,orient,color,material,size,transparency}` | – |
| `WhatAreYouAfterService.Effects` | S→C | WhatAreYouAfterController | Aerial passes BodyPosition (`Aim` attr) | – |
| `AppetizerService.Effects` | S→C | AppetizerController | | – |
| `GraniteBlastService.Effects` | S→C | GraniteBlastController | Aerial passes BodyPosition; BodyGyro `Lock` attr | – |
| `SecondHelpingService.Effects` | S→C | SecondHelpingController | | – |
| `UnsatisfiedService.Effects` | S→C | UnsatisfiedController | | – |

No `Service:Method()` RemoteFunction/Signal calls (C→S) appear in any of these 35 files; input binding lives elsewhere (ToolController / input controllers, not in slice).

#### 3.3.E — Movesets E (Todo, Uro, Yuki, Yuta)

| Remote / Service.Method | Direction | Fired by (file) | Args decoded | Client-auth? |
|---|---|---|---|---|
| `<X>Service.Effects` (all 33 services: Brothers, ClimaxJump, Dreams, IdolDebut, BruteForce, PebbleThrow, SwiftKick, Todo, BlindRage, SkyDistortion, ThinIceBreaker, Uro, GarudaRebound, GarudaStab, MassBreaker, RisingRage, Yuki, Copy, ElbowRush, LoveBeam, Outburst, ResoluteSlash, Revolve, SeveringPath, Veilstep, RikaDownslam, RikaGrab, RikaHaymaker, RikaLaunch, RikaLoveBeam, RikaSlam, RikaThrow, Yuta) | S→C | each controller | `(effectName, ...)` — see Effects keys per file | — |
| `UroService.Hitbox` | S→C then C→S | UroController | in: `(timerPart, char, remoteEvent)`; out: `remoteEvent:FireServer(hitsTable|nil, hrpCFrame)` after client SphereHitbox r=10 @ (0,-1,-3) | **YES** |
| `RevolveService.Hitbox` | S→C then C→S | RevolveController | in: `(projectilePart, char, remoteEvent)`; out: `remoteEvent:FireServer(hitsTable|false, groundHitPos|nil)` (SphereHitbox r=8 @ (0,-5,-5) + forward ray) | **YES** |
| `YukiService.Debree` | S→C | YukiController | `(rockDataArray, centerPos)` cosmetic debris | — |
| Veilstep `DiveHitbox` remote (passed in Effects) | C→S | VeilstepController | `FireServer(hitPosition, hitNormal)` — ground impact from Right Arm raycast, local char only | Partial (position, not targets) |
| SwiftKick `UpdateCamera` remote (passed in Effects) | C→S | SwiftKickController | `FireServer(buffer6)` = camera LookVector as 3×float16, every Heartbeat | No (aim stream) |
| RikaThrow `TrackCamera` remote (passed in Effects) | C→S | RikaThrowController | `FireServer(cameraLookVector)` every frame until remote attr `Disabled` | No (aim stream) |
| Copy `PromptWheel` select remote (passed in Effects; also `remote.OnClientEvent("Swap")`) | C→S (+S→C) | CopyController | `FireServer(techniqueName)`; server may send `"Swap"` to flip page | No |
| `CopyController:SelectWheel(slot)` | intra-client API | CopyController | keyboard slot → fires select remote with that button's `Name` attr | — |
| `MokouController:ArcTween(startPart, bool)` | intra-client API | ThinIceBreaker, UroController | reused debris arc tween | — |

Client-side authoritative *movement* (not remotes, but server-trusting): SwiftKick Dash BodyVelocity, Todo Swap HRP.CFrame teleport, IdolDebut Jump lerping other players' HRPs, BlindRage Fly target-part steering, Uro Flight / Yuki OhNo camera-direction velocity, Yuki BlackHole pull.

#### 3.3.F — Join menus / settings / anti-cheat slice

| Remote / Service.Method | Direction | Fired by (file) | Args decoded | Client-auth? |
|---|---|---|---|---|
| `EmoteService.Equip` (RemoteSignal) | C→S | InventoryController | `(slot 1..16, emoteName)` | n (server presumably validates ownership) |
| `EmoteService.ChangeInv` | C→S / S→C | InventoryController | C→S `(titleName)`; S→C `(list, kind 1/2/3/other)` | n |
| `EmoteService.ChangeMVP` | C→S | InventoryController | `(mvpEmoteName)` | n |
| `EmoteService.ChangeSkin` | C→S / S→C | InventoryController | C→S `(category[, skinName])`; S→C `(previewModel or nil)` | n |
| `NepService.Effects` | S→C | NepController | `(effectName, model, ...)` keys ToggleRadio/RadioBeep/RadioSignal/RadioBounce/RadioTalk/UngezieferRage | — |
| `JoinService.AcceptRules` | C→S | RulesController | `()` | n |
| `JoinService.Setting` | C→S / S→C | SettingsController | C→S `(valKey, value)`; S→C `("Batch", zstdJSONBuffer)` or `("Single", key, value)` | n |
| `AchievementService.Give` | C→S (and S→C echo) | SettingsController | `("Space Shenanigans")`, `("Betavision", true)` | **YES — client decides it earned an achievement** |
| `ReplicatedStorage.Remotes.ForceFun` (RemoteEvent) | S→C | SettingsController | `(localSettingName)` → force-enable a "fun" local setting | — |
| Player attribute `HidePlayer` | local only | KnitRunClient | set on UserIds 1241352401 / 31070091 / 174332536 | — |
| AntiCheatController remotes | ? | AntiCheatController | **unrecoverable (obfuscated)** | ? |
| CameraController remotes | ? | CameraController | **unrecoverable (obfuscated)** | ? |

#### 3.3.G — Core controllers, workspace, utils

| Remote / Service.Method | Direction | Fired by (file) | Args decoded | Client-auth? |
|---|---|---|---|---|
| `HitboxService.Hitbox` (RemoteSignal) | S→C | HitboxController | `(attackerChar, hrpOffsetCFrame, diameter, perAttackRemoteEvent, lifetimeObj?)` | — |
| per-attack `RemoteEvent:FireServer` | C→S | HitboxController | `({hitCharModel, ...})` every 0.025s while hits | **YES — hit list** |
| `ReplicatedStorage.Remotes.GetClient` | S→C then C→S | HitboxController | S: `(replyRemote)`; C: `replyRemote:FireServer(cameraCFrame)` | **YES — aim/camera** |
| `DebugService.Debug` | both | DebugController | C→S `(cmd, target?)` cmds: Respawn2, Destroy, OP, FF, TI, Item, Dummy1–9, Gravity, WalkSpeed, JumpPower, ServerName, ServerIcon, Fidelity, Tick, Damage, Knockback, Lock, Voice, RC, CC1–3, GlobalName, MaxDmg, VK, VKB, KF (server flags); Flight, Build, PSPerms, CD, Ult, Stun, Respawn, DeathKick, Skill, SkillM1, SkillUlt, Parkour, Burst, ApplyNew, Workshop (per-player); Kick, Ban, Heal, ResetCD, Kill, Bring, Go, Respawn3 (actions). S→C `(name, value)` / `("Banned", {[userId]={Name,DisplayName}})` | Admin-gated (server) |
| `DebugService.Unban` | C→S | DebugController | `(userId)` | admin |
| `DebugService.Update` | both | DebugController | C→S `()` request; S→C `(flagsTable)` | — |
| `ReplicatedStorage.Remotes.Request` | S→C / C→S | DebugController | S: `(requesterPlayer, text)` build-mode request notification; C: `FireServer(requesterPlayer)` = Allow | — |
| `BuildService` | — | DebugController | fetched, unused | — |
| `DomainService.Effects` | S→C | DomainController | `(key, ...)` keys Clash/Hit/Swing/Swing2/Launch/ClashHighlight | — |
| `DomainService.CFix` | S→C | FXController | `(offsetVector3)` | — |
| `DebreeService.Sound/Create/Physics/Prop/Domain` | S→C | FXController | see FX section (binary buffers) | — |
| `ReplicatedStorage.Remotes.Message` | S→C | FXController | `(systemMessageText, playClickSound?)` | — |
| `ItemService.Effects` | S→C | ItemController | `(key, ...)` see Item table | — |
| `FinalShowdownService.Effects` | S→C | FinalShowdownController | `PipeShoot()`, `Transition(text)` | — |
| `NightParadeService.Effects` | S→C | NightParadeController | `PickVows()` | — |
| `RouletteService.Effects` | S→C | RouletteController | see Roulette section | — |
| `RouletteService.Spectate` | C→S | RouletteController | `()` toggle spectate / `(afkBool)` | — |
| `AchievementService.Give` | C→S | RouletteController | `("Poor Performance")` | **YES — client-requested achievement** |
| Kit `RemoteEvent` (passed in `Kit` effect) | C→S | RouletteController | `FireServer(vowIndex)` | — |
| `CrowUpd` (RemoteEvent in crow model) | C→S / S→C | RouletteController / Utils.Misc.Crow.Caw | C: `FireServer(crowCFrame)` per Heartbeat; S: `()` caw sound | **YES — crow position** |
| `Modules.Discord.RemoteEvents["UpdateActivity"]` | C→S | DiscordClient | `(activityTable)` | — |
| `Utils.Yuta.Rika.Client.Remote` | C→S | Rika Client | `(MoveDirection)` owner only | minor (movement intent) |
| `Utils.Yuta.Rika.Client` `Effects` RemoteEvent | S→C | Rika Client | `(key, ...)` UltimateStart/Break/StartScream/Teleport | — |
| `Ads.MoneyDestroyer5000.RemoteEvent` | C→S | PianoSystem (BillboardEditUI) | `(billboardModel, text \| "Report")` | — |
| `StationControl.Handle.Mic_Air` | C→S / S→C | StationControl Handle | C: `()`; S: `(1\|2\|other)` | — |
| `StationControl.Handle.Train` | C→S / S→C | StationControl Handle, DebugController | C: `()`; S: `()` | — |

---

#### 3.3.H — ReplicatedStorage.Modules

| Remote / Service.Method | Dir | Fired by | Args | Client-auth? |
|---|---|---|---|---|
| `ReplicatedStorage.Remotes.TTS` (RemoteFunction) | C→S invoke | Settings/Audio/TTS/TextToZee | `(text, accent)` → returns `{ {syllable, pitchMult}, ... }` per word | n/a (text) |
| `JoinService.MobileLayout` (Knit RemoteSignal) | C→S | Settings/Controls/Keybinds | `(bindings{Action={K={key,mod?},G={btn,mod?}}}, true)` | n/a (prefs) |
| `JoinService.Setting` (Knit RemoteSignal) | C→S | Settings/General/Awakening Outfit | `("Outfit", outfitId|nil)` | n/a (prefs; server should check gamepass 857428668) |
| Discord/RemoteEvents `getOrCreate/waitFor/tryGet` | helper | – | any name under `ReplicatedStorage.Remotes` | – |

#### 3.3.I — Cmdr / Knit / libraries

| Remote / method | Instance path | Direction | Fired by | Args | Client-auth? |
|---|---|---|---|---|---|
| `CmdrFunction` (RemoteFunction) | `ReplicatedStorage.CmdrClient.CmdrFunction` | C→S | `CmdrClient/Shared/Dispatcher.Send` (every command executed from the console, incl. `watch` after client-side hooks) | `InvokeServer(commandText: string, {Data = any})`; server returns result string; server caps text at 500,000 chars, runs `Dispatcher:EvaluateAndRun(text, player, options)` which re-runs BeforeRun permission hook server-side | No (server validates permission via `Permissions.lua` hook + Cmdr arg validation); actual command effects depend on server impls not in dump |
| `CmdrEvent` (RemoteEvent) | `ReplicatedStorage.CmdrClient.CmdrEvent` | S→C | server `Command:SendEvent(player, name, ...)` → client `CmdrClient.Events[name](...)` | `"Message"(text)` → system chat "[Announcement] text"; `"AddLine"(...)` → console line | n/a |
| Knit `Services` folder | `ReplicatedStorage.Knit.Services.<ServiceName>` (RF/RE/RP folders created by sleitnick comm@1.0.1 ServerComm) | both | `KnitClient.GetService` builds `ClientComm` objects (ServicePromises=true) | per-service; enumerated in controller slices | per service |
| TopbarPlus `MarketplaceService:GetProductInfo(117501901079852)` | – | client→Roblox API | `Icon/VERSION.getLatestVersion` (only if update-check attribute enabled) | version check | n/a |

No `FireServer` calls exist anywhere in this slice; no client-authoritative hit reports here.

#### 3.3.J — Supplement: ToolController / Beam / Emote / Join

| Remote / Service.Method | Dir | File | Args decoded | Client-auth? |
|---|---|---|---|---|
| `<Moveset>Service.Activated` | C→S | ToolController | M1: `(dir "Up"/"Down"/nil, targetChar)`; skill: `(moveNumberValue, extra per §2.4)` | move choice, aim, airborne, target are client values |
| `<Moveset>Service.Deactivated` | C→S | ToolController | `(moveNumberValue, ToolDeactivate(char) result or extra)` | yes (controller-computed payload) |
| `<Moveset>Service.RightActivated` / `RightDeactivated` | C→S | ToolController | `(target)` / `(aimVec3, target)` Naoya,Hanami / `(moveVector)` MeiMei / `(modelOrThrowable)` Todo; release no args | aim/target client |
| `<Moveset>Service.Ultimate` / `Deultimate` | C→S | ToolController | none | — |
| `ItadoriService.UltimateEnchain` | C→S | ToolController | none (when char attr `Enchain`) | — |
| `CustomService.Awaken` / `Melee` / `Special` | C→S | ToolController | `({isAir, target, moveVec, jumping})` | yes |
| `DomainService.Activated` | C→S | ToolController | `(dir)` during `Info.DomainClash` | — |
| `BlockService.Activated` / `Deactivated` | C→S | ToolController | `(target)` / none | target |
| `ItemService.M1` / `M2` / `Drop` | C→S | ToolController | `(dir, target)` / none / none | — |
| `MovementService.Throwable` | C→S | ToolController | `(throwableModel)` | client picks model (proximity checked client-side only) |
| `EmoteService.EmoteEnd` | C→S | ToolController, EmoteController | none | — |
| `EmoteService.Emote` | C→S | EmoteController | `(slot:number)` or `(name:string)` | — |
| `EmoteService.Equip` | S→C | EmoteController | `(slot, name, animId, tip)` | — |
| `EmoteService.Effects` | S→C | EmoteController | `(name, ...)` → `script.Effects` module | — |
| `JoinService.MobileLayout` | C→S / S→C | ToolController | `({Block/Dash/Melee/Special/Lock = {X,Y,S}})`; S→C same or legacy 8-num array | — |
| `JoinService.Change` | C→S | JoinController | `(movesetKey string)` | — |
| `JoinService.Talk` | C→S / S→C | JoinController | C→S `(voiceAssetId)`; S→C `(char, voiceAssetId)` | — |
| `JoinService.Reset` | C→S / S→C | JoinController | C→S none (reset button); S→C `(title, text)` notification | — |
| `Remotes.UpdateLog` (RemoteEvent) | C→S / S→C | JoinController | C→S `()` or `(clientVer)`; S→C `(serverVer)` | — |
| `AntiCheatService.Camera` | C→S / S→C | JoinController | C→S `(camPosBuf9, hrpCFrameBuf15, char, NaN)` every Stepped; S→C `({[playerName] = hrpBuf15 | bool})` | **client reports own HRP CFrame** |
| `AntiCheatService.Teleport` | S→C / C→S | JoinController | S→C `(char, cfBuf15, token)`; C→S `(token)` ack | — |
| `BeamService.Effects` | S→C | BeamController | `("ClashQTE", qteRemote, beamA, beamB)` | — |
| `qteRemote` (RemoteEvent passed in) | C→S | BeamController | `(true)` = correct press / mobile tap; `()` = wrong key | **yes** (expected key chosen client-side) |
| `_G.Crow` (RemoteEvent in `workspace.Effects.Crows`) | C→S | ToolController | `(true)` on M1 while controlling crow | — |
| `CopyController:SelectWheel(N)` | local | ToolController | slot number | — |

#### 3.3.K — Supplement: Movement / Handicap / Final Judgement / Elbow Drop

| Remote / Service.Method | Dir | Fired by | Args decoded | Client-auth? |
|---|---|---|---|---|
| MovementService.Dash (RemoteSignal) | C→S | MovementController | `(dir "Front"/"Back"/"Left"/"Right"[, isEscape=true])` | Client picks dir & timing; local CD only |
| MovementService.Parkour (RemoteSignal) | C→S | MovementController | `()` | **Yes** — client decides parkour occurred; physics applied locally |
| ItemService.Dash | C→S | MovementController | `()` | item dash request |
| ToolController:UseSetService("Chase", inAir) | C→S (via set service) | MovementController | `("Chase", bool FloorMaterial==Air)` | request |
| CustomService.Chase | C→S | MovementController | `(ToolController.ExtraData.Custom())` | custom-char chase |
| AchievementService.Give | C→S | MovementController | `("Committed to the peace")` | **Yes** — client-triggered achievement |
| MovementService.Effects | S→C | MovementController | `(playerOrN, name, char, extra)` | – |
| MovementService.Throwable | S→C | MovementController | `(throwableModel, char, cframe)` | – |
| MovementService.ResetDash | S→C | MovementController | `()` | – |
| HandicapService.Effects | S→C | HandicapController | `(a, name, char/part, b, c)` see §3 | – (client realizes forces) |
| HandicapService.Hit | S→C | HandicapController | `(char)` | – |
| BlockService.Effects | S→C | HandicapController | `(char, perfectBool)` | – |
| CustomService.SFX / SFX2 / FX / FX2 / PARTICLE / PARTICLE2 / LOOK | S→C | HandicapController | see §3 | – |
| FinalJudgementService.Effects | S→C | FinalJudgementController | `(name, ...)` | – |
| QTE RemoteEvent (instance passed in `Effects("QTE", remote)`) | C→S | FinalJudgementController | `FireServer(true)` = success, `FireServer()` = miss | **Yes** — spammable; mobile always success |
| ElbowDropService.Effects | S→C | ElbowDropController | `(name, ...)` | – |

---

### 3.4 State markers, attributes and Info values (consolidated, whole dump)

The game marks state with **Roblox attributes** (on Player, Character, `char.Info`, skill parts, workspace) and with an `Info` folder inside each character (children named after states, e.g. `Info.InSkill`, plus attributes). `ListData.States` (§4.5) is the canonical list the server's state machine and the custom-move `STATE` node use. Numbers in parentheses = occurrences in the dump.

| Scope | Attribute / value | Meaning (evidence) |
|---|---|---|
| Player | `Ultimate` (0–100) | Awakening/ult meter; read by Charles trail, Blood Rain intensity, Reveal billboard `Ult.Fill = v/100` |
| Player | `MVP`, `Title` | Equipped MVP cinematic name (default "King of Curses") and title |
| Player | `Spectate` | Local spectate flag in Final Showdown |
| Player | `PS_Perms`, `Workshop`, `BuildTag`, `Youtuber`, `AllowCustomMoveset` | Creator/private-server perms; workshop/build mode; Cmdr role attrs |
| Player | `LastRulesAccepted`, `Adjusting_Keybinds`, `HidePlayer` | Rules version accepted; keybind UI open; client-side dev hide-list |
| Player | `player.Gamepasses:GetAttribute(<name>)` | Owned gamepasses as boolean attrs on a `Gamepasses` folder |
| Player | `leaderstats:GetAttribute("HiddenKills")` | Server-set; client hides Kills |
| Character | `Moveset` (17) | Current character name (`"Gojo"`, `"Heian"`, `"Mechamaru"`…); gates voice lines/variants, `UltNames` lookup |
| Character | `Dead` (9), `InUlt` (12), `Bleeding`, `MeiBleeding`, `Evade` (0–50 evasive meter), `Ragdoll` (number, ≤0 = none), `Stun`, `Emote`, `UltDrain`, `Pitch`, `Charge`/`Charging`/`Max`/`Cost` (Yuki), `CloudEnabled` (Goku), `KamehamehaFinished`, `A1`/`A2` (Mahoraga adaptation: 1.1/1.3/1.5/1.7 → −10/−30/−50/−70 % dmg), `Collective`, `Rebound`, `Freeze`, `InControl` (MeiMei crow), `VisualHealth`, `DecreaseHP` | Combat state markers read by VFX |
| `char.Info` attributes | `CD`, `NoStun`, `NoRes`, `DeathKick`, `Skill`, `M1`, `Ult`, `Parkour`, `Burst` (DebugController per-player flags), `NaoyaFrame` | Admin overrides / per-char flags |
| `char.Info` children | `InSkill`, `Knockback` (BoolValue, false = un-knockbackable → hitbox skips), `BoostOnHold`, `Stun`, `DomainTag` (member of a domain), `Transparent`, `SnapPosition`, `FrameNPC` | Presence-as-state pattern (`FindFirstChild`) |
| `char.Moveset` folder | NumberValue per move with attrs `Key` (slot key label), `LastUse`, `ReadyAt` (server time), `Cooldown`, `LastUsed` | **Cooldowns are server-set attributes**; Reveal/MoveReveal billboards render them — the only cooldown evidence on the client |
| Character children | `SetAssets.*` (weapons: GWarstaff, Gavel, GokuStick), `BoosterR/L`, `Outfit`, `Nep`, `StyleAura`, `NimbusCloud`, `HumanoidRootPart.FlightForce`, `HRP.StyleMusic` | Equipment/aura markers |
| Skill instances (server-created) | `Speed` (26; projectile stud/s for client `Interp`), `BeamStartCFrame`/`BeamLength`, `TargetWidth`/`MaxWidth`/`Width`, `Aim`, `FinalPos`, `Track`, `Grab`, `Purple`, `End`, `Disabled`, `Timer`, `Type`, `Offset`, `Order`, `Jackpot`, `Health`, `Fade`, `Color`, `Roulette`, `GoHam`, `Mode`, `Fired`, `Dropped`, `Finisher`, `Ending`, `STOP`, `CurrentTiming`, `Lock`, `OGTP`, `P1`/`P2`, `V2`, `Velocity` | Parameters the server attaches to effect parts so the client can extrapolate/animate |
| Workspace | `Timer`, `Loading`, `Roulette`, `ServerRegion`; `Lighting.Config.{ClockTime,Ambient,OutdoorAmbient,FogColor,FogEnd,Brightness,EnvironmentDiffuseScale,ColorShift_Top/Bottom}` | Round state / lighting restore points |
| Domains (`workspace.Domains.*`) | `Health`, `Fade`, `Timer`, `Color`; `ClashFolder` children `Type` ∈ {MS, IV, DS, JP, ML, SP, TCMP, SOB}, `Offset` | Domain HP and clash cinematics |
| VFX templates | `EmitCount` (101), `EmitDelay`, `EmitDuration`, `RepeatCount/Delay`, `StartTransparency/EndTransparency`, `Duration`, `Part_/Mesh_/Decal_TweenParams`, `Welded`, `Raycast`, `RaycastHitOffset`, `Distortion`, `Parent`, `Time`, `Lifetime`, `KeepVFX`, `MaxSpeed`, `EmtiCount` [sic] | Data-driven emitters (EffectUtils / SraikoVFX / FXController.PlayParticles) |
| Blood pools | `CF`, `RT`, `Ref` ObjectValue | BloodyZee PoolActor |
| CollectionService tags | `KJUI` (TekrinnDialogue GUIs) | only tag in dump |
| Teams | `Lobby` | Not in round |
| CollisionGroups | `Effects` | Debris |

`ListData.States` (selectable in the custom-move STATE node, default `Stun`): Cancel, Stun, IFrame, NoM1, NoSprint, NoJump, NoDash, NoBlock, NoParkour, NoMass, NoDeath, DisableChase, Block, DirectionLock, SpeedMultiplier, JumpMultiplier, DamageMultiplier, HealthMultiplier, KnockbackMultiplier, Scale, InSkill, CameraMaxZoomDistance, Wakeup, Ragdoll, Character, Projection, Bleed, LastHit. Which server attribute/Info child each maps to is **n/a (server)**; the client only ever reads `Stun`, `Ragdoll`, `InSkill`, `Block`-adjacent visuals.

---

### 3.5 ListData.States gating notes (from SkillDefault node descriptions)

`ListData.States` (28) — these are the values selectable in the SkillDefault **STATE** node (default "Stun"; "VALUE used for SpeedMultiplier, JumpMultiplier, and Scale"; STATE TAG + "Cancel" cancels a tagged state). Gating below is from the node descriptions + names; server enforcement not in dump.

| State | What it gates (evidence) |
|---|---|
| Cancel | Pseudo-state: cancels a tagged STATE (STATE node desc) / HITBOX "CANCEL ENEMY" cancels target's current action |
| Stun | Cannot act; Headcam reads char attribute `Stun`; HITBOX "STUN" seconds; "-1 = no stun but mark LAST HIT" |
| IFrame | Invulnerability (Burst grants "invincibility frames" per tutorial) |
| NoM1 / NoSprint / NoJump / NoDash / NoBlock / NoParkour | Disable the respective input |
| NoMass | Blocks mass/"Mass Buildup"? (Yuki special) — likely disables weight/heavy attribute (?) |
| NoDeath | Cannot die (cf. HITBOX "CAN KILL" false) |
| DisableChase | Disables chase-hit (Melee.Chase anims) |
| Block | Currently blocking (HITBOX BLOCKABLE / 360 BLOCK) |
| DirectionLock | Locks facing |
| SpeedMultiplier / JumpMultiplier / DamageMultiplier / HealthMultiplier / KnockbackMultiplier / Scale | Numeric states (VALUE field) |
| InSkill | Busy in a skill |
| CameraMaxZoomDistance | Numeric camera cap |
| Wakeup | Post-ragdoll wakeup stun immunity (HITBOX "IGNORE WAKEUP: ignore the wakeup stun immunity, disable for accurate M1s") |
| Ragdoll | Ragdolled; Headcam reads char attribute `Ragdoll` (number, `<= 0` = not ragdolled); VELO node "RAGDOLL seconds", "TRUE RAGDOLL disables ragdoll cancel" |
| Character | (?) probably current character-id state |
| Projection | Naoya Projection Sorcery 24fps state |
| Bleed | Naoya Bleedout DoT |
| LastHit | Last hit target marker used by every "LAST HIT" node param |

Attributes / values seen in this slice: character attrs `Ragdoll`, `Stun`, `Emote`, `Pitch` (TTS); player attr `Adjusting_Keybinds`; `leaderstats` attr `HiddenKills`; `workspace` attr `ServerRegion`; `Lighting.Config` attrs `ClockTime, Ambient, OutdoorAmbient, FogColor, FogEnd, Brightness, EnvironmentDiffuseScale, ColorShift_Top, ColorShift_Bottom`; VFX attrs listed in the A.8 catalogue; StyleAura model attr `Color`; blood pool attrs `CF`, `RT`; InputBinding attr `D`; KJDialogue gui attr `Created`. CollectionService tag: `KJUI`. `_G` refs: `_G.Settings.*` (Gore, Outfit, DesPHY …), `_G.LocalSettings.*` (Goodnight, Sunset, Darkness, Jolly), `_G.SettingUpdate.<name>:Fire()`, `_G.MVP_PLAYING`, `_G.TutorialIcon`.

---

## 4. Game data (ReplicatedStorage.Modules.ListData / UltNames) — full transcription

### 4.1 Items (21)
Coin, Gun, TNT, Jet Black, Soda, Banana Peel, Tinted Glasses, Hazenoki's Eye, Voice Recorder, Transfigured Human, Transfigured Flesh, Playful Cloud, Sniper, Broom, Flashlight, Snowball, Bowling Ball, Naginata, Crowbar, Tiantui Star's Blade, Tiansha Star's Blade.

### 4.2 MoveList (index = character index in `Characters`; header {display name, Color3}; then move names in order)

Slot-order evidence: `Characters[i]` ↔ `MoveList[i]` ↔ `AnimList[i]` share an index (25 entries each). Within each list, the pattern for the 8-move rosters is **1-4 = base kit, 5-8 = awakening kit** (e.g. Gojo: Lapse Blue / Reversal Red / Rapid Punches / Twofold Kick, then Lapse Blue MAX / Reversal Red MAX / Hollow Purple / Infinite Void; Itadori: Cursed Strikes…Manji Kick then Dismantle / Open / Rush / Malevolent Shrine). This matches the `SkillDefault.defaultProp.AWK/AWK2` flags and the `ULT` node condition. Characters with 4 moves have no awakening kit in this list (Locust, Yuki, Heian, Charles, Goku, MeiMei); Mahoraga has 6; several lists carry extra entries past 8 (variants, sub-moves, OLD versions) — those are referenced by name by the SKILL node "MOVE" dropdown, not necessarily bound to a slot. Rosters are not strict 4+4 for Perfection (12), Cursed Partners (18), Puppet Master (10), Head of the Hei (9), Defense Attorney (9), Lucky Coward (7), Register (10), Sky Assassin (3).

| # | Character | Header | Color RGB | Moves (in order) |
|---|---|---|---|---|
| 1 | Gojo | HONORED ONE | 170,255,255 | 1 Lapse Blue · 2 Reversal Red · 3 Rapid Punches · 4 Twofold Kick · 5 Lapse Blue MAX · 6 Reversal Red MAX · 7 Hollow Purple · 8 Infinite Void |
| 2 | Itadori | VESSEL | 255,155,155 | 1 Cursed Strikes · 2 Crushing Blow · 3 Divergent Fist · 4 Manji Kick · 5 Dismantle · 6 Open · 7 Rush · 8 Malevolent Shrine |
| 3 | Hakari | RESTLESS GAMBLER | 170,255,127 | 1 Reserve Balls · 2 Shutter Doors · 3 Rough Energy · 4 Fever Breaker · 5 Lucky Volley · 6 Lucky Rushdown · 7 Overwhelming Luck · 8 Energy Surge |
| 4 | Megumi | TEN SHADOWS | 120,120,120 | 1 Rabbit Escape · 2 Nue · 3 Toad · 4 Divine Dog: Totality · 5 Max Elephant · 6 Great Serpent · 7 Shadow Swarm · 8 Mahoraga |
| 5 | Mahoraga | MAHORAGA | 255,255,255 | 1 Divine Pummel · 2 Ground Pitch · 3 Earthquake · 4 Takedown · 5 Adaptation · 6 World Slash |
| 6 | Mahito | PERFECTION | 255,170,255 | 1 Stockpile · 2 Soul Fire · 3 Focus Strike · 4 Body Repel · 5 Idle Transfiguration · 6 Body Disfigure · 7 Spike Wrath · 8 Embodiment of Self Perfection · 9 Widespread Strikes · 10 Face Blitz · 11 Crushing Rushdown · 12 Head Splitter |
| 7 | Choso | BLOOD MANIPULATOR | 170,75,75 | 1 Piercing Blood · 2 Flowing Red Scale · 3 Supernova · 4 Blood Edge · 5 Slicing Exorcism · 6 Wing King · 7 Blood Rain · 8 Plasma Wave |
| 8 | Todo | SWITCHER | 170,255,255 | 1 Swift Kick · 2 Brute Force · 3 Pebble Throw · 4 Elbow Drop · 5 Idol's Debut · 6 Climax Jumping · 7 Dreams · 8 Brothers |
| 9 | Locust | LOCUST | 170,255,127 | 1 Crushing Jaws · 2 Clever · 3 Wing Throw · 4 Black Mucus |
| 10 | Hiromi | DEFENSE ATTORNEY | 115,99,77 | 1 Extended Swings · 2 Justice Served · 3 Judgement's Reach · 4 Pressing Charges · 5 Execution · 6 Final Judgement · 7 Verdict · 8 Triple Sentence · 9 Grapple |
| 11 | Yuki | STAR RAGE | 170,170,255 | 1 Garuda Rebound · 2 Rising Rage · 3 Mass Breaker · 4 Garuda Stab |
| 12 | Heian | HEIAN | 255,85,0 | 1 Strong Dismantle · 2 Open FURNACE · 3 Cleave Rush · 4 Kamutoke |
| 13 | Yuta | CURSED PARTNERS | 255,170,255 | 1 Severing Path · 2 Resolute Slash · 3 Veilstep · 4 Second Wind · 5 Outburst · 6 Revolve · 7 Rika Downslam · 8 Rika Launch · 9 Rika Slam · 10 Rika Haymaker · 11 Rika Grab · 12 Rika Throw · 13 Rika Smash · 14 True Love Beam · 15 Authentic Mutual Love · 16 Elbow Rush · 17 Copy · 18 Energy Ripple |
| 14 | Charles | ASPIRING MANGAKA | 255,235,235 | 1 Despair · 2 Shut Up! · 3 Eye Catching · 4 Sacrilege |
| 15 | Mechamaru | PUPPET MASTER | 225,10,75 | 1 Ultra Spin · 2 Boost On · 3 Ultra Cannon · 4 Heat Emission · 5 Miracle Cannon · 6 Pigeon Viola · 7 Absolute Destruction · 8 Technique Charge · 9 Boost On OLD · 10 Ultra Cannon OLD |
| 16 | Naoya | HEAD OF THE HEI | 128,126,255 | 1 Projection Breaker · 2 Bleedout · 3 Decisive Strike · 4 Cursory Impact · 5 Top Speed · 6 Flash Freezing · 7 Tendril Grab · 8 Time Cell Moon Palace · 9 Decisive Strike OLD |
| 17 | Nanami | SALARYMAN | 94,191,255 | 1 Cleaving Whirlwind · 2 Severance Kick · 3 Blunt Cut · 4 Stabilize · 5 Ratio Breaker · 6 Sharpen · 7 Interrogate · 8 Collapse |
| 18 | Goku | MONKEY KID | 255,21,52 | 1 Kamehameha · 2 Ki Spam · 3 Staff Extend · 4 Staff Uppercut |
| 19 | Haruta | LUCKY COWARD | 167,125,203 | 1 Ambush · 2 Backstab · 3 Trip · 4 Cheap Shot · 5 Ankle Cutter · 6 High Time · 7 Dirty Play |
| 20 | MeiMei | CROW CHARMER | 35,40,80 | 1 Impetus Updraft · 2 Circling · 3 Gliding Flight · 4 Bird Control |
| 21 | Hanami | DISASTER PLANTS | 172,203,163 | 1 Root Swarm · 2 Surging Thorns · 3 Bud Shot · 4 Defense Response · 5 Cursed Buds · 6 Shining Sea of Growing Branches · 7 Flower Field · 8 Root Rampage |
| 22 | Ryu | TRUE CANNON | 170,255,255 | 1 Granite Blast · 2 Unsatisfied · 3 Second Helping · 4 Appetizer · 5 "What are you after?" · 6 "I had no idea..." · 7 "This is what dessert is like!" · 8 "You weren't invited." |
| 23 | Kurourushi | BLACK DEATH | 101,35,44 | 1 Festering Strikes · 2 Detach · 3 Chokehold · 4 Roach Swarm |
| 24 | Reggie | REGISTER | 255,255,255 | 1 Gushing Wound · 2 Homerun · 3 Littering · 4 Coupon · 5 Piano Drop · 6 Garage Sale · 7 Blunt Trauma · 8 Fleche · 9 Drone Strike · 10 Pole Vault |
| 25 | Uro | SKY ASSASSIN | 255,165,165 | 1 Blind Rage · 2 Sky Distortion · 3 Thin Ice Breaker |

### 4.3 SpecialList (special/passive name → character index)
| Special | Char # | Character |
|---|---|---|
| Limitless | 1 | Gojo |
| Combat Instincts, Cleave | 2 | Itadori |
| Door Guard, Rhythm | 3 | Hakari |
| Lurking Shadow | 4 | Megumi |
| Adaptation Wheel | 5 | Mahoraga |
| Self Transfiguration | 6 | Mahito |
| Convergence | 7 | Choso |
| Boogie Woogie | 8 | Todo |
| Fluttering Pounce | 9 | Locust |
| No Escape, Domain Amplification | 10 | Hiromi |
| Mass Buildup | 11 | Yuki |
| Incantation | 12 | Heian |
| Rika | 13 | Yuta |
| Clairvoyance | 14 | Charles |
| Offload, Energy Output | 15 | Mechamaru |
| Projection Sorcery, Acceleration | 16 | Naoya |
| Ratio Point | 17 | Nanami |
| Instant Transmission | 18 | Goku |
| Helping Hand | 19 | Haruta |
| Flock | 20 | MeiMei |
| Flower Field | 21 | Hanami |
| Restyle | 22 | Ryu |
| Earthen Insect Trance | 23 | Kurourushi |
| Discard | 24 | Reggie |
(No special listed for 25 Uro.)

### 4.4 AttackTypes (5)
Melee, Bullet, Explosion, Swarm, Domain — used by SkillDefault HITBOX/PROJECTILE "ATTACK TYPE" and COUNTER "ATTACK TYPE2".

### 4.5 States (28) — see §3.5.4–3.5.

### 4.6 Characters (25, index order)
1 Gojo · 2 Itadori · 3 Hakari · 4 Megumi · 5 Mahoraga · 6 Mahito · 7 Choso · 8 Todo · 9 Locust · 10 Hiromi · 11 Yuki · 12 Heian · 13 Yuta · 14 Charles · 15 Mechamaru · 16 Naoya · 17 Nanami · 18 Goku · 19 Haruta · 20 MeiMei · 21 Hanami · 22 Ryu · 23 Kurourushi · 24 Reggie · 25 Uro.

### 4.7 Materials (45)
Plastic, SmoothPlastic, Neon, Wood, WoodPlanks, Marble, Slate, Concrete, CrackedLava, Basalt, Limestone, Granite, Pavement, Brick, Pebble, Cobblestone, Rock, Sandstone, CorrodedMetal, DiamondPlate, Foil, Metal, Grass, LeafyGrass, Sand, Fabric, Snow, Mud, Ground, Asphalt, Salt, Ice, Glacier, Glass, ForceField, Air, Water, Cardboard, Carpet, CeramicTiles, ClayRoofTiles, RoofShingles, Leather, Plaster, Rubber. (FXController iterates this for material-based hit VFX/SFX.)

### 4.8 UltNames (awakening name, primary color, secondary color, flag)
| Character | Name | Color A | Color B | Flag |
|---|---|---|---|---|
| Gojo | Six Eyes | 85,255,255 | 0,170,255 | true |
| Itadori | King of Curses | 255,0,0 | 0,170,255 | true |
| Hakari | Idle Death Gamble | 85,255,127 | 0,170,255 | true |
| Megumi | Insanity | 45,45,45 | 0,170,255 | true |
| Mahito | Essence of the Soul | 170,170,255 | 0,170,255 | true |
| Choso | Duty as a Brother | 130,0,0 | 0,0,0 | true |
| Todo | False Memories | 255,255,255 | 0,170,255 | true |
| Hiromi | Deadly Sentencing | 179,130,61 | 88,57,37 | true |
| Locust | Directed Poison | 85,170,0 | 85,170,0 | true |
| Yuki | Unrestricted Density | 0,0,0 | 0,0,0 | true |
| Yuta | True Love | 255,170,255 | 255,0,127 | true |
| Charles | Foresight | 255,255,255 | 85,0,0 | true |
| Mechamaru | Absolute | 225,10,75 | 85,85,85 | true |
| Naoya | Vengeance | 255,255,255 | 128,126,255 | true |
| Nanami | Overtime | 131,203,199 | 59,84,143 | true |
| Haruta | Jawbreaker | 167,125,203 | 112,85,143 | true |
| Hanami | Unwrap | 172,203,163 | 79,69,49 | true |
| MeiMei | Bird Strike | 35,40,80 | 62,51,106 | true |
| Ryu | Every Last Drop. | 170,255,255 | 255,170,255 | true |
| Kurourushi | Parthenogenesis | 101,35,44 | 40,14,18 | true |
| Reggie | Con Artistry | 255,255,255 | 150,150,150 | true |
| Uro | Temper | 170,255,255 | 255,85,127 | true |
| Mahoraga | Ritual | 255,255,255 | 0,170,255 | **false** |
| Heian | Incomplete Shrine | 85,0,0 | 0,170,255 | true |
| Goku | Monkey | 255,0,0 | 1,1,0 (yellow) | true |
| Mokou | Immortal Blaze | 255,170,0 | (1,.33,0) | true |
| Chara | SINCE WHEN WERE YOU THE ONE IN CONTROL? | 255,0,0 | (.33,0,0) | true |
The 4th bool is false only for Mahoraga (summon, no real awakening — probably "show awakening banner/domain UI?"). Mokou & Chara have no ListData entry → unreleased/event/admin characters.

### 4.9 AnimList (ReplicatedStorage.Animations.<Char>.…) — per character index
1 Gojo: HollowPurple, InfiniteVoid, LapseBlue, LapseBlueMaximum, RapidPunches, ReversalRed, ReversalRedMaximum, Teleport, TwofoldHit, TwofoldKick, Ultimate, ShortVoid, Melee.Melee1-4, Melee.Up, Melee.Down, Melee.Chase
2 Itadori: CursedStrike, CursedStrikeHit, CrushingBlow, Variants.DivergentFist1-4, ManjiKick, ManjiKickHit, Cleave, Dismantle, FlameArrow, Rush, RushHit, MalevolentShrine, SlaughterDemon, Ultimate, UltimateEnchain, Instincts, Melee.Melee1-4
3 Hakari: Counter, EnergySurge, FeverBreaker, IdleDeath, LuckyRushdown, LuckyVolley, OverLuck, ReserveBalls, Rhythm, RoughEnergy, ShutterDoors, Melee.Melee1-4, Melee.Up, Melee.Chase
4 Megumi: DivineDog, GreatSerpent, MahoragaSummon, MahoragaUse, MaxElephant, Nue, RabbitEscape, Shadow, ShadowSwarm, ShadowSwarm1, ShadowSwarm2, ShadowSwarmHit, ShadowSwarmRun, Ultimate, Melee.Melee1-4
5 Mahoraga (under Megumi.Mahoraga): Adaptation, DivinePummel, Earthquake, GroundPitch, Parry, Takedown, WorldSlash, Melee.Melee1-4, Melee.Up, Melee.Down
6 Mahito: BodyRepel, CrushingRushdown, CrushingRushdownHit, DrillSplit, FaceBlitz, FocusStrike, ForceGrab, HeadSplitter, HeadSplitterHit, HeartPiercer, IdleTransfig, SelfPerfection, Soulfire, SpikeWrath, Stockpile, Ultimate, Ultimate2, WideStrike, WideStrikeHit, Variants.ChaseClub, Variants.ChaseSword, Variants.ChaseArmor, Melee.Melee1-4, Melee.Up, Variants.MeleeClub.Melee1-4, Variants.MeleeClub.Down, Variants.MeleeSword.Melee1-4
7 Choso: BloodEdge, BloodEdgeVictim, BloodRain, Convergence, PiercingBlood, PlasmaWave, RedScale, RedScaleAir, RedScaleVictim, SlicingExorcism, Supernova, SupernovaCounter, Ultimate, WingKing, WingKingVictim, Melee.Melee1-4
8 Todo: Brothers, BruteForce, ClimaxJump, ClimaxJumpHit, Dreams, ElbowDrop, IdolDebut, PebbleThrow, PebbleThrowHit, SwiftKick, SwiftKickHit, Ultimate, UltimateSummon, TakadaJoint.JumpStart/JumpEnd/TakadaIdle/Emote, Clap.Clap1-3, Melee.Melee1-4
9 Locust: BlackMucus, BugFlight, Flight, FourArmed, SnapChomp, SnapChompHit, Ultimate, Melee.Melee1-4
10 Hiromi: DeadlySentence, Execution, ExecutionHit1-3, ExtendSwing, FinalJudgement, FinalJudgementHit, Grapple, JusticeServed, JusticeServedHit, TwirlingStrikes, Ultimate, Dodge.Dodge1-5, Verdict, TripleSentence, TripleSentenceHit, JudgeReach, JudgeReachHit, JudgeReachHit2, GavelThrow, Melee.Melee1-4, Melee2.Melee1-4, Melee2.Chase, JudgeReach2, PressingCharges
11 Yuki: GarudaRebound, GarudaStab, GarudaStabHit, MassBreaker, RisingStar, Ultimate, MeleeOld.Melee1-4, Melee.Melee1-4
12 Heian: Chant, Cleave, Dismantle, FlameArrow, Kamutoke, MalevolentShrine, WCS
13 Yuta: ResoluteSlash, Revolve, SeveringPath, Sheath, Veilstep, VeilstepDive, SeveringPathAir, RevolveReaction, YutaBeam, Launch, Ultimate, JacobLadder, JacobLadderTarget, ElbowBeatdown, ElbowBeatdownTarget, RunSlash, CursedSpeech, Melee.Melee1-4, Melee.Chase, Melee.Up, Melee.Down, SeveringSwing, Outburst, QuickdrawAerial, SecondWind, EnergyRipple, MeleeUlt.Melee1-4, Ultimate2, SeveringPathSwordAir, LaunchGround, LaunchGroundMelee, RunPierce
14 Charles: Despair, EyeCatch, ShutUp, ShutUpVictim, Sacrilegious, SacrilegiousHit, Ultimate, UltimateHit, UltimateAfter, Mark, Melee.Melee1-4, Melee.Up
15 Mechamaru: BoostOnStart, BoostOnEnd, BoostOnTarget, UltraSpin, UltraSpinHit, UltraCannon, PuppetBarrage.User/Grab/Kick, Offloads.FunnyFall/SmoothLanding1/SmoothLanding2/BackSlide/SupermanLanding/ArmsFlyIn, BoostOn, BoostOnHit, HeatEmission, MiracleCannon, PigeonViola, AbsoluteDestructionOLD, Absolute.GunShot/Kick/JumpCrouch/Stagger/Spawn/UltEnd, Melee.Melee1-4, Absolute.Melee.Melee1-4, Absolute.Melee.Up, AbsoluteDestruction, AbsoluteDestructionAir
16 Naoya: Bleedout, BleedoutHit, CursoryImpact, DecisiveStrike, DecisiveStrikeHit, Flicker, ProjectionBreaker, Ultimate, UltimateHit, TopSpeed, FlashFreezing, TendrilGrab, MoonPalace, Acceleration, Melee.Melee1-4, Melee2.Melee1-4
17 Nanami: CleavingWhirlwind, SeveranceKick, BluntCut, Stabilize, StabilizeTarget, StabilizeTargetShort, RatioBreaker.RatioBreak1-4, RatioBreakStun, Ultimate, Melee.Melee1-4, Melee.Up, Melee.Down, MeleeUlt.Melee1-4, Sharpen, Interrogate, InterrogateHit, InterrogateFinalHit, Collapse
18 Goku: Kamehameha, KiSpam, StaffExtend, StaffUppercut, Ultimate, Melee.Melee1-4
19 Haruta: Ambush, Stinger, Backstab, BackstabTargetBack, BackstabTargetFront, Trip, CheapShot, DirtyPlay, Hand.JawbreakerHit, Hand.JawbreakerVictim, Melee.Melee1-4, Melee.Melee4Victim, Melee.MeleeChase, Melee.SwordChase, Melee.Up, Melee.Down, Taunt1-4
20 MeiMei: BirdCall, BirdHold, Bounding, BoundingVictim, Circling, CirclingVictim, CirclingVictimFinisher, Flock, GlidingFlight, GlidingFlightVictim, ImpetusUpdraft, Melee.Melee1-4, Melee.Up, Melee.Down, Melee.Chase, ImpetusNew, Murmurate, Teleport, Ultimate
21 Hanami: BudShot, DefenseResponse, FlowerField, RootSwarm, SurgingThorns, Melee.Melee1-4, Melee.Chase, MeleeUlt.Melee1-4, Empower, Ultimate, Domain, CursedBuds, Beam
22 Ryu: Appetizer, GraniteBlast, HadNoIdea, HadNoIdeaHit, Recovery, Recovery2, SecondHelping, ThisDessert, ThisDessertHit, Ultimate, Unsatisfied, WhatAreYouAfter, WhatAreYouAfterHit, Melee.Chase, Melee.Melee3_2, WerentInvited, Recovery3
23 Kurourushi: FesteringStrikes, Detach, Reattach, ChokeholdHit, ChokeholdVictim, EarthenTrance, RoachSwarm, Melee.Melee1-4, MeleeDetach.Melee1-4, Parthenogenesis, Eat, EatVictim, Melee.Down
24 Reggie: GushingWound, Homerun, Littering, Coupon, PianoDrop, GarageSale, BluntTrauma, BluntTraumaHit, Discard, Melee.Melee1-4, Drone.DroneStrikeStart, PoleVault, Fleche, SpeedCrash, SpeedCrashHit
25 Uro: Melee.Melee1-4, BlindRage, BlindRageHit, ThinIceBreaker, ThinIceBreaker2, SkyDistortion, Ultimate, Melee.Chase

---

## 5. Per-character reference

Each block: character controller vs skill controllers, moveset table (slot = `Key` attribute on the server-created `char.Moveset` NumberValue, see §6.9; ListData order is only a hint, so the column stays `?` unless evidence exists; cooldown column shows only client-visible evidence), combat-controller config, skins/markers, animations, VFX modules, sounds, and explicit not-in-dump notes.

### Charles
- **Character controller**: `CharlesController` (M1 Hit/Swing/Swing2/Chase/ChaseHit/Launch, Ultimate counter, Mark, Future dash, Perfect dodge, Dead). Skill controllers: Despair, EyeCatch, Sacrilegious, ShutUp.
- Weapon: staff `SetAssets.GWarstaff`; M1 4-hit (count 4 = Right Leg kick); trail color scales with `Ultimate` attribute toward dark red.

| Slot/key | Move name | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? | Despair | n/a (server) | DespairService | Startup, Spin, Swing, Swing2, Barrage, Hit, Hit2, Die | Spin-swing combo into staff barrage (arm clones every 0.025 s) with kill finisher `Die` |
| ? | Eye Catch | n/a (server) | EyeCatchService | Hit, Fade | Dodge/feint (`Fade` afterimage) into heavy hit |
| ? | Sacrilegious | n/a (server) | SacrilegiousService | Startup, Stab, Dialog, Hit, Spin, Hit2, Dash | Dash-in stab, two dialogue lines, spin throw |
| ? | Shut Up | n/a (server) | ShutUpService | Startup, Throw, Swing, Hit, Hit1, Hit2, Jump, Crush | Stab → 0.7 s later throw → jump → ground crush |
| Ult | Ultimate (counter) | n/a (server) | CharlesService | Startup, UltimateNo, Ultimate | Counter stance; on success 8+ s cutscene (camera frames from `Utils.Charles.CounterCutscene`) with 13 parries; `UltimateNo` = fail/whiff variant |
| ? | Mark | n/a | CharlesService | Mark | 30 s mark decal on target |
| ? | Future / Perfect | n/a | CharlesService | Future, Perfect | Directional afterimage dash; perfect dodge (Hiromi dodge anims) |

- Animations: `Animations.Charles.UltimateAfter`, `Animations.Misc.Movement.DashLeft/DashRight/DashBack`, `Animations.Hiromi.Dodge[1-5]`.
- VFX modules: CameraShaker (LightHit, HeavyHit, Snap, SnapOh), BloodyZee. Templates: Utils.Charles.{CombatTrail, ParryFX.Core/Glow, Afterimage, CounterCutscene, HitEnd, Mark, Barrage, Dialogue, StabWind}, Utils.Todo.Swing, Utils.Gojo.{Twofold, LapseBlue.Throw}, Utils.Hiromi.Shockwave, Utils.Mahito.Dash, Utils.Damage.HitGlow, Utils.Locust.Slam, Utils.Choso.CounterSwing, Utils.Itadori.{RushWind,Shock}, Utils.ChaseHit.
- Sounds: Sounds.Charles.{M1.Hit*, UltStart, Ult, UltVoice, Throw, Despair.*, EyeCatch.*, ShutUp.*}, Misc.{Chase, Swing.Fist/Fist3}, Megumi.Mahoraga.Throw.Break, Itadori.ManjiKick.Dodge, Hiromi.{Verdict.Hit2, Execution.Stab}, Yuki.Swing, Itadori.CrushingBlow.GroundImpact.
- Skins/markers: none. Not in dump: cooldowns, damage, key bindings, ult meter gain, counter window.

### Choso (Base / Awake)
- **Character controller**: `ChosoController` (M1 Hit idx, Swing2 count 1-4 + Up/Down, Chase, Launch, BloodStart, Convergence, Interp homing orb, HomingHit, Chat = awakening cinematic with 3 "Brother" ghosts). Folder split: `Choso/Base` (BloodEdge, PiercingBlood, RedScale, Supernova) and `Choso/Awake` (BloodRain, PlasmaWave, SlicingExorcism, WingKing).

| Slot/key | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| Base ? | Blood Edge | n/a | BloodEdgeService | Draw, Swing, Dash, Hit, FinalHit, Crush | Blade dash-leap; client reports landing position |
| Base ? | Piercing Blood | n/a | PiercingBloodService | Startup, Clap, Blood, Hold, Flash, Hit | Hold-to-charge (30 → 60 stud beam) |
| Base ? | Red Scale | n/a | RedScaleService | Leap, Crush, Launch, Swing, Dash, Hit, FinalHit | Leap slam / rush combo; client self-launch velocity |
| Base ? | Supernova | n/a | SupernovaService | Start, Throw, Hit, Burst, CounterHit, Hit1, Hit2, Finisher | Blood-orb throw that also acts as counter (CounterHit) |
| Awake ? | Blood Rain | n/a | BloodRainService | Startup, Hit, Rain | Area rain, intensity scales with `Ultimate` attr; DomainBurst on start |
| Awake ? | Plasma Wave | n/a | PlasmaWaveService | Startup, Clap, Fire, FinalHit, BeamClashing | Giant beam with beam-clash support |
| Awake ? | Slicing Exorcism | n/a | SlicingExorcismService | Saw, Interp, Hit, Hit2, Reflect, Finisher, Flashup, Blood | Reflecting saw projectile (150 studs/s) + 4-stage blood beam |
| Awake ? | Wing King | n/a | WingKingService | Dash, Swing(1-7), Swing2, Hit, FinalHit, Hit2, Crush, Interp, Retract, GrabArm | Blood-arm whip grab (200 studs/s), 7-hit combo, earthquake crush |
| Awakening | Chat | n/a | ChosoService | Chat, BloodStart, Convergence | Dialogue + Brother ghosts + Switch eye GUI |

- Animations: only `Utils.Choso.Brother.AnimationController.Animation` (in template). VFX: CameraShaker, BloodyZee; Utils.Choso.{BloodRain, RainDrop, Switch, Convergence.Blood1, PlasmaWave, PlasmaWaveClash, PiercingBlood, Supernova.Blood1, CounterSwing, CounterHit, Concentrate, Flash, BloodExplode, BloodSpread, Brother, Dialogue}; cross-uses Hakari.RoughHit, Megumi.Mahoraga.{Earthquake, WorldSlash}, Itadori.{RushWind, Shock, CrushingBlow, DivergentFist.BlackFlashCC/BlackFlashHit}, Mahito.BodyRepel.Wind5, Gojo.{Twofold, HardHit.Ring, LapseBlue.Throw}.
- Sounds: Sounds.Choso.{M1.Hit*, Awaken, BloodMerge, Convergence, Counter, BloodBurst, BloodBurst2, BloodRain.*, PlasmaWave.*, PiercingBlood.*, SlicingExorcism.*, BloodEdge.*}; plus Itadori, Mahito, Hakari, Gojo, Megumi borrow-ins listed per row.
- Highlight colors: ArmFlash RGB(255,0,0) M1, RGB(170,0,0) skills. Not in dump: cooldowns, awakening trigger threshold, base↔awake move swap rules.

### Custom — Mokou (Touhou)
- **Character controller**: `MokouController` (M1 Hit idx 1-4, Swing2 count 1-5, AerialHit, Chase, Launch, Revive, Wing/WingFly, Kill, Awaken, generic Interp; `Service.Hitbox` client hit loop; `SpawnAnim`/`SpawnFunc` intro). Skills: Mokou1-4.

| Slot/key | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| 1? | Mokou1 (fire slash) | n/a | Mokou1Service | Startup, Swing(1-3), Hit, Hit2 | 3-angle slash, voice line on first |
| 2? | Mokou2 (dive kick) | n/a | Mokou2Service (+Hitbox) | Startup, Dive, Hit, Crush | Client hitbox r=8 + ground raycast, reports hits/ground pos |
| 3? | Mokou3 (Scorchrise pillar) | n/a | Mokou3Service | Startup, Pillar, Hit | Player becomes fireball steered by client move vector (70 studs/s) |
| 4? | Mokou4 (talisman barrage) | n/a | Mokou4Service | Startup, Barrage, Interp, Hit | Client streams aim target/pos at 50 Hz; talismans 200 studs/s |
| Ult | Awaken | n/a | MokouService | Awaken | ~10 s scripted transformation |
| Passive | Revive | n/a | MokouService | Revive, Kill | Phoenix resurrection cinematic (camera lock) |
| ? | Wing / WingFly | n/a | MokouService | Wing, WingFly | Wing aura toggled by BoolValue; flight burst |

- Animations: SpawnAnim id `109651238159963`. VFX: Utils.Misc.M.{Slash, Hit, DashHit, FirePilla, fireballstartup, Barrage, Talisman, Revive, wing, WingFly, TouhouBurst, Awk.*, SnapArm, FlameArm}; Utils.Misc.S.Boost (borrowed), Hiromi.Shockwave, Gojo.{Twofold.Sparks, HardHit, LapseBlue.Throw}. Modules: CameraShaker, BloodyZee, PlayerModule (controls), TekrinnDialogue.
- Sounds: Sounds.Misc.M.{M1.Hit1-4, Swing.1-4, Slash, Kick, KickHit, Scorchrise, Scorchrise2, Charm, Mokou1-4Voice, Revive, Kill, MokouUlt, MokouSpawn, MokouSpawnVoice}, Mahito.Soulfire.Hit, Hiromi.Grapple.Energy, Itadori.CraniumSmash.Hit2.
- Highlight: ArmFlash RGB(255,85,0); Revive highlight RGB(255,255,127). Dialogue lines in SpawnFunc (see row 22). Not in dump: cooldowns, revive count/conditions, awaken trigger.

### Custom — Chaos ("S")
- Single controller `ChaosController` (no separate character controller in slice). Keys: Form (7-orb ring), Boost (dash trail), Melee (client-side rush toward target), MeleeHit, Interp (Speed-attr homing orb), HomingHit, On (global sound). Assets `Utils.Misc.S.*`, `Sounds.Misc.S.*`. Highlight ArmFlash RGB(255,255,127). Not in dump: what character "S" is, unlock/cooldowns.

### Custom — Archive (Mechamaru / Hiromi leftovers)
- `BoostOn2Controller` (Mechamaru Boost On: BodyVelocity dash 125→5, boosters Stage1/Stage2, SraikoVFX), `PuppetBarrageController` (Mechamaru puppet with Owner/User/Friend exclusions, client Hitbox loop), `UltraCannon2Controller` (Albatros cannon, EffectUtils/Trove, works for non-Mechamaru `Moveset` with hidden accessories), `GrappleController` (Hiromi gavel grapple, LightningBeams chain, JoinController.lastRecvServer override). Path says `Custom/Archive` — likely disabled/legacy but still registered by `AddControllersDeep`.

### Gojo (Base / Awake)
- **Character controller**: `GojoController` (M1 Hit idx, Swing2, Chase/ChaseHit/AerialHit, Launch, Teleport w/ owner shard screen FX, Chat = blindfold-off awakening, FistSlam, CamFix, DragStart/DragThrow; `Service.Hitbox` client hit loop r=10).

| Slot/key | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| Base ? | Lapse Blue | n/a | LapseBlueService | LapseBlue, BlueGrab, Grab, Hit, Finisher | Pull orb, Infinity contact, debris-implosion finisher |
| Base ? | Reversal Red | n/a | ReversalRedService | Red, Explode, Finisher, Flip | Repel orb; Flip variant w/ voice |
| Base ? | Rapid Punches | n/a | RapidPunchesService | Hit, FinalHit, BlackFlashHit | Punch flurry, Black Flash chance |
| Awake ? | Lapse Blue Max | n/a | LapseBlueMaxService (+Debree) | Aerial, BlueGrab, Blue, PurpleHit, Finisher, Finisher2 | Aerial big Blue; `Purple` attr converts to Purple Max explosion |
| Awake ? | Reversal Red Max | n/a | ReversalRedMaxService | Aerial, Swing, Red, Fire, Explode, Hit, Music, BlackFlashImpact, BlackFlashHit, Finisher | Aerial 100-stud red beam; Black Flash variant with music `Gojo.Remember` |
| Awake Ult | Hollow Purple | n/a | HollowPurpleService | Aerial, Purple, Launch, Interp, Hit, Finisher | Blue+Red merge 1.25 s, 200 studs/s projectile, legs-only finisher, plays HollowPurple.Music |
| Awakening | Chat / Teleport | n/a | GojoService | Chat, Teleport | Blindfold dialogue; teleport with shard FX |

- Animations: none referenced. VFX: Utils.Gojo.{Teleport, TeleportBreak, Shard, Dialogue, HardHit, LapseBlue.{LapseBlue, LapseBlueMax, Infinity, Throw}, HollowPurple.{Blue, Red, Purple, PurpleMax, PurpleSnap}, ReversalRed.{RedExplode, RedMaxFire}, BlackFlashHit, Twofold}; Utils.Itadori.DivergentFist.{BlackFlashHit, BlackFlashCC, BlackFlashLaunch, FinisherDrag}, Utils.Itadori.CounterHit.Feint, Utils.Damage.{LegBurn, Chunk}, Utils.Heian.BloodSpread, Utils.Choso.CounterSwing.Shock. Modules: CameraShaker, BloodyZee, ToolController:GetMouseTarget.
- Sounds: Sounds.Gojo.{M1.Hit*, Teleport, Teleport2, TeleportDrag, DragThrow, FistSlam, GrabBlinds, BlindsOff, Remember, RedFlip, LapseBlue.*, HollowPurple.*, ReversalRed.*}, Itadori.{CraniumSmash.Hit2, Dismantle.Explode, DivergentFist.BlackFlash/BlackFlashHit}, Mahito.BlackFlash, Megumi.Mahoraga.{Throw.*, M1.Hit3-4}, Misc.{Chase, Swing.Fist}.
- Highlight: ArmFlash RGB(85,255,255); Blue grab flash RGB(85,170,255); purple hit RGB(255,85,255). Not in dump: cooldowns, Black Flash odds, awakening meter, aerial-input rules.

### Goku
- **Character controller**: `GokuController` (M1 uses Itadori.M1 sounds; KickHit, DownslamHit, ChaseHit, DismantleHit patterns 1-4, CleaveGrab/CleaveHit, StartScream, ChestBeat, Feint, Chase w/ NimbusCloud flight, StopCloud, Switch, Chat/Chat2, GokuVanish, Follow). Base skills: Kamehameha, KiSpam, StaffExtend, StaffUppercut. No Awake folder in this slice.

| Slot/key | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? | Kamehameha | n/a | KamehamehaService | AutoRotate, StartCharge, ChargeStronger, Shoot, RemoveCharges, Hit | Camera-aimed 50-stud beam, chargeable; disintegration finisher on `Dead` |
| ? | Ki Spam | n/a | KiSpamService | AutoRotate, ProjectileExplode, Hit, Shoot | Alternating L/R ki blasts, camera-aimed |
| ? | Staff Extend | n/a | StaffExtendService | Start, Swing, Hit, UpriseExtend, UpriseEnd, Launch | Power-pole thrust; pole-vault `Uprise` to ground |
| ? | Staff Uppercut | n/a | StaffUppercutService | Start, StaffTrail, StopTrail, Hit | Launcher; star twinkle if victim dead above Y 275 |
| M2 | Downslam / Kick | n/a | GokuService | DownslamHit, KickHit | Sound `Goku.M2DownslamHit` |
| ? | Cleave / Dismantle (Itadori reuse) | n/a | GokuService | DismantleHit, CleaveGrab, CleaveHit | Copied Itadori Sukuna moves |
| ? | Instant Transmission | n/a | GokuService | GokuVanish | Vanish → Appear on inst removal |
| Chase | Nimbus | n/a | GokuService | Chase, StopCloud | Cloud ride; owner aims HRP with camera |
| Awakening? | Switch / Chat / Scream / ChestBeat | n/a | GokuService | Switch, Chat, Chat2, StartScream, ChestBeat | Itadori.Switch FX, MonkeyScream (Oozaru?), chest beat shake <300 |

- Weapon: `SetAssets.GokuStick` (Uprise, Extention.Trail). Animations: none referenced. VFX: Utils.Goku.{Ball, Kamehameha, Explode, Star, NimbusCloud, Vanish}; Utils.Itadori.{Dismantle.DismantleFly/Cleave, Switch.Fade/Switch, Dialogue, CounterHit.Feint, DivergentFist.BlackFlashCC}; Utils.Gojo.LapseBlue.Throw; ChaseHit. Modules: CameraShaker (SmallBump, Snap, HeavyHit, LightLoop, SnapOh), BloodyZee.
- Sounds: Sounds.Goku.{Kamehameha.Use/Finisher, ExplodeKi, HitKi, ShootKi, StaffExtend.*, StaffUppercut.{Swing,Hit,Twinkle}, M2DownslamHit, MonkeyScream, ChestBeat, Vanish, Appear}, Itadori.{M1.*, Dismantle.*, FireArrow.Arrow}, Hakari.EnergySurge.Hit1, Gojo.{M1.Hit3, LapseBlue.Grab, BlindsOff}, Misc.{Chase, Swing.Fist}.
- Not in dump: cooldowns, ki charge levels, whether Cleave/Dismantle/Chat2 are live for Goku or copy-paste residue.

### Hakari
- **Character controller: NOT in this slice** (no `HakariController` file; only 8 skill controllers). Folder split: Base = FeverBreaker, ReserveBall, RoughEnergy, ShutterDoors; Awake = EnergySurge, LuckyRushdown, LuckyVolley, OverLuck.
- Moveset table:

| Slot | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? (Base) | Rough Energy | n/a (server) | RoughEnergyService | Startup, Swing, Hit, Dash, Crush | Palm blast → dash → ground crush (big variant) |
| ? (Base) | Reserve Balls | n/a (server) | ReserveBallService | Swing, Fire, Interp, Hit, Another | Pachinko ball projectile (150 st/s client interp); `Another` = position swap w/ target |
| ? (Base) | Shutter Doors | n/a (server) | ShutterDoorService | Spawn, Close, Fade, Bound, Break, Hit, Finisher | Summon doors (counter/trap), slam close, break (bleed finisher) |
| ? (Base) | Fever Breaker | n/a (server) | FeverBreakerService | Startup, Swing, Hit, Hit2, Dash, Spawn, Break, CrushSwing | Dash-in slash, door spawn & break combo |
| ? (Awake) | Energy Surge | n/a (server) | EnergySurgeService | Dash, HeavySwing, Flash, Flash2, Teleport, Jump, Hit | Teleport + heavy swing grab (Jump = grab-follow) |
| ? (Awake) | Lucky Rushdown | n/a (server) | LuckyRushdownService | Dash, Grab, Throw, Jump, JumpBurst, Hit | Rush 200→50 st/s, grab, jump slam, throw; bleed on final |
| ? (Awake) | Lucky Volley | n/a (server) | LuckyVolleyService | Barrage, Hit, Hit2, Swing | Rapid fist barrage (25ms loop) + finishing swing |
| ? (Awake) | Over Luck | n/a (server) | OverLuckService | Charge, Dash, Swing, HeavySwing, Hit | 4-swing rushing combo w/ speed dips on `Swing` attr |
- Combat-controller config: not in dump. Awakening = "Awake" folder (Idle Death Gamble jackpot presumably; no meter code here).
- Skins/markers: door color & ball color passed as optional Color3 args (skin recolor hook). Theme green (85,255,127).
- Animations: none referenced.
- VFX modules: CameraShaker; templates `Utils.Hakari.{RoughHit,RoughSwing,RoughImpact,Barrage,Indicators.BallFire}`, borrowed `Utils.{Itadori.CrushingBlow,Itadori.RushWind,Itadori.Shock,Gojo.Teleport,Gojo.TeleportBreak,Gojo.Shard,Gojo.Twofold,Gojo.AirPalm,Gojo.HardHit,Gojo.LapseBlue.Throw,Hiromi.Shockwave,Locust.Slam}`.
- Sounds: `Sounds.Hakari.{EnergySurge,FeverBreak,OverLuck,ReserveBalls,ShutterDoors,Counter,Shock,Impact}` + Itadori/Gojo/Misc borrowings.
- Not in dump: HakariController (M1/awakening/jackpot), cooldowns, damage, jackpot roll logic.

### Hanami
- Main: **HanamiController** (M1 `Hit`/`Swing`/`Swing2`, `Chase`/`ChaseHit`/`AerialHit`, `Launch`, uppercut/downslam roots, status effects Daze/Bud, Empower, awakening `Chat`, `BeamOffCD`). Skills: Base = BudShot, DefenseResponse, RootSwarm, SurgingThorns; Awake = CursedBuds, FlowerBeam, FlowerField, RootRampage.

| Slot | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? | Bud Shot | n/a | BudShotService | Startup, Interp, Hit | Fast seed projectile (200 st/s) |
| ? | Defense Response | n/a | DefenseResponseService | Weave, Hit, Spike, TreeMonster, SmallField | Counter: root spike / tree-monster grab that follows a part; small flower field |
| ? | Root Swarm | n/a | RootSwarmService | Startup, Roots, Hit | Ground root wave 9×4 studs forward |
| ? | Surging Thorns | n/a | SurgingThornsService | Spikes, WoodenBall, SpikesWindup, Hit | 360° spike ring; two wood balls firing spears on `Phase1/2` |
| ? (Awake) | Cursed Buds | n/a | CursedBudsService | Start, Appear, Interp, Hit, Hit2, Disappear | Aimed plant turret; client streams aim pos to server |
| ? (Awake) | Flower Beam | n/a | FlowerBeamService | Windup, StartBeam | Sustained beam; width/length via attributes |
| ? (Awake) | Flower Field | n/a | FlowerFieldService | Windup, FlowerTrail, FlowerExplosion, Lasso, LassoFail, GrappleHit | Trail then AoE bloom; root lasso grab |
| Ult | Root Rampage | n/a | RootRampageService | Windup, Roots, ReplicateRoots, StartSurf | Ride roots (camera-steered), surf phase, wooden-ball spike finish; OST plays |
- Combat config: M1 index `n` 1..4 + dir "Up"/"Down"; `InUlt` attribute flips arm-flash limb. Meter/status: Bud stacks (IntValue), Daze (token part).
- Skins/markers: none; theme (172,203,163) arm flash; wood palette {86,66,54},{76,60,51},{86,60,51},(67,47,35).
- Animations: `Animations.Hanami.{CursedBudsTreeSmall (marker "Loop"),EvilTreeIdle,EvilTreeThrow}`.
- VFX modules: CameraShaker, BloodyZee, SraikoVFX, MokouController:ArcTween; templates `Utils.Hanami.*` (Petals, Buds, FlowerField, UppercutRoot, EmpowerCharge, EmpowerAura, Dialogue, ParticleDissipationHolder, bud1, 360Spike, TreeMonster, SmallFieldWindup/Explosion, Beam.*, FlowerFieldTrail/Explosion, RootsDust, CurvedRoot, WoodBall).
- Sounds: `Sounds.Hanami.*` (BudShot, CursedBuds, DefenseResponse, FlowerBeam, FlowersField, RootRampage incl. OST, RootSwarm, AOESpikes, Uppercut, ArmWrapRip, Empower*, Awaken, RootDisappear).
- Not in dump: cooldowns, damage, bud-stack thresholds, ult meter.

### Haruta
- Main: **HarutaController** (sword/unarmed M1 split on `SetAssets.HarutaSword`, chase, launch, Miracles meter UI 0–6, dodge system, sword catch, taunt, HandMode LoS highlight, Jawbreaker execution cutscene). Skills: Base = Ambush ("StingerController"), Backstab, CheapShot, Trip; Hand = AnkleCutter, HighTime (thrown-sword/hand mode set).

| Slot | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? | Ambush/Stinger | n/a | AmbushService | Start, Whoosh, Hit, Stab | Lunge slash + stab |
| ? | Backstab | n/a | BackstabService | Start, Whoosh, Stab, Crush, Kick | Back/front stab; finisher Stab<n>→Slam→Kick |
| ? | Cheap Shot | n/a | CheapShotService | Start, ArmWave, Throw, Hit, Interp, Finisher | Sword throw projectile 150 st/s; bleed finisher |
| ? | Trip | n/a | TripService | Start, Hit | Leg sweep; reads target `Ragdoll` attr |
| ? (Hand) | Ankle Cutter | n/a | AnkleCutterService | Start, Hit, Interp, Dash | Projectile + dash-to-point |
| ? (Hand) | High Time | n/a | HighTimeService | Hit, Swing | Upward slash |
| — | Jawbreaker | n/a | HarutaService | JawbreakerStart | Curb-stomp execution cutscene (120fps CFrame frames) |
- Combat config: M1 idx 1..4, dir Up/Down; `Miracles` GUI Mir1..Mir6 (`UpdateMiracles(gui, n)`); `MiracleGain`/`MiracleUse` flashes; `DodgeAttempt`/`Dodge` (auto-dodge via miracles?).
- Skins: theme purple (167,125,203); HandMode highlight fill (167,125,203).
- Animations: `Animations.Hiromi.Dodge` children (random 1–5), stops tracks named Dodge1..Dodge5.
- VFX: CameraShaker, BloodyZee; `Utils.Haruta.{CombatTrail,SwordThrow,SlashEmit,SwordGrab,JawbreakerUI,JawbreakerCutscene}`, `Utils.Damage.{HitGlow,Skeleton.Head}`, `Yuta.SlashHit`, `Choso.CounterSwing`, `Mechamaru.Dust`, `Locust.Slam`.
- Sounds: `Sounds.Haruta.*` (M1.Hit/Swing<n>, AmbushSwing/Hit, Backstab*, BackstabFinisher.*, SwordThrow, Wave, CheapShotHit, SwordSpin, AnkleCutter*, Hightime, Trip1-3, Gain, Lose, Catch, Taunt, Jawbreaker).
- Not in dump: miracle gain rules, cooldowns.

### Heian (Sukuna Heian-era)
- **No HeianController** in slice (4 skill controllers only, no Base/Awake split). Voice lines gated by `char:GetAttribute("Moveset") == "Heian"` → these controllers are shared with another moveset (likely Itadori/Sukuna) and only Heian gets voice.

| Slot | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? | Cleave Rush | n/a | CleaveRushService | Start, Warn, Dash, CleaveGrab, Cleave, CleaveHit, Finisher, BlackFlashFinisherHard | Dash grab → 20-slash cleave; BF finisher variant |
| ? | Dismantle V2 | n/a | DismantleV2Service | Start, Interp, Hit, Hit2, DismantleSweep, Split, WCS | Slash projectile 300 st/s; 0.75s sweep; World Cutting Slash 500 studs |
| ? | Furnace Arrow (Fuga) | n/a | FurnaceArrowService | HotHands, Clap, Clap2, Arrow, Fire, Interp, Burn, Finisher | Clap → arrow charge → fire 192 st/s → burn explosion; Burn finisher |
| ? | Kamutoke | n/a | KamutokeService | Kamutoke, Strike, Finisher | Equip lightning tool; 0.7s telegraphed strike |
- Skins: none. Attributes `Moveset`, `Dead`; workspace `CC1`.
- Animations: none.
- VFX: CameraShaker, BloodyZee, LightningBeams; `Utils.Heian.{Cleave,BloodSpread,Sweep,WorldSlash,FlameArrow.*,Kamutoke,Lightning}`.
- Sounds: `Sounds.Heian.*` incl. Voice-group lines.
- Not in dump: HeianController, M1s, awakening, cooldowns.

### Hiromi (Higuruma)
- Main: **HiromiController** (M1 gavel/sword/unarmed, dodge, chase, awakening `Chat` gavel build, **Domain: Deadly Sentencing** minigame UI, Confiscate list, Amplification, gavel Recall/HammerSwap/HammerIFrame). Base = ExtendSwing, JudgeReach, PressingCharges; Awake = Execution, TripleSentence, Verdict.

| Slot | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? | Extend Swing | n/a | ExtendSwingService | Swing, SwingDown, Crush, Sweep, Hit, Hit2, Hit3, SweepMiss, SweepHit, Finisher | Gavel combo; sweep block-break; decap finisher |
| ? | Judge Reach | n/a | JudgeReachService | Startup, ExtendWind, Hit | Extended gavel strike |
| ? | Pressing Charges | n/a | PressingChargesService | Startup, Dash, Dash2, Hit, Hit2, Finisher | Twirl dash kick |
| ? (Awake) | Execution | n/a | ExecutionService | Charge, Charged, Aerial, Woosh, Fly, Hit, Whack, Arm, Leg, Head, Curb | Sword thrust (aerial aimable), dismember arm/leg/head, curb stomp |
| ? (Awake) | Triple Sentence | n/a | TripleSentenceService | Interp, Summon, Arm, Leg, Teleport, Stab, Toss, Hit1, Hit2, ThrowStart, Throw | Sword summon, teleport combo, throw |
| ? (Awake) | Verdict | n/a | VerdictService | Swing, Jump, Arm, Leg, HitSlash, HitBreak, Hit | Grab-follow combo w/ severs |
| Domain | Deadly Sentencing | n/a | HiromiService | Startup, Opening, Shatter, LightShatter | Trial: 3 buttons DENIAL/SILENCE/CONFESS → `choiceRemote:FireServer(1/2/3)`; timer 3s; health bar /3; saws drop on `VisualHealth`; `Confiscate` = ability removal list |
- Combat config: `Swing2(char, idx, dir)`; gavel trail (179,130,61); ExecSword idx 4 = punch. Dodge = `Animations.Hiromi.Dodge`. Amplification flash cyan.
- Skins: none explicit.
- Animations: `Animations.Hiromi.{Dodge/*,DomainWarn}`.
- VFX: CameraShaker, BloodyZee, LightningBeams (JudgeReach requires), `Modules.DeadlyData`; `Utils.Hiromi.*` (DeadlySentencing.*, SwordBuild.*, Limb, Thrust, Whack, Throw, BlockBreak, CombatTrail/2, GavelShard, AmpliAbsorb, HammerSwap, Confiscate, Dialogue), `Utils.Domain`.
- Sounds: `Sounds.Hiromi.*`.
- Not in dump: domain outcome rules (server), cooldowns, confiscation logic.

### Itadori
- Main: **ItadoriController** (M1 `Hit(target,n,isCounter)`, `Swing2` red arm flash / white in `InUlt`, chase, launch, `Switch` Sukuna swap VFX, `Chat`/`Chat2` awakening dialogue, cleave/dismantle/black-flash hit VFX, throwable). Base = CrushingBlow, CursedStrikes, DivergentFist, ManjiKick; Awake = Dismantle, FlameArrow, Rush.

| Slot | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? | Divergent Fist | n/a | DivergentFistService | CurseBuild, DivergentSwing, DivergentHit, DivergentStun, BlackFlashHit, BlackFlashChain, BlackFlashFinisher, Finisher, MusicStart, Music, BlackFlashHitHard, BlackFlashFinisherHard | Delayed-impact punch; Black Flash variants + cinematic hard hit |
| ? | Crushing Blow | n/a | CrushingBlowService | CurseBuild, Crush, Burst, Hit | Ground smash w/ rock projectile |
| ? | Cursed Strikes | n/a | CursedStrikesService (+`Hitbox` signal) | Swing, Leap, Dash, Hit, Crush, FinalHit, BlackFlashHit | Leap + dive; **client-reported hits** |
| ? | Manji Kick | n/a | ManjiKickService | Startup, Hit, Fade, Swing, Slam, Wheel, Crush, AprilFools | Counter dodge-kick; easter-egg finisher |
| ? (Awake) | Rush | n/a | RushService | Dash, Hit, FinalHit, AerialHit, Jump, JumpBurst | Rush grab combo |
| ? (Awake) | Dismantle | n/a | DismantleService | Swing, Hit, Hit2, Finisher, Chant, WorldSlash, WorldHit, DismantleFly, Aerial | Slashes, chant (3 stages) → world slash |
| ? (Awake) | Flame Arrow | n/a | FlameArrowService | HotHands, Clap, Arrow, Fire, Interp, Burn, Finisher | Fuga (Itadori version) |
- Combat config: M1 idx 1..4 (4 = leg), dirs Up/Down; `InUlt` attr; `Feint` VFX; `DismantleHit` slash patterns 1–4.
- Skins: none; red theme, white in ult.
- Animations: none.
- VFX: CameraShaker, BloodyZee, LightningBeams, MokouController; `Utils.Itadori.*`, `Utils.Todo.BlackFlashHit`, `Utils.Megumi.Mahoraga.*`.
- Sounds: `Sounds.Itadori.*` (M1, DivergentFist, CrushingBlow, CursedStrikes, ManjiKick, Rush, Dismantle, FireArrow, AprilFools, PerfectHit).
- Not in dump: Black Flash chance, cooldowns, ult (Sukuna switch) meter.

### Kurourushi
- **Character controller**: `KurourushiController` (M1 `Hit`/`Swing`/`Swing2`, `Chase`/`ChaseHit`, `Launch`, Hitbox client-report, injury/egg system, eat/limb removal, insect trance, Bugnado, Parthenogenesis, clone reveal). Skill controllers: Chokehold, Detach, FesteringStrikes, RoachSwarm. Folder split `Base/` vs root (no `Awake/` folder in dump).
- **Moveset table**

| Slot/key | Move name | Cooldown | Service/remote | Effects keys | Mechanic summary |
|---|---|---|---|---|---|
| ? | M1 string (fist / FesteringSword variants) | n/a (server) | KurourushiService | `Swing`,`Swing2`,`Hit`,`Launch` | 4-hit; `Swing2` idx 1/3 = sword trail when `SetAssets.FesteringSword` present, 2 = left ArmFlash, 4 = both arms; `Down`/`Up` finisher variants; detach-mode anim set `ArmsDetach/MeleeDetach` |
| ? | Chase | n/a | KurourushiService | `Chase`,`ChaseHit` | dash-in follow-up |
| ? | Chokehold | n/a | ChokeholdService | `Start`,`Hit`,`Hit2`,`Slash` | grab; punch or cleave variant (`isPunch` flag) |
| ? | Detach | n/a | DetachService | `Start`,`Aerial`,`Detach`,`Interp`,`Impact`,`Hit` | fires own right arm as projectile; aerial version aimed with mouse; arm rebounds (`Rebound` attr) with roach chain |
| ? | Festering Strikes | n/a | FesteringStrikesService | `Arms`,`Slash`,`Hit`,`Hit2`,`Hit3`,`Clash`,`PunchSwing` | 3-swing sword string w/ punch variant; clashable (`Clash`); slow-mo final hit |
| ? | Roach Swarm | n/a | RoachSwarmService | `Swarm1`,`Swarm2`,`Hit`,`Finisher`,`Explosion` | swarm projectile + follow-up; finisher skeletonises target |
| ? | Injury / Egg | n/a | KurourushiService | `Injury`,`InjuryTick`,`InjuryHatch` | DoT eggs implanted in torso; hatch spawns bugs/chunks |
| ? | Eat | n/a | KurourushiService | `EatStart`,`Eat`,`EatSoda`,`RipArms` | consumes limb by name (Head/Torso/Arms) |
| ? | Insect Trance ("Earthen Trance") | n/a | KurourushiService | `EarthenTranceStart`,`Interp`,`InsectBurst`,`InsectHit`,`InsectDisappear`,`Explode` | summon bug part that homes; screen-hit on victim |
| ? | Bugnado | n/a | KurourushiService | `Bugnado`,`Explode` | 4 swarm ribbons orbit growing tornado part |
| ult? | Parthenogenesis | n/a | KurourushiService | `CollectBugs`,`Divide`,`KuroClone`,`StartInvade` | splits into 2 clones; clones tagged w/ MoveReveal billboard visible when targeted |
- **Combat config**: Hitbox = sphere r8 at (0,0,-4) from HRP, `Info.Knockback` gate. Hit sounds idx 1/3 = own `Kurourushi.M1`, else `Gojo.M1`. Arm-flash colour RGB 101,35,44; injury flash 141,49,63; hatch flash 118,168,92.
- **Skins/markers**: `SetAssets.HeianArms.HeianArmsModel` (extra arm rig w/ own Humanoid + `Attach` ObjectValue), `SetAssets.FesteringSword.Union`. `Utils.MoveReveal` billboard (`Moveset` frame, `Handle`) on clones.
- **Animations**: `Animations.Kurourushi.{Chokehold,ChokeholdHitArms,ChokeholdHit,FesteringStrikesArms,FesteringStrikes,ArmsMelee.{Melee1-4?,Chase,Down,Up},Melee.*,ArmsDetach.*,MeleeDetach.*,EatArms,Eat,EarthenTranceArms,EarthenTrance,Parthenogenesis,ParthenogenesisArms}` (TimePosition 2.117 for clone split pose).
- **VFX modules**: CameraShaker (Snap, SnapOh, HeavyHit, MediumHit, LightHit), BloodyZee, FXController (Flash, ArmFlash, PlaySound, PlayParticles, DustTrail, DustBreak, Bleed), ToolController (GetTarget, GetMouseTarget).
- **Sounds**: `Sounds.Kurourushi.*` (M1, Chokehold, FesteringStrikes, Detach, RoachSwarm, Tick, Egg1-4, Hatch, EatStart, InsectTrance, Bugnado, Parthenogenesis, StartInvade), borrowed `Gojo.M1`, `Mahito.Eat`, `Itadori.Dismantle.Explode`, `Megumi.Rabbit.Eat`, `Megumi.Mahoraga.Throw.Break`, `Misc.{Chase,Swing.Fist,Items.Clash}`.
- **Not in dump**: cooldowns, damage, egg tick rate/duration, key bindings, unlock/gamepass.

### Locust
- **Character controller**: `LocustController` (claw M1, chase, aerial, flight, stinger, poison). Skills: BlackMucus, Clever, CrushJaw, WingThrow. No Hitbox handler (server-side hitboxes or via another controller).

| Slot/key | Move name | Cooldown | Service | Effects keys | Mechanic summary |
|---|---|---|---|---|---|
| ? | M1 (claws) | n/a | LocustService | `Swing`,`Swing2`,`Hit`,`Launch` | idx 3 = punch sound, 4 = no slash; `Down` = right-leg flash |
| ? | Chase / Aerial | n/a | LocustService | `Chase`,`ChaseHit`,`AerialHit` | |
| ? | Flight | n/a | LocustService | `Flight` | camera-directed flight; client sets HRP orientation and mover target |
| ? | Stinger | n/a | LocustService | `StingerOut`,`StingerFire`,`PoisonHit` | stinger reveal then fire; poison hit sound |
| ? | Black Mucus | n/a | BlackMucusService | `Start`,`Fire`,`Interp`,`Hit` | 125 studs/s projectile, purple 15s flash on hit |
| ? | Clever (four-armed) | n/a | CleverService | `Startup`,`Barrage`,`Hit`,`Hit2` | rapid arm barrage |
| ? | Crush Jaw | n/a | CrushJawService | `Dash`,`Leap`,`Chomp`,`Bite`,`Hit`,`Crush` | dash-bite grab w/ ground slam |
| ? | Wing Throw | n/a | WingThrowService | `Dash`,`Grab`,`Throw`,`ThrowHit` | 0.7s camera-steered grab dash, then throw |
- **Combat config**: ArmFlash colour RGB 85,170,0; Claws trails on arm for 0.3s.
- **Skins/markers**: none seen.
- **Animations**: none referenced client-side.
- **VFX modules**: CameraShaker, FXController; `_G.MapParams`.
- **Sounds**: `Sounds.Locust.{BlackMucus,FourArmed,Chomp,Slash,Flight,Victory}`; borrowed Itadori/Mahito/Gojo/Todo/Misc.
- **Not in dump**: cooldowns, hitboxes (no client hitbox), awakening (none seen).

### Mahito
- **Character controller**: `MahitoController` (4-variant M1 w/ Sword/Club weapons, chase variants, transform `M`, worms, dialogue, black flash, Hitbox client-report). Skills split `Base/` (BodyRepel, FocusStrike, Soulfire, Stockpile), `PreAwk/` (BodyDisfigure, IdleTransfiguration, SpikeWrath), `Awake/` (CrushingRushdown, FaceBlitz, HeadSplitter, WideSPStrike).

| Slot/key | Move name | Cooldown | Service | Effects keys | Mechanic summary |
|---|---|---|---|---|---|
| ? | M1 (variants 1-4) | n/a | MahitoService | `Hit`,`Swing`,`Swing2`,`Swing3`,`BladeHit`,`Launch`,`M` | variant 1 = dual swords (`MahitoWepR/L.Sword.Blade`), 2 = clubs (`ClubBase`), 3/4 = fists; `M(char,variant,parts)` = transform |
| ? | Chase | n/a | MahitoService | `ChaseStart`,`Chase`,`Chase2`,`ChaseHit` | variant-specific |
| ? | Worms / Spit | n/a | MahitoService | `Worms`,`Worms2`,`Spit`,`Chat`,`Chat2` | worm ragdoll spray; dialogue bubbles |
| ? | Body Repel | n/a | BodyRepelService | `Start`,`Clap`,`Fire`,`Hit` | flesh-serpent projectile, optionally ridden |
| ? | Focus Strike | n/a | FocusStrikeService | `Startup`,`Chain`,`ChainHit`,`BigClub`,`Hit`,`BlackFlashHit`,`Finisher1`,`Finisher` | charged strike; chain-whip / big-club variants; black flash chance |
| ? | Soulfire | n/a | SoulfireService | `Morph`,`Fire`,`Interp`,`Hit` | 200 studs/s projectile |
| ? | Stockpile | n/a | StockpileService | `Create`,`Swing`,`Hit`,`FinalHit`,`Crush`,`Finisher` | creates 2 weapon bodies; flattening finisher |
| pre-awk | Body Disfigure | n/a | BodyDisfigureService | `Pierce`,`Arm`,`Grab`,`Swing`,`Throw`,`Dash`,`Drill`,`DrillHit`,`Jump`,`Hit` | grab w/ mash escape (Jump, 20 presses → UnreliableRemoteEvent) + drill |
| pre-awk | Idle Transfiguration | n/a | IdleTransfigurationService | `Start`,`Flash`,`Dash`,`Hit`,`HitFinish`,`Finisher`,`BlackFlash*` | dash-touch; head-pop finisher (Nanami special case) |
| pre-awk | Spike Wrath | n/a | SpikeWrathService | `Startup`,`Start`,`Grab`,`Grab2` | beam-spike grabs |
| awake | Crushing Rushdown | n/a | CrushingRushdownService | `Interp`,`Hair`,`HairRetract`,`Ram`,`Hit` | hair-grab pull then ram |
| awake | Face Blitz | n/a | FaceBlitzService | `Grab`,`Leap`,`Leap2`,`Teleport`,`Crush` | grab → leap → teleport slam |
| awake | Head Splitter | n/a | HeadSplitterService | `Weave`,`Hit` | cinematic weave + slash |
| awake | Wide SP Strike | n/a | WideSPStrikesService | `Afterimages`,`Voice`,`Voice2`,`Hit` | 2.1s afterimage spin AoE |
- **Combat config**: Hitbox modes: continuous r12 at origin every 0.05s, or single r8 at -4. Arm-flash purple RGB 124,80,255; transfig flash 170,85,255. `Outfit` folder on char. `Aura` particle name.
- **Skins/markers**: `SetAssets.Weapon.MahitoWepR/MahitoWepL` with `Sword.Blade` or `Club.ClubBase`; attr `Moveset` ("Nanami" cross-check in finisher).
- **Animations**: `Animations.Mahito.WideStrike` only.
- **VFX modules**: CameraShaker (incl. ShakeSustain), BloodyZee, FXController (Flash, ArmFlash, Bleed, DustTrail, DustBreak); `_G.Settings.{Gore,Flash}`, `_G.MapParams`.
- **Sounds**: `Sounds.Mahito.{Variants.{M1,M2,M3,StrikeStart,Spin,Strike,Transform1-3},BodyRepel,Chainwhip,ForceGrab,DrillSplit,HeadSplit,WideSPStrike,CrushingRushdown,Soulfire,Stockpile,Transfig,Worms,BlackFlash,Eat,Slap,Roll}` + borrowed Itadori/Gojo/Hakari/Megumi.
- **Not in dump**: cooldowns, black-flash odds, variant switching input, awakening meter.

### Mechamaru
- **Character controller**: `MechamaruController` (base M1 `Swing2/Hit`, awakened M1 `Swing3/Hit2` = `Absolute`, Offload charge/aura, landing intros, detonation). Skills `Base/` (BoostOn, HeatEmission, UltraCannon, UltraSpin), `Awake/` (AbsoluteDestruction, MiracleCannon, PigeonViola, TechniqueCharge). No client Hitbox handler.

| Slot/key | Move name | Cooldown | Service | Effects keys | Mechanic summary |
|---|---|---|---|---|---|
| ? | M1 (base) | n/a | MechamaruService | `Swing`,`Swing2`,`Hit`,`Launch` | ArmFlash RGB 225,10,75 |
| ? | M1 (awakened "Absolute") | n/a | MechamaruService | `Swing3`,`Hit2` | own swing/hit sounds |
| ? | Offload (awakening) | n/a | MechamaruService | `OffloadCharge`,`OffloadAura`,`Sparks`,`Explosion` | charge → burst → aura; `red` flag recolors 250,75,75 |
| intro | Landings | n/a | MechamaruService | `SupermanLanding`,`BackSlide`,`ArmsFlyIn`,`FunnyFall`,`SmoothLanding1`,`SmoothLanding2` | entrance animations VFX |
| ? | Boost On | n/a | BoostOnService | `Start`,`Boost`,`Hit`,`Touch`,`Blast` | booster punch → touch grab → hand-blaster blast |
| ? | Heat Emission | n/a | HeatEmissionService | `Start`,`Leap`,`Blast`,`Hit` | vent / ignite variants |
| ? | Ultra Cannon | n/a | UltraCannonService | `Start`,`FireCannon`,`AlbatrosStart`,`AlbatrosCharge`,`AlbatrosFire`,`AlbatrosHit` | aimed cannon (client streams mouse target); "Albatros" = mouth-beam mode 37.5 studs |
| ? | Ultra Spin | n/a | UltraSpinService | `Start`,`Drill*`,`Hit`,`FinalHit`,`Finisher`,`Burst*`,`Burn*`,`Strike2`,`Burnt` | drill grab, slam, follow-up burst/burn |
| awake | Absolute Destruction | n/a | AbsoluteDestructionService | `Start`,`Step`,`Jump`,`Slam`,`Hit2` | run/jump/slam |
| awake | Miracle Cannon | n/a | MiracleCannonService | `Charge`,`Charge2`,`Push`,`ShootBeam`,`Explode`,`OneYearCharge`,`1YearEnabled`,`1YearExplode`,`1YearHit`; signal `Debree` | beam; "One Year" charged version w/ burn |
| awake | Pigeon Viola | n/a | PigeonViolaService | `Start`,`Spawn`,`Shoot`,`Interp`,`Hit`,`Explode` | homing projectiles (`Speed` attr) |
| awake | Technique Charge | n/a | TechniqueChargeService | `SpecialStartSound`,`FingertipLightning`,`FingerShoot`,`SimpleDomainDart` | finger-gun shot; dart implant detonation |
- **Combat config**: attr `Moveset~="Mechamaru"` hides Mechamaru-only mesh parts (blasters, boosters) → these moves are usable by other movesets (shared/borrowed).
- **Skins/markers**: char parts `FingersR`, `BoosterL/R` (Union w/ `Stage1/Stage2`), `Hand blasterL/R`, `Mecha mouth blaster`, `Drill`.
- **Animations**: none client-side.
- **VFX modules**: SraikoVFX (HandleMesh, Emit, EmitMesh, Enabled), EffectUtils (AutoEffects, AutoMeshes, Enable, Visibility, Tween, Debris), Trove (`Knit.Trove`), CameraShaker (incl. `HeavyLoop`), BloodyZee. `_G.Settings.DesPHY`, `_G.Settings.Gore`, `_G.MapParams`.
- **Sounds**: `Sounds.Mechamaru.{BoostOn,HeatEmission,UltraCannon,UltraSpin,AbsoluteDestruction,Absolute.{M1,M1Swing,Special},MiracleCannon,PigeonViola,Offload,PuppetBarrage}`.
- **Not in dump**: cooldowns, charge thresholds, Debree server trigger.

### Megumi
- **Character controller**: `MegumiController` (M1, chase, shadow-sink, awaken dialogue). Skills `Base/` (DivineDog, Nue, RabbitEscape, Toad), `Awake/` (GreatSerpent, MahoragaUse, MaxElephant, ShadowSwarm), `Mahoraga/` (Adaptation, DivinePummel, Earthquake, GroundPitch) = Mahoraga-form moveset.

| Slot/key | Move name | Cooldown | Service | Effects keys | Mechanic summary |
|---|---|---|---|---|---|
| ? | M1 | n/a | MegumiService | `Swing`,`Swing2`,`Hit`,`Launch` | black ArmFlash; idx 4 = left leg |
| ? | Chase / Shadow | n/a | MegumiService | `Chase`,`ChaseHit`,`Shadow` | shadow decal follow |
| ? | Divine Dog | n/a | DivineDogService | `Summon`,`Follow`,`Slash`,`Hit`,`Finisher` | pet follows owner client-side; slash x2 + bite |
| ? | Nue | n/a | NueService | `Nue`,`Hit`,`Finisher` | bezier swoop, carries grabbed target; burn finisher |
| ? | Rabbit Escape | n/a | RabbitEscapeService | `Start`,`Rab`,`Hit`,`Hit2`,`Launch` | rabbits hop to owner; eat dead targets |
| ? | Toad | n/a | ToadService | `Grab`,`Toad`,`ToadAir`,`Hit`,`HitAir` | tongue grab (ground / 10 air toads) |
| awake | Great Serpent | n/a | GreatSerpentService | `Start`,`Leap`,`Spawn`,`Hit` | camera-aimed serpent ride |
| awake | Max Elephant | n/a | MaxElephantService | `Start`,`Hitbox`,`Spawn`,`Smash`,`Hit`,`Finisher` | placeable 40x40 AoE (mouse target ≤75 studs) |
| awake | Shadow Swarm | n/a | ShadowSwarmService | `Domain`,`Start`,`Summon`,`Shadow`,`Dash`,`Grab`,`Swing`,`Hit`,`FinalHit`,`Wep`,`ForceFix` | 2 shadow clones dash & grab; DomainBurst |
| ult | Mahoraga Use | n/a | MahoragaUseService | `Start`,`Timer`,`Goodbye`,`Hit` | ritual chant + cutscene summon |
| Mahoraga | Adaptation | n/a | AdaptationService | `Glow`,`Adapt`,`Start`,`Teleport`,`Hit`,`WorldSlash`,`WorldSparkle`,`Interp`,`WorldHit` | adapts to attack type `A1`, damage mult `A2` (1.1/1.3/1.5/1.7/full); World Slash |
| Mahoraga | Divine Pummel | n/a | DivinePummelService | `Swing`,`Grab`,`Hit`,`FinalHit` | grab pummel |
| Mahoraga | Earthquake | n/a | EarthquakeService | `Start`,`Crush`,`Crush2` | attempt/success |
| Mahoraga | Ground Pitch | n/a | GroundPitchService | `Crunch`,`Throw`,`Interp`,`Hit`,`Finisher` | rips rock (server sends debris tuples), throws at 150 studs/s |
- **Combat config**: raycast include lists `workspace.{Map,Spawns,Domains}`; `char.Info.{Emote,WorldSlash}`; NumberValue `Offset` on char (serpent sway).
- **Skins/markers**: Mahoraga `Outfit.Head.{DivineWheel,Beard,Hat,Mouth.Pumpkin}` (Halloween variant parts destroyed in cutscene copy), `DivineWheelWeld`. Attr `Dead` on targets.
- **Animations**: `Animations.Megumi.{MahoragaSummon,ShadowSwarmRun,ShadowSwarm1,ShadowSwarm2}`; shikigami `AnimationController.{DivineDogsIdle,DivineDogsWalk,Emote,Summon}`.
- **VFX modules**: CameraShaker, BloodyZee (required, unused directly), FXController (DomainBurst, DomainMapFade, WorldModelChar, Burn, Bleed, DustBreak), MovementController (Tilt), ToolController (GetMouseTarget).
- **Sounds**: `Sounds.Megumi.{DivineDog,Nue,Rabbit,Toad,Serpent,Elephant,ShadowGarden,ShadowEnter,Awaken,Voice,Mahoraga.{AdaptGlow,Adapt2,Takedown,WorldSlash,Earthquake,Throw,Ritual,M1}}`, `Itadori.MalevolantShrine.Music`.
- **Not in dump**: cooldowns, adaptation thresholds/hit counts, Mahoraga form duration, domain rules.

### MeiMei
- **Character controller**: `MeiMeiController` (axe M1, chase/aerial, flock, crowstep, crow ultimate w/ remote-controlled crow, teleport). Skills `Base/` (BirdControl, Circling, ImpetusUpdraft, Murmurate). No client Hitbox handler.

| Slot/key | Move name | Cooldown | Service | Effects keys | Mechanic summary |
|---|---|---|---|---|---|
| ? | M1 (axe) | n/a | MeiMeiService | `Swing`,`Swing2`,`Hit`,`Launch` | trail on `SetAssets.MeiMeiAxe.Axe`; idx 4 = long trail 0.75s; `Up`/`Down` |
| ? | Chase / Aerial | n/a | MeiMeiService | `Chase`,`ChaseHit`,`AerialHit`,`Jump` | |
| ? | Flock | n/a | MeiMeiService | `Flock`,`FlockHit` | |
| ? | Crowstep | n/a | MeiMeiService | `Crowstep` | dash w/ crow explosion |
| ? | Teleport | n/a | MeiMeiService | `TeleportStart`,`Teleport` | two-point teleport VFX |
| ult | Crow Ultimate (Bird Strike) | n/a | MeiMeiService | `UltimateStart`,`CrowUltimate`,`CrowControl`,`CrowStart`,`CrowHit`,`CrowSmash`,`CrowBoom` | player pilots crow (camera subject), streams aim; kamikaze hit/smash/AoE |
| ? | Bird Control | n/a | BirdControlService | `Eye`,`Hit`,`Explode`,`Interp`,`Flight` | crow projectile / crow-carry flight (WASD-driven) |
| ? | Circling | n/a | CirclingService | `Start`,`Charge`,`Slash`,`Slash2`,`Slash3`,`DivebombWhoosh`,`DivebombFall`,`Crush`,`Hit1-4`,`Finisher` | chargeable (2 levels) divebomb w/ 3 fall stages |
| ? | Impetus Updraft | n/a | ImpetusUpdraftService | `Slash`,`Hit`,`Slash2`,`Hit2`,`Slash3`,`Hit3`,`Finisher` | launcher + 3-hit + 5-hit aerial strings |
| ? | Murmurate | n/a | MurmurateService | `Start`,`Throw`,`Flight`,`Slash`,`Slash2`,`Hit`,`Hit2`,`Land`,`Catch` | throw axe, glide (client reports landing), spin slashes, catch |
- **Combat config**: hit sounds `MeiMei.M1.Hit<N>`; slash VFX colour RGB 34,48,56 / 0.51,0.64,1; raycast include `workspace.{Map,Domains}`.
- **Skins/markers**: `SetAssets.MeiMeiAxe.Axe`; crow model attr `InControl`; target attr `MeiBleeding`.
- **Animations**: none client-side.
- **VFX modules**: CameraShaker, SraikoVFX (HandleMesh), FXController (Flash, Bleed, PlayParticles, DustBreak), ToolController, `PlayerModule.ControlModule`.
- **Sounds**: `Sounds.MeiMei.{M1,BirdControl,Circling,Gliding,Murmurate,Crush,Fall,UpdraftHit,UpdraftSlash,Flock,UltStart,BirdoStrike,CrowHit,CrowSmash,CrowExplode,CrowLaunch,Teleport,WingFlap}`, `Misc.Crow.Caw1-3`, `Misc.CrowMad2`.
- **Not in dump**: cooldowns, charge timings, crow HP/duration, axe catch window.

### Nanami
- **Character controller**: `NanamiController` (NanamiService). Skill controllers: CleavingWhirl, SeveranceKick, Stabilize (Base); Collapse, Interrogate, Sharpen (Awake).
- **Moveset table**

| Slot/key | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? (Base) | Cleaving Whirlwind | n/a (server) | CleavingWhirlService | Hit, Start, CleaverEmit, Slash, Swing, Whoosh, Dash, Finisher | Dash-in spinning cleaver; ratio hit variant (extra blood + RatioHit sfx); Finisher → Bleed |
| ? (Base) | Severance Kick | n/a (server) | SeveranceKickService | Swing, Whoosh, Hit, ThrowableWind, ThrowableHit | Front/back kick, delayed 2nd impact; stun-back variant; can hit throwables |
| ? (Base) | Stabilize | n/a (server) | StabilizeService | Start, Whoosh, Hit, Spin | Spin/hold; long vs short spin sfx; ratio hit variant |
| ? (Awake) | Collapse | n/a (server) | CollapseService | Hit, Hit2, Jump, ArmEmit, Leap, Collapse, CollapseDebree, Break, Launch, Finisher | Camera-steered leap → ground slam with voxel destruction (client reports impact point) |
| ? (Awake) | Interrogate | n/a (server) | InterrogateService | Start, Swing, Dash, TrueRagdoll, FinalSwing, Ohno, Hit, Grab, Chat, FinalHit, FinalHit2 | Grab cinematic with dialogue lines & numbered Grab sounds; finisher freeze variant |
| ? (Awake) | Sharpen | n/a (server) | SharpenService | Hit, Slash2, CleaverSlam, CleaverTrail, Slash, RatioBar, RatioBreak | Air/ground cleaver slashes with physical ratio bar; finisher → Bleed |
| Ult | "Ultimate" / awakening | n/a | NanamiService | Ultimate, EyeFlash, Chat, Dismember | Sets `InUlt` attr (server); M1s switch to fist sounds |
| passive | Ratio Technique (7:3) | n/a | NanamiService | SpawnRatio, DestroyRatio, BlackFlashHit | Timing-bar minigame driven by server time; success → ratio hits |

- **Combat config**: M1 idx 1–4, directions "Down"/"Up"/"Air"; cleaver trail on non-ult swings (swing 4 longer 0.45s); Black Flash hit effect; Chase/ChaseHit/Launch standard.
- **Skins/markers**: `SetAssets.NanamiCleaver` accessory model. No skin names.
- **Animations**: none referenced (Animations folder loaded but unused).
- **VFX modules**: CameraShaker, BloodyZee, SraikoVFX (Collapse/Sharpen), LightningBeams (required, unused).
- **Sounds**: `Sounds.Nanami.{M1, CleavingWhirlwind, SeveranceKick, Stabilize, CrossCut, Collapse, Interrogate, Sharpen, Ratio, BlackFlash, Ultimate, EyeFlash, Dismember}` plus borrowed Gojo/Itadori/Todo/Mahito/Megumi/Hiromi/Yuta/Hakari sounds.
- **Not in dump**: keybinds, cooldowns, damage, ratio timing window, InUlt grant rules, voxel destruction rules.

### Naoya
- **Character controller**: `NaoyaController` (NaoyaService). Skills: Bleedout, CursoryImpact, DecisiveStrike (+DecisiveStrike2), ProjectionBreaker (Base); FlashFreezing, TendrilGrab, TopSpeed (Awake).
- **Moveset table**

| Slot/key | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? (Base) | Bleedout | n/a | BleedoutService | Startup, Stab, Hit, Hit2, Hit2Freeze, Throw, FinishingStab, Afterimages, Flash | Stab combo w/ bleed DoT; afterimage rush cinematic |
| ? (Base) | Cursory Impact | n/a | CursoryImpactService | Startup, Hit, UhOh, Grab, Hit2, Throw, Zwoosh, Swing, Swing2 | Punch → kick → grab → throw; teleport flicker |
| ? (Base) | Decisive Strike (2 variants) | n/a | DecisiveStrikeService, DecisiveStrike2Service | Weave, Flick, ClearForce, FlickBar, Ding, Windup, Hit1, Hit2, Hit, Hit3 | Charged flicker-dash w/ 1–3 level bar (FlickBar meter), barrage finisher |
| ? (Base) | Projection Breaker | n/a | ProjectionBreakerService | Weave, Spin, Kick, Hit | Dodge weave + spin kick |
| ? (Awake) | Flash Freezing | n/a | FlashFreezingService | Frame, Explode | Frame glass trap/shatter |
| ? (Awake) | Tendril Grab | n/a | TendrilGrabService | Preview, Grab | 50-stud ground AoE preview → tendril bind on victims |
| ? (Awake) | Top Speed | n/a | TopSpeedService | Start, Fly, Hit, Pass, Track | Camera-steered flight; Speed attr 1→3+ (sonic boom); auto-track FrameNPC |
| Ult | Projection form | n/a | NaoyaService | Form, SpinStart, Spin, Velocity, Parry, Lost, Grip, Blink, Trail, Zwoosh, Frame | Transform + speed buildup meter; Parry counter (Lost = enemy fell/caught) |

- **Combat config**: M1 `Gojo.M1.HitN`; Swing2/Swing3 ArmFlash patterns (purple RGB(128,126,255)); M1 hit FX suppressed while `Info.NaoyaFrame` present (frame = 24fps rule violation state). `Humanoid.Speed` attr 2–4 for Velocity meter.
- **Skins/markers**: none. Frame clone char named `FrameNPC` in `workspace.Characters`.
- **Animations**: none referenced.
- **VFX modules**: CameraShaker, BloodyZee, SraikoVFX (ProjectionBreaker).
- **Sounds**: `Sounds.Naoya.{Frame, FrameBreak, Frames, Acceleration, Pass, Bleedout, Cursory, Decisive, ProjectionBreaker, TendrilGrab, TopSpeed, Ultimate}`.
- **Not in dump**: frame-rule logic, Speed accumulation, cooldowns, damage, grab durations.

### Reggie
- **Character controller**: `ReggieController` (ReggieService). Skills: BluntTrauma, DroneStrike, Fleche, GarageSale, GushingWound, Homerun, PianoDrop, PoleVault, SpeedCrash (Base); Arson, BigMoves, Mayhem (Awake).
- **Moveset table**

| Slot/key | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ReggieSlot (rotating item) | MoveSwap | n/a | ReggieService | MoveSwap, Discard, GoldSeal, DiscardWhoosh, Burn, CouponStart | Slot UI flashes on item change; Discard/GoldSeal highlight self |
| ? | Blunt Trauma | n/a | BluntTraumaService | Start, Slash, Break, Hit, Align, Dizzy | 5-hit melee w/ breakable object; dizzy debuff |
| ? | Drone Strike | n/a | DroneStrikeService | Start, DroneStart, Press, DroneLoop, Aim, Break, Explode, Interp | Player-steered drone (client streams move vector) |
| ? | Fleche | n/a | FlecheService | Hit, Hit2, Dash, Pull, Drop, Open | Lunge stab w/ open/closed weapon states |
| ? | Garage Sale | n/a | GarageSaleService | Start, Interp, Break, Hit | Throws random furniture incl. Fridge |
| ? | Gushing Wound | n/a | GushingWoundService | Start, Hit, Interp | Knife throw(s), bleed |
| ? | Homerun | n/a | HomerunService | Start, Interp, HitBall, Hit, Hit2, CollidedBall | Bat ball projectile, boostable, reflectable |
| ? | Piano Drop | n/a | PianoDropService | Hitbox, Spawn, Smash | Mouse-targeted AoE (15/30 studs) piano drop; ToolDeactivate returns mouse target |
| ? | Pole Vault | n/a | PoleVaultService | Hit, Drop, Slam, Launch | Vault leap + slam |
| ? | Speed Crash | n/a | SpeedCrashService | Throw, Start, Drive, Explode, Hit, Hit2, Slide | Motorbike ram, boost, explode |
| ? (Awake) — **removed in 1.85** | Arson | n/a | ArsonService | GasolineBurst, Explosion, Gas, Burn, BurnTick | Gasoline soak → ignite → burn DoT |
| ? (Awake) | Big Moves | n/a | BigMovesService | Hit, Shake | Truck summon (Speed>40 wind/shake) |
| ? (Awake) | Mayhem | n/a | MayhemService | Start, Explosion, Interp, Land, Heal | Receipt bombs + heal |
| ? (Awake) **(1.85)** | Road Rage | n/a | RoadRageService | Hit, Hitbox, CarInterp, Crush2, Finisher | Aimed car strike. Server sends the caster `Effects("Hitbox", remote)`; the client shows a 15×15 `Megumi.HitArea` shrinking over 9 s at its mouse point (`GetMouseTarget(200)`, snapped to the ground by a 300-stud down-ray) and **streams that point into the throwaway remote every 0.025 s for as long as the remote exists**. `CarInterp` drives a car model (`Root`, `Car`, colour attribute `C`) with two wheel rays following the ground |
| ? (Awake) **(1.85)** | 132-Square-Foot Two-Story House | n/a | HouseService | Start, Voice, Hitbox, Smash, Interp, Smash2, Hit, Finisher | Aimed 50×50 drop. `Effects("Hitbox", flag BoolValue, remote)`; the client streams its mouse point about every 0.1 s and sends it once more when the flag turns true. `Utils.Reggie.HouseVisual` follows the falling part until its `Stop` attribute is set |
| misc | Littering / Spa / Sweep / Ball / RainbowSeal | n/a | ReggieService | LitteringStart, LitteringLand, LitteringActivate, Ball, BallHit, Spa, Sweep, RainbowSealExplode, Chat, Ultimate | Coupon/receipt item effects; Ultimate sfx |

- **Combat config**: M1 `Gojo.M1.HitN`, white ArmFlash mapping; Chase/ChaseHit/Launch standard.
- **Skins/markers**: `Utils.Reggie.Highlight` (Discard white / GoldSeal gold RGB(255,217,102)) on local char only.
- **Animations**: none referenced.
- **VFX modules**: CameraShaker, BloodyZee; projectile dead-reckoning via `BulkMoveTo` + `Speed` attr (Drone, GarageSale, GushingWound, Homerun, Mayhem).
- **Sounds**: `Sounds.Reggie.{BluntTrauma, DroneStrike, Fleche, GarageSale(folder), Homerun, Littering, SpeedCrash, TruckHit, TruckHorn, KnifeHit, KnifeThrow, CouponBurn, CouponBurn2, CouponWhoosh, GarageSaleFire, Metal1, Metal2, PianoFall, PianoBreak, Discard, Heal, MayhemStart, Ultimate}`.
- **Not in dump**: item deck/rotation rules, Gold/Rainbow seal effects, cooldowns, damage, drone lifetime.

### Ryu
- **Character controller**: **not in this slice** (no `RyuController` file assigned; skill files only). Skills: Appetizer, GraniteBlast, SecondHelping, Unsatisfied (Base); HadNoIdea, WerentInvited, WhatAreYouAfter (Awake).
- **Moveset table**

| Slot/key | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? (Base) | Appetizer | n/a | AppetizerService | Startup, Fire, Fire2, Interp | Quick granite beam projectile (180 st/s), hard variant |
| ? (Base) | Granite Blast | n/a | GraniteBlastService | Startup, Warn, Fire, FireHard, Hit, Interp, Aerial, Finisher | Charged beam, aerial hover aim, Finisher → Burn |
| ? (Base) | Second Helping | n/a | SecondHelpingService | Startup, Swing, Crush, Hit, HitPact | Leap slam toward target; air-hit variant |
| ? (Base) | Unsatisfied | n/a | UnsatisfiedService | Startup, Dash, Dash2, Hit, Hit2, HitEnd | Rush combo; lightning burst finisher |
| ? (Awake) | Had No Idea | n/a | HadNoIdeaService | Startup, Swing, Ow, StartHit, Hit, FinalHit | Grab beatdown |
| ? (Awake) | Weren't Invited | n/a | WerentInvitedService | Startup, Charge, Charged, Dash, Swing, Interp, Crunch, Hit, PunchWall | Chargeable punch carrying rock mass (120 st/s), wall punch |
| ? (Awake) | What Are You After | n/a | WhatAreYouAfterService | Startup, Aerial, Crush, Dash, Hit, Hit2 | Aerial hover → dive crush |

- **Combat config**: n/a in slice. Theme color cyan RGB(170,255,255).
- **Skins/markers**: none.
- **Animations**: none referenced.
- **VFX modules**: CameraShaker, BloodyZee, LightningBeams + StaticLightning (Unsatisfied), `MokouController:ArcTween` (shared arc VFX from Mokou), `Utils.Misc.M.Awk.mokultMeh["3"]`.
- **Sounds**: `Sounds.Ryu.{GraniteBlast, SecondHelping, Unsatisfied, HadNoIdea, NotInvited, Dessert}` + Hakari/Mechamaru/Megumi/Nanami/Naoya borrows.
- **Not in dump**: RyuController (M1s/awakening), cooldowns, damage, charge thresholds.

### Todo (Aoi Todo) — Boogie Woogie
- Character controller: **TodoController** (`TodoService`): M1 hits, chase, launch, Boogie Woogie swap VFX/teleport, awakening cutscene, Takada companion. Skill controllers: Base = BruteForce, PebbleThrow, SwiftKick; Awake = Brothers, ClimaxJump, Dreams, IdolDebut.

| Slot/key | Move name | Cooldown | Service | Effects keys | Mechanic summary |
|---|---|---|---|---|---|
| ? | M1 / Chase / Launch | n/a (server) | TodoService | Hit, ChaseHit, Chase, Swing, Swing2, Launch, Woosh, GrabHit | Todo.M1.Hit1-3 sounds; ArmFlash blue (0,170,255); GrabHit idx 1-3 (a 3-hit grab combo, idx1 heavy) |
| ? | Boogie Woogie swap | n/a | TodoService | Swap, Swap2, Fakeout, Perfect, BlueGrab2 | Clap VFX at both ends; local client relocates own HRP to server-given CFrame (skipped if target Ragdoll>0, skip flag, or `_G.Shift` false); Swap2 = swap with an object/model; Fakeout = clap without swap; Perfect = cyan highlight "perfect" timing feedback; BlueGrab2 = blue mark on a swap-target model |
| ? | Brute Force | n/a | BruteForceService | Swing, UhOH, Woosh, Hit, BlackFlashHit | Heavy punch; Black Flash variant, "Wapam" special variant with Bleed + voice |
| ? | Pebble Throw | n/a | PebbleThrowService | Interp, Stomp, Hit | Stomps ground, throws pebble projectile (130 st/s client interp) |
| ? | Swift Kick | n/a | SwiftKickService | Start, Swing, Dash, Hit, Grab, UpdateCamera, Aim, Throw | Dash 150/165 → 35 client-driven BodyVelocity; grab → aim (camera-locked BodyGyro, camera streamed to server as float16) → throw |
| ? (Awake) | Brothers | n/a | BrothersService | Clap, Swap, BlackFlash | Swaps in a Yuji dummy (`Utils.Todo.Yuji`, `Animations.Todo.Brothers`) who lands a Black Flash |
| ? (Awake) | Climax Jump | n/a | ClimaxJumpService | Grab, Hit, Hit2, Hit3, Burst, Dash | Grab → cinematic (Takada stage cutscene when InUlt) → hits; Takada plays JumpStart/JumpEnd |
| ? (Awake) | Dreams | n/a | DreamsService | Start, Hit, Hit2, Swing | Pink 4-swing barrage w/ heart hit VFX |
| ? (Awake) | Idol Debut | n/a | IdolDebutService | Swing, Swing2, Jump, JumpBurst, Hit, Hit2 | Beam swing, jump (BodyPosition), cinematic hit when InUlt |
| Awakening | "Imagination" (Takada summon) | n/a | TodoService | Chat, Applause | Chat = cutscene GUI (`Utils.Todo.Awakening.Flash`, `Animations.Todo.Ultimate`, chain necklace viewport, "THIS IS <DISPLAYNAME>'S IMAGINATION" label, Todo.Awaken.Music loop while `InUlt`), Aura + CC; spawns `FollowTakada` companion model (idle anim `TakadaJoint.TakadaIdle`, offset (-2,2,2) or attr `A`, hidden while Stun/Ragdoll) for the whole InUlt duration. Applause = summon pose (`Animations.Todo.Summon`, Todo.OST) |

- Combat config: M1 hit sounds indexed 1-3; Swing2 dir "Down"/idx 1-4 → limb flash; chase hit uses Hit3. Awakening flag attr `InUlt`.
- Skins/markers: none. Takada outfit override via `_G.Settings.Outfit` (outfit id → HumanoidDescription applied to `Utils.Todo.Awakening.Takada`, persisted into ReplicatedStorage copy).
- Animations: `Animations.Todo.Brothers`, `.Todo.Ultimate`, `.Todo.Summon`, `.Todo.IdolDebut`, `.Todo.TakadaJoint.{TakadaIdle, Emote, JumpStart, JumpEnd}`; GUI-embedded anims `Flash.User/Takada/Target`, `Main.TakadaSummon`, `Chain.Chain`; all `Utils.Todo` Animation descendants preloaded on Takada.
- VFX modules: CameraShaker, LightningBeams (Brothers). Utils: Todo.{Clap, Yuji, HeavyHit, BlackFlashHit, Swing, Woosh, Jump.*, Debut.*, Awakening.*}, Hakari.{Barrage.ColorArm, RoughSwing}, Mahito.BodyRepel.Wind1-5, DomainWarn.Panel.Viewport.Display.
- Sounds: Sounds.Todo.{M1.Hit1-3, Clap, Perfect, Woosh, Wapam, WapamVoice, OST, Voice, Awaken.SFX/Music, Jump.Bell, Debut.Jump/Jump2, BruteForce.Start/Swing/Hit}; borrowed Itadori/Hakari/Gojo/Mahito/Megumi/Choso sets.
- Not in dump: cooldowns, damage, swap range/rules, what `_G.Shift` toggles (client "shift-lock"?), awakening meter.

### Toji (Hired Hunter) — Hidden Inventory **(1.85)**
- **Character controller**: `TojiController` (`TojiService`: `Activated`, `Chase`, `Effects`, `Hitbox`, `RightActivated`, `RightDeactivated`, `Ultimate`). Skill controllers are foldered by weapon: `SSK/` Flourish, Debilitate; `ISOH/` Transcend, Rupture; `COATM/` Lasso, Whiplash. All seven controllers are **effects-only**: each connects `<X>Service.Effects` and nothing else, none reports a hitbox and none fires a remote. Every C→S input goes through the generic `ToolController` route (§17.3). `TojiService.Hitbox` exists in the remote tree but no dumped client code references it.
- **Stances**: `Info.Stance` (StringValue) is `"SSK"`, `"ISOH"` or `"COATM"` — by the asset and sound names, Split Soul Katana, Inverted Spear of Heaven and Chain of a Thousand Miles. The weapon models sit under `char.SetAssets` named after the stance (`SSK.Blade`, `ISOH.Blade`, `COATM["1"]`, `COATM.Beam5/6`). The special, **Hidden Inventory** (`TojiService.RightActivated(target)` then `RightDeactivated`), changes the stance. A child `Info.FastSwap` (attribute `Duration`) makes the client overlay a draining white bar on `Main.Controls.Ultimate.Special` — a window in which the next swap is quick. Each stance has its own M1 chain and its own two moves.
- Ultimate name **Puppet of Carnage** (`UltNames.Toji`, colours 24,24,24 / 0,0,0). List header `HIRED HUNTER`, RGB(50,50,50). `ListData.Characters[26]`.

| Slot/key | Move | Cooldown | Service | Arg code (§17.3) | Effects keys | Mechanic |
|---|---|---|---|---|---|---|
| M1 / Chase | per stance | n/a | TojiService | Chase: `(airborne, dir)` | Swing, Swing2, Hit, Launch, Chase, ChaseHit, Chase1Hit, Chase1Spin, Chase3Crush, Chase3Hit, Chase3Finisher, Chase3Whoosh | `AnimList`: SSK `Melee1–3`, ISOH `Melee1–4`, COATM `Melee1–4`, each with `Up`, `Down`, `Chase`. `Swing`/`Hit` take the stance as an argument and pick `Sounds.Toji.<Stance>.M1`. `Chase1*` = SSK spin slash (`Utils.Toji.SSKCombatTrail` welded to `SSK.Blade` for 0.4 s). `Chase3*` = COATM chain crush ending in a gore finisher (`Chase3Finisher`: victim made invisible, 50 blood bursts, 20 `Damage.Chunk`). **In COATM a Back dash also chases**: `MovementController` treats `Moveset == "Toji" and dir == "Back" and Info.Stance.Value == "COATM"` like a Front dash and calls `UseSetService("Chase", airborne, dir)` |
| Special | Hidden Inventory | n/a (client sees `M2_CD`/`LastM2` as for every special) | TojiService | `RightActivated(GetTarget())` | Setup, StanceHide, StanceUnequip, StanceEquip, Equip | Stance swap. `StanceEquip(char, stance)` plays `Sounds.Toji.Stance.<stance>Equip` plus `Toji.Worm.Laugh1/2` (the inventory curse); `StanceHide` is a camera shake only |
| ? (SSK) | Flourish | n/a (server) | FlourishService | 0 (`false`) | Spin, Hit, Hit2, AfterImage, Slowmo, Slash, ChainSpin, ChainGrab, ChainHit, ISOHHit, KickHit, ISOHTrail, FasterDash, FinalLand | Spin-slash opener. The 1.85 log names three variants — **The Wrath**, **The Greed**, **The Pride** (anims `Toji.SSK.FlourishWrath`, `Greed`, `Pride`; victim anims `WrathVictimL1/L2/R1/R2/Last/Slash`, `PrideVictim`, `FlourishVictim`). The key list suggests one variant uses all three weapons in one string (`ChainGrab` → `ISOHHit` → `KickHit`) with a slow-motion beat (`Slowmo`, `Sounds.Toji.SSK.Flourish.SlowMo`). What selects a variant is server-side |
| ? (SSK) | Debilitate | n/a (server) | DebilitateService | 6 (`{airborne, InDash, InRoll}`) | Swing, Hitbox, Hitbox1, Jump, Hitbox2, Hitstop, Launch | Three-slash dash attack (`Slash1–3`, `Dash`, `Hit1–2`) with a hit-stop frame (`Utils.Toji.DebilitateHitstop`). The three flags it sends presumably pick the opener (that choice is server-side); the `Hitbox*` keys only draw, they are not hit reports |
| ? (ISOH) | Transcend | n/a (server) | TranscendService | 1 (airborne) | Startup, Dash, Hit | Blink-dash strike to a server-chosen point (`Dash(char, goalPos, …)` with dust and afterimages). Airborne it becomes **Ascend** (attribute `Ascend` on the trail). `Hit(…, clash)` plays `Misc.Items.Clash`, so it can clash with a weapon |
| ? (ISOH) | Rupture | n/a (server) | RuptureService | 0 | Hit, Dash, Swing1, Windup, Swing2, SkillCheck, Feint, Catch, EatISOH, Throw, Stab, Hit2 | Dash, two swings, then the spear is thrown and caught (`Throw`, `ThrowLoop` sound, `Catch`). `SkillCheck` flashes `Utils.Toji.ISOHUseTwice` on the blade for 0.5 s (until a server object's `Start` attribute changes) — by its name, a prompt to press the move a second time; `Feint` is a sidestep with a flicker afterimage; `EatISOH` only plays the ISOH unequip sound (the spear is stowed). Variants **Paradise**, **Reincarnation**; which input leads to which is server-side |
| ? (COATM) | Lasso | n/a (server) | LassoService | 0 | Start, ChainGrab, Hit, Pull, KickWhoosh, Hit2 | The chain coils three times round the victim's `Torso`, pulls them in, kick. `AnimList` has `LassoBroken`, so it can be broken out of |
| ? (COATM) | Whiplash | n/a (server) | WhiplashService | 0 | Start, Spin, Whoosh, Hit, Hit2, Dash | Spin-up then a whip slam. The client searches for the ground impact **27 studs** ahead of the caster (stepping back toward 0 if there is no floor) — the best client evidence of its reach. Variant **Twirling Strike** (`WhiplashVariant`, `WhiplashSpin`) |
| Ult | Puppet of Carnage | n/a | TojiService.Ultimate | — | — | Name only; nothing of the awakening kit is in the client beyond the standard ultimate plumbing |

- **Rules other controllers apply to a Toji** (he has no cursed energy, and the code says so): `DomainController.TojiDisableCollider` polls every 0.1 s and makes domain barriers non-collidable for a local Toji; `ItemController` destroys the `Reveal` marker on a Toji's HRP; Hakari's Idle Death Gamble info card is not shown to a Toji; `DuelController` skips the binding-vow picker for a Toji.
- Idle animation: 119619096808750 in SSK, 140491244934559 in the other two (`Animate`).
- VFX/Utils: `Utils.Toji.{SSKCombatTrail, ISOHCombatTrail, COATMCombatTrail, ChainHit, ChainCircles, ChainTip, Flourish, Smears1, Teleport, ShineHolder, RuptureFlash, RuptureSlash, ISOHUseTwice, DebilitateHitstop}`, reusing `Yuta.SlashHit`, `Itadori.CrushingBlow`, `Gojo.LapseBlue.Throw`, `Mahito.CrushingRushdown.DrillImpact`.
- Sounds: `Sounds.Toji.{SSK, ISOH, COATM}.{M1, <Move>.*}`, `Toji.Stance.<Stance>Equip/Unequip`, `Toji.Worm.{Equip, Unequip, Laugh1, Laugh2}`, `Toji.COATM.Chase`.
- **Not in dump**: cooldowns, damage, the swap order and its cooldown, what opens a `FastSwap` window, variant selection, the awakening kit.

### Uro (Takako Uro) — Sky Manipulation ("Sky Bender" in 1.85; special **Sky Veil**)
- Character controller: **UroController** (`UroService`): M1/aerial/chase, ult intro dialogue, air-distortion trails, giant Thin Ice Breaker (`TIB`), `SkyGrab`, `Flight`, plus **client-auth `UroService.Hitbox`** sphere hit report. Skills: BlindRage, SkyDistortion, ThinIceBreaker.

| Slot/key | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? | M1 / Aerial / Chase / Launch | n/a | UroService | Hit, ChaseHit, AerialHit, Chase, Swing, Swing2, Launch | Gojo.M1 sounds; ArmFlash cyan (85,255,255); alt Swing2 mode flashes Left Leg (3) / both arms (4) |
| ? | (hitbox move) | n/a | UroService.Hitbox | — | Client loops SphereHitbox r=10 at (0,-1,-3) until a knockback-able target found, then `FireServer(hits, hrpCF)` — likely dash/tackle |
| ? | Blind Rage | n/a | BlindRageService | Fly, Swing, Startup, Dash, Throw, Grab, Hit | Flies toward camera-aimed target part (client steers part 40 studs ahead of camera), grab → 2 swings → throw |
| ? | Sky Distortion | n/a | SkyDistortionService | Startup, Interp, Crunch, Hit | Throws a distorted-air projectile (180 st/s) that crunches ground rocks into itself; rocks tween home on destroy |
| ? | Thin Ice Breaker | n/a | ThinIceBreakerService | Aerial, Startup, Crack, Hit, HitEnd | Aerial mouse-aimed punch; sky "cracks" (`Utils.Uro.IceBreaker`) with timings (t1,t2); t1==0.5 = kill/finisher variant with Die sound |
| ? **(1.85)** | Turbulence | n/a | TurbulanceService (sic) | Startup, Startup2, Wave, Kick, Crush, Crush2, Hit, Finisher | Air wave then a kick, with a gore finisher. Sends arg code 7 (`airborne or Humanoid.Jump`), the only move that does; the 1.85 log calls the airborne form *Aerial Turbulence* and gives it the larger hitbox |
| Ult | Sky ult | n/a | UroService | Chat, Chat2, AirDistort, UhOh, TIB, SkyGrab, Flight | Chat: "ARE YOU THAT AFRAID?" + hand distortions; SkyGrab: `Utils.Uro.GlassPlane` welded + `Animations.Uro.ThinIceBreaker2Sky`; TIB: 8× scaled sky shatter w/ mokultMeh debris; Flight: camera-direction launch (client velocity) |

- Combat config: M1 idx 1-4, dir "Up"/"Down". `Info.Knockback` gate on hitbox targets.
- Skins/markers: none.
- Animations: `Animations.Uro.ThinIceBreaker2Sky`.
- VFX modules: CameraShaker, StaticLightning/LightningBeams (required, unused), MokouController:ArcTween (cross-character reuse of `Utils.Ryu.Launch`, `Utils.Misc.M.Awk.mokultMeh["2"/"3"]`). Utils: Uro.{Ring, AirDistort2, IceBreaker, GlassPlane, Dialogue}, Gojo.Shard.
- Sounds: Sounds.Uro.{BlindRage.*, SkyDistortion.Swing/Throw, ThinIceBreaker.Start/Die/Impact/Crack/Explode, Ultimate.Voice/Voice1/Voice2/Grab/Grab2/Break/Fly}, Ryu.{NotInvited.Dash/Swing, SecondHelping.Hit, Unsatisfied.Hit*/FinalHit2}, Locust.Flight.
- Not in dump: cooldowns, ult meter/duration, which move owns `UroService.Hitbox`.

### Yuki (Yuki Tsukumo) — Star Rage / Garuda
- Character controller: **YukiController** (`YukiService`): M1/chase/launch, `BlackHole` (client-side pull physics), `OhNo`/`OhNo2` grab with charge meter, `Buildup` (charging state, attrs `Charging`/`Charge`), `MeterVis` (stack meter w/ `Max`/`Cost`), `Debree` signal. Skills: GarudaRebound, GarudaStab, MassBreaker, RisingRage.

| Slot/key | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? | M1 / Chase / Launch | n/a | YukiService | Hit, ChaseHit, Chase, Swing, Swing2, Launch | Gojo.M1 sounds; ArmFlash magenta (255,85,255); idx 3 = Left Leg, idx 4 = Right Leg kick |
| ? | Charge (mass build) | n/a | YukiService | Buildup, MeterVis | Hold to charge attr `Charge` 0-100 while `Charging`; `Warp2` sphere visual; meter IntValue with `Max` stacks and `Cost` per use |
| ? | Garuda Rebound | n/a | GarudaReboundService | Startup, Punch, Interp, Recall, Hit, HeavyHit, Kick, Woosh, Impact, TrueFinish | Throws Garuda ball (160 st/s, `Freeze` attr pause), recalls (straight or bounce arc), kick follow-up w/ `KickWarp`; TrueFinish = gore finisher (hide target, blood, chunks) |
| ? | Garuda Stab | n/a | GarudaStabService | Startup, Swing, Stab, Trail, Hit, GarudaTrail, Whip, Whip1, Whip2, FlyBack, WhipHit, WhipHitHard | Stab + Garuda tail whip combo (SetAssets.Garuda model) |
| ? | Mass Breaker | n/a | MassBreakerService | Startup, Dash, Aerial, Hit | Mouse-aimed aerial dash punch (part attr `Aim` override) |
| ? | Rising Rage | n/a | RisingRageService | Startup, Trail, Hit, Hit2, KneeBuild, Dash, KneeHit, HeadHit | Kick combo (Hit idx 1-3), knee charge, HeadHit finisher gives victim 5s blur/ring |
| Ult? | Black Hole / grab | n/a | YukiService | BlackHole, Absorbed, OhNo, OhNo2 | BlackHole: 3.8s pull on local char within 100 studs (client physics), Absorbed fades victims; OhNo2: grab w/ `GrabOST`, charge bar shown to victim, outcome depends on `Charge>=100` |

- Combat config: Charge attribute 0-100; meter `Max`/`Cost`; sounds Yuki.Charge.{Start, Finish, End, Charge, ChargeFail}.
- Skins/markers: none. SetAssets "Garuda" (tail `segment finale.TailHolder`).
- Animations: none referenced.
- VFX modules: CameraShaker, BloodyZee (`:Blood(cf, speed, spread, spread)`). Utils: Yuki.{KickWarp, MassChargeLeg, MassCharge, MassHit, FullRisingRage, BlackHole2, Buildup, Warp2, Meter, MeterBar}, Heian.BloodSpread, Damage.{Chunk, HitGlow}, Hakari.IdleDeath.AudioVis.
- Sounds: Sounds.Yuki.{Startup, Startup2, Swing, Stab, FirstWhip, SecondWhip, WhipFlyBack, Secret, SecretSFX, Freeze, Explode, Explode2, Scream, Grab, GrabOST, Rebound.*, Mass.*, RisingRage.*, Hole.Hole, Charge.*}.
- Not in dump: charge rate, meter max, black-hole damage, gore setting source.

### Yuta (Yuta Okkotsu) — Copy / Rika
- Character controller: **YutaController** (`YutaService`): M1 in sword or fist mode (`InUlt` → fists + "MetalHit" metal arm), chase, launch, sword draw sound, awakening prep sounds (BreakChain/EquipArm/ShakeArm/PutRing), `BreakChain` physics, `Chat` (VL / VLZero voice lines), `RingEmit`. Base skills: Outburst, ResoluteSlash, Revolve, SeveringPath, Veilstep. Awake skills: Copy, ElbowRush, LoveBeam. Rika (summon) skills: RikaDownslam, RikaGrab, RikaHaymaker, RikaLaunch, RikaLoveBeam, RikaSlam, RikaThrow.

| Slot/key | Move | Cooldown | Service | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? | M1 (sword) / M1 (fist, InUlt) / Chase / Launch | n/a | YutaService | Hit, ChaseHit, AerialHit, Chase, Swing, Swing2, Launch, SwordSound | Sword: Yuta.M1.Hit1-4/Up/Down + slash VFX + CombatTrail; Fist: Gojo.M1 + MetalHit3; ArmFlash magenta |
| ? | Outburst | n/a | OutburstService | BodyBurst, Hit, SwordBurst, ProjectileExplode, Aerial, Interp, StartCharge, Slash, GroundExplode, ExplosionHit, Clash | 3-tick charge (0.6s) with meter bars, big slash / CE projectile (attr `Speed`), ground explosion scaled to size; Clash handling |
| ? | Resolute Slash | n/a | ResoluteSlashService | WarnAndTrack, Teleport, ChargeEffect, Confused, Swing, Swing2, Slash, Hit, BlackFlashWindup, BlackFlash, BlackFlashTrail, SmallThrow, FinalThrow | Teleport-behind slash; Black Flash variant with flipbook windup, red lightning, trail bolts, final throw + Bleed |
| ? | Revolve | n/a | RevolveService (+Hitbox signal) | DiveSound, Land, Spin, Impale, ImpaleFinisher | Dive attack; client-auth sphere hitbox r=8 + ground ray; impale finisher bleeds |
| ? | Severing Path | n/a | SeveringPathService | Start, Start2, Swing, PunchSwing, Hit, AirHit | 4-hit slash string (Hit idx→angle table) w/ punch |
| ? | Veilstep | n/a | VeilstepService | Sound, Sound2, Dust, SecondWind, SecondWindGrab, DiveFloorHit, SpinRing, Hit, DiveHitbox | Dash/step; Second Wind follow-up dash+grab; dive with client-reported floor impact |
| ? (Awake) | Copy | n/a | CopyService | Start, MouthSpeech, MouthGlitch, DontMove, PromptWheel | Radial wheel of copied techniques (up to 8, 2 pages) → `FireServer(name)`; Cursed Speech "Don't move" VFX; per-technique cooldown display (server time) |
| ? (Awake) | Elbow Rush | n/a | ElbowRushService | BarrageHit, BarrageSound, Dust, ElbowHit, StepSound, HeavyHit, Vanish | Vanish-teleport into elbow barrage |
| ? (Awake) | Love Beam (small) | n/a | LoveBeamService | StartSound, Track, Bubble, SmallBeam, Hit | Charged ball → small pink beam (width 2, `BeamLength`) |
| Rika | Rika Downslam | n/a | RikaDownslamService | RikaHit, RikaFloorHit, RikaGrab, StartFly, DownslamFinisher | Rika grabs, flies, slams; finisher gibs target |
| Rika | Rika Grab | n/a | RikaGrabService | GrabSound | hold loop sound |
| Rika | Rika Haymaker | n/a | RikaHaymakerService | StartSound | — |
| Rika | Rika Launch | n/a | RikaLaunchService | Feint, StartSound | feint (EnergyRipple) then launch |
| Rika | Rika Love Beam (true) | n/a | RikaLoveBeamService | ScaleTo, Charge, StartBeamSound, StartBeam, Hit, Finisher | Rika scales to 1.7, charges ball, giant beam width 30-60 (`Width` attr), `TrueLove` sound, camera FX when inside beam; Finisher vaporizes target |
| Rika | Rika Slam | n/a | RikaSlamService | StartSound, GrabLand, Ring | ring VFX indexed per swing |
| Rika | Rika Throw | n/a | RikaThrowService | TrackCamera, Sniper | camera rides thrown object; look vector streamed to server; Sniper = black-flash style hit on target |
| Awakening | Rika manifestation | n/a | YutaService | BreakChainSound, MetalArmSound, ShakeArmSound, PutRingSound, BreakChain, Chat, RingEmit | Chain break on `SetAssets.YutaSword.ChainRing`, ring glow on `SetAssets.YutaRing`, dialogue VL / VLZero (variant "Zero") |

- Combat config: sword vs fist mode via `InUlt`/`forceSword`; Swing sounds Yuta.M1.Swing1-4 / Swing4Sword; ChaseHit sword flag; Copy wheel keybinds from `ReplicatedStorage.Keybind.Combat["Skill 1-4"]`.
- Skins/markers: none. SetAssets: YutaSword (Sword.MeshPart, Sword.Blade, Sheath.Glow, ChainRing), YutaRing (Diamond.Visuals).
- Animations: none referenced directly.
- VFX modules: CameraShaker, BloodyZee, SraikoVFX (`HandleMesh`), StaticLightning (`CreateBolt`, `ThicknessFade`), LightningBeams, KeybindIcons, ListData. AssetService EditableImage + EncodingService Zstd for the Black Flash flipbook. Utils: Yuta.{SlashHit, CombatTrail, Dialogue, RingSwing, SecondWind, ElbowRush.HitParticle, RikaHandTrail.CSVfx, CopyWheel, Outburst.*, ResoluteSlash.*, Veilstep.*, LoveBeam.*}, Goku.Vanish, Nanami.BluntCut.Charge, Ryu.Slash, Hiromi.Shockwave, Gojo.{Teleport, ReversalRed.RedExplode}, Misc.Items.{Voice, Clash}.
- Sounds: Sounds.Yuta.{M1.*, MetalHit/2/3, SwordGrab, Leap, Swing, ResoluteSlash, ResoluteHit, BlackFlash.Windup/Windup2/Land/Land2/Land3, RevolveDive/RevolveLand, Veilstep*, SecondWind.*, SeveringPath.*, Outburst.*, ElbowRush.*, LoveBeam.*, Rika.*, EnergyRipple.Feint.*, CursedSpeechStart, VoiceDontMove, Ultimate.*}; Haruta.AmbushHit, Hiromi.Stab/Throw2, Hakari.Shock/Impact, Itadori.Dismantle.Explode, Misc.UI.*, Misc.Items.*.
- Not in dump: cooldowns (wheel receives them from server at prompt time), copy technique list source, Rika duration/meter, damage.

### Supplement: moves missing from the first dump (Hiromi — Final Judgement; Todo — Elbow Drop)

#### Hiromi (Awake) — Final Judgement
| Slot/key | Move | Cooldown | Service/remote | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? (awakening ult) | Final Judgement | n/a (server) | FinalJudgementService; QTE RemoteEvent passed as arg | Charge, Dash, Swing, Dodge, Miss, Parry, Hit, Grab, Charged, RealHit, Drag, QTE, QTE2, Haiyah, Feint | Charge (green flash) → forward BodyVelocity dash (client-driven, 0→65 over 1s, reset to 0 when bv attr `Swing` changes) → sword swing; Miss/Parry/Dodge outcomes; Grab → QTE mash clash (two health bars) → RealHit stab (40 blood) → Drag (sword pull) → "Haiyah" drill-impact finisher. Feint variant |

- **C→S**: inside `QTE(remote)`: correct key → `remote:FireServer(true)`; wrong key → `remote:FireServer()`; **mobile `QTE_MOBILE` button always `FireServer(true)`** (no wrong-input possibility). Client-authoritative QTE progress — spammable/automatable; flag.
- QTE keys: keyboard W/A/D; controller ButtonX/Y/B with icons Xbox `8981031512/8981031340/8981032988`, PlayStation `126768975062846/140161712330460/137275294114393`; input source from `ToolController.LastInput` ("Keyboard"/"Xbox"/"Playstation"). GUI `Utils.Hiromi.QTE` (Health.Bar1/Bar2, QTE_PC, QTE_CONSOLE, QTE_MOBILE); `QTE2(a,b)` sets Bar1 ratio (negatives → reciprocal).
- **Dash physics**: server passes the BodyVelocity; owner client sets `bv.Velocity = HRP.Look * value` every Stepped (client-owned).
- VFX: `Utils.Damage.HitGlow` (Miss, black), `Utils.Damage.BlockHit` (Parry), `Utils.Hiromi.SwordBuild.ChargeEmit` on `char.SetAssets.ExecSword` (Charged; per-emitter attr `EmitCount`), `Utils.Mahito.CrushingRushdown.DrillImpact` recolored (1,1,0.498) (Haiyah), `Utils.Itadori.CounterHit.Feint` (255,195,134) (Feint), BloodyZee blood (RealHit x40, Drag x8).
- Sounds: `Sounds.Hakari.OverLuck.Charge`, `Hiromi.Sprint`, `Hiromi.Swing`, `Hiromi.Dodges`, `Itadori.ManjiKick.Dodge`, `Misc.Block.Block1-3`, `Itadori.M1.Hit1-4`, `Gojo.LapseBlue.Grab`, `Hiromi.Execution.Flash`, `Hiromi.Stab`, `Hiromi.SwordPull`, `Misc.UI.Click`, `Misc.UI.Switch`, `Hakari.EnergySurge.Hit1`, `Hiromi.Grapple.Start`.
- Camera shakes: HeavyHit (Dash owner, Hit ≤70), LightHit (Parry ≤70), Snap (Grab ≤70, Haiyah participants), SnapOh (RealHit ≤70).
- Flash colors: Charge (85,255,127) 1s; Hit/Grab/Drag white; RealHit (1,1,0.498) 1s.
- Attributes/paths: `char.SetAssets.ExecSword`, bv attr `Swing`. No anims loaded client-side (server plays).

#### Todo (Base) — Elbow Drop
| Slot/key | Move | Cooldown | Service/remote | Effects keys | Mechanic |
|---|---|---|---|---|---|
| ? | Elbow Drop | n/a (server) | ElbowDropService | Hit, Jump, Crush, Woah, Force, SlideStart, SlideKnockback, SlideKick | Leap: `Jump(targetPart, bodyPosition)` — owner client tweens `BodyPosition.P→100000` and pins `bp.Position = target.Position - (targetLook*3 - (0,5,0))` (hover above/behind target) until bp removed; non-owners lerp the attacker HRP CFrame locally. Landing `Crush(player, pos)` VFX. Slide variant: `Force(char, bv)` locks bv to horizontal look, `Blockcast` stops at walls, `PivotTo` facing each frame; `SlideStart` dust/rushwind; `SlideKnockback(attacker, victim, lifetimeInst, duration, serverStartTime)` — all clients pivot the victim above the attacker with parabolic arc (height 4–8 by speed, +2.5), zero velocities, `D_CC` CanCollide off, until `lifetimeInst`/victim unparented; `SlideKick(attacker, victim)` finisher VFX. `Woah(c1, c2)` meme popup |

- **C→S**: none.
- Client physics: own BodyPosition/BodyVelocity driven locally; victim repositioned by `PivotTo` on every client (client-owned victim physics = trust surface, same as HandicapController Grab).
- VFX: `Utils.Misc.SmokeTrail` (dustTrail, ground-color smoke), `Utils.Itadori.CrushingBlow` (Floor Ring 10/Sparks 10/Wind2 8, color (0.333,0.667,1)), `Utils.Todo.Woah` gui with image `rbxassetid://73458769859093`, `Utils.Itadori.RushWind`, `Utils.Gojo.LapseBlue.Throw`, `Utils.Mahito.CrushingRushdown.DrillImpact`, `Utils.Itadori.Shock` x2, `FXController:DustBreak`.
- Sounds: `Sounds.Itadori.M1.Hit2`, `Itadori.Rush.RushBreak`, `Megumi.Mahoraga.Throw.Break`, `Itadori.CrushingBlow.GroundImpact`, `Todo.Boom`, `Gojo.TeleportDrag` (pitch 1.15–1.4 by speed), `Todo.SlideKick.Slide/Kick1/Kick2/WhooshKick2`, `Ryu.SecondHelping.Hit`.
- Shakes: Hit → MediumHit (3rd arg truthy) or HeavyHit; Crush/SlideKick → Snap.
- Uses `workspace:GetServerTimeNow() - startTime` to sync arc; `_G.MapParams`; `HandicapController:GetCharacterHeight`. `require(Modules.EffectUtils)` loaded but unused.

### Helper-script evidence per character (ReplicatedStorage.Utils)

| Character | Helper | Evidence |
|---|---|---|
| Choso | `Utils.Choso.Convergence.{Spin,WingKing}` | "Convergence" charges blood orbs `Blood1..4` (attr `Charge` 0–4) orbiting the character; consuming a charge sends the orb to the Right Arm (0.6s bezier) and bursts with `Utils.Choso.PiercingBlood.Start.Burst` → Piercing Blood consumes Convergence charges. `WingKing` variant (faster spin, `Smear` trail) = awakened/"Wing King" form? Also `Utils.Choso.CounterSwing.Shock` referenced by Roulette CrowMad |
| Hakari | `Utils.Hakari.IdleDeath.Scenarios.{IC_Scenario,P_Scenario}.ScenarioPlay` | Idle Death Gamble pachinko cutscene rigs with `Yuuki` humanoid; attrs `Jackpot` bool, `Speed` multiplier; miss = anim from t=7 + darken. Domain `Segment` and sounds `IdleDeath`, `ClashTravel`; clash type code `JP` |
| Nanami | `Utils.Nanami.OvertimeAura.Music.ClientMusic` | Overtime awakening has a music aura only the owner hears |
| Todo | `Utils.Todo.Awakening.Bleed` | While char attr `InUlt`, Todo bleeds from a body part (`FaceFrontAttachment`); `Utils.Todo.Clap` + `Sounds.Todo.Clap` reused for Roulette swap FX (Boogie Woogie clap) |
| Yuta | `Utils.Yuta.Rika.Client` | Rika summon: rig follows owner (lerp 7/s or `Info.SnapPosition`), directional anims F/B/L/R, becomes translucent when obstructing camera (0.7; owner 0.9) or `Invisible` attr; Effects `UltimateStart("Zero")` = "Rika Zero"/full manifestation variant vs normal Ultimate; `Break`; `StartScream` (mouth `Out` emitter, HeavyHit + sustained LightHit for owner); `Teleport`. Owner streams `Humanoid.MoveDirection` to server via `script.Remote:FireServer(dir)`. Attr `Dead` → desummon (reverse Spawn anim, scale to 0 over 0.5s). Sounds `Sounds.Yuta.Rika.*`, `Sounds.Yuta.MutualLove.VoiceCrush` |
| Gojo / Itadori(Sukuna) / Hiromi / Mahito / Megumi | Domain clash types `IV`, `MS`, `DS`, `SP`, `TCMP`(?) | See DomainController table; assets `Utils.Gojo.{InfiniteVoid.DomainTravel,LapseBlue.Throw,Twofold.Sparks}`, `Utils.Itadori.MalevolantShrine.DomainBG`, `Utils.Hiromi.GavelShard`, `Utils.Mahito.{SelfPerfection.Hand,Morph}`, `Utils.Megumi.Mahoraga.{Outfit,Rock,WorldSlash,Throw}` |
| Misc | `Utils.Misc.Crow.CrowUpd.Caw` | Crow spectator rig: `AnimControl`, `Animations.Misc.Crow`, `Sounds.Misc.Crow.Caw1..3` |

Generic HUD helpers: `Utils.MoveReveal.Handle` / `Utils.Reveal.Handle` read a character's `Moveset` folder (NumberValue per move; attrs `Key` = slot key, `LastUse`, `ReadyAt` = server-time cooldown end) → **cooldown UI is driven by server-set `ReadyAt` attributes**; player attr `Ultimate` (0–100 meter), char attr `Evade` (0–50 evasive meter).

Global player/char attributes & values seen in this slice: player `PS_Perms`, `Workshop`, `Spectate`, `MVP`, `Ultimate`; character `UltDrain`, `Moveset`, `Dead`, `Bleeding`, `InUlt`, `Evade`; `char.Info` attrs `CD`, `NoStun`, `NoRes`, `DeathKick`, `Skill`, `M1`, `Ult`, `Parkour`, `Burst`; `char.Info` children `DomainTag`, `InSkill`, `Transparent`, `SnapPosition`; `char.Moveset` folder; workspace attrs `Timer`, `Loading`, `Roulette`; `_G.Settings.{DesPHY,DesVFX,DesINT,Gore,Flash,SENS}`, `_G.MapParams`, `_G.WorkshopIcon`, `_G.MVP_PLAYING`, `_G.Crow`, `_G.Shift`. CollisionGroup `Effects`. Team `Lobby`.

Asset IDs: DrumFont 31173820, 31173799, 31173844, 31173863, 31173881, 31173898, 31173735, 31173771; PianoFont 14894840794, 14894840716, 14894840665, 14894840494, 14894840403, 14894840359, 14894840207, 14894840845, 14894840012, 14894839957, 14894839839, 14894839723, 14894839698, 14894839465, 14894839401, 14894839262, 14894839204, 14894839014, 14894838907, 14894838844, 14894838660, 14894838573, 14894838540, 14894838315, 14894838272, 14894838103, 14894838147, 14894837920, 14894837766, 14894838013, 14894837643; TrumpetFont 3036987884. (All sound samples for an in-game playable instrument system; the "Preload" folder suggests a piano/instrument feature.) No gamepass/product/place IDs found in this slice.

---

---

## 6. Core systems

### 6.1 Hitbox / client-authoritative combat pipeline

**Setup**
- `OverlapParams`: `FilterType = Include`, `FilterDescendantsInstances = { workspace.Characters }` — only parts under `workspace.Characters` are candidates.
- Debug visual: `ReplicatedStorage.Utils.Hitbox.Hitsphere` is cloned into `workspace.Effects` for 0.5s **only if its `Transparency ~= 1`** (i.e. a dev can un-hide the template to see hitboxes; exploiters can too).

**`HitboxController:SphereHitbox(char, cframeOrPos, size)`** (public, also called by other controllers per brief)
1. If `char` is non-nil: `pos = (char.HumanoidRootPart.CFrame * cframeOffset).Position` (offset is relative to HRP). If `char` is nil, second arg is treated as a world position.
2. `workspace:GetPartBoundsInRadius(pos, size / 2, params)` — **radius = size/2**, so the 3rd arg is a diameter.
3. Keep parts where `Name == "HumanoidRootPart"`, `Parent ~= char` (no self-hit), and `Parent:FindFirstChild("Humanoid")`.
4. Returns `{ characterModel, ... }` (parents of the HRPs). No dedupe needed (one HRP per char). **No checks** for: team, `Dead` attribute, iframes, blocking, LOS/walls, distance sanity, max hit count.

**Server-driven hitbox loop — `HitboxService.Hitbox` RemoteSignal**
Server fires `Hitbox(char, cframeOffset, size, remoteEvent, lifetimeObject)`:
- `char` — attacker character (must have HRP or handler returns immediately).
- `cframeOffset` — CFrame relative to attacker HRP.
- `size` — sphere diameter.
- `remoteEvent` — a per-attack `RemoteEvent` instance created by the server (its lifetime bounds the hitbox).
- `lifetimeObject` (optional) — a second instance; loop also stops when it is unparented.

Client loop: `while true do hits = SphereHitbox(char, offset, size); if #hits > 0 then remoteEvent:FireServer(hits) end; task.wait(0.025); if not remoteEvent.Parent or (lifetimeObject and not lifetimeObject.Parent) then return end end`
- Runs at ~40 Hz; fires **every tick** there are hits (no client-side "already hit" set — dedupe must be server-side).
- Hitbox follows the attacker's HRP live (recomputed each tick from current HRP CFrame).
- **CLIENT-AUTHORITATIVE HIT REPORT**: the server never verifies geometry on the client; the payload is a plain array of character Models. An exploiter can fire `remoteEvent:FireServer({anyChar})` while the remote exists. Any server-side validation (distance, cooldown, dedupe) is not in the dump.

**`ReplicatedStorage.Remotes.GetClient`** — server fires `GetClient(remote)`; client replies `remote:FireServer(workspace.CurrentCamera.CFrame)` if the remote still has a Parent. Used by the server to get the player's camera CFrame (aim direction for projectiles/dashes). Client-authoritative aim.

---

### 6.2 FXController API

Knit controller `FXController`; services `DebreeService`, `DomainService`. Every method uses `self` (call with `:`).

| Method | Args | Behaviour |
|---|---|---|
| `PlaySound(soundTemplate, parent, soundGroup, keep?)` | Sound instance, parent Instance, `SoundService.Effect/Music/Voice`, bool | Clones, sets SoundGroup, plays. If `PlayOnRemove` → destroyed immediately (fires on remove). Else auto-destroys on `Ended`/failed load unless `keep`. Returns the clone |
| `PlayParticles(inst)` | Instance | For every ParticleEmitter in inst+descendants: honors attrs `EmitDelay`, `EmitCount`, `EmitDuration` (enables for that many seconds) |
| `ResizeParticle(emitter, mult)` | ParticleEmitter, number | Scales Size NumberSequence |
| `PreloadMeshFlipbook(textureIds)` | array of texture strings | Creates a near-invisible part rigid-constrained 0.2 studs in front of camera with Texture children to force-load textures; returns part |
| `PlayMeshFlipbook(meshPart\|specialMesh, duration, frames, onDone?)` | — | Heartbeat-driven `TextureID`/`TextureId` swap |
| `Flash(char, color, fadeTime?)` | Model, Color3, number | Hit-flash: clones `Utils.Damage.HitGlow` (limb-shaped glow parts), welds each to same-named limb, scaled to `char:GetScale()`, lifetime `fadeTime or 0.15`. Skipped if Manhattan distance from camera > 200 |
| `ArmFlash(limbPart, color, duration?)` | BasePart, Color3, number | Clones `Utils.Damage.CombatTrail` (part+Trail) welded to limb, size×1.1, disables after `duration or 0.2`. ≤200 studs |
| `Notification(text, color, duration?)` | string, Color3, number(3) | UI toast from `PlayerGui.Menus.Preset.Notification` into `Menus.Notif`; yields for duration |
| `DustBreak(pos, normal, spread, count, minSize, maxSize, rayLen?)` | Vector3, Vector3, num, int, num, num, num(8) | Debris chunks (`Utils.Damage.DebreeRef`) colored from raycast hit (`_G.MapParams`), CollisionGroup `Effects`, random velocity; only if `_G.Settings.DesPHY`; ≤200 studs |
| `DustTrail(char, duration, offsetCFrame?)` | Model, num, CFrame | `Utils.Misc.SmokeTrail` follows HRP, ground-raycast colored smoke; `offset` enables `Dash.Smoke` burst (15). Returns trail part |
| `Bleed(char)` | Model | Requires `_G.Settings.Gore`; clones attachments from `Utils.Damage.Explode` onto limbs; sets char attr `Bleeding=true`; loops `BloodyZee:Blood(Torso.CFrame, 50, 180, 180)` every 0.1s until char removed |
| `Burn(char)` | Model | Charred look: parts/clothing → Color 0.1 grey, `Utils.Damage.LegBurn.Smoke` on each part, accessory textures cleared |
| `DomainMapFade(color, fadeIn, hold)` | Color3, num, num | Occluded Highlight on `workspace.Map` (fill+outline) for `hold`, fades out 0.5s |
| `DomainBurst(part)` | BasePart | `Utils.DomainBurst` sphere expands to 75 studs in 0.3s + `Attachment.Spark`; plays `Sounds.Misc.Domain.DomainOpen` |
| `ApplyCopyOutfit(srcChar, dstRig)` | Model, Model | Copies Shirt/Pants/TShirt/BodyColors/Accessories/CharacterMesh/head Mesh/face; if `srcChar.Outfit` exists clones `Utils.Megumi.Mahoraga.Mahoraga.Outfit` scaled 2/3 (minus Beard/Hat); recolors `FingersL/FingersR` |
| `WorldModelChar(char, parent)` | Model, Instance | Anchored WorldModel clone mirroring char part CFrames every Stepped (for viewport display) |
| `Domain(char, setupFn)` | Model, function(gui, displayRig) | **Domain Expansion warning banner**: clones `Utils.DomainWarn` ScreenGui, viewport with outfit copy, FOV 40; stacks up to 3 concurrent banners via attr `Order` (positions 0.5/0.3/0.7, rotations ±80/±90/±100); Panel/PanelBack open 0.625s, hold, close 0.625s. `DomainWarn` animation preloaded from `ReplicatedStorage.Animations` (any descendant named `DomainWarn`) |
| `DebreeSound(part)` | BasePart | Material-based impact sound (`Sounds.Impact.Enviroment.{Brick,Glass,Stone,Wood,Grass,Metal,Neon}Impact` random child); ≤300 studs. Material table also carries a weight (1.3 Brick … 0.2 Glass) that is unused client-side |
| `ColorSeqLerpVec(specialMesh, colorSeq, duration, mult?)` | — | PreRender lerp of `VertexColor` through a ColorSequence |
| `ColorSeqLerpc(part, colorSeq, duration, mult?)` | — | Same for `Color` |
| `Voxels` (table) | — | `Voxels[u16 id] = { part, nearCamera?, tween? }` — client cache of destruction voxels |

**Server→client signals handled in KnitStart**
- `DebreeService.Sound(x)`: `buffer` of i16 voxel ids → DebreeSound per voxel; `number` → one voxel; else a part.
- `DebreeService.Create(data, noVFX?)`: nested `data[transparencyStr][materialName]["r,g,b"] = { staticBuf, lockedBuf, physBuf }`. Static/locked records are **32 bytes**: f32 x,y,z; i16 rx,ry,rz (÷100 → degrees); f32 sx,sy,sz; u16 id. Physics records are **44 bytes** (adds i16 linear vel ×3, angular vel ×3, ÷100). Parts come from PartCache; placed via `workspace:BulkMoveTo`. Debris particle `Utils.Damage.Break` if any chunk is within 100 studs and `_G.Settings.DesVFX`. Physics voxels only spawned if first record within 150 studs; fade out after 3s.
- `DebreeService.Physics(buffer)`: **21-byte** records (f32 pos ×3, i16 rot ×3, u16 id, u8 flag). With `_G.Settings.DesINT` tweens (0.4s Quad if flag==1 else 0.2s linear overshoot lerp 1.5); otherwise BulkMoveTo.
- `DebreeService.Prop(ids)`: returns voxels to PartCache.
- `DebreeService.Domain(part)`: plays `Sounds.Misc.Domain.DomainHit` at part and its `DomainCollider`.
- `DomainService.CFix(offset)`: shifts BodyPosition/AlignPosition(OneAttachment) targets and Freecam attr `ow` by offset — used when the server relocates the player (domain teleport) so local movers don't yank them back.
- `Remotes.Message(text, click?)`: `TextChatService.TextChannels.RBXGeneral:DisplaySystemMessage(text)` + optional UI click.
- RenderStepped: **DomainFade overlay** — if camera is inside any `workspace.Domains` child with attrs `Health` and `Fade` (radius = Size.Y/2) and local char's parent folder lacks `Info.DomainTag`, `PlayerGui.DomainFade.DomainFade` is painted the domain's Color (opaque). I.e. players who are not "tagged" into a domain see a solid color wall when their camera enters it.
- Startup: preloads all `Utils.Preload` Animations onto a temp Humanoid.

---

### 6.3 DomainController (domain expansion / clash)

Only handles **`DomainService.Effects`** (no client→server calls). Domain fade/warning banner/burst live in FXController (above).

Effects keys:
- **`Clash(centerPart, domainPart, opponentDomainPart, skipIntro)`** — Domain clash cinematic.
  - Requires `domainPart.ClashFolder` (server-created folder; each child is a BoolValue-like object with attrs `Type` and `Offset`, and a `.Value` that turns false when that side loses).
  - Timer HUD: `PlayerGui.Main.Controls.Ultimate.Time` shows `domainPart:GetAttribute("Timer")` (server-driven countdown) until either domain is destroyed.
  - Clones `Utils.Misc.DomainClash.ClashBG` at center. If `not skipIntro`: enables `domainPart.DomainGround.Surround` (ShapePartial→1, 0.8s), plays `Sounds.Hakari.IdleDeath.IdleDeath`, `DomainMapFade(black, 0.25, 1)`, waits 1.25s, Snap shake.
  - Plays looping `Sounds.Misc.Domain.ClashMusic` (Music group) until clash ends (2s fade).
  - For each ClashFolder child, clones `Utils.Misc.DomainClash[Type]` oriented by `-Offset` (XZ). Per-type intro VFX (domain codes):
    | Type | Domain | Extra |
    |---|---|---|
    | `MS` | Malevolent Shrine (Sukuna/"Itadori") | `Utils.Itadori.MalevolantShrine.DomainBG.Floor` rises, Skulls, Water splash |
    | `IV` | Infinite Void (Gojo) | `Utils.Gojo.InfiniteVoid.DomainTravel.SpaceBG` + `Lines` following camera |
    | `DS` | Deadly Sentence (Hiromi Higuruma) | Saw `Blade1..N` drop loop, sounds `Sounds.Hiromi.DeadlySentence.{BladeUp,BladeFallRope,BladeFall1/2}`, GreaterMediumHit shake |
    | `JP` | Idle Death Gamble (Hakari) | Two 50-segment `Utils.Hakari.IdleDeath.Segment` trains at z=195, `Sounds.Hakari.IdleDeath.ClashTravel` |
    | `ML` | Mutual Love? / Yuta domain (`YutaDomain`, bows + props) | Bows grow, props rise as expanding radius, `Stars` emitter, bobbing |
    | `SP` | Self-Embodiment of Perfection (Mahito) | `Hands` rig anim (marker `Loop` → t=1.5), ring of `Utils.Mahito.SelfPerfection.Hand` |
    | `TCMP` | Chimera Shadow Garden? (Megumi; model with `Eye` tracking camera) | Parts fly in, Eye grows to 30 |
    | `SOB` | Sea of Branches? (`SeaOfBranch`, emitters w/ `EmitDelay`/`EmitCount`) | — |
  - Sustained LightHit shake; loop until either domain leaves workspace; sides whose folder entry `.Value` is false fade out. If own side survives and opponent's `ClashFolder` gone → SnapOh shake + (if `_G.Settings.Flash`) inverted ColorCorrection `InvertCC` 1s.
- **`Hit(char, n)`** — generic domain-attack hit: white Flash, `Sounds.Gojo.M1.Hit<n>`, `Utils.Gojo.LapseBlue.Throw` ring burst at head.
- **`Swing(char)`** — `Sounds.Misc.Swing.Fist`.
- **`Swing2(char, comboIndex, dir)`** — ArmFlash colored by `UltNames[char:GetAttribute("Moveset")][2]` (fallback white); `dir=="Down"` → Right Leg 0.4s; combo 1/4 → Right Arm; else Left Arm. (Suggests a 4-hit M1 string in domain state.)
- **`Launch(char, yOffset)`** — ring VFX; if `yOffset < 0` (slam): `Sounds.Megumi.Mahoraga.Throw.Break`, `DustBreak`, LightHit shake if <20 studs.
- **`ClashHighlight(charList, anchorObj)`** — occluded outline Highlight on each char until `anchorObj` is 3 levels deep removed.

States/attributes seen: domain parts in `workspace.Domains` with attrs `Health`, `Fade`, `Timer`, `Color`; `ClashFolder` children attrs `Type`, `Offset`; `char.Info.DomainTag` (member of a domain); `DomainCollider` child; `DomainGround.Surround`. Domain HP, sure-hit damage, cast conditions: **n/a (server)**.

---

### 6.4 ItemController (items)

No client→server calls; purely renders `ItemService.Effects`. Item pickup/usage input is elsewhere (not in this slice; possibly `CharlesController`, which is fetched but unused here).

| Effects key | Args | Item / mechanic |
|---|---|---|
| `Soda(char, sodaPart)` | Model, Part | Soda can thrown: clone flung along HRP.RightVector×20, original hidden |
| `SodaHit(char)` | Model | Flash, 20× BloodyZee blood at head, `Sounds.Misc.Items.SodaHit` + `Itadori.DivergentFist.DivergentHit`, `Utils.Gojo.Twofold.Sparks`, HeavyHit shake <60 |
| `Gunfire(gun)` | Model | Muzzle flash on `Mesh.Attachment`, `Sounds.Misc.Items.Gunfire`; Snap shake <100 unless gun attr `Roulette` and not `GoHam` (Russian-roulette pistol mode) |
| `Sniperfire(gun)` / `SniperBolt(gun)` | Model | Sniper: `Sniper.Attachment.{Flash,Bolt.Casing,Bolt.Dust}`, sounds `Sniperfire`, `Bolt` |
| `SniperAim(player, on)` | Player, bool | For local player: `Utils.Misc.Items.Crosshair` GUI, LockFirstPerson, `MouseDeltaSensitivity = 0.1*_G.Settings.SENS`, FOV 10, camera pitch locked flat; off restores FOV 70 / sens. Sounds `ScopeIn/ScopeOut` |
| `Interp(bullet)` | Part | Client-side extrapolation of projectiles in `workspace.Bullets` using attr `Speed` (BulkMoveTo along LookVector) |
| `GunBreak(char, pos)` | Model, Vector3 | 10 `Utils.Hiromi.GavelShard` dark shards, `Sounds.Misc.Items.Gunbreak`, SnapOh if self |
| `Breakball(part)` | Part | Same shard burst, `Breakball` sound (bowling ball break) |
| `BulletHit(char)` | Model | Flash, `Sounds.Mahito.Soulfire.Hit`, Twofold sparks, SnapOh if self |
| `Coin(coin)` / `CoinParry(coin)` | Model | Coin toss (`Sounds.Misc.Items.Coin`, `Coin.Shine`); parry (`Parry`, Sparks/Wind2, HeavyHit <100) — coin can parry |
| `BananaPeel(x)` / `BananaPeelSlip(x)` | Instance | Sounds only |
| `TNT(tnt)` / `TNTExplode(pos)` | Model / Vector3 | 7 flash pulses over ~3.75s then grows to 4×4×4; explosion `Utils.Misc.Items.TNTExplosion` Emit(255), `TNTExplode` sound, Snap <100 |
| `JetSwing(x)` / `JetHit(char)` | — | Sword swing sound; hit Flash + `Sounds.Megumi.Mahoraga.M1.Hit1` |
| `Explode(pos)` | Vector3 | `Utils.Misc.Items.EyeBomb` (attr `EmtiCount` [sic]), `Sounds.Misc.Items.Eye`, Snap <100 |
| `Voice(pos, mode)` | Vector3, "Plummet"\|"Blast"\|other | Megaphone/voice item: `Utils.Misc.Items.Voice`; mode sounds `Yuta.MutualLove.VoiceCrush` / `Voice3` / `Voice2` (Voice group); HeavyHit <100 |
| `VoiceHit(char, anchor)` | Model, Instance | Rainbow limb-glow jitter loop until anchor removed; self: Snap sustain + ColorCorrection if `_G.Settings.Flash`; `Utils.Misc.Items.VoiceHit` aura |
| `VoiceSwitch(item)` | Model | attr `Mode` 1/2/3 → glow red/orange/green, `VoiceSwitch` sound |
| `Wall(part)` | Part | Wall item grows; `Utils.Mahito.Morph` blobs on each Size change; `Wall` sound |
| `PlayfulSwing(char, n, dir)` / `PlayfulHit(char, n)` / `PlayfulBreak(char, toy)` / `PlayfulStuck(char)` / `PlayfulImpact(pos)` | — | "Playful Cloud"-style staff item (`PlayfulSwing.Swing<n>`, `Itadori.M1.Hit<n>` + `Hiromi.M1.Hit<n>`, `Utils.Misc.Items.BiteHit`, `Hiromi.Execution.Sever`, red shards from `toy.Core`, `Megumi.Mahoraga.Rock` ground impact w/ `Itadori.CrushingBlow.GroundImpact`) |
| `TintedGlassesOn(item, wearerChar)` | Instance, Model | Tinted Glasses: attaches `Utils.Reveal` billboard (MaxDistance 75) to every other player's HRP → wearer sees others' movesets, cooldowns, Ult/Evade bars. Cleans up when item/char removed |
| `SnowballHit(char)` / `Snowball(char, formed)` / `SnowballSpin(tool)` | — | Snowball: `Snowball.{Hit,Hit2,Form,Startup}`; spin uses `Handle.Tween` BoolValue and `Handle.Sound` |
| `Clash(char)` | Model | Item clash: yellow Flash 0.6s, `Utils.Misc.Items.Clash.Attachment` (PointLight attr `Duration`), Snap <150 |
| `BowlingHit(char)` | Model | `Hitball` sound |
| `NaginataVaultHit(char)` / `NaginataVaultSlam(char)` | Model | Naginata: 13 blood sprays; MediumHit / HeavyHit if self |
| `CrowbarSwing(char)` / `CrowbarHit(char)` | Model | `Crowbar`, `Crowbar3`, then `Crowbar2` after 0.4s; hit: `CrowbarHIt`, 20 blood, `Utils.Locust.Slam`, SnapOh <100 |

Item list inferred: Soda, Pistol (incl. Roulette mode), Sniper, Coin, Banana Peel, TNT, Jet (sword), Eye Bomb, Voice/Megaphone (3 modes), Wall, Playful (staff), Tinted Glasses, Snowball, Bowling Ball, Naginata, Crowbar. Damage/knockback/durations: **n/a (server)**.

---

### 6.5 Game modes (Roulette / Night Parade / Final Showdown)

Common: all three use a custom `Start()` method (not `KnitStart`) — presumably called by a parent `RankedController` when that mode's server is active. All use `PlayerGui.Roulette` ScreenGui, workspace attrs `Timer` (round countdown text) and `Loading` (transition hold), team `Lobby` = not in round (hides `PlayerGui.Main` HUD, shows lobby buttons), `workspace.Effects.WaitAmbience` (lobby ambience, `.Vol` NumberValue) and `workspace.Effects.Music`.

**Roulette (`RouletteService`)** — random-kit FFA/team mode.
- Flow: `Announce(title, subtitle)` (5s show, 5s fade, sound `Misc.UI.Gamemode`) → `Credits(mapName, creators)` ("By …") → `Transition(gamemodeText)` loading screen until `workspace.Loading` false → `Kit(remote, vows)` **kit pick**: `Utils.Misc.RouletteKit` GUI shows 3 "Vow" cards, each `{Title, Moveset[], Health?, Author?, Rarity (1 basic/2 rare/3 legendary), Index}`; clicking fires `remote:FireServer(vow.Index)` → round → `Result(scores)` or `ResultTeam(scores, winTeam, loseTeam, winnerTeam)`.
- Lobby buttons: `Spectate` → `RouletteService.Spectate:Fire()`; `AFK` toggle → `RouletteService.Spectate:Fire(isAfk)` (text "AFK"/"PLAYING").
- **Rewards evidence**: `scores[i] = { score, rewardsTable, playerName }`; `rewardsTable = { [reasonString] = amount }`; UI lists `"<reason> (<n>$)"`, running total shown as `math.clamp(total, 0, 50) .. "$"` → **per-match cash reward capped at 50$ (display cap; server cap unknown)**. Zero total → "NOTHING??????? (0$)" and client fires `AchievementService.Give:Fire("Poor Performance")` (**client-triggered achievement grant — exploitable trivially if server trusts it**). Top scorer gets MVP cutscene via `Modules.MVP:MVP_Play(player, player:GetAttribute("MVP") or "King of Curses")` (MVP title attribute; default "King of Curses"), else 8.5s wait; `MVP_End(handle, true)`.
- **Crow spectator**: `Crow(crowModel)` — dead/lobby players become a crow (`workspace.Effects.Crows.<PlayerName>`, `CrowUpd` RemoteEvent). Client moves the crow itself (20 studs/s, accel while holding move, `_G.Shift` toggles free-look) and fires `CrowUpd:FireServer(cframe)` each Heartbeat → **client-authoritative crow position**. Chat bubbles from crows are re-displayed on the crow head (`TextChatService.MessageReceived` while workspace attr `Roulette`). `ClapSpawn(pos)`, `CrowExplode(pos)` (`Utils.Damage.CrowExplode`, `Sounds.Misc.Crow`), `CrowMad(crow)` (flames, `Sounds.Misc.CrowMad/CrowMad2`, `Naoya.TopSpeed.SonicBoom`, Choso CounterSwing shock ring) — crows can be killed/enraged.
- `CaptureRealm(cf, char)` — "Prison Realm" capture: 10 `Utils.Misc.Items.Prison.PrisonCap` beams converge on target, `PrisonSeal` welded, target made invisible, `Megumi.Mahoraga.WorldSlash.mesh` swirl, Gojo LapseBlue rings, SnapOh <120, Todo Clap sound.
- Per-player `Vow` picks / kit contents: **n/a (server)**.

**Final Showdown (`FinalShowdownService`)** — elimination/last-stand mode.
- Same Timer/Transition UI; AFK button hidden. Local spectate system (player attr `Spectate`, `CycleLeft/CycleRight` over non-Lobby players, `Static` noise overlay, sound `Misc.UI.SpectateStart`); `Spectate` attr cleared on team change. Effects: `PipeShoot()` — `workspace.Map.Core.Pipe.Core.PipePoint.Wind` emitters + `Sounds.Misc.Pipe` at random pitch 1.4–2.0 (map hazard pipe). Win conditions/rewards: **n/a (server)**.

**Night Parade (`NightParadeService`)** — stub; only `PickVows` effect (empty). Mode appears unimplemented client-side (name suggests "Night Parade of a Hundred Demons" — Binding Vows pick). n/a.

---

### 6.6 Discord integration

- `DiscordController` is an empty Knit controller that requires `DiscordClient`.
- `DiscordClient` wraps `ReplicatedStorage.Modules.Discord.{RemoteEvents, Logger, Utils}` (a Roblox "Social SDK" style module, not in this slice). `setActivity(details, state, assets, type, party, secret)` (or a table) → `Utils.createGameActivity(tbl)` → `UpdateActivity:FireServer(activity)` where the RemoteEvent is looked up via `RemoteEvents.tryGet("UpdateActivity", 2)`.
- **No webhooks, tokens, or URLs on the client.** Data sent is a Discord Rich-Presence-style activity payload (details/state/assets/type/party/secret). `isReady()` is never set true. Whether anything calls `setActivity` is not visible in this slice (grep other controllers for `DiscordClient`/`setActivity`).

---

### 6.7 Map interactables

| Location | Behaviour | Remotes |
|---|---|---|
| `Workspace/Map/Destructible/Model/Ads` (+`Script`, `BillboardEditUI/PianoSystem`, `MoneyDestroyer5000`) | Player-editable ad billboards: ProximityPrompt on each ad opens `BillboardEditUI` TextBox; Enter/Submit sends text, `Report` button sends "Report". SurfaceGui adornee = `Screen` part | `Ads.MoneyDestroyer5000.RemoteEvent:FireServer(billboardModel, text)`; server side (`MoneyDestroyer5000`) unavailable — name implies paid (Robux) ad placement; product id not visible |
| `Workspace/Map/Core/the most blatant ad ever/Part/AL2_TP` (+`AL2_UI/LocalScript`) | Teleport pad to another experience ("AL2" — likely the developer's other game, "Anime Last Stand 2"? unconfirmed); LocalScript only animates a splash GUI (`Frame`, `Sound`, `Icon`, `Area`, `Area2`, `Star`, `Stars`) | Server `AL2_TP` script unavailable → **place ID not in dump** |
| `Workspace/Map/Destructible/Model/StationControl/Handle` | Train station PA & train hazard: prompts `ButtonAir.Button` (`Mic_Air:FireServer()` → server broadcasts 1=JingleAir, 2=JingleOff, else Train sound) and `ButtonTrain.Button` (`Train:FireServer()` → server broadcasts `Train` → client spawns `Utils.Misc.Train` moving 1200 studs in 3s; DebugController adds distance-based camera shake Snap<150 / HeavyHit<300 / LightHit>300 w/ LOS check). Voice mic: `Mic.Head.Wire → AudioFader`, speakers ← `Mic.AudioEqualizer`; EQ muffled unless camera has LOS to a `Speaker` within 300 studs. Prompt `Button.Enabled = not Status.Enabled` (server cooldown indicator) | `Handle.Mic_Air`, `Handle.Train` RemoteEvents (children of the Handle script) |
| `Workspace/Map/Destructible/Model/Courtroom/Court/Handle` | Courtroom voice-chat: any non-`Mic*` seat child with a `Head` gets `Audio.<SeatName>Wire.SourceInstance = Head.AudioListener`; `Speaker1/2/<SeatName>.Wire ← Audio.AudioReverb` | none |
| `Workspace/Map/Destructible/Model/Talk/Talkshow/Handle` | Talk-show stage mic: `Mic.Head.AudioListener → Audio.Wire`; `Speaker1/2 ← Audio.AudioReverb` | none |
| `Workspace/Effects/Blood/PoolActor/Blood` | Parallel-Lua actor placing blood pool decals on Map/Domains surfaces (attrs `RT`, `CF`; `Ref` ObjectValue) | Actor message `Ray` |

Map is destructible (`workspace.Map.Destructible`, voxel system in FXController via `DebreeService`); `workspace.Map.Data` holds the PartCache pool; `_G.MapParams` is the shared RaycastParams for map geometry.

---

### 6.8 Playable-instrument sound fonts (Utils/Preload/SoundFont)

Piano sample ids: 14894840794, 14894840716, 14894840665, 14894840494, 14894840403, 14894840359, 14894840207, 14894840845, 14894840012, 14894839957, 14894839839, 14894839723, 14894839698, 14894839465, 14894839401, 14894839262, 14894839204, 14894839014, 14894838907, 14894838844, 14894838660, 14894838573, 14894838540, 14894838315, 14894838272, 14894838103, 14894838147, 14894837920, 14894837766, 14894838013, 14894837643 (pitch step 1.059463^n). Drum: 31173820, 31173799, 31173844, 31173863, 31173881, 31173898, 31173735, 31173771. Trumpet: 3036987884. `SoundCache` pools 50 Sounds; `Tween` is a TweenService wrapper. The map "Ads" billboard editor is misnamed `PianoSystem`.

### 6.9 Input & skill-activation pipeline (ToolController, BeamController, EmoteController, JoinController, KeybindIcons)

#### 2.1 Input source
`ReplicatedStorage.Keybind.Combat.<Action>` objects each expose `.Pressed` / `.Released` signals and per-platform children `Keyboard` / `Gamepad` / `Mobile` with a `.KeyCode` (EnumItem). Actions referenced: `Melee`, `Block`, `Special`, `Awaken`, `Drop Item`, `Shift Lock`, `Lock On`, `Dash` (KeybindIcons only; handled by MovementController), `Emote` (EmoteController), `Skill 1`..`Skill 9` (single digit parsed from char 7 of the name; ToolController iterates all children whose name starts with `"Skill "`). Default keycodes are **not** in these files (the Keybind module/loader is not in this slice). Player attr `Adjusting_Keybinds` suppresses Emote toggle → a rebind UI exists.

Platform: `GetPlatform(UserInputService.PreferredInput)` → `"Mobile" | "Playstation" (ButtonB string == "ButtonCircle") | "Xbox" | "Keyboard"`; stored in `ToolController.LastInput`, re-evaluated on `PreferredInput` change (leaving gamepad clears `MovementController.LockOn`). GUI elements tagged (CollectionService) `Keyboard`/`Playstation`/`Xbox`/`Mobile` are shown only for the active platform; `KeybindIcons:updateAll()` refreshes icons.

#### 2.2 Slots / hotbar
- Moves live as **NumberValue** instances under `char.Moveset` (created server-side). Attributes read: `Key` (slot number 1–9 = which `Skill N` bind fires it; also hotbar `LayoutOrder` and key label), `Service` (Knit service name, e.g. `"GojoService"`), `Tag` (display name override), `Tip` (sub-text), `AWK` (base-kit move hidden/unusable while `char.InUlt`), `AWK2` (awakening-only move, usable only while `InUlt`), `LastUse`, `ReadyAt`, `SkipTo`, `Paused`, `Seal` (Reggie 1/2/3), `USE` (on a value named `Custom`: auto-fires `UseTool(Activated)` every 0.5 s while set).
- `ReturnKey(slot)` = first **direct child** of `char.Moveset` with `Key == slot` AND `Service` set AND `not (AWK and InUlt)` AND `(not AWK2 or InUlt)`. So awakening remaps slots by having two values share a `Key` (one `AWK`, one `AWK2`); ListData order is irrelevant on the client — order = `GetChildren()` order, first match wins.
- Hotbar: `PlayerGui.Main.Preset.Item` cloned into `Main.Controls.Moveset`, one per NumberValue **descendant** (nested ones exist but are hidden because `Parent.Name ~= "Moveset"`), frames with attr `FakeMove` are ignored. Clicking `ItemName` fires `UseKey(Key,"Activated")` on down / `"Deactivated"` on up.
- Three activation modes for `Skill N`:
  1. `CopyController.SelectRemote` truthy → `CopyController:SelectWheel(N)` (copy-selection wheel, presumably Yuta "Copy"); nothing else fires.
  2. `_G.Settings.AutoUse == true` → press = `UseKey(N,"Activated")`, release = `UseKey(N,"Deactivated")`.
  3. AutoUse false → press toggles `Selected.Value` (ObjectValue exposed as `ToolController.Selected`, outline on hotbar frame). Then **Melee** fires the selected move: `Activated` on M1 down, `Deactivated` on M1 up.
- Mobile: `PlayerGui.Controls.Mobile.Jump.{Melee,Block,Special,Dash}` + `ShiftLock.Lock`; `Dash` → `MovementController:DashRequest()`; ult bar `Controls.Ultimate.Bar.Touch` → Ultimate/Deultimate. Layout editor (Icon topbar img `15117261700`, "Lock Layout"/"Reset Layout"): drag/pinch buttons (size clamp 0.5–2), saved via `JoinService.MobileLayout:Fire({Block={X,Y,S},Dash=…,Melee=…,Special=…,Lock=…})`; server replays it via `JoinService.MobileLayout` (also accepts legacy flat 8-number array). Mobile pad hidden while any `Menus.Group` frame is visible or `PlayerGui.BuildTools` exists.
- Gamepad: same Keybind actions via `Gamepad` child; `Lock On` toggles `MovementController.LockOn = GetTarget()` (client-side camera lock only, no remote).

#### 2.3 Key → remote map (all `Service.X:Fire(...)` = Knit RemoteSignal C→S unless noted)

| Input | Pre-checks (client) | Remote & decoded args | Client-supplied values trusted? |
|---|---|---|---|
| Skill N (Activated) | `ReturnKey` filter only; **no cooldown / stun / state check** | `<Service attr>.Activated:Fire(moveValueInstance, extra)`; `extra` by move-name table (§2.4) or `ExtraData[name]()` | Yes: move instance chosen by client; `extra` = airborne bool, target char, aim Vector3, move vector, InDash/InRoll bools — all client-computed |
| Skill N (Deactivated) | none | `<Service>.Deactivated:Fire(moveValueInstance, extra)`; before firing, calls `<Prefix>Controller.ToolDeactivate(char)` (Prefix = Service name minus trailing 7 chars `"Service"`) and sends its return as `extra` | Yes |
| M1 (Melee) hold | `_G.Crow` alive → `_G.Crow:FireServer(true)` (MeiMei crow control remote) and return; ends emote via `EmoteService.EmoteEnd:Fire()`; throwable check | loop every **0.025 s** while held: item with `M1` child → `ItemService.M1:Fire("Down"|"Up"|nil, target)`; `Info.DomainClash` → `DomainService.Activated:Fire(dir)`; `char.CustomM1` → `CustomService.Melee:Fire(Custom())`; else `<Moveset>Service.Activated:Fire(dir, GetTarget())` (dir: `"Down"` if FloorMaterial==Air, `"Up"` if Humanoid.Jump, else nil; Hanami order swapped) | Yes: dir strings + target. 40 Hz spam relies on server rate-limit |
| Throwable (inside Melee) | `Info.NoThrowable` absent; nearest `Map.Destructible.Throwable` model within `4*scale` studs of HRP+3 forward, not attr `B`/`Hold`; or held `Info.Throwable` ObjectValue not `Stored` | `MovementService.Throwable:Fire(model)` | Yes: client picks which model |
| M2 (Special) | none | item with `M2` → `ItemService.M2:Fire()`; `CustomChar.CustomSpecial` → `CustomService.Special:Fire(Custom())`; Todo → `RightActivated(GetTargetOrProjectile())`; Naoya/Hanami → `RightActivated(GetMouseTarget(75), GetTarget())`; MeiMei → `RightActivated(moveVector)`; default → `RightActivated(GetTarget())`; release → `RightDeactivated()` | Yes |
| Block | ends emote (blocked if `_G.UsingPiano == 2`) | `BlockService.Activated:Fire(GetTarget())`; release → `BlockService.Deactivated:Fire()` | target only |
| Awaken / Ult | none | `CustomChar.CustomUltData` → `CustomService.Awaken:Fire(Custom())`; char attr `Enchain` → `ItadoriService.UltimateEnchain:Fire()`; else `<Moveset>Service.Ultimate:Fire()`; release → `<Moveset>Service.Deultimate:Fire()` | no args |
| Drop Item | none | `ItemService.Drop:Fire()` | — |
| Shift Lock | — | local: `_G.Shift` toggle, `UpdateShift()` (crosshair, mouse icon `rbxasset://textures/collapsibleArrowDown.png`, `RotationType`, `MouseBehavior`) | — |
| Lock On | — | local only (`MovementController.LockOn`) | — |
| Emote | `_G.UsingPiano ~= 2`, not `Adjusting_Keybinds` | `EmoteService.Emote:Fire(slotNumber)` (wheel) or `:Fire(emoteNameString)` (search list, frame name); jump → `EmoteService.EmoteEnd:Fire()` unless `Info.EmoteCanJump` | slot/name only |
| Dash / sprint / chase / parkour / burst-evasive / taunt | **not in these files** (MovementController; mobile Dash calls `MovementController:DashRequest()`) | — | — |

`ExtraData.Custom()` = `{isAir(FloorMaterial==Air), GetTarget(), ControlModule:GetMoveVector(), Humanoid.Jump}`.

#### 2.4 Per-move extra-arg codes (`v_u_25`, keyed by move **name**)
| Code | Payload sent as 2nd arg | Moves |
|---|---|---|
| 1 | `isAirborne` = FloorMaterial==Air AND no ground within `HandicapController:GetCharacterHeight(char)+1` below (raycast w/ `_G.MapParams`) | Cursed Strikes, Crushing Blow, Dismantle, Reversal Red MAX, Lapse Blue MAX, Hollow Purple, Rough Energy, Stockpile, Flowing Red Scale, Slicing Exorcism, Kamehameha, Ki Spam, Staff Extend, Execution, Mass Breaker, Shut Up!, Veilstep, Revolve, Outburst, Second Wind, Rika Launch, Blunt Cut, Collapse, Sharpen, Ambush, Impetus Updraft, Circling, Murmurate, Root Swarm, Surging Thorns, Defense Response, Root Rampage, Granite Blast, "What are you after?", Detach, Roach Swarm, Sky Distortion |
| 2 | `GetTarget()` (character model or nil) | Lapse Blue, Shutter Doors, Rabbit Escape, Nue, Toad, Divine Dog: Totality, Mahoraga, Takedown, Body Disfigure, Face Blitz, Crushing Rushdown, Judgement's Reach, Grapple, Garuda Rebound, Resolute Slash OLD, Authentic Mutual Love, Puppet Barrage, Pigeon Viola, Technique Charge, Decisive Strike, Tendril Grab, Flower Field, Second Helping, Blind Rage, Thin Ice Breaker |
| 3 | `GetMouseTarget(75)` (Vector3 aim point) | Piano Drop |
| 4 | `ControlModule:GetMoveVector()` | Severing Path, Severance Kick |
| 5 | `{isAirborne, GetTarget(), GetMouseTarget(75), moveVector}` | Resolute Slash, Copy, Bird Control, Tracking Roots |
| 6 | `{isAirborne, Info.InDash exists, Info.InRoll exists}` | Swift Kick |
| (none) | `false` → falls back to `ExtraData[name]()` if present (only `Custom`) | everything else |

If a code-1 airborne bool is used server-side to pick aerial variants, a cheat can spoof it (client-computed).

#### 2.5 Public API consumed by other controllers
| Member | Returns |
|---|---|
| `LastInput` | `"Keyboard" | "Xbox" | "Playstation" | "Mobile"` |
| `Selected` | ObjectValue; `.Value` = currently selected move NumberValue (non-AutoUse mode) |
| `ShowReady` | bool override forcing ult "Ready" label |
| `ExtraData` | table `{Custom = fn}` |
| `GetPlatform(preferredInputEnum)` | platform string |
| `GetMouseTarget(range?, ignoreAllChars?)` | **Vector3**. range default 300 (600 if Moveset Hanami). Mobile or flag: ray from camera pos (+1 up) along camera LookVector; else ray from camera toward `mouse.Hit`. Filter excludes own char (or all `workspace.Characters` if flag), `workspace.Effects`, `workspace.Logic`. Returns hit position or ray endpoint. |
| `GetTarget(range_ignored)` | **character Model or nil**: among `workspace.Characters` children with `Info` + Humanoid + HRP, excluding self, `HarutaSwordNPC`, and `HitboxNPC`s whose `Owner.Value == self`; within moveset range from **camera** position (Chaos 1000, Haruta 350, Mechamaru 300, Chara 60, Hanami 300, default 100 studs); picks closest to cursor (`mouse.X/Y`) or mobile crosshair (`PlayerGui.Controls.Crosshair.AbsolutePosition`) in screen space within `ViewportSize.Y/5` px. |
| `GetTargetOrProjectile()` | Model: same screen-space pick (100 studs, any candidate's parent) over characters' HRPs + `Map.Destructible.Throwable` models (PrimaryPart without Weld) + CollectionService tag `CanBoogieWoogie` PrimaryParts. |
| `GetToolService(name)` | cached `Knit.GetService(name)` |
| `UseSetService(method, ...)` | fires `<Moveset>Service[method]` (with Ultimate special-cases) |
| `ReturnKey(slot)`, `UseTool(value, "Activated"/"Deactivated")`, `UseKey(slot, mode)`, `Melee()`, `Special()`, `ReleaseSpecial()`, `Block()`, `UpdateShift()` | as above |

#### 2.6 Cooldown / meter display (all server-driven via attributes; **no client gating**)
- Skill: on `LastUse` change, loop: `fill = clamp(((SkipTo or ReadyAt) - GetServerTimeNow()) / (ReadyAt - now_at_start), 0, 1)`; `Paused` attr freezes; `SkipTo` shortens; ends when time reached, value/frame gone, or `char.Info` attr `CD` set (global cooldown reset); flash white → RGB(31,31,31). Uses `workspace:GetServerTimeNow()` — `ReadyAt` is a server clock timestamp. No `Cooldown` attribute is read.
- M2: char attrs `LastM2` (server time) and `M2_CD` (seconds) → `Controls.Ultimate.Special.Fill` size; aborts on `Info.CD`.
- Ult bar: player attr `Ultimate` (0–100) → `Controls.Ultimate.Bar.Fill`; char attr `Ult2` (second meter, rainbow `Fill2`); `Ready` visible if `not InUlt and not Info:GetAttribute("Ult") and Ultimate>=100` with overrides: Yuki needs `Dead` and not `LastResort`; Haruta needs `Sword == nil`; MeiMei ready if `Info.ControlRemote` attr `Active`; Reggie ready when `InUlt`; Uro ready if `(InUlt and Ultimate>=100) or Ult2==100`. Reaching 100 (from <100, not InUlt) spawns white Highlight + PointLight flash. `UltNames[moveset] = {title, fillColor, gradientColor, showReadyText, customImageId}`; char attrs `CustomUlt` (title) / `CustomUltC` (`"r,g,b r,g,b"` gradient string) override. HUD (Title/Bar/Evade/Special/Moveset, `Miracles` gui) slides off when player attr `UI == false` or `Info.DomainClash` exists.
- Reggie `Seal` attr 1/2/3 → `Utils.Reggie.ReggieSeal` stamp overlay (red / RGB(255,200,0) / white+gradient), sound `Sounds.Reggie.Stamp`.

#### 2.7 Anti-cheat-ish / state reads
- No client-side anti-cheat in ToolController. Only gates: character+`Info` exist, `ReturnKey` filter, `Selected` cleared when hotbar frame hidden.
- `Melee()` M1 loop 40 Hz; custom `USE` auto-loop 2 Hz — server must throttle.
- Attributes read: char `Moveset`, `InUlt`, `Enchain`, `Ult2`, `Dead`, `LastResort`, `Sword`, `LastM2`, `M2_CD`, `CustomUlt`, `CustomUltC`, `HitboxNPC` (+`Owner` ObjectValue); `CustomChar` child attrs `CustomUltData`, `CustomSpecial`; `Info` attrs `Ult`, `CD`; `Info` children `InDash`, `InRoll`, `Emote`, `Item` (+`M1`/`M2` children), `DomainClash`, `Throwable` (ObjectValue, attr `Stored`), `NoThrowable`, `ControlRemote` (attr `Active`); player attrs `Ultimate`, `UI`; throwable attrs `B`, `Hold`. `_G`: `Settings.AutoUse`, `Shift`, `Crow` (RemoteEvent under `workspace.Effects.Crows`), `UsingPiano`, `MapParams`. Tags: `Keyboard`, `Playstation`, `Xbox`, `Mobile`, `CanBoogieWoogie`.
- On character load: camera FOV 70, `CameraMaxZoomDistance 30`, preloads all Animations under `Animations[Moveset]` (Mokou → `Animations.Misc.M`, Chara → `Animations.Misc.C`) and `Animations.Misc.Hits`.

#### 2.8 BeamController — beam clash QTE
`BeamService.Effects("ClashQTE", qteRemote, beamPartA, beamPartB)`: clones `Utils.Misc.BeamQTE` GUI; bars coloured from `BeamColor` attrs; bar ratio from `Weight` attrs (w<0 → 1/|w|, 0 → 1). Prompt key chosen **locally at random**: keyboard W/A/D; gamepad ButtonX/Y/B (Xbox imgs `8981031512/8981031340/8981032988`, PS `126768975062846/140161712330460/137275294114393`); mobile: button at random position. Correct key or mobile tap → `qteRemote:FireServer(true)`; wrong key (any of the 6 listed) → `qteRemote:FireServer()`. Runs until `qteRemote` is destroyed. **Client-authoritative**: server never knows which key was expected, so a cheat can spam `FireServer(true)`; only server-side rate limit could bound it.

#### 2.9 EmoteController
Wheel `PlayerGui.Emotes.Emote` (Page1 = slots 1–8, Page2 = 9–16, `Switch` button), preview rigs from `Emotes.Preset.Rig` in ViewportFrames (camera FOV 17, 30 studs back), anims looped with `Loop` marker rewind. `Equip(slot, name, animId, tip)` S→C fills slot + `Menus.Group.Inventory.Items.Emotes.Equipped[slot]` text (page-relative) and `EmoteCache[slot] = name`. Search box filters `Inventory.Items.Emotes.List` frames by name → `Emote:Fire(frameName)`. Gamepass attrs on `player.Gamepasses`: `742180133` → slots 5–8, 13–16 visible; `1151174294` → page switch + search. `Effects` dispatched to `script.Effects` module (missing from dump).

#### 2.10 JoinController
- **Character select**: topbar Icon "Characters" (img `7992557358`, initially disabled) dropdown → `JoinService.Change:Fire(key)`. Labels→keys: Honored One→Gojo, Vessel→Itadori, Restless Gambler→Hakari, Ten Shadows→Megumi, Perfection→Mahito, Blood Manipulator→Choso, Switcher→Todo, Defense Attorney→Hiromi, Cursed Partners→Yuta, Puppet Master→Mechamaru, Head of the Hei→Naoya, Salaryman→Nanami, Disaster Plants→Hanami, True Cannon→Ryu, Register→Reggie; grey "base" style: Locust Guy→Locust, Star Rage→Yuki, Aspiring Mangaka→Charles, Lucky Coward→Haruta, Crow Charmer→MeiMei, Black Death→Kurourushi, Sky Assassin→Uro. Conditional (orange): Strongest Of History→Heian if `workspace.AllowOP`; Mokou (img `129398506853336`) if player attr `Mokou`; Monkey Kid→Goku (img `79537216753706`) if player attr `Goku` or `AllowOP`. Custom chars: `workspace.LogicData.CustomChar` ObjectValues → attrs `MoveNameFt`, `IMG`, `Flip` (enabled flag); `Change:Fire(MoveNameFt)` (blue label).
- **Menus** (`PlayerGui.Menus.Group.*`, fade-in once all children have attr `Loaded`): Shop (img `9405933217`, label `$Cash`), Settings `5480743826`, Inventory `6870729295`, Achievements `11829454151`, Logs `11214451393` (fires `Remotes.UpdateLog:FireServer(UpdateLogController.Ver)` once; `UpdateLog.OnClientEvent(ver)` ≠ local Ver → notify badge; also `UpdateLog:FireServer()` with no arg at start), chat-voice dropdown `14809805905` (entries from `Modules.RobloxChatVoice` `{[id]={Name,Sound,Volume}}` → `JoinService.Talk:Fire(id)`; S→C `Talk(char,id)` plays sound at HRP via `Sounds.Impact.Players.Death` clone, SoundGroup `Taunt`, billboard `Utils.Voice`), Rules `71437429504293` (forced open until player attr `LastRulesAccepted == Modules.Rules.Version`), Ranked `2599458148`, Private `401280105` (player attrs `PS_Owner`/`PS_Perms`), Cmdr `95498291180289` (player attr `Cmdr`, touch only; `CmdrClient:Show()`), Tutorial_Info (`_G.TutorialIcon`), Workshop `10626050757` (player attr `Workshop`, `_G.WorkshopIcon`). Shop/Inventory/Ranked disabled when `workspace.Match` attr set. VoiceChat availability → `IconController.voiceChatEnabled`. CoreGui Backpack & EmotesMenu disabled. Reset button → `JoinService.Reset:Fire()`; S→C `Reset(title,text)` → SendNotification. Chat: `TextChatService.OnIncomingMessage` prefixes `[Title]` from player attr `Title`; `Title=="?"` → black `[ ? ] ?:` prefix (anonymised).
- **`lastRecvServer` = custom position replication/interp**: every `Stepped` the client sends `AntiCheatService.Camera:Fire(buf9, buf15, char, NaN)` — buf9 = camera X/Y/Z as 24-bit ints (no scaling, negatives +2^24), buf15 = HRP CFrame (pos×100 as 24-bit, XYZ euler ×1000 as i16). Server rebroadcasts `AntiCheatService.Camera({[playerName] = buf15 | bool})`; client stores `lastRecvServer[char] = {targetCF, currentCF(HRP.CFrame*MO), tick()}` and on `RenderStepped` for **other** players lerps HRP from current→target over 0.05 s (snaps if >15 studs), sets `HRP.Velocity` (zeroed if >50 st/s) and `HRP.CFrame`; if `GrabWeld` with non-HRP Part0 exists, stores offset in HRP attr `MO` instead. `false`/ragdoll (`Ragdoll` attr >0)/`Humanoid.Sit` → reset `RootJoint.C0` and clear `MO`. So other players' root positions are driven by this 15-byte stream, not native replication; own HRP CFrame is **client-reported** (the "AntiCheat" service presumably validates it server-side — not visible). `Teleport(char, buf, token)` S→C: own char → echo `Teleport:Fire(token)` (ack, teleport applied by server?); others → `PivotTo` + reset entry.
- Not present: TeleportService, place ids, DataStore/data sync (only attributes `Cash`, `LastRulesAccepted`, `leaderstats` waited on).

#### 2.11 KeybindIcons
`KeybindImages` (A–Z, One–Zero, punctuation, F1–F12, arrows, mouse buttons, Xbox ButtonA/B/X/Y, DPad, L1/L2/L3/R1/R2/R3), `KeybindPSImages` (PS glyphs for the same gamepad codes), `KeybindNames` (One→"1"… Zero→"0", ButtonL1→LB, L2→LT, R1→RB, R2→RT), `KeybindPSNames` (L1/L2/R1/R2). `updateKeyText(keyFrame, bindObj)`: picks child `Keyboard`/`Gamepad`/`Mobile` by `ToolController.LastInput` (Xbox/Playstation → `Gamepad`); precedence PS name → generic name → PS image → image → `UIS:GetImageForKeyCode` → raw KeyCode name. `updateAll()` refreshes `PlayerGui.Controls.Gamepad.{Block,Dash,LockOn,Melee,ShiftLock,Special}` and every hotbar frame's `Key` via `Skill <Key>`. No default keycodes defined here.

### 6.10 MovementController (sprint / dash / chase / parkour / ragdoll / camera lock)

**Init**: `KnitInit` → MovementService, ItemService, AchievementService, ToolController, HandicapController, FXController. `KnitStart` runs `Tilt()` on every `workspace.Characters` child (existing + ChildAdded). Globals set: `_G.Shift=false`, `_G.MapParams` (Include: workspace.Map, Domains, Spawns). Keybind source: `ReplicatedStorage.Keybind.Combat.Dash.Pressed`.

#### Dash / Chase / Escape (`DashRequest`, `Dash`)
| Aspect | Detail |
|---|---|
| Direction | From camera-flattened look vs `Humanoid.MoveDirection`: Front/Back/Left/Right (default Front) |
| Escape path | If `Info.Knockback` exists OR (char attr `Burst` and not `Info` attr `Burst`) OR `Info.ForceEsc.Value` → `MovementService.Dash:Fire(dir, true)` and return (server does the escape; client renders via Effects "Escape") |
| Blocks (client-side, bypassable) | `Info.Block`, `Info.Stun`, char attr `Ragdoll>0`, `Info.InSkill.Value==false` without `Info.AllowDashInSkill`, `Info.NoDash`, `Info.NoSprint.Value==false` without attr `AllowDash` (side/back dash). Skipped when `CustomChar` attr `CustomChase` and dir==Front |
| Front dash = Chase | Not for Moveset "Naoya" / `Info.DomainClash` / flank case. Local gate 0.4s since last dash. `Info.Item` with child `Dash` → `ItemService.Dash:Fire()`; CustomChar → `CustomService.Chase:Fire(ToolController.ExtraData.Custom())`; else `ToolController:UseSetService("Chase", FloorMaterial==Air)` |
| Flank check | If `Info.DisableChase`: `ToolController:GetTarget(200)`; if target not ragdolled/stunned and we're behind-ish (dot look >-0.2, dot velocity >0.2) → treat as side dash w/ short CD |
| Side/back dash CD (local) | Normal: 2s (`tick()-last>=2`). Naoya / DomainClash / flank: 0.45s (0.3s DC/flank), 2 charges (`v_u_116`) refilled after 2s (1s in DomainClash); flank dash doesn't consume charge |
| Fire | `MovementService.Dash:Fire(dir)` then local `self:Dash(LocalPlayer, char, dir)` immediately (no server ack) |
| Local physics | `HandicapController:ClearForce(Torso)`, `ClearForce(HRP)`; **client creates `Info.InDash` BoolValue** (0.4s); `BodyVelocity "MovementForce"` in Torso, MaxForce (40000,0,40000), P 400000, Debris 0.4s; `HandicapController:Swing(HRP, bv, 0.4, dirVec*200*Info.DashMultiplier)` then re-tweens magnitude to `16*mult` (Circular Out 0.4s). RenderStepped faces HRP to camera look (unless AutoRotate false / first person). `Stun` attr change → zero velocity, destroy bv, stop anim |
| Camera/VFX/SFX | FOV tween → 70 (0.5s); `FXController:DustTrail(char, 0.4, rotCF)`; sound `Sounds.Misc.Dash`; anim `Animations.Misc.Movement["Dash"..dir]` speed 1.8 (Back 0.8), priority Movement |
| Server→client | `Effects("Dash")` args `(player, "Dash", char, dir)` → runs `Dash()` for all clients (only owner does physics). `ResetDash` → `last = tick()-2` (server can refund CD) |

#### Sprint
| Aspect | Detail |
|---|---|
| Trigger | Double-tap W within 0.2s → `char:SetAttribute("Sprint", true)` (client-set attr, local only); W release clears. `_G.Settings.AutoRun` → auto Sprint when moving forward (dot>0.5). `Info.NoSprint` clears it; `NoSprint` attr `S` overrides WalkSpeed |
| Speed | Base `StarterPlayer.CharacterWalkSpeed - hpPenalty` (penalty = (1-hp%)*3); Sprint = `CharacterWalkSpeed*1.375 - penalty`; Stun count>0 → 0.1 / JumpPower 0; Block>0 → 4 (backwards) or 6, JumpPower 0; `NoJump` count → 0. Multipliers: Humanoid attrs `Speed`, `Speed2`, `Jump`; Player attr `Spectate` → 0/0; char attr `Movement` → JumpPower 0 |
| Set locally every Stepped | `Humanoid.WalkSpeed`, `Humanoid.JumpPower`, **`HRP.Anchored=false`** (client un-anchors every frame). Client-authoritative speed — a cheat can set any WalkSpeed; no server value seen |
| Info counters | `Stun`, `NoJump`, `Block`, `Emote`, `NoLock` — counts of same-named children of `Info` (ChildAdded/Removed) |

#### Parkour (`Parkour(char, hrp, hum)`) — 100% client-decided, called each Stepped while Sprint and not `Movement`
| Move | Condition (raycasts vs workspace.Map, scaled by `char:GetScale()`) | Force (`HandicapController:MovementForce(char, startVel, endVel, dur)`) | Anim IDs |
|---|---|---|---|
| Slide | Running; wall 3.5 ahead at chest but gap at -2.5 and clear beyond 6 | `look*35 - up*80 → look*28`, 0.3s; HipHeight -2 for 0.35s | 98500512116998 |
| Dive | Running; wall at +1.5 & -2.5 and also at +4 | `look*35 + (0,30,0) → look*28`, 0.3s; HipHeight -2 0.4s | 98195977533316, 85222050280022 |
| Vault | Running; low obstacle (dist diff > -2*scale) | `look*24 + up*40 → look*24`, 0.3s | 125187993473697, 95602001882956, 107860751460547, 79201532345509 |
| Climb (ledge) | Freefall; nothing 4 above, ledge surface found ahead | `up*40 → up*10 + look*12`, 0.3s | 104763108763761 |
| Wall bounce L/R | Freefall; strafe input, Jump held, wall 3 to side; count < max (3; Goku 4; DomainClash 1; -1 if HP<66%, -2 if <33%); reset when grounded | `vel + right*(±50) → up*20 - right*(±40) + look*30`, 0.4s | R 94327920127463, L 113609963676386 |

All: `ClearForce(Torso)`, `char:SetAttribute("Movement", true)` (0.3–0.4s), sound `Sounds.Misc.Parkour.Parkour` (pitch 0.9–1.1), **`MovementService.Parkour:Fire()` (no args)** — server only replicates sound (`Effects("Parkour", _, char, isRoll)` plays Parkour or Roll). Gates: `Info` attr `Parkour`, `Info.NoParkour`. Anim template `Animations.Misc.Movement.Parkour` (AnimationId swapped per move).

#### Other client physics
- **Ragdoll steering**: when char attr `Ragdoll>0`, each Stepped adds `MoveDirection * |vel|*1.3*factor*dt` to `HRP.Velocity` and adds RotVelocity from `PlayerModule:GetControls():GetMoveVector()` (X→camera Look*60*dt, Z→Right*60*dt). Client steers its own ragdoll.
- **Tilt(char)** (public API, per character incl. others): skip if attr `NoProcess`. Local char only: `SetStateEnabled(FallingDown,false)`, `(Dead,false)`; preload parkour anims; `Ragdoll>0` & not `NoRagdoll` → `ChangeState(Physics)`, else `GettingUp` on change. All chars: accessory `Handle` moved into a Folder (kills accessory physics); RootJoint C1 lean from local velocity (clamp ±6°) + RotVelocity.Y roll, lerp 6*dt; ragdoll limb collision SFX (`_G.Settings.RagSFX`, `Sounds.Impact.Players.Ragdoll_Collision.Hit1-8`, ≤300 studs, 0.075s throttle); footsteps via leg raycast, material→sound table (below), Water → `Utils.Water` splash (Ring 3, Splash 7) + `Sounds.Misc.Footstep.Water`; attrs `Makora`/`UltMecha` → vol 3, slower pitch, `CameraShaker Presets.LightHit` within 30 studs.
- **Evade/Burst HUD**: `PlayerGui.Main.Controls.Ultimate.Evade.Fill` size = char attr `Evade`/50. Burst state (attr `Burst` and not `Info` attr `Burst`) → white bar, `Utils.Damage.BurstIcon.BurstIcon` on HRP, Highlight (white, 0.95), sound `Sounds.Misc.Evade`. ForceEsc available (`Info.ForceEsc.Value`, no `Info` child with attr `Disable`) → bar (0,174,255) else (0,85,127). `Dead` → grey.
- **Emote**: `Info.Emote` disables all `CollectionService` tag `Emote` instances; `Emote` attr `Team` accumulates 300s → **`AchievementService.Give:Fire("Committed to the peace")` (client-initiated achievement grant — trust surface)**.

#### Camera (`BindToRenderStep "Cam"`, Camera+1)
- `_G.Shift==true` (and cam >2 from head): `GameSettings.RotationType=CameraRelative`, `MouseBehavior=LockCenter`, offset (1.75,0,0) or (2,0.75,0) if `ToolController.LastInput=="Mobile"`, scaled by char scale.
- Lock-on: `MovementController.LockOn` (character; set elsewhere — not in this file), GUI `PlayerGui.Controls.LockTarget` (Adornee=target HRP), Player attr `LockOn`. Cleared on death/no HRP; `Info.NoLockOn` → `_G.Shift=false`; camera rotation lerped toward `targetHRP + ownRight*1.75` at `54*dt` unless `NoLock` count>0 or CameraType Scriptable.
- `_G.Settings.Follow` → CameraOffset follows head; `Dead` → `CameraSubject=Head`.

#### Effects handled (`MovementService.Effects(a, name, char, extra)`)
| Key | Args | Render |
|---|---|---|
| Dash | (player, char, dir) | `Dash()` (see above) |
| Parkour | (_, char, isRoll) | `Sounds.Misc.Parkour.Roll` or `.Parkour` |
| Escape | (kind, char) | kind 1: `Utils.DashCancel` Ring 7/Wind 4; else `Sounds.Misc.Burst2`, `FXController:Flash(white,1)`, DashCancel Burst 8/Sparks 20/Ring 7/Wind 4, `Utils.Damage.Rage` white particle rate 80→0 |
| Grab | (n, char) | `Sounds.Misc["Throwable"..n]` |
| Hit | (_, char) | `Utils.Gojo.Twofold.Sparks` (20), Flash white, `Sounds.Itadori.DivergentFist.DivergentHit` |
| `Throwable` signal | (model, char, cframe) | Tween weld C1 from head-relative to original (0.267s) |
| `ResetDash` signal | () | local dash CD reset |

Unused table: colors for Itadori, Hakari, Megumi, Mahoraga, Mahito, Choso, Locust, Yuki, Mechamaru (dead code).

### 6.11 HandicapController (status / knockback / grab receiver, custom-move FX runtime)

"Handicap" = the receiver for server-applied status/physics effects (knockback swings, ragdoll collisions, grabs, bleed/poison, iframes, spawn anims, custom creator-clash FX). **No client→server calls.**

**Public API** (used by MovementController, ElbowDropController, other movesets):
| Method | Behaviour |
|---|---|
| `GetCharacterHeight(char)` | `HipHeight + HRP.Size.Y/2 + max(leg heights)` |
| `Swing(_, bodyVelocity, duration, localVec, wallCheck)` | **Only for LocalPlayer.Character**: loop each Stepped `bv.Velocity = HRP.CFrame:VectorToWorldSpace(localVec)`; if `duration`, magnitude is a NumberValue (child of bv) tweened `|vec|→0` Quad In; if `wallCheck` and `Blockcast((2,2,1), 1.8 ahead, Map)` → keep only Y. Runs until bv or HRP unparented |
| `MovementForce(char, startVel, endVel, dur)` | `BodyVelocity "MovementForce"` in Torso, MaxForce 40000³, P 40000, Velocity tween start→end 0.3s, Debris `dur` |
| `ClearForce(part[, except])` | Destroys BodyVelocity children named `SwingForce` or `MovementForce` (except `except`) |

**Trust surface**: server sends `Effects("Swing", bv, ...)` with a BodyVelocity it created on the client-owned HRP/Torso; the client sets `bv.Velocity` every frame from a local vector. Because the character's physics is client-owned, knockback distance/direction, grab positioning (`PivotTo`), and ragdoll motion are all realized on the victim's client — an exploiter can zero/alter them (also `ClearForce` is callable freely).

**`HandicapService.Effects(p1, name, p3, p4, p5)`** (name is 2nd arg):
| Key | Args | Client behaviour |
|---|---|---|
| Collide | (hrp, _, char) | While `Ragdoll>0`: ground touch → `Sounds.Impact.Players.RagdollFall1-3` (vol = speed/50 ≤3); speed>100 into wall → `Sounds.Hakari.OverLuck.Hit1` + `Sounds.Itadori.Rush.RushLaunch` + `FXController:DustBreak`, `Presets.Snap` within 100; `_G.Settings.DesPHY` dust every 0.05s at speed>50; `Utils.Damage.RagdollWind` at ≥100 (Trail >150) |
| Swing | (bv, _, localVec, duration, wallCheck) | `self:Swing(bv.Parent, bv, duration, vec, wallCheck)` |
| Death | (soundId, _, char) | `_G.Settings.VolKS` gate; clones `Sounds.Impact.Players.Death` with `rbxassetid://<id>` |
| Spawn | (_, _, char, movesetName) | `GetController(movesetName.."Controller")` → `.SpawnAnim` id into `Animations.Misc.SpawnAnim`, marker `Function` → `.SpawnFunc[marker](char, cleanupTbl)`; stopped on Info child added / health change / moved >1 stud / ancestry change |
| Poison | (ticks, _, char) | `Utils.Megumi.Poison` on HRP, per tick Flash (85,0,127) 2s + `Sounds.Megumi.Serpent.Poison1-3`, 1s apart |
| Bleed | (count, _, char) | per count: `Sounds.Misc.Bleed`, Flash (85,0,0) (or (255,85,255) if `_G.Settings.Gore==false`), `BloodyZee:Blood(Torso.CFrame, 15-30, 180, 180)` x2, `Utils.Damage.Explode` attachments' `Blood:Emit(8)` |
| SBleed | (_, _, char) | `Sounds.Misc.SBleed`, Flash 0.5, 1 blood |
| WakeupEvade | (_, _, char) | `Utils.Itadori.CounterHit` recolored (0,150,200) |
| IFrames | (duration, _, char) | Flash white `duration` |
| Grab | (grabberPart, _, victimHRP, weld, skipCollisionPart) | Every Heartbeat: victim model `PivotTo(grabberPart.CFrame * weld.C1)`, zero assembly velocities, victim parts with attr `D_CC` → CanCollide false; unless `skipCollisionPart`, creates invisible `GrabCollisionPart` welded to grabber HRP at victim HRP offset. Connection stored per character |
| GrabEnd | (grabberPart, _, victimHRP) | disconnect, destroy `GrabCollisionPart`, restore `D_CC` CanCollide, zero velocities |

**`HandicapService.Hit(char)`** (S→C): random hit-reaction anim from `Animations.Misc.Hits.Normal` (Humanoid attr `LHit` avoids repeats), speed 0.75, stopped on `PlatformStanding`.

**`BlockService.Effects(char, perfect)`**: perfect → `Sounds.Impact.Players.Perfect`; else `Sounds.Misc.Block.Block1-3` + `Utils.Damage.BlockHit`; char attr `Sword` or Moveset "Mechamaru" → additionally `Sounds.Misc.SwordBlock.Block1-3` + `Utils.Damage.SwordBlockHit`.

**`CustomService` (creator-clash / custom move builder runtime)** — all S→C:
| Signal | Args | Behaviour |
|---|---|---|
| SFX, SFX2 | (charOrPart, {ID, VOLUME, SPEED, START, END, "FADE IN", "FADE OUT", CANCEL, GLOBAL}) | Plays `rbxassetid://ID` (clone of Impact.Players.Death) w/ PlaybackRegion; GLOBAL → parented to workspace; CANCEL destroys matching sounds; workspace attr `CC1` clamps vol ≤2, forces non-global, kills sounds with PlaybackLoudness>750; >30s → SoundGroup Music |
| FX, FX2 | (char, lineItemValues) | Maps positional values onto `Modules.SkillDefault.LineItems.VISUAL` schema (`"✿"` = default), then `Modules.BuilderFX[EFFECT](char, cfg)`. If workspace attr `CreatorClash` and EFFECT ∈ {Screen Color, Overlay, Field of View, Camera, Shake Light/Medium/Heavy} → only when char attr `InMatch` == local char `InMatch` |
| PARTICLE, PARTICLE2 | (char, cfg) | Builds ParticleEmitter from string fields (POSITION, PART SIZE, SPREAD ANGLE, TEXTURE, RATE, COLOR, TRANSPARENCY, SQUASH, EMIT COUNT, DURATION, LIFETIME, SIZE, SPEED, ROTATION, ROT SPEED, ACCELERATION, DRAG, LIGHT EMISSION/INFLUENCE, ZOFFSET, LOCK TO PART, ORIENTATION TYPE, EMISSION DIRECTION, SHAPE, SHAPE INOUT/PARTIAL, FLIPBOOK *, BODY PART, CANCEL, CANCEL TAG, UID); `CC1` clamps lifetime ≤10, emit ≤100, duration ≤10; tag `CustomParticles` with attrs `ID`, `Owner`, `Tag` |
| LOOK | (char, {SMOOTHNESS, "CAMERA DIRECTION", "HORIZONTAL ONLY", GROUNDED}, target, lifetimeInst) | `AlignOrientation "CustomRotation"` on HRP (attr `UseMouse`), faces `ToolController:GetMouseTarget(1000)` / camera / target HRP each frame; GROUNDED adjusts HipHeight; destroyed when `lifetimeInst` unparented |

### 6.12 Supplement constants (movement numbers, attributes, IDs)

| ID / constant | Use |
|---|---|
| Footstep sounds: 5761648082 (Plastic/SmoothPlastic), 5639243489 (Slate/Concrete/Brick/Cobblestone), 619083295 (Fabric), 3437778169 (Glass), 5639245164 (Metal), 5639245590 (DiamondPlate), 5632735811 (Wood/WoodPlanks), 5639244517 (Grass), 5639243992 (Ground), 5639245918 (Sand), 7437372937 (Snow) | MovementController material footsteps |
| Parkour anims: Vault 125187993473697 / 95602001882956 / 107860751460547 / 79201532345509; Dive 98195977533316 / 85222050280022; Slide 98500512116998; Climb 104763108763761; BounceR 94327920127463; BounceL 113609963676386 | MovementController |
| QTE icons: Xbox 8981031512 (X), 8981031340 (Y), 8981032988 (B); PS 126768975062846, 140161712330460, 137275294114393 | FinalJudgement QTE |
| 73458769859093 | Todo "Woah" popup image |
| Dash: speed 200×DashMultiplier → tween to 16×, 0.4s, FOV 70; CD 2s / 0.45s (Naoya, DomainClash, flank) w/ 2 charges; chase gate 0.4s | MovementController |
| Sprint ×1.375 of `StarterPlayer.CharacterWalkSpeed`; HP speed penalty ≤3; Block speed 4/6; Stun 0.1 | MovementController |
| Wall-bounce max 3 (Goku 4, DomainClash 1) | MovementController |
| Evade bar max 50 | MovementController |
| Achievement "Committed to the peace" after 300s team-emote | MovementController |
| Shift-lock offset (1.75,0,0), mobile (2,0.75,0); lock-on lerp 54*dt | MovementController |
| Ragdoll impact thresholds: 50 (dust), 100 (wall hit/wind), 150 (trail) | HandicapController |
| Final Judgement dash speed 65 (1s ramp) | FinalJudgement |
| SlideKnockback arc height 4–8 (+2.5), speed ref 90; SlideStart speed ref 85 | ElbowDrop |

**Attributes / Info / states / tags / _G seen**
- Character attrs: `Sprint`, `Movement`, `Ragdoll` (number), `NoRagdoll`, `NoProcess`, `Stun`, `Burst`, `Evade`, `Dead`, `Moveset` ("Naoya","Goku","Mechamaru"), `Makora`, `UltMecha`, `Sword`, `InMatch`; `CustomChar` attr `CustomChase`; `SetAssets.ExecSword`.
- Humanoid attrs: `Speed`, `Speed2`, `Jump`, `LHit`. Player attrs: `Spectate`, `LockOn`. Workspace attrs: `CC1`, `CreatorClash`. Part attr: `D_CC` (disable-collision-on-grab), `UseMouse`, `EmitCount`. BodyVelocity attr `Swing`.
- `Info` children: `Knockback`, `ForceEsc` (Value), `Block`, `Stun`, `InSkill` (Value), `AllowDashInSkill`, `NoDash`, `DisableChase`, `DomainClash`, `Item` (child `Dash`), `NoSprint` (Value; attrs `AllowDash`, `S`), `NoJump`, `Emote` (attr `Team`), `NoLock`, `NoLockOn`, `NoParkour`, `InDash` (client-created), `DashMultiplier` (Value); `Info` attrs: `Burst`, `Parkour`; any child attr `Disable`.
- Tags: `Emote`, `CustomParticles`. `_G`: `Shift`, `MapParams`, `Settings.RagSFX/AutoRun/Follow/DesPHY/VolKS/Gore`.
- Modules: CameraShaker (Presets LightHit, MediumHit, HeavyHit, Snap, SnapOh), BloodyZee, SkillDefault, BuilderFX, EffectUtils (unused), Keybind (ReplicatedStorage.Keybind.Combat.Dash).

| Id / string | Use |
|---|---|
| 15117261700 | mobile layout topbar icon |
| 11713358131 | emote topbar icon |
| Gamepass 742180133 | emote slots 5–8 & 13–16 |
| Gamepass 1151174294 | emote page 2 switch + search |
| 7992557358 / 9405933217 / 5480743826 / 6870729295 / 11829454151 / 11214451393 / 14809805905 / 71437429504293 / 2599458148 / 401280105 / 95498291180289 / 10626050757 | topbar icons: Characters / Cash-Shop / Settings / Inventory / Achievements / Logs / Chat-voice / Rules / Ranked / Private server / Cmdr / Workshop |
| 129398506853336, 79537216753706 | Mokou, Goku (Monkey Kid) character icons |
| 8981031512, 8981031340, 8981032988 | Xbox X/Y/B QTE glyphs |
| 126768975062846, 140161712330460, 137275294114393 | PS X/Y/B(circle) QTE glyphs |
| KeybindIcons image table | ~100 key glyph ids (8146744410–8152439938 letters; 11903615000–11903615962 digits; 11850722536–11850728216 misc; 9972613363–9972618653 Xbox; 15030911057–15030935337 PS) |
| `rbxasset://textures/collapsibleArrowDown.png` | shift-lock cursor |
| Colors | ult-ready highlight white; hotbar idle RGB(31,31,31); mobile edit tint RGB(85,255,255); QTE hit RGB(0,255,127), miss RGB(170,0,0) |
| Strings | movesets referenced by name: Hanami, Chaos, Haruta, Mechamaru, Chara, Todo, Naoya, MeiMei, Yuki, Reggie, Uro, Mokou; NPC names `HarutaSwordNPC`; character keys list §2.10 |
| Modules | `Modules.Icon` (+`IconController`), `KeybindIcons`, `UltNames`, `RobloxChatVoice`, `Rules` (`.Version`), `CameraShaker`, `BloodyZee`, `CmdrClient` |

---

## 7. GUI, menus, shop, settings, update log

### 7.1 Menus / inventory / rules / achievements / update-log v1.82

- GUI root: `PlayerGui.Menus` with `Group.{Inventory, Rules, Settings, Logs}`, `Preset.{Emote, RuleAgree, Option, OptionString, OptionValue, OptionButton}`. Each controller sets attribute `Loaded=true` on its group frame when built.
- **Inventory**: tabs Emotes (search TextBox, `SortAZ` toggles LayoutOrder/Name → "NEW"/"A-Z", 8-slot equip bar with page Switch = 16 emote slots), Titles (attr `Title`), MVP victory emotes (attr `MVP`), Skins (dev-only tab for `imed2004`; per-category dropdown with `Default` + skin buttons, 3D viewport preview with rotation slider). All changes go through `EmoteService`.
- **Settings**: data-driven from `ReplicatedStorage.Modules.Settings/<Category>/<Setting>` modules (not in this slice) → keys unknown except those referenced in code: `Keybinds` (server-stored), local "fun" settings `Gravity`, `Invert`, plus `_G.Settings.DesPHY` etc. from the brief. Server pushes the whole settings blob as **Zstd-compressed JSON buffer** (`EncodingService:DecompressBuffer`). Gamepass-gated settings check `player.Gamepasses:GetAttribute(<GamepassName>)` (boolean attrs per pass; pass names/IDs not in slice). `Remotes.ForceFun` lets the server force a local fun-setting on. **No shop, gamepass IDs, or product IDs appear in this slice** (shop only referenced in UpdateLog text: "merch tab", "gifting icon").
- **Rules**: `Modules.Rules` (`RuleList`, `Agreements`, `Version`); acceptance persisted via player attribute `LastRulesAccepted`; `JoinService.AcceptRules`.
- **Achievements**: names seen `"Space Shenanigans"` (camera above Y 15000), `"Betavision"` (Gravity+Invert fun settings both on) — granted via client `AchievementService.Give:Fire` (client-authoritative).
- **Update log v1.82 "THE NOTHING UPDATE"** — balance/character facts (verbatim numbers):
  - SKY ASSASSIN: new skills *Blind Rage*, *Sky Distortion*, *Thin Ice Breaker*; new awakening *Temper*.
  - REGISTER: new awakening *Con-Artistry*; awakening moves *Mayhem*, *Big Moves*; "Sealing a move now has a sound effect".
  - DISASTER PLANT: released & free. Empower variants for *Root Rampage* (roots doubled, follow camera) and *Flower Field* (spike that pulls when reused). R special reverted to *Plant Guidance* (usable while blocking; spot only visible to user). *Aerial Root Rampage* dmg 30→25, hitbox wider. *Flower Field* explosion dmg → 12, spike dmg → 14; non-empowered spike hits 2 targets, empowered 4 (and same target repeatedly when pulled). *Cursed Buds*: Flower ragdoll +0.15s, Buds stun +0.05s, Buds dmg 1.25→1.7, Buds knockback x2.5. *Defense Response* gets Plant Guidance variant.
  - SWITCHER: new *Swift Kick* variant *Slide Kick*; *Pebble Throw* slide variant cooldown **7s → 8s**.
  - HEAD OF THE HEI: reverted *Cursory Impact* being able to Frame.
  - CURSED PARTNERS: new run anims/visuals during *Authentic Mutual Love* (copies techniques incl. Thin Ice Breaker).
  - BEAMS: clash duration 5→10s; post-win clash 2→3s; equal starting clash weight.
  - SHOP: 13 new emotes (Beat It, MewMew, Shwifty, Distraction, Yo-yo Walk, Sentadao, Livesey Walk, Let's Groove, Upside Down, Pistol Trick, Gravestone, Everyone is dancing!, Shout); style emotes Crane/Snake/Tiger/Boxer; Stand Proud, Big Shoe, Taka La, Mayhem emote.
  - BUILD MODE & SKILL BUILDER: custom awakening colors; exclusive weapons; Particle Nodes respect "creator clash visual limits".
  - ROULETTE: *Final Showdown* temporarily re-added; EOJ curses:sorcerers ratio 50/50 → 20/80.
  - BUG FIXES mention moves/systems: Detach, Second Wind (grab), Headcam, Speed Crash (grab version), Workshop, custom movesets used by NPCs, character export codes, Transfigured Humans + Swift Kick, Fleche "Use Twice", "You weren't invited" projectile.

### 7.2 Settings system (all 43 modules)

Each `Settings/<Category>/<Name>` module returns `{Btn, SortOrder, Val, Desc, Max?, Gamepass?, BtnText?, Callback?(value)}`. `Btn` types (inferred): **1** = toggle, **2** = text/ID input, **3** = slider (0..Max), **4** = push-button opening a sub-menu. `Val` = key in `_G.Settings` (persisted; sent via `JoinService.Setting:Fire(key, value)`); modules **without `Val`** (all Fun) live in `_G.LocalSettings` and are session-local. Defaults are not in these modules (server/JoinService) — "default" column shows only what code implies.

| Category | Name | Btn | Key | Default (evidence) | Effect |
|---|---|---|---|---|---|
| Audio | Effect | slider max 2 | VolFX | ? | SoundService.Effect.Volume |
| Audio | Music | slider max 2 | VolMS | ? | SoundService.Music.Volume |
| Audio | Background Music | slider max 2 | VolMS2 | ? | SoundService.Music2.Volume |
| Audio | Voice | slider max 2 | VolVA | ? | SoundService.Voice.Volume |
| Audio | Taunt | slider max 2 | VolTA | ? | SoundService.Taunt.Volume |
| Audio | Custom Sounds | toggle | VolKS | ? | hear other players' custom kill/death sounds |
| Audio | Custom Kill Sound | text | Killsound | – | gamepass 718699461; sound id |
| Audio | Custom Death Sound | text | Deathsound | – | gamepass 718699461; sound id |
| Audio | TTS | toggle | TTS | off | chat bubbles → TextToZee TTS (server `Remotes.TTS`) |
| Controls | Auto Use | toggle | AutoUse | ? | skills fire on key press (else select-then-click); clears ToolController.Selected |
| Controls | Auto Run | toggle | AutoRun | ? | always sprint |
| Controls | UI Scale | slider max 2 | UIS | 1 | Main/Gamepad/Emotes/Miracles/Adaptation UIScale |
| Controls | Menu Scale | slider max 2 | UIS2 | 1 | Menus/Roulette/Ranked UIScale (clamp .2–2) |
| Controls | Keybinds | button | Keybinds | defaults from `ReplicatedStorage.Keybind` | rebind; diffs sent `JoinService.MobileLayout:Fire(tbl, true)` |
| Controls | Sensitivity | slider max 10 | SENS | 1 | MouseDeltaSensitivity |
| Controls | Toolbar Offset | slider max 2 | TBO | 0 | Main.Controls X position |
| General | Game Info | button | – | – | opens tutorial (`_G.TutorialIcon:select()`) |
| General | Blood | toggle | Gore | ? | BloodyZee gate (`_G.Settings.Gore`) / recolor |
| General | Screen Shake | toggle | ScreenShake | ? | CameraShaker gate (consumed elsewhere) |
| General | Server Region | toggle | Region | off | topbar icon with `workspace.ServerRegion` |
| General | Camera Follow | toggle | Follow | ? | camera follows head |
| General | Hide Kills | toggle | HiddenKills | off | server sets leaderstats attr; client hides Kills value |
| General | Awakening Outfit | button | Outfit | nil | gamepass 857428668; `JoinService.Setting:Fire("Outfit", id|nil)` |
| General | Flashing Lights | toggle | Flash | ? | reduce flashes/impact frames |
| Performance | FPS Counter | toggle | FPS | off | Main.FPS label |
| Performance | Shadows | toggle | Shadows | ? | Lighting.GlobalShadows |
| Performance | Destruction S | toggle | DesVFX | ? | destruction smoke |
| Performance | Destruction I | toggle | DesINT | ? | interpolate debris |
| Performance | Physics VFX | toggle | DesPHY | ? | physics-heavy VFX gate |
| Performance | Ragdoll SFX | toggle | RagSFX | ? | limb collision sounds |
| Fun | Invert | toggle (local) | – | off | Saturation −2 |
| Fun | Gravity | toggle (local) | – | off | camera upside-down |
| Fun | Goodnight | toggle (local) | – | off | night lighting (excl. Sunset/Darkness) |
| Fun | Rain | toggle (local) | – | off | rain + indoor muffle |
| Fun | Cherry | toggle (local) | – | off | blossom petals + CC |
| Fun | Jolly | toggle (local) | – | off | snow, FogEnd 500 (excl. Darkness) |
| Fun | Bloodbath | toggle (local) | – | off | BloodyZee.PermBlood (pools persist, no range cull) |
| Fun | Bloom | toggle (local) | – | off | Utils.Misc.FunBlm |
| Fun | Sunset | toggle (local) | – | off | sunset lighting (excl. Goodnight/Darkness) |
| Fun | Darkness | toggle (local) | – | off | OLED black, FogEnd 50 (excl. Goodnight/Sunset/Jolly) |
| Fun | Headcam | toggle (local) | – | off | first-person head camera |

### 7.3 Tutorial, rules, dialogue, chat-voice modules

`Info/Tutorial`: 8 pages (Ragdolls, Blocking, Parkour, Burst, Throwables, Items, Shop, Combat) — image ids in §13. `Rules`: version 3, 17 rules + 1 agreement (Ranked, Roulette, workshop content, billboards, supporter streams). `TekrinnDialogue.Speak(player, segments)`: per-letter animated dialogue GUI tagged `KJUI`. `DeadlyData`: Hiromi Deadly Sentencing crimes (26) + dialog/fail lines. `RobloxChatVoice`: 36 chat-triggered voice clips keyed by catalog asset id with per-clip cooldown (full map in §8.4). `StyleAura`: taunt/style stance aura + owner-only `StyleMusic`. `CountryCodes` + `Settings/General/Server Region`: continent label from `workspace.ServerRegion`.

---

## 8. Custom moveset editor, MVP cinematics, misc modules

### 8.1 Custom moveset editor (SkillDefault node schema)

`SkillDefault.LineItems[NODE] = { {ParamName, typeCode, default, Desc=?}, ... }`. Type codes (inferred from defaults): 1 bool, 2 number, 3 string/dropdown, 4 anim preview {start,end}, 5 Vector3 "x, y, z", 6 Color3 "r, g, b", 7 hitbox preview, 8 comma-list, 9 NumberSequence "a, b", 10 ColorSequence "r,g,b r,g,b", 11 NumberRange "min, max". A move = graph of NODEs in BRANCHes; "LAST HIT" (seconds) params make a node conditional on a recent hit; "RELATIVE FROM BRANCH" uses the branch origin; "PROJECTILE TAG" links nodes to a projectile.

| Node | Params (default) |
|---|---|
| WAIT | TIME (1) |
| SKILL | MOVE ("Divergent Fist" — dropdown of MoveList names), SPEED (1), CANCEL LAST (false), ENABLE VARIANTS (true), HOLD FOR (0; holdable skills e.g. Max Elephant), START (0 s) |
| SPECIAL | SPEC ("Limitless" — SpecialList), SPEED, CANCEL LAST, ENABLE VARIANTS |
| ANIM | PREVIEW {0,15}, ANIM_USE {1,1}, LOOPED (false), SPEED (1), FADE IN (.1), FADE OUT (0), LAST HIT (−1) |
| SFX | ID (12222253), SPEED (1), VOLUME (.5), START (0), END (500), FADE IN/OUT (0), CANCEL (false, stops all SFX nodes), GLOBAL (no 3D falloff), CLIENT SIDED (target's client only), LAST HIT, PROJECTILE TAG |
| VELO | FORCE "0,0,0", TIME (0), FADE, TRACK (follows torso orientation), LAST HIT, RAGDOLL (s), TRUE RAGDOLL (no ragdoll-cancel), RELATIVE FROM BRANCH |
| CONNECT | SIGNAL ("Nothing"), TIME (.1), RANGE (inf studs) — "block's signal" (inter-player signal?) |
| HITBOX | PREVIEW, POSITION "0,0,4", ROTATION, SIZE "6,6,6", STUN (1; −1 = no stun but mark LAST HIT), STUN ANIM, IGNORE WAKEUP (true), DAMAGE (1), DEBREE (0; fidelity default 2; negative = destroy without debris), ATTACK TYPE ("Melee"), BLOCKABLE (true), 360 BLOCK, CANCEL ENEMY (true), CLEAR KNOCKBACK, CAN KILL (true), HIT RAGDOLL, HIT USER, SINGLE TARGET (true), BRANCH (on hit), BRANCH TARGET (forces target into a branch), BRANCH FINISHER (if fatal), PROJECTILE TAG, LINK USER (s; damage to hitbox transfers to user) |
| ULTGIB / HPGIB / EVGIB | AMOUNT (5) [+ HPGIB CAN KILL false] — give/take Ult meter, HP, Evasive meter |
| SETCD | KEY (−1 = current move), COOLDOWN (−1 = default) |
| HITCNCL | TIME (1), FLIP, ENDLAG (1 s stun on cancel), BRANCH — branch depending on whether a target was hit in last TIME s |
| BRANCH | BRANCH, RANDOM (comma list), LAST HIT |
| VISUAL | EFFECT ("Slash"; "Mesh" → AMOUNT becomes mesh id; "Cancel" cancels VISUAL TAG), AMOUNT (1), TEXTURE (asset id), COLOR/ALT COLOR, OPACITY/ALT, POSITION/ALT, ROTATION/ALT, SIZE/ALT (1), TIME (1), LAST HIT, BODY PART ("HumanoidRootPart"), VISUAL TAG, PROJECTILE TAG, RUN ON SERVER, CLIENT SIDED, CANCEL ON INTERRUPT, RELATIVE FROM BRANCH, CAN COLLIDE, EASING STYLE ("Linear"), EASING DIRECTION ("In"), SIZE 2 / ALT SIZE 2 ("-1,-1,-1" uniform sizing for mesh/part) |
| LOOP | LOOP BACK (1), LOOP AMOUNT (3), HOLD |
| GRAB | BODY PART, BODY PART2, POSITION, ROTATION, TIME (1), LAST HIT (1) |
| PROJECTILE | PROJECTILE TAG, CANCEL PROJECTILE, ID CHECK (true, tag scoped to this move), SPAWN AT PROJECTILE TAG, POSITION, ROTATION, SIZE "6,6,6", SPEED (1 stud/s), TIME (1), STUN, STUN ANIM, IGNORE WAKEUP, DAMAGE, DEBREE, ATTACK TYPE, BLOCKABLE, 360 BLOCK, CANCEL ENEMY, CLEAR KNOCKBACK, CAN KILL, HIT RAGDOLL, HIT USER, AIM LAST HIT, CONTINUE (pierce), BRANCH, BRANCH TARGET, BRANCH COLLIDED (empty = ignore env), FILTER INTERVAL (1), REFLECT COUNT (0 bounces), CACHE (true) |
| COUNTER | ATTACK TYPE2 ("Melee"), TIME (1), STUN (1), CANCEL ENEMY, BRANCH, BRANCH TARGET, REMOVE ON HIT (true), REFLECT (redirect projectiles), CONTINUE (take damage but still trigger) |
| TAG | TAG, VALUE, TIME (1), CHECK (supports `<`/`>` prefix), ADD/REMOVE (true), SET (true), BRANCH, LAST HIT — per-move variables |
| STATE | STATE ("Stun" — ListData.States), VALUE (1), TIME (1), CANCEL ON END, DISABLE BURST, LAST HIT, CHECK (does LAST HIT have state → BRANCH), BRANCH, STATE TAG |
| TELEPORT | POSITION, ROTATION, LAST HIT, PROJECTILE TAG, RELATIVE FROM BRANCH, IGNORE WALLS (true) |
| LOOK | TIME (1), SMOOTHNESS (40; 10–200), HORIZONTAL ONLY, LAST HIT (−1 = cursor), RELATIVE FROM BRANCH, PROJECTILE TAG, CAMERA DIRECTION, GROUNDED |
| SETMELEE | COMBO (0; −1 keep), OFFSET (0 s reset), LAST HIT |
| PARTICLE | PROJECTILE TAG, LAST HIT, PART SIZE, TEXTURE, EMIT COUNT (10), RATE, DURATION, COLOR (ColorSequence), SIZE, BRIGHTNESS, TRANSPARENCY, SQUASH, LIFETIME ".5,1", SPEED "5,5", ROTATION, ROT SPEED, ACCELERATION, DRAG, LIGHT EMISSION, LIGHT INFLUENCE, ZOFFSET, SPREAD ANGLE, POSITION, LOCK TO PART, BODY PART, ORIENTATION TYPE ("FacingCamera"), EMISSION DIRECTION ("Top"), FLIPBOOK SIZE/MODE("OneShot")/FRAMERATE, SHAPE ("Box"), SHAPE INOUT ("Outward"), SHAPE PARTIAL, RUN ON SERVER ("permanent auras"), CLIENT SIDED, CANCEL TAG, CANCEL, CANCEL ON INTERRUPT |
| AIR / JUMP / AIM / ULT / DOMAIN / HOLD | FLIP (false) — condition nodes: in air / jumping / aiming / awakened / in domain / key held |
| HP | AMOUNT (10), FLIP — HP threshold condition |
| BAR | AMOUNT (5), FLIP — meter (ult bar) threshold condition |
| DUR | DURABILITY (1) — item durability cost? |

`defaultProp` (per-move properties): DMG 1, KNOCK 1, KEEP false, REP false, REP2 false, INV false, AWK false, AWK2 false, USE false, USEONDEATH false, NOSTUN false, NOCANCEL false, VAR "-". (AWK/AWK2 ≈ "usable only when awakened / second awakening"; REP/REP2 ≈ replaces base/awk slot; USEONDEATH = triggers on death; VAR = variant name.)

### 8.2 MVP titles / cinematics

`MVP:MVP_Play(player, name)` requires `MVP/<name>` and plays a fixed cinematic. **The selection rule (which title a player earns) is not in the dump — it is decided server-side and passed as the name.** Evidence-based table:

| Title (module) | What the cutscene shows / implied condition |
|---|---|
| Domain Invasion | Winner inside a domain scene (Megumi/Sukuna-like BG "Shadow" water). Implied: won via domain (?) |
| King Of Curses | Sukuna atmosphere (`SukunaAtmo`), Voice line. Implied: Itadori awakening / Malevolent Shrine (?) |
| Meditation | Todo clap SFX ("Clap Todo"), butterflies, waterfall. Implied: Todo (?) / peaceful win |
| Phenomenal | 4-armed rig ("ExtraLeft/Right Arm"), Text banner, Music. Implied: Hakari "Idle Death Gamble" jackpot or Locust (?) |
| Stalemate Collapse | Winner + a victim rig (viewer, or random other player if viewer is winner/teammate), victim cut with Beam + Blood. Nanami "Collapse" (?) |
| Stand Proud | Meteor + flames, Voice. Gojo "Stand proud, you are strong" (?) |
| True Value | Slash overlay at keyframe "Cut", FOV 17. Yuta/Nanami slash (?) |
| Watch Your Head | Winner + victim rig, glass/sparks burst, FOV punch. Decapitation joke (Hiromi/Reggie/Haruta ?) |
All: `PlayerGui.Main` disabled during, camera Scriptable, restored by `MVP_End`. Team-aware victim choice uses `Player.Team`.

### 8.3 Discord / logging modules

- `Discord/Version` identifies the folder as **"Discord Roblox SDK" v1.0.3 built 2026-06-25** — a stock SDK for Discord Rich Presence/activities, apparently only partially included (Logger, RemoteEvents helper, Utils/createGameActivity, Version).
- **No webhook URLs, no HttpService calls, no player-data exfiltration** in this slice. Logger prints to console only (level WARN default, `customOutputFunction` hook unset).
- Where the SDK is actually invoked (client presence updates?) is not in this slice.

### 8.4 Module provenance verdicts and per-module asset list

| Module | Verdict |
|---|---|
| BloodyZee | Game-specific ("Zee" author, same as TextToZee); built on FastCastRedux; hard-wired to `workspace.Effects.Blood`, `workspace.Map/Domains`, `_G.Settings.Gore`. Not stock. |
| SraikoVFX | Third-party base (Sraiko) with game edits: speed NumberValue slow-mo re-tween, cleanup-list param, `workspace.Effects` target, `Offset` value on meshes. |
| EffectUtils | Game-specific. |
| LightningBeams | Stock LightningBolt module; only default parent changed to `workspace.Effects.Bolt`. |
| StaticLightning | Small custom bolt builder (BulkMoveTo), game-specific. |
| SimplePath | Stock, unmodified. |
| Base64 | Custom (adds Zstd via EncodingService). |
| CountryCodes | Generic data table. |
| Discord/* | Stock SDK pieces. |
| RobloxChatVoice, StyleAura, TekrinnDialogue, DeadlyData, MVP/*, Settings/*, ListData, SkillDefault, UltNames, Rules, Info/Tutorial | Game-specific. |

| ID | Kind | Use |
|---|---|---|
| 718699461 | Gamepass | Custom Kill Sound + Custom Death Sound |
| 857428668 | Gamepass | Awakening Outfit |
| 12222253 | Sound | SkillDefault SFX node default |
| 124674005293931 / 93359191648570 / 102306667240177 / 119038955627224 / 5670799859 / 5608359401 | Image | Tutorial pages Ragdolls / Blocking / Parkour / Burst / Throwables / Items+Shop+Combat |
| RobloxChatVoice (trigger asset → sound id, vol, cd, name) | Sound | 105199432380841→136360298072269 (.5, 2.5, "mahito itadori"); 18680487885→78896502619972 (.6, 2.2, "sorry nanami"); 18257697094→83421804187475 (1.6, 1.1, "best friend"); 129622474979733→97653793049098 (1.3, 2, "BEST FRIEND"); 71411567772779→81647678860208 (.9, 4.5, "what are you mahito"); 7061193663→134720365521601 (1.3, 3, "yo its been a while"); 7948969023→7147847068 (1, 1.4, "yowai mo"); 7061369096→18956314488 (1.5, 1.3, "next"); 137318879402973→91314701968093 (1.3, 1.3, "idiot"); 99137255050147→124723824798365 (1.5, 1.5, "you did it"); 18319797565→124478817965650 (1.1, 1.8, "laugh"); 18370175258→109660701821480 (1.7, 1.4, "oi"); 97871211303571→72270862303024 (1, .8, "mambo"); 89667437228243→85458465816182 (.9, 3.3, "yujiiiii"); 15917626934→130066562156553 (1.2, 1.2, "convergence"); 15753185070→126062298173538 (1.2, 4.7, "apologize"); 16363777391→83353502086066 (1, .5, "huh"); 18246120711→79557514967485 (1, 1.5, "vibraslap"); 10173613362→83040544565202 (1.5, .9, "nanami sigh"); 12917642257→83684170238132 (.7, 4, "don"); 6265242673→120491615591769 (.7, 1, "satoru gojo!!!"); 16159090773→136810908754750 (.9, 1, "for real"); 7061190867→136033743459006 (2, .6, "for real"); 112599702984899→85491616155103 (.8, 1.2, "you cryin"); 6743603446→120433297149723 (.8, 1.1, "toji fushiguro"); 128755610900618→127466398361373 (1.5, 1.2, "ganbare ganbare"); 131371183130808→74559114283681 (.9, .5, "somethings off"); 13997948756→93687341563646 (1.5, 2, "angry"); 100445971002729→96682343073262 (.7, 5, "stand proud"); 5775509840→75909189523782 (.8, 2, "waste of time"); 18976119144→75069825195204 (.8, 1.3, "sata andagi"); 96326653225562→129765136259554 (.8, 1.4, "where are you going"); 78044670447386→71783048161793 (1.5, 1.2, "idk this guy"); 106755448566954→117890102723144 (1.5, 2.5, "hidoi na"); 108907296117028→131171831543343 (1, 2.5, "JACKPOT"); 134719689134074→103780040278292 (2, 2.5, "words are unnecessary") |
| `rbxthumb://type=Outfit&id=<id>&w=150&h=150` | Thumb | Outfit picker |
No place ids, product ids or UserIds in this slice.

---

## 9. Admin tooling

Two layers: (a) **Cmdr console** (F2 / `;`), 44 game-specific commands with group-role gating via a `Permissions` BeforeRun hook, executed through `ReplicatedStorage.CmdrClient.CmdrFunction:InvokeServer(text, {Data})`; (b) **DebugController creator panel** (`PlayerGui.Menus.Group.Private`) speaking `DebugService.Debug:Fire(cmd, target?)` with server flags (Respawn2, Destroy, OP, FF, TI, Item, Dummy1–9, Gravity, WalkSpeed, JumpPower, ServerName, ServerIcon, Fidelity, Tick, Damage, Knockback, Lock, Voice, RC, CC1–3, GlobalName, MaxDmg, VK, VKB, KF), per-player flags (Flight, Build, PSPerms, CD, Ult, Stun, Respawn, DeathKick, Skill, SkillM1, SkillUlt, Parkour, Burst, ApplyNew, Workshop) and actions (Kick, Ban, Heal, ResetCD, Kill, Bring, Go, Respawn3), plus `DebugService.Unban(userId)`, `DebugService.Update()` and a build-mode request flow over `Remotes.Request`. Creator keybinds: `Keybind.Creator["Reset Cooldowns" | "Toggle Flight" | "Toggle Build Menu"]`. Server implementations of every command are **n/a (server)**.

#### 3a. Game commands (`ReplicatedStorage/CmdrClient/Commands`, 44) — server implementations are **not** in the dump for any of them (server side); `watch` is the only ClientRun.

Permission hook (`CmdrClient/Types/Permissions.lua`, runs as `BeforeRun` on client *and* server since it is registered via `RegisterTypesIn`): `_G.GroupId = 16357742`; role verifiers via `Player:GetRoleInGroup(16357742)`:
`Owner` = role "Owner" (or UserId<0 i.e. Studio test); `Developer` = "Developers"; `HeadMod` = "Head Moderators" or "Community Manager"; `Mod` = "Moderators"; `Contrib` = "Contributors"; `Tester` = "Testers" **and** `game.PlaceId == 9164905432`; `TesterPublic` = "Testers" (any place); `Youtuber` = `Player:GetAttribute("Youtuber")`; `CustomMoveset` = `Player:GetAttribute("AllowCustomMoveset")`. Command with no Group → "A group isn't linked to this command!"; no match → "You don't have permission to run this command".

| name | aliases | Group (roles) | args (type:name [opt/default]) | description | server file in dump? | notes |
|---|---|---|---|---|---|---|
| announce | – | Owner, Developer, HeadMod | string:Message; boolean:Global [opt, def false]; boolean:"Include username" [opt, def false]; number:"Duration of message" [opt, def 6] | Announces a server-wide message (or global one) | no | "Global" implies MessagingService cross-server broadcast |
| ban | – | Owner, Developer, HeadMod, Mod | username:Username; reason:Reason [opt]; number:"Duration (in days)" [opt]; boolean:"Include Alternative Accounts" [opt] | Removes the player's ability to join the game along with their place in the leaderboards | no | alt-account banning; leaderboard wipe |
| banreason | – | Owner, Developer, HeadMod, Mod | username:Username | Returns the player's reason for ban | no | |
| blacklist | – | Owner, Developer, HeadMod | number:ID | Add an ID to the killsound or billboard blacklist | no | asset-ID blacklist for custom killsounds/billboards |
| blacklistclear | – | Owner, Developer, HeadMod | number:ID | Removes an ID to the killsound or billboard blacklist | no | |
| build | – | Owner, Developer, HeadMod, Mod | username:Username; number:Slot; number:Version [opt] | Loads a player's build into the game | no | "build" = custom-moveset/creator save slots (versioned) |
| buildworkshop | – | Owner, Developer, HeadMod, Mod | string:"Entry ID" | Loads a player's workshop upload into the game | no | workshop entries exist |
| cash | – | Owner, Developer, HeadMod | player:Player; number:Value | Sets the player's cash to the value specified | no | currency "cash" |
| checkblacklist | – | Owner, Developer, HeadMod | number:ID | Check if an ID is blacklisted anywhere | no | |
| clearslot | – | Owner, Developer, HeadMod, Mod | username:Username; number:Slot | Erases all data from a slot | no | |
| code | – | Owner, Developer | player:Player; string:Code; boolean:Clear | Adds / Remove a code from a player's data | no | redeem-code system |
| customMoveset | – | Owner, Developer, HeadMod, **CustomMoveset** | string:"moveset data" [opt] ("Paste exported data here (must be wrapped in quotes)"); player:"player to load for" [opt] ("Head Mod+"); boolean:"save when rejoining" [opt] ("loads the moveset when you rejoin (only works if you load on self)") | exports/imports current moveset | no | whitelisted users (attribute `AllowCustomMoveset`) can import/export moveset strings; no arg = export |
| customWhitelist | – | Owner, HeadMod, Developer | username:Username; boolean:allow; boolean:"allow loading movesets for other people" [opt, def false] | Change player's permission to load custom movesets | no | presumably sets `AllowCustomMoveset` (+ a second flag) |
| data | – | Owner, HeadMod, Developer, Mod | username:Username; number:Version [opt] | Display all data of a player | no | versioned datastore reads |
| disguise | – | Owner, Developer, HeadMod, Mod, Contrib, Youtuber | players:Players; username:To | Wears the player's outfit | no | applies another user's avatar |
| emote | – | Owner, Developer | player:Player; string:Emote; boolean:Clear | Adds / Remove an emote from a player's inventory | no | |
| emotetoken | – | Owner, Developer | player:Player | Adds an emote token to a player | no | "emote token" currency |
| endcreate | – | Owner, Developer, HeadMod, Mod | string:Username | Ends a server made with the ingame creator | no | in-game private-server creator |
| ErrorLogs | – | Owner, Developer, Tester, TesterPublic, HeadMod, Mod | (none) | Get server's error logs | no | |
| gamepass | – | Owner, Developer, HeadMod | username:Username; number:"ID of gamepass" | Gifts a gamepass to the player | no | gamepass ownership stored in data |
| hitbox | **ht** | Owner, Tester, Developer, **Moderator** | boolean:Bool | Sets the transparency of hitboxes | no | "Moderator" is not a defined verifier key → `v_u_12["Moderator"]` is nil → hook errors for anyone not already matched by Owner/Tester/Developer. Only command with an alias. |
| item | – | Owner, Developer, HeadMod, Mod, Tester, TesterPublic, Contrib | item:Item; boolean:"Disable Drop" [opt]; boolean:"Disable Durability" [opt]; number:"Despawn Timer" [opt, def 10]; boolean:"Auto Equip" [opt] | Spawns an item where you're located | no | items have durability/drop/despawn |
| join | – | Owner, Developer, Contrib, HeadMod, Mod | string:Username; boolean:"alternative method" [opt] | Joins the server the player is currently in | no | |
| joincreate | – | Owner, Developer, HeadMod, Mod | string:Username | Joins a server made with the ingame creator. A player will be forcefully kicked if the server is full | no | |
| kick | – | Owner, Developer, HeadMod, Mod | player:Player; string:Reason [opt] | Removes the player from the server | no | |
| kills | – | Owner, HeadMod, Developer | username:Username; number:amount | Changes the kill amount of a player | no | |
| loadhistory | – | Owner, Developer, HeadMod, Mod, CustomMoveset | player:Player [opt]; boolean:Raw [opt] | Loads the history of a player's data | no | |
| locateblacklist | – | Owner, Developer, HeadMod, Mod | string:Data | Finds blacklisted ids in moveset data | no | scans exported moveset strings for blacklisted asset IDs |
| mapsong | – | Owner, Developer, HeadMod, Mod, Contrib, Tester | (none) | Map a song | no | |
| mokou | – | Owner, HeadMod | player:Player; number:"Duration (in minutes)" | Adds a player temporarily to the whitelist | no | temporary whitelist named after the Mokou moveset (Custom/Mokou controllers exist in other slices) |
| moveset | – | Owner, Developer, HeadMod, Mod, Tester, Youtuber | character:Moveset; boolean:Ultimate [opt] | Loads a moveset into your inventory | no | `character` autocomplete only on PlaceId 9164905432; "Ultimate" flag = grant ult/awakened variant |
| op | – | Owner, Developer, HeadMod, Mod, Tester, Youtuber | (none) | Makes the player extremely strong | no | file named Overpower |
| pickroulette | – | Owner | number:gamemode | Pick the gamemode for roulette | no | |
| ping | – | Owner, Developer, Contrib, HeadMod, Mod | player:Player | Returns the ping of the user | no | |
| resetquests | – | Owner, Developer, Tester, HeadMod, Mod | player:Player | Removes all data of player's quests | no | quest system |
| restart | – | Owner | gamemode:Gamemode | Restarts all servers with specified server type | no | server types Creator/Final/Parade/Roulette |
| rollback | – | Owner, Developer, HeadMod, Mod | username:Username; number:Slot; number:Versions | Rollback their build data by the specified versions | no | |
| scale | – | Owner, Developer, HeadMod, Mod, Youtuber | player:Player; number:Scale | Scales the player's character | no | |
| secrettest | – | Owner, Developer | player:Player | "imed secret command for testing" | no | |
| title | – | Owner | username:Username; string:Title; boolean:Clear | Adds / Remove a title from a player's inventory | no | |
| unban | – | Owner, Developer, HeadMod, HeadMod(dup), Mod | username:Username | Returns the player's ability to join the game | no | |
| versionlist | – | Owner, Developer, HeadMod, Mod | username:Username; number:Slot | Lists all versions of the file | no | |
| watch | – | Owner, Developer, HeadMod, Mod, Tester, TesterPublic, Contrib, Youtuber | player:Player | Watches a player. | n/a (ClientRun) | client-only: `workspace.CurrentCamera.CameraSubject = target Humanoid`; still goes through BeforeRun permission hook |
| wavecheck | – | Owner, Developer, HeadMod, Mod | string:Username | Performs a wavecheck on the given player | no | "wavecheck" = ? (likely an anti-cheat/inventory audit) |

Role coverage summary: Owner has every command; Owner-only: `pickroulette`, `restart`, `title`; Owner+Developer only: `code`, `emote`, `emotetoken`, `secrettest`; Owner+HeadMod only: `mokou`.

#### 3b. Stock Cmdr built-ins (`ReplicatedStorage/Modules/Cmdr/Server commands`) — present in the replicated server module but **not registered** (none appear in `CmdrClient/Commands`), so they are not usable in-game.

| name | aliases | group | args | description | impl in dump? | notes |
|---|---|---|---|---|---|---|
| announce | m | DefaultAdmin | string:text | Makes a server-wide announcement. | `announceServer.lua` (filters text, `SendEvent(player,"Message",...)`) | name collides with game's `announce` |
| goto-place | – | DefaultAdmin | players; integer:"Place ID"; string:JobId [opt] | Teleport to a Roblox place | `gotoPlaceServer.lua` | AutoExec aliases `follow-player`, `rejoin` |
| kick | boot | DefaultAdmin | players | Kicks a player or set of players. | `kickServer.lua` ("Kicked by admin.") | collides with game's `kick` |
| kill | slay | DefaultAdmin | players:victims | Kills a player or set of players. | `killServer.lua` (BreakJoints) | |
| respawn | – | DefaultAdmin | players:targets | Respawns a player or a group of players. | `respawnServer.lua` (LoadCharacter) | AutoExec alias `refresh` |
| teleport | tp | DefaultAdmin | players:From; player@vector3:Destination | Teleports a player or set of players to one target. | `teleportServer.lua` | AutoExec `bring`, `to` |
| blink | b | DefaultDebug | – | Teleports you to where your mouse is hovering. | ClientRun | |
| fetch | – | DefaultDebug | url | Fetch a value from the Internet | `fetchServer.lua` (HttpService:GetAsync) | |
| get-player-place-instance | – | DefaultDebug | playerId; enum Format | Returns target's PlaceId/JobId | `getPlayerPlaceInstanceServer.lua` | |
| position | pos | DefaultDebug | player [opt] | Returns Vector3 position | ClientRun | |
| thru | t, through | DefaultDebug | number:"Extra distance" [opt] | Teleports you through the hovered wall | ClientRun | |
| uptime | – | DefaultDebug | – | Server uptime | `uptimeServer.lua` | |
| version | – | DefaultDebug | – | Shows the current version of Cmdr | Run → "Cmdr Version v1.12.0" | |
| alias | – | DefaultUtil | string; string | Creates a new command from a command string | ClientRun | |
| bind | – | DefaultUtil | userInput!bindableResource@player; command; string | Binds a command string to a key/mouse/chat | ClientRun | |
| clear | – | DefaultUtil | – | Clear Cmdr window | ClientRun | |
| convertTimestamp | date | DefaultUtil | number | Timestamp → human readable | ClientRun | |
| echo | = | DefaultUtil | string | Echo | Run | |
| edit | – | DefaultUtil | string; string [opt] | Edit text in a TextBox | ClientRun | |
| history | – | DefaultUtil | integer | Previous commands | ClientRun | AutoExec `!`, `^` |
| hover | – | DefaultUtil | – | Name of hovered player | ClientRun | |
| json-array-decode | – | DefaultUtil | json | JSON array → CSV | ClientRun | |
| json-array-encode | – | DefaultUtil | string | CSV → JSON array | Run | |
| len | – | DefaultUtil | string | Length of CSV | Run | |
| math | – | DefaultUtil | mathOperator; number; number | Math op | ClientRun | AutoExec aliases |
| pick | – | DefaultUtil | integer; string | Pick from CSV | Run | |
| rand | – | DefaultUtil | integer; integer [opt] | Random number | Run | |
| replace | gsub, // | DefaultUtil | string×3 | gsub | Run | AutoExec `map` etc. |
| resolve | – | DefaultUtil | type; operator | Resolve argument operators | Run | AutoExec `me` |
| run | > | DefaultUtil | string | Run a command string | Run | AutoExec `discard` |
| run-lines | – | DefaultUtil | string | Run each line | ClientRun | |
| runif | – | DefaultUtil | conditionFunction; string×3 | Conditional run | Run | |
| unbind | – | DefaultUtil | userInput!bindableResource@player | Unbind | ClientRun | |
| var | – | DefaultUtil | storedKey | Get stored var | ClientRun (`varServer.lua` backs it) | AutoExec `init-edit`, `init-run` |
| var= | – | DefaultUtil | storedKey; string | Set stored var | ClientRun (`varSetServer.lua`) | |
| help | – | Help | command [opt] | List/inspect commands | ClientRun | |

---

## 10. Anti-cheat

- `AntiCheatController` (115 KB, 2593 lines) is 100% a Luraph-family bytecode VM. The header line `return 11 - 1 == 10 and "Owl-Fuscator Anti Decompile v3; By Google Chrome#6242" or (...):DD()` is a decoy/anti-decompile banner (as decompiled it would return the string, but that is almost certainly a decompiler artefact of the real dispatch). The remainder is an opcode interpreter (register file `v_u_70`, opcode switch on `v83` 1..~90, upvalue capture, varargs, `coroutine.yield`-based execution) plus a constant-decryption layer (`bit32` arithmetic on `p3[...]` tables) and Ascii85-encoded payload strings (~21 KB; `z` / `!!!` runs = zero words).
- **Nothing observable**: no `game`, `Players`, `Kick`, `FireServer`/`InvokeServer`, `Knit`, `Humanoid`, `WalkSpeed`, `GetAttribute`, `getgenv`/`syn`/`hookfunction` strings appear in plaintext. Every check, threshold, reporting remote, punishment (kick/flag/attribute) and whitelist is inside the encrypted bytecode. The numeric literals present (e.g. 793929241, 706355807, 4503599627370495, 4294967xxx) are VM arithmetic constants, not UserIds/asset IDs.
- Environment: it is loaded like any other controller (`Knit.AddControllersDeep` from `Controllers/Character/AntiCheatController`), so it is expected to `CreateController` + `GetService("AntiCheatService"?)` internally — **unverified**. It is the only controller in the dump using `getfenv/setfenv` (needed by the VM), which itself is a common exploit-detection vector.
- The only anti-cheat-adjacent plaintext in this slice: KnitRunClient's UserId hide-list (cosmetic, hides dev/staff accounts from Players list) and the InventoryController "imed2004" dev whitelist for the Skins tab. Neither is enforcement.
- Practical implication: to learn what it detects one must dump the VM at runtime (hook the interpreter's constant table / trace `FireServer` from inside the spawned thread), not read this file.

Additional plaintext observations across the dump: the only exploit-relevant client checks anywhere are cosmetic (`HidePlayer` hide-list, `imed2004` skins tab); hitbox debug spheres render whenever `Utils.Hitbox.Hitsphere.Transparency ~= 1` (toggled by the `hitbox`/`ht` admin command); no controller inspects `getgenv`, `hookfunction`, `WalkSpeed`, or `Humanoid` state for tampering. Whatever detection exists is entirely inside the VM.

---

## 11. Camera / cutscene system

- `CameraController` (210 KB, 3524 lines, path is bare `CameraController` — root-level with no ancestry, i.e. the dumper found it outside the normal `PlayerScripts/Controllers` tree; probably a cached/`nil`-parented module) is also a Luraph VM (`"Luraph Script:"` error prefix at L2834, `buffer.*` readers, `readf32` for float constants, ~59 KB Ascii85 payload). Wrapped in `task.spawn(function(...) ... end) return true` — so the *module returns `true`*, not a controller table, meaning it is **not** a normal Knit controller; it runs its body asynchronously on require.
- **Custom vs stock**: no plaintext `CameraModule`, `Poppercam`, `ClassicCamera`, `BaseCamera`, `MouseLockController` strings; stock PlayerModule camera code is never obfuscated and PlayerScriptsLoader still requires the normal `PlayerModule`. So this is almost certainly a **custom overlay** (cutscene / lock-on / shake / spectate) layered on top of the stock camera — but the APIs, remotes, and presets are unrecoverable. Other slices' controllers should be checked for `GetController("CameraController")` calls (lock-on / shake / cutscene methods) — the export surface is not visible here.
- Evidence of camera features elsewhere in this slice: SettingsController reads `workspace.CurrentCamera.CFrame.Y` (space skybox at Y>15000); UpdateLog mentions a "Headcam fun setting" (fixed vertical movement), "custom awakening colors", camera-following roots ("keep following the camera").

What *is* visible about camera control in plaintext: (1) `CameraShaker` singleton `CurrentShaker` at `RenderPriority.Camera`, gated by `_G.Settings.ScreenShake`, with 11 custom presets (§12.2); (2) MVP cinematics (§8.2) and awakening cutscenes (Todo/Uro/Yuki/Yuta/Charles/Choso/Gojo `Chat`/`Ultimate` effects) set `Camera.CameraType = Scriptable` and drive CFrame from animation rigs in `ReplicatedStorage.Utils.<Char>.*Cutscene*`; (3) domain clash uses `PlayerGui.Main.Controls.Ultimate.Time` and full-screen `DomainFade`; (4) Sniper `SniperAim` locks first person / FOV 10; (5) Final Showdown/Roulette spectate cycles `CameraSubject`; (6) `Settings/Fun/Headcam` and `Gravity` are RenderStepped camera hacks; (7) `DomainService.CFix` compensates local movers after server teleports. Lock-on targeting is `ToolController:GetTarget(range)` (screen-space nearest-to-cursor among `workspace.Characters` within a per-moveset camera range: default 100, Hanami/Mechamaru 300, Haruta 350, Chaos 1000, Chara 60). Shift-lock is not the stock MouseLockController path: `_G.Shift` → `RotationType=CameraRelative`, `MouseBehavior=LockCenter`, manual `CameraOffset` (1.75,0,0) / mobile (2,0.75,0); lock-on lerps the camera toward `targetHRP + right*1.75` at `54*dt` (MovementController `BindToRenderStep "Cam"`). The obfuscated root `CameraController` therefore sits on top of these — its purpose remains unknown.

---

## 12. Stock / third-party libraries — stock vs modified

### 12.1 Library summary

| Library | Upstream name + version (evidence) | Files | Verdict | Notable points |
|---|---|---|---|---|
| Cmdr server root (`ReplicatedStorage/Modules/Cmdr`, `Initialize`, `CreateGui`, `Server commands/*`) | evaera Cmdr **v1.12.0** (`version.lua` returns "Cmdr Version v1.12.0") | 50 | stock | The Cmdr **server** module is sitting in ReplicatedStorage.Modules (normally ServerScriptService) so it replicated to clients. `Initialize` creates `ReplicatedStorage.CmdrClient.CmdrFunction` (RemoteFunction) and `.CmdrEvent` (RemoteEvent). `Server commands/` = stock `BuiltInCommands` renamed by Initialize; 23 of them are *definitions* (Name/Args/ClientRun) and 13 are `*Server.lua` implementations (see §3). None of these stock commands appear in `CmdrClient/Commands`, so `RegisterDefaultCommands` was **not** called — only the game's own 44 commands are registered. |
| Cmdr client (`ReplicatedStorage/CmdrClient` root, CmdrInterface, Shared, DefaultEventHandlers, built-in Types) | Cmdr v1.12.0 | 33 (77 minus 44 commands) | stock except 6 game-specific Types | Activation key **F2**; `Dispatcher:Send` → `CmdrFunction:InvokeServer(commandText, {Data=...})`; server `OnServerInvoke` caps input at 500,000 chars and runs `Dispatcher:EvaluateAndRun`; `CmdrEvent.OnClientEvent(name, ...)` → handlers "Message" (system chat "[Announcement] …", colour 249,217,56) and "AddLine". Game-specific types: `character`, `item`, `gamemode`, `reason`, `username`, plus **`Permissions.lua` = BeforeRun permission hook** (details §3). |
| CmdrClient/Commands | game-specific | 44 | game-specific | 44 admin command definitions (client copies). All use a `Group` *array* of role names (non-standard: stock Cmdr Group is a string) consumed by the Permissions hook. Only `watch` has `ClientRun`; all others run server-side (`*Server` impls not in dump). |
| Knit + wally `_Index` | sleitnick Knit **~1.5.x** (KnitClient has ServicePromises/Middleware/PerServiceMiddleware; deps comm@1.0.1, component@2.4.8, enum-list@2.1.0, input@2.3.0, option@1.0.5, signal@2.0.1, streamable@1.2.4, symbol@2.0.1, table-util@1.2.1, timer@1.1.2, trove@1.1.0, evaera promise@4.0.0) | 63 | stock | 26 files are 1-line re-exports; 13 are `*.spec` TestEZ files (dead weight). **Broken deps:** `streamable@1.2.4/Signal` & `timer@1.1.2/Signal` require `sleitnick_signal@1.5.0`, and `streamable@1.2.4/Trove` requires `sleitnick_trove@0.4.2` — neither package exists in `_Index`, so `Knit.Streamable` / `Knit.Timer` would error on require (probably unused). KnitClient waits for `ReplicatedStorage.Knit.Services` folder (Comm). |
| CameraShaker | sleitnick CameraShaker (no version string) | 3 | **modified** + game presets | `Shake/ShakeSustain/ShakeOnce/StartShake` early-return a no-op stub unless `_G.Settings.ScreenShake` is truthy; module self-starts a singleton `CameraShaker.CurrentShaker` at `Enum.RenderPriority.Camera` that multiplies `workspace.CurrentCamera.CFrame`. `CameraShakePresets` replaced entirely with 11 game presets (§4). |
| FastCastRedux | Etithespirit FastCast Redux **v14.x** (HighFidelityBehavior, TypeMarshaller, PartCache-aware) | 5 | stock | `DebugLogging=false`, `VisualizeCasts=false`. Requires `script.TypeDefinitions` which is not in the dump. |
| PartCache | Xan PartCache (v4-era, `__type="PartCache"`) | 2 | stock | Parked CFrame (0,1e7,0), ExpansionSize 10. |
| Icon (TopbarPlus) | ForeverHD TopbarPlus **v3.4.0** (`VERSION.appVersion`) | 15 | stock | Update check via `MarketplaceService:GetProductInfo(117501901079852)`. Root `Icon` ModuleScript itself is not in the dump. |
| PlayerModule | Roblox stock PlayerModule (2025 build: has `CommonUtils/FlagUtil`, `ConnectionUtil`, `AvatarAbilitiesInterface` w/ `UserAllowAbilityControls` flag, `VehicleCameraConfig`) | 28 | stock | No FireServer/InvokeServer/_G/GetAttribute/Knit/game words in any file. Missing from dump: `PlayerModule` root, `CameraModule` root, `ControlModule` root, `MouseLockController`, `TouchJump`, `TouchThumbstick`, `DynamicThumbstick`, `ClickToMoveController`, `PathDisplay` — so shift-lock / sprint / camera-override edits (if any) cannot be verified from this slice. |

### 12.2 CameraShaker presets (game-specific)

| Preset | magnitude | roughness | fadeIn | fadeOut | PositionInfluence | RotationInfluence | Type |
|---|---|---|---|---|---|---|---|
| LightHit | 4 | 7 | 0.1 | 0.75 | (0.25, 0.25, 0) | (0,0,0) | one-shot, positional only |
| MediumHit | 6 | 9.5 | 0.1 | 0.85 | (0.325, 0.325, 0) | (0,0,0) | one-shot |
| GreaterMediumHit | 6.85 | 11.2 | 0 | 0.95 | (0.395, 0.395, 0) | (0,0,0) | one-shot |
| HeavyHit | 8 | 14 | 0 | 1.25 | (0.5, 0.5, 0) | (0,0,0) | one-shot |
| Snap | 8 | 25 | 0 | 0.7 | (0.6, 0.6, 0) | (0,0,0) | one-shot, very rough |
| SnapOh | 8 | 25 | 0 | 1.4 | (0.6, 0.6, 0) | (0,0,0) | one-shot, longer Snap |
| LightLoop | 7 | 7 | 0.04 | 0.04 | (0.1, 0.1, 0) | (0,0,0) | sustained (fadeOut≈0 → used with ShakeSustain/StopSustained) |
| HeavyLoop | 7 | 12 | 0.03 | 0.03 | (0.3, 0.3, 0) | (0,0,0) | sustained |
| SmallBump | 2.5 | 4 | 0.1 | 0.75 | (0.01, 0.01, 0.01) | (0.25, 0.25, 0.25) | one-shot, rotational |
| QuickBumpSmall | 4 | 14 | 0 | 0.3 | (0.12, 0.18, 0.12) | (1.2, 1.2, 1.2) | one-shot, rotational |
| ViolenterBump | 4.5 | 13.5 | 0.1 | 0.35 | (0.3, 0.3, 0.3) | (1.4, 1.4, 1.4) | one-shot, strongest rotational |

Stock presets (Bump, Explosion, Earthquake, BadTrip, HandheldCamera, Vibration, RoughDriving) are absent; any controller referencing them would hit the `error("No preset found …")` path. `ShakeOnce(mag, rough, fadeIn, fadeOut, posInfl?, rotInfl?)` defaults: pos (0.15,0.15,0.15), rot (1,1,1). All shakes are skipped when `_G.Settings.ScreenShake` is false (settings toggle).

### 12.3 PlayerModule modification check

All 28 present files are unmodified Roblox PlayerModule sources (2025 generation: `CommonUtils/FlagUtil.getUserFlag`, `ConnectionUtil`, `AvatarAbilitiesInterface` gated on `UserAllowAbilityControls`, `VehicleCameraConfig`/`VehicleCameraCore`, `CameraUI`, `CameraUtils`, `VRCamera`/`VRVehicleCamera`). Concretely checked:
- No `FireServer`/`InvokeServer`/`OnClientEvent`, no `_G`, no `GetAttribute/SetAttribute`, no `ReplicatedStorage`/`Knit`/`workspace.Characters`, no game vocabulary (Domain/Awaken/Ult/Cursed/Mokou) in any of the 28 files.
- `BaseCamera`: default subject distance `math.clamp(12.5, CameraMinZoomDistance, CameraMaxZoomDistance)`; zoom limits read live from `Player.CameraMin/MaxZoomDistance` (stock). `ZoomController` spring `(4.5, 12.5, 0.5, max)` stock.
- `CameraInput`: stock mouse/touch/gamepad sensitivity constants (`Vector2(1,0.77)*rad(4)*60`, `*rad(0.5)`, `*rad(7)`, `Vector2(1,0.66)*rad(1)`), `GamepadCameraSensitivity`/`GetCameraYInvertValue` from UserGameSettings; no custom sensitivity multiplier.
- `Keyboard`: binds only `Enum.PlayerActions.CharacterForward/Backward/Left/Right/Jump` at `CONTROL_ACTION_PRIORITY`; no sprint/shift handling. `Gamepad`: stock (ButtonR2 activate, ButtonA jump, Thumbstick1 move).
- `TransparencyController`, `Popper`, `Poppercam`, `Invisicam`, `ClassicCamera`, `LegacyCamera`, `OrbitalCamera`, `VehicleCamera*`, `CharacterUtil`, `CameraWrapper`, `BaseOcclusion`, `BaseCharacterController`, `VRNavigation`, `VehicleController`: stock logic, no foreign identifiers.
- Therefore any shift-lock, sprint, FOV or camera-override behaviour in this game lives in game controllers (other slices) or in the PlayerModule files that are **absent from the dump** (`PlayerModule` root, `CameraModule` root, `ControlModule` root, `MouseLockController`, `TouchJump`, `TouchThumbstick`, `DynamicThumbstick`, `ClickToMoveController`, `PathDisplay`).

| File | Verdict | Evidence |
|---|---|---|
| PlayerModule (root) | **Stock** | Identical to upstream: requires CameraModule/ControlModule, GetCameras/GetControls/GetClickToMoveController |
| ControlModule | **Stock** (recent upstream w/ `UserInputService.PreferredInput`, `UserDynamicThumbstickSafeAreaUpdate` flag, VR torso estimation) | No Knit/_G/attribute/ReplicatedStorage refs; standard module map, `ControlScriptRenderstep`, VehicleController, ClickToMove fallthrough. Upstream quirk retained (`OnHumanoidSeated` uses `self.vehicleController.new`) |
| CameraModule | **Stock** (flags `UserPlayerConnectionMemoryLeak`, `UserPSFixCameraControllerReset`; ConnectionUtil; PreferredInput) | Registers Default/Follow/Classic(+CameraToggle) modes; no game edits. Note this copy is the runtime instance under `Players/SmartzyMan/PlayerScripts`, not the StarterPlayer copy |
| MouseLockController | **Stock** (`UserFixStuckShiftLock` flag) | BoundKeys `LeftShift,RightShift`, `GetMouseLockOffset` = (1.75,0,0), cursor `rbxasset://textures/MouseLockedCursor.png`, action `MouseLockSwitchAction` |

Game-specific edits inside PlayerModule: **none found**. All shift-lock/lock-on/sensitivity behaviour is layered on top by MovementController (`_G.Shift` → `RotationType=CameraRelative` + `MouseBehavior=LockCenter` + manual `CameraOffset` (1.75,0,0)/(2,0.75,0), lock-on lerp) and MovementController reads `require(PlayerScripts.PlayerModule):GetControls():GetMoveVector()` for ragdoll steering. Sub-modules not in this slice (ClassicCamera, CameraInput, Keyboard, TouchThumbstick…) could still be edited — unverified.

---

## 13. Consolidated ID register

| ID | Kind | Where | Use |
|---|---|---|---|
| 16357742 | Roblox group | `CmdrClient/Types/Permissions`, `_G.GroupId` | Role-gated admin: Owner / Developers / Head Moderators / Community Manager / Moderators / Contributors / Testers |
| 9164905432 | Place | `Permissions` (Tester role), `character` Cmdr type | Test/dev place; character autocomplete only there. Live place id **not in dump** |
| 742180133 | Gamepass | `EmoteController` | Emote slots 5–8 & 13–16 |
| 1151174294 | Gamepass | `EmoteController` | Emote page 2 + search |
| 718699461 | Gamepass | `Settings/Audio/Custom Kill Sound`, `Custom Death Sound` | Custom kill/death sound IDs |
| 857428668 | Gamepass | `Settings/General/Awakening Outfit` | Awakening outfit picker (`JoinService.Setting("Outfit", id)`) |
| 117501901079852 | Asset (TopbarPlus) | `Icon/VERSION` | Stock update check |
| 1241352401, 31070091, 174332536 | UserIds | `KnitRunClient` | Client-side `HidePlayer` hide-list (staff) |
| `imed2004` | Username | `InventoryController` | Only user shown the Skins tab; `secrettest` = "imed secret command" |
| 109651238159963 | Animation | `MokouController.SpawnAnim` | Mokou spawn intro |
| 12222253 | Sound | `SkillDefault` | Default SFX node id |
| 7992557358, 9405933217, 5480743826, 6870729295, 11829454151, 11214451393, 14809805905, 71437429504293, 2599458148, 401280105, 95498291180289, 10626050757, 15117261700, 11713358131 | Images | `JoinController`, `ToolController`, `EmoteController` | Topbar icons: Characters, Shop, Settings, Inventory, Achievements, Logs, Chat-voice, Rules, Ranked, Private server, Cmdr, Workshop, Mobile layout, Emotes |
| 129398506853336, 79537216753706 | Images | `JoinController` | Mokou and Goku ("Monkey Kid") character-select icons (gated by player attrs `Mokou` / `Goku` or `workspace.AllowOP`) |
| 125187993473697, 95602001882956, 107860751460547, 79201532345509 (vault); 98195977533316, 85222050280022 (dive); 98500512116998 (slide); 104763108763761 (climb); 94327920127463 / 113609963676386 (wall-bounce R/L) | Animations | `MovementController` | Parkour |
| 5761648082, 5639243489, 619083295, 3437778169, 5639245164, 5639245590, 5632735811, 5639244517, 5639243992, 5639245918, 7437372937 | Sounds | `MovementController` | Material footsteps |
| 8981031512, 8981031340, 8981032988 (Xbox X/Y/B); 126768975062846, 140161712330460, 137275294114393 (PS) | Images | `BeamController`, `FinalJudgementController` | QTE glyphs |
| 73458769859093 | Image | `ElbowDropController` | Todo "Woah" popup |
| ~100 key-glyph ids (8146744410–8152439938, 11903615000–11903615962, 11850722536–11850728216, 9972613363–9972618653, 15030911057–15030935337) | Images | `KeybindIcons` | Keyboard/Xbox/PS key icons |
| 124674005293931, 93359191648570, 102306667240177, 119038955627224, 5670799859, 5608359401 | Images | `Info/Tutorial` | Tutorial pages (Ragdolls, Blocking, Parkour, Burst, Throwables, Items/Shop/Combat) |
| 31173820, 31173799, 31173844, 31173863, 31173881, 31173898, 31173735, 31173771 | Sounds | `Utils/Preload/SoundFont/DrumFont` | Playable drum kit |
| 14894840794 … 14894837643 (31 ids, listed in §6.8) | Sounds | `PianoFont` | Playable piano |
| 3036987884 | Sound | `TrumpetFont` | Playable trumpet |
| 36 trigger→sound pairs (listed in §8.4) | Sounds | `RobloxChatVoice` | Chat-triggered voice clips with per-clip cooldown |
| `rbxthumb://type=Outfit&id=…` | Thumbs | Awakening Outfit | Outfit previews |
| Discord SDK 1.0.3 (build 2026-06-25, ts 1782418400) | Version | `Modules/Discord/Version` | Rich Presence stub |
| Cmdr v1.12.0, TopbarPlus v3.4.0, FastCast Redux v14.x, Knit ~1.5.x, Rules v3, game v1.82 | Versions | various | — |

No DeveloperProduct IDs, no live PlaceId, no TeleportService calls and no webhook URLs exist anywhere in the 586 files.

---

## 14. Open questions (what the dump cannot answer)

> **Partly answered since.** §16 records what live testing settled, and what it
> did not. Items 3, 4 and 5 below are narrowed there; item 1 remains open.

| # | Question | Evidence that exists | Where it lives |
|---|---|---|---|
| 1 | Does the server validate client hit lists (range, LOS, dedupe, rate)? | Client fires raw `{Model}` arrays at 20–40 Hz on 10 different Hitbox paths with zero filtering; ToolController also sends aim/airborne/target with every activation | `HitboxService` + per-char services (server) |
| 2 | ~~Key → slot binding~~ **Resolved by supplement**: `Skill N` → `char.Moveset` NumberValue with `Key==N` (AWK/AWK2 filter) → `<Service>.Activated:Fire(value, extra)`. Still unknown: **default key codes** (Keybind loader absent) and whether the server checks the value belongs to the caller | §6.9 | Keybind loader, server |
| 3 | Cooldown numbers per move | Only `char.Moveset.<Move>` attrs `ReadyAt/LastUse/Cooldown` (server-set) and v1.82 patch notes (Pebble Throw slide 7→8 s, beam clash 5→10 s) | server data |
| 4 | Damage / stun / knockback values | None client-side except patch notes (Root Rampage 30→25, Flower Field 12/14, Cursed Buds 1.25→1.7) and Mahoraga adaptation multipliers | server |
| 5 | Awakening trigger (Ultimate ≥ 100?) and Base↔Awake slot swap | Player attr `Ultimate` 0–100, `InUlt`, `UltNames` table, `Awake/` controller folders, `Chat` effects | server |
| 6 | Character unlock / purchase rules, cash economy, shop catalogue | Cmdr `cash`, `gamepass`, `emotetoken`, `code` commands; Roulette reward strings capped at 50$ in UI; UpdateLog lists 13 new emotes | server + GUI instances |
| 7 | What `AntiCheatController` checks, reports, punishes; whitelist | Fully Luraph/Owl-Fuscator VM; loaded as a normal controller; only module using `getfenv/setfenv` | runtime hook only |
| 8 | Is the decompiled `return 11-1==10 and "Owl-Fuscator…" or VM` literally a dead decoy? | Constant-folds to returning a string (module would do nothing) — almost certainly a decompiler artefact of the anti-decompile trick | — |
| 9 | Root `CameraController` API (lock-on, cutscene, shake, spectate) and who requires it | Obfuscated; returns `true` from a `task.spawn` wrapper; no plaintext controller `GetController("CameraController")` anywhere | runtime |
| 10 | Server implementations of all 44 Cmdr admin commands (`op`, `wavecheck`, `mokou`, `secrettest`, `ban` alt-detection…) | Signatures + role gates only | ServerScriptService |
| 11 | `hitbox` command lists role `Moderator` with no verifier — dead for mods? | `Permissions.lua` verifier table lacks the key | — |
| 12 | MVP title award rule (which cinematic plays for whom) | 8 cinematics; `MVP_Play(player, player:GetAttribute("MVP") or "King of Curses")` | server / inventory |
| 13 | Roulette kit ("Vow") contents, rarity odds, reward formula, EOJ 20/80 ratio logic | Kit card schema `{Title, Moveset[], Health, Author, Rarity 1–3, Index}`; patch notes | `RouletteService` |
| 14 | Night Parade mode rules | Client stub with empty `PickVows` | unimplemented / server |
| 15 | Final Showdown win condition, pipe hazard damage | Only `PipeShoot` VFX and `Transition` | server |
| 16 | Domain HP, sure-hit damage, clash weight formula, which characters own `TCMP`/`SOB`/`ML` clash codes | `Health`/`Timer` attrs; clash type table; `SOB` = "Sea of Branches" (Hanami), `ML` = `YutaDomain`, `TCMP` has an `Eye` (Megumi's Chimera Shadow Garden?) | `DomainService` |
| 17 | AL2_TP teleport destination place id | Server script stub; LocalScript is splash-only | server |
| 18 | Billboard ads: free, Robux, or admin? text filtering? | `MoneyDestroyer5000` stub; client sends `(billboard, text)` and `"Report"`; `blacklist` command covers "billboard blacklist" | server |
| 19 | Are `Custom/Archive` controllers (BoostOn2, Grapple, PuppetBarrage, UltraCannon2) and `Goku`'s copied Sukuna effects live? | Still registered by `AddControllersDeep`; server decides which Effects fire | server |
| 20 | Mokou / Chara / Chaos ("S") — unreleased, event, or admin-only characters? | `UltNames` entries with no `ListData` row; `mokou` Cmdr command = temporary whitelist | server |
| 21 | Uro incomplete (3 moves, no special, no awakening kit) | ListData + UpdateLog "SKY ASSASSIN new skills" | — |
| 22 | Do `Knit.Streamable`/`Knit.Timer` ever get required? (broken `_Index` deps would error) | No controller in dump requires them | — |
| 23 | Custom-move `CONNECT` node "SIGNAL" semantics, `DUR` durability target | Node schema only | server executor |
| 24 | Settings defaults and persistence path | `Val` keys → `_G.Settings`; blob pushed by `JoinService.Setting("Batch")` | `JoinService` |
| 25 | Where `DiscordClient.setActivity` is called (Rich Presence wired at all?) | `isReady()` never true; no caller in dump | server / missing controller |
| 26 | Health/regen script logic | 12 identical `Health` stubs (server `Script` per character) | server |
| 27 | ~~Missing PlayerModule pieces~~ **Resolved**: root, `ControlModule`, `CameraModule`, `MouseLockController` are stock; shift-lock/lock-on are layered in `MovementController` (`_G.Shift`). Sub-modules `ClassicCamera`/`CameraInput`/`Keyboard` were already verified stock | — | — |
| 28 | Does the server accept the client-reported HRP CFrame stream (`AntiCheatService.Camera`) as authoritative, or only for validation? What is the `NaN` 4th arg (tamper canary?) and the `Teleport` token contract? | Client applies received CFrames verbatim to others; own position sent every Stepped | `AntiCheatService` (server) |
| 29 | Server-side cooldown/stun enforcement for skills, dash (`ResetDash` implies a server CD), parkour (`Parkour:Fire()` carries nothing), WalkSpeed | Zero client gates; `ReadyAt` is display-only | server |
| 30 | QTE (beam clash / Final Judgement) expected-press count and rate limit; mobile path never sends a miss | Client picks the key locally | `BeamService`, `FinalJudgementService` |
| 31 | Who sets `MovementController.LockOn` besides the gamepad `Lock On` action; `CopyController.SelectRemote` wiring | Only ToolController gamepad path seen | — |
| 33 | Who calls `RouletteController/FinalShowdownController/NightParadeController:Start()`? No client caller exists in either dump | `Start()` defined alongside `KnitStart`; no `GetController("RouletteController")` anywhere | undumped GUI script or obfuscated VM |
| 32 | `Modules.BuilderFX` (custom-move visual runtime), `EmoteController.Effects`, `Keybind` loader | Required but absent | extraction gap |

---

## 15. Coverage checklist

| Bucket | Files | Read | Notes |
|---|---|---|---|
| Moveset controllers (`Controllers/Moveset/*`) | 196 | 196 | 25 character folders; every file catalogued in Appendix A.1–A.5 |
| Character/Join controllers + KnitRunClient + loader + root CameraController | 9 | 9 | 2 obfuscated (AntiCheat, CameraController) — read, not decodable |
| Core controllers (Hitbox, Debug, Discord ×2, Domain, FX, Item, Ranked ×3) | 10 | 10 | |
| Workspace / StarterPlayer / root stubs | 24 | 24 | 17 are bytecode-less server stubs (listed once in §1) |
| `ReplicatedStorage.Utils` helper scripts | 17 | 17 | |
| `ReplicatedStorage.Modules` game-specific | 74 | 74 | ListData transcribed in full |
| `ReplicatedStorage.Modules` third-party (Cmdr server 50, Icon 15, FastCast 5, PartCache 2, CameraShaker 3) | 75 | 75 | stock-vs-modified verdict per file |
| `ReplicatedStorage.CmdrClient` | 77 | 77 | 44 game admin commands read fully |
| `ReplicatedStorage.Knit` (+`_Index`) | 63 | 63 | 9 files in 4 content-dupe groups |
| `PlayerScripts.PlayerModule` | 28 | 28 | all stock |
| Supplement `missing_deps.zip` — new scripts | 13 | 13 | 155 files in zip; 142 content-duplicates of already-covered files skipped (0 new stubs, 0 obfuscated) |
| **Total unique** | **586** | **586** | 567 readable game/library files fully analysed; 17 stubs; 2 obfuscated |

Cross-checks performed: file partition covered 573/573 (+13/13 supplement) with 0 overlaps; supplement deduped against the main dump by comment/whitespace-normalised MD5; MD5 and whitespace/comment-normalised hashes; global greps for `FireServer`/`InvokeServer` (42/10 sites, all attributed above), `GetService("*Service")` (210 Knit services ↔ 210 controllers), `GetController` (5 controllers referenced but absent), `Get/SetAttribute` (all names folded into §3.4), `_G.*`, `rbxassetid://` (0 hits), numeric gamepass/place/user ids.

---

## Appendix A — Per-file catalogue (every file, once)

Columns: path (from header) · type · lines · Knit name · services · client→server calls (decoded) · server→client signals handled · client-auth hit report? · notes. Server-stub and dupe files are listed in §1 / A.9.

### A.1 Movesets: Charles, Choso, Custom, Gojo, Goku (36)

| # | Path (from header) | Type | Lines | Knit name | Services used | Client→server calls | Server→client signals handled (Effects keys) | Client-auth hit report? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Controllers/Moveset/Charles/CharlesController | ModuleScript | 686 | CharlesController | CharlesService; ctrl: HitboxController, FXController | none | Hit(atk,victim,idx), ChaseHit(atk,victim), Chase(char), Swing(char), Swing2(char,count,dir "Up"/"Down"), Launch(char,dy), Startup(char), UltimateNo(instance,atk,victim), Ultimate(instance,atk,victim), Dead(char), Mark(char,fromPos,markInst), Future(char,player,dir "Left"/"Right"/"Back"), Perfect(char) | No | M1 hit sound `Sounds.Charles.M1.Hit<idx>`; Swing2 color lerps white→RGB(85,0,0) by `player:GetAttribute("Ultimate")/100`; weapon `char.SetAssets.GWarstaff` (also `GWarStaff` at 7.7s — casing mismatch, likely dead branch) gets `Utils.Charles.CombatTrail`. **Ultimate** = counter cutscene: camera Scriptable, frames from `Utils.Charles.CounterCutscene.Frames/<n>` + `.FOV/<n>` at 60 fps, lerped 0.8s; timed FX table (1.1 Todo.Swing, 1.733 Gojo.Twofold, 1.917 Hiromi.Shockwave, 2.383 Afterimage clone w/ `Animations.Charles.UltimateAfter` + ColorCorrection desat, 13 ParryFX deflects 5.283–7.1s alternating L/R arm, 7.7 ParryFX.Glow on staff, 8.15 `Utils.Charles.HitEnd`); ends with ExposureCompensation 2→0 + Snap shake. **UltimateNo** = same first 2 beats only (whiff). **Mark**: `Utils.Mahito.Dash` line + `Utils.Charles.Mark` welded to Torso, 30 s, fades when markInst removed. **Future**: afterimage dash (`Animations.Misc.Movement.DashLeft/Right/Back`, 12 studs) local-only for owner; others get AutoRotate off 0.7s. **Perfect**: perfect-dodge; `Utils.Damage.HitGlow` black, `Animations.Hiromi.Dodge` random 1-5, stops tracks named Dodge1-5 when `Info` gets child `Stun` or `InSkill`. Dead: Bleed + 40 BloodyZee. Sounds: Charles.{M1,UltStart,Ult,UltVoice}, Misc.Chase, Misc.Swing.Fist, Megumi.Mahoraga.Throw.Break, Itadori.ManjiKick.Dodge. Accessory meshes rebuilt via `AssetService:CreateMeshPartAsync`. |
| 2 | Controllers/Moveset/Charles/DespairController | ModuleScript | 198 | DespairController | DespairService; FXController | none | Startup, Spin, Swing, Swing2, Barrage(char,inst), Hit, Hit2, Die | No | Spin/Swing/Swing2 sounds `Sounds.Charles.Despair.*`; Swing uses `Utils.Choso.CounterSwing`, Swing2 `Utils.Todo.Swing` scaled 1.4. **Barrage**: loops every 0.025s spawning `Utils.Charles.Barrage` arm clones (copies victim's Shirt + Left Arm color, has `GWarstaff` part) thrust 7 studs, until `inst.Parent==nil`. Hit random Despair.Hit1-3; Hit2 Hit3. **Die** = finisher: Hiromi.Verdict.Hit2, `Utils.Locust.Slam` (EmitCount attr), 20 blood, SnapOh shake <100 studs. |
| 3 | Controllers/Moveset/Charles/EyeCatchController | ModuleScript | 77 | EyeCatchController | EyeCatchService; FXController | none | Hit(player,victim), Fade(char) | No | Hit: HeavyHit shake; Fade: black `Utils.Damage.HitGlow` afterimage + Itadori.ManjiKick.Dodge + Charles.EyeCatch.Dodge (dodge/feint move). |
| 4 | Controllers/Moveset/Charles/SacrilegiousController | ModuleScript | 189 | SacrilegiousController | SacrilegiousService; FXController | none | Startup, Stab(player,victim), Dialog(char,idx), Hit(player,victim), Spin, Hit2(player,victim), Dash(char,fromPos) | No | **Dialog** billboard `Utils.Charles.Dialogue` text idx1 "STOP DESECRATING THIS WORK!!" idx2 "DID YOU EVEN READ THE ORIGINAL PROPERLY!?" (offset left/right). Stab: Hiromi.Execution.Stab. Dash: Mahito.Dash line from fromPos, Itadori.RushWind (scaled 0.6), 3× Itadori.Shock, sounds Yuki.Swing + Charles.Despair.Swing. Hit/Hit2 sounds Charles.ShutUp.Hit/Hit2 (shared with ShutUp). Spin: Charles.Throw. |
| 5 | Controllers/Moveset/Charles/ShutUpController | ModuleScript | 171 | ShutUpController | ShutUpService; FXController | none | Startup, Throw, Swing, Hit(victim), Hit1(player,victim), Hit2(player,victim), Jump, Crush(player,pos) | No | Hit: Flash 1s, ShutUp.Stab then 0.7s later ShutUp.Throw (stab→throw grab). Swing: `Utils.Charles.StabWind`. Jump: Gojo.Twofold 24-stud ring + Misc.Swing.Fist3. Crush: Hiromi.Shockwave + Choso.CounterSwing.Shock column, Itadori.CrushingBlow.GroundImpact. |
| 6 | Controllers/Moveset/Choso/Awake/BloodRainController | ModuleScript | 157 | BloodRainController | BloodRainService; FXController | none | Startup, Hit, Rain(char,inst) | No | Startup: `FX:DomainBurst(hrp)` + Choso.BloodRain.Start. **Rain**: `Utils.Choso.BloodRain` beam follows Torso; Flow.Rate = 400 × `LocalPlayer:GetAttribute("Ultimate")/100`; owner gets ColorCorrection desat scaled by ult; sustained HeavyHit <120 studs; every 2nd step raycasts 4 `Utils.Choso.RainDrop`s (±35 studs, `_G.MapParams`) <300 studs; ends when inst removed (BloodRain.End). Hit: Itadori.Dismantle.Slash. Loop sound BloodRain.Loop. |
| 7 | Controllers/Moveset/Choso/Awake/PlasmaWaveController | ModuleScript | 307 | PlasmaWaveController | PlasmaWaveService; FXController | none | Startup(char,inst), Clap, Fire(char,beamPart), FinalHit(player,victim), BeamClashing(beamA,beamB) | No | Startup: `Utils.Choso.Switch` eye GUI on Head + 15 `Utils.Choso.Convergence.Blood1` cubic-bezier swarm (<150 studs). **Fire**: `Utils.Choso.PlasmaWave` positioned from `beamPart:GetAttribute("BeamStartCFrame")` *CF(0,0,-62); End tweens to `-BeamLength/2` on `BeamLength` attr change; owner FOV 70→120→70; `_G.Settings.Flash` gates BlackFlashCC white flash; sustained HeavyHit <180 studs. **BeamClashing**: `Utils.Choso.PlasmaWaveClash` at BeamStart*(-BeamLength) while both beams alive (beam-clash mechanic). FinalHit: Hakari.RoughHit recolored RGB(150,0,0). Sounds Choso.PlasmaWave.{Swarm,Fire}, Choso.PiercingBlood.{Clap,Fire}, Choso.BloodRain.End, Hakari.OverLuck.Hit2. |
| 8 | Controllers/Moveset/Choso/Awake/SlicingExorcismController | ModuleScript | 224 | SlicingExorcismController | SlicingExorcismService; FXController | none | Saw, Interp(proj), Hit(atk,victim), Hit2(victim), Reflect(proj), Finisher, Flashup(char,attachHolder), Blood(char,attachHolder,stage 1-4) | No | **Interp**: client-side projectile extrapolation 150 studs/s via `BulkMoveTo` from last replicated Position, stops when Transparency==1; loop sound Choso.SlicingExorcism.Saw. **Reflect**: `proj.Center.Sparks`, LightHit <140 (saw bounces). **Blood**: PiercingBlood beam held `{0,0.5,1,1.5}[stage]` s, feeds from attachHolder beams; Flashup swaps emitters to `Utils.Choso.Supernova.Blood1`. Finisher: Bleed + Dismantle.Explode. Sounds: Choso.{Convergence,BloodBurst}, Itadori.CursedStrikes.Spin, Mahito.CrushingRushdown.HairPull, Mahito.DrillSplit.Drill, Choso.PiercingBlood.{Fire,Hit}. |
| 9 | Controllers/Moveset/Choso/Awake/WingKingController | ModuleScript | 322 | WingKingController | WingKingService; ctrl: HitboxController (unused), FXController | none | Dash(char,bodyMover), Swing(char,idx 1-7), Swing2, Hit(player,victim,_), FinalHit, Hit2, Crush(pos), Interp(proj,fxHolder), Retract(char,beamPart), GrabArm(char,victim,beamPart) | No (but client drives own velocity) | **Dash**: for owner, sets `bodyMover.Velocity = Look*30→0` over 3s (client-side movement). Swing 1-7 = 7-hit combo with ArmFlash RGB(170,0,0) and Todo.Swing/StabWind alternation. Crush: Megumi.Mahoraga.Earthquake + WorldSlash mesh, DustBreak radius 12. **Interp**: 200 studs/s extrapolation, beam CurveSize elastic. Retract/GrabArm: blood-arm beam clone lerps back to Left Arm (blood whip grab). Sounds Hakari.OverLuck.{Dash,Hit1,Hit2}, Mahito.WideSPStrike.Crush/Crush2, Misc.Swing.Fist3. |
| 10 | Controllers/Moveset/Choso/Base/BloodEdgeController | ModuleScript | 143 | BloodEdgeController | BloodEdgeService; ctrl: HitboxController (unused), FXController | **`landRemote:FireServer(hrp.Position + Look*1.5)`** in Dash (owner only) | Draw, Swing, Dash(char,_,landRemote), Hit, FinalHit, Crush(player,pos) | **Position report** (client decides landing point after ground raycast; not a hit list) | Dash: waits 0.5s then raycasts down 6 studs (Include Map/Spawns/Domains) each frame; when ground found fires remote with landing pos. Hit: 2× BloodyZee <150. Crush: Itadori.CrushingBlow recolored red + Choso.CounterSwing pinkish. Sounds Mahito.DrillSplit.Unmorph, Choso.BloodEdge.{Dash,StabHit}, Mahito.CrushingRushdown.Leap, Itadori.CursedStrikes.Hit, Itadori.CrushingBlow.GroundImpact. |
| 11 | Controllers/Moveset/Choso/Base/PiercingBloodController | ModuleScript | 146 | PiercingBloodController | PiercingBloodService; FXController | none | Startup, Clap, Blood(char,charged?), Hold(char,inst), Flash, Hit | No | Blood: `Utils.Choso.PiercingBlood` beam 30 studs (60 if charged), Blood.Speed 10-400 when charged, 4× Itadori.Shock at 7 (14) stud steps. **Hold**: red Flash 1s + `Utils.Choso.Concentrate` on `Right Arm.RightGripAttachment` until inst destroyed (charge hold). Flash: `Utils.Choso.Flash` + PiercingBlood.Pressure. Hit: red Flash. |
| 12 | Controllers/Moveset/Choso/Base/RedScaleController | ModuleScript | 206 | RedScaleController | RedScaleService; ctrl: HitboxController (unused), FXController | none | Leap(char,part), Crush(player,pos), Launch(char,fromPart?), Swing, Dash(char,cframe), Hit(atk,victim,final?,variant 1/2), FinalHit(atk,victim,burst?) | No (client applies own velocity) | **Launch**: client sets `hrp.Velocity` — toward-from-part impulse `(1-dist/20)*200` (Y clamped ±100) or straight up 150. Leap: `part.Position = hrp+12` (client positions server part?), Gojo.HardHit.Ring emitter. Hit: Itadori.M1.Hit1-4 or CursedStrikes.Hit; variant1 Mahito.BodyRepel.Wind5. FinalHit burst: `Utils.Choso.BloodExplode` + Choso.BloodBurst2. Dash sounds Itadori.Rush.Rush + Gojo.ReversalRed.Aim. |
| 13 | Controllers/Moveset/Choso/Base/SupernovaController | ModuleScript | 158 | SupernovaController | SupernovaService; ctrl: HitboxController (unused), FXController | none | Start, Throw, Hit(atk,victim), Burst(part), CounterHit(char,other), Hit1(atk,victim), Hit2(atk,victim), Finisher | No | **CounterHit**: Choso.Counter sound, `Utils.Choso.CounterHit` + BlackFlashHit.Wind2 (Supernova doubles as counter). Hit2: 4× Itadori.Shock along victim velocity + CounterSwing. Burst: BloodExplode. Finisher: Bleed. Sounds Itadori.ManjiKick.Dodge, Itadori.DivergentFist.Swing, Mahito.Chainwhip.Hit, Mahito.Stockpile.Swing, Hakari.EnergySurge.Hit2, Choso.BloodBurst/BloodBurst2. |
| 14 | Controllers/Moveset/Choso/ChosoController | ModuleScript | 332 | ChosoController | ChosoService; ctrl: HitboxController (unused), FXController | none | Hit(char,idx), ChaseHit, Chase, Swing, Swing2(char,count 1-4,dir), Launch(char,dy), BloodStart, Convergence(char,merge?), Interp(proj), HomingHit(victim), Chat(char) | No | M1 sounds `Sounds.Choso.M1.Hit<idx>`; ChaseHit uses Gojo.M1.Hit3. Swing2 ArmFlash RGB(255,0,0): 1/Up=R arm, 2=L arm, 3/Down=R leg, 4=L leg. **Interp**: projectile extrapolated at `proj:GetAttribute("Speed")` studs/s (homing blood orb); HomingHit Hakari.RoughHit red. **Chat** = awakening: Choso.Awaken, `Utils.Choso.Switch` eye GUI, `Utils.Choso.BloodSpread` 80, 3× `Utils.Choso.Brother` ghost models (−35°/+35°/0°, AnimationController.Animation), `Utils.Choso.Dialogue` Text1/Chat1 (text baked in template). Sounds Gojo.BlindsOff, Choso.{BloodMerge,Convergence}, PiercingBlood.{Fire,Pressure2,Hit}. |
| 15 | Controllers/Moveset/Custom/Archive/BoostOn2Controller | ModuleScript | 290 | BoostOn2Controller | BoostOn2Service; ctrl: HitboxController (unused), FXController | none | BoostEnabled(char,inst), BoostLandEnabledTrue, DisableBoosters(boosterR,boosterL), Hit, DashStart, DashEnd, Punch, PunchHit, BoostOnOffload(char,_) | No (client drives own velocity) | Mechamaru "Boost On" (archived). **BoostEnabled** owner: BodyVelocity MaxForce (40000,1750,40000) speed 125→5 over 1s, re-boost 20→0 when `char.Info.BoostOnHold` BoolValue changes; cleaned when inst removed; `inst:GetAttribute("End")` → SecondPart sound. Booster models `char.BoosterR/BoosterL` with `Arm BoostterrrrR/L` union `.Stage1/.Stage2` emitter groups; `Booster:GetAttribute("Disabled")`. Uses **SraikoVFX** (`Enabled`, `Emit`, `HandleMesh(mesh, cf, {Weld=})` returns lifetime) with `Utils.Mechamaru.BoostOnVFX.*` (BoostDash, BoostEnabled, BoostRepeat.Meshes, BoostHit, BoostLandEnabled, Offload.VFX.{BoostRepeat.Meshes.Loop1-3, BoostDash, BoostThrow}). Sounds Mechamaru.BoostOn.{Booster,SecondPart,Start,PunchWoosh,Hit,DummyThrow}. |
| 16 | Controllers/Moveset/Custom/ChaosController | ModuleScript | 259 | ChaosController | ChaosService; ctrl: HitboxController (unused), FXController | none | Form, Boost, Melee(char,target), MeleeHit, Interp(proj), HomingHit, On() | No (client moves own HRP in Melee) | Character "S"/Chaos (assets `Utils.Misc.S.*`, `Sounds.Misc.S.*`). Form: 7 orbiting `Utils.Misc.S.C` parts (51.43° apart) expand to 8 studs, 2 s, HeavyHit <100. Boost: `Misc.S.Boost` trail + 30 Mahito.BodyRepel.Wind1-5 rings. **Melee**: client lerps `hrp.CFrame` toward `target.HRP - Look*3` for 0.3s with random jitter (client-side teleport-rush; applies to any viewer's copy of `char`, so non-owners move a replicated model locally). Interp: Speed-attr projectile (same code as Choso). On(): global sound `Misc.S.On`. Sounds Misc.S.{Form,Dash,Dash2,Hit.Hit1-2,OrbHit,On}. |
| 17 | Controllers/Moveset/Custom/Archive/GrappleController | ModuleScript | 200 | GrappleController | GrappleService; ctrl: FXController, JoinController | none | Jump(anchorPart,bodyPos,dirVec), Grapple(char,stateIntValue,targetPart), Grab(char,victim), GrabHit, Hit(player,victim) | No (client moves own HRP) | Hiromi gavel grapple (archived). **Jump** owner: tweens `bodyPos.P`→50000 and sets `bodyPos.Position = anchor - dir*5`, faces dir; non-owner: writes `JoinController.lastRecvServer[char] = false` and lerps HRP (client-side interpolation override). **Grapple**: weapon `char.SetAssets.Gavel` (parts hidden, `.A` attachment, `.Extensions`), `LightningBeams.new(gavel.A, target.RootAttachment, 5, model)` wood-colored RGB(90,76,66) chain; `state.Value==2` triggers radius pulse; ends w/ `Utils.Hiromi.GavelFire`. Sounds Hiromi.Grapple.{Fire,Start}, Gojo.LapseBlue.Grab, Hakari.EnergySurge.Hit1. Grab FX: Itadori.CounterHit.Feint recolored RGB(255,195,134); Hit: Mahito.CrushingRushdown.DrillImpact yellow. |
| 18 | Controllers/Moveset/Custom/Mokou/Mokou1Controller | ModuleScript | 124 | Mokou1Controller | Mokou1Service; ctrl: FXController, ToolController (unused) | none | Startup, Swing(char,idx 1-3), Hit(player,victim), Hit2(player,victim) | No | Slash move: `Utils.Misc.M.Slash` welded arc at 3 angles; idx1 plays voice `Sounds.Misc.M.Mokou1Voice` (Voice group). Hits: Mahito.Soulfire.Hit + Gojo.Twofold.Sparks. |
| 19 | Controllers/Moveset/Custom/Mokou/Mokou2Controller | ModuleScript | 161 | Mokou2Controller | Mokou2Service; ctrl: FXController, HitboxController | **`remote:FireServer(hitsTable|false, groundPos|nil)`** from `Service.Hitbox` handler | Effects: Startup, Dive(char,inst), Hit(player,victim), Crush(player,pos). Extra RemoteSignal **`Mokou2Service.Hitbox(inst, char, remote)`** | **YES** — loop every 0.025s: `SphereHitbox(char, CF(0,-5,-5), 8)` + downward-forward raycast (Map/Domains); fires hits and/or ground hit pos; destroys inst on ground contact | Dive kick: `Utils.Misc.S.Boost` trail scaled 0.5 (reused from Chaos). Crush: Hiromi.Shockwave + `Utils.Misc.M.DashHit` (EmitCount attrs) + red PointLight. Sounds Misc.M.{Kick,Mokou2Voice,KickHit}. |
| 20 | Controllers/Moveset/Custom/Mokou/Mokou3Controller | ModuleScript | 179 | Mokou3Controller | Mokou3Service; ctrl: FXController, HitboxController (unused) | none (but owner moves server part locally) | Startup, Pillar(char,ctrlPart), Hit(player,victim) | No (client steers `ctrlPart.Position` with `PlayerModule:GetControls():GetMoveVector()` at 70 studs/s relative to camera — client-authoritative steering of a physics part while char is invisible) | Fire pillar / "Scorchrise": Hiromi.Shockwave scale 35, `Utils.Misc.M.FirePilla` (Tornado, "1"."1-3" beams, "2"), `Utils.Misc.M.fireballstartup` follows HRP, char parts made transparent until ctrlPart removed (then Explode emitters, Scorchrise2). Sounds Misc.M.{Scorchrise,Scorchrise2,Mokou3Voice}, Hiromi.Grapple.Energy. |
| 21 | Controllers/Moveset/Custom/Mokou/Mokou4Controller | ModuleScript | 163 | Mokou4Controller | Mokou4Service; ctrl: FXController, HitboxController (unused), ToolController | **`aimRemote:FireServer(targetChar)`** or **`aimRemote:FireServer(aimPos:Vector3)`** every 0.02s in Startup while remote alive | Startup(char,aimRemote), Barrage, Interp(inst,startCF), Hit | **Aim/target report** (client picks `ToolController:GetTarget(100)` lock-on or mouse raycast 300 studs excluding other chars) | Talisman barrage: `Utils.Misc.M.Barrage` welded, ArmFlash RGB(255,85,0) both arms. **Interp**: `Utils.Misc.M.Talisman` flies 200 studs/s for ≤0.4s, raycast `_G.MapParams`, sticks & shrinks on wall. Hit: `Sounds.Misc.M.M1.Hit1-4` + `Utils.Misc.M.Hit` orange RGB(255,85,0). Sounds Misc.M.{Charm,Mokou4Voice}. |
| 22 | Controllers/Moveset/Custom/Mokou/MokouController | ModuleScript | 785 | MokouController | MokouService; ctrl: HitboxController, FXController | **`remote:FireServer(hitsTable|nil, hrp.CFrame)`** from `Service.Hitbox` handler | Effects: Hit(char,idx), ChaseHit, AerialHit, Chase, Swing2(char,count 1-5,dir), Launch(char,dy), Revive(player,inst,cframe), Wing(char,boolValue), WingFly, Interp(cfValue,startCF,duration,template), Kill, Awaken. Extra RemoteSignal **`MokouService.Hitbox(inst, char, remote)`**. Also exports `SpawnAnim = "109651238159963"` and `SpawnFunc = {Startup(char,cleanupTbl), Hitbox(char,cleanupTbl)}` | **YES** — loop every 0.05s: `SphereHitbox(char, CF(0,0,-4), 8)`, accepts targets whose `Info.Knockback` ≠ false; tweens inst's NumberValue→0 on hit; fires hits (or nil) + HRP CFrame | Character controller for Mokou (Touhou). M1 sounds `Sounds.Misc.M.M1.Hit<idx>`, `Utils.Misc.M.Hit` orange, idx4 emits Flames. Swing2 sounds `Misc.M.Swing[1-4]`, ArmFlash RGB(255,85,0). AerialHit: Itadori.CraniumSmash.Hit2 + Gojo.HardHit. **Revive** (phoenix resurrection): owner camera Scriptable until inst removed, then Highlight RGB(255,255,127)→black/red, `Utils.Misc.M.Revive` (Activate/Explode groups w/ EmitCount/EmitDuration attrs), Snap sustain <150. **Wing**: `Utils.Misc.M.wing` on Torso (prewing → Left/right on boolValue change) until boolValue leaves `workspace.Characters`. WingFly: `Utils.Misc.M.WingFly` (WHAT, Mesh/Mesh2/Mesh3 Start→End). Interp: generic template clone rotated by `cfValue.Value` per frame for `duration`. **Kill**: char invisible, `Utils.Misc.M.TouhouBurst`, owner ExposureCompensation 3→0. **Awaken**: ~10 s scripted ult intro using `Utils.Misc.M.Awk.{Att, mokultMeh.1-3, melting, Pre, meshUP, GETIN}` + `ArcTween` helper (template attrs `StartTransparency`, `Duration`, `Part_TweenParams`/`Mesh_TweenParams`/`Decal_TweenParams` "Style,Direction"), sound Misc.M.MokouUlt. **SpawnFunc.Startup**: Misc.M.MokouSpawnVoice/MokouSpawn, `Utils.Misc.M.SnapArm`, `Modules.TekrinnDialogue.Speak` lines "I'll show you the legendary phoenix..." (0.08 type speed) then 3.8s later "that grows stronger each time it's reborn." (shake on). SpawnFunc.Hitbox: `Utils.Misc.M.FlameArm` on Left Arm + Hiromi.Shockwave. |
| 23 | Controllers/Moveset/Custom/Archive/PuppetBarrageController | ModuleScript | 265 | PuppetBarrageController | PuppetBarrageService; ctrl: HitboxController, FXController | **`remote:FireServer(hitsTable|nil, hrp.CFrame)`** from `Service.Hitbox` handler | Effects: StartFly, PowerFly, Dive, DiveHit, Grab, Kickup. Extra RemoteSignal **`PuppetBarrageService.Hitbox(inst, puppetChar, remote)`** | **YES** — same loop as Mokou (r=8, CF(0,0,-4), 0.05s) but excludes `puppetChar.Owner.Value`, `.User.Value`, `.Friend.Value` (ObjectValues) and requires `Info.Knockback` ≠ false | Mechamaru puppet (archived). StartFly: clones `Utils.Mechamaru.BoosterL/R` onto arms via Motor6D C0 (0,0.75,0.625)·Angles(45°), Stage1 emitters, 3 s. requires EffectUtils, Trove (unused). Sounds Mechamaru.PuppetBarrage.{FlyUp,Grab,Kick}. |
| 24 | Controllers/Moveset/Custom/Archive/UltraCannon2Controller | ModuleScript | 314 | UltraCannon2Controller | UltraCannon2Service; ctrl: HitboxController (unused), ToolController, FXController | none (client sets `aimPart.Position`/BodyGyro locally) | Aerial(char,aimPart), Start(char,inst), ChargeStart(char,inst), AlbatrosStart(char,inst), AlbatrosCharge(char,inst), AlbatrosFire(char,inst), AlbatrosHit, FireCannon(char,proj), ProjectileCancel(proj), ProjectileExplode(proj) | No | Mechamaru Ultra Cannon / "Albatros" (archived). **Aerial**: BodyGyro P 10000 aims at `ToolController:GetMouseTarget()` or `aimPart:GetAttribute("Aim")`, PlatformStand while aimPart alive. Uses **EffectUtils** (`AutoEffects`, `Enable(classes, template, parent, dur, destroy?)`, `AutoMeshes`, `Visibility`, `Tween`) + **Trove** (`AttachToInstance`, `Clone`, `Add`). `char:GetAttribute("Moveset") ~= "Mechamaru"` hides `Utils.Mechamaru.["Hand blasterL"]`, `["Mecha mouth blaster"]`, `Booster%s` accessories (skill usable by non-Mechamaru movesets). AlbatrosFire: 21 × 0.07s beam raycast 37.5 studs `_G.MapParams` resizing `AlbatrosFire.Beam/Enable`, `AlbatrosRepeat.ConeSwirl` (attrs RepeatCount/RepeatDelay), emitter `MaxSpeed` attr. FireCannon: projectile extrapolated 180 studs/s. Sounds Mechamaru.UltraCannon.{Start,Albatros,Shoot,Explode}. Shake presets LightLoop, MediumHit. |
| 25 | Controllers/Moveset/Gojo/Awake/HollowPurpleController | ModuleScript | 224 | HollowPurpleController | HollowPurpleService; ctrl: FXController, ToolController | none | Aerial(char,aimPart), Purple(char,holder), Launch, Interp(proj), Hit, Finisher | No | Aerial: BodyGyro aim at mouse, PlatformStand, aimPart +6 Y. **Purple**: plays `Sounds.Gojo.HollowPurple.Music` (Music group, vol 1.25) if no `workspace.Music`; `Utils.Gojo.HollowPurple.Blue/Red` orbit-merge 1 s → `Purple` sphere 15 studs + Warp highlight; sustained LightHit for owner. Launch: `PurpleSnap.Center` on Right Arm. Interp: 200 studs/s. Hit: Flash RGB(255,85,255) 2 s. **Finisher**: victim invisible except legs + `Utils.Damage.LegBurn` (legs-only death). |
| 26 | Controllers/Moveset/Gojo/Awake/LapseBlueMaxController | ModuleScript | 339 | LapseBlueMaxController | LapseBlueMaxService; ctrl: FXController, ToolController | none | Effects: Aerial, BlueGrab, Blue(char,attachment), PurpleHit, Finisher(victim,holder), Finisher2. Extra RemoteSignal **`LapseBlueMaxService.Debree(partDataList, attachment)`** | No | **Blue**: `Utils.Gojo.LapseBlue.LapseBlueMax` AlignPosition to server attachment; `attachment:GetAttribute("Grab")` true → grows to 10, Responsiveness 20 (owner) / 70; `GetAttribute("Purple")` → converts to `Utils.Gojo.HollowPurple.PurpleMax` (Blue+Red→Purple Max), 2.5 s charge, Lightning, explode to 150 studs, ExposureCompensation 10→0 <150, HeavyHit sustain 4 s. Sounds Gojo.LapseBlue.{Grab,Wind,Absorb}, Gojo.HollowPurple.{Smash,Music2,Summon,MaxCharge,Explode,Hit}. **Finisher**: victim invisible, 2 `Utils.Damage.Chunk` per limb pulled into holder.Parent by AlignPosition; `_G.Settings.Gore==false` recolors chunks purple. Finisher2: `FX:Burn`. **Debree**: only if `_G.Settings.DesPHY` and <75 studs: spawns parts from `{pos, orientation, color, material, size}` tuples, sucked to attachment (`BlueGrab` attachment name), 10% `DebreeSound`. |
| 27 | Controllers/Moveset/Gojo/Awake/ReversalRedMaxController | ModuleScript | 301 | ReversalRedMaxController | ReversalRedMaxService; ctrl: FXController, ToolController | none | Aerial (aimPart +12 Y), Swing, Red(orbPart), Fire(char,cframe), Explode(pos), Hit, Music, BlackFlashImpact(atk,victim), BlackFlashHit(atk,victim), Finisher | No | Red: orb tween + Beam widths, MaxCharge sound. Fire: `Utils.Gojo.ReversalRed.RedMaxFire` at cf·(0,1,-55) → 100-stud beam; `_G.Settings.Flash` BlackFlashCC strobe. Hit: Gojo.M1.Hit1-4. **Music**: `Sounds.Gojo.Remember` (Music group). **BlackFlashImpact/BlackFlashHit**: Itadori DivergentFist BlackFlash assets (FinisherDrag, BlackFlashLaunch, BlackFlashCC inverted, FOV 70→40→70, `Utils.Gojo.BlackFlashHit` w/ BillboardGui disabled), Mahito.BlackFlash sound, ExposureCompensation 2→0. Finisher: Bleed. |
| 28 | Controllers/Moveset/Gojo/Base/LapseBlueController | ModuleScript | 318 | LapseBlueController | LapseBlueService; FXController | none | LapseBlue(char), BlueGrab(victim), Grab(atk,victim,inst), Hit(atk,victim), Finisher(partDataList,origin,center,victimsList) | No | LapseBlue: `Utils.Gojo.LapseBlue.LapseBlue` welded orb 0.3 s + Grab ring. Grab: travel delay `dist/60` then `Utils.Gojo.LapseBlue.Infinity` + Infinity sound. Hit: Itadori.CraniumSmash.Hit2 + Gojo.HardHit. **Finisher**: pads debris list to 15 (Ground RGB(86,66,54) 2×2×2) / caps 40; parts bezier-converge on first victim's HRP over 0.3-0.8 s, every 7th plays Mahoraga.M1.Hit3-4 + blood; at 1.5 s victims made invisible, parts implode; `_G.Settings.DesPHY` → parts unanchored, CollisionGroup "Effects". Sounds Gojo.LapseBlue.{LapseBlue,Grab,Infinity,Absorb}, Megumi.Mahoraga.Throw.{Throw,Break}. |
| 29 | Controllers/Moveset/Gojo/Base/RapidPunchesController | ModuleScript | 100 | RapidPunchesController | RapidPunchesService; FXController | none | Hit, FinalHit, BlackFlashHit(atk,victim) | No | Hit Gojo.M1.Hit1-4, FinalHit Hit4. BlackFlashHit: `Utils.Itadori.DivergentFist.BlackFlashHit` + BlackFlashCC (gated `_G.Settings.Flash`) — rapid punches can Black Flash. |
| 30 | Controllers/Moveset/Gojo/Base/ReversalRedController | ModuleScript | 110 | ReversalRedController | ReversalRedService; FXController | none | Red(char,orbPart), Explode(pos), Finisher, Flip(char,orbPart) | No | Red: orb grows to 0.9, Center.Light/Charge, Wind then Throw sound. Explode: `Utils.Gojo.ReversalRed.RedExplode`. Finisher: `_G.Settings.Gore` → `Utils.Heian.BloodSpread` + Bleed. **Flip**: `orb.Flip.*` emitters + voice `Sounds.Gojo.RedFlip` (Voice) — flip/aerial variant. |
| 31 | Controllers/Moveset/Gojo/GojoController | ModuleScript | 376 | GojoController | GojoService; ctrl: HitboxController, FXController | **`remote:FireServer(hitsTable|nil, hrp.CFrame)`** from `Service.Hitbox` handler | Effects: Hit(char,idx), ChaseHit, AerialHit, Teleport(char), Chase, Swing, Swing2(char,count,dir), Launch(char,dy), Chat(char), FistSlam, CamFix(char,cframe), DragStart(char,victim,inst), DragThrow(char). Extra RemoteSignal **`GojoService.Hitbox(inst, char, remote)`** | **YES** — loop 0.05s: `SphereHitbox(char, CF(0,-1,-3), 10)`, `Info.Knockback` ≠ false filter, tweens inst NumberValue→0, fires hits + HRP CFrame | Gojo character controller. M1 sounds `Sounds.Gojo.M1.Hit<idx>`; Swing2 ArmFlash RGB(85,255,255): Down=R leg, count 1/4=R arm else L arm. **Teleport**: `Utils.Gojo.Teleport` + owner-only `Utils.Gojo.TeleportBreak` screen-shard effect (30 `Utils.Gojo.Shard` w/ BodyVelocity, follows camera). **Chat** (awakening/blindfold): `Utils.Gojo.Dialogue` Chat1/Chat2 (text in template), Gojo.GrabBlinds → BlindsOff. **CamFix(char, cf)**: client sets `hrp.CFrame = cf` preserving camera offset (client-applied teleport). DragStart/DragThrow: Gojo.TeleportDrag loop, BlackFlashLaunch + CounterSwing.Shock, Gojo.DragThrow. FistSlam sound. |
| 32 | Controllers/Moveset/Goku/Base/KamehamehaController | ModuleScript | 207 | KamehamehaController | KamehamehaService; FXController | none (client sets `aimPart.CFrame` locally) | AutoRotate(char,aimPart), StartCharge, ChargeStronger, Shoot(char,cframe), RemoveCharges, Hit(victim) | No (owner writes `aimPart.CFrame = aimPart:GetAttribute("FinalPos") or camera-look`) | StartCharge: `Utils.Goku.Ball` welded to Left Arm; ChargeStronger size 2. **Shoot**: `Utils.Goku.Kamehameha` (Ball1/Ball2/Shaft) raycast 50 studs excluding `workspace.Characters` & `workspace.Map.Data`, 0.5 s beam, LightLoop shake. Hit: if `victim:GetAttribute("Dead")` → sets `KamehamehaFinished` attr, victim invisible, 10 neon RGB(13,105,172) shards (disintegration finisher); else Flash blue. Sounds Goku.Kamehameha.{Use,Finisher}. |
| 33 | Controllers/Moveset/Goku/Base/KiSpamController | ModuleScript | 92 | KiSpamController | KiSpamService; FXController | none (client sets aimPart.CFrame) | AutoRotate(char,aimPart), ProjectileExplode(cframe), Hit(victim), Shoot(char,proj,hand "Left"/"Right") | No | `Utils.Goku.Explode` (Attachment children w/ EmitCount). Shoot: `proj.Attachment.Impact15`, ShootKi pitch 1.2 for Left. Sounds Goku.{ExplodeKi,HitKi,ShootKi}. |
| 34 | Controllers/Moveset/Goku/Base/StaffExtendController | ModuleScript | 144 | StaffExtendController | StaffExtendService; FXController | none | Start, Swing, Hit(atk,victim), UpriseExtend(char), UpriseEnd(char), Launch(char,dy) | No | Weapon `char.SetAssets.GokuStick` with `.Uprise` part (+ `.Uprise.Uprise` emitter): UpriseExtend raycasts down 75 studs `_G.MapParams`, anchors & tweens staff base to ground (pole-vault); UpriseEnd restores. Sounds Goku.StaffExtend.{Swing,Hit}. |
| 35 | Controllers/Moveset/Goku/Base/StaffUppercutController | ModuleScript | 84 | StaffUppercutController | StaffUppercutService; FXController | none | Start, StaffTrail, StopTrail, Hit(atk,victim) | No | `GokuStick.Extention.Trail` toggled. Hit: SnapOh if `victim:GetAttribute("Dead")` else HeavyHit; after 2 s if dead and `hrp.Position.Y > 275` → `Utils.Goku.Star` twinkle + Goku.StaffUppercut.Twinkle (launched-into-sky finisher). |
| 36 | Controllers/Moveset/Goku/GokuController | ModuleScript | 526 | GokuController | GokuService; ctrl: HitboxController (unused), FXController | none (owner steers HRP orientation in Chase) | Hit(char,idx), KickHit(player,victim), DownslamHit(player,victim), ChaseHit, DismantleHit(player,target|Vector3,pattern 1-4), CleaveGrab, CleaveHit(atk,victim), StartScream, ChestBeat, Finisher, Feint, Chase(char), StopCloud(char), Swing, Launch(char,dy), Switch, Chat, Chat2, GokuVanish(char,inst), Follow(part,part2,targetPart,dirVec) | No | Goku character controller — **heavily reuses Itadori assets** (M1 sounds `Sounds.Itadori.M1.Hit<idx>`, Dismantle, Cleave, Switch, Dialogue, CounterHit.Feint). **Chase**: `Utils.Goku.NimbusCloud` parented to char, `char:SetAttribute("CloudEnabled", true)`; owner rotates HRP to camera look while airborne (raycast down 4) — client-side flight orientation; StopCloud clears attr. DismantleHit patterns: 1/2/3 single slash angles, 4 = triple. CleaveHit: Cleave + 10 slashes + blood, BlackFlashCC if `_G.Settings.Flash`. Chat2 overrides text "IT'S A BINDING VOW I MADE WITH THAT BRAT." (Itadori/Sukuna line). **GokuVanish**: `Utils.Goku.Vanish.{Limb,Head,Torso,Limb2,Head2,Torso2}.Attachment` per-limb emit, waits `inst.AncestryChanged` then Appear (instant transmission). **Follow**: `part.Position = target + dir*3` until `part:GetAttribute("Track")` falsy. Sounds Goku.{M2DownslamHit,MonkeyScream,ChestBeat,Vanish,Appear}, Hakari.EnergySurge.Hit1, Itadori.Dismantle.{FinishSlash,Slash,Explode}, Itadori.FireArrow.Arrow, Gojo.LapseBlue.Grab, Gojo.BlindsOff. |

#### Asset IDs / numeric ids
| Id | Where | Use |
|---|---|---|
| `109651238159963` | MokouController `SpawnAnim` | Animation id for Mokou spawn intro |

No `rbxassetid://`, gamepass, product, UserId or place ids anywhere else in this slice.

#### Attributes / Info values / tags / _G seen
- **Player attributes**: `Ultimate` (0-100 meter; CharlesController Swing2, BloodRainController Rain).
- **Character attributes**: `Moveset` (compared to `"Mechamaru"`, UltraCannon2), `Dead` (Kamehameha, StaffUppercut), `KamehamehaFinished` (set by client), `CloudEnabled` (set/cleared by client, Goku Chase/StopCloud).
- **Skill-instance attributes** (server-created parts/folders): `BeamStartCFrame`, `BeamLength` (PlasmaWave), `Speed` (Choso/Chaos homing projectile), `End` (BoostOn2), `Disabled` (Booster models, set by client), `Grab`, `Purple` (LapseBlueMax attachment), `Aim` (UltraCannon2 aim part), `FinalPos` (Kamehameha aim part), `Track` (Goku Follow).
- **VFX-template attributes**: `EmitCount`, `EmitDuration`, `RepeatCount`, `RepeatDelay`, `MaxSpeed`, `StartTransparency`, `Duration`, `Part_TweenParams` / `Mesh_TweenParams` / `Decal_TweenParams`.
- **`Info` folder values**: `Info.Knockback` (BoolValue; hitbox filter), `Info.BoostOnHold` (BoolValue), `Info.Stun`, `Info.InSkill` (child-added names, Charles Perfect).
- **Character children**: `SetAssets.GWarstaff` (+`GWarStaff` typo), `SetAssets.Gavel` (.A, .Extensions), `SetAssets.GokuStick` (.Uprise, .Extention.Trail), `BoosterR`/`BoosterL` (`Arm BoostterrrrR/L`.Stage1/Stage2), `Hand blasterL`, `NimbusCloud`, `Ball`; puppet char has `Owner`/`User`/`Friend` ObjectValues.
- **Animation track names**: `Dodge1`..`Dodge5`.
- **`_G`**: `_G.MapParams` (RaycastParams), `_G.Settings.Flash`, `_G.Settings.Gore`, `_G.Settings.DesPHY`.
- **workspace refs**: `Effects`, `Characters`, `Map`, `Map.Data`, `Spawns`, `Domains`, `Music` (presence check). CollisionGroup `"Effects"`. No CollectionService tags in this slice.

### A.2 Movesets: Hakari, Hanami, Haruta, Heian, Hiromi, Itadori (43)

| # | Path (from header) | Type | Lines | Knit name | Services used | Client→server calls | Server→client signals handled (Effects keys) | Client-auth hit? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Moveset/Hakari/Awake/EnergySurgeController | ModuleScript | 166 | EnergySurgeController | EnergySurgeService; ctrls HitboxController, FXController | none | `Dash, HeavySwing, Flash, Flash2, Teleport(char, cf), Jump(anchorPart, bodyMover), Hit(player, target, isHeavy)` | No | Green (85,255,127) recolor of `Utils.Itadori.CrushingBlow`; `Utils.Gojo.Teleport`; `Utils.Hakari.RoughHit`. `Jump` = client drags own BodyPosition (`P=100000`) / lerps other HRPs to an anchor part (grab-follow). Sounds `Sounds.Hakari.EnergySurge.{Dash,Swing,Swag,Teleport,Hit1,Hit2}`, `Hakari.OverLuck.Hit1`. |
| 2 | Moveset/Hakari/Base/FeverBreakerController | ModuleScript | 175 | FeverBreakerController | FeverBreakerService (stored as GLOBAL `FeverBreakerService` — decompiler artifact/bug); FXController | none | `Startup, Swing, Hit(player,target), Hit2(player,target), Dash, Spawn(doorModel, color?), Break(char, doorModel, _), CrushSwing` | No | Shutter-door summon model with `Doors.Door1/Door2`, `Weld1/Weld2`, `Stars` emitters; door color param (skin?). Break: doors fly with `Velocity`. VFX `Utils.Gojo.Twofold`, `Utils.Hakari.RoughHit`. Sounds `Hakari.FeverBreak.{Swing,Hit1,Dash,CrushSwing}`, `Hakari.ShutterDoors.{Spawn,Swing}`, `Hakari.Counter.Slam`, `Itadori.CraniumSmash.Hit2`. |
| 3 | Moveset/Hakari/Awake/LuckyRushdownController | ModuleScript | 178 | LuckyRushdownController | LuckyRushdownService; HitboxController, FXController, JoinController | none | `Dash(char, bodyVel, speedMult)`, `Grab`, `Throw`, `Jump(anchor, bodyMover)`, `JumpBurst(pos)`, `Hit(player,target,isFinal)` | No (but client drives own BodyVelocity: `200*mult → 50*mult` LookVector) | Grab/throw rushdown. `Jump` on non-local chars sets `JoinController.lastRecvServer[char]=false` (suppresses interpolation). Green JumpBurst recolor of CrushingBlow. Sounds `Itadori.Rush.{Rush,RushBreak}`, `Gojo.LapseBlue.Grab`, `Itadori.CursedStrikes.Startup`, `Hakari.OverLuck.Hit1`, `Itadori.CrushingBlow.GroundImpact`. FX `Bleed` on final. |
| 4 | Moveset/Hakari/Awake/LuckyVolleyController | ModuleScript | 160 | LuckyVolleyController | LuckyVolleyService; FXController | none | `Barrage(char, token)`, `Hit`, `Hit2(player,target)`, `Swing` | No | Barrage: loops every 0.025s while `token.Parent`, clones `Utils.Hakari.Barrage` (arm copies w/ player's Shirt + arm colors; `ColorArm` parts), `Gojo.LapseBlue.Throw` rings. `Utils.Hakari.RoughSwing` (Weld, Beam, Core.Flames). Sounds `Misc.Swing.Fist`, `Gojo.M1.Hit1-3`, `Itadori.CraniumSmash.Hit2`, `Hakari.EnergySurge.Hit2`, `Hakari.Counter.Startup`. |
| 5 | Moveset/Hakari/Awake/OverLuckController | ModuleScript | 163 | OverLuckController | OverLuckService; HitboxController, FXController | none | `Charge`, `Dash(char, bodyVel, mult)`, `Swing(char, idx 1..4)`, `HeavySwing(char, isLeft)`, `Hit(player,target, variant true/false/nil)` | No (client drives own BodyVelocity 50*mult, dips to 25*mult on `Swing` attribute change) | Attribute `Swing` on the BodyVelocity object (GetAttributeChangedSignal). Green Flash (85,255,127). Sounds `Hakari.OverLuck.{Charge,Dash,Speed1,Speed2,Swing,Hit1,Hit2}`, `Misc.Swing.Fist2/Fist3`. |
| 6 | Moveset/Hakari/Base/ReserveBallController | ModuleScript | 185 | ReserveBallController | ReserveBallService; FXController | none | `Swing`, `Fire(char, cf, ballPart, color?)`, `Interp(part)`, `Hit(player,target)`, `Another(charA, charB)` | No | Projectile: `Interp` = client-side extrapolation `BulkMoveTo` at 150 studs/s along LookVector between server position updates. `Another` = swap/teleport both chars (`Gojo.Teleport`, `Gojo.TeleportBreak` + `Gojo.Shard` glass shards on local cam). Ball color param (skin recolor). `Utils.Hakari.Indicators.BallFire`. Sounds `Hakari.ReserveBalls.{Fire,Impact}`, `Gojo.Teleport`, `Itadori.DivergentFist.Swing`. |
| 7 | Moveset/Hakari/Base/RoughEnergyController | ModuleScript | 156 | RoughEnergyController | RoughEnergyService; FXController | none | `Startup, Swing, Hit(player,target), Dash, Crush(_, pos, isBig)` | No | `Utils.Gojo.AirPalm`, `Utils.Itadori.Shock` x3, `Utils.Hiromi.Shockwave`, `Utils.Hakari.RoughImpact`. Sounds `Hakari.OverLuck.{Charge,Speed1}`, `Hakari.EnergySurge.Swing`, `Hakari.{Shock,Impact}`, `Itadori.DivergentFist.Swing`. |
| 8 | Moveset/Hakari/Base/ShutterDoorsController | ModuleScript | 179 | **ShutterDoorController** (name differs from file) | ShutterDoorService; FXController | none | `Spawn(doorModel, color?, speedScale?)`, `Close(doorModel, mode)`, `Fade`, `Bound(part)`, `Break(doorModel)`, `Hit`, `Finisher` | No | Door summon/close/break (rigid doors `Velocity (0,-100,0)`, RotVelocity ±80). `Bound`: reads/sets part attribute `CF`. `Utils.Locust.Slam` (emitters w/ `EmitCount` attr). Sounds `Hakari.ShutterDoors.{Spawn,Swing,Slam}`, `Hakari.Counter.{Swing,Slam}`, `Itadori.Dismantle.Explode`, `Itadori.CraniumSmash.Hit2`. Bleed on Finisher. |
| 9 | Moveset/Hanami/Base/BudShotController | ModuleScript | 83 | BudShotController | BudShotService; FXController | none | `Startup, Interp(proj), Hit(target, n)` | No | Projectile extrapolation 200 st/s. Sounds `Hanami.BudShot.{Startup,Throw,Hit<n>}`. `Utils.Gojo.Twofold.Sparks`. |
| 10 | Moveset/Hanami/Awake/CursedBudsController | ModuleScript | 231 | CursedBudsController | CursedBudsService; FXController, ToolController | **`aimRemote:FireServer(targetPos)`** every 0.02s while remote alive (Appear) — pos = `ToolController:GetTarget().PrimaryPart.Position` or `GetMouseTarget(300)` | `Start, Appear(char, budModel, aimRemote), Interp(proj, budModel), Hit, Hit2, Disappear(_, budModel)` | Client-auth **aim/target stream** (not hits) | Summons plant turret (`budModel` w/ `stem4.Mouth.PartRoot`, `.Model`), scaled via ScaleTo, spawns 4 `Utils.Hanami.bud1` trees (AnimationController + `Animations.Hanami.CursedBudsTreeSmall`, marker `Loop`). Palette {86,66,54},{76,60,51},{86,60,51}; recolors parts colored (84,72,47). Attr `Smoke` on descendants. `_G.MapParams`. `Utils.Hanami.ParticleDissipationHolder`, `Mahito.CrushingRushdown.DrillImpact`. Sounds `Hanami.CursedBuds.{Start,Appear,Disappear}`, `Hanami.BudShot.{Throw,Hit1,Hit2}`, `Hanami.DefenseResponse.Hit2`. |
| 11 | Moveset/Hanami/Base/DefenseResponseController | ModuleScript | 361 | DefenseResponseController | DefenseResponseService; FXController | none | `Weave(char, isAir)`, `Hit(target, n)`, `Spike(pos, followPart, scale, isTreeMonster)`, `TreeMonster(pos, followPart, scale)`, `SmallField(pos)` | No | Root spike counter/grab; `Utils.Hanami.{360Spike,TreeMonster,SmallFieldWindup,SmallFieldExplosion,ParticleDissipationHolder}`, `Naoya.Fall`, `Choso.CounterSwing.Shock`, `Hiromi.GavelShard` debris (gated `_G.Settings.DesPHY`). TreeMonster plays `Animations.Hanami.EvilTreeIdle`, `EvilTreeThrow` on attr `Lasso` change. Waits while followPart in `workspace.Characters`. ArmFlash color (172,203,163). Sounds `Hanami.DefenseResponse.{Startup,AirStartup,Hit<n>,Root}`, `Hanami.RootDisappear`, `Hanami.FlowersField.Field`. |
| 12 | Moveset/Hanami/Awake/FlowerBeamController | ModuleScript | 262 | FlowerBeamController | FlowerBeamService; FXController, ToolController | none | `Windup(char)`, `StartBeam(beamObj)` | No | Beam driven by attributes on server object: `BeamStartCFrame`, `BeamLength`, `Width`. `drawBeam`/`shootSpec` helpers; `Utils.Hanami.Beam.{Windup,FlowerBeam}`, `Yuta.LoveBeam.{BlackSpec,CameraFX}`, `Utils.Misc.M.Awk.mokultMeh["3"]`, `Utils.Ryu.Launch` via `MokouController:ArcTween`. Lighting ExposureCompensation -2 when near. Sounds `Hanami.FlowerBeam.{Windup,Shoot}`. |
| 13 | Moveset/Hanami/Awake/FlowerFieldController | ModuleScript | 388 | FlowerFieldController | FlowerFieldService; FXController, ToolController | none | `Windup` (empty), `FlowerTrail(part, player)`, `FlowerExplosion(pos)`, `Lasso(part, lassoObj, targetHRP)`, `LassoFail(char, lassoObj)`, `GrappleHit(target)` | No | Local player gets `Utils.Megumi.HitArea` (30x30) ground indicator. Lasso = 8 procedurally bent wooden Parts in `lassoObj.Parts`, `lassoObj.Grab.Value` (ObjectValue → grabbed char), StrangleRoot/WrappingRoot welds. `SraikoVFX.HandleMesh` on `Nanami.BluntCut.Charge` models. `_G.MapParams`. Sounds `Hanami.FlowersField.{Field,Hit}`, `Hanami.AOESpikes.WoodBallsAppear`, `Megumi.Mahoraga.Throw.Break`, `Hanami.DefenseResponse.Startup`, `Hanami.RootDisappear`, `Gojo.LapseBlue.Grab`. |
| 14 | Moveset/Hanami/HanamiController | ModuleScript | 727 | HanamiController | HanamiService; HitboxController, FXController | none | `Hit(target,n)`, `ChaseHit`, `AerialHit`, `Chase`, `Swing`, `Swing2(char, idx, dir)`, `Launch(char, y)`, `ApplyDaze(target, token)`, `ApplyBud(target, intValue)`, `Field(char, cf)`, `FieldStart`, `FlowersFieldHit`, `Lasso(char, lassoObj, cf)`, `LassoFail`, `GrappleHit`, `UppercutSpike(cf, mode, target)`, `DownslamRoot` (stub), `Pierced(target)`, `EmpowerStart(char, boolValue, useArm)`, `Chat`, `RipSound`, `BeamOffCD`, `PlantGuide(part)` | No | Character controller. Attr `InUlt` (char, ult-mode left-arm flash), `Dead` (target). `Character.Info:FindFirstChild("DomainTag")` referenced in RootRampage. Status VFX: `Utils.Hanami.Petals` (Daze, re-flash every 8s pink 255,170,255), `Utils.Hanami.Buds` (bud stacks count = IntValue.Value). `Utils.Hanami.{FlowerField,UppercutRoot,EmpowerCharge,EmpowerAura,Dialogue}`. Awakening `Chat` = Dialogue GUI Chat1/Chat2 + `Sounds.Hanami.Awaken`. Sounds `Hanami.{Uppercut,ArmWrapRip,EmpowerStart,Empower,RootDisappear}`, `Hanami.AOESpikes.{Spikes,WoodBallsAppear}`, `Hiromi.Stab`, `Gojo.M1.Hit<n>`, `Misc.Chase`, `Misc.Swing.Fist`. BloodyZee x40 on Pierced. |
| 15 | Moveset/Hanami/Awake/RootRampageController | ModuleScript | 626 | RootRampageController | RootRampageService; FXController | **`steerRemote:FireServer(camera.LookVector)`** every frame while alive (Roots, local player only) | `Windup(char, token)`, `Roots(player, rootsRemote, steerRemote, size)`, `ReplicateRoots(tbl, lifetime, size)`, `StartSurf(surfRemote, fovDeg, char, token)`; plus raw `rootsRemote.OnClientEvent("PB", lookVec)` / `(cf, moveCam, id)` and `surfRemote.OnClientEvent("Surf", cf)` / `("WoodenBall", ball, chars)` / `("Spikes", ball, {{char,pos,dir,len}})` / `("DestroyWoodenBall", ball)` | Client-auth **camera steering** stream (not hits) | Ultimate: root ride; local camera subject swapped to an anchor part. Roots are procedural wooden Parts (67,47,35) via `CreateRampageRootsForHitbox` / `CreateSurfRootsForHitbox`; `Utils.Hanami.RootsDust`, `Megumi.HitArea` cone indicator. Music `Sounds.Hanami.RootRampage.OST` (SoundGroup Music). Lifetime `DomainTag and 5 or 30`. Sounds `Hanami.RootRampage.{Start,RootAppear,RootLoop}`, `Hanami.AOESpikes.{WoodBallsAppear,Spear1,Spear2}`. |
| 16 | Moveset/Hanami/Base/RootSwarmController | ModuleScript | 222 | RootSwarmController | RootSwarmService; FXController | none | `Startup`, `Roots(cf)`, `Hit(target)` | No | 9 segments × 3 roots procedural ground wave, samples floor color. Sounds `Hanami.RootSwarm.{Startup,Swarm,Disappear}`, `Hakari.EnergySurge.Hit1`. |
| 17 | Moveset/Hanami/Base/SurgingThornsController | ModuleScript | 242 | SurgingThornsController | SurgingThornsService; FXController | none | `Spikes(cf)`, `WoodenBall(char, target)`, `SpikesWindup`, `Hit(target, n)` | No | Two wood balls at ±3 studs follow HRP; fire spears when target gets attr `Phase1`/`Phase2` (CFrame). Dies if target leaves `workspace.Characters`. `Utils.Hanami.{CurvedRoot,WoodBall}`. Sounds `Hanami.AOESpikes.{WoodBallsAppear,Spear<n>,SpikesWindup}`, `Hanami.DefenseResponse.Hit<n>`, `Hanami.RootDisappear`. |
| 18 | Moveset/Haruta/Base/AmbushController | ModuleScript | 139 | **StingerController** (name differs) | AmbushService; HitboxController, FXController | none | `Start`, `Whoosh`, `Hit(char,target,isHigh)`, `Stab(char,target,_)` | No | Uses `char.SetAssets.HarutaSword.Blade` for `Utils.Haruta.CombatTrail`. `Utils.Choso.CounterSwing`, `Yuta.SlashHit`. Blood flash (0.745,0,0.0117). Sounds `Haruta.{AmbushSwing,Backstab,AmbushHit}`, `Choso.BloodEdge.StabHit`. |
| 19 | Moveset/Haruta/Hand/AnkleCutterController | ModuleScript | 153 | AnkleCutterController | AnkleCutterService; HitboxController, FXController | none | `Start`, `Hit(target)`, `Interp(proj)`, `Dash(char, fromPos)` | No | "Hand" folder (thrown-sword/hand mode). Proj extrapolation 150 st/s. `Utils.Mahito.Dash`, `Itadori.RushWind`, `Itadori.Shock`. Blood on both legs. Sounds `Haruta.{AnkleCutterWhoosh,AnkleCutterHit}`, `Nanami.BluntCut.Dash`. |
| 20 | Moveset/Haruta/Base/BackstabController | ModuleScript | 169 | BackstabController | BackstabService; HitboxController, FXController | none | `Start`, `Whoosh(char, isFinisher)`, `Stab(char,target,isBack,finisherIdx)`, `Crush(char,target,pos)`, `Kick(char,target)` | No | Back-vs-front stab variant sounds; finisher chain Stab<n>/Slam/Kick. `Utils.Hiromi.Shockwave`, `Gojo.HardHit`. Sounds `Haruta.{Backstab,BackstabBack,BackstabFront}`, `Haruta.BackstabFinisher.{Whoosh,Stab<n>,Slam,Kick}`. |
| 21 | Moveset/Haruta/Base/CheapShotController | ModuleScript | 129 | CheapShotController | CheapShotService; HitboxController, FXController | none | `Start`, `ArmWave`, `Throw`, `Hit(char,target,xOffset)`, `Interp(proj)`, `Finisher` | No | Sword throw projectile (150 st/s, looping `Haruta.SwordSpin`). `Utils.Haruta.SwordThrow`. Sounds `Haruta.{SwordThrow,Wave,CheapShotHit,SwordSpin}`. Bleed on Finisher. |
| 22 | Moveset/Haruta/HarutaController | ModuleScript | 537 | HarutaController | HarutaService; HitboxController, FXController | none | `Hit(char,target,idx,dir)`, `ChaseHit(char,target,noSword)`, `AerialHit`, `Chase`, `Swing(char,idx,dir)`, `Swing2(char,idx,dir)`, `Launch(char,y)`, `Miracles(gui)`, `UpdateMiracles(gui, n)`, `Stab`, `Kick`, `DodgeAttempt`, `MiracleGain`, `MiracleUse`, `Dodge`, `SwordCatch`, `Taunt(char, token)`, `HandMode(char, objValue)`, `JawbreakerStart(char, viewer?, target, token)` | No | Character controller. Sword-vs-unarmed M1 branching on `SetAssets.HarutaSword`. **Meter "Miracles"**: GUI `Mir1..Mir6` fill toggles (max 6), `_G.Settings.UIS` scale. Purple theme (167,125,203), gain (209,157,255), use (126,91,154). `HandMode`: Highlight on `objValue.Value` model, enabled only when LoS blocked (raycast `_G.MapParams`). `JawbreakerStart` = execution cutscene: `Utils.Haruta.JawbreakerUI` + `JawbreakerCutscene.Frames` (per-frame CFrameValues, 120fps), Scriptable camera, `Utils.Damage.Skeleton.Head`, `_G.Settings.Flash` red CC. Dodge anims `Animations.Hiromi.Dodge` (5, track names Dodge1-5). Sounds `Haruta.M1.{Hit<n>,Swing<n>}`, `Haruta.{Gain,Lose,Catch,Taunt,Jawbreaker}`, `Hiromi.Execution.{Curb,Step}`, `Itadori.ManjiKick.{Startup,Dodge}`, `Choso.BloodEdge.StabHit`. |
| 23 | Moveset/Haruta/Hand/HighTimeController | ModuleScript | 75 | HighTimeController | HighTimeService; HitboxController, FXController | none | `Hit(target)`, `Swing` | No | `Utils.Haruta.SlashEmit`. Sounds `Haruta.Hightime`, `Choso.BloodEdge.StabHit`. Leg blood. |
| 24 | Moveset/Haruta/Base/TripController | ModuleScript | 79 | TripController | TripService; HitboxController, FXController | none | `Start`, `Hit(char,target,extra)` | No | Reads target attr `Ragdoll` (>0 → extra sound). Sounds `Naoya.Cursory.Kick`, `Haruta.{Trip,Trip2,Trip3}`, `Nanami.CleavingWhirlwind.Hit`. |
| 25 | Moveset/Heian/CleaveRushController | ModuleScript | 283 | CleaveRushController | CleaveRushService; FXController | none | `Start`, `Warn(char, isFlash)`, `Dash`, `CleaveGrab(char,target)`, `Cleave`, `CleaveHit`, `Finisher`, `BlackFlashFinisherHard(char,target)` | No | Sukuna Heian. Voice lines via SoundGroup **Voice**: `Heian.{CleaveStart,CleaveFlashVoice,CleaveVoice,CleaveVoice2}`. `Utils.Heian.{Cleave,BloodSpread}`, `Itadori.{EyeTrails,Dismantle.Cleave,DivergentFist.BlackFlashLaunch/BlackFlashCC}`, LightningBeams red bolt into `workspace.Effects.Bolt`. Gates `_G.Settings.Flash`, `_G.Settings.Gore`. |
| 26 | Moveset/Heian/DismantleV2Controller | ModuleScript | 239 | DismantleV2Controller | DismantleV2Service; FXController, ToolController | none | `Start(char, n)`, `Interp(_, proj)`, `Hit`, `Hit2`, `DismantleSweep`, `Split`, `WCS(cf)` | No | Attr `Moveset == "Heian"` gates voice lines `Heian.Dismantle1/2/3`. Proj extrapolation 300 st/s. `WCS` = World Cutting Slash: `Utils.Heian.WorldSlash` size→(0,0,500); skips CC if `workspace:GetAttribute("CC1")`. `Utils.Heian.Sweep`. Attr `Dead`. Sounds `Heian.Dismantle.{Start,Fire,Hit,FireWCS}`, `Heian.Slashes2`, `Itadori.Dismantle.{Slash,Explode}`, `Itadori.Rush.RushLaunch`. |
| 27 | Moveset/Heian/FurnaceArrowController | ModuleScript | 284 | FurnaceArrowController | FurnaceArrowService; FXController | none | `HotHands(char, holder)`, `Clap(char, holder)`, `Clap2`, `Arrow(char, holder)`, `Fire(char, holder)`, `Interp(proj)`, `Burn(pos)`, `Finisher` | No | Fuga. `Utils.Heian.FlameArrow.{Hands,Clap,Arrow,Shot,explode}`, `Itadori.FireArrow.Burn`, `Megumi.Mahoraga.WorldSlash.mesh`, `Utils.Damage.Flames`. Proj 192 st/s. Voice `Heian.FireArrow.{Voice,FugaVoice}` if `Moveset=="Heian"`. Sounds `Heian.FireArrow.{Hands,FlameIdle,Clap,Arrow,Fire,Shockwave,Explode}`. FX `Burn(char)`. |
| 28 | Moveset/Heian/KamutokeController | ModuleScript | 126 | KamutokeController | KamutokeService; FXController | none | `Kamutoke(char, holder)`, `Strike(pos)`, `Finisher` | No | Lightning tool welded to Right Arm (`Utils.Heian.Kamutoke`), 0.7s red ground telegraph (`Mahito.WideSPStrike.HitArea` 19x19), then `Utils.Heian.Lightning` + LightningBeams. Sounds `Heian.Kamutoke.{Equip,Equip2,Fire.1-4}`, `Gojo.HollowPurple.Hit`. |
| 29 | Moveset/Hiromi/Awake/ExecutionController | ModuleScript | 297 | ExecutionController | ExecutionService; FXController, ToolController | none | `Charge`, `Charged`, `Aerial(char, aimPart)`, `Woosh`, `Fly`, `Hit(target, fell)`, `Whack(player,target)`, `Arm(char,target)`, `Leg(char,target)`, `Head(char,target)`, `Curb(char,target)` | No | Requires `SetAssets.ExecSword`. `Aerial`: client BodyGyro aims at `aimPart:GetAttribute("Aim")` or `ToolController:GetMouseTarget()`, PlatformStand. Dismemberment: `Utils.Hiromi.Limb` w/ Shirt/Pants clone follows sword. `Utils.Hiromi.{SwordBuild.Charge/ChargeEmit,Thrust}`, `Mahito.BodyRepel.Wind1-5`, `Locust.Slam`. Sounds `Hiromi.Execution.{Charge,Flash,Dash,Stab,Sever,Sever2,Curb,Step}`, `Hiromi.{Fall,Stab}`, `Hakari.EnergySurge.Hit1`. |
| 30 | Moveset/Hiromi/Base/ExtendSwingController | ModuleScript | 180 | ExtendSwingController | ExtendSwingService; FXController | none | `Swing`, `SwingDown`, `Crush(player,pos)`, `Sweep`, `Hit`, `Hit2`, `Hit3(player,target)`, `SweepMiss`, `SweepHit(player,target)`, `Finisher` | No | Yellow (1,1,0.498) CrushingBlow recolor. Finisher = decapitation VFX (head + face accessories hidden, `Heian.BloodSpread` if Gore). `Utils.Hiromi.BlockBreak`. Sounds `Hiromi.Sweep`, `Megumi.Elephant.{Hit,Explode}`, `Gojo.Teleport`, `Gojo.M1.Hit1`, `Itadori.Dismantle.Explode`. |
| 31 | Moveset/Hiromi/HiromiController | ModuleScript | 1119 | HiromiController | HiromiService; HitboxController, FXController | **`choiceRemote:FireServer(1|2|3)`** on Denial/Silence/Confess button click (domain minigame) | `Hit(target,n)`, `Dodge2`, `Dodge`, `ChaseHit`, `Chase`, `Swing`, `Swing2(char,idx,dir)`, `Chat(char, weldPart, gavel)`, `Launch`, `Startup(char)`, `Opening(domainPart, ground, domainFolder, choiceRemote, crimeIdx, caster, isLate, hp)`, `Shatter(pos)`, `LightShatter(pos)`, `Confiscate(char, name, color?)`, `AmpliStart`, `AmpliAbsorb`, `Interp(proj)`, `Recall(char, proj, fromPos, dur)`, `HammerHit(player,target)`, `Dash`, `HammerSwap(char, attach/part)`, `HammerIFrame(char, token)`, `Bang`; raw `choiceRemote.OnClientEvent(a, chosen, correct, failIdx, hp, speaker)` | Client-auth **choice input** (game decision, not hit) | Character controller + **Domain "Deadly Sentencing"**. Domain attrs on ground part: `VisualHealth`, `UI`, `UI2`, `DenialCount`, `SilenceCount`, `ConfessCount`; saw attrs `DecreaseHP`, `cf`. Module `Modules.DeadlyData` (`Dialog`, `DialogFail`, `Crimes`). GUI `Utils.Hiromi.DeadlySentencing.{DomainBG,JudgemanPanel,Choose,HiromiText,LightShatter}`. `Animations.Hiromi.DomainWarn`, `Animations.Hiromi.Dodge`. Proj attr `Rebound`. Gavel M1 (`SetAssets.Gavel`) vs ExecSword M1 sounds `Hiromi.M1Swing.Swing<n>` / `Hiromi.M1SwordSwing.Swing<n>`. Brown theme (179,130,61). Confiscate text "- [name]" over head. Amplification flash (0.667,1,1). Sounds `Hiromi.DeadlySentence.{Talk,Voice,Create,BladeFallRope,BladeFall1/2,Tick,Fill,Sure,TalkFail,Music,Travel,Shatter}`, `Hiromi.Amplification.{Start,Absorb}`, `Hiromi.{Awaken,Recall,Bang}`, `Hiromi.Verdict.Hit1`, `Yuki.Rebound.Bounce`, `Misc.UI.Click`. AmbientReverb Auditorium in domain. |
| 32 | Moveset/Hiromi/Base/JudgeReachController | ModuleScript | 79 | JudgeReachController | JudgeReachService (GLOBAL var artifact); HitboxController, FXController, JoinController | none | `Startup`, `ExtendWind` (stub), `Hit(player,target)` | No | Sounds `Hakari.EnergySurge.{Swing,Hit1}`. |
| 33 | Moveset/Hiromi/Base/PressingChargesController | ModuleScript | 115 | PressingChargesController | PressingChargesService; FXController | none | `Startup`, `Dash(char, cf)`, `Dash2`, `Hit`, `Hit2`, `Finisher` | No | Sounds `Hiromi.Twirl.{Start,Hit}`, `Gojo.ReversalRed.Aim`, `Hiromi.JudgeReachFinisher` (TimePosition 0.733). |
| 34 | Moveset/Hiromi/Awake/TripleSentenceController | ModuleScript | 273 | TripleSentenceController | TripleSentenceService; FXController | none | `Interp(proj)`, `Summon(char, holder)`, `Arm(char,target,dir)`, `Leg(char,target,dir)`, `Teleport`, `Stab(_,target)`, `Toss(player,target)`, `Hit1`, `Hit2`, `ThrowStart`, `Throw(char, variant)` | No | Proj 300 st/s. Severed limbs are physics parts (CollisionGroup `Effects`, velocity dir*50). `Utils.Hiromi.{Throw,Whack,Limb}`. Sounds `Hiromi.{SwordPull,Swing,Sweep,Stab,ThrowStart,Throw,Throw2}`, `Hiromi.Verdict.Hit1/2`, `Megumi.Mahoraga.Takedown.Teleport`. |
| 35 | Moveset/Hiromi/Awake/VerdictController | ModuleScript | 232 | VerdictController | VerdictService; HitboxController, FXController | none | `Swing`, `Jump(anchor, bodyMover, isSmack)`, `Arm`, `Leg`, `HitSlash(player,target)`, `HitBreak(player,target)`, `Hit(player,target)` | No | Grab-follow `Jump` (same pattern as Hakari). Sounds `Hiromi.Verdict.{Start,RunSmack,RunSlash,Hit1,Hit2}`, `Hiromi.Execution.{Sever,Sever2,Flash}`. |
| 36 | Moveset/Itadori/Base/CrushingBlowController | ModuleScript | 113 | CrushingBlowController | CrushingBlowService; FXController | none | `CurseBuild`, `Crush(player,pos)`, `Burst(proj)`, `Hit` | No | `Burst` releases `proj.Rocks` as physics debris. Sounds `Itadori.DivergentFist.Crack`, `Itadori.CrushingBlow.{GroundImpact,Hit1,Hit2}`. |
| 37 | Moveset/Itadori/Base/CursedStrikesController | ModuleScript | 266 | CursedStrikesController | CursedStrikesService (**extra RemoteSignal `Hitbox`**); HitboxController, FXController | **`remote:FireServer(hitsTable, rayHitPos?)`** every 0.025s from `Service.Hitbox:Connect(proj, char, remote)`: `HitboxController:SphereHitbox(char, CFrame(0,-5,-5), 12)` + raycast 7 studs along `proj.Velocity`; destroys proj locally on wall hit | `Swing`, `Leap(char, bodyMover)`, `Dash(char, true|cf)`, `Hit(target, isSpecial)`, `Crush(player,pos)`, `FinalHit(char,target)`, `BlackFlashHit(char,target,doCC)` | **YES — CLIENT-AUTHORITATIVE HIT REPORT** | Dive-kick aerial; client raises `bodyMover.Position` +12. `Utils.Itadori.DivergentFist.{BlackFlashHit,FinisherDrag,BlackFlashCC}`. Sounds `Itadori.CursedStrikes.{Startup,Spin,Hit}`, `Itadori.M1.Hit1-4`, `Itadori.Rush.Rush`. |
| 38 | Moveset/Itadori/Awake/DismantleController | ModuleScript | 322 | DismantleController | DismantleService; FXController, ToolController | none | `Swing`, `Hit(char,target)`, `Hit2`, `Finisher`, `Chant(char, n)`, `WorldSlash(char, cf)`, `WorldHit(target, isFinal)`, `DismantleFly(char, cf, doCC)`, `Aerial(char, aimPart, noLift)` | No | Chant text "RECOIL..." / "TWIN METEORS." (`Utils.Heian.Chant.Chant`). `Aerial` client BodyGyro toward `ToolController:GetMouseTarget()`. `Utils.Itadori.Dismantle.{DismantleFly,Dismantle,WorldSlash,DismatleProj}`. Sounds `Itadori.Dismantle.{Slash,FinishSlash,Explode,WorldSlash1-3}`, `Heian.Dismantle.{Fire,FireWCS}`. |
| 39 | Moveset/Itadori/Base/DivergentFistController | ModuleScript | 514 | DivergentFistController | DivergentFistService; FXController | none | `CurseBuild`, `DivergentSwing(char, isBlackFlash)`, `DivergentHit`, `DivergentStun(char,target)`, `BlackFlashHit(char,target)`, `BlackFlashChain`, `BlackFlashFinisher(char,target,muteVoice)`, `Finisher`, `MusicStart`, `Music`, `BlackFlashHitHard(char,target,token)`, `BlackFlashFinisherHard` | No | Black Flash system. `Utils.Itadori.DivergentFist.{DivergentSwing,DivergentStun,BlackFlashHit,FlashBurn,BlackFlashLaunch,BlackFlashCC,FinisherScene}`, `Utils.Todo.BlackFlashHit`, LightningBeams red bolts, `workspace.Effects.Bolt`. Sounds `Itadori.DivergentFist.{Crack,Swing,BlackFlash,Divergent,DivergentHit,BlackFlashHit,Voice,Voice2,Woosh,Wapam}`, `Itadori.PerfectHit`, `Mahito.BlackFlash`. `_G.Settings.Flash` gates CC + lightning speed. |
| 40 | Moveset/Itadori/Awake/FlameArrowController | ModuleScript | 184 | FlameArrowController | FlameArrowService; FXController | none | `HotHands`, `Clap`, `Arrow(char, arrowObj)`, `Fire`, `Interp(proj)`, `Burn(pos)`, `Finisher` | No | Proj 192 st/s. `Utils.Itadori.FireArrow.{HotHands,FireClap,Burn}`, `Utils.Damage.Flames`. Sounds `Itadori.FireArrow.{Hands,Clap,Arrow,Idle,Fire,Explode}`. FX `Burn(char)`. |
| 41 | Moveset/Itadori/ItadoriController | ModuleScript | 433 | ItadoriController | ItadoriService; HitboxController, FXController | none | `Hit(target, n, isCounter)`, `ChaseHit`, `DismantleHit(player, targetOrPos, pattern 1-4)`, `CleaveGrab`, `CleaveHit(char,target)`, `BlackFlashHit`, `Finisher`, `Feint`, `Chase`, `Swing`, `Swing2(char, idx, dir)`, `Launch(char,y)`, `Switch`, `Chat`, `Chat2`, `ThrowableWind`, `ThrowableHit` | No | Character controller. Attr `InUlt` (white arm flash in ult vs red normally). `Switch` = Sukuna swap VFX (`Utils.Itadori.Switch.{Fade,Switch}`). `Chat2` text "IT'S A BINDING VOW I MADE WITH THAT BRAT." `Utils.Itadori.{CounterHit,CounterHit.Feint,PerfectHit,Dialogue}`. Sounds `Itadori.M1.Hit<n>`, `Gojo.BlindsOff`, `Yuta.{PunchSwing,MetalHit}`, `Hakari.Impact`. |
| 42 | Moveset/Itadori/Base/ManjiKickController | ModuleScript | 225 | ManjiKickController | ManjiKickService; FXController | none | `Startup`, `Hit(player,target)`, `Fade`, `Swing`, `Slam`, `Wheel`, `Crush(pos)`, `AprilFools(char,target)` | No | Counter/dodge kick (`Fade` = black HitGlow afterimage). `AprilFools` easter-egg finisher (`Sounds.Itadori.AprilFools.{Surprise,Fah,Explosion,Explosion2,Bass}`, `Yuki.RisingRage.Hit3`, MokouController ArcTween). `Utils.Megumi.Mahoraga.{Earthquake,WorldSlash.mesh}`. Sounds `Itadori.ManjiKick.{Startup,Dodge,Swing,Slam}`, `Mahito.WideSPStrike.{Crush,Crush2}`. |
| 43 | Moveset/Itadori/Awake/RushController | ModuleScript | 185 | RushController | RushService; FXController, JoinController | none | `Dash(char, light)`, `Hit(_, char, target, dir, token)`, `FinalHit(player,target)`, `AerialHit`, `Jump(anchor, bodyMover)`, `JumpBurst(pos)` | No (but non-local clients move the *attacker's* HRP 65 st/s along `dir` with wall raycast — visual prediction) | Sets `JoinController.lastRecvServer[char]=false` during Jump. Red JumpBurst recolor. Sounds `Itadori.Rush.{Rush,RushHit,RushBreak,RushLaunch}`, `Itadori.M1.Hit1/2/4`. |

Shared observations across slice: `workspace.Effects` (+ `Effects.Bolt`), `workspace.Characters`, `workspace.Map`, `workspace.Domains` (raycast include lists); `Character.SetAssets` folder (weapon models `HarutaSword`, `ExecSword`, `Gavel`); `Character.Info` folder (`DomainTag`); CollisionGroup `"Effects"`; emitter attribute `EmitCount` / `EmitDuration`; `_G.MapParams`, `_G.Settings.{DesPHY,Flash,Gore,UIS}`; `workspace:GetAttribute("CC1")`; SoundGroups `SoundService.{Effect,Music,Voice}`.

### A.3 Movesets: Kurourushi, Locust, Mahito, Mechamaru, Megumi, MeiMei (49)

| # | Path (from header) | Type | Lines | Knit name | Services used (GetService) | Client→server calls | Server→client signals handled (Effects keys or other) | Client-auth hit report? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Moveset/Kurourushi/Base/ChokeholdController | ModuleScript | 149 | ChokeholdController | ChokeholdService (+ctrl FXController, KurourushiController) | none | Effects: `Start(char)` (PlayArms Chokehold anim, sets `HeianArmsModel.Attach.Value=HRP` while playing), `Hit(char,target,isPunch)`, `Hit2(char,target,isPunch)` (2-stage drill impact, particle TimeScale freeze), `Slash(char,swingIdx)` (CombatTrail on `SetAssets.FesteringSword.Union`) | No | Grab. Sounds `Kurourushi.Chokehold.{Start,PunchGrab,CleaveGrab,PunchHit1/2,CleaveHit1/2}`, `Kurourushi.FesteringStrikes.Swing<N>`. Anims `Animations.Kurourushi.{Chokehold,ChokeholdHitArms,ChokeholdHit}`. VFX `Utils.Mahito.CrushingRushdown.DrillImpact` (recolor RGB 101,35,44), `Utils.Kurourushi.CombatTrail`. Shaker Snap/SnapOh/HeavyHit |
| 2 | Moveset/Kurourushi/Base/DetachController | ModuleScript | 325 | DetachController | DetachService (+FXController, KurourushiController, ToolController) | none (local `ToolController:GetMouseTarget()` for aim) | Effects: `Start(char)`, `Aerial(char,projPart)` (Swarm VFX under player; LOCAL owner: BodyGyro aims HRP at mouse, `Humanoid.PlatformStand=true`, sets `projPart.Position=HRP+6Y`), `Detach(char,armProjModel)` (hides Right Arm + right-side accessories, clones Shirt onto `ArmProjectile`, RoachTorso/RoachJet beams, RoachSection chain once proj attr `Rebound` set), `Interp(char,part)` (client extrapolates part along `-UpVector*Speed attr`), `Impact(pos)`, `Hit(char,target)` | No | Arm-detach projectile. Attributes: proj `Rebound`, `Speed`; swarm part `Owner`. Sounds `Kurourushi.Detach.{Detach,Reattach,WallHit,Hit}`. VFX `Utils.Kurourushi.{Swarm,RoachTorso,RoachJet,RoachSection}`, `Utils.Damage.SwordBlockHit`, `Utils.Mahito.CrushingRushdown.DrillImpact` |
| 3 | Moveset/Kurourushi/Base/FesteringStrikesController | ModuleScript | 641 | FesteringStrikesController | FesteringStrikesService (+FXController, KurourushiController) | none | Effects: `Hit(char,target,idx,final?)`, `Arms(char,playThrowSnd)` (PlayArms FesteringStrikes), `Clash(char,target)` (yellow flash both, `Misc.Items.Clash`), `Slash(char,idx,flag)` (3 swing variants of KurourushiSwing/WindMesh2/SwingThinner/SwirlMesh1), `Hit2(char,target)` (slow-mo 1.5s tweens cancelled at 0.5s → snap; recolored Clash attachment 141,49,63; ShakeSustain Snap), `Hit3(char,target,idx)` (Chokehold punch sounds + LapseBlue.Throw ring), `PunchSwing(char,idx)` (ArmFlash 101,35,44 on HeianArms + real arms) | No | Sword multi-hit string. Sounds `Kurourushi.FesteringStrikes.{Hit<N>,FinalHit1,FinalHit2,Throw,Swing<N>,PunchSwing<N>}`, `Misc.Items.Clash`, `Kurourushi.Chokehold.PunchHit1/2`. VFX `Utils.Yuta.SlashHit`, `Utils.Kurourushi.{KurourushiSwing,KurourushiSwingThinner,SwirlMesh1,CombatTrail}`, `Utils.MeiMei.WindMesh2`, `Utils.Misc.Items.Clash.Attachment` (attrs `Duration`,`EmitCount`), `Utils.Gojo.LapseBlue.Throw`. Anims `Animations.Kurourushi.{FesteringStrikesArms,FesteringStrikes}` |
| 4 | Moveset/Kurourushi/KurourushiController | ModuleScript | 1118 | KurourushiController | KurourushiService (+HitboxController, FXController, ToolController) | `remote:FireServer(hitsTable_or_nil, HRP.CFrame)` from `Service.Hitbox` handler | Effects: `Hit(char,target,idx,flag)`, `ChaseHit`, `Chase`, `Swing(char,idx,_,flag)`, `Swing2(char,idx,dirStr,detachMode)`, `Launch(char,yOff)`, `InjuryTick(_,target)`, `Injury(char,target,count)` (egg implant morphs), `InjuryHatch(char,target)` (Chunks + `Utils.Kurourushi.Bug` ragdolls, Gore gate), `EatStart`, `RipArms(char)` (BloodyZee), `Eat(char,target,limbName)` (hides limb/decals/accessories; if Torso shrinks legs + `SetAssets:ClearAllChildren()`), `EarthenTranceStart`, `Interp(char,bugPart,ownerPart)`, `InsectDisappear(_,part)`, `InsectBurst(char,part)`, `InsectHit(char,target)` (green screen VFX/Blur/CC, Flash gate), `Explode(pos)`, `KuroClone(model)` (MoveReveal billboard), `Bugnado(char,tornadoPart,pos)`, `EatSoda`, `Divide(char,folder)` (Parthenogenesis: 2 clones split ±4 studs, FOV 50), `CollectBugs(char,obj)`, `StartInvade(char,a,b)`. Other: `Service.Hitbox(startObj,char,remote)`; RenderStepped loop shows `target.PrimaryPart.MoveReveal.Moveset` for `ToolController:GetTarget()` | **YES** — client `SphereHitbox(char, CFrame(0,0,-4), 8)` polled every 0.05s until a hit whose `Info.Knockback ~= false`, tweens `startObj` NumberValue→0, then `remote:FireServer(hits, HRP.CFrame)` | Character controller. `PlayArms(char,armsAnim,charAnim)` drives `SetAssets.HeianArms.HeianArmsModel.Humanoid` synced to char track. Anims `Animations.Kurourushi.{ArmsMelee.*,Melee.*,ArmsDetach.*,MeleeDetach.*,ArmsMelee.Chase,Melee.Chase,EatArms,Eat,EarthenTranceArms,EarthenTrance,Parthenogenesis,ParthenogenesisArms}`. Sounds `Kurourushi.M1.{Hit1-3,Swing<N>}`, `Gojo.M1.Hit<N>`, `Kurourushi.Tick.Tick1-3`, `Kurourushi.Egg1-4`, `Kurourushi.Hatch`, `Kurourushi.EatStart`, `Kurourushi.InsectTrance.{Start,BugAppear,FlyLoop,BugDisappear,BugExplode,Screen}`, `Kurourushi.Bugnado.{Start,Tornado,Explosion}`, `Kurourushi.Parthenogenesis.{Startup,Explode,Explode2}`, `Kurourushi.StartInvade`, `Mahito.Eat`, `Itadori.Dismantle.Explode`, `Megumi.Mahoraga.Throw.Break`, `Misc.Chase`, `Misc.Swing.Fist`. VFX `Utils.Kurourushi.{Bug,InsectBurst,RoachExplosion,Swarm,Parthenogenesis.RoachUlt,Parthenogenesis.RoachUlt2}`, `Utils.Mahito.Morph`, `Utils.Damage.Chunk`, `Utils.MoveReveal`, `Utils.ChaseHit`, `Utils.Yuta.SlashHit`, `Gojo.LapseBlue.Throw`. CollisionGroups `Effects`,`NoCollision`. `_G.Settings.Gore`, `_G.Settings.Flash` |
| 5 | Moveset/Kurourushi/Base/RoachSwarmController | ModuleScript | 297 | RoachSwarmController | RoachSwarmService (+FXController, KurourushiController) | none | Effects: `Hit(char,target)`, `Swarm1(char,cf,variant,marker)` (quadratic bezier swarm flight 0.5s; marker attr `KeepVFX`), `Swarm2(char,cf,marker)` (2 swarms, reuses existing `Swarm` with attr `Owner==char.Name`, cubic bezier), `Finisher(_,target)` (swarm orbits target; every 0.25s a limb → `Utils.Damage.Skeleton` part; `Megumi.Rabbit.Eat` snd; Bleed), `Explosion(pos)` | No | Sounds `Kurourushi.RoachSwarm.{Hit,Swarm1,Swarm2,SwarmFollowupWhoosh,SwarmFollowup,Explosion}`. VFX `Utils.Kurourushi.{RoachExplosion,Swarm}` |
| 6 | Moveset/Locust/BlackMucusController | ModuleScript | 108 | BlackMucusController | BlackMucusService (+FXController) | none | Effects: `Start(char)`, `Fire(char,cf)`, `Interp(part)` (client extrapolation 125 studs/s forward; plays Explode snd when part reparented to `workspace.Effects`), `Hit(player,target)` (Flash purple (0.65,0,1) 15s) | No | Projectile. Sounds `Locust.BlackMucus.{Use,Fire,Explode,Hit}`. VFX `Utils.Locust.MucusFire` |
| 7 | Moveset/Locust/CleverController | ModuleScript | 127 | CleverController | CleverService (+FXController) | none | Effects: `Startup(char)`, `Barrage(char,marker)` (Hakari.Barrage arm-clone loop every 0.025s until marker gone), `Hit(target)`, `Hit2(target)` | No | Four-armed barrage. Sounds `Locust.FourArmed`, `Misc.Swing.Fist`, `Gojo.M1.Hit1-4`, `Itadori.CraniumSmash.Hit2`. VFX `Utils.Hakari.Barrage`, `Gojo.LapseBlue.Throw` |
| 8 | Moveset/Locust/CrushJawController | ModuleScript | 154 | **CrusshJawController** (typo in Name) | CrushJawService (+FXController) | none | Effects: `Crush(player,pos)`, `Chomp(char,idx)`, `Bite(target)`, `Hit(target)`, `Dash(char)`, `Leap(char)` | No | Bite grab. Sounds `Itadori.CrushingBlow.{GroundImpact,Hit1,Hit2}`, `Locust.Chomp.{Bite<N>,Hit,Dash,Throw,Slam}`. VFX `Itadori.CrushingBlow`, `Locust.MucusFire`, `Mahito.BodyRepel.Wind1-5` |
| 9 | Moveset/Locust/LocustController | ModuleScript | 262 | LocustController | LocustService (+HitboxController, FXController) | none (no Hitbox handler) | Effects: `Hit(target,idx)`, `ChaseHit`, `AerialHit`, `Chase`, `Swing`, `Swing2(char,idx,dir)` (ArmFlash RGB 85,170,0; `Utils.Locust.Claws` trails), `Launch(char,yOff)`, `Flight(char,moverPart,_)` (LOCAL owner: sets `HRP.CFrame` to camera look and `part.Position=HRP+camLook*40*(1,0.5,1)`), `StingerOut`, `StingerFire`, `PoisonHit(target)` | No (but `Flight` lets client set own HRP CFrame/part pos) | Character controller (M1 = claws; hits 3 = punch, else slash). Sounds `Gojo.M1.Hit<N>`, `Locust.Slash.{Punch,Slash}`, `Locust.Flight`, `Locust.Victory` (Voice), `Locust.Chomp.Dash`, `Mahito.ForceGrab.{Retract,Swing}`, `Mahito.Variants.Transform1/3`, `Mahito.Soulfire.Hit`, `Itadori.CraniumSmash.Hit2`, `Misc.Chase`, `Misc.Swing.Fist`, `Megumi.Mahoraga.Throw.Break`. VFX `Utils.ChaseHit`, `Gojo.HardHit`, `Gojo.LapseBlue.Throw`, `Locust.Claws`, `Itadori.Shock`, `Locust.MucusFire` |
| 10 | Moveset/Locust/WingThrowController | ModuleScript | 150 | WingThrowController | WingThrowService (+ToolController, FXController) | none | Effects: `Dash(char,moverPart)` (LOCAL owner: BodyGyro=camera CF, PlatformStand; for 0.7s raycast `_G.MapParams` 10 studs and set `part.Position` to hit-4 or HRP+camLook*25), `Throw(char)`, `Grab(char,target)`, `ThrowHit(target)` | No (client positions mover) | Sounds `Locust.Flight`, `Todo.BruteForce.Swing`, `Gojo.LapseBlue.Grab`. VFX `Itadori.DivergentFist.BlackFlashLaunch`, `Choso.CounterSwing.Shock`, `Itadori.Shock` |
| 11 | Moveset/Mahito/PreAwk/BodyDisfigureController | ModuleScript | 481 | BodyDisfigureController | BodyDisfigureService (+HitboxController, FXController) | `gui:FindFirstChildWhichIsA("UnreliableRemoteEvent"):FireServer()` per Jump press during `Grab` (mash input, capped 20 presses) | Effects: `Pierce(char)`, `Hit(target)`, `Arm(char,armProj)` (ForceGrab hand+beam; on Destroying retracts to Right Arm), `Grab(char,billboardGui)` (LOCAL victim: mash Jump → fires gui's UnreliableRemoteEvent, bar `gui.Bar.Size`), `Swing`, `Throw`, `Dash(char,marker,_)`, `Drill(char,marker)` (DrillArm spinning on Right Arm), `DrillHit(player,char,target,marker)` (loop Flash + DrillHit snd 0.1s; Gore → BloodyZee blood), `Jump(targetPart,bodyPosition)` (BodyPosition follows target) | No | Mash-escape grab. Sounds `Mahito.DrillSplit.{Morph,Unmorph,Leap,DrillWind,Drill,DrillHit}`, `Mahito.Variants.M3.Hit1-4`, `Mahito.ForceGrab.{Fire,Retract,Swing}`, `Itadori.Rush.RushBreak`, `Gojo.LapseBlue.Grab`, `Misc.UI.Click`, `Megumi.Mahoraga.Throw.Throw`. VFX `Mahito.Worms.Morph2`, `Mahito.Pierce`, `Mahito.Morph`, `Mahito.Drill.{DrillArm,DrillImpact}`. `_G.Settings.Gore` |
| 12 | Moveset/Mahito/Base/BodyRepelController | ModuleScript | 265 | BodyRepelController | BodyRepelService (+FXController) | none | Effects: `Start(char,folder)`, `Clap(char,folder)`, `Fire(char,projPart,ridesIt)` (6-segment BodyRepel body chain follows proj; 120 studs/s extrapolation while server-updated, 60/s after; if `ridesIt` owner HRP is pinned to Head), `Hit(player,target)` | No | Sounds `Mahito.BodyRepel.{Start,Clap,Fire}`, `Hakari.EnergySurge.Hit2`. VFX `Utils.Mahito.BodyRepel.{BodyRepelStart,BodyCreate,BodyRepel(Head,Body1-5),Wind1-5}`, `Itadori.RushWind`, `Megumi.DivineAttack`, `Mahito.Morph` |
| 13 | Moveset/Mahito/Awake/CrushingRushdownController | ModuleScript | 193 | CrushingRushdownController | CrushingRushdownService (+HitboxController, FXController) | none | Effects: `Interp(part)` (200 studs/s; beam curve elastic), `HairRetract(char,hairModel)`, `Hair(char,target,attachment)` (HairEnd/HairGrab welded to target Left Leg), `Hit(player,target)`, `Ram(char,marker)` | No | Sounds `Mahito.CrushingRushdown.{HairPull,Leap}`, `Hakari.EnergySurge.Hit1`, `Mahito.WideSPStrike.Crush2`, `Megumi.Mahoraga.Throw.{Wind,Throw}`. VFX `Mahito.Worms.{HairEnd,HairGrab}`, `Mahito.CrushingRushdown.{DrillImpact,Dash}` |
| 14 | Moveset/Mahito/Awake/FaceBlitzController | ModuleScript | 250 | FaceBlitzController | FaceBlitzService (+HitboxController, FXController) | none | Effects: `Grab(target)`, `Leap(char)`, `Leap2(char)`, `Teleport(char)` (Gojo.Teleport x2 scale, RootJoint elastic, fades `char.Outfit` parts in), `Crush(pos)` (Earthquake + WorldSlash mesh) | No | Sounds `Gojo.LapseBlue.Grab`, `Itadori.CrushingBlow.GroundImpact`, `Itadori.Rush.RushLaunch`, `Megumi.Mahoraga.Takedown.Teleport`, `Megumi.Mahoraga.Throw.Break`, `Mahito.WideSPStrike.Crush/Crush2`. VFX `Itadori.CrushingBlow` (recolor 0.667,0.333,1), `Itadori.Shock`, `Mahito.Worms.WormLaunch.groundwaveing.*`, `Gojo.Teleport`, `Megumi.Mahoraga.{Earthquake,WorldSlash.mesh}`. `_G.MapParams` |
| 15 | Moveset/Mahito/Base/FocusStrikeController | ModuleScript | 407 | FocusStrikeController | FocusStrikeService (+FXController) | none | Effects: `Startup(char,variant)`, `Chain(char)` (physics rope whip `Mahito.Whip` S1-S6 w/ BodyForce, rope→rod swap), `Hit(_,target)`, `BlackFlashHit(char,target)`, `Finisher1(char,target)`, `Finisher(char,target)` (limb morph burst then Dismantle explode + Bleed), `ChainHit(_,target)`, `BigClub(char)` (`Mahito.BigClub` on Right Arm 1.9s) | No | Sounds `Hakari.OverLuck.Charge`, `Mahito.Variants.Transform2/3`, `Mahito.Chainwhip.{Chains,Swing,Hit}`, `Itadori.CraniumSmash.Hit1`, `Itadori.DivergentFist.BlackFlashHit`, `Mahito.BlackFlash`, `Itadori.Rush.RushBreak`, `Itadori.Dismantle.Explode`, `Mahito.ForceGrab.Swing`. VFX `Mahito.{Morph,Whip,FocusHit,FocusHit.Burst,BigClub}`, `Itadori.DivergentFist.{FlashBurn,BlackFlashHit,BlackFlashCC,BlackFlashLaunch}`, `Gojo.BlackFlashHit.Sparks2`, `Gojo.Twofold.Sparks`. `_G.Settings.Flash` |
| 16 | Moveset/Mahito/Awake/HeadSplitterController | ModuleScript | 164 | HeadSplitterController | HeadSplitterService (+HitboxController, FXController) | none | Effects: `Weave(char,target)` (FOV 50 + desaturate 1.5s, ScreenSlash on target Head, 30 HitGlow afterimages, EyeTrails, `What` voice at 0.7s), `Hit(target,final?)` (BlackFlashCC flash, Bleed on final) | No | Sounds `Mahito.HeadSplit.{Weave,Weave2,Bass,What(Voice),Slash}`, `Mahito.DrillSplit.{Leap,Drill}`, `Itadori.Dismantle.Slash`. VFX `Mahito.WideSPStrike.ScreenSlash`, `Damage.HitGlow`, `Gojo.Teleport`, `Itadori.EyeTrails`, `Mahito.Sparks`, `Itadori.DivergentFist.BlackFlashCC`. `_G.Settings.Flash` |
| 17 | Moveset/Mahito/PreAwk/IdleTransfigurationController | ModuleScript | 413 | IdleTransfigurationController | IdleTransfigurationService (+HitboxController, FXController) | none | Effects: `Start`, `Flash(char)` (EyeGlow), `Dash(char,mover)` (LOCAL owner: NumberValue 200→50 tween, sets `mover.Velocity=HRP.LookVector*value` each Stepped), `Hit(player,target)` (AudioVis GUI, ExposureCompensation -4), `HitFinish(char,target)`, `Finisher(target)` (head explode; `Moveset=="Nanami"` → torso+arms too, `SetAssets` destroyed), `BlackFlashImpact`, `BlackFlashHit` | No (client drives own dash velocity) | Attribute `Moveset` ("Nanami" check). Sounds `Mahito.Transfig.{Start,Eyes}`, `Itadori.Rush.{Rush,RushBreak}`, `Hakari.OverLuck.Hit1`, `Mahito.Soulfire.Morph`, `Mahito.Slap`, `Itadori.Dismantle.Explode`, `Itadori.DivergentFist.BlackFlashHit`, `Mahito.BlackFlash`. VFX `Mahito.EyeGlow`, `Itadori.{RushWind,Shock}`, `Mahito.BodyRepel.Wind<N>`, `Mahito.CrushingRushdown.DrillImpact`, `Hakari.IdleDeath.AudioVis`, `Mahito.FocusHit.Burst`, `Mahito.Morph`, `Damage.Chunk`, `Itadori.DivergentFist.{BlackFlashCC,BlackFlashLaunch}`. `_G.Settings.Gore/Flash` |
| 18 | Moveset/Mahito/MahitoController | ModuleScript | 1077 | MahitoController | MahitoService (+HitboxController, FXController, ToolController) | `remote:FireServer(hits, HRP.CFrame)` from `Service.Hitbox` | Effects: `Hit(target,idx,variant,dir)` (variant 1→`Mahito.Variants.M1`, 2→`M2` unless dir=="Up", 4→`M3`, else `Gojo.M1`), `BladeHit`, `ChaseHit`, `Chase`, `ChaseStart(char,variant)`, `Chase2(char,variant,pos)`, `Swing`, `Swing2(char)` (RootJoint spin, DashSlash), `Swing3(char,idx,dir,variant)` (variant 1 sword trails on `SetAssets.Weapon.MahitoWepR/L.Sword.Blade`; 2 club trails on `...Club.ClubBase`; 3/4 arm flashes RGB 124,80,255), `Launch`, `M(char,variant,partsList)` (transform morph on given parts), `Chat2`, `Worms(char)` (15 worm ragdolls), `Spit`, `Chat`, `Worms2`, `Dash`, `BlackFlashImpact`, `BlackFlashHit`, `Eat`. Other: `Service.Hitbox(startObj,char,remote,continuous)` | **YES** — `continuous`: loop `SphereHitbox(char,CFrame(0,0,0),12)` every 0.05s, `remote:FireServer(hits,HRP.CFrame)` whenever >0; else same as Kurourushi (offset -4, r 8, Knockback check, NumberValue→0) | Character controller with 4 weapon "variants" (Transform1/2/3 sounds). Sounds `Mahito.Variants.{M1,M2,M3}.Hit<N>`, `Mahito.Variants.{StrikeStart,Spin,Strike,Transform1,Transform2,Transform3}`, `Megumi.Mahoraga.M1.Hit1`, `Mahito.Worms.{Fire,Spit,Morph,Whip}`, `Mahito.Transfig.Start`, `Mahito.BlackFlash`, `Mahito.Eat`, `Gojo.BlindsOff`, `Gojo.GrabBlinds`, `Itadori.Rush.Rush`, `Itadori.DivergentFist.BlackFlashHit`, `Gojo.M1.Hit<N>`, `Misc.Chase`, `Misc.Swing.Fist`, `Megumi.Mahoraga.Throw.Break`. VFX `Mahito.{Dash,ClubCombatTrail,SwordCombatTrail,Morph,EyeGlow}`, `Mahito.Worms.{WormLaunch,DashSlash,Dialogue,Dialogue2,Worm,Spit,FleshSpread,Morph2}`, `Mahito.BodyRepel.BodyRepelStart`, `Megumi.Wep.Attachment.Ring`, `Itadori.{RushWind,Shock}`, `Itadori.DivergentFist.{BlackFlashCC,BlackFlashLaunch}`, `Utils.ChaseHit`, `Gojo.LapseBlue.Throw`. `_G.Settings.Flash` |
| 19 | Moveset/Mahito/Base/SoulfireController | ModuleScript | 141 | SoulfireController | SoulfireService (+FXController) | none | Effects: `Morph(char,marker)`, `Fire(char,proj)`, `Interp(part)` (200 studs/s), `Hit(target)` | No | Projectile. Sounds `Mahito.Soulfire.{Morph,Fire,Hit}`. VFX `Mahito.Morph`, `Gojo.LapseBlue.Throw`, `Gojo.Twofold.Sparks` |
| 20 | Moveset/Mahito/PreAwk/SpikeWrathController | ModuleScript | 230 | SpikeWrathController | SpikeWrathService (+HitboxController, FXController) | none | Effects: `Startup(char,_)`, `Start(char,marker)` (loop Pierce beams from `Torso.BodyFrontAttachment` + Morph2 blobs every 0.075s while marker alive), `Grab(char,beam,duration)`, `Grab2(char,target)` | No | Sounds `Mahito.ForceGrab.Retract`, `Mahito.Roll`, `Mahito.DrillSplit.{Morph,Unmorph}`. VFX `Mahito.Pierce`(+`.Pierce` beam), `Mahito.Worms.Morph2` |
| 21 | Moveset/Mahito/Base/StockpileController | ModuleScript | 214 | StockpileController | StockpileService (+FXController) | none | Effects: `Create(char,wep1,wep2)` (morph-in; on Destroying drop physical copies), `Swing(char,isFirst)`, `Hit(_,target)`, `FinalHit(player,target)`, `Crush(player,pos)` (magenta CrushingBlow), `Finisher(_,target)` (flatten Z to 5%, BloodyZee x40, `Heian.BloodSpread` if Gore) | No | Sounds `Mahito.Stockpile.{Create,Swing,Swing2}`, `Itadori.CraniumSmash.Hit1/2`, `Itadori.CrushingBlow.GroundImpact`, `Itadori.Dismantle.Explode`, `Megumi.Elephant.Explode`. VFX `Mahito.Morph`, `Gojo.Twofold.Sparks`, `Itadori.CrushingBlow`, `Heian.BloodSpread`. `_G.Settings.Gore` |
| 22 | Moveset/Mahito/Awake/WideSPStrikeController | ModuleScript | 220 | WideSPStrikeController | **WideSPStrikesService** (plural; +HitboxController, FXController) | none | Effects: `Afterimages(char)` (4 anchored clones playing `Animations.Mahito.WideStrike` spin around owner 2.1s; HitArea ring shrinks 25→0 over 2.1s; real char + `Aura` particles hidden), `Voice(char,flag)`, `Voice2`, `Hit(char,target)` (ScreenSlash on Flash) | No | AoE spin. Sounds `Mahito.WideSPStrike.{Start,Voice(Voice),Flash(Voice),Hit1-5}`. VFX `Mahito.WideSPStrike.{HitArea,Afterimage,ScreenSlash}`, `Mahito.Worms.DashSlash.Attachment`. Shaker `HardHit` preset. `_G.MapParams`, `_G.Settings.Flash` |
| 23 | Moveset/Mechamaru/Awake/AbsoluteDestructionController | ModuleScript | 158 | AbsoluteDestructionController | AbsoluteDestructionService (+HitboxController, FXController) | none | Effects: `Start(char,isJump,marker)` (Run loop faded when marker attr `Footsteps` false), `Step(char,pos)`, `Jump(char,pos)`, `Slam(char,pos)`, `Hit2(target,color)` | No | Attr `Footsteps`, `EmitCount`. Sounds `Mechamaru.AbsoluteDestruction.{Jump,Run,Slam}`, `Hakari.EnergySurge.Hit1`. VFX `Mechamaru.{Dust,BigSlam}`, `Choso.CounterSwing.Shock`, `Mahito.CrushingRushdown.DrillImpact`. `_G.MapParams` |
| 24 | Moveset/Mechamaru/Base/BoostOnController | ModuleScript | 197 | BoostOnController | BoostOnService (+HitboxController, ToolController, FXController) | none | Effects: `Start(char,troveHost)` (BoosterL/R Motor6D `Arm BoostterrrrR/L` on arms, C0 (0,0.75,0.625)), `Boost(char)` (Stage1→Stage2 emitters), `Hit(char,target)`, `Touch(char,target,host)` (`Hand blasterR`; hidden if `Moveset~="Mechamaru"`), `Blast(char)` | No | Uses Trove, SraikoVFX(HandleMesh/Emit/Enabled), EffectUtils. Sounds `Mechamaru.BoostOn.{PunchWoosh,Start,Booster,SecondPart,Hit}`, `Mechamaru.PuppetBarrage.FlyUp`, `Gojo.LapseBlue.Grab`, `Mechamaru.UltraCannon.{Shoot,Explode}`. VFX `Utils.Mechamaru.{BoosterL,BoosterR,BoostOnVFX.BoostHit.Meshes.Mesh,BoostOnVFX.BoostHit.Emit.Strike,Hand blasterR,Heat,CannonFire}`, `Misc.M.{DashHit,Slash.PointLight}` |
| 25 | Moveset/Mechamaru/Base/HeatEmissionController | ModuleScript | 197 | HeatEmissionController | HeatEmissionService (+FXController) | none | Effects: `Start(char,host)` (boosters), `Leap(char)`, `Blast(char,ignite)` (ignite → FireCannon AutoEffects + Ignition snd; else shock ring), `Hit(target,_)` | No | Sounds `Mechamaru.HeatEmission.{Start,Vent,Ignition}`, `Naoya.Decisive.Swing2`. VFX `Mechamaru.BoosterL/R`, `Mechamaru.BoostOnVFX.BoostHit`, `Hiromi.Shockwave`, `Misc.M.{DashHit,Slash.PointLight}`, `Mechamaru.Heat`, `Mechamaru.UltraCannonVFX.FireCannon`, `Choso.CounterSwing.Shock` |
| 26 | Moveset/Mechamaru/MechamaruController | ModuleScript | 599 | MechamaruController | MechamaruService (+HitboxController, FXController) | none (no Hitbox handler) | Effects: `Hit(target,idx)`, `ChaseHit`, `Chase`, `Swing`, `Swing2(char,idx,dir)` (ArmFlash RGB 225,10,75; idx 1/2/4 right arm, 3 left), `Swing3(char,idx,_)` (awakened `Absolute.M1Swing.Swing<N>`), `Hit2(target,idx)` (awakened `Absolute.M1.Hit<N>`), `Launch`, `OffloadCharge(char,marker,red)`, `OffloadAura(char,marker,red)`, `SupermanLanding`, `BackSlide`, `ArmsFlyIn`, `FunnyFall`, `SmoothLanding1`, `SmoothLanding2` (entrance/landing variants), `Sparks(part)`, `Explosion(pos,isUlt)` (DesPHY → `Hiromi.GavelShard` debris 10/35) | No | Character controller; "Offload"/"Absolute" = awakening naming. Red recolor RGB 250,75,75 when `red` flag. Sounds `Gojo.M1.Hit<N>`, `Mechamaru.Absolute.M1Swing.Swing<N>`, `Mechamaru.Absolute.M1.Hit<N>`, `Mechamaru.Offload.{Charge,Burst,StopSound,SupermanLand,BackSlide,ArmsFlyIn,FunnyFall,SmoothLanding,SmoothLanding2,Sparks,Explode}`, `Misc.Chase`, `Misc.Swing.Fist`, `Megumi.Mahoraga.Throw.Break`. VFX `Utils.Mechamaru.Offload.{Burst,ChargeEffect,Aura,SupermanLanding,Backslide.ArriveDashBurst/ArriveDash,ArmsFlyIn.*,FunnyFall.*,SmoothLanding1.*,SmoothLanding2.*}`, `Mechamaru.{Detonate,DetonateUltScaled}`, `Hiromi.GavelShard`, `Utils.ChaseHit`, `Gojo.LapseBlue.Throw`. `_G.Settings.DesPHY` |
| 27 | Moveset/Mechamaru/Awake/MiracleCannonController | ModuleScript | 212 | MiracleCannonController | MiracleCannonService (+HitboxController, FXController) | none | Effects: `Charge`, `Charge2`, `Push`, `ShootBeam`, `Explode(char,part)`, `OneYearCharge`, `1YearEnabled(char)`, `1YearExplode(char,cf,_,length,_)` (BeamForShoot scaled to length+7), `1YearHit(target,burn)` (FX:Burn + `Damage.Flames` on parts). Other signal: **`Service.Debree(debrisList, container)`** (S→C; spawns debris parts from `{pos,orient,color,material,size}` tuples if DesPHY and within 100 studs of container attr `WorldPosition`) | No | Sounds `Mechamaru.MiracleCannon.{AttemptCharge,AttemptChargePhase,ChargeBeam,Explosion,OneYearCharge,OneYearExplosion}`. VFX `Mechamaru.MiracleCannonVFX.{Start,Start2,CHARGECVFX,CHARGECVFX2,Push,Shoot,ExplodeVFX,BeamForShoot,OneYear.Shoot}`, `Damage.Flames`. FX methods `Burn`, `DebreeSound`. `_G.Settings.DesPHY` |
| 28 | Moveset/Mechamaru/Awake/PigeonViolaController | ModuleScript | 148 | PigeonViolaController | PigeonViolaService (+HitboxController, FXController) | none | Effects: `Start(char)`, `Spawn(char)`, `Shoot(char)`, `Interp(part)` (client extrapolation using part attr `Speed`), `Hit(target,color)`, `Explode(char,part)` (DrillImpact colored `part.Color`) | No | Homing projectiles. Sounds `Mechamaru.PigeonViola.{Start,Hit1,Hit2}`. VFX `Mechamaru.PigeonViolaVFX.{Hands,Spawn,Stars}`, `Mahito.CrushingRushdown.DrillImpact` |
| 29 | Moveset/Mechamaru/Awake/TechniqueChargeController | ModuleScript | 269 | TechniqueChargeController | TechniqueChargeService (+HitboxController, FXController) | none | Effects: `FingertipLightning(char,marker)` (`char.FingersR` → `GunEffects` attachment), `FingerShoot(char,cf,target)` (GunBullet beam), `SpecialStartSound`, `SimpleDomainDart(target,fromPos)` (dart welded into Torso via raycast, capsule spins 1s, detonates; if target `Moveset=="Mahito"` spawns half-size worms) | No | Sounds `Mechamaru.Absolute.Special.{LightningStart,LightningLoop,Shot,Start}`, `Mahito.Soulfire.{Fire,Hit,Morph}`, `Mahito.Worms.Fire`. VFX `Gojo.LapseBlue.Throw`, `Mechamaru.{GunBullet,SimpleDomainDart}`, `Mahito.Morph`, `Mahito.Worms.Worm` |
| 30 | Moveset/Mechamaru/Base/UltraCannonController | ModuleScript | 272 | UltraCannonController | UltraCannonService (+FXController, ToolController) | `remote:FireServer(ToolController:GetMouseTarget(75))` every frame while host alive (aim stream) in `Start` | Effects: `Start(char,host,remote,ownerChar)` (`Hand blasterL`; LOCAL owner streams mouse target), `FireCannon(char)`, `AlbatrosStart(char,host)` (`Mecha mouth blaster` on Head if Mechamaru moveset; boosters), `AlbatrosCharge(char,host)`, `AlbatrosFire(char,host)` (beam length via raycast ≤37.5, 21 ticks × 0.07s), `AlbatrosHit(target)` | No (aim only) | Attr `Moveset~="Mechamaru"` hides parts. Sounds `Mechamaru.UltraCannon.{Start,Shoot,Albatros}`. VFX `Mechamaru.{Hand blasterL,Mecha mouth blaster,BoosterL,BoosterR,CannonFire}`, `Mechamaru.UltraCannonVFX.{FireCannon,AlbatrosStart,AlbatrosCharge,AlbatrosFire,AlbatrosRepeat}` (attrs `RepeatCount`,`RepeatDelay`,`MaxSpeed`), `Itadori.RushWind`. `_G.MapParams` |
| 31 | Moveset/Mechamaru/Base/UltraSpinController | ModuleScript | 378 | UltraSpinController | UltraSpinService (+HitboxController, FXController) | none | Effects: `Start(char,host)` (`Mechamaru.Drill` on Right Arm), `DrillAppear(char,marker)`, `DrillWindup`, `DrillSwing(char,marker)` (cleans when `GrabWeld` added to HRP), `DrillHide`, `DrillStop`, `HitSound(target)`, `Hit(char,marker,target,grabbed)` (loop Flash/DrillHit/BloodyZee 0.075s until marker leaves `workspace.Characters` or attr `Finisher`; shaker `HeavyLoop`), `FinalHit(char,_,target,_)`, `Finisher(char)`, `DrillClose`, `BurstEnableTrue(char)` (`Hand blasterR` 4s), `BurstEnableFalse`, `Burn(char,marker)` (until marker attr `Disable`), `Burn2`, `Burn3`, `Strike2(char,marker)` (sets `Disable=true`), `Burnt`, `BurnFalse(_,marker)` (clears `Disable`) | No | Drill grab. Sounds `Mechamaru.UltraSpin.{Start,Dash,End,Hit,Finisher}`, `Mahito.DrillSplit.DrillHit`, `Megumi.Mahoraga.Throw.Break`, `Hakari.Impact`. VFX `Mechamaru.Drill`(B/F/L/R/Metalbit), `Mechamaru.UltraSpinVFX.{DrillRepeat,DrillAppear,DrillSwing,DrillSlam,DrillClose,ShootReady,Shoot,Burn,Burn2,Burn3,Burn4,Burnt}`, `Mahito.Drill.DrillImpact`, `Hiromi.Shockwave`, `Choso.CounterSwing.Shock`, `Hand blasterR`. `_G.Settings.Gore` |
| 32 | Moveset/Megumi/Mahoraga/AdaptationController | ModuleScript | 411 | AdaptationController | AdaptationService (+FXController) | none | Effects: `Glow(char)` (`Outfit.Head.DivineWheel` neon copy), `Adapt(char,target,silent)` (`DivineWheelWeld` spin; GUI `Utils.Megumi.Mahoraga.Adapt`: `Type.Text = (attr A1 or "Melee").." Attacks"`, `Effect.Text` from attr `A2`: 1.1→-10% DMG, 1.3→-30%, 1.5→-50%, 1.7→-70%, else "FULL ADAPTATION"), `Start`, `Teleport(char)`, `Hit(char,target)`, `WorldSlash(char)` (needs `char.Info.WorldSlash`), `WorldSparkle(char)` (ImpactFrames CC), `Interp(char,slashPart)` (250 studs/s), `WorldHit(target,final)` | No | Mahoraga adaptation. Attributes `A1`,`A2`; Info value `WorldSlash`. Sounds `Megumi.Mahoraga.{AdaptGlow,Adapt2,Takedown.Startup,Takedown.Teleport,WorldSlash.Startup,WorldSlash.Swing}`, `Megumi.Elephant.Hit`, `Itadori.Rush.RushLaunch`, `Itadori.Dismantle.{Slash,Explode}`. VFX `Utils.Megumi.Mahoraga.{Adapt,WorldSlash,ImpactFrames}`, `Gojo.{Teleport,HardHit}`, `Itadori.DivergentFist.BlackFlashCC`. `_G.Settings.Flash` |
| 33 | Moveset/Megumi/Base/DivineDogController | ModuleScript | 191 | DivineDogController | DivineDogService (+FXController) | none | Effects: `Summon(part)`, `Follow(char,dogModel,marker)` (client-side pet positioning 8 studs right of owner, raycast to ground; follows `dog.Target.Value` / attr `CF`; reacts to `char.Info.Emote`), `Slash(dog,idx)` (1-2 slash, 3 bite), `Hit(player,target,idx)`, `Finisher(target)` (Bleed) | No | Dog anims from `dog.AnimationController.{DivineDogsIdle,DivineDogsWalk,Emote}`. Sounds `Megumi.DivineDog.{Spawn,Despawn,Slash,Bite,SlashHit,BiteHit}`. VFX `Megumi.Spawn`, `Megumi.DivineAttack`. Raycast include `workspace.{Map,Spawns,Domains}` |
| 34 | Moveset/Megumi/Mahoraga/DivinePummelController | ModuleScript | 98 | DivinePummelController | DivinePummelService (+FXController) | none | Effects: `Swing(char)`, `Grab(target)`, `Hit(player,target)` (ground impact under player's Right Arm), `FinalHit(player,target)` | No | Sounds `Misc.Swing.Fist3`, `Gojo.LapseBlue.Grab`, `Gojo.M1.Hit3/4`, `Itadori.CrushingBlow.GroundImpact`. VFX `Itadori.CrushingBlow` |
| 35 | Moveset/Megumi/Mahoraga/EarthquakeController | ModuleScript | 127 | EarthquakeController | EarthquakeService (+FXController) | none | Effects: `Start(char)`, `Crush(player,pos,noAttempt)` (FluxFissure + Attempt snd for owner), `Crush2(pos)` (success big quake + WorldSlash mesh) | No | Sounds `Megumi.Mahoraga.Earthquake.{Startup,Attempt,Success}`, `Itadori.CrushingBlow.GroundImpact`. VFX `Megumi.Mahoraga.{Cursed,Earthquake,WorldSlash.mesh}` |
| 36 | Moveset/Megumi/Awake/GreatSerpentController | ModuleScript | 290 | GreatSerpentController | GreatSerpentService (+FXController) | none | Effects: `Start`, `Leap(char)`, `Spawn(char,aimPart)` (serpent model segments follow Neck with sine wobble; owner hidden; on aimPart removal serpent flies off at 120/s; LOCAL owner: BodyGyro, PlatformStand, FOV 120, sets `aimPart.Position = HRP + camLook*value(50→25)`), `Hit(char,target,weld)` (weld C0 sways with owner's `Offset` NumberValue) | No (client positions aim part) | Sounds `Megumi.Serpent.{Start,Spawn,Fly,Despawn,Hit}`, `Itadori.CursedStrikes.Spin`, `Megumi.DivineDog.Despawn`. VFX `Gojo.HardHit`, `Megumi.Serpent`(Head,Jaw,Neck,Torso1-6,Tail), `Megumi.Spawn`, `Megumi.DivineAttack.Bite` |
| 37 | Moveset/Megumi/Mahoraga/GroundPitchController | ModuleScript | 170 | GroundPitchController | GroundPitchService (+FXController) | none | Effects: `Crunch(char,rockPart,debrisList)` (builds rock from `{pos,orient,color,material,size,transparency}` tuples into `rockPart.Rocks`; on Destroying break VFX), `Throw`, `Interp(part)` (150 studs/s), `Hit(target)`, `Finisher(target)` | No | Sounds `Megumi.Mahoraga.Throw.{Wind,Break,Throw}`, `Itadori.M1.Hit1`, `Itadori.Rush.RushHit`. VFX `Megumi.Mahoraga.Rock` |
| 38 | Moveset/Megumi/Awake/MahoragaUseController | ModuleScript | 335 | MahoragaUseController | MahoragaUseService (+FXController) | none | Effects: `Start(char)`, `Timer(char,target,second)` (chant bubble `Heian.Chant.Chant`: "I SUMMON" / "WITH THIS TREASURE"; `FX:DomainMapFade`), `Goodbye(char,target,cf)` (Mahoraga model plays `Animations.Megumi.MahoragaSummon`; for involved players: fullscreen Viewport cutscene GUI `Utils.Megumi.Mahoraga.Ritual` with Toad/Wolf rows, strings, `Itadori.MalevolantShrine.Music`), `Hit(char,target)` | No | Ult cutscene. Sounds `Megumi.Rabbit.Start`, `Megumi.Mahoraga.Ritual.{Timer,Spawn,Moving,Summon,Hit}`, `Itadori.MalevolantShrine.Music` (Music group). VFX `Megumi.Mahoraga.{RitualStart,Mahoraga,Ritual,String}`, `Heian.Chant.Chant`, `Itadori.DivergentFist.BlackFlashCC`. FX methods `DomainMapFade`, `WorldModelChar`. `_G.Settings.Flash` |
| 39 | Moveset/Megumi/Awake/MaxElephantController | ModuleScript | 140 | MaxElephantController | MaxElephantService (+FXController, ToolController) | none direct; exposes `Controller:ToolDeactivate()` → returns `ToolController:GetMouseTarget(75)` (ToolController presumably sends it) | Effects: `Start`, `Hitbox(marker)` (local aim preview `Megumi.HitArea` 40x40 following mouse target, raycast down 300 `_G.MapParams`), `Spawn(pos,isSpawn)`, `Smash(pos)`, `Hit(target)`, `Finisher(target)` (Bleed + 20 Chunks) | No | Sounds `Megumi.Rabbit.Start`, `Megumi.Elephant.{Spawn,Despawn,Hit,Explode}`. VFX `Megumi.{HitArea,Smash}`, `Damage.Chunk`. `_G.MapParams`, `_G.Settings.Gore` |
| 40 | Moveset/Megumi/MegumiController | ModuleScript | 237 | MegumiController | MegumiService (+HitboxController, FXController) | none (no Hitbox handler) | Effects: `Hit(target,idx)`, `ChaseHit`, `Shadow(char,marker)` (shadow decal follows under owner until marker gone), `Chase`, `Swing`, `Swing2(char,idx,dir)` (ArmFlash black; 1/3/Up right arm, 2 left arm, 4 left leg), `Launch`, `Chat(char)` (awaken dialogue `Megumi.Dialogue`) | No | Character controller. Sounds `Gojo.M1.Hit<N>`, `Megumi.ShadowEnter`, `Megumi.Rabbit.Despawn`, `Megumi.Awaken`, `Misc.Chase`, `Misc.Swing.Fist`, `Megumi.Mahoraga.Throw.Break`. VFX `Utils.ChaseHit`, `Megumi.{Shadow,Dialogue}`, `Gojo.LapseBlue.Throw` |
| 41 | Moveset/Megumi/Base/NueController | ModuleScript | 213 | NueController | NueService (+FXController) | none | Effects: `Nue(char,startPos,midPos,target,duration,bodyPos)` (quadratic bezier flight to target then away; BodyPosition (P→100000) drags grabbed target on Nue RightLeg; owner-side parents bodyPos into own Right Arm), `Hit(player,target)`, `Finisher(target)` (Burn + red CC) | No | Nue anim `Nue.AnimationController.Summon`. Sounds `Megumi.Nue.{Spawn,Hit1,Hit2}`. VFX `Megumi.{Spawn,Nue,NueShock}`, `Itadori.DivergentFist.BlackFlashCC`. `_G.Settings.Flash` |
| 42 | Moveset/Megumi/Base/RabbitEscapeController | ModuleScript | 206 | RabbitEscapeController | RabbitEscapeService (+FXController) | none | Effects: `Start`, `Rab(char,pos,duration)` (rabbit hops toward owner), `Hit(target)` (if target attr `Dead` → swap limb for `Damage.Skeleton` part + Eat snd), `Hit2(player,target)`, `Launch(char)` (`RabbitLaunch` parts flung up) | No | Attr `Dead`. Sounds `Megumi.Rabbit.{Start,Spawn,Despawn,Eat}`, `Gojo.M1.Hit1-4`, `Hakari.EnergySurge.Hit2`. VFX `Megumi.{Rabbit,Shadow,RabbitLaunch}`, `Damage.Skeleton` |
| 43 | Moveset/Megumi/Awake/ShadowSwarmController | ModuleScript | 399 | ShadowSwarmController | ShadowSwarmService (+HitboxController, MovementController, FXController) | none | Effects: `Domain(char)` (`FX:DomainBurst` + `Megumi.Voice`), `Start`, `Summon(char,folder)` (2 shadow clones with `FolderWeld` at (-6,0,-3)/(6,0,-2)→z=4; `Animations.Megumi.ShadowSwarmRun`; `MovementController:Tilt`), `Shadow(char)`, `Dash(char,folder)` (clones WalkSpeed 48, `Humanoid:Move` forward until weld re-enabled), `Grab(player,target,folder,marker)` (clones play `ShadowSwarm1/2`, lerp to target; LOCAL grabber: RenderStep `Cam2` CameraOffset, Head/Torso NoCollision), `Hit(target)`, `Swing(char,part)`, `FinalHit(player,target)`, `Wep(part)` (drops `Megumi.Wep` copy on destroy), `ForceFix(char,obj,pos,marker)` (destroys obj if >100 studs from pos) | No | Awakening/domain move. Anims `Animations.Megumi.{ShadowSwarmRun,ShadowSwarm1,ShadowSwarm2}`. Sounds `Megumi.Voice`(Voice), `Megumi.ShadowGarden.Start`, `Megumi.ShadowEnter`, `Itadori.Rush.Rush`, `Gojo.LapseBlue.Grab`, `Gojo.M1.Hit1-4`, `Megumi.Rabbit.Despawn`, `Itadori.CraniumSmash.Hit2`. VFX `Megumi.{Shadow,Wep}`, `Itadori.RushWind`, `Gojo.Twofold.Sparks`. CollisionGroups Effects/NoCollision/Default |
| 44 | Moveset/Megumi/Base/ToadController | ModuleScript | 287 | ToadController | ToadService (+FXController) | none | Effects: `Grab(char)` (purple Feint 125,45,152), `Toad(player,target,pos,folder)` (toad spawns, tongue attachment tweens to target then back; 1.2s), `ToadAir(_,target,pos,folder)` (10 `ToadNue` flyers), `Hit(_,target,folder)` (tongue beam → `TongueGrab` on target), `HitAir(_,target,folder)` | No | Sounds `Megumi.Toad.{Spawn,Fly,Flyback,Despawn,Hit}`, `Gojo.LapseBlue.Grab`. VFX `Itadori.CounterHit.Feint`, `Megumi.{Spawn,Toad,ToadNue,Shadow,TongueGrab}`. Toad anim `Toad.AnimationController.Summon` |
| 45 | Moveset/MeiMei/Base/BirdControlController | ModuleScript | 191 | BirdControlController | BirdControlService (+FXController, ToolController) | none | Effects: `Eye(char,target?)` (CrowEye; if target: Feint recolor 30,40,80 + Grapple.Start), `Hit(target)`, `Explode(_,pos)`, `Interp(part,caw,launch)` (extrapolation by attr `Speed`; Fly snd speed 2→1 when Speed changes; `CrowWind` if launch), `Flight(char,mover,destroyObj,crowModel)` (crow pivoted to Left Arm; LOCAL owner: BodyGyro=camera yaw, PlatformStand, `mover.Velocity` lerps to `moveVector*25*1.3` via `PlayerModule.ControlModule:GetMoveVector()`) | No (client drives own flight velocity) | Sounds `MeiMei.BirdControl.{CrowEye,Hit,Impact,Fly,Grab}`, `Hiromi.Grapple.Start`, `Misc.Crow.Caw1-3`, `MeiMei.CrowLaunch`. VFX `MeiMei.{CrowEye,CrowWind}`, `Itadori.CounterHit.Feint`, `Damage.CrowExplode` |
| 46 | Moveset/MeiMei/Base/CirclingController | ModuleScript | 739 | CirclingController | CirclingService (+FXController) | none | Effects: `Crush(_,pos,stage)` (scale 0.8+0.2*stage), `DivebombWhoosh(char)`, `DivebombFall(char,stageValue)` (NumberValue stages 1→2→3 escalate fall VFX FallStage1/2/3 + AxeWindTrail), `Start`, `Charge(char,level)` (1 orange 0.9x, 2 red 1.15x; `Nanami.BluntCut.Charge` meshes), `Slash(char)`, `Slash2(char,silent)`, `Slash3(char,target)` (calls Slash2 + FinisherWhoosh), `Hit1`, `Hit2`, `Hit3(char,target,final)`, `Finisher(target)`, `Hit4` | No | Axe divebomb. Requires `SetAssets.MeiMeiAxe(.Axe)`. SraikoVFX.HandleMesh. Sounds `MeiMei.Crush`, `MeiMei.Fall`, `MeiMei.Circling.{AirSlash,Start,Charge1,Charge2,Slash1,Slash2,FinisherWhoosh,Hit1,Hit2,FinisherHit,FinisherSlash}`. VFX `Hiromi.Shockwave`, `Choso.CounterSwing.Shock`, `MeiMei.Circling.{MeiMeiWideSlash1,2,3,SwingMesh,WindMesh1,2,3}`, `MeiMei.{FallStage1,2,3,AxeWindTrail,Shock}`, `Nanami.BluntCut.Charge`, `Mahito.CrushingRushdown.DrillImpact` (recolor 0.51,0.64,1), `Itadori.CrushingBlow.Floor.Wind2` |
| 47 | Moveset/MeiMei/Base/ImpetusUpdraftController | ModuleScript | 303 | ImpetusUpdraftController | ImpetusUpdraftService (+FXController) | none | Effects: `Hit(char,target,bleed)`, `Slash(char)` (ground `Launch` VFX), `Slash2(char,idx1-3)`, `Hit2(char,target,idx)`, `Slash3(char,idx1-5)`, `Hit3(char,target,idx)`, `Finisher(target)` (sets attr `MeiBleeding`, Bleed once) | No | Launcher + aerial string. Attr `MeiBleeding`. Sounds `MeiMei.{UpdraftHit,UpdraftSlash}`. VFX `MeiMei.{SlashHit,Launch,MeiMeiSlash}`, `MeiMei.Circling.{SwingMesh,WindMesh1}`. `_G.MapParams` |
| 48 | Moveset/MeiMei/MeiMeiController | ModuleScript | 458 | MeiMeiController | MeiMeiService (+HitboxController, FXController, ToolController) | `remote:FireServer(camPos + camLook*100)` every frame in `CrowUltimate` while crow attr `InControl` (aim stream) | Effects: `Hit(char,target,idx,dirOverride)`, `ChaseHit`, `AerialHit`, `Chase`, `Swing(char,idx,dir)` (`MeiMei.M1.Swing<N|Up|Down>`), `Swing2(char,idx,flag)` (CombatTrail on `SetAssets.MeiMeiAxe.Axe`; 0.75s if idx 4), `Launch`, `Flock`, `FlockHit(char,target)`, `Jump`, `Crowstep(char)` (drops `MeiMei.Crow` ragdoll + CrowExplode), `UltimateStart`, `CrowUltimate(char,crowModel,remote)` (LOCAL owner: camera subject = crow, MinZoom 5, streams aim), `CrowControl(char,crow)`, `CrowStart(_,crow)`, `CrowHit(char,crow,target|cf)` (BirdoStrike voice, BirdStrikeHit1), `CrowSmash(char,crow,target)`, `CrowBoom(char,_,pos)`, `TeleportStart`, `Teleport(char,cf1,cf2)` (Naoya.Teleport at both ends) | No (aim only; no Hitbox handler) | Character controller. Attr `InControl` on crow. Sounds `MeiMei.M1.{Hit<N>,Swing<N>,SwingUp,SwingDown}`, `MeiMei.{Flock,UltStart,BirdoStrike(Voice),CrowHit,CrowSmash,CrowExplode,Teleport,WingFlap}`, `Hiromi.Grapple.Hit`, `Gojo.InfiniteVoid.Hits.Hit3`, `Misc.CrowMad2`, `Itadori.CraniumSmash.Hit2`, `Misc.Chase`, `Megumi.Mahoraga.Throw.Break`. VFX `MeiMei.{SlashHit,CombatTrail,Crow,CrowControl,BirdStrikeHit1,BirdStrikeHit2,BirdStrikeAOE}`, `Yuta.SlashHit` (recolor 34,48,56), `Gojo.HardHit`, `Gojo.LapseBlue.Throw`, `Gojo.LapseBlue.LapseBlue.Grab`, `Damage.CrowExplode`, `Naoya.Teleport`. `StarterPlayer.CameraMinZoomDistance` restored |
| 49 | Moveset/MeiMei/Base/MurmurateController | ModuleScript | 411 | MurmurateController | MurmurateService (+FXController) | `remote:FireServer(landPos, normal)` once when client's raycast detects landing (or Y < -100) in `Flight` | Effects: `Flight(char,mover,remote)` (LOCAL owner: BodyGyro; 2-phase glide arc, speed 40→80 over 0.55s then 80→205 over 1.25s; client raycasts ahead/down and reports landing then destroys mover), `Start`, `Hit(char,target)`, `Hit2(char,target)`, `Slash2(char)`, `Slash(char,marker)` (marker attr `Start`; cycles Slash1-3 sounds), `Land(char,pos)`, `Throw(char,axeModel,marker)` (Murmurate particles on `axe.Stick`), `Catch(char)` | **Partial** — client decides landing position/normal and reports it | Axe-throw glide. Sounds `MeiMei.Murmurate.{AxeThrow,AxeSpin,AxeCatch}`, `MeiMei.Gliding.{Start,Slash1-3,SpinHit1-2,FallHit,FallSlash,Impact}`. VFX `Mahito.CrushingRushdown.DrillImpact`, `MeiMei.{SlashHit,MeiMeiSlash,Slam,ShockwaveMesh,WindMesh2,SpikeMesh1,Murmurate}`, `MeiMei.Circling.{SwingMesh,MeiMeiWideSlash3,WindMesh2}` |

### A.4 Movesets: Nanami, Naoya, Reggie, Ryu (35)

| # | Path (from header) | Type | Lines | Knit name | Services used | Client→server calls | Server→client signals handled (Effects keys) | Client-auth hit? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | .../Nanami/Base/CleavingWhirlController | ModuleScript | 255 | CleavingWhirlController | CleavingWhirlService; ctrl: FXController | none | Hit(attacker,victim,isRatio), Start(char,tracker), CleaverEmit(char,tracker), Slash, Swing(char,dur), Whoosh, Dash, Finisher(victim→FX:Bleed) | No | Cleaver spin. VFX `Utils.Nanami.CleavingWhirlwind.{Hit,VFX,SlashEmit,SlashBeam}`, `Utils.Nanami.CombatTrail` welded to `char.SetAssets.NanamiCleaver.Blade`, `Utils.Todo.Swing`, `Utils.Itadori.{RushWind,Shock}`. BloodyZee blood on ratio hit. Shakes MediumHit. |
| 2 | .../Nanami/Awake/CollapseController | ModuleScript | 360 | CollapseController | CollapseService; ctrl: HitboxController, FXController, HandicapController | **`remote:FireServer(rayHitPos, rayNormal, hrpPos)`** inside `Leap` (remote passed as arg; fired once after 0.3s when local raycast hits map) | Hit, Hit2, Jump(char,skip), ArmEmit, Leap(char,bodyPosPart,remote), Collapse(char,pos,normal), CollapseDebree(char,u16buffer,tracker), Break(pos), Launch(char,yVel), Finisher | **Partial: client chooses landing/impact point** | Awakening leap-slam: local player steers flight with camera LookVector via BodyGyro/BodyPosition (`PlatformStand=true`), raycasts with `_G.MapParams`, reports impact. `CollapseDebree` reads `buffer.readu16` voxel indices → `FX.Voxels[idx]` and drops `Utils.Nanami.Collapse.Rock` clones (map destruction). Waits for `HRP.CollapseBG` to vanish. Reuses `Utils.Gojo.LapseBlue.{Grab,Throw}`, `Utils.Heian.BloodSpread` (Gore), SraikoVFX.HandleMesh/Emit, `Sounds.Megumi.Mahoraga.Throw.Break`. Shakes Snap/HeavyHit/LightHit. `_G.Settings.Gore`. |
| 3 | .../Nanami/Awake/InterrogateController | ModuleScript | 362 | InterrogateController | InterrogateService; ctrl: FXController, ToolController | none | Start, Swing, Dash, TrueRagdoll, FinalSwing(char,victim,slowmo), Ohno(char,victim), Hit, Grab(victim,idx→`Sounds.Nanami.Interrogate["Grab"..idx]`), Chat(char,text,pitch), FinalHit(victim,isFinisher), FinalHit2 | No | Awakening grab/interrogation cinematic. FOV tweens (35/50→70), ColorCorrection desat. Text bubble reuses `Utils.Hiromi.DeadlySentencing.HiromiText` (destroys existing `Head.HiromiText`), voice via `SoundService.Voice`. Blood freeze uses `Utils.Naoya.BleedFreeze.Attachment` (Gore). VFX: `Utils.Itadori.DivergentFist.BlackFlashLaunch`, `Utils.Choso.CounterSwing.Shock`, `Utils.Mahito.CrushingRushdown.DrillImpact`, `Utils.Mechamaru.Dust`. Presets HeavyHit/SnapOh/Snap. ArmFlash color RGB(129,168,203). |
| 4 | .../Nanami/NanamiController | ModuleScript | 473 | NanamiController | NanamiService; ctrl: HitboxController, FXController | none | Hit(att,vic,idx,dir,_), BlackFlashHit, ChaseHit, Chase, Ultimate, Swing, Swing2(char,idx,dir), Launch(char,yVel), EyeFlash, Chat, SpawnRatio(player,char,billboard,boolValue,duration,serverStart), DestroyRatio(player,char,billboard,success), Dismember | No | Character controller. M1 sound picks `Sounds.Gojo.M1.HitN` when `char:GetAttribute("InUlt")` (awakened uses fists) else `Sounds.Nanami.M1.HitN` / `.Up`; dir strings "Down","Up","Air"; idx 1–4. Swing2: cleaver trail from `SetAssets.NanamiCleaver.Blade` when not InUlt; ArmFlash on Right Arm/Leg when InUlt. **Ratio mechanic**: `SpawnRatio` shows a BillboardGui bar whose cursor moves by `(GetServerTimeNow()-start)/duration`; `boolValue.Value` true = success; `boolValue:GetAttribute("CurrentTiming")`. `DestroyRatio` splits bar (`Utils.Nanami.SplitRatio`, `RatioBreak`), BlackFlashCC screen flash if `_G.Settings.Flash`. `Utils.Nanami.Dialogue` (Text1/Chat1/Chat2) on Ultimate chat. `Utils.Itadori.{PerfectHit,EyeTrails}`, `Utils.ChaseHit`. Sounds `Nanami.{BlackFlash,Ultimate,EyeFlash,Dismember,Ratio.{Appear,Success,Break,Disappear}}`. |
| 5 | .../Nanami/Base/SeveranceKickController | ModuleScript | 196 | SeveranceKickController | SeveranceKickService; ctrl: FXController | none | Swing(char,isBack), Whoosh(char,isBack), Hit(att,vic,isBack,isStun,dirVec), ThrowableWind, ThrowableHit | No | Front/back kick with two-stage hit (0.2/0.35s delayed second burst). `Utils.Nanami.SeveranceHit` (Beams, Hit.Sparks/Wind2, Back1/2). Pauses `HRP.WhooshBack/WhooshFront` sound during hit. Throwable variant reuses `Sounds.Yuta.{PunchSwing,MetalHit}`, `Sounds.Hakari.Impact`. Sounds `Nanami.SeveranceKick.{WhooshBack,WhooshFront,HitBack,HitFront,HitBackStun}`, `Nanami.CrossCut.Hit2`. Flash color (0.33,0.67,1). |
| 6 | .../Nanami/Awake/SharpenController | ModuleScript | 283 | SharpenController | SharpenService; ctrl: FXController, ToolController | none | Hit(victim,isFinisher), Slash2, CleaverSlam, CleaverTrail, Slash(char,_), RatioBar(char,barModel), RatioBreak(player,barModel) | No | Awakening cleaver slash w/ ratio bar physically welded (`barModel.SharpenRatio.Weld`, `.Front/.Back` SurfaceGuis with Bar/Cursor/FakeBar1/2, `barModel.Shock`). SraikoVFX Emit/EmitMesh with `Utils.Nanami.Sharpen.VFX.{DustLand,SlashR,Slash,MovingTrail}`, `Utils.Nanami.Sharpen.SharpenAir.{SlashEmit,SlashBeam}`. Finisher: FX:Bleed + BlackFlashCC white flash (`_G.Settings.Flash`). Sounds `Nanami.Sharpen.{JumpSlash,Slash,JumpWindup,RatioHit}`, `Itadori.{CraniumSmash.Hit2,Dismantle.Explode}`, `Todo.BruteForce.Hit`. |
| 7 | .../Nanami/Base/StabilizeController | ModuleScript | 127 | StabilizeController | StabilizeService; ctrl: HitboxController, FXController | none | Start, Whoosh, Hit(att,vic,isRatio), Spin(char,tracker,isLong) | No | Spin attack. `Utils.Nanami.HitFX` scaled 1.5, `Utils.Choso.CounterSwing`. Ratio hit → blood + slow particles. Sounds `Nanami.Stabilize.{Start,Spin,SpinShort}`, `Nanami.CrossCut.{RatioHit,Hit2}`. Unused RaycastParams incl `workspace.Map, workspace.Domains`. |
| 8 | .../Naoya/Awake/FlashFreezingController | ModuleScript | 108 | FlashFreezingController | FlashFreezingService; ctrl: FXController | none | Frame(char), Explode(pos) | No | Awakening "frame" glass: Torso transparency tween, `Utils.Naoya.NaoyaGlass` shatter (Flash/Wind/WindCircle/Shockwave/Shatter emitters), `Utils.Gojo.Shard` debris if `_G.Settings.DesPHY` (CollisionGroup "Effects"). Sounds `Naoya.{Frame,FrameBreak}`. |
| 9 | .../Naoya/Awake/TendrilGrabController | ModuleScript | 193 | TendrilGrabController | TendrilGrabService; ctrl: FXController | none | Preview(char,_), Grab(cframe,victim,tracker) | No | Ground AoE preview: `Utils.Mahito.WideSPStrike.HitArea` recolored red, 50x50 studs, grows over 0.5s (follows caster via `_G.MapParams` raycast). Grab: `Utils.Naoya.GrabModel` parts welded to victim limbs via attrs `AttachPart`, `Attach0`, `Attach`, `OldSize`; shards `Utils.Hiromi.GavelShard` on release (DesPHY). Sounds `Naoya.TendrilGrab.{Start,Preview,Retrieve,Grab,GrabEnd}`. |
| 10 | .../Naoya/Awake/TopSpeedController | ModuleScript | 266 | TopSpeedController | TopSpeedService; ctrl: FXController | none | Start, Fly(char,bodyPosPart), Hit(att,vic,_), Pass(cframe), Track(targetChar?,speedPart) | No | Awakening flight: local player BodyGyro+PlatformStand, target point = HRP + camLook*clamp(25*Speed*0.8,25,75); FOV = 70+30*(Speed-1). `speedPart:GetAttribute("Speed")`; ≥3 triggers sonic boom (`Utils.Megumi.Mahoraga.WorldSlash.mesh`). `Utils.Naoya.{Air,FlyWind,Pass}`. Track: camera auto-aims at nearest `workspace.Characters` child named **"FrameNPC"** within 50 studs (Naoya's frame clone). Sounds `Naoya.TopSpeed.{Startup,Fly,SonicBoom}`, `Naoya.Pass`, `Hakari.EnergySurge.Hit1`. |
| 11 | .../Naoya/Base/BleedoutController | ModuleScript | 204 | BleedoutController | BleedoutService; ctrl: FXController | none | Startup, Stab, Hit(player,vic,isBleed), Hit2, Hit2Freeze, Throw, FinishingStab, Afterimages(char,victim), Flash | No | Stab combo w/ bleed. Afterimages: FOV 60 + ColorCorrection tint RGB(135,167,255), 7x `Utils.Damage.HitGlow` clones colored RGB(128,126,255). `Utils.Naoya.BleedFreeze.Attachment` (Gore). Sounds `Naoya.Bleedout.{Startup,Hit,Throw,FinisherStab,Afterimages}`, `Misc.Bleed`. |
| 12 | .../Naoya/Base/CursoryImpactController | ModuleScript | 272 | CursoryImpactController | CursoryImpactService; ctrl: FXController | none | Startup, Hit(player,vic), UhOh, Grab, Hit2, Throw, Zwoosh(char,_), Swing, Swing2 | No | Punch→kick→grab→throw string. Zwoosh = teleport flicker (char parts transparency 1 for 0.25s, `Utils.Naoya.Teleport`). `Utils.Naoya.RoughSwing` beam swings. Sounds `Naoya.Cursory.{Swing,Hit,Kick,Grab,KickHit}`, `Naoya.Decisive.{Startup,Flicker2}`, `Gojo.LapseBlue.Grab`, `Todo.BruteForce.Swing`. |
| 13 | .../Naoya/Base/DecisiveStrikeController | ModuleScript | 483 | DecisiveStrikeController | **DecisiveStrikeService AND DecisiveStrike2Service** (both Effects wired to same table); ctrl: FXController, HandicapController | none | Weave, Flick(char,boost,level), ClearForce(char→Handicap:ClearForce HRP+Torso), FlickBar(char,intValue), Ding, Windup, Hit1, Hit2, Hit, Hit3 | No | Two variants of same move share controller. Flick: afterimage teleport w/ boost scaled by `level` (1–3). FlickBar: `Utils.Yuta.Outburst.ChargeMeter` w/ `Bars` children named by `intValue.Value`, gradient `Utils.Naoya.Projection.Bar.Bar.UIGradient`. Windup ArmFlash cancelled when `char.Info` gets child **`NaoyaFrame`**. Hit/Hit3: `Utils.Naoya.Barrage` (Arm1/Arm2 fist afterimages), preset LightLoop. Sounds `Naoya.Decisive.{Startup,Flicker1-3,Boost,Ding,Swing,Swing2,FirstHit,SecondHit,Hit1-4}`. |
| 14 | .../Naoya/Base/ProjectionBreakerController | ModuleScript | 137 | ProjectionBreakerController | ProjectionBreakerService; ctrl: FXController | none | Weave, Spin, Kick, Hit(player,vic,silent) | No | Dodge-weave + spin kick. `Utils.Mechamaru.BoostOnVFX.BoostHit.{Meshes.Mesh (Offset Value), Emit.Strike}` via SraikoVFX.HandleMesh. Sounds `Itadori.ManjiKick.Dodge`, `Misc.M.Swing["1"]`, `Naoya.ProjectionBreaker.{Spin,Kick}`, `Mechamaru.BoostOn.Hit`, `Itadori.CursedStrikes.Hit`. |
| 15 | .../Naoya/NaoyaController | ModuleScript | 859 | NaoyaController | NaoyaService; ctrl: HitboxController, FXController | none | Hit(char,idx), Chase, Swing, Swing2(char,idx,_,flag), Swing3(char,idx,dir), Launch(char,yVel), Frame(char,frameClone), Zwoosh(char,_,color?), Trail(char,from,to), Blink(char,toPos), Parry(char,victim), Lost(char,victim,didFall), Grip(char,victim), Form(char), Spin(char,tracker), SpinStart, Velocity(char,tracker) | No | Character controller. M1 sounds `Gojo.M1.HitN`, suppressed when `char.Info.NaoyaFrame` exists. **Frame** (Projection Sorcery 24fps): `Utils.Naoya.NaoyaGlass` follows Torso; two `Utils.Naoya.NaoyaGlassUI` BillboardGuis w/ ViewportFrame char clone (strips Scripts, `Stunna`, `ChargeMeter`); char hidden until `frameClone` leaves `workspace.Characters`; shatter + `Utils.Gojo.Shard` (DesPHY). **Blink**: FX:DomainMapFade black. **Parry** (ultimate counter): `Utils.Misc.C.M1.Hit1`, fades `HRP.Startup` sound. **Lost**: fall (`Utils.Naoya.Fall`) or catch + `Utils.Naoya.Dialogue`. **Form** (ultimate transform): `Utils.Naoya.Form` sphere colored from body parts, `Utils.Misc.M.WingFly`, `Utils.Mahito.Worms.Morph2`. **Spin**: `Utils.Naoya.HitArea` follows HRP, clones `char.Curse` model as purple afterimage every 0.1s. **Velocity**: `Utils.Yuki.Buildup` meter from `Humanoid:GetAttribute("Speed")` (range 2–4). Sounds `Naoya.{Frame,FrameBreak,Acceleration,Frames}`, `Naoya.Ultimate.{Parry,Fall,Catch,Grab,Grab2,Form}`, `Naoya.Decisive.{Startup,Flicker2}`. Theme color RGB(128,126,255). |
| 16 | .../Reggie/Awake/ArsonController | ModuleScript | 108 | ArsonController | ArsonService; ctrl: HitboxController, FXController | none | GasolineBurst(_,part), Explosion(_,part), Gas(_,victim,tracker), Burn(_,victim,tracker), BurnTick(victim) | No | Gasoline DoT: `Utils.Reggie.{Gas_Burst,Gas_Ignite,Gas,Burn_Asset}` welded to Torso, removed on tracker `Destroying`. BurnTick flashes RGB(255,113,12). Sound `Kurourushi.InsectTrance.BugExplode`. |
| 17 | .../Reggie/Awake/BigMovesController | ModuleScript | 93 | BigMovesController | BigMovesService; ctrl: HitboxController, FXController | none | Hit(att,vic), Shake(truckPart) | No | Truck summon: `truckPart.Parent.Truck.Main`, `Utils.Reggie.TruckWind` (Wind1/2 enabled while `Speed` attr >40), HeavyHit shake within 60 studs. Sounds `Reggie.{TruckHit,TruckHorn}`. |
| 18 | .../Reggie/Base/BluntTraumaController | ModuleScript | 183 | BluntTraumaController | BluntTraumaService; ctrl: HitboxController, FXController | none | Start, Slash(char,idx 1–5), Break(part), Hit(att,vic,idx,_), Align(att,vic,bodyPosPart), Dizzy(att,vic,tracker) | No | 5-hit bat/object combo; hit 5 uses `Utils.Ryu.Slash` arc. Break: 9x `Utils.Hiromi.GavelShard` from part. Align: local attacker's BodyPosition tracks victim until `vic:GetAttribute("Ragdoll")==0`. Dizzy: `Utils.Damage.Dizzy` on victim head. Sounds `Reggie.BluntTrauma.{Start,Whoosh1-5,Break1-2,Hit1-5,Jump}`. Presets SnapOh(5)/Snap(4)/HeavyHit. |
| 19 | .../Reggie/Base/DroneStrikeController | ModuleScript | 160 | DroneStrikeController | DroneStrikeService; ctrl: HitboxController, FXController | **`remote:FireServer(moveVector)`** every frame in `Aim` (ControlModule:GetMoveVector) | Start, DroneStart, Press, DroneLoop(drone→`drone.Rootpart`), Aim(char,valueObj,remote), Break(part), Explode(char,pos,big), Interp(part) | No (steering input only) | Drone: client streams WASD move vector to server while `valueObj:GetAttribute("Fired")` false; crosshair `Utils.Reggie.Crosshair` at `HRP.CFrame * valueObj:GetAttribute("Aim")` raycast-clamped. Interp: client-side dead-reckoning `BulkMoveTo` using part `Speed` attr. `Utils.Reggie.BikeExplode`. Sounds `Reggie.DroneStrike.{Whoosh,DroneStart,Press,Loop,Explode}`. |
| 20 | .../Reggie/Base/FlecheController | ModuleScript | 194 | FlecheController | FlecheService; ctrl: HitboxController, FXController | none | Hit, Hit2, Dash, Pull(att,vic), Drop(weaponModel), Open(char,weaponModel) | No | Umbrella/blade lunge: `weaponModel.Open/.Closed` transparency toggle; Drop clones weapon into world (CollisionGroup "NoPlayerCollision"). Sounds `Reggie.Fleche.{Hit,HitOpen,Dash,PullOut,Unleash,UnleashWhoosh}`. |
| 21 | .../Reggie/Base/GarageSaleController | ModuleScript | 159 | GarageSaleController | GarageSaleService; ctrl: HitboxController, FXController | none | Start, Interp(char,projectile), Break(part), Hit(att,vic,heavy,_) | No | Throws random furniture (`Fridge` special-cased, bigger VFX + `Metal1/2` sounds). Burn VFX from `char.ReceiptStack`. Client dead-reckons projectile via `Speed` attr. Random sound from `Sounds.Reggie.GarageSale` folder. Sounds `Reggie.{GarageSaleFire,CouponBurn,Metal1,Metal2}`. |
| 22 | .../Reggie/Base/GushingWoundController | ModuleScript | 116 | GushingWoundController | GushingWoundService; ctrl: HitboxController, FXController | none | Start(char,knifeModel,_), Hit(att,vic,quiet), Interp(knife,quiet) | No | Knife throw(s): `Utils.Reggie.ReceiptBurn` on each knife part; projectile moves along **-RightVector** * `Speed`. Blood via BloodyZee. Sounds `Reggie.{KnifeHit,KnifeThrow,CouponBurn}`. |
| 23 | .../Reggie/Base/HomerunController | ModuleScript | 189 | HomerunController | HomerunService; ctrl: HitboxController, FXController | none | Start, Interp(char,ball), HitBall, Hit(att,vic,isHomerun), Hit2, CollidedBall(ball,reverse) | No | Bat + ball: ball lives in `workspace.Bullets`, dead-reckoned by `Speed`; `Boosted` attr change spawns `Utils.Reggie.Boost`. Hit has 0.15s time-stop then followup. Sounds `Reggie.Homerun.{Start,BallLaunch1,BallLaunch2,BallFire,Hit,Hit2,Hit2Homerun,Followup,BallHit}`. |
| 24 | .../Reggie/Awake/MayhemController | ModuleScript | 131 | MayhemController | MayhemService; ctrl: HitboxController, FXController | none | Start, Explosion(char,pos), Interp(projectile,glow), Land(receiptPart,noBurn), Heal(char) | No | Receipt bombs: `Utils.Reggie.{Explosion,ReceiptGlow,ReceiptBurn,SpotlightQuick}`, `receiptPart.CE_Infuse` emitters. Heal VFX+`Sounds.Reggie.Heal`. Sounds `Reggie.{MayhemStart,CouponBurn2}`, `Reggie.Littering.Land`, `Reggie.DroneStrike.Explode`. |
| 25 | .../Reggie/Base/PianoDropController | ModuleScript | 181 | PianoDropController | PianoDropService; ctrl: HitboxController, FXController, ToolController | none directly; exposes **`ToolDeactivate()` → returns `ToolController:GetMouseTarget(75)`** (ToolController presumably sends to server) | Hitbox(boolValue,big), Spawn(_,pianoModel), Smash(pos,big) | Indirect: client-supplied mouse target = drop location | Ground-target AoE: `Utils.Megumi.HitArea` 15x15 (+30x30 red if `big`) follows mouse raycast (`_G.MapParams`) until `boolValue.Value`. Piano `Root` follows with `Utils.Reggie.PianoDrop.{Wind1,Wind2,Stage2}` when `Speed`>1 until `Dropped` attr. Smash: `Utils.Megumi.{Smash,Mahoraga.Earthquake,Mahoraga.WorldSlash.mesh}`. Sounds `Reggie.{PianoFall,PianoBreak}`. |
| 26 | .../Reggie/Base/PoleVaultController | ModuleScript | 142 | PoleVaultController | PoleVaultService; ctrl: HitboxController, FXController | none | Hit, Drop(poleModel), Slam, Launch | No | Pole vault leap. `Utils.Hiromi.Shockwave`, `Utils.Choso.CounterSwing.Shock`. Sounds `Nanami.CrossCut.Hit1`, `Haruta.BackstabFinisher.Slam`, `Reggie.BluntTrauma.Whoosh5`. |
| 27 | .../Reggie/ReggieController | ModuleScript | 383 | ReggieController | ReggieService; ctrl: HitboxController, FXController | none | Hit(vic,idx), ChaseHit, Chase, Swing, Swing2(char,idx,dir), Launch(char,yVel), MoveSwap(char,itemInst,noSlotFlash), Discard(char,tracker), GoldSeal(char,tracker), DiscardWhoosh, Burn(char,receiptModel,cframe), Spa(char,_), Sweep, Ultimate, Chat, CouponStart, LitteringStart, LitteringLand(part), LitteringActivate(part), Ball(spawnerPart,quiet), BallHit, RainbowSealExplode | No | Character controller. M1 uses `Gojo.M1.HitN`; ArmFlash white per idx/dir (Down→Right Leg, Up→Right Arm, 1 L Arm, 2 R Arm, 3–4 L Leg). **MoveSwap**: flashes `PlayerGui.Main.Controls.Moveset.ReggieSlot` and the Frame whose `ItemName.Text == item.Name` — Reggie's slot rotates items. Discard/GoldSeal: `Utils.Reggie.Highlight` (gold RGB(255,217,102)) on self. Littering balls: `Utils.Reggie.Ball` physics parts, size halved if spawner has `Delay` attr. `Utils.Reggie.{Spotlight,SweepStars,Dialogue,BikeExplode,ReceiptBurn}`. Sounds `Reggie.{Discard,CouponBurn,CouponBurn2,CouponWhoosh,Ultimate}`, `Reggie.Littering.{Start,Land,BallSpawn,BallHit}`, `Reggie.DroneStrike.Explode`. |
| 28 | .../Reggie/Base/SpeedCrashController | ModuleScript | 177 | SpeedCrashController | SpeedCrashService; ctrl: HitboxController, FXController | none | Throw(char,bikePart), Start, Drive(char,boost), Explode(char,bikePart,pos,big), Hit, Hit2, Slide(char,long) | No | Motorbike dash: bike shards (`Utils.Hiromi.GavelShard`), `Utils.Reggie.BikeExplode` scaled 1.5 if big, two offset DustTrails. Sounds `Reggie.SpeedCrash.{Start,Drive,DriveBoost,Explode,Hit,Slide}`. |
| 29 | .../Ryu/Awake/HadNoIdeaController | ModuleScript | 160 | HadNoIdeaController | HadNoIdeaService; ctrl: FXController | none | Startup, Swing, Ow(victim), StartHit(att,vic,tracker), Hit, FinalHit | No | Awakening grab-beatdown. `Sounds.Ryu.HadNoIdea.Hit` volume-faded if tracker removed before 1.3s. DrillImpact recolored RGB(170,255,255) (Ryu theme). Sounds `Ryu.HadNoIdea.{Startup,Hit}`, `Ryu.Unsatisfied.Weave`, `Ryu.Dessert.Hit`, `Naoya.Decisive.SecondHit`, `Hakari.EnergySurge.Hit1`. |
| 30 | .../Ryu/Awake/WerentInvitedController | ModuleScript | 242 | WerentInvitedController | WerentInvitedService; ctrl: FXController (+ `Knit.GetController("MokouController"):ArcTween` at runtime) | none | Startup, Charge, Charged, Dash(char,_,power), Swing, Interp(projectile), Crunch(char,projectile,rockDataArray,offset), Hit(att,vic,cframe), PunchWall(char,cframe) | No | Chargeable dash-punch that carries a rock mass: Interp dead-reckons at fixed **120 studs/s**; `Crunch` builds `Rocks` parts from server array `{pos,orient,color,material,size,transparency}` welded to projectile; on Destroying spawns `Utils.Megumi.Mahoraga.Rock` + up to 25 falling rocks (CollisionGroup "Effects"). Charged flash cyan RGB(0,255,255). BlackFlashCC strobe if `_G.Settings.Flash`. VFX `Utils.Ryu.{Launch,Doosh}`, `Utils.Misc.M.Awk.mokultMeh["3"]` arcs via MokouController:ArcTween. Sounds `Ryu.NotInvited.{Windup,ChargeStart,FullCharge,PowerDash,Dash,Swing,Hit}`. |
| 31 | .../Ryu/Awake/WhatAreYouAfterController | ModuleScript | 175 | WhatAreYouAfterController | WhatAreYouAfterService; ctrl: FXController, ToolController (+MokouController) | none | Startup, Aerial(char,bodyPosPart), Crush(pos), Dash, Hit(att,vic), Hit2 | No | Aerial: local BodyGyro aims at `bodyPosPart:GetAttribute("Aim")` or mouse target (`ToolController:GetMouseTarget()`), hovers +18 studs, PlatformStand. Crush: `Utils.Megumi.Mahoraga.Earthquake`, DustBreak radius 12/35. Hit flashes both chars + double blood. Sounds `Hakari.FeverBreak.CrushSwing`, `Hakari.OverLuck.Dash`, `Mechamaru.AbsoluteDestruction.Slam`, `Nanami.Interrogate.Hit`, `Nanami.Dismember`, `Naoya.Decisive.FirstHit`, `Ryu.Dessert.Hit`. |
| 32 | .../Ryu/Base/AppetizerController | ModuleScript | 114 | AppetizerController | AppetizerService; ctrl: FXController, ToolController | none | Startup(no-op), Fire(char,_), Fire2(char,hard), Interp(projectile) | No | Granite beam from Head (`Utils.Ryu.GraniteBeam` 12x12x60, white 6x6 if hard), projectile at **180 studs/s**, muzzle `Utils.Todo.Clap` RGB(128,187,219). Sounds `Ryu.GraniteBlast.{Fire,FireHard}`. |
| 33 | .../Ryu/Base/GraniteBlastController | ModuleScript | 192 | GraniteBlastController | GraniteBlastService; ctrl: FXController, ToolController (+MokouController) | none | Startup(char,tracker), Warn, Fire(char,_), FireHard(char,cframe), Hit(victim), Interp(projectile), Aerial(char,bodyPosPart), Finisher(victim→FX:Burn) | No | Charged blast: `Utils.Ryu.{Charge,ChargeWarn,GraniteBeam,Launch}`; Aerial hover w/ mouse aim unless BodyGyro attr `Lock`; projectile 180 studs/s. Sounds `Ryu.GraniteBlast.{Charge,Fire,FireHard,Hit}`. |
| 34 | .../Ryu/Base/SecondHelpingController | ModuleScript | 180 | SecondHelpingController | SecondHelpingService; ctrl: FXController, ToolController (+MokouController) | none | Startup(char,targetPos), Swing, Crush(pos), Hit(victim), HitPact(att,vic) | No | Leap-slam toward target: `Utils.Ryu.{Doosh,Slash}`, `Utils.Hiromi.Shockwave`, DustBreak. Sounds `Ryu.SecondHelping.{Startup,Hit,AirHit,AirHit2}`, `Megumi.Mahoraga.Throw.Break`, `Hakari.Impact`. |
| 35 | .../Ryu/Base/UnsatisfiedController | ModuleScript | 207 | UnsatisfiedController | UnsatisfiedService; ctrl: FXController (+MokouController) | none | Startup, Dash(char,cframe), Dash2, Hit(victim,idx), Hit2(victim), HitEnd(att,vic) | No | Rushdown combo; Hit2 draws 7 LightningBeams from `HRP.RootAttachment` (color purple, or pink/blue if `victim:GetAttribute("Moveset")=="Yuta"`). Requires `Modules.StaticLightning`, `Modules.LightningBeams`. Sounds `Ryu.Unsatisfied.{Weave,Dash,Hit1..N,FinalHit1,FinalHit2}`. |

#### Cross-cutting identifiers seen in this slice
- **Attributes**: char `InUlt` (Nanami awakening), `Moveset` (value "Yuta" checked), `Ragdoll` (0 = ended), `Speed` (on projectiles/parts, tools, and `Humanoid` for Naoya), `Fired`, `Aim` (CFrame, on ValueBase/BodyPosition), `Boosted`, `Dropped`, `Delay`, `Lock` (BodyGyro), `CurrentTiming` (BoolValue), `EmitCount` (every ParticleEmitter), `OldSize`/`AttachPart`/`Attach0`/`Attach` (Naoya GrabModel), `Offset` (ObjectValue on mesh).
- **Info folder children**: `Info.NaoyaFrame` (presence = Naoya frame active). No `Info.Knockback/Stunned` in this slice.
- **Character children/names**: `SetAssets.NanamiCleaver.Blade`, `Curse` (Naoya spin afterimage source), `Stunna`, `ChargeMeter`, `ReceiptStack`, `MainReceipt`, `Rocks`, `Ring`, `CE_Infuse`, `Rootpart`, `Truck.Main`, `Fridge`, `Open`/`Closed`, `HRP.CollapseBG`, `HRP.Startup` (sound), `HRP.WhooshBack/WhooshFront` (sounds), `Head.HiromiText`, `RatioVisual`, `SharpenRatio`, character named **`FrameNPC`** in `workspace.Characters`.
- **Workspace folders**: `workspace.Effects`, `workspace.Map`, `workspace.Domains`, `workspace.Characters`, `workspace.Bullets`. CollisionGroups: `Effects`, `NoPlayerCollision`.
- **`_G`**: `_G.Settings.Gore`, `_G.Settings.Flash`, `_G.Settings.DesPHY`, `_G.MapParams`.
- **GUI**: `PlayerGui.Main.Controls.Moveset` (+ `ReggieSlot`, per-slot `ItemName` TextLabel), `PlayerGui` BillboardGuis (NaoyaGlassUI).
- **FXController API used**: `Flash(char,color,dur?)`, `ArmFlash(limb,color,dur)`, `PlaySound(sound,parent,group)`, `PlayParticles(inst)`, `Bleed(char)`, `Burn(char)`, `DustBreak(pos,normal,a,b,c,d)`, `DustTrail(char,dur,offsetCF)`, `DomainMapFade(color,a,b)`, `FX.Voxels[idx] = {part, bool}`. `ToolController:GetMouseTarget(range?)`. `HandicapController:ClearForce(part)`. `MokouController:ArcTween(startPart, bool)`.
- **CameraShaker presets**: LightHit, MediumHit, HeavyHit, Snap, SnapOh, LightLoop; `ShakeSustain(...):StartFadeOut(t)`.
- **SoundGroups**: `SoundService.Effect`, `SoundService.Voice`.

### A.5 Movesets: Todo, Uro, Yuki, Yuta (33)

| # | Path (from header) | Type | Lines | Knit name | Services used | Client→server calls | Server→client signals handled (Effects keys) | Client-auth hit report? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Moveset/Todo/Awake/BrothersController | ModuleScript | 216 | BrothersController | BrothersService; ctrls Hitbox, FX | none | `Clap`(char); `Swap`(char, BoolValue) — hides char parts, spawns `Utils.Todo.Yuji` dummy (CollisionGroup "Effects") playing `Animations.Todo.Brothers` from TimePosition 2.4, follows HRP until BoolValue.Value==true, then restores; shrinks `workspace.Effects.FollowTakada` to 0.01 for 1.34s; `BlackFlash`(attacker, target) — FlashBurn on target parts, BlackFlashLaunch, red `LightningBeams` (PulseSpeed 1000, MaxRadius 20) parented to `workspace.Effects.Bolt`, Snap shake, BlackFlashCC if `_G.Settings.Flash` | No | Sounds: Todo.Clap, Itadori.ManjiKick.Startup, Itadori.DivergentFist.BlackFlashHit/Voice. Modules: CameraShaker, LightningBeams |
| 2 | Moveset/Todo/Awake/ClimaxJumpController | ModuleScript | 361 | ClimaxJumpController | ClimaxJumpService; Hitbox, FX | none | `Grab`(attacker, target) — DrillImpact white + Snap; if local==attacker and `attacker:GetAttribute("InUlt")` → full-screen cutscene GUI `Utils.Todo.Jump.Flash` (ViewportFrame w/ Camera), two `Utils.DomainWarn.Panel.Viewport.Display` dummies outfitted via `FX:ApplyCopyOutfit` + `Utils.Todo.Awakening.Takada`, camera driven by `Utils.Todo.Jump.CameraData.Frames/FOV` (60 fps indexed CFrameValues; hijacks workspace camera for frames <79), `Utils.Todo.Jump.Stage` at (2000,0,0) w/ Bloom in Lighting, `EndSpotlight`, Exposure -6→0, FollowTakada attr `A`=CFrame(-6,0,0) + `Animations.Todo.TakadaJoint.JumpEnd`; `Hit`,`Hit2`,`Hit3`(player/char, target); `Burst`(char) FollowTakada attr `A`=CFrame(4,0,0) + `TakadaJoint.JumpStart`; `Dash`(char) BlackFlashLaunch + 10× `Utils.Mahito.BodyRepel.Wind1-5` | No | Sounds: Hakari.EnergySurge.Hit1/Hit2, Gojo.M1.Hit1-4, Itadori.CursedStrikes.Startup, Itadori.Rush.RushLaunch, Todo.Jump.Bell. `_G.Settings.Flash` gates Flashes emitters + CC. Attr: InUlt, A |
| 3 | Moveset/Todo/Awake/DreamsController | ModuleScript | 179 | DreamsController | DreamsService; Hitbox, FX | none | `Start`(char) black flash 0.5 + FollowTakada `Animations.Todo.TakadaJoint.Emote` at speed 3 for 1.4s; `Hit`,`Hit2`(player, target) — local attacker sees `Utils.Todo.HeavyHit` (Hearts emitter), others DrillImpact; `Swing`(char, idx 1-4) — `Utils.Hakari.Barrage.ColorArm` pink (255,170,255) + LapseBlue.Throw; idx 3 adds BlackFlashLaunch | No | Sounds: Hakari.EnergySurge.Hit1/Hit2/Swing |
| 4 | Moveset/Todo/Awake/IdolDebutController | ModuleScript | 259 | IdolDebutController | IdolDebutService; Hitbox, FX | none | `Swing`(char) FollowTakada `Animations.Todo.IdolDebut` 0.7s; `Swing2`(char) `Utils.Hakari.RoughSwing` beam; `Jump`(part, BodyPosition) — local char: tween BP.P→100000 and pin BP to part; **non-local chars: client lerps their HRP.CFrame toward part (0.15)**; `JumpBurst`(pos, char) `Utils.Itadori.CrushingBlow`; `Hit`(attacker, target) HeavyHit + if local attacker InUlt → cutscene `Utils.Todo.Debut.Flash` + `Debut.CameraData`, Exposure 2→0; `Hit2` | No | Sounds: Hakari.EnergySurge.Swag/Hit1, Mahito.DrillSplit.Leap, Hakari.Counter.Startup, Megumi.Mahoraga.Throw.Break, Itadori.CrushingBlow.GroundImpact, Todo.Debut.Jump/Jump2, Itadori.CraniumSmash.Hit2, Todo.BruteForce.Hit. Attr: InUlt |
| 5 | Moveset/Todo/Base/BruteForceController | ModuleScript | 182 | BruteForceController | BruteForceService; Hitbox, FX | none | `Swing`; `UhOH`(char) Todo.Woosh in Music group; `Woosh`(char, isBlackFlash) BlackFlashLaunch + Choso.CounterSwing.Shock; `Hit`(player,target); `BlackFlashHit`(attacker, target, isWapam) — `Utils.Todo.BlackFlashHit`, red flash 2s, if isWapam: Todo.Wapam (Music) + `FX:Bleed(target)` + Todo.WapamVoice (Voice), Exposure 2→0; CC gated by Flash | No | Sounds: Todo.BruteForce.Start/Swing/Hit, Mahito.BlackFlash, Mahito.Stockpile.Swing2, Itadori.DivergentFist.BlackFlash, Itadori.CraniumSmash.Hit2 |
| 6 | Moveset/Todo/Base/PebbleThrowController | ModuleScript | 101 | PebbleThrowController | PebbleThrowService; Hitbox, FX | none | `Interp`(char, projectile) — client-side extrapolation: BulkMoveTo along LookVector at **130 studs/s** from last replicated Position, stops when Anchored==false or attr `STOP`; `Stomp`(char, pos) DustBreak; `Hit`(target) flash (0.33,0.67,1) | No | Sounds: Megumi.Mahoraga.Throw.Throw/Break, Mahito.WideSPStrike.Crush, Itadori.DivergentFist.DivergentHit |
| 7 | Moveset/Todo/Base/SwiftKickController | ModuleScript | 260 | SwiftKickController | SwiftKickService; Hitbox, **ToolController**, FX | `remote:FireServer(buffer[6])` inside `UpdateCamera` — every Heartbeat sends camera LookVector X/Y/Z as 3× float16 (custom `writeFloat16`) until remote is unparented | `Start`; `Swing` (`Utils.Todo.Swing` beam weld); `Dash`(char, BodyVelocity, boosted) — local client drives BV.Velocity = look × NumberValue(165 if boosted else 150 → 35, 0.5s Exponential); `Hit`; `Grab`; `UpdateCamera`(remote); `Aim`(char, part) BodyGyro P 10000 to camera look, PlatformStand, `ToolController:GetMouseTarget(nil,true)`, part.Position = HRP+2y until part gone; `Throw`(attacker, target) Choso.CounterSwing + 4× Itadori.Shock along target velocity | No (aim/camera stream only) | Sounds: Hakari.FeverBreak.Dash, Hakari.Counter.Startup, Choso.PiercingBlood.Startup, Itadori.Rush.Rush, Itadori.CraniumSmash.Hit2, Gojo.LapseBlue.Grab, Mahito.CrushingRushdown.Leap, Mahito.Stockpile.Swing2 |
| 8 | Moveset/Todo/TodoController | ModuleScript | 556 | TodoController | TodoService; Hitbox, FX | none | `Hit`(target, idx) Sounds.Todo.M1.Hit<idx>; `ChaseHit`; `Chase`; `Swing`; `Swing2`(char, idx, dir) ArmFlash (0,170,255): "Down"→Right Leg 0.4, idx 2/4→Right Arm, else Left Arm; `Swap`(charA, charB, cfA, cfB, skip) — Boogie Woogie: 2× `Utils.Todo.Clap`; abort if charB attr `Ragdoll`>0, skip==true, or `not _G.Shift`; **local client sets its own HRP.CFrame to cfA/cfB and preserves camera offset**; `Swap2`(char, model); `Fakeout`(char, pos?); `Perfect`(char) cyan highlight (85,255,255 / 170,255,255) + Todo.Perfect; `Woosh` (`Utils.Todo.Woosh`); `GrabHit`(player, target, idx 1-3); `Launch`(char, y); `BlueGrab2`(model) Itadori.CounterHit.Feint recolored (85,170,255); `Chat`(char) — **awakening cutscene** (see §2); `Applause`(char) Clap + white highlight + Todo.OST (Music) + Todo.Voice (Voice) + `Animations.Todo.Summon` | No | Attr: Ragdoll (number), InUlt, Stun, A (CFrame on FollowTakada). `_G.Shift`, `_G.Settings.Outfit` (→ `Players:GetHumanoidDescriptionFromOutfitId`), CollisionGroup "NoCollision". Sounds: Todo.M1.Hit1-3, Misc.Chase, Misc.Swing.Fist, Todo.Clap, Todo.Perfect, Hakari.OverLuck.Hit2, Gojo.M1.Hit1-4, Megumi.Mahoraga.Throw.Break, Todo.Awaken.SFX/Music, Todo.OST, Todo.Voice |
| 9 | Moveset/Uro/BlindRageController | ModuleScript | 212 | BlindRageController | BlindRageService; FX only | none | `Fly`(char, part) — ring trail `Utils.Uro.Ring` every 0.1s while part in `workspace.Characters`; **local: BodyGyro to camera, part.Position = HRP + camLook×40 (client steers server target part)**, PlatformStand; `Swing`(char, idx); `Startup`; `Dash` (RushWind scaled 0.6 + 2 Shocks); `Throw`; `Grab`(a,t); `Hit`(t) DrillImpact (170,255,255) | No | Requires StaticLightning/LightningBeams (unused). Sounds: Uro.BlindRage.Fly/Swing1/Swing2/Swing3/Throw, Ryu.NotInvited.Dash, Gojo.LapseBlue.Grab, Ryu.SecondHelping.Hit |
| 10 | Moveset/Uro/SkyDistortionController | ModuleScript | 191 | SkyDistortionController | SkyDistortionService; FX | none | `Startup`; `Interp`(proj) — extrapolate **180 studs/s**; `Utils.Uro.AirDistort2` stretched from spawn point to projectile (width 10→2); on `Destroying`, children of `proj.Rocks` fly back to attr `P1`/`V2` and shrink; `Crunch`(char, proj, rockData[]) — builds rock Parts {pos, orient, color, material, size, transparency} in `proj.Rocks`, attrs `P1`,`P2`, Attachment "BlueGrab" + AlignPosition (Responsiveness 30→200) to `proj.Attachment`; only if camera ≤75 studs; `Hit`(t) | No | Sounds: Uro.SkyDistortion.Swing/Throw, Megumi.Mahoraga.Throw.Break, Ryu.SecondHelping.Hit |
| 11 | Moveset/Uro/ThinIceBreakerController | ModuleScript | 221 | ThinIceBreakerController | ThinIceBreakerService; FX, ToolController | none | `Aerial`(char, part) BodyGyro faces `ToolController:GetMouseTarget()` unless gyro attr `Lock`; `Startup` ArmFlash (170,255,255) R then L; `Crack`(char, t1, t2) — `Utils.Uro.IceBreaker` SmallShard/BigShard: t1==0.5 → Die sound + sustained HeavyHit (kill variant), t1==0.15 → offset variant; then Crack → Explode; `Utils.Ryu.Launch` + (t1==0.5) `Utils.Misc.M.Awk.mokultMeh["3"]` via `Knit.GetController("MokouController"):ArcTween(model.Start, true)`; `_G.Settings.DesPHY` → 20 `Utils.Gojo.Shard` glass shards; `Hit`(t, idx) Ryu.Unsatisfied.Hit<idx>; `HitEnd`(t, other) FinalHit2 + DrillImpact | No | Sounds: Uro.ThinIceBreaker.Start/Die/Impact/Crack/Explode, Ryu.NotInvited.Swing, Ryu.Unsatisfied.Hit*/FinalHit2 |
| 12 | Moveset/Uro/UroController | ModuleScript | 654 | UroController | UroService; Hitbox, FX | `remote:FireServer(hitsTable_or_nil, hrpCFrame)` from `UroService.Hitbox` handler | Effects: `Hit`(target, idx) Gojo.M1.Hit<idx>; `ChaseHit`; `AerialHit`; `Chase`; `Swing`; `Swing2`(char, idx, dir, alt) ArmFlash (85,255,255) incl. Left Leg on 3, both arms on 4 when alt; `Launch`; `Chat`(char) ult intro: `Utils.Uro.Dialogue` "ARE YOU THAT AFRAID?", two AirDistort2 planes from hands (width 12→3), sustained LightHit 0.65s, Break sound, DesPHY shards; `AirDistort`(char, part, width, duration, fade) segmented AirDistort2 trail following part; `Chat2`(char) Voice1/Fly/Voice2; `UhOh`() HeavyHit + Contrast -3→0 CC (Flash); `TIB`(cframe) giant IceBreaker (ScaleTo 8), sustained HeavyHit 1.5s, SnapOh, mokultMeh["2"]+["3"] ArcTween, 25 shards ×8; `SkyGrab`(char) `Utils.Uro.GlassPlane` welded, `Animations.Uro.ThinIceBreaker2Sky`, ScaleTo 1.5→0.6; `Flight`(char) Locust.Flight, 5 Shocks; **local: HRP.Velocity = camLook × (300 if looking down <-0.8 else 100)**. Extra signal **`UroService.Hitbox`**(part, char, remote): loop `HitboxController:SphereHitbox(char, CFrame(0,-1,-3), 10)` every 0.05s, accept first hit whose `Info.Knockback` ~= false, tween part's NumberValue→0, then FireServer | **YES** — client computes hit list (Uro base hitbox / dash?) | Attr/values: `Info.Knockback`. `workspace.Characters`. Sounds: Gojo.M1.Hit*, Itadori.CraniumSmash.Hit2, Misc.Chase, Misc.Swing.Fist, Megumi.Mahoraga.Throw.Break, Uro.Ultimate.Voice/Voice1/Voice2/Grab/Grab2/Break/Fly, Uro.ThinIceBreaker.Impact/Crack/Explode, Locust.Flight |
| 13 | Moveset/Yuki/GarudaReboundController | ModuleScript | 353 | GarudaReboundController | GarudaReboundService; FX | none | `Startup`; `Punch`; `Interp`(proj, speed=160, longTrail) — extrapolate at `speed`; attr `Freeze` pauses (Trail.Lifetime 20); spins `proj.GarudaBall.Weld` 400°/s; `Recall`(char, proj, startPos, dur) — dur==0.1 → straight lerp + Return sound, else sine arc (15 studs) + Bounce sound, destroys proj; `Hit`; `HeavyHit`; `Kick`; `Woosh`; `Impact`(char) — local: FOV 70→50→70, Saturation -0.5, 1/20 chance Yuki.Secret (Voice)+SecretSFX; `Utils.Yuki.KickWarp` on Left Leg, impactframelines; `TrueFinish`(player, target, dirVec) — Yuki.Freeze (Exposure 3 for 0.3s if involved), Explode/Explode2, hides target, 100× `BloodyZee:Blood`, `_G.Settings.Gore` → `Utils.Heian.BloodSpread`; 20× `Utils.Damage.Chunk` (pink 255,85,255 when Gore==false) | No | Modules: BloodyZee. Sounds: Yuki.Rebound.Startup/Punch/Return/Bounce/Hit/Slow, Yuki.Secret/SecretSFX/Freeze/Explode/Explode2, Itadori.CraniumSmash.Hit2, Todo.BruteForce.Hit/Swing, Mahito.Stockpile.Swing2 |
| 14 | Moveset/Yuki/GarudaStabController | ModuleScript | 237 | GarudaStabController | GarudaStabService; FX | none | `Startup`(Yuki.Startup2); `Swing`(Yuki.Stab); `Stab`(target) Hiromi.Stab + 40 blood from Torso; `Trail` `Utils.Yuki.MassChargeLeg` on Right Leg 0.3s; `Hit`(player,target) `Utils.Yuki.MassHit` + `Utils.Gojo.LapseBlue.LapseBlue.Grab` implosion 40→0; `GarudaTrail`(char) `char.SetAssets.Garuda.Garuda["segment finale"].TailHolder` gets `Utils.Yuki.MassCharge` blinking 0.4s ×2; `Whip` (`Utils.Yuta.Veilstep.Spin.SpinRing` size 17.5); `Whip1`/`Whip2`/`FlyBack` sounds; `WhipHit`(_, t); `WhipHitHard`(p, t) | No | Sounds: Yuki.Startup2/Stab/FirstWhip/SecondWhip/WhipFlyBack, Hiromi.Stab, Yuki.Mass.Hit/Hit2, Yuki.RisingRage.Hit/Hit3. SetAssets "Garuda" model |
| 15 | Moveset/Yuki/MassBreakerController | ModuleScript | 142 | MassBreakerController | MassBreakerService; FX, ToolController | none | `Startup`(Yuki.Mass.Start); `Dash` Choso Shock + 4 Shocks, Yuki.Mass.Miss/Dash; `Aerial`(char, part) BodyGyro = part attr `Aim` or face `GetMouseTarget()`, part.Position = HRP+6y; `Hit`(player, target, cframe) MassHit oriented to cframe.LookVector | No | Sounds: Yuki.Mass.Start/Miss/Dash/Hit/Hit2 |
| 16 | Moveset/Yuki/RisingRageController | ModuleScript | 287 | RisingRageController | RisingRageService; FX, ToolController(unused) | none | `Startup`(Yuki.Startup); `Trail` (MassChargeLeg on Left Leg 0.2s); `Hit`(p, t, idx 1-3 → Yuki.Mass.Hit / RisingRage.Hit / RisingRage.Hit2); `Hit2` MassHit implosion; `KneeBuild`(char) RisingRage.Charge + `Utils.Yuki.FullRisingRage` on Right Leg (0.6s build, then Smear/Flare); `Dash` (4 Shocks + Choso Shock + BlackFlashLaunch); `KneeHit`(p,t) RisingRage.Hit3; `HeadHit`(p, t, dirVec) — red flash 5s, 40 blood from Head; **victim** gets SnapOh + 5s LightHit sustain, RisingRage.Ring sound, BlurEffect 64→0 over 5s, red CC sequence (Flash) | No | Sounds: Yuki.Startup/Swing, Yuki.Mass.Hit, Yuki.RisingRage.Hit/Hit2/Hit3/Charge/Ring |
| 17 | Moveset/Yuki/YukiController | ModuleScript | 629 | YukiController | YukiService; Hitbox, FX | none | Effects: `Hit`(target, idx) Gojo.M1.Hit<idx>; `ChaseHit`; `Chase`; `Swing`; `Swing2`(char, idx, dir) ArmFlash (255,85,255); `Launch`; `BlackHole`(part) — `Utils.Yuki.BlackHole2` follows part, grows to 20 over 2.5s then shrinks; Yuki.Hole.Hole; **local char within 100 studs is pulled: AssemblyLinearVelocity += dir × (1-d/100) × (300 air / 2000 grounded) × dt, FOV 120, LightLoop shake, for 3.8s**; `Absorbed`(char) fades parts; `OhNo`(char) Yuki.Scream (Voice) + Rush + Hakari.EnergySurge.Teleport, 10 Shocks; **local: HRP.Velocity = camLook×100 for 0.5s**; `OhNo2`(attacker, target, part) grab: LapseBlue.Grab vol 5, Yuki.Grab, Yuki.GrabOST (Music); `Utils.Hakari.IdleDeath.AudioVis` beat GUI for involved; target sees `Utils.Yuki.Buildup` bar in attacker.Torso driven by attacker attr `Charge`/100; OST fades 6s if Charge≥100 else 1s; `Buildup`(char, hasWarp) — Buildup bar (local), `Utils.Yuki.Warp2` sphere (Highlight 103,88,135 → black; stages at 33%/66%), `Utils.Damage.HitGlow` (170,85,255); loops while attr `Charging`; Yuki.Charge.Start / Finish (Charge≥100) / End; `MeterVis`(char, IntValue) — `Utils.Yuki.Meter` + `MeterBar` ×attr `Max`, `Buildup.Cost` = attr `Cost`/100, sounds Yuki.Charge.Charge / ChargeFail when Value==Max. Extra signal **`YukiService.Debree`**(rockData[], centerPos): if DesPHY & camera ≤200 → debris Parts into `workspace.Effects.CamIgnore`, random velocity 60-100, 10% `FX:DebreeSound`, after 0.2s AlignPosition (OneAttachment, attachment "BlueGrab") to centerPos | No | Attr: Charge (0-100), Charging, Max, Cost (on meter IntValue). `_G.Settings.DesPHY`. Sounds: Gojo.M1.Hit*, Misc.Chase, Misc.Swing.Fist, Megumi.Mahoraga.Throw.Break, Yuki.Hole.Hole, Yuki.Scream, Itadori.Rush.Rush, Hakari.EnergySurge.Teleport, Gojo.LapseBlue.Grab, Yuki.Grab/GrabOST, Yuki.Charge.Start/Finish/End/Charge/ChargeFail |
| 18 | Moveset/Yuta/Awake/CopyController | ModuleScript | 341 | CopyController | CopyService (stored in **global** `CopyService`); Hitbox, FX, ToolController | `selectRemote:FireServer(techniqueName)` — from wheel button click, radial mouse/gamepad release, or public method `CopyController:SelectWheel(slotNumber)` (fires `PlayerGui.CopyWheel.Wheel[slot]:GetAttribute("Name")`) | `Start`(char) Yuta.CursedSpeechStart; `MouthSpeech`(char) `Utils.Yuta.RikaHandTrail.CSVfx` on Head; `MouthGlitch`; `DontMove`(char) — HeavyHit ≤100 studs, `Utils.Misc.Items.Voice` scaled 1.8 Motor6D'd to Head, Sounds Misc.Items.Voice + Yuta.VoiceDontMove (Voice) — Cursed Speech "Don't move"; `PromptWheel`(options, remote) — radial `Utils.Yuta.CopyWheel`; options[1..4] page 1, [5..8] page 2 (Switch button / remote `OnClientEvent("Swap")`); each option = {name, cooldown, lastUsed}; buttons named "1".."4" get attrs `Name`, `Cooldown`, `LastUsed`; keybind text from `ReplicatedStorage.Keybind.Combat["Skill N"].<Keyboard|Gamepad>` via `KeybindIcons:GetTextForKeyCode`, `ToolController.LastInput` (Xbox/Playstation→Gamepad); cooldown countdown uses `workspace:GetServerTimeNow()`; `char.Moveset` descendant "Copy" ValueBase w/ attrs `Tip`, `LastUse` overrides displayed cooldown; wheel destroyed when remote unparented | No | Technique color map (22): Shrine, Doors, Limitless, 10 Shadows, Adaptation, Transfiguration, Blood, Boogie Woogie, Black Mucus, Execution, Mass, Dismantle, Clairvoyance, Puppets, Projection, Ratio, Kamehameha, Hand Sword, Bird Control, Plants, Granite Blast, Roaches. Modules: KeybindIcons, ListData.MoveList (required, unused), BloodyZee. Sounds: Misc.UI.Hover/Click/Switch |
| 19 | Moveset/Yuta/Awake/ElbowRushController | ModuleScript | 152 | ElbowRushController | ElbowRushService; Hitbox, FX | none | `BarrageHit`(target, double) `Utils.Yuta.ElbowRush.HitParticle` ×1-2; `BarrageSound` Barrage + Barrage2 (Voice); `Dust` DustTrail + Whiff; `ElbowHit`(attacker, target, cframe) MetalHit2 + ElbowRush.Hit + RushWind at cframe, HeavyHit; `StepSound`(char, n) ElbowRush.Step<n>; `HeavyHit` Yuta.MetalHit; `Vanish`(char, part) ElbowRush.Teleport + `Utils.Gojo.Teleport`, char invisible until part unparented | No | Sounds: Yuta.ElbowRush.Barrage/Barrage2/Whiff/Hit/Step*/Teleport, Yuta.MetalHit/MetalHit2 |
| 20 | Moveset/Yuta/Awake/LoveBeamController | ModuleScript | 207 | LoveBeamController | LoveBeamService (**global** `LoveBeamService`); Hitbox, FX | none | `StartSound`(part, char) LoveBeam.ChargeSFX + Voiceline (Voice); `Track`(part, cframe, t=0.3) tween; `Bubble`(ball, part) — grows to `Utils.Yuta.LoveBeam.ChargeBall` size, spawns bubble clones w/ RigidConstraint every 0.05s; `SmallBeam`(cframe, part) — `Utils.Yuta.LoveBeam.Beam` (Black/Pink Start/Middle/End) via local `drawBeam(width 2, length = part attr `BeamLength`)`, `ChargeBall2`, sustained HeavyHit ≤180 studs, particles resized 0.3/0.5; `Hit`(t) pink flash (255,85,255) + `BeamHit` | No | Attr: BeamLength. Sounds: Yuta.LoveBeam.ChargeSFX/Voiceline/SmallBeam/SmallBeamHit |
| 21 | Moveset/Yuta/Base/OutburstController | ModuleScript | 393 | OutburstController | OutburstService; Hitbox, FX, ToolController | none | `BodyBurst`(char) `Utils.Yuta.Outburst.Aura`; `Hit`(a, t) Haruta.AmbushHit, pink `Utils.Yuta.SlashHit`, MediumHit; `SwordBurst`(char) on `SetAssets.YutaSword.Sword`; `ProjectileExplode`(pos) `YutaAOE`; `Aerial`(char, part) BodyGyro to `GetMouseTarget()`, Itadori.CursedStrikes.Spin; `Interp`(proj) extrapolate at attr `Speed` only while `proj.Parent == workspace.Bullets`; grows to (15,.25,.25); `StartCharge`(char, part) — `ChargeMeter` GUI Bars 1-3, `SwordCEFlash`; on part attr `Started`: 3 ticks/0.2s, flash white→pink, Yuta.ResoluteSlash sound (speed 2.2-i/3), ground raycast (Map/Domains) spawns `Utils.Nanami.BluntCut.Charge` models via `SraikoVFX.HandleMesh` scaled 0.7/1.05/1.4; `Slash`(char, extra) Outburst.Swing, `Utils.Ryu.Slash` scaled 1.7 (mesh 16+extra); `GroundExplode`(cframe, size) `OutburstExplode` scaled to size, Charge sound, 0.5s later Explosion + `Utils.Gojo.ReversalRed.RedExplode` recolored (255,150,255), HeavyHit ≤60; `ExplosionHit`(t); `Clash`(char, other) yellow flash (1,1,.5), `Utils.Misc.Items.Clash` | No | Attr: Started, Speed, EmitDelay, EmitCount, Duration. Modules: SraikoVFX. Sounds: Yuta.Outburst.Start/Swing/Charge/Explosion/ExplosionHit, Yuta.ResoluteSlash, Haruta.AmbushHit, Itadori.CursedStrikes.Spin, Misc.Items.Clash |
| 22 | Moveset/Yuta/Base/ResoluteSlashController | ModuleScript | 565 | ResoluteSlashController | ResoluteSlashService; FX | none | `WarnAndTrack`(attacker, part, target, silent) — pink Feint on attacker, Yuta.SwordGrab; **if local==target: part.CFrame = lookAt(target→attacker) each frame (client-driven gyro on victim)**; `Teleport`(char, noBurst) Yuta.Leap, `Utils.Goku.Vanish` limb particles, `SwordBurst2.SwordB2` + `SwordBurst.Center` on `SetAssets.YutaSword.Sword.Blade`; `ChargeEffect`(char); `Confused`(char) question mark; `Swing` (Yuta.Swing + `RingSwing`, only if sword equipped); `Swing2`; `Slash`(dirVec, target) `SlashHit` on Head + ResoluteSlash sound; `Hit`(target, withSound) ResoluteHit; `BlackFlashWindup`(attacker, target, big) — big: Yuta.BlackFlash.Windup (Music), CC tween 1.1s, FOV 40→70, Exposure 2→0, 10 red LightningBeams from target `Head.FaceFrontAttachment`; always Windup2 + `BlackFlashWindup` billboard playing decoded flipbook (EditableImage, frames ×2 loops, drifts to `Left Arm.LeftGripAttachment`); `BlackFlash`(attacker, target, part) Land2 + Land (Music, fades after 5s), DivergentFist.BlackFlashHit, red flash, red lightning every 0.02s while part alive, SnapOh + CC + sustained HeavyHit (Flash); `BlackFlashTrail`(cframe, len) `StaticLightning.CreateBolt` red bolts every 20 studs along raycast (`_G.MapParams`), `Utils.Yuta.ResoluteSlash.Disk` decals at hits; `SmallThrow`(a, t) BF hit VFX + FlashBurn 0.4s later; `FinalThrow`(attacker, cframe, target) BlackFlashLaunch, red flash, `FX:Bleed(target)`, Snap sustain | No | Uses AssetService.CreateEditableImage + EncodingService Zstd: `Utils.Yuta.ResoluteSlash.BlackFlashFlipbook` children attr `Image` (zstd buffer) + attr `Size`, destroyed after decode. `_G.MapParams`, `_G.Settings.Flash`. Sounds: Yuta.SwordGrab/Leap/Swing/ResoluteSlash/ResoluteHit, Yuta.BlackFlash.Windup/Windup2/Land/Land2, Itadori.DivergentFist.BlackFlashHit |
| 23 | Moveset/Yuta/Base/RevolveController | ModuleScript | 141 | RevolveController | RevolveService; Hitbox, FX | `remote:FireServer(hitsTable_or_false, hitPosition_or_nil)` from `RevolveService.Hitbox` | Effects: `DiveSound`(char, part) RevolveDive + VeilstepDive (killed when part gone); `Land`(pos) CrushingBlow + RevolveLand; `Spin` SpinRing; `Impale`(t) Yuta.M1.Hit1; `ImpaleFinisher`(t) blood every 0.1s while HRP exists. Signal **`RevolveService.Hitbox`**(part, char, remote): every 0.025s raycast from HRP along part.Velocity×7 + look×3 (Map/Domains) and `SphereHitbox(char, CFrame(0,-5,-5), 8)`; fires when either hits; destroys part on ray hit | **YES** — client computes hit list + ground point | Sounds: Yuta.RevolveDive/VeilstepDive/RevolveLand, Yuta.M1.Hit1. Module: BloodyZee |
| 24 | Moveset/Yuta/Base/SeveringPathController | ModuleScript | 124 | SeveringPathController | SeveringPathService; FX | none | `Start` SeveringPath.Start; `Start2` sword burst on Blade; `Swing` SeveringPath.Swing1-3; `PunchSwing` Hiromi.Throw2 (speed 0.9-1.1); `Hit`(a, t, idx) SeveringPath.Hit<idx>, pink SlashHit rolled by table {10,5,55,50}[idx]; `AirHit`(t) Yuta.M1.Hit4 | No | Sounds: Yuta.SeveringPath.Start/Swing1-3/Hit*, Hiromi.Throw2, Yuta.M1.Hit4 |
| 25 | Moveset/Yuta/Base/VeilstepController | ModuleScript | 225 | VeilstepController | VeilstepService; FX | `remote:FireServer(hitPosition, hitNormal)` from `DiveHitbox` (local char only) | `Sound` Yuta.Veilstep; `Sound2` VeilstepJump; `Dust`(cframe, char) ground raycast `_G.MapParams` → `Utils.Yuta.Veilstep.Dust` (Smoke2 tinted floor color); `SecondWind`(cframe, char) SecondWind.Dash + `Utils.Yuta.SecondWind`; `SecondWindGrab`(char) SpinRing + SecondWind.Grab; `DiveFloorHit`(cframe) `Utils.Hiromi.Shockwave` + `Veilstep.CEImpact`, Hakari.Shock/Impact + VeilstepHit, Snap ≤150 / HeavyHit ≤25; `SpinRing`; `Hit`(t, pink) Yuta.M1.Hit4 ×2 vol; `DiveHitbox`(char, part, remote) — local: raycast from Right Arm along part.Velocity×10 (Map/Domains) or down 6 when grounded; on hit FireServer + destroy part | **Partial** — client reports ground-impact point (not a player hit list) | Sounds: Yuta.Veilstep/VeilstepJump/VeilstepDive/VeilstepHit, Yuta.SecondWind.Dash/Grab, Hakari.Shock/Impact, Yuta.M1.Hit4 |
| 26 | Moveset/Yuta/Rika/RikaDownslamController | ModuleScript | 135 | RikaDownslamController | RikaDownslamService (**global**); Hitbox, FX | none | `RikaHit`(t) Yuta.M1.Hit4; `RikaFloorHit`(posOrChar, normal?) CrushingBlow + VeilstepHit, HeavyHit ≤50; `RikaGrab`(part, target) VeilstepJump @0.2s + Rika.Grab; `StartFly`(part) Rika.StartFly; `DownslamFinisher`(target) 8 blood, VeilstepHit ×1.5, Itadori.Dismantle.Explode, hides target, 2× `Damage.Chunk` per limb (pink if Gore==false) | No | `_G.Settings.Gore`. Sounds: Yuta.Rika.Grab/StartFly, Yuta.VeilstepHit/VeilstepJump, Itadori.Dismantle.Explode |
| 27 | Moveset/Yuta/Rika/RikaGrabController | ModuleScript | 53 | RikaGrabController | RikaGrabService (**global**); Hitbox, FX | none | `GrabSound`(part, holdPart) Rika.GrabStart + looping Rika.GrabHold destroyed when holdPart unparented | No | Sounds: Yuta.Rika.GrabStart/GrabHold |
| 28 | Moveset/Yuta/Rika/RikaHaymakerController | ModuleScript | 48 | RikaHaymakerController | RikaHaymakerService (**global**); Hitbox, FX | none | `StartSound`(part) Rika.Haymaker | No | Sounds: Yuta.Rika.Haymaker |
| 29 | Moveset/Yuta/Rika/RikaLaunchController | ModuleScript | 70 | RikaLaunchController | RikaLaunchService (**global**); Hitbox, FX | none | `Feint`(char, withSound) Yuta.EnergyRipple.Feint.Feint then Swing (0.2s), pink Itadori.CounterHit.Feint; `StartSound`(part) Rika.Launch | No | Sounds: Yuta.EnergyRipple.Feint.Feint/Swing, Yuta.Rika.Launch |
| 30 | Moveset/Yuta/Rika/RikaLoveBeamController | ModuleScript | 397 | RikaLoveBeamController | RikaLoveBeamService (**global**); Hitbox, FX | none | `ScaleTo`(rikaModel, scale=1.7) 0.2s lerp + LoveBeam.RikaMovement; `Charge`(ball) grows 1.5→2.25→3.25, `ChargeBallEffects` staged, jitters 0.3; `StartBeamSound`(part) re-clones `part.TrueLove` sound, EmitterSize 100; `StartBeam`(part, soundHolder) — reads part attrs `BeamStartCFrame`, `BeamLength`, `Width`; `ChargeBall2` + white Highlight model "WhiteHighlight"; if camera facing (dot≥0.7, <70 studs) HeavyHit + pink CC (Flash); `Utils.Yuta.LoveBeam.Beam` via `drawBeam` (start seg 45 studs; width 30→60→40→30 then `Width`-5), `StaticLightning.CreateBolt` bolts 3 lanes every 0.06s, `BlackSpec` shooting every 0.3s, `Utils.Yuta.LoveBeam.CameraFX` inserted into Lighting while camera inside beam bbox, sustained HeavyHit ≤180; ends when part unparented; `Hit`(t) pink flash; `Finisher`(target) hides, CollisionGroup "NoPlayerCollision", `LoveBeam.Smoke` per limb | No | Attr: BeamStartCFrame, BeamLength, Width. Sounds: Yuta.LoveBeam.RikaMovement, `TrueLove` sound instance on part |
| 31 | Moveset/Yuta/Rika/RikaSlamController | ModuleScript | 73 | RikaSlamController | RikaSlamService; Hitbox, FX | none | `StartSound`(part) Rika.SlamTry; `GrabLand`(part, holdPart) Rika.SlamLand until holdPart gone; `Ring`(rikaModel, idx) `Utils.Yuta.RingSwing[idx].Ring` at Torso facing RootPart look | No | Sounds: Yuta.Rika.SlamTry/SlamLand |
| 32 | Moveset/Yuta/Rika/RikaThrowController | ModuleScript | 101 | RikaThrowController | RikaThrowService (**global**); Hitbox, FX | `remote:FireServer(cameraLookVector)` every frame in `TrackCamera` until remote attr `Disabled` | `TrackCamera`(remote, subjectPart) — Rika.ThrowStart, sets `Camera.CameraSubject = subjectPart` (ride the thrown projectile/Rika), streams look vector, restores Humanoid subject; `Sniper`(target, thrower) BlackFlashHit VFX + `FinisherDrag` on target, red flash, DivergentFist.BlackFlashHit, Yuta.BlackFlash.Land3 (Music), HeavyHit + CC | No (aim stream only) | Attr: Disabled (on remote). Sounds: Yuta.Rika.ThrowStart, Yuta.BlackFlash.Land3 |
| 33 | Moveset/Yuta/YutaController | ModuleScript | 425 | YutaController | YutaService; Hitbox, FX | none | `Hit`(attacker, target, idx, dir, fistMode) — fistMode or dir==false → Gojo.M1.Hit<idx> (+Yuta.MetalHit3 if fistMode); else Yuta.M1.Hit<idx|Up|Down> + pink `Utils.Yuta.SlashHit` rolled per idx (2: -15°, 3: +25°, Up: -75°); `ChaseHit`(a, t, sword) Yuta.M1.Hit1-3 vs Gojo.M1.Hit3; `AerialHit`; `Chase`; `Swing`(char, idx, dir, forceSword) — `InUlt` and not forceSword → Misc.Swing.Fist else Yuta.M1.Swing<idx|4Sword>; `Swing2`(char, idx, dir, sword) — sword==false: ArmFlash (255,85,255) L/R combos; idx 4 no dir → Left Leg; sword → `Utils.Yuta.CombatTrail` welded to `SetAssets.YutaSword.Sword.MeshPart` (0.425s on idx 4 else 0.275s); `Launch`; `SwordSound`(char, quiet) Yuta.SwordGrab + `Sheath.Glow.Glow`; `BreakChainSound`/`MetalArmSound`/`ShakeArmSound`/`PutRingSound` → Yuta.Ultimate.BreakChain/EquipArm/ShakeArm/PutRing; `BreakChain`(char) — `SetAssets.YutaSword.ChainRing`: destroys welds, keeps every 3rd Part and simulates it client-side w/ attr `Velocity` + gravity; `Chat`(char, variant) Yuta.Ultimate.VL / VLZero (Voice) + `Utils.Yuta.Dialogue` Text1/Text2/Chat; `RingEmit`(char) `SetAssets.YutaRing.Diamond.Visuals` ConstantGlow + Beam sweep | No | Attr: InUlt. SetAssets: YutaSword (Sword.MeshPart/Blade, Sheath, ChainRing), YutaRing. Sounds: Gojo.M1.Hit*, Yuta.M1.Hit1-4/HitUp/HitDown/Swing1-4/Swing4Sword, Yuta.MetalHit3, Yuta.SwordGrab, Misc.Swing.Fist, Misc.Chase, Itadori.CraniumSmash.Hit2, Megumi.Mahoraga.Throw.Break, Yuta.Ultimate.BreakChain/EquipArm/ShakeArm/PutRing/VL/VLZero |

No `rbxassetid://`, gamepass, product, place or UserId literals appear in any of the 33 files. Outfit id comes from `_G.Settings.Outfit` (runtime value).

### A.6 Character/Join controllers, KnitRunClient, loader, root CameraController (9)

| # | Path (from header) | Type | Lines | Knit name | Services used (GetService) | Client→server calls | Server→client signals handled | Client-auth hit report? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `CameraController` (root — no PlayerScripts prefix; parent unknown, likely nil/orphaned or dumped from a `require`d module cache) | ModuleScript | 3524 | none visible (obfuscated) | ? (obfuscated) | ? (obfuscated) | ? (obfuscated) | ? | **Fully VM-obfuscated (Luraph-style)**: `task.spawn(function(...) return ({...VM table...}):j()(...) end) return true`. Uses `buffer`, `readf32/readu8/readu16/readi16/readstring`, `bit32.*`, `getfenv/setfenv`, `coroutine.wrap/yield`, error handler string `"Luraph Script:" .. name .. ": " ..`. ~59 KB of Ascii85 payload strings. **Zero** plaintext references to `game`, `workspace`, `Knit`, `Camera`, `CFrame`, `TweenService`. Cannot determine custom-vs-stock; see prose. |
| 2 | `Players/SmartzyMan/PlayerScripts/Controllers/Character/AntiCheatController` | ModuleScript | 2593 | none visible (obfuscated) | ? | ? | ? | n/a | **Fully VM-obfuscated**. First statement: `return 11 - 1 == 10 and "Owl-Fuscator Anti Decompile v3; By Google Chrome#6242" or ({...VM...}):DD()`. Same VM primitives (`bit32.*`, `string.pack/unpack/char/sub/gsub/match`, `getfenv/setfenv`, `coroutine.wrap/yield`, `pcall`, `table.move`). ~21 KB Ascii85 payload. Two functions "failed to decompile" (L1576, L1910). **Zero** plaintext `game`/`Kick`/`FireServer`/`Knit`. No checks/thresholds/remotes recoverable from dump. |
| 3 | `.../Controllers/Character/JoinController/InventoryController` | ModuleScript | 346 | `InventoryController` | `EmoteService`; controllers `FXController`, `EmoteController` | `EmoteService.Equip:Fire(slotIndex(1..16), emoteName)`; `EmoteService.ChangeInv:Fire(titleName)`; `EmoteService.ChangeMVP:Fire(mvpName)`; `EmoteService.ChangeSkin:Fire(category)` (reset to default) / `ChangeSkin:Fire(category, skinName)` | `EmoteService.ChangeInv(list, kind)` kind 1=emotes, 2=MVP/victories, 3=skins `{owned={cat={skins}}, equipped={cat=skin}}`, else=titles; `EmoteService.ChangeSkin(previewModel|nil)` → viewport preview | No | GUI `PlayerGui.Menus.Group.Inventory` (Categories/Items: Emotes, Titles, MVP, Skins; `Preset.Emote`, `Items.Skins.Preset.Category/Skin`). Emote equip grid 8 slots x 2 pages (`EmoteController.Page`, `EmoteController.EmoteCache`). Attributes read: `player.Title`, `player.MVP`; sets `Inventory.Loaded=true`. **Hardcoded username whitelist**: "Skins" category button only visible if `LocalPlayer.Name == "imed2004"`. Highlight colors: selected `Color3.fromRGB(85,170,255)`, default white. Sounds `Sounds.Misc.UI.Click/Switch`, SoundGroup `SoundService.Effect`. Viewport preview camera with `UIDragDetector` slider (rotate ±90°). |
| 4 | `.../JoinController/NepController` | ModuleScript | 136 | `NepController` | `NepService`; `FXController` | none | `NepService.Effects`: `ToggleRadio(nepModel)`, `RadioBeep(nepModel)`, `RadioSignal(nepModel, stop?)`, `RadioBounce(nepModel)`, `RadioTalk(nepModel, text, duration=2.5)`, `UngezieferRage(character)` | No | "Nep" = a radio NPC/prop with `.Root` (Sounds StaticLoop/Signal/Music, BillboardGui `_Entry`) and `.Model.Button`. RadioBounce scales model by music volume (`ScaleTo(1+sin*0.15*vol/2)`). RadioBeep reuses `Utils.Itadori.EyeTrails` VFX recolored `RGB(203,0,3)`. Sounds `Sounds.Misc.Nep.{Start,StaticLoop,Beep,Signal,Talk,TalkStart,Rage}`; `SoundService.Voice` group for Talk. "Ungeziefer" (German: vermin) rage sound on a HumanoidRootPart — probably an NPC/boss. |
| 5 | `.../JoinController/RulesController` | ModuleScript | 100 | `RulesController` | `JoinService`; `FXController` | `JoinService.AcceptRules:Fire()` (no args) | none (reads attr) | No | `Rules = require(ReplicatedStorage.Modules.Rules)` → `RuleList`, `Agreements`, `Version` (rule text not in this file). GUI `Menus.Group.Rules` (ScrollingFrame.Rule template, `Preset.RuleAgree`, `Accept` button). Player attribute `LastRulesAccepted` compared to `Rules.Version`; Accept shown until server sets attr. Checkbox glyph "✔️". |
| 6 | `.../JoinController/SettingsController` | ModuleScript | 376 | `SettingsController` | `JoinService`, `AchievementService`; controllers `ToolController`, `FXController` | `JoinService.Setting:Fire(valKey, boolean)` (toggle); `JoinService.Setting:Fire(valKey, number|"")` (ID setting, e.g. music/asset IDs, gamepass gated); `JoinService.Setting:Fire(valKey, number 0..Max)` (slider/volume); `AchievementService.Give:Fire("Space Shenanigans")` (camera Y > 15000); `AchievementService.Give:Fire("Betavision", true)` (when LocalSettings.Gravity and .Invert both on) | `JoinService.Setting("Batch", zstdBuffer)` → `EncodingService:DecompressBuffer(..., Zstd)` + JSONDecode → `_G.Settings` full table; `JoinService.Setting("Single", key, value)`; `AchievementService.Give` (also listened client-side); raw `ReplicatedStorage.Remotes.ForceFun.OnClientEvent(settingName)` → forces a LocalSetting true | No | Defines `_G.Settings`, `_G.LocalSettings`, `_G.SettingUpdate` (BindableEvents keyed by setting `Val`). Setting definitions are ModuleScripts under `ReplicatedStorage.Modules.Settings.<Category>.<Name>` with fields `Btn` (1 toggle, 2 ID string, 3 value slider w/ `Max`, 4 button w/ `BtnText`), `Val` (server key; nil → local-only), `Desc`, `SortOrder`, `Callback`, `Gamepass` (attribute name on `player.Gamepasses` folder gating visibility). Keybinds: `Settings.Keybinds[actionName] = {K={KeyCode,Modifier?}, G={...}}` applied to `ReplicatedStorage.Keybind.<action>.Keyboard/Gamepad` (`.KeyCode`, `.PrimaryModifier`). Achievement client-triggered = **client-authoritative achievement grant** (exploitable). Space skybox VFX `Utils.Misc.Space` (Earth/Atmo) above Y 15000. Requires `Modules.Icon`, `Modules.BloodyZee`. Toggle colors green `RGB(85,255,0)` / red `RGB(255,0,0)`. |
| 7 | `.../JoinController/UpdateLogController` | ModuleScript | 240 | `UpdateLogController` | `FXController` | none | none | No | `Ver = "1.82"`, title `"V1.82 \n THE NOTHING UPDATE"`. Renders `Updates` nested tables into `Menus.Group.Logs.ScrollingFrame.UpdateInfo.UpdateText` (rich text) and prints a markdown version. Full text in prose section. |
| 8 | `Players/SmartzyMan/PlayerScripts/KnitRunClient` | LocalScript | 45 | — | — | none | none | No | `Knit.AddControllersDeep(PlayerScripts.Controllers)`; `Knit.Start({ServicePromises=false})`; `CmdrClient:SetActivationKeys({F2, Semicolon})`. **Hardcoded UserId hide-list** `{1241352401, 31070091, 174332536}` → sets attribute `HidePlayer=true` on those Players; every `Stepped`, any other player with `HidePlayer` is reparented to `nil` client-side (hidden from leaderboard/Players list), others restored to `game.Players`. |
| 9 | `Players/SmartzyMan/PlayerScripts/PlayerScriptsLoader` | LocalScript | 9 | — | — | none | none | No | Stock Roblox loader: `require(script.Parent:WaitForChild("PlayerModule"))`. Implies a `PlayerModule` (stock or forked) exists in PlayerScripts. |

### A.7 Core controllers, Workspace, StarterPlayer, Utils (51 incl. 17 stubs)

Note: 19 files in this slice are `-- failed to get script bytecode` stubs (server-side `Script`s whose bytecode is not replicated to the client). They are listed once in the "Unavailable server scripts" table below and omitted from the main table.

| # | Path (from header) | Type | Lines | Knit name | Services used (GetService) | Client→server calls | Server→client signals handled | Client-auth hit report? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 5 | Players/.../Controllers/Combat/HitboxController | ModuleScript | 77 | `HitboxController` | `HitboxService` | `remoteEvent:FireServer(hitCharsTable)` (remote supplied by server per-hitbox); `ReplicatedStorage.Remotes.GetClient` reply: `remote:FireServer(camera.CFrame)` | `HitboxService.Hitbox(char, cframeOffset, radius, remoteEvent, lifetimeObj?)` (RemoteSignal); `Remotes.GetClient.OnClientEvent(remote)` | **YES** — client computes sphere overlap and sends the hit character list | OverlapParams Include `workspace.Characters`; `Utils.Hitbox.Hitsphere` debug visual (only if its Transparency ~= 1) parented to `workspace.Effects`; loop tick 0.025s |
| 6 | Players/.../Controllers/DebugController | ModuleScript | 517 | `DebugController` | `DebugService`, `BuildService`; ctrl `FXController` | `DebugService.Debug:Fire(cmdName[, targetPlayer\|"All"\|text])`; `DebugService.Unban:Fire(userId)`; `DebugService.Update:Fire()`; `Remotes.Request:FireServer(requesterPlayer)` (Allow build-mode request) | `DebugService.Debug(name, value)` (incl. `"Banned"` list), `DebugService.Update(flagsTable)`, `Remotes.Request.OnClientEvent(player, text)`, `Workspace.Map.Destructible.Model.StationControl.Handle.Train.OnClientEvent` (train camera shake) | No | Admin/creator panel in `PlayerGui.Menus.Group.Private`; keybinds `ReplicatedStorage.Keybind.Creator["Reset Cooldowns"/"Toggle Flight"/"Toggle Build Menu"]`; attributes: player `PS_Perms`, `Workshop`; char `UltDrain`; `char.Info` attrs `CD`, `NoStun`, `NoRes`, `DeathKick`, `Skill`, `M1`, `Ult`, `Parkour`, `Burst`; `HumanoidRootPart.FlightForce`, player `BuildTag`; `_G.WorkshopIcon`, `_G.MapParams`; CameraShaker presets Snap/HeavyHit/LightHit; `Icon` module |
| 7 | Players/.../Controllers/DiscordController/DiscordClient | ModuleScript | 47 | (helper module) | — (uses `ReplicatedStorage.Modules.Discord.{RemoteEvents,Logger,Utils}`) | `UpdateActivity:FireServer(activityTable)` — remote fetched via `RemoteEvents.tryGet("UpdateActivity", 2)` | — | No | Roblox Discord Social SDK client wrapper: `setActivity(details, state, assets, type, party, secret)` → `Utils.createGameActivity(tbl)`; `isReady()` always false in dump (never set). Logger tag `"NETWORK"`, "SocialSDKClient" |
| 8 | Players/.../Controllers/DiscordController | ModuleScript | 22 | `DiscordController` | — | — | — | No | Empty controller; only `require(script.DiscordClient)` |
| 9 | Players/.../Controllers/DomainController | ModuleScript | 759 | `DomainController` | `DomainService`; ctrl `FXController` | — (none) | `DomainService.Effects` keys: `Clash`, `Hit`, `Swing`, `Swing2`, `Launch`, `ClashHighlight` | No | Domain clash cinematic (see prose). Modules: CameraShaker, BloodyZee (required, unused), `UltNames` (moveset→color table). Char attr `Moveset`; clash-part attrs `Timer`, `Type`, `Offset`; `_G.Settings.Flash`; UI `PlayerGui.Main.Controls.Ultimate.Time` |
| 10 | Players/.../Controllers/FXController | ModuleScript | 1211 | `FXController` | `DebreeService`, `DomainService` | — (none) | `DebreeService.Sound(buffer\|voxelId\|part)`, `DebreeService.Create(voxelData, noVFX?)`, `DebreeService.Physics(buffer)`, `DebreeService.Prop(voxelIdList)`, `DebreeService.Domain(part)`, `DomainService.CFix(offsetVector3)`, `Remotes.Message.OnClientEvent(text, playClick?)` | No | Shared FX API (see prose). Modules: BloodyZee, PartCache (2000 parts, `Utils.Damage.DebreeRef`, container `workspace.Map.Data`), ListData.Materials. `_G.Settings.{DesPHY,Gore,DesVFX,DesINT,Flash}`, `_G.MapParams`. Domain attrs `Health`, `Fade`; `char.Info.DomainTag`; char attr `Bleeding`; UI `PlayerGui.DomainFade`, `PlayerGui.Menus.Preset.Notification`, `Utils.DomainWarn` |
| 11 | Players/.../Controllers/ItemController | ModuleScript | 770 | `ItemController` | `ItemService`; ctrls `FXController`, `CharlesController` | — (none) | `ItemService.Effects` keys (see Item section) | No | Item VFX/SFX; `_G.Settings.SENS`, `_G.Settings.Flash`; item attrs `Roulette`, `GoHam`, `Speed`, `Mode`; `workspace.Bullets` |
| 12 | Players/.../Controllers/RankedController/FinalShowdownController | ModuleScript | 230 | `FinalShowdownController` | `FinalShowdownService`; ctrl `FXController` | — (none; spectate is local attr) | `FinalShowdownService.Effects` keys: `PipeShoot`, `Transition(gamemodeText)` | No | Uses `Start()` not `KnitStart` (custom lifecycle?). Workspace attrs `Timer`, `Loading`; player attr `Spectate`; team `Lobby`; `workspace.Map.Core.Pipe.Core.PipePoint`; `workspace.Effects.WaitAmbience`; modules Icon, MVP, PlayerModule |
| 13 | Players/.../Controllers/RankedController/NightParadeController | ModuleScript | 47 | `NightParadeController` | `NightParadeService`; ctrl `FXController` | — | `NightParadeService.Effects` key: `PickVows` (empty stub) | No | Stub |
| 14 | Players/.../Controllers/RankedController/RouletteController | ModuleScript | 765 | `RouletteController` | `RouletteService`, `AchievementService`; ctrl `FXController` | `RouletteService.Spectate:Fire()` (toggle spectate); `RouletteService.Spectate:Fire(afkBool)` (AFK toggle); `AchievementService.Give:Fire("Poor Performance")`; `kitRemote:FireServer(vowIndex)` (Kit pick); `CrowUpd:FireServer(cframe)` (client-driven crow movement, every Heartbeat) | `RouletteService.Effects` keys: `Transition`, `Result`, `ResultTeam`, `Announce`, `Credits`, `Crow`, `ClapSpawn`, `CrowExplode`, `CrowMad`, `CaptureRealm`, `Kit` | No (but crow position is **client-authoritative movement**) | Workspace attrs `Timer`, `Loading`, `Roulette`; char attr `Dead`; player attr `MVP`; `_G.MVP_PLAYING`, `_G.Crow`, `_G.Shift`; `workspace.Effects.{WaitAmbience,Music,Crows}`; `Utils.Misc.RouletteKit`; UI `PlayerGui.Roulette` |
| 15 | ReplicatedStorage/Utils/Choso/Convergence/Spin | Script | 92 | — | — | — | — | No | Choso Convergence: 4 orbiting `Blood1..4` attachments spin (160°/s) around weld; attr `Charge` (0–4) decrements → blood orb flies via quadratic bezier to Right Arm over 0.6s then bursts with `Utils.Choso.PiercingBlood.Start.Burst` |
| 16 | ReplicatedStorage/Utils/Choso/Convergence/WingKing | Script | 53 | — | — | — | — | No | Variant: tighter radius 2.6, spin 700°/s, `Smear` enabled; `Charge` attr destroys orbs, Smear off at 0 |
| 17 | ReplicatedStorage/Utils/Hakari/IdleDeath/Scenarios/IC_Scenario/ScenarioPlay | Script | 34 | — | — | — | — | No | Hakari Idle Death Gamble scenario (Yuuki rig anim `script.Animation`); attrs `Jackpot` (bool), `Speed`; on miss: anim jumps to t=7, doors `Door1/Door2` swing ±90°, black Highlight fade |
| 18 | ReplicatedStorage/Utils/Hakari/IdleDeath/Scenarios/P_Scenario/ScenarioPlay | Script | 27 | — | — | — | — | No | Same as above, no doors |
| 19 | ReplicatedStorage/Utils/Misc/Crow/CrowUpd/Caw | Script | 24 | — | — | — | `CrowUpd.OnClientEvent()` → play `Sounds.Misc.Crow.Caw1..3` | No | Crow rig idle anim `Animations.Misc.Crow` on `AnimControl` |
| 20 | ReplicatedStorage/Utils/MoveReveal/Handle | Script | 86 | — | — | — | — | No | Billboard moveset/cooldown display over a character: reads `char.Moveset` folder of NumberValues, attrs `Key`, `LastUse`, `ReadyAt` (server time) |
| 21 | ReplicatedStorage/Utils/Nanami/OvertimeAura/Music/ClientMusic | Script | 13 | — | — | — | — | No | Nanami Overtime music: audible only to owner (RollOff distances 0 for others) |
| 22 | ReplicatedStorage/Utils/Preload/LightEtye/Script | Script | 12 | — | — | — | — | No | If in local char: sustained Snap shake fading 1s |
| 23 | ReplicatedStorage/Utils/Preload/LocalCarScript | LocalScript | 126 | — | — | — | — | No | Hover-car driver script: `script.Car` ObjectValue, `Configurations.{Suspension,Bounce,Height,Speed,TurnSpeed}`, `CarScript.RaycastModule`, BodyThrust/BodyVelocity; **sets local HRP Velocity/RotVelocity directly** (client-driven vehicle) |
| 24 | ReplicatedStorage/Utils/Preload/SoundFont/Fonts/DrumFont | ModuleScript | 34 | — | — | — | — | No | Sound font: asset ids 31173820, 31173799, 31173844, 31173863, 31173881, 31173898, 31173735, 31173771 |
| 25 | ReplicatedStorage/Utils/Preload/SoundFont/Fonts/PianoFont | ModuleScript | 79 | — | — | — | — | No | 31 piano samples 14894840794 … 14894837643 (see Asset list); pitch 1.059463^n |
| 26 | ReplicatedStorage/Utils/Preload/SoundFont/Fonts/TrumpetFont | ModuleScript | 25 | — | — | — | — | No | asset 3036987884 |
| 27 | ReplicatedStorage/Utils/Preload/SoundFont/SoundCache | ModuleScript | 43 | — | — | — | — | No | Sound object pool (50 prealloc) |
| 28 | ReplicatedStorage/Utils/Preload/SoundFont/Tween | ModuleScript | 29 | — | — | — | — | No | TweenService wrapper |
| 29 | ReplicatedStorage/Utils/Reveal/Handle | Script | 96 | — | — | — | — | No | Same as MoveReveal + `Ult.Fill` (player attr `Ultimate`/100) and `Evasive.Fill` (char attr `Evade`/50) bars; used by Tinted Glasses item (MaxDistance 75) |
| 30 | ReplicatedStorage/Utils/Todo/Awakening/Bleed | Script | 27 | — | — | — | — | No | Todo awakening bleed VFX while char attr `InUlt`; BloodyZee; `_G.Settings.Gore`; skipped on local char |
| 31 | ReplicatedStorage/Utils/Yuta/Rika/Client | Script | 270 | — | — | `script.Remote:FireServer(humanoid.MoveDirection)` (owner only) | `script.Parent.Effects.OnClientEvent(name, ...)` keys: `UltimateStart("Zero"\|other)`, `Break`, `StartScream(obj)`, `Teleport(cf)` | No | Rika summon rig client: `Owner` ObjectValue; `RikaRig` w/ `Control` animator; anims `script.{Idle,Spawn,F,B,L,R}`; attrs on rig model `Invisible`, `Dead`, `Move`; `Info.{InSkill,Transparent,SnapPosition}`; sounds `Sounds.Yuta.Rika.{Summon,SummonVL,Desummon,Ultimate.Start,Ultimate.Break,UltimateZero.Start,UltimateZero.Voiceline}` |
| 43 | Workspace/Effects/Blood/PoolActor/Blood | Script (Actor, parallel) | 40 | — | — | — | Actor message `"Ray"(part)` | No | Blood-pool decal placement: raycast down 3 studs (Include Map+Domains), sets attr `CF`, `Ref` ObjectValue; attr `RT` rotation |
| 44 | Workspace/Map/Core/the most blatant ad ever/Part/AL2_TP/AL2_UI/LocalScript | LocalScript | 34 | — | — | — | — | No | Teleport splash UI animation (Frame fade, Sound, Icon, Area/Area2/Star/Stars). **No place ID present** — the teleport itself lives in the unavailable server script `AL2_TP` (#45) |
| 47 | Workspace/Map/Destructible/Model/Ads/Script/BillboardEditUI/PianoSystem | LocalScript | 55 | — | — | `script.Parent.Remote.Value:FireServer(promptObj, text)` / `(promptObj, "Report")` | — | No | Billboard text edit UI (misnamed "PianoSystem"); remote = `Ads.MoneyDestroyer5000.RemoteEvent` (via ObjectValue) |
| 48 | Workspace/Map/Destructible/Model/Ads/Script | Script (client RunContext) | 44 | — | — | — | — | No | Wires ProximityPrompts on ad billboards → opens `BillboardEditUI`; sets SurfaceGui Adornee to `Screen` parts |
| 49 | Workspace/Map/Destructible/Model/Courtroom/Court/Handle | Script | 42 | — | — | — | — | No | Voice-chat audio routing: seat models get `Head.AudioListener` → `Audio.<Name>Wire`; speakers `Speaker1/2` ← `Audio.AudioReverb` |
| 50 | Workspace/Map/Destructible/Model/StationControl/Handle | Script | 105 | — | — | `script.Mic_Air:FireServer()`, `script.Train:FireServer()` (ProximityPrompt `Button` under `ButtonAir`/`ButtonTrain`) | `script.Mic_Air.OnClientEvent(1\|2\|other)` → JingleAir/JingleOff/Train sounds; `script.Train.OnClientEvent()` → spawn `Utils.Misc.Train`, tween 1200 studs over 3s | No | Station PA: `Mic.AudioEqualizer` bypass toggled by camera LOS to `Speakers` (≤300 studs); EQ muffles (-80/-20/-80 dB) when not in LOS |
| 51 | Workspace/Map/Destructible/Model/Talk/Talkshow/Handle | Script | 38 | — | — | — | — | No | Talk-show mic: `Mic.Head.AudioListener` → `Audio.Wire`; `Speaker1/2` ← `Audio.AudioReverb` |

#### Unavailable server scripts (bytecode not replicated) — 19 files

| # | Path | Type | Note |
|---|---|---|---|
| 1 | Aaqwert112233A/Health | Script | Per-character Health script (Roblox default regen replacement?) |
| 2 | Animate | Script | Server-side Animate (custom; not the default LocalScript) |
| 3 | Health | Script | — |
| 4 | LocalScript | LocalScript | Unnamed; bytecode unavailable even though LocalScript (possibly destroyed/inaccessible) |
| 32 | Script | Script | — |
| 33 | StarterPlayer/StarterCharacterScripts/Health | Script | Template for per-character Health |
| 34–42 | Workspace/Characters/{Alva270, Erikplase325, Martel12346, SmartzyMan, animegod123l, gamerbombast, itsKMSVR, tackierambow, theplasmaguy7}/Health | Script | Same Health script cloned into each live character (characters live under `workspace.Characters`) |
| 45 | Workspace/Map/Core/the most blatant ad ever/Part/AL2_TP | Script | Server teleport for the "AL2" ad part — **place ID not recoverable from client dump** |
| 46 | Workspace/Map/Destructible/Model/Ads/MoneyDestroyer5000 | Script | Server handler for billboard-edit RemoteEvent (text filtering / paid ads?) |

Health scripts confirm: health/regen is server-authoritative and not visible.

---

### A.8 ReplicatedStorage.Modules game-specific (74)

| # | Path | Type | Lines | Knit name | Services used | Client→server calls | Server→client handled | Client-auth hit? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | ReplicatedStorage/Modules/Base64 | Module | 101 | – | – | – | – | no | Base64 + Zstd (`EncodingService:CompressBuffer`) helpers: `to_base64/from_base64` (zstd then b64), `to_base64raw/from_base64raw`, `to_zstd/from_zstd`. Likely used for custom-moveset import/export codes. |
| 2 | ReplicatedStorage/Modules/BloodyZee | Module | 97 | – | – | – | – | no | Client blood system on FastCastRedux. API `BloodyZee:Blood(originCFrame, speed, pitchSpread, yawSpread)`; `BloodyZee.PermBlood` flag. Gated by `_G.Settings.Gore == true` and 150-stud camera range. Pools land on `workspace.Map`/`workspace.Domains`, parented to `workspace.Effects.Blood`, 8 s Debris unless PermBlood; 3 `PoolActor` actors (`SendMessage("Ray", pool)`) re-raycast pools whose parent part vanished. Attributes on pool: `CF`, `RT`; `Ref` ObjectValue. Game-specific (not stock). |
| 3 | ReplicatedStorage/Modules/CountryCodes | Module | 280 | – | – | – | – | no | ISO country→continent map (~250 entries), `Continents` set, `ContinentCode` (NA/SA/OC/AF/AS/EU/AN). Used by server-region display. |
| 4 | ReplicatedStorage/Modules/DeadlyData | Module | 62 | – | – | – | – | no | Hiromi "Deadly Sentencing" ult data: 26 `Crimes` strings, 4 `Dialog` pairs (3 defendant lines / 3 judge responses each), 4 `DialogFail` lines. Joke crimes reference game meta ("Using Vessel", "Steering Mahoraga's wheel", "Criticising Unlicensed Studios"). |
| 5 | ReplicatedStorage/Modules/Discord/Logger | Module | 229 | – | – | – | – | no | Generic leveled console logger (ERROR/WARN/INFO/DEBUG/TRACE), default level WARN, per-category enable, `setConfig`. Console only — NO webhook / HttpService. Part of "Discord Roblox SDK". |
| 6 | ReplicatedStorage/Modules/Discord/RemoteEvents | Module | 54 | – | – | – | – | no | Helper: `getOrCreate(name, class)` (server-only, creates in `ReplicatedStorage.Remotes`), `waitFor(name)`, `tryGet(name, timeout=10)`. |
| 7 | ReplicatedStorage/Modules/Discord/Utils | Module | 42 | – | – | – | – | no | `createGameActivity{type,state="In Game",details="Playing",assets,timestamps,party,secret}` → Discord Rich Presence payload (platform "desktop"); `ActivityType` enum (PLAYING 0, STREAMING 1, LISTENING 2, WATCHING 3, COMPETING 5). |
| 8 | ReplicatedStorage/Modules/Discord/Version | Module | 71 | – | – | – | – | no | `VERSION "1.0.3"`, `BUILD_DATE "2026-06-25 20:13:20 UTC"`, `BUILD_TIMESTAMP 1782418400`, `ToString` → "Discord Roblox SDK 1.0.3 (built …)". Stock SDK module. |
| 9 | ReplicatedStorage/Modules/EffectUtils | Module | 285 | – | – | – | – | no | VFX helper lib: `Debris`, `Visibility(model, visible, tweenTime)` (respects `Invisible` attribute), `EmitParticle`, `Emit(template, parentOrCFrame, lifetime)`, `Enable(classFilter, template, parent, duration, invert)`, `Mesh`, `Tween(obj, t, style, dir, props)`, `AutoMeshes`/`AutoEmit`/`AutoEnabled`/`AutoEffects(folder, rootPart)` driven by attributes `EmitCount`, `EmitDelay`, `StartTransparency`, `EndTransparency`, `Distortion`, `Duration`, `Welded`, `Part_TweenParams`, `Mesh_TweenParams`, `Decal_TweenParams`, `Parent` (dot path), `Raycast`, `RaycastHitOffset`, `Time`. Emits into `workspace.Effects`; raycasts against `workspace.Map`. Game-specific. |
| 10 | ReplicatedStorage/Modules/Info/Tutorial | Module | 77 | – | – | – | – | no | 8 tutorial pages {title, subtitle, imageId, paragraphs}: Ragdolls (img 124674005293931), Blocking (93359191648570), Parkour (102306667240177), Burst (119038955627224), Throwables (5670799859), Items (5608359401), Shop (5608359401), Combat (5608359401). Mechanics text below. |
| 11 | ReplicatedStorage/Modules/LightningBeams | Module | 241 | – | – | – | – | no | Stock "LightningBolt" module (Quasiduck-style): `LightningBolt.new(att0, att1, partCount=30, parent=workspace.Effects.Bolt)`, props CurveSize0/1, MinRadius, MaxRadius 2.4, Frequency, AnimationSpeed 7, Thickness, Min/MaxThicknessMultiplier, Min/MaxTransparency, PulseSpeed 2, PulseLength, FadeLength .2, ContractFrom .5, Color (Color3 or ColorSequence), ColorOffsetSpeed 3, Material Neon; `Destroy`, `DestroyDissipate(t, strength)`. Heartbeat-driven, `debug.profilebegin("LightningBolt")`. Only change from stock: default parent `workspace.Effects.Bolt`. |
| 12 | ReplicatedStorage/Modules/ListData | Module | 1005 | – | – | – | – | no | Master data lists: Items, MoveList, SpecialList, AttackTypes, States, Characters, Materials, AnimList (see §4). Consumed by CmdrClient Types (Items, Characters), FXController (Materials), Yuta CopyController (MoveList). |
| 13 | ReplicatedStorage/Modules/MVP/Domain Invasion | Module | 84 | – | – | – | – | no | MVP cutscene: clones `script.Domain` scene into `workspace.Effects`, applies winner's HumanoidDescription to `Rig`, plays `script.Character`/`script.Camera` anims, `script.SFX` (SoundGroup Effect), camera Scriptable FOV 40, background billboard follows camera, `DepthOfField` to Lighting, cloud/shadow particle timing, freezes at end. Title sounds like Megumi/Sukuna domain. |
| 14 | ReplicatedStorage/Modules/MVP/King Of Curses | Module | 82 | – | – | – | – | no | MVP cutscene: `script.Innate` scene, `script.Voice` (SoundGroup Voice), `SukunaAtmo` Atmosphere + `DepthOfField` to Lighting, FOV 41, `BindToRenderStep("Focus",301)`, `Dust.Dust:Emit(300)`. Sukuna themed. |
| 15 | ReplicatedStorage/Modules/MVP/Meditation | Module | 123 | – | – | – | – | no | MVP cutscene: `script.Scene` with `Butterfly*` animated models, sounds `birds-chirping`, `waterfall3_looped`, `Clap Todo`; Lighting ColorShift_Bottom (0,48,255)/Top (253,255,159)/Ambient (20,192,255)/Brightness 5 then restored from `Lighting.Config` attributes; FOV 30, camera from `Scene.Camera.camera`. Todo themed. |
| 16 | ReplicatedStorage/Modules/MVP | Module | 82 | – | – | – | – | no | Dispatcher: `MVP:MVP_Play(player, name)` → `script:FindFirstChild(name)` → `require(child):Start(player, cleanupList)`; sets `_G.MVP_PLAYING = true` during; `script.Fade` ScreenGui fade-in 2 s / out 0.5 s; `MVP_End(list, silent)` disconnects/stops/destroys everything, restores camera Custom FOV 70, re-enables `PlayerGui.Main`. **No title selection rule here** — the name is passed in by caller (server). |
| 17 | ReplicatedStorage/Modules/MVP/Phenomenal | Module | 112 | – | – | – | – | no | MVP cutscene: `script.Scene`, Voice/Music/Effect sounds, `script.Text` ScreenGui title, rig has `ExtraLeft Arm`/`ExtraRight Arm` recolored (4-armed → Hakari? or Locust "FourArmed"), Torso PointLight fade. Anim speed 0.923. |
| 18 | ReplicatedStorage/Modules/MVP/Stalemate Collapse | Module | 153 | – | – | – | – | no | Two-rig MVP: `Rig` = winner, `Rig2` = local viewer (or a random other player if viewer is the winner / same Team); SFX/Voice/Music; FOV 40→10 after anim t>5.5; DepthOfField + ColorCorrection; `Vignette` gui with `Flash`; Rig2 Torso Beam + Blood particle; `script.Shadow` decals on Rig2 limbs. Team-aware (`player.Team`). Nanami "Collapse" themed. |
| 19 | ReplicatedStorage/Modules/MVP/Stand Proud | Module | 88 | – | – | – | – | no | MVP cutscene: `script.Meteor` scene, SFX + Voice, at 3.533 s swaps BG for Meteor (Beam/Beam2/Beam3, Sparks.Hit 200, Meteor.Dust 75, Camera.Torso.Flames), ColorCorrection + DepthOfField. Gojo themed. |
| 20 | ReplicatedStorage/Modules/MVP/True Value | Module | 82 | – | – | – | – | no | MVP cutscene: `script.Scene` with `Cam` (AnimationController) + `Rig`; `script.User`/`script.Cam` anims; `script.Slash` ScreenGui (Clip tween, Cut/Deep frames) at keyframe "Cut" −0.14 s; FOV 17; rig slides −10 studs over 4.5 s. Yuta/Nanami slash themed. |
| 21 | ReplicatedStorage/Modules/MVP/Watch Your Head | Module | 135 | – | – | – | – | no | Two-rig MVP like Stalemate Collapse (winner + viewer/random victim); FOV 80→60→80 punch, `BurstCC` ColorCorrection + `BurstBlur`, `Dust.Glass`/`Dust.Sparks` 200, Vignette gui. Hiromi/Reggie? (decapitation joke) |
| 22 | ReplicatedStorage/Modules/RobloxChatVoice | Module | 226 | – | – | – | – | no | Map of 36 **catalog/decal asset ids → {Sound id, Volume, CD, Name}**: chat-triggered voice clips (e.g. 7948969023→7147847068 "yowai mo", 100445971002729→96682343073262 "stand proud"). Full list in §8.4. |
| 23 | ReplicatedStorage/Modules/Rules | Module | 31 | – | – | – | – | no | `Version 3`, 17 rules, 1 agreement string. Rules reference Ranked, Roulette, workshop content, billboards, "supporter streams". |
| 24 | Settings/Audio/Background Music | Module | 18 | – | – | – | – | no | Slider `VolMS2` max 2 → `SoundService.Music2.Volume`. |
| 25 | Settings/Audio/Custom Death Sound | Module | 15 | – | – | – | – | no | Btn 2 (text/id input) `Deathsound`; **Gamepass 718699461**. |
| 26 | Settings/Audio/Custom Kill Sound | Module | 15 | – | – | – | – | no | Btn 2 `Killsound`; **Gamepass 718699461**. |
| 27 | Settings/Audio/Custom Sounds | Module | 14 | – | – | – | – | no | Toggle `VolKS` "Toggle global player custom sounds". |
| 28 | Settings/Audio/Effect | Module | 18 | – | – | – | – | no | Slider `VolFX` → `SoundService.Effect.Volume`. |
| 29 | Settings/Audio/Music | Module | 18 | – | – | – | – | no | Slider `VolMS` → `SoundService.Music.Volume`. |
| 30 | Settings/Audio/TTS | Module | 51 | – | – | (via TextToZee) | – | no | Toggle `TTS`: hooks `TextChatService.OnBubbleAdded` → `TextToZee.TTS(text, character.PrimaryPart, {Pitch=1,Speed=1,Accent=1,Voice="TTZ"})`. Reads character attribute `Pitch` (unused). |
| 31 | Settings/Audio/TTS/TextToZee | Module | 105 | – | – | `ReplicatedStorage.Remotes.TTS:InvokeServer(text, accent)` → returns word list of {syllable, pitchMult} | – | no | Server phonemizes; client plays `script.Voices.<Voice>.<syllable>` sounds (SoundGroup Voice) with PitchShift, stress digits 0/1/2 alter vol/speed/pitch; punctuation pauses .05/.5/.7 s. |
| 32 | Settings/Audio/Taunt | Module | 18 | – | – | – | – | no | Slider `VolTA` → `SoundService.Taunt.Volume`. |
| 33 | Settings/Audio/Voice | Module | 18 | – | – | – | – | no | Slider `VolVA` → `SoundService.Voice.Volume`. |
| 34 | Settings/Controls/Auto Run | Module | 14 | – | – | – | – | no | Toggle `AutoRun`. |
| 35 | Settings/Controls/Auto Use | Module | 17 | – | ToolController | – | – | no | Toggle `AutoUse` "Automatically use skills when pressing keys"; callback clears `ToolController.Selected.Value`. |
| 36 | Settings/Controls/Keybinds | Module | 338 | – | JoinService, ToolController | `JoinService.MobileLayout:Fire(bindTable, true)` — bindTable = {ActionName = {K={key,modifier?}, G={btn,modifier?}}} only for bindings changed from default | – | no | Rebind UI over `ReplicatedStorage.Keybind` (InputAction/InputBinding, children named Keyboard/Gamepad); default stored as attribute `D`; supports modifier+key (2-key chord); sets player attribute `Adjusting_Keybinds`; calls `Modules.KeybindIcons:updateAll()`. Uses `ToolController.LastInput` ("Mobile"/"Xbox"/"Playstation"/"Keyboard"). |
| 37 | Settings/Controls/Menu Scale | Module | 26 | – | – | – | – | no | Slider `UIS2` max 2 → UIScale of `Menus`, `Roulette`, `Ranked` guis (clamp .2–2). |
| 38 | Settings/Controls/Sensitivity | Module | 18 | – | – | – | – | no | Slider `SENS` max 10 → `UserInputService.MouseDeltaSensitivity`. |
| 39 | Settings/Controls/Toolbar Offset | Module | 18 | – | – | – | – | no | Slider `TBO` max 2 → `Main.Controls.Position = UDim2(v/2,0,0,0)`. |
| 40 | Settings/Controls/UI Scale | Module | 28 | – | – | – | – | no | Slider `UIS` max 2 → UIScale of `Main`, `Controls.Gamepad`, `Emotes`, `Miracles` (Mechamaru), `Adaptation` (Mahoraga) guis. |
| 41 | Settings/Fun/Bloodbath | Module | 26 | – | – | – | – | no | Toggle (no Val → local-only) → `BloodyZee.PermBlood`; off destroys `workspace.Effects.Blood` Pools. |
| 42 | Settings/Fun/Bloom | Module | 26 | – | – | – | – | no | Toggle → clones `ReplicatedStorage.Utils.Misc.FunBlm` into Lighting. |
| 43 | Settings/Fun/Cherry | Module | 41 | – | – | – | – | no | Toggle → `Utils.Misc.Rain` with `Blossom` emitter + `BlossomCC` in Lighting, follows camera +30 Y. |
| 44 | Settings/Fun/Darkness | Module | 54 | – | – | – | – | no | Toggle "OLED": mutually exclusive with Goodnight/Sunset/Jolly via `_G.LocalSettings.X=false; _G.SettingUpdate.X:Fire()`; tweens Lighting ClockTime 0, Ambient/OutdoorAmbient/FogColor black, FogEnd 50, Brightness 0; restore from `Lighting.Config` attributes. |
| 45 | Settings/Fun/Goodnight | Module | 47 | – | – | – | – | no | Night: ClockTime 0, OutdoorAmbient (40,50,75), EnvDiffuse 0. Excl. with Sunset/Darkness. |
| 46 | Settings/Fun/Gravity | Module | 28 | – | – | – | – | no | RenderStepped camera roll π (upside-down). |
| 47 | Settings/Fun/Headcam | Module | 67 | – | – | – | – | no | First-person head cam FOV 90; hides head/hat accessories; mouse-X rotates HRP when char attrs `Ragdoll<=0` and not `Stun`/`Emote` and Humanoid.AutoRotate; pitch clamp ±90. Reads character attributes **Ragdoll, Stun, Emote**. |
| 48 | Settings/Fun/Invert | Module | 26 | – | – | – | – | no | ColorCorrection Saturation −2 named `InvertCC`. |
| 49 | Settings/Fun/Jolly | Module | 49 | – | – | – | – | no | Snow via `Utils.Misc.Rain.Snow`, FogEnd 500, velocity-compensated follow. Excl. with Darkness. |
| 50 | Settings/Fun/Rain | Module | 62 | – | – | – | – | no | Rain emitter follows camera +10 Y; raycast up 40 vs `workspace.Map` → indoors mutes rain & enables `RainSFX.Muffle`; random ground splash raycasts. |
| 51 | Settings/Fun/Sunset | Module | 45 | – | – | – | – | no | ClockTime 17.7, Ambient (172,109,33), OutdoorAmbient (255,163,87), FogColor (84,0,0). Excl. with Goodnight/Darkness. |
| 52 | Settings/General/Awakening Outfit | Module | 87 | – | JoinService, FXController | `JoinService.Setting:Fire("Outfit", outfitId or nil)` | – | no | Btn 4 `Outfit`; **Gamepass 857428668**; lists `AvatarEditorService:GetOutfits(Created)` thumbnails `rbxthumb://type=Outfit&id=…&w=150&h=150`; selected = `_G.Settings.Outfit`; click sound `Sounds.Misc.UI.Click` via `FXController:PlaySound`. |
| 53 | Settings/General/Blood | Module | 14 | – | – | – | – | no | Toggle `Gore` "Toggles blood visibily or recolors it" (read by BloodyZee as `_G.Settings.Gore`). |
| 54 | Settings/General/Camera Follow | Module | 14 | – | – | – | – | no | Toggle `Follow`. |
| 55 | Settings/General/Flashing Lights | Module | 14 | – | – | – | – | no | Toggle `Flash` "Reduces flashing lights and impact frames". |
| 56 | Settings/General/Game Info | Module | 17 | – | – | – | – | no | Button "Info" → `_G.TutorialIcon:select()` (TopbarPlus icon). |
| 57 | Settings/General/Hide Kills/FormatNumber | Module | 22 | – | – | – | – | no | `Format(n)` adds thousands commas. |
| 58 | Settings/General/Hide Kills | Module | 46 | – | – | – | – | no | Toggle `HiddenKills`; client-side: for every player, moves `leaderstats.Kills` into a `Hidden` folder when `leaderstats:GetAttribute("HiddenKills")` (server sets attribute). |
| 59 | Settings/General/Screen Shake | Module | 14 | – | – | – | – | no | Toggle `ScreenShake`. |
| 60 | Settings/General/Server Region | Module | 33 | – | – | – | – | no | Toggle `Region` → TopbarPlus `Icon` (Modules.Icon) label from `workspace:GetAttribute("ServerRegion")`. |
| 61 | Settings/Performance/Destruction I | Module | 14 | – | – | – | – | no | Toggle `DesINT` "Interpolates the movement of destroyed parts". |
| 62 | Settings/Performance/Destruction S | Module | 14 | – | – | – | – | no | Toggle `DesVFX` destruction smoke. |
| 63 | Settings/Performance/FPS Counter | Module | 35 | – | – | – | – | no | Toggle `FPS` → `Main.FPS` label, RenderStepped ceil(1/dt). |
| 64 | Settings/Performance/Physics VFX | Module | 14 | – | – | – | – | no | Toggle `DesPHY` "physics heavy effects" (the `_G.Settings.DesPHY` gate seen in controllers). |
| 65 | Settings/Performance/Ragdoll SFX | Module | 14 | – | – | – | – | no | Toggle `RagSFX` limb-collision audio. |
| 66 | Settings/Performance/Shadows | Module | 17 | – | – | – | – | no | Toggle `Shadows` → `Lighting.GlobalShadows`. |
| 67 | ReplicatedStorage/Modules/SimplePath | Module | 355 | – | – | – | – | no | Stock SimplePath (grilme99/V3N0M) pathfinding wrapper: `new(agent, agentParams, settings)`, `Run(target)`, `Stop`, `Destroy`, events Reached/WaypointReached/Blocked/Error/Stopped, `Visualize`. Unmodified. Client copy likely for summons (Mahoraga/Takada/Rika?). |
| 68 | ReplicatedStorage/Modules/SkillDefault | Module | 1288 | – | – | – | – | no | Custom-move node editor schema: `LineItems` (node types → param rows) and `defaultProp`. See §8.1. Default SFX id 12222253. |
| 69 | ReplicatedStorage/Modules/SraikoVFX | Module | 557 | – | – | – | – | no | VFX lib: `Enabled`, `Emit(template, cfOrPart, weld?, life=5, c0)`, `EmitMesh`, `TweenMesh` (Start/End model pairs w/ attributes RepeatCount, RepeatDelay, Decal_/Mesh_/Part_TweenParams, Duration/Lifetime/EffectDuration, StartTransparency, Decal_StartTransparency; optional speed NumberValue for slow-mo), `HandleMesh`, `HandleVFXFromString(script, assetsFolder, originCFrame, callbacks, cleanupList)` — text timeline "`0.5s Name Emit|EmitAll|Enable|EnableAll|Mesh [Classes,] [Weld]`". Emits into `workspace.Effects`. Third-party (Sraiko) but adapted (speed value, cleanup list). |
| 70 | ReplicatedStorage/Modules/StaticLightning | Module | 96 | – | – | – | – | no | `CreateBolt{Position1,Position2,PartCount=10,CurveCenter,MinRadius=1,MaxRadius=2,PartPool,Color,Parent,Thickness=.2|fn}` returns neon BoltPart list via `BulkMoveTo`; `ThicknessFade(a,b,style,dir)`. Game-specific helper. |
| 71 | ReplicatedStorage/Modules/StyleAura/LocalMusic | LocalScript | 35 | – | – | – | – | no | Cloned into character by StyleAura: re-clones `HRP.StyleMusic` locally, destroys it when `StyleAura` model leaves. |
| 72 | ReplicatedStorage/Modules/StyleAura | Module | 83 | – | – | – | – | no | `StyleAura(player, character, animTrack, cleanupList, musicSound, color?)` toggle: default color (74,116,255); `Assets.StyleAura` model welded to Torso with color→0.2*color particle gradient; `Assets.Stance` SFX; `Assets.Smoke` burst on each limb; after 0.35 s if anim still playing, plays `StyleMusic` (SoundGroup Music) + inserts LocalMusic. Attribute `Color` on aura model. (Taunt/style stance system.) |
| 73 | ReplicatedStorage/Modules/TekrinnDialogue | Module | 173 | – | – | – | – | no | `Speak(player, segments)` — per-letter animated dialogue GUI `script.KJDialogue` (name `<Player>KJUI`, CollectionService tag **`KJUI`**), segments {Text, Bold, Italic, Color(ColorSequence), TextStrokeColor, Shake{Enabled,Intensity,Lifetime}, TypeSpeed}; auto-retires after 5 s. |
| 74 | ReplicatedStorage/Modules/UltNames | Module | 172 | – | – | – | – | no | Awakening/ult display names + 2 colors + bool per character (see §4.8). Includes non-roster **Mokou** ("Immortal Blaze") and **Chara** ("SINCE WHEN WERE YOU THE ONE IN CONTROL?") — crossover/event/unreleased. Read by DomainController. |

### A.9 Third-party / stock libraries (243) — verdict per file, dupe groups marked

Byte-identical dupe groups (body only, header stripped):
- **A** `comm@1.0.1/Signal` ≡ `component@2.4.8/Signal` ≡ `input@2.3.0/Signal` (`return require(script.Parent.Parent["sleitnick_signal@2.0.1"].signal)`)
- **B** `comm@1.0.1/Promise` ≡ `component@2.4.8/Promise` (→ `evaera_promise@4.0.0`)
- **C** `component@2.4.8/Trove` ≡ `input@2.3.0/Trove` (→ `sleitnick_trove@1.1.0`)
- **D** `streamable@1.2.4/Signal` ≡ `timer@1.1.2/Signal` (→ **missing** `sleitnick_signal@1.5.0`)
- The 13 top-level `ReplicatedStorage/Knit/<Name>` files and the `comm/Option`, `component/Symbol`, `streamable/Trove` files are also 1-line re-exports but each targets a different package (not byte-identical).

| # | filename | Path | Lines | verdict | note |
|---|---|---|---|---|---|
| 1 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_B_ModuleScript_BaseCamera.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/BaseCamera | 547 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 2 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_B_ModuleScript_BaseOcclusion.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/BaseOcclusion | 28 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 3 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_C_ModuleScript_CameraInput.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/CameraInput | 426 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 4 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_C_ModuleScript_CameraUI.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/CameraUI | 28 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 5 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_C_ModuleScript_CameraUtils.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/CameraUtils | 235 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 6 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_C_ModuleScript_ClassicCamera.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/ClassicCamera | 175 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 7 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_I_ModuleScript_Invisicam.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/Invisicam | 475 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 8 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_L_ModuleScript_LegacyCamera.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/LegacyCamera | 84 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 9 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_O_ModuleScript_OrbitalCamera.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/OrbitalCamera | 267 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 10 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_P_ModuleScript_Poppercam.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/Poppercam | 81 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 11 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_T_ModuleScript_TransparencyController.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/TransparencyController | 199 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 12 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_V_ModuleScript_VRCamera.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/VRCamera | 298 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 13 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_V_ModuleScript_VRVehicleCamera.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/VRVehicleCamera | 354 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 14 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_V_ModuleScript_VehicleCamera.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/VehicleCamera | 154 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 15 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_V_ModuleScript_VehicleCameraConfig.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/VehicleCamera/VehicleCameraConfig | 20 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 16 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_V_ModuleScript_VehicleCameraCore.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/VehicleCamera/VehicleCameraCore | 143 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 17 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_Z_ModuleScript_Popper.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/ZoomController/Popper | 436 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 18 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CameraModule_Z_ModuleScript_ZoomController.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule/ZoomController | 100 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 19 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CommonUtils_Ca_ModuleScript_CameraWrapper.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CommonUtils/CameraWrapper | 60 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 20 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CommonUtils_Ch_ModuleScript_CharacterUtil.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CommonUtils/CharacterUtil | 88 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 21 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CommonUtils_Co_ModuleScript_ConnectionUtil.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CommonUtils/ConnectionUtil | 37 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 22 | `Players_SmartzyMan_PlayerScripts_PlayerModule_CommonUtils_Fl_ModuleScript_FlagUtil.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/CommonUtils/FlagUtil | 9 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 23 | `Players_SmartzyMan_PlayerScripts_PlayerModule_ControlModule__ModuleScript_AvatarAbilitiesInterface.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/ControlModule/AvatarAbilitiesInterface | 65 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 24 | `Players_SmartzyMan_PlayerScripts_PlayerModule_ControlModule__ModuleScript_BaseCharacterController.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/ControlModule/BaseCharacterController | 30 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 25 | `Players_SmartzyMan_PlayerScripts_PlayerModule_ControlModule__ModuleScript_Gamepad.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/ControlModule/Gamepad | 162 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 26 | `Players_SmartzyMan_PlayerScripts_PlayerModule_ControlModule__ModuleScript_Keyboard.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/ControlModule/Keyboard | 133 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 27 | `Players_SmartzyMan_PlayerScripts_PlayerModule_ControlModule__ModuleScript_VRNavigation.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/ControlModule/VRNavigation | 426 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 28 | `Players_SmartzyMan_PlayerScripts_PlayerModule_ControlModule__ModuleScript_VehicleController.lua` | Players/SmartzyMan/PlayerScripts/PlayerModule/ControlModule/VehicleController | 131 | stock | Roblox PlayerModule (2025); no game identifiers/remotes/_G/attributes found |
| 29 | `ReplicatedStorage_CmdrClient_CmdrInterface_AutoComplete_ModuleScript_AutoComplete.lua` | ReplicatedStorage/CmdrClient/CmdrInterface/AutoComplete | 165 | stock | Cmdr v1.12.0 client/shared |
| 30 | `ReplicatedStorage_CmdrClient_CmdrInterface_ModuleScript_CmdrInterface.lua` | ReplicatedStorage/CmdrClient/CmdrInterface | 149 | stock | Cmdr v1.12.0 client/shared |
| 31 | `ReplicatedStorage_CmdrClient_CmdrInterface_Window_ModuleScript_Window.lua` | ReplicatedStorage/CmdrClient/CmdrInterface/Window | 273 | stock | v1.12 window; disables TextChatService window while open; mash-to-enable logic |
| 32 | `ReplicatedStorage_CmdrClient_Commands_Announce_ModuleScript_Announce.lua` | ReplicatedStorage/CmdrClient/Commands/Announce | 31 | game-specific | admin command definition (client copy) - see section 3 |
| 33 | `ReplicatedStorage_CmdrClient_Commands_BanReason_ModuleScript_BanReason.lua` | ReplicatedStorage/CmdrClient/Commands/BanReason | 18 | game-specific | admin command definition (client copy) - see section 3 |
| 34 | `ReplicatedStorage_CmdrClient_Commands_Ban_ModuleScript_Ban.lua` | ReplicatedStorage/CmdrClient/Commands/Ban | 33 | game-specific | admin command definition (client copy) - see section 3 |
| 35 | `ReplicatedStorage_CmdrClient_Commands_BlacklistClear_ModuleScript_BlacklistClear.lua` | ReplicatedStorage/CmdrClient/Commands/BlacklistClear | 13 | game-specific | admin command definition (client copy) - see section 3 |
| 36 | `ReplicatedStorage_CmdrClient_Commands_Blacklist_ModuleScript_Blacklist.lua` | ReplicatedStorage/CmdrClient/Commands/Blacklist | 13 | game-specific | admin command definition (client copy) - see section 3 |
| 37 | `ReplicatedStorage_CmdrClient_Commands_BuildWorkshop_ModuleScript_BuildWorkshop.lua` | ReplicatedStorage/CmdrClient/Commands/BuildWorkshop | 18 | game-specific | admin command definition (client copy) - see section 3 |
| 38 | `ReplicatedStorage_CmdrClient_Commands_Build_ModuleScript_Build.lua` | ReplicatedStorage/CmdrClient/Commands/Build | 27 | game-specific | admin command definition (client copy) - see section 3 |
| 39 | `ReplicatedStorage_CmdrClient_Commands_Cash_ModuleScript_Cash.lua` | ReplicatedStorage/CmdrClient/Commands/Cash | 17 | game-specific | admin command definition (client copy) - see section 3 |
| 40 | `ReplicatedStorage_CmdrClient_Commands_CheckBlacklist_ModuleScript_CheckBlacklist.lua` | ReplicatedStorage/CmdrClient/Commands/CheckBlacklist | 13 | game-specific | admin command definition (client copy) - see section 3 |
| 41 | `ReplicatedStorage_CmdrClient_Commands_ClearSlot_ModuleScript_ClearSlot.lua` | ReplicatedStorage/CmdrClient/Commands/ClearSlot | 22 | game-specific | admin command definition (client copy) - see section 3 |
| 42 | `ReplicatedStorage_CmdrClient_Commands_Code_ModuleScript_Code.lua` | ReplicatedStorage/CmdrClient/Commands/Code | 21 | game-specific | admin command definition (client copy) - see section 3 |
| 43 | `ReplicatedStorage_CmdrClient_Commands_CustomMoveset_ModuleScript_CustomMoveset.lua` | ReplicatedStorage/CmdrClient/Commands/CustomMoveset | 32 | game-specific | admin command definition (client copy) - see section 3 |
| 44 | `ReplicatedStorage_CmdrClient_Commands_Data_ModuleScript_Data.lua` | ReplicatedStorage/CmdrClient/Commands/Data | 23 | game-specific | admin command definition (client copy) - see section 3 |
| 45 | `ReplicatedStorage_CmdrClient_Commands_Disguise_ModuleScript_Disguise.lua` | ReplicatedStorage/CmdrClient/Commands/Disguise | 24 | game-specific | admin command definition (client copy) - see section 3 |
| 46 | `ReplicatedStorage_CmdrClient_Commands_EmoteToken_ModuleScript_EmoteToken.lua` | ReplicatedStorage/CmdrClient/Commands/EmoteToken | 13 | game-specific | admin command definition (client copy) - see section 3 |
| 47 | `ReplicatedStorage_CmdrClient_Commands_Emote_ModuleScript_Emote.lua` | ReplicatedStorage/CmdrClient/Commands/Emote | 21 | game-specific | admin command definition (client copy) - see section 3 |
| 48 | `ReplicatedStorage_CmdrClient_Commands_EndCreate_ModuleScript_EndCreate.lua` | ReplicatedStorage/CmdrClient/Commands/EndCreate | 18 | game-specific | admin command definition (client copy) - see section 3 |
| 49 | `ReplicatedStorage_CmdrClient_Commands_ErrorLogs_ModuleScript_ErrorLogs.lua` | ReplicatedStorage/CmdrClient/Commands/ErrorLogs | 15 | game-specific | admin command definition (client copy) - see section 3 |
| 50 | `ReplicatedStorage_CmdrClient_Commands_Gamepass_ModuleScript_Gamepass.lua` | ReplicatedStorage/CmdrClient/Commands/Gamepass | 17 | game-specific | admin command definition (client copy) - see section 3 |
| 51 | `ReplicatedStorage_CmdrClient_Commands_Hitbox_ModuleScript_Hitbox.lua` | ReplicatedStorage/CmdrClient/Commands/Hitbox | 20 | game-specific | admin command definition (client copy) - see section 3 |
| 52 | `ReplicatedStorage_CmdrClient_Commands_Item_ModuleScript_Item.lua` | ReplicatedStorage/CmdrClient/Commands/Item | 42 | game-specific | admin command definition (client copy) - see section 3 |
| 53 | `ReplicatedStorage_CmdrClient_Commands_JoinCreate_ModuleScript_JoinCreate.lua` | ReplicatedStorage/CmdrClient/Commands/JoinCreate | 18 | game-specific | admin command definition (client copy) - see section 3 |
| 54 | `ReplicatedStorage_CmdrClient_Commands_Join_ModuleScript_Join.lua` | ReplicatedStorage/CmdrClient/Commands/Join | 24 | game-specific | admin command definition (client copy) - see section 3 |
| 55 | `ReplicatedStorage_CmdrClient_Commands_Kick_ModuleScript_Kick.lua` | ReplicatedStorage/CmdrClient/Commands/Kick | 23 | game-specific | admin command definition (client copy) - see section 3 |
| 56 | `ReplicatedStorage_CmdrClient_Commands_Kills_ModuleScript_Kills.lua` | ReplicatedStorage/CmdrClient/Commands/Kills | 17 | game-specific | admin command definition (client copy) - see section 3 |
| 57 | `ReplicatedStorage_CmdrClient_Commands_LoadHistory_ModuleScript_LoadHistory.lua` | ReplicatedStorage/CmdrClient/Commands/LoadHistory | 25 | game-specific | admin command definition (client copy) - see section 3 |
| 58 | `ReplicatedStorage_CmdrClient_Commands_LocateBlacklist_ModuleScript_LocateBlacklist.lua` | ReplicatedStorage/CmdrClient/Commands/LocateBlacklist | 18 | game-specific | admin command definition (client copy) - see section 3 |
| 59 | `ReplicatedStorage_CmdrClient_Commands_MapSong_ModuleScript_MapSong.lua` | ReplicatedStorage/CmdrClient/Commands/MapSong | 15 | game-specific | admin command definition (client copy) - see section 3 |
| 60 | `ReplicatedStorage_CmdrClient_Commands_Mokou_ModuleScript_Mokou.lua` | ReplicatedStorage/CmdrClient/Commands/Mokou | 17 | game-specific | admin command definition (client copy) - see section 3 |
| 61 | `ReplicatedStorage_CmdrClient_Commands_Moveset_ModuleScript_Moveset.lua` | ReplicatedStorage/CmdrClient/Commands/Moveset | 25 | game-specific | admin command definition (client copy) - see section 3 |
| 62 | `ReplicatedStorage_CmdrClient_Commands_Overpower_ModuleScript_Overpower.lua` | ReplicatedStorage/CmdrClient/Commands/Overpower | 15 | game-specific | admin command definition (client copy) - see section 3 |
| 63 | `ReplicatedStorage_CmdrClient_Commands_PickRoulette_ModuleScript_PickRoulette.lua` | ReplicatedStorage/CmdrClient/Commands/PickRoulette | 13 | game-specific | admin command definition (client copy) - see section 3 |
| 64 | `ReplicatedStorage_CmdrClient_Commands_Ping_ModuleScript_Ping.lua` | ReplicatedStorage/CmdrClient/Commands/Ping | 19 | game-specific | admin command definition (client copy) - see section 3 |
| 65 | `ReplicatedStorage_CmdrClient_Commands_ResetQuests_ModuleScript_ResetQuests.lua` | ReplicatedStorage/CmdrClient/Commands/ResetQuests | 19 | game-specific | admin command definition (client copy) - see section 3 |
| 66 | `ReplicatedStorage_CmdrClient_Commands_Restart_ModuleScript_Restart.lua` | ReplicatedStorage/CmdrClient/Commands/Restart | 13 | game-specific | admin command definition (client copy) - see section 3 |
| 67 | `ReplicatedStorage_CmdrClient_Commands_Rollback_ModuleScript_Rollback.lua` | ReplicatedStorage/CmdrClient/Commands/Rollback | 26 | game-specific | admin command definition (client copy) - see section 3 |
| 68 | `ReplicatedStorage_CmdrClient_Commands_Scale_ModuleScript_Scale.lua` | ReplicatedStorage/CmdrClient/Commands/Scale | 23 | game-specific | admin command definition (client copy) - see section 3 |
| 69 | `ReplicatedStorage_CmdrClient_Commands_SecretTest_ModuleScript_SecretTest.lua` | ReplicatedStorage/CmdrClient/Commands/SecretTest | 13 | game-specific | admin command definition (client copy) - see section 3 |
| 70 | `ReplicatedStorage_CmdrClient_Commands_Title_ModuleScript_Title.lua` | ReplicatedStorage/CmdrClient/Commands/Title | 21 | game-specific | admin command definition (client copy) - see section 3 |
| 71 | `ReplicatedStorage_CmdrClient_Commands_Unban_ModuleScript_Unban.lua` | ReplicatedStorage/CmdrClient/Commands/Unban | 19 | game-specific | admin command definition (client copy) - see section 3 |
| 72 | `ReplicatedStorage_CmdrClient_Commands_VersionList_ModuleScript_VersionList.lua` | ReplicatedStorage/CmdrClient/Commands/VersionList | 22 | game-specific | admin command definition (client copy) - see section 3 |
| 73 | `ReplicatedStorage_CmdrClient_Commands_Watch_ModuleScript_Watch.lua` | ReplicatedStorage/CmdrClient/Commands/Watch | 35 | game-specific | ClientRun only: sets CurrentCamera.CameraSubject to target Humanoid (spectate) |
| 74 | `ReplicatedStorage_CmdrClient_Commands_WaveCheck_ModuleScript_WaveCheck.lua` | ReplicatedStorage/CmdrClient/Commands/WaveCheck | 18 | game-specific | admin command definition (client copy) - see section 3 |
| 75 | `ReplicatedStorage_CmdrClient_Commands_customWhitelist_ModuleScript_customWhitelist.lua` | ReplicatedStorage/CmdrClient/Commands/customWhitelist | 23 | game-specific | admin command definition (client copy) - see section 3 |
| 76 | `ReplicatedStorage_CmdrClient_DefaultEventHandlers_ModuleScript_DefaultEventHandlers.lua` | ReplicatedStorage/CmdrClient/DefaultEventHandlers | 16 | stock | "Message" -> ChatMakeSystemMessage "[Announcement] ..."; "AddLine" |
| 77 | `ReplicatedStorage_CmdrClient_ModuleScript_CmdrClient.lua` | ReplicatedStorage/CmdrClient | 102 | stock | Cmdr client root; F2 activation; remotes CmdrFunction/CmdrEvent; registers Types+Commands folders |
| 78 | `ReplicatedStorage_CmdrClient_Shared_Argument_ModuleScript_Argument.lua` | ReplicatedStorage/CmdrClient/Shared/Argument | 212 | stock | Cmdr v1.12.0 client/shared |
| 79 | `ReplicatedStorage_CmdrClient_Shared_Command_ModuleScript_Command.lua` | ReplicatedStorage/CmdrClient/Shared/Command | 191 | stock | SendEvent -> RemoteEvent:FireClient (server side) |
| 80 | `ReplicatedStorage_CmdrClient_Shared_Dispatcher_ModuleScript_Dispatcher.lua` | ReplicatedStorage/CmdrClient/Shared/Dispatcher | 135 | stock | Dispatcher:Send -> RemoteFunction:InvokeServer(text,{Data=...}); runs BeforeRun/AfterRun hooks |
| 81 | `ReplicatedStorage_CmdrClient_Shared_Registry_ModuleScript_Registry.lua` | ReplicatedStorage/CmdrClient/Shared/Registry | 266 | stock | Cmdr v1.12.0 client/shared |
| 82 | `ReplicatedStorage_CmdrClient_Shared_Util_ModuleScript_Util.lua` | ReplicatedStorage/CmdrClient/Shared/Util | 472 | stock | Cmdr v1.12.0 client/shared |
| 83 | `ReplicatedStorage_CmdrClient_Types_BindableResource_ModuleScript_BindableResource.lua` | ReplicatedStorage/CmdrClient/Types/BindableResource | 3 | stock | Cmdr built-in type |
| 84 | `ReplicatedStorage_CmdrClient_Types_BrickColor_ModuleScript_BrickColor.lua` | ReplicatedStorage/CmdrClient/Types/BrickColor | 253 | stock | Cmdr built-in type |
| 85 | `ReplicatedStorage_CmdrClient_Types_Characters_ModuleScript_Characters.lua` | ReplicatedStorage/CmdrClient/Types/Characters | 22 | game-specific | type "character": autocomplete from ReplicatedStorage.Modules.ListData.Characters, only when PlaceId==9164905432 |
| 86 | `ReplicatedStorage_CmdrClient_Types_Color3_ModuleScript_Color3.lua` | ReplicatedStorage/CmdrClient/Types/Color3 | 55 | stock | Cmdr built-in type |
| 87 | `ReplicatedStorage_CmdrClient_Types_Command_ModuleScript_Command.lua` | ReplicatedStorage/CmdrClient/Types/Command | 21 | stock | Cmdr built-in type |
| 88 | `ReplicatedStorage_CmdrClient_Types_ConditionFunction_ModuleScript_ConditionFunction.lua` | ReplicatedStorage/CmdrClient/Types/ConditionFunction | 3 | stock | Cmdr built-in type |
| 89 | `ReplicatedStorage_CmdrClient_Types_Duration_ModuleScript_Duration.lua` | ReplicatedStorage/CmdrClient/Types/Duration | 98 | stock | Cmdr built-in type |
| 90 | `ReplicatedStorage_CmdrClient_Types_Gamemodes_ModuleScript_Gamemodes.lua` | ReplicatedStorage/CmdrClient/Types/Gamemodes | 25 | game-specific | type "gamemode": enum Creator/Final/Parade/Roulette |
| 91 | `ReplicatedStorage_CmdrClient_Types_Items_ModuleScript_Items.lua` | ReplicatedStorage/CmdrClient/Types/Items | 20 | game-specific | type "item": autocomplete from ListData.Items |
| 92 | `ReplicatedStorage_CmdrClient_Types_JSON_ModuleScript_JSON.lua` | ReplicatedStorage/CmdrClient/Types/JSON | 14 | stock | Cmdr built-in type |
| 93 | `ReplicatedStorage_CmdrClient_Types_MathOperator_ModuleScript_MathOperator.lua` | ReplicatedStorage/CmdrClient/Types/MathOperator | 46 | stock | Cmdr built-in type |
| 94 | `ReplicatedStorage_CmdrClient_Types_Permissions_ModuleScript_Permissions.lua` | ReplicatedStorage/CmdrClient/Types/Permissions | 57 | game-specific | BeforeRun hook: group-role permission check; sets _G.GroupId=16357742; Youtuber/AllowCustomMoveset attributes; PlaceId 9164905432 gate for Tester |
| 95 | `ReplicatedStorage_CmdrClient_Types_PlayerId_ModuleScript_PlayerId.lua` | ReplicatedStorage/CmdrClient/Types/PlayerId | 72 | stock | Cmdr built-in type |
| 96 | `ReplicatedStorage_CmdrClient_Types_Player_ModuleScript_Player.lua` | ReplicatedStorage/CmdrClient/Types/Player | 34 | stock | Cmdr built-in type |
| 97 | `ReplicatedStorage_CmdrClient_Types_Primitives_ModuleScript_Primitives.lua` | ReplicatedStorage/CmdrClient/Types/Primitives | 165 | stock | Cmdr built-in type |
| 98 | `ReplicatedStorage_CmdrClient_Types_Reasons_ModuleScript_Reasons.lua` | ReplicatedStorage/CmdrClient/Types/Reasons | 20 | game-specific | type "reason": enum {"Exploiting"} |
| 99 | `ReplicatedStorage_CmdrClient_Types_StoredKey_ModuleScript_StoredKey.lua` | ReplicatedStorage/CmdrClient/Types/StoredKey | 30 | stock | Cmdr built-in type |
| 100 | `ReplicatedStorage_CmdrClient_Types_Team_ModuleScript_Team.lua` | ReplicatedStorage/CmdrClient/Types/Team | 47 | stock | Cmdr built-in type |
| 101 | `ReplicatedStorage_CmdrClient_Types_Type_ModuleScript_Type.lua` | ReplicatedStorage/CmdrClient/Types/Type | 21 | stock | Cmdr built-in type |
| 102 | `ReplicatedStorage_CmdrClient_Types_URL_ModuleScript_URL.lua` | ReplicatedStorage/CmdrClient/Types/URL | 18 | stock | Cmdr built-in type |
| 103 | `ReplicatedStorage_CmdrClient_Types_UserInput_ModuleScript_UserInput.lua` | ReplicatedStorage/CmdrClient/Types/UserInput | 26 | stock | Cmdr built-in type |
| 104 | `ReplicatedStorage_CmdrClient_Types_Username_ModuleScript_Username.lua` | ReplicatedStorage/CmdrClient/Types/Username | 23 | game-specific | type "username": free string, autocompletes online player names (allows offline targets) |
| 105 | `ReplicatedStorage_CmdrClient_Types_Vector_ModuleScript_Vector.lua` | ReplicatedStorage/CmdrClient/Types/Vector | 33 | stock | Cmdr built-in type |
| 106 | `ReplicatedStorage_Knit_Comm_ModuleScript_Comm.lua` | ReplicatedStorage/Knit/Comm | 1 | stock | 1-line re-export into _Index |
| 107 | `ReplicatedStorage_Knit_Component_ModuleScript_Component.lua` | ReplicatedStorage/Knit/Component | 1 | stock | 1-line re-export into _Index |
| 108 | `ReplicatedStorage_Knit_EnumList_ModuleScript_EnumList.lua` | ReplicatedStorage/Knit/EnumList | 1 | stock | 1-line re-export into _Index |
| 109 | `ReplicatedStorage_Knit_Input_ModuleScript_Input.lua` | ReplicatedStorage/Knit/Input | 1 | stock | 1-line re-export into _Index |
| 110 | `ReplicatedStorage_Knit_Knit_KnitClient_ModuleScript_KnitClient.lua` | ReplicatedStorage/Knit/Knit/KnitClient | 162 | stock | Knit client (1.5.x era): ServicePromises=true, Middleware/PerServiceMiddleware, waits for Knit.Services folder |
| 111 | `ReplicatedStorage_Knit_Knit_ModuleScript_Knit.lua` | ReplicatedStorage/Knit/Knit | 9 | stock | Knit entry; destroys KnitServer on client |
| 112 | `ReplicatedStorage_Knit_Option_ModuleScript_Option.lua` | ReplicatedStorage/Knit/Option | 1 | stock | 1-line re-export into _Index |
| 113 | `ReplicatedStorage_Knit_Promise_ModuleScript_Promise.lua` | ReplicatedStorage/Knit/Promise | 1 | stock | 1-line re-export into _Index |
| 114 | `ReplicatedStorage_Knit_Signal_ModuleScript_Signal.lua` | ReplicatedStorage/Knit/Signal | 1 | stock | 1-line re-export into _Index |
| 115 | `ReplicatedStorage_Knit_Streamable_ModuleScript_Streamable.lua` | ReplicatedStorage/Knit/Streamable | 1 | stock | 1-line re-export into _Index |
| 116 | `ReplicatedStorage_Knit_TableUtil_ModuleScript_TableUtil.lua` | ReplicatedStorage/Knit/TableUtil | 1 | stock | 1-line re-export into _Index |
| 117 | `ReplicatedStorage_Knit_Timer_ModuleScript_Timer.lua` | ReplicatedStorage/Knit/Timer | 1 | stock | 1-line re-export into _Index |
| 118 | `ReplicatedStorage_Knit_Trove_ModuleScript_Trove.lua` | ReplicatedStorage/Knit/Trove | 1 | stock | 1-line re-export into _Index |
| 119 | `ReplicatedStorage_Knit__Index_evaera_promise_4.0.0_promise_ModuleScript_promise.lua` | ReplicatedStorage/Knit/_Index/evaera_promise@4.0.0/promise | 1300 | stock | sleitnick/evaera wally package body |
| 120 | `ReplicatedStorage_Knit__Index_evaera_promise_4.0.0_promise_i_ModuleScript_initspec.lua` | ReplicatedStorage/Knit/_Index/evaera_promise@4.0.0/promise/init.spec | 1604 | stock | TestEZ spec file (dead weight) |
| 121 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_Option_ModuleScript_Option.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/Option | 1 | stock | 1-line re-export |
| 122 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_Promise_ModuleScript_Promise.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/Promise | 1 | stock | 1-line re-export |
| 123 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_Signal_ModuleScript_Signal.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/Signal | 1 | stock | 1-line re-export |
| 124 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_comm_Clie_ModuleScript_Client.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/comm/Client | 140 | stock | sleitnick/evaera wally package body |
| 125 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_comm_Clie_ModuleScript_ClientComm.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/comm/Client/ClientComm | 68 | stock | sleitnick/evaera wally package body |
| 126 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_comm_Clie_ModuleScript_ClientRemoteProperty.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/comm/Client/ClientRemoteProperty | 60 | stock | sleitnick/evaera wally package body |
| 127 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_comm_Clie_ModuleScript_ClientRemoteSignal.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/comm/Client/ClientRemoteSignal | 69 | stock | sleitnick/evaera wally package body |
| 128 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_comm_ModuleScript_comm.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/comm | 6 | stock | sleitnick/evaera wally package body |
| 129 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_comm_Serv_ModuleScript_RemoteProperty.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/comm/Server/RemoteProperty | 108 | stock | sleitnick/evaera wally package body |
| 130 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_comm_Serv_ModuleScript_RemoteSignal.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/comm/Server/RemoteSignal | 103 | stock | sleitnick/evaera wally package body |
| 131 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_comm_Serv_ModuleScript_Server.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/comm/Server | 111 | stock | sleitnick/evaera wally package body |
| 132 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_comm_Serv_ModuleScript_ServerComm.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/comm/Server/ServerComm | 42 | stock | sleitnick/evaera wally package body |
| 133 | `ReplicatedStorage_Knit__Index_sleitnick_comm_1.0.1_comm_Util_ModuleScript_Util.lua` | ReplicatedStorage/Knit/_Index/sleitnick_comm@1.0.1/comm/Util | 24 | stock | sleitnick/evaera wally package body |
| 134 | `ReplicatedStorage_Knit__Index_sleitnick_component_2.4.8_Prom_ModuleScript_Promise.lua` | ReplicatedStorage/Knit/_Index/sleitnick_component@2.4.8/Promise | 1 | stock | dupe of comm@1.0.1/Promise (1-line re-export) |
| 135 | `ReplicatedStorage_Knit__Index_sleitnick_component_2.4.8_Sign_ModuleScript_Signal.lua` | ReplicatedStorage/Knit/_Index/sleitnick_component@2.4.8/Signal | 1 | stock | dupe of comm@1.0.1/Signal (1-line re-export) |
| 136 | `ReplicatedStorage_Knit__Index_sleitnick_component_2.4.8_Symb_ModuleScript_Symbol.lua` | ReplicatedStorage/Knit/_Index/sleitnick_component@2.4.8/Symbol | 1 | stock | 1-line re-export |
| 137 | `ReplicatedStorage_Knit__Index_sleitnick_component_2.4.8_Trov_ModuleScript_Trove.lua` | ReplicatedStorage/Knit/_Index/sleitnick_component@2.4.8/Trove | 1 | stock | 1-line re-export |
| 138 | `ReplicatedStorage_Knit__Index_sleitnick_component_2.4.8_comp_ModuleScript_component.lua` | ReplicatedStorage/Knit/_Index/sleitnick_component@2.4.8/component | 353 | stock | sleitnick/evaera wally package body |
| 139 | `ReplicatedStorage_Knit__Index_sleitnick_component_2.4.8_comp_ModuleScript_initspec.lua` | ReplicatedStorage/Knit/_Index/sleitnick_component@2.4.8/component/init.spec | 372 | stock | TestEZ spec file (dead weight) |
| 140 | `ReplicatedStorage_Knit__Index_sleitnick_enum-list_2.1.0_enum_ModuleScript_enumlist.lua` | ReplicatedStorage/Knit/_Index/sleitnick_enum-list@2.1.0/enum-list | 48 | stock | sleitnick/evaera wally package body |
| 141 | `ReplicatedStorage_Knit__Index_sleitnick_enum-list_2.1.0_enum_ModuleScript_initspec.lua` | ReplicatedStorage/Knit/_Index/sleitnick_enum-list@2.1.0/enum-list/init.spec | 97 | stock | TestEZ spec file (dead weight) |
| 142 | `ReplicatedStorage_Knit__Index_sleitnick_input_2.3.0_Signal_ModuleScript_Signal.lua` | ReplicatedStorage/Knit/_Index/sleitnick_input@2.3.0/Signal | 1 | stock | dupe of comm@1.0.1/Signal (1-line re-export) |
| 143 | `ReplicatedStorage_Knit__Index_sleitnick_input_2.3.0_Trove_ModuleScript_Trove.lua` | ReplicatedStorage/Knit/_Index/sleitnick_input@2.3.0/Trove | 1 | stock | dupe of component@2.4.8/Trove (1-line re-export) |
| 144 | `ReplicatedStorage_Knit__Index_sleitnick_input_2.3.0_input_Ga_ModuleScript_Gamepad.lua` | ReplicatedStorage/Knit/_Index/sleitnick_input@2.3.0/input/Gamepad | 214 | stock | sleitnick/evaera wally package body |
| 145 | `ReplicatedStorage_Knit__Index_sleitnick_input_2.3.0_input_Ke_ModuleScript_Keyboard.lua` | ReplicatedStorage/Knit/_Index/sleitnick_input@2.3.0/input/Keyboard | 52 | stock | sleitnick/evaera wally package body |
| 146 | `ReplicatedStorage_Knit__Index_sleitnick_input_2.3.0_input_Mo_ModuleScript_Mouse.lua` | ReplicatedStorage/Knit/_Index/sleitnick_input@2.3.0/input/Mouse | 106 | stock | sleitnick/evaera wally package body |
| 147 | `ReplicatedStorage_Knit__Index_sleitnick_input_2.3.0_input_ModuleScript_input.lua` | ReplicatedStorage/Knit/_Index/sleitnick_input@2.3.0/input | 7 | stock | sleitnick/evaera wally package body |
| 148 | `ReplicatedStorage_Knit__Index_sleitnick_input_2.3.0_input_Pr_ModuleScript_PreferredInput.lua` | ReplicatedStorage/Knit/_Index/sleitnick_input@2.3.0/input/PreferredInput | 74 | stock | sleitnick/evaera wally package body |
| 149 | `ReplicatedStorage_Knit__Index_sleitnick_input_2.3.0_input_To_ModuleScript_Touch.lua` | ReplicatedStorage/Knit/_Index/sleitnick_input@2.3.0/input/Touch | 30 | stock | sleitnick/evaera wally package body |
| 150 | `ReplicatedStorage_Knit__Index_sleitnick_option_1.0.5_option_ModuleScript_option.lua` | ReplicatedStorage/Knit/_Index/sleitnick_option@1.0.5/option | 185 | stock | sleitnick/evaera wally package body |
| 151 | `ReplicatedStorage_Knit__Index_sleitnick_option_1.0.5_option__ModuleScript_initspec.lua` | ReplicatedStorage/Knit/_Index/sleitnick_option@1.0.5/option/init.spec | 369 | stock | TestEZ spec file (dead weight) |
| 152 | `ReplicatedStorage_Knit__Index_sleitnick_signal_2.0.1_signal_ModuleScript_signal.lua` | ReplicatedStorage/Knit/_Index/sleitnick_signal@2.0.1/signal | 199 | stock | sleitnick/evaera wally package body |
| 153 | `ReplicatedStorage_Knit__Index_sleitnick_signal_2.0.1_signal__ModuleScript_initspec.lua` | ReplicatedStorage/Knit/_Index/sleitnick_signal@2.0.1/signal/init.spec | 201 | stock | TestEZ spec file (dead weight) |
| 154 | `ReplicatedStorage_Knit__Index_sleitnick_streamable_1.2.4_Sig_ModuleScript_Signal.lua` | ReplicatedStorage/Knit/_Index/sleitnick_streamable@1.2.4/Signal | 1 | stock (dangling) | requires _Index["sleitnick_signal@1.5.0"] which is NOT present in _Index (only signal@2.0.1) - Streamable would error if required |
| 155 | `ReplicatedStorage_Knit__Index_sleitnick_streamable_1.2.4_Tro_ModuleScript_Trove.lua` | ReplicatedStorage/Knit/_Index/sleitnick_streamable@1.2.4/Trove | 1 | stock (dangling) | requires _Index["sleitnick_trove@0.4.2"] which is NOT present (only trove@1.1.0) |
| 156 | `ReplicatedStorage_Knit__Index_sleitnick_streamable_1.2.4_str_ModuleScript_StreamableUtil.lua` | ReplicatedStorage/Knit/_Index/sleitnick_streamable@1.2.4/streamable/StreamableUtil | 39 | stock | sleitnick/evaera wally package body |
| 157 | `ReplicatedStorage_Knit__Index_sleitnick_streamable_1.2.4_str_ModuleScript_StreamableUtilspec.lua` | ReplicatedStorage/Knit/_Index/sleitnick_streamable@1.2.4/streamable/StreamableUtil.spec | 63 | stock | TestEZ spec file (dead weight) |
| 158 | `ReplicatedStorage_Knit__Index_sleitnick_streamable_1.2.4_str_ModuleScript_Streamablespec.lua` | ReplicatedStorage/Knit/_Index/sleitnick_streamable@1.2.4/streamable/Streamable.spec | 141 | stock | TestEZ spec file (dead weight) |
| 159 | `ReplicatedStorage_Knit__Index_sleitnick_streamable_1.2.4_str_ModuleScript_streamable.lua` | ReplicatedStorage/Knit/_Index/sleitnick_streamable@1.2.4/streamable/Streamable | 84 | stock | sleitnick/evaera wally package body |
| 160 | `ReplicatedStorage_Knit__Index_sleitnick_symbol_2.0.1_symbol_ModuleScript_symbol.lua` | ReplicatedStorage/Knit/_Index/sleitnick_symbol@2.0.1/symbol | 9 | stock | sleitnick/evaera wally package body |
| 161 | `ReplicatedStorage_Knit__Index_sleitnick_symbol_2.0.1_symbol__ModuleScript_initspec.lua` | ReplicatedStorage/Knit/_Index/sleitnick_symbol@2.0.1/symbol/init.spec | 34 | stock | TestEZ spec file (dead weight) |
| 162 | `ReplicatedStorage_Knit__Index_sleitnick_table-util_1.2.1_tab_ModuleScript_initspec.lua` | ReplicatedStorage/Knit/_Index/sleitnick_table-util@1.2.1/table-util/init.spec | 697 | stock | TestEZ spec file (dead weight) |
| 163 | `ReplicatedStorage_Knit__Index_sleitnick_table-util_1.2.1_tab_ModuleScript_tableutil.lua` | ReplicatedStorage/Knit/_Index/sleitnick_table-util@1.2.1/table-util | 405 | stock | sleitnick/evaera wally package body |
| 164 | `ReplicatedStorage_Knit__Index_sleitnick_timer_1.1.2_Signal_ModuleScript_Signal.lua` | ReplicatedStorage/Knit/_Index/sleitnick_timer@1.1.2/Signal | 1 | stock (dangling) | dupe of streamable@1.2.4/Signal; requires missing sleitnick_signal@1.5.0 - Timer would error if required |
| 165 | `ReplicatedStorage_Knit__Index_sleitnick_timer_1.1.2_timer_ModuleScript_timer.lua` | ReplicatedStorage/Knit/_Index/sleitnick_timer@1.1.2/timer | 107 | stock | sleitnick/evaera wally package body |
| 166 | `ReplicatedStorage_Knit__Index_sleitnick_timer_1.1.2_timer_in_ModuleScript_initspec.lua` | ReplicatedStorage/Knit/_Index/sleitnick_timer@1.1.2/timer/init.spec | 71 | stock | TestEZ spec file (dead weight) |
| 167 | `ReplicatedStorage_Knit__Index_sleitnick_trove_1.1.0_trove_ModuleScript_trove.lua` | ReplicatedStorage/Knit/_Index/sleitnick_trove@1.1.0/trove | 186 | stock | sleitnick/evaera wally package body |
| 168 | `ReplicatedStorage_Knit__Index_sleitnick_trove_1.1.0_trove_in_ModuleScript_initspec.lua` | ReplicatedStorage/Knit/_Index/sleitnick_trove@1.1.0/trove/init.spec | 210 | stock | TestEZ spec file (dead weight) |
| 169 | `ReplicatedStorage_Modules_CameraShaker_CameraShakeInstance_ModuleScript_CameraShakeInstance.lua` | ReplicatedStorage/Modules/CameraShaker/CameraShakeInstance | 133 | stock | perlin-noise shake instance |
| 170 | `ReplicatedStorage_Modules_CameraShaker_CameraShakePresets_ModuleScript_CameraShakePresets.lua` | ReplicatedStorage/Modules/CameraShaker/CameraShakePresets | 90 | game-specific | all 11 presets custom (stock Bump/Explosion/... removed) - see section 4 |
| 171 | `ReplicatedStorage_Modules_CameraShaker_ModuleScript_CameraShaker.lua` | ReplicatedStorage/Modules/CameraShaker | 154 | modified | Sleitnick CameraShaker + game edits: every Shake* gated by _G.Settings.ScreenShake (returns no-op stub); auto-creates module.CurrentShaker bound at RenderPriority.Camera applying to workspace.CurrentCamera |
| 172 | `ReplicatedStorage_Modules_Cmdr_CreateGui_ModuleScript_CreateGui.lua` | ReplicatedStorage/Modules/Cmdr/CreateGui | 195 | stock | builds StarterGui.Cmdr |
| 173 | `ReplicatedStorage_Modules_Cmdr_Initialize_ModuleScript_Initialize.lua` | ReplicatedStorage/Modules/Cmdr/Initialize | 31 | stock | creates CmdrFunction/CmdrEvent/Commands/Types under ReplicatedStorage.CmdrClient; renames BuiltInCommands -> "Server commands" |
| 174 | `ReplicatedStorage_Modules_Cmdr_ModuleScript_Cmdr.lua` | ReplicatedStorage/Modules/Cmdr | 33 | stock | Cmdr SERVER root (leaked into ReplicatedStorage.Modules); OnServerInvoke -> Dispatcher:EvaluateAndRun; 500000-char cap |
| 175 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_announc_ModuleScript_announce.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/announce | 15 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 176 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_announc_ModuleScript_announceServer.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/announceServer | 13 | stock | Cmdr built-in command server impl (*Server.lua) - NOT registered (absent from CmdrClient/Commands) |
| 177 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_gotoPla_ModuleScript_gotoPlace.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/gotoPlace | 28 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 178 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_gotoPla_ModuleScript_gotoPlaceServer.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/gotoPlaceServer | 20 | stock | Cmdr built-in command server impl (*Server.lua) - NOT registered (absent from CmdrClient/Commands) |
| 179 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_kickSer_ModuleScript_kickServer.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/kickServer | 6 | stock | Cmdr built-in command server impl (*Server.lua) - NOT registered (absent from CmdrClient/Commands) |
| 180 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_kick_ModuleScript_kick.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/kick | 15 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 181 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_killSer_ModuleScript_killServer.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/killServer | 8 | stock | Cmdr built-in command server impl (*Server.lua) - NOT registered (absent from CmdrClient/Commands) |
| 182 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_kill_ModuleScript_kill.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/kill | 15 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 183 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_respawn_ModuleScript_respawn.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/respawn | 15 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 184 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_respawn_ModuleScript_respawnServer.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/respawnServer | 8 | stock | Cmdr built-in command server impl (*Server.lua) - NOT registered (absent from CmdrClient/Commands) |
| 185 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_telepor_ModuleScript_teleport.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/teleport | 22 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 186 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Admin_telepor_ModuleScript_teleportServer.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Admin/teleportServer | 17 | stock | Cmdr built-in command server impl (*Server.lua) - NOT registered (absent from CmdrClient/Commands) |
| 187 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Debug_blink_ModuleScript_blink.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Debug/blink | 19 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 188 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Debug_fetchSe_ModuleScript_fetchServer.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Debug/fetchServer | 5 | stock | Cmdr built-in command server impl (*Server.lua) - NOT registered (absent from CmdrClient/Commands) |
| 189 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Debug_fetch_ModuleScript_fetch.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Debug/fetch | 15 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 190 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Debug_getPlay_ModuleScript_getPlayerPlaceInstance.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Debug/getPlayerPlaceInstance | 24 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 191 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Debug_getPlay_ModuleScript_getPlayerPlaceInstanceServer.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Debug/getPlayerPlaceInstanceServer | 29 | stock | Cmdr built-in command server impl (*Server.lua) - NOT registered (absent from CmdrClient/Commands) |
| 192 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Debug_positio_ModuleScript_position.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Debug/position | 27 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 193 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Debug_thru_ModuleScript_thru.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Debug/thru | 28 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 194 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Debug_uptimeS_ModuleScript_uptimeServer.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Debug/uptimeServer | 11 | stock | Cmdr built-in command server impl (*Server.lua) - NOT registered (absent from CmdrClient/Commands) |
| 195 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Debug_uptime_ModuleScript_uptime.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Debug/uptime | 9 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 196 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Debug_version_ModuleScript_version.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Debug/version | 11 | stock | returns "Cmdr Version v1.12.0" |
| 197 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_alias_ModuleScript_alias.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/alias | 25 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 198 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_bind_ModuleScript_bind.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/bind | 59 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 199 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_clear_ModuleScript_clear.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/clear | 24 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 200 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_conve_ModuleScript_convertTimestamp.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/convertTimestamp | 21 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 201 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_echo_ModuleScript_echo.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/echo | 19 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 202 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_edit_ModuleScript_edit.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/edit | 77 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 203 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_histo_ModuleScript_history.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/history | 25 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 204 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_hover_ModuleScript_hover.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/hover | 18 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 205 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_jsonA_ModuleScript_jsonArrayDecode.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/jsonArrayDecode | 20 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 206 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_jsonA_ModuleScript_jsonArrayEncode.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/jsonArrayEncode | 21 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 207 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_len_ModuleScript_len.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/len | 19 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 208 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_math_ModuleScript_math.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/math | 38 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 209 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_pick_ModuleScript_pick.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/pick | 24 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 210 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_rand_ModuleScript_rand.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/rand | 26 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 211 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_repla_ModuleScript_replace.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/replace | 32 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 212 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_resol_ModuleScript_resolve.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/resolve | 32 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 213 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_runLi_ModuleScript_runLines.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/runLines | 33 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 214 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_run_ModuleScript_run.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/run | 21 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 215 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_runif_ModuleScript_runif.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/runif | 48 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 216 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_unbin_ModuleScript_unbind.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/unbind | 25 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 217 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_varSe_ModuleScript_varServer.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/varServer | 59 | stock | Cmdr built-in command server impl (*Server.lua) - NOT registered (absent from CmdrClient/Commands) |
| 218 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_varSe_ModuleScript_varSet.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/varSet | 25 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 219 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_varSe_ModuleScript_varSetServer.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/varSetServer | 59 | stock | Cmdr built-in command server impl (*Server.lua) - NOT registered (absent from CmdrClient/Commands) |
| 220 | `ReplicatedStorage_Modules_Cmdr_Server_commands_Utility_var_ModuleScript_var.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/Utility/var | 21 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 221 | `ReplicatedStorage_Modules_Cmdr_Server_commands_help_ModuleScript_help.lua` | ReplicatedStorage/Modules/Cmdr/Server commands/help | 55 | stock | Cmdr built-in command definition - NOT registered (absent from CmdrClient/Commands) |
| 222 | `ReplicatedStorage_Modules_FastCastRedux_ActiveCast_ModuleScript_ActiveCast.lua` | ReplicatedStorage/Modules/FastCastRedux/ActiveCast | 616 | stock | cast simulation; PartCache-aware CosmeticBulletProvider |
| 223 | `ReplicatedStorage_Modules_FastCastRedux_ModuleScript_FastCastRedux.lua` | ReplicatedStorage/Modules/FastCastRedux | 55 | stock | FastCast Redux v14.x (HighFidelityBehavior present); DebugLogging/VisualizeCasts=false; requires script.TypeDefinitions (not in dump) |
| 224 | `ReplicatedStorage_Modules_FastCastRedux_Signal_ModuleScript_Signal.lua` | ReplicatedStorage/Modules/FastCastRedux/Signal | 120 | stock | FastCast bundled Signal |
| 225 | `ReplicatedStorage_Modules_FastCastRedux_Table_ModuleScript_Table.lua` | ReplicatedStorage/Modules/FastCastRedux/Table | 65 | stock | FastCast bundled Table util |
| 226 | `ReplicatedStorage_Modules_FastCastRedux_TypeMarshaller_ModuleScript_TypeMarshaller.lua` | ReplicatedStorage/Modules/FastCastRedux/TypeMarshaller | 20 | stock | typeof marshaller |
| 227 | `ReplicatedStorage_Modules_Icon_Attribute_ModuleScript_Attribute.lua` | ReplicatedStorage/Modules/Icon/Attribute | 14 | stock | TopbarPlus v3.4.0 internals |
| 228 | `ReplicatedStorage_Modules_Icon_Elements_Container_ModuleScript_Container.lua` | ReplicatedStorage/Modules/Icon/Elements/Container | 208 | stock | TopbarPlus v3.4.0 internals |
| 229 | `ReplicatedStorage_Modules_Icon_Elements_Dropdown_ModuleScript_Dropdown.lua` | ReplicatedStorage/Modules/Icon/Elements/Dropdown | 321 | stock | TopbarPlus v3.4.0 internals |
| 230 | `ReplicatedStorage_Modules_Icon_Elements_Notice_ModuleScript_Notice.lua` | ReplicatedStorage/Modules/Icon/Elements/Notice | 94 | stock | TopbarPlus v3.4.0 internals |
| 231 | `ReplicatedStorage_Modules_Icon_Elements_Selection_ModuleScript_Selection.lua` | ReplicatedStorage/Modules/Icon/Elements/Selection | 40 | stock | TopbarPlus v3.4.0 internals |
| 232 | `ReplicatedStorage_Modules_Icon_Elements_Widget_ModuleScript_Widget.lua` | ReplicatedStorage/Modules/Icon/Elements/Widget | 436 | stock | TopbarPlus v3.4.0 internals |
| 233 | `ReplicatedStorage_Modules_Icon_Features_Gamepad_ModuleScript_Gamepad.lua` | ReplicatedStorage/Modules/Icon/Features/Gamepad | 167 | stock | TopbarPlus v3.4.0 internals |
| 234 | `ReplicatedStorage_Modules_Icon_Features_Overflow_ModuleScript_Overflow.lua` | ReplicatedStorage/Modules/Icon/Features/Overflow | 298 | stock | TopbarPlus v3.4.0 internals |
| 235 | `ReplicatedStorage_Modules_Icon_Features_Themes_Classic_ModuleScript_Classic.lua` | ReplicatedStorage/Modules/Icon/Features/Themes/Classic | 88 | stock | TopbarPlus v3.4.0 internals |
| 236 | `ReplicatedStorage_Modules_Icon_Features_Themes_ModuleScript_Themes.lua` | ReplicatedStorage/Modules/Icon/Features/Themes | 310 | stock | TopbarPlus v3.4.0 internals |
| 237 | `ReplicatedStorage_Modules_Icon_Packages_GoodSignal_ModuleScript_GoodSignal.lua` | ReplicatedStorage/Modules/Icon/Packages/GoodSignal | 119 | stock | TopbarPlus v3.4.0 internals |
| 238 | `ReplicatedStorage_Modules_Icon_Packages_Janitor_ModuleScript_Janitor.lua` | ReplicatedStorage/Modules/Icon/Packages/Janitor | 281 | stock | TopbarPlus v3.4.0 internals |
| 239 | `ReplicatedStorage_Modules_Icon_Reference_ModuleScript_Reference.lua` | ReplicatedStorage/Modules/Icon/Reference | 20 | stock | TopbarPlus v3.4.0 internals |
| 240 | `ReplicatedStorage_Modules_Icon_Utility_ModuleScript_Utility.lua` | ReplicatedStorage/Modules/Icon/Utility | 588 | stock | TopbarPlus v3.4.0 internals |
| 241 | `ReplicatedStorage_Modules_Icon_VERSION_ModuleScript_VERSION.lua` | ReplicatedStorage/Modules/Icon/VERSION | 44 | stock | TopbarPlus appVersion "v3.4.0"; checks MarketplaceService product 117501901079852 |
| 242 | `ReplicatedStorage_Modules_PartCache_ModuleScript_PartCache.lua` | ReplicatedStorage/Modules/PartCache | 142 | stock | Xan PartCache; parts stored at CFrame(0,1e7,0); ExpansionSize 10 |
| 243 | `ReplicatedStorage_Modules_PartCache_Table_ModuleScript_Table.lua` | ReplicatedStorage/Modules/PartCache/Table | 60 | stock | PartCache bundled Table util |

### A.10 Supplement (`missing_deps.zip`) — 13 new files

| # | Path | Type | Lines | Knit name | Services used (GetService) | Client→server calls | Server→client handled | Client-auth hit report? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | ReplicatedStorage/Modules/KeybindIcons | ModuleScript | 225 | n/a (module) | none | none | none | no | Keycode→icon image maps (KB, Xbox, PS), `updateKeyText/updateKeyImage/updateAll` refresh hotbar + gamepad HUD. Reads `ToolController.LastInput`. |
| 2 | StarterPlayer/.../Controllers/BeamController | ModuleScript | 171 | BeamController | BeamService; controllers FXController, ToolController | `qteRemote:FireServer(true)` (correct key / mobile tap), `qteRemote:FireServer()` (wrong key) | `BeamService.Effects`: `ClashQTE(remote, beamA, beamB)` | no (but QTE is client-auth, see §2.8) | Beam-clash mash QTE GUI `Utils.Misc.BeamQTE`; reads `BeamColor`, `Weight` attrs on beam parts. |
| 3 | StarterPlayer/.../Controllers/Character/EmoteController | ModuleScript | 235 | EmoteController | EmoteService; FXController | `EmoteService.Emote:Fire(slot:number | emoteName:string)`, `EmoteService.EmoteEnd:Fire()` | `EmoteService.Equip(slot, name, animId, tip)`, `EmoteService.Effects(name, ...)` → `script.Effects` module (not in dump) | no | Emote wheel GUI `PlayerGui.Emotes.Emote`, 16 slots/2 pages, search box, gamepass gating via `player.Gamepasses` attrs `742180133`, `1151174294`. Icon img 11713358131. |
| 4 | StarterPlayer/.../Controllers/Character/JoinController | ModuleScript | 767 | JoinController | JoinService, AntiCheatService; UpdateLogController | `JoinService.Change:Fire(movesetKey)`, `JoinService.Talk:Fire(voiceId)`, `JoinService.Reset:Fire()`, `JoinService.MobileLayout` (fired from ToolController), `Remotes.UpdateLog:FireServer(ver?)`, `AntiCheatService.Camera:Fire(camPosBuf9, hrpCFrameBuf15, char, NaN)` every Stepped, `AntiCheatService.Teleport:Fire(token)` (ack) | `JoinService.Reset(title,text)`, `JoinService.Talk(char, voiceId)`, `AntiCheatService.Camera(table name→buf|bool)`, `AntiCheatService.Teleport(char, cfBuf, token)`, `Remotes.UpdateLog.OnClientEvent(ver)` | no | Topbar Icon menu (character select, shop, settings, inventory, achievements, logs, rules, ranked, private server, Cmdr, tutorial, workshop, chat-voice), custom position replication/interp (`lastRecvServer`), chat title prefix, reset-button hook. No TeleportService / place ids. |
| 5 | StarterPlayer/.../Controllers/Character/ToolController | ModuleScript | 1429 | ToolController | JoinService, BlockService, MovementService, EmoteService, ItemService, lazily `<Moveset>Service`, `CustomService`, `ItadoriService`, `DomainService`; controllers MovementController, HandicapController, CopyController | see §2.3 table | `JoinService.MobileLayout(layoutTable | legacy 8-num array)` | no | Central input router: Keybind → service RemoteSignals; hotbar UI, cooldown bars, ult bar, target/aim helpers, platform detection, mobile layout editor. |

| # | Path | Type | Lines | Knit name | Services (GetService) / Controllers | Client→server calls | Server→client handled | Client-auth hit report? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | StarterPlayer/StarterPlayerScripts/Controllers/Character/MovementController | ModuleScript | 1101 | MovementController | MovementService, ItemService, AchievementService; ToolController, HandicapController, FXController | `MovementService.Dash:Fire(dir[, true])`, `MovementService.Parkour:Fire()`, `ItemService.Dash:Fire()`, `ToolController:UseSetService("Chase", inAir)`, `ToolController:GetToolService("CustomService").Chase:Fire(ExtraData.Custom())`, `AchievementService.Give:Fire("Committed to the peace")` | `MovementService.Effects` (name is 2nd arg): Dash, Parkour, Escape, Grab, Hit; `MovementService.Throwable`; `MovementService.ResetDash` | No hit report, but client-authoritative movement (WalkSpeed/JumpPower/BodyVelocity/parkour/achievement) | Dash, chase, sprint, parkour (vault/dive/slide/climb/wall-bounce), ragdoll steering, footsteps, tilt, lock-on camera, evade/burst bar |
| 2 | StarterPlayer/StarterPlayerScripts/Controllers/Combat/HandicapController | ModuleScript | 980 | HandicapController | HandicapService, BlockService, CustomService; FXController, ToolController | none | `HandicapService.Effects`: Collide, Swing, Death, Spawn, Poison, Bleed, SBleed, WakeupEvade, IFrames, Grab, GrabEnd; `HandicapService.Hit`; `BlockService.Effects`; `CustomService.SFX/SFX2/FX/FX2/LOOK/PARTICLE/PARTICLE2` | No | Status/knockback/grab receiver. Exposes Swing/MovementForce/ClearForce/GetCharacterHeight APIs used by other controllers. Creator-Clash custom-move FX runtime (BuilderFX, SkillDefault) |
| 3 | StarterPlayer/StarterPlayerScripts/PlayerModule | ModuleScript | 22 | – | – | – | – | – | Stock Roblox PlayerModule root |
| 4 | StarterPlayer/StarterPlayerScripts/PlayerModule/ControlModule | ModuleScript | 501 | – | – | – | – | – | Stock (PreferredInput-era). No game edits |
| 5 | Players/SmartzyMan/PlayerScripts/PlayerModule/CameraModule | ModuleScript | 473 | – | – | – | – | – | Stock (runtime copy from a player, not StarterPlayer). No game edits |
| 6 | StarterPlayer/StarterPlayerScripts/PlayerModule/CameraModule/MouseLockController | ModuleScript | 172 | – | – | – | – | – | Stock. Offset (1.75,0,0), keys LeftShift/RightShift |
| 7 | StarterPlayer/StarterPlayerScripts/Controllers/Moveset/Hiromi/Awake/FinalJudgementController | ModuleScript | 352 | FinalJudgementController | FinalJudgementService; ToolController, FXController | `qteRemote:FireServer(true)` (correct key / mobile tap), `qteRemote:FireServer()` (wrong key) | Effects: Charge, Dash, Swing, Dodge, Miss, Parry, Hit, Grab, Charged, RealHit, Drag, QTE, QTE2, Haiyah, Feint | No hit report; QTE input is client-driven (spammable) | Hiromi awakening ult: charge → BodyVelocity dash → grab → QTE clash → stab/drag → finisher |
| 8 | StarterPlayer/StarterPlayerScripts/Controllers/Moveset/Todo/Base/ElbowDropController | ModuleScript | 428 | ElbowDropController | ElbowDropService; HandicapController, FXController | none | Effects: Hit, Jump, Crush, Woah, Force, SlideStart, SlideKnockback, SlideKick | No | Todo base: leap onto target + crush landing; slide-kick carry variant. Client drives own BodyPosition/BodyVelocity and PivotTo |

---

## Appendix B — Per-slice open questions (detail behind §14)

### B.A Movesets A

1. **Key bindings / slots**: no input handling in any of these files (UserInputService acquired but unused) — slot order must come from a shared input/skill controller elsewhere.
2. **Cooldowns, damage, stun durations**: entirely server-side; zero numeric evidence here.
3. **Base↔Awake switching for Choso/Gojo**: folders exist but the trigger (Ultimate attribute ≥100? `Chat` effect?) and which service is bound to which slot are not visible.
4. **`Custom/Archive` controllers** (BoostOn2, Grapple, PuppetBarrage, UltraCannon2): still loaded by `AddControllersDeep`; are their services live on the server? Names ending in "2" suggest reworked versions elsewhere.
5. **Goku ↔ Itadori overlap**: GokuController carries DismantleHit/CleaveHit/Chat2 ("BINDING VOW") and Itadori M1 sounds — copy-paste residue or shared "Sukuna vessel" awakening? Server dictates which Effects fire.
6. **Chaos ("S") identity**: assets under `Misc.S`; no character controller in slice — is Chaos a full moveset or a boss/event skill? `On()` global sound suggests server/event-wide announce.
7. **`SetAssets.GWarstaff` vs `GWarStaff`** in Charles Ultimate (7.7 s beat) — casing mismatch means the staff glow never plays unless both exist.
8. **Mokou `SpawnAnim`/`SpawnFunc` contract**: consumed by some spawn/intro controller not in this slice; other characters may export the same fields.
9. **`JoinController.lastRecvServer`** (Grapple): indicates a client-side interpolation system for other players' characters that skills can override — definition lives elsewhere.
10. **Server-side validation of client hit reports**: all four `Hitbox` loops and the BloodEdge/Mokou4 position/aim reports are fully client-computed; whether the server range-checks them is unknowable from this dump.

### B.B Movesets B

- **Hakari & Heian have no character controller here** — HakariController/HeianController (M1s, jackpot/awakening, Sukuna domain) must live elsewhere or not exist; only skill controllers dumped.
- **Slot/key bindings**: no input handling in any file (all input is in a shared InputController not in slice). Folder names Base/Awake/Hand imply movesets swap by state, but the key→move map is unknown.
- **Cooldowns/damage**: zero evidence; all server.
- **Heian shared code**: `Moveset == "Heian"` checks in DismantleV2/FurnaceArrow suggest the same services serve Itadori(Sukuna) and Heian; which character actually owns `DismantleV2Service` vs `DismantleService` is unclear.
- **CursedStrikes client hit report**: server validation unknown (radius 12 sphere at (0,-5,-5) is generous; exploitable if unvalidated).
- **Grab-follow `Jump` handlers** (EnergySurge, LuckyRushdown, Verdict, Rush) move the *victim's* HRP client-side and disable JoinController interpolation — server reconciliation unknown.
- **Haruta Miracles**: max 6 pips; gain/use triggers and what "HandMode" (`objValue.Value` model highlight through walls) tracks are server-side.
- **Hiromi domain**: correct-answer logic, `DeadlyData.Dialog` contents, confiscation rules all server/module-side (`Modules.DeadlyData` not in slice).
- **Decompiler artifacts**: FeverBreakerController and JudgeReachController assign their service to a global (`FeverBreakerService`, `JudgeReachService`) — likely upvalue-recovery failure, not real globals. Controller names `ShutterDoorController` / `StingerController` differ from filenames.
- **Attribute owners**: `Phase%d` (SurgingThorns target), `Lasso` (DefenseResponse follow part), `Rebound` (Hiromi projectile), `Aim` (Execution aim part), `Swing` (OverLuck BodyVelocity), `CF` (ShutterDoors part) — set server-side except `CF` (client sets it); semantics inferred.
- **`Character.Info.DomainTag`** only referenced (RootRampage lifetime 5 vs 30) — Info folder contents otherwise unseen in this slice.

### B.C Movesets C

- **Key bindings / slot order**: none of the 49 files reference input; all move→key mapping lives elsewhere (ToolController / server). Evidence: only `UserInputService` is fetched then discarded.
- **Cooldowns/damage**: zero numeric cooldowns in this slice; only VFX timers. All "n/a (server)".
- **Hitbox coverage**: only Kurourushi and Mahito have client `Service.Hitbox` handlers. Locust, Mechamaru, Megumi, MeiMei controllers fetch `HitboxController` but never use it — are their M1 hitboxes server-side, or handled by a shared controller outside this slice?
- **Mahito variants**: `Swing3` variant 1 = sword, 2 = club, 3/4 = unarmed; `M(char,variant,parts)` plays Transform1/2/3. What triggers variant switches and whether 4 is awakened is not visible.
- **Mechamaru `Moveset ~= "Mechamaru"` checks** (BoostOn, UltraCannon, UltraSpin): implies these skills are shared with another moveset (Kokichi/human form? puppet?). Which one is unknown.
- **`WideSPStrikesService`** (plural) vs controller name `WideSPStrikeController` and `CrusshJawController` typo: confirm server service names match when mapping remotes.
- **Adaptation attrs `A1`/`A2`**: `A1` string attack type, `A2` multiplier steps 1.1/1.3/1.5/1.7 then "FULL"; the hit-count needed per step and reset rules are server-side.
- **MiracleCannon `Debree`** and **GroundPitch `Crunch`** receive server-computed terrain-debris tuples — is map destruction real (server) or cosmetic-only? Only client rendering seen.
- **MoveReveal / KuroClone**: clone billboards show `Moveset` frame when targeted — exact UI content not in dump.
- **Mahoraga `Outfit.Head.{Beard,Hat,Pumpkin}`**: seasonal (Halloween?) cosmetic parts exist on the Mahoraga model; skin system not visible here.
- **Murmurate landing report**: server appears to trust client landing pos/normal (`FireServer(pos,normal)`); validation unknown.
- **BodyDisfigure mash escape**: UnreliableRemoteEvent per Jump press, client caps display at 20; server threshold unknown.

### B.D Movesets D

1. **Collapse landing authority**: server passes a RemoteEvent and the client reports `(hitPos, normal, hrpPos)`. Does the server validate distance/velocity, or accept any position (teleport-slam exploit)? Only client side visible.
2. **Drone steering**: `FireServer(moveVector)` each frame — is magnitude clamped server-side? Client could send >1 vectors.
3. **PianoDrop / Aerial mouse targets**: `ToolDeactivate` returns `GetMouseTarget(75)`; how ToolController forwards it and whether range 75 is enforced server-side is not in slice.
4. **Ratio (Nanami) timing**: `CurrentTiming` attr and `boolValue.Value` are server-set; the input that submits the timing is not here (likely NanamiService method in an input controller).
5. **Reggie item rotation**: `MoveSwap` shows a `ReggieSlot` UI frame and per-item frames — actual item pool/deck logic (Gold/Rainbow seals, Coupons, Littering) is server-only.
6. **Naoya frame rule**: `Info.NaoyaFrame` presence and `FrameNPC` character indicate a 24-frame "projection" mechanic; trigger conditions (enemy not following frames) unseen.
7. **DecisiveStrike2Service**: why two services feed one controller — separate cooldown slots or awakened variant? Unknown.
8. **RyuController missing** from this slice: M1s, awakening name, and any skins for Ryu are not covered here.
9. **Client-side dead-reckoning** (`Speed` attr + `BulkMoveTo`) for Reggie/Ryu projectiles is visual only — hit detection presumably server; unverified.
10. Cooldown numbers, damage values, and unlock/gamepass gating for all four characters: nothing in these files.

### B.E Movesets E

1. **Which Uro move owns `UroService.Hitbox`?** The handler is generic (sphere r=10, waits for a knockback-able target, cancels a NumberValue timer). Evidence only that it is fired with a part carrying a NumberValue; likely a dash/tackle — server side not in dump.
2. **Key/slot mapping** for every move is absent; only `ReplicatedStorage.Keybind.Combat["Skill N"]` (N=1-4) is referenced (CopyController). Whether Awake and Rika moves replace slots 1-4 or use extra keys is unknown.
3. **Cooldowns**: only the Copy wheel shows cooldowns, and those values arrive from the server in `PromptWheel(options)`; nothing numeric is hard-coded client side.
4. **`_G.Shift`** gates the Boogie Woogie client teleport — unclear whether it is a settings flag (shift-lock?) or a state flag; source not in this slice.
5. **`_G.Settings.Outfit`** (Takada outfit override) — where it is set and whether it is a purchased/premium option is not visible.
6. **Copy technique list**: the 22-entry color map hints at copyable techniques (incl. non-JJK "Kamehameha", "Hand Sword", "Bird Control", "Plants", "Granite Blast", "Roaches") but the actual list/unlock rules come from the server.
7. **Yuki charge economics**: `Charge` (0-100), meter `Max`/`Cost` attrs are server-set; rates, decay and what "Charge ≥ 100" unlocks in `OhNo2` are unknown.
8. **Yuta `InUlt` semantics**: fist-mode M1 + MetalHit sounds + `Chat` variant "Zero" suggest an awakened "Rika full manifestation" state vs. a "Zero" (movie) variant — dialogue text lives in `Utils.Yuta.Dialogue` (asset, not dump).
9. **`SetAssets` folder** (YutaSword, YutaRing, Garuda) — created server-side; skin/variant handling not visible.
10. **Todo `Ragdoll` attribute is numeric** (compared `> 0` / `<= 0`), `Stun` is truthy — confirm shared state schema with other slices.
11. **`workspace.Bullets`, `workspace.Effects.CamIgnore`, `workspace.Effects.Bolt`, `workspace.Characters`, `workspace.Map`, `workspace.Domains`** containers and `_G.MapParams` RaycastParams are referenced but defined elsewhere.

### B.F Join/anti-cheat/camera

- AntiCheatController: what it checks, thresholds, reporting service/remote, punishment, whitelists — **all hidden in Luraph VM bytecode**; needs runtime hooking. Does it expose a Knit controller name at all?
- CameraController: why is its path root-level (`CameraController`) rather than under `Controllers`? What Knit controller (if any) wraps it, and what lock-on/shake/cutscene/spectate API do other controllers call? Grep other slices for `GetController("CameraController")` and `Remotes.GetClient`.
- Is the decompiled `return 11-1==10 and "Owl-Fuscator..." or ...` literally the runtime behaviour (module returns a string and does nothing)? If so the anti-cheat is a dead decoy and the real one lives elsewhere; more likely a decompiler artefact.
- Setting keys/gamepass names live in `ReplicatedStorage.Modules.Settings.*` and `Modules.Rules` — not in this slice.
- Who are UserIds 1241352401, 31070091, 174332536 (hidden players) and username `imed2004` (skins dev)? Presumed developers/staff.
- Does the server validate `AchievementService.Give` (client fires achievement names) — likely exploitable for "Space Shenanigans"/"Betavision".
- `EmoteService.Equip` slot 1..16 and `ChangeSkin` ownership checks are server-side — not in dump.

### B.G Core/workspace/utils

1. **Server validation of hitbox reports** — `HitboxService` server code absent. Unknown whether the server re-checks distance/angle between attacker and reported victims, dedupes per-attack, or rate-limits the 40 Hz `FireServer`. Evidence: client sends raw Model list with no token/sequence.
2. **Who calls `HitboxController:SphereHitbox` directly?** It is public; other controllers (M1/skill controllers in other slices) likely call it and fire their own remotes — those are additional client-auth paths to cross-reference.
3. **AL2_TP place ID** — server script unavailable; the LocalScript has no `TeleportService` call. Need a `TeleportService` grep in other slices or the actual game page.
4. **MoneyDestroyer5000** — server-only; is billboard editing free, Robux (DeveloperProduct), or admin? "Report" string implies moderation of user text.
5. **Achievement "Poor Performance"** — granted on client request; does `AchievementService.Give` validate that a Result just occurred with 0 rewards?
6. **Roulette reward cap** — UI clamps at 50$; unknown if server caps payouts or only display. Reward reason strings are server-generated (not enumerated client-side).
7. **Domain clash type codes** `TCMP` and `SOB` — which characters? (`TCMP` model has `Eye`; `SOB` = "Sea of Branch"). `ML` = Yuta's domain (`YutaDomain`) but code letters unclear ("Mutual Love"?). Also `UltNames` module (moveset → [name, color]) not in this slice.
8. **`Start()` vs `KnitStart()`** on the three Ranked controllers — who invokes `Start()`? Probably a `RankedController` parent module (not in this slice) that checks which gamemode place/server it is in.
9. **DiscordClient usage** — nothing in this slice calls `setActivity`; `Modules.Discord.*` (RemoteEvents/Logger/Utils) not dumped here. Is Rich Presence actually wired?
10. **Health scripts** — 12 copies unavailable; regen, max HP per kit (`Kit` cards show `Max health : N`, so HP varies per Roulette kit) are server-side.
11. **DebugController server flags** (`Damage`, `Knockback`, `MaxDmg`, `Tick`, `Fidelity`, `VK/VKB/KF`) — semantics unknown; `Tick 20` and `Fidelity 2` may be destruction-physics replication params.
12. **`_G.Settings` source** — settings controller not in this slice; keys used here: DesPHY, DesVFX, DesINT, Gore, Flash, SENS.

### B.H Modules

1. **MVP title conditions** — only the cinematics exist client-side; the rule mapping (kills? character? finishing move?) is server-side. Names hint at character-specific finishers (Stand Proud=Gojo, King of Curses=Itadori, Meditation=Todo, Stalemate Collapse/True Value=Nanami/Yuta, Watch Your Head=?, Phenomenal=Hakari?, Domain Invasion=Megumi?).
2. **Slot binding** — MoveList index→hotkey slot is inferred (1-4 base / 5-8 awakening) from list shape and SkillDefault AWK flags; the actual slot table (and how 9+ entries like "Grapple", "Rika *", "* OLD" are reached) lives in server/ToolController data not in this slice.
3. **Settings defaults & persistence** — `Val` keys map to `_G.Settings`, but defaults and the JoinService load path are elsewhere (JoinService/SettingsController).
4. **Mokou / Chara** in UltNames with no ListData/MoveList entry — unreleased, event, or admin-only characters (?).
5. **Uro has no SpecialList entry** and only 3 moves — new/incomplete character at dump time.
6. **CONNECT node "SIGNAL"** semantics and **DUR node** (durability) target are undocumented here.
7. Where the Discord SDK is actually used (presence payload) — not in this slice; no webhook found.
8. `UltNames[4]` boolean meaning (false only for Mahoraga) — likely "has awakening banner/domain-name UI".

### B.I Libraries/Cmdr

1. **Server implementations of the 43 game commands** (`ban`, `op`, `moveset`, `customMoveset`, `mokou`, `wavecheck`, `secrettest`, …) are not in the dump; only signatures and role gates are known. What `wavecheck`, `mapsong`, `secrettest` ("imed secret command") and `op` actually do is unknown.
2. `hitbox` lists role `"Moderator"` which has no verifier — is this a dead command for Mods (hook would throw `attempt to call a nil value`)?
3. `ReplicatedStorage.Modules.ListData` (referenced by `character`/`item` types) is in another slice — its `Characters`/`Items` arrays define the valid `moveset`/`item` names.
4. Place `9164905432` gates `Tester` perms and character autocomplete — presumably the test/dev place; the live place id is not in this slice.
5. Streamable/Timer packages point at non-existent `sleitnick_signal@1.5.0` / `sleitnick_trove@0.4.2` — do any controllers require `Knit.Streamable`/`Knit.Timer` (they would error)?
6. `FastCastRedux.TypeDefinitions`, TopbarPlus root `Icon` module, and the PlayerModule root/ControlModule/MouseLockController files are absent from the dump — extraction gap or intentionally removed? Shift-lock/sprint edits cannot be ruled out without `MouseLockController`/`ControlModule`.
7. Whether the Cmdr server module in `ReplicatedStorage.Modules.Cmdr` is the *live* instance (it self-relocates `CmdrClient` to ReplicatedStorage on require, which matches the observed layout) or a stale copy; either way stock built-ins are not registered.
8. Is Cmdr's `_G.GroupId = 16357742` also used by non-Cmdr code (e.g. rank badges/titles)? Set as a side-effect of requiring the Permissions type on the client.

### B.J Supplement: input layer

- `ReplicatedStorage.Keybind.Combat.<Action>` has `.Pressed:Connect` and children with `.KeyCode` — not a plain Instance tree; the Keybind module/loader and **default key mappings** are outside this slice.
- Whether the server validates the `moveNumberValue` instance belongs to the caller's `char.Moveset` and enforces `AWK/AWK2` + cooldown (`ReadyAt`) — no client gating exists, so all of it must be server-side.
- How much the server trusts code-1 `isAirborne`, code-3 aim Vector3, `dir` strings and chosen `Throwable` model.
- `AntiCheatService.Camera`: is the client HRP CFrame used only for validation, or is it the authoritative source rebroadcast to others (client code applies received CFrames verbatim, which suggests the latter, i.e. position is client-authoritative modulo server checks)? The 4th arg `0/0` (NaN) purpose is unknown (tamper canary?).
- `AntiCheatService.Teleport` token semantics (ack vs. confirmation of applied CFrame).
- `CopyController.SelectRemote` / `SelectWheel` (copy wheel) and `MovementController.DashRequest/LockOn` internals are in other files.
- Emote `script.Effects` module, `UltNames` contents, `RobloxChatVoice` table and `Rules.Version` not in this slice.
- Beam QTE: server-side rate limit / expected-press count unknown.

### B.K Supplement: movement/handicap/PlayerModule

- Who sets `MovementController.LockOn` (lock-on target)? Not in this file — likely ToolController / a UI controller.
- Does the server validate `MovementService.Dash` direction/cooldown, or trust the 2s/0.45s local gate? `ResetDash` suggests the server tracks a CD, but parkour (`Parkour:Fire()` with no args) appears purely trusted.
- Server-side WalkSpeed/JumpPower checks: none visible; client sets Humanoid speed each frame (incl. `HRP.Anchored=false`).
- `Info.InDash` is created by the client — does the server also create it, and does anything server-side read the client copy (it does not replicate)?
- `AchievementService.Give` — does the server verify the 300s emote condition or accept any string?
- QTE remote: server rate-limit/expected-key check unknown; mobile path never sends a miss.
- HandicapController `Grab` heartbeat: decompiled `v_u_89:Disconnect()` on a nil upvalue — probably decompiler artifact of `else conn:Disconnect()`; cannot confirm.
- Camera sub-modules (ClassicCamera, CameraInput, Keyboard, etc.) not in this slice — sensitivity/zoom edits, if any, would live there.
- Naming: "Naoya" gets unlimited-charge fast dashes; "Goku" 4 wall bounces — movesets exist beyond JJK roster (Goku, Ryu, Todo, Hiromi).

---

## 16. Runtime findings (observed in live play, Sep 2026)

Everything above was read from the decompiled client. This section is different
in kind: it is what a bot running against the live server actually measured,
over roughly 300 lives across 25 characters. It is recorded separately because
its authority is different — the sections above describe code that exists, this
one describes behaviour that was watched, and where the two disagree this
section is the one that was tested.

Method: passive observers on `Info`, `<Service>.Effects` and
`ReplicatedStorage.Animations`, plus manually fired remotes with before/after
state capture. No metatable hooks — an earlier `__namecall` spy silently broke
the very calls it was meant to observe, and every finding below was obtained by
reading state instead.

### 16.1 Character switching (`JoinService.Change`)

| Finding | Detail |
|---|---|
| Change forces a respawn | `JoinService.Change:Fire(name)` causes a full server-side respawn in ~0.5 s. No separate `Reset` is needed, and firing one wastes a life. |
| Confirmation is on spawn | `char.Moveset` is the only reliable confirmation. It can be **unset for up to ~2 s after spawn**, so an immediate read produces a false failure. |
| Rate limited, silently | Roughly 10 s server-side. A call inside that window is dropped with no error and no reply. |
| Combat lock | Being **hit** puts the character into a state that refuses Change for ~14 s, also silently. Indistinguishable from an unowned character by the client. |
| Unowned characters | Also fail silently and identically. Only repetition distinguishes them from the two cases above. |
| **(1.85)** Death no longer respawns | Since 1.85 the server leaves a dead fighter where it fell. Whether `Change` still forces a respawn from a live character was not re-tested; nothing in the client suggests it changed. See §17.2 for the new `Respawn` remote. |

The practical consequence: every failure mode of `Change` looks the same from
the client — nothing happens. Success can only be detected by watching for the
respawn plus a matching `Moveset`.

### 16.2 The `Info` folder — observed flag vocabulary

§6.9 documents `Info` as a status folder. These are the children actually seen
in play, with what they accompany:

| Flag | Observed alongside |
|---|---|
| `Cancel` | present essentially always |
| `Stun` | CC; **can appear more than once simultaneously** (three concurrent `Stun` children were logged) |
| `Knockback`, `Wakeup` | knockback and the getup that follows |
| `InSkill` | any move in progress, including carrying a throwable |
| `NoSprint`, `NoJump` | movement restrictions during moves and while carrying |
| `DisableChase` | after being hit; blocks the chase follow-up |
| `Dash`, `DashLinger`, `InDash` | dash window and its tail |
| `DMG_M` | damage multiplier state, seen for long stretches after heavy trades |
| `ItadoriCancel` | Itadori-specific cancel window |
| `Throwable` | **ObjectValue** pointing at the carried model (see 16.3) |
| `Item` | tool in hand, e.g. `Item=Jet Black` (see 16.3) |

### 16.3 Throwables and tools are two different systems

This is the finding that took longest to establish and contradicts the obvious
reading of the remote list.

| | Throwable (bin, chair, fire extinguisher) | Tool (`Jet Black`) |
|---|---|---|
| Marker | `Info.Throwable` = ObjectValue → the model | `Info.Item` |
| Moveset while held | **locked** — no skills, no melee | not locked |
| Movement while held | allowed, slower | normal |
| Pick up | `MovementService.Throwable:Fire(model)` | — |
| Throw / use | **`MovementService.Throwable` again** | `ItemService.M1(dir, target)` |

**`MovementService.Throwable` is a toggle.** Fire it with a model to pick that
model up; fire it again to throw what is in your hands. `ItemService.M1`, `M2`
and `Drop` do **not** release a carried throwable — all four were tested
directly and only the re-fire worked.

Two further details that cost real debugging time:

- The folder holds **models**, and each model contains several `Part`s. Firing
  `Throwable` at a Part does nothing; the server wants the model.
- Picking up sets `Stun` as well as `InSkill` and `NoSprint`. Any bot that
  treats stun as "wait" will stand frozen for the entire carry.

`Workspace.Map.Destructible` children, counted live:
`Throwable` (122 models, incl. `Extinguish`, `Trash`), `Buildable` (0),
`Vending` (14), `Neps` (8), `Model` (782), and six separate `Bowling Ball`
folders of 6 each.

### 16.4 `ReplicatedStorage.Animations` is a usable move index

§4.9 catalogues this tree. What it does not say is that it is **readable at
runtime and directly useful**: walking it yields **885 animations across 25
characters**, keyed by `AnimationId`, each named for its move
(`Animations.Gojo.LapseBlue`, `Animations.Itadori.CrushingBlow`).

Two things follow, both of which remove guesswork entirely:

1. **What an opponent is doing** — read the tracks playing on their `Humanoid`
   and look the ids up. No proximity heuristics, no "they are mid-skill so it
   is probably them".
2. **What hit you** — the index contains **victim animations**
   (`BloodEdgeVictim`, `RedScaleVictim`, `WingKingVictim`, `ShadowSwarmHit`,
   `CrushingRushdownHit`). When one plays on your own character, the game has
   named the move that landed.

This is the most reliable identification channel available to a client, and it
is better than the effect signals for the purpose, because effects announce
what the server did while animations show what is happening now.

### 16.5 Effect signal shape

Confirmed by classifying ~43 hooked services in play: the signal is
`<Move>Service.<Phase>`. The **service** identifies the move; the **effect
name** is the phase. Phases divide cleanly into telegraphs (`Startup`,
`Windup`, `Charge`, `Grab`, `Dash`, `Fire`, `Spin`, `Weave`, `Throw`, `Flick`)
and landings (`Hit`, `Hit1..3`, `FinalHit`, `ChaseHit`, `BlackFlashHit`,
`Explode`, `Crush`, `Victim`, `Impact`).

Keying danger classification on the **effect** name matches almost nothing —
a real measurement put it at about 1%. Keying on the **service** name works.

### 16.6 Blocking is not directly observable

There is no client-visible "is blocking" flag on another player.
`BlockService.Effects` fires, but the durable signal is `Humanoid.WalkSpeed`
(§6.9: block sets 4 or 6). An **absolute** threshold fails, because base walk
speed varies per character and with sprint and HP penalties — using one marked
every player as permanently blocking. A per-character rolling baseline, with
block inferred from a *relative* drop, works.

### 16.7 `PathfindingService` limits

`ComputeAsync` fails routinely beyond roughly 120–150 studs in this map. A
failed path at that range means "far", not "unreachable" — treating it as the
latter blacklists most of the server. Observed: the same opponent rejected six
times in one second at 190 studs.

### 16.8 Map scale

Cell-mapping at 24-stud resolution over ~300 lives covered about
**4400 × 3600 studs**, with hostiles observed in 1341 of 1400 visited cells —
the playable area is effectively the whole map, not a central arena.

### 16.9 Move ranges

Client-side `MoveRules`-style estimates inferred from move names were checked
against the published catalogue for the 83 moves where both exist: **correct
for 2**, median error **15 studs**. Examples: `Cheap Shot` 11 vs 60 actual,
`Pigeon Viola` 60 vs 250, `Reserve Balls` unbounded vs 65.

Ranges are **horizontal**. Vertical reach is documented nowhere public and had
to be treated as a per-move unknown; a target 34 studs below with 15 studs of
horizontal separation is not reachable by anything in the roster.

### 16.10 Corrections to §14 (open questions)

| §14 item | What live observation adds |
|---|---|
| #3 Cooldown numbers per move | Still server-held, but the public catalogue supplies listed cooldowns for 166 moves, and `ReadyAt`/`LastUse` attributes track them client-visibly in practice. |
| #4 Damage / stun values | Still server-held. Relative damage is measurable per move by attributing HP deltas, which is enough to rank a kit without knowing absolute numbers. |
| #5 Awakening trigger | `InUlt` observed as **nil rather than false** when not awakened — a truthiness test on it is safe, an equality test is not. |

### 16.11 Still unknown after live testing

- Whether the server validates hit lists (§14 #1) — untestable without
  deliberately sending false ones, which was not done.
- Startup frames, active windows and vertical reach per move: absent from the
  client, absent from public catalogues, and not cleanly measurable from
  outside.
- Whether `Change` refusals differ internally between combat lock, rate limit
  and unowned character. All three present identically to the client.

---

## 17. Version 1.85 delta (THE HALLOWEEN UPDATE) — from the place file

Everything in this section was read from `shanin.rbxl` (see the header). Nothing here was tested against the live server, so wherever §16's standard would apply — "does the server really do that" — the answer is still open and is listed in §17.11.

### 17.1 What the place file is, and what it adds over a script dump

| Fact | Value |
|---|---|
| Format | Roblox binary place (`<roblox!`), chunks LZ4/zstd; written by UniversalSynSaveInstance, whose `README` script is at the root |
| Instances / classes | 71,665 / 201 |
| Scripts with source | 962 (917 ModuleScript, 32 Script, 13 LocalScript), 7.9 MB. 302 are the dumping player's live `PlayerScripts`, 258 are the `StarterPlayerScripts/Controllers` templates (the same code), the rest `ReplicatedStorage` modules |
| Still unreadable | `ServerStorage`, `ServerScriptService` and server `Script`s (FilteringEnabled). The saver also reports it could not read properties of types `AssetContentMap`, `Color3uint8`, `Enum`, `NetAssetRef`, `OptionalCoordinateFrame` |
| Version | `UpdateLogController.Ver = "1.85"`, banner `V1.85 \n THE HALLOWEEN UPDATE` |
| Dumping player state | `SmartzyMan`, `Moveset = "Uro"`, `Ultimate = 36.75`, `Cash = 400`, `Candies2026 = 18`, `LastRulesAccepted = 3`, `MVP = "King Of Curses"`; hotbar `Main.Controls.Moveset` = Blind Rage, Thin Ice Breaker, Sky Distortion, Turbulence |
| Other characters present | only `Workspace.Characters.Dummy` (empty `Moveset`, `Info` = `Cancel`, `Wakeup`) |

What it settles that the 1.82 dump could only infer:

- **The whole C↔S surface.** `ReplicatedStorage.Knit.Knit.Services` holds one folder per Knit service with an `RE` (RemoteEvent) and sometimes `RF` (RemoteFunction) child folder: **260 services, 711 RemoteEvents, 2 RemoteFunctions**. Appendix C lists all of them. 44 of those services are not named anywhere in §1–§16.
- **GUI structure.** `StarterGui` = `Controls`, `DomainFade`, `Emotes`, `Main`, `Menus`, `Ranked`, `Roulette`, `CandiesMobile`, `Candies`, `HalloweenShop`, `Cmdr`. `Menus.Group` = Achievements, Inventory, Logs, Private, Ranked, Settings, Tutorial_Info, Rules, Workshop, Shop. `Main` = `Preset`, `UIScale`, **`Respawn`** (TextButton), `FPS`, `Controls`.
- **Hotbar naming.** The frames under `Main.Controls.Moveset` are named after the moves exactly as `ListData.MoveList` spells them, which is the same string a `char.Moveset` NumberValue carries.
- **Controllers the 1.82 dump lacked.** 39 controller modules are new to this reference (§17.7). Most are not new to the game — the first dump simply missed them (`HakariController`, `RyuController`, `AbsoluteController`, `MahoragaController`, `HeianController`, several awakening moves). The ones that *are* new in 1.85 are the seven Toji controllers, `Reggie/Awake/HouseController` and `RoadRageController`, and `Uro/TurbulanceController`.

### 17.2 Respawning is manual now

The 1.85 log, under COMBAT: *"You no longer automatically respawn (A setting is available under [Controls] to revert the change)."*

| Piece | Where | What it does |
|---|---|---|
| `JoinService.Respawn` | `Knit/Services/JoinService/RE/Respawn` (new; the other six `JoinService` remotes are unchanged: `AcceptRules`, `Change`, `MobileLayout`, `Reset`, `Setting`, `Talk`) | C→S, **no arguments**. The request to be respawned |
| `char:GetAttribute("CanRespawn")` | set by the server on the dead character | The offer. `ToolController` reads it every `Stepped` |
| `Info.NoRes` (attribute **or** child) | on the character's `Info` | Vetoes the offer. Driven by the private-server setting "Allow manual respawn" (`DebugController` setting `AutoRes`, default `true`; its `Respawn` getter returns `not Info:GetAttribute("NoRes")`) |
| `PlayerGui.Main.Respawn` | TextButton "Respawn", `Visible = false` in `StarterGui`, child `Key` (`KeyIcon`, `Key` label) | Shown while `CanRespawn and not NoRes`: fades in over 1 s (background to 0.5). While it is up, the toolbar and guides slide away (the same branch that hides them during a domain clash) |
| Click | `ToolController` → `Main.Respawn.MouseButton1Click` | UI click sound, a 290×50 → 300×60 bounce, then `JoinService.Respawn:Fire()` |
| Special key | `ToolController.Special` | **If `Main.Respawn.Visible`, the Special key fires `JoinService.Respawn` instead of the character's special** (checked before items, custom specials and `RightActivated`) |
| Setting | `Modules.Settings.Controls["Auto Respawn"]` = `{Btn = 1, SortOrder = 8, Val = "AutoRes", Desc = "Automatically respawn when available"}` | A per-player toggle sent like every other setting, `JoinService.Setting:Fire("AutoRes", bool)`. With it on, the server presumably respawns as before; the client code for the toggle is only the generic settings row |

Consequences for an automated client:

- A client that waited for `CharacterAdded` after death now waits forever. It has to notice `CanRespawn` on its own dead character and fire `JoinService.Respawn`.
- The remote takes no arguments and nothing is sent back, so — exactly like `Change` (§16.1) — a refusal is indistinguishable from a lost request. The only confirmation is the new character. Repeat on a timer.
- `CanRespawn` is the server's "you may now" signal; firing before it appears is at best ignored. How long after death it appears is server-side.
- Flipping the player's own `AutoRes` setting through `JoinService.Setting` would restore the old behaviour, but that edits a saved preference; firing `Respawn` does not.
- The same log adds **"Hitting a player now triggers combat tag"**. §16.1's combat lock on `Change` (~14 s after being hit) should now be expected after *landing* a hit too. No client-visible flag for the tag was found: no attribute or `Info` child with "combat"/"tag" in its name is read anywhere in the client.

### 17.3 Skill arguments: ToolController's table, complete

§6.9 described the route; the 1.85 client gives the data. `ToolController.UseTool(moveValue, "Activated"|"Deactivated")` looks the move's **name** up in a table of 75 entries and builds the one extra argument the service receives. Moves not in the table send `false`.

| Code | Extra argument sent | Moves (name as on the hotbar) |
|---|---|---|
| 1 | airborne (bool) | "What are you after?", Ambush, Blunt Cut, Circling, Cleave, Collapse, Crushing Blow, Cursed Strikes, Defense Response, Detach, Dismantle, Execution, Flowing Red Scale, Granite Blast, Hollow Purple, Impetus Updraft, Kamehameha, Ki Spam, Lapse Blue MAX, Mass Breaker, Murmurate, Outburst, Reversal Red MAX, Revolve, Rika Launch, Roach Swarm, Root Rampage, Root Swarm, Rough Energy, Second Wind, Sharpen, Shut Up!, Sky Distortion, Slicing Exorcism, Staff Extend, Stockpile, Surging Thorns, Transcend, Veilstep |
| 2 | lock target (`GetTarget()`) | Authentic Mutual Love, Blind Rage, Body Disfigure, Crushing Rushdown, Decisive Strike, Divine Dog: Totality, Face Blitz, Flower Field, Garuda Rebound, Grapple, Judgement's Reach, Lapse Blue, Mahoraga, Nue, Passenger Cars, Pigeon Viola, Puppet Barrage, Rabbit Escape, Resolute Slash OLD, Second Helping, Shutter Doors, Takedown, Technique Charge, Tendril Grab, Thin Ice Breaker, Toad |
| 3 | mouse point (`GetMouseTarget(75)`) | Piano Drop |
| 4 | move vector (`ControlModule:GetMoveVector()`) | Severance Kick, Severing Path |
| 5 | `{airborne, target, mousePoint, moveVector}` | Bird Control, Copy, Resolute Slash, Tracking Roots |
| 6 | `{airborne, InDash, InRoll}` | Debilitate, Swift Kick |
| 7 | **new in 1.85** — `airborne or Humanoid.Jump == true` | Turbulence |

- "airborne" is computed as: `Humanoid.FloorMaterial == Air`, not swimming, **and** a down-ray of `GetCharacterHeight(char) + 1` studs against `_G.MapParams` finds nothing.
- `Activated` fires `Service.Activated(moveValue, extra)`. If `extra` is falsy and `ExtraData[moveName]` exists, that function supplies it; the only entry is `Custom`, returning `{airborne, GetTarget(), GetMoveVector(), Humanoid.Jump == true}` (used by the custom-moveset `CustomService` calls).
- `Deactivated` first asks `<Move>Controller.ToolDeactivate(char)` (derived by stripping `Service` from the move's `Service` attribute) for a replacement extra, then fires `Service.Deactivated(moveValue, extra)`.
- `ReturnKey(key)` — which NumberValue a hotbar key maps to — is unchanged: first child of `char.Moveset` whose `Key` matches, that has a `Service`, skipping `AWK` moves while `InUlt` and `AWK2` moves while not.
- **Special key** (`ToolController.Special`), in order: `Info.InstantDomainClash` → `DomainService.Activated2:Fire()` (new remote); `Main.Respawn.Visible` → `JoinService.Respawn:Fire()`; `Info.Item.M2` → `ItemService.M2`; custom special → `CustomService.Special(ExtraData.Custom())`; otherwise `<Moveset>Service.RightActivated(...)` with `Todo` → `GetTargetOrProjectile()`, `Naoya`/`Hanami` → `(GetMouseTarget(75), GetTarget())`, `MeiMei` → move vector, everyone else (Toji included) → `GetTarget()`. Release → `RightDeactivated()`.
- `GetMouseTarget(range, includeChars)` on `LastInput == "Mobile"` is **not** a touch position: it is a ray from the camera, one stud up, along the camera's look vector (range 300 by default, 600 for Hanami), ignoring the own character (or all characters), `workspace.Effects` and `workspace.Logic`.
- `GetTarget()` is a screen-space pick: nearest character to the crosshair (mobile: `Controls.Crosshair.AbsolutePosition`) within a fifth of the viewport height and a per-moveset distance cap (`SuperTze` 1000, `Haruta` 350, `Mechamaru` 300, …). It skips characters with `Info.UroDistort` — that is what "you can no longer lock onto the user when invisible" is — and the `HarutaSwordNPC`.

### 17.4 Roster and game data

**Characters dropdown** (`JoinController.KnitStart`). Every entry fires `JoinService.Change(key)`.

| Group | Entries (label → key) |
|---|---|
| Full roster (`CreateIcon`, default label colour) | Honored One → Gojo, Vessel → Itadori, Restless Gambler → Hakari, Ten Shadows → Megumi, Perfection → Mahito, Blood Manipulator → Choso, Switcher → Todo, Defense Attorney → Hiromi, Cursed Partners → Yuta, Puppet Master → Mechamaru, Head of the Hei → Naoya, Salaryman → Nanami, Disaster Plants → Hanami, True Cannon → Ryu, **Register → Reggie** (moved up from the early-access group: "REGISTER HAS BEEN RELEASED TO THE PUBLIC!"), **Hired Hunter → Toji** (new) |
| Early access (`CreateIconBase`, label RGB 152,152,152) | Locust Guy → Locust, Star Rage → Yuki, Aspiring Mangaka → Charles, Lucky Coward → Haruta, Crow Charmer → MeiMei, Black Death → Kurourushi, Sky Bender → Uro |
| Conditional (label RGB 255,170,0) | Strongest Of History → Heian if `workspace:GetAttribute("AllowOP")`; Mokou (icon 129398506853336) if the player has attribute `Mokou`; Monkey Kid → Goku (icon 79537216753706) if the player has `Goku` or `AllowOP` |
| Custom (label RGB 85,170,255) | one per ObjectValue under `workspace.LogicData.CustomChar`; label and key = the value's `MoveNameFt` attribute, icon = `IMG`, enabled only while `Flip == true` |

The `Characters` icon is created with `setEnabled(false)` and no readable 1.85 code enables it again, yet it is visible in live play. Whatever enables it is in one of the two obfuscated scripts or was lost in decompilation.

**ListData** (compare §4):

| List | 1.85 state |
|---|---|
| `Characters` | 26 — the 25 of §4 plus `"Toji"` at the end |
| `MoveList` | 26 blocks, same index as `Characters`. New block `HIRED HUNTER` RGB(50,50,50): Flourish, Debilitate, Transcend, Rupture, Lasso, Whiplash. `SKY BENDER` (was listed as Sky Assassin in older notes) RGB(255,165,165) gains **Turbulence** as its fourth. `REGISTER` lists ten: Gushing Wound, Homerun, Littering, Coupon, Piano Drop, Garage Sale, Blunt Trauma, Fleche, Drone Strike, Pole Vault — the awakening moves (Road Rage, House, Big Moves, Mayhem, Speed Crash) are not in it. `TRUE CANNON` lists its awakening moves by their quoted names (`"What are you after?"`, `"I had no idea..."`, `"This is what dessert is like!"`, `"You weren't invited."`) |
| `SpecialList` | 30 names → index. Not named in §1–§16: Sky Veil (25) |
| `Items` | 25. Not named in §1–§16: C4, RPG, Tiangang Star's Blade |
| `AttackTypes` | unchanged: Melee, Bullet, Explosion, Swarm, Domain |
| `States` | 28, unchanged |
| `AnimList` | gains the Toji set: `Toji.Melee.{SSK,ISOH,COATM}.*`, `Toji.COATM.{Lasso, LassoBroken, Whiplash, WhiplashSpin, WhiplashVariant}`, `Toji.ISOH.{Rupture, RuptureHit, Transcend}`, `Toji.SSK.{Debilitate, DebilitateVictim, Flourish, FlourishVictim, FlourishWrath, Greed, Pride, PrideVictim, WrathVictim*}`, `Toji.Stance.*` |

**UltNames** adds `Toji = {"Puppet of Carnage", RGB(24,24,24), RGB(0,0,0), true}` and `Chara = {"SINCE WHEN WERE YOU THE ONE IN CONTROL?", RGB(255,0,0), (0.33,0,0), true}`. `Chara` has no controller, no service and no roster entry in this dump.

### 17.5 Hired Hunter (Toji)

The full block is in §5 under **Toji**. In short: three weapon stances on `Info.Stance`, swapped by the special; each stance has its own melee chain and two moves; all six move controllers are effects-only, so the only client-side facts about a move are its argument code, its effect keys and its assets.

### 17.6 Changes to existing movesets

| Character | Change |
|---|---|
| Reggie | Released to the full roster. Awakening: **Arson is gone** (no controller, no `ArsonService`); **Road Rage** and **132-Square-Foot Two-Story House** are new (rows added to the Reggie table in §5). Both are *aim-after-activation* moves: the server hands the caster a throwaway remote inside an `Effects("Hitbox", …)` event and the client streams its mouse point into it. A client that does not answer still casts, aimed wherever the game's own controller says the camera is looking. Log: "Big Moves somewhat reworked", "Littering and Gushing Wound now properly stick to objects and throwables" |
| Uro | Header is `SKY BENDER`. New fourth move **Turbulence** (`TurbulanceService`, arg code 7). The special is in `SpecialList` as **Sky Veil** (index 25): invisibility, implemented for other clients as `Info.UroDistort`, which removes the character from `GetTarget()`. Log: reduced hitlag on R+3, a height requirement on the aerial evasive, Sky Distortion Temper knocks close enemies away |
| Mechamaru | "Removed that god awful multi npc body system for Absolute". `AbsoluteController` (1,600+ lines, `AbsoluteService`: `Debree`, `DropkickHitbox`, `Effects`, `EjectHitbox`, `JumpRequest`) is now in the dump. Awakening: melee consumes awakening, skill costs adjusted |
| Hanami | Chain knockback spikes 7 → 6; Surging Thorns 5-5-5 → 3-3-5, special variant 9 → 6, block-break/interrupt bonus 3 → 2. The only damage numbers the client has ever shown, and only because the log prints them |
| Domains | Barrier damage cut for Roach Swarm (−60%), Slicing Exorcism (−70%), Defense Response (−25%), Perfection club fists (−65%), Disaster Plants uppercuts/downslam (−50%). Clash: non-melee attacks cannot hit you during a clash; a domain can be opened during awakening if inside an opening domain. New remote `DomainService.Activated2` (fired by the Special key while `Info.InstantDomainClash` exists) |
| Toji vs. everyone | Domain barriers do not collide for a Toji client; see §5 |

Effect keys of every moveset controller that is new to this reference:

| Controller (under `Controllers/`) | Effects keys |
|---|---|
| `Moveset/Gojo/Awake/InfiniteVoidController` | Startup, Opening, Shatter |
| `Moveset/Gojo/Base/TwofoldKickController` | Swing1, Swing2, Hit, FinalHit, Domain, DomainWind, Music, Boost, Trail, Smear, SpeedHit, Slow, SpeedFinish, Cut |
| `Moveset/Hakari/HakariController` | Hit, ChaseHit, Counter, Fade, CounterHit, CounterEnd, CounterSwing, Chase, Swing, Swing2, Launch, Surge, Startup, Opening, Richii, Roll, Jackpot, Shatter, RevengeAppear |
| `Moveset/Hanami/Awake/SeaOfBranchesController` | Startup, Absorb, FloorEffect, Fade, Opening, Shatter |
| `Moveset/Heian/HeianController` | Hit, ChaseHit, Chase, Swing, Swing2, Launch, Startup, Chant, Interp, DebreeOverlay, DomainOpen |
| `Moveset/Hiromi/Base/JusticeServedController` | Expand, Crush, Hit2, FinalHit, Jump, Finisher, BangEmoteFinisher, Hyah |
| `Moveset/Itadori/Awake/MalevolantShrineController` | Startup, Opening, Shatter, Hit |
| `Moveset/Itadori/Awake2/CleaveController` | Start, Hit, Dash, Hit2, Hit3, Leap, Spiderweb, LaunchDown, Finisher |
| `Moveset/Mahito/PreAwk/SelfPerfectionController` | Startup, Opening, Shatter |
| `Moveset/Mechamaru/AbsoluteController` | Hit, ChaseHit, Chase, Swing, Swing2, Swing3, Hit2, Sparks, Explosion, RedLights, RootCamera, LightUpEyes, ComeOut, ComeOut2, ComeOut3, TorsoComeOut, MechaJump, MechaLand, UltHUD, TorsoParticle, SmallWind, SmallWind2, DustLand, DropkickLeap, Dropkick, DropkickSpark, DropkickHold, DropkickLand, MechaHoldJump, Jump, Eject, DrillShow, BoostRepeat2, DustLandEject, DustLand2Eject, DiveEject, EjectDiveHit, UltEnd, ULTM1Rotation, MechaDamage, KickStart, KickSwing, MechaKickFinal, Stagger, StaggerGetUp, LockOn, StaggerPunishSound, StaggerSecondJump, EnergyOutputUI |
| `Moveset/Megumi/Mahoraga/MahoragaController` | Hit, ChaseHit, Chase, Swing, Launch, Wheel, Wheel2, Wheel3, ParryStart, Parry, Parry2 |
| `Moveset/Nanami/Awake/RatioBreakerController` | Start, Slash, SlashHit, WindCharge, ArmEmit, Whoosh1, WhooshUlt, BlackFlashHit, ArmCharge, Whoosh2, Jump, JumpHitbox, Slam, ArmCharge2, RatioBreakerBlackFlash, Dash, RatioBreakerHit, RatioBreakerFinisher |
| `Moveset/Nanami/Base/BluntCutController` | Start, Hit, Charge, Dash, Hit2, Hit3, Swing2, Whoosh, Endlag, Launch, Leap, Slam, LaunchDown, Finisher, FinisherBleed, Finisher2 |
| `Moveset/Naoya/Awake/TimeCellMoonPalaceController` | Startup, Opening, Shatter, Hit, Form |
| `Moveset/Reggie/Awake/HouseController` | Start, Voice, Hitbox, Smash, Interp, Smash2, Hit, Finisher |
| `Moveset/Reggie/Awake/RoadRageController` | Hit, Hitbox, CarInterp, Crush2, Finisher |
| `Moveset/Ryu/Awake/ThisDessertController` | Startup, Dash, FirstHit, Swing, StartHit, Flash, Hit1, Weave, FinalHit |
| `Moveset/Ryu/RyuController` | Hit, ChaseHit, Chase, Swing, Swing2, Launch, Ring, Overheat, Comb, Comb2, FireBeam, UltimateCharge, Ultimate, EveryLastDrop, StartBeam, YutaClashing |
| `Moveset/Toji/COATM/LassoController` | Start, ChainGrab, Hit, Pull, KickWhoosh, Hit2 |
| `Moveset/Toji/COATM/WhiplashController` | Start, Spin, Whoosh, Hit, Hit2, Dash |
| `Moveset/Toji/ISOH/RuptureController` | Hit, Dash, Swing1, Windup, Swing2, SkillCheck, Feint, Catch, EatISOH, Throw, Stab, Hit2 |
| `Moveset/Toji/ISOH/TranscendController` | Startup, Dash, Hit |
| `Moveset/Toji/SSK/DebilitateController` | Swing, Hitbox, Hitbox1, Jump, Hitbox2, Hitstop, Launch |
| `Moveset/Toji/SSK/FlourishController` | Spin, Hit, Hit2, AfterImage, Slowmo, Slash, ChainSpin, ChainGrab, ChainHit, ISOHHit, KickHit, ISOHTrail, FasterDash, FinalLand |
| `Moveset/Toji/TojiController` | Setup, StanceHide, StanceUnequip, StanceEquip, Chase1Hit, Chase1Spin, Chase3Crush, Chase3Hit, Chase3Finisher, ChaseHit, Chase, Swing, Swing2, Hit, Launch, Equip, Chase3Whoosh |
| `Moveset/Uro/TurbulanceController` | Startup, Startup2, Wave, Kick, Crush, Crush2, Hit, Finisher |
| `Moveset/Yuta/Awake/MutualLoveController` | Startup, Opening, DropSwords, Pickup, RunSwing, Run, SwordHit, BigVoice, Shikigami, ShikigamiHit, Dodge, JLFinisher, Dodge2, TIBHit, Shatter, JacobLadder |
| `Moveset/Yuta/Base/EnergyRippleController` | Hit, AirHit, StartBomb, StabFloor, Bomb, BombHit, FeintSwing, FeintHit |

### 17.7 Controllers new to this reference

Rows continue the numbering of §2.5.5 and use its columns.

| # | Path (under PlayerScripts) | Knit name | Lines | Services (`GetService`) | Controllers (`GetController`) | Init | Start | S→C signals connected | FireServer / InvokeServer |
|---|---|---|---|---|---|---|---|---|---|
| 221 | `Controllers/Character/AchievementController` | `AchievementController` | 351 | AchievementService | FXController | ✓ | KnitStart | Daily, Update, Weekly | 0 / 1 |
| 222 | `Controllers/Character/EmoteController/Effects` | `(module)` | 1135 | — | FXController | — | — | — | 0 / 0 |
| 223 | `Controllers/Character/JoinController/CandiesController` | `CandiesController` | 208 | CandiesService, ShopService | FXController | ✓ | KnitStart | OpenShop | 0 / 0 |
| 224 | `Controllers/Character/JoinController/ShopController` | `ShopController` | 712 | ShopService | FXController | ✓ | KnitStart | Chat, Notification, Preview, UpdateOdds | 0 / 1 |
| 225 | `Controllers/Character/JoinController/TutorialController` | `TutorialController` | 105 | — | FXController | ✓ | KnitStart | — | 0 / 0 |
| 226 | `Controllers/Character/KoganeController` | `KoganeController` | 732 | HandicapService, KoganeService | AchievementController, EmoteController, FXController | ✓ | KnitStart | Effects, LastHit, Playlist | 0 / 0 |
| 227 | `Controllers/Combat/DebreeController` | `DebreeController` | 246 | DebreeService | FXController | ✓ | KnitStart | Create, Destroy, Domain, Loaded, MoveAway, MoveIn, Physics, Sound | 0 / 0 |
| 228 | `Controllers/Combat/DebreeController/BufferRead` | `(module)` | 165 | EncodingService | — | — | — | — | 0 / 0 |
| 229 | `Controllers/Moveset/Gojo/Awake/InfiniteVoidController` | `InfiniteVoidController` | 231 | InfiniteVoidService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 230 | `Controllers/Moveset/Gojo/Base/TwofoldKickController` | `TwofoldKickController` | 622 | TwofoldKickService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 231 | `Controllers/Moveset/Hakari/HakariController` | `HakariController` | 704 | HakariService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 232 | `Controllers/Moveset/Hanami/Awake/SeaOfBranchesController` | `SeaOfBranchesController` | 306 | SeaOfBranchesService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 233 | `Controllers/Moveset/Heian/HeianController` | `HeianController` | 426 | HeianService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 234 | `Controllers/Moveset/Hiromi/Base/JusticeServedController` | `JusticeServedController` | 387 | JusticeServedService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 235 | `Controllers/Moveset/Itadori/Awake/MalevolantShrineController` | `MalevolantShrineController` | 254 | MalevolantShrineService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 236 | `Controllers/Moveset/Itadori/Awake2/CleaveController` | `CleaveController` | 303 | CleaveService | FXController, HitboxController | ✓ | KnitStart | Effects, Hitbox | 1 / 0 |
| 237 | `Controllers/Moveset/Mahito/PreAwk/SelfPerfectionController` | `SelfPerfectionController` | 257 | SelfPerfectionService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 238 | `Controllers/Moveset/Mechamaru/AbsoluteController` | `AbsoluteController` | 1660 | AbsoluteService, MechamaruService | FXController, HitboxController | ✓ | KnitStart | Effects, DropkickHitbox, EjectHitbox | 2 / 0 |
| 239 | `Controllers/Moveset/Megumi/Mahoraga/MahoragaController` | `MahoragaController` | 271 | MahoragaService | FXController, HitboxController | ✓ | KnitStart | Effects, Hitbox | 1 / 0 |
| 240 | `Controllers/Moveset/Nanami/Awake/RatioBreakerController` | `RatioBreakerController` | 928 | RatioBreakerService | FXController, HitboxController | ✓ | KnitStart | Effects | 1 / 0 |
| 241 | `Controllers/Moveset/Nanami/Base/BluntCutController` | `BluntCutController` | 532 | BluntCutService | FXController, HitboxController | ✓ | KnitStart | Effects, Hitbox | 1 / 0 |
| 242 | `Controllers/Moveset/Naoya/Awake/TimeCellMoonPalaceController` | `TimeCellMoonPalaceController` | 309 | TimeCellMoonPalaceService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 243 | `Controllers/Moveset/Reggie/Awake/HouseController` | `HouseController` | 221 | HouseService | FXController, HitboxController, ToolController | ✓ | KnitStart | Effects | 2 / 0 |
| 244 | `Controllers/Moveset/Reggie/Awake/RoadRageController` | `RoadRageController` | 310 | RoadRageService | FXController, HitboxController, ToolController | ✓ | KnitStart | Effects | 1 / 0 |
| 245 | `Controllers/Moveset/Ryu/Awake/ThisDessertController` | `ThisDessertController` | 431 | ThisDessertService | FXController, MokouController | ✓ | KnitStart | Effects | 0 / 0 |
| 246 | `Controllers/Moveset/Ryu/RyuController` | `RyuController` | 648 | RyuService | FXController, HitboxController, MokouController | ✓ | KnitStart | Effects | 0 / 0 |
| 247 | `Controllers/Moveset/Toji/COATM/LassoController` | `LassoController` | 302 | LassoService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 248 | `Controllers/Moveset/Toji/COATM/WhiplashController` | `WhiplashController` | 265 | WhiplashService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 249 | `Controllers/Moveset/Toji/ISOH/RuptureController` | `RuptureController` | 346 | RuptureService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 250 | `Controllers/Moveset/Toji/ISOH/TranscendController` | `TranscendController` | 167 | TranscendService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 251 | `Controllers/Moveset/Toji/SSK/DebilitateController` | `DebilitateController` | 414 | DebilitateService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 252 | `Controllers/Moveset/Toji/SSK/FlourishController` | `FlourishController` | 817 | FlourishService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 253 | `Controllers/Moveset/Toji/TojiController` | `TojiController` | 569 | TojiService | FXController, HitboxController | ✓ | KnitStart | Effects | 0 / 0 |
| 254 | `Controllers/Moveset/Uro/TurbulanceController` | `TurbulanceController` | 336 | TurbulanceService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 255 | `Controllers/Moveset/Yuta/Awake/MutualLoveController` | `MutualLoveController` | 877 | MutualLoveService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 256 | `Controllers/Moveset/Yuta/Base/EnergyRippleController` | `EnergyRippleController` | 416 | EnergyRippleService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 257 | `Controllers/RankedController` | `RankedController` | 533 | RankedService | DuelController, FXController, FinalShowdownController, NightParadeController, RouletteController | ✓ | KnitStart | Filter, Teleport | 0 / 0 |
| 258 | `Controllers/RankedController/DuelController` | `DuelController` | 573 | DuelService | FXController | ✓ | KnitStart | Effects | 0 / 0 |
| 259 | `Controllers/WorkshopController` | `WorkshopController` | 794 | ShopService, WorkshopService | FXController, ShopController | ✓ | KnitStart | Buy, Load | 0 / 2 |

Gone since 1.82: `Controllers/Moveset/Reggie/Awake/ArsonController`.

### 17.8 Systems new to this reference

| System | Controller → service | What the client shows |
|---|---|---|
| Kogane (lobby companion) | `KoganeController` → `KoganeService` (`RE`: `Action`, `Effects`, `Playlist`; `RF`: `ActivateShenanigans`) | `Action:Fire("Spawn" | "Pet" | "Leaderboard" | "Shenanigans" | "Playlist")`; `Playlist:Fire(list)`. Effects: Interpolation, TweenSize, PlaySound, Despawn, Speak, Sad, LeaderboardStats, Shenanigans, UpdatePetTimer, Playlist. Listens to `HandicapService.LastHit` (new remote). 1.85 added seven "shenanigans" (Liquidation, Transfer, Sunrise, Nightmare, Steed, Void Strider, Overproduction); one prefab reads "Your next respawn is where you last died" |
| Halloween candies | `CandiesController` → `CandiesService` (`OpenShop`, `Purchase`) and `ShopService` | Player attribute `Candies2026`. `CandiesService.Purchase:Fire("Emote" | "Skin" | "OldEmote" | "Item")`; Robux top-ups via `ShopService.Purchase("Candies<N>", "Robux")`. GUIs `Candies`, `CandiesMobile`, `HalloweenShop`. Candies come from kills and events |
| Shop | `ShopController` → `ShopService` (`RE`: `Chat`, `Code`, `Notification`, `Preview`, `Purchase`, `SendRobux`, `UpdateOdds`; `RF`: `GetGiftProducts`) | `Purchase(itemKey, "Robux" | "Cash" | "Gamepass" [, giftTarget])` with keys `Emote<N>`, `Skin<N>`, `MVP`, `Soda`, `Item`, `WorkshopSlot`; `Code:Fire(text)` redeems a code; `UpdateOdds("Emotes" | "Skins" | "MVPs")`; `SendRobux(receiverId, amount)` (gifting) |
| Achievements | `AchievementController` → `AchievementService` (`Daily`, `Request`, `Update`, `Weekly`) | Daily and weekly quest lists with a refresh countdown ("Refreshes in:", "Total Progress:"); `Update` arrives with four arguments whose meaning is not evident from the handler alone |
| Tutorial / Game Info | `TutorialController` (no service) | `Menus.Group.Tutorial_Info`: topic list from `Modules.Info_Tutorial`, each `{title, heading, videoAssetId, {paragraphs}}` |
| Ranked and duels | `RankedController` → `RankedService` (`Filter`, `Teleport`); `DuelController` → `DuelService` (`Effects`, `MatchEnd`, `Vows`) | `Teleport:Fire(mode [, arg])` with modes 1–6 (4 = join by user id / key, 6 = follow a visitor id, 3 = code text); `Filter:Fire(n [, text])` for the server browser. Duel effects: Countdown, Result, Vows, Teleport, Menu, MenuClose, Rematch. Binding vows are chosen with `Vows:Fire(name)`; the card text includes "0.9x DMG for all but your last lives", "1.25x DMG your last life", "Awakening automatically activates", "Death when awakening ends", "Instantly restore all health when activating awakening". Workspace attribute `Match` hides Shop, Inventory and Gamemodes |
| Workshop (shared custom movesets) | `WorkshopController` → `WorkshopService` (`Buy`, `CustomUpload`, `DataLoad`, `DataQuery`, `Delete`, `Donate`, `Favourite`, `Load`, `Report`, `Upload`) | Browse, load, upload, report and buy community movesets by `_id`. Gated by player attribute `Workshop`; slots bought with `ShopService.Purchase("WorkshopSlot", …)`. "Data over 200k characters cannot be previewed" |
| Destruction replication | `DebreeController` (+ `BufferRead`) → `DebreeService` (`Create`, `Destroy`, `Domain`, `Loaded`, `MoveAway`, `MoveIn`, `Physics`, `Sound`) | The "new destruction system" the log says was brought back: the client announces `Loaded`, then receives buffer-packed create/physics/destroy batches |
| Emote effects | `EmoteController/Effects` (40 KB) | The child module §1 listed as absent |

### 17.9 Settings modules

`ReplicatedStorage.Modules.Settings/<Tab>/<Name>` — `Val` is the key sent with `JoinService.Setting:Fire(Val, value)` and mirrored in `_G.Settings`; `Btn` is the control type (inferred from the rows: 1 toggle, 2 text/id entry, 3 slider, 4 opens a sub-menu). The `Fun` tab entries have no `Val`: they are local visual filters.

| Tab | Setting | `Val` | Btn | Description |
|---|---|---|---|---|
| Audio | Background Music | `VolMS2` | 3 | Change the volume for background music |
| Audio | Combat Music | `VolMS3` | 3 | Change the volume for combat music |
| Audio | Custom Death Sound | `Deathsound` | 2 | Changes your Death Sound |
| Audio | Custom Kill Sound | `Killsound` | 2 | Changes your Kill Sound |
| Audio | Custom Sounds | `VolKS` | 1 | Toggle global player custom sounds |
| Audio | Effect | `VolFX` | 3 | Change the volume for sound effects |
| Audio | Music | `VolMS` | 3 | Change the volume for music |
| Audio | Taunt | `VolTA` | 3 | Change the volume for taunts |
| Audio | Voice | `VolVA` | 3 | Change the volume for voicelines |
| Controls | Auto Respawn | `AutoRes` | 1 | Automatically respawn when available |
| Controls | Auto Run | `AutoRun` | 1 | lazy man >:P |
| Controls | Auto Use | `AutoUse` | 1 | Automatically use skills when pressing keys |
| Controls | Keybinds | `Keybinds` | 4 | Change what keys you need to press to use your abilities |
| Controls | Menu Scale | `UIS2` | 3 | Change the scale of some menus |
| Controls | Sensitivity | `SENS` | 3 | Change the sensitivity multiplier |
| Controls | Toolbar Offset | `TBO` | 3 | Change the offset of the toolbar |
| Controls | UI Scale | `UIS` | 3 | Change the scale of your toolbar / guides |
| Fun | Bloodbath | `—` | 1 | paint the world red |
| Fun | Bloom | `—` | 1 | this will be what jjs will look like in 2014..... |
| Fun | Cherry | `—` | 1 | pink everywhere |
| Fun | Darkness | `—` | 1 | OLED |
| Fun | Goodnight | `—` | 1 | When you just need that little nap |
| Fun | Gravity | `—` | 1 | The world is upside down, scream. |
| Fun | Headcam | `—` | 1 | yo clip this chat |
| Fun | Invert | `—` | 1 | Reverse the colors and see the world in a new view |
| Fun | Jolly | `—` | 1 | snow everywhere |
| Fun | Rain | `—` | 1 | rain everywhere |
| Fun | Sunset | `—` | 1 | When you just need to chill |
| General | Awakening Outfit | `Outfit` | 4 | Changes your outfit when awakened |
| General | Blood | `Gore` | 1 | Toggles blood visibily or recolors it |
| General | Camera Follow | `Follow` | 1 | Keeps the camera focused on your peanut head ;) |
| General | Damage Counter | `DmgCounter` | 1 | See how much damage you deal |
| General | Flashing Lights | `Flash` | 1 | Reduces flashing lights and impact frames |
| General | Game Info | `—` | 4 | Read about mechanics, tips and tricks |
| General | Hide Kills | `HiddenKills` | 1 | Hides your kills on the leaderboard |
| General | Screen Shake | `ScreenShake` | 1 | Enable or disable screen shaking |
| General | Server Region | `Region` | 1 | View the current server's location |
| Performance | Destruction Interpolation | `DesINT` | 1 | Interpolates the movement of destroyed parts |
| Performance | Destruction Smoke | `DesVFX` | 1 | Creates smoke effects when parts are destroyed |
| Performance | FPS Counter | `FPS` | 1 | See your current framerate |
| Performance | Physics VFX | `DesPHY` | 1 | Toggles the visibility of physics heavy effects |
| Performance | Ragdoll SFX | `RagSFX` | 1 | Toggle the audios that plays when limbs collide with parts |
| Performance | Shadows | `Shadows` | 1 | Render shadows globally |

New in 1.85 by the log: `Auto Respawn` (Controls) and `Damage Counter` (General).

### 17.10 The 1.85 update log, transcribed

From `UpdateLogController.Updates`, in the order shown in game.

- **HALLOWEEN**
  - We travelled to a different city!
  - Gather candies by getting kills or completing various events and go through the portal to exchange them for exclusive emotes, skins and a broom item!
- **HIRED HUNTER**
  - ADDED 1 NEW SPECIAL (Hidden Inventory)
  - ADDED 1 NEW MOVE (Flourish)
  - ADDED 1 NEW VARIANT (The Wrath)
  - ADDED 1 NEW VARIANT (The Greed)
  - ADDED 1 NEW VARIANT (The Pride)
  - ADDED 1 NEW MOVE (Debilitate)
  - ADDED 1 NEW MOVE (Transcend)
  - ADDED 1 NEW VARIANT (Ascend)
  - ADDED 1 NEW MOVE (Rupture)
  - ADDED 1 NEW VARIANT (Paradise)
  - ADDED 1 NEW VARIANT (Reincarnation)
  - ADDED 1 NEW MOVE (Lasso)
  - ADDED 1 NEW MOVE (Whiplash)
  - ADDED 1 NEW VARIANT (Twirling Strike)
- **REGISTER**
  - REGISTER HAS BEEN RELEASED TO THE PUBLIC!
  - ADDED 1 NEW AWAKENING MOVE (Road Rage)
  - ADDED 1 NEW AWAKENING MOVE (132-Square-Foot Two-Story House)
  - *GENERAL*
    - Big Moves somewhat reworked
    - Littering and Gushing Wound now properly stick to objects and throwables
- **SKY BENDER**
  - *GENERAL*
    - Reduced the hitlag of R+3
    - Added a height requirement to the aerial evasive
    - You can no longer lock onto the user when invisible
  - *TURBULENCE*
    - Increased the hitbox size of Aerial Turbulence
  - *SKY DISTORTION*
    - Sky Distortion Temper now knocks the enemy away when close to you
- **PUPPET MASTER**
  - Removed that god awful multi npc body system for Absolute (I HATE IT I HATE IT THERES SO MANY BUGS)
  - *AWAKENING*
    - Melee attacks now consume your awakening
    - Adjusted the cost of skills during your awakening
- **DISASTER PLANTS**
  - Chain knockback spikes damage reduced by 1 (7 -> 6)
  - *SURGING THORNS*
    - Surging Thorns damage reduced by 4 (5-5-5 -> 3-3-5)
    - Surging Thorns special variant normal damage reduced by 3 (9 -> 6)
    - Surging Thorns special variant block break / interrupt damage boost reduced by 1 (3 -> 2)
- **SHOP**
  - ADDED SKINS
  - ADDED 2 NEW ITEMS (C4, RPG)
  - ADDED 1 NEW VICTORY FLASH (Final Dessert)
  - ADDED 12 NEW EMOTES (Cory, California Girls, I'm all ears, Ex Provocation2, Join us for a bite, Wildside, In My Mind, Malo Mart, Richard, Jumper, Hollow Bench, Victory Lap)
  - *GENERAL*
    - Removed 2x option for buying emotes
    - Gravestone now displays the last kill
    - Transfigured Flesh wall is now breakable
    - Added sound effects for Pistol Trick emote
- **KOGANE**
  - ADDED 7 NEW SHENANIGANS (Liquidation, Transfer, Sunrise, Nightmare, Steed, Void Strider, Overproduction)
  - ADDED A NEW PLAYLIST BUTTON TO KOGANE
  - Kogane can now respond to basic chat messages from players
  - *QOL*
    - Added icons to Kogane buttons
    - Added timer for the pet daily reward
- **DOMAIN**
  - Roach Swarm domain barrier damage reduced by 60%
  - Slicing Exorcism domain barrier damage reduced by 70%
  - Defense Response domain barrier damage reduced by 25%
  - Perfection club fists domain barrier damage reduced by 65%
  - Disaster Plants uppercuts and downslam domain barrier damage reduced by 50%
  - *CLASHING*
    - Slightly reduced the cooldown of dashing during a domain clash
    - You can no longer be hit by non-melee attacks during a domain clash
    - You can now use domain expansions during your awakening if you are within the range of an opening domain expansion
- **PERFORMANCE**
  - Brought back the new destruction system
  - Improved anchoring of moving parts from destruction
  - Improved destruction replication (should fix most lag spikes, but server size is also bigger so be aware of that)
- **DUELS**
  - Ranked now removes the grass
  - Ranked no longer has destruction
  - Ranked will temporarily default to the flat map until the new maps are fixed
- **COMBAT**
  - Hitting a player now triggers combat tag
  - Hitting dead players no longer gives awakening
  - You no longer automatically respawn (A setting is available under [Controls] to revert the change)
- **SKILL BUILDER & BUILD MODE**
  - ADDED 1 NEW BLOCK (Water)
  - ADDED 3 NEW VISUAL EFFECTS (HighlightCore, HighlightFocus, HighlightOutline)
  - *ANIMATIONS*
    - Added missing animations for Vessel
    - Added missing animations for Switcher
    - Added missing animations for Salaryman
    - Added missing animations for Perfection
    - Added missing animations for Monkey Kid
    - Added missing animations for Black Death
    - Added missing animations for Sky Bender
    - Added missing animations for Head of the Hei
  - *GENERAL*
    - Added horses to the Vehicle Block
    - Fixed Particle Node being uncancellable in other branches
- **PRIVATE SERVER+**
  - ADDED 2 NEW SERVER SETTINGS (Respawn Debris, Debris Respawn Time)
  - *QOL*
    - Reorganized layout of server settings
- **GENERAL**
  - ADDED 1 NEW GENERAL SETTING (Damage Counter)
  - *QOL*
    - Added captions to all topbar buttons
    - Added a visible glow to items that are on the ground
    - Improved ragdoll controls when dead or using the Ragdoll emote
    - Water now has a different visual effects when landed on at high speeds
  - *ACHIEVEMENTS*
    - Changed the obtainment method for one achievement
- **BUG FIXES**
  - Fixed Jeep emote not consistently working
  - Fixed being able to glide with skateboard emote
  - Fixed Cursory Impact giving double Projection Meter
  - Fixed ragdolls triggering a lot of debris effects at once
  - Fixed TNT flinging the target if grabbed by another player
  - Fixed Sky Bender's moveset being unavailable in skill builder
  - Fixed "I love the taste of iron!" achievement not being obtainable
  - Fixed 0.2 Infinite Void sometimes permanently locking all of your skills
  - Fixed outside forces killing players not giving kill rewards to other players
  - Fixed stationary parts from destruction still being interpolated on the client
  - Fixed being able to hit people with Sky Bender's 2nd melee attack if the enemy isn't ragdolled
  - Fixed skill builder's linked hitboxes being able to slip through other hitboxes if they're large enough
  - Fixed extra emote pages having issues loading after 32 (do not ask me why some players bought that many)
  - Fixed Murmurate's variant knockback being in world space instead of relative to the height (basically more consistent)

### 17.11 Open after 1.85

- How long after death `CanRespawn` appears, and whether `JoinService.Respawn` is rate-limited.
- Whether `Change` is accepted from a dead character (which would fold respawn and character switch into one request).
- Whether the combat tag from *landing* a hit locks `Change` for the same ~14 s as being hit, and whether any replicated flag exposes it.
- Toji: the stance order and swap cooldown, what grants `FastSwap`, what selects each named variant, every cooldown and damage value, and the whole awakening.
- What `TojiService.Hitbox` is for — no client code fires or connects it.
- Whether Road Rage and House use the last point streamed or the first, and what they do when the caster's client sends nothing.
- What enables the `Characters` topbar icon, given the readable code creates it disabled.
- `Chara`: an `UltNames` entry with nothing else behind it.

---

## 18. Public-source research (wiki and guides), Nov 2026

*This section is not from the game files. It is what the public wiki and guides say about how moves behave, gathered on 2026-11-09 to tell the bot what each move is for.*

**How far to trust it.** Every page fetch was refused by the research session's network settings, so every fact below was read from web-search extracts of the cited page, not from the page. The search tool reported most wiki pages as about 100 days old, and the sources call the Halloween update V1.84 where the place file says 1.85. Where sources disagree both values are kept. Blanks mean the source did not say. The bot treats all of it as a starting belief and corrects it from its own casts (see `TACTICS.md`, v87); the raw entries with full descriptions and source URLs are in `research/group1.json` to `group5.json`.

What it adds to §1 to §17: the server-side facts the client dump cannot show. Whether a move can be blocked, whether it reaches a body on the ground, counter windows, the four-hit basic string and its three endings, the evasive meter, dash distances.

### 18.1 Mechanics


#### Basic attacks (M1)

| Fact | Source |
|---|---|
| Holding or repeating M1 chains up to four hits, a 4-hit string dealing 14 damage in total (3 + 3 + 4 + 4). | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| After the 4-hit M1 string finishes, M1 goes on a downtime of 2 seconds. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| A landed M1 stuns the target for about 0.75 s and pulls the attacker about 1 stud towards the target. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| A blocked M1 carries double the endlag for the attacker. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| The fourth M1 is the hit that ragdolls, and which variant comes out depends on the attacker's vertical movement at that moment. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Fourth M1 with no vertical speed (neutral): knocks the enemy backwards and has the shortest ragdoll of the M1 variants. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Uppercut: fourth M1 while moving upward (jumping). It is an uptilt that knocks the enemy into the air and has the longest ragdoll duration of all M1 variants because of the target's airtime. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Downslam: fourth M1 while falling after a jump. It is unblockable and bypasses ragdoll (it can hit a ragdolled target). | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Uppercuts and downslams refill the VICTIM's ragdoll-cancel meter when they land on a target that is ragdolled or just waking up; one extract of the page gave the amount as +20% (downslam on a ragdolled target, or uppercut / neutral fourth M1 on wakeup). A second extract of the same page did not show the 20% figure. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Sources disagree on M1 damage: the games.gg beginner guide says the first two hits deal 3 and the last two deal 2 (10 total), while the Fandom wiki says 3 + 3 + 4 + 4 (14 total). | https://games.gg/roblox/guides/jujutsu-shenanigans-beginners-guide/ |
| games.gg describes the inputs as: jump before the fourth hit for a ground slam, hold jump during the combo for an uppercut. | https://games.gg/roblox/guides/jujutsu-shenanigans-beginners-guide/ |
| Uppercut-surfing tech: holding jump during an M1 chain and delaying the fourth input lets you jump on the opponent's head while uppercutting, gaining height and lengthening the opponent's ragdoll time. (The search extract said one tech on this page is marked outdated without saying which.) | https://jujutsu-shenanigans.fandom.com/wiki/Techs |
| No source found states a general 'M1 cancels into skills at time X' rule. What the wiki does state: a side/back dash can be used during the startup of abilities or M1s at the cost of a slight delay in their windup. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Skills are routinely used between M1s in wiki combo listings, e.g. Sky Bender: '3 M1s + Blind Rage + 3 M1s + Turbulence + Thin Ice Breaker + 4 M1s' for 75 damage. The pattern is to stop at 3 M1s (before the ragdolling fourth hit), use a skill, and only finish with the full 4. | https://jujutsu-shenanigans.fandom.com/wiki/Sky_Bender |
| Character-specific 'M1 reset' techs exist and are timing-tight: Vessel must use a move within a few frames after the first M1; Locust Guy gets a full reset from one M1 followed immediately by Clever (four M1s instead of three); True Cannon resets with an uncharged Granite Blast during the string. (Each is on that character's own wiki page: /wiki/Vessel, /wiki/Locust_Guy, /wiki/True_Cannon.) | https://jujutsu-shenanigans.fandom.com/wiki/Vessel |

#### Blocking

| Fact | Source |
|---|---|
| Block is the main defensive option: it nullifies the damage and/or stun of incoming attacks in exchange for slower movement and the inability to attack or dash while blocking. On PC it is held with F (rebindable). | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Blocking only works within a 170-degree arc in front of the blocker; some attacks are tagged as blockable from all sides. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Block is not blanket immunity: some attacks deal reduced damage on block, some are entirely unblockable, some can only be 'perfect-blocked' by blocking before impact, and some get stronger when blocked. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| The downslam (fourth M1 while falling) is unblockable; the neutral and uppercut fourth hits are not described as unblockable. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Blocking an M1 doubles the attacker's endlag, and a blocked front-dash punch also gets additional endlag, so a successful block hands the blocker the next action. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Attacks from behind bypass block: listed techs are the wrap-around (front dash past the defender while flicking the camera 180 degrees so the hit lands from behind) and side dash + M1. | https://jujutsu-shenanigans.fandom.com/wiki/Techs |
| NamuWiki agrees: F blocks normal attacks and some skills coming from the front, attacks from behind cannot be blocked, and some skills/basic attacks can be defended from all 360 degrees. | https://en.namu.wiki/w/Jujutsu%20Shenanigans |
| The wiki tags each move individually: UNBLOCKABLE, BLOCKABLE, SEMI BLOCKABLE, BLOCKABLE FROM ALL SIDES, plus INTERRUPTIBLE / UNINTERRUPTIBLE. Blockability is per move, not per move type. | https://jujutsu-shenanigans.fandom.com/wiki/Vessel |
| Sources disagree on grabs: the gamesving beginner guide says some abilities break guard and 'grabs completely ignore blocking', but the Fandom wiki tags Black Death's Chokehold as a BLOCKABLE grab. Treat grab blockability as per-move. | https://gamesving.com/guides/jujutsu-shenanigans-beginner-guide/ |
| No general block-durability meter and no general guard-break stun duration was found. Block breaks are described only on individual moves (e.g. Defense Attorney's Justice Served leaves a blocking target 'block broken on the floor for a few seconds', which the page calls visual only). | https://jujutsu-shenanigans.fandom.com/wiki/Defense_Attorney |
| Some moves punish blocking specifically: Perfection's Homerun bypasses guard and removes the blocker's ragdoll cancel; Club Mode's last 2 hits bypass block entirely. | https://jujutsu-shenanigans.fandom.com/wiki/Perfection |
| No universal parry was found. 'Perfect block' in the wiki means blocking before impact, required for certain attacks. Separately, 'counters' are a class of ability: the user enters a brief stance and, if hit during it, evades or blocks and strikes back while disabling the attacker's ragdoll cancel. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| No source found states a delay between releasing block and acting. The only stated restriction is that you cannot attack or dash WHILE blocking. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Guide advice: do not rely on block alone; mix it with side dashes and movement so you are harder to read. | https://gamesving.com/guides/jujutsu-shenanigans-beginner-guide/ |
| Guide advice: blocking too early lets the opponent wait out the guard; react to the swing instead. (Attribution within the jujutsushenanigans.org / gamesving extracts was not precise.) | https://jujutsushenanigans.org/ |

#### Ragdoll cancel (evasive)

| Fact | Source |
|---|---|
| Ragdoll cancel (the 'evasive') is a side dash performed while ragdolled: the user quick-steps and gets up from ragdoll while gaining about a second of i-frames. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| It is gated by a meter that refills from both dealing and taking damage. Above 50 HP the bar fully charges after sustaining about 77 damage or dealing 200 damage; at 50 HP or below it charges faster. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| One extract of the page gave low-HP fill figures of 62.5 damage taken or 100 damage dealt (damage dealt counting double at 50 HP or below). The extract attached them to the Awakening bar, but 100 is exactly half of the ragdoll-cancel figure of 200, so they most plausibly belong to the ragdoll-cancel bar. Unresolved. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| History: the meter was added in the V1.51-V1.60 range so players manage ragdoll cancels; it is instantly restored after every kill and gained by being damaged or damaging enemies. A later update tuned gain per damage and made it slowly regenerate out of combat or when healing with a soda. | https://jujutsu-shenanigans.fandom.com/wiki/Update_Log/V1.60_to_V1.51 |
| The 'Evade 50' value shown on characters was not explained by any source found. The only 50 the wiki ties to the evasive is the 50 HP threshold below which the ragdoll-cancel bar charges faster. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| True ragdoll cannot be evaded, but its timer starts counting down immediately on hit. A regular ragdoll only starts counting down once the player touches a surface (so being juggled in the air prolongs it). | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| After getting up from ragdoll the player stands immediately and has about 0.5 s of immunity to melee stun. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Things that remove the option: counters (disable ragdoll cancel on the player who hit them), and specific moves such as Restless Gambler's Overwhelming Luck (until its last hit), Perfection's Homerun on a blocking target, Lucky Coward's Trip on a moving target, and grabs like Perfection's Heart Piercer (no escape until the move ends). | https://jujutsu-shenanigans.fandom.com/wiki/Perfection |
| Move tags that matter after a knockdown: BYPASSES RAGDOLL means the move can hit a target lying in grounded ragdoll; CANNOT BYPASS GROUNDED RAGDOLL means it whiffs on one; TRUE RAGDOLL marks an unevadable ragdoll. Meanings are read from usage; the wiki has no single glossary in the extracts. | https://jujutsu-shenanigans.fandom.com/wiki/Head_of_the_Hei |
| The op.gg guide agrees in outline: watch the evasive bar; true ragdolls and moves that disable evasives cannot be escaped; dealing or taking damage refills the resource and a kill refills it fully. | https://op.gg/roblox/wiki/jujutsu-shenanigans/guides |
| Sources describe the input differently: the wiki says side dash while ragdolled; the op.gg game listing says 'Q - dash (use in stun to escape)'; games.gg says press Q while holding M1 toward the enemy after being hit, and that missing the window means eating the full combo. | https://games.gg/roblox/guides/jujutsu-shenanigans-beginners-guide/ |
| Landing certain moves is punishable by the victim's ragdoll cancel (Vessel's Divergent Fist and Aerial Cursed Strikes), so the wiki advises using them only after baiting the evasive out first. | https://jujutsu-shenanigans.fandom.com/wiki/Vessel |
| games.gg: dashing toward the opponent during their windup or endlag turns the cancel into a punish. | https://games.gg/roblox/guides/jujutsu-shenanigans-beginners-guide/ |

#### Dashes

| Fact | Source |
|---|---|
| Front dash (dash while moving forward or standing still): the user slides forward about 20 studs while winding up a jab, then punches. Cooldown 6 s. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| The front-dash punch deals 4 blockable melee damage, cannot bypass grounded ragdoll, and has additional endlag when blocked. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| The front-dash punch normally stuns, but it ragdolls any enemy it meets before the dash has travelled half its full distance (i.e. at point-blank). | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Side or back dash: a quick-step that slides about 17.5 studs in the direction the player was walking. Cooldown 2 s. Its trajectory can be steered by turning mid-dash. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Front side dash (anti-run): if the front dash goes on cooldown while chasing a target, a 'front' side dash is allocated and can repeat while the regular front dash is on cooldown. It is unavailable if the running target turns to face back, or if the pursuer faces away. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| No i-frames are stated for ordinary dashes. The only stated dash invulnerability is the roughly 1 s of i-frames on a ragdoll cancel. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Default keys per the op.gg game listing: M1 melee combo, 1-4 skills, Q dash, F block, R special, W+W sprint (automatically avoids obstacles), G awaken. | https://op.gg/roblox/games/3508322461 |
| Guide advice: a forward dash is a good way to pressure and close the gap before starting a combo. | https://gamesving.com/guides/jujutsu-shenanigans-beginner-guide/ |

#### Combos

| Fact | Source |
|---|---|
| A combo is a sequence where each hit connects before the defender can block, dash away or ragdoll cancel. If the opponent can interrupt, it is a string with an escape window, not a guaranteed combo. | https://jujutsushenanigans.org/combos/ |
| 'True combo' as defined by sabertoothgames: zero gap between hits, i.e. the hitstun from the previous hit is longer than the startup of the next attack. (The search tool flagged another article on this site as generic, so weight it lightly.) | https://sabertoothgames.com/how-to-chain-combos-per-character-in-jujutsu-shenanigans/ |
| Since a landed M1 stuns for about 0.75 s, the next hit of a true string has to start inside that window. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Universal beginner opener per jujutsushenanigans.org: three M1 hits into a downslam, then one skill; check that it works for your character, because follow-ups vary by moveset and opponent state. | https://jujutsushenanigans.org/combos/ |
| sabertoothgames: downslam resets are generally true if you act immediately during the ragdoll animation. | https://sabertoothgames.com/how-to-chain-combos-per-character-in-jujutsu-shenanigans/ |
| Typical wiki combo shape: 3 M1s -> skill -> 3 M1s -> skill -> skill -> 4 M1s (Sky Bender, 75 damage). Listed Sky Bender Temper combos fall in the 58-75 damage range. | https://jujutsu-shenanigans.fandom.com/wiki/Sky_Bender |
| gamesving describes the basic pattern as M1, then dash, then skill, then a follow-up attack, and warns that throwing abilities from long range gives the opponent plenty of time to escape. | https://gamesving.com/guides/jujutsu-shenanigans-beginner-guide/ |
| What ends a combo, pieced together from the wiki: the fourth M1 ragdolls and knocks the target away and puts M1 on a 2 s downtime; the defender's ragdoll cancel (about 1 s of i-frames); follow-ups tagged CANNOT BYPASS GROUNDED RAGDOLL whiffing on a floored target; and the roughly 0.5 s melee-stun immunity on wakeup. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Walls help extend: pushing a ragdolled enemy into a wall reduces knockback so a combo can continue without spending a dash (stated for Aspiring Mangaka's Shut Up! after an uppercut). | https://jujutsu-shenanigans.fandom.com/wiki/Aspiring_Mangaka |
| itemlevel's Nanami guide notes that longer strings rely on reads and pressure rather than being true combos. | https://itemlevel.net/jujutsu-shenanigans-nanami-guide-salaryman/ |

#### Awakening

| Fact | Source |
|---|---|
| The Awakening bar sits above the skill boxes and only fills as damage is dealt; it loses all progress when switching characters. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| It takes about 286 damage dealt in total (2000/7) to fill; the user briefly flashes white when the bar reaches maximum. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| One extract says that at 50 HP or below damage taken also feeds the bar and damage dealt counts double, and that a kill or landing the anti-team burst fills it to maximum. The V1.60 log says the same 'restored after every kill' rule about the ragdoll-cancel bar, so which bar these lines describe was not fully clear from the extracts. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Awakening for a complete character: a brief invulnerable sequence with some healing, then an awakening moveset that lasts about a minute. Some characters must meet requirements first, and 'Base-only' characters have no awakening. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| Halloween patch: hitting dead players no longer grants awakening. | https://games.gg/roblox/guides/halloween-candy-shop-rewards-patch-notes/ |
| Sources disagree on fill sources: beginner guides say awakening builds from landing M1s, using your technique and surviving exchanges, while the wiki says the bar only fills as damage is dealt. | https://gamesving.com/guides/jujutsu-shenanigans-beginner-guide/ |
| Guide advice on timing: do not cast the moment it is ready; wait until the opponent cannot interrupt the 1.25 s windup. 'An uppercut after an evasive' is called the most reliable setup. (The extract tied the 1.25 s figure to the domain windup, and did not say which of the jujutsushenanigans.org / gamesving pages it came from.) | https://jujutsushenanigans.org/ |
| Character-specific bars differ. Sky Bender's Temper is a passive on the Awakening bar that fills four times faster, activates with the Awakening button, drains after 15 s without dealing damage, and shortens all active cooldowns to 3 s. | https://jujutsu-shenanigans.fandom.com/wiki/Sky_Bender |

#### Domains

| Fact | Source |
|---|---|
| A domain is a move category that expands after a short hand-sign windup; those caught inside are frozen in a neutral stage while on-screen text explains that domain's rules. | https://jujutsu-shenanigans.fandom.com/wiki/Domain_Expansion |
| A domain clash happens when two or more players cast their domain expansions simultaneously; a caster who loses the clash is refunded 75% of the Awakening bar. | https://jujutsu-shenanigans.fandom.com/wiki/Domain_Expansion |
| A clash meter appears above each participant's bar and after 10 seconds the player with more progress on it wins. (The extract tied this wording to the True Love Beam clash on the mechanics page.) | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |
| bloxodes: during a clash sure-hit pressure is disabled, landing hits fills the clash bar, and the winner keeps their domain while the losing domains are cancelled. | https://bloxodes.com/articles/jujutsu-shenanigans-domains-explained |
| A domain can be stopped at startup: any attack during the 1.25 s windup (a single M1, a projectile or any stun) cancels it. bloxodes agrees that interrupting the startup is cleaner than dealing with the domain afterwards. (Which jujutsushenanigans.org page carried the 1.25 s figure was not precise in the extract.) | https://jujutsushenanigans.org/how-to-invade-domains/ |
| Inside slash-style domains blocking is recommended; Time Cell Moon Palace punishes movement and attacks, so blocking is the safer choice there too. | https://bloxodes.com/wiki/jujutsu-shenanigans/domains |

#### Combat tag and respawn

| Fact | Source |
|---|---|
| Halloween update patch notes: hitting a player now triggers combat tag, and hitting dead players no longer grants awakening. So the attacker is tagged too, not only the player who was hit. | https://games.gg/roblox/guides/halloween-candy-shop-rewards-patch-notes/ |
| Halloween update: players no longer respawn automatically. Automatic respawn is disabled by default and a 'Respawns' general setting can turn it back on (a Damage Counter setting was added in the same patch). | https://jujutsu-shenanigans.fandom.com/wiki/Update_Log |
| Version label: the sources found call the Halloween update V1.84, not V1.85. The wiki's version list has a V1.85 entry whose contents were not shown in the extracts. | https://games.gg/roblox/guides/halloween-candy-shop-rewards-patch-notes/ |
| An earlier update introduced combat tag as a 15-second lock after being hit during which the player cannot switch or reset characters. | https://jujutsu-shenanigans.fandom.com/wiki/Update_Log |
| The Halloween event ran from 23 October 2026 to 23 November 2026 22:00 UTC per the game's Roblox event listing as reported by games.gg. | https://games.gg/roblox/guides/halloween-candy-shop-rewards-patch-notes/ |

#### Neutral play

| Fact | Source |
|---|---|
| Most fights are decided by movement, positioning and knowing when to use skills rather than by fast ability use. | https://gamesving.com/guides/jujutsu-shenanigans-beginner-guide/ |
| The core exchange: get close without taking a punish, confirm hits, then block or dash out before the opponent turns the combo around. Most kits rely on opening hits, avoiding endlag and using the right move variant. | https://bloxodes.com/articles/roblox-anime-games-skill-combat |
| Do not throw abilities from long range: raw skills at distance give the opponent plenty of time to escape. Skills are meant to be confirmed off M1s. | https://gamesving.com/guides/jujutsu-shenanigans-beginner-guide/ |
| Missed moves carry endlag that is punishable (e.g. Crow Charmer's Impetus Updraft has 'major endlag' on a miss; Aspiring Mangaka's page notes punishable endlag on all its moves but one). | https://jujutsu-shenanigans.fandom.com/wiki/Crow_Charmer |
| Feints exist to bait defensive options: Vessel's special cancels an M1 or skill windup with no endlag and keeps the move off cooldown, and the wiki says it is mainly used to bait enemies into blocking or using a counter. | https://jujutsu-shenanigans.fandom.com/wiki/Vessel |
| If your attack is blocked, expect the opponent's full combo in return (stated in itemlevel's Vessel guide; consistent with the wiki's doubled endlag on blocked M1s). | https://itemlevel.net/jujutsu-shenanigans-yuji-itadori-vessel-guide-showcase/ |
| Bait the opponent's ragdoll cancel before committing your best move; several wiki techs are prefaced with 'need to waste their evasive before'. | https://jujutsu-shenanigans.fandom.com/f/p/4400000000000044707 |
| Button-mashing loses; games.gg recommends using training modes before PvP, and jujutsushenanigans.org recommends practising one extension at a time until it lands ten times in a row. | https://games.gg/roblox/guides/jujutsu-shenanigans-beginners-guide/ |
| Uppercut and downslam on a floored or waking opponent hand them ragdoll-cancel meter, so repeatedly re-launching the same target feeds their escape. | https://jujutsu-shenanigans.fandom.com/wiki/Controls_%26_Mechanics |

### 18.2 How this lines up with the game files

| Research says | Game files say (§ of this reference) |
|---|---|
| The fourth basic hit is a downslam when falling and an uppercut when rising | `ToolController` sends the direction itself: `"Down"` if `Humanoid.FloorMaterial == Air` and not swimming, else `"Up"` if `Humanoid.Jump`, else nothing. For Hanami the order is reversed (§17.3) |
| Ragdoll cancel is a side dash while ragdolled, gated by a meter | `MovementController.DashRequest` fires `MovementService.Dash(dir, true)` in any direction when `Info.Knockback` exists, or the character has `Burst` and `Info` does not, or `Info.ForceEsc.Value`. The meter is the character attribute `Evade`, 0 to 50 (§3) |
| Dash cooldowns: front 6 s, side and back 2 s | `DashRequest` enforces 2 s client-side for side and back dashes; the front dash goes through the moveset service as `Chase` |
| You cannot attack or dash while blocking | `DashRequest` returns early on `Info.Block`, `Info.Stun` and `Ragdoll > 0` |
| Cooldowns | `Moveset/<move>` attributes `ReadyAt` and `LastUse` are set by the server (§5); the bot now logs the difference next to the listed value |

### 18.3 Move catalogue

Family is the researcher's reading where the source did not state it. "Block" is the wiki tag; semi-blockable moves are listed as blockable because the opening hit is what a guard stops. "Ground" is whether the move reaches a body lying in ragdoll.

#### Gojo

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Lapse Blue | base | pull | blockable | hits | 12.5 total (5 pull + 7.5 kick) | 13 | 35 | no opponent under the cursor within 35 studs, or the target is blocking |
| Reversal Red | base | projectile | blockable | ? | 12.5 (6.25 if blocked) | 20 | 40 | short windup and interruptible; orb stops at 40 studs; half damage into a block |
| Rapid Punches | base | melee | unblockable | misses | 17.25 total | 15 | ? | the opening kick must connect on a nearby enemy; cannot hit a grounded ragdolled target |
| Twofold Kick | base | melee | blockable | hits | 10 total (6 first kick + 4 second) | 18 | ? | first kick blocked or out of melee range |
| Limitless | special | mobility | unblockable | hits | 0 (Limitless Air kick 8; Face Grater follow-up 10.2 over 3 h | 15 | ? | needs an enemy under the cursor; interruptible |
| Lapse Blue MAX | awakening | pull | unblockable | hits | about 44 total (2.2 per tick x 20 ticks) | 17 | ? | interruptible; pulled enemies can ragdoll-cancel away as soon as they are pulled |
| Reversal Red MAX | awakening | projectile | unblockable | ? | 30 down to 7 by distance (Fandom); about 5-34.4 +10 (NamuWik | 10 | 100 | interruptible; damage falls off with distance |
| Hollow Purple | awakening | projectile | unblockable | hits | 70 | 40 | ? | about 3 s charge before release; the hitbox does not cover the gap directly in front of the user |
| Infinite Void | awakening | domain | unblockable | hits | 0 | 120 | ? | interruptible while casting; the stun does not interrupt actions started before the sure-hit began |

#### Itadori

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Cursed Strikes | base | rush | blockable | misses | 17.5 ground / 14 air (NamuWiki); 14 (Fandom) | 18 | ? | blocked from any side; cannot hit a ragdolled target |
| Crushing Blow | base | grab | unblockable | hits | 12 total (6 per slam x2); 3 for the miss shockwave; NamuWiki | 15 | ? | a miss gives only a 3-damage shockwave with no stun; interruptible |
| Divergent Fist | base | melee | blockable | ? | 10 (5 per hit x2); Black Flash 10, or 20 on interrupting an  | 18 | ? | tagged 'partly bypasses ragdoll', so part of it misses downed targets; windup can be blocked |
| Manji Kick | base | counter | unblockable | hits | 8.5 | 20 | ? | does nothing unless the user is hit by a melee or bullet attack inside the 0.6 s window |
| Combat Instincts | special | other | ? | ? | 0 (throwable variant 15) | 2 | ? | only does something during an M1 or skill windup |
| Cleave | special | melee | ? | misses | 40% of target's current HP (minimum 10) | 12 | ? | cannot hit a grounded ragdolled target |
| Dismantle | awakening | projectile | blockable | ? | 17.5 total (1.75 per tick); 10 on block; NamuWiki: air varia | 13 | 30 | target beyond 30 studs; much weaker into a block |
| Open | awakening | projectile | ? | ? | 30 | 40 | ? |  |
| Rush | awakening | rush | ? | ? | 25 total (5 impact + 15 kick + 5 slam) | 15 | ? |  |
| Malevolent Shrine | awakening | domain | blockable | ? | 2 per slash, 156 over 78 slashes (0.5 per slash on block) | 120 | ? | targets who hold block take a quarter damage |

#### Hakari

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Reserve Balls | base | projectile | blockable | hits | 7.5 (NamuWiki); 13.5 total with the Shutter Doors variant | 12 | 65 | blockable; ball disappears after 65 studs |
| Shutter Doors | base | melee | blockable | misses | 8; miss variant 6 total over three bounces | 15 | ? | base hit cannot reach a ragdolled target; on a miss it becomes a 7 s lingering trap that does hit ragdolled targets |
| Rough Energy | base | melee | unblockable | hits | 12.5 ground; 8 air; 16 from above jump height | 14 | ? | slow windup and interruptible; the normal air version can be blocked |
| Fever Breaker | base | melee | blockable | misses | 15 total (5 kick + 10 dropkick); Fever Crush 20 (8 doors + 1 | 23 | ? | blockable; cannot hit a grounded ragdolled target |
| Door Guard | special | counter | ? | ? | 5 against melee, 0 against bullets | 16 | ? | needs the opponent to attack into it; only melee attackers take damage |
| Rhythm | special | buff | ? | ? | 0 | 8 | ? | if the dance is interrupted no buff is gained |
| Lucky Volley | awakening | melee | blockable | hits | 28.7 total (2.3 x 9 barrage + 8 final hit) | 10 | ? | barrage hits can be blocked; interruptible |
| Lucky Rushdown | awakening | rush | unblockable | hits | 24 total (14 grab + 10 throw) | 15 | ? | runs in a straight line and catches only what it runs into; interruptible |
| Overwhelming Luck | awakening | rush | ? | ? | 40 total | 20 | ? | charge-up before the rush |
| Energy Surge | awakening | rush | unblockable | hits | 20 total (10 per hit) | 25 | ? |  |

#### Megumi

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Rabbit Escape | base | summon | blockable | hits | 14 (0.7 per rabbit) | 18 | 40 | no enemy within 40 studs; being hit or stunned during the hand sign stops the rabbits from spawning |
| Nue | base | summon | unblockable | hits | 16 | 20 | ? | cannot be summoned while Rabbit Escape is swarming a grounded target; interruptible |
| Toad | base | pull | blockable | hits | 0 (Well's Unknown Abyss variant 12) | 15 | 75 | no opponent under the aim within 75 studs; blockable |
| Divine Dog: Totality | base | summon | blockable | hits | 18 total, 6 per attack (three attacks) | 20 | 50 | no enemy within 50 studs of the dog; dog is lost if the user gets ragdolled |
| Lurking Shadow | special | mobility | ? | ? | 0 | 10 | ? |  |
| Max Elephant | awakening | summon | unblockable | hits | 35 | 25 | ? | interruptible |
| Great Serpent | awakening | grab | unblockable | hits | 29 plus poison 2.9 per second for 10 s | 25 | ? | interruptible |
| Shadow Swarm | awakening | grab | unblockable | hits | 18 total | 15 | ? | interruptible; the domain-invasion variant costs the user 4 HP per second |
| Mahoraga | awakening | summon | unblockable | hits | 0 | 120 | 60 | no opponent within 60 studs; fails if the user is interrupted during the 3 s ritual |
| Divine Pummel | form | grab | unblockable | ? | 15 total (3 grab + 4 per slam + 4 punch) | 12 | ? | interruptible; may not hit ragdolled targets on the current patch |
| Ground Pitch | form | projectile | unblockable | hits | 25 (5 grab + 20 debris) | 20 | ? | cancelled if nothing is picked up near the user |
| Earthquake | form | aoe_self | blockable | hits | 12.5 tap; 25 held (half melee, half bullet) | 15 | ? | tap version can be blocked; interruptible while charging |
| Takedown | form | rush | unblockable | hits | 12.5 | 7 if landed, 15 if missed | 70 | no opponent within 70 studs; a miss doubles the cooldown |
| Adaptation | form | counter | ? | ? | 0 (heals 15 HP) | 5 if missed, 2 if landed, 15 on special  | ? | needs to be hit inside the 0.4 s window |
| World Slash | form | projectile | unblockable | hits | 40 | 30 | ? | long windup, interruptible |
| Adaptation Wheel | special | stance | ? | ? | 0 | ? | ? |  |

#### Mahito

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Stockpile | base | melee | blockable | ? | 12 (6 per swing); air variant 10 | 12 | ? | first swing can be blocked and does not hit ragdolled targets (tagged 'partly bypasses ragdoll') |
| Soul Fire | base | projectile | blockable | hits | 12 total (4 per bullet) | 12 | ? | blockable; interruptible |
| Focus Strike | base | melee | blockable | misses | 10; Black Flash variant 12 | 15 | ? | base hit is blockable and cannot hit a grounded ragdolled target |
| Body Repel | base | projectile | unblockable | hits | 14 | 20 | 70 | travels only where the user is facing; interruptible |
| Self Transfiguration | special | ? | ? | ? | ? | ? | ? |  |
| Idle Transfiguration | awakening | ? | ? | ? | ? | ? | ? |  |
| Body Disfigure | awakening | ? | ? | ? | ? | ? | ? |  |
| Spike Wrath | awakening | ? | ? | ? | ? | ? | ? |  |
| Embodiment of Self Perfection | awakening | ? | ? | ? | ? | ? | ? |  |
| Widespread Strikes | form | ? | ? | ? | ? | ? | ? |  |
| Face Blitz | form | ? | ? | ? | ? | ? | ? |  |
| Crushing Rushdown | form | ? | ? | ? | ? | ? | ? |  |
| Head Splitter | form | ? | ? | ? | ? | ? | ? |  |

#### Choso

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Piercing Blood | base | beam | blockable | ? | 12 | 15 | 30 | base beam can be blocked and only reaches about 30 studs |
| Piercing Blood (charged, uses an orb) | base | beam | unblockable | ? | 20 | 15 | 60 | needs a Convergence orb and a hold of at least 1.35 s; without an orb it stays the base beam |
| Flowing Red Scale | base | rush | blockable | hits | 13 (3 per rush hit, 4 on the last); 17 with a Convergence or | 12 | ? | the short forward dash has to connect; blockable from all sides |
| Flowing Red Scale (air) | base | melee | unblockable | ? | 6 | 12 | ? | must be airborne and on top of the target |
| Flowing Red Scale (air, with orb: blood mine) | base | trap | blockable | hits | 10 (explosion) | 12 | 10 | mine is static, so the target has to be within its 10-stud radius when detonated; also hurts the user |
| Supernova (no orbs: counter) | base | counter | ? | ? | 14 (7 per hit) | 15 | ? | needs the opponent to hit the user with a melee attack inside the 0.6 s counter window |
| Supernova (with orbs: thrown blood bomb) | base | projectile | ? | ? | 8 | 4 | ? | getting stunned makes the orb dissipate; cannot be used when four orbs are already active |
| Blood Edge | base | melee | ? | ? | 11 (5 grab, 6 slam) | 13 | ? |  |
| Convergence | special | buff | ? | ? | ? | 20 | ? | cannot be used while at least one orb remains |
| Convergence (awakening: homing orb after Wing King) | special | projectile | ? | ? | ? | ? | 75 | needs orbs left after Wing King and a target within 75 studs |
| Slicing Exorcism | awakening | beam | unblockable | ? | 17.5 | 13 | 66 | uses the available Convergence orbs, so it is weak or unusable without them; camera is locked while firing |
| Wing King | awakening | rush | ? | ? | 43.75 (28.75 flurry, 15 pull and slam) per bloxodes | 16 | ? | the long-range arm extension can be blocked |
| Blood Rain | awakening | aoe_self | blockable | ? | 2 per tick, 0.5 per tick on block | 35 | 35 | only reaches 35 studs from the user; blocking cuts it to chip damage |
| Plasma Wave | awakening | beam | unblockable | ? | 104 (~7.42 per tick) per Fandom; 95 per bloxodes (more recen | 45 | 120 | long spin-up before the cone fires; the last tick does not always hit |
| Duty as a Brother (awakening) | form | other | ? | ? | ? | ? | ? |  |

#### Todo

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Swift Kick | base | melee | blockable | ? | 15 (9 kick, 1 grab, 5 toss) | 15 | ? | the opening kick can be blocked; feinting it ends the kick's stun early |
| Brute Force | base | melee | unblockable | ? | 17.5 (6 if only the wind gust hits) | 17 | ? | if the target is not close enough only the weaker shockwave hits (less damage and knockback) |
| Pebble Throw | base | projectile | blockable | hits | 4 | 12 | ? | cannot hit ragdolled players within 20 studs of the user; blockable |
| Elbow Drop | base | melee | unblockable | misses | 12 (5 uppercut, 7 slam) | 16 | ? | the opening uppercut is a close-range hit; a community post says it does not hit ragdolled targets |
| Boogie Woogie | special | other | ? | ? | ? | 6 | 60 | needs a target within 60 studs; a target further than 35 studs (45 after a later +10 stud patch) can block the swap |
| Idol's Debut | awakening | melee | unblockable | ? | 30 (15 per hit) | 17 | ? | the cutscene only triggers if the first punch launches an enemy |
| Climax Jumping | awakening | rush | unblockable | ? | 42.4 (1 lunge, 27.4 barrage at 1.2 per hit, 15 uptilt) | 22 | ? | the opening lunge has to connect |
| Dreams | awakening | melee | ? | ? | 21 (7 per hit) | 10 | ? | three forward punches, so the target has to stay in front through the knockback |
| Brothers | awakening | counter | ? | ? | 80 on a successful counter; 70 if nothing is countered (game | 45 | ? | needs the opponent to throw a melee attack during the 1.1 s counter window |
| False Memories (awakening) | form | buff | ? | ? | ? | ? | ? |  |

#### Hiromi

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Extended Swings | base | melee | blockable | misses | 15 (2 per swing x3, 9 slam) | 15 | ? | swings cannot hit grounded ragdolled targets; first hits can be blocked and countered |
| Justice Served | base | melee | ? | ? | 12 | 18 | ? | needs ground to slam on; has a wind-up (25% faster if the user was unarmed before using it) |
| Judgement's Reach | base | melee | ? | ? | 7 | 13 | ? |  |
| Pressing Charges | base | melee | ? | ? | 7.5 (4 kick, 3.5 swing); the swing does 14.5 as a finisher o | 16 | ? | the kick's stun is never long enough to guarantee both hits connect |
| No Escape | special | projectile | blockable | hits | 3 | 5 | 50 | a gavel that hits nothing flies 50 studs and returns after 0.75 s |
| Domain Amplification | special | other | ? | ? | ? | 8 | ? | only about half a second of i-frames; cannot stop all damage or stun from multi-hit attacks |
| Execution | awakening | rush | ? | ? | 25 (10 lunge, 15 toss); executes a target that already has 2 | 12 | ? | the forward lunge has to catch the target |
| Final Judgement | awakening | rush | ? | ? | 10 for the lunge's swing, 300 for the stab; games.gg: 300 if | 21 | ? | hard to land (the wiki says so directly); failing the QTE drops it to minor damage |
| Verdict | awakening | rush | blockable | ? | 5 + 5; 300 on execution (one wiki line says reduced to 50; a | 18 | ? | if blocked the target dodges and no stack is applied |
| Triple Sentence | awakening | projectile | ? | ? | 8 per throw; 310 on execution | 12 | ? | hard to land (the wiki says so directly); each extra throw adds 6 s of cooldown |
| Grapple | awakening | pull | blockable | hits | 11 | 13 | ? | target has to be airborne; blockable |
| Deadly Sentencing (domain) / Death Penalty | form | domain | ? | ? | ? | ? | ? | the awakened moves need the Death Penalty outcome |

#### Yuta

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Severing Path | base | rush | ? | ? | 10.9 (4 sweep, 2.3 per swing) | 15 | ? | the forward slide has to reach the target |
| Resolute Slash | base | melee | unblockable | misses | ? | 15 | ? | cannot hit ragdolled targets |
| Veilstep | base | mobility | ? | ? | ? | ? | ? | does no damage; it is a back-roll away from the target |
| Second Wind | base | grab | ? | ? | 10 (2 grab, 8 slam) | 16 | ? | the dash grab has to catch the target (no cooldown if the first use fails) |
| Outburst | base | counter | ? | ? | sword swing 2 or 4 (the patch note is self-contradictory) | ? | ? | the parry only happens if the user is hit within 0.25 s of using it; otherwise it is a plain swing |
| Revolve | base | other | ? | ? | ? | ? | ? |  |
| Rika | special | summon | ? | ? | ? | ? | ? | Rika cannot go further than 100 studs from the user |
| Rika Downslam | base | summon | unblockable | ? | 12 (8 on contact, 4 on the second impact); 10 against airbor | 13 | ? |  |
| Rika Launch | base | summon | ? | ? | none | 10 | ? |  |
| Rika Slam | awakening | grab | ? | ? | 12 (1 grab, 2 per slam, 3 last slam) | 13 | ? | the target can evade the grab early |
| Rika Haymaker | base | summon | unblockable | ? | 12; 18 if blocked | 10 | ? |  |
| Rika Grab | base | grab | ? | hits | ? | ? | ? | only worked on a ragdolled target |
| Rika Throw | awakening | summon | ? | ? | 8 to 18 to the target; 0.5 to 22 to the user on a miss | 13 | ? | missing damages the user instead (0.5 to 22) |
| Rika Smash | base | summon | ? | ? | 10; 8 against airborne targets | 10 | ? |  |
| True Love Beam | awakening | beam | ? | ? | 117 per an older games.gg guide (reduced in V1.75) | ? | ? |  |
| Authentic Mutual Love | awakening | domain | ? | ? | ? | ? | ? |  |
| Elbow Rush | awakening | melee | ? | ? | 15 | ? | ? |  |
| Copy | awakening | other | ? | ? | ? | ? | ? |  |
| Energy Ripple | awakening | aoe_self | ? | ? | 19 | 18 | 27 | only reaches 27 studs around the user |

#### Mechamaru

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Ultra Spin | base | melee | blockable | ? | 13.5 (9.5 drill, 4 slam) | 15 | ? | blockable on the current wiki page |
| Boost On | base | grab | unblockable | ? | 10 (4 grab, 6 blast) | 16 | ? | the grab has to connect |
| Ultra Cannon | base | projectile | blockable | ? | 10 | 17 | ? | blockable from all sides |
| Ultimate Cannon (Ultra Cannon held 1.3 s) | base | beam | unblockable | hits | 16.15 (0.95 per tick, 17 ticks) | 17 | ? | 1.3 s hold before anything comes out; interruptible |
| Heat Emission | base | aoe_self | unblockable | ? | 13; 9 for the use-twice variant | 16 | ? | the use-twice variant is blockable from all sides |
| Offload | special | summon | ? | ? | ? | 10 | ? | switches itself off after 15 seconds if no move is used |
| Energy Output | special | buff | ? | ? | ? | 0 | ? | resets to level 1 after any move, or if pressed at level 5 |
| Miracle Cannon | awakening | projectile | ? | ? | 20; 35 for the charged sphere | 8 | ? | the big sphere needs Energy Output level 2 or higher |
| Pigeon Viola | awakening | projectile | ? | ? | 15, up to 35 (5 per projectile) | 8 | 250 | needs a target within 250 studs |
| Absolute Destruction | awakening | melee | ? | ? | 4 per stomp, 5 leap, 20 slam | 8 | ? |  |
| Technique Charge | awakening | other | ? | ? | 20 for the charge, +1 per Energy Output level; 5 for the sim | 8 | ? |  |
| Absolute (awakening) | form | other | ? | ? | ? | ? | ? |  |

#### Naoya

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| M1 string (Projectionism / Frame Freeze passive) | m1 | melee | ? | hits | 8 total (2 per hit x4) | ? | ? |  |
| Projection Breaker | base | melee | blockable | hits | 9 | 18 | ? | blockable (a forum tip says a fast reaction can block it); the backdash puts him 15 studs away before the kick, and a miss or block puts Projection on the user |
| Bleedout | base | melee | unblockable | hits | 5 stab + 3 per Bleed stack (x3) + 1.3 per Hemorrhage tick (3 | 20 | ? | interruptible; a forum comment says it has to follow an M1 or the target is i-framed (unverified) |
| Decisive Strike | base | rush | blockable | ? | 6 jab + 1 slap + 0.5 per blow (x14) | 18 | ? | interruptible; stages 1-2 can be blocked; windup looks like Projection Sorcery and Cursory Impact |
| Decisive Strike follow-up (heavy swing, press 1 after stage 3) | base | melee | unblockable | hits | 12 (36 if enemy interrupted, 24 if enemy ragdolled) | ? | ? | only available after Decisive Strike stage 3; wiki says missing it 'grants the user a frame' (the user gets framed) |
| Cursory Impact | base | rush | unblockable | ? | 7.5 slap + 5.5 kick (framed target: 19.5 slap + 5 toss) | 16 | ? | interruptible; windup resembles Projection Sorcery and Decisive Strike; a miss puts Projection on the user |
| Projection Sorcery | special | mobility | ? | ? | 0 (punch variant: 9, numbers unverified) | 18 | 50 | second teleport needs a target in sight; can be interrupted |
| Vengeance (awakening activation) | form | melee | ? | ? | ? | ? | ? | slow windup; any melee hit during the activation reverses it onto the user |
| Top Speed | awakening | rush | unblockable | ? | 5 base, +1.5 per Acceleration, up to 15 | 14 | ? | interruptible; weak (5 damage) without Acceleration stacks |
| Flash Freezing | awakening | beam | ? | ? | 7 per frame (15 frames) | 18 | ? | line in front of the user only |
| Tendril Grab | awakening | aoe_self | ? | ? | 0 | 10 | 25 | no enemy within 25 studs |
| Time Cell Moon Palace | awakening | domain | ? | hits | 1 per tick (per action) | 60 | ? | interruptible on cast; enemies who stand still or block take little or nothing |
| Acceleration | special | aoe_self | blockable | ? | 7 (1 per spin) | 9 | ? | no speed gain if blocked; cannot finish a kill |

#### Nanami

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| M1 string | m1 | melee | ? | ? | ? | ? | ? |  |
| Ratio Point | special | other | ? | ? | 0 | 5 | 70 | no target within 70 studs; mistimed second press gives no weak point; weak point expires after 4.5s |
| Cleaving Whirlwind | base | rush | blockable | ? | 12 | 16 | 25 | blockable and interruptible; straight 25-stud charge |
| Severance Kick | base | melee | blockable | ? | 12 kick, 15 from throwables | 14 | ? | damage can be blocked (knockback still applies) |
| Blunt Cut | base | rush | blockable | hits | 9 (14 if held); Ratio: 13 (18 if held) | 16 | 34 | blockable without a Ratio mark; interruptible during the charge |
| Stabilize | base | melee | unblockable | misses | 6 (10 on interruption) | 12 | ? | interruptible; cannot hit grounded ragdolled targets; melee range only |
| Overtime (awakening activation) | form | buff | ? | ? | 0 | ? | ? |  |
| Ratio Breaker I | awakening | melee | ? | hits | 10, 5 per hit (10 to either with Ratio, up to 20) | 19 | ? | without a Ratio mark on the target the chain ends and resets to stage I |
| Ratio Breaker II | awakening | melee | unblockable | ? | 7 (14 with Ratio) | 19 | ? | the sequence resets to stage I after a use that fails to hit a Ratio-marked target |
| Ratio Breaker III | awakening | aoe_self | unblockable | ? | 10 (20 with Ratio) | 19 | ? | interruptible during the hop/windup |
| Ratio Breaker IV | awakening | rush | unblockable | ? | 35 Black Flash (105 with Ratio) | 19 | 60 | fourth stage of the sequence, which resets to stage I after a use that fails to hit a Ratio-marked target |
| Sharpen | awakening | rush | unblockable | hits | 15 (23 with Ratio) | 20 | 45 |  |
| Interrogate | awakening | grab | unblockable | ? | 4 grab + 15 punch | 20 | ? |  |
| Collapse | awakening | aoe_self | unblockable | ? | 5 slam + 7 impact (15 with Ratio); recast: 40 per debris, ma | 22 | ? | debris only falls where it was left; enemies have up to 8s to leave the area |

#### Hanami

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| M1 string | m1 | melee | ? | ? | 14 total over 4 hits (as stated under Unwrap) | ? | ? |  |
| Lasso (passive front dash) | base | pull | ? | ? | 4 | 10 | ? |  |
| Plant Guidance | special | aoe_point | ? | ? | 0 | 12 | 65 | spot is fixed once placed (enemy must be at the mark); follow-up used on the ground and idle gives the normal move instead |
| Root Swarm | base | beam | unblockable | ? | 10 roots + 6 spike bounce | 15 | 50 | ground line only; older patch notes say it was blockable at close range |
| Surging Thorns | base | other | blockable | misses | 11 total: 3 per branch (x2) + 5 thorns (possibly reduced by  | 16 | 35 | interruptible; thorn damage blockable from any side; does nothing to ragdolled targets |
| Bud Shot | base | projectile | blockable | hits | 8 total (4 per bud x2) | 15 | 70 | blockable; pushes close targets away instead of pulling |
| Defense Response | base | rush | unblockable | misses | 12 (air/special variant: 14 = 8 emergence + 6 bounce) | 15 | ? | interruptible; cannot hit ragdolled targets |
| Unwrap (awakening activation) | form | buff | ? | ? | 30 total (6 per spike bounce x5) | ? | ? |  |
| Energy Absorb / Flower Beam | awakening | beam | ? | ? | ? | 20 | ? |  |
| Cursed Buds | awakening | summon | blockable | ? | 33.5 total: 8 summon + 1.7 per bud (x15) | 16 | ? | buds are blockable unless empowered |
| Shining Sea of Growing Branches | awakening | domain | ? | ? | 4 per interruption | 120 | ? | interruptible; enemies who only run, side dash or block take nothing |
| Flower Field | awakening | other | ? | ? | 12 emergence + 7 (or 6) per bounce; 6 on interruption | 16 | ? |  |
| Root Rampage | awakening | beam | ? | ? | 5 per hit | 16 | ? | easily interrupted during the ~7s channel |
| Thorn Rampage (Root Rampage air variant) | awakening | projectile | unblockable | ? | 25 | 16 | ? | dodged by a last-second dash |

#### Ryu

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| M1 string (Cursed Energy Discharge / Overheat passive) | m1 | melee | ? | ? | ? | ? | ? | final-hit ray is lost at 90%+ Overheat |
| Granite Blast | base | beam | blockable | ? | 5.5 (held: 12, 6 at further range; dash variant: 4) | 0.5 | 78.5 | tap version is blockable and stops at the first target; wiki says Cursed Energy Discharge attacks are disabled at 100% Overheat |
| Unsatisfied | base | melee | blockable | hits | 18 total: 3 per punch (x3) + 3 back clash + 6 toss (12 on ra | 20 | ? | blockable (extra endlag when blocked) and interruptible |
| Second Helping | base | melee | unblockable | hits | 12 | 15 | ? | interruptible; reduced hitbox; i-frames start late |
| Appetizer | base | beam | blockable | ? | 16 total: 4 per blast (x2) + 8 final ray | 18 | ? | blockable and interruptible; wiki says Cursed Energy Discharge attacks are disabled at 100% Overheat |
| Restyle | special | buff | ? | ? | 0 | 17 | ? | vulnerable during the animation, much more so in the full-Overheat comb variant |
| Every Last Drop (awakening activation) | form | other | ? | ? | ? | ? | ? | needs Overheat at 80-99% beforehand to enter the awakening state |
| "What are you after?" | awakening | melee | unblockable | hits | 10 slam + 20 lunge + 5 toss (5 self-damage on launch) | 18 | ? |  |
| "I had no idea..." | awakening | grab | ? | ? | 3 grab + 2 per punch (x7) + 3 push (self-damage 2 + 1 per pu | 15 | ? |  |
| "This is what dessert is like!" | awakening | melee | ? | ? | 7 kick + 3 swing + 5 per hit (x4) + 6 push (self-damage 2 pe | 20 | ? |  |
| "You weren't invited." | awakening | other | ? | ? | 20 (40 if held to full charge) | 20 | ? |  |

#### Reggie

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| M1 string | m1 | melee | ? | ? | ? | ? | ? |  |
| Discard | special | other | ? | ? | 0 | 25 | ? | not an attack; 25s cooldown (minus 5s per final M1 or uppercut) |
| Con Artistry (awakening activation) | form | buff | ? | ? | 0 | ? | ? |  |
| Coupon | base | buff | ? | ? | 0 | 5 | ? |  |
| Extra Coupon | base | buff | ? | ? | 0 | 8 | ? |  |
| Gushing Wound | base | projectile | unblockable | misses | 9 knife + 3 Bleed stack | 12 | ? | no ragdoll if blocked; cannot hit ragdolled targets |
| Homerun | base | melee | unblockable | misses | 10 (15 from throwables) | 14 | ? | noticeable startup; cannot hit ragdolled targets |
| Littering | base | trap | blockable | hits | 8 | 15 | ? | needs the second press and an enemy near the receipts; blockable from any side |
| Pole Vault | base | melee | unblockable | hits | 5 (patch note: 7) | 14 | ? | interruptible |
| Piano Drop | base | aoe_point | unblockable | hits | 14 (red seal: 19 at centre) | 13 | ? | interruptible; small 7x7 landing area |
| Garage Sale | base | projectile | blockable | hits | 12 (1.2 per item); red seal 17 | 16 | ? | blockable; interruptible during windup |
| Blunt Trauma | base | melee | blockable | hits | 15 total: 3 per swing + 6 last hit | 14 | ? | first swing must connect; blockable and interruptible |
| Drone Strike | base | summon | unblockable | hits | 12 | 10 | ? | needs the second press to detonate |
| Fleche | base | rush | blockable | misses | 8 | 14 | ? | blockable and interruptible; straight-line dash; cannot hit ragdolled targets |
| Speed Crash | base | rush | unblockable | hits | 12 explosion (red seal: 14) | 16 | ? | hitting a wall or obstacle damages the user |
| Road Rage | awakening | projectile | ? | ? | 36 total (12 per car, 6 per hit) | 15 | ? |  |
| 132-Square-Foot Two-Story House | awakening | other | ? | ? | 125 total (35 initial hit + 90 second impact) | 16 | ? |  |
| Big Moves | awakening | projectile | ? | ? | 55 total (30 crash + 12.5 per explosion) | 16 | ? | a target standing in the gap between the two trucks is not hit by the crash |
| Mayhem | awakening | aoe_self | ? | ? | 24 | 16 | ? |  |

#### Toji

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Hidden Inventory | special | stance | ? | ? | ? | 5 | ? | being hit or stunned mid-swap cancels it (the special then stays off cooldown and can be retried) |
| Flourish | base | melee | unblockable | ? | 5 | 15 | ? | punishable endlag on miss; cannot kill |
| The Wrath | base | rush | ? | ? | 7 (Gaming Route; not confirmed from the wiki) | ? | ? | only available during Flourish's slowdown; if the first swing misses the other two do not come out |
| The Greed | base | melee | unblockable | ? | 11 total (3 kick, 1 per slash x5, 3 last hit) | 15 | ? | only available during Flourish's slowdown; the slashes only follow if the kick lands; interruptible |
| The Pride | base | grab | ? | ? | 9 (Gaming Route; not confirmed from the wiki) | ? | ? | only available during Flourish's slowdown; the target can escape the stun before the chain connects |
| Debilitate | base | melee | blockable | hits | 13 total (4 kick/sweep, 4.5 per slash) | 13 | ? | blockable and interruptible; the full slash sequence only happens on a standing opponent |
| Transcend | base | rush | unblockable | hits | 12 | 14 | ? | needs a second press or the user just stands up; punishable endlag on miss; interruptible |
| Ascend | base | mobility | ? | ? | ? | ? | ? | deals no damage by itself; not available while airborne |
| Rupture | base | rush | ? | ? | 14 total (9 lunge, 2.5 swing, 2.5 stab); timesaver.gg: 14 on | 15 | ? | listed as semi-blockable; failing the timed second press makes the opponent block and push the user away |
| Paradise | base | rush | blockable | ? | 9 (lunge only) | 15 | ? | blockable |
| Reincarnation | base | other | blockable | ? | 9 (lunge, as listed on the wiki) | 15 | ? | blockable and interruptible |
| Lasso | base | pull | unblockable | hits | 12 total (4 pull, 8 kick) | 16 | 24 | the chain is twirled for a moment before it is thrown; target must be within 24 studs |
| Whiplash | base | melee | blockable | ? | 5 (bullet damage) | 15 | ? | blockable |
| Twirling Strike | base | rush | unblockable | ? | 8 | 15 | ? | only available in the 1.5 s spin window after Whiplash; goes wherever the user is aiming |
| Puppet of Carnage | awakening | buff | ? | ? | ? | ? | ? | has no attacks to land |
| M1 (basic attack) notes | m1 | melee | ? | ? | ? | ? | ? |  |

#### Locust

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Crushing Jaws | base | melee | ? | ? | 16 total (4 per bite, 4 slam, 3 throw to other targets) | 17 on the character page; the V1.70-V1.6 | ? | semi-blockable: only the first bite can be blocked; if the first bite misses, the rest of the windup is 40% slower |
| Clever | base | rush | blockable | ? | about 14.2 total (1.1 per hit, 1 on the last); an older guid | 15 (cut from 17 in V1.70); an older guid | ? | blockable and interruptible; if the barrage is blocked even briefly the user is locked in place |
| Wing Throw | base | grab | blockable | hits | 8 total (3 grab, 5 throw) | 15 | ? | blockable and interruptible; the arm is wound back first; a blocked grab does not move the user |
| Black Mucus | base | projectile | unblockable | hits | 8 (bullet damage) | 17 | 60 | the head is wound back before the spit; interruptible; travels straight forward |
| Fluttering Pounce | special | mobility | ? | ? | none (no direct damage) | 16 on the character page; the V1.70-V1.6 | 25 | interruptible; it is movement only and does not hit by itself |
| Fluttering Pounce (air combo) | special | rush | ? | hits | none (no direct damage) | 16 | 80 | needs an airborne, ragdolled enemy within 80 studs; the combo ends after a second without action or if the enemy gets ragdolled |
| Directed Poison | awakening | projectile | unblockable | hits | sting 0; poison 90 total at 9 per second for 10 s (other gui | ? | ? | a miss refunds half of the awakening bar (V1.70) |

#### Yuki

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Garuda Rebound | base | projectile | blockable | ? | 5 | 14 | ? | blockable from all sides; interruptible |
| Garuda Rebound (second kick) | base | projectile | unblockable | ? | 7 (12.5 to the user if it is parried back) | 20 | ? | a perfect block sends Garuda back at the user (who can parry it back again) |
| Garuda Rebound (mass variant) | base | projectile | unblockable | ? | 24 | 20 | ? | needs 100% mass; a perfect block parries it back; gives no awakening progress |
| Rising Rage | base | melee | blockable | ? | 14 total (7 per hit) | 15 | ? | blockable and interruptible; the first kick cannot hit a ragdolled target (the second can) |
| Rising Rage (mass variant, one charge) | base | melee | ? | ? | 16 | 15 | ? | needs 30% mass |
| Rising Rage (mass variant, two charges) | base | melee | ? | ? | 24 | 15 | ? | needs 60% mass in total; listed as semi-blockable (the last knee is the unblockable part) |
| Mass Breaker | base | rush | unblockable | ? | 15 | 15 | ? | has a charge-up before the lunge; interruptible |
| Mass Breaker (mass variant) | base | aoe_self | ? | ? | 12 | 15 | ? | needs 30% mass; replaces the lunge, so it has no forward reach |
| Garuda Stab | base | melee | unblockable | misses | 14 total across two hits | 14 | ? | the kick only follows if the stab connects; does not bypass ragdoll; interruptible |
| Garuda Stab (mass variant) | base | pull | unblockable | ? | 21 total (stab plus two whip hits) | 20 | ? | needs 50% mass; interruptible; a forum post says this variant is now blockable |
| Mass Buildup | special | buff | ? | ? | ? | 16 on the wiki; one guide says 15 | ? | holding it immobilises the user (per a guide) |
| Unrestricted Density | awakening | aoe_self | ? | ? | about 1600 total, about 28.5 per tick, falling off with dist | ? | ? | the latch counts as a melee attack, so counters trigger on it; the grab alone spends the whole awakening bar even if the black hole never forms; interruptible |

#### Charles

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Despair | base | melee | ? | ? | 16.1 total (15 from thrusts, 1.1 last hit); an older patch n | 16 | ? | slows down if it misses or is blocked by an unmarked target (V1.69 removed the slowdown when a marked enemy blocks) |
| Shut Up! | base | melee | blockable | ? | 7 total (3 stab, 4 kick) | 16 | ? | blockable; a later patch made it no longer evadable |
| Shut Up! (air) | base | aoe_point | unblockable | ? | 12 | 16 | ? | ends automatically if the user does not reach the ground in time |
| Eye Catching | base | counter | ? | ? | 9 | 14, or none if the counter lands | ? | needs the opponent to hit with a melee or bullet attack inside the 0.75 s window; explosion and swarm attacks are not countered (they are only blocked, if blockable) |
| Sacrilege | base | rush | unblockable | hits | 12 total (6 thrust, 6 kick) | 16 | 20 | missing the dash leaves 0.85 s of endlag (was 0.75 s, earlier 1 s); the hitbox can sometimes miss ragdolled or uppercutted targets |
| Clairvoyance | special | buff | ? | ? | ? | 25 | 35 | the cursor must be over an opponent within 35 studs |
| Clairvoyance: Prediction | special | other | ? | misses | ? | 4 (a forum post says each use costs 2% a | ? | only works on a marked target that is not ragdolled and not using a skill |

#### Haruta

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Ambush | base | melee | unblockable | ? | 12 | 15, shared with Ankle Cutter | ? | a perfect block makes the enemy dodge the blade |
| Backstab | base | melee | unblockable | misses | 8 | 12, shared with High Time | ? | interruptible; cannot hit an opponent ragdolled on the ground; the long stun needs the hit to come from behind |
| Trip | base | melee | ? | hits | 7 kick + 4 fall | 14 (not spent if it kills or hits a corp | ? | against an already ragdolled enemy it only adds knockback and deals no fall damage |
| Cheap Shot | base | projectile | blockable | ? | 7 | 15 (not shared with Dirty Play) | 60 | if it is blocked the blade just stops in place instead of tracking |
| Ankle Cutter | base | projectile | blockable | hits | 10 | 15, shared with Ambush | ? | blockable from all sides; interruptible |
| High Time | base | aoe_point | blockable | ? | 12 | 12, shared with Backstab (none on a dead | ? | blockable from all sides; it happens at the blade's position, so enemies must be near the blade |
| Dirty Play | base | projectile | blockable | hits | 8 (bullet damage) | 15 (not shared with Cheap Shot) | ? | cannot be used while stunned or ragdolled; only hits targets on the blade's path back |
| Helping Hand | special | summon | ? | ? | ? | ? | ? |  |

#### Crow Charmer

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Impetus Updraft | base | melee | blockable | hits | 11 | 16 | ? | Major endlag on a miss; a forum post claims a blocked swing stuns the user for 2 s (unverified) |
| Circling | base | melee | blockable | ? | 14 | 18 | ? | If a swing is blocked the user stays in place |
| Gliding Flight | base | melee | ? | hits | ? | ? | ? |  |
| Murmurate | base | projectile | blockable | ? | 9 | 16 | ? |  |
| Bird Control | base | mobility | blockable | ? | ? | 18 | 35 | No cooldown if feinted; cancelling the flight with Spatial Transference keeps it off cooldown |
| Flock | special | other | ? | ? | 5 | 10 | ? |  |
| Spatial Transference | special | other | ? | ? | ? | ? | ? |  |
| Free Fall | base | melee | ? | ? | ? | ? | ? |  |
| Dive Bomb | base | other | blockable | ? | ? | ? | ? |  |
| Bird Strike | awakening | projectile | unblockable | ? | ? | ? | ? |  |

#### Black Death

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Festering Strikes | base | melee | blockable | ? | 3 | 20 | ? |  |
| Detach | base | projectile | blockable | ? | 2 | 13 | 85 | After 85 studs without a hit the user pulls it back and reattaches it |
| Reattach | base | pull | unblockable | hits | 0 | 13 | ? | Unavailable once 8 seconds have passed since Detach |
| Chokehold | base | grab | blockable | ? | 2 | 16 | ? |  |
| Roach Swarm | base | projectile | ? | ? | 9 | 17 | 35 | Its hitbox does not cover targets on the user's right |
| Roach Swarm (air variant) | base | rush | ? | ? | ? | 17 | 40 | No endlag per the wiki tip |
| Roach Swarm (special variant) | base | aoe_self | ? | ? | 6 | 17 | ? | A small gap directly in front of the user lets targets avoid it |
| Earthen Insect Trance | special | summon | ? | ? | 4 | 15 | 100 | Ends if the user is ragdolled; cooldown starts only after the insects are gone |
| Parthenogenesis | awakening | summon | ? | ? | ? | ? | ? |  |

#### Sky Bender

| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |
|---|---|---|---|---|---|---|---|---|
| Blind Rage | base | grab | unblockable | misses | 9 | 15 | ? | If the target evades out of the grab above 25 studs of altitude they automatically counterattack the user |
| Sky Distortion | base | melee | ? | ? | 10 | 12 | ? |  |
| Thin Ice Breaker | base | grab | unblockable | misses | 14 | 15 | ? |  |
| Turbulence | base | pull | ? | ? | 10 | 15 | 60 |  |
| Turbulence (air variant) | base | rush | ? | ? | 14 | 15 | ? |  |
| Turbulence (Sky Veil variant) | base | counter | ? | ? | ? | 15 | ? | Counter window is 0.75 s and using it ends the invisibility |
| Sky Veil | special | buff | ? | ? | 0 | 8 | ? |  |
| Temper | awakening | buff | ? | ? | ? | ? | ? |  |

### 18.4 What the research could not find

- Nine of Mahito's moves, Yuta's current Rika moves, most awakening moves of Ryu, Reggie and Mechamaru.
- Reach in studs for most moves, and how most moves are aimed.
- A general rule for cancelling a basic attack into a skill, block durability, a delay on acting after a block, ragdoll durations, dash invulnerability.
- What the "Evade 50" figure means beyond the 0 to 50 meter in the files.

---

## Appendix C — Knit service and remote register (1.85, from the place file)

Read from `ReplicatedStorage.Knit.Knit.Services/<Service>/{RE,RF}/<Name>`: **260 services, 711 RemoteEvents, 2 RemoteFunctions**. ★ marks a service that §1–§16 never name. Direction is not recorded in the tree; a Knit RemoteSignal can carry both.

The commonest shapes: `Activated, Effects` ×173; `Activated, Deactivated, Effects` ×22; `Activated, Chase, Effects, RightActivated, Ultimate` ×14; `Activated, Chase, Effects, Hitbox, RightActivated, Ultimate` ×9.

| Service | RemoteEvents (`RE`) | RemoteFunctions (`RF`) |
|---|---|---|
| `AbsoluteDestructionService` | Activated, Effects | — |
| ★ `AbsoluteService` | Debree, DropkickHitbox, Effects, EjectHitbox, JumpRequest | — |
| `AchievementService` | Daily, Give, Request, Update, Weekly | — |
| `AdaptationService` | Activated, Effects | — |
| `AmbushService` | Activated, Effects | — |
| `AnkleCutterService` | Activated, Effects | — |
| `AntiCheatService` | Camera, Teleport | — |
| `AppetizerService` | Activated, Effects | — |
| `BackstabService` | Activated, Effects | — |
| `BeamService` | Effects | — |
| `BigMovesService` | Activated, Effects | — |
| `BirdControlService` | Activated, Effects | — |
| `BlackMucusService` | Activated, Effects | — |
| `BleedoutService` | Activated, Effects | — |
| `BlindRageService` | Activated, Effects | — |
| `BlockService` | Activated, Deactivated, Effects | — |
| `BloodEdgeService` | Activated, Effects | — |
| `BloodRainService` | Activated, Deactivated, Effects | — |
| ★ `BluntCutService` | Activated, Deactivated, Effects, Hitbox | — |
| `BluntTraumaService` | Activated, Effects | — |
| `BodyDisfigureService` | Activated, Effects | — |
| `BodyRepelService` | Activated, Effects | — |
| `BoostOn2Service` | Activated, Effects | — |
| `BoostOnService` | Activated, Effects | — |
| `BrothersService` | Activated, Effects | — |
| `BruteForceService` | Activated, Effects | — |
| `BudShotService` | Activated, Effects | — |
| `BuildService` | LoadPack, Packs | — |
| ★ `CandiesService` | OpenShop, Purchase | — |
| `CharlesService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `CheapShotService` | Activated, Effects | — |
| `ChokeholdService` | Activated, Effects | — |
| `ChosoService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `CirclingService` | Activated, Deactivated, Effects | — |
| `CleaveRushService` | Activated, Effects | — |
| ★ `CleaveService` | Activated, Deactivated, Effects, Hitbox | — |
| `CleavingWhirlService` | Activated, Effects | — |
| `CleverService` | Activated, Effects | — |
| `ClimaxJumpService` | Activated, Effects | — |
| `CollapseService` | Activated, Effects | — |
| `CopyService` | Activated, Deactivated, Effects | — |
| ★ `CopyWheelService` | Activated, Deactivated | — |
| ★ `CouponService` | Activated, Effects | — |
| `CrushJawService` | Activated, Effects | — |
| `CrushingBlowService` | Activated, Effects | — |
| `CrushingRushdownService` | Activated, Effects | — |
| `CursedBudsService` | Activated, Effects | — |
| `CursedStrikesService` | Activated, Effects, Hitbox | — |
| `CursoryImpactService` | Activated, Effects | — |
| `CustomService` | Activated, Awaken, Chase, Deactivated, FX, FX2, LOOK, Melee, PARTICLE, PARTICLE2, SFX, SFX2, Special | — |
| ★ `DebilitateService` | Activated, Effects | — |
| `DebreeService` | Create, Destroy, Domain, Loaded, MoveAway, MoveIn, Physics, Sound | — |
| `DebugService` | Debug, Unban, Update | — |
| `DecisiveStrike2Service` | Activated, Effects | — |
| `DecisiveStrikeService` | Activated, Effects | — |
| `DefenseResponseService` | Activated, Effects | — |
| `DespairService` | Activated, Effects | — |
| `DetachService` | Activated, Effects | — |
| ★ `DirtyPlayService` | Activated, Effects | — |
| `DismantleService` | Activated, Effects | — |
| `DismantleV2Service` | Activated, Effects | — |
| `DivergentFistService` | Activated, Effects | — |
| `DivineDogService` | Activated, Effects | — |
| `DivinePummelService` | Activated, Effects | — |
| `DomainService` | Activated, Activated2, CFix, Effects | — |
| `DreamsService` | Activated, Effects | — |
| `DroneStrikeService` | Activated, Effects | — |
| ★ `DuelService` | Effects, MatchEnd, Vows | — |
| `EarthquakeService` | Activated, Deactivated, Effects | — |
| `ElbowDropService` | Activated, Effects | — |
| `ElbowRushService` | Activated, Effects | — |
| `EmoteService` | ChangeInv, ChangeMVP, ChangeSkin, Effects, Emote, EmoteEnd, Equip | — |
| ★ `EnergyRippleService` | Activated, Effects | — |
| `EnergySurgeService` | Activated, Effects | — |
| `ExecutionService` | Activated, Effects | — |
| `ExtendSwingService` | Activated, Effects | — |
| `EyeCatchService` | Activated, Effects | — |
| `FaceBlitzService` | Activated, Effects | — |
| `FesteringStrikesService` | Activated, Effects | — |
| `FeverBreakerService` | Activated, Effects | — |
| `FinalJudgementService` | Activated, Effects | — |
| `FinalShowdownService` | Effects | — |
| `FlameArrowService` | Activated, Effects | — |
| `FlashFreezingService` | Activated, Effects | — |
| `FlecheService` | Activated, Effects | — |
| ★ `FlourishService` | Activated, Effects | — |
| `FlowerBeamService` | Activated, Effects | — |
| `FlowerFieldService` | Activated, Effects | — |
| `FocusStrikeService` | Activated, Effects | — |
| `FurnaceArrowService` | Activated, Effects | — |
| `GarageSaleService` | Activated, Effects | — |
| `GarudaReboundService` | Activated, Deactivated, Effects | — |
| `GarudaStabService` | Activated, Effects | — |
| `GojoService` | Activated, Chase, Effects, Hitbox, RightActivated, Ultimate | — |
| `GokuService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `GraniteBlastService` | Activated, Deactivated, Effects | — |
| `GrappleService` | Activated, Effects | — |
| `GreatSerpentService` | Activated, Effects | — |
| `GroundPitchService` | Activated, Effects | — |
| `GushingWoundService` | Activated, Effects | — |
| `HadNoIdeaService` | Activated, Effects | — |
| ★ `HakariService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `HanamiService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `HandicapService` | Effects, Hit, LastHit | — |
| `HarutaService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `HeadSplitterService` | Activated, Effects | — |
| `HeatEmissionService` | Activated, Deactivated, Effects | — |
| ★ `HeianService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `HighTimeService` | Activated, Effects | — |
| `HiromiService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `HitboxService` | Hitbox | — |
| `HollowPurpleService` | Activated, Effects | — |
| `HomerunService` | Activated, Effects | — |
| ★ `HouseService` | Activated, Effects | — |
| `IdleTransfigurationService` | Activated, Effects | — |
| `IdolDebutService` | Activated, Effects | — |
| `ImpetusUpdraftService` | Activated, Effects | — |
| ★ `InfiniteVoidService` | Activated, Effects | — |
| `InterrogateService` | Activated, Effects, Hitbox | — |
| `ItadoriService` | Activated, Chase, Effects, RightActivated, Ultimate, UltimateEnchain | — |
| `ItemService` | Dash, Drop, Effects, M1, M2 | — |
| `JoinService` | AcceptRules, Change, MobileLayout, Reset, Respawn, Setting, Talk | — |
| `JudgeReachService` | Activated, Effects | — |
| ★ `JusticeServedService` | Activated, Effects | — |
| `KamehamehaService` | Activated, Effects | — |
| `KamutokeService` | Activated, Effects | — |
| `KiSpamService` | Activated, Deactivated, Effects | — |
| ★ `KoganeService` | Action, Effects, Playlist | ActivateShenanigans |
| `KurourushiService` | Activated, Chase, Effects, Hitbox, RightActivated, Ultimate | — |
| `LapseBlueMaxService` | Activated, Debree, Effects | — |
| `LapseBlueService` | Activated, Effects | — |
| ★ `LassoService` | Activated, Effects | — |
| ★ `LitteringService` | Activated, Effects | — |
| `LocustService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `LoveBeamService` | Activated, Effects | — |
| `LuckyRushdownService` | Activated, Effects | — |
| `LuckyVolleyService` | Activated, Effects | — |
| `MahitoService` | Activated, Chase, Effects, Hitbox, RightActivated, Ultimate | — |
| ★ `MahoragaService` | Activated, Chase, Effects, Hitbox, RightActivated, Ultimate | — |
| `MahoragaUseService` | Activated, Effects | — |
| ★ `MalevolantShrineService` | Activated, Effects | — |
| `ManjiKickService` | Activated, Effects | — |
| `MassBreakerService` | Activated, Effects | — |
| `MaxElephantService` | Activated, Deactivated, Effects | — |
| `MayhemService` | Activated, Effects | — |
| `MechamaruService` | Activated, Chase, Debree, Effects, JumpRequest, RightActivated, RightDeactivated, Ultimate | — |
| `MegumiService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `MeiMeiService` | Activated, Chase, Effects, Hitbox, RightActivated, Ultimate | — |
| `MiracleCannonService` | Activated, Debree, Effects | — |
| `Mokou1Service` | Activated, Effects | — |
| `Mokou2Service` | Activated, Effects, Hitbox | — |
| `Mokou3Service` | Activated, Effects | — |
| `Mokou4Service` | Activated, Deactivated, Effects | — |
| `MokouService` | Activated, Chase, Effects, Hitbox, RightActivated, Ultimate | — |
| `MovementService` | Dash, Effects, Parkour, RagdollSound, ResetDash, Throwable | — |
| `MurmurateService` | Activated, Effects | — |
| ★ `MutualLoveService` | Activated, Effects | — |
| `NanamiService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `NaoyaService` | Activated, Effects, Hitbox, RightActivated, Ultimate | — |
| `NepService` | Effects | — |
| `NightParadeService` | Effects | — |
| `NueService` | Activated, Effects | — |
| `OutburstService` | Activated, Deactivated, Effects | — |
| `OverLuckService` | Activated, Effects | — |
| `PebbleThrowService` | Activated, Effects | — |
| `PianoDropService` | Activated, Deactivated, Effects | — |
| `PiercingBloodService` | Activated, Deactivated, Effects | — |
| `PigeonViolaService` | Activated, Effects | — |
| `PlasmaWaveService` | Activated, Effects | — |
| `PoleVaultService` | Activated, Effects | — |
| `PressingChargesService` | Activated, Effects | — |
| `ProjectionBreakerService` | Activated, Effects | — |
| `PuppetBarrageService` | Activated, Effects, Hitbox | — |
| `RabbitEscapeService` | Activated, Effects | — |
| ★ `RankedService` | Filter, Teleport | — |
| `RapidPunchesService` | Activated, Effects | — |
| ★ `RatioBreakerService` | Activated, Effects | — |
| `RedScaleService` | Activated, Effects | — |
| `ReggieService` | Activated, Chase, Effects, Hitbox, RightActivated, Ultimate | — |
| `ReserveBallService` | Activated, Effects | — |
| `ResoluteSlashService` | Activated, Effects | — |
| ★ `ResoluteSwingService` | Activated, Effects | — |
| `ReversalRedMaxService` | Activated, Effects | — |
| `ReversalRedService` | Activated, Effects | — |
| `RevolveService` | Activated, Effects, Hitbox | — |
| `RikaDownslamService` | Activated, Effects | — |
| `RikaGrabService` | Activated, Effects | — |
| `RikaHaymakerService` | Activated, Effects | — |
| `RikaLaunchService` | Activated, Effects | — |
| `RikaLoveBeamService` | Activated, Effects | — |
| ★ `RikaService` | Activated, Chase, Effects, Hitbox, RightActivated, Ultimate | — |
| `RikaSlamService` | Activated, Effects | — |
| ★ `RikaSmashService` | Activated, Effects | — |
| `RikaThrowService` | Activated, Effects | — |
| `RisingRageService` | Activated, Effects | — |
| `RoachSwarmService` | Activated, Effects | — |
| ★ `RoadRageService` | Activated, Effects | — |
| `RootRampageService` | Activated, Effects | — |
| `RootSwarmService` | Activated, Effects | — |
| `RoughEnergyService` | Activated, Effects | — |
| `RouletteService` | Effects, Spectate | — |
| ★ `RuptureService` | Activated, Effects | — |
| `RushService` | Activated, Effects | — |
| ★ `RyuService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| `SacrilegiousService` | Activated, Effects | — |
| ★ `SeaOfBranchesService` | Activated, Effects | — |
| `SecondHelpingService` | Activated, Effects | — |
| ★ `SecondWindService` | Activated, Effects | — |
| ★ `SelfPerfectionService` | Activated, Effects | — |
| `SeveranceKickService` | Activated, Effects | — |
| `SeveringPathService` | Activated, Deactivated, Effects | — |
| `ShadowSwarmService` | Activated, Effects | — |
| `SharpenService` | Activated, Effects | — |
| ★ `ShopService` | Chat, Code, Notification, Preview, Purchase, SendRobux, UpdateOdds | GetGiftProducts |
| `ShutUpService` | Activated, Effects | — |
| `ShutterDoorService` | Activated, Effects | — |
| `SkyDistortionService` | Activated, Effects | — |
| `SlicingExorcismService` | Activated, Deactivated, Effects | — |
| `SoulfireService` | Activated, Deactivated, Effects | — |
| `SpeedCrashService` | Activated, Effects | — |
| `SpikeWrathService` | Activated, Effects | — |
| `StabilizeService` | Activated, Effects, Hitbox | — |
| `StaffExtendService` | Activated, Deactivated, Effects | — |
| `StaffUppercutService` | Activated, Effects | — |
| `StockpileService` | Activated, Effects | — |
| ★ `SuperTzeService` | Activated, Chase, Effects, RightActivated | — |
| `SupernovaService` | Activated, Effects | — |
| `SurgingThornsService` | Activated, Effects | — |
| `SwiftKickService` | Activated, Effects | — |
| `TechniqueChargeService` | Activated, Deactivated, Effects | — |
| `TendrilGrabService` | Activated, Effects | — |
| `ThinIceBreakerService` | Activated, Effects | — |
| ★ `ThirdWheelService` | Activated, Effects | — |
| ★ `ThisDessertService` | Activated, Effects | — |
| ★ `TimeCellMoonPalaceService` | Activated, Effects | — |
| `ToadService` | Activated, Effects | — |
| `TodoService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
| ★ `TojiService` | Activated, Chase, Effects, Hitbox, RightActivated, RightDeactivated, Ultimate | — |
| `TopSpeedService` | Activated, Effects | — |
| ★ `TranscendService` | Activated, Effects | — |
| `TripService` | Activated, Effects | — |
| `TripleSentenceService` | Activated, Effects | — |
| ★ `TurbulanceService` | Activated, Effects | — |
| ★ `TwofoldKickService` | Activated, Effects | — |
| `UltraCannon2Service` | Activated, Deactivated, Effects | — |
| `UltraCannonService` | Activated, Deactivated, Effects | — |
| `UltraSpinService` | Activated, Effects | — |
| `UnsatisfiedService` | Activated, Effects | — |
| `UroService` | Activated, Chase, Effects, Hitbox, RightActivated, Ultimate | — |
| `VeilstepService` | Activated, Effects | — |
| `VerdictService` | Activated, Effects | — |
| `WerentInvitedService` | Activated, Deactivated, Effects | — |
| `WhatAreYouAfterService` | Activated, Effects | — |
| ★ `WhiplashService` | Activated, Effects | — |
| `WideSPStrikesService` | Activated, Effects | — |
| `WingKingService` | Activated, Effects | — |
| `WingThrowService` | Activated, Effects | — |
| ★ `WorkshopService` | Buy, CustomUpload, DataLoad, DataQuery, Delete, Donate, Favourite, Load, Report, Upload | — |
| `YukiService` | Activated, Chase, Debree, Effects, RightActivated, RightDeactivated, Ultimate | — |
| `YutaService` | Activated, Chase, Effects, RightActivated, Ultimate | — |
