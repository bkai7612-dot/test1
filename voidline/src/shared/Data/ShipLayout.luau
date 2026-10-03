--!strict
--[[
	ShipLayout
	The single description of the ASTERION's floor plan. MapService builds
	geometry from it on the server; clients use it for room names, the
	locator and waypoints. Pure data + math (no Roblox types) so it can be
	unit-tested headless.

	Layout: a 5 x 3 grid of cells, CellSpacing studs apart. Each cell holds one
	room. Connections join rooms in neighbouring cells with a straight
	corridor (or a narrow maintenance tunnel). Every room side has at most one
	doorway, centred on that wall.

	Coordinates: X grows east, Z grows south. Rows: -1 = Fore, 0 = Mid, 1 = Aft.
]]

local TableUtil = require(script.Parent.Parent.Utility.TableUtil)

export type Room = {
	Id: string,
	Name: string,
	Col: number,
	Row: number,
	SizeX: number,
	SizeZ: number,
	Height: number,
	Section: string,
	Theme: string,
	-- Derived
	CenterX: number,
	CenterZ: number,
}

export type Connection = {
	Id: string,
	A: string, -- west/north room
	B: string, -- east/south room
	Kind: "Corridor" | "Tunnel",
	Axis: "X" | "Z",
	-- Derived corridor rectangle (axis-aligned), floor coordinates
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
	Width: number,
	Section: string,
}

export type Fixture = {
	Id: string,
	Room: string,
	Anchor: string,
	Kind: string,
	Label: string,
}

export type EscapeStep = { Room: string, Anchor: string, Label: string }
export type EscapeRoute = {
	Id: string,
	Name: string,
	Steps: { EscapeStep },
	ExtractionRoom: string,
}

local ShipLayout = {}

ShipLayout.CellSpacing = 100
ShipLayout.FloorY = 200
ShipLayout.WallHeight = 16
ShipLayout.CorridorWidth = 12
ShipLayout.CorridorHeight = 12
ShipLayout.TunnelWidth = 7
ShipLayout.TunnelHeight = 9
ShipLayout.AnchorInset = 4
ShipLayout.GalleryHeight = 14
ShipLayout.MeetingRoom = "CentralOps"
-- The departure lounge sits behind the ship, level with its decks, so the
-- big window looks straight at the ASTERION's engines.
ShipLayout.LobbyCenter = { X = 0, Y = 200, Z = 440 }

local ROOM_DEFS = {
	-- Fore
	{ Id = "Navigation", Name = "Navigation", Col = -2, Row = -1, SizeX = 56, SizeZ = 48, Theme = "Bridge" },
	{ Id = "Communications", Name = "Communications", Col = -1, Row = -1, SizeX = 48, SizeZ = 48, Theme = "Comms" },
	{ Id = "ObservationDeck", Name = "Observation Deck", Col = 0, Row = -1, SizeX = 64, SizeZ = 52, Theme = "Observation", Height = 30 },
	{ Id = "Laboratory", Name = "Laboratory", Col = 1, Row = -1, SizeX = 52, SizeZ = 48, Theme = "Lab" },
	{ Id = "MedicalBay", Name = "Medical Bay", Col = 2, Row = -1, SizeX = 52, SizeZ = 52, Theme = "Medical" },
	-- Midship
	{ Id = "EscapeHangar", Name = "Escape Hangar", Col = -2, Row = 0, SizeX = 64, SizeZ = 60, Theme = "Hangar", Height = 22 },
	{ Id = "CargoStorage", Name = "Cargo Storage", Col = -1, Row = 0, SizeX = 56, SizeZ = 56, Theme = "Cargo" },
	{ Id = "CentralOps", Name = "Central Operations", Col = 0, Row = 0, SizeX = 64, SizeZ = 64, Theme = "Operations" },
	{ Id = "CrewQuarters", Name = "Crew Quarters", Col = 1, Row = 0, SizeX = 56, SizeZ = 52, Theme = "Quarters" },
	{ Id = "EmergencyShelter", Name = "Emergency Shelter", Col = 2, Row = 0, SizeX = 44, SizeZ = 44, Theme = "Shelter" },
	-- Aft
	{ Id = "Hydroponics", Name = "Hydroponics", Col = -2, Row = 1, SizeX = 60, SizeZ = 56, Theme = "Hydroponics" },
	{ Id = "Engineering", Name = "Engineering", Col = -1, Row = 1, SizeX = 56, SizeZ = 56, Theme = "Engineering" },
	{ Id = "ReactorChamber", Name = "Reactor Chamber", Col = 0, Row = 1, SizeX = 60, SizeZ = 60, Theme = "Reactor", Height = 22 },
	{ Id = "LowerJunction", Name = "Lower Junction", Col = 1, Row = 1, SizeX = 44, SizeZ = 44, Theme = "Junction" },
	{ Id = "MaintenanceHub", Name = "Maintenance Hub", Col = 2, Row = 1, SizeX = 40, SizeZ = 40, Theme = "Maintenance" },
}

local SECTION_BY_ROW = { [-1] = "Fore", [0] = "Mid", [1] = "Aft" }

-- Pairs are written west->east or north->south.
local CONNECTION_DEFS: { { A: string, B: string, Kind: "Corridor" | "Tunnel" } } = {
	{ A = "Navigation", B = "Communications", Kind = "Corridor" },
	{ A = "Communications", B = "ObservationDeck", Kind = "Corridor" },
	{ A = "ObservationDeck", B = "Laboratory", Kind = "Corridor" },
	{ A = "Laboratory", B = "MedicalBay", Kind = "Corridor" },
	{ A = "ObservationDeck", B = "CentralOps", Kind = "Corridor" },
	{ A = "MedicalBay", B = "EmergencyShelter", Kind = "Corridor" },
	{ A = "Navigation", B = "EscapeHangar", Kind = "Corridor" },
	{ A = "EscapeHangar", B = "CargoStorage", Kind = "Corridor" },
	{ A = "CargoStorage", B = "CentralOps", Kind = "Corridor" },
	{ A = "CentralOps", B = "CrewQuarters", Kind = "Corridor" },
	{ A = "CrewQuarters", B = "EmergencyShelter", Kind = "Corridor" },
	{ A = "CargoStorage", B = "Engineering", Kind = "Corridor" },
	{ A = "CentralOps", B = "ReactorChamber", Kind = "Corridor" },
	{ A = "EscapeHangar", B = "Hydroponics", Kind = "Corridor" },
	{ A = "Hydroponics", B = "Engineering", Kind = "Corridor" },
	{ A = "Engineering", B = "ReactorChamber", Kind = "Corridor" },
	{ A = "ReactorChamber", B = "LowerJunction", Kind = "Corridor" },
	{ A = "CrewQuarters", B = "LowerJunction", Kind = "Corridor" },
	{ A = "LowerJunction", B = "MaintenanceHub", Kind = "Corridor" },
	-- Maintenance tunnels: narrow, dark shortcuts.
	{ A = "Communications", B = "CargoStorage", Kind = "Tunnel" },
	{ A = "Laboratory", B = "CrewQuarters", Kind = "Tunnel" },
	{ A = "EmergencyShelter", B = "MaintenanceHub", Kind = "Tunnel" },
}

-- Interactive fixtures that are not crew objectives.
local FIXTURE_DEFS: { Fixture } = {
	{ Id = "Beacon", Room = "CentralOps", Anchor = "C", Kind = "Beacon", Label = "Muster Beacon" },
	{ Id = "SecurityTerminal", Room = "Communications", Anchor = "N1", Kind = "Terminal", Label = "Security Terminal" },
	{ Id = "Breaker.Fore", Room = "Navigation", Anchor = "W1", Kind = "Breaker", Label = "Fore Breaker" },
	{ Id = "Breaker.Mid", Room = "CargoStorage", Anchor = "W2", Kind = "Breaker", Label = "Midship Breaker" },
	{ Id = "Breaker.Aft", Room = "Engineering", Anchor = "S1", Kind = "Breaker", Label = "Aft Breaker" },
	{ Id = "LightsPanel", Room = "Engineering", Anchor = "S2", Kind = "Breaker", Label = "Lighting Bus" },
	{ Id = "Coolant.A", Room = "ReactorChamber", Anchor = "N1", Kind = "Valve", Label = "Coolant Valve A" },
	{ Id = "Coolant.B", Room = "Engineering", Anchor = "N2", Kind = "Valve", Label = "Coolant Valve B" },
	{ Id = "O2.A", Room = "Hydroponics", Anchor = "S1", Kind = "Valve", Label = "Oxygen Mixer A" },
	{ Id = "O2.B", Room = "MedicalBay", Anchor = "E1", Kind = "Valve", Label = "Oxygen Mixer B" },
	{ Id = "NavConsole", Room = "Navigation", Anchor = "N2", Kind = "Console", Label = "Helm Console" },
	-- Room systems nodes (fix point for room-level hazards).
	{ Id = "Node.Navigation", Room = "Navigation", Anchor = "E2", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.Communications", Room = "Communications", Anchor = "W2", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.ObservationDeck", Room = "ObservationDeck", Anchor = "W2", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.Laboratory", Room = "Laboratory", Anchor = "SW", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.MedicalBay", Room = "MedicalBay", Anchor = "N1", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.EscapeHangar", Room = "EscapeHangar", Anchor = "SE", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.CargoStorage", Room = "CargoStorage", Anchor = "NE", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.CentralOps", Room = "CentralOps", Anchor = "SE", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.CrewQuarters", Room = "CrewQuarters", Anchor = "NW", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.EmergencyShelter", Room = "EmergencyShelter", Anchor = "NE", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.Hydroponics", Room = "Hydroponics", Anchor = "W1", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.Engineering", Room = "Engineering", Anchor = "NE", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.ReactorChamber", Room = "ReactorChamber", Anchor = "NW", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.LowerJunction", Room = "LowerJunction", Anchor = "SW", Kind = "Node", Label = "Systems Node" },
	{ Id = "Node.MaintenanceHub", Room = "MaintenanceHub", Anchor = "SE", Kind = "Node", Label = "Systems Node" },
	-- Observation Deck lift between floor and gallery.
	{ Id = "Lift.Bottom", Room = "ObservationDeck", Anchor = "LiftBottom", Kind = "Lift", Label = "Gallery Lift" },
	{ Id = "Lift.Top", Room = "ObservationDeck", Anchor = "LiftTop", Kind = "Lift", Label = "Gallery Lift" },
}

local ESCAPE_ROUTES: { EscapeRoute } = {
	{
		Id = "HangarShuttle",
		Name = "Hangar Shuttle",
		ExtractionRoom = "EscapeHangar",
		Steps = {
			{ Room = "ReactorChamber", Anchor = "S1", Label = "Reroute emergency power" },
			{ Room = "CargoStorage", Anchor = "N2", Label = "Release hangar clamps" },
			{ Room = "EscapeHangar", Anchor = "W1", Label = "Prime shuttle launch" },
		},
	},
	{
		Id = "GalleryLifeboats",
		Name = "Gallery Lifeboats",
		ExtractionRoom = "ObservationDeck",
		Steps = {
			{ Room = "Engineering", Anchor = "E1", Label = "Divert backup power" },
			{ Room = "Navigation", Anchor = "S2", Label = "Plot lifeboat trajectory" },
			{ Room = "ObservationDeck", Anchor = "S1", Label = "Unseal lifeboat bay" },
		},
	},
	{
		Id = "AftCapsules",
		Name = "Aft Drop Capsules",
		ExtractionRoom = "MaintenanceHub",
		Steps = {
			{ Room = "MedicalBay", Anchor = "S2", Label = "Charge capsule cells" },
			{ Room = "LowerJunction", Anchor = "S2", Label = "Pressurize capsule rail" },
			{ Room = "MaintenanceHub", Anchor = "E1", Label = "Arm drop capsules" },
		},
	},
}

-- Rooms with security cameras (used by the evidence system).
ShipLayout.CameraRooms = { "CargoStorage", "ReactorChamber", "CentralOps", "Laboratory", "Hydroponics", "MedicalBay" }

---------------------------------------------------------------------------
-- Derived data
---------------------------------------------------------------------------

local rooms: { Room } = {}
local roomById: { [string]: Room } = {}

for _, def in ROOM_DEFS do
	local room: Room = {
		Id = def.Id,
		Name = def.Name,
		Col = def.Col,
		Row = def.Row,
		SizeX = def.SizeX,
		SizeZ = def.SizeZ,
		Height = (def :: any).Height or ShipLayout.WallHeight,
		Section = SECTION_BY_ROW[def.Row],
		Theme = def.Theme,
		CenterX = def.Col * ShipLayout.CellSpacing,
		CenterZ = def.Row * ShipLayout.CellSpacing,
	}
	table.insert(rooms, room)
	roomById[room.Id] = room
end

local connections: { Connection } = {}
local connectionById: { [string]: Connection } = {}

for _, def in CONNECTION_DEFS do
	local a = roomById[def.A]
	local b = roomById[def.B]
	assert(a and b, "Unknown room in connection " .. def.A .. "/" .. def.B)
	local width = if def.Kind == "Tunnel" then ShipLayout.TunnelWidth else ShipLayout.CorridorWidth
	local axis: "X" | "Z"
	local minX, maxX, minZ, maxZ
	if a.Row == b.Row then
		assert(b.Col == a.Col + 1, "Horizontal connection must join adjacent cells west->east")
		axis = "X"
		minX = a.CenterX + a.SizeX / 2
		maxX = b.CenterX - b.SizeX / 2
		minZ = a.CenterZ - width / 2
		maxZ = a.CenterZ + width / 2
	else
		assert(a.Col == b.Col and b.Row == a.Row + 1, "Vertical connection must join adjacent cells north->south")
		axis = "Z"
		minZ = a.CenterZ + a.SizeZ / 2
		maxZ = b.CenterZ - b.SizeZ / 2
		minX = a.CenterX - width / 2
		maxX = a.CenterX + width / 2
	end
	local connection: Connection = {
		Id = def.A .. "-" .. def.B,
		A = def.A,
		B = def.B,
		Kind = def.Kind,
		Axis = axis,
		MinX = minX,
		MaxX = maxX,
		MinZ = minZ,
		MaxZ = maxZ,
		Width = width,
		Section = a.Section,
	}
	table.insert(connections, connection)
	connectionById[connection.Id] = connection
end

local fixtureById: { [string]: Fixture } = {}
for _, fixture in FIXTURE_DEFS do
	fixtureById[fixture.Id] = fixture
end

local routeById: { [string]: EscapeRoute } = {}
for _, route in ESCAPE_ROUTES do
	routeById[route.Id] = route
end

ShipLayout.Rooms = rooms
ShipLayout.Connections = connections
ShipLayout.Fixtures = FIXTURE_DEFS
ShipLayout.EscapeRoutes = ESCAPE_ROUTES
ShipLayout.Sections = { "Fore", "Mid", "Aft" }

function ShipLayout.getRoom(id: string): Room?
	return roomById[id]
end

function ShipLayout.getConnection(id: string): Connection?
	return connectionById[id]
end

function ShipLayout.getFixture(id: string): Fixture?
	return fixtureById[id]
end

function ShipLayout.getRoute(id: string): EscapeRoute?
	return routeById[id]
end

function ShipLayout.roomsInSection(section: string): { string }
	local list = {}
	for _, room in rooms do
		if room.Section == section then
			table.insert(list, room.Id)
		end
	end
	return list
end

-- Connections touching any room of `section`.
function ShipLayout.connectionsInSection(section: string): { Connection }
	local list = {}
	for _, connection in connections do
		local a = roomById[connection.A]
		local b = roomById[connection.B]
		if a.Section == section or b.Section == section then
			table.insert(list, connection)
		end
	end
	return list
end

-- Which side of `room` a connection enters from: "N" | "S" | "E" | "W".
function ShipLayout.doorSide(roomId: string, connection: Connection): string
	if connection.Axis == "X" then
		return if connection.A == roomId then "E" else "W"
	end
	return if connection.A == roomId then "S" else "N"
end

--[[
	Anchors are named positions inside a room, as offsets from its centre
	(plus optional height). Wall/corner anchors sit AnchorInset studs from the
	walls and away from the doorway centred on each wall.
]]
function ShipLayout.anchorOffset(roomId: string, anchor: string): (number, number, number)
	local room = roomById[roomId]
	assert(room, "Unknown room " .. roomId)
	local hx = room.SizeX / 2
	local hz = room.SizeZ / 2
	local i = ShipLayout.AnchorInset
	local wx = hx - i -- distance to east/west wall anchors
	local wz = hz - i
	local qx = math.max(hx / 2, 9)
	local qz = math.max(hz / 2, 9)

	local table_: { [string]: { number } } = {
		C = { 0, 0, 0 },
		NW = { -wx, -wz, 0 },
		NE = { wx, -wz, 0 },
		SW = { -wx, wz, 0 },
		SE = { wx, wz, 0 },
		N1 = { -qx, -wz, 0 },
		N2 = { qx, -wz, 0 },
		S1 = { -qx, wz, 0 },
		S2 = { qx, wz, 0 },
		W1 = { -wx, -qz, 0 },
		W2 = { -wx, qz, 0 },
		E1 = { wx, -qz, 0 },
		E2 = { wx, qz, 0 },
		-- Observation Deck gallery
		G1 = { 0, -hz + 5, ShipLayout.GalleryHeight },
		LiftBottom = { hx - 6, -hz + 18, 0 },
		LiftTop = { hx - 6, -hz + 6, ShipLayout.GalleryHeight },
	}
	local offset = table_[anchor]
	assert(offset, "Unknown anchor " .. anchor)
	return offset[1], offset[2], offset[3]
end

-- World-space (x, y, z) of an anchor's floor point.
function ShipLayout.anchorPosition(roomId: string, anchor: string): (number, number, number)
	local room = roomById[roomId]
	local ox, oz, oy = ShipLayout.anchorOffset(roomId, anchor)
	return room.CenterX + ox, ShipLayout.FloorY + oy, room.CenterZ + oz
end

-- Area id at a world position: a room id, a connection id, or nil (outside the ship).
-- Second return is true when the area is a connection.
function ShipLayout.areaAt(x: number, y: number, z: number): (string?, boolean)
	if y < ShipLayout.FloorY - 6 or y > ShipLayout.FloorY + 40 then
		return nil, false
	end
	for _, room in rooms do
		if math.abs(x - room.CenterX) <= room.SizeX / 2 and math.abs(z - room.CenterZ) <= room.SizeZ / 2 then
			return room.Id, false
		end
	end
	for _, connection in connections do
		if x >= connection.MinX and x <= connection.MaxX and z >= connection.MinZ and z <= connection.MaxZ then
			return connection.Id, true
		end
	end
	return nil, false
end

-- Human-readable name for any area id.
function ShipLayout.areaName(areaId: string?): string
	if not areaId then
		return "Outside"
	end
	local room = roomById[areaId]
	if room then
		return room.Name
	end
	local connection = connectionById[areaId]
	if connection then
		return if connection.Kind == "Tunnel" then "Maintenance Tunnel" else (connection.Section .. " Corridor")
	end
	return areaId
end

-- Section of any area id.
function ShipLayout.areaSection(areaId: string?): string?
	if not areaId then
		return nil
	end
	local room = roomById[areaId]
	if room then
		return room.Section
	end
	local connection = connectionById[areaId]
	return if connection then connection.Section else nil
end

-- The room an area belongs to for gameplay purposes (connections map to their A room).
function ShipLayout.areaRoom(areaId: string?): string?
	if not areaId then
		return nil
	end
	if roomById[areaId] then
		return areaId
	end
	local connection = connectionById[areaId]
	return if connection then connection.A else nil
end

return TableUtil.deepFreeze(ShipLayout)
