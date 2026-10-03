--!strict
--[[
	Hud
	In-round heads-up display:
	  top-left    objectives (cover story for infiltrators, extraction steps in
	              the endgame) and shared objectives
	  top-centre  ship Stability / Restoration, round timer, active hazards
	  top-right   role, accent, location, carried component, tokens, radio
	  bottom      stamina, infiltrator abilities, alert button
	  world       markers on the consoles for your current steps

	Every status uses text as well as colour. During a Navigation Error the
	crew's room readouts and markers become unreliable (that's the sabotage).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local AccentPalette = require(Shared.Data.AccentPalette)
local Format = require(Shared.Utility.Format)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local localPlayer = Players.LocalPlayer

return function(ctx: any)
	local root = Create("Frame", {
		Name = "Hud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})

	---------------------------------------------------------------------
	-- Objectives
	---------------------------------------------------------------------
	local objectives = Components.panel({
		Name = "Objectives",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Components.padding(10).Parent = objectives
	Components.list(4).Parent = objectives
	local objectivesTitle = Components.label("OBJECTIVES", {
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Accent,
		LayoutOrder = 0,
		Parent = objectives,
	})
	local objectiveBody = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = objectives,
	})
	Components.list(4).Parent = objectiveBody
	local collapsed = false

	---------------------------------------------------------------------
	-- Ship status
	---------------------------------------------------------------------
	local status = Create("Frame", {
		Name = "ShipStatus",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Components.list(5, false, Enum.HorizontalAlignment.Center).Parent = status
	local stabilityBar = Components.progress(18, Theme.status("Warning"))
	stabilityBar.Frame.LayoutOrder = 1
	stabilityBar.Frame.Parent = status
	local restorationBar = Components.progress(18, Theme.status("Success"))
	restorationBar.Frame.LayoutOrder = 2
	restorationBar.Frame.Parent = status
	local timerLabel = Components.label("", {
		LayoutOrder = 3,
		Font = Theme.Font.Mono,
		TextSize = Theme.TextSize.Large,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = status,
	})
	local hazardList = Create("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = status,
	})
	Components.list(4, false, Enum.HorizontalAlignment.Center).Parent = hazardList

	---------------------------------------------------------------------
	-- Personal
	---------------------------------------------------------------------
	local personal = Components.panel({
		Name = "Personal",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(240, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Components.padding(10).Parent = personal
	Components.list(4).Parent = personal
	local roleLabel = Components.label("", { Font = Theme.Font.Bold, TextSize = Theme.TextSize.Large, LayoutOrder = 1, Parent = personal })
	local accentLabel = Components.label("", { Font = Theme.Font.Bold, LayoutOrder = 2, Parent = personal })
	local locationLabel = Components.label("", { LayoutOrder = 3, Parent = personal })
	local carryLabel = Components.label("", { LayoutOrder = 4, TextColor3 = Theme.status("Warning"), Parent = personal })
	local tokenLabel = Components.label("", { LayoutOrder = 5, TextColor3 = Theme.Color.Muted, TextSize = Theme.TextSize.Small, Parent = personal })
	local commsLabel = Components.label("", { LayoutOrder = 6, TextColor3 = Theme.Color.Muted, TextSize = Theme.TextSize.Small, Parent = personal })

	---------------------------------------------------------------------
	-- Bottom: stamina, abilities, alert
	---------------------------------------------------------------------
	local stamina = Components.progress(8, Theme.Color.Accent)
	stamina.Frame.AnchorPoint = Vector2.new(0.5, 1)
	stamina.Frame.Position = UDim2.new(0.5, 0, 1, -18)
	stamina.Frame.Size = UDim2.fromOffset(220, 8)
	stamina.Frame.Parent = root

	local abilities = Components.panel({
		Name = "Abilities",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = root,
	})
	Components.padding(10).Parent = abilities
	Components.list(6).Parent = abilities
	Components.label("MURMUR LINK", { Font = Theme.Font.Bold, TextColor3 = Theme.status("Infiltrator"), LayoutOrder = 1, Parent = abilities })
	local siphonLabel = Components.label("", { LayoutOrder = 2, Parent = abilities })
	local sabotageLabel = Components.label("", { LayoutOrder = 3, Parent = abilities })
	Components.button("Sabotage console (Q)", function()
		ctx.Open("Sabotage")
	end, "Danger", { LayoutOrder = 4, Parent = abilities })

	local alertButton = Components.button("RAISE ALERT (G)", function()
		ctx.Fire(Net.Names.EmergencyAlert)
	end, "Danger", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(220, 40),
		Visible = false,
		Parent = root,
	})

	ctx.Input.StaminaChanged:Connect(function(value: number, sprinting: boolean)
		stamina.Set(value, nil, if value < 0.3 then Theme.status("Warning") else Theme.Color.Accent)
		stamina.Frame.Visible = value < 0.999 or sprinting
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Tab and root.Visible then
			collapsed = not collapsed
			objectiveBody.Visible = not collapsed
		end
	end)

	---------------------------------------------------------------------
	-- World markers
	---------------------------------------------------------------------
	local markerFolder = Instance.new("Folder")
	markerFolder.Name = "VoidlineMarkers"
	markerFolder.Parent = localPlayer:WaitForChild("PlayerGui")
	local markers: { [string]: BillboardGui } = {}

	local function setMarkers(wanted: { [string]: string })
		for anchorId, gui in markers do
			if not wanted[anchorId] then
				gui:Destroy()
				markers[anchorId] = nil
			end
		end
		local scrambled = ctx.Effects.IsNavScrambled()
		for anchorId, text in wanted do
			local adorneeId = anchorId
			if scrambled then
				-- Misleading indicator: point at some other console.
				local hash = 0
				for i = 1, #anchorId do
					hash += string.byte(anchorId, i)
				end
				local stations = {}
				for _, part in game:GetService("CollectionService"):GetTagged(Constants.Tag.Station) do
					table.insert(stations, part:GetAttribute(Constants.Attribute.AnchorId))
				end
				table.sort(stations)
				if #stations > 0 then
					adorneeId = stations[(hash % #stations) + 1]
				end
			end
			local anchor = ctx.Interaction.GetAnchor(adorneeId)
			local gui = markers[anchorId]
			if not gui then
				local created = Instance.new("BillboardGui")
				created.Name = anchorId
				created.AlwaysOnTop = true
				created.Size = UDim2.fromOffset(160, 40)
				created.StudsOffset = Vector3.new(0, 3, 0)
				created.LightInfluence = 0
				created.MaxDistance = 400
				gui = created
				local label = Instance.new("TextLabel")
				label.Name = "Text"
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Font = Theme.Font.Bold
				label.TextScaled = true
				label.TextColor3 = Theme.Color.Accent
				label.TextStrokeTransparency = 0.3
				label.Parent = created
				created.Parent = markerFolder
				markers[anchorId] = created
			end
			local g = gui :: BillboardGui
			g.Adornee = anchor
			g.Enabled = anchor ~= nil
			local label = g:FindFirstChild("Text") :: TextLabel
			label.Text = "◆ " .. text
		end
	end

	---------------------------------------------------------------------
	-- Refresh
	---------------------------------------------------------------------
	local function taskRow(text: string, sub: string, done: boolean, order: number)
		local row = Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = objectiveBody,
		})
		Components.list(0).Parent = row
		Components.label((if done then "✓ " else "▸ ") .. text, {
			Font = Theme.Font.Medium,
			TextColor3 = if done then Theme.Color.Faint else Theme.Color.Text,
			TextSize = Theme.TextSize.Small + 1,
			Parent = row,
		})
		if sub ~= "" and not done then
			Components.label("   " .. sub, { TextColor3 = Theme.Color.Muted, TextSize = Theme.TextSize.Small, Parent = row })
		end
	end

	local function refresh()
		local role = ctx.Client.GetPrivate(Constants.PrivateKey.Role)
		local faction = if type(role) == "table" then role.Faction else nil
		local escape = ctx.Client.GetPublic(Constants.PublicKey.Escape)
		local tasks = ctx.Client.GetPrivate(Constants.PrivateKey.Tasks)
		local shared = ctx.Client.GetPublic(Constants.PublicKey.SharedTasks)
		local wantedMarkers: { [string]: string } = {}

		Components.clear(objectiveBody)
		local order = 0
		if type(escape) == "table" then
			objectivesTitle.Text = "EXTRACTION · " .. string.upper(escape.RouteName or "")
			for index, step in escape.Steps or {} do
				order += 1
				local current = index == escape.StepIndex
				taskRow(step.Label, ctx.Effects.DisplayArea(step.Room), step.Done, order)
				if current then
					wantedMarkers[step.Anchor] = step.Label
				end
			end
			if escape.ExtractionEndsAt then
				order += 1
				taskRow("Reach " .. (escape.ExtractionRoomName or "extraction"), "Be inside when the countdown ends!", false, order)
			end
		else
			objectivesTitle.Text = if faction == Constants.Faction.Infiltrator then "COVER STORY" else "OBJECTIVES"
			if type(tasks) == "table" then
				for _, entry in tasks do
					order += 1
					local step = entry.Steps[entry.StepIndex]
					local sub = if step then string.format("%s · %s", step.Label, ctx.Effects.DisplayArea(step.Room)) else ""
					local progress = if #entry.Steps > 1 then string.format(" (%d/%d)", math.min(entry.StepIndex - 1, #entry.Steps), #entry.Steps) else ""
					taskRow(entry.Name .. progress, sub, entry.Done, order)
					if step and not entry.Done then
						wantedMarkers[step.Anchor] = step.Label
					end
				end
			end
			if type(shared) == "table" and #shared > 0 then
				order += 1
				Components.label("SHARED OBJECTIVES", {
					Font = Theme.Font.Bold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.status("Warning"),
					LayoutOrder = order,
					Parent = objectiveBody,
				})
				for _, entry in shared do
					order += 1
					taskRow(entry.Name, string.format("%s · %s", entry.Label, ctx.Effects.DisplayArea(entry.Room)), false, order)
				end
			end
		end
		setMarkers(wantedMarkers)

		-- Ship status
		local meters = ctx.Client.GetPublic(Constants.PublicKey.Meters)
		if type(meters) == "table" then
			local stability = meters.Stability or 0
			stabilityBar.Set(stability / 100, string.format("HULL STABILITY %d%%", math.floor(stability)), if stability < 30 then Theme.status("Danger") else Theme.status("Warning"))
			local restoration = meters.Restoration or 0
			restorationBar.Set(restoration / 100, string.format("RESTORATION %d%%", math.floor(restoration)), Theme.status("Success"))
		end
		Components.clear(hazardList)
		local hazards = ctx.Client.GetPublic(Constants.PublicKey.Hazards)
		if type(hazards) == "table" then
			for index, hazard in hazards do
				local chip = Components.chip(
					string.format("%s %s · %s", if hazard.Critical then "⚠⚠" else "⚠", hazard.Name, hazard.TargetName or ""),
					if hazard.Critical then Theme.status("Danger") else Theme.status("Warning")
				)
				chip.LayoutOrder = index
				chip.Parent = hazardList
			end
		end

		-- Personal
		roleLabel.Text = if faction == Constants.Faction.Infiltrator then "INFILTRATOR" elseif faction then "CREW" else ""
		roleLabel.TextColor3 = Theme.factionColor(faction)
		if type(role) == "table" then
			accentLabel.Text = "Accent " .. AccentPalette.label(role.Accent or 1)
			accentLabel.TextColor3 = Theme.accentColor(role.Accent)
		end
		local carrying = ctx.Client.GetPrivate(Constants.PrivateKey.Carrying)
		carryLabel.Visible = type(carrying) == "string"
		carryLabel.Text = if type(carrying) == "string" then "Carrying: " .. carrying else ""
		local tokens = ctx.Client.GetPrivate(Constants.PrivateKey.Tokens)
		if type(tokens) == "table" then
			tokenLabel.Text = string.format(
				"Muster beacon %d/%d · Audits %d",
				math.max(0, (tokens.BeaconLimit or 1) - (tokens.BeaconUses or 0)),
				tokens.BeaconLimit or 1,
				tokens.AuditTokens or 0
			)
			alertButton.Visible = (tokens.AlertTokens or 0) > 0 and ctx.Client.GetRoundState() == Constants.RoundState.ActiveRound
		end
		local chatMode = if ctx.Chat.IsOnRadio() then "Radio (V to switch)" else "Proximity chat (V for radio)"
		commsLabel.Text = chatMode .. (if ctx.Voice.IsEnabled() then " · Voice nearby" else "")

		abilities.Visible = faction == Constants.Faction.Infiltrator
	end

	-- Fast-changing text (timers, location, cooldowns) on a light loop.
	task.spawn(function()
		while true do
			task.wait(0.2)
			if root.Visible then
				local now = workspace:GetServerTimeNow()
				local timer = ctx.Client.GetPublic(Constants.PublicKey.Timer)
				local escape = ctx.Client.GetPublic(Constants.PublicKey.Escape)
				if type(timer) == "table" and type(timer.EndsAt) == "number" then
					timerLabel.Text = string.format("%s  %s", string.upper(timer.Label or ""), Format.clock(timer.EndsAt - now))
					timerLabel.TextColor3 = if timer.EndsAt - now < 10 then Theme.status("Danger") else Theme.Color.Text
				else
					local info = ctx.Client.GetPublic(Constants.PublicKey.MatchInfo)
					timerLabel.Text = if type(info) == "table" and info.ActiveSince then "SHIP CLOCK " .. Format.clock(now - info.ActiveSince) else ""
					timerLabel.TextColor3 = Theme.Color.Muted
				end
				local area = ctx.Effects.GetArea()
				locationLabel.Text = "Location: " .. ctx.Effects.DisplayArea(area)
				local siphon = ctx.Client.GetPrivate(Constants.PrivateKey.Siphon)
				if type(siphon) == "table" then
					local wait = (siphon.ReadyAt or 0) - now
					siphonLabel.Text = if wait > 0 then string.format("Siphon recharging %ds", math.ceil(wait)) else "Siphon READY (F / Y near target)"
				end
				local abilitiesState = ctx.Client.GetPrivate(Constants.PrivateKey.Abilities)
				if type(abilitiesState) == "table" then
					local wait = (abilitiesState.GlobalReadyAt or 0) - now
					sabotageLabel.Text = if wait > 0 then string.format("Sabotage link %ds", math.ceil(wait)) else "Sabotage READY"
				end
				-- Distance on markers.
				local character = localPlayer.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rootPart and not escape then
					for _, gui in markers do
						local adornee = gui.Adornee
						local label = gui:FindFirstChild("Text") :: TextLabel?
						if adornee and adornee:IsA("BasePart") and label then
							local base = string.match(label.Text, "^(.-)  %(") or label.Text
							label.Text = string.format("%s  (%dm)", base, math.floor((adornee.Position - rootPart.Position).Magnitude))
						end
					end
				end
			end
		end
	end)

	ctx.Chat.RadioChanged:Connect(function()
		if root.Visible then
			refresh()
		end
	end)

	return {
		Root = root,
		Refresh = refresh,
		OnHide = function()
			setMarkers({})
		end,
	}
end
