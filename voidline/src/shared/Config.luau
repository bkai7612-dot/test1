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
		Version = "0.1.0-phase1",
	},

	Players = {
		MinPlayers = 6,
		MaxPlayers = 12,
		-- Lets a single developer start rounds in Studio playtests.
		AllowSoloInStudio = true,
		-- Seconds a client has to finish booting before the server logs a warning.
		LoadWarningSeconds = 30,
	},

	Roles = {
		-- Inclusive player-count brackets. RoleManager (Phase 4) picks a count in [Min, Max].
		InfiltratorScaling = {
			{ MinPlayers = 1, MaxPlayers = 6, Min = 1, Max = 1 },
			{ MinPlayers = 7, MaxPlayers = 9, Min = 1, Max = 2 },
			{ MinPlayers = 10, MaxPlayers = 12, Min = 2, Max = 3 },
		},
		-- Hard ceiling regardless of bracket, so odd configurations stay fair.
		MaxInfiltratorRatio = 0.34,
	},

	-- Durations in seconds. Consumed by the round state machine (Phase 3+).
	Timers = {
		LobbyCountdown = 20,
		Preparation = 5,
		RoleReveal = 6,
		Discussion = 60,
		Voting = 30,
		Results = 12,
	},

	Network = {
		-- Token bucket applied to client->server remotes that don't specify their own.
		DefaultRateLimit = { Capacity = 10, RefillPerSecond = 5 },
		-- Malformed requests (wrong types/arg counts) are never sent by a legitimate client.
		KickOnMalformedRequests = true,
		MalformedRequestKickThreshold = 15,
		MaxStringLength = 200,
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
		ShowDebugHud = true,
	},
}

return TableUtil.deepFreeze(Config)
