--[[
	Runtime integration test: boots the REAL server code (src/server +
	src/shared) on FakeRoblox under Lune, then plays a solo round through the
	same remotes a client uses:

	  join -> ready -> launch -> role -> complete EVERY objective step (click
	  station -> server mini-game/process session -> correct answer) -> muster
	  via beacon -> hazard fix -> endgame route -> extraction -> results ->
	  rewards saved -> back to lobby

	plus a few exploit checks. Run: lune run tests/runtime/run.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Fake = require("./FakeRoblox")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local ROOT = (process.args[1] or ".")
local failures = 0
local function check(condition, message)
	if condition then
		print("  ok   " .. message)
	else
		failures += 1
		print("  FAIL " .. message)
	end
	return condition
end

---------------------------------------------------------------------------
-- World + module loading
---------------------------------------------------------------------------
local world = Fake.createWorld()
Fake.installRemotes(world)

-- Each context (server, client) gets its own module cache, like Roblox.
local function makeLoader(globals)
	local cache = {}
	local function requireModule(module)
		if cache[module] ~= nil then
			return cache[module]
		end
		local path = rawget(module, "__source")
		assert(path, "require on non-module " .. tostring(module))
		local env = table.clone(globals)
		env.script = module
		env.require = requireModule
		local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env, injectGlobals = false })
		local result = chunk()
		cache[module] = result
		return result
	end
	globals.require = requireModule
	return requireModule
end
local requireModule = makeLoader(Fake.globals(world))

local function mount(dir, parent)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			local folder = Fake.new("Folder", parent)
			folder.Name = name
			mount(path, folder)
		elseif string.sub(name, -5) == ".luau" then
			local stem = string.gsub(name, "%.luau$", "")
			local className = "ModuleScript"
			if string.sub(stem, -7) == ".server" then
				className = "Script"
				stem = string.sub(stem, 1, -8)
			elseif string.sub(stem, -7) == ".client" then
				className = "LocalScript"
				stem = string.sub(stem, 1, -8)
			end
			local module = Fake.new(className, parent)
			module.Name = stem
			rawset(module, "__source", path)
		end
	end
end

local shared = Fake.new("Folder", world.services.ReplicatedStorage)
shared.Name = "Shared"
mount(ROOT .. "/src/shared", shared)
local server = Fake.new("Folder", world.services.ServerScriptService)
server.Name = "Server"
mount(ROOT .. "/src/server", server)
for _, name in { "Lobby", "ActiveMap", "SpawnPoints", "InteractiveObjects" } do
	Fake.new("Folder", world.services.Workspace).Name = name
end

local function service(name)
	return requireModule(server.Services:FindFirstChild(name))
end
local function sharedModule(path)
	local node = shared
	for part in string.gmatch(path, "[^/]+") do
		node = node:FindFirstChild(part)
	end
	return requireModule(node)
end

---------------------------------------------------------------------------
-- Client-side view of a player (folds the remote inbox)
---------------------------------------------------------------------------
local function view(player)
	local public, private, events = {}, {}, {}
	for _, message in rawget(player, "__inbox") do
		local args = message.Args
		if message.Remote == "PublicStateChanged" then
			public[args[1]] = args[2]
		elseif message.Remote == "PrivateStateChanged" then
			private[args[1]] = args[2]
		else
			table.insert(events, message)
		end
	end
	return public, private, events
end

local function waitFor(description, predicate, timeout)
	local deadline = os.clock() + (timeout or 20)
	while os.clock() < deadline do
		local value = predicate()
		if value then
			return value
		end
		task.wait(0.1)
	end
	print("  ... timed out waiting for " .. description)
	return nil
end

local function lastEvent(player, remoteName, after)
	local inbox = rawget(player, "__inbox")
	for i = #inbox, after + 1, -1 do
		if inbox[i].Remote == remoteName then
			return inbox[i].Args, i
		end
	end
	return nil
end

local function standAt(player, anchorId)
	local MapService = service("MapService")
	local anchor = MapService.GetAnchor(anchorId)
	assert(anchor, "missing anchor " .. anchorId)
	local look = anchor.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, 1)
	local position = anchor.Position + flat * 3
	player.Character.HumanoidRootPart.CFrame = CFrame.new(position.X, anchor.Position.Y - 0.4, position.Z)
	MapService.MarkTeleported(player)
end

local function solve(kind, challenge)
	if kind == "Process" then
		return true
	elseif kind == "Sliders" then
		return table.clone(challenge.Targets)
	elseif kind == "Sequence" then
		return challenge.Code
	elseif kind == "Timing" then
		return { Hits = challenge.Required, Misses = 0 }
	elseif kind == "Wires" then
		local answer = {}
		for i, colour in challenge.Left do
			answer[i] = table.find(challenge.Right, colour)
		end
		return answer
	end
	error("unknown kind " .. tostring(kind))
end

---------------------------------------------------------------------------
-- Scenario
---------------------------------------------------------------------------
print("Booting server...")
local gameServer = server:FindFirstChild("GameServer")
local bootOk, bootErr = pcall(function()
	task.spawn(requireModule, gameServer)
end)
task.wait(1.5)
check(bootOk and world.services.ReplicatedStorage:FindFirstChild("Remotes") ~= nil, "server boots and creates remotes " .. tostring(bootErr or ""))
local partCount = 0
for _, d in world.services.Workspace:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	end
end
check(partCount > 500, "map built (" .. partCount .. " parts)")

print("Player joins and the real client boots...")
local player = world.addPlayer("Tester", 101)
local clientGlobals, playerGui = Fake.createClient(world, player)
local clientRequire = makeLoader(clientGlobals)
local playerScripts = Fake.new("Folder", player)
playerScripts.Name = "PlayerScripts"
local clientFolder = Fake.new("Folder", playerScripts)
clientFolder.Name = "Client"
mount(ROOT .. "/src/client", clientFolder)
local clientBootError = nil
task.spawn(function()
	local ok, err = pcall(clientRequire, clientFolder:FindFirstChild("ClientMain"))
	if not ok then
		clientBootError = tostring(err)
	end
end)
task.wait(2)
check(clientBootError == nil, "client boots without errors " .. (clientBootError or ""))
check(player.Character ~= nil, "server spawned a character")
check(waitFor("profile", function()
	local _, private = view(player)
	return private.DataStatus == "Ready" and private.Profile ~= nil
end, 10) ~= nil, "client reported ready and profile loaded")

local function clientModule(name)
	return clientRequire(clientFolder.Controllers:FindFirstChild(name))
end

-- Find a visible button by text anywhere in the player's GUI.
local function isShown(gui)
	local node = gui
	while node and node ~= playerGui do
		if node:IsA("GuiObject") and node.Visible == false then
			return false
		end
		if node:IsA("LayerCollector") and node.Enabled == false then
			return false
		end
		node = node.Parent
	end
	return true
end
local function findButton(pattern)
	for _, d in playerGui:GetDescendants() do
		if d.ClassName == "TextButton" and type(d.Text) == "string" and string.find(d.Text, pattern) and isShown(d) then
			return d
		end
	end
	return nil
end
local function click(pattern)
	local button = findButton(pattern)
	if button then
		Fake.signalFor(button, "Activated"):Fire()
		task.wait(0.2)
	end
	return button ~= nil
end

for _, layer in { "VoidlineHud", "VoidlineScreens", "VoidlineModals", "VoidlineOverlay", "VoidlineMinigame" } do
	check(playerGui:FindFirstChild(layer) ~= nil, "UI layer " .. layer .. " exists")
end
check(click("^Play$"), "main menu Play button works")

-- Exploit: junk requests are rejected and counted.
world.fire(player, "Sabotage", "PowerSurge", "Fore")
world.fire(player, "InteractComplete", string.rep("x", 500))
check(service("RemoteService").GetStrikes(player) == 1, "malformed request counted as a strike")

print("Ready up via the lobby screen...")
check(click("^READY$"), "lobby READY button works")
check(waitFor("ACTIVE_ROUND", function()
	return (view(player)).RoundState == "ACTIVE_ROUND"
end, 40) ~= nil, "round reached ACTIVE_ROUND")
local _, private = view(player)
check(type(private.Role) == "table" and private.Role.Faction == "Crew", "solo player is crew")
check(type(private.Tasks) == "table" and #private.Tasks == 5, "five objectives assigned")
check(playerGui.VoidlineHud ~= nil and isShown(playerGui.VoidlineHud.Hud), "HUD visible in play")

local function promptFor(interactionId)
	for _, d in world.services.Workspace:GetDescendants() do
		if d.ClassName == "ProximityPrompt" and d.Name == "Voidline_" .. interactionId then
			return d
		end
	end
	return nil
end

-- Exploit: completing a station from across the map does nothing.
do
	local before = #rawget(player, "__inbox")
	local firstStep = private.Tasks[1].Steps[1]
	world.fire(player, "InteractComplete", "Task:" .. string.sub(firstStep.Anchor, 9))
	task.wait(0.3)
	check(lastEvent(player, "MinigameStart", before) == nil, "out-of-range station request rejected")
end

-- Gallery lift: one press up, one press down.
do
	local root = player.Character.HumanoidRootPart
	for _, spec in { { "Lift:Lift.Bottom", "Fixture:Lift.Bottom", 1 }, { "Lift:Lift.Top", "Fixture:Lift.Top", -1 } } do
		standAt(player, spec[2])
		local startY = root.Position.Y
		local lift = waitFor("prompt " .. spec[1], function()
			return promptFor(spec[1])
		end, 3)
		if check(lift ~= nil and lift.Enabled, "lift prompt shown: " .. spec[1]) then
			check(lift.HoldDuration == 0, "lift rides with a single press")
			task.wait(1.6) -- past the ride cooldown
			Fake.signalFor(lift, "Triggered"):Fire(player)
			check(waitFor("lift moved " .. spec[1], function()
				return (root.Position.Y - startY) * spec[3] > 8
			end, 3) ~= nil, "lift moved the player " .. (if spec[3] > 0 then "up to the gallery" else "down to the deck"))
		end
	end
end

local minigameGui = playerGui:FindFirstChild("VoidlineMinigame")

print("Completing every objective step through the client...")
local steps, meetingDone, hazardDone = 0, false, false
for _ = 1, 40 do
	local public
	public, private = view(player)
	if public.RoundState ~= "ACTIVE_ROUND" then
		break
	end
	local current
	for _, entry in private.Tasks do
		if not entry.Done then
			current = entry
			break
		end
	end
	if not current then
		break
	end
	local step = current.Steps[current.StepIndex]
	local key = string.sub(step.Anchor, 9)
	standAt(player, step.Anchor)
	local prompt = waitFor("prompt Task:" .. key, function()
		return promptFor("Task:" .. key)
	end, 3)
	if not check(prompt ~= nil and prompt.Enabled, "client shows a prompt: " .. current.Name .. " / " .. step.Label) then
		break
	end
	check(prompt.HoldDuration == 0, "task prompt opens with a single press")
	local before = #rawget(player, "__inbox")
	Fake.signalFor(prompt, "Triggered"):Fire(player)
	local start = waitFor("MinigameStart for " .. key, function()
		return lastEvent(player, "MinigameStart", before)
	end, 3)
	if not check(start ~= nil, "pressing the prompt opens a task") then
		break
	end
	task.wait(0.2)
	check(minigameGui.Enabled and minigameGui:FindFirstChild("Minigame") ~= nil, "task window shown on screen (" .. start[2] .. ")")
	local sessionId, kind, challenge = start[1], start[2], start[3]
	if kind ~= "Process" then
		-- Player solves it (the UI is emulated by sending the answer it would send).
		local minSeconds = sharedModule("Logic/Minigames").limits(kind, nil)
		task.wait(minSeconds + 0.25)
		world.fire(player, "MinigameSubmit", sessionId, solve(kind, challenge))
	end
	local result = waitFor("MinigameResult", function()
		return lastEvent(player, "MinigameResult", before)
	end, (challenge.Duration or 3) + 4)
	check(result ~= nil and result[2] == true, string.format("%s step accepted%s", kind, if kind == "Process" then " (auto-submitted by the client panel)" else ""))
	task.wait(0.2)
	check(not minigameGui.Enabled, "task window closed afterwards")
	steps += 1

	if steps == 3 and not hazardDone then
		hazardDone = true
		print("Sabotage + fix through a hold prompt...")
		local res = world.invoke(player, "AdminCommand", "Sabotage", "PowerSurge", "Aft")
		check(res and res.Ok, "admin sabotage started")
		local hazard = waitFor("hazard", function()
			local pub = view(player)
			return pub.Hazards and pub.Hazards[1]
		end, 3)
		if check(hazard ~= nil, "hazard published") then
			local fixture = hazard.Fixtures[1]
			standAt(player, "Fixture:" .. fixture)
			local id = string.format("Hazard:%s:%s", hazard.Id, fixture)
			local fixPrompt = waitFor("fix prompt", function()
				return promptFor(id)
			end, 3)
			if check(fixPrompt ~= nil, "fix prompt shown") then
				Fake.signalFor(fixPrompt, "PromptButtonHoldBegan"):Fire(player)
				task.wait(fixPrompt.HoldDuration + 0.2)
				Fake.signalFor(fixPrompt, "Triggered"):Fire(player)
				Fake.signalFor(fixPrompt, "PromptButtonHoldEnded"):Fire(player)
				check(waitFor("hazard cleared", function()
					local pub = view(player)
					return pub.Hazards and #pub.Hazards == 0
				end, 3) ~= nil, "hazard fixed by holding the prompt")
			end
		end
	end
	if steps == 5 and not meetingDone then
		meetingDone = true
		print("Muster via beacon, voting through the muster screen...")
		task.wait(math.max(0, 22 - steps * 3))
		standAt(player, "Fixture:Beacon")
		local beacon = waitFor("beacon prompt", function()
			return promptFor("Beacon")
		end, 3)
		if check(beacon ~= nil, "beacon prompt shown") then
			Fake.signalFor(beacon, "PromptButtonHoldBegan"):Fire(player)
			task.wait(beacon.HoldDuration + 0.2)
			Fake.signalFor(beacon, "Triggered"):Fire(player)
		end
		if check(waitFor("DISCUSSION", function()
			return (view(player)).RoundState == "DISCUSSION"
		end, 5) ~= nil, "beacon called a muster") then
			task.wait(0.4)
			check(isShown(playerGui.VoidlineScreens.Meeting), "muster screen visible")
			check(click("^REQUEST EVIDENCE$"), "request evidence button")
			check(click("^END DISCUSSION"), "end discussion button")
			check(waitFor("VOTING", function()
				return (view(player)).RoundState == "VOTING"
			end, 3) ~= nil, "moved to voting")
			task.wait(0.3)
			check(click("^SKIP VOTE$"), "skip vote button")
			check(waitFor("back to play", function()
				return (view(player)).RoundState == "ACTIVE_ROUND"
			end, 12) ~= nil, "muster resolved and play resumed")
		end
	end
end

print("Endgame...")
check(waitFor("ENDGAME", function()
	return (view(player)).RoundState == "ENDGAME"
end, 10) ~= nil, "100% restoration starts the endgame")
for _ = 1, 3 do
	local escape = (view(player)).Escape
	if not escape or escape.ExtractionEndsAt then
		break
	end
	local step = escape.Steps[escape.StepIndex]
	standAt(player, step.Anchor)
	local id = "Escape:" .. escape.StepIndex
	local escapePrompt = waitFor("escape prompt", function()
		return promptFor(id)
	end, 3)
	if check(escapePrompt ~= nil, "escape prompt shown: " .. step.Label) then
		Fake.signalFor(escapePrompt, "PromptButtonHoldBegan"):Fire(player)
		task.wait(escapePrompt.HoldDuration + 0.3)
		Fake.signalFor(escapePrompt, "Triggered"):Fire(player)
	end
	check(waitFor("escape step", function()
		local p = view(player)
		return p.Escape and (p.Escape.StepIndex > escape.StepIndex or p.Escape.ExtractionEndsAt ~= nil)
	end, 3) ~= nil, "escape step done")
end
local escape = (view(player)).Escape
if check(escape and escape.ExtractionEndsAt ~= nil, "extraction armed") then
	local MapService = service("MapService")
	local center = MapService.RoomCenter(escape.ExtractionRoom)
	player.Character.HumanoidRootPart.CFrame = CFrame.new(center + Vector3.new(4, 3, 4))
	MapService.MarkTeleported(player)
	print("Waiting for extraction countdown...")
	check(waitFor("RESULTS", function()
		return (view(player)).RoundState == "RESULTS"
	end, 60) ~= nil, "round ended")
	local public
	public, private = view(player)
	check(public.Results and public.Results.Winner == "Crew", "crew won by escaping")
	check(type(private.Reward) == "table" and private.Reward.Xp > 0, "rewards granted")
	task.wait(0.3)
	check(isShown(playerGui.VoidlineScreens.Results), "results screen visible")
end
check(waitFor("LOBBY", function()
	return (view(player)).RoundState == "LOBBY"
end, 30) ~= nil, "returned to lobby")
local _, finalPrivate = view(player)
check(finalPrivate.Profile and finalPrivate.Profile.Stats.RoundsPlayed == 1, "stats recorded in profile")

print("Menus...")
check(click("^Menu"), "lobby menu button")
for _, name in { "Customize", "Statistics", "Settings", "Credits" } do
	check(click("^" .. name .. "$"), name .. " opens")
	check(click("^✕$"), name .. " closes")
end

for _, err in world.errors or {} do
	check(false, "client frame error: " .. err)
end

print("Leaving (profile save)...")
world.running = false
world.removePlayer(player)
task.wait(1)
local store = world.stores["VoidlineProfiles_v1"]
local record = store and store["u_101"]
check(record and record.Data and record.Data.Stats.RoundsPlayed == 1 and record.Lock == nil, "profile saved and session lock released")

print(string.format("\n%s (%d failure%s)", if failures == 0 then "PASSED" else "FAILED", failures, if failures == 1 then "" else "s"))
process.exit(if failures == 0 then 0 else 1)
