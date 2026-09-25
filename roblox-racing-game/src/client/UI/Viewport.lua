-- 3D car preview inside a ViewportFrame. It turns slowly on its own;
-- players can drag (mouse or touch) to spin it and tilt the view, and
-- scroll to zoom. Auto-rotation resumes a few seconds after letting go.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarBuilder = require(Shared.CarBuilder)
local Cars = require(Shared.Cars)
local Util = require(script.Parent.Util)

local Viewport = {}
Viewport.__index = Viewport

local AUTO_SPIN_SPEED = 0.45 -- radians / second
local AUTO_SPIN_RESUME = 4 -- seconds after the last drag
local DRAG_YAW = 0.012 -- radians per pixel
local DRAG_PITCH = 0.006
local PITCH_MIN, PITCH_MAX = 0.05, 1.1
local ZOOM_MIN, ZOOM_MAX = 0.6, 1.6

function Viewport.new(parent, props)
	local frame = Util.new("ViewportFrame", {
		BackgroundColor3 = Color3.fromRGB(30, 34, 48),
		BorderSizePixel = 0,
		Active = true, -- touches on the preview don't also move the game camera
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

	local hint = Util.label(frame, "Drag to turn  •  Scroll to zoom", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -20, 0, 16),
		TextColor3 = Color3.fromRGB(200, 205, 220),
		TextTransparency = 0.2,
		Font = Enum.Font.Gotham,
		ZIndex = 2,
	})
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		hint.Text = "Drag to turn"
	end

	local self = setmetatable({
		frame = frame,
		camera = camera,
		angle = 0.9,
		pitch = math.atan(0.32),
		zoom = 1,
		dist = 30,
		model = nil,
		carId = nil,
		dragInput = nil,
		lastPos = nil,
		lastInteract = -math.huge,
		conns = {},
	}, Viewport)

	-- Drag to rotate ------------------------------------------------------------
	local function isPointer(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end
	table.insert(
		self.conns,
		frame.InputBegan:Connect(function(input)
			if isPointer(input) and not self.dragInput then
				self.dragInput = input
				self.lastPos = input.Position
				self.lastInteract = os.clock()
			end
		end)
	)
	table.insert(
		self.conns,
		UserInputService.InputChanged:Connect(function(input)
			local drag = self.dragInput
			if not drag then
				return
			end
			local moved = (drag.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
				or input == drag
			if moved then
				local delta = input.Position - self.lastPos
				self.lastPos = input.Position
				self:Rotate(delta.X, delta.Y)
			end
		end)
	)
	table.insert(
		self.conns,
		UserInputService.InputEnded:Connect(function(input)
			if input == self.dragInput or (isPointer(input) and self.dragInput and input.UserInputType == self.dragInput.UserInputType) then
				self.dragInput = nil
				self.lastInteract = os.clock()
			end
		end)
	)
	-- Scroll to zoom.
	table.insert(
		self.conns,
		frame.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				self.zoom = math.clamp(self.zoom - input.Position.Z * 0.1, ZOOM_MIN, ZOOM_MAX)
				self.lastInteract = os.clock()
				self:UpdateCamera()
			end
		end)
	)

	table.insert(
		self.conns,
		RunService.RenderStepped:Connect(function(dt)
			if not frame.Visible then
				return
			end
			if not self.dragInput and os.clock() - self.lastInteract > AUTO_SPIN_RESUME then
				self.angle += dt * AUTO_SPIN_SPEED
			end
			self:UpdateCamera()
		end)
	)
	return self
end

-- Turn the view by a drag of (dx, dy) pixels.
function Viewport:Rotate(dx, dy)
	self.angle -= dx * DRAG_YAW
	self.pitch = math.clamp(self.pitch + dy * DRAG_PITCH, PITCH_MIN, PITCH_MAX)
	self.lastInteract = os.clock()
	self:UpdateCamera()
end

function Viewport:UpdateCamera()
	local d = self.dist * self.zoom
	local a, p = self.angle, self.pitch
	local pos = Vector3.new(math.sin(a) * math.cos(p) * d, math.sin(p) * d, math.cos(a) * math.cos(p) * d)
	self.camera.CFrame = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
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
	for _, conn in self.conns do
		conn:Disconnect()
	end
	self.frame:Destroy()
end

return Viewport
