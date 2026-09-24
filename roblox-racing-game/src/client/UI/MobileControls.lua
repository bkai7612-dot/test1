-- On-screen driving buttons for touch devices.
local UserInputService = game:GetService("UserInputService")

local Util = require(script.Parent.Util)
local T = Util.Theme

local MobileControls = {}

local root, exitButton

local function holdButton(parent, text, color, props, flagTable, flag)
	local button = Util.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.25,
		Font = Enum.Font.GothamBlack,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Parent = parent,
	})
	for key, value in props do
		button[key] = value
	end
	Util.corner(button, 40)
	Util.padding(button, 12)
	local function set(on)
		flagTable[flag] = on
		button.BackgroundTransparency = on and 0 or 0.25
	end
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			set(true)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			set(false)
		end
	end)
	return button
end

function MobileControls.Init(gui, controller)
	root = Util.frame(gui, {
		Name = "MobileControls",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})
	local touch = controller.Touch
	holdButton(root, "<", T.panel2, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -30),
		Size = UDim2.new(0, 90, 0, 90),
	}, touch, "left")
	holdButton(root, ">", T.panel2, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 124, 1, -30),
		Size = UDim2.new(0, 90, 0, 90),
	}, touch, "right")
	holdButton(root, "GAS", T.good, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -30),
		Size = UDim2.new(0, 96, 0, 96),
	}, touch, "gas")
	holdButton(root, "BRAKE", T.bad, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -128, 1, -30),
		Size = UDim2.new(0, 80, 0, 80),
	}, touch, "brake")
	holdButton(root, "N2O", T.accent2, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -140),
		Size = UDim2.new(0, 70, 0, 70),
	}, touch, "boost")
	holdButton(root, "DRIFT", T.accent, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -108, 1, -126),
		Size = UDim2.new(0, 70, 0, 70),
	}, touch, "drift")
	Util.button(root, "RESET", T.panel2, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -134),
		Size = UDim2.new(0, 90, 0, 40),
	}, function()
		controller.Respawn()
	end)
	exitButton = Util.button(root, "EXIT", T.bad, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 124, 1, -134),
		Size = UDim2.new(0, 90, 0, 40),
	}, function()
		controller.ExitCar()
	end)
end

function MobileControls.SetVisible(visible, mode)
	root.Visible = visible and UserInputService.TouchEnabled
	exitButton.Visible = mode == "test"
end

return MobileControls
