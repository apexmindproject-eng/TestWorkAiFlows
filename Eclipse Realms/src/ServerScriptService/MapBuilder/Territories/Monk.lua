--!strict
-- Jade Monastery: temples on a mountain plateau above bamboo slopes, waterfalls and shrines.

local MapBuilder = script.Parent.Parent
local Lib = require(MapBuilder.Lib)
local Props = require(MapBuilder.Props)
local World = require(MapBuilder.World)
local Types = require(MapBuilder.Types)

local M = Enum.Material
local Monk = {}

local PLASTER = Color3.fromRGB(236, 230, 215)
local JADE = Color3.fromRGB(40, 125, 95)
local REDWOOD = Color3.fromRGB(140, 45, 40)
local GOLD = Color3.fromRGB(230, 190, 90)
local PLATEAU_H = 36
local PLATEAU_R = 165

local TEMPLE: Props.HouseStyle = { Wall = PLASTER, WallMaterial = M.Plaster, Roof = JADE, RoofMaterial = M.ClayRoofTiles, Trim = REDWOOD, WindowGlow = Color3.fromRGB(255, 215, 150), Pyramid = true, RoofPitch = 0.35 }
local QUARTERS: Props.HouseStyle = { Wall = PLASTER, WallMaterial = M.Plaster, Roof = JADE, RoofMaterial = M.ClayRoofTiles, Trim = REDWOOD, WindowGlow = Color3.fromRGB(255, 215, 150), RoofPitch = 0.4 }

local function stoneLantern(f: Folder, base: Vector3)
	Lib.boxAt(f, "LanternBase", CFrame.new(base), Vector3.new(1.6, 0.6, 1.6), Color3.fromRGB(170, 168, 160), M.Granite)
	Lib.boxAt(f, "LanternPost", CFrame.new(base + Vector3.new(0, 0.6, 0)), Vector3.new(0.7, 2.4, 0.7), Color3.fromRGB(170, 168, 160), M.Granite)
	local light = Lib.boxAt(f, "LanternLight", CFrame.new(base + Vector3.new(0, 3, 0)), Vector3.new(1.4, 1.2, 1.4), Color3.fromRGB(255, 220, 160), M.Neon)
	Lib.glow(light, Color3.fromRGB(255, 210, 140), 0.9, 16)
	Lib.pyramidRoof(f, CFrame.new(base + Vector3.new(0, 4.2, 0)), 2.6, 1, Color3.fromRGB(150, 148, 140), M.Granite)
end

local function torii(f: Folder, cf: CFrame, width: number, height: number)
	for _, s in { -1, 1 } do
		Lib.boxAt(f, "ToriiPost", cf * CFrame.new(s * width / 2, 0, 0), Vector3.new(1.6, height, 1.6), REDWOOD, M.Wood)
	end
	Lib.boxAt(f, "ToriiBeam", cf * CFrame.new(0, height - 1.2, 0), Vector3.new(width + 1.5, 1, 1.6), REDWOOD, M.Wood)
	Lib.boxAt(f, "ToriiTop", cf * CFrame.new(0, height + 0.6, 0), Vector3.new(width + 5, 1.4, 2.2), Color3.fromRGB(45, 40, 42), M.Wood)
end

local function pagodaTier(f: Folder, cf: CFrame, w: number, h: number, withDoor: boolean)
	Props.house(f, cf, w, w, h, TEMPLE, { Door = withDoor, Floor = withDoor })
end

local function trainingDummy(f: Folder, base: Vector3, yaw: number)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	Lib.boxAt(f, "DummyPost", cf, Vector3.new(1, 6, 1), Color3.fromRGB(150, 115, 75), M.Wood)
	Lib.boxAt(f, "DummyArm", cf * CFrame.new(0, 4, 0), Vector3.new(4, 0.5, 0.5), Color3.fromRGB(150, 115, 75), M.Wood)
	Lib.boxAt(f, "DummyArm", cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(3, 0.5, 0.5), Color3.fromRGB(150, 115, 75), M.Wood)
	Lib.boxAt(f, "DummyWrap", cf * CFrame.new(0, 2, 0), Vector3.new(1.3, 1.5, 1.3), Color3.fromRGB(190, 170, 130), M.Fabric)
end

function Monk.terrain(ctx: Types.Ctx)
	local hub = ctx.hub
	-- Mountain plateau
	Lib.fillCylinder(hub + Vector3.new(0, PLATEAU_H / 2 - 4, 0), PLATEAU_H + 8, PLATEAU_R + 24, M.Rock)
	Lib.fillCylinder(hub + Vector3.new(0, PLATEAU_H - 1.5, 0), 3, PLATEAU_R, M.Grass)
	Lib.registerPlateau(hub.X, hub.Z, PLATEAU_R + 8, PLATEAU_H)
	-- Long stair-like ramp down toward the road
	local edge = hub + ctx.toward * (PLATEAU_R + 10)
	local mid = edge + ctx.toward * 70 + Vector3.new(0, PLATEAU_H / 2, 0)
	Lib.fillWedge(CFrame.lookAt(mid, mid + ctx.toward), Vector3.new(36, PLATEAU_H, 140), M.Rock)
	Lib.fillWedge(CFrame.lookAt(mid + Vector3.new(0, 0.5, 0), mid + ctx.toward), Vector3.new(28, PLATEAU_H, 140), M.Cobblestone)
	-- Snowy peaks behind the monastery and rocky slopes everywhere
	for _ = 1, 14 do
		local p = ctx.ringPoint(Lib.rand(1080, 1200), Lib.rand(-0.3, 0.3))
		local r = Lib.rand(50, 90)
		Lib.hill(p.X, p.Z, r, r * 0.25, M.Rock, M.Snow)
	end
	for _ = 1, 14 do
		local p = ctx.ringPoint(Lib.rand(590, 860), Lib.rand(-0.3, 0.3))
		if World.distanceToRoad(p.X, p.Z) > 55 then
			Lib.hill(p.X, p.Z, Lib.rand(28, 55), Lib.rand(18, 36), M.Rock, M.Grass)
		end
	end
	for _ = 1, 20 do
		local p = ctx.ringPoint(Lib.rand(580, 1000), Lib.rand(-0.3, 0.3))
		Lib.fillCylinder(p - Vector3.new(0, 2, 0), 4, Lib.rand(20, 50), Lib.pick({ M.LeafyGrass, M.Grass, M.Rock, M.Ground }))
	end
	-- Koi pond on the plateau
	local pond = hub - ctx.right * 70
	Lib.fillCylinder(pond + Vector3.new(0, PLATEAU_H - 2.5, 0), 5, 24, M.Air)
	Lib.fillCylinder(pond + Vector3.new(0, PLATEAU_H - 3.2, 0), 3.6, 24, M.Water)
	Lib.fillCylinder(pond + Vector3.new(0, PLATEAU_H - 1, 0), 2, 28, M.Sand)
	Lib.fillCylinder(pond + Vector3.new(0, PLATEAU_H - 2.5, 0), 5, 24, M.Air)
	Lib.fillCylinder(pond + Vector3.new(0, PLATEAU_H - 3.2, 0), 3.6, 24, M.Water)
	-- Zen garden sand
	Lib.fillCylinder(hub + ctx.right * 70 + Vector3.new(0, PLATEAU_H - 1, 0), 2, 26, M.Sand)
	-- Waterfall hill and plunge pool beside the road
	local wf = ctx.ringPoint(700, 0.13)
	Lib.hill(wf.X, wf.Z, 44, 10, M.Rock, M.Grass)
	local poolC = wf + (hub - wf).Unit * -52
	Lib.fillCylinder(poolC - Vector3.new(0, 3, 0), 6, 22, M.Air)
	Lib.fillCylinder(poolC - Vector3.new(0, 3.75, 0), 4.5, 22, M.Water)
	Lib.fillBlock(CFrame.lookAt(wf + Vector3.new(0, 20, 0), poolC + Vector3.new(0, 20, 0)) * CFrame.new(0, 0, -40), Vector3.new(10, 36, 6), M.Water)
	table.insert(ctx.avoid, { pos = wf, r = 60 })
	table.insert(ctx.avoid, { pos = poolC, r = 30 })
	-- Hot spring
	local hs = ctx.ringPoint(1060, -0.2)
	Lib.fillCylinder(hs + Vector3.new(0, Lib.ground(hs.X, hs.Z) - 2.5, 0), 5, 12, M.Air)
	Lib.fillCylinder(hs + Vector3.new(0, Lib.ground(hs.X, hs.Z) - 3.2, 0), 3.6, 12, M.Water)
	Lib.fillCylinder(hs + Vector3.new(0, Lib.ground(hs.X, hs.Z) - 1, 0), 2, 16, M.Rock)
	Lib.fillCylinder(hs + Vector3.new(0, Lib.ground(hs.X, hs.Z) - 2.5, 0), 5, 12, M.Air)
	Lib.fillCylinder(hs + Vector3.new(0, Lib.ground(hs.X, hs.Z) - 3.2, 0), 3.6, 12, M.Water)
	table.insert(ctx.avoid, { pos = hs, r = 22 })
end

function Monk.build(ctx: Types.Ctx)
	local f = ctx.folder
	local hub = ctx.hub
	local toward, right = ctx.toward, ctx.right
	local avoid = ctx.avoid
	table.insert(avoid, { pos = hub, r = PLATEAU_R + 30 })
	local top = Vector3.new(hub.X, PLATEAU_H, hub.Z)
	local gateAngle = math.atan2(toward.Z, toward.X)

	-- Low monastery wall with a gate
	local R = 128
	local verts = {}
	for k = 0, 7 do
		local a = gateAngle + math.rad(22.5) + k * math.rad(45)
		table.insert(verts, top + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R))
	end
	for k = 1, 8 do
		local a, b = verts[k], verts[k % 8 + 1]
		if k == 8 then
			local mid = (a + b) / 2
			local dir = (b - a).Unit
			Lib.wall(f, "MonasteryWall", a, mid - dir * 9, 6, 2, PLASTER, M.Plaster)
			Lib.wall(f, "MonasteryWall", mid + dir * 9, b, 6, 2, PLASTER, M.Plaster)
			torii(f, CFrame.lookAt(mid, mid + toward), 16, 14)
			stoneLantern(f, mid - dir * 11 - toward * 4)
			stoneLantern(f, mid + dir * 11 - toward * 4)
		else
			Lib.wall(f, "MonasteryWall", a, b, 6, 2, PLASTER, M.Plaster)
		end
		-- Jade tile cap
		Lib.part(f, { Name = "WallCap", Size = Vector3.new(3, 0.8, (b - a).Magnitude + 3), CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, 6.4, 0), Color = JADE, Material = M.ClayRoofTiles })
	end

	-- Courtyard paving, spawn, lanterns
	Lib.disc(f, "Courtyard", top + Vector3.new(0, 0.3, 0), 44, 0.6, Color3.fromRGB(200, 196, 185), M.Cobblestone)
	Lib.spawnLocation(f, ctx.race.Name .. "Spawn", top + toward * 20, BrickColor.new(ctx.race.TeamColor))
	for k = 1, 8 do
		local a = k / 8 * 2 * math.pi + math.pi / 8
		stoneLantern(f, top + Vector3.new(math.cos(a) * 40, 0.3, math.sin(a) * 40))
	end
	-- Incense burner in the centre
	local burner = Lib.column(f, "IncenseBurner", top + Vector3.new(0, 0.3, 0), 2.2, 3, Color3.fromRGB(60, 55, 50), M.Metal)
	local incense = Lib.part(f, { Name = "IncenseTop", Size = Vector3.new(1, 0.2, 1), Position = top + Vector3.new(0, 3.4, 0), Transparency = 1, CanCollide = false })
	Lib.smoke(incense, 0.8, Color3.fromRGB(200, 200, 210))
	burner.Name = "IncenseBurner"

	-- Great pagoda (three tiers)
	do
		local pos = top - toward * 56
		local cf = CFrame.lookAt(pos, top)
		pagodaTier(f, cf, 30, 12, true)
		pagodaTier(f, cf * CFrame.new(0, 12 + 0.35 * 33 * 0.4, 0), 22, 9, false)
		pagodaTier(f, cf * CFrame.new(0, 12 + 0.35 * 33 * 0.4 + 9 + 0.35 * 25 * 0.4, 0), 14, 8, false)
		local spireBase = cf * CFrame.new(0, 12 + 0.35 * 33 * 0.4 + 9 + 0.35 * 25 * 0.4 + 8 + 0.35 * 17, 0)
		Lib.boxAt(f, "Spire", spireBase, Vector3.new(0.8, 7, 0.8), GOLD, M.Metal)
		local orb = Lib.ball(f, "SpireOrb", spireBase.Position + Vector3.new(0, 7.5, 0), 1.3, GOLD, M.Neon, false)
		Lib.glow(orb, GOLD, 2, 50)
		-- Interior: golden statue, offerings, cushions
		Props.statue(f, (cf * CFrame.new(0, 0, 10)).Position, gateAngle, GOLD, 9)
		for k = -2, 2 do
			Lib.boxAt(f, "Cushion", cf * CFrame.new(k * 4, 0, -4), Vector3.new(2.4, 0.5, 2.4), REDWOOD, M.Fabric)
			Lib.boxAt(f, "Cushion", cf * CFrame.new(k * 4, 0, 0), Vector3.new(2.4, 0.5, 2.4), REDWOOD, M.Fabric)
		end
		for _, x in { -3, 3 } do
			local fl = Lib.part(f, { Name = "CandleFlame", Size = Vector3.new(0.3, 0.5, 0.3), CFrame = cf * CFrame.new(x, 3.2, 7), Color = Color3.fromRGB(255, 210, 130), Material = M.Neon, CanCollide = false })
			Lib.glow(fl, Color3.fromRGB(255, 200, 120), 0.8, 12)
			Lib.column(f, "Candle", (cf * CFrame.new(x, 2.5, 7)).Position, 0.2, 0.7, Color3.fromRGB(240, 230, 210), M.SmoothPlastic)
			Lib.boxAt(f, "OfferingTable", cf * CFrame.new(x, 0, 7), Vector3.new(2, 2.5, 1.2), REDWOOD, M.Wood)
		end
	end

	-- Hall of Scrolls (mission hub)
	do
		local pos = top + right * 62
		local cf = CFrame.lookAt(pos, top)
		local w, d, h = 20, 28, 10
		Props.house(f, cf, w, d, h, QUARTERS)
		local sign = Lib.part(f, { Name = "HallSign", Size = Vector3.new(6, 1.8, 0.3), CFrame = cf * CFrame.new(0, h - 1.2, -d / 2 - 0.3), Color = REDWOOD, Material = M.Wood })
		Lib.surfaceText(sign, "Hall of Scrolls", GOLD)
		-- Scroll racks along both long walls
		for _, s in { -1, 1 } do
			local rack = cf * CFrame.new(s * (w / 2 - 1.2), 0, 2) * CFrame.Angles(0, math.rad(90), 0)
			Lib.boxAt(f, "ScrollRack", rack, Vector3.new(18, 7, 1.2), Color3.fromRGB(120, 85, 55), M.WoodPlanks)
			for row = 1, 4 do
				for col = -7, 7 do
					Lib.part(f, {
						Name = "Scroll",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(1, 0.5, 0.5),
						CFrame = rack * CFrame.new(col * 1.15, row * 1.6 - 0.4, -0.5) * CFrame.Angles(0, math.rad(90), 0),
						Color = Lib.pick({ Color3.fromRGB(235, 225, 200), Color3.fromRGB(220, 200, 160), Color3.fromRGB(200, 170, 130) }),
						Material = M.SmoothPlastic,
						CanCollide = false,
					})
				end
			end
		end
		for k = -1, 1 do
			Lib.boxAt(f, "LowTable", cf * CFrame.new(0, 0, k * 7), Vector3.new(6, 1.2, 3), Color3.fromRGB(120, 85, 55), M.Wood)
			for _, s in { -1, 1 } do
				Lib.boxAt(f, "Cushion", cf * CFrame.new(0, 0, k * 7 + s * 2.6), Vector3.new(2, 0.4, 1.6), REDWOOD, M.Fabric)
			end
			Lib.column(f, "Candle", (cf * CFrame.new(1.5, 1.2, k * 7)).Position, 0.15, 0.6, Color3.fromRGB(240, 230, 210), M.SmoothPlastic)
			local fl = Lib.part(f, { Name = "CandleFlame", Size = Vector3.new(0.25, 0.4, 0.25), CFrame = cf * CFrame.new(1.5, 2, k * 7), Color = Color3.fromRGB(255, 210, 130), Material = M.Neon, CanCollide = false })
			Lib.glow(fl, Color3.fromRGB(255, 200, 120), 0.7, 10)
		end
		Props.noticeBoard(f, cf * CFrame.new(0, 0.5, d / 2 - 1.3), {
			{ "FIRST TRIAL", "Carry water from the plunge pool to the summit shrine without spilling. Then do it at a run." },
			{ "THE LOST NOVICE", "Brother Tam went to the hot spring three days ago. Find him. Bring him back." },
			{ "STILL WATER", "A wolf pack has been drinking at our pool. Discourage them. Harm none that yield." },
			{ "PILGRIMAGE", "Walk to the Neutral Grounds and return. Carry nothing. Fear nothing." },
		}, JADE)
	end

	-- Bell tower, quarters, training yard
	do
		local bp = top - right * 30 - toward * 20
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Lib.boxAt(f, "BellPost", CFrame.new(bp + Vector3.new(sx * 3, 0, sz * 3)), Vector3.new(1, 12, 1), REDWOOD, M.Wood)
			end
		end
		Lib.pyramidRoof(f, CFrame.new(bp + Vector3.new(0, 12, 0)), 10, 4, JADE, M.ClayRoofTiles)
		Lib.boxAt(f, "BellBeam", CFrame.new(bp + Vector3.new(0, 11, 0)), Vector3.new(7, 0.6, 0.6), REDWOOD, M.Wood)
		local bell = Lib.part(f, { Name = "Bell", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 3.2, 3.2), CFrame = CFrame.new(bp + Vector3.new(0, 8.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(190, 150, 60), Material = M.Metal })
		bell.Name = "Bell"
		Lib.column(f, "BellStriker", bp + Vector3.new(0, 1, 5), 0.4, 6, Color3.fromRGB(120, 85, 55), M.Wood).Orientation = Vector3.new(0, 0, 0)
	end
	for _, deg in { 120, 150, -120, -150 } do
		local a = gateAngle + math.rad(deg + 180)
		local pos = top + Vector3.new(math.cos(a) * 96, 0, math.sin(a) * 96)
		Props.house(f, CFrame.lookAt(pos, top), 12, 14, 7, QUARTERS)
	end
	do
		local yard = top - right * 40 + toward * 60
		Lib.disc(f, "YardFloor", yard + Vector3.new(0, 0.2, 0), 20, 0.4, Color3.fromRGB(190, 170, 130), M.Ground)
		for k = 1, 5 do
			local a = k / 5 * 2 * math.pi
			trainingDummy(f, yard + Vector3.new(math.cos(a) * 12, 0.2, math.sin(a) * 12), -a)
		end
		-- Weapon rack with staves
		Lib.boxAt(f, "StaffRack", CFrame.new(yard + toward * 18) * CFrame.Angles(0, gateAngle, 0), Vector3.new(6, 1, 1), Color3.fromRGB(120, 85, 55), M.Wood)
		for k = -2, 2 do
			Lib.boxAt(f, "Staff", CFrame.new(yard + toward * 18 + right * k * 1.1) * CFrame.Angles(math.rad(10), 0, 0), Vector3.new(0.3, 7, 0.3), Color3.fromRGB(150, 115, 75), M.Wood)
		end
	end

	-- Zen garden and koi pond details
	do
		local zen = top + right * 70
		for k = 1, 3 do
			Lib.disc(f, "RakedRing", zen + Vector3.new(0, 0.15, 0), 6 + k * 5, 0.2, Color3.fromRGB(225, 215, 190), M.Sand).Transparency = 0.2
		end
		for _, off in { Vector3.new(4, 0, -3), Vector3.new(-6, 0, 5), Vector3.new(7, 0, 8) } do
			Lib.fillBall(zen + off + Vector3.new(0, -1, 0), Lib.rand(2.5, 4), M.Rock)
		end
		Props.bench(f, CFrame.lookAt(zen - right * 26, zen))

		local pond = top - right * 70
		Props.bridge(f, pond - toward * 20, pond + toward * 20, 6, Color3.fromRGB(140, 50, 45), M.Wood)
		for k = 1, 5 do
			local a = k / 5 * 2 * math.pi
			stoneLantern(f, pond + Vector3.new(math.cos(a) * 28, 0.1, math.sin(a) * 28))
		end
		for k = 1, 6 do
			local a = k / 6 * 2 * math.pi
			Lib.disc(f, "LilyPad", pond + Vector3.new(math.cos(a) * Lib.rand(6, 18), -0.6, math.sin(a) * Lib.rand(6, 18)), Lib.rand(1, 1.8), 0.1, Color3.fromRGB(70, 130, 70), M.Grass)
		end
	end

	-- Cherry trees and bamboo on the plateau
	for _ = 1, 14 do
		local a = Lib.rand(0, 2 * math.pi)
		local d = Lib.rand(60, R - 12)
		local p = top + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local da = math.abs((a - gateAngle + math.pi) % (2 * math.pi) - math.pi)
		if da > math.rad(14) and (p - (top + right * 62)).Magnitude > 24 and (p - (top - toward * 56)).Magnitude > 32 and (p - (top - right * 70)).Magnitude > 34 and (p - (top + right * 70)).Magnitude > 32 then
			if Lib.chance(0.6) then
				Props.tree(f, p, Lib.rand(10, 15), Lib.pick({ Color3.fromRGB(240, 150, 190), Color3.fromRGB(250, 180, 205), Color3.fromRGB(235, 130, 170) }), Lib.rand(10, 14))
			else
				Props.bamboo(f, p)
			end
		end
	end

	-- Prayer flags across the gate approach
	do
		local a = top + toward * (R + 20) + right * 14
		local b = top + toward * (R + 20) - right * 14
		Lib.column(f, "FlagPole", a, 0.3, 12, REDWOOD, M.Wood)
		Lib.column(f, "FlagPole", b, 0.3, 12, REDWOOD, M.Wood)
		for k = 0, 12 do
			local t = k / 12
			local p = a:Lerp(b, t) + Vector3.new(0, 11 - math.sin(t * math.pi) * 1.5, 0)
			Lib.box(f, "PrayerFlag", p - Vector3.new(0, 1.6, 0), Vector3.new(1.4, 1.6, 0.1), Lib.pick({ Color3.fromRGB(60, 90, 200), Color3.fromRGB(240, 240, 240), Color3.fromRGB(220, 50, 50), Color3.fromRGB(70, 160, 80), Color3.fromRGB(240, 210, 70) }), M.Fabric, gateAngle)
		end
	end

	-- Summit shrine on a hill in the wilds, waterfall mist, hot-spring steam
	do
		local p = ctx.ringPoint(830, -0.14)
		Lib.hill(p.X, p.Z, 36, 18, M.Rock, M.Grass)
		local s = Lib.onGround(p.X, p.Z)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Lib.boxAt(f, "ShrinePost", CFrame.new(s + Vector3.new(sx * 3.5, 0, sz * 3.5)), Vector3.new(1, 8, 1), REDWOOD, M.Wood)
			end
		end
		Lib.pyramidRoof(f, CFrame.new(s + Vector3.new(0, 8, 0)), 12, 4, JADE, M.ClayRoofTiles)
		Props.statue(f, s, ctx.angle + math.pi, Color3.fromRGB(190, 185, 175), 6)
		stoneLantern(f, s + toward * 7 + right * 4)
		stoneLantern(f, s + toward * 7 - right * 4)
		torii(f, CFrame.lookAt(s + toward * 14, s), 8, 8)
		table.insert(avoid, { pos = p, r = 46 })

		local wf = ctx.ringPoint(700, 0.13)
		local poolC = wf + (hub - wf).Unit * -52
		local mistPart = Lib.part(f, { Name = "WaterfallMist", Size = Vector3.new(16, 2, 16), Position = poolC + Vector3.new(0, 1, 0), Transparency = 1, CanCollide = false })
		local mist = Lib.particles(mistPart, Color3.fromRGB(235, 240, 255), 30, 6, 2.5, 3, 40)
		mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
		mist.LightEmission = 0.2
		Props.bench(f, CFrame.lookAt(poolC + right * 28, poolC))
		stoneLantern(f, poolC + right * 26 + toward * 6)

		local hs = ctx.ringPoint(1060, -0.2)
		local steamPart = Lib.part(f, { Name = "Steam", Size = Vector3.new(14, 1, 14), Position = Lib.onGround(hs.X, hs.Z, 0.5), Transparency = 1, CanCollide = false })
		local steam = Lib.particles(steamPart, Color3.fromRGB(240, 240, 245), 14, 5, 1.2, 5, 20)
		steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
		steam.LightEmission = 0.1
		for k = 1, 4 do
			local a = k / 4 * 2 * math.pi
			Lib.fillBall(Lib.onGround(hs.X + math.cos(a) * 14, hs.Z + math.sin(a) * 14, -1), Lib.rand(2.5, 4), M.Rock)
		end
	end

	-- Slopes: bamboo, pines, cherry, boulders
	World.scatter(ctx.index, 240, 575, 1180, avoid, 13, function(p)
		local d = Vector2.new(p.X, p.Z).Magnitude
		local roll = Lib.rng:NextNumber()
		if d > 1040 then
			if roll < 0.7 then
				Props.pine(f, p, Lib.rand(18, 30), Color3.fromRGB(40, 80, 60))
			else
				Lib.fillBall(p + Vector3.new(0, -1.5, 0), Lib.rand(3, 7), M.Rock)
			end
		elseif roll < 0.45 then
			Props.bamboo(f, p)
		elseif roll < 0.7 then
			Props.pine(f, p, Lib.rand(16, 28), Color3.fromRGB(45, 95, 65))
		elseif roll < 0.85 then
			Props.tree(f, p, Lib.rand(10, 15), Color3.fromRGB(240, 150, 190), Lib.rand(9, 13))
		else
			Lib.fillBall(p + Vector3.new(0, -1.5, 0), Lib.rand(3, 7), M.Rock)
		end
	end)
end

return Monk
