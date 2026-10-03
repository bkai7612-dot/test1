--!strict
--[[
	Signal
	Lightweight script-side event, used for service-to-service communication
	without BindableEvents (which deep-copy tables and lose metatables).

	    local changed = Signal.new()
	    local conn = changed:Connect(function(a, b) ... end)
	    changed:Fire(1, 2)
	    conn:Disconnect()

	Handlers run via task.spawn, so a yielding or erroring handler does not
	block or break the others.
]]

local Connection = {}
Connection.__index = Connection

local Signal = {}
Signal.__index = Signal

type SignalData = { _handlers: { any } }
export type Signal = typeof(setmetatable({} :: SignalData, Signal))

type ConnectionData = {
	Connected: boolean,
	_signal: Signal,
	_fn: (...any) -> (),
}
export type Connection = typeof(setmetatable({} :: ConnectionData, Connection))

function Connection.Disconnect(self: Connection)
	if not self.Connected then
		return
	end
	self.Connected = false
	local handlers = self._signal._handlers
	local index = table.find(handlers, self)
	if index then
		table.remove(handlers, index)
	end
end

-- Alias so Maid can clean connections up uniformly.
Connection.Destroy = Connection.Disconnect

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Signal, fn: (...any) -> ()): Connection
	local connection: Connection = setmetatable({
		Connected = true,
		_signal = self,
		_fn = fn,
	}, Connection)
	table.insert(self._handlers, connection)
	return connection
end

function Signal.Once(self: Signal, fn: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	-- Iterate a snapshot so handlers may connect/disconnect while firing.
	for _, connection in table.clone(self._handlers) do
		local c = connection :: Connection
		if c.Connected then
			task.spawn(c._fn, ...)
		end
	end
end

-- Yields until the next Fire and returns its arguments.
function Signal.Wait(self: Signal): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: Signal)
	for _, connection in self._handlers do
		(connection :: Connection).Connected = false
	end
	table.clear(self._handlers)
end

Signal.Destroy = Signal.DisconnectAll

return Signal
