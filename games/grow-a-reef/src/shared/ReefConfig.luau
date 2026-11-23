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

ReefConfig.DATA_VERSION = 2 -- 2: coral planted anywhere in a round bed (1 used a tile grid)
ReefConfig.STARTING_SHELLS = 40
ReefConfig.STARTING_SEEDS = { kelp = 3 } :: { [string]: number }
ReefConfig.MAX_SEEDS_PER_TYPE = 999

-- Plot layout. Coral is planted anywhere inside the plot's round reef bed; each coral
-- uses one slot, and every slot bought also widens the bed.
ReefConfig.STARTING_SLOTS = 6
ReefConfig.MAX_SLOTS = 12
ReefConfig.BED_RADIUS = 11 -- studs, with the starting slots
ReefConfig.BED_RADIUS_PER_SLOT = 0.75 -- extra radius for each slot bought
ReefConfig.PLANT_SPACING = 5 -- minimum studs between two corals
ReefConfig.PLANT_EDGE = 1.5 -- keep coral this far inside the bed's edge
ReefConfig.PLANT_REACH = 50 -- how far from your character you can plant
ReefConfig.PLOT_COUNT = 6 -- one plot per player; set the place's max players to 6

-- Growing the reef: price of the n-th extra slot = floor(baseCost * costGrowth ^ n)
ReefConfig.EXPAND = { baseCost = 200, costGrowth = 2.5 }

ReefConfig.SEED_ORDER = { "kelp", "brain", "fan", "anemone", "clam", "star" }

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
} :: { [string]: SeedDef }

-- Rolled once when a seed is planted. Currents can later copy a mutation onto
-- a neighbour's un-mutated coral.
ReefConfig.Mutations = {
	{ id = "None", weight = 900, multiplier = 1 },
	{ id = "Glowing", weight = 75, multiplier = 2, color = Color3.fromRGB(120, 255, 200) },
	{ id = "Golden", weight = 22, multiplier = 5, color = Color3.fromRGB(255, 196, 40) },
	{ id = "Prismatic", weight = 3, multiplier = 15, color = Color3.fromRGB(255, 120, 255) },
} :: { MutationDef }

ReefConfig.MutationById = {} :: { [string]: MutationDef }
for _, mutation in ReefConfig.Mutations do
	ReefConfig.MutationById[mutation.id] = mutation
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
			id = "Current", name = "Ocean Current", weight = 30, duration = 40,
			color = Color3.fromRGB(110, 200, 255),
			message = "An ocean current is flowing! Mutations can drift between reefs.",
		},
		{
			id = "Night", name = "Bioluminescent Night", weight = 20, duration = 75,
			color = Color3.fromRGB(120, 255, 220),
			message = "Bioluminescent Night! The sea goes dark, and Glowing mutations are 3x as likely. Plant now!",
		},
		{
			id = "Frenzy", name = "Feeding Frenzy", weight = 20, duration = 60,
			color = Color3.fromRGB(255, 170, 90),
			message = "Feeding Frenzy! Fish come to your coral twice as fast.",
		},
		{
			id = "Treasure", name = "Treasure Storm", weight = 15, duration = 40,
			color = Color3.fromRGB(255, 205, 80),
			message = "Treasure Storm! Chests are sinking from the surface. Open them for shells and seeds!",
		},
		{
			id = "Whale", name = "Whale Pass", weight = 15, duration = 50,
			color = Color3.fromRGB(150, 190, 255),
			message = "A giant whale is passing overhead! Coral grows twice as fast while it's here.",
		},
	} :: { EventDef },
	glowingMultiplier = 3, -- Bioluminescent Night: Glowing mutation weight x this
	fishSpawnMultiplier = 2, -- Feeding Frenzy: fish spawn clock runs this much faster
	growthMultiplier = 2, -- Whale Pass: coral grows this much faster
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
	area = { minX = -210, maxX = 210, minZ = -110, maxZ = 150 },
	fishSchools = 6, -- each school is one species
	fishPerSchool = 9,
	turtles = 2,
	jellyfish = 8,
	mantas = 1,
	crabs = 8,
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

function ReefConfig.harvestValue(seedId: string, mutationId: string): number
	local seed = ReefConfig.Seeds[seedId]
	local mutation = ReefConfig.MutationById[mutationId]
	if not seed or not mutation then
		return 0
	end
	return math.floor(seed.sellValue * mutation.multiplier)
end

function ReefConfig.inventoryKey(seedId: string, mutationId: string): string
	return seedId .. ":" .. mutationId
end

function ReefConfig.splitInventoryKey(key: string): (string?, string?)
	local seedId, mutationId = string.match(key, "^(%w+):(%w+)$")
	return seedId, mutationId
end

return ReefConfig
