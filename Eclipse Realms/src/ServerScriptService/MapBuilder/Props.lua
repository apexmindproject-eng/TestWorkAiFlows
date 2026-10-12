--!strict
-- Reusable world props: trees, buildings, furniture, bridges, camps.

local Lib = require(script.Parent.Lib)

local Props = {}

local WOOD = Color3.fromRGB(92, 66, 42)
local DARKWOOD = Color3.fromRGB(58, 42, 30)
local STONE = Color3.fromRGB(128, 124, 116)
local DARKSTONE = Color3.fromRGB(70, 68, 72)

-------------------------------------------------------------------------------
-- Vegetation
-------------------------------------------------------------------------------

-- Broadleaf tree: tapered trunk + 3-5 leaf clusters.
function Props.tree(parent: Instance, base: Vector3, height: number, leafColor: Color3, canopy: number)
	local trunkColor = Color3.fromRGB(72, 52, 36):Lerp(Color3.fromRGB(95, 70, 48), Lib.rand(0, 1))
	local lean = Lib.rand(-4, 4)
	local trunk = Lib.part(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 2.2, 2.2),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2 - 1.5, 0)) * CFrame.Angles(0, Lib.rand(0, math.pi), math.rad(90 + lean)),
		Color = trunkColor,
		Material = Enum.Material.Wood,
	})
	local top = base + Vector3.new(0, height - 1, 0)
	local clusters = Lib.rng:NextInteger(3, 5)
	for k = 1, clusters do
		local off = if k == 1 then Vector3.zero else Vector3.new(Lib.rand(-1, 1), Lib.rand(-0.4, 0.5), Lib.rand(-1, 1)).Unit * canopy * Lib.rand(0.3, 0.55)
		local r = canopy * (if k == 1 then 0.55 else Lib.rand(0.32, 0.46))
		Lib.ball(parent, "Leaves", top + off, r, leafColor:Lerp(Color3.new(0, 0, 0), Lib.rand(0, 0.18)), Enum.Material.Grass, false)
	end
	trunk.Name = "Trunk"
end

-- Conifer: trunk + stacked cones (approximated with shrinking cylinders is ugly, use wedges-free stacked balls flattened)
function Props.pine(parent: Instance, base: Vector3, height: number, color: Color3)
	Lib.part(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height * 0.5, 1.6, 1.6),
		CFrame = CFrame.new(base + Vector3.new(0, height * 0.25 - 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 50, 36),
		Material = Enum.Material.Wood,
	})
	local tiers = 4
	for k = 1, tiers do
		local t = (k - 1) / (tiers - 1)
		local y = base.Y + height * (0.35 + 0.55 * t)
		local r = height * 0.22 * (1 - t * 0.7) + 1.5
		Lib.part(parent, {
			Name = "Needles",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(r * 2, r * 1.1, r * 2),
			Position = Vector3.new(base.X, y, base.Z),
			Color = color:Lerp(Color3.new(0, 0, 0), Lib.rand(0, 0.15)),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
end

function Props.deadTree(parent: Instance, base: Vector3, height: number)
	local color = Color3.fromRGB(52, 46, 44)
	Lib.part(parent, {
		Name = "DeadTrunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.8, 1.8),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2 - 1, 0)) * CFrame.Angles(0, Lib.rand(0, math.pi), math.rad(90 + Lib.rand(-6, 6))),
		Color = color,
		Material = Enum.Material.Wood,
	})
	for _ = 1, Lib.rng:NextInteger(2, 4) do
		local y = height * Lib.rand(0.5, 0.9)
		local yaw = Lib.rand(0, 2 * math.pi)
		local len = Lib.rand(4, 8)
		Lib.part(parent, {
			Name = "Branch",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(len, 0.7, 0.7),
			CFrame = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, yaw, math.rad(Lib.rand(20, 50))) * CFrame.new(len / 2, 0, 0),
			Color = color,
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
	end
end

function Props.bamboo(parent: Instance, base: Vector3)
	for _ = 1, Lib.rng:NextInteger(4, 8) do
		local p = base + Vector3.new(Lib.rand(-2.5, 2.5), 0, Lib.rand(-2.5, 2.5))
		local h = Lib.rand(12, 22)
		Lib.part(parent, {
			Name = "Bamboo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, 0.6, 0.6),
			CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90 + Lib.rand(-3, 3))),
			Color = Color3.fromRGB(120, 160, 70),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		Lib.ball(parent, "BambooLeaves", p + Vector3.new(0, h - 1, 0), Lib.rand(1.5, 2.5), Color3.fromRGB(110, 170, 80), Enum.Material.Grass, false)
	end
end

function Props.bush(parent: Instance, base: Vector3, color: Color3, size: number)
	for _ = 1, Lib.rng:NextInteger(2, 4) do
		local p = base + Vector3.new(Lib.rand(-size * 0.4, size * 0.4), size * 0.3, Lib.rand(-size * 0.4, size * 0.4))
		Lib.ball(parent, "Bush", p, size * Lib.rand(0.4, 0.6), color:Lerp(Color3.new(0, 0, 0), Lib.rand(0, 0.2)), Enum.Material.Grass, false)
	end
end

function Props.mushrooms(parent: Instance, base: Vector3, capColor: Color3, glow: boolean)
	for _ = 1, Lib.rng:NextInteger(2, 5) do
		local p = base + Vector3.new(Lib.rand(-2, 2), 0, Lib.rand(-2, 2))
		local h = Lib.rand(0.8, 1.8)
		Lib.column(parent, "Stem", p, 0.2, h, Color3.fromRGB(225, 215, 190), Enum.Material.SmoothPlastic)
		local cap = Lib.part(parent, {
			Name = "Cap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(h * 1.2, h * 0.6, h * 1.2),
			Position = p + Vector3.new(0, h, 0),
			Color = capColor,
			Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		if glow then
			Lib.glow(cap, capColor, 0.6, 8)
		end
	end
end

-------------------------------------------------------------------------------
-- Small props
-------------------------------------------------------------------------------

function Props.barrel(parent: Instance, base: Vector3)
	local b = Lib.column(parent, "Barrel", base, 1.3, 3.2, Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
	for _, y in { 0.6, 2.6 } do
		Lib.part(parent, {
			Name = "Hoop",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 2.75, 2.75),
			CFrame = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(50, 50, 55),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
	end
	return b
end

function Props.crate(parent: Instance, base: Vector3, size: number?, yaw: number?)
	local s = size or 2.6
	return Lib.box(parent, "Crate", base, Vector3.new(s, s, s), Color3.fromRGB(140, 105, 65), Enum.Material.WoodPlanks, yaw or Lib.rand(0, math.pi))
end

function Props.sack(parent: Instance, base: Vector3)
	return Lib.part(parent, {
		Name = "Sack",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.2, 1.8, 2.2),
		Position = base + Vector3.new(0, 0.9, 0),
		Color = Color3.fromRGB(170, 150, 110),
		Material = Enum.Material.Fabric,
	})
end

function Props.hayBale(parent: Instance, base: Vector3, yaw: number?)
	return Lib.part(parent, {
		Name = "HayBale",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 3, 3),
		CFrame = CFrame.new(base + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, yaw or Lib.rand(0, math.pi), 0),
		Color = Color3.fromRGB(205, 175, 90),
		Material = Enum.Material.Fabric,
	})
end

function Props.lanternPost(parent: Instance, base: Vector3, lightColor: Color3?, height: number?)
	local h = height or 9
	local c = lightColor or Color3.fromRGB(255, 200, 120)
	Lib.column(parent, "LampPost", base, 0.3, h, Color3.fromRGB(45, 42, 40), Enum.Material.Metal)
	Lib.part(parent, {
		Name = "LampArm",
		Size = Vector3.new(0.3, 0.3, 2.2),
		CFrame = CFrame.new(base + Vector3.new(0, h - 0.4, 1)),
		Color = Color3.fromRGB(45, 42, 40),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	local lamp = Lib.part(parent, {
		Name = "Lantern",
		Size = Vector3.new(1.1, 1.5, 1.1),
		Position = base + Vector3.new(0, h - 1.4, 2),
		Color = c,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	Lib.glow(lamp, c, 1.4, 26)
	return lamp
end

function Props.wallTorch(parent: Instance, cf: CFrame)
	local stick = Lib.part(parent, {
		Name = "Torch",
		Size = Vector3.new(0.35, 2, 0.35),
		CFrame = cf * CFrame.Angles(math.rad(-20), 0, 0),
		Color = DARKWOOD,
		Material = Enum.Material.Wood,
		CanCollide = false,
	})
	local head = Lib.part(parent, {
		Name = "TorchHead",
		Size = Vector3.new(0.6, 0.6, 0.6),
		CFrame = cf * CFrame.new(0, 1.1, -0.4),
		Color = Color3.fromRGB(255, 160, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	Lib.fire(head, 2)
	stick.Name = "Torch"
end

function Props.brazier(parent: Instance, base: Vector3, color: Color3?, secondary: Color3?)
	Lib.column(parent, "BrazierStand", base, 0.4, 3, Color3.fromRGB(40, 38, 40), Enum.Material.Metal)
	local bowl = Lib.part(parent, {
		Name = "BrazierBowl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 3, 3),
		CFrame = CFrame.new(base + Vector3.new(0, 3.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(40, 38, 40),
		Material = Enum.Material.Metal,
	})
	local coals = Lib.part(parent, {
		Name = "Coals",
		Size = Vector3.new(1.5, 0.4, 1.5),
		Position = base + Vector3.new(0, 3.9, 0),
		Color = color or Color3.fromRGB(255, 120, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	Lib.fire(coals, 4, color, secondary)
	bowl.Name = "BrazierBowl"
end

function Props.campfire(parent: Instance, base: Vector3)
	for k = 1, 6 do
		local a = k / 6 * 2 * math.pi
		Lib.part(parent, {
			Name = "FireStone",
			Size = Vector3.new(1.2, 0.9, 1),
			CFrame = CFrame.new(base + Vector3.new(math.cos(a) * 2.2, 0.45, math.sin(a) * 2.2)) * CFrame.Angles(0, -a, 0),
			Color = Color3.fromRGB(90, 88, 85),
			Material = Enum.Material.Slate,
		})
	end
	for k = 1, 3 do
		Lib.part(parent, {
			Name = "Log",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.2, 0.7, 0.7),
			CFrame = CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, k * math.pi / 3, math.rad(15)),
			Color = Color3.fromRGB(60, 42, 30),
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
	end
	local core = Lib.part(parent, { Name = "Embers", Size = Vector3.new(1.4, 0.3, 1.4), Position = base + Vector3.new(0, 0.7, 0), Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.Neon, CanCollide = false })
	Lib.fire(core, 5)
	Lib.smoke(core, 2)
	-- Log seats
	for k = 1, 3 do
		local a = k / 3 * 2 * math.pi + 0.4
		Lib.part(parent, {
			Name = "SeatLog",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 1.4, 1.4),
			CFrame = CFrame.new(base + Vector3.new(math.cos(a) * 6, 0.7, math.sin(a) * 6)) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = Color3.fromRGB(80, 58, 40),
			Material = Enum.Material.Wood,
		})
	end
end

function Props.fence(parent: Instance, a: Vector3, b: Vector3, color: Color3?)
	local c = color or Color3.fromRGB(110, 85, 55)
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local posts = math.max(1, math.floor(len / 6))
	for k = 0, posts do
		local p = a + dir * (len * k / posts)
		Lib.box(parent, "FencePost", Vector3.new(p.X, Lib.ground(p.X, p.Z) - 0.3, p.Z), Vector3.new(0.5, 3.5, 0.5), c, Enum.Material.Wood)
	end
	for _, y in { 1.2, 2.5 } do
		local ga = Vector3.new(a.X, Lib.ground(a.X, a.Z) + y, a.Z)
		local gb = Vector3.new(b.X, Lib.ground(b.X, b.Z) + y, b.Z)
		Lib.part(parent, {
			Name = "FenceRail",
			Size = Vector3.new(0.25, 0.5, len),
			CFrame = CFrame.lookAt((ga + gb) / 2, gb),
			Color = c,
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
	end
end

function Props.cart(parent: Instance, base: Vector3, yaw: number)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	Lib.boxAt(parent, "CartBed", cf * CFrame.new(0, 1.6, 0), Vector3.new(4, 0.4, 7), WOOD, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		Lib.boxAt(parent, "CartSide", cf * CFrame.new(s * 1.9, 2, 0), Vector3.new(0.3, 1.6, 7), WOOD, Enum.Material.WoodPlanks)
		Lib.part(parent, {
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 3, 3),
			CFrame = cf * CFrame.new(s * 2.3, 1.5, 1.5),
			Color = DARKWOOD,
			Material = Enum.Material.Wood,
		})
	end
	Lib.part(parent, {
		Name = "CartHandle",
		Size = Vector3.new(0.4, 0.4, 5),
		CFrame = cf * CFrame.new(0, 1.2, -5.5) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	Props.sack(parent, (cf * CFrame.new(0.6, 1.8, 1)).Position - Vector3.new(0, 0, 0))
	Props.crate(parent, (cf * CFrame.new(-0.6, 1.8, -1.5)).Position, 1.8, yaw)
end

function Props.well(parent: Instance, base: Vector3)
	local ring = Lib.column(parent, "WellRing", base, 3, 2.6, STONE, Enum.Material.Cobblestone)
	Lib.disc(parent, "WellWater", base + Vector3.new(0, 1.2, 0), 2.4, 0.3, Color3.fromRGB(40, 70, 90), Enum.Material.Glass)
	for _, s in { -1, 1 } do
		Lib.column(parent, "WellPost", base + Vector3.new(s * 2.6, 2.6, 0), 0.25, 5, WOOD, Enum.Material.Wood)
	end
	Lib.part(parent, { Name = "WellBeam", Size = Vector3.new(6, 0.4, 0.4), Position = base + Vector3.new(0, 7.6, 0), Color = WOOD, Material = Enum.Material.Wood })
	Lib.pitchedRoof(parent, CFrame.new(base + Vector3.new(0, 7.8, 0)), 6.5, 6, 2.2, Color3.fromRGB(110, 60, 45), Enum.Material.Slate, 0.5)
	Lib.part(parent, { Name = "Bucket", Size = Vector3.new(1, 1.1, 1), Position = base + Vector3.new(0, 4.5, 0), Color = Color3.fromRGB(110, 80, 50), Material = Enum.Material.Wood, CanCollide = false })
	ring.Name = "WellRing"
end

function Props.bench(parent: Instance, cf: CFrame)
	Lib.boxAt(parent, "BenchSeat", cf * CFrame.new(0, 1.4, 0), Vector3.new(5, 0.3, 1.4), WOOD, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		Lib.boxAt(parent, "BenchLeg", cf * CFrame.new(s * 2, 0, 0), Vector3.new(0.4, 1.4, 1.2), DARKWOOD, Enum.Material.Wood)
	end
end

function Props.tableWithStools(parent: Instance, cf: CFrame, round: boolean?)
	if round then
		Lib.column(parent, "TableLeg", cf.Position, 0.3, 2.6, DARKWOOD, Enum.Material.Wood)
		Lib.disc(parent, "TableTop", cf.Position + Vector3.new(0, 2.8, 0), 2.6, 0.3, WOOD, Enum.Material.WoodPlanks)
	else
		Lib.boxAt(parent, "TableTop", cf * CFrame.new(0, 2.6, 0), Vector3.new(6, 0.3, 3), WOOD, Enum.Material.WoodPlanks)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Lib.boxAt(parent, "TableLeg", cf * CFrame.new(sx * 2.6, 0, sz * 1.2), Vector3.new(0.35, 2.6, 0.35), DARKWOOD, Enum.Material.Wood)
			end
		end
	end
	for k = 1, 4 do
		local a = k / 4 * 2 * math.pi + math.pi / 4
		local sp = cf * CFrame.new(math.cos(a) * 3.6, 0, math.sin(a) * 2.6)
		Lib.column(parent, "Stool", sp.Position, 0.7, 1.7, DARKWOOD, Enum.Material.Wood)
	end
	-- a mug or two
	Lib.column(parent, "Mug", (cf * CFrame.new(0.8, 2.8, 0.4)).Position, 0.28, 0.5, Color3.fromRGB(180, 170, 150), Enum.Material.SmoothPlastic)
	Lib.column(parent, "Candle", (cf * CFrame.new(-0.6, 2.8, -0.3)).Position, 0.12, 0.7, Color3.fromRGB(235, 225, 200), Enum.Material.SmoothPlastic)
	local flame = Lib.part(parent, { Name = "CandleFlame", Size = Vector3.new(0.2, 0.3, 0.2), CFrame = cf * CFrame.new(-0.6, 3.6, -0.3), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, CanCollide = false })
	Lib.glow(flame, Color3.fromRGB(255, 190, 110), 0.8, 10)
end

function Props.bookshelf(parent: Instance, cf: CFrame, width: number?)
	local w = width or 4
	Lib.boxAt(parent, "Shelf", cf, Vector3.new(w, 7, 1.2), DARKWOOD, Enum.Material.WoodPlanks)
	for row = 1, 4 do
		local x = -w / 2 + 0.3
		while x < w / 2 - 0.4 do
			local bw = Lib.rand(0.25, 0.5)
			Lib.part(parent, {
				Name = "Book",
				Size = Vector3.new(bw, Lib.rand(1, 1.4), 0.9),
				CFrame = cf * CFrame.new(x + bw / 2, row * 1.6 - 0.2, -0.15),
				Color = Lib.pick({ Color3.fromRGB(120, 40, 40), Color3.fromRGB(40, 60, 110), Color3.fromRGB(60, 90, 50), Color3.fromRGB(130, 110, 60), Color3.fromRGB(70, 40, 80) }),
				Material = Enum.Material.Fabric,
				CanCollide = false,
			})
			x += bw + 0.08
		end
	end
end

function Props.bed(parent: Instance, cf: CFrame, blanket: Color3)
	Lib.boxAt(parent, "BedFrame", cf, Vector3.new(4, 1.2, 7), DARKWOOD, Enum.Material.Wood)
	Lib.boxAt(parent, "Mattress", cf * CFrame.new(0, 1.2, 0), Vector3.new(3.6, 0.6, 6.6), Color3.fromRGB(225, 215, 195), Enum.Material.Fabric)
	Lib.boxAt(parent, "Blanket", cf * CFrame.new(0, 1.8, 1), Vector3.new(3.7, 0.3, 4.4), blanket, Enum.Material.Fabric)
	Lib.boxAt(parent, "Pillow", cf * CFrame.new(0, 1.8, -2.6), Vector3.new(2.6, 0.5, 1.2), Color3.fromRGB(240, 235, 220), Enum.Material.Fabric)
end

function Props.banner(parent: Instance, cf: CFrame, color: Color3, height: number?)
	local h = height or 7
	Lib.part(parent, { Name = "BannerRod", Size = Vector3.new(3.4, 0.25, 0.25), CFrame = cf, Color = DARKWOOD, Material = Enum.Material.Wood, CanCollide = false })
	Lib.part(parent, { Name = "Banner", Size = Vector3.new(3, h, 0.15), CFrame = cf * CFrame.new(0, -h / 2, 0), Color = color, Material = Enum.Material.Fabric, CanCollide = false })
	Lib.part(parent, { Name = "BannerTrim", Size = Vector3.new(3, 0.5, 0.2), CFrame = cf * CFrame.new(0, -h + 0.25, 0), Color = Color3.fromRGB(210, 180, 90), Material = Enum.Material.Fabric, CanCollide = false })
end

function Props.gravestone(parent: Instance, base: Vector3, yaw: number)
	local kind = Lib.rng:NextInteger(1, 3)
	if kind == 1 then
		Lib.box(parent, "Gravestone", base, Vector3.new(2.2, Lib.rand(2.5, 3.5), 0.6), Color3.fromRGB(95, 95, 100), Enum.Material.Slate, yaw)
	elseif kind == 2 then
		local h = Lib.rand(3, 4.5)
		Lib.box(parent, "GraveCross", base, Vector3.new(0.6, h, 0.6), Color3.fromRGB(90, 90, 95), Enum.Material.Slate, yaw)
		Lib.part(parent, { Name = "GraveCross", Size = Vector3.new(2.2, 0.6, 0.6), CFrame = CFrame.new(base + Vector3.new(0, h * 0.7, 0)) * CFrame.Angles(0, yaw, 0), Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.Slate })
	else
		Lib.box(parent, "Tomb", base, Vector3.new(3, 1.6, 6), Color3.fromRGB(80, 80, 88), Enum.Material.Concrete, yaw)
	end
end

function Props.statue(parent: Instance, base: Vector3, yaw: number, color: Color3, height: number)
	-- Simple robed figure on a plinth
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	Lib.boxAt(parent, "Plinth", cf, Vector3.new(4, 2.5, 4), STONE, Enum.Material.Concrete)
	local s = height / 8
	Lib.boxAt(parent, "StatueBody", cf * CFrame.new(0, 2.5, 0), Vector3.new(2.4 * s, 5 * s, 1.6 * s), color, Enum.Material.Marble)
	Lib.ball(parent, "StatueHead", (cf * CFrame.new(0, 2.5 + 5.8 * s, 0)).Position, 0.9 * s, color, Enum.Material.Marble)
	Lib.boxAt(parent, "StatueArm", cf * CFrame.new(1.6 * s, 2.5 + 2 * s, -0.6 * s) * CFrame.Angles(math.rad(-60), 0, 0), Vector3.new(0.7 * s, 3.5 * s, 0.7 * s), color, Enum.Material.Marble)
end

-------------------------------------------------------------------------------
-- Buildings
-------------------------------------------------------------------------------

export type HouseStyle = {
	Wall: Color3,
	WallMaterial: Enum.Material,
	Roof: Color3,
	RoofMaterial: Enum.Material,
	Trim: Color3?,
	WindowGlow: Color3?,
	Chimney: boolean?,
	RoofPitch: number?, -- rise as a fraction of depth
	Pyramid: boolean?,
}

-- A house. `cf` is ground centre; front door faces -Z of cf. Returns the interior floor CFrame.
function Props.house(parent: Instance, cf: CFrame, width: number, depth: number, height: number, style: HouseStyle, opts: { Door: boolean?, Windows: boolean?, Floor: boolean? }?): CFrame
	local o = opts or {}
	local t = 1 -- wall thickness
	local trim = style.Trim or style.Wall:Lerp(Color3.new(0, 0, 0), 0.4)

	-- Floor
	if o.Floor ~= false then
		Lib.boxAt(parent, "Floor", cf * CFrame.new(0, -0.5, 0), Vector3.new(width + 1, 1, depth + 1), Color3.fromRGB(120, 95, 65), Enum.Material.WoodPlanks)
	end

	-- Back and side walls
	Lib.boxAt(parent, "Wall", cf * CFrame.new(0, 0, depth / 2 - t / 2), Vector3.new(width, height, t), style.Wall, style.WallMaterial)
	for _, s in { -1, 1 } do
		Lib.boxAt(parent, "Wall", cf * CFrame.new(s * (width / 2 - t / 2), 0, 0), Vector3.new(t, height, depth), style.Wall, style.WallMaterial)
	end
	-- Front wall with doorway
	local doorW, doorH = 4, 6.5
	if o.Door == false then
		Lib.boxAt(parent, "Wall", cf * CFrame.new(0, 0, -depth / 2 + t / 2), Vector3.new(width, height, t), style.Wall, style.WallMaterial)
	else
		local sideW = (width - doorW) / 2
		for _, s in { -1, 1 } do
			Lib.boxAt(parent, "Wall", cf * CFrame.new(s * (doorW / 2 + sideW / 2), 0, -depth / 2 + t / 2), Vector3.new(sideW, height, t), style.Wall, style.WallMaterial)
		end
		Lib.boxAt(parent, "Wall", cf * CFrame.new(0, doorH, -depth / 2 + t / 2), Vector3.new(doorW, height - doorH, t), style.Wall, style.WallMaterial)
		-- Door frame
		for _, s in { -1, 1 } do
			Lib.boxAt(parent, "DoorFrame", cf * CFrame.new(s * (doorW / 2 + 0.2), 0, -depth / 2 + t / 2), Vector3.new(0.5, doorH + 0.3, t + 0.3), trim, Enum.Material.Wood)
		end
		Lib.boxAt(parent, "DoorFrame", cf * CFrame.new(0, doorH, -depth / 2 + t / 2), Vector3.new(doorW + 0.9, 0.5, t + 0.3), trim, Enum.Material.Wood)
		-- Open door leaf
		Lib.boxAt(parent, "Door", cf * CFrame.new(-doorW / 2, 0, -depth / 2 - 0.3) * CFrame.Angles(0, math.rad(-70), 0) * CFrame.new(doorW / 2 - 0.2, 0, 0), Vector3.new(doorW - 0.4, doorH - 0.2, 0.3), Color3.fromRGB(80, 55, 35), Enum.Material.Wood)
	end

	-- Windows (glass with warm light inside)
	if o.Windows ~= false then
		local glowC = style.WindowGlow or Color3.fromRGB(255, 190, 110)
		local wy = height * 0.55
		local positions = {}
		for _, s in { -1, 1 } do
			if depth >= 10 then
				table.insert(positions, cf * CFrame.new(s * (width / 2), wy, -depth / 4) * CFrame.Angles(0, math.rad(90), 0))
				table.insert(positions, cf * CFrame.new(s * (width / 2), wy, depth / 4) * CFrame.Angles(0, math.rad(90), 0))
			else
				table.insert(positions, cf * CFrame.new(s * (width / 2), wy, 0) * CFrame.Angles(0, math.rad(90), 0))
			end
			if width >= 10 then
				table.insert(positions, cf * CFrame.new(s * (width / 4 + doorW / 4), wy, -depth / 2))
			end
		end
		for _, wcf in positions do
			local glass = Lib.part(parent, {
				Name = "Window",
				Size = Vector3.new(2.2, 2.6, t + 0.2),
				CFrame = wcf,
				Color = glowC,
				Material = Enum.Material.Neon,
				Transparency = 0.25,
				CanCollide = false,
			})
			Lib.glow(glass, glowC, 0.9, 14)
			Lib.part(parent, { Name = "WindowFrame", Size = Vector3.new(2.6, 0.3, t + 0.3), CFrame = wcf * CFrame.new(0, 1.4, 0), Color = trim, Material = Enum.Material.Wood, CanCollide = false })
			Lib.part(parent, { Name = "WindowFrame", Size = Vector3.new(2.6, 0.3, t + 0.3), CFrame = wcf * CFrame.new(0, -1.4, 0), Color = trim, Material = Enum.Material.Wood, CanCollide = false })
		end
	end

	-- Corner beams
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Lib.boxAt(parent, "Beam", cf * CFrame.new(sx * (width / 2), 0, sz * (depth / 2)), Vector3.new(0.7, height, 0.7), trim, Enum.Material.Wood)
		end
	end

	-- Roof
	local roofBase = cf * CFrame.new(0, height, 0)
	if style.Pyramid then
		Lib.pyramidRoof(parent, roofBase, math.max(width, depth) + 3, (style.RoofPitch or 0.45) * math.max(width, depth), style.Roof, style.RoofMaterial)
	else
		Lib.pitchedRoof(parent, roofBase, width, depth, (style.RoofPitch or 0.5) * depth, style.Roof, style.RoofMaterial)
	end

	if style.Chimney then
		local chimney = Lib.boxAt(parent, "Chimney", cf * CFrame.new(width / 2 - 2, height - 1, depth / 4), Vector3.new(1.8, (style.RoofPitch or 0.5) * depth + 3, 1.8), Color3.fromRGB(100, 90, 85), Enum.Material.Brick)
		local top = Lib.part(parent, { Name = "ChimneyTop", Size = Vector3.new(1, 0.2, 1), CFrame = chimney.CFrame * CFrame.new(0, chimney.Size.Y / 2, 0), Transparency = 1, CanCollide = false })
		Lib.smoke(top, 1.2, Color3.fromRGB(150, 150, 155))
	end

	return cf
end

-- Round tower with a pyramid roof.
function Props.tower(parent: Instance, base: Vector3, radius: number, height: number, wallColor: Color3, wallMaterial: Enum.Material, roofColor: Color3, roofMaterial: Enum.Material, windowGlow: Color3?)
	Lib.column(parent, "Tower", base, radius, height, wallColor, wallMaterial)
	Lib.disc(parent, "TowerLedge", base + Vector3.new(0, height + 0.6, 0), radius + 0.8, 0.6, wallColor:Lerp(Color3.new(0, 0, 0), 0.2), wallMaterial)
	Lib.pyramidRoof(parent, CFrame.new(base + Vector3.new(0, height + 0.6, 0)), radius * 2 + 2, radius * 1.8, roofColor, roofMaterial)
	if windowGlow then
		for k = 1, 3 do
			local a = k / 3 * 2 * math.pi
			local w = Lib.part(parent, {
				Name = "TowerWindow",
				Size = Vector3.new(1.2, 2.4, 0.6),
				CFrame = CFrame.new(base + Vector3.new(math.cos(a) * radius, height * 0.7, math.sin(a) * radius)) * CFrame.Angles(0, -a + math.pi / 2, 0),
				Color = windowGlow,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			Lib.glow(w, windowGlow, 0.8, 16)
		end
	end
end

-- Crenellated stone wall segment.
function Props.battlement(parent: Instance, a: Vector3, b: Vector3, height: number, thickness: number, color: Color3, material: Enum.Material)
	Lib.wall(parent, "CurtainWall", a, b, height, thickness, color, material)
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local n = math.floor(len / 4)
	for k = 0, n do
		if k % 2 == 0 then
			local p = a + dir * (k * 4 + 2)
			Lib.part(parent, {
				Name = "Merlon",
				Size = Vector3.new(thickness, 2, 2.4),
				CFrame = CFrame.lookAt(p, p + dir) * CFrame.new(0, height + 1, 0),
				Color = color,
				Material = material,
			})
		end
	end
	-- Walkway lip
	Lib.part(parent, {
		Name = "Walkway",
		Size = Vector3.new(thickness + 2, 0.6, len),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, height - 0.3, 0),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.15),
		Material = material,
	})
end

-- Arched gatehouse opening in a wall line. `cf` at ground centre of the gate, -Z = outside.
function Props.gatehouse(parent: Instance, cf: CFrame, openingW: number, height: number, color: Color3, material: Enum.Material, torchColor: Color3?)
	local postW = 5
	for _, s in { -1, 1 } do
		Lib.boxAt(parent, "GatePost", cf * CFrame.new(s * (openingW / 2 + postW / 2), 0, 0), Vector3.new(postW, height + 6, 8), color, material)
		Lib.pyramidRoof(parent, cf * CFrame.new(s * (openingW / 2 + postW / 2), height + 6, 0), postW + 2, 4, color:Lerp(Color3.new(0, 0, 0), 0.5), Enum.Material.Slate)
		Props.wallTorch(parent, cf * CFrame.new(s * (openingW / 2 - 0.3), height * 0.55, -4.2))
	end
	Lib.boxAt(parent, "GateLintel", cf * CFrame.new(0, height - 2, 0), Vector3.new(openingW + 1, 4, 8), color, material)
	-- Portcullis bars (raised)
	for k = -2, 2 do
		Lib.boxAt(parent, "Portcullis", cf * CFrame.new(k * openingW / 6, height - 5, 0), Vector3.new(0.3, 3.5, 0.3), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
	end
	local _ = torchColor
end

-- Stone bridge from a to b (ground points) with a gentle arch and parapets.
function Props.bridge(parent: Instance, a: Vector3, b: Vector3, width: number, color: Color3, material: Enum.Material)
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local segments = 7
	local rise = 3.5
	local prev: Vector3? = nil
	for k = 0, segments do
		local t = k / segments
		local p = a + dir * (len * t) + Vector3.new(0, math.sin(t * math.pi) * rise, 0)
		if prev then
			local mid = (prev + p) / 2
			local segLen = (p - prev).Magnitude
			Lib.part(parent, {
				Name = "BridgeDeck",
				Size = Vector3.new(width, 1.2, segLen + 0.4),
				CFrame = CFrame.lookAt(mid, p) * CFrame.new(0, -0.6, 0),
				Color = color,
				Material = material,
			})
			for _, s in { -1, 1 } do
				Lib.part(parent, {
					Name = "Parapet",
					Size = Vector3.new(0.8, 1.6, segLen + 0.4),
					CFrame = CFrame.lookAt(mid, p) * CFrame.new(s * (width / 2 - 0.4), 0.6, 0),
					Color = color:Lerp(Color3.new(0, 0, 0), 0.15),
					Material = material,
				})
			end
		end
		prev = p
	end
	-- Piers
	for _, t in { 0.3, 0.7 } do
		local p = a + dir * (len * t)
		Lib.box(parent, "Pier", Vector3.new(p.X, -14, p.Z), Vector3.new(width - 2, 15, 4), color:Lerp(Color3.new(0, 0, 0), 0.2), material)
	end
	-- Lanterns at both ends
	local right = Vector3.new(-dir.Z, 0, dir.X)
	for _, endP in { a, b } do
		for _, s in { -1, 1 } do
			Props.lanternPost(parent, endP + right * s * (width / 2 + 1.2), Color3.fromRGB(255, 205, 130), 7)
		end
	end
end

function Props.tent(parent: Instance, base: Vector3, yaw: number, color: Color3, size: number?)
	local s = size or 1
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	Lib.pitchedRoof(parent, cf * CFrame.new(0, 0.2, 0), 8 * s, 9 * s, 5 * s, color, Enum.Material.Fabric, 0)
	Lib.boxAt(parent, "TentPole", cf * CFrame.new(0, 0, 0), Vector3.new(0.3, 5.2 * s, 0.3), Color3.fromRGB(90, 70, 45), Enum.Material.Wood)
	Lib.boxAt(parent, "Bedroll", cf * CFrame.new(1.5 * s, 0, 1), Vector3.new(2.5 * s, 0.5, 5 * s), Color3.fromRGB(110, 80, 60), Enum.Material.Fabric)
end

function Props.marketStall(parent: Instance, cf: CFrame, awning: Color3, goods: Color3)
	Lib.boxAt(parent, "StallCounter", cf, Vector3.new(7, 2.8, 2.6), WOOD, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		Lib.boxAt(parent, "StallPost", cf * CFrame.new(s * 3.3, 0, 1.2), Vector3.new(0.35, 7.5, 0.35), DARKWOOD, Enum.Material.Wood)
		Lib.boxAt(parent, "StallPost", cf * CFrame.new(s * 3.3, 0, -1.6), Vector3.new(0.35, 6.5, 0.35), DARKWOOD, Enum.Material.Wood)
	end
	Lib.part(parent, {
		Name = "Awning",
		Size = Vector3.new(8, 0.2, 4.2),
		CFrame = cf * CFrame.new(0, 7.2, -0.2) * CFrame.Angles(math.rad(-14), 0, 0),
		Color = awning,
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	for k = -1, 1 do
		Lib.part(parent, {
			Name = "Goods",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * Lib.rand(0.8, 1.3),
			CFrame = cf * CFrame.new(k * 1.8, 3.3, 0),
			Color = goods:Lerp(Color3.new(1, 1, 1), Lib.rand(0, 0.3)),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end
	Props.crate(parent, (cf * CFrame.new(-2.8, 0, 2.6)).Position, 2)
	Props.barrel(parent, (cf * CFrame.new(3, 0, 2.6)).Position)
end

-- Mission board: a wall-mounted board with notices. `cf` at the board's bottom centre, -Z facing reader.
function Props.noticeBoard(parent: Instance, cf: CFrame, titles: { { string } }, frameColor: Color3?)
	local w = 9
	local h = 6
	Lib.boxAt(parent, "NoticeBoard", cf, Vector3.new(w, h, 0.5), Color3.fromRGB(70, 50, 35), Enum.Material.WoodPlanks)
	Lib.boxAt(parent, "BoardFrame", cf * CFrame.new(0, -0.3, -0.05), Vector3.new(w + 0.6, 0.4, 0.7), frameColor or DARKWOOD, Enum.Material.Wood)
	Lib.boxAt(parent, "BoardFrame", cf * CFrame.new(0, h, -0.05), Vector3.new(w + 0.6, 0.4, 0.7), frameColor or DARKWOOD, Enum.Material.Wood)
	local n = #titles
	for i, entry in titles do
		local x = -w / 2 + (i - 0.5) * (w / n)
		Lib.notice(parent, cf * CFrame.new(x + Lib.rand(-0.2, 0.2), h / 2 + Lib.rand(-0.3, 0.3), -0.3) * CFrame.Angles(0, 0, math.rad(Lib.rand(-4, 4))), entry[1], entry[2], Vector2.new(w / n - 0.5, 3.4))
	end
end

return Props
