--!nonstrict
-- Models for the Volcano Vent, Giant Octopus, Mermaid Merchant and Sunken Treasure Hunt
-- events, made from plain Parts like the rest of the reef. Each builder returns a Model
-- whose PrimaryPart sits at the `base` CFrame given (on the seabed, facing -Z).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefSounds = require(ReplicatedStorage.Shared.ReefSounds)

local EventVisuals = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder (along X) upright
local LAVA = Color3.fromRGB(255, 110, 40)
local BASALT = Color3.fromRGB(70, 62, 60)

local function piece(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
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

local function root(model: Model, base: CFrame): Part
	local r = piece(model, "Root", Vector3.new(1, 1, 1), base, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	r.Transparency = 1
	model.PrimaryPart = r
	return r
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
	return l
end

local function emitter(parent: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

-- A volcano cone of stacked basalt discs, lava running down its sides and a glowing crater
-- that smokes. `height` studs tall. Returns the model and the crater part.
function EventVisuals.volcano(base: CFrame, height: number): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Volcano"
	root(model, base)
	local layers = 8
	for i = 0, layers - 1 do
		local t = i / layers
		local radius = height * (0.75 - 0.55 * t)
		local h = height / layers
		piece(model, "Slope", Vector3.new(h + 0.5, radius * 2, radius * 2), base * CFrame.new(0, h * (i + 0.5), 0) * UPRIGHT * CFrame.Angles(i * 0.7, 0, 0), BASALT:Lerp(Color3.fromRGB(110, 90, 80), t * 0.6), Enum.Material.Basalt, Enum.PartType.Cylinder)
	end
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local top = base.Position + Vector3.new(0, height * 0.95, 0) + outward * height * 0.2
		local bottom = base.Position + Vector3.new(0, height * 0.15, 0) + outward * height * 0.62
		local cf = CFrame.lookAt((top + bottom) / 2, bottom)
		local flow = piece(model, "LavaFlow", Vector3.new(1.6, 0.6, (top - bottom).Magnitude), cf, LAVA, Enum.Material.Neon)
		flow.Transparency = 0.1
	end
	local crater = piece(model, "Crater", Vector3.new(1, height * 0.36, height * 0.36), base * CFrame.new(0, height + 0.2, 0) * UPRIGHT, LAVA, Enum.Material.Neon, Enum.PartType.Cylinder)
	light(crater, LAVA, 60, 4)
	emitter(crater, {
		Name = "Smoke",
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(60, 55, 55), Color3.fromRGB(120, 110, 110)),
		Size = NumberSequence.new(6, 22),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(5, 8),
		Rate = 6,
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(20, 20),
		EmissionDirection = Enum.NormalId.Right, -- the cylinder is turned upright: +X points up
	})
	emitter(crater, {
		Name = "Embers",
		Color = ColorSequence.new(LAVA),
		LightEmission = 1,
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(1.5, 3),
		Rate = 20,
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Right,
	})
	return model, crater
end

-- A glowing lava rock with a smoky trail.
function EventVisuals.lavaRock(): Part
	local rock = piece(nil :: any, "LavaRock", Vector3.new(2.6, 2.2, 2.6), CFrame.identity, Color3.fromRGB(255, 90, 30), Enum.Material.Neon, Enum.PartType.Ball)
	light(rock, LAVA, 14, 2)
	emitter(rock, {
		Name = "Trail",
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 120, 60), Color3.fromRGB(70, 60, 60)),
		Size = NumberSequence.new(1.5, 4),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 30,
		Speed = NumberRange.new(0.5, 1),
	})
	return rock
end

-- A one-off burst of particles at a point, cleaned up after.
function EventVisuals.burst(at: Vector3, color: Color3, count: number)
	local spot = Instance.new("Part")
	spot.Name = "Burst"
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.Transparency = 1
	spot.Size = Vector3.new(1, 1, 1)
	spot.Position = at
	local e = emitter(spot, {
		Color = ColorSequence.new(color),
		LightEmission = 0.8,
		Size = NumberSequence.new(1.2, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(180, 180),
		Enabled = false,
	})
	spot.Parent = Workspace
	e:Emit(count)
	task.delay(2, spot.Destroy, spot)
end

-- A one-off sound heard around a point (ReefSounds.effects[name]), cleaned up after.
function EventVisuals.sound(at: Vector3, name: string)
	local def = ReefSounds.effects[name]
	if not def then
		return
	end
	local spot = Instance.new("Part")
	spot.Name = "SoundSpot"
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.Transparency = 1
	spot.Size = Vector3.new(1, 1, 1)
	spot.Position = at
	local s = Instance.new("Sound")
	s.SoundId = ReefSounds.assetId(def)
	s.Volume = def.volume or 0.6
	s.PlaybackSpeed = def.playbackSpeed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 15
	s.RollOffMaxDistance = 160
	s.Parent = spot
	spot.Parent = Workspace
	s:Play()
	task.delay(6, spot.Destroy, spot)
end

-- The Giant Octopus: a huge head with big eyes and eight curling arms. Returns the model and
-- its body part (where the health bar hangs).
function EventVisuals.octopus(base: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "GiantOctopus"
	root(model, base)
	local skin = Color3.fromRGB(190, 70, 150)
	local spots = Color3.fromRGB(240, 140, 200)
	local body = piece(model, "Body", Vector3.new(16, 18, 16), base * CFrame.new(0, 6, 0), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	for i = 1, 7 do
		local angle = i * 2.4
		local at = base * CFrame.new(math.cos(angle) * 6.5, 8 + math.sin(i) * 4, math.sin(angle) * 6.5)
		piece(model, "Spot", Vector3.new(2.2, 2.2, 2.2), at, spots, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	for _, side in { -1, 1 } do
		piece(model, "Eye", Vector3.new(5, 5, 5), base * CFrame.new(side * 4, 2, -6.4), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(model, "Pupil", Vector3.new(2.4, 3, 2.4), base * CFrame.new(side * 4, 2, -8.6), Color3.fromRGB(20, 15, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(model, "Brow", Vector3.new(5.5, 0.9, 1), base * CFrame.new(side * 4, 5.2, -7.4) * CFrame.Angles(0, 0, side * math.rad(-18)), skin:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.SmoothPlastic)
	end
	for arm = 1, 8 do
		local angle = (arm - 0.5) / 8 * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from = base.Position + Vector3.new(0, -1, 0) + direction * 4
		local thick = 3
		for segment = 1, 5 do
			local out = direction * (3.2 + segment * 0.4)
			local down = Vector3.new(0, -2.6 + segment * 0.5, 0) -- each segment bends further up: a curl
			local to = from + out + down
			local cf = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
			piece(model, "Arm", Vector3.new((to - from).Magnitude + 0.6, thick, thick), cf, skin, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			from = to
			thick *= 0.82
		end
	end
	light(body, Color3.fromRGB(255, 150, 220), 30, 1.2)
	return model, body
end

-- Marina the Mermaid's stall: a giant shell canopy over a counter, with Marina behind it.
-- Returns the model and the counter (where the "Trade" prompt goes).
function EventVisuals.mermaidStall(base: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "MermaidMerchant"
	root(model, base)
	local shell = Color3.fromRGB(255, 200, 210)
	local counter = piece(model, "Counter", Vector3.new(10, 3.5, 3), base * CFrame.new(0, 1.75, -1), Color3.fromRGB(230, 210, 170), Enum.Material.Sandstone)
	counter.CanCollide = true
	counter.CanQuery = true
	piece(model, "CounterTop", Vector3.new(10.6, 0.4, 3.6), base * CFrame.new(0, 3.7, -1), Color3.fromRGB(120, 220, 210), Enum.Material.SmoothPlastic)
	-- A scallop-shell canopy: ridged slices fanned out over the stall.
	for i = -4, 4 do
		local fan = base * CFrame.new(0, 3.8, 3) * CFrame.Angles(0, 0, math.rad(i * 18)) * CFrame.new(0, 5.5, 0)
		piece(model, "ShellRib", Vector3.new(2.3, 11, 0.6), fan, shell:Lerp(Color3.fromRGB(255, 160, 170), (i % 2) * 0.4), Enum.Material.SmoothPlastic)
	end
	piece(model, "ShellHinge", Vector3.new(3, 3, 1.5), base * CFrame.new(0, 3.8, 3), shell, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	-- Marina: a teal tail curling up from the sand, a body, a face and long hair.
	local tail = Color3.fromRGB(60, 200, 180)
	local skin = Color3.fromRGB(240, 196, 160)
	local from = base.Position + Vector3.new(1.5, 0.6, 1.5)
	for segment, offset in { Vector3.new(-0.8, 1, -0.3), Vector3.new(-0.6, 1.2, -0.2), Vector3.new(-0.1, 1.3, 0) } do
		local to = from + offset
		local cf = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
		piece(model, "Tail", Vector3.new((to - from).Magnitude + 0.4, 1.6 - segment * 0.1, 1.6 - segment * 0.1), cf, tail, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		from = to
	end
	piece(model, "Fin", Vector3.new(2.6, 0.3, 1.4), base * CFrame.new(2.6, 0.5, 2) * CFrame.Angles(0, math.rad(30), 0), tail:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.SmoothPlastic)
	piece(model, "Body", Vector3.new(1.8, 2.2, 1.2), base * CFrame.new(0, 5.3, 1.5), skin, Enum.Material.SmoothPlastic)
	piece(model, "Top", Vector3.new(1.9, 0.7, 1.3), base * CFrame.new(0, 5.8, 1.5), Color3.fromRGB(255, 140, 170), Enum.Material.SmoothPlastic)
	local head = piece(model, "Head", Vector3.new(1.7, 1.8, 1.7), base * CFrame.new(0, 7.3, 1.5), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	piece(model, "Hair", Vector3.new(2, 2.6, 1.4), base * CFrame.new(0, 6.9, 2.1), Color3.fromRGB(240, 90, 80), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		piece(model, "Eye", Vector3.new(0.3, 0.3, 0.3), base * CFrame.new(side * 0.35, 7.45, 0.68), Color3.fromRGB(30, 60, 90), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(model, "Arm", Vector3.new(0.5, 2, 0.5), base * CFrame.new(side * 1.2, 5, 1) * CFrame.Angles(math.rad(-30), 0, side * math.rad(-15)), skin, Enum.Material.SmoothPlastic)
	end
	piece(model, "Crown", Vector3.new(1.4, 0.4, 1.4), base * CFrame.new(0, 8.25, 1.5), Color3.fromRGB(255, 215, 90), Enum.Material.Foil)
	light(head, Color3.fromRGB(180, 255, 240), 18, 1.4)
	-- Seed jars on the counter, glowing in the seed colours.
	for i, color in { Color3.fromRGB(70, 230, 230), Color3.fromRGB(235, 235, 245), Color3.fromRGB(255, 220, 80) } do
		local jar = piece(model, "Jar", Vector3.new(1.1, 1.4, 1.1), base * CFrame.new(-3 + (i - 1) * 3, 4.6, -1), color, Enum.Material.Glass)
		jar.Transparency = 0.25
	end
	emitter(head, {
		Name = "Sparkle",
		Color = ColorSequence.new(Color3.fromRGB(180, 255, 240)),
		LightEmission = 1,
		Size = NumberSequence.new(0.4, 0),
		Lifetime = NumberRange.new(1, 2),
		Rate = 6,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
	})
	return model, counter
end

-- Where the Treasure Hunt chest is buried: a few sunken stones and faint bubbles, and later
-- the chest itself when it's dug up.
function EventVisuals.digSpot(at: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "BuriedTreasure"
	local spot = root(model, CFrame.new(at + Vector3.new(0, 0.5, 0)))
	spot.Size = Vector3.new(4, 1, 4)
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2
		local s = 0.8 + (i % 3) * 0.3
		piece(model, "Stone", Vector3.new(s, s * 0.6, s), CFrame.new(at + Vector3.new(math.cos(angle) * 2.4, 0.1, math.sin(angle) * 2.4)), Color3.fromRGB(150, 140, 125), Enum.Material.Slate, Enum.PartType.Ball)
	end
	emitter(spot, {
		Name = "Bubbles",
		Color = ColorSequence.new(Color3.fromRGB(230, 245, 255)),
		Size = NumberSequence.new(0.3, 0.6),
		Transparency = NumberSequence.new(0.4, 1),
		Lifetime = NumberRange.new(2, 4),
		Rate = 0, -- the second clue turns these on
		Speed = NumberRange.new(3, 5),
		SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Top,
	})
	return model, spot
end

-- An opened chest of gold rising out of the sand at the dig spot.
function EventVisuals.openChest(at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "DugUpChest"
	local gold = Color3.fromRGB(255, 200, 70)
	root(model, CFrame.new(at))
	piece(model, "Box", Vector3.new(3.4, 1.8, 2.2), CFrame.new(at + Vector3.new(0, 0.9, 0)), Color3.fromRGB(125, 82, 45), Enum.Material.WoodPlanks)
	piece(model, "Lid", Vector3.new(3.4, 0.4, 2.2), CFrame.new(at + Vector3.new(0, 2.4, 1.2)) * CFrame.Angles(math.rad(-70), 0, 0), Color3.fromRGB(110, 72, 40), Enum.Material.WoodPlanks)
	local coins = piece(model, "Gold", Vector3.new(3, 0.6, 1.9), CFrame.new(at + Vector3.new(0, 1.8, 0)), gold, Enum.Material.Foil, Enum.PartType.Ball)
	light(coins, gold, 16, 2)
	return model
end

return EventVisuals
