-- Team match queues (1v1 up to 5v5). When a queue has enough players the
-- match starts on its own track: random map, Circuit or Sprint, Red vs
-- Blue with teams balanced by level. Points by finishing position decide
-- the winning team.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Maps = require(Shared.Maps)
local RaceTypes = require(Shared.RaceTypes)

local DataService = require(script.Parent.DataService)
local RaceSession = require(script.Parent.RaceSession)
local Sessions = require(script.Parent.Sessions)
local LobbyBuilder = require(script.Parent.LobbyBuilder)

local MatchService = {}
MatchService.OnChanged = nil -- set by RaceService to re-broadcast lobby state

local queues = {} -- [size] = { player, ... } in join order
for _, size in Config.TeamSizes do
	queues[size] = {}
end

local function changed()
	for _, size in Config.TeamSizes do
		LobbyBuilder.SetTeamPad(size, #queues[size], size * 2)
	end
	if MatchService.OnChanged then
		MatchService.OnChanged()
	end
end

function MatchService.QueueOf(player)
	for size, list in queues do
		if table.find(list, player) then
			return size
		end
	end
	return nil
end

function MatchService.Leave(player)
	local was = false
	for _, list in queues do
		local idx = table.find(list, player)
		if idx then
			table.remove(list, idx)
			was = true
		end
	end
	if was then
		changed()
	end
	return was
end

function MatchService.Join(player, size)
	if type(size) ~= "number" or not queues[size] then
		return false, "Unknown match size."
	end
	if Sessions.IsRacing(player) then
		return false, "Finish your current race first."
	end
	local current = MatchService.QueueOf(player)
	if current == size then
		return true, string.format("You're already in the %dv%d queue.", size, size)
	end
	MatchService.Leave(player)
	table.insert(queues[size], player)
	changed()
	return true,
		string.format("Joined the %dv%d queue (%d/%d). You can free drive while you wait!", size, size, #queues[size], size * 2)
end

-- For the client: { { size = 1, count = n, needed = 2, members = {userIds} }, ... }
function MatchService.Snapshot()
	local out = {}
	for _, size in Config.TeamSizes do
		local members = {}
		for _, player in queues[size] do
			table.insert(members, player.UserId)
		end
		table.insert(out, { size = size, count = #queues[size], needed = size * 2, members = members })
	end
	return out
end

local function startMatch(size)
	local list = queues[size]
	local players = {}
	for _ = 1, size * 2 do
		table.insert(players, table.remove(list, 1))
	end
	changed()

	local mapId = Maps.Order[math.random(1, #Maps.Order)]
	local raceType = math.random() < 0.5 and "Circuit" or "Sprint"
	local label = string.format("%dv%d", size, size)
	for _, player in players do
		DataService.Notify(
			player,
			string.format(
				"%s match found! %s on %s. Loading...",
				label,
				RaceTypes.List[raceType].name,
				Maps.List[mapId].name
			),
			"success"
		)
	end
	task.wait(Config.MATCH_START_DELAY)

	-- Pull anyone out of free drive (their character goes straight to the grid).
	local ready = {}
	for _, player in players do
		if player.Parent then
			local current = Sessions.Get(player)
			if current and current.raceType == "FreeDrive" then
				current:RemovePlayer(player, true)
			end
			if not Sessions.Get(player) then
				table.insert(ready, player)
			end
		end
	end
	if #ready < 2 then
		for _, player in ready do
			DataService.Notify(player, "Not enough players stayed for the match. You're back in the queue.", "error")
			table.insert(queues[size], 1, player)
		end
		changed()
		return
	end

	local session = RaceSession.new({
		mapId = mapId,
		raceType = raceType,
		players = ready,
		teams = true,
		label = label,
	})
	session:Run()
end

local function isValid(player)
	if not player.Parent or Sessions.IsRacing(player) then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

function MatchService.Init()
	Players.PlayerRemoving:Connect(function(player)
		MatchService.Leave(player)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, size in Config.TeamSizes do
				local list = queues[size]
				for i = #list, 1, -1 do
					if not list[i].Parent then
						table.remove(list, i)
					end
				end
				-- Only count players who can actually start now.
				local validCount = 0
				for _, player in list do
					if isValid(player) then
						validCount += 1
					end
				end
				if validCount >= size * 2 then
					-- Move players who can't start right now to the back.
					table.sort(list, function(a, b)
						return isValid(a) and not isValid(b)
					end)
					task.spawn(function()
						local ok, err = pcall(startMatch, size)
						if not ok then
							warn("[MatchService] Match error:", err)
						end
					end)
				end
			end
		end
	end)
	changed()
end

return MatchService
