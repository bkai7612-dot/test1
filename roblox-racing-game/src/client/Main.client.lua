-- Client entry point: builds the UI and wires server events.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.State)
local CarController = require(script.Parent.CarController)
local LightingController = require(script.Parent.LightingController)

local UI = script.Parent.UI
local HUD = require(UI.HUD)
local Notify = require(UI.Notify)
local Garage = require(UI.Garage)
local UpgradesPanel = require(UI.UpgradesPanel)
local CustomizePanel = require(UI.CustomizePanel)
local ShopPanel = require(UI.ShopPanel)
local CodesPanel = require(UI.CodesPanel)
local RaceHUD = require(UI.RaceHUD)
local Results = require(UI.Results)
local MobileControls = require(UI.MobileControls)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "RedlineRushUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

Notify.Init(gui)
HUD.Init(gui)
Garage.Init(gui, HUD)
UpgradesPanel.Init(gui, HUD)
CustomizePanel.Init(gui, HUD)
ShopPanel.Init(gui, HUD)
CodesPanel.Init(gui, HUD)
RaceHUD.Init(gui, HUD, player.UserId)
Results.Init(gui, HUD, player.UserId)
MobileControls.Init(gui, CarController)

HUD.RegisterPanel("Garage", Garage)
HUD.RegisterPanel("Upgrades", UpgradesPanel)
HUD.RegisterPanel("Customize", CustomizePanel)
HUD.RegisterPanel("Shop", ShopPanel)
HUD.RegisterPanel("Codes", CodesPanel)

CarController.OnTelemetry = RaceHUD.SetTelemetry

State.On("Driving", function(driving, mode)
	if driving then
		RaceHUD.Show(mode)
	else
		RaceHUD.Hide()
	end
	MobileControls.SetVisible(driving, mode)
	if driving and mode == "race" then
		HUD.CloseAll()
	end
end)

---------------------------------------------------------------------------
-- Server events
---------------------------------------------------------------------------
Remotes.Event("DataUpdated").OnClientEvent:Connect(State.SetData)
Remotes.Event("Notify").OnClientEvent:Connect(Notify.Show)

Remotes.Event("RaceState").OnClientEvent:Connect(function(payload)
	State.race = payload
	State.inRace = table.find(payload.participants or {}, player.UserId) ~= nil
	if State.inRace and payload.mapId then
		LightingController.SetMap(payload.mapId)
	else
		LightingController.SetMap(nil)
	end
	State.Fire("Race", payload)
end)

Remotes.Event("CarAssigned").OnClientEvent:Connect(function(model, mode)
	-- Fall back to a lookup in case the model hadn't replicated yet.
	model = model or workspace:WaitForChild("Cars"):WaitForChild(player.Name .. "_Car", 5)
	if not model then
		return
	end
	if mode == "race" then
		HUD.CloseAll()
		Results.Hide()
	end
	task.spawn(CarController.Start, model, mode)
end)
Remotes.Event("CarRemoved").OnClientEvent:Connect(function()
	CarController.Stop()
end)

Remotes.Event("Countdown").OnClientEvent:Connect(RaceHUD.Countdown)
Remotes.Event("RaceUpdate").OnClientEvent:Connect(RaceHUD.Update)
Remotes.Event("Checkpoint").OnClientEvent:Connect(RaceHUD.OnCheckpoint)
Remotes.Event("RaceResults").OnClientEvent:Connect(Results.Show)

task.spawn(function()
	local ok, data = pcall(function()
		return Remotes.Func("GetData"):InvokeServer()
	end)
	if ok and data then
		State.queued = data.queued ~= false
		HUD.RefreshQueue()
		State.SetData(data)
		Notify.Show("Welcome to Redline Rush! Try code LAUNCH for free coins.", "info")
	end
end)

---------------------------------------------------------------------------
-- World effects: showroom turntables, rainbow underglow, garage prompts
---------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, model in CollectionService:GetTagged("Turntable") do
		local center = model:GetAttribute("Center")
		if center and model.PrimaryPart then
			model:PivotTo(CFrame.new(center) * CFrame.Angles(0, t * 0.4, 0))
		end
	end
	local color = Color3.fromHSV((t * 0.25) % 1, 1, 1)
	for _, part in CollectionService:GetTagged("RainbowGlow") do
		part.Color = color
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = color
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local carId = prompt:GetAttribute("CarId")
	if carId and not State.driving then
		HUD.OpenPanel("Garage", carId)
	end
end)
