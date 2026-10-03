--!strict
--[[
	Progression
	Level curve, XP application and ship badges (achievements derived from
	lifetime stats). Pure so both server (granting) and client (XP bars) agree.
]]

local Config = require(script.Parent.Parent.Config)

local Progression = {}

export type Badge = { Id: string, Name: string, Description: string, Stat: string, Threshold: number }

Progression.Badges = {
	{ Id = "first_round", Name = "First Shift", Description = "Complete a round.", Stat = "RoundsPlayed", Threshold = 1 },
	{ Id = "first_escape", Name = "Out the Airlock", Description = "Escape the ASTERION.", Stat = "Escapes", Threshold = 1 },
	{ Id = "tasks_50", Name = "Grease Monkey", Description = "Complete 50 objectives.", Stat = "TasksCompleted", Threshold = 50 },
	{ Id = "revives_10", Name = "Lifeline", Description = "Revive 10 crew members.", Stat = "Revives", Threshold = 10 },
	{ Id = "crew_wins_10", Name = "Steady Hands", Description = "Win 10 rounds as crew.", Stat = "CrewWins", Threshold = 10 },
	{ Id = "inf_wins_5", Name = "Quiet Voice", Description = "Win 5 rounds as an infiltrator.", Stat = "InfiltratorWins", Threshold = 5 },
	{ Id = "votes_10", Name = "Sharp Eyes", Description = "Cast 10 correct accusations.", Stat = "CorrectVotes", Threshold = 10 },
	{ Id = "evidence_25", Name = "Archivist", Description = "Reveal 25 pieces of evidence.", Stat = "EvidenceRevealed", Threshold = 25 },
	{ Id = "rounds_100", Name = "Lifer", Description = "Play 100 rounds.", Stat = "RoundsPlayed", Threshold = 100 },
} :: { Badge }

function Progression.xpToNext(level: number): number
	local settings = Config.Progression
	return settings.BaseXpPerLevel + settings.XpPerLevelGrowth * (level - 1)
end

-- Returns (newLevel, newXpIntoLevel, levelsGained).
function Progression.applyXp(level: number, xp: number, gained: number): (number, number, number)
	local maxLevel = Config.Progression.MaxLevel
	local newLevel = level
	local newXp = xp + math.max(0, math.floor(gained))
	while newLevel < maxLevel and newXp >= Progression.xpToNext(newLevel) do
		newXp -= Progression.xpToNext(newLevel)
		newLevel += 1
	end
	if newLevel >= maxLevel then
		newXp = math.min(newXp, Progression.xpToNext(maxLevel))
	end
	return newLevel, newXp, newLevel - level
end

function Progression.earnedBadges(stats: { [string]: number }): { Badge }
	local earned = {}
	for _, badge in Progression.Badges do
		if (stats[badge.Stat] or 0) >= badge.Threshold then
			table.insert(earned, badge)
		end
	end
	return earned
end

return Progression
