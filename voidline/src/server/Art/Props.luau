--!strict
--[[
	Props
	Each room's hero set dressing. Props stay inside the room's quadrants,
	clear of the central cross paths between doorways, the console anchors
	near the walls, and the spawn / muster rings at room centres.

	Large props collide (you walk around them); small dressing doesn't.
	Motion (spin / orbit / pulse / bob) is animated on clients by
	AmbientController from tags set here.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShipLayout = require(Shared.Data.ShipLayout)

local Kit = require(script.Parent.Kit)

local Props = {}

local FLOOR_Y = ShipLayout.FloorY
local C = Kit.Color

-- Parts placed in a ring that orbits a centre (animated on clients).
local function orbitRing(parent: Instance, center: Vector3, radius: number, count: number, size: Vector3, color: Color3, speed: number)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local part = Kit.neon(parent, "OrbitSegment", size, CFrame.lookAt(position, center), color)
		part:SetAttribute("OrbitCenter", center)
		part:SetAttribute("OrbitSpeed", speed)
		CollectionService:AddTag(part, "VoidlineOrbit")
	end
end

local function planter(parent: Instance, origin: CFrame, length: number)
	Kit.box(parent, "Planter", Vector3.new(4.5, 2.4, length), origin * CFrame.new(0, 1.2, 0), C.HullDark, Enum.Material.Metal, true)
	Kit.box(parent, "Soil", Vector3.new(4, 0.3, length - 0.6), origin * CFrame.new(0, 2.5, 0), Color3.fromRGB(70, 50, 35), Enum.Material.Ground)
	local count = math.floor(length / 2.4)
	for i = 1, count do
		local z = -length / 2 + (i - 0.5) * (length / count)
		local size = 1.6 + ((i * 37) % 10) / 10
		Kit.ball(parent, "Plant", size, origin * CFrame.new(((i % 2) - 0.5) * 1.2, 2.6 + size / 3, z), C.Plant:Lerp(Color3.fromRGB(150, 220, 90), (i % 3) / 4), Enum.Material.Grass)
	end
	-- Grow light bar overhead.
	local lamp = Kit.neon(parent, "GrowLight", Vector3.new(1, 0.3, length), origin * CFrame.new(0, 8, 0), Color3.fromRGB(200, 120, 255))
	Kit.pulse(lamp, 0.25)
	for _, z in { -length / 2 + 1, length / 2 - 1 } do
		Kit.cylinder(parent, "LampRod", 5.4, 0.25, origin * CFrame.new(0, 5.4, z), C.Steel, Enum.Material.Metal, "Y")
	end
end

local function crateStack(parent: Instance, base: CFrame, seed: number)
	local colors = { Color3.fromRGB(150, 116, 70), Color3.fromRGB(70, 96, 120), Color3.fromRGB(160, 70, 50), Color3.fromRGB(90, 110, 80) }
	Kit.box(parent, "Crate", Vector3.new(4, 4, 4), base * CFrame.new(0, 2, 0), colors[(seed % 4) + 1], Enum.Material.WoodPlanks, true)
	Kit.box(parent, "Crate", Vector3.new(3, 3, 3), base * CFrame.new(0.4, 5.5, -0.2) * CFrame.Angles(0, math.rad(15 * seed), 0), colors[((seed + 1) % 4) + 1], Enum.Material.Metal, true)
	Kit.box(parent, "Crate", Vector3.new(3.4, 2, 2.4), base * CFrame.new(3.8, 1, 1), colors[((seed + 2) % 4) + 1], Enum.Material.Metal, true)
end

local function container(parent: Instance, cf: CFrame, color: Color3)
	Kit.box(parent, "Container", Vector3.new(9, 5, 4.5), cf * CFrame.new(0, 2.5, 0), color, Enum.Material.CorrodedMetal, true)
	for i = -2, 2 do
		Kit.box(parent, "Rib", Vector3.new(0.3, 5.2, 4.7), cf * CFrame.new(i * 2, 2.5, 0), color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Metal)
	end
	Kit.neon(parent, "ContainerTag", Vector3.new(1.2, 0.4, 0.1), cf * CFrame.new(-3, 4, -2.3), C.Amber)
end

local function serverRack(parent: Instance, cf: CFrame)
	Kit.box(parent, "Rack", Vector3.new(3, 9, 2.4), cf * CFrame.new(0, 4.5, 0), C.HullDark, Enum.Material.Metal, true)
	for row = 1, 6 do
		for col = -1, 1 do
			local light = Kit.neon(parent, "RackLight", Vector3.new(0.4, 0.2, 0.05), cf * CFrame.new(col * 0.8, row * 1.3, -1.23), if (row + col) % 3 == 0 then C.Amber else C.Cyan)
			if (row * 3 + col) % 4 == 0 then
				Kit.pulse(light, 2 + row * 0.3)
			end
		end
	end
end

local function bed(parent: Instance, cf: CFrame, sheet: Color3)
	Kit.box(parent, "BedFrame", Vector3.new(7, 1.6, 3.4), cf * CFrame.new(0, 0.8, 0), C.Panel, Enum.Material.Metal, true)
	Kit.box(parent, "Mattress", Vector3.new(6.6, 0.6, 3), cf * CFrame.new(0, 1.9, 0), sheet, Enum.Material.Fabric)
	Kit.box(parent, "Pillow", Vector3.new(1.2, 0.5, 2.4), cf * CFrame.new(-2.6, 2.4, 0), C.White, Enum.Material.Fabric)
end

local function bench(parent: Instance, cf: CFrame, length: number)
	Kit.box(parent, "BenchSeat", Vector3.new(length, 0.6, 2), cf * CFrame.new(0, 1.6, 0), C.PanelDark, Enum.Material.Fabric, true)
	for _, x in { -length / 2 + 0.6, length / 2 - 0.6 } do
		Kit.box(parent, "BenchLeg", Vector3.new(0.6, 1.4, 1.6), cf * CFrame.new(x, 0.7, 0), C.Trim, Enum.Material.Metal)
	end
end

local function desk(parent: Instance, cf: CFrame, width: number)
	Kit.box(parent, "Desk", Vector3.new(width, 2.8, 2.6), cf * CFrame.new(0, 1.4, 0), C.Hull, Enum.Material.Metal, true)
	Kit.wedge(parent, "DeskSlope", Vector3.new(width, 0.8, 1.6), cf * CFrame.new(0, 3.2, 0.4) * CFrame.Angles(0, math.rad(180), 0), C.HullDark, Enum.Material.Metal)
	local screen = Kit.neon(parent, "DeskScreen", Vector3.new(width - 1, 1.6, 0.1), cf * CFrame.new(0, 4.4, 1.1) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(40, 130, 190))
	screen.Transparency = 0.15
end

---------------------------------------------------------------------------
-- Themes
---------------------------------------------------------------------------

local builders: { [string]: (room: ShipLayout.Room, parent: Instance, at: (number, number, number) -> CFrame) -> () } = {}

builders.Operations = function(room, parent, at)
	Kit.cylinder(parent, "MusterTable", 3, 12, at(0, 1.5, 0), C.Hull, Enum.Material.Metal, "Y", true)
	Kit.cylinder(parent, "TableEdge", 0.4, 12.6, at(0, 3.1, 0), C.Cyan, Enum.Material.Neon, "Y")
	Kit.cylinder(parent, "MusterRing", 0.1, 26, at(0, 0.08, 0), Kit.SectionColor.Mid, Enum.Material.Neon, "Y").Transparency = 0.6
	-- Hologram of the ship's position above the table.
	local holo = Kit.ball(parent, "HoloPlanet", 4, at(0, 11, 0), Color3.fromRGB(90, 200, 255), Enum.Material.Neon, 0.45)
	Kit.spin(holo, 20, "Y")
	orbitRing(parent, Vector3.new(room.CenterX, FLOOR_Y + 11, room.CenterZ), 4, 14, Vector3.new(0.4, 0.15, 1.6), C.Cyan, 25)
	for i = 1, 4 do
		local angle = math.rad(45 + i * 90)
		local x, z = math.cos(angle) * 5.3, math.sin(angle) * 5.3
		Kit.neon(parent, "Projector", Vector3.new(0.5, 0.5, 0.5), at(x, 3.3, z), C.Cyan)
	end
	-- Ceiling halo ring light.
	orbitRing(parent, Vector3.new(room.CenterX, FLOOR_Y + room.Height - 1.5, room.CenterZ), 9, 16, Vector3.new(0.4, 0.3, 3.2), Color3.fromRGB(210, 230, 255), 0)
end

builders.Reactor = function(room, parent, at)
	local h = room.Height
	Kit.cylinder(parent, "CorePlatform", 1.5, 18, at(0, 0.75, 0), C.HullDark, Enum.Material.DiamondPlate, "Y", true)
	Kit.cylinder(parent, "CoreHazardRing", 0.2, 22, at(0, 0.1, 0), C.Hazard, Enum.Material.Neon, "Y").Transparency = 0.5
	local core = Kit.cylinder(parent, "ReactorCore", h - 4, 6, at(0, (h - 4) / 2 + 1.5, 0), Color3.fromRGB(120, 230, 255), Enum.Material.Neon, "Y", true)
	Kit.pulse(core, 0.5)
	Kit.cylinder(parent, "CoreGlass", h - 4, 8.5, at(0, (h - 4) / 2 + 1.5, 0), C.Glass, Enum.Material.Glass, "Y", true).Transparency = 0.65
	for index, y in { 5, 10, 15 } do
		orbitRing(parent, Vector3.new(room.CenterX, FLOOR_Y + y, room.CenterZ), 6 + index, 12, Vector3.new(0.5, 0.5, 2.6), if index == 2 then C.Amber else C.Cyan, (if index % 2 == 0 then -1 else 1) * (30 + index * 12))
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.cylinder(parent, "Pylon", h - 2, 1.6, at(sx * 11, (h - 2) / 2, sz * 11), C.Steel, Enum.Material.Metal, "Y", true)
			local tip = Kit.neon(parent, "PylonTip", Vector3.new(2, 0.6, 2), at(sx * 11, h - 3, sz * 11), C.Cyan)
			Kit.pulse(tip, 1)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 220, 255)
	light.Range = 30
	light.Brightness = 2
	light.Parent = core
end

builders.Hydroponics = function(room, parent, at)
	for _, x in { -19, -10 } do
		planter(parent, at(x, 0, 0), 18)
	end
	-- Irrigation pipe and water tank.
	Kit.cylinder(parent, "Irrigation", 14, 0.6, at(-14.5, 9.5, -9), C.Steel, Enum.Material.Metal, "X")
	Kit.cylinder(parent, "WaterTank", 7, 4, at(8, 3.5, 12), C.Glass, Enum.Material.Glass, "Y", true).Transparency = 0.4
	local water = Kit.cylinder(parent, "Water", 5, 3.4, at(8, 3, 12), Color3.fromRGB(70, 170, 255), Enum.Material.Neon, "Y")
	water.Transparency = 0.35
end

builders.Cargo = function(room, parent, at)
	container(parent, at(-14, 0, -14), Color3.fromRGB(150, 70, 50))
	container(parent, at(14, 0, 14) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(60, 100, 140))
	crateStack(parent, at(-15, 0, 14), 1)
	crateStack(parent, at(13, 0, -15), 2)
	-- Overhead gantry rail.
	Kit.box(parent, "GantryRail", Vector3.new(room.SizeX - 6, 0.8, 0.8), at(0, room.Height - 2.5, -6), C.Hazard, Enum.Material.Metal)
	local hook = Kit.box(parent, "GantryHook", Vector3.new(1.2, 3, 1.2), at(6, room.Height - 4.5, -6), C.Trim, Enum.Material.Metal)
	Kit.bob(hook, 0.8)
end

builders.Quarters = function(room, parent, at)
	for _, spot in { { -14, -10 }, { -14, 10 }, { 14, 10 } } do
		local base = at(spot[1], 0, spot[2])
		bed(parent, base, Color3.fromRGB(60, 80, 130))
		Kit.box(parent, "BunkPost", Vector3.new(0.4, 6, 0.4), base * CFrame.new(-3.3, 3, 1.5), C.Steel, Enum.Material.Metal)
		Kit.box(parent, "BunkPost", Vector3.new(0.4, 6, 0.4), base * CFrame.new(3.3, 3, 1.5), C.Steel, Enum.Material.Metal)
		bed(parent, base * CFrame.new(0, 3.6, 0), Color3.fromRGB(90, 60, 120))
	end
	-- Mess table with stools.
	Kit.box(parent, "MessTable", Vector3.new(6, 0.4, 3), at(14, 2.6, -11), C.Panel, Enum.Material.Metal, true)
	Kit.cylinder(parent, "TableLeg", 2.4, 0.6, at(14, 1.2, -11), C.Trim, Enum.Material.Metal, "Y")
	for _, x in { 11, 17 } do
		Kit.cylinder(parent, "Stool", 1.6, 1.4, at(x, 0.8, -11), C.PanelDark, Enum.Material.Fabric, "Y", true)
	end
	Kit.box(parent, "Rug", Vector3.new(9, 0.08, 6), at(14, 0.1, -11), Color3.fromRGB(110, 60, 60), Enum.Material.Fabric)
end

builders.Medical = function(room, parent, at)
	for _, z in { -8, 4 } do
		bed(parent, at(-12, 0, z), Color3.fromRGB(150, 210, 230))
		Kit.cylinder(parent, "IVPole", 6, 0.2, at(-16.5, 3, z - 1.5), C.Steel, Enum.Material.Metal, "Y")
		Kit.ball(parent, "IVBag", 0.9, at(-16.5, 5.8, z - 1.5), Color3.fromRGB(160, 230, 255), Enum.Material.Glass, 0.3)
	end
	-- Scanner arch.
	for _, x in { 6, 14 } do
		Kit.box(parent, "ArchPost", Vector3.new(1, 8, 1.4), at(x, 4, -10), C.PanelLight, Enum.Material.Metal, true)
	end
	Kit.box(parent, "ArchTop", Vector3.new(9, 1.2, 1.6), at(10, 8.4, -10), C.PanelLight, Enum.Material.Metal)
	local scan = Kit.neon(parent, "ScanBeam", Vector3.new(7, 0.15, 1.2), at(10, 4, -10), C.Green)
	scan.Transparency = 0.3
	Kit.bob(scan, 3)
	-- Medical cross sign on the north wall.
	Kit.neon(parent, "CrossV", Vector3.new(1.2, 4, 0.2), at(0, 9, -room.SizeZ / 2 + 0.25), C.Green)
	Kit.neon(parent, "CrossH", Vector3.new(4, 1.2, 0.2), at(0, 9, -room.SizeZ / 2 + 0.25), C.Green)
end

builders.Lab = function(room, parent, at)
	for _, z in { -8, 8 } do
		Kit.box(parent, "Bench", Vector3.new(12, 3, 3), at(7, 1.5, z), C.PanelLight, Enum.Material.SmoothPlastic, true)
		for i = 1, 5 do
			local colors = { C.Green, C.Cyan, C.Violet, C.Amber, C.Red }
			local tube = Kit.cylinder(parent, "SampleTube", 1.6, 0.6, at(2.5 + i * 1.8, 3.8, z), colors[i], Enum.Material.Neon, "Y")
			tube.Transparency = 0.25
		end
	end
	-- Specimen tank with a floating sample.
	Kit.cylinder(parent, "TankBase", 1, 6, at(-9, 0.5, -8), C.HullDark, Enum.Material.Metal, "Y", true)
	Kit.cylinder(parent, "TankGlass", 8, 5, at(-9, 5, -8), C.Glass, Enum.Material.Glass, "Y", true).Transparency = 0.55
	Kit.cylinder(parent, "TankCap", 1, 6, at(-9, 9.5, -8), C.HullDark, Enum.Material.Metal, "Y")
	local specimen = Kit.ball(parent, "Specimen", 2, at(-9, 5, -8), C.Violet, Enum.Material.Neon, 0.1)
	Kit.bob(specimen, 0.8)
	Kit.spin(specimen, 15, "Y")
end

builders.Bridge = function(room, parent, at)
	desk(parent, at(-7, 0, -12) * CFrame.Angles(0, math.rad(-12), 0), 8)
	desk(parent, at(7, 0, -12) * CFrame.Angles(0, math.rad(12), 0), 8)
	-- Captain's chair.
	Kit.cylinder(parent, "ChairBase", 1.2, 2, at(0, 0.6, -3), C.Trim, Enum.Material.Metal, "Y", true)
	Kit.box(parent, "ChairSeat", Vector3.new(2.6, 0.8, 2.4), at(0, 1.8, -3), C.PanelDark, Enum.Material.Fabric)
	Kit.box(parent, "ChairBack", Vector3.new(2.6, 3.6, 0.6), at(0, 3.6, -1.9), C.PanelDark, Enum.Material.Fabric)
	-- Star chart hologram.
	local chart = Kit.cylinder(parent, "StarChart", 0.1, 7, at(0, 6.5, -12), C.Cyan, Enum.Material.Neon, "Y")
	chart.Transparency = 0.6
	Kit.spin(chart, 10, "Y")
end

builders.Observation = function(room, parent, at)
	local hz = room.SizeZ / 2
	local galleryDepth = 12
	-- Gallery (walkable, reached by lift) with glass railing and supports.
	Kit.box(parent, "Gallery", Vector3.new(room.SizeX, 1, galleryDepth), at(0, ShipLayout.GalleryHeight - 0.5, -hz + galleryDepth / 2), C.Hull, Enum.Material.DiamondPlate, true)
	Kit.box(parent, "GalleryRail", Vector3.new(room.SizeX, 3, 0.4), at(0, ShipLayout.GalleryHeight + 1.5, -hz + galleryDepth), C.Glass, Enum.Material.Glass, true).Transparency = 0.5
	Kit.neon(parent, "GalleryEdge", Vector3.new(room.SizeX, 0.2, 0.3), at(0, ShipLayout.GalleryHeight - 1.05, -hz + galleryDepth - 0.2), Kit.SectionColor.Fore)
	for _, x in { -20, 0, 20 } do
		Kit.box(parent, "GallerySupport", Vector3.new(1, ShipLayout.GalleryHeight - 1, 1), at(x, (ShipLayout.GalleryHeight - 1) / 2, -hz + galleryDepth - 1), C.Steel, Enum.Material.Metal, true)
	end
	-- Telescope on the gallery.
	Kit.cylinder(parent, "TelescopeMount", 2, 1, at(-12, ShipLayout.GalleryHeight + 1, -hz + 4), C.Trim, Enum.Material.Metal, "Y")
	Kit.cylinder(parent, "Telescope", 6, 1.4, at(-12, ShipLayout.GalleryHeight + 3, -hz + 3) * CFrame.Angles(math.rad(35), math.rad(90), 0), C.PanelLight, Enum.Material.Metal, "X")
	-- Viewing benches facing the window.
	for _, x in { -12, 12 } do
		bench(parent, at(x, 0, 6), 8)
	end
	-- Lift pads.
	for _, anchor in { "LiftBottom", "LiftTop" } do
		local ox, oz, oy = ShipLayout.anchorOffset(room.Id, anchor)
		local pad = Kit.neon(parent, "LiftPad", Vector3.new(5, 0.2, 5), at(ox - 4, oy + 0.1, oz + 3), Color3.fromRGB(90, 200, 255))
		pad.Transparency = 0.4
		Kit.pulse(pad, 0.8)
	end
end

builders.Comms = function(room, parent, at)
	serverRack(parent, at(9, 0, 9))
	serverRack(parent, at(13, 0, 9))
	serverRack(parent, at(-9, 0, 9))
	Kit.cylinder(parent, "AntennaMast", 12, 1.2, at(-12, 6, -10), C.Steel, Enum.Material.Metal, "Y", true)
	local dish = Kit.cylinder(parent, "Dish", 0.6, 6, at(-12, 12.5, -10) * CFrame.Angles(math.rad(30), 0, 0), C.PanelLight, Enum.Material.Metal, "Y")
	Kit.spin(dish, 12, "Y")
	local tip = Kit.ball(parent, "AntennaTip", 0.8, at(-12, 13.5, -10), C.Red, Enum.Material.Neon)
	Kit.pulse(tip, 1.5)
end

builders.Shelter = function(room, parent, at)
	for _, z in { -8, 8 } do
		bench(parent, at(13, 0, z) * CFrame.Angles(0, math.rad(90), 0), 8)
	end
	Kit.cylinder(parent, "SafeRing", 0.1, 20, at(-2, 0.08, 0), C.Green, Enum.Material.Neon, "Y").Transparency = 0.5
	for _, z in { -11, 11 } do
		Kit.box(parent, "SupplyLocker", Vector3.new(2, 7, 3), at(-12, 3.5, z), Color3.fromRGB(60, 120, 80), Enum.Material.Metal, true)
		Kit.neon(parent, "LockerLight", Vector3.new(0.1, 0.5, 1), at(-10.95, 5.5, z), C.Green)
	end
end

builders.Hangar = function(room, parent, at)
	-- Landing pad markings.
	Kit.box(parent, "Pad", Vector3.new(22, 0.1, 30), at(-14, 0.06, 0), C.HullDark, Enum.Material.DiamondPlate)
	for _, x in { -25, -3 } do
		Kit.hazardStrip(parent, 30, 0.8, 0.12, at(x, 0.12, 0), "Z", 3)
	end
	-- Shuttle.
	local base = at(-14, 0, 0)
	Kit.box(parent, "ShuttleBody", Vector3.new(9, 6, 18), base * CFrame.new(0, 4, 0), C.White, Enum.Material.SmoothPlastic, true)
	Kit.wedge(parent, "ShuttleNose", Vector3.new(9, 6, 6), base * CFrame.new(0, 4, -12) * CFrame.Angles(0, math.rad(180), 0), C.White, Enum.Material.SmoothPlastic)
	Kit.box(parent, "Cockpit", Vector3.new(6, 2.4, 4), base * CFrame.new(0, 7.6, -6), Color3.fromRGB(80, 160, 220), Enum.Material.Glass)
	for _, side in { -1, 1 } do
		Kit.wedge(parent, "Wing", Vector3.new(1, 5, 10), base * CFrame.new(side * 7, 2.6, 3) * CFrame.Angles(0, 0, math.rad(side * 90)), C.PanelLight, Enum.Material.SmoothPlastic)
		Kit.box(parent, "LandingStrut", Vector3.new(0.8, 1.6, 0.8), base * CFrame.new(side * 3.5, 0.8, 5), C.Trim, Enum.Material.Metal)
	end
	Kit.box(parent, "Stripe", Vector3.new(9.1, 0.8, 18.1), base * CFrame.new(0, 3.2, 0), C.Amber, Enum.Material.SmoothPlastic)
	local glow = Kit.cylinder(parent, "ShuttleEngine", 0.6, 4, base * CFrame.new(0, 4, 9.3), C.Cyan, Enum.Material.Neon, "Z")
	Kit.pulse(glow, 0.5)
	-- Hangar floodlights.
	for _, x in { -24, -4 } do
		local lamp = Kit.neon(parent, "Floodlight", Vector3.new(3, 0.4, 3), at(x, room.Height - 1, 0), C.White)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 30
		light.Angle = 70
		light.Brightness = 2
		light.Parent = lamp
	end
end

builders.Engineering = function(room, parent, at)
	Kit.cylinder(parent, "Generator", 10, 7, at(0, 3.5, 10) * CFrame.Angles(0, 0, 0), C.Hull, Enum.Material.Metal, "X", true)
	for _, x in { -3, 0, 3 } do
		local band = Kit.cylinder(parent, "GeneratorBand", 0.5, 7.4, at(x, 3.5, 10), C.Amber, Enum.Material.Neon, "X")
		Kit.spin(band, 90, "X")
	end
	Kit.box(parent, "GeneratorFoot", Vector3.new(11, 1, 6), at(0, 0.5, 10), C.HullDark, Enum.Material.Metal, true)
	-- Pipes along the north wall.
	for index, y in { room.Height - 2, room.Height - 4 } do
		Kit.cylinder(parent, "Pipe", room.SizeX - 6, if index == 1 then 1.8 else 1.2, at(0, y, -room.SizeZ / 2 + 2), if index == 1 then C.Copper else C.Steel, Enum.Material.Metal, "X")
	end
	desk(parent, at(-12, 0, -14) * CFrame.Angles(0, math.rad(90), 0), 6)
end

builders.Junction = function(room, parent, at)
	for i, offset in { { -12, -10 }, { -9, -12 }, { -12, -6 } } do
		Kit.cylinder(parent, "VerticalPipe", room.Height, 1.2 + i * 0.2, at(offset[1], room.Height / 2, offset[2]), if i == 2 then C.Copper else C.Steel, Enum.Material.Metal, "Y", true)
	end
	local valve = Kit.cylinder(parent, "Valve", 0.4, 2.4, at(-10.5, 4, -10) * CFrame.Angles(0, math.rad(45), 0), C.Red, Enum.Material.Metal, "X")
	Kit.spin(valve, 8, "X")
end

builders.Maintenance = function(room, parent, at)
	for _, spot in { { 8, -4 }, { 10, 4 } } do
		Kit.box(parent, "Toolbox", Vector3.new(3, 2, 2), at(spot[1], 1, spot[2]), C.Red, Enum.Material.Metal, true)
	end
	Kit.cylinder(parent, "Pipe", room.SizeZ - 6, 1.6, at(-room.SizeX / 2 + 3, room.Height - 2, 0), C.Copper, Enum.Material.Metal, "Z")
	local fan = Kit.cylinder(parent, "CeilingFan", 0.3, 6, at(0, room.Height - 0.8, 6), C.Steel, Enum.Material.Metal, "Y")
	Kit.spin(fan, 140, "Y")
end

function Props.build(room: ShipLayout.Room, parent: Instance)
	local builder = builders[room.Theme]
	if not builder then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = parent
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(room.CenterX + x, FLOOR_Y + y, room.CenterZ + z)
	end
	builder(room, folder, at)
end

return Props
