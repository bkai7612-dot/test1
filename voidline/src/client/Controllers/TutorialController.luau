--!strict
--[[
	TutorialController
	A short, interactive training in the lobby's Training Bay:
	  move -> interact -> objective mini-game -> evidence -> hazards ->
	  musters -> voting -> escape
	Practice props use local prompts and a local mini-game, so nothing here
	touches real objectives. Finishing tells the server once (one-time reward).
	It never blocks play: players can skip at any time, and it closes itself
	when a match launches.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local ClientController = require(script.Parent.ClientController)
local MinigameController = require(script.Parent.MinigameController)
local UIController = require(script.Parent.UIController)
local Components = require(script.Parent.Parent.UI.Components)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)

local localPlayer = Players.LocalPlayer

local TutorialController = {}

type Step = {
	Title: string,
	Text: string,
	Button: string?, -- shows a Continue-style button
	Prop: string?, -- TrainingId of the prop to interact with
	Action: string?,
	Hold: number?,
	Reach: boolean?, -- completes when close to the Training Bay
	Minigame: string?,
}

local STEPS: { Step } = {
	{
		Title = "Welcome aboard",
		Text = "This two-minute training covers everything you need for your first shift on the ASTERION. Skip any time.",
		Button = "Start",
	},
	{
		Title = "Movement",
		Text = "Walk to the TRAINING BAY - the blue floor on the east side of the lounge. WASD / left stick / on-screen joystick. Hold Shift (L3) to sprint.",
		Reach = true,
	},
	{
		Title = "Interacting & objectives",
		Text = "Objectives are consoles around the ship. Hold E (X on gamepad, or tap) at the PRACTICE CONSOLE, then align the sliders.",
		Prop = "Console",
		Action = "Practice objective",
		Hold = 1,
		Minigame = "Sliders",
	},
	{
		Title = "Evidence",
		Text = "When someone is siphoned they leave a stasis pod. SCAN pods to reveal the attacker's suit accent. Scan the PRACTICE POD.",
		Prop = "Pod",
		Action = "Scan residue",
		Hold = 2,
	},
	{
		Title = "Emergencies",
		Text = "Hazards and sabotage break ship systems. Fix them at the marked panel before they cost hull stability. Reset the PRACTICE BREAKER.",
		Prop = "Breaker",
		Action = "Reset breaker",
		Hold = 2,
	},
	{
		Title = "Musters",
		Text = "Report a stasis pod, or use the Muster Beacon in Central Operations, to gather the crew and talk. Press the PRACTICE BEACON.",
		Prop = "Beacon",
		Action = "Call practice muster",
		Hold = 1,
	},
	{
		Title = "Voting",
		Text = "In a muster: review the ship log, AUDIT a suspect if you hold a token, REQUEST EVIDENCE to pull security logs, then ACCUSE someone or SKIP. Ties confine nobody.",
		Button = "Got it",
	},
	{
		Title = "Escape",
		Text = "Objectives raise RESTORATION. At 100% the ship breaks apart: follow the extraction steps and be inside the extraction room when the countdown ends. Infiltrators win if the hull collapses or they outnumber you.",
		Button = "Finish training",
	},
}

local active = false
local stepIndex = 0
local panel: Frame
local titleLabel: TextLabel
local bodyLabel: TextLabel
local continueButton: TextButton
local currentPrompt: ProximityPrompt? = nil
local reachThread: thread? = nil

local function findProp(id: string): BasePart?
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return nil
	end
	for _, descendant in lobby:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("TrainingId") == id then
			return descendant
		end
	end
	return nil
end

local function clearStep()
	if currentPrompt then
		currentPrompt:Destroy()
		currentPrompt = nil
	end
	if reachThread then
		pcall(task.cancel, reachThread)
		reachThread = nil
	end
end

local function finish(completed: boolean)
	clearStep()
	active = false
	panel.Visible = false
	if completed then
		Net.getEvent(Net.Names.TutorialComplete):FireServer()
	end
end

local showStep: (number) -> ()

local function advance()
	if stepIndex >= #STEPS then
		finish(true)
	else
		showStep(stepIndex + 1)
	end
end

function showStep(index: number)
	clearStep()
	stepIndex = index
	local step = STEPS[index]
	titleLabel.Text = string.format("TRAINING %d/%d · %s", index, #STEPS, string.upper(step.Title))
	bodyLabel.Text = step.Text
	continueButton.Visible = step.Button ~= nil
	continueButton.Text = step.Button or ""

	if step.Reach then
		reachThread = task.spawn(function()
			local target = findProp("Console")
			while active and stepIndex == index do
				local character = localPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				target = target or findProp("Console")
				if not target then
					-- Not streamed in: let the player continue manually.
					continueButton.Visible = true
					continueButton.Text = "Continue"
				elseif root and (root.Position - target.Position).Magnitude < 22 then
					advance()
					return
				end
				task.wait(0.3)
			end
		end)
	elseif step.Prop then
		local prop = findProp(step.Prop)
		if not prop then
			continueButton.Visible = true
			continueButton.Text = "Continue"
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "VoidlineTraining"
		prompt.ActionText = step.Action or "Use"
		prompt.ObjectText = "Training"
		prompt.HoldDuration = step.Hold or 1
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			if step.Minigame then
				prompt.Enabled = false
				MinigameController.RunLocal(step.Minigame, function(success)
					if success and stepIndex == index then
						advance()
					else
						prompt.Enabled = true
					end
				end)
			else
				advance()
			end
		end)
		prompt.Parent = prop
		currentPrompt = prompt
	end
end

function TutorialController.Begin()
	if ClientController.GetRoundState() ~= Constants.RoundState.Lobby then
		return
	end
	active = true
	panel.Visible = true
	showStep(1)
end

function TutorialController.IsActive(): boolean
	return active
end

function TutorialController.Init()
	panel = Components.panel({
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = UIController.GetLayer("Overlay"),
	})
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.Color.Accent
	end
	Components.padding(14).Parent = panel
	Components.list(8).Parent = panel
	titleLabel = Components.label("", { Font = Theme.Font.Bold, TextColor3 = Theme.Color.Accent, LayoutOrder = 1, Parent = panel })
	bodyLabel = Components.label("", { LayoutOrder = 2, Parent = panel })
	local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 3, Parent = panel })
	continueButton = Components.button("Continue", advance, "Primary", { Size = UDim2.new(0.6, -4, 1, 0), Parent = row })
	Components.button("Skip training", function()
		finish(false)
	end, "Ghost", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, -4, 1, 0), Parent = row })

	UIController.SetTutorialStarter(TutorialController.Begin)
end

function TutorialController.Start()
	-- A launching match ends training.
	ClientController.PublicChanged:Connect(function(key: string, value: any)
		if key == Constants.PublicKey.RoundState and value ~= Constants.RoundState.Lobby and active then
			finish(false)
		end
	end)
end

return TutorialController
