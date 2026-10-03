local ShipLayout = require(Shared.Data.ShipLayout)
local ObjectiveCatalog = require(Shared.Data.ObjectiveCatalog)
local HazardCatalog = require(Shared.Data.HazardCatalog)
local SabotageCatalog = require(Shared.Data.SabotageCatalog)
local EventCatalog = require(Shared.Data.EventCatalog)
local CosmeticCatalog = require(Shared.Data.CosmeticCatalog)
local SettingsSchema = require(Shared.Data.SettingsSchema)
local Config = require(Shared.Config)

test("Every room side has at most one doorway and corridors have length", function()
	local sides = {}
	for _, connection in ShipLayout.Connections do
		for _, roomId in { connection.A, connection.B } do
			local key = roomId .. ":" .. ShipLayout.doorSide(roomId, connection)
			assert(not sides[key], "two doors on " .. key)
			sides[key] = true
		end
		assert(connection.MaxX > connection.MinX and connection.MaxZ > connection.MinZ, "empty corridor " .. connection.Id)
	end
end)

-- Collect every placed anchor: fixtures, objective stations, escape steps.
local function placements()
	local list = {}
	for _, fixture in ShipLayout.Fixtures do
		table.insert(list, { Room = fixture.Room, Anchor = fixture.Anchor, What = "fixture " .. fixture.Id })
	end
	local seenStation = {}
	for _, objective in ObjectiveCatalog.Objectives do
		for stepIndex, step in objective.Steps do
			for altIndex, station in step.Stations do
				table.insert(list, { Room = station.Room, Anchor = station.Anchor, What = ObjectiveCatalog.stationKey(objective.Id, stepIndex, altIndex) })
			end
		end
	end
	for _, route in ShipLayout.EscapeRoutes do
		for i, step in route.Steps do
			table.insert(list, { Room = step.Room, Anchor = step.Anchor, What = "escape " .. route.Id .. "." .. i })
		end
	end
	return list
end

test("Anchors are unique, inside rooms and spaced apart", function()
	local used = {}
	local list = placements()
	for _, p in list do
		assert(ShipLayout.getRoom(p.Room), "unknown room " .. p.Room .. " for " .. p.What)
		local key = p.Room .. "/" .. p.Anchor
		assert(not used[key], key .. " used by both " .. tostring(used[key]) .. " and " .. p.What)
		used[key] = p.What
		local room = ShipLayout.getRoom(p.Room)
		local ox, oz = ShipLayout.anchorOffset(p.Room, p.Anchor)
		assert(math.abs(ox) < room.SizeX / 2 and math.abs(oz) < room.SizeZ / 2, p.What .. " outside room")
	end
	for i, a in list do
		for j = i + 1, #list do
			local b = list[j]
			if a.Room == b.Room then
				local ax, az, ay = ShipLayout.anchorOffset(a.Room, a.Anchor)
				local bx, bz, by = ShipLayout.anchorOffset(b.Room, b.Anchor)
				local d = math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2 + (ay - by) ^ 2)
				assert(d >= 5.5, string.format("%s and %s are only %.1f studs apart", a.What, b.What, d))
			end
		end
	end
end)

test("Wall anchors stay clear of doorways", function()
	for _, p in placements() do
		local room = ShipLayout.getRoom(p.Room)
		local ox, oz, oy = ShipLayout.anchorOffset(p.Room, p.Anchor)
		if oy == 0 then
			for _, connection in ShipLayout.Connections do
				if connection.A == p.Room or connection.B == p.Room then
					local side = ShipLayout.doorSide(p.Room, connection)
					local half = connection.Width / 2 + 2
					local nearWall
					if side == "N" then nearWall = oz < -room.SizeZ / 2 + 8 and math.abs(ox) < half
					elseif side == "S" then nearWall = oz > room.SizeZ / 2 - 8 and math.abs(ox) < half
					elseif side == "W" then nearWall = ox < -room.SizeX / 2 + 8 and math.abs(oz) < half
					else nearWall = ox > room.SizeX / 2 - 8 and math.abs(oz) < half end
					assert(not nearWall, p.What .. " blocks the " .. side .. " doorway of " .. p.Room)
				end
			end
		end
	end
end)

test("Area lookup finds rooms and corridors", function()
	for _, room in ShipLayout.Rooms do
		local area, isConnection = ShipLayout.areaAt(room.CenterX, ShipLayout.FloorY + 2, room.CenterZ)
		assert(area == room.Id and not isConnection, "room lookup " .. room.Id)
	end
	for _, connection in ShipLayout.Connections do
		local x = (connection.MinX + connection.MaxX) / 2
		local z = (connection.MinZ + connection.MaxZ) / 2
		local area, isConnection = ShipLayout.areaAt(x, ShipLayout.FloorY + 2, z)
		assert(area == connection.Id and isConnection, "corridor lookup " .. connection.Id)
	end
	assert(ShipLayout.areaAt(0, 0, 0) == nil, "lobby is outside the ship")
end)

test("Hazard fixtures exist for every possible target", function()
	for _, kind in HazardCatalog.Kinds do
		local targets = { false }
		if kind.Target == "Section" then targets = ShipLayout.Sections end
		if kind.Target == "Room" then
			targets = {}
			for _, room in ShipLayout.Rooms do table.insert(targets, room.Id) end
		end
		for _, target in targets do
			for _, id in HazardCatalog.fixturesFor(kind, if target then target else nil) do
				assert(ShipLayout.getFixture(id), kind.Id .. " needs missing fixture " .. id)
			end
		end
	end
	for _, sabotage in SabotageCatalog.Sabotages do
		local kind = HazardCatalog.get(sabotage.Hazard)
		assert(kind, "sabotage hazard " .. sabotage.Hazard)
		assert(kind.Target == sabotage.Target, "target mismatch for " .. sabotage.Id)
	end
	for _, event in EventCatalog.Events do
		if event.Hazard then
			local kind = HazardCatalog.get(event.Hazard)
			assert(kind and kind.Target == event.Target, "event hazard " .. event.Id)
		end
	end
end)

test("Cosmetic and settings defaults are valid", function()
	for slot, id in CosmeticCatalog.DefaultEquipped do
		local item = CosmeticCatalog.get(id)
		assert(item and item.Slot == slot and item.Source == "Default", "default " .. slot)
	end
	local ids = {}
	for _, item in CosmeticCatalog.Items do
		assert(not ids[item.Id], "duplicate cosmetic " .. item.Id)
		ids[item.Id] = true
		if item.Source == "Credits" then assert((item.Price or 0) > 0, "price " .. item.Id) end
		if item.Source == "Level" then assert((item.UnlockLevel or 0) > 1, "level " .. item.Id) end
	end
	for key, value in SettingsSchema.Defaults do
		assert(SettingsSchema.sanitize(key, value) == value, "default setting " .. key)
	end
	assert(SettingsSchema.sanitize("MasterVolume", 5) == 1, "clamped")
	assert(SettingsSchema.sanitize("MasterVolume", "loud") == nil, "type checked")
	assert(SettingsSchema.sanitize("Nope", 1) == nil, "unknown key")
end)

test("Start rooms and safe rooms exist", function()
	for _, id in Config.Round.StartRooms do assert(ShipLayout.getRoom(id), id) end
	for _, id in Config.Elimination.SafeRooms do assert(ShipLayout.getRoom(id), id) end
	for _, id in ShipLayout.CameraRooms do assert(ShipLayout.getRoom(id), id) end
end)
