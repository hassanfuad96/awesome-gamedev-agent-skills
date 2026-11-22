--!nonstrict
-- Plot ownership, planting, growth and harvesting. Tiles and coral are clicked through
-- ClickDetectors, whose MouseClick event fires on the server with the real player, so
-- the client never tells the server which tile it owns or what it planted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local World = require(script.Parent.World)
local PlayerData = require(script.Parent.PlayerData)
local CoralVisuals = require(script.Parent.CoralVisuals)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

type PlotParts = World.PlotParts
type Profile = PlayerData.Profile

export type ReadyCoral = { tileIndex: number, seed: string, mutation: string, position: Vector3 }

local Plots = {}

local plots: { PlotParts } = {}
local ownerByPlot: { [number]: Player } = {}
local plotByPlayer: { [Player]: PlotParts } = {}
local coralModels: { [Player]: { [number]: Model } } = {}
local spawnConnections: { [Player]: RBXScriptConnection } = {}
local rng = Random.new()

local MIN_SCALE = 0.25
local EMPTY_COLOR = Color3.fromRGB(120, 96, 70)
local LOCKED_COLOR = Color3.fromRGB(60, 56, 52)

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

local function growthOf(tile: PlayerData.Tile): number
	local seed = ReefConfig.Seeds[tile.seed]
	if not seed then
		return 1
	end
	return math.clamp((os.time() - tile.plantedAt) / seed.growSeconds, 0, 1)
end

local function tileBase(tilePart: BasePart): CFrame
	return tilePart.CFrame * CFrame.new(0, tilePart.Size.Y / 2, 0)
end

local handleTileClick: (Player, PlotParts, number) -> ()

local function setCoral(player: Player, plot: PlotParts, tileIndex: number, tile: PlayerData.Tile?)
	local models = coralModels[player]
	if not models then
		return
	end
	local existing = models[tileIndex]
	if existing then
		existing:Destroy()
		models[tileIndex] = nil
	end

	local tilePart = plot.tiles[tileIndex]
	if tile then
		local model = CoralVisuals.build(tile.seed, tile.mutation, tileBase(tilePart))
		model:ScaleTo(MIN_SCALE + (1 - MIN_SCALE) * growthOf(tile))
		-- Coral covers the tile, so it needs its own click target.
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 40
		click.Parent = model
		click.MouseClick:Connect(function(clicker)
			handleTileClick(clicker, plot, tileIndex)
		end)
		model.Parent = plot.model
		models[tileIndex] = model

		local seed = ReefConfig.Seeds[tile.seed]
		tilePart:SetAttribute("Seed", tile.seed)
		tilePart:SetAttribute("Mutation", tile.mutation)
		tilePart:SetAttribute("ReadyAt", tile.plantedAt + (if seed then seed.growSeconds else 0))
	else
		tilePart:SetAttribute("Seed", nil)
		tilePart:SetAttribute("Mutation", nil)
		tilePart:SetAttribute("ReadyAt", nil)
	end
end

local function paintTile(plot: PlotParts, tileIndex: number, unlocked: boolean)
	local tilePart = plot.tiles[tileIndex]
	tilePart.Color = if unlocked then EMPTY_COLOR else LOCKED_COLOR
	tilePart.Transparency = if unlocked then 0 else 0.4
	tilePart:SetAttribute("Locked", not unlocked)
end

local function renderPlot(player: Player, profile: Profile)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	for tileIndex = 1, ReefConfig.TILE_COUNT do
		paintTile(plot, tileIndex, tileIndex <= profile.data.unlocked)
		setCoral(player, plot, tileIndex, profile.data.tiles[tostring(tileIndex)])
	end
end

local function plant(player: Player, profile: Profile, plot: PlotParts, tileIndex: number)
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

	local mutation = EconomyMath.pickWeighted(ReefConfig.Mutations, rng:NextNumber())
	local tile = { seed = seedId, plantedAt = os.time(), mutation = mutation }
	profile.data.tiles[tostring(tileIndex)] = tile
	setCoral(player, plot, tileIndex, tile)
	if mutation ~= "None" then
		notify(player, `Lucky! A {displayName(seedId, mutation)} sprouted!`, "rare")
	end
	PlayerData.sync(player)
end

local function harvest(player: Player, profile: Profile, plot: PlotParts, tileIndex: number, tile: PlayerData.Tile)
	profile.data.tiles[tostring(tileIndex)] = nil
	local key = ReefConfig.inventoryKey(tile.seed, tile.mutation)
	profile.data.inventory[key] = (profile.data.inventory[key] or 0) + 1
	profile.data.harvested += 1
	setCoral(player, plot, tileIndex, nil)
	local value = ReefConfig.harvestValue(tile.seed, tile.mutation)
	notify(player, `+1 {displayName(tile.seed, tile.mutation)} (sells for {EconomyMath.formatNumber(value)} shells)`, "good")
	PlayerData.sync(player)
end

handleTileClick = function(player: Player, plot: PlotParts, tileIndex: number)
	if ownerByPlot[plot.index] ~= player then
		local owner = ownerByPlot[plot.index]
		notify(player, if owner then `That's {owner.DisplayName}'s reef.` else "Nobody owns this reef.")
		return
	end
	if not RateLimit.consume(player) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if tileIndex > profile.data.unlocked then
		notify(player, "Locked tile. Expand your reef at the Seed Shop.")
		return
	end

	local tile = profile.data.tiles[tostring(tileIndex)]
	if not tile then
		plant(player, profile, plot, tileIndex)
	elseif growthOf(tile) >= 1 then
		harvest(player, profile, plot, tileIndex, tile)
	else
		local seed = ReefConfig.Seeds[tile.seed]
		local left = tile.plantedAt + seed.growSeconds - os.time()
		notify(player, `{displayName(tile.seed, tile.mutation)}: {left}s until it's ready.`)
	end
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
	for tileIndex = 1, ReefConfig.TILE_COUNT do
		setCoral(player, plot, tileIndex, nil)
		paintTile(plot, tileIndex, tileIndex <= ReefConfig.STARTING_TILES)
	end
	plot.sign.Text = "Empty reef"
	plot.model:SetAttribute("OwnerUserId", nil)
	ownerByPlot[plot.index] = nil
	plotByPlayer[player] = nil
	coralModels[player] = nil
end

function Plots.refresh(player: Player)
	local profile = PlayerData.get(player)
	if profile then
		renderPlot(player, profile)
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
	for key, tile in profile.data.tiles do
		local tileIndex = tonumber(key)
		if tileIndex and growthOf(tile) >= 1 then
			table.insert(result, {
				tileIndex = tileIndex,
				seed = tile.seed,
				mutation = tile.mutation,
				position = plot.tiles[tileIndex].Position,
			})
		end
	end
	return result
end

-- Planted coral without a mutation, grown or not (currents can mutate these).
function Plots.unmutatedTiles(player: Player): { number }
	local result: { number } = {}
	local profile = PlayerData.get(player)
	if not profile then
		return result
	end
	for key, tile in profile.data.tiles do
		local tileIndex = tonumber(key)
		if tileIndex and tile.mutation == "None" then
			table.insert(result, tileIndex)
		end
	end
	return result
end

function Plots.setMutation(player: Player, tileIndex: number, mutationId: string): boolean
	local profile = PlayerData.get(player)
	local plot = plotByPlayer[player]
	if not profile or not plot or not ReefConfig.MutationById[mutationId] then
		return false
	end
	local tile = profile.data.tiles[tostring(tileIndex)]
	if not tile then
		return false
	end
	tile.mutation = mutationId
	setCoral(player, plot, tileIndex, tile)
	return true
end

function Plots.start(worldParts: World.WorldParts)
	plots = worldParts.plots
	for _, plot in plots do
		for tileIndex, tilePart in plot.tiles do
			local click = tilePart:FindFirstChildOfClass("ClickDetector")
			if click then
				click.MouseClick:Connect(function(player)
					handleTileClick(player, plot, tileIndex)
				end)
			end
		end
	end

	PlayerData.onLoaded(Plots.assign)
	Players.PlayerRemoving:Connect(Plots.release)

	-- Grow coral visibly. Growth itself is just a timestamp, so it continues while offline.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, models in coralModels do
				local profile = PlayerData.get(player)
				if profile then
					for tileIndex, model in models do
						local tile = profile.data.tiles[tostring(tileIndex)]
						if tile and model.Parent then
							local target = MIN_SCALE + (1 - MIN_SCALE) * growthOf(tile)
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
