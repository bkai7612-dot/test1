--!strict
--[[
	AudioCatalog
	Every sound the game plays. AssetId values are intentionally EMPTY
	placeholders: VOIDLINE ships no third-party audio. Upload original or
	properly licensed sounds to your Roblox account/group and paste their
	"rbxassetid://<id>" here. Sounds without an AssetId are skipped, but their
	Caption is still shown (subtitles / audio cue alternatives), so no
	information is ever carried by sound alone.
]]

local TableUtil = require(script.Parent.Parent.Utility.TableUtil)

export type Sound = {
	AssetId: string,
	Group: "Music" | "Effects" | "Ambient" | "UI",
	Volume: number,
	Looped: boolean?,
	Caption: string?,
}

local SOUNDS: { [string]: Sound } = {
	-- Ambience and music
	AmbientShip = { AssetId = "", Group = "Ambient", Volume = 0.4, Looped = true },
	AmbientLobby = { AssetId = "", Group = "Ambient", Volume = 0.3, Looped = true },
	MusicMenu = { AssetId = "", Group = "Music", Volume = 0.5, Looped = true },
	MusicEndgame = { AssetId = "", Group = "Music", Volume = 0.6, Looped = true, Caption = "[Urgent music]" },
	-- Ship events
	Alarm = { AssetId = "", Group = "Effects", Volume = 0.6, Caption = "[Alarm blaring]" },
	CriticalAlarm = { AssetId = "", Group = "Effects", Volume = 0.8, Caption = "[Critical alarm]" },
	Sparks = { AssetId = "", Group = "Effects", Volume = 0.5, Caption = "[Sparks crackle]" },
	Door = { AssetId = "", Group = "Effects", Volume = 0.5, Caption = "[Door seals]" },
	Siphon = { AssetId = "", Group = "Effects", Volume = 0.7, Caption = "[Distorted hum nearby]" },
	Revive = { AssetId = "", Group = "Effects", Volume = 0.6, Caption = "[Stasis shatters]" },
	Whisper = { AssetId = "", Group = "Effects", Volume = 0.6, Caption = "[Static whispers]" },
	Announcement = { AssetId = "", Group = "Effects", Volume = 0.6, Caption = "[Ship intercom chime]" },
	MeetingCalled = { AssetId = "", Group = "Effects", Volume = 0.8, Caption = "[Muster klaxon]" },
	Extraction = { AssetId = "", Group = "Effects", Volume = 0.8, Caption = "[Launch sequence engaged]" },
	-- Objectives and UI
	StepComplete = { AssetId = "", Group = "UI", Volume = 0.5 },
	TaskFail = { AssetId = "", Group = "UI", Volume = 0.5, Caption = "[Error buzz]" },
	Click = { AssetId = "", Group = "UI", Volume = 0.3 },
	Notify = { AssetId = "", Group = "UI", Volume = 0.4 },
	Victory = { AssetId = "", Group = "Music", Volume = 0.7 },
	Defeat = { AssetId = "", Group = "Music", Volume = 0.7 },
}

local AudioCatalog = {}
AudioCatalog.Sounds = SOUNDS

function AudioCatalog.get(id: string): Sound?
	return SOUNDS[id]
end

return TableUtil.deepFreeze(AudioCatalog)
