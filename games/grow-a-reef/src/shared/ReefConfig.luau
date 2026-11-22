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

local ReefConfig = {}

ReefConfig.DATA_VERSION = 1
ReefConfig.STARTING_SHELLS = 40
ReefConfig.STARTING_SEEDS = { kelp = 3 } :: { [string]: number }
ReefConfig.MAX_SEEDS_PER_TYPE = 999

-- Plot layout
ReefConfig.TILE_COLUMNS = 4
ReefConfig.TILE_ROWS = 3
ReefConfig.TILE_COUNT = 12
ReefConfig.STARTING_TILES = 6
ReefConfig.TILE_SIZE = 8
ReefConfig.PLOT_COUNT = 6 -- one plot per player; set the place's max players to 6

-- Unlocking extra tiles: price of the n-th extra tile = floor(baseCost * costGrowth ^ n)
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

-- Ocean currents flow from plot i to plot i + 1 (the last plot wraps to the first).
ReefConfig.Current = {
	interval = 240, -- seconds between currents
	duration = 40, -- how long a current lasts
	tick = 8, -- seconds between spread attempts while it flows
	spreadChance = 0.35, -- chance per tick, per plot, that one mutation drifts downstream
}

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

function ReefConfig.expandCost(unlocked: number): number
	local extra = unlocked - ReefConfig.STARTING_TILES
	return math.floor(ReefConfig.EXPAND.baseCost * ReefConfig.EXPAND.costGrowth ^ extra)
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
