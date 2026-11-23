--!nonstrict
-- Builds the Starter Lagoon at server start (layout in ReefConfig.Lagoon; north is -Z):
--   centre  the plaza, with the spawn on a glowing dais and Inky, the tutorial octopus
--   north   the Research Station, a glass dome holding the Reef Index and the Pet Hatchery,
--           and the Upgrade Station beside it (reef expansion, gear, fences, decorations)
--   east    the Coral Shop: buy seeds from Captain Coralie, sell coral to Pinch
--   west    the Ocean Gate, a stone arch out to the open ocean (where shipwrecks sink)
--   south   the leaderboards
--   around  the six reefs in a ring, each gate facing the plaza, sand paths leading to them
-- Everything lives under Workspace.Reef so it is easy to find in Explorer during play;
-- once you like the layout you can copy it out of a running session and save it into
-- the place, then delete this module's calls.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local CoralVisuals = require(ReplicatedStorage.Shared.CoralVisuals)
local FenceVisuals = require(ReplicatedStorage.Shared.FenceVisuals)
local SeabedDecor = require(script.Parent.SeabedDecor)
local ShopkeeperVisuals = require(script.Parent.ShopkeeperVisuals)

export type PlotParts = {
	index: number,
	model: Model,
	frame: CFrame, -- centre on the seabed, gate at local -Z; saved coral offsets use this frame
	center: Vector3,
	radius: number, -- the whole mound; points within it belong to this plot
	bed: BasePart, -- the round plantable bed (a cylinder lying flat)
	bedTop: number, -- world Y of the bed's top surface
	sign: TextLabel,
	likes: TextLabel, -- under the name on the sign
	signPart: BasePart, -- holds the "Like this reef" prompt
	spawn: CFrame,
	fence: Model, -- swapped when the owner picks another style
	fenceFrame: CFrame,
	fenceRadius: number,
}

export type WorldParts = {
	plots: { PlotParts },
	shopStand: BasePart, -- the Coral Shop's seed counter
	sellStand: BasePart, -- the Coral Shop's sell counter
	hatcheryStand: BasePart, -- the hatchery counter inside the Research Station
	suppliesStand: BasePart, -- the Upgrade Station counter (expansion, gear, fences, decor)
	shopsPad: BasePart, -- the teleport pad's pool in front of the Coral Shop
	boardList: Frame, -- Top Reefs, by shells earned
	likesBoardList: Frame, -- Best Reefs, by likes
	currentStreams: { ParticleEmitter }, -- one from each reef to the next, round the ring
	surface: BasePart,
	lightShafts: { BasePart },
}

local World = {}

local LAGOON = ReefConfig.Lagoon
local CENTER = LAGOON.center
local SAND = Color3.fromRGB(222, 204, 160)
local PATH_SAND = Color3.fromRGB(240, 228, 194)
local PLAZA_STONE = Color3.fromRGB(228, 216, 188)
local PLAZA_INLAY = Color3.fromRGB(222, 156, 140)
local REEF_SAND = Color3.fromRGB(196, 172, 128)
-- Slate, because Ground renders almost black under the underwater lighting.
local BED_SOIL = Color3.fromRGB(140, 100, 66)
local ROCK = Color3.fromRGB(96, 104, 112)
local STONE = Color3.fromRGB(112, 132, 156) -- the blue-grey of the low-poly rocks and arch
local SEA_GRASS = Color3.fromRGB(70, 150, 90)
local GLOW = Color3.fromRGB(90, 220, 240)
local METAL_DARK = Color3.fromRGB(52, 74, 96)
local HULL_WHITE = Color3.fromRGB(210, 228, 236)
local CORAL_PINK = Color3.fromRGB(240, 150, 160)
local TUBE_BLUE = Color3.fromRGB(60, 110, 230)
-- How far the mound (with its lumpy rim) reaches from a plot's centre.
local MOUND_REACH = ReefConfig.bedRadius(ReefConfig.MAX_SLOTS) + 7
-- Rocks, light shafts and decoration spread over the sea life's roaming area.
local AREA = ReefConfig.SeaLife.area
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X

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

-- Decoration: never collides or takes clicks, so it never gets in a player's way.
local function prop(props: { [string]: any }): Part
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return part(props)
end

-- A flat round slab. Roblox cylinders run along X, so it is rolled onto its side.
local function disc(parent: Instance, name: string, radius: number, height: number, position: Vector3, color: Color3, material: Enum.Material): Part
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(position) * UPRIGHT,
		Color = color,
		Material = material,
		Parent = parent,
	})
end

-- A thin bar from a to b.
local function bar(parent: Instance, name: string, a: Vector3, b: Vector3, thick: number, color: Color3, material: Enum.Material): Part
	return prop({
		Name = name,
		Size = Vector3.new(thick, thick, (b - a).Magnitude + thick * 0.5),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

-- A frame at `position` whose +Z (the front of a stand) faces `toward`.
local function facing(position: Vector3, toward: Vector3): CFrame
	local flat = Vector3.new(toward.X, position.Y, toward.Z)
	return CFrame.lookAt(position, position + (position - flat))
end

local function seaGrass(parent: Instance, position: Vector3, rng: Random, tall: number?)
	local scale = tall or 1
	for blade = 1, 3 do
		local height = rng:NextNumber(1.8, 3.2) * scale
		local lean = CFrame.Angles(rng:NextNumber(-0.25, 0.25), (blade / 3) * math.pi * 2, rng:NextNumber(-0.25, 0.25))
		prop({
			Name = "SeaGrass",
			Size = Vector3.new(0.25 * scale, height, 0.1),
			CFrame = CFrame.new(position) * lean * CFrame.new(0, height / 2, 0),
			Color = SEA_GRASS:Lerp(Color3.fromRGB(150, 200, 70), rng:NextNumber(0, 0.4)),
			Material = Enum.Material.Grass,
			Parent = parent,
		})
	end
end

-- A faceted, low-poly boulder: a few blocks tumbled together.
local function boulder(parent: Instance, position: Vector3, size: number, rng: Random, collide: boolean?)
	for _ = 1, 3 do
		local s = Vector3.new(size * rng:NextNumber(0.65, 1), size * rng:NextNumber(0.45, 0.75), size * rng:NextNumber(0.65, 1))
		local offset = Vector3.new(rng:NextNumber(-0.25, 0.25) * size, s.Y * 0.3, rng:NextNumber(-0.25, 0.25) * size)
		part({
			Name = "Boulder",
			Size = s,
			CFrame = CFrame.new(position + offset) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.5, 0.5)),
			Color = STONE:Lerp(Color3.fromRGB(70, 84, 110), rng:NextNumber(0, 0.5)),
			Material = Enum.Material.Slate,
			CanCollide = collide ~= false,
			Parent = parent,
		})
	end
end

-- Pink table coral: flat plates stacked on short stalks, like a tiered cake.
local function tableCoral(parent: Instance, position: Vector3, rng: Random, color: Color3?)
	local tint = (color or CORAL_PINK):Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.15))
	local y = 0
	local radius = rng:NextNumber(3, 4.5)
	for tier = 1, rng:NextInteger(2, 4) do
		local at = position + Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
		prop({ Name = "TableStalk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 0.8, 0.8), CFrame = CFrame.new(at + Vector3.new(0, y + 0.7, 0)) * UPRIGHT, Color = tint:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.Pebble, Parent = parent })
		y += 1.4
		prop({ Name = "TablePlate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, radius * 2, radius * 2), CFrame = CFrame.new(at + Vector3.new(0, y + 0.3, 0)) * UPRIGHT, Color = tint:Lerp(Color3.new(0, 0, 0), tier * 0.04), Material = Enum.Material.Pebble, Parent = parent })
		y += 0.6
		radius *= rng:NextNumber(0.62, 0.8)
		tint = tint:Lerp(Color3.new(1, 1, 1), 0.1)
	end
end

-- A clump of tube coral: upright tubes with dark open tops.
local function tubeCoral(parent: Instance, position: Vector3, rng: Random, color: Color3?)
	local base = color or TUBE_BLUE
	for _ = 1, rng:NextInteger(4, 7) do
		local height = rng:NextNumber(2, 6)
		local width = rng:NextNumber(0.9, 1.7)
		local at = position + Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))
		local lean = CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
		local tint = base:Lerp(Color3.fromRGB(150, 200, 255), rng:NextNumber(0, 0.35))
		local tube = CFrame.new(at) * lean * CFrame.new(0, height / 2, 0)
		prop({ Name = "Tube", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, width, width), CFrame = tube * UPRIGHT, Color = tint, Material = Enum.Material.SmoothPlastic, Parent = parent })
		prop({ Name = "TubeMouth", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, width * 0.7, width * 0.7), CFrame = tube * CFrame.new(0, height / 2 + 0.02, 0) * UPRIGHT, Color = Color3.fromRGB(150, 40, 30), Material = Enum.Material.SmoothPlastic, Parent = parent })
	end
end

-- Coral grown from the planted-coral models, past full size.
local function bigCoral(parent: Instance, position: Vector3, rng: Random, scale: number)
	local seedId = ReefConfig.SEED_ORDER[rng:NextInteger(1, #ReefConfig.SEED_ORDER)]
	if ReefConfig.Seeds[seedId].shop == false then
		seedId = "kelp" -- keep event seeds rare, even as decoration
	end
	local coral = CoralVisuals.build(seedId, "None", CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	coral.Name = "DecorCoral"
	coral:ScaleTo(scale)
	for _, descendant in coral:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end
	coral.Parent = parent
end

-- A glowing jellyfish lamp on a kelp stalk, lighting the paths.
local function jellyLamp(parent: Instance, position: Vector3, color: Color3, light: boolean)
	local height = 7
	prop({ Name = "LampStalk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 0.45, 0.45), CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * UPRIGHT, Color = Color3.fromRGB(70, 120, 60), Material = Enum.Material.Grass, Parent = parent })
	local bell = prop({ Name = "LampBell", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Position = position + Vector3.new(0, height + 0.5, 0), Color = color, Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false, Parent = parent })
	for i = 1, 4 do
		local angle = i / 4 * math.pi * 2
		local top = position + Vector3.new(math.cos(angle) * 0.6, height - 0.1, math.sin(angle) * 0.6)
		bar(parent, "LampTentacle", top, top - Vector3.new(0, 1.6, 0), 0.15, color, Enum.Material.Neon)
	end
	if light then
		local pointLight = Instance.new("PointLight")
		pointLight.Color = color
		pointLight.Range = 16
		pointLight.Brightness = 0.9
		pointLight.Parent = bell
	end
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

local function prompt(parent: Instance, kind: string, action: string, object: string, distance: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = kind .. "Prompt"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = distance
	p.RequiresLineOfSight = false
	p:SetAttribute("Kind", kind)
	p.Parent = parent
	return p
end

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
		Size = Vector3.new(1400, 2, 1400),
		Position = Vector3.new(CENTER.X, 110, CENTER.Z),
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

local function bubbles(parent: BasePart, rate: number, direction: Enum.NormalId)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	emitter.Size = NumberSequence.new(0.4, 0.9)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(4, 7)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.EmissionDirection = direction
	emitter.Parent = parent
	return emitter
end

local function bubbleVent(parent: Instance, position: Vector3)
	local vent = prop({ Name = "BubbleVent", Size = Vector3.new(3, 1, 3), Position = position, Color = ROCK, Material = Enum.Material.Basalt, Parent = parent })
	bubbles(vent, 6, Enum.NormalId.Top)
end

-- A whirlpool teleport pad: a stone ring round a glowing pool, four marker stones with
-- glowing tips, and bubbles rising off it. The server's Teleport module answers its prompt.
local function teleportPad(parent: Instance, position: Vector3, kind: string, action: string): BasePart
	local model = Instance.new("Model")
	model.Name = "TeleportPad"
	model.Parent = parent
	disc(model, "Ring", 4.5, 0.6, position + Vector3.new(0, 0.3, 0), ROCK, Enum.Material.Slate)
	local pool = disc(model, "Pool", 3.6, 0.1, position + Vector3.new(0, 0.62, 0), GLOW, Enum.Material.Neon)
	pool.Transparency = 0.25
	pool.CanCollide = false
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + math.pi / 4
		local at = position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 4.2
		part({ Name = "MarkerStone", Size = Vector3.new(0.9, 2.6, 0.9), Position = at + Vector3.new(0, 1.3, 0), Color = ROCK, Material = Enum.Material.Basalt, Parent = model })
		prop({ Name = "MarkerGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), Position = at + Vector3.new(0, 2.8, 0), Color = GLOW, Material = Enum.Material.Neon, Parent = model })
	end
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = pool
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Color = ColorSequence.new(Color3.fromRGB(200, 245, 255))
	swirl.LightEmission = 0.5
	swirl.Size = NumberSequence.new(0.3, 0.7)
	swirl.Transparency = NumberSequence.new(0.2, 1)
	swirl.Lifetime = NumberRange.new(2, 4)
	swirl.Rate = 10
	swirl.Speed = NumberRange.new(3, 6)
	swirl.RotSpeed = NumberRange.new(-90, 90)
	swirl.SpreadAngle = Vector2.new(20, 20)
	swirl.EmissionDirection = Enum.NormalId.Right -- up, since the cylinder lies on its side
	swirl.Parent = pool

	local p = prompt(pool, kind, action, "Whirlpool", 8)
	p.Name = "TeleportPrompt"
	return pool
end

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

-- Inky's rock beside the spawn, a "Start here" sign, and Inky, facing the spawn.
local function buildGuide(root: Instance): Vector3
	local at = LAGOON.guide
	local model = Instance.new("Model")
	model.Name = "Guide"
	model.Parent = root
	local seat = disc(model, "GuideRock", 2.8, 1.6, at + Vector3.new(0, 0.8, 0), STONE, Enum.Material.Slate)
	prompt(seat, "Guide", "Talk", "Inky", 12)
	local base = CFrame.lookAt(at + Vector3.new(0, 1.6, 0), Vector3.new(CENTER.X, 1.6, CENTER.Z))
	ShopkeeperVisuals.build("Guide", base).Parent = model

	local signAt = base * CFrame.new(4.2, 0, 0.8)
	part({ Name = "SignPost", Size = Vector3.new(0.5, 5, 0.5), CFrame = signAt * CFrame.new(0, 1, 0), Color = Color3.fromRGB(110, 84, 62), Material = Enum.Material.Wood, Parent = model })
	local board = part({ Name = "StartSign", Size = Vector3.new(4.6, 1.8, 0.3), CFrame = signAt * CFrame.new(0, 3.2, 0), Color = Color3.fromRGB(40, 90, 120), CanCollide = false, Parent = model })
	surfaceLabel(board, Enum.NormalId.Front, "START HERE!", Color3.fromRGB(255, 220, 120))
	return at
end

-- The Research Station (the concept art's glass dome): a dark base ringed with light, a
-- glass dome with white ribs and a round skylight, a tunnel door facing the plaza, the Reef
-- Index hologram in the middle and the Pet Hatchery counter at the back. A submarine is
-- parked beside it. Returns the hatchery counter.
local function buildResearchStation(root: Instance, rng: Random): BasePart
	local model = Instance.new("Model")
	model.Name = "ResearchStation"
	model.Parent = root
	local R = 19
	local frame = CFrame.lookAt(LAGOON.research, Vector3.new(CENTER.X, LAGOON.research.Y, CENTER.Z)) -- -Z: the door
	local function at(x: number, y: number, z: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end

	disc(model, "Base", R + 0.8, 1.2, at(0, 0.6, 0), METAL_DARK, Enum.Material.Metal)
	disc(model, "BaseGlow", R + 0.95, 0.3, at(0, 1.0, 0), GLOW, Enum.Material.Neon)
	disc(model, "Floor", R, 0.2, at(0, 1.3, 0), Color3.fromRGB(176, 220, 228), Enum.Material.SmoothPlastic)
	disc(model, "FloorGlow", 9, 0.22, at(0, 1.31, 0), GLOW, Enum.Material.Neon)
	disc(model, "FloorInner", 8.4, 0.24, at(0, 1.32, 0), Color3.fromRGB(176, 220, 228), Enum.Material.SmoothPlastic)

	prop({
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(R * 2, R * 2, R * 2),
		Position = at(0, 1.2, 0),
		Color = Color3.fromRGB(175, 230, 250),
		Material = Enum.Material.Glass,
		Transparency = 0.72,
		Reflectance = 0.1,
		CastShadow = false,
		Parent = model,
	})
	-- White ribs from the base up to the skylight, leaving the door side clear.
	local top = 1.2 + R
	for k = 0, 5 do
		local azimuth = math.rad(30 + k * 60)
		local out = Vector3.new(math.sin(azimuth), 0, -math.cos(azimuth))
		local previous
		for step = 0, 7 do
			local theta = math.rad(step * 72 / 7) -- stop short of the skylight ring
			local point = out * (R + 0.1) * math.cos(theta) + Vector3.new(0, 1.2 + (R + 0.1) * math.sin(theta), 0)
			local world = frame:PointToWorldSpace(point)
			if previous then
				bar(model, "Rib", previous, world, 0.45, HULL_WHITE, Enum.Material.Metal)
			end
			previous = world
		end
	end
	disc(model, "Skylight", 6, 0.8, at(0, top - 1.1, 0), HULL_WHITE, Enum.Material.Metal)
	disc(model, "SkylightGlow", 6.2, 0.35, at(0, top - 1.2, 0), GLOW, Enum.Material.Neon)
	local skylight = disc(model, "SkylightGlass", 5.2, 0.85, at(0, top - 1.1, 0), Color3.fromRGB(200, 245, 255), Enum.Material.Glass)
	skylight.Transparency = 0.5
	skylight.CanCollide = false
	bubbles(skylight, 3, Enum.NormalId.Right)

	-- The door: a short tunnel with a glowing rim, and a ramp up from the sand.
	local doorZ = -R - 1
	for _, x in { -4.4, 4.4 } do
		part({ Name = "DoorFrame", Size = Vector3.new(1.4, 4.6, 4), CFrame = frame * CFrame.new(x, 1.2 + 2.3, doorZ), Color = HULL_WHITE, Material = Enum.Material.Metal, Parent = model })
	end
	for i = 0, 8 do
		local a = math.pi * i / 8
		local cf = frame * CFrame.new(math.cos(a) * 4.4, 5.8 + math.sin(a) * 4.4, doorZ) * CFrame.Angles(0, 0, a)
		part({ Name = "DoorArch", Size = Vector3.new(1.4, 1.9, 4), CFrame = cf, Color = HULL_WHITE, Material = Enum.Material.Metal, Parent = model })
		prop({ Name = "DoorGlow", Size = Vector3.new(0.3, 1.9, 4.1), CFrame = frame * CFrame.new(math.cos(a) * 3.6, 5.8 + math.sin(a) * 3.6, doorZ) * CFrame.Angles(0, 0, a), Color = GLOW, Material = Enum.Material.Neon, Parent = model })
	end
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(7.6, 1.3, 4)
	ramp.CFrame = frame * CFrame.new(0, 0.65, -R - 0.8 - 4)
	ramp.Color = METAL_DARK
	ramp.Material = Enum.Material.Metal
	ramp.Parent = model
	local sign = part({ Name = "Sign", Size = Vector3.new(17, 2.8, 0.5), CFrame = frame * CFrame.new(0, 13.6, doorZ - 1), Color = Color3.fromRGB(30, 70, 100), CanCollide = false, Parent = model })
	surfaceLabel(sign, Enum.NormalId.Front, "RESEARCH STATION", Color3.fromRGB(180, 245, 255))

	-- The Reef Index: a hologram globe over a pedestal in the middle.
	local pedestal = part({ Name = "IndexPedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2.8, 2.8), CFrame = frame * CFrame.new(0, 2.9, 0) * UPRIGHT, Color = HULL_WHITE, Material = Enum.Material.Metal, Parent = model })
	local globe = prop({ Name = "IndexGlobe", Shape = Enum.PartType.Ball, Size = Vector3.new(3.6, 3.6, 3.6), Position = at(0, 6.4, 0), Color = GLOW, Material = Enum.Material.Neon, Transparency = 0.45, CastShadow = false, Parent = model })
	prop({ Name = "IndexOrbit", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 5.6, 5.6), CFrame = CFrame.new(globe.Position) * CFrame.Angles(0.4, 0, math.rad(90) + 0.3), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon, Transparency = 0.3, Parent = model })
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 24
	light.Brightness = 1.2
	light.Parent = globe
	prompt(pedestal, "Index", "Open Reef Index", "Research Station", 10)

	-- The Pet Hatchery: a curved counter at the back with three glowing egg incubators.
	local hatchery
	for i, deg in { 150, 180, 210 } do
		local azimuth = math.rad(deg)
		local pos = at(math.sin(azimuth) * 11.5, 2.9, -math.cos(azimuth) * 11.5)
		local counter = part({ Name = if i == 2 then "HatcheryCounter" else "Counter", Size = Vector3.new(6.4, 3, 2.4), CFrame = CFrame.lookAt(pos, Vector3.new(LAGOON.research.X, pos.Y, LAGOON.research.Z)), Color = HULL_WHITE, Material = Enum.Material.SmoothPlastic, Parent = model })
		prop({ Name = "CounterGlow", Size = Vector3.new(6.5, 0.25, 2.5), CFrame = counter.CFrame * CFrame.new(0, 1.4, 0), Color = Color3.fromRGB(200, 140, 255), Material = Enum.Material.Neon, Parent = model })
		if i == 2 then
			hatchery = counter
		end
		local incubator = at(math.sin(azimuth) * 15.5, 1.4, -math.cos(azimuth) * 15.5)
		disc(model, "IncubatorBase", 1.7, 0.6, incubator + Vector3.new(0, 0.3, 0), METAL_DARK, Enum.Material.Metal)
		local glass = disc(model, "IncubatorGlass", 1.5, 3.4, incubator + Vector3.new(0, 2.3, 0), Color3.fromRGB(220, 240, 255), Enum.Material.Glass)
		glass.Transparency = 0.6
		glass.CanCollide = false
		local egg = prop({ Name = "Egg", Shape = Enum.PartType.Ball, Size = Vector3.new(1.7, 1.7, 1.7), Position = incubator + Vector3.new(0, 1.9, 0), Color = ({ Color3.fromRGB(255, 170, 210), Color3.fromRGB(255, 215, 110), Color3.fromRGB(120, 230, 210) })[i], Material = Enum.Material.Neon, Transparency = 0.1, Parent = model })
		local eggLight = Instance.new("PointLight")
		eggLight.Color = egg.Color
		eggLight.Range = 7
		eggLight.Brightness = 0.8
		eggLight.Parent = egg
	end
	local hatchPrompt = prompt(hatchery, "Hatchery", "Hatch eggs", "Pet Hatchery", 12)
	hatchPrompt.Name = "StandPrompt"

	-- Benches and kelp along the curve, coral by the walls.
	for _, deg in { 75, 285 } do
		local azimuth = math.rad(deg)
		local pos = at(math.sin(azimuth) * 14, 2.1, -math.cos(azimuth) * 14)
		part({ Name = "Bench", Size = Vector3.new(6, 1.4, 2.4), CFrame = CFrame.lookAt(pos, Vector3.new(LAGOON.research.X, pos.Y, LAGOON.research.Z)), Color = HULL_WHITE, Material = Enum.Material.SmoothPlastic, Parent = model })
	end
	for _, deg in { 45, 115, 245, 315 } do
		local azimuth = math.rad(deg)
		seaGrass(model, at(math.sin(azimuth) * 16.5, 1.4, -math.cos(azimuth) * 16.5), rng, 2.2)
	end
	for _, deg in { 125, 235 } do
		local azimuth = math.rad(deg)
		bigCoral(model, at(math.sin(azimuth) * 16, 1.4, -math.cos(azimuth) * 16), rng, 1.3)
	end

	-- Coral heaped round the outside (not across the door), like the concept art.
	for i = 1, 16 do
		local azimuth = math.rad(rng:NextNumber(40, 320))
		local pos = at(math.sin(azimuth) * rng:NextNumber(R + 2.5, R + 7), 0, -math.cos(azimuth) * rng:NextNumber(R + 2.5, R + 7))
		local pick = i % 4
		if pick == 0 then
			tableCoral(model, pos, rng, if i % 8 == 0 then Color3.fromRGB(200, 130, 110) else CORAL_PINK)
		elseif pick == 1 then
			tubeCoral(model, pos, rng)
		elseif pick == 2 then
			bigCoral(model, pos, rng, rng:NextNumber(1.6, 2.4))
		else
			seaGrass(model, pos, rng, 1.4)
		end
	end
	boulder(model, at(-R - 4, 0, 6), 6, rng)
	boulder(model, at(R + 3, 0, 9), 5, rng)

	-- The submarine parked beside the door.
	local sub = frame * CFrame.new(R + 8, 0, -9) * CFrame.Angles(0, math.rad(-35), 0)
	local hull = Color3.fromRGB(64, 112, 132)
	prop({ Name = "SubHull", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 4, 4), CFrame = sub * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(90), 0), Color = hull, Material = Enum.Material.SmoothPlastic, Parent = model })
	prop({ Name = "SubNose", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), CFrame = sub * CFrame.new(0, 3, -4), Color = hull, Material = Enum.Material.SmoothPlastic, Parent = model })
	prop({ Name = "SubTail", Shape = Enum.PartType.Ball, Size = Vector3.new(3.6, 3.6, 3.6), CFrame = sub * CFrame.new(0, 3, 4), Color = hull, Material = Enum.Material.SmoothPlastic, Parent = model })
	prop({ Name = "SubCockpit", Shape = Enum.PartType.Ball, Size = Vector3.new(2.8, 2.8, 2.8), CFrame = sub * CFrame.new(0, 4.6, -2.2), Color = Color3.fromRGB(150, 230, 255), Material = Enum.Material.Glass, Transparency = 0.35, Parent = model })
	prop({ Name = "SubStripe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4.1, 4.1), CFrame = sub * CFrame.new(0, 3, 1.5) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 196, 64), Material = Enum.Material.SmoothPlastic, Parent = model })
	prop({ Name = "SubFin", Size = Vector3.new(0.4, 2, 2.4), CFrame = sub * CFrame.new(0, 5.4, 3.4), Color = hull, Material = Enum.Material.SmoothPlastic, Parent = model })
	prop({ Name = "SubTailFin", Size = Vector3.new(4.6, 0.3, 1.6), CFrame = sub * CFrame.new(0, 3, 5.6), Color = hull, Material = Enum.Material.SmoothPlastic, Parent = model })
	for _, side in { -1, 1 } do
		prop({ Name = "SubThruster", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.6, 1.6), CFrame = sub * CFrame.new(side * 2.8, 2.4, 2.4) * CFrame.Angles(0, math.rad(90), 0), Color = METAL_DARK, Material = Enum.Material.Metal, Parent = model })
		prop({ Name = "SubThrusterGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.3, 1.3), CFrame = sub * CFrame.new(side * 2.8, 2.4, 3.95) * CFrame.Angles(0, math.rad(90), 0), Color = GLOW, Material = Enum.Material.Neon, Parent = model })
		prop({ Name = "SubLight", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = sub * CFrame.new(side * 1.1, 2.5, -5.7), Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon, Parent = model })
		prop({ Name = "SubSkid", Size = Vector3.new(0.5, 0.5, 7), CFrame = sub * CFrame.new(side * 1.6, 0.3, 0), Color = METAL_DARK, Material = Enum.Material.Metal, Parent = model })
		for _, z in { -2, 2 } do
			bar(model, "SubStrut", (sub * CFrame.new(side * 1.6, 0.4, z)).Position, (sub * CFrame.new(side * 1, 1.6, z)).Position, 0.3, METAL_DARK, Enum.Material.Metal)
		end
	end
	return hatchery
end

-- The Upgrade Station beside the Research Station: a stand kept by Old Shellby the turtle,
-- with an anchor, crates and a cog over the sign. Returns the counter.
local function buildUpgradeStation(root: Instance, rng: Random): BasePart
	local frame = facing(LAGOON.upgrade, CENTER)
	local counter = stand(root, "UpgradeStation", frame, Color3.fromRGB(46, 150, 170), "Upgrade Station", "Supplies", "Upgrade your reef")
	local model = counter.Parent :: Model
	local facePlayers = CFrame.Angles(0, math.pi, 0)
	ShopkeeperVisuals.build("Supplies", counter.CFrame * CFrame.new(-4, counter.Size.Y / 2, 0) * facePlayers).Parent = model

	-- A cog over the sign.
	local cog = frame * CFrame.new(0, 16.4, -1)
	local brass = Color3.fromRGB(214, 170, 80)
	prop({ Name = "Cog", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4.4, 4.4), CFrame = cog * CFrame.Angles(0, math.rad(90), 0), Color = brass, Material = Enum.Material.Metal, Parent = model })
	prop({ Name = "CogHub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 1.6, 1.6), CFrame = cog * CFrame.Angles(0, math.rad(90), 0), Color = METAL_DARK, Material = Enum.Material.Metal, Parent = model })
	for i = 0, 7 do
		local a = i * math.pi / 4
		prop({ Name = "CogTooth", Size = Vector3.new(1, 1, 0.6), CFrame = cog * CFrame.Angles(0, 0, a) * CFrame.new(0, 2.5, 0), Color = brass, Material = Enum.Material.Metal, Parent = model })
	end

	-- An anchor leaning on the right, crates on the left.
	local anchor = frame * CFrame.new(9.5, 0, 0.5) * CFrame.Angles(0, 0, math.rad(-8))
	local iron = Color3.fromRGB(110, 90, 80)
	prop({ Name = "AnchorShank", Size = Vector3.new(0.8, 7.5, 0.8), CFrame = anchor * CFrame.new(0, 4, 0), Color = iron, Material = Enum.Material.CorrodedMetal, Parent = model })
	prop({ Name = "AnchorStock", Size = Vector3.new(4, 0.7, 0.7), CFrame = anchor * CFrame.new(0, 6.6, 0), Color = iron, Material = Enum.Material.CorrodedMetal, Parent = model })
	prop({ Name = "AnchorRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.6, 1.6), CFrame = anchor * CFrame.new(0, 8.1, 0) * CFrame.Angles(0, math.rad(90), 0), Color = iron, Material = Enum.Material.CorrodedMetal, Parent = model })
	for _, side in { -1, 1 } do
		prop({ Name = "AnchorArm", Size = Vector3.new(3, 0.7, 0.7), CFrame = anchor * CFrame.new(side * 1.2, 0.9, 0) * CFrame.Angles(0, 0, side * math.rad(35)), Color = iron, Material = Enum.Material.CorrodedMetal, Parent = model })
	end
	for _, spot in { Vector3.new(-9.5, 1.25, 0.5), Vector3.new(-11.6, 1, 2.6), Vector3.new(-9.8, 3.6, 0.6) } do
		part({ Name = "Crate", Size = Vector3.new(2.5, 2.5, 2.5) * (if spot.Y > 2 then 0.8 else 1), CFrame = frame * CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Color = Color3.fromRGB(150, 110, 80), Material = Enum.Material.WoodPlanks, Parent = model })
	end
	tubeCoral(model, (frame * CFrame.new(13, 0, -3)).Position, rng, Color3.fromRGB(70, 200, 180))
	seaGrass(model, (frame * CFrame.new(-13, 0, -2)).Position, rng, 1.3)
	return counter
end

-- The Coral Shop on the east side: a seed counter and a sell counter in front of a lumpy
-- pink coral-stone wall, under one big sign. Returns (seed counter, sell counter).
local function buildCoralShop(root: Instance, rng: Random): (BasePart, BasePart)
	local frame = facing(LAGOON.coralShop, CENTER)
	local model = Instance.new("Model")
	model.Name = "CoralShop"
	model.Parent = root
	local seeds = stand(model, "SeedCounter", frame * CFrame.new(-11, 0, 0), Color3.fromRGB(70, 170, 110), "Seeds", "SeedShop", "Browse seeds")
	local sell = stand(model, "SellCounter", frame * CFrame.new(11, 0, 0), Color3.fromRGB(220, 140, 60), "Sell Coral", "Sell", "Sell all coral")
	local seedPrompt = seeds:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	seedPrompt.ObjectText = "Coral Shop"
	-- Shopkeepers face the customers: the diver stands behind the seed counter, the crab
	-- sits on the sell counter, off to one side.
	local facePlayers = CFrame.Angles(0, math.pi, 0)
	ShopkeeperVisuals.build("SeedShop", seeds.CFrame * CFrame.new(0, -seeds.Size.Y / 2, -seeds.Size.Z / 2 - 1.1) * facePlayers).Parent = model
	ShopkeeperVisuals.build("Sell", sell.CFrame * CFrame.new(4.5, sell.Size.Y / 2, 0) * facePlayers).Parent = model

	-- The backdrop: two rows of overlapping coral-stone domes, table coral growing on top.
	for row = 0, 1 do
		for i = 0, 10 - row do
			local size = if row == 0 then rng:NextNumber(8, 10) else rng:NextNumber(6.5, 8.5)
			local x = -24 + i * 4.8 + row * 2.4
			local tint = Color3.fromRGB(226, 140, 132):Lerp(Color3.fromRGB(190, 110, 130), rng:NextNumber(0, 0.6))
			part({ Name = "ShopWall", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = frame * CFrame.new(x, if row == 0 then 3 else 9, -9.5 + row * 0.5), Color = tint, Material = Enum.Material.Pebble, Parent = model })
		end
	end
	for _, x in { -20, -3, 15 } do
		tableCoral(model, (frame * CFrame.new(x, 12.5, -9.5)).Position, rng)
	end
	local sign = part({ Name = "Sign", Size = Vector3.new(30, 5, 0.8), CFrame = frame * CFrame.new(0, 19.5, -7), Color = Color3.fromRGB(30, 70, 100), CanCollide = false, Parent = model })
	surfaceLabel(sign, Enum.NormalId.Back, "CORAL SHOP", Color3.fromRGB(255, 220, 120))
	for _, x in { -26, 26 } do
		jellyLamp(model, (frame * CFrame.new(x, 0, 4)).Position, Color3.fromRGB(255, 160, 90), true)
		tubeCoral(model, (frame * CFrame.new(x * 0.95, 0, -3)).Position, rng)
	end
	return seeds, sell
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

-- A sand path from the plaza out along `bearing` (degrees clockwise from north), with
-- pebbles along both edges.
local function path(parent: Instance, bearing: number, from: number, to: number, width: number, rng: Random)
	local direction = Vector3.new(math.sin(math.rad(bearing)), 0, -math.cos(math.rad(bearing)))
	local a, b = CENTER + direction * from, CENTER + direction * to
	part({
		Name = "Path",
		Size = Vector3.new(width, 0.3, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.15, 0), b + Vector3.new(0, 0.15, 0)),
		Color = PATH_SAND,
		Material = Enum.Material.Sand,
		Parent = parent,
	})
	local side = Vector3.new(-direction.Z, 0, direction.X)
	local length = (b - a).Magnitude
	for d = 3, length, 5 do
		for _, s in { -1, 1 } do
			if rng:NextNumber() < 0.7 then
				local size = rng:NextNumber(0.8, 1.6)
				prop({
					Name = "Pebble",
					Size = Vector3.new(size, size * 0.4, size * 1.2),
					CFrame = CFrame.new(a + direction * (d + rng:NextNumber(-1.5, 1.5)) + side * s * (width / 2 + rng:NextNumber(0, 0.8)) + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
					Color = Color3.fromRGB(200, 196, 186):Lerp(STONE, rng:NextNumber(0, 0.5)),
					Material = Enum.Material.Pebble,
					Parent = parent,
				})
			end
		end
	end
	return direction, side
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

	-- The bed is where coral goes. Plots resizes it to the owner's slots.
	local bed = disc(model, "Bed", ReefConfig.bedRadius(ReefConfig.STARTING_SLOTS), 0.4, center + Vector3.new(0, 1.2, 0), BED_SOIL, Enum.Material.Slate)

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
		bedTop = bed.Position.Y + 0.2,
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

-- Open seabed: clear of the plaza and buildings, the reefs and the channel out west
-- through the Ocean Gate, where shipwrecks sink.
local function clearOfPlayArea(x: number, z: number): boolean
	local dx, dz = x - CENTER.X, z - CENTER.Z
	if dx * dx + dz * dz < 150 * 150 then
		return false
	end
	if ReefConfig.nearPlot(x, z, 6) then
		return false
	end
	local wreck = ReefConfig.Shipwreck.landing
	return not (x < LAGOON.oceanGate.X and math.abs(z - wreck.Z) < 45)
end

function World.build(): WorldParts
	setupLighting()

	local root = Instance.new("Folder")
	root.Name = "Reef"
	root.Parent = Workspace

	-- The seabed runs far past the play area so its edge is lost in the haze.
	part({ Name = "Seabed", Size = Vector3.new(1200, 4, 1200), Position = CENTER + Vector3.new(0, -2, 0), Color = SAND, Material = Enum.Material.Sand, Parent = root })
	local rng = Random.new(42)

	-- Low-poly boulders: a ragged rim round the lagoon, more scattered over open seabed,
	-- some with bubble vents.
	for i = 1, 44 do
		local angle = (i / 44) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local distance = rng:NextNumber(300, 345)
		local x, z = CENTER.X + math.sin(angle) * distance, CENTER.Z - math.cos(angle) * distance
		if clearOfPlayArea(x, z) then
			boulder(root, Vector3.new(x, 0, z), rng:NextNumber(10, 22), rng)
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
	local hatcheryStand = buildResearchStation(root, rng)
	local suppliesStand = buildUpgradeStation(root, rng)
	local shopStand, sellStand = buildCoralShop(root, rng)
	buildOceanGate(root, rng)

	-- Sand paths: to every reef's gate, to each building, and out through the Ocean Gate.
	local paths = Instance.new("Model")
	paths.Name = "Paths"
	paths.Parent = root
	local plaza = LAGOON.plazaRadius - 1
	local reefGate = LAGOON.plotRing - ReefConfig.moundRadius() - 2
	local function bearingOf(point: Vector3): number
		return math.deg(math.atan2(point.X - CENTER.X, -(point.Z - CENTER.Z)))
	end
	for index = 1, ReefConfig.PLOT_COUNT do
		local bearing = bearingOf(ReefConfig.plotFrame(index).Position)
		local direction, side = path(paths, bearing, plaza, reefGate, 10, rng)
		-- Lamps along the way, swapping sides, and sea grass meadows either side.
		for k, d in { 72, 108 } do
			jellyLamp(paths, CENTER + direction * d + side * (if k == 1 then 7.5 else -7.5), if index % 2 == 0 then GLOW else Color3.fromRGB(255, 140, 220), true)
		end
		for _ = 1, 10 do
			local d = rng:NextNumber(plaza + 12, reefGate - 6)
			local s = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(8, 18)
			seaGrass(paths, CENTER + direction * d + side * s, rng, rng:NextNumber(0.9, 1.5))
		end
	end
	path(paths, bearingOf(LAGOON.coralShop), plaza, (LAGOON.coralShop - CENTER).Magnitude - 4, 12, rng)
	path(paths, bearingOf(LAGOON.research), plaza, (LAGOON.research - CENTER).Magnitude - 22, 8, rng)
	path(paths, bearingOf(LAGOON.upgrade), plaza, (LAGOON.upgrade - CENTER).Magnitude - 4, 8, rng)
	path(paths, bearingOf(LAGOON.oceanGate), plaza, 360, 12, rng)

	-- Coral gardens just off the plaza, between the paths.
	for _, bearing in { 44, 75, 105, 150, 210, 255, 285, 316 } do
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
	root:SetAttribute("Landmark_Upgrade", suppliesStand.Position)

	return {
		plots = plots,
		shopStand = shopStand,
		sellStand = sellStand,
		hatcheryStand = hatcheryStand,
		suppliesStand = suppliesStand,
		shopsPad = shopsPad,
		boardList = boardList,
		likesBoardList = likesBoardList,
		currentStreams = buildCurrents(root),
		surface = surface,
		lightShafts = lightShafts,
	}
end

return World
