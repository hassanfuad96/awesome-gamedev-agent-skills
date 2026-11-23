--!nonstrict
-- Builds the seabed, stands, leaderboard board and the empty plots at server start.
-- Everything lives under Workspace.Reef so it is easy to find in Explorer during play;
-- once you like the layout you can copy it out of a running session and save it into
-- the place, then delete this module's calls.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)

export type PlotParts = {
	index: number,
	model: Model,
	center: Vector3,
	sign: TextLabel,
	tiles: { BasePart },
	spawn: CFrame,
}

export type WorldParts = {
	plots: { PlotParts },
	shopStand: BasePart,
	sellStand: BasePart,
	boardList: Frame,
	currentStream: ParticleEmitter,
}

local World = {}

local SAND = Color3.fromRGB(214, 196, 150)
local ROCK = Color3.fromRGB(96, 104, 112)
local PLOT_SPACING = 50
local PLOT_ROW_Z = 45

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function surfaceLabel(target: BasePart, face: Enum.NormalId, text: string, color: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
	return label
end

local function setupLighting()
	Lighting.Ambient = Color3.fromRGB(40, 80, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 120, 160)
	Lighting.FogColor = Color3.fromRGB(18, 72, 112)
	Lighting.FogStart = 40
	Lighting.FogEnd = 320
	Lighting.ClockTime = 13
	Lighting.Brightness = 1.6
	Lighting.GlobalShadows = true

	-- Atmosphere would override the fog settings above, so remove a default one.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere:Destroy()
	end

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "UnderwaterTint"
	tint.TintColor = Color3.fromRGB(190, 230, 255)
	tint.Saturation = 0.15
	tint.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "CoralGlow"
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.2
	bloom.Parent = Lighting
end

local function bubbleVent(parent: Instance, position: Vector3)
	local vent = part({
		Name = "BubbleVent",
		Size = Vector3.new(3, 1, 3),
		Position = position,
		Color = ROCK,
		Material = Enum.Material.Basalt,
		CanCollide = false,
		Parent = parent,
	})
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	bubbles.Size = NumberSequence.new(0.4, 0.9)
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.Lifetime = NumberRange.new(4, 7)
	bubbles.Rate = 6
	bubbles.Speed = NumberRange.new(4, 7)
	bubbles.SpreadAngle = Vector2.new(12, 12)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Parent = vent
end

local function stand(parent: Instance, name: string, position: Vector3, color: Color3, title: string, kind: string, action: string): BasePart
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local counter = part({
		Name = "Counter",
		Size = Vector3.new(14, 4, 5),
		Position = position + Vector3.new(0, 2, 0),
		Color = Color3.fromRGB(150, 110, 80),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	for _, x in { -6, 6 } do
		part({
			Name = "Post",
			Size = Vector3.new(1, 10, 1),
			Position = position + Vector3.new(x, 5, -2),
			Color = Color3.fromRGB(120, 90, 60),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	part({
		Name = "Roof",
		Size = Vector3.new(16, 1, 8),
		Position = position + Vector3.new(0, 10.5, -1),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(14, 3, 0.5),
		Position = position + Vector3.new(0, 12.5, -1),
		Color = color,
		Parent = model,
	})
	surfaceLabel(sign, Enum.NormalId.Back, title, Color3.new(1, 1, 1))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StandPrompt"
	prompt.ActionText = action
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", kind)
	prompt.Parent = counter

	model.PrimaryPart = counter
	return counter
end

local function buildPlot(parent: Instance, index: number): PlotParts
	local center = Vector3.new(-((ReefConfig.PLOT_COUNT - 1) * PLOT_SPACING) / 2 + (index - 1) * PLOT_SPACING, 0, PLOT_ROW_Z)
	local size = ReefConfig.TILE_SIZE
	local width = ReefConfig.TILE_COLUMNS * size + 4
	local depth = ReefConfig.TILE_ROWS * size + 4

	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model:SetAttribute("PlotIndex", index)
	model.Parent = parent

	part({
		Name = "Base",
		Size = Vector3.new(width, 1, depth),
		Position = center + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(196, 172, 128),
		Material = Enum.Material.Sand,
		Parent = model,
	})

	local signPart = part({
		Name = "Sign",
		Size = Vector3.new(16, 4, 0.5),
		Position = center + Vector3.new(0, 4, -depth / 2 - 1),
		Color = Color3.fromRGB(40, 90, 120),
		Parent = model,
	})
	local sign = surfaceLabel(signPart, Enum.NormalId.Front, "Empty reef", Color3.fromRGB(200, 240, 255))

	local tiles: { BasePart } = {}
	for row = 1, ReefConfig.TILE_ROWS do
		for column = 1, ReefConfig.TILE_COLUMNS do
			local tileIndex = (row - 1) * ReefConfig.TILE_COLUMNS + column
			local offset = Vector3.new(
				(column - (ReefConfig.TILE_COLUMNS + 1) / 2) * size,
				1.2,
				(row - (ReefConfig.TILE_ROWS + 1) / 2) * size
			)
			local tile = part({
				Name = "Tile_" .. tileIndex,
				Size = Vector3.new(size - 1, 0.4, size - 1),
				Position = center + offset,
				-- Ground renders almost black under the underwater lighting; Slate stays brown.
				Color = Color3.fromRGB(140, 100, 66),
				Material = Enum.Material.Slate,
				Parent = model,
			})
			tile:SetAttribute("TileIndex", tileIndex)
			local click = Instance.new("ClickDetector")
			click.MaxActivationDistance = 40
			click.Parent = tile
			tiles[tileIndex] = tile
		end
	end

	local spawnPosition = center + Vector3.new(0, 3, -depth / 2 - 6)
	return {
		index = index,
		model = model,
		center = center,
		sign = sign,
		tiles = tiles,
		spawn = CFrame.lookAt(spawnPosition, center + Vector3.new(0, 3, 0)),
	}
end

local function buildBoard(parent: Instance): Frame
	local board = part({
		Name = "TopReefsBoard",
		Size = Vector3.new(20, 14, 1),
		Position = Vector3.new(0, 9, -42),
		Color = Color3.fromRGB(30, 60, 90),
		Parent = parent,
	})
	part({
		Name = "BoardPost",
		Size = Vector3.new(1.5, 4, 1.5),
		Position = Vector3.new(0, 1, -42),
		Color = ROCK,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.15)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.Text = "Top Reefs (shells earned)"
	title.Parent = gui

	local list = Instance.new("Frame")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.05, 0.17)
	list.Size = UDim2.fromScale(0.9, 0.8)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

function World.build(): WorldParts
	setupLighting()

	local root = Instance.new("Folder")
	root.Name = "Reef"
	root.Parent = Workspace

	-- Seabed and a few rocks for shape.
	part({
		Name = "Seabed",
		Size = Vector3.new(440, 4, 280),
		Position = Vector3.new(0, -2, 20),
		Color = SAND,
		Material = Enum.Material.Sand,
		Parent = root,
	})
	local rng = Random.new(42)
	for i = 1, 40 do
		local x = rng:NextNumber(-210, 210)
		local z = rng:NextNumber(-110, 150)
		-- Keep the play area (stands and plots) clear.
		if math.abs(z - PLOT_ROW_Z) > 22 and not (math.abs(x) < 60 and z > -60 and z < 10) then
			local s = rng:NextNumber(3, 10)
			local rock = part({
				Name = "Rock",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(s, s * 0.7, s),
				Position = Vector3.new(x, s * 0.2, z),
				Color = ROCK:Lerp(SAND, rng:NextNumber(0, 0.3)),
				Material = Enum.Material.Rock,
				Parent = root,
			})
			if i % 5 == 0 then
				bubbleVent(root, rock.Position + Vector3.new(0, s * 0.4, 0))
			end
		end
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(10, 1, 10)
	spawnLocation.Position = Vector3.new(0, 0.5, -10)
	spawnLocation.Color = Color3.fromRGB(80, 170, 200)
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = root

	local shopStand = stand(root, "SeedShop", Vector3.new(-26, 0, -22), Color3.fromRGB(70, 170, 110), "Seed Shop", "SeedShop", "Browse seeds")
	local sellStand = stand(root, "SellStand", Vector3.new(26, 0, -22), Color3.fromRGB(220, 140, 60), "Sell Coral", "Sell", "Sell all coral")
	local boardList = buildBoard(root)

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = root
	local plots: { PlotParts } = {}
	for index = 1, ReefConfig.PLOT_COUNT do
		plots[index] = buildPlot(plotsFolder, index)
	end

	-- A wide band of drifting particles over the plots, switched on during currents.
	local span = ReefConfig.PLOT_COUNT * PLOT_SPACING
	local streamPart = part({
		Name = "CurrentStream",
		Size = Vector3.new(4, 10, 36),
		Position = Vector3.new(-span / 2 - 10, 6, PLOT_ROW_Z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = root,
	})
	local stream = Instance.new("ParticleEmitter")
	stream.Name = "Current"
	stream.Enabled = false
	stream.EmissionDirection = Enum.NormalId.Right
	stream.Speed = NumberRange.new(40, 55)
	stream.Lifetime = NumberRange.new(span / 45, span / 40)
	stream.Rate = 60
	stream.Size = NumberSequence.new(0.5, 1.2)
	stream.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.4),
		NumberSequenceKeypoint.new(0.9, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	stream.Color = ColorSequence.new(Color3.fromRGB(150, 230, 255))
	stream.LightEmission = 0.6
	stream.SpreadAngle = Vector2.new(5, 5)
	stream.Parent = streamPart

	return {
		plots = plots,
		shopStand = shopStand,
		sellStand = sellStand,
		boardList = boardList,
		currentStream = stream,
	}
end

return World
