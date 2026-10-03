--!strict
--[[
	TableUtil
	Small, dependency-free table helpers shared by client and server.
]]

local TableUtil = {}

-- Recursively freezes a table so configuration cannot be mutated at runtime.
function TableUtil.deepFreeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, child in value :: any do
			TableUtil.deepFreeze(child)
		end
		table.freeze(value :: any)
	end
	return value
end

-- Recursively copies plain data tables. Metatables are not preserved.
function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[TableUtil.deepCopy(key)] = TableUtil.deepCopy(child)
	end
	return copy :: any
end

-- Counts entries in any table (dictionaries included).
function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

return TableUtil
