--!strict
--[[
	DataService
	Persistent player profiles on DataStoreService with session locking.

	Record layout (one key per player, "u_<UserId>"):
	    { Data = Profile, Lock = { JobId, Time } | nil }

	Session locking prevents two servers from editing the same profile (which
	is how items get duplicated or progress gets lost):
	  * Load takes the lock with UpdateAsync. If another live server holds it,
	    we retry; a lock that hasn't been refreshed for LockStaleSeconds belongs
	    to a crashed server and may be taken over.
	  * Every save refreshes the lock and refuses to write if the lock was
	    taken by someone else.
	  * Leaving releases the lock; a rejoin on the same server waits for the
	    release to finish before loading.

	When the DataStore is unreachable (outage, or Studio without API access)
	the player gets a temporary profile that is never saved, and the client
	is told so.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local CosmeticCatalog = require(Shared.Data.CosmeticCatalog)
local SettingsSchema = require(Shared.Data.SettingsSchema)
local Progression = require(Shared.Logic.Progression)
local Logger = require(Shared.Utility.Logger)
local Signal = require(Shared.Utility.Signal)
local TableUtil = require(Shared.Utility.TableUtil)

local PlayerManager = require(script.Parent.PlayerManager)
local ReplicationService = require(script.Parent.ReplicationService)

local log = Logger.new("DataService")

export type Profile = {
	Version: number,
	Xp: number,
	Level: number,
	Credits: number,
	Stats: { [string]: number },
	Owned: { [string]: boolean },
	Equipped: { [string]: string },
	Settings: { [string]: any },
	TutorialDone: boolean,
	Supporter: boolean,
	Receipts: { string },
	FirstJoin: number,
	LastJoin: number,
}

type State = {
	Player: Player,
	Key: string,
	Data: Profile,
	Temporary: boolean,
	Dirty: boolean,
	Saving: boolean,
	SaveQueued: boolean,
	Released: boolean,
}

type Store = {
	UpdateAsync: (self: any, key: string, transform: (any) -> any) -> any,
}

local PROFILE_VERSION = 1

local DEFAULT_PROFILE: Profile = {
	Version = PROFILE_VERSION,
	Xp = 0,
	Level = 1,
	Credits = 0,
	Stats = {
		RoundsPlayed = 0,
		Wins = 0,
		CrewWins = 0,
		InfiltratorWins = 0,
		TimesInfiltrator = 0,
		TasksCompleted = 0,
		Escapes = 0,
		Revives = 0,
		Siphons = 0,
		CorrectVotes = 0,
		EvidenceRevealed = 0,
		Survived = 0,
		HazardsFixed = 0,
	},
	Owned = {},
	Equipped = table.clone(CosmeticCatalog.DefaultEquipped),
	Settings = table.clone(SettingsSchema.Defaults),
	TutorialDone = false,
	Supporter = false,
	Receipts = {},
	FirstJoin = 0,
	LastJoin = 0,
}

local DataService = {}

-- (player, profile)
DataService.ProfileLoaded = Signal.new()
-- (player, profile)
DataService.ProfileChanged = Signal.new()

local states: { [Player]: State } = {}
local pendingRelease: { [number]: boolean } = {}
local store: Store
local usingMock = false
local jobId = if game.JobId ~= "" then game.JobId else ("studio-" .. tostring(math.random(1, 1e9)))

---------------------------------------------------------------------------
-- Mock store for Studio without API access (same UpdateAsync contract)
---------------------------------------------------------------------------
local MockStore = {}
MockStore.__index = MockStore
function MockStore.new()
	return setmetatable({ _data = {} :: { [string]: any } }, MockStore)
end
function MockStore:UpdateAsync(key: string, transform: (any) -> any): any
	local current = TableUtil.deepCopy(self._data[key])
	local result = transform(current)
	if result ~= nil then
		self._data[key] = TableUtil.deepCopy(result)
	end
	return result
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Fills any missing fields from defaults (new fields added in updates).
local function reconcile(target: { [any]: any }, defaults: { [any]: any })
	for key, value in defaults do
		if target[key] == nil then
			target[key] = TableUtil.deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil and value[1] == nil then
			reconcile(target[key], value)
		end
	end
end

local function sanitizeLoaded(data: any): Profile
	local profile: any = if type(data) == "table" then data else {}
	reconcile(profile, DEFAULT_PROFILE)
	-- Drop settings that are no longer valid.
	for key, value in profile.Settings do
		local clean = SettingsSchema.sanitize(key, value)
		profile.Settings[key] = if clean ~= nil then clean else SettingsSchema.Defaults[key]
	end
	-- Equipped items must still exist and be unlocked.
	for slot, defaultId in CosmeticCatalog.DefaultEquipped do
		local item = CosmeticCatalog.get(profile.Equipped[slot] or "")
		if not item or item.Slot ~= slot or not CosmeticCatalog.isUnlocked(item, profile.Owned, profile.Level) then
			profile.Equipped[slot] = defaultId
		end
	end
	profile.Version = PROFILE_VERSION
	return profile :: Profile
end

local function waitForBudget()
	if usingMock then
		return
	end
	local deadline = os.clock() + 10
	while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) < 1 and os.clock() < deadline do
		task.wait(0.5)
	end
end

-- What the owning client sees of its profile (no receipts or internals).
local function clientView(profile: Profile)
	return {
		Level = profile.Level,
		Xp = profile.Xp,
		XpToNext = Progression.xpToNext(profile.Level),
		Credits = profile.Credits,
		Stats = profile.Stats,
		Owned = profile.Owned,
		Equipped = profile.Equipped,
		Settings = profile.Settings,
		TutorialDone = profile.TutorialDone,
		Supporter = profile.Supporter,
	}
end

local function publish(state: State)
	ReplicationService.SetPrivate(state.Player, Constants.PrivateKey.Profile, clientView(state.Data))
end

---------------------------------------------------------------------------
-- Load / save
---------------------------------------------------------------------------

local function load(player: Player)
	local userId = player.UserId
	local key = "u_" .. userId
	ReplicationService.SetPrivate(player, Constants.PrivateKey.DataStatus, "Loading")

	-- Same-server rejoin: let the previous session's release finish first.
	local waited = 0
	while pendingRelease[userId] and waited < 30 do
		task.wait(0.5)
		waited += 0.5
	end

	local settings = Config.Data
	local loadedData: any = nil
	local success = false
	local lockedElsewhere = false

	for attempt = 1, settings.LoadAttempts do
		if player.Parent ~= Players then
			return
		end
		waitForBudget()
		local blocked = false
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old: any)
				blocked = false
				local record = if type(old) == "table" then old else {}
				local lock = record.Lock
				if type(lock) == "table" and lock.JobId ~= jobId and os.time() - (lock.Time or 0) < settings.LockStaleSeconds then
					blocked = true
					return nil -- cancel: another live server owns this profile
				end
				record.Lock = { JobId = jobId, Time = os.time() }
				loadedData = record.Data
				return record
			end)
		end)
		if ok and not blocked then
			success = true
			break
		end
		lockedElsewhere = blocked
		log:Warn(string.format("Load attempt %d for %d failed: %s", attempt, userId, if ok then "locked by another server" else tostring(err)))
		task.wait(settings.LoadRetryDelay * attempt)
	end

	if player.Parent ~= Players then
		-- Left while loading: give the lock straight back.
		if success then
			pcall(function()
				store:UpdateAsync(key, function(old: any)
					if type(old) == "table" and type(old.Lock) == "table" and old.Lock.JobId == jobId then
						old.Lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return
	end

	if not success and lockedElsewhere then
		player:Kick("Your progress is still saving on another server. Please rejoin in a moment.")
		return
	end

	local temporary = not success
	local profile = sanitizeLoaded(loadedData)
	if profile.FirstJoin == 0 then
		profile.FirstJoin = os.time()
	end
	profile.LastJoin = os.time()

	local state: State = {
		Player = player,
		Key = key,
		Data = profile,
		Temporary = temporary,
		Dirty = false,
		Saving = false,
		SaveQueued = false,
		Released = false,
	}
	states[player] = state

	if temporary then
		log:Error("Using a temporary (unsaved) profile for", player.Name)
	end
	ReplicationService.SetPrivate(player, Constants.PrivateKey.DataStatus, if temporary then "Temporary" else "Ready")
	publish(state)
	DataService.ProfileLoaded:Fire(player, profile)
end

-- Writes the profile. Returns true on success. `release` gives up the lock.
local function save(state: State, release: boolean): boolean
	if state.Temporary or state.Released then
		return state.Temporary
	end
	if state.Saving then
		state.SaveQueued = true
		while state.Saving do
			task.wait(0.1)
		end
		if not release and not state.Dirty then
			return true
		end
	end
	state.Saving = true
	state.SaveQueued = false

	local stolen = false
	local success = false
	for attempt = 1, 3 do
		waitForBudget()
		local snapshot = TableUtil.deepCopy(state.Data)
		local ok, err = pcall(function()
			store:UpdateAsync(state.Key, function(old: any)
				stolen = false
				local record = if type(old) == "table" then old else {}
				if type(record.Lock) == "table" and record.Lock.JobId ~= jobId then
					stolen = true
					return nil
				end
				record.Data = snapshot
				record.Lock = if release then nil else { JobId = jobId, Time = os.time() }
				return record
			end)
		end)
		if ok and not stolen then
			success = true
			break
		end
		if stolen then
			break
		end
		log:Warn(string.format("Save attempt %d for %s failed: %s", attempt, state.Key, tostring(err)))
		task.wait(2 ^ attempt)
	end

	if stolen then
		-- Another server took over (e.g. after we were presumed crashed). Our copy is stale.
		log:Error("Session lock lost for", state.Key, "- not saving to avoid overwriting newer data")
		state.Released = true
	elseif success then
		state.Dirty = false
		if release then
			state.Released = true
		end
	end
	state.Saving = false
	return success
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok and result then
		store = result :: any
	end

	if RunService:IsStudio() then
		-- Probe: Studio without "Enable Studio Access to API Services" throws here.
		local probeOk = ok and pcall(function()
			(store :: any):GetAsync("__probe")
		end)
		if not probeOk then
			log:Warn("DataStores unavailable in Studio; using an in-memory store (progress is not saved)")
			store = MockStore.new() :: any
			usingMock = true
		end
	elseif not ok then
		log:Error("GetDataStore failed:", result)
		store = MockStore.new() :: any
		usingMock = true
	end
end

function DataService.Start()
	PlayerManager.SessionAdded:Connect(function(session)
		task.spawn(load, session.Player)
	end)
	for _, session in PlayerManager.GetSessions() do
		if not states[session.Player] then
			task.spawn(load, session.Player)
		end
	end

	PlayerManager.SessionRemoving:Connect(function(session)
		local player = session.Player
		local state = states[player]
		if not state then
			return
		end
		pendingRelease[player.UserId] = true
		task.spawn(function()
			save(state, true)
			states[player] = nil
			pendingRelease[player.UserId] = nil
		end)
	end)

	-- Autosave loop, staggered so requests don't burst.
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for _, state in table.clone(states) do
				if not state.Released then
					task.spawn(save, state, false)
					task.wait(1)
				end
			end
		end
	end)
end

function DataService.Shutdown()
	local remaining = 0
	for _, state in table.clone(states) do
		remaining += 1
		task.spawn(function()
			save(state, true)
			remaining -= 1
		end)
	end
	local deadline = os.clock() + 25
	while remaining > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

function DataService.GetProfile(player: Player): Profile?
	local state = states[player]
	return if state then state.Data else nil
end

function DataService.IsLoaded(player: Player): boolean
	return states[player] ~= nil
end

function DataService.IsTemporary(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.Temporary
end

-- Mutates a profile through `mutator`, marks it for saving and syncs the client.
function DataService.Update(player: Player, mutator: (Profile) -> ())
	local state = states[player]
	if not state or state.Released then
		return
	end
	mutator(state.Data)
	state.Dirty = true
	publish(state)
	DataService.ProfileChanged:Fire(player, state.Data)
end

-- Saves immediately (yields). Used after purchases.
function DataService.SaveNow(player: Player): boolean
	local state = states[player]
	if not state then
		return false
	end
	return save(state, false)
end

function DataService.IsUsingMock(): boolean
	return usingMock
end

return DataService
