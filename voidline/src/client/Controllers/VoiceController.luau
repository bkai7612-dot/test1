--!strict
--[[
	VoiceController
	Reports whether Roblox voice chat is available to the local player.
	Voice uses Roblox's own spatial (proximity) voice and its safety systems;
	VOIDLINE never records, alters or routes voice audio. The HUD shows a
	voice indicator so players know whether nearby voices are an option.
]]

local Players = game:GetService("Players")
local VoiceChatService = game:GetService("VoiceChatService")

local VoiceController = {}

local enabled = false

function VoiceController.IsEnabled(): boolean
	return enabled
end

function VoiceController.Start()
	task.spawn(function()
		local ok, result = pcall(function()
			return VoiceChatService:IsVoiceEnabledForUserIdAsync(Players.LocalPlayer.UserId)
		end)
		enabled = ok and result == true
	end)
end

return VoiceController
