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
	weight: number, -- how often it comes to reef coral (0: never)
	multiplier: number,
	color: Color3,
	kelpWeight: number?, -- set for Kelp Forest fish: how often each turns up there
	creature: string?, -- its mesh model in CreatureMeshes, if it has one (else Part-built)
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
-- New players start with no seeds: Kai, the tutorial guide by the spawn, hands out the
-- first ones (ReefConfig.Tutorial.firstSeeds).
ReefConfig.STARTING_SEEDS = {} :: { [string]: number }
ReefConfig.MAX_SEEDS_PER_TYPE = 999

-- Plot layout. Each reef is a round bed of sand planters, one coral per planter, laid out
-- on a hex grid. You start with STARTING_SLOTS planters and unlock the rest, one at a time,
-- at the Research Laboratory (EXPAND). Saved coral remembers its planter (Plant.slot).
ReefConfig.STARTING_SLOTS = 20
ReefConfig.MAX_SLOTS = 30
ReefConfig.PLANTER_SPACING = 10 -- studs between neighbouring planter centres
ReefConfig.PLANTER_RADIUS = 3.2
ReefConfig.PLANTER_HEIGHT = 1.4 -- how far a planter's sand top stands above the bed
ReefConfig.BED_RADIUS = 34 -- the round bed the planters stand on
ReefConfig.MOUND_RADIUS = 44 -- the whole reef out to the fence; decorations go round the bed
ReefConfig.PLANT_REACH = 60 -- how far from your character you can plant
ReefConfig.PLOT_COUNT = 6 -- one plot per player; set the place's max players to 6

-- Planter centres as (x, z) offsets in the reef's frame, in the order they unlock: the middle,
-- then each hex ring outwards. The outer ring fills from the back, so the way in from the
-- gate (local -Z) stays open longest.
ReefConfig.Planters = {} :: { { x: number, z: number } }
do
	local cells = {}
	for q = -3, 3 do
		for r = -3, 3 do
			local ring = math.max(math.abs(q), math.abs(r), math.abs(q + r))
			if ring <= 3 then
				local x = ReefConfig.PLANTER_SPACING * (q + r / 2)
				local z = ReefConfig.PLANTER_SPACING * (r * math.sqrt(3) / 2)
				table.insert(cells, { x = x, z = z, ring = ring })
			end
		end
	end
	table.sort(cells, function(a, b)
		if a.ring ~= b.ring then
			return a.ring < b.ring
		elseif math.abs(a.z - b.z) > 0.01 then
			return a.z > b.z
		end
		return a.x < b.x
	end)
	for i = 1, ReefConfig.MAX_SLOTS do
		ReefConfig.Planters[i] = { x = cells[i].x, z = cells[i].z }
	end
end

-- The planter at (x, z) in a reef's frame, if the point is on one.
function ReefConfig.planterAt(x: number, z: number): number?
	local reach = ReefConfig.PLANTER_RADIUS + 0.8
	for slot, planter in ReefConfig.Planters do
		local dx, dz = planter.x - x, planter.z - z
		if dx * dx + dz * dz <= reach * reach then -- false for NaN
			return slot
		end
	end
	return nil
end

-- The Starter Lagoon, the central hub: a round plaza in the middle with the spawn, and four
-- buildings in the four quadrants round it, each joined to the plaza by a glass tube corridor.
-- The roads leave along the axes: north to the Kelp Forest, west through the Ocean Gate to the
-- Main Reef, east to the Sunken Ruins, south to the Abyss.
-- North is -Z, east is +X. Every position is on the seabed (Y = 0).
ReefConfig.Lagoon = {
	center = Vector3.zero, -- the plaza's middle, where new players spawn
	plazaRadius = 44,
	rimRadius = 180, -- the lagoon's rocky edge, open where the roads leave
	guide = Vector3.new(12, 0, -10), -- the guide rock beside the spawn, where Kai the guide waits
	-- North-west, the biggest: the Research Laboratory, a geodesic glass dome with a glowing
	-- coral on top. Research species, unlock planters, coral growth, reef health.
	research = Vector3.new(-84, 0, -84),
	labRadius = 36,
	-- North-east: the Aquarium (Collection Center). The Reef Index, the Pet Hatchery and tanks
	-- showing everything you've discovered.
	aquarium = Vector3.new(84, 0, -84),
	-- South-east: the Coral Market. Seeds, selling, decorations, fences and rare species.
	coralShop = Vector3.new(84, 0, 84),
	-- South-west: the Equipment Station. Diving gear, oxygen tank, swim fins.
	upgrade = Vector3.new(-84, 0, 84),
	oceanGate = Vector3.new(-122, 0, 0), -- west: the stone arch out to the Main Reef
	boards = Vector3.new(0, 0, 76), -- south: the two leaderboards, either side of the path
}

-- The Main Reef: the big coral garden through the Ocean Gate, where the reefs are. A stone
-- road runs west along Z = 0 with three reefs on each side, their gates facing it. Coral
-- bridges arch over the road between the reefs, fish nurseries sit in the gaps between
-- reefs, rocky ridges with caves wall it in north and south, and the Grand Reef Rock (with a
-- grotto in its foot) closes the far west end.
ReefConfig.MainReef = {
	roadFrom = -150, -- X where the road leaves the Ocean Gate
	roadTo = -790, -- X where it ends, at the Grand Reef Rock
	roadWidth = 14,
	entrance = Vector3.new(-205, 0, 0), -- the Main Reef sign over the road
	-- Reef centres, in plot order: west along the north side, then back east along the
	-- south, so a current flowing 1 > 2 > ... > 6 > 1 goes round the road.
	reefs = {
		Vector3.new(-330, 0, -100),
		Vector3.new(-480, 0, -100),
		Vector3.new(-630, 0, -100),
		Vector3.new(-630, 0, 100),
		Vector3.new(-480, 0, 100),
		Vector3.new(-330, 0, 100),
	},
	bridges = { -405, -555 }, -- X of the coral bridges over the road
	fishSpots = { -- wild fish nurseries in the gaps between reefs
		Vector3.new(-405, 0, -104),
		Vector3.new(-555, 0, -104),
		Vector3.new(-555, 0, 104),
		Vector3.new(-405, 0, 104),
	},
	ridgeZ = 190, -- the rocky ridges along the north and south edges
	caves = { -- small caves in the ridges: { mouth, direction into the rock }
		{ mouth = Vector3.new(-720, 0, -168), into = Vector3.new(0, 0, -1) },
		{ mouth = Vector3.new(-720, 0, 168), into = Vector3.new(0, 0, 1) },
		{ mouth = Vector3.new(-255, 0, -170), into = Vector3.new(0, 0, -1) },
	},
	grandRock = Vector3.new(-805, 0, 0),
}

-- Where reef `index` sits: its centre on the seabed, turned so its gate (local -Z) faces the
-- road. Saved coral and decoration positions are in this frame, so they stay put on any reef.
function ReefConfig.plotFrame(index: number): CFrame
	local center = ReefConfig.MainReef.reefs[index]
	return CFrame.lookAt(center, Vector3.new(center.X, center.Y, 0))
end

-- A world point as an offset (x, z) in a reef's frame (ReefConfig.plotFrame), and back.
-- Coral and decorations are saved as these offsets.
function ReefConfig.plotOffset(frame: CFrame, point: Vector3): (number, number)
	local offset = frame:PointToObjectSpace(point)
	return offset.X, offset.Z
end

function ReefConfig.plotPoint(frame: CFrame, x: number, z: number, y: number): Vector3
	local point = frame:PointToWorldSpace(Vector3.new(x, 0, z))
	return Vector3.new(point.X, y, point.Z)
end

-- Whether (x, z) lies within `margin` studs of any reef's mound.
function ReefConfig.nearPlot(x: number, z: number, margin: number): boolean
	local reach = ReefConfig.MOUND_RADIUS + margin
	for index = 1, ReefConfig.PLOT_COUNT do
		local center = ReefConfig.plotFrame(index).Position
		local dx, dz = x - center.X, z - center.Z
		if dx * dx + dz * dz < reach * reach then
			return true
		end
	end
	return false
end

-- Unlocking a planter: the n-th extra one costs floor(baseCost * costGrowth ^ n) shells and
-- 1 + floor(n / 2) pearls, so the last ones need exploring the Main Reef for pearls.
ReefConfig.EXPAND = { baseCost = 1000, costGrowth = 1.55 }

-- Shells and pearls lying around the Main Reef. Anyone can swim into one to pick it up; it
-- comes back somewhere else in a while. Pearls hide in caves, the grotto and up high.
ReefConfig.Collectibles = {
	shells = { count = 18, min = 5, max = 25, respawn = { 40, 80 } }, -- shells each, seconds
	pearls = { count = 4, respawn = { 120, 240 } },
	reach = 7, -- studs: how close you must be (the server checks)
}

export type FenceDef = {
	id: string,
	name: string,
	-- How FenceVisuals builds it: "planks" (posts and rails), "hedge" (kelp bushes), "wall"
	-- (stacked stone), "ribs" (arched bones) or "crystal" (glowing shards).
	kind: string,
	price: number, -- shells at Reef Supplies; 0 = free
	shop: boolean?, -- false: never sold (a Reef Index reward, or a game pass's)
	pass: string?, -- the ReefConfig.Store.passes key that gives this fence
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
-- whirlpool pads (one beside the Coral Market, one in front of every reef's gate).
ReefConfig.Teleport = {
	cooldown = 3, -- seconds between teleports
	shopsPad = Vector3.new(68, 0, 50), -- beside the Coral Market's corridor
}

-- The Starter Lagoon tutorial. Kai (by the spawn) walks every new player through these
-- steps in order; the HUD shows the current one and points the way. Each step finishes when
-- the player does `action` (the same names Quests.progress reports), except "guide" (talk
-- to Kai) and "upgrade" (talk at the Research Laboratory's counter).
export type TutorialStep = {
	id: string,
	action: string,
	title: string,
	hint: string,
	inky: string, -- what Kai the guide says while this is the current step (once Inky's)
}
ReefConfig.Tutorial = {
	firstSeeds = { kelp = 3 } :: { [string]: number }, -- Kai's gift, the first step
	reward = 150, -- shells for finishing every step
	steps = {
		{
			id = "seed",
			action = "guide",
			title = "Collect your first coral seed",
			hint = "Talk to Kai the guide, right beside the spawn.",
			inky = "Welcome to the Starter Lagoon! Here are 3 Bubble Kelp seeds to get you going.",
		},
		{
			id = "plant",
			action = "plant",
			title = "Plant your first coral",
			hint = "Press Home to go to your reef in the Main Reef, through the Ocean Gate. Pick a seed, then tap a sand planter.",
			inky = "Now press Home to visit your reef in the Main Reef. Pick a seed and tap a sand planter!",
		},
		{
			id = "sell",
			action = "sell",
			title = "Earn your first shells",
			hint = "When a coral says Ready!, click it to harvest. Then sell your bag at the Coral Market (south-east).",
			inky = "Harvest coral when it's Ready!, then sell your bag to Pinch at the Coral Market.",
		},
		{
			id = "fish",
			action = "fish",
			title = "Unlock your first fish",
			hint = "Plant again and let it grow. Fish gather round fully grown coral: click one to catch it.",
			inky = "Fish love grown coral. Let some grow on your reef, then click a fish to catch it!",
		},
		{
			id = "expand",
			action = "upgrade",
			title = "Learn how to expand your reef",
			hint = "Visit the Research Laboratory, the big glass dome north-west of the plaza.",
			inky = "Last one! The Research Laboratory, the big dome, unlocks planters and new species.",
		},
	} :: { TutorialStep },
	doneLines = {
		"Your reef is looking great! Rare seeds show up in the Coral Market at every restock.",
		"Try the Research Station: the Reef Index pays out when you finish a set.",
		"Sea events start every few minutes. Watch the timer under your shells!",
		"Follow the sand road east from the plaza to the Sunken Ruins. Shipwrecks sink there!",
		"Take the road north from the plaza to the Kelp Forest. Otto the otter has challenges for you!",
	},
}

-- The step a player is on, or nil once they've finished the tutorial.
function ReefConfig.tutorialStep(step: number): TutorialStep?
	return ReefConfig.Tutorial.steps[step]
end

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
	{
		-- Gold spires topped with pearls. Only from the VIP Royal Fence game pass (Store).
		id = "royal",
		name = "Royal Pearl",
		kind = "crystal",
		price = 0,
		shop = false,
		pass = "royalFence",
		-- Deep golds (the sea's blue light pales them) and warm pearl.
		postColor = Color3.fromRGB(255, 180, 30),
		plankColors = { Color3.fromRGB(255, 185, 35), Color3.fromRGB(255, 160, 20), Color3.fromRGB(255, 232, 205) },
		material = "Foil",
		height = 5.5,
		postSpacing = 6,
		rails = 1,
		brokenChance = 0,
		rope = false,
		barnacles = false,
		glow = Color3.fromRGB(255, 200, 110),
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
	oxygen = {
		id = "oxygen",
		name = "Oxygen Tank",
		costs = { 800, 4000, 15000, 60000, 200000 },
		perLevel = 45, -- extra seconds of air in deep water (ReefConfig.Oxygen)
	},
	fins = {
		id = "fins",
		name = "Swim Fins",
		costs = { 1200, 6000, 24000, 90000, 300000 },
		perLevel = 0.08, -- 8% faster swimming per level
	},
}
ReefConfig.GEAR_ORDER = { "fertilizer", "wand", "bag", "oxygen", "fins" }
-- Where each piece of gear is sold: coral growth is research, the rest is diving equipment.
ReefConfig.GearStation = {
	fertilizer = "lab",
	wand = "equipment",
	bag = "equipment",
	oxygen = "equipment",
	fins = "equipment",
} :: { [string]: string }

-- Air. You breathe freely almost everywhere; only deep water (the Main Reef's caves, the
-- Ruins' cave, the bottom of the Abyss: see the shared DeepWater module) uses it up, and it
-- refills as soon as you're out. Run out and you're whisked back to the plaza.
ReefConfig.Oxygen = {
	base = 60, -- seconds of air with no Oxygen Tank upgrades
	refillPerSecond = 30,
}

function ReefConfig.oxygenCapacity(level: number): number
	return ReefConfig.Oxygen.base + ReefConfig.Gear.oxygen.perLevel * level
end

function ReefConfig.swimSpeedMultiplier(finsLevel: number): number
	return 1 + ReefConfig.Gear.fins.perLevel * finsLevel
end

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

-- Quest rewards grow with the reef: x1 with the starting planters, x3 with all of them.
function ReefConfig.questShells(quest: QuestDef, unlocked: number): number
	local extra = math.max(0, unlocked - ReefConfig.STARTING_SLOTS)
	return math.floor(quest.shells * (1 + extra * 2 / (ReefConfig.MAX_SLOTS - ReefConfig.STARTING_SLOTS)))
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

export type StorePass = { key: string, id: number, icon: number, name: string, price: number, description: string }
-- A product is one of: shells (a shell pack), a boost (instantGrow, restock), the Starter Pack
-- (starter), or a gift (gift = true): a gift goes to the friend the buyer picked, either shells or
-- a game pass (pass = its key) that the friend keeps forever.
export type StoreProduct = {
	key: string,
	id: number,
	icon: number,
	name: string,
	price: number,
	description: string,
	shells: number?,
	gift: boolean?,
	pass: string?,
	starter: boolean?,
}

-- Robux purchases (the Store button). These ids are the game passes and developer products
-- created for this game on Roblox; their prices are set there (Creator Dashboard → Monetization),
-- and `price` here is only what the Store window shows until Roblox reports the live price.
-- Monetization.luau checks ownership and grants every purchase on the server.
ReefConfig.Store = {
	passes = {
		{ key = "doubleShells", id = 2098378468, icon = 95742037983152, name = "2x Shells", price = 349, description = "Coral and fish sell for double shells, forever." },
		{ key = "vipBag", id = 2098990444, icon = 114475212129680, name = "VIP Bag", price = 149, description = "Your bag holds 100 more coral, forever." },
		{ key = "speedFins", id = 2100196418, icon = 71397266954804, name = "Speed Fins", price = 99, description = "Swim 50% faster, forever." },
		{ key = "royalFence", id = 2100418407, icon = 82183083188594, name = "VIP Royal Fence", price = 199, description = "The gold-and-pearl Royal Pearl fence and the VIP title." },
	} :: { StorePass },
	products = {
		{ key = "instantGrow", id = 3735507930, icon = 118944028336147, name = "Instant Grow", price = 49, description = "Every coral growing on your reef finishes now." },
		{ key = "restock", id = 3735507942, icon = 72061199940919, name = "Personal Restock", price = 25, description = "Every seed fully stocked in the Seed Shop, just for you, for 5 minutes." },
		{ key = "shellPouch", id = 3735508014, icon = 103748338573033, name = "Shell Pouch", price = 49, description = "25,000 shells.", shells = 25000 },
		{ key = "shellChest", id = 3735508029, icon = 129559014498909, name = "Shell Chest", price = 299, description = "250,000 shells. Best value!", shells = 250000 },
		{ key = "starterPack", id = 3735602585, icon = 101305712359335, name = "Starter Pack", price = 99, description = "Golden Seahorse, 5 Glow Anemone, 2 Pearl Clam seeds and 20,000 shells.", starter = true },
		{ key = "giftShellChest", id = 3735602600, icon = 103011145197660, name = "Gift: Shell Chest", price = 299, description = "250,000 shells for a friend.", shells = 250000, gift = true },
		{ key = "giftDoubleShells", id = 3735602621, icon = 97945944794612, name = "Gift: 2x Shells", price = 349, description = "The 2x Shells pass for a friend, forever.", pass = "doubleShells", gift = true },
		{ key = "giftVipBag", id = 3735602677, icon = 87700947803393, name = "Gift: VIP Bag", price = 149, description = "The VIP Bag pass for a friend, forever.", pass = "vipBag", gift = true },
	} :: { StoreProduct },
	-- The Starter Pack: offered for the first `days` days after a player first joins, once.
	starter = {
		days = 3,
		pet = { species = "seahorse", golden = true },
		seeds = { anemone = 5, clam = 2 },
		shells = 20000,
		fullPetsShells = 15000, -- instead of the pet, when the player has no room for another
	},
	-- A gifted pass the friend already has turns into this many shells for them instead.
	giftOwnedShells = 250000,
	doubleShells = 2, -- sale multiplier with the 2x Shells pass
	vipBagBonus = 100, -- extra bag space with the VIP Bag pass
	speedFinsMultiplier = 1.5, -- swim speed with the Speed Fins pass
	royalFence = "royal", -- the fence and title the VIP Royal Fence pass gives
	royalTitle = "vip",
	receiptsKept = 100, -- recent purchase ids remembered per player, so a receipt is never granted twice
}
ReefConfig.StorePassByKey = {} :: { [string]: StorePass }
ReefConfig.StorePassById = {} :: { [number]: StorePass }
for _, pass in ReefConfig.Store.passes do
	ReefConfig.StorePassByKey[pass.key] = pass
	ReefConfig.StorePassById[pass.id] = pass
end
ReefConfig.StoreProductById = {} :: { [number]: StoreProduct }
ReefConfig.StoreProductByKey = {} :: { [string]: StoreProduct }
for _, product in ReefConfig.Store.products do
	ReefConfig.StoreProductById[product.id] = product
	ReefConfig.StoreProductByKey[product.key] = product
end

-- Rewards for coming back and bringing friends (Rewards.luau, Social.luau). Codes live on the
-- server only (Rewards.luau), so they can't be read from the game files.
export type RewardBundle = { shells: number?, seeds: { [string]: number }? }

ReefConfig.Rewards = {
	-- Daily login streak, by day of the streak; after day 7 it starts again at day 1 (the
	-- streak count keeps going). Missing a day (UTC) restarts at day 1.
	daily = {
		{ shells = 500 },
		{ shells = 1000 },
		{ seeds = { anemone = 2 } },
		{ shells = 2500 },
		{ seeds = { clam = 1 } },
		{ shells = 5000 },
		{ shells = 10000, seeds = { star = 1 } },
	} :: { RewardBundle },
	-- While you're away your reef's planters bring in shells (and coral keeps growing).
	offline = {
		minSeconds = 5 * 60, -- shorter absences don't count
		maxSeconds = 8 * 3600, -- at most 8 hours' worth
		shellsPerPlanterMinute = 1, -- per unlocked planter, times the sale bonus
	},
	-- Sale bonuses on top of rebirths and 2x Shells.
	premiumBonus = 0.1, -- Roblox Premium members
	friendBonus = 0.1, -- per friend in the same server
	friendBonusMax = 0.5,
	-- The game's Roblox group. 0 = no group yet: the group reward stays hidden.
	group = { id = 0, shells = 5000, title = "reefcrew" },
	-- Inviting friends: the inviter gets `shells` for each friend who joins from their invite
	-- for the first time and stays `stayMinutes`; the friend gets `newcomerShells`.
	referral = { shells = 5000, newcomerShells = 2000, stayMinutes = 5, ambassadorAt = 3, title = "ambassador" },
	-- The weekly board ranks shells earned since Monday 00:00 UTC. Prizes by rank last week.
	weekly = {
		size = 10,
		prizes = { 100000, 50000, 25000, 10000, 10000, 10000, 10000, 10000, 10000, 10000 },
		title = "champion", -- for first place
	},
	-- Watering a friend's reef at its gate sign: their growing coral jumps ahead.
	watering = {
		growSeconds = 60,
		visitorShells = 200,
		givenPerDay = 10, -- reefs one player can water a day (each reef once)
		receivedPerDay = 30, -- waterings one reef can take a day
	},
	-- Trading seeds and pets with someone in the same server.
	trade = {
		maxSeedKinds = 8,
		maxPets = 4,
		requestSeconds = 60, -- how long a trade request stays open
		cooldown = 3, -- seconds between trade requests
	},
	visitCooldown = 5,
}

-- The Monday-based week number (UTC) of a time.
function ReefConfig.weekNumber(time: number): number
	return (time - 4 * 86400) // (7 * 86400) -- 1 Jan 1970 was a Thursday; weeks start on Monday
end

-- "500 shells, 2 Glow Anemone seeds" for a reward bundle.
function ReefConfig.bundleText(bundle: RewardBundle): string
	local parts = {}
	if bundle.shells and bundle.shells > 0 then
		local formatted = tostring(bundle.shells):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		table.insert(parts, `{formatted} shells`)
	end
	for _, seedId in ReefConfig.SEED_ORDER do
		local count = bundle.seeds and bundle.seeds[seedId]
		local seed = ReefConfig.Seeds[seedId]
		if count and count > 0 and seed then
			table.insert(parts, `{count} {seed.name} seed{if count == 1 then "" else "s"}`)
		end
	end
	return table.concat(parts, ", ")
end

export type TitleDef = { id: string, text: string, color: Color3 }

-- Titles shown over your head. Earned from Reef Index sets and from rebirthing.
ReefConfig.Titles = {
	{ id = "reborn", text = "Reborn", color = Color3.fromRGB(255, 150, 90) },
	{ id = "vip", text = "VIP", color = Color3.fromRGB(255, 215, 90) }, -- the VIP Royal Fence game pass
	{ id = "kelpkeeper", text = "Kelp Keeper", color = Color3.fromRGB(120, 230, 120) },
	{ id = "bigbrain", text = "Big Brain", color = Color3.fromRGB(255, 150, 190) },
	{ id = "fanfavourite", text = "Fan Favourite", color = Color3.fromRGB(190, 140, 255) },
	{ id = "pearlhunter", text = "Pearl Hunter", color = Color3.fromRGB(235, 240, 255) },
	{ id = "starlight", text = "Starlight Legend", color = Color3.fromRGB(255, 225, 90) },
	{ id = "transcendent", text = "Transcendent", color = Color3.fromRGB(130, 255, 225) },
	{ id = "angler", text = "Master Angler", color = Color3.fromRGB(110, 190, 255) },
	-- Sunken Ruins: the explorer missions and the two hidden coral sets.
	{ id = "ruinexplorer", text = "Ruin Explorer", color = Color3.fromRGB(240, 200, 130) },
	{ id = "ghostdiver", text = "Ghost Diver", color = Color3.fromRGB(190, 235, 255) },
	{ id = "relickeeper", text = "Relic Keeper", color = Color3.fromRGB(255, 180, 110) },
	-- Kelp Forest: all three hidden glades (KelpConfig.Challenges).
	{ id = "kelpranger", text = "Kelp Ranger", color = Color3.fromRGB(150, 225, 90) },
	-- The Abyss: every deep-sea creature spotted, and two abyssal coral sets.
	{ id = "abyssdiver", text = "Abyss Diver", color = Color3.fromRGB(150, 140, 255) },
	{ id = "deepglow", text = "Deep Glow", color = Color3.fromRGB(110, 210, 255) },
	{ id = "voidwalker", text = "Void Walker", color = Color3.fromRGB(130, 255, 215) },
	-- Rewards: joining the group, inviting friends, and winning the weekly board.
	{ id = "reefcrew", text = "Reef Crew", color = Color3.fromRGB(120, 220, 255) },
	{ id = "ambassador", text = "Reef Ambassador", color = Color3.fromRGB(255, 170, 220) },
	{ id = "champion", text = "Weekly Champion", color = Color3.fromRGB(255, 200, 60) },
} :: { TitleDef }
ReefConfig.TitleById = {} :: { [string]: TitleDef }
for _, title in ReefConfig.Titles do
	ReefConfig.TitleById[title.id] = title
end

-- Reef ratings: anyone visiting can like a reef once a day, at the sign over its gate.
ReefConfig.Likes = {
	maxRemembered = 200, -- reefs a player's "liked today" list keeps
}

-- Species research (the Research Laboratory): a coral sold in the Coral Market can only be
-- bought once you've researched it. Bubble Kelp is known from the start; each species after it
-- needs the one before it researched and grown at least once (it's in your Reef Index), plus
-- shells. Seeds you get any other way can always be planted.
ReefConfig.Research = {
	free = "kelp",
	costs = { brain = 150, fan = 600, anemone = 2500, clam = 10000, star = 50000 },
	order = { "kelp", "brain", "fan", "anemone", "clam", "star" },
}

-- Whether this player can buy seedId in the Coral Market.
function ReefConfig.speciesUnlocked(data: any, seedId: string): boolean
	return seedId == ReefConfig.Research.free or (data.research ~= nil and data.research[seedId] == true)
end

-- Why seedId can't be researched yet, or nil if it can (it still costs its shells).
function ReefConfig.researchProblem(data: any, seedId: string): string?
	local order = ReefConfig.Research.order
	local index = table.find(order, seedId)
	if not index or seedId == ReefConfig.Research.free then
		return "That species can't be researched."
	end
	if ReefConfig.speciesUnlocked(data, seedId) then
		return "You've already researched that species."
	end
	local previous = order[index - 1]
	local previousName = ReefConfig.Seeds[previous].name
	if not ReefConfig.speciesUnlocked(data, previous) then
		return `Research {previousName} first.`
	end
	for key in data.index and data.index.coral or {} do
		if ReefConfig.splitInventoryKey(key) == previous then
			return nil
		end
	end
	return `Grow and harvest some {previousName} first: research needs a sample.`
end

ReefConfig.SEED_ORDER = { "kelp", "brain", "fan", "anemone", "clam", "star", "seagrass", "ghost", "relic", "glowcap", "lumen", "voidbloom" }

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
	-- Hidden coral from the Sunken Ruins (RuinsConfig): never in the shop. Ghost Coral grows in
	-- the cave (a cutting a day), and turns up in ruins chests.
	ghost = {
		id = "ghost", name = "Ghost Coral", price = 0, growSeconds = 900, sellValue = 9000,
		color = Color3.fromRGB(180, 230, 255), stockChance = 0, stockMin = 0, stockMax = 0,
		shop = false, rarity = "Mythic",
	},
	-- Relic Coral grows in the temple sanctum, for divers who found every relic, and comes
	-- from the last exploration missions.
	relic = {
		id = "relic", name = "Relic Coral", price = 0, growSeconds = 1800, sellValue = 45000,
		color = Color3.fromRGB(255, 160, 110), stockChance = 0, stockMin = 0, stockMax = 0,
		shop = false, rarity = "Ancient",
	},
	-- Abyssal coral: sold only at Lumi's stall in the Abyss (AbyssConfig.SHOP_SEEDS), at these
	-- prices, never in the Coral Market. The high-value end of the game.
	glowcap = {
		id = "glowcap", name = "Glowcap", price = 45000, growSeconds = 1500, sellValue = 120000,
		color = Color3.fromRGB(180, 110, 255), stockChance = 0, stockMin = 0, stockMax = 0,
		shop = false, rarity = "Abyssal",
	},
	lumen = {
		id = "lumen", name = "Lumen Brain", price = 180000, growSeconds = 2400, sellValue = 480000,
		color = Color3.fromRGB(90, 200, 255), stockChance = 0, stockMin = 0, stockMax = 0,
		shop = false, rarity = "Abyssal",
	},
	voidbloom = {
		id = "voidbloom", name = "Void Bloom", price = 750000, growSeconds = 3600, sellValue = 2000000,
		color = Color3.fromRGB(110, 255, 210), stockChance = 0, stockMin = 0, stockMax = 0,
		shop = false, rarity = "Abyssal",
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

-- Never rolled at planting; only sea events give these (Cold Current, Bioluminescent Night,
-- Volcano Vent).
ReefConfig.EventMutations = {
	{ id = "Frosted", weight = 0, multiplier = 3, color = Color3.fromRGB(175, 230, 255) },
	{ id = "Shadow", weight = 0, multiplier = 4, color = Color3.fromRGB(110, 60, 180) },
	{ id = "Molten", weight = 0, multiplier = 6, color = Color3.fromRGB(255, 110, 40) },
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

-- Sea events: one at a time, picked at random (never the same twice in a row). The weights
-- add up to 100, so each one is that event's percent chance.
ReefConfig.Events = {
	interval = 180, -- seconds from the end of one event to the start of the next
	list = {
		{
			id = "Current", name = "Ocean Current", weight = 15, duration = 40,
			color = Color3.fromRGB(110, 200, 255),
			message = "An ocean current is flowing! Mutations can drift between reefs.",
		},
		{
			id = "Cold", name = "Cold Current", weight = 10, duration = 45,
			color = Color3.fromRGB(175, 230, 255),
			message = "A cold current is flowing! Grown coral can turn Frosted (x3).",
		},
		{
			id = "Night", name = "Bioluminescent Night", weight = 15, duration = 75,
			color = Color3.fromRGB(120, 255, 220),
			message = "Bioluminescent Night! Glowing is 3x as likely when you plant, and grown coral can turn Shadow (x4).",
		},
		{
			id = "Frenzy", name = "Feeding Frenzy", weight = 15, duration = 60,
			color = Color3.fromRGB(255, 170, 90),
			message = "Feeding Frenzy! Fish come to your coral twice as fast.",
		},
		{
			id = "Treasure", name = "Treasure Storm", weight = 8, duration = 40,
			color = Color3.fromRGB(255, 205, 80),
			message = "Treasure Storm! Chests are sinking from the surface. Open them for shells and seeds!",
		},
		{
			id = "Whale", name = "Whale Pass", weight = 8, duration = 50,
			color = Color3.fromRGB(150, 190, 255),
			message = "A giant whale is passing overhead! Coral grows twice as fast while it's here.",
		},
		{
			id = "Volcano", name = "Volcano Vent", weight = 6, duration = 45,
			color = Color3.fromRGB(255, 120, 60),
			message = "A volcano vent is erupting! Lava rocks that hit your grown coral can turn it Molten (x6).",
		},
		{
			id = "Octopus", name = "Giant Octopus", weight = 6, duration = 60,
			color = Color3.fromRGB(220, 110, 200),
			message = "A Giant Octopus is attacking the plaza! Everyone tap it to drive it off. Everyone who helps wins a prize!",
		},
		{
			id = "Merchant", name = "Mermaid Merchant", weight = 6, duration = 90,
			color = Color3.fromRGB(120, 230, 210),
			message = "Marina the Mermaid Merchant is in the plaza with rare seeds! She leaves soon.",
		},
		{
			id = "Hunt", name = "Sunken Treasure Hunt", weight = 6, duration = 120,
			color = Color3.fromRGB(255, 215, 120),
			message = "A treasure chest is buried somewhere in the lagoon! Follow the clues and dig it up first.",
		},
		{
			-- 20 s to hide, a 30 s hunt, 5 s for the orcas to leave (see Shipwreck below).
			id = "Shipwreck", name = "Shipwreck", weight = 5, duration = 55,
			color = Color3.fromRGB(255, 110, 100),
			message = "A giant ship is sinking into the Sunken Ruins, and orcas are following it! Press Ruins, swim inside the wreck and hide before they arrive!",
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

-- Volcano Vent: a volcano rises out past the lagoon and throws lava rocks onto every reef's
-- grown coral. A rock that hits turns its coral Molten with `moltenChance`.
ReefConfig.Volcano = {
	vent = Vector3.new(170, 0, -300), -- north-east, out past the lagoon's rim
	height = 70,
	every = 2.5, -- seconds between volleys; each volley throws one rock at each reef
	rockSpeed = 110, -- studs per second along the arc
	moltenChance = 0.6,
	riseSeconds = 6,
}

-- Giant Octopus: it hovers over the plaza; everyone taps it. Beat it before the event ends
-- and everyone who hit it `minHits` times wins shells (x their coral slots / 10) and seeds.
ReefConfig.Octopus = {
	hover = Vector3.new(0, 24, 0), -- above the plaza centre (ReefConfig.Lagoon.center)
	baseHealth = 120,
	healthPerPlayer = 90,
	hitsPerSecond = 4, -- the most taps a player can land each second
	clickRange = 70,
	minHits = 5,
	shells = 1500,
	seeds = { { id = "anemone", count = 2 }, { id = "clam", count = 1 } },
	starChance = 0.2, -- chance each winner also gets a Starlight Coral seed
}

export type MerchantOffer = { id: string, seed: string, count: number, price: number, chance: number }

-- Mermaid Merchant: Marina sets up a stall in the plaza with `offersPerVisit` offers drawn
-- from this list (by chance). Each player can buy each offer once per visit.
ReefConfig.Merchant = {
	stall = Vector3.new(-20, 0, 18), -- from the plaza centre
	offersPerVisit = 3,
	offers = {
		{ id = "anemone3", seed = "anemone", count = 3, price = 1400, chance = 1 },
		{ id = "clam2", seed = "clam", count = 2, price = 4200, chance = 1 },
		{ id = "star1", seed = "star", count = 1, price = 9000, chance = 0.8 },
		{ id = "star2", seed = "star", count = 2, price = 17000, chance = 0.35 },
		{ id = "seagrass1", seed = "seagrass", count = 1, price = 350000, chance = 0.15 },
	} :: { MerchantOffer },
}
ReefConfig.MerchantOfferById = {} :: { [string]: MerchantOffer }
for _, offer in ReefConfig.Merchant.offers do
	ReefConfig.MerchantOfferById[offer.id] = offer
end

-- Sunken Treasure Hunt: one chest is buried on open seabed in the lagoon. A first clue at the
-- start names a landmark and a direction; a closer clue comes at `secondClueAt`. Everyone's
-- HUD shows how hot they are. The first to dig it up wins.
ReefConfig.Hunt = {
	secondClueAt = 45, -- seconds into the hunt
	digSeconds = 2,
	digRange = 9,
	heat = { burning = 15, hot = 40, warm = 90 }, -- studs from the chest
	shells = 4000, -- x the digger's coral slots / 10
	seeds = { { id = "star", count = 1 }, { id = "clam", count = 2 } },
	seagrassChance = 0.1,
	clearOfBuildings = 50, -- studs from any lagoon building's centre (the Lab dome is 36 across its radius)
	rimFallback = 180, -- lagoon edge if ReefConfig.Lagoon.rimRadius isn't set
}

-- A compass word for a direction on the seabed ("north-east"). North is -Z.
function ReefConfig.compass(dx: number, dz: number): string
	local names = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }
	local angle = math.deg(math.atan2(dx, -dz)) % 360
	return names[math.floor((angle + 22.5) / 45) % 8 + 1]
end

-- How close to the buried chest a distance is.
function ReefConfig.huntHeat(distance: number): string
	local heat = ReefConfig.Hunt.heat
	return if distance < heat.burning then "Burning hot!" elseif distance < heat.hot then "Hot" elseif distance < heat.warm then "Warm" else "Cold"
end

-- The Shipwreck event: a liner sinks into the Wreck Basin in the Sunken Ruins, then a pod of
-- orcas hunts everyone who isn't hiding inside it. Everyone who was there when the hunt
-- began and didn't get eaten wins the reward seed.
ReefConfig.Shipwreck = {
	landing = Vector3.new(420, 0, -85), -- the Sunken Ruins' Wreck Basin (RuinsConfig.Places.basin)
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
	-- Wild fish at the Main Reef's fish nurseries: anyone can catch them.
	wild = { perSpot = 2, interval = 15, value = 12, roam = 9 }, -- value x fish multiplier
	kinds = {
		{ id = "Minnow", weight = 60, multiplier = 1, color = Color3.fromRGB(180, 200, 220), creature = "minnow" },
		{ id = "Striped Tang", weight = 28, multiplier = 2, color = Color3.fromRGB(60, 120, 255), creature = "stripedTang" },
		{ id = "Pufferfish", weight = 10, multiplier = 4, color = Color3.fromRGB(240, 200, 90), creature = "pufferfish" },
		{ id = "Moonfish", weight = 2, multiplier = 10, color = Color3.fromRGB(230, 230, 255), creature = "moonfish" },
		-- Kelp Forest fish (KelpConfig.FISH_IDS): never on the reefs, only in the forest.
		{ id = "Garibaldi", weight = 0, kelpWeight = 40, multiplier = 2, color = Color3.fromRGB(255, 130, 40), creature = "garibaldi" },
		{ id = "Kelp Bass", weight = 0, kelpWeight = 30, multiplier = 2, color = Color3.fromRGB(120, 110, 70), creature = "kelpBass" },
		{ id = "Opaleye", weight = 0, kelpWeight = 18, multiplier = 3, color = Color3.fromRGB(80, 140, 120), creature = "opaleye" },
		{ id = "Sheephead", weight = 0, kelpWeight = 9, multiplier = 6, color = Color3.fromRGB(230, 110, 130), creature = "sheephead" },
		{ id = "Giant Sea Bass", weight = 0, kelpWeight = 3, multiplier = 15, color = Color3.fromRGB(70, 80, 100), creature = "giantSeaBass" },
	} :: { FishDef },
}

ReefConfig.SAVE_INTERVAL = 90
ReefConfig.LEADERBOARD_REFRESH = 60
ReefConfig.INTERACT_DISTANCE = 20 -- studs from a shop or sell stand

-- Shopkeepers, keyed by the stand's prompt Kind. The animal ones are built by the server
-- (ShopkeeperVisuals) and animated by each client; the human crew (ReefConfig.Crew) are R15
-- NPCs the server walks about (Crew). Each client shows their greetings on approach.
ReefConfig.SHOPKEEPER_TAG = "Shopkeeper"
ReefConfig.SHOPKEEPER_GREET_DISTANCE = 22 -- studs
ReefConfig.SHOPKEEPER_GREET_COOLDOWN = 20 -- seconds before the same shopkeeper greets again
ReefConfig.Shopkeepers = {
	-- Coralie, the Shopkeeper from the character roster, at the Coral Market's seed counter.
	SeedShop = {
		name = "Coralie",
		bob = 0.25,
		greetings = {
			"Welcome, diver! Fresh seeds, straight from the deep.",
			"New here? Bubble Kelp grows in 20 seconds.",
			"Rare seeds sell out fast. Come back after a restock!",
			"Swim Fins make you faster, and a bigger Oxygen Tank lets you dive longer.",
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
	-- Captain Mako, the Master Diver, at the Equipment Station: gear, and your diving suit.
	Supplies = {
		name = "Captain Mako",
		bob = 0.15,
		greetings = {
			"Ahoy! Need better gear? Every good dive starts here.",
			"A bigger Oxygen Tank lets you stay down in the deep for longer.",
			"Swim Fins make you faster. Very handy round the Abyss!",
			"Fancy a new look? Press F by me to change your diving suit.",
			"A Bigger Bag holds more coral between trips to Pinch.",
		},
	},
	-- Dr. Pearl, the Research Scientist, at the Research Laboratory's counter.
	Lab = {
		name = "Dr. Pearl",
		bob = 0.15,
		greetings = {
			"Welcome to the lab! Every species you find helps the reef.",
			"Research a new species and the whole ocean gets healthier.",
			"Fascinating... your reef's health is looking up!",
			"New planters, faster growth: talk to me at the counter.",
		},
	},
	-- Kai, the Guide NPC by the spawn. Talking to him (the Guide prompt on the rock beside him)
	-- gives the tutorial lines in ReefConfig.Tutorial instead; these are for walking past.
	Guide = {
		name = "Kai",
		bob = 0.2,
		greetings = {
			"Hi there! I'm Kai, your guide. Press E to talk to me!",
			"Welcome to the Starter Lagoon! Talk to me if you're lost.",
			"Psst! Talk to me for the next step.",
		},
	},
	-- Otto the sea otter, the Kelp Forest's ranger (KelpWorld). Talking opens his journal of
	-- challenges (KelpPanel); these are for walking past.
	Otto = {
		name = "Otto",
		bob = 0.2,
		greetings = {
			"Welcome to the Kelp Forest! It's a whole different world from the reefs.",
			"The seagrass meadows need help. Replant a patch or two?",
			"Shh... the turtles are nesting. Guide a hatchling to the sea!",
			"Some paths here are hidden. Look for glowing pebbles.",
		},
	},
	-- Marlo, the Explorer NPC at the Sunken Ruins entrance (one of the Crew). Talking to him
	-- (the rock beside him) opens the Explorer's Journal; these are for walking past.
	Explorer = {
		name = "Marlo",
		bob = 0.18,
		greetings = {
			"Ahoy, diver! Welcome to the Sunken Ruins. Talk to me for a mission!",
			"Chests down here refill every 20 minutes. Go and look!",
			"Six relics, four rare creatures... can you find them all?",
			"Ghost Coral grows in the cave. It grows nowhere else in the sea!",
		},
	},
	-- Lumi the lanternfish, who sells abyssal coral at the bottom of the Abyss (AbyssWorld).
	Abyss = {
		name = "Lumi",
		bob = 0.3,
		greetings = {
			"Ooh, a visitor! Abyssal coral, the brightest seeds in the sea!",
			"Void Bloom sells for two million shells. Worth every one!",
			"Have you seen the Ghost Shark? It glides right over the pit.",
			"Mind the dark, diver. Follow the glow!",
		},
	},
} :: { [string]: ShopkeeperDef }

-- The human crew from the character roster (1-npc-character.png): R15 NPCs dressed by
-- Outfits and walked about by Crew, keyed by their shopkeeper Kind (ReefConfig.Shopkeepers
-- has their names and lines). ShopkeeperVisuals builds no animal model for these kinds.
--   station/mode  the counter prompt they stand behind (Guide and Explorer stand by a rock)
--   wander        how far (studs) they stroll from their post when nobody needs them
export type CrewDef = {
	name: string,
	outfit: string,
	skin: string, -- Outfits.SKIN key
	station: string?,
	mode: string?,
	wander: number,
	restMin: number?,
	restMax: number?,
	walkSpeed: number?,
	prompt: { kind: string, action: string }?, -- a prompt on the NPC itself
}
ReefConfig.Crew = {
	SeedShop = { name = "Coralie", outfit = "shopkeeper", skin = "Coralie", station = "SeedShop", wander = 9 },
	Guide = { name = "Kai", outfit = "guide", skin = "Kai", wander = 8, restMin = 10, restMax = 18 },
	Supplies = {
		name = "Captain Mako", outfit = "masterdiver", skin = "Mako", station = "Supplies", mode = "equipment", wander = 9,
		prompt = { kind = "SuitPicker", action = "Change diving suit" },
	},
	Lab = { name = "Dr. Pearl", outfit = "scientist", skin = "Pearl", station = "Lab", wander = 14 },
	Explorer = { name = "Marlo", outfit = "explorer", skin = "Marlo", wander = 16, restMin = 6, restMax = 12, walkSpeed = 9 },
} :: { [string]: CrewDef }

-- The players' diving suits (Suits, Outfits): each player picks one, saved as data.suit.
-- Roblox doesn't tell games a player's gender, so it's the player's choice, not assumed.
export type SuitDef = { id: string, name: string, outfit: string, color: Color3 }
ReefConfig.Suits = {
	order = { "blue", "pink" },
	byId = {
		blue = { id = "blue", name = "Blue Explorer", outfit = "explorerBlue", color = Color3.fromRGB(40, 150, 255) },
		pink = { id = "pink", name = "Pink Explorer", outfit = "explorerPink", color = Color3.fromRGB(235, 70, 200) },
	} :: { [string]: SuitDef },
}

ReefConfig.CORAL_TAG = "Coral" -- every planted coral model, for the client's labels and preview

-- Ambient sea life (client-side and cosmetic) and where it, and the seabed decoration, roam.
ReefConfig.SeaLife = {
	area = { minX = -880, maxX = 620, minZ = -300, maxZ = 300 }, -- the Main Reef, the lagoon and the Ruins
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

-- Pearls to unlock the next planter, after `unlocked` planters.
function ReefConfig.expandPearls(unlocked: number): number
	return 1 + (unlocked - ReefConfig.STARTING_SLOTS) // 2
end

-- The round bed the planters stand on. The same size for every reef.
function ReefConfig.bedRadius(_unlocked: number?): number
	return ReefConfig.BED_RADIUS
end

-- The reef's whole mound, out to the fence (the fence stands just past this).
function ReefConfig.moundRadius(): number
	return ReefConfig.MOUND_RADIUS
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
	-- Planters (locked ones too) are for coral.
	for _, planter in ReefConfig.Planters do
		local dx, dz = planter.x - x, planter.z - z
		local gap = item.footprint + ReefConfig.PLANTER_RADIUS + 0.5
		if dx * dx + dz * dz < gap * gap then
			return "Too close to a planter."
		end
	end
	-- Keep the way in from the gate (at -Z) clear.
	if math.abs(x) < ReefConfig.FENCE_GATE_WIDTH / 2 + item.footprint and z < -(reach - 10) then
		return "Keep the gateway clear."
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

-- Why a coral can't be planted at (x, z) in the reef's frame, or nil if it can, plus the
-- planter it would go in. Shared so the client's preview agrees with the server, which makes
-- the real decision. `plants` is what's planted on the reef (each with its slot).
function ReefConfig.plantProblem(x: number, z: number, unlocked: number, plants: { [any]: { slot: number? } }): (string?, number?)
	local slot = ReefConfig.planterAt(x, z)
	if not slot then
		return "Tap one of the sand planters to plant.", nil
	end
	if slot > unlocked then
		return "That planter is locked. Unlock more at the Research Laboratory.", slot
	end
	for _, plant in plants do
		if plant.slot == slot then
			return "That planter already has coral in it.", slot
		end
	end
	return nil, slot
end

-- Every coral grows through three stages, by how far along it is (0 to 1):
--   1 Seedling       a few thin sprouts poking out of the planter's sand
--   2 Growing        the coral itself, small, filling out as it grows
--   3 Fully grown    full size, with polyps round its foot and bubbles rising: ready to harvest
ReefConfig.SEEDLING_UNTIL = 0.35
ReefConfig.STAGE_NAMES = { "Seedling", "Growing", "Fully grown" }

function ReefConfig.growthStage(progress: number): number
	if progress >= 1 then
		return 3
	end
	return if progress < ReefConfig.SEEDLING_UNTIL then 1 else 2
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
	ghost = { title = "ghostdiver", decor = { id = "vent", count = 1 } },
	relic = { title = "relickeeper", decor = { id = "statue", count = 1 } },
	glowcap = { decor = { id = "lantern", count = 3 } },
	lumen = { title = "deepglow", decor = { id = "vent", count = 1 } },
	voidbloom = { title = "voidwalker", pet = { species = "octopus", golden = true } },
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
