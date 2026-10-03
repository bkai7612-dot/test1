--!strict
--[[
	VoteTally
	Pure vote counting for musters.

	votes: { [voterId] = targetId | VoteTally.SKIP }
	Only votes from `eligibleVoters` for `eligibleTargets` (or skip) count, so
	votes from players who left or were eliminated mid-vote are discarded, as
	are votes for players who are no longer valid targets.

	Outcomes:
	  Confine - a single target strictly has the most votes and beats skip
	  Tie     - two or more targets share the top count (above skip)
	  Skip    - skip votes are >= the top target count
	  NoVotes - nobody cast a valid vote
]]

local VoteTally = {}

VoteTally.SKIP = "__skip"

export type Result = {
	Outcome: "Confine" | "Tie" | "Skip" | "NoVotes",
	Target: any?,
	Counts: { [any]: number },
	SkipCount: number,
	ValidVotes: number,
}

function VoteTally.tally(votes: { [any]: any }, eligibleVoters: { [any]: boolean }, eligibleTargets: { [any]: boolean }): Result
	local counts: { [any]: number } = {}
	local skipCount = 0
	local valid = 0

	for voter, target in votes do
		if eligibleVoters[voter] then
			if target == VoteTally.SKIP then
				skipCount += 1
				valid += 1
			elseif eligibleTargets[target] then
				counts[target] = (counts[target] or 0) + 1
				valid += 1
			end
		end
	end

	if valid == 0 then
		return { Outcome = "NoVotes", Counts = counts, SkipCount = 0, ValidVotes = 0 }
	end

	local topCount = 0
	local leaders = {}
	for target, count in counts do
		if count > topCount then
			topCount = count
			leaders = { target }
		elseif count == topCount then
			table.insert(leaders, target)
		end
	end

	if topCount == 0 or skipCount >= topCount then
		return { Outcome = "Skip", Counts = counts, SkipCount = skipCount, ValidVotes = valid }
	end
	if #leaders > 1 then
		return { Outcome = "Tie", Counts = counts, SkipCount = skipCount, ValidVotes = valid }
	end
	return { Outcome = "Confine", Target = leaders[1], Counts = counts, SkipCount = skipCount, ValidVotes = valid }
end

return VoteTally
