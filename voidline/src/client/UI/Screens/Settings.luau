--!strict
--[[
	Settings
	Every option from SettingsSchema, grouped (Audio, Display, Camera,
	Controls, Accessibility). Changes apply instantly and save automatically.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SettingsSchema = require(Shared.Data.SettingsSchema)

local Components = require(script.Parent.Parent.Components)

local GROUP_ORDER = { "Audio", "Display", "Camera", "Controls", "Accessibility" }

return function(ctx: any)
	local root, body = Components.modal("Settings", "Changes save automatically.", ctx.Close)
	local list = Components.scroll({ Parent = body })

	local function build()
		Components.clear(list)
		local order = 0
		for _, group in GROUP_ORDER do
			order += 1
			Components.label(string.upper(group), {
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.fromRGB(86, 214, 255),
				LayoutOrder = order,
				Parent = list,
			})
			for _, key in SettingsSchema.Order do
				local rule = SettingsSchema.Rules[key]
				if rule.Group == group then
					order += 1
					local value = ctx.Settings.Get(key)
					local control
					if rule.Type == "number" then
						local isPercent = rule.Max <= 1.5 and rule.Min >= 0 and key ~= "UIScale" and key ~= "Sensitivity"
						control = Components.slider(rule.Min, rule.Max, rule.Step or 0.05, value, function(v)
							ctx.Settings.Set(key, v)
						end, function(v)
							if isPercent then
								return string.format("%d%%", math.floor(v * 100 + 0.5))
							elseif key == "FieldOfView" then
								return string.format("%d°", v)
							end
							return string.format("%.2fx", v)
						end)
					elseif rule.Type == "boolean" then
						control = Components.toggle(value == true, function(v)
							ctx.Settings.Set(key, v)
						end)
					else
						control = Components.cycle(rule.Options, value, function(v)
							ctx.Settings.Set(key, v)
						end)
					end
					local row = Components.row(rule.Label, control)
					row.Size = UDim2.new(1, -10, 0, 40)
					row.LayoutOrder = order
					row.Parent = list
				end
			end
		end
	end

	return {
		Root = root,
		-- Rebuilt on open so controls reflect the latest saved values.
		OnShow = build,
	}
end
