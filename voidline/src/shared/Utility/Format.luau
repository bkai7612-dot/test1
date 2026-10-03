--!strict
--[[
	Format
	Small text helpers for timers and labels.
]]

local Format = {}

-- 75 -> "01:15"
function Format.clock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", total // 60, total % 60)
end

-- 0.456 -> "46%"
function Format.percent(fraction: number): string
	return string.format("%d%%", math.floor(math.clamp(fraction, 0, 1) * 100 + 0.5))
end

-- 1234567 -> "1,234,567"
function Format.thousands(value: number): string
	local formatted = tostring(math.floor(value))
	while true do
		local replaced, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return formatted
end

return Format
