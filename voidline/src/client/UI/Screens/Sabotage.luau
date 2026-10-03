--!strict
--[[
	Sabotage (infiltrator console)
	Choose a sabotage, pick its target (section or room) where needed, and
	send it. Cooldowns are shown from the server's private Abilities data;
	the server re-validates everything. Also hosts the one-use log Spoof.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local SabotageCatalog = require(Shared.Data.SabotageCatalog)
local ShipLayout = require(Shared.Data.ShipLayout)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

return function(ctx: any)
	local root, body = Components.modal("MURMUR Link", "Sabotage the ASTERION. Each use leaves an anomaly in the ship log.", ctx.Close, Vector2.new(820, 600))
	local list = Components.scroll({ Size = UDim2.new(1, 0, 1, -56), Parent = body })

	local roomIds = {}
	for _, room in ShipLayout.Rooms do
		table.insert(roomIds, room.Id)
	end
	local targets: { [string]: string } = {}
	local cooldownLabels: { [string]: TextLabel } = {}
	local globalLabel = Components.label("", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.5, 0, 0, 44),
		AutomaticSize = Enum.AutomaticSize.None,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Theme.Font.Bold,
		Parent = body,
	})

	-- Spoof
	local spoofRoom = roomIds[1]
	local spoofRow = Create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.5, 0, 0, 44),
		Parent = body,
	})
	local spoofPicker = Components.cycle(roomIds, spoofRoom, function(value)
		spoofRoom = value
	end, function(value)
		return ShipLayout.areaName(value)
	end)
	spoofPicker.Size = UDim2.new(0.55, -4, 1, 0)
	spoofPicker.TextSize = Theme.TextSize.Small
	spoofPicker.Parent = spoofRow
	local spoofButton = Components.button("Plant false trace", function()
		ctx.Fire(Net.Names.Spoof, spoofRoom)
	end, "Danger", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.45, -4, 1, 0),
		TextSize = Theme.TextSize.Small,
		Parent = spoofRow,
	})

	for index, sabotage in SabotageCatalog.Sabotages do
		local card = Components.panel({
			LayoutOrder = index,
			Size = UDim2.new(1, -10, 0, 74),
			BackgroundColor3 = Theme.Color.PanelLight,
			Parent = list,
		})
		Components.padding(8).Parent = card
		Components.label(sabotage.Name, {
			Font = Theme.Font.Bold,
			Size = UDim2.new(0.5, 0, 0, 20),
			AutomaticSize = Enum.AutomaticSize.None,
			Parent = card,
		})
		Components.label(sabotage.Description, {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(0.5, 0, 0, 36),
			AutomaticSize = Enum.AutomaticSize.None,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Color.Muted,
			Parent = card,
		})
		cooldownLabels[sabotage.Id] = Components.label("", {
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0.2, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextSize = Theme.TextSize.Small,
			Parent = card,
		})
		if sabotage.Target ~= "Ship" then
			local options = if sabotage.Target == "Section" then ShipLayout.Sections else roomIds
			targets[sabotage.Id] = options[1]
			local picker = Components.cycle(options, options[1], function(value)
				targets[sabotage.Id] = value
			end, function(value)
				return if sabotage.Target == "Section" then (if value == "Mid" then "Midship" else value) else ShipLayout.areaName(value)
			end)
			picker.AnchorPoint = Vector2.new(1, 0.5)
			picker.Position = UDim2.new(1, -130, 0.5, 0)
			picker.Size = UDim2.fromOffset(170, 36)
			picker.TextSize = Theme.TextSize.Small
			picker.Parent = card
		end
		Components.button("SEND", function()
			ctx.Fire(Net.Names.Sabotage, sabotage.Id, targets[sabotage.Id])
			ctx.Close()
		end, "Danger", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(120, 40),
			Parent = card,
		})
	end

	local function refresh()
		local abilities = ctx.Client.GetPrivate(Constants.PrivateKey.Abilities)
		local now = workspace:GetServerTimeNow()
		if type(abilities) ~= "table" then
			globalLabel.Text = "Link offline."
			return
		end
		local global = (abilities.GlobalReadyAt or 0) - now
		globalLabel.Text = if global > 0 then string.format("Link recharging: %ds", math.ceil(global)) else "Link ready."
		globalLabel.TextColor3 = if global > 0 then Theme.status("Warning") else Theme.status("Success")
		for id, label in cooldownLabels do
			local readyAt = (abilities.TypeReadyAt or {})[id] or 0
			local remaining = readyAt - now
			label.Text = if remaining > 0 then string.format("Cooldown %ds", math.ceil(remaining)) else "Ready"
			label.TextColor3 = if remaining > 0 then Theme.Color.Muted else Theme.status("Success")
		end
		spoofButton.Text = string.format("Plant false trace (%d)", abilities.SpoofUses or 0)
		Components.setEnabled(spoofButton, (abilities.SpoofUses or 0) > 0)
	end

	task.spawn(function()
		while true do
			task.wait(0.5)
			if root.Visible then
				refresh()
			end
		end
	end)

	return { Root = root, Refresh = refresh }
end
