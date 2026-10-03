--!strict
--[[
	Kit
	Building blocks for the ASTERION's art pass: a shared palette and helpers
	for decorative parts. Decorative parts never collide with players unless
	asked to, don't cast shadows (cheap on mobile) and are skipped by
	raycasts, so they can never affect gameplay checks.

	Animation is tag-driven and runs on clients (AmbientController):
	  VoidlineSpin   rotate continuously (attributes SpinSpeed deg/s, SpinAxis "X"|"Y"|"Z")
	  VoidlinePulse  breathing glow on neon parts (attribute PulseSpeed)
	  VoidlineBob    gentle float up/down (attribute BobHeight)
]]

local CollectionService = game:GetService("CollectionService")

local Kit = {}

Kit.Color = {
	Hull = Color3.fromRGB(58, 63, 74),
	HullDark = Color3.fromRGB(32, 35, 42),
	Panel = Color3.fromRGB(150, 158, 170),
	PanelLight = Color3.fromRGB(196, 202, 212),
	PanelDark = Color3.fromRGB(86, 92, 104),
	Trim = Color3.fromRGB(40, 44, 52),
	Floor = Color3.fromRGB(52, 57, 66),
	FloorInset = Color3.fromRGB(70, 76, 88),
	Ceiling = Color3.fromRGB(28, 31, 38),
	Glass = Color3.fromRGB(150, 195, 235),
	White = Color3.fromRGB(235, 240, 248),
	Hazard = Color3.fromRGB(255, 190, 40),
	HazardDark = Color3.fromRGB(30, 30, 34),
	Copper = Color3.fromRGB(176, 112, 64),
	Steel = Color3.fromRGB(120, 126, 138),
	Cyan = Color3.fromRGB(86, 214, 255),
	Amber = Color3.fromRGB(255, 176, 60),
	Green = Color3.fromRGB(110, 235, 150),
	Violet = Color3.fromRGB(170, 120, 255),
	Red = Color3.fromRGB(255, 80, 80),
	Plant = Color3.fromRGB(80, 170, 90),
}

Kit.SectionColor = {
	Fore = Color3.fromRGB(86, 214, 255),
	Mid = Color3.fromRGB(255, 186, 80),
	Aft = Color3.fromRGB(110, 235, 150),
	Lobby = Color3.fromRGB(86, 214, 255),
}

-- Creates an anchored decorative part. Pass Collide = true for solid props.
function Kit.part(props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new(props.ClassName or "Part") :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	local collide = props.Collide == true
	part.CanCollide = collide
	part.CanQuery = collide
	for key, value in props do
		if key ~= "ClassName" and key ~= "Collide" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

function Kit.box(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): BasePart
	return Kit.part({
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Collide = collide,
	}, parent)
end

function Kit.neon(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, transparency: number?): BasePart
	return Kit.part({
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = transparency or 0,
	}, parent)
end

-- Cylinder along an axis. `cframe` is the centre; length runs along `axis`.
function Kit.cylinder(parent: Instance, name: string, length: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?, axis: string?, collide: boolean?): BasePart
	local rotation = if axis == "Y"
		then CFrame.Angles(0, 0, math.rad(90))
		elseif axis == "Z" then CFrame.Angles(0, math.rad(90), 0)
		else CFrame.new()
	return Kit.part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = cframe * rotation,
		Color = color,
		Material = material or Enum.Material.Metal,
		Collide = collide,
	}, parent)
end

function Kit.ball(parent: Instance, name: string, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?, transparency: number?): BasePart
	return Kit.part({
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		CFrame = cframe,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Transparency = transparency or 0,
	}, parent)
end

function Kit.wedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): BasePart
	return Kit.part({
		ClassName = "WedgePart",
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}, parent)
end

function Kit.spin(part: BasePart, degreesPerSecond: number, axis: string?)
	part:SetAttribute("SpinSpeed", degreesPerSecond)
	part:SetAttribute("SpinAxis", axis or "Y")
	CollectionService:AddTag(part, "VoidlineSpin")
end

function Kit.pulse(part: BasePart, speed: number?)
	part:SetAttribute("PulseSpeed", speed or 1)
	CollectionService:AddTag(part, "VoidlinePulse")
end

function Kit.bob(part: BasePart, height: number?)
	part:SetAttribute("BobHeight", height or 0.6)
	CollectionService:AddTag(part, "VoidlineBob")
end

-- Diagonal hazard stripes on a flat strip (alternating blocks), e.g. door frames.
function Kit.hazardStrip(parent: Instance, length: number, thickness: number, height: number, cframe: CFrame, along: "X" | "Z", blockLength: number?)
	local count = math.max(2, math.floor(length / (blockLength or 1.5)))
	local step = length / count
	for i = 0, count - 1 do
		local offset = -length / 2 + step * (i + 0.5)
		local size = if along == "X" then Vector3.new(step, height, thickness) else Vector3.new(thickness, height, step)
		local position = if along == "X" then CFrame.new(offset, 0, 0) else CFrame.new(0, 0, offset)
		Kit.box(parent, "Hazard", size, cframe * position, if i % 2 == 0 then Kit.Color.Hazard else Kit.Color.HazardDark)
	end
end

return Kit
