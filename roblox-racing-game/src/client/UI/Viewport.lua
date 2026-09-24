-- Rotating 3D car preview inside a ViewportFrame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarBuilder = require(Shared.CarBuilder)
local Cars = require(Shared.Cars)
local Util = require(script.Parent.Util)

local Viewport = {}
Viewport.__index = Viewport

function Viewport.new(parent, props)
	local frame = Util.new("ViewportFrame", {
		BackgroundColor3 = Color3.fromRGB(30, 34, 48),
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.5, -0.6),
		Parent = parent,
	})
	for key, value in props or {} do
		frame[key] = value
	end
	Util.corner(frame, 12)
	Util.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 170)),
		Rotation = 90,
		Parent = frame,
	})

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = frame
	frame.CurrentCamera = camera

	-- Showroom floor disc.
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(0.4, 26, 26)
	floor.Color = Color3.fromRGB(45, 48, 60)
	floor.Material = Enum.Material.SmoothPlastic
	floor.CFrame = CFrame.new(0, -2.7, 0) * CFrame.Angles(0, 0, math.pi / 2)
	floor.Parent = frame

	local self = setmetatable({
		frame = frame,
		camera = camera,
		angle = 0.9,
		dist = 30,
		model = nil,
		carId = nil,
	}, Viewport)

	self.conn = RunService.RenderStepped:Connect(function(dt)
		if frame.Visible then
			self.angle += dt * 0.45
			self:UpdateCamera()
		end
	end)
	return self
end

function Viewport:UpdateCamera()
	local d = self.dist
	local a = self.angle
	self.camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(a) * d, d * 0.32, math.cos(a) * d), Vector3.new(0, 0, 0))
end

function Viewport:SetCar(carId, custom)
	if self.carId == carId and self.model then
		self:SetCustom(custom)
		return
	end
	if self.model then
		self.model:Destroy()
	end
	local car = Cars.List[carId]
	local model = CarBuilder.Build(carId, custom, true)
	local restY = 1.21 + car.body.wheelRadius
	model:PivotTo(CFrame.new(0, -2.5 + restY, 0))
	model.Parent = self.frame
	self.model = model
	self.carId = carId
	self.dist = car.body.length * 1.45 + 7
	self:UpdateCamera()
end

function Viewport:SetCustom(custom)
	if self.model then
		CarBuilder.ApplyCustomization(self.model, custom)
	end
end

function Viewport:Destroy()
	self.conn:Disconnect()
	self.frame:Destroy()
end

return Viewport
