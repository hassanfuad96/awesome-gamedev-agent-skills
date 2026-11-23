--!nonstrict
-- The Reef Index: a collection book of every seed in every mutation combination and every
-- fish (ReefConfig.IndexSets). Harvesting and catching record entries here; completing a
-- set pays its shells once, and a badge too if ReefConfig.Index.badges names one. Callers
-- sync the player afterwards (harvest and catch already do).

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

return ReefIndex
