--!nonstrict
-- Grow a Reef: client entry point. Renders what the server sends and turns button
-- presses into requests. It never decides prices, growth or rewards.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local AdminPanel = require(script.Parent.AdminPanel)
local CoralLabels = require(script.Parent.CoralLabels)
local Hud = require(script.Parent.Hud)
local IndexPanel = require(script.Parent.IndexPanel)
local OceanEffects = require(script.Parent.OceanEffects)
local PetFollowers = require(script.Parent.PetFollowers)
local PetPanel = require(script.Parent.PetPanel)
local Planter = require(script.Parent.Planter)
local SeaLife = require(script.Parent.SeaLife)
local ShopPanel = require(script.Parent.ShopPanel)
local Shopkeepers = require(script.Parent.Shopkeepers)
local Swimming = require(script.Parent.Swimming)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local index = IndexPanel.new(playerGui)
local pets = PetPanel.new(playerGui)
local admin = AdminPanel.new(playerGui)
local sidePanels = { index = index, pets = pets, admin = admin }
local hud = Hud.new(playerGui, function(seedId: string?)
	Remotes.SelectSeed:FireServer(seedId)
end, function(panel: string)
	-- The side buttons toggle their window; only one big window is open at a time.
	local opening = sidePanels[panel] and not sidePanels[panel].gui.Enabled
	for id, window in sidePanels do
		window:setOpen(id == panel and opening)
	end
end, function(destination: string)
	Remotes.Teleport:FireServer(destination)
end)
local shop = ShopPanel.new(playerGui)

Remotes.DataSync.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	hud:setData(data)
	shop:setData(data)
	Planter.setData(data)
	index:setData(data)
	pets:setData(data)
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

-- Admin announcements (already filtered by the server): the banner, and a line in chat.
Remotes.Announcement.OnClientEvent:Connect(function(from, text, global)
	if type(from) ~= "string" or type(text) ~= "string" then
		return
	end
	hud:announce(from, text, global == true)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general then
		-- Chat reads rich text, so escape the message's own markup characters.
		local safe = string.gsub(`[{from}] {text}`, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" })
		pcall(function()
			(general :: TextChannel):DisplaySystemMessage(`<font color="#FFCD50">{safe}</font>`)
		end)
	end
end)

Remotes.Teleported.OnClientEvent:Connect(function()
	Swimming.stop()
	hud:flash()
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredBy)
	if triggeredBy ~= player then
		return
	end
	local kind = prompt:GetAttribute("Kind")
	if kind == "SeedShop" then
		shop:setOpen(true, prompt.Parent :: BasePart)
	elseif kind == "Hatchery" then
		index:setOpen(false)
		admin:setOpen(false)
		pets:setOpen(true, prompt.Parent :: BasePart)
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
	pets:update()
end)

CoralLabels.start(playerGui)
Planter.start()
Shopkeepers.start(playerGui)
SeaLife.start()
OceanEffects.start()
PetFollowers.start()
Swimming.start()

-- Ask for a snapshot in case DataSync fired before these handlers connected.
Remotes.RequestSync:FireServer()
hud:toast("Welcome to Grow a Reef! Buy seeds at the Seed Shop, plant them on your reef.", "good")
