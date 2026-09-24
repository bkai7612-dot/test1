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

local Sessions = G.require(roots.server.Sessions)
local RaceService = G.require(roots.server.RaceService)
local MatchService = G.require(roots.server.MatchService)
local Customization = G.require(Shared.Customization)

-- Moves each driver's car along its session's track. speed = track samples per tick.
local function driveSession(drivers, maxTicks)
	local session = Sessions.Get(drivers[1].player)
	local frames = session.track.frames
	local n = #frames
	local idx = {}
	local open = session.track.open
	for _, d in drivers do
		idx[d.player] = open and session.track.startIndex - 10 or n - 14
	end
	local ticks = 0
	while ticks < maxTicks and session.phase ~= "Results" and not session.closed do
		for _, d in drivers do
			local model = CarService.Get(d.player)
			if model and Sessions.Get(d.player) == session then
				idx[d.player] += d.speed
				local k = open and math.min(idx[d.player], n) or (idx[d.player] - 1) % n + 1
				local f = frames[k]
				local pos = f.pos + f.up * 3
				model.PrimaryPart.CFrame = CFrame.lookAt(pos, pos + f.dir)
			end
		end
		G.advance(0.05)
		ticks += 1
	end
	return ticks, session
end

local lastPayload
game.ReplicatedStorage.Remotes.RaceResults.OnClientEvent:Connect(function(payload)
	lastPayload = payload
end)

-- Cosmetic items ----------------------------------------------------------------------------
print("== cosmetics")
DataService.AddCoins(player, 60000)
DataService.Push(player)
G.run(0.2)
local coinsBeforeItems = State.data.coins
check(req("Customize", "Hatch", "wings", "Angel") == false, "can't equip unowned wings")
check(req("BuyItem", "wings", "Angel") == true, "bought Angel wings")
check(State.data.coins == coinsBeforeItems - 4000, "wings cost 4,000 coins")
check(State.data.custom.Hatch.wings == "Angel", "wings auto-equipped")
check(req("BuyItem", "wings", "Angel") == false, "can't buy twice")
check(req("BuyItem", "eyes", "Lashes") == true, "bought lash eyes")
check(req("BuyItem", "trail", "Rainbow") == true, "bought rainbow trail")
check(req("BuyItem", "paint", "Jet Black") == false, "paints aren't shop items")
check(req("Customize", "Hatch", "wings", "None") == true, "unequip wings")
check(req("Customize", "Hatch", "wings", "Angel") == true, "re-equip owned wings")
HUD.OpenPanel("Customize")
G.run(0.2)
HUD.CloseAll()
check(req("TestDrive") == true, "test drive with cosmetics")
G.run(0.3)
local cosCar = CarService.Get(player)
local cos = cosCar and cosCar:FindFirstChild("Cosmetics")
local wingCount, lashCount = 0, 0
for _, dsc in cos and cos:GetChildren() or {} do
	if dsc.Name == "Wing" then
		wingCount += 1
	elseif dsc.Name == "Lash" then
		lashCount += 1
	end
end
check(wingCount == 10 and lashCount == 6, "wings and lashes built (" .. wingCount .. " feathers, " .. lashCount .. " lashes)")
local trail = cosCar and cosCar.PrimaryPart:FindFirstChild("CosmeticTrail")
check(trail ~= nil and trail.FaceCamera == false, "flat rainbow trail attached")
check(trail ~= nil and trail.Attachment0.Position.Y < -1.5, "trail sits low near the road")
for _, eyeStyle in Customization.Options.eyes do
	for _, carId in Cars.Order do
		local CarBuilder = G.require(Shared.CarBuilder)
		local m = CarBuilder.Build(carId, { eyes = eyeStyle.id, wings = "Dragon", trail = "Fire" }, true)
		check(m:FindFirstChild("Cosmetics") ~= nil, "cosmetics build: " .. carId .. " / " .. eyeStyle.id)
		m:Destroy()
	end
end
req("ExitCar")
G.run(0.3)

print("== robot visor")
do
	local CarBuilder = G.require(Shared.CarBuilder)
	local m = CarBuilder.Build("Hatch", { eyes = "Robot" }, true)
	local segs = m.Cosmetics:FindFirstChild("VisorSegments")
	check(segs ~= nil and #segs:GetChildren() == 11, "visor has 11 scanner segments")
	local cs = game:GetService("CollectionService")
	local tagged = false
	for _, t in cs:GetTagged("RobotVisor") do
		tagged = tagged or t == segs
	end
	check(tagged, "visor segments tagged for the scanner animation")
	local names = {}
	for _, p in m.Cosmetics:GetChildren() do
		names[p.Name] = (names[p.Name] or 0) + 1
	end
	check(names.VisorHousing == 1 and names.VisorLens == 1 and names.VisorAntenna == 2 and names.VisorPod == 2, "visor housing, lens, pods and antennas")
	m:Destroy()
end

print("== sprint routes")
for _, mapId in Maps.Order do
	local sprint = Maps.Sprint(mapId)
	local pts = {}
	for _, q in sprint.points do
		table.insert(pts, Vector3.new(q[1], q[2], q[3]))
	end
	local samples = TrackBuilder.Sample(pts, 8, true)
	local length, maxX, monotone, minR = 0, 0, true, math.huge
	for k = 2, #samples do
		length += (samples[k] - samples[k - 1]).Magnitude
		maxX = math.max(maxX, math.abs(samples[k].X))
		monotone = monotone and samples[k].Z > samples[k - 1].Z
	end
	for k = 3, #samples - 2 do
		local a, b, c = samples[k - 2], samples[k], samples[k + 2]
		local ab, bc, ac = (b - a).Magnitude, (c - b).Magnitude, (c - a).Magnitude
		local s = (ab + bc + ac) / 2
		local area = math.sqrt(math.max(s * (s - ab) * (s - bc) * (s - ac), 0))
		if area > 1e-6 then
			minR = math.min(minR, ab * bc * ac / (4 * area))
		end
	end
	check(
		length > 5000 and monotone and maxX < 1700 and minR > 60,
		string.format("%s sprint: %d studs long, max |x| %d, tightest bend r=%d", mapId, length, maxX, minR)
	)
end
do
	local built = TrackBuilder.Build(Maps.Sprint("Volcano"), Vector3.new(0, 0, 40000))
	check(built.open and #built.checkpoints >= 8 and #built.grid == 24, "sprint track builds (" .. #built.checkpoints .. " checkpoints)")
	local lastCP = built.checkpoints[#built.checkpoints].cf.Position
	local finish = built.frames[built.finishIndex].pos
	check((lastCP - finish).Magnitude < 12, "last checkpoint is the finish line")
	built.model:Destroy()
end

-- Races on all 8 maps (lobby round) ----------------------------------------------------------
for idx, mapId in Maps.Order do
	print("== race " .. idx .. ": " .. mapId)
	waitFor(function()
		return State.race.phase == "Intermission"
	end, 40, "intermission reached")
	check(req("Vote", mapId) == true, "voted " .. mapId)
	local wantType = idx == 1 and "Sprint" or "Circuit"
	check(req("VoteType", wantType) == true, "voted " .. wantType)
	waitFor(function()
		return State.race.phase == "Racing"
	end, 60, "race started")
	check(State.race.mapId == mapId and State.race.raceType == wantType, "voted map + type chosen")
	local session = Sessions.Get(player)
	check(session ~= nil and session.track.model.Parent == workspace.Tracks, "track in Tracks folder")
	print("   track parts:", session and G.countParts(session.track.model), "laps:", session and session.laps)
	if wantType == "Sprint" then
		check(session.laps == 1 and session.track.open == true, "sprint runs on an open road")
		check(session.map.name == Maps.List[mapId].name .. " Sprint", "sprint route named after the map")
	end
	local model = CarService.Get(player)
	check(model ~= nil and not model.PrimaryPart.Anchored, "race car released")
	finishInfo = nil
	local ticks = driveSession({ { player = player, speed = 1 } }, 5000)
	check(finishInfo ~= nil and finishInfo.place == 1, "finished 1st (" .. ticks .. " ticks)")
	waitFor(function()
		return State.race.phase == "Intermission" or State.race.phase == "Waiting"
	end, 30, "back to lobby")
	check(#workspace.Tracks:GetChildren() == 0, "track cleaned up")
	check(State.data.stats.races == idx, "race counted (" .. State.data.stats.races .. ")")
	print("   coins/level/xp:", State.data.coins, State.data.level, State.data.xp)
	local bestKey = mapId .. (wantType == "Sprint" and ":Sprint" or "")
	check(State.data.bestTimes[bestKey] ~= nil, "best time recorded")
	check(lastResult ~= nil and lastResult.xp == Config.Rewards.xpSolo, "solo race gives flat solo XP")
end

-- More players (server-only bots) -------------------------------------------------------------
local bot2 = G.makePlayer("Bot2", 2)
game.Players.PlayerAdded:Fire(bot2)
bot2:LoadCharacter()
local bot3 = G.makePlayer("Bot3", 3)
game.Players.PlayerAdded:Fire(bot3)
bot3:LoadCharacter()
G.run(1)

print("== elimination race (3 racers)")
waitFor(function()
	return State.race.phase == "Intermission"
end, 60, "intermission reached")
req("Vote", "Volcano")
req("VoteType", "Elimination")
waitFor(function()
	return State.race.phase == "Racing"
end, 60, "elimination started")
local elimSession = Sessions.Get(player)
check(elimSession ~= nil and elimSession.raceType == "Elimination" and elimSession.laps == 2, "elimination: 3 racers -> 2 laps")
lastPayload = nil
driveSession({
	{ player = player, speed = 3 },
	{ player = bot2, speed = 2 },
	{ player = bot3, speed = 1 },
}, 4000)
waitFor(function()
	return lastPayload ~= nil
end, 15, "elimination results")
local byId = {}
for _, entry in lastPayload and lastPayload.results or {} do
	byId[entry.userId] = entry
end
check(byId[1] and byId[1].place == 1, "leader won the elimination")
check(byId[3] and byId[3].eliminated and byId[3].place == 3, "last place was eliminated in 3rd")
check(byId[2] and byId[2].place == 2, "runner-up 2nd")
RaceService.SetQueued(bot2, false)
RaceService.SetQueued(bot3, false)
waitFor(function()
	return State.race.phase == "Intermission" or State.race.phase == "Waiting"
end, 30, "back to lobby")

print("== team match 1v1")
check(req("JoinTeamQueue", 1) == true, "joined 1v1 queue")
G.run(0.2)
check(State.race.teamQueues[1].count == 1, "queue count broadcast")
check(MatchService.Join(bot2, 1) == true, "bot joined 1v1 queue")
waitFor(function()
	local s = Sessions.Get(player)
	return s ~= nil and s.teams and s.phase == "Racing"
end, 30, "1v1 match racing")
local teamSession = Sessions.Get(player)
check(teamSession.label == "1v1", "match labelled 1v1")
check(teamSession.racers[player].team ~= teamSession.racers[bot2].team, "players on opposite teams")
lastPayload = nil
driveSession({ { player = player, speed = 3 }, { player = bot2, speed = 1 } }, 6000)
waitFor(function()
	return lastPayload ~= nil
end, 40, "team results")
local myTeam = teamSession.racers[player] and teamSession.racers[player].team
check(lastPayload and lastPayload.teams and lastPayload.teams.winner ~= nil, "team scores in results")
check(lastPayload and lastPayload.teams.winner == myTeam, "winning team is the 1st-place racer's")
local mine
for _, entry in lastPayload and lastPayload.results or {} do
	if entry.userId == 1 then
		mine = entry
	end
end
check(mine and mine.teamWin == true, "team-win bonus flagged")
waitFor(function()
	return Sessions.Get(player) == nil
end, 30, "match cleaned up")

print("== free drive")
check(req("FreeDrive", "NeonDrift") == true, "free drive started")
local free = Sessions.Get(player)
check(free ~= nil and free.raceType == "FreeDrive", "in free drive session")
local _, freeMode = CarService.Get(player)
check(freeMode == "free", "car in free mode")
check(CarController.IsActive(), "controller active in free drive")
local lapInfo
local lapConn = game.ReplicatedStorage.Remotes.Checkpoint.OnClientEvent:Connect(function(info)
	if info.freeLap then
		lapInfo = info
	end
end)
driveSession({ { player = player, speed = 2 } }, math.floor(#free.track.frames * 1.2 / 2))
check(lapInfo ~= nil and lapInfo.freeLap > 0, "free-drive lap time reported")
lapConn:Disconnect()
check(State.race.freeDrive.NeonDrift == 1, "free drive count broadcast")
check(req("JoinTeamQueue", 2) == true, "can queue for teams while free driving")
req("LeaveTeamQueue")
check(req("ExitCar") == true, "left free drive")
G.run(0.5)
check(Sessions.Get(player) == nil and CarService.Get(player) == nil, "free drive session left")
G.run(Config.FREE_DRIVE_EMPTY_GRACE + 3)
check(free.closed == true, "empty free-drive track removed")

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
