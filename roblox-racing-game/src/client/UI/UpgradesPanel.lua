-- Upgrades: spend coins (or Robux) on the selected car's performance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cars = require(Shared.Cars)
local Upgrades = require(Shared.Upgrades)
local Products = require(Shared.Products)
local Util = require(script.Parent.Util)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.Parent.State)
local T = Util.Theme

local UpgradesPanel = {}

local frame, titleLabel, maxAllButton
local rows = {}

local function request(...)
	local ok, msg = State.Request(...)
	if not ok and msg then
		Notify.Show(msg, "error")
	end
	return ok
end

function UpgradesPanel.Init(gui, hud)
	local content
	frame, content = Util.panel(gui, "UPGRADES", UDim2.fromOffset(760, 500), function()
		hud.ClosePanel("Upgrades")
	end)

	titleLabel = Util.label(content, "", {
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		TextColor3 = T.accent,
	})

	for i, stat in Upgrades.Order do
		local info = Upgrades.Info[stat]
		local row = Util.frame(content, {
			Position = UDim2.new(0, 0, 0, 36 + (i - 1) * 64),
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = T.panel,
		})
		Util.corner(row, 10)
		local icon = Util.frame(row, {
			Position = UDim2.new(0, 8, 0, 8),
			Size = UDim2.new(0, 40, 0, 40),
			BackgroundColor3 = T.panel2,
		})
		Util.corner(icon, 8)
		Util.label(icon, info.short, { Size = UDim2.new(1, -6, 1, -12), Position = UDim2.new(0, 3, 0, 6), TextColor3 = T.accent2 })
		Util.label(row, info.name, {
			Position = UDim2.new(0, 58, 0, 6),
			Size = UDim2.new(0.3, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBlack,
		})
		Util.label(row, info.description, {
			Position = UDim2.new(0, 58, 0, 30),
			Size = UDim2.new(0.34, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.sub,
			Font = Enum.Font.Gotham,
		})
		local pips = {}
		for p = 1, Upgrades.MAX_LEVEL do
			local pip = Util.frame(row, {
				Position = UDim2.new(0.43, (p - 1) * 22, 0.5, -9),
				Size = UDim2.new(0, 18, 0, 18),
				BackgroundColor3 = T.panel2,
			})
			Util.corner(pip, 4)
			pips[p] = pip
		end
		local buy = Util.button(row, "", T.accent, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -86, 0.5, 0),
			Size = UDim2.new(0, 170, 0, 40),
		}, function()
			local carId = State.data and State.data.selectedCar
			if carId then
				request("Upgrade", carId, stat)
			end
		end)
		local robux = Util.button(row, "R$ MAX", T.robux, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0, 72, 0, 40),
		}, function()
			local carId = State.data and State.data.selectedCar
			if carId then
				request("PromptProduct", "MaxUpgrade", carId, stat)
			end
		end)
		rows[stat] = { pips = pips, buy = buy, robux = robux }
	end

	maxAllButton = Util.button(content, "", T.robux, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0.6, 0, 0, 44),
	}, function()
		local carId = State.data and State.data.selectedCar
		if carId then
			request("PromptProduct", "MaxAllUpgrades", carId)
		end
	end)

	State.On("Data", function()
		if frame.Visible then
			UpgradesPanel.Refresh()
		end
	end)
end

function UpgradesPanel.Refresh()
	local data = State.data
	if not data then
		return
	end
	local carId = data.selectedCar
	local car = Cars.List[carId]
	local upg = data.upgrades[carId] or Upgrades.Default()
	titleLabel.Text = "TUNING: " .. string.upper(car.name) .. "   (change car in the Garage)"
	local allMax = true
	for stat, row in rows do
		local level = upg[stat] or 0
		for p, pip in row.pips do
			pip.BackgroundColor3 = p <= level and T.accent or T.panel2
		end
		local cost = Upgrades.Cost(carId, stat, level)
		if cost then
			allMax = false
			row.buy.Text = "UPGRADE • " .. Util.formatNumber(cost)
			row.buy.BackgroundColor3 = data.coins >= cost and T.accent or T.locked
			row.robux.Visible = true
		else
			row.buy.Text = "MAXED"
			row.buy.BackgroundColor3 = T.good
			row.robux.Visible = false
		end
	end
	local product = Products.Developer.MaxAllUpgrades
	maxAllButton.Visible = not allMax
	maxAllButton.Text = product.id ~= 0 and ("FULLY TUNE THIS CAR • R$ " .. product.robux) or "FULLY TUNE (R$) • COMING SOON"
end

function UpgradesPanel.Open()
	frame.Visible = true
	UpgradesPanel.Refresh()
end

function UpgradesPanel.Close()
	frame.Visible = false
end

return UpgradesPanel
