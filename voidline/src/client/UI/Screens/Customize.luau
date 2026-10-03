--!strict
--[[
	Customize
	Cosmetics by slot. Buy with Credits, equip unlocked items. Everything here
	is cosmetic only. Optional Robux credit packs / Supporter pass appear only
	when product ids are configured.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local CosmeticCatalog = require(Shared.Data.CosmeticCatalog)
local Format = require(Shared.Utility.Format)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local SLOTS = { "Suit", "Helmet", "Gloves", "Back", "Nameplate", "Title", "Emote" }

return function(ctx: any)
	local root, body = Components.modal("Customize", "Cosmetic only - nothing here affects gameplay.", ctx.Close, Vector2.new(860, 600))
	local currentSlot = "Suit"

	local tabs = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = body })
	Components.list(6, true).Parent = tabs
	local credits = Components.label("", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 44),
		Size = UDim2.fromOffset(300, 22),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.Font.Bold,
		TextColor3 = Theme.status("Warning"),
		Parent = body,
	})
	local message = Components.label("", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, -310, 0, 22),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Theme.Color.Muted,
		Parent = body,
	})
	local grid = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 1, -130),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Selectable = false,
		Parent = body,
	})
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(190, 120),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local store = Create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 46),
		Parent = body,
	})
	Components.list(8, true).Parent = store
	for index, pack in Config.Monetization.CreditPacks do
		if pack.ProductId ~= 0 then
			Components.button(string.format("+%s credits", Format.thousands(pack.Credits)), function()
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, pack.ProductId)
			end, "Primary", { Size = UDim2.fromOffset(170, 42), LayoutOrder = index, Parent = store })
		end
	end
	if Config.Monetization.SupporterPassId ~= 0 then
		Components.button("Supporter nameplate", function()
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, Config.Monetization.SupporterPassId)
		end, "Success", { Size = UDim2.fromOffset(200, 42), LayoutOrder = 10, Parent = store })
	end

	local function refresh()
		local profile = ctx.Client.GetPrivate(Constants.PrivateKey.Profile)
		if type(profile) ~= "table" then
			return
		end
		credits.Text = Format.thousands(profile.Credits) .. " credits"
		Components.clear(grid)
		for index, item in CosmeticCatalog.itemsForSlot(currentSlot) do
			local unlocked = CosmeticCatalog.isUnlocked(item, profile.Owned or {}, profile.Level or 1)
			local equipped = profile.Equipped and profile.Equipped[currentSlot] == item.Id
			local card = Components.panel({
				LayoutOrder = index,
				BackgroundColor3 = if equipped then Theme.Color.PanelHover else Theme.Color.PanelLight,
				Parent = grid,
			})
			Components.padding(8).Parent = card
			if item.Color then
				Create("Frame", {
					BackgroundColor3 = Color3.fromRGB(item.Color[1], item.Color[2], item.Color[3]),
					Size = UDim2.fromOffset(18, 18),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Parent = card,
				})
			end
			Components.label(item.Name, { Font = Theme.Font.Bold, Size = UDim2.new(1, -24, 0, 20), AutomaticSize = Enum.AutomaticSize.None, Parent = card })
			local statusText
			if equipped then
				statusText = "✓ Equipped"
			elseif unlocked then
				statusText = if currentSlot == "Emote" then "✓ Owned" else "Owned"
			elseif item.Source == "Credits" then
				statusText = Format.thousands(item.Price or 0) .. " credits"
			elseif item.Source == "Level" then
				statusText = "Unlocks at level " .. tostring(item.UnlockLevel)
			else
				statusText = "Supporter reward"
			end
			Components.label(statusText, {
				Position = UDim2.fromOffset(0, 24),
				TextSize = Theme.TextSize.Small,
				TextColor3 = if unlocked then Theme.status("Success") else Theme.Color.Muted,
				Parent = card,
			})
			if not unlocked and item.Source == "Credits" then
				Components.button("Buy", function()
					local result = ctx.Invoke(Net.Names.PurchaseItem, item.Id)
					message.Text = if type(result) == "table" then result.Message else "Purchase failed."
				end, "Primary", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 34), Parent = card })
			elseif unlocked and not equipped and currentSlot ~= "Emote" then
				Components.button("Equip", function()
					ctx.Fire(Net.Names.EquipItem, currentSlot, item.Id)
				end, "Secondary", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 34), Parent = card })
			end
		end
	end

	for index, slot in SLOTS do
		Components.button(slot, function()
			currentSlot = slot
			message.Text = ""
			refresh()
		end, "Secondary", { Size = UDim2.fromOffset(110, 36), LayoutOrder = index, TextSize = Theme.TextSize.Small, Parent = tabs })
	end

	return { Root = root, Refresh = refresh }
end
