# Redline Rush — Roblox Racing Game

A complete Roblox racing game written in Luau. Everything (the lobby, all 8
tracks, all 5 cars, the UI) is generated from code, so the whole game lives in
plain text files and builds into a place file with [Rojo](https://rojo.space).

## Features

| System | What you get |
| --- | --- |
| **5 cars** | Real-world car types, no branding: hot hatch, AWD rally sedan, V8 muscle coupe, Japanese GT tuner, mid-engine supercar. Each car has its own body shape, stats, price and level requirement. |
| **8 tracks** | Sunset Speedway, Downtown Circuit (night), Canyon Run (desert), Alpine Pass (snow), Coastal Highway, Redwood Rally (dirt/forest), Volcano Ring, Neon Drift (neon city). Each has its own scenery, lighting, laps and difficulty. |
| **Lobby** | Showroom with the 5 cars on turntables (walk up to one to open the Garage), live "next race" screen, global wins leaderboard, a test-drive ring road with jump ramps. |
| **Garage** | 3D car preview, stats, buy with coins (or Robux), select a car. |
| **Upgrades** | Engine, Turbo, Suspension, Brakes, Nitro. 5 levels each, saved per car. |
| **Customization** | Body paint, accent color (stripes / wing / scoop), rims, underglow (including an animated rainbow glow), paint finish (glossy, matte, metallic, carbon, chrome, neon). Some are unlocked by level or VIP. |
| **Levels** | XP from every race, level-up coin bonuses, cars and cosmetics unlock by level. |
| **Robux** | Coin packs, "Instant Max Upgrade" (one stat), "Fully Tuned" (every stat), unlock any car with Robux, VIP game pass (2x coins and exclusive cosmetics), 2x XP game pass. |
| **Racing** | Round-based: map vote → grid → 3-2-1 countdown → laps with checkpoints → live positions → results and rewards. Handles respawning, cars that flip over, players leaving, and personal-best lap times. |
| **Extras** | Daily login reward with streaks, promo codes (`LAUNCH`, `REDLINE`, `NITRO`), nitro that refills when you drift, chase camera with speed-based FOV, on-screen controls for mobile, gamepad support, DataStore saving with retries and duplicate-purchase protection. |

### Cars

| Car | Type | Unlock |
| --- | --- | --- |
| Street Hatch | Hot hatchback | Starter |
| Rally Sport | AWD rally sedan | Level 3 · 6,000 coins |
| Muscle V8 | American muscle coupe | Level 6 · 14,000 coins |
| Tuner GT | Japanese sports coupe | Level 10 · 28,000 coins |
| Hyper X | Mid-engine supercar | Level 15 · 65,000 coins |

### Controls

| Action | Keyboard | Gamepad | Mobile |
| --- | --- | --- | --- |
| Accelerate / brake / reverse | W / S (or arrow keys) | RT / LT | GAS / BRAKE |
| Steer | A / D | Left stick | < / > |
| Handbrake drift | Space | X | DRIFT |
| Nitro | Shift | A | N2O |
| Respawn at last checkpoint | R | Y | RESET |
| Switch camera distance / look back | V / hold C | R3 | — |
| Leave test-drive car | F | B | EXIT |

## Getting it into Roblox Studio

### Option A: open the place file (fastest)

1. Open `RedlineRush.rbxlx` in Roblox Studio.
2. Press **Play**. The lobby, tracks and UI are all built when the server starts.
3. To test multiplayer, use **Test → Clients and Servers** with 2+ players.

### Option B: live sync with Rojo (for development)

```bash
# install Rojo: https://rojo.space/docs/v7/getting-started/installation/
rojo serve            # then connect from the Rojo plugin in Studio
# or rebuild the place file:
rojo build default.project.json -o RedlineRush.rbxlx
```

### Turn on saving

Progress is saved with DataStores, which only work in a published game:

1. **File → Publish to Roblox**.
2. **Game Settings → Security → Enable Studio Access to API Services** (so saving also works in Studio).

If DataStores aren't available, the game still runs and tells the player that
progress won't be saved this session.

### Set up Robux purchases

1. In the [Creator Dashboard](https://create.roblox.com/dashboard/creations), open your experience → **Monetization**.
2. Create the **Developer Products** and **Passes** listed in
   `src/shared/Products.lua` (coin packs, MaxUpgrade, MaxAllUpgrades, Car_*,
   VIP, DoubleXP).
3. Paste each ID into `src/shared/Products.lua`. Until an ID is set, that item
   shows as "SOON" in the shop and can't be bought. Once it's set, the shop
   shows the live Robux price.

Purchases are handled in `src/server/ShopService.lua`. Each purchase ID is
stored with the player's save, so if Roblox retries a receipt the player
isn't charged or rewarded twice.

## Customizing

- **Balance:** `src/shared/Config.lua` has race timings, rewards, daily bonus, promo codes and suspension settings.
- **Cars:** `src/shared/Cars.lua` has stats, prices, level gates and body dimensions. The body is built by `src/shared/CarBuilder.lua`.
- **Tracks:** `src/shared/Maps.lua`. A track is a list of control points that a closed spline runs through, plus theme, lighting, laps and road width. Add a new entry and put its id in `Maps.Order` to add a map.
- **Upgrades / cosmetics / levels:** `Upgrades.lua`, `Customization.lua` and `Levels.lua` in `src/shared`.
- **Sounds:** set `Config.Sounds.Engine` to an audio asset id to get an engine sound whose pitch follows your speed.

## Project layout

```
src/
  shared/   (ReplicatedStorage.Shared)  config, cars, maps, upgrades, products, CarBuilder, Remotes
  server/   (ServerScriptService.Server)
    Main.server.lua   boot + request routing
    DataService       saving, coins, XP/levels, daily reward, leaderboard
    RaceService       round loop, voting, checkpoints, laps, positions, rewards
    CarService        spawning / seating / network ownership
    ShopService       coin purchases, customization, codes, Robux receipts & passes
    TrackBuilder      spline track generator + themed scenery
    LobbyBuilder      lobby, showroom, screens, test-drive ring
  client/   (StarterPlayerScripts.Client)
    Main.client.lua   boot + event wiring
    CarController     raycast-suspension arcade physics, input, chase camera
    LightingController, State
    UI/               HUD, Garage, Upgrades, Customize, Shop, Codes, RaceHUD, Results, Notify, MobileControls
tests/      headless smoke test (see below)
```

**How driving works:** the server spawns the car and gives the driver's client
network ownership. The client then runs the physics every frame: raycast
suspension, engine and brake forces, side grip, drifting and nitro. Because
the driver's client owns the car, everyone else sees it move smoothly. The
server tracks checkpoint crossings, laps and positions on its own, so a
client can't claim it finished a race it didn't drive.

## Smoke test

`tests/` runs the real server and client scripts against a mocked Roblox
engine inside a Luau VM (no Studio needed). It covers joining, codes, buying
and upgrading, customization, Robux receipts (including duplicate receipts), a
test drive, a full race on each of the 8 maps, re-seating a driver who left
their car, dying mid-race, and saving.

```bash
cd tests && npm install && npm test
```

The mock doesn't simulate real physics or rendering. To check how the cars
handle and how things look, play the game in Studio.
