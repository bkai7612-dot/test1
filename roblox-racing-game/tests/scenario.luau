-- End-to-end smoke test: server + client in one VM against the engine mock.
local G = __getMock()
local game, workspace = G.game, G.workspace
local CFrame, Vector3 = G.CFrame, G.Vector3

-- Module loader ----------------------------------------------------------------
local ENV_NAMES = {
	"require", "os", "task", "game", "workspace", "Instance", "Vector3", "Vector2", "CFrame", "Color3",
	"UDim", "UDim2", "Enum", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence",
	"NumberSequenceKeypoint", "NumberRange", "PhysicalProperties", "TweenInfo", "Random", "RaycastParams",
	"typeof", "warn",
}
local prefixParts = {}
for _, n in ENV_NAMES do
	table.insert(prefixParts, "__G." .. n)
end
local PREFIX = "local script, __G = ...; local " .. table.concat(ENV_NAMES, ", ") .. " = " .. table.concat(prefixParts, ", ") .. "; "

local cache = {}
local function runScript(scriptInst)
	local src = scriptInst:GetAttribute("__source")
	local fn = __compile(PREFIX .. src, scriptInst:GetAttribute("__path"))
	return fn(scriptInst, G)
end
function G.require(moduleScript)
	assert(moduleScript and moduleScript.ClassName == "ModuleScript", "require: not a ModuleScript " .. tostring(moduleScript))
	if cache[moduleScript] == nil then
		cache[moduleScript] = runScript(moduleScript)
	end
	return cache[moduleScript]
end

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = G.Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local roots = {
	shared = folder(game.ReplicatedStorage, "Shared"),
	server = folder(game.ServerScriptService, "Server"),
	client = G.Instance.new("Folder"),
}
roots.client.Name = "Client"

for path in string.gmatch(__listFiles(), "[^\n]+") do
	local top, rest = string.match(path, "^(%w+)/(.+)$")
	local parent = roots[top]
	local segments = string.split(rest, "/")
	for i = 1, #segments - 1 do
		parent = folder(parent, segments[i])
	end
	local file = segments[#segments]
	local className, name = "ModuleScript", string.gsub(file, "%.lua$", "")
	if string.find(file, "%.server%.lua$") then
		className, name = "Script", string.gsub(file, "%.server%.lua$", "")
	elseif string.find(file, "%.client%.lua$") then
		className, name = "LocalScript", string.gsub(file, "%.client%.lua$", "")
	end
	local inst = G.Instance.new(className)
	inst.Name = name
	inst:SetAttribute("__source", __readFile(path))
	inst:SetAttribute("__path", path)
	inst.Parent = parent
end

local function check(cond, msg)
	if cond then
		print("  ok   " .. msg)
	else
		print("  FAIL " .. msg)
		table.insert(G.errors, "check failed: " .. msg)
	end
end

-- Boot server ------------------------------------------------------------------
print("== boot server")
G.task.spawn(runScript, roots.server.Main)
G.run(0.5)
check(workspace:FindFirstChild("Lobby") ~= nil, "lobby built")
print("   lobby parts:", G.countParts(workspace.Lobby))

local player = G.makePlayer("Tester", 1)
G.localPlayer = player
game.Players.LocalPlayer = player
game.Players.PlayerAdded:Fire(player)
player:LoadCharacter()
G.run(1)

-- Boot client ------------------------------------------------------------------
print("== boot client")
G.isServer = false
local playerScripts = G.Instance.new("Folder")
playerScripts.Name = "PlayerScripts"
playerScripts.Parent = player
roots.client.Parent = playerScripts
G.task.spawn(runScript, roots.client.Main)
G.run(2)

local State = G.require(roots.client.State)
local HUD = G.require(roots.client.UI.HUD)
local CarController = G.require(roots.client.CarController)
local Shared = game.ReplicatedStorage.Shared
local Maps = G.require(Shared.Maps)
local Config = G.require(Shared.Config)
local Products = G.require(Shared.Products)
local Cars = G.require(Shared.Cars)
local Upgrades = G.require(Shared.Upgrades)
local TrackBuilder = G.require(roots.server.TrackBuilder)
local CarService = G.require(roots.server.CarService)
local DataService = G.require(roots.server.DataService)

check(State.data ~= nil, "client received data")
print("   coins:", State.data and State.data.coins)

-- Shop / garage actions -----------------------------------------------------------
print("== shop actions")
local function req(...)
	local ok, msg = State.Request(...)
	G.run(0.2)
	return ok, msg
end
local coins0 = State.data.coins
check(req("RedeemCode", " launch ") == true, "redeem LAUNCH")
check(State.data.coins == coins0 + 1000, "coins +1000 from code")
check(req("RedeemCode", "LAUNCH") == false, "cannot redeem twice")
local ok, msg = req("BuyCar", "Rally")
check(ok == false, "cannot buy Rally at level 1 (" .. tostring(msg) .. ")")
check(req("Upgrade", "Hatch", "Engine") == true, "upgrade Hatch engine")
check(State.data.upgrades.Hatch.Engine == 1, "engine level 1")
check(req("Customize", "Hatch", "paint", "Sky Blue") == false, "locked paint rejected")
check(req("Customize", "Hatch", "paint", "Jet Black") == true, "paint Jet Black")
check(req("Customize", "Hatch", "glow", "Rainbow") == false, "VIP glow rejected")
check(req("PromptProduct", "Coins1") == false, "unconfigured product rejected")
check(req("SelectCar", "Muscle") == false, "cannot select unowned car")

for _, name in { "Garage", "Upgrades", "Customize", "Shop", "Codes" } do
	HUD.OpenPanel(name)
	G.run(0.1)
end
HUD.CloseAll()
HUD.OpenPanel("Garage", "Hyper")
G.run(0.1)
HUD.CloseAll()

-- Robux receipts ---------------------------------------------------------------------
print("== robux")
local Marketplace = game.MarketplaceService
Products.Developer.Coins1.id = 111
Products.Developer.MaxUpgrade.id = 222
Products.Developer.Car_Tuner.id = 333
check(req("PromptProduct", "Coins1") == true, "prompt coins pack")
local before = State.data.coins
local receipt = { PlayerId = 1, PurchaseId = "p1", ProductId = 111, CurrencySpent = 25 }
local decision
G.task.spawn(function()
	decision = Marketplace.ProcessReceipt(receipt)
end)
G.run(0.3)
check(decision and decision.Name == "PurchaseGranted", "receipt granted")
check(State.data.coins == before + 1000, "coins granted once")
G.task.spawn(function()
	decision = Marketplace.ProcessReceipt(receipt)
end)
G.run(0.3)
check(State.data.coins == before + 1000, "duplicate receipt not double-granted")
check(req("PromptProduct", "MaxUpgrade", "Hatch", "Turbo") == true, "prompt max upgrade")
G.task.spawn(function()
	decision = Marketplace.ProcessReceipt({ PlayerId = 1, PurchaseId = "p2", ProductId = 222 })
end)
G.run(0.3)
check(State.data.upgrades.Hatch.Turbo == Upgrades.MAX_LEVEL, "turbo maxed by robux")
G.task.spawn(function()
	decision = Marketplace.ProcessReceipt({ PlayerId = 1, PurchaseId = "p3", ProductId = 333 })
end)
G.run(0.3)
check(State.data.owned.Tuner == true, "Tuner unlocked by robux")
check(req("SelectCar", "Hatch") == true, "reselect Hatch")

-- Test drive ------------------------------------------------------------------------------
print("== test drive")
check(req("TestDrive") == true, "test drive spawned")
G.run(0.5)
check(CarController.IsActive(), "car controller active")
local car = CarService.Get(player)
check(car ~= nil and car.DriverSeat.Occupant ~= nil, "driver seated")
G.groundY = car.PrimaryPart.Position.Y - 2.45
G.keys.W = true
G.keys.LeftShift = true
G.run(1, 1 / 60)
G.keys.W = false
G.keys.LeftShift = false
local vel = car.PrimaryPart.AssemblyLinearVelocity
print("   velocity after throttle:", vel)
check(vel.Magnitude > 1, "throttle produced motion")
check(req("ExitCar") == true, "exit test car")
G.run(0.5)
check(not CarController.IsActive(), "controller stopped")
check(CarService.Get(player) == nil, "test car removed")

-- Races on all 8 maps --------------------------------------------------------------------
local function waitFor(pred, maxSeconds, label)
	local t = 0
	while not pred() and t < maxSeconds do
		G.advance(0.1)
		t += 0.1
	end
	check(pred(), label)
	return pred()
end

local finishInfo
game.ReplicatedStorage.Remotes.Checkpoint.OnClientEvent:Connect(function(info)
	if info.finished then
		finishInfo = info
	end
end)

for idx, mapId in Maps.Order do
	print("== race " .. idx .. ": " .. mapId)
	waitFor(function()
		return State.race.phase == "Intermission"
	end, 40, "intermission reached")
	check(req("Vote", mapId) == true, "voted " .. mapId)
	waitFor(function()
		return State.race.phase == "Racing"
	end, 60, "race started")
	check(State.race.mapId == mapId, "voted map chosen")
	local track = workspace:FindFirstChild("ActiveTrack")
	print("   track parts:", track and G.countParts(track))

	local model = CarService.Get(player)
	check(model ~= nil and not model.PrimaryPart.Anchored, "race car released")
	local chassis = model.PrimaryPart
	local pts = {}
	for _, q in Maps.List[mapId].points do
		table.insert(pts, Config.TRACK_ORIGIN + Vector3.new(q[1], q[2], q[3]))
	end
	local samples = TrackBuilder.Sample(pts, 8)
	local frames = {}
	for k = 1, #samples do
		local a, b = samples[(k - 2) % #samples + 1], samples[k % #samples + 1]
		local dir = (b - a).Unit
		local right = dir:Cross(Vector3.yAxis).Unit
		frames[k] = { pos = samples[k], dir = dir, up = right:Cross(dir).Unit }
	end
	local n = #frames
	finishInfo = nil
	local i = n - 10
	local steps = 0
	while not finishInfo and steps < n * (Maps.List[mapId].laps + 1) + 50 do
		local f = frames[(i - 1) % n + 1]
		local p = f.pos + f.up * 3
		chassis.CFrame = CFrame.lookAt(p, p + f.dir)
		G.advance(0.05)
		i += 1
		steps += 1
	end
	check(finishInfo ~= nil and finishInfo.place == 1, "finished 1st in " .. steps .. " steps")
	waitFor(function()
		return State.race.phase == "Results"
	end, 10, "results phase")
	waitFor(function()
		return State.race.phase == "Intermission" or State.race.phase == "Waiting"
	end, 30, "back to lobby")
	check(workspace:FindFirstChild("ActiveTrack") == nil, "track cleaned up")
	check(State.data.stats.races == idx, "race counted (" .. State.data.stats.races .. ")")
	print("   coins/level/xp:", State.data.coins, State.data.level, State.data.xp)
	check(State.data.bestTimes[mapId] ~= nil, "best time recorded")
end

-- DNF path: join a race and leave the car mid-race ------------------------------------
print("== reseat + death")
waitFor(function()
	return State.race.phase == "Racing"
end, 80, "another race started")
local model = CarService.Get(player)
local seat = model.DriverSeat
seat.SeatWeld:Destroy()
G.run(0.5)
check(seat.Occupant ~= nil, "racer re-seated after leaving")
player.Character.Humanoid.Died:Fire()
G.run(0.5)
check(CarService.Get(player) == nil, "car removed on death")
waitFor(function()
	return State.race.phase == "Intermission" or State.race.phase == "Waiting"
end, 30, "race ended after DNF")

-- Save --------------------------------------------------------------------------------------
print("== save")
check(DataService.Save(player) == true, "save succeeded")
local saved = G.memStore[Config.DATASTORE_NAME]["Player_1"]
check(saved ~= nil and saved.stats.races >= 8, "saved races")

print("")
print("ERRORS: " .. #G.errors)
for _, e in G.errors do
	print("----\n" .. e)
end
if #G.errors > 0 then
	error(#G.errors .. " smoke test error(s)")
end
print("ALL CHECKS PASSED")
