--!strict
--[[
	RemoteService
	Owns every remote instance and is the ONLY place client requests enter
	the server. Each request passes through, in order:

	  1. Sender check   - player must still be connected.
	  2. Rate limit     - per-player, per-remote token bucket. Excess is dropped.
	  3. Validation     - argument count and types (see Validate). Failures are
	                      counted as strikes; a legit client never produces them.
	  4. Handler        - runs inside pcall so one bad request can't break others.

	Handlers still own *game-rule* validation (e.g. "is this player alive?").
	This layer only guarantees the shape and rate of the input.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Logger = require(Shared.Utility.Logger)
local RateLimiter = require(Shared.Utility.RateLimiter)
local Validate = require(Shared.Utility.Validate)

type Check = Validate.Check
type RateLimiter = RateLimiter.RateLimiter

local log = Logger.new("RemoteService")

local RemoteService = {}

local events: { [string]: RemoteEvent } = {}
local functions: { [string]: RemoteFunction } = {}
local limiters: { [string]: RateLimiter } = {}
local bound: { [string]: boolean } = {}
local strikes: { [Player]: number } = {}

local function getDefinition(name: string, expectedKind: Net.RemoteKind, expectedDirection: Net.Direction)
	local definition = Net.Definitions[name]
	assert(definition, "Unknown remote: " .. name)
	assert(definition.Kind == expectedKind, string.format("Remote %s is a %s, not a %s", name, definition.Kind, expectedKind))
	assert(
		definition.Direction == expectedDirection,
		string.format("Remote %s is %s, not %s", name, definition.Direction, expectedDirection)
	)
	return definition
end

local function addStrike(player: Player, remoteName: string, reason: string)
	local count = (strikes[player] or 0) + 1
	strikes[player] = count
	log:Warn(string.format("Rejected %s from %s (%d): %s", remoteName, player.Name, player.UserId, reason))

	local settings = Config.Network
	if settings.KickOnMalformedRequests and count >= settings.MalformedRequestKickThreshold then
		log:Warn(string.format("Kicking %s (%d) after %d malformed requests", player.Name, player.UserId, count))
		player:Kick("Connection error. Please rejoin.")
	end
end

-- Shared gatekeeping. Returns true if the request may reach the handler.
local function admit(name: string, player: Player, checks: { Check }, args: { any }, count: number): boolean
	if player.Parent ~= Players then
		return false
	end
	if not limiters[name]:Check(player) then
		log:Debug("Rate limited", name, "from", player.Name)
		return false
	end
	local ok, reason = Validate.args(checks, args, count)
	if not ok then
		addStrike(player, name, reason or "invalid arguments")
		return false
	end
	return true
end

function RemoteService.Init()
	-- The server is the sole author of remotes. Remove anything left in the place file.
	local existing = ReplicatedStorage:FindFirstChild(Net.FolderName)
	if existing then
		log:Warn("Removing pre-existing Remotes folder; remotes are created from Net.Definitions")
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = Net.FolderName

	for name, definition in Net.Definitions do
		if definition.Kind == "Event" then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
			events[name] = remote
		else
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
			functions[name] = remote
		end

		if definition.Direction == "ClientToServer" then
			local limit = definition.RateLimit or Config.Network.DefaultRateLimit
			limiters[name] = RateLimiter.new(limit.Capacity, limit.RefillPerSecond)
		end
	end

	-- Parent last so clients never observe a half-built folder.
	folder.Parent = ReplicatedStorage
end

function RemoteService.Start()
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:Reset(player)
		end
		strikes[player] = nil
	end)

	-- Unbound client->server remotes would otherwise queue requests forever.
	-- Deferred so every service's Start has had the chance to bind first.
	task.defer(function()
		for name, definition in Net.Definitions do
			if definition.Direction == "ClientToServer" and not bound[name] then
				log:Warn("No handler bound for", name, "- requests will be dropped")
				if definition.Kind == "Event" then
					events[name].OnServerEvent:Connect(function() end)
				else
					functions[name].OnServerInvoke = function()
						return nil
					end
				end
			end
		end
	end)
end

-- Binds a handler to a client->server RemoteEvent.
function RemoteService.OnEvent(name: string, checks: { Check }, handler: (Player, ...any) -> ())
	getDefinition(name, "Event", "ClientToServer")
	assert(not bound[name], "Handler already bound for " .. name)
	bound[name] = true

	events[name].OnServerEvent:Connect(function(player: Player, ...: any)
		local count = select("#", ...)
		local args = { ... }
		if not admit(name, player, checks, args, count) then
			return
		end
		local ok: boolean, err: any = pcall(handler, player, table.unpack(args, 1, count))
		if not ok then
			log:Error("Handler for", name, "errored:", err)
		end
	end)
end

-- Binds a handler to a client->server RemoteFunction.
-- Rejected or failed requests return nil to the client; errors are never leaked.
function RemoteService.OnInvoke(name: string, checks: { Check }, handler: (Player, ...any) -> ...any)
	getDefinition(name, "Function", "ClientToServer")
	assert(not bound[name], "Handler already bound for " .. name)
	bound[name] = true

	functions[name].OnServerInvoke = function(player: Player, ...: any): ...any
		local count = select("#", ...)
		local args = { ... }
		if not admit(name, player, checks, args, count) then
			return nil
		end
		local result = table.pack(pcall(handler, player, table.unpack(args, 1, count)))
		if not result[1] then
			log:Error("Handler for", name, "errored:", result[2])
			return nil
		end
		return table.unpack(result, 2, result.n)
	end
end

function RemoteService.FireClient(name: string, player: Player, ...: any)
	getDefinition(name, "Event", "ServerToClient")
	if player.Parent ~= Players then
		return
	end
	events[name]:FireClient(player, ...)
end

function RemoteService.FireClients(name: string, players: { Player }, ...: any)
	getDefinition(name, "Event", "ServerToClient")
	local remote = events[name]
	for _, player in players do
		if player.Parent == Players then
			remote:FireClient(player, ...)
		end
	end
end

function RemoteService.FireAllClients(name: string, ...: any)
	getDefinition(name, "Event", "ServerToClient")
	events[name]:FireAllClients(...)
end

-- Exposed for debugging/tests.
function RemoteService.GetStrikes(player: Player): number
	return strikes[player] or 0
end

return RemoteService
