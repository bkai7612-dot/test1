-- Garage: browse the five cars, buy with coins or Robux, select a car.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cars = require(Shared.Cars)
local Upgrades = require(Shared.Upgrades)
local Products = require(Shared.Products)
local Util = require(script.Parent.Util)
local Viewport = require(script.Parent.Viewport)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.Parent.State)
local T = Util.Theme

local Garage = {}

local frame, viewport
local viewing = "Hatch"
local listButtons = {}
local nameLabel, classLabel, descLabel, careerLabel
local statRows = {}
local actionButton, robuxButton

local STATS = {
	{ key = "topSpeed", name = "Top Speed" },
	{ key = "accel", name = "Acceleration" },
	{ key = "handling", name = "Handling" },
	{ key = "grip", name = "Grip" },
	{ key = "nitro", name = "Nitro" },
}

local function onAction()
	local data = State.data
	local car = Cars.List[viewing]
	if not data or not car then
		return
	end
	local ok, msg
	if data.owned[viewing] then
		ok, msg = State.Request("SelectCar", viewing)
		if ok then
			Notify.Show(car.name .. " selected!", "success")
		end
	else
		ok, msg = State.Request("BuyCar", viewing)
	end
	if not ok and msg then
		Notify.Show(msg, "error")
	end
end

local function onRobux()
	local ok, msg = State.Request("PromptProduct", "Car_" .. viewing)
	if not ok and msg then
		Notify.Show(msg, "error")
	end
end

function Garage.Init(gui, hud)
	local content
	frame, content = Util.panel(gui, "GARAGE", UDim2.fromOffset(860, 520), function()
		hud.ClosePanel("Garage")
	end)

	local list = Util.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0.3, 0, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = content,
	})
	Util.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	for i, carId in Cars.Order do
		local car = Cars.List[carId]
		local button = Util.new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = T.panel,
			Size = UDim2.new(1, -10, 0, 70),
			LayoutOrder = i,
			Parent = list,
		})
		Util.corner(button, 10)
		local stroke = Util.stroke(button, T.accent, 2, 1)
		Util.label(button, car.name, {
			Position = UDim2.new(0, 12, 0, 8),
			Size = UDim2.new(1, -24, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBlack,
		})
		local sub = Util.label(button, "", {
			Position = UDim2.new(0, 12, 0, 38),
			Size = UDim2.new(1, -24, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.sub,
		})
		button.Activated:Connect(function()
			Garage.View(carId)
		end)
		listButtons[carId] = { button = button, sub = sub, stroke = stroke }
	end

	local right = Util.frame(content, {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.32, 0, 0, 0),
		Size = UDim2.new(0.68, 0, 1, 0),
	})
	viewport = Viewport.new(right, { Size = UDim2.new(1, 0, 0.46, 0) })

	nameLabel = Util.label(right, "", {
		Position = UDim2.new(0, 0, 0.48, 0),
		Size = UDim2.new(0.6, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
	})
	classLabel = Util.label(right, "", {
		Position = UDim2.new(0.6, 0, 0.48, 4),
		Size = UDim2.new(0.4, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = T.accent,
	})
	descLabel = Util.label(right, "", {
		Position = UDim2.new(0, 0, 0.48, 34),
		Size = UDim2.new(1, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = T.sub,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
	})
	Util.new("UITextSizeConstraint", { MaxTextSize = 16, Parent = descLabel })

	local statsFrame = Util.frame(right, {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0.48, 76),
		Size = UDim2.new(1, 0, 0, #STATS * 20),
	})
	for i, stat in STATS do
		local y = (i - 1) * 20
		Util.label(statsFrame, stat.name, {
			Position = UDim2.new(0, 0, 0, y),
			Size = UDim2.new(0.25, 0, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.sub,
		})
		local _, fill = Util.bar(statsFrame, {
			Position = UDim2.new(0.27, 0, 0, y + 2),
			Size = UDim2.new(0.73, 0, 0, 12),
		})
		statRows[stat.key] = fill
	end

	actionButton = Util.button(right, "SELECT", T.accent, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.58, 0, 0, 48),
	}, onAction)
	robuxButton = Util.button(right, "R$", T.robux, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.4, 0, 0, 48),
	}, onRobux)
	careerLabel = Util.label(right, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -54),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.sub,
		Font = Enum.Font.Gotham,
	})

	State.On("Data", function()
		if frame.Visible then
			Garage.Refresh()
		end
	end)
end

function Garage.View(carId)
	viewing = carId
	Garage.Refresh()
end

function Garage.Refresh()
	local data = State.data
	if not data then
		return
	end
	for carId, entry in listButtons do
		local car = Cars.List[carId]
		local owned = data.owned[carId]
		if carId == data.selectedCar then
			entry.sub.Text = "SELECTED"
			entry.sub.TextColor3 = T.good
		elseif owned then
			entry.sub.Text = "Owned"
			entry.sub.TextColor3 = T.accent2
		elseif data.level < car.level then
			entry.sub.Text = string.format("Locked • Level %d", car.level)
			entry.sub.TextColor3 = T.bad
		else
			entry.sub.Text = Util.formatNumber(car.price) .. " coins"
			entry.sub.TextColor3 = T.gold
		end
		entry.stroke.Transparency = carId == viewing and 0 or 1
		entry.button.BackgroundColor3 = carId == viewing and T.panel2 or T.panel
	end

	local car = Cars.List[viewing]
	local owned = data.owned[viewing]
	viewport:SetCar(viewing, data.custom[viewing])
	nameLabel.Text = car.name
	classLabel.Text = car.class
	descLabel.Text = car.description .. "  (Inspired by: " .. car.inspiration .. ")"

	local stats = Upgrades.GetStats(viewing, owned and data.upgrades[viewing] or nil)
	for key, fill in statRows do
		local frac = math.clamp(stats[key] / Cars.StatMax[key], 0.03, 1)
		Util.tween(fill, 0.3, { Size = UDim2.fromScale(frac, 1) })
	end

	if viewing == data.selectedCar then
		actionButton.Text = "SELECTED"
		actionButton.BackgroundColor3 = T.good
	elseif owned then
		actionButton.Text = "SELECT"
		actionButton.BackgroundColor3 = T.accent
	elseif data.level < car.level then
		actionButton.Text = string.format("REACH LEVEL %d", car.level)
		actionButton.BackgroundColor3 = T.locked
	else
		actionButton.Text = "BUY • " .. Util.formatNumber(car.price) .. " COINS"
		actionButton.BackgroundColor3 = data.coins >= car.price and T.accent or T.locked
	end

	local product = Products.Developer["Car_" .. viewing]
	robuxButton.Visible = product ~= nil and not owned
	if product then
		robuxButton.Text = product.id ~= 0 and ("UNLOCK • R$ " .. product.robux) or "R$ • SOON"
	end

	local s = data.stats
	careerLabel.Text = string.format("Career: %d races  •  %d wins  •  %d podiums", s.races, s.wins, s.podiums)
end

function Garage.Open(carId)
	viewing = carId or (State.data and State.data.selectedCar) or "Hatch"
	frame.Visible = true
	Garage.Refresh()
end

function Garage.Close()
	frame.Visible = false
end

return Garage
