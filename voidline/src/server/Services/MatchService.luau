--!strict
--[[
	MatchService
	Owns the round state machine and everything that describes the match in
	progress: participants, their life state, the ship's meters (Stability and
	Restoration), the round clock, and presence history (who was where, when).

	Only RoundService drives lifecycle states (LOBBY, PREPARATION, ...).
	Gameplay services request in-round transitions (EMERGENCY, DISCUSSION,
	VOTING, ENDGAME) through MatchService.Transition, which rejects anything
	the transition table doesn't allow.

	Privacy: a participant's faction lives only on the server record. The
	public roster shows "Active" for anyone not publicly known to be out;
	players who are lost become publicly "Lost" only when a muster reveals it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Types = require(Shared.Types)
local Rewards = require(Shared.Logic.Rewards)
local StateMachine = require(Shared.Logic.StateMachine)
local WinConditions = require(Shared.Logic.WinConditions)
local Logger = require(Shared.Utility.Logger)
local Signal = require(Shared.Utility.Signal)

local MapService = require(script.Parent.MapService)
local PlayerManager = require(script.Parent.PlayerManager)
local ReplicationService = require(script.Parent.ReplicationService)

local log = Logger.new("MatchService")

local S = Constants.RoundState
local L = Constants.LifeState

export type Participant = {
	Player: Player,
	UserId: number,
	Name: string,
	DisplayName: string,
	Faction: Types.Faction?,
	Accent: number,
	Life: Types.LifeState,
	PublicLife: Types.PublicLifeState,
	Area: string?,
	Stats: Types.RoundStats,
	BeaconUses: number,
	AuditTokens: number,
	AlertTokens: number,
	ShakenUntil: number,
	LostAt: number?,
}

type PresenceSample = { Time: number, Area: string? }
type AreaChange = { Time: number, UserId: number, From: string?, To: string? }

type Match = {
	Id: number,
	ActiveSince: number?, -- server time ACTIVE_ROUND first began
	Participants: { [Player]: Participant },
	ByUserId: { [number]: Participant },
	Stability: number,
	Restoration: number,
	TotalInfiltrators: number,
	Outcome: { Winner: string, Reason: string }?,
	History: { [number]: { PresenceSample } },
	AreaChanges: { AreaChange },
}

local TRANSITIONS: { [string]: { string } } = {
	[S.Lobby] = { S.Preparation },
	[S.Preparation] = { S.RoleAssignment, S.Results },
	[S.RoleAssignment] = { S.ActiveRound, S.Results },
	[S.ActiveRound] = { S.Emergency, S.Discussion, S.Endgame, S.Results },
	[S.Emergency] = { S.ActiveRound, S.Results },
	[S.Discussion] = { S.Voting, S.Results },
	[S.Voting] = { S.ActiveRound, S.Results },
	[S.Endgame] = { S.Results },
	[S.Results] = { S.Reset },
	[S.Reset] = { S.Lobby },
}

local MatchService = {}

-- (newState, oldState)
MatchService.StateChanged = Signal.new()
-- (participant, newLife, oldLife)
MatchService.LifeChanged = Signal.new()
-- (participant) a participant disconnected mid-match
MatchService.ParticipantLeft = Signal.new()
-- (winner, reason)
MatchService.OutcomeDeclared = Signal.new()
-- (stability, restoration)
MatchService.MetersChanged = Signal.new()

local machine = StateMachine.new(TRANSITIONS, S.Lobby)
local match: Match? = nil
local matchCounter = 0
local lastMetersPublish = 0

---------------------------------------------------------------------------
-- State machine
---------------------------------------------------------------------------

function MatchService.GetState(): string
	return machine:Get()
end

function MatchService.IsState(...: string): boolean
	return machine:Is(...)
end

-- States in which ship gameplay (objectives, sabotage, siphons) runs.
function MatchService.InPlay(): boolean
	return machine:Is(S.ActiveRound, S.Emergency, S.Endgame)
end

function MatchService.Transition(to: string): boolean
	local ok, err = machine:Transition(to)
	if not ok then
		log:Warn("Rejected transition:", err)
	end
	return ok
end

---------------------------------------------------------------------------
-- Publishing
---------------------------------------------------------------------------

local function publishRoster()
	if not match then
		ReplicationService.SetPublic(Constants.PublicKey.Roster, nil)
		return
	end
	local roster = {}
	for _, p in match.Participants do
		table.insert(roster, {
			UserId = p.UserId,
			Name = p.Name,
			DisplayName = p.DisplayName,
			Accent = p.Accent,
			Status = p.PublicLife,
		})
	end
	table.sort(roster, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	ReplicationService.SetPublic(Constants.PublicKey.Roster, roster)
end

local function publishMeters(force: boolean?)
	if not match then
		return
	end
	local now = os.clock()
	if not force and now - lastMetersPublish < 1 then
		return
	end
	lastMetersPublish = now
	ReplicationService.SetPublic(Constants.PublicKey.Meters, {
		Stability = math.floor(match.Stability * 10) / 10,
		Restoration = math.floor(match.Restoration * 10) / 10,
	})
end

local function publishLife(p: Participant)
	ReplicationService.SetPrivate(p.Player, Constants.PrivateKey.Life, p.Life)
end

-- Public timer bar: label + server time it ends (nil clears it).
function MatchService.SetTimer(label: string?, endsAt: number?)
	if label and endsAt then
		ReplicationService.SetPublic(Constants.PublicKey.Timer, { Label = label, EndsAt = endsAt })
	else
		ReplicationService.SetPublic(Constants.PublicKey.Timer, nil)
	end
end

---------------------------------------------------------------------------
-- Match lifecycle
---------------------------------------------------------------------------

function MatchService.Begin(players: { Player })
	matchCounter += 1
	local newMatch: Match = {
		Id = matchCounter,
		ActiveSince = nil,
		Participants = {},
		ByUserId = {},
		Stability = Config.Round.StabilityStart,
		Restoration = 0,
		TotalInfiltrators = 0,
		Outcome = nil,
		History = {},
		AreaChanges = {},
	}
	for _, player in players do
		if player.Parent == Players then
			local p: Participant = {
				Player = player,
				UserId = player.UserId,
				Name = player.Name,
				DisplayName = player.DisplayName,
				Faction = nil,
				Accent = 1,
				Life = L.Alive :: Types.LifeState,
				PublicLife = Constants.PublicLifeState.Active :: Types.PublicLifeState,
				Area = nil,
				Stats = Rewards.emptyStats(),
				BeaconUses = 0,
				AuditTokens = 0,
				AlertTokens = 0,
				ShakenUntil = 0,
				LostAt = nil,
			}
			newMatch.Participants[player] = p
			newMatch.ByUserId[player.UserId] = p
			newMatch.History[player.UserId] = {}
			PlayerManager.SetStatus(player, Constants.PlayerStatus.InRound :: Types.PlayerStatus)
		end
	end
	match = newMatch
	publishRoster()
	publishMeters(true)
	for _, p in newMatch.Participants do
		publishLife(p)
	end
	ReplicationService.SetPublic(Constants.PublicKey.MatchInfo, { Id = newMatch.Id, ActiveSince = nil })
end

-- Called when the round first enters ACTIVE_ROUND.
function MatchService.MarkActive()
	if match and not match.ActiveSince then
		match.ActiveSince = workspace:GetServerTimeNow()
		ReplicationService.SetPublic(Constants.PublicKey.MatchInfo, { Id = match.Id, ActiveSince = match.ActiveSince })
	end
end

function MatchService.End()
	if not match then
		return
	end
	for _, p in match.Participants do
		if p.Player.Parent == Players then
			ReplicationService.SetPrivate(p.Player, Constants.PrivateKey.Life, nil)
			PlayerManager.SetStatus(p.Player, Constants.PlayerStatus.Lobby :: Types.PlayerStatus)
		end
	end
	match = nil
	publishRoster()
	ReplicationService.SetPublic(Constants.PublicKey.Meters, nil)
	ReplicationService.SetPublic(Constants.PublicKey.MatchInfo, nil)
	MatchService.SetTimer(nil, nil)
end

function MatchService.IsRunning(): boolean
	return match ~= nil
end

function MatchService.GetMatchId(): number
	return if match then match.Id else 0
end

-- Seconds since the round went active (0 before that).
function MatchService.RoundTime(): number
	if not match or not match.ActiveSince then
		return 0
	end
	return workspace:GetServerTimeNow() - match.ActiveSince
end

---------------------------------------------------------------------------
-- Participants
---------------------------------------------------------------------------

function MatchService.GetParticipant(player: Player): Participant?
	return if match then match.Participants[player] else nil
end

function MatchService.GetByUserId(userId: number): Participant?
	return if match then match.ByUserId[userId] else nil
end

function MatchService.GetParticipants(): { Participant }
	local list = {}
	if match then
		for _, p in match.Participants do
			table.insert(list, p)
		end
	end
	return list
end

local function isLiving(p: Participant): boolean
	return p.Life == L.Alive or p.Life == L.Downed
end

-- Participants still in play (alive or in stasis), optionally filtered by faction.
function MatchService.Living(faction: string?): { Participant }
	local list = {}
	if match then
		for _, p in match.Participants do
			if isLiving(p) and (faction == nil or p.Faction == faction) then
				table.insert(list, p)
			end
		end
	end
	return list
end

-- Alive and on their feet.
function MatchService.IsActive(player: Player): boolean
	local p = MatchService.GetParticipant(player)
	return p ~= nil and p.Life == L.Alive
end

function MatchService.IsInfiltrator(player: Player): boolean
	local p = MatchService.GetParticipant(player)
	return p ~= nil and p.Faction == Constants.Faction.Infiltrator
end

function MatchService.SetFactionCounts(totalInfiltrators: number)
	if match then
		match.TotalInfiltrators = totalInfiltrators
	end
end

function MatchService.GetTotalInfiltrators(): number
	return if match then match.TotalInfiltrators else 0
end

function MatchService.SetLife(p: Participant, life: Types.LifeState)
	local old = p.Life
	if old == life then
		return
	end
	p.Life = life
	if life == L.Lost then
		p.LostAt = MatchService.RoundTime()
	elseif life == L.Confined then
		p.PublicLife = Constants.PublicLifeState.Confined :: Types.PublicLifeState
	elseif life == L.Escaped then
		p.PublicLife = Constants.PublicLifeState.Escaped :: Types.PublicLifeState
	elseif life == L.Disconnected then
		p.PublicLife = Constants.PublicLifeState.Disconnected :: Types.PublicLifeState
	end
	publishLife(p)
	publishRoster()
	MatchService.LifeChanged:Fire(p, life, old)
end

-- At a muster, everyone lost so far becomes publicly known. Returns them.
function MatchService.RevealLost(): { Participant }
	local revealed = {}
	if match then
		for _, p in match.Participants do
			if p.Life == L.Lost and p.PublicLife == Constants.PublicLifeState.Active then
				p.PublicLife = Constants.PublicLifeState.Lost :: Types.PublicLifeState
				table.insert(revealed, p)
			end
		end
	end
	if #revealed > 0 then
		publishRoster()
	end
	return revealed
end

function MatchService.SetAccent(p: Participant, accent: number)
	p.Accent = accent
	publishRoster()
end

---------------------------------------------------------------------------
-- Meters
---------------------------------------------------------------------------

function MatchService.GetStability(): number
	return if match then match.Stability else 0
end

function MatchService.GetRestoration(): number
	return if match then match.Restoration else 0
end

function MatchService.AddStability(delta: number)
	if not match or match.Outcome then
		return
	end
	match.Stability = math.clamp(match.Stability + delta, 0, 100)
	publishMeters(delta <= -5 or delta >= 2)
	MatchService.MetersChanged:Fire(match.Stability, match.Restoration)
	if match.Stability <= 0 then
		MatchService.CheckWin()
	end
end

function MatchService.SetRestoration(percent: number)
	if not match then
		return
	end
	match.Restoration = math.clamp(percent, 0, 100)
	publishMeters(true)
	MatchService.MetersChanged:Fire(match.Stability, match.Restoration)
end

---------------------------------------------------------------------------
-- Outcome
---------------------------------------------------------------------------

function MatchService.DeclareOutcome(winner: string, reason: string)
	if not match or match.Outcome then
		return
	end
	match.Outcome = { Winner = winner, Reason = reason }
	log:Info("Outcome:", winner, "-", reason)
	MatchService.OutcomeDeclared:Fire(winner, reason)
end

function MatchService.GetOutcome(): { Winner: string, Reason: string }?
	return if match then match.Outcome else nil
end

-- Evaluates elimination/parity/stability win conditions.
function MatchService.CheckWin()
	if not match or match.Outcome then
		return
	end
	if not machine:Is(S.ActiveRound, S.Emergency, S.Discussion, S.Voting, S.Endgame) then
		return
	end
	local winner, reason = WinConditions.evaluate({
		AliveCrew = #MatchService.Living(Constants.Faction.Crew),
		AliveInfiltrators = #MatchService.Living(Constants.Faction.Infiltrator),
		TotalInfiltrators = match.TotalInfiltrators,
		Stability = match.Stability,
	})
	if winner and reason then
		MatchService.DeclareOutcome(winner, reason)
	end
end

---------------------------------------------------------------------------
-- Presence history (feeds evidence and audits)
---------------------------------------------------------------------------

local function samplePresence()
	if not match then
		return
	end
	local now = MatchService.RoundTime()
	local keep = Config.Round.PresenceHistorySeconds
	for _, p in match.Participants do
		if isLiving(p) then
			local character = p.Player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local area = if root then MapService.AreaAt(root.Position) else nil
			if area ~= p.Area then
				table.insert(match.AreaChanges, { Time = now, UserId = p.UserId, From = p.Area, To = area })
				if #match.AreaChanges > 1500 then
					table.remove(match.AreaChanges, 1)
				end
				p.Area = area
			end
			local history = match.History[p.UserId]
			table.insert(history, { Time = now, Area = area })
			while #history > 0 and now - history[1].Time > keep do
				table.remove(history, 1)
			end
		end
	end
end

function MatchService.AreaOf(p: Participant): string?
	return p.Area
end

-- Area a participant was in at round time `t` (nil if unknown).
function MatchService.AreaAt(p: Participant, t: number): string?
	if not match then
		return nil
	end
	local history = match.History[p.UserId]
	local best: PresenceSample? = nil
	for _, sample in history do
		if sample.Time <= t + 0.5 then
			best = sample
		else
			break
		end
	end
	return if best then best.Area else nil
end

-- Area changes into or out of `areaIds` between t0 and t1.
function MatchService.AreaChangesNear(areaIds: { string }, t0: number, t1: number): { AreaChange }
	local list = {}
	if match then
		for _, change in match.AreaChanges do
			if change.Time >= t0 and change.Time <= t1 then
				if
					(change.To and table.find(areaIds, change.To)) or (change.From and table.find(areaIds, change.From))
				then
					table.insert(list, change)
				end
			end
		end
	end
	return list
end

-- Participants whose sampled area at time t was in `areaIds`.
function MatchService.PresentAt(areaIds: { string }, t: number): { Participant }
	local list = {}
	if match then
		for _, p in match.Participants do
			local area = MatchService.AreaAt(p, t)
			if area and table.find(areaIds, area) then
				table.insert(list, p)
			end
		end
	end
	return list
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function MatchService.Init()
	machine:OnChanged(function(new, old)
		ReplicationService.SetPublic(Constants.PublicKey.RoundState, new)
		MatchService.StateChanged:Fire(new, old)
	end)
end

function MatchService.Start()
	ReplicationService.SetPublic(Constants.PublicKey.RoundState, machine:Get())

	PlayerManager.SessionRemoving:Connect(function(session)
		if not match then
			return
		end
		local p = match.Participants[session.Player]
		if not p then
			return
		end
		if isLiving(p) then
			MatchService.SetLife(p, L.Disconnected :: Types.LifeState)
		else
			p.PublicLife = Constants.PublicLifeState.Disconnected :: Types.PublicLifeState
			publishRoster()
		end
		MatchService.ParticipantLeft:Fire(p)
		MatchService.CheckWin()
	end)

	-- Single clock for decay and presence sampling (no per-frame work).
	task.spawn(function()
		local sinceSample = 0
		while true do
			local dt = task.wait(0.5)
			if match and not match.Outcome then
				if machine:Is(S.ActiveRound, S.Emergency, S.Endgame) then
					local decay = Config.Round.StabilityDecayPerMinute / 60 * dt
					match.Stability = math.max(0, match.Stability - decay)
					publishMeters(false)
					if match.Stability <= 0 then
						MatchService.CheckWin()
					end
					if MatchService.RoundTime() > Config.Round.MaxRoundSeconds then
						match.Stability = 0
						MatchService.CheckWin()
					end
				end
				sinceSample += dt
				if sinceSample >= Config.Round.PresenceSampleSeconds then
					sinceSample = 0
					samplePresence()
				end
			end
		end
	end)
end

return MatchService
