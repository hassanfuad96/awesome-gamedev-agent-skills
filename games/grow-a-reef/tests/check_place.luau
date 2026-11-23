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
for _, name in { "SelectSeed", "BuySeed", "ExpandReef", "PlantAt", "RequestSync", "DataSync", "ShopSync", "Notify" } do
	local r = rs.Remotes:FindFirstChild(name)
	check(r and r.ClassName == "RemoteEvent", "remote " .. name)
end
local server = game:GetService("ServerScriptService").Server
check(server.Main.ClassName == "Script", "server Main is a Script")
for _, m in { "World", "PlayerData", "Plots", "Shop", "Fish", "Currents", "Leaderboard", "RateLimit", "CoralVisuals", "ShopkeeperVisuals", "SeabedDecor" } do
	check(server:FindFirstChild(m) and server[m].ClassName == "ModuleScript", "server module " .. m)
end
local client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
check(client.Main.ClassName == "LocalScript", "client Main is a LocalScript")
check(rs.Shared.ReefConfig.ClassName == "ModuleScript", "shared ReefConfig")
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
local env = { Color3 = roblox.Color3, math = math, string = string, table = table, pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, tonumber = tonumber, error = error, setmetatable = setmetatable }
local function load(path) return luau.load(fs.readFile(path), { debugName = path, environment = env })() end
local Config = load("src/shared/ReefConfig.luau")
local Econ = load("src/shared/EconomyMath.luau")

check(Config.harvestValue("brain", "Golden") == 375, "Golden Brain Coral sells for 375")
check(Config.harvestValue("nope", "None") == 0, "unknown seed sells for 0")
check(Config.expandCost(6) == 200 and Config.expandCost(7) == 500 and Config.expandCost(11) == 19531, "expand costs 200, 500 ... 19531")
check(Config.bedRadius(6) == 11 and Config.bedRadius(12) == 15.5, "reef bed grows from 11 to 15.5 studs")
check(Config.plantProblem(0, 0, 6, {}) == nil, "coral fits in the middle of an empty bed")
check(Config.plantProblem(10, 0, 6, {}) ~= nil and Config.plantProblem(9.4, 0, 6, {}) == nil, "coral must stay 1.5 studs inside the bed edge")
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

print(failures == 0 and "ALL PASSED" or (failures .. " FAILED"))
process.exit(if failures > 0 then 1 else 0)
