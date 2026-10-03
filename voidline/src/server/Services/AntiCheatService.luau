--!strict
--[[
	AntiCheatService
	Lightweight, lag-tolerant movement sanity checks. Characters are
	client-simulated on Roblox, so the server samples positions and corrects
	clearly impossible movement:

	  * Speed: horizontal travel faster than sprint speed x tolerance (plus a
	    flat allowance) for several consecutive samples -> snapped back.
	  * Frozen drift: a frozen player (role reveal, muster, siphon channel)
	    moving more than a few studs -> snapped back.
	  * Server teleports grant a grace period so they never trigger it.

	Corrections are logged and counted; nobody is kicked for movement alone,
	because lag spikes can look like speed hacks. Every gameplay action is
	independently range-checked on the server anyway.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Logger = require(Shared.Utility.Logger)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local HazardService = require(script.Parent.HazardService)
local MapService = require(script.Parent.MapService)

local log = Logger.new("AntiCheat")

local AntiCheatService = {}

type Sample = { Position: Vector3, Time: number }

local lastValid: { [Player]: Sample } = {}
local violations: { [Player]: number } = {}
local corrections: { [Player]: number } = {}

local function correct(player: Player, root: BasePart, sample: Sample, reason: string)
	corrections[player] = (corrections[player] or 0) + 1
	violations[player] = 0
	MapService.MarkTeleported(player)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(sample.Position) * (root.CFrame - root.CFrame.Position))
	end
	log:Warn(string.format("Corrected %s (%d): %s [#%d]", player.Name, player.UserId, reason, corrections[player]))
	AnalyticsService.Count("MovementCorrections")
end

local function speedAllowance(position: Vector3): number
	local area = MapService.AreaAt(position)
	if area and (HazardService.IsActive("Gravity", area) or HazardService.IsActive("Breach", area)) then
		return 1.8
	end
	return 1
end

local function check(player: Player, settings: typeof(Config.AntiCheat))
	local root = CharacterService.GetRoot(player)
	if not root then
		lastValid[player] = nil
		return
	end
	local now = os.clock()
	local current: Sample = { Position = root.Position, Time = now }
	local previous = lastValid[player]
	if not previous or root.Anchored or now - MapService.GetLastTeleport(player) < settings.TeleportGraceSeconds then
		lastValid[player] = current
		violations[player] = 0
		return
	end

	local delta = current.Position - previous.Position
	local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude

	if CharacterService.IsFrozen(player) then
		if horizontal > settings.FrozenDriftAllowance then
			correct(player, root, previous, "moved while frozen")
		end
		return -- keep the frozen anchor point
	end

	local dt = now - previous.Time
	local maxDistance = Config.Movement.SprintSpeed * settings.SpeedTolerance * speedAllowance(root.Position) * dt + settings.FlatAllowance
	if horizontal > maxDistance or delta.Y > 80 then
		violations[player] = (violations[player] or 0) + 1
		if violations[player] >= settings.ViolationsBeforeCorrection then
			correct(player, root, previous, string.format("moved %.1f studs in %.2fs", horizontal, dt))
		end
		return -- don't accept the suspicious position as the new baseline
	end

	violations[player] = 0
	lastValid[player] = current
end

function AntiCheatService.Start()
	local settings = Config.AntiCheat
	if not settings.Enabled then
		return
	end
	Players.PlayerRemoving:Connect(function(player)
		lastValid[player] = nil
		violations[player] = nil
		corrections[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(settings.CheckInterval)
			for _, player in Players:GetPlayers() do
				local ok: boolean, err: any = pcall(check, player, settings)
				if not ok then
					log:Debug("check failed", err)
				end
			end
		end
	end)
end

function AntiCheatService.GetCorrections(player: Player): number
	return corrections[player] or 0
end

return AntiCheatService
