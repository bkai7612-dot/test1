--!strict
--[[
	AdminService
	Developer-only tools, authorised by UserId (never by name, which can change).

	  DebugQuery("ServerState")     read-only server snapshot (Phase 1, unchanged)
	  AdminCommand(cmd, a?, b?)     start/end rounds, spawn events, test sabotage,
	                                give credits/XP, force objectives/roles,
	                                teleport, set meters, test UI notifications

	Every command re-checks IsAdmin on the server. Non-admin attempts are
	logged and ignored; the client admin panel is only shown to admins
	(private IsAdmin flag) but hiding it is not what protects it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local EventCatalog = require(Shared.Data.EventCatalog)
local SabotageCatalog = require(Shared.Data.SabotageCatalog)
local ShipLayout = require(Shared.Data.ShipLayout)
local Progression = require(Shared.Logic.Progression)
local Logger = require(Shared.Utility.Logger)
local Validate = require(Shared.Utility.Validate)

local AnalyticsService = require(script.Parent.AnalyticsService)
local AntiCheatService = require(script.Parent.AntiCheatService)
local DataService = require(script.Parent.DataService)
local EliminationService = require(script.Parent.EliminationService)
local EventService = require(script.Parent.EventService)
local HazardService = require(script.Parent.HazardService)
local LobbyService = require(script.Parent.LobbyService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local PlayerManager = require(script.Parent.PlayerManager)
local RemoteService = require(script.Parent.RemoteService)
local ReplicationService = require(script.Parent.ReplicationService)
local RoleService = require(script.Parent.RoleService)
local SabotageService = require(script.Parent.SabotageService)

local log = Logger.new("AdminService")

local AdminService = {}

local QUERIES = { "ServerState" }

local COMMANDS = {
	"StartRound",
	"EndRound",
	"SpawnEvent",
	"Sabotage",
	"GiveCredits",
	"GiveXp",
	"CompleteTasks",
	"SetRestoration",
	"SetStability",
	"ForceRole",
	"Teleport",
	"Notify",
	"ToggleEvents",
	"DownSelf",
	"TestUI",
}

local bootClock = os.clock()

function AdminService.IsAdmin(player: Player): boolean
	if player.Parent ~= Players then
		return false
	end
	local settings = Config.Admin
	if table.find(settings.UserIds, player.UserId) then
		return true
	end
	if settings.AllowStudioAdmins and RunService:IsStudio() then
		return true
	end
	if settings.AllowGameOwner and game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId then
		return true
	end
	return false
end

local function buildServerState()
	local players = {}
	for _, session in PlayerManager.GetSessions() do
		local p = MatchService.GetParticipant(session.Player)
		table.insert(players, {
			Name = session.Player.Name,
			UserId = session.UserId,
			Status = session.Status,
			IsLoaded = session.IsLoaded,
			Strikes = RemoteService.GetStrikes(session.Player),
			Corrections = AntiCheatService.GetCorrections(session.Player),
			-- Factions are shown to admins only (this response never goes to non-admins).
			Faction = if p then p.Faction else nil,
			Life = if p then p.Life else nil,
		})
	end
	local hazards = {}
	for _, hazard in HazardService.GetActive() do
		table.insert(hazards, { Kind = hazard.Kind.Id, Target = hazard.Target, Source = hazard.Source })
	end
	return {
		Version = Config.Game.Version,
		PlaceVersion = game.PlaceVersion,
		UptimeSeconds = math.floor(os.clock() - bootClock),
		RoundState = MatchService.GetState(),
		RoundTime = math.floor(MatchService.RoundTime()),
		Stability = MatchService.GetStability(),
		Restoration = MatchService.GetRestoration(),
		Players = players,
		Hazards = hazards,
		Analytics = AnalyticsService.Summary(),
		DataStoreMock = DataService.IsUsingMock(),
		Public = ReplicationService.GetPublicSnapshot(),
	}
end

local function asNumber(value: any, default: number): number
	local n = tonumber(value)
	if n == nil or n ~= n then
		return default
	end
	return n
end

local function runCommand(player: Player, command: string, a: any, b: any): (boolean, string)
	if command == "StartRound" then
		if not MatchService.IsState(Constants.RoundState.Lobby) then
			return false, "A round is already running."
		end
		LobbyService.ForceStart()
		return true, "Launching."
	elseif command == "EndRound" then
		local winner = if a == "Crew" or a == "Infiltrator" then a else Constants.Winner.None
		MatchService.DeclareOutcome(winner, "Round ended by an administrator.")
		return true, "Ending round."
	elseif command == "SpawnEvent" then
		if not MatchService.InPlay() then
			return false, "No round in play."
		end
		local id = if type(a) == "string" and EventCatalog.get(a) then a else nil
		return EventService.Run(id), "Event requested."
	elseif command == "Sabotage" then
		if type(a) ~= "string" or not SabotageCatalog.get(a) then
			return false, "Unknown sabotage."
		end
		local ok, reason = SabotageService.Trigger(nil, a, b, true)
		return ok, reason or "Sabotage triggered."
	elseif command == "GiveCredits" then
		local amount = math.clamp(math.floor(asNumber(a, 100)), -1e6, 1e6)
		DataService.Update(player, function(profile)
			profile.Credits = math.max(0, profile.Credits + amount)
		end)
		return true, "Credits adjusted."
	elseif command == "GiveXp" then
		local amount = math.clamp(math.floor(asNumber(a, 100)), 0, 1e7)
		DataService.Update(player, function(profile)
			profile.Level, profile.Xp = Progression.applyXp(profile.Level, profile.Xp, amount)
		end)
		return true, "XP granted."
	elseif command == "CompleteTasks" then
		ObjectiveService.DebugCompleteAll(player)
		return true, "Your objectives are complete."
	elseif command == "SetRestoration" then
		ObjectiveService.DebugSetRestoration(asNumber(a, 100))
		return true, "Restoration set."
	elseif command == "SetStability" then
		MatchService.AddStability(asNumber(a, 100) - MatchService.GetStability())
		return true, "Stability set."
	elseif command == "ForceRole" then
		local faction: Types.Faction? = if a == "Crew" or a == "Infiltrator" then a else nil
		RoleService.ForceNext(player.UserId, faction)
		return true, "Role will apply next round."
	elseif command == "Teleport" then
		if type(a) ~= "string" or not ShipLayout.getRoom(a) then
			return false, "Unknown room."
		end
		MapService.Teleport(player, MapService.SpawnRing(a, 1, 4)[1])
		return true, "Teleported."
	elseif command == "Notify" then
		NotifyService.Broadcast(if type(a) == "string" then a else "Test announcement.", "Info", 5)
		return true, "Sent."
	elseif command == "ToggleEvents" then
		EventService.SetEnabled(a == true)
		return true, "Events " .. (if a == true then "enabled." else "disabled.")
	elseif command == "DownSelf" then
		EliminationService.DebugDown(player)
		return true, "You are in stasis."
	elseif command == "TestUI" then
		for _, kind in { "Info", "Warning", "Alert", "Success" } do
			NotifyService.Send(player, "Test " .. kind .. " notification", kind :: Types.NotificationKind, 4)
		end
		NotifyService.Cue(player, "AdminTestUI", { Screen = a })
		return true, "UI test sent."
	end
	return false, "Unknown command."
end

function AdminService.Start()
	RemoteService.OnInvoke(Net.Names.DebugQuery, { Validate.oneOf(QUERIES) }, function(player: Player, query: string)
		if not AdminService.IsAdmin(player) then
			log:Warn("Non-admin", player.Name, player.UserId, "attempted DebugQuery")
			return nil
		end
		if query == "ServerState" then
			return buildServerState()
		end
		return nil
	end)

	RemoteService.OnInvoke(
		Net.Names.AdminCommand,
		{ Validate.oneOf(COMMANDS), Validate.optional(Validate.primitive(120)), Validate.optional(Validate.primitive(40)) },
		function(player: Player, command: string, a: any, b: any)
			if not AdminService.IsAdmin(player) then
				log:Warn("Non-admin", player.Name, player.UserId, "attempted AdminCommand", command)
				return nil
			end
			log:Info(string.format("Admin %s (%d) ran %s %s %s", player.Name, player.UserId, command, tostring(a), tostring(b)))
			local ok, message = runCommand(player, command, a, b)
			return { Ok = ok, Message = message }
		end
	)

	-- Tell admins privately so the client can show the panel.
	PlayerManager.PlayerLoaded:Connect(function(session)
		ReplicationService.SetPrivate(session.Player, Constants.PrivateKey.IsAdmin, AdminService.IsAdmin(session.Player))
	end)
	for _, player in PlayerManager.GetLoadedPlayers() do
		ReplicationService.SetPrivate(player, Constants.PrivateKey.IsAdmin, AdminService.IsAdmin(player))
	end
end

-- Exposed for other services/tests.
AdminService.Commands = COMMANDS

return AdminService
