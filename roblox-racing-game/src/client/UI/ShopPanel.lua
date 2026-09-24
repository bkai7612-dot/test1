-- Robux shop: coin packs, game passes and upgrade boosts.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared.Products)
local Util = require(script.Parent.Util)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.Parent.State)
local T = Util.Theme

local ShopPanel = {}

local frame
local passButtons = {}

local function priceText(info)
	return info.id ~= 0 and ("R$ " .. info.robux) or "SOON"
end

-- Replace display prices with live ones once ids are configured.
local function fetchPrice(info, infoType, button)
	if info.id == 0 then
		return
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return MarketplaceService:GetProductInfo(info.id, infoType)
		end)
		if ok and result and result.PriceInRobux then
			info.robux = result.PriceInRobux
			if button.Parent and button.Text ~= "OWNED" then
				button.Text = "R$ " .. result.PriceInRobux
			end
		end
	end)
end

local function prompt(action, key)
	local ok, msg = State.Request(action, key)
	if not ok and msg then
		Notify.Show(msg, "error")
	end
end

local function sectionTitle(parent, text, order)
	Util.label(parent, text, {
		Size = UDim2.new(1, -10, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		TextColor3 = T.accent,
		LayoutOrder = order,
	})
end

local function card(parent, title, subtitle, color, order)
	local c = Util.frame(parent, {
		BackgroundColor3 = T.panel,
		LayoutOrder = order,
	})
	Util.corner(c, 12)
	Util.stroke(c, color, 2, 0.4)
	Util.label(c, title, {
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -20, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextColor3 = color,
	})
	local sub = Util.label(c, subtitle, {
		Position = UDim2.new(0, 10, 0, 40),
		Size = UDim2.new(1, -20, 0, 54),
		TextColor3 = T.sub,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
	})
	Util.new("UITextSizeConstraint", { MaxTextSize = 15, Parent = sub })
	return c
end

function ShopPanel.Init(gui, hud)
	local content
	frame, content = Util.panel(gui, "ROBUX SHOP", UDim2.fromOffset(860, 540), function()
		hud.ClosePanel("Shop")
	end)

	local scroller = Util.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = content,
	})
	Util.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroller })

	local function grid(order, cellHeight)
		local g = Util.frame(scroller, {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
		})
		Util.new("UIGridLayout", {
			CellSize = UDim2.new(0.25, -8, 0, cellHeight),
			CellPadding = UDim2.new(0, 8, 0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = g,
		})
		return g
	end

	-- Coin packs
	sectionTitle(scroller, "COIN PACKS", 1)
	local coinGrid = grid(2, 150)
	local packs = {}
	for key, info in Products.Developer do
		if info.coins then
			table.insert(packs, { key = key, info = info })
		end
	end
	table.sort(packs, function(a, b)
		return a.info.order < b.info.order
	end)
	for i, pack in packs do
		local c = card(coinGrid, Util.formatNumber(pack.info.coins) .. " COINS", pack.info.name, T.gold, i)
		local button = Util.button(c, priceText(pack.info), T.robux, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 38),
		}, function()
			prompt("PromptProduct", pack.key)
		end)
		fetchPrice(pack.info, Enum.InfoType.Product, button)
	end

	-- Game passes
	sectionTitle(scroller, "GAME PASSES", 3)
	local passGrid = grid(4, 170)
	local order = 0
	for key, info in Products.Passes do
		order += 1
		local c = card(passGrid, string.upper(info.name), info.description, T.accent2, order)
		local button = Util.button(c, priceText(info), T.robux, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 38),
		}, function()
			prompt("PromptPass", key)
		end)
		passButtons[key] = button
		fetchPrice(info, Enum.InfoType.GamePass, button)
	end

	-- Boosts (bought from the Upgrades / Garage panels)
	sectionTitle(scroller, "PERFORMANCE BOOSTS", 5)
	local boostGrid = grid(6, 150)
	local boosts = {
		{ Products.Developer.MaxUpgrade, "Max one upgrade stat instantly. Buy it from the R$ MAX buttons in UPGRADES." },
		{ Products.Developer.MaxAllUpgrades, "Max every stat on your selected car. Buy it at the bottom of UPGRADES." },
		{ Products.Developer.Car_Hyper, "Skip the grind: unlock cars with Robux right from the GARAGE." },
	}
	for i, boost in boosts do
		local c = card(boostGrid, string.upper(boost[1].name), boost[2], T.accent, i)
		local openButton = Util.button(c, "OPEN", T.panel2, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 34),
		}, function()
			hud.OpenPanel(i == 3 and "Garage" or "Upgrades")
		end)
		openButton.Name = "Open"
	end

	State.On("Data", function()
		ShopPanel.Refresh()
	end)
end

function ShopPanel.Refresh()
	local data = State.data
	if not data then
		return
	end
	for key, button in passButtons do
		if data.passes and data.passes[key] then
			button.Text = "OWNED"
			button.BackgroundColor3 = T.good
		end
	end
end

function ShopPanel.Open()
	frame.Visible = true
	ShopPanel.Refresh()
end

function ShopPanel.Close()
	frame.Visible = false
end

return ShopPanel
