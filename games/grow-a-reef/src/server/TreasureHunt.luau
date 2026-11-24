--!nonstrict
-- Sunken Treasure Hunt, one of the sea events: a chest is buried at a random spot on open
-- seabed in the lagoon (inside its rim, outside the plaza, away from the buildings). The first
-- clue names the nearest landmark and a direction; the second, later, says how far from that
-- landmark and makes bubbles rise from the sand. Every player's HuntHeat attribute (Cold, Warm,
-- Hot, Burning hot!) shows on their HUD. The first to dig it up (a hold prompt that only shows
-- right on top of it) wins, and the hunt ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local RateLimit = require(script.Parent.RateLimit)
local EventVisuals = require(script.Parent.EventVisuals)

local TreasureHunt = {}

local SETTINGS = ReefConfig.Hunt
local GOLD = Color3.fromRGB(255, 205, 80)

local rng = Random.new()
local runId = 0
local spot: Vector3? = nil
local site: Model? = nil
local found = false

-- Lagoon landmarks a clue can point at, by their ReefConfig.Lagoon key.
local LANDMARKS = {
	{ key = "research", name = "the Research Laboratory" },
	{ key = "aquarium", name = "the Aquarium" },
	{ key = "coralShop", name = "the Coral Market" },
	{ key = "upgrade", name = "the Equipment Station" },
	{ key = "oceanGate", name = "the Ocean Gate" },
	{ key = "boards", name = "the leaderboards" },
	{ key = "guide", name = "Kai" },
}

local function landmarks(): { { name: string, at: Vector3 } }
	local list = {}
	for _, landmark in LANDMARKS do
		local at = ReefConfig.Lagoon[landmark.key]
		if typeof(at) == "Vector3" then
			table.insert(list, { name = landmark.name, at = at })
		end
	end
	return list
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- A random point on open seabed: inside the rim, outside the plaza, clear of the buildings.
local function pickSpot(): Vector3
	local lagoon = ReefConfig.Lagoon
	local rim = lagoon.rimRadius or SETTINGS.rimFallback
	local inner, outer = lagoon.plazaRadius + 12, rim - 15
	local x, z = lagoon.center.X, lagoon.center.Z + inner
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(rng:NextNumber(inner * inner, outer * outer))
		local px, pz = lagoon.center.X + math.cos(angle) * distance, lagoon.center.Z + math.sin(angle) * distance
		local clear = true
		for _, landmark in landmarks() do
			if flatDistance(Vector3.new(px, 0, pz), landmark.at) < SETTINGS.clearOfBuildings then
				clear = false
				break
			end
		end
		if clear then
			x, z = px, pz
			break
		end
	end
	-- Rest it on the seabed itself, not on kelp, rocks or players.
	local params = RaycastParams.new()
	local reef = Workspace:FindFirstChild("Reef")
	local seabed = reef and reef:FindFirstChild("Seabed")
	if seabed then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { seabed }
	else
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = {}
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		params.FilterDescendantsInstances = ignore
	end
	local hit = Workspace:Raycast(Vector3.new(x, 150, z), Vector3.new(0, -200, 0), params)
	return Vector3.new(x, if hit then hit.Position.Y else 0, z)
end

local function nearestLandmark(at: Vector3): { name: string, at: Vector3 }
	local best, bestDistance = { name = "the plaza", at = ReefConfig.Lagoon.center }, flatDistance(at, ReefConfig.Lagoon.center)
	for _, landmark in landmarks() do
		local d = flatDistance(at, landmark.at)
		if d < bestDistance then
			best, bestDistance = landmark, d
		end
	end
	return best
end

local function notifyAll(text: string, tone: string)
	for _, player in Players:GetPlayers() do
		Plots.notify(player, text, tone)
	end
end

local function reward(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local data = profile.data
	local shells = math.floor(SETTINGS.shells * math.max(1, data.unlocked / 10))
	PlayerData.addShells(player, shells)
	local parts = { `{EconomyMath.formatNumber(shells)} shells` }
	local seeds = table.clone(SETTINGS.seeds)
	if rng:NextNumber() < SETTINGS.seagrassChance then
		table.insert(seeds, { id = "seagrass", count = 1 })
	end
	for _, gift in seeds do
		local seed = ReefConfig.Seeds[gift.id]
		if seed then
			data.seeds[gift.id] = math.min(ReefConfig.MAX_SEEDS_PER_TYPE, (data.seeds[gift.id] or 0) + gift.count)
			table.insert(parts, `{gift.count} {seed.name}`)
		end
	end
	Plots.notify(player, `You dug up the sunken treasure! +{table.concat(parts, ", ")}`, "rare")
	PlayerData.sync(player)
end

-- onFound is called once when someone digs the chest up, so the event can end early.
function TreasureHunt.start(onFound: (() -> ())?)
	runId += 1
	local myRun = runId
	found = false
	local at = pickSpot()
	spot = at
	local model, root = EventVisuals.digSpot(at)
	model.Parent = Workspace
	site = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DigPrompt"
	prompt.ActionText = "Dig"
	prompt.ObjectText = "Something buried"
	prompt.HoldDuration = SETTINGS.digSeconds
	prompt.MaxActivationDistance = SETTINGS.digRange
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		if found or runId ~= myRun or not RateLimit.consume(player) then
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp or flatDistance(hrp.Position, at) > SETTINGS.digRange + 3 then
			return
		end
		found = true
		prompt.Enabled = false
		EventVisuals.openChest(at).Parent = model
		EventVisuals.burst(at + Vector3.new(0, 2, 0), GOLD, 80)
		EventVisuals.sound(at, "dig")
		reward(player)
		notifyAll(`{player.DisplayName} dug up the sunken treasure!`, "rare")
		if onFound then
			task.delay(4, onFound)
		end
	end)

	-- The first clue: the nearest landmark, and which side of it.
	local near = nearestLandmark(at)
	local side = ReefConfig.compass(at.X - near.at.X, at.Z - near.at.Z)
	notifyAll(`Clue 1: the old map shows the chest buried {side} of {near.name}.`, "rare")

	task.spawn(function()
		local started = os.clock()
		local secondClue = false
		while runId == myRun and not found do
			-- Everyone's hot/cold reading, for their HUD.
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				player:SetAttribute("HuntHeat", if hrp then ReefConfig.huntHeat(flatDistance(hrp.Position, at)) else nil)
			end
			if not secondClue and os.clock() - started >= SETTINGS.secondClueAt then
				secondClue = true
				local studs = math.round(flatDistance(at, near.at) / 5) * 5
				notifyAll(`Clue 2: about {studs} studs {side} of {near.name}. Look for bubbles rising from the sand!`, "rare")
				local bubbles = root:FindFirstChild("Bubbles") :: ParticleEmitter?
				if bubbles then
					bubbles.Rate = 8
				end
			end
			task.wait(0.5)
		end
	end)
end

function TreasureHunt.stop()
	runId += 1
	if site and not found and spot then
		local near = nearestLandmark(spot)
		local side = ReefConfig.compass(spot.X - near.at.X, spot.Z - near.at.Z)
		notifyAll(`Nobody found it! The chest was {side} of {near.name}. A crab dragged it away...`, "info")
	end
	local oldSite = site
	site = nil
	spot = nil
	if oldSite then
		task.delay(if found then 6 else 0, oldSite.Destroy, oldSite)
	end
	for _, player in Players:GetPlayers() do
		player:SetAttribute("HuntHeat", nil)
	end
end

return TreasureHunt
