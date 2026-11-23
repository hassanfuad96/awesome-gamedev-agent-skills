--!nonstrict
-- The Kelp Forest (zone 4): a sunlit forest of giant kelp north of the lagoon, a different
-- ecosystem from the coral reefs. Shared by the server (KelpWorld builds it, Kelp runs it)
-- and the client (KelpLife animates it, KelpPanel shows Otto's challenges).
--   giant kelp groves      tall swaying kelp reaching for the surface, a sunlit clearing
--   hidden paths           faint glowing pebble trails into three hidden glades
--   sea turtle habitats    two of them, with nests where you guide hatchlings to the sea
--   seagrass restoration   two shared meadows; replant bare patches and they grow back
--   new fish               five kelp-forest species, caught only here (Reef Index too)
--   challenges             Otto the sea otter's eight exploration challenges
-- North is -Z. Every position is on the seabed (Y = 0) unless it says otherwise.

local KelpConfig = {}

KelpConfig.center = Vector3.new(-80, 0, -470)
KelpConfig.radius = 215 -- flat studs from the centre that count as "in the forest"
KelpConfig.entrance = Vector3.new(0, 0, -262) -- where the road from the plaza arrives
KelpConfig.CANOPY_Y = 68 -- swim this high in the forest to reach the kelp canopy
KelpConfig.REACH = 12 -- studs: how close you must be to plant or guide a hatchling

function KelpConfig.inForest(point: Vector3): boolean
	local dx, dz = point.X - KelpConfig.center.X, point.Z - KelpConfig.center.Z
	return dx * dx + dz * dz <= KelpConfig.radius * KelpConfig.radius
end

-- The main trail through the forest: from the entrance up to the sunlit clearing, then a
-- loop round the forest and back to the clearing.
KelpConfig.Trail = {
	Vector3.new(0, 0, -262),
	Vector3.new(-25, 0, -350),
	Vector3.new(-80, 0, -440),
	Vector3.new(-160, 0, -520),
	Vector3.new(-90, 0, -610),
	Vector3.new(15, 0, -545),
	Vector3.new(-80, 0, -440),
}
KelpConfig.clearing = { at = Vector3.new(-80, 0, -462), radius = 24 } -- the sunlit clearing

-- Hidden glades: walled in by dense kelp with one narrow gap, reached by a faint trail of
-- glowing pebbles that leaves the main trail at `from`. `gap` points from the glade's centre
-- to the opening in its wall.
export type Glade = { id: string, name: string, at: Vector3, radius: number, from: Vector3, gap: Vector3, hint: string }
KelpConfig.Glades = {
	{
		id = "statue",
		name = "Statue Glade",
		at = Vector3.new(-228, 0, -365),
		radius = 15,
		from = Vector3.new(-120, 0, -480),
		gap = Vector3.new(0.6, 0, -0.8).Unit,
		hint = "Glowing pebbles leave the trail west of the clearing.",
	},
	{
		id = "moonpool",
		name = "Moonpool Glade",
		at = Vector3.new(-120, 0, -648),
		radius = 15,
		from = Vector3.new(-115, 0, -590),
		gap = Vector3.new(0.2, 0, 1).Unit,
		hint = "Under the rocks at the north end of the trail.",
	},
	{
		id = "camp",
		name = "Diver's Camp",
		at = Vector3.new(105, 0, -470),
		radius = 15,
		from = Vector3.new(20, 0, -520),
		gap = Vector3.new(-1, 0, -0.3).Unit,
		hint = "Pebbles leave the trail east, near the turtle cove.",
	},
} :: { Glade }

-- Sea turtle habitats. Each has nests; holding the prompt at a nest guides a hatchling out
-- to sea (once per nest every `nestCooldown` seconds, per player).
export type Habitat = { id: string, name: string, at: Vector3, radius: number, nests: number }
KelpConfig.Habitats = {
	{ id = "cove", name = "Turtle Cove", at = Vector3.new(60, 0, -600), radius = 26, nests = 4 },
	{ id = "reef", name = "Turtle Reef", at = Vector3.new(-205, 0, -560), radius = 24, nests = 3 },
} :: { Habitat }
KelpConfig.nestCooldown = 600
KelpConfig.hatchlingShells = 60

-- Seagrass restoration: each meadow is a ring of bare patches anyone can replant. A planted
-- patch grows for `growSeconds`, stays lush for `lushSeconds`, then wilts back to bare.
-- The whole server shares the meadows; whoever plants a patch gets the reward.
export type Meadow = { id: string, name: string, at: Vector3, radius: number, patches: number }
KelpConfig.Meadows = {
	{ id = "east", name = "East Meadow", at = Vector3.new(45, 0, -405), radius = 15, patches = 10 },
	{ id = "west", name = "West Meadow", at = Vector3.new(-200, 0, -440), radius = 15, patches = 10 },
} :: { Meadow }
KelpConfig.Restoration = { growSeconds = 120, lushSeconds = 900, plantShells = 30 }

-- Patch `index` of a meadow, on a ring round its middle.
function KelpConfig.patchPoint(meadow: Meadow, index: number): Vector3
	local angle = (index / meadow.patches) * math.pi * 2
	return meadow.at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * meadow.radius * 0.7
end

-- Wild kelp fish gather at these spots (Fish spawns them). Spots by a meadow only have fish
-- while that meadow is at least half restored: healthy seagrass brings the fish back.
export type FishSpot = { at: Vector3, meadow: string? }
KelpConfig.FishSpots = {
	{ at = Vector3.new(45, 0, -405), meadow = "east" },
	{ at = Vector3.new(-200, 0, -440), meadow = "west" },
	{ at = Vector3.new(-80, 0, -462) }, -- the sunlit clearing
	{ at = Vector3.new(60, 0, -600) }, -- the turtle cove
} :: { FishSpot }

-- The kelp forest's fish. They live in ReefConfig.Fish.kinds too (weight 0, so reefs never
-- get them); kelpWeight is how often each turns up here.
KelpConfig.FISH_IDS = { "Garibaldi", "Kelp Bass", "Opaleye", "Sheephead", "Giant Sea Bass" }

-- Exploration challenges, in any order. Each finishes as soon as `done` is true (given the
-- player's kelp state and their Reef Index fish) and pays its reward once.
export type Reward = { shells: number, seeds: { [string]: number }?, title: string? }
export type Challenge = {
	id: string,
	title: string,
	hint: string,
	reward: Reward,
	done: (any, { [string]: true }) -> boolean,
}

local function count(set: { [string]: any }?): number
	local n = 0
	for _ in set or {} do
		n += 1
	end
	return n
end
KelpConfig.count = count

KelpConfig.Challenges = {
	{
		id = "reach",
		title = "Into the Kelp",
		hint = "Follow the sand road north from the plaza, between the dome and the Upgrade Station.",
		reward = { shells = 250 },
		done = function(s)
			return s.places.reach == true
		end,
	},
	{
		id = "canopy",
		title = "Canopy Climber",
		hint = "Swim up through the kelp until you reach its golden canopy.",
		reward = { shells = 500 },
		done = function(s)
			return s.places.canopy == true
		end,
	},
	{
		id = "turtles",
		title = "Turtle Friend",
		hint = "Visit both sea turtle habitats: Turtle Cove (north-east) and Turtle Reef (west).",
		reward = { shells = 600 },
		done = function(s)
			return s.places.cove == true and s.places.reef == true
		end,
	},
	{
		id = "hatchlings",
		title = "Hatchling Helper",
		hint = "Guide 3 hatchlings out to sea from the turtle nests.",
		reward = { shells = 900, seeds = { anemone = 1 } },
		done = function(s)
			return s.hatchlings >= 3
		end,
	},
	{
		id = "glade",
		title = "Off the Beaten Path",
		hint = "Follow a trail of glowing pebbles off the main trail to a hidden glade.",
		reward = { shells = 800 },
		done = function(s)
			return count(s.glades) >= 1
		end,
	},
	{
		id = "meadow",
		title = "Meadow Mender",
		hint = "Replant 10 bare seagrass patches in the meadows.",
		reward = { shells = 1500, seeds = { fan = 1 } },
		done = function(s)
			return s.restored >= 10
		end,
	},
	{
		id = "naturalist",
		title = "Kelp Naturalist",
		hint = "Catch all five kelp forest fish. Restored meadows bring them back.",
		reward = { shells = 3000, seeds = { clam = 1 } },
		done = function(_, fish)
			for _, id in KelpConfig.FISH_IDS do
				if not fish[id] then
					return false
				end
			end
			return true
		end,
	},
	{
		id = "glades",
		title = "Kelp Ranger",
		hint = "Find all three hidden glades. Otto's journal says where to look.",
		reward = { shells = 4000, seeds = { star = 1 }, title = "kelpranger" },
		done = function(s)
			return count(s.glades) >= #KelpConfig.Glades
		end,
	},
} :: { Challenge }

-- What each player has done in the forest.
export type State = {
	done: { [string]: boolean }, -- challenges finished (and paid)
	places: { [string]: boolean }, -- "reach", "canopy", "cove", "reef"
	glades: { [string]: boolean },
	nests: { [string]: number }, -- nest id -> os.time() a hatchling was last guided from it
	hatchlings: number,
	restored: number, -- seagrass patches planted, ever
}

function KelpConfig.newState(): State
	return { done = {}, places = {}, glades = {}, nests = {}, hatchlings = 0, restored = 0 }
end

-- Every nest id ("cove1", "reef3", ...).
KelpConfig.NEST_IDS = {} :: { [string]: boolean }
for _, habitat in KelpConfig.Habitats do
	for n = 1, habitat.nests do
		KelpConfig.NEST_IDS[habitat.id .. n] = true
	end
end

local function idSet(list: { { id: string } }): { [string]: boolean }
	local set = {}
	for _, item in list do
		set[item.id] = true
	end
	return set
end
local CHALLENGE_IDS = idSet(KelpConfig.Challenges)
local GLADE_IDS = idSet(KelpConfig.Glades)
local PLACE_IDS = { reach = true, canopy = true, cove = true, reef = true }

local function wholeNumber(value: any, max: number): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.min(math.floor(value), max)
end

-- Repairs a saved state instead of erroring: unknown ids and bad numbers are dropped.
function KelpConfig.sanitize(raw: any): State
	local state = KelpConfig.newState()
	if type(raw) ~= "table" then
		return state
	end
	local function flags(source: any, valid: { [string]: boolean }): { [string]: boolean }
		local clean = {}
		if type(source) == "table" then
			for key, value in source do
				if type(key) == "string" and valid[key] and value == true then
					clean[key] = true
				end
			end
		end
		return clean
	end
	state.done = flags(raw.done, CHALLENGE_IDS)
	state.places = flags(raw.places, PLACE_IDS)
	state.glades = flags(raw.glades, GLADE_IDS)
	if type(raw.nests) == "table" then
		for key, value in raw.nests do
			if type(key) == "string" and KelpConfig.NEST_IDS[key] and type(value) == "number" and value == value and value >= 0 then
				state.nests[key] = math.floor(value)
			end
		end
	end
	state.hatchlings = wholeNumber(raw.hatchlings, 1e9)
	state.restored = wholeNumber(raw.restored, 1e9)
	return state
end

-- Seconds until this player can guide another hatchling from the nest (0 = now).
function KelpConfig.nestWait(state: State, nestId: string, now: number): number
	local last = state.nests[nestId]
	return if last then math.max(0, last + KelpConfig.nestCooldown - now) else 0
end

-- Tags and attributes on the server-built pieces the client animates or reads.
KelpConfig.KELP_TAG = "GiantKelp" -- giant kelp models; the client sways them
KelpConfig.PATCH_TAG = "SeagrassPatch" -- attributes: Meadow, Index, State ("bare", "growing", "lush"), Progress

return KelpConfig
