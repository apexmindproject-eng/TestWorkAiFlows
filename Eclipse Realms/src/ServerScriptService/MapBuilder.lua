--!strict
-- Builds the whole map out of Parts into Workspace.Map and the lobby into Workspace.Lobby.
-- Runs automatically on server start (see Bootstrap.server.lua). You can also bake it into the
-- place permanently from the Studio command bar:
--     require(game.ServerScriptService.MapBuilder).Build()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)
local MapConfig = require(ReplicatedStorage.Shared.MapConfig)

local MapBuilder = {}

local rng = Random.new(20261012) -- fixed seed so the map is identical every build

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame?,
	Position: Vector3?,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	CanCollide: boolean?,
	Reflectance: number?,
}

local function part(parent: Instance, props: PartProps): Part
	local p = Instance.new("Part")
	p.Name = props.Name or "Part"
	p.Anchored = true
	p.Size = props.Size
	p.Shape = props.Shape or Enum.PartType.Block
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or Color3.fromRGB(160, 160, 160)
	p.Transparency = props.Transparency or 0
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.Reflectance = props.Reflectance or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	if props.CFrame then
		p.CFrame = props.CFrame
	elseif props.Position then
		p.Position = props.Position
	end
	p.Parent = parent
	return p
end

-- Flat disc lying on the ground (a cylinder turned on its side).
local function disc(parent: Instance, name: string, center: Vector3, radius: number, thickness: number, color: Color3, material: Enum.Material): Part
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(center + Vector3.new(0, -thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

-- Vertical cylinder standing on the ground at `base`.
local function column(parent: Instance, name: string, base: Vector3, radius: number, height: number, color: Color3, material: Enum.Material): Part
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

local function box(parent: Instance, name: string, base: Vector3, size: Vector3, color: Color3, material: Enum.Material, yaw: number?): Part
	return part(parent, {
		Name = name,
		Size = size,
		CFrame = CFrame.new(base + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw or 0, 0),
		Color = color,
		Material = material,
	})
end

local function glow(p: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = p
end

local function label(p: BasePart, text: string, color: Color3?, size: Vector2?, offsetY: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset((size or Vector2.new(260, 60)).X, (size or Vector2.new(260, 60)).Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY or (p.Size.Y / 2 + 4), 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 350
	gui.Parent = p

	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.Text = text
	text_.TextColor3 = color or Color3.new(1, 1, 1)
	text_.TextStrokeTransparency = 0.2
	text_.TextStrokeColor3 = Color3.new(0, 0, 0)
	text_.Font = Enum.Font.Antique
	text_.TextScaled = true
	text_.Parent = gui
end

-- Rectangular road from world point a to b, lying on the ground.
local function road(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, color: Color3, material: Enum.Material)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	local p = part(parent, {
		Name = name,
		Size = Vector3.new(width, 0.4, length),
		CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, 0.2, 0),
		Color = color,
		Material = material,
	})
	return p
end

local function wallBetween(parent: Instance, name: string, a: Vector3, b: Vector3, height: number, thickness: number, color: Color3, material: Enum.Material)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	return part(parent, {
		Name = name,
		Size = Vector3.new(thickness, height, length + thickness),
		CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, height / 2, 0),
		Color = color,
		Material = material,
	})
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function makeSpawn(parent: Instance, name: string, position: Vector3, teamColor: BrickColor?, color: Color3): SpawnLocation
	local s = Instance.new("SpawnLocation")
	s.Name = name
	s.Anchored = true
	s.Size = Vector3.new(12, 1, 12)
	s.Position = position + Vector3.new(0, 0.5, 0)
	s.Color = color
	s.Material = Enum.Material.Neon
	s.TopSurface = Enum.SurfaceType.Smooth
	s.Duration = 0
	s.AllowTeamChangeOnTouch = false
	if teamColor then
		s.Neutral = false
		s.TeamColor = teamColor
	else
		s.Neutral = true
	end
	s.Parent = parent
	return s
end

-- Direction vectors for a sector: `outward` points away from the warzone.
local function sectorFrame(index: number)
	local angle = MapConfig.SectorCenterAngle(index)
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local right = Vector3.new(-outward.Z, 0, outward.X)
	return angle, outward, right
end

-------------------------------------------------------------------------------
-- World base: ground, rings, roads, walls
-------------------------------------------------------------------------------

local function buildGround(map: Folder)
	local g = folder(map, "Ground")
	local y = MapConfig.GroundY

	-- Whole world base (outer territories)
	disc(g, "WorldBase", Vector3.new(0, y - 0.3, 0), MapConfig.WorldRadius + 40, 8, Color3.fromRGB(78, 92, 60), Enum.Material.Grass)
	-- Neutral ring
	disc(g, "NeutralGround", Vector3.new(0, y - 0.15, 0), MapConfig.Neutral.Outer, 4, Color3.fromRGB(120, 112, 98), Enum.Material.Cobblestone)
	-- Warzone floor
	disc(g, "WarzoneGround", Vector3.new(0, y, 0), MapConfig.Warzone.Radius, 4, Color3.fromRGB(45, 40, 38), Enum.Material.Slate)

	-- Kill floor far below in case anyone falls off the world edge
	part(g, {
		Name = "VoidFloor",
		Size = Vector3.new(2000, 2, 2000),
		Position = Vector3.new(0, y - 120, 0),
		Transparency = 1,
		CanCollide = true,
	})
end

local function buildOuterWall(map: Folder)
	local f = folder(map, "OuterWall")
	local segments = 48
	local r = MapConfig.WorldRadius
	for i = 1, segments do
		local a0 = (i - 1) / segments * 2 * math.pi
		local a1 = i / segments * 2 * math.pi
		local p0 = MapConfig.PointOnRing(a0, r)
		local p1 = MapConfig.PointOnRing(a1, r)
		local h = 70 + rng:NextNumber(0, 30)
		wallBetween(f, "Cliff", p0, p1, h, 14, Color3.fromRGB(70, 70, 76), Enum.Material.Rock)
	end
end

local function buildSectorWalls(map: Folder)
	local f = folder(map, "SectorWalls")
	for i = 1, #RaceConfig.Races do
		local boundary = MapConfig.SectorCenterAngle(i) - MapConfig.SectorAngle / 2
		local a = MapConfig.PointOnRing(boundary, MapConfig.Neutral.Outer)
		local b = MapConfig.PointOnRing(boundary, MapConfig.WorldRadius)
		wallBetween(f, "SectorWall", a, b, MapConfig.WallHeight, MapConfig.WallThickness, Color3.fromRGB(60, 58, 64), Enum.Material.Basalt)
	end
end

local function buildRoads(map: Folder)
	local f = folder(map, "Roads")
	for i, race in RaceConfig.Races do
		local angle = MapConfig.SectorCenterAngle(i)
		local startC = MapConfig.StartCenter(i)
		local missionC = MapConfig.MissionCenter(i)
		local neutralEdge = MapConfig.PointOnRing(angle, MapConfig.Neutral.Outer)
		local warEdge = MapConfig.PointOnRing(angle, MapConfig.Warzone.Radius - 30)

		road(f, race.Name .. "Road_StartToMission", startC, missionC, MapConfig.RoadWidth, Color3.fromRGB(110, 100, 88), Enum.Material.Cobblestone)
		road(f, race.Name .. "Road_MissionToNeutral", missionC, neutralEdge, MapConfig.RoadWidth, Color3.fromRGB(110, 100, 88), Enum.Material.Cobblestone)
		road(f, race.Name .. "Road_NeutralToWar", neutralEdge, warEdge, MapConfig.RoadWidth, Color3.fromRGB(90, 70, 62), Enum.Material.CrackedLava)
	end

	-- Neutral ring road so players can circle between sectors
	local segments = 60
	local r = (MapConfig.Neutral.Inner + MapConfig.Neutral.Outer) / 2
	for i = 1, segments do
		local a0 = (i - 1) / segments * 2 * math.pi
		local a1 = i / segments * 2 * math.pi
		road(f, "NeutralRingRoad", MapConfig.PointOnRing(a0, r), MapConfig.PointOnRing(a1, r), 16, Color3.fromRGB(130, 120, 100), Enum.Material.Cobblestone)
	end
end

-------------------------------------------------------------------------------
-- Warzone
-------------------------------------------------------------------------------

local function buildWarzone(map: Folder)
	local f = folder(map, "Warzone")
	local r = MapConfig.Warzone.Radius

	-- Central Eclipse Altar: the high-reward objective
	local altarBase = disc(f, "AltarBase", Vector3.new(0, 3, 0), 30, 3, Color3.fromRGB(35, 30, 32), Enum.Material.Basalt)
	disc(f, "AltarStep", Vector3.new(0, 6, 0), 20, 3, Color3.fromRGB(50, 42, 45), Enum.Material.Basalt)
	disc(f, "AltarTop", Vector3.new(0, 9, 0), 10, 3, Color3.fromRGB(70, 55, 55), Enum.Material.Marble)
	for k = 1, 6 do
		local a = k / 6 * 2 * math.pi
		local base = MapConfig.PointOnRing(a, 26, 3)
		local pillar = column(f, "AltarPillar", base, 2.2, 28 + rng:NextNumber(-6, 4), Color3.fromRGB(40, 36, 40), Enum.Material.Basalt)
		pillar.Orientation = pillar.Orientation + Vector3.new(0, 0, rng:NextNumber(-6, 6))
	end
	local orb = part(f, {
		Name = "EclipseOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		Position = Vector3.new(0, 20, 0),
		Color = Color3.fromRGB(255, 120, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	glow(orb, Color3.fromRGB(255, 120, 40), 4, 90)
	label(altarBase, "ECLIPSE ALTAR\nHigh Risk - High Reward", Color3.fromRGB(255, 150, 80), Vector2.new(360, 90), 32)

	-- Craters
	for _ = 1, 14 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local d = rng:NextNumber(45, r - 15)
		local radius = rng:NextNumber(6, 16)
		disc(f, "Crater", MapConfig.PointOnRing(a, d, 0.15), radius, 0.3, Color3.fromRGB(25, 22, 22), Enum.Material.Asphalt)
		local ember = disc(f, "CraterEmber", MapConfig.PointOnRing(a, d, 0.2), radius * 0.35, 0.2, Color3.fromRGB(255, 80, 20), Enum.Material.Neon)
		glow(ember, Color3.fromRGB(255, 90, 30), 1.5, 24)
	end

	-- Rubble and broken pillars for cover
	for _ = 1, 40 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local d = rng:NextNumber(38, r - 8)
		local size = Vector3.new(rng:NextNumber(4, 12), rng:NextNumber(3, 10), rng:NextNumber(4, 12))
		local p = box(f, "Rubble", MapConfig.PointOnRing(a, d), size, Color3.fromRGB(55, 50, 50), Enum.Material.Slate, rng:NextNumber(0, math.pi))
		p.Orientation = p.Orientation + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
	end

	-- Ruined wall arcs
	for k = 1, 5 do
		local a = k / 5 * 2 * math.pi + 0.3
		local d = 95
		local p0 = MapConfig.PointOnRing(a - 0.12, d)
		local p1 = MapConfig.PointOnRing(a + 0.12, d)
		wallBetween(f, "RuinWall", p0, p1, 10 + rng:NextNumber(0, 6), 3, Color3.fromRGB(60, 55, 58), Enum.Material.Basalt)
	end

	-- Entry gates where each race's road enters the warzone
	for i, race in RaceConfig.Races do
		local angle, outward, right = sectorFrame(i)
		local gatePos = MapConfig.PointOnRing(angle, r + 2)
		local h = 26
		local w = MapConfig.RoadWidth
		local left = column(f, "GatePost", gatePos - right * (w / 2 + 2), 2, h, Color3.fromRGB(40, 36, 40), Enum.Material.Basalt)
		local rightPost = column(f, "GatePost", gatePos + right * (w / 2 + 2), 2, h, Color3.fromRGB(40, 36, 40), Enum.Material.Basalt)
		local lintel = part(f, {
			Name = "GateLintel",
			Size = Vector3.new(w + 10, 3, 4),
			CFrame = CFrame.lookAt(gatePos + Vector3.new(0, h + 1.5, 0), gatePos + Vector3.new(0, h + 1.5, 0) + outward),
			Color = Color3.fromRGB(40, 36, 40),
			Material = Enum.Material.Basalt,
		})
		local flame = part(f, {
			Name = "GateFlame",
			Size = Vector3.new(3, 3, 3),
			Position = gatePos + Vector3.new(0, h + 4.5, 0),
			Color = race.Accent,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Shape = Enum.PartType.Ball,
		})
		glow(flame, race.Accent, 2, 40)
		label(lintel, "WARZONE\nNo rules. No mercy.", Color3.fromRGB(255, 90, 60), Vector2.new(300, 80), 8)
		left.Name = race.Name .. "GateLeft"
		rightPost.Name = race.Name .. "GateRight"
	end
end

-------------------------------------------------------------------------------
-- Neutral ring
-------------------------------------------------------------------------------

local function buildNeutral(map: Folder)
	local f = folder(map, "Neutral")
	local rRoad = (MapConfig.Neutral.Inner + MapConfig.Neutral.Outer) / 2

	-- Lamp posts along the ring road
	local posts = 30
	for k = 1, posts do
		local a = k / posts * 2 * math.pi
		local base = MapConfig.PointOnRing(a, rRoad + 11)
		column(f, "LampPost", base, 0.5, 12, Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
		local lamp = part(f, {
			Name = "Lamp",
			Size = Vector3.new(2, 2, 2),
			Position = base + Vector3.new(0, 13, 0),
			Color = Color3.fromRGB(255, 225, 150),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		glow(lamp, Color3.fromRGB(255, 220, 150), 1.2, 30)
	end

	-- A small trade post between every pair of sectors (future: shops / black market)
	for i = 1, #RaceConfig.Races do
		local a = MapConfig.SectorCenterAngle(i) + MapConfig.SectorAngle / 2
		local base = MapConfig.PointOnRing(a, rRoad)
		local pad = disc(f, "TradePostFloor", base, 14, 1, Color3.fromRGB(150, 135, 110), Enum.Material.WoodPlanks)
		for cx = -1, 1, 2 do
			for cz = -1, 1, 2 do
				column(f, "TradePostPole", base + Vector3.new(cx * 9, 0, cz * 9), 0.7, 11, Color3.fromRGB(95, 70, 45), Enum.Material.Wood)
			end
		end
		box(f, "TradePostRoof", base + Vector3.new(0, 11, 0), Vector3.new(24, 1.5, 24), Color3.fromRGB(120, 50, 40), Enum.Material.Fabric)
		box(f, "TradeCounter", base + Vector3.new(0, 1, 0), Vector3.new(10, 3.5, 2.5), Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
		label(pad, "NEUTRAL TRADE POST\n(shops coming soon)", Color3.fromRGB(240, 220, 170), Vector2.new(320, 80), 16)
	end

	-- Zone marker signs at each sector entrance from the neutral ring
	for i, race in RaceConfig.Races do
		local angle, _, right = sectorFrame(i)
		local base = MapConfig.PointOnRing(angle, MapConfig.Neutral.Outer - 6) + right * (MapConfig.RoadWidth / 2 + 4)
		local post = column(f, "SignPost", base, 0.6, 9, Color3.fromRGB(80, 60, 40), Enum.Material.Wood)
		local board = box(f, "SignBoard", base + Vector3.new(0, 7, 0), Vector3.new(7, 3, 0.6), race.Color, Enum.Material.WoodPlanks, -angle)
		label(board, race.MissionZone .. "\n" .. race.Plural .. " only beyond", race.Accent, Vector2.new(300, 70), 4)
		post.Name = race.Name .. "SignPost"
	end
end

-------------------------------------------------------------------------------
-- Mission zones (one per race)
-------------------------------------------------------------------------------

local function buildMissionZone(parent: Folder, index: number, race: RaceConfig.Race)
	local f = folder(parent, race.MissionZone)
	local center = MapConfig.MissionCenter(index)
	local angle, outward, right = sectorFrame(index)

	disc(f, "MissionGround", center + Vector3.new(0, 0.1, 0), MapConfig.Mission.Radius, 1, race.Color:Lerp(Color3.fromRGB(90, 90, 90), 0.55), Enum.Material.Ground)

	-- Mission board
	local boardPos = center + right * 30
	column(f, "MissionBoardPost", boardPos - right * 3, 0.6, 10, Color3.fromRGB(70, 55, 40), Enum.Material.Wood)
	column(f, "MissionBoardPost", boardPos + right * 3, 0.6, 10, Color3.fromRGB(70, 55, 40), Enum.Material.Wood)
	local board = box(f, "MissionBoard", boardPos + Vector3.new(0, 5, 0), Vector3.new(8, 5, 0.8), Color3.fromRGB(60, 45, 35), Enum.Material.WoodPlanks, -angle)
	label(board, race.MissionZone .. "\nMISSION BOARD", race.Accent, Vector2.new(340, 80), 5)

	-- Three mission pads where quest givers / objectives will live
	for k = -1, 1 do
		local pos = center - right * 25 + outward * (k * 22)
		local pad = disc(f, "MissionPad" .. (k + 2), pos + Vector3.new(0, 0.3, 0), 5, 0.4, race.Accent, Enum.Material.Neon)
		glow(pad, race.Accent, 1, 20)
		label(pad, "Mission " .. (k + 2) .. "\n(coming soon)", Color3.new(1, 1, 1), Vector2.new(200, 60), 6)
	end

	-- Theme props
	if race.Name == "Vampire" then
		for _ = 1, 10 do
			local p = center + Vector3.new(rng:NextNumber(-45, 45), 0, rng:NextNumber(-45, 45))
			box(f, "Tombstone", p, Vector3.new(3, rng:NextNumber(4, 7), 1), Color3.fromRGB(70, 70, 75), Enum.Material.Slate, rng:NextNumber(-0.3, 0.3))
		end
		box(f, "CryptEntrance", center + outward * 40, Vector3.new(14, 12, 10), Color3.fromRGB(45, 40, 48), Enum.Material.Basalt, -angle)
	elseif race.Name == "Wolf" then
		for _ = 1, 12 do
			local p = center + Vector3.new(rng:NextNumber(-50, 50), 0, rng:NextNumber(-50, 50))
			local rock = part(f, { Name = "Boulder", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(4, 9), Position = p, Color = Color3.fromRGB(95, 90, 85), Material = Enum.Material.Rock })
			rock.Position = p + Vector3.new(0, rock.Size.Y * 0.3, 0)
		end
	elseif race.Name == "Witch" then
		for _ = 1, 10 do
			local p = center + Vector3.new(rng:NextNumber(-50, 50), 0, rng:NextNumber(-50, 50))
			local pool = disc(f, "MarshPool", p + Vector3.new(0, 0.2, 0), rng:NextNumber(4, 9), 0.3, Color3.fromRGB(40, 90, 60), Enum.Material.Glass)
			pool.Transparency = 0.3
			column(f, "DeadTree", p + Vector3.new(6, 0, 2), 0.8, rng:NextNumber(10, 16), Color3.fromRGB(45, 40, 38), Enum.Material.Wood)
		end
	elseif race.Name == "Human" then
		-- Palisade outpost
		for k = 1, 16 do
			local a = k / 16 * 2 * math.pi
			if k % 8 ~= 0 then
				column(f, "PalisadeLog", center + Vector3.new(math.cos(a) * 52, 0, math.sin(a) * 52), 1.2, 9, Color3.fromRGB(100, 75, 45), Enum.Material.Wood)
			end
		end
		box(f, "Watchtower", center + right * -40, Vector3.new(8, 18, 8), Color3.fromRGB(110, 85, 55), Enum.Material.WoodPlanks)
	elseif race.Name == "Monk" then
		-- Stone steps and training posts
		for k = 1, 8 do
			local a = k / 8 * 2 * math.pi
			column(f, "TrainingPost", center + Vector3.new(math.cos(a) * 40, 0, math.sin(a) * 40), 0.8, 7, Color3.fromRGB(150, 120, 80), Enum.Material.Wood)
		end
		disc(f, "MeditationRing", center + Vector3.new(0, 0.4, 0), 12, 0.6, Color3.fromRGB(220, 235, 220), Enum.Material.Marble)
	end
end

-------------------------------------------------------------------------------
-- Start zones (one per race)
-------------------------------------------------------------------------------

local function buildTree(parent: Folder, base: Vector3, trunkH: number, leafColor: Color3, leafSize: number)
	column(parent, "Trunk", base, 1.1, trunkH, Color3.fromRGB(70, 50, 35), Enum.Material.Wood)
	local leaves = part(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * leafSize,
		Position = base + Vector3.new(0, trunkH + leafSize * 0.3, 0),
		Color = leafColor,
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
	return leaves
end

local function buildStartZone(parent: Folder, index: number, race: RaceConfig.Race): SpawnLocation
	local f = folder(parent, race.StartZone)
	local center = MapConfig.StartCenter(index)
	local angle, outward, right = sectorFrame(index)
	local R = MapConfig.Start.Radius

	disc(f, "StartGround", center + Vector3.new(0, 0.15, 0), R, 1.2, race.Color:Lerp(Color3.fromRGB(110, 110, 110), 0.5), Enum.Material.Ground)

	-- Spawn pad sits toward the back of the zone, facing the road
	local spawnPos = center + outward * 20
	local spawn = makeSpawn(f, race.Name .. "Spawn", spawnPos, BrickColor.new(race.TeamColor), race.Accent)
	label(spawn, race.StartZone .. "\nHome of the " .. race.Plural, race.Accent, Vector2.new(360, 90), 14)

	-- Race banner pillars flanking the road exit
	for side = -1, 1, 2 do
		local base = center - outward * (R - 6) + right * side * (MapConfig.RoadWidth / 2 + 5)
		column(f, "BannerPillar", base, 1.5, 22, Color3.fromRGB(60, 58, 62), Enum.Material.Basalt)
		local banner = box(f, "Banner", base + Vector3.new(0, 10, 0), Vector3.new(0.4, 10, 5), race.Accent, Enum.Material.Fabric, -angle)
		banner.CanCollide = false
	end

	if race.Name == "Vampire" then
		-- Castle Noctis: dark keep with four towers and glowing red windows
		local keepPos = center + outward * 36
		box(f, "Keep", keepPos, Vector3.new(34, 34, 44), Color3.fromRGB(38, 32, 40), Enum.Material.Basalt, -angle)
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local tbase = keepPos + right * sx * 22 + outward * sz * 17
				column(f, "Tower", tbase, 6, 56, Color3.fromRGB(32, 27, 35), Enum.Material.Basalt)
				local cap = disc(f, "TowerCap", tbase + Vector3.new(0, 58, 0), 7.5, 2, Color3.fromRGB(80, 15, 25), Enum.Material.Slate)
				local win = part(f, { Name = "Window", Size = Vector3.new(2, 4, 2), Position = tbase + Vector3.new(0, 40, 0) - outward * 6, Color = Color3.fromRGB(255, 40, 60), Material = Enum.Material.Neon, CanCollide = false })
				glow(win, Color3.fromRGB(255, 40, 60), 1.5, 30)
				cap.Name = "TowerCap"
			end
		end
		local door = box(f, "KeepDoor", keepPos - outward * 17.3, Vector3.new(1, 14, 10), Color3.fromRGB(20, 10, 12), Enum.Material.Wood, -angle)
		door.CanCollide = false
		-- Dead trees and a blood moon
		for _ = 1, 8 do
			local p = center + Vector3.new(rng:NextNumber(-R + 10, R - 10), 0, rng:NextNumber(-R + 10, R - 10))
			if (p - keepPos).Magnitude > 40 then
				column(f, "DeadTree", p, 0.9, rng:NextNumber(12, 18), Color3.fromRGB(40, 35, 35), Enum.Material.Wood)
			end
		end
		local moon = part(f, { Name = "BloodMoon", Shape = Enum.PartType.Ball, Size = Vector3.one * 26, Position = center + outward * 120 + Vector3.new(0, 150, 0), Color = Color3.fromRGB(200, 40, 50), Material = Enum.Material.Neon, CanCollide = false })
		glow(moon, Color3.fromRGB(200, 40, 50), 2, 200)

	elseif race.Name == "Wolf" then
		-- Moonfang Forest: dense trees, a den rock and a moon totem
		for _ = 1, 34 do
			local p = center + Vector3.new(rng:NextNumber(-R + 8, R - 8), 0, rng:NextNumber(-R + 8, R - 8))
			if (p - spawnPos).Magnitude > 16 and (math.abs((p - center):Dot(right)) > 14 or (p - center):Dot(outward) > 10) then
				buildTree(f, p, rng:NextNumber(10, 20), Color3.fromRGB(35, 70, 40):Lerp(Color3.fromRGB(60, 95, 45), rng:NextNumber()), rng:NextNumber(10, 16))
			end
		end
		local den = part(f, { Name = "DenRock", Shape = Enum.PartType.Ball, Size = Vector3.new(40, 26, 34), Position = center + outward * 45 + Vector3.new(0, 6, 0), Color = Color3.fromRGB(85, 80, 75), Material = Enum.Material.Rock })
		den.Name = "DenRock"
		local totem = column(f, "MoonTotem", center + right * 30, 1.5, 18, Color3.fromRGB(90, 65, 40), Enum.Material.Wood)
		local moonStone = part(f, { Name = "MoonStone", Shape = Enum.PartType.Ball, Size = Vector3.one * 5, Position = totem.Position + Vector3.new(0, 12, 0), Color = Color3.fromRGB(230, 235, 255), Material = Enum.Material.Neon, CanCollide = false })
		glow(moonStone, Color3.fromRGB(200, 210, 255), 2, 50)

	elseif race.Name == "Witch" then
		-- Hexwood Coven: crooked huts, giant cauldron and a rune stone circle
		local cauldronPos = center + outward * 30
		local cauldron = column(f, "Cauldron", cauldronPos, 8, 9, Color3.fromRGB(30, 30, 35), Enum.Material.Metal)
		local brew = disc(f, "Brew", cauldronPos + Vector3.new(0, 9.2, 0), 7.2, 0.6, Color3.fromRGB(90, 255, 120), Enum.Material.Neon)
		glow(brew, Color3.fromRGB(90, 255, 120), 2.5, 50)
		cauldron.Name = "Cauldron"
		for k = 1, 8 do
			local a = k / 8 * 2 * math.pi
			local sp = cauldronPos + Vector3.new(math.cos(a) * 22, 0, math.sin(a) * 22)
			local stone = box(f, "RuneStone", sp, Vector3.new(4, rng:NextNumber(9, 14), 2.5), Color3.fromRGB(55, 50, 65), Enum.Material.Slate, a)
			stone.Orientation = stone.Orientation + Vector3.new(rng:NextNumber(-8, 8), 0, 0)
			local rune = part(f, { Name = "Rune", Size = Vector3.new(1.5, 1.5, 0.3), CFrame = stone.CFrame * CFrame.new(0, 2, 1.4), Color = race.Accent, Material = Enum.Material.Neon, CanCollide = false })
			glow(rune, race.Accent, 1, 14)
		end
		for k = 1, 3 do
			local hp = center + right * (k - 2) * 38 - outward * 10 + outward * (k == 2 and -30 or 0)
			local hut = box(f, "Hut", hp, Vector3.new(14, 11, 14), Color3.fromRGB(60, 45, 70), Enum.Material.WoodPlanks, rng:NextNumber(-0.3, 0.3))
			hut.Orientation = hut.Orientation + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
			local roof = box(f, "HutRoof", hp + Vector3.new(0, 11, 0), Vector3.new(17, 6, 17), Color3.fromRGB(35, 25, 45), Enum.Material.Slate, rng:NextNumber(-0.3, 0.3))
			roof.Orientation = roof.Orientation + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
			local orb = part(f, { Name = "WispOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Position = hp + Vector3.new(0, 22, 0), Color = Color3.fromRGB(200, 120, 255), Material = Enum.Material.Neon, CanCollide = false })
			glow(orb, Color3.fromRGB(200, 120, 255), 1.5, 30)
		end
		for _ = 1, 10 do
			local p = center + Vector3.new(rng:NextNumber(-R + 8, R - 8), 0, rng:NextNumber(-R + 8, R - 8))
			if (p - cauldronPos).Magnitude > 30 and (p - spawnPos).Magnitude > 14 then
				buildTree(f, p, rng:NextNumber(12, 20), Color3.fromRGB(70, 40, 90), rng:NextNumber(8, 12))
			end
		end

	elseif race.Name == "Human" then
		-- Aldermere Keep: walled town with corner towers, a great hall and torches
		local half = R - 14
		local corners = {
			center + right * half + outward * half,
			center - right * half + outward * half,
			center - right * half - outward * half,
			center + right * half - outward * half,
		}
		for k = 1, 4 do
			local a = corners[k]
			local b = corners[k % 4 + 1]
			if k == 3 then
				-- Front wall has the gate opening toward the road
				local gapHalf = MapConfig.RoadWidth / 2 + 2
				local mid = (a + b) / 2
				wallBetween(f, "TownWall", a, mid - right * gapHalf, 16, 4, Color3.fromRGB(150, 145, 135), Enum.Material.Brick)
				wallBetween(f, "TownWall", mid + right * gapHalf, b, 16, 4, Color3.fromRGB(150, 145, 135), Enum.Material.Brick)
				local arch = part(f, { Name = "GateArch", Size = Vector3.new(gapHalf * 2 + 8, 4, 5), CFrame = CFrame.lookAt(mid + Vector3.new(0, 18, 0), mid + Vector3.new(0, 18, 0) + outward), Color = Color3.fromRGB(150, 145, 135), Material = Enum.Material.Brick })
				label(arch, "ALDERMERE KEEP", race.Accent, Vector2.new(320, 70), 5)
			else
				wallBetween(f, "TownWall", a, b, 16, 4, Color3.fromRGB(150, 145, 135), Enum.Material.Brick)
			end
			column(f, "CornerTower", a, 6, 26, Color3.fromRGB(135, 130, 120), Enum.Material.Brick)
			disc(f, "TowerRoof", a + Vector3.new(0, 28, 0), 7.5, 2, Color3.fromRGB(40, 60, 120), Enum.Material.Slate)
			local torch = part(f, { Name = "Torch", Size = Vector3.new(1.5, 1.5, 1.5), Position = a + Vector3.new(0, 30, 0), Color = Color3.fromRGB(255, 190, 80), Material = Enum.Material.Neon, CanCollide = false })
			glow(torch, Color3.fromRGB(255, 180, 80), 1.5, 40)
		end
		local hallPos = center + outward * 30
		box(f, "GreatHall", hallPos, Vector3.new(36, 20, 24), Color3.fromRGB(170, 160, 140), Enum.Material.Brick, -angle)
		box(f, "GreatHallRoof", hallPos + Vector3.new(0, 20, 0), Vector3.new(38, 5, 26), Color3.fromRGB(40, 60, 120), Enum.Material.Slate, -angle)
		for k = -1, 1, 2 do
			box(f, "House", center + right * k * 38 + outward * 5, Vector3.new(14, 10, 14), Color3.fromRGB(180, 165, 135), Enum.Material.WoodPlanks, -angle)
			box(f, "HouseRoof", center + right * k * 38 + outward * 5 + Vector3.new(0, 10, 0), Vector3.new(16, 4, 16), Color3.fromRGB(110, 60, 40), Enum.Material.Slate, -angle)
		end
		disc(f, "Fountain", center - outward * 10, 6, 2, Color3.fromRGB(160, 160, 165), Enum.Material.Marble)
		local water = disc(f, "FountainWater", center - outward * 10 + Vector3.new(0, 2.2, 0), 5, 0.4, Color3.fromRGB(90, 160, 255), Enum.Material.Glass)
		water.Transparency = 0.35

	elseif race.Name == "Monk" then
		-- Jade Monastery: tiered pagoda on a raised platform, blossom trees and a bell
		local platformPos = center + outward * 28
		disc(f, "MonasteryPlatform", platformPos + Vector3.new(0, 2.5, 0), 40, 2.5, Color3.fromRGB(225, 225, 215), Enum.Material.Marble)
		-- Steps down toward the spawn
		for s = 1, 4 do
			box(f, "Step", platformPos - outward * (40 + s * 2.5) + Vector3.new(0, 2.5 - s * 0.6, 0), Vector3.new(2.5, 0.6, 20), Color3.fromRGB(210, 210, 200), Enum.Material.Marble, -angle)
		end
		local tiers = { Vector3.new(34, 12, 34), Vector3.new(26, 10, 26), Vector3.new(18, 9, 18) }
		local y = 2.5
		for _, size in tiers do
			box(f, "PagodaTier", platformPos + Vector3.new(0, y, 0), size, Color3.fromRGB(235, 225, 200), Enum.Material.Wood, -angle)
			box(f, "PagodaRoof", platformPos + Vector3.new(0, y + size.Y, 0), Vector3.new(size.X + 8, 2.5, size.Z + 8), Color3.fromRGB(40, 130, 100), Enum.Material.Slate, -angle)
			y += size.Y + 2.5
		end
		local spire = part(f, { Name = "Spire", Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Position = platformPos + Vector3.new(0, y + 2, 0), Color = Color3.fromRGB(255, 215, 90), Material = Enum.Material.Neon, CanCollide = false })
		glow(spire, Color3.fromRGB(255, 215, 90), 1.5, 50)
		for k = -1, 1, 2 do
			buildTree(f, center + right * k * 48 - outward * 5, 10, Color3.fromRGB(240, 150, 190), 11)
			buildTree(f, center + right * k * 40 + outward * 40, 12, Color3.fromRGB(240, 150, 190), 12)
		end
		local bellFrame = box(f, "BellFrame", center - right * 30 - outward * 20, Vector3.new(8, 10, 1.5), Color3.fromRGB(120, 60, 40), Enum.Material.Wood, -angle)
		local bell = part(f, { Name = "Bell", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 4, 4), CFrame = bellFrame.CFrame * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(190, 150, 60), Material = Enum.Material.Metal })
		bell.Name = "Bell"
	end

	return spawn
end

-------------------------------------------------------------------------------
-- Lobby (Selection Chamber)
-------------------------------------------------------------------------------

local function buildLobby(lobby: Folder)
	local pos = MapConfig.Lobby.Position
	local size = MapConfig.Lobby.Size

	local floor = part(lobby, { Name = "LobbyFloor", Size = size, Position = pos, Color = Color3.fromRGB(30, 30, 40), Material = Enum.Material.Marble })
	disc(lobby, "LobbyRing", pos + Vector3.new(0, size.Y / 2 + 0.2, 0), 30, 0.4, Color3.fromRGB(120, 110, 160), Enum.Material.Neon)
	local topY = pos.Y + size.Y / 2

	-- Invisible walls so nobody wanders off the edge
	local wallH = 40
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local along = Vector3.new(math.abs(dir.Z), 0, math.abs(dir.X))
		part(lobby, {
			Name = "LobbyWall",
			Size = Vector3.new(1, wallH, 1) + along * (size.X + 2),
			Position = pos + dir * (size.X / 2 + 0.5) + Vector3.new(0, wallH / 2, 0),
			Transparency = 1,
		})
	end

	-- One glowing pillar per race around the edge
	for i, race in RaceConfig.Races do
		local a = MapConfig.SectorCenterAngle(i)
		local base = Vector3.new(pos.X + math.cos(a) * 32, topY, pos.Z + math.sin(a) * 32)
		local pillar = column(lobby, race.Name .. "Pillar", base, 2, 18, race.Color, Enum.Material.Marble)
		local crystal = part(lobby, { Name = race.Name .. "Crystal", Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Position = base + Vector3.new(0, 20, 0), Color = race.Accent, Material = Enum.Material.Neon, CanCollide = false })
		glow(crystal, race.Accent, 2, 40)
		label(pillar, race.Plural, race.Accent, Vector2.new(200, 50), 14)
	end

	local spawn = makeSpawn(lobby, "LobbySpawn", Vector3.new(pos.X, topY, pos.Z), nil, Color3.fromRGB(200, 200, 230))
	label(spawn, "SELECTION CHAMBER\nChoose your race", Color3.fromRGB(230, 230, 255), Vector2.new(360, 90), 14)
	floor.Name = "LobbyFloor"
end

-------------------------------------------------------------------------------
-- Public
-------------------------------------------------------------------------------

function MapBuilder.Build()
	local map = Workspace:FindFirstChild("Map") :: Folder?
	if not map then
		map = folder(Workspace, "Map")
	end
	assert(map)
	map:ClearAllChildren()

	local lobby = Workspace:FindFirstChild("Lobby") :: Folder?
	if not lobby then
		lobby = folder(Workspace, "Lobby")
	end
	assert(lobby)
	lobby:ClearAllChildren()

	-- Remove the template baseplate if it's still around
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local templateSpawn = Workspace:FindFirstChildOfClass("SpawnLocation")
	if templateSpawn then
		templateSpawn:Destroy()
	end

	buildGround(map)
	buildOuterWall(map)
	buildSectorWalls(map)
	buildRoads(map)
	buildWarzone(map)
	buildNeutral(map)

	local missions = folder(map, "MissionZones")
	local starts = folder(map, "StartZones")
	for i, race in RaceConfig.Races do
		buildMissionZone(missions, i, race)
		buildStartZone(starts, i, race)
	end

	buildLobby(lobby)

	map:SetAttribute("Built", true)
	print(("[MapBuilder] Built %d parts"):format(#map:GetDescendants() + #lobby:GetDescendants()))
end

return MapBuilder
