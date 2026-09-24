-- UI construction helpers and theme.
local TweenService = game:GetService("TweenService")

local Util = {}

Util.Theme = {
	bg = Color3.fromRGB(14, 16, 24),
	panel = Color3.fromRGB(24, 27, 38),
	panel2 = Color3.fromRGB(34, 38, 52),
	accent = Color3.fromRGB(255, 120, 30),
	accent2 = Color3.fromRGB(0, 200, 255),
	text = Color3.fromRGB(245, 245, 250),
	sub = Color3.fromRGB(160, 165, 185),
	good = Color3.fromRGB(60, 210, 110),
	bad = Color3.fromRGB(235, 70, 70),
	gold = Color3.fromRGB(255, 200, 50),
	robux = Color3.fromRGB(0, 176, 111),
	locked = Color3.fromRGB(70, 72, 85),
}
local T = Util.Theme

function Util.new(className, props, children)
	local inst = Instance.new(className)
	local parent
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Util.corner(inst, radius)
	Util.new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = inst })
	return inst
end

function Util.stroke(inst, color, thickness, transparency)
	return Util.new("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

function Util.padding(inst, px)
	Util.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = inst,
	})
end

function Util.label(parent, text, props)
	local label = Util.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = T.text,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	for key, value in props or {} do
		label[key] = value
	end
	return label
end

function Util.frame(parent, props)
	local frame = Util.new("Frame", {
		BackgroundColor3 = T.panel,
		BorderSizePixel = 0,
		Parent = parent,
	})
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

function Util.button(parent, text, color, props, onClick)
	local button = Util.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color or T.accent,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Parent = parent,
	})
	for key, value in props or {} do
		button[key] = value
	end
	Util.corner(button, 8)
	Util.new("UITextSizeConstraint", { MaxTextSize = 22, Parent = button })
	Util.padding(button, 6)
	local scale = Util.new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		scale.Scale = 1.05
	end)
	button.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function Util.tween(inst, time, props, style)
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- Modal panel with a title bar and close button.
function Util.panel(parent, title, size, onClose)
	local frame = Util.frame(parent, {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 5,
	})
	Util.corner(frame, 14)
	Util.stroke(frame, T.accent, 2, 0.3)
	Util.new("UISizeConstraint", { MaxSize = Vector2.new(size.X.Offset, size.Y.Offset), Parent = frame })
	frame.Size = UDim2.new(0.94, 0, 0.84, 0)

	local header = Util.frame(frame, {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = T.panel,
	})
	Util.corner(header, 14)
	Util.label(header, title, {
		Font = Enum.Font.GothamBlack,
		Size = UDim2.new(1, -120, 0, 30),
		Position = UDim2.new(0, 18, 0, 9),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = Util.button(header, "X", T.bad, {
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(1, -44, 0, 6),
	}, onClose)
	close.Name = "Close"

	local content = Util.frame(frame, {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 58),
		Size = UDim2.new(1, -28, 1, -72),
	})
	return frame, content
end

function Util.bar(parent, props)
	local back = Util.frame(parent, { BackgroundColor3 = T.panel2 })
	for key, value in props or {} do
		back[key] = value
	end
	Util.corner(back, 6)
	local fill = Util.frame(back, { Name = "Fill", BackgroundColor3 = T.accent, Size = UDim2.fromScale(0, 1) })
	Util.corner(fill, 6)
	return back, fill
end

function Util.formatNumber(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

function Util.formatTime(seconds)
	if not seconds then
		return "--:--.--"
	end
	local m = math.floor(seconds / 60)
	local s = seconds - m * 60
	return string.format("%d:%05.2f", m, s)
end

function Util.ordinal(n)
	local suffix = "th"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "st", "nd", "rd" })[n % 10] or "th"
	end
	return n .. suffix
end

return Util
