-- In-car HUD: countdown, position, lap, timer, standings, speedometer,
-- nitro gauge and control hints.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RaceTypes = require(Shared.RaceTypes)
local Util = require(script.Parent.Util)
local T = Util.Theme

local RaceHUD = {}

local root, raceInfo, countdownLabel, bannerLabel
local positionLabel, totalLabel, lapLabel, timeLabel
local standingsFrame, standingRows = nil, {}
local speedLabel, nitroFill, hints
local typeLabel, teamBar, redLabel, blueLabel
local mode = nil
local localUserId

local function playBeep(speed)
	local sound = Instance.new("Sound")
	sound.SoundId = Config.Sounds.Countdown
	sound.PlaybackSpeed = speed or 1
	sound.Volume = 0.6
	SoundService:PlayLocalSound(sound)
end

function RaceHUD.Init(gui, hud, userId)
	localUserId = userId
	root = Util.frame(gui, { Name = "RaceHUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })

	countdownLabel = Util.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.3, 0.22),
		Font = Enum.Font.GothamBlack,
		TextColor3 = T.accent,
		TextStrokeTransparency = 0.2,
		Visible = false,
	})
	bannerLabel = Util.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromScale(0.5, 0.08),
		Font = Enum.Font.GothamBlack,
		TextColor3 = T.gold,
		TextStrokeTransparency = 0.3,
		Visible = false,
	})

	-- Top-right race info ----------------------------------------------------------
	raceInfo = Util.frame(root, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 56),
		Size = UDim2.new(0, 250, 0, 150),
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.2,
	})
	Util.corner(raceInfo, 14)
	hud.AutoScale(raceInfo)
	positionLabel = Util.label(raceInfo, "1st", {
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(0, 120, 0, 64),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.gold,
	})
	totalLabel = Util.label(raceInfo, "/ 1", {
		Position = UDim2.new(0, 136, 0, 30),
		Size = UDim2.new(0, 100, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.sub,
	})
	lapLabel = Util.label(raceInfo, "LAP 1/3", {
		Position = UDim2.new(0, 14, 0, 78),
		Size = UDim2.new(1, -28, 0, 28),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	timeLabel = Util.label(raceInfo, "0:00.00", {
		Position = UDim2.new(0, 14, 0, 110),
		Size = UDim2.new(1, -28, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.accent2,
	})

	-- Race type + team score (top centre) --------------------------------------------
	typeLabel = Util.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 360, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.4,
	})
	teamBar = Util.frame(root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 38),
		Size = UDim2.new(0, 300, 0, 34),
		BackgroundTransparency = 1,
		Visible = false,
	})
	hud.AutoScale(teamBar)
	local red = Util.frame(teamBar, { Size = UDim2.new(0.5, -3, 1, 0), BackgroundColor3 = Config.Teams.Red.color })
	Util.corner(red, 8)
	redLabel = Util.label(red, "RED 0", { Size = UDim2.new(1, -12, 1, -8), Position = UDim2.new(0, 6, 0, 4), Font = Enum.Font.GothamBlack })
	local blue = Util.frame(teamBar, {
		Position = UDim2.new(0.5, 3, 0, 0),
		Size = UDim2.new(0.5, -3, 1, 0),
		BackgroundColor3 = Config.Teams.Blue.color,
	})
	Util.corner(blue, 8)
	blueLabel = Util.label(blue, "0 BLUE", { Size = UDim2.new(1, -12, 1, -8), Position = UDim2.new(0, 6, 0, 4), Font = Enum.Font.GothamBlack })

	-- Standings (left) -----------------------------------------------------------------
	standingsFrame = Util.frame(root, {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 56),
		Size = UDim2.new(0, 220, 0, 8 * 28 + 12),
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.35,
	})
	Util.corner(standingsFrame, 12)
	hud.AutoScale(standingsFrame)
	for i = 1, 8 do
		standingRows[i] = Util.label(standingsFrame, "", {
			Position = UDim2.new(0, 10, 0, 6 + (i - 1) * 28),
			Size = UDim2.new(1, -20, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	-- Speedometer (bottom-right) -----------------------------------------------------------
	local speedo = Util.frame(root, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 230, 0, 120),
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.2,
	})
	Util.corner(speedo, 14)
	hud.AutoScale(speedo)
	speedLabel = Util.label(speedo, "0", {
		Position = UDim2.new(0, 14, 0, 6),
		Size = UDim2.new(0, 140, 0, 70),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	Util.label(speedo, "MPH", {
		Position = UDim2.new(0, 160, 0, 36),
		Size = UDim2.new(0, 60, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.sub,
	})
	Util.label(speedo, "NITRO", {
		Position = UDim2.new(0, 14, 0, 84),
		Size = UDim2.new(0, 56, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.accent2,
	})
	local _, fill = Util.bar(speedo, {
		Position = UDim2.new(0, 74, 0, 86),
		Size = UDim2.new(1, -88, 0, 14),
	})
	nitroFill = fill
	nitroFill.BackgroundColor3 = T.accent2

	-- Control hints (bottom-left) ----------------------------------------------------------
	hints = Util.label(root, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.new(0, 520, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(220, 220, 230),
		TextStrokeTransparency = 0.5,
		Font = Enum.Font.Gotham,
	})
end

function RaceHUD.Show(newMode)
	mode = newMode
	root.Visible = true
	local racing = mode == "race"
	raceInfo.Visible = racing
	standingsFrame.Visible = racing
	teamBar.Visible = false
	hints.Visible = not UserInputService.TouchEnabled
	if racing then
		hints.Text = "W/S drive • A/D steer • SPACE drift • SHIFT nitro • R respawn • V camera • C look back"
	elseif mode == "free" then
		hints.Text = "FREE DRIVE • W/S drive • A/D steer • SPACE drift • SHIFT nitro • R respawn • F leave"
	else
		hints.Text = "W/S drive • A/D steer • SPACE drift • SHIFT nitro • R reset • F exit car"
	end
	typeLabel.Text = mode == "free" and "FREE DRIVE" or ""
	typeLabel.TextColor3 = RaceTypes.List.FreeDrive.color
	speedLabel.Text = "0"
end

function RaceHUD.Hide()
	mode = nil
	root.Visible = false
	countdownLabel.Visible = false
	bannerLabel.Visible = false
end

function RaceHUD.Banner(text, color, duration)
	bannerLabel.Text = text
	bannerLabel.TextColor3 = color or T.gold
	bannerLabel.Visible = true
	local token = {}
	RaceHUD._bannerToken = token
	task.delay(duration or 2.5, function()
		if RaceHUD._bannerToken == token then
			bannerLabel.Visible = false
		end
	end)
end

function RaceHUD.Countdown(n)
	countdownLabel.Visible = true
	countdownLabel.Text = n > 0 and tostring(n) or "GO!"
	countdownLabel.TextColor3 = n > 0 and T.accent or T.good
	countdownLabel.Size = UDim2.fromScale(0.45, 0.33)
	Util.tween(countdownLabel, 0.5, { Size = UDim2.fromScale(0.3, 0.22) }, Enum.EasingStyle.Back)
	playBeep(n > 0 and 1 or 1.6)
	if n == 0 then
		task.delay(1, function()
			countdownLabel.Visible = false
		end)
	end
end

function RaceHUD.Update(info)
	if mode ~= "race" then
		return
	end
	positionLabel.Text = Util.ordinal(info.position)
	totalLabel.Text = "/ " .. info.total
	lapLabel.Text = info.laps == 1 and "SPRINT" or string.format("LAP %d/%d", info.lap, info.laps)
	timeLabel.Text = Util.formatTime(info.elapsed)
	local typeInfo = RaceTypes.List[info.raceType]
	if typeInfo then
		typeLabel.Text = string.upper(typeInfo.name) .. (info.label and ("  •  " .. info.label) or "")
		typeLabel.TextColor3 = typeInfo.color
	end
	if info.teamScores then
		teamBar.Visible = true
		redLabel.Text = "RED " .. info.teamScores.Red
		blueLabel.Text = info.teamScores.Blue .. " BLUE"
	else
		teamBar.Visible = false
	end
	for i, row in standingRows do
		local entry = info.standings[i]
		if entry then
			local suffix = entry.finished and "  FIN" or entry.eliminated and "  OUT" or (entry.dnf and "  DNF" or "")
			row.Text = string.format("%d. %s%s", i, entry.name, suffix)
			if entry.userId == localUserId then
				row.TextColor3 = T.gold
			elseif entry.team and Config.Teams[entry.team] then
				row.TextColor3 = Config.Teams[entry.team].color
			else
				row.TextColor3 = T.text
			end
		else
			row.Text = ""
		end
	end
end

function RaceHUD.OnCheckpoint(info)
	if info.freeLap then
		RaceHUD.Banner((info.best and "BEST LAP  " or "LAP  ") .. Util.formatTime(info.freeLap), info.best and T.good or T.accent2, 3)
		playBeep(1.3)
		return
	end
	if info.eliminated then
		RaceHUD.Banner("ELIMINATED! You finished " .. Util.ordinal(info.place), T.bad, 4)
		playBeep(0.7)
		return
	end
	if info.finished then
		RaceHUD.Banner("FINISHED " .. Util.ordinal(info.place) .. "!  " .. Util.formatTime(info.time), T.gold, 5)
		playBeep(2)
		return
	end
	if info.newLap then
		if info.lap == info.laps then
			RaceHUD.Banner("FINAL LAP!", T.bad, 2.5)
		else
			RaceHUD.Banner(string.format("LAP %d / %d", info.lap, info.laps), T.accent2, 2)
		end
		playBeep(1.3)
	end
end

function RaceHUD.SetTelemetry(speed, _topSpeed, nitroFrac, boosting)
	if not root.Visible then
		return
	end
	speedLabel.Text = tostring(math.floor(math.abs(speed) * Config.SPEED_TO_MPH))
	speedLabel.TextColor3 = boosting and T.accent2 or T.text
	nitroFill.Size = UDim2.fromScale(math.clamp(nitroFrac, 0, 1), 1)
end

return RaceHUD
