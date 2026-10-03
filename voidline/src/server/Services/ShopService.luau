--!strict
--[[
	ShopService
	Cosmetic purchases and equipment. Everything sold is cosmetic: nothing
	here changes roles, abilities, speed or any gameplay value.

	  PurchaseItem  - buy a cosmetic with Credits (server checks price, level,
	                  ownership and balance; the client never sets values)
	  EquipItem     - equip an unlocked cosmetic
	  Robux         - Developer Product credit packs and a Supporter game pass
	                  (cosmetic nameplate). Receipts are idempotent: a receipt
	                  is only acknowledged after the profile holding it saved.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CosmeticCatalog = require(Shared.Data.CosmeticCatalog)
local Net = require(Shared.Net)
local Logger = require(Shared.Utility.Logger)
local Validate = require(Shared.Utility.Validate)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local RemoteService = require(script.Parent.RemoteService)

local log = Logger.new("ShopService")

local ShopService = {}

local itemIds = {}
for _, item in CosmeticCatalog.Items do
	table.insert(itemIds, item.Id)
end

function ShopService.Purchase(player: Player, itemId: string): (boolean, string)
	local item = CosmeticCatalog.get(itemId)
	if not item then
		return false, "Unknown item."
	end
	if item.Source ~= "Credits" or not item.Price then
		return false, "This item can't be bought with credits."
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "Your profile is still loading."
	end
	if profile.Owned[item.Id] then
		return false, "You already own this."
	end
	if profile.Credits < item.Price then
		return false, "Not enough credits."
	end
	DataService.Update(player, function(p)
		-- Re-check inside the mutation in case of concurrent calls.
		if p.Owned[item.Id] or p.Credits < (item.Price :: number) then
			return
		end
		p.Credits -= item.Price :: number
		p.Owned[item.Id] = true
	end)
	AnalyticsService.Track("CosmeticPurchased", item.Price, { item = item.Id }, player)
	return true, "Purchased " .. item.Name .. "!"
end

function ShopService.Equip(player: Player, slot: string, itemId: string): boolean
	local item = CosmeticCatalog.get(itemId)
	local profile = DataService.GetProfile(player)
	if not item or not profile or item.Slot ~= slot then
		return false
	end
	if not table.find(CosmeticCatalog.EquipSlots, slot) then
		return false
	end
	if not CosmeticCatalog.isUnlocked(item, profile.Owned, profile.Level) then
		return false
	end
	DataService.Update(player, function(p)
		p.Equipped[slot] = item.Id
	end)
	CosmeticService.Apply(player)
	return true
end

---------------------------------------------------------------------------
-- Robux (cosmetic only)
---------------------------------------------------------------------------

local function creditPackFor(productId: number): number?
	for _, pack in Config.Monetization.CreditPacks do
		if pack.ProductId ~= 0 and pack.ProductId == productId then
			return pack.Credits
		end
	end
	return nil
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.GetProfile(player)
	if not profile or DataService.IsTemporary(player) then
		-- Can't persist the grant right now; Roblox will retry later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(profile.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local credits = creditPackFor(receipt.ProductId)
	if not credits then
		log:Warn("Unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.Update(player, function(p)
		p.Credits += credits
		table.insert(p.Receipts, purchaseId)
		while #p.Receipts > Config.Data.ReceiptHistory do
			table.remove(p.Receipts, 1)
		end
	end)
	if not DataService.SaveNow(player) then
		-- Not saved: don't acknowledge. The receipt id is in memory, so a retry
		-- on this server won't double-grant; on another server the unsaved
		-- grant never existed.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	NotifyService.Send(player, string.format("+%d credits. Thanks for supporting VOIDLINE!", credits), "Success", 5)
	AnalyticsService.Track("RobuxCreditPack", credits, nil, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function grantSupporter(player: Player)
	DataService.Update(player, function(p)
		p.Supporter = true
		p.Owned.plate_supporter = true
	end)
end

local function checkSupporter(player: Player)
	local passId = Config.Monetization.SupporterPassId
	if passId == 0 then
		return
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	if ok and owns then
		grantSupporter(player)
	end
end

function ShopService.Start()
	RemoteService.OnInvoke(Net.Names.PurchaseItem, { Validate.oneOf(itemIds) }, function(player: Player, itemId: string)
		local ok, message = ShopService.Purchase(player, itemId)
		return { Ok = ok, Message = message }
	end)

	RemoteService.OnEvent(
		Net.Names.EquipItem,
		{ Validate.oneOf(CosmeticCatalog.EquipSlots), Validate.oneOf(itemIds) },
		function(player: Player, slot: string, itemId: string)
			ShopService.Equip(player, slot, itemId)
		end
	)

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.Monetization.SupporterPassId and passId ~= 0 then
			grantSupporter(player)
			NotifyService.Send(player, "Supporter nameplate unlocked. Thank you!", "Success", 5)
		end
	end)

	DataService.ProfileLoaded:Connect(function(player: Player)
		task.spawn(checkSupporter, player)
	end)
end

return ShopService
