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

-- The level 50 reward car: a double cheeseburger on wheels. The buns,
-- patty, lettuce and tomato keep their food colours; the cheese uses the
-- accent colour so it can still be customised.
local BUN = Color3.fromRGB(214, 146, 62)
local BUN_BASE = Color3.fromRGB(196, 128, 52)
local PATTY = Color3.fromRGB(92, 52, 32)
local LETTUCE = Color3.fromRGB(96, 196, 64)
local TOMATO = Color3.fromRGB(215, 45, 35)
local KETCHUP = Color3.fromRGB(180, 20, 20)
local SESAME = Color3.fromRGB(250, 240, 210)
local FRY = Color3.fromRGB(245, 195, 70)

local function disc(model, name, height, diameter, y, color, material, role)
	return cylinder(
		model,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material,
		role
	)
end

local function buildBurger(model, b, display)
	local D = b.length -- the burger is round: diameter = length
	local bottom = b.bottom

	disc(model, "BottomBun", 1.4, D, bottom + 0.7, BUN_BASE)
	disc(model, "Patty", 1.0, D + 0.5, bottom + 1.9, PATTY, Enum.Material.Ground)
	disc(model, "Ketchup", 0.18, D + 0.1, bottom + 2.49, KETCHUP)
	-- Square cheese slice turned 45 degrees so the corners droop over the edge.
	make(
		model,
		"Part",
		"Cheese",
		Vector3.new(D * 0.82, 0.25, D * 0.82),
		CFrame.new(0, bottom + 2.7, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color3.new(1, 1, 1),
		nil,
		"Accent"
	)
	disc(model, "Lettuce", 0.35, D + 0.9, bottom + 2.95, LETTUCE, Enum.Material.LeafyGrass)
	for i = 0, 2 do
		local angle = i / 3 * math.pi * 2 + 0.4
		cylinder(
			model,
			"Tomato",
			Vector3.new(0.3, D * 0.3, D * 0.3),
			CFrame.new(math.cos(angle) * D * 0.28, bottom + 3.25, math.sin(angle) * D * 0.28)
				* CFrame.Angles(0, 0, math.pi / 2),
			TOMATO
		)
	end

	-- Top bun: short cylinder plus a stretched sphere for the dome.
	local bunY = bottom + 3.4
	disc(model, "TopBunBase", 1.0, D + 0.3, bunY + 0.5, BUN)
	local dome = make(model, "Part", "TopBun", Vector3.new(D + 0.3, 3.8, D + 0.3), CFrame.new(0, bunY + 1, 0), BUN)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = dome
	local r = (D + 0.3) / 2
	local seeds = Random.new(50)
	for _ = 1, 22 do
		local angle = seeds:NextNumber(0, math.pi * 2)
		local dist = seeds:NextNumber(0.5, r * 0.8)
		local x, z = math.cos(angle) * dist, math.sin(angle) * dist
		-- Skip the hatch where the driver pops out.
		if (Vector2.new(x, z) - Vector2.new(0, 0.8)).Magnitude > 2.2 then
			local y = bunY + 1 + 1.9 * math.sqrt(math.max(0, 1 - (dist / r) ^ 2))
			make(
				model,
				"Part",
				"Sesame",
				Vector3.new(0.45, 0.2, 0.28),
				CFrame.new(x, y, z) * CFrame.Angles(0, seeds:NextNumber(0, math.pi), 0),
				SESAME
			)
		end
	end

	-- Headlights set into the patty, tail lights at the back.
	local edge = (D + 0.5) / 2
	for _, side in { -1, 1 } do
		local head = make(
			model,
			"Part",
			"Headlight",
			Vector3.new(1.3, 0.6, 0.3),
			CFrame.new(side * 2.2, bottom + 1.9, -edge + 0.3),
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
			Vector3.new(1.3, 0.5, 0.3),
			CFrame.new(side * 2.2, bottom + 1.9, edge - 0.3),
			TAILLIGHT,
			Enum.Material.Neon
		)
		-- French-fry exhausts (nitro flames shoot out of them).
		for k = 0, 1 do
			local fry = make(
				model,
				"Part",
				"Exhaust",
				Vector3.new(2.4, 0.45, 0.45),
				CFrame.new(side * (1.2 + k * 0.6), bottom + 0.9 + k * 0.3, D / 2 + 0.6)
					* CFrame.Angles(0, math.pi / 2, 0)
					* CFrame.Angles(0, 0, math.rad(-12)),
				FRY
			)
			if not display and k == 0 then
				addNitroFlame(fry)
			end
		end
	end
end

function CarBuilder.Build(carId, custom, display)
	local car = Cars.List[carId] or Cars.List.Hatch
	local b = car.body
	local c = b.cabin
	custom = custom or Customization.Default(car.id)

	local model = Instance.new("Model")
	model.Name = car.name
	model:SetAttribute("CarId", car.id)
	model:SetAttribute("Display", display == true)

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

	local cabW = W - 2 * c.inset
	local cabY = yTop + c.height / 2

	if b.style == "burger" then
		buildBurger(model, b, display)
	else
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

	end

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

	if b.style ~= "burger" then
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
		seat.CFrame = CFrame.new(b.seat or Vector3.new(-W * 0.18, -0.5, c.z + 0.2))
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

---------------------------------------------------------------------------
-- Cosmetic items: eyes, wings, trails
---------------------------------------------------------------------------
local WING_STYLES = {
	Angel = { feathers = 5, len = 3.4, grow = 0.6, width = 1.1, angle0 = 18, step = 9 },
	Bat = { feathers = 4, len = 4.6, grow = 0.2, width = 0.9, angle0 = 6, step = 13 },
	Butterfly = { feathers = 2, len = 3.8, grow = -0.6, width = 2.6, angle0 = 35, step = -25, material = Enum.Material.Neon },
	Dragon = { feathers = 4, len = 5.2, grow = 0.4, width = 1.2, angle0 = 12, step = 12 },
	Jet = { feathers = 1, len = 5.5, grow = 0, width = 2.6, angle0 = 4, step = 0, material = Enum.Material.Metal },
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 160, 30)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 40)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(50, 220, 80)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(40, 140, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 60, 255)),
})

-- Where cosmetics attach, in car space.
local function cosmeticAnchors(car)
	local b = car.body
	if b.style == "burger" then
		return {
			eyes = Vector3.new(0, 4.9, -4.6),
			eyeSpacing = 1.8,
			eyeScale = 1.15,
			wing = Vector3.new(6.2, 2.6, 0),
			trailX = 2.6,
			trailZ = b.length / 2,
		}
	end
	local h1 = b.height - b.noseDrop
	return {
		-- Eyes sit on the very front of the nose, like big headlights.
		eyes = Vector3.new(0, b.bottom + h1 + 0.55, -b.length / 2 + 1.2),
		eyeSpacing = b.width * 0.22,
		eyeScale = 1,
		wing = Vector3.new(b.width / 2 - 0.2, b.bottom + b.height + 0.1, b.cabin.z),
		trailX = b.width * 0.3,
		trailZ = b.length / 2,
	}
end

local function ball(parent, name, diameter, cframe, color, material)
	local part = make(parent, "Part", name, Vector3.new(diameter, diameter, diameter), cframe, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Robot visor: an armoured housing with a smoked lens, a row of light
-- segments (animated by the client as a sweeping scanner), a brow plate,
-- side pods with antennas and a chin vent.
local VISOR_SEGMENTS = 11
local function buildRobotVisor(folder, base, anchors, option)
	local s = anchors.eyeScale
	local w = anchors.eyeSpacing * 2 + 2.2 * s
	local h = 0.95 * s
	local metal = Color3.fromRGB(48, 52, 60)
	local dark = Color3.fromRGB(18, 20, 24)

	-- Housing with rounded ends.
	make(folder, "Part", "VisorHousing", Vector3.new(w, h, 0.7), base, metal, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		cylinder(
			folder,
			"VisorCap",
			Vector3.new(0.7, h, h),
			base * CFrame.new(side * w / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
			metal,
			Enum.Material.Metal
		)
	end
	-- Smoked lens across the front.
	local lens = make(
		folder,
		"Part",
		"VisorLens",
		Vector3.new(w - 0.2, h * 0.62, 0.12),
		base * CFrame.new(0, -0.02, -0.38),
		dark,
		Enum.Material.Glass
	)
	lens.Transparency = 0.25
	lens.Reflectance = 0.3
	-- Light segments behind the lens (the client sweeps a bright spot across them).
	local segments = Instance.new("Folder")
	segments.Name = "VisorSegments"
	segments:SetAttribute("VisorColor", option.color)
	segments.Parent = folder
	local segW = (w - 0.6) / VISOR_SEGMENTS
	for i = 1, VISOR_SEGMENTS do
		local seg = make(
			segments,
			"Part",
			"Segment",
			Vector3.new(segW * 0.78, h * 0.34, 0.1),
			base * CFrame.new(-w / 2 + 0.3 + segW * (i - 0.5), -0.02, -0.34),
			option.color,
			Enum.Material.Neon
		)
		seg:SetAttribute("Index", i)
	end
	CollectionService:AddTag(segments, "RobotVisor")
	-- Angled brow plate and chin vent.
	make(
		folder,
		"Part",
		"VisorBrow",
		Vector3.new(w + 0.2, 0.18, 0.9),
		base * CFrame.new(0, h / 2 + 0.05, -0.1) * CFrame.Angles(math.rad(-12), 0, 0),
		metal,
		Enum.Material.Metal
	)
	for k = -1, 1 do
		make(
			folder,
			"Part",
			"VisorVent",
			Vector3.new(w * 0.18, 0.08, 0.1),
			base * CFrame.new(k * w * 0.22, -h / 2 + 0.12, -0.36),
			dark
		)
	end
	-- Side pods with antennas and glowing tips.
	for _, side in { -1, 1 } do
		local pod = base * CFrame.new(side * (w / 2 + 0.3), 0, 0.05)
		make(folder, "Part", "VisorPod", Vector3.new(0.5, h * 0.8, 0.8), pod, dark, Enum.Material.Metal)
		cylinder(
			folder,
			"VisorPodLight",
			Vector3.new(0.1, h * 0.35, h * 0.35),
			pod * CFrame.new(side * 0.26, 0, 0),
			option.color,
			Enum.Material.Neon
		)
		local antennaBase = pod * CFrame.new(0, h * 0.4, 0.1)
		local antennaCF = antennaBase * CFrame.Angles(0, 0, -side * 0.35) * CFrame.new(0, 0.7 * s, 0)
		make(folder, "Part", "VisorAntenna", Vector3.new(0.1, 1.4 * s, 0.1), antennaCF, metal, Enum.Material.Metal)
		ball(folder, "VisorAntennaTip", 0.3 * s, antennaCF * CFrame.new(0, 0.75 * s, 0), option.color, Enum.Material.Neon)
	end
end

local function buildEyes(folder, base, anchors, option)
	local s = anchors.eyeScale
	local style = option.id
	if style == "Robot" then
		buildRobotVisor(folder, base, anchors, option)
		return
	end
	local white = Color3.new(1, 1, 1)
	local black = Color3.fromRGB(15, 15, 18)
	local size = (style == "Cute" and 1.9 or 1.6) * s
	for _, side in { -1, 1 } do
		local center = base * CFrame.new(side * anchors.eyeSpacing, 0, 0)
		ball(folder, "Eye", size, center, white)
		if style == "Love" then
			ball(folder, "Pupil", size * 0.55, center * CFrame.new(0, 0, -size * 0.34), option.color, Enum.Material.Neon)
		else
			ball(folder, "Pupil", size * 0.48, center * CFrame.new(0, -0.05, -size * 0.36), black)
		end
		if style == "Cute" then
			ball(folder, "Shine", size * 0.15, center * CFrame.new(size * 0.12, size * 0.16, -size * 0.5), white, Enum.Material.Neon)
		elseif style == "Angry" then
			make(
				folder,
				"Part",
				"Brow",
				Vector3.new(size * 1.05, 0.3, 0.35),
				center * CFrame.new(0, size * 0.58, -size * 0.25) * CFrame.Angles(0, 0, side * 0.4),
				black
			)
		elseif style == "Lashes" then
			for k = -1, 1 do
				make(
					folder,
					"Part",
					"Lash",
					Vector3.new(0.12, size * 0.45, 0.12),
					center * CFrame.new(k * size * 0.28, size * 0.55, -size * 0.2) * CFrame.Angles(0, 0, -k * 0.5),
					black
				)
			end
		end
	end
end

local function buildWings(folder, chassisCF, anchors, option)
	local st = WING_STYLES[option.id]
	if not st then
		return
	end
	for _, side in { -1, 1 } do
		for k = 0, st.feathers - 1 do
			local len = st.len + k * st.grow
			local angle = math.rad(st.angle0 + k * st.step)
			local zOff = (k - (st.feathers - 1) / 2) * st.width * 0.85
			make(
				folder,
				"Part",
				"Wing",
				Vector3.new(len, 0.18, st.width),
				chassisCF
					* CFrame.new(side * anchors.wing.X, anchors.wing.Y, anchors.wing.Z + zOff)
					* CFrame.Angles(0, 0, side * angle)
					* CFrame.new(side * len / 2, 0, 0),
				option.color,
				st.material
			)
		end
	end
end

local function buildTrail(chassis, anchors, option)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(-anchors.trailX, -2.1, anchors.trailZ)
	a0.Parent = chassis
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(anchors.trailX, -2.1, anchors.trailZ)
	a1.Parent = chassis
	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.FaceCamera = false -- flat ribbon on the road, never a wall
	trail.Lifetime = 0.8
	trail.MinLength = 0.2
	trail.LightEmission = 0.7
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = option.rainbow and RAINBOW or ColorSequence.new(option.color, option.color2 or option.color)
	trail.Parent = chassis
end

function CarBuilder.ApplyCosmetics(model, custom)
	local chassis = model.PrimaryPart
	local car = Cars.List[model:GetAttribute("CarId")]
	if not chassis or not car then
		return
	end
	local old = model:FindFirstChild("Cosmetics")
	if old then
		old:Destroy()
	end
	for _, name in { "TrailA0", "TrailA1", "CosmeticTrail" } do
		local inst = chassis:FindFirstChild(name)
		if inst then
			inst:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Cosmetics"
	folder.Parent = model
	local anchors = cosmeticAnchors(car)
	local chassisCF = chassis.CFrame
	local eyes = Customization.Find("eyes", custom.eyes)
	if eyes and eyes.id ~= "None" then
		buildEyes(folder, chassisCF * CFrame.new(anchors.eyes), anchors, eyes)
	end
	local wings = Customization.Find("wings", custom.wings)
	if wings and wings.id ~= "None" then
		buildWings(folder, chassisCF, anchors, wings)
	end
	local display = model:GetAttribute("Display") == true
	local trail = Customization.Find("trail", custom.trail)
	if trail and trail.id ~= "None" and not display then
		buildTrail(chassis, anchors, trail)
	end
	if display then
		for _, part in folder:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
	end
end

function CarBuilder.ApplyCustomization(model, custom)
	custom = custom or {}
	CarBuilder.ApplyCosmetics(model, custom)
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
