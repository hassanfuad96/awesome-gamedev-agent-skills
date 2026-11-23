--!nonstrict
-- The Abyss's gameplay (AbyssConfig; AbyssWorld builds the place). The server decides
-- everything:
--   unlocking    a player opens the Abyss for good on reaching Exploration Level or Reef
--                Health (AbyssConfig.Unlock); until then anyone who gets into the pit (by
--                swimming down, say) is put back at the Pressure Gate
--   Lumi's stall the high-value abyssal seeds at fixed prices (BuyAbyssSeed carries only a
--                seed id; price, unlock and distance are checked here)
--   sightings    swim close to a deep-sea creature (paths depend only on the server time)
-- Progress is saved in data.abyss (AbyssConfig.State).
--   Abyss.isUnlocked(player)  for Teleport's "abyss" destination

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local AbyssConfig = require(ReplicatedStorage.Shared.AbyssConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Abyss = {}

local POLL = 0.5
local TURNED_BACK = CFrame.lookAt(AbyssConfig.gate + Vector3.new(0, 3, -10), AbyssConfig.gate + Vector3.new(0, 3, -40))
local lastWarned: { [Player]: number } = {}

local function notify(player: Player, text: string, tone: string)
	Remotes.Notify:FireClient(player, text, tone)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if humanoid and humanoid.Health > 0 then root else nil
end

-- Opens the Abyss for this player if they now qualify. Returns true when it just opened.
local function checkUnlock(player: Player, profile: PlayerData.Profile): boolean
	local state = profile.data.abyss
	if state.unlocked or not AbyssConfig.meetsUnlock(profile.data) then
		return false
	end
	state.unlocked = true
	notify(player, "The Abyss is open to you! Head south from the plaza, or press Go to Abyss in your Journal.", "rare")
	return true
end

function Abyss.isUnlocked(player: Player): boolean
	local profile = PlayerData.get(player)
	if not profile then
		return false
	end
	if checkUnlock(player, profile) then
		PlayerData.sync(player)
	end
	return profile.data.abyss.unlocked
end

function Abyss.lockedText(player: Player): string
	local profile = PlayerData.get(player)
	return if profile then AbyssConfig.lockedText(profile.data) else "The Abyss is locked."
end

local function buy(player: Player, seedId: unknown)
	if not RateLimit.consume(player) or type(seedId) ~= "string" or not table.find(AbyssConfig.SHOP_SEEDS, seedId) then
		return
	end
	local profile = PlayerData.get(player)
	local seed = ReefConfig.Seeds[seedId]
	local root = rootOf(player)
	if not profile or not seed or not root or not profile.data.abyss.unlocked then
		return
	end
	if (root.Position - AbyssConfig.Places.shop).Magnitude > AbyssConfig.REACH then
		notify(player, "Swim over to Lumi's stall to buy.", "info")
		return
	end
	local data = profile.data
	local owned = data.seeds[seedId] or 0
	if owned >= ReefConfig.MAX_SEEDS_PER_TYPE then
		return
	end
	local wallet = { shells = data.shells }
	if not EconomyMath.trySpend(wallet, { shells = seed.price }) then
		notify(player, `Not enough shells: {seed.name} costs {EconomyMath.formatNumber(seed.price)}.`, "bad")
		return
	end
	-- No yields between the checks above and these writes.
	data.shells = wallet.shells
	data.seeds[seedId] = owned + 1
	profile.selected = profile.selected or seedId
	notify(player, `Bought a {seed.name} seed! It sells for {EconomyMath.formatNumber(seed.sellValue)} when grown.`, "rare")
	PlayerData.sync(player)
end

local function poll()
	local now = Workspace:GetServerTimeNow()
	local creatures = {}
	for _, creature in AbyssConfig.Creatures.list do
		creatures[creature.id] = AbyssConfig.creaturePosition(creature.id, now)
	end
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		local root = rootOf(player)
		if not profile or not root then
			continue
		end
		local state = profile.data.abyss
		local changed = checkUnlock(player, profile)
		local p = root.Position
		if not state.unlocked then
			if AbyssConfig.inPit(p) then
				-- Swam (or fell) into the pit while it's still locked: back to the gate.
				player.Character:PivotTo(TURNED_BACK)
				if os.clock() - (lastWarned[player] or -math.huge) > 4 then
					lastWarned[player] = os.clock()
					notify(player, AbyssConfig.lockedText(profile.data), "bad")
				end
			end
		elseif AbyssConfig.inZone(p) then
			for _, creature in AbyssConfig.Creatures.list do
				local at = creatures[creature.id]
				if at and not state.sighted[creature.id] and (at - p).Magnitude <= creature.sight then
					state.sighted[creature.id] = true
					changed = true
					PlayerData.addShells(player, AbyssConfig.Creatures.shells)
					local seen = 0
					for _ in state.sighted do
						seen += 1
					end
					notify(player, `Deep-sea creature spotted: {creature.name}! ({seen}/{#AbyssConfig.Creatures.list}) +{EconomyMath.formatNumber(AbyssConfig.Creatures.shells)} shells`, "rare")
					if seen >= #AbyssConfig.Creatures.list and not state.allRewarded then
						state.allRewarded = true
						local reward = AbyssConfig.Creatures.allReward
						local title = ReefConfig.TitleById[reward.title]
						if title then
							profile.data.titles[title.id] = true
							if profile.data.title == "" then
								profile.data.title = title.id
							end
						end
						local seed = ReefConfig.Seeds[reward.seed]
						if seed then
							profile.data.seeds[seed.id] = math.min(ReefConfig.MAX_SEEDS_PER_TYPE, (profile.data.seeds[seed.id] or 0) + reward.count)
						end
						notify(player, `Every deep-sea creature spotted! The "{title and title.text or ""}" title and {reward.count} {seed and seed.name or ""} seed!`, "rare")
					end
				end
			end
		end
		if changed then
			PlayerData.sync(player)
		end
	end
end

function Abyss.start()
	Remotes.BuyAbyssSeed.OnServerEvent:Connect(buy)
	PlayerData.onLoaded(function(player, profile)
		if checkUnlock(player, profile) then
			PlayerData.sync(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastWarned[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(POLL)
			poll()
		end
	end)
end

return Abyss
