--!strict
--[[
	Minigames (UI)
	Interactive panels for each server-issued challenge. Each builder takes
	the challenge and two callbacks, and returns a destroy function.
	All four kinds work with mouse, touch and gamepad (D-pad + A).

	  Sliders  - drag three sliders onto their target marks
	  Sequence - type the displayed code on a keypad
	  Timing   - lock a sweeping needle inside the highlighted zones
	  Wires    - connect each left relay to the matching colour on the right
]]

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Components = require(script.Parent.Components)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local Minigames = {}

export type Callbacks = { Submit: (answer: any) -> (), Cancel: () -> () }

-- Wire colours always paired with a letter, so colourblind players can match them.
local WIRE_COLORS = {
	{ Color = Color3.fromRGB(255, 92, 92), Label = "A" },
	{ Color = Color3.fromRGB(90, 170, 255), Label = "B" },
	{ Color = Color3.fromRGB(255, 196, 92), Label = "C" },
	{ Color = Color3.fromRGB(110, 230, 150), Label = "D" },
	{ Color = Color3.fromRGB(190, 140, 255), Label = "E" },
	{ Color = Color3.fromRGB(240, 240, 240), Label = "F" },
}

local function frame(parent: Instance, title: string, timeLimit: number, callbacks: Callbacks): (Frame, Frame, () -> ())
	local root = Components.panel({
		Name = "Minigame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 360),
		Parent = parent,
	})
	Components.padding(16).Parent = root
	Components.label(string.upper(title), {
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Large,
		TextColor3 = Theme.Color.Accent,
		Size = UDim2.new(1, -110, 0, 24),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = root,
	})
	local timer = Components.label("", {
		Font = Theme.Font.Mono,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -100, 0, 0),
		Size = UDim2.fromOffset(100, 24),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Theme.Color.Muted,
		Parent = root,
	})
	local body = Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -84),
		Parent = root,
	})
	Components.button("Cancel (B)", callbacks.Cancel, "Ghost", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(130, 38),
		Parent = root,
	})
	local started = os.clock()
	local conn = RunService.Heartbeat:Connect(function()
		local remaining = math.max(0, timeLimit - (os.clock() - started))
		timer.Text = string.format("%04.1fs", remaining)
		timer.TextColor3 = if remaining < 5 then Theme.status("Danger") else Theme.Color.Muted
	end)
	local function cleanup()
		conn:Disconnect()
		root:Destroy()
	end
	return root, body, cleanup
end

---------------------------------------------------------------------------
-- Sliders
---------------------------------------------------------------------------
function Minigames.Sliders(parent: Instance, challenge: any, info: any, callbacks: Callbacks): () -> ()
	local root, body, cleanup = frame(parent, info.Title or "Align", info.TimeLimit or 25, callbacks)
	Components.label("Drag each slider onto its marker, then press Confirm.", {
		TextColor3 = Theme.Color.Muted,
		TextSize = Theme.TextSize.Small,
		Parent = body,
	})
	local values = {}
	local tolerance = challenge.Tolerance or 6
	local count = #challenge.Targets
	for i, target in challenge.Targets do
		values[i] = (target + 45) % 100 -- start away from the target
		local y = 30 + (i - 1) * 56
		local track = Create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Selectable = true,
			BackgroundColor3 = Theme.Color.PanelLight,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 34),
			Parent = body,
		})
		Components.corner(6).Parent = track
		local stroke = Components.stroke()
		stroke.Parent = track
		Create("Frame", { -- target marker
			BackgroundColor3 = Theme.status("Success"),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(target / 100, 0),
			Size = UDim2.new(0, 4, 1, 0),
			Parent = track,
		})
		Create("Frame", { -- tolerance window
			BackgroundColor3 = Theme.status("Success"),
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(target / 100, 0),
			Size = UDim2.new(tolerance * 2 / 100, 0, 1, 0),
			Parent = track,
		})
		local knob = Create("Frame", {
			BackgroundColor3 = Theme.Color.Accent,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(values[i] / 100, 0.5),
			Size = UDim2.fromOffset(18, 30),
			Parent = track,
		})
		Components.corner(4).Parent = knob
		local function set(v: number)
			values[i] = math.clamp(v, 0, 100)
			knob.Position = UDim2.fromScale(values[i] / 100, 0.5)
		end
		local dragging = false
		track.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				set((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X * 100)
			end
		end)
		track.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		local moveConn = UserInputService.InputChanged:Connect(function(input: InputObject)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				set((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X * 100)
			end
		end)
		local padConn = UserInputService.InputBegan:Connect(function(input: InputObject)
			if GuiService.SelectedObject == track then
				if input.KeyCode == Enum.KeyCode.DPadLeft then
					set(values[i] - 2)
				elseif input.KeyCode == Enum.KeyCode.DPadRight then
					set(values[i] + 2)
				end
			end
		end)
		track.Destroying:Connect(function()
			moveConn:Disconnect()
			padConn:Disconnect()
		end)
		track.SelectionGained:Connect(function()
			stroke.Color = Theme.Color.Accent
		end)
		track.SelectionLost:Connect(function()
			stroke.Color = Theme.Color.Stroke
		end)
	end
	Components.button("Confirm", function()
		local answer = {}
		for i = 1, count do
			answer[i] = math.floor(values[i] + 0.5)
		end
		callbacks.Submit(answer)
	end, "Primary", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(150, 38),
		Parent = root,
	})
	Components.focus(root)
	return cleanup
end

---------------------------------------------------------------------------
-- Sequence
---------------------------------------------------------------------------
function Minigames.Sequence(parent: Instance, challenge: any, info: any, callbacks: Callbacks): () -> ()
	local root, body, cleanup = frame(parent, info.Title or "Enter code", info.TimeLimit or 25, callbacks)
	local code: string = challenge.Code
	local entered = ""
	local spaced = string.gsub(code, "(%d)", "%1 ")
	Components.label("Transmit: " .. spaced, {
		Font = Theme.Font.Mono,
		TextSize = 22,
		TextColor3 = Theme.Color.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = body,
	})
	local display = Components.label("_ _ _ _ _", {
		Font = Theme.Font.Mono,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 32),
		Parent = body,
	})
	local function refresh()
		local chars = {}
		for i = 1, #code do
			chars[i] = if i <= #entered then string.sub(entered, i, i) else "_"
		end
		display.Text = table.concat(chars, " ")
	end
	local pad = Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(110, 66),
		Size = UDim2.fromOffset(220, 170),
		Parent = body,
	})
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(68, 38),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = pad,
	})
	local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK" }
	for order, key in keys do
		Components.button(key, function()
			if key == "⌫" then
				entered = string.sub(entered, 1, -2)
			elseif key == "OK" then
				callbacks.Submit(entered)
				return
			elseif #entered < #code then
				entered ..= key
			end
			refresh()
			if #entered == #code then
				callbacks.Submit(entered)
			end
		end, if key == "OK" then "Primary" else "Secondary", { LayoutOrder = order, Size = UDim2.fromOffset(68, 38), Parent = pad })
	end
	-- Keyboard digits work too.
	local conn = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local name = input.KeyCode.Name
		local digit = string.match(name, "^(%d)$") or string.match(name, "^Keypad(%d)$")
		local words: { [string]: string } = { Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9" }
		digit = digit or words[name]
		if digit and #entered < #code then
			entered ..= digit
			refresh()
			if #entered == #code then
				callbacks.Submit(entered)
			end
		elseif input.KeyCode == Enum.KeyCode.Backspace then
			entered = string.sub(entered, 1, -2)
			refresh()
		end
	end)
	root.Destroying:Connect(function()
		conn:Disconnect()
	end)
	refresh()
	Components.focus(pad)
	return cleanup
end

---------------------------------------------------------------------------
-- Timing
---------------------------------------------------------------------------
function Minigames.Timing(parent: Instance, challenge: any, info: any, callbacks: Callbacks): () -> ()
	local root, body, cleanup = frame(parent, info.Title or "Calibrate", info.TimeLimit or 25, callbacks)
	local required = challenge.Required or 3
	local maxMisses = challenge.MaxMisses or 2
	local hits, misses = 0, 0
	local zoneIndex = 1
	local status = Components.label("", { TextXAlignment = Enum.TextXAlignment.Center, Parent = body })
	local track = Create("Frame", {
		BackgroundColor3 = Theme.Color.PanelLight,
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = body,
	})
	Components.corner(6).Parent = track
	local zoneFrame = Create("Frame", {
		BackgroundColor3 = Theme.status("Success"),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	})
	local needle = Create("Frame", {
		BackgroundColor3 = Theme.Color.Text,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0, 4, 1, 0),
		Parent = track,
	})
	local function showZone()
		local zone = challenge.Zones[((zoneIndex - 1) % #challenge.Zones) + 1]
		zoneFrame.Position = UDim2.fromScale(zone.Start, 0)
		zoneFrame.Size = UDim2.fromScale(zone.Width, 1)
		status.Text = string.format("Locks %d / %d     Misses %d / %d", hits, required, misses, maxMisses)
	end
	showZone()
	local period = challenge.Period or 1.6
	local started = os.clock()
	local position = 0
	local conn = RunService.RenderStepped:Connect(function()
		local t = ((os.clock() - started) % period) / period
		position = if t < 0.5 then t * 2 else (1 - t) * 2
		needle.Position = UDim2.fromScale(position, 0)
	end)
	local function lock()
		local zone = challenge.Zones[((zoneIndex - 1) % #challenge.Zones) + 1]
		if position >= zone.Start and position <= zone.Start + zone.Width then
			hits += 1
			zoneIndex += 1
		else
			misses += 1
		end
		showZone()
		if hits >= required or misses > maxMisses then
			callbacks.Submit({ Hits = hits, Misses = misses })
		end
	end
	Components.button("LOCK (Space / A)", lock, "Primary", {
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 54),
		Parent = body,
	})
	local keyConn = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and (input.KeyCode == Enum.KeyCode.Space) then
			lock()
		end
	end)
	root.Destroying:Connect(function()
		conn:Disconnect()
		keyConn:Disconnect()
	end)
	Components.focus(body)
	return cleanup
end

---------------------------------------------------------------------------
-- Wires
---------------------------------------------------------------------------
function Minigames.Wires(parent: Instance, challenge: any, info: any, callbacks: Callbacks): () -> ()
	local _root, body, cleanup = frame(parent, info.Title or "Reconnect", info.TimeLimit or 25, callbacks)
	Components.label("Select a left relay, then the matching relay on the right.", {
		TextColor3 = Theme.Color.Muted,
		TextSize = Theme.TextSize.Small,
		Parent = body,
	})
	local left: { number } = challenge.Left
	local right: { number } = challenge.Right
	local mapping: { [number]: number } = {}
	local selectedLeft: number? = nil
	local leftButtons: { TextButton } = {}
	local rightButtons: { TextButton } = {}

	local function refresh()
		for i, button in leftButtons do
			local wire = WIRE_COLORS[left[i]]
			button.Text = wire.Label .. (if mapping[i] then "  ✓" else "")
			button.BackgroundColor3 = if selectedLeft == i then Theme.Color.PanelHover else Theme.Color.PanelLight
		end
		local used: { [number]: boolean } = {}
		for _, r in mapping do
			used[r] = true
		end
		for j, button in rightButtons do
			button.Text = WIRE_COLORS[right[j]].Label .. (if used[j] then "  ✓" else "")
		end
	end

	for i, colour in left do
		local wire = WIRE_COLORS[colour]
		local button = Components.button(wire.Label, function()
			selectedLeft = i
			refresh()
		end, "Secondary", {
			Position = UDim2.fromOffset(0, 30 + (i - 1) * 46),
			Size = UDim2.fromOffset(150, 38),
			TextColor3 = wire.Color,
			Font = Theme.Font.Bold,
			Parent = body,
		})
		leftButtons[i] = button
	end
	for j, colour in right do
		local wire = WIRE_COLORS[colour]
		local button = Components.button(wire.Label, function()
			if selectedLeft then
				for k, r in mapping do
					if r == j then
						mapping[k] = nil
					end
				end
				mapping[selectedLeft] = j
				selectedLeft = nil
				refresh()
				local complete = true
				for k = 1, #left do
					if not mapping[k] then
						complete = false
					end
				end
				if complete then
					local answer = {}
					for k = 1, #left do
						answer[k] = mapping[k]
					end
					callbacks.Submit(answer)
				end
			end
		end, "Secondary", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 30 + (j - 1) * 46),
			Size = UDim2.fromOffset(150, 38),
			TextColor3 = wire.Color,
			Font = Theme.Font.Bold,
			Parent = body,
		})
		rightButtons[j] = button
	end
	refresh()
	Components.focus(body)
	return cleanup
end

return Minigames
