--!strict
--[[
	LiftService
	The Observation Deck gallery lift. Riding takes a short hold and moves the
	rider between the deck floor and the gallery above it (a quiet, risky
	spot: one way in, one way out).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShipLayout = require(Shared.Data.ShipLayout)

local InteractionService = require(script.Parent.InteractionService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)

local LiftService = {}

local function destination(anchor: string): CFrame
	local x, y, z = ShipLayout.anchorPosition("ObservationDeck", anchor)
	local room = ShipLayout.getRoom("ObservationDeck") :: ShipLayout.Room
	-- Step off the pad toward the room centre (gallery riders face south).
	local position = Vector3.new(x - 4, y + 3.5, z + (if anchor == "LiftTop" then 2 else 3))
	return CFrame.lookAt(position, Vector3.new(room.CenterX, position.Y, position.Z + 10))
end

local function register(fixtureId: string, toAnchor: string, label: string)
	InteractionService.Register({
		Id = "Lift:" .. fixtureId,
		Anchor = "Fixture:" .. fixtureId,
		Action = label,
		Object = "Gallery Lift",
		Hold = 1,
		Visible = function(player)
			return MatchService.InPlay() and MatchService.IsActive(player)
		end,
		OnComplete = function(player)
			MapService.Teleport(player, destination(toAnchor))
		end,
	})
end

function LiftService.Start()
	register("Lift.Bottom", "LiftTop", "Ride up")
	register("Lift.Top", "LiftBottom", "Ride down")
end

return LiftService
