--!nonstrict
-- Every tunable number in Grow a Reef. Server and client both read this module,
-- but only the server ever decides an amount from it.

export type SeedDef = {
	id: string,
	name: string,
	price: number,
	growSeconds: number,
	sellValue: number,
	color: Color3,
	stockChance: number, -- chance this seed appears at each restock
	stockMin: number,
	stockMax: number,
	shop: boolean?, -- false: never sold in the Seed Shop (event rewards only)
	rarity: string?, -- shown for special seeds, e.g. "Transcendent"
}

export type MutationDef = {
	id: string,
	weight: number, -- natural roll weight at planting time
	multiplier: number, -- sell value multiplier
	color: Color3?,
}

export type FishDef = {
	id: string,
	weight: number,
	multiplier: number,
	color: Color3,
}

export type ShopkeeperDef = {
	name: string,
	bob: number, -- idle bob height in studs
	greetings: { string },
}

local ReefConfig = {}

ReefConfig.DATA_VERSION = 3 -- 3: stacked mutations, Reef Index, pets; 2: free planting; 1: tile grid
ReefConfig.STARTING_SHELLS = 40
ReefConfig.STARTING_SEEDS = { kelp = 3 } :: { [string]: number }
ReefConfig.MAX_SEEDS_PER_TYPE = 999

-- Plot layout. Coral is planted anywhere inside the plot's round reef bed; each coral
-- uses one slot, and every slot bought also widens the bed.
ReefConfig.STARTING_SLOTS = 10
ReefConfig.MAX_SLOTS = 50
ReefConfig.BED_RADIUS = 37 -- studs, with the starting slots
ReefConfig.BED_RADIUS_PER_SLOT = 0.425 -- extra radius for each slot bought (54 at 50 slots)
ReefConfig.PLANT_SPACING = 5 -- minimum studs between two corals
ReefConfig.PLANT_EDGE = 1.5 -- keep coral this far inside the bed's edge
ReefConfig.PLANT_REACH = 60 -- how far from your character you can plant
ReefConfig.PLOT_COUNT = 6 -- one plot per player; set the place's max players to 6
ReefConfig.PLOT_SPACING = 126 -- studs between plot centres, along X
ReefConfig.PLOT_ROW_Z = 85 -- the plots' row, behind the stands

-- Growing the reef: price of the n-th extra slot = floor(baseCost * costGrowth ^ n)
ReefConfig.EXPAND = { baseCost = 200, costGrowth = 1.2 }

export type FenceDef = {
	id: string,
	name: string,
	postColor: Color3,
	plankColors: { Color3 },
	material: string,
	height: number,
	postSpacing: number,
	rails: number,
	brokenChance: number,
	rope: boolean,
	barnacles: boolean,
}

-- Teleporting between the shops and your reef, from the HUD's Shop and Home buttons or the
-- whirlpool pads (one by the stands, one in front of every reef's gate).
ReefConfig.Teleport = {
	cooldown = 3, -- seconds between teleports
	shopsPad = Vector3.new(0, 0, 4), -- the plaza pad in front of the stands
}

-- Swimming: jumping pushes off into a swim, which is faster than walking (16 studs/s).
ReefConfig.Swim = {
	speed = 34, -- studs per second, in the direction the camera points
	rise = 20, -- extra upward speed while jump is held
	sink = 5, -- how fast you drift down when not moving
	maxHeight = 80, -- swim no higher than this, well below the water surface
}

-- Fences around each reef, with a gap at the front to walk in. Only the first style exists
-- so far; more go in this list. Materials are Enum.Material names.
ReefConfig.Fences = {
	{
		id = "shipwood",
		name = "Shipwreck Wood",
		-- Salvaged hull planks, sun-bleached, tarred or green with weed. Brighter than they
		-- look: the underwater tint darkens wood a lot.
		postColor = Color3.fromRGB(110, 84, 62),
		plankColors = {
			Color3.fromRGB(176, 136, 96),
			Color3.fromRGB(150, 116, 84),
			Color3.fromRGB(190, 170, 136),
			Color3.fromRGB(128, 138, 106),
			Color3.fromRGB(100, 80, 64),
		},
		material = "WoodPlanks",
		height = 4,
		postSpacing = 7,
		rails = 3,
		brokenChance = 0.1, -- a plank snapped and hanging off one post
		rope = true, -- rope lashings on some posts
		barnacles = true,
	},
}
ReefConfig.DEFAULT_FENCE = "shipwood"
ReefConfig.FENCE_GATE_WIDTH = 12 -- studs, the opening at the front
ReefConfig.FenceById = {} :: { [string]: FenceDef }
for _, fence in ReefConfig.Fences do
	ReefConfig.FenceById[fence.id] = fence
end

ReefConfig.SEED_ORDER = { "kelp", "brain", "fan", "anemone", "clam", "star", "seagrass" }

ReefConfig.Seeds = {
	kelp = {
		id = "kelp", name = "Bubble Kelp", price = 10, growSeconds = 20, sellValue = 18,
		color = Color3.fromRGB(86, 196, 92), stockChance = 1, stockMin = 8, stockMax = 15,
	},
	brain = {
		id = "brain", name = "Brain Coral", price = 40, growSeconds = 60, sellValue = 75,
		color = Color3.fromRGB(240, 128, 160), stockChance = 0.9, stockMin = 4, stockMax = 8,
	},
	fan = {
		id = "fan", name = "Sea Fan", price = 150, growSeconds = 150, sellValue = 300,
		color = Color3.fromRGB(150, 90, 220), stockChance = 0.6, stockMin = 2, stockMax = 5,
	},
	anemone = {
		id = "anemone", name = "Glow Anemone", price = 600, growSeconds = 300, sellValue = 1300,
		color = Color3.fromRGB(70, 230, 230), stockChance = 0.4, stockMin = 1, stockMax = 3,
	},
	clam = {
		id = "clam", name = "Pearl Clam", price = 2500, growSeconds = 600, sellValue = 6000,
		color = Color3.fromRGB(235, 235, 245), stockChance = 0.2, stockMin = 1, stockMax = 2,
	},
	star = {
		id = "star", name = "Starlight Coral", price = 12000, growSeconds = 1200, sellValue = 32000,
		color = Color3.fromRGB(255, 220, 80), stockChance = 0.07, stockMin = 1, stockMax = 1,
	},
	-- Transcendent: only from surviving the Shipwreck event's orca hunt. Never in the shop.
	seagrass = {
		id = "seagrass", name = "Seagrass", price = 0, growSeconds = 1800, sellValue = 150000,
		color = Color3.fromRGB(110, 240, 210), stockChance = 0, stockMin = 0, stockMax = 0,
		shop = false, rarity = "Transcendent",
	},
} :: { [string]: SeedDef }

-- A coral can hold up to MAX_MUTATIONS mutations at once, and their multipliers multiply
-- ("Glowing + Golden" sells at x10). One is rolled from this table when a seed is planted;
-- sea events and currents add more later.
ReefConfig.MAX_MUTATIONS = 2
ReefConfig.Mutations = {
	{ id = "None", weight = 900, multiplier = 1 },
	{ id = "Glowing", weight = 75, multiplier = 2, color = Color3.fromRGB(120, 255, 200) },
	{ id = "Golden", weight = 22, multiplier = 5, color = Color3.fromRGB(255, 196, 40) },
	{ id = "Prismatic", weight = 3, multiplier = 15, color = Color3.fromRGB(255, 120, 255) },
} :: { MutationDef }

-- Never rolled at planting; only sea events give these (Cold Current, Bioluminescent Night).
ReefConfig.EventMutations = {
	{ id = "Frosted", weight = 0, multiplier = 3, color = Color3.fromRGB(175, 230, 255) },
	{ id = "Shadow", weight = 0, multiplier = 4, color = Color3.fromRGB(110, 60, 180) },
} :: { MutationDef }

ReefConfig.MutationById = {} :: { [string]: MutationDef }
ReefConfig.MUTATION_ORDER = {} :: { string } -- every real mutation, in display order
for _, list in { ReefConfig.Mutations, ReefConfig.EventMutations } do
	for _, mutation in list do
		ReefConfig.MutationById[mutation.id] = mutation
		if mutation.id ~= "None" then
			table.insert(ReefConfig.MUTATION_ORDER, mutation.id)
		end
	end
end

ReefConfig.RESTOCK_SECONDS = 300

-- Ocean currents (one of the sea events below) flow from plot i to plot i + 1 (the last
-- plot wraps to the first).
ReefConfig.Current = {
	tick = 8, -- seconds between spread attempts while it flows
	spreadChance = 0.35, -- chance per tick, per plot, that one mutation drifts downstream
}

export type EventDef = {
	id: string,
	name: string,
	weight: number, -- how often it is picked, against the other events
	duration: number, -- seconds
	color: Color3, -- HUD timer colour while it runs
	message: string, -- announced to everyone when it starts
}

-- Sea events: one at a time, picked at random (never the same twice in a row).
ReefConfig.Events = {
	interval = 180, -- seconds from the end of one event to the start of the next
	list = {
		{
			id = "Current", name = "Ocean Current", weight = 20, duration = 40,
			color = Color3.fromRGB(110, 200, 255),
			message = "An ocean current is flowing! Mutations can drift between reefs.",
		},
		{
			id = "Cold", name = "Cold Current", weight = 15, duration = 45,
			color = Color3.fromRGB(175, 230, 255),
			message = "A cold current is flowing! Grown coral can turn Frosted (x3).",
		},
		{
			id = "Night", name = "Bioluminescent Night", weight = 20, duration = 75,
			color = Color3.fromRGB(120, 255, 220),
			message = "Bioluminescent Night! Glowing is 3x as likely when you plant, and grown coral can turn Shadow (x4).",
		},
		{
			id = "Frenzy", name = "Feeding Frenzy", weight = 20, duration = 60,
			color = Color3.fromRGB(255, 170, 90),
			message = "Feeding Frenzy! Fish come to your coral twice as fast.",
		},
		{
			id = "Treasure", name = "Treasure Storm", weight = 10, duration = 40,
			color = Color3.fromRGB(255, 205, 80),
			message = "Treasure Storm! Chests are sinking from the surface. Open them for shells and seeds!",
		},
		{
			id = "Whale", name = "Whale Pass", weight = 10, duration = 50,
			color = Color3.fromRGB(150, 190, 255),
			message = "A giant whale is passing overhead! Coral grows twice as fast while it's here.",
		},
		{
			-- 20 s to hide, a 30 s hunt, 5 s for the orcas to leave (see Shipwreck below).
			id = "Shipwreck", name = "Shipwreck", weight = 5, duration = 55,
			color = Color3.fromRGB(255, 110, 100),
			message = "A giant ship is sinking, and orcas are following it! Swim inside the wreck and hide before they arrive!",
		},
	} :: { EventDef },
	glowingMultiplier = 3, -- Bioluminescent Night: Glowing mutation weight x this
	fishSpawnMultiplier = 2, -- Feeding Frenzy: fish spawn clock runs this much faster
	growthMultiplier = 2, -- Whale Pass: coral grows this much faster
	mutationTick = 6, -- seconds between event mutation rolls (Cold Current, Night)
	frostChance = 0.1, -- Cold Current: chance per roll that a grown coral turns Frosted
	shadowChance = 0.05, -- Bioluminescent Night: chance per roll that a grown coral turns Shadow
	treasure = {
		every = 3, -- seconds between chests during a storm
		lifetime = 45, -- seconds before an unopened chest washes away
		maxChests = 12,
		shells = { min = 30, max = 200 },
		seedChance = 0.35, -- otherwise the chest holds shells
		seeds = {
			{ id = "brain", weight = 40, count = 2 },
			{ id = "fan", weight = 30, count = 1 },
			{ id = "anemone", weight = 18, count = 1 },
			{ id = "clam", weight = 9, count = 1 },
			{ id = "star", weight = 3, count = 1 },
		},
	},
}

ReefConfig.EventById = {} :: { [string]: EventDef }
for _, event in ReefConfig.Events.list do
	ReefConfig.EventById[event.id] = event
end

-- The Shipwreck event: a liner sinks onto the seabed in front of the stands, then a pod of
-- orcas hunts everyone who isn't hiding inside it. Everyone who was there when the hunt
-- began and didn't get eaten wins the reward seed.
ReefConfig.Shipwreck = {
	landing = Vector3.new(0, 0, -88), -- where the wreck comes to rest, on open seabed
	length = 120, -- the hull, which you can swim into through its holes and hatches
	width = 22,
	height = 18,
	sinkSeconds = 9,
	huntStartsAt = 20, -- seconds into the event when the orcas arrive
	huntSeconds = 30, -- then 5 more seconds for them to swim off
	orcas = 6,
	orcaSpeed = 40, -- studs/s, faster than swimming: hiding is the way to survive
	catchRadius = 8,
	reward = { seed = "seagrass", count = 1 },
}

-- Whether a point is inside the wreck's hull, where the orcas can't reach. shipCFrame is
-- the middle of the hull at keel level.
function ReefConfig.insideShipwreck(shipCFrame: CFrame, point: Vector3): boolean
	local s = ReefConfig.Shipwreck
	local p = shipCFrame:PointToObjectSpace(point)
	return math.abs(p.X) < s.length / 2 - 1.5 and p.Y > 0 and p.Y < s.height and math.abs(p.Z) < s.width / 2 - 1
end

-- Fully grown coral attracts fish that the plot owner can click to catch.
ReefConfig.Fish = {
	spawnInterval = 20,
	spawnChance = 0.3, -- per ready coral, per interval
	maxPerPlot = 4,
	lifetime = 45,
	valueFraction = 0.2, -- fish value = coral sellValue * valueFraction * fish multiplier
	kinds = {
		{ id = "Minnow", weight = 60, multiplier = 1, color = Color3.fromRGB(180, 200, 220) },
		{ id = "Striped Tang", weight = 28, multiplier = 2, color = Color3.fromRGB(60, 120, 255) },
		{ id = "Pufferfish", weight = 10, multiplier = 4, color = Color3.fromRGB(240, 200, 90) },
		{ id = "Moonfish", weight = 2, multiplier = 10, color = Color3.fromRGB(230, 230, 255) },
	} :: { FishDef },
}

ReefConfig.SAVE_INTERVAL = 90
ReefConfig.LEADERBOARD_REFRESH = 60
ReefConfig.INTERACT_DISTANCE = 20 -- studs from a shop or sell stand

-- Cosmetic shopkeepers, keyed by the stand's prompt Kind. The server builds them
-- (ShopkeeperVisuals); each client animates them and shows a greeting on approach.
ReefConfig.SHOPKEEPER_TAG = "Shopkeeper"
ReefConfig.SHOPKEEPER_GREET_DISTANCE = 22 -- studs
ReefConfig.SHOPKEEPER_GREET_COOLDOWN = 20 -- seconds before the same shopkeeper greets again
ReefConfig.Shopkeepers = {
	SeedShop = {
		name = "Captain Coralie",
		bob = 0.25,
		greetings = {
			"Welcome, diver! Fresh seeds, straight from the deep.",
			"New here? Bubble Kelp grows in 20 seconds.",
			"Rare seeds sell out fast. Come back after a restock!",
			"Short on space? I can grow your reef bigger.",
		},
	},
	Sell = {
		name = "Pinch",
		bob = 0.12,
		greetings = {
			"Got coral? I'll take the whole bag!",
			"Glowing, Golden, Prismatic... mutated coral pays more!",
			"Fresh from the reef? Hand it over, I pay in shells.",
			"Snip snip! Best prices on the seabed.",
		},
	},
} :: { [string]: ShopkeeperDef }

ReefConfig.CORAL_TAG = "Coral" -- every planted coral model, for the client's labels and preview

-- Ambient sea life (client-side and cosmetic) and where it, and the seabed decoration, roam.
ReefConfig.SeaLife = {
	area = { minX = -440, maxX = 440, minZ = -110, maxZ = 230 },
	fishSchools = 10, -- each school is one species
	fishPerSchool = 9,
	turtles = 3,
	jellyfish = 14,
	mantas = 2,
	crabs = 14,
}

function ReefConfig.expandCost(unlocked: number): number
	local extra = unlocked - ReefConfig.STARTING_SLOTS
	return math.floor(ReefConfig.EXPAND.baseCost * ReefConfig.EXPAND.costGrowth ^ extra)
end

function ReefConfig.bedRadius(unlocked: number): number
	return ReefConfig.BED_RADIUS + ReefConfig.BED_RADIUS_PER_SLOT * (unlocked - ReefConfig.STARTING_SLOTS)
end

-- Why a coral can't be planted at (x, z) from the plot centre, or nil if it can. Shared so
-- the client's placement preview agrees with the server, which makes the real decision.
function ReefConfig.plantProblem(x: number, z: number, unlocked: number, plants: { [any]: { x: number, z: number } }): string?
	local count = 0
	for _ in plants do
		count += 1
	end
	if count >= unlocked then
		return "Your reef is full. Harvest coral, or grow your reef at the Seed Shop."
	end
	local reach = ReefConfig.bedRadius(unlocked) - ReefConfig.PLANT_EDGE
	if x * x + z * z > reach * reach then
		return "Plant inside your reef bed."
	end
	for _, plant in plants do
		local dx, dz = plant.x - x, plant.z - z
		if dx * dx + dz * dz < ReefConfig.PLANT_SPACING * ReefConfig.PLANT_SPACING then
			return "Too close to another coral."
		end
	end
	return nil
end

-- A coral's mutations are one key: "None", one id ("Golden"), or ids joined with "+" in
-- alphabetical order ("Glowing+Golden"). The bag and the Reef Index use the same key.
function ReefConfig.mutationParts(key: string): { string }
	return if key == "None" then {} else string.split(key, "+")
end

function ReefConfig.mutationKey(parts: { string }): string
	if #parts == 0 then
		return "None"
	end
	local sorted = table.clone(parts)
	table.sort(sorted)
	return table.concat(sorted, "+")
end

-- "None", or 1 to MAX_MUTATIONS different real mutations in alphabetical order.
function ReefConfig.isMutationKey(key: unknown): boolean
	if type(key) ~= "string" then
		return false
	end
	if key == "None" then
		return true
	end
	local parts = string.split(key, "+")
	if #parts > ReefConfig.MAX_MUTATIONS then
		return false
	end
	for i, id in parts do
		if id == "None" or not ReefConfig.MutationById[id] or (i > 1 and parts[i - 1] >= id) then
			return false
		end
	end
	return true
end

-- The key with one more mutation, or nil when it already has it or has no room.
function ReefConfig.withMutation(key: string, mutationId: string): string?
	local parts = ReefConfig.mutationParts(key)
	if not ReefConfig.MutationById[mutationId] or mutationId == "None" or #parts >= ReefConfig.MAX_MUTATIONS then
		return nil
	end
	if table.find(parts, mutationId) then
		return nil
	end
	table.insert(parts, mutationId)
	return ReefConfig.mutationKey(parts)
end

-- Sell multiplier of a key (the mutations' multipliers multiplied), 0 if the key is invalid.
function ReefConfig.mutationMultiplier(key: string): number
	if not ReefConfig.isMutationKey(key) then
		return 0
	end
	local total = 1
	for _, id in ReefConfig.mutationParts(key) do
		total *= ReefConfig.MutationById[id].multiplier
	end
	return total
end

-- "Glowing + Golden Bubble Kelp"; just the seed name with no mutations.
function ReefConfig.displayName(seedId: string, key: string): string
	local seed = ReefConfig.Seeds[seedId]
	local name = if seed then seed.name else seedId
	local parts = ReefConfig.mutationParts(key)
	return if #parts == 0 then name else table.concat(parts, " + ") .. " " .. name
end

function ReefConfig.harvestValue(seedId: string, mutationKey: string): number
	local seed = ReefConfig.Seeds[seedId]
	if not seed then
		return 0
	end
	return math.floor(seed.sellValue * ReefConfig.mutationMultiplier(mutationKey))
end

function ReefConfig.inventoryKey(seedId: string, mutationKey: string): string
	return seedId .. ":" .. mutationKey
end

function ReefConfig.splitInventoryKey(key: string): (string?, string?)
	local seedId, mutationKey = string.match(key, "^(%w+):([%w%+]+)$")
	return seedId, mutationKey
end

-- Every mutation key, in Reef Index order: none, each single mutation, then each pair.
ReefConfig.MUTATION_KEYS = { "None" } :: { string }
for _, id in ReefConfig.MUTATION_ORDER do
	table.insert(ReefConfig.MUTATION_KEYS, id)
end
for i, first in ReefConfig.MUTATION_ORDER do
	for j = i + 1, #ReefConfig.MUTATION_ORDER do
		table.insert(ReefConfig.MUTATION_KEYS, ReefConfig.mutationKey({ first, ReefConfig.MUTATION_ORDER[j] }))
	end
end

export type IndexSet = { id: string, name: string, kind: string, entries: { string }, reward: number }

-- The Reef Index: one set per seed (every mutation key of it) and one set of every fish.
-- Completing a set pays its reward once; badges are optional (create the badge on the
-- Creator Dashboard, then put its id here under the set id, e.g. kelp = 123456).
ReefConfig.Index = {
	setRewardPerSellValue = 10, -- a seed's set pays that seed's sell value x this
	fishSetReward = 1000,
	badges = {} :: { [string]: number },
}
ReefConfig.IndexSets = {} :: { IndexSet }
for _, seedId in ReefConfig.SEED_ORDER do
	local entries = {}
	for _, key in ReefConfig.MUTATION_KEYS do
		table.insert(entries, ReefConfig.inventoryKey(seedId, key))
	end
	local seed = ReefConfig.Seeds[seedId]
	table.insert(ReefConfig.IndexSets, {
		id = seedId,
		name = seed.name,
		kind = "coral",
		entries = entries,
		reward = seed.sellValue * ReefConfig.Index.setRewardPerSellValue,
	})
end
do
	local fishIds = {}
	for _, kind in ReefConfig.Fish.kinds do
		table.insert(fishIds, kind.id)
	end
	table.insert(ReefConfig.IndexSets, { id = "fish", name = "Fish", kind = "fish", entries = fishIds, reward = ReefConfig.Index.fishSetReward })
end

export type PetDef = { id: string, name: string, perk: string, goldenPerk: string, color: Color3 }
export type EggDef = { id: string, name: string, price: number, color: Color3, odds: { { id: string, weight: number } } }

-- Pets hatch from eggs bought with shells at the Pet Hatchery. Golden pets have double
-- perks. Eggs cost shells only; if they are ever sold for Robux, read the paid random
-- items section of skills/other-engines/roblox-simulator-economy first.
ReefConfig.Pets = {
	maxOwned = 24,
	maxEquipped = 2, -- the same kind twice gives no extra perk
	goldenChance = 0.04,
	releaseShells = { normal = 100, golden = 1000 },
	growthBonus = 0.25, -- seahorse: coral grows this much faster (golden: twice this)
	harvestEvery = 60, -- octopus: seconds between harvests (golden: half this)
	fishBonus = 0.5, -- pufferfish: fish worth this much more (golden: twice this)
	species = {
		seahorse = { id = "seahorse", name = "Seahorse", color = Color3.fromRGB(255, 160, 70), perk = "Coral grows 25% faster", goldenPerk = "Coral grows 50% faster" },
		octopus = { id = "octopus", name = "Octopus", color = Color3.fromRGB(200, 90, 160), perk = "Harvests a grown coral every minute", goldenPerk = "Harvests a grown coral every 30 s" },
		pufferfish = { id = "pufferfish", name = "Pufferfish", color = Color3.fromRGB(240, 210, 90), perk = "Fish you catch are worth 50% more", goldenPerk = "Fish you catch are worth double" },
	} :: { [string]: PetDef },
	eggs = {
		{
			id = "reef", name = "Reef Egg", price = 750, color = Color3.fromRGB(120, 200, 230),
			odds = { { id = "seahorse", weight = 50 }, { id = "pufferfish", weight = 35 }, { id = "octopus", weight = 15 } },
		},
		{
			id = "abyss", name = "Abyss Egg", price = 6000, color = Color3.fromRGB(90, 60, 160),
			odds = { { id = "seahorse", weight = 30 }, { id = "pufferfish", weight = 30 }, { id = "octopus", weight = 40 } },
		},
	} :: { EggDef },
}
ReefConfig.EggById = {} :: { [string]: EggDef }
for _, egg in ReefConfig.Pets.eggs do
	ReefConfig.EggById[egg.id] = egg
end

return ReefConfig
