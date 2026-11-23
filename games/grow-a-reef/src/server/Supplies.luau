--!nonstrict
-- Reef Supplies: fences, decorations and gear upgrades, bought at the Reef Supplies stand.
-- Remotes carry ids only; prices and limits come from ReefConfig.
--   BuyFence <id> / EquipFence <id>   buy a fence style (it goes up at once) or swap styles
--   BuyDecor <id> / PlaceDecor <id> <point>   buy a decoration, then place it on your reef
--   UpgradeGear <id>                  Fertilizer, Bubble Wand or Bigger Bag, one level a time
-- Fertilizer works here (every second counts as extra growth, like a seahorse); the Bubble
-- Wand and the bag size work in Plots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local World = require(script.Parent.World)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Quests = require(script.Parent.Quests)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Supplies = {}

local stand: BasePart

local function isNear(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - stand.Position).Magnitude <= ReefConfig.INTERACT_DISTANCE
end

-- Takes `price` shells if the player has them. No yields between the check and the write.
local function pay(player: Player, profile: PlayerData.Profile, price: number): boolean
	local wallet = { shells = profile.data.shells }
	if not EconomyMath.trySpend(wallet, { shells = price }) then
		Plots.notify(player, `That costs {EconomyMath.formatNumber(price)} shells.`)
		return false
	end
	profile.data.shells = wallet.shells
	return true
end

local function onBuyFence(player: Player, fenceId: unknown)
	if not RateLimit.consume(player, 2) or type(fenceId) ~= "string" then
		return
	end
	local fence = ReefConfig.FenceById[fenceId]
	local profile = PlayerData.get(player)
	if not fence or not profile or profile.data.fences[fenceId] then
		return
	end
	if fence.shop == false then
		Plots.notify(player, `The {fence.name} fence can't be bought. Complete its Reef Index set!`)
		return
	end
	if not isNear(player) then
		Plots.notify(player, "Walk over to Reef Supplies to buy fences.")
		return
	end
	if not pay(player, profile, fence.price) then
		return
	end
	profile.data.fences[fenceId] = true
	profile.data.fence = fenceId
	Plots.setFence(player)
	Plots.notify(player, `Your reef has a new {fence.name} fence!`, "good")
	PlayerData.sync(player)
end

local function onEquipFence(player: Player, fenceId: unknown)
	if not RateLimit.consume(player) or type(fenceId) ~= "string" then
		return
	end
	local profile = PlayerData.get(player)
	if not profile or not profile.data.fences[fenceId] or profile.data.fence == fenceId then
		return
	end
	profile.data.fence = fenceId
	Plots.setFence(player)
	PlayerData.sync(player)
end

local function onBuyDecor(player: Player, itemId: unknown)
	if not RateLimit.consume(player) or type(itemId) ~= "string" then
		return
	end
	local item = ReefConfig.DecorById[itemId]
	local profile = PlayerData.get(player)
	if not item or not profile then
		return
	end
	if not isNear(player) then
		Plots.notify(player, "Walk over to Reef Supplies to buy decorations.")
		return
	end
	local owned = (profile.data.decorStorage[itemId] or 0) + (PlayerData.placedCounts(profile.data)[itemId] or 0)
	if owned >= ReefConfig.Decor.maxOwned then
		Plots.notify(player, `You have {ReefConfig.Decor.maxOwned} of those, the most you can keep.`)
		return
	end
	if not pay(player, profile, item.price) then
		return
	end
	profile.data.decorStorage[itemId] = (profile.data.decorStorage[itemId] or 0) + 1
	local article = if string.find(item.name, "^[AEIOU]") then "an" else "a"
	Plots.notify(player, `Bought {article} {item.name}! Press Place, then tap your reef.`, "good")
	PlayerData.sync(player)
end

local function onPlaceDecor(player: Player, itemId: unknown, point: unknown)
	if not RateLimit.consume(player) or type(itemId) ~= "string" or typeof(point) ~= "Vector3" then
		return
	end
	if Plots.placeDecor(player, itemId, point :: Vector3) then
		Quests.progress(player, "decor", 1)
		PlayerData.sync(player)
	end
end

local function onUpgradeGear(player: Player, gearId: unknown)
	if not RateLimit.consume(player, 2) or type(gearId) ~= "string" then
		return
	end
	local gear = ReefConfig.Gear[gearId]
	local profile = PlayerData.get(player)
	if not gear or not profile then
		return
	end
	local level = profile.data.gear[gearId] or 0
	if level >= #gear.costs then
		Plots.notify(player, `Your {gear.name} is fully upgraded.`)
		return
	end
	if not isNear(player) then
		Plots.notify(player, "Walk over to Reef Supplies to upgrade your gear.")
		return
	end
	if not pay(player, profile, gear.costs[level + 1]) then
		return
	end
	profile.data.gear[gearId] = level + 1
	Plots.notify(player, `{gear.name} upgraded to level {level + 1}!`, "good")
	PlayerData.sync(player)
end

function Supplies.start(worldParts: World.WorldParts)
	stand = worldParts.suppliesStand
	Remotes.BuyFence.OnServerEvent:Connect(onBuyFence)
	Remotes.EquipFence.OnServerEvent:Connect(onEquipFence)
	Remotes.BuyDecor.OnServerEvent:Connect(onBuyDecor)
	Remotes.PlaceDecor.OnServerEvent:Connect(onPlaceDecor)
	Remotes.UpgradeGear.OnServerEvent:Connect(onUpgradeGear)

	-- Fertilizer: each second counts as extra seconds of growth for that player's coral.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local profile = PlayerData.get(player)
				local level = profile and profile.data.gear.fertilizer or 0
				if level > 0 then
					Plots.boostGrowth(ReefConfig.Gear.fertilizer.perLevel * level, player)
				end
			end
		end
	end)
end

return Supplies
