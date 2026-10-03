--!strict
--[[
	RewardService
	End-of-round progression plus small profile actions:
	  * GrantRound   - XP, levels, Credits and lifetime stats from server-tracked
	                   round stats (see Logic/Rewards). Nothing comes from the client.
	  * SaveSetting  - validated settings persistence (SettingsSchema)
	  * TutorialComplete - one-time tutorial reward
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local SettingsSchema = require(Shared.Data.SettingsSchema)
local Progression = require(Shared.Logic.Progression)
local Rewards = require(Shared.Logic.Rewards)
local Validate = require(Shared.Utility.Validate)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local RemoteService = require(script.Parent.RemoteService)
local ReplicationService = require(script.Parent.ReplicationService)

local RewardService = {}

function RewardService.GrantRound(winner: string)
	for _, p in MatchService.GetParticipants() do
		local player = p.Player
		if player.Parent == Players and p.Faction and DataService.GetProfile(player) then
			local won = winner == p.Faction
			local survived = p.Life == Constants.LifeState.Alive or p.Life == Constants.LifeState.Escaped
			local escaped = p.Life == Constants.LifeState.Escaped
			local result = Rewards.compute({
				Faction = p.Faction,
				Won = won,
				Survived = survived,
				Escaped = escaped,
				Stats = p.Stats,
			})
			local before = (DataService.GetProfile(player) :: DataService.Profile).Level
			local after = before
			local levelsGained = 0
			DataService.Update(player, function(profile)
				local level, xp, gained = Progression.applyXp(profile.Level, profile.Xp, result.Xp)
				profile.Level = level
				profile.Xp = xp
				after = level
				levelsGained = gained
				profile.Credits += result.Credits
				local stats = profile.Stats
				stats.RoundsPlayed += 1
				if won then
					stats.Wins += 1
					if p.Faction == Constants.Faction.Crew then
						stats.CrewWins += 1
					else
						stats.InfiltratorWins += 1
					end
				end
				if p.Faction == Constants.Faction.Infiltrator then
					stats.TimesInfiltrator += 1
				end
				stats.TasksCompleted += p.Stats.TasksCompleted
				stats.Revives += p.Stats.Revives
				stats.Siphons += p.Stats.Siphons
				stats.CorrectVotes += p.Stats.CorrectVotes
				stats.EvidenceRevealed += p.Stats.EvidenceRevealed
				stats.HazardsFixed += p.Stats.HazardsFixed
				if survived then
					stats.Survived += 1
				end
				if escaped then
					stats.Escapes += 1
				end
			end)
			ReplicationService.SetPrivate(player, Constants.PrivateKey.Reward, {
				Xp = result.Xp,
				Credits = result.Credits,
				Lines = result.Lines,
				Won = won,
				Faction = p.Faction,
				LevelBefore = before,
				LevelAfter = after,
				LevelsGained = levelsGained,
			})
			if levelsGained > 0 then
				NotifyService.Send(player, string.format("Level up! You reached level %d.", after), "Success", 5)
			end
			AnalyticsService.Track("RoundReward", result.Xp, { faction = p.Faction, won = tostring(won) }, player)
		end
	end
end

function RewardService.ClearRewards()
	for _, player in Players:GetPlayers() do
		ReplicationService.SetPrivate(player, Constants.PrivateKey.Reward, nil)
	end
end

function RewardService.Start()
	local settingKeys = {}
	for key in SettingsSchema.Rules do
		table.insert(settingKeys, key)
	end
	RemoteService.OnEvent(Net.Names.SaveSetting, { Validate.oneOf(settingKeys), Validate.primitive(10) }, function(player: Player, key: string, value: any)
		local clean = SettingsSchema.sanitize(key, value)
		if clean == nil then
			return
		end
		DataService.Update(player, function(profile)
			profile.Settings[key] = clean
		end)
	end)

	RemoteService.OnEvent(Net.Names.TutorialComplete, {}, function(player: Player)
		local profile = DataService.GetProfile(player)
		if not profile or profile.TutorialDone then
			return
		end
		DataService.Update(player, function(p)
			p.TutorialDone = true
			p.Credits += Config.Rewards.TutorialCredits
		end)
		NotifyService.Send(player, string.format("Training complete! +%d credits.", Config.Rewards.TutorialCredits), "Success", 5)
		AnalyticsService.Onboarding(player, 2, "TutorialComplete")
	end)
end

return RewardService
