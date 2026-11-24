--!nonstrict
-- Fully grown coral attracts fish. Only the reef's owner can click a fish to catch it;
-- the value comes from the coral that attracted it, decided when the fish spawns.
-- Wild fish also gather at the Main Reef's fish nurseries (ReefConfig.MainReef.fishSpots)
-- and in the Kelp Forest (KelpConfig.FishSpots, its own species); anyone can catch those,
-- first click wins. Kelp spots by a seagrass meadow only have fish while it's half restored.
-- Fish with a mesh model (FishDef.creature, see Creatures) swim as that model once the
-- templates are built; the rest (and every fish before then) are a Part-built body and tail.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local EventState = require(script.Parent.EventState)
local Pets = require(script.Parent.Pets)
local ReefIndex = require(script.Parent.ReefIndex)
local Quests = require(script.Parent.Quests)
local Tutorial = require(script.Parent.Tutorial)
local Kelp = require(script.Parent.Kelp)
local KelpConfig = require(ReplicatedStorage.Shared.KelpConfig)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local RateLimit = require(script.Parent.RateLimit)

local Fish = {}

local fishByPlayer: { [Player]: { [Model]: true } } = {}
local wildBySpot: { [string]: { [Model]: true } } = {}
local wildFolder: Folder
local rng = Random.new()

local function countFish(player: Player): number
	local count = 0
	for _ in fishByPlayer[player] or {} do
		count += 1
	end
	return count
end

local function despawn(player: Player, model: Model)
	local owned = fishByPlayer[player]
	if owned then
		owned[model] = nil
	end
	if model.Parent then
		model:Destroy()
	end
end

local function buildFish(kind: ReefConfig.FishDef, at: CFrame): (Model, BasePart)
	local creature = kind.creature and Creatures.clone(kind.creature)
	if creature then
		creature.Name = kind.id
		creature:SetAttribute("Pace", 1.4) -- always darting somewhere (CreatureAnimator)
		creature:PivotTo(at)
		local root = creature.PrimaryPart :: BasePart
		if kind.multiplier >= 10 then
			local glow = Instance.new("PointLight")
			glow.Color = kind.color
			glow.Range = 8
			glow.Parent = root
		end
		return creature, root
	end

	local model = Instance.new("Model")
	model.Name = kind.id

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.Size = Vector3.new(0.9, 1.1, 2)
	body.Color = kind.color
	body.Material = Enum.Material.SmoothPlastic
	body.CFrame = at
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	body.Parent = model

	-- The tail is unanchored and welded, so tweening the body carries it along.
	local tail = Instance.new("WedgePart")
	tail.Name = "Tail"
	tail.Anchored = false
	tail.CanCollide = false
	tail.CanTouch = false
	tail.Massless = true
	tail.Size = Vector3.new(0.2, 1, 0.8)
	tail.Color = kind.color:Lerp(Color3.new(0, 0, 0), 0.25)
	tail.CFrame = at * CFrame.new(0, 0, 1.3) * CFrame.Angles(0, math.rad(180), 0)
	tail.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = tail
	weld.Parent = body

	if kind.multiplier >= 10 then
		local glow = Instance.new("PointLight")
		glow.Color = kind.color
		glow.Range = 8
		glow.Parent = body
	end

	model.PrimaryPart = body
	return model, body
end

-- Reef fish (weight > 0) and Kelp Forest fish (kelpWeight), as weighted outcomes.
local REEF_ODDS, KELP_ODDS = {}, {}
local KIND_BY_ID: { [string]: ReefConfig.FishDef } = {}
for _, kind in ReefConfig.Fish.kinds do
	KIND_BY_ID[kind.id] = kind
	if kind.weight > 0 then
		table.insert(REEF_ODDS, { id = kind.id, weight = kind.weight })
	end
	if kind.kelpWeight then
		table.insert(KELP_ODDS, { id = kind.id, weight = kind.kelpWeight })
	end
end

local function pickKind(forest: boolean?): ReefConfig.FishDef?
	return KIND_BY_ID[EconomyMath.pickWeighted(if forest then KELP_ODDS else REEF_ODDS, rng:NextNumber())]
end

-- Swims the fish between random points from randomPoint until it expires or is caught.
-- Returns when it's gone; the caller cleans up.
local function swimAbout(model: Model, body: BasePart, randomPoint: () -> Vector3, lifetime: number)
	local expires = os.clock() + lifetime
	while model.Parent and os.clock() < expires do
		local target = randomPoint()
		local from = body.Position
		local direction = target - from
		if direction.Magnitude > 0.5 then
			body.CFrame = CFrame.lookAt(from, target)
			TweenService:Create(body, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				CFrame = CFrame.lookAt(target, target + direction.Unit),
			}):Play()
		end
		-- A fixed wait (not tween.Completed) so a destroyed fish can't stall this loop.
		task.wait(2.6)
	end
end

-- Pays the catcher for a fish worth `value` before their own bonuses.
local function reward(clicker: Player, kind: ReefConfig.FishDef, value: number)
	local profile = PlayerData.get(clicker)
	if not profile then
		return
	end
	-- A pufferfish makes the catch worth more, and so do rebirths.
	local earned = math.floor(value * Pets.fishMultiplier(clicker) * PlayerData.saleMultiplier(profile.data))
	PlayerData.addShells(clicker, earned)
	profile.data.fishCaught += 1
	Quests.progress(clicker, "fish", 1)
	Plots.notify(clicker, `Caught a {kind.id}! +{EconomyMath.formatNumber(earned)} shells`, if kind.multiplier >= 4 then "rare" else "good")
	ReefIndex.discoverFish(clicker, profile, kind.id)
	PlayerData.sync(clicker)
end

-- A wild fish at spot `key` (a Main Reef nursery or a Kelp Forest spot): anyone can click it.
local function spawnWild(key: string, spot: Vector3, forest: boolean)
	local kind = pickKind(forest)
	if not kind then
		return
	end
	local fishKind = kind :: ReefConfig.FishDef
	local settings = ReefConfig.Fish.wild
	local function randomPoint(): Vector3
		return spot + Vector3.new(rng:NextNumber(-settings.roam, settings.roam), rng:NextNumber(2.5, 7), rng:NextNumber(-settings.roam, settings.roam))
	end
	local model, body = buildFish(fishKind, CFrame.new(randomPoint()))
	model:SetAttribute("Wild", true)
	local caught = false
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 40
	click.Parent = model
	click.MouseClick:Connect(function(clicker)
		if caught or not RateLimit.consume(clicker) or not PlayerData.get(clicker) then
			return
		end
		caught = true
		reward(clicker, fishKind, settings.value * fishKind.multiplier)
		model:Destroy()
	end)
	model.Parent = wildFolder
	local here = wildBySpot[key]
	here[model] = true
	task.spawn(function()
		swimAbout(model, body, randomPoint, ReefConfig.Fish.lifetime)
		here[model] = nil
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function spawnFish(player: Player, coral: Plots.ReadyCoral)
	local plot = Plots.plotOf(player)
	if not plot then
		return
	end
	local kind = pickKind()
	if not kind then
		return
	end
	local fishKind = kind :: ReefConfig.FishDef

	local seed = ReefConfig.Seeds[coral.seed]
	local mutations = ReefConfig.mutationMultiplier(coral.mutation)
	local value = math.max(1, math.floor(seed.sellValue * ReefConfig.Fish.valueFraction * fishKind.multiplier * mutations))

	local home = coral.position
	local function randomPoint(): Vector3
		return home + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(3, 7), rng:NextNumber(-10, 10))
	end
	local start = randomPoint()
	local model, body = buildFish(fishKind, CFrame.new(start))
	model:SetAttribute("Value", value)
	model:SetAttribute("OwnerUserId", player.UserId)

	local caught = false
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 40
	click.Parent = model
	click.MouseClick:Connect(function(clicker)
		if caught then
			return
		end
		if clicker ~= player then
			Plots.notify(clicker, "Only the reef owner can catch these fish.")
			return
		end
		if not RateLimit.consume(clicker) or not PlayerData.get(clicker) then
			return
		end
		caught = true
		reward(clicker, fishKind, value)
		despawn(clicker, model)
	end)

	model.Parent = plot.model
	local owned = fishByPlayer[player]
	if not owned then
		owned = {}
		fishByPlayer[player] = owned
	end
	(owned :: { [Model]: true })[model] = true

	task.spawn(function()
		swimAbout(model, body, randomPoint, ReefConfig.Fish.lifetime)
		if not caught then
			despawn(player, model)
		end
	end)
end

function Fish.start()
	wildFolder = Instance.new("Folder")
	wildFolder.Name = "WildFish"
	wildFolder.Parent = workspace:FindFirstChild("Reef") or workspace
	-- Every wild fish spot: the Main Reef's nurseries and the Kelp Forest's spots.
	local spots = {}
	for index, at in ReefConfig.MainReef.fishSpots do
		table.insert(spots, { key = `reef{index}`, at = at, forest = false })
	end
	for index, spot in KelpConfig.FishSpots do
		table.insert(spots, { key = `kelp{index}`, at = spot.at, forest = true, meadow = spot.meadow })
	end
	for _, spot in spots do
		wildBySpot[spot.key] = {}
	end
	-- Each spot tops up to perSpot, one fish at a time.
	task.spawn(function()
		while true do
			task.wait(ReefConfig.Fish.wild.interval)
			for _, spot in spots do
				local count = 0
				for _ in wildBySpot[spot.key] do
					count += 1
				end
				local healthy = not spot.meadow or Kelp.meadowHealth(spot.meadow) >= 0.5
				if count < ReefConfig.Fish.wild.perSpot and healthy then
					spawnWild(spot.key, spot.at, spot.forest)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for model in fishByPlayer[player] or {} do
			model:Destroy()
		end
		fishByPlayer[player] = nil
	end)

	task.spawn(function()
		-- A spawn clock rather than a plain wait, so a Feeding Frenzy speeds it up mid-wait.
		local clock = 0
		while true do
			task.wait(1)
			clock += EventState.fishSpawnMultiplier()
			if clock < ReefConfig.Fish.spawnInterval then
				continue
			end
			clock = 0
			for _, player in Players:GetPlayers() do
				for _, coral in Plots.readyCorals(player) do
					if countFish(player) >= ReefConfig.Fish.maxPerPlot then
						break
					end
					-- On the tutorial's fish step, every ready coral brings one, so nobody waits.
					local chance = if Tutorial.isOn(player, "fish") then 1 else ReefConfig.Fish.spawnChance
					if rng:NextNumber() < chance then
						spawnFish(player, coral)
					end
				end
			end
		end
	end)
end

return Fish
