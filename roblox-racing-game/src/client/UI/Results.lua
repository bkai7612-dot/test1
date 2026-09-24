-- End-of-race results screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Maps = require(Shared.Maps)
local RaceTypes = require(Shared.RaceTypes)
local Util = require(script.Parent.Util)
local T = Util.Theme

local Results = {}

local frame, content, subtitle, rewardLabel, list
local localUserId

function Results.Init(gui, _hud, userId)
	localUserId = userId
	frame, content = Util.panel(gui, "RACE RESULTS", UDim2.fromOffset(640, 480), function()
		Results.Hide()
	end)
	frame.ZIndex = 10

	subtitle = Util.label(content, "", {
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = T.accent,
		Font = Enum.Font.GothamBlack,
	})
	rewardLabel = Util.label(content, "", {
		Position = UDim2.new(0, 0, 0, 30),
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = T.gold,
		Font = Enum.Font.GothamBlack,
	})
	list = Util.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 70),
		Size = UDim2.new(1, 0, 1, -70),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = content,
	})
	Util.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
end

function Results.Show(payload)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local map = Maps.List[payload.mapId]
	local typeInfo = RaceTypes.List[payload.raceType]
	local heading = (typeInfo and string.upper(typeInfo.name) .. "  •  " or "") .. (map and string.upper(map.name) or "")
	subtitle.TextColor3 = T.accent
	if payload.teams then
		local winner = Config.Teams[payload.teams.winner]
		heading = string.format(
			"%s TEAM WINS  %d - %d  •  %s",
			winner.name,
			payload.teams[payload.teams.winner],
			payload.teams[payload.teams.winner == "Red" and "Blue" or "Red"],
			payload.label or ""
		)
		subtitle.TextColor3 = winner.color
	end
	subtitle.Text = heading
	rewardLabel.Text = ""

	for i, entry in payload.results do
		local mine = entry.userId == localUserId
		local row = Util.frame(list, {
			Size = UDim2.new(1, -10, 0, 40),
			BackgroundColor3 = mine and Color3.fromRGB(60, 50, 20) or T.panel,
			LayoutOrder = i,
		})
		Util.corner(row, 8)
		local place = entry.place and Util.ordinal(entry.place) or "DNF"
		if entry.team and Config.Teams[entry.team] then
			local stripe = Util.frame(row, {
				Size = UDim2.new(0, 5, 1, 0),
				BackgroundColor3 = Config.Teams[entry.team].color,
			})
			Util.corner(stripe, 3)
		end
		Util.label(row, place, {
			Position = UDim2.new(0, 10, 0, 6),
			Size = UDim2.new(0, 60, 0, 28),
			Font = Enum.Font.GothamBlack,
			TextColor3 = entry.place == 1 and T.gold or T.text,
		})
		Util.label(row, entry.name, {
			Position = UDim2.new(0, 80, 0, 8),
			Size = UDim2.new(0.45, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Util.label(row, entry.eliminated and "ELIMINATED" or (Util.formatTime(entry.time) .. (entry.newBest and "  PB!" or "")), {
			Position = UDim2.new(0.55, 0, 0, 8),
			Size = UDim2.new(0.22, 0, 0, 24),
			TextColor3 = entry.newBest and T.good or T.accent2,
		})
		local capped = (entry.xpCoins or 0) > 0
		local rewardText = capped and string.format("+%d  •  MAX LV", entry.coins + entry.xpCoins)
			or string.format("+%d  •  +%d XP", entry.coins, entry.xp)
		Util.label(row, rewardText, {
			Position = UDim2.new(0.78, 0, 0, 10),
			Size = UDim2.new(0.21, 0, 0, 20),
			TextColor3 = T.gold,
		})
		if mine then
			if capped then
				rewardLabel.Text = string.format(
					"You earned %s coins (+%s from XP at max level)!",
					Util.formatNumber(entry.coins + entry.xpCoins),
					Util.formatNumber(entry.xpCoins)
				)
			else
				local placeText = entry.place and (Util.ordinal(entry.place) .. " place") or "DNF"
				rewardLabel.Text = string.format(
					"%s: %s coins and %s XP!",
					placeText,
					Util.formatNumber(entry.coins),
					Util.formatNumber(entry.xp)
				)
			end
		end
	end

	frame.Visible = true
	local token = {}
	Results._token = token
	task.delay(Config.RESULTS_TIME + 2, function()
		if Results._token == token then
			Results.Hide()
		end
	end)
end

function Results.Hide()
	frame.Visible = false
end

return Results
