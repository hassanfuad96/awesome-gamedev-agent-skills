--!nonstrict
-- Pets: eggs bought with shells at the Pet Hatchery hatch into sea creatures with perks.
-- The server rolls every egg (from the same odds list the client shows), owns the perks,
-- and publishes each player's equipped pets as the "EquippedPets" attribute, which every
-- client turns into followers (PetFollowers). Remotes carry ids only.
--   Seahorse: coral grows faster. Octopus: harvests a grown coral now and then.
--   Pufferfish: caught fish are worth more. Golden pets double the perk.

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

local Pets = {}

local SETTINGS = ReefConfig.Pets
local rng = Random.new()
local hatchery: BasePart

local function petName(pet: PlayerData.Pet): string
	local name = SETTINGS.species[pet.species].name
	return if pet.golden then "Golden " .. name else name
end

-- The perk level a player has for a kind of pet: 0 none, 1 normal, 2 golden. Two pets of
-- the same kind don't add up; the better one counts.
local function perkLevel(player: Player, species: string): number
	local profile = PlayerData.get(player)
	if not profile then
		return 0
	end
	local level = 0
	for _, petId in profile.data.equipped do
		local pet = profile.data.pets[petId]
		if pet and pet.species == species then
			level = math.max(level, if pet.golden then 2 else 1)
		end
	end
	return level
end

-- Multiplier for a fish this player catches.
function Pets.fishMultiplier(player: Player): number
	return 1 + SETTINGS.fishBonus * perkLevel(player, "pufferfish")
end

-- What other players' clients need to draw this player's followers: "seahorse,octopus:golden".
local function publish(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local shown = {}
	for _, petId in profile.data.equipped do
		local pet = profile.data.pets[petId]
		if pet then
			table.insert(shown, if pet.golden then pet.species .. ":golden" else pet.species)
		end
	end
	player:SetAttribute("EquippedPets", table.concat(shown, ","))
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function onBuyEgg(player: Player, eggId: unknown)
	if not RateLimit.consume(player, 2) or type(eggId) ~= "string" then
		return
	end
	local egg = ReefConfig.EggById[eggId]
	local profile = PlayerData.get(player)
	if not egg or not profile then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - hatchery.Position).Magnitude > ReefConfig.INTERACT_DISTANCE then
		Plots.notify(player, "Walk over to the Pet Hatchery to buy eggs.")
		return
	end
	if count(profile.data.pets) >= SETTINGS.maxOwned then
		Plots.notify(player, `You have {SETTINGS.maxOwned} pets, the most you can keep. Release one first.`)
		return
	end
	local wallet = { shells = profile.data.shells }
	if not EconomyMath.trySpend(wallet, { shells = egg.price }) then
		Plots.notify(player, "Not enough shells.")
		return
	end
	-- No yields between the checks above and these writes.
	profile.data.shells = wallet.shells
	local pet = {
		species = EconomyMath.pickWeighted(egg.odds, rng:NextNumber()),
		golden = rng:NextNumber() < SETTINGS.goldenChance,
	}
	profile.data.petSeq += 1
	profile.data.pets[tostring(profile.data.petSeq)] = pet
	local name = petName(pet)
	local article = if string.find(name, "^[AEIOU]") then "an" else "a"
	Plots.notify(player, `You hatched {article} {name}!`, if pet.golden then "rare" else "good")
	Quests.progress(player, "hatch", 1)
	PlayerData.sync(player)
end

local function onEquip(player: Player, petId: unknown, equip: unknown)
	if not RateLimit.consume(player) or type(petId) ~= "string" or type(equip) ~= "boolean" then
		return
	end
	local profile = PlayerData.get(player)
	if not profile or not profile.data.pets[petId] then
		return
	end
	local equipped = profile.data.equipped
	local at = table.find(equipped, petId)
	if equip and not at then
		if #equipped >= SETTINGS.maxEquipped then
			Plots.notify(player, `You can have {SETTINGS.maxEquipped} pets out at once. Put one away first.`)
			return
		end
		table.insert(equipped, petId)
	elseif not equip and at then
		table.remove(equipped, at)
	else
		return
	end
	publish(player)
	PlayerData.sync(player)
end

local function onRelease(player: Player, petId: unknown)
	if not RateLimit.consume(player, 2) or type(petId) ~= "string" then
		return
	end
	local profile = PlayerData.get(player)
	local pet = profile and profile.data.pets[petId]
	if not pet then
		return
	end
	profile.data.pets[petId] = nil
	local at = table.find(profile.data.equipped, petId)
	if at then
		table.remove(profile.data.equipped, at)
	end
	local shells = if pet.golden then SETTINGS.releaseShells.golden else SETTINGS.releaseShells.normal
	PlayerData.addShells(player, shells)
	Plots.notify(player, `You released your {petName(pet)} into the reef. +{EconomyMath.formatNumber(shells)} shells`)
	publish(player)
	PlayerData.sync(player)
end

function Pets.start(worldParts: World.WorldParts)
	hatchery = worldParts.hatcheryStand
	Remotes.BuyEgg.OnServerEvent:Connect(onBuyEgg)
	Remotes.EquipPet.OnServerEvent:Connect(onEquip)
	Remotes.ReleasePet.OnServerEvent:Connect(onRelease)
	PlayerData.onLoaded(function(player)
		publish(player)
	end)

	-- Perks that act over time. Seahorse: each second counts as extra seconds of growth.
	-- Octopus: harvests one grown coral when its timer runs out.
	local octopusTimers: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player)
		octopusTimers[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local seahorse = perkLevel(player, "seahorse")
				if seahorse > 0 then
					Plots.boostGrowth(SETTINGS.growthBonus * seahorse, player)
				end
				local octopus = perkLevel(player, "octopus")
				if octopus > 0 then
					local waited = (octopusTimers[player] or 0) + 1
					if waited >= SETTINGS.harvestEvery / octopus and Plots.harvestOne(player, "Your Octopus") then
						waited = 0
					end
					octopusTimers[player] = waited
				else
					octopusTimers[player] = nil
				end
			end
		end
	end)
end

return Pets
