--!nonstrict
-- Grow a Reef: client entry point. Renders what the server sends and turns button
-- presses into requests. It never decides prices, growth or rewards.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local AdminPanel = require(script.Parent.AdminPanel)
local Audio = require(script.Parent.Audio)
local CoralLabels = require(script.Parent.CoralLabels)
local Hud = require(script.Parent.Hud)
local IndexPanel = require(script.Parent.IndexPanel)
local NameTags = require(script.Parent.NameTags)
local OceanEffects = require(script.Parent.OceanEffects)
local PetFollowers = require(script.Parent.PetFollowers)
local PetPanel = require(script.Parent.PetPanel)
local Planter = require(script.Parent.Planter)
local QuestsPanel = require(script.Parent.QuestsPanel)
local SeaLife = require(script.Parent.SeaLife)
local MerchantPanel = require(script.Parent.MerchantPanel)
local ShopPanel = require(script.Parent.ShopPanel)
local Shopkeepers = require(script.Parent.Shopkeepers)
local SuppliesPanel = require(script.Parent.SuppliesPanel)
local Swimming = require(script.Parent.Swimming)
local TutorialPanel = require(script.Parent.TutorialPanel)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local index = IndexPanel.new(playerGui)
local pets = PetPanel.new(playerGui)
local admin = AdminPanel.new(playerGui)
local quests = QuestsPanel.new(playerGui)
local sidePanels = { index = index, pets = pets, quests = quests, admin = admin }
local function closeSidePanels()
	for _, window in sidePanels do
		window:setOpen(false)
	end
end
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
end, function()
	Planter.stopPlacing()
end)
local shop = ShopPanel.new(playerGui)
local merchant = MerchantPanel.new(playerGui)
local supplies = SuppliesPanel.new(playerGui, function(itemId: string)
	Planter.startPlacing(itemId)
	hud:toast("Teleport Home, then tap inside your fence to place it.", "info")
end)

local function refreshPlacing()
	local item = ReefConfig.DecorById[Planter.placingItem() or ""]
	hud:setPlacing(item and item.name, Planter.placingLeft())
end
Planter.onPlacingChanged(refreshPlacing)

Remotes.DataSync.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	hud:setData(data)
	shop:setData(data)
	Planter.setData(data)
	index:setData(data)
	pets:setData(data)
	quests:setData(data)
	supplies:setData(data)
	merchant:setData(data)
	Audio.onData(data)
	hud:setQuestReady(QuestsPanel.readyToClaim(data))
	TutorialPanel.setData(data)
	refreshPlacing()
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

-- Inky's tutorial lines, already chosen by the server.
Remotes.GuideLine.OnClientEvent:Connect(function(text)
	if type(text) == "string" then
		Shopkeepers.say("Guide", text)
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
		closeSidePanels()
		pets:setOpen(true, prompt.Parent :: BasePart)
	elseif kind == "Supplies" then
		closeSidePanels()
		supplies:setOpen(true, prompt.Parent :: BasePart)
	elseif kind == "Merchant" then
		closeSidePanels()
		merchant:setOpen(true, prompt.Parent :: BasePart)
	elseif kind == "Index" then
		-- The Reef Index hologram in the Research Station; the side button opens it anywhere.
		closeSidePanels()
		index:setOpen(true)
	end
end)

-- Some prompts are only for some players: "Pick up" only on your own decorations, and
-- "Like this reef" only on other people's reefs. Prompts are made by the server, so each
-- client hides the ones that aren't for it.
-- Both prompts sit on a part whose parent (the decoration, or the plot) has OwnerUserId.
local function ownerOf(prompt: ProximityPrompt): number?
	local holder = prompt.Parent and prompt.Parent.Parent
	return holder and holder:GetAttribute("OwnerUserId")
end
ProximityPromptService.PromptShown:Connect(function(prompt)
	local kind = prompt:GetAttribute("Kind")
	if kind ~= "Decor" and kind ~= "LikeReef" then
		return
	end
	local owner = ownerOf(prompt)
	local hide = if kind == "Decor" then owner ~= player.UserId else (owner == nil or owner == player.UserId)
	if hide then
		prompt.Enabled = false
		-- A reef changes hands when players come and go: check again when it does.
		local plot = prompt.Parent and prompt.Parent.Parent
		if kind == "LikeReef" and plot then
			local connection
			connection = plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				connection:Disconnect()
				prompt.Enabled = true
			end)
		end
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
	supplies:update()
	merchant:update()
	quests:update()
end)

CoralLabels.start(playerGui)
Planter.start()
Shopkeepers.start(playerGui)
SeaLife.start()
OceanEffects.start()
PetFollowers.start()
Swimming.start()
NameTags.start()
Audio.start(playerGui)
TutorialPanel.start(playerGui)

-- Ask for a snapshot in case DataSync fired before these handlers connected.
Remotes.RequestSync:FireServer()
hud:toast("Welcome to the Starter Lagoon! Talk to Inky the octopus to get started.", "good")
