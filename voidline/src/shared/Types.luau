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
export type Winner = "Crew" | "Infiltrator" | "None"

export type PlayerStatus = "Connecting" | "Lobby" | "InRound" | "Spectating"

export type LifeState = "Alive" | "Downed" | "Lost" | "Confined" | "Escaped" | "Disconnected"
export type PublicLifeState = "Active" | "Lost" | "Confined" | "Escaped" | "Disconnected"

-- Server-only record describing a connected player. Never sent to clients as-is.
export type PlayerSession = {
	Player: Player,
	UserId: number,
	JoinedAt: number,
	Status: PlayerStatus,
	IsLoaded: boolean,
}

export type NotificationKind = "Info" | "Warning" | "Alert" | "Success"

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

-- Per-round stats tracked for rewards and analytics.
export type RoundStats = {
	TaskSteps: number,
	TasksCompleted: number,
	Revives: number,
	Scans: number,
	EvidenceRevealed: number,
	CorrectVotes: number,
	Siphons: number,
	Sabotages: number,
	MeetingsSurvived: number,
	HazardsFixed: number,
}

-- Random source for pure logic: a Roblox Random, or the test shim (which
-- provides NextInteger/NextNumber). Typed loosely because Roblox's Random is a
-- class type that table types can't describe structurally.
export type Rng = any

-- One entry of the private "Interactions" list sent to a client.
export type InteractionEntry = {
	Anchor: string,
	Action: string,
	Object: string,
	Hold: number,
	Key: number,
	Range: number,
}

export type EvidenceEntry = {
	Id: string,
	Time: number, -- seconds since round start
	Kind: string,
	Room: string?,
	Text: string,
	SharedBy: string?,
}

return {}
