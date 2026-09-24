-- Player levelling curve.
local Levels = {}

-- Level cap. Every car and cosmetic unlocks well before this (level 20),
-- so the cap is the long-term goal.
Levels.MAX = 50

-- One-off coin bonus for reaching the cap.
Levels.MAX_LEVEL_BONUS = 5000

-- Once capped, XP from races is converted into coins at this rate, so
-- racing still pays off.
Levels.MAX_XP_TO_COINS = 0.5

-- XP required to go from `level` to `level + 1`.
function Levels.XPForLevel(level)
	return math.floor(100 * level ^ 1.2)
end

-- Coins awarded when reaching `level`.
function Levels.LevelReward(level)
	return 150 + level * 50
end

return Levels
