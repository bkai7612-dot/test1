--!strict
--[[
	Rewards
	Pure end-of-round reward calculation. RewardService gathers the inputs
	from server-tracked round stats; the client never reports any of them.
]]

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

local Rewards = {}

export type Input = {
	Faction: string,
	Won: boolean,
	Survived: boolean,
	Escaped: boolean,
	Stats: Types.RoundStats,
}
export type Line = { Label: string, Xp: number }
export type Result = { Xp: number, Credits: number, Lines: { Line } }

function Rewards.compute(input: Input): Result
	local xpTable = Config.Rewards.Xp
	local lines: { Line } = {}
	local function add(label: string, amount: number)
		if amount > 0 then
			table.insert(lines, { Label = label, Xp = math.floor(amount) })
		end
	end

	local stats = input.Stats
	add("Round complete", xpTable.RoundComplete)
	if input.Won then
		add("Victory", xpTable.Win)
	end
	if input.Faction == "Crew" then
		add("Objective steps", stats.TaskSteps * xpTable.TaskStep)
		add("Objectives completed", stats.TasksCompleted * xpTable.TaskComplete)
		add("Teammates revived", stats.Revives * xpTable.Revive)
		add("Correct accusations", stats.CorrectVotes * xpTable.CorrectVote)
		if input.Survived then
			add("Survived", xpTable.Survive)
		end
		if input.Escaped then
			add("Escaped", xpTable.Escape)
		end
	else
		add("Crew siphoned", stats.Siphons * xpTable.Siphon)
		add("Sabotages", stats.Sabotages * xpTable.Sabotage)
		add("Musters survived undetected", stats.MeetingsSurvived * xpTable.MeetingSurvivedAsInfiltrator)
		if input.Survived then
			add("Stayed hidden", xpTable.Survive)
		end
	end
	add("Investigations", stats.Scans * xpTable.Scan)
	add("Evidence revealed", stats.EvidenceRevealed * xpTable.EvidenceRevealed)
	add("Hazards fixed", stats.HazardsFixed * xpTable.FixHazard)

	local xp = 0
	for _, line in lines do
		xp += line.Xp
	end
	local credits = math.floor(xp * Config.Rewards.CreditsPerXp) + (if input.Won then Config.Rewards.WinCredits else 0)
	return { Xp = xp, Credits = credits, Lines = lines }
end

function Rewards.emptyStats(): Types.RoundStats
	return {
		TaskSteps = 0,
		TasksCompleted = 0,
		Revives = 0,
		Scans = 0,
		EvidenceRevealed = 0,
		CorrectVotes = 0,
		Siphons = 0,
		Sabotages = 0,
		MeetingsSurvived = 0,
		HazardsFixed = 0,
	}
end

return Rewards
