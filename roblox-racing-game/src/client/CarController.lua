-- Client-side arcade car physics (raycast suspension), input and chase
-- camera. The server gives the driver network ownership of the car, so
-- all forces applied here replicate to everyone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local SUSP = Config.Suspension
local WHEEL_NAMES = { "FL", "FR", "RL", "RR" }

local CarController = {}
CarController.Touch = { gas = false, brake = false, left = false, right = false, boost = false, drift = false }
CarController.OnTelemetry = nil -- function(speedStudsPerSec, topSpeed, nitroFraction, boosting)

local active = nil

local function buildRayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local list = {}
	for _, name in { "Lobby", "ActiveTrack" } do
		local inst = workspace:FindFirstChild(name)
		if inst then
			table.insert(list, inst)
		end
	end
	params.FilterDescendantsInstances = list
	return params
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
local function keyDown(...)
	for _, key in { ... } do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function readInput()
	local throttle, steer = 0, 0
	local handbrake, boost = false, false
	if not UserInputService:GetFocusedTextBox() then
		if keyDown(Enum.KeyCode.W, Enum.KeyCode.Up) then
			throttle += 1
		end
		if keyDown(Enum.KeyCode.S, Enum.KeyCode.Down) then
			throttle -= 1
		end
		if keyDown(Enum.KeyCode.A, Enum.KeyCode.Left) then
			steer -= 1
		end
		if keyDown(Enum.KeyCode.D, Enum.KeyCode.Right) then
			steer += 1
		end
		handbrake = keyDown(Enum.KeyCode.Space)
		boost = keyDown(Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
	end

	if UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
		for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if input.KeyCode == Enum.KeyCode.ButtonR2 then
				throttle += input.Position.Z
			elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
				throttle -= input.Position.Z
			elseif input.KeyCode == Enum.KeyCode.Thumbstick1 and math.abs(input.Position.X) > 0.15 then
				steer += input.Position.X
			end
		end
		handbrake = handbrake or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonX)
		boost = boost or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
	end

	local t = CarController.Touch
	if t.gas then
		throttle += 1
	end
	if t.brake then
		throttle -= 1
	end
	if t.left then
		steer -= 1
	end
	if t.right then
		steer += 1
	end
	handbrake = handbrake or t.drift
	boost = boost or t.boost

	return math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1), handbrake, boost
end

---------------------------------------------------------------------------
-- Physics
---------------------------------------------------------------------------
local function setFlames(a, on)
	if a.flamesOn == on then
		return
	end
	a.flamesOn = on
	for _, emitter in a.flames do
		emitter.Enabled = on
	end
end

local function flipUpright(a)
	local cf = a.chassis.CFrame
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	local pos = cf.Position + Vector3.new(0, 4, 0)
	a.model:PivotTo(CFrame.lookAt(pos, pos + flat.Unit))
	a.chassis.AssemblyLinearVelocity = Vector3.zero
	a.chassis.AssemblyAngularVelocity = Vector3.zero
end

local function updateWheels(a, dt, fwdSpeed)
	for _, w in a.wheels do
		w.visual += (w.length - w.visual) * math.min(dt * 20, 1)
		w.spin = (w.spin - fwdSpeed / w.radius * dt) % (math.pi * 2)
		local steerAngle = w.front and (-a.steer * 0.45) or 0
		w.weld.C0 = CFrame.new(w.mount.X, w.mount.Y - w.visual, w.mount.Z)
			* CFrame.Angles(0, steerAngle, 0)
			* CFrame.Angles(w.spin, 0, 0)
	end
end

local function physicsStep(dt)
	local a = active
	if not a or not a.chassis.Parent then
		return
	end
	local chassis = a.chassis
	dt = math.min(dt, 1 / 30)

	local throttle, steerInput, handbrake, boostHeld = readInput()
	a.steer += (steerInput - a.steer) * math.min(dt * 6, 1)

	if chassis.Anchored then
		updateWheels(a, dt, 0)
		return
	end

	local stats = a.stats
	local cf = chassis.CFrame
	local up, fwd, right = cf.UpVector, cf.LookVector, cf.RightVector
	local vel = chassis.AssemblyLinearVelocity
	local mass = chassis.AssemblyMass
	local g = workspace.Gravity

	-- Suspension -------------------------------------------------------------
	local rest = SUSP.restLength
	local k = (mass * g / 4) / (rest * SUSP.sag)
	local c = 2 * math.sqrt(k * mass / 4) * SUSP.dampingRatio
	local grounded = 0
	for _, w in a.wheels do
		local origin = cf:PointToWorldSpace(w.mount)
		local result = workspace:Raycast(origin, -up * (rest + w.radius), a.rayParams)
		if result then
			local length = math.max(result.Distance - w.radius, 0)
			local compression = rest - length
			local pointVel = chassis:GetVelocityAtPosition(origin)
			local force = k * compression - c * pointVel:Dot(up)
			if force > 0 then
				chassis:ApplyImpulseAtPosition(up * force * dt, origin)
			end
			w.length = length
			grounded += 1
		else
			w.length = rest
		end
	end

	-- Drive ------------------------------------------------------------------
	local fwdSpeed = vel:Dot(fwd)
	local latSpeed = vel:Dot(right)
	local boosting = boostHeld and a.nitro > 0
	if boosting then
		a.nitro = math.max(0, a.nitro - dt)
	else
		a.nitro = math.min(stats.nitro, a.nitro + dt * 0.06)
	end

	if grounded > 0 then
		local traction = grounded / 4
		local top = stats.topSpeed * (boosting and 1.25 or 1)
		if boosting then
			throttle = 1
		end

		local accel
		if throttle > 0.05 then
			if fwdSpeed < -3 then
				accel = stats.brake * throttle
			else
				local ratio = math.clamp(fwdSpeed / top, 0, 1)
				accel = stats.accel * (boosting and stats.nitroPower or 1) * throttle * (1 - ratio * ratio)
			end
		elseif throttle < -0.05 then
			if fwdSpeed > 3 then
				accel = -stats.brake * -throttle
			else
				local ratio = math.clamp(-fwdSpeed / (top * 0.35), 0, 1)
				accel = -stats.accel * 0.6 * -throttle * (1 - ratio)
			end
		else
			accel = -fwdSpeed * 0.35
		end
		if fwdSpeed > top then
			accel -= (fwdSpeed - top) * 1.5
		end
		if handbrake and math.abs(fwdSpeed) > 0.5 then
			accel -= math.sign(fwdSpeed) * math.min(math.abs(fwdSpeed) / dt, stats.brake * 0.35)
		end

		local gripRate = stats.grip * (handbrake and 0.18 or 1)
		local impulse = fwd * accel * mass * dt * traction
		impulse += right * (-latSpeed * math.min(gripRate * dt, 1)) * mass * traction
		chassis:ApplyImpulse(impulse)

		-- Steering: drive the yaw rate directly for a tight arcade feel.
		local speedAbs = math.abs(fwdSpeed)
		local speedFactor = math.clamp(speedAbs / 18, 0, 1)
		local highSpeed = 1 - 0.3 * math.clamp(speedAbs / stats.topSpeed, 0, 1)
		local dir = fwdSpeed >= 0 and 1 or -1
		local targetYaw = -a.steer * stats.handling * speedFactor * highSpeed * dir * (handbrake and 1.35 or 1)
		local angVel = chassis.AssemblyAngularVelocity
		local yaw = angVel:Dot(up)
		local newYaw = yaw + (targetYaw - yaw) * math.min(dt * 7 * traction, 1)
		local other = (angVel - up * yaw) * (1 - math.min(dt * 2, 1))
		chassis.AssemblyAngularVelocity = other + up * newYaw

		-- Drifting refills nitro.
		if handbrake and math.abs(latSpeed) > 12 and speedAbs > 20 then
			a.nitro = math.min(stats.nitro, a.nitro + dt * 0.35)
		end
	else
		-- Airborne: a bit of extra gravity and angular damping.
		chassis:ApplyImpulse(Vector3.new(0, -g * 0.35 * mass * dt, 0))
		chassis.AssemblyAngularVelocity *= (1 - math.min(dt * 1.5, 1))
	end

	a.boosting = boosting
	setFlames(a, boosting)
	updateWheels(a, dt, fwdSpeed)

	if a.engineSound then
		local ratio = math.clamp(math.abs(fwdSpeed) / stats.topSpeed, 0, 1.3)
		a.engineSound.PlaybackSpeed = 0.7 + ratio * 1.1
	end

	-- Recovery: fell off the world or stuck upside down.
	if cf.Position.Y < a.killY then
		CarController.Respawn()
	end
	if up.Y < 0.3 and vel.Magnitude < 15 then
		a.flipTimer += dt
		if a.flipTimer > 2 then
			a.flipTimer = 0
			flipUpright(a)
		end
	else
		a.flipTimer = 0
	end

	if CarController.OnTelemetry then
		CarController.OnTelemetry(fwdSpeed, stats.topSpeed, a.nitro / stats.nitro, boosting)
	end
end

---------------------------------------------------------------------------
-- Camera
---------------------------------------------------------------------------
local function cameraStep(dt)
	local a = active
	if not a or not a.chassis.Parent then
		return
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local chassis = a.chassis
	local look = chassis.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.2 and flat.Unit or a.camDir
	if keyDown(Enum.KeyCode.C) then
		flat = -flat
	end
	a.camDir = a.camDir:Lerp(flat, math.min(dt * 4, 1))
	if a.camDir.Magnitude < 0.05 then
		a.camDir = flat
	end
	a.camDir = a.camDir.Unit

	local vel = chassis.AssemblyLinearVelocity
	local dist = (a.camFar and 26 or 17) + math.min(vel.Magnitude * 0.03, 6)
	local height = a.camFar and 9 or 6
	local focus = chassis.Position + Vector3.new(0, 3, 0)
	local desired = focus - a.camDir * dist + Vector3.new(0, height, 0)
	local hit = workspace:Raycast(focus, desired - focus, a.rayParams)
	if hit then
		desired = hit.Position + (focus - desired).Unit * 1.5
	end
	camera.CFrame = CFrame.lookAt(desired, focus + a.camDir * 10)

	local ratio = math.clamp(math.abs(vel:Dot(look)) / a.stats.topSpeed, 0, 1.3)
	local targetFov = 70 + ratio * 16 + (a.boosting and 10 or 0)
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(dt * 4, 1)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function setResetEnabled(enabled)
	task.spawn(function()
		for _ = 1, 5 do
			if pcall(function()
				StarterGui:SetCore("ResetButtonCallback", enabled)
			end) then
				return
			end
			task.wait(0.5)
		end
	end)
end

function CarController.IsActive()
	return active ~= nil
end

function CarController.Respawn()
	local a = active
	if not a or a.respawning or a.chassis.Anchored then
		return
	end
	a.respawning = true
	task.spawn(function()
		local ok, cf = State.Request("Respawn")
		if ok and typeof(cf) == "CFrame" and active == a and a.model.Parent then
			a.model:PivotTo(cf)
			a.chassis.AssemblyLinearVelocity = Vector3.zero
			a.chassis.AssemblyAngularVelocity = Vector3.zero
		end
		task.wait(1)
		a.respawning = false
	end)
end

function CarController.ExitCar()
	if active and active.mode == "test" then
		State.Request("ExitCar")
	end
end

function CarController.Start(model, mode)
	CarController.Stop()
	local chassis = model:WaitForChild("Chassis", 10)
	if not chassis then
		return
	end
	local wheels = {}
	for _, name in WHEEL_NAMES do
		local tire = model:WaitForChild("Wheel_" .. name, 10)
		local weld = tire and tire:WaitForChild("WheelWeld", 10)
		if not weld then
			return
		end
		local restLen = SUSP.restLength * (1 - SUSP.sag)
		table.insert(wheels, {
			tire = tire,
			weld = weld,
			mount = tire:GetAttribute("Mount"),
			front = tire:GetAttribute("Front") == true,
			radius = tire.Size.Y / 2,
			length = restLen,
			visual = restLen,
			spin = 0,
		})
	end

	local stats = {
		topSpeed = model:GetAttribute("topSpeed") or 100,
		accel = model:GetAttribute("accel") or 50,
		handling = model:GetAttribute("handling") or 2.4,
		grip = model:GetAttribute("grip") or 7,
		brake = model:GetAttribute("brake") or 90,
		nitro = model:GetAttribute("nitro") or 3,
		nitroPower = model:GetAttribute("nitroPower") or 1.35,
	}

	local flames = {}
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Name == "NitroFlame" then
			table.insert(flames, d)
		end
	end

	local look = chassis.CFrame.LookVector
	local a = {
		model = model,
		chassis = chassis,
		mode = mode,
		wheels = wheels,
		stats = stats,
		nitro = stats.nitro,
		steer = 0,
		flames = flames,
		flamesOn = false,
		boosting = false,
		flipTimer = 0,
		killY = model:GetAttribute("KillY") or -100,
		rayParams = buildRayParams(),
		camDir = Vector3.new(look.X, 0, look.Z).Unit,
		camFar = false,
		conns = {},
	}
	active = a

	if Config.Sounds.Engine ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = Config.Sounds.Engine
		sound.Looped = true
		sound.Volume = 0.4
		sound.Parent = chassis
		sound:Play()
		a.engineSound = sound
	end

	table.insert(a.conns, RunService.Heartbeat:Connect(physicsStep))
	RunService:BindToRenderStep("CarCamera", Enum.RenderPriority.Camera.Value + 1, cameraStep)
	table.insert(
		a.conns,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) and active == a then
				CarController.Stop()
			end
		end)
	)
	-- Refresh the raycast filter in case the track finished streaming in late.
	task.spawn(function()
		for _ = 1, 5 do
			task.wait(1)
			if active ~= a then
				return
			end
			a.rayParams = buildRayParams()
		end
	end)

	-- Space / gamepad A are driving controls: sink them so they don't jump.
	ContextActionService:BindActionAtPriority("CarSinkJump", function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:BindAction("CarRespawn", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			CarController.Respawn()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("CarCameraToggle", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and active then
			active.camFar = not active.camFar
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.V, Enum.KeyCode.ButtonR3)
	if mode == "test" then
		ContextActionService:BindAction("CarExit", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				CarController.ExitCar()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonB)
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and mode == "race" then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		setResetEnabled(false)
	end
	pcall(function()
		GuiService.TouchControlsEnabled = false
	end)

	State.driving = true
	State.driveMode = mode
	State.Fire("Driving", true, mode)
end

function CarController.Stop()
	local a = active
	if not a then
		return
	end
	active = nil
	for _, conn in a.conns do
		conn:Disconnect()
	end
	pcall(function()
		RunService:UnbindFromRenderStep("CarCamera")
	end)
	for _, name in { "CarSinkJump", "CarRespawn", "CarCameraToggle", "CarExit" } do
		ContextActionService:UnbindAction(name)
	end
	if a.engineSound then
		a.engineSound:Destroy()
	end

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
	setResetEnabled(true)
	pcall(function()
		GuiService.TouchControlsEnabled = true
	end)
	for key in CarController.Touch do
		CarController.Touch[key] = false
	end

	State.driving = false
	State.driveMode = nil
	State.Fire("Driving", false, nil)
end

return CarController
