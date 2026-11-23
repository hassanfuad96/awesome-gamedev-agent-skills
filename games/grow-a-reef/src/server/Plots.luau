--!nonstrict
-- Plot ownership, planting, growth and harvesting. Coral can be planted anywhere inside the
-- owner's round reef bed: the client sends only the clicked point (PlantAt), and the server
-- checks the plot, reach, slots, spacing and seed before planting. Coral is harvested by
-- clicking it (if the bag has room); ClickDetector.MouseClick fires on the server with the
-- real player. Clicking growing coral with a Bubble Wand speeds it up. Plots also draws each
-- reef's fence style, placed decorations and the name and likes on its sign.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local World = require(script.Parent.World)
local PlayerData = require(script.Parent.PlayerData)
local CoralVisuals = require(ReplicatedStorage.Shared.CoralVisuals)
local DecorVisuals = require(ReplicatedStorage.Shared.DecorVisuals)
local FenceVisuals = require(ReplicatedStorage.Shared.FenceVisuals)
local RateLimit = require(script.Parent.RateLimit)
local EventState = require(script.Parent.EventState)
local ReefIndex = require(script.Parent.ReefIndex)
local Quests = require(script.Parent.Quests)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

type PlotParts = World.PlotParts
type Profile = PlayerData.Profile
type Plant = PlayerData.Plant

export type ReadyCoral = { plantId: string, seed: string, mutation: string, position: Vector3 }

local Plots = {}

local plots: { PlotParts } = {}
local ownerByPlot: { [number]: Player } = {}
local plotByPlayer: { [Player]: PlotParts } = {}
local coralModels: { [Player]: { [string]: Model } } = {}
local decorModels: { [Player]: { [string]: Model } } = {}
local spawnConnections: { [Player]: RBXScriptConnection } = {}
local wandReadyAt: { [Player]: number } = {} -- os.clock() when the Bubble Wand can be used again
local rng = Random.new()

local MIN_SCALE = 0.25
local BED_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function notify(player: Player, text: string, tone: string?)
	Remotes.Notify:FireClient(player, text, tone or "info")
end
Plots.notify = notify

local displayName = ReefConfig.displayName

local function growthOf(plant: Plant): number
	local seed = ReefConfig.Seeds[plant.seed]
	if not seed then
		return 1
	end
	return math.clamp((os.time() - plant.plantedAt) / seed.growSeconds, 0, 1)
end

local function worldPosition(plot: PlotParts, plant: Plant): Vector3
	return ReefConfig.plotPoint(plot.frame, plant.x, plant.z, plot.bedTop)
end

-- The point's plot, if it lies on one of the reef mounds.
local function plotAt(point: Vector3): PlotParts?
	for _, plot in plots do
		local dx, dz = point.X - plot.center.X, point.Z - plot.center.Z
		if dx * dx + dz * dz <= plot.radius * plot.radius then -- false for NaN
			return plot
		end
	end
	return nil
end

local function setBedRadius(plot: PlotParts, radius: number)
	local size = Vector3.new(plot.bed.Size.X, radius * 2, radius * 2)
	if (plot.bed.Size - size).Magnitude > 0.01 then
		TweenService:Create(plot.bed, BED_TWEEN, { Size = size }):Play()
	end
end

local handleCoralClick: (Player, PlotParts, string) -> ()

local function setCoral(player: Player, plot: PlotParts, plantId: string, plant: Plant?)
	local models = coralModels[player]
	if not models then
		return
	end
	local existing = models[plantId]
	if existing then
		existing:Destroy()
		models[plantId] = nil
	end
	if not plant then
		return
	end

	-- A steady turn per plant (the golden angle) so a reef doesn't look stamped out.
	local turn = math.rad(((tonumber(plantId) or 0) * 137.5) % 360)
	local model = CoralVisuals.build(plant.seed, plant.mutation, CFrame.new(worldPosition(plot, plant)) * CFrame.Angles(0, turn, 0))
	model:ScaleTo(MIN_SCALE + (1 - MIN_SCALE) * growthOf(plant))
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 40
	click.Parent = model
	click.MouseClick:Connect(function(clicker)
		handleCoralClick(clicker, plot, plantId)
	end)
	local seed = ReefConfig.Seeds[plant.seed]
	model:SetAttribute("ReadyAt", plant.plantedAt + (if seed then seed.growSeconds else 0))
	-- Arrive whole on clients, so their labels and placement preview see a complete coral.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:AddTag(ReefConfig.CORAL_TAG)
	model.Parent = plot.model
	models[plantId] = model
end

-- Ground height at (x, z) from the plot centre: the bed where it reaches, else the mound.
local function groundAt(plot: PlotParts, x: number, z: number): number
	local bedRadius = plot.bed.Size.Y / 2
	return if x * x + z * z <= bedRadius * bedRadius then plot.bedTop else plot.center.Y + 1
end

local pickUpDecor: (Player, string) -> ()

local function setDecor(player: Player, plot: PlotParts, decorId: string, placed: ReefConfig.PlacedDecor?)
	local models = decorModels[player]
	if not models then
		return
	end
	if models[decorId] then
		models[decorId]:Destroy()
		models[decorId] = nil
	end
	if not placed then
		return
	end
	local item = ReefConfig.DecorById[placed.item]
	if not item then
		return
	end
	local at = ReefConfig.plotPoint(plot.frame, placed.x, placed.z, groundAt(plot, placed.x, placed.z))
	local model = DecorVisuals.build(placed.item, CFrame.new(at))
	model:SetAttribute("DecorItem", placed.item)
	model:SetAttribute("OwnerUserId", player.UserId)
	-- The owner picks it up again here. Clients hide the prompt on other people's reefs.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUpPrompt"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = item.name
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", "Decor")
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(by)
		if by == player then
			pickUpDecor(player, decorId)
		end
	end)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:AddTag(ReefConfig.DECOR_TAG)
	model.Parent = plot.model
	models[decorId] = model
end

-- Builds the plot's fence in `fenceId`'s style (unless it already is).
local function buildFence(plot: PlotParts, fenceId: string)
	if plot.fence and plot.fence.Parent and plot.fence:GetAttribute("FenceId") == fenceId then
		return
	end
	if plot.fence then
		plot.fence:Destroy()
	end
	plot.fence = FenceVisuals.build(fenceId, plot.fenceFrame, plot.fenceRadius, Random.new(plot.index))
	plot.fence.Parent = plot.model
end

-- The name over the gate, and the reef's likes under it.
local function updateSign(player: Player)
	local plot = plotByPlayer[player]
	local profile = PlayerData.get(player)
	if plot and profile then
		plot.sign.Text = `{player.DisplayName}'s Reef`
		local likes = profile.data.likes
		plot.likes.Text = if likes == 1 then "1 like" else `{EconomyMath.formatNumber(likes)} likes`
	end
end
Plots.updateSign = updateSign

local function renderPlot(player: Player, profile: Profile)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	setBedRadius(plot, ReefConfig.bedRadius(profile.data.unlocked))
	for plantId, plant in profile.data.plants do
		setCoral(player, plot, plantId, plant)
	end
	for decorId, placed in profile.data.decor do
		setDecor(player, plot, decorId, placed)
	end
	buildFence(plot, profile.data.fence)
	updateSign(player)
end

local function plant(player: Player, profile: Profile, plot: PlotParts, x: number, z: number)
	local seedId = profile.selected
	if not seedId then
		notify(player, "Pick a seed from your hotbar first.")
		return
	end
	local owned = profile.data.seeds[seedId] or 0
	if owned <= 0 then
		notify(player, `You're out of {ReefConfig.Seeds[seedId].name} seeds. Buy more at the Coral Shop.`)
		return
	end
	profile.data.seeds[seedId] = if owned > 1 then owned - 1 else nil
	if owned <= 1 then
		profile.selected = nil
	end

	local mutation = EconomyMath.pickWeighted(EventState.mutationWeights(), rng:NextNumber())
	profile.data.plantSeq += 1
	local plantId = tostring(profile.data.plantSeq)
	local newPlant = { seed = seedId, plantedAt = os.time(), mutation = mutation, x = x, z = z }
	profile.data.plants[plantId] = newPlant
	setCoral(player, plot, plantId, newPlant)
	if mutation ~= "None" then
		notify(player, `Lucky! A {displayName(seedId, mutation)} sprouted!`, "rare")
	end
	Quests.progress(player, "plant", 1)
	PlayerData.sync(player)
end

local function bagFull(profile: Profile): boolean
	return PlayerData.bagCount(profile.data) >= PlayerData.bagCapacity(profile.data)
end

-- `by` names a pet that harvested for the player ("Your Octopus"). Callers check the bag
-- has room first.
local function harvest(player: Player, profile: Profile, plot: PlotParts, plantId: string, grown: Plant, by: string?)
	profile.data.plants[plantId] = nil
	local key = ReefConfig.inventoryKey(grown.seed, grown.mutation)
	profile.data.inventory[key] = (profile.data.inventory[key] or 0) + 1
	profile.data.harvested += 1
	setCoral(player, plot, plantId, nil)
	local value = math.floor(ReefConfig.harvestValue(grown.seed, grown.mutation) * ReefConfig.shellMultiplier(profile.data.rebirths))
	local what = if by then `{by} harvested a` else "+1"
	notify(player, `{what} {displayName(grown.seed, grown.mutation)} (sells for {EconomyMath.formatNumber(value)} shells)`, "good")
	ReefIndex.discoverCoral(player, profile, grown.seed, grown.mutation)
	Quests.progress(player, "harvest", 1)
	if grown.mutation ~= "None" then
		Quests.progress(player, "mutated", 1)
	end
	PlayerData.sync(player)
end

-- A burst of bubbles where the Bubble Wand hit.
local function wandBurst(position: Vector3)
	local spot = Instance.new("Part")
	spot.Name = "WandBubbles"
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.Transparency = 1
	spot.Size = Vector3.new(1, 1, 1)
	spot.Position = position + Vector3.new(0, 1.5, 0)
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(170, 240, 255))
	bubbles.LightEmission = 0.6
	bubbles.Size = NumberSequence.new(0.5, 1)
	bubbles.Transparency = NumberSequence.new(0, 1)
	bubbles.Lifetime = NumberRange.new(0.8, 1.5)
	bubbles.Speed = NumberRange.new(4, 9)
	bubbles.SpreadAngle = Vector2.new(60, 60)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Enabled = false
	bubbles.Parent = spot
	spot.Parent = workspace
	bubbles:Emit(24)
	task.delay(2, spot.Destroy, spot)
end

-- The Bubble Wand: speeds up one growing coral, then needs to refill. Returns false when
-- the player has no wand.
local function useWand(player: Player, profile: Profile, plot: PlotParts, plantId: string, growing: Plant): boolean
	local level = profile.data.gear.wand or 0
	if level <= 0 then
		return false
	end
	local seed = ReefConfig.Seeds[growing.seed]
	local now = os.clock()
	local readyAt = wandReadyAt[player] or 0
	if now < readyAt then
		local left = growing.plantedAt + seed.growSeconds - os.time()
		notify(player, `{displayName(growing.seed, growing.mutation)}: {math.ceil(left)}s until it's ready. The wand refills in {math.ceil(readyAt - now)}s.`)
		return true
	end
	wandReadyAt[player] = now + ReefConfig.Gear.wand.cooldown
	local boost = ReefConfig.wandBoost(level, seed.growSeconds)
	growing.plantedAt -= boost
	local model = coralModels[player] and coralModels[player][plantId]
	if model then
		model:SetAttribute("ReadyAt", growing.plantedAt + seed.growSeconds)
	end
	wandBurst(worldPosition(plot, growing))
	local left = math.max(0, math.ceil(growing.plantedAt + seed.growSeconds - os.time()))
	notify(player, if left > 0 then `Bubble Wand: +{math.round(boost)}s of growth! Ready in {left}s.` else "Bubble Wand: it's fully grown! Click it to harvest.", "good")
	return true
end

local function notifyNotYours(player: Player, plot: PlotParts)
	local owner = ownerByPlot[plot.index]
	notify(player, if owner then `That's {owner.DisplayName}'s reef.` else "Nobody owns this reef.")
end

handleCoralClick = function(player: Player, plot: PlotParts, plantId: string)
	if ownerByPlot[plot.index] ~= player then
		notifyNotYours(player, plot)
		return
	end
	if not RateLimit.consume(player) then
		return
	end
	local profile = PlayerData.get(player)
	local clicked = profile and profile.data.plants[plantId]
	if not profile or not clicked then
		return
	end
	if growthOf(clicked) >= 1 then
		if bagFull(profile) then
			local capacity = PlayerData.bagCapacity(profile.data)
			notify(player, `Your bag is full ({capacity}/{capacity})! Sell your coral at Sell Coral, or get a Bigger Bag at the Upgrade Station.`, "bad")
			return
		end
		harvest(player, profile, plot, plantId, clicked)
	elseif not useWand(player, profile, plot, plantId, clicked) then
		local seed = ReefConfig.Seeds[clicked.seed]
		local left = clicked.plantedAt + seed.growSeconds - os.time()
		notify(player, `{displayName(clicked.seed, clicked.mutation)}: {math.ceil(left)}s until it's ready.`)
	end
end

local function onPlantAt(player: Player, point: unknown)
	if typeof(point) ~= "Vector3" or not RateLimit.consume(player) then
		return
	end
	local position = point :: Vector3
	local profile = PlayerData.get(player)
	local plot = plotAt(position)
	if not profile or not plot then
		return
	end
	if ownerByPlot[plot.index] ~= player then
		notifyNotYours(player, plot)
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - position).Magnitude > ReefConfig.PLANT_REACH then
		notify(player, "Swim closer to your reef to plant.")
		return
	end
	local offsetX, offsetZ = ReefConfig.plotOffset(plot.frame, position)
	local x = math.round(offsetX * 10) / 10
	local z = math.round(offsetZ * 10) / 10
	local problem = ReefConfig.plantProblem(x, z, profile.data.unlocked, profile.data.plants, profile.data.decor)
	if problem then
		notify(player, problem)
		return
	end
	plant(player, profile, plot, x, z)
end

function Plots.assign(player: Player, profile: Profile)
	local free: PlotParts? = nil
	for _, plot in plots do
		if not ownerByPlot[plot.index] then
			free = plot
			break
		end
	end
	if not free then
		player:Kick("This reef server is full. Please join another server.")
		return
	end
	local plot = free :: PlotParts
	ownerByPlot[plot.index] = player
	plotByPlayer[player] = plot
	coralModels[player] = {}
	decorModels[player] = {}
	plot.model:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("PlotIndex", plot.index)
	renderPlot(player, profile)

	-- Players still in the tutorial start in the middle of the lagoon, by Inky; everyone else
	-- (and every respawn, like after an orca) starts at home.
	local startAtPlaza = ReefConfig.tutorialStep(profile.data.tutorial) ~= nil
	local function moveToPlot(character: Model)
		if startAtPlaza then
			startAtPlaza = false
			return
		end
		task.defer(function()
			if character.Parent and plotByPlayer[player] == plot then
				character:PivotTo(plot.spawn)
			end
		end)
	end
	spawnConnections[player] = player.CharacterAdded:Connect(moveToPlot)
	if player.Character then
		moveToPlot(player.Character)
	end
end

function Plots.release(player: Player)
	local plot = plotByPlayer[player]
	if spawnConnections[player] then
		spawnConnections[player]:Disconnect()
		spawnConnections[player] = nil
	end
	if not plot then
		return
	end
	for _, model in coralModels[player] or {} do
		model:Destroy()
	end
	for _, model in decorModels[player] or {} do
		model:Destroy()
	end
	setBedRadius(plot, ReefConfig.bedRadius(ReefConfig.STARTING_SLOTS))
	buildFence(plot, ReefConfig.DEFAULT_FENCE)
	plot.sign.Text = "Empty reef"
	plot.likes.Text = ""
	plot.model:SetAttribute("OwnerUserId", nil)
	ownerByPlot[plot.index] = nil
	plotByPlayer[player] = nil
	coralModels[player] = nil
	decorModels[player] = nil
	wandReadyAt[player] = nil
end

-- Puts up the owner's chosen fence style (after they buy or pick one).
function Plots.setFence(player: Player)
	local profile = PlayerData.get(player)
	local plot = plotByPlayer[player]
	if profile and plot then
		buildFence(plot, profile.data.fence)
	end
end

-- Places one decoration from storage at `point` on the player's own reef. The server checks
-- everything again (ReefConfig.decorProblem). Returns true when it was placed.
function Plots.placeDecor(player: Player, itemId: string, point: Vector3): boolean
	local profile = PlayerData.get(player)
	local plot = plotAt(point)
	local item = ReefConfig.DecorById[itemId]
	if not profile or not item then
		return false
	end
	if not plot or ownerByPlot[plot.index] ~= player then
		notify(player, "Place decorations on your own reef.")
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - point).Magnitude > ReefConfig.PLANT_REACH then
		notify(player, "Swim closer to your reef to place it.")
		return false
	end
	local stored = profile.data.decorStorage[itemId] or 0
	if stored <= 0 then
		notify(player, `You have no {item.name} to place. Buy one at the Upgrade Station.`)
		return false
	end
	local offsetX, offsetZ = ReefConfig.plotOffset(plot.frame, point)
	local x = math.round(offsetX * 10) / 10
	local z = math.round(offsetZ * 10) / 10
	local problem = ReefConfig.decorProblem(itemId, x, z, profile.data.plants, profile.data.decor)
	if problem then
		notify(player, problem)
		return false
	end
	profile.data.decorStorage[itemId] = if stored > 1 then stored - 1 else nil
	profile.data.decorSeq += 1
	local decorId = tostring(profile.data.decorSeq)
	local placed = { item = itemId, x = x, z = z }
	profile.data.decor[decorId] = placed
	setDecor(player, plot, decorId, placed)
	local left = profile.data.decorStorage[itemId] or 0
	notify(player, if left > 0 then `Placed your {item.name}! {left} more to place.` else `Placed your {item.name}!`, "good")
	return true
end

pickUpDecor = function(player: Player, decorId: string)
	if not RateLimit.consume(player) then
		return
	end
	local profile = PlayerData.get(player)
	local plot = plotByPlayer[player]
	local placed = profile and profile.data.decor[decorId]
	if not plot or not placed then
		return
	end
	profile.data.decor[decorId] = nil
	profile.data.decorStorage[placed.item] = (profile.data.decorStorage[placed.item] or 0) + 1
	setDecor(player, plot, decorId, nil)
	notify(player, `Picked up your {ReefConfig.DecorById[placed.item].name}. Place it again from the Upgrade Station.`)
	PlayerData.sync(player)
end

-- After a rebirth: the coral is gone and the bed is back to its starting size.
function Plots.resetReef(player: Player)
	local plot = plotByPlayer[player]
	local models = coralModels[player]
	if not plot or not models then
		return
	end
	for plantId, model in models do
		model:Destroy()
		models[plantId] = nil
	end
	setBedRadius(plot, ReefConfig.bedRadius(ReefConfig.STARTING_SLOTS))
end

-- Where the player arrives home: on the pad in front of their reef's gate.
function Plots.homeFor(player: Player): CFrame?
	local plot = plotByPlayer[player]
	return plot and plot.spawn
end

-- Called after the reef grows: widens the bed to the new slot count.
function Plots.refresh(player: Player)
	local profile = PlayerData.get(player)
	local plot = plotByPlayer[player]
	if profile and plot then
		setBedRadius(plot, ReefConfig.bedRadius(profile.data.unlocked))
	end
end

function Plots.plotOf(player: Player): PlotParts?
	return plotByPlayer[player]
end

function Plots.ownerOf(plotIndex: number): Player?
	return ownerByPlot[plotIndex]
end

function Plots.count(): number
	return #plots
end

-- Fully grown coral still on the reef (used by fish and currents).
function Plots.readyCorals(player: Player): { ReadyCoral }
	local result: { ReadyCoral } = {}
	local profile = PlayerData.get(player)
	local plot = plotByPlayer[player]
	if not profile or not plot then
		return result
	end
	for plantId, grown in profile.data.plants do
		if growthOf(grown) >= 1 then
			table.insert(result, {
				plantId = plantId,
				seed = grown.seed,
				mutation = grown.mutation,
				position = worldPosition(plot, grown),
			})
		end
	end
	return result
end

-- Planted coral, grown or not, that could still take this mutation (currents use it).
function Plots.plantsAccepting(player: Player, mutationId: string): { string }
	local result: { string } = {}
	local profile = PlayerData.get(player)
	if not profile then
		return result
	end
	for plantId, growing in profile.data.plants do
		if ReefConfig.withMutation(growing.mutation, mutationId) then
			table.insert(result, plantId)
		end
	end
	return result
end

-- Every growing coral counts as planted `seconds` earlier, so it grows faster: for
-- everyone (Whale Pass) or for one player (a seahorse). Shifting the saved planting time
-- keeps growth a plain timestamp, offline included.
function Plots.boostGrowth(seconds: number, only: Player?)
	for player, models in coralModels do
		local profile = PlayerData.get(player)
		if profile and (not only or player == only) then
			for plantId, growing in profile.data.plants do
				local seed = ReefConfig.Seeds[growing.seed]
				if seed and growthOf(growing) < 1 then
					growing.plantedAt -= seconds
					local model = models[plantId]
					if model then
						model:SetAttribute("ReadyAt", growing.plantedAt + seed.growSeconds)
					end
				end
			end
		end
	end
end

-- Adds one mutation to a planted coral. Returns the coral's new mutation key, or nil when
-- it can't take that mutation (it has it already, or it's full).
function Plots.addMutation(player: Player, plantId: string, mutationId: string): string?
	local profile = PlayerData.get(player)
	local plot = plotByPlayer[player]
	local target = profile and profile.data.plants[plantId]
	if not plot or not target then
		return nil
	end
	local key = ReefConfig.withMutation(target.mutation, mutationId)
	if not key then
		return nil
	end
	target.mutation = key
	setCoral(player, plot, plantId, target)
	return key
end

-- Sea events (Cold Current, Night): each fully grown coral on every reef takes the
-- mutation with this chance, if it has room for it.
function Plots.mutateAll(mutationId: string, chance: number)
	for player in coralModels do
		local profile = PlayerData.get(player)
		if profile then
			for plantId, growing in profile.data.plants do
				if growthOf(growing) >= 1 and rng:NextNumber() < chance then
					local key = Plots.addMutation(player, plantId, mutationId)
					if key then
						local multiplier = ReefConfig.mutationMultiplier(key)
						notify(player, `Your coral turned {mutationId}: {displayName(growing.seed, key)} (x{multiplier})!`, "rare")
					end
				end
			end
		end
	end
end

-- Harvests one fully grown coral for a pet. Returns false when none is ready.
function Plots.harvestOne(player: Player, by: string): boolean
	local profile = PlayerData.get(player)
	local plot = plotByPlayer[player]
	if not profile or not plot then
		return false
	end
	if bagFull(profile) then
		return false -- the octopus waits until there is room
	end
	for plantId, growing in profile.data.plants do
		if growthOf(growing) >= 1 then
			harvest(player, profile, plot, plantId, growing, by)
			return true
		end
	end
	return false
end

function Plots.start(worldParts: World.WorldParts)
	plots = worldParts.plots
	Remotes.PlantAt.OnServerEvent:Connect(onPlantAt)
	PlayerData.onLoaded(Plots.assign)
	Players.PlayerRemoving:Connect(Plots.release)

	-- Grow coral visibly. Growth itself is just a timestamp, so it continues while offline.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, models in coralModels do
				local profile = PlayerData.get(player)
				if profile then
					for plantId, model in models do
						local growing = profile.data.plants[plantId]
						if growing and model.Parent then
							local target = MIN_SCALE + (1 - MIN_SCALE) * growthOf(growing)
							if math.abs(model:GetScale() - target) > 0.01 then
								model:ScaleTo(target)
							end
						end
					end
				end
			end
		end
	end)
end

return Plots
