--!strict
--[[
	RoundService
	The round orchestrator. Runs the match loop and drives every lifecycle
	state; gameplay services drive the in-round states.

	  LOBBY            LobbyService decides when to launch
	  PREPARATION      ship reset, crew boards (frozen), StreamingEnabled preload
	  ROLE_ASSIGNMENT  secret roles, accents, objectives, abilities
	  ACTIVE_ROUND  <->  EMERGENCY (critical hazard)
	        |       <->  DISCUSSION -> VOTING (musters)
	        v
	  ENDGAME          Restoration hit 100%: extraction sequence
	  RESULTS          winner, rewards, stats
	  RESET            cleanup, everyone back to the lobby
	  LOBBY

	Any declared outcome (from any in-round state) jumps to RESULTS. If the
	match loop throws, the server recovers to the lobby instead of hanging.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Logger = require(Shared.Utility.Logger)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local ChatService = require(script.Parent.ChatService)
local EliminationService = require(script.Parent.EliminationService)
local EscapeService = require(script.Parent.EscapeService)
local EventService = require(script.Parent.EventService)
local EvidenceService = require(script.Parent.EvidenceService)
local HazardService = require(script.Parent.HazardService)
local InteractionService = require(script.Parent.InteractionService)
local LobbyService = require(script.Parent.LobbyService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local MeetingService = require(script.Parent.MeetingService)
local NotifyService = require(script.Parent.NotifyService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local ReplicationService = require(script.Parent.ReplicationService)
local RewardService = require(script.Parent.RewardService)
local RoleService = require(script.Parent.RoleService)
local SabotageService = require(script.Parent.SabotageService)

local log = Logger.new("RoundService")

local S = Constants.RoundState

local RoundService = {}

local pendingEndgame = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function connectedParticipants(): { Player }
	local list = {}
	for _, p in MatchService.GetParticipants() do
		if p.Player.Parent == Players then
			table.insert(list, p.Player)
		end
	end
	return list
end

local function boardShip(players: { Player })
	local startRoom = Config.Round.StartRooms[math.random(1, #Config.Round.StartRooms)]
	local ring = MapService.SpawnRing(startRoom, #players, 8)
	for index, player in players do
		task.spawn(function()
			if not CharacterService.GetRoot(player) then
				CharacterService.Spawn(player)
			end
			CharacterService.SetFrozen(player, true)
			MapService.Teleport(player, ring[index])
		end)
	end
end

local function publishResults(winner: string, reason: string)
	local list = {}
	for _, p in MatchService.GetParticipants() do
		table.insert(list, {
			UserId = p.UserId,
			Name = p.DisplayName,
			Faction = p.Faction,
			Life = p.Life,
			Accent = p.Accent,
		})
	end
	ReplicationService.SetPublic(Constants.PublicKey.Results, { Winner = winner, Reason = reason, Players = list })
end

local function cleanup()
	InteractionService.CancelAll()
	EscapeService.Reset()
	EliminationService.Reset()
	ObjectiveService.Reset()
	SabotageService.Reset()
	MeetingService.Reset()
	ChatService.Reset()
	RoleService.Clear()
	EvidenceService.Clear()
	HazardService.ClearAll()
	MapService.ResetShip()
end

local function runMatch(players: { Player })
	pendingEndgame = false
	MatchService.Transition(S.Preparation)
	MatchService.Begin(players)
	cleanup()
	RewardService.ClearRewards()
	ReplicationService.SetPublic(Constants.PublicKey.Results, nil)

	boardShip(players)
	MatchService.SetTimer("Boarding the " .. Config.Game.ShipName, now() + Config.Round.PreparationSeconds)
	NotifyService.Broadcast("Boarding the " .. Config.Game.ShipName .. ". Systems are failing...", "Info", 4)
	task.wait(Config.Round.PreparationSeconds)

	local aboard = connectedParticipants()
	if #aboard == 0 then
		MatchService.DeclareOutcome(Constants.Winner.None, "Everyone disconnected.")
	else
		MatchService.Transition(S.RoleAssignment)
		RoleService.Assign(LobbyService.GetSettings().InfiltratorCount)
		ObjectiveService.AssignForMatch()
		EliminationService.SetupForMatch()
		SabotageService.SetupForMatch()
		MeetingService.SetupForMatch()
		ChatService.SetupForMatch()
		EventService.ResetForMatch()
		MatchService.SetTimer("Role reveal", now() + Config.Round.RoleRevealSeconds)
		task.wait(Config.Round.RoleRevealSeconds)

		if not MatchService.GetOutcome() then
			MatchService.Transition(S.ActiveRound)
			MatchService.MarkActive()
			MatchService.SetTimer(nil, nil)
			for _, player in connectedParticipants() do
				CharacterService.SetFrozen(player, false)
			end
			InteractionService.Refresh()
			MatchService.CheckWin()
		end
	end

	-- Main phase: wait for an outcome, starting the endgame when ready.
	while not MatchService.GetOutcome() do
		if pendingEndgame and MatchService.IsState(S.ActiveRound) then
			pendingEndgame = false
			HazardService.ClearAll()
			if MatchService.Transition(S.Endgame) then
				EscapeService.Begin()
			end
		end
		task.wait(0.25)
	end

	-- Let a muster's result card finish before results.
	local waitUntil = os.clock() + Config.Meeting.ResultSeconds + 1
	while MeetingService.IsActive() and os.clock() < waitUntil do
		task.wait(0.2)
	end

	local outcome = MatchService.GetOutcome() :: { Winner: string, Reason: string }
	MatchService.Transition(S.Results)
	InteractionService.CancelAll()
	HazardService.ClearAll()
	EliminationService.Reset()
	for _, player in connectedParticipants() do
		CharacterService.SetFrozen(player, false)
	end
	publishResults(outcome.Winner, outcome.Reason)
	MatchService.SetTimer("Results", now() + Config.Round.ResultsSeconds)
	NotifyService.CueAll("RoundEnded", { Winner = outcome.Winner })
	RewardService.GrantRound(outcome.Winner)
	AnalyticsService.RoundCompleted(MatchService.RoundTime(), outcome.Winner, #MatchService.GetParticipants())
	task.wait(Config.Round.ResultsSeconds)

	MatchService.Transition(S.Reset)
	cleanup()
	local survivors = connectedParticipants()
	MatchService.End()
	for _, player in survivors do
		task.spawn(CharacterService.Spawn, player)
	end
	task.wait(Config.Round.ResetSeconds)
	ReplicationService.SetPublic(Constants.PublicKey.Results, nil)
	RewardService.ClearRewards()
	MatchService.Transition(S.Lobby)
end

-- Walks the state machine back to LOBBY after an unexpected error.
local function recover()
	log:Error("Recovering to lobby after a match error")
	pcall(cleanup)
	if not MatchService.IsState(S.Lobby, S.Results, S.Reset) then
		MatchService.Transition(S.Results)
	end
	if MatchService.IsState(S.Results) then
		MatchService.Transition(S.Reset)
	end
	local survivors = connectedParticipants()
	pcall(MatchService.End)
	for _, player in survivors do
		CharacterService.SetFrozen(player, false)
		task.spawn(CharacterService.Spawn, player)
	end
	if MatchService.IsState(S.Reset) then
		MatchService.Transition(S.Lobby)
	end
	MatchService.SetTimer(nil, nil)
end

function RoundService.Start()
	ObjectiveService.RestorationComplete:Connect(function()
		pendingEndgame = true
	end)

	task.spawn(function()
		while true do
			local players = LobbyService.StartRequested:Wait() :: { Player }
			if MatchService.IsState(S.Lobby) and #players > 0 then
				local ok: boolean, err: any = xpcall(runMatch, debug.traceback, players)
				if not ok then
					log:Error("Match loop error:", err)
					recover()
				end
			end
		end
	end)
end

return RoundService
