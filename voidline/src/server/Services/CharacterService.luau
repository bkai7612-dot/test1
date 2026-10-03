--!strict
--[[
	CharacterService
	Server-controlled character spawning (CharacterAutoLoads is off).

	  * Players spawn in the lobby when they join and after each round.
	  * Eliminated participants (lost/confined) have no character: they are
	    Signal Ghosts and spectate until the round resets.
	  * If an active participant's character dies anyway (fell out, reset
	    exploit), they are respawned straight back aboard the ship.

	Also owns per-character setup shared by other systems: hiding default
	name tags (custom nameplates replace them), base walk speed, the freeze
	flag used during reveals and musters, and the "Char:<UserId>" anchor
	used for player-targeted interactions.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Logger = require(Shared.Utility.Logger)
local Signal = require(Shared.Utility.Signal)

local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local PlayerManager = require(script.Parent.PlayerManager)

local log = Logger.new("CharacterService")

local CharacterService = {}

-- (player, character)
CharacterService.CharacterSpawned = Signal.new()

local spawning: { [Player]: boolean } = {}
local intentionalRemoval: { [Player]: boolean } = {}
local frozen: { [Player]: boolean } = {}

local function anchorId(player: Player): string
	return "Char:" .. player.UserId
end

local function applyMovement(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local isFrozen = frozen[player] == true
	character:SetAttribute(Constants.Attribute.Frozen, isFrozen)
	humanoid.WalkSpeed = if isFrozen then 0 else Config.Movement.WalkSpeed
	humanoid.JumpHeight = if isFrozen then 0 else 6
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root or character.Parent == nil then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.UseJumpPower = false
	applyMovement(player, character)
	MapService.SetAnchor(anchorId(player), root)

	humanoid.Died:Connect(function()
		if intentionalRemoval[player] then
			return
		end
		task.wait(Config.Players.LobbyRespawnSeconds)
		if player.Parent ~= Players or player.Character ~= character then
			return
		end
		local p = MatchService.GetParticipant(player)
		if p and p.Life ~= Constants.LifeState.Alive and p.Life ~= Constants.LifeState.Downed then
			CharacterService.Despawn(player)
			return
		end
		CharacterService.Spawn(player)
		if p and MatchService.IsRunning() then
			-- Back aboard: muster room is always safe to drop into.
			local ring = MapService.SpawnRing("CentralOps", 8, 10)
			MapService.Teleport(player, ring[math.random(1, #ring)])
		end
	end)

	CharacterService.CharacterSpawned:Fire(player, character)
end

-- Loads a fresh character (yields). Spawns at the lobby SpawnLocation.
function CharacterService.Spawn(player: Player)
	if spawning[player] or player.Parent ~= Players then
		return
	end
	spawning[player] = true
	intentionalRemoval[player] = true
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	intentionalRemoval[player] = nil
	spawning[player] = nil
	if not ok then
		log:Warn("LoadCharacter failed for", player.Name, err)
	end
	MapService.MarkTeleported(player)
end

-- Removes the character (ghosts have no body).
function CharacterService.Despawn(player: Player)
	local character = player.Character
	MapService.SetAnchor(anchorId(player), nil)
	if character then
		intentionalRemoval[player] = true
		player.Character = nil
		character:Destroy()
		intentionalRemoval[player] = nil
	end
end

function CharacterService.SetFrozen(player: Player, isFrozen: boolean)
	if isFrozen then
		frozen[player] = true
	else
		frozen[player] = nil
	end
	local character = player.Character
	if character then
		applyMovement(player, character)
	end
end

function CharacterService.IsFrozen(player: Player): boolean
	return frozen[player] == true
end

function CharacterService.GetRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function CharacterService.GetHumanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function CharacterService.Init()
	Players.CharacterAutoLoads = false
end

function CharacterService.Start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end

	PlayerManager.SessionAdded:Connect(function(session)
		watch(session.Player)
		task.spawn(CharacterService.Spawn, session.Player)
	end)
	for _, session in PlayerManager.GetSessions() do
		watch(session.Player)
		if not session.Player.Character then
			task.spawn(CharacterService.Spawn, session.Player)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		MapService.SetAnchor(anchorId(player), nil)
		spawning[player] = nil
		intentionalRemoval[player] = nil
		frozen[player] = nil
	end)
end

return CharacterService
