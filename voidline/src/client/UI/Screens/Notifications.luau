--!strict
--[[
	Notifications (overlay)
	Toast stack (top centre) for server notifications, and a caption feed
	(bottom centre) for sound captions when Subtitles are on. Every toast
	carries a text prefix ([ALERT], [INFO]...) so it never relies on colour.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local PREFIX = { Info = "INFO", Warning = "WARNING", Alert = "ALERT", Success = "DONE" }
local MAX_TOASTS = 4
local MAX_CAPTIONS = 3

return function(ctx: any)
	local root = Create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})

	local toasts = Create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Components.list(6, false, Enum.HorizontalAlignment.Center).Parent = toasts

	local captions = Create("Frame", {
		Name = "Captions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(520, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Components.list(4, false, Enum.HorizontalAlignment.Center).Parent = captions

	local dataWarning = Components.chip("Progress can't be saved right now - your rewards this session are temporary.", Theme.status("Warning"))
	dataWarning.AnchorPoint = Vector2.new(0.5, 1)
	dataWarning.Position = UDim2.new(0.5, 0, 1, -8)
	dataWarning.Visible = false
	dataWarning.Parent = root

	local order = 0

	local function fadeOut(item: GuiObject, after: number)
		task.delay(after, function()
			if not item.Parent then
				return
			end
			local info = TweenInfo.new(0.35)
			for _, d in item:GetDescendants() do
				if d:IsA("TextLabel") then
					TweenService:Create(d, info, { TextTransparency = 1 }):Play()
				elseif d:IsA("UIStroke") then
					TweenService:Create(d, info, { Transparency = 1 }):Play()
				end
			end
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
			task.wait(0.4)
			item:Destroy()
		end)
	end

	local function trim(container: Instance, max: number)
		local items = {}
		for _, child in container:GetChildren() do
			if child:IsA("GuiObject") then
				table.insert(items, child)
			end
		end
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		while #items > max do
			local oldest = table.remove(items, 1)
			if oldest then
				oldest:Destroy()
			end
		end
	end

	local function toast(text: string, kind: string, duration: number?)
		order += 1
		local color = if kind == "Alert"
			then Theme.status("Danger")
			elseif kind == "Warning" then Theme.status("Warning")
			elseif kind == "Success" then Theme.status("Success")
			else Theme.Color.Accent
		local frame = Components.panel({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 0.12,
			Parent = toasts,
		})
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = color
			stroke.Transparency = 0.2
		end
		Components.padding(8, 14).Parent = frame
		Components.label(string.format("[%s]  %s", PREFIX[kind] or "INFO", text), {
			Font = Theme.Font.Medium,
			TextColor3 = Theme.Color.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = frame,
		})
		trim(toasts, MAX_TOASTS)
		fadeOut(frame, math.clamp(duration or 4, 1.5, 15))
	end

	local function caption(text: string)
		order += 1
		local label = Components.label(text, {
			LayoutOrder = order,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Font.Medium,
			Parent = captions,
		})
		Components.padding(3, 8).Parent = label
		trim(captions, MAX_CAPTIONS)
		fadeOut(label, 3)
	end

	ctx.Client.Notified:Connect(function(notification: any)
		toast(notification.Text, notification.Kind, notification.Duration)
		if ctx.Settings.Get("Subtitles") then
			-- Mirror important alerts into captions too (they usually come with a sound).
			if notification.Kind == "Alert" then
				caption("[Alarm] " .. notification.Text)
			end
		end
	end)
	ctx.Audio.Captioned:Connect(caption)
	ctx.Interaction.HoldReleasedEarly:Connect(function(action: string, duration: number)
		toast(string.format("Keep holding to %s (%.1fs).", string.lower(action), duration), "Info", 2)
	end)
	ctx.Minigame.Finished:Connect(function(success: boolean, reason: string?)
		if success then
			toast("Step complete.", "Success", 2)
		elseif reason then
			toast(reason, "Warning", 3)
		end
	end)

	return {
		Root = root,
		Refresh = function()
			dataWarning.Visible = ctx.Client.GetPrivate(Constants.PrivateKey.DataStatus) == "Temporary"
		end,
	}
end
