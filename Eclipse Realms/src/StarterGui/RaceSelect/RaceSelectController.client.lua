--!strict
-- Race selection: a slow flyover of the world with the five races to choose from along the bottom.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SelectRace = Remotes:WaitForChild("SelectRace") :: RemoteFunction
local RaceAssigned = Remotes:WaitForChild("RaceAssigned") :: RemoteEvent

local player = Players.LocalPlayer
local gui = script.Parent :: ScreenGui

-------------------------------------------------------------------------------
-- Intro camera: orbit high over the world
-------------------------------------------------------------------------------

local orbitConnection: RBXScriptConnection? = nil
local orbitAngle = 0

local function startOrbit()
	if orbitConnection then
		return
	end
	orbitConnection = RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		orbitAngle += dt * 0.045
		local radius = 620
		local height = 260 + math.sin(orbitAngle * 0.7) * 40
		local pos = Vector3.new(math.cos(orbitAngle) * radius, height, math.sin(orbitAngle) * radius)
		camera.CFrame = CFrame.lookAt(pos, Vector3.new(0, 20, 0))
		camera.FieldOfView = 62
	end)
end

local function stopOrbit()
	if orbitConnection then
		orbitConnection:Disconnect()
		orbitConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

-------------------------------------------------------------------------------
-- UI
-------------------------------------------------------------------------------

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Visible = false
root.Parent = gui

-- Dark vignette top and bottom so the world shows through the middle
local topShade = Instance.new("Frame")
topShade.Name = "TopShade"
topShade.Size = UDim2.fromScale(1, 0.3)
topShade.BackgroundColor3 = Color3.fromRGB(6, 5, 10)
topShade.BorderSizePixel = 0
topShade.Parent = root
local topGrad = Instance.new("UIGradient")
topGrad.Rotation = 90
topGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
topGrad.Parent = topShade

local bottomShade = Instance.new("Frame")
bottomShade.Name = "BottomShade"
bottomShade.AnchorPoint = Vector2.new(0, 1)
bottomShade.Position = UDim2.fromScale(0, 1)
bottomShade.Size = UDim2.fromScale(1, 0.62)
bottomShade.BackgroundColor3 = Color3.fromRGB(6, 5, 10)
bottomShade.BorderSizePixel = 0
bottomShade.Parent = root
local bottomGrad = Instance.new("UIGradient")
bottomGrad.Rotation = 90
bottomGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.25), NumberSequenceKeypoint.new(1, 0.05) })
bottomGrad.Parent = bottomShade

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.fromScale(0.5, 0.05)
title.Size = UDim2.fromScale(0.9, 0.09)
title.BackgroundTransparency = 1
title.Text = "ECLIPSE REALMS"
title.Font = Enum.Font.Antique
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(240, 232, 220)
title.TextStrokeTransparency = 0.6
title.Parent = root

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.fromScale(0.5, 0.14)
subtitle.Size = UDim2.fromScale(0.9, 0.035)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Five peoples. One night that never ends. Choose who you were born as."
subtitle.Font = Enum.Font.Garamond
subtitle.TextScaled = true
subtitle.TextColor3 = Color3.fromRGB(200, 190, 185)
subtitle.Parent = root

local cards = Instance.new("Frame")
cards.Name = "Cards"
cards.AnchorPoint = Vector2.new(0.5, 1)
cards.Position = UDim2.fromScale(0.5, 0.96)
cards.Size = UDim2.fromScale(0.94, 0.46)
cards.BackgroundTransparency = 1
cards.Parent = root

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Padding = UDim.new(0.012, 0)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = cards

local cardWidth = (1 - 0.012 * (#RaceConfig.Races - 1)) / #RaceConfig.Races
local busy = false

local function makeText(parent: Instance, name: string, text: string, pos: UDim2, size: UDim2, color: Color3, font: Enum.Font, alignX: Enum.TextXAlignment?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Position = pos
	t.Size = size
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color
	t.Font = font
	t.TextScaled = true
	t.TextWrapped = true
	t.TextXAlignment = alignX or Enum.TextXAlignment.Center
	t.Parent = parent
	return t
end

local function buildCard(index: number, race: RaceConfig.Race)
	local card = Instance.new("Frame")
	card.Name = race.Name .. "Card"
	card.LayoutOrder = index
	card.Size = UDim2.fromScale(cardWidth, 0.92)
	card.BackgroundColor3 = Color3.fromRGB(14, 12, 18)
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.Parent = cards

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = race.Accent
	stroke.Thickness = 1.5
	stroke.Transparency = 0.55
	stroke.Parent = card

	-- Thin accent line at the top
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.Size = UDim2.new(1, 0, 0, 4)
	band.BackgroundColor3 = race.Accent
	band.BorderSizePixel = 0
	band.Parent = card

	makeText(card, "Name", race.Plural:upper(), UDim2.fromScale(0.06, 0.06), UDim2.fromScale(0.88, 0.13), race.Accent, Enum.Font.Antique)
	makeText(card, "Tagline", race.Tagline, UDim2.fromScale(0.06, 0.2), UDim2.fromScale(0.88, 0.065), Color3.fromRGB(225, 220, 215), Enum.Font.Garamond)
	makeText(card, "Description", race.Description, UDim2.fromScale(0.08, 0.29), UDim2.fromScale(0.84, 0.2), Color3.fromRGB(175, 170, 170), Enum.Font.Gotham)

	makeText(card, "PowersHeader", "GIFTS", UDim2.fromScale(0.08, 0.52), UDim2.fromScale(0.84, 0.05), race.Accent, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
	for k, power in race.Powers do
		makeText(card, "Power" .. k, power, UDim2.fromScale(0.08, 0.52 + k * 0.055), UDim2.fromScale(0.84, 0.05), Color3.fromRGB(220, 215, 215), Enum.Font.Gotham, Enum.TextXAlignment.Left)
	end
	makeText(card, "Home", race.StartZone, UDim2.fromScale(0.08, 0.76), UDim2.fromScale(0.84, 0.045), Color3.fromRGB(150, 145, 150), Enum.Font.Garamond, Enum.TextXAlignment.Left)

	local button = Instance.new("TextButton")
	button.Name = "Choose"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.fromScale(0.5, 0.95)
	button.Size = UDim2.fromScale(0.84, 0.1)
	button.BackgroundColor3 = race.Accent
	button.BackgroundTransparency = 0.15
	button.Text = "BECOME " .. race.Name:upper()
	button.TextColor3 = Color3.fromRGB(12, 10, 14)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Parent = card
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button

	local baseSize = card.Size
	card.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.15), { Size = UDim2.fromScale(cardWidth, 1), BackgroundTransparency = 0.05 }):Play()
		stroke.Transparency = 0.1
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.15), { Size = baseSize, BackgroundTransparency = 0.18 }):Play()
		stroke.Transparency = 0.55
	end)

	button.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		button.Text = "..."
		local ok, accepted = pcall(function()
			return SelectRace:InvokeServer(race.Name)
		end)
		if ok and accepted then
			root.Visible = false
			stopOrbit()
		else
			button.Text = "TRY AGAIN"
			busy = false
		end
	end)
end

for i, race in RaceConfig.Races do
	buildCard(i, race)
end

-------------------------------------------------------------------------------
-- Show / hide
-------------------------------------------------------------------------------

local function setVisible(visible: boolean)
	root.Visible = visible
	if visible then
		startOrbit()
	else
		stopOrbit()
	end
end

RaceAssigned.OnClientEvent:Connect(function(raceName: string?)
	setVisible(raceName == nil)
end)

player:GetAttributeChangedSignal("Race"):Connect(function()
	setVisible(player:GetAttribute("Race") == nil)
end)

-- Fallback if the server's event arrived before this script was running.
task.delay(1.5, function()
	if player:GetAttribute("Race") == nil and not root.Visible then
		setVisible(true)
	end
end)
