--!strict
-- Shared types for the map builder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)

export type Avoid = { pos: Vector3, r: number }

export type Ctx = {
	index: number,
	race: RaceConfig.Race,
	angle: number, -- world angle of this sector's centre line
	outward: Vector3, -- unit vector from the world centre out through the hub
	toward: Vector3, -- unit vector from the hub toward the warzone
	right: Vector3,
	hub: Vector3, -- centre of the settlement (ground level 0 before plateaus)
	folder: Folder,
	avoid: { Avoid },
	-- hub + toward * forward + right * side
	P: (forward: number, side: number, y: number?) -> Vector3,
	-- point at `radius` from the world centre, `angleOffset` radians off the sector centre line
	ringPoint: (radius: number, angleOffset: number) -> Vector3,
}

return {}
