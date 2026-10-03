--!strict
--[[
	ClientController
	Keeps a local, read-only mirror of the state the server lets this client
	see, and turns server pushes into Signals other controllers can use.

	    ClientController.PublicChanged:Connect(function(key, value, old) ... end)
	    ClientController.GetPublic("RoundState")

	Nothing in here is authoritative. The mirror exists only to drive UI and
	effects; every gameplay decision happens on the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local Logger = require(Shared.Utility.Logger)
local Signal = require(Shared.Utility.Signal)

local log = Logger.new("ClientController")

local SNAPSHOT_ATTEMPTS = 4

local ClientController = {}

-- (key: string, value: any, oldValue: any)
ClientController.PublicChanged = Signal.new()
ClientController.PrivateChanged = Signal.new()
-- (notification: Types.Notification)
ClientController.Notified = Signal.new()
-- () fired once the first snapshot has been applied
ClientController.Synced = Signal.new()
-- (kind: string, data: table) one-shot cues from the server (VFX/audio/HUD)
ClientController.ShipEvent = Signal.new()

local publicState: { [string]: any } = {}
local privateState: { [string]: any } = {}
local publicVersion = 0
local privateVersion = 0
local isSynced = false

local function setKey(store: { [string]: any }, changed: Signal.Signal, key: string, value: any)
	local old = store[key]
	store[key] = value
	if old ~= value or type(value) == "table" then
		changed:Fire(key, value, old)
	end
end

-- Replaces a whole store, firing change events for added, changed and removed keys.
local function replaceStore(store: { [string]: any }, changed: Signal.Signal, incoming: { [string]: any })
	for key in table.clone(store) do
		if incoming[key] == nil then
			setKey(store, changed, key, nil)
		end
	end
	for key, value in incoming do
		setKey(store, changed, key, value)
	end
end

local function isValidNotification(value: any): boolean
	return type(value) == "table" and type(value.Text) == "string" and type(value.Kind) == "string"
end

local function applySnapshot(snapshot: Types.StateSnapshot)
	-- Only apply a scope if the snapshot is newer than what live events already gave us.
	if snapshot.PublicVersion > publicVersion then
		publicVersion = snapshot.PublicVersion
		replaceStore(publicState, ClientController.PublicChanged, snapshot.Public)
	end
	if snapshot.PrivateVersion > privateVersion then
		privateVersion = snapshot.PrivateVersion
		replaceStore(privateState, ClientController.PrivateChanged, snapshot.Private)
	end
end

local function fetchSnapshot()
	local remote = Net.getFunction(Net.Names.RequestSnapshot)
	for attempt = 1, SNAPSHOT_ATTEMPTS do
		local ok, result = pcall(remote.InvokeServer, remote)
		if ok and type(result) == "table" then
			applySnapshot(result :: Types.StateSnapshot)
			isSynced = true
			ClientController.Synced:Fire()
			log:Debug("Snapshot applied", "public v" .. publicVersion, "private v" .. privateVersion)
			return
		end
		log:Warn("Snapshot attempt", attempt, "failed:", if ok then "empty response" else result)
		task.wait(2 ^ attempt)
	end
	log:Error("Could not sync state with server")
end

function ClientController.Init()
	-- Connect listeners first so no update is missed while the snapshot is in flight.
	Net.getEvent(Net.Names.PublicStateChanged).OnClientEvent:Connect(function(key: any, value: any, version: any)
		if type(key) ~= "string" or type(version) ~= "number" or version <= publicVersion then
			return
		end
		publicVersion = version
		setKey(publicState, ClientController.PublicChanged, key, value)
	end)

	Net.getEvent(Net.Names.PrivateStateChanged).OnClientEvent:Connect(function(key: any, value: any, version: any)
		if type(key) ~= "string" or type(version) ~= "number" or version <= privateVersion then
			return
		end
		privateVersion = version
		setKey(privateState, ClientController.PrivateChanged, key, value)
	end)

	Net.getEvent(Net.Names.Notify).OnClientEvent:Connect(function(notification: any)
		if isValidNotification(notification) then
			ClientController.Notified:Fire(notification)
		end
	end)

	Net.getEvent(Net.Names.ShipEvent).OnClientEvent:Connect(function(kind: any, data: any)
		if type(kind) == "string" then
			ClientController.ShipEvent:Fire(kind, if type(data) == "table" then data else {})
		end
	end)
end

function ClientController.Start()
	task.spawn(fetchSnapshot)
end

-- Convenience accessors used across controllers and screens.
function ClientController.GetRoundState(): string
	return publicState.RoundState or "LOBBY"
end

-- This player's participant entry in the public roster, if any.
function ClientController.IsParticipant(): boolean
	return privateState.Life ~= nil
end

-- Tells the server this client finished booting. Called by ClientMain.
function ClientController.SignalReady()
	Net.getEvent(Net.Names.ClientReady):FireServer()
end

function ClientController.GetPublic(key: string): any
	return publicState[key]
end

function ClientController.GetPrivate(key: string): any
	return privateState[key]
end

function ClientController.IsSynced(): boolean
	return isSynced
end

return ClientController
