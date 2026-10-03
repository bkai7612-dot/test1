--!strict
--[[
	RoleService
	Secret role assignment.

	  * Runs entirely on the server with a fresh Random per round.
	  * A player's faction is stored only on their server-side Participant
	    record and sent ONLY to that player (ReplicationService.SetPrivate).
	    Infiltrators additionally learn who their fellow infiltrators are.
	  * Nothing role-related is written to attributes, values, names, teams or
	    any replicated instance, so exploit tools have nothing to read.
	  * Accents (the visible armband clue) are spread evenly across players.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Types = require(Shared.Types)
local AccentPalette = require(Shared.Data.AccentPalette)
local ObjectiveAssigner = require(Shared.Logic.ObjectiveAssigner)
local RoleAllocator = require(Shared.Logic.RoleAllocator)
local Logger = require(Shared.Utility.Logger)
local Signal = require(Shared.Utility.Signal)

local MatchService = require(script.Parent.MatchService)
local ReplicationService = require(script.Parent.ReplicationService)

local log = Logger.new("RoleService")

local RoleService = {}

-- () fired after every participant has a faction and accent
RoleService.Assigned = Signal.new()

local lastInfiltrators: { [number]: boolean } = {}
local forced: { [number]: Types.Faction } = {}

-- Admin/debug: force a faction for a user on the next assignment.
function RoleService.ForceNext(userId: number, faction: Types.Faction?)
	if faction then
		forced[userId] = faction
	else
		forced[userId] = nil
	end
end

function RoleService.Assign(override: number?)
	local participants = MatchService.GetParticipants()
	local rng = Random.new()
	local count = RoleAllocator.infiltratorCount(
		#participants,
		Config.Roles.InfiltratorScaling,
		Config.Roles.MaxInfiltratorRatio,
		rng,
		if override and override > 0 then override else nil
	)

	-- Forced picks first (debug only), then weighted selection for the rest.
	local chosen: { [any]: boolean } = {}
	local forcedCount = 0
	local candidates = {}
	for _, p in participants do
		local force = forced[p.UserId]
		if force == Constants.Faction.Infiltrator and forcedCount < math.max(count, 1) and #participants > 1 then
			chosen[p.UserId] = true
			forcedCount += 1
		elseif force ~= Constants.Faction.Crew then
			table.insert(candidates, {
				Id = p.UserId,
				Weight = if lastInfiltrators[p.UserId] then Config.Roles.RepeatInfiltratorWeight else 1,
			})
		end
	end
	table.clear(forced)
	count = math.max(count, forcedCount)
	for id in RoleAllocator.pick(candidates, count - forcedCount, rng) do
		chosen[id] = true
	end

	table.clear(lastInfiltrators)
	local infiltrators = {}
	for _, p in participants do
		if chosen[p.UserId] then
			p.Faction = Constants.Faction.Infiltrator :: Types.Faction
			lastInfiltrators[p.UserId] = true
			table.insert(infiltrators, p)
		else
			p.Faction = Constants.Faction.Crew :: Types.Faction
		end
	end
	MatchService.SetFactionCounts(#infiltrators)

	-- Even accent distribution in random order.
	local accents = {}
	for i = 1, AccentPalette.Count do
		accents[i] = i
	end
	local order = ObjectiveAssigner.shuffled(participants, rng)
	local accentOrder = ObjectiveAssigner.shuffled(accents, rng)
	for i, p in order do
		MatchService.SetAccent(p, accentOrder[((i - 1) % #accentOrder) + 1])
	end

	-- Private reveal.
	for _, p in participants do
		local allies = {}
		if p.Faction == Constants.Faction.Infiltrator then
			for _, other in infiltrators do
				if other ~= p then
					table.insert(allies, { UserId = other.UserId, Name = other.DisplayName })
				end
			end
		end
		ReplicationService.SetPrivate(p.Player, Constants.PrivateKey.Role, {
			Faction = p.Faction,
			Accent = p.Accent,
			Allies = allies,
			InfiltratorCount = #infiltrators,
		})
	end

	log:Info(string.format("Assigned roles: %d players, %d infiltrators", #participants, #infiltrators))
	RoleService.Assigned:Fire()
end

-- Clears private role data (round reset).
function RoleService.Clear()
	for _, p in MatchService.GetParticipants() do
		ReplicationService.SetPrivate(p.Player, Constants.PrivateKey.Role, nil)
	end
end

return RoleService
