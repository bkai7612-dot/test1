--!strict
--[[
	Types
	Shared Luau type definitions. Require this module and reference types as
	`Types.PlayerSession` etc. It contains no runtime values.
]]

export type RoundState =
	"LOBBY"
	| "PREPARATION"
	| "ROLE_ASSIGNMENT"
	| "ACTIVE_ROUND"
	| "EMERGENCY"
	| "DISCUSSION"
	| "VOTING"
	| "ENDGAME"
	| "RESULTS"
	| "RESET"

export type Faction = "Crew" | "Infiltrator"

export type PlayerStatus = "Connecting" | "Lobby" | "InRound" | "Spectating"

-- Server-only record describing a connected player. Never sent to clients as-is.
export type PlayerSession = {
	Player: Player,
	UserId: number,
	JoinedAt: number,
	Status: PlayerStatus,
	IsLoaded: boolean,
}

export type NotificationKind = "Info" | "Warning" | "Alert"

export type Notification = {
	Text: string,
	Kind: NotificationKind,
	Duration: number?,
}

-- Returned by the RequestSnapshot remote so a client can sync its state mirror.
export type StateSnapshot = {
	Public: { [string]: any },
	PublicVersion: number,
	Private: { [string]: any },
	PrivateVersion: number,
	ServerTime: number,
}

-- Lifecycle contract every server service / client controller follows.
-- Init: create state, no cross-service calls that assume others started.
-- Start: connect events, call other services. Must not yield for long.
-- Shutdown: (server) flush work during BindToClose.
export type Lifecycle = {
	Init: (() -> ())?,
	Start: (() -> ())?,
	Shutdown: (() -> ())?,
}

return {}
