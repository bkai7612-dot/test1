--[[
	FakeRoblox
	A small, deliberately simple emulation of the Roblox engine APIs that
	VOIDLINE's *server* code uses, so the real server modules can boot and be
	driven headlessly under Lune. Datatypes (Vector3, CFrame, Enum, ...) are
	Lune's real implementations; instances, signals and services are fakes.

	It is not a physics engine: parts don't move by themselves, raycasts hit
	nothing, and characters only move when a test sets their CFrame.
]]

local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local Fake = {}

---------------------------------------------------------------------------
-- Signal
---------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local connection = { Connected = true }
	local handlers = self._handlers
	function connection.Disconnect()
		connection.Connected = false
		local index = table.find(handlers, connection)
		if index then
			table.remove(handlers, index)
		end
	end
	connection._fn = fn
	table.insert(handlers, connection)
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	for _, connection in table.clone(self._handlers) do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

Fake.Signal = Signal

---------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------
local PARENT_CLASS = {
	Part = "BasePart",
	SpawnLocation = "Part",
	WedgePart = "BasePart",
	CornerWedgePart = "BasePart",
	TrussPart = "BasePart",
	MeshPart = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	Workspace = "Model",
	PVInstance = "Instance",
	TextLabel = "GuiObject",
	TextButton = "GuiButton",
	TextBox = "GuiObject",
	ImageLabel = "GuiObject",
	GuiButton = "GuiObject",
	Frame = "GuiObject",
	GuiObject = "GuiBase2d",
	SurfaceGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	ScreenGui = "LayerCollector",
	LayerCollector = "GuiBase2d",
	PointLight = "Light",
	SpotLight = "Light",
	SurfaceLight = "Light",
	ObjectValue = "ValueBase",
	BloomEffect = "PostEffect",
	ColorCorrectionEffect = "PostEffect",
	BlurEffect = "PostEffect",
	SunRaysEffect = "PostEffect",
	DepthOfFieldEffect = "PostEffect",
	Script = "BaseScript",
	LocalScript = "BaseScript",
	ModuleScript = "LuaSourceContainer",
	BaseScript = "LuaSourceContainer",
}

local EVENT_NAMES = {
	Destroying = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	Changed = true,
	AttributeChanged = true,
	AncestryChanged = true,
	Died = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	OnServerEvent = true,
	Touched = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	Heartbeat = true,
	Stepped = true,
	PromptGamePassPurchaseFinished = true,
	Completed = true,
	-- client-side events
	Activated = true,
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Click = true,
	SelectionGained = true,
	SelectionLost = true,
	InputBegan = true,
	InputEnded = true,
	InputChanged = true,
	Triggered = true,
	PromptButtonHoldBegan = true,
	PromptButtonHoldEnded = true,
	OnClientEvent = true,
	RenderStepped = true,
	Focused = true,
	FocusLost = true,
}

local InstanceMeta = {}
local Methods = {}
local registry = setmetatable({}, { __mode = "k" })

function Fake.isInstance(value)
	return type(value) == "table" and registry[value] == true
end

local function isA(className, target)
	local current = className
	while current do
		if current == target then
			return true
		end
		current = PARENT_CLASS[current]
	end
	return target == "Instance"
end

local function defaultProps(className)
	local props = { Name = className, ClassName = className, Archivable = true }
	if isA(className, "BasePart") then
		props.Size = Vector3.new(4, 1, 2)
		props.CFrame = CFrame.new()
		props.Anchored = false
		props.CanCollide = true
		props.CanQuery = true
		props.CanTouch = true
		props.Transparency = 0
		props.Massless = false
		props.AssemblyMass = 1
		props.Color = roblox.Color3.new(0.6, 0.6, 0.6)
	end
	if className == "Humanoid" then
		props.Health = 100
		props.MaxHealth = 100
		props.WalkSpeed = 16
		props.JumpHeight = 7.2
		props.MoveDirection = Vector3.zero
		props.UseJumpPower = true
	end
	if className == "Model" or className == "Workspace" then
		props.PrimaryPart = nil
	end
	if isA(className, "GuiObject") then
		props.Visible = true
		props.Active = true
		props.AbsolutePosition = roblox.Vector2.zero
		props.AbsoluteSize = roblox.Vector2.new(200, 40)
		props.Selectable = false
		props.LayoutOrder = 0
	end
	if isA(className, "LayerCollector") or className == "ProximityPrompt" or isA(className, "Light") or isA(className, "PostEffect") then
		props.Enabled = true
	end
	if className == "ProximityPrompt" then
		props.HoldDuration = 0
		props.ActionText = ""
		props.ObjectText = ""
	end
	return props
end

function Fake.new(className, parent)
	local self = setmetatable({}, InstanceMeta)
	registry[self] = true
	rawset(self, "__props", defaultProps(className))
	rawset(self, "__children", {})
	rawset(self, "__attributes", {})
	rawset(self, "__signals", {})
	rawset(self, "__tags", {})
	if parent then
		self.Parent = parent
	end
	return self
end

local function signalFor(self, name)
	local signals = rawget(self, "__signals")
	local signal = signals[name]
	if not signal then
		signal = Signal.new()
		signals[name] = signal
	end
	return signal
end
Fake.signalFor = signalFor

InstanceMeta.__index = function(self, key)
	local props = rawget(self, "__props")
	-- Per-instance overrides (service methods set by the harness) win.
	local own = props[key]
	if type(own) == "function" then
		return own
	end
	local method = Methods[key]
	if method then
		return method
	end
	if key == "Position" and props.CFrame and isA(props.ClassName, "BasePart") then
		return props.CFrame.Position
	end
	if key == "Orientation" then
		return Vector3.zero
	end
	local value = props[key]
	if value ~= nil then
		return value
	end
	if EVENT_NAMES[key] then
		return signalFor(self, key)
	end
	-- Children are accessible by name (Roblox behaviour).
	for _, child in rawget(self, "__children") do
		if child.Name == key then
			return child
		end
	end
	return nil
end

InstanceMeta.__newindex = function(self, key, value)
	local props = rawget(self, "__props")
	if key == "Parent" then
		local old = props.Parent
		if old == value then
			return
		end
		if old then
			local siblings = rawget(old, "__children")
			local index = table.find(siblings, self)
			if index then
				table.remove(siblings, index)
			end
		end
		props.Parent = value
		if value then
			if not Fake.isInstance(value) then
				error("Parent must be an Instance, got " .. typeof(value), 2)
			end
			table.insert(rawget(value, "__children"), self)
			signalFor(value, "ChildAdded"):Fire(self)
		end
		return
	end
	if key == "Position" and isA(props.ClassName, "BasePart") then
		local cf = props.CFrame or CFrame.new()
		props.CFrame = CFrame.new(value) * (cf - cf.Position)
		return
	end
	props[key] = value
	local changed = rawget(self, "__signals")["Prop_" .. key]
	if changed then
		changed:Fire()
	end
end

InstanceMeta.__tostring = function(self)
	return rawget(self, "__props").Name
end

function Methods:IsA(className)
	return isA(self.ClassName, className)
end
function Methods:GetChildren()
	return table.clone(rawget(self, "__children"))
end
function Methods:GetDescendants()
	local list = {}
	local function walk(node)
		for _, child in rawget(node, "__children") do
			table.insert(list, child)
			walk(child)
		end
	end
	walk(self)
	return list
end
function Methods:FindFirstChild(name, recursive)
	for _, child in rawget(self, "__children") do
		if child.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in rawget(self, "__children") do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Methods:WaitForChild(name, timeout)
	local found = self:FindFirstChild(name)
	if found then
		return found
	end
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		task.wait(0.05)
		found = self:FindFirstChild(name)
		if found then
			return found
		end
	end
	return nil
end
function Methods:FindFirstChildOfClass(className)
	for _, child in rawget(self, "__children") do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end
function Methods:FindFirstChildWhichIsA(className)
	for _, child in rawget(self, "__children") do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end
function Methods:FindFirstAncestorWhichIsA(className)
	local node = self.Parent
	while node do
		if node:IsA(className) then
			return node
		end
		node = node.Parent
	end
	return nil
end
function Methods:FindFirstAncestor(name)
	local node = self.Parent
	while node do
		if node.Name == name then
			return node
		end
		node = node.Parent
	end
	return nil
end
function Methods:IsDescendantOf(ancestor)
	local node = self.Parent
	while node do
		if node == ancestor then
			return true
		end
		node = node.Parent
	end
	return false
end
function Methods:Destroy()
	signalFor(self, "Destroying"):Fire()
	for _, child in table.clone(rawget(self, "__children")) do
		child:Destroy()
	end
	self.Parent = nil
end
function Methods:ClearAllChildren()
	for _, child in table.clone(rawget(self, "__children")) do
		child:Destroy()
	end
end
function Methods:GetAttribute(name)
	return rawget(self, "__attributes")[name]
end
function Methods:SetAttribute(name, value)
	rawget(self, "__attributes")[name] = value
	signalFor(self, "AttributeChanged"):Fire(name)
end
function Methods:GetAttributes()
	return table.clone(rawget(self, "__attributes"))
end
function Methods:GetPropertyChangedSignal(name)
	return signalFor(self, "Prop_" .. name)
end
function Methods:AddTag(tag)
	rawget(self, "__tags")[tag] = true
end
function Methods:HasTag(tag)
	return rawget(self, "__tags")[tag] == true
end
function Methods:GetPivot()
	if self:IsA("BasePart") then
		return self.CFrame
	end
	local primary = self.PrimaryPart or self:FindFirstChild("HumanoidRootPart")
	return if primary then primary.CFrame else CFrame.new()
end
function Methods:PivotTo(cf)
	if self:IsA("BasePart") then
		self.CFrame = cf
		return
	end
	local root = self.PrimaryPart or self:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cf
	end
end
-- Sound / Tween / misc no-ops the server may call.
function Methods:Play() end
function Methods:Stop() end

---------------------------------------------------------------------------
-- Services and globals
---------------------------------------------------------------------------
function Fake.createWorld()
	local world = {}
	local game = Fake.new("DataModel")
	world.game = game
	local props = rawget(game, "__props")
	props.JobId = "harness-job"
	props.PlaceVersion = 1
	props.CreatorType = roblox.Enum.CreatorType.User
	props.CreatorId = 0
	props.PrivateServerId = ""
	props.PrivateServerOwnerId = 0
	world.closeHandlers = {}

	local services = {}
	world.services = services
	local function service(name, className)
		local instance = Fake.new(className or name)
		instance.Name = name
		instance.Parent = game
		services[name] = instance
		return instance
	end

	local workspace = service("Workspace")
	local Players = service("Players")
	service("ReplicatedStorage")
	service("ServerScriptService")
	service("ServerStorage")
	service("Lighting")
	service("SoundService")
	service("StarterGui")
	service("StarterPlayer")
	local RunService = service("RunService")
	local CollectionService = service("CollectionService")
	local DataStoreService = service("DataStoreService")
	local TextChatService = service("TextChatService")
	local MarketplaceService = service("MarketplaceService")
	local AnalyticsService = service("AnalyticsService")
	service("HttpService")
	service("TweenService")

	-- game methods
	function Methods:GetService(name)
		if self ~= game then
			error("GetService on non-DataModel")
		end
		local found = services[name]
		if not found then
			found = service(name)
		end
		return found
	end
	function Methods:BindToClose(fn)
		table.insert(world.closeHandlers, fn)
	end

	-- Workspace
	rawget(workspace, "__props").Gravity = 196.2
	rawget(workspace, "__props").StreamingEnabled = true
	local startClock = os.clock()
	function Methods:GetServerTimeNow()
		return 1700000000 + (os.clock() - startClock)
	end
	function Methods:Raycast()
		return nil -- no physics: line of sight is always clear
	end

	-- RunService
	world.studio = true
	function Methods:IsStudio()
		return world.studio
	end
	function Methods:IsServer()
		return true
	end
	function Methods:IsClient()
		return false
	end

	-- CollectionService
	local tags = {}
	local tagSignals = {}
	local function tagSignal(tag, kind)
		tagSignals[tag] = tagSignals[tag] or { Added = Signal.new(), Removed = Signal.new() }
		return tagSignals[tag][kind]
	end
	CollectionService.AddTag = function(_, instance, tag)
		tags[tag] = tags[tag] or {}
		if not table.find(tags[tag], instance) then
			table.insert(tags[tag], instance)
			instance:AddTag(tag)
			tagSignal(tag, "Added"):Fire(instance)
		end
	end
	CollectionService.RemoveTag = function(_, instance, tag)
		local list = tags[tag]
		local index = list and table.find(list, instance)
		if index then
			table.remove(list, index)
			tagSignal(tag, "Removed"):Fire(instance)
		end
	end
	CollectionService.GetTagged = function(_, tag)
		return table.clone(tags[tag] or {})
	end
	CollectionService.HasTag = function(_, instance, tag)
		return tags[tag] ~= nil and table.find(tags[tag], instance) ~= nil
	end
	CollectionService.GetInstanceAddedSignal = function(_, tag)
		return tagSignal(tag, "Added")
	end
	CollectionService.GetInstanceRemovedSignal = function(_, tag)
		return tagSignal(tag, "Removed")
	end

	-- DataStoreService (in-memory, real UpdateAsync semantics)
	local stores = {}
	world.stores = stores
	DataStoreService.GetDataStore = function(_, name)
		stores[name] = stores[name] or {}
		local data = stores[name]
		return {
			UpdateAsync = function(_, key, transform)
				local result = transform(data[key])
				if result ~= nil then
					data[key] = result
				end
				return result
			end,
			GetAsync = function(_, key)
				return data[key]
			end,
		}
	end
	DataStoreService.GetRequestBudgetForRequestType = function()
		return 100
	end

	-- TextChatService
	rawget(TextChatService, "__props").ChatVersion = roblox.Enum.ChatVersion.TextChatService
	local channels = Fake.new("Folder", TextChatService)
	channels.Name = "TextChannels"
	local general = Fake.new("TextChannel", channels)
	general.Name = "RBXGeneral"

	-- MarketplaceService
	MarketplaceService.UserOwnsGamePassAsync = function()
		return false
	end
	AnalyticsService.LogCustomEvent = function() end
	AnalyticsService.LogOnboardingFunnelStepEvent = function() end

	-- Players
	rawget(Players, "__props").CharacterAutoLoads = true
	local playerList = {}
	world.players = playerList
	Players.GetPlayers = function()
		local list = {}
		for _, player in playerList do
			if player.Parent == Players then
				table.insert(list, player)
			end
		end
		return list
	end
	Players.GetPlayerByUserId = function(_, userId)
		for _, player in playerList do
			if player.UserId == userId and player.Parent == Players then
				return player
			end
		end
		return nil
	end

	function world.addPlayer(name, userId)
		local player = Fake.new("Player")
		local p = rawget(player, "__props")
		p.Name = name
		p.DisplayName = name
		p.UserId = userId
		p.Character = nil
		rawset(player, "__inbox", {})
		player.Kick = function(_, message)
			rawset(player, "__kicked", message or true)
			player.Parent = nil
		end
		player.RequestStreamAroundAsync = function() end
		player.LoadCharacterAsync = function()
			local old = player.Character
			if old then
				signalFor(player, "CharacterRemoving"):Fire(old)
				old:Destroy()
			end
			local character = Fake.new("Model")
			character.Name = name
			local humanoid = Fake.new("Humanoid", character)
			humanoid.Name = "Humanoid"
			local root = Fake.new("Part", character)
			root.Name = "HumanoidRootPart"
			root.Size = Vector3.new(2, 2, 1)
			for _, partName in { "Head", "UpperTorso", "LeftUpperArm", "LeftHand", "RightHand" } do
				local part = Fake.new("Part", character)
				part.Name = partName
				part.Size = Vector3.new(1, 1, 1)
			end
			local animate = Fake.new("LocalScript", character)
			animate.Name = "Animate"
			character.PrimaryPart = root
			-- Spawn on the first SpawnLocation, like Roblox.
			local spawnCFrame = CFrame.new(0, 10, 0)
			for _, d in workspace:GetDescendants() do
				if d.ClassName == "SpawnLocation" then
					spawnCFrame = d.CFrame + Vector3.new(0, 4, 0)
					break
				end
			end
			root.CFrame = spawnCFrame
			character.Parent = workspace
			rawget(player, "__props").Character = character
			signalFor(player, "CharacterAdded"):Fire(character)
		end
		player.LoadCharacter = player.LoadCharacterAsync
		table.insert(playerList, player)
		player.Parent = Players
		signalFor(Players, "PlayerAdded"):Fire(player)
		if Players.CharacterAutoLoads then
			task.defer(player.LoadCharacterAsync)
		end
		return player
	end

	function world.removePlayer(player)
		signalFor(Players, "PlayerRemoving"):Fire(player)
		task.wait(0.05)
		if player.Character then
			player.Character:Destroy()
		end
		player.Parent = nil
	end

	return world
end

---------------------------------------------------------------------------
-- Remotes (server side behaviour + inbox capture for tests)
---------------------------------------------------------------------------
function Fake.installRemotes(world)
	local Players = world.services.Players
	-- Instance.new("RemoteEvent") gets server methods via Methods.
	function Methods:FireClient(player, ...)
		local inbox = rawget(player, "__inbox")
		if inbox then
			table.insert(inbox, { Remote = self.Name, Args = table.pack(...) })
		end
		-- Deliver to an emulated client for this player, if one is running.
		if world.clientPlayer == player then
			signalFor(self, "OnClientEvent"):Fire(...)
		end
	end
	function Methods:FireServer(...)
		assert(world.clientPlayer, "FireServer without a client")
		signalFor(self, "OnServerEvent"):Fire(world.clientPlayer, ...)
	end
	function Methods:InvokeServer(...)
		assert(world.clientPlayer, "InvokeServer without a client")
		local handler = self.OnServerInvoke
		assert(handler, "no OnServerInvoke for " .. self.Name)
		return handler(world.clientPlayer, ...)
	end
	function Methods:FireAllClients(...)
		for _, player in Players:GetPlayers() do
			self:FireClient(player, ...)
		end
	end
	-- Test helpers acting as a client.
	function world.fire(player, remoteName, ...)
		local folder = world.services.ReplicatedStorage:FindFirstChild("Remotes")
		local remote = folder and folder:FindFirstChild(remoteName)
		assert(remote, "No remote " .. remoteName)
		signalFor(remote, "OnServerEvent"):Fire(player, ...)
	end
	function world.invoke(player, remoteName, ...)
		local folder = world.services.ReplicatedStorage:FindFirstChild("Remotes")
		local remote = folder and folder:FindFirstChild(remoteName)
		assert(remote and remote.OnServerInvoke, "No invocable remote " .. remoteName)
		return remote.OnServerInvoke(player, ...)
	end
end

---------------------------------------------------------------------------
-- Globals table for loaded chunks
---------------------------------------------------------------------------
function Fake.globals(world)
	local RandomClass = {}
	RandomClass.new = function()
		return {
			NextInteger = function(_, a, b)
				return math.random(a, b)
			end,
			NextNumber = function(_, a, b)
				a = a or 0
				b = b or 1
				return a + math.random() * (b - a)
			end,
		}
	end
	local RaycastParams = {
		new = function()
			return { FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false }
		end,
	}
	local TweenInfo = {
		new = function(...)
			return { ... }
		end,
	}
	local InstanceLib = {
		new = function(className, parent)
			return Fake.new(className, parent)
		end,
	}
	local function fakeTypeof(value)
		if Fake.isInstance(value) then
			return "Instance"
		end
		if type(value) == "table" and value.Connected ~= nil and value.Disconnect then
			return "RBXScriptConnection"
		end
		return typeof(value)
	end
	return {
		game = world.game,
		workspace = world.services.Workspace,
		Instance = InstanceLib,
		Random = RandomClass,
		RaycastParams = RaycastParams,
		TweenInfo = TweenInfo,
		typeof = fakeTypeof,
		task = task,
		warn = function(...)
			print("[warn]", ...)
		end,
		print = print,
		Enum = roblox.Enum,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		BrickColor = roblox.BrickColor,
		Font = roblox.Font,
		Rect = roblox.Rect,
		PhysicalProperties = roblox.PhysicalProperties,
		-- standard library
		math = math,
		string = string,
		table = table,
		os = os,
		coroutine = coroutine,
		utf8 = utf8,
		buffer = buffer,
		bit32 = bit32,
		debug = debug,
		pairs = pairs,
		ipairs = ipairs,
		next = next,
		select = select,
		type = type,
		tostring = tostring,
		tonumber = tonumber,
		error = error,
		assert = assert,
		pcall = pcall,
		xpcall = xpcall,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		rawget = rawget,
		rawset = rawset,
		rawequal = rawequal,
		rawlen = rawlen,
		unpack = table.unpack,
	}
end


---------------------------------------------------------------------------
-- Client emulation (one local player)
---------------------------------------------------------------------------
-- Builds the client-only services and a `game` proxy for client modules.
function Fake.createClient(world, player)
	world.clientPlayer = player
	local Players = world.services.Players
	rawget(Players, "__props").LocalPlayer = player
	local playerGui = Fake.new("PlayerGui", player)
	playerGui.Name = "PlayerGui"

	local clientServices = {}
	local function clientService(name, className)
		local instance = Fake.new(className or name)
		instance.Name = name
		clientServices[name] = instance
		return instance
	end

	-- RunService (client view) with a frame loop.
	local runService = clientService("RunService")
	runService.IsServer = function()
		return false
	end
	runService.IsClient = function()
		return true
	end
	runService.IsStudio = function()
		return world.studio
	end
	local renderSteps = {}
	runService.BindToRenderStep = function(_, name, _priority, fn)
		renderSteps[name] = fn
	end
	runService.UnbindFromRenderStep = function(_, name)
		renderSteps[name] = nil
	end
	world.errors = world.errors or {}
	task.spawn(function()
		local last = os.clock()
		while world.running ~= false do
			task.wait(1 / 30)
			local now = os.clock()
			local dt = now - last
			last = now
			signalFor(runService, "Heartbeat"):Fire(dt)
			signalFor(runService, "RenderStepped"):Fire(dt)
			for name, fn in table.clone(renderSteps) do
				local ok, err = pcall(fn, dt)
				if not ok then
					table.insert(world.errors, "RenderStep " .. name .. ": " .. tostring(err))
					renderSteps[name] = nil
				end
			end
		end
	end)

	local uis = clientService("UserInputService")
	local uisProps = rawget(uis, "__props")
	uisProps.TouchEnabled = false
	uisProps.KeyboardEnabled = true
	uisProps.GamepadEnabled = false
	uisProps.MouseDeltaSensitivity = 1

	local cas = clientService("ContextActionService")
	world.actions = {}
	cas.BindAction = function(_, name, fn, touch, ...)
		world.actions[name] = { Fn = fn, Touch = touch, Keys = { ... } }
	end
	cas.UnbindAction = function(_, name)
		world.actions[name] = nil
	end
	cas.SetTitle = function() end
	cas.SetPosition = function() end

	local guiService = clientService("GuiService")
	rawget(guiService, "__props").SelectedObject = nil

	local tweenService = clientService("TweenService")
	tweenService.Create = function(_, instance, _info, goals)
		local tween = Fake.new("Tween")
		tween.Play = function()
			for key, value in goals do
				instance[key] = value
			end
			task.defer(function()
				signalFor(tween, "Completed"):Fire(roblox.Enum.PlaybackState.Completed)
			end)
		end
		tween.Cancel = function() end
		tween.Pause = function() end
		return tween
	end

	local starterGui = clientService("StarterGui")
	starterGui.SetCore = function() end
	starterGui.GetCore = function()
		return nil
	end

	local voice = clientService("VoiceChatService")
	voice.IsVoiceEnabledForUserIdAsync = function()
		return false
	end

	local http = clientService("HttpService")
	http.JSONEncode = function(_, value)
		return tostring(value)
	end

	local marketplace = clientService("MarketplaceService")
	marketplace.PromptProductPurchase = function() end
	marketplace.PromptGamePassPurchase = function() end

	clientService("ProximityPromptService")
	clientService("SoundService")

	-- Chat on the client
	local textChat = world.services.TextChatService
	local inputBar = Fake.new("ChatInputBarConfiguration", textChat)
	inputBar.Name = "ChatInputBarConfiguration"

	-- Camera
	local camera = Fake.new("Camera", world.services.Workspace)
	camera.Name = "Camera"
	local cameraProps = rawget(camera, "__props")
	cameraProps.ViewportSize = roblox.Vector2.new(1366, 768)
	cameraProps.FieldOfView = 70
	cameraProps.CFrame = CFrame.new()
	rawget(world.services.Workspace, "__props").CurrentCamera = camera

	local clientGame = Fake.new("DataModel")
	local gameProps = rawget(clientGame, "__props")
	for _, key in { "JobId", "PlaceVersion", "CreatorType", "CreatorId", "PrivateServerId", "PrivateServerOwnerId" } do
		gameProps[key] = rawget(world.game, "__props")[key]
	end
	clientGame.GetService = function(_, name)
		return clientServices[name] or world.game:GetService(name)
	end

	local globals = Fake.globals(world)
	globals.game = clientGame
	return globals, playerGui
end

return Fake
