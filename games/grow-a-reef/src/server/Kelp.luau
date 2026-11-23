--!nonstrict
-- The Kelp Forest's server side (layout in KelpConfig, built by KelpWorld):
--   seagrass meadows   shared by the whole server: plant a bare patch (hold the prompt) and it
--                      grows lush, stays a while, then wilts back to bare for someone else
--   turtle nests       guide a hatchling out to sea, once per nest per cooldown, per player
--   exploring          reaching the forest, the canopy, the habitats and the hidden glades
--                      are noticed by position, checked here once a second
--   challenges         Otto's challenges pay out the moment they're done
-- Each player's progress is saved in data.kelp (KelpConfig.State).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local KelpConfig = require(ReplicatedStorage.Shared.KelpConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kelp = {}

type PatchState = { state: string, since: number } -- "bare", "growing" or "lush", and when it started

local SETTINGS = KelpConfig.Restoration
local patches: { any } = {} -- KelpWorld.Patch, plus its state
local patchStates: { [any]: PatchState } = {}
local nestById: { [string]: any } = {}
local rng = Random.new()

local function notify(player: Player, text: string, tone: string?)
	Remotes.Notify:FireClient(player, text, tone or "info")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- How restored a meadow is, 0 to 1: lush patches count fully, growing ones half.
function Kelp.meadowHealth(meadowId: string): number
	local total, score = 0, 0
	for _, patch in patches do
		if patch.meadow == meadowId then
			total += 1
			local state = patchStates[patch].state
			score += if state == "lush" then 1 elseif state == "growing" then 0.5 else 0
		end
	end
	return if total > 0 then score / total else 0
end

-- Draws a patch: bare mud, seagrass growing up out of it, or a lush green patch.
local function paintPatch(patch: any)
	local entry = patchStates[patch]
	local progress = if entry.state == "lush" then 1 elseif entry.state == "growing" then math.clamp((os.time() - entry.since) / SETTINGS.growSeconds, 0.08, 1) else 0
	for _, blade in patch.blades do
		local part = blade.part
		if progress <= 0 then
			part.Transparency = 1
		else
			local height = blade.height * progress
			part.Transparency = 0
			part.Size = Vector3.new(part.Size.X, height, part.Size.Z)
			-- Grow up from the mud: keep the blade's foot where it was.
			part.CFrame = blade.cf * CFrame.new(0, (height - blade.height) / 2, 0)
		end
	end
	patch.base.Color = if entry.state == "bare" then Color3.fromRGB(96, 78, 58) else Color3.fromRGB(120, 110, 70)
	patch.base:SetAttribute("State", entry.state)
	patch.prompt.Enabled = entry.state == "bare"
end

local function setPatch(patch: any, state: string)
	patchStates[patch] = { state = state, since = os.time() }
	paintPatch(patch)
end

-- Pays every challenge this player has just finished.
local function checkChallenges(player: Player, profile: PlayerData.Profile): boolean
	local data = profile.data
	local state = data.kelp
	local changed = false
	for _, challenge in KelpConfig.Challenges do
		if not state.done[challenge.id] and challenge.done(state, data.index.fish) then
			state.done[challenge.id] = true
			changed = true
			local reward = challenge.reward
			PlayerData.addShells(player, reward.shells)
			local extras = {}
			for seedId, count in reward.seeds or {} do
				local seed = ReefConfig.Seeds[seedId]
				if seed then
					data.seeds[seedId] = math.min(ReefConfig.MAX_SEEDS_PER_TYPE, (data.seeds[seedId] or 0) + count)
					table.insert(extras, `{count} {seed.name} seed{if count == 1 then "" else "s"}`)
				end
			end
			if reward.title and ReefConfig.TitleById[reward.title] then
				data.titles[reward.title] = true
				table.insert(extras, `the "{ReefConfig.TitleById[reward.title].text}" title`)
			end
			local more = if #extras > 0 then ", " .. table.concat(extras, ", ") else ""
			notify(player, `Kelp challenge done: {challenge.title}! +{EconomyMath.formatNumber(reward.shells)} shells{more}`, "rare")
		end
	end
	return changed
end

-- Places noticed by where the player is: the forest, the canopy, the habitats, the glades.
local function notice(player: Player, profile: PlayerData.Profile): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	local at = root.Position
	if not KelpConfig.inForest(at) then
		return false
	end
	local state = profile.data.kelp
	local changed = false
	local function mark(set: { [string]: boolean }, id: string, text: string?)
		if not set[id] then
			set[id] = true
			changed = true
			if text then
				notify(player, text, "good")
			end
		end
	end
	mark(state.places, "reach", nil)
	if at.Y >= KelpConfig.CANOPY_Y then
		mark(state.places, "canopy", "You reached the kelp canopy! The sunlight up here is golden.")
	end
	for _, habitat in KelpConfig.Habitats do
		if ((at - habitat.at) * Vector3.new(1, 0, 1)).Magnitude <= habitat.radius then
			mark(state.places, habitat.id, `You found {habitat.name}. Turtles nest here!`)
		end
	end
	for _, glade in KelpConfig.Glades do
		if ((at - glade.at) * Vector3.new(1, 0, 1)).Magnitude <= glade.radius then
			mark(state.glades, glade.id, `You found a hidden place: {glade.name}!`)
		end
	end
	return changed
end

local function onPlant(player: Player, prompt: ProximityPrompt)
	local patch
	for _, candidate in patches do
		if candidate.prompt == prompt then
			patch = candidate
		end
	end
	local profile = PlayerData.get(player)
	local root = rootOf(player)
	if not patch or not profile or not root or patchStates[patch].state ~= "bare" then
		return
	end
	if (root.Position - patch.base.Position).Magnitude > KelpConfig.REACH + 4 then
		return
	end
	setPatch(patch, "growing")
	profile.data.kelp.restored += 1
	PlayerData.addShells(player, SETTINGS.plantShells)
	local health = math.round(Kelp.meadowHealth(patch.meadow) * 100)
	notify(player, `You planted seagrass! +{SETTINGS.plantShells} shells. The meadow is {health}% restored.`, "good")
	checkChallenges(player, profile)
	PlayerData.sync(player)
end

local function onNest(player: Player, prompt: ProximityPrompt)
	local nest = nestById[prompt:GetAttribute("NestId")]
	local profile = PlayerData.get(player)
	local root = rootOf(player)
	if not nest or not profile or not root or (root.Position - nest.at).Magnitude > KelpConfig.REACH + 4 then
		return
	end
	local state = profile.data.kelp
	local wait = KelpConfig.nestWait(state, nest.id, os.time())
	if wait > 0 then
		notify(player, `This nest is resting. Come back in {math.ceil(wait / 60)} min, or try another nest.`)
		return
	end
	state.nests[nest.id] = os.time()
	state.hatchlings += 1
	PlayerData.addShells(player, KelpConfig.hatchlingShells)
	notify(player, `A hatchling made it to the sea! +{KelpConfig.hatchlingShells} shells`, "good")
	checkChallenges(player, profile)
	PlayerData.sync(player)
end

function Kelp.start(kelpParts: any)
	patches = kelpParts.patches
	for _, patch in patches do
		-- Each meadow starts a little restored, so it's clear what you're working towards.
		setPatch(patch, if patch.index % 4 == 0 then "lush" else "bare")
	end
	for _, nest in kelpParts.nests do
		nestById[nest.id] = nest
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local kind = prompt:GetAttribute("Kind")
		if kind == "SeagrassPatch" then
			if RateLimit.consume(player) then
				onPlant(player, prompt)
			end
		elseif kind == "TurtleNest" then
			if RateLimit.consume(player) then
				onNest(player, prompt)
			end
		elseif kind == "Otto" then
			-- The client opens Otto's journal; Otto says hello too.
			Remotes.Notify:FireClient(player, ReefConfig.Shopkeepers.Otto.greetings[rng:NextInteger(1, #ReefConfig.Shopkeepers.Otto.greetings)], "info")
		end
	end)

	-- Once a second: grow and wilt the meadows, and notice where everyone has been.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, patch in patches do
				local entry = patchStates[patch]
				if entry.state == "growing" then
					if now - entry.since >= SETTINGS.growSeconds then
						setPatch(patch, "lush")
					else
						paintPatch(patch)
					end
				elseif entry.state == "lush" and now - entry.since >= SETTINGS.lushSeconds then
					setPatch(patch, "bare")
				end
			end
			for _, player in Players:GetPlayers() do
				local profile = PlayerData.get(player)
				if profile then
					local noticed = notice(player, profile)
					-- Fish caught anywhere count for the Kelp Naturalist, so check every second.
					local paid = checkChallenges(player, profile)
					if noticed or paid then
						PlayerData.sync(player)
					end
				end
			end
		end
	end)
end

return Kelp
