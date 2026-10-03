--!strict
--[[
	SettingsController
	Holds the local player's settings, applies the ones that map directly to
	engine values, and saves changes to the server (debounced). Other
	controllers listen to Changed for anything they own (volume, UI scale...).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local SettingsSchema = require(Shared.Data.SettingsSchema)
local Signal = require(Shared.Utility.Signal)

local ClientController = require(script.Parent.ClientController)

local SettingsController = {}

-- (key, value)
SettingsController.Changed = Signal.new()

local values: { [string]: any } = table.clone(SettingsSchema.Defaults)
local loadedFromProfile = false
local pendingSave: { [string]: any } = {}
local saveScheduled = false

local function applyEngine(key: string, value: any)
	if key == "Sensitivity" then
		pcall(function()
			UserInputService.MouseDeltaSensitivity = value
		end)
	end
end

local function flush()
	saveScheduled = false
	local remote = Net.getEvent(Net.Names.SaveSetting)
	for key, value in pendingSave do
		remote:FireServer(key, value)
	end
	table.clear(pendingSave)
end

function SettingsController.Get(key: string): any
	return values[key]
end

function SettingsController.Set(key: string, value: any)
	local clean = SettingsSchema.sanitize(key, value)
	if clean == nil or values[key] == clean then
		return
	end
	values[key] = clean
	applyEngine(key, clean)
	SettingsController.Changed:Fire(key, clean)
	pendingSave[key] = clean
	if not saveScheduled then
		saveScheduled = true
		task.delay(0.75, flush)
	end
end

function SettingsController.Init()
	ClientController.PrivateChanged:Connect(function(key: string, profile: any)
		if key ~= Constants.PrivateKey.Profile or type(profile) ~= "table" or loadedFromProfile then
			return
		end
		loadedFromProfile = true
		if type(profile.Settings) == "table" then
			for settingKey, value in profile.Settings do
				local clean = SettingsSchema.sanitize(settingKey, value)
				if clean ~= nil and values[settingKey] ~= clean then
					values[settingKey] = clean
					applyEngine(settingKey, clean)
					SettingsController.Changed:Fire(settingKey, clean)
				end
			end
		end
	end)
end

function SettingsController.Start()
	for key, value in values do
		applyEngine(key, value)
	end
end

return SettingsController
