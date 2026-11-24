--!nonstrict
-- Playing together (ReefConfig.Rewards): visiting a reef, watering it, and trading.
--   Visit (VisitReef): whirls you to the gate of another player's reef in this server.
--   Water (the "Water reef" prompt on each reef's gate sign): that reef's growing coral jumps
--     ahead; the visitor earns a few shells. Each player can water each reef once a day and
--     up to givenPerDay reefs a day; a reef takes at most receivedPerDay waterings a day.
--   Trade (TradeRequest, TradeAction → TradeSync): seeds and pets between two players in this
--     server. Asking someone who has asked you opens the trade. Each side puts in an offer;
--     any change clears both sides' Accept. When both accept, both must Confirm; then the swap
--     is checked again against both saves and done in one step (no yields). Leaving cancels.
--     Only for players whose Roblox policy allows trading paid items (the Starter Pack's pet).

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local World = require(script.Parent.World)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Pets = require(script.Parent.Pets)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Social = {}

local SETTINGS = ReefConfig.Rewards
local TRADE = SETTINGS.trade

local lastVisit: { [Player]: number } = {}

-- Visits ----------------------------------------------------------------------------------

local function onVisit(player: Player, userId: unknown)
	if not RateLimit.consume(player, 2) or type(userId) ~= "number" then
		return
	end
	local owner = Players:GetPlayerByUserId(userId)
	local plot = owner and owner ~= player and Plots.plotOf(owner)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not plot or not humanoid or humanoid.Health <= 0 then
		return
	end
	local waited = os.clock() - (lastVisit[player] or -math.huge)
	if waited < SETTINGS.visitCooldown then
		Plots.notify(player, `The whirlpool is still spinning up ({math.ceil(SETTINGS.visitCooldown - waited)}s).`)
		return
	end
	lastVisit[player] = os.clock()
	character:PivotTo(plot.spawn)
	Remotes.Teleported:FireClient(player)
	Plots.notify(player, `Welcome to {owner.DisplayName}'s reef! Water it at the gate sign to help it grow.`, "good")
	Plots.notify(owner, `{player.DisplayName} is visiting your reef!`, "good")
end

-- Watering --------------------------------------------------------------------------------

-- Starts a new day's watering counts.
local function freshWatering(data: PlayerData.Data)
	local today = ReefConfig.dayNumber(os.time())
	if data.watering.day ~= today then
		data.watering = { day = today, given = 0, received = 0, reefs = {} }
	end
	return data.watering
end

local function splash(sign: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 210, 255), Color3.fromRGB(200, 245, 255))
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new(0.9, 0.3)
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(4, 8)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Enabled = false
	emitter.Parent = sign
	emitter:Emit(40)
	task.delay(2.5, emitter.Destroy, emitter)
end

local function onWater(player: Player, plot: World.PlotParts)
	if not RateLimit.consume(player, 2) then
		return
	end
	local owner = Plots.ownerOf(plot.index)
	if not owner then
		Plots.notify(player, "Nobody owns this reef yet.")
		return
	end
	if owner == player then
		Plots.notify(player, "Friends can water your reef to make it grow faster. Invite some!")
		return
	end
	local visitor = PlayerData.get(player)
	local ownerProfile = PlayerData.get(owner)
	if not visitor or not ownerProfile then
		return
	end
	local settings = SETTINGS.watering
	local given = freshWatering(visitor.data)
	local received = freshWatering(ownerProfile.data)
	local key = tostring(owner.UserId)
	if given.reefs[key] then
		Plots.notify(player, `You already watered {owner.DisplayName}'s reef today. Come back tomorrow!`)
		return
	end
	if given.given >= settings.givenPerDay then
		Plots.notify(player, `You've watered {settings.givenPerDay} reefs today. Your watering can is empty until tomorrow!`)
		return
	end
	if received.received >= settings.receivedPerDay then
		Plots.notify(player, `{owner.DisplayName}'s reef is soaked: it's had all the water it can take today.`)
		return
	end
	given.reefs[key] = true
	given.given += 1
	received.received += 1
	Plots.boostGrowth(settings.growSeconds, owner)
	PlayerData.addShells(player, settings.visitorShells)
	splash(plot.signPart)
	Plots.notify(player, `You watered {owner.DisplayName}'s reef! +{settings.visitorShells} shells`, "good")
	Plots.notify(owner, `{player.DisplayName} watered your reef: your coral grew {settings.growSeconds} seconds!`, "rare")
	PlayerData.sync(player)
	PlayerData.sync(owner)
end

-- Trading ---------------------------------------------------------------------------------

export type Offer = { seeds: { [string]: number }, pets: { string } }

type Trade = {
	players: { Player },
	offers: { [Player]: Offer },
	accepted: { [Player]: boolean },
	confirmed: { [Player]: boolean },
	stage: string, -- "offer" or "confirm"
}

local trades: { [Player]: Trade } = {}
local requests: { [Player]: { [Player]: number } } = {} -- target → who asked → os.clock()
local lastRequest: { [Player]: number } = {}
local tradeAllowed: { [Player]: boolean } = {}

local function emptyOffer(): Offer
	return { seeds = {}, pets = {} }
end

-- Cleans an offer from a client. Returns nil when it isn't a valid shape.
local function cleanOffer(raw: unknown): Offer?
	if type(raw) ~= "table" then
		return nil
	end
	local offer = emptyOffer()
	local kinds = 0
	if type(raw.seeds) == "table" then
		for seedId, count in raw.seeds do
			if type(seedId) ~= "string" or not ReefConfig.Seeds[seedId] then
				return nil
			end
			local clean = EconomyMath.sanitizeLevel(count, ReefConfig.MAX_SEEDS_PER_TYPE)
			if clean > 0 then
				kinds += 1
				offer.seeds[seedId] = clean
			end
		end
	end
	if type(raw.pets) == "table" then
		for _, petId in raw.pets do
			if type(petId) ~= "string" or #petId > 10 or table.find(offer.pets, petId) then
				return nil
			end
			table.insert(offer.pets, petId)
		end
	end
	if kinds > TRADE.maxSeedKinds or #offer.pets > TRADE.maxPets then
		return nil
	end
	return offer
end

-- Why `data` can't give `offer`, or nil when it can.
local function offerProblem(data: PlayerData.Data, offer: Offer): string?
	for seedId, count in offer.seeds do
		if (data.seeds[seedId] or 0) < count then
			return `not enough {ReefConfig.Seeds[seedId].name} seeds`
		end
	end
	for _, petId in offer.pets do
		if not data.pets[petId] then
			return "a pet that's no longer there"
		end
	end
	return nil
end

local function countPets(data: PlayerData.Data): number
	local n = 0
	for _ in data.pets do
		n += 1
	end
	return n
end

-- Why `data` can't take `incoming` while giving `outgoing`, or nil when it can.
local function roomProblem(data: PlayerData.Data, outgoing: Offer, incoming: Offer): string?
	if countPets(data) - #outgoing.pets + #incoming.pets > ReefConfig.Pets.maxOwned then
		return "no room for more pets"
	end
	for seedId, count in incoming.seeds do
		local after = (data.seeds[seedId] or 0) - (outgoing.seeds[seedId] or 0) + count
		if after > ReefConfig.MAX_SEEDS_PER_TYPE then
			return `too many {ReefConfig.Seeds[seedId].name} seeds`
		end
	end
	return nil
end

-- Checks both sides, then swaps. Never yields. Returns nil when done, or the problem.
-- (Public so a Studio test can run it on two saves.)
function Social.swap(dataA: PlayerData.Data, dataB: PlayerData.Data, offerA: Offer, offerB: Offer): string?
	local problem = offerProblem(dataA, offerA) or offerProblem(dataB, offerB)
	if problem then
		return problem
	end
	problem = roomProblem(dataA, offerA, offerB) or roomProblem(dataB, offerB, offerA)
	if problem then
		return problem
	end
	local function move(from: PlayerData.Data, to: PlayerData.Data, offer: Offer)
		for seedId, count in offer.seeds do
			from.seeds[seedId] -= count
			if from.seeds[seedId] <= 0 then
				from.seeds[seedId] = nil
			end
			to.seeds[seedId] = (to.seeds[seedId] or 0) + count
		end
		for _, petId in offer.pets do
			local pet = from.pets[petId]
			from.pets[petId] = nil
			local at = table.find(from.equipped, petId)
			if at then
				table.remove(from.equipped, at)
			end
			to.petSeq += 1
			to.pets[tostring(to.petSeq)] = { species = pet.species, golden = pet.golden }
		end
	end
	move(dataA, dataB, offerA)
	move(dataB, dataA, offerB)
	return nil
end

local function otherOf(trade: Trade, player: Player): Player
	return if trade.players[1] == player then trade.players[2] else trade.players[1]
end

-- Sends each side the trade as they see it (nil = no trade).
local function syncTrade(trade: Trade?, ...: Player)
	for _, player in { ... } do
		if not trade then
			Remotes.TradeSync:FireClient(player, nil)
			continue
		end
		local other = otherOf(trade, player)
		local otherProfile = PlayerData.get(other)
		-- Their pets as the client draws them (it can't see the other player's save).
		local theirPets = {}
		for _, petId in trade.offers[other].pets do
			local pet = otherProfile and otherProfile.data.pets[petId]
			if pet then
				table.insert(theirPets, { species = pet.species, golden = pet.golden })
			end
		end
		Remotes.TradeSync:FireClient(player, {
			kind = "trade",
			with = other.UserId,
			withName = other.DisplayName,
			mine = trade.offers[player],
			theirSeeds = trade.offers[other].seeds,
			theirPets = theirPets,
			stage = trade.stage,
			accepted = trade.accepted[player] == true,
			theyAccepted = trade.accepted[other] == true,
			confirmed = trade.confirmed[player] == true,
			theyConfirmed = trade.confirmed[other] == true,
		})
	end
end

local function endTrade(trade: Trade, message: string?, tone: string?)
	for _, player in trade.players do
		if trades[player] == trade then
			trades[player] = nil
		end
		if player.Parent then
			syncTrade(nil, player)
			if message then
				Plots.notify(player, message, tone)
			end
		end
	end
end

local function canTrade(player: Player): boolean
	return tradeAllowed[player] == true
end

local function onTradeRequest(player: Player, userId: unknown)
	if not RateLimit.consume(player, 2) or type(userId) ~= "number" then
		return
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == player or not PlayerData.get(player) or not PlayerData.get(target) then
		return
	end
	if not canTrade(player) then
		Plots.notify(player, "Trading isn't available on your account.", "bad")
		return
	end
	if not canTrade(target) then
		Plots.notify(player, `{target.DisplayName} can't trade.`, "bad")
		return
	end
	if trades[player] then
		Plots.notify(player, "Finish your current trade first.")
		return
	end
	if trades[target] then
		Plots.notify(player, `{target.DisplayName} is already trading. Try again soon.`)
		return
	end
	-- They asked you first: this opens the trade.
	local asked = requests[player] and requests[player][target]
	if asked and os.clock() - asked <= TRADE.requestSeconds then
		requests[player][target] = nil
		if requests[target] then
			requests[target][player] = nil
		end
		local trade: Trade = {
			players = { target, player },
			offers = { [target] = emptyOffer(), [player] = emptyOffer() },
			accepted = {},
			confirmed = {},
			stage = "offer",
		}
		trades[player] = trade
		trades[target] = trade
		syncTrade(trade, player, target)
		return
	end
	if os.clock() - (lastRequest[player] or -math.huge) < TRADE.cooldown then
		return
	end
	lastRequest[player] = os.clock()
	requests[target] = requests[target] or {}
	requests[target][player] = os.clock()
	Remotes.TradeSync:FireClient(target, { kind = "request", from = player.UserId, fromName = player.DisplayName })
	Plots.notify(player, `Trade request sent to {target.DisplayName}.`)
end

local function onTradeAction(player: Player, action: unknown, payload: unknown)
	if not RateLimit.consume(player) or type(action) ~= "string" then
		return
	end
	if action == "decline" then
		local from = type(payload) == "number" and Players:GetPlayerByUserId(payload)
		if from and requests[player] and requests[player][from] then
			requests[player][from] = nil
			Plots.notify(from, `{player.DisplayName} said no to trading right now.`)
		end
		return
	end
	local trade = trades[player]
	if not trade then
		return
	end
	local other = otherOf(trade, player)
	local mine = PlayerData.get(player)
	local theirs = PlayerData.get(other)
	if not mine or not theirs then
		endTrade(trade, "The trade was cancelled.")
		return
	end
	if action == "cancel" then
		endTrade(trade, `The trade with {other.DisplayName} was cancelled.`)
	elseif action == "offer" then
		local offer = cleanOffer(payload)
		if not offer then
			return
		end
		local problem = offerProblem(mine.data, offer)
		if problem then
			Plots.notify(player, `You can't offer that: {problem}.`, "bad")
			return
		end
		trade.offers[player] = offer
		trade.accepted = {}
		trade.confirmed = {}
		trade.stage = "offer"
		syncTrade(trade, player, other)
	elseif action == "accept" and trade.stage == "offer" then
		trade.accepted[player] = true
		if trade.accepted[other] then
			local problem = offerProblem(mine.data, trade.offers[player]) or offerProblem(theirs.data, trade.offers[other])
			if problem then
				endTrade(trade, `The trade was cancelled: {problem}.`, "bad")
				return
			end
			trade.stage = "confirm"
			trade.confirmed = {}
		end
		syncTrade(trade, player, other)
	elseif action == "confirm" and trade.stage == "confirm" then
		trade.confirmed[player] = true
		if not trade.confirmed[other] then
			syncTrade(trade, player, other)
			return
		end
		local a, b = trade.players[1], trade.players[2]
		local profileA, profileB = PlayerData.get(a), PlayerData.get(b)
		if not profileA or not profileB then
			endTrade(trade, "The trade was cancelled.")
			return
		end
		local problem = Social.swap(profileA.data, profileB.data, trade.offers[a], trade.offers[b])
		if problem then
			endTrade(trade, `The trade was cancelled: {problem}.`, "bad")
			return
		end
		endTrade(trade, nil)
		for _, who in trade.players do
			Plots.notify(who, `Trade with {otherOf(trade, who).DisplayName} done!`, "rare")
			Pets.publish(who)
			PlayerData.sync(who)
			task.spawn(PlayerData.save, who, false)
		end
	end
end

local function checkPolicy(player: Player)
	local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	tradeAllowed[player] = ok and type(policy) == "table" and policy.IsPaidItemTradingAllowed == true
	player:SetAttribute("CanTrade", tradeAllowed[player])
end

function Social.start(worldParts: World.WorldParts)
	Remotes.VisitReef.OnServerEvent:Connect(onVisit)
	Remotes.TradeRequest.OnServerEvent:Connect(onTradeRequest)
	Remotes.TradeAction.OnServerEvent:Connect(onTradeAction)
	for _, plot in worldParts.plots do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "WaterPrompt"
		prompt.ActionText = "Water reef"
		prompt.ObjectText = "Help it grow"
		prompt.KeyboardKeyCode = Enum.KeyCode.F -- E is "Like this reef" on the same sign
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.UIOffset = Vector2.new(0, 70)
		prompt:SetAttribute("Kind", "WaterReef")
		prompt.Parent = plot.signPart
		prompt.Triggered:Connect(function(player)
			onWater(player, plot)
		end)
	end
	PlayerData.onLoaded(function(player)
		checkPolicy(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local trade = trades[player]
		if trade then
			endTrade(trade, `{player.DisplayName} left, so the trade was cancelled.`)
		end
		requests[player] = nil
		for _, asked in requests do
			asked[player] = nil
		end
		lastRequest[player] = nil
		lastVisit[player] = nil
		tradeAllowed[player] = nil
	end)
end

return Social
