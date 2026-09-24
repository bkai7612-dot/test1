-- Free drive: pick any circuit and cruise it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maps = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Maps"))
local Util = require(script.Parent.Util)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.Parent.State)
local T = Util.Theme

local FreeDrivePanel = {}

local frame
local counts = {}
local busy = false

function FreeDrivePanel.Init(gui, hud)
	local content
	frame, content = Util.panel(gui, "FREE DRIVE", UDim2.fromOffset(720, 470), function()
		hud.ClosePanel("FreeDrive")
	end)
	Util.label(content, "No timer, no opponents. Lap times are shown each time you cross the line. Press F / EXIT to leave.", {
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = T.sub,
		Font = Enum.Font.Gotham,
	})
	local grid = Util.frame(content, {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 1, -32),
	})
	Util.new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -8, 0, 150),
		CellPadding = UDim2.new(0, 8, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for i, mapId in Maps.Order do
		local map = Maps.List[mapId]
		local card = Util.new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = T.panel,
			LayoutOrder = i,
			Parent = grid,
		})
		Util.corner(card, 12)
		Util.stroke(card, map.cardColor, 2, 0.3)
		Util.label(card, map.name, {
			Position = UDim2.new(0, 8, 0, 10),
			Size = UDim2.new(1, -16, 0, 40),
			Font = Enum.Font.GothamBlack,
			TextWrapped = true,
			TextColor3 = map.cardColor,
		})
		Util.label(card, map.difficulty, {
			Position = UDim2.new(0, 8, 0, 56),
			Size = UDim2.new(1, -16, 0, 20),
			TextColor3 = T.sub,
		})
		counts[mapId] = Util.label(card, "", {
			Position = UDim2.new(0, 8, 0, 80),
			Size = UDim2.new(1, -16, 0, 18),
			TextColor3 = T.good,
			Font = Enum.Font.Gotham,
		})
		local function onDrive()
			if busy then
				return
			end
			busy = true
			hud.CloseAll()
			Notify.Show("Loading " .. map.name .. "...", "info")
			local ok, msg = State.Request("FreeDrive", mapId)
			busy = false
			if msg then
				Notify.Show(msg, ok and "success" or "error")
			end
		end
		Util.button(card, "DRIVE", T.good, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 34),
		}, onDrive)
		card.Activated:Connect(onDrive)
	end
	State.On("Race", function()
		if frame.Visible then
			FreeDrivePanel.Refresh()
		end
	end)
end

function FreeDrivePanel.Refresh()
	local live = State.race.freeDrive or {}
	for mapId, label in counts do
		local n = live[mapId] or 0
		label.Text = n > 0 and string.format("%d driving now", n) or ""
	end
end

function FreeDrivePanel.Open()
	frame.Visible = true
	FreeDrivePanel.Refresh()
end

function FreeDrivePanel.Close()
	frame.Visible = false
end

return FreeDrivePanel
