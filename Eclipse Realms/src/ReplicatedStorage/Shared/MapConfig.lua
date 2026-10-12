--!strict
-- Map layout. Everything is laid out in rings around the Warzone at the world origin.
--
--   Start Zone  ->  Mission Zone  ->  Neutral Zone (ring)  ->  WARZONE (center)
--
-- Each race owns one "sector" (a 72 degree wedge). Sectors are walled off from each
-- other in the outer rings, so the only way between races is through the Neutral ring.

local RaceConfig = require(script.Parent.RaceConfig)

local MapConfig = {}

MapConfig.GroundY = 0 -- top surface of the ground

-- Ring radii (studs from the center)
MapConfig.Warzone = { Radius = 140 }
MapConfig.Neutral = { Inner = 140, Outer = 260 }
MapConfig.Mission = { Inner = 260, Outer = 420, Center = 340, Radius = 60 }
MapConfig.Start = { Inner = 420, Outer = 600, Center = 520, Radius = 70 }
MapConfig.WorldRadius = 600

MapConfig.RoadWidth = 24
MapConfig.WallHeight = 60
MapConfig.WallThickness = 6

-- Lobby floats above the center. New players spawn here until they pick a race.
MapConfig.Lobby = { Position = Vector3.new(0, 420, 0), Size = Vector3.new(80, 4, 80) }

MapConfig.SectorAngle = (2 * math.pi) / #RaceConfig.Races

function MapConfig.SectorCenterAngle(index: number): number
	-- First sector points "north" (-Z), remaining go clockwise.
	return -math.pi / 2 + (index - 1) * MapConfig.SectorAngle
end

function MapConfig.PointOnRing(angle: number, radius: number, y: number?): Vector3
	return Vector3.new(math.cos(angle) * radius, y or MapConfig.GroundY, math.sin(angle) * radius)
end

function MapConfig.StartCenter(index: number): Vector3
	return MapConfig.PointOnRing(MapConfig.SectorCenterAngle(index), MapConfig.Start.Center)
end

function MapConfig.MissionCenter(index: number): Vector3
	return MapConfig.PointOnRing(MapConfig.SectorCenterAngle(index), MapConfig.Mission.Center)
end

export type ZoneInfo = { Name: string, Kind: string, Danger: string, Color: Color3 }

-- Returns which zone a world position is in. Used by the client HUD.
function MapConfig.GetZoneAt(position: Vector3): ZoneInfo
	if position.Y > MapConfig.Lobby.Position.Y - 60 then
		return { Name = "Selection Chamber", Kind = "Lobby", Danger = "SAFE", Color = Color3.fromRGB(200, 200, 220) }
	end

	local flat = Vector2.new(position.X, position.Z)
	local dist = flat.Magnitude

	if dist <= MapConfig.Warzone.Radius then
		return { Name = "The Warzone", Kind = "Warzone", Danger = "EXTREME RISK  |  HIGH REWARD", Color = Color3.fromRGB(255, 70, 40) }
	end
	if dist <= MapConfig.Neutral.Outer then
		return { Name = "Neutral Grounds", Kind = "Neutral", Danger = "PVP ENABLED", Color = Color3.fromRGB(220, 200, 120) }
	end

	-- Work out which sector (race wedge) we're in.
	local angle = math.atan2(flat.Y, flat.X)
	local offset = angle - (-math.pi / 2) + MapConfig.SectorAngle / 2
	offset = offset % (2 * math.pi)
	local index = math.floor(offset / MapConfig.SectorAngle) + 1
	index = math.clamp(index, 1, #RaceConfig.Races)
	local race = RaceConfig.Races[index]

	if dist <= MapConfig.Mission.Outer then
		return { Name = race.MissionZone, Kind = "Mission", Danger = race.Plural .. " MISSION ZONE", Color = race.Accent }
	end
	return { Name = race.StartZone, Kind = "Start", Danger = race.Plural .. " TERRITORY  |  SAFE", Color = race.Accent }
end

return MapConfig
