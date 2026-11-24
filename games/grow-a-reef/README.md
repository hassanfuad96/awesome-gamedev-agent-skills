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
| Kai, the Guide | Beside the spawn | In a blue cap and polo. Talk to him at the guide rock (E) for your first seeds and the next tutorial step. |
| Research Laboratory | North-west, the biggest | A geodesic glass dome (from `5-athmosphere.jpg`) over a lit research tower, labs and coral garden beds, with a big glowing coral on top and a robot arm outside. Its counter: **research species**, **unlock planters**, **coral growth** research and **reef health**. |
| Aquarium | North-east | The Collection Center: display tanks filled with the fish, coral and rare creatures you've discovered (each player sees their own), the **Reef Index** hologram and the **Pet Hatchery**. |
| Coral Market | South-east | **Seeds** (Coralie the Shopkeeper), **Sell Coral** (Pinch), **Decor & Fences**, and a case of rare species. The Shop teleport lands beside it. |
| Equipment Station | South-west | Captain Mako, the Master Diver (press F by him to change your diving suit): the **Bubble Wand**, **Bigger Bag**, **Oxygen Tank** and **Swim Fins**. |
| Ocean Gate | West | A huge stone arch; the road through it leads to the **Main Reef**, where the reefs are. |
| Roads | North, east, south | North to the **Kelp Forest** (or the whirlpool at the plaza's north edge), east to the **Sunken Ruins**, south past the leaderboards to the **Abyss**. |
| Leaderboards | South | Top Reefs and Best Reefs, either side of the south path. |

Each building is joined to the plaza by a walk-through glass tube corridor, like the concept art.

**Species research.** Coral seeds in the Coral Market are locked until you research them at the
Lab, in order: Bubble Kelp is known from the start; each next species needs the one before it
researched and harvested at least once, plus shells (Brain Coral 150, Sea Fan 600, Glow Anemone
2,500, Pearl Clam 10,000, Starlight Coral 50,000). Seeds from rewards can always be planted.
Players from before research keep every species they had grown, planted or held seeds of.

**Oxygen.** You breathe freely almost everywhere. Deep water uses up air: the Main Reef's caves
and grotto, the Sunken Ruins' cave, and the Abyss below y = -15 (except its air pockets). An air
bar appears while you dive and refills the moment you're out. Run out and a whirlpool carries you
back to the plaza. You start with 60 seconds; the **Oxygen Tank** adds 45 a level (285 at the top).

The layout lives in `ReefConfig.Lagoon` (north is -Z). The lagoon's rocky rim
(`rimRadius`) is open at the Ocean Gate (west) and at the sand road to the Sunken Ruins (east).

**Tutorial.** Kai walks every new player through five steps; a card at the top right shows the
current one, and a glowing beam and marker point the way:

1. Collect your first coral seed: talk to Kai (he gives 3 Bubble Kelp seeds).
2. Plant your first coral.
3. Earn your first shells: harvest it and sell at the Coral Shop.
4. Unlock your first fish: catch one at your reef (fish come to every grown coral on this step).
5. Learn how to expand your reef: visit the Research Laboratory's counter.

Finishing pays 150 shells. Players who already had progress before the tutorial existed skip it.
Players still in the tutorial start at the plaza; everyone else starts at home.

## The Main Reef

Where players spend most of their time: the big coral garden through the Ocean Gate, built
from the `images/*-zone2.jpg` concept art. Layout in `ReefConfig.MainReef`; scenery in
`src/server/MainReef.luau`.

| Feature | What's there |
|---|---|
| Reef road | A flagstone road west from the Ocean Gate, under a "THE MAIN REEF" arch, lined with orange coral trees with pink and purple canopies. |
| Player reefs | Six reefs, three either side of the road, gates facing it. Each is a fenced bed of **30 sand planters**: 20 unlocked to start, the rest unlocked at the Upgrade Station. |
| Coral bridges | Two coral arches over the road between the reefs; walk or swim over the top (a pearl sometimes sits up there). |
| Fish nurseries | Four rings of glowing anemones in the gaps between reefs. **Wild fish** gather there (two at a time); anyone can click one to catch it. |
| Rock ridges and caves | Low-poly rock ridges wall the reef in north and south, with three small **caves** lit by crystals. Pearls hide inside. |
| Grand Reef Rock | A tall rock tower at the end of the road, coral on every ledge and bubbles streaming off the top, with a **grotto** in its foot. |
| Coral gardens | Clusters of table, tube and branching coral, sea grass and rocks over the open sand. |

**Planters and growth.** Each planter holds one coral. Tap a sand planter (glowing rim = empty
and unlocked; dark rock = locked) to plant. Every coral grows through three stages, shown on the
reef and in its label:

1. **Seedling**: thin sprouts poking out of the sand (the first 35% of its grow time).
2. **Growing**: the coral itself, filling out from half size.
3. **Fully grown**: full size, with polyps round its foot and bubbles rising, and a burst of
   bubbles when it gets there. Ready to harvest; fish gather round it.

**Shells and pearls.** 18 shells and 4 pearls lie around the Main Reef at any time: shells on
the open sand (5 to 25 shells each), pearls in the caves, the grotto, on the bridges and on top
of the Grand Reef Rock. Swim into one to pick it up; another appears elsewhere a minute or two
later. Pearls show next to your shells and are what unlocking planters 21 to 30 needs:

| Planter | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30 |
|---|---|---|---|---|---|---|---|---|---|---|
| Shells | 1,000 | 1,550 | 2,402 | 3,723 | 5,772 | 8,946 | 13,867 | 21,494 | 33,316 | 51,639 |
| Pearls | 1 | 1 | 2 | 2 | 3 | 3 | 4 | 4 | 5 | 5 |

Saves from before planters load safely: coral moves to the nearest free planter (or its seed
goes back in your bag if none is left), reefs with fewer than 20 slots get 20, and slots past 30
are paid back in shells at what they cost.

## The Sunken Ruins

The exploration zone, built from the `2-Sunken-Ruins.jpg` concept art. Follow the sand road east
from the plaza, or press **Ruins** on the right. It is a disc of radius 175 centred at
(430, 0, 0), x 255 to 605, and it is where the **Shipwreck** event's liner sinks. Its layout,
rewards and missions are all in `src/shared/RuinsConfig.luau`.

| Place | What's there |
|---|---|
| Entrance | Two great pillars under a "SUNKEN RUINS" plaque. **Marlo** the Explorer (talk at his rock: E) gives the missions and opens your Journal. A whirlpool takes you back to the shops. |
| Archway | A ruined stone arch over the road, with a chest on its cap stone. |
| Wreck Basin | Open sand ringed by rocks and bubble vents (left as you walk in). The Shipwreck liner lands here, and the Giant Squid rises out of it every 6 minutes. |
| Temple terrace | Up a flight of mossy steps (right): broken columns, the temple and its sanctum (an altar with the Stone Tablet, and the Relic Coral), the mermaid statue with her harp, and the tallest column, with the Old Spyglass on top. |
| Pirate ship | Bow up on a rock, sails torn, the main mast snapped. Swim in through the holes in its sides or the deck hatches: the hold has a chest and the Golden Compass. |
| Underwater cave | At the far end: a tunnel into a dark chamber lit by crystals and glowing mushrooms. Ghost Coral, a chest, the Crystal Trident and the Anglerfish. |
| Coral garden | The treasure trove from the art (a huge open chest spilling gold), a giant anchor, and the ship's wheel with the Ship's Bell beside it. |

What you can find, all saved per player:

- **8 treasure chests.** Each one refills for you 20 minutes after you open it. Each opening gives
  120 to 450 shells (scaled with your reef like daily quests, up to x3), or, 40% of the time, seeds: Brain Coral up to
  Starlight Coral, and 4% of seed drops are Ghost Coral.
- **Hidden coral**, two species sold nowhere: **Ghost Coral** (Mythic: 15 min, sells for 9,000)
  grows at two spots in the cave, and **Relic Coral** (Ancient: 30 min, sells for 45,000) grows
  in the sanctum. Take one cutting (a seed) from each spot a day (UTC). The Relic Coral only
  lets divers who have found all six relics take a cutting.
- **6 relics** (Golden Compass, Pearl Crown, Stone Tablet, Ship's Bell, Crystal Trident, Old
  Spyglass): 500 shells each, found once.
- **4 rare creatures** (Coelacanth, Anglerfish, Leafy Sea Dragon, Giant Squid): swim close to
  one to spot it, for 750 shells the first time. Their paths depend only on the server time,
  so every player sees them in the same place, and the server checks sightings against that path.

**Exploration missions.** Marlo's nine missions run in order; each one finishes as soon as it's
done and pays its reward. A card at the top right shows the current one once the tutorial is
over, with a marker while you're in the ruins.

| # | Mission | Reward |
|---|---|---|
| 1 | Find the Sunken Ruins | 200 shells |
| 2 | Open a treasure chest | 400 shells |
| 3 | Find a lost relic | 600 shells, 1 Sea Fan |
| 4 | Explore the underwater cave | 800 shells |
| 5 | Take a hidden coral cutting | 1,000 shells, 1 Glow Anemone |
| 6 | Spot a rare sea creature | 1,500 shells |
| 7 | Board the pirate ship | 2,000 shells, 1 Pearl Clam |
| 8 | Find all six relics | 5,000 shells, 1 Relic Coral, the "Ruin Explorer" title |
| 9 | Spot all four rare creatures | 8,000 shells, 1 Relic Coral, 2 Ghost Coral |

The **Journal** button on the left (or talking to Marlo) opens the Explorer's Journal: the
missions, where each relic and creature is, when each chest refills and when the coral regrows,
and a **Go to Ruins** button. Each player sees their own state in the world: a chest you've
emptied shows its refill time, relics you've found are gone, and cut coral says when it regrows.

## The Abyss

Zone 3, built from the `3-athmosphere.jpg` concept art: a dark, bioluminescent trench south of
the plaza. Follow the sand road south through the gap in the lagoon's rim to the **Pressure
Gate**, then take the glowing ramp down the pit's north wall to the floor, 45 studs below the
seabed. Once it's unlocked, the Journal's **Go to Abyss** button takes you straight to the floor.
Its layout, unlock rules and creatures are in `src/shared/AbyssConfig.luau`.

**Unlocking.** Reach either **Exploration Level 5** (5 Sunken Ruins missions done) or **Reef
Health 200** (200 coral harvested, ever). It opens for good the moment you qualify, and the
Journal shows how close you are. Until then the server turns you back at the gate if you swim
down into the pit, and refuses the teleport.

**The look.** The sea gets darker and bluer as you go down (a tint and bloom of each player's
own, so sea events' lighting is untouched), and everything down there glows: violet and teal
branching coral with bright tips, anemones, glowing kelp, a giant brain coral wrapped in a
shimmering glow, a forest of giant glowing mushrooms, crystal formations, and the 42-stud
**Crystal Spire** in the middle. Twenty-two glowing jellyfish drift round the pit, most of them
in the jellyfish garden, and faint violet light falls from far above.

| What | Where | |
|---|---|---|
| Lumi's Deep Seeds | By the foot of the ramp | Lumi the lanternfish sells the high-value abyssal coral (below) at fixed prices, as many as you can afford. |
| Whirlpool | Beside Lumi's stall | Back to the shops; where Go to Abyss lands you. |
| Air pockets | At the whirlpool, Lumi's stall and the Crystal Spire | Columns of bubbles rising from glowing vents (`AbyssConfig.AirPockets`): your air refills inside them. |
| Ghost Shark | High over the whole pit | 1,500 shells for your first sighting of each creature. |
| Vampire Squid | Close round the Crystal Spire | |
| Gulper Eel | Low along the south wall | |
| Dumbo Octopus | In the mushroom forest | Spot all four for the "Abyss Diver" title and a Glowcap seed. |

| Abyssal coral | Price | Grows in | Sells for | Index set reward |
|---|---|---|---|---|
| Glowcap | 45,000 | 25 min | 120,000 | 3 Lantern Posts |
| Lumen Brain | 180,000 | 40 min | 480,000 | "Deep Glow" title, a Bubble Vent |
| Void Bloom | 750,000 | 1 h | 2,000,000 | "Void Walker" title, a Golden Octopus |

**Checked in Studio** (solo Play through the Studio MCP server, on 2026-11-24): the zone builds
with no errors. A new player is refused the Abyss teleport with the reason, and is put back at
the gate after swimming into the pit. Finishing the fifth Sunken Ruins mission unlocks it on
the spot. Go to Abyss lands on the floor pad. Lumi's window opens; a purchase is refused
without enough shells and goes through with them; an unknown seed id is ignored. All four
deep-sea creatures were spotted (each paid, then the all-four reward). The lighting holds steady
on the shelf, returns to normal in the other zones, and reaches full darkness on the floor.
Not yet checked: walking down the ramp, sea-event lighting (Bioluminescent Night) while inside,
and the Abyss on a phone.

## The Kelp Forest

A different ecosystem from the coral reefs, built from the `4-athmosphere.jpg` concept art: a
sunlit forest of giant kelp north of the lagoon. Take the sand road north from the plaza
(between the dome and the Upgrade Station), or the whirlpool at the plaza's north edge. It is a
disc of radius 215 centred at (-80, 0, -470); layout and challenges are in
`src/shared/KelpConfig.luau`.

| Feature | What's there |
|---|---|
| Giant kelp | About 70 kelp stalks, 45 to 95 studs tall, with long translucent blades, gas bladders and golden fronds at the top. They sway, the water turns a sunlit green while you're inside, and shafts of light pour down through them. Schools of dark fish drift between the stalks. |
| Sunlit clearing | Open sand in the middle of the forest, where the main trail loops round. |
| Hidden paths | Faint trails of glowing pebbles leave the main trail, one of them under a rock overhang, and lead through gaps in walls of dense kelp to three hidden glades: the **Statue Glade**, the **Moonpool** and the **Diver's Camp**. Pearls can turn up inside them. |
| Sea turtle habitats | **Turtle Cove** and **Turtle Reef**: sandy clearings with nests, turtles resting on the sand and swimming round. Hold the prompt at a nest to guide a hatchling out to sea (60 shells; each nest rests 10 minutes for you afterwards). |
| Seagrass restoration | The **East** and **West Meadows**, 10 patches each, shared by everyone on the server. Hold the prompt on a bare mud patch to plant seagrass (30 shells). It grows for 2 minutes, stays lush for 15, then wilts back to bare. |
| New fish | Five kelp forest species caught only here: Garibaldi, Kelp Bass, Opaleye, Sheephead and the rare Giant Sea Bass. They're wild fish (anyone can catch them) at the clearing and the turtle cove, and by each meadow while it's at least half restored: healthy seagrass brings the fish back. They're in the Reef Index too. |
| Otto the sea otter | The forest's ranger, at the entrance. Talk to him for his Ranger Journal of challenges, with progress and the meadows' health. |

**Exploration challenges** (any order; each pays once, the moment it's done):

| Challenge | How | Reward |
|---|---|---|
| Into the Kelp | Reach the forest | 250 shells |
| Canopy Climber | Swim up to the kelp canopy | 500 shells |
| Turtle Friend | Visit both turtle habitats | 600 shells |
| Hatchling Helper | Guide 3 hatchlings to the sea | 900 shells, 1 Glow Anemone |
| Off the Beaten Path | Find a hidden glade | 800 shells |
| Meadow Mender | Plant 10 seagrass patches | 1,500 shells, 1 Sea Fan |
| Kelp Naturalist | Catch all five kelp fish | 3,000 shells, 1 Pearl Clam |
| Kelp Ranger | Find all three hidden glades | 4,000 shells, 1 Starlight Coral, the "Kelp Ranger" title |

## How to play

| Do this | How |
|---|---|
| Buy seeds | Walk to the **Coral Market** (south-east), press the prompt at the green **Seeds** counter (E / tap). Species you haven't researched yet show as locked. |
| Plant | Pick a seed in the hotbar at the bottom, then click or tap a sand planter on your reef. With a mouse, a ring snaps onto the planter: green fits, red is locked or taken. |
| Harvest | Click fully grown coral (its label says "Ready!"). It goes into your bag. |
| Sell | Press the prompt at the orange **Sell Coral** counter in the Coral Market. Everything in your bag sells. |
| Catch fish | Fish swim around grown coral on your reef: click them before they swim off. Wild fish at the Main Reef's fish nurseries can be caught by anyone. |
| Collect | Swim into shells and pearls lying around the Main Reef. |
| Grow your reef | You start with 20 planters. At the **Research Laboratory**, the Reef tab unlocks the next one (up to 30) for shells and pearls, and researches faster coral growth. |
| Fences and decorations | At the Coral Market's **Decor & Fences** counter buy fence styles and decorations. Press **Place** on a decoration, go home, and tap anywhere inside your fence (not on coral or the gateway). Hold the prompt on a placed one to pick it up. |
| Gear | At the **Equipment Station**: **Bubble Wand** (click a growing coral to speed it up), **Bigger Bag** (your bag holds 30 coral, +30 a level), **Oxygen Tank** (+45 seconds of air a level) and **Swim Fins** (+8% swim speed a level). Coral growth (the old Fertilizer) is research at the Lab. |
| Quests | **Quests** on the left: three daily quests, the same for everyone, new each day (UTC). Claim the reward when one is done; a red "!" shows when one is waiting. |
| Rebirth | In the Quests window. Pay the rebirth cost to start over for +25% shells from coral and fish, forever. You keep pets, the Index, fences, decorations, gear and titles. |
| Titles | Pick one in the Quests window; it shows over your head. Earned from Reef Index sets and from rebirthing. |
| Like a reef | Visit someone's reef and press **F** at the sign over its gate (once a day per reef). The sign shows its likes, and the **Best Reefs** board ranks them. |
| Reef Index | Press **Index** on the left, or use the hologram in the Aquarium. Every coral in every mutation combo, and every fish. |
| Pets | Hatch eggs at the **Pet Hatchery** counter inside the Aquarium, then take pets out from **Pets** on the left. |
| Teleport | **Shop**, **Home** and **Ruins** on the right take you to the Coral Market, your reef or the Sunken Ruins entrance (3 s cooldown). The glowing whirlpool pads beside the Coral Market and at each reef gate do the same; the one at the plaza's north edge goes to the Kelp Forest. |
| Swim | Jump to start swimming: about twice walking speed, in the direction the camera points (tilt it well down or up to dive or rise). Hold jump to swim up; let go of everything to drift down and land. |

The whole map is underwater: deep-blue haze instead of sky, a glowing surface with light shafts
far overhead, kelp forests, coral clusters, starfish and urchins on the seabed, and drifting
specks and diver bubbles near you. Schools of reef fish, sea turtles, jellyfish, a manta ray
and crabs swim around. They are decoration and can't be caught; the fish to catch are the
ones that gather around your own grown coral.

Each counter has a shopkeeper: Coralie behind the Seeds counter, Pinch the crab on the Sell
Coral counter, Captain Mako at the Equipment Station and Dr. Pearl at the Lab; Kai the guide waits
by the spawn. They greet you when you walk up. Their names and lines are in
`ReefConfig.Shopkeepers` (see Characters, below, for the human crew).

## Characters

From the character roster (`1-npc-character.png`).

**Your diving suit.** Every player wears a diving suit over their own avatar (their head, face and
hair stay): black with **blue** accents (Blue Explorer) or **pink** accents (Pink Explorer), with an
oxygen tank, goggles on the forehead, a glowing coral emblem, a harness and belt, and flippers.
Roblox doesn't tell games a player's gender, so each player picks: a window offers both the first
time you play, and Captain Mako at the Equipment Station (press F by him) lets you change it.
The choice is saved. Outfits are parts welded to the limbs and sized to them, so they fit R15
and R6 avatars of any body scale.

**The crew** are real R15 characters with Roblox's default idle, walk and wave animations, run by
a small AI (`Crew.luau`): each stands at their post facing customers, now and then strolls
nearby along a path and back, stops to turn and wave when a player walks up, and hurries back to
the counter whenever someone comes to it. Players walk through them rather than pushing them.

| Character | Role | Where | Look |
|---|---|---|---|
| Coralie | Shopkeeper: coral seeds | Coral Market seed counter | Tan shirt, navy apron with the coral emblem, straw sun hat |
| Kai | Guide NPC: tutorial | By the spawn | Blue polo and cap, khaki shorts, lanyard badge |
| Captain Mako | Master Diver: equipment, diving suits | Equipment Station | Black suit with glowing cyan trim, full helmet with a glowing visor, gold-banded tank |
| Dr. Pearl | Research Scientist: the Lab | Research Laboratory counter | White lab coat over navy, glasses, a glowing tablet |
| Marlo | Explorer NPC: Sunken Ruins missions | Ruins entrance | Khaki shirt and shorts, safari hat, binoculars, backpack |

Pinch the crab (selling), Otto the otter (Kelp Forest), Lumi the lanternfish (Abyss) and Marina
the mermaid (a sea event) are still the animal characters.

**Marine life.** Besides the reef fish, turtles, jellyfish and the pufferfish pet, a friendly
cartoon **shark** patrols high over the lagoon and the Main Reef, and a **dolphin pod** of three
porpoises along a loop of its own (`MarineCast.luau`, client only). Both steer smoothly, and now
and then swim over to circle a player who's close before heading back to their route.

**Mesh creatures.** The marine-life catalog (`images/living-sea/catchable-model.png`, reference
only) is being rebuilt as real 3D meshes made with Roblox's AI mesh generator, in the catalog's
priority order. Batch 1 is done: the catchable **Minnow, Striped Tang, Pufferfish and Moonfish**
and the **Seahorse** and **Pufferfish** pets. Each is a few textured MeshParts (asset ids, sizes
and offsets in `CreatureMeshes.luau`), built at server start into
`ReplicatedStorage.CreatureModels` with `AssetService:CreateMeshPartAsync` (`CreatureModels.luau`),
then cloned by the fish, the pets, the Reef Index and the aquarium (`Creatures.luau`). On each
client, `CreatureAnimator.luau` swims every one near the camera: the body sways, and tails and
fins swing from their hinges when the generator split them out cleanly. Golden pets are gold foil.
Anything still loading, or a creature whose meshes fail, keeps its old Part-built look.

Batch 2 adds the **Octopus** pet (all three pets are meshes now) and the animal shopkeepers:
**Pinch** the crab, **Otto** the sea-otter ranger and **Lumi** the lanternfish. Shopkeepers are
built with the world, before the templates load, so `ShopkeeperVisuals.start` swaps each one's
Part-built body for its mesh once they're ready. The swap keeps the model and its Root, adds an
invisible Head for speech bubbles and re-tags the keeper so clients pick it up again. Lumi's lure
carries a light. Tentacles and the otter's arms use the `dangle` role, swaying from their tops.

Batch 3 is the event characters. **Marina** the mermaid floats behind her shell stall (the counter,
canopy and jars are unchanged). The Shipwreck **orcas** are chubby, toy-like meshes, still moved by
their server-owned AlignPosition/AlignOrientation. The Whale Pass **humpback** crosses overhead and
casts a shadow. The **Giant Octopus** is the octopus pet mesh at 22 studs tall. Its head is named
`Body` and its Root pivots at the hover point, so `GiantOctopus.luau` (taps, ink bursts, drop and
bob) works unchanged. Whales and orcas use the `whale` style and the `fluke` role: they roll and
beat their tails up and down instead of wiggling sideways. A negative `Pace` gives the whale and
the Giant Octopus a slow, heavy beat.

Batch 4 is the Sunken Ruins' rare creatures. `RuinsLife.luau` builds the **Coelacanth**,
**Anglerfish**, **Leafy Sea Dragon** and **Giant Squid** from Parts as before. Once the templates
are ready it swaps each one for its mesh, which then follows the same server-timed path, so
sightings still match. The anglerfish keeps its glowing lure, and the sea dragon's fronds sway. The
generator made the squid chubby and upright (one big mantle piece), so it turns only left and
right as it rises out of the Wreck Basin, with its arms and tentacles dangling.

Batch 5 is the Abyss. `AbyssLife.luau` swaps the **Ghost Shark**, **Vampire Squid**, **Gulper Eel**
and **Dumbo Octopus** for their meshes the same way. The pit is dark, so each mesh gets a soft
light in its own colour, like the neon eyes and tips the Part-built ones had: pale blue for the
shark, cyan for the squid, pink at the eel's tail and on the octopus. The vampire squid and the
octopus are upright and only turn left and right; the octopus's ear fins flap. The generator
coiled the gulper eel up under its big head instead of making it long.

Batch 6 is the Kelp Forest's catchable fish: **Garibaldi, Kelp Bass, Opaleye, Sheephead** and the
rare **Giant Sea Bass** (4.5 studs). They're ordinary fish kinds with a `creature` field in
`ReefConfig.Fish.kinds`, so the wild fish, the Reef Index and the aquarium all show the meshes.

Batch 7, the last, is the background sea life. On the Main Reef (`SeaLife`) the six school
species (**Clownfish, Blue Tang, Yellow Tang, Angelfish, Sardine, Wrasse**), the **Sea Turtles**,
**Jellyfish** and **Manta Rays** get their own meshes, and the crabs reuse Pinch's crab mesh at
crab size, standing on the seabed. In the Kelp Forest (`KelpLife`) the turtles and hatchlings
use the sea turtle mesh, and the dark fish schools are Kelp Bass meshes drawn as silhouettes.
All of them are built from Parts first and swap to their meshes once the templates are ready
(`Creatures.onReady`), so the Parts stay as the fallback. Every jellyfish uses the same pink
mesh; its light still comes in four colours. The manta took three tries: the first two came
out as chubby blobs. The one used was generated facing backwards, so creature definitions can
now say `turn = 180`. Its wing pieces sit on top of its flat body, so it glides on the gentle
whale roll without flapping.

Checked in Studio (2026-11-24): all five templates build at their game sizes with no errors. New
wild fish spawn as meshes, their pieces stay attached while they swim, and they keep their click
detector. The seahorse and golden pufferfish pets follow the player as meshes, and fins and tails
animate near the camera. Studio's screenshots weren't drawing 3D during this test, so how the
models look (and which way the tang, pufferfish and moonfish face) still needs checking by eye.
Batch 2 (same day): all nine templates build. Pinch, Otto and Lumi swap to their meshes and the
human crew are left alone. Pinch's claws animate while he bobs and turns, and he greets a player
walking up with the bubble on his new Head. The octopus pets (plain and golden) follow as meshes
with rippling tentacles.
Batch 3 (same day): all twelve templates build. The Giant Octopus, Marina's stall and an orca were
built with the real builders in Play. The octopus pivots at its hover point with all five pieces
tappable. The orca glides to its goal under its movers. The Whale Pass whale swims its path facing
forward. All four animate near the camera.
Batch 4 (same day): all sixteen templates build. The coelacanth, anglerfish and sea dragon swap
to their meshes in the Ruins, face along their paths, have no leftover Parts and the lure glows.
In a later Play test the squid rose out of the Wreck Basin on time as its mesh: upright, all five
pieces animating, no Parts left behind.
Batch 5 (same day): all twenty templates build. The four Abyss creatures swap to their meshes,
face along their paths, keep their lights, stay level where upright, and the octopus's ears
and arms animate near the camera.
Batch 6 (same day): all twenty-five templates build, and wild Kelp Forest fish spawn as meshes
with their click detectors.
Batch 7 (same day): all thirty-four templates build. Every Main Reef school fish, turtle,
jellyfish, manta and crab, and all 31 Kelp Forest turtles and fish, swap to their meshes, with no
Parts left behind. Their pieces animate near the camera, travelling creatures face along their
paths (crabs scuttle sideways), and the jellyfish keep their lights. The client held 60 fps with
21 mesh creatures animating around the camera.

**Checked in Studio** (solo Play through the Studio MCP server, on 2026-11-24): all five crew
spawn at their posts, dressed and playing their idle animations; Dr. Pearl, Captain Mako and
Marlo stroll 5 to 13 studs out (walk animation) and back, and Coralie stays at her counter while a
player is there. Talking to Kai still gives the first seeds, shows his line in a bubble over his
head and finishes tutorial step 1. The suit picker opens on a first visit; Pink and Blue each put
the suit on (35 pieces, the avatar's own shirt and pants removed), switching replaces the old one,
an unknown suit id is ignored, Captain Mako's F prompt reopens the picker, and the suit comes back
after a respawn. The shark and the three dolphins swim at their cruising speeds, the dolphins in
formation. Not yet checked: the shark and dolphins coming over to circle a player, the suits on R6
avatars and on phones, and pathfinding round the larger hub buildings over a long session.

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
| Shipwreck (5%) | 55 s | A liner sinks into the Wreck Basin in the **Sunken Ruins** (press **Ruins** to get there fast). 20 s after it starts, six orcas arrive and hunt for 30 s. They are faster than swimming, so swim inside the wreck (through the holes in its sides or the deck hatches) and stay there. Anyone caught is eaten and respawns at home. Everyone who was there when the orcas came and wasn't eaten gets a **Seagrass** seed. The HUD says whether you are hidden. |

### Reef Index

The **Index** button opens a collection book of every seed in all 22 mutation combinations
and every fish, 202 entries in all. Entries you haven't found are black silhouettes. Harvesting
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
| Ghost Coral (Mythic) | not sold | 15 min | 9,000 | Sunken Ruins cave cuttings and chests |
| Relic Coral (Ancient) | not sold | 30 min | 45,000 | Sunken Ruins sanctum cuttings and missions |
| Glowcap (Abyssal) | 45,000 | 25 min | 120,000 | Lumi's stall in the Abyss |
| Lumen Brain (Abyssal) | 180,000 | 40 min | 480,000 | Lumi's stall in the Abyss |
| Void Bloom (Abyssal) | 750,000 | 1 h | 2,000,000 | Lumi's stall in the Abyss |

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

### Music and sound

Every sound comes from the Roblox Creator Store's licensed libraries (APM Music and Pro Sound
Effects), so they are free to use in any experience. The ids are all in `src/shared/ReefSounds.luau`;
swap one there to change it.

- **Music:** two calm underwater tracks play in turn. The Volcano Vent, Giant Octopus and Shipwreck
  have their own tense music, and when the orcas arrive it switches to chase music. A **Music**
  button at the top right turns the music off and on (sound effects stay).
- **Ambience:** a soft underwater loop under everything.
- **Effects:** planting, harvesting, selling, buying, hatching, placing decorations, upgrades,
  rewards, rebirths, teleports, starting a swim, every sea event starting, octopus hits, treasure
  clues, and lava rocks and the treasure chest heard where they land.

### Store (Robux)

The gold **Store** button (right side, under Music) opens the Store. These items exist on Roblox for
this game; their ids and the shown prices are in `ReefConfig.Store`. Change a price on the Creator
Dashboard (Monetization) and the Store shows the new one.

| Item | Kind | Price | What it does |
|---|---|---|---|
| 2x Shells | game pass | 349 R$ | Coral and fish sell for double shells (stacks with rebirths). |
| VIP Bag | game pass | 149 R$ | +100 bag space. |
| Speed Fins | game pass | 99 R$ | Swim 50% faster. |
| VIP Royal Fence | game pass | 199 R$ | The gold-and-pearl Royal Pearl fence and the VIP title. |
| Instant Grow | product | 49 R$ | Every coral growing on your reef finishes now. |
| Personal Restock | product | 25 R$ | Every seed fully stocked, just for you, for 5 minutes. |
| Shell Pouch | product | 49 R$ | 25,000 shells. |
| Shell Chest | product | 299 R$ | 250,000 shells. |
| Starter Pack | product | 99 R$ | Golden Seahorse, 5 Glow Anemone and 2 Pearl Clam seeds, 20,000 shells. Shown only in a player's first 3 days, until bought. |
| Gift: Shell Chest | product | 299 R$ | 250,000 shells for a friend in the server. |
| Gift: 2x Shells | product | 349 R$ | The 2x Shells pass for a friend, forever. |
| Gift: VIP Bag | product | 149 R$ | The VIP Bag pass for a friend, forever. |

Gifts: pressing **Gift** asks who it's for (anyone else in the server; people who already have
that pass are greyed out), then opens the purchase. The friend gets it if they're still in the
server; if they left, the buyer gets it instead. A gifted pass the friend already has turns
into 250,000 shells. Gifted passes are saved in `giftedPasses` and count just like bought ones.

`Monetization.luau` is the only purchase handler: passes are checked with Roblox on join and after
a purchase; each product receipt is recorded with its grant and saved before Roblox is told it
was granted, so a repeated receipt never pays twice. The game's owner owns every pass, so in
Studio the Store shows them as Owned; test product purchases in Studio are free. The icons are
in `store-icons/`.

### Rewards and friends

Under the Store button are **Rewards** and **Friends**. Everything here is decided on the server
(`Rewards.luau`, `Social.luau`) and recorded in the save, so each reward is given once. The
numbers are in `ReefConfig.Rewards`.

- **Daily streak:** one reward a day (UTC) on joining, or at midnight while playing. Days 1 to 7:
  500 shells, 1,000, 2 Glow Anemone seeds, 2,500, 1 Pearl Clam seed, 5,000, then 10,000 plus a
  Starlight Coral seed; then it starts again at day 1. Missing one day keeps the streak.
- **Offline earnings:** 1 shell a minute for each unlocked planter while you're away (at least
  5 minutes, at most 8 hours), times your sale bonus. Coral keeps growing too. A "Welcome back!"
  popup shows what you earned, your daily reward and how much coral is ready.
- **Shell boost:** +10% on sales for Roblox Premium members, and +10% for each friend in the
  same server (up to +50%). It stacks with rebirths and 2x Shells.
- **Invite friends:** the Invite button opens Roblox's invite prompt. A friend who joins from it
  for the first time gets 2,000 shells; once they've stayed 5 minutes, you get 5,000 (in any
  server, within about 5 minutes). 3 friends gives the Reef Ambassador title.
- **Codes:** players type a code in the Rewards window. The codes are in `Rewards.luau` (on the
  server, so nobody can read them from the game): `REEFLAUNCH` (5,000 shells), `BUBBLES`
  (2 Glow Anemone seeds), `SEAHORSE` (2,500 shells and a Pearl Clam seed). Add one there, with
  an optional `expires` time, and publish.
- **Group:** set `ReefConfig.Rewards.group.id` to the game's Roblox group id and publish. Members
  then get 5,000 shells and the Reef Crew title once. While it's 0 the section is hidden.
- **Notifications:** the Notify me button asks Roblox to let the game send this player
  notifications. Sending them needs a notification string made on the Creator Dashboard
  (Engagement → Notifications) and the Open Cloud user-notifications API with an API key.
- **Weekly board:** the top 10 by shells earned since Monday 00:00 UTC (in the Rewards window).
  Last week's top 10 get prizes the next time they play: 100,000 shells and the Weekly Champion
  title for 1st, 50,000 for 2nd, 25,000 for 3rd, 10,000 for 4th to 10th.
- **Visiting and watering:** Friends lists everyone in the server with **Visit** (whirl to their
  reef) and **Trade**. At another player's gate sign, **Water reef** (F) makes their growing coral
  jump 60 seconds ahead and gives you 200 shells. You can water each reef once a day and 10
  reefs a day; a reef takes 30 waterings a day at most.
- **Trading:** seeds and pets, with someone in the same server. Asking someone who has asked you
  opens the trade. Both put in offers, both Accept (any change clears both), then both
  Confirm. The server checks both saves again and swaps everything in one step; leaving cancels
  it. Trading is only for accounts whose Roblox policy allows trading paid items.

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
  RuinsConfig.luau          the Sunken Ruins: layout, chests, hidden coral, relics, creature
                            paths, missions, and the saved state's repair
  AbyssConfig.luau          the Abyss: layout, unlock rules, the darkness, Lumi's seeds,
                            deep-sea creature paths, and the saved state's repair
  CoralVisuals.luau         coral models made from Parts, plus mutation effects (server and Index)
  FenceVisuals.luau         reef fences made from Parts: planks, hedge, wall, ribs or crystal
  DecorVisuals.luau         the reef decorations made from Parts
  ReefSounds.luau           every sound id: music, ambience and effects
  CreatureMeshes.luau       the mesh creatures' asset ids, piece sizes, offsets and swim roles
  Creatures.luau            cloning, scaling, gilding and swimming the mesh creatures
  EconomyMath.luau          copied unchanged from skills/other-engines/roblox-simulator-economy
src/server/                 -> ServerScriptService.Server
  Main.server.luau          starts everything in order
  WorldKit.luau             shared building blocks: parts, boulders, coral, lamps, labels, paths
  MainReef.luau             the Main Reef's scenery: road, coral trees, bridges, nurseries,
                            ridges, caves, Grand Reef Rock; picks the shell and pearl spots
  Collectibles.luau         the shells and pearls to pick up in the Main Reef
  KelpWorld.luau            builds the Kelp Forest: giant kelp, trail, glades, habitats, meadows
  Kelp.luau                 the Kelp Forest: meadows, nests, places found, Otto's challenges
  Hub.luau                  the hub's four buildings and their glass corridors
  Research.luau             species research at the Lab (ResearchSpecies)
  Oxygen.luau               air in deep water: drains, refills, whisks you home when it runs out
  World.luau                builds the Starter Lagoon: seabed, lighting, surface, plaza and
                            spawn, the guide rock, Research Station, Upgrade Station, Coral Shop, Ocean
                            Gate, paths and leaderboards, then the 6 reefs and their planters
                            in the Main Reef
  Tutorial.luau             the Starter Lagoon tutorial steps, Kai's lines and the reward
  Crew.luau                 the human crew: R15 NPCs at their posts, with a wander, greet and
                            serve AI (pathfinding, default animations)
  Outfits.luau              the character outfits built from parts welded to the limbs: the
                            players' Blue and Pink Explorer suits and the crew's clothes
  Suits.luau                players' diving suits: choosing (ChooseSuit), saving, dressing
                            on spawn, and the picker's previews
  CreatureModels.luau       builds the mesh creature templates at server start
  SeabedDecor.luau          kelp forests, coral clusters, starfish and urchins
  PlayerData.luau           DataStore load/save with a session lock, data repair, leaderstats
  Plots.luau                plot assignment, free planting (PlantAt), growth, harvesting
  ReefIndex.luau            Reef Index finds, set rewards and IndexRewards (titles, fences, pets)
  Supplies.luau             Upgrade Station: fences, decorations, gear upgrades, Fertilizer
  Quests.luau               daily quests: progress and claiming
  Likes.luau                reef likes at each gate sign
  Monetization.luau         Robux passes and products: the only ProcessReceipt, gifts, Starter Pack
  Rewards.luau              daily streak, offline earnings, Premium/friend boost, codes, group,
                            referrals, the weekly board and its prizes
  Social.luau               visiting reefs, watering them, and trading
  Rebirth.luau              rebirths and picking a title
  Pets.luau                 eggs, taking pets out, releasing, and the pet perks
  Teleport.luau             Shop/Home teleports, the whirlpool pads and their bubble effect
  Admin.luau                admin checks, event control, announcements, gifts
  ShopkeeperVisuals.luau    the animal shopkeeper models made from Parts, tagged "Shopkeeper"
                            (the human crew's kinds get an empty placeholder)
  Shop.luau                 shared stock, buying, expanding, seed selection, selling
  Fish.luau                 fish spawning, swimming and catching
  Events.luau               sea event scheduler: timer, banner, night lighting, whale growth boost
  EventState.luau           the running event's modifiers, read by Plots and Fish
  Currents.luau             ocean current mutation spreading
  TreasureStorm.luau        treasure chests: dropping, opening, rewards
  Shipwreck.luau            the Shipwreck event: sinking, the orca hunt, eating, rewards
  ShipwreckVisuals.luau     the wreck and orca models made from Parts
  RuinsWorld.luau           builds the Sunken Ruins: terrace and temple, mermaid statue, pirate
                            ship, cave, coral garden, Wreck Basin, Marlo, and the chests, relics
                            and hidden coral
  Ruins.luau                the ruins' gameplay: chests, relics, cuttings, sightings, missions
  AbyssWorld.luau           builds the Abyss: road, shelf, Pressure Gate, ramp, pit, glowing
                            coral, mushrooms, crystals, the Crystal Spire, Lumi's stall
  Abyss.luau                the Abyss's gameplay: unlocking, turning locked players back,
                            Lumi's sales (BuyAbyssSeed), deep-sea creature sightings
  Volcano.luau              the Volcano Vent event: the volcano and its lava rocks
  GiantOctopus.luau         the Giant Octopus event: hits, health and prizes
  Merchant.luau             the Mermaid Merchant event: Marina's stall and offers (BuyMerchant)
  TreasureHunt.luau         the Sunken Treasure Hunt event: burying, clues, heat, digging
  EventVisuals.luau         the volcano, lava rock, octopus, mermaid stall and dig spot models (and their sounds)
  Leaderboard.luau          global "Top Reefs" (shells earned) and "Best Reefs" (likes) boards
  RateLimit.luau            per-player token bucket for every request
src/client/                 -> StarterPlayer.StarterPlayerScripts.Client
  Main.client.luau          connects remotes and UI
  OceanEffects.luau         marine snow around the camera, bubbles from divers
  CoralLabels.luau          name and growth countdown over each coral
  Hud.luau                  shells, bag, sea-event timer, toasts, seed hotbar, side and Shop/Home/Ruins buttons
  SuppliesPanel.luau        the Upgrade Station window (Reef, Gear, Fences, Decor)
  MerchantPanel.luau        Marina the Mermaid Merchant's trade window
  Audio.luau                music, ambience and sound effects (and the Music button)
  TutorialPanel.luau        the Starter Lagoon tutorial card, beam and marker
  RuinsPanel.luau           the Explorer's Journal, the ruins mission card, and each player's
                            own view of chests, relics and cut coral
  RuinsLife.luau            the ruins' rare creatures on their shared paths (client only)
  AbyssLife.luau            the Abyss's darkness, glowing jellyfish and deep-sea creatures
                            (client only)
  AbyssPanel.luau           Lumi's Deep Seeds window
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
  Shopkeepers.luau          shopkeeper idle animation, turning and greetings (client only;
                            the crew walk on their own, so they only get the greetings)
  SuitPicker.luau           the Choose your diving suit window, with 3D previews
  MarineCast.luau           the shark and the dolphin pod, with their steering AI (client only)
  CreatureAnimator.luau     swims the mesh creatures near the camera (client only)
  StorePanel.luau           the Store window: passes, products, Starter Pack, gifts
  RewardsPanel.luau         the Rewards window and the welcome-back popup
  SocialPanel.luau          the Friends window: players here, Visit, trade requests and trading
  MenuButtons.luau          the Store / Rewards / Friends buttons under Music
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

**Sunken Ruins, checked in Studio** (solo Play through the Studio MCP server, on 2026-11-24):
the zone builds (about 3,900 parts, 17 interactive spots) with no errors; the Ruins button lands
on the entrance pad; opening the gate chest, picking up the Ship's Bell (it disappears for that
player), entering the cave, taking a Ghost Coral cutting (it arrives in the hotbar), spotting
the Anglerfish and boarding the pirate ship each finished their mission in order and paid out;
the Journal shows missions, relics, creatures and timers; and a forced Shipwreck landed in the
Wreck Basin, where a player hidden in the hull survived the orcas and got the Seagrass seed.
Not yet checked: the Giant Squid's visit, the Relic Coral cutting after all six relics, chests
refilling after 20 minutes, and the mission card (it only shows once the tutorial is done).

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
