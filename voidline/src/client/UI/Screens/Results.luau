--!strict
--[[
	Results
	Winner, reason, every participant's faction and fate, and the local
	player's rewards (XP breakdown, credits, level progress).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local AccentPalette = require(Shared.Data.AccentPalette)
local Progression = require(Shared.Logic.Progression)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local FATE = {
	Alive = "Survived",
	Escaped = "Escaped",
	Lost = "Lost in stasis",
	Confined = "Confined",
	Downed = "In stasis",
	Disconnected = "Disconnected",
}

return function(ctx: any)
	local root = Create("Frame", {
		Name = "Results",
		BackgroundColor3 = Theme.Color.Background,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromScale(1, 1),
	})
	local banner = Components.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(900, 60),
		AutomaticSize = Enum.AutomaticSize.None,
		Font = Theme.Font.Display,
		TextSize = Theme.TextSize.Hero,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})
	local reason = Components.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(900, 24),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Color.Muted,
		TextSize = Theme.TextSize.Large,
		Parent = root,
	})

	local roster = Components.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -10, 0, 150),
		Size = UDim2.fromOffset(460, 440),
		Parent = root,
	})
	Components.padding(12).Parent = roster
	Components.label("CREW MANIFEST", { Font = Theme.Font.Bold, TextColor3 = Theme.Color.Accent, Parent = roster })
	local rosterList = Components.scroll({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26), Parent = roster })

	local rewards = Components.panel({
		Position = UDim2.new(0.5, 10, 0, 150),
		Size = UDim2.fromOffset(420, 440),
		Parent = root,
	})
	Components.padding(12).Parent = rewards
	Components.label("YOUR PERFORMANCE", { Font = Theme.Font.Bold, TextColor3 = Theme.Color.Accent, Parent = rewards })
	local rewardList = Components.scroll({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -110), Parent = rewards })
	local totals = Components.label("", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -30),
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Large,
		Parent = rewards,
	})
	local levelBar = Components.progress(16, Theme.Color.Accent)
	levelBar.Frame.AnchorPoint = Vector2.new(0, 1)
	levelBar.Frame.Position = UDim2.fromScale(0, 1)
	levelBar.Frame.Parent = rewards

	return {
		Root = root,
		Refresh = function()
			local results = ctx.Client.GetPublic(Constants.PublicKey.Results)
			if type(results) ~= "table" then
				return
			end
			if results.Winner == Constants.Winner.Crew then
				banner.Text = "CREW VICTORY"
				banner.TextColor3 = Theme.status("Crew")
			elseif results.Winner == Constants.Winner.Infiltrator then
				banner.Text = "INFILTRATORS WIN"
				banner.TextColor3 = Theme.status("Infiltrator")
			else
				banner.Text = "SHIP LOST"
				banner.TextColor3 = Theme.Color.Muted
			end
			reason.Text = results.Reason or ""

			Components.clear(rosterList)
			local players = results.Players or {}
			table.sort(players, function(a, b)
				if a.Faction ~= b.Faction then
					return a.Faction == Constants.Faction.Infiltrator
				end
				return a.Name < b.Name
			end)
			for index, entry in players do
				local row = Create("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -8, 0, 26),
					LayoutOrder = index,
					Parent = rosterList,
				})
				Components.label(entry.Name, {
					Size = UDim2.new(0.42, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.None,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Font = Theme.Font.Medium,
					Parent = row,
				})
				Components.label(string.upper(entry.Faction or "?"), {
					Position = UDim2.fromScale(0.42, 0),
					Size = UDim2.new(0.25, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.None,
					Font = Theme.Font.Bold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.factionColor(entry.Faction),
					Parent = row,
				})
				Components.label((FATE :: any)[entry.Life] or entry.Life or "", {
					Position = UDim2.fromScale(0.67, 0),
					Size = UDim2.new(0.33, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.None,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Color.Muted,
					Parent = row,
				})
				Create("Frame", {
					BackgroundColor3 = Theme.accentColor(entry.Accent),
					Size = UDim2.new(0, 3, 1, -6),
					Position = UDim2.new(0, -6, 0, 3),
					BorderSizePixel = 0,
					Parent = row,
				})
				row:SetAttribute("Accent", AccentPalette.label(entry.Accent or 1))
			end

			Components.clear(rewardList)
			local reward = ctx.Client.GetPrivate(Constants.PrivateKey.Reward)
			if type(reward) == "table" then
				for index, line in reward.Lines or {} do
					local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 22), LayoutOrder = index, Parent = rewardList })
					Components.label(line.Label, { Size = UDim2.new(0.75, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None, Parent = row })
					Components.label("+" .. line.Xp .. " XP", {
						Position = UDim2.fromScale(0.75, 0),
						Size = UDim2.new(0.25, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.None,
						TextXAlignment = Enum.TextXAlignment.Right,
						TextColor3 = Theme.Color.Accent,
						Parent = row,
					})
				end
				totals.Text = string.format("+%d XP   +%d credits%s", reward.Xp or 0, reward.Credits or 0, if (reward.LevelsGained or 0) > 0 then "   LEVEL UP!" else "")
			else
				totals.Text = "Rewards are calculated for crew who finished the round."
			end
			local profile = ctx.Client.GetPrivate(Constants.PrivateKey.Profile)
			if type(profile) == "table" then
				local need = Progression.xpToNext(profile.Level)
				levelBar.Set(profile.Xp / need, string.format("LEVEL %d  ·  %d / %d XP", profile.Level, profile.Xp, need))
			end
		end,
	}
end
