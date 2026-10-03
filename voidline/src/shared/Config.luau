--!strict
--[[
	Config
	Central tuning values for VOIDLINE. Every system reads its numbers from here
	so balancing never requires touching gameplay code.

	The table is deep-frozen: attempting to modify it at runtime throws.
	This module is replicated to clients, so NEVER put secrets here.
]]

local TableUtil = require(script.Parent.Utility.TableUtil)

local Config = {
	Game = {
		Title = "VOIDLINE", -- placeholder title
		ShipName = "ASTERION",
		AIName = "MURMUR", -- the rogue intelligence that compromises infiltrators
		Version = "1.0.0",
	},

	Players = {
		MinPlayers = 6,
		MaxPlayers = 12,
		-- Lets a single developer start rounds in Studio playtests.
		AllowSoloInStudio = true,
		-- Seconds a client has to finish booting before the server logs a warning.
		LoadWarningSeconds = 30,
		LobbyRespawnSeconds = 2,
	},

	Lobby = {
		-- Fraction of loaded players that must be ready to begin the countdown.
		ReadyRatioToStart = 0.6,
		CountdownSeconds = 20,
		-- Countdown is shortened to this when everyone is ready.
		AllReadyCountdownSeconds = 5,
		-- Once enough players are present, start anyway after this long.
		AutoStartAfterSeconds = 90,
		-- Private server owners may start with fewer players.
		PrivateServerMinPlayers = 4,
	},

	Roles = {
		-- Inclusive player-count brackets. RoleAllocator picks a count in [Min, Max].
		InfiltratorScaling = {
			{ MinPlayers = 1, MaxPlayers = 1, Min = 0, Max = 0 }, -- solo practice
			{ MinPlayers = 2, MaxPlayers = 6, Min = 1, Max = 1 },
			{ MinPlayers = 7, MaxPlayers = 9, Min = 1, Max = 2 },
			{ MinPlayers = 10, MaxPlayers = 12, Min = 2, Max = 3 },
		},
		-- Hard ceiling regardless of bracket, so odd configurations stay fair.
		MaxInfiltratorRatio = 0.34,
		-- Weight multiplier for players who were infiltrators last round (anti-streak).
		RepeatInfiltratorWeight = 0.35,
	},

	Round = {
		PreparationSeconds = 5,
		RoleRevealSeconds = 7,
		ResultsSeconds = 15,
		ResetSeconds = 3,
		-- Safety cap; the ship collapses if a round somehow runs this long.
		MaxRoundSeconds = 1500,
		StabilityStart = 100,
		StabilityDecayPerMinute = 3.5,
		StabilityPerCrewStep = 0.6,
		StartRooms = { "CentralOps", "CrewQuarters", "CargoStorage" },
		PresenceSampleSeconds = 1,
		PresenceHistorySeconds = 180,
	},

	Objectives = {
		TasksPerPlayer = 5,
		MaxCarryTasks = 1,
		MinLongTasks = 1,
		MaxLongTasks = 2,
		InteractRange = 9,
		RangeTolerance = 3,
		-- Holds must last at least this fraction of the advertised duration.
		MinHoldRatio = 0.85,
		FailCooldownSeconds = 4,
		MinigameGraceSeconds = 4,
	},

	Elimination = {
		SiphonRange = 7,
		SiphonChannelSeconds = 1.25,
		SiphonCooldown = 32,
		InitialSiphonCooldown = 22,
		-- Siphon fails if this many other active crew are within CrowdRadius of the target.
		CrowdBlockCount = 2,
		CrowdRadius = 11,
		StasisBleedSeconds = 25,
		ReviveHoldSeconds = 4,
		ShakenProtectionSeconds = 45,
		ScrubHoldSeconds = 3,
		ScanHoldSeconds = 2.5,
		ReportHoldSeconds = 0,
		WitnessRadius = 38,
		SafeRooms = { "EmergencyShelter" },
		CancelledSiphonCooldown = 12,
	},

	Sabotage = {
		GlobalCooldown = 28,
		InitialCooldown = 25,
		-- Chance a sabotage leaves a trace of the saboteur's room in the logs.
		TraceChance = 0.5,
		SpoofUsesPerRound = 1,
		CriticalFailStabilityLoss = 30,
		DualValveWindowSeconds = 4,
	},

	Meeting = {
		DiscussionSeconds = 60,
		VotingSeconds = 30,
		ResultSeconds = 7,
		BeaconUsesPerPlayer = 1,
		BeaconCooldownSeconds = 20,
		-- Fraction of living participants that must request ending discussion early.
		EndDiscussionRatio = 0.5,
		-- "Faction" reveals the confined player's faction, "None" reveals nothing.
		RevealOnConfine = "Faction",
		AnonymousVotes = true,
		AuditTokenOnReport = true,
	},

	Escape = {
		TotalSeconds = 180,
		StepHoldSeconds = 4,
		ExtractionCountdown = 40,
	},

	Events = {
		Enabled = true,
		FirstEventAfter = 55,
		MinInterval = 55,
		MaxInterval = 100,
		MaxConcurrent = 2,
		SignalRevealsInfiltratorCount = true,
	},

	Chat = {
		ProximityRadius = 70,
		RadioEnabled = true,
	},

	Ghost = {
		WhisperCooldown = 45,
		WhisperDuration = 6,
		GlobalWhisperGap = 8,
	},

	Movement = {
		WalkSpeed = 14,
		SprintSpeed = 21,
		StaminaSeconds = 5,
		StaminaRegenPerSecond = 0.8,
	},

	Progression = {
		BaseXpPerLevel = 100,
		XpPerLevelGrowth = 40,
		MaxLevel = 100,
	},

	Rewards = {
		Xp = {
			RoundComplete = 40,
			Win = 60,
			TaskStep = 6,
			TaskComplete = 10,
			Survive = 25,
			Escape = 40,
			Revive = 25,
			Scan = 8,
			EvidenceRevealed = 5,
			CorrectVote = 15,
			Siphon = 20,
			Sabotage = 6,
			MeetingSurvivedAsInfiltrator = 15,
			FixHazard = 10,
		},
		CreditsPerXp = 0.4,
		WinCredits = 20,
		TutorialCredits = 50,
	},

	Data = {
		StoreName = "VoidlineProfiles_v1",
		AutosaveSeconds = 120,
		-- A lock not refreshed for this long is considered abandoned (crashed server).
		LockStaleSeconds = 330,
		LoadAttempts = 6,
		LoadRetryDelay = 3,
		ReceiptHistory = 50,
	},

	Network = {
		-- Token bucket applied to client->server remotes that don't specify their own.
		DefaultRateLimit = { Capacity = 10, RefillPerSecond = 5 },
		-- Malformed requests (wrong types/arg counts) are never sent by a legitimate client.
		KickOnMalformedRequests = true,
		MalformedRequestKickThreshold = 15,
		MaxStringLength = 200,
	},

	AntiCheat = {
		Enabled = true,
		CheckInterval = 0.5,
		-- Horizontal speed allowed = SprintSpeed * SpeedTolerance + FlatAllowance/interval.
		SpeedTolerance = 1.6,
		FlatAllowance = 4,
		ViolationsBeforeCorrection = 3,
		TeleportGraceSeconds = 2,
		FrozenDriftAllowance = 5,
	},

	Monetization = {
		-- Cosmetic credit packs (Developer Products). Id 0 = disabled.
		CreditPacks = {
			{ ProductId = 0, Credits = 500 },
			{ ProductId = 0, Credits = 1200 },
			{ ProductId = 0, Credits = 3000 },
		},
		-- Game pass granting the purely cosmetic "Supporter" nameplate. 0 = disabled.
		SupporterPassId = 0,
	},

	Logging = {
		MinLevel = "Info", -- live servers
		StudioMinLevel = "Debug", -- Studio playtests
	},

	Admin = {
		-- Developer UserIds allowed to use debug tools. Add yours here.
		UserIds = {} :: { number },
		-- Everyone is treated as an admin inside Studio playtests.
		AllowStudioAdmins = true,
		-- The owner of a user-owned experience is always an admin.
		AllowGameOwner = true,
	},

	Debug = {
		ShowDebugHud = false,
	},
}

return TableUtil.deepFreeze(Config)
