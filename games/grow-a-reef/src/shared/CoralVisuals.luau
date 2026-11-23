--!nonstrict
-- Builds a coral Model out of plain Parts at full size. The model's pivot is the
-- centre of its base, so Model:ScaleTo() grows it up out of the reef bed. Shared so the
-- server plants it and the client can draw it in the Reef Index.

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
}

-- Surface materials some mutations give; with two, the later one in the key wins.
local MATERIALS = {
	Golden = Enum.Material.Foil,
	Frosted = Enum.Material.Ice,
}

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

function CoralVisuals.build(seedId: string, mutationKey: string, base: CFrame): Model
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
	if seed and build then
		build(model, base, seed.color)
	end
	applyMutations(model, mutationKey)
	model:SetAttribute("Seed", seedId)
	model:SetAttribute("Mutation", mutationKey)
	return model
end

return CoralVisuals
