-- Server entry point: builds the world, starts every service and routes
-- client requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local CarService = require(script.Parent.CarService)
local ShopService = require(script.Parent.ShopService)
local RaceService = require(script.Parent.RaceService)
local LobbyBuilder = require(script.Parent.LobbyBuilder)

Players.RespawnTime = 2

LobbyBuilder.Build()
DataService.Init()
CarService.Init()
ShopService.Init()
RaceService.Init()

---------------------------------------------------------------------------
-- Request routing
---------------------------------------------------------------------------
local handlers = {}
for name, fn in ShopService.Handlers do
	handlers[name] = fn
end

function handlers.SetQueue(player, value)
	return RaceService.SetQueued(player, value == true)
end

function handlers.Vote(player, mapId)
	return RaceService.Vote(player, mapId)
end

function handlers.TestDrive(player)
	if RaceService.IsRacing(player) then
		return false, "You're in a race!"
	end
	local model = CarService.Spawn(player, LobbyBuilder.GetTestSpawn(), "test", false, { KillY = -60 })
	if not model then
		return false, "Couldn't spawn your car. Try again in a moment."
	end
	return true
end

function handlers.ExitCar(player)
	local _, mode = CarService.Get(player)
	if mode ~= "test" then
		return false, "You can't leave your car during a race."
	end
	CarService.Despawn(player)
	return true
end

function handlers.Respawn(player)
	local model, mode = CarService.Get(player)
	if not model then
		return false
	end
	if mode == "race" then
		return true, RaceService.GetRespawn(player)
	end
	return true, LobbyBuilder.GetTestSpawn()
end

local lastRequest = {}
Remotes.Func("Request").OnServerInvoke = function(player, action, ...)
	local handler = type(action) == "string" and handlers[action]
	if not handler then
		return false, "Unknown request."
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.08 then
		return false, "Slow down!"
	end
	lastRequest[player] = now
	if not DataService.Get(player) then
		return false, "Your data is still loading."
	end
	local ok, result, extra = pcall(handler, player, ...)
	if not ok then
		warn("[Request]", action, "failed:", result)
		return false, "Something went wrong."
	end
	return result, extra
end

Remotes.Func("GetData").OnServerInvoke = function(player)
	DataService.WaitFor(player, 30)
	local view = DataService.View(player)
	if view then
		view.queued = RaceService.IsQueued(player)
	end
	return view
end

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

---------------------------------------------------------------------------
-- Global leaderboard refresh
---------------------------------------------------------------------------
task.spawn(function()
	while true do
		local ok, entries = pcall(DataService.GetTopWins, 10)
		if ok then
			LobbyBuilder.SetLeaderboard(entries)
		end
		task.wait(90)
	end
end)
