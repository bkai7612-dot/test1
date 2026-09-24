-- Team races: queue for 1v1 up to 5v5 (same as the Team Arena pads).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.Parent.State)
local T = Util.Theme

local TeamPanel = {}

local frame
local rows = {}
local localUserId = Players.LocalPlayer.UserId

-- Size of the team queue the local player is in (from the lobby broadcast).
function TeamPanel.MyQueue()
	for _, q in State.race.teamQueues or {} do
		if table.find(q.members, localUserId) then
			return q.size
		end
	end
	return nil
end

function TeamPanel.Toggle(size)
	local ok, msg
	if TeamPanel.MyQueue() == size then
		ok, msg = State.Request("LeaveTeamQueue")
	else
		ok, msg = State.Request("JoinTeamQueue", size)
	end
	if msg then
		Notify.Show(msg, ok and "success" or "error")
	end
end

function TeamPanel.Init(gui, hud)
	local content
	frame, content = Util.panel(gui, "TEAM RACES", UDim2.fromOffset(620, 470), function()
		hud.ClosePanel("Teams")
	end)
	Util.label(content, "RED vs BLUE. Points by finishing place (25, 18, 15...). Winning team gets bonus coins and XP.", {
		Size = UDim2.new(1, 0, 0, 36),
		TextColor3 = T.sub,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
	})
	for i, size in Config.TeamSizes do
		local row = Util.frame(content, {
			Position = UDim2.new(0, 0, 0, 46 + (i - 1) * 64),
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = T.panel,
		})
		Util.corner(row, 10)
		Util.label(row, string.format("%dv%d", size, size), {
			Position = UDim2.new(0, 14, 0, 8),
			Size = UDim2.new(0, 90, 0, 40),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local count = Util.label(row, "", {
			Position = UDim2.new(0, 110, 0, 14),
			Size = UDim2.new(0.4, 0, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.gold,
		})
		local button = Util.button(row, "JOIN", T.good, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 150, 0, 40),
		}, function()
			TeamPanel.Toggle(size)
		end)
		rows[size] = { count = count, button = button }
	end
	Util.label(content, "Tip: you can free drive while you wait. You'll be pulled into the match when it's ready.", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = T.sub,
		Font = Enum.Font.Gotham,
	})
	State.On("Race", function()
		if frame.Visible then
			TeamPanel.Refresh()
		end
	end)
end

function TeamPanel.Refresh()
	local mine = TeamPanel.MyQueue()
	for _, q in State.race.teamQueues or {} do
		local row = rows[q.size]
		if row then
			row.count.Text = string.format("%d / %d players queued", q.count, q.needed)
			row.button.Text = mine == q.size and "LEAVE QUEUE" or "JOIN"
			row.button.BackgroundColor3 = mine == q.size and T.bad or T.good
		end
	end
end

function TeamPanel.Open()
	frame.Visible = true
	TeamPanel.Refresh()
end

function TeamPanel.Close()
	frame.Visible = false
end

return TeamPanel
