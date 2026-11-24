--!nonstrict
-- Loads, repairs, saves and syncs each player's reef. One record per player:
--   key "Player_<UserId>" -> { data = Data, lock = { owner, at }? }
-- The lock is a session lease so two servers never write over each other
-- (see skills/other-engines/roblox-datastores/references/sessions-and-limits.md).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local RuinsConfig = require(ReplicatedStorage.Shared.RuinsConfig)
local AbyssConfig = require(ReplicatedStorage.Shared.AbyssConfig)
local KelpConfig = require(ReplicatedStorage.Shared.KelpConfig)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- A planted coral. x and z are studs from the plot centre.
-- mutation is a mutation key: "None", "Golden" or "Glowing+Golden" (ReefConfig.mutationParts).
-- slot is the planter (ReefConfig.Planters); x and z are that planter's offsets, kept for the
-- code that only needs the position.
export type Plant = { seed: string, plantedAt: number, mutation: string, slot: number, x: number, z: number }

export type Pet = { species: string, golden: boolean }

-- What the player has found, by Reef Index entry, and the sets already paid out.
export type IndexBook = { coral: { [string]: true }, fish: { [string]: true }, sets: { [string]: true } }

-- Today's three daily quests (ReefConfig.dailyQuests(day)): progress and claims by position.
export type QuestBook = { day: number, progress: { number }, claimed: { boolean } }

export type Data = {
	version: number,
	shells: number,
	pearls: number, -- collected in the Main Reef; unlocking planters costs some
	seeds: { [string]: number },
	inventory: { [string]: number },
	plants: { [string]: Plant }, -- keyed by plant id
	plantSeq: number, -- the last plant id handed out
	unlocked: number, -- coral slots
	totalEarned: number,
	harvested: number,
	fishCaught: number,
	index: IndexBook,
	pets: { [string]: Pet }, -- keyed by pet id
	petSeq: number, -- the last pet id handed out
	equipped: { string }, -- pet ids, at most ReefConfig.Pets.maxEquipped
	fences: { [string]: true }, -- fence styles owned (the default one always is)
	fence: string, -- the style round your reef
	decorStorage: { [string]: number }, -- decorations owned but not placed, by item id
	decor: { [string]: ReefConfig.PlacedDecor }, -- placed decorations, keyed by decor id
	decorSeq: number, -- the last decor id handed out
	gear: { [string]: number }, -- gear upgrade levels
	quests: QuestBook,
	rebirths: number,
	titles: { [string]: true }, -- titles earned
	title: string, -- the title shown over your head, "" for none
	likes: number, -- likes other players gave your reef
	liked: { [string]: number }, -- reefs you liked (owner user id) and the day you did
	indexRewarded: { [string]: true }, -- Reef Index sets whose IndexRewards were given
	tutorial: number, -- the Starter Lagoon step you're on; past the last step = finished
	ruins: RuinsConfig.State, -- Sunken Ruins: missions, chests, cuttings, relics, sightings
	abyss: AbyssConfig.State, -- the Abyss: unlocked, deep-sea creatures spotted
	suit: string, -- the diving suit picked (ReefConfig.Suits), "" until the player picks one
	kelp: KelpConfig.State, -- the Kelp Forest: places found, hatchlings, seagrass, challenges
	research: { [string]: true }, -- coral species researched at the lab (ReefConfig.Research)
	ownedPasses: { [string]: true }, -- Store game passes owned (ReefConfig.Store keys), re-checked on join
	receipts: { [string]: number }, -- recent developer product purchase ids → when granted (Monetization)
}

export type Profile = {
	data: Data,
	persist: boolean, -- false when DataStores are unavailable (Studio without API access)
	selected: string?, -- seed chosen in the hotbar; not saved
}

local STORE_NAME = "GrowAReef_PlayerData_v1"
local SESSION_ID = HttpService:GenerateGUID(false) -- game.JobId is "" in Studio
local LEASE_SECONDS = 300
local CLAIM_ATTEMPTS = 5

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStores unavailable, progress will not save:", result)
	end
end

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}

local PlayerData = {}

local function defaultData(): Data
	return {
		version = ReefConfig.DATA_VERSION,
		shells = ReefConfig.STARTING_SHELLS,
		pearls = 0,
		seeds = table.clone(ReefConfig.STARTING_SEEDS),
		inventory = {},
		plants = {},
		plantSeq = 0,
		unlocked = ReefConfig.STARTING_SLOTS,
		totalEarned = 0,
		harvested = 0,
		fishCaught = 0,
		index = { coral = {}, fish = {}, sets = {} },
		pets = {},
		petSeq = 0,
		equipped = {},
		fences = { [ReefConfig.DEFAULT_FENCE] = true },
		fence = ReefConfig.DEFAULT_FENCE,
		decorStorage = {},
		decor = {},
		decorSeq = 0,
		gear = {},
		quests = { day = ReefConfig.dayNumber(os.time()), progress = {}, claimed = {} },
		rebirths = 0,
		titles = {},
		title = "",
		likes = 0,
		liked = {},
		indexRewarded = {},
		tutorial = 1,
		ruins = RuinsConfig.newState(),
		abyss = AbyssConfig.newState(),
		suit = "",
		kelp = KelpConfig.newState(),
		research = {},
		ownedPasses = {},
		receipts = {},
	}
end

-- Starts a new day's quests when the saved ones are from an earlier day. Every slot is filled
-- in: a remote cuts an array short at its first gap, so the client would lose later quests.
function PlayerData.freshQuests(data: Data): QuestBook
	local today = ReefConfig.dayNumber(os.time())
	if data.quests.day ~= today then
		data.quests = { day = today, progress = {}, claimed = {} }
	end
	for slot = 1, ReefConfig.Quests.perDay do
		data.quests.progress[slot] = data.quests.progress[slot] or 0
		data.quests.claimed[slot] = data.quests.claimed[slot] or false
	end
	return data.quests
end

-- Copies the keys of a saved set that pass `valid`, as a fresh { [key]: true }.
local function cleanKeySet(raw: any, valid: (string) -> boolean): { [string]: true }
	local clean = {}
	if type(raw) == "table" then
		for key, value in raw do
			if type(key) == "string" and value == true and valid(key) then
				clean[key] = true
			end
		end
	end
	return clean
end

-- Repairs anything malformed instead of erroring, so old or edited saves still load.
local function sanitize(raw: any): Data
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end
	data.shells = EconomyMath.sanitizeAmount(raw.shells)
	data.pearls = math.min(EconomyMath.sanitizeAmount(raw.pearls), 1e6)
	data.totalEarned = EconomyMath.sanitizeAmount(raw.totalEarned)
	data.harvested = EconomyMath.sanitizeAmount(raw.harvested)
	data.fishCaught = EconomyMath.sanitizeAmount(raw.fishCaught)
	local savedSlots = EconomyMath.sanitizeAmount(raw.unlocked)
	data.unlocked = math.clamp(savedSlots, ReefConfig.STARTING_SLOTS, ReefConfig.MAX_SLOTS)
	-- Before planters, reefs grew to 50 free-planting slots. Slots past the planter limit are
	-- paid back at what they cost then (200 shells x 1.2 per slot past 10).
	for slot = ReefConfig.MAX_SLOTS, math.min(savedSlots, 50) - 1 do
		data.shells += math.floor(200 * 1.2 ^ (slot - 10))
	end
	data.plantSeq = math.min(EconomyMath.sanitizeAmount(raw.plantSeq), 1e6)

	data.seeds = {}
	if type(raw.seeds) == "table" then
		for seedId, count in raw.seeds do
			if type(seedId) == "string" and ReefConfig.Seeds[seedId] then
				local clean = EconomyMath.sanitizeLevel(count, ReefConfig.MAX_SEEDS_PER_TYPE)
				if clean > 0 then
					data.seeds[seedId] = clean
				end
			end
		end
	end

	if type(raw.inventory) == "table" then
		for key, count in raw.inventory do
			if type(key) == "string" then
				local seedId, mutationId = ReefConfig.splitInventoryKey(key)
				if seedId and mutationId and ReefConfig.Seeds[seedId] and ReefConfig.isMutationKey(mutationId) then
					local clean = EconomyMath.sanitizeAmount(count)
					if clean > 0 then
						data.inventory[key] = clean
					end
				end
			end
		end
	end

	local now = os.time()
	-- Each coral goes in its saved planter; coral from before planters (or a clash) goes in the
	-- nearest free unlocked one. With no planter left, its seed goes back in the seed bag.
	local taken: { [number]: boolean } = {}
	local function freePlanterNear(x: number, z: number): number?
		local best, bestDistance = nil, math.huge
		for slot = 1, data.unlocked do
			local planter = ReefConfig.Planters[slot]
			local distance = (planter.x - x) ^ 2 + (planter.z - z) ^ 2
			if not taken[slot] and distance < bestDistance then
				best, bestDistance = slot, distance
			end
		end
		return best
	end
	local function addPlant(key: any, saved: any, x: any, z: any)
		if
			type(saved) ~= "table"
			or type(saved.seed) ~= "string"
			or not ReefConfig.Seeds[saved.seed]
			or type(saved.mutation) ~= "string"
			or not ReefConfig.isMutationKey(saved.mutation)
		then
			return
		end
		local slot = saved.slot
		if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > data.unlocked or taken[slot] then
			local fromX = if type(x) == "number" and x == x then x else 0
			local fromZ = if type(z) == "number" and z == z then z else 0
			slot = freePlanterNear(fromX, fromZ)
		end
		if not slot then
			data.seeds[saved.seed] = math.min(ReefConfig.MAX_SEEDS_PER_TYPE, (data.seeds[saved.seed] or 0) + 1)
			return
		end
		taken[slot] = true
		local plantedAt = EconomyMath.sanitizeAmount(saved.plantedAt)
		-- A planted time in the future (clock skew, edited data) counts as now.
		if plantedAt == 0 or plantedAt > now then
			plantedAt = now
		end
		-- Keep the saved id when it is a usable whole number; otherwise hand out a new one.
		local id = tonumber(key)
		if not id or id ~= math.floor(id) or id < 1 or id > 1e6 or data.plants[tostring(id)] then
			id = data.plantSeq + 1
		end
		data.plantSeq = math.max(data.plantSeq, id)
		local planter = ReefConfig.Planters[slot]
		data.plants[tostring(id)] =
			{ seed = saved.seed, plantedAt = plantedAt, mutation = saved.mutation, slot = slot, x = planter.x, z = planter.z }
	end

	if type(raw.plants) == "table" then
		for key, plant in raw.plants do
			if type(plant) == "table" then
				addPlant(key, plant, plant.x, plant.z)
			end
		end
	elseif type(raw.tiles) == "table" then
		-- Version 1 saves used a 4 x 3 grid of 8-stud tiles. Keep the same layout, pulled in
		-- a little so every coral lands inside the starting bed and stays 5.6 studs apart.
		for key, tile in raw.tiles do
			local index = tonumber(key)
			if index and index == math.floor(index) and index >= 1 and index <= 12 then
				local column = (index - 1) % 4 + 1
				local row = (index - 1) // 4 + 1
				addPlant(index, tile, (column - 2.5) * 8 * 0.7, (row - 2) * 8 * 0.7)
			end
		end
	end

	local index = if type(raw.index) == "table" then raw.index else {}
	data.index.coral = cleanKeySet(index.coral, function(key)
		local seedId, mutationKey = ReefConfig.splitInventoryKey(key)
		return seedId ~= nil and ReefConfig.Seeds[seedId] ~= nil and ReefConfig.isMutationKey(mutationKey)
	end)
	local fishKinds = {}
	for _, kind in ReefConfig.Fish.kinds do
		fishKinds[kind.id] = true
	end
	data.index.fish = cleanKeySet(index.fish, function(id)
		return fishKinds[id] == true
	end)
	local setIds = {}
	for _, set in ReefConfig.IndexSets do
		setIds[set.id] = true
	end
	data.index.sets = cleanKeySet(index.sets, function(id)
		return setIds[id] == true
	end)

	data.petSeq = math.min(EconomyMath.sanitizeAmount(raw.petSeq), 1e6)
	local petCount = 0
	if type(raw.pets) == "table" then
		for key, pet in raw.pets do
			local id = tonumber(key)
			if
				petCount < ReefConfig.Pets.maxOwned
				and id
				and id == math.floor(id)
				and id >= 1
				and id <= 1e6
				and type(pet) == "table"
				and type(pet.species) == "string"
				and ReefConfig.Pets.species[pet.species]
			then
				data.pets[tostring(id)] = { species = pet.species, golden = pet.golden == true }
				data.petSeq = math.max(data.petSeq, id)
				petCount += 1
			end
		end
	end
	if type(raw.equipped) == "table" then
		for _, petId in raw.equipped do
			if
				#data.equipped < ReefConfig.Pets.maxEquipped
				and type(petId) == "string"
				and data.pets[petId]
				and not table.find(data.equipped, petId)
			then
				table.insert(data.equipped, petId)
			end
		end
	end

	-- Fences: the default is always owned; equipped must be owned.
	data.fences = cleanKeySet(raw.fences, function(id)
		return ReefConfig.FenceById[id] ~= nil
	end)
	data.fences[ReefConfig.DEFAULT_FENCE] = true
	data.fence = if type(raw.fence) == "string" and data.fences[raw.fence] then raw.fence else ReefConfig.DEFAULT_FENCE

	-- Decorations: placed ones must still fit where they are (a later rule change or edited
	-- data sends the rest back to storage), and no kind can exceed maxOwned in total.
	local owned: { [string]: number } = {}
	data.decorSeq = math.min(EconomyMath.sanitizeAmount(raw.decorSeq), 1e6)
	if type(raw.decor) == "table" then
		for key, placed in raw.decor do
			local id = tonumber(key)
			if
				id
				and id == math.floor(id)
				and id >= 1
				and id <= 1e6
				and type(placed) == "table"
				and type(placed.item) == "string"
				and ReefConfig.DecorById[placed.item]
				and type(placed.x) == "number"
				and type(placed.z) == "number"
				and (owned[placed.item] or 0) < ReefConfig.Decor.maxOwned
			then
				owned[placed.item] = (owned[placed.item] or 0) + 1
				if ReefConfig.decorProblem(placed.item, placed.x, placed.z, {}, data.decor) == nil then
					data.decor[tostring(id)] = { item = placed.item, x = placed.x, z = placed.z }
					data.decorSeq = math.max(data.decorSeq, id)
				else
					data.decorStorage[placed.item] = (data.decorStorage[placed.item] or 0) + 1
				end
			end
		end
	end
	if type(raw.decorStorage) == "table" then
		for itemId, count in raw.decorStorage do
			if type(itemId) == "string" and ReefConfig.DecorById[itemId] then
				local room = ReefConfig.Decor.maxOwned - (owned[itemId] or 0)
				local clean = math.min(EconomyMath.sanitizeAmount(count), room)
				if clean > 0 then
					owned[itemId] = (owned[itemId] or 0) + clean
					data.decorStorage[itemId] = (data.decorStorage[itemId] or 0) + clean
				end
			end
		end
	end
	-- (decorProblem above keeps every decoration off the planters, so none sits on coral.)

	if type(raw.gear) == "table" then
		for _, gearId in ReefConfig.GEAR_ORDER do
			local level = EconomyMath.sanitizeLevel(raw.gear[gearId], #ReefConfig.Gear[gearId].costs)
			if level > 0 then
				data.gear[gearId] = level
			end
		end
	end

	local quests = if type(raw.quests) == "table" then raw.quests else {}
	if type(quests.day) == "number" and quests.day == math.floor(quests.day) then
		data.quests.day = quests.day
		for i = 1, ReefConfig.Quests.perDay do
			data.quests.progress[i] = math.min(EconomyMath.sanitizeAmount(type(quests.progress) == "table" and quests.progress[i]), 1e9)
			data.quests.claimed[i] = type(quests.claimed) == "table" and quests.claimed[i] == true
		end
	end

	data.rebirths = EconomyMath.sanitizeLevel(raw.rebirths, ReefConfig.Rebirth.maxRebirths)
	data.titles = cleanKeySet(raw.titles, function(id)
		return ReefConfig.TitleById[id] ~= nil
	end)
	if data.rebirths > 0 then
		data.titles.reborn = true
	end
	data.title = if type(raw.title) == "string" and data.titles[raw.title] then raw.title else ""
	data.likes = EconomyMath.sanitizeAmount(raw.likes)
	if type(raw.liked) == "table" then
		local kept = 0
		for ownerId, day in raw.liked do
			if kept < ReefConfig.Likes.maxRemembered and type(ownerId) == "string" and tonumber(ownerId) and type(day) == "number" then
				data.liked[ownerId] = day
				kept += 1
			end
		end
	end
	data.indexRewarded = cleanKeySet(raw.indexRewarded, function(id)
		return ReefConfig.IndexRewards[id] ~= nil
	end)
	-- Store: passes are a cache (Monetization re-checks them with Roblox on join); receipts
	-- keep only the most recent purchase ids, so the save can't grow forever.
	data.ownedPasses = cleanKeySet(raw.ownedPasses, function(key)
		return ReefConfig.StorePassByKey[key] ~= nil
	end)
	if type(raw.receipts) == "table" then
		local recent = {}
		for purchaseId, at in raw.receipts do
			if type(purchaseId) == "string" and #purchaseId <= 64 and type(at) == "number" and at == at then
				table.insert(recent, { id = purchaseId, at = at })
			end
		end
		table.sort(recent, function(a, b)
			return a.at > b.at
		end)
		for i = 1, math.min(#recent, ReefConfig.Store.receiptsKept) do
			data.receipts[recent[i].id] = recent[i].at
		end
	end
	-- Saves from before the tutorial: anyone who has already grown or earned something has
	-- played, so they skip it.
	local finished = #ReefConfig.Tutorial.steps + 1
	if type(raw.tutorial) == "number" and raw.tutorial == raw.tutorial then
		data.tutorial = math.clamp(math.floor(raw.tutorial), 1, finished)
	elseif data.totalEarned > 0 or data.harvested > 0 or next(data.plants) ~= nil then
		data.tutorial = finished
	end
	data.ruins = RuinsConfig.sanitize(raw.ruins)
	data.abyss = AbyssConfig.sanitize(raw.abyss)
	data.suit = if type(raw.suit) == "string" and ReefConfig.Suits.byId[raw.suit] then raw.suit else ""
	data.kelp = KelpConfig.sanitize(raw.kelp)
	-- Researched species. Saves from before research keep every species the player has already
	-- grown (Reef Index), planted, or has seeds of, so nobody loses anything they could buy.
	data.research = cleanKeySet(raw.research, function(id)
		return ReefConfig.Research.costs[id] ~= nil
	end)
	if type(raw.research) ~= "table" then
		for _, seedId in ReefConfig.Research.order do
			if ReefConfig.Research.costs[seedId] then
				local known = (data.seeds[seedId] or 0) > 0
				for key in data.index.coral do
					known = known or ReefConfig.splitInventoryKey(key) == seedId
				end
				for _, plant in data.plants do
					known = known or plant.seed == seedId
				end
				if known then
					data.research[seedId] = true
				end
			end
		end
	end

	return data
end

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

-- Stamps this server as the owner of the key. Returns (ok, claimed, rawData).
-- ok = false means the request itself failed; claimed = false means another live server owns it.
local function claim(key: string): (boolean, boolean, any)
	assert(store, "store")
	local claimed, loaded = false, nil
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(record)
			claimed = false -- the callback can run more than once
			record = if type(record) == "table" then record else {}
			local lock = record.lock
			local now = os.time()
			if
				type(lock) == "table"
				and lock.owner ~= SESSION_ID
				and type(lock.at) == "number"
				and now - lock.at < LEASE_SECONDS
			then
				return nil -- someone else owns it: cancel the write
			end
			record.lock = { owner = SESSION_ID, at = now }
			claimed, loaded = true, record.data
			return record
		end)
	end)
	if not ok then
		warn("[PlayerData] claim failed", key, err)
	end
	return ok, claimed, loaded
end

local function write(key: string, snapshot: Data, release: boolean): boolean
	if not store then
		return false
	end
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(record)
			if type(record) ~= "table" or type(record.lock) ~= "table" or record.lock.owner ~= SESSION_ID then
				return nil -- lost ownership: never write a stale snapshot
			end
			record.data = snapshot
			record.lock = if release then nil else { owner = SESSION_ID, at = os.time() }
			return record
		end)
	end)
	if not ok then
		warn("[PlayerData] save failed", key, err)
	end
	return ok
end

local function createLeaderstats(player: Player, data: Data)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local shells = Instance.new("NumberValue")
	shells.Name = "Shells"
	shells.Value = data.shells
	shells.Parent = stats
	local harvested = Instance.new("IntValue")
	harvested.Name = "Harvested"
	harvested.Value = data.harvested
	harvested.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.rebirths
	rebirths.Parent = stats
	stats.Parent = player
end

local function onPlayerAdded(player: Player)
	local key = keyFor(player)
	local data: Data
	local persist = false

	if store then
		local loadedOk, claimed, raw = false, false, nil
		for attempt = 1, CLAIM_ATTEMPTS do
			loadedOk, claimed, raw = claim(key)
			if loadedOk and claimed then
				break
			end
			if not loadedOk and RunService:IsStudio() then
				break -- usually "Enable Studio Access to API Services" is off; don't make testers wait
			end
			if not player.Parent then
				return
			end
			task.wait(2 ^ math.min(attempt, 3))
		end

		if loadedOk and claimed then
			data = sanitize(raw)
			persist = true
		elseif RunService:IsStudio() then
			warn("[PlayerData] Studio without DataStore access: using an unsaved session")
			data = defaultData()
		else
			player:Kick("Your reef is still saving on another server. Please rejoin in a minute.")
			return
		end
	else
		data = defaultData()
	end

	if not player.Parent then
		-- Left while loading: hand the lock back without changing anything.
		if persist then
			write(key, data, true)
		end
		return
	end

	local profile: Profile = { data = data, persist = persist, selected = nil }
	profiles[player] = profile
	createLeaderstats(player, data)
	player:SetAttribute("DataLoaded", true)

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
	PlayerData.sync(player)
end

function PlayerData.save(player: Player, release: boolean): boolean
	local profile = profiles[player]
	if not profile or not profile.persist then
		return false
	end
	return write(keyFor(player), deepCopy(profile.data), release)
end

function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

function PlayerData.all(): { [Player]: Profile }
	return profiles
end

function PlayerData.onLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

function PlayerData.addShells(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or amount <= 0 then
		return
	end
	local clean = math.floor(amount)
	profile.data.shells += clean
	profile.data.totalEarned += clean
end

-- What selling coral and catching fish pay on top of their value: the rebirth bonus, doubled
-- with the 2x Shells game pass.
function PlayerData.saleMultiplier(data: Data): number
	local passBonus = if data.ownedPasses.doubleShells then ReefConfig.Store.doubleShells else 1
	return ReefConfig.shellMultiplier(data.rebirths) * passBonus
end

-- What the bag sells for, bonuses included.
local function inventoryValue(data: Data): number
	local total = 0
	for key, count in data.inventory do
		local seedId, mutationId = ReefConfig.splitInventoryKey(key)
		if seedId and mutationId then
			total += ReefConfig.harvestValue(seedId, mutationId) * count
		end
	end
	return math.floor(total * PlayerData.saleMultiplier(data))
end
PlayerData.inventoryValue = inventoryValue

-- Coral in the bag, and how much it holds.
function PlayerData.bagCount(data: Data): number
	local count = 0
	for _, amount in data.inventory do
		count += amount
	end
	return count
end

function PlayerData.bagCapacity(data: Data): number
	local passBonus = if data.ownedPasses.vipBag then ReefConfig.Store.vipBagBonus else 0
	return ReefConfig.bagCapacity(data.gear.bag or 0) + passBonus
end

-- Placed decorations by item id.
local function placedCounts(data: Data): { [string]: number }
	local placed = {}
	for _, decor in data.decor do
		placed[decor.item] = (placed[decor.item] or 0) + 1
	end
	return placed
end
PlayerData.placedCounts = placedCounts

-- Pushes this player's private state to their client and refreshes leaderstats.
function PlayerData.sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.data
	local planted = 0
	for _ in data.plants do
		planted += 1
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local shells = stats:FindFirstChild("Shells") :: NumberValue?
		local harvested = stats:FindFirstChild("Harvested") :: IntValue?
		if shells then
			shells.Value = data.shells
		end
		if harvested then
			harvested.Value = data.harvested
		end
		local rebirths = stats:FindFirstChild("Rebirths") :: IntValue?
		if rebirths then
			rebirths.Value = data.rebirths
		end
	end
	-- Public: every client's NameTags draws the title and rebirths over this player's head.
	player:SetAttribute("Title", data.title)
	player:SetAttribute("Rebirths", data.rebirths)
	local quests = PlayerData.freshQuests(data)
	Remotes.DataSync:FireClient(player, {
		shells = data.shells,
		pearls = data.pearls,
		seeds = data.seeds,
		inventory = data.inventory,
		inventoryValue = inventoryValue(data),
		unlocked = data.unlocked,
		planted = planted,
		expandCost = if data.unlocked < ReefConfig.MAX_SLOTS then ReefConfig.expandCost(data.unlocked) else nil,
		expandPearls = if data.unlocked < ReefConfig.MAX_SLOTS then ReefConfig.expandPearls(data.unlocked) else nil,
		selected = profile.selected,
		fishCaught = data.fishCaught,
		index = data.index,
		pets = data.pets,
		equipped = data.equipped,
		bagCount = PlayerData.bagCount(data),
		bagCapacity = PlayerData.bagCapacity(data),
		fences = data.fences,
		fence = data.fence,
		decorStorage = data.decorStorage,
		decorPlaced = placedCounts(data),
		gear = data.gear,
		quests = quests,
		rebirths = data.rebirths,
		rebirthCost = ReefConfig.rebirthCost(data.rebirths),
		titles = data.titles,
		title = data.title,
		likes = data.likes,
		ownedPasses = data.ownedPasses,
		tutorial = data.tutorial,
		ruins = data.ruins,
		abyss = data.abyss,
		suit = data.suit,
		kelp = data.kelp,
		research = data.research,
		harvested = data.harvested, -- Reef Health, for the Abyss's unlock
	})
end

function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if profiles[player] then
			PlayerData.save(player, true)
			profiles[player] = nil
		end
	end)

	-- Periodic save that also refreshes the lease.
	task.spawn(function()
		while true do
			task.wait(ReefConfig.SAVE_INTERVAL)
			for player in profiles do
				task.spawn(PlayerData.save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				PlayerData.save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait()
		end
	end)

	Remotes.RequestSync.OnServerEvent:Connect(function(player)
		if RateLimit.consume(player, 2) then
			PlayerData.sync(player)
		end
	end)
end

return PlayerData
