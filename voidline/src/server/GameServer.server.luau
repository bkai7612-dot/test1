--!strict
--[[
	GameServer (bootstrap)
	The only server Script. Loads services in a fixed order and runs their
	lifecycle:

	  1. require  - every module in SERVICE_ORDER
	  2. Init     - in order; create state and instances
	  3. Start    - in order; bind remotes, connect events
	  4. Shutdown - REVERSE order, inside BindToClose (data saving etc.)

	If any step fails the boot aborts loudly: a half-started server would
	accept players into a broken game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local Logger = require(Shared.Utility.Logger)

local Services = script.Parent:WaitForChild("Services")

local log = Logger.new("GameServer")

-- Explicit order keeps boot deterministic. Add new services here as phases land.
local SERVICE_ORDER = {
	"RemoteService",
	"ReplicationService",
	"PlayerManager",
	"AdminService",
	-- Phase 2+: "LobbyManager", "RoundManager", "RoleManager", ...
}

type LoadedService = { Name: string, Module: Types.Lifecycle }

local bootStart = os.clock()
local loaded: { LoadedService } = {}

for _, name in SERVICE_ORDER do
	local moduleScript = Services:FindFirstChild(name)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		error(string.format("[GameServer] Service module %q not found", name))
	end
	local ok, result = pcall(require, moduleScript)
	if not ok then
		error(string.format("[GameServer] Failed to require %s: %s", name, tostring(result)))
	end
	table.insert(loaded, { Name = name, Module = result :: Types.Lifecycle })
end

local function runPhase(phase: "Init" | "Start")
	for _, service in loaded do
		local fn = service.Module[phase]
		if fn then
			local ok: boolean, err: any = pcall(fn)
			if not ok then
				error(string.format("[GameServer] %s.%s failed: %s", service.Name, phase, tostring(err)))
			end
		end
	end
end

runPhase("Init")
runPhase("Start")

game:BindToClose(function()
	log:Info("Server shutting down")
	for i = #loaded, 1, -1 do
		local service = loaded[i]
		local fn = service.Module.Shutdown
		if fn then
			local ok: boolean, err: any = pcall(fn)
			if not ok then
				log:Error(service.Name, "Shutdown failed:", err)
			end
		end
	end
end)

-- Initial public state. RoundManager (Phase 3) takes ownership of RoundState.
local ReplicationService = require(Services.ReplicationService)
local RemoteService = require(Services.RemoteService)
local PlayerManager = require(Services.PlayerManager)

ReplicationService.SetPublic(Constants.PublicKey.ServerVersion, Config.Game.Version)
ReplicationService.SetPublic(Constants.PublicKey.RoundState, Constants.RoundState.Lobby)

PlayerManager.PlayerLoaded:Connect(function(session: Types.PlayerSession)
	local notification: Types.Notification = {
		Text = string.format("Link established. Welcome aboard the %s.", Config.Game.ShipName),
		Kind = "Info",
		Duration = 5,
	}
	RemoteService.FireClient(Net.Names.Notify, session.Player, notification)
end)

log:Info(string.format("Server ready (%s) in %.1f ms", Config.Game.Version, (os.clock() - bootStart) * 1000))
