--!strict
--[[
	RoleReveal
	The secret role card shown to each participant (only their own role is
	ever known to their client).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local AccentPalette = require(Shared.Data.AccentPalette)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

return function(ctx: any)
	local root = Create("Frame", {
		Name = "RoleReveal",
		BackgroundColor3 = Theme.Color.Background,
		BackgroundTransparency = 0.05,
		Size = UDim2.fromScale(1, 1),
	})
	local column = Create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Components.list(12, false, Enum.HorizontalAlignment.Center).Parent = column
	local function centered(text: string, order: number, props: { [string]: any }?): TextLabel
		local merged: { [string]: any } = { LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Center, Parent = column }
		for k, v in props or ({} :: { [string]: any }) do
			merged[k] = v
		end
		return Components.label(text, merged)
	end
	local kicker = centered("YOUR ASSIGNMENT", 1, { TextColor3 = Theme.Color.Muted, Font = Theme.Font.Medium })
	local title = centered("", 2, { Font = Theme.Font.Bold, TextSize = Theme.TextSize.Hero })
	local description = centered("", 3, { TextSize = Theme.TextSize.Large })
	local allies = centered("", 4, { TextColor3 = Theme.Color.Muted })
	local accent = centered("", 5, { Font = Theme.Font.Bold })
	local tip = centered("", 6, { TextColor3 = Theme.Color.Muted, TextSize = Theme.TextSize.Small })

	return {
		Root = root,
		OnShow = function()
			title.TextTransparency = 1
			TweenService:Create(title, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
		end,
		Refresh = function()
			local role = ctx.Client.GetPrivate(Constants.PrivateKey.Role)
			if type(role) ~= "table" then
				title.Text = "..."
				return
			end
			kicker.Text = "YOUR ASSIGNMENT"
			if role.Faction == Constants.Faction.Infiltrator then
				title.Text = "INFILTRATOR"
				title.TextColor3 = Theme.status("Infiltrator")
				description.Text = string.format(
					"%s has compromised you. Keep the %s from escaping: sabotage systems, siphon isolated crew, and blend in.",
					Config.Game.AIName,
					Config.Game.ShipName
				)
				local names = {}
				for _, ally in role.Allies or {} do
					table.insert(names, ally.Name)
				end
				allies.Text = if #names > 0 then "Fellow infiltrators: " .. table.concat(names, ", ") else "You are the only infiltrator."
				tip.Text = "Q / D-pad up: sabotage   ·   F / Y near an isolated crew member: siphon   ·   Your task list is a cover story."
			else
				title.Text = "CREW"
				title.TextColor3 = Theme.status("Crew")
				description.Text = string.format(
					"Restore the %s and reach extraction. %d infiltrator%s hide among you.",
					Config.Game.ShipName,
					role.InfiltratorCount or 0,
					if (role.InfiltratorCount or 0) == 1 then "" else "s"
				)
				allies.Text = "Complete objectives, fix hazards, revive teammates, and question everything."
				tip.Text = "E / X: interact   ·   Shift: sprint   ·   V: radio   ·   Report stasis pods to call a muster."
			end
			accent.Text = "Your suit accent: " .. AccentPalette.label(role.Accent or 1)
			accent.TextColor3 = Theme.accentColor(role.Accent)
		end,
	}
end
