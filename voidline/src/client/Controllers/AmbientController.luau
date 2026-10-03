--!strict
--[[
	AmbientController
	Brings the ship to life locally (no network cost): animates parts tagged
	by the server's art pass.

	  VoidlineSpin        rotate around an axis       (SpinSpeed, SpinAxis)
	  VoidlineOrbit       circle a centre point        (OrbitCenter, OrbitSpeed)
	  VoidlinePulse       breathing neon glow          (PulseSpeed)
	  VoidlineBob         gentle float                 (BobHeight)
	  VoidlineScreenBars  console level bars flicker

	One RenderStepped connection drives everything; tagged parts are tracked
	as they stream in/out. Reduced effects freezes motion, and Low effects
	quality also softens bloom.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local SettingsController = require(script.Parent.SettingsController)

local AmbientController = {}

type Spin = { Part: BasePart, Base: CFrame, Speed: number, Axis: string, Angle: number }
type Orbit = { Part: BasePart, Center: Vector3, Radius: number, Height: number, Angle: number, Speed: number }
type Pulse = { Part: BasePart, Speed: number, Phase: number, Base: number }
type Bob = { Part: BasePart, Base: CFrame, Height: number, Phase: number }

local spins: { [BasePart]: Spin } = {}
local orbits: { [BasePart]: Orbit } = {}
local pulses: { [BasePart]: Pulse } = {}
local bobs: { [BasePart]: Bob } = {}
local barGroups: { [Instance]: boolean } = {}
local enabled = true
local barTimer = 0
local clock = 0

local function phaseOf(part: BasePart): number
	local p = part.Position
	return (p.X * 0.13 + p.Z * 0.07) % (math.pi * 2)
end

local function track(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

local function applyQuality()
	local reduced = SettingsController.Get("ReducedEffects") == true
	enabled = not reduced
	local low = reduced or SettingsController.Get("EffectsQuality") == "Low"
	local bloom = Lighting:FindFirstChild("VoidlineBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = if low then 0.35 else 0.85
		bloom.Size = if low then 18 else 30
	end
end

local function step(dt: number)
	if not enabled then
		return
	end
	clock += dt
	for part, spin in spins do
		if part.Parent then
			spin.Angle += math.rad(spin.Speed) * dt
			local rotation = if spin.Axis == "X"
				then CFrame.Angles(spin.Angle, 0, 0)
				elseif spin.Axis == "Z" then CFrame.Angles(0, 0, spin.Angle)
				else CFrame.Angles(0, spin.Angle, 0)
			part.CFrame = spin.Base * rotation
		end
	end
	for part, orbit in orbits do
		if part.Parent and orbit.Speed ~= 0 then
			orbit.Angle += math.rad(orbit.Speed) * dt
			local position = orbit.Center + Vector3.new(math.cos(orbit.Angle) * orbit.Radius, orbit.Height, math.sin(orbit.Angle) * orbit.Radius)
			part.CFrame = CFrame.lookAt(position, orbit.Center + Vector3.new(0, orbit.Height, 0))
		end
	end
	for part, pulse in pulses do
		if part.Parent then
			local wave = (math.sin(clock * pulse.Speed * math.pi * 2 + pulse.Phase) + 1) / 2
			part.Transparency = math.clamp(pulse.Base + wave * 0.45, 0, 0.95)
		end
	end
	for part, bob in bobs do
		if part.Parent then
			local offset = Vector3.new(0, math.sin(clock * 1.4 + bob.Phase) * bob.Height, 0)
			-- Spinning parts were already positioned this frame; bob on top of that.
			part.CFrame = if spins[part] then part.CFrame + offset else bob.Base + offset
		end
	end
	barTimer += dt
	if barTimer > 0.18 then
		barTimer = 0
		for group in barGroups do
			if group.Parent then
				for _, bar in group:GetChildren() do
					if bar:IsA("Frame") and math.random() < 0.5 then
						bar.Size = UDim2.fromScale(0.08, 0.2 + math.random() * 0.8)
					end
				end
			end
		end
	end
end

function AmbientController.Start()
	track("VoidlineSpin", function(instance)
		if instance:IsA("BasePart") then
			local axis = instance:GetAttribute("SpinAxis")
			spins[instance] = {
				Part = instance,
				Base = instance.CFrame,
				Speed = tonumber(instance:GetAttribute("SpinSpeed")) or 20,
				Axis = if type(axis) == "string" then axis else "Y",
				Angle = 0,
			}
		end
	end, function(instance)
		spins[instance :: any] = nil
	end)

	track("VoidlineOrbit", function(instance)
		if instance:IsA("BasePart") then
			local center = instance:GetAttribute("OrbitCenter")
			if typeof(center) ~= "Vector3" then
				return
			end
			local offset = instance.Position - center
			orbits[instance] = {
				Part = instance,
				Center = center,
				Radius = Vector3.new(offset.X, 0, offset.Z).Magnitude,
				Height = offset.Y,
				Angle = math.atan2(offset.Z, offset.X),
				Speed = tonumber(instance:GetAttribute("OrbitSpeed")) or 0,
			}
		end
	end, function(instance)
		orbits[instance :: any] = nil
	end)

	track("VoidlinePulse", function(instance)
		if instance:IsA("BasePart") then
			pulses[instance] = {
				Part = instance,
				Speed = tonumber(instance:GetAttribute("PulseSpeed")) or 1,
				Phase = phaseOf(instance),
				Base = instance.Transparency,
			}
		end
	end, function(instance)
		pulses[instance :: any] = nil
	end)

	track("VoidlineBob", function(instance)
		if instance:IsA("BasePart") then
			bobs[instance] = {
				Part = instance,
				Base = instance.CFrame,
				Height = tonumber(instance:GetAttribute("BobHeight")) or 0.6,
				Phase = phaseOf(instance),
			}
		end
	end, function(instance)
		bobs[instance :: any] = nil
	end)

	track("VoidlineScreenBars", function(instance)
		barGroups[instance] = true
	end, function(instance)
		barGroups[instance] = nil
	end)

	applyQuality()
	SettingsController.Changed:Connect(function(key: string)
		if key == "ReducedEffects" or key == "EffectsQuality" then
			applyQuality()
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return AmbientController
