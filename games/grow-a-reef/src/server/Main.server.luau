--!nonstrict
-- Grow a Reef: server entry point. Order matters: the world must exist before the
-- systems that hook into its parts, and PlayerData starts last so every system has
-- registered its onLoaded callback before the first player loads.

local World = require(script.Parent.World)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Shop = require(script.Parent.Shop)
local Fish = require(script.Parent.Fish)
local Events = require(script.Parent.Events)
local Pets = require(script.Parent.Pets)
local Leaderboard = require(script.Parent.Leaderboard)
local Teleport = require(script.Parent.Teleport)
local Admin = require(script.Parent.Admin)
local ReefIndex = require(script.Parent.ReefIndex)
local Quests = require(script.Parent.Quests)
local Supplies = require(script.Parent.Supplies)
local Likes = require(script.Parent.Likes)
local Rebirth = require(script.Parent.Rebirth)
local Tutorial = require(script.Parent.Tutorial)
local Collectibles = require(script.Parent.Collectibles)
local RuinsWorld = require(script.Parent.RuinsWorld)
local Ruins = require(script.Parent.Ruins)
local AbyssWorld = require(script.Parent.AbyssWorld)
local Abyss = require(script.Parent.Abyss)
local Kelp = require(script.Parent.Kelp)
local Research = require(script.Parent.Research)
local Oxygen = require(script.Parent.Oxygen)
local Crew = require(script.Parent.Crew)
local Suits = require(script.Parent.Suits)
local CreatureModels = require(script.Parent.CreatureModels)
local ShopkeeperVisuals = require(script.Parent.ShopkeeperVisuals)
local Monetization = require(script.Parent.Monetization)
local Rewards = require(script.Parent.Rewards)
local Social = require(script.Parent.Social)

CreatureModels.start() -- the mesh creatures' templates load in the background
local worldParts = World.build()
RuinsWorld.build() -- the Sunken Ruins, east of the plaza
AbyssWorld.build() -- the Abyss, south of the lagoon
ShopkeeperVisuals.start() -- Pinch, Otto and Lumi swap to their mesh models once those load
Plots.start(worldParts)
Teleport.start(worldParts)
Shop.start(worldParts)
Fish.start()
Events.start(worldParts)
Pets.start(worldParts)
Admin.start()
ReefIndex.start()
Quests.start()
Supplies.start(worldParts)
Likes.start(worldParts)
Rebirth.start()
Tutorial.start()
Collectibles.start(worldParts)
Ruins.start()
Abyss.start()
Kelp.start(worldParts.kelp)
Research.start(worldParts)
Oxygen.start()
Monetization.start() -- Robux purchases: before PlayerData, so pass checks run on every join
Rewards.start() -- daily streak, offline earnings, boosts, codes, group, referrals, weekly board
Social.start(worldParts) -- visiting, watering and trading
-- The crew and diving suits are cosmetic: if one of them breaks (say a place synced without
-- the ChooseSuit remote), warn and carry on, so saves, reefs and teleports still start.
-- Crew goes after every world is built: the crew stand at their counters.
for _, feature in { { "Crew", Crew.start }, { "Suits", Suits.start } } do
	local ok, problem = pcall(feature[2])
	if not ok then
		warn(`{feature[1]} didn't start: {problem}`)
	end
end
PlayerData.start()
Leaderboard.start(worldParts)
