--!strict
--[[
	HazardCatalog
	Hazards are the ship-side effects shared by infiltrator sabotage and
	dynamic events (a "Power Surge" sabotage and a "Power Outage" event both
	create a Darkness hazard). Each hazard kind defines how it is targeted and
	how the crew fixes it.

	Fix fixture ids may contain {Section} or {Room}, replaced by the target.
	Fix modes:
	  Any          - complete any one listed fixture
	  All          - complete every listed fixture (any order, any players)
	  Simultaneous - complete every listed fixture within DualValveWindowSeconds
	                 (needs two people)
	  None         - cannot be fixed; ends when its timer runs out
]]

local TableUtil = require(script.Parent.Parent.Utility.TableUtil)

export type FixMode = "Any" | "All" | "Simultaneous" | "None"
export type HazardKind = {
	Id: string,
	Name: string,
	Target: "Ship" | "Section" | "Room",
	Critical: boolean,
	Fix: { Mode: FixMode, Fixtures: { string }, Hold: number, Action: string },
	-- Continuous stability loss while active (per second).
	StabilityDrain: number,
	-- Stability change when fixed (rewarding events).
	FixReward: number,
	-- Stability loss if a critical hazard times out.
	FailurePenalty: number,
	Caption: string,
}

local KINDS: { HazardKind } = {
	{
		Id = "Darkness",
		Name = "Power Failure",
		Target = "Section",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "Breaker.{Section}" }, Hold = 3, Action = "Reset breaker" },
		StabilityDrain = 0,
		FixReward = 0,
		FailurePenalty = 0,
		Caption = "Power lost in the {Target} section.",
	},
	{
		Id = "Blackout",
		Name = "Lighting Failure",
		Target = "Ship",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "LightsPanel" }, Hold = 4, Action = "Restore lighting bus" },
		StabilityDrain = 0,
		FixReward = 0,
		FailurePenalty = 0,
		Caption = "Ship-wide lighting failure.",
	},
	{
		Id = "Gravity",
		Name = "Gravity Failure",
		Target = "Room",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "Node.{Room}" }, Hold = 3, Action = "Stabilize gravity" },
		StabilityDrain = 0,
		FixReward = 0,
		FailurePenalty = 0,
		Caption = "Artificial gravity failing in {Target}.",
	},
	{
		Id = "Jam",
		Name = "Communication Jam",
		Target = "Section",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "Breaker.{Section}" }, Hold = 3, Action = "Reboot comm relay" },
		StabilityDrain = 0,
		FixReward = 0,
		FailurePenalty = 0,
		Caption = "Communications jammed in the {Target} section.",
	},
	{
		Id = "Lockdown",
		Name = "Security Lockdown",
		Target = "Section",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "Breaker.{Section}" }, Hold = 4, Action = "Override lockdown" },
		StabilityDrain = 0,
		FixReward = 0,
		FailurePenalty = 0,
		Caption = "Security lockdown in the {Target} section.",
	},
	{
		Id = "Coolant",
		Name = "Coolant Failure",
		Target = "Ship",
		Critical = true,
		Fix = { Mode = "Simultaneous", Fixtures = { "Coolant.A", "Coolant.B" }, Hold = 3, Action = "Open coolant valve" },
		StabilityDrain = 0.1,
		FixReward = 0,
		FailurePenalty = 30,
		Caption = "CRITICAL: reactor coolant failure. Open both valves together.",
	},
	{
		Id = "Oxygen",
		Name = "Oxygen Imbalance",
		Target = "Ship",
		Critical = true,
		Fix = { Mode = "All", Fixtures = { "O2.A", "O2.B" }, Hold = 3, Action = "Rebalance oxygen" },
		StabilityDrain = 0.1,
		FixReward = 0,
		FailurePenalty = 30,
		Caption = "CRITICAL: oxygen mix failing. Rebalance both mixers.",
	},
	{
		Id = "NavScramble",
		Name = "Navigation Error",
		Target = "Ship",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "NavConsole" }, Hold = 3, Action = "Reset nav indicators" },
		StabilityDrain = 0.05,
		FixReward = 0,
		FailurePenalty = 0,
		Caption = "Navigation indicators unreliable.",
	},
	{
		Id = "Fire",
		Name = "Fire",
		Target = "Room",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "Node.{Room}" }, Hold = 4, Action = "Trigger suppression" },
		StabilityDrain = 0.12,
		FixReward = 1,
		FailurePenalty = 0,
		Caption = "Fire detected in {Target}.",
	},
	{
		Id = "Breach",
		Name = "Hull Breach",
		Target = "Room",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "Node.{Room}" }, Hold = 4, Action = "Seal breach" },
		StabilityDrain = 0.15,
		FixReward = 1,
		FailurePenalty = 0,
		Caption = "Hull breach in {Target}! Seal it at the systems node.",
	},
	{
		Id = "Malfunction",
		Name = "Computer Malfunction",
		Target = "Room",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "Node.{Room}" }, Hold = 3, Action = "Reboot room systems" },
		StabilityDrain = 0,
		FixReward = 1,
		FailurePenalty = 0,
		Caption = "Consoles in {Target} have crashed.",
	},
	{
		Id = "Damage",
		Name = "Equipment Failure",
		Target = "Room",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "Node.{Room}" }, Hold = 4, Action = "Repair equipment" },
		StabilityDrain = 0.05,
		FixReward = 3,
		FailurePenalty = 0,
		Caption = "Equipment failure reported in {Target}.",
	},
	{
		Id = "ReactorUnstable",
		Name = "Reactor Instability",
		Target = "Ship",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "Node.ReactorChamber" }, Hold = 4, Action = "Dampen reactor" },
		StabilityDrain = 0.3,
		FixReward = 2,
		FailurePenalty = 0,
		Caption = "Reactor output unstable.",
	},
	{
		Id = "Signal",
		Name = "Unknown Signal",
		Target = "Ship",
		Critical = false,
		Fix = { Mode = "Any", Fixtures = { "Node.Communications" }, Hold = 5, Action = "Decode signal" },
		StabilityDrain = 0,
		FixReward = 4,
		FailurePenalty = 0,
		Caption = "An unknown signal is reaching the ship.",
	},
}

local HazardCatalog = {}

local byId: { [string]: HazardKind } = {}
for _, kind in KINDS do
	byId[kind.Id] = kind
end

HazardCatalog.Kinds = KINDS

function HazardCatalog.get(id: string): HazardKind?
	return byId[id]
end

-- Resolves fixture templates for a target.
function HazardCatalog.fixturesFor(kind: HazardKind, target: string?): { string }
	local list = {}
	for _, template in kind.Fix.Fixtures do
		local id = template
		if target then
			id = string.gsub(id, "{Section}", target)
			id = string.gsub(id, "{Room}", target)
		end
		table.insert(list, id)
	end
	return list
end

return TableUtil.deepFreeze(HazardCatalog)
