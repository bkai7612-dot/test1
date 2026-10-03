--!strict
--[[
	Validate
	Composable runtime type checks for data arriving from clients.
	Every client->server remote declares a list of checks, one per argument,
	and RemoteService rejects the call before the handler runs if any fail.

	    RemoteService.OnEvent("CastVote", { Validate.integer(1, 12) }, handler)

	A check returns (true) or (false, reason).
]]

local Players = game:GetService("Players")

export type Check = (value: any) -> (boolean, string?)

local Validate = {}

local function isFiniteNumber(value: any): boolean
	-- NaN fails value == value; inf fails the abs comparison.
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

function Validate.any(): Check
	return function()
		return true
	end
end

function Validate.boolean(): Check
	return function(value)
		if type(value) ~= "boolean" then
			return false, "expected boolean"
		end
		return true
	end
end

function Validate.number(min: number?, max: number?): Check
	return function(value)
		if not isFiniteNumber(value) then
			return false, "expected finite number"
		end
		if min and value < min then
			return false, "number below minimum"
		end
		if max and value > max then
			return false, "number above maximum"
		end
		return true
	end
end

function Validate.integer(min: number?, max: number?): Check
	local numberCheck = Validate.number(min, max)
	return function(value)
		local ok, reason = numberCheck(value)
		if not ok then
			return false, reason
		end
		if value % 1 ~= 0 then
			return false, "expected integer"
		end
		return true
	end
end

function Validate.string(maxLength: number?, minLength: number?): Check
	return function(value)
		if type(value) ~= "string" then
			return false, "expected string"
		end
		-- utf8.len returns nil for invalid UTF-8 byte sequences.
		local length = utf8.len(value)
		if length == nil then
			return false, "invalid utf8"
		end
		if maxLength and length > maxLength then
			return false, "string too long"
		end
		if minLength and length < minLength then
			return false, "string too short"
		end
		return true
	end
end

-- Value must equal one of the provided options (typically enum strings).
function Validate.oneOf(options: { any }): Check
	return function(value)
		if table.find(options, value) == nil then
			return false, "value not in allowed set"
		end
		return true
	end
end

function Validate.instanceOf(className: string): Check
	return function(value)
		if typeof(value) ~= "Instance" or not value:IsA(className) then
			return false, "expected " .. className
		end
		return true
	end
end

-- A Player who is currently in this server.
function Validate.player(): Check
	return function(value)
		if typeof(value) ~= "Instance" or not value:IsA("Player") or value.Parent ~= Players then
			return false, "expected connected player"
		end
		return true
	end
end

-- A table with at most `maxEntries` entries (contents are validated by the consumer).
function Validate.table(maxEntries: number): Check
	return function(value)
		if type(value) ~= "table" then
			return false, "expected table"
		end
		local count = 0
		for _ in value do
			count += 1
			if count > maxEntries then
				return false, "table too large"
			end
		end
		return true
	end
end

-- Any primitive value commonly used as a loosely-typed argument.
function Validate.primitive(maxStringLength: number?): Check
	local stringCheck = Validate.string(maxStringLength or 200)
	local numberCheck = Validate.number()
	return function(value)
		local kind = type(value)
		if kind == "string" then
			return stringCheck(value)
		elseif kind == "number" then
			return numberCheck(value)
		elseif kind == "boolean" then
			return true
		end
		return false, "expected primitive"
	end
end

function Validate.optional(check: Check): Check
	return function(value)
		if value == nil then
			return true
		end
		return check(value)
	end
end

-- Validates a full argument list. `count` is select("#", ...) of the received
-- args so extra trailing arguments are rejected too.
function Validate.args(checks: { Check }, args: { any }, count: number): (boolean, string?)
	if count > #checks then
		return false, string.format("too many arguments (%d > %d)", count, #checks)
	end
	for index, check in checks do
		local ok, reason = check(args[index])
		if not ok then
			return false, string.format("argument %d: %s", index, reason or "invalid")
		end
	end
	return true
end

return Validate
