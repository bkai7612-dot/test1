--!strict
--[[
	ObjectiveService
	Crew objectives: assignment, station interactions, server-issued
	mini-games, carried components and the ship's Restoration meter.

	  * Each round, every objective step picks one of its alternative stations.
	  * Every participant gets a private task list. Infiltrators get a *cover*
	    list: they can perform it (and be seen doing so), but it never moves
	    Restoration.
	  * Mini-games are issued by the server with a secret answer; completion
	    needs a matching answer, a minimum solve time and the player still at
	    the station.
	  * When a crew member is lost, their unfinished objectives become shared
	    objectives once the loss is revealed at a muster (so the shared list
	    never leaks a loss early).
	  * Restoration reaching 100% fires RestorationComplete (endgame).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local ObjectiveCatalog = require(Shared.Data.ObjectiveCatalog)
local ShipLayout = require(Shared.Data.ShipLayout)
local Minigames = require(Shared.Logic.Minigames)
local ObjectiveAssigner = require(Shared.Logic.ObjectiveAssigner)
local Logger = require(Shared.Utility.Logger)
local Signal = require(Shared.Utility.Signal)
local Validate = require(Shared.Utility.Validate)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local HazardService = require(script.Parent.HazardService)
local InteractionService = require(script.Parent.InteractionService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local RemoteService = require(script.Parent.RemoteService)
local ReplicationService = require(script.Parent.ReplicationService)

local log = Logger.new("ObjectiveService")

type TaskState = { ObjectiveId: string, StepIndex: number, Done: boolean, Cover: boolean }
type SharedTask = { Key: string, ObjectiveId: string, StepIndex: number, Done: boolean }
type TaskRef = { Own: TaskState?, Shared: SharedTask? }
type Session = {
	Id: string,
	Player: Player,
	Kind: string,
	Secret: any,
	StartedAt: number,
	StationKey: string,
	Ref: TaskRef,
}
type Carry = { ObjectiveId: string, Item: string, Part: BasePart?, Ref: TaskRef }

local ObjectiveService = {}

-- () Restoration reached 100%
ObjectiveService.RestorationComplete = Signal.new()

local picks: { [string]: { number } } = {}
local tasks: { [Player]: { TaskState } } = {}
local sharedTasks: { SharedTask } = {}
local pendingOrphans: { SharedTask } = {}
local sessions: { [Player]: Session } = {}
local carrying: { [Player]: Carry } = {}
local cooldowns: { [Player]: { [string]: number } } = {}
local usedStations: { [string]: boolean } = {}
local totalCrewSteps = 0
local completedCrewSteps = 0
local restorationFired = false
local sessionCounter = 0
local sharedCounter = 0

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function stationKeyFor(objectiveId: string, stepIndex: number): string?
	local objectivePicks = picks[objectiveId]
	if not objectivePicks or not objectivePicks[stepIndex] then
		return nil
	end
	return ObjectiveCatalog.stationKey(objectiveId, stepIndex, objectivePicks[stepIndex])
end

local function stationFor(objectiveId: string, stepIndex: number): ObjectiveCatalog.Station?
	local objective = ObjectiveCatalog.get(objectiveId)
	local objectivePicks = picks[objectiveId]
	if not objective or not objectivePicks then
		return nil
	end
	local step = objective.Steps[stepIndex]
	return if step then step.Stations[objectivePicks[stepIndex]] else nil
end

local function describeTask(state: TaskState)
	local objective = ObjectiveCatalog.get(state.ObjectiveId) :: ObjectiveCatalog.Objective
	local steps = {}
	for index, step in objective.Steps do
		local station = stationFor(state.ObjectiveId, index)
		table.insert(steps, {
			Label = step.Label,
			Kind = step.Kind,
			Room = if station then station.Room else nil,
			RoomName = if station then ShipLayout.areaName(station.Room) else "?",
			Anchor = "Station:" .. (stationKeyFor(state.ObjectiveId, index) or ""),
		})
	end
	return {
		Id = state.ObjectiveId,
		Name = objective.Name,
		Category = objective.Category,
		Cover = state.Cover,
		Done = state.Done,
		StepIndex = state.StepIndex,
		Steps = steps,
	}
end

local function publishTasks(player: Player)
	local list = {}
	for _, state in tasks[player] or ({} :: { TaskState }) do
		table.insert(list, describeTask(state))
	end
	ReplicationService.SetPrivate(player, Constants.PrivateKey.Tasks, list)
end

local function publishShared()
	local list = {}
	for _, shared in sharedTasks do
		if not shared.Done then
			local objective = ObjectiveCatalog.get(shared.ObjectiveId) :: ObjectiveCatalog.Objective
			local station = stationFor(shared.ObjectiveId, shared.StepIndex)
			table.insert(list, {
				Key = shared.Key,
				Name = objective.Name,
				Label = objective.Steps[shared.StepIndex].Label,
				Room = if station then station.Room else nil,
				RoomName = if station then ShipLayout.areaName(station.Room) else "?",
				Anchor = "Station:" .. (stationKeyFor(shared.ObjectiveId, shared.StepIndex) or ""),
			})
		end
	end
	ReplicationService.SetPublic(Constants.PublicKey.SharedTasks, list)
end

local function isCrew(player: Player): boolean
	local p = MatchService.GetParticipant(player)
	return p ~= nil and p.Faction == Constants.Faction.Crew
end

local function updateRestoration()
	local percent = if totalCrewSteps > 0 then completedCrewSteps / totalCrewSteps * 100 else 0
	MatchService.SetRestoration(percent)
	if percent >= 100 and not restorationFired then
		restorationFired = true
		ObjectiveService.RestorationComplete:Fire()
	end
end

-- Finds what `player` would progress at station `key`: own task first, then shared.
local function findRef(player: Player, key: string): TaskRef?
	for _, state in tasks[player] or ({} :: { TaskState }) do
		if not state.Done and stationKeyFor(state.ObjectiveId, state.StepIndex) == key then
			return { Own = state }
		end
	end
	if MatchService.IsActive(player) then
		for _, shared in sharedTasks do
			if not shared.Done and stationKeyFor(shared.ObjectiveId, shared.StepIndex) == key then
				return { Shared = shared }
			end
		end
	end
	return nil
end

local function refObjective(ref: TaskRef): (string, number)
	if ref.Own then
		return ref.Own.ObjectiveId, ref.Own.StepIndex
	end
	local shared = ref.Shared :: SharedTask
	return shared.ObjectiveId, shared.StepIndex
end

---------------------------------------------------------------------------
-- Carried components
---------------------------------------------------------------------------

local function dropCarry(player: Player, revert: boolean)
	local carry = carrying[player]
	if not carry then
		return
	end
	carrying[player] = nil
	if carry.Part then
		carry.Part:Destroy()
	end
	if revert then
		-- Back to the pickup step (the component returns to storage).
		if carry.Ref.Own then
			carry.Ref.Own.StepIndex = math.max(1, carry.Ref.Own.StepIndex - 1)
		elseif carry.Ref.Shared then
			carry.Ref.Shared.StepIndex = math.max(1, carry.Ref.Shared.StepIndex - 1)
		end
	end
	ReplicationService.SetPrivate(player, Constants.PrivateKey.Carrying, nil)
end

local function giveCarry(player: Player, item: string, ref: TaskRef)
	local objectiveId = refObjective(ref)
	local part: BasePart? = nil
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if hand then
		local box = Instance.new("Part")
		box.Name = "CarriedComponent"
		box.Size = Vector3.new(1.4, 1.1, 1.4)
		box.Color = Color3.fromRGB(230, 170, 60)
		box.Material = Enum.Material.SmoothPlastic
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.Massless = true
		box.CFrame = hand.CFrame * CFrame.new(0, -1, -0.5)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = box
		weld.Parent = box
		box.Parent = character
		part = box
	end
	carrying[player] = { ObjectiveId = objectiveId, Item = item, Part = part, Ref = ref }
	ReplicationService.SetPrivate(player, Constants.PrivateKey.Carrying, item)
end

---------------------------------------------------------------------------
-- Step completion
---------------------------------------------------------------------------

local function flashStation(key: string, objectiveName: string)
	local anchorId = "Station:" .. key
	MapService.SetScreen(anchorId, "✓ RESTORED", Color3.fromRGB(120, 255, 160))
	task.delay(4, function()
		if usedStations[key] then
			MapService.SetScreen(anchorId, string.upper(objectiveName))
		end
	end)
end

local function completeStep(player: Player, ref: TaskRef, key: string)
	local objectiveId, stepIndex = refObjective(ref)
	local objective = ObjectiveCatalog.get(objectiveId) :: ObjectiveCatalog.Objective
	local step = objective.Steps[stepIndex]
	local p = MatchService.GetParticipant(player)
	local realProgress = isCrew(player) and not (ref.Own and ref.Own.Cover)

	if step.Kind == "Pickup" then
		giveCarry(player, step.Item or "Component", ref)
	elseif step.Kind == "Deliver" then
		dropCarry(player, false)
	end

	-- Infiltrators "completing" a shared objective changes nothing.
	if ref.Shared and not realProgress then
		NotifyService.Cue(player, "StepComplete", { Fake = true })
		InteractionService.Refresh()
		return
	end

	local state = ref.Own or ref.Shared
	local finished = false
	if ref.Own then
		ref.Own.StepIndex += 1
		if ref.Own.StepIndex > #objective.Steps then
			ref.Own.Done = true
			finished = true
		end
	elseif ref.Shared then
		ref.Shared.StepIndex += 1
		if ref.Shared.StepIndex > #objective.Steps then
			ref.Shared.Done = true
			finished = true
		end
	end
	assert(state, "no task state")

	if realProgress then
		completedCrewSteps += 1
		MatchService.AddStability(Config.Round.StabilityPerCrewStep)
		if p then
			p.Stats.TaskSteps += 1
			if finished then
				p.Stats.TasksCompleted += 1
			end
		end
		if finished and #objective.Steps > 1 then
			flashStation(key, objective.Name)
		end
		if finished then
			AnalyticsService.Track("ObjectiveCompleted", 1, { objective = objectiveId }, player)
		end
		updateRestoration()
	end

	NotifyService.Cue(player, "StepComplete", { Finished = finished })
	if ref.Own then
		publishTasks(player)
	end
	if ref.Shared then
		publishShared()
	end
	InteractionService.Refresh()
end

---------------------------------------------------------------------------
-- Mini-games
---------------------------------------------------------------------------

local function endSession(player: Player, success: boolean, reason: string?)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	RemoteService.FireClient(Net.Names.MinigameResult, player, session.Id, success, reason)
	InteractionService.Refresh()
end

local function failStation(player: Player, key: string, reason: string)
	cooldowns[player] = cooldowns[player] or {}
	cooldowns[player][key] = os.clock() + Config.Objectives.FailCooldownSeconds
	NotifyService.CueAll("StationSpark", { Anchor = "Station:" .. key })
	endSession(player, false, reason)
end

local function startSession(player: Player, key: string, ref: TaskRef, kind: string, title: string, options: Minigames.Options?)
	sessionCounter += 1
	local challenge, secret = Minigames.generate(kind, Random.new(), options)
	local session: Session = {
		Id = "M" .. sessionCounter,
		Player = player,
		Kind = kind,
		Secret = secret,
		StartedAt = os.clock(),
		StationKey = key,
		Ref = ref,
	}
	sessions[player] = session
	local _, maxSeconds = Minigames.limits(kind, secret)
	RemoteService.FireClient(Net.Names.MinigameStart, player, session.Id, kind, challenge, {
		Title = title,
		TimeLimit = maxSeconds,
	})
	InteractionService.Refresh()
end

local function onSubmit(player: Player, sessionId: string, answer: any)
	local session = sessions[player]
	if not session or session.Id ~= sessionId then
		return
	end
	local elapsed = os.clock() - session.StartedAt
	local minSeconds, maxSeconds = Minigames.limits(session.Kind, session.Secret)
	if elapsed < minSeconds then
		failStation(player, session.StationKey, "Too fast - recalibrating.")
		return
	end
	if elapsed > maxSeconds + Config.Objectives.MinigameGraceSeconds then
		failStation(player, session.StationKey, "Timed out.")
		return
	end
	if not MatchService.IsActive(player) or not MatchService.InPlay() then
		endSession(player, false, "Interrupted.")
		return
	end
	local def = InteractionService.Get("Task:" .. session.StationKey)
	local root = CharacterService.GetRoot(player)
	local anchor = MapService.GetAnchor("Station:" .. session.StationKey)
	if not def or not root or not anchor then
		endSession(player, false, "Interrupted.")
		return
	end
	if (root.Position - anchor.Position).Magnitude > Config.Objectives.InteractRange + Config.Objectives.RangeTolerance + 2 then
		endSession(player, false, "You walked away from the console.")
		return
	end
	local ok, reason = Minigames.verify(session.Kind, session.Secret, answer)
	if not ok then
		failStation(player, session.StationKey, "Calibration failed: " .. (reason or "invalid"))
		return
	end
	-- The referenced task might have changed (e.g. a shared task finished by someone else).
	local objectiveId, stepIndex = refObjective(session.Ref)
	if stationKeyFor(objectiveId, stepIndex) ~= session.StationKey then
		endSession(player, false, "Someone else finished this first.")
		return
	end
	local ref = session.Ref
	local key = session.StationKey
	endSession(player, true, nil)
	completeStep(player, ref, key)
end

---------------------------------------------------------------------------
-- Station interactions
---------------------------------------------------------------------------

local function registerStation(key: string, objective: ObjectiveCatalog.Objective, stepIndex: number)
	local step = objective.Steps[stepIndex]
	local station = step.Stations[picks[objective.Id][stepIndex]]
	usedStations[key] = true
	MapService.SetScreen("Station:" .. key, string.upper(objective.Name))

	InteractionService.Register({
		Id = "Task:" .. key,
		Anchor = "Station:" .. key,
		Action = step.Label,
		Object = objective.Name,
		-- One press/click opens the task panel; timing happens in the session.
		Hold = 0,
		Key = 1,
		Visible = function(player)
			if not MatchService.InPlay() or not MatchService.IsActive(player) or sessions[player] then
				return false
			end
			return findRef(player, key) ~= nil
		end,
		CanBegin = function(player)
			local disabled, reason = HazardService.IsRoomDisabled(station.Room)
			if disabled then
				return false, reason
			end
			local until_ = cooldowns[player] and cooldowns[player][key]
			if until_ and os.clock() < until_ then
				return false, "Console recalibrating..."
			end
			local ref = findRef(player, key)
			if not ref then
				return false, nil
			end
			local objectiveId, index = refObjective(ref)
			local currentStep = (ObjectiveCatalog.get(objectiveId) :: ObjectiveCatalog.Objective).Steps[index]
			if currentStep.Kind == "Pickup" and carrying[player] then
				return false, "Your hands are full."
			end
			if currentStep.Kind == "Deliver" then
				local carry = carrying[player]
				if not carry or carry.ObjectiveId ~= objectiveId then
					return false, "You need the component first."
				end
			end
			return true
		end,
		OnComplete = function(player)
			local ref = findRef(player, key)
			if not ref then
				return
			end
			local objectiveId, index = refObjective(ref)
			local currentStep = (ObjectiveCatalog.get(objectiveId) :: ObjectiveCatalog.Objective).Steps[index]
			if ObjectiveCatalog.MinigameKinds[currentStep.Kind] then
				startSession(player, key, ref, currentStep.Kind, currentStep.Label)
			else
				-- Hold / pickup / install steps: a timed task the player stays at.
				startSession(player, key, ref, "Process", currentStep.Label, {
					Duration = currentStep.Hold or 2,
					Label = currentStep.Label,
				})
			end
		end,
	})
end

---------------------------------------------------------------------------
-- Round hooks
---------------------------------------------------------------------------

function ObjectiveService.AssignForMatch()
	ObjectiveService.Reset()
	local rng = Random.new()
	picks = ObjectiveAssigner.pickStations(ObjectiveCatalog.Objectives, rng)
	local rules = {
		Count = Config.Objectives.TasksPerPlayer,
		MaxCarry = Config.Objectives.MaxCarryTasks,
		MinLong = Config.Objectives.MinLongTasks,
		MaxLong = Config.Objectives.MaxLongTasks,
	}
	local registered: { [string]: boolean } = {}
	for _, p in MatchService.GetParticipants() do
		local cover = p.Faction == Constants.Faction.Infiltrator
		local list = {}
		for _, id in ObjectiveAssigner.assign(ObjectiveCatalog.Objectives, rules, rng) do
			local objective = ObjectiveCatalog.get(id) :: ObjectiveCatalog.Objective
			table.insert(list, { ObjectiveId = id, StepIndex = 1, Done = false, Cover = cover })
			if not cover then
				totalCrewSteps += #objective.Steps
			end
			for stepIndex in objective.Steps do
				local key = stationKeyFor(id, stepIndex) :: string
				if not registered[key] then
					registered[key] = true
					registerStation(key, objective, stepIndex)
				end
			end
		end
		tasks[p.Player] = list
		publishTasks(p.Player)
	end
	publishShared()
	updateRestoration()
	log:Info("Objectives assigned;", totalCrewSteps, "crew steps total")
end

-- Called at a muster: losses become public, so their objectives can be shared.
function ObjectiveService.ReleaseOrphans()
	if #pendingOrphans == 0 then
		return
	end
	for _, shared in pendingOrphans do
		table.insert(sharedTasks, shared)
	end
	table.clear(pendingOrphans)
	publishShared()
	InteractionService.Refresh()
end

local function orphan(player: Player, immediate: boolean)
	local list = tasks[player]
	if not list then
		return
	end
	for _, state in list do
		if not state.Done and not state.Cover then
			sharedCounter += 1
			local shared: SharedTask = {
				Key = "S" .. sharedCounter,
				ObjectiveId = state.ObjectiveId,
				StepIndex = state.StepIndex,
				Done = false,
			}
			state.Done = true -- no longer theirs
			if immediate then
				table.insert(sharedTasks, shared)
			else
				table.insert(pendingOrphans, shared)
			end
		end
	end
	if immediate then
		publishShared()
	end
end

function ObjectiveService.CancelAllSessions()
	for player in table.clone(sessions) do
		endSession(player, false, "Interrupted.")
	end
end

function ObjectiveService.Reset()
	for _, def in { "Task:" } do
		InteractionService.UnregisterPrefix(def)
	end
	for player in table.clone(carrying) do
		dropCarry(player, false)
	end
	for player in table.clone(sessions) do
		endSession(player, false, "Round ended.")
	end
	for player in tasks do
		if player.Parent == Players then
			ReplicationService.SetPrivate(player, Constants.PrivateKey.Tasks, nil)
		end
	end
	table.clear(tasks)
	table.clear(sharedTasks)
	table.clear(pendingOrphans)
	table.clear(cooldowns)
	table.clear(usedStations)
	picks = {}
	totalCrewSteps = 0
	completedCrewSteps = 0
	restorationFired = false
	ReplicationService.SetPublic(Constants.PublicKey.SharedTasks, nil)
end

-- Admin/debug: complete every remaining objective for `player`.
function ObjectiveService.DebugCompleteAll(player: Player)
	for _, state in tasks[player] or ({} :: { TaskState }) do
		local objective = ObjectiveCatalog.get(state.ObjectiveId) :: ObjectiveCatalog.Objective
		while not state.Done do
			local key = stationKeyFor(state.ObjectiveId, state.StepIndex) :: string
			local step = objective.Steps[state.StepIndex]
			if step.Kind == "Deliver" then
				dropCarry(player, false)
			end
			completeStep(player, { Own = state }, key)
		end
	end
end

-- Admin/debug: force restoration to a value.
function ObjectiveService.DebugSetRestoration(percent: number)
	completedCrewSteps = math.floor(totalCrewSteps * math.clamp(percent, 0, 100) / 100)
	updateRestoration()
end

function ObjectiveService.Start()
	RemoteService.OnEvent(Net.Names.MinigameSubmit, {
		Validate.string(24),
		function(value: any)
			if type(value) == "boolean" then
				return true
			elseif type(value) == "string" then
				return #value <= 12, "answer too long"
			elseif type(value) == "table" then
				local n = 0
				for _ in value do
					n += 1
				end
				return n <= 8, "answer too large"
			end
			return false, "bad answer type"
		end,
	}, onSubmit)

	RemoteService.OnEvent(Net.Names.MinigameCancel, { Validate.string(24) }, function(player: Player, sessionId: string)
		local session = sessions[player]
		if session and session.Id == sessionId then
			endSession(player, false, nil)
		end
	end)

	MatchService.LifeChanged:Connect(function(p, life)
		if life == Constants.LifeState.Alive or life == Constants.LifeState.Escaped then
			return
		end
		endSession(p.Player, false, "Interrupted.")
		dropCarry(p.Player, true)
		if p.Faction == Constants.Faction.Crew then
			if life == Constants.LifeState.Lost then
				orphan(p.Player, false)
			elseif life == Constants.LifeState.Confined or life == Constants.LifeState.Disconnected then
				orphan(p.Player, true)
			end
		end
		InteractionService.Refresh()
	end)

	-- Mini-game timeouts.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, session in table.clone(sessions) do
				local _, maxSeconds = Minigames.limits(session.Kind, session.Secret)
				local limit = maxSeconds + Config.Objectives.MinigameGraceSeconds
				if now - session.StartedAt > limit then
					failStation(player, session.StationKey, "Timed out.")
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		carrying[player] = nil
		cooldowns[player] = nil
		tasks[player] = nil
	end)
end

return ObjectiveService
