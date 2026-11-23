--!nonstrict
-- Builds the Main Reef's scenery (layout in ReefConfig.MainReef): the stone road west from
-- the Ocean Gate, the entrance arch, coral trees along the road, coral bridges arching over
-- it, fish nurseries between the reefs, rocky ridges with small caves along the north and
-- south edges, and the Grand Reef Rock with a grotto at the far west end. The reefs
-- themselves are built by World.
-- Returns where shells and pearls may appear (Collectibles picks from these).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local CoralVisuals = require(ReplicatedStorage.Shared.CoralVisuals)
local WorldKit = require(script.Parent.WorldKit)

export type Spots = {
	shells: { Vector3 }, -- on open seabed
	pearls: { Vector3 }, -- in caves, the grotto and high up
}

local MainReef = {}

local LAYOUT = ReefConfig.MainReef
local C = WorldKit.Colors
local part, prop, disc, bar = WorldKit.part, WorldKit.prop, WorldKit.disc, WorldKit.bar
local seaGrass, boulder, tableCoral, tubeCoral = WorldKit.seaGrass, WorldKit.boulder, WorldKit.tableCoral, WorldKit.tubeCoral
local bigCoral, jellyLamp, surfaceLabel = WorldKit.bigCoral, WorldKit.jellyLamp, WorldKit.surfaceLabel

local ROAD_STONE = Color3.fromRGB(150, 160, 178)
-- Bright on purpose: the underwater tint turns mid-tone oranges into brown.
local BRIDGE_CORAL = Color3.fromRGB(255, 150, 128)
local TRUNK = Color3.fromRGB(255, 152, 72)
local CANOPY = { Color3.fromRGB(240, 110, 190), Color3.fromRGB(170, 96, 224), Color3.fromRGB(252, 168, 120) }
local CRYSTAL = { Color3.fromRGB(90, 230, 220), Color3.fromRGB(180, 120, 255), Color3.fromRGB(120, 200, 255) }

local function at(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

-- The road: a sand bed paved with uneven blue-grey flagstones.
local function buildRoad(parent: Instance, rng: Random)
	local from, to = at(LAYOUT.roadFrom, 0), at(LAYOUT.roadTo + 20, 0)
	WorldKit.path(parent, from, to, LAYOUT.roadWidth, rng)
	for x = LAYOUT.roadFrom - 3, LAYOUT.roadTo + 24, -5.5 do
		for _, z in { -3.2, 3.2 } do
			local size = Vector3.new(rng:NextNumber(4, 5), 0.35, rng:NextNumber(4.2, 5.4))
			prop({
				Name = "Flagstone",
				Size = size,
				CFrame = CFrame.new(x + rng:NextNumber(-0.6, 0.6), 0.32, z + rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0),
				Color = ROAD_STONE:Lerp(C.STONE, rng:NextNumber(0, 0.6)),
				Material = Enum.Material.Slate,
				Parent = parent,
			})
		end
	end
end

-- The way in: two coral pillars and a sign over the road.
local function buildEntrance(parent: Instance, rng: Random)
	local x = LAYOUT.entrance.X
	for _, z in { -11, 11 } do
		for k = 0, 3 do
			local size = 5.5 - k * 0.6
			part({ Name = "EntrancePillar", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Position = Vector3.new(x, 2 + k * 3.6, z), Color = BRIDGE_CORAL:Lerp(Color3.fromRGB(255, 200, 170), k * 0.12), Material = Enum.Material.Pebble, Parent = parent })
		end
		tubeCoral(parent, Vector3.new(x, 14.5, z), rng, Color3.fromRGB(150, 90, 220))
		jellyLamp(parent, Vector3.new(x + 4, 0, z * 1.4), C.GLOW, true)
	end
	local sign = part({ Name = "MainReefSign", Size = Vector3.new(0.6, 3.4, 22), CFrame = CFrame.new(x, 15.5, 0), Color = Color3.fromRGB(30, 70, 100), CanCollide = false, Parent = parent })
	surfaceLabel(sign, Enum.NormalId.Right, "THE MAIN REEF", Color3.fromRGB(255, 220, 120)) -- faces the lagoon (+X)
	surfaceLabel(sign, Enum.NormalId.Left, "STARTER LAGOON", Color3.fromRGB(180, 245, 255))
end

-- A coral tree from the concept art: an orange trunk that forks twice, with puffs of pink,
-- purple and peach coral at every branch tip.
local function coralTree(parent: Instance, base: Vector3, rng: Random)
	local function branch(from: CFrame, length: number, thick: number, depth: number)
		local tip = from * CFrame.new(0, length, 0)
		bar(parent, "TreeBranch", from.Position, tip.Position, thick, TRUNK:Lerp(Color3.fromRGB(230, 110, 70), rng:NextNumber(0, 0.4)), Enum.Material.SmoothPlastic)
		if depth == 0 then
			for k = 1, 2 do
				local size = rng:NextNumber(4, 6.5)
				prop({ Name = "TreeCanopy", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Position = tip.Position + Vector3.new(rng:NextNumber(-1.5, 1.5), k * 1.2, rng:NextNumber(-1.5, 1.5)), Color = CANOPY[rng:NextInteger(1, #CANOPY)], Material = Enum.Material.Pebble, Parent = parent })
			end
			return
		end
		for k = 1, 3 do
			local spin = (k / 3) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			branch(tip * CFrame.Angles(0, spin, 0) * CFrame.Angles(rng:NextNumber(0.45, 0.8), 0, 0), length * rng:NextNumber(0.6, 0.75), thick * 0.62, depth - 1)
		end
	end
	branch(CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(9, 12), 2.2, 2)
	tableCoral(parent, base + Vector3.new(3, 0, 2), rng)
end

-- A coral bridge arching over the road at `x`, solid so you can walk over the top, with
-- coral growing along it. Returns the point on top, where a pearl may sit.
local function buildBridge(parent: Instance, x: number, rng: Random): Vector3
	local span, rise, foot = 17, 12, 3
	local previous
	for i = 0, 12 do
		local a = math.pi * i / 12
		local point = Vector3.new(x, foot + math.sin(a) * rise, math.cos(a) * span)
		if previous then
			local length = (point - previous).Magnitude + 0.8
			part({
				Name = "BridgeArch",
				Size = Vector3.new(8, 3, length),
				CFrame = CFrame.lookAt((point + previous) / 2, point),
				Color = BRIDGE_CORAL:Lerp(Color3.fromRGB(255, 200, 170), rng:NextNumber(0, 0.35)),
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			})
		end
		previous = point
	end
	for _, z in { -span, span } do
		boulder(parent, Vector3.new(x, 0, z), 8, rng)
		tableCoral(parent, Vector3.new(x + rng:NextNumber(-3, 3), 0, z * 1.25), rng)
	end
	local top = Vector3.new(x, foot + rise + 1.5, 0)
	-- Coral on top, either side of the walkway down the middle.
	for _, z in { -7, -3.5, 3.5, 7 } do
		local a = math.acos(math.clamp(z / span, -1, 1))
		local spot = Vector3.new(x + (if z > 0 then 1.8 else -1.8), foot + math.sin(a) * rise + 1.1, z)
		if math.abs(z) > 5 then
			tubeCoral(parent, spot, rng, CANOPY[rng:NextInteger(1, #CANOPY)])
		else
			seaGrass(parent, spot, rng, 0.8)
		end
	end
	return top + Vector3.new(0, 1.5, 0)
end

-- A fish nursery: a ring of glowing anemones on a patch of pink sand. Wild fish gather here
-- (Fish), and anyone can catch them.
local function buildNursery(parent: Instance, spot: Vector3, rng: Random)
	disc(parent, "NurserySand", 8, 0.2, spot + Vector3.new(0, 0.1, 0), Color3.fromRGB(236, 190, 180), Enum.Material.Sand).CanCollide = false
	for i = 1, 7 do
		local angle = (i / 7) * math.pi * 2
		local anemone = CoralVisuals.build("anemone", "None", CFrame.new(spot + Vector3.new(math.cos(angle) * 5.5, 0.2, math.sin(angle) * 5.5)) * CFrame.Angles(0, angle, 0))
		anemone.Name = "NurseryAnemone"
		anemone:ScaleTo(rng:NextNumber(1.1, 1.6))
		for _, descendant in anemone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.Color = descendant.Color:Lerp(CANOPY[i % #CANOPY + 1], 0.5)
			end
		end
		anemone.Parent = parent
	end
	local glow = prop({ Name = "NurseryGlow", Size = Vector3.new(1, 1, 1), Position = spot + Vector3.new(0, 3, 0), Transparency = 1, Parent = parent })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 220)
	light.Range = 16
	light.Brightness = 1
	light.Parent = glow
	local post = part({ Name = "NurserySignPost", Size = Vector3.new(0.5, 4.5, 0.5), Position = spot + Vector3.new(0, 2.25, -9.5 * math.sign(spot.Z)), Color = Color3.fromRGB(110, 84, 62), Material = Enum.Material.Wood, Parent = parent })
	local board = part({ Name = "NurserySign", Size = Vector3.new(5, 1.5, 0.3), CFrame = CFrame.lookAt(post.Position + Vector3.new(0, 2.6, 0), Vector3.new(spot.X, post.Position.Y + 2.6, 0)), Color = Color3.fromRGB(40, 90, 120), CanCollide = false, Parent = parent })
	surfaceLabel(board, Enum.NormalId.Front, "Fish Nursery", Color3.fromRGB(255, 210, 230))
end

-- Glowing crystals and mushrooms for the caves.
local function cavernGlow(parent: Instance, frame: CFrame, rng: Random, count: number)
	for i = 1, count do
		local side = if i % 2 == 0 then 1 else -1
		local spot = frame * CFrame.new(side * rng:NextNumber(3, 4.2), 0, -rng:NextNumber(4, 22))
		local color = CRYSTAL[rng:NextInteger(1, #CRYSTAL)]
		for k = 1, 3 do
			local height = rng:NextNumber(1.5, 3.5)
			prop({ Name = "Crystal", Size = Vector3.new(0.7, height, 0.7), CFrame = spot * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi), rng:NextNumber(-0.5, 0.5)) * CFrame.new(0, height / 2, 0) + Vector3.new(k * 0.4, 0, 0), Color = color, Material = Enum.Material.Neon, Transparency = 0.15, Parent = parent })
		end
		if i % 3 == 0 then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 14
			light.Brightness = 1.2
			light.Parent = prop({ Name = "CrystalLight", Size = Vector3.new(0.5, 0.5, 0.5), Position = spot.Position + Vector3.new(0, 2, 0), Transparency = 1, Parent = parent })
		end
	end
end

-- A small cave you can walk into: rock walls, a rocky roof and a back wall, lit by crystals.
-- `frame` sits at the mouth on the seabed with -Z pointing in. Returns pearl spots inside.
local function buildCave(parent: Instance, frame: CFrame, depth: number, rng: Random): { Vector3 }
	local model = Instance.new("Model")
	model.Name = "Cave"
	model.Parent = parent
	local width, height = 12, 10
	for z = -2, -depth, -5 do
		for _, side in { -1, 1 } do
			part({ Name = "CaveWall", Size = Vector3.new(3.5, height + 2, 6), CFrame = frame * CFrame.new(side * (width / 2 + 1.5), (height + 2) / 2, z) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.08, 0.08)), Color = C.STONE:Lerp(Color3.fromRGB(60, 70, 96), rng:NextNumber(0.2, 0.6)), Material = Enum.Material.Slate, Parent = model })
		end
		part({ Name = "CaveRoof", Size = Vector3.new(width + 7, 3.5, 6), CFrame = frame * CFrame.new(0, height + 1.5, z) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)), Color = C.STONE:Lerp(Color3.fromRGB(60, 70, 96), rng:NextNumber(0.2, 0.6)), Material = Enum.Material.Slate, Parent = model })
	end
	part({ Name = "CaveBack", Size = Vector3.new(width + 6, height + 4, 4), CFrame = frame * CFrame.new(0, (height + 4) / 2, -depth - 3), Color = C.STONE:Lerp(Color3.fromRGB(60, 70, 96), 0.5), Material = Enum.Material.Slate, Parent = model })
	-- Rock heaped over and round it, so it reads as a hole in the ridge.
	for z = -4, -depth, -9 do
		for _, side in { -1, 1 } do
			boulder(model, (frame * CFrame.new(side * (width / 2 + 7), 0, z)).Position, rng:NextNumber(11, 15), rng)
		end
		boulder(model, (frame * CFrame.new(rng:NextNumber(-3, 3), height + 3, z)).Position, rng:NextNumber(10, 14), rng)
	end
	cavernGlow(model, frame, rng, 6)
	for _, side in { -1, 1 } do
		seaGrass(model, (frame * CFrame.new(side * (width / 2 + 2), 0, 2)).Position, rng, 1.6)
	end
	return {
		(frame * CFrame.new(-2, 1.5, -depth + 3)).Position,
		(frame * CFrame.new(2.5, 1.5, -depth * 0.55)).Position,
	}
end

-- A rocky ridge along one edge of the Main Reef, broken where the caves open into it.
local function buildRidge(parent: Instance, z: number, caveXs: { number }, rng: Random)
	local x = LAYOUT.roadFrom - 60
	while x > LAYOUT.roadTo - 30 do
		local nearCave = false
		for _, caveX in caveXs do
			if math.abs(x - caveX) < 16 then
				nearCave = true
			end
		end
		if not nearCave then
			local size = rng:NextNumber(14, 26)
			local spot = Vector3.new(x, 0, z + math.sign(z) * rng:NextNumber(0, 12))
			boulder(parent, spot, size, rng)
			-- Some stacks rise into pillars.
			if rng:NextNumber() < 0.35 then
				boulder(parent, spot + Vector3.new(rng:NextNumber(-3, 3), size * 0.55, rng:NextNumber(-3, 3)), size * 0.7, rng)
				if rng:NextNumber() < 0.5 then
					bigCoral(parent, spot + Vector3.new(0, size * 0.95, 0), rng, rng:NextNumber(1.5, 2.2))
				end
			end
			if rng:NextNumber() < 0.5 then
				seaGrass(parent, spot - Vector3.new(0, 0, math.sign(z) * size * 0.6), rng, rng:NextNumber(1.2, 2.2))
			end
		end
		x -= rng:NextNumber(14, 20)
	end
end

-- The Grand Reef Rock at the end of the road: a tall tower of rock with coral ledges all the
-- way up, bubbles streaming off it, and a grotto in its foot facing the road. Returns pearl
-- spots (in the grotto and on the highest ledge).
local function buildGrandRock(parent: Instance, rng: Random): { Vector3 }
	local model = Instance.new("Model")
	model.Name = "GrandReefRock"
	model.Parent = parent
	local base = LAYOUT.grandRock
	-- The grotto: a short cave into the rock, facing east up the road.
	local grotto = CFrame.lookAt(base + Vector3.new(26, 0, 0), base)
	local pearls = buildCave(model, grotto, 14, rng)
	-- The tower: rings of rock getting smaller as they rise, with coral plates on the ledges.
	local y = 0
	for level = 0, 5 do
		local radius = 22 - level * 3
		local count = 7 - math.floor(level / 2)
		for k = 1, count do
			local angle = (k / count) * math.pi * 2 + level * 0.5
			local spot = base + Vector3.new(math.cos(angle) * radius * 0.6, y, math.sin(angle) * radius * 0.6)
			-- Keep the grotto mouth on the east side clear at the bottom.
			if not (level == 0 and math.cos(angle) > 0.6) then
				boulder(model, spot, radius * rng:NextNumber(0.7, 0.9), rng)
			end
		end
		if level >= 1 then
			for k = 1, 3 do
				local angle = rng:NextNumber(0, math.pi * 2)
				local ledge = base + Vector3.new(math.cos(angle) * radius * 0.9, y + 2, math.sin(angle) * radius * 0.9)
				if k == 1 then
					tableCoral(model, ledge, rng, CANOPY[rng:NextInteger(1, #CANOPY)])
				elseif k == 2 then
					tubeCoral(model, ledge, rng)
				else
					bigCoral(model, ledge, rng, rng:NextNumber(1.4, 2))
				end
			end
		end
		y += 7
	end
	local summit = base + Vector3.new(0, y + 2, 0)
	local vent = prop({ Name = "SummitBubbles", Size = Vector3.new(6, 1, 6), Position = summit, Transparency = 1, Parent = model })
	WorldKit.bubbles(vent, 8, Enum.NormalId.Top)
	table.insert(pearls, summit + Vector3.new(0, 1, 0))
	return pearls
end

function MainReef.build(root: Instance, rng: Random): Spots
	local folder = Instance.new("Folder")
	folder.Name = "MainReef"
	folder.Parent = root
	local spots: Spots = { shells = {}, pearls = {} }

	buildRoad(folder, rng)
	buildEntrance(folder, rng)

	-- Coral trees along the road, between the reef gates and the bridges.
	local trees = Instance.new("Model")
	trees.Name = "CoralTrees"
	trees.Parent = folder
	for i, x in { -250, -370, -440, -520, -590, -670, -735 } do
		coralTree(trees, at(x, if i % 2 == 0 then 27 else -27), rng)
	end

	local bridges = Instance.new("Model")
	bridges.Name = "CoralBridges"
	bridges.Parent = folder
	for _, x in LAYOUT.bridges do
		table.insert(spots.pearls, buildBridge(bridges, x, rng))
	end

	local nurseries = Instance.new("Model")
	nurseries.Name = "FishNurseries"
	nurseries.Parent = folder
	for _, spot in LAYOUT.fishSpots do
		buildNursery(nurseries, spot, rng)
		table.insert(spots.shells, spot + Vector3.new(0, 1.2, -12 * math.sign(spot.Z)))
	end

	-- The ridges, and the caves opening into them.
	local ridges = Instance.new("Model")
	ridges.Name = "RockRidges"
	ridges.Parent = folder
	local northCaves, southCaves = {}, {}
	for _, cave in LAYOUT.caves do
		local frame = CFrame.lookAt(cave.mouth, cave.mouth + cave.into)
		for _, pearl in buildCave(ridges, frame, 24, rng) do
			table.insert(spots.pearls, pearl)
		end
		table.insert(spots.shells, cave.mouth + Vector3.new(0, 1.2, 0) - cave.into * 6)
		table.insert(if cave.mouth.Z < 0 then northCaves else southCaves, cave.mouth.X)
	end
	buildRidge(ridges, -LAYOUT.ridgeZ, northCaves, rng)
	buildRidge(ridges, LAYOUT.ridgeZ, southCaves, rng)

	for _, pearl in buildGrandRock(folder, rng) do
		table.insert(spots.pearls, pearl)
	end

	-- Coral gardens over the open seabed between everything else, with a shell spot in each.
	local gardens = Instance.new("Model")
	gardens.Name = "CoralGardens"
	gardens.Parent = folder
	local placed = 0
	for _ = 1, 400 do
		if placed >= 34 then
			break
		end
		local spot = at(rng:NextNumber(LAYOUT.roadTo + 40, LAYOUT.roadFrom - 50), rng:NextNumber(-LAYOUT.ridgeZ + 22, LAYOUT.ridgeZ - 22))
		local clear = math.abs(spot.Z) > LAYOUT.roadWidth / 2 + 6
			and not ReefConfig.nearPlot(spot.X, spot.Z, 8)
			and (spot - LAYOUT.grandRock).Magnitude > 50
		for _, x in LAYOUT.bridges do
			clear = clear and not (math.abs(spot.X - x) < 14 and math.abs(spot.Z) < 28)
		end
		for _, nursery in LAYOUT.fishSpots do
			clear = clear and (spot - nursery).Magnitude > 14
		end
		if clear then
			placed += 1
			local pick = placed % 4
			if pick == 0 then
				tableCoral(gardens, spot, rng, CANOPY[rng:NextInteger(1, #CANOPY)])
			elseif pick == 1 then
				tubeCoral(gardens, spot, rng, if rng:NextNumber() < 0.5 then C.TUBE_BLUE else Color3.fromRGB(70, 200, 180))
			else
				bigCoral(gardens, spot, rng, rng:NextNumber(1.6, 2.6))
			end
			for _ = 1, 2 do
				seaGrass(gardens, spot + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), rng, rng:NextNumber(1, 1.6))
			end
			if placed % 2 == 0 then
				boulder(gardens, spot + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), rng:NextNumber(3, 6), rng)
			end
			table.insert(spots.shells, spot + Vector3.new(rng:NextNumber(-7, 7), 1.2, rng:NextNumber(-7, 7)))
		end
	end
	-- And along the road verges.
	for x = LAYOUT.roadFrom - 30, LAYOUT.roadTo + 40, -45 do
		table.insert(spots.shells, at(x + rng:NextNumber(-8, 8), (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(10, 16)) + Vector3.new(0, 1.2, 0))
	end
	return spots
end

return MainReef
