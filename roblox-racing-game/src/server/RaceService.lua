-- Round-based race loop: intermission + map vote -> load track -> grid
-- & countdown -> race with checkpoints / laps / positions -> results &
-- rewards -> back to the lobby.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Maps = require(Shared.Maps)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local CarService = require(script.Parent.CarService)
local TrackBuilder = require(script.Parent.TrackBuilder)
local LobbyBuilder = require(script.Parent.LobbyBuilder)

local RaceService = {}

local state = {
	phase = "Waiting",
	timeLeft = 0,
	mapId = nil,
	laps = 0,
}
local votes = {} -- [player] = mapId
local queued = {} -- [player] = bool
local racers = {} -- [player] = racer record
local track -- current TrackBuilder result
local startClock = 0
local deadline = 0
local finishCount = 0

local PHASE_TEXT = {
	Waiting = "Waiting for racers",
	Intermission = "Vote for the next map!",
	Loading = "Loading track...",
	Countdown = "Get ready!",
	Racing = "Race in progress",
	Results = "Race finished",
}

local function isEligible(player)
	if not queued[player] or not DataService.Get(player) then
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

local function voteCounts()
	local counts = {}
	for player, mapId in votes do
		if player.Parent then
			counts[mapId] = (counts[mapId] or 0) + 1
		end
	end
	return counts
end

local function broadcast()
	local participants = {}
	for player in racers do
		table.insert(participants, player.UserId)
	end
	local payload = {
		phase = state.phase,
		timeLeft = math.max(0, math.ceil(state.timeLeft)),
		mapId = state.mapId,
		laps = state.laps,
		votes = voteCounts(),
		participants = participants,
		queuedCount = #eligiblePlayers(),
	}
	Remotes.Event("RaceState"):FireAllClients(payload)

	local mapName = state.mapId and Maps.List[state.mapId].name or ""
	local main, sub = PHASE_TEXT[state.phase] or state.phase, ""
	if state.phase == "Intermission" then
		main = string.format("Starts in %d", payload.timeLeft)
		sub = string.format("%d racer(s) ready • vote with the MAP VOTE panel", payload.queuedCount)
	elseif state.phase == "Waiting" then
		sub = "Turn on RACE QUEUE to join"
	elseif state.phase == "Racing" then
		main = mapName
		sub = string.format("Race in progress • %d:%02d left", payload.timeLeft // 60, payload.timeLeft % 60)
	elseif state.phase == "Loading" or state.phase == "Countdown" then
		sub = mapName
	end
	LobbyBuilder.SetStatus(main, sub)
end

---------------------------------------------------------------------------
-- Public API (called from Main request handlers)
---------------------------------------------------------------------------

function RaceService.SetQueued(player, value)
	queued[player] = value == true
	return true, queued[player] and "You are in the race queue." or "You left the race queue."
end

function RaceService.IsQueued(player)
	return queued[player] == true
end

function RaceService.Vote(player, mapId)
	if state.phase ~= "Intermission" and state.phase ~= "Waiting" then
		return false, "Voting is closed."
	end
	if type(mapId) ~= "string" or not Maps.List[mapId] then
		return false, "Unknown map."
	end
	votes[player] = mapId
	broadcast()
	return true
end

function RaceService.IsRacing(player)
	return racers[player] ~= nil
end

function RaceService.GetRespawn(player)
	local racer = racers[player]
	if racer then
		return racer.respawnCF
	end
	return nil
end

---------------------------------------------------------------------------
-- Race internals
---------------------------------------------------------------------------

local function ordinal(n)
	local suffix = "th"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "st", "nd", "rd" })[n % 10] or "th"
	end
	return n .. suffix
end
RaceService.Ordinal = ordinal

local function computeStandings()
	local list = {}
	for player, racer in racers do
		local score
		if racer.finished then
			score = 1e9 - racer.place
		elseif racer.dnf then
			score = -1e9
		else
			local cp = track.checkpoints[racer.nextCP]
			score = racer.cpPassed * 100000 - (cp.cf.Position - racer.lastPos).Magnitude
		end
		table.insert(list, { player = player, racer = racer, score = score })
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	for i, entry in list do
		entry.racer.position = i
	end
	return list
end

local function finishRacer(player, racer)
	finishCount += 1
	racer.finished = true
	racer.place = finishCount
	racer.finishTime = os.clock() - startClock
	Remotes.Event("Checkpoint"):FireClient(player, {
		finished = true,
		place = racer.place,
		time = racer.finishTime,
	})
	if finishCount == 1 then
		deadline = math.min(deadline, os.clock() + Config.FINISH_GRACE)
		for other in racers do
			if other ~= player then
				DataService.Notify(
					other,
					string.format("%s won! %d seconds left to finish.", player.DisplayName, Config.FINISH_GRACE),
					"info"
				)
			end
		end
	end
end

local function onCheckpoint(player, racer, cp)
	racer.cpPassed += 1
	racer.respawnCF = cp.spawnCF
	if racer.nextCP == 1 then
		racer.lap += 1
		if racer.lap > state.laps then
			finishRacer(player, racer)
			return
		end
	end
	racer.nextCP = racer.nextCP % #track.checkpoints + 1
	Remotes.Event("Checkpoint"):FireClient(player, {
		lap = math.max(racer.lap, 1),
		laps = state.laps,
		newLap = racer.nextCP == 2 and racer.lap > 1,
	})
end

local function checkCrossings()
	for player, racer in racers do
		if not racer.finished and not racer.dnf then
			local chassis = racer.model.Parent and racer.model.PrimaryPart
			if not chassis then
				racer.dnf = true
			else
				local pos = chassis.Position
				local cp = track.checkpoints[racer.nextCP]
				local a = cp.cf:PointToObjectSpace(racer.lastPos)
				local b = cp.cf:PointToObjectSpace(pos)
				-- Crossing the gate plane moving forward (local +Z -> -Z).
				if a.Z > 0 and b.Z <= 0 then
					local t = a.Z / (a.Z - b.Z)
					local hit = a:Lerp(b, t)
					if math.abs(hit.X) <= cp.halfWidth and math.abs(hit.Y) <= 25 then
						onCheckpoint(player, racer, cp)
					end
				end
				racer.lastPos = pos
			end
		end
	end
end

local function sendUpdates(standings)
	local board = {}
	for i, entry in standings do
		if i > 8 then
			break
		end
		table.insert(board, {
			name = entry.player.DisplayName,
			userId = entry.player.UserId,
			finished = entry.racer.finished,
			dnf = entry.racer.dnf,
		})
	end
	local elapsed = os.clock() - startClock
	for _, entry in standings do
		local player, racer = entry.player, entry.racer
		if player.Parent then
			Remotes.Event("RaceUpdate"):FireClient(player, {
				position = racer.position,
				total = #standings,
				lap = math.clamp(racer.lap, 1, state.laps),
				laps = state.laps,
				elapsed = racer.finished and racer.finishTime or elapsed,
				timeLeft = math.max(0, deadline - os.clock()),
				standings = board,
			})
		end
	end
end

local function allDone()
	for _, racer in racers do
		if not racer.finished and not racer.dnf then
			return false
		end
	end
	return true
end

local function awardRewards(standings)
	local R = Config.Rewards
	local total = 0
	for _, entry in standings do
		if entry.racer.finished then
			total += 1
		end
	end
	local results = {}
	for _, entry in standings do
		local player, racer = entry.player, entry.racer
		local coins, xp, newBest, xpCoins = 0, 0, false, 0
		if racer.finished then
			local beaten = #standings - racer.place
			coins = R.base + R.perLap * state.laps + R.perBeaten * beaten + (R.placeBonus[racer.place] or 0)
			if #standings == 1 then
				xp = R.xpSolo
			else
				xp = R.xpByPlace[racer.place] or R.xpFinish
			end
		else
			coins, xp = R.dnfCoins, R.dnfXP
		end

		local data = player.Parent and DataService.Get(player)
		if data then
			if racer.finished then
				local best = data.bestTimes[state.mapId]
				if not best or racer.finishTime < best then
					data.bestTimes[state.mapId] = racer.finishTime
					if best then
						newBest = true
						coins += R.newBestCoins
					end
				end
			end
			if DataService.HasPass(player, "VIP") then
				coins *= 2
			end
			if DataService.HasPass(player, "DoubleXP") then
				xp *= 2
			end
			data.stats.races += 1
			if racer.finished and racer.place == 1 and #standings >= 2 then
				data.stats.wins += 1
			end
			if racer.finished and racer.place <= 3 and #standings >= 2 then
				data.stats.podiums += 1
			end
			DataService.AddCoins(player, coins)
			xpCoins = DataService.AddXP(player, xp)
			DataService.Push(player)
		end

		table.insert(results, {
			userId = player.UserId,
			name = player.DisplayName,
			place = racer.finished and racer.place or nil,
			time = racer.finished and racer.finishTime or nil,
			coins = coins,
			xp = xp,
			xpCoins = xpCoins, -- XP converted to coins at the level cap
			newBest = newBest,
		})
	end
	return results
end

local function pickMap()
	local counts = voteCounts()
	local best, bestCount = {}, 0
	for _, mapId in Maps.Order do
		local c = counts[mapId] or 0
		if c > bestCount then
			best, bestCount = { mapId }, c
		elseif c == bestCount then
			table.insert(best, mapId)
		end
	end
	return best[math.random(1, #best)]
end

local function cleanupRace()
	for player in racers do
		CarService.Despawn(player)
		if player.Parent then
			task.spawn(function()
				pcall(function()
					player:LoadCharacter()
				end)
			end)
		end
	end
	racers = {}
	if track then
		track.model:Destroy()
		track = nil
	end
	state.mapId = nil
	state.laps = 0
end

local function runRound()
	-- Intermission / voting ------------------------------------------------
	votes = {}
	state.mapId = nil
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

	-- Load ---------------------------------------------------------------------
	local mapId = pickMap()
	local map = Maps.List[mapId]
	state.phase = "Loading"
	state.mapId = mapId
	state.laps = map.laps
	broadcast()

	track = TrackBuilder.Build(map, Config.TRACK_ORIGIN)
	track.model.Name = "ActiveTrack"
	track.model.Parent = workspace
	task.wait(2)

	local list = eligiblePlayers()
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	for i, player in list do
		local slot = track.grid[i] or (track.grid[#track.grid] * CFrame.new(0, 0, 12 * (i - #track.grid)))
		local model = CarService.Spawn(player, slot, "race", true, { KillY = track.killY, MapId = mapId })
		if model then
			racers[player] = {
				model = model,
				lap = 0,
				nextCP = 1,
				cpPassed = 0,
				finished = false,
				dnf = false,
				lastPos = model.PrimaryPart.Position,
				respawnCF = slot,
				position = i,
			}
		end
	end

	if next(racers) == nil then
		cleanupRace()
		return
	end

	-- Countdown -----------------------------------------------------------------
	state.phase = "Countdown"
	for n = Config.COUNTDOWN, 1, -1 do
		state.timeLeft = n
		broadcast()
		for player in racers do
			Remotes.Event("Countdown"):FireClient(player, n)
		end
		task.wait(1)
	end
	for player in racers do
		Remotes.Event("Countdown"):FireClient(player, 0)
		CarService.Release(player)
	end

	-- Race ------------------------------------------------------------------------
	state.phase = "Racing"
	startClock = os.clock()
	deadline = startClock + Config.MAX_RACE_TIME
	finishCount = 0
	local heartbeat = RunService.Heartbeat:Connect(checkCrossings)
	local lastBroadcast = 0
	while os.clock() < deadline and not allDone() do
		local standings = computeStandings()
		sendUpdates(standings)
		state.timeLeft = deadline - os.clock()
		if os.clock() - lastBroadcast >= 1 then
			lastBroadcast = os.clock()
			broadcast()
		end
		task.wait(0.25)
	end
	heartbeat:Disconnect()

	-- Results -----------------------------------------------------------------------
	state.phase = "Results"
	state.timeLeft = Config.RESULTS_TIME
	local standings = computeStandings()
	local results = awardRewards(standings)
	for player in racers do
		if player.Parent then
			Remotes.Event("RaceResults"):FireClient(player, { mapId = state.mapId, results = results })
		end
	end
	broadcast()
	task.wait(Config.RESULTS_TIME)
	cleanupRace()
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
		local racer = racers[player]
		if racer then
			racer.dnf = true
			racers[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(runRound)
			if not ok then
				warn("[RaceService] Round error:", err)
				pcall(cleanupRace)
				task.wait(3)
			end
		end
	end)
end

return RaceService
