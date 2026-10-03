--!strict
--[[
	AdminService
	Authorization for developer tools, by UserId (never by name, which can change).
	Phase 1 exposes a single read-only query; the full debug console arrives in
	Phase 34 and must route every command through AdminService.IsAdmin.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Logger = require(Shared.Utility.Logger)
local Validate = require(Shared.Utility.Validate)

local PlayerManager = require(script.Parent.PlayerManager)
local RemoteService = require(script.Parent.RemoteService)
local ReplicationService = require(script.Parent.ReplicationService)

local log = Logger.new("AdminService")

local AdminService = {}

local QUERIES = { "ServerState" }

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
		table.insert(players, {
			Name = session.Player.Name,
			UserId = session.UserId,
			Status = session.Status,
			IsLoaded = session.IsLoaded,
			Strikes = RemoteService.GetStrikes(session.Player),
		})
	end
	return {
		Version = Config.Game.Version,
		PlaceVersion = game.PlaceVersion,
		UptimeSeconds = math.floor(os.clock() - bootClock),
		Players = players,
		Public = ReplicationService.GetPublicSnapshot(),
	}
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
end

return AdminService
