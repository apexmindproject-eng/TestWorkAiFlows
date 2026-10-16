--!strict
-- Castle Noctis: a black castle on a crag above a village of thralls, with a graveyard and dead woods below.

local MapBuilder = script.Parent.Parent
local Lib = require(MapBuilder.Lib)
local Props = require(MapBuilder.Props)
local World = require(MapBuilder.World)
local Types = require(MapBuilder.Types)

local M = Enum.Material
local Vampire = {}

local BLACKSTONE = Color3.fromRGB(38, 34, 40)
local CRIMSON = Color3.fromRGB(110, 18, 30)
local REDGLOW = Color3.fromRGB(255, 50, 60)
local PLATEAU_H = 20
local PLATEAU_R = 92

local THRALL: Props.HouseStyle = { Wall = Color3.fromRGB(85, 78, 80), WallMaterial = M.WoodPlanks, Roof = Color3.fromRGB(30, 26, 32), RoofMaterial = M.Slate, Trim = Color3.fromRGB(40, 34, 36), WindowGlow = Color3.fromRGB(255, 150, 80), Chimney = true, RoofPitch = 0.7 }

function Vampire.terrain(ctx: Types.Ctx)
	local hub = ctx.hub
	-- Crag the castle sits on
	Lib.fillCylinder(hub + Vector3.new(0, PLATEAU_H / 2 - 2, 0), PLATEAU_H + 4, PLATEAU_R + 10, M.Rock)
	Lib.fillCylinder(hub + Vector3.new(0, PLATEAU_H - 1, 0), 2, PLATEAU_R, M.Basalt)
	Lib.registerPlateau(hub.X, hub.Z, PLATEAU_R + 4, PLATEAU_H)
	-- Ramp down toward the village
	local edge = hub + ctx.toward * (PLATEAU_R + 6)
	local mid = edge + ctx.toward * 40 + Vector3.new(0, PLATEAU_H / 2, 0)
	Lib.fillWedge(CFrame.lookAt(mid, mid + ctx.toward), Vector3.new(30, PLATEAU_H, 80), M.Rock)
	Lib.fillWedge(CFrame.lookAt(mid + Vector3.new(0, 0.5, 0), mid + ctx.toward), Vector3.new(26, PLATEAU_H, 80), M.Basalt)
	-- Dead ground
	for _ = 1, 24 do
		local p = ctx.ringPoint(Lib.rand(580, 1180), Lib.rand(-0.3, 0.3))
		Lib.fillCylinder(p - Vector3.new(0, 2, 0), 4, Lib.rand(20, 60), Lib.pick({ M.Ground, M.Mud, M.Ground, M.Slate }))
	end
	for _ = 1, 8 do
		local p = ctx.ringPoint(Lib.rand(600, 820), Lib.rand(-0.26, 0.26))
		if World.distanceToRoad(p.X, p.Z) > 60 then
			Lib.hill(p.X, p.Z, Lib.rand(25, 45), Lib.rand(18, 34), M.Ground, M.Rock)
		end
	end
end

function Vampire.build(ctx: Types.Ctx)
	local f = ctx.folder
	local hub = ctx.hub
	local toward, right = ctx.toward, ctx.right
	local avoid = ctx.avoid
	table.insert(avoid, { pos = hub, r = 150 })
	local top = Vector3.new(hub.X, PLATEAU_H, hub.Z)

	-- Curtain wall octagon on the crag
	local R = 72
	local gateAngle = math.atan2(toward.Z, toward.X)
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
			Props.battlement(f, a, mid - dir * 8, 18, 3.5, BLACKSTONE, M.Basalt)
			Props.battlement(f, mid + dir * 8, b, 18, 3.5, BLACKSTONE, M.Basalt)
			Props.gatehouse(f, CFrame.lookAt(mid, mid + toward), 12, 18, BLACKSTONE, M.Basalt)
			Props.banner(f, CFrame.lookAt(mid, mid + toward) * CFrame.new(-11, 20, -4.2), CRIMSON, 9)
			Props.banner(f, CFrame.lookAt(mid, mid + toward) * CFrame.new(11, 20, -4.2), CRIMSON, 9)
		else
			Props.battlement(f, a, b, 18, 3.5, BLACKSTONE, M.Basalt)
		end
		if k % 2 == 1 then
			Props.tower(f, a, 7, 36, BLACKSTONE, M.Basalt, Color3.fromRGB(60, 12, 20), M.Slate, REDGLOW)
		end
	end

	-- Courtyard
	Lib.disc(f, "Courtyard", top + Vector3.new(0, 0.3, 0), 60, 0.6, Color3.fromRGB(48, 44, 48), M.Cobblestone)
	for k = 1, 6 do
		local a = k / 6 * 2 * math.pi + 0.5
		Props.brazier(f, top + Vector3.new(math.cos(a) * 28, 0.3, math.sin(a) * 28), REDGLOW, Color3.fromRGB(80, 0, 20))
	end
	Props.statue(f, top + right * 18 + toward * 20, gateAngle + math.pi, Color3.fromRGB(40, 36, 42), 10)
	Props.statue(f, top - right * 18 + toward * 20, gateAngle + math.pi, Color3.fromRGB(40, 36, 42), 10)
	Props.deadTree(f, top - right * 30 + toward * 2, 16)
	Lib.spawnLocation(f, ctx.race.Name .. "Spawn", top + toward * 8, BrickColor.new(ctx.race.TeamColor))

	-- The Keep and its Blood Court (mission hub)
	do
		local pos = top - toward * 28
		local cf = CFrame.lookAt(pos, top)
		local w, d, h = 36, 40, 18
		Props.house(f, cf, w, d, h, { Wall = BLACKSTONE, WallMaterial = M.Basalt, Roof = Color3.fromRGB(50, 10, 18), RoofMaterial = M.Slate, Trim = Color3.fromRGB(25, 22, 26), WindowGlow = REDGLOW, RoofPitch = 0.6 })
		-- Towers on the keep's back corners and a tall spire
		Props.tower(f, (cf * CFrame.new(-w / 2, 0, d / 2)).Position, 6, 44, BLACKSTONE, M.Basalt, Color3.fromRGB(60, 12, 20), M.Slate, REDGLOW)
		Props.tower(f, (cf * CFrame.new(w / 2, 0, d / 2)).Position, 6, 44, BLACKSTONE, M.Basalt, Color3.fromRGB(60, 12, 20), M.Slate, REDGLOW)
		Props.tower(f, (cf * CFrame.new(0, 0, d / 2 + 4)).Position, 5, 62, BLACKSTONE, M.Basalt, Color3.fromRGB(60, 12, 20), M.Slate, REDGLOW)
		-- Interior: carpet, throne, tables, chandeliers, banners
		Lib.boxAt(f, "Carpet", cf * CFrame.new(0, 0, 2), Vector3.new(6, 0.15, d - 6), CRIMSON, M.Fabric)
		Lib.boxAt(f, "Dais", cf * CFrame.new(0, 0, d / 2 - 6), Vector3.new(14, 1.5, 7), Color3.fromRGB(30, 26, 30), M.Marble)
		Lib.boxAt(f, "ThroneSeat", cf * CFrame.new(0, 1.5, d / 2 - 5), Vector3.new(3.5, 2.2, 3), Color3.fromRGB(25, 22, 26), M.Basalt)
		Lib.boxAt(f, "ThroneBack", cf * CFrame.new(0, 1.5, d / 2 - 3.6), Vector3.new(3.5, 8, 0.8), Color3.fromRGB(25, 22, 26), M.Basalt)
		Lib.boxAt(f, "ThroneCushion", cf * CFrame.new(0, 3.7, d / 2 - 5), Vector3.new(3, 0.4, 2.6), CRIMSON, M.Fabric)
		for _, s in { -1, 1 } do
			Lib.boxAt(f, "ThroneArm", cf * CFrame.new(s * 1.9, 1.5, d / 2 - 5), Vector3.new(0.5, 3.4, 3), Color3.fromRGB(25, 22, 26), M.Basalt)
			Props.brazier(f, (cf * CFrame.new(s * 6, 1.5, d / 2 - 6)).Position, REDGLOW, Color3.fromRGB(80, 0, 20))
			-- Long feast tables
			local tcf = cf * CFrame.new(s * 10, 0, -2)
			Lib.boxAt(f, "LongTable", tcf * CFrame.new(0, 2.8, 0), Vector3.new(4, 0.3, 22), Color3.fromRGB(40, 30, 32), M.WoodPlanks)
			for k = -2, 2 do
				Lib.boxAt(f, "TableLeg", tcf * CFrame.new(0, 0, k * 5), Vector3.new(0.5, 2.8, 0.5), Color3.fromRGB(30, 24, 26), M.Wood)
				Lib.column(f, "Goblet", (tcf * CFrame.new(Lib.rand(-1.2, 1.2), 3.1, k * 5 + Lib.rand(-1.5, 1.5))).Position, 0.25, 0.6, Color3.fromRGB(180, 150, 70), M.Metal)
				local candle = Lib.part(f, { Name = "CandleFlame", Size = Vector3.new(0.25, 0.4, 0.25), CFrame = tcf * CFrame.new(0, 3.6, k * 5 + 2.5), Color = Color3.fromRGB(255, 180, 110), Material = M.Neon, CanCollide = false })
				Lib.glow(candle, Color3.fromRGB(255, 160, 100), 0.6, 8)
			end
			for k = -2, 2 do
				Props.banner(f, cf * CFrame.new(s * (w / 2 - 0.8), h - 1, k * 7) * CFrame.Angles(0, math.rad(90), 0), CRIMSON, 9)
			end
		end
		for k = -1, 1 do
			local chand = Lib.disc(f, "Chandelier", (cf * CFrame.new(0, h - 4, k * 11)).Position, 3, 0.3, Color3.fromRGB(35, 30, 32), M.Metal)
			Lib.glow(chand, Color3.fromRGB(255, 120, 90), 1.6, 30)
			for j = 1, 8 do
				local a = j / 8 * 2 * math.pi
				Lib.part(f, { Name = "CandleFlame", Size = Vector3.new(0.25, 0.45, 0.25), CFrame = cf * CFrame.new(math.cos(a) * 2.6, h - 3.4, k * 11 + math.sin(a) * 2.6), Color = Color3.fromRGB(255, 190, 120), Material = M.Neon, CanCollide = false })
			end
		end
		-- Covenant board: blood contracts, by the door
		Props.noticeBoard(f, cf * CFrame.new(11, 0.5, -d / 2 + 1.3) * CFrame.Angles(0, math.pi, 0), {
			{ "THE HUNT", "A hunter stalks the dead woods with silver. Bring the Court his bow." },
			{ "TITHE", "The thralls of Noctis owe blood. Collect it before the moon sets." },
			{ "THE CRYPT", "Something stirs below the graveyard that is not ours. Put it back down." },
			{ "WAR", "The Crown's bridge guards grow bold. Remind them whose night this is." },
		}, Color3.fromRGB(20, 18, 22))
		Lib.signpost(f, (cf * CFrame.new(-10, 0, -d / 2 - 8)).Position, "The Blood Court\nPetitioners enter kneeling.", cf.LookVector, Color3.fromRGB(150, 30, 40))
	end

	-- Red lanterns along the ramp and the village road
	for k = 0, 5 do
		local p = hub + toward * (PLATEAU_R + 10 + k * 16) + right * 14
		Props.lanternPost(f, Lib.onGround(p.X, p.Z), REDGLOW, 8)
	end

	-- Thrall village at the foot of the crag
	local villageC = hub + toward * 160
	table.insert(avoid, { pos = villageC, r = 80 })
	Lib.fillCylinder(villageC - Vector3.new(0, 2, 0), 4, 60, M.Ground)
	for _, deg in { 30, 75, 125, 160, -30, -75, -125, -160 } do
		local a = gateAngle + math.rad(deg + 180)
		local pos = villageC + Vector3.new(math.cos(a) * 42, 0, math.sin(a) * 42)
		local cf = CFrame.lookAt(pos, villageC)
		local house = Props.house(f, cf, Lib.rand(10, 13), Lib.rand(11, 15), Lib.rand(7, 9), THRALL)
		local _ = house
	end
	Props.well(f, villageC)
	for k = 1, 4 do
		local a = k / 4 * 2 * math.pi
		Props.lanternPost(f, villageC + Vector3.new(math.cos(a) * 18, 0, math.sin(a) * 18), Color3.fromRGB(255, 120, 80), 8)
	end
	Props.cart(f, villageC + right * 20 + toward * 10, gateAngle)
	Props.deadTree(f, villageC - right * 26, 14)
	-- Inn for travellers (the thralls still need to drink)
	do
		local pos = villageC + right * 60
		local cf = CFrame.lookAt(pos, villageC)
		Props.house(f, cf, 18, 22, 9, THRALL)
		local sign = Lib.part(f, { Name = "InnSign", Size = Vector3.new(5, 2.2, 0.3), CFrame = cf * CFrame.new(5, 7.8, -12.4), Color = Color3.fromRGB(40, 32, 34), Material = M.WoodPlanks })
		Lib.surfaceText(sign, "The Pale Hound", Color3.fromRGB(200, 60, 70))
		Props.tableWithStools(f, cf * CFrame.new(-5, 0, -4), true)
		Props.tableWithStools(f, cf * CFrame.new(5, 0, 3))
		Lib.boxAt(f, "Bar", cf * CFrame.new(0, 0, 8), Vector3.new(12, 3.2, 2.4), Color3.fromRGB(50, 38, 36), M.WoodPlanks)
		for _ = 1, 3 do
			Props.barrel(f, (cf * CFrame.new(Lib.rand(-7, -5), 0, Lib.rand(6, 9))).Position)
		end
	end

	-- Graveyard and mausoleum
	do
		local gy = ctx.ringPoint(720, 0.16)
		gy = Lib.onGround(gy.X, gy.Z)
		table.insert(avoid, { pos = gy, r = 75 })
		Lib.fillCylinder(gy - Vector3.new(0, 2, 0), 4, 60, M.Ground)
		-- Iron fence square
		local hw = 52
		local corners = { gy + Vector3.new(-hw, 0, -hw), gy + Vector3.new(hw, 0, -hw), gy + Vector3.new(hw, 0, hw), gy + Vector3.new(-hw, 0, hw) }
		for k = 1, 4 do
			Props.fence(f, corners[k], corners[k % 4 + 1], Color3.fromRGB(35, 33, 36))
		end
		for _ = 1, 44 do
			local p = gy + Vector3.new(Lib.rand(-46, 46), 0, Lib.rand(-46, 46))
			if (p - gy).Magnitude > 16 then
				Props.gravestone(f, Lib.onGround(p.X, p.Z, -0.3), Lib.rand(-0.3, 0.3))
			end
		end
		-- Mausoleum
		local mcf = CFrame.lookAt(gy, gy + toward)
		Props.house(f, mcf, 14, 16, 9, { Wall = Color3.fromRGB(95, 92, 100), WallMaterial = M.Concrete, Roof = Color3.fromRGB(45, 42, 50), RoofMaterial = M.Slate, Pyramid = true, RoofPitch = 0.5 }, { Windows = false })
		Props.statue(f, (mcf * CFrame.new(-6, 0, -12)).Position, gateAngle, Color3.fromRGB(90, 88, 95), 7)
		Props.statue(f, (mcf * CFrame.new(6, 0, -12)).Position, gateAngle, Color3.fromRGB(90, 88, 95), 7)
		Props.wallTorch(f, mcf * CFrame.new(-3, 5, -8.6))
		Props.wallTorch(f, mcf * CFrame.new(3, 5, -8.6))
		-- Graveyard mist
		local mist = Lib.part(f, { Name = "Mist", Size = Vector3.new(110, 1, 110), Position = gy + Vector3.new(0, 1, 0), Transparency = 1, CanCollide = false })
		local e = Lib.particles(mist, Color3.fromRGB(170, 160, 185), 18, 14, 0.6, 12, 10)
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(1, 1) })
		e.LightEmission = 0.1
		for _ = 1, 8 do
			local p = gy + Vector3.new(Lib.rand(-50, 50), 0, Lib.rand(-50, 50))
			Props.deadTree(f, Lib.onGround(p.X, p.Z), Lib.rand(12, 18))
		end
		for _ = 1, 6 do
			local p = gy + Vector3.new(Lib.rand(-40, 40), 0, Lib.rand(-40, 40))
			Props.mushrooms(f, Lib.onGround(p.X, p.Z), Color3.fromRGB(170, 90, 230), true)
		end
	end

	-- Crypt dug into a hillside
	do
		local p = ctx.ringPoint(640, -0.17)
		Lib.hill(p.X, p.Z, 34, 20, M.Ground, M.Rock)
		local dir = (hub - p).Unit
		local mouth = p - dir * 26
		Lib.fillBlock(CFrame.lookAt(mouth + Vector3.new(0, 4.5, 0), p + Vector3.new(0, 4.5, 0)), Vector3.new(8, 9, 30), M.Air)
		Lib.fillBlock(CFrame.lookAt(mouth + Vector3.new(0, 0.5, 0), p + Vector3.new(0, 0.5, 0)), Vector3.new(8, 1, 30), M.Basalt)
		local frame = CFrame.lookAt(mouth, mouth - dir)
		for _, s in { -1, 1 } do
			Lib.boxAt(f, "CryptPillar", frame * CFrame.new(s * 4.6, 0, 0), Vector3.new(1.6, 9.5, 1.6), Color3.fromRGB(70, 66, 74), M.Concrete)
		end
		Lib.boxAt(f, "CryptLintel", frame * CFrame.new(0, 9.2, 0), Vector3.new(11, 1.6, 2), Color3.fromRGB(70, 66, 74), M.Concrete)
		Props.brazier(f, (frame * CFrame.new(-6.5, 0, -2)).Position, Color3.fromRGB(150, 60, 255), Color3.fromRGB(40, 0, 80))
		Props.brazier(f, (frame * CFrame.new(6.5, 0, -2)).Position, Color3.fromRGB(150, 60, 255), Color3.fromRGB(40, 0, 80))
		Lib.signpost(f, (frame * CFrame.new(-9, 0, -5)).Position, "CRYPT OF THE FIRST\nDo not wake them.", -dir, Color3.fromRGB(150, 30, 40))
		table.insert(avoid, { pos = p, r = 45 })
	end

	-- Blood moon low over the castle
	local moon = Lib.ball(f, "BloodMoon", hub - toward * 420 + Vector3.new(0, 300, 0), 42, Color3.fromRGB(190, 35, 45), M.Neon, false)
	moon.Transparency = 0.1
	Lib.glow(moon, Color3.fromRGB(200, 40, 50), 3, 400)

	-- Dead woods everywhere else
	World.scatter(ctx.index, 170, 580, 880, avoid, 14, function(p)
		if Lib.chance(0.65) then
			Props.deadTree(f, p, Lib.rand(12, 20))
		elseif Lib.chance(0.5) then
			Props.pine(f, p, Lib.rand(16, 26), Color3.fromRGB(35, 45, 40))
		elseif Lib.chance(0.5) then
			Props.mushrooms(f, p, Color3.fromRGB(170, 90, 230), true)
		else
			Lib.fillBall(p + Vector3.new(0, -1.5, 0), Lib.rand(3, 6), M.Rock)
		end
	end)
	World.scatter(ctx.index, 60, 1000, 1160, avoid, 14, function(p)
		Props.deadTree(f, p, Lib.rand(12, 20))
	end)
end

return Vampire
