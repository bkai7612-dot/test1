--!strict
--[[
	Atmosphere
	Lighting, post-processing and everything outside the hull: a starfield
	sky, a glowing gas giant and moon beyond the windows, faint nebula
	glow, and the ASTERION's exterior (hull plating, engines, antennae) as
	seen from the departure lounge window.

	Post effects live in Lighting so they replicate to every client; the
	client may scale them down for low effects quality.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShipLayout = require(Shared.Data.ShipLayout)

local Kit = require(script.Parent.Kit)

local Atmosphere = {}

local function effect<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance :: any
end

function Atmosphere.applyLighting()
	Lighting.ClockTime = 0 -- night sky = stars
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(38, 42, 56)
	Lighting.OutdoorAmbient = Color3.fromRGB(26, 28, 40)
	Lighting.ColorShift_Top = Color3.fromRGB(10, 14, 24)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.75
	Lighting.ExposureCompensation = 0.15
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.FogEnd = 100000

	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.Name = "VoidlineSky"
	sky.StarCount = 6000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting

	local bloom = effect("BloomEffect", "VoidlineBloom") :: BloomEffect
	bloom.Intensity = 0.85
	bloom.Size = 30
	bloom.Threshold = 0.92

	local grade = effect("ColorCorrectionEffect", "VoidlineGrade") :: ColorCorrectionEffect
	grade.Contrast = 0.14
	grade.Saturation = 0.08
	grade.Brightness = 0.02
	grade.TintColor = Color3.fromRGB(232, 240, 255)

	local rays = effect("SunRaysEffect", "VoidlineRays") :: SunRaysEffect
	rays.Enabled = false
end

-- Celestial backdrop visible through every window.
local function buildSpace(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Space"
	folder.Parent = parent

	-- Gas giant beyond the fore windows (north = -Z), with an atmosphere halo.
	local planetCenter = CFrame.new(-700, 80, -2500)
	Kit.ball(folder, "Planet", 1900, planetCenter, Color3.fromRGB(22, 58, 110), Enum.Material.Neon)
	Kit.ball(folder, "PlanetBands", 1905, planetCenter * CFrame.Angles(0, 0, math.rad(18)), Color3.fromRGB(70, 120, 190), Enum.Material.Neon, 0.82)
	Kit.ball(folder, "PlanetHalo", 1990, planetCenter, Color3.fromRGB(110, 190, 255), Enum.Material.Neon, 0.94)
	local ring = Kit.cylinder(folder, "PlanetRing", 6, 2040, planetCenter * CFrame.Angles(math.rad(76), 0, math.rad(12)), Color3.fromRGB(160, 170, 210), Enum.Material.Neon, "Y")
	ring.Transparency = 0.88

	-- Moon and distant nebula glows.
	Kit.ball(folder, "Moon", 260, CFrame.new(950, 520, -2200), Color3.fromRGB(120, 116, 130), Enum.Material.Neon)
	Kit.ball(folder, "NebulaViolet", 2000, CFrame.new(2400, 900, -1500), Color3.fromRGB(120, 60, 200), Enum.Material.Neon, 0.96)
	Kit.ball(folder, "NebulaTeal", 1800, CFrame.new(-2500, -600, 1200), Color3.fromRGB(40, 170, 170), Enum.Material.Neon, 0.96)
	Kit.ball(folder, "NebulaRose", 1600, CFrame.new(1800, -400, 2400), Color3.fromRGB(200, 70, 120), Enum.Material.Neon, 0.97)
end

-- The ASTERION seen from outside: plating over and under the decks,
-- engines aft, a nose fore, antenna masts with blinking beacons.
local function buildHull(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Hull"
	folder.Parent = parent

	local floorY = ShipLayout.FloorY
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, room in ShipLayout.Rooms do
		minX = math.min(minX, room.CenterX - room.SizeX / 2)
		maxX = math.max(maxX, room.CenterX + room.SizeX / 2)
		minZ = math.min(minZ, room.CenterZ - room.SizeZ / 2)
		maxZ = math.max(maxZ, room.CenterZ + room.SizeZ / 2)
	end
	local width = maxX - minX + 16
	local depth = maxZ - minZ + 16
	local cx = (minX + maxX) / 2
	local cz = (minZ + maxZ) / 2

	-- Upper and lower plating (above the tallest ceiling, below the floors).
	local roofY = floorY + 34
	Kit.box(folder, "Roof", Vector3.new(width, 2, depth), CFrame.new(cx, roofY, cz), Kit.Color.Hull, Enum.Material.DiamondPlate)
	Kit.box(folder, "Keel", Vector3.new(width - 20, 6, depth - 20), CFrame.new(cx, floorY - 4, cz), Kit.Color.HullDark, Enum.Material.Metal)
	-- Plating seams on the roof.
	for i = -3, 3 do
		Kit.box(folder, "Seam", Vector3.new(1, 0.6, depth - 4), CFrame.new(cx + i * width / 7, roofY + 1.2, cz), Kit.Color.HullDark, Enum.Material.Metal)
	end
	-- Side skirts closing the decks.
	for _, side in { -1, 1 } do
		Kit.box(folder, "Skirt", Vector3.new(4, 40, depth), CFrame.new(cx + side * (width / 2 + 2), floorY + 15, cz), Kit.Color.Hull, Enum.Material.Metal)
		-- Running lights along the skirt.
		for j = -4, 4 do
			local light = Kit.neon(folder, "RunningLight", Vector3.new(0.6, 1.2, 3), CFrame.new(cx + side * (width / 2 + 4.3), floorY + 22, cz + j * depth / 9), if side < 0 then Kit.Color.Red else Kit.Color.Green)
			Kit.pulse(light, 0.6)
		end
	end

	-- Engines (aft = +Z).
	local aftZ = maxZ + 8
	for _, x in { -150, 0, 150 } do
		local engineCenter = CFrame.new(cx + x, floorY + 14, aftZ + 26)
		Kit.cylinder(folder, "EngineNacelle", 52, 30, engineCenter, Kit.Color.Hull, Enum.Material.Metal, "Z")
		Kit.cylinder(folder, "EngineRing", 6, 33, engineCenter * CFrame.new(0, 0, 18), Kit.Color.HullDark, Enum.Material.Metal, "Z")
		local glow = Kit.cylinder(folder, "EngineGlow", 1, 24, engineCenter * CFrame.new(0, 0, 26.6), Color3.fromRGB(110, 190, 255), Enum.Material.Neon, "Z")
		Kit.pulse(glow, 0.35)
		local plume = Kit.cylinder(folder, "EnginePlume", 26, 18, engineCenter * CFrame.new(0, 0, 40), Color3.fromRGB(90, 160, 255), Enum.Material.Neon, "Z")
		plume.Transparency = 0.82
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(110, 190, 255)
		light.Range = 60
		light.Brightness = 3
		light.Parent = glow
	end

	-- Nose (fore = -Z): a stepped prow.
	local foreZ = minZ - 8
	Kit.wedge(folder, "Prow", Vector3.new(width * 0.7, 30, 60), CFrame.new(cx, floorY + 14, foreZ - 30) * CFrame.Angles(0, math.rad(180), 0), Kit.Color.Hull, Enum.Material.Metal)
	Kit.box(folder, "ProwCollar", Vector3.new(width * 0.75, 34, 6), CFrame.new(cx, floorY + 15, foreZ - 2), Kit.Color.HullDark, Enum.Material.Metal)

	-- Antenna masts with blinking beacons.
	for i, x in { -180, -60, 90, 200 } do
		local height = 18 + (i % 2) * 10
		Kit.cylinder(folder, "Mast", height, 1.2, CFrame.new(cx + x, roofY + height / 2, cz - 40 + i * 18), Kit.Color.Steel, Enum.Material.Metal, "Y")
		local beacon = Kit.ball(folder, "Beacon", 2, CFrame.new(cx + x, roofY + height + 1, cz - 40 + i * 18), Kit.Color.Red, Enum.Material.Neon)
		Kit.pulse(beacon, 1.4)
	end
	-- Comms dish on the roof (slowly turning).
	local dish = Kit.cylinder(folder, "Dish", 2, 22, CFrame.new(cx - 100, roofY + 8, cz - 70) * CFrame.Angles(math.rad(35), 0, 0), Kit.Color.PanelLight, Enum.Material.Metal, "Y")
	Kit.spin(dish, 6, "Y")
end

function Atmosphere.buildExterior(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Exterior"
	folder.Parent = parent
	buildSpace(folder)
	buildHull(folder)
end

return Atmosphere
