--!strict
--[[
	EliminationService
	The infiltrators' SIPHON and everything that follows it.

	  Siphon   - an infiltrator holds a short channel on an isolated crew
	             member. Both are rooted and a visible beam links them, so
	             anyone nearby can witness it. Blocked in the Emergency Shelter,
	             against crowds (2+ other crew close by), and against anyone
	             recently revived ("shaken").
	  Stasis   - the victim is frozen in a crystal for a bleed timer. Any
	             player can Revive them (the revived victim gets a glimpse of
	             the attacker's accent) or Report them (calls a muster).
	  Lost     - if nobody revives them, the victim becomes a Signal Ghost
	             and leaves a stasis pod behind.
	  Pods     - can be Reported, Scanned (reveals the attacker's accent and
	             time) or, by infiltrators, Scrubbed to destroy that trace.

	Every step is validated on the server (roles, range, line of sight,
	cooldowns, states). No gore: stylised crystal and light effects only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local AccentPalette = require(Shared.Data.AccentPalette)
local ShipLayout = require(Shared.Data.ShipLayout)
local Format = require(Shared.Utility.Format)
local Logger = require(Shared.Utility.Logger)
local Signal = require(Shared.Utility.Signal)
local Validate = require(Shared.Utility.Validate)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local EvidenceService = require(script.Parent.EvidenceService)
local InteractionService = require(script.Parent.InteractionService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local RemoteService = require(script.Parent.RemoteService)
local ReplicationService = require(script.Parent.ReplicationService)

local log = Logger.new("EliminationService")

type Participant = MatchService.Participant

type Channel = { Attacker: Player, Target: Player, Beam: Instance? }
type Downed = { Attacker: Participant?, At: number, BleedEndsAt: number, Crystal: BasePart?, Area: string? }
type Pod = {
	Id: string,
	VictimName: string,
	Area: string?,
	Time: number,
	AttackerAccent: number?,
	Scrubbed: boolean,
	Scanned: boolean,
	Part: BasePart,
}

local EliminationService = {}

-- (reporter: Player, subjectName: string?) a body was reported
EliminationService.ReportRequested = Signal.new()

local siphonReadyAt: { [Player]: number } = {}
local channels: { [Player]: Channel } = {} -- keyed by attacker
local downed: { [Player]: Downed } = {}
local pods: { [string]: Pod } = {}
local whisperReadyAt: { [Player]: number } = {}
local lastWhisper = 0
local podCounter = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publishSiphon(player: Player)
	if MatchService.IsInfiltrator(player) then
		ReplicationService.SetPrivate(player, Constants.PrivateKey.Siphon, { ReadyAt = siphonReadyAt[player] or 0 })
	end
end

local function inSafeRoom(player: Player): boolean
	local root = CharacterService.GetRoot(player)
	if not root then
		return false
	end
	local area = MapService.AreaAt(root.Position)
	return area ~= nil and table.find(Config.Elimination.SafeRooms, area) ~= nil
end

local function clearLineOfSight(from: Vector3, to: Vector3): boolean
	local exclude: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	return workspace:Raycast(from, to - from, rayParams) == nil
end

---------------------------------------------------------------------------
-- Visual effects
---------------------------------------------------------------------------

local function makeBeam(attacker: Player, target: Player): Instance?
	local a = CharacterService.GetRoot(attacker)
	local b = CharacterService.GetRoot(target)
	if not a or not b then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "SiphonBeam"
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.5, -0.8)
	a0.Parent = a
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0.5, 0)
	a1.Parent = b
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Color3.fromRGB(150, 110, 255), Color3.fromRGB(90, 220, 255))
	beam.LightEmission = 1
	beam.Width0 = 0.6
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.Segments = 12
	beam.CurveSize0 = 1.5
	beam.CurveSize1 = -1.5
	beam.Parent = folder
	-- Attachments are parented to characters; track them for cleanup.
	a0:SetAttribute("SiphonBeam", true)
	a1:SetAttribute("SiphonBeam", true)
	local holder = Instance.new("ObjectValue")
	holder.Name = "A0"
	holder.Value = a0
	holder.Parent = folder
	local holder1 = Instance.new("ObjectValue")
	holder1.Name = "A1"
	holder1.Value = a1
	holder1.Parent = folder
	folder.Parent = workspace
	return folder
end

local function destroyBeam(beam: Instance?)
	if not beam then
		return
	end
	for _, child in beam:GetChildren() do
		if child:IsA("ObjectValue") and child.Value then
			child.Value:Destroy()
		end
	end
	beam:Destroy()
end

local function makeCrystal(player: Player): BasePart?
	local root = CharacterService.GetRoot(player)
	if not root then
		return nil
	end
	local crystal = Instance.new("Part")
	crystal.Name = "StasisCrystal"
	crystal.Shape = Enum.PartType.Block
	crystal.Size = Vector3.new(4, 6.5, 4)
	crystal.CFrame = root.CFrame * CFrame.Angles(0, math.rad(45), 0)
	crystal.Color = Color3.fromRGB(120, 200, 255)
	crystal.Material = Enum.Material.Glass
	crystal.Transparency = 0.45
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.CanQuery = false
	crystal.CanTouch = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 200, 255)
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = crystal
	crystal.Parent = player.Character
	return crystal
end

---------------------------------------------------------------------------
-- Siphon
---------------------------------------------------------------------------

local function endChannel(attacker: Player, completed: boolean)
	local channel = channels[attacker]
	if not channel then
		return
	end
	channels[attacker] = nil
	destroyBeam(channel.Beam)
	CharacterService.SetFrozen(attacker, false)
	if not completed then
		if downed[channel.Target] == nil then
			CharacterService.SetFrozen(channel.Target, false)
		end
		siphonReadyAt[attacker] = math.max(siphonReadyAt[attacker] or 0, now() + Config.Elimination.CancelledSiphonCooldown)
		publishSiphon(attacker)
	end
end

local function targetBeingSiphoned(target: Player): boolean
	for _, channel in channels do
		if channel.Target == target then
			return true
		end
	end
	return false
end

local function witnesses(attacker: Player, victim: Player): { Player }
	local list = {}
	local victimRoot = CharacterService.GetRoot(victim)
	if not victimRoot then
		return list
	end
	for _, p in MatchService.Living(Constants.Faction.Crew) do
		if p.Player ~= victim and p.Life == Constants.LifeState.Alive then
			local root = CharacterService.GetRoot(p.Player)
			if root and (root.Position - victimRoot.Position).Magnitude <= Config.Elimination.WitnessRadius then
				if clearLineOfSight(root.Position + Vector3.new(0, 1.5, 0), victimRoot.Position) then
					table.insert(list, p.Player)
				end
			end
		end
	end
	return list
end

function EliminationService.Lose(victim: Player)
	local p = MatchService.GetParticipant(victim)
	local state = downed[victim]
	if not p or not state then
		return
	end
	downed[victim] = nil
	local root = CharacterService.GetRoot(victim)
	local position = if root then root.Position else (if state.Crystal then state.Crystal.Position else nil)

	if position then
		podCounter += 1
		local id = "P" .. podCounter
		local podPart = Instance.new("Part")
		podPart.Name = "StasisPod_" .. id
		podPart.Size = Vector3.new(3.5, 6, 3.5)
		podPart.Position = Vector3.new(position.X, ShipLayout.FloorY + 3, position.Z)
		podPart.Color = Color3.fromRGB(110, 170, 230)
		podPart.Material = Enum.Material.Glass
		podPart.Transparency = 0.3
		podPart.Anchored = true
		podPart.CanCollide = true
		podPart.CanTouch = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(110, 170, 230)
		light.Range = 12
		light.Parent = podPart
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(160, 28)
		tag.StudsOffset = Vector3.new(0, 4.2, 0)
		tag.MaxDistance = 40
		tag.Parent = podPart
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(200, 230, 255)
		label.TextStrokeTransparency = 0.4
		label.Text = "STASIS POD - " .. p.DisplayName
		label.Parent = tag
		podPart.Parent = MapService.GetShipFolder()

		local pod: Pod = {
			Id = id,
			VictimName = p.DisplayName,
			Area = state.Area,
			Time = state.At,
			AttackerAccent = if state.Attacker then state.Attacker.Accent else nil,
			Scrubbed = false,
			Scanned = false,
			Part = podPart,
		}
		pods[id] = pod
		MapService.SetAnchor("Pod:" .. id, podPart)
		EliminationService.RegisterPodInteractions(pod)
	end

	MatchService.SetLife(p, Constants.LifeState.Lost :: Types.LifeState)
	CharacterService.SetFrozen(victim, false)
	CharacterService.Despawn(victim)
	NotifyService.Send(victim, "Your signal fades... You are now a Signal Ghost.", "Alert", 6)
	AnalyticsService.Count("Eliminations")
	InteractionService.Refresh()
	MatchService.CheckWin()
end

local function down(victim: Player, attacker: Participant?)
	local p = MatchService.GetParticipant(victim)
	if not p or p.Life ~= Constants.LifeState.Alive then
		return
	end
	InteractionService.CancelPlayer(victim)
	local root = CharacterService.GetRoot(victim)
	local area = if root then MapService.AreaAt(root.Position) else nil
	local t = MatchService.RoundTime()
	local state: Downed = {
		Attacker = attacker,
		At = t,
		BleedEndsAt = now() + Config.Elimination.StasisBleedSeconds,
		Crystal = makeCrystal(victim),
		Area = area,
	}
	downed[victim] = state
	CharacterService.SetFrozen(victim, true)
	if root then
		root.Anchored = true
	end

	if attacker then
		attacker.Stats.Siphons += 1
		for _, witness in witnesses(attacker.Player, victim) do
			EvidenceService.AddPrivate(
				witness,
				"Witness",
				area,
				string.format(
					"You saw a siphon beam in %s at %s. Attacker accent: %s.",
					ShipLayout.areaName(area),
					Format.clock(t),
					AccentPalette.label(attacker.Accent)
				),
				t
			)
			local wp = MatchService.GetParticipant(witness)
			if wp then
				wp.AlertTokens = 1
			end
			NotifyService.Send(witness, "You witnessed a siphon! You can raise an emergency alert from anywhere.", "Alert", 6)
			NotifyService.Cue(witness, "TokensChanged", {})
		end
	end
	-- After witness tokens are set, so the token resync on LifeChanged includes them.
	MatchService.SetLife(p, Constants.LifeState.Downed :: Types.LifeState)
	NotifyService.Send(victim, "You've been siphoned into stasis! Hope someone revives you...", "Alert", 6)
	NotifyService.CueAll("Siphoned", { UserId = victim.UserId })

	EvidenceService.RecordIncident(area, t)
	AnalyticsService.Count("Siphons")
	InteractionService.Refresh()

	task.delay(Config.Elimination.StasisBleedSeconds, function()
		if downed[victim] == state then
			EliminationService.Lose(victim)
		end
	end)
end

function EliminationService.Revive(victim: Player, reviver: Player?)
	local p = MatchService.GetParticipant(victim)
	local state = downed[victim]
	if not p or not state then
		return
	end
	downed[victim] = nil
	if state.Crystal then
		state.Crystal:Destroy()
	end
	local root = CharacterService.GetRoot(victim)
	if root then
		root.Anchored = false
	end
	CharacterService.SetFrozen(victim, false)
	p.ShakenUntil = now() + Config.Elimination.ShakenProtectionSeconds
	MatchService.SetLife(p, Constants.LifeState.Alive :: Types.LifeState)

	if state.Attacker then
		EvidenceService.AddPrivate(
			victim,
			"Glimpse",
			state.Area,
			string.format("Before stasis took you (%s, %s) you glimpsed your attacker's accent: %s.", ShipLayout.areaName(state.Area), Format.clock(state.At), AccentPalette.label(state.Attacker.Accent)),
			state.At
		)
	end
	if reviver then
		local rp = MatchService.GetParticipant(reviver)
		if rp then
			rp.Stats.Revives += 1
		end
		NotifyService.Send(victim, reviver.DisplayName .. " pulled you out of stasis!", "Success", 4)
	end
	NotifyService.CueAll("Revived", { UserId = victim.UserId })
	AnalyticsService.Count("Revives")
	InteractionService.Refresh()
end

---------------------------------------------------------------------------
-- Interaction registration
---------------------------------------------------------------------------

local function registerPlayerInteractions(target: Participant)
	local targetPlayer = target.Player
	local uid = target.UserId
	local anchor = "Char:" .. uid

	InteractionService.Register({
		Id = "Siphon:" .. uid,
		Anchor = anchor,
		Action = "Siphon",
		Object = target.DisplayName,
		Hold = Config.Elimination.SiphonChannelSeconds,
		Key = 2,
		Range = Config.Elimination.SiphonRange,
		Visible = function(viewer)
			if viewer == targetPlayer or not MatchService.InPlay() then
				return false
			end
			local vp = MatchService.GetParticipant(viewer)
			return vp ~= nil
				and vp.Faction == Constants.Faction.Infiltrator
				and vp.Life == Constants.LifeState.Alive
				and target.Faction == Constants.Faction.Crew
				and target.Life == Constants.LifeState.Alive
		end,
		CanBegin = function(viewer)
			if (siphonReadyAt[viewer] or 0) > now() then
				return false, string.format("Siphon recharging (%ds).", math.ceil((siphonReadyAt[viewer] or 0) - now()))
			end
			if target.ShakenUntil > now() then
				return false, "Their nerves are too sharp right now."
			end
			if channels[viewer] or targetBeingSiphoned(targetPlayer) or CharacterService.IsFrozen(targetPlayer) then
				return false, nil
			end
			if inSafeRoom(viewer) or inSafeRoom(targetPlayer) then
				return false, "The shelter's dampers block your link."
			end
			local targetRoot = CharacterService.GetRoot(targetPlayer)
			if not targetRoot then
				return false, nil
			end
			local crowd = 0
			for _, other in MatchService.Living(Constants.Faction.Crew) do
				if other ~= target and other.Life == Constants.LifeState.Alive then
					local root = CharacterService.GetRoot(other.Player)
					if root and (root.Position - targetRoot.Position).Magnitude <= Config.Elimination.CrowdRadius then
						crowd += 1
					end
				end
			end
			if crowd >= Config.Elimination.CrowdBlockCount then
				return false, "Too many eyes here."
			end
			return true
		end,
		OnBegin = function(viewer)
			CharacterService.SetFrozen(viewer, true)
			CharacterService.SetFrozen(targetPlayer, true)
			InteractionService.CancelPlayer(targetPlayer)
			channels[viewer] = { Attacker = viewer, Target = targetPlayer, Beam = makeBeam(viewer, targetPlayer) }
		end,
		OnCancel = function(viewer)
			endChannel(viewer, false)
		end,
		OnComplete = function(viewer)
			local vp = MatchService.GetParticipant(viewer)
			endChannel(viewer, true)
			siphonReadyAt[viewer] = now() + Config.Elimination.SiphonCooldown
			publishSiphon(viewer)
			down(targetPlayer, vp)
		end,
	})

	InteractionService.Register({
		Id = "Revive:" .. uid,
		Anchor = anchor,
		Action = "Revive",
		Object = target.DisplayName,
		Hold = Config.Elimination.ReviveHoldSeconds,
		Key = 1,
		Visible = function(viewer)
			return viewer ~= targetPlayer and downed[targetPlayer] ~= nil and MatchService.IsActive(viewer) and MatchService.InPlay()
		end,
		OnComplete = function(viewer)
			EliminationService.Revive(targetPlayer, viewer)
		end,
	})

	InteractionService.Register({
		Id = "ReportDowned:" .. uid,
		Anchor = anchor,
		Action = "Report",
		Object = target.DisplayName,
		Hold = 0,
		Key = 2,
		Visible = function(viewer)
			return viewer ~= targetPlayer
				and downed[targetPlayer] ~= nil
				and MatchService.IsActive(viewer)
				and MatchService.IsState(Constants.RoundState.ActiveRound)
		end,
		OnComplete = function(viewer)
			EliminationService.ReportRequested:Fire(viewer, target.DisplayName)
		end,
	})
end

function EliminationService.RegisterPodInteractions(pod: Pod)
	local anchor = "Pod:" .. pod.Id
	InteractionService.Register({
		Id = "PodReport:" .. pod.Id,
		Anchor = anchor,
		Action = "Report",
		Object = "Stasis pod",
		Hold = 0,
		Key = 1,
		Visible = function(viewer)
			return pods[pod.Id] ~= nil and MatchService.IsActive(viewer) and MatchService.IsState(Constants.RoundState.ActiveRound)
		end,
		OnComplete = function(viewer)
			EliminationService.ReportRequested:Fire(viewer, pod.VictimName)
		end,
	})
	InteractionService.Register({
		Id = "PodScan:" .. pod.Id,
		Anchor = anchor,
		Action = "Scan residue",
		Object = "Stasis pod",
		Hold = Config.Elimination.ScanHoldSeconds,
		Key = 2,
		Visible = function(viewer)
			return pods[pod.Id] ~= nil and not pod.Scanned and MatchService.IsActive(viewer) and MatchService.InPlay()
		end,
		OnComplete = function(viewer)
			if pod.Scanned then
				return
			end
			pod.Scanned = true
			local vp = MatchService.GetParticipant(viewer)
			if vp then
				vp.Stats.Scans += 1
			end
			local where = ShipLayout.areaName(pod.Area)
			local text
			if pod.Scrubbed then
				text = string.format("Stasis residue (%s, %s): trace deliberately degraded. Unreadable.", pod.VictimName, where)
			elseif pod.AttackerAccent then
				text = string.format(
					"Stasis residue (%s, %s, ~%s): accent trace %s.",
					pod.VictimName,
					where,
					Format.clock(pod.Time),
					AccentPalette.label(pod.AttackerAccent)
				)
			else
				text = string.format("Stasis residue (%s, %s): no attacker trace.", pod.VictimName, where)
			end
			EvidenceService.AddPublic("Pod", pod.Area, text, pod.Time)
			NotifyService.Broadcast("New evidence: stasis residue scanned.", "Info", 3)
			InteractionService.Refresh()
		end,
	})
	InteractionService.Register({
		Id = "PodScrub:" .. pod.Id,
		Anchor = anchor,
		Action = "Scrub trace",
		Object = "Stasis pod",
		Hold = Config.Elimination.ScrubHoldSeconds,
		Key = 3,
		Visible = function(viewer)
			if pods[pod.Id] == nil or pod.Scanned or pod.Scrubbed or not MatchService.InPlay() then
				return false
			end
			local vp = MatchService.GetParticipant(viewer)
			return vp ~= nil and vp.Faction == Constants.Faction.Infiltrator and vp.Life == Constants.LifeState.Alive
		end,
		OnComplete = function()
			pod.Scrubbed = true
			pod.Part.Color = Color3.fromRGB(90, 100, 120)
			InteractionService.Refresh()
		end,
	})
end

---------------------------------------------------------------------------
-- Round hooks
---------------------------------------------------------------------------

function EliminationService.SetupForMatch()
	EliminationService.Reset()
	local readyAt = now() + Config.Elimination.InitialSiphonCooldown
	for _, p in MatchService.GetParticipants() do
		registerPlayerInteractions(p)
		if p.Faction == Constants.Faction.Infiltrator then
			siphonReadyAt[p.Player] = readyAt
			publishSiphon(p.Player)
		end
	end
end

-- After a muster: fresh cooldown for every infiltrator.
function EliminationService.ResetCooldowns()
	local readyAt = now() + Config.Elimination.SiphonCooldown
	for player in siphonReadyAt do
		siphonReadyAt[player] = readyAt
		publishSiphon(player)
	end
end

-- Muster start: stasis collapses for anyone not revived in time.
function EliminationService.CollapseAllDowned()
	for attacker in table.clone(channels) do
		endChannel(attacker, false)
	end
	for victim in table.clone(downed) do
		EliminationService.Lose(victim)
	end
end

function EliminationService.ClearPods()
	for id, pod in pods do
		InteractionService.UnregisterPrefix("PodReport:" .. id)
		InteractionService.UnregisterPrefix("PodScan:" .. id)
		InteractionService.UnregisterPrefix("PodScrub:" .. id)
		MapService.SetAnchor("Pod:" .. id, nil)
		pod.Part:Destroy()
	end
	table.clear(pods)
end

function EliminationService.Reset()
	for attacker in table.clone(channels) do
		endChannel(attacker, true)
	end
	for victim, state in table.clone(downed) do
		if state.Crystal then
			state.Crystal:Destroy()
		end
		local root = CharacterService.GetRoot(victim)
		if root then
			root.Anchored = false
		end
		CharacterService.SetFrozen(victim, false)
	end
	table.clear(downed)
	EliminationService.ClearPods()
	for player in siphonReadyAt do
		if player.Parent == Players then
			ReplicationService.SetPrivate(player, Constants.PrivateKey.Siphon, nil)
		end
	end
	table.clear(siphonReadyAt)
	table.clear(whisperReadyAt)
	for _, prefix in { "Siphon:", "Revive:", "ReportDowned:" } do
		InteractionService.UnregisterPrefix(prefix)
	end
end

-- Admin/debug: siphon a target directly.
function EliminationService.DebugDown(victim: Player)
	down(victim, nil)
end

function EliminationService.IsDowned(player: Player): boolean
	return downed[player] ~= nil
end

---------------------------------------------------------------------------
-- Signal Ghost whispers
---------------------------------------------------------------------------

local function onWhisper(player: Player, roomId: string)
	local p = MatchService.GetParticipant(player)
	if not p or (p.Life ~= Constants.LifeState.Lost and p.Life ~= Constants.LifeState.Confined) then
		return
	end
	if not MatchService.InPlay() or not ShipLayout.getRoom(roomId) then
		return
	end
	local t = os.clock()
	if (whisperReadyAt[player] or 0) > t or t - lastWhisper < Config.Ghost.GlobalWhisperGap then
		NotifyService.Send(player, "The static needs a moment to gather.", "Warning", 2)
		return
	end
	whisperReadyAt[player] = t + Config.Ghost.WhisperCooldown
	lastWhisper = t
	local living = {}
	for _, lp in MatchService.Living() do
		table.insert(living, lp.Player)
	end
	NotifyService.CueMany(living, "Whisper", { Room = roomId, Duration = Config.Ghost.WhisperDuration })
	NotifyService.SendMany(living, "Strange static crackles in " .. ShipLayout.areaName(roomId) .. "...", "Info", 4)
	NotifyService.Send(player, "Your whisper reaches " .. ShipLayout.areaName(roomId) .. ".", "Success", 3)
	NotifyService.Cue(player, "WhisperCooldown", { ReadyAt = workspace:GetServerTimeNow() + Config.Ghost.WhisperCooldown })
end

function EliminationService.Start()
	local roomIds = {}
	for _, room in ShipLayout.Rooms do
		table.insert(roomIds, room.Id)
	end
	RemoteService.OnEvent(Net.Names.GhostWhisper, { Validate.oneOf(roomIds) }, onWhisper)

	MatchService.LifeChanged:Connect(function(p, life)
		if life == Constants.LifeState.Disconnected then
			downed[p.Player] = nil
		end
		-- Attackers who go down mid-channel lose the channel.
		if life ~= Constants.LifeState.Alive then
			endChannel(p.Player, false)
			for attacker, channel in table.clone(channels) do
				if channel.Target == p.Player then
					endChannel(attacker, false)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		siphonReadyAt[player] = nil
		whisperReadyAt[player] = nil
		channels[player] = nil
	end)
	log:Debug("ready")
end

return EliminationService
