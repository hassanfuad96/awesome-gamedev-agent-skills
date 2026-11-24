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
-- Personal Restock (a Store product): that player's own full stock for RESTOCK_SECONDS.
local personal: { [Player]: { stock: { [string]: number }, expires: number } } = {}
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

-- Each player sees the shared stock, or their own after a Personal Restock.
local function broadcastStock(target: Player?)
	for _, player in if target then { target } else Players:GetPlayers() do
		local own = personal[player]
		if own then
			Remotes.ShopSync:FireClient(player, { stock = own.stock, restockAt = own.expires, personal = true })
		else
			Remotes.ShopSync:FireClient(player, { stock = stock, restockAt = restockAt, personal = false })
		end
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
	local own = personal[player]
	local source = if own then own.stock else stock
	if (source[seedId] or 0) <= 0 then
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
	source[seedId] -= 1
	profile.data.seeds[seedId] = owned + 1
	if not profile.selected then
		profile.selected = seedId
	end
	PlayerData.sync(player)
	broadcastStock(if source == stock then nil else player)
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
	-- Rebirths (and the 2x Shells pass) add their bonus to every sale.
	total = math.floor(total * PlayerData.saleMultiplier(profile.data))
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

-- Personal Restock (bought in the Store): every seed the shop sells, fully stocked, just for
-- this player for the next RESTOCK_SECONDS.
function Shop.personalRestock(player: Player)
	local own = {}
	for _, seedId in ReefConfig.SEED_ORDER do
		local seed = ReefConfig.Seeds[seedId]
		if seed.shop ~= false and seed.stockMax > 0 then
			own[seedId] = seed.stockMax
		end
	end
	personal[player] = { stock = own, expires = Workspace:GetServerTimeNow() + ReefConfig.RESTOCK_SECONDS }
	broadcastStock(player)
end

function Shop.start(worldParts: World.WorldParts)
	shopStand = worldParts.shopStand
	sellStand = worldParts.sellStand

	local sellPrompt = sellStand:FindFirstChildOfClass("ProximityPrompt")
	if sellPrompt then
		sellPrompt.Triggered:Connect(sellAll)
	end

	Players.PlayerRemoving:Connect(function(player)
		personal[player] = nil
	end)
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
			local now = Workspace:GetServerTimeNow()
			if now >= restockAt then
				restock()
			end
			for player, own in personal do
				if now >= own.expires then
					personal[player] = nil
					broadcastStock(player) -- back to the shared stock
				end
			end
		end
	end)
end

return Shop
