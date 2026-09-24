-- Player levelling curve.
local Levels = {}

Levels.MAX = 100

-- XP required to go from `level` to `level + 1`.
function Levels.XPForLevel(level)
	return math.floor(100 * level ^ 1.2)
end

-- Coins awarded when reaching `level`.
function Levels.LevelReward(level)
	return 150 + level * 50
end

return Levels
