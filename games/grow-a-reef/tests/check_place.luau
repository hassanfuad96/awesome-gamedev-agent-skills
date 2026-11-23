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
for _, name in { "SelectSeed", "BuySeed", "ExpandReef", "PlantAt", "BuyEgg", "EquipPet", "ReleasePet", "RequestSync", "DataSync", "ShopSync", "Notify", "Teleport", "Teleported" } do
	local r = rs.Remotes:FindFirstChild(name)
	check(r and r.ClassName == "RemoteEvent", "remote " .. name)
end
local server = game:GetService("ServerScriptService").Server
check(server.Main.ClassName == "Script", "server Main is a Script")
for _, m in { "World", "PlayerData", "Plots", "Shop", "Fish", "Currents", "Leaderboard", "RateLimit", "ShopkeeperVisuals", "SeabedDecor", "Events", "EventState", "TreasureStorm", "ReefIndex", "Pets", "Teleport" } do
	check(server:FindFirstChild(m) and server[m].ClassName == "ModuleScript", "server module " .. m)
end
local client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
check(client.Main.ClassName == "LocalScript", "client Main is a LocalScript")
check(client:FindFirstChild("Swimming") and client.Swimming.ClassName == "ModuleScript", "client module Swimming")
check(rs.Shared.ReefConfig.ClassName == "ModuleScript", "shared ReefConfig")
for _, m in { "CoralVisuals", "FenceVisuals" } do
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
local env = { Color3 = roblox.Color3, Vector3 = roblox.Vector3, math = math, string = string, table = table, pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, tonumber = tonumber, error = error, setmetatable = setmetatable }
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
check(table.concat(eventIds, ",") == "Current,Cold,Night,Frenzy,Treasure,Whale", "six sea events")

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
check(#Config.IndexSets == 7 and indexEntries == 100, "Reef Index: 7 sets, 100 entries")

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

print(failures == 0 and "ALL PASSED" or (failures .. " FAILED"))
process.exit(if failures > 0 then 1 else 0)
