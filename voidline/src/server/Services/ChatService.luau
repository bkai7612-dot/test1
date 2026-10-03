--!strict
--[[
	ChatService
	Social communication rules on top of Roblox TextChatService (so Roblox's
	own filtering, safety and age rules always apply).

	General channel delivery during a match:
	  * Living players hear each other within ProximityRadius studs; during
	    musters everyone living hears everyone.
	  * Signal Ghosts (lost/confined) and spectators talk only among
	    themselves, but can read the living.
	Radio channel:
	  * Ship-wide channel for living participants while the ship is in play,
	    silenced for anyone standing in a jammed section.
	Jammed sections also garble text locally (client ChatController).

	Voice chat uses Roblox's built-in spatial voice, which is already
	proximity based; we don't alter it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local ShipLayout = require(Shared.Data.ShipLayout)
local Logger = require(Shared.Utility.Logger)

local CharacterService = require(script.Parent.CharacterService)
local HazardService = require(script.Parent.HazardService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)

local log = Logger.new("ChatService")

local ChatService = {}

local radio: TextChannel? = nil

local S = Constants.RoundState

local function isLiving(p: MatchService.Participant?): boolean
	return p ~= nil and (p.Life == Constants.LifeState.Alive or p.Life == Constants.LifeState.Downed)
end

local function sectionOf(player: Player): string?
	local root = CharacterService.GetRoot(player)
	if not root then
		return nil
	end
	return ShipLayout.areaSection(MapService.AreaAt(root.Position))
end

local function shouldDeliverGeneral(message: TextChatMessage, target: TextSource): boolean
	if not MatchService.IsRunning() then
		return true
	end
	local source = message.TextSource
	if not source then
		return true
	end
	local sender = Players:GetPlayerByUserId(source.UserId)
	local recipient = Players:GetPlayerByUserId(target.UserId)
	if not sender or not recipient or sender == recipient then
		return true
	end
	local sp = MatchService.GetParticipant(sender)
	local rp = MatchService.GetParticipant(recipient)
	local senderLiving = isLiving(sp)
	local recipientLiving = isLiving(rp)

	if not senderLiving then
		-- Ghosts and spectators: only other ghosts/spectators hear them.
		return not recipientLiving
	end
	if not recipientLiving then
		return true
	end
	if MatchService.IsState(S.Discussion, S.Voting, S.Results, S.Preparation, S.RoleAssignment) then
		return true
	end
	local a = CharacterService.GetRoot(sender)
	local b = CharacterService.GetRoot(recipient)
	if not a or not b then
		return false
	end
	return (a.Position - b.Position).Magnitude <= Config.Chat.ProximityRadius
end

local function shouldDeliverRadio(message: TextChatMessage, target: TextSource): boolean
	if not Config.Chat.RadioEnabled or not MatchService.IsRunning() then
		return false
	end
	local source = message.TextSource
	if not source then
		return false
	end
	local sender = Players:GetPlayerByUserId(source.UserId)
	local recipient = Players:GetPlayerByUserId(target.UserId)
	if not sender or not recipient then
		return false
	end
	if not isLiving(MatchService.GetParticipant(sender)) or not isLiving(MatchService.GetParticipant(recipient)) then
		return false
	end
	if sender == recipient then
		return true
	end
	for _, player in { sender, recipient } do
		local section = sectionOf(player)
		if section and HazardService.IsSectionJammed(section) then
			return false
		end
	end
	return true
end

function ChatService.SetupForMatch()
	local channel = radio
	if not channel then
		return
	end
	for _, child in channel:GetChildren() do
		if child:IsA("TextSource") then
			child:Destroy()
		end
	end
	for _, p in MatchService.GetParticipants() do
		task.spawn(function()
			local ok, err = pcall(function()
				channel:AddUserAsync(p.UserId)
			end)
			if not ok then
				log:Debug("Radio AddUserAsync failed", err)
			end
		end)
	end
end

function ChatService.Reset()
	if radio then
		for _, child in radio:GetChildren() do
			if child:IsA("TextSource") then
				child:Destroy()
			end
		end
	end
end

function ChatService.Start()
	task.spawn(function()
		if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
			log:Warn("Legacy chat is enabled; proximity chat rules need TextChatService")
			return
		end
		local channels = TextChatService:WaitForChild("TextChannels", 15)
		if not channels then
			log:Warn("TextChannels not found; chat rules disabled")
			return
		end
		local general = channels:WaitForChild("RBXGeneral", 15) :: TextChannel?
		if general then
			general.ShouldDeliverCallback = shouldDeliverGeneral
		end
		local channel = Instance.new("TextChannel")
		channel.Name = "VoidlineRadio"
		channel.ShouldDeliverCallback = shouldDeliverRadio
		channel.Parent = channels
		radio = channel
	end)
end

return ChatService
