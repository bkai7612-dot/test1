-- Coin purchases (cars, upgrades), customisation, codes and every Robux
-- transaction (developer products + game passes).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local Upgrades = require(Shared.Upgrades)
local Customization = require(Shared.Customization)
local Products = require(Shared.Products)

local DataService = require(script.Parent.DataService)

local ShopService = {}
ShopService.Handlers = {}

local pendingUpgrade = {} -- [player] = { carId, stat } context for MaxUpgrade products

local function notify(player, text, kind)
	DataService.Notify(player, text, kind)
end

local function ownCar(player, data, carId)
	data.owned[carId] = true
	data.selectedCar = carId
	DataService.EnsureCar(data, carId)
end

---------------------------------------------------------------------------
-- Coin actions
---------------------------------------------------------------------------

function ShopService.Handlers.BuyCar(player, carId)
	local data = DataService.Get(player)
	local car = type(carId) == "string" and Cars.List[carId]
	if not data or not car then
		return false, "Unknown car."
	end
	if data.owned[carId] then
		return false, "You already own this car."
	end
	if data.level < car.level then
		return false, string.format("Reach level %d to unlock the %s.", car.level, car.name)
	end
	if not DataService.SpendCoins(player, car.price) then
		return false, "Not enough coins."
	end
	ownCar(player, data, carId)
	DataService.Push(player)
	notify(player, "You bought the " .. car.name .. "!", "success")
	return true
end

function ShopService.Handlers.SelectCar(player, carId)
	local data = DataService.Get(player)
	if not data or type(carId) ~= "string" or not data.owned[carId] then
		return false, "You don't own that car."
	end
	data.selectedCar = carId
	DataService.EnsureCar(data, carId)
	DataService.Push(player)
	return true
end

function ShopService.Handlers.Upgrade(player, carId, stat)
	local data = DataService.Get(player)
	if not data or type(carId) ~= "string" or not data.owned[carId] or not Upgrades.Info[stat] then
		return false, "Invalid upgrade."
	end
	DataService.EnsureCar(data, carId)
	local level = data.upgrades[carId][stat]
	local cost = Upgrades.Cost(carId, stat, level)
	if not cost then
		return false, "Already maxed out."
	end
	if not DataService.SpendCoins(player, cost) then
		return false, "Not enough coins."
	end
	data.upgrades[carId][stat] = level + 1
	DataService.Push(player)
	return true
end

function ShopService.Handlers.Customize(player, carId, category, optionId)
	local data = DataService.Get(player)
	if not data or type(carId) ~= "string" or not data.owned[carId] then
		return false, "You don't own that car."
	end
	if type(category) ~= "string" or type(optionId) ~= "string" then
		return false, "Invalid option."
	end
	local option = Customization.Find(category, optionId)
	if not option then
		return false, "Invalid option."
	end
	local ok, reason = Customization.CanUse(option, data.level, DataService.HasPass(player, "VIP"))
	if not ok then
		return false, reason
	end
	DataService.EnsureCar(data, carId)
	data.custom[carId][category] = optionId
	DataService.Push(player)
	return true
end

function ShopService.Handlers.RedeemCode(player, code)
	local data = DataService.Get(player)
	if not data or type(code) ~= "string" then
		return false, "Invalid code."
	end
	code = string.upper((string.gsub(code, "%s", "")))
	local reward = Config.Codes[code]
	if not reward then
		return false, "That code doesn't exist."
	end
	if data.codes[code] then
		return false, "You already redeemed this code."
	end
	data.codes[code] = true
	if reward.coins then
		DataService.AddCoins(player, reward.coins)
	end
	if reward.xp then
		DataService.AddXP(player, reward.xp)
	end
	DataService.Push(player)
	notify(player, reward.message or "Code redeemed!", "success")
	return true
end

---------------------------------------------------------------------------
-- Robux
---------------------------------------------------------------------------

function ShopService.Handlers.PromptProduct(player, key, carId, stat)
	local info = type(key) == "string" and Products.Developer[key]
	if not info then
		return false, "Unknown product."
	end
	if info.id == 0 then
		return false, "This item isn't set up yet (developer product id missing)."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data not loaded."
	end
	if info.car and data.owned[info.car] then
		return false, "You already own this car."
	end
	if key == "MaxUpgrade" or key == "MaxAllUpgrades" then
		if type(carId) ~= "string" or not data.owned[carId] then
			return false, "Select a car you own first."
		end
		if key == "MaxUpgrade" and not Upgrades.Info[stat] then
			return false, "Invalid upgrade."
		end
		pendingUpgrade[player] = { carId = carId, stat = stat }
	end
	MarketplaceService:PromptProductPurchase(player, info.id)
	return true
end

function ShopService.Handlers.PromptPass(player, key)
	local info = type(key) == "string" and Products.Passes[key]
	if not info then
		return false, "Unknown game pass."
	end
	if info.id == 0 then
		return false, "This pass isn't set up yet (game pass id missing)."
	end
	if DataService.HasPass(player, key) then
		return false, "You already own this pass."
	end
	MarketplaceService:PromptGamePassPurchase(player, info.id)
	return true
end

local function grantProduct(player, key, info)
	local data = DataService.Get(player)
	if info.coins then
		DataService.AddCoins(player, info.coins)
		notify(player, string.format("Purchase complete: +%d coins!", info.coins), "success")
	elseif info.car then
		ownCar(player, data, info.car)
		notify(player, Cars.List[info.car].name .. " unlocked!", "success")
	elseif key == "MaxUpgrade" or key == "MaxAllUpgrades" then
		local ctx = pendingUpgrade[player] or {}
		local carId = (ctx.carId and data.owned[ctx.carId]) and ctx.carId or data.selectedCar
		DataService.EnsureCar(data, carId)
		local upg = data.upgrades[carId]
		if key == "MaxAllUpgrades" then
			for _, stat in Upgrades.Order do
				upg[stat] = Upgrades.MAX_LEVEL
			end
			notify(player, Cars.List[carId].name .. " is now fully tuned!", "success")
		else
			local stat = ctx.stat
			if not Upgrades.Info[stat] or upg[stat] >= Upgrades.MAX_LEVEL then
				-- Fall back to the lowest stat so the purchase is never wasted.
				stat = Upgrades.Order[1]
				for _, s in Upgrades.Order do
					if upg[s] < upg[stat] then
						stat = s
					end
				end
			end
			upg[stat] = Upgrades.MAX_LEVEL
			notify(player, string.format("%s maxed out on the %s!", Upgrades.Info[stat].name, Cars.List[carId].name), "success")
		end
		pendingUpgrade[player] = nil
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.WaitFor(player, 10)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if DataService.HasReceipt(player, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key, info = Products.FindDeveloperById(receipt.ProductId)
	if not key then
		warn("[ShopService] Unknown product id", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(grantProduct, player, key, info)
	if not ok then
		warn("[ShopService] Grant failed:", err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.AddReceipt(player, receipt.PurchaseId)
	DataService.Push(player)
	-- The receipt is recorded in memory, so a retry in this session can't
	-- double-grant even if this save fails.
	if not DataService.Save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function refreshPasses(player)
	for key, info in Products.Passes do
		local owned = false
		if Config.STUDIO_GRANTS_PASSES and RunService:IsStudio() then
			owned = true
		elseif info.id ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.id)
			end)
			owned = ok and result
		end
		DataService.SetPass(player, key, owned)
	end
end

function ShopService.Init()
	MarketplaceService.ProcessReceipt = processReceipt

	DataService.OnLoaded(function(player)
		refreshPasses(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key, info = Products.FindPassById(passId)
		if key then
			DataService.SetPass(player, key, true)
			notify(player, "Thanks for buying " .. info.name .. "! Perks are active now.", "success")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingUpgrade[player] = nil
	end)
end

return ShopService
