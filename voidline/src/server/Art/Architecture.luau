--!strict
--[[
	Architecture
	Detail layer on top of MapService's structural shell: floor insets and
	trims, baseboards, accent light strips, wall pillars, corner columns,
	ceiling beams with glowing light panels, chunky door frames with hazard
	stripes, and corridor ribs with pipes.

	Nothing here changes walkable space beyond a few studs at the walls, and
	all detail stays clear of doorways and console anchors (consoles stand
	AnchorInset studs from the walls; pillars protrude less than 1 stud).
	Light panels are registered through `registerFixture` so power failures
	turn them off along with the room's lights.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShipLayout = require(Shared.Data.ShipLayout)

local Kit = require(script.Parent.Kit)

local Architecture = {}

export type Context = {
	registerFixture: (part: BasePart, room: string, section: string) -> (),
	doorsBySide: { [string]: ShipLayout.Connection },
}

local FLOOR_Y = ShipLayout.FloorY

local function doorHeight(connection: ShipLayout.Connection): number
	return if connection.Kind == "Tunnel" then ShipLayout.TunnelHeight else ShipLayout.CorridorHeight
end

-- Splits a wall of `length` into solid spans around an optional centred gap.
local function spans(length: number, gap: number?): { { number } }
	if not gap then
		return { { -length / 2, length / 2 } }
	end
	return { { -length / 2, -gap / 2 }, { gap / 2, length / 2 } }
end

-- Places something along a wall: `along` offset from the wall centre, `inset` into the room.
local function wallCFrame(room: ShipLayout.Room, side: string, along: number, y: number, inset: number): CFrame
	local cx, cz = room.CenterX, room.CenterZ
	local hx, hz = room.SizeX / 2, room.SizeZ / 2
	local position
	if side == "N" then
		position = Vector3.new(cx + along, y, cz - hz + inset)
	elseif side == "S" then
		position = Vector3.new(cx + along, y, cz + hz - inset)
	elseif side == "W" then
		position = Vector3.new(cx - hx + inset, y, cz + along)
	else
		position = Vector3.new(cx + hx - inset, y, cz + along)
	end
	-- Face into the room.
	return CFrame.lookAt(position, Vector3.new(cx, y, cz))
end

function Architecture.decorateRoom(room: ShipLayout.Room, parent: Instance, ctx: Context)
	local folder = Instance.new("Folder")
	folder.Name = "Detail"
	folder.Parent = parent
	local cx, cz = room.CenterX, room.CenterZ
	local height = room.Height
	local accent = Kit.SectionColor[room.Section]
	local isService = room.Theme == "Maintenance" or room.Theme == "Junction"

	-- Floor: raised inset panel and perimeter trim.
	Kit.box(folder, "FloorInset", Vector3.new(room.SizeX - 12, 0.1, room.SizeZ - 12), CFrame.new(cx, FLOOR_Y + 0.05, cz), if isService then Kit.Color.HullDark else Kit.Color.FloorInset, Enum.Material.DiamondPlate)
	for _, offset in { -1, 1 } do
		Kit.box(folder, "FloorTrim", Vector3.new(room.SizeX - 12, 0.12, 0.6), CFrame.new(cx, FLOOR_Y + 0.06, cz + offset * (room.SizeZ / 2 - 6)), Kit.Color.Trim, Enum.Material.Metal)
		Kit.box(folder, "FloorTrim", Vector3.new(0.6, 0.12, room.SizeZ - 12), CFrame.new(cx + offset * (room.SizeX / 2 - 6), FLOOR_Y + 0.06, cz), Kit.Color.Trim, Enum.Material.Metal)
	end

	for _, side in { "N", "S", "E", "W" } do
		local alongX = side == "N" or side == "S"
		local isWindow = side == "N" and (room.Theme == "Bridge" or room.Theme == "Observation")
		local length = if alongX then room.SizeX else room.SizeZ
		local door = ctx.doorsBySide[side]
		local gap = if door then door.Width + 3 else nil
		for _, span in spans(length, gap) do
			local a, b = span[1], span[2]
			local mid, size = (a + b) / 2, b - a
			if size > 0.5 then
				-- Baseboard, mid panel band and an accent light strip.
				local base = wallCFrame(room, side, mid, FLOOR_Y + 0.6, 0.3)
				Kit.box(folder, "Baseboard", Vector3.new(size, 1.2, 0.6), base, Kit.Color.Trim, Enum.Material.Metal)
				if not isWindow then
					local band = wallCFrame(room, side, mid, FLOOR_Y + 4.5, 0.12)
					Kit.box(folder, "PanelBand", Vector3.new(size, 5, 0.24), band, Kit.Color.PanelDark, Enum.Material.SmoothPlastic)
				end
				local strip = wallCFrame(room, side, mid, FLOOR_Y + height - 2.4, 0.18)
				local light = Kit.neon(folder, "LightStrip", Vector3.new(size, 0.25, 0.3), strip, accent)
				ctx.registerFixture(light, room.Id, room.Section)
				-- Pillars every ~12 studs inside this span.
				local count = math.floor(size / 12)
				for i = 1, count do
					local along = a + i * (size / (count + 1))
					local pillar = wallCFrame(room, side, along, FLOOR_Y + height / 2, 0.45)
					Kit.box(folder, "Pillar", Vector3.new(1.4, height, 0.9), pillar, Kit.Color.Panel, Enum.Material.Metal)
					local cap = wallCFrame(room, side, along, FLOOR_Y + 3.2, 0.95)
					Kit.box(folder, "PillarCap", Vector3.new(1.6, 0.25, 0.2), cap, Kit.Color.Trim)
				end
			end
		end

		-- Door frame on this side.
		if door then
			local doorH = doorHeight(door)
			local half = door.Width / 2
			for _, s in { -1, 1 } do
				local jamb = wallCFrame(room, side, s * (half + 0.7), FLOOR_Y + doorH / 2, 0.6)
				Kit.box(folder, "DoorJamb", Vector3.new(1.4, doorH, 1.2), jamb, Kit.Color.Trim, Enum.Material.Metal)
				local glow = wallCFrame(room, side, s * (half + 0.05), FLOOR_Y + doorH / 2, 0.75)
				local edge = Kit.neon(folder, "DoorEdge", Vector3.new(0.12, doorH - 1, 0.12), glow, accent)
				ctx.registerFixture(edge, room.Id, room.Section)
			end
			local lintel = wallCFrame(room, side, 0, FLOOR_Y + doorH + 0.7, 0.6)
			Kit.box(folder, "DoorLintel", Vector3.new(door.Width + 2.8, 1.4, 1.2), lintel, Kit.Color.Trim, Enum.Material.Metal)
			Kit.hazardStrip(folder, door.Width + 2.6, 0.1, 0.5, lintel * CFrame.new(0, 0, -0.62), "X")
		end
	end

	-- Corner columns.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.box(
				folder,
				"Corner",
				Vector3.new(2, height, 2),
				CFrame.new(cx + sx * (room.SizeX / 2 - 1), FLOOR_Y + height / 2, cz + sz * (room.SizeZ / 2 - 1)),
				Kit.Color.PanelDark,
				Enum.Material.Metal
			)
		end
	end

	-- Ceiling beams across the shorter axis, with light panels between them.
	local beamsAlongX = room.SizeX < room.SizeZ
	local span = if beamsAlongX then room.SizeZ else room.SizeX
	local cross = if beamsAlongX then room.SizeX else room.SizeZ
	local beamCount = math.max(2, math.floor(span / 12))
	local ceilingY = FLOOR_Y + height - 0.6
	for i = 1, beamCount do
		local t = -span / 2 + i * span / (beamCount + 1)
		local cf = if beamsAlongX then CFrame.new(cx, ceilingY, cz + t) else CFrame.new(cx + t, ceilingY, cz)
		local size = if beamsAlongX then Vector3.new(cross, 1.2, 1) else Vector3.new(1, 1.2, cross)
		Kit.box(folder, "Beam", size, cf, Kit.Color.Trim, Enum.Material.Metal)
		if i < beamCount then
			local nextT = -span / 2 + (i + 1) * span / (beamCount + 1)
			local mid = (t + nextT) / 2
			local panelCf = if beamsAlongX then CFrame.new(cx, ceilingY + 0.4, cz + mid) else CFrame.new(cx + mid, ceilingY + 0.4, cz)
			local panelSize = if beamsAlongX then Vector3.new(cross * 0.45, 0.15, 3) else Vector3.new(3, 0.15, cross * 0.45)
			local panel = Kit.neon(folder, "CeilingPanel", panelSize, panelCf, Color3.fromRGB(225, 235, 255))
			ctx.registerFixture(panel, room.Id, room.Section)
		end
	end
end

function Architecture.decorateConnection(connection: ShipLayout.Connection, parent: Instance, ctx: Context)
	local folder = Instance.new("Folder")
	folder.Name = "Detail"
	folder.Parent = parent
	local isTunnel = connection.Kind == "Tunnel"
	local height = doorHeight(connection)
	local width = connection.Width
	local alongX = connection.Axis == "X"
	local length = if alongX then connection.MaxX - connection.MinX else connection.MaxZ - connection.MinZ
	local cx = (connection.MinX + connection.MaxX) / 2
	local cz = (connection.MinZ + connection.MaxZ) / 2
	local accent = if isTunnel then Kit.Color.Amber else Kit.SectionColor[connection.Section]
	local frameColor = if isTunnel then Color3.fromRGB(70, 60, 50) else Kit.Color.Trim

	local function at(t: number, side: number, y: number): CFrame
		-- t along the corridor, side across it (-1/1 = walls).
		if alongX then
			return CFrame.new(connection.MinX + t, FLOOR_Y + y, cz + side * (width / 2 - 0.4))
		end
		return CFrame.new(cx + side * (width / 2 - 0.4), FLOOR_Y + y, connection.MinZ + t)
	end

	-- Ribs: two posts and an overhead beam every few studs.
	local spacing = if isTunnel then 6 else 8
	local count = math.max(1, math.floor(length / spacing) - 1)
	for i = 1, count do
		local t = i * length / (count + 1)
		for _, side in { -1, 1 } do
			Kit.box(folder, "RibPost", if alongX then Vector3.new(0.8, height, 0.8) else Vector3.new(0.8, height, 0.8), at(t, side, height / 2), frameColor, Enum.Material.Metal)
		end
		local beamCf = if alongX then CFrame.new(connection.MinX + t, FLOOR_Y + height - 0.5, cz) else CFrame.new(cx, FLOOR_Y + height - 0.5, connection.MinZ + t)
		Kit.box(folder, "RibBeam", if alongX then Vector3.new(0.8, 1, width) else Vector3.new(width, 1, 0.8), beamCf, frameColor, Enum.Material.Metal)
		local glow = Kit.neon(folder, "RibLight", if alongX then Vector3.new(0.3, 0.12, width - 3) else Vector3.new(width - 3, 0.12, 0.3), beamCf * CFrame.new(0, -0.55, 0), accent)
		ctx.registerFixture(glow, connection.Id, connection.Section)
	end

	-- Pipes along the upper corners.
	for index, side in { -1, 1 } do
		local pipeCf = if alongX
			then CFrame.new(cx, FLOOR_Y + height - 1.8, cz + side * (width / 2 - 1))
			else CFrame.new(cx + side * (width / 2 - 1), FLOOR_Y + height - 1.8, cz)
		Kit.cylinder(folder, "Pipe", length, if index == 1 then 0.9 else 0.6, pipeCf, if index == 1 then Kit.Color.Copper else Kit.Color.Steel, Enum.Material.Metal, if alongX then "X" else "Z")
	end

	-- Centre floor grating / hazard edging in tunnels.
	local floorCf = CFrame.new(cx, FLOOR_Y + 0.06, cz)
	Kit.box(folder, "Grate", if alongX then Vector3.new(length, 0.12, 3) else Vector3.new(3, 0.12, length), floorCf, Kit.Color.HullDark, Enum.Material.DiamondPlate)
	if isTunnel then
		for _, side in { -1, 1 } do
			local edgeCf = if alongX then CFrame.new(cx, FLOOR_Y + 0.07, cz + side * (width / 2 - 0.5)) else CFrame.new(cx + side * (width / 2 - 0.5), FLOOR_Y + 0.07, cz)
			Kit.hazardStrip(folder, length, 0.6, 0.12, edgeCf, if alongX then "X" else "Z", 4)
		end
	end
end

return Architecture
