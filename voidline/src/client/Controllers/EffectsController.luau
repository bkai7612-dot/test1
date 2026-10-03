--!strict
--[[
	EffectsController
	Client-side presentation of ship hazards and cues:
	  * Tracks which ship area the local player is in.
	  * Gravity failure (floaty movement), hull breach (push), fire (slow).
	  * Darkness: local ambient drops; infiltrators keep "MURMUR sight".
	  * Comms jam static, critical-alarm vignette, oxygen blur.
	  * One-shot VFX: station sparks, ghost whispers, siphon/revive flashes.

	All effects respect Reduced effects / Reduced flashing / Effects quality.
	Nothing here is authoritative: hazards themselves live on the server.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local ShipLayout = require(Shared.Data.ShipLayout)
local Signal = require(Shared.Utility.Signal)

local CameraController = require(script.Parent.CameraController)
local ClientController = require(script.Parent.ClientController)
local SettingsController = require(script.Parent.SettingsController)

local localPlayer = Players.LocalPlayer

local EffectsController = {}

-- (areaId: string?)
EffectsController.AreaChanged = Signal.new()

local currentArea: string? = nil
local hazards: { any } = {}
local speedMultiplier = 1
local gui: ScreenGui
local vignette: Frame
local staticLabel: TextLabel
local flash: Frame
local blur: BlurEffect
local murmurLight: PointLight? = nil
local gravityForce: VectorForce? = nil
local pushForce: VectorForce? = nil
local baseAmbient = Lighting.Ambient
local baseOutdoor = Lighting.OutdoorAmbient
local darkApplied = false

local function isInfiltrator(): boolean
	local role = ClientController.GetPrivate(Constants.PrivateKey.Role)
	return type(role) == "table" and role.Faction == Constants.Faction.Infiltrator
end

local function hazardActive(kind: string, target: string?): boolean
	for _, hazard in hazards do
		if hazard.Kind == kind and (target == nil or hazard.Target == target) then
			return true
		end
	end
	return false
end

local function getRoot(): BasePart?
	local character = localPlayer.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function quality(): string
	if SettingsController.Get("ReducedEffects") then
		return "Low"
	end
	return SettingsController.Get("EffectsQuality")
end

---------------------------------------------------------------------------
-- Queries used by other controllers / screens
---------------------------------------------------------------------------

function EffectsController.GetArea(): string?
	return currentArea
end

function EffectsController.GetSpeedMultiplier(): number
	return speedMultiplier
end

function EffectsController.GetHazards(): { any }
	return hazards
end

-- Navigation Error scrambles readouts for the crew (infiltrators see the truth).
function EffectsController.IsNavScrambled(): boolean
	return hazardActive("NavScramble") and not isInfiltrator()
end

function EffectsController.IsSectionJammed(section: string?): boolean
	return section ~= nil and hazardActive("Jam", section)
end

function EffectsController.IsPlayerJammed(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local area = ShipLayout.areaAt(root.Position.X, root.Position.Y, root.Position.Z)
	return EffectsController.IsSectionJammed(ShipLayout.areaSection(area))
end

function EffectsController.IsDark(): boolean
	if hazardActive("Blackout") then
		return true
	end
	local section = ShipLayout.areaSection(currentArea)
	return section ~= nil and hazardActive("Darkness", section)
end

-- Fake room names while navigation is scrambled.
function EffectsController.DisplayArea(areaId: string?): string
	if EffectsController.IsNavScrambled() and areaId then
		local rooms = ShipLayout.Rooms
		local hash = 0
		for i = 1, #areaId do
			hash += string.byte(areaId, i)
		end
		hash += math.floor(os.clock() / 8) -- shifts every few seconds
		return rooms[(hash % #rooms) + 1].Name
	end
	return ShipLayout.areaName(areaId)
end

---------------------------------------------------------------------------
-- Overlay
---------------------------------------------------------------------------

local function buildOverlay()
	gui = Instance.new("ScreenGui")
	gui.Name = "VoidlineEffects"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	gradient.Parent = vignette

	staticLabel = Instance.new("TextLabel")
	staticLabel.Name = "Static"
	staticLabel.Size = UDim2.fromScale(1, 1)
	staticLabel.BackgroundTransparency = 1
	staticLabel.TextTransparency = 1
	staticLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	staticLabel.Font = Enum.Font.Code
	staticLabel.TextSize = 18
	staticLabel.TextWrapped = true
	staticLabel.Parent = gui

	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	blur = Instance.new("BlurEffect")
	blur.Name = "VoidlineBlur"
	blur.Size = 0
	blur.Parent = Lighting
end

local function screenFlash(color: Color3)
	if SettingsController.Get("ReducedFlashing") or SettingsController.Get("ReducedEffects") then
		return
	end
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

---------------------------------------------------------------------------
-- Continuous effects
---------------------------------------------------------------------------

local function setForce(existing: VectorForce?, root: BasePart?, force: Vector3?): VectorForce?
	if not root or not force then
		if existing then
			local attachment = existing.Attachment0
			existing:Destroy()
			if attachment then
				attachment:Destroy()
			end
		end
		return nil
	end
	if existing and existing.Parent then
		existing.Force = force
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "VoidlineForce"
	attachment.Parent = root
	local vf = Instance.new("VectorForce")
	vf.Attachment0 = attachment
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.ApplyAtCenterOfMass = true
	vf.Force = force
	vf.Parent = root
	return vf
end

local staticGlyphs = { "▓", "▒", "░", "#", "%", "*", "/", "\\", "|", "~" }

local function update()
	local root = getRoot()
	local area = if root then ShipLayout.areaAt(root.Position.X, root.Position.Y, root.Position.Z) else nil
	if area ~= currentArea then
		currentArea = area
		EffectsController.AreaChanged:Fire(area)
	end
	local room = ShipLayout.areaRoom(area)
	local section = ShipLayout.areaSection(area)
	local mass = if root then root.AssemblyMass else 0

	-- Gravity failure: cancel most of gravity.
	local floating = room ~= nil and hazardActive("Gravity", room)
	gravityForce = setForce(gravityForce, if floating then root else nil, Vector3.new(0, mass * workspace.Gravity * 0.72, 0))

	-- Hull breach: drag toward the breached (north) wall.
	local breached = room ~= nil and hazardActive("Breach", room)
	if breached and root and room then
		local roomData = ShipLayout.getRoom(room)
		local target = if roomData then Vector3.new(roomData.CenterX, root.Position.Y, roomData.CenterZ - roomData.SizeZ / 2) else root.Position
		local direction = (target - root.Position)
		local push = if direction.Magnitude > 1 then direction.Unit * mass * 35 else Vector3.zero
		pushForce = setForce(pushForce, root, push)
	else
		pushForce = setForce(pushForce, nil, nil)
	end

	-- Fire slows movement.
	speedMultiplier = if room ~= nil and hazardActive("Fire", room) then 0.65 else 1

	-- Darkness / MURMUR sight.
	local dark = EffectsController.IsDark()
	if dark and not darkApplied then
		darkApplied = true
		Lighting.Ambient = baseAmbient:Lerp(Color3.new(0, 0, 0), 0.75)
		Lighting.OutdoorAmbient = baseOutdoor:Lerp(Color3.new(0, 0, 0), 0.75)
	elseif not dark and darkApplied then
		darkApplied = false
		Lighting.Ambient = baseAmbient
		Lighting.OutdoorAmbient = baseOutdoor
	end
	local wantsSight = dark and isInfiltrator() and root ~= nil
	if wantsSight and not murmurLight then
		local light = Instance.new("PointLight")
		light.Name = "MurmurSight"
		light.Range = 28
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(180, 150, 255)
		light.Parent = root
		murmurLight = light
	elseif not wantsSight and murmurLight then
		murmurLight:Destroy()
		murmurLight = nil
	end

	-- Comms jam static.
	local jammed = EffectsController.IsSectionJammed(section)
	if jammed then
		local chars = table.create(240)
		for i = 1, 240 do
			chars[i] = if math.random() < 0.6 then " " else staticGlyphs[math.random(1, #staticGlyphs)]
		end
		staticLabel.Text = table.concat(chars)
		staticLabel.TextTransparency = if quality() == "Low" then 0.9 else 0.75
	else
		staticLabel.TextTransparency = 1
	end

	-- Critical alarm vignette (pulsing, or steady with reduced flashing).
	local critical = hazardActive("Coolant") or hazardActive("Oxygen")
	if critical then
		local pulse = if SettingsController.Get("ReducedFlashing") then 0.75 else 0.6 + 0.25 * math.sin(os.clock() * 4)
		vignette.BackgroundTransparency = pulse
	elseif room ~= nil and hazardActive("Fire", room) then
		vignette.BackgroundColor3 = Color3.fromRGB(255, 120, 40)
		vignette.BackgroundTransparency = 0.7
	else
		vignette.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
		vignette.BackgroundTransparency = 1
	end

	blur.Size = if hazardActive("Oxygen") and quality() ~= "Low" then 6 else 0
end

---------------------------------------------------------------------------
-- One-shot cues
---------------------------------------------------------------------------

local function findAnchor(anchorId: string): BasePart?
	for _, part in CollectionService:GetTagged(Constants.Tag.InteractAnchor) do
		if part:GetAttribute(Constants.Attribute.AnchorId) == anchorId and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function burst(position: Vector3, color: Color3, duration: number, rate: number)
	if quality() == "Low" then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(2, 2, 2)
	part.Position = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.3)
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(4, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = if quality() == "Medium" then rate / 2 else rate
	emitter.Parent = part
	part.Parent = workspace
	task.delay(duration, function()
		emitter.Enabled = false
		task.wait(1)
		part:Destroy()
	end)
end

local function onCue(kind: string, data: { [string]: any })
	if kind == "StationSpark" and type(data.Anchor) == "string" then
		local anchor = findAnchor(data.Anchor)
		if anchor then
			burst(anchor.Position, Color3.fromRGB(255, 230, 140), 0.5, 60)
		end
	elseif kind == "Whisper" and type(data.Room) == "string" then
		local room = ShipLayout.getRoom(data.Room)
		if room then
			burst(Vector3.new(room.CenterX, ShipLayout.FloorY + 4, room.CenterZ), Color3.fromRGB(170, 150, 255), data.Duration or 6, 25)
		end
	elseif kind == "Siphoned" or kind == "Revived" then
		local player = Players:GetPlayerByUserId(data.UserId or 0)
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			burst(root.Position, if kind == "Siphoned" then Color3.fromRGB(150, 110, 255) else Color3.fromRGB(140, 230, 255), 0.4, 80)
		end
	elseif kind == "MeetingCalled" then
		screenFlash(Color3.fromRGB(255, 220, 120))
	elseif kind == "HazardStarted" then
		if data.Critical then
			screenFlash(Color3.fromRGB(255, 60, 60))
			CameraController.Shake(1.2, 0.6)
		elseif data.Kind == "Breach" then
			CameraController.Shake(0.8, 0.5)
		end
	elseif kind == "ExtractionArmed" or kind == "EndgameStarted" then
		CameraController.Shake(1, 0.8)
	end
end

function EffectsController.Init()
	buildOverlay()
end

function EffectsController.Start()
	-- Capture the server-configured lighting as the "normal" baseline.
	baseAmbient = Lighting.Ambient
	baseOutdoor = Lighting.OutdoorAmbient
	ClientController.PublicChanged:Connect(function(key: string, value: any)
		if key == Constants.PublicKey.Hazards then
			hazards = if type(value) == "table" then value else {}
		end
	end)
	hazards = ClientController.GetPublic(Constants.PublicKey.Hazards) or {}
	ClientController.ShipEvent:Connect(onCue)
	localPlayer.CharacterAdded:Connect(function()
		gravityForce = nil
		pushForce = nil
		murmurLight = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.15)
			local ok: boolean, err: any = pcall(update)
			if not ok then
				warn("[EffectsController]", err)
			end
		end
	end)
end

return EffectsController
