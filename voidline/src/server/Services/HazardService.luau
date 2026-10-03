--!strict
--[[
	HazardService
	Runs ship hazards for both sabotage and dynamic events: applies their
	server-side effects (lights, doors, fire, alarms), publishes them so
	clients can render local effects (gravity, darkness, static, scrambled
	readouts), registers the crew's fix interactions and resolves success or
	failure.

	Rules that keep hazards fair:
	  * One hazard per room / section / ship-wide kind at a time.
	  * Only one critical hazard at a time; a critical hazard switches the
	    round to EMERGENCY and failing it costs Stability, not the game.
	  * Every hazard can be fixed by the crew, or ends on its timer.
	  * Whether a hazard was sabotage or an accident is never published.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local HazardCatalog = require(Shared.Data.HazardCatalog)
local ShipLayout = require(Shared.Data.ShipLayout)
local Format = require(Shared.Utility.Format)
local Logger = require(Shared.Utility.Logger)
local Signal = require(Shared.Utility.Signal)

local EvidenceService = require(script.Parent.EvidenceService)
local InteractionService = require(script.Parent.InteractionService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local ReplicationService = require(script.Parent.ReplicationService)

local log = Logger.new("HazardService")

export type Hazard = {
	Id: string,
	Kind: HazardCatalog.HazardKind,
	Target: string?,
	Source: string,
	StartedAt: number,
	EndsAt: number,
	Fixtures: { string },
	Progress: { [string]: number },
	Ended: boolean,
	Effects: { Instance },
}

local HazardService = {}

-- (hazard)
HazardService.Started = Signal.new()
-- (hazard, fixed: boolean, fixer: Player?)
HazardService.Ended = Signal.new()

local active: { [string]: Hazard } = {}
local counter = 0

local function targetName(hazard: Hazard): string
	if not hazard.Target then
		return "ship"
	end
	if hazard.Kind.Target == "Section" then
		return (if hazard.Target == "Mid" then "Midship" else hazard.Target)
	end
	return ShipLayout.areaName(hazard.Target)
end

local function caption(hazard: Hazard): string
	return (string.gsub(hazard.Kind.Caption, "{Target}", targetName(hazard)))
end

local function publish()
	local list = {}
	for _, hazard in active do
		local remaining = {}
		for _, fixture in hazard.Fixtures do
			if not hazard.Progress[fixture] then
				table.insert(remaining, fixture)
			end
		end
		table.insert(list, {
			Id = hazard.Id,
			Kind = hazard.Kind.Id,
			Name = hazard.Kind.Name,
			Target = hazard.Target,
			TargetName = targetName(hazard),
			TargetType = hazard.Kind.Target,
			Critical = hazard.Kind.Critical,
			EndsAt = hazard.EndsAt,
			Fixtures = remaining,
			FixAction = hazard.Kind.Fix.Action,
			Caption = caption(hazard),
		})
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	ReplicationService.SetPublic(Constants.PublicKey.Hazards, list)
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------

local function emitterPart(parent: Instance, position: Vector3, kind: "Fire" | "Sparks" | "Steam"): BasePart
	local part = Instance.new("Part")
	part.Name = kind
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(4, 1, 4)
	part.Position = position
	local emitter = Instance.new("ParticleEmitter")
	if kind == "Fire" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 60, 20))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0.2) })
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.Rate = 30
		emitter.Speed = NumberRange.new(4, 8)
		emitter.SpreadAngle = Vector2.new(15, 15)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 40)
		light.Range = 18
		light.Brightness = 2
		light.Parent = part
	elseif kind == "Sparks" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(0.25)
		emitter.Lifetime = NumberRange.new(0.3, 0.6)
		emitter.Rate = 20
		emitter.Speed = NumberRange.new(8, 14)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.Acceleration = Vector3.new(0, -30, 0)
	else
		emitter.Color = ColorSequence.new(Color3.fromRGB(230, 235, 240))
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 5) })
		emitter.Lifetime = NumberRange.new(1, 2)
		emitter.Rate = 25
		emitter.Speed = NumberRange.new(10, 16)
		emitter.SpreadAngle = Vector2.new(10, 10)
	end
	emitter.Parent = part
	part.Parent = parent
	return part
end

local function apply(hazard: Hazard)
	local kind = hazard.Kind.Id
	local target = hazard.Target
	local ship = MapService.GetShipFolder()

	if kind == "Darkness" and target then
		MapService.SetLights("Off", { Section = target })
	elseif kind == "Blackout" then
		MapService.SetLights("Dim", nil)
	elseif kind == "Lockdown" and target then
		for _, connection in ShipLayout.connectionsInSection(target) do
			MapService.SetDoorLocked(connection.Id, true)
			local doorId = "Door:" .. connection.Id
			InteractionService.Register({
				Id = doorId,
				Anchor = "DoorPanel:" .. connection.Id,
				Action = "Override door",
				Object = "Door control",
				Hold = 3,
				Visible = function(player)
					return MatchService.IsActive(player) and MapService.IsDoorLocked(connection.Id)
				end,
				OnComplete = function()
					MapService.SetDoorLocked(connection.Id, false)
					InteractionService.Refresh()
				end,
			})
		end
	elseif kind == "Coolant" or kind == "Oxygen" then
		MapService.SetLights("Alarm", nil)
	elseif (kind == "Fire" or kind == "Breach" or kind == "Damage") and target then
		local room = ShipLayout.getRoom(target)
		if room then
			local center = MapService.RoomCenter(target)
			if kind == "Fire" then
				for _, offset in { Vector3.new(-8, 0.5, 6), Vector3.new(7, 0.5, -5), Vector3.new(0, 0.5, 9) } do
					table.insert(hazard.Effects, emitterPart(ship, center + offset, "Fire"))
				end
				MapService.SetLights("Alarm", { Room = target })
			elseif kind == "Breach" then
				local wallPoint = center + Vector3.new(0, 6, -room.SizeZ / 2 + 1)
				table.insert(hazard.Effects, emitterPart(ship, wallPoint, "Steam"))
				MapService.SetLights("Alarm", { Room = target })
			else
				local node = MapService.GetAnchor("Fixture:Node." .. target)
				if node then
					table.insert(hazard.Effects, emitterPart(ship, node.Position + Vector3.new(0, 1, 0), "Sparks"))
				end
			end
		end
	elseif kind == "Malfunction" and target then
		MapService.SetLights("Dim", { Room = target })
	elseif kind == "ReactorUnstable" then
		MapService.SetLights("Alarm", { Room = "ReactorChamber" })
	end
end

local function hasOther(kindId: string, predicate: (Hazard) -> boolean): boolean
	for _, other in active do
		if other.Kind.Id == kindId and predicate(other) then
			return true
		end
	end
	return false
end

-- Restores whatever this hazard changed (other hazards' effects are reapplied).
local function clear(hazard: Hazard)
	local kind = hazard.Kind.Id
	local target = hazard.Target
	for _, effect in hazard.Effects do
		effect:Destroy()
	end
	table.clear(hazard.Effects)

	if kind == "Lockdown" and target then
		for _, connection in ShipLayout.connectionsInSection(target) do
			-- A neighbouring section's lockdown may still hold shared corridors.
			local stillHeld = hasOther("Lockdown", function(other)
				local otherTarget = other.Target
				if not otherTarget then
					return false
				end
				for _, c in ShipLayout.connectionsInSection(otherTarget) do
					if c.Id == connection.Id then
						return true
					end
				end
				return false
			end)
			if not stillHeld then
				MapService.SetDoorLocked(connection.Id, false)
				InteractionService.Unregister("Door:" .. connection.Id)
			end
		end
	end

	-- Lights: reset everything, then reapply remaining hazards in order.
	if kind ~= "Lockdown" and kind ~= "Gravity" and kind ~= "Jam" and kind ~= "NavScramble" and kind ~= "Signal" then
		-- During the endgame the whole ship stays on alarm lighting.
		MapService.SetLights(if MatchService.IsState(Constants.RoundState.Endgame) then "Alarm" else "Normal", nil)
		for _, other in active do
			if other ~= hazard and not other.Ended then
				local otherKind = other.Kind.Id
				if otherKind == "Darkness" and other.Target then
					MapService.SetLights("Off", { Section = other.Target })
				elseif otherKind == "Blackout" then
					MapService.SetLights("Dim", nil)
				elseif otherKind == "Coolant" or otherKind == "Oxygen" then
					MapService.SetLights("Alarm", nil)
				elseif (otherKind == "Fire" or otherKind == "Breach") and other.Target then
					MapService.SetLights("Alarm", { Room = other.Target })
				elseif otherKind == "Malfunction" and other.Target then
					MapService.SetLights("Dim", { Room = other.Target })
				elseif otherKind == "ReactorUnstable" then
					MapService.SetLights("Alarm", { Room = "ReactorChamber" })
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Fixing
---------------------------------------------------------------------------

local function checkResolved(hazard: Hazard, fixer: Player)
	local mode = hazard.Kind.Fix.Mode
	local done = 0
	for _, fixture in hazard.Fixtures do
		if hazard.Progress[fixture] then
			done += 1
		end
	end
	if mode == "Any" and done >= 1 then
		HazardService.End(hazard, true, fixer)
	elseif mode == "All" and done == #hazard.Fixtures then
		HazardService.End(hazard, true, fixer)
	elseif mode == "Simultaneous" then
		if done == #hazard.Fixtures then
			local minT, maxT = math.huge, -math.huge
			for _, t in hazard.Progress do
				minT = math.min(minT, t)
				maxT = math.max(maxT, t)
			end
			if maxT - minT <= Config.Sabotage.DualValveWindowSeconds then
				HazardService.End(hazard, true, fixer)
				return
			end
			-- Too far apart: only the newest completion counts.
			for fixture, t in table.clone(hazard.Progress) do
				if t < maxT then
					hazard.Progress[fixture] = nil
				end
			end
			NotifyService.Broadcast("Valves out of sync! Open both within a few seconds of each other.", "Warning", 4)
		end
		publish()
		InteractionService.Refresh()
	else
		publish()
		InteractionService.Refresh()
	end
end

local function registerFixes(hazard: Hazard)
	for _, fixture in hazard.Fixtures do
		InteractionService.Register({
			Id = string.format("Hazard:%s:%s", hazard.Id, fixture),
			Anchor = "Fixture:" .. fixture,
			Action = hazard.Kind.Fix.Action,
			Object = hazard.Kind.Name,
			Hold = hazard.Kind.Fix.Hold,
			Key = 2,
			Visible = function(player)
				return not hazard.Ended and hazard.Progress[fixture] == nil and MatchService.IsActive(player)
			end,
			OnComplete = function(player)
				if hazard.Ended then
					return
				end
				hazard.Progress[fixture] = os.clock()
				local p = MatchService.GetParticipant(player)
				if p then
					p.Stats.HazardsFixed += 1
				end
				checkResolved(hazard, player)
			end,
		})
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

-- True if starting `kindId` at `target` would conflict with an active hazard.
function HazardService.Conflicts(kindId: string, target: string?): boolean
	local kind = HazardCatalog.get(kindId)
	if not kind then
		return true
	end
	for _, other in active do
		if kind.Critical and other.Kind.Critical then
			return true
		end
		if other.Kind.Id == kindId and other.Target == target then
			return true
		end
		if kind.Target ~= "Ship" and other.Kind.Target == kind.Target and other.Target == target then
			-- One section/room hazard per target (they share fix fixtures).
			return true
		end
		if kind.Target == "Ship" and other.Kind.Id == kindId then
			return true
		end
	end
	return false
end

function HazardService.Begin(kindId: string, target: string?, duration: number, source: string): Hazard?
	local kind = HazardCatalog.get(kindId)
	if not kind or not MatchService.IsRunning() then
		return nil
	end
	if HazardService.Conflicts(kindId, target) then
		return nil
	end
	if kind.Critical and not MatchService.IsState(Constants.RoundState.ActiveRound) then
		return nil
	end
	counter += 1
	local now = workspace:GetServerTimeNow()
	local hazard: Hazard = {
		Id = "H" .. counter,
		Kind = kind,
		Target = target,
		Source = source,
		StartedAt = now,
		EndsAt = now + duration,
		Fixtures = HazardCatalog.fixturesFor(kind, target),
		Progress = {},
		Ended = false,
		Effects = {},
	}
	active[hazard.Id] = hazard
	apply(hazard)
	if kind.Fix.Mode ~= "None" then
		registerFixes(hazard)
	end
	publish()

	if kind.Critical then
		MatchService.Transition(Constants.RoundState.Emergency)
		MatchService.SetTimer(kind.Name, hazard.EndsAt)
		NotifyService.Broadcast(caption(hazard), "Alert", 6)
	else
		NotifyService.Broadcast(caption(hazard), "Warning", 4)
	end
	NotifyService.CueAll("HazardStarted", { Kind = kind.Id, Target = target, Critical = kind.Critical })
	log:Debug("Hazard started", kind.Id, target, "from", source)
	HazardService.Started:Fire(hazard)
	return hazard
end

function HazardService.End(hazard: Hazard, fixed: boolean, fixer: Player?)
	if hazard.Ended then
		return
	end
	hazard.Ended = true
	active[hazard.Id] = nil
	InteractionService.UnregisterPrefix("Hazard:" .. hazard.Id .. ":")
	clear(hazard)
	publish()

	local kind = hazard.Kind
	if fixed then
		if kind.FixReward ~= 0 then
			MatchService.AddStability(kind.FixReward)
		end
		NotifyService.Broadcast(
			string.format("%s resolved%s.", kind.Name, if fixer then " by " .. fixer.DisplayName else ""),
			"Success",
			3
		)
		if kind.Id == "Signal" and Config.Events.SignalRevealsInfiltratorCount then
			local count = #MatchService.Living(Constants.Faction.Infiltrator)
			local text = string.format("Decoded signal: %d unregistered biosignature%s active aboard.", count, if count == 1 then "" else "s")
			EvidenceService.AddPublic("Signal", "Communications", text)
			NotifyService.Broadcast(text, "Info", 6)
		end
	elseif kind.Critical then
		MatchService.AddStability(-kind.FailurePenalty)
		NotifyService.Broadcast(string.format("%s was not contained! Hull stability critical.", kind.Name), "Alert", 5)
		EvidenceService.AddPublic("Damage", nil, string.format("%s breached containment at %s.", kind.Name, Format.clock(MatchService.RoundTime())))
	end

	if kind.Critical then
		MatchService.SetTimer(nil, nil)
		if MatchService.IsState(Constants.RoundState.Emergency) then
			MatchService.Transition(Constants.RoundState.ActiveRound)
		end
	end
	NotifyService.CueAll("HazardEnded", { Kind = kind.Id, Target = hazard.Target, Fixed = fixed })
	HazardService.Ended:Fire(hazard, fixed, fixer)
	InteractionService.Refresh()
end

-- Ends everything without penalties (muster start, round end).
function HazardService.ClearAll()
	for _, hazard in table.clone(active) do
		hazard.Ended = true
		active[hazard.Id] = nil
		InteractionService.UnregisterPrefix("Hazard:" .. hazard.Id .. ":")
		for _, effect in hazard.Effects do
			effect:Destroy()
		end
		if hazard.Kind.Critical then
			MatchService.SetTimer(nil, nil)
		end
	end
	InteractionService.UnregisterPrefix("Door:")
	MapService.UnlockAllDoors()
	MapService.SetLights("Normal", nil)
	publish()
	InteractionService.Refresh()
end

function HazardService.GetActive(): { Hazard }
	local list = {}
	for _, hazard in active do
		table.insert(list, hazard)
	end
	return list
end

function HazardService.HasCritical(): boolean
	for _, hazard in active do
		if hazard.Kind.Critical then
			return true
		end
	end
	return false
end

function HazardService.IsActive(kindId: string, target: string?): boolean
	for _, hazard in active do
		if hazard.Kind.Id == kindId and (target == nil or hazard.Target == target) then
			return true
		end
	end
	return false
end

function HazardService.CountBySource(source: string): number
	local n = 0
	for _, hazard in active do
		if hazard.Source == source then
			n += 1
		end
	end
	return n
end

-- Is `roomId` without power (section power failure) or crashed (malfunction)?
function HazardService.IsRoomDisabled(roomId: string): (boolean, string?)
	local section = ShipLayout.areaSection(roomId)
	for _, hazard in active do
		if hazard.Kind.Id == "Darkness" and hazard.Target == section then
			return true, "No power in this section."
		end
		if hazard.Kind.Id == "Malfunction" and hazard.Target == roomId then
			return true, "Consoles in this room have crashed."
		end
	end
	return false, nil
end

function HazardService.IsSectionJammed(section: string): boolean
	return HazardService.IsActive("Jam", section)
end

function HazardService.Start()
	EvidenceService.IsSectionJammed = HazardService.IsSectionJammed

	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			if next(active) ~= nil then
				local now = workspace:GetServerTimeNow()
				local drain = 0
				for _, hazard in table.clone(active) do
					drain += hazard.Kind.StabilityDrain * dt
					if now >= hazard.EndsAt then
						HazardService.End(hazard, false, nil)
					end
				end
				if drain > 0 and MatchService.InPlay() then
					MatchService.AddStability(-drain)
				end
			end
		end
	end)
end

return HazardService
