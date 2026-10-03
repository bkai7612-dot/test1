# VOIDLINE

*Working title.* VOIDLINE is an original multiplayer social-deduction survival game for Roblox, for 6–12 players.

A civilian emergency crew boards the crippled research vessel **ASTERION**. They have to restore its systems and reach extraction before the hull breaks apart. Some of the crew are hidden **Infiltrators**, compromised by a rogue intelligence called **MURMUR**. Infiltrators look exactly like everyone else. They sabotage the ship, siphon isolated crew into stasis, and manipulate the vote.

This folder is a [Rojo](https://rojo.space) project. Everything is written in typed Luau, and both the map and the UI are built in code.

| Doc | What's in it |
|---|---|
| **README.md** (this file) | Game overview, architecture, how to run it |
| [docs/LAUNCH.md](docs/LAUNCH.md) | Step-by-step launch checklist, including what only the game owner can do in Roblox |
| [docs/TESTING.md](docs/TESTING.md) | Test plan for every system: solo, full lobby, exploits, mobile and console |

---

## Quick start

1. Run `rokit install`. This installs the pinned `rojo` and `luau-lsp`.
2. Install the Rojo plugin in Roblox Studio.
3. Get the code into Studio, either by syncing or by building a place file:
   - **Sync:** run `rojo serve`, open a new **Baseplate** in Studio, then click **Rojo → Connect**.
   - **Build:** run `rojo build -o Voidline.rbxl`, then open the file.
4. Go to **Game Settings → Security** and turn on **Enable Studio Access to API Services**. Without it, saving uses an in-memory store and a "progress not saved" banner appears.
5. Press **Play**. The ship and lobby are built when the server starts.

Without Studio, you can still run the static checks:

```bash
./scripts/analyze.sh                       # type-check + lint every file against the Roblox API
LUAU=/path/to/luau python3 tests/run.py    # headless logic and catalog-integrity tests
lune run tests/runtime/run.luau .          # full round: real server + client code on fake Roblox services (~3 min)
```

---

## The game

### Round flow

`LOBBY → PREPARATION → ROLE_ASSIGNMENT → ACTIVE_ROUND ⇄ EMERGENCY / DISCUSSION → VOTING → … → ENDGAME → RESULTS → RESET → LOBBY`

| Stage | What happens |
|---|---|
| Lobby | Players ready up. The countdown starts once enough players are present and either most are ready or the lobby has waited long enough. Private-server hosts can change match settings and start early. |
| Boarding | Everyone is teleported aboard, into one of several start rooms chosen at random. |
| Role reveal | Each player privately learns whether they are **Crew** or **Infiltrator**, plus their suit **accent** (a coloured armband with a symbol). Infiltrators also learn who their allies are. |
| Play | The crew completes objectives, which raises **Restoration**. **Stability** decays over time and drops further from failures. Infiltrators sabotage and siphon. Random ship events keep each round different. |
| Musters | Players call a meeting by reporting a stasis pod, using the Muster Beacon, or raising a witness alert. They then discuss, audit, pull evidence and vote. |
| Endgame | When Restoration reaches 100%, a random extraction route is chosen. The crew completes its steps, then has to be inside the extraction room when the countdown ends. |
| Results | The winner, everyone's faction and fate, and XP, Credits and level-ups. |

### Win conditions

**The crew wins if:**
- at least one crew member escapes, or
- every infiltrator is confined.

**The infiltrators win if:**
- they equal or outnumber the living crew,
- Stability reaches 0,
- the endgame timer runs out, or
- no crew member makes it to extraction.

### Original mechanics

| Mechanic | How it works |
|---|---|
| **Siphon → Stasis** | An infiltrator holds a short, visible beam on a crew member. The victim is frozen in a crystal for 25 s. Anyone can **Revive** them, and a revived victim gets a private glimpse of the attacker's accent. Anyone can also **Report** them. If nobody acts in time, the victim becomes a **Signal Ghost**. Siphoning doesn't work inside the Emergency Shelter, against a crowd of crew, or on someone who was just revived. |
| **Accents** | Each round assigns accents from a palette smaller than the player count, so several players share each accent. A clue narrows the suspects down but never names one. Every accent has a symbol and a name, so it doesn't rely on colour. |
| **Evidence** | **Public** evidence covers sabotage anomalies, scanned pods and audits. **Hidden** evidence covers door logs, camera counts and interference traces; it is revealed from the Security Terminal or with "Request evidence" during a muster. **Private** evidence covers what a witness saw and the glimpse a revived victim got; players can share it during a muster. |
| **Infiltrator tools** | **Scrub** a pod to destroy its trace (scanning it afterwards still shows the trace was tampered with). **Spoof** plants one fake interference trace per round. Infiltrators can perform their cover-story tasks, but those tasks never move Restoration. |
| **Signal Ghosts** | Ghosts can watch the crew and talk with other ghosts. Every 45 s, a ghost can send an anonymous "static whisper" into a room. |
| **Shared objectives** | When a crew member is lost, their unfinished objectives become shared work for the crew. This only happens once the loss is revealed at a muster, so the shared list never gives away a death early. |
| **Hazards** | One engine powers both sabotage and random events. Section power cuts, ship-wide blackouts, gravity failure, comms jams, door lockdowns, fires, hull breaches, malfunctions, reactor instability and an unknown signal can all be fixed. Coolant and oxygen are critical hazards that need two fixes. Failing a hazard costs Stability rather than ending the game. |

### Controls

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Interact | E | X | tap the prompt |
| Secondary interaction (fix, scan, siphon) | F | Y | tap the prompt |
| Infiltrator interaction (scrub) | R | R1 | tap the prompt |
| Sprint | Shift (hold, or toggle in Settings) | L3 | Sprint button |
| Sabotage console (infiltrators) | Q | D-pad up | Sabotage button |
| Radio / proximity chat | V | D-pad left | Radio button |
| Emergency alert (witnesses) | G | D-pad right | Alert button |
| Emotes | B | D-pad down | Emote button (lobby) |
| Collapse objectives | Tab | – | – |
| Menu (lobby) | M | Select | Menu button |
| Back / close | – | B | ✕ |
| Admin panel (admins only) | F2 | – | – |

---

## Architecture

```
src/shared  → ReplicatedStorage.Shared
  Config, Constants, Types, Net          tuning values, protocol ids, types, the remote list
  Data/      ShipLayout, ObjectiveCatalog, HazardCatalog, SabotageCatalog, EventCatalog,
             CosmeticCatalog, AccentPalette, SettingsSchema, AudioCatalog
  Logic/     StateMachine, RoleAllocator, ObjectiveAssigner, Minigames, VoteTally,
             WinConditions, Progression, Rewards   (pure, headless-tested)
  Utility/   Logger, Signal, Maid, RateLimiter, Validate, TableUtil, Format

src/server  → ServerScriptService.Server
  GameServer.server.luau    boots services in a fixed order: Init → Start; Shutdown on close
  Services/  (27 modules)   Remote, Replication, PlayerManager, Data, Analytics, Notify,
                            Map, Match, Character, Lobby, Role, Interaction, Lift, Evidence,
                            Hazard, Objective, Sabotage, Elimination, Meeting, Escape, Event,
                            Chat, Cosmetic, Shop, Reward, AntiCheat, Round, Admin

src/client  → StarterPlayer.StarterPlayerScripts.Client
  ClientMain.client.luau    boots controllers in a fixed order
  Controllers/ (13)         Client (state mirror), Settings, Audio, Camera, Effects, Input,
                            Chat, Voice, Interaction, Minigame, Nameplate, UI, Tutorial
  UI/                       Theme, Create, Components, Minigames, Screens/ (15 screens)

src/server/Art               the visual pass, called by MapService
  Kit                        palette and part builders
  Atmosphere                 Future lighting, bloom, grading, sky; planet, moon, nebula, ship hull and engines
  Architecture               per-room trim, panels, light strips, pillars, door frames, ceiling beams
  Props                      themed hero props for each area
```

Animated parts are tagged by the server (`VoidlineSpin`, `VoidlineOrbit`, `VoidlinePulse`, `VoidlineBob`, `VoidlineScreenBars`) and animated locally by `AmbientController`. Reduced effects turns this off.

There is no hand-authored content in the place file. The ASTERION (15 areas, 22 corridors and tunnels, a lift gallery, doors, about 90 consoles) and the lobby with its training bay are built from `ShipLayout`. The UI is built by the client controllers.

### Security model

The client never decides anything. It only requests.

- **Remotes.** Every remote is listed in `Net.luau` and created by the server. Each client request passes four gates, in order:
  1. The sender is still connected.
  2. The sender is within a per-player rate limit for that remote.
  3. The arguments pass type and range validation. A malformed request counts as a strike, and enough strikes gets the player kicked.
  4. The handler runs inside `pcall`.
- **Game rules.** Handlers then check the game rules themselves: the round state, whether the player is alive, their faction, cooldowns, range from server-side positions, and line of sight.
- **Roles.** Roles exist only on the server. Each player receives their own role privately. Nothing role-related is written to attributes, values, teams or names. Role-specific actions, such as a siphon prompt, are only ever sent to the players allowed to use them.
- **Objectives.** Holds are timed by the server. Mini-games are issued by the server with a secret answer, a minimum solve time, and a check that the player is still at the console.
- **Votes.** One vote per player, and it can't be changed. Votes from players who have left are discarded, and ties confine nobody. Whether the confined player's role is revealed is configurable.
- **Currency and rewards.** All values are computed on the server from server-tracked stats. Robux receipts are idempotent and are only acknowledged after a successful save.
- **Data.** Saving uses DataStore session locking with retries, budget waits, stale-lock takeover and save-on-shutdown.
- **Movement.** Server-side sanity checks correct impossible speeds and frozen-player drift. They are tolerant of lag.
- **Admin tools.** Authorised by UserId, and re-checked for every command.

### Performance

- `StreamingEnabled` is on. Console models are persistent so prompts are always reliable.
- Server work runs on a few low-frequency loops (0.25–1 s) rather than per-frame.
- The client has a single Heartbeat connection, for movement and stamina. Effects run at 0.15 s.
- Interaction lists are diffed before they are sent. Lobby state is deduplicated. Refresh requests are coalesced to one per frame.
- Every per-player resource is released through Maids or player-removal hooks.
- Effects quality is adjustable (Low/Medium/High), along with Reduced effects.

### Accessibility

- A colourblind palette.
- A symbol and a name for every accent and status, so nothing relies on colour alone.
- Subtitles and captions for every sound cue. Sounds without audio assets still produce captions.
- Reduced flashing and Reduced effects options.
- Adjustable UI scale, which also scales automatically for phones and TVs.
- Toggle sprint.
- Full gamepad and touch support.
- Clear objective markers.

---

## Balancing

All tuning lives in `src/shared/Config.luau`, which is frozen at runtime. The values most worth adjusting during playtests:

| What | Key |
|---|---|
| Infiltrator scaling | `Roles.InfiltratorScaling`, `MaxInfiltratorRatio` |
| Pace | `Round.StabilityDecayPerMinute`, `Objectives.TasksPerPlayer`, `Round.StabilityPerCrewStep` |
| Siphon | `Elimination.SiphonCooldown`, `CrowdBlockCount`, `StasisBleedSeconds` |
| Sabotage | `Sabotage.GlobalCooldown`, per-sabotage `Cooldown` / `Duration` in `SabotageCatalog` |
| Musters | `Meeting.DiscussionSeconds`, `VotingSeconds`, `RevealOnConfine` |
| Endgame | `Escape.TotalSeconds`, `ExtractionCountdown` |
| Events | `Events.MinInterval` / `MaxInterval`, weights in `EventCatalog` |

`docs/TESTING.md` lists the metrics to watch, which come from the analytics hooks.

---

## Status and limitations

**Done:** all twenty build phases are implemented. The full static type check passes with zero errors. The headless logic and catalog tests pass. The runtime harness plays a full solo round through the real server and client code: tasks, a sabotage fix, a meeting, extraction, rewards and the save. Rojo builds a valid place file. There are no require cycles.

**Not done:** the game has not been run in Roblox Studio, and the harness fakes the Roblox engine, so it can't check rendering, physics or touch input. It has to be playtested before launch, as described in [docs/LAUNCH.md](docs/LAUNCH.md).

Known limitations:
- **No audio assets ship with the game.** Every sound is a captioned placeholder. Add original or licensed sound IDs to `AudioCatalog`.
- **Voice is Roblox's own spatial voice.** Comms jams garble text chat and block the radio, but they don't alter voice.
- **Emotes need R15 avatars.** They use the default `Animate` script.
- **Rejoining mid-round doesn't restore a role.** Roblox rejoins create a new session, so a player who rejoins spectates until the next round.
- **Movement checks only correct.** They never kick a player for movement, because lag spikes can look like speed hacks.
