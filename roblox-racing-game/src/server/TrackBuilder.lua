-- Generates a complete race track from a map definition (see Shared.Maps):
-- road surface, barriers, curbs, start gantry, checkpoints, starting grid,
-- ground, lighting posts and themed scenery.
local TrackBuilder = {}

local SAMPLE_SPACING = 8

local function newPart(parent, size, cframe, color, material, opts)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	if opts then
		if opts.visualOnly then
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		end
		if opts.shape then
			part.Shape = opts.shape
		end
		if opts.transparency then
			part.Transparency = opts.transparency
		end
	end
	part.Parent = parent
	return part
end
TrackBuilder.NewPart = newPart

local function catmull(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

-- Evenly-ish spaced samples along a Catmull-Rom spline: a closed loop,
-- or (open = true) a road from the first point to the last.
function TrackBuilder.Sample(points, spacing, open)
	local n = #points
	local out = {}
	for i = 1, open and n - 1 or n do
		local p0, p1, p2, p3
		if open then
			p0 = points[math.max(i - 1, 1)]
			p1 = points[i]
			p2 = points[i + 1]
			p3 = points[math.min(i + 2, n)]
		else
			p0 = points[(i - 2) % n + 1]
			p1 = points[i]
			p2 = points[i % n + 1]
			p3 = points[(i + 1) % n + 1]
		end
		local len, prev = 0, p1
		for s = 1, 20 do
			local q = catmull(p0, p1, p2, p3, s / 20)
			len += (q - prev).Magnitude
			prev = q
		end
		local steps = math.max(2, math.ceil(len / spacing))
		for s = 0, steps - 1 do
			table.insert(out, catmull(p0, p1, p2, p3, s / steps))
		end
	end
	if open then
		table.insert(out, points[n])
	end
	return out
end

local function buildFrames(samples, open)
	local n = #samples
	local frames = table.create(n)
	for i = 1, n do
		local a, b
		if open then
			a, b = samples[math.max(i - 1, 1)], samples[math.min(i + 1, n)]
		else
			a, b = samples[(i - 2) % n + 1], samples[i % n + 1]
		end
		local dir = (b - a).Unit
		local right = dir:Cross(Vector3.yAxis).Unit
		local up = right:Cross(dir).Unit
		frames[i] = { pos = samples[i], dir = dir, right = right, up = up }
	end
	return frames
end

---------------------------------------------------------------------------
-- Scenery
---------------------------------------------------------------------------
local Deco = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

function Deco.building(parent, pos, rng, neon)
	local w, d = rng:NextNumber(30, 60), rng:NextNumber(30, 60)
	local h = rng:NextNumber(60, 220)
	local shade = rng:NextInteger(35, 80)
	local bodyColor = neon and rgb(18, 18, 26) or rgb(shade, shade, shade + 10)
	local cf = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	newPart(parent, Vector3.new(w, h, d), cf, bodyColor, neon and Enum.Material.SmoothPlastic or Enum.Material.Concrete)
	local stripColors = neon and { rgb(255, 40, 200), rgb(0, 230, 255), rgb(150, 60, 255) }
		or { rgb(255, 220, 140), rgb(200, 220, 255) }
	local strip = stripColors[rng:NextInteger(1, #stripColors)]
	local floors = math.floor(h / 14)
	for f = 1, floors do
		if rng:NextNumber() < (neon and 0.35 or 0.6) then
			local y = -h / 2 + f * 14 - 4
			newPart(
				parent,
				Vector3.new(w + 0.4, 1.4, d + 0.4),
				cf * CFrame.new(0, y, 0),
				strip,
				Enum.Material.Neon,
				{ visualOnly = true }
			)
		end
	end
	if neon then
		newPart(
			parent,
			Vector3.new(1.2, h, 1.2),
			cf * CFrame.new(w / 2, 0, d / 2),
			strip,
			Enum.Material.Neon,
			{ visualOnly = true }
		)
	end
end

function Deco.pine(parent, pos, rng, snowy)
	local scale = rng:NextNumber(0.8, 1.6)
	local trunkH = 10 * scale
	newPart(
		parent,
		Vector3.new(2 * scale, trunkH, 2 * scale),
		CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)),
		rgb(90, 60, 40),
		Enum.Material.Wood
	)
	local leaf = snowy and rgb(220, 235, 240) or rgb(40, 95, 50)
	for i = 0, 3 do
		local size = (16 - i * 3.5) * scale
		local y = trunkH + i * 5 * scale
		newPart(
			parent,
			Vector3.new(4 * scale, size, size),
			CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			leaf,
			snowy and Enum.Material.Snow or Enum.Material.Grass,
			{ shape = Enum.PartType.Cylinder, visualOnly = i > 0 }
		)
	end
end

function Deco.redwood(parent, pos, rng)
	local scale = rng:NextNumber(1, 1.8)
	local trunkH = 45 * scale
	newPart(
		parent,
		Vector3.new(trunkH, 4 * scale, 4 * scale),
		CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(110, 55, 35),
		Enum.Material.Wood,
		{ shape = Enum.PartType.Cylinder }
	)
	for i = 1, 3 do
		local off = Vector3.new(rng:NextNumber(-5, 5), trunkH - 4 + i * 5, rng:NextNumber(-5, 5)) * Vector3.new(scale, 1, scale)
		newPart(
			parent,
			Vector3.new(1, 1, 1) * rng:NextNumber(14, 22) * scale,
			CFrame.new(pos + off),
			rgb(35, rng:NextInteger(80, 110), 40),
			Enum.Material.Grass,
			{ shape = Enum.PartType.Ball, visualOnly = true }
		)
	end
end

function Deco.palm(parent, pos, rng)
	local h = rng:NextNumber(18, 30)
	local lean = rng:NextNumber(-0.25, 0.25)
	local trunkCF = CFrame.new(pos) * CFrame.Angles(lean, rng:NextNumber(0, math.pi * 2), 0) * CFrame.new(0, h / 2, 0)
	newPart(parent, Vector3.new(1.6, h, 1.6), trunkCF, rgb(140, 100, 60), Enum.Material.Wood)
	local top = trunkCF * CFrame.new(0, h / 2, 0)
	for i = 1, 6 do
		local leafCF = top * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, 0, -5)
		newPart(
			parent,
			Vector3.new(2.6, 0.3, 10),
			leafCF,
			rgb(50, 150, 60),
			Enum.Material.Grass,
			{ visualOnly = true }
		)
	end
end

function Deco.cactus(parent, pos, rng)
	local h = rng:NextNumber(8, 16)
	local green = rgb(70, 130, 60)
	newPart(parent, Vector3.new(2, h, 2), CFrame.new(pos + Vector3.new(0, h / 2, 0)), green, Enum.Material.Grass)
	for _, side in { -1, 1 } do
		if rng:NextNumber() < 0.7 then
			local y = rng:NextNumber(h * 0.35, h * 0.6)
			newPart(
				parent,
				Vector3.new(3, 1.4, 1.4),
				CFrame.new(pos + Vector3.new(side * 2, y, 0)),
				green,
				Enum.Material.Grass,
				{ visualOnly = true }
			)
			newPart(
				parent,
				Vector3.new(1.4, 4, 1.4),
				CFrame.new(pos + Vector3.new(side * 3.2, y + 2, 0)),
				green,
				Enum.Material.Grass,
				{ visualOnly = true }
			)
		end
	end
end

function Deco.rock(parent, pos, rng, color, material)
	local s = rng:NextNumber(6, 22)
	newPart(
		parent,
		Vector3.new(s * rng:NextNumber(0.8, 1.6), s * rng:NextNumber(0.5, 1.2), s * rng:NextNumber(0.8, 1.6)),
		CFrame.new(pos + Vector3.new(0, s * 0.3, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
		color,
		material
	)
end

function Deco.mesa(parent, pos, rng)
	local w = rng:NextNumber(60, 140)
	local h = rng:NextNumber(40, 120)
	newPart(
		parent,
		Vector3.new(w, h, w * rng:NextNumber(0.6, 1.2)),
		CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		rgb(rng:NextInteger(170, 200), rng:NextInteger(90, 115), 60),
		Enum.Material.Sandstone
	)
end

function Deco.lava(parent, pos, rng)
	if rng:NextNumber() < 0.5 then
		local s = rng:NextNumber(20, 50)
		newPart(
			parent,
			Vector3.new(0.6, s, s),
			CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			rgb(255, 90, 20),
			Enum.Material.Neon,
			{ shape = Enum.PartType.Cylinder, visualOnly = true }
		)
	else
		local h = rng:NextNumber(20, 70)
		local w = rng:NextNumber(8, 18)
		newPart(
			parent,
			Vector3.new(w, h, w),
			CFrame.new(pos + Vector3.new(0, h / 2, 0))
				* CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6), rng:NextNumber(-0.15, 0.15)),
			rgb(35, 30, 30),
			Enum.Material.Basalt
		)
	end
end

function Deco.grandstand(parent, cf, color)
	for step = 0, 4 do
		newPart(
			parent,
			Vector3.new(80, 3, 6),
			cf * CFrame.new(0, 1.5 + step * 3, step * 6),
			step % 2 == 0 and color or rgb(230, 230, 230),
			Enum.Material.SmoothPlastic
		)
	end
	newPart(parent, Vector3.new(84, 2, 36), cf * CFrame.new(0, 22, 12), rgb(40, 40, 45), Enum.Material.Metal)
end

function Deco.lamp(parent, pos, facing, neonColor)
	local poleH = 16
	newPart(parent, Vector3.new(0.8, poleH, 0.8), CFrame.new(pos + Vector3.new(0, poleH / 2, 0)), rgb(60, 60, 65), Enum.Material.Metal)
	local head = newPart(
		parent,
		Vector3.new(1.5, 0.8, 5),
		CFrame.lookAt(pos + Vector3.new(0, poleH, 0), pos + Vector3.new(0, poleH, 0) + facing) * CFrame.new(0, 0, -2),
		neonColor or rgb(255, 230, 170),
		Enum.Material.Neon,
		{ visualOnly = true }
	)
	local light = Instance.new("PointLight")
	light.Range = 50
	light.Brightness = 1.6
	light.Color = neonColor or rgb(255, 225, 170)
	light.Parent = head
end

function Deco.streetLight(parent, base, inward, color)
	color = color or rgb(255, 220, 160)
	local poleH = 26
	local metal = rgb(55, 58, 64)
	newPart(parent, Vector3.new(1.2, poleH, 1.2), CFrame.new(base + Vector3.new(0, poleH / 2, 0)), metal, Enum.Material.Metal)
	newPart(parent, Vector3.new(2.4, 1, 2.4), CFrame.new(base + Vector3.new(0, 0.5, 0)), metal, Enum.Material.Metal)
	local top = base + Vector3.new(0, poleH, 0)
	local flatIn = Vector3.new(inward.X, 0, inward.Z).Unit
	newPart(
		parent,
		Vector3.new(0.7, 0.7, 14),
		CFrame.lookAt(top, top + flatIn) * CFrame.new(0, 0, -7),
		metal,
		Enum.Material.Metal,
		{ visualOnly = true }
	)
	local headPos = top + flatIn * 13 - Vector3.new(0, 0.6, 0)
	local head = newPart(
		parent,
		Vector3.new(3, 0.5, 5),
		CFrame.lookAt(headPos, headPos + flatIn),
		color,
		Enum.Material.Neon,
		{ visualOnly = true }
	)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 120
	light.Range = 60
	light.Brightness = 4
	light.Color = color
	light.Shadows = false
	light.Parent = head
end

local THEMES = {}

function THEMES.speedway(parent, pos, rng)
	if rng:NextNumber() < 0.7 then
		Deco.pine(parent, pos, rng, false)
	else
		Deco.rock(parent, pos, rng, rgb(120, 120, 110), Enum.Material.Slate)
	end
end
function THEMES.city(parent, pos, rng)
	Deco.building(parent, pos, rng, false)
end
function THEMES.neon(parent, pos, rng)
	Deco.building(parent, pos, rng, true)
end
function THEMES.desert(parent, pos, rng)
	local roll = rng:NextNumber()
	if roll < 0.45 then
		Deco.cactus(parent, pos, rng)
	elseif roll < 0.8 then
		Deco.rock(parent, pos, rng, rgb(190, 130, 80), Enum.Material.Sandstone)
	else
		Deco.mesa(parent, pos, rng)
	end
end
function THEMES.snow(parent, pos, rng)
	if rng:NextNumber() < 0.8 then
		Deco.pine(parent, pos, rng, true)
	else
		Deco.rock(parent, pos, rng, rgb(150, 155, 165), Enum.Material.Slate)
	end
end
function THEMES.coast(parent, pos, rng)
	if rng:NextNumber() < 0.8 then
		Deco.palm(parent, pos, rng)
	else
		Deco.rock(parent, pos, rng, rgb(140, 130, 120), Enum.Material.Rock)
	end
end
function THEMES.forest(parent, pos, rng)
	local roll = rng:NextNumber()
	if roll < 0.55 then
		Deco.redwood(parent, pos, rng)
	elseif roll < 0.9 then
		Deco.pine(parent, pos, rng, false)
	else
		Deco.rock(parent, pos, rng, rgb(100, 105, 95), Enum.Material.Rock)
	end
end
function THEMES.volcano(parent, pos, rng)
	Deco.lava(parent, pos, rng)
end

---------------------------------------------------------------------------
-- Track
---------------------------------------------------------------------------

-- Returns { model, frames, checkpoints, grid, killY, spawn }
-- `map` fields used: id, name, width, road, ground, barrier, curbs, lamps,
-- lampEvery, theme, decoCount, seed, points, sea, and the optional flags
-- noGround / noGantry / noBarriers.
function TrackBuilder.Build(map, origin)
	local model = Instance.new("Model")
	model.Name = "Track_" .. map.id

	local roadFolder = Instance.new("Folder")
	roadFolder.Name = "Road"
	roadFolder.Parent = model
	local sceneryFolder = Instance.new("Folder")
	sceneryFolder.Name = "Scenery"
	sceneryFolder.Parent = model

	local points = {}
	for _, p in map.points do
		local scale = map.scale or 1
		table.insert(points, origin + Vector3.new(p[1] * scale, p[2], p[3] * scale))
	end
	local open = map.open == true
	local samples = TrackBuilder.Sample(points, SAMPLE_SPACING, open)
	local frames = buildFrames(samples, open)
	local n = #frames
	local W = map.width

	local minX, maxX, minZ, maxZ, minY = math.huge, -math.huge, math.huge, -math.huge, math.huge
	for _, s in samples do
		minX, maxX = math.min(minX, s.X), math.max(maxX, s.X)
		minZ, maxZ = math.min(minZ, s.Z), math.max(maxZ, s.Z)
		minY = math.min(minY, s.Y)
	end
	local groundTop = minY - 0.6

	local roadColor, roadMat = map.road.color, map.road.material
	local lanes = math.max(1, math.floor(W / 10 + 0.5))
	local barrierColor, barrierMat = map.barrier.color, map.barrier.material

	-- Open roads: the grid sits before startIndex, the finish is at finishIndex
	-- and there's a run-off after it.
	local startIndex = open and 30 or 1
	local finishIndex = open and n - 30 or 1
	for i = 1, open and n - 1 or n do
		local f, g = frames[i], frames[i % n + 1]
		local a, b = f.pos, g.pos
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local segCF = CFrame.lookAt(mid, b)

		-- Road slab plus a disc at every joint so curves have no gaps.
		newPart(roadFolder, Vector3.new(W, 1, len + 0.4), segCF, roadColor, roadMat)
		newPart(
			roadFolder,
			Vector3.new(1, W, W),
			CFrame.fromMatrix(a, f.up, f.dir),
			roadColor,
			roadMat,
			{ shape = Enum.PartType.Cylinder }
		)

		-- Dashed lane dividers.
		if i % 3 == 0 then
			local laneWidth = W / lanes
			for lane = 1, lanes - 1 do
				newPart(
					roadFolder,
					Vector3.new(0.5, 0.1, len * 0.6),
					segCF * CFrame.new(-W / 2 + lane * laneWidth, 0.52, 0),
					Color3.fromRGB(235, 235, 235),
					Enum.Material.SmoothPlastic,
					{ visualOnly = true }
				)
			end
		end

		for _, side in { -1, 1 } do
			if not map.noBarriers then
				local off = W / 2 + 0.75
				local e1 = a + f.right * side * off
				local e2 = b + g.right * side * off
				local blen = (e2 - e1).Magnitude
				if blen > 0.05 then
					newPart(
						roadFolder,
						Vector3.new(1.5, 5, blen + 0.3),
						CFrame.lookAt((e1 + e2) / 2, e2) * CFrame.new(0, 3, 0),
						barrierColor,
						barrierMat
					)
				end
			end
			if map.curbs then
				local off = W / 2 - 1
				local c1 = a + f.right * side * off
				local c2 = b + g.right * side * off
				local clen = (c2 - c1).Magnitude
				if clen > 0.05 then
					newPart(
						roadFolder,
						Vector3.new(2, 0.2, clen + 0.1),
						CFrame.lookAt((c1 + c2) / 2, c2) * CFrame.new(0, 0.5, 0),
						i % 2 == 0 and Color3.fromRGB(210, 30, 30) or Color3.fromRGB(240, 240, 240),
						Enum.Material.SmoothPlastic,
						{ visualOnly = true }
					)
				end
			end
		end

		-- Support pillars under elevated road.
		if not map.noGround and i % 5 == 0 and a.Y - groundTop > 4 then
			local h = a.Y - 0.5 - groundTop
			newPart(
				roadFolder,
				Vector3.new(5, h, 5),
				CFrame.new(a.X, groundTop + h / 2, a.Z),
				Color3.fromRGB(120, 120, 125),
				Enum.Material.Concrete
			)
		end

		-- Night tracks: street lights on alternating sides, arms reaching over the road.
		if map.night and i % 10 == 0 then
			local side = (i // 10) % 2 == 0 and 1 or -1
			local base = a + f.right * side * (W / 2 + 4) - f.up * 0.5
			Deco.streetLight(sceneryFolder, base, -f.right * side, map.lampColor)
		elseif map.lamps and i % (map.lampEvery or 12) == 0 then
			local side = (i // (map.lampEvery or 12)) % 2 == 0 and 1 or -1
			local base = a + f.right * side * (W / 2 + 5) - Vector3.new(0, 0.5, 0)
			local neon = map.theme == "neon"
				and ((i // (map.lampEvery or 12)) % 3 == 0 and Color3.fromRGB(255, 40, 200) or Color3.fromRGB(0, 230, 255))
			Deco.lamp(sceneryFolder, base, -f.right * side, neon or nil)
		end
	end

	-- Checkpoints ----------------------------------------------------------
	-- Closed: evenly around the loop, #1 is the start/finish line.
	-- Open: #1 is the start line, the last one is the finish line.
	local span = open and (finishIndex - startIndex) or n
	local numCP = open and math.clamp(span // 14, 8, 80) or math.clamp(n // 14, 8, 40)
	local checkpoints = {}
	for k = 0, numCP - 1 do
		local idx
		if open then
			idx = startIndex + math.floor(k * span / (numCP - 1) + 0.5)
		else
			idx = math.floor(k * n / numCP) + 1
		end
		local f = frames[idx]
		local center = f.pos + f.up * 8
		local spawnPos = f.pos + f.dir * 8 + f.up * 3
		table.insert(checkpoints, {
			index = k + 1,
			cf = CFrame.lookAt(center, center + f.dir),
			halfWidth = W / 2 + 12,
			spawnCF = CFrame.lookAt(spawnPos, spawnPos + f.dir),
		})
	end

	-- Start / finish line ----------------------------------------------------
	local function gantry(f, caption, neonColor)
		local tiles = math.floor(W / 4)
		local tileSize = W / tiles
		for row = 0, 1 do
			for col = 0, tiles - 1 do
				local pos = f.pos + f.right * (-W / 2 + tileSize * (col + 0.5)) + f.dir * (row * 3 - 1.5)
				newPart(
					roadFolder,
					Vector3.new(tileSize, 0.1, 3),
					CFrame.lookAt(pos, pos + f.dir) * CFrame.new(0, 0.53, 0),
					(row + col) % 2 == 0 and Color3.new(1, 1, 1) or Color3.new(0.05, 0.05, 0.05),
					Enum.Material.SmoothPlastic,
					{ visualOnly = true }
				)
			end
		end
		local gantryH = 24
		for _, side in { -1, 1 } do
			local base = f.pos + f.right * side * (W / 2 + 4)
			newPart(
				roadFolder,
				Vector3.new(3, gantryH, 3),
				CFrame.lookAt(base, base + f.dir) * CFrame.new(0, gantryH / 2, 0),
				Color3.fromRGB(40, 40, 45),
				Enum.Material.Metal
			)
		end
		local beamCF = CFrame.lookAt(f.pos, f.pos + f.dir) * CFrame.new(0, gantryH, 0)
		local beam = newPart(roadFolder, Vector3.new(W + 10, 5, 3), beamCF, Color3.fromRGB(25, 25, 30), Enum.Material.Metal)
		newPart(
			roadFolder,
			Vector3.new(W + 10, 0.6, 3.2),
			beamCF * CFrame.new(0, -2.8, 0),
			neonColor,
			Enum.Material.Neon,
			{ visualOnly = true }
		)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 20
			gui.LightInfluence = 0
			gui.Parent = beam
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Text = caption
			label.Parent = gui
		end
	end
	if not map.noGantry then
		if open then
			gantry(frames[startIndex], string.upper(map.name) .. "  •  START", Color3.fromRGB(60, 210, 110))
			gantry(frames[finishIndex], "FINISH", Color3.fromRGB(255, 120, 30))
		else
			gantry(frames[1], string.upper(map.name) .. "  •  START / FINISH", Color3.fromRGB(255, 120, 30))
		end
	end
	if open then
		-- Walls across both ends of the road.
		for _, idx in { 1, n } do
			local f = frames[idx]
			newPart(
				roadFolder,
				Vector3.new(W + 6, 8, 3),
				CFrame.lookAt(f.pos, f.pos + f.dir) * CFrame.new(0, 4.5, 0),
				barrierColor,
				barrierMat
			)
		end
	end

	-- Starting grid (up to 4 across, staggered) --------------------------------
	local grid = {}
	local cols = math.clamp(lanes // 2 + 1, 2, 4)
	for k = 0, 23 do
		local row = k // cols
		local col = k % cols
		local idx = open and math.max(1, startIndex - 3 - row * 3) or (1 - (3 + row * 3) - 1) % n + 1
		local f = frames[idx]
		local lateral = (col - (cols - 1) / 2) * (W / (cols + 0.5))
		local pos = f.pos + f.right * lateral + f.up * 3 - f.dir * (col * 3)
		grid[k + 1] = CFrame.lookAt(pos, pos + f.dir)
	end

	-- Ground, sea ----------------------------------------------------------------
	if not map.noGround then
		local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
		local sx = (maxX - minX) + 700
		local sz = (maxZ - minZ) + 700
		-- Parts max out at 2048 studs, so big tracks get a grid of ground tiles.
		local tilesX, tilesZ = math.ceil(sx / 2000), math.ceil(sz / 2000)
		local tileX, tileZ = sx / tilesX, sz / tilesZ
		for tx = 0, tilesX - 1 do
			for tz = 0, tilesZ - 1 do
				newPart(
					model,
					Vector3.new(tileX + 0.1, 4, tileZ + 0.1),
					CFrame.new(cx - sx / 2 + tileX * (tx + 0.5), groundTop - 2, cz - sz / 2 + tileZ * (tz + 0.5)),
					map.ground.color,
					map.ground.material
				)
			end
		end
		if map.sea then
			newPart(
				model,
				Vector3.new(2048, 2, 1600),
				CFrame.new(cx, groundTop - 1.5, cz - sz / 2 - 800),
				Color3.fromRGB(30, 120, 190),
				Enum.Material.Glass,
				{ transparency = 0.2 }
			)
		end
		if map.theme == "volcano" and not open then
			-- The volcano itself, in the middle of the ring.
			local peak = Vector3.new(cx, groundTop, cz)
			for i = 0, 5 do
				local size = 300 - i * 45
				local h = 22
				newPart(
					sceneryFolder,
					Vector3.new(h, size, size),
					CFrame.new(peak + Vector3.new(0, h / 2 + i * h, 0)) * CFrame.Angles(0, 0, math.pi / 2),
					Color3.fromRGB(45 + i * 4, 35, 32),
					Enum.Material.Basalt,
					{ shape = Enum.PartType.Cylinder }
				)
			end
			local crater = newPart(
				sceneryFolder,
				Vector3.new(2, 60, 60),
				CFrame.new(peak + Vector3.new(0, 6 * 22 + 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(255, 90, 20),
				Enum.Material.Neon,
				{ shape = Enum.PartType.Cylinder }
			)
			local fire = Instance.new("Fire")
			fire.Size = 30
			fire.Heat = 25
			fire.Parent = crater
		end
	end

	-- Scenery -------------------------------------------------------------------
	local rng = Random.new(map.seed or 1)
	local theme = THEMES[map.theme]
	local function farFromTrack(pos, margin)
		local m2 = margin * margin
		for i = 1, n, 2 do
			local s = samples[i]
			local dx, dz = s.X - pos.X, s.Z - pos.Z
			if dx * dx + dz * dz < m2 then
				return false
			end
		end
		return true
	end
	if theme then
		local margin = W / 2 + 20
		if map.theme == "city" or map.theme == "neon" then
			margin = W / 2 + 45
		elseif map.theme == "volcano" then
			margin = W / 2 + 30
		end
		for _ = 1, map.decoCount or 0 do
			for _ = 1, 8 do
				local pos
				if open then
					-- Long roads: scatter scenery along the roadside.
					local f = frames[rng:NextInteger(1, n)]
					local side = rng:NextNumber() < 0.5 and -1 or 1
					local p = f.pos + f.right * side * (W / 2 + rng:NextNumber(25, 260))
					pos = Vector3.new(p.X, groundTop, p.Z)
				else
					pos = Vector3.new(rng:NextNumber(minX - 260, maxX + 260), groundTop, rng:NextNumber(minZ - 260, maxZ + 260))
				end
				local insideVolcano = not open
					and map.theme == "volcano"
					and (Vector2.new(pos.X, pos.Z) - Vector2.new((minX + maxX) / 2, (minZ + maxZ) / 2)).Magnitude < 170
				if not insideVolcano and farFromTrack(pos, margin) then
					theme(sceneryFolder, pos, rng)
					break
				end
			end
		end
		if map.theme == "speedway" then
			for i = 1, n, math.max(1, n // 6) do
				local f = frames[i]
				for _, side in { -1, 1 } do
					local pos = f.pos + f.right * side * (W / 2 + 30)
					if farFromTrack(pos, W / 2 + 25) then
						local base = Vector3.new(pos.X, groundTop, pos.Z)
						Deco.grandstand(sceneryFolder, CFrame.lookAt(base, base - f.right * side), map.cardColor)
					end
				end
			end
		end
	end

	return {
		model = model,
		frames = frames,
		checkpoints = checkpoints,
		grid = grid,
		killY = minY - 80,
		spawn = grid[1],
		open = open,
		startIndex = startIndex,
		finishIndex = finishIndex,
	}
end

return TrackBuilder
