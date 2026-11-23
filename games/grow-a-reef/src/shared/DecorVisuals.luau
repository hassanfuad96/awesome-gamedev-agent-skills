--!nonstrict
-- Reef decorations (ReefConfig.Decor) made from plain Parts, like the coral and fences.
-- build(itemId, base) returns a Model whose PrimaryPart "Root" sits at `base`, on the ground
-- in the middle of the item's footprint. Shared so the Reef Supplies window can show them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)

local DecorVisuals = {}

local WOOD = Color3.fromRGB(150, 112, 78)
local DARK_WOOD = Color3.fromRGB(96, 70, 50)
local GOLD = Color3.fromRGB(255, 200, 70)
-- Lighter than they'd be on land: the sea's blue light darkens everything.
local RUST = Color3.fromRGB(184, 120, 86)
local STONE = Color3.fromRGB(222, 218, 206)
local ROCK = Color3.fromRGB(112, 116, 122)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder (along X) upright

local function piece(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanTouch = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

local function bubbles(parent: BasePart, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	e.LightEmission = 0.4
	e.Size = NumberSequence.new(0.35, 0.8)
	e.Transparency = NumberSequence.new(0.15, 1)
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = rate
	e.Speed = NumberRange.new(4, 7)
	e.SpreadAngle = Vector2.new(15, 15)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
end

local builders: { [string]: (Model, CFrame) -> () } = {
	-- A driftwood post with a crossbar and a glowing lantern hanging from it.
	lantern = function(model, base)
		piece(model, "Post", Vector3.new(0.6, 6, 0.6), base * CFrame.new(0, 3, 0), DARK_WOOD, Enum.Material.Wood, nil, true)
		piece(model, "Arm", Vector3.new(0.4, 0.4, 2), base * CFrame.new(0, 5.7, -0.8), DARK_WOOD, Enum.Material.Wood)
		piece(model, "Chain", Vector3.new(0.1, 0.6, 0.1), base * CFrame.new(0, 5.2, -1.5), RUST, Enum.Material.Metal)
		piece(model, "LampTop", Vector3.new(0.9, 0.25, 0.9), base * CFrame.new(0, 4.85, -1.5), RUST, Enum.Material.Metal)
		local glass = piece(model, "LampGlass", Vector3.new(0.75, 1, 0.75), base * CFrame.new(0, 4.25, -1.5), Color3.fromRGB(255, 220, 150), Enum.Material.Glass)
		glass.Transparency = 0.35
		local flame = piece(model, "Flame", Vector3.new(0.35, 0.5, 0.35), base * CFrame.new(0, 4.2, -1.5), Color3.fromRGB(255, 190, 90), Enum.Material.Neon)
		light(flame, Color3.fromRGB(255, 200, 130), 16, 1.6)
		piece(model, "LampBase", Vector3.new(0.9, 0.2, 0.9), base * CFrame.new(0, 3.7, -1.5), RUST, Enum.Material.Metal)
	end,

	-- A ship's anchor, leaning and half sunk in the sand.
	anchor = function(model, base)
		local lean = base * CFrame.Angles(0, 0, math.rad(14))
		piece(model, "Shank", Vector3.new(5, 0.6, 0.6), lean * CFrame.new(0, 2.2, 0) * UPRIGHT, RUST, Enum.Material.CorrodedMetal, Enum.PartType.Cylinder, true)
		piece(model, "Stock", Vector3.new(0.4, 0.4, 3), lean * CFrame.new(0, 4.1, 0), RUST, Enum.Material.CorrodedMetal)
		piece(model, "Ring", Vector3.new(0.25, 1.1, 1.1), lean * CFrame.new(0, 4.9, 0) * CFrame.Angles(0, math.rad(90), 0), RUST, Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
		for _, side in { -1, 1 } do
			local arm = lean * CFrame.new(side * 1.05, 0.55, 0) * CFrame.Angles(0, 0, side * math.rad(-55))
			piece(model, "Arm", Vector3.new(0.5, 2.4, 0.5), arm, RUST, Enum.Material.CorrodedMetal)
			piece(model, "Fluke", Vector3.new(0.9, 0.9, 0.3), lean * CFrame.new(side * 2, 1.25, 0) * CFrame.Angles(0, 0, math.rad(45)), RUST, Enum.Material.CorrodedMetal)
		end
		piece(model, "Crown", Vector3.new(0.9, 0.9, 0.9), lean * CFrame.new(0, 0, 0), RUST, Enum.Material.CorrodedMetal, Enum.PartType.Ball)
		for i = 1, 4 do
			piece(model, "Weed", Vector3.new(0.15, 1.2 + i * 0.2, 0.1), lean * CFrame.new(-0.2 + i * 0.1, 2.3 + i * 0.4, 0.3) * CFrame.Angles(0.3, 0, 0.2 * i), Color3.fromRGB(70, 150, 90), Enum.Material.Grass)
		end
	end,

	-- An open chest spilling gold coins.
	chest = function(model, base)
		piece(model, "Box", Vector3.new(3, 1.6, 2), base * CFrame.new(0, 0.8, 0), WOOD, Enum.Material.WoodPlanks, nil, true)
		for _, x in { -1.1, 1.1 } do
			piece(model, "Band", Vector3.new(0.25, 1.65, 2.05), base * CFrame.new(x, 0.8, 0), GOLD, Enum.Material.Metal)
		end
		local hinge = base * CFrame.new(0, 1.6, 1) * CFrame.Angles(math.rad(-65), 0, 0)
		piece(model, "Lid", Vector3.new(3, 0.3, 2), hinge * CFrame.new(0, 0.15, -1), WOOD, Enum.Material.WoodPlanks)
		local coins = piece(model, "Gold", Vector3.new(2.7, 0.5, 1.7), base * CFrame.new(0, 1.55, 0), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
		light(coins, GOLD, 9, 1)
		local spill = { { -1.8, -1.2 }, { -0.9, -1.6 }, { 0.6, -1.4 }, { 1.7, -1.1 }, { 0.1, -2 } }
		for _, xz in spill do
			piece(model, "Coin", Vector3.new(0.12, 0.6, 0.6), base * CFrame.new(xz[1], 0.06, xz[2]) * UPRIGHT, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		piece(model, "Gem", Vector3.new(0.5, 0.5, 0.5), base * CFrame.new(0.5, 1.85, 0.2), Color3.fromRGB(255, 80, 150), Enum.Material.Glass, Enum.PartType.Ball)
	end,

	-- A rocky vent that bubbles all day.
	vent = function(model, base)
		local sizes = { { 3.6, 0.8 }, { 2.8, 1.6 }, { 2, 2.3 } }
		for i, s in sizes do
			piece(model, "Rock", Vector3.new(s[1], 1.4, s[1]), base * CFrame.new(0, s[2] - 0.4, 0) * CFrame.Angles(0, i, 0), ROCK:Lerp(Color3.new(0, 0, 0), i * 0.06), Enum.Material.Basalt, Enum.PartType.Ball, i == 1)
		end
		local mouth = piece(model, "Mouth", Vector3.new(0.2, 1, 1), base * CFrame.new(0, 2.6, 0) * UPRIGHT, Color3.fromRGB(255, 150, 80), Enum.Material.Neon, Enum.PartType.Cylinder)
		light(mouth, Color3.fromRGB(255, 160, 90), 8, 0.8)
		bubbles(mouth, 14)
	end,

	-- A stone fish leaping from a carved plinth.
	statue = function(model, base)
		piece(model, "Plinth", Vector3.new(3, 1.6, 3), base * CFrame.new(0, 0.8, 0), STONE, Enum.Material.Limestone, nil, true)
		piece(model, "PlinthTop", Vector3.new(3.4, 0.4, 3.4), base * CFrame.new(0, 1.8, 0), STONE:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Limestone)
		piece(model, "Wave", Vector3.new(1.2, 1.6, 1.2), base * CFrame.new(0, 2.6, 0.3), STONE, Enum.Material.Marble, Enum.PartType.Ball)
		-- The fish is carved from pale green-blue stone, so it stands out from its plinth.
		local jade = Color3.fromRGB(150, 220, 210)
		local leap = base * CFrame.new(0, 4.4, -0.2) * CFrame.Angles(math.rad(35), 0, 0)
		piece(model, "Body", Vector3.new(1.4, 1.8, 3.6), leap, jade, Enum.Material.Marble, Enum.PartType.Ball)
		piece(model, "Tail", Vector3.new(0.3, 2.2, 1.4), leap * CFrame.new(0, 0, 2.3), jade, Enum.Material.Marble)
		piece(model, "Fin", Vector3.new(0.25, 1, 1.2), leap * CFrame.new(0, 1, 0.2), jade, Enum.Material.Marble)
		for _, side in { -1, 1 } do
			piece(model, "Eye", Vector3.new(0.3, 0.3, 0.3), leap * CFrame.new(side * 0.6, 0.25, -1.2), Color3.fromRGB(70, 200, 230), Enum.Material.Neon, Enum.PartType.Ball)
		end
	end,

	-- A tall natural arch of rock: two pillars and a curved span you can swim under.
	arch = function(model, base)
		local radius = 4
		local sandstone = Color3.fromRGB(200, 178, 146)
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				local s = 2.6 - i * 0.2
				piece(model, "Pillar", Vector3.new(s, 2.4, s), base * CFrame.new(side * radius, 1.1 + i * 2, 0) * CFrame.Angles(0, i, 0), sandstone:Lerp(STONE, i * 0.2), Enum.Material.Sandstone, Enum.PartType.Ball, true)
			end
		end
		local steps = 7
		for i = 0, steps do
			local angle = math.pi * i / steps
			local at = base * CFrame.new(-math.cos(angle) * radius, 6 + math.sin(angle) * radius * 0.8, 0) * CFrame.Angles(0, 0, angle - math.pi / 2)
			piece(model, "Span", Vector3.new(2.2, 2.4, 2.4), at, sandstone:Lerp(Color3.fromRGB(226, 200, 160), (i % 2) * 0.5), Enum.Material.Sandstone, Enum.PartType.Ball)
		end
		for i = 1, 5 do
			piece(model, "Weed", Vector3.new(0.2, 1.6, 0.1), base * CFrame.new(-radius + i * 1.6, 1, 1.2) * CFrame.Angles(0.2, i, 0.15), Color3.fromRGB(80, 170, 90), Enum.Material.Grass)
		end
	end,
}

function DecorVisuals.build(itemId: string, base: CFrame): Model
	local item = ReefConfig.DecorById[itemId]
	local build = builders[itemId]
	assert(item and build, `no decoration {itemId}`)
	local model = Instance.new("Model")
	model.Name = item.name

	-- The root marks the footprint; it holds the pick-up prompt.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(item.footprint * 2, 1, item.footprint * 2)
	root.CFrame = base * CFrame.new(0, 0.5, 0)
	root.Parent = model
	model.PrimaryPart = root

	build(model, base)
	return model
end

return DecorVisuals
