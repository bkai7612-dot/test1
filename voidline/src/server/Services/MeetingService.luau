--!strict
--[[
	MeetingService
	Musters: the crew's emergency discussions.

	Called by
	  * Report      - a downed player or stasis pod (reporter gets an Audit token)
	  * Beacon      - the Muster Beacon in Central Operations (limited uses)
	  * Alert       - a witness raising an emergency alert from anywhere

	Phases
	  DISCUSSION  talk, review the ship log, and:
	                Investigate      spend an Audit token: where was <player> at
	                                 the last incident?
	                Request evidence once per muster, pull hidden security logs
	                End discussion   majority vote to move on early
	  VOTING      Accuse a player or Skip. One vote each, final. Ends early when
	              everyone has voted.
	  RESULT      Confine the top accused (no ties, must beat Skip). Faction
	              reveal is configurable.

	Every action is validated server-side: muster phase, voter alive, target
	valid, one vote per player. Votes of players who disconnect are discarded.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local ShipLayout = require(Shared.Data.ShipLayout)
local VoteTally = require(Shared.Logic.VoteTally)
local Format = require(Shared.Utility.Format)
local Logger = require(Shared.Utility.Logger)
local Validate = require(Shared.Utility.Validate)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local EliminationService = require(script.Parent.EliminationService)
local EvidenceService = require(script.Parent.EvidenceService)
local HazardService = require(script.Parent.HazardService)
local InteractionService = require(script.Parent.InteractionService)
local LobbyService = require(script.Parent.LobbyService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local RemoteService = require(script.Parent.RemoteService)
local ReplicationService = require(script.Parent.ReplicationService)
local SabotageService = require(script.Parent.SabotageService)

local log = Logger.new("MeetingService")

local S = Constants.RoundState

type Meeting = {
	Reason: string,
	CallerName: string,
	Subject: string?,
	Phase: "Discussion" | "Voting" | "Result",
	EndsAt: number,
	Votes: { [number]: any },
	EndDiscussion: { [number]: boolean },
	RequestUsed: boolean,
	CalledAt: number,
	Revealed: { string },
	Result: { [string]: any }?,
}

local MeetingService = {}

local meeting: Meeting? = nil
local beaconReadyAt = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function activeVoters(): { MatchService.Participant }
	local list = {}
	for _, p in MatchService.Living() do
		if p.Life == Constants.LifeState.Alive then
			table.insert(list, p)
		end
	end
	return list
end

local function publishTokens(p: MatchService.Participant)
	ReplicationService.SetPrivate(p.Player, Constants.PrivateKey.Tokens, {
		BeaconUses = p.BeaconUses,
		BeaconLimit = Config.Meeting.BeaconUsesPerPlayer,
		AuditTokens = p.AuditTokens,
		AlertTokens = p.AlertTokens,
	})
end

local function publish()
	local m = meeting
	if not m then
		ReplicationService.SetPublic(Constants.PublicKey.Meeting, nil)
		return
	end
	local voted = {}
	for userId in m.Votes do
		table.insert(voted, userId)
	end
	local endCount = 0
	for _ in m.EndDiscussion do
		endCount += 1
	end
	local needed = math.floor(#activeVoters() * Config.Meeting.EndDiscussionRatio) + 1
	ReplicationService.SetPublic(Constants.PublicKey.Meeting, {
		Reason = m.Reason,
		CallerName = m.CallerName,
		Subject = m.Subject,
		Phase = m.Phase,
		EndsAt = m.EndsAt,
		Voted = voted,
		EndDiscussionCount = endCount,
		EndDiscussionNeeded = needed,
		RequestUsed = m.RequestUsed,
		Revealed = m.Revealed,
		Result = m.Result,
	})
	MatchService.SetTimer(if m.Phase == "Discussion" then "Discussion" elseif m.Phase == "Voting" then "Voting" else "Muster result", m.EndsAt)
end

---------------------------------------------------------------------------
-- Calling a muster
---------------------------------------------------------------------------

function MeetingService.Call(caller: Player, reason: "Report" | "Beacon" | "Alert", subject: string?): boolean
	if meeting or not MatchService.IsState(S.ActiveRound) or MatchService.GetOutcome() then
		return false
	end
	local callerP = MatchService.GetParticipant(caller)
	if not callerP or callerP.Life ~= Constants.LifeState.Alive then
		return false
	end
	if not MatchService.Transition(S.Discussion) then
		return false
	end

	-- Freeze the ship: stop holds, mini-games, hazards; stasis collapses.
	InteractionService.CancelAll()
	ObjectiveService.CancelAllSessions()
	HazardService.ClearAll()
	EliminationService.CollapseAllDowned()
	local revealed = MatchService.RevealLost()
	ObjectiveService.ReleaseOrphans()

	if reason == "Report" and Config.Meeting.AuditTokenOnReport then
		callerP.AuditTokens += 1
	end
	if reason == "Alert" then
		callerP.AlertTokens = 0
	end
	publishTokens(callerP)

	local revealedNames = {}
	for _, p in revealed do
		table.insert(revealedNames, p.DisplayName)
	end

	local settings = LobbyService.GetSettings()
	local newMeeting: Meeting = {
		Reason = reason :: string,
		CallerName = caller.DisplayName,
		Subject = subject,
		Phase = "Discussion",
		EndsAt = now() + settings.DiscussionSeconds,
		Votes = {} :: { [number]: any },
		EndDiscussion = {} :: { [number]: boolean },
		RequestUsed = false,
		CalledAt = MatchService.RoundTime(),
		Revealed = revealedNames,
		Result = nil,
	}
	meeting = newMeeting

	-- Gather everyone still aboard around the muster table.
	local gathered = activeVoters()
	local positions = MapService.MeetingPositions(#gathered)
	for index, p in gathered do
		CharacterService.SetFrozen(p.Player, true)
		task.spawn(MapService.Teleport, p.Player, positions[index])
	end

	local text = if reason == "Report"
		then string.format("%s reported %s! Muster in Central Operations.", caller.DisplayName, subject or "a stasis pod")
		elseif reason == "Alert" then string.format("%s raised an emergency alert! Muster called.", caller.DisplayName)
		else string.format("%s activated the Muster Beacon.", caller.DisplayName)
	NotifyService.Broadcast(text, "Alert", 5)
	NotifyService.CueAll("MeetingCalled", { Reason = reason })
	AnalyticsService.Track("MeetingCalled", 1, { reason = reason }, caller)
	publish()
	InteractionService.Refresh()
	return true
end

---------------------------------------------------------------------------
-- Phases
---------------------------------------------------------------------------

local function beginVoting()
	local m = meeting
	if not m or m.Phase ~= "Discussion" then
		return
	end
	if not MatchService.Transition(S.Voting) then
		return
	end
	m.Phase = "Voting"
	m.EndsAt = now() + LobbyService.GetSettings().VotingSeconds
	NotifyService.Broadcast("Voting is open. Accuse or skip.", "Info", 3)
	publish()
end

local function finishMeeting()
	local m = meeting
	meeting = nil
	publish()
	EliminationService.ClearPods()
	if MatchService.GetOutcome() then
		return -- RoundService takes over
	end
	for _, p in MatchService.Living() do
		CharacterService.SetFrozen(p.Player, false)
	end
	beaconReadyAt = now() + Config.Meeting.BeaconCooldownSeconds
	EliminationService.ResetCooldowns()
	SabotageService.ResetCooldown()
	MatchService.SetTimer(nil, nil)
	MatchService.Transition(S.ActiveRound)
	InteractionService.Refresh()
	log:Debug("Muster ended", if m then m.Reason else "")
end

local function resolveVotes()
	local m = meeting
	if not m or m.Phase ~= "Voting" then
		return
	end
	local voters = activeVoters()
	local eligibleVoters: { [any]: boolean } = {}
	local eligibleTargets: { [any]: boolean } = {}
	for _, p in voters do
		eligibleVoters[p.UserId] = true
		eligibleTargets[p.UserId] = true
	end
	local result = VoteTally.tally(m.Votes, eligibleVoters, eligibleTargets)
	local settings = LobbyService.GetSettings()

	local resultPayload: { [string]: any } = { Outcome = result.Outcome, SkipCount = result.SkipCount }
	if not Config.Meeting.AnonymousVotes then
		resultPayload.Votes = m.Votes
	end
	local counts = {}
	for userId, count in result.Counts do
		table.insert(counts, { UserId = userId, Count = count })
	end
	resultPayload.Counts = counts

	local message
	if result.Outcome == "Confine" then
		local target = MatchService.GetByUserId(result.Target :: number)
		if target then
			resultPayload.TargetUserId = target.UserId
			resultPayload.TargetName = target.DisplayName
			if settings.RevealOnConfine == "Faction" then
				resultPayload.Faction = target.Faction
				message = string.format("%s was confined. They were %s.", target.DisplayName, if target.Faction == Constants.Faction.Infiltrator then "an INFILTRATOR" else "CREW")
			else
				message = string.format("%s was confined to the brig.", target.DisplayName)
			end
			-- Reward accurate accusers.
			if target.Faction == Constants.Faction.Infiltrator then
				for voterId, votedFor in m.Votes do
					if votedFor == target.UserId then
						local voter = MatchService.GetByUserId(voterId)
						if voter and voter.Faction == Constants.Faction.Crew then
							voter.Stats.CorrectVotes += 1
						end
					end
				end
			end
			MatchService.SetLife(target, Constants.LifeState.Confined :: Types.LifeState)
			CharacterService.SetFrozen(target.Player, false)
			CharacterService.Despawn(target.Player)
			AnalyticsService.Count("Confinements")
		end
	elseif result.Outcome == "Tie" then
		message = "The vote was tied. Nobody was confined."
	elseif result.Outcome == "Skip" then
		message = "The crew chose to skip. Nobody was confined."
	else
		message = "No votes were cast. Nobody was confined."
	end

	-- Infiltrators who made it through a muster unconfined.
	for _, p in MatchService.Living(Constants.Faction.Infiltrator) do
		p.Stats.MeetingsSurvived += 1
	end

	-- Stay in VOTING (players frozen) while the result card is shown;
	-- finishMeeting returns to ACTIVE_ROUND afterwards.
	for _, p in MatchService.Living() do
		CharacterService.SetFrozen(p.Player, true)
	end
	m.Phase = "Result"
	m.Result = resultPayload
	m.EndsAt = now() + Config.Meeting.ResultSeconds
	NotifyService.Broadcast(message, "Info", Config.Meeting.ResultSeconds)
	publish()
	MatchService.CheckWin()
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local function onAction(player: Player, action: string, target: number?)
	local m = meeting
	if not m then
		return
	end
	local p = MatchService.GetParticipant(player)
	if not p or p.Life ~= Constants.LifeState.Alive then
		return
	end

	local function validTarget(): MatchService.Participant?
		if type(target) ~= "number" then
			return nil
		end
		local tp = MatchService.GetByUserId(target :: number)
		if tp and tp.Life == Constants.LifeState.Alive then
			return tp
		end
		return nil
	end

	if action == Constants.MeetingAction.Accuse or action == Constants.MeetingAction.Skip then
		if m.Phase ~= "Voting" or m.Votes[p.UserId] ~= nil then
			return
		end
		if action == Constants.MeetingAction.Skip then
			m.Votes[p.UserId] = VoteTally.SKIP
		else
			local tp = validTarget()
			if not tp or tp == p then
				return
			end
			m.Votes[p.UserId] = tp.UserId
		end
		publish()
		local all = true
		for _, voter in activeVoters() do
			if m.Votes[voter.UserId] == nil then
				all = false
				break
			end
		end
		if all then
			resolveVotes()
		end
	elseif action == Constants.MeetingAction.Investigate then
		if m.Phase == "Result" or p.AuditTokens <= 0 then
			return
		end
		local tp = validTarget()
		if not tp then
			return
		end
		p.AuditTokens -= 1
		publishTokens(p)
		local t = EvidenceService.LastIncidentTime() or m.CalledAt
		local area = MatchService.AreaAt(tp, t)
		EvidenceService.AddPublic(
			"Audit",
			area,
			string.format("Audit by %s: %s's tracker logged them in %s at %s.", player.DisplayName, tp.DisplayName, ShipLayout.areaName(area), Format.clock(t)),
			t
		)
		NotifyService.Broadcast(player.DisplayName .. " audited " .. tp.DisplayName .. ".", "Info", 3)
	elseif action == Constants.MeetingAction.RequestEvidence then
		if m.Phase ~= "Discussion" or m.RequestUsed then
			return
		end
		m.RequestUsed = true
		local count = EvidenceService.RevealHidden(player)
		NotifyService.Broadcast(
			if count > 0
				then string.format("%s pulled the security logs: %d new entr%s.", player.DisplayName, count, if count == 1 then "y" else "ies")
				else player.DisplayName .. " pulled the security logs: nothing new.",
			"Info",
			4
		)
		publish()
	elseif action == Constants.MeetingAction.EndDiscussion then
		if m.Phase ~= "Discussion" then
			return
		end
		m.EndDiscussion[p.UserId] = true
		local count = 0
		for _ in m.EndDiscussion do
			count += 1
		end
		if count > #activeVoters() * Config.Meeting.EndDiscussionRatio then
			beginVoting()
		else
			publish()
		end
	end
end

---------------------------------------------------------------------------
-- Beacon and alerts
---------------------------------------------------------------------------

local function registerBeacon()
	InteractionService.Register({
		Id = "Beacon",
		Anchor = "Fixture:Beacon",
		Action = "Call muster",
		Object = "Muster Beacon",
		Hold = 1.5,
		Range = 12,
		Visible = function(player)
			local p = MatchService.GetParticipant(player)
			return p ~= nil
				and p.Life == Constants.LifeState.Alive
				and MatchService.IsState(S.ActiveRound)
				and p.BeaconUses < Config.Meeting.BeaconUsesPerPlayer
		end,
		CanBegin = function()
			if now() < beaconReadyAt then
				return false, string.format("Beacon charging (%ds).", math.ceil(beaconReadyAt - now()))
			end
			if HazardService.HasCritical() then
				return false, "Deal with the crisis first!"
			end
			return true
		end,
		OnComplete = function(player)
			local p = MatchService.GetParticipant(player)
			if p and MeetingService.Call(player, "Beacon", nil) then
				p.BeaconUses += 1
				publishTokens(p)
			end
		end,
	})
end

function MeetingService.SetupForMatch()
	meeting = nil
	beaconReadyAt = now() + Config.Meeting.BeaconCooldownSeconds
	for _, p in MatchService.GetParticipants() do
		publishTokens(p)
	end
	publish()
end

function MeetingService.Reset()
	meeting = nil
	publish()
	for _, p in MatchService.GetParticipants() do
		if p.Player.Parent == Players then
			ReplicationService.SetPrivate(p.Player, Constants.PrivateKey.Tokens, nil)
		end
	end
end

function MeetingService.IsActive(): boolean
	return meeting ~= nil
end

function MeetingService.Start()
	registerBeacon()

	EliminationService.ReportRequested:Connect(function(reporter: Player, subject: string?)
		MeetingService.Call(reporter, "Report", subject)
	end)

	RemoteService.OnEvent(Net.Names.EmergencyAlert, {}, function(player: Player)
		local p = MatchService.GetParticipant(player)
		if p and p.AlertTokens > 0 and not HazardService.HasCritical() then
			MeetingService.Call(player, "Alert", nil)
		end
	end)

	RemoteService.OnEvent(Net.Names.MeetingAction, {
		Validate.oneOf({
			Constants.MeetingAction.Accuse,
			Constants.MeetingAction.Skip,
			Constants.MeetingAction.Investigate,
			Constants.MeetingAction.RequestEvidence,
			Constants.MeetingAction.EndDiscussion,
		}),
		Validate.optional(Validate.integer(1, 2 ^ 53)),
	}, onAction)

	-- Witness alert tokens are granted by EliminationService when someone is
	-- downed; resync tokens (and the muster card) on any life change.
	MatchService.LifeChanged:Connect(function()
		for _, p in MatchService.GetParticipants() do
			if p.Player.Parent == Players then
				publishTokens(p)
			end
		end
		if meeting then
			publish()
		end
	end)

	-- Phase timer.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local m = meeting
			if m and now() >= m.EndsAt then
				if m.Phase == "Discussion" then
					beginVoting()
				elseif m.Phase == "Voting" then
					resolveVotes()
				elseif m.Phase == "Result" then
					finishMeeting()
				end
			end
		end
	end)
end

-- Exposed so EliminationService's witness tokens can be synced to clients.
function MeetingService.PublishTokens(player: Player)
	local p = MatchService.GetParticipant(player)
	if p then
		publishTokens(p)
	end
end

return MeetingService
