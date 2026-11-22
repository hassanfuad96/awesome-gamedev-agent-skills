--!nonstrict
-- Grow a Reef: server entry point. Order matters: the world must exist before the
-- systems that hook into its parts, and PlayerData starts last so every system has
-- registered its onLoaded callback before the first player loads.

local World = require(script.Parent.World)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Shop = require(script.Parent.Shop)
local Fish = require(script.Parent.Fish)
local Currents = require(script.Parent.Currents)
local Leaderboard = require(script.Parent.Leaderboard)

local worldParts = World.build()
Plots.start(worldParts)
Shop.start(worldParts)
Fish.start()
Currents.start(worldParts)
PlayerData.start()
Leaderboard.start(worldParts)
