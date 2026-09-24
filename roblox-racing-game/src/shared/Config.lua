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
-- Several races can run at once (lobby round, team matches, free drive);
-- each gets its own copy of a track, this far apart along X.
Config.TRACK_SLOT_SPACING = 6000

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
	-- XP by finishing position when 2+ players race.
	xpByPlace = { 250, 175, 125 }, -- 1st, 2nd, 3rd
	xpFinish = 75, -- 4th place and below
	-- Racing alone always gives 1st place, so it earns a flat amount instead
	-- of podium XP (stops solo farming, still rewards practising).
	xpSolo = 100,
	newBestCoins = 150,
	-- Team matches: every member of the winning team also gets this.
	teamWinCoins = 250,
	teamWinXP = 100,
	dnfCoins = 60,
	dnfXP = 20,
}

-- Team matches (1v1 up to 5v5) from the Team Arena in the lobby.
Config.TeamSizes = { 1, 2, 3, 4, 5 }
Config.Teams = {
	Red = { name = "RED", color = Color3.fromRGB(235, 60, 60) },
	Blue = { name = "BLUE", color = Color3.fromRGB(60, 140, 255) },
}
-- Points by finishing position; the team with the most points wins.
Config.TeamPoints = { 25, 18, 15, 12, 10, 8, 6, 4, 2, 1 }
-- Seconds between a team queue filling up and the match loading.
Config.MATCH_START_DELAY = 4

-- Free drive tracks are removed this many seconds after the last driver leaves.
Config.FREE_DRIVE_EMPTY_GRACE = 10

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
