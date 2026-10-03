--!strict
--[[
	LobbyService
	Ready system, countdown and automatic start.

	A countdown begins when enough players are present AND either
	  * at least ReadyRatioToStart of them are ready, or
	  * enough players have been waiting for AutoStartAfterSeconds, or
	  * a private-server host (or admin) presses Start.
	The countdown shortens when everyone is ready and cancels if the lobby
	drops below the minimum.

	Private servers: the server owner is the Host and may adjust match
	settings (infiltrator count, discussion/voting time, role reveal) and
	start with fewer players. Public servers use Roblox's own matchmaking to
	fill; this service just decides when a filled lobby begins.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local CosmeticCatalog = require(Shared.Data.CosmeticCatalog)
local Net = require(Shared.Net)
local Logger = require(Shared.Utility.Logger)
local Signal = require(Shared.Utility.Signal)
local Validate = require(Shared.Utility.Validate)

local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)
local PlayerManager = require(script.Parent.PlayerManager)
local RemoteService = require(script.Parent.RemoteService)
local ReplicationService = require(script.Parent.ReplicationService)

local log = Logger.new("LobbyService")

export type MatchSettings = {
	InfiltratorCount: number, -- 0 = automatic
	DiscussionSeconds: number,
	VotingSeconds: number,
	RevealOnConfine: string,
}

local LobbyService = {}

-- (players) countdown finished
LobbyService.StartRequested = Signal.new()

local ready: { [Player]: boolean } = {}
local countdownEndsAt: number? = nil
local enoughSince: number? = nil
local forceStart = false
local isPrivate = game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
local hostUserId = if isPrivate then game.PrivateServerOwnerId else 0

local settings: MatchSettings = {
	InfiltratorCount = 0,
	DiscussionSeconds = Config.Meeting.DiscussionSeconds,
	VotingSeconds = Config.Meeting.VotingSeconds,
	RevealOnConfine = Config.Meeting.RevealOnConfine,
}

local SETTING_RULES: { [string]: (any) -> any } = {
	InfiltratorCount = function(v)
		return if type(v) == "number" and v % 1 == 0 and v >= 0 and v <= 3 then v else nil
	end,
	DiscussionSeconds = function(v)
		return if type(v) == "number" and v == v then math.clamp(math.floor(v / 15) * 15, 30, 120) else nil
	end,
	VotingSeconds = function(v)
		return if type(v) == "number" and v == v then math.clamp(math.floor(v / 5) * 5, 15, 60) else nil
	end,
	RevealOnConfine = function(v)
		return if v == "Faction" or v == "None" then v else nil
	end,
}

local function isHost(player: Player): boolean
	if isPrivate and player.UserId == hostUserId then
		return true
	end
	-- Studio playtests: the first player acts as host for testing.
	return RunService:IsStudio() and Config.Admin.AllowStudioAdmins
end

local function requiredPlayers(): number
	if RunService:IsStudio() and Config.Players.AllowSoloInStudio then
		return 1
	end
	if isPrivate then
		return math.min(Config.Lobby.PrivateServerMinPlayers, Config.Players.MinPlayers)
	end
	return Config.Players.MinPlayers
end

-- Loaded players waiting in the lobby (everyone, when no match is running).
local function eligiblePlayers(): { Player }
	local list = {}
	for _, player in PlayerManager.GetLoadedPlayers() do
		if not MatchService.GetParticipant(player) then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a, b)
		-- Ready players first, then by join order (stable).
		local ra, rb = ready[a] == true, ready[b] == true
		if ra ~= rb then
			return ra
		end
		local sa, sb = PlayerManager.GetSession(a), PlayerManager.GetSession(b)
		return (if sa then sa.JoinedAt else 0) < (if sb then sb.JoinedAt else 0)
	end)
	return list
end

local lastSignature = ""

local function publish(status: string)
	local entries = {}
	for _, player in eligiblePlayers() do
		local profile = DataService.GetProfile(player)
		local titleItem = profile and CosmeticCatalog.get(profile.Equipped.Title or "")
		table.insert(entries, {
			UserId = player.UserId,
			Name = player.DisplayName,
			Ready = ready[player] == true,
			Level = if profile then profile.Level else 1,
			Title = if titleItem then titleItem.Name else "",
			IsHost = isPrivate and player.UserId == hostUserId,
		})
	end
	-- Skip identical rebroadcasts (the tick runs twice a second).
	local parts: { string } = {
		status,
		tostring(countdownEndsAt),
		tostring(settings.InfiltratorCount),
		tostring(settings.DiscussionSeconds),
		tostring(settings.VotingSeconds),
		settings.RevealOnConfine,
	}
	for _, entry in entries do
		table.insert(parts, string.format("%d:%s:%d:%s", entry.UserId, tostring(entry.Ready), entry.Level, entry.Title))
	end
	local signature = table.concat(parts, "|")
	if signature == lastSignature then
		return
	end
	lastSignature = signature

	ReplicationService.SetPublic(Constants.PublicKey.Lobby, {
		Players = entries,
		Required = requiredPlayers(),
		Max = Config.Players.MaxPlayers,
		CountdownEndsAt = countdownEndsAt,
		IsPrivate = isPrivate,
		HostUserId = hostUserId,
		Settings = settings,
		Status = status,
	})
end

local function tick()
	if not MatchService.IsState(Constants.RoundState.Lobby) then
		countdownEndsAt = nil
		enoughSince = nil
		return
	end
	local players = eligiblePlayers()
	local required = requiredPlayers()
	local now = workspace:GetServerTimeNow()

	if #players < required and not (forceStart and #players >= 1) then
		countdownEndsAt = nil
		enoughSince = nil
		forceStart = false
		publish(string.format("Waiting for crew (%d/%d)", #players, required))
		return
	end

	enoughSince = enoughSince or now
	local readyCount = 0
	for _, player in players do
		if ready[player] then
			readyCount += 1
		end
	end
	local allReady = readyCount == #players
	local lobbyConfig = Config.Lobby

	if not countdownEndsAt then
		local readyEnough = readyCount / #players >= lobbyConfig.ReadyRatioToStart
		local waitedEnough = now - (enoughSince :: number) >= lobbyConfig.AutoStartAfterSeconds
		if readyEnough or waitedEnough or forceStart then
			local seconds = if allReady or forceStart then lobbyConfig.AllReadyCountdownSeconds else lobbyConfig.CountdownSeconds
			countdownEndsAt = now + seconds
		end
	elseif allReady and (countdownEndsAt :: number) - now > lobbyConfig.AllReadyCountdownSeconds then
		countdownEndsAt = now + lobbyConfig.AllReadyCountdownSeconds
	end

	if countdownEndsAt and now >= countdownEndsAt then
		local participants = {}
		for i, player in players do
			if i <= Config.Players.MaxPlayers then
				table.insert(participants, player)
			end
		end
		countdownEndsAt = nil
		enoughSince = nil
		forceStart = false
		table.clear(ready)
		publish("Launching")
		log:Info("Starting match with", #participants, "players")
		LobbyService.StartRequested:Fire(participants)
		return
	end

	if countdownEndsAt then
		publish("Departure imminent")
	else
		local autoIn = math.max(0, math.ceil(lobbyConfig.AutoStartAfterSeconds - (now - (enoughSince :: number))))
		publish(string.format("Ready up! %d/%d ready - auto-launch in %ds", readyCount, #players, autoIn))
	end
end

function LobbyService.Start()
	RemoteService.OnEvent(Net.Names.SetReady, { Validate.boolean() }, function(player: Player, value: boolean)
		if not MatchService.IsState(Constants.RoundState.Lobby) or MatchService.GetParticipant(player) then
			return
		end
		if value then
			ready[player] = true
		else
			ready[player] = nil
		end
		tick()
	end)

	RemoteService.OnEvent(
		Net.Names.HostSetting,
		{ Validate.oneOf({ "InfiltratorCount", "DiscussionSeconds", "VotingSeconds", "RevealOnConfine" }), Validate.primitive(20) },
		function(player: Player, key: string, value: any)
			if not isHost(player) or not MatchService.IsState(Constants.RoundState.Lobby) then
				return
			end
			local clean = SETTING_RULES[key](value)
			if clean ~= nil then
				(settings :: any)[key] = clean
				tick()
			end
		end
	)

	RemoteService.OnEvent(Net.Names.HostStart, {}, function(player: Player)
		if isHost(player) and MatchService.IsState(Constants.RoundState.Lobby) then
			forceStart = true
			tick()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok: boolean, err: any = pcall(tick)
			if not ok then
				log:Error("Lobby tick failed:", err)
			end
		end
	end)
end

-- Used by admin tools to bypass the minimum.
function LobbyService.ForceStart()
	forceStart = true
	tick()
end

function LobbyService.GetSettings(): MatchSettings
	return settings
end

function LobbyService.IsPrivateServer(): boolean
	return isPrivate
end

return LobbyService
