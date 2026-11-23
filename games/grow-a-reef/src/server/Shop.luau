--!nonstrict
-- The Coral Market (seed counter with a server-wide stock that restocks on a timer, and the
-- sell counter) and hotbar seed selection. Remotes carry ids only; prices come from
-- ReefConfig. (Planters and species research are at the Research Laboratory.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local World = require(script.Parent.World)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Quests = require(script.Parent.Quests)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Shop = {}

local stock: { [string]: number } = {}
local restockAt = 0
local rng = Random.new()
local shopStand: BasePart
local sellStand: BasePart

local function isNear(player: Player, target: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	return (root.Position - target.Position).Magnitude <= ReefConfig.INTERACT_DISTANCE
end

local function broadcastStock(target: Player?)
	local payload = { stock = stock, restockAt = restockAt }
	if target then
		Remotes.ShopSync:FireClient(target, payload)
	else
		Remotes.ShopSync:FireAllClients(payload)
	end
end

local function restock()
	stock = {}
	for _, seedId in ReefConfig.SEED_ORDER do
		local seed = ReefConfig.Seeds[seedId]
		if seed.shop ~= false and rng:NextNumber() < seed.stockChance then
			stock[seedId] = rng:NextInteger(seed.stockMin, seed.stockMax)
		end
	end
	restockAt = Workspace:GetServerTimeNow() + ReefConfig.RESTOCK_SECONDS
	broadcastStock()
	if stock.star then
		for _, player in Players:GetPlayers() do
			Plots.notify(player, "Starlight Coral seeds are in stock!", "rare")
		end
	end
end

local function onBuySeed(player: Player, seedId: unknown)
	if not RateLimit.consume(player) then
		return
	end
	if type(seedId) ~= "string" then
		return
	end
	local seed = ReefConfig.Seeds[seedId]
	local profile = PlayerData.get(player)
	if not seed or not profile then
		return
	end
	if not isNear(player, shopStand) then
		Plots.notify(player, "Walk over to the Coral Market to buy seeds.")
		return
	end
	-- Species research (the Research Laboratory) comes first, so a locked seed never says
	-- "sold out" or "not enough shells".
	if not ReefConfig.speciesUnlocked(profile.data, seedId) then
		Plots.notify(player, `Research {seed.name} at the Research Laboratory before you can buy it.`)
		return
	end
	if (stock[seedId] or 0) <= 0 then
		Plots.notify(player, `{seed.name} is sold out. Restock soon!`)
		return
	end
	local owned = profile.data.seeds[seedId] or 0
	if owned >= ReefConfig.MAX_SEEDS_PER_TYPE then
		return
	end
	local wallet = { shells = profile.data.shells }
	if not EconomyMath.trySpend(wallet, { shells = seed.price }) then
		Plots.notify(player, "Not enough shells.")
		return
	end
	-- No yields between the checks above and these writes.
	profile.data.shells = wallet.shells
	stock[seedId] -= 1
	profile.data.seeds[seedId] = owned + 1
	if not profile.selected then
		profile.selected = seedId
	end
	PlayerData.sync(player)
	broadcastStock()
end

local function onSelectSeed(player: Player, seedId: unknown)
	if not RateLimit.consume(player, 0.5) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if seedId == nil then
		profile.selected = nil
	elseif type(seedId) == "string" and ReefConfig.Seeds[seedId] and (profile.data.seeds[seedId] or 0) > 0 then
		profile.selected = seedId
	else
		return
	end
	PlayerData.sync(player)
end

local function sellAll(player: Player)
	if not RateLimit.consume(player, 2) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local total, count = 0, 0
	for key, amount in profile.data.inventory do
		local seedId, mutationId = ReefConfig.splitInventoryKey(key)
		if seedId and mutationId then
			total += ReefConfig.harvestValue(seedId, mutationId) * amount
			count += amount
		end
	end
	if count == 0 then
		Plots.notify(player, "Nothing to sell. Harvest fully grown coral first.")
		return
	end
	-- Rebirths add their bonus to every sale.
	total = math.floor(total * ReefConfig.shellMultiplier(profile.data.rebirths))
	profile.data.inventory = {}
	PlayerData.addShells(player, total)
	Plots.notify(player, `Sold {count} coral for {EconomyMath.formatNumber(total)} shells!`, "good")
	Quests.progress(player, "sell", count)
	Quests.progress(player, "earn", total)
	PlayerData.sync(player)
end

-- Restock right now (admins), which also restarts the restock timer.
function Shop.restockNow()
	restock()
end

function Shop.start(worldParts: World.WorldParts)
	shopStand = worldParts.shopStand
	sellStand = worldParts.sellStand

	local sellPrompt = sellStand:FindFirstChildOfClass("ProximityPrompt")
	if sellPrompt then
		sellPrompt.Triggered:Connect(sellAll)
	end

	Remotes.BuySeed.OnServerEvent:Connect(onBuySeed)
	Remotes.SelectSeed.OnServerEvent:Connect(onSelectSeed)
	Remotes.RequestSync.OnServerEvent:Connect(function(player)
		if RateLimit.consume(player) then
			broadcastStock(player)
		end
	end)

	restock()
	task.spawn(function()
		while true do
			task.wait(1)
			if Workspace:GetServerTimeNow() >= restockAt then
				restock()
			end
		end
	end)
end

return Shop
