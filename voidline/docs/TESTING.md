# VOIDLINE test plan

This plan covers every item in the spec's testing section.

There are two kinds of tests:

- **Static tests** run anywhere. They are the type check (`scripts/analyze.sh`) and the headless Luau tests (`tests/run.py`). The headless tests cover the state machine, role allocation, objective assignment, mini-game verification, vote tallying, win conditions, progression, rewards, and catalog and map integrity: anchor collisions, doorway clearance, hazard fixtures and area lookup.
- **Studio tests** run in Roblox Studio, using **Test → Clients and Servers** for multiplayer.

Admin tools are on **F2**. Everyone is an admin inside Studio.

---

## Core scenarios

| Scenario | How to test | Expected |
|---|---|---|
| **1 player** | Play solo, then ready up | A practice round with no infiltrators. Objectives, hazards, musters and extraction all work. The round ends via extraction or with "Ship lost". |
| **Minimum count** | Clients and Servers with 3 players | One infiltrator. With 2 players there is never an infiltrator, because the crew must outnumber them. F2 → *Force my next role* can override this, but parity then ends the round immediately. |
| **Full count** | 12 clients (heavy), or a live server | 2–3 infiltrators. No overlapping spawns. The lobby list scrolls. |
| **Players leaving** | Close a client mid-round, and mid-vote | Roster shows "Disconnected". Their votes are discarded. A disconnected crew member's objectives become shared. A win check runs. |
| **Players reconnecting** | Rejoin during a round | The player spectates until the next round. The lobby picks them up at the next departure. |
| **Server shutdown** | Clients and Servers → Cleanup | `Server shutting down` in Output. Profiles save and their locks are released. |
| **Data** | Play, earn credits, stop, play again | Credits and level persist. Turning off API access shows the "temporary profile" banner. |
| **Tied votes** | 4 players: 2 vote A, 2 vote B | "TIED VOTE" and nobody is confined. Skip votes equal to the top count also result in a skip. |
| **Missing objectives** | Stand at a console that isn't yours | No prompt appears. Firing `InteractComplete` from the command bar does nothing. |
| **Failed objectives** | Submit a wrong mini-game answer, or let it time out | Sparks, a warning toast, and a 4 s console cooldown. No progress. |
| **Multiple simultaneous events** | F2: spawn event ×3, then sabotage | Up to two event hazards at once, plus sabotage. One hazard per room or section. Lights restore correctly as each one ends. |
| **Critical sabotage** | F2 → Sabotage `CoolantFailure` | EMERGENCY state with a red vignette. Two players must open the valves within 4 s of each other. Failing costs 30 Stability. |
| **Endgame** | F2 → Set restoration 100 | A route is chosen and its steps go in order. The extraction countdown runs. Players inside the extraction room escape. |
| **Mobile** | Device emulator (phone) | The UI scales down. Touch buttons appear for Sprint, Radio, Sabotage, Alert and Emote. Prompts can be tapped. Mini-games are draggable. |
| **Controller** | Plug in a gamepad, or use the emulator | Menus get focus automatically. B goes back. The D-pad adjusts sliders. Prompts use X, Y and R1. |
| **Low-end hardware** | Settings → Effects Low + Reduced effects; Studio *Rendering quality* 1 | No particle bursts, blur, shake or flashes. Stable frame rate. |

## Exploits (client command bar in Studio, "Current: Client")

```lua
local R = game.ReplicatedStorage.Remotes

-- Rate limiting: these get dropped silently ("Rate limited" at Debug level).
for i = 1, 100 do R.InteractBegin:FireServer("Beacon") end

-- Malformed arguments: each one adds a strike, and 15 strikes is a kick.
R.Sabotage:FireServer(123)
R.MeetingAction:FireServer("Accuse", 0/0)
R.MinigameSubmit:FireServer(string.rep("x", 500), {})

-- Rule violations: these are ignored (no strike, because the input is well formed).
R.Sabotage:FireServer("PowerSurge", "Fore")   -- as crew: ignored
R.InteractComplete:FireServer("Beacon")       -- with no hold started: nothing happens
R.MeetingAction:FireServer("Accuse", 1)       -- outside a muster: ignored
R.GhostWhisper:FireServer("Engineering")      -- while alive: ignored
print(R.AdminCommand:InvokeServer("GiveCredits", 1e9)) -- nil for non-admins (set AllowStudioAdmins=false to test)

-- Role privacy: none of these should reveal anyone else's role.
for _, p in game.Players:GetPlayers() do
	print(p.Name, p:GetAttributes(), p.Character and p.Character:GetAttributes())
end
```

Movement: teleport-walk from the client. Setting WalkSpeed directly doesn't work as a test, because the client recomputes it every frame.

```lua
local hrp = game.Players.LocalPlayer.Character.HumanoidRootPart
for i = 1, 20 do hrp.CFrame += hrp.CFrame.LookVector * 12; task.wait(0.1) end
```

The server should snap you back after a few samples, and the server log should show `Corrected ...`.

## Balancing

Use F2 → *Refresh server state* (the analytics summary) and the Creator Hub custom events.

| Metric | Target | Adjust |
|---|---|---|
| Average round length | 8–14 min | `TasksPerPlayer`, `StabilityDecayPerMinute` |
| Crew vs. infiltrator win rate | 45–55% | `SiphonCooldown`, `CrowdBlockCount`, sabotage cooldowns |
| Escape rate (rounds that reach the endgame) | about 40% | `Escape.TotalSeconds`, the steps in each route |
| Musters per round | 2–4 | `BeaconUsesPerPlayer`, `BeaconCooldownSeconds` |
| Revive rate | 20–40% of siphons | `StasisBleedSeconds`, `ReviveHoldSeconds` |
| Mini-game failure rate | under 15% | `Minigames.TimeLimit`, slider tolerance |
