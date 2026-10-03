local StateMachine = require(Shared.Logic.StateMachine)
local RoleAllocator = require(Shared.Logic.RoleAllocator)
local ObjectiveAssigner = require(Shared.Logic.ObjectiveAssigner)
local Minigames = require(Shared.Logic.Minigames)
local VoteTally = require(Shared.Logic.VoteTally)
local WinConditions = require(Shared.Logic.WinConditions)
local Progression = require(Shared.Logic.Progression)
local Rewards = require(Shared.Logic.Rewards)
local Config = require(Shared.Config)
local ObjectiveCatalog = require(Shared.Data.ObjectiveCatalog)

local function eq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "mismatch", tostring(b), tostring(a)), 2)
	end
end

test("StateMachine allows listed transitions only", function()
	local changes = {}
	local sm = StateMachine.new({ A = { "B" }, B = { "A", "C" }, C = {} }, "A")
	sm:OnChanged(function(new, old) table.insert(changes, old .. ">" .. new) end)
	assert(sm:Transition("B"))
	local ok = sm:Transition("B")
	assert(not ok, "B->B should be rejected")
	assert(sm:Transition("C"))
	assert(not sm:Transition("A"), "C is terminal")
	eq(sm:Get(), "C")
	eq(table.concat(changes, ","), "A>B,B>C")
end)

test("Infiltrator counts follow brackets and stay fair", function()
	local rng = Random.new(1)
	local scaling = Config.Roles.InfiltratorScaling
	for _ = 1, 200 do
		for players = 1, 12 do
			local n = RoleAllocator.infiltratorCount(players, scaling, Config.Roles.MaxInfiltratorRatio, rng)
			assert(n >= 0, "negative")
			assert(players - n > n or n == 0, "crew must outnumber infiltrators: " .. players .. "/" .. n)
			if players == 6 then eq(n, 1, "6 players") end
			if players >= 7 and players <= 9 then assert(n >= 1 and n <= 2, "7-9 players") end
			if players >= 10 then assert(n >= 2 and n <= 3, "10-12 players got " .. n) end
		end
	end
	eq(RoleAllocator.infiltratorCount(1, scaling, 0.34, rng), 0, "solo")
	eq(RoleAllocator.infiltratorCount(2, scaling, 0.34, rng), 0, "two players can't be fair with an infiltrator")
	eq(RoleAllocator.infiltratorCount(12, scaling, 0.34, rng, 10), 4, "override is clamped to fair cap")
end)

test("Weighted role pick respects count and favours higher weight", function()
	local rng = Random.new(7)
	local heavy, light = 0, 0
	for _ = 1, 2000 do
		local chosen = RoleAllocator.pick({ { Id = "a", Weight = 1 }, { Id = "b", Weight = 0.35 } }, 1, rng)
		if chosen.a then heavy += 1 end
		if chosen.b then light += 1 end
	end
	eq(heavy + light, 2000, "exactly one pick each time")
	assert(heavy > light * 2, "weight should bias selection")
	local chosen = RoleAllocator.pick({ { Id = 1, Weight = 1 }, { Id = 2, Weight = 1 }, { Id = 3, Weight = 1 } }, 5, rng)
	local count = 0
	for _ in chosen do count += 1 end
	eq(count, 3, "cannot pick more than available")
end)

test("Objective assignment mixes lengths", function()
	local rng = Random.new(3)
	local rules = { Count = 5, MaxCarry = 1, MinLong = 1, MaxLong = 2 }
	for _ = 1, 300 do
		local ids = ObjectiveAssigner.assign(ObjectiveCatalog.Objectives, rules, rng)
		eq(#ids, 5, "count")
		local long, carry, seen = 0, 0, {}
		for _, id in ids do
			assert(not seen[id], "duplicate objective " .. id)
			seen[id] = true
			local objective = ObjectiveCatalog.get(id)
			if objective.Length == "Long" then long += 1 end
			if objective.Length == "Carry" then carry += 1 end
		end
		assert(long >= 1 and long <= 2, "long count " .. long)
		assert(carry <= 1, "carry count " .. carry)
	end
	local stations = ObjectiveAssigner.pickStations(ObjectiveCatalog.Objectives, rng)
	for _, objective in ObjectiveCatalog.Objectives do
		for stepIndex, step in objective.Steps do
			local alt = stations[objective.Id][stepIndex]
			assert(alt >= 1 and alt <= #step.Stations, "alt in range")
		end
	end
end)

test("Minigames accept correct answers and reject wrong ones", function()
	local rng = Random.new(11)
	for _ = 1, 50 do
		local c, s = Minigames.generate("Sliders", rng)
		assert(Minigames.verify("Sliders", s, { c.Targets[1] + 3, c.Targets[2] - 5, c.Targets[3] }))
		assert(not Minigames.verify("Sliders", s, { c.Targets[1] + 20, c.Targets[2], c.Targets[3] }))
		assert(not Minigames.verify("Sliders", s, { c.Targets[1] }))
		assert(not Minigames.verify("Sliders", s, { 0 / 0, 0 / 0, 0 / 0 }))

		c, s = Minigames.generate("Sequence", rng)
		eq(#c.Code, 5, "code length")
		assert(Minigames.verify("Sequence", s, c.Code))
		assert(not Minigames.verify("Sequence", s, "xxxxx"))
		assert(not Minigames.verify("Sequence", s, 12345))

		c, s = Minigames.generate("Wires", rng)
		local answer = {}
		for i, colour in c.Left do answer[i] = table.find(c.Right, colour) end
		assert(Minigames.verify("Wires", s, answer))
		local wrong = table.clone(answer)
		wrong[1], wrong[2] = wrong[2], wrong[1]
		assert(not Minigames.verify("Wires", s, wrong))

		c, s = Minigames.generate("Timing", rng)
		assert(Minigames.verify("Timing", s, { Hits = 3, Misses = 1 }))
		assert(not Minigames.verify("Timing", s, { Hits = 3, Misses = 5 }))
		assert(not Minigames.verify("Timing", s, { Hits = 2.5, Misses = 0 }))
		for _, zone in c.Zones do
			assert(zone.Start >= 0 and zone.Start + zone.Width <= 1, "zone inside track")
		end
	end
end)

test("Vote tally outcomes", function()
	local voters = { a = true, b = true, c = true, d = true }
	local targets = { a = true, b = true, c = true, d = true }
	local r = VoteTally.tally({ a = "b", b = "b", c = "a", d = VoteTally.SKIP }, voters, targets)
	eq(r.Outcome, "Confine") eq(r.Target, "b")
	r = VoteTally.tally({ a = "b", b = "a" }, voters, targets)
	eq(r.Outcome, "Tie", "two-way tie")
	r = VoteTally.tally({ a = "b", b = VoteTally.SKIP }, voters, targets)
	eq(r.Outcome, "Skip", "skip ties top target")
	r = VoteTally.tally({}, voters, targets)
	eq(r.Outcome, "NoVotes")
	-- Disconnected voter and invalid target are discarded.
	r = VoteTally.tally({ a = "c", ghost = "a", b = "zzz" }, voters, targets)
	eq(r.Outcome, "Confine") eq(r.Target, "c") eq(r.ValidVotes, 1)
end)

test("Win conditions", function()
	eq((WinConditions.evaluate({ AliveCrew = 5, AliveInfiltrators = 1, TotalInfiltrators = 1, Stability = 50 })), nil)
	eq((WinConditions.evaluate({ AliveCrew = 5, AliveInfiltrators = 0, TotalInfiltrators = 1, Stability = 50 })), "Crew")
	eq((WinConditions.evaluate({ AliveCrew = 2, AliveInfiltrators = 2, TotalInfiltrators = 2, Stability = 50 })), "Infiltrator")
	eq((WinConditions.evaluate({ AliveCrew = 5, AliveInfiltrators = 1, TotalInfiltrators = 1, Stability = 0 })), "Infiltrator")
	eq((WinConditions.evaluate({ AliveCrew = 1, AliveInfiltrators = 0, TotalInfiltrators = 0, Stability = 20 })), nil, "solo practice continues")
	eq((WinConditions.extraction(1, 1)), "Crew")
	eq((WinConditions.extraction(0, 1)), "Infiltrator")
end)

test("Progression levels up and caps", function()
	local level, xp, gained = Progression.applyXp(1, 0, 100)
	eq(level, 2) eq(xp, 0) eq(gained, 1)
	level, xp = Progression.applyXp(1, 50, 30)
	eq(level, 1) eq(xp, 80)
	level = Progression.applyXp(1, 0, 10 ^ 9)
	eq(level, Config.Progression.MaxLevel, "capped")
	eq(#Progression.earnedBadges({ RoundsPlayed = 1 }), 1)
end)

test("Rewards are positive and faction-specific", function()
	local stats = Rewards.emptyStats()
	stats.TaskSteps = 4
	stats.TasksCompleted = 2
	local crew = Rewards.compute({ Faction = "Crew", Won = true, Survived = true, Escaped = true, Stats = stats })
	assert(crew.Xp > 0 and crew.Credits > 0)
	local inf = Rewards.compute({ Faction = "Infiltrator", Won = false, Survived = false, Escaped = false, Stats = stats })
	assert(inf.Xp < crew.Xp, "infiltrator shouldn't earn crew task xp")
	local sum = 0
	for _, line in crew.Lines do sum += line.Xp end
	eq(sum, crew.Xp, "lines add up")
end)
