--!strict
-- Shows which zone the player is standing in (Start / Mission / Neutral / Warzone)
-- and flashes a banner when they cross into a new one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local MapConfig = require(ReplicatedStorage.Shared.MapConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "ZoneHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = playerGui

-- Persistent small badge (top centre)
local badge = Instance.new("Frame")
badge.Name = "Badge"
badge.AnchorPoint = Vector2.new(0.5, 0)
badge.Position = UDim2.new(0.5, 0, 0, 12)
badge.Size = UDim2.fromOffset(320, 44)
badge.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
badge.BackgroundTransparency = 0.35
badge.BorderSizePixel = 0
badge.Parent = gui
local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 10)
badgeCorner.Parent = badge
local badgeStroke = Instance.new("UIStroke")
badgeStroke.Thickness = 2
badgeStroke.Parent = badge

local badgeName = Instance.new("TextLabel")
badgeName.Size = UDim2.new(1, -16, 0.55, 0)
badgeName.Position = UDim2.fromOffset(8, 2)
badgeName.BackgroundTransparency = 1
badgeName.Font = Enum.Font.Antique
badgeName.TextScaled = true
badgeName.TextColor3 = Color3.new(1, 1, 1)
badgeName.Parent = badge

local badgeDanger = Instance.new("TextLabel")
badgeDanger.Size = UDim2.new(1, -16, 0.38, 0)
badgeDanger.Position = UDim2.new(0, 8, 0.58, 0)
badgeDanger.BackgroundTransparency = 1
badgeDanger.Font = Enum.Font.GothamBold
badgeDanger.TextScaled = true
badgeDanger.Parent = badge

-- Big banner that flashes when entering a new zone
local banner = Instance.new("TextLabel")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.3)
banner.Size = UDim2.fromScale(0.8, 0.12)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.Antique
banner.TextScaled = true
banner.TextStrokeTransparency = 0.3
banner.TextTransparency = 1
banner.Parent = gui

local currentZone: string? = nil
local bannerToken = 0

local function showBanner(zone: MapConfig.ZoneInfo)
	bannerToken += 1
	local myToken = bannerToken
	banner.Text = zone.Name:upper()
	banner.TextColor3 = zone.Color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.3
	task.delay(2.2, function()
		if bannerToken == myToken then
			TweenService:Create(banner, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.25 then
		return
	end
	accumulator = 0

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local zone = MapConfig.GetZoneAt(rootPart.Position)
	badgeName.Text = zone.Name
	badgeDanger.Text = zone.Danger
	badgeDanger.TextColor3 = zone.Color
	badgeStroke.Color = zone.Color

	if zone.Name ~= currentZone then
		local first = currentZone == nil
		currentZone = zone.Name
		if not first and zone.Kind ~= "Lobby" then
			showBanner(zone)
		end
	end
end)
