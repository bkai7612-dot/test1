--!strict
--[[
	Meeting (muster)
	  Left    crew cards: accent, status, voted marker; per-card ACCUSE (voting)
	          and AUDIT (if you hold an Audit token)
	  Right   ship log (public evidence) and your private evidence (SHARE)
	  Bottom  SKIP, REQUEST EVIDENCE (once per muster), END DISCUSSION
	  Result  outcome card after voting

	The server validates every action; buttons only send requests.
	Signal Ghosts see the muster read-only.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local AccentPalette = require(Shared.Data.AccentPalette)
local Format = require(Shared.Utility.Format)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local localPlayer = Players.LocalPlayer
local A = Constants.MeetingAction

return function(ctx: any)
	local root = Create("Frame", {
		Name = "Meeting",
		BackgroundColor3 = Theme.Color.Background,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
	})
	local panel = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1060, 640),
		Parent = root,
	})
	Components.padding(16).Parent = panel

	local title = Components.label("", {
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Title,
		TextColor3 = Theme.Color.Accent,
		Size = UDim2.new(1, -200, 0, 32),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = panel,
	})
	local subtitle = Components.label("", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, -200, 0, 20),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Theme.Color.Muted,
		Parent = panel,
	})
	local timer = Components.label("", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(190, 32),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.Font.Mono,
		TextSize = Theme.TextSize.Title,
		Parent = panel,
	})
	local phaseLabel = Components.label("", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 34),
		Size = UDim2.fromOffset(190, 20),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.Font.Bold,
		Parent = panel,
	})

	local crewGrid = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(0.56, -8, 1, -130),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Selectable = false,
		Parent = panel,
	})
	Create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 92),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = crewGrid,
	})

	local evidencePanel = Components.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 66),
		Size = UDim2.new(0.44, -8, 1, -130),
		BackgroundColor3 = Theme.Color.PanelLight,
		Parent = panel,
	})
	Components.padding(10).Parent = evidencePanel
	Components.label("SHIP LOG", { Font = Theme.Font.Bold, TextColor3 = Theme.Color.Accent, Parent = evidencePanel })
	local evidenceList = Components.scroll({
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		Parent = evidencePanel,
	})

	local actions = Create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 48),
		Parent = panel,
	})
	Components.list(10, true).Parent = actions
	local skipButton = Components.button("SKIP VOTE", function()
		ctx.Fire(Net.Names.MeetingAction, A.Skip)
	end, "Secondary", { Size = UDim2.fromOffset(200, 46), LayoutOrder = 1, Parent = actions })
	local requestButton = Components.button("REQUEST EVIDENCE", function()
		ctx.Fire(Net.Names.MeetingAction, A.RequestEvidence)
	end, "Primary", { Size = UDim2.fromOffset(230, 46), LayoutOrder = 2, Parent = actions })
	local endButton = Components.button("END DISCUSSION", function()
		ctx.Fire(Net.Names.MeetingAction, A.EndDiscussion)
	end, "Secondary", { Size = UDim2.fromOffset(260, 46), LayoutOrder = 3, Parent = actions })
	local hint = Components.label("", {
		Size = UDim2.fromOffset(300, 46),
		AutomaticSize = Enum.AutomaticSize.None,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = Theme.Color.Muted,
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 4,
		Parent = actions,
	})

	local resultCard = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(620, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Components.padding(24).Parent = resultCard
	Components.list(8, false, Enum.HorizontalAlignment.Center).Parent = resultCard
	local resultTitle = Components.label("", {
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Parent = resultCard,
	})
	local resultBody = Components.label("", {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Color.Muted,
		LayoutOrder = 2,
		Parent = resultCard,
	})

	local lastFocusedPhase = ""

	local function entryRow(text: string, sub: string?, color: Color3?, order: number, share: (() -> ())?)
		local row = Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = evidenceList,
		})
		Components.list(2).Parent = row
		Components.label(text, { TextSize = Theme.TextSize.Small + 1, TextColor3 = color or Theme.Color.Text, Parent = row })
		if sub then
			Components.label(sub, { TextSize = Theme.TextSize.Small - 1, TextColor3 = Theme.Color.Faint, Parent = row })
		end
		if share then
			Components.button("SHARE WITH CREW", share, "Primary", { Size = UDim2.fromOffset(170, 28), TextSize = Theme.TextSize.Small, Parent = row })
		end
	end

	local function refresh()
		local meeting = ctx.Client.GetPublic(Constants.PublicKey.Meeting)
		if type(meeting) ~= "table" then
			return
		end
		local life = ctx.Client.GetPrivate(Constants.PrivateKey.Life)
		local canAct = life == Constants.LifeState.Alive
		local tokens = ctx.Client.GetPrivate(Constants.PrivateKey.Tokens)
		local audits = if type(tokens) == "table" then tokens.AuditTokens or 0 else 0
		local phase = meeting.Phase
		local voted: { [number]: boolean } = {}
		for _, userId in meeting.Voted or {} do
			voted[userId] = true
		end
		local iVoted = voted[localPlayer.UserId] == true

		title.Text = if meeting.Reason == "Report"
			then "MUSTER · BODY REPORTED"
			elseif meeting.Reason == "Alert" then "MUSTER · EMERGENCY ALERT"
			else "MUSTER · BEACON"
		local sub = "Called by " .. tostring(meeting.CallerName)
		if meeting.Subject then
			sub ..= " · " .. meeting.Subject .. " was found in stasis"
		end
		if meeting.Revealed and #meeting.Revealed > 0 then
			sub ..= " · Signals lost: " .. table.concat(meeting.Revealed, ", ")
		end
		subtitle.Text = sub
		phaseLabel.Text = if phase == "Discussion" then "DISCUSS" elseif phase == "Voting" then "VOTE NOW" else "RESULT"
		phaseLabel.TextColor3 = if phase == "Voting" then Theme.status("Warning") else Theme.Color.Accent

		-- Crew cards
		Components.clear(crewGrid)
		local roster = ctx.Client.GetPublic(Constants.PublicKey.Roster) or {}
		for index, entry in roster do
			local active = entry.Status == "Active"
			local card = Components.panel({
				LayoutOrder = index,
				BackgroundColor3 = if active then Theme.Color.PanelLight else Theme.Color.Panel,
				BackgroundTransparency = if active then 0 else 0.4,
				Parent = crewGrid,
			})
			Components.padding(8).Parent = card
			local isMe = entry.UserId == localPlayer.UserId
			Components.label(entry.DisplayName .. (if isMe then " (you)" else ""), {
				Font = Theme.Font.Bold,
				Size = UDim2.new(1, -60, 0, 20),
				AutomaticSize = Enum.AutomaticSize.None,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = if active then Theme.Color.Text else Theme.Color.Faint,
				Parent = card,
			})
			Components.label(AccentPalette.label(entry.Accent or 1), {
				Position = UDim2.fromOffset(0, 20),
				Size = UDim2.new(1, 0, 0, 18),
				AutomaticSize = Enum.AutomaticSize.None,
				TextSize = Theme.TextSize.Small,
				Font = Theme.Font.Bold,
				TextColor3 = Theme.accentColor(entry.Accent),
				Parent = card,
			})
			local statusText = if not active then string.upper(entry.Status) elseif voted[entry.UserId] then "✓ VOTED" else ""
			if statusText ~= "" then
				local chip = Components.chip(statusText, if active then Theme.status("Success") else Theme.Color.Faint)
				chip.AnchorPoint = Vector2.new(1, 0)
				chip.Position = UDim2.fromScale(1, 0)
				chip.Parent = card
			end
			if active and canAct and not isMe then
				local buttonsRow = Create("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 30),
					Parent = card,
				})
				Components.list(6, true).Parent = buttonsRow
				if phase == "Voting" and not iVoted then
					Components.button("ACCUSE", function()
						ctx.Fire(Net.Names.MeetingAction, A.Accuse, entry.UserId)
					end, "Danger", { Size = UDim2.fromOffset(110, 28), TextSize = Theme.TextSize.Small, Parent = buttonsRow })
				end
				if phase ~= "Result" and audits > 0 then
					Components.button("AUDIT", function()
						ctx.Fire(Net.Names.MeetingAction, A.Investigate, entry.UserId)
					end, "Primary", { Size = UDim2.fromOffset(90, 28), TextSize = Theme.TextSize.Small, Parent = buttonsRow })
				end
			end
		end

		-- Evidence
		Components.clear(evidenceList)
		local order = 0
		local private = ctx.Client.GetPrivate(Constants.PrivateKey.PrivateEvidence)
		if type(private) == "table" and #private > 0 then
			for _, entry in private do
				order += 1
				entryRow("🔒 " .. entry.Text, "Only you know this · " .. Format.clock(entry.Time or 0), Theme.status("Warning"), order, if canAct and phase ~= "Result"
					then function()
						ctx.Fire(Net.Names.ShareEvidence, entry.Id)
					end
					else nil)
			end
		end
		local log = ctx.Client.GetPublic(Constants.PublicKey.Evidence)
		if type(log) == "table" and #log > 0 then
			for i = #log, 1, -1 do
				local entry = log[i]
				order += 1
				entryRow(entry.Text, string.format("%s%s", Format.clock(entry.Time or 0), if entry.SharedBy then " · shared by " .. entry.SharedBy else ""), nil, order, nil)
			end
		else
			order += 1
			entryRow("No evidence recorded yet. Scan stasis pods and download security logs.", nil, Theme.Color.Muted, order, nil)
		end

		-- Actions
		skipButton.Visible = phase == "Voting" and canAct and not iVoted
		requestButton.Visible = phase == "Discussion" and canAct and not meeting.RequestUsed
		endButton.Visible = phase == "Discussion" and canAct
		endButton.Text = string.format("END DISCUSSION (%d/%d)", meeting.EndDiscussionCount or 0, meeting.EndDiscussionNeeded or 0)
		hint.Text = if not canAct
			then "You are watching as a Signal Ghost."
			elseif phase == "Voting" and iVoted then "Vote cast. Waiting for the crew..."
			elseif audits > 0 then "You hold an Audit token: AUDIT reveals where someone was at the last incident."
			else "Talk it through. Evidence never names a culprit."

		-- Result card
		local result = meeting.Result
		resultCard.Visible = phase == "Result" and type(result) == "table"
		if type(result) == "table" then
			if result.Outcome == "Confine" then
				local factionText = if result.Faction == Constants.Faction.Infiltrator
					then " They were an INFILTRATOR."
					elseif result.Faction == Constants.Faction.Crew then " They were CREW."
					else ""
				resultTitle.Text = string.upper(result.TargetName or "?") .. " CONFINED"
				resultTitle.TextColor3 = if result.Faction then Theme.factionColor(result.Faction) else Theme.Color.Text
				resultBody.Text = "Sealed in the brig." .. factionText
			else
				resultTitle.Text = if result.Outcome == "Tie" then "TIED VOTE" elseif result.Outcome == "Skip" then "VOTE SKIPPED" else "NO VOTES"
				resultTitle.TextColor3 = Theme.Color.Text
				resultBody.Text = "Nobody was confined."
			end
			local counts = {}
			for _, item in result.Counts or {} do
				for _, entry in roster do
					if entry.UserId == item.UserId then
						table.insert(counts, string.format("%s: %d", entry.DisplayName, item.Count))
					end
				end
			end
			if (result.SkipCount or 0) > 0 then
				table.insert(counts, "Skip: " .. result.SkipCount)
			end
			if #counts > 0 then
				resultBody.Text ..= "\n" .. table.concat(counts, "   ")
			end
		end

		-- Rebuilding destroys the selected button; keep gamepad focus inside the panel.
		if phase ~= lastFocusedPhase or GuiService.SelectedObject == nil then
			lastFocusedPhase = phase
			Components.focus(panel)
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.25)
			if root.Visible then
				local meeting = ctx.Client.GetPublic(Constants.PublicKey.Meeting)
				if type(meeting) == "table" and type(meeting.EndsAt) == "number" then
					local remaining = meeting.EndsAt - workspace:GetServerTimeNow()
					timer.Text = Format.clock(remaining)
					timer.TextColor3 = if remaining < 10 then Theme.status("Danger") else Theme.Color.Text
				end
			end
		end
	end)

	return {
		Root = root,
		Refresh = refresh,
		OnShow = function()
			lastFocusedPhase = ""
			ctx.Interaction.SetSuppressed(true)
		end,
		OnHide = function()
			ctx.Interaction.SetSuppressed(false)
		end,
	}
end
