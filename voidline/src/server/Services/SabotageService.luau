--!strict
--[[
	SabotageService
	Infiltrator sabotage requests and log spoofing.

	Cooldowns are shared by the infiltrator team: a global cooldown after any
	sabotage plus a per-sabotage cooldown. Every request is validated:
	faction, alive, round state, cooldowns, target validity and hazard
	conflicts. Critical sabotage is only possible during normal play.

	Counterplay and detectability:
	  * Each sabotage posts a public anomaly to the ship log.
	  * With TraceChance it also leaves a hidden "interference trace" naming
	    the room the saboteur was standing in (revealed by security logs).
	  * Spoof lets an infiltrator plant one fake trace per round.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local SabotageCatalog = require(Shared.Data.SabotageCatalog)
local ShipLayout = require(Shared.Data.ShipLayout)
local Format = require(Shared.Utility.Format)
local Validate = require(Shared.Utility.Validate)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local EvidenceService = require(script.Parent.EvidenceService)
local HazardService = require(script.Parent.HazardService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local RemoteService = require(script.Parent.RemoteService)
local ReplicationService = require(script.Parent.ReplicationService)

local SabotageService = {}

local globalReadyAt = 0
local typeReadyAt: { [string]: number } = {}
local spoofUses: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish()
	for _, p in MatchService.Living(Constants.Faction.Infiltrator) do
		ReplicationService.SetPrivate(p.Player, Constants.PrivateKey.Abilities, {
			GlobalReadyAt = globalReadyAt,
			TypeReadyAt = typeReadyAt,
			SpoofUses = spoofUses[p.Player] or 0,
		})
	end
end

local function validTarget(sabotage: SabotageCatalog.Sabotage, target: any): (boolean, string?)
	if sabotage.Target == "Ship" then
		return true, nil
	elseif sabotage.Target == "Section" then
		if type(target) == "string" and table.find(ShipLayout.Sections, target) then
			return true, target
		end
	elseif sabotage.Target == "Room" then
		if type(target) == "string" and ShipLayout.getRoom(target) then
			return true, target
		end
	end
	return false, nil
end

-- Performs a sabotage. `force` skips role/cooldown checks (admin testing).
function SabotageService.Trigger(player: Player?, sabotageId: string, rawTarget: any, force: boolean?): (boolean, string?)
	local sabotage = SabotageCatalog.get(sabotageId)
	if not sabotage then
		return false, "Unknown sabotage."
	end
	local ok, target = validTarget(sabotage, rawTarget)
	if not ok then
		return false, "Choose a valid target."
	end
	local isCritical = sabotageId == "CoolantFailure" or sabotageId == "OxygenImbalance"

	if not force then
		if not player or not MatchService.IsInfiltrator(player) or not MatchService.IsActive(player) then
			return false, nil
		end
		if not MatchService.IsState(Constants.RoundState.ActiveRound, Constants.RoundState.Endgame) then
			return false, "Not now."
		end
		if isCritical and not MatchService.IsState(Constants.RoundState.ActiveRound) then
			return false, "Critical sabotage is unavailable right now."
		end
		local t = now()
		if t < globalReadyAt then
			return false, string.format("Link recharging (%ds).", math.ceil(globalReadyAt - t))
		end
		if t < (typeReadyAt[sabotageId] or 0) then
			return false, string.format("%s recharging (%ds).", sabotage.Name, math.ceil(typeReadyAt[sabotageId] - t))
		end
	end

	if HazardService.Conflicts(sabotage.Hazard, target) then
		return false, "That system is already failing."
	end
	local hazard = HazardService.Begin(sabotage.Hazard, target, sabotage.Duration, "Sabotage")
	if not hazard then
		return false, "The system resisted."
	end

	local t = now()
	globalReadyAt = t + Config.Sabotage.GlobalCooldown
	typeReadyAt[sabotageId] = t + sabotage.Cooldown
	publish()

	local roundTime = MatchService.RoundTime()
	local where = if target then (if sabotage.Target == "Section" then target .. " section" else ShipLayout.areaName(target)) else "ship systems"
	EvidenceService.AddPublic("Anomaly", target, string.format("%s detected in %s at %s.", sabotage.Name, where, Format.clock(roundTime)), roundTime)

	if player then
		local p = MatchService.GetParticipant(player)
		if p then
			p.Stats.Sabotages += 1
		end
		local root = CharacterService.GetRoot(player)
		local area = if root then MapService.AreaAt(root.Position) else nil
		local room = ShipLayout.areaRoom(area)
		if room and math.random() < Config.Sabotage.TraceChance then
			EvidenceService.AddHidden(
				"Trace",
				room,
				string.format("Interference trace: the %s command originated near %s.", sabotage.Name, ShipLayout.areaName(room)),
				roundTime
			)
		end
		EvidenceService.RecordIncident(area, roundTime)
		AnalyticsService.Track("SabotageUsed", 1, { sabotage = sabotageId }, player)
	end
	return true, nil
end

function SabotageService.SetupForMatch()
	local t = now()
	globalReadyAt = t + Config.Sabotage.InitialCooldown
	table.clear(typeReadyAt)
	table.clear(spoofUses)
	for _, p in MatchService.Living(Constants.Faction.Infiltrator) do
		spoofUses[p.Player] = Config.Sabotage.SpoofUsesPerRound
	end
	publish()
end

-- After a muster, sabotage waits a moment so the crew can regroup.
function SabotageService.ResetCooldown()
	globalReadyAt = math.max(globalReadyAt, now() + Config.Sabotage.GlobalCooldown)
	publish()
end

function SabotageService.Reset()
	for player in spoofUses do
		if player.Parent then
			ReplicationService.SetPrivate(player, Constants.PrivateKey.Abilities, nil)
		end
	end
	table.clear(spoofUses)
	table.clear(typeReadyAt)
	globalReadyAt = 0
end

function SabotageService.Start()
	local roomIds = {}
	for _, room in ShipLayout.Rooms do
		table.insert(roomIds, room.Id)
	end

	RemoteService.OnEvent(
		Net.Names.Sabotage,
		{ Validate.oneOf(SabotageCatalog.ids()), Validate.optional(Validate.string(32)) },
		function(player: Player, sabotageId: string, target: string?)
			local ok, reason = SabotageService.Trigger(player, sabotageId, target, false)
			if not ok and reason then
				NotifyService.Send(player, reason, "Warning", 3)
			elseif ok then
				NotifyService.Cue(player, "SabotageSent", { Id = sabotageId })
			end
		end
	)

	RemoteService.OnEvent(Net.Names.Spoof, { Validate.oneOf(roomIds) }, function(player: Player, roomId: string)
		if not MatchService.IsInfiltrator(player) or not MatchService.IsActive(player) or not MatchService.InPlay() then
			return
		end
		local uses = spoofUses[player] or 0
		if uses <= 0 then
			NotifyService.Send(player, "No spoof charges left this round.", "Warning", 3)
			return
		end
		spoofUses[player] = uses - 1
		local t = MatchService.RoundTime()
		local names = { "Power Surge", "Communication Jam", "Security Lockdown", "Gravity Failure" }
		EvidenceService.AddHidden(
			"Trace",
			roomId,
			string.format("Interference trace: the %s command originated near %s.", names[math.random(1, #names)], ShipLayout.areaName(roomId)),
			math.max(0, t - math.random(10, 60))
		)
		NotifyService.Send(player, "False trace planted in the security logs.", "Success", 3)
		publish()
	end)
end

return SabotageService
