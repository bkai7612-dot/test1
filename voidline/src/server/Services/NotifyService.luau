--!strict
--[[
	NotifyService
	One place for player-facing messages:
	  Send/Broadcast  - toast + subtitle text (Notify remote)
	  Cue/CueAll      - one-shot audio/VFX/HUD cues (ShipEvent remote)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local RemoteService = require(script.Parent.RemoteService)

local NotifyService = {}

local function build(text: string, kind: Types.NotificationKind?, duration: number?): Types.Notification
	return { Text = text, Kind = kind or "Info", Duration = duration }
end

function NotifyService.Send(player: Player, text: string, kind: Types.NotificationKind?, duration: number?)
	RemoteService.FireClient(Net.Names.Notify, player, build(text, kind, duration))
end

function NotifyService.SendMany(players: { Player }, text: string, kind: Types.NotificationKind?, duration: number?)
	RemoteService.FireClients(Net.Names.Notify, players, build(text, kind, duration))
end

function NotifyService.Broadcast(text: string, kind: Types.NotificationKind?, duration: number?)
	RemoteService.FireAllClients(Net.Names.Notify, build(text, kind, duration))
end

function NotifyService.Cue(player: Player, kind: string, data: { [string]: any }?)
	RemoteService.FireClient(Net.Names.ShipEvent, player, kind, data or {})
end

function NotifyService.CueMany(players: { Player }, kind: string, data: { [string]: any }?)
	RemoteService.FireClients(Net.Names.ShipEvent, players, kind, data or {})
end

function NotifyService.CueAll(kind: string, data: { [string]: any }?)
	RemoteService.FireAllClients(Net.Names.ShipEvent, kind, data or {})
end

return NotifyService
