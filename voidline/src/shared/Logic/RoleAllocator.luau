--!strict
--[[
	RoleAllocator
	Pure role-count and selection logic (no Roblox APIs) so it can be tested
	headless. RoleService feeds it real players and a Roblox Random.

	Fairness rules:
	  * The count comes from the configured bracket for the player count.
	  * Infiltrators can never reach parity at the start (crew > infiltrators).
	  * MaxInfiltratorRatio caps the count for odd configurations.
	  * Players who were infiltrators last round get a reduced selection weight.
]]

local Types = require(script.Parent.Parent.Types)

export type Bracket = { MinPlayers: number, MaxPlayers: number, Min: number, Max: number }
export type Candidate = { Id: any, Weight: number }

local RoleAllocator = {}

local function findBracket(playerCount: number, scaling: { Bracket }): Bracket?
	for _, bracket in scaling do
		if playerCount >= bracket.MinPlayers and playerCount <= bracket.MaxPlayers then
			return bracket
		end
	end
	-- Above the highest bracket: use the largest one.
	local best: Bracket? = nil
	for _, bracket in scaling do
		if playerCount > bracket.MaxPlayers and (best == nil or bracket.MaxPlayers > best.MaxPlayers) then
			best = bracket
		end
	end
	return best
end

-- Largest infiltrator count that is still fair for `playerCount`.
function RoleAllocator.fairCap(playerCount: number, maxRatio: number): number
	if playerCount < 2 then
		return 0
	end
	-- Crew must strictly outnumber infiltrators.
	local parityCap = (playerCount - 1) // 2
	local ratioCap = math.max(1, math.floor(playerCount * maxRatio))
	return math.min(parityCap, ratioCap)
end

-- Number of infiltrators for this round. `override` (e.g. a private server
-- host setting) is honoured but still clamped to the fair cap.
function RoleAllocator.infiltratorCount(
	playerCount: number,
	scaling: { Bracket },
	maxRatio: number,
	rng: Types.Rng,
	override: number?
): number
	local cap = RoleAllocator.fairCap(playerCount, maxRatio)
	if override then
		return math.clamp(math.floor(override), 0, cap)
	end
	local bracket = findBracket(playerCount, scaling)
	if not bracket then
		return math.min(1, cap)
	end
	local count = rng:NextInteger(bracket.Min, math.max(bracket.Min, bracket.Max))
	return math.clamp(count, 0, cap)
end

-- Weighted selection without replacement. Returns a set of chosen ids.
function RoleAllocator.pick(candidates: { Candidate }, count: number, rng: Types.Rng): { [any]: boolean }
	local chosen: { [any]: boolean } = {}
	local pool = table.clone(candidates)
	for _ = 1, math.min(count, #pool) do
		local total = 0
		for _, candidate in pool do
			total += math.max(candidate.Weight, 0.0001)
		end
		local roll = rng:NextNumber(0, total)
		local index = #pool
		local running = 0
		for i, candidate in pool do
			running += math.max(candidate.Weight, 0.0001)
			if roll <= running then
				index = i
				break
			end
		end
		chosen[pool[index].Id] = true
		table.remove(pool, index)
	end
	return chosen
end

return RoleAllocator
