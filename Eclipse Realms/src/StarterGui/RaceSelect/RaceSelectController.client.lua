--!strict
-- Race selection screen. Builds the UI from RaceConfig so adding a race = adding a table entry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SelectRace = Remotes:WaitForChild("SelectRace") :: RemoteFunction
local RaceAssigned = Remotes:WaitForChild("RaceAssigned") :: RemoteEvent

local player = Players.LocalPlayer
local gui = script.Parent :: ScreenGui

-------------------------------------------------------------------------------
-- Build UI
-------------------------------------------------------------------------------

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
root.BackgroundTransparency = 0.15
root.BorderSizePixel = 0
root.Visible = false
root.Parent = gui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.fromScale(0.5, 0.06)
title.Size = UDim2.fromScale(0.9, 0.1)
title.BackgroundTransparency = 1
title.Text = "ECLIPSE REALMS"
title.Font = Enum.Font.Antique
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(240, 230, 255)
title.TextStrokeTransparency = 0.4
title.Parent = root

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.fromScale(0.5, 0.16)
subtitle.Size = UDim2.fromScale(0.9, 0.045)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Choose your race. This choice is permanent... for now."
subtitle.Font = Enum.Font.Gotham
subtitle.TextScaled = true
subtitle.TextColor3 = Color3.fromRGB(180, 180, 200)
subtitle.Parent = root

local cards = Instance.new("Frame")
cards.Name = "Cards"
cards.AnchorPoint = Vector2.new(0.5, 0.5)
cards.Position = UDim2.fromScale(0.5, 0.58)
cards.Size = UDim2.fromScale(0.94, 0.62)
cards.BackgroundTransparency = 1
cards.Parent = root

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
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
	card.Size = UDim2.fromScale(cardWidth, 1)
	card.BackgroundColor3 = race.Color:Lerp(Color3.new(0, 0, 0), 0.55)
	card.BorderSizePixel = 0
	card.Parent = cards

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = race.Accent
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = card

	-- Colour band at the top
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.Size = UDim2.fromScale(1, 0.22)
	band.BackgroundColor3 = race.Color
	band.BorderSizePixel = 0
	band.Parent = card
	local bandCorner = Instance.new("UICorner")
	bandCorner.CornerRadius = UDim.new(0, 14)
	bandCorner.Parent = band

	local emblem = Instance.new("Frame")
	emblem.Name = "Emblem"
	emblem.AnchorPoint = Vector2.new(0.5, 0.5)
	emblem.Position = UDim2.fromScale(0.5, 0.5)
	emblem.Size = UDim2.fromScale(0.3, 0.55)
	emblem.SizeConstraint = Enum.SizeConstraint.RelativeYY
	emblem.BackgroundColor3 = race.Accent
	emblem.Rotation = 45
	emblem.BorderSizePixel = 0
	emblem.Parent = band
	local emblemCorner = Instance.new("UICorner")
	emblemCorner.CornerRadius = UDim.new(0, 6)
	emblemCorner.Parent = emblem

	makeText(card, "Name", race.Plural:upper(), UDim2.fromScale(0.05, 0.24), UDim2.fromScale(0.9, 0.1), race.Accent, Enum.Font.Antique)
	makeText(card, "Tagline", race.Tagline, UDim2.fromScale(0.05, 0.345), UDim2.fromScale(0.9, 0.05), Color3.fromRGB(220, 220, 230), Enum.Font.GothamMedium)
	makeText(card, "Description", race.Description, UDim2.fromScale(0.07, 0.41), UDim2.fromScale(0.86, 0.17), Color3.fromRGB(190, 190, 205), Enum.Font.Gotham)

	makeText(card, "PowersHeader", "POWERS", UDim2.fromScale(0.07, 0.6), UDim2.fromScale(0.86, 0.045), race.Accent, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
	for k, power in race.Powers do
		makeText(card, "Power" .. k, "•  " .. power, UDim2.fromScale(0.07, 0.6 + k * 0.05), UDim2.fromScale(0.86, 0.045), Color3.fromRGB(230, 230, 240), Enum.Font.Gotham, Enum.TextXAlignment.Left)
	end

	makeText(card, "Home", "Home: " .. race.StartZone, UDim2.fromScale(0.07, 0.815), UDim2.fromScale(0.86, 0.04), Color3.fromRGB(160, 160, 180), Enum.Font.Gotham, Enum.TextXAlignment.Left)

	local button = Instance.new("TextButton")
	button.Name = "Choose"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.fromScale(0.5, 0.96)
	button.Size = UDim2.fromScale(0.86, 0.085)
	button.BackgroundColor3 = race.Accent
	button.Text = "CHOOSE " .. race.Name:upper()
	button.TextColor3 = Color3.fromRGB(15, 10, 20)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Parent = card
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 10)
	buttonCorner.Parent = button

	-- Hover lift
	local baseSize = card.Size
	card.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.15), { Size = UDim2.fromScale(cardWidth, 1.04) }):Play()
		stroke.Transparency = 0
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.15), { Size = baseSize }):Play()
		stroke.Transparency = 0.4
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

local function refresh()
	root.Visible = player:GetAttribute("Race") == nil
end

RaceAssigned.OnClientEvent:Connect(function(raceName: string?)
	root.Visible = raceName == nil
end)

player:GetAttributeChangedSignal("Race"):Connect(refresh)

-- If the server already assigned us before this script ran (saved race), stay hidden.
-- Otherwise show after a short grace period in case the RaceAssigned event is late.
task.delay(1.5, function()
	if player:GetAttribute("Race") == nil then
		root.Visible = true
	end
end)
