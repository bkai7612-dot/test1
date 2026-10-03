--!strict
--[[
	Admin (developer panel, F2)
	Only shown to players the server marked as admins. Every command is
	re-authorised on the server; this panel is just a convenience.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local COMMANDS: { { Id: string, Label: string, HasArgs: boolean } } = {
	{ Id = "StartRound", Label = "Start round", HasArgs = false },
	{ Id = "EndRound", Label = "End round (Crew/Infiltrator/None)", HasArgs = true },
	{ Id = "SpawnEvent", Label = "Spawn event (id or blank)", HasArgs = true },
	{ Id = "Sabotage", Label = "Sabotage id (target in arg 2)", HasArgs = true },
	{ Id = "GiveCredits", Label = "Give credits (amount)", HasArgs = true },
	{ Id = "GiveXp", Label = "Give XP (amount)", HasArgs = true },
	{ Id = "CompleteTasks", Label = "Complete my objectives", HasArgs = false },
	{ Id = "SetRestoration", Label = "Set restoration %", HasArgs = true },
	{ Id = "SetStability", Label = "Set stability %", HasArgs = true },
	{ Id = "ForceRole", Label = "Force my next role", HasArgs = true },
	{ Id = "Teleport", Label = "Teleport to room id", HasArgs = true },
	{ Id = "Notify", Label = "Broadcast message", HasArgs = true },
	{ Id = "ToggleEvents", Label = "Events on (true/false)", HasArgs = true },
	{ Id = "DownSelf", Label = "Put me in stasis", HasArgs = false },
	{ Id = "TestUI", Label = "Test notifications", HasArgs = false },
}

local function parse(text: string): any
	if text == "" then
		return nil
	elseif text == "true" then
		return true
	elseif text == "false" then
		return false
	end
	return tonumber(text) or text
end

return function(ctx: any)
	local root, body = Components.modal("Developer Tools", "Admin only. All commands are validated on the server.", ctx.Close, Vector2.new(900, 620))
	local left = Components.scroll({ Size = UDim2.new(0.55, -8, 1, 0), Parent = body })
	local right = Components.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.45, -8, 1, 0),
		BackgroundColor3 = Theme.Color.PanelLight,
		Parent = body,
	})
	Components.padding(8).Parent = right
	local output = Create("TextBox", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -44),
		Font = Theme.Font.Mono,
		TextSize = 12,
		TextColor3 = Theme.Color.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ClearTextOnFocus = false,
		TextEditable = false,
		MultiLine = true,
		Text = "",
		Parent = right,
	})
	Components.button("Refresh server state", function()
		local state = ctx.Invoke(Net.Names.DebugQuery, "ServerState")
		local ok, encoded = pcall(HttpService.JSONEncode, HttpService, state)
		output.Text = if ok then encoded else tostring(state)
	end, "Primary", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 38), Parent = right })

	for index, spec in COMMANDS do
		local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 38), LayoutOrder = index, Parent = left })
		local argA, argB
		if spec.HasArgs then
			argA = Create("TextBox", {
				PlaceholderText = "arg",
				Text = "",
				BackgroundColor3 = Theme.Color.PanelLight,
				TextColor3 = Theme.Color.Text,
				Font = Theme.Font.Regular,
				TextSize = 13,
				Position = UDim2.new(0.55, 4, 0, 2),
				Size = UDim2.new(0.22, -4, 1, -4),
				ClearTextOnFocus = false,
				Parent = row,
			})
			argB = Create("TextBox", {
				PlaceholderText = "arg 2",
				Text = "",
				BackgroundColor3 = Theme.Color.PanelLight,
				TextColor3 = Theme.Color.Text,
				Font = Theme.Font.Regular,
				TextSize = 13,
				Position = UDim2.new(0.77, 4, 0, 2),
				Size = UDim2.new(0.23, -4, 1, -4),
				ClearTextOnFocus = false,
				Parent = row,
			})
		end
		Components.button(spec.Label, function()
			local a = if argA then parse(argA.Text) else nil
			local b = if argB then parse(argB.Text) else nil
			local result = ctx.Invoke(Net.Names.AdminCommand, spec.Id, a, b)
			output.Text = if type(result) == "table" then string.format("%s: %s", if result.Ok then "OK" else "FAILED", tostring(result.Message)) else "No response (not authorised?)"
		end, "Secondary", { Size = UDim2.new(if spec.HasArgs then 0.55 else 1, 0, 1, -4), TextSize = 13, Parent = row })
	end

	return { Root = root }
end
