--!strict
-- Hexwood Coven: a stilt village in a glowing marsh, ruled from the Covenstead.

local MapBuilder = script.Parent.Parent
local Lib = require(MapBuilder.Lib)
local Props = require(MapBuilder.Props)
local World = require(MapBuilder.World)
local Types = require(MapBuilder.Types)

local M = Enum.Material
local Witch = {}

local HEXWOOD = Color3.fromRGB(62, 50, 70)
local HEXROOF = Color3.fromRGB(28, 22, 34)
local WITCHLIGHT = Color3.fromRGB(120, 255, 150)
local VIOLET = Color3.fromRGB(190, 100, 255)
local HUT: Props.HouseStyle = { Wall = HEXWOOD, WallMaterial = M.WoodPlanks, Roof = HEXROOF, RoofMaterial = M.Slate, Trim = Color3.fromRGB(35, 28, 40), WindowGlow = WITCHLIGHT, Chimney = true, RoofPitch = 0.95 }

local function stiltHouse(f: Folder, cf: CFrame, w: number, d: number, h: number, stilt: number)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Lib.boxAt(f, "Stilt", cf * CFrame.new(sx * (w / 2 - 1), 0, sz * (d / 2 - 1)), Vector3.new(1, stilt + 0.5, 1), Color3.fromRGB(45, 36, 40), M.Wood)
		end
	end
	local raised = cf * CFrame.new(0, stilt, 0)
	Props.house(f, raised, w, d, h, HUT)
	-- Steps down from the door
	Lib.wedge(f, {
		Name = "Steps",
		Size = Vector3.new(4, stilt, stilt * 1.6),
		CFrame = cf * CFrame.new(0, stilt / 2, -d / 2 - stilt * 0.8) ,
		Color = Color3.fromRGB(70, 56, 60),
		Material = M.WoodPlanks,
	})
	-- Broom by the door, lantern on the corner
	Lib.boxAt(f, "Broom", raised * CFrame.new(w / 2 - 2.5, 0, -d / 2 - 0.4) * CFrame.Angles(0, 0, math.rad(12)), Vector3.new(0.25, 5, 0.25), Color3.fromRGB(110, 85, 55), M.Wood)
	Lib.boxAt(f, "Bristles", raised * CFrame.new(w / 2 - 2.5 - 0.5, -0.6, -d / 2 - 0.4), Vector3.new(0.9, 1.6, 0.9), Color3.fromRGB(190, 160, 90), M.Fabric)
	local lamp = Lib.part(f, { Name = "HutLantern", Size = Vector3.new(0.8, 1.1, 0.8), CFrame = raised * CFrame.new(-w / 2 + 0.8, h - 1.5, -d / 2 - 0.8), Color = WITCHLIGHT, Material = M.Neon, CanCollide = false })
	Lib.glow(lamp, WITCHLIGHT, 1, 18)
end

local function wisp(f: Folder, p: Vector3, color: Color3)
	local w = Lib.ball(f, "Wisp", p, 0.6, color, M.Neon, false)
	Lib.glow(w, color, 1.2, 16)
	local e = Lib.particles(w, color, 8, 0.3, 0.6, 2.5, 180)
	e.LightEmission = 1
end

local function pool(ctx: Types.Ctx, p: Vector3, r: number)
	Lib.fillCylinder(p - Vector3.new(0, 3, 0), 6, r + 5, M.Mud)
	Lib.fillCylinder(p - Vector3.new(0, 3.5, 0), 7, r, M.Air)
	Lib.fillCylinder(p - Vector3.new(0, 4.25, 0), 5.5, r, M.Water)
	table.insert(ctx.avoid, { pos = p, r = r + 5 })
end

function Witch.terrain(ctx: Types.Ctx)
	local hub = ctx.hub
	-- Whole territory is marsh
	for _ = 1, 40 do
		local p = ctx.ringPoint(Lib.rand(580, 1180), Lib.rand(-0.3, 0.3))
		Lib.fillCylinder(p - Vector3.new(0, 2, 0), 4, Lib.rand(25, 70), Lib.pick({ M.Mud, M.Mud, M.LeafyGrass, M.Ground }))
	end
	Lib.fillCylinder(hub - Vector3.new(0, 2, 0), 4, 110, M.Mud)
	-- Pools scattered through the marsh
	for _ = 1, 18 do
		local p = ctx.ringPoint(Lib.rand(590, 1160), Lib.rand(-0.27, 0.27))
		if World.distanceToRoad(p.X, p.Z) > 34 and (p - hub).Magnitude > 125 then
			pool(ctx, p, Lib.rand(8, 22))
		end
	end
	-- A few low mounds
	for _ = 1, 6 do
		local p = ctx.ringPoint(Lib.rand(620, 1100), Lib.rand(-0.26, 0.26))
		if World.distanceToRoad(p.X, p.Z) > 50 and (p - hub).Magnitude > 140 then
			Lib.hill(p.X, p.Z, Lib.rand(20, 36), Lib.rand(15, 28), M.Mud, M.LeafyGrass)
		end
	end
end

function Witch.build(ctx: Types.Ctx)
	local f = ctx.folder
	local hub = ctx.hub
	local toward, right = ctx.toward, ctx.right
	local avoid = ctx.avoid
	table.insert(avoid, { pos = hub, r = 125 })
	local gateAngle = math.atan2(toward.Z, toward.X)

	-- Boardwalk from the road into the village
	for k = 0, 10 do
		local p = hub + toward * (30 + k * 7)
		Lib.box(f, "Boardwalk", p + Vector3.new(0, 0.2, 0), Vector3.new(6, 0.4, 7.2), Color3.fromRGB(75, 60, 60), M.WoodPlanks, gateAngle)
		if k % 3 == 0 then
			Props.lanternPost(f, p + right * 4, WITCHLIGHT, 7)
		end
	end

	-- The Covenstead (mission hub)
	do
		local pos = hub - toward * 30
		local cf = CFrame.lookAt(pos, hub)
		local w, d, h = 26, 26, 14
		Props.house(f, cf, w, d, h, { Wall = Color3.fromRGB(50, 40, 58), WallMaterial = M.WoodPlanks, Roof = HEXROOF, RoofMaterial = M.Slate, Trim = Color3.fromRGB(30, 24, 36), WindowGlow = WITCHLIGHT, Pyramid = true, RoofPitch = 0.8 })
		-- Spire with a crooked finial
		local spire = Lib.boxAt(f, cf * CFrame.new(0, h + 0.8 * 29, 0), Vector3.new(0.6, 6, 0.6), Color3.fromRGB(30, 24, 36), M.Metal)
		local orb = Lib.ball(f, "SpireOrb", spire.Position + Vector3.new(0, 3.6, 0), 1, VIOLET, M.Neon, false)
		Lib.glow(orb, VIOLET, 2, 40)
		-- Interior: cauldron, rune circle, potion shelves, hanging herbs, grimoire wall
		local runeRing = Lib.disc(f, "RuneCircle", (cf * CFrame.new(0, 0.12, 0)).Position, 7, 0.1, VIOLET, M.Neon)
		runeRing.Transparency = 0.4
		Lib.disc(f, "RuneCircleInner", (cf * CFrame.new(0, 0.14, 0)).Position, 6.2, 0.1, Color3.fromRGB(40, 30, 45), M.WoodPlanks)
		local cauldron = Lib.column(f, "Cauldron", cf.Position, 3.2, 4, Color3.fromRGB(28, 28, 32), M.Metal)
		local brew = Lib.disc(f, "Brew", cf.Position + Vector3.new(0, 4.1, 0), 2.9, 0.3, WITCHLIGHT, M.Neon)
		Lib.glow(brew, WITCHLIGHT, 2.5, 30)
		local bubbles = Lib.particles(brew, WITCHLIGHT, 20, 0.4, 2, 1.5, 25)
		bubbles.LightEmission = 1
		Lib.smoke(brew, 2, Color3.fromRGB(90, 160, 110))
		for k = 1, 3 do
			local a = k / 3 * 2 * math.pi
			Lib.boxAt(f, "CauldronLeg", CFrame.new(cf.Position + Vector3.new(math.cos(a) * 2.6, 0, math.sin(a) * 2.6)), Vector3.new(0.6, 1.2, 0.6), Color3.fromRGB(28, 28, 32), M.Metal)
		end
		cauldron.Name = "Cauldron"
		local firebed = Lib.part(f, { Name = "CauldronFire", Size = Vector3.new(2, 0.4, 2), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(120, 255, 160), Material = M.Neon, CanCollide = false })
		Lib.fire(firebed, 3, Color3.fromRGB(100, 255, 140), Color3.fromRGB(20, 90, 50))
		Props.bookshelf(f, cf * CFrame.new(-w / 2 + 1.2, 0, 4) * CFrame.Angles(0, math.rad(90), 0), 8)
		Props.bookshelf(f, cf * CFrame.new(0, 0, d / 2 - 1.2), 10)
		for k = -4, 4 do
			-- potion bottles along the back shelf top
			local b = Lib.column(f, "Potion", (cf * CFrame.new(k * 1.1, 7.1, d / 2 - 1.2)).Position, 0.25, 0.8, Lib.pick({ WITCHLIGHT, VIOLET, Color3.fromRGB(255, 120, 80), Color3.fromRGB(80, 160, 255) }), M.Neon)
				Lib.glow(b, b.Color, 0.4, 5)
		end
		for k = -3, 3 do
			Lib.boxAt(f, "Herbs", cf * CFrame.new(k * 2.5 + Lib.rand(-0.4, 0.4), h - 3, -6), Vector3.new(0.8, 2.2, 0.8), Lib.pick({ Color3.fromRGB(70, 110, 60), Color3.fromRGB(110, 90, 50), Color3.fromRGB(130, 60, 70) }), M.Grass)
		end
		Props.tableWithStools(f, cf * CFrame.new(8, 0, -6))
		Props.noticeBoard(f, cf * CFrame.new(w / 2 - 1.1, 0.5, -6) * CFrame.Angles(0, math.rad(90), 0), {
			{ "HEX WANTED", "A Keep merchant cheated Mother Yarrow. Make his cart's wheels forget how to turn." },
			{ "MOONWATER", "Fill three vials from the river under moonlight. Mind the bridge guards." },
			{ "THE DROWNED", "Something sings in the sunken chapel. Find out what it wants." },
			{ "WITCHFINDER", "A hunter from the Keep camps on our marsh with cages. Send him home." },
		}, Color3.fromRGB(25, 20, 30))
		local sign = Lib.part(f, { Name = "CovenSign", Size = Vector3.new(6, 2, 0.3), CFrame = cf * CFrame.new(0, h - 1.8, -d / 2 - 0.3), Color = Color3.fromRGB(30, 24, 36), Material = M.WoodPlanks })
		Lib.surfaceText(sign, "The Covenstead", WITCHLIGHT)
		Lib.spawnLocation(f, ctx.race.Name .. "Spawn", (cf * CFrame.new(0, 0, -d / 2 - 10)).Position, BrickColor.new(ctx.race.TeamColor))
	end

	-- Stilt huts around the Covenstead
	for _, deg in { 35, 72, 108, 145, -35, -72, -108, -145 } do
		local a = gateAngle + math.rad(deg + 180)
		local pos = hub + Vector3.new(math.cos(a) * Lib.rand(56, 70), 0, math.sin(a) * Lib.rand(56, 70))
		local cf = CFrame.lookAt(pos, hub) * CFrame.Angles(0, math.rad(Lib.rand(-10, 10)), 0)
		stiltHouse(f, cf, Lib.rand(9, 12), Lib.rand(10, 13), Lib.rand(8, 11), 4)
	end

	-- Stone circle and effigies
	do
		local s = hub + right * 95
		s = Lib.onGround(s.X, s.Z)
		for k = 1, 9 do
			local a = k / 9 * 2 * math.pi
			local st = Lib.box(f, "StandingStone", s + Vector3.new(math.cos(a) * 12, -0.4, math.sin(a) * 12), Vector3.new(2.6, Lib.rand(7, 11), 1.8), Color3.fromRGB(70, 66, 78), M.Slate, -a)
			st.Orientation = st.Orientation + Vector3.new(Lib.rand(-7, 7), 0, 0)
			local rune = Lib.part(f, { Name = "Rune", Size = Vector3.new(1, 1.4, 0.2), CFrame = st.CFrame * CFrame.new(0, 1.5, -1), Color = VIOLET, Material = M.Neon, CanCollide = false })
			Lib.glow(rune, VIOLET, 0.8, 12)
		end
		Lib.disc(f, "Altar", s + Vector3.new(0, 1.2, 0), 2.4, 1.2, Color3.fromRGB(60, 56, 68), M.Slate)
		for k = 1, 5 do
			local a = k / 5 * 2 * math.pi
			local fl = Lib.part(f, { Name = "CandleFlame", Size = Vector3.new(0.25, 0.4, 0.25), Position = s + Vector3.new(math.cos(a) * 1.6, 1.5, math.sin(a) * 1.6), Color = Color3.fromRGB(255, 200, 120), Material = M.Neon, CanCollide = false })
			Lib.glow(fl, Color3.fromRGB(255, 190, 110), 0.6, 8)
		end
		table.insert(avoid, { pos = s, r = 24 })
	end
	for _ = 1, 6 do
		local p = hub + Vector3.new(Lib.rand(-110, 110), 0, Lib.rand(-110, 110))
		if (p - hub).Magnitude > 80 and World.distanceToRoad(p.X, p.Z) > 14 then
			local base = Lib.onGround(p.X, p.Z)
			Lib.column(f, "EffigyPost", base, 0.25, 6, Color3.fromRGB(80, 65, 50), M.Wood)
			Lib.box(f, "EffigyArms", base + Vector3.new(0, 4.5, 0), Vector3.new(3.4, 0.25, 0.25), Color3.fromRGB(80, 65, 50), M.Wood, Lib.rand(0, math.pi))
			Lib.box(f, "EffigyBody", base + Vector3.new(0, 2.6, 0), Vector3.new(1.4, 2.2, 0.8), Color3.fromRGB(150, 130, 90), M.Fabric)
			Lib.ball(f, "EffigyHead", base + Vector3.new(0, 6, 0), 0.7, Color3.fromRGB(150, 130, 90), M.Fabric)
		end
	end

	-- Sunken chapel in a big pool
	do
		local p = ctx.ringPoint(690, 0.16)
		pool(ctx, p, 30)
		for k = 1, 6 do
			local a = k / 6 * 2 * math.pi
			local b = p + Vector3.new(math.cos(a) * 16, -3, math.sin(a) * 16)
			local col = Lib.column(f, "SunkenColumn", b, 1.6, Lib.rand(6, 14), Color3.fromRGB(110, 110, 118), M.Concrete)
			col.Orientation = col.Orientation + Vector3.new(Lib.rand(-8, 8), 0, Lib.rand(-8, 8))
		end
		local arch = Lib.box(f, "SunkenArch", p + Vector3.new(0, -3, 0), Vector3.new(14, 16, 2.5), Color3.fromRGB(100, 100, 108), M.Concrete, gateAngle)
		arch.Orientation = arch.Orientation + Vector3.new(0, 0, 6)
		Lib.box(f, "ArchGap", p + Vector3.new(0, -3, 0), Vector3.new(6, 10, 3), Color3.fromRGB(20, 40, 35), M.Glass, gateAngle).Transparency = 0.5
		for _ = 1, 5 do
			wisp(f, p + Vector3.new(Lib.rand(-24, 24), Lib.rand(1, 5), Lib.rand(-24, 24)), Color3.fromRGB(120, 200, 255))
		end
	end

	-- Witchfinder's camp (humans trespassing on the marsh)
	do
		local c = ctx.ringPoint(640, -0.15)
		c = Lib.onGround(c.X, c.Z)
		Lib.fillCylinder(c - Vector3.new(0, 2, 0), 4, 22, M.Ground)
		Props.campfire(f, c)
		Props.tent(f, c + Vector3.new(10, 0, 4), 0.3, Color3.fromRGB(150, 140, 120))
		Props.tent(f, c + Vector3.new(-10, 0, 6), 2.8, Color3.fromRGB(150, 140, 120))
		Props.cart(f, c + Vector3.new(2, 0, -14), 1.2)
		-- Iron cages
		for k = 1, 2 do
			local cp = c + Vector3.new(k * 8 - 12, 0, 12)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					Lib.box(f, "CageBar", cp + Vector3.new(sx * 1.5, 0, sz * 1.5), Vector3.new(0.25, 5, 0.25), Color3.fromRGB(45, 45, 50), M.Metal)
				end
			end
			Lib.box(f, "CageTop", cp + Vector3.new(0, 5, 0), Vector3.new(3.5, 0.3, 3.5), Color3.fromRGB(45, 45, 50), M.Metal)
			Lib.box(f, "CageFloor", cp, Vector3.new(3.5, 0.3, 3.5), Color3.fromRGB(45, 45, 50), M.Metal)
		end
		local pole = Lib.column(f, "CampPole", c + Vector3.new(0, 0, 18), 0.3, 11, Color3.fromRGB(100, 80, 55), M.Wood)
		Props.banner(f, CFrame.new(pole.Position + Vector3.new(0, 5.3, 0)), Color3.fromRGB(45, 65, 115), 6)
		table.insert(avoid, { pos = c, r = 32 })
	end

	-- Hag's hut far out in the bog
	do
		local p = ctx.ringPoint(1120, 0.2)
		local cf = CFrame.lookAt(Lib.onGround(p.X, p.Z), hub) * CFrame.Angles(0, math.rad(20), 0)
		stiltHouse(f, cf, 10, 11, 9, 6)
		for _ = 1, 4 do
			wisp(f, p + Vector3.new(Lib.rand(-20, 20), Lib.rand(2, 6), Lib.rand(-20, 20)), WITCHLIGHT)
		end
		Props.deadTree(f, Lib.onGround(p.X + 12, p.Z + 6), 18)
		table.insert(avoid, { pos = p, r = 28 })
	end

	-- Bog lights over the marsh
	local bogField = Lib.part(f, { Name = "BogLights", Size = Vector3.new(520, 6, 520), Position = ctx.ringPoint(820, 0) + Vector3.new(0, 4, 0), Transparency = 1, CanCollide = false })
	local bl = Lib.particles(bogField, WITCHLIGHT, 30, 0.35, 1, 7, 180)
	bl.LightEmission = 1
	local mistPart = Lib.part(f, { Name = "MarshMist", Size = Vector3.new(560, 1, 560), Position = ctx.ringPoint(840, 0) + Vector3.new(0, 1, 0), Transparency = 1, CanCollide = false })
	local mist = Lib.particles(mistPart, Color3.fromRGB(150, 175, 160), 40, 16, 0.5, 14, 10)
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.88), NumberSequenceKeypoint.new(1, 1) })
	mist.LightEmission = 0.1

	-- Marsh vegetation
	World.scatter(ctx.index, 260, 575, 1180, avoid, 12, function(p)
		local roll = Lib.rng:NextNumber()
		if roll < 0.35 then
			Props.deadTree(f, p, Lib.rand(12, 22))
			-- hanging moss
			for _ = 1, 2 do
				Lib.box(f, "Moss", p + Vector3.new(Lib.rand(-3, 3), Lib.rand(8, 13), Lib.rand(-3, 3)), Vector3.new(0.4, Lib.rand(3, 6), 0.4), Color3.fromRGB(80, 110, 70), M.Grass)
			end
		elseif roll < 0.6 then
			Props.tree(f, p, Lib.rand(14, 24), Lib.pick({ Color3.fromRGB(55, 80, 50), Color3.fromRGB(70, 60, 90), Color3.fromRGB(45, 70, 60) }), Lib.rand(12, 18))
		elseif roll < 0.75 then
			Props.mushrooms(f, p, Lib.pick({ VIOLET, WITCHLIGHT, Color3.fromRGB(255, 140, 80) }), true)
		elseif roll < 0.9 then
			Props.bamboo(f, p)
		else
			Props.bush(f, p, Color3.fromRGB(60, 85, 55), Lib.rand(3, 5))
		end
	end)
	World.scatter(ctx.index, 20, 575, 1180, avoid, 20, function(p)
		wisp(f, p + Vector3.new(0, Lib.rand(2, 6), 0), Lib.pick({ WITCHLIGHT, VIOLET }))
	end)
end

return Witch
