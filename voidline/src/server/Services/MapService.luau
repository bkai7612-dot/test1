--!strict
--[[
	MapService
	Builds the ASTERION and the departure lobby procedurally from ShipLayout
	at server boot, then exposes the handles other systems need: anchor parts
	for interactions, doors, room lights, spawn points and teleports.

	Building in code (instead of a hand-made place file) keeps the map in git,
	guarantees every interactive fixture exists where the catalogs expect it,
	and keeps part counts predictable for low-end devices.

	Anchor ids (attribute AnchorId on the panel part, tag InteractAnchor):
	  Station:<stationKey>     objective consoles
	  Fixture:<fixtureId>      breakers, valves, nodes, beacon, lift ...
	  Escape:<routeId>.<step>  extraction consoles
	  DoorPanel:<connectionId> manual door overrides
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local ObjectiveCatalog = require(Shared.Data.ObjectiveCatalog)
local ShipLayout = require(Shared.Data.ShipLayout)
local Logger = require(Shared.Utility.Logger)

local log = Logger.new("MapService")

local MapService = {}

local FLOOR_Y = ShipLayout.FloorY

local SECTION_COLORS: { [string]: Color3 } = {
	Fore = Color3.fromRGB(86, 214, 255),
	Mid = Color3.fromRGB(255, 196, 92),
	Aft = Color3.fromRGB(120, 230, 150),
}

local PALETTE = {
	Floor = Color3.fromRGB(46, 50, 58),
	Wall = Color3.fromRGB(168, 174, 184),
	WallDark = Color3.fromRGB(86, 92, 102),
	Ceiling = Color3.fromRGB(34, 37, 44),
	Trim = Color3.fromRGB(60, 64, 74),
	Tunnel = Color3.fromRGB(70, 66, 60),
	Console = Color3.fromRGB(52, 58, 68),
	Screen = Color3.fromRGB(24, 120, 160),
	Light = Color3.fromRGB(235, 240, 255),
	TunnelLight = Color3.fromRGB(255, 170, 90),
	Door = Color3.fromRGB(255, 80, 80),
	Glass = Color3.fromRGB(150, 190, 230),
}

local KIND_SCREEN: { [string]: Color3 } = {
	Station = Color3.fromRGB(24, 120, 160),
	Breaker = Color3.fromRGB(200, 150, 30),
	Valve = Color3.fromRGB(40, 150, 200),
	Node = Color3.fromRGB(40, 160, 90),
	Terminal = Color3.fromRGB(120, 80, 200),
	Beacon = Color3.fromRGB(200, 50, 50),
	Console = Color3.fromRGB(40, 110, 200),
	Lift = Color3.fromRGB(90, 200, 255),
	Escape = Color3.fromRGB(230, 120, 30),
	DoorPanel = Color3.fromRGB(200, 60, 60),
}

type LightRecord = { Light: PointLight, Fixture: BasePart, Room: string, Section: string, BaseColor: Color3, BaseBrightness: number }
type DoorRecord = { Part: BasePart, Locked: boolean, Connection: ShipLayout.Connection }

local shipFolder: Folder
local lobbyFolder: Folder
local anchors: { [string]: BasePart } = {}
local screens: { [string]: TextLabel } = {}
local lights: { LightRecord } = {}
local doors: { [string]: DoorRecord } = {}
local extractionMarkers: { [string]: BasePart } = {}
local trainingParts: { [string]: BasePart } = {}
local lobbySpawn: SpawnLocation
local lastTeleport: { [Player]: number } = {}

---------------------------------------------------------------------------
-- Geometry helpers
---------------------------------------------------------------------------

local function makePart(props: { [string]: any }, parent: Instance): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "ClassName" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function vertical(position: Vector3): CFrame
	-- Cylinders extend along X; rotate so they stand upright.
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

local function addLight(parent: Instance, position: Vector3, roomId: string, section: string, range: number, color: Color3, brightness: number)
	local fixture = makePart({
		Name = "LightFixture",
		Size = Vector3.new(5, 0.3, 5),
		Position = position,
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, parent)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color
	light.Shadows = false
	light.Parent = fixture
	fixture:SetAttribute(Constants.Attribute.Room, roomId)
	fixture:SetAttribute(Constants.Attribute.Section, section)
	CollectionService:AddTag(fixture, Constants.Tag.RoomLight)
	table.insert(lights, {
		Light = light,
		Fixture = fixture,
		Room = roomId,
		Section = section,
		BaseColor = color,
		BaseBrightness = brightness,
	})
end

local function addSign(parent: Instance, cframe: CFrame, text: string, color: Color3)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(10, 1.6, 0.2),
		CFrame = cframe,
		Color = PALETTE.Trim,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = string.upper(text)
	label.Parent = gui
end

---------------------------------------------------------------------------
-- Consoles (interactive fixtures)
---------------------------------------------------------------------------

-- Builds a console standing at `floorPos`, screen facing `facing` (a point).
local function buildConsole(parent: Instance, anchorId: string, floorPos: Vector3, facing: Vector3, kind: string, label: string): BasePart
	local model = Instance.new("Model")
	model.Name = anchorId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local look = Vector3.new(facing.X, floorPos.Y, facing.Z)
	if (look - floorPos).Magnitude < 0.1 then
		look = floorPos + Vector3.new(0, 0, 1)
	end
	local base = CFrame.lookAt(floorPos, look)

	makePart({
		Name = "Base",
		Size = Vector3.new(2.6, 3, 1.6),
		CFrame = base * CFrame.new(0, 1.5, 0.3),
		Color = PALETTE.Console,
		Material = Enum.Material.Metal,
	}, model)

	local screenColor = KIND_SCREEN[kind] or PALETTE.Screen
	local panel = makePart({
		Name = "Panel",
		Size = Vector3.new(2.4, 1.6, 0.3),
		CFrame = base * CFrame.new(0, 3.4, -0.1) * CFrame.Angles(math.rad(-25), 0, 0),
		Color = screenColor,
		Material = Enum.Material.Glass,
		CanCollide = false,
	}, model)
	model.PrimaryPart = panel

	if kind == "Valve" then
		makePart({
			ClassName = "Part",
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 2.2, 2.2),
			CFrame = base * CFrame.new(1.8, 2, -0.2) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(200, 60, 50),
			Material = Enum.Material.Metal,
			CanCollide = false,
		}, model)
	elseif kind == "Beacon" then
		makePart({
			Name = "Dome",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.4, 2.4, 2.4),
			CFrame = base * CFrame.new(0, 3.6, 0.3),
			Color = Color3.fromRGB(230, 50, 50),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, model)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	gui.Parent = panel
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(8, 14, 22)
	text.BackgroundTransparency = 0.15
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(220, 240, 255)
	text.Text = label
	text.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = text

	panel:SetAttribute(Constants.Attribute.AnchorId, anchorId)
	CollectionService:AddTag(panel, Constants.Tag.InteractAnchor)
	anchors[anchorId] = panel
	screens[anchorId] = text

	model.Parent = parent
	return panel
end

---------------------------------------------------------------------------
-- Rooms
---------------------------------------------------------------------------

local doorsBySide: { [string]: { [string]: ShipLayout.Connection } } = {}

local function indexDoors()
	for _, connection in ShipLayout.Connections do
		for _, roomId in { connection.A, connection.B } do
			doorsBySide[roomId] = doorsBySide[roomId] or {}
			doorsBySide[roomId][ShipLayout.doorSide(roomId, connection)] = connection
		end
	end
end

local function doorHeight(connection: ShipLayout.Connection): number
	return if connection.Kind == "Tunnel" then ShipLayout.TunnelHeight else ShipLayout.CorridorHeight
end

local function buildWalls(room: ShipLayout.Room, parent: Instance)
	local cx, cz = room.CenterX, room.CenterZ
	local hx, hz = room.SizeX / 2, room.SizeZ / 2
	local height = room.Height
	local glassNorth = room.Theme == "Bridge" or room.Theme == "Observation"

	for _, side in { "N", "S", "E", "W" } do
		local alongX = side == "N" or side == "S"
		local length = (if alongX then room.SizeX else room.SizeZ) + 2
		local plane = if side == "N"
			then cz - hz - 0.5
			elseif side == "S" then cz + hz + 0.5
			elseif side == "W" then cx - hx - 0.5
			else cx + hx + 0.5
		local isGlass = glassNorth and side == "N"

		local function segment(a: number, b: number, y0: number, y1: number)
			if b - a <= 0.05 or y1 - y0 <= 0.05 then
				return
			end
			local mid = (a + b) / 2
			local position = if alongX
				then Vector3.new(cx + mid, FLOOR_Y + (y0 + y1) / 2, plane)
				else Vector3.new(plane, FLOOR_Y + (y0 + y1) / 2, cz + mid)
			local size = if alongX then Vector3.new(b - a, y1 - y0, 1) else Vector3.new(1, y1 - y0, b - a)
			makePart({
				Name = "Wall" .. side,
				Size = size,
				Position = position,
				Color = if isGlass then PALETTE.Glass else PALETTE.Wall,
				Material = if isGlass then Enum.Material.Glass else Enum.Material.SmoothPlastic,
				Transparency = if isGlass then 0.55 else 0,
				CastShadow = not isGlass,
			}, parent)
		end

		local door = doorsBySide[room.Id] and doorsBySide[room.Id][side]
		if door then
			local gap = door.Width / 2
			local h = doorHeight(door)
			segment(-length / 2, -gap, 0, height)
			segment(gap, length / 2, 0, height)
			segment(-gap, gap, h, height)
		elseif isGlass then
			-- Window band with solid trim below and above.
			segment(-length / 2, length / 2, 0, 3)
			local p = makePart({
				Name = "WindowTrim",
				Size = if alongX then Vector3.new(length, height - 3, 1) else Vector3.new(1, height - 3, length),
				Position = if alongX
					then Vector3.new(cx, FLOOR_Y + 3 + (height - 3) / 2, plane)
					else Vector3.new(plane, FLOOR_Y + 3 + (height - 3) / 2, cz),
				Color = PALETTE.Glass,
				Material = Enum.Material.Glass,
				Transparency = 0.55,
				CastShadow = false,
			}, parent)
			p.Name = "Window"
		else
			segment(-length / 2, length / 2, 0, height)
		end
	end
end

local function buildRoomShell(room: ShipLayout.Room, parent: Instance)
	local cx, cz = room.CenterX, room.CenterZ
	local accent = SECTION_COLORS[room.Section]

	makePart({
		Name = "Floor",
		Size = Vector3.new(room.SizeX, 1, room.SizeZ),
		Position = Vector3.new(cx, FLOOR_Y - 0.5, cz),
		Color = PALETTE.Floor,
		Material = if room.Theme == "Maintenance" or room.Theme == "Junction"
			then Enum.Material.DiamondPlate
			else Enum.Material.Metal,
	}, parent)
	makePart({
		Name = "Ceiling",
		Size = Vector3.new(room.SizeX + 2, 1, room.SizeZ + 2),
		Position = Vector3.new(cx, FLOOR_Y + room.Height + 0.5, cz),
		Color = PALETTE.Ceiling,
		CastShadow = false,
	}, parent)
	-- Accent floor ring (orientation aid, colour-coded by section).
	for _, offset in { -1, 1 } do
		makePart({
			Name = "AccentStrip",
			Size = Vector3.new(room.SizeX - 2, 0.1, 0.4),
			Position = Vector3.new(cx, FLOOR_Y + 0.05, cz + offset * (room.SizeZ / 2 - 1)),
			Color = accent,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		}, parent)
	end

	buildWalls(room, parent)

	-- Lights: bigger rooms get two.
	local lightY = FLOOR_Y + room.Height - 0.3
	local brightness = if room.Theme == "Maintenance" or room.Theme == "Junction" then 0.9 else 1.4
	local color = if room.Theme == "Shelter" then Color3.fromRGB(200, 255, 215) else PALETTE.Light
	if room.SizeX >= 56 then
		addLight(parent, Vector3.new(cx - room.SizeX / 4, lightY, cz), room.Id, room.Section, 38, color, brightness)
		addLight(parent, Vector3.new(cx + room.SizeX / 4, lightY, cz), room.Id, room.Section, 38, color, brightness)
	else
		addLight(parent, Vector3.new(cx, lightY, cz), room.Id, room.Section, 44, color, brightness)
	end

	-- Room name signs above each doorway, facing inward.
	for side, connection in doorsBySide[room.Id] or ({} :: { [string]: ShipLayout.Connection }) do
		local h = doorHeight(connection) + 1.5
		local cframe
		if side == "N" then
			cframe = CFrame.lookAt(Vector3.new(cx, FLOOR_Y + h, cz - room.SizeZ / 2 + 0.2), Vector3.new(cx, FLOOR_Y + h, cz))
		elseif side == "S" then
			cframe = CFrame.lookAt(Vector3.new(cx, FLOOR_Y + h, cz + room.SizeZ / 2 - 0.2), Vector3.new(cx, FLOOR_Y + h, cz))
		elseif side == "W" then
			cframe = CFrame.lookAt(Vector3.new(cx - room.SizeX / 2 + 0.2, FLOOR_Y + h, cz), Vector3.new(cx, FLOOR_Y + h, cz))
		else
			cframe = CFrame.lookAt(Vector3.new(cx + room.SizeX / 2 - 0.2, FLOOR_Y + h, cz), Vector3.new(cx, FLOOR_Y + h, cz))
		end
		-- Readable from inside the room, above the doorway.
		addSign(parent, cframe * CFrame.new(0, 0, -0.3), room.Name, accent)
	end
end

-- Decorative props per theme. Kept clear of anchors and doorway paths.
local function buildProps(room: ShipLayout.Room, parent: Instance)
	local cx, cz = room.CenterX, room.CenterZ
	local function at(x: number, y: number, z: number): Vector3
		return Vector3.new(cx + x, FLOOR_Y + y, cz + z)
	end
	local function box(name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?)
		makePart({ Name = name, Size = size, Position = pos, Color = color, Material = material or Enum.Material.Metal }, parent)
	end
	local theme = room.Theme

	if theme == "Operations" then
		makePart({
			Name = "MusterTable",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 12, 12),
			CFrame = vertical(at(0, 1.5, 0)),
			Color = Color3.fromRGB(70, 76, 88),
			Material = Enum.Material.Metal,
		}, parent)
		makePart({
			Name = "MusterRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 30, 30),
			CFrame = vertical(at(0, 0.06, 0)),
			Color = SECTION_COLORS.Mid,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CanCollide = false,
			CanQuery = false,
		}, parent)
	elseif theme == "Reactor" then
		makePart({
			Name = "ReactorCore",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(room.Height - 2, 9, 9),
			CFrame = vertical(at(0, (room.Height - 2) / 2, 0)),
			Color = Color3.fromRGB(120, 220, 255),
			Material = Enum.Material.Neon,
		}, parent)
		makePart({
			Name = "CoreShield",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 13, 13),
			CFrame = vertical(at(0, 2, 0)),
			Color = PALETTE.WallDark,
			Material = Enum.Material.Metal,
		}, parent)
	elseif theme == "Hydroponics" then
		for _, x in { -20, -10 } do
			box("Planter", Vector3.new(5, 2.5, 18), at(x, 1.25, 0), Color3.fromRGB(90, 70, 50), Enum.Material.Wood)
			box("Plants", Vector3.new(4.4, 1, 17), at(x, 3, 0), Color3.fromRGB(80, 190, 90), Enum.Material.Grass)
		end
	elseif theme == "Cargo" then
		for _, p in { { -12, -12 }, { 12, 12 }, { -12, 12 }, { 12, -12 } } do
			box("Crate", Vector3.new(5, 5, 5), at(p[1], 2.5, p[2]), Color3.fromRGB(150, 120, 70), Enum.Material.WoodPlanks)
		end
		box("Crate", Vector3.new(4, 4, 4), at(-12, 7, -12), Color3.fromRGB(110, 120, 90), Enum.Material.Metal)
	elseif theme == "Quarters" then
		for _, p in { { -14, -10 }, { -14, 10 }, { 14, 10 } } do
			box("Bunk", Vector3.new(8, 2, 4), at(p[1], 1, p[2]), Color3.fromRGB(70, 90, 130), Enum.Material.Fabric)
			box("BunkTop", Vector3.new(8, 0.6, 4), at(p[1], 5, p[2]), Color3.fromRGB(70, 90, 130), Enum.Material.Fabric)
		end
	elseif theme == "Medical" then
		for _, z in { -8, 8 } do
			box("MedBed", Vector3.new(7, 2.4, 3.4), at(-10, 1.2, z), Color3.fromRGB(220, 225, 230))
		end
	elseif theme == "Lab" then
		for _, z in { -7, 7 } do
			box("Bench", Vector3.new(12, 3, 3), at(6, 1.5, z), Color3.fromRGB(200, 205, 210))
		end
	elseif theme == "Bridge" then
		box("HelmDesk", Vector3.new(16, 3, 3), at(0, 1.5, -12), Color3.fromRGB(60, 66, 78))
	elseif theme == "Comms" then
		for _, p in { { 8, 8 }, { -8, 8 } } do
			makePart({
				Name = "Antenna",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(12, 1.4, 1.4),
				CFrame = vertical(at(p[1], 6, p[2])),
				Color = Color3.fromRGB(160, 165, 175),
				Material = Enum.Material.Metal,
			}, parent)
		end
	elseif theme == "Shelter" then
		for _, z in { -10, 10 } do
			box("Bench", Vector3.new(3, 2, 10), at(14, 1, z), Color3.fromRGB(60, 120, 80), Enum.Material.Fabric)
		end
	elseif theme == "Hangar" then
		box("ShuttleBody", Vector3.new(12, 6, 18), at(-12, 3, 0), Color3.fromRGB(220, 220, 225))
		box("ShuttleCockpit", Vector3.new(8, 3, 4), at(-12, 5, -10), Color3.fromRGB(80, 160, 220), Enum.Material.Glass)
		box("ShuttleFin", Vector3.new(1, 5, 5), at(-12, 8, 7), Color3.fromRGB(230, 120, 30))
	elseif theme == "Engineering" then
		box("Generator", Vector3.new(8, 5, 6), at(0, 2.5, 10), Color3.fromRGB(90, 96, 110))
		makePart({
			Name = "Pipe",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(room.SizeX - 4, 1.6, 1.6),
			Position = at(0, room.Height - 2, -14),
			Color = Color3.fromRGB(150, 110, 60),
			Material = Enum.Material.Metal,
			CanCollide = false,
		}, parent)
	elseif theme == "Junction" or theme == "Maintenance" then
		makePart({
			Name = "Pipe",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(room.Height, 2, 2),
			CFrame = vertical(at(-room.SizeX / 2 + 3, room.Height / 2, -room.SizeZ / 2 + 10)),
			Color = Color3.fromRGB(150, 110, 60),
			Material = Enum.Material.Metal,
		}, parent)
	elseif theme == "Observation" then
		-- Gallery along the north window, reached by lift.
		local galleryDepth = 12
		local hz = room.SizeZ / 2
		box(
			"Gallery",
			Vector3.new(room.SizeX, 1, galleryDepth),
			at(0, ShipLayout.GalleryHeight - 0.5, -hz + galleryDepth / 2),
			Color3.fromRGB(60, 64, 74),
			Enum.Material.DiamondPlate
		)
		makePart({
			Name = "GalleryRail",
			Size = Vector3.new(room.SizeX, 3, 0.4),
			Position = at(0, ShipLayout.GalleryHeight + 1.5, -hz + galleryDepth),
			Color = PALETTE.Glass,
			Material = Enum.Material.Glass,
			Transparency = 0.5,
		}, parent)
		addLight(parent, at(0, room.Height - 0.3, -hz + 6), room.Id, room.Section, 30, PALETTE.Light, 1)
	end
end

---------------------------------------------------------------------------
-- Corridors and doors
---------------------------------------------------------------------------

local function buildConnection(connection: ShipLayout.Connection, parent: Instance)
	local model = folder(connection.Id, parent)
	local isTunnel = connection.Kind == "Tunnel"
	local height = doorHeight(connection)
	local width = connection.Width
	local alongX = connection.Axis == "X"
	local length = if alongX then connection.MaxX - connection.MinX else connection.MaxZ - connection.MinZ
	local cx = (connection.MinX + connection.MaxX) / 2
	local cz = (connection.MinZ + connection.MaxZ) / 2
	local wallColor = if isTunnel then PALETTE.Tunnel else PALETTE.WallDark

	makePart({
		Name = "Floor",
		Size = if alongX then Vector3.new(length, 1, width) else Vector3.new(width, 1, length),
		Position = Vector3.new(cx, FLOOR_Y - 0.5, cz),
		Color = if isTunnel then PALETTE.Tunnel else PALETTE.Floor,
		Material = if isTunnel then Enum.Material.DiamondPlate else Enum.Material.Metal,
	}, model)
	makePart({
		Name = "Ceiling",
		Size = if alongX then Vector3.new(length, 1, width + 2) else Vector3.new(width + 2, 1, length),
		Position = Vector3.new(cx, FLOOR_Y + height + 0.5, cz),
		Color = PALETTE.Ceiling,
		CastShadow = false,
	}, model)
	for _, sign in { -1, 1 } do
		local offset = sign * (width / 2 + 0.5)
		makePart({
			Name = "Wall",
			Size = if alongX then Vector3.new(length, height, 1) else Vector3.new(1, height, length),
			Position = if alongX
				then Vector3.new(cx, FLOOR_Y + height / 2, cz + offset)
				else Vector3.new(cx + offset, FLOOR_Y + height / 2, cz),
			Color = wallColor,
		}, model)
		-- Floor guide strips.
		makePart({
			Name = "GuideStrip",
			Size = if alongX then Vector3.new(length, 0.1, 0.3) else Vector3.new(0.3, 0.1, length),
			Position = if alongX
				then Vector3.new(cx, FLOOR_Y + 0.05, cz + sign * (width / 2 - 0.6))
				else Vector3.new(cx + sign * (width / 2 - 0.6), FLOOR_Y + 0.05, cz),
			Color = if isTunnel then PALETTE.TunnelLight else SECTION_COLORS[connection.Section],
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		}, model)
	end
	addLight(
		model,
		Vector3.new(cx, FLOOR_Y + height - 0.3, cz),
		connection.Id,
		connection.Section,
		if isTunnel then 18 else 26,
		if isTunnel then PALETTE.TunnelLight else PALETTE.Light,
		if isTunnel then 0.7 else 1
	)

	-- Door at the A end (in the room's wall gap). Open by default.
	local doorPos = if alongX
		then Vector3.new(connection.MinX + 0.5, FLOOR_Y + height / 2, cz)
		else Vector3.new(cx, FLOOR_Y + height / 2, connection.MinZ + 0.5)
	local door = makePart({
		Name = "Door",
		Size = if alongX then Vector3.new(0.6, height, width) else Vector3.new(width, height, 0.6),
		Position = doorPos,
		Color = PALETTE.Door,
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, model)
	door:SetAttribute("ConnectionId", connection.Id)
	CollectionService:AddTag(door, Constants.Tag.Door)
	doors[connection.Id] = { Part = door, Locked = false, Connection = connection }

	-- Manual override panel on the corridor wall just past the door.
	local panelFloor, panelFacing
	if alongX then
		panelFloor = Vector3.new(connection.MinX + 3, FLOOR_Y, cz - width / 2 + 1.2)
		panelFacing = Vector3.new(connection.MinX + 3, FLOOR_Y, cz)
	else
		panelFloor = Vector3.new(cx - width / 2 + 1.2, FLOOR_Y, connection.MinZ + 3)
		panelFacing = Vector3.new(cx, FLOOR_Y, connection.MinZ + 3)
	end
	buildConsole(model, "DoorPanel:" .. connection.Id, panelFloor, panelFacing, "DoorPanel", "DOOR CONTROL")
end

---------------------------------------------------------------------------
-- Interactive fixtures, stations and escape consoles
---------------------------------------------------------------------------

local function anchorWorld(roomId: string, anchor: string): (Vector3, Vector3)
	local x, y, z = ShipLayout.anchorPosition(roomId, anchor)
	local room = ShipLayout.getRoom(roomId) :: ShipLayout.Room
	local floor = Vector3.new(x, y, z)
	local facing = Vector3.new(room.CenterX, y, room.CenterZ)
	if anchor == "G1" or anchor == "LiftTop" then
		-- Gallery consoles face south, into the room.
		facing = floor + Vector3.new(0, 0, 10)
	end
	return floor, facing
end

local function buildInteractives(parent: Instance)
	local fixturesFolder = folder("Fixtures", parent)
	for _, fixture in ShipLayout.Fixtures do
		local floor, facing = anchorWorld(fixture.Room, fixture.Anchor)
		if fixture.Kind == "Beacon" then
			floor += Vector3.new(0, 3, 0) -- sits on the muster table
		end
		buildConsole(fixturesFolder, "Fixture:" .. fixture.Id, floor, facing, fixture.Kind, fixture.Label)
		if fixture.Kind == "Lift" then
			makePart({
				Name = "LiftPad",
				Size = Vector3.new(5, 0.2, 5),
				Position = floor + Vector3.new(0, 0.1, 3),
				Color = KIND_SCREEN.Lift,
				Material = Enum.Material.Neon,
				Transparency = 0.4,
				CanCollide = false,
				CanQuery = false,
			}, fixturesFolder)
		end
	end

	local stationsFolder = folder("Stations", parent)
	for _, objective in ObjectiveCatalog.Objectives do
		for stepIndex, step in objective.Steps do
			for altIndex, station in step.Stations do
				local key = ObjectiveCatalog.stationKey(objective.Id, stepIndex, altIndex)
				local floor, facing = anchorWorld(station.Room, station.Anchor)
				local panel = buildConsole(stationsFolder, "Station:" .. key, floor, facing, "Station", "STANDBY")
				CollectionService:AddTag(panel, Constants.Tag.Station)
			end
		end
	end

	local escapeFolder = folder("Escape", parent)
	for _, route in ShipLayout.EscapeRoutes do
		for index, step in route.Steps do
			local floor, facing = anchorWorld(step.Room, step.Anchor)
			buildConsole(escapeFolder, string.format("Escape:%s.%d", route.Id, index), floor, facing, "Escape", "SEALED")
		end
		local room = ShipLayout.getRoom(route.ExtractionRoom) :: ShipLayout.Room
		local marker = makePart({
			Name = "Extraction_" .. route.Id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, math.min(room.SizeX, room.SizeZ) - 6, math.min(room.SizeX, room.SizeZ) - 6),
			CFrame = vertical(Vector3.new(room.CenterX, FLOOR_Y + 0.08, room.CenterZ)),
			Color = Color3.fromRGB(90, 255, 160),
			Material = Enum.Material.Neon,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		}, escapeFolder)
		extractionMarkers[route.Id] = marker
	end
end

---------------------------------------------------------------------------
-- Lobby (Departure Concourse) with a training bay
---------------------------------------------------------------------------

local function buildLobby(parent: Instance)
	local c = ShipLayout.LobbyCenter
	local center = Vector3.new(c.X, c.Y, c.Z)
	local sizeX, sizeZ, height = 140, 100, 26

	makePart({
		Name = "Floor",
		Size = Vector3.new(sizeX, 1, sizeZ),
		Position = center - Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(56, 60, 70),
		Material = Enum.Material.Metal,
	}, parent)
	makePart({
		Name = "Ceiling",
		Size = Vector3.new(sizeX + 2, 1, sizeZ + 2),
		Position = center + Vector3.new(0, height + 0.5, 0),
		Color = PALETTE.Ceiling,
		CastShadow = false,
	}, parent)
	local walls: { { Offset: Vector3, Size: Vector3, Glass: boolean } } = {
		{ Offset = Vector3.new(0, height / 2, -sizeZ / 2 - 0.5), Size = Vector3.new(sizeX + 2, height, 1), Glass = true },
		{ Offset = Vector3.new(0, height / 2, sizeZ / 2 + 0.5), Size = Vector3.new(sizeX + 2, height, 1), Glass = false },
		{ Offset = Vector3.new(-sizeX / 2 - 0.5, height / 2, 0), Size = Vector3.new(1, height, sizeZ), Glass = false },
		{ Offset = Vector3.new(sizeX / 2 + 0.5, height / 2, 0), Size = Vector3.new(1, height, sizeZ), Glass = false },
	}
	for _, spec in walls do
		local glass = spec.Glass
		makePart({
			Name = if glass then "Window" else "Wall",
			Size = spec.Size,
			Position = center + spec.Offset,
			Color = if glass then PALETTE.Glass else PALETTE.Wall,
			Material = if glass then Enum.Material.Glass else Enum.Material.SmoothPlastic,
			Transparency = if glass then 0.5 else 0,
		}, parent)
	end
	for _, x in { -45, 0, 45 } do
		for _, z in { -25, 25 } do
			addLight(parent, center + Vector3.new(x, height - 0.3, z), "Lobby", "Lobby", 50, PALETTE.Light, 1.3)
		end
	end

	lobbySpawn = Instance.new("SpawnLocation")
	lobbySpawn.Name = "LobbySpawn"
	lobbySpawn.Anchored = true
	lobbySpawn.Neutral = true
	lobbySpawn.Duration = 0
	lobbySpawn.Size = Vector3.new(12, 1, 12)
	lobbySpawn.Position = center + Vector3.new(-20, 0, 10)
	lobbySpawn.Color = Color3.fromRGB(86, 214, 255)
	lobbySpawn.Material = Enum.Material.Neon
	lobbySpawn.Transparency = 0.6
	lobbySpawn.TopSurface = Enum.SurfaceType.Smooth
	lobbySpawn.Parent = parent

	addSign(
		parent,
		CFrame.lookAt(center + Vector3.new(0, 18, sizeZ / 2 - 0.3), center + Vector3.new(0, 18, 0)),
		"VOIDLINE  //  ASTERION DEPARTURES",
		Color3.fromRGB(86, 214, 255)
	)

	-- Training bay (east end): client-only practice props for the tutorial.
	local bay = folder("TrainingBay", parent)
	local bayCenter = center + Vector3.new(45, 0, 0)
	makePart({
		Name = "BayFloor",
		Size = Vector3.new(36, 0.2, 60),
		Position = bayCenter + Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(40, 70, 90),
		Material = Enum.Material.DiamondPlate,
		CanCollide = false,
	}, bay)
	addSign(bay, CFrame.lookAt(bayCenter + Vector3.new(-17.6, 10, 0), bayCenter + Vector3.new(0, 10, 0)), "TRAINING BAY", SECTION_COLORS.Fore)

	local function training(id: string, offset: Vector3, kind: string, label: string)
		local floor = bayCenter + offset
		local panel = buildConsole(bay, "Training:" .. id, floor, bayCenter + Vector3.new(-30, 0, offset.Z), kind, label)
		panel:SetAttribute("TrainingId", id)
		trainingParts[id] = panel
	end
	training("Console", Vector3.new(10, 0, -20), "Station", "PRACTICE CONSOLE")
	training("Breaker", Vector3.new(10, 0, -6), "Breaker", "PRACTICE BREAKER")
	training("Beacon", Vector3.new(10, 0, 22), "Beacon", "PRACTICE BEACON")

	local pod = makePart({
		Name = "PracticePod",
		Size = Vector3.new(3, 6, 3),
		Position = bayCenter + Vector3.new(0, 3, 8),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
	}, bay)
	pod:SetAttribute("TrainingId", "Pod")
	trainingParts.Pod = pod
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local function configureLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(42, 46, 58)
	Lighting.OutdoorAmbient = Color3.fromRGB(30, 32, 44)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 100000
end

function MapService.Init()
	local started = os.clock()
	indexDoors()
	configureLighting()

	local activeMap = workspace:FindFirstChild("ActiveMap") or folder("ActiveMap", workspace)
	local lobbyRoot = workspace:FindFirstChild("Lobby") or folder("Lobby", workspace)

	shipFolder = folder("ASTERION", activeMap)
	lobbyFolder = folder("Concourse", lobbyRoot)

	local roomsFolder = folder("Rooms", shipFolder)
	for _, room in ShipLayout.Rooms do
		local roomFolder = folder(room.Id, roomsFolder)
		buildRoomShell(room, roomFolder)
		buildProps(room, roomFolder)
	end
	local connectionsFolder = folder("Connections", shipFolder)
	for _, connection in ShipLayout.Connections do
		buildConnection(connection, connectionsFolder)
	end
	buildInteractives(shipFolder)
	buildLobby(lobbyFolder)

	local count = 0
	for _, d in shipFolder:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	log:Info(string.format("Built ASTERION (%d parts) and lobby in %.0f ms", count, (os.clock() - started) * 1000))
end

function MapService.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function MapService.GetAnchor(anchorId: string): BasePart?
	return anchors[anchorId]
end

-- Registers a runtime anchor (pods, characters). Pass nil to remove.
function MapService.SetAnchor(anchorId: string, part: BasePart?)
	local existing = anchors[anchorId]
	if existing and existing ~= part and existing.Parent then
		CollectionService:RemoveTag(existing, Constants.Tag.InteractAnchor)
	end
	if part then
		anchors[anchorId] = part
		part:SetAttribute(Constants.Attribute.AnchorId, anchorId)
		CollectionService:AddTag(part, Constants.Tag.InteractAnchor)
	else
		anchors[anchorId] = nil
	end
end

function MapService.SetScreen(anchorId: string, text: string, color: Color3?)
	local label = screens[anchorId]
	if not label then
		return
	end
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(220, 240, 255)
end

function MapService.GetLobbySpawn(): CFrame
	return lobbySpawn.CFrame + Vector3.new(0, 4, 0)
end

function MapService.GetTrainingParts(): { [string]: BasePart }
	return trainingParts
end

function MapService.AreaAt(position: Vector3): string?
	local area = ShipLayout.areaAt(position.X, position.Y, position.Z)
	return area
end

function MapService.RoomCenter(roomId: string): Vector3
	local room = ShipLayout.getRoom(roomId) :: ShipLayout.Room
	return Vector3.new(room.CenterX, FLOOR_Y, room.CenterZ)
end

-- `count` standing positions in a ring around a room's centre, facing inward.
function MapService.SpawnRing(roomId: string, count: number, radius: number?): { CFrame }
	local center = MapService.RoomCenter(roomId)
	local r = radius or 9
	local list = {}
	for i = 1, math.max(count, 1) do
		local angle = (i / math.max(count, 1)) * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * r, 3.5, math.sin(angle) * r)
		table.insert(list, CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)))
	end
	return list
end

function MapService.MeetingPositions(count: number): { CFrame }
	return MapService.SpawnRing(ShipLayout.MeetingRoom, count, 10)
end

---------------------------------------------------------------------------
-- Teleport (with streaming pre-load and anti-cheat grace)
---------------------------------------------------------------------------

function MapService.Teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if not character or not character.Parent then
		return
	end
	lastTeleport[player] = os.clock()
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 2)
	end)
	if character.Parent then
		lastTeleport[player] = os.clock()
		character:PivotTo(cframe)
	end
end

function MapService.GetLastTeleport(player: Player): number
	return lastTeleport[player] or 0
end

function MapService.MarkTeleported(player: Player)
	lastTeleport[player] = os.clock()
end

---------------------------------------------------------------------------
-- Doors
---------------------------------------------------------------------------

function MapService.SetDoorLocked(connectionId: string, locked: boolean)
	local record = doors[connectionId]
	if not record or record.Locked == locked then
		return
	end
	record.Locked = locked
	record.Part.CanCollide = locked
	record.Part.CanQuery = locked
	record.Part.Transparency = if locked then 0.25 else 1
	MapService.SetScreen("DoorPanel:" .. connectionId, if locked then "LOCKED - HOLD TO OVERRIDE" else "DOOR CONTROL")
end

function MapService.IsDoorLocked(connectionId: string): boolean
	local record = doors[connectionId]
	return record ~= nil and record.Locked
end

function MapService.UnlockAllDoors()
	for id in doors do
		MapService.SetDoorLocked(id, false)
	end
end

---------------------------------------------------------------------------
-- Lighting
---------------------------------------------------------------------------

export type LightMode = "Normal" | "Off" | "Dim" | "Alarm"

local function applyLight(record: LightRecord, mode: LightMode)
	if mode == "Normal" then
		record.Light.Enabled = true
		record.Light.Color = record.BaseColor
		record.Light.Brightness = record.BaseBrightness
		record.Fixture.Color = record.BaseColor
		record.Fixture.Material = Enum.Material.Neon
	elseif mode == "Off" then
		record.Light.Enabled = false
		record.Fixture.Color = Color3.fromRGB(30, 30, 34)
		record.Fixture.Material = Enum.Material.SmoothPlastic
	elseif mode == "Dim" then
		record.Light.Enabled = true
		record.Light.Color = record.BaseColor
		record.Light.Brightness = record.BaseBrightness * 0.25
		record.Fixture.Color = record.BaseColor:Lerp(Color3.new(0, 0, 0), 0.6)
	elseif mode == "Alarm" then
		record.Light.Enabled = true
		record.Light.Color = Color3.fromRGB(255, 70, 60)
		record.Light.Brightness = record.BaseBrightness * 0.9
		record.Fixture.Color = Color3.fromRGB(255, 70, 60)
		record.Fixture.Material = Enum.Material.Neon
	end
end

-- Applies `mode` to lights matching `filter` (room id, section, or nil for the whole ship).
function MapService.SetLights(mode: LightMode, filter: { Room: string?, Section: string? }?)
	for _, record in lights do
		if record.Section ~= "Lobby" then
			local matches = filter == nil
				or (filter.Room ~= nil and record.Room == filter.Room)
				or (filter.Section ~= nil and record.Section == filter.Section)
			if matches then
				applyLight(record, mode)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Extraction markers and reset
---------------------------------------------------------------------------

function MapService.SetExtractionMarker(routeId: string, visible: boolean)
	local marker = extractionMarkers[routeId]
	if marker then
		marker.Transparency = if visible then 0.35 else 1
	end
end

function MapService.ResetShip()
	MapService.UnlockAllDoors()
	MapService.SetLights("Normal", nil)
	for routeId in extractionMarkers do
		MapService.SetExtractionMarker(routeId, false)
	end
	for anchorId, label in screens do
		if string.sub(anchorId, 1, 8) == "Station:" then
			label.Text = "STANDBY"
			label.TextColor3 = Color3.fromRGB(220, 240, 255)
		elseif string.sub(anchorId, 1, 7) == "Escape:" then
			label.Text = "SEALED"
			label.TextColor3 = Color3.fromRGB(220, 240, 255)
		end
	end
end

function MapService.GetShipFolder(): Folder
	return shipFolder
end

return MapService
