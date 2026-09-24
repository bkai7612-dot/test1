-- Creates (server) or fetches (client) every RemoteEvent / RemoteFunction.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"DataUpdated", -- server -> client: player profile view
	"RaceState", -- server -> all: phase, timer, votes
	"RaceUpdate", -- server -> racer: position, lap, standings
	"Checkpoint", -- server -> racer: checkpoint / lap / finish
	"Countdown", -- server -> racer: 3, 2, 1, 0 (GO)
	"RaceResults", -- server -> racers: final results
	"CarAssigned", -- server -> player: (carModel, mode)
	"CarRemoved", -- server -> player
	"Notify", -- server -> player: (text, kind)
}

local FUNCTIONS = {
	"Request", -- client -> server: (action, ...) -> (ok, message/result)
	"GetData", -- client -> server: initial profile view
}

local Remotes = {}
local folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

function Remotes.Event(name)
	return folder:WaitForChild(name)
end

function Remotes.Func(name)
	return folder:WaitForChild(name)
end

return Remotes
