-- Builds the lobby: plaza, spawn, car showroom with turntables, status
-- screen, global leaderboard and a test-drive ring road with ramps.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local Maps = require(Shared.Maps)
local CarBuilder = require(Shared.CarBuilder)
local Customization = require(Shared.Customization)

local TrackBuilder = require(script.Parent.TrackBuilder)
local newPart = TrackBuilder.NewPart

local LobbyBuilder = {}

local statusLabel, subStatusLabel
local leaderboardRows = {}
local testSpawn

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function surfaceGui(part, face, pps)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 20
	gui.LightInfluence = 0
	gui.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = rgb(14, 16, 24)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	return gui, bg
end

local function text(parent, str, size, pos, color, font)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = pos
	label.Font = font or Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = str
	label.Parent = parent
	return label
end

function LobbyBuilder.Build()
	local origin = Config.LOBBY_ORIGIN
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"

	-- Ground & plaza ---------------------------------------------------------
	newPart(lobby, Vector3.new(1100, 4, 1100), CFrame.new(origin + Vector3.new(0, -2, 0)), rgb(80, 150, 70), Enum.Material.Grass)
	newPart(lobby, Vector3.new(220, 1, 220), CFrame.new(origin + Vector3.new(0, -0.4, 0)), rgb(170, 170, 175), Enum.Material.Pavement)
	for _, side in { -1, 1 } do
		newPart(
			lobby,
			Vector3.new(220, 0.2, 2),
			CFrame.new(origin + Vector3.new(0, 0.12, side * 109)),
			rgb(255, 120, 30),
			Enum.Material.Neon,
			{ visualOnly = true }
		)
		newPart(
			lobby,
			Vector3.new(2, 0.2, 220),
			CFrame.new(origin + Vector3.new(side * 109, 0.12, 0)),
			rgb(255, 120, 30),
			Enum.Material.Neon,
			{ visualOnly = true }
		)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(origin + Vector3.new(0, 0.1, 55))
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = rgb(255, 120, 30)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby

	-- Showroom -----------------------------------------------------------------
	local stageZ = -65
	newPart(lobby, Vector3.new(160, 2, 44), CFrame.new(origin + Vector3.new(0, 1, stageZ)), rgb(30, 30, 36), Enum.Material.SmoothPlastic)
	newPart(
		lobby,
		Vector3.new(160, 0.3, 1),
		CFrame.new(origin + Vector3.new(0, 1.9, stageZ + 22)),
		rgb(255, 120, 30),
		Enum.Material.Neon,
		{ visualOnly = true }
	)
	local wall = newPart(lobby, Vector3.new(170, 44, 2), CFrame.new(origin + Vector3.new(0, 22, stageZ - 24)), rgb(20, 20, 26), Enum.Material.SmoothPlastic)
	local _, wallBg = surfaceGui(wall, Enum.NormalId.Back, 10)
	wallBg.BackgroundColor3 = rgb(16, 18, 26)
	text(wallBg, Config.GAME_NAME, UDim2.fromScale(0.8, 0.3), UDim2.fromScale(0.1, 0.05), rgb(255, 130, 40))
	text(
		wallBg,
		"CHOOSE • UPGRADE • CUSTOMIZE • RACE",
		UDim2.fromScale(0.7, 0.08),
		UDim2.fromScale(0.15, 0.36),
		rgb(220, 220, 230),
		Enum.Font.GothamBold
	)

	for i, carId in Cars.Order do
		local car = Cars.List[carId]
		local x = (i - 3) * 30
		local center = origin + Vector3.new(x, 2.25, stageZ)
		newPart(
			lobby,
			Vector3.new(0.5, 24, 24),
			CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
			rgb(55, 55, 62),
			Enum.Material.DiamondPlate,
			{ shape = Enum.PartType.Cylinder }
		)
		newPart(
			lobby,
			Vector3.new(0.4, 24.6, 24.6),
			CFrame.new(center - Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			rgb(255, 120, 30),
			Enum.Material.Neon,
			{ shape = Enum.PartType.Cylinder, visualOnly = true }
		)

		local display = CarBuilder.Build(carId, Customization.Default(carId), true)
		local restY = Config.Suspension.restLength * (1 - Config.Suspension.sag) + car.body.wheelRadius
		local pivot = center + Vector3.new(0, 0.25 + restY, 0)
		display:PivotTo(CFrame.new(pivot) * CFrame.Angles(0, math.rad(35), 0))
		display.Name = "Display_" .. carId
		display:SetAttribute("Center", pivot)
		CollectionService:AddTag(display, "Turntable")

		local board = Instance.new("BillboardGui")
		board.Size = UDim2.fromOffset(220, 70)
		board.StudsOffset = Vector3.new(0, 7, 0)
		board.MaxDistance = 120
		board.Parent = display.PrimaryPart
		text(board, car.name, UDim2.new(1, 0, 0.5, 0), UDim2.new(), Color3.new(1, 1, 1))
		text(
			board,
			car.price == 0 and "STARTER CAR" or string.format("LV %d  •  %d COINS", car.level, car.price),
			UDim2.new(1, 0, 0.35, 0),
			UDim2.new(0, 0, 0.55, 0),
			rgb(255, 170, 60),
			Enum.Font.GothamBold
		)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open Garage"
		prompt.ObjectText = car.name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 18
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("CarId", carId)
		prompt.Parent = display.PrimaryPart

		display.Parent = lobby
	end

	-- Status screen -------------------------------------------------------------
	local screen = newPart(lobby, Vector3.new(2, 30, 56), CFrame.new(origin + Vector3.new(100, 19, -10)), rgb(20, 20, 26), Enum.Material.SmoothPlastic)
	newPart(lobby, Vector3.new(3, 4, 3), CFrame.new(origin + Vector3.new(100, 2, -10)), rgb(40, 40, 46), Enum.Material.Metal)
	local _, screenBg = surfaceGui(screen, Enum.NormalId.Left, 16)
	text(screenBg, "NEXT RACE", UDim2.fromScale(0.9, 0.16), UDim2.fromScale(0.05, 0.06), rgb(255, 130, 40))
	statusLabel = text(screenBg, "Loading...", UDim2.fromScale(0.9, 0.3), UDim2.fromScale(0.05, 0.28), Color3.new(1, 1, 1))
	subStatusLabel = text(
		screenBg,
		"",
		UDim2.fromScale(0.9, 0.16),
		UDim2.fromScale(0.05, 0.66),
		rgb(190, 190, 210),
		Enum.Font.GothamBold
	)

	-- Leaderboard -----------------------------------------------------------------
	local lb = newPart(lobby, Vector3.new(2, 30, 40), CFrame.new(origin + Vector3.new(-100, 19, -10)), rgb(20, 20, 26), Enum.Material.SmoothPlastic)
	newPart(lobby, Vector3.new(3, 4, 3), CFrame.new(origin + Vector3.new(-100, 2, -10)), rgb(40, 40, 46), Enum.Material.Metal)
	local _, lbBg = surfaceGui(lb, Enum.NormalId.Right, 16)
	text(lbBg, "TOP RACERS • WINS", UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.03), rgb(255, 200, 60))
	for i = 1, 10 do
		leaderboardRows[i] = text(
			lbBg,
			string.format("%d.  ---", i),
			UDim2.fromScale(0.9, 0.075),
			UDim2.fromScale(0.05, 0.15 + (i - 1) * 0.083),
			i <= 3 and rgb(255, 220, 120) or Color3.new(1, 1, 1),
			Enum.Font.GothamBold
		)
		leaderboardRows[i].TextXAlignment = Enum.TextXAlignment.Left
	end

	-- Plaza decoration ----------------------------------------------------------------
	for _, corner in { Vector3.new(-95, 0, -95), Vector3.new(95, 0, -95), Vector3.new(-95, 0, 95), Vector3.new(95, 0, 95) } do
		local base = origin + corner
		newPart(lobby, Vector3.new(1, 18, 1), CFrame.new(base + Vector3.new(0, 9, 0)), rgb(60, 60, 66), Enum.Material.Metal)
		local head = newPart(lobby, Vector3.new(3, 1, 3), CFrame.new(base + Vector3.new(0, 18, 0)), rgb(255, 230, 170), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 1.5
		light.Parent = head
	end
	local rng = Random.new(7)
	for i = 1, 24 do
		local angle = i / 24 * math.pi * 2
		local pos = origin + Vector3.new(math.cos(angle) * 125, 0, math.sin(angle) * 125)
		local h = rng:NextNumber(18, 26)
		local trunk = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), angle, 0) * CFrame.new(0, h / 2, 0)
		newPart(lobby, Vector3.new(1.5, h, 1.5), trunk, rgb(140, 100, 60), Enum.Material.Wood)
		for k = 1, 6 do
			newPart(
				lobby,
				Vector3.new(2.4, 0.3, 9),
				trunk * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, 0, -4.5),
				rgb(50, 150, 60),
				Enum.Material.Grass,
				{ visualOnly = true }
			)
		end
	end

	-- Test-drive ring road -------------------------------------------------------------
	local ringPoints = {}
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		table.insert(ringPoints, { math.cos(angle) * 240, 0, math.sin(angle) * 240 })
	end
	local ring = TrackBuilder.Build({
		id = "LobbyRing",
		name = "Test Track",
		width = 30,
		road = { color = rgb(50, 50, 56), material = Enum.Material.Asphalt },
		barrier = { color = rgb(240, 240, 240), material = Enum.Material.Concrete },
		curbs = true,
		lamps = true,
		lampEvery = 16,
		points = ringPoints,
		noGround = true,
		noGantry = true,
		noBarriers = true,
	}, origin)
	ring.model.Parent = lobby
	testSpawn = ring.grid[1]

	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + 0.3
		local pos = origin + Vector3.new(math.cos(angle) * 350, 3.5, math.sin(angle) * 350)
		local ramp = Instance.new("WedgePart")
		ramp.Anchored = true
		ramp.Size = Vector3.new(26, 7, 36)
		ramp.CFrame = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi / 2, 0)
		ramp.Color = rgb(255, 170, 40)
		ramp.Material = Enum.Material.DiamondPlate
		ramp.Parent = lobby
	end

	lobby.Parent = workspace

	-- Default lighting (clients switch it per race).
	for key, value in Maps.LobbyLighting.lighting do
		Lighting[key] = value
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	for key, value in Maps.LobbyLighting.atmosphere do
		atmosphere[key] = value
	end
	atmosphere.Parent = Lighting

	return lobby
end

function LobbyBuilder.GetTestSpawn()
	return testSpawn
end

function LobbyBuilder.SetStatus(main, sub)
	if statusLabel then
		statusLabel.Text = main
		subStatusLabel.Text = sub or ""
	end
end

function LobbyBuilder.SetLeaderboard(entries)
	for i, row in leaderboardRows do
		local entry = entries[i]
		row.Text = entry and string.format("%d.  %s  —  %d", i, entry.name, entry.wins) or string.format("%d.  ---", i)
	end
end

return LobbyBuilder
