--!strict
--[[
	Create
	Declarative instance builder used by every screen:

	    Create("TextButton", {
	        Text = "Ready",
	        Size = UDim2.fromOffset(120, 36),
	        OnActivated = function() ... end,   -- "On<Event>" connects a signal
	        Parent = frame,
	    }, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })

	Parent is applied last so the instance is fully configured before it
	replicates into the rendered tree.
]]

local function Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			elseif string.sub(key, 1, 2) == "On" and type(value) == "function" then
				((instance :: any)[string.sub(key, 3)] :: RBXScriptSignal):Connect(value)
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

return Create
