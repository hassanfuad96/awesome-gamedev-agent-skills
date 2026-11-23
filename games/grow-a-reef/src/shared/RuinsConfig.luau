--!nonstrict
-- The Sunken Ruins: the exploration zone east of the Starter Lagoon, where the Shipwreck
-- event's liner sinks. Shared by the server (RuinsWorld builds it, Ruins runs it) and the
-- client (RuinsPanel, RuinsLife). Every number and place in the zone is here.
--
-- The zone sits east of the plaza, at the end of a sand road. Its layout is written in the
-- zone's own frame (RuinsConfig.frame), where +X points back west to the lagoon. Walking in
-- from the entrance (heading east), "left" is the frame's +Z and "right" its -Z:
--   entrance   two broken pillars, Marlo the explorer, and a whirlpool back to the shops
--   middle     the sand road runs on in under a ruined archway
--   left       the Wreck Basin, open sand where the Shipwreck liner comes down
--   right      a raised stone terrace up a flight of steps: the temple (with its sanctum),
--              the mermaid statue, and one lone column taller than the rest
--   right-near a sunken pirate ship, bow up on a rock, holed so you can swim in
--   far end    the underwater cave, dark inside and lit by crystals
--   far left   the coral garden: a treasure trove, a giant anchor and a ship's wheel
-- Players find treasure chests (refill per player), hidden coral (one cutting a day),
-- six relics (once each) and four rare creatures (spotted once each). Exploration missions
-- lead them round all of it.

local RuinsConfig = {}

RuinsConfig.center = Vector3.new(430, 0, 0) -- east of the lagoon, at the end of the east road
RuinsConfig.radius = 175 -- flat studs from the centre that count as "in the ruins"
-- Turned half round, so the frame's +X (the entrance) faces west, back to the lagoon.
RuinsConfig.frame = CFrame.new(RuinsConfig.center) * CFrame.Angles(0, math.pi, 0)
-- The sand road from just outside the lagoon to the entrance, along world z = 0.
RuinsConfig.roadFromX = 190

-- A point in the zone's frame, in world space.
function RuinsConfig.at(x: number, y: number, z: number): Vector3
	return RuinsConfig.frame:PointToWorldSpace(Vector3.new(x, y, z))
end
local at = RuinsConfig.at

RuinsConfig.TERRACE_TOP = 10 -- the temple terrace's floor height

RuinsConfig.Places = {
	entrance = at(150, 0, 0), -- the two pillars and the "SUNKEN RUINS" plaque
	explorer = at(128, 0, -16), -- Marlo the seal, who gives the missions
	pad = at(128, 0, 14), -- whirlpool back to the shops; you land here teleporting in
	archway = at(60, 0, 0), -- a ruined arch over the path in
	basin = at(10, 0, 85), -- the Wreck Basin: the Shipwreck liner lands here
	terrace = at(-65, 0, -80), -- the terrace's middle, on the seabed
	temple = at(-65, 10, -90),
	statue = at(-32, 10, -56),
	tallColumn = at(-104, 10, -50),
	garden = at(-75, 0, 25),
	cave = at(-140, 0, 40),
}

-- The terrace: a stone block (x, z extents in the zone frame) with steps down its south face.
RuinsConfig.Terrace = { minX = -122, maxX = -8, minZ = -122, maxZ = -40, stepsX = -65, stepsWidth = 20 }

-- The pirate ship lies bow-up on a rock: keel at the frame's origin, bow towards local +X.
RuinsConfig.Ship = {
	length = 70,
	width = 18,
	height = 14,
	frame = RuinsConfig.frame * CFrame.new(75, 3, -75) * CFrame.Angles(0, math.rad(25), 0) * CFrame.Angles(0, 0, math.rad(8)) * CFrame.Angles(math.rad(12), 0, 0),
}

-- The cave: a hollow hill with one tunnel in from the east.
RuinsConfig.Cave = { radius = 18, height = 14, tunnelLength = 18, tunnelWidth = 10, tunnelHeight = 9 }

-- A point in the ship's frame, in world space.
function RuinsConfig.shipPoint(x: number, y: number, z: number): Vector3
	return RuinsConfig.Ship.frame:PointToWorldSpace(Vector3.new(x, y, z))
end

function RuinsConfig.inRuins(point: Vector3): boolean
	local d = (point - RuinsConfig.center) * Vector3.new(1, 0, 1)
	return d.Magnitude < RuinsConfig.radius
end

function RuinsConfig.inCave(point: Vector3): boolean
	local c = RuinsConfig.Places.cave
	local d = (point - c) * Vector3.new(1, 0, 1)
	return d.Magnitude < RuinsConfig.Cave.radius and point.Y < RuinsConfig.Cave.height
end

function RuinsConfig.aboardShip(point: Vector3): boolean
	local s = RuinsConfig.Ship
	local p = s.frame:PointToObjectSpace(point)
	return math.abs(p.X) < s.length / 2 - 2 and p.Y > 0 and p.Y < s.height and math.abs(p.Z) < s.width / 2 - 1
end

-- How close (studs) a player must be to open, pick up or take a cutting. A little more than
-- the prompts' reach, since the server checks it again.
RuinsConfig.REACH = 14

-- Treasure chests. Each player can open each one once every `cooldown` seconds. `at` is the
-- ground under the chest.
RuinsConfig.Chests = {
	cooldown = 20 * 60,
	-- Scaled with your reef like daily quests (ReefConfig.questShells): x1 to x3.
	shells = { min = 120, max = 450 },
	seedChance = 0.4, -- otherwise shells
	seeds = {
		{ id = "brain", weight = 30, count = 3 },
		{ id = "fan", weight = 28, count = 2 },
		{ id = "anemone", weight = 20, count = 1 },
		{ id = "clam", weight = 12, count = 1 },
		{ id = "star", weight = 6, count = 1 },
		{ id = "ghost", weight = 4, count = 1 },
	},
	spots = {
		{ id = "gate", name = "Gate Chest", at = at(141, 0, 24) },
		{ id = "basin", name = "Basin Chest", at = at(-40, 0, 122) },
		{ id = "garden", name = "Trove Chest", at = at(-108, 0, 12) },
		{ id = "sanctum", name = "Sanctum Chest", at = at(-72, 12, -95) },
		{ id = "statue", name = "Statue Chest", at = at(-18, 10, -66) },
		{ id = "ship", name = "Ship's Hold Chest", at = RuinsConfig.shipPoint(8, 1, -4) },
		{ id = "cave", name = "Cave Chest", at = at(-130, 0, 52) },
		{ id = "arch", name = "Archtop Chest", at = at(60, 27, 0) },
	},
}

-- Hidden coral: rare species growing in the ruins. Take one cutting (a seed) from each spot
-- a day (UTC). `needsAllRelics`: the sanctum's Relic Coral only lets a diver who has found
-- every relic take a cutting.
RuinsConfig.HiddenCoral = {
	{ id = "cave1", seed = "ghost", at = at(-148, 0, 30) },
	{ id = "cave2", seed = "ghost", at = at(-152, 0, 50) },
	{ id = "sanctum", seed = "relic", at = at(-56, 12, -98), needsAllRelics = true },
}

-- Relics: six lost things, each picked up once, for good. `at` is where it rests.
RuinsConfig.Relics = {
	shells = 500, -- for each one found
	list = {
		{ id = "compass", name = "Golden Compass", hint = "In the pirate ship's hold.", at = RuinsConfig.shipPoint(-14, 1, 4) },
		{ id = "crown", name = "Pearl Crown", hint = "Left at the mermaid statue's feet.", at = at(-34, 13, -53.5) },
		{ id = "tablet", name = "Stone Tablet", hint = "On the altar in the temple sanctum.", at = at(-65, 13.6, -97.5) },
		{ id = "bell", name = "Ship's Bell", hint = "Half buried by the ship's wheel in the coral garden.", at = at(-42, 0, 14) },
		{ id = "trident", name = "Crystal Trident", hint = "Deep inside the underwater cave.", at = at(-154, 1, 40) },
		{ id = "spyglass", name = "Old Spyglass", hint = "On top of the tallest column. Swim up!", at = at(-104, 36.6, -50) },
	},
}

-- Rare sea creatures. Each swims a fixed path that depends only on the server time, so the
-- server knows where every client sees it. Swim within `sight` studs to spot it.
export type CreatureDef = { id: string, name: string, hint: string, sight: number }
RuinsConfig.Creatures = {
	shells = 750, -- for each one spotted
	list = {
		{ id = "coelacanth", name = "Coelacanth", hint = "A living fossil that circles the temple.", sight = 24 },
		{ id = "angler", name = "Anglerfish", hint = "Follow the little light in the cave.", sight = 18 },
		{ id = "seadragon", name = "Leafy Sea Dragon", hint = "Drifts round the pirate ship.", sight = 20 },
		-- Only shows for `squidSeconds` of every `squidEvery`.
		{ id = "squid", name = "Giant Squid", hint = "Rises out of the Wreck Basin now and then.", sight = 40 },
	} :: { CreatureDef },
	squidEvery = 360,
	squidSeconds = 70,
}

local function loopPath(center: Vector3, rx: number, rz: number, bob: number, speed: number, phase: number, t: number): Vector3
	local a = t * speed / math.max(rx, rz) + phase
	return center + Vector3.new(math.sin(a) * rx, math.sin(a * 2) * bob, math.cos(a) * rz)
end

-- Where a creature is at server time `t`, or nil when it isn't out (the squid between visits).
function RuinsConfig.creaturePosition(id: string, t: number): Vector3?
	local P = RuinsConfig.Places
	if id == "coelacanth" then
		return loopPath(P.temple + Vector3.new(0, 8, 0), 36, 26, 2, 5, 0, t)
	elseif id == "angler" then
		return loopPath(P.cave + Vector3.new(0, 5, 0), 9, 9, 1.2, 3, 1, t)
	elseif id == "seadragon" then
		return loopPath(at(75, 7, -75), 48, 32, 2.5, 4, 2, t)
	elseif id == "squid" then
		local c = RuinsConfig.Creatures
		local into = t % c.squidEvery
		if into > c.squidSeconds then
			return nil
		end
		-- Rises out of the sand, circles high over the basin, then sinks back.
		local rise = math.clamp(math.min(into, c.squidSeconds - into) / 8, 0, 1)
		local p = loopPath(P.basin, 34, 26, 3, 9, 0, t)
		return Vector3.new(p.X, -30 + rise * 58, p.Z)
	end
	return nil
end

export type Reward = { shells: number, seeds: { [string]: number }?, title: string? }
export type Mission = {
	id: string,
	title: string,
	hint: string,
	marlo: string, -- what Marlo says while it's the current mission
	reward: Reward,
	target: Vector3?, -- where the tracker points
	done: (any) -> boolean, -- given the player's ruins state
}

local function count(set: { [string]: any }?): number
	local n = 0
	for _ in set or {} do
		n += 1
	end
	return n
end
RuinsConfig.count = count

-- Exploration missions, in order. Each finishes as soon as its `done` is true (so one
-- already done when it comes up finishes straight away) and pays its reward.
RuinsConfig.Missions = {
	{
		id = "reach",
		title = "Find the Sunken Ruins",
		hint = "Follow the sand road east from the plaza, or press Ruins on the right.",
		marlo = "Welcome, diver! These ruins are full of treasure. Stick with me!",
		reward = { shells = 200 },
		target = RuinsConfig.Places.entrance,
		done = function(s)
			return s.visited.reach == true
		end,
	},
	{
		id = "chest",
		title = "Open a treasure chest",
		hint = "There's one right by the entrance pillars. Chests refill every 20 minutes.",
		marlo = "See that chest by the pillars? Open it! There are eight hidden round the ruins.",
		reward = { shells = 400 },
		target = RuinsConfig.Chests.spots[1].at,
		done = function(s)
			return s.opened >= 1
		end,
	},
	{
		id = "relic",
		title = "Find a lost relic",
		hint = "A Ship's Bell lies by the old ship's wheel in the coral garden, left of the road.",
		marlo = "Six relics were lost down here. The bell by the ship's wheel is the easiest!",
		reward = { shells = 600, seeds = { fan = 1 } },
		target = RuinsConfig.Relics.list[4].at,
		done = function(s)
			return count(s.relics) >= 1
		end,
	},
	{
		id = "cave",
		title = "Explore the underwater cave",
		hint = "The cave is at the far end of the ruins. Swim in through the tunnel.",
		marlo = "The cave at the far end glows inside. Mind the Anglerfish!",
		reward = { shells = 800 },
		target = RuinsConfig.Places.cave,
		done = function(s)
			return s.visited.cave == true
		end,
	},
	{
		id = "coral",
		title = "Take a hidden coral cutting",
		hint = "Ghost Coral grows in the cave. Take a cutting: it's a seed you can plant!",
		marlo = "Ghost Coral grows nowhere else. Take a cutting, it regrows every day.",
		reward = { shells = 1000, seeds = { anemone = 1 } },
		target = RuinsConfig.HiddenCoral[1].at,
		done = function(s)
			return s.cut >= 1
		end,
	},
	{
		id = "creature",
		title = "Spot a rare sea creature",
		hint = "A Coelacanth circles the temple on the terrace. Swim close to it.",
		marlo = "Rare creatures live here. Get close to one and you'll spot it in your journal.",
		reward = { shells = 1500 },
		target = RuinsConfig.Places.temple,
		done = function(s)
			return count(s.sighted) >= 1
		end,
	},
	{
		id = "ship",
		title = "Board the pirate ship",
		hint = "Swim into the pirate ship through a hole in its side or a deck hatch.",
		marlo = "That old pirate ship has a full hold. Swim in through the holes!",
		reward = { shells = 2000, seeds = { clam = 1 } },
		target = RuinsConfig.shipPoint(0, 6, 0),
		done = function(s)
			return s.visited.ship == true
		end,
	},
	{
		id = "relics",
		title = "Find all six relics",
		hint = "Your Journal lists where each one is.",
		marlo = "Find all six relics and the sanctum's Relic Coral will let you take cuttings.",
		reward = { shells = 5000, seeds = { relic = 1 }, title = "ruinexplorer" },
		done = function(s)
			return count(s.relics) >= #RuinsConfig.Relics.list
		end,
	},
	{
		id = "creatures",
		title = "Spot all four rare creatures",
		hint = "The Giant Squid only rises out of the Wreck Basin now and then.",
		marlo = "Last one! The Giant Squid only comes up every few minutes. Keep watch!",
		reward = { shells = 8000, seeds = { relic = 1, ghost = 2 } },
		done = function(s)
			return count(s.sighted) >= #RuinsConfig.Creatures.list
		end,
	},
} :: { Mission }

RuinsConfig.doneLines = {
	"You've done it all! Chests refill every 20 minutes, and the coral regrows every day.",
	"The Giant Squid still comes up now and then. Beautiful, isn't it?",
	"When a giant ship sinks into the basin, hide inside it. The orcas can't reach you there!",
}

-- Tags and attributes on the server-built interactive spots, which the client reads to show
-- each player's own state (looted chests, found relics, cuttings taken).
RuinsConfig.SPOT_TAG = "RuinsSpot" -- attributes: Kind ("Chest", "Relic", "Coral") and Id

-- A fresh save: what each player has done in the ruins.
export type State = {
	mission: number, -- the current mission; past the last = all done
	visited: { [string]: boolean }, -- "reach", "cave", "ship"
	chests: { [string]: number }, -- chest id -> os.time() last opened
	opened: number, -- chests opened, ever
	cuttings: { [string]: number }, -- hidden coral spot id -> day number of the last cutting
	cut: number, -- cuttings taken, ever
	relics: { [string]: boolean },
	sighted: { [string]: boolean },
}

function RuinsConfig.newState(): State
	return { mission = 1, visited = {}, chests = {}, opened = 0, cuttings = {}, cut = 0, relics = {}, sighted = {} }
end

local function ids(list: { { id: string } }): { [string]: boolean }
	local set = {}
	for _, item in list do
		set[item.id] = true
	end
	return set
end
local CHEST_IDS = ids(RuinsConfig.Chests.spots)
local CORAL_IDS = ids(RuinsConfig.HiddenCoral)
local RELIC_IDS = ids(RuinsConfig.Relics.list)
local CREATURE_IDS = ids(RuinsConfig.Creatures.list)
local PLACE_IDS = { reach = true, cave = true, ship = true }

local function wholeNumber(value: any, max: number): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.min(math.floor(value), max)
end

-- Repairs a saved state instead of erroring: unknown ids and bad numbers are dropped.
function RuinsConfig.sanitize(raw: any): State
	local state = RuinsConfig.newState()
	if type(raw) ~= "table" then
		return state
	end
	state.mission = math.max(1, wholeNumber(raw.mission, #RuinsConfig.Missions + 1))
	state.opened = wholeNumber(raw.opened, 1e9)
	state.cut = wholeNumber(raw.cut, 1e9)
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
	local function stamps(source: any, valid: { [string]: boolean }): { [string]: number }
		local clean = {}
		if type(source) == "table" then
			for key, value in source do
				if type(key) == "string" and valid[key] and type(value) == "number" and value == value and value >= 0 then
					clean[key] = math.floor(value)
				end
			end
		end
		return clean
	end
	state.visited = flags(raw.visited, PLACE_IDS)
	state.relics = flags(raw.relics, RELIC_IDS)
	state.sighted = flags(raw.sighted, CREATURE_IDS)
	state.chests = stamps(raw.chests, CHEST_IDS)
	state.cuttings = stamps(raw.cuttings, CORAL_IDS)
	return state
end

-- Seconds until a chest refills for this player (0 when it's ready).
function RuinsConfig.chestWait(state: State, chestId: string, now: number): number
	local last = state.chests[chestId]
	if not last then
		return 0
	end
	return math.max(0, last + RuinsConfig.Chests.cooldown - now)
end

-- Why a cutting can't be taken from this spot today, or nil if it can.
function RuinsConfig.cuttingProblem(state: State, spot: { id: string, needsAllRelics: boolean? }, day: number): string?
	if state.cuttings[spot.id] == day then
		return "You've taken a cutting here today. It regrows tomorrow."
	end
	if spot.needsAllRelics and count(state.relics) < #RuinsConfig.Relics.list then
		return `The Relic Coral only trusts divers who found all {#RuinsConfig.Relics.list} relics.`
	end
	return nil
end

return RuinsConfig
