--!strict
--[[
	WinConditions
	Pure evaluation of whether a round has been decided.
	"Alive" counts include players in stasis (they can still be revived).
]]

local WinConditions = {}

export type Snapshot = {
	AliveCrew: number,
	AliveInfiltrators: number,
	TotalInfiltrators: number,
	Stability: number,
}

-- Returns (winner, reason) or (nil, nil) if the round continues.
function WinConditions.evaluate(s: Snapshot): (string?, string?)
	if s.AliveCrew <= 0 then
		if s.TotalInfiltrators > 0 then
			return "Infiltrator", "No crew remain aboard the ASTERION."
		end
		return "None", "Nobody remains aboard."
	end
	if s.TotalInfiltrators > 0 and s.AliveInfiltrators <= 0 then
		return "Crew", "Every infiltrator has been confined."
	end
	if s.AliveInfiltrators > 0 and s.AliveInfiltrators >= s.AliveCrew then
		return "Infiltrator", "The infiltrators now outnumber the crew."
	end
	if s.Stability <= 0 then
		if s.TotalInfiltrators > 0 then
			return "Infiltrator", "The ASTERION has broken apart."
		end
		return "None", "The ASTERION has broken apart."
	end
	return nil, nil
end

-- Outcome of the extraction sequence.
function WinConditions.extraction(crewEscaped: number, totalInfiltrators: number): (string, string)
	if crewEscaped > 0 then
		return "Crew", string.format("%d crew member%s escaped the ASTERION.", crewEscaped, if crewEscaped == 1 then "" else "s")
	end
	if totalInfiltrators > 0 then
		return "Infiltrator", "No crew made it to extraction."
	end
	return "None", "No crew made it to extraction."
end

return WinConditions
