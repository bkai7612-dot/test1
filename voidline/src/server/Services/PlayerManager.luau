--!strict
--[[
	PlayerManager
	Tracks a server-side session for every connected player.

	Lifecycle:
	  PlayerAdded       -> session created (Status = Connecting)   -> SessionAdded
	  ClientReady       -> IsLoaded = true  (Status = Lobby)       -> PlayerLoaded
	  PlayerRemoving    -> per-player Maid cleaned, session gone   -> SessionRemoving

	Other services should hang per-player cleanup on PlayerManager.GetMaid(player)
	so it runs automatically when the player leaves.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local Logger = require(Shared.Utility.Logger)
local Maid = require(Shared.Utility.Maid)
local Signal = require(Shared.Utility.Signal)

local RemoteService = require(script.Parent.RemoteService)
local ReplicationService = require(script.Parent.ReplicationService)

type PlayerSession = Types.PlayerSession
type Maid = Maid.Maid

local log = Logger.new("PlayerManager")

local PlayerManager = {}

-- (session: PlayerSession)
PlayerManager.SessionAdded = Signal.new()
-- (session: PlayerSession) client has booted and can receive UI/gameplay data
PlayerManager.PlayerLoaded = Signal.new()
-- (session: PlayerSession) fired before the session is discarded
PlayerManager.SessionRemoving = Signal.new()

local sessions: { [Player]: PlayerSession } = {}
local maids: { [Player]: Maid } = {}

local function publishPlayerCount()
	local count = 0
	for _ in sessions do
		count += 1
	end
	ReplicationService.SetPublic(Constants.PublicKey.PlayerCount, count)
end

-- What the owning client is allowed to see about its own session.
local function publishSession(session: PlayerSession)
	ReplicationService.SetPrivate(session.Player, Constants.PrivateKey.Session, {
		Status = session.Status,
		IsLoaded = session.IsLoaded,
		JoinedAt = session.JoinedAt,
	})
end

local function onPlayerAdded(player: Player)
	if sessions[player] or player.Parent ~= Players then
		return
	end

	local session: PlayerSession = {
		Player = player,
		UserId = player.UserId,
		JoinedAt = workspace:GetServerTimeNow(),
		Status = Constants.PlayerStatus.Connecting :: Types.PlayerStatus,
		IsLoaded = false,
	}
	sessions[player] = session

	local maid = Maid.new()
	maids[player] = maid

	-- Surface clients that never finish booting (bad connection, script error).
	maid:Give(task.delay(Config.Players.LoadWarningSeconds, function()
		if sessions[player] == session and not session.IsLoaded then
			log:Warn(player.Name, "has not reported ClientReady after", Config.Players.LoadWarningSeconds, "s")
		end
	end))

	log:Info("Session created:", player.Name, player.UserId)
	publishSession(session)
	publishPlayerCount()
	PlayerManager.SessionAdded:Fire(session)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end

	PlayerManager.SessionRemoving:Fire(session)

	local maid = maids[player]
	maids[player] = nil
	if maid then
		maid:Cleanup()
	end

	sessions[player] = nil
	log:Info("Session ended:", player.Name, player.UserId)
	publishPlayerCount()
end

local function onClientReady(player: Player)
	local session = sessions[player]
	if not session or session.IsLoaded then
		-- Duplicate ready signals are harmless; ignore them.
		return
	end
	session.IsLoaded = true
	session.Status = Constants.PlayerStatus.Lobby :: Types.PlayerStatus
	log:Info("Client loaded:", player.Name)
	publishSession(session)
	PlayerManager.PlayerLoaded:Fire(session)
end

function PlayerManager.Start()
	RemoteService.OnEvent(Net.Names.ClientReady, {}, onClientReady)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Players who joined before this script ran (common in Studio).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function PlayerManager.GetSession(player: Player): PlayerSession?
	return sessions[player]
end

-- Array of all sessions. Order is not guaranteed.
function PlayerManager.GetSessions(): { PlayerSession }
	local list = {}
	for _, session in sessions do
		table.insert(list, session)
	end
	return list
end

function PlayerManager.GetLoadedPlayers(): { Player }
	local list = {}
	for player, session in sessions do
		if session.IsLoaded then
			table.insert(list, player)
		end
	end
	return list
end

function PlayerManager.GetPlayerCount(): number
	local count = 0
	for _ in sessions do
		count += 1
	end
	return count
end

-- True if the player is connected and has a live session.
function PlayerManager.IsActive(player: Player): boolean
	return sessions[player] ~= nil and player.Parent == Players
end

function PlayerManager.SetStatus(player: Player, status: Types.PlayerStatus)
	local session = sessions[player]
	if not session or session.Status == status then
		return
	end
	session.Status = status
	publishSession(session)
end

-- Per-player Maid, cleaned automatically when the player leaves.
function PlayerManager.GetMaid(player: Player): Maid?
	return maids[player]
end

return PlayerManager
