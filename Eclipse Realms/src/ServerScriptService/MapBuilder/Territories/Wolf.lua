--!strict
-- Moonfang Forest: a palisaded tribal village deep in old-growth forest, with dens and hunting grounds.

local MapBuilder = script.Parent.Parent
local Lib = require(MapBuilder.Lib)
local Props = require(MapBuilder.Props)
local World = require(MapBuilder.World)
local Types = require(MapBuilder.Types)

local M = Enum.Material
local Wolf = {}

local LOG = Color3.fromRGB(105, 75, 48)
local THATCH = Color3.fromRGB(165, 135, 80)
local LONGHOUSE: Props.HouseStyle = { Wall = LOG, WallMaterial = M.Wood, Roof = THATCH, RoofMaterial = M.Fabric, Trim = Color3.fromRGB(70, 50, 32), WindowGlow = Color3.fromRGB(255, 170, 90), RoofPitch = 0.6 }

local function totem(f: Folder, base: Vector3, yaw: number)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	local colors = { Color3.fromRGB(120, 70, 40), Color3.fromRGB(150, 50, 40), Color3.fromRGB(90, 80, 60) }
	for k = 1, 3 do
		Lib.boxAt(f, "Totem", cf * CFrame.new(0, (k - 1) * 3.2, 0), Vector3.new(2.6, 3.2, 2.6), colors[k], M.Wood)
	end
	Lib.ball(f, "WolfHead", (cf * CFrame.new(0, 10.8, 0)).Position, 1.6, Color3.fromRGB(110, 95, 80), M.Wood)
	Lib.boxAt(f, "Snout", cf * CFrame.new(0, 10.1, -1.6), Vector3.new(1.2, 1, 1.6), Color3.fromRGB(110, 95, 80), M.Wood)
	for _, s in { -1, 1 } do
		local eye = Lib.part(f, { Name = "Eye", Size = Vector3.new(0.4, 0.4, 0.2), CFrame = cf * CFrame.new(s * 0.6, 11.2, -1.5), Color = Color3.fromRGB(255, 220, 80), Material = M.Neon, CanCollide = false })
		Lib.glow(eye, Color3.fromRGB(255, 200, 80), 0.6, 8)
		Lib.boxAt(f, "Ear", cf * CFrame.new(s * 0.9, 12, 0) * CFrame.Angles(0, 0, s * math.rad(-15)), Vector3.new(0.6, 1.2, 0.4), Color3.fromRGB(110, 95, 80), M.Wood)
	end
end

local function dryingRack(f: Folder, cf: CFrame)
	for _, s in { -1, 1 } do
		Lib.boxAt(f, "RackPost", cf * CFrame.new(s * 3, 0, 0), Vector3.new(0.4, 6, 0.4), Color3.fromRGB(90, 68, 45), M.Wood)
	end
	Lib.boxAt(f, "RackBar", cf * CFrame.new(0, 5.6, 0), Vector3.new(6.4, 0.3, 0.3), Color3.fromRGB(90, 68, 45), M.Wood)
	for k = -1, 1 do
		Lib.boxAt(f, "Hide", cf * CFrame.new(k * 1.9, 1.6, 0), Vector3.new(1.5, 4, 0.15), Lib.pick({ Color3.fromRGB(120, 90, 60), Color3.fromRGB(90, 70, 55), Color3.fromRGB(150, 130, 100) }), M.Fabric)
	end
end

function Wolf.terrain(ctx: Types.Ctx)
	local hub = ctx.hub
	Lib.fillCylinder(hub - Vector3.new(0, 2, 0), 4, 90, M.Ground)
	for _ = 1, 30 do
		local p = ctx.ringPoint(Lib.rand(580, 1180), Lib.rand(-0.3, 0.3))
		Lib.fillCylinder(p - Vector3.new(0, 2, 0), 4, Lib.rand(25, 70), Lib.pick({ M.LeafyGrass, M.LeafyGrass, M.Ground, M.Mud }))
	end
	for _ = 1, 14 do
		local p = ctx.ringPoint(Lib.rand(590, 1150), Lib.rand(-0.28, 0.28))
		if World.distanceToRoad(p.X, p.Z) > 60 and (p - hub).Magnitude > 140 then
			Lib.hill(p.X, p.Z, Lib.rand(28, 60), Lib.rand(20, 44), M.Grass, M.LeafyGrass)
		end
	end
	-- Forest ponds
	for _ = 1, 3 do
		local p = ctx.ringPoint(Lib.rand(620, 820), Lib.rand(-0.24, 0.24))
		if World.distanceToRoad(p.X, p.Z) > 50 and Lib.ground(p.X, p.Z) < 1 then
			local r = Lib.rand(14, 24)
			Lib.fillCylinder(p - Vector3.new(0, 3, 0), 6, r + 4, M.Mud)
			Lib.fillCylinder(p - Vector3.new(0, 4, 0), 8, r, M.Air)
			Lib.fillCylinder(p - Vector3.new(0, 4.75, 0), 6.5, r, M.Water)
			table.insert(ctx.avoid, { pos = p, r = r + 6 })
		end
	end
end

function Wolf.build(ctx: Types.Ctx)
	local f = ctx.folder
	local hub = ctx.hub
	local toward, right = ctx.toward, ctx.right
	local avoid = ctx.avoid
	table.insert(avoid, { pos = hub, r = 110 })
	local gateAngle = math.atan2(toward.Z, toward.X)

	-- Palisade of sharpened logs with a gap toward the road
	local R = 88
	local n = 64
	for k = 1, n do
		local a = k / n * 2 * math.pi
		local da = math.abs((a - gateAngle + math.pi) % (2 * math.pi) - math.pi)
		if da > math.rad(9) then
			local p = hub + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
			local h = Lib.rand(9, 11)
			Lib.column(f, "Palisade", Lib.onGround(p.X, p.Z, -1), 1.3, h, LOG:Lerp(Color3.new(0, 0, 0), Lib.rand(0, 0.2)), M.Wood)
			Lib.part(f, {
				Name = "PalisadeTip",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2.4, 1.6, 2.4),
				Position = Lib.onGround(p.X, p.Z, h - 1.2),
				Color = Color3.fromRGB(150, 120, 80),
				Material = M.Wood,
				CanCollide = false,
			})
		end
	end
	-- Watch platforms flanking the entrance
	for _, s in { -1, 1 } do
		local p = hub + toward * (R - 2) + right * s * 16
		for _, dx in { -2, 2 } do
			for _, dz in { -2, 2 } do
				Lib.column(f, "PlatformLeg", p + right * dx + toward * dz, 0.6, 14, LOG, M.Wood)
			end
		end
		Lib.box(f, "Platform", p + Vector3.new(0, 14, 0), Vector3.new(7, 0.6, 7), Color3.fromRGB(120, 90, 60), M.WoodPlanks, gateAngle)
		Lib.box(f, "PlatformRail", p + Vector3.new(0, 14.6, 0) + toward * 3.3, Vector3.new(7, 1.6, 0.3), LOG, M.Wood, gateAngle)
		Props.brazier(f, p + Vector3.new(0, 14.6, 0), Color3.fromRGB(255, 150, 60))
	end
	-- Skull-and-antler gate posts
	for _, s in { -1, 1 } do
		local p = hub + toward * R + right * s * 11
		Lib.column(f, "GatePost", Lib.onGround(p.X, p.Z, -1), 1.6, 16, Color3.fromRGB(80, 58, 38), M.Wood)
		Lib.boxAt(f, "Antler", CFrame.new(Lib.onGround(p.X, p.Z, 15)) * CFrame.Angles(0, gateAngle, math.rad(s * 35)), Vector3.new(0.4, 4, 0.4), Color3.fromRGB(220, 210, 190), M.SmoothPlastic)
		Lib.boxAt(f, "Antler", CFrame.new(Lib.onGround(p.X, p.Z, 15)) * CFrame.Angles(0, gateAngle, math.rad(-s * 35)), Vector3.new(0.4, 4, 0.4), Color3.fromRGB(220, 210, 190), M.SmoothPlastic)
	end
	Lib.box(f, "GateBeam", hub + toward * R + Vector3.new(0, 15, 0), Vector3.new(0.8, 1.2, 24), Color3.fromRGB(80, 58, 38), M.Wood, gateAngle + math.pi / 2)

	-- Central fire circle, totems, spawn
	Props.campfire(f, hub)
	Lib.disc(f, "FireRing", hub + Vector3.new(0, 0.2, 0), 14, 0.4, Color3.fromRGB(95, 80, 60), M.Ground)
	for k = 1, 4 do
		local a = k / 4 * 2 * math.pi + math.pi / 4
		totem(f, hub + Vector3.new(math.cos(a) * 20, 0, math.sin(a) * 20), -a + math.pi / 2)
	end
	Lib.spawnLocation(f, ctx.race.Name .. "Spawn", hub + toward * 22, BrickColor.new(ctx.race.TeamColor))

	-- Great Lodge (mission hub)
	do
		local pos = hub - toward * 48
		local cf = CFrame.lookAt(pos, hub)
		local w, d, h = 22, 36, 11
		Props.house(f, cf, w, d, h, LONGHOUSE)
		-- Antlers over the door and a carved sign
		local sign = Lib.part(f, { Name = "LodgeSign", Size = Vector3.new(6, 1.8, 0.3), CFrame = cf * CFrame.new(0, h - 1.2, -d / 2 - 0.3), Color = Color3.fromRGB(70, 50, 32), Material = M.Wood })
		Lib.surfaceText(sign, "Moonfang Lodge", Color3.fromRGB(230, 200, 140))
		for _, s in { -1, 1 } do
			Lib.boxAt(f, "Antler", cf * CFrame.new(s * 1.2, h + 0.4, -d / 2 - 0.4) * CFrame.Angles(0, 0, math.rad(s * 40)), Vector3.new(0.4, 3.5, 0.4), Color3.fromRGB(220, 210, 190), M.SmoothPlastic)
		end
		-- Interior: long fire pit, chieftain's seat, hides, trophy wall, hunt board
		Lib.boxAt(f, "FirePit", cf * CFrame.new(0, 0, 0), Vector3.new(4, 0.8, 14), Color3.fromRGB(80, 75, 70), M.Slate)
		local pitFire = Lib.part(f, { Name = "PitFire", Size = Vector3.new(2, 0.4, 11), CFrame = cf * CFrame.new(0, 1, 0), Color = Color3.fromRGB(255, 120, 40), Material = M.Neon, CanCollide = false })
		Lib.fire(pitFire, 6)
		Lib.smoke(pitFire, 2.5)
		Lib.boxAt(f, "ChiefSeat", cf * CFrame.new(0, 0, d / 2 - 4), Vector3.new(5, 2.2, 3), Color3.fromRGB(80, 58, 38), M.Wood)
		Lib.boxAt(f, "ChiefFur", cf * CFrame.new(0, 2.2, d / 2 - 4), Vector3.new(5, 0.6, 3), Color3.fromRGB(150, 135, 110), M.Fabric)
		Lib.boxAt(f, "ChiefBack", cf * CFrame.new(0, 2.2, d / 2 - 2.7), Vector3.new(5, 5, 0.6), Color3.fromRGB(80, 58, 38), M.Wood)
		for k = -2, 2 do
			Lib.boxAt(f, "HideRug", cf * CFrame.new(-7, 0, k * 6), Vector3.new(5, 0.15, 4), Lib.pick({ Color3.fromRGB(120, 90, 60), Color3.fromRGB(90, 70, 55) }), M.Fabric)
			Lib.boxAt(f, "HideRug", cf * CFrame.new(7, 0, k * 6), Vector3.new(5, 0.15, 4), Lib.pick({ Color3.fromRGB(150, 130, 100), Color3.fromRGB(90, 70, 55) }), M.Fabric)
		end
		for k = 1, 4 do
			-- trophy skulls on the right wall
			Lib.ball(f, "Skull", (cf * CFrame.new(w / 2 - 1.2, 6 + (k % 2), -10 + k * 5)).Position, 0.8, Color3.fromRGB(225, 215, 195), M.SmoothPlastic)
		end
		Props.noticeBoard(f, cf * CFrame.new(-w / 2 + 1.1, 0.5, -8) * CFrame.Angles(0, math.rad(-90), 0), {
			{ "THE WHITE STAG", "Seen by the north ponds. Its hide buys a winter. Bring it to the Lodge." },
			{ "SILVER", "Hunters from the Keep set silver traps on our side of the river. Break them." },
			{ "THE DEN", "The old den under the great oak has new tenants. Clear them out." },
			{ "PACK RUN", "Howl at the river stones at moonrise. The pack runs to the Warzone." },
		}, Color3.fromRGB(200, 190, 170))
	end

	-- Longhouses around the fire
	for _, deg in { 50, 110, -50, -110 } do
		local a = gateAngle + math.rad(deg + 180)
		local pos = hub + Vector3.new(math.cos(a) * 52, 0, math.sin(a) * 52)
		local cf = CFrame.lookAt(pos, hub)
		Props.house(f, cf, Lib.rand(11, 13), Lib.rand(22, 28), 8, LONGHOUSE)
	end
	-- Hide tents, racks, spits
	for _, deg in { 20, 150, -20, -150 } do
		local a = gateAngle + math.rad(deg + 180)
		local pos = hub + Vector3.new(math.cos(a) * 36, 0, math.sin(a) * 36)
		Props.tent(f, pos, -a + math.pi / 2, Lib.pick({ Color3.fromRGB(120, 90, 60), Color3.fromRGB(95, 75, 55) }))
	end
	dryingRack(f, CFrame.lookAt(hub + right * 30 + toward * 30, hub))
	dryingRack(f, CFrame.lookAt(hub - right * 30 + toward * 30, hub))
	for _ = 1, 6 do
		Props.barrel(f, hub + Vector3.new(Lib.rand(-60, 60), 0, Lib.rand(-60, 60)))
	end
	-- Moon shrine
	do
		local s = hub - right * 66
		for k = 1, 7 do
			local a = k / 7 * 2 * math.pi
			local st = Lib.box(f, "Standing Stone", s + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8), Vector3.new(2.2, Lib.rand(5, 8), 1.6), Color3.fromRGB(120, 118, 115), M.Slate, -a)
			st.Orientation = st.Orientation + Vector3.new(Lib.rand(-5, 5), 0, 0)
		end
		local plinth = Lib.column(f, "MoonPlinth", s, 1.6, 3, Color3.fromRGB(110, 108, 105), M.Slate)
		local stone = Lib.ball(f, "MoonStone", s + Vector3.new(0, 4.6, 0), 1.6, Color3.fromRGB(225, 230, 255), M.Neon, false)
		Lib.glow(stone, Color3.fromRGB(200, 210, 255), 2, 40)
		plinth.Name = "MoonPlinth"
	end

	-- Dens: hollowed hills with bones outside
	for _, off in { { 690, 0.17 }, { 760, -0.19 }, { 1080, 0.2 } } do
		local p = ctx.ringPoint(off[1], off[2])
		Lib.hill(p.X, p.Z, 30, 16, M.Ground, M.LeafyGrass)
		local dir = (hub - p).Unit
		local mouth = p - dir * 22
		Lib.fillBall(p + Vector3.new(0, 3, 0), 11, M.Air)
		Lib.fillBlock(CFrame.lookAt(mouth + Vector3.new(0, 4, 0), p + Vector3.new(0, 4, 0)), Vector3.new(8, 8, 24), M.Air)
		Lib.fillBlock(CFrame.lookAt(mouth + Vector3.new(0, 0.5, 0), p + Vector3.new(0, 0.5, 0)), Vector3.new(8, 1, 24), M.Ground)
		for _ = 1, 5 do
			local b = mouth - dir * Lib.rand(2, 8) + Vector3.new(Lib.rand(-5, 5), 0.3, Lib.rand(-5, 5))
			Lib.part(f, { Name = "Bone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(Lib.rand(2, 4), 0.5, 0.5), CFrame = CFrame.new(Lib.onGround(b.X, b.Z, 0.3)) * CFrame.Angles(0, Lib.rand(0, math.pi), 0), Color = Color3.fromRGB(225, 215, 195), Material = M.SmoothPlastic, CanCollide = false })
		end
		table.insert(avoid, { pos = p, r = 42 })
	end

	-- Hunters' camp near the river and a lookout over the bridge
	do
		local c = ctx.ringPoint(620, 0.12)
		c = Lib.onGround(c.X, c.Z)
		Props.campfire(f, c)
		Props.tent(f, c + Vector3.new(10, 0, 4), 0.6, Color3.fromRGB(110, 85, 60))
		dryingRack(f, CFrame.lookAt(c + Vector3.new(-9, 0, 5), c))
		Props.crate(f, c + Vector3.new(4, 0, -8))
		table.insert(avoid, { pos = c, r = 25 })

		local l = ctx.ringPoint(590, -0.08)
		l = Lib.onGround(l.X, l.Z)
		for _, dx in { -3, 3 } do
			for _, dz in { -3, 3 } do
				Lib.column(f, "LookoutLeg", l + Vector3.new(dx, 0, dz), 0.7, 20, LOG, M.Wood)
			end
		end
		Lib.box(f, "LookoutDeck", l + Vector3.new(0, 20, 0), Vector3.new(9, 0.6, 9), Color3.fromRGB(120, 90, 60), M.WoodPlanks)
		Lib.pitchedRoof(f, CFrame.new(l + Vector3.new(0, 24, 0)), 9, 9, 3, THATCH, M.Fabric, 0.5)
		for k = 1, 4 do
			local a = k / 4 * 2 * math.pi + math.pi / 4
			Lib.column(f, "LookoutPost", l + Vector3.new(math.cos(a) * 4.2, 20.6, math.sin(a) * 4.2), 0.3, 3.4, LOG, M.Wood)
		end
		Props.brazier(f, l + Vector3.new(0, 20.6, 0), Color3.fromRGB(255, 150, 60))
		table.insert(avoid, { pos = l, r = 12 })
	end

	-- Fireflies drifting through the forest
	local fireflyField = Lib.part(f, { Name = "Fireflies", Size = Vector3.new(500, 10, 500), Position = ctx.ringPoint(760, 0) + Vector3.new(0, 8, 0), Transparency = 1, CanCollide = false })
	local ff = Lib.particles(fireflyField, Color3.fromRGB(200, 255, 120), 40, 0.25, 1.5, 8, 180)
	ff.LightEmission = 1

	-- The forest itself
	World.scatter(ctx.index, 320, 575, 1180, avoid, 13, function(p)
		local roll = Lib.rng:NextNumber()
		if roll < 0.45 then
			Props.tree(f, p, Lib.rand(18, 32), Lib.pick({ Color3.fromRGB(45, 95, 45), Color3.fromRGB(60, 110, 50), Color3.fromRGB(80, 120, 45) }), Lib.rand(14, 22))
		elseif roll < 0.8 then
			Props.pine(f, p, Lib.rand(22, 38), Lib.pick({ Color3.fromRGB(30, 75, 45), Color3.fromRGB(40, 85, 50) }))
		elseif roll < 0.9 then
			Props.bush(f, p, Color3.fromRGB(60, 100, 45), Lib.rand(3, 6))
		elseif roll < 0.96 then
			Lib.fillBall(p + Vector3.new(0, -1.5, 0), Lib.rand(3, 7), M.Rock)
		else
			Lib.part(f, { Name = "FallenLog", Shape = Enum.PartType.Cylinder, Size = Vector3.new(Lib.rand(8, 14), 2.2, 2.2), CFrame = CFrame.new(p + Vector3.new(0, 1, 0)) * CFrame.Angles(0, Lib.rand(0, math.pi), 0), Color = Color3.fromRGB(75, 55, 38), Material = M.Wood })
		end
	end)
	World.scatter(ctx.index, 30, 575, 1180, avoid, 13, function(p)
		Props.mushrooms(f, p, Color3.fromRGB(200, 80, 60), false)
	end)
end

return Wolf
