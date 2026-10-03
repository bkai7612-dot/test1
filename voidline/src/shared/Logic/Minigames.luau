--!strict
--[[
	Minigames
	Server-issued challenges for objective mini-games, and verification of the
	client's answer. The server keeps the `secret` and only sends `challenge`.
	The client cannot complete an objective without an answer that matches,
	and ObjectiveService also enforces a minimum solve time.

	Kinds:
	  Sliders  - challenge { Targets = {n, n, n}, Tolerance }       answer { n, n, n }
	  Sequence - challenge { Code = "47192" }                       answer "47192"
	  Timing   - challenge { Zones = {{Start, Width}...}, Period }  answer { Hits, Misses }
	  Wires    - challenge { Left = {c...}, Right = {c...} }        answer { rightIndexForLeft1, ... }
]]

local Types = require(script.Parent.Parent.Types)

local Minigames = {}

Minigames.TimeLimit = { Sliders = 25, Sequence = 25, Timing = 25, Wires = 25 }
Minigames.MinSeconds = { Sliders = 1.2, Sequence = 2, Timing = 2.5, Wires = 1.5 }

local SLIDER_COUNT = 3
local SLIDER_TOLERANCE = 6
local CODE_LENGTH = 5
local WIRE_COUNT = 4
local TIMING_ZONES = 3
local TIMING_REQUIRED = 3
local TIMING_MAX_MISSES = 2

function Minigames.generate(kind: string, rng: Types.Rng): (any, any)
	if kind == "Sliders" then
		local targets = {}
		for i = 1, SLIDER_COUNT do
			targets[i] = rng:NextInteger(10, 90)
		end
		return { Targets = targets, Tolerance = SLIDER_TOLERANCE }, { Targets = targets }
	elseif kind == "Sequence" then
		local digits = {}
		for i = 1, CODE_LENGTH do
			digits[i] = tostring(rng:NextInteger(0, 9))
		end
		local code = table.concat(digits)
		return { Code = code }, { Code = code }
	elseif kind == "Timing" then
		local zones = {}
		for i = 1, TIMING_ZONES do
			local width = 0.12 + rng:NextNumber(0, 0.06)
			zones[i] = { Start = rng:NextNumber(0.05, 0.95 - width), Width = width }
		end
		return {
			Zones = zones,
			Period = 1.4 + rng:NextNumber(0, 0.6),
			Required = TIMING_REQUIRED,
			MaxMisses = TIMING_MAX_MISSES,
		}, { Required = TIMING_REQUIRED, MaxMisses = TIMING_MAX_MISSES }
	elseif kind == "Wires" then
		local left = {}
		for i = 1, WIRE_COUNT do
			left[i] = i
		end
		-- Shuffle until the right side isn't identical to the left.
		local right = table.clone(left)
		repeat
			for i = #right, 2, -1 do
				local j = rng:NextInteger(1, i)
				right[i], right[j] = right[j], right[i]
			end
			local identical = true
			for i = 1, WIRE_COUNT do
				if right[i] ~= left[i] then
					identical = false
					break
				end
			end
		until not identical
		local mapping = {}
		for i, colour in left do
			mapping[i] = table.find(right, colour)
		end
		return { Left = left, Right = right }, { Mapping = mapping }
	end
	error("Unknown minigame kind " .. tostring(kind))
end

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0
end

function Minigames.verify(kind: string, secret: any, answer: any): (boolean, string?)
	if kind == "Sliders" then
		if type(answer) ~= "table" or #answer ~= #secret.Targets then
			return false, "malformed"
		end
		for i, target in secret.Targets do
			local value = answer[i]
			if type(value) ~= "number" or value ~= value or math.abs(value - target) > SLIDER_TOLERANCE then
				return false, "misaligned"
			end
		end
		return true
	elseif kind == "Sequence" then
		if type(answer) ~= "string" then
			return false, "malformed"
		end
		return answer == secret.Code, if answer == secret.Code then nil else "wrong code"
	elseif kind == "Timing" then
		if type(answer) ~= "table" or not isInteger(answer.Hits) or not isInteger(answer.Misses) then
			return false, "malformed"
		end
		if answer.Misses > secret.MaxMisses then
			return false, "too many misses"
		end
		if answer.Hits < secret.Required then
			return false, "not enough hits"
		end
		return true
	elseif kind == "Wires" then
		if type(answer) ~= "table" or #answer ~= #secret.Mapping then
			return false, "malformed"
		end
		for i, expected in secret.Mapping do
			if answer[i] ~= expected then
				return false, "miswired"
			end
		end
		return true
	end
	return false, "unknown kind"
end

return Minigames
