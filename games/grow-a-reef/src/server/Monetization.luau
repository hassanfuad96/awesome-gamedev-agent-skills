--!nonstrict
-- Robux purchases (ReefConfig.Store). The client only opens Roblox's purchase prompt; this
-- module, on the server, is the one place that decides what a player owns and grants it.
--   Game passes: ownership is checked with Roblox on join and after a purchase, and cached in
--   data.ownedPasses. A failed check keeps the cached answer (it never takes a pass away).
--     2x Shells    PlayerData.saleMultiplier doubles coral and fish sales
--     VIP Bag      PlayerData.bagCapacity adds ReefConfig.Store.vipBagBonus
--     Speed Fins   the client's Swimming reads ownedPasses (swimming is client physics)
--     Royal Fence  the "royal" fence and the "vip" title
--   Developer products: the only ProcessReceipt in the game. Each purchase id is recorded in
--   data.receipts together with the grant, then saved; a repeated receipt is acknowledged
--   without granting again. The receipt is only acknowledged once the save went through, so
--   Roblox retries it (and the grant is not repeated) if anything failed.
--   Gifts: before the purchase prompt the client names the friend (SetGiftTarget, checked
--   here). The gift goes to that friend if they're still in the server, recorded and saved in
--   their save first, then in the buyer's; if they've left, it goes to the buyer instead.
--   A gifted pass is kept in giftedPasses (refreshPasses only manages bought ones).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RateLimit = require(script.Parent.RateLimit)

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Shop = require(script.Parent.Shop)

local Monetization = {}

local STORE = ReefConfig.Store
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Who each player last picked to receive a gift (user id).
local giftTargets: { [Player]: number } = {}

-- The pass's perks that live in the save: the royal fence and VIP title.
local function applyPassPerks(data: PlayerData.Data)
	if data.ownedPasses.royalFence then
		data.fences[STORE.royalFence] = true
		data.titles[STORE.royalTitle] = true
	end
end

-- Asks Roblox whether the player owns each pass. Returns true when anything changed.
local function refreshPasses(player: Player, profile: PlayerData.Profile): boolean
	local changed = false
	for _, pass in STORE.passes do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
		if ok and type(owns) == "boolean" then
			local had = profile.data.ownedPasses[pass.key] == true
			if owns ~= had then
				profile.data.ownedPasses[pass.key] = if owns then true else nil
				changed = true
			end
		elseif not ok then
			warn("[Monetization] pass check failed, keeping the saved answer:", pass.name, owns)
		end
	end
	applyPassPerks(profile.data)
	return changed
end

local function onPassPurchased(player: Player, passId: number, purchased: boolean)
	local pass = ReefConfig.StorePassById[passId]
	local profile = PlayerData.get(player)
	if not purchased or not pass or not profile then
		return
	end
	profile.data.ownedPasses[pass.key] = true
	applyPassPerks(profile.data)
	if pass.key == "royalFence" and profile.data.title == "" then
		profile.data.title = STORE.royalTitle
	end
	Plots.notify(player, `Thanks for buying {pass.name}! {pass.description}`, "rare")
	PlayerData.sync(player)
	task.spawn(PlayerData.save, player, false)
end

local function petCount(data: PlayerData.Data): number
	local n = 0
	for _ in data.pets do
		n += 1
	end
	return n
end

-- The Starter Pack's contents.
local function grantStarter(player: Player, data: PlayerData.Data)
	local starter = STORE.starter
	data.starterBought = true
	for seedId, count in starter.seeds do
		data.seeds[seedId] = math.min(ReefConfig.MAX_SEEDS_PER_TYPE, (data.seeds[seedId] or 0) + count)
	end
	local shells = starter.shells
	local petText = `Golden {ReefConfig.Pets.species[starter.pet.species].name}`
	if petCount(data) < ReefConfig.Pets.maxOwned then
		data.petSeq += 1
		data.pets[tostring(data.petSeq)] = { species = starter.pet.species, golden = starter.pet.golden }
	else
		shells += starter.fullPetsShells
		petText = `{EconomyMath.formatNumber(starter.fullPetsShells)} more shells (your pets are full)`
	end
	PlayerData.addShells(player, shells)
	Plots.notify(player, `Starter Pack: a {petText}, seeds and {EconomyMath.formatNumber(starter.shells)} shells! Open Pets to equip it.`, "rare")
end

-- A gift for `player`: from the friend named `from`, or (from = nil) the buyer's own gift,
-- because the friend it was for had left.
local function grantGift(player: Player, data: PlayerData.Data, product: ReefConfig.StoreProduct, from: string?)
	local intro = if from then `{from} gifted you` else "Your friend left before your gift arrived, so it's yours:"
	local pass = product.pass and ReefConfig.StorePassByKey[product.pass]
	if pass and not PlayerData.hasPass(data, pass.key) then
		data.giftedPasses[pass.key] = true
		Plots.notify(player, `{intro} {pass.name}! {pass.description}`, "rare")
		return
	end
	-- A shell gift, or a pass they already have: shells.
	local shells = product.shells or STORE.giftOwnedShells
	PlayerData.addShells(player, shells)
	local why = if pass then ` (you already had {pass.name})` else ""
	Plots.notify(player, `{intro} {EconomyMath.formatNumber(shells)} shells{why}!`, "rare")
end

-- Gives one developer product (not a gift: processGift). Returns false if it couldn't be
-- given right now.
local function grant(player: Player, profile: PlayerData.Profile, product: ReefConfig.StoreProduct): boolean
	if product.starter then
		grantStarter(player, profile.data)
	elseif product.shells then
		PlayerData.addShells(player, product.shells)
		Plots.notify(player, `+{EconomyMath.formatNumber(product.shells)} shells! Thanks for your support!`, "rare")
	elseif product.key == "instantGrow" then
		-- Every coral still growing counts as planted one full grow time ago. (Not a huge number:
		-- planting times must stay real timestamps, or a reload would reset them.)
		local longest = 0
		for _, seed in ReefConfig.Seeds do
			longest = math.max(longest, seed.growSeconds)
		end
		Plots.boostGrowth(longest + 1, player)
		Plots.notify(player, "Instant Grow! Every coral on your reef is fully grown.", "rare")
	elseif product.key == "restock" then
		Shop.personalRestock(player)
		Plots.notify(player, "Personal Restock! The Seed Shop is fully stocked just for you for 5 minutes.", "rare")
	else
		return false
	end
	return true
end

-- Keeps only the newest receipt ids.
local function trimReceipts(data: PlayerData.Data)
	local ids = {}
	for id, at in data.receipts do
		table.insert(ids, { id = id, at = at })
	end
	if #ids > STORE.receiptsKept then
		table.sort(ids, function(a, b)
			return a.at > b.at
		end)
		for i = STORE.receiptsKept + 1, #ids do
			data.receipts[ids[i].id] = nil
		end
	end
end

-- Saves when the profile persists. Returns false only when a real save failed.
local function saved(player: Player, profile: PlayerData.Profile): boolean
	return not profile.persist or PlayerData.save(player, false)
end

-- A gift: to the friend picked, if they're here; else to the buyer.
local function processGift(receipt, product: ReefConfig.StoreProduct, buyer: Player, buyerProfile: PlayerData.Profile)
	local purchaseId = tostring(receipt.PurchaseId)
	local buyerData = buyerProfile.data
	if not buyerData.receipts[purchaseId] then
		local friend = giftTargets[buyer] and Players:GetPlayerByUserId(giftTargets[buyer])
		if friend and friend ~= buyer and friend.Parent and not friend:GetAttribute("DataLoaded") then
			return Enum.ProductPurchaseDecision.NotProcessedYet -- still loading: try again shortly
		end
		local friendProfile = friend and PlayerData.get(friend)
		if friend and friend ~= buyer and friendProfile then
			-- The friend's save records the purchase id with the gift, and is saved first.
			if not friendProfile.data.receipts[purchaseId] then
				friendProfile.data.receipts[purchaseId] = os.time()
				grantGift(friend, friendProfile.data, product, buyer.DisplayName)
				trimReceipts(friendProfile.data)
				PlayerData.sync(friend)
			end
			if not saved(friend, friendProfile) then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			Plots.notify(buyer, `Your gift ({product.name}) went to {friend.DisplayName}. Thank you!`, "good")
		else
			-- They left: the buyer keeps it.
			grantGift(buyer, buyerData, product, nil)
		end
		buyerData.receipts[purchaseId] = os.time()
		trimReceipts(buyerData)
		PlayerData.sync(buyer)
	end
	if not saved(buyer, buyerProfile) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function processReceipt(receipt)
	local product = ReefConfig.StoreProductById[receipt.ProductId]
	if not product then
		warn("[Monetization] receipt for an unknown product:", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and PlayerData.get(player)
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- not here or not loaded yet: Roblox retries later
	end
	if product.gift then
		return processGift(receipt, product, player, profile)
	end
	local data = profile.data
	local purchaseId = tostring(receipt.PurchaseId)
	if not data.receipts[purchaseId] then
		-- Record the id with the grant, in the same in-memory save, before anything can yield.
		data.receipts[purchaseId] = os.time()
		if not grant(player, profile, product) then
			data.receipts[purchaseId] = nil
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		trimReceipts(data)
		PlayerData.sync(player)
	end
	-- Acknowledge only once it's saved (in Studio without data stores there's nothing to save).
	if not saved(player, profile) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- The friend a player wants their next gift to go to: someone else in this server.
local function onSetGiftTarget(player: Player, userId: unknown)
	if not RateLimit.consume(player) then
		return
	end
	local friend = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if friend and friend ~= player then
		giftTargets[player] = friend.UserId
	else
		giftTargets[player] = nil
	end
end

-- The receipt handler itself, so a Studio test script can replay receipts through it.
Monetization.processReceipt = processReceipt

-- Whether the player owns a pass right now, for other server code.
function Monetization.owns(player: Player, passKey: string): boolean
	local profile = PlayerData.get(player)
	return profile ~= nil and PlayerData.hasPass(profile.data, passKey)
end

function Monetization.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchased)
	Remotes.SetGiftTarget.OnServerEvent:Connect(onSetGiftTarget)
	Players.PlayerRemoving:Connect(function(player)
		giftTargets[player] = nil
	end)
	PlayerData.onLoaded(function(player, profile)
		refreshPasses(player, profile)
		PlayerData.sync(player)
	end)
end

return Monetization
