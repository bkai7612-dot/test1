-- Cosmetic customisation options. Every option is free once unlocked by
-- level (or the VIP game pass).
local Cars = require(script.Parent.Cars)

local Customization = {}

Customization.Categories = { "paint", "accent", "rim", "glow", "finish", "wings", "eyes", "trail" }

-- Cosmetic items bought once with coins, then free to equip on any car.
Customization.ItemCategories = { wings = true, eyes = true, trail = true }

Customization.CategoryNames = {
	paint = "Body Paint",
	accent = "Accent / Stripes / Wing",
	rim = "Rims",
	glow = "Underglow",
	finish = "Paint Finish",
	wings = "Wings (shop item)",
	eyes = "Eyes (shop item)",
	trail = "Trail (shop item)",
}

local paints = {
	{ id = "Racing Red", color = Color3.fromRGB(200, 25, 35) },
	{ id = "Rally Blue", color = Color3.fromRGB(20, 70, 190) },
	{ id = "Grabber Orange", color = Color3.fromRGB(255, 110, 20) },
	{ id = "Pearl White", color = Color3.fromRGB(235, 235, 240) },
	{ id = "Jet Black", color = Color3.fromRGB(20, 20, 24) },
	{ id = "Gunmetal", color = Color3.fromRGB(80, 85, 95) },
	{ id = "Silver", color = Color3.fromRGB(175, 180, 188) },
	{ id = "Sunburst Yellow", color = Color3.fromRGB(250, 205, 20) },
	{ id = "Lime Rush", color = Color3.fromRGB(140, 220, 30) },
	{ id = "British Green", color = Color3.fromRGB(15, 80, 45) },
	{ id = "Sky Blue", color = Color3.fromRGB(90, 180, 245), level = 3 },
	{ id = "Candy Pink", color = Color3.fromRGB(245, 110, 180), level = 4 },
	{ id = "Midnight Purple", color = Color3.fromRGB(60, 25, 110), level = 6 },
	{ id = "Teal Wave", color = Color3.fromRGB(0, 160, 150), level = 8 },
	{ id = "Burnt Copper", color = Color3.fromRGB(170, 85, 45), level = 12 },
	{ id = "Royal Gold", color = Color3.fromRGB(215, 170, 50), level = 20 },
	{ id = "Toxic Green", color = Color3.fromRGB(60, 255, 90), vip = true },
	{ id = "Hot Magenta", color = Color3.fromRGB(255, 0, 170), vip = true },
}

local rims = {
	{ id = "Silver", color = Color3.fromRGB(190, 195, 200) },
	{ id = "Black", color = Color3.fromRGB(25, 25, 28) },
	{ id = "Gunmetal", color = Color3.fromRGB(80, 85, 95) },
	{ id = "White", color = Color3.fromRGB(240, 240, 240) },
	{ id = "Gold", color = Color3.fromRGB(215, 170, 50), level = 5 },
	{ id = "Bronze", color = Color3.fromRGB(150, 100, 50), level = 7 },
	{ id = "Red", color = Color3.fromRGB(200, 25, 35), level = 9 },
	{ id = "Neon Blue", color = Color3.fromRGB(0, 170, 255), vip = true },
}

local glows = {
	{ id = "None" },
	{ id = "Cyan", color = Color3.fromRGB(0, 220, 255), level = 2 },
	{ id = "Red", color = Color3.fromRGB(255, 40, 40), level = 4 },
	{ id = "Green", color = Color3.fromRGB(40, 255, 90), level = 6 },
	{ id = "Purple", color = Color3.fromRGB(170, 60, 255), level = 8 },
	{ id = "Pink", color = Color3.fromRGB(255, 80, 200), level = 12 },
	{ id = "Gold", color = Color3.fromRGB(255, 200, 40), level = 16 },
	{ id = "Rainbow", color = Color3.fromRGB(255, 255, 255), vip = true },
}

local finishes = {
	{ id = "Glossy", material = Enum.Material.SmoothPlastic, reflectance = 0.12 },
	{ id = "Matte", material = Enum.Material.SmoothPlastic, reflectance = 0 },
	{ id = "Metallic", material = Enum.Material.SmoothPlastic, reflectance = 0.3, level = 5 },
	{ id = "Carbon", material = Enum.Material.Fabric, reflectance = 0.05, level = 9 },
	{ id = "Chrome", material = Enum.Material.SmoothPlastic, reflectance = 0.55, level = 14 },
	{ id = "Neon", material = Enum.Material.Neon, reflectance = 0, vip = true },
}

local wings = {
	{ id = "None" },
	{ id = "Angel", price = 4000, color = Color3.fromRGB(245, 245, 250) },
	{ id = "Bat", price = 4000, color = Color3.fromRGB(35, 30, 40) },
	{ id = "Butterfly", price = 6000, color = Color3.fromRGB(240, 110, 200) },
	{ id = "Dragon", price = 7500, color = Color3.fromRGB(170, 25, 25) },
	{ id = "Jet", price = 9000, color = Color3.fromRGB(150, 155, 165) },
}

local eyes = {
	{ id = "None" },
	{ id = "Cute", price = 1500, color = Color3.fromRGB(255, 255, 255) },
	{ id = "Angry", price = 2500, color = Color3.fromRGB(255, 90, 60) },
	{ id = "Lashes", price = 2500, color = Color3.fromRGB(255, 150, 210) },
	{ id = "Love", price = 4000, color = Color3.fromRGB(255, 60, 150) },
	{ id = "Robot", price = 6000, color = Color3.fromRGB(0, 230, 255) },
}

-- Trails are a flat ribbon just above the road behind the car, so they
-- never block the view of whoever is following.
local trails = {
	{ id = "None" },
	{ id = "Blue Streak", price = 1500, color = Color3.fromRGB(40, 140, 255) },
	{ id = "Fire", price = 3000, color = Color3.fromRGB(255, 110, 20), color2 = Color3.fromRGB(255, 30, 0) },
	{ id = "Ice", price = 3000, color = Color3.fromRGB(170, 240, 255), color2 = Color3.fromRGB(40, 150, 255) },
	{ id = "Toxic", price = 3000, color = Color3.fromRGB(120, 255, 60), color2 = Color3.fromRGB(20, 160, 40) },
	{ id = "Gold", price = 6000, color = Color3.fromRGB(255, 215, 60), color2 = Color3.fromRGB(255, 160, 20) },
	{ id = "Rainbow", price = 10000, color = Color3.fromRGB(255, 60, 60), rainbow = true },
}

Customization.Options = {
	paint = paints,
	accent = paints,
	rim = rims,
	glow = glows,
	finish = finishes,
	wings = wings,
	eyes = eyes,
	trail = trails,
}

-- Key used in the player's saved `items` table.
function Customization.ItemKey(category, id)
	return category .. ":" .. id
end

-- Whether the player may equip this option: free options always, shop
-- items once bought (admins own everything).
function Customization.Owns(data, category, option)
	if not option.price then
		return true
	end
	if data.admin then
		return true
	end
	return data.items ~= nil and data.items[Customization.ItemKey(category, option.id)] == true
end

function Customization.Find(category, id)
	local list = Customization.Options[category]
	if not list then
		return nil
	end
	for _, option in list do
		if option.id == id then
			return option
		end
	end
	return nil
end

function Customization.CanUse(option, level, isVip)
	if option.vip and not isVip then
		return false, "VIP only"
	end
	if option.level and level < option.level then
		return false, "Requires level " .. option.level
	end
	return true
end

function Customization.Default(carId)
	local car = Cars.List[carId]
	local custom = {
		paint = car and car.defaultPaint or "Racing Red",
		accent = "Jet Black",
		rim = "Silver",
		glow = "None",
		finish = "Glossy",
		wings = "None",
		eyes = "None",
		trail = "None",
	}
	for key, value in (car and car.defaultCustom) or {} do
		custom[key] = value
	end
	return custom
end

return Customization
