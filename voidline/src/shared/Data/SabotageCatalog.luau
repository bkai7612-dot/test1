--!strict
--[[
	SabotageCatalog
	Infiltrator sabotage options. Each one starts a hazard (see HazardCatalog)
	and has its own cooldown in addition to the shared global cooldown.
	Critical sabotages put the round into the EMERGENCY state.
]]

local TableUtil = require(script.Parent.Parent.Utility.TableUtil)

export type Sabotage = {
	Id: string,
	Name: string,
	Description: string,
	Hazard: string,
	Target: "Ship" | "Section" | "Room",
	Duration: number,
	Cooldown: number,
}

local SABOTAGES: { Sabotage } = {
	{
		Id = "PowerSurge",
		Name = "Power Surge",
		Description = "Kill power and lights in one section until its breaker is reset.",
		Hazard = "Darkness",
		Target = "Section",
		Duration = 30,
		Cooldown = 60,
	},
	{
		Id = "GravityFailure",
		Name = "Gravity Failure",
		Description = "Make one room float. Jumps go high, footing goes bad.",
		Hazard = "Gravity",
		Target = "Room",
		Duration = 30,
		Cooldown = 55,
	},
	{
		Id = "CommsJam",
		Name = "Communication Jam",
		Description = "Garble text chat and silence the radio in one section.",
		Hazard = "Jam",
		Target = "Section",
		Duration = 40,
		Cooldown = 70,
	},
	{
		Id = "SecurityLockdown",
		Name = "Security Lockdown",
		Description = "Seal every door in one section. Doors can be overridden by hand.",
		Hazard = "Lockdown",
		Target = "Section",
		Duration = 16,
		Cooldown = 60,
	},
	{
		Id = "CoolantFailure",
		Name = "Coolant Failure",
		Description = "CRITICAL. Two crew must open both coolant valves together.",
		Hazard = "Coolant",
		Target = "Ship",
		Duration = 45,
		Cooldown = 120,
	},
	{
		Id = "LightingFailure",
		Name = "Lighting Failure",
		Description = "Dim the whole ship. Your MURMUR link keeps your sight sharp.",
		Hazard = "Blackout",
		Target = "Ship",
		Duration = 50,
		Cooldown = 90,
	},
	{
		Id = "OxygenImbalance",
		Name = "Oxygen Imbalance",
		Description = "CRITICAL. Both oxygen mixers must be rebalanced in time.",
		Hazard = "Oxygen",
		Target = "Ship",
		Duration = 50,
		Cooldown = 120,
	},
	{
		Id = "NavigationError",
		Name = "Navigation Error",
		Description = "Scramble room readouts and objective markers for the crew.",
		Hazard = "NavScramble",
		Target = "Ship",
		Duration = 45,
		Cooldown = 75,
	},
}

local SabotageCatalog = {}

local byId: { [string]: Sabotage } = {}
for _, sabotage in SABOTAGES do
	byId[sabotage.Id] = sabotage
end

SabotageCatalog.Sabotages = SABOTAGES

function SabotageCatalog.get(id: string): Sabotage?
	return byId[id]
end

function SabotageCatalog.ids(): { string }
	local ids = {}
	for _, sabotage in SABOTAGES do
		table.insert(ids, sabotage.Id)
	end
	return ids
end

return TableUtil.deepFreeze(SabotageCatalog)
