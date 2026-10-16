--!strict
-- Shared building helpers: parts, wedges, lights, signs, terrain and ground height.

local Workspace = game:GetService("Workspace")

local Lib = {}

Lib.rng = Random.new(20261012)

function Lib.rand(min: number, max: number): number
	return Lib.rng:NextNumber(min, max)
end

function Lib.chance(p: number): boolean
	return Lib.rng:NextNumber() < p
end

function Lib.pick<T>(list: { T }): T
	return list[Lib.rng:NextInteger(1, #list)]
end

-------------------------------------------------------------------------------
-- Ground height registry (terrain is generated from these same shapes)
-------------------------------------------------------------------------------

type Hill = { x: number, z: number, y: number, r: number }
type Plateau = { x: number, z: number, r: number, h: number }

local hills: { Hill } = {}
local plateaus: { Plateau } = {}

function Lib.resetGround()
	table.clear(hills)
	table.clear(plateaus)
end

function Lib.registerHill(x: number, z: number, y: number, r: number)
	table.insert(hills, { x = x, z = z, y = y, r = r })
end

function Lib.registerPlateau(x: number, z: number, r: number, h: number)
	table.insert(plateaus, { x = x, z = z, r = r, h = h })
end

-- Ground surface height at a flat position.
function Lib.ground(x: number, z: number): number
	local y = 0
	for _, p in plateaus do
		local dx, dz = x - p.x, z - p.z
		if dx * dx + dz * dz <= p.r * p.r then
			y = math.max(y, p.h)
		end
	end
	for _, h in hills do
		local dx, dz = x - h.x, z - h.z
		local d2 = dx * dx + dz * dz
		if d2 < h.r * h.r then
			y = math.max(y, h.y + math.sqrt(h.r * h.r - d2))
		end
	end
	return y
end

function Lib.onGround(x: number, z: number, lift: number?): Vector3
	return Vector3.new(x, Lib.ground(x, z) + (lift or 0), z)
end

-------------------------------------------------------------------------------
-- Terrain
-------------------------------------------------------------------------------

local Terrain = Workspace.Terrain

function Lib.fillBall(center: Vector3, radius: number, material: Enum.Material)
	Terrain:FillBall(center, radius, material)
end

function Lib.fillBlock(cf: CFrame, size: Vector3, material: Enum.Material)
	Terrain:FillBlock(cf, size, material)
end

function Lib.fillCylinder(center: Vector3, height: number, radius: number, material: Enum.Material)
	Terrain:FillCylinder(CFrame.new(center), height, radius, material)
end

function Lib.fillWedge(cf: CFrame, size: Vector3, material: Enum.Material)
	Terrain:FillWedge(cf, size, material)
end

-- A hill that is both carved into terrain and registered for Lib.ground.
function Lib.hill(x: number, z: number, radius: number, sink: number, material: Enum.Material, cap: Enum.Material?)
	local y = -sink
	Lib.fillBall(Vector3.new(x, y, z), radius, material)
	if cap then
		Lib.fillBall(Vector3.new(x, y + radius * 0.35, z), radius * 0.55, cap)
	end
	Lib.registerHill(x, z, y, radius)
end

-- Terrain road: a strip of material flush with the ground along a polyline.
function Lib.terrainRoad(points: { Vector3 }, width: number, material: Enum.Material)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ga = Vector3.new(a.X, Lib.ground(a.X, a.Z), a.Z)
		local gb = Vector3.new(b.X, Lib.ground(b.X, b.Z), b.Z)
		local mid = (ga + gb) / 2 - Vector3.new(0, 2, 0)
		local len = (gb - ga).Magnitude + 4
		Lib.fillBlock(CFrame.lookAt(mid, gb - Vector3.new(0, 2, 0)), Vector3.new(width, 4, len), material)
	end
end

-------------------------------------------------------------------------------
-- Parts
-------------------------------------------------------------------------------

export type PartProps = {
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

local function applyBase(p: BasePart, props: PartProps)
	p.Name = props.Name or "Part"
	p.Anchored = true
	p.Size = props.Size
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or Color3.fromRGB(160, 160, 160)
	p.Transparency = props.Transparency or 0
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.Reflectance = props.Reflectance or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.CFrame then
		p.CFrame = props.CFrame
	elseif props.Position then
		p.Position = props.Position
	end
end

function Lib.part(parent: Instance, props: PartProps): Part
	local p = Instance.new("Part")
	p.Shape = props.Shape or Enum.PartType.Block
	applyBase(p, props)
	p.Parent = parent
	return p
end

function Lib.wedge(parent: Instance, props: PartProps): WedgePart
	local p = Instance.new("WedgePart")
	applyBase(p, props)
	p.Parent = parent
	return p
end

function Lib.cornerWedge(parent: Instance, props: PartProps): CornerWedgePart
	local p = Instance.new("CornerWedgePart")
	applyBase(p, props)
	p.Parent = parent
	return p
end

-- Box standing on `base` (bottom centre), rotated by yaw.
function Lib.box(parent: Instance, name: string, base: Vector3, size: Vector3, color: Color3, material: Enum.Material, yaw: number?): Part
	return Lib.part(parent, {
		Name = name,
		Size = size,
		CFrame = CFrame.new(base + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw or 0, 0),
		Color = color,
		Material = material,
	})
end

-- Box positioned by a CFrame at its bottom centre.
function Lib.boxAt(parent: Instance, name: string, baseCF: CFrame, size: Vector3, color: Color3, material: Enum.Material): Part
	return Lib.part(parent, {
		Name = name,
		Size = size,
		CFrame = baseCF * CFrame.new(0, size.Y / 2, 0),
		Color = color,
		Material = material,
	})
end

-- Vertical cylinder standing on `base`.
function Lib.column(parent: Instance, name: string, base: Vector3, radius: number, height: number, color: Color3, material: Enum.Material): Part
	return Lib.part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

-- Flat disc, top surface at center.Y
function Lib.disc(parent: Instance, name: string, center: Vector3, radius: number, thickness: number, color: Color3, material: Enum.Material): Part
	return Lib.part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(center - Vector3.new(0, thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

function Lib.ball(parent: Instance, name: string, center: Vector3, radius: number, color: Color3, material: Enum.Material, canCollide: boolean?): Part
	return Lib.part(parent, {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2,
		Position = center,
		Color = color,
		Material = material,
		CanCollide = canCollide,
	})
end

-- Wall from a to b (ground points), given height and thickness.
function Lib.wall(parent: Instance, name: string, a: Vector3, b: Vector3, height: number, thickness: number, color: Color3, material: Enum.Material): Part
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	return Lib.part(parent, {
		Name = name,
		Size = Vector3.new(thickness, height, length + thickness),
		CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, height / 2, 0),
		Color = color,
		Material = material,
	})
end

-- Pitched roof. `baseCF` is the centre of the roof's base rectangle (top of walls),
-- ridge runs along local X. width = along ridge, depth = across, height = rise.
function Lib.pitchedRoof(parent: Instance, baseCF: CFrame, width: number, depth: number, height: number, color: Color3, material: Enum.Material, overhang: number?)
	local oh = overhang or 1.5
	local w = width + oh * 2
	local d = depth / 2 + oh
	-- Each wedge: vertical back face (+Z) sits at the ridge, slope falls toward -Z.
	Lib.wedge(parent, {
		Name = "Roof",
		Size = Vector3.new(w, height, d),
		CFrame = baseCF * CFrame.new(0, height / 2, -d / 2),
		Color = color,
		Material = material,
	})
	Lib.wedge(parent, {
		Name = "Roof",
		Size = Vector3.new(w, height, d),
		CFrame = baseCF * CFrame.new(0, height / 2, d / 2) * CFrame.Angles(0, math.pi, 0),
		Color = color,
		Material = material,
	})
	-- Gable fills
	for side = -1, 1, 2 do
		Lib.part(parent, {
			Name = "Gable",
			Size = Vector3.new(0.6, height, depth),
			CFrame = baseCF * CFrame.new(side * (width / 2 - 0.3), height / 2, 0),
			Color = color:Lerp(Color3.new(1, 1, 1), 0.15),
			Material = Enum.Material.WoodPlanks,
		})
	end
end

-- Square pyramid roof from four corner wedges. baseCF at the base centre.
function Lib.pyramidRoof(parent: Instance, baseCF: CFrame, side: number, height: number, color: Color3, material: Enum.Material)
	local half = side / 2
	local quads = { { -1, -1, 0 }, { 1, -1, -math.pi / 2 }, { 1, 1, math.pi }, { -1, 1, math.pi / 2 } }
	for _, q in quads do
		Lib.cornerWedge(parent, {
			Name = "Roof",
			Size = Vector3.new(half, height, half),
			CFrame = baseCF * CFrame.new(q[1] * half / 2, height / 2, q[2] * half / 2) * CFrame.Angles(0, q[3], 0),
			Color = color,
			Material = material,
		})
	end
end

-------------------------------------------------------------------------------
-- Lights and effects
-------------------------------------------------------------------------------

function Lib.glow(p: BasePart, color: Color3, brightness: number, range: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = p
	return light
end

function Lib.fire(p: BasePart, size: number, color: Color3?, secondary: Color3?)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = size * 1.2
	f.Color = color or Color3.fromRGB(255, 150, 60)
	f.SecondaryColor = secondary or Color3.fromRGB(140, 40, 10)
	f.Parent = p
	Lib.glow(p, f.Color, 1.6, size * 6)
end

function Lib.smoke(p: BasePart, size: number, color: Color3?, rate: number?)
	local s = Instance.new("Smoke")
	s.Size = size
	s.Opacity = 0.25
	s.RiseVelocity = 4
	s.Color = color or Color3.fromRGB(120, 120, 125)
	s.Parent = p
	local _ = rate
end

function Lib.sparkles(p: BasePart, color: Color3)
	local s = Instance.new("Sparkles")
	s.SparkleColor = color
	s.Parent = p
end

-- Floating ash / embers / fireflies
function Lib.particles(p: BasePart, color: Color3, rate: number, size: number, speed: number, lifetime: number, spread: number)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Rate = rate
	e.Size = NumberSequence.new(size)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.LightEmission = 0.8
	e.LightInfluence = 0
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) })
	e.Drag = 1
	e.Parent = p
	return e
end

-------------------------------------------------------------------------------
-- Text on surfaces
-------------------------------------------------------------------------------

-- Readable text on the front (-Z) face of a part. Keep it small and physical, no billboards.
function Lib.surfaceText(p: BasePart, text: string, color: Color3, font: Enum.Font?, face: Enum.NormalId?, scale: number?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.8
	gui.Parent = p

	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.Size = UDim2.fromScale(scale or 0.9, scale or 0.85)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color
	t.Font = font or Enum.Font.Antique
	t.TextScaled = true
	t.TextWrapped = true
	t.Parent = gui
	return gui
end

-- Wooden signpost with a board that reads `text`, facing `faceDir`.
function Lib.signpost(parent: Instance, base: Vector3, text: string, faceDir: Vector3, textColor: Color3?)
	local post = Lib.column(parent, "SignPost", base, 0.35, 7, Color3.fromRGB(85, 62, 40), Enum.Material.Wood)
	local look = CFrame.lookAt(base + Vector3.new(0, 6, 0), base + Vector3.new(0, 6, 0) + faceDir)
	local board = Lib.part(parent, {
		Name = "SignBoard",
		Size = Vector3.new(5.5, 1.8, 0.4),
		CFrame = look * CFrame.new(0, 0, -0.4),
		Color = Color3.fromRGB(120, 92, 60),
		Material = Enum.Material.WoodPlanks,
	})
	Lib.surfaceText(board, text, textColor or Color3.fromRGB(45, 30, 20))
	post.Name = "SignPost"
	return board
end

-- A parchment notice pinned to a wall with a prompt to read it. `cf` is the poster's
-- centre with -Z facing the reader.
function Lib.notice(parent: Instance, cf: CFrame, title: string, body: string, size: Vector2?)
	local sz = size or Vector2.new(2.2, 3)
	local paper = Lib.part(parent, {
		Name = "Notice",
		Size = Vector3.new(sz.X, sz.Y, 0.08),
		CFrame = cf,
		Color = Color3.fromRGB(222, 203, 160),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.9
	gui.Parent = paper

	local t = Instance.new("TextLabel")
	t.Position = UDim2.fromScale(0.06, 0.05)
	t.Size = UDim2.fromScale(0.88, 0.22)
	t.BackgroundTransparency = 1
	t.Text = title
	t.TextColor3 = Color3.fromRGB(60, 35, 20)
	t.Font = Enum.Font.Antique
	t.TextScaled = true
	t.TextWrapped = true
	t.Parent = gui

	local b = Instance.new("TextLabel")
	b.Position = UDim2.fromScale(0.08, 0.3)
	b.Size = UDim2.fromScale(0.84, 0.62)
	b.BackgroundTransparency = 1
	b.Text = body
	b.TextColor3 = Color3.fromRGB(70, 50, 35)
	b.Font = Enum.Font.Garamond
	b.TextScaled = true
	b.TextWrapped = true
	b.TextYAlignment = Enum.TextYAlignment.Top
	b.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Read"
	prompt.ObjectText = title
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = paper

	-- Pin
	Lib.part(parent, {
		Name = "Pin",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.25,
		CFrame = cf * CFrame.new(0, sz.Y / 2 - 0.2, -0.1),
		Color = Color3.fromRGB(120, 30, 30),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	return paper
end

function Lib.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Lib.spawnLocation(parent: Instance, name: string, position: Vector3, teamColor: BrickColor?): SpawnLocation
	local s = Instance.new("SpawnLocation")
	s.Name = name
	s.Anchored = true
	s.Size = Vector3.new(8, 0.5, 8)
	s.Position = position + Vector3.new(0, 0.25, 0)
	s.Transparency = 1
	s.CanCollide = false
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

return Lib
