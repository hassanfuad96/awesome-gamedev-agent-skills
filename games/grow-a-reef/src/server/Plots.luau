--!nonstrict
-- Plot ownership, planting, growth and harvesting. Coral can be planted anywhere inside the
-- owner's round reef bed: the client sends only the clicked point (PlantAt), and the server
-- checks the plot, reach, slots, spacing and seed before planting. Coral is harvested by
-- clicking it; ClickDetector.MouseClick fires on the server with the real player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local World = require(script.Parent.World)
local PlayerData = require(script.Parent.PlayerData)
local CoralVisuals = require(script.Parent.CoralVisuals)
local RateLimit = require(script.Parent.RateLimit)
local EventState = require(script.Parent.EventState)

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
local spawnConnections: { [Player]: RBXScriptConnection } = {}
local rng = Random.new()

local MIN_SCALE = 0.25
local BED_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function notify(player: Player, text: string, tone: string?)
	Remotes.Notify:FireClient(player, text, tone or "info")
end
Plots.notify = notify

local function displayName(seedId: string, mutationId: string): string
	local seed = ReefConfig.Seeds[seedId]
	local name = if seed then seed.name else seedId
	return if mutationId == "None" then name else mutationId .. " " .. name
end
Plots.displayName = displayName

local function growthOf(plant: Plant): number
	local seed = ReefConfig.Seeds[plant.seed]
	if not seed then
		return 1
	end
	return math.clamp((os.time() - plant.plantedAt) / seed.growSeconds, 0, 1)
end

local function worldPosition(plot: PlotParts, plant: Plant): Vector3
	return Vector3.new(plot.center.X + plant.x, plot.bedTop, plot.center.Z + plant.z)
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

local function renderPlot(player: Player, profile: Profile)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	setBedRadius(plot, ReefConfig.bedRadius(profile.data.unlocked))
	for plantId, plant in profile.data.plants do
		setCoral(player, plot, plantId, plant)
	end
end

local function plant(player: Player, profile: Profile, plot: PlotParts, x: number, z: number)
	local seedId = profile.selected
	if not seedId then
		notify(player, "Pick a seed from your hotbar first.")
		return
	end
	local owned = profile.data.seeds[seedId] or 0
	if owned <= 0 then
		notify(player, `You're out of {ReefConfig.Seeds[seedId].name} seeds. Buy more at the Seed Shop.`)
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
	PlayerData.sync(player)
end

local function harvest(player: Player, profile: Profile, plot: PlotParts, plantId: string, grown: Plant)
	profile.data.plants[plantId] = nil
	local key = ReefConfig.inventoryKey(grown.seed, grown.mutation)
	profile.data.inventory[key] = (profile.data.inventory[key] or 0) + 1
	profile.data.harvested += 1
	setCoral(player, plot, plantId, nil)
	local value = ReefConfig.harvestValue(grown.seed, grown.mutation)
	notify(player, `+1 {displayName(grown.seed, grown.mutation)} (sells for {EconomyMath.formatNumber(value)} shells)`, "good")
	PlayerData.sync(player)
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
		harvest(player, profile, plot, plantId, clicked)
	else
		local seed = ReefConfig.Seeds[clicked.seed]
		local left = clicked.plantedAt + seed.growSeconds - os.time()
		notify(player, `{displayName(clicked.seed, clicked.mutation)}: {left}s until it's ready.`)
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
	local x = math.round((position.X - plot.center.X) * 10) / 10
	local z = math.round((position.Z - plot.center.Z) * 10) / 10
	local problem = ReefConfig.plantProblem(x, z, profile.data.unlocked, profile.data.plants)
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
	plot.sign.Text = `{player.DisplayName}'s Reef`
	plot.model:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("PlotIndex", plot.index)
	renderPlot(player, profile)

	local function moveToPlot(character: Model)
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
	setBedRadius(plot, ReefConfig.bedRadius(ReefConfig.STARTING_SLOTS))
	plot.sign.Text = "Empty reef"
	plot.model:SetAttribute("OwnerUserId", nil)
	ownerByPlot[plot.index] = nil
	plotByPlayer[player] = nil
	coralModels[player] = nil
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

-- Planted coral without a mutation, grown or not (currents can mutate these).
function Plots.unmutatedPlants(player: Player): { string }
	local result: { string } = {}
	local profile = PlayerData.get(player)
	if not profile then
		return result
	end
	for plantId, growing in profile.data.plants do
		if growing.mutation == "None" then
			table.insert(result, plantId)
		end
	end
	return result
end

-- Whale Pass: every growing coral counts as planted `seconds` earlier, so it grows faster.
-- Shifting the saved planting time keeps growth a plain timestamp, offline included.
function Plots.boostGrowth(seconds: number)
	for player, models in coralModels do
		local profile = PlayerData.get(player)
		if profile then
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

function Plots.setMutation(player: Player, plantId: string, mutationId: string): boolean
	local profile = PlayerData.get(player)
	local plot = plotByPlayer[player]
	if not profile or not plot or not ReefConfig.MutationById[mutationId] then
		return false
	end
	local target = profile.data.plants[plantId]
	if not target then
		return false
	end
	target.mutation = mutationId
	setCoral(player, plot, plantId, target)
	return true
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
