--!strict
--[[
	Credits
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Components = require(script.Parent.Parent.Components)

return function(ctx: any)
	local root, body = Components.modal("Credits", nil, ctx.Close, Vector2.new(620, 460))
	local list = Components.scroll({ Parent = body })
	local lines: { { Text: string, Heading: boolean } } = {
		{ Text = Config.Game.Title, Heading = true },
		{ Text = "An original social-deduction survival game set aboard the research vessel " .. Config.Game.ShipName .. ".", Heading = false },
		{ Text = "Design & code", Heading = true },
		{ Text = "The VOIDLINE development team.", Heading = false },
		{ Text = "Audio", Heading = true },
		{ Text = "Original or properly licensed audio only. See AudioCatalog for sources.", Heading = false },
		{ Text = "Built with", Heading = true },
		{ Text = "Roblox, Luau and Rojo.", Heading = false },
		{ Text = "Thanks", Heading = true },
		{ Text = "To every crew member who trusted the wrong person.", Heading = false },
	}
	for index, line in lines do
		Components.label(line.Text, {
			Font = if line.Heading then Enum.Font.GothamBold else Enum.Font.Gotham,
			TextColor3 = if line.Heading then Color3.fromRGB(86, 214, 255) else Color3.fromRGB(226, 234, 245),
			LayoutOrder = index,
			Parent = list,
		})
	end
	return { Root = root }
end
