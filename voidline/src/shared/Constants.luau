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

	-- Winner values reported in results. "None" = aborted / ship lost with no infiltrators.
	Winner = {
		Crew = "Crew",
		Infiltrator = "Infiltrator",
		None = "None",
	},

	PlayerStatus = {
		Connecting = "Connecting",
		Lobby = "Lobby",
		InRound = "InRound",
		Spectating = "Spectating",
	},

	-- Server-side truth about a participant during a match.
	LifeState = {
		Alive = "Alive",
		Downed = "Downed", -- in stasis, can be revived
		Lost = "Lost", -- eliminated, now a Signal Ghost
		Confined = "Confined", -- removed by crew vote
		Escaped = "Escaped",
		Disconnected = "Disconnected",
	},

	-- What everyone else is allowed to know about a participant.
	-- "Lost" only becomes public at the next muster.
	PublicLifeState = {
		Active = "Active",
		Lost = "Lost",
		Confined = "Confined",
		Escaped = "Escaped",
		Disconnected = "Disconnected",
	},

	Section = {
		Fore = "Fore",
		Mid = "Mid",
		Aft = "Aft",
	},

	-- Keys used with ReplicationService. Public keys go to everyone,
	-- private keys only ever go to the player they describe.
	PublicKey = {
		RoundState = "RoundState",
		PlayerCount = "PlayerCount",
		ServerVersion = "ServerVersion",
		Lobby = "Lobby",
		Roster = "Roster",
		Meters = "Meters",
		Timer = "Timer",
		Hazards = "Hazards",
		Evidence = "Evidence",
		Meeting = "Meeting",
		Escape = "Escape",
		Results = "Results",
		SharedTasks = "SharedTasks",
		MatchInfo = "MatchInfo",
		Doors = "Doors",
	},
	PrivateKey = {
		Session = "Session",
		Profile = "Profile",
		Role = "Role",
		Tasks = "Tasks",
		Interactions = "Interactions",
		Abilities = "Abilities",
		PrivateEvidence = "PrivateEvidence",
		Carrying = "Carrying",
		Life = "Life",
		Reward = "Reward",
		IsAdmin = "IsAdmin",
		DataStatus = "DataStatus",
	},

	NotificationKind = {
		Info = "Info",
		Warning = "Warning",
		Alert = "Alert",
		Success = "Success",
	},

	MeetingAction = {
		Accuse = "Accuse",
		Skip = "Skip",
		Investigate = "Investigate",
		RequestEvidence = "RequestEvidence",
		EndDiscussion = "EndDiscussion",
	},

	CosmeticSlot = {
		Suit = "Suit",
		Helmet = "Helmet",
		Gloves = "Gloves",
		Back = "Back",
		Nameplate = "Nameplate",
		Title = "Title",
		Emote = "Emote",
	},

	-- Instance tags / attribute names shared by server and client.
	Tag = {
		InteractAnchor = "VoidlineInteractAnchor",
		RoomLight = "VoidlineRoomLight",
		Door = "VoidlineDoor",
		Station = "VoidlineStation",
	},
	Attribute = {
		AnchorId = "AnchorId",
		Frozen = "VoidlineFrozen",
		Accent = "VoidlineAccent",
		Room = "VoidlineRoom",
		Section = "VoidlineSection",
	},

	Ghost = {
		WhisperTag = "Whisper",
	},
}

return TableUtil.deepFreeze(Constants)
