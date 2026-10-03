--!strict
--[[
	Spectator
	For Signal Ghosts (lost or confined players) and for players waiting for
	the next round. Ghosts can cycle the camera between living crew and send
	a "static whisper" into a room (an anonymous, cooldown-limited ping).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local ShipLayout = require(Shared.Data.ShipLayout)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

return function(ctx: any)
	local root = Components.panel({
		Name = "Spectator",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Components.padding(12).Parent = root
	Components.list(8).Parent = root

	local title = Components.label("", { Font = Theme.Font.Bold, TextSize = Theme.TextSize.Large, TextColor3 = Theme.Color.Ghost, LayoutOrder = 1, Parent = root })
	local info = Components.label("", { TextColor3 = Theme.Color.Muted, LayoutOrder = 2, Parent = root })

	local camRow = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 3, Parent = root })
	Components.list(8, true).Parent = camRow
	Components.button("◀ Prev", function()
		if not ctx.Camera.IsSpectating() then
			ctx.Camera.StartSpectating()
		end
		ctx.Camera.Cycle(-1)
	end, "Secondary", { Size = UDim2.fromOffset(110, 38), Parent = camRow })
	local watching = Components.label("", {
		Size = UDim2.fromOffset(300, 38),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = camRow,
	})
	Components.button("Next ▶", function()
		if not ctx.Camera.IsSpectating() then
			ctx.Camera.StartSpectating()
		end
		ctx.Camera.Cycle(1)
	end, "Secondary", { Size = UDim2.fromOffset(110, 38), Parent = camRow })

	local whisperRow = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4, Parent = root })
	local roomIds = {}
	for _, room in ShipLayout.Rooms do
		table.insert(roomIds, room.Id)
	end
	local chosenRoom = roomIds[1]
	local roomPicker = Components.cycle(roomIds, chosenRoom, function(value)
		chosenRoom = value
	end, function(value)
		return ShipLayout.areaName(value)
	end)
	roomPicker.Size = UDim2.new(0.6, -4, 1, 0)
	roomPicker.Parent = whisperRow
	local whisperButton = Components.button("Whisper", function()
		ctx.Fire(Net.Names.GhostWhisper, chosenRoom)
	end, "Primary", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, -4, 1, 0),
		Parent = whisperRow,
	})
	whisperButton.Name = "Whisper"

	ctx.Camera.SpectateChanged:Connect(function(name: string?)
		watching.Text = if name then "Watching " .. name else "No crew to watch"
	end)

	return {
		Root = root,
		Refresh = function()
			local life = ctx.Client.GetPrivate(Constants.PrivateKey.Life)
			local ghost = life == Constants.LifeState.Lost or life == Constants.LifeState.Confined
			if ghost then
				title.Text = if life == Constants.LifeState.Confined then "CONFINED · SIGNAL GHOST" else "SIGNAL GHOST"
				info.Text = "You can't be heard by the living, but you can chat with other ghosts and send static whispers."
			else
				title.Text = "MATCH IN PROGRESS"
				info.Text = "You'll board on the next departure. Watch the crew in the meantime."
			end
			whisperRow.Visible = ghost
			local name = ctx.Camera.GetTargetName()
			watching.Text = if name then "Watching " .. name else "Press Next to watch the crew"
		end,
	}
end
