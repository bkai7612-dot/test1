--!strict
--[[
	NameplateController
	Draws nameplates for other players locally (BillboardGuis in PlayerGui):
	display name, cosmetic title, and the round accent (symbol + name, so it
	never relies on colour). Being local lets colourblind mode recolour them
	and darkness shrink their range without touching replicated objects.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local AccentPalette = require(Shared.Data.AccentPalette)
local CosmeticCatalog = require(Shared.Data.CosmeticCatalog)
local Maid = require(Shared.Utility.Maid)

local ClientController = require(script.Parent.ClientController)
local EffectsController = require(script.Parent.EffectsController)
local SettingsController = require(script.Parent.SettingsController)
local Theme = require(script.Parent.Parent.UI.Theme)

local localPlayer = Players.LocalPlayer

local NameplateController = {}

type Plate = { Gui: BillboardGui, Name: TextLabel, Title: TextLabel, Accent: TextLabel, Stroke: UIStroke, Maid: Maid.Maid }

local plates: { [Player]: Plate } = {}
local container: Folder

local function refreshPlate(player: Player)
	local plate = plates[player]
	local character = player.Character
	if not plate or not character then
		return
	end
	plate.Name.Text = player.DisplayName
	local title = character:GetAttribute("VoidlineTitle")
	plate.Title.Text = if type(title) == "string" then title else ""
	plate.Title.Visible = plate.Title.Text ~= ""

	local accentIndex = character:GetAttribute(Constants.Attribute.Accent)
	if type(accentIndex) == "number" then
		plate.Accent.Visible = true
		plate.Accent.Text = AccentPalette.label(accentIndex)
		plate.Accent.TextColor3 = Theme.accentColor(accentIndex)
	else
		plate.Accent.Visible = false
	end

	local plateId = character:GetAttribute("VoidlinePlate")
	local item = if type(plateId) == "string" then CosmeticCatalog.get(plateId) else nil
	local color = if item and item.Color then Color3.fromRGB(item.Color[1], item.Color[2], item.Color[3]) else Theme.Color.Panel
	if item and item.Style == "Edge" then
		plate.Stroke.Color = color
		plate.Stroke.Transparency = 0
	else
		plate.Stroke.Color = Theme.Color.Stroke
		plate.Stroke.Transparency = 0.6
	end
end

local function removePlate(player: Player)
	local plate = plates[player]
	if plate then
		plates[player] = nil
		plate.Maid:Cleanup()
	end
end

local function buildPlate(player: Player, character: Model)
	removePlate(player)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not head or player.Character ~= character then
		return
	end
	local maid = Maid.new()
	local gui = maid:Give(Instance.new("BillboardGui"))
	gui.Name = "Nameplate_" .. player.UserId
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(180, 58)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	gui.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.Color.Panel
	frame.BackgroundTransparency = 0.35
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local function line(order: number, size: number, font: Enum.Font, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -8, 0, size + 2)
		label.Font = font
		label.TextSize = size
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.6
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Parent = frame
		return label
	end
	local nameLabel = line(1, 16, Theme.Font.Bold, Theme.Color.Text)
	local titleLabel = line(2, 12, Theme.Font.Regular, Theme.Color.Muted)
	local accentLabel = line(3, 13, Theme.Font.Bold, Theme.Color.Accent)

	plates[player] = { Gui = gui, Name = nameLabel, Title = titleLabel, Accent = accentLabel, Stroke = stroke, Maid = maid }
	maid:Give(character.AttributeChanged:Connect(function()
		refreshPlate(player)
	end))
	gui.Parent = container
	refreshPlate(player)
end

local function watch(player: Player)
	if player == localPlayer then
		return
	end
	player.CharacterAdded:Connect(function(character)
		buildPlate(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		removePlate(player)
	end)
	if player.Character then
		task.spawn(buildPlate, player, player.Character)
	end
end

function NameplateController.Start()
	container = Instance.new("Folder")
	container.Name = "VoidlineNameplates"
	container.Parent = localPlayer:WaitForChild("PlayerGui")

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(removePlate)

	SettingsController.Changed:Connect(function(key: string, value: any)
		if key == "ColorblindMode" then
			Theme.SetColorblind(value == true)
			for player in plates do
				refreshPlate(player)
			end
		end
	end)

	-- Darkness shrinks how far names can be read (infiltrators see further).
	task.spawn(function()
		while true do
			task.wait(0.5)
			local role = nil
			local distance = 60
			if EffectsController.IsDark() then
				distance = 16
				local clientRole = ClientController.GetPrivate(Constants.PrivateKey.Role)
				role = if type(clientRole) == "table" then clientRole.Faction else nil
				if role == Constants.Faction.Infiltrator then
					distance = 40
				end
			end
			for _, plate in plates do
				plate.Gui.MaxDistance = distance
			end
		end
	end)
end

return NameplateController
