-- Client-side shared state plus a tiny signal system.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local State = {
	data = nil, -- profile view from the server
	race = { phase = "Waiting", timeLeft = 0, votes = {}, typeVotes = {}, teamQueues = {}, freeDrive = {} },
	queued = true,
	myVote = nil,
	driving = false,
	driveMode = nil, -- "race" | "test"
}

local listeners = {}

function State.On(event, callback)
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], callback)
end

function State.Fire(event, ...)
	for _, callback in listeners[event] or {} do
		task.spawn(callback, ...)
	end
end

function State.SetData(data)
	if data then
		State.data = data
		State.Fire("Data", data)
	end
end

-- Invoke a server request: returns ok, messageOrResult.
function State.Request(action, ...)
	local ok, a, b = pcall(function(...)
		return Remotes.Func("Request"):InvokeServer(action, ...)
	end, ...)
	if not ok then
		return false, "Connection problem."
	end
	return a, b
end

return State
