# Grow a Reef

A Roblox farming game set underwater. Plant coral seeds on your reef, wait for them to grow,
harvest them and sell them for shells. Grown coral attracts fish you can catch for extra shells.
Coral can carry two mutations at once, sea events and currents add new ones, a Reef Index
tracks every coral and fish you find, and pets hatched from eggs follow you and help out.

Written in Luau as a [Rojo](https://rojo.space) project, following the Roblox skills in this
repository (`skills/other-engines/roblox-*`).

## The Starter Lagoon

Every new player starts in the middle of the lagoon, on the glowing dais in the plaza.

| Place | Where | What it's for |
|---|---|---|
| Spawn | Centre of the plaza | Where new players appear. |
| Inky, the tutorial guide | Beside the spawn | A purple octopus. Talk to him (E) for your first seeds and the next tutorial step. |
| Research Station | North | The glass dome from the concept art: the **Reef Index** hologram in the middle, the **Pet Hatchery** counter at the back, a submarine parked outside. |
| Upgrade Station | North, next to the dome | Old Shellby the turtle: **grow your reef**, gear, fences and decorations. |
| Coral Shop | East | Two counters: **Seeds** (Captain Coralie) and **Sell Coral** (Pinch). The Shop teleport lands in front of it. |
| Ocean Gate | West | A huge stone arch out to the open ocean. Shipwrecks sink out past it. |
| Reefs | All around | The six player reefs in a ring round the plaza, each gate facing the middle, with sand paths and jellyfish lamps leading to them. |
| Leaderboards | South | Top Reefs and Best Reefs, either side of the south path. |

The layout lives in `ReefConfig.Lagoon` (north is -Z). Each reef is turned to face the plaza
(`ReefConfig.plotFrame`), and coral and decoration positions are saved in the reef's own frame,
so they stay put whichever reef a player gets.

**Tutorial.** Inky walks every new player through five steps; a card at the top right shows the
current one, and a glowing beam and marker point the way:

1. Collect your first coral seed: talk to Inky (he gives 3 Bubble Kelp seeds).
2. Plant your first coral.
3. Earn your first shells: harvest it and sell at the Coral Shop.
4. Unlock your first fish: catch one at your reef (fish come to every grown coral on this step).
5. Learn how to expand your reef: visit the Upgrade Station.

Finishing pays 150 shells. Players who already had progress before the tutorial existed skip it.
Players still in the tutorial start at the plaza; everyone else starts at home.

## How to play

| Do this | How |
|---|---|
| Buy seeds | Walk to the **Coral Shop** (east), press the prompt at the green **Seeds** counter (E / tap). |
| Plant | Pick a seed in the hotbar at the bottom, then click or tap anywhere on your reef bed (the round brown patch). With a mouse, a ring shows where it goes: green fits, red is too close to other coral or the edge. |
| Harvest | Click fully grown coral (its label says "Ready!"). It goes into your bag. |
| Sell | Press the prompt at the orange **Sell Coral** counter in the Coral Shop. Everything in your bag sells. |
| Catch fish | Fish swim around grown coral on your reef. Click them before they swim off. |
| Grow your reef | You start with 10 coral slots. At the **Upgrade Station**, the Reef tab adds a slot (up to 50) and widens your bed, from 74 studs across to 108. |
| Fences and decorations | At the **Upgrade Station** (north, kept by Old Shellby the turtle) buy fence styles and decorations. Press **Place** on a decoration, go home, and tap anywhere inside your fence (not on coral or the gateway). Hold the prompt on a placed one to pick it up. |
| Gear | Also at the Upgrade Station: **Fertilizer** (coral grows faster), **Bubble Wand** (click a growing coral to speed it up) and **Bigger Bag** (your bag holds 30 coral, +30 a level). |
| Quests | **Quests** on the left: three daily quests, the same for everyone, new each day (UTC). Claim the reward when one is done; a red "!" shows when one is waiting. |
| Rebirth | In the Quests window. Pay the rebirth cost to start over for +25% shells from coral and fish, forever. You keep pets, the Index, fences, decorations, gear and titles. |
| Titles | Pick one in the Quests window; it shows over your head. Earned from Reef Index sets and from rebirthing. |
| Like a reef | Visit someone's reef and press **F** at the sign over its gate (once a day per reef). The sign shows its likes, and the **Best Reefs** board ranks them. |
| Reef Index | Press **Index** on the left, or use the hologram in the Research Station. Every coral in every mutation combo, and every fish. |
| Pets | Hatch eggs at the **Pet Hatchery** counter inside the Research Station, then take pets out from **Pets** on the left. |
| Teleport | **Shop** and **Home** on the right take you to the Coral Shop or your reef (3 s cooldown). The glowing whirlpool pads in front of the Coral Shop and each reef gate do the same. |
| Swim | Jump to start swimming: about twice walking speed, in the direction the camera points (tilt it well down or up to dive or rise). Hold jump to swim up; let go of everything to drift down and land. |

The whole map is underwater: deep-blue haze instead of sky, a glowing surface with light shafts
far overhead, kelp forests, coral clusters, starfish and urchins on the seabed, and drifting
specks and diver bubbles near you. Schools of reef fish, sea turtles, jellyfish, a manta ray
and crabs swim around. They are decoration and can't be caught; the fish to catch are the
ones that gather around your own grown coral.

Each counter has a shopkeeper: Captain Coralie, a diver behind the Seeds counter, Pinch, a crab
on the Sell Coral counter, and Old Shellby, a turtle at the Upgrade Station; Inky the octopus waits
by the spawn. They turn to face you and greet you when you walk up. Their
names and lines are in `ReefConfig.Shopkeepers`.

### Mutations and sea events

A coral can hold **two mutations**, and their multipliers multiply: Glowing + Golden sells at
x10, Prismatic + Shadow at x60. When a seed is planted it can sprout with one:

| Mutation | Where it comes from | Value |
|---|---|---|
| Glowing | 7.5% when planted (3x during Bioluminescent Night) | x2 |
| Golden | 2.2% when planted | x5 |
| Prismatic | 0.3% when planted | x15 |
| Frosted | grown coral during a Cold Current | x3 |
| Shadow | grown coral during a Bioluminescent Night | x4 |
| Molten | grown coral hit by a lava rock during a Volcano Vent | x6 |

The second mutation comes from sea events, or from a neighbour's coral through an Ocean
Current. Fish caught near mutated coral are worth more as well.

Every 3 minutes a **sea event** starts for everyone on the server. It is picked at random and
never the same twice in a row; the weights in `ReefConfig.Events` add up to 100, so each is
that event's percent chance. The timer under your shells counts down to the next one, then
shows the event running.

| Event | Length | What happens |
|---|---|---|
| Volcano Vent (6%) | 45 s | A volcano rises out past the lagoon's north-east rim and throws glowing lava rocks in arcs. Every 2.5 s one lands on a grown coral on each player's reef; a hit turns it Molten (x6) 60% of the time, if it has room for another mutation. The volcano sinks back afterwards. |
| Giant Octopus (6%) | 60 s | A giant octopus drops in over the plaza with a health bar (more health with more players). Tap or click it to hit it, up to 4 hits a second each. Beat it in time and everyone who hit it at least 5 times wins shells (x your coral slots / 10), 2 Glow Anemone and a Pearl Clam seed, with a 20% chance of a Starlight Coral seed. Otherwise it gets away. |
| Mermaid Merchant (6%) | 90 s | Marina the mermaid sets up a shell stall in the plaza with three offers: cheaper Glow Anemone, Pearl Clam and Starlight Coral seeds, and now and then a Seagrass seed for 350K shells. One of each per player. |
| Sunken Treasure Hunt (6%) | 120 s | A chest is buried on open seabed in the lagoon. Clue 1 names the nearest landmark and the direction from it; Clue 2 (after 45 s) says how many studs away and makes bubbles rise from the sand. The HUD shows how hot you are (Cold, Warm, Hot, Burning hot!). The first player to hold Dig on the spot wins shells (x your slots / 10), a Starlight Coral and two Pearl Clam seeds, with a 10% chance of Seagrass. |
| Ocean Current | 40 s | One mutation from a grown coral can drift onto a coral on the next player's reef downstream that has room for it, stacking with what it has (the last reef wraps around to the first). |
| Cold Current | 45 s | Grown coral can turn Frosted (x3). |
| Bioluminescent Night | 75 s | The sea goes dark so glowing things stand out. Glowing is 3x as likely on coral planted now, and grown coral can turn Shadow (x4). |
| Feeding Frenzy | 60 s | Fish come to grown coral twice as fast. |
| Treasure Storm | 40 s | Chests sink onto the plaza and reefs. Anyone can hold E (or tap) to open one for 30-200 shells, or sometimes rare seeds. Unopened chests wash away after 45 s. |
| Whale Pass | 50 s | A giant whale crosses overhead, and all coral grows twice as fast while it's there. |
| Shipwreck (5%) | 55 s | A liner sinks onto the seabed out past the Ocean Gate. 20 s after it starts, six orcas arrive and hunt for 30 s. They are faster than swimming, so swim inside the wreck (through the holes in its sides or the deck hatches) and stay there. Anyone caught is eaten and respawns at home. Everyone who was there when the orcas came and wasn't eaten gets a **Seagrass** seed. The HUD says whether you are hidden. |

### Reef Index

The **Index** button opens a collection book of every seed in all 16 mutation combinations
and every fish, 116 entries in all. Entries you haven't found are black silhouettes. Harvesting
a coral or catching a fish records it. Completing a seed's set pays 10x that seed's sell value
(180 shells for Bubble Kelp, up to 320,000 for Starlight Coral) and the fish set pays 1,000.
To also award a badge, create it on the Creator Dashboard and put its id in
`ReefConfig.Index.badges` under the set id.

### Pets

Eggs are sold at the **Pet Hatchery** (inside the Research Station) for shells, and every outcome's odds are shown before
you buy:

| Egg | Price | Seahorse | Pufferfish | Octopus |
|---|---|---|---|---|
| Reef Egg | 750 | 50% | 35% | 15% |
| Abyss Egg | 6,000 | 30% | 30% | 40% |

Any pet has a 4% chance to hatch **Golden**, which doubles its perk.

| Pet | Perk (Golden) |
|---|---|
| Seahorse | Coral grows 25% faster (50%) |
| Octopus | Harvests a grown coral every minute (30 s) |
| Pufferfish | Fish you catch are worth 50% more (double) |

Take out up to 2 pets at once; they swim beside you, and everyone sees them. Two of the same
kind don't add up. You can keep 24 and release one for 100 shells (1,000 if Golden). Eggs cost
shells only. If they are ever sold for Robux, Roblox's paid random items rules apply: read that
section of `skills/other-engines/roblox-simulator-economy/SKILL.md` first.

### Seeds

| Seed | Price | Grows in | Sells for | Restock chance |
|---|---|---|---|---|
| Bubble Kelp | 10 | 20 s | 18 | always |
| Brain Coral | 40 | 1 min | 75 | 90% |
| Sea Fan | 150 | 2.5 min | 300 | 60% |
| Glow Anemone | 600 | 5 min | 1,300 | 40% |
| Pearl Clam | 2,500 | 10 min | 6,000 | 20% |
| Starlight Coral | 12,000 | 20 min | 32,000 | 7% |
| Seagrass (Transcendent) | not sold | 30 min | 150,000 | Shipwreck survivors only |

The shop stock is shared by everyone on the server and restocks every 5 minutes. Growth is
stored as a timestamp, so coral keeps growing while you're offline.

### Upgrade Station, quests and rebirth

| Fence | Cost | Look |
|---|---|---|
| Shipwreck Wood | free | salvaged planks and posts with rope and barnacles |
| Kelp Hedge | 5K | kelp stalks topped with leafy bushes and a low hedge |
| Coral Stone Wall | 25K | pink stone pillars and stacked stone rows |
| Whale Bone | 120K | giant ribs arching over the reef, joined by rope |
| Glow Crystal | Reef Index reward (Glow Anemone set) | glowing crystal shards and a light bar |

Decorations: Lantern Post (800), Old Anchor (2.5K), Treasure Chest (6K), Bubble Vent (12K), Fish
Statue (40K), Rock Arch (90K). Up to 24 on a reef, 99 of each kind owned.

Gear has five levels each. Fertilizer: +10% growth speed a level. Bubble Wand: each click gives
a growing coral 1 s plus 1% of its grow time per level, then refills for 10 s. Bigger Bag:
30 coral, +30 a level; a full bag stops harvesting (and the octopus) until you sell.

Daily quests pay their shells times your coral slots / 10, so they keep up with you. Rebirths
cost 500K, then 1.5M, 4.5M and so on (x3 each). Optional rebirth badges go in
`ReefConfig.Rebirth.badges` once you create them on the Creator Dashboard.

Every Reef Index set now also gives a title, a fence, decorations or a Golden pet
(`ReefConfig.IndexRewards`); players who finished a set earlier get it when they next join.

### Admins

Owners and admins get a red **Admin** button on the left. Its window can:

- **Sea events:** start any event now (a running one ends first), or stop the running one.
- **Announcement:** type a message and send it to this server or to every server. It shows
  as a gold banner and in chat, after Roblox's text filter has checked it.
- **Gifts for everyone in this server:** 1 seed of any kind (Seagrass included), 1K, 10K or
  100K shells, or an instant Coral Shop restock.

Admins are listed by **user id** in `ReefConfig.Admin` (usernames can change; ids can't).
The id is the number in a player's profile link, `roblox.com/users/<id>/profile`.
far_rel2017 (5067168140) is the owner. To add an admin, put `[<id>] = "name"` in
`ReefConfig.Admin.admins` and publish. The server checks every admin request against these
lists, so the window alone gives nobody any power.

Every-server announcements use MessagingService, so they work in a published game (and in
Studio); if a publish fails, the message still shows on the server that sent it.

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
  ReefConfig.luau           every tunable number: seeds, mutations, fish, sea events, index, pets
  CoralVisuals.luau         coral models made from Parts, plus mutation effects (server and Index)
  FenceVisuals.luau         reef fences made from Parts: planks, hedge, wall, ribs or crystal
  DecorVisuals.luau         the reef decorations made from Parts
  EconomyMath.luau          copied unchanged from skills/other-engines/roblox-simulator-economy
src/server/                 -> ServerScriptService.Server
  Main.server.luau          starts everything in order
  World.luau                builds the Starter Lagoon: seabed, lighting, surface, plaza and
                            spawn, Inky, Research Station, Upgrade Station, Coral Shop, Ocean
                            Gate, paths, leaderboards and the ring of 6 reefs
  Tutorial.luau             the Starter Lagoon tutorial steps, Inky's lines and the reward
  SeabedDecor.luau          kelp forests, coral clusters, starfish and urchins
  PlayerData.luau           DataStore load/save with a session lock, data repair, leaderstats
  Plots.luau                plot assignment, free planting (PlantAt), growth, harvesting
  ReefIndex.luau            Reef Index finds, set rewards and IndexRewards (titles, fences, pets)
  Supplies.luau             Upgrade Station: fences, decorations, gear upgrades, Fertilizer
  Quests.luau               daily quests: progress and claiming
  Likes.luau                reef likes at each gate sign
  Rebirth.luau              rebirths and picking a title
  Pets.luau                 eggs, taking pets out, releasing, and the pet perks
  Teleport.luau             Shop/Home teleports, the whirlpool pads and their bubble effect
  Admin.luau                admin checks, event control, announcements, gifts
  ShopkeeperVisuals.luau    the shopkeeper models made from Parts, tagged "Shopkeeper"
  Shop.luau                 shared stock, buying, expanding, seed selection, selling
  Fish.luau                 fish spawning, swimming and catching
  Events.luau               sea event scheduler: timer, banner, night lighting, whale growth boost
  EventState.luau           the running event's modifiers, read by Plots and Fish
  Currents.luau             ocean current mutation spreading
  TreasureStorm.luau        treasure chests: dropping, opening, rewards
  Shipwreck.luau            the Shipwreck event: sinking, the orca hunt, eating, rewards
  ShipwreckVisuals.luau     the wreck and orca models made from Parts
  Volcano.luau              the Volcano Vent event: the volcano and its lava rocks
  GiantOctopus.luau         the Giant Octopus event: hits, health and prizes
  Merchant.luau             the Mermaid Merchant event: Marina's stall and offers (BuyMerchant)
  TreasureHunt.luau         the Sunken Treasure Hunt event: burying, clues, heat, digging
  EventVisuals.luau         the volcano, lava rock, octopus, mermaid stall and dig spot models
  Leaderboard.luau          global "Top Reefs" (shells earned) and "Best Reefs" (likes) boards
  RateLimit.luau            per-player token bucket for every request
src/client/                 -> StarterPlayer.StarterPlayerScripts.Client
  Main.client.luau          connects remotes and UI
  OceanEffects.luau         marine snow around the camera, bubbles from divers
  CoralLabels.luau          name and growth countdown over each coral
  Hud.luau                  shells, bag, sea-event timer, toasts, seed hotbar, side and Shop/Home buttons
  SuppliesPanel.luau        the Upgrade Station window (Reef, Gear, Fences, Decor)
  MerchantPanel.luau        Marina the Mermaid Merchant's trade window
  TutorialPanel.luau        the Starter Lagoon tutorial card, beam and marker
  QuestsPanel.luau          the Quests window: daily quests, rebirth, titles
  NameTags.luau             titles and rebirths over players' heads
  Swimming.luau             jump-to-swim movement and animation (client only)
  AdminPanel.luau           the Admin window (shown only to admins)
  IndexPanel.luau           the Reef Index window (3D entries, silhouettes, set progress)
  PetPanel.luau             the Pets window (eggs with odds, your pets)
  PetVisuals.luau           pet models made from Parts
  PetFollowers.luau         everyone's pets swimming beside them (client only)
  Planter.luau              placement preview ring, click/tap to plant or place decorations
  SeaLife.luau              fish schools, turtles, jellyfish, manta ray, crabs (client only)
  ShopPanel.luau            seed shop window
  Shopkeepers.luau          shopkeeper idle animation, turning and greetings (client only)
  Ui.luau                   shared colours and UI helpers
```

## How it stays fair

- The server owns every number. Remotes carry only ids ("buy `brain`"); prices, stock, growth
  and rewards come from `ReefConfig` on the server.
- Planting sends only the clicked point. The server checks that it is on your own bed, within
  reach, spaced from other coral and inside a free slot, using the same `plantProblem` rules the
  client preview uses. Harvesting and fish catching use `ClickDetector.MouseClick`, which fires
  on the server with the real player.
- Buying checks that the player is standing at the Coral Shop, and expanding at the Upgrade
  Station; eggs, at the Pet
  Hatchery. The server rolls every egg from the same odds list the window shows.
- Every request goes through a per-player rate limit.
- Saves use `UpdateAsync` with a session lease, so two servers can't overwrite each other's
  progress during a fast rejoin. Loaded data is repaired (bad numbers, unknown seeds, coral
  outside the bed, planting times in the future) instead of erroring. Version 1 saves, from the
  old tile grid, are converted to the same layout.

## Tuning

Change numbers in `src/shared/ReefConfig.luau`. Things you might want to change first:
`STARTING_SHELLS`, seed prices and grow times, `Mutations` weights, `Events` (interval, event weights and lengths, chest rewards),
`Fish.spawnChance`, `EXPAND` (each slot costs 20% more: 200, 240, 288 ... 244,961 for the 50th), and the bed:
`BED_RADIUS`, `BED_RADIUS_PER_SLOT` and `PLANT_SPACING` (keep `PLOT_SPACING` at least 2 x
(biggest bed radius + 7), which a test checks). `SeaLife` sets how many of each sea
creature swim around; the underwater look (Atmosphere, tint) is in `World.luau`'s `setupLighting`.

To change the economy with the pacing calculator, see
`skills/other-engines/roblox-simulator-economy/SKILL.md`.

## Test checklist

**Checked outside Studio** (Rojo 7.7.1, Lune 0.11.1, on 2026-11-23):

```bash
rojo build default.project.json -o GrowAReef.rbxlx   # builds
lune run tests/compile_check.luau src                # all 47 scripts compile
lune run tests/check_place.luau GrowAReef.rbxlx      # 362 checks pass
```

`check_place` confirms that the remotes exist, that each script has the right class and every
`require` points at a real module, and it runs the config and economy maths (sell values,
expand prices, mutation odds over 200,000 rolls).

**Checked in Studio** (solo Play through the Studio MCP server, on 2026-11-23): items 1 and 2
below with the free-planting reef (mouse planting with the green and red preview, the
too-close and edge refusals, harvesting, fish), and the shopkeepers turning, bobbing and
greeting. All five sea events were started with item 6 and checked: their timer and banner, the
night lighting fading out and back, chests landing and paying out, the whale crossing with
coral growing at 2x, and the current's stream. Growing the reef widened the bed. Also checked:
a Cold Current turning grown kelp Frosted and a Night stacking Shadow on top (Frosted + Shadow,
x12, also on the fish it attracts); the Reef Index recording harvests and catches; hatching
eggs at the Pet Hatchery (shells charged, odds shown), taking pets out (the third refused),
the Seahorse (1.25x growth), Octopus (harvest within a minute) and Pufferfish (x1.5 catch)
perks, and releasing. Output showed no game errors, only the expected DataStore warning.
Item 5 was checked on an iPhone 14 (the HUD and windows draw at 70% there, see `Ui.autoScale`)
and on a 1366 x 768 laptop (full size). Not yet checked: tap-to-plant on a real phone, the
random odds over many tries, a mutation drifting between two players' reefs, completing an
Index set, and items 3 and 4, which need a published place and two clients.

Roblox engine behaviour (parts, UI, DataStores, ClickDetectors) only runs inside Studio.
After changes, run these and check Output:

1. **Solo Play:** you spawn at your reef. Buy kelp, plant it, watch it grow, harvest it, sell it,
   then check that the Shells number changes. Click a growing coral (you should see a countdown
   message), and try planting next to a coral and at the bed edge (red ring, and a message
   saying why).
2. **Fish:** leave grown coral on the reef for about a minute; fish should appear and be
   catchable.
3. **Saving (published test place with API access):** earn shells, stop, play again. The shells,
   seeds, bag and planted coral should all be back, and coral should have kept growing.
4. **Server & Clients with 2 players** (Test tab): each gets their own reef; trying to plant on the
   other reef says it's theirs. Start a current (see item 6) and raise the Glowing weight, then
   check that a mutation crosses to the other reef.
5. **Phone:** Device Simulator on a phone. The HUD and the Shop, Index and Pets windows shrink
   to 70% (see `Ui.screenScale`); check the hotbar and shop fit and can be tapped.
6. **Sea events:** in Studio you don't have to wait. In the Command Bar, in the server view, run
   `workspace:SetAttribute("DebugSeaEvent", "Whale")` (or `Current`, `Cold`, `Night`, `Frenzy`,
   `Treasure`, `Shipwreck`, `Volcano`, `Octopus`, `Merchant`, `Hunt`) to start that event now. This only works in Studio.

## Known limits and next steps

- The map is built by `World.luau` when the server starts, because it was written without
  Studio. Once you're happy with it, you can copy `Workspace.Reef` from a running session into
  the place and replace the builder with your own models.
- No rebirths, gamepasses or Robux items yet. If you add paid random items (eggs or packs), read
  the paid random items section of the economy skill first.
- Coral is single-harvest. Regrowing coral or fertiliser items would be natural additions.
