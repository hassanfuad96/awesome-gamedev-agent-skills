--!nonstrict
-- Builds the Kelp Forest (layout in KelpConfig): its own seabed and water surface, giant kelp
-- groves with a sunlit clearing, the main trail, three hidden glades walled in by kelp and
-- reached by faint glowing pebble trails, two sea turtle habitats with nests, two seagrass
-- meadows of bare patches to replant, light shafts, and Otto the sea otter at the entrance.
-- Kelp (server) runs the meadows and nests; KelpLife (client) sways the kelp, swims the
-- turtles and fish, and tints the water green while you're inside.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KelpConfig = require(ReplicatedStorage.Shared.KelpConfig)
local WorldKit = require(script.Parent.WorldKit)
local ShopkeeperVisuals = require(script.Parent.ShopkeeperVisuals)

export type Patch = {
	meadow: string,
	index: number,
	base: BasePart, -- the mud (or seagrass) disc, holding the prompt
	prompt: ProximityPrompt,
	blades: { { part: BasePart, height: number, cf: CFrame } }, -- full-grown pose of each blade
}

export type Nest = { id: string, at: Vector3, prompt: ProximityPrompt }

export type KelpParts = {
	patches: { Patch },
	nests: { Nest },
	pearlSpots: { Vector3 }, -- for Collectibles, in the hidden glades
}

local KelpWorld = {}

local C = WorldKit.Colors
local part, prop, disc, bar = WorldKit.part, WorldKit.prop, WorldKit.disc, WorldKit.bar
local seaGrass, boulder, jellyLamp, surfaceLabel = WorldKit.seaGrass, WorldKit.boulder, WorldKit.jellyLamp, WorldKit.surfaceLabel
local UPRIGHT = WorldKit.UPRIGHT

local CENTER = KelpConfig.center
local FOREST_SAND = Color3.fromRGB(206, 200, 156)
local MUD = Color3.fromRGB(96, 78, 58)
local STIPE = Color3.fromRGB(120, 112, 44)
local BLADE_LOW = Color3.fromRGB(96, 160, 44)
local BLADE_HIGH = Color3.fromRGB(196, 230, 90) -- sunlit tops, like the concept art
local BLADDER = Color3.fromRGB(206, 186, 74)
local SEAGRASS = Color3.fromRGB(90, 176, 80)

-- A giant kelp: a holdfast of roots, a gently wavy stalk up toward the surface, a long
-- translucent blade with a gas bladder at every joint, and a spray of golden fronds on top.
-- Tagged for KelpLife, which sways it from the holdfast.
local function giantKelp(parent: Instance, base: Vector3, height: number, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "GiantKelp"
	local root = prop({ Name = "Holdfast", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), Position = base + Vector3.new(0, 0.6, 0), Color = Color3.fromRGB(86, 64, 40), Material = Enum.Material.Slate, Parent = model })
	for k = 1, 3 do
		local angle = k * 2.1 + rng:NextNumber(0, 1)
		prop({ Name = "Root", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Position = base + Vector3.new(math.cos(angle) * 1.4, 0.4, math.sin(angle) * 1.4), Color = Color3.fromRGB(96, 72, 46), Material = Enum.Material.Slate, Parent = model })
	end
	local segments = math.max(3, math.round(height / 8))
	local step = height / segments
	local phase = rng:NextNumber(0, math.pi * 2)
	local previous = base + Vector3.new(0, 1, 0)
	for i = 1, segments do
		local t = i / segments
		local point = base + Vector3.new(math.sin(i * 0.7 + phase) * 1.4, i * step, math.cos(i * 0.55 + phase) * 1.4)
		bar(model, "Stipe", previous, point, 0.55, STIPE:Lerp(BLADE_LOW, t * 0.5), Enum.Material.SmoothPlastic).CastShadow = false
		-- One long blade per joint, on alternating sides, angled up and out.
		local length = rng:NextNumber(7, 10.5)
		local spin = i * 2.4 + phase
		local blade = CFrame.new(point) * CFrame.Angles(0, spin, 0) * CFrame.Angles(0, 0, math.rad(-38)) * CFrame.new(0, length / 2, 0)
		prop({ Name = "Blade", Size = Vector3.new(0.14, length, rng:NextNumber(1.8, 2.6)), CFrame = blade, Color = BLADE_LOW:Lerp(BLADE_HIGH, t), Material = Enum.Material.SmoothPlastic, Transparency = 0.15, CastShadow = false, Parent = model })
		prop({ Name = "Bladder", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(point) * CFrame.Angles(0, spin, 0) * CFrame.new(0.5, 0, 0), Color = BLADDER, Material = Enum.Material.SmoothPlastic, CastShadow = false, Parent = model })
		previous = point
	end
	-- The canopy: golden fronds spreading out flat at the top.
	for k = 1, 4 do
		local spin = (k / 4) * math.pi * 2 + phase
		local frond = CFrame.new(previous) * CFrame.Angles(0, spin, 0) * CFrame.Angles(0, 0, math.rad(-72)) * CFrame.new(0, 4.5, 0)
		prop({ Name = "Frond", Size = Vector3.new(0.14, 9, 2.4), CFrame = frond, Color = BLADE_HIGH, Material = Enum.Material.SmoothPlastic, Transparency = 0.1, CastShadow = false, Parent = model })
	end
	model.PrimaryPart = root
	model:SetAttribute("Height", height)
	model:AddTag(KelpConfig.KELP_TAG)
	model.Parent = parent
	return model
end

-- A short, bushy kelp for the walls round the hidden glades.
local function wallKelp(parent: Instance, base: Vector3, rng: Random)
	local height = rng:NextNumber(16, 26)
	local model = giantKelp(parent, base, height, rng)
	model.Name = "WallKelp"
end

-- Distance from point p to the segment a-b, on the seabed.
local function distanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = (b - a) * Vector3.new(1, 0, 1)
	local ap = (p - a) * Vector3.new(1, 0, 1)
	local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (ap - ab * t).Magnitude
end

local function nearTrail(p: Vector3, margin: number): boolean
	local trail = KelpConfig.Trail
	for i = 1, #trail - 1 do
		if distanceToSegment(p, trail[i], trail[i + 1]) < margin then
			return true
		end
	end
	return false
end

-- A trail of faint glowing pebbles from a to b: easy to miss unless you're looking.
local function pebbleTrail(parent: Instance, a: Vector3, b: Vector3, rng: Random)
	local length = ((b - a) * Vector3.new(1, 0, 1)).Magnitude
	local direction = ((b - a) * Vector3.new(1, 0, 1)).Unit
	local side = Vector3.new(-direction.Z, 0, direction.X)
	for d = 0, length, 4.5 do
		local at = a + direction * d + side * rng:NextNumber(-1.2, 1.2)
		prop({ Name = "GlowPebble", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), Position = Vector3.new(at.X, 0.25, at.Z), Color = Color3.fromRGB(190, 255, 230), Material = Enum.Material.Neon, Transparency = 0.35, Parent = parent })
	end
end

-- A hidden glade: a ring of dense kelp and rocks with one narrow gap, the pebble trail
-- leading to it, and what's inside. Returns a pearl spot inside.
local function buildGlade(parent: Instance, glade: KelpConfig.Glade, rng: Random): Vector3
	local model = Instance.new("Model")
	model.Name = glade.name
	model.Parent = parent
	local wall = glade.radius + 3
	for k = 0, 23 do
		local angle = (k / 24) * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if out:Dot(glade.gap) < 0.9 then -- leave the gap open
			wallKelp(model, glade.at + out * (wall + rng:NextNumber(-1, 1.5)), rng)
			if k % 2 == 0 then
				boulder(model, glade.at + out * (wall + 3), rng:NextNumber(5, 8), rng)
			end
		end
	end
	disc(model, "GladeSand", glade.radius, 0.3, glade.at + Vector3.new(0, 0.15, 0), Color3.fromRGB(236, 230, 196), Enum.Material.Sand).CanCollide = false
	pebbleTrail(model, glade.from, glade.at + glade.gap * (wall + 2), rng)

	-- What each glade hides.
	if glade.id == "statue" then
		-- An old stone diver statue, half reclaimed by the sea.
		local stone = Color3.fromRGB(150, 160, 150)
		part({ Name = "Plinth", Size = Vector3.new(5, 2, 5), Position = glade.at + Vector3.new(0, 1, 0), Color = stone, Material = Enum.Material.Cobblestone, Parent = model })
		part({ Name = "StatueBody", Size = Vector3.new(2.8, 5, 1.8), Position = glade.at + Vector3.new(0, 4.5, 0), Color = stone, Material = Enum.Material.Slate, Parent = model })
		part({ Name = "StatueHelmet", Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 3.2, 3.2), Position = glade.at + Vector3.new(0, 8.4, 0), Color = stone, Material = Enum.Material.Slate, Parent = model })
		prop({ Name = "HelmetWindow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.8, 1.8), CFrame = CFrame.new(glade.at + Vector3.new(0, 8.4, -1.5)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(120, 230, 210), Material = Enum.Material.Neon, Transparency = 0.3, Parent = model })
		for k = 1, 5 do
			local angle = k * 1.25
			local anemone = glade.at + Vector3.new(math.cos(angle) * 7, 0, math.sin(angle) * 7)
			WorldKit.bigCoral(model, anemone, rng, 1.3)
		end
		seaGrass(model, glade.at + Vector3.new(2, 2, 1.5), rng, 0.8)
	elseif glade.id == "moonpool" then
		-- A pool of moonlight: white sand under a bright shaft, and a giant clam.
		prop({ Name = "Moonbeam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(110, 10, 10), CFrame = CFrame.new(glade.at + Vector3.new(0, 55, 0)) * UPRIGHT, Color = Color3.fromRGB(220, 245, 255), Material = Enum.Material.Neon, Transparency = 0.85, CastShadow = false, Parent = model })
		local clam = glade.at + Vector3.new(0, 0, 3)
		part({ Name = "GiantClamBottom", Size = Vector3.new(6, 1.2, 4.6), Position = clam + Vector3.new(0, 0.6, 0), Color = Color3.fromRGB(140, 120, 190), Material = Enum.Material.Marble, Parent = model })
		part({ Name = "GiantClamTop", Size = Vector3.new(6, 1.2, 4.6), CFrame = CFrame.new(clam + Vector3.new(0, 2.6, 2)) * CFrame.Angles(math.rad(-55), 0, 0), Color = Color3.fromRGB(140, 120, 190), Material = Enum.Material.Marble, Parent = model })
		-- The way in runs under a rock overhang.
		local mouth = glade.at + glade.gap * (wall + 8)
		for _, side in { -1, 1 } do
			boulder(model, mouth + Vector3.new(glade.gap.Z, 0, -glade.gap.X) * side * 7, 9, rng)
		end
		part({ Name = "Overhang", Size = Vector3.new(18, 4, 12), CFrame = CFrame.lookAt(mouth + Vector3.new(0, 9, 0), mouth + Vector3.new(0, 9, 0) + glade.gap) * CFrame.Angles(0.08, 0, 0.05), Color = C.STONE, Material = Enum.Material.Slate, Parent = model })
	else
		-- An old diver's camp: a brass helmet, a crate and a lantern.
		local brass = Color3.fromRGB(214, 170, 80)
		part({ Name = "DivingHelmet", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), Position = glade.at + Vector3.new(-2, 1.4, 0), Color = brass, Material = Enum.Material.Metal, Parent = model })
		prop({ Name = "HelmetPort", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.6, 1.6), CFrame = CFrame.new(glade.at + Vector3.new(-2, 1.5, -1.45)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(150, 220, 240), Material = Enum.Material.Glass, Parent = model })
		part({ Name = "Crate", Size = Vector3.new(3, 2.4, 2.4), CFrame = CFrame.new(glade.at + Vector3.new(3, 1.2, 1)) * CFrame.Angles(0, 0.4, 0), Color = Color3.fromRGB(150, 110, 80), Material = Enum.Material.WoodPlanks, Parent = model })
		jellyLamp(model, glade.at + Vector3.new(0, 0, -5), Color3.fromRGB(255, 200, 120), true)
	end
	return glade.at + Vector3.new(rng:NextNumber(-4, 4), 1.5, rng:NextNumber(-4, 4))
end

-- A sea turtle lying on the sand, flippers out.
local function restingTurtle(parent: Instance, at: Vector3, facing: number)
	local frame = CFrame.new(at) * CFrame.Angles(0, facing, 0)
	local shell = Color3.fromRGB(120, 110, 60)
	local skin = Color3.fromRGB(110, 150, 110)
	part({ Name = "TurtleShell", Size = Vector3.new(3.4, 1.4, 4.2), CFrame = frame * CFrame.new(0, 0.9, 0), Color = shell, Material = Enum.Material.Slate, Parent = parent })
	prop({ Name = "TurtleShellTop", Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 3.2, 3.2), CFrame = frame * CFrame.new(0, 0.9, 0), Color = shell:Lerp(Color3.new(1, 1, 1), 0.1), Material = Enum.Material.Slate, Parent = parent })
	prop({ Name = "TurtleHead", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), CFrame = frame * CFrame.new(0, 1, -2.6), Color = skin, Material = Enum.Material.SmoothPlastic, Parent = parent })
	for _, side in { -1, 1 } do
		prop({ Name = "Flipper", Size = Vector3.new(2.2, 0.25, 0.9), CFrame = frame * CFrame.new(side * 2, 0.5, -1) * CFrame.Angles(0, side * 0.5, 0), Color = skin, Material = Enum.Material.SmoothPlastic, Parent = parent })
		prop({ Name = "BackFlipper", Size = Vector3.new(1.2, 0.25, 0.7), CFrame = frame * CFrame.new(side * 1.3, 0.45, 1.8) * CFrame.Angles(0, -side * 0.6, 0), Color = skin, Material = Enum.Material.SmoothPlastic, Parent = parent })
	end
end

local function buildHabitat(parent: Instance, habitat: KelpConfig.Habitat, rng: Random): { Nest }
	local model = Instance.new("Model")
	model.Name = habitat.name
	model.Parent = parent
	disc(model, "HabitatSand", habitat.radius, 0.3, habitat.at + Vector3.new(0, 0.15, 0), Color3.fromRGB(240, 226, 180), Enum.Material.Sand).CanCollide = false
	local nests = {}
	for n = 1, habitat.nests do
		local angle = (n / habitat.nests) * math.pi * 2 + 0.4
		local at = habitat.at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * habitat.radius * 0.55
		local mound = part({ Name = "Nest", Shape = Enum.PartType.Ball, Size = Vector3.new(4.5, 4.5, 4.5), Position = at - Vector3.new(0, 1.3, 0), Color = Color3.fromRGB(226, 206, 160), Material = Enum.Material.Sand, Parent = model })
		for k = 1, 3 do
			prop({ Name = "Egg", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Position = at + Vector3.new(math.cos(k * 2.1) * 0.6, 0.95, math.sin(k * 2.1) * 0.6), Color = Color3.fromRGB(250, 248, 236), Material = Enum.Material.SmoothPlastic, Parent = model })
		end
		local id = habitat.id .. n
		local prompt = WorldKit.prompt(mound, "TurtleNest", "Guide a hatchling", habitat.name, KelpConfig.REACH - 2)
		prompt.HoldDuration = 1
		prompt:SetAttribute("NestId", id)
		table.insert(nests, { id = id, at = at, prompt = prompt })
	end
	-- A couple of turtles resting on the sand, and a cleaning-station rock.
	restingTurtle(model, habitat.at + Vector3.new(-4, 0, 3), rng:NextNumber(0, math.pi * 2))
	if habitat.nests > 3 then
		restingTurtle(model, habitat.at + Vector3.new(5, 0, -4), rng:NextNumber(0, math.pi * 2))
	end
	boulder(model, habitat.at + Vector3.new(0, 0, habitat.radius * 0.1), 6, rng)
	for _ = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		seaGrass(model, habitat.at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * habitat.radius * rng:NextNumber(0.75, 0.95), rng, 1.4)
	end
	local sign = part({ Name = "HabitatSign", Size = Vector3.new(6, 1.6, 0.3), CFrame = CFrame.lookAt(habitat.at + Vector3.new(0, 4.4, habitat.radius * 0.9), habitat.at + Vector3.new(0, 4.4, habitat.radius * 2)), Color = Color3.fromRGB(40, 90, 120), CanCollide = false, Parent = model })
	surfaceLabel(sign, Enum.NormalId.Front, habitat.name, Color3.fromRGB(200, 255, 200))
	part({ Name = "HabitatSignPost", Size = Vector3.new(0.4, 4, 0.4), Position = sign.Position - Vector3.new(0, 2.4, 0), Color = Color3.fromRGB(110, 84, 62), Material = Enum.Material.Wood, Parent = model })
	return nests
end

-- A seagrass meadow: a ring of bare mud patches (Kelp regrows them), with lush seagrass
-- already round the edge to show what it should look like.
local function buildMeadow(parent: Instance, meadow: KelpConfig.Meadow, rng: Random): { Patch }
	local model = Instance.new("Model")
	model.Name = meadow.name
	model.Parent = parent
	disc(model, "MeadowBed", meadow.radius, 0.25, meadow.at + Vector3.new(0, 0.12, 0), Color3.fromRGB(150, 140, 100), Enum.Material.Sand).CanCollide = false
	local patches = {}
	for index = 1, meadow.patches do
		local at = KelpConfig.patchPoint(meadow, index)
		local base = disc(model, "Patch", 2.4, 0.3, at + Vector3.new(0, 0.2, 0), MUD, Enum.Material.Mud)
		base.CanCollide = false
		base:SetAttribute("Meadow", meadow.id)
		base:SetAttribute("Index", index)
		base:SetAttribute("State", "bare")
		base:AddTag(KelpConfig.PATCH_TAG)
		local prompt = WorldKit.prompt(base, "SeagrassPatch", "Plant seagrass", meadow.name, KelpConfig.REACH - 2)
		prompt.HoldDuration = 1.2
		local blades = {}
		for k = 1, 7 do
			local height = rng:NextNumber(2.4, 4)
			local cf = CFrame.new(at + Vector3.new(rng:NextNumber(-1.6, 1.6), 0.3, rng:NextNumber(-1.6, 1.6)))
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25))
				* CFrame.new(0, height / 2, 0)
			local blade = prop({ Name = "SeagrassBlade", Size = Vector3.new(0.35, height, 0.12), CFrame = cf, Color = SEAGRASS:Lerp(Color3.fromRGB(170, 220, 90), rng:NextNumber(0, 0.4)), Material = Enum.Material.Grass, Transparency = 1, Parent = model })
			table.insert(blades, { part = blade, height = height, cf = cf })
		end
		table.insert(patches, { meadow = meadow.id, index = index, base = base, prompt = prompt, blades = blades })
	end
	for _ = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		seaGrass(model, meadow.at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * meadow.radius * rng:NextNumber(0.95, 1.2), rng, 1.3)
	end
	local sign = part({ Name = "MeadowSign", Size = Vector3.new(7, 1.6, 0.3), CFrame = CFrame.lookAt(meadow.at + Vector3.new(0, 4.4, -meadow.radius - 2), meadow.at + Vector3.new(0, 4.4, -meadow.radius - 10)), Color = Color3.fromRGB(40, 90, 120), CanCollide = false, Parent = model })
	surfaceLabel(sign, Enum.NormalId.Front, meadow.name, Color3.fromRGB(200, 255, 200))
	part({ Name = "MeadowSignPost", Size = Vector3.new(0.4, 4, 0.4), Position = sign.Position - Vector3.new(0, 2.4, 0), Color = Color3.fromRGB(110, 84, 62), Material = Enum.Material.Wood, Parent = model })
	return patches
end

function KelpWorld.build(root: Instance): KelpParts
	local rng = Random.new(4040)
	local folder = Instance.new("Folder")
	folder.Name = "KelpForest"
	folder.Parent = root
	local result: KelpParts = { patches = {}, nests = {}, pearlSpots = {} }

	-- Its own seabed (a touch higher than the main one, so they never z-fight where they meet)
	-- and its own patch of water surface, plus light shafts pouring down through the kelp.
	part({ Name = "KelpSeabed", Size = Vector3.new(470, 4, 480), Position = Vector3.new(CENTER.X, -1.95, CENTER.Z - 5), Color = FOREST_SAND, Material = Enum.Material.Sand, Parent = folder })
	prop({ Name = "KelpSurface", Size = Vector3.new(520, 2, 270), Position = Vector3.new(CENTER.X, 110, -635), Color = Color3.fromRGB(150, 225, 200), Material = Enum.Material.Neon, Transparency = 0.25, CastShadow = false, Parent = folder })
	for i = 1, 18 do
		local width = rng:NextNumber(6, 14)
		local at = if i <= 4 then KelpConfig.clearing.at + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12)) else CENTER + Vector3.new(rng:NextNumber(-180, 180), 0, rng:NextNumber(-180, 180))
		prop({
			Name = "SunShaft",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(120, width, width),
			CFrame = CFrame.new(at.X, 55, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(90) + rng:NextNumber(-0.18, 0.18)),
			Color = Color3.fromRGB(235, 255, 200),
			Material = Enum.Material.Neon,
			Transparency = if i <= 4 then 0.86 else 0.92,
			CastShadow = false,
			Parent = folder,
		})
	end

	-- The entrance: a sign between two driftwood posts, Otto on his rock, and a whirlpool.
	local entrance = KelpConfig.entrance
	local gate = Instance.new("Model")
	gate.Name = "Entrance"
	gate.Parent = folder
	for _, x in { -9, 9 } do
		part({ Name = "DriftwoodPost", Size = Vector3.new(1.4, 12, 1.4), CFrame = CFrame.new(entrance + Vector3.new(x, 6, 0)) * CFrame.Angles(0, 0, math.rad(x * 0.4)), Color = Color3.fromRGB(170, 150, 120), Material = Enum.Material.Wood, Parent = gate })
		giantKelp(gate, entrance + Vector3.new(x * 1.6, 0, -4), 40, rng)
	end
	local sign = part({ Name = "KelpForestSign", Size = Vector3.new(18, 3.4, 0.6), Position = entrance + Vector3.new(0, 11.5, 0), Color = Color3.fromRGB(40, 90, 70), CanCollide = false, Parent = gate })
	surfaceLabel(sign, Enum.NormalId.Back, "KELP FOREST", Color3.fromRGB(210, 255, 150)) -- faces the lagoon (+Z)
	surfaceLabel(sign, Enum.NormalId.Front, "STARTER LAGOON", Color3.fromRGB(180, 245, 255))
	local ottoAt = entrance + Vector3.new(12, 0, 6)
	local rock = disc(gate, "OttoRock", 2.8, 1.6, ottoAt + Vector3.new(0, 0.8, 0), C.STONE, Enum.Material.Slate)
	WorldKit.prompt(rock, "Otto", "Talk", "Otto the Ranger", 12)
	ShopkeeperVisuals.build("Otto", CFrame.lookAt(ottoAt + Vector3.new(0, 1.6, 0), Vector3.new(entrance.X, 1.6, entrance.Z + 20))).Parent = gate
	WorldKit.teleportPad(gate, entrance + Vector3.new(-12, 0, 8), "TeleportShops", "Go to the shops")

	-- The main trail, a little paler than the forest floor.
	local trail = Instance.new("Model")
	trail.Name = "Trail"
	trail.Parent = folder
	for i = 1, #KelpConfig.Trail - 1 do
		WorldKit.path(trail, KelpConfig.Trail[i] + Vector3.new(0, 0.05, 0), KelpConfig.Trail[i + 1] + Vector3.new(0, 0.05, 0), 9, rng)
	end
	-- The sunlit clearing: open sand, a few rocks and lush seagrass.
	local clearing = KelpConfig.clearing
	disc(folder, "ClearingSand", clearing.radius, 0.3, clearing.at + Vector3.new(0, 0.15, 0), Color3.fromRGB(240, 232, 196), Enum.Material.Sand).CanCollide = false
	for k = 1, 4 do
		local angle = k * 1.6
		boulder(folder, clearing.at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (clearing.radius - 3), rng:NextNumber(3, 6), rng)
	end

	local places = Instance.new("Model")
	places.Name = "Places"
	places.Parent = folder
	for _, glade in KelpConfig.Glades do
		table.insert(result.pearlSpots, buildGlade(places, glade, rng))
	end
	for _, habitat in KelpConfig.Habitats do
		for _, nest in buildHabitat(places, habitat, rng) do
			table.insert(result.nests, nest)
		end
	end
	for _, meadow in KelpConfig.Meadows do
		for _, patch in buildMeadow(places, meadow, rng) do
			table.insert(result.patches, patch)
		end
	end

	-- The groves: giant kelp everywhere that isn't trail, clearing, glade, habitat or meadow.
	local groves = Instance.new("Model")
	groves.Name = "KelpGroves"
	groves.Parent = folder
	local planted: { Vector3 } = {}
	local function clear(p: Vector3): boolean
		if not KelpConfig.inForest(p) or (p - CENTER).Magnitude > KelpConfig.radius - 6 then
			return false
		end
		if nearTrail(p, 8) or (p - entrance).Magnitude < 26 or (p - clearing.at).Magnitude < clearing.radius + 6 then
			return false
		end
		for _, glade in KelpConfig.Glades do
			if (p - glade.at).Magnitude < glade.radius + 9 or distanceToSegment(p, glade.from, glade.at) < 6 then
				return false
			end
		end
		for _, habitat in KelpConfig.Habitats do
			if (p - habitat.at).Magnitude < habitat.radius + 6 then
				return false
			end
		end
		for _, meadow in KelpConfig.Meadows do
			if (p - meadow.at).Magnitude < meadow.radius + 7 then
				return false
			end
		end
		for _, other in planted do
			if (p - other).Magnitude < 10 then
				return false
			end
		end
		return true
	end
	for _ = 1, 900 do
		if #planted >= 70 then
			break
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local p = CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.sqrt(rng:NextNumber()) * KelpConfig.radius
		if clear(p) then
			table.insert(planted, p)
			giantKelp(groves, p, rng:NextNumber(45, 95), rng)
			if #planted % 3 == 0 then
				seaGrass(groves, p + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)), rng, 1.5)
			end
			if #planted % 7 == 0 then
				boulder(groves, p + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), rng:NextNumber(4, 8), rng)
			end
		end
	end
	return result
end

return KelpWorld
