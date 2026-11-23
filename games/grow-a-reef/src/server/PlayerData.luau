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
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- A planted coral. x and z are studs from the plot centre.
export type Plant = { seed: string, plantedAt: number, mutation: string, x: number, z: number }

export type Data = {
	version: number,
	shells: number,
	seeds: { [string]: number },
	inventory: { [string]: number },
	plants: { [string]: Plant }, -- keyed by plant id
	plantSeq: number, -- the last plant id handed out
	unlocked: number, -- coral slots
	totalEarned: number,
	harvested: number,
	fishCaught: number,
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
		seeds = table.clone(ReefConfig.STARTING_SEEDS),
		inventory = {},
		plants = {},
		plantSeq = 0,
		unlocked = ReefConfig.STARTING_SLOTS,
		totalEarned = 0,
		harvested = 0,
		fishCaught = 0,
	}
end

-- Repairs anything malformed instead of erroring, so old or edited saves still load.
local function sanitize(raw: any): Data
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end
	data.shells = EconomyMath.sanitizeAmount(raw.shells)
	data.totalEarned = EconomyMath.sanitizeAmount(raw.totalEarned)
	data.harvested = EconomyMath.sanitizeAmount(raw.harvested)
	data.fishCaught = EconomyMath.sanitizeAmount(raw.fishCaught)
	data.unlocked = math.clamp(
		EconomyMath.sanitizeAmount(raw.unlocked),
		ReefConfig.STARTING_SLOTS,
		ReefConfig.MAX_SLOTS
	)
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
				if seedId and mutationId and ReefConfig.Seeds[seedId] and ReefConfig.MutationById[mutationId] then
					local clean = EconomyMath.sanitizeAmount(count)
					if clean > 0 then
						data.inventory[key] = clean
					end
				end
			end
		end
	end

	local now = os.time()
	local count = 0
	local bedRadius = ReefConfig.bedRadius(data.unlocked)
	local function addPlant(key: any, saved: any, x: any, z: any)
		if
			count >= data.unlocked
			or type(saved) ~= "table"
			or type(saved.seed) ~= "string"
			or not ReefConfig.Seeds[saved.seed]
			or type(saved.mutation) ~= "string"
			or not ReefConfig.MutationById[saved.mutation]
			or type(x) ~= "number"
			or type(z) ~= "number"
			or not (x * x + z * z <= bedRadius * bedRadius) -- also false for NaN
		then
			return
		end
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
		data.plants[tostring(id)] =
			{ seed = saved.seed, plantedAt = plantedAt, mutation = saved.mutation, x = x, z = z }
		count += 1
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

local function inventoryValue(data: Data): number
	local total = 0
	for key, count in data.inventory do
		local seedId, mutationId = ReefConfig.splitInventoryKey(key)
		if seedId and mutationId then
			total += ReefConfig.harvestValue(seedId, mutationId) * count
		end
	end
	return total
end
PlayerData.inventoryValue = inventoryValue

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
	end
	Remotes.DataSync:FireClient(player, {
		shells = data.shells,
		seeds = data.seeds,
		inventory = data.inventory,
		inventoryValue = inventoryValue(data),
		unlocked = data.unlocked,
		planted = planted,
		expandCost = if data.unlocked < ReefConfig.MAX_SLOTS then ReefConfig.expandCost(data.unlocked) else nil,
		selected = profile.selected,
		fishCaught = data.fishCaught,
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
