--!strict
--[[
	Constants
	Fixed identifiers used across systems. Unlike Config, these are not tuning
	values; changing them changes the protocol between server and client.
]]

local TableUtil = require(script.Parent.Utility.TableUtil)

local Constants = {
	RoundState = {
		Lobby = "LOBBY",
		Preparation = "PREPARATION",
		RoleAssignment = "ROLE_ASSIGNMENT",
		ActiveRound = "ACTIVE_ROUND",
		Emergency = "EMERGENCY",
		Discussion = "DISCUSSION",
		Voting = "VOTING",
		Endgame = "ENDGAME",
		Results = "RESULTS",
		Reset = "RESET",
	},

	Faction = {
		Crew = "Crew",
		Infiltrator = "Infiltrator",
	},

	PlayerStatus = {
		Connecting = "Connecting",
		Lobby = "Lobby",
		InRound = "InRound",
		Spectating = "Spectating",
	},

	-- Keys used with ReplicationService. Public keys go to everyone,
	-- private keys only ever go to the player they describe.
	PublicKey = {
		RoundState = "RoundState",
		PlayerCount = "PlayerCount",
		ServerVersion = "ServerVersion",
	},
	PrivateKey = {
		Session = "Session",
		-- Phase 4: Role = "Role"
	},

	NotificationKind = {
		Info = "Info",
		Warning = "Warning",
		Alert = "Alert",
	},
}

return TableUtil.deepFreeze(Constants)
