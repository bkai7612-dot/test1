-- Which race / free-drive session each player is currently in.
local Sessions = {}

local byPlayer = {}

function Sessions.Get(player)
	return byPlayer[player]
end

function Sessions.Set(player, session)
	byPlayer[player] = session
end

-- Only clears if the player is still in `session` (they may have moved on).
function Sessions.Clear(player, session)
	if byPlayer[player] == session then
		byPlayer[player] = nil
	end
end

-- True if the player is in a competitive race (not free drive).
function Sessions.IsRacing(player)
	local session = byPlayer[player]
	return session ~= nil and session.raceType ~= "FreeDrive"
end

return Sessions
