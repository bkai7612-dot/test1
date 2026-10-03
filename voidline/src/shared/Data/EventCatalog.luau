--!strict
--[[
	EventCatalog
	Dynamic ship events picked by EventService during a round. Events either
	start a hazard (fixable by the crew) or are pure announcements. Weights
	control how often each appears.
]]

local TableUtil = require(script.Parent.Parent.Utility.TableUtil)

export type ShipEvent = {
	Id: string,
	Name: string,
	Weight: number,
	Hazard: string?,
	Target: "Ship" | "Section" | "Room" | "None",
	Duration: number,
	MinRoundSeconds: number,
	Announcement: string?,
}

local EVENTS: { ShipEvent } = {
	{ Id = "PowerOutage", Name = "Power outage", Weight = 3, Hazard = "Darkness", Target = "Section", Duration = 14, MinRoundSeconds = 0 },
	{ Id = "HullBreach", Name = "Hull breach", Weight = 2, Hazard = "Breach", Target = "Room", Duration = 45, MinRoundSeconds = 90 },
	{ Id = "Fire", Name = "Fire", Weight = 2, Hazard = "Fire", Target = "Room", Duration = 45, MinRoundSeconds = 60 },
	{ Id = "ComputerMalfunction", Name = "Computer malfunction", Weight = 3, Hazard = "Malfunction", Target = "Room", Duration = 35, MinRoundSeconds = 0 },
	{ Id = "GravityDisturbance", Name = "Gravity disturbance", Weight = 2, Hazard = "Gravity", Target = "Room", Duration = 20, MinRoundSeconds = 0 },
	{ Id = "SecurityGlitch", Name = "Security lockdown", Weight = 2, Hazard = "Lockdown", Target = "Section", Duration = 10, MinRoundSeconds = 60 },
	{ Id = "ReactorInstability", Name = "Reactor instability", Weight = 2, Hazard = "ReactorUnstable", Target = "Ship", Duration = 40, MinRoundSeconds = 120 },
	{ Id = "EquipmentFailure", Name = "Equipment failure", Weight = 2, Hazard = "Damage", Target = "Room", Duration = 60, MinRoundSeconds = 30 },
	{ Id = "UnknownSignal", Name = "Unknown signal", Weight = 1, Hazard = "Signal", Target = "Ship", Duration = 60, MinRoundSeconds = 150 },
	{ Id = "Announcement", Name = "Automated announcement", Weight = 3, Target = "None", Duration = 0, MinRoundSeconds = 0 },
}

-- Flavour lines for automated announcements. {Ship} and {AI} are substituted.
local ANNOUNCEMENTS = {
	"Reminder: the {Ship} is a research vessel. Please do not lick the samples.",
	"Hull integrity monitoring is operating within tolerances. Mostly.",
	"Crew morale survey postponed due to ongoing catastrophe.",
	"Unregistered processes detected in ship memory. Origin: unknown.",
	"Hydroponics reports the tomatoes are, against all odds, thriving.",
	"Please keep corridors clear. Emergency drills are now emergencies.",
	"Biosignature census pending. Do not panic. Panic is not in the manual.",
	"Coffee dispenser offline. Estimated repair time: never.",
	"Navigation reminds you that space remains very large.",
	"Low-level interference on internal channels. Stay with your crewmates.",
}

local EventCatalog = {}

local byId: { [string]: ShipEvent } = {}
for _, event in EVENTS do
	byId[event.Id] = event
end

EventCatalog.Events = EVENTS
EventCatalog.Announcements = ANNOUNCEMENTS

function EventCatalog.get(id: string): ShipEvent?
	return byId[id]
end

function EventCatalog.ids(): { string }
	local ids = {}
	for _, event in EVENTS do
		table.insert(ids, event.Id)
	end
	return ids
end

return TableUtil.deepFreeze(EventCatalog)
