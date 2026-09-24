-- Customise: paint, accent, rims, underglow and finish with a live preview.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cars = require(Shared.Cars)
local Customization = require(Shared.Customization)
local Util = require(script.Parent.Util)
local Viewport = require(script.Parent.Viewport)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.Parent.State)
local T = Util.Theme

local CustomizePanel = {}

local frame, viewport, carLabel
local swatches = {} -- [category] = { [optionId] = { button, stroke, lock, option, price } }
local pendingBuy = {} -- [category .. id] = click time (buy confirmation)

function CustomizePanel.Init(gui, hud)
	local content
	frame, content = Util.panel(gui, "CUSTOMIZE", UDim2.fromOffset(900, 540), function()
		hud.ClosePanel("Customize")
	end)

	viewport = Viewport.new(content, { Size = UDim2.new(0.42, 0, 0.88, 0) })
	carLabel = Util.label(content, "", {
		Position = UDim2.new(0, 0, 0.9, 0),
		Size = UDim2.new(0.42, 0, 0.08, 0),
		Font = Enum.Font.GothamBlack,
		TextColor3 = T.accent,
	})

	local scroller = Util.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.44, 0, 0, 0),
		Size = UDim2.new(0.56, 0, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = content,
	})
	Util.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroller })

	for i, category in Customization.Categories do
		Util.label(scroller, Customization.CategoryNames[category], {
			Size = UDim2.new(1, -10, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBlack,
			LayoutOrder = i * 2 - 1,
		})
		local grid = Util.frame(scroller, {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i * 2,
		})
		local isItem = Customization.ItemCategories[category] == true
		local isText = category == "finish" or category == "glow" or isItem
		Util.new("UIGridLayout", {
			CellSize = isItem and UDim2.new(0, 110, 0, 50) or isText and UDim2.new(0, 110, 0, 38) or UDim2.new(0, 46, 0, 46),
			CellPadding = UDim2.new(0, 6, 0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = grid,
		})
		swatches[category] = {}
		for j, option in Customization.Options[category] do
			local button = Util.new("TextButton", {
				AutoButtonColor = false,
				BackgroundColor3 = option.color or T.panel2,
				Text = isText and string.upper(option.id) or "",
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeTransparency = 0.5,
				Font = Enum.Font.GothamBlack,
				TextScaled = true,
				LayoutOrder = j,
				Parent = grid,
			})
			if isItem then
				button.BackgroundColor3 = option.color and option.color:Lerp(Color3.new(0, 0, 0), 0.45) or T.panel2
				button.TextYAlignment = Enum.TextYAlignment.Top
			end
			if category == "glow" and option.id ~= "None" then
				button.BackgroundColor3 = option.color:Lerp(Color3.new(0, 0, 0), 0.3)
			end
			if option.id == "Rainbow" then
				Util.new("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
						ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
						ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 120, 255)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 200)),
					}),
					Parent = button,
				})
			end
			Util.corner(button, 8)
			Util.padding(button, 4)
			local stroke = Util.stroke(button, Color3.new(1, 1, 1), 3, 1)
			local lockText = option.vip and "VIP" or (option.level and ("LV" .. option.level)) or ""
			local lock = Util.label(button, lockText, {
				BackgroundTransparency = 0.35,
				BackgroundColor3 = Color3.new(0, 0, 0),
				TextColor3 = option.vip and T.gold or T.text,
				Visible = false,
				ZIndex = 3,
			})
			local price
			if option.price then
				price = Util.label(button, "$" .. Util.formatNumber(option.price), {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, 1),
					Size = UDim2.fromScale(1, 0.42),
					TextColor3 = T.gold,
					ZIndex = 2,
				})
			end
			button.Activated:Connect(function()
				local data = State.data
				if not data then
					return
				end
				local ok, reason = Customization.CanUse(option, data.level, (data.passes and data.passes.VIP) or data.admin)
				if not ok then
					Notify.Show(option.id .. ": " .. reason, "error")
					return
				end
				if not Customization.Owns(data, category, option) then
					-- First click previews the item; a second click within 4s buys it.
					local key = category .. option.id
					if pendingBuy[key] and os.clock() - pendingBuy[key] < 4 then
						pendingBuy[key] = nil
						local bought, msg = State.Request("BuyItem", category, option.id)
						if not bought and msg then
							Notify.Show(msg, "error")
						end
					else
						table.clear(pendingBuy)
						pendingBuy[key] = os.clock()
						local preview = table.clone(data.custom[data.selectedCar] or Customization.Default(data.selectedCar))
						preview[category] = option.id
						viewport:SetCustom(preview)
						Notify.Show(
							string.format("Previewing %s. Click again to buy for %s coins.", option.id, Util.formatNumber(option.price)),
							"info"
						)
					end
					return
				end
				local success, msg = State.Request("Customize", data.selectedCar, category, option.id)
				if not success and msg then
					Notify.Show(msg, "error")
				end
			end)
			swatches[category][option.id] = { button = button, stroke = stroke, lock = lock, option = option, price = price }
		end
	end

	State.On("Data", function()
		if frame.Visible then
			CustomizePanel.Refresh()
		end
	end)
end

function CustomizePanel.Refresh()
	local data = State.data
	if not data then
		return
	end
	local carId = data.selectedCar
	local custom = data.custom[carId] or Customization.Default(carId)
	viewport:SetCar(carId, custom)
	carLabel.Text = string.upper(Cars.List[carId].name)
	local isVip = (data.passes and data.passes.VIP) or data.admin
	for category, entries in swatches do
		for optionId, entry in entries do
			entry.stroke.Transparency = custom[category] == optionId and 0 or 1
			entry.lock.Visible = not Customization.CanUse(entry.option, data.level, isVip)
			if entry.price then
				entry.price.Visible = not Customization.Owns(data, category, entry.option)
			end
		end
	end
end

function CustomizePanel.Open()
	frame.Visible = true
	CustomizePanel.Refresh()
end

function CustomizePanel.Close()
	frame.Visible = false
end

return CustomizePanel
