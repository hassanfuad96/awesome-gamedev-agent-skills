--!nonstrict
-- Building blocks shared by the world builders (World for the Starter Lagoon, MainReef for
-- the Main Reef, and any other zone): plain Parts, low-poly boulders, coral, sea grass, lamps,
-- labels, prompts, bubbles, whirlpool teleport pads and sand paths. Everything here is
-- static; decoration never collides or takes clicks (prop), so it never blocks a player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local CoralVisuals = require(ReplicatedStorage.Shared.CoralVisuals)

local WorldKit = {}

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

-- A sand path from a to b on the seabed, with pebbles along both edges. Returns the
-- direction along it and the sideways direction.
local function path(parent: Instance, a: Vector3, b: Vector3, width: number, rng: Random): (Vector3, Vector3)
	local direction = ((b - a) * Vector3.new(1, 0, 1)).Unit
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

WorldKit.Colors = {
	SAND = SAND,
	PATH_SAND = PATH_SAND,
	PLAZA_STONE = PLAZA_STONE,
	PLAZA_INLAY = PLAZA_INLAY,
	REEF_SAND = REEF_SAND,
	BED_SOIL = BED_SOIL,
	ROCK = ROCK,
	STONE = STONE,
	SEA_GRASS = SEA_GRASS,
	GLOW = GLOW,
	METAL_DARK = METAL_DARK,
	HULL_WHITE = HULL_WHITE,
	CORAL_PINK = CORAL_PINK,
	TUBE_BLUE = TUBE_BLUE,
}
WorldKit.UPRIGHT = UPRIGHT
WorldKit.part = part
WorldKit.prop = prop
WorldKit.disc = disc
WorldKit.bar = bar
WorldKit.facing = facing
WorldKit.seaGrass = seaGrass
WorldKit.boulder = boulder
WorldKit.tableCoral = tableCoral
WorldKit.tubeCoral = tubeCoral
WorldKit.bigCoral = bigCoral
WorldKit.jellyLamp = jellyLamp
WorldKit.surfaceLabel = surfaceLabel
WorldKit.prompt = prompt
WorldKit.bubbles = bubbles
WorldKit.bubbleVent = bubbleVent
WorldKit.teleportPad = teleportPad
WorldKit.path = path

return WorldKit
