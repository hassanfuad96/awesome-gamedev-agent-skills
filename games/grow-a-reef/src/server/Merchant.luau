--!nonstrict
-- Mermaid Merchant, one of the sea events: Marina sets up a shell stall in the plaza with a few
-- rare-seed offers (drawn by chance from ReefConfig.Merchant.offers). Each player can buy each
-- offer once per visit, at the stall. Clients read the offers from the MerchantOffers Workspace
-- attribute and what they've bought from their MerchantBought attribute; BuyMerchant carries
-- only an offer id, and the server checks the price, distance and limits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local RateLimit = require(script.Parent.RateLimit)
local EventVisuals = require(script.Parent.EventVisuals)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Merchant = {}

local SETTINGS = ReefConfig.Merchant

local rng = Random.new()
local stall: Model? = nil
local counter: BasePart? = nil
local offers: { [string]: true } = {}
local bought: { [Player]: { [string]: true } } = {}

local function publishBought(player: Player)
	local ids = {}
	for id in bought[player] or {} do
		table.insert(ids, id)
	end
	player:SetAttribute("MerchantBought", if #ids > 0 then table.concat(ids, ",") else nil)
end

-- This visit's offers: each has its chance to be on the stall, up to offersPerVisit, in the
-- order of the list.
local function pickOffers(): { string }
	local picked = {}
	for _, offer in SETTINGS.offers do
		if #picked < SETTINGS.offersPerVisit and rng:NextNumber() < offer.chance then
			table.insert(picked, offer.id)
		end
	end
	return picked
end

local function onBuy(player: Player, offerId: unknown)
	if not RateLimit.consume(player, 2) or type(offerId) ~= "string" then
		return
	end
	local offer = ReefConfig.MerchantOfferById[offerId]
	local profile = PlayerData.get(player)
	if not offer or not offers[offerId] or not counter or not profile then
		return
	end
	local mine = bought[player] or {}
	if mine[offerId] then
		Plots.notify(player, "Marina: \"One of those per diver, sweetie!\"")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - counter.Position).Magnitude > ReefConfig.INTERACT_DISTANCE then
		Plots.notify(player, "Swim over to Marina's stall to trade.")
		return
	end
	local seed = ReefConfig.Seeds[offer.seed]
	local owned = profile.data.seeds[offer.seed] or 0
	if owned + offer.count > ReefConfig.MAX_SEEDS_PER_TYPE then
		Plots.notify(player, `You can't carry more {seed.name} seeds.`)
		return
	end
	local wallet = { shells = profile.data.shells }
	if not EconomyMath.trySpend(wallet, { shells = offer.price }) then
		Plots.notify(player, `That costs {EconomyMath.formatNumber(offer.price)} shells.`)
		return
	end
	-- No yields between the checks above and these writes.
	profile.data.shells = wallet.shells
	profile.data.seeds[offer.seed] = owned + offer.count
	mine[offerId] = true
	bought[player] = mine
	publishBought(player)
	Plots.notify(player, `Marina sold you {offer.count} {seed.name} seed{if offer.count > 1 then "s" else ""}!`, "rare")
	PlayerData.sync(player)
end

function Merchant.start()
	offers = {}
	bought = {}
	local picked = pickOffers()
	for _, id in picked do
		offers[id] = true
	end
	local center = ReefConfig.Lagoon.center
	local at = center + SETTINGS.stall
	-- Marina faces the middle of the plaza.
	local model, newCounter = EventVisuals.mermaidStall(CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z)))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TradePrompt"
	prompt.ActionText = "Trade"
	prompt.ObjectText = "Marina the Mermaid"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", "Merchant")
	prompt.Parent = newCounter
	model.Parent = Workspace
	EventVisuals.burst(at + Vector3.new(0, 4, 0), Color3.fromRGB(150, 255, 230), 60)
	stall = model
	counter = newCounter
	Workspace:SetAttribute("MerchantOffers", table.concat(picked, ","))
end

function Merchant.stop()
	if stall then
		EventVisuals.burst(stall:GetPivot().Position + Vector3.new(0, 4, 0), Color3.fromRGB(150, 255, 230), 60)
		stall:Destroy()
	end
	stall = nil
	counter = nil
	offers = {}
	bought = {}
	Workspace:SetAttribute("MerchantOffers", nil)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("MerchantBought", nil)
	end
end

-- Where the stall is while she's in town (the client closes its window when you swim off).
function Merchant.counter(): BasePart?
	return counter
end

function Merchant.init()
	Remotes.BuyMerchant.OnServerEvent:Connect(onBuy)
	Players.PlayerRemoving:Connect(function(player)
		bought[player] = nil
	end)
end

return Merchant
