--!strict
--[[
	ClientMain (bootstrap)
	The only client LocalScript. Mirrors the server bootstrap: require
	controllers in a fixed order, run Init then Start, then tell the server
	this client is ready.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Logger = require(Shared.Utility.Logger)

local Controllers = script.Parent:WaitForChild("Controllers")

local log = Logger.new("ClientMain")

-- Explicit order. Add new controllers here as phases land
-- (InteractionController, VoiceController, EffectsController, ...).
local CONTROLLER_ORDER = {
	"ClientController",
	"UIController",
}

type LoadedController = { Name: string, Module: Types.Lifecycle }

local bootStart = os.clock()
local loaded: { LoadedController } = {}

for _, name in CONTROLLER_ORDER do
	local moduleScript = Controllers:WaitForChild(name, 10)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		error(string.format("[ClientMain] Controller module %q not found", name))
	end
	table.insert(loaded, { Name = name, Module = require(moduleScript) :: Types.Lifecycle })
end

for _, phase in { "Init", "Start" } do
	for _, controller in loaded do
		local fn = (controller.Module :: any)[phase]
		if fn then
			local ok, err = pcall(fn)
			if not ok then
				error(string.format("[ClientMain] %s.%s failed: %s", controller.Name, phase, tostring(err)))
			end
		end
	end
end

require(Controllers.ClientController).SignalReady()

log:Info(string.format("Client ready in %.1f ms", (os.clock() - bootStart) * 1000))
