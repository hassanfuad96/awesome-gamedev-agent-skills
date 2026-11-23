--!nonstrict
-- Daily quests. Everyone gets the same ReefConfig.Quests.perDay quests each day (UTC), from
-- ReefConfig.dailyQuests. Other systems report what the player did with Quests.progress
-- (planting, harvesting, selling, fishing, hatching, decorating); finishing a quest tells
-- the player, and they claim the reward from the Quests window (ClaimQuest). Callers sync
-- the player afterwards, as they already do after the action itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local Tutorial = require(script.Parent.Tutorial)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Quests = {}

local function notify(player: Player, text: string, tone: string)
	Remotes.Notify:FireClient(player, text, tone)
end

local function questText(quest: ReefConfig.QuestDef): string
	return string.format(quest.text, quest.goal)
end

-- Counts `amount` towards every unfinished quest today of kind `questId`.
function Quests.progress(player: Player, questId: string, amount: number)
	local profile = PlayerData.get(player)
	if not profile or amount <= 0 then
		return
	end
	-- The Starter Lagoon tutorial listens to the same actions.
	Tutorial.progress(player, questId)
	local book = PlayerData.freshQuests(profile.data)
	for i, id in ReefConfig.dailyQuests(book.day) do
		local quest = ReefConfig.QuestById[id]
		local before = book.progress[i] or 0
		if id == questId and not book.claimed[i] and before < quest.goal then
			book.progress[i] = math.min(quest.goal, before + math.floor(amount))
			if book.progress[i] >= quest.goal then
				notify(player, `Quest complete: {questText(quest)}! Claim it in Quests.`, "rare")
			end
		end
	end
end

local function onClaim(player: Player, slot: unknown)
	if not RateLimit.consume(player) then
		return
	end
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > ReefConfig.Quests.perDay then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local data = profile.data
	local book = PlayerData.freshQuests(data)
	local quest = ReefConfig.QuestById[ReefConfig.dailyQuests(book.day)[slot]]
	if not quest or book.claimed[slot] or (book.progress[slot] or 0) < quest.goal then
		return
	end
	book.claimed[slot] = true
	local shells = ReefConfig.questShells(quest, data.unlocked)
	PlayerData.addShells(player, shells)
	local reward = `+{EconomyMath.formatNumber(shells)} shells`
	if quest.seed and ReefConfig.Seeds[quest.seed.id] then
		local owned = data.seeds[quest.seed.id] or 0
		data.seeds[quest.seed.id] = math.min(ReefConfig.MAX_SEEDS_PER_TYPE, owned + quest.seed.count)
		reward ..= ` and {quest.seed.count} {ReefConfig.Seeds[quest.seed.id].name} seed`
	end
	notify(player, `Quest reward: {reward}!`, "good")
	PlayerData.sync(player)
end

function Quests.start()
	Remotes.ClaimQuest.OnServerEvent:Connect(onClaim)
end

return Quests
