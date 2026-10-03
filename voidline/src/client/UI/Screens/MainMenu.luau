--!strict
--[[
	MainMenu
	Title screen: Play, Customize, Statistics, Settings, Training, Credits,
	with the player's level and credits.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Format = require(Shared.Utility.Format)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

return function(ctx: any)
	local root = Create("Frame", {
		Name = "MainMenu",
		BackgroundColor3 = Theme.Color.Background,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
	})
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(10, 20, 34), Color3.fromRGB(4, 6, 10)),
		Rotation = 90,
		Parent = root,
	})

	-- Backdrop: drifting starfield and a glowing planet limb.
	local stars = Create("Frame", { Name = "Stars", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	local starList = {}
	for i = 1, 90 do
		local size = if i % 9 == 0 then 3 else (if i % 3 == 0 then 2 else 1)
		local star = Create("Frame", {
			BackgroundColor3 = if i % 7 == 0 then Color3.fromRGB(170, 210, 255) else Color3.new(1, 1, 1),
			BackgroundTransparency = math.random() * 0.6,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromScale(math.random(), math.random()),
			Parent = stars,
		})
		table.insert(starList, { Frame = star, Speed = 0.004 + size * 0.004 })
	end
	local planet = Create("Frame", {
		Name = "Planet",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.86, 1.02),
		Size = UDim2.fromScale(0.75, 0.75),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = Color3.fromRGB(40, 110, 200),
		BorderSizePixel = 0,
		Parent = root,
	})
	Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = planet })
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(120, 200, 255), Color3.fromRGB(8, 20, 40)),
		Rotation = 120,
		Parent = planet,
	})
	Create("UIStroke", { Color = Color3.fromRGB(120, 200, 255), Thickness = 3, Transparency = 0.4, Parent = planet })
	game:GetService("RunService").RenderStepped:Connect(function(dt)
		if not root.Visible then
			return
		end
		for _, star in starList do
			local position = star.Frame.Position
			local x = position.X.Scale - star.Speed * dt
			star.Frame.Position = UDim2.fromScale(if x < 0 then 1 else x, position.Y.Scale)
		end
	end)

	local column = Create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 90, 0.5, 0),
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Components.list(10).Parent = column

	local title = Components.label(Config.Game.Title, {
		Font = Theme.Font.Display,
		TextSize = Theme.TextSize.Hero,
		TextColor3 = Theme.Color.Accent,
		LayoutOrder = 1,
		Parent = column,
	})
	Create("UIStroke", { Color = Color3.fromRGB(40, 140, 200), Thickness = 2, Transparency = 0.35, Parent = title })
	Components.label("Restore the " .. Config.Game.ShipName .. ". Trust carefully.", {
		TextColor3 = Theme.Color.Muted,
		LayoutOrder = 2,
		Parent = column,
	})
	local profileLine = Components.label("", {
		Font = Theme.Font.Medium,
		LayoutOrder = 3,
		Parent = column,
	})
	Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 10), LayoutOrder = 4, Parent = column })

	local tutorialHint = Components.label("New aboard? Training takes about two minutes.", {
		TextColor3 = Theme.status("Warning"),
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 5,
		Visible = false,
		Parent = column,
	})

	local buttons: { { Label: string, Style: Components.ButtonStyle, Action: () -> () } } = {
		{ Label = "Play", Style = "Primary", Action = function()
			ctx.DismissMenu()
		end },
		{ Label = "Training", Style = "Secondary", Action = function()
			ctx.StartTutorial()
		end },
		{ Label = "Customize", Style = "Secondary", Action = function()
			ctx.Open("Customize")
		end },
		{ Label = "Statistics", Style = "Secondary", Action = function()
			ctx.Open("Stats")
		end },
		{ Label = "Settings", Style = "Secondary", Action = function()
			ctx.Open("Settings")
		end },
		{ Label = "Credits", Style = "Ghost", Action = function()
			ctx.Open("Credits")
		end },
	}
	for index, spec in buttons do
		Components.button(spec.Label, spec.Action, spec.Style, {
			LayoutOrder = 10 + index,
			Size = UDim2.new(1, 0, 0, 46),
			TextSize = Theme.TextSize.Large,
			Parent = column,
		})
	end

	Components.label("v" .. Config.Game.Version .. "  ·  An original game", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -12),
		Size = UDim2.fromOffset(400, 20),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Color.Faint,
		TextSize = Theme.TextSize.Small,
		Parent = root,
	})

	return {
		Root = root,
		Refresh = function()
			local profile = ctx.Client.GetPrivate(Constants.PrivateKey.Profile)
			if type(profile) == "table" then
				profileLine.Text = string.format("Level %d  ·  %s credits", profile.Level, Format.thousands(profile.Credits))
				tutorialHint.Visible = profile.TutorialDone ~= true
			else
				profileLine.Text = "Loading profile..."
			end
		end,
	}
end
