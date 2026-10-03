--!strict
--[[
	CameraController
	Field of view from settings, optional camera shake (off with the
	"Camera shake" or "Reduced effects" settings), and spectating for Signal
	Ghosts and players waiting for the next round.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Signal = require(Shared.Utility.Signal)

local ClientController = require(script.Parent.ClientController)
local SettingsController = require(script.Parent.SettingsController)

local localPlayer = Players.LocalPlayer

local CameraController = {}

-- (targetName: string?) spectate target changed
CameraController.SpectateChanged = Signal.new()

local spectating = false
local targetIndex = 1
local currentTarget: Player? = nil
local shakeUntil = 0
local shakeStrength = 0

local function camera(): Camera
	return workspace.CurrentCamera
end

local function applyFov()
	camera().FieldOfView = SettingsController.Get("FieldOfView")
end

-- Living participants (from the public roster) that currently have a character.
local function targets(): { Player }
	local list = {}
	local roster = ClientController.GetPublic(Constants.PublicKey.Roster)
	if type(roster) == "table" then
		for _, entry in roster do
			local player = Players:GetPlayerByUserId(entry.UserId)
			if player and player ~= localPlayer and player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
				table.insert(list, player)
			end
		end
	end
	return list
end

local function focus(player: Player?)
	currentTarget = player
	local humanoid = if player and player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		camera().CameraSubject = humanoid
	end
	CameraController.SpectateChanged:Fire(if player then player.DisplayName else nil)
end

function CameraController.StartSpectating()
	spectating = true
	local list = targets()
	targetIndex = math.clamp(targetIndex, 1, math.max(#list, 1))
	focus(list[targetIndex])
end

function CameraController.StopSpectating()
	if not spectating then
		return
	end
	spectating = false
	currentTarget = nil
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera().CameraSubject = humanoid
	end
	CameraController.SpectateChanged:Fire(nil)
end

function CameraController.Cycle(direction: number)
	local list = targets()
	if #list == 0 then
		focus(nil)
		return
	end
	targetIndex = ((targetIndex - 1 + direction) % #list) + 1
	focus(list[targetIndex])
end

function CameraController.IsSpectating(): boolean
	return spectating
end

function CameraController.GetTargetName(): string?
	return if currentTarget then currentTarget.DisplayName else nil
end

function CameraController.Shake(strength: number, duration: number)
	if not SettingsController.Get("CameraShake") or SettingsController.Get("ReducedEffects") then
		return
	end
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
	RunService:BindToRenderStep("VoidlineShake", Enum.RenderPriority.Camera.Value + 1, function()
		local remaining = shakeUntil - os.clock()
		if remaining <= 0 then
			shakeStrength = 0
			RunService:UnbindFromRenderStep("VoidlineShake")
			return
		end
		local s = shakeStrength * math.min(1, remaining)
		local cam = camera()
		cam.CFrame = cam.CFrame * CFrame.Angles(
			math.rad((math.random() - 0.5) * s),
			math.rad((math.random() - 0.5) * s),
			0
		)
	end)
end

local function evaluate()
	local life = ClientController.GetPrivate(Constants.PrivateKey.Life)
	local state = ClientController.GetRoundState()
	local isGhost = life == Constants.LifeState.Lost or life == Constants.LifeState.Confined
	if isGhost and state ~= Constants.RoundState.Lobby then
		if not spectating then
			CameraController.StartSpectating()
		end
	elseif spectating and (state == Constants.RoundState.Lobby or state == Constants.RoundState.Reset) then
		CameraController.StopSpectating()
	end
	-- Retarget if the watched player lost their character.
	if spectating and (not currentTarget or not currentTarget.Character) then
		CameraController.Cycle(0)
	end
end

function CameraController.Start()
	applyFov()
	SettingsController.Changed:Connect(function(key: string)
		if key == "FieldOfView" then
			applyFov()
		end
	end)
	ClientController.PrivateChanged:Connect(evaluate)
	ClientController.PublicChanged:Connect(function(key: string)
		if key == Constants.PublicKey.RoundState or key == Constants.PublicKey.Roster then
			evaluate()
		end
	end)
	localPlayer.CharacterAdded:Connect(function()
		task.defer(applyFov)
		if spectating and ClientController.GetRoundState() == Constants.RoundState.Lobby then
			CameraController.StopSpectating()
		end
	end)
end

return CameraController
