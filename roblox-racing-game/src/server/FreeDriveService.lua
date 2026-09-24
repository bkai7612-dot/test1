-- Free drive: pick any circuit and cruise it with no timer or opponents.
-- One shared free-drive track per map, opened on demand and removed a few
-- seconds after the last driver leaves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maps = require(Shared.Maps)

local RaceSession = require(script.Parent.RaceSession)
local Sessions = require(script.Parent.Sessions)

local FreeDriveService = {}
FreeDriveService.OnChanged = nil -- set by RaceService

local sessions = {} -- [mapId] = RaceSession

local function changed()
	if FreeDriveService.OnChanged then
		FreeDriveService.OnChanged()
	end
end

function FreeDriveService.Counts()
	local counts = {}
	for mapId, session in sessions do
		counts[mapId] = session:PlayerCount()
	end
	return counts
end

function FreeDriveService.Join(player, mapId)
	if type(mapId) ~= "string" or not Maps.List[mapId] then
		return false, "Unknown map."
	end
	local current = Sessions.Get(player)
	if current and current.raceType ~= "FreeDrive" then
		return false, "You're in a race right now."
	end
	if current then
		if current.mapId == mapId then
			return false, "You're already driving this circuit."
		end
		current:RemovePlayer(player, true)
	end

	local session = sessions[mapId]
	if not session or session.closing or session.closed then
		session = RaceSession.new({ mapId = mapId, raceType = "FreeDrive" })
		sessions[mapId] = session
		task.spawn(function()
			local ok, err = pcall(session.RunFreeDrive, session)
			if not ok then
				warn("[FreeDriveService]", err)
				pcall(session.Cleanup, session)
			end
			if sessions[mapId] == session then
				sessions[mapId] = nil
			end
			changed()
		end)
	end

	local deadline = os.clock() + 15
	while not session.track and os.clock() < deadline do
		task.wait(0.1)
	end
	if not session.track or session.closing then
		return false, "That circuit is still loading. Try again."
	end
	local racer = session:AddPlayer(player)
	changed()
	if not racer then
		return false, "Couldn't spawn your car. Try again in a moment."
	end
	return true, "Free driving " .. Maps.List[mapId].name .. ". Press F (or EXIT) to leave."
end

function FreeDriveService.Leave(player)
	local current = Sessions.Get(player)
	if current and current.raceType == "FreeDrive" then
		current:RemovePlayer(player)
		changed()
		return true
	end
	return false
end

return FreeDriveService
