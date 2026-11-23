--!nonstrict
-- The Reef Index: a collection book of every seed in every mutation combination and every
-- fish (ReefConfig.IndexSets). Harvesting and catching record entries here; completing a
-- set pays its shells once, its ReefConfig.IndexRewards (a title, fence, decorations or a
-- pet), and a badge too if ReefConfig.Index.badges names one. Callers sync the player
-- afterwards (harvest and catch already do).

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ReefIndex = {}

local function notify(player: Player, text: string, tone: string)
	Remotes.Notify:FireClient(player, text, tone)
end

local function petCount(profile: PlayerData.Profile): number
	local n = 0
	for _ in profile.data.pets do
		n += 1
	end
	return n
end

-- Gives one completed set's IndexRewards (title, fence, decorations, pet), all at once and
-- only once. A pet reward waits while the player has no room for another pet.
local function grantReward(player: Player, profile: PlayerData.Profile, setId: string): boolean
	local data = profile.data
	local reward = ReefConfig.IndexRewards[setId]
	if not reward or data.indexRewarded[setId] then
		return false
	end
	if reward.pet and petCount(profile) >= ReefConfig.Pets.maxOwned then
		notify(player, `A Reef Index reward pet is waiting! Release a pet to make room, then rejoin.`, "bad")
		return false
	end
	data.indexRewarded[setId] = true
	if reward.title and ReefConfig.TitleById[reward.title] then
		data.titles[reward.title] = true
		if data.title == "" then
			data.title = reward.title
		end
	end
	if reward.fence and ReefConfig.FenceById[reward.fence] then
		data.fences[reward.fence] = true
	end
	if reward.decor and ReefConfig.DecorById[reward.decor.id] then
		local id = reward.decor.id
		local owned = (data.decorStorage[id] or 0) + (PlayerData.placedCounts(data)[id] or 0)
		local room = math.max(0, ReefConfig.Decor.maxOwned - owned)
		local given = math.min(room, reward.decor.count)
		if given > 0 then
			data.decorStorage[id] = (data.decorStorage[id] or 0) + given
		end
	end
	if reward.pet and ReefConfig.Pets.species[reward.pet.species] then
		data.petSeq += 1
		data.pets[tostring(data.petSeq)] = { species = reward.pet.species, golden = reward.pet.golden }
	end
	notify(player, `Reef Index reward: {ReefConfig.indexRewardText(setId)}!`, "rare")
	return true
end

-- Rewards for every completed set that hasn't had them yet. Returns true when any was given.
function ReefIndex.grantRewards(player: Player, profile: PlayerData.Profile): boolean
	local any = false
	for _, set in ReefConfig.IndexSets do
		if profile.data.index.sets[set.id] and grantReward(player, profile, set.id) then
			any = true
		end
	end
	return any
end

local function payCompletedSets(player: Player, profile: PlayerData.Profile)
	local book = profile.data.index
	for _, set in ReefConfig.IndexSets do
		if not book.sets[set.id] then
			local found = book[set.kind]
			local complete = true
			for _, entry in set.entries do
				if not found[entry] then
					complete = false
					break
				end
			end
			if complete then
				book.sets[set.id] = true
				PlayerData.addShells(player, set.reward)
				notify(player, `Reef Index set complete: {set.name}! +{EconomyMath.formatNumber(set.reward)} shells`, "rare")
				local badgeId = ReefConfig.Index.badges[set.id]
				if badgeId then
					task.spawn(function()
						local ok, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
						if not ok then
							warn("[ReefIndex] badge", badgeId, "not awarded:", err)
						end
					end)
				end
				grantReward(player, profile, set.id)
			end
		end
	end
end

local function discover(player: Player, profile: PlayerData.Profile, kind: string, entry: string, label: string)
	local found = profile.data.index[kind]
	if found[entry] then
		return
	end
	found[entry] = true
	notify(player, `New in your Reef Index: {label}!`, "good")
	payCompletedSets(player, profile)
end

function ReefIndex.discoverCoral(player: Player, profile: PlayerData.Profile, seedId: string, mutationKey: string)
	discover(player, profile, "coral", ReefConfig.inventoryKey(seedId, mutationKey), ReefConfig.displayName(seedId, mutationKey))
end

function ReefIndex.discoverFish(player: Player, profile: PlayerData.Profile, fishId: string)
	discover(player, profile, "fish", fishId, fishId)
end

-- Sets finished before their rewards existed (or while the pets were full) pay out on join.
function ReefIndex.start()
	PlayerData.onLoaded(function(player, profile)
		if ReefIndex.grantRewards(player, profile) then
			PlayerData.sync(player)
		end
	end)
end

return ReefIndex
