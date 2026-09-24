-- Performance upgrades. Every car tracks its own upgrade levels.
local Cars = require(script.Parent.Cars)

local Upgrades = {}

Upgrades.MAX_LEVEL = 5
Upgrades.Order = { "Engine", "Turbo", "Handling", "Brakes", "Nitro" }

Upgrades.Info = {
	Engine = { name = "Engine", short = "ENG", description = "+6% top speed per level" },
	Turbo = { name = "Turbo", short = "TRB", description = "+8% acceleration per level" },
	Handling = { name = "Suspension", short = "SUS", description = "+5% steering and +6% grip per level" },
	Brakes = { name = "Brakes", short = "BRK", description = "+10% braking power per level" },
	Nitro = { name = "Nitro", short = "N2O", description = "+15% nitro tank and stronger boost per level" },
}

function Upgrades.Default()
	return { Engine = 0, Turbo = 0, Handling = 0, Brakes = 0, Nitro = 0 }
end

-- Coin cost to go from `currentLevel` to `currentLevel + 1`.
function Upgrades.Cost(carId, stat, currentLevel)
	local car = Cars.List[carId]
	if not car or currentLevel >= Upgrades.MAX_LEVEL then
		return nil
	end
	local statMult = (stat == "Nitro" or stat == "Brakes") and 0.8 or 1
	local raw = car.upgradeBase * statMult * (1 + currentLevel) ^ 1.45
	return math.floor(raw / 10 + 0.5) * 10
end

-- Final driving stats for a car with the given upgrade levels.
function Upgrades.GetStats(carId, upgrades)
	local base = Cars.List[carId].stats
	upgrades = upgrades or {}
	local e = upgrades.Engine or 0
	local t = upgrades.Turbo or 0
	local h = upgrades.Handling or 0
	local b = upgrades.Brakes or 0
	local n = upgrades.Nitro or 0
	return {
		topSpeed = base.topSpeed * (1 + 0.06 * e),
		accel = base.accel * (1 + 0.08 * t),
		handling = base.handling * (1 + 0.05 * h),
		grip = base.grip * (1 + 0.06 * h),
		brake = base.brake * (1 + 0.1 * b),
		nitro = base.nitro * (1 + 0.15 * n),
		nitroPower = 1.35 + 0.04 * n,
	}
end

return Upgrades
