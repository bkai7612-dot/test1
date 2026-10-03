--!strict
--[[
	InteractionController
	Turns the server's private "Interactions" list into ProximityPrompts.
	Roblox prompts give keyboard, gamepad and touch support for free.

	The client never decides outcomes: prompts only *request* actions
	(InteractBegin / InteractComplete / InteractCancel) and the server
	validates range, line of sight, timing and game rules.

	Anchor parts are found by tag + AnchorId attribute, and prompts are
	(re)created as anchors stream in and out (StreamingEnabled).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local Signal = require(Shared.Utility.Signal)

local ClientController = require(script.Parent.ClientController)

local InteractionController = {}

-- (actionText: string) a hold prompt was released before it finished
InteractionController.HoldReleasedEarly = Signal.new()

local KEYBOARD = { Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.R }
local GAMEPAD = { Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonR1 }

local anchors: { [string]: BasePart } = {}
local entries: { [string]: Types.InteractionEntry } = {}
local prompts: { [string]: ProximityPrompt } = {}
local suppressed = false

local beginRemote: RemoteEvent
local cancelRemote: RemoteEvent
local completeRemote: RemoteEvent

local function destroyPrompt(id: string)
	local prompt = prompts[id]
	if prompt then
		prompts[id] = nil
		prompt:Destroy()
	end
end

local function createPrompt(id: string, entry: Types.InteractionEntry)
	local anchor = anchors[entry.Anchor]
	if not anchor or not anchor.Parent then
		return
	end
	local existing = prompts[id]
	if not existing or existing.Parent ~= anchor then
		destroyPrompt(id)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Voidline_" .. id
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.ClickablePrompt = true
		local triggered = false
		local heldSince = 0
		prompt.PromptButtonHoldBegan:Connect(function()
			triggered = false
			heldSince = os.clock()
			beginRemote:FireServer(id)
		end)
		prompt.PromptButtonHoldEnded:Connect(function()
			if not triggered then
				cancelRemote:FireServer(id)
				if os.clock() - heldSince < prompt.HoldDuration then
					InteractionController.HoldReleasedEarly:Fire(prompt.ActionText, prompt.HoldDuration)
				end
			end
		end)
		prompt.Triggered:Connect(function()
			triggered = true
			completeRemote:FireServer(id)
		end)
		prompt.Parent = anchor
		prompts[id] = prompt
		existing = prompt
	end
	local p = existing :: ProximityPrompt
	p.ActionText = entry.Action
	p.ObjectText = entry.Object
	p.HoldDuration = entry.Hold
	p.MaxActivationDistance = entry.Range
	p.KeyboardKeyCode = KEYBOARD[entry.Key] or KEYBOARD[1]
	p.GamepadKeyCode = GAMEPAD[entry.Key] or GAMEPAD[1]
	p.Enabled = not suppressed
end

local function sync()
	for id in table.clone(prompts) do
		if not entries[id] then
			destroyPrompt(id)
		end
	end
	for id, entry in entries do
		createPrompt(id, entry)
	end
end

local function onAnchorAdded(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute(Constants.Attribute.AnchorId)
	if type(id) ~= "string" then
		return
	end
	anchors[id] = part
	for entryId, entry in entries do
		if entry.Anchor == id then
			createPrompt(entryId, entry)
		end
	end
end

local function onAnchorRemoved(part: Instance)
	local id = part:GetAttribute(Constants.Attribute.AnchorId)
	if type(id) == "string" and anchors[id] == part then
		anchors[id] = nil
	end
end

-- Hide all prompts (e.g. while a mini-game or menu is open).
function InteractionController.SetSuppressed(value: boolean)
	suppressed = value
	for _, prompt in prompts do
		prompt.Enabled = not value
	end
end

-- Current entries (used by the HUD for objective markers).
function InteractionController.GetAnchor(anchorId: string): BasePart?
	return anchors[anchorId]
end

function InteractionController.Init()
	beginRemote = Net.getEvent(Net.Names.InteractBegin)
	cancelRemote = Net.getEvent(Net.Names.InteractCancel)
	completeRemote = Net.getEvent(Net.Names.InteractComplete)
end

function InteractionController.Start()
	for _, part in CollectionService:GetTagged(Constants.Tag.InteractAnchor) do
		onAnchorAdded(part)
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tag.InteractAnchor):Connect(onAnchorAdded)
	CollectionService:GetInstanceRemovedSignal(Constants.Tag.InteractAnchor):Connect(onAnchorRemoved)

	ClientController.PrivateChanged:Connect(function(key: string, value: any)
		if key == Constants.PrivateKey.Interactions then
			entries = if type(value) == "table" then value else {}
			sync()
		end
	end)
	local initial = ClientController.GetPrivate(Constants.PrivateKey.Interactions)
	if type(initial) == "table" then
		entries = initial
		sync()
	end
end

return InteractionController
