--!strict
-- Builds the whole world: terrain, roads, the Neutral Grounds, the Warzone and the five
-- race territories, plus the hidden holding chamber new players wait in.
-- Runs on server start (see Bootstrap.server.lua). To bake it into the place permanently,
-- run this in the Studio command bar and then save:
--     require(game.ServerScriptService.MapBuilder).Build()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)
local MapConfig = require(ReplicatedStorage.Shared.MapConfig)
local Lib = require(script.Lib)
local World = require(script.World)
local Types = require(script.Types)

local Territories = {
	Vampire = require(script.Territories.Vampire),
	Wolf = require(script.Territories.Wolf),
	Witch = require(script.Territories.Witch),
	Human = require(script.Territories.Human),
	Monk = require(script.Territories.Monk),
}

local MapBuilder = {}

local function makeCtx(index: number, race: RaceConfig.Race, parent: Folder): Types.Ctx
	local angle = MapConfig.SectorCenterAngle(index)
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local toward = -outward
	local right = Vector3.new(-outward.Z, 0, outward.X)
	local hub = MapConfig.HubCenter(index)
	local ctx: Types.Ctx = {
		index = index,
		race = race,
		angle = angle,
		outward = outward,
		toward = toward,
		right = right,
		hub = hub,
		folder = Lib.folder(parent, race.StartZone),
		avoid = {},
		P = function(forward: number, side: number, y: number?): Vector3
			return hub + toward * forward + right * side + Vector3.new(0, y or 0, 0)
		end,
		ringPoint = function(radius: number, angleOffset: number): Vector3
			return MapConfig.PointOnRing(angle + angleOffset, radius)
		end,
	}
	return ctx
end

local function buildHoldingChamber(parent: Folder)
	local c = MapConfig.HoldingChamber
	local pos, size = c.Position, c.Size
	local dark = Color3.fromRGB(12, 12, 16)
	Lib.part(parent, { Name = "Floor", Size = Vector3.new(size.X, 1, size.Z), Position = pos - Vector3.new(0, size.Y / 2, 0), Color = dark, Material = Enum.Material.Slate })
	Lib.part(parent, { Name = "Ceiling", Size = Vector3.new(size.X, 1, size.Z), Position = pos + Vector3.new(0, size.Y / 2, 0), Color = dark, Material = Enum.Material.Slate })
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local along = Vector3.new(math.abs(dir.Z), 0, math.abs(dir.X))
		Lib.part(parent, {
			Name = "Wall",
			Size = Vector3.new(1, size.Y, 1) + along * size.X,
			Position = pos + dir * (size.X / 2),
			Color = dark,
			Material = Enum.Material.Slate,
		})
	end
	Lib.spawnLocation(parent, "HoldingSpawn", pos - Vector3.new(0, size.Y / 2 - 0.5, 0), nil)
end

function MapBuilder.Build()
	local t0 = os.clock()

	local map = Workspace:FindFirstChild("Map") :: Folder?
	if not map then
		map = Lib.folder(Workspace, "Map")
	end
	assert(map)
	map:ClearAllChildren()

	local holding = Workspace:FindFirstChild("HoldingChamber") :: Folder?
	if not holding then
		holding = Lib.folder(Workspace, "HoldingChamber")
	end
	assert(holding)
	holding:ClearAllChildren()

	for _, name in { "Baseplate", "SpawnLocation" } do
		local leftover = Workspace:FindFirstChild(name)
		if leftover then
			leftover:Destroy()
		end
	end

	-- Water look
	local terrain = Workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(18, 50, 60)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 8

	Lib.resetGround()

	-- 1. Terrain
	World.terrainBase()
	local territoriesFolder = Lib.folder(map, "Territories")
	local ctxs: { Types.Ctx } = {}
	for i, race in RaceConfig.Races do
		local ctx = makeCtx(i, race, territoriesFolder)
		ctxs[i] = ctx
		Territories[race.Name].terrain(ctx)
	end

	-- 2. Roads (need final ground heights)
	World.roads()

	-- 3. Structures and props
	World.neutral(map)
	World.warzone(map)
	for i, race in RaceConfig.Races do
		Territories[race.Name].build(ctxs[i])
	end

	buildHoldingChamber(holding)

	map:SetAttribute("Built", true)
	print(("[MapBuilder] World built: %d instances in %.1fs"):format(#map:GetDescendants(), os.clock() - t0))
end

return MapBuilder
