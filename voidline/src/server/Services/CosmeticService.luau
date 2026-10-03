--!strict
--[[
	CosmeticService
	Applies equipped cosmetics to characters. All cosmetics are built from
	simple parts in code (no external assets) and are purely decorative:
	massless, non-colliding and ignored by raycasts.

	Nameplates are drawn by each client (so colourblind mode and darkness can
	adjust them locally); the server only publishes character attributes:
	  VoidlineTitle, VoidlinePlate, VoidlineAccent (round accent, gameplay clue)
	The accent armband is added during rounds and is never affected by
	cosmetics.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local AccentPalette = require(Shared.Data.AccentPalette)
local CosmeticCatalog = require(Shared.Data.CosmeticCatalog)

local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)
local RoleService = require(script.Parent.RoleService)

local CosmeticService = {}

local FOLDER_NAME = "VoidlineCosmetics"

local function rgb(values: { number }?): Color3
	if not values then
		return Color3.new(1, 1, 1)
	end
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function findPart(character: Model, ...: string): BasePart?
	for i = 1, select("#", ...) do
		local part = character:FindFirstChild((select(i, ...)))
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function attach(folder: Instance, base: BasePart, props: { [string]: any }, offset: CFrame): BasePart
	local part = Instance.new(props.ClassName or "Part") :: BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" then
			(part :: any)[key] = value
		end
	end
	part.CFrame = base.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

local function buildSuit(folder: Instance, character: Model, item: CosmeticCatalog.Item)
	local torso = findPart(character, "UpperTorso", "Torso")
	if not torso then
		return
	end
	local size = torso.Size
	attach(folder, torso, {
		Name = "SuitVest",
		Size = Vector3.new(size.X + 0.12, size.Y * 0.85, size.Z + 0.14),
		Color = rgb(item.Color),
		Material = Enum.Material.Fabric,
	}, CFrame.new(0, -size.Y * 0.05, 0))
	-- Chest stripe (neon for "Glow" suits).
	attach(folder, torso, {
		Name = "SuitStripe",
		Size = Vector3.new(size.X + 0.16, 0.18, size.Z + 0.18),
		Color = if item.Style == "Glow" then rgb(item.Color):Lerp(Color3.new(1, 1, 1), 0.4) else Color3.fromRGB(40, 44, 52),
		Material = if item.Style == "Glow" then Enum.Material.Neon else Enum.Material.SmoothPlastic,
	}, CFrame.new(0, size.Y * 0.18, 0))
end

local function buildHelmet(folder: Instance, character: Model, item: CosmeticCatalog.Item)
	local head = findPart(character, "Head")
	if not head or not item.Style then
		return
	end
	local color = rgb(item.Color)
	if item.Style == "Visor" then
		attach(folder, head, {
			Name = "Visor",
			Size = Vector3.new(head.Size.X + 0.1, 0.3, head.Size.Z * 0.6),
			Color = color,
			Material = Enum.Material.Neon,
		}, CFrame.new(0, 0.15, -head.Size.Z * 0.25))
	elseif item.Style == "Dome" then
		attach(folder, head, {
			Name = "Dome",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1) * (math.max(head.Size.X, head.Size.Y, head.Size.Z) + 0.9),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.6,
		}, CFrame.new(0, 0.1, 0))
	elseif item.Style == "Hood" then
		attach(folder, head, {
			Name = "Hood",
			Size = Vector3.new(head.Size.X + 0.25, head.Size.Y * 0.55, head.Size.Z + 0.25),
			Color = color,
			Material = Enum.Material.Fabric,
		}, CFrame.new(0, head.Size.Y * 0.35, 0.05))
	elseif item.Style == "Halo" then
		attach(folder, head, {
			Name = "Halo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 1.8, 1.8),
			Color = color,
			Material = Enum.Material.Neon,
		}, CFrame.new(0, head.Size.Y * 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)))
	end
end

local function buildGloves(folder: Instance, character: Model, item: CosmeticCatalog.Item)
	if not item.Color then
		return
	end
	for _, names in { { "LeftHand", "Left Arm" }, { "RightHand", "Right Arm" } } do
		local hand = findPart(character, names[1], names[2])
		if hand then
			local isArm = hand.Name == names[2]
			local size = if isArm then Vector3.new(hand.Size.X + 0.1, 0.6, hand.Size.Z + 0.1) else hand.Size + Vector3.new(0.12, 0.08, 0.12)
			attach(folder, hand, {
				Name = "Glove",
				Size = size,
				Color = rgb(item.Color),
				Material = if item.Style == "Metal" then Enum.Material.Metal else Enum.Material.Fabric,
				Reflectance = if item.Style == "Metal" then 0.3 else 0,
			}, if isArm then CFrame.new(0, -hand.Size.Y / 2 + 0.3, 0) else CFrame.new())
		end
	end
end

local function buildBack(folder: Instance, character: Model, item: CosmeticCatalog.Item)
	local torso = findPart(character, "UpperTorso", "Torso")
	if not torso or not item.Style then
		return
	end
	local color = rgb(item.Color)
	local back = torso.Size.Z / 2
	if item.Style == "Tanks" then
		for _, x in { -0.35, 0.35 } do
			attach(folder, torso, {
				Name = "Tank",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.4, 0.55, 0.55),
				Color = color,
				Material = Enum.Material.Metal,
			}, CFrame.new(x, 0, back + 0.3) * CFrame.Angles(0, 0, math.rad(90)))
		end
	elseif item.Style == "Rack" then
		attach(folder, torso, {
			Name = "ToolRack",
			Size = Vector3.new(1.4, 1.4, 0.5),
			Color = color,
			Material = Enum.Material.Metal,
		}, CFrame.new(0, 0, back + 0.25))
	elseif item.Style == "Antenna" then
		attach(folder, torso, {
			Name = "AntennaBase",
			Size = Vector3.new(0.8, 0.8, 0.4),
			Color = color,
			Material = Enum.Material.Metal,
		}, CFrame.new(0.4, 0.2, back + 0.2))
		attach(folder, torso, {
			Name = "AntennaRod",
			Size = Vector3.new(0.1, 2.6, 0.1),
			Color = color,
			Material = Enum.Material.Metal,
		}, CFrame.new(0.55, 1.6, back + 0.25))
	elseif item.Style == "Drone" then
		attach(folder, torso, {
			Name = "Drone",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.8, 0.8, 0.8),
			Color = color,
			Material = Enum.Material.Neon,
		}, CFrame.new(1.4, 1.5, back))
	end
end

local function buildAccentBand(folder: Instance, character: Model, accentIndex: number)
	local arm = findPart(character, "LeftUpperArm", "Left Arm")
	local accent = AccentPalette.get(accentIndex)
	if not arm or not accent then
		return
	end
	attach(folder, arm, {
		Name = "AccentBand",
		Size = Vector3.new(arm.Size.X + 0.14, 0.35, arm.Size.Z + 0.14),
		Color = rgb(accent.Color),
		Material = Enum.Material.Neon,
	}, CFrame.new(0, if arm.Name == "Left Arm" then 0.5 else 0, 0))
end

-- Rebuilds every cosmetic on `player`'s current character.
function CosmeticService.Apply(player: Player)
	local character = player.Character
	if not character or not character.Parent then
		return
	end
	local existing = character:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	local profile = DataService.GetProfile(player)
	local equipped = if profile then profile.Equipped else CosmeticCatalog.DefaultEquipped
	local function item(slot: string): CosmeticCatalog.Item?
		return CosmeticCatalog.get(equipped[slot] or CosmeticCatalog.DefaultEquipped[slot])
	end

	local suit = item("Suit")
	if suit then
		buildSuit(folder, character, suit)
	end
	local helmet = item("Helmet")
	if helmet then
		buildHelmet(folder, character, helmet)
	end
	local gloves = item("Gloves")
	if gloves then
		buildGloves(folder, character, gloves)
	end
	local back = item("Back")
	if back then
		buildBack(folder, character, back)
	end

	local p = MatchService.GetParticipant(player)
	if p and p.Faction then
		buildAccentBand(folder, character, p.Accent)
		character:SetAttribute(Constants.Attribute.Accent, p.Accent)
	else
		character:SetAttribute(Constants.Attribute.Accent, nil)
	end

	local title = item("Title")
	local plate = item("Nameplate")
	character:SetAttribute("VoidlineTitle", if title then title.Name else "")
	character:SetAttribute("VoidlinePlate", if plate then plate.Id else "plate_basic")
	folder.Parent = character
end

function CosmeticService.ApplyAll()
	for _, player in Players:GetPlayers() do
		task.spawn(CosmeticService.Apply, player)
	end
end

function CosmeticService.Start()
	CharacterService.CharacterSpawned:Connect(function(player: Player)
		-- Wait a beat for the avatar's appearance to finish loading.
		task.delay(0.5, CosmeticService.Apply, player)
	end)
	DataService.ProfileLoaded:Connect(function(player: Player)
		CosmeticService.Apply(player)
	end)
	RoleService.Assigned:Connect(CosmeticService.ApplyAll)
end

return CosmeticService
