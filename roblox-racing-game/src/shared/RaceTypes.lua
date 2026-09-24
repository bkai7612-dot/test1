-- Race formats. The lobby round votes on one; team matches pick Circuit or
-- Sprint at random; Free Drive is its own mode with no timer or rewards.
local RaceTypes = {}

RaceTypes.Order = { "Circuit", "Sprint", "Elimination" }

RaceTypes.List = {
	Circuit = {
		id = "Circuit",
		name = "Circuit",
		description = "Classic multi-lap race. First across the line wins.",
		color = Color3.fromRGB(255, 120, 30),
	},
	Sprint = {
		id = "Sprint",
		name = "Sprint",
		description = "A long point-to-point road. First across the finish line wins.",
		color = Color3.fromRGB(0, 200, 255),
	},
	Elimination = {
		id = "Elimination",
		name = "Elimination",
		description = "Last place is knocked out every lap until one racer is left. Needs 3+ racers.",
		color = Color3.fromRGB(235, 60, 60),
		minRacers = 3,
	},
	FreeDrive = {
		id = "FreeDrive",
		name = "Free Drive",
		description = "Cruise any circuit with no timer, no opponents to beat and no rewards.",
		color = Color3.fromRGB(60, 210, 110),
	},
}

-- Falls back to Circuit when a format can't run with this many racers.
function RaceTypes.Resolve(typeId, racerCount)
	local info = RaceTypes.List[typeId]
	if not info or typeId == "FreeDrive" then
		return "Circuit"
	end
	if info.minRacers and racerCount < info.minRacers then
		return "Circuit"
	end
	return typeId
end

function RaceTypes.Laps(typeId, map, racerCount)
	if typeId == "Sprint" then
		return 1
	elseif typeId == "Elimination" then
		-- One knockout per lap until two remain, then a final lap.
		return math.clamp(racerCount - 1, 2, 6)
	end
	return map.laps
end

return RaceTypes
