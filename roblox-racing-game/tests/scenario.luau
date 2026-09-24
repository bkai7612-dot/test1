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
local lastResult
game.ReplicatedStorage.Remotes.RaceResults.OnClientEvent:Connect(function(payload)
	for _, entry in payload.results do
		if entry.userId == player.UserId then
			lastResult = entry
		end
	end
end)
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
	check(lastResult ~= nil and lastResult.xp == Config.Rewards.xpSolo, "solo race gives flat solo XP")
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

-- Level cap ----------------------------------------------------------------------------------
print("== level cap")
local Levels = G.require(Shared.Levels)
local d = DataService.Get(player)
d.level = Levels.MAX - 1
d.xp = 0
local coinsBefore = d.coins
local converted = DataService.AddXP(player, Levels.XPForLevel(Levels.MAX - 1) + 1000)
check(d.level == Levels.MAX, "reached level cap " .. Levels.MAX)
check(converted == 500, "overflow XP converted to coins (" .. converted .. ")")
check(d.coins == coinsBefore + Levels.LevelReward(Levels.MAX) + Levels.MAX_LEVEL_BONUS + 500, "cap bonus paid")
converted = DataService.AddXP(player, 200)
check(d.level == Levels.MAX and d.xp == 0 and converted == 100, "no levels past the cap")
DataService.Push(player)
G.run(0.2)
check(State.data.maxLevel == Levels.MAX and State.data.level == Levels.MAX, "client sees max level")
check(Config.Rewards.xpByPlace[1] > Config.Rewards.xpByPlace[2] and Config.Rewards.xpByPlace[2] > Config.Rewards.xpByPlace[3]
	and Config.Rewards.xpByPlace[3] > Config.Rewards.xpFinish, "placement XP ordered 1st > 2nd > 3rd > finish")

check(State.data.owned.Burger == true, "level 50 reward car granted")

-- Admin code ------------------------------------------------------------------------------
print("== admin code")
local sha256 = G.require(roots.server.Sha256)
check(sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "sha256 test vector")
check(sha256("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "sha256 empty vector")
local AdminCodes = G.require(roots.server.AdminCodes)
local TEST_CODE = "TESTCODE2345ABCDEFGHJKMNP"
check(#TEST_CODE == 25, "test code is 25 chars")
AdminCodes.Codes[sha256(TEST_CODE)] = { id = "TEST_ADMIN", maxUses = 2 }
d.level = 5
d.xp = 0
d.owned = { Hatch = true }
d.selectedCar = "Hatch"
check(req("Customize", "Hatch", "glow", "Rainbow") == false, "VIP glow locked before admin")
check(req("RedeemCode", "testcode 2345abcdefghjkmnp") == true, "admin code redeemed (case/space-insensitive)")
check(State.data.admin == true and State.data.level == Levels.MAX, "admin is level 50")
local allOwned = true
for _, carId in Cars.Order do
	allOwned = allOwned and State.data.owned[carId] == true
end
check(allOwned, "admin owns every car")
check(req("Customize", "Hatch", "glow", "Rainbow") == true, "admin can use VIP-only cosmetics")
check(req("Customize", "Hatch", "finish", "Chrome") == true, "admin can use level-locked cosmetics")
local okAgain, msgAgain = req("RedeemCode", TEST_CODE)
check(okAgain == false, "same account can't redeem twice (" .. tostring(msgAgain) .. ")")
local adminStore = G.memStore[AdminCodes.STORE]
check(adminStore.TEST_ADMIN.uses == 1, "one global use recorded")
adminStore.TEST_ADMIN = { uses = 2, users = { ["77"] = true, ["88"] = true } }
d.codes.TEST_ADMIN = nil
local okFull, msgFull = req("RedeemCode", TEST_CODE)
check(okFull == false, "code rejected after 2 other accounts used it (" .. tostring(msgFull) .. ")")
adminStore.TEST_ADMIN = { uses = 2, users = { ["1"] = true, ["88"] = true } }
check(req("RedeemCode", TEST_CODE) == true, "account that already holds a use can re-redeem (new save)")
check(adminStore.TEST_ADMIN.uses == 2, "re-redeem doesn't consume a use")
local okBad = req("RedeemCode", "ZZZZZZZZZZZZZZZZZZZZZZZZZ")
check(okBad == false, "wrong 25-char code rejected")

-- Burger car ------------------------------------------------------------------------------
print("== burger car")
check(req("SelectCar", "Burger") == true, "select burger")
waitFor(function()
	return State.race.phase == "Intermission" or State.race.phase == "Waiting"
end, 60, "lobby phase for test drive")
check(req("TestDrive") == true, "burger test drive")
G.run(0.5)
local burger = CarService.Get(player)
check(burger ~= nil and burger:FindFirstChild("TopBun") ~= nil and burger:FindFirstChild("Cheese") ~= nil, "burger body built")
check(burger ~= nil and burger.DriverSeat.Occupant ~= nil, "driver in burger")
local flames = 0
for _, dsc in burger:GetDescendants() do
	if dsc.Name == "NitroFlame" then
		flames += 1
	end
end
check(flames == 2, "fry exhausts have nitro flames")
req("ExitCar")
G.run(0.5)
req("SelectCar", "Hatch")

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
