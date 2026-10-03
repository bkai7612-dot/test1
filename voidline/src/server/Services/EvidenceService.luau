--!strict
--[[
	EvidenceService
	Investigation data. Evidence never names a culprit; it gives facts
	players must interpret ("Reactor Chamber door log: 3 passages between
	04:10 and 04:40", "Stasis residue: accent trace ▲ Amber").

	Three visibilities:
	  Public  - in the ship log everyone sees (and shown at musters)
	  Hidden  - recorded by security systems; revealed when someone downloads
	            logs at the Security Terminal or requests evidence at a muster
	  Private - personal knowledge (witnessing a siphon); can be shared to the
	            public log at a muster, attributed to the sharer
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local ShipLayout = require(Shared.Data.ShipLayout)
local Format = require(Shared.Utility.Format)
local Validate = require(Shared.Utility.Validate)

local InteractionService = require(script.Parent.InteractionService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local RemoteService = require(script.Parent.RemoteService)
local ReplicationService = require(script.Parent.ReplicationService)

local EvidenceService = {}

local MAX_PUBLIC = 60
local TERMINAL_COOLDOWN = 30

type Entry = Types.EvidenceEntry

local publicLog: { Entry } = {}
local hidden: { Entry } = {}
local private: { [Player]: { Entry } } = {}
local counter = 0
local terminalReadyAt = 0
local lastIncidentTime: number? = nil

-- Hooks set by HazardService (avoids a circular require).
EvidenceService.IsSectionJammed = function(_section: string): boolean
	return false
end

local function nextId(): string
	counter += 1
	return "E" .. counter
end

local function make(kind: string, area: string?, text: string, time: number?): Entry
	return {
		Id = nextId(),
		Time = time or MatchService.RoundTime(),
		Kind = kind,
		Room = area,
		Text = text,
	}
end

local function publishPublic()
	while #publicLog > MAX_PUBLIC do
		table.remove(publicLog, 1)
	end
	ReplicationService.SetPublic(Constants.PublicKey.Evidence, publicLog)
end

local function publishPrivate(player: Player)
	ReplicationService.SetPrivate(player, Constants.PrivateKey.PrivateEvidence, private[player] or {})
end

function EvidenceService.clock(t: number): string
	return Format.clock(t)
end

function EvidenceService.AddPublic(kind: string, area: string?, text: string, time: number?): Entry
	local entry = make(kind, area, text, time)
	table.insert(publicLog, entry)
	publishPublic()
	return entry
end

function EvidenceService.AddHidden(kind: string, area: string?, text: string, time: number?): Entry
	local entry = make(kind, area, text, time)
	table.insert(hidden, entry)
	return entry
end

function EvidenceService.AddPrivate(player: Player, kind: string, area: string?, text: string, time: number?): Entry
	local entry = make(kind, area, text, time)
	private[player] = private[player] or {}
	table.insert(private[player], entry)
	publishPrivate(player)
	return entry
end

-- Moves every hidden entry into the public log. Returns how many.
function EvidenceService.RevealHidden(revealer: Player?): number
	local count = #hidden
	if count == 0 then
		return 0
	end
	table.sort(hidden, function(a, b)
		return a.Time < b.Time
	end)
	for _, entry in hidden do
		table.insert(publicLog, entry)
	end
	table.clear(hidden)
	publishPublic()
	if revealer then
		local p = MatchService.GetParticipant(revealer)
		if p then
			p.Stats.EvidenceRevealed += count
		end
	end
	return count
end

function EvidenceService.HiddenCount(): number
	return #hidden
end

-- Shares one of `player`'s private entries to the public log.
function EvidenceService.Share(player: Player, entryId: string): boolean
	local list = private[player]
	if not list then
		return false
	end
	for index, entry in list do
		if entry.Id == entryId then
			table.remove(list, index)
			local shared = table.clone(entry)
			shared.Id = nextId()
			shared.SharedBy = player.DisplayName
			table.insert(publicLog, shared)
			publishPublic()
			publishPrivate(player)
			return true
		end
	end
	return false
end

-- Records security data around an incident at `area`, captured a few seconds
-- later so movement right after the incident is included.
function EvidenceService.RecordIncident(area: string?, time: number)
	lastIncidentTime = time
	local room = ShipLayout.areaRoom(area)
	if not room then
		return
	end
	local section = ShipLayout.areaSection(room)
	task.delay(10, function()
		if not MatchService.IsRunning() then
			return
		end
		if section and EvidenceService.IsSectionJammed(section) then
			EvidenceService.AddHidden("DoorLog", room, string.format("%s door log: corrupted by interference near %s.", ShipLayout.areaName(room), Format.clock(time)), time)
			return
		end
		local t0, t1 = math.max(0, time - 20), time + 10
		local changes = MatchService.AreaChangesNear({ room }, t0, t1)
		local text
		if #changes == 0 then
			text = string.format("%s door log: no passages between %s and %s.", ShipLayout.areaName(room), Format.clock(t0), Format.clock(t1))
		else
			local stamps = {}
			for i, change in changes do
				if i > 6 then
					break
				end
				table.insert(stamps, Format.clock(change.Time))
			end
			text = string.format(
				"%s door log: %d passage%s between %s and %s (%s).",
				ShipLayout.areaName(room),
				#changes,
				if #changes == 1 then "" else "s",
				Format.clock(t0),
				Format.clock(t1),
				table.concat(stamps, ", ")
			)
		end
		EvidenceService.AddHidden("DoorLog", room, text, time)

		if table.find(ShipLayout.CameraRooms, room) then
			local present = #MatchService.PresentAt({ room }, time)
			EvidenceService.AddHidden(
				"Camera",
				room,
				string.format("Camera feed, %s at %s: %d figure%s in frame.", ShipLayout.areaName(room), Format.clock(time), present, if present == 1 then "" else "s"),
				time
			)
		end
	end)
end

function EvidenceService.LastIncidentTime(): number?
	return lastIncidentTime
end

function EvidenceService.Clear()
	table.clear(publicLog)
	table.clear(hidden)
	for player in private do
		if player.Parent == Players then
			ReplicationService.SetPrivate(player, Constants.PrivateKey.PrivateEvidence, nil)
		end
	end
	table.clear(private)
	lastIncidentTime = nil
	terminalReadyAt = 0
	ReplicationService.SetPublic(Constants.PublicKey.Evidence, nil)
end

-- Security Terminal: downloads hidden logs into the public ship log.
local function registerTerminal()
	InteractionService.Register({
		Id = "SecurityTerminal",
		Anchor = "Fixture:SecurityTerminal",
		Action = "Download logs",
		Object = "Security Terminal",
		Hold = 3,
		Visible = function(player)
			return MatchService.InPlay() and MatchService.IsActive(player)
		end,
		CanBegin = function()
			if EvidenceService.IsSectionJammed("Fore") then
				return false, "The terminal is jammed."
			end
			if os.clock() < terminalReadyAt then
				return false, string.format("Terminal rebooting (%ds).", math.ceil(terminalReadyAt - os.clock()))
			end
			return true
		end,
		OnComplete = function(player)
			terminalReadyAt = os.clock() + TERMINAL_COOLDOWN
			local count = EvidenceService.RevealHidden(player)
			if count > 0 then
				NotifyService.Broadcast(string.format("Security logs downloaded: %d new entr%s in the ship log.", count, if count == 1 then "y" else "ies"), "Info", 4)
			else
				NotifyService.Send(player, "No new security records.", "Info", 3)
			end
		end,
	})
end

function EvidenceService.Start()
	registerTerminal()

	RemoteService.OnEvent(Net.Names.ShareEvidence, { Validate.string(20) }, function(player: Player, entryId: string)
		if not MatchService.IsState(Constants.RoundState.Discussion, Constants.RoundState.Voting) then
			return
		end
		if not MatchService.IsActive(player) then
			return
		end
		if EvidenceService.Share(player, entryId) then
			NotifyService.Broadcast(player.DisplayName .. " shared evidence with the crew.", "Info", 3)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		private[player] = nil
	end)
end

return EvidenceService
