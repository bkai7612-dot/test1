--!strict
--[[
	ObjectiveAssigner
	Pure logic choosing which objectives each player receives and which
	alternative station each objective step uses this round.
]]

local Types = require(script.Parent.Parent.Types)

export type StepLike = { Stations: { any } }
export type ObjectiveLike = { Id: string, Category: string, Length: string, Steps: { StepLike } }
export type Rules = { Count: number, MaxCarry: number, MinLong: number, MaxLong: number }

local ObjectiveAssigner = {}

local function shuffled<T>(list: { T }, rng: Types.Rng): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = rng:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end
ObjectiveAssigner.shuffled = shuffled

-- For every objective, picks one station alternative per step.
-- Returns { [objectiveId] = { altIndexForStep1, altIndexForStep2, ... } }.
function ObjectiveAssigner.pickStations(objectives: { ObjectiveLike }, rng: Types.Rng): { [string]: { number } }
	local result: { [string]: { number } } = {}
	for _, objective in objectives do
		local picks = {}
		for stepIndex, step in objective.Steps do
			picks[stepIndex] = rng:NextInteger(1, #step.Stations)
		end
		result[objective.Id] = picks
	end
	return result
end

-- Chooses `rules.Count` objective ids with a healthy mix of lengths and categories.
function ObjectiveAssigner.assign(objectives: { ObjectiveLike }, rules: Rules, rng: Types.Rng): { string }
	local pool = shuffled(objectives, rng)
	local chosen: { string } = {}
	local usedCategories: { [string]: number } = {}
	local longCount, carryCount = 0, 0

	local function take(objective: ObjectiveLike)
		table.insert(chosen, objective.Id)
		usedCategories[objective.Category] = (usedCategories[objective.Category] or 0) + 1
		if objective.Length == "Long" then
			longCount += 1
		elseif objective.Length == "Carry" then
			carryCount += 1
		end
	end

	local function isChosen(id: string): boolean
		return table.find(chosen, id) ~= nil
	end

	-- 1) Guarantee the minimum number of long objectives.
	for _, objective in pool do
		if longCount >= rules.MinLong or #chosen >= rules.Count then
			break
		end
		if objective.Length == "Long" then
			take(objective)
		end
	end

	-- 2) Fill, preferring new categories; 3) fill again allowing repeats.
	for pass = 1, 2 do
		for _, objective in pool do
			if #chosen >= rules.Count then
				break
			end
			if not isChosen(objective.Id) then
				local lengthOk = (objective.Length ~= "Long" or longCount < rules.MaxLong)
					and (objective.Length ~= "Carry" or carryCount < rules.MaxCarry)
				local categoryOk = pass == 2 or usedCategories[objective.Category] == nil
				if lengthOk and categoryOk then
					take(objective)
				end
			end
		end
	end

	return chosen
end

return ObjectiveAssigner
