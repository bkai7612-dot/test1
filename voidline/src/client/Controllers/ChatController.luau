--!strict
--[[
	ChatController
	Client side of chat rules:
	  * Toggle between proximity chat and the ship radio (V / D-pad right).
	  * Radio messages get a [RADIO] prefix.
	  * Messages from players standing in a jammed section are garbled on
	    screen (the original text never displays).
	Delivery rules themselves are enforced by the server's ShouldDeliverCallback.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Utility.Signal)

local EffectsController = require(script.Parent.EffectsController)

local ChatController = {}

-- (onRadio: boolean)
ChatController.RadioChanged = Signal.new()

local onRadio = false
local GLYPHS = { "▓", "▒", "░", "#", "%", "&", "*", "?" }

local function garble(text: string): string
	local out = table.create(#text)
	local seed = #text
	for i = 1, #text do
		local ch = string.sub(text, i, i)
		if ch == " " then
			out[i] = " "
		else
			seed = (seed * 31 + i) % 9973
			out[i] = GLYPHS[(seed % #GLYPHS) + 1]
		end
	end
	return table.concat(out)
end

local function channels(): (TextChannel?, TextChannel?)
	local folder = TextChatService:FindFirstChild("TextChannels")
	if not folder then
		return nil, nil
	end
	return folder:FindFirstChild("RBXGeneral") :: TextChannel?, folder:FindFirstChild("VoidlineRadio") :: TextChannel?
end

function ChatController.ToggleRadio()
	local general, radio = channels()
	local config = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if not config or not general then
		return
	end
	if not onRadio and radio then
		onRadio = true
		config.TargetTextChannel = radio
	else
		onRadio = false
		config.TargetTextChannel = general
	end
	ChatController.RadioChanged:Fire(onRadio)
end

function ChatController.IsOnRadio(): boolean
	return onRadio
end

function ChatController.Start()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local channel = message.TextChannel
		if channel and channel.Name == "VoidlineRadio" then
			properties.PrefixText = "<font color=\"#56D6FF\">[RADIO]</font> " .. message.PrefixText
		end
		local source = message.TextSource
		local sender = if source then Players:GetPlayerByUserId(source.UserId) else nil
		if sender and sender ~= Players.LocalPlayer and channel and channel.Name == "RBXGeneral" then
			if EffectsController.IsPlayerJammed(sender) then
				properties.Text = garble(message.Text)
			end
		end
		return properties
	end
end

return ChatController
