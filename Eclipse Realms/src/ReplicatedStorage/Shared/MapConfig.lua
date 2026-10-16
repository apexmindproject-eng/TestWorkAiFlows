--!strict
-- World layout. Rings around the Warzone at the origin:
--
--   Territory (hub + wilds)  ->  River + bridge  ->  Neutral Grounds  ->  Crater rim  ->  WARZONE
--
-- Each race owns one 72 degree wedge of the outer world. Mountain ridges separate the
-- wedges, so the only ways between races are the Neutral Grounds and the Warzone.

local RaceConfig = require(script.Parent.RaceConfig)

local MapConfig = {}

-- Radii in studs from the world centre
MapConfig.Warzone = { Radius = 260, RimOuter = 310 }
MapConfig.Neutral = { Inner = 310, Outer = 500, RingRoad = 400 }
MapConfig.River = { Inner = 500, Outer = 544, BankOuter = 556, BankInner = 492 }
MapConfig.Territory = { Inner = 556, Outer = 1200, HubRadiusFromCentre = 940, HubRadius = 170 }
MapConfig.WorldRadius = 1250

MapConfig.RoadWidth = 18

-- Hidden chamber new players sit in while they pick a race (camera is elsewhere).
MapConfig.HoldingChamber = { Position = Vector3.new(0, 1600, 0), Size = Vector3.new(40, 16, 40) }

MapConfig.SectorAngle = (2 * math.pi) / #RaceConfig.Races

function MapConfig.SectorCenterAngle(index: number): number
	return -math.pi / 2 + (index - 1) * MapConfig.SectorAngle
end

function MapConfig.PointOnRing(angle: number, radius: number, y: number?): Vector3
	return Vector3.new(math.cos(angle) * radius, y or 0, math.sin(angle) * radius)
end

function MapConfig.HubCenter(index: number): Vector3
	return MapConfig.PointOnRing(MapConfig.SectorCenterAngle(index), MapConfig.Territory.HubRadiusFromCentre)
end

-- Which race's wedge contains this flat position (1..#Races)
function MapConfig.SectorIndexAt(x: number, z: number): number
	local angle = math.atan2(z, x)
	local offset = (angle + math.pi / 2 + MapConfig.SectorAngle / 2) % (2 * math.pi)
	return math.clamp(math.floor(offset / MapConfig.SectorAngle) + 1, 1, #RaceConfig.Races)
end

export type ZoneInfo = { Name: string, Kind: string, Danger: string, Color: Color3 }

function MapConfig.GetZoneAt(position: Vector3): ZoneInfo
	if position.Y > MapConfig.HoldingChamber.Position.Y - 200 then
		return { Name = "", Kind = "Lobby", Danger = "", Color = Color3.new(1, 1, 1) }
	end

	local dist = Vector2.new(position.X, position.Z).Magnitude

	if dist <= MapConfig.Warzone.RimOuter then
		return { Name = "The Warzone", Kind = "Warzone", Danger = "Lawless. Everything is permitted.", Color = Color3.fromRGB(255, 96, 64) }
	end
	if dist <= MapConfig.River.Outer then
		return { Name = "The Neutral Grounds", Kind = "Neutral", Danger = "Contested. Watch your back.", Color = Color3.fromRGB(226, 206, 150) }
	end

	local index = MapConfig.SectorIndexAt(position.X, position.Z)
	local race = RaceConfig.Races[index]
	local hub = MapConfig.HubCenter(index)
	local toHub = (Vector2.new(position.X, position.Z) - Vector2.new(hub.X, hub.Z)).Magnitude

	if toHub <= MapConfig.Territory.HubRadius then
		return { Name = race.StartZone, Kind = "Start", Danger = race.Plural .. " sanctuary", Color = race.Accent }
	end
	return { Name = race.MissionZone, Kind = "Mission", Danger = race.Plural .. " lands. Missions here.", Color = race.Accent }
end

return MapConfig
