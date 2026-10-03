# VOIDLINE launch checklist

The code is complete, but some launch steps can only be done by the owner of the Roblox experience: publishing, settings, product IDs, assets and live playtests. This checklist covers them, in order.

Some items are marked **(Owner)**. These need your Roblox account or group.

---

## 1. Build and import

- [ ] Run `rokit install`, then `rojo build -o Voidline.rbxl`. Open the file in Studio, or use `rojo serve` with the Rojo plugin.
- [ ] Remove the default Baseplate if you like. The lobby floats at y=60 and the ship at y=200, so it isn't required.
- [ ] Check that the place has these:
  - `ServerScriptService.Server.GameServer`, a **Script**
  - `StarterPlayerScripts.Client.ClientMain`, a **LocalScript**
  - `ReplicatedStorage.Shared`
  - `Workspace.StreamingEnabled` set to `true`
- [ ] Press Play. The Output window should show `Built ASTERION (... parts)` and `Server ready`.

## 2. Configure (code)

These values are in `src/shared/Config.luau`.

- [ ] Add your developer UserIds to `Admin.UserIds`. Admin tools work for everyone in Studio and for the owner of a user-owned experience. A **group-owned** game needs its developers listed here.
- [ ] Make sure `Admin.AllowStudioAdmins` stays `true`. It only applies inside Studio.
- [ ] Review the player counts: `Players.MinPlayers` (6) and `MaxPlayers` (12).
- [ ] If you'll sell cosmetic Credits (see section 4), fill in the Robux product IDs:
  - `Monetization.CreditPacks[*].ProductId`
  - `Monetization.SupporterPassId`
- [ ] Bump `Game.Version` for each release.
- [ ] If you change the experience title, update `Game.Title`. "VOIDLINE" is a placeholder; check that your final name isn't already in use.

## 3. Experience settings in Studio **(Owner)**

Go to **Game Settings** in Studio.

- [ ] **Basic Info:** set the name, description, genre, and the devices it supports: **Computer, Phone, Tablet and Console**.
- [ ] **Permissions:** make the experience Public when you're ready to launch.
- [ ] **Security:**
  - [ ] Turn **Enable Studio Access to API Services** on, so DataStores work in testing.
  - [ ] Leave **Allow HTTP Requests** off. It isn't needed.
- [ ] **Places → Server size:** set it to 12, to match `Config.Players.MaxPlayers`.
- [ ] **Avatar:** R15 is recommended, because emotes use the R15 `Animate` script. Cosmetics support both R6 and R15.
- [ ] **Communication:**
  - [ ] Enable **Chat**. The game uses TextChatService (proximity, radio and ghost chat).
  - [ ] Optionally enable **Spatial Voice**. Voice is proximity-based by default.
- [ ] **Monetization:** enable **Private Servers** if you want them. Hosts get match settings and can start early.
- [ ] Fill in the **Experience Questionnaire / content maturity** form. Accurate answers: no blood or gore; "players are eliminated" through stylised stasis crystals; text and voice chat; social deduction.

## 4. Monetization (optional, cosmetic only) **(Owner)**

- [ ] Go to **Creator Hub → your experience → Monetization → Developer Products**. Create one credit pack for each entry in `CreditPacks`, then paste the IDs into Config.
- [ ] Go to **Passes** and create the "Supporter" pass, which unlocks a cosmetic nameplate only. Paste its ID into `SupporterPassId`.
- [ ] Do **not** sell anything that affects gameplay (roles, speed, cooldowns, information). The code has no hooks for it, and the design rules forbid it.
- [ ] Test purchases in Studio. Purchases there are free test prompts. Then confirm the credits arrive, and that buying again with the same receipt doesn't grant them twice.

## 5. Audio **(Owner)**

- [ ] Upload **original or properly licensed** sounds to your account or group. Don't use sounds taken from other games.
- [ ] Paste each one as `rbxassetid://<id>` into `src/shared/Data/AudioCatalog.luau`. Every entry has a placeholder and a caption.
- [ ] If you add a soundtrack, credit it in `UI/Screens/Credits.luau`.

## 6. Store presence **(Owner)**

- [ ] Make an original icon (512×512) and thumbnails. Build them from in-game screenshots of the ASTERION; never use another game's art.
- [ ] Write a description in your own words, covering: social deduction, survival, cosmetic-only purchases, and support for mobile, console and PC.
- [ ] Optionally create Roblox Badges that mirror the in-game Ship Badges. The current badges are stored in the profile only.

## 7. Playtests before launch

Run [TESTING.md](TESTING.md) in full. The minimum:

- [ ] **Solo in Studio.**
  1. Ready up and wait for the countdown (or use F2 → Start round).
  2. Complete an objective, fix a hazard, and call a muster.
  3. Use F2 → Set restoration 100, then complete the extraction.
  4. Check the results screen and that rewards were saved.
- [ ] **Clients and Servers, 3–4 players.** Check that:
  - roles are secret, and only infiltrators see siphon prompts;
  - siphoning works, along with revive, report, scan and scrub;
  - voting works, including ties and skips;
  - a player disconnecting mid-vote is handled correctly.
- [ ] **A published private server with 6+ real players.** Check pacing, balance and how readable everything is on phones.
- [ ] **A real device check.** At least one phone, one tablet and one gamepad.
- [ ] **Exploit pass.** Run the snippets in TESTING.md §Exploits from the client command bar in Studio.

## 8. Launch day

- [ ] Publish, then check the server Output in the Developer Console (F9) for warnings.
- [ ] Watch **Creator Hub → Analytics → Custom events**. Useful events include `RoundReward`, `ObjectiveCompleted`, `SabotageUsed` and `MeetingCalled`.
- [ ] Keep an admin in the first servers. F2 → *Refresh server state* shows each round's state, players, hazards and the analytics counters.
- [ ] Plan a balance pass after about 100 rounds, using the metrics in TESTING.md §Balancing.

## Post-launch backlog

- Real audio and music, and a custom ProximityPrompt style.
- A second ship layout, via another `ShipLayout`-style data module.
- Roblox Badges for the Ship Badges, and seasonal cosmetics.
- Group-rank admin authorisation (`AdminService.IsAdmin`).
