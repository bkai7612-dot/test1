--!strict
--[[
	CosmeticCatalog
	Every cosmetic item. Cosmetics never affect gameplay: suits, helmets and
	packs are decorative parts; the round's accent (a gameplay clue) is drawn
	separately and cannot be changed by cosmetics.

	Unlock sources:
	  Default     - owned by everyone
	  Credits     - bought with in-game Credits (Price)
	  Level       - unlocked automatically at UnlockLevel
	  Pass        - granted by the cosmetic Supporter game pass
]]

local TableUtil = require(script.Parent.Parent.Utility.TableUtil)

export type Item = {
	Id: string,
	Slot: string,
	Name: string,
	Source: "Default" | "Credits" | "Level" | "Pass",
	Price: number?,
	UnlockLevel: number?,
	Color: { number }?,
	Style: string?,
	Emote: string?,
	Description: string?,
}

local ITEMS: { Item } = {
	-- Suits (a fitted vest over the avatar's torso)
	{ Id = "suit_standard", Slot = "Suit", Name = "Standard Issue", Source = "Default", Color = { 120, 128, 140 } },
	{ Id = "suit_hazard", Slot = "Suit", Name = "Hazard Orange", Source = "Credits", Price = 200, Color = { 235, 120, 40 } },
	{ Id = "suit_deep", Slot = "Suit", Name = "Deep Blue", Source = "Credits", Price = 200, Color = { 40, 70, 150 } },
	{ Id = "suit_field", Slot = "Suit", Name = "Field Green", Source = "Credits", Price = 300, Color = { 70, 110, 70 } },
	{ Id = "suit_ivory", Slot = "Suit", Name = "Ivory Lab", Source = "Level", UnlockLevel = 5, Color = { 230, 228, 218 } },
	{ Id = "suit_graphite", Slot = "Suit", Name = "Graphite", Source = "Level", UnlockLevel = 10, Color = { 45, 48, 56 } },
	{ Id = "suit_solar", Slot = "Suit", Name = "Solar Flare", Source = "Credits", Price = 800, Color = { 250, 200, 60 }, Style = "Glow" },
	{ Id = "suit_void", Slot = "Suit", Name = "Voidwalker", Source = "Level", UnlockLevel = 30, Color = { 20, 16, 40 }, Style = "Glow" },

	-- Helmets
	{ Id = "helmet_none", Slot = "Helmet", Name = "No Helmet", Source = "Default" },
	{ Id = "helmet_visor", Slot = "Helmet", Name = "Visor Band", Source = "Credits", Price = 150, Color = { 90, 200, 255 }, Style = "Visor" },
	{ Id = "helmet_dome", Slot = "Helmet", Name = "Glass Dome", Source = "Credits", Price = 350, Color = { 200, 230, 255 }, Style = "Dome" },
	{ Id = "helmet_hood", Slot = "Helmet", Name = "Engineer Hood", Source = "Level", UnlockLevel = 8, Color = { 200, 120, 40 }, Style = "Hood" },
	{ Id = "helmet_halo", Slot = "Helmet", Name = "Halo Lamp", Source = "Credits", Price = 600, Color = { 255, 240, 180 }, Style = "Halo" },

	-- Gloves
	{ Id = "gloves_none", Slot = "Gloves", Name = "Bare Hands", Source = "Default" },
	{ Id = "gloves_work", Slot = "Gloves", Name = "Work Gloves", Source = "Credits", Price = 100, Color = { 150, 110, 70 } },
	{ Id = "gloves_insulated", Slot = "Gloves", Name = "Insulated", Source = "Credits", Price = 250, Color = { 240, 200, 40 } },
	{ Id = "gloves_chrome", Slot = "Gloves", Name = "Chrome", Source = "Level", UnlockLevel = 15, Color = { 200, 205, 215 }, Style = "Metal" },

	-- Back accessories
	{ Id = "back_none", Slot = "Back", Name = "Nothing", Source = "Default" },
	{ Id = "back_oxygen", Slot = "Back", Name = "Oxygen Pack", Source = "Credits", Price = 250, Color = { 220, 220, 230 }, Style = "Tanks" },
	{ Id = "back_toolrack", Slot = "Back", Name = "Tool Rack", Source = "Credits", Price = 400, Color = { 90, 95, 100 }, Style = "Rack" },
	{ Id = "back_antenna", Slot = "Back", Name = "Comms Antenna", Source = "Level", UnlockLevel = 12, Color = { 160, 165, 175 }, Style = "Antenna" },
	{ Id = "back_drone", Slot = "Back", Name = "Shoulder Drone", Source = "Credits", Price = 900, Color = { 90, 200, 255 }, Style = "Drone" },

	-- Nameplates
	{ Id = "plate_basic", Slot = "Nameplate", Name = "Basic", Source = "Default", Color = { 20, 26, 36 } },
	{ Id = "plate_neon", Slot = "Nameplate", Name = "Neon Edge", Source = "Credits", Price = 200, Color = { 86, 214, 255 }, Style = "Edge" },
	{ Id = "plate_hazard", Slot = "Nameplate", Name = "Hazard Stripe", Source = "Level", UnlockLevel = 6, Color = { 255, 196, 92 }, Style = "Edge" },
	{ Id = "plate_holo", Slot = "Nameplate", Name = "Holo", Source = "Credits", Price = 500, Color = { 190, 140, 255 }, Style = "Edge" },
	{ Id = "plate_supporter", Slot = "Nameplate", Name = "Supporter", Source = "Pass", Color = { 255, 215, 120 }, Style = "Edge", Description = "Thanks for supporting VOIDLINE!" },

	-- Titles (shown under your name)
	{ Id = "title_recruit", Slot = "Title", Name = "Recruit", Source = "Default" },
	{ Id = "title_technician", Slot = "Title", Name = "Technician", Source = "Level", UnlockLevel = 2 },
	{ Id = "title_specialist", Slot = "Title", Name = "Specialist", Source = "Level", UnlockLevel = 5 },
	{ Id = "title_navigator", Slot = "Title", Name = "Navigator", Source = "Level", UnlockLevel = 10 },
	{ Id = "title_unshaken", Slot = "Title", Name = "Unshaken", Source = "Credits", Price = 150 },
	{ Id = "title_ghost", Slot = "Title", Name = "Signal Ghost", Source = "Credits", Price = 300 },
	{ Id = "title_veteran", Slot = "Title", Name = "Veteran", Source = "Level", UnlockLevel = 25 },
	{ Id = "title_commander", Slot = "Title", Name = "Commander", Source = "Level", UnlockLevel = 40 },

	-- Emotes (Roblox default avatar emotes, played locally by the avatar's Animate script)
	{ Id = "emote_wave", Slot = "Emote", Name = "Wave", Source = "Default", Emote = "wave" },
	{ Id = "emote_point", Slot = "Emote", Name = "Point", Source = "Default", Emote = "point" },
	{ Id = "emote_cheer", Slot = "Emote", Name = "Cheer", Source = "Level", UnlockLevel = 3, Emote = "cheer" },
	{ Id = "emote_laugh", Slot = "Emote", Name = "Laugh", Source = "Credits", Price = 150, Emote = "laugh" },
	{ Id = "emote_dance", Slot = "Emote", Name = "Dance", Source = "Credits", Price = 300, Emote = "dance" },
	{ Id = "emote_dance2", Slot = "Emote", Name = "Groove", Source = "Credits", Price = 450, Emote = "dance2" },
	{ Id = "emote_dance3", Slot = "Emote", Name = "Zero-G Shuffle", Source = "Level", UnlockLevel = 20, Emote = "dance3" },
}

-- Default equipped item per slot (Emote slot holds the owned list, not an equip).
local DEFAULT_EQUIPPED = {
	Suit = "suit_standard",
	Helmet = "helmet_none",
	Gloves = "gloves_none",
	Back = "back_none",
	Nameplate = "plate_basic",
	Title = "title_recruit",
}

local CosmeticCatalog = {}

local byId: { [string]: Item } = {}
for _, item in ITEMS do
	byId[item.Id] = item
end

CosmeticCatalog.Items = ITEMS
CosmeticCatalog.DefaultEquipped = DEFAULT_EQUIPPED
CosmeticCatalog.EquipSlots = { "Suit", "Helmet", "Gloves", "Back", "Nameplate", "Title" }

function CosmeticCatalog.get(id: string): Item?
	return byId[id]
end

-- True if `item` is available to a player with the given ownership state.
function CosmeticCatalog.isUnlocked(item: Item, owned: { [string]: boolean }, level: number): boolean
	if item.Source == "Default" then
		return true
	elseif item.Source == "Level" then
		return level >= (item.UnlockLevel or math.huge)
	end
	return owned[item.Id] == true
end

function CosmeticCatalog.itemsForSlot(slot: string): { Item }
	local list = {}
	for _, item in ITEMS do
		if item.Slot == slot then
			table.insert(list, item)
		end
	end
	return list
end

return TableUtil.deepFreeze(CosmeticCatalog)
