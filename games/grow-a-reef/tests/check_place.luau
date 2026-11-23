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
for _, name in { "SelectSeed", "BuySeed", "ExpandReef", "PlantAt", "BuyEgg", "EquipPet", "ReleasePet", "RequestSync", "DataSync", "ShopSync", "Notify", "Teleport", "Teleported", "AdminAction", "Announcement", "BuyFence", "EquipFence", "BuyDecor", "PlaceDecor", "UpgradeGear", "ClaimQuest", "Rebirth", "EquipTitle" } do
	local r = rs.Remotes:FindFirstChild(name)
	check(r and r.ClassName == "RemoteEvent", "remote " .. name)
end
local server = game:GetService("ServerScriptService").Server
check(server.Main.ClassName == "Script", "server Main is a Script")
for _, m in { "World", "PlayerData", "Plots", "Shop", "Fish", "Currents", "Leaderboard", "RateLimit", "ShopkeeperVisuals", "SeabedDecor", "Events", "EventState", "TreasureStorm", "ReefIndex", "Pets", "Teleport", "Shipwreck", "ShipwreckVisuals", "Admin", "Quests", "Supplies", "Likes", "Rebirth" } do
	check(server:FindFirstChild(m) and server[m].ClassName == "ModuleScript", "server module " .. m)
end
local client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
check(client.Main.ClassName == "LocalScript", "client Main is a LocalScript")
for _, m in { "Swimming", "AdminPanel", "SuppliesPanel", "QuestsPanel", "NameTags" } do
	check(client:FindFirstChild(m) and client[m].ClassName == "ModuleScript", "client module " .. m)
end
check(rs.Shared.ReefConfig.ClassName == "ModuleScript", "shared ReefConfig")
for _, m in { "CoralVisuals", "FenceVisuals", "DecorVisuals" } do
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
check(Config.expandCost(10) == 200 and Config.expandCost(11) == 240 and Config.expandCost(49) == 244961, "expand costs 200, 240 ... 244,961")
check(Config.bedRadius(10) == 37 and math.abs(Config.bedRadius(50) - 54) < 1e-9, "reef bed grows from 37 to 54 studs")
local maxReach = Config.bedRadius(Config.MAX_SLOTS) + 7
check(Config.PLOT_SPACING >= maxReach * 2, "neighbouring reef mounds don't overlap")
local rowHalf = (Config.PLOT_COUNT - 1) * Config.PLOT_SPACING / 2 + maxReach
check(rowHalf < Config.SeaLife.area.maxX and rowHalf < 600, "the row of reefs fits inside the sea area and the seabed")
check(Config.plantProblem(0, 0, 10, {}) == nil, "coral fits in the middle of an empty bed")
check(Config.plantProblem(35.6, 0, 10, {}) ~= nil and Config.plantProblem(35.4, 0, 10, {}) == nil, "coral must stay 1.5 studs inside the bed edge")
check(Config.Swim.speed > 16 and Config.Swim.rise > 0 and Config.Swim.sink > 0, "swimming is faster than walking (16)")
check(Config.Teleport.cooldown > 0 and Config.Teleport.shopsPad.Z > -15, "teleport has a cooldown and the shops pad clears the stands")
check(Config.adminRole(5067168140) == "Owner" and Config.adminRole(1) == nil, "far_rel2017 (5067168140) is the owner; others are not admins")
local giftsOk = #Config.Admin.giftShells > 0
for _, amount in Config.Admin.giftShells do giftsOk = giftsOk and amount > 0 and amount % 1 == 0 end
check(giftsOk and Config.Admin.announceMaxLength <= 200, "admin gift amounts and announcement length are sane")
local fence = Config.FenceById[Config.DEFAULT_FENCE]
check(fence ~= nil and fence.name == "Shipwreck Wood" and #fence.plankColors > 0, "the default fence is Shipwreck Wood")
for _, style in Config.Fences do
	check(style.height > 0 and style.postSpacing > 0 and style.rails >= 1 and type(style.material) == "string", "fence " .. style.id .. " has a height, post spacing, rails and a material")
end
check(Config.plantProblem(4.9, 0, 6, { { x = 0, z = 0 } }) ~= nil and Config.plantProblem(5, 0, 6, { { x = 0, z = 0 } }) == nil, "coral needs 5 studs of spacing")
local full = {}
for i = 1, 6 do full[tostring(i)] = { x = (i - 3.5) * 100, z = 0 } end
check(string.find(Config.plantProblem(0, 0, 6, full) or "", "full") ~= nil, "a full reef refuses more coral")
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
local fishWeights = Econ.oddsPercent(Config.Fish.kinds)
check(fishWeights.Moonfish == 2, "Moonfish odds 2%")
local eventIds = {}
for _, event in Config.Events.list do
	check(Config.EventById[event.id] == event and event.duration > 0 and event.weight > 0, "sea event " .. event.id .. " is listed with a duration and weight")
	table.insert(eventIds, event.id)
end
check(table.concat(eventIds, ",") == "Current,Cold,Night,Frenzy,Treasure,Whale,Shipwreck", "seven sea events")
local eventOdds = Econ.oddsPercent(Config.Events.list)
check(math.abs(eventOdds.Shipwreck - 5) < 1e-9, "Shipwreck is picked 5% of the time")
local ship = Config.Shipwreck
check(Config.EventById.Shipwreck.duration == ship.huntStartsAt + ship.huntSeconds + 5 and ship.sinkSeconds < ship.huntStartsAt, "Shipwreck: sink, then hide, hunt and 5 s for the orcas to leave")
check(ship.orcaSpeed > Config.Swim.speed, "orcas are faster than swimming, so hiding is the way to survive")
local reward = Config.Seeds[ship.reward.seed]
check(reward ~= nil and reward.shop == false and reward.rarity == "Transcendent" and reward.stockChance == 0, "the reward seed is Transcendent and never in the shop")
local rest = roblox.CFrame.new(ship.landing)
check(Config.insideShipwreck(rest, ship.landing + roblox.Vector3.new(10, 5, 3)) and not Config.insideShipwreck(rest, ship.landing + roblox.Vector3.new(0, 5, 20)) and not Config.insideShipwreck(rest, ship.landing + roblox.Vector3.new(0, 30, 0)), "inside the hull is hidden; beside or above it is not")
check(ship.landing.Z + ship.width / 2 < -30 and ship.landing.Z - ship.width / 2 > Config.SeaLife.area.minZ, "the wreck lands on open seabed in front of the stands")

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
check(#Config.MUTATION_KEYS == 16, "16 mutation keys (none, 5 singles, 10 pairs)")

-- Reef Index
local indexEntries = 0
for _, set in Config.IndexSets do
	indexEntries += #set.entries
end
check(#Config.IndexSets == 8 and indexEntries == 116, "Reef Index: 8 sets, 116 entries")

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
check(table.concat(fenceIds, ",") == "shipwood,kelp,coralstone,whalebone,crystal", "five fence styles")
for _, item in Config.Decor.items do
	check(Config.DecorById[item.id] == item and item.price > 0 and item.footprint > 0, "decoration " .. item.id .. " has a price and footprint")
end
local mound = Config.moundRadius()
check(Config.decorProblem("anchor", 30, 20, {}, {}) == nil, "a decoration fits on open reef")
check(Config.decorProblem("anchor", mound, 0, {}, {}) ~= nil, "decorations stay inside the fence")
check(Config.decorProblem("lantern", 0, -mound + 4, {}, {}) ~= nil, "the gateway stays clear")
check(Config.decorProblem("anchor", 0, 0, { { x = 1, z = 0 } }, {}) ~= nil, "decorations can't go on coral")
check(Config.decorProblem("anchor", 0, 0, {}, { { item = "chest", x = 3, z = 0 } }) ~= nil and Config.decorProblem("anchor", 0, 0, {}, { { item = "chest", x = 6, z = 0 } }) == nil, "decorations keep their footprints apart")
check(Config.plantProblem(0, 0, 10, {}, { { item = "statue", x = 2, z = 0 } }) ~= nil and Config.plantProblem(0, 0, 10, {}, { { item = "statue", x = 6, z = 0 } }) == nil, "coral can't grow on a decoration")
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
check(Config.questShells(Config.QuestById.plant, 10) == 150 and Config.questShells(Config.QuestById.plant, 50) == 750, "quest rewards grow with your reef (x1 at 10 slots, x5 at 50)")
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

print(failures == 0 and "ALL PASSED" or (failures .. " FAILED"))
process.exit(if failures > 0 then 1 else 0)
