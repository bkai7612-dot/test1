--!strict
--[[
	UIController
	Builds and manages every screen.

	Layers (ScreenGuis):
	  Hud      in-round HUD (objectives, ship status, abilities)
	  Screens  state screens (lobby, role reveal, muster, results, spectator)
	  Modals   menus opened on demand (main menu, settings, customise, ...)
	  Overlay  notifications and captions (always on top)

	Visibility of state screens follows the round state and the local
	player's life state. Modals form a stack so "Back" returns to the
	previous menu. Every layer has a UIScale = automatic (screen size) x the
	player's UI scale setting, so the same layout works on phones, tablets,
	PCs and TVs.

	Screens are modules in UI/Screens returning `function(ctx) -> Screen`.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)
local ChatController = require(script.Parent.ChatController)
local ClientController = require(script.Parent.ClientController)
local EffectsController = require(script.Parent.EffectsController)
local InputController = require(script.Parent.InputController)
local InteractionController = require(script.Parent.InteractionController)
local MinigameController = require(script.Parent.MinigameController)
local SettingsController = require(script.Parent.SettingsController)
local VoiceController = require(script.Parent.VoiceController)
local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)

local Screens = script.Parent.Parent.UI.Screens
local localPlayer = Players.LocalPlayer

local S = Constants.RoundState

export type Screen = {
	Root: GuiObject,
	Refresh: (() -> ())?,
	OnShow: (() -> ())?,
	OnHide: (() -> ())?,
}

local UIController = {}

local layers: { [string]: ScreenGui } = {}
local scales: { UIScale } = {}
local screens: { [string]: Screen } = {}
local visible: { [string]: boolean } = {}
local modalStack: { string } = {}
local menuDismissed = false
local refreshQueued = false
local tutorialStarter: (() -> ())? = nil

local STATE_SCREENS = { "Lobby", "Hud", "RoleReveal", "Meeting", "Results", "Spectator" }
local MODAL_SCREENS = { "MainMenu", "Settings", "Customize", "Stats", "Credits", "Sabotage", "Admin", "Emotes" }

---------------------------------------------------------------------------
-- Context passed to screens
---------------------------------------------------------------------------

local ctx = {
	Client = ClientController,
	Settings = SettingsController,
	Input = InputController,
	Effects = EffectsController,
	Camera = CameraController,
	Chat = ChatController,
	Voice = VoiceController,
	Audio = AudioController,
	Minigame = MinigameController,
	Interaction = InteractionController,
	Layers = layers,
}

function ctx.Fire(remoteName: string, ...: any)
	Net.getEvent(remoteName):FireServer(...)
end

function ctx.Invoke(remoteName: string, ...: any): any
	local remote = Net.getFunction(remoteName)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	return if ok then result else nil
end

function ctx.Open(name: string)
	UIController.OpenModal(name)
end

function ctx.Close()
	UIController.CloseModal()
end

function ctx.DismissMenu()
	menuDismissed = true
	UIController.CloseAllModals()
end

function ctx.StartTutorial()
	UIController.CloseAllModals()
	menuDismissed = true
	if tutorialStarter then
		tutorialStarter()
	end
	UIController.Refresh()
end

function ctx.IsOpen(name: string): boolean
	return visible[name] == true
end

function ctx.Refresh()
	UIController.Refresh()
end

---------------------------------------------------------------------------
-- Layers and scaling
---------------------------------------------------------------------------

local function makeLayer(name: string, order: number, ignoreInset: boolean?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Voidline" .. name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if ignoreInset then
		gui.IgnoreGuiInset = true
	else
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end
	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Parent = gui
	table.insert(scales, scale)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	layers[name] = gui
	return gui
end

local function applyScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	local auto = math.clamp(math.min(viewport.X / 1366, viewport.Y / 768), 0.55, 1.35)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		auto = math.max(auto, 0.6)
	end
	local value = auto * (SettingsController.Get("UIScale") or 1)
	for _, scale in scales do
		scale.Scale = value
	end
	local minigameScale = MinigameController.GetGui():FindFirstChild("Scale") :: UIScale?
	if minigameScale then
		minigameScale.Scale = value
	end
end

---------------------------------------------------------------------------
-- Visibility
---------------------------------------------------------------------------

local function setVisible(name: string, value: boolean)
	local screen = screens[name]
	if not screen or visible[name] == value then
		return
	end
	visible[name] = value
	screen.Root.Visible = value
	if value then
		if screen.Refresh then
			screen.Refresh()
		end
		if screen.OnShow then
			screen.OnShow()
		end
	elseif screen.OnHide then
		screen.OnHide()
	end
end

local function computeStateScreens(): { [string]: boolean }
	local state = ClientController.GetRoundState()
	local life = ClientController.GetPrivate(Constants.PrivateKey.Life)
	local participant = life ~= nil
	local ghost = life == Constants.LifeState.Lost or life == Constants.LifeState.Confined
	local inRound = state == S.Preparation or state == S.ActiveRound or state == S.Emergency or state == S.Endgame
	local results = ClientController.GetPublic(Constants.PublicKey.Results)

	return {
		Lobby = state == S.Lobby and menuDismissed,
		RoleReveal = state == S.RoleAssignment and participant,
		Hud = participant and not ghost and inRound,
		Meeting = participant and (state == S.Discussion or state == S.Voting),
		Results = (state == S.Results or state == S.Reset) and results ~= nil,
		Spectator = (ghost and inRound) or (not participant and state ~= S.Lobby and state ~= S.Results and state ~= S.Reset),
	}
end

function UIController.Refresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		local wanted = computeStateScreens()
		for _, name in STATE_SCREENS do
			setVisible(name, wanted[name] == true)
		end
		for name, isVisible in visible do
			local screen = screens[name]
			if isVisible and screen and screen.Refresh then
				local ok: boolean, err: any = pcall(screen.Refresh)
				if not ok then
					warn("[UI] refresh failed for", name, err)
				end
			end
		end
		UIController.UpdateActions()
	end)
end

---------------------------------------------------------------------------
-- Modals
---------------------------------------------------------------------------

function UIController.OpenModal(name: string)
	if not screens[name] then
		return
	end
	local top = modalStack[#modalStack]
	if top == name then
		return
	end
	if top then
		setVisible(top, false)
	end
	table.insert(modalStack, name)
	setVisible(name, true)
	InteractionController.SetSuppressed(true)
	Components.focus(screens[name].Root)
	UIController.UpdateActions()
end

function UIController.CloseModal()
	local top = table.remove(modalStack)
	if top then
		setVisible(top, false)
	end
	local nextTop = modalStack[#modalStack]
	if nextTop then
		setVisible(nextTop, true)
		Components.focus(screens[nextTop].Root)
	else
		InteractionController.SetSuppressed(MinigameController.IsOpen())
		GuiService.SelectedObject = nil
	end
	UIController.UpdateActions()
end

function UIController.CloseAllModals()
	while #modalStack > 0 do
		UIController.CloseModal()
	end
end

function UIController.SetTutorialStarter(fn: () -> ())
	tutorialStarter = fn
end

function UIController.GetLayer(name: string): ScreenGui
	return layers[name]
end

---------------------------------------------------------------------------
-- Actions (keyboard / gamepad / touch)
---------------------------------------------------------------------------

local function bindIf(condition: boolean, spec: InputController.ActionSpec)
	if condition then
		if not InputController.IsBound(spec.Name) then
			InputController.Bind(spec)
		end
	elseif InputController.IsBound(spec.Name) then
		InputController.Unbind(spec.Name)
	end
end

function UIController.UpdateActions()
	local state = ClientController.GetRoundState()
	local life = ClientController.GetPrivate(Constants.PrivateKey.Life)
	local role = ClientController.GetPrivate(Constants.PrivateKey.Role)
	local tokens = ClientController.GetPrivate(Constants.PrivateKey.Tokens)
	local alive = life == Constants.LifeState.Alive
	local inPlay = state == S.ActiveRound or state == S.Emergency or state == S.Endgame
	local infiltrator = type(role) == "table" and role.Faction == Constants.Faction.Infiltrator
	local modalOpen = #modalStack > 0

	bindIf(modalOpen, {
		Name = "VoidlineBack",
		Title = "Back",
		Keys = { Enum.KeyCode.ButtonB },
		Touch = false,
		Callback = UIController.CloseModal,
	})
	bindIf(alive and inPlay and infiltrator and not modalOpen, {
		Name = "VoidlineSabotage",
		Title = "Sabotage",
		Keys = { Enum.KeyCode.Q, Enum.KeyCode.DPadUp },
		Touch = true,
		TouchPosition = UDim2.new(1, -95, 1, -230),
		Callback = function()
			UIController.OpenModal("Sabotage")
		end,
	})
	bindIf(alive and state == S.ActiveRound and type(tokens) == "table" and (tokens.AlertTokens or 0) > 0, {
		Name = "VoidlineAlert",
		Title = "Alert",
		Keys = { Enum.KeyCode.G, Enum.KeyCode.DPadRight },
		Touch = true,
		TouchPosition = UDim2.new(1, -170, 1, -230),
		Callback = function()
			ctx.Fire(Net.Names.EmergencyAlert)
		end,
	})
	bindIf(alive and inPlay, {
		Name = "VoidlineRadio",
		Title = "Radio",
		Keys = { Enum.KeyCode.V, Enum.KeyCode.DPadLeft },
		Touch = true,
		TouchPosition = UDim2.new(1, -245, 1, -170),
		Callback = ChatController.ToggleRadio,
	})
	bindIf(localPlayer.Character ~= nil and not modalOpen and (state == S.Lobby or alive), {
		Name = "VoidlineEmotes",
		Title = "Emote",
		Keys = { Enum.KeyCode.B, Enum.KeyCode.DPadDown },
		Touch = state == S.Lobby,
		TouchPosition = UDim2.new(1, -245, 1, -230),
		Callback = function()
			UIController.OpenModal("Emotes")
		end,
	})
	bindIf(state == S.Lobby and not modalOpen, {
		Name = "VoidlineMenu",
		Title = "Menu",
		Keys = { Enum.KeyCode.M, Enum.KeyCode.ButtonSelect },
		Touch = false,
		Callback = function()
			UIController.OpenModal("MainMenu")
		end,
	})
	bindIf(CameraController.IsSpectating(), {
		Name = "VoidlineSpectateNext",
		Title = "Next",
		Keys = { Enum.KeyCode.E, Enum.KeyCode.ButtonR2 },
		Touch = true,
		TouchPosition = UDim2.new(1, -95, 1, -170),
		Callback = function()
			CameraController.Cycle(1)
		end,
	})
	bindIf(ClientController.GetPrivate(Constants.PrivateKey.IsAdmin) == true, {
		Name = "VoidlineAdmin",
		Title = "Admin",
		Keys = { Enum.KeyCode.F2 },
		Touch = false,
		Callback = function()
			if visible.Admin then
				UIController.CloseModal()
			else
				UIController.OpenModal("Admin")
			end
		end,
	})
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function UIController.Init()
	-- Characters are server-managed, so the default "Reset character" is
	-- disabled. SetCore can fail until the CoreGui is ready, so retry briefly.
	task.spawn(function()
		for _ = 1, 20 do
			if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
				return
			end
			task.wait(0.5)
		end
	end)
	Theme.SetColorblind(SettingsController.Get("ColorblindMode") == true)
	Components.SetReducedMotion(SettingsController.Get("ReducedEffects") == true)

	makeLayer("Hud", 1)
	makeLayer("Screens", 3)
	makeLayer("Modals", 5)
	makeLayer("Overlay", 10)

	local parentFor: { [string]: string } = {
		Lobby = "Screens",
		Hud = "Hud",
		RoleReveal = "Screens",
		Meeting = "Screens",
		Results = "Screens",
		Spectator = "Hud",
	}
	for _, name in STATE_SCREENS do
		local module = Screens:FindFirstChild(name)
		if module and module:IsA("ModuleScript") then
			local screen = (require(module) :: any)(ctx) :: Screen
			screen.Root.Visible = false
			screen.Root.Parent = layers[parentFor[name]]
			screens[name] = screen
		end
	end
	for _, name in MODAL_SCREENS do
		local module = Screens:FindFirstChild(name)
		if module and module:IsA("ModuleScript") then
			local screen = (require(module) :: any)(ctx) :: Screen
			screen.Root.Visible = false
			screen.Root.Parent = layers.Modals
			screens[name] = screen
		end
	end
	-- Notifications are always visible.
	local notifications = (require(Screens:WaitForChild("Notifications")) :: any)(ctx) :: Screen
	notifications.Root.Parent = layers.Overlay
	screens.Notifications = notifications
	visible.Notifications = true
end

function UIController.Start()
	applyScale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	SettingsController.Changed:Connect(function(key: string, value: any)
		if key == "UIScale" then
			applyScale()
		elseif key == "ColorblindMode" then
			Theme.SetColorblind(value == true)
			UIController.Refresh()
		elseif key == "ReducedEffects" then
			Components.SetReducedMotion(value == true)
		end
	end)
	ClientController.PublicChanged:Connect(function(key: string, value: any)
		-- A launching match closes lobby menus so nobody misses their role reveal.
		if key == Constants.PublicKey.RoundState and value == S.Preparation then
			menuDismissed = true
			local keep = { Settings = true, Admin = true }
			for i = #modalStack, 1, -1 do
				if not keep[modalStack[i]] then
					UIController.CloseAllModals()
					break
				end
			end
		end
		UIController.Refresh()
	end)
	ClientController.PrivateChanged:Connect(function()
		UIController.Refresh()
	end)
	ClientController.Synced:Connect(UIController.Refresh)
	CameraController.SpectateChanged:Connect(function()
		UIController.Refresh()
	end)
	localPlayer.CharacterAdded:Connect(function()
		UIController.Refresh()
	end)

	-- First visit: the main menu greets the player.
	UIController.OpenModal("MainMenu")
	UIController.Refresh()
end

return UIController
