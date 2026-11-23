--!nonstrict
-- Grow a Reef: client entry point. Renders what the server sends and turns button
-- presses into requests. It never decides prices, growth or rewards.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Hud = require(script.Parent.Hud)
local ShopPanel = require(script.Parent.ShopPanel)
local Shopkeepers = require(script.Parent.Shopkeepers)
local TileLabels = require(script.Parent.TileLabels)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local hud = Hud.new(playerGui, function(seedId: string?)
	Remotes.SelectSeed:FireServer(seedId)
end)
local shop = ShopPanel.new(playerGui)

Remotes.DataSync.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	hud:setData(data)
	shop:setData(data)
end)

Remotes.ShopSync.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and type(payload.stock) == "table" and type(payload.restockAt) == "number" then
		shop:setStock(payload.stock, payload.restockAt)
	end
end)

Remotes.Notify.OnClientEvent:Connect(function(text, tone)
	if type(text) == "string" then
		hud:toast(text, if type(tone) == "string" then tone else nil)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredBy)
	if triggeredBy ~= player then
		return
	end
	if prompt:GetAttribute("Kind") == "SeedShop" then
		shop:setOpen(true, prompt.Parent :: BasePart)
	end
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.2 then
		return
	end
	elapsed = 0
	hud:updateTimers()
	shop:update()
end)

task.spawn(TileLabels.start, playerGui)
Shopkeepers.start(playerGui)

-- Ask for a snapshot in case DataSync fired before these handlers connected.
Remotes.RequestSync:FireServer()
hud:toast("Welcome to Grow a Reef! Buy seeds at the Seed Shop, plant them on your reef.", "good")
