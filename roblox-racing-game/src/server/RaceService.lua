-- The lobby race round: intermission + map / race-type vote -> a
-- RaceSession with everyone in the race queue -> back to intermission.
-- Also broadcasts lobby state (votes, team queues, free-drive counts).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Maps = require(Shared.Maps)
local RaceTypes = require(Shared.RaceTypes)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local RaceSession = require(script.Parent.RaceSession)
local Sessions = require(script.Parent.Sessions)
local MatchService = require(script.Parent.MatchService)
local FreeDriveService = require(script.Parent.FreeDriveService)

local RaceService = {}

local state = {
	phase = "Waiting",
	timeLeft = 0,
	mapId = nil,
	raceType = nil,
	laps = 0,
}
local votes = {} -- [player] = mapId
local typeVotes = {} -- [player] = raceType
local queued = {} -- [player] = bool
local session = nil -- current lobby-round RaceSession

local PHASE_TEXT = {
	Waiting = "Waiting for racers",
	Intermission = "Vote for the next race!",
	Loading = "Loading track...",
	Countdown = "Get ready!",
	Racing = "Race in progress",
	Results = "Race finished",
}

local function isEligible(player)
	if not queued[player] or not DataService.Get(player) then
		return false
	end
	-- Busy elsewhere: racing, free driving, or waiting for a team match.
	if Sessions.Get(player) or MatchService.QueueOf(player) then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character.PrimaryPart ~= nil
end

local function eligiblePlayers()
	local list = {}
	for _, player in Players:GetPlayers() do
		if isEligible(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function tally(tbl)
	local counts = {}
	for player, choice in tbl do
		if player.Parent then
			counts[choice] = (counts[choice] or 0) + 1
		end
	end
	return counts
end

local function broadcast()
	local payload = {
		phase = state.phase,
		timeLeft = math.max(0, math.ceil(state.timeLeft)),
		mapId = state.mapId,
		raceType = state.raceType,
		laps = state.laps,
		votes = tally(votes),
		typeVotes = tally(typeVotes),
		queuedCount = #eligiblePlayers(),
		teamQueues = MatchService.Snapshot(),
		freeDrive = FreeDriveService.Counts(),
	}
	Remotes.Event("RaceState"):FireAllClients(payload)

	local mapName = state.mapId and Maps.List[state.mapId].name or ""
	local typeName = state.raceType and RaceTypes.List[state.raceType].name or ""
	local main, sub = PHASE_TEXT[state.phase] or state.phase, ""
	if state.phase == "Intermission" then
		main = string.format("Starts in %d", payload.timeLeft)
		sub = string.format("%d racer(s) ready • vote with the VOTE panel", payload.queuedCount)
	elseif state.phase == "Waiting" then
		sub = "Turn on RACE QUEUE to join"
	elseif state.phase == "Racing" then
		main = mapName
		sub = string.format("%s in progress • %d:%02d left", typeName, payload.timeLeft // 60, payload.timeLeft % 60)
	elseif state.phase == "Loading" or state.phase == "Countdown" then
		sub = typeName .. " • " .. mapName
	end
	LobbyBuilder.SetStatus(main, sub)
end
RaceService.Broadcast = broadcast

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function RaceService.SetQueued(player, value)
	queued[player] = value == true
	broadcast()
	return true, queued[player] and "You are in the race queue." or "You left the race queue."
end

function RaceService.IsQueued(player)
	return queued[player] == true
end

local function votingOpen()
	return state.phase == "Intermission" or state.phase == "Waiting"
end

function RaceService.Vote(player, mapId)
	if not votingOpen() then
		return false, "Voting is closed."
	end
	if type(mapId) ~= "string" or not Maps.List[mapId] then
		return false, "Unknown map."
	end
	votes[player] = mapId
	broadcast()
	return true
end

function RaceService.VoteType(player, raceType)
	if not votingOpen() then
		return false, "Voting is closed."
	end
	if type(raceType) ~= "string" or not table.find(RaceTypes.Order, raceType) then
		return false, "Unknown race type."
	end
	typeVotes[player] = raceType
	broadcast()
	return true
end

---------------------------------------------------------------------------
-- Round loop
---------------------------------------------------------------------------

local function pickFrom(order, choices, default)
	local counts = tally(choices)
	local best, bestCount = {}, 0
	for _, id in order do
		local c = counts[id] or 0
		if c > bestCount then
			best, bestCount = { id }, c
		elseif c == bestCount and c > 0 then
			table.insert(best, id)
		end
	end
	if #best == 0 then
		return default or order[math.random(1, #order)]
	end
	return best[math.random(1, #best)]
end

local function runRound()
	votes = {}
	typeVotes = {}
	state.mapId = nil
	state.raceType = nil
	state.laps = 0
	state.timeLeft = Config.INTERMISSION_TIME
	while true do
		if #eligiblePlayers() < Config.MIN_RACERS then
			state.phase = "Waiting"
			state.timeLeft = Config.INTERMISSION_TIME
		else
			state.phase = "Intermission"
		end
		broadcast()
		if state.phase == "Intermission" and state.timeLeft <= 0 then
			break
		end
		task.wait(1)
		if state.phase == "Intermission" then
			state.timeLeft -= 1
		end
	end

	local players = eligiblePlayers()
	local mapId = pickFrom(Maps.Order, votes)
	local raceType = pickFrom(RaceTypes.Order, typeVotes, "Circuit")
	session = RaceSession.new({
		mapId = mapId,
		raceType = raceType,
		players = players,
		onUpdate = function(s)
			state.phase = s.phase
			state.timeLeft = s.timeLeft
			state.laps = s.laps
			broadcast()
		end,
	})
	state.mapId = mapId
	state.raceType = session.raceType
	session:Run()
	session = nil
end

function RaceService.Init()
	Players.PlayerAdded:Connect(function(player)
		queued[player] = true
	end)
	for _, player in Players:GetPlayers() do
		queued[player] = true
	end
	Players.PlayerRemoving:Connect(function(player)
		queued[player] = nil
		votes[player] = nil
		typeVotes[player] = nil
		local s = Sessions.Get(player)
		if s then
			s:RemovePlayer(player)
		end
	end)

	MatchService.OnChanged = broadcast
	FreeDriveService.OnChanged = broadcast

	task.spawn(function()
		while true do
			local ok, err = pcall(runRound)
			if not ok then
				warn("[RaceService] Round error:", err)
				if session then
					pcall(session.Cleanup, session)
					session = nil
				end
				task.wait(3)
			end
		end
	end)
end

return RaceService
