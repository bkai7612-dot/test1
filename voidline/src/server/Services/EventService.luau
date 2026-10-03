--!strict
--[[
	EventService
	Dynamic ship events. During normal play an event fires every
	MinInterval-MaxInterval seconds, chosen by weight from the events that are
	currently eligible (minimum round time, no conflicting hazard, under the
	concurrency cap). Targets (rooms/sections) are random each time, so no two
	rounds play out the same way.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local EventCatalog = require(Shared.Data.EventCatalog)
local ShipLayout = require(Shared.Data.ShipLayout)
local Logger = require(Shared.Utility.Logger)

local AnalyticsService = require(script.Parent.AnalyticsService)
local HazardService = require(script.Parent.HazardService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)

local log = Logger.new("EventService")

local EventService = {}

local nextEventAt: number? = nil
local enabled = true

local function randomTarget(targetType: string): string?
	if targetType == "Section" then
		return ShipLayout.Sections[math.random(1, #ShipLayout.Sections)]
	elseif targetType == "Room" then
		local rooms = ShipLayout.Rooms
		return rooms[math.random(1, #rooms)].Id
	end
	return nil
end

local function announce()
	local lines = EventCatalog.Announcements
	local line = lines[math.random(1, #lines)]
	line = string.gsub(line, "{Ship}", Config.Game.ShipName)
	line = string.gsub(line, "{AI}", Config.Game.AIName)
	NotifyService.Broadcast("ANNOUNCEMENT: " .. line, "Info", 6)
	NotifyService.CueAll("Announcement", {})
end

-- Runs one event. `forcedId` lets admins spawn a specific event. Returns success.
function EventService.Run(forcedId: string?): boolean
	local roundTime = MatchService.RoundTime()
	local candidates = {}
	local totalWeight = 0
	for _, event in EventCatalog.Events do
		local eligible = if forcedId then event.Id == forcedId else roundTime >= event.MinRoundSeconds
		if eligible then
			table.insert(candidates, event)
			totalWeight += event.Weight
		end
	end
	-- Try a few weighted picks; some may conflict with active hazards.
	for _ = 1, 6 do
		if #candidates == 0 then
			return false
		end
		local roll = math.random() * totalWeight
		local pick = candidates[#candidates]
		for _, event in candidates do
			roll -= event.Weight
			if roll <= 0 then
				pick = event
				break
			end
		end
		if not pick.Hazard then
			announce()
			AnalyticsService.Count("Event_" .. pick.Id)
			return true
		end
		local target = randomTarget(pick.Target)
		if not HazardService.Conflicts(pick.Hazard, target) then
			local hazard = HazardService.Begin(pick.Hazard, target, pick.Duration, "Event")
			if hazard then
				AnalyticsService.Count("Event_" .. pick.Id)
				log:Debug("Event", pick.Id, target)
				return true
			end
		end
	end
	return false
end

function EventService.ResetForMatch()
	nextEventAt = nil
	enabled = Config.Events.Enabled
end

function EventService.SetEnabled(value: boolean)
	enabled = value
end

function EventService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			if enabled and MatchService.IsState(Constants.RoundState.ActiveRound) and not MatchService.GetOutcome() then
				local t = MatchService.RoundTime()
				if not nextEventAt then
					nextEventAt = t + Config.Events.FirstEventAfter
				elseif t >= (nextEventAt :: number) then
					if HazardService.CountBySource("Event") < Config.Events.MaxConcurrent then
						EventService.Run(nil)
					end
					nextEventAt = t + math.random(Config.Events.MinInterval, Config.Events.MaxInterval)
				end
			end
		end
	end)
end

return EventService
