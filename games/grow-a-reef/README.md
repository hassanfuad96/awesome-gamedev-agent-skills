# Grow a Reef

A Roblox farming game set underwater. Plant coral seeds on your reef, wait for them to grow,
harvest them and sell them for shells. Grown coral attracts fish you can catch for extra shells.
Ocean currents carry rare mutations from one player's reef to the next.

Written in Luau as a [Rojo](https://rojo.space) project, following the Roblox skills in this
repository (`skills/other-engines/roblox-*`).

## How to play

| Do this | How |
|---|---|
| Buy seeds | Walk to the **Seed Shop** (green stand) and press the prompt (E / tap). |
| Plant | Pick a seed in the hotbar at the bottom, then click or tap an empty tile on your reef. |
| Harvest | Click fully grown coral (its label says "Ready!"). It goes into your bag. |
| Sell | Walk to **Sell Coral** (orange stand) and press the prompt. Everything in your bag sells. |
| Catch fish | Fish swim around grown coral on your reef. Click them before they swim off. |
| Grow your reef | In the Seed Shop, "Unlock a reef tile" adds one of 6 locked tiles. |

Each stand has a shopkeeper: Captain Coralie, a diver behind the Seed Shop counter, and Pinch,
a crab on the Sell Coral counter. They turn to face you and greet you when you walk up. Their
names and lines are in `ReefConfig.Shopkeepers`.

### Mutations and currents

When a seed is planted it can sprout with a mutation that multiplies its sell value:

| Mutation | Chance | Value |
|---|---|---|
| Glowing | 7.5% | x2 |
| Golden | 2.2% | x5 |
| Prismatic | 0.3% | x15 |

Every 4 minutes an **ocean current** flows along the row of reefs for 40 seconds. While it
flows, a fully grown mutated coral can copy its mutation onto an un-mutated coral on the next
player's reef downstream (the last reef wraps around to the first). Fish caught near
mutated coral are worth more as well.

### Seeds

| Seed | Price | Grows in | Sells for | Restock chance |
|---|---|---|---|---|
| Bubble Kelp | 10 | 20 s | 18 | always |
| Brain Coral | 40 | 1 min | 75 | 90% |
| Sea Fan | 150 | 2.5 min | 300 | 60% |
| Glow Anemone | 600 | 5 min | 1,300 | 40% |
| Pearl Clam | 2,500 | 10 min | 6,000 | 20% |
| Starlight Coral | 12,000 | 20 min | 32,000 | 7% |

The shop stock is shared by everyone on the server and restocks every 5 minutes. Growth is
stored as a timestamp, so coral keeps growing while you're offline.

## Set it up in Roblox Studio

1. Install Rojo 7.7 (the Rojo Studio plugin plus the `rojo` command, from
   <https://rojo.space/docs/v7/getting-started/installation/>).
2. Build a place file and open it:

   ```bash
   cd games/grow-a-reef
   rojo build default.project.json -o GrowAReef.rbxlx
   ```

   Open `GrowAReef.rbxlx` in Studio. To keep editing the code and see changes live, run
   `rojo serve` and press **Connect** in the Rojo plugin instead.
3. **Max players: 6.** There are six reefs. In Studio, File → Game Settings → Places, set
   *Max Players* to 6 (more players than reefs get kicked with a "server is full" message).
3. **Saving.** Publish the place (File → Publish to Roblox), then turn on File → Game Settings →
   Security → *Enable Studio Access to API Services*. Use a test place for this, because Studio
   reads and writes the same live data your players use. Without it the game still runs in Studio,
   but progress isn't saved (Output shows a warning).
5. Press **Play**.

## Project layout

```
default.project.json        Rojo mapping; also creates the RemoteEvents and sets Gravity = 70
src/shared/                 -> ReplicatedStorage.Shared
  ReefConfig.luau           every tunable number: seeds, mutations, fish, currents, prices
  EconomyMath.luau          copied unchanged from skills/other-engines/roblox-simulator-economy
src/server/                 -> ServerScriptService.Server
  Main.server.luau          starts everything in order
  World.luau                builds the seabed, lighting, stands, shopkeepers, leaderboard board and 6 plots
  PlayerData.luau           DataStore load/save with a session lock, data repair, leaderstats
  Plots.luau                plot assignment, planting, growth, harvesting (ClickDetectors)
  CoralVisuals.luau         coral models made from Parts, plus mutation effects
  ShopkeeperVisuals.luau    the shopkeeper models made from Parts, tagged "Shopkeeper"
  Shop.luau                 shared stock, buying, expanding, seed selection, selling
  Fish.luau                 fish spawning, swimming and catching
  Currents.luau             ocean current event and mutation spreading
  Leaderboard.luau          global "Top Reefs" board (OrderedDataStore of shells earned)
  RateLimit.luau            per-player token bucket for every request
src/client/                 -> StarterPlayer.StarterPlayerScripts.Client
  Main.client.luau          connects remotes and UI
  Hud.luau                  shells, bag, current timer, toasts, seed hotbar
  ShopPanel.luau            seed shop window
  Shopkeepers.luau          shopkeeper idle animation, turning and greetings (client only)
  TileLabels.luau           growth countdowns over each tile
  Ui.luau                   shared colours and UI helpers
```

## How it stays fair

- The server owns every number. Remotes carry only ids ("buy `brain`"); prices, stock, growth
  and rewards come from `ReefConfig` on the server.
- Planting, harvesting and fish catching use `ClickDetector.MouseClick`, which fires on the
  server with the real player, so the client never says which tile it owns.
- Buying and expanding check that the player is standing at the Seed Shop.
- Every request goes through a per-player rate limit.
- Saves use `UpdateAsync` with a session lease, so two servers can't overwrite each other's
  progress during a fast rejoin. Loaded data is repaired (bad numbers, unknown seeds, tiles in
  the future) instead of erroring.

## Tuning

Change numbers in `src/shared/ReefConfig.luau`. Things you might want to change first:
`STARTING_SHELLS`, seed prices and grow times, `Mutations` weights, `Current.interval`,
`Fish.spawnChance`, and `EXPAND` (tile prices are 200, 500, 1,250, 3,125, 7,812, 19,531).

To change the economy with the pacing calculator, see
`skills/other-engines/roblox-simulator-economy/SKILL.md`.

## Test checklist

**Checked outside Studio** (Rojo 7.7.1, Lune 0.11.1, on 2026-11-23):

```bash
rojo build default.project.json -o GrowAReef.rbxlx   # builds
lune run tests/compile_check.luau src                # all 19 scripts compile
lune run tests/check_place.luau GrowAReef.rbxlx      # 87 checks pass
```

`check_place` confirms that the remotes exist, that each script has the right class and every
`require` points at a real module, and it runs the config and economy maths (sell values,
expand prices, mutation odds over 200,000 rolls).

**Checked in Studio** (solo Play through the Studio MCP server, on 2026-11-23): items 1, 2 and
5 below, plus the shopkeepers turning, bobbing and greeting. Output showed no game errors, only
the expected DataStore warning. Items 3 and 4 still need a published place and two clients.

Roblox engine behaviour (parts, UI, DataStores, ClickDetectors) only runs inside Studio.
After changes, run these and check Output:

1. **Solo Play:** you spawn at your reef. Buy kelp, plant it, watch it grow, harvest it, sell it,
   then check that the Shells number changes. Click a growing coral (you should see a countdown
   message) and a locked tile (you should see the "Expand" message).
2. **Fish:** leave grown coral on the reef for about a minute; fish should appear and be
   catchable.
3. **Saving (published test place with API access):** earn shells, stop, play again. The shells,
   seeds, bag and planted coral should all be back, and coral should have kept growing.
4. **Server & Clients with 2 players** (Test tab): each gets their own reef; clicking the other
   reef says it's theirs. To test currents quickly, set `Current.interval = 20` and raise the
   Glowing weight, then check that a mutation crosses to the other reef.
5. **Phone:** Device Simulator, check the hotbar and shop fit and can be tapped.

## Known limits and next steps

- The map is built by `World.luau` when the server starts, because it was written without
  Studio. Once you're happy with it, you can copy `Workspace.Reef` from a running session into
  the place and replace the builder with your own models.
- No rebirths, gamepasses or Robux items yet. If you add paid random items (eggs or packs), read
  the paid random items section of the economy skill first.
- Coral is single-harvest. Regrowing coral or fertiliser items would be natural additions.
