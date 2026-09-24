-- Lobby HUD: coins / level / XP, menu buttons, race queue + test drive,
-- race status and the map vote panel. Also manages which modal panel is
-- open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maps = require(Shared.Maps)
local RaceTypes = require(Shared.RaceTypes)
local Util = require(script.Parent.Util)
local State = require(script.Parent.Parent.State)
local Notify = require(script.Parent.Notify)
local T = Util.Theme

local HUD = {}

local panels = {}
local openName = nil
local root, coinsLabel, levelLabel, xpFill, xpLabel, statusLabel, queueButton, driveButton
local voteFrame, voteButtons = nil, {}
local typeButtons = {}

---------------------------------------------------------------------------
-- Panel management
---------------------------------------------------------------------------
function HUD.RegisterPanel(name, module)
	panels[name] = module
end

function HUD.OpenPanel(name, ...)
	if openName and panels[openName] then
		panels[openName].Close()
	end
	openName = name
	panels[name].Open(...)
end

function HUD.TogglePanel(name)
	if openName == name then
		HUD.ClosePanel(name)
	else
		HUD.OpenPanel(name)
	end
end

function HUD.ClosePanel(name)
	if panels[name] then
		panels[name].Close()
	end
	if openName == name then
		openName = nil
	end
end

function HUD.CloseAll()
	if openName then
		HUD.ClosePanel(openName)
	end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function autoScale(inst)
	local scale = Util.new("UIScale", { Parent = inst })
	local camera = workspace.CurrentCamera
	local function update()
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.55, 1.15)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end
HUD.AutoScale = autoScale

function HUD.Init(gui)
	root = Util.frame(gui, { Name = "LobbyHUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })

	-- Player card (top-left) --------------------------------------------------
	local card = Util.frame(root, {
		Position = UDim2.new(0, 12, 0, 56),
		Size = UDim2.new(0, 290, 0, 84),
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.15,
	})
	Util.corner(card, 14)
	Util.stroke(card, T.accent, 1.5, 0.5)
	autoScale(card)
	card.AnchorPoint = Vector2.new(0, 0)

	local badge = Util.frame(card, {
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(0, 64, 0, 64),
		BackgroundColor3 = T.accent,
	})
	Util.corner(badge, 32)
	Util.label(badge, "LV", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 0, 8),
		Font = Enum.Font.GothamBlack,
	})
	levelLabel = Util.label(badge, "1", {
		Size = UDim2.new(1, -8, 0, 30),
		Position = UDim2.new(0, 4, 0, 24),
		Font = Enum.Font.GothamBlack,
	})

	local coinIcon = Util.frame(card, {
		Position = UDim2.new(0, 86, 0, 12),
		Size = UDim2.new(0, 26, 0, 26),
		BackgroundColor3 = T.gold,
	})
	Util.corner(coinIcon, 13)
	Util.label(coinIcon, "$", { TextColor3 = Color3.fromRGB(120, 80, 0), Font = Enum.Font.GothamBlack })
	coinsLabel = Util.label(card, "0", {
		Position = UDim2.new(0, 118, 0, 10),
		Size = UDim2.new(1, -128, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		TextColor3 = T.gold,
	})

	local xpBack
	xpBack, xpFill = Util.bar(card, {
		Position = UDim2.new(0, 86, 0, 48),
		Size = UDim2.new(1, -98, 0, 22),
	})
	xpFill.BackgroundColor3 = T.accent2
	xpLabel = Util.label(xpBack, "0 / 100 XP", {
		Size = UDim2.new(1, -8, 1, -6),
		Position = UDim2.new(0, 4, 0, 3),
		ZIndex = 2,
	})

	-- Menu (left) ----------------------------------------------------------------
	local menu = Util.frame(root, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 20),
		Size = UDim2.new(0, 170, 0, 7 * 54),
	})
	autoScale(menu)
	Util.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	local menuItems = {
		{ "GARAGE", "Garage", T.accent },
		{ "UPGRADES", "Upgrades", Color3.fromRGB(80, 110, 255) },
		{ "CUSTOMIZE", "Customize", Color3.fromRGB(200, 60, 200) },
		{ "SHOP", "Shop", T.robux },
		{ "TEAM RACES", "Teams", Color3.fromRGB(235, 60, 60) },
		{ "FREE DRIVE", "FreeDrive", Color3.fromRGB(40, 170, 90) },
		{ "CODES", "Codes", Color3.fromRGB(90, 95, 115) },
	}
	for i, item in menuItems do
		local button = Util.button(menu, item[1], item[3], {
			Size = UDim2.new(1, 0, 0, 46),
			LayoutOrder = i,
		}, function()
			HUD.TogglePanel(item[2])
		end)
		Util.stroke(button, Color3.new(0, 0, 0), 2, 0.6)
	end

	-- Bottom centre: status + queue / test drive ------------------------------------
	local bottom = Util.frame(root, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 480, 0, 116),
	})
	autoScale(bottom)
	local statusBox = Util.frame(bottom, {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.2,
	})
	Util.corner(statusBox, 10)
	statusLabel = Util.label(statusBox, "Connecting...", {
		Size = UDim2.new(1, -20, 1, -14),
		Position = UDim2.new(0, 10, 0, 7),
		Font = Enum.Font.GothamBlack,
	})

	queueButton = Util.button(bottom, "RACE QUEUE: ON", T.good, {
		Position = UDim2.new(0, 0, 0, 56),
		Size = UDim2.new(0.5, -6, 0, 56),
	}, function()
		local want = not State.queued
		local ok, msg = State.Request("SetQueue", want)
		if ok then
			State.queued = want
			HUD.RefreshQueue()
			HUD.RefreshVotes()
			Notify.Show(msg, "info")
		elseif msg then
			Notify.Show(msg, "error")
		end
	end)
	driveButton = Util.button(bottom, "TEST DRIVE", T.accent, {
		Position = UDim2.new(0.5, 6, 0, 56),
		Size = UDim2.new(0.5, -6, 0, 56),
	}, function()
		if State.driving then
			State.Request("ExitCar")
		else
			HUD.CloseAll()
			local ok, msg = State.Request("TestDrive")
			if not ok and msg then
				Notify.Show(msg, "error")
			end
		end
	end)

	-- Map vote (right) ---------------------------------------------------------------
	voteFrame = Util.frame(root, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 230, 0, 96 + #Maps.Order * 44),
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.15,
	})
	Util.corner(voteFrame, 14)
	Util.stroke(voteFrame, T.accent2, 1.5, 0.5)
	autoScale(voteFrame)
	Util.label(voteFrame, "VOTE: RACE TYPE + MAP", {
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.new(0, 10, 0, 10),
		Font = Enum.Font.GothamBlack,
		TextColor3 = T.accent2,
	})
	for i, typeId in RaceTypes.Order do
		local info = RaceTypes.List[typeId]
		local button = Util.button(voteFrame, "", T.panel2, {
			Position = UDim2.new((i - 1) / 3, i == 1 and 10 or 3, 0, 44),
			Size = UDim2.new(1 / 3, -13, 0, 38),
		}, function()
			local ok, msg = State.Request("VoteType", typeId)
			if ok then
				State.myTypeVote = typeId
				HUD.RefreshVotes()
				Notify.Show(info.name .. ": " .. info.description, "info")
			elseif msg then
				Notify.Show(msg, "error")
			end
		end)
		local stripe = Util.frame(button, {
			Size = UDim2.new(1, 0, 0, 3),
			Position = UDim2.new(0, 0, 1, -3),
			BackgroundColor3 = info.color,
		})
		Util.corner(stripe, 2)
		local name = Util.label(button, string.upper(info.name), {
			Size = UDim2.new(1, 0, 0.55, 0),
			Font = Enum.Font.GothamBlack,
		})
		local count = Util.label(button, "0", {
			Size = UDim2.new(1, 0, 0.4, 0),
			Position = UDim2.new(0, 0, 0.55, 0),
			TextColor3 = T.gold,
		})
		typeButtons[typeId] = { button = button, count = count, name = name }
	end
	for i, mapId in Maps.Order do
		local map = Maps.List[mapId]
		local button = Util.button(voteFrame, "", T.panel2, {
			Position = UDim2.new(0, 10, 0, 88 + (i - 1) * 44),
			Size = UDim2.new(1, -20, 0, 38),
		}, function()
			local ok, msg = State.Request("Vote", mapId)
			if ok then
				State.myVote = mapId
				HUD.RefreshVotes()
			elseif msg then
				Notify.Show(msg, "error")
			end
		end)
		local stripe = Util.frame(button, {
			Size = UDim2.new(0, 6, 1, 0),
			Position = UDim2.new(0, -6, 0, 0),
			BackgroundColor3 = map.cardColor,
		})
		Util.corner(stripe, 3)
		local name = Util.label(button, map.name, {
			Size = UDim2.new(0.72, 0, 0.6, 0),
			Position = UDim2.new(0, 4, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local info = Util.label(button, string.format("%s • %d laps", map.difficulty, map.laps), {
			Size = UDim2.new(0.72, 0, 0.36, 0),
			Position = UDim2.new(0, 4, 0.62, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.sub,
			Font = Enum.Font.Gotham,
		})
		local count = Util.label(button, "0", {
			Size = UDim2.new(0.22, 0, 0.8, 0),
			Position = UDim2.new(0.78, 0, 0.1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBlack,
			TextColor3 = T.gold,
		})
		voteButtons[mapId] = { button = button, count = count, name = name, info = info }
	end

	State.On("Data", HUD.RefreshData)
	State.On("Race", function()
		HUD.RefreshStatus()
		HUD.RefreshVotes()
	end)
	State.On("Driving", function()
		HUD.RefreshDrive()
	end)
	HUD.RefreshQueue()
	HUD.RefreshDrive()
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
function HUD.RefreshData(data)
	data = data or State.data
	if not data or not coinsLabel then
		return
	end
	coinsLabel.Text = Util.formatNumber(data.coins)
	levelLabel.Text = tostring(data.level)
	if data.maxLevel and data.level >= data.maxLevel then
		Util.tween(xpFill, 0.3, { Size = UDim2.fromScale(1, 1) })
		xpFill.BackgroundColor3 = T.gold
		xpLabel.Text = "MAX LEVEL"
		return
	end
	xpFill.BackgroundColor3 = T.accent2
	local frac = math.clamp(data.xp / math.max(data.xpNeeded, 1), 0, 1)
	Util.tween(xpFill, 0.3, { Size = UDim2.fromScale(frac, 1) })
	xpLabel.Text = string.format("%s / %s XP", Util.formatNumber(data.xp), Util.formatNumber(data.xpNeeded))
end

function HUD.RefreshQueue()
	if not queueButton then
		return
	end
	queueButton.Text = State.queued and "RACE QUEUE: ON" or "RACE QUEUE: OFF"
	queueButton.BackgroundColor3 = State.queued and T.good or T.locked
end

function HUD.RefreshDrive()
	if not driveButton then
		return
	end
	driveButton.Text = State.driving and (State.driveMode == "free" and "EXIT FREE DRIVE" or "EXIT CAR (F)")
		or "TEST DRIVE"
	driveButton.BackgroundColor3 = State.driving and T.bad or T.accent
	-- Racing or free driving: hide the lobby HUD (the race HUD takes over).
	root.Visible = not (State.driving and (State.driveMode == "race" or State.driveMode == "free"))
end

function HUD.RefreshStatus()
	local race = State.race
	if not statusLabel then
		return
	end
	local mapName = race.mapId and Maps.List[race.mapId] and Maps.List[race.mapId].name or ""
	if race.raceType and RaceTypes.List[race.raceType] then
		mapName = RaceTypes.List[race.raceType].name .. " on " .. mapName
	end
	local text
	if race.phase == "Waiting" then
		text = "Waiting for racers — turn on the race queue!"
	elseif race.phase == "Intermission" then
		text = string.format("Next race in %ds  •  %d racer(s) ready", race.timeLeft, race.queuedCount or 0)
	elseif race.phase == "Loading" then
		text = "Loading " .. mapName .. "..."
	elseif race.phase == "Countdown" then
		text = mapName .. " is starting!"
	elseif race.phase == "Racing" then
		text = string.format("%s  •  %d:%02d left", mapName, race.timeLeft // 60, race.timeLeft % 60)
	elseif race.phase == "Results" then
		text = "Race finished! Next round soon..."
	else
		text = race.phase
	end
	statusLabel.Text = text
end

function HUD.RefreshVotes()
	if not voteFrame then
		return
	end
	local race = State.race
	local open = race.phase == "Intermission" or race.phase == "Waiting"
	voteFrame.Visible = open and State.queued
	if not open then
		State.myVote = nil
		State.myTypeVote = nil
	end
	for typeId, entry in typeButtons do
		entry.count.Text = tostring((race.typeVotes or {})[typeId] or 0)
		entry.button.BackgroundColor3 = State.myTypeVote == typeId and Color3.fromRGB(0, 120, 160) or T.panel2
	end
	for mapId, entry in voteButtons do
		entry.count.Text = tostring((race.votes or {})[mapId] or 0)
		local mine = State.myVote == mapId
		entry.button.BackgroundColor3 = mine and Color3.fromRGB(0, 120, 160) or T.panel2
	end
end

return HUD
