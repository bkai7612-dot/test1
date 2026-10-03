--!strict
--[[
	InputController
	Movement (walk/sprint with stamina, hold or toggle) and every bindable
	action, through ContextActionService so keyboard, gamepad and touch all
	work. On touch devices, bound actions get on-screen buttons automatically.

	Speed rules (all client-side presentation; the server sanity-checks speed):
	  frozen (reveal, muster, siphon channel) -> 0
	  sprinting with stamina                  -> SprintSpeed
	  otherwise                               -> WalkSpeed
	  multiplied by hazard slowdowns (fire)
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Signal = require(Shared.Utility.Signal)

local EffectsController = require(script.Parent.EffectsController)
local SettingsController = require(script.Parent.SettingsController)

local localPlayer = Players.LocalPlayer

local InputController = {}

-- (stamina 0..1, sprinting)
InputController.StaminaChanged = Signal.new()

local sprintHeld = false
local sprintToggled = false
local stamina = 1
local exhausted = false
local lastReported = -1

export type ActionSpec = {
	Name: string,
	Title: string,
	Keys: { Enum.KeyCode },
	Touch: boolean,
	Callback: () -> (),
	TouchPosition: UDim2?,
}

local bound: { [string]: ActionSpec } = {}

local function isSprinting(): boolean
	local wants = if SettingsController.Get("ToggleSprint") then sprintToggled else sprintHeld
	return wants and not exhausted
end

local function onSprint(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		sprintHeld = true
		sprintToggled = not sprintToggled
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		sprintHeld = false
	end
	return Enum.ContextActionResult.Pass
end

local function step(dt: number)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local sprinting = isSprinting() and moving
	local movement = Config.Movement
	if sprinting then
		stamina = math.max(0, stamina - dt / movement.StaminaSeconds)
		if stamina <= 0 then
			exhausted = true
			sprintToggled = false
		end
	else
		stamina = math.min(1, stamina + dt * movement.StaminaRegenPerSecond / movement.StaminaSeconds)
		if exhausted and stamina >= 0.3 then
			exhausted = false
		end
	end

	local frozen = character:GetAttribute(Constants.Attribute.Frozen) == true
	local speed = if frozen then 0 elseif sprinting then movement.SprintSpeed else movement.WalkSpeed
	speed *= EffectsController.GetSpeedMultiplier()
	if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
		humanoid.WalkSpeed = speed
	end
	if frozen and humanoid.JumpHeight ~= 0 then
		humanoid.JumpHeight = 0
	elseif not frozen and humanoid.JumpHeight == 0 then
		humanoid.JumpHeight = 6
	end

	local rounded = math.floor(stamina * 50) / 50
	if rounded ~= lastReported then
		lastReported = rounded
		InputController.StaminaChanged:Fire(stamina, sprinting)
	end
end

-- Binds an action for keyboard/gamepad (and a touch button if requested).
function InputController.Bind(spec: ActionSpec)
	InputController.Unbind(spec.Name)
	bound[spec.Name] = spec
	ContextActionService:BindAction(spec.Name, function(_, state)
		if state == Enum.UserInputState.Begin then
			spec.Callback()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, spec.Touch, table.unpack(spec.Keys))
	if spec.Touch then
		ContextActionService:SetTitle(spec.Name, spec.Title)
		if spec.TouchPosition then
			ContextActionService:SetPosition(spec.Name, spec.TouchPosition)
		end
	end
end

function InputController.Unbind(name: string)
	if bound[name] then
		bound[name] = nil
		ContextActionService:UnbindAction(name)
	end
end

function InputController.IsBound(name: string): boolean
	return bound[name] ~= nil
end

function InputController.GetStamina(): number
	return stamina
end

function InputController.Start()
	ContextActionService:BindAction("VoidlineSprint", onSprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("VoidlineSprint", "Sprint")
	ContextActionService:SetPosition("VoidlineSprint", UDim2.new(1, -170, 1, -170))
	RunService.Heartbeat:Connect(step)
end

return InputController
