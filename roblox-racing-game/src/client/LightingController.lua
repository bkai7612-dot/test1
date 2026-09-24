-- Applies per-map lighting locally (racers see the track's time of day,
-- players in the lobby keep lobby lighting).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Maps = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Maps"))

local LightingController = {}

local current = nil

local function apply(preset)
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Sine)
	local tweenable = {}
	for key, value in preset.lighting do
		if key == "ClockTime" then
			Lighting.ClockTime = value
		else
			tweenable[key] = value
		end
	end
	TweenService:Create(Lighting, info, tweenable):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	TweenService:Create(atmosphere, info, preset.atmosphere):Play()
end

function LightingController.SetMap(mapId)
	local key = mapId or "Lobby"
	if current == key then
		return
	end
	current = key
	local preset = mapId and Maps.List[mapId] or Maps.LobbyLighting
	apply(preset)
end

return LightingController
