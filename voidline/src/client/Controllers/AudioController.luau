--!strict
--[[
	AudioController
	Sound groups (Master/Music/Effects/Ambient/UI) driven by settings, a tiny
	pool of reusable Sound instances for one-shots, ambience per round state,
	and captions for every captioned cue (shown even when a sound has no
	asset yet).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioCatalog = require(Shared.Data.AudioCatalog)
local Signal = require(Shared.Utility.Signal)

local ClientController = require(script.Parent.ClientController)
local SettingsController = require(script.Parent.SettingsController)

local AudioController = {}

-- (caption: string) for the subtitle feed
AudioController.Captioned = Signal.new()

local groups: { [string]: SoundGroup } = {}
local master: SoundGroup = Instance.new("SoundGroup")
local loops: { [string]: Sound } = {}
local pool: { Sound } = {}
local POOL_SIZE = 8
local poolIndex = 0

local function makeGroup(name: string, parent: Instance): SoundGroup
	local group = Instance.new("SoundGroup")
	group.Name = "Voidline" .. name
	group.Parent = parent
	return group
end

local function applyVolumes()
	master.Volume = SettingsController.Get("MasterVolume")
	groups.Music.Volume = SettingsController.Get("MusicVolume")
	groups.Effects.Volume = SettingsController.Get("EffectsVolume")
	groups.Ambient.Volume = SettingsController.Get("EffectsVolume") * 0.8
	groups.UI.Volume = SettingsController.Get("EffectsVolume")
end

local function caption(id: string)
	local sound = AudioCatalog.get(id)
	if sound and sound.Caption and SettingsController.Get("Subtitles") then
		AudioController.Captioned:Fire(sound.Caption)
	end
end

-- Plays a one-shot. `position` makes it 3D (attached to a temporary part).
function AudioController.Play(id: string, position: Vector3?)
	local definition = AudioCatalog.get(id)
	if not definition then
		return
	end
	caption(id)
	if definition.AssetId == "" then
		return
	end
	if position then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Position = position
		holder.Parent = workspace
		local sound = Instance.new("Sound")
		sound.SoundId = definition.AssetId
		sound.Volume = definition.Volume
		sound.SoundGroup = groups[definition.Group]
		sound.RollOffMaxDistance = 80
		sound.Parent = holder
		sound:Play()
		task.delay(10, function()
			holder:Destroy()
		end)
		return
	end
	poolIndex = poolIndex % POOL_SIZE + 1
	local sound = pool[poolIndex]
	sound.SoundId = definition.AssetId
	sound.Volume = definition.Volume
	sound.SoundGroup = groups[definition.Group]
	sound.TimePosition = 0
	sound:Play()
end

-- Starts/stops a looping sound by id.
function AudioController.SetLoop(id: string, playing: boolean)
	local definition = AudioCatalog.get(id)
	if not definition or definition.AssetId == "" then
		return
	end
	local sound = loops[id]
	if playing then
		if not sound then
			local created = Instance.new("Sound")
			created.Name = id
			created.SoundId = definition.AssetId
			created.Looped = true
			created.Volume = definition.Volume
			created.SoundGroup = groups[definition.Group]
			created.Parent = SoundService
			loops[id] = created
			sound = created
		end
		if not (sound :: Sound).IsPlaying then
			(sound :: Sound):Play()
		end
	elseif sound then
		sound:Stop()
	end
end

local function updateAmbience(state: string)
	local inShip = state ~= "LOBBY" and state ~= "RESET"
	AudioController.SetLoop("AmbientShip", inShip and state ~= "RESULTS")
	AudioController.SetLoop("AmbientLobby", not inShip)
	AudioController.SetLoop("MusicEndgame", state == "ENDGAME")
end

local CUE_SOUNDS: { [string]: string } = {
	StationSpark = "Sparks",
	Siphoned = "Siphon",
	Revived = "Revive",
	Whisper = "Whisper",
	Announcement = "Announcement",
	MeetingCalled = "MeetingCalled",
	ExtractionArmed = "Extraction",
	StepComplete = "StepComplete",
	InteractRejected = "TaskFail",
}

function AudioController.Init()
	master.Name = "VoidlineMaster"
	master.Parent = SoundService
	for _, name in { "Music", "Effects", "Ambient", "UI" } do
		groups[name] = makeGroup(name, master)
	end
	for i = 1, POOL_SIZE do
		local sound = Instance.new("Sound")
		sound.Name = "OneShot" .. i
		sound.Parent = SoundService
		pool[i] = sound
	end
	applyVolumes()
end

function AudioController.Start()
	SettingsController.Changed:Connect(function(key: string)
		if string.find(key, "Volume") then
			applyVolumes()
		end
	end)
	ClientController.PublicChanged:Connect(function(key: string, value: any)
		if key == "RoundState" and type(value) == "string" then
			updateAmbience(value)
		end
	end)
	ClientController.ShipEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "HazardStarted" then
			AudioController.Play(if data.Critical then "CriticalAlarm" else "Alarm")
			return
		end
		local id = CUE_SOUNDS[kind]
		if id then
			AudioController.Play(id)
		end
	end)
	updateAmbience(ClientController.GetRoundState())
end

return AudioController
