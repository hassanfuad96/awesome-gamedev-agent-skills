--!nonstrict
-- Fully grown coral attracts fish. Only the reef's owner can click a fish to catch it;
-- the value comes from the coral that attracted it, decided when the fish spawns.

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
local RateLimit = require(script.Parent.RateLimit)

local Fish = {}

local fishByPlayer: { [Player]: { [Model]: true } } = {}
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

local function spawnFish(player: Player, coral: Plots.ReadyCoral)
	local plot = Plots.plotOf(player)
	if not plot then
		return
	end
	local kindId = EconomyMath.pickWeighted(ReefConfig.Fish.kinds, rng:NextNumber())
	local kind: ReefConfig.FishDef? = nil
	for _, candidate in ReefConfig.Fish.kinds do
		if candidate.id == kindId then
			kind = candidate
		end
	end
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
		if not RateLimit.consume(clicker) then
			return
		end
		local profile = PlayerData.get(clicker)
		if not profile then
			return
		end
		caught = true
		-- A pufferfish makes the catch worth more.
		local earned = math.floor(value * Pets.fishMultiplier(clicker))
		PlayerData.addShells(clicker, earned)
		profile.data.fishCaught += 1
		Plots.notify(clicker, `Caught a {fishKind.id}! +{EconomyMath.formatNumber(earned)} shells`, if fishKind.multiplier >= 4 then "rare" else "good")
		ReefIndex.discoverFish(clicker, profile, fishKind.id)
		PlayerData.sync(clicker)
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
		local expires = os.clock() + ReefConfig.Fish.lifetime
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
		if not caught then
			despawn(player, model)
		end
	end)
end

function Fish.start()
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
					if rng:NextNumber() < ReefConfig.Fish.spawnChance then
						spawnFish(player, coral)
					end
				end
			end
		end
	end)
end

return Fish
