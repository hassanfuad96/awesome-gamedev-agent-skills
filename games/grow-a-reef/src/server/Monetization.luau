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

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Shop = require(script.Parent.Shop)

local Monetization = {}

local STORE = ReefConfig.Store

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

-- Gives one developer product. Returns false if it couldn't be given right now.
local function grant(player: Player, profile: PlayerData.Profile, product: ReefConfig.StoreProduct): boolean
	if product.shells then
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
	local data = profile.data
	local purchaseId = tostring(receipt.PurchaseId)
	if not data.receipts[purchaseId] then
		-- Record the id with the grant, in the same in-memory save, before anything can yield.
		data.receipts[purchaseId] = os.time()
		if not grant(player, profile, product) then
			data.receipts[purchaseId] = nil
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- Keep only the newest receipt ids.
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
		PlayerData.sync(player)
	end
	-- Acknowledge only once it's saved (in Studio without data stores there's nothing to save).
	if profile.persist and not PlayerData.save(player, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- The receipt handler itself, so a Studio test script can replay receipts through it.
Monetization.processReceipt = processReceipt

-- Whether the player owns a pass right now, for other server code.
function Monetization.owns(player: Player, passKey: string): boolean
	local profile = PlayerData.get(player)
	return profile ~= nil and profile.data.ownedPasses[passKey] == true
end

function Monetization.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchased)
	PlayerData.onLoaded(function(player, profile)
		refreshPasses(player, profile)
		PlayerData.sync(player)
	end)
end

return Monetization
