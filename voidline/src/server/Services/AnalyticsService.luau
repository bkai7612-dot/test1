--!strict
--[[
	AnalyticsService
	Gameplay telemetry hooks. Aggregates counters in memory (visible in the
	admin server-state query) and forwards events to Roblox's built-in
	AnalyticsService when available.

	Only gameplay facts are recorded (event names, counts, durations, ids
	from our own catalogs). No chat, no names, no personal information.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxAnalytics = game:GetService("AnalyticsService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.Utility.Logger)

local log = Logger.new("Analytics")

local AnalyticsService = {}

local counters: { [string]: number } = {}
local roundDurations: { number } = {}
local warnedUnavailable = false

local function bump(name: string, amount: number?)
	counters[name] = (counters[name] or 0) + (amount or 1)
end

-- Records a custom event. `player` is optional (Roblox attributes events to a player when given).
function AnalyticsService.Track(name: string, value: number?, fields: { [string]: any }?, player: Player?)
	bump(name)
	log:Debug("event", name, value or "", if fields then table.concat((function()
		local parts = {}
		for k, v in fields do
			table.insert(parts, k .. "=" .. tostring(v))
		end
		return parts
	end)(), ",") else "")
	if not player then
		return
	end
	local ok, err = pcall(function()
		local customFields: { [string]: any }? = nil
		if fields then
			-- Roblox supports up to three custom field slots.
			customFields = {}
			local slots = { Enum.AnalyticsCustomFieldKeys.CustomField01.Name, Enum.AnalyticsCustomFieldKeys.CustomField02.Name, Enum.AnalyticsCustomFieldKeys.CustomField03.Name }
			local i = 0
			for k, v in fields do
				i += 1
				if i > 3 then
					break
				end
				(customFields :: any)[slots[i]] = k .. ":" .. tostring(v)
			end
		end
		RobloxAnalytics:LogCustomEvent(player, name, value or 1, customFields :: any)
	end)
	if not ok and not warnedUnavailable then
		warnedUnavailable = true
		log:Debug("Roblox analytics unavailable:", err)
	end
end

function AnalyticsService.RoundCompleted(durationSeconds: number, winner: string, participants: number)
	bump("RoundsCompleted")
	bump("Winner_" .. winner)
	table.insert(roundDurations, durationSeconds)
	if #roundDurations > 200 then
		table.remove(roundDurations, 1)
	end
	log:Info(string.format("Round complete: %s win after %ds with %d players", winner, math.floor(durationSeconds), participants))
end

function AnalyticsService.Onboarding(player: Player, step: number, name: string)
	bump("Onboarding_" .. name)
	pcall(function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function AnalyticsService.Count(name: string, amount: number?)
	bump(name, amount)
end

-- Snapshot for the admin panel.
function AnalyticsService.Summary(): { [string]: any }
	local total = 0
	for _, d in roundDurations do
		total += d
	end
	return {
		Counters = table.clone(counters),
		AverageRoundSeconds = if #roundDurations > 0 then math.floor(total / #roundDurations) else 0,
		RoundsSampled = #roundDurations,
	}
end

return AnalyticsService
