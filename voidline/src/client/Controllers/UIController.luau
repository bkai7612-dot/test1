--!strict
--[[
	UIController
	Phase 1: a small diagnostic status panel and a notification toast, built in
	code so the foundation can be verified in a playtest. The full sci-fi UI
	(main menu, lobby, HUD, meetings, results) replaces this in Phase 13.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Types = require(Shared.Types)

local ClientController = require(script.Parent.ClientController)

local localPlayer = Players.LocalPlayer

local THEME = {
	Background = Color3.fromRGB(12, 16, 24),
	Accent = Color3.fromRGB(86, 214, 255),
	Text = Color3.fromRGB(226, 234, 245),
	Muted = Color3.fromRGB(140, 154, 176),
	Warning = Color3.fromRGB(255, 196, 92),
	Alert = Color3.fromRGB(255, 104, 104),
	Font = Enum.Font.Gotham,
	FontBold = Enum.Font.GothamBold,
}

-- Every notification kind has a text prefix, so meaning never relies on colour alone.
local KIND_STYLE: { [string]: { Color: Color3, Prefix: string } } = {
	[Constants.NotificationKind.Info] = { Color = THEME.Accent, Prefix = "INFO" },
	[Constants.NotificationKind.Warning] = { Color = THEME.Warning, Prefix = "WARNING" },
	[Constants.NotificationKind.Alert] = { Color = THEME.Alert, Prefix = "ALERT" },
}

local UIController = {}

local statusLabels: { [string]: TextLabel } = {}
local toast: TextLabel? = nil
local toastToken = 0

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeLabel(parent: Instance, name: string, order: number, font: Enum.Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.Font = font
	label.TextSize = 14
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = parent
	return label
end

local function buildGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "VoidlineDebugHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	local panel = Instance.new("Frame")
	panel.Name = "StatusPanel"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 12, 1, -12)
	panel.AutomaticSize = Enum.AutomaticSize.XY
	panel.Size = UDim2.fromOffset(0, 0)
	panel.BackgroundColor3 = THEME.Background
	panel.BackgroundTransparency = 0.2
	panel.Parent = gui
	addCorner(panel, 8)

	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Accent
	stroke.Transparency = 0.6
	stroke.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = panel

	local title = makeLabel(panel, "Title", 1, THEME.FontBold, THEME.Accent)
	title.Text = string.format("%s // %s", Config.Game.Title, Config.Game.ShipName)

	statusLabels.Link = makeLabel(panel, "Link", 2, THEME.Font, THEME.Text)
	statusLabels.RoundState = makeLabel(panel, "RoundState", 3, THEME.Font, THEME.Text)
	statusLabels.PlayerCount = makeLabel(panel, "PlayerCount", 4, THEME.Font, THEME.Text)
	statusLabels.Session = makeLabel(panel, "Session", 5, THEME.Font, THEME.Muted)
	statusLabels.Version = makeLabel(panel, "Version", 6, THEME.Font, THEME.Muted)

	local toastLabel = Instance.new("TextLabel")
	toastLabel.Name = "Toast"
	toastLabel.AnchorPoint = Vector2.new(0.5, 0)
	toastLabel.Position = UDim2.new(0.5, 0, 0, 12)
	toastLabel.AutomaticSize = Enum.AutomaticSize.XY
	toastLabel.Size = UDim2.fromOffset(0, 0)
	toastLabel.BackgroundColor3 = THEME.Background
	toastLabel.BackgroundTransparency = 0.15
	toastLabel.Font = THEME.FontBold
	toastLabel.TextSize = 16
	toastLabel.TextColor3 = THEME.Text
	toastLabel.Visible = false
	toastLabel.Parent = gui
	addCorner(toastLabel, 6)

	local toastPadding = Instance.new("UIPadding")
	toastPadding.PaddingTop = UDim.new(0, 8)
	toastPadding.PaddingBottom = UDim.new(0, 8)
	toastPadding.PaddingLeft = UDim.new(0, 14)
	toastPadding.PaddingRight = UDim.new(0, 14)
	toastPadding.Parent = toastLabel

	local toastStroke = Instance.new("UIStroke")
	toastStroke.Name = "Stroke"
	toastStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	toastStroke.Parent = toastLabel

	toast = toastLabel
	return gui
end

local function refresh()
	if not statusLabels.Link then
		return
	end
	statusLabels.Link.Text = "Link: " .. (if ClientController.IsSynced() then "ONLINE" else "connecting...")
	statusLabels.RoundState.Text = "Ship state: " .. tostring(ClientController.GetPublic(Constants.PublicKey.RoundState) or "-")
	statusLabels.PlayerCount.Text = "Crew aboard: " .. tostring(ClientController.GetPublic(Constants.PublicKey.PlayerCount) or "-")

	local session = ClientController.GetPrivate(Constants.PrivateKey.Session)
	statusLabels.Session.Text = "You: "
		.. (if type(session) == "table" then tostring(session.Status) else "-")
	statusLabels.Version.Text = "Build " .. tostring(ClientController.GetPublic(Constants.PublicKey.ServerVersion) or "?")
end

local function showNotification(notification: Types.Notification)
	local label = toast
	if not label then
		return
	end
	local style = KIND_STYLE[notification.Kind] or KIND_STYLE[Constants.NotificationKind.Info]
	toastToken += 1
	local token = toastToken

	label.Text = string.format("[%s]  %s", style.Prefix, notification.Text)
	local stroke = label:FindFirstChild("Stroke") :: UIStroke?
	if stroke then
		stroke.Color = style.Color
	end
	label.TextTransparency = 0
	label.BackgroundTransparency = 0.15
	label.Visible = true

	local duration = if type(notification.Duration) == "number"
		then math.clamp(notification.Duration, 1, 15)
		else 4
	task.delay(duration, function()
		-- A newer notification replaced this one; let it manage visibility.
		if token ~= toastToken then
			return
		end
		local fade = TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		if token == toastToken then
			label.Visible = false
		end
	end)
end

function UIController.Init()
	if not Config.Debug.ShowDebugHud then
		return
	end
	local gui = buildGui()
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

function UIController.Start()
	ClientController.PublicChanged:Connect(refresh)
	ClientController.PrivateChanged:Connect(refresh)
	ClientController.Synced:Connect(refresh)
	ClientController.Notified:Connect(showNotification)
	refresh()
end

return UIController
