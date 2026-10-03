--!strict
--[[
	Components
	Reusable interface pieces built on Create + Theme. Every interactive
	component is a Selectable GuiButton so gamepad navigation works, and
	hover/press feedback is a short tween (skipped with reduced effects).
]]

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local Components = {}

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local reducedMotion = false
function Components.SetReducedMotion(value: boolean)
	reducedMotion = value
end

local function tween(instance: Instance, props: { [string]: any })
	if reducedMotion then
		for key, value in props do
			(instance :: any)[key] = value
		end
		return
	end
	TweenService:Create(instance, FAST, props):Play()
end
Components.tween = tween

function Components.corner(radius: number?): UICorner
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius) })
end

function Components.stroke(color: Color3?, transparency: number?, thickness: number?): UIStroke
	return Create("UIStroke", {
		Color = color or Theme.Color.Stroke,
		Transparency = transparency or 0.3,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Components.padding(all: number?, horizontal: number?): UIPadding
	local p = all or Theme.Padding
	local h = horizontal or p
	return Create("UIPadding", {
		PaddingTop = UDim.new(0, p),
		PaddingBottom = UDim.new(0, p),
		PaddingLeft = UDim.new(0, h),
		PaddingRight = UDim.new(0, h),
	})
end

function Components.list(padding: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	return Create("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
	})
end

-- A dark rounded panel. `props` are applied to the Frame.
function Components.panel(props: { [string]: any }?, children: { Instance }?): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}
	for key, value in props or ({} :: { [string]: any }) do
		merged[key] = value
	end
	local frame = Create("Frame", merged, children)
	Components.corner().Parent = frame
	Components.stroke().Parent = frame
	-- Subtle top-lit gradient for depth.
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 180, 200)),
		Rotation = 90,
		Parent = frame,
	})
	return frame
end

-- Accent corner brackets (top-left and bottom-right), a HUD-style frame.
function Components.brackets(frame: GuiObject, color: Color3?)
	local tint = color or Theme.Color.Accent
	local specs: { { Anchor: Vector2, Position: UDim2 } } = {
		{ Anchor = Vector2.new(0, 0), Position = UDim2.fromOffset(-2, -2) },
		{ Anchor = Vector2.new(1, 1), Position = UDim2.new(1, 2, 1, 2) },
	}
	for _, spec in specs do
		local anchor = spec.Anchor
		local position = spec.Position
		Create("Frame", {
			Name = "BracketH",
			AnchorPoint = anchor,
			Position = position,
			Size = UDim2.fromOffset(22, 3),
			BackgroundColor3 = tint,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = frame,
		})
		Create("Frame", {
			Name = "BracketV",
			AnchorPoint = anchor,
			Position = position,
			Size = UDim2.fromOffset(3, 22),
			BackgroundColor3 = tint,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = frame,
		})
	end
end

function Components.label(text: string, props: { [string]: any }?): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		Text = text,
		Font = Theme.Font.Regular,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Color.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		RichText = false,
	}
	for key, value in props or ({} :: { [string]: any }) do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

export type ButtonStyle = "Primary" | "Secondary" | "Danger" | "Ghost" | "Success"

local STYLE_COLORS: { [string]: { Background: Color3, Text: Color3, Stroke: Color3 } } = {
	Primary = { Background = Color3.fromRGB(28, 92, 120), Text = Theme.Color.Text, Stroke = Theme.Color.Accent },
	Secondary = { Background = Theme.Color.PanelLight, Text = Theme.Color.Text, Stroke = Theme.Color.Stroke },
	Danger = { Background = Color3.fromRGB(110, 30, 40), Text = Theme.Color.Text, Stroke = Theme.Color.Danger },
	Success = { Background = Color3.fromRGB(28, 95, 60), Text = Theme.Color.Text, Stroke = Theme.Color.Success },
	Ghost = { Background = Theme.Color.Panel, Text = Theme.Color.Muted, Stroke = Theme.Color.Stroke },
}

-- Text button with hover/press feedback. Returns the TextButton.
function Components.button(text: string, onClick: () -> (), style: ButtonStyle?, props: { [string]: any }?): TextButton
	local colors = STYLE_COLORS[style or "Secondary"]
	local merged: { [string]: any } = {
		Text = text,
		Font = Theme.Font.Medium,
		TextSize = Theme.TextSize.Body,
		TextColor3 = colors.Text,
		BackgroundColor3 = colors.Background,
		AutoButtonColor = false,
		Selectable = true,
		Size = UDim2.new(1, 0, 0, 40),
		BorderSizePixel = 0,
		TextWrapped = true,
	}
	for key, value in props or ({} :: { [string]: any }) do
		merged[key] = value
	end
	local button = Create("TextButton", merged)
	Components.corner().Parent = button
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 198, 215)),
		Rotation = 90,
		Parent = button,
	})
	if style == "Primary" or style == "Danger" or style == "Success" then
		Create("Frame", {
			Name = "AccentBar",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -10, 0.5, 0),
			Size = UDim2.new(0, 3, 0.6, 0),
			BackgroundColor3 = colors.Stroke,
			BorderSizePixel = 0,
			Parent = button,
		})
	end
	local stroke = Components.stroke(colors.Stroke, 0.45)
	stroke.Parent = button
	Components.padding(4, 10).Parent = button

	local base = colors.Background
	button.MouseEnter:Connect(function()
		tween(button, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.12) })
	end)
	button.MouseLeave:Connect(function()
		tween(button, { BackgroundColor3 = base })
	end)
	button.SelectionGained:Connect(function()
		stroke.Transparency = 0
		stroke.Thickness = 2
	end)
	button.SelectionLost:Connect(function()
		stroke.Transparency = 0.45
		stroke.Thickness = 1
	end)
	button.Activated:Connect(function()
		if button.Active then
			onClick()
		end
	end)
	return button
end

-- Enables/disables a button with a dimmed look.
function Components.setEnabled(button: GuiButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = false
	button.BackgroundTransparency = if enabled then 0 else 0.5
	if button:IsA("TextButton") then
		button.TextTransparency = if enabled then 0 else 0.5
	end
end

export type Progress = { Frame: Frame, Set: (alpha: number, text: string?, color: Color3?) -> () }

function Components.progress(height: number?, color: Color3?): Progress
	local frame = Create("Frame", {
		BackgroundColor3 = Theme.Color.PanelLight,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height or 14),
	})
	Components.corner(4).Parent = frame
	local fill = Create("Frame", {
		BackgroundColor3 = color or Theme.Color.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = frame,
	})
	Components.corner(4).Parent = fill
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 160, 180)),
		Rotation = 90,
		Parent = fill,
	})
	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font.Bold,
		TextSize = math.max(10, (height or 14) - 3),
		TextColor3 = Theme.Color.Text,
		TextStrokeTransparency = 0.5,
		Text = "",
		ZIndex = 2,
		Parent = frame,
	})
	return {
		Frame = frame,
		Set = function(alpha: number, text: string?, fillColor: Color3?)
			tween(fill, { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) })
			if fillColor then
				fill.BackgroundColor3 = fillColor
			end
			label.Text = text or ""
		end,
	}
end

function Components.scroll(props: { [string]: any }?): ScrollingFrame
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.AccentDim,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Selectable = false,
	}
	for key, value in props or ({} :: { [string]: any }) do
		merged[key] = value
	end
	local frame = Create("ScrollingFrame", merged)
	Components.list(6).Parent = frame
	return frame
end

function Components.header(title: string, subtitle: string?): Frame
	local frame = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Components.list(2).Parent = frame
	Components.label(string.upper(title), {
		Font = Theme.Font.Display,
		TextSize = Theme.TextSize.Title - 2,
		TextColor3 = Theme.Color.Accent,
		LayoutOrder = 1,
		Parent = frame,
	})
	if subtitle then
		Components.label(subtitle, { TextColor3 = Theme.Color.Muted, LayoutOrder = 2, Parent = frame })
	end
	return frame
end

-- A row with a label on the left and an arbitrary control on the right.
function Components.row(labelText: string, control: GuiObject, height: number?): Frame
	local row = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 40),
	})
	Components.label(labelText, {
		Size = UDim2.new(0.5, -8, 1, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = row,
	})
	control.AnchorPoint = Vector2.new(1, 0.5)
	control.Position = UDim2.new(1, 0, 0.5, 0)
	control.Size = UDim2.new(0.5, 0, 0, (height or 40) - 6)
	control.Parent = row
	return row
end

-- Cycles through `options` on click / gamepad A. Calls onChange(newValue).
function Components.cycle(options: { string }, value: string, onChange: (string) -> (), display: ((string) -> string)?): TextButton
	local index = math.max(1, table.find(options, value) or 1)
	local function text(): string
		local option = options[index]
		return "◀  " .. (if display then display(option) else option) .. "  ▶"
	end
	local button: TextButton
	button = Components.button(text(), function()
		index = index % #options + 1
		button.Text = text()
		onChange(options[index])
	end, "Secondary")
	return button
end

-- Toggle button showing ON/OFF text (not colour-only).
function Components.toggle(value: boolean, onChange: (boolean) -> ()): TextButton
	local state = value
	local button: TextButton
	local function refresh()
		button.Text = if state then "ON" else "OFF"
		button.TextColor3 = if state then Theme.status("Success") else Theme.Color.Muted
	end
	button = Components.button("", function()
		state = not state
		refresh()
		onChange(state)
	end, "Secondary")
	refresh()
	return button
end

-- Horizontal slider. Drag with mouse/touch; D-pad left/right while selected.
function Components.slider(min: number, max: number, step: number, value: number, onChange: (number) -> (), format: ((number) -> string)?): TextButton
	local current = value
	local track = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.PanelLight,
		BorderSizePixel = 0,
		Selectable = true,
	})
	Components.corner(6).Parent = track
	local stroke = Components.stroke(Theme.Color.Stroke, 0.45)
	stroke.Parent = track
	local fill = Create("Frame", {
		BackgroundColor3 = Theme.Color.AccentDim,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	})
	Components.corner(6).Parent = fill
	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font.Medium,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Color.Text,
		ZIndex = 2,
		Parent = track,
	})

	local function set(v: number, notify: boolean)
		v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
		current = v
		fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
		label.Text = if format then format(v) else string.format("%.2f", v)
		if notify then
			onChange(v)
		end
	end
	set(value, false)

	local dragging = false
	local function fromX(x: number)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		set(min + alpha * (max - min), true)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	local changedConn = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	local beganConn = UserInputService.InputBegan:Connect(function(input)
		if GuiService.SelectedObject ~= track then
			return
		end
		if input.KeyCode == Enum.KeyCode.DPadLeft then
			set(current - step, true)
		elseif input.KeyCode == Enum.KeyCode.DPadRight then
			set(current + step, true)
		end
	end)
	-- Global listeners must not outlive the slider.
	track.Destroying:Connect(function()
		changedConn:Disconnect()
		beganConn:Disconnect()
	end)
	track.SelectionGained:Connect(function()
		stroke.Transparency = 0
		stroke.Thickness = 2
	end)
	track.SelectionLost:Connect(function()
		stroke.Transparency = 0.45
		stroke.Thickness = 1
	end)
	return track
end

-- Small rounded chip (status tags). Text carries the meaning; colour is a hint.
function Components.chip(text: string, color: Color3?): TextLabel
	local chip = Create("TextLabel", {
		BackgroundColor3 = Theme.Color.PanelLight,
		BackgroundTransparency = 0.1,
		Text = text,
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = color or Theme.Color.Text,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 22),
	})
	Components.corner(11).Parent = chip
	Components.padding(3, 9).Parent = chip
	return chip
end

-- Standard centred modal: dimmed backdrop, panel, title, close button.
-- Returns (backdrop, body). `onClose` runs on the close button / B.
function Components.modal(title: string, subtitle: string?, onClose: () -> (), size: Vector2?): (Frame, Frame)
	local backdrop = Create("Frame", {
		Name = "Modal_" .. title,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
	})
	local dims = size or Vector2.new(760, 560)
	local panel = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(dims.X, dims.Y),
		Parent = backdrop,
	})
	Components.padding(16).Parent = panel
	Components.brackets(panel)
	local header = Components.header(title, subtitle)
	header.Size = UDim2.new(1, -60, 0, 0)
	header.Parent = panel
	Components.button("✕", onClose, "Ghost", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 40),
		Parent = panel,
	})
	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, if subtitle then 64 else 44),
		Size = UDim2.new(1, 0, 1, if subtitle then -64 else -44),
		Parent = panel,
	})
	return backdrop, body
end

-- Focus the first selectable descendant for gamepad users.
function Components.focus(root: GuiObject)
	if not UserInputService.GamepadEnabled then
		return
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") and descendant.Selectable and descendant.Visible then
			GuiService.SelectedObject = descendant
			return
		end
	end
end

function Components.clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Components
