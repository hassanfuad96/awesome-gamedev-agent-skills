-- Checks a built place: remotes, script classes, require targets, and the economy numbers.
-- Usage (from games/grow-a-reef): rojo build default.project.json -o GrowAReef.rbxlx
--                                 lune run tests/check_place.luau GrowAReef.rbxlx
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failures = 0
local function check(cond, msg) if cond then print("ok   " .. msg) else failures += 1; print("FAIL " .. msg) end end

-- 1. Place structure
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local rs = game:GetService("ReplicatedStorage")
for _, name in { "SelectSeed", "BuySeed", "ExpandReef", "PlantAt", "BuyEgg", "EquipPet", "ReleasePet", "RequestSync", "DataSync", "ShopSync", "Notify", "Teleport", "Teleported", "AdminAction", "Announcement", "BuyFence", "EquipFence", "BuyDecor", "PlaceDecor", "UpgradeGear", "ClaimQuest", "Rebirth", "EquipTitle", "GuideLine", "BuyMerchant", "BuyAbyssSeed", "ResearchSpecies", "ChooseSuit", "SetGiftTarget", "RedeemCode", "ClaimGroup", "WeeklyBoard", "Welcome", "VisitReef", "TradeRequest", "TradeAction", "TradeSync" } do
	local r = rs.Remotes:FindFirstChild(name)
	check(r and r.ClassName == "RemoteEvent", "remote " .. name)
end
local server = game:GetService("ServerScriptService").Server
check(server.Main.ClassName == "Script", "server Main is a Script")
for _, m in { "World", "PlayerData", "Plots", "Shop", "Fish", "Currents", "Leaderboard", "RateLimit", "ShopkeeperVisuals", "SeabedDecor", "Events", "EventState", "TreasureStorm", "ReefIndex", "Pets", "Teleport", "Shipwreck", "ShipwreckVisuals", "Admin", "Quests", "Supplies", "Likes", "Rebirth", "Tutorial", "RuinsWorld", "Ruins", "AbyssWorld", "Abyss", "Crew", "Outfits", "Suits", "WorldKit", "MainReef", "Collectibles", "Volcano", "GiantOctopus", "Merchant", "TreasureHunt", "EventVisuals", "KelpWorld", "Kelp", "Hub", "Research", "Oxygen", "CreatureModels", "Monetization", "Rewards", "Social" } do
	check(server:FindFirstChild(m) and server[m].ClassName == "ModuleScript", "server module " .. m)
end
local client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
check(client.Main.ClassName == "LocalScript", "client Main is a LocalScript")
for _, m in { "Swimming", "AdminPanel", "SuppliesPanel", "QuestsPanel", "NameTags", "TutorialPanel", "MerchantPanel", "RuinsPanel", "RuinsLife", "AbyssPanel", "AbyssLife", "Audio", "KelpPanel", "KelpLife", "LabPanel", "OxygenBar", "AquariumDisplay", "SuitPicker", "MarineCast", "CreatureAnimator", "StorePanel", "MenuButtons", "RewardsPanel", "SocialPanel" } do
	check(client:FindFirstChild(m) and client[m].ClassName == "ModuleScript", "client module " .. m)
end
check(rs.Shared.ReefConfig.ClassName == "ModuleScript", "shared ReefConfig")
for _, m in { "CoralVisuals", "FenceVisuals", "DecorVisuals", "RuinsConfig", "ReefSounds", "CreatureMeshes", "Creatures" } do
	check(rs.Shared:FindFirstChild(m) and rs.Shared[m].ClassName == "ModuleScript", "shared " .. m)
end
check(math.abs(game:GetService("Workspace").Gravity - 70) < 0.01, "Workspace.Gravity = 70")

-- 2. Every require(script.Parent.X) / Shared.X points at a real sibling
for _, s in game:GetDescendants() do
	if s:IsA("LuaSourceContainer") then
		local src = s.Source
		for name in string.gmatch(src, "require%(script%.Parent%.(%w+)%)") do
			check(s.Parent:FindFirstChild(name) ~= nil, s.Name .. " requires " .. name)
		end
		for name in string.gmatch(src, "require%(ReplicatedStorage%.Shared%.(%w+)%)") do
			check(rs.Shared:FindFirstChild(name) ~= nil, s.Name .. " requires Shared." .. name)
		end
	end
end

-- 3. Config and economy logic, run for real with Lune's Roblox datatypes
local env = { Color3 = roblox.Color3, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, math = math, string = string, table = table, pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, tonumber = tonumber, error = error, setmetatable = setmetatable }
local function load(path) return luau.load(fs.readFile(path), { debugName = path, environment = env })() end
local Config = load("src/shared/ReefConfig.luau")
local Econ = load("src/shared/EconomyMath.luau")

check(Config.harvestValue("brain", "Golden") == 375, "Golden Brain Coral sells for 375")
check(Config.harvestValue("nope", "None") == 0, "unknown seed sells for 0")
check(Config.STARTING_SLOTS == 20 and Config.MAX_SLOTS == 30 and #Config.Planters == 30, "reefs start with 20 planters and unlock up to 30")
check(Config.expandCost(20) == 1000 and Config.expandCost(21) == 1550 and Config.expandCost(29) == 51639, "planters cost 1,000, 1,550 ... 51,639 shells")
check(Config.expandPearls(20) == 1 and Config.expandPearls(21) == 1 and Config.expandPearls(22) == 2 and Config.expandPearls(29) == 5, "planters cost 1, 1, 2, 2 ... 5 pearls")
local plantersApart, plantersInside = true, true
for i, a in Config.Planters do
	plantersInside = plantersInside and math.sqrt(a.x * a.x + a.z * a.z) + Config.PLANTER_RADIUS <= Config.BED_RADIUS
	for j, b in Config.Planters do
		if i < j then
			plantersApart = plantersApart and math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= Config.PLANTER_RADIUS * 2 + 2
		end
	end
end
check(plantersApart and plantersInside, "planters sit on the bed with room to walk between them")
check(Config.Planters[1].x == 0 and Config.Planters[1].z == 0 and Config.planterAt(0.5, 0.5) == 1 and Config.planterAt(5, 0) == nil, "the first planter is in the middle; between planters is no planter")
check(Config.growthStage(0) == 1 and Config.growthStage(0.34) == 1 and Config.growthStage(0.5) == 2 and Config.growthStage(0.999) == 2 and Config.growthStage(1) == 3, "coral grows through seedling, growing and fully grown")
local maxReach = Config.bedRadius(Config.MAX_SLOTS) + 7
-- The Starter Lagoon: reefs in a ring round the plaza, buildings in between.
local Lagoon = Config.Lagoon
local V3 = roblox.Vector3
local function flat(v) return V3.new(v.X, 0, v.Z) end
local ringOk, gatesOk, insideOk = true, true, true
for i = 1, Config.PLOT_COUNT do
	local frame = Config.plotFrame(i)
	local nextFrame = Config.plotFrame(i % Config.PLOT_COUNT + 1)
	ringOk = ringOk and (frame.Position - nextFrame.Position).Magnitude >= maxReach * 2 + 4
	local toRoad = roblox.Vector3.new(0, 0, -frame.Position.Z).Unit
	gatesOk = gatesOk and frame.LookVector:Dot(toRoad) > 0.999
	local p = frame.Position
	insideOk = insideOk and p.X - maxReach > Config.SeaLife.area.minX and p.X + maxReach < Config.MainReef.roadFrom
		and math.abs(p.Z) + maxReach < Config.MainReef.ridgeZ and math.abs(p.Z) - maxReach > Config.MainReef.roadWidth / 2
end
check(ringOk, "neighbouring reef mounds don't overlap")
check(gatesOk, "every reef's gate (local -Z) faces the Main Reef's road")
check(insideOk, "the reefs fit between the road and the ridges, inside the sea area")
local spotsOk = true
for _, spot in Config.MainReef.fishSpots do
	spotsOk = spotsOk and not Config.nearPlot(spot.X, spot.Z, 6) and math.abs(spot.Z) < Config.MainReef.ridgeZ - 20
end
for _, x in Config.MainReef.bridges do
	spotsOk = spotsOk and not Config.nearPlot(x, 0, 0) and x < Config.MainReef.roadFrom and x > Config.MainReef.roadTo
end
check(spotsOk, "fish nurseries and coral bridges stand clear of the reefs")
local buildings = { guide = 4, research = Lagoon.labRadius + 4, aquarium = 30, upgrade = 26, coralShop = 30, oceanGate = 30, boards = 34 }
for name, radius in buildings do
	local at = Lagoon[name]
	check(not Config.nearPlot(at.X, at.Z, radius), "the " .. name .. " stands clear of every reef")
end
check((Lagoon.guide - Lagoon.center).Magnitude < Config.SHOPKEEPER_GREET_DISTANCE, "Kai is close enough to the spawn to greet new players")
-- The hub: four buildings in the four quadrants, the Lab the biggest, the roads on the axes.
check(Lagoon.research.X < -40 and Lagoon.research.Z < -40, "the Research Laboratory is north-west")
check(Lagoon.aquarium.X > 40 and Lagoon.aquarium.Z < -40, "the Aquarium is north-east")
check(Lagoon.coralShop.X > 40 and Lagoon.coralShop.Z > 40, "the Coral Market is south-east")
check(Lagoon.upgrade.X < -40 and Lagoon.upgrade.Z > 40, "the Equipment Station is south-west")
local hubRadii = { research = Lagoon.labRadius, aquarium = 25, coralShop = 25, upgrade = 22 }
local hubClear = true
for key, radius in hubRadii do
	local at = Lagoon[key]
	hubClear = hubClear and math.abs(at.X) - radius > 12 and math.abs(at.Z) - radius > 12
		and roblox.Vector3.new(at.X, 0, at.Z).Magnitude + radius < Lagoon.rimRadius - 10
		and roblox.Vector3.new(at.X, 0, at.Z).Magnitude - radius > Lagoon.plazaRadius + 10
	if key ~= "research" then
		hubClear = hubClear and radius < Lagoon.labRadius
	end
end
check(hubClear, "the hub's buildings sit between the plaza and the rim, clear of the roads, the Lab the biggest")
-- Species research and the new gear.
local fresh = { research = {}, index = { coral = {} } }
check(Config.speciesUnlocked(fresh, "kelp") and not Config.speciesUnlocked(fresh, "brain"), "only Bubble Kelp is known at the start")
check(Config.researchProblem(fresh, "brain") ~= nil and Config.researchProblem({ research = {}, index = { coral = { [Config.inventoryKey("kelp", "None")] = true } } }, "brain") == nil, "researching a species needs the one before it grown")
check(Config.researchProblem({ research = {}, index = { coral = {} } }, "fan") ~= nil and Config.researchProblem(fresh, "ghost") ~= nil, "species research goes in order, and special coral can't be researched")
local researchOk = true
for _, seedId in Config.Research.order do
	researchOk = researchOk and Config.Seeds[seedId] ~= nil and Config.Seeds[seedId].shop ~= false
	researchOk = researchOk and (seedId == Config.Research.free or (Config.Research.costs[seedId] or 0) > 0)
end
check(researchOk, "every researchable species is a shop coral with a research cost")
check(Config.oxygenCapacity(0) == Config.Oxygen.base and Config.oxygenCapacity(#Config.Gear.oxygen.costs) > Config.Oxygen.base * 3, "the Oxygen Tank gives several times the air")
check(Config.swimSpeedMultiplier(0) == 1 and Config.swimSpeedMultiplier(#Config.Gear.fins.costs) > 1.3, "Swim Fins make you faster")
local stationsOk = true
for _, gearId in Config.GEAR_ORDER do
	stationsOk = stationsOk and (Config.GearStation[gearId] == "lab" or Config.GearStation[gearId] == "equipment")
end
check(stationsOk and Config.GearStation.fertilizer == "lab" and Config.GearStation.fins == "equipment", "every piece of gear is sold at the Lab or the Equipment Station")
check(Lagoon.oceanGate.X < -60 and math.abs(Lagoon.oceanGate.Z) < 10, "the Ocean Gate is on the west side")
local frame3 = Config.plotFrame(3)
local x3, z3 = Config.plotOffset(frame3, Config.plotPoint(frame3, 12.5, -7.25, 1.4))
check(math.abs(x3 - 12.5) < 1e-6 and math.abs(z3 + 7.25) < 1e-6, "plot offsets round-trip through world space on a turned reef")
check(Config.STARTING_SEEDS.kelp == nil and Config.Tutorial.firstSeeds.kelp == 3, "new players get their first seeds from Kai")
local actions = {}
for _, step in Config.Tutorial.steps do table.insert(actions, step.action) end
check(table.concat(actions, ",") == "guide,plant,sell,fish,upgrade", "tutorial: seed, plant, sell, fish, expand")
check(Config.plantProblem(0, 0, 10, {}) == nil, "coral fits in the middle of an empty bed")
local p20, p21 = Config.Planters[20], Config.Planters[21]
check(Config.plantProblem(p20.x, p20.z, 20, {}) == nil and Config.plantProblem(p21.x, p21.z, 20, {}) ~= nil, "coral goes in unlocked planters only")
check(Config.Swim.speed > 16 and Config.Swim.rise > 0 and Config.Swim.sink > 0, "swimming is faster than walking (16)")
local pad = Config.Teleport.shopsPad
check(Config.Teleport.cooldown > 0 and (pad - Lagoon.coralShop).Magnitude < 40 and (pad - Lagoon.coralShop).Magnitude > 20, "teleport has a cooldown and the shops pad sits in front of the Coral Shop")
check(Config.adminRole(5067168140) == "Owner" and Config.adminRole(1) == nil, "far_rel2017 (5067168140) is the owner; others are not admins")
local giftsOk = #Config.Admin.giftShells > 0
for _, amount in Config.Admin.giftShells do giftsOk = giftsOk and amount > 0 and amount % 1 == 0 end
check(giftsOk and Config.Admin.announceMaxLength <= 200, "admin gift amounts and announcement length are sane")
local fence = Config.FenceById[Config.DEFAULT_FENCE]
check(fence ~= nil and fence.name == "Shipwreck Wood" and #fence.plankColors > 0, "the default fence is Shipwreck Wood")
for _, style in Config.Fences do
	check(style.height > 0 and style.postSpacing > 0 and style.rails >= 1 and type(style.material) == "string", "fence " .. style.id .. " has a height, post spacing, rails and a material")
end
local taken, takenSlot = Config.plantProblem(0, 0, 20, { { slot = 1 } })
check(taken ~= nil and takenSlot == 1 and Config.plantProblem(0, 0, 20, { { slot = 2 } }) == nil, "one coral per planter")
check(Config.plantProblem(5, 0, 20, {}) ~= nil, "coral can't go between planters")
local s, m = Config.splitInventoryKey(Config.inventoryKey("star", "Prismatic"))
check(s == "star" and m == "Prismatic", "inventory key round trip")
check(Config.splitInventoryKey("bad key") == nil, "malformed inventory key rejected")
for _, id in Config.SEED_ORDER do
	local seed = Config.Seeds[id]
	check(seed and seed.sellValue > seed.price and seed.stockMin <= seed.stockMax, "seed " .. id .. " is profitable and has a valid stock range")
end
local odds = Econ.oddsPercent(Config.Mutations)
check(math.abs(odds.None + odds.Glowing + odds.Golden + odds.Prismatic - 100) < 1e-9, string.format("mutation odds sum to 100 (Glowing %.1f%%, Golden %.1f%%, Prismatic %.1f%%)", odds.Glowing, odds.Golden, odds.Prismatic))
local counts = {}
math.randomseed(1)
for _ = 1, 200000 do local id = Econ.pickWeighted(Config.Mutations, math.random()); counts[id] = (counts[id] or 0) + 1 end
check(math.abs(counts.Golden / 200000 * 100 - odds.Golden) < 0.2, string.format("200k rolls: Golden %.2f%% vs %.2f%% expected", counts.Golden / 2000, odds.Golden))
local reefFish = {}
for _, kind in Config.Fish.kinds do if kind.weight > 0 then table.insert(reefFish, kind) end end
local fishWeights = Econ.oddsPercent(reefFish)
check(fishWeights.Moonfish == 2, "Moonfish odds 2%")
local eventIds = {}
for _, event in Config.Events.list do
	check(Config.EventById[event.id] == event and event.duration > 0 and event.weight > 0, "sea event " .. event.id .. " is listed with a duration and weight")
	table.insert(eventIds, event.id)
end
check(table.concat(eventIds, ",") == "Current,Cold,Night,Frenzy,Treasure,Whale,Volcano,Octopus,Merchant,Hunt,Shipwreck", "eleven sea events")
local eventOdds = Econ.oddsPercent(Config.Events.list)
local weightTotal = 0
for _, event in Config.Events.list do weightTotal += event.weight end
check(weightTotal == 100 and math.abs(eventOdds.Shipwreck - 5) < 1e-9, "event weights add up to 100; Shipwreck is picked 5% of the time")

-- Volcano, Giant Octopus, Mermaid Merchant, Sunken Treasure Hunt
check(Config.MutationById.Molten ~= nil and Config.MutationById.Molten.multiplier == 6 and Config.MutationById.Molten.weight == 0, "Molten (x6) only comes from the Volcano Vent")
check(Config.Volcano.moltenChance > 0 and Config.Volcano.moltenChance <= 1 and Config.Volcano.every > 0, "volcano rocks have a Molten chance and a volley timer")
local volcanoFromCenter = roblox.Vector3.new(Config.Volcano.vent.X, 0, Config.Volcano.vent.Z).Magnitude
check(volcanoFromCenter > (Lagoon.rimRadius or Config.Hunt.rimFallback) + Config.Volcano.height * 0.75, "the volcano stands out past the lagoon's rim")
check(Config.Octopus.minHits * 1 / Config.Octopus.hitsPerSecond < Config.EventById.Octopus.duration and Config.Octopus.baseHealth > 0, "a player can land enough hits on the octopus before it leaves")
local soloSeconds = (Config.Octopus.baseHealth + Config.Octopus.healthPerPlayer) / Config.Octopus.hitsPerSecond
check(soloSeconds < Config.EventById.Octopus.duration, string.format("one diver tapping flat out can beat the octopus (%.0f s of %d)", soloSeconds, Config.EventById.Octopus.duration))
for _, gift in Config.Octopus.seeds do check(Config.Seeds[gift.id] ~= nil, "octopus seed " .. gift.id .. " exists") end
local sureOffers = 0
for _, offer in Config.Merchant.offers do
	local seed = Config.Seeds[offer.seed]
	check(Config.MerchantOfferById[offer.id] == offer and seed ~= nil and offer.count > 0 and offer.price > 0 and offer.chance > 0 and offer.chance <= 1, "merchant offer " .. offer.id .. " is a real seed with a price and chance")
	if offer.chance >= 1 then sureOffers += 1 end
	if seed and seed.shop ~= false then
		check(offer.price < seed.price * offer.count, "merchant offer " .. offer.id .. " is cheaper than the Seed Shop")
	end
end
check(sureOffers >= 1 and Config.Merchant.offersPerVisit >= 1, "Marina always brings at least one offer")
check(Config.Hunt.secondClueAt < Config.EventById.Hunt.duration and Config.Hunt.heat.burning < Config.Hunt.heat.hot and Config.Hunt.heat.hot < Config.Hunt.heat.warm, "the hunt's second clue comes in time, and heat bands are in order")
check(Config.huntHeat(5) == "Burning hot!" and Config.huntHeat(30) == "Hot" and Config.huntHeat(60) == "Warm" and Config.huntHeat(500) == "Cold", "hunt heat readings")
check(Config.compass(0, -10) == "north" and Config.compass(10, 0) == "east" and Config.compass(10, 10) == "south-east" and Config.compass(-10, -10) == "north-west", "compass directions (north is -Z)")
for _, key in { "research", "upgrade", "coralShop", "oceanGate" } do
	local at = Lagoon[key]
	check(typeof(at) ~= "Vector3" or roblox.Vector3.new(at.X, 0, at.Z).Magnitude < (Lagoon.rimRadius or Config.Hunt.rimFallback), "landmark " .. key .. " is inside the lagoon, so hunt clues can point at it")
end
local ship = Config.Shipwreck
check(Config.EventById.Shipwreck.duration == ship.huntStartsAt + ship.huntSeconds + 5 and ship.sinkSeconds < ship.huntStartsAt, "Shipwreck: sink, then hide, hunt and 5 s for the orcas to leave")
check(ship.orcaSpeed > Config.Swim.speed, "orcas are faster than swimming, so hiding is the way to survive")
local reward = Config.Seeds[ship.reward.seed]
check(reward ~= nil and reward.shop == false and reward.rarity == "Transcendent" and reward.stockChance == 0, "the reward seed is Transcendent and never in the shop")
local rest = roblox.CFrame.new(ship.landing)
check(Config.insideShipwreck(rest, ship.landing + roblox.Vector3.new(10, 5, 3)) and not Config.insideShipwreck(rest, ship.landing + roblox.Vector3.new(0, 5, 20)) and not Config.insideShipwreck(rest, ship.landing + roblox.Vector3.new(0, 30, 0)), "inside the hull is hidden; beside or above it is not")
local landingClear = true
for dx = -ship.length / 2, ship.length / 2, 10 do
	landingClear = landingClear and not Config.nearPlot(ship.landing.X + dx, ship.landing.Z, ship.width / 2)
end
check(landingClear and ship.landing.X - ship.length / 2 > 255 and ship.landing.X + ship.length / 2 < Config.SeaLife.area.maxX, "the wreck lands in the Sunken Ruins, east of the lagoon, inside the sea area")

-- Stacked mutations
check(Config.harvestValue("kelp", "Glowing+Golden") == 180, "Glowing + Golden Bubble Kelp sells at x10 (180)")
check(Config.withMutation("Golden", "Glowing") == "Glowing+Golden", "adding Glowing to Golden gives Glowing+Golden")
check(Config.withMutation("Glowing+Golden", "Shadow") == nil, "a coral holds at most two mutations")
check(Config.withMutation("Golden", "Golden") == nil, "the same mutation can't stack twice")
check(Config.withMutation("None", "Frosted") == "Frosted", "an event mutation lands on plain coral")
check(Config.isMutationKey("Golden+Glowing") == false and Config.isMutationKey("Glowing+Golden"), "mutation keys are in alphabetical order")
check(Config.isMutationKey("Glowing+Glowing") == false and Config.isMutationKey("Nope") == false, "bad mutation keys are rejected")
local cs, cm = Config.splitInventoryKey(Config.inventoryKey("star", "Prismatic+Shadow"))
check(cs == "star" and cm == "Prismatic+Shadow", "combo inventory key round trip")
check(Config.displayName("kelp", "Glowing+Golden") == "Glowing + Golden Bubble Kelp", "combo display name")
check(#Config.MUTATION_KEYS == 22, "22 mutation keys (none, 6 singles, 15 pairs)")

-- Reef Index
local indexEntries = 0
for _, set in Config.IndexSets do
	indexEntries += #set.entries
end
-- One set per seed (every mutation key) plus the fish set, whatever seeds and fish exist.
local expectedEntries = #Config.SEED_ORDER * #Config.MUTATION_KEYS + #Config.Fish.kinds
check(#Config.IndexSets == #Config.SEED_ORDER + 1 and indexEntries == expectedEntries, string.format("Reef Index: %d sets (every seed and the fish), %d entries", #Config.IndexSets, indexEntries))

-- Pet eggs: every outcome is a real pet and the shown odds sum to 100
for _, egg in Config.Pets.eggs do
	local eggOdds = Econ.oddsPercent(egg.odds)
	local sum = 0
	for id, percent in eggOdds do
		check(Config.Pets.species[id] ~= nil, "egg " .. egg.id .. " outcome " .. id .. " is a pet")
		sum += percent
	end
	check(math.abs(sum - 100) < 1e-9 and egg.price > 0, "egg " .. egg.id .. " odds sum to 100")
end
for _, entry in Config.Events.treasure.seeds do
	check(Config.Seeds[entry.id] ~= nil and entry.count >= 1, "treasure seed " .. entry.id .. " exists")
end

-- Fences, decorations and gear
local fenceIds = {}
for _, style in Config.Fences do
	table.insert(fenceIds, style.id)
	check(style.kind == "planks" or style.kind == "hedge" or style.kind == "wall" or style.kind == "ribs" or style.kind == "crystal", "fence " .. style.id .. " has a known kind")
	check(style.price >= 0 and (style.shop == false or style.price > 0 or style.id == Config.DEFAULT_FENCE), "fence " .. style.id .. " is free (default), priced, or an Index reward")
end
check(table.concat(fenceIds, ",") == "shipwood,kelp,coralstone,whalebone,crystal,royal", "six fence styles (the last from the VIP pass)")
for _, item in Config.Decor.items do
	check(Config.DecorById[item.id] == item and item.price > 0 and item.footprint > 0, "decoration " .. item.id .. " has a price and footprint")
end
local mound = Config.moundRadius()
check(Config.decorProblem("anchor", 38, 10, {}, {}) == nil, "a decoration fits round the planters")
check(Config.decorProblem("anchor", mound, 0, {}, {}) ~= nil, "decorations stay inside the fence")
check(Config.decorProblem("lantern", 0, -mound + 4, {}, {}) ~= nil, "the gateway stays clear")
check(Config.decorProblem("anchor", 0, 0, {}, {}) ~= nil and Config.decorProblem("lantern", 5, 0, {}, {}) ~= nil, "decorations can't go on or right beside a planter")
check(Config.decorProblem("anchor", 38, 10, {}, { { item = "chest", x = 38, z = 13 } }) ~= nil and Config.decorProblem("anchor", 38, 10, {}, { { item = "chest", x = 38, z = 16 } }) == nil, "decorations keep their footprints apart")
local manyDecor = {}
for i = 1, Config.Decor.maxPlaced do manyDecor[tostring(i)] = { item = "lantern", x = 100 * i, z = 0 } end
check(Config.decorProblem("lantern", 0, 0, {}, manyDecor) ~= nil, "a reef holds at most " .. Config.Decor.maxPlaced .. " decorations")
for _, gearId in Config.GEAR_ORDER do
	local costs = Config.Gear[gearId].costs
	local rising = #costs > 0
	for i = 2, #costs do rising = rising and costs[i] > costs[i - 1] end
	check(rising, "gear " .. gearId .. " costs rise with each level")
end
check(Config.bagCapacity(0) >= 30 and Config.bagCapacity(5) > Config.bagCapacity(0), "the bag holds 30 coral, more with upgrades")
check(Config.bagCapacity(1) >= Config.MAX_SLOTS, "one bag upgrade holds a full 50-coral reef")
check(math.abs(Config.wandBoost(1, 1200) - 13) < 1e-9 and Config.wandBoost(0, 1200) == 0, "Bubble Wand level 1 gives 1 s + 1% (13 s for Starlight)")

-- Daily quests
local q1, q2 = Config.dailyQuests(20000), Config.dailyQuests(20000)
check(#q1 == Config.Quests.perDay and table.concat(q1, ",") == table.concat(q2, ","), "a day's quests are the same every time")
local distinct, valid = {}, true
for _, id in q1 do valid = valid and Config.QuestById[id] ~= nil and not distinct[id]; distinct[id] = true end
check(valid, "a day's quests are real and all different")
local varied = false
for day = 20001, 20010 do varied = varied or table.concat(Config.dailyQuests(day), ",") ~= table.concat(q1, ",") end
check(varied, "quests change from day to day")
check(Config.questShells(Config.QuestById.plant, 20) == 150 and Config.questShells(Config.QuestById.plant, 30) == 450, "quest rewards grow with your reef (x1 at 20 planters, x3 at 30)")
check(Config.Collectibles.shells.min > 0 and Config.Collectibles.shells.max >= Config.Collectibles.shells.min and Config.Collectibles.pearls.count > 0, "shells and pearls to collect in the Main Reef")
for _, quest in Config.Quests.pool do
	check(quest.goal > 0 and quest.shells > 0 and string.find(quest.text, "%%d") ~= nil and (not quest.seed or Config.Seeds[quest.seed.id] ~= nil), "quest " .. quest.id .. " has a goal, reward and text")
end

-- Rebirth, titles and Index rewards
check(Config.rebirthCost(0) == 500000 and Config.rebirthCost(1) == 1500000 and Config.rebirthCost(2) == 4500000, "rebirths cost 500K, 1.5M, 4.5M ...")
check(Config.shellMultiplier(0) == 1 and Config.shellMultiplier(2) == 1.5, "each rebirth adds +25% shells")
for setId, reward in Config.IndexRewards do
	local setExists = false
	for _, set in Config.IndexSets do setExists = setExists or set.id == setId end
	local ok = setExists
		and (not reward.title or Config.TitleById[reward.title] ~= nil)
		and (not reward.fence or Config.FenceById[reward.fence] ~= nil)
		and (not reward.decor or Config.DecorById[reward.decor.id] ~= nil)
		and (not reward.pet or Config.Pets.species[reward.pet.species] ~= nil)
	check(ok and Config.indexRewardText(setId) ~= nil, "Index reward for " .. setId .. " is real: " .. tostring(Config.indexRewardText(setId)))
end
for _, set in Config.IndexSets do
	check(Config.IndexRewards[set.id] ~= nil, "Index set " .. set.id .. " has a reward")
end
check(Config.FenceById.crystal.shop == false and Config.IndexRewards.anemone.fence == "crystal", "the Glow Crystal fence comes only from the Index")

-- The Sunken Ruins (RuinsConfig): layout, the save, missions and the creatures' paths
local Ruins = load("src/shared/RuinsConfig.luau")
check((Ruins.Places.basin - ship.landing).Magnitude < 1e-6, "the Shipwreck lands in the ruins' Wreck Basin")
check(Ruins.inRuins(ship.landing) and Ruins.inRuins(Ruins.Places.entrance) and not Ruins.inRuins(Lagoon.center), "the basin and entrance are in the ruins; the plaza isn't")
check(Ruins.center.X - Ruins.radius >= 250 and Ruins.Places.entrance.X < Ruins.center.X and Ruins.roadFromX < Ruins.Places.entrance.X, "the ruins sit east of the lagoon (x > 250), entrance and road on the lagoon side")
check(Ruins.center.X + Ruins.radius <= Config.SeaLife.area.maxX + 5, "the ruins fit inside the sea area")
local allIn = true
for _, spot in Ruins.Chests.spots do allIn = allIn and Ruins.inRuins(spot.at) end
for _, spot in Ruins.HiddenCoral do allIn = allIn and Ruins.inRuins(spot.at) and Config.Seeds[spot.seed] ~= nil and Config.Seeds[spot.seed].shop == false end
for _, relic in Ruins.Relics.list do allIn = allIn and Ruins.inRuins(relic.at) end
check(allIn, "every chest, hidden coral and relic is in the ruins, and hidden coral is a seed sold nowhere")
check(Ruins.inCave(Ruins.Places.cave + V3.new(3, 4, 2)) and not Ruins.inCave(Ruins.Places.cave + V3.new(0, 30, 0)) and Ruins.inCave(Ruins.HiddenCoral[1].at), "the cave holds its Ghost Coral; above it isn't inside")
check(Ruins.aboardShip(Ruins.shipPoint(0, 5, 0)) and not Ruins.aboardShip(Ruins.shipPoint(0, 5, 20)) and Ruins.aboardShip(Ruins.Relics.list[1].at + V3.new(0, 1, 0)), "the ship's hold counts as aboard (the compass is in it); beside it doesn't")
local ok = true
for _, entry in Ruins.Chests.seeds do ok = ok and Config.Seeds[entry.id] ~= nil and entry.count >= 1 end
check(ok and Ruins.Chests.cooldown > 0, "ruins chest seeds exist")
local fresh = Ruins.newState()
check(fresh.mission == 1 and Ruins.Missions[1].done(fresh) == false, "a new diver starts on the first mission, not done")
local bad = Ruins.sanitize({ mission = 99, opened = -5, relics = { crown = true, nope = true }, chests = { gate = 123, fake = 1 }, cuttings = { cave1 = "x" }, visited = { reach = true, moon = true }, sighted = { squid = 1 } })
check(bad.mission == #Ruins.Missions + 1 and bad.opened == 0 and bad.relics.crown and not bad.relics.nope and bad.chests.gate == 123 and bad.chests.fake == nil and bad.cuttings.cave1 == nil and bad.visited.reach and not bad.visited.moon and not bad.sighted.squid, "a bad ruins save is repaired")
check(Ruins.sanitize(nil).mission == 1, "a missing ruins save starts fresh")
check(Ruins.chestWait({ chests = { gate = 1000 } }, "gate", 1000 + Ruins.Chests.cooldown - 5) == 5 and Ruins.chestWait({ chests = {} }, "gate", 0) == 0, "chests refill after the cooldown")
local cave1, sanctum = Ruins.HiddenCoral[1], Ruins.HiddenCoral[3]
check(Ruins.cuttingProblem(fresh, cave1, 100) == nil and Ruins.cuttingProblem({ cuttings = { cave1 = 100 }, relics = {} }, cave1, 100) ~= nil and Ruins.cuttingProblem({ cuttings = { cave1 = 99 }, relics = {} }, cave1, 100) == nil, "one cutting a day from each spot")
local allRelics = {}
for _, relic in Ruins.Relics.list do allRelics[relic.id] = true end
check(Ruins.cuttingProblem(fresh, sanctum, 100) ~= nil and Ruins.cuttingProblem({ cuttings = {}, relics = allRelics }, sanctum, 100) == nil, "the Relic Coral needs every relic")
local missionsOk, ids = true, {}
for _, mission in Ruins.Missions do
	table.insert(ids, mission.id)
	missionsOk = missionsOk and mission.reward.shells > 0 and (not mission.reward.title or Config.TitleById[mission.reward.title] ~= nil)
	for seedId in mission.reward.seeds or {} do missionsOk = missionsOk and Config.Seeds[seedId] ~= nil end
end
check(missionsOk and table.concat(ids, ",") == "reach,chest,relic,cave,coral,creature,ship,relics,creatures", "nine exploration missions with real rewards")
local everything = { mission = 1, visited = { reach = true, cave = true, ship = true }, opened = 1, cut = 1, relics = allRelics, sighted = { coelacanth = true, angler = true, seadragon = true, squid = true }, chests = {}, cuttings = {} }
local allDone = true
for _, mission in Ruins.Missions do allDone = allDone and mission.done(everything) end
check(allDone, "doing everything finishes every mission")
local inPlace, squidUp, squidDown = true, Ruins.creaturePosition("squid", 30), Ruins.creaturePosition("squid", Ruins.Creatures.squidSeconds + 10)
for _, creature in Ruins.Creatures.list do
	for t = 0, 600, 7 do
		local p = Ruins.creaturePosition(creature.id, t)
		inPlace = inPlace and (p == nil or (Ruins.inRuins(p) and p.Y < 80))
	end
end
check(inPlace and squidUp ~= nil and squidDown == nil and squidUp.Y > 20, "creatures stay in the ruins; the squid comes up only for part of each cycle")
local anglerIn = true
for t = 0, 120, 3 do anglerIn = anglerIn and Ruins.inCave(Ruins.creaturePosition("angler", t)) end
check(anglerIn, "the Anglerfish never leaves the cave")
check(Config.Shopkeepers.Explorer ~= nil and Config.Seeds.ghost.rarity == "Mythic" and Config.Seeds.relic.rarity == "Ancient" and Config.IndexRewards.ghost and Config.IndexRewards.relic, "Marlo, the two hidden seeds and their Index rewards are configured")

-- Sounds: every id is a real asset number, and event music belongs to real events
local Sounds = load("src/shared/ReefSounds.luau")
local soundDefs = { Sounds.ambience, Sounds.orcaMusic }
for _, def in Sounds.playlist do table.insert(soundDefs, def) end
for _, def in Sounds.eventMusic do table.insert(soundDefs, def) end
for _, def in Sounds.effects do table.insert(soundDefs, def) end
local soundsOk = #Sounds.playlist > 0
for _, def in soundDefs do
	soundsOk = soundsOk and type(def.id) == "number" and def.id > 0 and def.id % 1 == 0 and (def.volume == nil or (def.volume > 0 and def.volume <= 1))
end
check(soundsOk, string.format("%d sounds have asset ids and sane volumes", #soundDefs))
for eventId in Sounds.eventMusic do
	check(Config.EventById[eventId] ~= nil, "event music for " .. eventId .. " belongs to a real sea event")
end
for _, name in { "plant", "harvest", "sell", "buy", "hatch", "teleport", "swim", "place", "lava", "octopusHit", "dig", "reward", "bigReward", "eventStart", "clue" } do
	check(Sounds.effects[name] ~= nil, "sound effect " .. name)
end

-- The Abyss (AbyssConfig): layout, unlock, Lumi's seeds, creatures, the save
local Abyss = load("src/shared/AbyssConfig.luau")
local A = Abyss
check(A.Shelf.minZ >= 450 and A.Shelf.minZ > Lagoon.center.Z + 180, "the Abyss starts south of the lagoon and the shared seabed (z >= 450)")
check(A.Pit.minX > A.Shelf.minX and A.Pit.maxX < A.Shelf.maxX and A.Pit.minZ > A.Shelf.minZ and A.Pit.maxZ < A.Shelf.maxZ and A.FLOOR < -30, "the pit sits inside the shelf and goes deep")
local ruinsFar = math.abs(Ruins.center.X - A.center.X) > Ruins.radius + (A.Shelf.maxX - A.Shelf.minX) / 2 or math.abs(Ruins.center.Z - A.center.Z) > Ruins.radius + (A.Shelf.maxZ - A.Shelf.minZ) / 2
check(ruinsFar, "the Abyss and the Sunken Ruins don't overlap")
check(A.inPit(A.Places.spire + V3.new(0, 5, 0)) and A.inPit(A.Places.pad + V3.new(0, 3, 0)) and A.inPit(A.Places.shop) and not A.inPit(A.gate + V3.new(0, 3, 0)), "the spire, pad and Lumi's stall are in the pit; the gate isn't")
check(A.darkness(Lagoon.center) == 0 and A.darkness(A.gate) > 0 and A.darkness(A.Places.spire + V3.new(0, 3, 0)) > 0.95, "the sea darkens from the gate to the pit floor")
local slope = math.deg(math.atan2(A.Ramp.top.Y - A.Ramp.bottom.Y, (A.Ramp.bottom - A.Ramp.top).Magnitude))
check(A.Ramp.bottom.Y == A.FLOOR and A.Ramp.top.Y == 0 and slope < 25 and A.Ramp.top.Z > A.Pit.minZ, string.format("the ramp runs from the shelf to the floor at a walkable %.0f degrees", slope))
check(not A.meetsUnlock({ harvested = 0, ruins = { mission = 1 } }), "a new player can't enter the Abyss")
check(A.meetsUnlock({ harvested = 0, ruins = { mission = A.Unlock.exploration + 1 } }) and not A.meetsUnlock({ harvested = 0, ruins = { mission = A.Unlock.exploration } }), "Exploration Level " .. A.Unlock.exploration .. " (Ruins missions done) unlocks it")
check(A.meetsUnlock({ harvested = A.Unlock.reefHealth, ruins = { mission = 1 } }) and not A.meetsUnlock({ harvested = A.Unlock.reefHealth - 1 }), "Reef Health " .. A.Unlock.reefHealth .. " (coral harvested) unlocks it")
local shopOk = #A.SHOP_SEEDS == 3
local lastPrice = 0
for _, id in A.SHOP_SEEDS do
	local seed = Config.Seeds[id]
	shopOk = shopOk and seed ~= nil and seed.shop == false and seed.price > Config.Seeds.star.price and seed.price > lastPrice and seed.sellValue > seed.price and seed.rarity == "Abyssal" and Config.IndexRewards[id] ~= nil
	lastPrice = seed and seed.price or 0
end
check(shopOk, "Lumi sells three high-value Abyssal seeds, pricier than Starlight, never in the Coral Shop")
check(Config.Shopkeepers.Abyss ~= nil and Config.TitleById[A.Creatures.allReward.title] ~= nil and Config.Seeds[A.Creatures.allReward.seed] ~= nil, "Lumi and the all-creatures reward are configured")
local inAbyss = true
for _, creature in A.Creatures.list do
	for t = 0, 600, 5 do
		local p = A.creaturePosition(creature.id, t)
		inAbyss = inAbyss and p ~= nil and A.inZone(p) and p.Y > A.FLOOR and p.Y < 0
	end
end
check(inAbyss, "every deep-sea creature stays in the pit, above the floor")
local fixed = A.sanitize({ unlocked = true, sighted = { gulper = true, nessie = true, dumbo = 1 }, allRewarded = "yes" })
local pocketsOk = #A.AirPockets >= 2 and A.inAirPocket(A.Places.pad + V3.new(0, 3, 0)) and A.inAirPocket(A.Places.shop + V3.new(0, 3, 0)) and not A.inAirPocket(A.Places.brain + V3.new(0, 3, 0))
for _, pocket in A.AirPockets do pocketsOk = pocketsOk and A.inPit(pocket.position) and pocket.position.Y < -15 and pocket.radius > 0 end
check(pocketsOk, "air pockets sit in the deep part of the pit, at the pad and Lumi's stall")
check(fixed.unlocked and fixed.sighted.gulper and not fixed.sighted.nessie and not fixed.sighted.dumbo and fixed.allRewarded == false and A.sanitize(nil).unlocked == false, "a bad Abyss save is repaired")

-- Kelp Forest (zone 4): north of the lagoon, its own ecosystem.
local Kelp = load("src/shared/KelpConfig.luau")
local KV = roblox.Vector3
local function flatDistance(a, b) return KV.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end
check(Kelp.center.Z + Kelp.radius < -(Config.Lagoon.rimRadius + 30), "the Kelp Forest sits north of the lagoon's rim")
check(not Kelp.inForest(Config.Volcano.vent) and flatDistance(Kelp.center, Config.Volcano.vent) > Kelp.radius + 40, "the Kelp Forest stays clear of the Volcano")
check(flatDistance(Kelp.center, Ruins.center) > Kelp.radius + Ruins.radius, "the Kelp Forest stays clear of the Sunken Ruins")
local kelpClearOfReefs = true
for i = 1, Config.PLOT_COUNT do
	kelpClearOfReefs = kelpClearOfReefs and flatDistance(Kelp.center, Config.plotFrame(i).Position) > Kelp.radius + Config.moundRadius()
end
check(kelpClearOfReefs and Kelp.center.Z + Kelp.radius < -Config.MainReef.ridgeZ - 20, "the Kelp Forest stays clear of the Main Reef")
check(Kelp.entrance.Z > Kelp.center.Z and math.abs(Kelp.entrance.X) < 25 and flatDistance(Kelp.entrance, Kelp.center) <= Kelp.radius + 15, "the entrance is on the lagoon side, on the road north from the plaza")
local placesInside = true
for _, list in { Kelp.Glades, Kelp.Habitats, Kelp.Meadows } do
	for _, place in list do
		placesInside = placesInside and flatDistance(place.at, Kelp.center) + place.radius <= Kelp.radius + 15
	end
end
check(placesInside, "every glade, habitat and meadow is inside the forest")
local apart = true
local places = {}
for _, list in { Kelp.Glades, Kelp.Habitats, Kelp.Meadows } do
	for _, place in list do table.insert(places, place) end
end
for i, a in places do
	for j, b in places do
		if i < j then apart = apart and flatDistance(a.at, b.at) > a.radius + b.radius + 10 end
	end
end
check(apart, "glades, habitats and meadows don't overlap")
local kelpFish = 0
for _, kind in Config.Fish.kinds do
	if kind.kelpWeight then
		kelpFish += 1
		check(kind.weight == 0 and kind.kelpWeight > 0 and table.find(Kelp.FISH_IDS, kind.id) ~= nil, "kelp fish " .. kind.id .. " lives only in the forest")
	end
end
check(kelpFish == #Kelp.FISH_IDS and kelpFish == 5, "five kelp forest fish")
local rewardsOk = true
for _, challenge in Kelp.Challenges do
	for seedId in challenge.reward.seeds or {} do rewardsOk = rewardsOk and Config.Seeds[seedId] ~= nil end
	if challenge.reward.title then rewardsOk = rewardsOk and Config.TitleById[challenge.reward.title] ~= nil end
	rewardsOk = rewardsOk and challenge.reward.shells > 0
end
check(rewardsOk and #Kelp.Challenges == 8, "eight kelp challenges, every reward a real seed or title")
check(Config.Shopkeepers.Otto ~= nil, "Otto the sea otter is a shopkeeper")
local saved = Kelp.sanitize({ done = { reach = true, nope = true }, glades = { statue = true, x = true }, nests = { cove1 = 100, bad = 5 }, hatchlings = 2.7, restored = -3 })
check(saved.done.reach and not saved.done.nope and saved.glades.statue and not saved.glades.x and saved.nests.cove1 == 100 and saved.nests.bad == nil and saved.hatchlings == 2 and saved.restored == 0, "kelp saves are repaired, not trusted")
check(Kelp.nestWait(Kelp.newState(), "cove1", 1000) == 0 and Kelp.nestWait({ nests = { cove1 = 1000 } }, "cove1", 1000 + Kelp.nestCooldown - 5) == 5, "turtle nests rest between hatchlings")

-- The character roster: the human crew and the players' suits
local outfitSource = fs.readFile("src/server/Outfits.luau")
local crewOk = true
for kind, def in Config.Crew do
	crewOk = crewOk and Config.Shopkeepers[kind] ~= nil and Config.Shopkeepers[kind].name == def.name
		and string.find(outfitSource, "\n\t" .. def.outfit .. " = function", 1, true) ~= nil
		and string.find(outfitSource, def.skin .. " = Color3", 1, true) ~= nil and def.wander >= 0
end
check(crewOk, "every crew member has a shopkeeper entry with their name, a real outfit and a skin tone")
check(Config.Crew.SeedShop and Config.Crew.Guide and Config.Crew.Supplies and Config.Crew.Lab and Config.Crew.Explorer and Config.Shopkeepers.Sell.name == "Pinch", "Shopkeeper, Guide, Master Diver, Scientist and Explorer are crew; Pinch stays")
check(Config.Crew.Supplies.prompt and Config.Crew.Supplies.prompt.kind == "SuitPicker", "Captain Mako changes your diving suit")
local suitsOk = #Config.Suits.order == 2
for _, id in Config.Suits.order do
	local suit = Config.Suits.byId[id]
	suitsOk = suitsOk and suit ~= nil and suit.id == id and string.find(outfitSource, "\n\t" .. suit.outfit .. " = function", 1, true) ~= nil
end
check(suitsOk and Config.Suits.byId.blue and Config.Suits.byId.pink, "players pick the Blue or Pink Explorer suit, each a real outfit")
check(string.find(Config.Tutorial.steps[1].hint, "Kai", 1, true) ~= nil and string.find(fs.readFile("src/client/TutorialPanel.luau"), '"Kai"', 1, true) ~= nil, "the tutorial and its tracker point at Kai the guide")

-- The mesh creatures (catalog batches 1-7: catchable fish, pets, shopkeepers, event characters, Ruins, Abyss, Kelp fish, background life)
local CreatureMeshes = load("src/shared/CreatureMeshes.luau")
local roles = { body = true, tail = true, fin = true, flutter = true, dangle = true, fluke = true }
local meshesOk, meshCount = true, 0
for id, def in CreatureMeshes do
	meshCount += 1
	meshesOk = meshesOk and def.id == id and (def.style == "fish" or def.style == "whale" or def.style == "upright") and def.length > 0 and #def.pieces >= 1
	for _, piece in def.pieces do
		meshesOk = meshesOk and roles[piece.role] and string.match(piece.mesh, "^rbxassetid://%d+$") ~= nil and string.match(piece.texture, "^rbxassetid://%d+$") ~= nil
			and (piece.role ~= "fin" or piece.side == -1 or piece.side == 1)
	end
end
check(meshesOk and meshCount >= 5, "every mesh creature has asset ids, a size and a known role for each piece")
local fishMeshOk = true
for _, kind in Config.Fish.kinds do
	fishMeshOk = fishMeshOk and (kind.creature == nil or CreatureMeshes[kind.creature] ~= nil)
end
check(fishMeshOk and Config.Fish.kinds[1].creature == "minnow", "catchable fish point at real mesh creatures")
local petSource = fs.readFile("src/client/PetVisuals.luau")
local petsMeshOk = true
for species in Config.Pets.species do
	petsMeshOk = petsMeshOk and CreatureMeshes[species] ~= nil and string.find(petSource, species .. " = %d", 1, false) ~= nil
end
check(petsMeshOk, "every pet (seahorse, pufferfish, octopus) uses its mesh model")
local keeperSource = fs.readFile("src/server/ShopkeeperVisuals.luau")
local keepersOk = true
for kind, creature in { Sell = "crab", Otto = "otter", Abyss = "lanternfish" } do
	keepersOk = keepersOk and Config.Shopkeepers[kind] ~= nil and CreatureMeshes[creature] ~= nil
		and string.find(keeperSource, kind .. ' = { creature = "' .. creature .. '"', 1, true) ~= nil
end
check(keepersOk and string.find(fs.readFile("src/server/Main.server.luau"), "ShopkeeperVisuals.start()", 1, true) ~= nil, "Pinch, Otto and Lumi swap to their crab, otter and lanternfish meshes")

local eventsMeshOk = true
for file, creature in {
	["src/server/EventVisuals.luau"] = 'Creatures.clone("octopus", OCTOPUS_HEIGHT)',
	["src/server/ShipwreckVisuals.luau"] = 'Creatures.clone("orca")',
	["src/client/SeaLife.luau"] = 'Creatures.clone("whale")',
} do
	eventsMeshOk = eventsMeshOk and string.find(fs.readFile(file), creature, 1, true) ~= nil
end
local eventSource = fs.readFile("src/server/EventVisuals.luau")
eventsMeshOk = eventsMeshOk and string.find(eventSource, 'Creatures.clone("mermaid")', 1, true) ~= nil
	and string.find(eventSource, 'head.Name = "Body"', 1, true) ~= nil -- GiantOctopus bursts ink from its Body
for _, id in { "mermaid", "orca", "whale", "octopus" } do
	eventsMeshOk = eventsMeshOk and CreatureMeshes[id] ~= nil
end
check(eventsMeshOk, "Marina, the orcas, the Whale Pass whale and the Giant Octopus use their meshes")
local ruinsSource = fs.readFile("src/client/RuinsLife.luau")
local ruinsMeshOk = string.find(ruinsSource, "Creatures.onReady", 1, true) ~= nil
for _, creature in Ruins.Creatures.list do
	local id = string.match(ruinsSource, "\n\t" .. creature.id .. ' = { id = "(%w+)"')
	ruinsMeshOk = ruinsMeshOk and id ~= nil and CreatureMeshes[id] ~= nil
end
check(ruinsMeshOk, "every Sunken Ruins creature swaps to its mesh")
local abyssSource = fs.readFile("src/client/AbyssLife.luau")
local abyssMeshOk = string.find(abyssSource, "Creatures.onReady", 1, true) ~= nil
for _, creature in A.Creatures.list do
	local id = string.match(abyssSource, "\n\t" .. creature.id .. ' = { id = "(%w+)"')
	abyssMeshOk = abyssMeshOk and id ~= nil and CreatureMeshes[id] ~= nil
end
check(abyssMeshOk, "every Abyss creature swaps to its mesh")
local kelpMeshOk = true
for _, id in Kelp.FISH_IDS do
	local kind = nil
	for _, k in Config.Fish.kinds do
		if k.id == id then
			kind = k
		end
	end
	kelpMeshOk = kelpMeshOk and kind ~= nil and kind.creature ~= nil and CreatureMeshes[kind.creature] ~= nil
end
check(kelpMeshOk, "every Kelp Forest fish is a mesh creature")
-- Batch 7, the background sea life: every school species, the turtles, jellyfish, mantas and
-- crabs (SeaLife), and the Kelp Forest's turtles and fish (KelpLife) swap to real meshes.
local function meshIds(source: string, pattern: string): { string }
	local ids = {}
	for id in string.gmatch(source, pattern) do
		table.insert(ids, id)
	end
	return ids
end
local seaSource = fs.readFile("src/client/SeaLife.luau")
local kelpSource = fs.readFile("src/client/KelpLife.luau")
local schoolIds = meshIds(seaSource, 'mesh = "(%w+)", length = [%d%.]+ }')
local seaIds = meshIds(seaSource, '%.spec = { id = "(%w+)"')
local kelpIds = meshIds(kelpSource, '{ id = "(%w+)", length')
local backgroundOk = #schoolIds == 6 and #seaIds == 4 and #kelpIds >= 3
	and string.find(seaSource, "Creatures.onReady", 1, true) ~= nil and string.find(kelpSource, "Creatures.onReady", 1, true) ~= nil
for _, list in { schoolIds, seaIds, kelpIds } do
	for _, id in list do
		backgroundOk = backgroundOk and CreatureMeshes[id] ~= nil
	end
end
for _, def in CreatureMeshes do
	backgroundOk = backgroundOk and (def.turn == nil or type(def.turn) == "number")
end
check(backgroundOk, "the background sea life (schools, turtles, jellyfish, mantas, crabs, Kelp turtles and fish) uses real meshes")

-- Store (Robux): real ids, unique, priced, with icons; the pass perks point at real things
local Store = Config.Store
local seenIds, storeOk = {}, #Store.passes == 4 and #Store.products == 8
for _, item in Store.passes do
	storeOk = storeOk and item.id > 0 and item.icon > 0 and item.price > 0 and not seenIds[item.id] and Config.StorePassByKey[item.key] == item and Config.StorePassById[item.id] == item
	seenIds[item.id] = true
end
for _, item in Store.products do
	storeOk = storeOk and item.id > 0 and item.icon > 0 and item.price > 0 and not seenIds[item.id] and Config.StoreProductById[item.id] == item and Config.StoreProductByKey[item.key] == item
	seenIds[item.id] = true
end
check(storeOk, "4 game passes and 8 developer products, each with a unique id, an icon and a price")
-- Gifts: each is shells or a real pass; the Starter Pack's contents are real.
local giftsOk, gifts, starters = true, 0, 0
for _, item in Store.products do
	if item.gift then
		gifts += 1
		giftsOk = giftsOk and ((item.shells or 0) > 0) ~= (item.pass ~= nil) and (item.pass == nil or Config.StorePassByKey[item.pass] ~= nil)
	end
	if item.starter then
		starters += 1
	end
end
check(giftsOk and gifts == 3 and Store.giftOwnedShells > 0, "3 gifts: shells or a real game pass")
local starter = Store.starter
local starterOk = starters == 1 and starter.days > 0 and starter.shells > 0 and starter.fullPetsShells > 0 and Config.Pets.species[starter.pet.species] ~= nil
for seedId, count in starter.seeds do
	starterOk = starterOk and Config.Seeds[seedId] ~= nil and count > 0
end
check(starterOk, "the Starter Pack gives a real pet, real seeds and shells")
check(Config.FenceById[Store.royalFence] ~= nil and Config.FenceById[Store.royalFence].shop == false and Config.StorePassByKey[Config.FenceById[Store.royalFence].pass] ~= nil, "the Royal Pearl fence is pass-only")
check(Config.TitleById[Store.royalTitle] ~= nil, "the VIP title exists")
check(Store.doubleShells == 2 and Store.vipBagBonus > 0 and Store.speedFinsMultiplier > 1 and Store.receiptsKept >= 50, "pass perks and receipt memory are sane")
local shellsPerRobux = {}
for _, item in Store.products do if item.shells and not item.gift then table.insert(shellsPerRobux, item.shells / item.price) end end
table.sort(shellsPerRobux)
check(#shellsPerRobux == 2 and shellsPerRobux[2] > shellsPerRobux[1], "the bigger shell pack is better value")
local royalRewardedByIndex = false
for _, reward in Config.IndexRewards do royalRewardedByIndex = royalRewardedByIndex or reward.fence == Store.royalFence end
check(not royalRewardedByIndex, "the Reef Index never gives away the pass fence")

-- Rewards: daily streak, boosts, group, referrals, the weekly board, watering, trading
local Rewards = Config.Rewards
local dailyOk = #Rewards.daily == 7
for _, bundle in Rewards.daily do
	dailyOk = dailyOk and ((bundle.shells or 0) > 0 or bundle.seeds ~= nil)
	for seedId, count in bundle.seeds or {} do
		dailyOk = dailyOk and Config.Seeds[seedId] ~= nil and count > 0
	end
end
check(dailyOk, "7 daily rewards, each shells or real seeds")
check(Config.bundleText({ shells = 2500, seeds = { anemone = 2 } }) == "2,500 shells, 2 Glow Anemone seeds", "reward text reads well")
check(Rewards.offline.minSeconds > 0 and Rewards.offline.maxSeconds <= 24 * 3600 and Rewards.offline.shellsPerPlanterMinute > 0, "offline earnings are capped")
check(Rewards.premiumBonus > 0 and Rewards.friendBonus > 0 and Rewards.friendBonusMax >= Rewards.friendBonus, "Premium and friend boosts are set")
check(Config.TitleById[Rewards.group.title] ~= nil and Config.TitleById[Rewards.referral.title] ~= nil and Config.TitleById[Rewards.weekly.title] ~= nil, "reward titles exist")
local prizesOk = #Rewards.weekly.prizes == Rewards.weekly.size
for i = 2, #Rewards.weekly.prizes do
	prizesOk = prizesOk and Rewards.weekly.prizes[i] <= Rewards.weekly.prizes[i - 1]
end
check(prizesOk, "weekly prizes for every rank, best first")
local monday = 1795392000 -- Monday 23 November 2026, 00:00 UTC
check(Config.weekNumber(monday) == Config.weekNumber(monday + 7 * 86400 - 1) and Config.weekNumber(monday - 1) == Config.weekNumber(monday) - 1, "weeks start on Monday (UTC)")
check(Rewards.watering.givenPerDay > 0 and Rewards.watering.receivedPerDay >= Rewards.watering.givenPerDay and Rewards.watering.growSeconds > 0, "watering is capped per day")
check(Rewards.trade.maxSeedKinds > 0 and Rewards.trade.maxPets > 0 and Rewards.trade.maxPets <= Config.Pets.maxEquipped * 4, "trades are limited")
local rewardsSource = fs.readFile("src/server/Rewards.luau")
check(string.find(rewardsSource, "local CODES", 1, true) ~= nil and string.find(fs.readFile("src/shared/ReefConfig.luau"), "REEFLAUNCH", 1, true) == nil, "codes live on the server only")

print(failures == 0 and "ALL PASSED" or (failures .. " FAILED"))
process.exit(if failures > 0 then 1 else 0)
