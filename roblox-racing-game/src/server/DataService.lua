-- Player profiles: loading, saving (DataStore), currency, XP / levels,
-- leaderstats, daily rewards and the global wins leaderboard.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local Upgrades = require(Shared.Upgrades)
local Customization = require(Shared.Customization)
local Cars = require(Shared.Cars)
local Remotes = require(Shared.Remotes)

local DataService = {}

local profiles = {} -- [player] = { data = table, canSave = bool, key = string, passes = {} }
local loadedSignal = Instance.new("BindableEvent")

local store, winsStore
do
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
		winsStore = DataStoreService:GetOrderedDataStore(Config.LEADERBOARD_STORE)
	end)
	if not ok then
		warn("[DataService] DataStores unavailable (enable Studio API access to save):", err)
	end
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function defaultProfile()
	return {
		version = 1,
		coins = Config.STARTING_COINS,
		xp = 0,
		level = 1,
		selectedCar = "Hatch",
		owned = { Hatch = true },
		upgrades = {},
		custom = {},
		stats = { races = 0, wins = 0, podiums = 0 },
		bestTimes = {},
		receipts = {},
		receiptOrder = {},
		codes = {},
		lastDaily = 0,
		dailyStreak = 0,
	}
end

local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and key == "stats" then
			reconcile(data[key], value)
		end
	end
end

function DataService.EnsureCar(data, carId)
	data.upgrades[carId] = data.upgrades[carId] or Upgrades.Default()
	for _, stat in Upgrades.Order do
		data.upgrades[carId][stat] = data.upgrades[carId][stat] or 0
	end
	data.custom[carId] = data.custom[carId] or Customization.Default(carId)
	local defaults = Customization.Default(carId)
	for key, value in defaults do
		if data.custom[carId][key] == nil then
			data.custom[carId][key] = value
		end
	end
end

local function sanitize(data)
	if not Cars.List[data.selectedCar] or not data.owned[data.selectedCar] then
		data.selectedCar = "Hatch"
	end
	data.owned.Hatch = true
	if data.level > Levels.MAX then
		data.level = Levels.MAX
		data.xp = 0
	end
	for carId in data.owned do
		if Cars.List[carId] then
			DataService.EnsureCar(data, carId)
		end
	end
end

---------------------------------------------------------------------------
-- Access
---------------------------------------------------------------------------

function DataService.Get(player)
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.WaitFor(player, timeout)
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return DataService.Get(player)
end

function DataService.HasPass(player, key)
	local profile = profiles[player]
	return profile ~= nil and profile.passes[key] == true
end

function DataService.SetPass(player, key, owned)
	local profile = profiles[player]
	if profile then
		profile.passes[key] = owned and true or nil
		DataService.Push(player)
	end
end

function DataService.OnLoaded(callback)
	return loadedSignal.Event:Connect(callback)
end

-- The profile as the client sees it.
function DataService.View(player)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local d = profile.data
	return {
		coins = d.coins,
		xp = d.xp,
		level = d.level,
		xpNeeded = Levels.XPForLevel(d.level),
		maxLevel = Levels.MAX,
		selectedCar = d.selectedCar,
		owned = d.owned,
		upgrades = d.upgrades,
		custom = d.custom,
		stats = d.stats,
		bestTimes = d.bestTimes,
		passes = profile.passes,
		canSave = profile.canSave,
	}
end

function DataService.Push(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local d = profile.data
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Level.Value = d.level
		stats.Wins.Value = d.stats.wins
		stats.Coins.Value = d.coins
	end
	Remotes.Event("DataUpdated"):FireClient(player, DataService.View(player))
end

function DataService.Notify(player, text, kind)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

---------------------------------------------------------------------------
-- Currency / XP
---------------------------------------------------------------------------

function DataService.AddCoins(player, amount)
	local d = DataService.Get(player)
	if not d then
		return
	end
	d.coins = math.max(0, d.coins + math.floor(amount))
end

function DataService.SpendCoins(player, amount)
	local d = DataService.Get(player)
	if not d or d.coins < amount then
		return false
	end
	d.coins -= amount
	return true
end

-- Adds XP and handles level-ups. Returns the coins that capped XP was
-- converted into (0 below the level cap).
function DataService.AddXP(player, amount)
	local d = DataService.Get(player)
	if not d then
		return 0
	end
	d.xp += math.floor(amount)
	while d.level < Levels.MAX and d.xp >= Levels.XPForLevel(d.level) do
		d.xp -= Levels.XPForLevel(d.level)
		d.level += 1
		local bonus = Levels.LevelReward(d.level)
		if d.level >= Levels.MAX then
			bonus += Levels.MAX_LEVEL_BONUS
			DataService.Notify(
				player,
				string.format("MAX LEVEL %d REACHED!  (+%d coins) XP now converts to coins.", d.level, bonus),
				"levelup"
			)
		else
			DataService.Notify(player, string.format("LEVEL UP! You reached level %d  (+%d coins)", d.level, bonus), "levelup")
		end
		d.coins += bonus
		for _, carId in Cars.Order do
			if Cars.List[carId].level == d.level then
				DataService.Notify(player, Cars.List[carId].name .. " is now available in the Garage!", "success")
			end
		end
	end
	if d.level >= Levels.MAX then
		-- At the cap, XP turns into coins instead.
		local coins = math.floor(d.xp * Levels.MAX_XP_TO_COINS)
		d.xp = 0
		d.coins += coins
		return coins
	end
	return 0
end

---------------------------------------------------------------------------
-- Receipts (idempotent Robux grants)
---------------------------------------------------------------------------

function DataService.HasReceipt(player, purchaseId)
	local d = DataService.Get(player)
	return d ~= nil and d.receipts[purchaseId] ~= nil
end

function DataService.AddReceipt(player, purchaseId)
	local d = DataService.Get(player)
	if not d then
		return
	end
	d.receipts[purchaseId] = os.time()
	table.insert(d.receiptOrder, purchaseId)
	while #d.receiptOrder > 100 do
		local old = table.remove(d.receiptOrder, 1)
		d.receipts[old] = nil
	end
end

---------------------------------------------------------------------------
-- Load / save
---------------------------------------------------------------------------

function DataService.Save(player)
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return false
	end
	local ok, err = pcall(function()
		store:UpdateAsync(profile.key, function()
			return profile.data
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
	end
	if winsStore then
		pcall(function()
			winsStore:SetAsync(tostring(player.UserId), profile.data.stats.wins)
		end)
	end
	return ok
end

local function giveDaily(player, data)
	local now = os.time()
	local since = now - (data.lastDaily or 0)
	if since < Config.Daily.cooldown then
		return
	end
	if since > Config.Daily.streakReset then
		data.dailyStreak = 1
	else
		data.dailyStreak = math.min((data.dailyStreak or 0) + 1, Config.Daily.maxStreak)
	end
	data.lastDaily = now
	local reward = Config.Daily.base + Config.Daily.perStreakDay * (data.dailyStreak - 1)
	data.coins += reward
	task.delay(4, function()
		if player.Parent then
			DataService.Notify(
				player,
				string.format("Daily reward! Day %d streak: +%d coins", data.dailyStreak, reward),
				"success"
			)
		end
	end)
end

local function createLeaderstats(player, data)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = data.level
	level.Parent = folder
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = data.stats.wins
	wins.Parent = folder
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.coins
	coins.Parent = folder
	folder.Parent = player
end

local function load(player)
	local key = "Player_" .. player.UserId
	local data, success = nil, false
	if store then
		for attempt = 1, 4 do
			local ok, result = pcall(function()
				return store:GetAsync(key)
			end)
			if ok then
				data = result
				success = true
				break
			end
			warn("[DataService] Load attempt", attempt, "failed for", player.Name, result)
			task.wait(attempt * 1.5)
		end
	end
	if not player.Parent then
		return
	end
	if type(data) ~= "table" then
		data = defaultProfile()
	end
	reconcile(data, defaultProfile())
	sanitize(data)
	giveDaily(player, data)

	profiles[player] = { data = data, canSave = success, key = key, passes = {} }
	createLeaderstats(player, data)
	loadedSignal:Fire(player)
	DataService.Push(player)
	if not success then
		task.delay(5, function()
			if player.Parent then
				DataService.Notify(player, "Progress is not being saved this session (DataStore unavailable).", "error")
			end
		end)
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- Top N players by wins: { {name, wins}, ... }
function DataService.GetTopWins(count)
	if not winsStore then
		return {}
	end
	local ok, pages = pcall(function()
		return winsStore:GetSortedAsync(false, count)
	end)
	if not ok then
		return {}
	end
	local out = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		local name = "Racer"
		if userId then
			local okName, result = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if okName then
				name = result
			end
		end
		table.insert(out, { name = name, wins = entry.value })
	end
	return out
end

return DataService
