--!nonstrict
-- Builds the Abyss at server start (layout in AbyssConfig): the road south from the lagoon,
-- the shelf and the Pressure Gate, the pit with its glowing ramp, and down on the floor the
-- bioluminescent coral, giant glowing mushrooms, crystal formations, the Crystal Spire, the
-- giant brain coral and Lumi's seed stall. Everything lives under Workspace.Abyss.
-- The darkness itself is the client's (AbyssLife): the parts here are lit by their own glow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local AbyssConfig = require(ReplicatedStorage.Shared.AbyssConfig)
local Kit = require(script.Parent.WorldKit)

local AbyssWorld = {}

local part, prop, bar = Kit.part, Kit.prop, Kit.bar
local UPRIGHT = Kit.UPRIGHT
local FLOOR = AbyssConfig.FLOOR
local PIT = AbyssConfig.Pit
local SHELF = AbyssConfig.Shelf

local ROCK = Color3.fromRGB(38, 46, 78) -- the pit's dark blue-black rock
local ROCK_LIGHT = Color3.fromRGB(62, 72, 112)
local SHELF_SAND = Color3.fromRGB(96, 110, 146)
local FLOOR_SAND = Color3.fromRGB(44, 52, 92)
-- The art's glow colours: violet, cyan, teal-green and magenta.
local GLOWS = {
	Color3.fromRGB(160, 90, 255),
	Color3.fromRGB(70, 200, 255),
	Color3.fromRGB(80, 255, 190),
	Color3.fromRGB(255, 100, 220),
	Color3.fromRGB(110, 130, 255),
}

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function glow(rng: Random): Color3
	return GLOWS[rng:NextInteger(1, #GLOWS)]
end

local function motes(parent: BasePart, color: Color3, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.3, 0)
	e.Lifetime = NumberRange.new(3, 5)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = rate
	e.Parent = parent
end

---------------------------------------------------------------------------------------------
-- Glowing things

-- Branching coral with bright tips, like the violet and teal stands in the art.
local function branchCoral(parent: Instance, position: Vector3, rng: Random, color: Color3, scale: number)
	for _ = 1, rng:NextInteger(5, 8) do
		local height = rng:NextNumber(2.5, 5) * scale
		local base = CFrame.new(position) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.6, 0.6))
		prop({ Name = "Branch", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 0.7 * scale, 0.7 * scale), CFrame = base * CFrame.new(0, height / 2, 0) * UPRIGHT, Color = color:Lerp(Color3.new(0, 0, 0), 0.35), Material = Enum.Material.SmoothPlastic, Parent = parent })
		prop({ Name = "BranchTip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9) * scale, CFrame = base * CFrame.new(0, height, 0), Color = color, Material = Enum.Material.Neon, Parent = parent })
	end
end

-- A dome of brain coral with a shimmering glow over it. `lit` adds a light (they're limited).
local function brainCoral(parent: Instance, position: Vector3, size: number, color: Color3, lit: boolean)
	prop({ Name = "Brain", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.75, size), CFrame = CFrame.new(position + Vector3.new(0, size * 0.25, 0)), Color = color:Lerp(Color3.new(0, 0, 0), 0.3), Material = Enum.Material.Pebble, Parent = parent })
	local sheen = prop({ Name = "BrainGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(size + 0.4, size * 0.75 + 0.3, size + 0.4), CFrame = CFrame.new(position + Vector3.new(0, size * 0.25, 0)), Color = color, Material = Enum.Material.ForceField, Parent = parent })
	if lit then
		light(sheen, color, size * 1.6, 1.4)
	end
end

-- A glowing mushroom: pale stem, a domed cap and bright gills underneath.
local function mushroom(parent: Instance, position: Vector3, height: number, radius: number, color: Color3, lit: boolean)
	prop({ Name = "MushroomStem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 0.35, radius * 0.35), CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * UPRIGHT, Color = Color3.fromRGB(190, 180, 230), Material = Enum.Material.SmoothPlastic, Parent = parent })
	prop({ Name = "MushroomCap", Shape = Enum.PartType.Ball, Size = Vector3.new(radius * 2, radius * 0.8, radius * 2), CFrame = CFrame.new(position + Vector3.new(0, height + radius * 0.15, 0)), Color = color:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.SmoothPlastic, Parent = parent })
	local gills = prop({ Name = "MushroomGills", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, radius * 1.8, radius * 1.8), CFrame = CFrame.new(position + Vector3.new(0, height - 0.1, 0)) * UPRIGHT, Color = color, Material = Enum.Material.Neon, Parent = parent })
	-- Glowing spots on the cap.
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		prop({ Name = "CapSpot", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5) * radius * 0.6, CFrame = CFrame.new(position + Vector3.new(math.cos(a) * radius * 0.6, height + radius * 0.4, math.sin(a) * radius * 0.6)), Color = Color3.fromRGB(230, 220, 255), Material = Enum.Material.Neon, Parent = parent })
	end
	if lit then
		light(gills, color, radius * 4, 1.6)
	end
end

-- A cluster of crystal shards: see-through glass round a glowing core.
local function crystals(parent: Instance, position: Vector3, size: number, rng: Random, color: Color3, lit: boolean)
	for k = 1, rng:NextInteger(4, 7) do
		local h = size * rng:NextNumber(0.5, 1) * (if k == 1 then 1.3 else 1)
		local w = size * rng:NextNumber(0.14, 0.24)
		local cf = CFrame.new(position + Vector3.new(rng:NextNumber(-0.3, 0.3) * size, 0, rng:NextNumber(-0.3, 0.3) * size))
			* CFrame.Angles(rng:NextNumber(-0.45, 0.45), rng:NextNumber(0, math.pi), rng:NextNumber(-0.45, 0.45))
			* CFrame.new(0, h / 2, 0)
		part({ Name = "Crystal", Size = Vector3.new(w, h, w), CFrame = cf * CFrame.Angles(0, math.rad(45), 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.25), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
		local core = prop({ Name = "CrystalCore", Size = Vector3.new(w * 0.45, h * 0.85, w * 0.45), CFrame = cf * CFrame.Angles(0, math.rad(45), 0), Color = color, Material = Enum.Material.Neon, Parent = parent })
		if k == 1 and lit then
			light(core, color, size * 3, 1.4)
		end
	end
end

-- A sea anemone with glowing tentacles.
local function anemone(parent: Instance, position: Vector3, rng: Random, color: Color3)
	prop({ Name = "AnemoneBase", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 1.6, 2.6), CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)), Color = color:Lerp(Color3.new(0, 0, 0), 0.45), Material = Enum.Material.SmoothPlastic, Parent = parent })
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		local base = CFrame.new(position + Vector3.new(math.cos(a) * 0.7, 1.1, math.sin(a) * 0.7)) * CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5)
		prop({ Name = "Tentacle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 0.3, 0.3), CFrame = base * CFrame.new(0, 1.2, 0) * UPRIGHT, Color = color, Material = Enum.Material.Neon, Parent = parent })
	end
end

-- Tall kelp with glowing bulbs.
local function glowKelp(parent: Instance, position: Vector3, rng: Random, color: Color3)
	for _ = 1, 3 do
		local height = rng:NextNumber(10, 22)
		local base = CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, math.pi), rng:NextNumber(-0.12, 0.12))
		prop({ Name = "DeepKelp", Size = Vector3.new(0.6, height, 0.15), CFrame = base * CFrame.new(0, height / 2, 0), Color = Color3.fromRGB(40, 90, 110), Material = Enum.Material.SmoothPlastic, Parent = parent })
		for y = 3, height, 3.5 do
			prop({ Name = "KelpBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = base * CFrame.new(0.4, y, 0), Color = color, Material = Enum.Material.Neon, Parent = parent })
		end
	end
end

-- A patch of mixed glowing life round a point.
local function glowPatch(parent: Instance, center: Vector3, spread: number, rng: Random, count: number)
	for i = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = math.sqrt(rng:NextNumber()) * spread
		local p = center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local color = glow(rng)
		local pick = i % 5
		if pick == 0 then
			brainCoral(parent, p, rng:NextNumber(3, 6), color, false)
		elseif pick == 1 or pick == 2 then
			branchCoral(parent, p, rng, color, rng:NextNumber(0.8, 1.4))
		elseif pick == 3 then
			anemone(parent, p, rng, color)
		else
			crystals(parent, p, rng:NextNumber(2, 4), rng, color, false)
		end
	end
end

---------------------------------------------------------------------------------------------
-- The places

local function buildGround(root: Instance, rng: Random)
	local m = model(root, "Ground")
	local cx = (PIT.minX + PIT.maxX) / 2
	local cz = (PIT.minZ + PIT.maxZ) / 2
	local pw, pd = PIT.maxX - PIT.minX, PIT.maxZ - PIT.minZ
	-- The shelf: four slabs at seabed height round the pit's hole.
	local function slab(minX: number, maxX: number, minZ: number, maxZ: number)
		part({ Name = "Shelf", Size = Vector3.new(maxX - minX, 4, maxZ - minZ), Position = Vector3.new((minX + maxX) / 2, -2, (minZ + maxZ) / 2), Color = SHELF_SAND, Material = Enum.Material.Sand, Parent = m })
	end
	slab(SHELF.minX, SHELF.maxX, SHELF.minZ, PIT.minZ)
	slab(SHELF.minX, SHELF.maxX, PIT.maxZ, SHELF.maxZ)
	slab(SHELF.minX, PIT.minX, PIT.minZ, PIT.maxZ)
	slab(PIT.maxX, SHELF.maxX, PIT.minZ, PIT.maxZ)
	-- The pit: its floor, and walls from the floor up to the shelf.
	part({ Name = "PitFloor", Size = Vector3.new(pw, 6, pd), Position = Vector3.new(cx, FLOOR - 3, cz), Color = FLOOR_SAND, Material = Enum.Material.Sand, Parent = m })
	local depth = -FLOOR
	local walls = {
		{ Vector3.new(pw + 20, depth, 10), Vector3.new(cx, FLOOR / 2, PIT.minZ - 5) },
		{ Vector3.new(pw + 20, depth, 10), Vector3.new(cx, FLOOR / 2, PIT.maxZ + 5) },
		{ Vector3.new(10, depth, pd), Vector3.new(PIT.minX - 5, FLOOR / 2, cz) },
		{ Vector3.new(10, depth, pd), Vector3.new(PIT.maxX + 5, FLOOR / 2, cz) },
	}
	for _, w in walls do
		part({ Name = "PitWall", Size = w[1], Position = w[2], Color = ROCK, Material = Enum.Material.Slate, Parent = m })
	end
	-- Rough the walls up: rock lumps along their foot and face, glowing veins and coral on them.
	local function alongWalls(step: number, fn: (Vector3, Vector3) -> ())
		for x = PIT.minX + 6, PIT.maxX - 6, step do
			fn(Vector3.new(x, 0, PIT.minZ), Vector3.new(0, 0, 1))
			fn(Vector3.new(x, 0, PIT.maxZ), Vector3.new(0, 0, -1))
		end
		for z = PIT.minZ + 6, PIT.maxZ - 6, step do
			fn(Vector3.new(PIT.minX, 0, z), Vector3.new(1, 0, 0))
			fn(Vector3.new(PIT.maxX, 0, z), Vector3.new(-1, 0, 0))
		end
	end
	alongWalls(9, function(edge, inward)
		local s = rng:NextNumber(7, 13)
		local y = rng:NextNumber(FLOOR, -8)
		-- Keep the ramp (north wall, x 10..130) clear.
		if not (inward.Z > 0 and edge.X > 0 and edge.X < 140 and y > FLOOR + 4) then
			part({ Name = "WallRock", Size = Vector3.new(s, s * 0.8, s), CFrame = CFrame.new(edge + inward * (s * 0.15) + Vector3.new(0, y, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), Color = ROCK:Lerp(ROCK_LIGHT, rng:NextNumber(0, 0.6)), Material = Enum.Material.Slate, Parent = m })
		end
	end)
	alongWalls(14, function(edge, inward)
		local color = glow(rng)
		local a = edge + inward * 0.4 + Vector3.new(0, rng:NextNumber(FLOOR + 6, -6), 0)
		local side = Vector3.new(inward.Z, 0, -inward.X)
		bar(m, "Vein", a, a + side * rng:NextNumber(-6, 6) + Vector3.new(0, rng:NextNumber(4, 10), 0), 0.35, color, Enum.Material.Neon)
		if rng:NextNumber() < 0.5 then
			branchCoral(m, edge + inward * 5 + Vector3.new(0, FLOOR, 0), rng, color, 1.2)
		end
	end)
	-- A dark rim of boulders round the outside of the shelf.
	for i = 1, 36 do
		local onX = i % 2 == 0
		local x = if onX then rng:NextNumber(SHELF.minX, SHELF.maxX) else (if i % 4 == 1 then SHELF.minX + 8 else SHELF.maxX - 8)
		local z = if onX then (if i % 4 == 0 then SHELF.maxZ - 8 else SHELF.minZ + 6) else rng:NextNumber(SHELF.minZ, SHELF.maxZ)
		if math.abs(x - AbyssConfig.roadX) > 30 or z > SHELF.minZ + 20 then
			Kit.boulder(m, Vector3.new(x, 0, z), rng:NextNumber(10, 20), rng)
		end
	end
	-- Glow scattered over the shelf, thicker near the pit's edge.
	for _ = 1, 26 do
		local x, z = rng:NextNumber(SHELF.minX + 15, SHELF.maxX - 15), rng:NextNumber(SHELF.minZ + 15, SHELF.maxZ - 15)
		local nearRoad = math.abs(x - AbyssConfig.roadX) < 16 and z < PIT.minZ
		local inPit = x > PIT.minX - 6 and x < PIT.maxX + 6 and z > PIT.minZ - 6 and z < PIT.maxZ + 6
		if not nearRoad and not inPit then
			glowPatch(m, Vector3.new(x, 0, z), 5, rng, 4)
		end
	end
end

-- The road from the lagoon, with glowing jellyfish lamps that turn bluer as it nears the gate.
local function buildRoad(root: Instance, rng: Random)
	local m = model(root, "Road")
	local x = AbyssConfig.roadX
	Kit.path(m, Vector3.new(x, 0, AbyssConfig.roadFromZ), Vector3.new(x, 0, AbyssConfig.gate.Z - 6), 12, rng)
	for i, z in { 230, 290, 350, 410, 465 } do
		local color = Color3.fromRGB(90, 220, 240):Lerp(GLOWS[1], (i - 1) / 4)
		Kit.jellyLamp(m, Vector3.new(x + (if i % 2 == 0 then -9 else 9), 0, z), color, true)
	end
end

-- The Pressure Gate: two crystal pillars, a lintel with the sign, and a shimmering membrane
-- across the way (it doesn't block anyone; the server turns locked divers back).
local function buildGate(root: Instance, rng: Random)
	local m = model(root, "PressureGate")
	local g = AbyssConfig.gate
	for _, side in { -1, 1 } do
		local base = Vector3.new(g.X + side * 11, 0, g.Z)
		part({ Name = "GatePillar", Size = Vector3.new(4, 20, 4), CFrame = CFrame.new(base + Vector3.new(0, 10, 0)), Color = ROCK_LIGHT, Material = Enum.Material.Slate, Parent = m })
		crystals(m, base + Vector3.new(side * 4, 0, 2), 7, rng, GLOWS[if side < 0 then 1 else 2], true)
	end
	part({ Name = "GateLintel", Size = Vector3.new(28, 3, 5), CFrame = CFrame.new(g + Vector3.new(0, 21.5, 0)), Color = ROCK, Material = Enum.Material.Slate, Parent = m })
	local sign = part({ Name = "GateSign", Size = Vector3.new(22, 4.5, 0.6), CFrame = CFrame.new(g + Vector3.new(0, 17, -2.8)), Color = Color3.fromRGB(16, 20, 44), CanCollide = false, Parent = m })
	-- The sign faces north (-Z, the Front face), up the road to the lagoon.
	local label = Kit.surfaceLabel(sign, Enum.NormalId.Front, "THE ABYSS", Color3.fromRGB(170, 140, 255))
	label.Size = UDim2.fromScale(1, 0.62)
	local sub = Kit.surfaceLabel(sign, Enum.NormalId.Front, `Exploration Level {AbyssConfig.Unlock.exploration} or Reef Health {AbyssConfig.Unlock.reefHealth} to enter`, Color3.fromRGB(150, 220, 255))
	sub.Position = UDim2.fromScale(0, 0.62)
	sub.Size = UDim2.fromScale(1, 0.34)
	sub.Parent.Name = "SubGui"
	local membrane = prop({ Name = "Membrane", Size = Vector3.new(18, 19, 0.4), CFrame = CFrame.new(g + Vector3.new(0, 9.5, 0)), Color = GLOWS[5], Material = Enum.Material.ForceField, Parent = m })
	motes(membrane, Color3.fromRGB(170, 160, 255), 8)
end

-- The ramp down the pit's north wall, lit by glowing posts along its open side.
local function buildRamp(root: Instance)
	local m = model(root, "Ramp")
	local r = AbyssConfig.Ramp
	local length = (r.bottom - r.top).Magnitude
	local mid = (r.top + r.bottom) / 2
	part({ Name = "RampPath", Size = Vector3.new(r.width, 2, length), CFrame = CFrame.lookAt(mid, r.bottom) * CFrame.new(0, -1, 0), Color = ROCK_LIGHT, Material = Enum.Material.Slate, Parent = m })
	-- A lip on the open side so nobody slides off by accident, and glowing posts.
	local side = Vector3.new(0, 0, r.width / 2)
	part({ Name = "RampLip", Size = Vector3.new(1, 1.2, length), CFrame = CFrame.lookAt(mid + side, r.bottom + side) * CFrame.new(0, 0.3, 0), Color = ROCK, Material = Enum.Material.Slate, Parent = m })
	local steps = 8
	for k = 0, steps do
		local p = r.top:Lerp(r.bottom, k / steps) + side
		local color = GLOWS[k % #GLOWS + 1]
		prop({ Name = "RampPost", Size = Vector3.new(0.6, 4, 0.6), CFrame = CFrame.new(p + Vector3.new(0, 2, 0)), Color = ROCK, Material = Enum.Material.Slate, Parent = m })
		local orb = prop({ Name = "RampOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(p + Vector3.new(0, 4.4, 0)), Color = color, Material = Enum.Material.Neon, Parent = m })
		if k % 2 == 0 then
			light(orb, color, 16, 1.2)
		end
	end
	-- The landing at the bottom.
	part({ Name = "Landing", Size = Vector3.new(16, 1, 20), CFrame = CFrame.new(r.bottom + Vector3.new(4, 0.5, 6)), Color = ROCK_LIGHT, Material = Enum.Material.Slate, Parent = m })
end

-- The floor of the pit: the Crystal Spire, the giant brain coral, the mushroom forest, the
-- jellyfish garden, and glowing life everywhere else.
local function buildFloor(root: Instance, rng: Random)
	local m = model(root, "PitFloorLife")
	local P = AbyssConfig.Places
	-- The Crystal Spire.
	local spire = model(m, "CrystalSpire")
	for k = 1, 9 do
		local a = k / 9 * math.pi * 2
		local h = if k == 1 then 42 else rng:NextNumber(14, 30)
		local d = if k == 1 then 0 else rng:NextNumber(3, 7)
		local w = if k == 1 then 6 else rng:NextNumber(2.5, 4.5)
		local color = GLOWS[k % 2 + 1]
		local cf = CFrame.new(P.spire + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)) * CFrame.Angles(math.cos(a) * d * 0.05, a, math.sin(a) * d * 0.05) * CFrame.new(0, h / 2, 0)
		part({ Name = "SpireShard", Size = Vector3.new(w, h, w), CFrame = cf * CFrame.Angles(0, math.rad(45), 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Material = Enum.Material.Glass, Transparency = 0.3, Parent = spire })
		local core = prop({ Name = "SpireCore", Size = Vector3.new(w * 0.4, h * 0.9, w * 0.4), CFrame = cf * CFrame.Angles(0, math.rad(45), 0), Color = color, Material = Enum.Material.Neon, Parent = spire })
		if k == 1 then
			light(core, Color3.fromRGB(150, 160, 255), 60, 2)
			motes(core, Color3.fromRGB(200, 210, 255), 14)
		end
	end
	glowPatch(spire, P.spire, 16, rng, 14)

	-- The giant brain coral (the art's centrepiece).
	brainCoral(m, P.brain, 26, GLOWS[2], true)
	brainCoral(m, P.brain + Vector3.new(15, 0, -9), 10, GLOWS[1], true)
	glowPatch(m, P.brain, 22, rng, 16)

	-- The mushroom forest.
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local d = if k == 1 then 0 else rng:NextNumber(8, 20)
		local h = if k == 1 then 24 else rng:NextNumber(7, 18)
		mushroom(m, P.mushrooms + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), h, h * 0.42, if k % 2 == 0 then GLOWS[1] else GLOWS[4], k <= 4)
	end
	glowPatch(m, P.mushrooms, 24, rng, 12)

	-- The jellyfish garden: glowing kelp and anemones where the jellyfish gather.
	for _ = 1, 10 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(2, 20)
		glowKelp(m, P.jellies + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), rng, glow(rng))
	end
	glowPatch(m, P.jellies, 20, rng, 14)

	-- Crystal formations and coral over the rest of the floor.
	local keepClear = { { P.spire, 20 }, { P.brain, 24 }, { P.mushrooms, 26 }, { P.jellies, 24 }, { P.shop, 18 }, { P.pad, 10 }, { AbyssConfig.Ramp.bottom, 16 } }
	local function clear(p: Vector3): boolean
		for _, k in keepClear do
			if ((p - k[1]) * Vector3.new(1, 0, 1)).Magnitude < k[2] then
				return false
			end
		end
		return true
	end
	for i = 1, 70 do
		local p = Vector3.new(rng:NextNumber(PIT.minX + 8, PIT.maxX - 8), FLOOR, rng:NextNumber(PIT.minZ + 18, PIT.maxZ - 8))
		if clear(p) then
			if i % 7 == 0 then
				crystals(m, p, rng:NextNumber(6, 12), rng, glow(rng), i % 14 == 0)
			elseif i % 11 == 0 then
				mushroom(m, p, rng:NextNumber(5, 10), rng:NextNumber(2.5, 4), glow(rng), false)
			else
				glowPatch(m, p, rng:NextNumber(4, 8), rng, rng:NextInteger(3, 6))
			end
		end
	end
	-- Faint violet light falling from far above, like the art.
	for _ = 1, 6 do
		prop({ Name = "DeepLightShaft", Shape = Enum.PartType.Cylinder, Size = Vector3.new(110, rng:NextNumber(8, 16), rng:NextNumber(8, 16)), CFrame = CFrame.new(rng:NextNumber(PIT.minX, PIT.maxX), 10, rng:NextNumber(PIT.minZ, PIT.maxZ)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(90) + rng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(150, 120, 255), Material = Enum.Material.Neon, Transparency = 0.93, CastShadow = false, Parent = m })
	end
end

-- Lumi's stall: a rock counter set with crystals, a sign, and Lumi the lanternfish, who sells
-- the abyssal coral (AbyssPanel; the server's Abyss module sells).
local function buildShop(root: Instance, rng: Random)
	local m = model(root, "LumisStall")
	local at = AbyssConfig.Places.shop
	local frame = CFrame.lookAt(at, at + Vector3.new(-1, 0, 0)) -- the counter faces west, into the pit
	local counter = part({ Name = "Counter", Size = Vector3.new(14, 4, 5), CFrame = frame * CFrame.new(0, 2, 0), Color = ROCK_LIGHT, Material = Enum.Material.Slate, Parent = m })
	prop({ Name = "CounterGlow", Size = Vector3.new(14.2, 0.3, 5.2), CFrame = frame * CFrame.new(0, 4, 0), Color = GLOWS[3], Material = Enum.Material.Neon, Parent = m })
	local p = Kit.prompt(counter, "AbyssShop", "Browse deep seeds", "Lumi's Deep Seeds", 12)
	p.Name = "StandPrompt"
	local sign = part({ Name = "Sign", Size = Vector3.new(16, 3.4, 0.5), CFrame = frame * CFrame.new(0, 13, 3), Color = Color3.fromRGB(16, 20, 44), CanCollide = false, Parent = m })
	Kit.surfaceLabel(sign, Enum.NormalId.Front, "LUMI'S DEEP SEEDS", Color3.fromRGB(140, 255, 220))
	for _, x in { -7.5, 7.5 } do
		part({ Name = "Post", Size = Vector3.new(1.2, 12, 1.2), CFrame = frame * CFrame.new(x, 6, 3), Color = ROCK, Material = Enum.Material.Slate, Parent = m })
		crystals(m, (frame * CFrame.new(x * 1.3, 0, 0)).Position, 5, rng, GLOWS[if x < 0 then 1 else 2], true)
	end
	-- Seed samples glowing on the counter.
	for i, seedId in AbyssConfig.SHOP_SEEDS do
		local seed = ReefConfig.Seeds[seedId]
		prop({ Name = "Sample", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = frame * CFrame.new(-4 + i * 2, 4.8, -1), Color = seed and seed.color or GLOWS[i], Material = Enum.Material.Neon, Parent = m })
	end
	AbyssWorld.buildLumi(m, frame * CFrame.new(-3, 4, 1.2))
	Kit.teleportPad(m, AbyssConfig.Places.pad, "TeleportShops", "Go to the shops")
end

-- Lumi: a round lanternfish with a glowing lure and big friendly eyes, tagged as a shopkeeper
-- (ReefConfig.Shopkeepers.Abyss). `base` is where Lumi floats, facing the players (-Z).
function AbyssWorld.buildLumi(parent: Instance, base: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Lumi"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local rootPart = prop({ Name = "Root", Size = Vector3.one, CFrame = base, Transparency = 1, Parent = m })
	m.PrimaryPart = rootPart
	local skin = Color3.fromRGB(60, 70, 130)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		return prop({ Name = name, Size = size, CFrame = base * offset, Color = color, Material = material or Enum.Material.SmoothPlastic, Shape = shape or Enum.PartType.Block, Parent = m })
	end
	local BALL = Enum.PartType.Ball
	piece("Head", Vector3.new(3.6, 3.2, 4), CFrame.new(0, 2, 0), skin, nil, BALL)
	piece("Belly", Vector3.new(2.6, 2, 3), CFrame.new(0, 1.4, -0.4), Color3.fromRGB(120, 140, 220), nil, BALL)
	for _, side in { -1, 1 } do
		piece("Eye", Vector3.new(1.2, 1.2, 1.2), CFrame.new(side * 0.9, 2.6, -1.5), Color3.new(1, 1, 1), nil, BALL)
		piece("Pupil", Vector3.new(0.6, 0.6, 0.6), CFrame.new(side * 0.9, 2.6, -2.05), Color3.fromRGB(20, 20, 40), nil, BALL)
		piece("Fin", Vector3.new(0.2, 1.4, 1.2), CFrame.new(side * 1.9, 1.8, 0.3) * CFrame.Angles(0, 0, side * 0.5), GLOWS[1], Enum.Material.Neon)
		for k = 1, 3 do
			piece("SideLight", Vector3.new(0.3, 0.3, 0.3), CFrame.new(side * 1.65, 1.4, -0.8 + k * 0.6), GLOWS[3], Enum.Material.Neon, BALL)
		end
	end
	piece("Smile", Vector3.new(1.2, 0.15, 0.1), CFrame.new(0, 1.5, -1.95), Color3.fromRGB(20, 20, 40))
	piece("Tail", Vector3.new(0.3, 2.4, 1.6), CFrame.new(0, 2, 2.6), GLOWS[1], Enum.Material.Neon)
	-- The lure: a stalk curling up and forward to a glowing bulb.
	bar(m, "LureStalk", (base * CFrame.new(0, 3.5, -0.6)).Position, (base * CFrame.new(0, 5.2, -2.2)).Position, 0.2, skin, Enum.Material.SmoothPlastic)
	local bulb = piece("Lure", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 5.2, -2.4), Color3.fromRGB(160, 255, 230), Enum.Material.Neon, BALL)
	light(bulb, Color3.fromRGB(150, 255, 230), 18, 2)
	m.Parent = parent
	m:SetAttribute("Shopkeeper", "Abyss")
	m:AddTag(ReefConfig.SHOPKEEPER_TAG)
	return m
end

-- Air pockets (AbyssConfig.AirPockets): a ring of glowing vents on the floor and a column of
-- big bubbles rising out of them, so divers can see where their air refills.
local function buildAirPockets(root: Instance)
	local m = model(root, "AirPockets")
	for _, pocket in AbyssConfig.AirPockets do
		local base = pocket.position
		local ring = prop({ Name = "AirRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, pocket.radius * 2, pocket.radius * 2), CFrame = CFrame.new(base + Vector3.new(0, 0.15, 0)) * UPRIGHT, Color = Color3.fromRGB(150, 235, 255), Material = Enum.Material.ForceField, Parent = m })
		ring.Transparency = 0.2
		for i = 1, 3 do
			local a = i / 3 * math.pi * 2
			local vent = part({ Name = "AirVent", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2.2, 2.2), CFrame = CFrame.new(base + Vector3.new(math.cos(a) * 3, 0.4, math.sin(a) * 3)) * UPRIGHT, Color = ROCK_LIGHT, Material = Enum.Material.Basalt, Parent = m })
			prop({ Name = "VentGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.6, 1.6), CFrame = vent.CFrame * CFrame.new(0.42, 0, 0), Color = Color3.fromRGB(170, 240, 255), Material = Enum.Material.Neon, Parent = m })
		end
		-- The column: an invisible disc that sends big bubbles straight up to the shelf.
		local emitter = prop({ Name = "AirColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 6, 6), CFrame = CFrame.new(base + Vector3.new(0, 1, 0)) * UPRIGHT, Transparency = 1, Parent = m })
		local bubbles = Instance.new("ParticleEmitter")
		bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		bubbles.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255))
		bubbles.LightEmission = 0.6
		bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
		bubbles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) })
		bubbles.Lifetime = NumberRange.new(5, 7)
		bubbles.Speed = NumberRange.new(7, 10)
		bubbles.SpreadAngle = Vector2.new(6, 6)
		bubbles.Rate = 18
		bubbles.EmissionDirection = Enum.NormalId.Right -- up, since the cylinder lies on its side
		bubbles.Parent = emitter
		light(emitter, Color3.fromRGB(170, 240, 255), pocket.radius * 1.4, 1)
		-- A label so it reads as more than decoration.
		local gui = Instance.new("BillboardGui")
		gui.Name = "AirLabel"
		gui.Size = UDim2.fromOffset(120, 26)
		gui.StudsOffset = Vector3.new(0, 7, 0)
		gui.MaxDistance = 70
		gui.LightInfluence = 0
		gui.Parent = emitter
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(190, 245, 255)
		label.TextStrokeTransparency = 0.4
		label.Text = "AIR POCKET"
		label.Parent = gui
	end
end

function AbyssWorld.build()
	local root = Instance.new("Folder")
	root.Name = "Abyss"
	root.Parent = Workspace
	local rng = Random.new(3000) -- the same Abyss every time
	buildGround(root, rng)
	buildRoad(root, rng)
	buildGate(root, rng)
	buildRamp(root)
	buildFloor(root, rng)
	buildShop(root, rng)
	buildAirPockets(root)
end

return AbyssWorld
