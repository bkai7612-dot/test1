--!strict
--[[
	StateMachine
	A deterministic finite state machine with an explicit transition table.
	Any transition not listed is rejected, which keeps the round flow from
	ever reaching an unexpected state.

	    local sm = StateMachine.new({ A = { "B" }, B = { "A" } }, "A")
	    sm:Transition("B") --> true
	    sm:Transition("C") --> false, "A->C not allowed" (state unchanged)
]]

local StateMachine = {}
StateMachine.__index = StateMachine

export type Listener = (newState: string, oldState: string) -> ()

type Data = {
	_state: string,
	_transitions: { [string]: { string } },
	_listeners: { Listener },
}
export type StateMachine = typeof(setmetatable({} :: Data, StateMachine))

function StateMachine.new(transitions: { [string]: { string } }, initial: string): StateMachine
	assert(transitions[initial], "Initial state must be in the transition table: " .. initial)
	return setmetatable({
		_state = initial,
		_transitions = transitions,
		_listeners = {},
	}, StateMachine)
end

function StateMachine.Get(self: StateMachine): string
	return self._state
end

function StateMachine.Is(self: StateMachine, ...: string): boolean
	for i = 1, select("#", ...) do
		if self._state == select(i, ...) then
			return true
		end
	end
	return false
end

function StateMachine.CanTransition(self: StateMachine, to: string): boolean
	local allowed = self._transitions[self._state]
	return allowed ~= nil and table.find(allowed, to) ~= nil
end

function StateMachine.Transition(self: StateMachine, to: string): (boolean, string?)
	if not self:CanTransition(to) then
		return false, string.format("%s->%s not allowed", self._state, to)
	end
	local old = self._state
	self._state = to
	for _, listener in table.clone(self._listeners) do
		listener(to, old)
	end
	return true
end

-- Listeners run synchronously, in registration order. Returns a disconnect function.
function StateMachine.OnChanged(self: StateMachine, listener: Listener): () -> ()
	table.insert(self._listeners, listener)
	return function()
		local index = table.find(self._listeners, listener)
		if index then
			table.remove(self._listeners, index)
		end
	end
end

return StateMachine
