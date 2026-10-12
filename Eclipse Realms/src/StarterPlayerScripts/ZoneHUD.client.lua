--!strict
-- Quiet region text when you cross into a new area, like an open-world RPG.

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

local banner = Instance.new("TextLabel")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.22)
banner.Size = UDim2.fromScale(0.8, 0.075)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.Antique
banner.TextScaled = true
banner.TextStrokeTransparency = 0.5
banner.TextTransparency = 1
banner.Parent = gui

local sub = Instance.new("TextLabel")
sub.Name = "Sub"
sub.AnchorPoint = Vector2.new(0.5, 0.5)
sub.Position = UDim2.fromScale(0.5, 0.275)
sub.Size = UDim2.fromScale(0.8, 0.028)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.Garamond
sub.TextScaled = true
sub.TextColor3 = Color3.fromRGB(220, 215, 210)
sub.TextStrokeTransparency = 0.6
sub.TextTransparency = 1
sub.Parent = gui

local line = Instance.new("Frame")
line.Name = "Line"
line.AnchorPoint = Vector2.new(0.5, 0.5)
line.Position = UDim2.fromScale(0.5, 0.255)
line.Size = UDim2.new(0, 0, 0, 1)
line.BorderSizePixel = 0
line.BackgroundTransparency = 1
line.Parent = gui

local currentZone: string? = nil
local token = 0

local function showBanner(zone: MapConfig.ZoneInfo)
	token += 1
	local myToken = token
	banner.Text = zone.Name
	banner.TextColor3 = zone.Color
	sub.Text = zone.Danger
	line.BackgroundColor3 = zone.Color

	banner.TextTransparency = 1
	sub.TextTransparency = 1
	line.Size = UDim2.new(0, 0, 0, 1)
	line.BackgroundTransparency = 0.2
	TweenService:Create(banner, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	TweenService:Create(sub, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0.3), { TextTransparency = 0 }):Play()
	TweenService:Create(line, TweenInfo.new(1.2, Enum.EasingStyle.Quart), { Size = UDim2.new(0.22, 0, 0, 1) }):Play()

	task.delay(3.4, function()
		if token == myToken then
			TweenService:Create(banner, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			TweenService:Create(sub, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
			TweenService:Create(line, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		end
	end)
end

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.3 then
		return
	end
	accumulator = 0

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local zone = MapConfig.GetZoneAt(rootPart.Position)
	if zone.Name ~= currentZone then
		local first = currentZone == nil
		currentZone = zone.Name
		if zone.Kind ~= "Lobby" and (not first or player:GetAttribute("Race") ~= nil) then
			showBanner(zone)
		end
	end
end)
