-- Builds car models entirely from parts (no meshes, no branding).
-- Used by the server (drivable cars, showroom) and the client (garage
-- viewport previews).
--
-- Car space: the invisible "Chassis" part sits at the origin, the car
-- faces -Z (Roblox's LookVector), +X is the right-hand side.
local CollectionService = game:GetService("CollectionService")

local Cars = require(script.Parent.Cars)
local Config = require(script.Parent.Config)
local Customization = require(script.Parent.Customization)

local CarBuilder = {}

local TRIM = Color3.fromRGB(22, 22, 26)
local TIRE = Color3.fromRGB(28, 28, 30)
local GLASS = Color3.fromRGB(20, 28, 40)
local CHROME = Color3.fromRGB(205, 205, 210)
local HEADLIGHT = Color3.fromRGB(255, 250, 225)
local TAILLIGHT = Color3.fromRGB(255, 25, 25)

CarBuilder.WHEEL_NAMES = { "FL", "FR", "RL", "RR" }

local function make(parent, className, name, size, cframe, color, material, role)
	local part = Instance.new(className)
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
	if role then
		part:SetAttribute("Role", role)
	end
	part.Parent = parent
	return part
end

local function cylinder(parent, name, size, cframe, color, material, role)
	local part = make(parent, "Part", name, size, cframe, color, material, role)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function addNitroFlame(exhaust)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "NitroFlame"
	emitter.EmissionDirection = Enum.NormalId.Left -- local -X points out of the back of the car
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 200, 255)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 160, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 20)),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.12, 0.25)
	emitter.Rate = 90
	emitter.Speed = NumberRange.new(18, 28)
	emitter.SpreadAngle = Vector2.new(8, 8)
	emitter.Enabled = false
	emitter.Parent = exhaust
end

function CarBuilder.Build(carId, custom, display)
	local car = Cars.List[carId] or Cars.List.Hatch
	local b = car.body
	local c = b.cabin
	custom = custom or Customization.Default(car.id)

	local model = Instance.new("Model")
	model.Name = car.name
	model:SetAttribute("CarId", car.id)

	local L, W, H, bottom = b.length, b.width, b.height, b.bottom
	local h1 = H - b.noseDrop
	local yTop = bottom + H
	local frontZ, rearZ = -L / 2, L / 2
	local paint = Color3.new(1, 1, 1) -- real colours applied by ApplyCustomization

	-- Physics body -----------------------------------------------------
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(W - 0.4, 1.2, L - 0.4)
	chassis.CFrame = CFrame.new()
	chassis.Transparency = 1
	chassis.CanCollide = true
	chassis.CanTouch = true
	chassis.CustomPhysicalProperties = PhysicalProperties.new(3, 0.05, 0, 100, 1)
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.Parent = model
	model.PrimaryPart = chassis

	-- Lower body -------------------------------------------------------
	make(model, "Part", "Body", Vector3.new(W, h1, L), CFrame.new(0, bottom + h1 / 2, 0), paint, nil, "Paint")
	make(
		model,
		"Part",
		"BodyUpper",
		Vector3.new(W, b.noseDrop, L - b.noseLen),
		CFrame.new(0, bottom + h1 + b.noseDrop / 2, b.noseLen / 2),
		paint,
		nil,
		"Paint"
	)
	-- WedgePart: tall edge at +Z, slope falls toward -Z (the nose).
	make(
		model,
		"WedgePart",
		"Nose",
		Vector3.new(W, b.noseDrop, b.noseLen),
		CFrame.new(0, bottom + h1 + b.noseDrop / 2, frontZ + b.noseLen / 2),
		paint,
		nil,
		"Paint"
	)

	-- Cabin --------------------------------------------------------------
	local cabW = W - 2 * c.inset
	local cabY = yTop + c.height / 2
	local glassCore = make(
		model,
		"Part",
		"Cabin",
		Vector3.new(cabW, c.height, c.length),
		CFrame.new(0, cabY, c.z),
		GLASS,
		Enum.Material.Glass
	)
	glassCore.Transparency = 0.35
	local windshield = make(
		model,
		"WedgePart",
		"Windshield",
		Vector3.new(cabW, c.height, c.windshield),
		CFrame.new(0, cabY, c.z - c.length / 2 - c.windshield / 2),
		GLASS,
		Enum.Material.Glass
	)
	windshield.Transparency = 0.35
	local rearGlass = make(
		model,
		"WedgePart",
		"RearWindow",
		Vector3.new(cabW, c.height, c.rear),
		CFrame.new(0, cabY, c.z + c.length / 2 + c.rear / 2) * CFrame.Angles(0, math.pi, 0),
		GLASS,
		Enum.Material.Glass
	)
	rearGlass.Transparency = 0.35
	make(
		model,
		"Part",
		"Roof",
		Vector3.new(cabW + 0.1, 0.25, c.length + 0.1),
		CFrame.new(0, yTop + c.height + 0.12, c.z),
		paint,
		nil,
		"Paint"
	)
	make(
		model,
		"Part",
		"BPillar",
		Vector3.new(cabW + 0.06, c.height, 0.35),
		CFrame.new(0, cabY, c.z),
		paint,
		nil,
		"Paint"
	)
	for _, side in { -1, 1 } do
		make(
			model,
			"Part",
			"Mirror",
			Vector3.new(0.5, 0.35, 0.6),
			CFrame.new(side * (W / 2 + 0.2), yTop + 0.35, c.z - c.length / 2 - c.windshield * 0.3),
			paint,
			nil,
			"Paint"
		)
	end

	-- Lights, grille, bumpers ------------------------------------------
	for _, side in { -1, 1 } do
		local head = make(
			model,
			"Part",
			"Headlight",
			Vector3.new(1.5, 0.45, 0.2),
			CFrame.new(side * (W / 2 - 1.1), bottom + h1 - 0.35, frontZ - 0.08),
			HEADLIGHT,
			Enum.Material.Neon
		)
		if not display then
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Range = 60
			spot.Angle = 55
			spot.Brightness = 3
			spot.Parent = head
		end
		make(
			model,
			"Part",
			"Taillight",
			Vector3.new(1.6, 0.4, 0.15),
			CFrame.new(side * (W / 2 - 1.1), yTop - 0.4, rearZ + 0.06),
			TAILLIGHT,
			Enum.Material.Neon
		)
		local exhaust = cylinder(
			model,
			"Exhaust",
			Vector3.new(0.8, 0.45, 0.45),
			CFrame.new(side * (W / 2 - 1.6), bottom + 0.35, rearZ + 0.15) * CFrame.Angles(0, math.pi / 2, 0),
			CHROME,
			Enum.Material.Metal
		)
		if not display then
			addNitroFlame(exhaust)
		end
	end
	make(
		model,
		"Part",
		"Grille",
		Vector3.new(W * 0.42, h1 * 0.45, 0.15),
		CFrame.new(0, bottom + h1 * 0.45, frontZ - 0.05),
		TRIM
	)
	make(
		model,
		"Part",
		"FrontLip",
		Vector3.new(W - 0.4, 0.25, 0.8),
		CFrame.new(0, bottom + 0.05, frontZ + 0.2),
		TRIM
	)
	make(
		model,
		"Part",
		"RearBumper",
		Vector3.new(W - 0.2, 0.5, 0.3),
		CFrame.new(0, bottom + 0.3, rearZ + 0.1),
		TRIM
	)
	make(
		model,
		"Part",
		"Plate",
		Vector3.new(1.6, 0.6, 0.05),
		CFrame.new(0, bottom + h1 * 0.55 + 0.2, rearZ + 0.04),
		Color3.fromRGB(240, 240, 240)
	)

	-- Wheels ------------------------------------------------------------
	local r, ww = b.wheelRadius, b.wheelWidth
	local restY = -(Config.Suspension.restLength * (1 - Config.Suspension.sag))
	local wheelSpecs = {
		{ "FL", -1, -1 },
		{ "FR", 1, -1 },
		{ "RL", -1, 1 },
		{ "RR", 1, 1 },
	}
	local wheels = {}
	for _, spec in wheelSpecs do
		local name, sx, sz = spec[1], spec[2], spec[3]
		local x, z = sx * b.track / 2, sz * b.wheelBase / 2
		local wheelCF = CFrame.new(x, restY, z)
		local tire = cylinder(model, "Wheel_" .. name, Vector3.new(ww, r * 2, r * 2), wheelCF, TIRE)
		tire:SetAttribute("Mount", Vector3.new(x, 0, z))
		tire:SetAttribute("Front", sz < 0)
		local parts = {
			cylinder(model, "Rim", Vector3.new(ww + 0.08, r * 1.25, r * 1.25), wheelCF, CHROME, nil, "Rim"),
			make(model, "Part", "Spoke", Vector3.new(ww + 0.12, r * 1.15, 0.3), wheelCF, CHROME, nil, "Rim"),
			make(
				model,
				"Part",
				"Spoke",
				Vector3.new(ww + 0.12, r * 1.15, 0.3),
				wheelCF * CFrame.Angles(math.pi / 2, 0, 0),
				CHROME,
				nil,
				"Rim"
			),
			cylinder(model, "Hub", Vector3.new(ww + 0.16, r * 0.35, r * 0.35), wheelCF, TRIM),
		}
		wheels[name] = { tire = tire, parts = parts, cf = wheelCF }

		if b.extras.mudflaps and sz > 0 then
			make(
				model,
				"Part",
				"Mudflap",
				Vector3.new(1.1, 0.9, 0.1),
				CFrame.new(x, bottom - 0.15, z + r + 0.25),
				TRIM
			)
		end
	end

	-- Spoilers -----------------------------------------------------------
	if b.spoiler == "roof" then
		make(
			model,
			"Part",
			"Spoiler",
			Vector3.new(cabW, 0.18, 1.0),
			CFrame.new(0, yTop + c.height + 0.22, c.z + c.length / 2 + 0.35),
			paint,
			nil,
			"Accent"
		)
	elseif b.spoiler == "wing" or b.spoiler == "gtwing" then
		local tall = b.spoiler == "gtwing" and 1.5 or 0.9
		local wingW = b.spoiler == "gtwing" and W + 0.2 or W - 0.8
		for _, side in { -1, 1 } do
			make(
				model,
				"Part",
				"WingPost",
				Vector3.new(0.25, tall, 0.5),
				CFrame.new(side * (W / 2 - 1.4), yTop + tall / 2, rearZ - 0.9),
				TRIM
			)
			if b.spoiler == "gtwing" then
				make(
					model,
					"Part",
					"Endplate",
					Vector3.new(0.15, 0.8, 1.7),
					CFrame.new(side * (wingW / 2 + 0.05), yTop + tall + 0.05, rearZ - 0.8),
					paint,
					nil,
					"Accent"
				)
			end
		end
		make(
			model,
			"Part",
			"Wing",
			Vector3.new(wingW, 0.2, b.spoiler == "gtwing" and 1.6 or 1.3),
			CFrame.new(0, yTop + tall + 0.1, rearZ - 0.8),
			paint,
			nil,
			"Accent"
		)
	elseif b.spoiler == "ducktail" then
		make(
			model,
			"WedgePart",
			"Ducktail",
			Vector3.new(W, 0.45, 1.1),
			CFrame.new(0, yTop + 0.22, rearZ - 0.55),
			paint,
			nil,
			"Paint"
		)
	end

	-- Extras ---------------------------------------------------------------
	local ex = b.extras
	local hoodStart = frontZ + b.noseLen
	local hoodEnd = c.z - c.length / 2 - c.windshield
	local hoodLen = hoodEnd - hoodStart
	if ex.scoop then
		make(
			model,
			"Part",
			"Scoop",
			Vector3.new(1.8, 0.4, 2.0),
			CFrame.new(0, yTop + 0.2, hoodEnd - 1.4),
			paint,
			nil,
			"Accent"
		)
	end
	if ex.stripes then
		local deckStart = c.z + c.length / 2 + c.rear
		for _, sx in { -0.55, 0.55 } do
			if hoodLen > 0.3 then
				make(
					model,
					"Part",
					"Stripe",
					Vector3.new(0.55, 0.06, hoodLen),
					CFrame.new(sx, yTop + 0.03, hoodStart + hoodLen / 2),
					paint,
					nil,
					"Accent"
				)
			end
			make(
				model,
				"Part",
				"Stripe",
				Vector3.new(0.55, 0.06, c.length),
				CFrame.new(sx, yTop + c.height + 0.27, c.z),
				paint,
				nil,
				"Accent"
			)
			if rearZ - deckStart > 0.3 then
				make(
					model,
					"Part",
					"Stripe",
					Vector3.new(0.55, 0.06, rearZ - deckStart),
					CFrame.new(sx, yTop + 0.03, (deckStart + rearZ) / 2),
					paint,
					nil,
					"Accent"
				)
			end
		end
	end
	if ex.roofVent then
		make(
			model,
			"Part",
			"RoofVent",
			Vector3.new(1.4, 0.2, 0.8),
			CFrame.new(0, yTop + c.height + 0.32, c.z - c.length / 2 + 0.6),
			TRIM
		)
	end
	if ex.intakes then
		for _, side in { -1, 1 } do
			make(
				model,
				"Part",
				"SideIntake",
				Vector3.new(0.2, 0.9, 2.2),
				CFrame.new(side * (W / 2 + 0.02), bottom + h1 * 0.5 + 0.3, c.z + c.length / 2 + 0.8),
				TRIM
			)
		end
	end
	if ex.engineVents then
		local deckStart = c.z + c.length / 2 + c.rear
		for i = 0, 2 do
			make(
				model,
				"Part",
				"EngineVent",
				Vector3.new(cabW * 0.8, 0.08, 0.25),
				CFrame.new(0, yTop + 0.04, deckStart + 0.4 + i * 0.6),
				TRIM
			)
		end
	end
	if ex.splitter then
		make(
			model,
			"Part",
			"Splitter",
			Vector3.new(W + 0.2, 0.15, 1.0),
			CFrame.new(0, bottom - 0.05, frontZ - 0.25),
			paint,
			nil,
			"Accent"
		)
	end
	if ex.sideSkirts then
		for _, side in { -1, 1 } do
			make(
				model,
				"Part",
				"SideSkirt",
				Vector3.new(0.25, 0.4, L * 0.5),
				CFrame.new(side * (W / 2 + 0.05), bottom + 0.2, 0),
				TRIM
			)
		end
	end

	-- Underglow -----------------------------------------------------------
	local glow = make(
		model,
		"Part",
		"Underglow",
		Vector3.new(W - 1.6, 0.1, L - 3),
		CFrame.new(0, bottom - 0.08, 0),
		Color3.new(1, 1, 1),
		Enum.Material.Neon,
		"Glow"
	)
	local glowLight = Instance.new("PointLight")
	glowLight.Range = 12
	glowLight.Brightness = 2
	glowLight.Parent = glow

	-- Driver seat (drivable cars only) --------------------------------------
	if not display then
		local seat = Instance.new("Seat")
		seat.Name = "DriverSeat"
		seat.Size = Vector3.new(1.6, 0.3, 1.6)
		seat.CFrame = CFrame.new(-W * 0.18, -0.5, c.z + 0.2)
		seat.Transparency = 1
		seat.Anchored = false
		seat.CanCollide = false
		seat.CanTouch = false
		seat.CanQuery = false
		seat.Massless = true
		seat.Parent = model
	end

	CarBuilder.ApplyCustomization(model, custom)

	-- Assemble --------------------------------------------------------------
	if display then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	else
		local wheelPartSet = {}
		for _, w in wheels do
			wheelPartSet[w.tire] = true
			for _, p in w.parts do
				wheelPartSet[p] = true
			end
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= chassis and not wheelPartSet[d] then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = chassis
				weld.Part1 = d
				weld.Parent = d
			end
		end
		for _, w in wheels do
			local weld = Instance.new("Weld")
			weld.Name = "WheelWeld"
			weld.Part0 = chassis
			weld.Part1 = w.tire
			weld.C0 = w.cf
			weld.C1 = CFrame.new()
			weld.Parent = w.tire
			for _, p in w.parts do
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = w.tire
				wc.Part1 = p
				wc.Parent = p
			end
		end
	end

	return model
end

function CarBuilder.ApplyCustomization(model, custom)
	custom = custom or {}
	local paint = Customization.Find("paint", custom.paint) or Customization.Options.paint[1]
	local accent = Customization.Find("accent", custom.accent) or Customization.Find("accent", "Jet Black")
	local rim = Customization.Find("rim", custom.rim) or Customization.Options.rim[1]
	local glow = Customization.Find("glow", custom.glow) or Customization.Options.glow[1]
	local finish = Customization.Find("finish", custom.finish) or Customization.Options.finish[1]

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local role = d:GetAttribute("Role")
			if role == "Paint" then
				d.Color = paint.color
				d.Material = finish.material
				d.Reflectance = finish.reflectance
			elseif role == "Accent" then
				d.Color = accent.color
				d.Material = finish.id == "Neon" and Enum.Material.Neon or Enum.Material.SmoothPlastic
				d.Reflectance = 0.1
			elseif role == "Rim" then
				d.Color = rim.color
				d.Material = rim.vip and Enum.Material.Neon or Enum.Material.SmoothPlastic
				d.Reflectance = rim.vip and 0 or 0.25
			elseif role == "Glow" then
				local light = d:FindFirstChildOfClass("PointLight")
				if glow.id == "None" then
					d.Transparency = 1
					if light then
						light.Enabled = false
					end
					CollectionService:RemoveTag(d, "RainbowGlow")
				else
					d.Transparency = 0
					d.Color = glow.color
					if light then
						light.Enabled = true
						light.Color = glow.color
					end
					if glow.id == "Rainbow" then
						CollectionService:AddTag(d, "RainbowGlow")
					else
						CollectionService:RemoveTag(d, "RainbowGlow")
					end
				end
			end
		end
	end
end

return CarBuilder
