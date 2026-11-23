--!nonstrict
-- Rebirth and titles.
--   Rebirth: pay ReefConfig.rebirthCost shells to start the reef over: shells, seeds, coral,
--   the bag and the reef's size reset; pets, the Reef Index, fences, decorations, gear and
--   titles stay. Each rebirth adds ReefConfig.Rebirth.shellBonus to every coral and fish
--   sale, earns the "Reborn" title, and a badge if ReefConfig.Rebirth.badges names one.
--   EquipTitle <id or "">: show an earned title over your head (NameTags draws it).

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Rebirth = {}

local SETTINGS = ReefConfig.Rebirth

local function awardBadge(player: Player, rebirths: number)
	local badgeId = SETTINGS.badges[rebirths]
	if not badgeId then
		return
	end
	task.spawn(function()
		local ok, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
		if not ok then
			warn("[Rebirth] badge", badgeId, "not awarded:", err)
		end
	end)
end

local function onRebirth(player: Player)
	if not RateLimit.consume(player, 3) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local data = profile.data
	if data.rebirths >= SETTINGS.maxRebirths then
		Plots.notify(player, "You've reached the highest rebirth!")
		return
	end
	local cost = ReefConfig.rebirthCost(data.rebirths)
	if data.shells < cost then
		Plots.notify(player, `Rebirthing needs {EconomyMath.formatNumber(cost)} shells.`)
		return
	end
	-- No yields between the check above and these writes.
	data.shells = ReefConfig.STARTING_SHELLS
	data.seeds = table.clone(ReefConfig.STARTING_SEEDS)
	data.inventory = {}
	data.plants = {}
	data.unlocked = ReefConfig.STARTING_SLOTS
	profile.selected = nil
	data.rebirths += 1
	data.titles.reborn = true
	if data.title == "" then
		data.title = "reborn"
	end
	Plots.resetReef(player)
	awardBadge(player, data.rebirths)
	local bonus = math.round((ReefConfig.shellMultiplier(data.rebirths) - 1) * 100)
	Plots.notify(player, `You were reborn! Coral and fish now pay +{bonus}% shells.`, "rare")
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Plots.notify(other, `{player.DisplayName} was reborn! (Rebirth {data.rebirths})`, "rare")
		end
	end
	PlayerData.sync(player)
end

local function onEquipTitle(player: Player, titleId: unknown)
	if not RateLimit.consume(player) or type(titleId) ~= "string" then
		return
	end
	local profile = PlayerData.get(player)
	if not profile or (titleId ~= "" and not profile.data.titles[titleId]) then
		return
	end
	profile.data.title = titleId
	PlayerData.sync(player)
end

function Rebirth.start()
	Remotes.Rebirth.OnServerEvent:Connect(onRebirth)
	Remotes.EquipTitle.OnServerEvent:Connect(onEquipTitle)
end

return Rebirth
