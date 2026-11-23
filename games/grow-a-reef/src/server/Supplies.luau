--!nonstrict
-- Upgrades and decorations, each bought at its own building in the hub:
--   Research Laboratory   ExpandReef (unlock the next planter: shells and pearls) and the
--                         Fertilizer ("coral growth" research)
--   Equipment Station     the Bubble Wand, Bigger Bag, Oxygen Tank and Swim Fins
--   Coral Market          fences and decorations
--   ExpandReef                        unlock the next planter (shells and pearls)
-- Remotes carry ids only; prices and limits come from ReefConfig.
--   BuyFence <id> / EquipFence <id>   buy a fence style (it goes up at once) or swap styles
--   BuyDecor <id> / PlaceDecor <id> <point>   buy a decoration, then place it on your reef
--   UpgradeGear <id>                  one level of a piece of gear (ReefConfig.GearStation says where)
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

-- Each building's counter, by role.
local stands: { [string]: BasePart } = {}
local BUILDING = { lab = "the Research Laboratory", equipment = "the Equipment Station", market = "the Coral Market" }

local function isNear(player: Player, role: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local stand = stands[role]
	return root ~= nil and stand ~= nil and (root.Position - stand.Position).Magnitude <= ReefConfig.INTERACT_DISTANCE
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

-- Unlocks the next planter on the player's reef, for shells and pearls.
local function onExpand(player: Player)
	if not RateLimit.consume(player, 2) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local data = profile.data
	if data.unlocked >= ReefConfig.MAX_SLOTS then
		Plots.notify(player, "Every planter on your reef is unlocked.")
		return
	end
	if not isNear(player, "lab") then
		Plots.notify(player, "Walk over to the Research Laboratory to unlock planters.")
		return
	end
	local price = ReefConfig.expandCost(data.unlocked)
	local pearls = ReefConfig.expandPearls(data.unlocked)
	if data.pearls < pearls then
		Plots.notify(player, `The next planter needs {pearls} pearl{if pearls == 1 then "" else "s"}. Find them in the Main Reef's caves and high places!`)
		return
	end
	if not pay(player, profile, price) then
		return
	end
	-- No yields between the checks above and these writes.
	data.pearls -= pearls
	data.unlocked += 1
	Plots.refresh(player)
	Plots.notify(player, `Planter unlocked! Your reef has {data.unlocked} planters now.`, "good")
	PlayerData.sync(player)
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
	if not isNear(player, "market") then
		Plots.notify(player, "Walk over to the Coral Market to buy fences.")
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
	if not isNear(player, "market") then
		Plots.notify(player, "Walk over to the Coral Market to buy decorations.")
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
	local role = ReefConfig.GearStation[gearId] or "equipment"
	if not isNear(player, role) then
		Plots.notify(player, `Walk over to {BUILDING[role]} for the {gear.name}.`)
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
	stands.lab = worldParts.labStand
	stands.equipment = worldParts.suppliesStand
	stands.market = worldParts.marketDecorStand
	Remotes.ExpandReef.OnServerEvent:Connect(onExpand)
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
