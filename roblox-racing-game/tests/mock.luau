-- Minimal Roblox engine mock for smoke-testing game scripts outside Studio.
local G = {}
local now = 0
local errors = {}
G.errors = errors

---------------------------------------------------------------------------
-- Scheduler
---------------------------------------------------------------------------
local queue = {}
local function report(err, co)
	local msg = tostring(err)
	if co then
		msg = debug.traceback(co, msg)
	end
	table.insert(errors, msg)
	print("!! ERROR: " .. msg)
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		report(err, co)
	end
end
local task = {}
function task.spawn(fn, ...)
	local co = type(fn) == "thread" and fn or coroutine.create(fn)
	resume(co, ...)
	return co
end
function task.defer(fn, ...)
	table.insert(queue, { co = type(fn) == "thread" and fn or coroutine.create(fn), wake = now, args = table.pack(...) })
end
function task.delay(t, fn, ...)
	table.insert(queue, { co = coroutine.create(fn), wake = now + (t or 0), args = table.pack(...) })
end
function task.wait(t)
	local co = coroutine.running()
	table.insert(queue, { co = co, wake = now + (t or 0.03), args = table.pack() })
	coroutine.yield()
	return t or 0.03
end
function task.cancel() end
G.task = task

local os2 = setmetatable({
	clock = function()
		return now
	end,
	time = function()
		return 1700000000 + math.floor(now)
	end,
}, { __index = os })
G.os = os2

---------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ conns = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { fn = fn, Connected = true }
	function conn.Disconnect(c)
		c.Connected = false
	end
	table.insert(self.conns, conn)
	return conn
end
function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
function Signal:Fire(...)
	for _, conn in table.clone(self.conns) do
		if conn.Connected then
			task.spawn(conn.fn, ...)
		end
	end
end
function Signal:Wait()
	local co = coroutine.running()
	self:Once(function(...)
		task.spawn(co, ...)
	end)
	return coroutine.yield()
end
G.Signal = Signal

---------------------------------------------------------------------------
-- Datatypes
---------------------------------------------------------------------------
local function typed(name, mt)
	mt.__type = name
	return mt
end

local Vector3 = {}
local V3 = typed("Vector3", {})
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif k == "Cross" then
		return function(a, b)
			return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return a + (b - a) * t
		end
	end
	error("Vector3 has no member " .. tostring(k), 2)
end
V3.__add = function(a, b)
	assert(getmetatable(a) == V3 and getmetatable(b) == V3, "Vector3 add with non-Vector3")
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	assert(getmetatable(a) == V3 and getmetatable(b) == V3, "Vector3 sub with non-Vector3")
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	assert(getmetatable(b) == V3, "Vector3 mul with bad type")
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(v)
	return string.format("%.2f, %.2f, %.2f", v.X, v.Y, v.Z)
end
Vector3.new = v3
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
G.Vector3 = Vector3

local Vector2 = {}
local V2 = typed("Vector2", {})
V2.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	end
	error("Vector2 has no member " .. tostring(k), 2)
end
V2.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
G.Vector2 = Vector2

-- CFrame: p + 3x3 rotation (columns = right, up, back)
local CFrame = {}
local CF = typed("CFrame", {})
local function cf(p, m)
	return setmetatable({ p = p, m = m }, CF)
end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mulM(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end
local function mulMV(m, v)
	return v3(m[1] * v.X + m[2] * v.Y + m[3] * v.Z, m[4] * v.X + m[5] * v.Y + m[6] * v.Z, m[7] * v.X + m[8] * v.Y + m[9] * v.Z)
end
local function transpose(m)
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end
local function fromCols(x, y, z)
	return { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z }
end
CF.__index = function(c, k)
	local m = c.m
	if k == "Position" then
		return c.p
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "RightVector" then
		return v3(m[1], m[4], m[7])
	elseif k == "UpVector" then
		return v3(m[2], m[5], m[8])
	elseif k == "LookVector" then
		return v3(-m[3], -m[6], -m[9])
	elseif k == "Rotation" then
		return cf(v3(), m)
	elseif k == "Inverse" then
		return function(self)
			local t = transpose(self.m)
			return cf(-mulMV(t, self.p), t)
		end
	elseif k == "PointToObjectSpace" then
		return function(self, v)
			return mulMV(transpose(self.m), v - self.p)
		end
	elseif k == "PointToWorldSpace" then
		return function(self, v)
			return self.p + mulMV(self.m, v)
		end
	elseif k == "VectorToWorldSpace" then
		return function(self, v)
			return mulMV(self.m, v)
		end
	elseif k == "VectorToObjectSpace" then
		return function(self, v)
			return mulMV(transpose(self.m), v)
		end
	elseif k == "ToObjectSpace" then
		return function(self, o)
			return self:Inverse() * o
		end
	elseif k == "Lerp" then
		return function(self, o, t)
			return cf(self.p:Lerp(o.p, t), t < 0.5 and self.m or o.m)
		end
	end
	error("CFrame has no member " .. tostring(k), 2)
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		return a.p + mulMV(a.m, b)
	end
	assert(getmetatable(b) == CF, "CFrame * bad type")
	return cf(a.p + mulMV(a.m, b.p), mulM(a.m, b.m))
end
CF.__add = function(a, b)
	assert(getmetatable(b) == V3, "CFrame + non-Vector3")
	return cf(a.p + b, a.m)
end
CF.__sub = function(a, b)
	return cf(a.p - b, a.m)
end
CF.__tostring = function(c)
	return "CFrame(" .. tostring(c.p) .. ")"
end
function CFrame.new(a, b, c)
	if a == nil then
		return cf(v3(), IDENT)
	elseif type(a) == "number" then
		return cf(v3(a, b, c), IDENT)
	elseif b ~= nil then
		return CFrame.lookAt(a, b)
	end
	assert(getmetatable(a) == V3, "CFrame.new bad arg")
	return cf(a, IDENT)
end
function CFrame.lookAt(pos, target, up)
	up = up or Vector3.yAxis
	local look = (target - pos).Unit
	local right = look:Cross(up).Unit
	local up2 = right:Cross(look)
	return cf(pos, fromCols(right, up2, -look))
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy).Unit
	return cf(pos, fromCols(vx, vy, vz))
end
function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(v3(), mulM(mulM(Rx, Ry), Rz))
end
G.CFrame = CFrame

local Color3 = {}
local C3 = typed("Color3", {})
C3.__index = function(c, k)
	if k == "Lerp" then
		return function(a, b, t)
			return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end
	end
	error("Color3 has no member " .. tostring(k), 2)
end
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
function Color3.fromHSV(h, s, v)
	return Color3.new(v, v * (1 - s * h), v)
end
G.Color3 = Color3

local function simpleType(name, ctor)
	local mt = typed(name, {})
	mt.__index = function(_, k)
		error(name .. " has no member " .. tostring(k), 2)
	end
	return function(...)
		return setmetatable(ctor(...), mt)
	end
end
G.UDim = { new = simpleType("UDim", function(s, o)
	return { Scale = s or 0, Offset = o or 0 }
end) }
local udim2 = simpleType("UDim2", function(xs, xo, ys, yo)
	return { X = G.UDim.new(xs, xo), Y = G.UDim.new(ys, yo), Width = G.UDim.new(xs, xo), Height = G.UDim.new(ys, yo) }
end)
G.UDim2 = {
	new = udim2,
	fromScale = function(x, y)
		return udim2(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		return udim2(0, x, 0, y)
	end,
}
local function passthrough(name)
	return {
		new = simpleType(name, function(...)
			return { args = { ... } }
		end),
	}
end
G.ColorSequence = passthrough("ColorSequence")
G.ColorSequenceKeypoint = passthrough("ColorSequenceKeypoint")
G.NumberSequence = passthrough("NumberSequence")
G.NumberSequenceKeypoint = passthrough("NumberSequenceKeypoint")
G.NumberRange = passthrough("NumberRange")
G.PhysicalProperties = passthrough("PhysicalProperties")
G.TweenInfo = passthrough("TweenInfo")
G.RaycastParams = {
	new = function()
		return { FilterType = nil, FilterDescendantsInstances = {} }
	end,
}
local RandomMT = typed("Random", {})
RandomMT.__index = {
	NextNumber = function(self, a, b)
		self.s = (self.s * 1103515245 + 12345) % 2147483648
		local r = self.s / 2147483648
		if a then
			return a + (b - a) * r
		end
		return r
	end,
	NextInteger = function(self, a, b)
		return math.floor(self:NextNumber(a, b + 1 - 1e-9))
	end,
}
G.Random = {
	new = function(seed)
		return setmetatable({ s = (seed or 1) % 2147483648 }, RandomMT)
	end,
}

G.Enum = setmetatable({}, {
	__index = function(t, enumName)
		local e = setmetatable({}, {
			__index = function(e, item)
				local v = { Name = item, Value = 0, EnumType = enumName }
				rawset(e, item, v)
				return v
			end,
		})
		rawset(t, enumName, e)
		return e
	end,
})

function G.typeof(v)
	local mt = getmetatable(v)
	if type(mt) == "table" and mt.__type then
		return mt.__type
	end
	return typeof(v)
end
function G.warn(...)
	print("[warn]", ...)
end

---------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------
local PARENTS = {
	Part = "BasePart",
	WedgePart = "BasePart",
	Seat = "Part",
	SpawnLocation = "Part",
	BasePart = "PVInstance",
	Model = "PVInstance",
	Workspace = "Model",
	Frame = "GuiObject",
	TextLabel = "GuiObject",
	TextButton = "GuiButton",
	GuiButton = "GuiObject",
	TextBox = "GuiObject",
	ScrollingFrame = "GuiObject",
	ViewportFrame = "GuiObject",
	GuiObject = "GuiBase2d",
	ScreenGui = "LayerCollector",
	SurfaceGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	PointLight = "Light",
	SpotLight = "Light",
	IntValue = "ValueBase",
	Script = "LuaSourceContainer",
	LocalScript = "Script",
	ModuleScript = "LuaSourceContainer",
	UICorner = "UIComponent",
	UIStroke = "UIComponent",
	UIScale = "UIComponent",
}
local EVENTS = {
	Activated = true,
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Click = true,
	InputBegan = true,
	InputEnded = true,
	FocusLost = true,
	AncestryChanged = true,
	ChildAdded = true,
	Died = true,
	Triggered = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	Heartbeat = true,
	RenderStepped = true,
	Stepped = true,
	CharacterAdded = true,
	OnClientEvent = true,
	OnServerEvent = true,
	Event = true,
	PromptTriggered = true,
	PromptGamePassPurchaseFinished = true,
	Touched = true,
	InputChanged = true,
}

local function isA(className, target)
	if target == "Instance" then
		return true
	end
	local c = className
	while c do
		if c == target then
			return true
		end
		c = PARENTS[c]
	end
	return false
end

local Instance = {}
local IMT = {}
local methods = {}
local classMethods = {}
local tags = {}

local function props(self)
	return rawget(self, "__p")
end
local function lazy(self, key)
	local t = rawget(self, key)
	if not t then
		t = {}
		rawset(self, key, t)
	end
	return t
end

local function newInstance(className)
	local self = setmetatable({}, IMT)
	rawset(self, "__p", { ClassName = className, Name = className })
	rawset(self, "__children", {})
	local p = props(self)
	if isA(className, "BasePart") then
		p.Size = v3(4, 1, 2)
		p.CFrame = CFrame.new()
		p.Anchored = false
		p.CanCollide = true
		p.CanQuery = true
		p.AssemblyLinearVelocity = v3()
		p.AssemblyAngularVelocity = v3()
		p.Transparency = 0
	elseif className == "Humanoid" then
		p.Health = 100
	elseif className == "Camera" then
		p.CFrame = CFrame.new()
		p.FieldOfView = 70
		p.ViewportSize = Vector2.new(1280, 720)
	elseif isA(className, "GuiObject") then
		p.Visible = true
		p.Size = G.UDim2.new(0, 0, 0, 0)
		p.BackgroundColor3 = Color3.new()
	elseif className == "IntValue" then
		p.Value = 0
	end
	return self
end

local function fireProp(self, key)
	local sig = lazy(self, "__psig")[key]
	if sig then
		sig:Fire()
	end
end

local function descendants(self, out)
	for _, c in rawget(self, "__children") do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end

local function fireAncestry(self)
	local s = lazy(self, "__sig").AncestryChanged
	if s then
		s:Fire()
	end
	for _, c in rawget(self, "__children") do
		fireAncestry(c)
	end
end

IMT.__type = "Instance"
IMT.__tostring = function(self)
	return props(self).Name
end
IMT.__index = function(self, key)
	local p = props(self)
	local cm = classMethods[p.ClassName]
	if cm and cm[key] then
		return cm[key]
	end
	if methods[key] then
		return methods[key]
	end
	local v = p[key]
	if v ~= nil then
		return v
	end
	if key == "Position" and p.CFrame then
		return p.CFrame.Position
	end
	if key == "AssemblyMass" then
		return 200
	end
	if EVENTS[key] then
		local s = lazy(self, "__sig")[key]
		if not s then
			s = Signal.new()
			lazy(self, "__sig")[key] = s
		end
		return s
	end
	for _, c in rawget(self, "__children") do
		if props(c).Name == key then
			return c
		end
	end
	return nil
end
IMT.__newindex = function(self, key, value)
	local p = props(self)
	if key == "Parent" then
		local old = p.Parent
		if old == value then
			return
		end
		if old then
			local list = rawget(old, "__children")
			local idx = table.find(list, self)
			if idx then
				table.remove(list, idx)
			end
		end
		p.Parent = value
		if value then
			table.insert(rawget(value, "__children"), self)
			local s = lazy(value, "__sig").ChildAdded
			if s then
				s:Fire(self)
			end
		end
		fireAncestry(self)
		return
	end
	if key == "Position" and p.CFrame then
		p.CFrame = p.CFrame - p.CFrame.Position + value
		return
	end
	if key == "Shape" and value.Name == "Cylinder" then
		p.Shape = value
		return
	end
	p[key] = value
	fireProp(self, key)
end

function methods.GetService(self, name)
	return self[name]
end
function methods.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "__children") do
		if props(c).Name == name then
			return c
		end
	end
	if recursive then
		for _, d in descendants(self, {}) do
			if props(d).Name == name then
				return d
			end
		end
	end
	return nil
end
function methods.WaitForChild(self, name)
	local c = methods.FindFirstChild(self, name)
	if c then
		return c
	end
	for _ = 1, 200 do
		task.wait(0.05)
		c = methods.FindFirstChild(self, name)
		if c then
			return c
		end
	end
	error("WaitForChild timed out: " .. tostring(self) .. "." .. name, 2)
end
function methods.FindFirstChildOfClass(self, className)
	for _, c in rawget(self, "__children") do
		if props(c).ClassName == className then
			return c
		end
	end
	return nil
end
function methods.GetChildren(self)
	return table.clone(rawget(self, "__children"))
end
function methods.GetDescendants(self)
	return descendants(self, {})
end
function methods.IsA(self, className)
	return isA(props(self).ClassName, className)
end
function methods.IsDescendantOf(self, other)
	local p = props(self).Parent
	while p do
		if p == other then
			return true
		end
		p = props(p).Parent
	end
	return false
end
function methods.Destroy(self)
	local p = props(self)
	if p.Name == "SeatWeld" and p.Parent and props(p.Parent).ClassName == "Seat" then
		local seat = p.Parent
		local hum = props(seat).Occupant
		self.Parent = nil
		seat.Occupant = nil
		if hum then
			hum.SeatPart = nil
		end
		return
	end
	for _, c in table.clone(rawget(self, "__children")) do
		c:Destroy()
	end
	self.Parent = nil
	rawset(self, "__destroyed", true)
end
function methods.SetAttribute(self, key, value)
	local t = G.typeof(value)
	assert(
		value == nil or t == "number" or t == "string" or t == "boolean" or t == "Vector3" or t == "Color3" or t == "CFrame",
		"bad attribute type " .. t
	)
	lazy(self, "__attrs")[key] = value
end
function methods.GetAttribute(self, key)
	return lazy(self, "__attrs")[key]
end
function methods.GetPropertyChangedSignal(self, key)
	local s = lazy(self, "__psig")[key]
	if not s then
		s = Signal.new()
		lazy(self, "__psig")[key] = s
	end
	return s
end
function methods.GetPivot(self)
	local p = props(self)
	if p.CFrame then
		return p.CFrame
	end
	if p.PrimaryPart then
		return p.PrimaryPart.CFrame
	end
	for _, d in descendants(self, {}) do
		if d:IsA("BasePart") then
			return d.CFrame
		end
	end
	return CFrame.new()
end
function methods.PivotTo(self, target)
	assert(G.typeof(target) == "CFrame", "PivotTo expects CFrame")
	local p = props(self)
	if p.CFrame then
		self.CFrame = target
		return
	end
	local delta = target * methods.GetPivot(self):Inverse()
	for _, d in descendants(self, {}) do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end
function methods.SetNetworkOwner(self, _player)
	if self.Anchored then
		error("Network Ownership API cannot be called on Anchored parts", 2)
	end
end
function methods.ApplyImpulse(self, impulse)
	assert(G.typeof(impulse) == "Vector3")
	self.AssemblyLinearVelocity = self.AssemblyLinearVelocity + impulse / 200
end
function methods.ApplyImpulseAtPosition(self, impulse, pos)
	assert(G.typeof(impulse) == "Vector3" and G.typeof(pos) == "Vector3")
	self.AssemblyLinearVelocity = self.AssemblyLinearVelocity + impulse / 200
end
function methods.GetVelocityAtPosition(self, pos)
	assert(G.typeof(pos) == "Vector3")
	return self.AssemblyLinearVelocity
end
function methods.Play() end
function methods.Stop() end
function methods.SetStateEnabled() end
function methods.Clone(self)
	error("Clone not mocked")
end

classMethods.Seat = {
	Sit = function(self, humanoid)
		assert(humanoid:IsA("Humanoid"))
		if props(self).Occupant then
			return
		end
		local weld = newInstance("Weld")
		weld.Name = "SeatWeld"
		weld.Parent = self
		humanoid.SeatPart = self
		self.Occupant = humanoid
	end,
}

local KNOWN_CLASSES = {}
for _, name in string.split(
	"Part WedgePart Seat SpawnLocation Model Folder Weld WeldConstraint Humanoid Camera Frame TextLabel TextButton "
		.. "TextBox ScrollingFrame ViewportFrame ScreenGui SurfaceGui BillboardGui PointLight SpotLight IntValue "
		.. "ParticleEmitter SpecialMesh UICorner UIStroke UIScale UIPadding UIListLayout UIGridLayout UIGradient "
		.. "UITextSizeConstraint UISizeConstraint Sound Atmosphere Fire ProximityPrompt RemoteEvent RemoteFunction "
		.. "BindableEvent Player PlayerGui Script LocalScript ModuleScript Trail Attachment",
	" "
) do
	KNOWN_CLASSES[name] = true
end
Instance.new = function(className, parent)
	assert(KNOWN_CLASSES[className], "Instance.new: unknown class " .. tostring(className))
	local inst = newInstance(className)
	if parent then
		inst.Parent = parent
	end
	return inst
end
G.Instance = Instance
G.newInstance = newInstance

---------------------------------------------------------------------------
-- DataModel & services
---------------------------------------------------------------------------
local game = newInstance("DataModel")
game.Name = "Game"
local function service(className)
	local s = newInstance(className)
	s.Name = className
	s.Parent = game
	return s
end
local workspace = service("Workspace")
workspace.Gravity = 196.2
local camera = newInstance("Camera")
camera.Parent = workspace
workspace.CurrentCamera = camera
G.groundY = 0
classMethods.Workspace = {
	Raycast = function(self, origin, dir, params)
		assert(G.typeof(origin) == "Vector3" and G.typeof(dir) == "Vector3")
		assert(params == nil or type(params) == "table")
		local gy = G.groundY
		if dir.Y < 0 and origin.Y >= gy and origin.Y + dir.Y <= gy then
			local t = (origin.Y - gy) / -dir.Y
			local dist = dir.Magnitude * t
			return { Distance = dist, Position = origin + dir * t, Normal = Vector3.yAxis, Instance = workspace }
		end
		return nil
	end,
}

local Players = service("Players")
classMethods.Players = {
	GetPlayers = function(self)
		local out = {}
		for _, c in rawget(self, "__children") do
			if c.ClassName == "Player" then
				table.insert(out, c)
			end
		end
		return out
	end,
	GetPlayerByUserId = function(self, id)
		for _, c in rawget(self, "__children") do
			if c.ClassName == "Player" and c.UserId == id then
				return c
			end
		end
		return nil
	end,
	GetNameFromUserIdAsync = function(_, id)
		return "User" .. id
	end,
}

local function makeCharacter(player)
	local char = newInstance("Model")
	char.Name = player.Name
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(0, 3, 55)
	root.Parent = char
	char.PrimaryPart = root
	local hum = newInstance("Humanoid")
	hum.Parent = char
	char.Parent = workspace
	return char
end

classMethods.Player = {
	LoadCharacter = function(self)
		if self.Character then
			self.Character:Destroy()
		end
		local char = makeCharacter(self)
		self.Character = char
		self.CharacterAdded:Fire(char)
	end,
	Kick = function() end,
}

local RunService = service("RunService")
G.isServer = true
local renderBinds = {}
classMethods.RunService = {
	IsServer = function()
		return G.isServer
	end,
	IsClient = function()
		return not G.isServer
	end,
	IsStudio = function()
		return true
	end,
	BindToRenderStep = function(_, name, _prio, fn)
		renderBinds[name] = fn
	end,
	UnbindFromRenderStep = function(_, name)
		renderBinds[name] = nil
	end,
}

local memStore = {}
local DataStoreService = service("DataStoreService")
G.dataStoreFails = false
local function makeStore(name)
	memStore[name] = memStore[name] or {}
	local data = memStore[name]
	return {
		GetAsync = function(_, key)
			return data[key]
		end,
		SetAsync = function(_, key, value)
			data[key] = value
		end,
		UpdateAsync = function(_, key, fn)
			local result = fn(data[key])
			if result ~= nil then
				data[key] = result
			end
			return data[key]
		end,
		GetSortedAsync = function(_, _asc, n)
			local list = {}
			for k, v in data do
				table.insert(list, { key = k, value = v })
			end
			return {
				GetCurrentPage = function()
					return list
				end,
			}
		end,
	}
end
classMethods.DataStoreService = {
	GetDataStore = function(_, name)
		if G.dataStoreFails then
			error("Studio API access disabled")
		end
		return makeStore(name)
	end,
	GetOrderedDataStore = function(_, name)
		return makeStore("ordered_" .. name)
	end,
}
G.memStore = memStore

service("ReplicatedStorage")
service("ServerScriptService")
service("StarterPlayer")
service("SoundService")
service("Lighting")
service("GuiService")
service("StarterGui")
service("ProximityPromptService")
local CollectionService = service("CollectionService")
classMethods.CollectionService = {
	AddTag = function(_, inst, tag)
		tags[tag] = tags[tag] or {}
		tags[tag][inst] = true
	end,
	RemoveTag = function(_, inst, tag)
		if tags[tag] then
			tags[tag][inst] = nil
		end
	end,
	GetTagged = function(_, tag)
		local out = {}
		for inst in tags[tag] or {} do
			if not rawget(inst, "__destroyed") then
				table.insert(out, inst)
			end
		end
		return out
	end,
}
classMethods.StarterGui = {
	SetCore = function() end,
	SetCoreGuiEnabled = function() end,
}
local TweenService = service("TweenService")
classMethods.TweenService = {
	Create = function(_, inst, _info, goal)
		return {
			Play = function()
				for k, v in goal do
					inst[k] = v
				end
			end,
		}
	end,
}
classMethods.SoundService = { PlayLocalSound = function() end }
local UIS = service("UserInputService")
G.keys = {}
classMethods.UserInputService = {
	IsKeyDown = function(_, key)
		return G.keys[key.Name] == true
	end,
	GetFocusedTextBox = function()
		return nil
	end,
	GetGamepadConnected = function()
		return false
	end,
	GetGamepadState = function()
		return {}
	end,
	IsGamepadButtonDown = function()
		return false
	end,
}
UIS.TouchEnabled = false
local CAS = service("ContextActionService")
classMethods.ContextActionService = {
	BindAction = function() end,
	BindActionAtPriority = function() end,
	UnbindAction = function() end,
}
local Marketplace = service("MarketplaceService")
G.prompts = {}
classMethods.MarketplaceService = {
	PromptProductPurchase = function(_, player, id)
		table.insert(G.prompts, { player = player, id = id })
	end,
	PromptGamePassPurchase = function(_, player, id)
		table.insert(G.prompts, { player = player, id = id, pass = true })
	end,
	UserOwnsGamePassAsync = function()
		return false
	end,
	GetProductInfo = function()
		return { PriceInRobux = 42 }
	end,
}

classMethods.DataModel = {
	BindToClose = function(_, fn)
		G.closeFn = fn
	end,
}

classMethods.RemoteEvent = {
	FireClient = function(self, player, ...)
		assert(player and player.ClassName == "Player", "FireClient needs a player")
		-- Only the local test player has a client in this VM.
		if player == G.localPlayer then
			self.OnClientEvent:Fire(...)
		end
	end,
	FireAllClients = function(self, ...)
		self.OnClientEvent:Fire(...)
	end,
	FireServer = function(self, ...)
		self.OnServerEvent:Fire(G.localPlayer, ...)
	end,
}
classMethods.RemoteFunction = {
	InvokeServer = function(self, ...)
		local fn = self.OnServerInvoke
		assert(fn, "no OnServerInvoke")
		return fn(G.localPlayer, ...)
	end,
}
classMethods.BindableEvent = {
	Fire = function(self, ...)
		self.Event:Fire(...)
	end,
}

G.game = game
G.workspace = workspace
G.renderBinds = renderBinds

function G.makePlayer(name, userId)
	local player = newInstance("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = userId
	local gui = newInstance("PlayerGui")
	gui.Name = "PlayerGui"
	gui.Parent = player
	player.Parent = Players
	return player
end

function G.advance(dt)
	now += dt
	RunService.Heartbeat:Fire(dt)
	RunService.RenderStepped:Fire(dt)
	for _, fn in renderBinds do
		task.spawn(fn, dt)
	end
	for _ = 1, 50 do
		local ready = {}
		local rest = {}
		for _, e in queue do
			if e.wake <= now then
				table.insert(ready, e)
			else
				table.insert(rest, e)
			end
		end
		queue = rest
		if #ready == 0 then
			break
		end
		for _, e in ready do
			if coroutine.status(e.co) == "suspended" then
				resume(e.co, table.unpack(e.args, 1, e.args.n))
			end
		end
	end
end
function G.run(seconds, step)
	step = step or 0.1
	local t = 0
	while t < seconds do
		G.advance(step)
		t += step
	end
end
function G.now()
	return now
end
function G.countParts(root)
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return G
