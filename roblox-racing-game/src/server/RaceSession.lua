-- One race (or free-drive) on its own copy of a track. Several sessions can
-- run at the same time: the lobby round, team matches and free-drive
-- circuits each get a separate track "slot".
--
-- Race flow: build track -> grid -> countdown -> checkpoints / laps /
-- positions (plus eliminations or team points) -> results & rewards ->
-- everyone back to the lobby.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Maps = require(Shared.Maps)
local RaceTypes = require(Shared.RaceTypes)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local CarService = require(script.Parent.CarService)
local TrackBuilder = require(script.Parent.TrackBuilder)
local Sessions = require(script.Parent.Sessions)

local RaceSession = {}
RaceSession.__index = RaceSession

local usedSlots = {}

local function tracksFolder()
	local folder = workspace:FindFirstChild("Tracks")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Tracks"
		folder.Parent = workspace
	end
	return folder
end

local function allocSlot()
	local slot = 0
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	return slot
end

local function reloadCharacter(player)
	if player.Parent then
		task.spawn(function()
			pcall(function()
				player:LoadCharacter()
			end)
		end)
	end
end

-- opts: mapId, raceType, players, teams (bool), label, onUpdate(session)
function RaceSession.new(opts)
	local map = Maps.List[opts.mapId]
	local players = opts.players or {}
	local raceType = opts.raceType == "FreeDrive" and "FreeDrive" or RaceTypes.Resolve(opts.raceType, #players)
	local self = setmetatable({
		mapId = opts.mapId,
		map = map,
		raceType = raceType,
		label = opts.label,
		teams = opts.teams == true,
		onUpdate = opts.onUpdate,
		players = players,
		racers = {},
		phase = "Loading",
		timeLeft = 0,
		laps = raceType == "FreeDrive" and 0 or RaceTypes.Laps(raceType, map, #players),
		finishCount = 0,
		startClock = 0,
		deadline = math.huge,
		eliminatedLaps = {},
		slot = allocSlot(),
	}, RaceSession)
	return self
end

function RaceSession:SetPhase(phase, timeLeft)
	self.phase = phase
	self.timeLeft = timeLeft or self.timeLeft
	if self.onUpdate then
		self.onUpdate(self)
	end
end

function RaceSession:BuildTrack()
	local origin = Config.TRACK_ORIGIN + Vector3.new(self.slot * Config.TRACK_SLOT_SPACING, 0, 0)
	local track = TrackBuilder.Build(self.map, origin)
	track.model.Name = "Track_" .. self.slot
	track.model.Parent = tracksFolder()
	self.track = track
end

function RaceSession:SpawnRacer(player, gridIndex, anchored, team)
	local grid = self.track.grid
	local cf = grid[gridIndex] or (grid[#grid] * CFrame.new(0, 0, 12 * (gridIndex - #grid)))
	local free = self.raceType == "FreeDrive"
	local extra = { KillY = self.track.killY, MapId = self.mapId, RaceType = self.raceType, Team = team }
	local onExit = free and function()
		self:RemovePlayer(player)
	end or nil
	local model = CarService.Spawn(player, cf, free and "free" or "race", anchored, extra, onExit)
	if not model then
		return nil
	end
	local racer = {
		model = model,
		name = player.DisplayName,
		team = team,
		lap = 0,
		nextCP = 1,
		cpPassed = 0,
		finished = false,
		dnf = false,
		eliminated = false,
		lastPos = model.PrimaryPart.Position,
		respawnCF = cf,
		position = gridIndex,
	}
	self.racers[player] = racer
	Sessions.Set(player, self)
	return racer
end

function RaceSession:GetRespawn(player)
	local racer = self.racers[player]
	return racer and racer.respawnCF
end

-- Player left the game, left free drive, or was pulled into a team match.
-- keepCharacter: don't send them back to the lobby (they're going somewhere else).
function RaceSession:RemovePlayer(player, keepCharacter)
	local racer = self.racers[player]
	if not racer then
		return
	end
	local ours = Sessions.Get(player) == self
	Sessions.Clear(player, self)
	if CarService.Get(player) == racer.model then
		CarService.Despawn(player)
	end
	if self.raceType == "FreeDrive" then
		self.racers[player] = nil
		if ours and not keepCharacter then
			reloadCharacter(player)
		end
	elseif not racer.finished and not racer.eliminated then
		racer.dnf = true
	end
end

---------------------------------------------------------------------------
-- Checkpoints, laps, eliminations
---------------------------------------------------------------------------
function RaceSession:ActiveRacers()
	local list = {}
	for player, racer in self.racers do
		if not racer.finished and not racer.dnf and not racer.eliminated then
			table.insert(list, { player = player, racer = racer })
		end
	end
	return list
end

function RaceSession:Finish(player, racer)
	self.finishCount += 1
	racer.finished = true
	racer.place = self.finishCount
	racer.finishTime = os.clock() - self.startClock
	Remotes.Event("Checkpoint"):FireClient(player, { finished = true, place = racer.place, time = racer.finishTime })
	if self.finishCount == 1 then
		self.deadline = math.min(self.deadline, os.clock() + Config.FINISH_GRACE)
		for other, otherRacer in self.racers do
			if other ~= player and other.Parent and not otherRacer.finished and not otherRacer.eliminated then
				DataService.Notify(
					other,
					string.format("%s won! %d seconds left to finish.", player.DisplayName, Config.FINISH_GRACE),
					"info"
				)
			end
		end
	end
end

function RaceSession:Eliminate(player, racer)
	racer.eliminated = true
	racer.place = #self:ActiveRacers() + 1
	Remotes.Event("Checkpoint"):FireClient(player, { eliminated = true, place = racer.place })
	DataService.Notify(player, string.format("ELIMINATED in %d%s place! Results come at the end of the race.", racer.place, ({ "st", "nd", "rd" })[racer.place] or "th"), "error")
	for other in self.racers do
		if other ~= player and other.Parent then
			DataService.Notify(other, racer.name .. " was eliminated!", "error")
		end
	end
	-- Send them back to the lobby; they still get results at the end.
	Sessions.Clear(player, self)
	if CarService.Get(player) == racer.model then
		CarService.Despawn(player)
	end
	reloadCharacter(player)
end

-- When the leader completes lap `lap`, the last active racer is knocked out.
function RaceSession:EliminationCheck(lap)
	if self.eliminatedLaps[lap] then
		return
	end
	local active = self:ActiveRacers()
	if #active <= 2 then
		return
	end
	self.eliminatedLaps[lap] = true
	local standings = self:ComputeStandings()
	for i = #standings, 1, -1 do
		local entry = standings[i]
		local r = entry.racer
		if not r.finished and not r.dnf and not r.eliminated then
			self:Eliminate(entry.player, r)
			return
		end
	end
end

function RaceSession:OnCheckpoint(player, racer, cp)
	racer.cpPassed += 1
	racer.respawnCF = cp.spawnCF
	if racer.nextCP == 1 then
		if self.raceType == "FreeDrive" then
			local now = os.clock()
			if racer.lapStart then
				local lapTime = now - racer.lapStart
				local best = racer.bestLap == nil or lapTime < racer.bestLap
				racer.bestLap = best and lapTime or racer.bestLap
				Remotes.Event("Checkpoint"):FireClient(player, { freeLap = lapTime, best = best })
			end
			racer.lapStart = now
		else
			racer.lap += 1
			if racer.lap > self.laps then
				self:Finish(player, racer)
				return
			end
			if self.raceType == "Elimination" and racer.lap > 1 then
				self:EliminationCheck(racer.lap - 1)
			end
		end
	end
	racer.nextCP = racer.nextCP % #self.track.checkpoints + 1
	if self.raceType ~= "FreeDrive" then
		Remotes.Event("Checkpoint"):FireClient(player, {
			lap = math.max(racer.lap, 1),
			laps = self.laps,
			newLap = racer.nextCP == 2 and racer.lap > 1,
		})
	end
end

function RaceSession:CheckCrossings()
	for player, racer in self.racers do
		if racer.finished or racer.dnf or racer.eliminated then
			continue
		end
		local chassis = racer.model.Parent and racer.model.PrimaryPart
		if not chassis then
			-- Car is gone (driver died or left).
			if self.raceType == "FreeDrive" then
				task.defer(self.RemovePlayer, self, player)
			else
				racer.dnf = true
				Sessions.Clear(player, self)
			end
			continue
		end
		local pos = chassis.Position
		local cp = self.track.checkpoints[racer.nextCP]
		local a = cp.cf:PointToObjectSpace(racer.lastPos)
		local b = cp.cf:PointToObjectSpace(pos)
		-- Crossing the gate plane moving forward (local +Z -> -Z).
		if a.Z > 0 and b.Z <= 0 then
			local t = a.Z / (a.Z - b.Z)
			local hit = a:Lerp(b, t)
			if math.abs(hit.X) <= cp.halfWidth and math.abs(hit.Y) <= 25 then
				self:OnCheckpoint(player, racer, cp)
			end
		end
		racer.lastPos = pos
	end
end

---------------------------------------------------------------------------
-- Standings, team points, rewards
---------------------------------------------------------------------------
function RaceSession:ComputeStandings()
	local list = {}
	for player, racer in self.racers do
		local score
		if racer.finished then
			score = 3e9 - racer.place
		elseif racer.dnf then
			score = -3e9
		elseif racer.eliminated then
			score = -1e9 - racer.place
		else
			local cp = self.track.checkpoints[racer.nextCP]
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

-- Points per team from the given standings, plus the winning team.
function RaceSession:TeamScores(standings)
	if not self.teams then
		return nil
	end
	local scores = { Red = 0, Blue = 0 }
	local best = {}
	for i, entry in standings do
		local r = entry.racer
		if r.team and not r.dnf then
			scores[r.team] += Config.TeamPoints[i] or 0
			best[r.team] = best[r.team] or i
		end
	end
	local winner
	if scores.Red ~= scores.Blue then
		winner = scores.Red > scores.Blue and "Red" or "Blue"
	else
		winner = (best.Red or math.huge) < (best.Blue or math.huge) and "Red" or "Blue"
	end
	return { Red = scores.Red, Blue = scores.Blue, winner = winner }
end

function RaceSession:SendUpdates(standings)
	local board = {}
	for i, entry in standings do
		if i > 10 then
			break
		end
		table.insert(board, {
			name = entry.player.DisplayName,
			userId = entry.player.UserId,
			finished = entry.racer.finished,
			dnf = entry.racer.dnf,
			eliminated = entry.racer.eliminated,
			team = entry.racer.team,
		})
	end
	local teamScores = self:TeamScores(standings)
	local elapsed = os.clock() - self.startClock
	for _, entry in standings do
		local player, racer = entry.player, entry.racer
		if player.Parent and Sessions.Get(player) == self then
			Remotes.Event("RaceUpdate"):FireClient(player, {
				position = racer.position,
				total = #standings,
				lap = math.clamp(racer.lap, 1, self.laps),
				laps = self.laps,
				elapsed = racer.finished and racer.finishTime or elapsed,
				timeLeft = math.max(0, self.deadline - os.clock()),
				raceType = self.raceType,
				label = self.label,
				team = racer.team,
				teamScores = teamScores,
				standings = board,
			})
		end
	end
end

function RaceSession:AllDone()
	for _, racer in self.racers do
		if not racer.finished and not racer.dnf and not racer.eliminated then
			return false
		end
	end
	return true
end

function RaceSession:AwardRewards(standings, teamScores)
	local R = Config.Rewards
	local results = {}
	for _, entry in standings do
		local player, racer = entry.player, entry.racer
		local coins, xp, newBest, xpCoins = 0, 0, false, 0
		if racer.place then
			local beaten = #standings - racer.place
			coins = R.base + R.perLap * self.laps + R.perBeaten * beaten + (R.placeBonus[racer.place] or 0)
			if #standings == 1 then
				xp = R.xpSolo
			else
				xp = R.xpByPlace[racer.place] or R.xpFinish
			end
		else
			coins, xp = R.dnfCoins, R.dnfXP
		end
		local wonTeam = teamScores ~= nil and racer.team == teamScores.winner
		if wonTeam then
			coins += R.teamWinCoins
			xp += R.teamWinXP
		end

		local data = player.Parent and DataService.Get(player)
		if data then
			if racer.finished then
				local key = self.mapId .. (self.raceType == "Sprint" and ":Sprint" or "")
				local best = data.bestTimes[key]
				if not best or racer.finishTime < best then
					data.bestTimes[key] = racer.finishTime
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
			if racer.place == 1 and #standings >= 2 then
				data.stats.wins += 1
			end
			if racer.place and racer.place <= 3 and #standings >= 2 then
				data.stats.podiums += 1
			end
			DataService.AddCoins(player, coins)
			xpCoins = DataService.AddXP(player, xp)
			DataService.Push(player)
		end

		table.insert(results, {
			userId = player.UserId,
			name = player.DisplayName,
			place = racer.place,
			time = racer.finished and racer.finishTime or nil,
			eliminated = racer.eliminated,
			team = racer.team,
			teamWin = wonTeam,
			coins = coins,
			xp = xp,
			xpCoins = xpCoins,
			newBest = newBest,
		})
	end
	return results
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function RaceSession:Cleanup()
	for player, racer in self.racers do
		if Sessions.Get(player) == self then
			Sessions.Clear(player, self)
			if CarService.Get(player) == racer.model then
				CarService.Despawn(player)
			end
			reloadCharacter(player)
		end
	end
	self.racers = {}
	if self.track then
		self.track.model:Destroy()
		self.track = nil
	end
	usedSlots[self.slot] = nil
	self.closed = true
end

-- Orders players for the grid. Teams are balanced by level (snake draft).
function RaceSession:GridOrder()
	local list = {}
	for _, player in self.players do
		if player.Parent then
			table.insert(list, player)
		end
	end
	local teamOf = {}
	if self.teams then
		table.sort(list, function(a, b)
			local da, db = DataService.Get(a), DataService.Get(b)
			return (da and da.level or 0) > (db and db.level or 0)
		end)
		for i, player in list do
			local pick = (i - 1) % 4
			teamOf[player] = (pick == 0 or pick == 3) and "Red" or "Blue"
		end
	else
		for i = #list, 2, -1 do
			local j = math.random(1, i)
			list[i], list[j] = list[j], list[i]
		end
	end
	return list, teamOf
end

function RaceSession:Run()
	self:SetPhase("Loading")
	self:BuildTrack()
	task.wait(2)

	local list, teamOf = self:GridOrder()
	for i, player in list do
		self:SpawnRacer(player, i, true, teamOf[player])
	end
	if next(self.racers) == nil then
		self:Cleanup()
		return
	end
	self.laps = RaceTypes.Laps(self.raceType, self.map, #list)

	for n = Config.COUNTDOWN, 1, -1 do
		self:SetPhase("Countdown", n)
		for player in self.racers do
			if player.Parent then
				Remotes.Event("Countdown"):FireClient(player, n)
			end
		end
		task.wait(1)
	end
	for player in self.racers do
		if player.Parent then
			Remotes.Event("Countdown"):FireClient(player, 0)
			CarService.Release(player)
		end
	end

	self.startClock = os.clock()
	self.deadline = self.startClock + Config.MAX_RACE_TIME
	self:SetPhase("Racing", Config.MAX_RACE_TIME)
	local heartbeat = RunService.Heartbeat:Connect(function()
		self:CheckCrossings()
	end)
	local lastTick = 0
	while os.clock() < self.deadline and not self:AllDone() do
		-- Elimination: the last car standing wins.
		if self.raceType == "Elimination" and self.finishCount == 0 then
			local active = self:ActiveRacers()
			if #active == 1 and next(self.eliminatedLaps) ~= nil then
				self:Finish(active[1].player, active[1].racer)
			end
		end
		self:SendUpdates(self:ComputeStandings())
		self.timeLeft = self.deadline - os.clock()
		if os.clock() - lastTick >= 1 then
			lastTick = os.clock()
			self:SetPhase("Racing")
		end
		task.wait(0.25)
	end
	heartbeat:Disconnect()

	local standings = self:ComputeStandings()
	local teamScores = self:TeamScores(standings)
	local results = self:AwardRewards(standings, teamScores)
	for player in self.racers do
		if player.Parent then
			Remotes.Event("RaceResults"):FireClient(player, {
				mapId = self.mapId,
				raceType = self.raceType,
				label = self.label,
				teams = teamScores,
				results = results,
			})
		end
	end
	self:SetPhase("Results", Config.RESULTS_TIME)
	task.wait(Config.RESULTS_TIME)
	self:Cleanup()
end

-- Free drive: stays open while anyone is driving it.
function RaceSession:RunFreeDrive()
	self:BuildTrack()
	self:SetPhase("FreeDrive")
	self.startClock = os.clock()
	local heartbeat = RunService.Heartbeat:Connect(function()
		self:CheckCrossings()
	end)
	local emptySince = nil
	while true do
		task.wait(1)
		if next(self.racers) == nil then
			emptySince = emptySince or os.clock()
			if os.clock() - emptySince >= Config.FREE_DRIVE_EMPTY_GRACE then
				break
			end
		else
			emptySince = nil
		end
	end
	self.closing = true
	heartbeat:Disconnect()
	self:Cleanup()
end

function RaceSession:AddPlayer(player)
	self.spawnIndex = (self.spawnIndex or 0) % #self.track.grid + 1
	return self:SpawnRacer(player, self.spawnIndex, false, nil)
end

function RaceSession:PlayerCount()
	local n = 0
	for _ in self.racers do
		n += 1
	end
	return n
end

return RaceSession
