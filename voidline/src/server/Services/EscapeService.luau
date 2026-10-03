--!strict
--[[
	EscapeService
	The endgame. When Restoration hits 100% the ASTERION goes critical and
	one of several extraction routes is chosen at random. The crew must
	complete its steps in order (restore emergency power -> open the bay ->
	arm extraction), then survive a final countdown inside the extraction
	room. Infiltrators keep siphoning and can still lock doors or kill power.

	Outcome:
	  * Countdown ends with >= 1 crew member in the extraction room -> Crew win.
	  * The overall endgame timer runs out first, or no crew made it -> Infiltrators.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Types = require(Shared.Types)
local ShipLayout = require(Shared.Data.ShipLayout)
local WinConditions = require(Shared.Logic.WinConditions)
local Logger = require(Shared.Utility.Logger)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local InteractionService = require(script.Parent.InteractionService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local ReplicationService = require(script.Parent.ReplicationService)

local log = Logger.new("EscapeService")

local EscapeService = {}

type State = {
	Route: ShipLayout.EscapeRoute,
	StepIndex: number,
	EndsAt: number,
	ExtractionEndsAt: number?,
	Finished: boolean,
}

local state: State? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish()
	local s = state
	if not s then
		ReplicationService.SetPublic(Constants.PublicKey.Escape, nil)
		return
	end
	local steps = {}
	for index, step in s.Route.Steps do
		table.insert(steps, {
			Label = step.Label,
			Room = step.Room,
			RoomName = ShipLayout.areaName(step.Room),
			Anchor = string.format("Escape:%s.%d", s.Route.Id, index),
			Done = index < s.StepIndex,
		})
	end
	ReplicationService.SetPublic(Constants.PublicKey.Escape, {
		RouteId = s.Route.Id,
		RouteName = s.Route.Name,
		Steps = steps,
		StepIndex = s.StepIndex,
		ExtractionRoom = s.Route.ExtractionRoom,
		ExtractionRoomName = ShipLayout.areaName(s.Route.ExtractionRoom),
		EndsAt = s.EndsAt,
		ExtractionEndsAt = s.ExtractionEndsAt,
	})
	if s.ExtractionEndsAt then
		MatchService.SetTimer("Extraction", s.ExtractionEndsAt)
	else
		MatchService.SetTimer("Ship breakup", s.EndsAt)
	end
end

local function finishExtraction()
	local s = state
	if not s or s.Finished then
		return
	end
	s.Finished = true
	local crewEscaped = 0
	for _, p in MatchService.Living() do
		if p.Life == Constants.LifeState.Alive then
			local root = CharacterService.GetRoot(p.Player)
			local area = if root then MapService.AreaAt(root.Position) else nil
			if area == s.Route.ExtractionRoom then
				MatchService.SetLife(p, Constants.LifeState.Escaped :: Types.LifeState)
				if p.Faction == Constants.Faction.Crew then
					crewEscaped += 1
				end
				AnalyticsService.Count("Escapes")
			end
		end
	end
	local winner, reason = WinConditions.extraction(crewEscaped, MatchService.GetTotalInfiltrators())
	MatchService.DeclareOutcome(winner, reason)
end

local function registerSteps()
	local s = state :: State
	for index, step in s.Route.Steps do
		local anchor = string.format("Escape:%s.%d", s.Route.Id, index)
		MapService.SetScreen(anchor, if index == 1 then string.upper(step.Label) else "LOCKED")
		InteractionService.Register({
			Id = "Escape:" .. index,
			Anchor = anchor,
			Action = step.Label,
			Object = s.Route.Name,
			Hold = Config.Escape.StepHoldSeconds,
			Key = 1,
			Visible = function(player)
				local current = state
				return current ~= nil
					and not current.Finished
					and current.StepIndex == index
					and MatchService.IsState(Constants.RoundState.Endgame)
					and MatchService.IsActive(player)
			end,
			OnComplete = function(player)
				local current = state
				if not current or current.StepIndex ~= index then
					return
				end
				current.StepIndex += 1
				MapService.SetScreen(anchor, "ONLINE", Color3.fromRGB(120, 255, 160))
				local nextStep = current.Route.Steps[current.StepIndex]
				if nextStep then
					MapService.SetScreen(string.format("Escape:%s.%d", current.Route.Id, current.StepIndex), string.upper(nextStep.Label))
					NotifyService.Broadcast(
						string.format("%s: %s complete. Next: %s in %s.", player.DisplayName, step.Label, nextStep.Label, ShipLayout.areaName(nextStep.Room)),
						"Success",
						5
					)
				else
					current.ExtractionEndsAt = now() + Config.Escape.ExtractionCountdown
					MapService.SetExtractionMarker(current.Route.Id, true)
					NotifyService.Broadcast(
						string.format("Extraction armed! Get to %s before the countdown ends!", ShipLayout.areaName(current.Route.ExtractionRoom)),
						"Alert",
						6
					)
					NotifyService.CueAll("ExtractionArmed", { Room = current.Route.ExtractionRoom })
				end
				publish()
				InteractionService.Refresh()
			end,
		})
	end
end

function EscapeService.Begin()
	local routes = ShipLayout.EscapeRoutes
	local route = routes[math.random(1, #routes)]
	state = {
		Route = route,
		StepIndex = 1,
		EndsAt = now() + Config.Escape.TotalSeconds,
		ExtractionEndsAt = nil,
		Finished = false,
	}
	registerSteps()
	publish()
	NotifyService.Broadcast(
		string.format("The ASTERION is breaking apart! Extraction via %s. First: %s in %s.", route.Name, route.Steps[1].Label, ShipLayout.areaName(route.Steps[1].Room)),
		"Alert",
		7
	)
	NotifyService.CueAll("EndgameStarted", { Route = route.Id })
	MapService.SetLights("Alarm", nil)
	log:Info("Endgame route:", route.Id)
	InteractionService.Refresh()
end

function EscapeService.Reset()
	state = nil
	InteractionService.UnregisterPrefix("Escape:")
	publish()
end

function EscapeService.Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local s = state
			if s and not s.Finished and MatchService.IsState(Constants.RoundState.Endgame) then
				local t = now()
				if s.ExtractionEndsAt and t >= s.ExtractionEndsAt then
					finishExtraction()
				elseif not s.ExtractionEndsAt and t >= s.EndsAt then
					s.Finished = true
					MatchService.DeclareOutcome(Constants.Winner.Infiltrator, "The ASTERION broke apart before extraction was armed.")
				end
			end
		end
	end)
end

return EscapeService
