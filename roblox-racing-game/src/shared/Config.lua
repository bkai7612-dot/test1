-- Global game configuration shared by server and client.
local Config = {}

Config.GAME_NAME = "REDLINE RUSH"

-- Data
Config.DATASTORE_NAME = "RedlineRush_PlayerData_v1"
Config.LEADERBOARD_STORE = "RedlineRush_Wins_v1"
Config.AUTOSAVE_INTERVAL = 120
Config.STARTING_COINS = 1500

-- World layout (the lobby and race tracks live far apart)
Config.LOBBY_ORIGIN = Vector3.new(0, 0, 0)
Config.TRACK_ORIGIN = Vector3.new(0, 0, 5000)

-- Race flow timings (seconds)
Config.INTERMISSION_TIME = 25
Config.MIN_RACERS = 1
Config.COUNTDOWN = 3
Config.MAX_RACE_TIME = 420
Config.FINISH_GRACE = 30
Config.RESULTS_TIME = 10

-- Rewards
Config.Rewards = {
	base = 150, -- every finisher
	perLap = 50,
	perBeaten = 100, -- per opponent finished ahead of
	placeBonus = { 200, 120, 60 },
	xpBase = 60,
	xpPerLap = 15,
	xpPerBeaten = 25,
	xpPlaceBonus = { 80, 50, 30 },
	newBestCoins = 150,
	dnfCoins = 60,
	dnfXP = 20,
}

-- Daily login reward: base + perStreakDay * min(streak, maxStreak)
Config.Daily = {
	base = 250,
	perStreakDay = 100,
	maxStreak = 7,
	cooldown = 20 * 3600,
	streakReset = 48 * 3600,
}

-- Redeemable codes (case-insensitive)
Config.Codes = {
	LAUNCH = { coins = 1000, message = "Launch bonus: +1,000 coins!" },
	REDLINE = { coins = 2500, message = "Redline! +2,500 coins!" },
	NITRO = { xp = 400, message = "Nitro boost: +400 XP!" },
}

-- Suspension shared by the car builder (visual rest pose) and the client physics.
Config.Suspension = {
	restLength = 2.2, -- mount -> wheel centre at zero compression
	sag = 0.45, -- fraction of restLength compressed at rest
	dampingRatio = 0.35,
}

-- Display conversion from studs/second to "MPH" on the speedometer.
Config.SPEED_TO_MPH = 0.9

-- Optional sound ids (leave "" to disable). Upload your own or pick from the Creator Store.
Config.Sounds = {
	Engine = "",
	Countdown = "rbxasset://sounds/electronicpingshort.wav",
	Checkpoint = "rbxasset://sounds/electronicpingshort.wav",
}

-- Studio convenience: grant all game passes when testing in Studio.
Config.STUDIO_GRANTS_PASSES = false

return Config
