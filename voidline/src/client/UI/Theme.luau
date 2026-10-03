--!strict
--[[
	Theme
	Colours, fonts and sizes for VOIDLINE's interface: a dark, clean sci-fi
	look with a single cyan accent and restrained motion.

	Status colours always come with a text label or symbol so meaning never
	depends on colour alone. Colourblind mode swaps to an Okabe-Ito based set.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AccentPalette = require(Shared.Data.AccentPalette)

local Theme = {}

Theme.Color = {
	Background = Color3.fromRGB(8, 11, 17),
	Panel = Color3.fromRGB(14, 19, 28),
	PanelLight = Color3.fromRGB(22, 30, 44),
	PanelHover = Color3.fromRGB(30, 41, 60),
	Stroke = Color3.fromRGB(60, 80, 105),
	Accent = Color3.fromRGB(86, 214, 255),
	AccentDim = Color3.fromRGB(40, 110, 140),
	Text = Color3.fromRGB(226, 234, 245),
	Muted = Color3.fromRGB(140, 154, 176),
	Faint = Color3.fromRGB(90, 102, 122),
	Crew = Color3.fromRGB(90, 170, 255),
	Infiltrator = Color3.fromRGB(240, 70, 100),
	Success = Color3.fromRGB(110, 230, 150),
	Warning = Color3.fromRGB(255, 196, 92),
	Danger = Color3.fromRGB(255, 92, 92),
	Ghost = Color3.fromRGB(170, 160, 255),
}

-- Colourblind-friendly replacements for status colours.
Theme.ColorblindColor = {
	Crew = Color3.fromRGB(86, 180, 233),
	Infiltrator = Color3.fromRGB(213, 94, 0),
	Success = Color3.fromRGB(0, 158, 115),
	Warning = Color3.fromRGB(240, 228, 66),
	Danger = Color3.fromRGB(213, 94, 0),
}

Theme.Font = {
	Display = Enum.Font.Michroma, -- wide sci-fi face for titles only
	Regular = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Mono = Enum.Font.RobotoMono,
}

Theme.TextSize = {
	Small = 13,
	Body = 15,
	Large = 18,
	Title = 26,
	Hero = 54,
}

Theme.Radius = 8
Theme.Padding = 12

local colorblind = false

function Theme.SetColorblind(value: boolean)
	colorblind = value
end

-- Status colour respecting colourblind mode ("Success", "Danger", "Crew", ...).
function Theme.status(name: string): Color3
	if colorblind then
		local alt = (Theme.ColorblindColor :: any)[name]
		if alt then
			return alt
		end
	end
	return (Theme.Color :: any)[name] or Theme.Color.Text
end

function Theme.accentColor(index: number?): Color3
	local accent = if index then AccentPalette.get(index) else nil
	if not accent then
		return Theme.Color.Muted
	end
	local rgb = if colorblind then accent.ColorblindColor else accent.Color
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function Theme.factionColor(faction: string?): Color3
	if faction == "Infiltrator" then
		return Theme.status("Infiltrator")
	elseif faction == "Crew" then
		return Theme.status("Crew")
	end
	return Theme.Color.Muted
end

return Theme
