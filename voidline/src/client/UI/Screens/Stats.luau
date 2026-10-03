--!strict
--[[
	Stats
	Level progress, lifetime statistics and ship badges.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Progression = require(Shared.Logic.Progression)
local Format = require(Shared.Utility.Format)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local STAT_LABELS = {
	{ "RoundsPlayed", "Rounds played" },
	{ "Wins", "Wins" },
	{ "CrewWins", "Wins as crew" },
	{ "InfiltratorWins", "Wins as infiltrator" },
	{ "TimesInfiltrator", "Rounds as infiltrator" },
	{ "TasksCompleted", "Objectives completed" },
	{ "Escapes", "Escapes" },
	{ "Revives", "Teammates revived" },
	{ "Siphons", "Siphons" },
	{ "CorrectVotes", "Correct accusations" },
	{ "EvidenceRevealed", "Evidence revealed" },
	{ "HazardsFixed", "Hazards fixed" },
	{ "Survived", "Rounds survived" },
}

return function(ctx: any)
	local root, body = Components.modal("Statistics", nil, ctx.Close)
	local levelBar = Components.progress(20)
	levelBar.Frame.Parent = body
	local columns = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), Parent = body })
	local statsList = Components.scroll({ Size = UDim2.new(0.5, -8, 1, 0), Parent = columns })
	local badgeList = Components.scroll({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, -8, 1, 0), Parent = columns })

	return {
		Root = root,
		Refresh = function()
			local profile = ctx.Client.GetPrivate(Constants.PrivateKey.Profile)
			if type(profile) ~= "table" then
				return
			end
			local need = Progression.xpToNext(profile.Level)
			levelBar.Set(profile.Xp / need, string.format("LEVEL %d  ·  %d / %d XP  ·  %s credits", profile.Level, profile.Xp, need, Format.thousands(profile.Credits)))
			Components.clear(statsList)
			for index, pair in STAT_LABELS do
				local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 24), LayoutOrder = index, Parent = statsList })
				Components.label(pair[2], { Size = UDim2.new(0.7, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None, Parent = row })
				Components.label(tostring((profile.Stats or {})[pair[1]] or 0), {
					Position = UDim2.fromScale(0.7, 0),
					Size = UDim2.new(0.3, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.None,
					TextXAlignment = Enum.TextXAlignment.Right,
					Font = Theme.Font.Bold,
					Parent = row,
				})
			end
			Components.clear(badgeList)
			Components.label("SHIP BADGES", { Font = Theme.Font.Bold, TextColor3 = Theme.Color.Accent, LayoutOrder = 0, Parent = badgeList })
			local earned: { [string]: boolean } = {}
			for _, badge in Progression.earnedBadges(profile.Stats or {}) do
				earned[badge.Id] = true
			end
			for index, badge in Progression.Badges do
				local has = earned[badge.Id] == true
				Components.label((if has then "★ " else "☆ ") .. badge.Name, {
					Font = Theme.Font.Bold,
					TextColor3 = if has then Theme.status("Warning") else Theme.Color.Faint,
					LayoutOrder = index * 2,
					Parent = badgeList,
				})
				Components.label("   " .. badge.Description, {
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Color.Muted,
					LayoutOrder = index * 2 + 1,
					Parent = badgeList,
				})
			end
		end,
	}
end
