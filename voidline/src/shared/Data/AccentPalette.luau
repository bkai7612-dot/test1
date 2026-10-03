--!strict
--[[
	AccentPalette
	Each round every participant is given a suit accent (armband + nameplate
	marker). Accents are a deduction clue: witnesses and stasis residue reveal
	the attacker's accent. There are fewer accents than players, so an accent
	narrows suspects down without naming anyone.

	Every accent has a name and a symbol so it never relies on colour alone,
	plus an alternative colour for colourblind mode (Okabe-Ito based).
	Colours are stored as {R, G, B} so this module stays Roblox-type free.
]]

local TableUtil = require(script.Parent.Parent.Utility.TableUtil)

export type Accent = {
	Name: string,
	Symbol: string,
	Color: { number },
	ColorblindColor: { number },
}

local ACCENTS: { Accent } = {
	{ Name = "Amber", Symbol = "▲", Color = { 255, 176, 46 }, ColorblindColor = { 230, 159, 0 } },
	{ Name = "Teal", Symbol = "●", Color = { 38, 198, 190 }, ColorblindColor = { 86, 180, 233 } },
	{ Name = "Violet", Symbol = "◆", Color = { 156, 104, 255 }, ColorblindColor = { 204, 121, 167 } },
	{ Name = "Lime", Symbol = "■", Color = { 150, 220, 60 }, ColorblindColor = { 240, 228, 66 } },
	{ Name = "Coral", Symbol = "✚", Color = { 255, 110, 110 }, ColorblindColor = { 213, 94, 0 } },
	{ Name = "Ice", Symbol = "★", Color = { 170, 215, 255 }, ColorblindColor = { 0, 114, 178 } },
}

local AccentPalette = {}

AccentPalette.Accents = ACCENTS
AccentPalette.Count = #ACCENTS

function AccentPalette.get(index: number): Accent?
	return ACCENTS[index]
end

-- "▲ Amber"
function AccentPalette.label(index: number): string
	local accent = ACCENTS[index]
	if not accent then
		return "Unknown"
	end
	return accent.Symbol .. " " .. accent.Name
end

return TableUtil.deepFreeze(AccentPalette)
