-- Toast notifications.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local T = Util.Theme

local Notify = {}
local container

local COLORS = {
	info = T.accent2,
	success = T.good,
	error = T.bad,
	levelup = T.gold,
}

function Notify.Init(gui)
	container = Util.frame(gui, {
		Name = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.new(0, 460, 0, 300),
		ZIndex = 20,
	})
	Util.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = container,
	})
end

local order = 0
function Notify.Show(text, kind)
	if not container then
		return
	end
	kind = kind or "info"
	order += 1
	local big = kind == "levelup"
	local toast = Util.frame(container, {
		Size = UDim2.new(1, 0, 0, big and 54 or 40),
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.1,
		LayoutOrder = order,
	})
	Util.corner(toast, 10)
	local stroke = Util.stroke(toast, COLORS[kind] or T.accent2, 2, 0.1)
	local label = Util.label(toast, text, {
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.new(0, 10, 0, 6),
		TextColor3 = big and T.gold or T.text,
		Font = big and Enum.Font.GothamBlack or Enum.Font.GothamBold,
	})
	Util.new("UITextSizeConstraint", { MaxTextSize = big and 26 or 18, Parent = label })

	if kind == "levelup" or kind == "success" then
		local sound = Instance.new("Sound")
		sound.SoundId = Config.Sounds.Checkpoint
		sound.PlaybackSpeed = big and 1.5 or 1.2
		sound.Volume = 0.5
		SoundService:PlayLocalSound(sound)
	end

	task.delay(big and 5 or 3.5, function()
		Util.tween(toast, 0.4, { BackgroundTransparency = 1 })
		Util.tween(label, 0.4, { TextTransparency = 1 })
		Util.tween(stroke, 0.4, { Transparency = 1 })
		task.wait(0.45)
		toast:Destroy()
	end)
end

return Notify
