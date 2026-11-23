--!nonstrict
-- Builds a coral Model out of plain Parts. The model's pivot is the centre of its base, so
-- Model:ScaleTo() grows it up out of the planter. Shared so the server plants it and the
-- client can draw it in the Reef Index.
-- Planted coral shows its growth stage (ReefConfig.growthStage): a seedling's sprouts, then
-- the coral itself, then the fully grown coral with polyps and rising bubbles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)

local CoralVisuals = {}

local function piece(model: Model, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = offset
	p.Parent = model
	return p
end

-- A vertical cylinder: Roblox cylinders run along X, so roll them 90 degrees.
local function stalk(model: Model, base: CFrame, height: number, radius: number, color: Color3, material: Enum.Material, tilt: CFrame?): Part
	local lean = tilt or CFrame.identity
	local cf = base * lean * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	return piece(model, Vector3.new(height, radius * 2, radius * 2), cf, color, material, Enum.PartType.Cylinder)
end

local builders: { [string]: (Model, CFrame, Color3) -> () } = {
	kelp = function(model, base, color)
		for i, x in { -1.2, 0, 1.2 } do
			local height = 4 + i
			local blade = stalk(model, base * CFrame.new(x, 0, (i % 2) * 0.8 - 0.4), height, 0.3, color, Enum.Material.Grass,
				CFrame.Angles(math.rad(x * 6), 0, math.rad(-x * 8)))
			blade.Name = "Blade"
			local bulb = piece(model, Vector3.new(0.8, 0.8, 0.8), blade.CFrame * CFrame.new(height / 2, 0, 0), color:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Glass, Enum.PartType.Ball)
			bulb.Name = "Bubble"
		end
	end,
	brain = function(model, base, color)
		piece(model, Vector3.new(4, 3, 4), base * CFrame.new(0, 1.5, 0), color, Enum.Material.Slate, Enum.PartType.Ball)
		piece(model, Vector3.new(2.4, 2, 2.4), base * CFrame.new(1.4, 1, 1), color:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Slate, Enum.PartType.Ball)
	end,
	fan = function(model, base, color)
		stalk(model, base, 1.5, 0.3, color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Wood)
		piece(model, Vector3.new(5, 4.5, 0.25), base * CFrame.new(0, 3.6, 0), color, Enum.Material.Fabric)
		piece(model, Vector3.new(3.5, 3, 0.25), base * CFrame.new(1, 3.2, 0.6) * CFrame.Angles(0, math.rad(35), 0), color:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Fabric)
	end,
	anemone = function(model, base, color)
		piece(model, Vector3.new(2.4, 1.6, 2.4), base * CFrame.new(0, 0.8, 0), color:Lerp(Color3.new(0, 0, 0), 0.4), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for i = 1, 7 do
			local angle = (i / 7) * math.pi * 2
			stalk(model, base * CFrame.new(math.cos(angle) * 0.7, 1, math.sin(angle) * 0.7), 2.6, 0.18, color, Enum.Material.Neon,
				CFrame.Angles(math.sin(angle) * 0.5, 0, -math.cos(angle) * 0.5))
		end
	end,
	clam = function(model, base, color)
		piece(model, Vector3.new(4, 0.8, 3.4), base * CFrame.new(0, 0.4, 0), color, Enum.Material.Marble)
		piece(model, Vector3.new(4, 0.8, 3.4), base * CFrame.new(0, 1.6, -1) * CFrame.Angles(math.rad(-40), 0, 0), color, Enum.Material.Marble)
		local pearl = piece(model, Vector3.new(1.3, 1.3, 1.3), base * CFrame.new(0, 1.2, 0.3), Color3.fromRGB(255, 250, 240), Enum.Material.Glass, Enum.PartType.Ball)
		pearl.Name = "Pearl"
	end,
	star = function(model, base, color)
		stalk(model, base, 3, 0.4, color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Slate)
		for i = 1, 6 do
			local angle = (i / 6) * math.pi * 2
			stalk(model, base * CFrame.new(0, 2.5, 0), 2.4, 0.22, color, Enum.Material.Neon,
				CFrame.Angles(math.sin(angle) * 1.1, 0, -math.cos(angle) * 1.1))
		end
		piece(model, Vector3.new(1.2, 1.2, 1.2), base * CFrame.new(0, 3.2, 0), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
	end,
	-- Transcendent: tall ribbons shading from teal to violet with glowing tips, round a
	-- shining heart that gives off drifting motes.
	seagrass = function(model, base, color)
		local tips = { Color3.fromRGB(120, 255, 230), Color3.fromRGB(150, 170, 255), Color3.fromRGB(235, 150, 255) }
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			local height = 5 + (i % 3) * 1.3
			local tip = tips[i % 3 + 1]
			local lean = CFrame.Angles(math.sin(angle) * 0.22, angle, -math.cos(angle) * 0.22)
			local at = base * CFrame.new(math.cos(angle) * 0.9, 0, math.sin(angle) * 0.9) * lean
			local ribbon = piece(model, Vector3.new(0.55, height, 0.14), at * CFrame.new(0, height / 2, 0), color:Lerp(tip, 0.45), Enum.Material.SmoothPlastic)
			ribbon.Transparency = 0.1
			piece(model, Vector3.new(0.6, 0.6, 0.6), at * CFrame.new(0, height, 0), tip, Enum.Material.Neon, Enum.PartType.Ball)
		end
		local heart = piece(model, Vector3.new(1.1, 1.1, 1.1), base * CFrame.new(0, 0.8, 0), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
		heart.Name = "Heart"
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 12
		light.Brightness = 2
		light.Parent = heart
		local motes = Instance.new("ParticleEmitter")
		motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		motes.Color = ColorSequence.new(tips[1], tips[3])
		motes.LightEmission = 1
		motes.Size = NumberSequence.new(0.25, 0)
		motes.Lifetime = NumberRange.new(2, 3)
		motes.Rate = 6
		motes.Speed = NumberRange.new(1, 2.5)
		motes.SpreadAngle = Vector2.new(40, 40)
		motes.EmissionDirection = Enum.NormalId.Top
		motes.Parent = heart
	end,
	-- Ghost Coral (Sunken Ruins cave): pale, half-see-through branching antlers that glow
	-- faintly at the tips, like the cave crystals it grows among.
	ghost = function(model, base, color)
		stalk(model, base, 1.6, 0.45, color:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Glass).Transparency = 0.35
		for i = 1, 5 do
			local angle = (i / 5) * math.pi * 2
			local lean = CFrame.Angles(math.sin(angle) * 0.55, 0, -math.cos(angle) * 0.55)
			local branch = stalk(model, base * CFrame.new(0, 1.4, 0), 2.6, 0.2, color, Enum.Material.Glass, lean)
			branch.Transparency = 0.3
			local tip = branch.CFrame * CFrame.new(1.3, 0, 0)
			for _, side in { -1, 1 } do
				local twig = piece(model, Vector3.new(1.2, 0.24, 0.24), tip * CFrame.Angles(0, 0, side * 0.7) * CFrame.new(0.5, 0, 0), color, Enum.Material.Glass)
				twig.Transparency = 0.3
				piece(model, Vector3.new(0.35, 0.35, 0.35), twig.CFrame * CFrame.new(0.65, 0, 0), Color3.fromRGB(220, 250, 255), Enum.Material.Neon, Enum.PartType.Ball)
			end
		end
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Range = 8
		glow.Brightness = 1.2
		glow.Parent = model:FindFirstChildWhichIsA("BasePart")
	end,
	-- Relic Coral (the temple sanctum): a stone-pink trunk carved with gold bands, fanning out
	-- into flat plates rimmed with gold, like an old column grown over.
	relic = function(model, base, color)
		local stone = Color3.fromRGB(226, 170, 150)
		local gold = Color3.fromRGB(255, 205, 90)
		stalk(model, base, 3.4, 0.6, stone, Enum.Material.Sandstone)
		for _, y in { 0.9, 2.3 } do
			stalk(model, base * CFrame.new(0, y, 0), 0.3, 0.68, gold, Enum.Material.Foil)
		end
		for i = 1, 4 do
			local angle = (i / 4) * math.pi * 2 + 0.4
			local y = 2.6 + (i % 2) * 0.9
			local plate = base * CFrame.new(math.cos(angle) * 1.5, y, math.sin(angle) * 1.5) * CFrame.Angles(0, -angle, 0)
			piece(model, Vector3.new(0.35, 2.6, 2.6), plate * CFrame.Angles(0, 0, math.rad(90 - 12)), color, Enum.Material.Pebble, Enum.PartType.Cylinder)
			piece(model, Vector3.new(0.3, 2.8, 2.8), plate * CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.rad(90 - 12)), gold, Enum.Material.Foil, Enum.PartType.Cylinder)
		end
		local gem = piece(model, Vector3.new(0.9, 0.9, 0.9), base * CFrame.new(0, 3.8, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)), gold, Enum.Material.Neon)
		gem.Name = "Gem"
		local light = Instance.new("PointLight")
		light.Color = gold
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = gem
	end,
	-- Abyssal coral (Lumi's stall in the Abyss). Glowcap: a cluster of glowing mushrooms, violet
	-- caps with bright gills.
	glowcap = function(model, base, color)
		for i, spot in { Vector3.new(0, 0, 0), Vector3.new(1.4, 0, 0.9), Vector3.new(-1.2, 0, 0.8) } do
			local height = if i == 1 then 3.6 else 2.2
			local radius = if i == 1 then 1.7 else 1.1
			local at = base * CFrame.new(spot)
			stalk(model, at, height, radius * 0.25, Color3.fromRGB(210, 200, 240), Enum.Material.SmoothPlastic)
			piece(model, Vector3.new(radius * 2, radius * 0.8, radius * 2), at * CFrame.new(0, height + radius * 0.1, 0), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			local gills = piece(model, Vector3.new(0.15, radius * 1.8, radius * 1.8), at * CFrame.new(0, height - 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), color:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Neon, Enum.PartType.Cylinder)
			if i == 1 then
				local light = Instance.new("PointLight")
				light.Color = color
				light.Range = 9
				light.Brightness = 1.4
				light.Parent = gills
			end
		end
	end,
	-- Lumen Brain: a big brain coral wrapped in a shimmering glow, with bright ridges.
	lumen = function(model, base, color)
		piece(model, Vector3.new(4.4, 3.2, 4.4), base * CFrame.new(0, 1.6, 0), color:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Pebble, Enum.PartType.Ball)
		local sheen = piece(model, Vector3.new(4.7, 3.5, 4.7), base * CFrame.new(0, 1.6, 0), color, Enum.Material.ForceField, Enum.PartType.Ball)
		sheen.Name = "Sheen"
		for i = 0, 3 do
			piece(model, Vector3.new(0.25, 0.25, 3.6 - math.abs(i - 1.5) * 0.9), base * CFrame.new(-1.2 + i * 0.8, 3.05 - math.abs(i - 1.5) * 0.35, 0), Color3.fromRGB(200, 245, 255), Enum.Material.Neon)
		end
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 11
		light.Brightness = 1.6
		light.Parent = sheen
	end,
	-- Void Bloom: a dark stem rising to a crown of glowing petals round a shining void-black
	-- heart, trailing motes.
	voidbloom = function(model, base, color)
		stalk(model, base, 3.6, 0.35, Color3.fromRGB(30, 30, 60), Enum.Material.SmoothPlastic)
		for i = 1, 7 do
			local angle = (i / 7) * math.pi * 2
			local petal = base * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(55), 0, 0) * CFrame.new(0, 1.3, 0)
			piece(model, Vector3.new(0.9, 2.6, 0.2), petal, color, Enum.Material.Neon).Transparency = 0.15
		end
		local heart = piece(model, Vector3.new(1.3, 1.3, 1.3), base * CFrame.new(0, 3.8, 0), Color3.fromRGB(20, 10, 40), Enum.Material.Glass, Enum.PartType.Ball)
		heart.Name = "Heart"
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 13
		light.Brightness = 2
		light.Parent = heart
		local motes = Instance.new("ParticleEmitter")
		motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		motes.Color = ColorSequence.new(color, Color3.fromRGB(170, 130, 255))
		motes.LightEmission = 1
		motes.Size = NumberSequence.new(0.25, 0)
		motes.Lifetime = NumberRange.new(2, 3)
		motes.Rate = 6
		motes.Speed = NumberRange.new(0.8, 2)
		motes.SpreadAngle = Vector2.new(50, 50)
		motes.EmissionDirection = Enum.NormalId.Top
		motes.Parent = heart
	end,
}

-- Surface materials some mutations give; with two, the later one in the key wins.
local MATERIALS = {
	Golden = Enum.Material.Foil,
	Frosted = Enum.Material.Ice,
	Molten = Enum.Material.CrackedLava,
}

-- Stage 1: thin branching sprouts in a paler shade of the seed's colour, like a coral cutting
-- just pushed into the sand.
local function seedling(model: Model, base: CFrame, color: Color3)
	local shade = color:Lerp(Color3.new(1, 1, 1), 0.35)
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2 + 0.4
		local lean = CFrame.Angles(math.sin(angle) * 0.35, angle, -math.cos(angle) * 0.35)
		local foot = base * CFrame.new(math.cos(angle) * 0.25, 0, math.sin(angle) * 0.25) * lean
		local height = 1.1 + (i % 3) * 0.3
		local trunk = stalk(model, foot, height, 0.13, shade, Enum.Material.SmoothPlastic)
		trunk.Name = "Sprout"
		-- A fork at the top: two short tines angled apart.
		local top = foot * CFrame.new(0, height, 0)
		for _, side in { -1, 1 } do
			stalk(model, top, 0.7, 0.1, shade, Enum.Material.SmoothPlastic, CFrame.Angles(0, 0, side * 0.55)).Name = "Tine"
		end
	end
end

-- Stage 3 extras: little polyp tufts round the coral's foot and a slow stream of bubbles,
-- so a ready coral stands out on the reef.
local function flourish(model: Model, base: CFrame, color: Color3)
	local accents = { color:Lerp(Color3.fromRGB(255, 120, 200), 0.5), color:Lerp(Color3.fromRGB(80, 220, 255), 0.5), color:Lerp(Color3.fromRGB(255, 220, 90), 0.5) }
	for i, tint in accents do
		local angle = (i / 3) * math.pi * 2 + 0.9
		local foot = base * CFrame.new(math.cos(angle) * 2.3, 0, math.sin(angle) * 2.3)
		piece(model, Vector3.new(0.9, 0.9, 0.9), foot * CFrame.new(0, 0.3, 0), tint:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.SmoothPlastic, Enum.PartType.Ball).Name = "Polyp"
		for k = 1, 3 do
			local spread = (k / 3) * math.pi * 2
			stalk(model, foot * CFrame.new(0, 0.5, 0), 0.9, 0.09, tint, Enum.Material.Neon, CFrame.Angles(math.sin(spread) * 0.5, 0, -math.cos(spread) * 0.5)).Name = "Tentacle"
		end
	end
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "ReadyBubbles"
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	bubbles.LightEmission = 0.4
	bubbles.Size = NumberSequence.new(0.25, 0.5)
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.Lifetime = NumberRange.new(2.5, 4)
	bubbles.Rate = 2
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.SpreadAngle = Vector2.new(15, 15)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Parent = model.PrimaryPart
end

-- Tints the coral for each mutation in its key: the first sets the colour, a second shades it.
local function applyMutations(model: Model, mutationKey: string)
	local parts = ReefConfig.mutationParts(mutationKey)
	if #parts == 0 then
		return
	end
	local root = model.PrimaryPart
	for index, mutationId in parts do
		local mutation = ReefConfig.MutationById[mutationId]
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child ~= root and mutation and mutation.color then
				child.Color = (child.Color :: Color3):Lerp(mutation.color, if index == 1 then 0.75 else 0.45)
				child.Material = MATERIALS[mutationId] or child.Material
			end
		end
	end
	if root then
		local first = ReefConfig.MutationById[parts[1]]
		local prismatic = table.find(parts, "Prismatic") ~= nil
		local light = Instance.new("PointLight")
		light.Color = first.color or Color3.new(1, 1, 1)
		light.Range = if prismatic or #parts > 1 then 14 else 9
		light.Brightness = 2
		light.Parent = root
		if prismatic then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = ReefConfig.MutationById.Prismatic.color or Color3.new(1, 1, 1)
			sparkles.Parent = root
		end
	end
end

-- `stage` (1-3) is the growth stage of planted coral; leave it out for the plain coral
-- (Reef Index, decoration).
function CoralVisuals.build(seedId: string, mutationKey: string, base: CFrame, stage: number?): Model
	local seed = ReefConfig.Seeds[seedId]
	local model = Instance.new("Model")
	model.Name = "Coral"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = base
	root.Parent = model
	model.PrimaryPart = root

	local build = builders[seedId]
	if seed and stage == 1 then
		seedling(model, base, seed.color)
	elseif seed and build then
		build(model, base, seed.color)
		if stage == 3 then
			flourish(model, base, seed.color)
		end
	end
	applyMutations(model, mutationKey)
	model:SetAttribute("Seed", seedId)
	model:SetAttribute("Mutation", mutationKey)
	if stage then
		model:SetAttribute("Stage", stage)
	end
	return model
end

return CoralVisuals
