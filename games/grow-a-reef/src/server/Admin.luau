--!nonstrict
-- Admin tools. Owners and admins (ReefConfig.Admin, by user id) get an "IsAdmin" attribute
-- that shows them the Admin window. Every request comes through the AdminAction remote and
-- is checked here: the sender must be on the list, and every argument is validated.
--   startEvent <id> / stopEvent       control sea events
--   announce <text> <"server"|"global"> filtered by Roblox, then shown to this server or,
--                                     through MessagingService, to every server
--   giveSeeds <seedId> / giveShells <amount> / restock   gifts for everyone in this server

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Events = require(script.Parent.Events)
local Shop = require(script.Parent.Shop)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Admin = {}

local SETTINGS = ReefConfig.Admin

local function notifyAll(text: string, tone: string)
	for _, player in Players:GetPlayers() do
		Plots.notify(player, text, tone)
	end
end

-- Roblox requires text typed by one player to be filtered before others see it.
local function filtered(player: Player, text: string): string?
	local ok, result = pcall(function()
		local filterResult = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		warn("[Admin] text filter failed:", result)
		return nil
	end
	return result
end

local function showAnnouncement(from: string, text: string, global: boolean)
	Remotes.Announcement:FireAllClients(from, text, global)
end

local function announce(player: Player, text: unknown, scope: unknown)
	if type(text) ~= "string" or (scope ~= "server" and scope ~= "global") then
		return
	end
	local message = string.sub((string.gsub(text, "%s+", " ")), 1, SETTINGS.announceMaxLength)
	if string.match(message, "^%s*$") then
		return
	end
	local clean = filtered(player, message)
	if not clean then
		Plots.notify(player, "Couldn't check that message with the text filter. Try again.", "bad")
		return
	end
	local from = `{ReefConfig.adminRole(player.UserId)} {player.DisplayName}`
	if scope == "global" then
		local ok, err = pcall(function()
			MessagingService:PublishAsync(SETTINGS.globalTopic, { from = from, text = clean })
		end)
		if ok then
			return -- every server, this one included, shows it from the subscription
		end
		warn("[Admin] global announcement failed, showing it on this server only:", err)
		Plots.notify(player, "Couldn't reach the other servers; announced here only.", "bad")
	end
	showAnnouncement(from, clean, false)
end

local function giveSeeds(player: Player, seedId: unknown)
	local seed = if type(seedId) == "string" then ReefConfig.Seeds[seedId] else nil
	if not seed then
		return
	end
	for _, target in Players:GetPlayers() do
		local profile = PlayerData.get(target)
		if profile then
			local owned = profile.data.seeds[seed.id] or 0
			profile.data.seeds[seed.id] = math.min(ReefConfig.MAX_SEEDS_PER_TYPE, owned + SETTINGS.giftSeedCount)
			PlayerData.sync(target)
		end
	end
	notifyAll(`{player.DisplayName} gave everyone {SETTINGS.giftSeedCount} {seed.name} seed{if SETTINGS.giftSeedCount == 1 then "" else "s"}!`, "rare")
end

local function giveShells(player: Player, amount: unknown)
	if type(amount) ~= "number" or not table.find(SETTINGS.giftShells, amount) then
		return
	end
	for _, target in Players:GetPlayers() do
		if PlayerData.get(target) then
			PlayerData.addShells(target, amount)
			PlayerData.sync(target)
		end
	end
	notifyAll(`{player.DisplayName} gave everyone {EconomyMath.formatNumber(amount)} shells!`, "rare")
end

local function onAction(player: Player, action: unknown, arg1: unknown, arg2: unknown)
	if not ReefConfig.adminRole(player.UserId) then
		return -- not an admin: ignore, whatever the request says
	end
	if not RateLimit.consume(player) or type(action) ~= "string" then
		return
	end
	print(`[Admin] {player.Name} ({player.UserId}): {action} {tostring(arg1)} {tostring(arg2)}`)
	if action == "startEvent" then
		if type(arg1) == "string" and Events.startNow(arg1) then
			Plots.notify(player, `Starting {ReefConfig.EventById[arg1].name}.`, "good")
		end
	elseif action == "stopEvent" then
		local stopped = Events.stopNow()
		Plots.notify(player, if stopped then `Stopping {ReefConfig.EventById[stopped].name}.` else "No sea event is running.", "info")
	elseif action == "announce" then
		announce(player, arg1, arg2)
	elseif action == "giveSeeds" then
		giveSeeds(player, arg1)
	elseif action == "giveShells" then
		giveShells(player, arg1)
	elseif action == "restock" then
		Shop.restockNow()
		notifyAll("The Coral Shop has been restocked!", "good")
	end
end

function Admin.start()
	local function mark(player: Player)
		player:SetAttribute("IsAdmin", ReefConfig.adminRole(player.UserId) ~= nil)
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
	Remotes.AdminAction.OnServerEvent:Connect(onAction)

	-- Every-server announcements. The text was filtered on the server that sent it.
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(SETTINGS.globalTopic, function(message)
				local data = message.Data
				if type(data) == "table" and type(data.from) == "string" and type(data.text) == "string" then
					showAnnouncement(string.sub(data.from, 1, 60), string.sub(data.text, 1, SETTINGS.announceMaxLength), true)
				end
			end)
		end)
		if not ok then
			warn("[Admin] every-server announcements are off:", err)
		end
	end)
end

return Admin
