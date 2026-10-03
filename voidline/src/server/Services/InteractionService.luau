--!strict
--[[
	InteractionService
	Server-authoritative hold-to-use interactions.

	Systems register interactions with a visibility rule and handlers. Each
	player receives (privately) only the interactions currently visible to
	them; the client turns those into ProximityPrompts. Because visibility is
	computed per player on the server, role-specific actions (e.g. siphon)
	are never sent to players who shouldn't have them.

	The client only *requests*:
	  InteractBegin(id)    - prompt hold started
	  InteractComplete(id) - prompt hold finished
	  InteractCancel(id)   - released early
	The server checks visibility, range (from its own character positions),
	line of sight, game rules (CanBegin) and times the hold itself. A client
	that skips the hold or fires from across the map gets nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local Logger = require(Shared.Utility.Logger)
local Validate = require(Shared.Utility.Validate)

local CharacterService = require(script.Parent.CharacterService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local PlayerManager = require(script.Parent.PlayerManager)
local RemoteService = require(script.Parent.RemoteService)
local ReplicationService = require(script.Parent.ReplicationService)

local log = Logger.new("InteractionService")

export type Def = {
	Id: string,
	Anchor: string,
	Action: string,
	Object: string,
	Hold: number,
	Key: number?, -- 1 = primary (E), 2 = secondary (F), 3 = tertiary (R)
	Range: number?,
	LineOfSight: boolean?,
	Visible: (player: Player) -> boolean,
	CanBegin: ((player: Player) -> (boolean, string?))?,
	OnBegin: ((player: Player) -> ())?,
	OnCancel: ((player: Player) -> ())?,
	OnComplete: (player: Player) -> (),
}

type Hold = { Id: string, StartedAt: number }

local InteractionService = {}

local defs: { [string]: Def } = {}
local holds: { [Player]: Hold } = {}
local lastSignature: { [Player]: string } = {}
local refreshQueued = false

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function inRange(player: Player, def: Def): boolean
	local root = CharacterService.GetRoot(player)
	local anchor = MapService.GetAnchor(def.Anchor)
	if not root or not anchor or not anchor.Parent then
		return false
	end
	local range = (def.Range or Config.Objectives.InteractRange) + Config.Objectives.RangeTolerance
	return (root.Position - anchor.Position).Magnitude <= range
end

local function hasLineOfSight(player: Player, def: Def): boolean
	if def.LineOfSight == false then
		return true
	end
	local root = CharacterService.GetRoot(player)
	local anchor = MapService.GetAnchor(def.Anchor)
	if not root or not anchor then
		return false
	end
	local exclude: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local anchorModel = anchor:FindFirstAncestorWhichIsA("Model")
	table.insert(exclude, anchorModel or anchor)
	rayParams.FilterDescendantsInstances = exclude
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local result = workspace:Raycast(origin, anchor.Position - origin, rayParams)
	return result == nil
end

local function isVisible(player: Player, def: Def): boolean
	local ok, visible = pcall(def.Visible, player)
	return ok and visible == true
end

---------------------------------------------------------------------------
-- Replication of visible interactions
---------------------------------------------------------------------------

local function refreshPlayer(player: Player)
	if player.Parent ~= Players then
		return
	end
	local entries: { [string]: Types.InteractionEntry } = {}
	local ids = {}
	for id, def in defs do
		if isVisible(player, def) then
			entries[id] = {
				Anchor = def.Anchor,
				Action = def.Action,
				Object = def.Object,
				Hold = def.Hold,
				Key = def.Key or 1,
				Range = def.Range or Config.Objectives.InteractRange,
			}
			table.insert(ids, id .. "|" .. def.Action .. "|" .. def.Object .. "|" .. def.Hold)
		end
	end
	table.sort(ids)
	local signature = table.concat(ids, ";")
	if signature == lastSignature[player] then
		return
	end
	lastSignature[player] = signature
	ReplicationService.SetPrivate(player, Constants.PrivateKey.Interactions, entries)
end

local function refreshAllNow()
	refreshQueued = false
	for _, player in PlayerManager.GetLoadedPlayers() do
		refreshPlayer(player)
	end
end

-- Recomputes visible interactions for everyone (coalesced to once per frame).
function InteractionService.Refresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(refreshAllNow)
end

function InteractionService.RefreshPlayer(player: Player)
	refreshPlayer(player)
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

function InteractionService.Register(def: Def)
	defs[def.Id] = def
	InteractionService.Refresh()
end

function InteractionService.Unregister(id: string)
	if defs[id] then
		defs[id] = nil
		for player, hold in holds do
			if hold.Id == id then
				holds[player] = nil
			end
		end
		InteractionService.Refresh()
	end
end

function InteractionService.UnregisterPrefix(prefix: string)
	for id in table.clone(defs) do
		if string.sub(id, 1, #prefix) == prefix then
			InteractionService.Unregister(id)
		end
	end
end

function InteractionService.Get(id: string): Def?
	return defs[id]
end

---------------------------------------------------------------------------
-- Holds
---------------------------------------------------------------------------

function InteractionService.IsHolding(player: Player, id: string): boolean
	local hold = holds[player]
	return hold ~= nil and hold.Id == id
end

function InteractionService.GetHolders(id: string): { Player }
	local list = {}
	for player, hold in holds do
		if hold.Id == id then
			table.insert(list, player)
		end
	end
	return list
end

-- Cancels whatever `player` is holding (downed, muster, teleported...).
function InteractionService.CancelPlayer(player: Player)
	local hold = holds[player]
	if not hold then
		return
	end
	holds[player] = nil
	local def = defs[hold.Id]
	if def and def.OnCancel then
		task.spawn(def.OnCancel, player)
	end
end

function InteractionService.CancelAll()
	for player in table.clone(holds) do
		InteractionService.CancelPlayer(player)
	end
end

local function reject(player: Player, reason: string?)
	if reason then
		NotifyService.Send(player, reason, "Warning", 2.5)
	end
	NotifyService.Cue(player, "InteractRejected", {})
end

local function onBegin(player: Player, id: string)
	local def = defs[id]
	if not def or not isVisible(player, def) then
		return
	end
	if CharacterService.IsFrozen(player) then
		return
	end
	if not inRange(player, def) then
		reject(player, "Too far away.")
		return
	end
	if not hasLineOfSight(player, def) then
		reject(player, "Something is in the way.")
		return
	end
	if def.CanBegin then
		local ok, allowed, reason = pcall(def.CanBegin, player)
		if not ok then
			log:Error("CanBegin for", id, "errored:", allowed)
			return
		end
		if not allowed then
			reject(player, reason)
			return
		end
	end
	-- One hold at a time; starting another cancels the previous.
	if holds[player] then
		InteractionService.CancelPlayer(player)
	end
	holds[player] = { Id = id, StartedAt = os.clock() }
	if def.OnBegin then
		def.OnBegin(player)
	end
end

local function onCancel(player: Player, id: string)
	local hold = holds[player]
	if hold and hold.Id == id then
		InteractionService.CancelPlayer(player)
	end
end

local function onComplete(player: Player, id: string)
	local def = defs[id]
	local hold = holds[player]
	if not def then
		holds[player] = nil
		return
	end
	if def.Hold <= 0 and (not hold or hold.Id ~= id) then
		-- Instant interactions may arrive without a separate begin.
		onBegin(player, id)
		hold = holds[player]
	end
	if not hold or hold.Id ~= id then
		return
	end
	local elapsed = os.clock() - hold.StartedAt
	if elapsed < def.Hold * Config.Objectives.MinHoldRatio then
		log:Debug(player.Name, "completed", id, "too quickly:", elapsed)
		InteractionService.CancelPlayer(player)
		return
	end
	if not isVisible(player, def) or not inRange(player, def) then
		InteractionService.CancelPlayer(player)
		return
	end
	holds[player] = nil
	local ok: boolean, err: any = pcall(def.OnComplete, player)
	if not ok then
		log:Error("OnComplete for", id, "errored:", err)
	end
end

function InteractionService.Start()
	local idCheck = { Validate.string(80) }
	RemoteService.OnEvent(Net.Names.InteractBegin, idCheck, onBegin)
	RemoteService.OnEvent(Net.Names.InteractCancel, idCheck, onCancel)
	RemoteService.OnEvent(Net.Names.InteractComplete, idCheck, onComplete)

	PlayerManager.PlayerLoaded:Connect(function(session)
		lastSignature[session.Player] = nil
		refreshPlayer(session.Player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		InteractionService.CancelPlayer(player)
		lastSignature[player] = nil
	end)

	-- Visibility rules depend on round state and life state.
	MatchService.StateChanged:Connect(InteractionService.Refresh)
	MatchService.LifeChanged:Connect(InteractionService.Refresh)

	-- Safety net: if a hold is never completed or cancelled (lost packet),
	-- release it so OnBegin side effects (e.g. rooting) don't stick.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, hold in table.clone(holds) do
				local def = defs[hold.Id]
				if not def or now - hold.StartedAt > def.Hold + 6 then
					InteractionService.CancelPlayer(player)
				end
			end
		end
	end)
end

return InteractionService
