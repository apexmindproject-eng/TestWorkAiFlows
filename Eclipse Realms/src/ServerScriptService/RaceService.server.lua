--!strict
-- Handles race selection: assigns the Team, remembers the choice, and spawns the player
-- in their race's start zone. New players spawn in the floating Selection Chamber.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SelectRace = Remotes:WaitForChild("SelectRace") :: RemoteFunction
local RaceAssigned = Remotes:WaitForChild("RaceAssigned") :: RemoteEvent

-- Set to false while designing if you want to re-pick a race every join.
local REMEMBER_RACE = true
local DATASTORE_NAME = "EclipseRealms_PlayerRace_v1"

local raceStore: DataStore? = nil
if REMEMBER_RACE then
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		raceStore = store
	else
		warn("[RaceService] DataStore unavailable, race choices will not persist:", store)
	end
end

local function loadSavedRace(player: Player): string?
	if not raceStore then
		return nil
	end
	local ok, value = pcall(function()
		return (raceStore :: DataStore):GetAsync("race_" .. player.UserId)
	end)
	if ok and typeof(value) == "string" and RaceConfig.GetByName(value) then
		return value
	end
	return nil
end

local function saveRace(player: Player, raceName: string)
	if not raceStore then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			(raceStore :: DataStore):SetAsync("race_" .. player.UserId, raceName)
		end)
		if not ok then
			warn("[RaceService] Failed to save race for", player.Name, err)
		end
	end)
end

local function findRaceSpawn(race: RaceConfig.Race): SpawnLocation?
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	local spawn = map:FindFirstChild(race.Name .. "Spawn", true)
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn
	end
	return nil
end

local function assignRace(player: Player, raceName: string, persist: boolean): boolean
	local race = RaceConfig.GetByName(raceName)
	if not race then
		return false
	end
	local team = Teams:FindFirstChild(race.TeamName)
	if not team or not team:IsA("Team") then
		warn("[RaceService] Missing team", race.TeamName)
		return false
	end

	player.Team = team
	player.Neutral = false
	player:SetAttribute("Race", race.Name)

	local spawn = findRaceSpawn(race)
	if spawn then
		player.RespawnLocation = spawn
	end

	if persist then
		saveRace(player, race.Name)
	end

	RaceAssigned:FireClient(player, race.Name)

	-- Move them out of the lobby right away
	task.defer(function()
		if player.Parent then
			player:LoadCharacter()
		end
	end)
	return true
end

SelectRace.OnServerInvoke = function(player: Player, raceName: any): boolean
	if typeof(raceName) ~= "string" then
		return false
	end
	if player:GetAttribute("Race") ~= nil then
		-- Already chosen. (Race changing can be added later as a paid / cooldown feature.)
		return false
	end
	return assignRace(player, raceName, true)
end

local function onPlayerAdded(player: Player)
	player.Neutral = true
	player.Team = nil

	local saved = loadSavedRace(player)
	if saved then
		assignRace(player, saved, false)
	else
		-- Tell the client it needs to show the selection screen
		RaceAssigned:FireClient(player, nil)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, existing in Players:GetPlayers() do
	task.spawn(onPlayerAdded, existing)
end
