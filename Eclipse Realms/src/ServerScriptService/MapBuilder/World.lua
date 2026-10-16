--!strict
-- World-level terrain and the shared zones: mountains, river, roads, Neutral Grounds, Warzone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)
local MapConfig = require(ReplicatedStorage.Shared.MapConfig)
local Lib = require(script.Parent.Lib)
local Props = require(script.Parent.Props)

local World = {}

local M = Enum.Material

-- Points along every road, so scatter functions can avoid them.
World.RoadPolylines = {} :: { { Vector3 } }
World.CraterPositions = {} :: { { pos: Vector3, r: number } }

local function addRoad(points: { Vector3 }, width: number, material: Enum.Material)
	table.insert(World.RoadPolylines, points)
	Lib.terrainRoad(points, width, material)
end

-- Distance from a flat point to the nearest road segment
function World.distanceToRoad(x: number, z: number): number
	local best = math.huge
	local p = Vector2.new(x, z)
	for _, line in World.RoadPolylines do
		for i = 1, #line - 1 do
			local a = Vector2.new(line[i].X, line[i].Z)
			local b = Vector2.new(line[i + 1].X, line[i + 1].Z)
			local ab = b - a
			local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
			local d = (a + ab * t - p).Magnitude
			if d < best then
				best = d
			end
		end
	end
	return best
end

-------------------------------------------------------------------------------
-- Base terrain
-------------------------------------------------------------------------------

function World.terrainBase()
	local terrain = Workspace.Terrain
	terrain:Clear()

	-- Ground slab for the whole world
	Lib.fillCylinder(Vector3.new(0, -14, 0), 28, 1400, M.Grass)

	-- Neutral grounds: slightly different grass with worn patches
	Lib.fillCylinder(Vector3.new(0, -2, 0), 4, MapConfig.Neutral.Outer, M.LeafyGrass)
	for _ = 1, 26 do
		local a = Lib.rand(0, 2 * math.pi)
		local d = Lib.rand(MapConfig.Neutral.Inner + 20, MapConfig.Neutral.Outer - 20)
		Lib.fillCylinder(MapConfig.PointOnRing(a, d, -2), 4, Lib.rand(12, 30), Lib.pick({ M.Ground, M.Grass, M.Mud }))
	end

	-- Warzone: basalt floor, scorched
	Lib.fillCylinder(Vector3.new(0, -14, 0), 28, MapConfig.Warzone.RimOuter, M.Basalt)
	for _ = 1, 40 do
		local a = Lib.rand(0, 2 * math.pi)
		local d = Lib.rand(0, MapConfig.Warzone.Radius - 10)
		Lib.fillCylinder(MapConfig.PointOnRing(a, d, -2), 4, Lib.rand(10, 28), Lib.pick({ M.CrackedLava, M.Slate, M.Asphalt, M.Basalt, M.Rock }))
	end

	-- River ring with sandy banks
	Lib.fillCylinder(Vector3.new(0, -2, 0), 4, MapConfig.River.BankOuter, M.Sand)
	Lib.fillCylinder(Vector3.new(0, -8, 0), 16, MapConfig.River.Outer, M.Air)
	Lib.fillCylinder(Vector3.new(0, -8.75, 0), 14.5, MapConfig.River.Outer, M.Water)
	Lib.fillCylinder(Vector3.new(0, -8, 0), 16, MapConfig.River.Inner - 4, M.LeafyGrass)
	Lib.fillCylinder(Vector3.new(0, -2, 0), 4, MapConfig.River.Inner, M.Sand)
	Lib.fillCylinder(Vector3.new(0, -2, 0), 4, MapConfig.River.BankInner, M.LeafyGrass)

	-- Crater rim around the warzone, with gaps where the roads enter
	local rimR = MapConfig.Warzone.RimOuter - 12
	local steps = 60
	for k = 1, steps do
		local a = k / steps * 2 * math.pi
		local nearRoad = false
		for i = 1, #RaceConfig.Races do
			local da = math.abs((a - MapConfig.SectorCenterAngle(i) + math.pi) % (2 * math.pi) - math.pi)
			if da < math.rad(7) then
				nearRoad = true
			end
		end
		if not nearRoad then
			local r = Lib.rand(22, 38)
			local p = MapConfig.PointOnRing(a + Lib.rand(-0.02, 0.02), rimR + Lib.rand(-8, 8))
			Lib.hill(p.X, p.Z, r, r * 0.55, M.Basalt, M.Rock)
		end
	end

	-- Craters inside the warzone
	for _ = 1, 18 do
		local a = Lib.rand(0, 2 * math.pi)
		local d = Lib.rand(50, MapConfig.Warzone.Radius - 30)
		local r = Lib.rand(8, 16)
		local p = MapConfig.PointOnRing(a, d)
		Lib.fillBall(p + Vector3.new(0, r * 0.55, 0), r, M.Air)
		Lib.fillBall(p + Vector3.new(0, -r * 0.2, 0), r * 0.45, M.CrackedLava)
		table.insert(World.CraterPositions, { pos = p, r = r + 4 })
	end

	-- Outer mountain ring
	local mountains = 44
	for k = 1, mountains do
		local a = k / mountains * 2 * math.pi + Lib.rand(-0.03, 0.03)
		local r = Lib.rand(120, 180)
		local p = MapConfig.PointOnRing(a, MapConfig.WorldRadius + 60 + Lib.rand(-30, 30))
		Lib.fillBall(Vector3.new(p.X, -r * 0.3, p.Z), r, M.Rock)
		Lib.fillBall(Vector3.new(p.X, r * 0.42, p.Z), r * 0.42, M.Snow)
		Lib.registerHill(p.X, p.Z, -r * 0.3, r)
	end
	-- Inner foothills so the edge of each territory rises naturally
	for k = 1, 60 do
		local a = k / 60 * 2 * math.pi + Lib.rand(-0.04, 0.04)
		local r = Lib.rand(50, 85)
		local p = MapConfig.PointOnRing(a, MapConfig.Territory.Outer + Lib.rand(-10, 30))
		Lib.hill(p.X, p.Z, r, r * 0.45, M.Rock, M.Grass)
	end

	-- Ridges between the five territories
	for i = 1, #RaceConfig.Races do
		local boundary = MapConfig.SectorCenterAngle(i) - MapConfig.SectorAngle / 2
		local d = MapConfig.Territory.Inner + 30
		while d < MapConfig.Territory.Outer do
			local r = Lib.rand(42, 70)
			local p = MapConfig.PointOnRing(boundary + Lib.rand(-0.01, 0.01), d)
			Lib.hill(p.X, p.Z, r, r * 0.4, M.Rock, if d > 900 then M.Snow else M.Grass)
			d += r * 0.9
		end
	end

	-- Clouds
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.3
	clouds.Color = Color3.fromRGB(225, 215, 230)
	clouds.Parent = terrain
end

-------------------------------------------------------------------------------
-- Roads
-------------------------------------------------------------------------------

local function jitter(p: Vector3, right: Vector3, amount: number): Vector3
	return p + right * Lib.rand(-amount, amount)
end

function World.roads()
	local w = MapConfig.RoadWidth
	for i = 1, #RaceConfig.Races do
		local angle = MapConfig.SectorCenterAngle(i)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local right = Vector3.new(-outward.Z, 0, outward.X)
		local hub = MapConfig.HubCenter(i)

		-- Territory road: hub -> bridge, with a gentle bend
		local bridgeOuter = MapConfig.PointOnRing(angle, MapConfig.River.BankOuter + 6)
		local territoryRoad = {
			hub,
			jitter(MapConfig.PointOnRing(angle, 840), right, 35),
			jitter(MapConfig.PointOnRing(angle, 700), right, 45),
			jitter(MapConfig.PointOnRing(angle, 610), right, 15),
			bridgeOuter,
		}
		addRoad(territoryRoad, w, M.Ground)

		-- Neutral road: bridge -> crater gate -> warzone centre-ish
		local bridgeInner = MapConfig.PointOnRing(angle, MapConfig.River.BankInner - 6)
		local neutralRoad = {
			bridgeInner,
			jitter(MapConfig.PointOnRing(angle, 440), right, 20),
			MapConfig.PointOnRing(angle, MapConfig.Neutral.Inner + 10),
			MapConfig.PointOnRing(angle, 200),
			MapConfig.PointOnRing(angle, 90),
		}
		addRoad(neutralRoad, w, M.Ground)
		Lib.terrainRoad({ neutralRoad[3], neutralRoad[4], neutralRoad[5] }, w + 6, M.Slate)
	end

	-- Ring road through the neutral grounds
	local ring = {}
	local segs = 48
	for k = 0, segs do
		local a = k / segs * 2 * math.pi
		table.insert(ring, MapConfig.PointOnRing(a, MapConfig.Neutral.RingRoad + (if k == segs then 0 else Lib.rand(-8, 8))))
	end
	ring[#ring] = ring[1]
	addRoad(ring, 14, M.Ground)
end

-------------------------------------------------------------------------------
-- Scatter helper (used by territories too)
-------------------------------------------------------------------------------

export type Avoid = { pos: Vector3, r: number }

-- Random flat points inside an annulus of a sector, away from roads, water and avoid-zones.
function World.scatter(index: number, count: number, rMin: number, rMax: number, avoid: { Avoid }, roadClearance: number, fn: (Vector3) -> ())
	local centerAngle = MapConfig.SectorCenterAngle(index)
	local placed, tries = 0, 0
	while placed < count and tries < count * 12 do
		tries += 1
		local d = math.sqrt(Lib.rand(rMin * rMin, rMax * rMax))
		local margin = math.atan(70 / d)
		local a = centerAngle + Lib.rand(-(MapConfig.SectorAngle / 2 - margin), MapConfig.SectorAngle / 2 - margin)
		local p = MapConfig.PointOnRing(a, d)
		local ok = true
		if d > MapConfig.River.BankInner - 12 and d < MapConfig.River.BankOuter + 12 then
			ok = false
		end
		if ok and World.distanceToRoad(p.X, p.Z) < roadClearance then
			ok = false
		end
		if ok then
			for _, av in avoid do
				if (Vector2.new(p.X, p.Z) - Vector2.new(av.pos.X, av.pos.Z)).Magnitude < av.r then
					ok = false
					break
				end
			end
		end
		if ok then
			placed += 1
			fn(Lib.onGround(p.X, p.Z))
		end
	end
end

-- Random points in a disc, avoiding roads/avoid zones.
function World.scatterDisc(center: Vector3, radius: number, count: number, avoid: { Avoid }, roadClearance: number, fn: (Vector3) -> ())
	local placed, tries = 0, 0
	while placed < count and tries < count * 12 do
		tries += 1
		local a = Lib.rand(0, 2 * math.pi)
		local d = math.sqrt(Lib.rand(0, radius * radius))
		local p = center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local ok = World.distanceToRoad(p.X, p.Z) >= roadClearance
		if ok then
			for _, av in avoid do
				if (Vector2.new(p.X, p.Z) - Vector2.new(av.pos.X, av.pos.Z)).Magnitude < av.r then
					ok = false
					break
				end
			end
		end
		if ok then
			placed += 1
			fn(Lib.onGround(p.X, p.Z))
		end
	end
end

-------------------------------------------------------------------------------
-- Neutral Grounds
-------------------------------------------------------------------------------

function World.neutral(parent: Folder)
	local f = Lib.folder(parent, "NeutralGrounds")
	local avoid: { Avoid } = {}

	-- Bridges over the river on every race road
	for i = 1, #RaceConfig.Races do
		local angle = MapConfig.SectorCenterAngle(i)
		local a = MapConfig.PointOnRing(angle, MapConfig.River.BankInner - 6)
		local b = MapConfig.PointOnRing(angle, MapConfig.River.BankOuter + 6)
		Props.bridge(f, a, b, 16, Color3.fromRGB(130, 125, 115), M.Cobblestone)
	end

	-- Caravan camps where the ring road passes between territories
	for i = 1, #RaceConfig.Races do
		local a = MapConfig.SectorCenterAngle(i) + MapConfig.SectorAngle / 2
		local c = MapConfig.PointOnRing(a, MapConfig.Neutral.RingRoad + 26)
		local outward = Vector3.new(math.cos(a), 0, math.sin(a))
		local right = Vector3.new(-outward.Z, 0, outward.X)
		table.insert(avoid, { pos = c, r = 45 })
		Lib.fillCylinder(c - Vector3.new(0, 2, 0), 4, 26, M.Ground)
		Props.campfire(f, c)
		Props.tent(f, c + right * 12 + outward * 6, -a + math.pi, Color3.fromRGB(150, 120, 80))
		Props.tent(f, c - right * 12 + outward * 4, -a + math.pi + 0.5, Color3.fromRGB(120, 90, 70))
		Props.tent(f, c + outward * 16, -a + math.pi / 2, Color3.fromRGB(100, 80, 60), 1.2)
		Props.cart(f, c - outward * 12 + right * 8, -a + 0.4)
		Props.marketStall(f, CFrame.lookAt(c - outward * 14 - right * 8, c - outward * 30 - right * 8), Color3.fromRGB(150, 60, 50), Color3.fromRGB(200, 120, 60))
		Props.marketStall(f, CFrame.lookAt(c - outward * 18 + right * 2, c - outward * 34 + right * 2), Color3.fromRGB(60, 80, 140), Color3.fromRGB(120, 160, 200))
		for _ = 1, 4 do
			Props.barrel(f, c + Vector3.new(Lib.rand(-10, 10), 0, Lib.rand(-10, 10)))
		end
		Props.lanternPost(f, c - outward * 24 + right * 10)
		Props.lanternPost(f, c - outward * 24 - right * 14)
		Lib.signpost(f, c - outward * 22, "Caravan Rest\nAll welcome. No blades drawn.", -outward)
	end

	-- Crossroads signposts where race roads meet the ring road
	for i, race in RaceConfig.Races do
		local angle = MapConfig.SectorCenterAngle(i)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local right = Vector3.new(-outward.Z, 0, outward.X)
		local p = MapConfig.PointOnRing(angle, MapConfig.Neutral.RingRoad) + right * 14
		Lib.signpost(f, p, race.StartZone .. "  ^\n v  The Warzone", right)
		table.insert(avoid, { pos = p, r = 10 })
	end

	-- Ruins of the old kingdom
	for _ = 1, 7 do
		local a = Lib.rand(0, 2 * math.pi)
		local d = Lib.rand(330, 480)
		local c = MapConfig.PointOnRing(a, d)
		if World.distanceToRoad(c.X, c.Z) > 30 then
			table.insert(avoid, { pos = c, r = 30 })
			local n = Lib.rng:NextInteger(3, 6)
			for k = 1, n do
				local ca = k / n * 2 * math.pi
				local base = c + Vector3.new(math.cos(ca) * 10, 0, math.sin(ca) * 10)
				local h = Lib.rand(4, 16)
				local col = Lib.column(f, "RuinColumn", Lib.onGround(base.X, base.Z, -0.5), 1.4, h, Color3.fromRGB(165, 160, 150), M.Marble)
				col.Orientation = col.Orientation + Vector3.new(0, 0, Lib.rand(-5, 5))
				if Lib.chance(0.4) then
					Lib.part(f, {
						Name = "FallenColumn",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(Lib.rand(6, 10), 2.6, 2.6),
						CFrame = CFrame.new(Lib.onGround(base.X + 4, base.Z + 3, 1.2)) * CFrame.Angles(0, Lib.rand(0, math.pi), 0),
						Color = Color3.fromRGB(160, 155, 145),
						Material = M.Marble,
					})
				end
			end
			Lib.disc(f, "RuinFloor", Lib.onGround(c.X, c.Z, 0.3), 13, 0.6, Color3.fromRGB(150, 145, 135), M.Cobblestone)
			if Lib.chance(0.5) then
				Props.statue(f, Lib.onGround(c.X, c.Z), Lib.rand(0, math.pi), Color3.fromRGB(170, 165, 158), 9)
			end
		end
	end

	-- Trees, bushes and boulders across the plains (sparse: it's open country)
	for i = 1, #RaceConfig.Races do
		World.scatter(i, 22, MapConfig.Neutral.Inner + 25, MapConfig.Neutral.Outer - 30, avoid, 16, function(p)
			if Lib.chance(0.6) then
				Props.tree(f, p, Lib.rand(14, 22), Color3.fromRGB(90, 130, 60), Lib.rand(12, 17))
			elseif Lib.chance(0.5) then
				Props.bush(f, p, Color3.fromRGB(80, 115, 55), Lib.rand(3, 5))
			else
				Lib.fillBall(p + Vector3.new(0, -1, 0), Lib.rand(3, 6), M.Rock)
			end
		end)
	end
end

-------------------------------------------------------------------------------
-- Warzone
-------------------------------------------------------------------------------

function World.warzone(parent: Folder)
	local f = Lib.folder(parent, "Warzone")
	local R = MapConfig.Warzone.Radius
	local avoid: { Avoid } = { { pos = Vector3.zero, r = 60 } }
	for _, c in World.CraterPositions do
		table.insert(avoid, c)
	end

	local BASALT = Color3.fromRGB(42, 38, 40)
	local ASHSTONE = Color3.fromRGB(70, 64, 66)

	-- Eclipse Altar: tiered dais, obsidian monoliths, the eclipsed sun
	Lib.disc(f, "AltarTier", Vector3.new(0, 2, 0), 40, 2, BASALT, M.Basalt)
	Lib.disc(f, "AltarTier", Vector3.new(0, 4, 0), 30, 2, ASHSTONE, M.Slate)
	Lib.disc(f, "AltarTier", Vector3.new(0, 6, 0), 20, 2, BASALT, M.Basalt)
	Lib.disc(f, "AltarTop", Vector3.new(0, 7, 0), 10, 1, Color3.fromRGB(90, 40, 30), M.Marble)
	for k = 1, 8 do
		local a = k / 8 * 2 * math.pi
		local base = MapConfig.PointOnRing(a, 32, 4)
		local h = Lib.rand(18, 30)
		local mono = Lib.box(f, "Monolith", base, Vector3.new(4, h, 2.5), Color3.fromRGB(20, 18, 22), M.Glass, -a)
		mono.Reflectance = 0.15
		mono.Orientation = mono.Orientation + Vector3.new(Lib.rand(-4, 4), 0, Lib.rand(-4, 4))
		local rune = Lib.part(f, { Name = "Rune", Size = Vector3.new(0.8, 3, 0.2), CFrame = mono.CFrame * CFrame.new(0, h * 0.2, -1.4), Color = Color3.fromRGB(255, 120, 50), Material = M.Neon, CanCollide = false })
		Lib.glow(rune, Color3.fromRGB(255, 120, 50), 1, 14)
		Props.brazier(f, MapConfig.PointOnRing(a + math.pi / 8, 44, 2), Color3.fromRGB(255, 110, 40))
	end
	local obelisk = Lib.box(f, "Obelisk", Vector3.new(0, 7, 0), Vector3.new(5, 34, 5), Color3.fromRGB(18, 16, 20), M.Basalt)
	obelisk.Name = "Obelisk"
	local halo = Lib.ball(f, "EclipseHalo", Vector3.new(0, 50, 0), 7.4, Color3.fromRGB(255, 140, 50), M.Neon, false)
	halo.Transparency = 0.55
	local core = Lib.ball(f, "EclipseCore", Vector3.new(0, 50, 0), 6.4, Color3.fromRGB(5, 3, 6), M.SmoothPlastic, false)
	core.Name = "EclipseCore"
	Lib.glow(halo, Color3.fromRGB(255, 130, 50), 5, 140)
	Lib.particles(halo, Color3.fromRGB(255, 150, 60), 25, 0.6, 6, 4, 180)

	-- Ash falling over the whole crater
	local ashField = Lib.part(f, { Name = "AshField", Size = Vector3.new(R * 2, 2, R * 2), Position = Vector3.new(0, 90, 0), Transparency = 1, CanCollide = false })
	local ash = Lib.particles(ashField, Color3.fromRGB(150, 140, 140), 120, 0.5, 2, 14, 30)
	ash.Acceleration = Vector3.new(1.5, -3, 0.5)
	ash.LightEmission = 0
	local embers = Lib.particles(ashField, Color3.fromRGB(255, 120, 40), 25, 0.35, 3, 10, 60)
	embers.Acceleration = Vector3.new(2, -1.5, 1)

	-- Shattered city: ruined building shells
	for _ = 1, 16 do
		local a = Lib.rand(0, 2 * math.pi)
		local d = Lib.rand(85, R - 25)
		local c = MapConfig.PointOnRing(a, d)
		if World.distanceToRoad(c.X, c.Z) > 22 then
			local okCrater = true
			for _, cr in World.CraterPositions do
				if (cr.pos - c).Magnitude < cr.r + 14 then
					okCrater = false
				end
			end
			if okCrater then
				table.insert(avoid, { pos = c, r = 24 })
				local yaw = Lib.rand(0, math.pi)
				local w, dpt = Lib.rand(14, 24), Lib.rand(12, 20)
				local cf = CFrame.new(Lib.onGround(c.X, c.Z)) * CFrame.Angles(0, yaw, 0)
				local color = Lib.pick({ ASHSTONE, Color3.fromRGB(85, 78, 78), Color3.fromRGB(60, 56, 58) })
				-- three walls of uneven height, one collapsed
				local walls = {
					{ cf * CFrame.new(0, 0, dpt / 2), Vector3.new(w, Lib.rand(6, 16), 1.2) },
					{ cf * CFrame.new(-w / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(dpt, Lib.rand(5, 14), 1.2) },
					{ cf * CFrame.new(w / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(dpt, Lib.rand(3, 9), 1.2) },
				}
				for _, wd in walls do
					local p = Lib.boxAt(f, "RuinWall", wd[1], wd[2], color, M.Slate)
					p.Orientation = p.Orientation + Vector3.new(0, 0, Lib.rand(-3, 3))
				end
				for _ = 1, Lib.rng:NextInteger(3, 7) do
					local rp = cf * CFrame.new(Lib.rand(-w / 2, w / 2), 0, Lib.rand(-dpt / 2, dpt / 2))
					local s = Vector3.new(Lib.rand(1.5, 5), Lib.rand(1, 3.5), Lib.rand(1.5, 5))
					local rb = Lib.boxAt(f, "Rubble", rp, s, color, M.Slate)
					rb.Orientation = Vector3.new(Lib.rand(-20, 20), Lib.rand(0, 180), Lib.rand(-20, 20))
				end
				if Lib.chance(0.35) then
					local wreck = Lib.boxAt(f, "BurningBeam", cf * CFrame.new(Lib.rand(-4, 4), 0.5, Lib.rand(-4, 4)) * CFrame.Angles(0, Lib.rand(0, math.pi), math.rad(12)), Vector3.new(6, 1, 1), Color3.fromRGB(30, 25, 25), M.Wood)
					Lib.fire(wreck, 4)
					Lib.smoke(wreck, 3, Color3.fromRGB(60, 60, 60))
				end
			end
		end
	end

	-- Fallen and leaning columns, scorched trees, rubble piles
	for i = 1, #RaceConfig.Races do
		World.scatter(i, 18, 70, R - 15, avoid, 14, function(p)
			local roll = Lib.rng:NextNumber()
			if roll < 0.3 then
				Lib.part(f, {
					Name = "FallenColumn",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(Lib.rand(8, 14), 2.8, 2.8),
					CFrame = CFrame.new(p + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, Lib.rand(0, math.pi), math.rad(Lib.rand(-6, 6))),
					Color = ASHSTONE,
					Material = M.Slate,
				})
			elseif roll < 0.5 then
				local col = Lib.column(f, "LeaningColumn", p, 1.6, Lib.rand(8, 18), ASHSTONE, M.Slate)
				col.Orientation = col.Orientation + Vector3.new(Lib.rand(-10, 10), 0, Lib.rand(-10, 10))
			elseif roll < 0.75 then
				Props.deadTree(f, p, Lib.rand(10, 16))
			else
				for _ = 1, 4 do
					local rb = Lib.box(f, "Rubble", p + Vector3.new(Lib.rand(-3, 3), 0, Lib.rand(-3, 3)), Vector3.new(Lib.rand(1.5, 4), Lib.rand(1, 3), Lib.rand(1.5, 4)), BASALT, M.Basalt, Lib.rand(0, math.pi))
					rb.Orientation = rb.Orientation + Vector3.new(Lib.rand(-15, 15), 0, Lib.rand(-15, 15))
				end
			end
		end)
	end

	-- Broken gate arches where each road enters the crater
	for i = 1, #RaceConfig.Races do
		local angle = MapConfig.SectorCenterAngle(i)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local right = Vector3.new(-outward.Z, 0, outward.X)
		local g = MapConfig.PointOnRing(angle, MapConfig.Warzone.RimOuter - 10)
		for _, s in { -1, 1 } do
			local base = g + right * s * (MapConfig.RoadWidth / 2 + 6)
			local h = if s == -1 then 26 else Lib.rand(12, 20)
			local pillar = Lib.box(f, "GatePillar", Lib.onGround(base.X, base.Z, -1), Vector3.new(5, h, 5), BASALT, M.Basalt, -angle)
			pillar.Orientation = pillar.Orientation + Vector3.new(0, 0, Lib.rand(-2, 2))
			Props.brazier(f, base - outward * 6, Color3.fromRGB(255, 90, 40))
		end
		Lib.signpost(f, g - outward * 16 + right * (MapConfig.RoadWidth / 2 + 3), "THE WARZONE\nNo law beyond this point.", -outward, Color3.fromRGB(120, 20, 20))
	end
end

return World
