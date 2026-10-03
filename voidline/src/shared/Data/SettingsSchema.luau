--!strict
--[[
	SettingsSchema
	Player settings: defaults plus the validation the server applies before
	saving. The client applies settings locally; the server only stores them.
]]

local TableUtil = require(script.Parent.Parent.Utility.TableUtil)

export type Rule =
	{ Type: "number", Min: number, Max: number, Step: number?, Label: string, Group: string }
	| { Type: "boolean", Label: string, Group: string }
	| { Type: "enum", Options: { string }, Label: string, Group: string }

local DEFAULTS = {
	MasterVolume = 0.8,
	MusicVolume = 0.5,
	EffectsVolume = 0.8,
	UIScale = 1,
	EffectsQuality = "High",
	ReducedEffects = false,
	ReducedFlashing = false,
	ColorblindMode = false,
	Subtitles = true,
	FieldOfView = 70,
	CameraShake = true,
	Sensitivity = 1,
	ToggleSprint = false,
}

-- Ordered for display.
local ORDER = {
	"MasterVolume",
	"MusicVolume",
	"EffectsVolume",
	"UIScale",
	"EffectsQuality",
	"ReducedEffects",
	"FieldOfView",
	"CameraShake",
	"Sensitivity",
	"ToggleSprint",
	"ColorblindMode",
	"ReducedFlashing",
	"Subtitles",
}

local RULES: { [string]: Rule } = {
	MasterVolume = { Type = "number", Min = 0, Max = 1, Step = 0.05, Label = "Master volume", Group = "Audio" },
	MusicVolume = { Type = "number", Min = 0, Max = 1, Step = 0.05, Label = "Music volume", Group = "Audio" },
	EffectsVolume = { Type = "number", Min = 0, Max = 1, Step = 0.05, Label = "Effects volume", Group = "Audio" },
	UIScale = { Type = "number", Min = 0.7, Max = 1.4, Step = 0.05, Label = "UI scale", Group = "Display" },
	EffectsQuality = { Type = "enum", Options = { "Low", "Medium", "High" }, Label = "Effects quality", Group = "Display" },
	ReducedEffects = { Type = "boolean", Label = "Reduced effects", Group = "Display" },
	FieldOfView = { Type = "number", Min = 60, Max = 90, Step = 1, Label = "Field of view", Group = "Camera" },
	CameraShake = { Type = "boolean", Label = "Camera shake", Group = "Camera" },
	Sensitivity = { Type = "number", Min = 0.2, Max = 2, Step = 0.05, Label = "Sensitivity", Group = "Camera" },
	ToggleSprint = { Type = "boolean", Label = "Toggle sprint", Group = "Controls" },
	ColorblindMode = { Type = "boolean", Label = "Colorblind palette", Group = "Accessibility" },
	ReducedFlashing = { Type = "boolean", Label = "Reduce flashing", Group = "Accessibility" },
	Subtitles = { Type = "boolean", Label = "Subtitles & sound captions", Group = "Accessibility" },
}

local SettingsSchema = {}

SettingsSchema.Defaults = DEFAULTS
SettingsSchema.Order = ORDER
SettingsSchema.Rules = RULES

-- Returns the sanitized value, or nil if `value` is not acceptable for `key`.
function SettingsSchema.sanitize(key: string, value: any): any
	local rule = RULES[key]
	if not rule then
		return nil
	end
	if rule.Type == "number" then
		if type(value) ~= "number" or value ~= value then
			return nil
		end
		local clamped = math.clamp(value, rule.Min, rule.Max)
		if rule.Step then
			clamped = math.floor(clamped / rule.Step + 0.5) * rule.Step
			clamped = math.clamp(clamped, rule.Min, rule.Max)
		end
		return clamped
	elseif rule.Type == "boolean" then
		return if type(value) == "boolean" then value else nil
	elseif rule.Type == "enum" then
		return if table.find(rule.Options, value) then value else nil
	end
	return nil
end

return TableUtil.deepFreeze(SettingsSchema)
