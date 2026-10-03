--!strict
--[[
	ObjectiveCatalog
	Every crew objective. Each objective is a list of steps; each step names
	its interaction kind and one or more alternative stations. At the start of
	a round ObjectiveService picks one alternative per step, so objective
	locations vary between rounds while staying learnable.

	Step kinds:
	  Hold      - hold the prompt for `Hold` seconds
	  Sliders   - align sliders to target marks         (mini-game)
	  Sequence  - enter a displayed code                (mini-game)
	  Timing    - lock a moving needle inside zones     (mini-game)
	  Wires     - connect matching coloured relays      (mini-game)
	  Pickup    - collect a component (carried visibly)
	  Deliver   - install the carried component
]]

local TableUtil = require(script.Parent.Parent.Utility.TableUtil)

export type StepKind = "Hold" | "Sliders" | "Sequence" | "Timing" | "Wires" | "Pickup" | "Deliver"
export type Station = { Room: string, Anchor: string }
export type Step = {
	Kind: StepKind,
	Label: string,
	Hold: number?,
	Item: string?,
	Stations: { Station },
}
export type Objective = {
	Id: string,
	Name: string,
	Category: string,
	Length: "Short" | "Long" | "Carry",
	Steps: { Step },
}

local OBJECTIVES: { Objective } = {
	-- POWER ---------------------------------------------------------------
	{
		Id = "AlignRegulators",
		Name = "Align power regulators",
		Category = "Power",
		Length = "Short",
		Steps = {
			{ Kind = "Sliders", Label = "Align regulators", Stations = {
				{ Room = "Engineering", Anchor = "W1" },
				{ Room = "ReactorChamber", Anchor = "W1" },
			} },
		},
	},
	{
		Id = "RestartGenerators",
		Name = "Restart auxiliary generators",
		Category = "Power",
		Length = "Long",
		Steps = {
			{ Kind = "Hold", Label = "Prime generator", Hold = 3, Stations = {
				{ Room = "Engineering", Anchor = "SW" },
				{ Room = "Hydroponics", Anchor = "NW" },
			} },
			{ Kind = "Timing", Label = "Sync generator phase", Stations = {
				{ Room = "ReactorChamber", Anchor = "SE" },
			} },
		},
	},
	{
		Id = "ReplaceFuses",
		Name = "Replace damaged fuses",
		Category = "Power",
		Length = "Carry",
		Steps = {
			{ Kind = "Pickup", Label = "Collect fuse cartridge", Item = "Fuse cartridge", Hold = 1, Stations = {
				{ Room = "CargoStorage", Anchor = "NW" },
				{ Room = "Laboratory", Anchor = "NW" },
			} },
			{ Kind = "Deliver", Label = "Install fuse", Hold = 2, Stations = {
				{ Room = "MaintenanceHub", Anchor = "S1" },
				{ Room = "LowerJunction", Anchor = "SE" },
			} },
		},
	},
	{
		Id = "BalanceEnergy",
		Name = "Balance energy distribution",
		Category = "Power",
		Length = "Long",
		Steps = {
			{ Kind = "Sliders", Label = "Set reactor output", Stations = {
				{ Room = "ReactorChamber", Anchor = "NE" },
			} },
			{ Kind = "Sliders", Label = "Balance ship load", Stations = {
				{ Room = "CentralOps", Anchor = "NE" },
			} },
		},
	},
	-- COMMUNICATIONS ------------------------------------------------------
	{
		Id = "ReconnectRelays",
		Name = "Reconnect communication relays",
		Category = "Communications",
		Length = "Short",
		Steps = {
			{ Kind = "Wires", Label = "Patch relays", Stations = {
				{ Room = "Communications", Anchor = "NW" },
				{ Room = "Navigation", Anchor = "NW" },
			} },
		},
	},
	{
		Id = "CalibrateAntenna",
		Name = "Calibrate antennas",
		Category = "Communications",
		Length = "Short",
		Steps = {
			{ Kind = "Timing", Label = "Calibrate antenna", Stations = {
				{ Room = "ObservationDeck", Anchor = "G1" },
				{ Room = "Communications", Anchor = "SE" },
			} },
		},
	},
	{
		Id = "RestoreSignal",
		Name = "Restore signal strength",
		Category = "Communications",
		Length = "Short",
		Steps = {
			{ Kind = "Hold", Label = "Boost signal", Hold = 5, Stations = {
				{ Room = "Navigation", Anchor = "SE" },
				{ Room = "ObservationDeck", Anchor = "SE" },
			} },
		},
	},
	{
		Id = "DecodeTransmission",
		Name = "Decode transmission data",
		Category = "Communications",
		Length = "Long",
		Steps = {
			{ Kind = "Sequence", Label = "Decode packet", Stations = {
				{ Room = "Communications", Anchor = "NE" },
			} },
			{ Kind = "Hold", Label = "Upload decoded data", Hold = 3, Stations = {
				{ Room = "CentralOps", Anchor = "SW" },
			} },
		},
	},
	-- MEDICAL -------------------------------------------------------------
	{
		Id = "RestoreMedScanner",
		Name = "Restore medical equipment",
		Category = "Medical",
		Length = "Short",
		Steps = {
			{ Kind = "Timing", Label = "Recalibrate scanner", Stations = {
				{ Room = "MedicalBay", Anchor = "NW" },
			} },
		},
	},
	{
		Id = "StabilizeLifeSupport",
		Name = "Stabilize emergency systems",
		Category = "Medical",
		Length = "Short",
		Steps = {
			{ Kind = "Hold", Label = "Stabilize life support", Hold = 4, Stations = {
				{ Room = "EmergencyShelter", Anchor = "NW" },
				{ Room = "CrewQuarters", Anchor = "NE" },
			} },
		},
	},
	{
		Id = "RetrieveMedSupplies",
		Name = "Retrieve medical supplies",
		Category = "Medical",
		Length = "Carry",
		Steps = {
			{ Kind = "Pickup", Label = "Collect med crate", Item = "Medical crate", Hold = 1, Stations = {
				{ Room = "CargoStorage", Anchor = "SE" },
			} },
			{ Kind = "Deliver", Label = "Stock medical bay", Hold = 2, Stations = {
				{ Room = "MedicalBay", Anchor = "NE" },
			} },
		},
	},
	{
		Id = "CalibrateBiomonitors",
		Name = "Calibrate biomonitors",
		Category = "Medical",
		Length = "Short",
		Steps = {
			{ Kind = "Wires", Label = "Rewire biomonitor", Stations = {
				{ Room = "MedicalBay", Anchor = "SW" },
				{ Room = "EmergencyShelter", Anchor = "SE" },
			} },
		},
	},
	-- ENGINEERING ---------------------------------------------------------
	{
		Id = "RepairCoolantPump",
		Name = "Repair coolant pumps",
		Category = "Engineering",
		Length = "Short",
		Steps = {
			{ Kind = "Wires", Label = "Repair pump controller", Stations = {
				{ Room = "ReactorChamber", Anchor = "SW" },
				{ Room = "Engineering", Anchor = "NW" },
			} },
		},
	},
	{
		Id = "ReplaceComponent",
		Name = "Replace components",
		Category = "Engineering",
		Length = "Carry",
		Steps = {
			{ Kind = "Pickup", Label = "Collect servo unit", Item = "Servo unit", Hold = 1, Stations = {
				{ Room = "Laboratory", Anchor = "SE" },
			} },
			{ Kind = "Deliver", Label = "Fit servo unit", Hold = 2, Stations = {
				{ Room = "Engineering", Anchor = "SE" },
			} },
		},
	},
	{
		Id = "StabilizePressure",
		Name = "Stabilize pressure",
		Category = "Engineering",
		Length = "Short",
		Steps = {
			{ Kind = "Sliders", Label = "Equalize pressure", Stations = {
				{ Room = "Hydroponics", Anchor = "NE" },
				{ Room = "LowerJunction", Anchor = "NW" },
			} },
		},
	},
	{
		Id = "RestartRecycler",
		Name = "Restart machinery",
		Category = "Engineering",
		Length = "Long",
		Steps = {
			{ Kind = "Hold", Label = "Flush recycler", Hold = 3, Stations = {
				{ Room = "Hydroponics", Anchor = "SW" },
			} },
			{ Kind = "Wires", Label = "Restart recycler bus", Stations = {
				{ Room = "MaintenanceHub", Anchor = "NW" },
			} },
		},
	},
	-- NAVIGATION ----------------------------------------------------------
	{
		Id = "RecalculateTrajectory",
		Name = "Recalculate trajectory",
		Category = "Navigation",
		Length = "Short",
		Steps = {
			{ Kind = "Sequence", Label = "Enter course solution", Stations = {
				{ Room = "Navigation", Anchor = "NE" },
				{ Room = "ObservationDeck", Anchor = "NE" },
			} },
		},
	},
	{
		Id = "RepairNavSensors",
		Name = "Repair navigation sensors",
		Category = "Navigation",
		Length = "Short",
		Steps = {
			{ Kind = "Timing", Label = "Realign sensor array", Stations = {
				{ Room = "LowerJunction", Anchor = "NE" },
				{ Room = "EscapeHangar", Anchor = "NE" },
			} },
		},
	},
	{
		Id = "RestoreNavComputer",
		Name = "Restore navigation computers",
		Category = "Navigation",
		Length = "Long",
		Steps = {
			{ Kind = "Wires", Label = "Reseat nav cores", Stations = {
				{ Room = "Navigation", Anchor = "SW" },
			} },
			{ Kind = "Sliders", Label = "Tune nav uplink", Stations = {
				{ Room = "CentralOps", Anchor = "NW" },
			} },
		},
	},
	-- SHIP SERVICES -------------------------------------------------------
	{
		Id = "AnalyzeSamples",
		Name = "Analyze research samples",
		Category = "Science",
		Length = "Short",
		Steps = {
			{ Kind = "Sequence", Label = "Run sample analysis", Stations = {
				{ Room = "Laboratory", Anchor = "NE" },
				{ Room = "Hydroponics", Anchor = "SE" },
			} },
		},
	},
	{
		Id = "CleanAirFilters",
		Name = "Clean air filters",
		Category = "Life Support",
		Length = "Short",
		Steps = {
			{ Kind = "Hold", Label = "Purge filters", Hold = 4, Stations = {
				{ Room = "CrewQuarters", Anchor = "SW" },
				{ Room = "EscapeHangar", Anchor = "SW" },
			} },
		},
	},
	{
		Id = "SortCargo",
		Name = "Secure loose cargo",
		Category = "Logistics",
		Length = "Short",
		Steps = {
			{ Kind = "Hold", Label = "Lock cargo straps", Hold = 3, Stations = {
				{ Room = "CargoStorage", Anchor = "SW" },
				{ Room = "EscapeHangar", Anchor = "NW" },
			} },
		},
	},
	{
		Id = "ResetBunkSystems",
		Name = "Reset habitat systems",
		Category = "Life Support",
		Length = "Short",
		Steps = {
			{ Kind = "Sliders", Label = "Tune habitat climate", Stations = {
				{ Room = "CrewQuarters", Anchor = "SE" },
				{ Room = "EmergencyShelter", Anchor = "SW" },
			} },
		},
	},
}

local ObjectiveCatalog = {}

local byId: { [string]: Objective } = {}
for _, objective in OBJECTIVES do
	byId[objective.Id] = objective
end

ObjectiveCatalog.Objectives = OBJECTIVES

function ObjectiveCatalog.get(id: string): Objective?
	return byId[id]
end

-- Mini-game step kinds (resolved through a server-issued challenge).
ObjectiveCatalog.MinigameKinds = { Sliders = true, Sequence = true, Timing = true, Wires = true }

-- Unique id of one physical station: "<ObjectiveId>.<step>.<alternative>".
function ObjectiveCatalog.stationKey(objectiveId: string, stepIndex: number, altIndex: number): string
	return string.format("%s.%d.%d", objectiveId, stepIndex, altIndex)
end

return TableUtil.deepFreeze(ObjectiveCatalog)
