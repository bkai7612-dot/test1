# VOIDLINE

*Working title.* An original multiplayer social-deduction survival game for Roblox.
A civilian emergency crew has to stabilise the crippled research vessel **ASTERION**
and reach extraction while hidden **Infiltrators**, compromised by a rogue AI,
work against them.

This folder is a [Rojo](https://rojo.space) project. All game code lives in `src/` as
`.luau` files and syncs into Roblox Studio.

**Status:** Phase 1 (foundation) is done. See [Roadmap](#roadmap).

---

## Getting started

1. Install the toolchain with [Rokit](https://github.com/rojo-rbx/rokit): run `rokit install`
   in this folder. That installs the pinned `rojo` and `luau-lsp`.
2. Install the Rojo plugin in Roblox Studio (Plugins → Manage Plugins, or `rojo plugin install`).
3. Pick one:
   - **Live sync:** run `rojo serve`, open a new Baseplate in Studio, then click **Connect**
     in the Rojo plugin.
   - **Build a place file:** run `rojo build -o Voidline.rbxl` and open the file in Studio.
4. Turn on **Game Settings → Security → Enable Studio Access to API Services**. The
   DataStores arrive in Phase 14, and having this on now avoids surprises then.

Type-check everything against the Roblox API with `./scripts/analyze.sh`.

---

## Project layout

| Repo path | Roblox location | Kind |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` | Folder |
| `src/shared/Config.luau` | `ReplicatedStorage.Shared.Config` | ModuleScript |
| `src/shared/Constants.luau` | `ReplicatedStorage.Shared.Constants` | ModuleScript |
| `src/shared/Types.luau` | `ReplicatedStorage.Shared.Types` | ModuleScript |
| `src/shared/Net.luau` | `ReplicatedStorage.Shared.Net` | ModuleScript |
| `src/shared/Utility/Logger.luau` | `ReplicatedStorage.Shared.Utility.Logger` | ModuleScript |
| `src/shared/Utility/Signal.luau` | `ReplicatedStorage.Shared.Utility.Signal` | ModuleScript |
| `src/shared/Utility/Maid.luau` | `ReplicatedStorage.Shared.Utility.Maid` | ModuleScript |
| `src/shared/Utility/RateLimiter.luau` | `ReplicatedStorage.Shared.Utility.RateLimiter` | ModuleScript |
| `src/shared/Utility/Validate.luau` | `ReplicatedStorage.Shared.Utility.Validate` | ModuleScript |
| `src/shared/Utility/TableUtil.luau` | `ReplicatedStorage.Shared.Utility.TableUtil` | ModuleScript |
| *(created at runtime)* | `ReplicatedStorage.Remotes` | Folder of RemoteEvents/Functions |
| *(project file)* | `ReplicatedStorage.Assets` | Folder |
| `src/server/GameServer.server.luau` | `ServerScriptService.Server.GameServer` | **Script** |
| `src/server/Services/RemoteService.luau` | `ServerScriptService.Server.Services.RemoteService` | ModuleScript |
| `src/server/Services/ReplicationService.luau` | `ServerScriptService.Server.Services.ReplicationService` | ModuleScript |
| `src/server/Services/PlayerManager.luau` | `ServerScriptService.Server.Services.PlayerManager` | ModuleScript |
| `src/server/Services/AdminService.luau` | `ServerScriptService.Server.Services.AdminService` | ModuleScript |
| *(project file)* | `ServerStorage.Maps / Objectives / ServerAssets` | Folders |
| `src/client/ClientMain.client.luau` | `StarterPlayer.StarterPlayerScripts.Client.ClientMain` | **LocalScript** |
| `src/client/Controllers/ClientController.luau` | `StarterPlayer.StarterPlayerScripts.Client.Controllers.ClientController` | ModuleScript |
| `src/client/Controllers/UIController.luau` | `StarterPlayer.StarterPlayerScripts.Client.Controllers.UIController` | ModuleScript |
| *(project file)* | `Workspace.Lobby / ActiveMap / SpawnPoints / InteractiveObjects` | Folders |

Working without Rojo? Create the instances in the **Roblox location** column by hand and
paste each file's contents in. `*.server.luau` is a Script, `*.client.luau` is a
LocalScript, and everything else is a ModuleScript. Name each one after its file without
the extension.

UI is built in code by client controllers, not authored in `StarterGui`. This keeps it
diffable in git. The `MainMenu`/`LobbyUI`/`GameHUD`/... screens arrive in Phase 13 as
controllers.

`Workspace.StreamingEnabled` is set to `true` by the project file.

---

## Architecture

### One Script, one LocalScript

There is one entry point on each side, and it loads modules in a **fixed order**:

```
GameServer.server.luau                 ClientMain.client.luau
  require  RemoteService                 require  ClientController
           ReplicationService                     UIController
           PlayerManager                 Init()   (in order)
           AdminService                  Start()  (in order)
  Init()   (in order)                    ClientController.SignalReady()
  Start()  (in order)
  BindToClose → Shutdown() (reverse order)
```

Every service or controller is a ModuleScript that can implement any of these:

- `Init()` creates state and instances. It doesn't depend on other modules having started.
- `Start()` binds remotes and connects events. It must not yield for long.
- `Shutdown()` (server only) flushes work inside `BindToClose`. Phase 14 uses this for data saving.

If any step fails, the boot **aborts with an error**. A half-started server is worse than
a server that fails loudly. To add a system, create the module and add its name to
`SERVICE_ORDER` / `CONTROLLER_ORDER`.

Modules talk to each other through plain `require` and `Signal`s, for example
`PlayerManager.PlayerLoaded:Connect(...)`. They never use globals or `_G`.

### Remote architecture (`Net` + `RemoteService`)

- `Shared/Net.luau` is the **only** list of remotes. It gives each remote's kind
  (Event or Function), direction, and rate limit.
- The **server creates** the `ReplicatedStorage.Remotes` folder at boot from that list.
  If the place file already has a Remotes folder, the server deletes it. The client
  waits for the folder with `Net.getEvent(name)` and `Net.getFunction(name)`.
- Every client→server request goes through `RemoteService.OnEvent` or `OnInvoke`, and
  passes four checks in order:
  1. **Sender check.** The player must still be connected.
  2. **Rate limit.** Each player has a token bucket per remote. Excess calls are dropped silently.
  3. **Argument validation.** Each argument has a `Validate` check, and the argument
     count is checked too. Rejects NaN, infinity, invalid UTF-8, extra args, wrong types
     and out-of-range values. Each failure is a **strike**. A real client never sends a
     malformed request, so a player with 15 strikes is kicked (configurable).
  4. **Handler**, run inside `pcall`. Errors are logged on the server and the client
     never sees them (a RemoteFunction just returns `nil`).
- Handlers still have to check **game rules**, such as "is this player alive?" or "is it
  the voting phase?". The remote layer only guarantees the shape and rate of the input.
- `InvokeClient` is never used. A client could hang the server with it.
- If a client→server remote has no handler, the server binds a drop handler so requests
  don't queue up in memory, and logs a warning.

### State replication (`ReplicationService` + `ClientController`)

This is the only path for game state to reach clients.

| API | Who receives it | Use for |
|---|---|---|
| `SetPublic(key, value)` | every client | round state, player count, timers |
| `SetPrivate(player, key, value)` | **that player only** | their session, and later their role and infiltrator abilities |

- **Secrets go through `SetPrivate` only.** Never put a role or anything secret in
  Attributes, ValueObjects, player names or any other replicated instance. Exploiters
  can read everything that replicates.
- Each scope has a version counter. The client asks for a full snapshot with
  `RequestSnapshot` and ignores any live update that's older than what it already has,
  so the initial sync and the update stream can't race.
- `ClientController` keeps a **read-only mirror** of that state and exposes it through
  `PublicChanged`, `PrivateChanged`, `Notified` and `Synced` signals. The client uses
  the mirror only for UI and effects. It never decides anything.

### PlayerManager

PlayerManager keeps a server-side `PlayerSession` for each player, moving through
`Connecting` → `Lobby` (and `InRound`/`Spectating` in later phases). It offers:

- Signals: `SessionAdded`, `PlayerLoaded` (the client finished booting), `SessionRemoving`.
- A **per-player Maid** (`GetMaid(player)`). Other systems should register per-player
  connections and instances on it so they get cleaned up when the player leaves.
- Queries: `GetSession`, `GetSessions`, `GetLoadedPlayers`, `GetPlayerCount`, `IsActive`, `SetStatus`.
- It handles players who joined before the script ran (common in Studio), ignores
  duplicate `ClientReady` calls, and logs a warning for clients that don't finish loading
  within 30 s.

### AdminService

Admins are authorised **by UserId** via `Config.Admin.UserIds`. In Studio everyone counts
as an admin, and the owner of a user-owned experience always does. For now the only admin
tool is the read-only `DebugQuery("ServerState")` remote, and non-admins get `nil`. The
full debug console (Phase 34) will check `AdminService.IsAdmin` on every command.

### Shared utilities

| Module | Purpose |
|---|---|
| `Logger` | Tagged logs filtered by level (`[VOIDLINE][S][PlayerManager] ...`). Debug level in Studio, Info and above in live games. `Logger.addSink` lets analytics hook in later. |
| `Signal` | Script-side events. Handlers are `task.spawn`ed, so one handler erroring or yielding doesn't block the others. |
| `Maid` | Cleans up connections, instances, threads and functions together. |
| `RateLimiter` | Token bucket keyed per player. |
| `Validate` | Runtime type checks you can combine, for remote arguments. |
| `TableUtil` | `deepFreeze`, `deepCopy`, `count`. |

`Config` and `Constants` are deep-frozen, so writing to them at runtime throws.
`Config` replicates to clients, so **never put secrets in it**.

---

## Testing Phase 1 in Roblox Studio

### 1. Single-player boot

Press **Play** (F5). You should see:

- In the **Output** window:
  - `[VOIDLINE][S][GameServer] Server ready (0.1.0-phase1) in X ms`
  - `[VOIDLINE][S][PlayerManager] Session created: <you>`
  - `[VOIDLINE][C][ClientMain] Client ready in X ms`
  - `[VOIDLINE][S][PlayerManager] Client loaded: <you>`
- On screen:
  - A status panel in the bottom-left reading `Link: ONLINE`, `Ship state: LOBBY`,
    `Crew aboard: 1`, `You: Lobby`, and `Build 0.1.0-phase1`.
  - A toast at the top: `[INFO] Link established. Welcome aboard the ASTERION.`
- In the Explorer, `ReplicatedStorage.Remotes` contains 6 remotes.

### 2. Multiple players and leaving

Go to **Test → Clients and Servers**, pick **3 players**, then **Start**.

- Every client should show `Crew aboard: 3`.
- Close one client window. The remaining clients should change to `Crew aboard: 2`, and
  the server Output should show `Session ended: Player3`.

### 3. Inspect server state (admin query)

During Play, open the command bar with the client context selected (**Test → Current:
Client**) and run:

```lua
local r = game.ReplicatedStorage.Remotes.DebugQuery
print(r:InvokeServer("ServerState"))
```

You should get a table with `Version`, `UptimeSeconds`, `Players` (each with Status,
IsLoaded and Strikes) and `Public` state.

### 4. Exploit simulation

Run each of these from the **client** command bar:

```lua
-- a) Rate-limit flood: no errors, Output (Debug level) shows "Rate limited ClientReady".
for i = 1, 50 do game.ReplicatedStorage.Remotes.ClientReady:FireServer() end

-- b) Malformed arguments: each call logs "Rejected DebugQuery ... argument 1: ...".
local r = game.ReplicatedStorage.Remotes.DebugQuery
print(r:InvokeServer(123))          --> nil
print(r:InvokeServer(0/0))          --> nil
print(r:InvokeServer("Nope"))       --> nil
print(r:InvokeServer("ServerState", "extra")) --> nil (too many arguments)

-- c) Strike kick: about 16 seconds later the client is kicked with "Connection error".
for i = 1, 20 do r:InvokeServer(i) task.wait(1.1) end

-- d) Privacy check: this must print nil. Other players' private state is never sent.
print(game.Players.LocalPlayer:GetAttribute("Session"))
```

To test the **non-admin** path, set `Config.Admin.AllowStudioAdmins = false`, then Play
and run test 3 again. It returns `nil`, and the server logs
`Non-admin ... attempted DebugQuery`.

### 5. Server shutdown

In a **Clients and Servers** test, click **Cleanup**. The server Output should show
`Server shutting down`. No service implements `Shutdown` yet; this just confirms the hook
runs.

### 6. Static checks (outside Studio)

```bash
./scripts/analyze.sh            # luau-lsp type check + lint against Roblox API definitions
rojo build -o Voidline.rbxl     # confirms the project tree is valid
```

---

## Conventions

- Use `--!strict` on every file, and typed Luau wherever it's practical.
- Services and controllers use PascalCase names and expose `Init`/`Start`/`Shutdown`.
- Don't use globals. Keep module state as `local`s inside the module.
- Get every remote name from `Net.Names`, and every tuning value from `Config`.
- Before changing an existing system, read it first and keep compatible behaviour.
  Don't silently overwrite it.
- Originality rule: no names, lore, assets, sounds, UI or map layouts taken from other
  games.

---

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| 1 | Core structure, config, bootstraps, remotes, logging, PlayerManager | ✅ |
| 2 | Lobby & player management (ready system, countdown, min/max players, private servers) | next |
| 3 | Round state machine (`LOBBY` → … → `RESET`) | |
| 4 | Secure role assignment | |
| 5 | Basic ASTERION map | |
| 6 | Interaction system | |
| 7 | Objectives & mini-games | |
| 8 | Sabotage | |
| 9 | Evidence | |
| 10 | Elimination | |
| 11 | Meetings & voting | |
| 12 | Escape / endgame | |
| 13 | Full UI | |
| 14 | Progression & DataStore | |
| 15–20 | Audio/VFX, mobile & controller, optimisation, anti-exploit testing, balancing, polish | |

## Known issues and limitations (Phase 1)

- The status panel is a **temporary diagnostic HUD**. It's controlled by
  `Config.Debug.ShowDebugHud` and is replaced in Phase 13.
- `GameServer` sets `RoundState = LOBBY` as a placeholder. `RoundManager` takes over
  this key in Phase 3.
- Everyone is an admin in Studio by design. Live servers rely on `Config.Admin.UserIds`
  and game ownership. Group-owned games need group-rank support, which comes in Phase 34.
- Exploiters can see remote names. That's expected: security comes from server-side
  validation, not from hiding names.
- If `Signal:DisconnectAll()` runs while a thread is inside `Signal:Wait()`, that thread
  never resumes. Avoid `Wait` on signals that may be destroyed.
- Nothing is persisted yet. DataStore and session locking come in Phase 14.
