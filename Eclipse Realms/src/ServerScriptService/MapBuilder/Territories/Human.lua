--!strict
-- Aldermere Keep: a walled market town with farmland behind it and bandit country toward the river.

local MapBuilder = script.Parent.Parent
local Lib = require(MapBuilder.Lib)
local Props = require(MapBuilder.Props)
local World = require(MapBuilder.World)
local Types = require(MapBuilder.Types)

local M = Enum.Material
local Human = {}

local STONE = Color3.fromRGB(150, 145, 135)
local SLATE_BLUE = Color3.fromRGB(45, 65, 115)

local HOUSE: Props.HouseStyle = { Wall = Color3.fromRGB(205, 190, 160), WallMaterial = M.Plaster, Roof = Color3.fromRGB(120, 65, 45), RoofMaterial = M.Slate, Trim = Color3.fromRGB(80, 55, 35), Chimney = true }
local STONEHOUSE: Props.HouseStyle = { Wall = STONE, WallMaterial = M.Brick, Roof = SLATE_BLUE, RoofMaterial = M.Slate, Trim = Color3.fromRGB(70, 60, 50), Chimney = true }

function Human.terrain(ctx: Types.Ctx)
	local hub = ctx.hub
	-- Paved town
	Lib.fillCylinder(hub - Vector3.new(0, 2, 0), 4, 100, M.Cobblestone)
	-- Farmland behind town
	for k = -1, 1 do
		local c = ctx.P(-150, k * 60)
		Lib.fillBlock(CFrame.lookAt(c - Vector3.new(0, 2, 0), c - Vector3.new(0, 2, 0) + ctx.toward), Vector3.new(44, 4, 60), M.Ground)
	end
	-- Rolling hills in the wilds
	for _ = 1, 10 do
		local p = ctx.ringPoint(Lib.rand(600, 820), Lib.rand(-0.25, 0.25))
		if World.distanceToRoad(p.X, p.Z) > 70 then
			Lib.hill(p.X, p.Z, Lib.rand(30, 55), Lib.rand(22, 40), M.Grass, M.LeafyGrass)
		end
	end
	-- Woodland floor
	for _ = 1, 8 do
		local p = ctx.ringPoint(Lib.rand(620, 860), Lib.rand(-0.28, 0.28))
		Lib.fillCylinder(p - Vector3.new(0, 2, 0), 4, Lib.rand(25, 50), M.LeafyGrass)
	end
end

function Human.build(ctx: Types.Ctx)
	local f = ctx.folder
	local hub = ctx.hub
	local toward, right = ctx.toward, ctx.right
	local avoid = ctx.avoid
	table.insert(avoid, { pos = hub, r = 120 })

	-- Town walls: octagon with the gate facing the road
	local R = 96
	local gateAngle = math.atan2(toward.Z, toward.X)
	local verts = {}
	for k = 0, 7 do
		local a = gateAngle + math.rad(22.5) + k * math.rad(45)
		table.insert(verts, hub + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R))
	end
	for k = 1, 8 do
		local a, b = verts[k], verts[k % 8 + 1]
		if k == 8 then
			-- Front side: wall halves with a gatehouse in the middle
			local mid = (a + b) / 2
			local dir = (b - a).Unit
			Props.battlement(f, a, mid - dir * 8, 14, 3, STONE, M.Brick)
			Props.battlement(f, mid + dir * 8, b, 14, 3, STONE, M.Brick)
			Props.gatehouse(f, CFrame.lookAt(mid, mid + toward), 12, 14, STONE, M.Brick)
			Props.banner(f, CFrame.lookAt(mid, mid + toward) * CFrame.new(-11, 16, -4.2), SLATE_BLUE)
			Props.banner(f, CFrame.lookAt(mid, mid + toward) * CFrame.new(11, 16, -4.2), SLATE_BLUE)
			-- Guard captain's bounty board just inside the gate
			Props.noticeBoard(f, CFrame.lookAt(mid, mid + toward) * CFrame.new(-14, 1, 3) * CFrame.Angles(0, math.pi, 0), {
				{ "BOUNTY", "Wanted: the Ironfield bandit captain. 200 gold, alive or otherwise." },
				{ "PATROL", "Guards needed on the river road at dusk. Report to the gate sergeant." },
				{ "LOST", "Merchant's cart overturned near the old watchtower. Recover the goods." },
			})
		else
			Props.battlement(f, a, b, 14, 3, STONE, M.Brick)
		end
		if k % 2 == 1 then
			Props.tower(f, a, 5.5, 20, STONE, M.Brick, SLATE_BLUE, M.Slate, Color3.fromRGB(255, 190, 110))
		end
	end

	-- Town square
	Props.well(f, hub)
	for k = 1, 6 do
		local a = k / 6 * 2 * math.pi + 0.3
		Props.lanternPost(f, hub + Vector3.new(math.cos(a) * 24, 0, math.sin(a) * 24))
	end
	Props.bench(f, CFrame.lookAt(hub + right * 12 - toward * 6, hub))
	Props.bench(f, CFrame.lookAt(hub - right * 12 - toward * 6, hub))
	Lib.spawnLocation(f, ctx.race.Name .. "Spawn", hub - toward * 14, BrickColor.new(ctx.race.TeamColor))

	-- Market
	for k = -1, 1 do
		local p = hub + toward * 30 + right * (k * 11)
		Props.marketStall(f, CFrame.lookAt(p, p - toward), Lib.pick({ Color3.fromRGB(150, 50, 50), Color3.fromRGB(60, 90, 150), Color3.fromRGB(170, 140, 60) }), Lib.pick({ Color3.fromRGB(200, 90, 60), Color3.fromRGB(120, 170, 80), Color3.fromRGB(220, 200, 120) }))
	end
	Props.cart(f, hub + toward * 44 + right * 20, gateAngle + 1.2)

	-- The Gilded Stag tavern (mission hub)
	do
		local pos = hub + right * 42
		local cf = CFrame.lookAt(pos, hub)
		local w, d, h = 20, 26, 10
		Props.house(f, cf, w, d, h, HOUSE)
		-- Hanging sign
		local sign = Lib.part(f, { Name = "TavernSign", Size = Vector3.new(5, 2.4, 0.3), CFrame = cf * CFrame.new(5, h - 1.5, -d / 2 - 1.5), Color = Color3.fromRGB(60, 42, 30), Material = M.WoodPlanks })
		Lib.surfaceText(sign, "The Gilded Stag", Color3.fromRGB(220, 180, 80))
		Lib.part(f, { Name = "SignBracket", Size = Vector3.new(0.3, 0.3, 3), CFrame = cf * CFrame.new(5, h - 0.2, -d / 2 - 1.5), Color = Color3.fromRGB(40, 40, 42), Material = M.Metal, CanCollide = false })
		Props.wallTorch(f, cf * CFrame.new(-4, 5, -d / 2 - 0.5))
		Props.wallTorch(f, cf * CFrame.new(4, 5, -d / 2 - 0.5))
		-- Interior
		Lib.boxAt(f, "Bar", cf * CFrame.new(0, 0, d / 2 - 4), Vector3.new(14, 3.2, 2.4), Color3.fromRGB(90, 62, 40), M.WoodPlanks)
		Lib.boxAt(f, "BackBar", cf * CFrame.new(0, 3.5, d / 2 - 1.6), Vector3.new(14, 4, 1), Color3.fromRGB(70, 50, 34), M.WoodPlanks)
		for k = -3, 3 do
			Lib.column(f, "Bottle", (cf * CFrame.new(k * 1.8, 7.5, d / 2 - 1.6)).Position, 0.2, 0.9, Lib.pick({ Color3.fromRGB(60, 120, 70), Color3.fromRGB(120, 60, 50), Color3.fromRGB(200, 170, 90) }), M.Glass)
		end
		Props.tableWithStools(f, cf * CFrame.new(-6, 0, -5), true)
		Props.tableWithStools(f, cf * CFrame.new(6, 0, -5), true)
		Props.tableWithStools(f, cf * CFrame.new(-6, 0, 4))
		Props.tableWithStools(f, cf * CFrame.new(6, 0, 4), true)
		for k = 1, 4 do
			Props.barrel(f, (cf * CFrame.new(w / 2 - 2.2, 0, d / 2 - 5 - k * 2.8)).Position)
		end
		-- Fireplace
		Lib.boxAt(f, "Hearth", cf * CFrame.new(-w / 2 + 1.6, 0, 8), Vector3.new(2.4, 7, 6), Color3.fromRGB(110, 100, 95), M.Brick)
		local hearthFire = Lib.part(f, { Name = "HearthFire", Size = Vector3.new(1, 0.5, 3), CFrame = cf * CFrame.new(-w / 2 + 2.9, 0.6, 8), Color = Color3.fromRGB(255, 120, 40), Material = M.Neon, CanCollide = false })
		Lib.fire(hearthFire, 4)
		-- Chandelier
		local chand = Lib.disc(f, "Chandelier", (cf * CFrame.new(0, h - 2.5, 0)).Position, 2.4, 0.3, Color3.fromRGB(50, 45, 40), M.Metal)
		Lib.glow(chand, Color3.fromRGB(255, 190, 110), 1.5, 24)
		for k = 1, 6 do
			local a = k / 6 * 2 * math.pi
			Lib.part(f, { Name = "CandleFlame", Size = Vector3.new(0.25, 0.4, 0.25), CFrame = cf * CFrame.new(math.cos(a) * 2, h - 2, math.sin(a) * 2), Color = Color3.fromRGB(255, 210, 130), Material = M.Neon, CanCollide = false })
		end
		-- Mission board inside, by the door
		Props.noticeBoard(f, cf * CFrame.new(6.5, 0.5, -d / 2 + 1.2) * CFrame.Angles(0, math.pi, 0), {
			{ "WOLVES AT THE FENCE", "Farmer Hale lost three sheep to something with teeth. Find the den." },
			{ "THE OLD MINE", "Ironfield mine fell silent a week ago. Someone go look. Pay on return." },
			{ "ESCORT WANTED", "Caravan to the Neutral Grounds needs blades. Leaves at dawn." },
			{ "RIVER TOLL", "Bandits are taxing the bridge. The Crown would like that to stop." },
		})
		Lib.signpost(f, pos + cf.LookVector * (d / 2 + 8) - cf.RightVector * 8, "The Gilded Stag\nAle. Beds. Work.", cf.LookVector)
	end

	-- Blacksmith
	do
		local pos = hub - right * 42
		local cf = CFrame.lookAt(pos, hub)
		Props.house(f, cf, 14, 16, 8, STONEHOUSE)
		Lib.boxAt(f, "Anvil", cf * CFrame.new(-3, 0, -2), Vector3.new(1.2, 2.2, 3), Color3.fromRGB(45, 45, 50), M.Metal)
		local forge = Lib.boxAt(f, "Forge", cf * CFrame.new(3.5, 0, 4), Vector3.new(4, 3, 4), Color3.fromRGB(95, 85, 80), M.Brick)
		local coals = Lib.part(f, { Name = "ForgeCoals", Size = Vector3.new(2.5, 0.4, 2.5), CFrame = cf * CFrame.new(3.5, 3.2, 4), Color = Color3.fromRGB(255, 110, 30), Material = M.Neon, CanCollide = false })
		Lib.fire(coals, 3)
		forge.Name = "Forge"
		-- Weapon rack outside
		Lib.boxAt(f, "Rack", cf * CFrame.new(-8.5, 0, -6), Vector3.new(0.4, 4, 4), Color3.fromRGB(80, 60, 40), M.Wood)
		for k = -1, 1 do
			Lib.boxAt(f, "Sword", cf * CFrame.new(-8.2, 0.6, -6 + k * 1.2), Vector3.new(0.15, 3.4, 0.5), Color3.fromRGB(190, 195, 205), M.Metal)
		end
		local sign = Lib.part(f, { Name = "SmithSign", Size = Vector3.new(4, 1.6, 0.3), CFrame = cf * CFrame.new(0, 9.5, -8.3), Color = Color3.fromRGB(60, 42, 30), Material = M.WoodPlanks })
		Lib.surfaceText(sign, "Hale & Sons Smithy", Color3.fromRGB(230, 220, 200))
	end

	-- Chapel with bell tower
	do
		local pos = hub - toward * 56
		local cf = CFrame.lookAt(pos, hub)
		Props.house(f, cf, 14, 26, 12, { Wall = STONE, WallMaterial = M.Brick, Roof = SLATE_BLUE, RoofMaterial = M.Slate, RoofPitch = 0.7, WindowGlow = Color3.fromRGB(255, 220, 160) })
		Props.tower(f, (cf * CFrame.new(0, 0, 10)).Position, 4, 26, STONE, M.Brick, SLATE_BLUE, M.Slate)
		local bell = Lib.part(f, { Name = "Bell", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 2, 2), CFrame = cf * CFrame.new(0, 23, 10) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(190, 150, 60), Material = M.Metal })
		bell.Name = "Bell"
		for k = 1, 3 do
			Props.bench(f, cf * CFrame.new(-3, 0, -6 + k * 4) * CFrame.Angles(0, math.rad(90), 0))
			Props.bench(f, cf * CFrame.new(3, 0, -6 + k * 4) * CFrame.Angles(0, math.rad(90), 0))
		end
		Lib.boxAt(f, "Altar", cf * CFrame.new(0, 0, 9), Vector3.new(5, 3, 2), Color3.fromRGB(230, 225, 215), M.Marble)
		for _, x in { -1.8, 1.8 } do
			Lib.column(f, "Candle", (cf * CFrame.new(x, 3, 9)).Position, 0.15, 1, Color3.fromRGB(240, 230, 210), M.SmoothPlastic)
			local fl = Lib.part(f, { Name = "CandleFlame", Size = Vector3.new(0.25, 0.4, 0.25), CFrame = cf * CFrame.new(x, 4.2, 9), Color = Color3.fromRGB(255, 210, 130), Material = M.Neon, CanCollide = false })
			Lib.glow(fl, Color3.fromRGB(255, 200, 120), 0.8, 10)
		end
	end

	-- Houses around the square
	for _, deg in { 35, 68, 112, 145, -35, -68, -112, -145 } do
		local a = gateAngle + math.rad(deg + 180)
		local pos = hub + Vector3.new(math.cos(a) * 68, 0, math.sin(a) * 68)
		local cf = CFrame.lookAt(pos, hub)
		local w, d = Lib.rand(11, 14), Lib.rand(12, 16)
		Props.house(f, cf, w, d, Lib.rand(7, 9), if Lib.chance(0.7) then HOUSE else STONEHOUSE)
		if Lib.chance(0.5) then
			Props.barrel(f, (cf * CFrame.new(w / 2 + 1.5, 0, -2)).Position)
		end
		if Lib.chance(0.5) then
			Props.crate(f, (cf * CFrame.new(-w / 2 - 1.8, 0, 1)).Position, 2.2)
		end
	end

	-- Farmland behind town
	for k = -1, 1 do
		local c = ctx.P(-150, k * 60)
		local cf = CFrame.lookAt(c, c + toward)
		for row = -4, 4 do
			Lib.boxAt(f, "Crops", cf * CFrame.new(row * 4.5, 0, 0), Vector3.new(1.6, 2.2, 54), Lib.pick({ Color3.fromRGB(205, 175, 80), Color3.fromRGB(120, 150, 70) }), M.Grass)
		end
		local a = (cf * CFrame.new(-23, 0, -31)).Position
		local b = (cf * CFrame.new(23, 0, -31)).Position
		local c2 = (cf * CFrame.new(23, 0, 31)).Position
		local d2 = (cf * CFrame.new(-23, 0, 31)).Position
		Props.fence(f, a, b)
		Props.fence(f, b, c2)
		Props.fence(f, c2, d2)
		Props.fence(f, d2, a)
		table.insert(avoid, { pos = c, r = 45 })
	end
	do
		local farm = ctx.P(-225, 70)
		local cf = CFrame.lookAt(farm, hub)
		Props.house(f, cf, 14, 18, 8, HOUSE)
		local barn = ctx.P(-230, -60)
		local bcf = CFrame.lookAt(barn, hub)
		Props.house(f, bcf, 18, 26, 10, { Wall = Color3.fromRGB(130, 60, 45), WallMaterial = M.WoodPlanks, Roof = Color3.fromRGB(70, 55, 45), RoofMaterial = M.Wood, Trim = Color3.fromRGB(220, 210, 190) }, { Windows = false })
		for _ = 1, 6 do
			Props.hayBale(f, barn + Vector3.new(Lib.rand(-24, 24), 0, Lib.rand(-24, 24)))
		end
		table.insert(avoid, { pos = farm, r = 30 })
		table.insert(avoid, { pos = barn, r = 40 })
		-- Windmill
		local mill = ctx.P(-250, 10)
		Props.tower(f, mill, 6, 22, STONE, M.Brick, Color3.fromRGB(70, 55, 45), M.Wood)
		local hubPart = Lib.part(f, { Name = "MillHub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 2, 2), CFrame = CFrame.lookAt(mill + Vector3.new(0, 18, 0), mill + Vector3.new(0, 18, 0) + toward) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(60, 45, 35), Material = M.Wood })
		for k = 0, 3 do
			Lib.part(f, {
				Name = "MillBlade",
				Size = Vector3.new(2.6, 16, 0.3),
				CFrame = CFrame.lookAt(mill + Vector3.new(0, 18, 0), mill + Vector3.new(0, 18, 0) + toward) * CFrame.new(0, 0, -7.5) * CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0, 8, 0),
				Color = Color3.fromRGB(200, 190, 170),
				Material = M.Fabric,
				CanCollide = false,
			})
		end
		hubPart.Name = "MillHub"
		table.insert(avoid, { pos = mill, r = 20 })
		-- Scarecrow
		local sc = ctx.P(-150, 0)
		Lib.column(f, "ScarecrowPost", sc, 0.25, 6, Color3.fromRGB(100, 75, 50), M.Wood)
		Lib.box(f, "ScarecrowArms", sc + Vector3.new(0, 4.2, 0), Vector3.new(4, 0.3, 0.3), Color3.fromRGB(100, 75, 50), M.Wood)
		Lib.box(f, "ScarecrowCoat", sc + Vector3.new(0, 2.5, 0), Vector3.new(2, 2.4, 0.8), Color3.fromRGB(110, 70, 50), M.Fabric)
		Lib.ball(f, "ScarecrowHead", sc + Vector3.new(0, 6.5, 0), 0.8, Color3.fromRGB(200, 170, 110), M.Fabric)
	end

	-- Ironfield wilds: bandit camp off the road
	do
		local camp = ctx.ringPoint(720, 0.14)
		table.insert(avoid, { pos = camp, r = 50 })
		local cy = Lib.ground(camp.X, camp.Z)
		camp = Vector3.new(camp.X, cy, camp.Z)
		Lib.fillCylinder(camp - Vector3.new(0, 2, 0), 4, 30, M.Ground)
		for k = 1, 22 do
			local a = k / 22 * 2 * math.pi
			if k % 11 ~= 0 then
				local p = camp + Vector3.new(math.cos(a) * 30, 0, math.sin(a) * 30)
				local log = Lib.column(f, "Palisade", Lib.onGround(p.X, p.Z, -1), 1, Lib.rand(7, 9), Color3.fromRGB(95, 70, 45), M.Wood)
				log.Orientation = log.Orientation + Vector3.new(0, 0, Lib.rand(-4, 4))
			end
		end
		Props.campfire(f, camp)
		Props.tent(f, camp + Vector3.new(12, 0, 6), 0.4, Color3.fromRGB(90, 70, 55))
		Props.tent(f, camp + Vector3.new(-12, 0, 8), 2.6, Color3.fromRGB(80, 60, 50))
		Props.tent(f, camp + Vector3.new(2, 0, -14), 1.5, Color3.fromRGB(100, 80, 60), 1.3)
		for _ = 1, 5 do
			Props.crate(f, camp + Vector3.new(Lib.rand(-14, 14), 0, Lib.rand(-14, 14)))
		end
		Lib.box(f, "LootChest", camp + Vector3.new(-6, 0, -4), Vector3.new(3, 2, 2), Color3.fromRGB(110, 70, 40), M.Wood, 0.3)
		local pole = Lib.column(f, "BanditPole", camp + Vector3.new(0, 0, 18), 0.3, 12, Color3.fromRGB(70, 55, 40), M.Wood)
		Props.banner(f, CFrame.new(pole.Position + Vector3.new(0, 5.8, 0)), Color3.fromRGB(30, 28, 30), 6)
	end

	-- Ruined watchtower
	do
		local p = ctx.ringPoint(650, -0.15)
		local base = Lib.onGround(p.X, p.Z)
		table.insert(avoid, { pos = base, r = 22 })
		local t = Lib.column(f, "RuinedTower", base, 6, 18, Color3.fromRGB(120, 115, 108), M.Brick)
		t.Orientation = t.Orientation + Vector3.new(0, 0, 3)
		for _ = 1, 8 do
			local rb = Lib.box(f, "TowerRubble", base + Vector3.new(Lib.rand(-10, 10), 0, Lib.rand(-10, 10)), Vector3.new(Lib.rand(1.5, 4), Lib.rand(1, 3), Lib.rand(1.5, 4)), Color3.fromRGB(120, 115, 108), M.Brick, Lib.rand(0, math.pi))
			rb.Orientation = rb.Orientation + Vector3.new(Lib.rand(-15, 15), 0, 0)
		end
		Props.bush(f, base + Vector3.new(7, 0, 4), Color3.fromRGB(70, 110, 50), 4)
	end

	-- Old mine dug into a hill
	do
		local p = ctx.ringPoint(790, -0.2)
		Lib.hill(p.X, p.Z, 40, 24, M.Rock, M.Grass)
		local dir = (hub - p).Unit
		local mouth = p - dir * 30
		Lib.fillBlock(CFrame.lookAt(mouth + Vector3.new(0, 5, 0), p + Vector3.new(0, 5, 0)), Vector3.new(10, 10, 36), M.Air)
		Lib.fillBlock(CFrame.lookAt(mouth + Vector3.new(0, 1, 0), p + Vector3.new(0, 1, 0)), Vector3.new(10, 2, 36), M.Ground)
		local frame = CFrame.lookAt(mouth, mouth - dir)
		for _, s in { -1, 1 } do
			Lib.boxAt(f, "MineBeam", frame * CFrame.new(s * 5, 0, 0), Vector3.new(1, 10, 1), Color3.fromRGB(90, 68, 45), M.Wood)
		end
		Lib.boxAt(f, "MineBeam", frame * CFrame.new(0, 9.5, 0), Vector3.new(11.5, 1, 1), Color3.fromRGB(90, 68, 45), M.Wood)
		Props.wallTorch(f, frame * CFrame.new(-5.6, 5, -0.6))
		Props.wallTorch(f, frame * CFrame.new(5.6, 5, -0.6))
		Props.cart(f, mouth - dir * 8 + right * 6, math.atan2(-dir.X, -dir.Z))
		Lib.signpost(f, mouth - dir * 10 - right * 7, "IRONFIELD MINE\nClosed by order of the Crown", -dir)
		table.insert(avoid, { pos = p, r = 50 })
	end

	-- Roadside shrine
	do
		local p = ctx.ringPoint(770, 0.03)
		local base = Lib.onGround(p.X, p.Z)
		Props.statue(f, base, ctx.angle, Color3.fromRGB(200, 195, 185), 7)
		for k = -1, 1 do
			local fl = Lib.part(f, { Name = "CandleFlame", Size = Vector3.new(0.25, 0.4, 0.25), Position = base + toward * 3 + right * k * 1.2 + Vector3.new(0, 0.6, 0), Color = Color3.fromRGB(255, 210, 130), Material = M.Neon, CanCollide = false })
			Lib.glow(fl, Color3.fromRGB(255, 200, 120), 0.6, 8)
		end
		table.insert(avoid, { pos = base, r = 8 })
	end

	-- Orchards near town, woodland further out
	World.scatter(ctx.index, 40, 1000, 1150, avoid, 14, function(p)
		Props.tree(f, p, Lib.rand(10, 14), Color3.fromRGB(80, 130, 55), Lib.rand(9, 12))
	end)
	World.scatter(ctx.index, 160, 600, 870, avoid, 14, function(p)
		if Lib.chance(0.7) then
			Props.tree(f, p, Lib.rand(14, 24), Lib.pick({ Color3.fromRGB(85, 125, 55), Color3.fromRGB(110, 140, 60), Color3.fromRGB(150, 120, 50) }), Lib.rand(12, 18))
		elseif Lib.chance(0.6) then
			Props.bush(f, p, Color3.fromRGB(75, 110, 50), Lib.rand(3, 5))
		else
			Lib.fillBall(p + Vector3.new(0, -1.5, 0), Lib.rand(3, 6), M.Rock)
		end
	end)
	World.scatter(ctx.index, 14, 600, 870, avoid, 20, function(p)
		Props.hayBale(f, p)
	end)
end

return Human
