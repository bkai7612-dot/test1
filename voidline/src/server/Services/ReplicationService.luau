--!strict
--[[
	ReplicationService
	The only way game state reaches clients.

	  Public state  -> every client      (round state, player count, ...)
	  Private state -> ONE client only   (their own session, later their role)

	Secret data (roles, sabotage cooldowns, ...) must only ever be written with
	SetPrivate. Never store it in Attributes, Values or replicated instances,
	because exploiters can read everything that replicates.

	Each scope has a monotonically increasing version. Clients ignore updates
	older than the snapshot they already applied, so the initial
	RequestSnapshot and the live update stream can't race each other.

	Values must be remote-serializable: primitives, Instances, and tables with
	either array OR string keys (not mixed, no metatables).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local TableUtil = require(Shared.Utility.TableUtil)

local RemoteService = require(script.Parent.RemoteService)

local ReplicationService = {}

local publicState: { [string]: any } = {}
local publicVersion = 0

type PrivateScope = { State: { [string]: any }, Version: number }
local privateScopes: { [Player]: PrivateScope } = {}

local function getScope(player: Player): PrivateScope
	local scope = privateScopes[player]
	if not scope then
		scope = { State = {}, Version = 0 }
		privateScopes[player] = scope
	end
	return scope
end

function ReplicationService.Start()
	RemoteService.OnInvoke(Net.Names.RequestSnapshot, {}, function(player: Player): Types.StateSnapshot
		return ReplicationService.GetSnapshot(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		privateScopes[player] = nil
	end)
end

-- Broadcasts `value` under `key` to every client. Pass nil to remove the key.
function ReplicationService.SetPublic(key: string, value: any)
	-- Primitives that didn't change are skipped; tables always resend.
	if type(value) ~= "table" and publicState[key] == value then
		return
	end
	publicState[key] = value
	publicVersion += 1
	RemoteService.FireAllClients(Net.Names.PublicStateChanged, key, value, publicVersion)
end

function ReplicationService.GetPublic(key: string): any
	return publicState[key]
end

-- Sends `value` under `key` to `player` only.
function ReplicationService.SetPrivate(player: Player, key: string, value: any)
	if player.Parent ~= Players then
		return
	end
	local scope = getScope(player)
	if type(value) ~= "table" and scope.State[key] == value then
		return
	end
	scope.State[key] = value
	scope.Version += 1
	RemoteService.FireClient(Net.Names.PrivateStateChanged, player, key, value, scope.Version)
end

function ReplicationService.GetPrivate(player: Player, key: string): any
	local scope = privateScopes[player]
	return if scope then scope.State[key] else nil
end

-- Everything `player` is allowed to know, right now.
function ReplicationService.GetSnapshot(player: Player): Types.StateSnapshot
	local scope = getScope(player)
	return {
		Public = TableUtil.deepCopy(publicState),
		PublicVersion = publicVersion,
		Private = TableUtil.deepCopy(scope.State),
		PrivateVersion = scope.Version,
		ServerTime = workspace:GetServerTimeNow(),
	}
end

function ReplicationService.GetPublicSnapshot(): { [string]: any }
	return TableUtil.deepCopy(publicState)
end

return ReplicationService
