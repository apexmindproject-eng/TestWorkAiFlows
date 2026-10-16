--!strict
-- Builds the world on server start unless it has already been baked into the place file.
local Workspace = game:GetService("Workspace")

local map = Workspace:FindFirstChild("Map")
if map and map:GetAttribute("Built") and #map:GetChildren() > 0 then
	print("[Bootstrap] World already baked into place, skipping build")
	return
end

require(script.Parent.MapBuilder).Build()
