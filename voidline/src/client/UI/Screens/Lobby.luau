--!strict
--[[
	Lobby
	Crew roster with ready states, the countdown, host match settings (private
	servers), and quick access to the menu and training.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

return function(ctx: any)
	local root = Components.panel({
		Name = "Lobby",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(340, 560),
	})
	Components.padding(14).Parent = root

	local header = Components.header("Departure Lounge", "Waiting to board the ASTERION")
	header.Parent = root

	local status = Components.label("", {
		Position = UDim2.fromOffset(0, 62),
		Font = Theme.Font.Medium,
		TextColor3 = Theme.Color.Accent,
		Parent = root,
	})
	local countdown = Components.label("", {
		Position = UDim2.fromOffset(0, 104),
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Title,
		Parent = root,
	})

	local list = Components.scroll({
		Position = UDim2.fromOffset(0, 140),
		Size = UDim2.new(1, 0, 1, -330),
		Parent = root,
	})

	local hostPanel = Create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -100),
		Size = UDim2.new(1, 0, 0, 86),
		Visible = false,
		Parent = root,
	})
	Components.list(4).Parent = hostPanel
	local hostControls: { [string]: any } = {}

	local readyButton: TextButton
	local isReady = false
	readyButton = Components.button("READY", function()
		isReady = not isReady
		ctx.Fire(Net.Names.SetReady, isReady)
	end, "Success", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -48),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = Theme.TextSize.Large,
		Parent = root,
	})
	Components.button("Menu (M)", function()
		ctx.Open("MainMenu")
	end, "Ghost", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.5, -4, 0, 40),
		Parent = root,
	})
	Components.button("Training", function()
		ctx.StartTutorial()
	end, "Ghost", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.5, -4, 0, 40),
		Parent = root,
	})

	local function buildHost(lobby: any)
		if hostControls.Built then
			return
		end
		hostControls.Built = true
		local settings = lobby.Settings or {}
		local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = hostPanel })
		local infiltrators = Components.cycle({ "0", "1", "2", "3" }, tostring(settings.InfiltratorCount or 0), function(value)
			ctx.Fire(Net.Names.HostSetting, "InfiltratorCount", tonumber(value))
		end, function(value)
			return if value == "0" then "Infiltrators: Auto" else "Infiltrators: " .. value
		end)
		infiltrators.Size = UDim2.new(0.6, -4, 1, 0)
		infiltrators.TextSize = Theme.TextSize.Small
		infiltrators.Parent = row
		Components.button("Start now", function()
			ctx.Fire(Net.Names.HostStart)
		end, "Primary", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.4, -4, 1, 0),
			TextSize = Theme.TextSize.Small,
			Parent = row,
		})
		local row2 = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = hostPanel })
		local discussion = Components.cycle({ "30", "45", "60", "75", "90", "120" }, tostring(settings.DiscussionSeconds or 60), function(value)
			ctx.Fire(Net.Names.HostSetting, "DiscussionSeconds", tonumber(value))
		end, function(value)
			return "Talk " .. value .. "s"
		end)
		discussion.Size = UDim2.new(0.5, -4, 1, 0)
		discussion.TextSize = Theme.TextSize.Small
		discussion.Parent = row2
		local reveal = Components.cycle({ "Faction", "None" }, settings.RevealOnConfine or "Faction", function(value)
			ctx.Fire(Net.Names.HostSetting, "RevealOnConfine", value)
		end, function(value)
			return if value == "Faction" then "Reveal roles" else "Hide roles"
		end)
		reveal.AnchorPoint = Vector2.new(1, 0)
		reveal.Position = UDim2.fromScale(1, 0)
		reveal.Size = UDim2.new(0.5, -4, 1, 0)
		reveal.TextSize = Theme.TextSize.Small
		reveal.Parent = row2
	end

	local function refresh()
		local lobby = ctx.Client.GetPublic(Constants.PublicKey.Lobby)
		if type(lobby) ~= "table" then
			status.Text = "Connecting to departures..."
			return
		end
		status.Text = lobby.Status or ""
		local endsAt = lobby.CountdownEndsAt
		if type(endsAt) == "number" then
			local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			countdown.Text = string.format("Launch in %ds", remaining)
		else
			countdown.Text = string.format("%d / %d crew", #(lobby.Players or {}), lobby.Required or 0)
		end

		Components.clear(list)
		local me = game:GetService("Players").LocalPlayer.UserId
		for index, entry in lobby.Players or {} do
			if entry.UserId == me then
				isReady = entry.Ready == true
			end
			local row = Components.panel({
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, 40),
				BackgroundColor3 = Theme.Color.PanelLight,
				Parent = list,
			})
			Components.label(entry.Name .. (if entry.IsHost then "  (Host)" else ""), {
				Position = UDim2.fromOffset(10, 3),
				Size = UDim2.new(1, -110, 0, 18),
				AutomaticSize = Enum.AutomaticSize.None,
				Font = Theme.Font.Medium,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = row,
			})
			Components.label(string.format("Lv %d  %s", entry.Level or 1, entry.Title or ""), {
				Position = UDim2.fromOffset(10, 20),
				Size = UDim2.new(1, -110, 0, 16),
				AutomaticSize = Enum.AutomaticSize.None,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Color.Muted,
				Parent = row,
			})
			local chip = Components.chip(if entry.Ready then "✓ READY" else "… WAITING", if entry.Ready then Theme.status("Success") else Theme.Color.Muted)
			chip.AnchorPoint = Vector2.new(1, 0.5)
			chip.Position = UDim2.new(1, -8, 0.5, 0)
			chip.Parent = row
		end
		readyButton.Text = if isReady then "NOT READY" else "READY"

		local isHost = lobby.IsPrivate and lobby.HostUserId == me
		hostPanel.Visible = isHost == true
		if isHost then
			buildHost(lobby)
		end
	end

	-- Keep the countdown ticking between server updates.
	task.spawn(function()
		while true do
			task.wait(1)
			if root.Visible then
				local lobby = ctx.Client.GetPublic(Constants.PublicKey.Lobby)
				if type(lobby) == "table" and type(lobby.CountdownEndsAt) == "number" then
					countdown.Text = string.format("Launch in %ds", math.max(0, math.ceil(lobby.CountdownEndsAt - workspace:GetServerTimeNow())))
				end
			end
		end
	end)

	return { Root = root, Refresh = refresh }
end
