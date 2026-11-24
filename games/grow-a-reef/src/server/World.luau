--!nonstrict
-- Builds the Starter Lagoon at server start (layout in ReefConfig.Lagoon; north is -Z):
--   centre  the plaza, with the spawn on a glowing dais and Kai the guide (one of the Crew)
--   round   the hub's four buildings in glass domes, joined to the plaza by glass corridors
--           (Hub builds them): the Research Laboratory (north-west, the biggest), the
--           Aquarium (north-east), the Coral Market (south-east), the Equipment Station
--           (south-west)
--   roads   north to the Kelp Forest (KelpWorld), west through the Ocean Gate to the Main
--           Reef, east to the Sunken Ruins, south past the leaderboards to the Abyss
-- and, through the Ocean Gate, the Main Reef (MainReef builds its scenery): the six reefs,
-- three either side of a stone road, each a bed of sand planters inside a fence.
-- Everything lives under Workspace.Reef so it is easy to find in Explorer during play;
-- once you like the layout you can copy it out of a running session and save it into
-- the place, then delete this module's calls.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local KelpConfig = require(ReplicatedStorage.Shared.KelpConfig)
local CoralVisuals = require(ReplicatedStorage.Shared.CoralVisuals)
local FenceVisuals = require(ReplicatedStorage.Shared.FenceVisuals)
local SeabedDecor = require(script.Parent.SeabedDecor)
local ShopkeeperVisuals = require(script.Parent.ShopkeeperVisuals)
local WorldKit = require(script.Parent.WorldKit)
local MainReef = require(script.Parent.MainReef)
local KelpWorld = require(script.Parent.KelpWorld)
local Hub = require(script.Parent.Hub)

export type PlotParts = {
	index: number,
	model: Model,
	frame: CFrame, -- centre on the seabed, gate at local -Z; saved coral offsets use this frame
	center: Vector3,
	radius: number, -- the whole mound; points within it belong to this plot
	bed: BasePart, -- the round bed the planters stand on (a cylinder lying flat)
	bedTop: number, -- world Y of the bed's top surface
	planters: { Planter }, -- by slot (ReefConfig.Planters); Plots paints them
	planterTop: number, -- world Y of a planter's sand top, where coral stands
	sign: TextLabel,
	likes: TextLabel, -- under the name on the sign
	signPart: BasePart, -- holds the "Like this reef" prompt
	spawn: CFrame,
	fence: Model, -- swapped when the owner picks another style
	fenceFrame: CFrame,
	fenceRadius: number,
}

export type Planter = {
	top: BasePart, -- the sand (or, while locked, rock) top; clients tap it to plant
	glow: BasePart, -- the glowing rim round an empty unlocked planter
}

export type WorldParts = {
	plots: { PlotParts },
	shopStand: BasePart, -- the Coral Market's seed counter
	labStand: BasePart, -- the Research Laboratory's counter (species, planters, coral growth)
	marketDecorStand: BasePart, -- the Coral Market's decorations and fences counter
	sellStand: BasePart, -- the Coral Market's sell counter
	hatcheryStand: BasePart, -- the hatchery counter inside the Research Station
	suppliesStand: BasePart, -- the Equipment Station counter (diving gear)
	shopsPad: BasePart, -- the teleport pad's pool beside the Coral Market
	boardList: Frame, -- Top Reefs, by shells earned
	likesBoardList: Frame, -- Best Reefs, by likes
	currentStreams: { ParticleEmitter }, -- one from each reef to the next, round the ring
	surface: BasePart,
	lightShafts: { BasePart },
	collectibleSpots: MainReef.Spots, -- where shells and pearls may appear
	kelp: KelpWorld.KelpParts, -- the Kelp Forest's meadow patches and turtle nests
}

local World = {}

local LAGOON = ReefConfig.Lagoon
local CENTER = LAGOON.center
local C = WorldKit.Colors
local SAND, PATH_SAND, PLAZA_STONE, PLAZA_INLAY = C.SAND, C.PATH_SAND, C.PLAZA_STONE, C.PLAZA_INLAY
local REEF_SAND, BED_SOIL, ROCK, STONE, GLOW = C.REEF_SAND, C.BED_SOIL, C.ROCK, C.STONE, C.GLOW
local METAL_DARK, HULL_WHITE, CORAL_PINK, TUBE_BLUE = C.METAL_DARK, C.HULL_WHITE, C.CORAL_PINK, C.TUBE_BLUE
-- How far the mound (with its lumpy rim) reaches from a plot's centre.
local MOUND_REACH = ReefConfig.moundRadius() + 4
-- Rocks, light shafts and decoration spread over the sea life's roaming area.
local AREA = ReefConfig.SeaLife.area
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X

local part, prop, disc, bar, facing = WorldKit.part, WorldKit.prop, WorldKit.disc, WorldKit.bar, WorldKit.facing
local seaGrass, boulder, tableCoral, tubeCoral = WorldKit.seaGrass, WorldKit.boulder, WorldKit.tableCoral, WorldKit.tubeCoral
local bigCoral, jellyLamp, surfaceLabel, prompt = WorldKit.bigCoral, WorldKit.jellyLamp, WorldKit.surfaceLabel, WorldKit.prompt

local function setupLighting()
	Lighting.Ambient = Color3.fromRGB(80, 125, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(115, 160, 185)
	Lighting.ClockTime = 13
	Lighting.Brightness = 2.1
	Lighting.GlobalShadows = true

	-- Clear, sunlit water: a light blue Atmosphere hides the sky and fades only the far
	-- distance into blue, so neighbouring reefs stay visible but the seabed has no visible
	-- edge. (Atmosphere replaces Lighting's fog settings.)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.36
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(95, 190, 220)
	atmosphere.Decay = Color3.fromRGB(45, 125, 175)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.3
	atmosphere.Parent = Lighting

	-- No sun, moon or stars overhead; the water surface (buildSurface) takes their place.
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
	sky.Parent = Lighting
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Enabled = false
	end

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "UnderwaterTint"
	tint.TintColor = Color3.fromRGB(195, 232, 255)
	tint.Contrast = 0.1
	tint.Saturation = 0.2
	tint.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "CoralGlow"
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.2
	bloom.Parent = Lighting
end

-- The water surface far overhead, glowing, with soft shafts of light coming down from it.
local function buildSurface(parent: Instance, rng: Random): (BasePart, { BasePart })
	local surface = prop({
		Name = "WaterSurface",
		Size = Vector3.new(1700, 2, 1000),
		Position = Vector3.new(-130, 110, 0), -- over the Main Reef, the lagoon and the Ruins
		Color = Color3.fromRGB(120, 210, 235),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CastShadow = false, -- it would shade the whole map
		Parent = parent,
	})
	local shafts = {}
	for i = 1, 26 do
		local width = rng:NextNumber(5, 12)
		-- A few always fall on the plaza, so the spawn feels sunlit.
		local x, z
		if i <= 4 then
			x, z = rng:NextNumber(-30, 30), rng:NextNumber(-30, 30)
		else
			x, z = rng:NextNumber(AREA.minX, AREA.maxX), rng:NextNumber(AREA.minZ, AREA.maxZ)
		end
		table.insert(shafts, prop({
			Name = "LightShaft",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(120, width, width),
			CFrame = CFrame.new(x, 50, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(90) + rng:NextNumber(-0.25, 0.25)),
			Color = Color3.fromRGB(190, 235, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.94,
			CastShadow = false,
			Parent = parent,
		}))
	end
	return surface, shafts
end

local bubbles, bubbleVent, teleportPad = WorldKit.bubbles, WorldKit.bubbleVent, WorldKit.teleportPad

-- A market stand: counter, posts, roof and a sign. `frame` is the stand's spot on the
-- seabed with its +Z (the customers' side) facing the players. Returns the counter, which
-- holds the prompt.
local function stand(parent: Instance, name: string, frame: CFrame, color: Color3, title: string, kind: string, action: string): BasePart
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local counter = part({ Name = "Counter", Size = Vector3.new(14, 4, 5), CFrame = frame * CFrame.new(0, 2, 0), Color = Color3.fromRGB(150, 110, 80), Material = Enum.Material.Wood, Parent = model })
	for _, x in { -6, 6 } do
		part({ Name = "Post", Size = Vector3.new(1, 10, 1), CFrame = frame * CFrame.new(x, 5, -2), Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.Wood, Parent = model })
	end
	part({ Name = "Roof", Size = Vector3.new(16, 1, 8), CFrame = frame * CFrame.new(0, 10.5, -1), Color = color, Material = Enum.Material.SmoothPlastic, Parent = model })
	local sign = part({ Name = "Sign", Size = Vector3.new(14, 3, 0.5), CFrame = frame * CFrame.new(0, 12.5, -1), Color = color, Parent = model })
	surfaceLabel(sign, Enum.NormalId.Back, title, Color3.new(1, 1, 1))
	prompt(counter, kind, action, title, 12).Name = "StandPrompt"

	model.PrimaryPart = counter
	return counter
end

-- The plaza: a round sandstone floor with a coral-pink ring and a glowing inlay, the spawn
-- dais in the middle, jellyfish lamps round the edge and coral planters between the paths.
local function buildPlaza(root: Instance, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Plaza"
	model.Parent = root
	local r = LAGOON.plazaRadius
	disc(model, "PlazaRim", r + 1.5, 0.5, CENTER + Vector3.new(0, 0.25, 0), Color3.fromRGB(176, 166, 146), Enum.Material.Slate)
	disc(model, "PlazaFloor", r, 0.6, CENTER + Vector3.new(0, 0.3, 0), PLAZA_STONE, Enum.Material.Sandstone)
	disc(model, "GlowRing", 27, 0.64, CENTER + Vector3.new(0, 0.32, 0), GLOW, Enum.Material.Neon)
	disc(model, "CoralRing", 26, 0.68, CENTER + Vector3.new(0, 0.34, 0), PLAZA_INLAY, Enum.Material.Pebble)
	disc(model, "InnerFloor", 20, 0.7, CENTER + Vector3.new(0, 0.35, 0), PLAZA_STONE, Enum.Material.Sandstone)
	-- Compass spokes in the outer ring, pointing at the four sides.
	for i = 0, 3 do
		local angle = i * math.pi / 2
		local direction = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local a, b = CENTER + direction * 27.5, CENTER + direction * (r - 1)
		part({ Name = "Spoke", Size = Vector3.new(2, 0.66, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.33, 0), b + Vector3.new(0, 0.33, 0)), Color = PLAZA_INLAY, Material = Enum.Material.Pebble, Parent = model })
	end

	-- The spawn dais: a raised round stone with a glowing pool on top.
	disc(model, "DaisGlow", 7.6, 1, CENTER + Vector3.new(0, 0.5, 0), GLOW, Enum.Material.Neon)
	disc(model, "Dais", 7.2, 1.2, CENTER + Vector3.new(0, 0.6, 0), Color3.fromRGB(236, 196, 176), Enum.Material.Marble)
	local pool = disc(model, "DaisPool", 4.8, 1.24, CENTER + Vector3.new(0, 0.62, 0), Color3.fromRGB(150, 235, 245), Enum.Material.Neon)
	pool.Transparency = 0.35
	bubbles(pool, 4, Enum.NormalId.Right)

	-- Lamps round the edge, between the paths; planters full of coral and grass.
	for i = 0, 11 do
		if i % 3 == 1 then
			continue -- 45, 135, 225, 315 degrees: the glass corridors to the buildings
		end
		local angle = math.rad(15 + i * 30)
		jellyLamp(model, CENTER + Vector3.new(math.sin(angle), 0, -math.cos(angle)) * (r - 3) + Vector3.new(0, 0.6, 0), if i % 2 == 0 then GLOW else Color3.fromRGB(255, 140, 220), false)
	end
	for _, bearing in { 150, 210 } do
		local angle = math.rad(bearing)
		local at = CENTER + Vector3.new(math.sin(angle), 0, -math.cos(angle)) * 33
		disc(model, "Planter", 5, 1.4, at + Vector3.new(0, 0.7, 0), Color3.fromRGB(176, 166, 146), Enum.Material.Slate)
		disc(model, "PlanterSand", 4.3, 1.5, at + Vector3.new(0, 0.75, 0), REEF_SAND, Enum.Material.Sand)
		bigCoral(model, at + Vector3.new(0, 1.5, 0), rng, 1.6)
		tubeCoral(model, at + Vector3.new(2, 1.5, 1), rng, if bearing == 150 then TUBE_BLUE else Color3.fromRGB(150, 90, 220))
		seaGrass(model, at + Vector3.new(-2.2, 1.5, -1), rng)
	end
end

-- The guide rock beside the spawn (its prompt talks to Kai the guide, a Crew NPC who stands
-- by it) and a "Start here" sign.
local function buildGuide(root: Instance): Vector3
	local at = LAGOON.guide
	local model = Instance.new("Model")
	model.Name = "Guide"
	model.Parent = root
	local seat = disc(model, "GuideRock", 2.8, 1.6, at + Vector3.new(0, 0.8, 0), STONE, Enum.Material.Slate)
	prompt(seat, "Guide", "Talk", "Kai the Guide", 12)
	local base = CFrame.lookAt(at + Vector3.new(0, 1.6, 0), Vector3.new(CENTER.X, 1.6, CENTER.Z))
	ShopkeeperVisuals.build("Guide", base).Parent = model

	local signAt = base * CFrame.new(4.2, 0, 0.8)
	part({ Name = "SignPost", Size = Vector3.new(0.5, 5, 0.5), CFrame = signAt * CFrame.new(0, 1, 0), Color = Color3.fromRGB(110, 84, 62), Material = Enum.Material.Wood, Parent = model })
	local board = part({ Name = "StartSign", Size = Vector3.new(4.6, 1.8, 0.3), CFrame = signAt * CFrame.new(0, 3.2, 0), Color = Color3.fromRGB(40, 90, 120), CanCollide = false, Parent = model })
	surfaceLabel(board, Enum.NormalId.Front, "START HERE!", Color3.fromRGB(255, 220, 120))
	return at
end

-- The Ocean Gate on the west side: a huge arch of tumbled blue-grey rock, coral and kelp
-- growing on it, a plaque, and a slow current of bubbles drifting out through it.
local function buildOceanGate(root: Instance, rng: Random)
	local model = Instance.new("Model")
	model.Name = "OceanGate"
	model.Parent = root
	local out = (LAGOON.oceanGate - CENTER) * Vector3.new(1, 0, 1)
	local frame = CFrame.lookAt(LAGOON.oceanGate, LAGOON.oceanGate + out) -- -Z: out to sea
	local span, rise = 18, 21

	for i = 0, 12 do
		local a = math.pi * i / 12
		local size = rng:NextNumber(7, 9.5)
		local cf = frame * CFrame.new(math.cos(a) * span, math.sin(a) * rise + 1, 0) * CFrame.Angles(0, 0, a) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3))
		part({ Name = "ArchRock", Size = Vector3.new(size, size * 0.85, size * 1.05), CFrame = cf, Color = STONE:Lerp(Color3.fromRGB(70, 84, 110), rng:NextNumber(0, 0.45)), Material = Enum.Material.Slate, Parent = model })
	end
	for _, side in { -1, 1 } do
		boulder(model, (frame * CFrame.new(side * (span + 3), 0, 0)).Position, 12, rng)
		boulder(model, (frame * CFrame.new(side * (span + 9), 0, 3)).Position, 8, rng)
		for k = 1, 3 do
			seaGrass(model, (frame * CFrame.new(side * (span - 3), 0, rng:NextNumber(-4, 4))).Position + Vector3.new(0, 0, k), rng, 1.6)
		end
		jellyLamp(model, (frame * CFrame.new(side * 11, 0, 7)).Position, GLOW, true)
	end
	-- Coral and grass along the top of the arch.
	for _, deg in { 35, 70, 105, 140 } do
		local a = math.rad(deg)
		local top = frame:PointToWorldSpace(Vector3.new(math.cos(a) * span, math.sin(a) * rise + 5, 0))
		if deg % 2 == 0 then
			tubeCoral(model, top, rng, Color3.fromRGB(150, 90, 220))
		else
			bigCoral(model, top, rng, 1.8)
		end
		seaGrass(model, top + Vector3.new(1.5, 0, 0), rng, 1.5)
	end

	-- A plaque hanging from the arch: the lagoon's name inside, the open ocean outside.
	local plaque = part({ Name = "GatePlaque", Size = Vector3.new(15, 3, 0.6), CFrame = frame * CFrame.new(0, 15.5, 0), Color = Color3.fromRGB(40, 60, 80), CanCollide = false, Parent = model })
	surfaceLabel(plaque, Enum.NormalId.Back, "OCEAN GATE", Color3.fromRGB(180, 245, 255))
	surfaceLabel(plaque, Enum.NormalId.Front, "STARTER LAGOON", Color3.fromRGB(255, 220, 120))
	for _, x in { -6, 6 } do
		bar(model, "Chain", (frame * CFrame.new(x, 17, 0)).Position, (frame * CFrame.new(x * 0.9, 20.5, 0)).Position, 0.25, Color3.fromRGB(90, 90, 90), Enum.Material.Metal)
	end

	-- The current out to sea: bubbles drifting west through the arch.
	local current = prop({ Name = "GateCurrent", Size = Vector3.new(span * 1.5, 14, 1), CFrame = frame * CFrame.new(0, 8, 6), Transparency = 1, Parent = model })
	local drift = bubbles(current, 8, Enum.NormalId.Front)
	drift.Speed = NumberRange.new(5, 9)
	drift.Lifetime = NumberRange.new(5, 8)
	drift.SpreadAngle = Vector2.new(8, 8)
end

-- A sand path from the plaza out along `bearing` (degrees clockwise from north).
local function path(parent: Instance, bearing: number, from: number, to: number, width: number, rng: Random)
	local direction = Vector3.new(math.sin(math.rad(bearing)), 0, -math.cos(math.rad(bearing)))
	return WorldKit.path(parent, CENTER + direction * from, CENTER + direction * to, width, rng)
end

local function buildPlot(parent: Instance, index: number): PlotParts
	local frame = ReefConfig.plotFrame(index)
	local center = frame.Position
	local function at(x: number, y: number, z: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end
	-- The mound reaches a little past the largest bed, leaving room for the rocky rim.
	local radius = ReefConfig.moundRadius()
	-- Each reef gets its own outline, the same every time the server starts.
	local rng = Random.new(index * 7919)

	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model:SetAttribute("PlotIndex", index)
	-- Clients turn tap points into the same local offsets the server saves.
	model:SetAttribute("PlotFrame", frame)
	model.Parent = parent

	-- A round sand mound with a lumpy edge: one big disc plus smaller ones around the rim.
	disc(model, "Base", radius, 1, center + Vector3.new(0, 0.5, 0), REEF_SAND, Enum.Material.Sand)
	local lumps = math.round(radius / 4)
	for i = 1, lumps do
		local angle = (i / lumps) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local lump = rng:NextNumber(4, 7)
		disc(model, "Base", lump, 1, at(math.cos(angle) * (radius - lump * 0.5), 0.5, math.sin(angle) * (radius - lump * 0.5)), REEF_SAND, Enum.Material.Sand)
	end

	-- The bed the planters stand on, a raised rocky reef base.
	local bed = disc(model, "Bed", ReefConfig.BED_RADIUS, 0.4, center + Vector3.new(0, 1.2, 0), BED_SOIL, Enum.Material.Slate)
	local bedTop = bed.Position.Y + 0.2

	-- The planters: raised rings of sand, one coral each. Plots paints locked and empty ones.
	local planters: { Planter } = {}
	local h = ReefConfig.PLANTER_HEIGHT
	for slot, spot in ReefConfig.Planters do
		local base = at(spot.x, bedTop, spot.z)
		disc(model, "PlanterRim", ReefConfig.PLANTER_RADIUS + 0.35, h - 0.3, base + Vector3.new(0, (h - 0.3) / 2, 0), Color3.fromRGB(150, 120, 96), Enum.Material.Slate)
		local glow = disc(model, "PlanterGlow", ReefConfig.PLANTER_RADIUS + 0.12, h - 0.05, base + Vector3.new(0, (h - 0.05) / 2, 0), GLOW, Enum.Material.Neon)
		glow.CanCollide = false
		glow.CanQuery = false
		glow.Transparency = 1
		local top = disc(model, "Planter", ReefConfig.PLANTER_RADIUS, h, base + Vector3.new(0, h / 2, 0), Color3.fromRGB(232, 204, 150), Enum.Material.Sand)
		top:SetAttribute("Slot", slot)
		planters[slot] = { top = top, glow = glow }
	end

	-- Rocks and sea grass inside the rim, with a gap at the front (local -Z) to walk in.
	local rocks = math.round(radius * 0.6)
	for i = 1, rocks do
		local angle = (i / rocks) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if direction.Z > -0.85 then
			local s = rng:NextNumber(1.6, 3.2)
			local edge = direction * (radius - rng:NextNumber(0.6, 1.8))
			part({
				Name = "Rock",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(s, s, s),
				Position = at(edge.X, 1 + s * 0.1, edge.Z),
				Color = ROCK:Lerp(REEF_SAND, rng:NextNumber(0, 0.35)),
				Material = Enum.Material.Rock,
				Parent = model,
			})
			if i % 2 == 0 then
				local grass = direction * (radius - 3.2)
				seaGrass(model, at(grass.X, 1, grass.Z), rng)
			end
		end
	end

	-- The fence runs along the mound's edge, open at the front. Plots swaps the style.
	local fenceRadius = radius + 0.3
	local fenceFrame = frame + Vector3.new(0, 1, 0)
	local fence = FenceVisuals.build(ReefConfig.DEFAULT_FENCE, fenceFrame, fenceRadius, Random.new(index))
	fence.Parent = model

	-- The name sign arches over the gate, high enough to walk under.
	local front = -fenceRadius - 1
	for _, x in { -7.5, 7.5 } do
		part({ Name = "SignPost", Size = Vector3.new(0.8, 11, 0.8), CFrame = frame * CFrame.new(x, 5.5, front + 0.3), Color = Color3.fromRGB(96, 72, 52), Material = Enum.Material.Wood, Parent = model })
	end
	local signPart = part({ Name = "Sign", Size = Vector3.new(16, 3.5, 0.5), CFrame = frame * CFrame.new(0, 9.75, front), Color = Color3.fromRGB(40, 90, 120), Parent = model })
	local sign = surfaceLabel(signPart, Enum.NormalId.Front, "Empty reef", Color3.fromRGB(200, 240, 255))
	sign.Size = UDim2.fromScale(1, 0.7)
	local likes = surfaceLabel(signPart, Enum.NormalId.Front, "", Color3.fromRGB(255, 150, 190))
	likes.Parent.Name = "LikesGui"
	likes.Position = UDim2.fromScale(0, 0.68)
	likes.Size = UDim2.fromScale(1, 0.3)
	-- Visitors like the reef here; the server's Likes module answers.
	local likePrompt = prompt(signPart, "LikeReef", "Like this reef", "Reef rating", 14)
	likePrompt.Name = "LikePrompt"
	likePrompt.HoldDuration = 0.3
	likePrompt.UIOffset = Vector2.new(0, 40)
	-- The teleport pad's prompt is close by on E; this one has its own key and shows too.
	likePrompt.KeyboardKeyCode = Enum.KeyCode.F
	likePrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	likePrompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow

	-- You arrive on this pad when teleporting home, and it takes you back to the shops.
	local spawnPosition = at(0, 3, -radius - 7)
	teleportPad(model, spawnPosition - Vector3.new(0, 3, 0), "TeleportShops", "Go to the shops")
	return {
		index = index,
		model = model,
		frame = frame,
		center = center,
		radius = radius,
		bed = bed,
		bedTop = bedTop,
		planters = planters,
		planterTop = bedTop + h,
		sign = sign,
		likes = likes,
		signPart = signPart,
		spawn = CFrame.lookAt(spawnPosition, center + Vector3.new(0, 3, 0)),
		fence = fence,
		fenceFrame = fenceFrame,
		fenceRadius = fenceRadius,
	}
end

-- A leaderboard on the south side, facing the plaza.
local function buildBoard(parent: Instance, name: string, position: Vector3, heading: string): Frame
	local frame = CFrame.lookAt(position, Vector3.new(CENTER.X, position.Y, CENTER.Z))
	local board = part({ Name = name, Size = Vector3.new(20, 14, 1), CFrame = frame * CFrame.new(0, 12, 0), Color = Color3.fromRGB(30, 60, 90), Parent = parent })
	for _, x in { -9, 9 } do
		part({ Name = "BoardPost", Size = Vector3.new(1.5, 6, 1.5), CFrame = frame * CFrame.new(x, 3, 0.6), Color = ROCK, Material = Enum.Material.Slate, Parent = parent })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
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
	title.Text = heading
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

-- A band of drifting particles from each reef to the next one round the ring, switched on
-- during currents (which carry mutations downstream in the same order).
local function buildCurrents(root: Instance): { ParticleEmitter }
	local emitters = {}
	for index = 1, ReefConfig.PLOT_COUNT do
		local from = ReefConfig.plotFrame(index).Position + Vector3.new(0, 6, 0)
		local to = ReefConfig.plotFrame(index % ReefConfig.PLOT_COUNT + 1).Position + Vector3.new(0, 6, 0)
		local distance = (to - from).Magnitude
		local streamPart = prop({ Name = "CurrentStream", Size = Vector3.new(MOUND_REACH * 1.2, 8, 2), CFrame = CFrame.lookAt(from, to), Transparency = 1, Parent = root })
		local stream = Instance.new("ParticleEmitter")
		stream.Name = "Current"
		stream.Enabled = false
		stream.EmissionDirection = Enum.NormalId.Front
		stream.Speed = NumberRange.new(40, 55)
		stream.Lifetime = NumberRange.new(distance / 50, distance / 42)
		stream.Rate = 45
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
		table.insert(emitters, stream)
	end
	return emitters
end

-- Open seabed for scattered rocks and decoration: outside the lagoon's rim, outside the Main
-- Reef (MainReef decorates it), off the sand road east to the Sunken Ruins, and short of the
-- Ruins themselves (x > 240, built by their own module).
local RUINS_EDGE = 240
local function clearOfPlayArea(x: number, z: number): boolean
	local dx, dz = x - CENTER.X, z - CENTER.Z
	if dx * dx + dz * dz < (LAGOON.rimRadius + 25) ^ 2 then
		return false
	end
	local zone = ReefConfig.MainReef
	if x < zone.roadFrom + 30 and x > zone.roadTo - 60 and math.abs(z) < zone.ridgeZ + 30 then
		return false
	end
	if x > LAGOON.rimRadius - 10 and math.abs(z) < 30 then
		return false -- the road east to the Ruins
	end
	if z > LAGOON.rimRadius - 10 and z < 460 and x > -5 and x < 45 then
		return false -- the road south to the Abyss (along x = 20)
	end
	if z < -(LAGOON.rimRadius - 10) and math.abs(x) < 25 then
		return false -- the road north to the Kelp Forest (along x = 0)
	end
	local kelp = KelpConfig.center
	if (x - kelp.X) ^ 2 + (z - kelp.Z) ^ 2 < (KelpConfig.radius + 20) ^ 2 then
		return false -- the Kelp Forest builds its own
	end
	return x < RUINS_EDGE - 15
end

function World.build(): WorldParts
	setupLighting()

	local root = Instance.new("Folder")
	root.Name = "Reef"
	root.Parent = Workspace

	-- The seabed runs from past the Main Reef in the west to the Sunken Ruins in the east
	-- (which lay their own), far enough that its edge is lost in the haze.
	part({ Name = "Seabed", Size = Vector3.new(1260, 4, 900), Position = Vector3.new(-380, -2, 0), Color = SAND, Material = Enum.Material.Sand, Parent = root })
	local rng = Random.new(42)

	-- Low-poly boulders: a ragged rim round the lagoon, open at the Ocean Gate (west) and the
	-- road to the Ruins (east); more scattered over open seabed, some with bubble vents.
	for i = 1, 40 do
		local angle = (i / 40) * math.pi * 2 + rng:NextNumber(-0.04, 0.04)
		local distance = LAGOON.rimRadius + rng:NextNumber(0, 18)
		local x, z = CENTER.X + math.sin(angle) * distance, CENTER.Z - math.cos(angle) * distance
		-- Gaps: the Ocean Gate (west) and the Ruins road (east) at z = 0, the Abyss road
		-- (south) along x = 20, and the Kelp Forest road (north) along x = 0.
		local abyssRoad = z > CENTER.Z and math.abs(x - 20) < 22
		local kelpRoad = z < CENTER.Z and math.abs(x) < 22
		if math.abs(z - CENTER.Z) > 32 and not abyssRoad and not kelpRoad then
			boulder(root, Vector3.new(x, 0, z), rng:NextNumber(10, 20), rng)
		end
	end
	for i = 1, 70 do
		local x = rng:NextNumber(AREA.minX, AREA.maxX)
		local z = rng:NextNumber(AREA.minZ, AREA.maxZ)
		if clearOfPlayArea(x, z) then
			local s = rng:NextNumber(4, 10)
			boulder(root, Vector3.new(x, 0, z), s, rng)
			if i % 5 == 0 then
				bubbleVent(root, Vector3.new(x, s * 0.55, z))
			end
		end
	end
	SeabedDecor.build(root, rng, clearOfPlayArea)
	local surface, lightShafts = buildSurface(root, rng)

	-- New players appear on the dais in the middle of the plaza.
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LagoonSpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = CENTER + Vector3.new(0, 0.75, 0)
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.CanQuery = false
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = root

	buildPlaza(root, rng)
	local guide = buildGuide(root)
	buildOceanGate(root, rng)

	-- Sand paths: to each building, to the leaderboards, out through the Ocean Gate to the Main
	-- Reef's road, and east to the edge of the lagoon towards the Ruins.
	local paths = Instance.new("Model")
	paths.Name = "Paths"
	paths.Parent = root
	local plaza = LAGOON.plazaRadius - 1
	local function bearingOf(point: Vector3): number
		return math.deg(math.atan2(point.X - CENTER.X, -(point.Z - CENTER.Z)))
	end
	-- The four buildings, each joined to the plaza by a glass corridor.
	local hub = Hub.build(root, paths, rng)
	local shopStand, sellStand, hatcheryStand, suppliesStand = hub.shopStand, hub.sellStand, hub.hatcheryStand, hub.suppliesStand
	path(paths, bearingOf(LAGOON.oceanGate), plaza, -ReefConfig.MainReef.roadFrom + 2, 12, rng)
	path(paths, 180, plaza, (LAGOON.boards - CENTER).Magnitude + 8, 10, rng)
	path(paths, 90, (LAGOON.coralShop - CENTER).Magnitude + 26, LAGOON.rimRadius + 12, 10, rng)
	-- Lamps along the long walk west to the Main Reef.
	for d = 70, 140, 35 do
		for _, side in { -1, 1 } do
			jellyLamp(paths, LAGOON.center + Vector3.new(-d, 0, side * 9), if side < 0 then GLOW else Color3.fromRGB(255, 140, 220), d % 70 == 0)
		end
	end

	-- Coral gardens just off the plaza, between the paths.
	for _, bearing in { 25, 70, 110, 160, 200, 250, 290, 335 } do
		local direction = Vector3.new(math.sin(math.rad(bearing)), 0, -math.cos(math.rad(bearing)))
		local spot = CENTER + direction * rng:NextNumber(54, 60)
		bigCoral(root, spot, rng, rng:NextNumber(1.8, 2.6))
		if bearing % 2 == 0 then
			tableCoral(root, spot + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), rng)
		else
			tubeCoral(root, spot + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), rng)
		end
		boulder(root, spot + direction * 6, rng:NextNumber(3, 5), rng)
		for _ = 1, 3 do
			seaGrass(root, spot + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), rng, 1.2)
		end
	end

	local boardList = buildBoard(root, "TopReefsBoard", LAGOON.boards + Vector3.new(-22, 0, 0), "Top Reefs (shells earned)")
	local likesBoardList = buildBoard(root, "BestReefsBoard", LAGOON.boards + Vector3.new(22, 0, 0), "Best Reefs (likes)")
	local shopsPad = teleportPad(root, ReefConfig.Teleport.shopsPad, "TeleportHome", "Go to your reef")

	local collectibleSpots = MainReef.build(root, rng)
	local kelp = KelpWorld.build(root)
	for _, spot in kelp.pearlSpots do
		table.insert(collectibleSpots.pearls, spot)
	end
	-- The road north to the Kelp Forest, between the dome and the Upgrade Station, with a
	-- whirlpool at the plaza's edge that takes you straight there.
	WorldKit.path(paths, CENTER + Vector3.new(0, 0, -(LAGOON.plazaRadius - 1)), KelpConfig.entrance + Vector3.new(0, 0, 6), 10, rng)
	teleportPad(root, CENTER + Vector3.new(0, 0, -(LAGOON.plazaRadius + 8)), "TeleportKelp", "Go to the Kelp Forest")

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = root
	local plots: { PlotParts } = {}
	for index = 1, ReefConfig.PLOT_COUNT do
		plots[index] = buildPlot(plotsFolder, index)
		-- Attributes on the folder reach every client, even before the reef streams in.
		root:SetAttribute(`PlotHome_{index}`, plots[index].center)
	end
	root:SetAttribute("Landmark_Guide", guide)
	root:SetAttribute("Landmark_Sell", sellStand.Position)
	root:SetAttribute("Landmark_Upgrade", hub.labStand.Position) -- the tutorial's last step

	return {
		plots = plots,
		shopStand = shopStand,
		sellStand = sellStand,
		hatcheryStand = hatcheryStand,
		suppliesStand = suppliesStand,
		labStand = hub.labStand,
		marketDecorStand = hub.marketDecorStand,
		shopsPad = shopsPad,
		boardList = boardList,
		likesBoardList = likesBoardList,
		currentStreams = buildCurrents(root),
		surface = surface,
		lightShafts = lightShafts,
		collectibleSpots = collectibleSpots,
		kelp = kelp,
	}
end

return World
