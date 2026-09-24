-- Robux monetisation.
--
-- Create these in the Creator Dashboard (Monetization > Developer Products /
-- Passes) and paste the ids below. Any entry with id = 0 is shown in the
-- shop as "Coming soon" and cannot be bought, so the game runs safely
-- before you configure anything. `robux` is only a display fallback; the
-- live price is fetched from Roblox when an id is set.
local Products = {}

Products.Developer = {
	Coins1 = { id = 0, name = "Pocket Change", coins = 1000, robux = 25, order = 1 },
	Coins2 = { id = 0, name = "Coin Stack", coins = 5000, robux = 99, order = 2 },
	Coins3 = { id = 0, name = "Coin Vault", coins = 15000, robux = 249, order = 3 },
	Coins4 = { id = 0, name = "Coin Mountain", coins = 50000, robux = 699, order = 4 },

	-- Instantly max ONE upgrade stat on the chosen car.
	MaxUpgrade = { id = 0, name = "Instant Max Upgrade", robux = 49 },
	-- Instantly max EVERY upgrade stat on the chosen car.
	MaxAllUpgrades = { id = 0, name = "Fully Tuned", robux = 199 },

	-- Skip the grind: unlock a car with Robux (ignores level requirement).
	Car_Rally = { id = 0, name = "Unlock Rally Sport", car = "Rally", robux = 79 },
	Car_Muscle = { id = 0, name = "Unlock Muscle V8", car = "Muscle", robux = 149 },
	Car_Tuner = { id = 0, name = "Unlock Tuner GT", car = "Tuner", robux = 249 },
	Car_Hyper = { id = 0, name = "Unlock Hyper X", car = "Hyper", robux = 449 },
}

Products.Passes = {
	VIP = {
		id = 0,
		name = "VIP",
		robux = 299,
		description = "2x coins from every race, VIP-only paints, rims, rainbow underglow and neon finish.",
	},
	DoubleXP = {
		id = 0,
		name = "2x XP",
		robux = 149,
		description = "Earn double XP from every race and level up twice as fast.",
	},
}

function Products.FindDeveloperById(id)
	for key, info in Products.Developer do
		if info.id ~= 0 and info.id == id then
			return key, info
		end
	end
	return nil
end

function Products.FindPassById(id)
	for key, info in Products.Passes do
		if info.id ~= 0 and info.id == id then
			return key, info
		end
	end
	return nil
end

return Products
