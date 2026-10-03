--!strict
--[[
	Net
	Single source of truth for every RemoteEvent / RemoteFunction in the game.

	The SERVER creates the instances at boot (RemoteService) from this table;
	nothing is authored in the place file, so client and server can never drift.

	Rules:
	  * ClientToServer remotes are *requests*. The server validates and decides.
	  * ServerToClient remotes carry only data the receiving client may see.
	  * Never use RemoteFunction:InvokeClient (a client can hang the server).
	  * Every ClientToServer remote gets a rate limit (explicit or default).

	To add a remote: add an entry below, then bind it on the server with
	RemoteService.OnEvent / OnInvoke and use Net.getEvent / Net.getFunction
	on the client.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type RemoteKind = "Event" | "Function"
export type Direction = "ClientToServer" | "ServerToClient"
export type RateLimit = { Capacity: number, RefillPerSecond: number }
export type RemoteDefinition = {
	Kind: RemoteKind,
	Direction: Direction,
	RateLimit: RateLimit?,
}

local CLIENT_WAIT_TIMEOUT = 30

local Definitions: { [string]: RemoteDefinition } = {
	-- Client -> Server ------------------------------------------------------
	-- Client finished booting its controllers.
	ClientReady = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 2, RefillPerSecond = 0.1 } },
	-- Client asks for a full copy of the state it is allowed to see.
	RequestSnapshot = { Kind = "Function", Direction = "ClientToServer", RateLimit = { Capacity = 3, RefillPerSecond = 0.5 } },
	-- Admin-only server inspection. Non-admins get nil.
	DebugQuery = { Kind = "Function", Direction = "ClientToServer", RateLimit = { Capacity = 5, RefillPerSecond = 1 } },
	-- Admin-only commands (start round, give credits, ...). Non-admins get nil.
	AdminCommand = { Kind = "Function", Direction = "ClientToServer", RateLimit = { Capacity = 10, RefillPerSecond = 3 } },

	-- Lobby
	SetReady = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 4, RefillPerSecond = 1 } },
	HostSetting = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 6, RefillPerSecond = 2 } },
	HostStart = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 2, RefillPerSecond = 0.5 } },

	-- Interactions (hold-to-use prompts). The server times every hold itself.
	InteractBegin = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 8, RefillPerSecond = 4 } },
	InteractCancel = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 8, RefillPerSecond = 4 } },
	InteractComplete = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 8, RefillPerSecond = 4 } },
	MinigameSubmit = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 3, RefillPerSecond = 1 } },
	MinigameCancel = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 3, RefillPerSecond = 1 } },

	-- Infiltrator abilities. Rejected silently for anyone who isn't one.
	Sabotage = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 3, RefillPerSecond = 0.5 } },
	Spoof = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 2, RefillPerSecond = 0.2 } },

	-- Meetings and evidence
	MeetingAction = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 6, RefillPerSecond = 2 } },
	ShareEvidence = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 4, RefillPerSecond = 1 } },
	GhostWhisper = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 2, RefillPerSecond = 0.2 } },
	EmergencyAlert = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 2, RefillPerSecond = 0.2 } },

	-- Meta (progression, cosmetics, settings)
	PurchaseItem = { Kind = "Function", Direction = "ClientToServer", RateLimit = { Capacity = 3, RefillPerSecond = 1 } },
	EquipItem = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 6, RefillPerSecond = 2 } },
	SaveSetting = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 20, RefillPerSecond = 5 } },
	TutorialComplete = { Kind = "Event", Direction = "ClientToServer", RateLimit = { Capacity = 2, RefillPerSecond = 0.1 } },

	-- Server -> Client ------------------------------------------------------
	-- (key, value, version) broadcast to all clients.
	PublicStateChanged = { Kind = "Event", Direction = "ServerToClient" },
	-- (key, value, version) sent ONLY to the player the data belongs to.
	PrivateStateChanged = { Kind = "Event", Direction = "ServerToClient" },
	-- (Types.Notification) toast/subtitle text.
	Notify = { Kind = "Event", Direction = "ServerToClient" },
	-- (kind: string, data: table) one-shot cues for audio/VFX/HUD (whispers, completions, ...).
	ShipEvent = { Kind = "Event", Direction = "ServerToClient" },
	-- (sessionId, kind, challenge) open a mini-game; (sessionId, success, reason) close it.
	MinigameStart = { Kind = "Event", Direction = "ServerToClient" },
	MinigameResult = { Kind = "Event", Direction = "ServerToClient" },
}

local Net = {}

Net.FolderName = "Remotes"
Net.Definitions = table.freeze(Definitions)

-- Name constants so typos fail loudly at require time instead of silently.
local names: { [string]: string } = {}
for name in Definitions do
	names[name] = name
end
Net.Names = table.freeze(names)

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(Net.FolderName)
		assert(folder and folder:IsA("Folder"), "Remotes folder not created yet (RemoteService.Init must run first)")
		return folder
	end
	local folder = ReplicatedStorage:WaitForChild(Net.FolderName, CLIENT_WAIT_TIMEOUT)
	assert(folder and folder:IsA("Folder"), "Timed out waiting for Remotes folder")
	return folder
end

local function getRemote(name: string, className: string): Instance
	local definition = Definitions[name]
	assert(definition, "Unknown remote: " .. tostring(name))
	local folder = getFolder()
	local remote = if RunService:IsServer()
		then folder:FindFirstChild(name)
		else folder:WaitForChild(name, CLIENT_WAIT_TIMEOUT)
	assert(remote and remote:IsA(className), string.format("Remote %s missing or not a %s", name, className))
	return remote
end

function Net.getEvent(name: string): RemoteEvent
	return getRemote(name, "RemoteEvent") :: RemoteEvent
end

function Net.getFunction(name: string): RemoteFunction
	return getRemote(name, "RemoteFunction") :: RemoteFunction
end

return Net
