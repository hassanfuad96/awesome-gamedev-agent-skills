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

-- 4: fences, decorations, gear, quests, rebirths, titles, likes; 3: stacked mutations, Reef
-- Index, pets; 2: free planting; 1: tile grid
ReefConfig.DATA_VERSION = 4
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
	-- How FenceVisuals builds it: "planks" (posts and rails), "hedge" (kelp bushes), "wall"
	-- (stacked stone), "ribs" (arched bones) or "crystal" (glowing shards).
	kind: string,
	price: number, -- shells at Reef Supplies; 0 = free
	shop: boolean?, -- false: never sold (a Reef Index reward)
	postColor: Color3,
	plankColors: { Color3 },
	material: string,
	height: number,
	postSpacing: number,
	rails: number,
	brokenChance: number,
	rope: boolean,
	barnacles: boolean,
	glow: Color3?, -- crystal fences light up in this colour
}

-- Admins get an Admin button: start or stop sea events, announce to this server or every
-- server, and hand out gifts. Listed by user id, because usernames can change; the id is the
-- number in the player's profile link (roblox.com/users/<id>/profile). The server checks
-- every admin request against these lists.
ReefConfig.Admin = {
	owners = { [5067168140] = "far_rel2017" } :: { [number]: string },
	admins = {} :: { [number]: string }, -- e.g. [123456789] = "a_friend"
	announceMaxLength = 200,
	announceSeconds = 8, -- how long an announcement stays on screen
	giftShells = { 1000, 10000, 100000 },
	giftSeedCount = 1, -- seeds per player for each press of a seed gift button
	globalTopic = "GrowAReefAnnouncements", -- MessagingService topic for every-server messages
}

function ReefConfig.adminRole(userId: number): string?
	if ReefConfig.Admin.owners[userId] then
		return "Owner"
	elseif ReefConfig.Admin.admins[userId] then
		return "Admin"
	end
	return nil
end

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

-- Fences around each reef, with a gap at the front to walk in. Everyone owns the first one;
-- the rest are bought at Reef Supplies (or won from the Reef Index) and swapped in from there.
-- Materials are Enum.Material names.
ReefConfig.Fences = {
	{
		id = "shipwood",
		name = "Shipwreck Wood",
		kind = "planks",
		price = 0,
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
	{
		-- Thick kelp bushes on stalks, joined by a low leafy hedge.
		id = "kelp",
		name = "Kelp Hedge",
		kind = "hedge",
		price = 5000,
		-- Brighter than real kelp: leafy materials render dark under the sea's light.
		postColor = Color3.fromRGB(110, 190, 90),
		plankColors = { Color3.fromRGB(130, 220, 110), Color3.fromRGB(100, 205, 120), Color3.fromRGB(170, 235, 120) },
		material = "LeafyGrass",
		height = 4,
		postSpacing = 6,
		rails = 2,
		brokenChance = 0,
		rope = false,
		barnacles = false,
	},
	{
		-- A low wall of pink coral stone with round pillars.
		id = "coralstone",
		name = "Coral Stone Wall",
		kind = "wall",
		price = 25000,
		postColor = Color3.fromRGB(226, 160, 150),
		plankColors = { Color3.fromRGB(236, 178, 160), Color3.fromRGB(214, 140, 132), Color3.fromRGB(244, 206, 186), Color3.fromRGB(196, 128, 126) },
		material = "Cobblestone",
		height = 3.5,
		postSpacing = 9,
		rails = 3, -- rows of stones
		brokenChance = 0,
		rope = false,
		barnacles = true,
	},
	{
		-- Giant whale ribs arching over the edge of the reef, with a rope between them.
		id = "whalebone",
		name = "Whale Bone",
		kind = "ribs",
		price = 120000,
		postColor = Color3.fromRGB(240, 232, 210),
		plankColors = { Color3.fromRGB(176, 150, 104) },
		material = "Limestone",
		height = 7,
		postSpacing = 8,
		rails = 1,
		brokenChance = 0,
		rope = true,
		barnacles = true,
	},
	{
		-- Glowing crystal shards. Only from completing the Glow Anemone set in the Reef Index.
		id = "crystal",
		name = "Glow Crystal",
		kind = "crystal",
		price = 0,
		shop = false,
		postColor = Color3.fromRGB(150, 230, 255),
		plankColors = { Color3.fromRGB(120, 210, 255), Color3.fromRGB(200, 150, 255), Color3.fromRGB(140, 255, 220) },
		material = "Glass",
		height = 5,
		postSpacing = 6,
		rails = 1,
		brokenChance = 0,
		rope = false,
		barnacles = false,
		glow = Color3.fromRGB(130, 220, 255),
	},
}
ReefConfig.DEFAULT_FENCE = "shipwood"
ReefConfig.FENCE_GATE_WIDTH = 12 -- studs, the opening at the front
ReefConfig.FenceById = {} :: { [string]: FenceDef }
for _, fence in ReefConfig.Fences do
	ReefConfig.FenceById[fence.id] = fence
end

export type DecorDef = {
	id: string,
	name: string,
	price: number,
	footprint: number, -- studs of radius it takes up on the reef
	description: string,
}

-- Decorations: bought at Reef Supplies, then placed anywhere inside your fence (not on coral,
-- and not in the gateway). Picking one up puts it back in your storage.
ReefConfig.Decor = {
	maxPlaced = 24, -- per reef
	maxOwned = 99, -- of each kind, placed or in storage
	edge = 2, -- studs to keep clear inside the fence
	items = {
		{ id = "lantern", name = "Lantern Post", price = 800, footprint = 1.5, description = "A glowing lantern on a driftwood post." },
		{ id = "anchor", name = "Old Anchor", price = 2500, footprint = 2.5, description = "A rusty ship's anchor, half sunk in the sand." },
		{ id = "chest", name = "Treasure Chest", price = 6000, footprint = 2.5, description = "An open chest spilling gold coins." },
		{ id = "vent", name = "Bubble Vent", price = 12000, footprint = 2, description = "A rocky vent that bubbles all day." },
		{ id = "statue", name = "Fish Statue", price = 40000, footprint = 3, description = "A stone fish leaping from a carved plinth." },
		{ id = "arch", name = "Rock Arch", price = 90000, footprint = 5, description = "A huge natural arch you can swim through." },
	} :: { DecorDef },
}
ReefConfig.DecorById = {} :: { [string]: DecorDef }
for _, item in ReefConfig.Decor.items do
	ReefConfig.DecorById[item.id] = item
end
ReefConfig.DECOR_TAG = "ReefDecor" -- every placed decoration, for the client's placement preview

-- Gear upgrades, bought one level at a time at Reef Supplies. costs[n] buys level n.
ReefConfig.Gear = {
	fertilizer = {
		id = "fertilizer",
		name = "Fertilizer",
		costs = { 1500, 6000, 25000, 90000, 300000 },
		perLevel = 0.1, -- coral grows 10% faster per level
	},
	wand = {
		id = "wand",
		name = "Bubble Wand",
		costs = { 1000, 5000, 20000, 80000, 250000 },
		-- Clicking a growing coral gives it a burst of growth: per level, 1 second plus 1% of
		-- its full grow time. Then the wand needs `cooldown` seconds to refill.
		boostSeconds = 1,
		boostFraction = 0.01,
		cooldown = 10,
	},
	bag = {
		id = "bag",
		name = "Bigger Bag",
		costs = { 2000, 8000, 30000, 100000, 350000 },
		base = 30, -- coral your bag holds with no upgrades
		perLevel = 30,
	},
}
ReefConfig.GEAR_ORDER = { "fertilizer", "wand", "bag" }

function ReefConfig.bagCapacity(level: number): number
	local bag = ReefConfig.Gear.bag
	return bag.base + bag.perLevel * level
end

-- Seconds of growth one wand click gives a coral that takes growSeconds to grow.
function ReefConfig.wandBoost(level: number, growSeconds: number): number
	local wand = ReefConfig.Gear.wand
	return level * (wand.boostSeconds + wand.boostFraction * growSeconds)
end

export type QuestDef = { id: string, text: string, goal: number, shells: number, seed: { id: string, count: number }? }

-- Daily quests: everyone gets the same `perDay` quests each day (UTC), picked from this pool.
-- Each quest pays its shells times (your coral slots / 10), so the reward keeps up with you.
ReefConfig.Quests = {
	perDay = 3,
	pool = {
		{ id = "plant", text = "Plant %d coral", goal = 10, shells = 150 },
		{ id = "harvest", text = "Harvest %d coral", goal = 10, shells = 200 },
		{ id = "mutated", text = "Harvest %d mutated coral", goal = 3, shells = 400, seed = { id = "fan", count = 1 } },
		{ id = "sell", text = "Sell %d coral", goal = 20, shells = 250 },
		{ id = "fish", text = "Catch %d fish", goal = 5, shells = 250 },
		{ id = "hatch", text = "Hatch %d pet egg", goal = 1, shells = 300, seed = { id = "anemone", count = 1 } },
		{ id = "earn", text = "Earn %d shells selling coral", goal = 1000, shells = 300 },
		{ id = "decor", text = "Place %d decorations", goal = 2, shells = 200 },
	} :: { QuestDef },
}
ReefConfig.QuestById = {} :: { [string]: QuestDef }
for _, quest in ReefConfig.Quests.pool do
	ReefConfig.QuestById[quest.id] = quest
end

-- The day number (UTC) for a time.
function ReefConfig.dayNumber(time: number): number
	return time // 86400
end

-- Today's quest ids. A small fixed generator (not Random) so every server, and the tests, pick
-- the same quests for a day.
function ReefConfig.dailyQuests(day: number): { string }
	local ids = {}
	for _, quest in ReefConfig.Quests.pool do
		table.insert(ids, quest.id)
	end
	local seed = (day * 7919 + 104729) % 2147483647
	local picked = {}
	for _ = 1, math.min(ReefConfig.Quests.perDay, #ids) do
		seed = (seed * 48271) % 2147483647
		table.insert(picked, table.remove(ids, seed % #ids + 1))
	end
	return picked
end

function ReefConfig.questShells(quest: QuestDef, unlocked: number): number
	return math.floor(quest.shells * math.max(1, unlocked / 10))
end

-- Rebirth: start your reef over for a permanent shell bonus. You keep your pets, Reef Index,
-- fences, decorations, gear and titles; shells, seeds, coral, your bag and reef size reset.
ReefConfig.Rebirth = {
	baseCost = 500000, -- shells for the first rebirth
	costGrowth = 3, -- each rebirth after that costs this much more (500K, 1.5M, 4.5M, ...)
	shellBonus = 0.25, -- +25% shells from selling coral and catching fish, per rebirth
	maxRebirths = 25,
	-- Optional Roblox badges by rebirth count: create them on the Creator Dashboard, then put
	-- their ids here, e.g. [1] = 123456789, [5] = 987654321.
	badges = {} :: { [number]: number },
}

function ReefConfig.rebirthCost(rebirths: number): number
	local r = ReefConfig.Rebirth
	return math.floor(r.baseCost * r.costGrowth ^ rebirths)
end

function ReefConfig.shellMultiplier(rebirths: number): number
	return 1 + ReefConfig.Rebirth.shellBonus * rebirths
end

export type TitleDef = { id: string, text: string, color: Color3 }

-- Titles shown over your head. Earned from Reef Index sets and from rebirthing.
ReefConfig.Titles = {
	{ id = "reborn", text = "Reborn", color = Color3.fromRGB(255, 150, 90) },
	{ id = "kelpkeeper", text = "Kelp Keeper", color = Color3.fromRGB(120, 230, 120) },
	{ id = "bigbrain", text = "Big Brain", color = Color3.fromRGB(255, 150, 190) },
	{ id = "fanfavourite", text = "Fan Favourite", color = Color3.fromRGB(190, 140, 255) },
	{ id = "pearlhunter", text = "Pearl Hunter", color = Color3.fromRGB(235, 240, 255) },
	{ id = "starlight", text = "Starlight Legend", color = Color3.fromRGB(255, 225, 90) },
	{ id = "transcendent", text = "Transcendent", color = Color3.fromRGB(130, 255, 225) },
	{ id = "angler", text = "Master Angler", color = Color3.fromRGB(110, 190, 255) },
} :: { TitleDef }
ReefConfig.TitleById = {} :: { [string]: TitleDef }
for _, title in ReefConfig.Titles do
	ReefConfig.TitleById[title.id] = title
end

-- Reef ratings: anyone visiting can like a reef once a day, at the sign over its gate.
ReefConfig.Likes = {
	maxRemembered = 200, -- reefs a player's "liked today" list keeps
}

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
	Supplies = {
		name = "Old Shellby",
		bob = 0.15,
		greetings = {
			"Fences, lanterns, anchors... make that reef your own!",
			"A Bigger Bag holds more coral between trips to Pinch.",
			"Fertilizer makes every coral on your reef grow faster.",
			"Try the Bubble Wand: tap a growing coral to hurry it along.",
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

-- The reef's whole mound, out to the fence (the fence stands just past this).
function ReefConfig.moundRadius(): number
	return ReefConfig.bedRadius(ReefConfig.MAX_SLOTS) + 3
end

export type PlacedDecor = { item: string, x: number, z: number }

-- Why a decoration can't go at (x, z) from the plot centre, or nil if it can. Like
-- plantProblem, shared by the server and the client's preview.
function ReefConfig.decorProblem(itemId: string, x: number, z: number, plants: { [any]: { x: number, z: number } }, decor: { [any]: PlacedDecor }): string?
	local item = ReefConfig.DecorById[itemId]
	if not item then
		return "That isn't a decoration."
	end
	local placed = 0
	for _ in decor do
		placed += 1
	end
	if placed >= ReefConfig.Decor.maxPlaced then
		return `Your reef holds {ReefConfig.Decor.maxPlaced} decorations at most. Pick one up first.`
	end
	local reach = ReefConfig.moundRadius() - ReefConfig.Decor.edge - item.footprint
	if not (x * x + z * z <= reach * reach) then -- also refuses NaN
		return "Place it inside your fence."
	end
	-- Keep the way in from the gate (at -Z) clear.
	if math.abs(x) < ReefConfig.FENCE_GATE_WIDTH / 2 + item.footprint and z < -(reach - 10) then
		return "Keep the gateway clear."
	end
	for _, plant in plants do
		local dx, dz = plant.x - x, plant.z - z
		local gap = item.footprint + ReefConfig.PLANT_SPACING / 2
		if dx * dx + dz * dz < gap * gap then
			return "Too close to your coral."
		end
	end
	for _, other in decor do
		local otherItem = ReefConfig.DecorById[other.item]
		local dx, dz = other.x - x, other.z - z
		local gap = item.footprint + (if otherItem then otherItem.footprint else 2)
		if dx * dx + dz * dz < gap * gap then
			return "Too close to another decoration."
		end
	end
	return nil
end

-- Why a coral can't be planted at (x, z) from the plot centre, or nil if it can. Shared so
-- the client's placement preview agrees with the server, which makes the real decision.
-- `decor` is the reef's placed decorations, which coral can't grow on.
function ReefConfig.plantProblem(x: number, z: number, unlocked: number, plants: { [any]: { x: number, z: number } }, decor: { [any]: PlacedDecor }?): string?
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
	for _, placed in decor or {} do
		local item = ReefConfig.DecorById[placed.item]
		local dx, dz = placed.x - x, placed.z - z
		local gap = (if item then item.footprint else 2) + ReefConfig.PLANT_SPACING / 2
		if dx * dx + dz * dz < gap * gap then
			return "Too close to a decoration."
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

export type IndexReward = {
	title: string?,
	fence: string?,
	decor: { id: string, count: number }?,
	pet: { species: string, golden: boolean }?,
}

-- What each Reef Index set gives on top of its shells. Players who finished a set before
-- these rewards existed get them the next time they join.
ReefConfig.IndexRewards = {
	kelp = { title = "kelpkeeper" },
	brain = { title = "bigbrain", decor = { id = "lantern", count = 2 } },
	fan = { title = "fanfavourite", decor = { id = "anchor", count = 1 } },
	anemone = { fence = "crystal" },
	clam = { title = "pearlhunter", pet = { species = "seahorse", golden = true } },
	star = { title = "starlight", pet = { species = "octopus", golden = true } },
	seagrass = { title = "transcendent", decor = { id = "arch", count = 1 } },
	fish = { title = "angler", pet = { species = "pufferfish", golden = true } },
} :: { [string]: IndexReward }

-- "Kelp Keeper title, Golden Seahorse" for the Reef Index window and the reward message.
function ReefConfig.indexRewardText(setId: string): string?
	local reward = ReefConfig.IndexRewards[setId]
	if not reward then
		return nil
	end
	local parts = {}
	if reward.title and ReefConfig.TitleById[reward.title] then
		table.insert(parts, `"{ReefConfig.TitleById[reward.title].text}" title`)
	end
	if reward.fence and ReefConfig.FenceById[reward.fence] then
		table.insert(parts, `{ReefConfig.FenceById[reward.fence].name} fence`)
	end
	if reward.decor and ReefConfig.DecorById[reward.decor.id] then
		local name = ReefConfig.DecorById[reward.decor.id].name
		table.insert(parts, if reward.decor.count > 1 then `{reward.decor.count} {name}s` else name)
	end
	if reward.pet and ReefConfig.Pets.species[reward.pet.species] then
		local name = ReefConfig.Pets.species[reward.pet.species].name
		table.insert(parts, if reward.pet.golden then `Golden {name} pet` else `{name} pet`)
	end
	return if #parts > 0 then table.concat(parts, ", ") else nil
end

return ReefConfig
