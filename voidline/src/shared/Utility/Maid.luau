--!strict
--[[
	Maid
	Collects things that need cleaning up and releases them all at once.
	Use one Maid per lifetime (per player, per round, per UI screen) to avoid
	leaked connections and orphaned instances.

	    local maid = Maid.new()
	    maid:Give(part.Touched:Connect(onTouched))
	    maid:Give(Instance.new("Part"))
	    maid:Give(function() print("cleanup") end)
	    maid:Cleanup()

	Supported tasks: RBXScriptConnection, Instance, function, thread,
	or any table with a Destroy or Disconnect method (e.g. Signal connections).
]]

local Maid = {}
Maid.__index = Maid

type MaidData = { _tasks: { any } }
export type Maid = typeof(setmetatable({} :: MaidData, Maid))

function Maid.new(): Maid
	return setmetatable({ _tasks = {} }, Maid)
end

-- Adds a task and returns it, so construction and registration can be one line.
function Maid.Give<T>(self: Maid, task: T): T
	table.insert(self._tasks, task)
	return task
end

local function cleanTask(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		-- The thread may be running (cleanup from inside itself) or already dead.
		pcall(task.cancel, item)
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

-- Cleans tasks in reverse order of registration. Safe to call repeatedly.
function Maid.Cleanup(self: Maid)
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		local ok: boolean, err: any = pcall(cleanTask, tasks[i])
		if not ok then
			warn("[Maid] cleanup task failed:", err)
		end
	end
end

Maid.Destroy = Maid.Cleanup

return Maid
