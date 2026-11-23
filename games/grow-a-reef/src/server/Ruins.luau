--!nonstrict
-- The Sunken Ruins' gameplay (RuinsConfig; RuinsWorld builds the place). The server decides
-- everything here; prompts carry only a spot id, which is checked against the config and the
-- player's distance:
--   chests        open one for shells or seeds; each refills per player after a cooldown
--   relics        six to find, each picked up once, for good
--   hidden coral  one cutting (a seed of a species sold nowhere) per spot per day
--   sightings     swim close to a rare creature; its path depends only on the server time,
--                 so the server knows where every client sees it
--   places        reaching the ruins, the cave and the pirate ship's hold
--   missions      Marlo's exploration missions finish as soon as each is done, in order,
--                 and pay their rewards
-- Progress is saved in data.ruins (RuinsConfig.State) and synced with the rest of the data.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local RuinsConfig = require(ReplicatedStorage.Shared.RuinsConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Ruins = {}

local POLL = 0.5 -- seconds between checks of where everyone is
local rng = Random.new()

local chestById: { [string]: any } = {}
for _, spot in RuinsConfig.Chests.spots do
	chestById[spot.id] = spot
end
local coralById: { [string]: any } = {}
for _, spot in RuinsConfig.HiddenCoral do
	coralById[spot.id] = spot
end
local relicById: { [string]: any } = {}
for _, relic in RuinsConfig.Relics.list do
	relicById[relic.id] = relic
end

local function notify(player: Player, text: string, tone: string)
	Remotes.Notify:FireClient(player, text, tone)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function near(player: Player, point: Vector3): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - point).Magnitude <= RuinsConfig.REACH
end

local function stateOf(player: Player): (PlayerData.Profile?, RuinsConfig.State?)
	local profile = PlayerData.get(player)
	if not profile then
		return nil, nil
	end
	return profile, profile.data.ruins
end

-- Adds seeds (capped like every other seed gift) and returns "2 Sea Fan seeds, ..." for
-- what was actually given.
local function giveSeeds(data: PlayerData.Data, seeds: { [string]: number }): string?
	local parts = {}
	for _, seedId in ReefConfig.SEED_ORDER do
		local amount = seeds[seedId]
		local seed = ReefConfig.Seeds[seedId]
		if amount and seed then
			local owned = data.seeds[seedId] or 0
			local given = math.min(amount, ReefConfig.MAX_SEEDS_PER_TYPE - owned)
			if given > 0 then
				data.seeds[seedId] = owned + given
				table.insert(parts, `{given} {seed.name} seed{if given > 1 then "s" else ""}`)
			end
		end
	end
	return if #parts > 0 then table.concat(parts, ", ") else nil
end

-- Finishes every mission in a row that is already done, paying each reward. Returns true
-- when anything changed.
local function advance(player: Player, profile: PlayerData.Profile): boolean
	local data = profile.data
	local state = data.ruins
	local changed = false
	while true do
		local mission = RuinsConfig.Missions[state.mission]
		if not mission or not mission.done(state) then
			break
		end
		state.mission += 1
		changed = true
		local reward = mission.reward
		local parts = { `+{EconomyMath.formatNumber(reward.shells)} shells` }
		PlayerData.addShells(player, reward.shells)
		local seeds = reward.seeds and giveSeeds(data, reward.seeds)
		if seeds then
			table.insert(parts, seeds)
		end
		local title = reward.title and ReefConfig.TitleById[reward.title]
		if title then
			data.titles[title.id] = true
			if data.title == "" then
				data.title = title.id
			end
			table.insert(parts, `the "{title.text}" title`)
		end
		notify(player, `Mission complete: {mission.title}! {table.concat(parts, ", ")}`, "rare")
		local nextMission = RuinsConfig.Missions[state.mission]
		if nextMission then
			notify(player, `Next mission: {nextMission.title}`, "good")
		else
			notify(player, "Every exploration mission done! You're a true Ruin Explorer.", "rare")
		end
	end
	return changed
end

local function openChest(player: Player, chestId: unknown)
	local spot = type(chestId) == "string" and chestById[chestId]
	local profile, state = stateOf(player)
	if not spot or not profile or not state or not near(player, spot.at) then
		return
	end
	local now = os.time()
	local wait = RuinsConfig.chestWait(state, spot.id, now)
	if wait > 0 then
		notify(player, `You've emptied this chest. It refills in {math.ceil(wait / 60)} min.`, "info")
		return
	end
	state.chests[spot.id] = now
	state.opened += 1
	local settings = RuinsConfig.Chests
	local data = profile.data
	local text
	if rng:NextNumber() < settings.seedChance then
		local seedId = EconomyMath.pickWeighted(settings.seeds, rng:NextNumber())
		for _, entry in settings.seeds do
			if entry.id == seedId then
				text = giveSeeds(data, { [seedId] = entry.count })
			end
		end
	end
	if text then
		notify(player, `{spot.name}: {text}!`, "rare")
	else
		-- Scaled with your reef like daily quests: x1 at the starting planters, up to x3.
		local rolled = rng:NextInteger(settings.shells.min, settings.shells.max)
		local shells = ReefConfig.questShells({ shells = rolled } :: any, data.unlocked)
		PlayerData.addShells(player, shells)
		notify(player, `{spot.name}: +{EconomyMath.formatNumber(shells)} shells!`, "good")
	end
	advance(player, profile)
	PlayerData.sync(player)
end

local function pickUpRelic(player: Player, relicId: unknown)
	local relic = type(relicId) == "string" and relicById[relicId]
	local profile, state = stateOf(player)
	if not relic or not profile or not state or state.relics[relic.id] or not near(player, relic.at) then
		return
	end
	state.relics[relic.id] = true
	PlayerData.addShells(player, RuinsConfig.Relics.shells)
	local found = RuinsConfig.count(state.relics)
	notify(player, `Relic found: {relic.name}! ({found}/{#RuinsConfig.Relics.list}) +{EconomyMath.formatNumber(RuinsConfig.Relics.shells)} shells`, "rare")
	advance(player, profile)
	PlayerData.sync(player)
end

local function takeCutting(player: Player, spotId: unknown)
	local spot = type(spotId) == "string" and coralById[spotId]
	local profile, state = stateOf(player)
	if not spot or not profile or not state or not near(player, spot.at) then
		return
	end
	local day = ReefConfig.dayNumber(os.time())
	local problem = RuinsConfig.cuttingProblem(state, spot, day)
	if problem then
		notify(player, problem, "info")
		return
	end
	local given = giveSeeds(profile.data, { [spot.seed] = 1 })
	if not given then
		notify(player, "You can't carry any more of those seeds.", "bad")
		return
	end
	state.cuttings[spot.id] = day
	state.cut += 1
	notify(player, `You took a cutting: {given}! Plant it on your reef.`, "rare")
	advance(player, profile)
	PlayerData.sync(player)
end

-- Where everyone is: reaching places and spotting creatures.
local function poll()
	local now = Workspace:GetServerTimeNow()
	local creatures = {}
	for _, creature in RuinsConfig.Creatures.list do
		creatures[creature.id] = RuinsConfig.creaturePosition(creature.id, now)
	end
	for _, player in Players:GetPlayers() do
		local profile, state = stateOf(player)
		local root = rootOf(player)
		if profile and state and root and RuinsConfig.inRuins(root.Position) then
			local p = root.Position
			local changed = false
			local function visit(place: string, label: string)
				if not state.visited[place] then
					state.visited[place] = true
					changed = true
					notify(player, label, "good")
				end
			end
			visit("reach", "You found the Sunken Ruins! Talk to Marlo the explorer by the entrance.")
			if RuinsConfig.inCave(p) then
				visit("cave", "You're inside the underwater cave. Follow the glow!")
			end
			if RuinsConfig.aboardShip(p) then
				visit("ship", "You're aboard the old pirate ship!")
			end
			for _, creature in RuinsConfig.Creatures.list do
				local at = creatures[creature.id]
				if at and not state.sighted[creature.id] and (at - p).Magnitude <= creature.sight then
					state.sighted[creature.id] = true
					changed = true
					PlayerData.addShells(player, RuinsConfig.Creatures.shells)
					notify(player, `Rare creature spotted: {creature.name}! ({RuinsConfig.count(state.sighted)}/{#RuinsConfig.Creatures.list}) +{EconomyMath.formatNumber(RuinsConfig.Creatures.shells)} shells`, "rare")
				end
			end
			if changed then
				advance(player, profile)
				PlayerData.sync(player)
			end
		end
	end
end

function Ruins.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local kind = prompt:GetAttribute("Kind")
		if kind ~= "RuinsChest" and kind ~= "RuinsRelic" and kind ~= "RuinsCoral" then
			return
		end
		if not RateLimit.consume(player) then
			return
		end
		local id = prompt:GetAttribute("Id")
		if kind == "RuinsChest" then
			openChest(player, id)
		elseif kind == "RuinsRelic" then
			pickUpRelic(player, id)
		else
			takeCutting(player, id)
		end
	end)
	-- Missions that a save already satisfies (or that new rules made easier) finish on join.
	PlayerData.onLoaded(function(player, profile)
		if advance(player, profile) then
			PlayerData.sync(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(POLL)
			poll()
		end
	end)
end

return Ruins
