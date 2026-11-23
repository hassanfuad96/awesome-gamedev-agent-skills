--!nonstrict
-- The Abyss: zone 3, a dark, bioluminescent trench south of the Starter Lagoon (concept art
-- 3-athmosphere.jpg). Shared by the server (AbyssWorld builds it, Abyss runs it) and the client
-- (AbyssLife: the darkness, jellyfish and deep-sea creatures; AbyssPanel: Lumi's seed shop).
--
-- Layout, in world space (north is -Z, so the lagoon is north of it):
--   road     sand road south from the lagoon along x = 20, to the Pressure Gate on the shelf
--   shelf    a rocky rim at seabed height round the pit
--   ramp     a glowing ledge down the pit's north wall, from the top by the gate to the floor
--   pit      45 studs deep: glowing coral, giant mushrooms, crystal formations, the Crystal
--            Spire in the middle, and Lumi the lanternfish's seed stall by the ramp's foot
-- The zone is locked until a player reaches Exploration Level `unlock.exploration` (Sunken Ruins
-- missions done) or Reef Health `unlock.reefHealth` (coral harvested). The server turns locked
-- players back at the gate.

local AbyssConfig = {}

AbyssConfig.center = Vector3.new(20, 0, 650)
AbyssConfig.FLOOR = -45 -- the pit floor's height
AbyssConfig.Shelf = { minX = -200, maxX = 240, minZ = 450, maxZ = 850 } -- the whole zone
AbyssConfig.Pit = { minX = -100, maxX = 140, minZ = 530, maxZ = 770 }
AbyssConfig.roadX = 20
AbyssConfig.roadFromZ = 185 -- just outside the lagoon
AbyssConfig.gate = Vector3.new(20, 0, 495) -- the Pressure Gate, where locked players are turned back
-- The ramp down the north wall: from its top (on the shelf's edge) to the floor, `width` wide.
AbyssConfig.Ramp = { top = Vector3.new(10, 0, 537), bottom = Vector3.new(130, -45, 537), width = 14 }

local F = AbyssConfig.FLOOR
AbyssConfig.Places = {
	pad = Vector3.new(100, F, 568), -- whirlpool back to the shops; you land here teleporting in
	shop = Vector3.new(126, F, 590), -- Lumi's stall
	spire = Vector3.new(20, F, 660), -- the Crystal Spire
	brain = Vector3.new(-45, F, 705), -- the giant glowing brain coral
	mushrooms = Vector3.new(-60, F, 585), -- the mushroom forest
	jellies = Vector3.new(85, F, 720), -- the jellyfish garden
}

-- Air pockets on the pit floor: rising columns of bubbles where a diver's air refills (the
-- Oxygen module drains air below y = -15 in the pit, and refills it within these). One at
-- the whirlpool, where Go to Abyss lands you, one at Lumi's stall, one at the Crystal Spire.
export type AirPocket = { position: Vector3, radius: number }
AbyssConfig.AirPockets = {
	{ position = AbyssConfig.Places.pad, radius = 14 },
	{ position = AbyssConfig.Places.shop, radius = 14 },
	{ position = AbyssConfig.Places.spire, radius = 16 },
} :: { AirPocket }

function AbyssConfig.inAirPocket(point: Vector3): boolean
	for _, pocket in AbyssConfig.AirPockets do
		if (point - pocket.position).Magnitude <= pocket.radius then
			return true
		end
	end
	return false
end

-- Whether a point is anywhere in the zone (shelf or pit), and in the pit itself.
function AbyssConfig.inZone(point: Vector3): boolean
	local s = AbyssConfig.Shelf
	return point.X > s.minX and point.X < s.maxX and point.Z > s.minZ and point.Z < s.maxZ and point.Y < 120
end

function AbyssConfig.inPit(point: Vector3): boolean
	local p = AbyssConfig.Pit
	return point.X > p.minX and point.X < p.maxX and point.Z > p.minZ and point.Z < p.maxZ and point.Y < 4
end

-- How dark the sea is at a point, 0 (normal) to 1 (the pit floor). The shelf is a little
-- darker already; it deepens as you go down into the pit.
function AbyssConfig.darkness(point: Vector3): number
	if not AbyssConfig.inZone(point) then
		return 0
	end
	local p = AbyssConfig.Pit
	-- How far inside the pit's footprint (studs), so the edge fades instead of snapping.
	local inside = math.min(point.X - p.minX, p.maxX - point.X, point.Z - p.minZ, p.maxZ - point.Z)
	local over = math.clamp((inside + 20) / 40, 0, 1)
	-- Full darkness soon after the camera drops below the rim: a zoomed-out third-person
	-- camera floats 20-30 studs over the character, and should still see the deep.
	local depth = math.clamp((6 - point.Y) / 16, 0, 1)
	return 0.35 + 0.65 * over * math.max(depth, 0.35)
end

-- Who may go in. Either one opens the zone, for good.
AbyssConfig.Unlock = {
	exploration = 5, -- Exploration Level: Sunken Ruins missions completed
	reefHealth = 200, -- Reef Health: coral harvested, ever
}

-- Exploration Level and Reef Health for a player's saved data.
function AbyssConfig.levels(data: any): (number, number)
	local exploration = 0
	if type(data.ruins) == "table" and type(data.ruins.mission) == "number" then
		exploration = math.max(0, data.ruins.mission - 1)
	end
	return exploration, (if type(data.harvested) == "number" then data.harvested else 0)
end

function AbyssConfig.meetsUnlock(data: any): boolean
	local exploration, health = AbyssConfig.levels(data)
	return exploration >= AbyssConfig.Unlock.exploration or health >= AbyssConfig.Unlock.reefHealth
end

-- "Reach Exploration Level 5 (you're 2) or Reef Health 200 (you're 87)."
function AbyssConfig.lockedText(data: any): string
	local exploration, health = AbyssConfig.levels(data)
	local u = AbyssConfig.Unlock
	return `The Abyss is too deep for you yet. Reach Exploration Level {u.exploration} (Sunken Ruins missions, you're at {exploration}) or Reef Health {u.reefHealth} (coral harvested, you're at {math.min(health, u.reefHealth)}).`
end

-- Lumi's stall: the high-value abyssal coral, at fixed prices, as many as you can afford.
AbyssConfig.SHOP_SEEDS = { "glowcap", "lumen", "voidbloom" }
AbyssConfig.REACH = 16 -- studs from Lumi's counter to buy

-- Rare deep-sea creatures, spotted by swimming within `sight` studs. Like the ruins' creatures,
-- each path depends only on the server time.
export type CreatureDef = { id: string, name: string, hint: string, sight: number }
AbyssConfig.Creatures = {
	shells = 1500, -- for each first sighting
	-- Spotting all of them gives this too (once).
	allReward = { title = "abyssdiver", seed = "glowcap", count = 1 },
	list = {
		{ id = "ghostshark", name = "Ghost Shark", hint = "Patrols the whole pit, high up.", sight = 30 },
		{ id = "vampiresquid", name = "Vampire Squid", hint = "Hides close to the Crystal Spire.", sight = 20 },
		{ id = "gulper", name = "Gulper Eel", hint = "Sweeps low along the south wall.", sight = 22 },
		{ id = "dumbo", name = "Dumbo Octopus", hint = "Flaps round the mushroom forest.", sight = 18 },
	} :: { CreatureDef },
}

local function loopPath(center: Vector3, rx: number, rz: number, bob: number, speed: number, phase: number, t: number): Vector3
	local a = t * speed / math.max(rx, rz) + phase
	return center + Vector3.new(math.sin(a) * rx, math.sin(a * 2) * bob, math.cos(a) * rz)
end

function AbyssConfig.creaturePosition(id: string, t: number): Vector3?
	local P = AbyssConfig.Places
	if id == "ghostshark" then
		return loopPath(AbyssConfig.center + Vector3.new(0, F + 22, 0), 90, 80, 4, 11, 0, t)
	elseif id == "vampiresquid" then
		return loopPath(P.spire + Vector3.new(0, 14, 0), 22, 22, 3, 3.5, 1, t)
	elseif id == "gulper" then
		return loopPath(Vector3.new(20, F + 6, 745), 95, 14, 2, 7, 2, t)
	elseif id == "dumbo" then
		return loopPath(P.mushrooms + Vector3.new(0, 10, 0), 14, 12, 3, 2.5, 3, t)
	end
	return nil
end

-- The client's darkness, at full strength on the pit floor (AbyssLife blends towards it).
-- Tuned in Studio against the concept art: a gentle blue tint keeps the violet, cyan and
-- green glows apart; the deep navy comes from the haze, ambient light and the dark water
-- overhead instead, so the glow stays bright.
AbyssConfig.Look = {
	tint = Color3.fromRGB(165, 180, 255),
	brightness = -0.12,
	contrast = 0.3,
	saturation = 0.55,
	bloomIntensity = 0.6,
	bloomThreshold = 1,
	bloomSize = 18,
	-- Lighting and Atmosphere values at full darkness.
	atmosphereColor = Color3.fromRGB(14, 24, 60),
	atmosphereDecay = Color3.fromRGB(6, 10, 34),
	atmosphereDensity = 0.42,
	ambient = Color3.fromRGB(22, 30, 64),
	outdoorAmbient = Color3.fromRGB(28, 38, 78),
	brightnessLighting = 0.8,
	ceiling = Color3.fromRGB(16, 24, 64), -- the dark water overhead
	jellyfish = 22,
}

-- A player's saved Abyss state.
export type State = { unlocked: boolean, sighted: { [string]: boolean }, allRewarded: boolean }

function AbyssConfig.newState(): State
	return { unlocked = false, sighted = {}, allRewarded = false }
end

local CREATURE_IDS = {}
for _, creature in AbyssConfig.Creatures.list do
	CREATURE_IDS[creature.id] = true
end

-- Repairs a saved state instead of erroring.
function AbyssConfig.sanitize(raw: any): State
	local state = AbyssConfig.newState()
	if type(raw) ~= "table" then
		return state
	end
	state.unlocked = raw.unlocked == true
	state.allRewarded = raw.allRewarded == true
	if type(raw.sighted) == "table" then
		for id, value in raw.sighted do
			if type(id) == "string" and CREATURE_IDS[id] and value == true then
				state.sighted[id] = true
			end
		end
	end
	return state
end

return AbyssConfig
