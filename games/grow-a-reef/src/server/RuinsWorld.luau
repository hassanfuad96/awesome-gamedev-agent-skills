--!nonstrict
-- Builds the Sunken Ruins at server start (layout in RuinsConfig, which explains the zone's
-- frame): its own seabed and the sand road in from the lagoon, the entrance with Marlo the
-- explorer, a ruined archway, the temple terrace (temple and sanctum, mermaid statue, the
-- tall column), the pirate ship, the underwater cave, the coral garden and the Wreck Basin.
-- Also the interactive spots: treasure chests, relics and hidden coral, each tagged
-- RuinsConfig.SPOT_TAG with Kind and Id attributes and a ProximityPrompt that the server's
-- Ruins module answers. Everything lives under Workspace.SunkenRuins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local RuinsConfig = require(ReplicatedStorage.Shared.RuinsConfig)
local CoralVisuals = require(ReplicatedStorage.Shared.CoralVisuals)

local RuinsWorld = {}

local F = RuinsConfig.frame
local at = RuinsConfig.at
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder (or bar) to run along Z

local SAND = Color3.fromRGB(230, 208, 160)
local ROAD = Color3.fromRGB(242, 230, 196)
local STONE = Color3.fromRGB(188, 204, 212) -- the pale blue-grey of the old temple stone
local STONE_DARK = Color3.fromRGB(140, 156, 170)
local CLIFF = Color3.fromRGB(176, 150, 118)
local MOSS = Color3.fromRGB(96, 184, 112)
local MARBLE = Color3.fromRGB(196, 222, 230)
local WOOD = Color3.fromRGB(128, 92, 62)
local WOOD_DARK = Color3.fromRGB(84, 60, 44)
local GOLD = Color3.fromRGB(255, 200, 70)
local ROCK = Color3.fromRGB(104, 112, 124)
local CORALS = {
	Color3.fromRGB(150, 90, 220), -- purple
	Color3.fromRGB(70, 140, 235), -- blue
	Color3.fromRGB(255, 140, 60), -- orange
	Color3.fromRGB(240, 120, 150), -- pink
	Color3.fromRGB(250, 210, 70), -- yellow
	Color3.fromRGB(60, 200, 170), -- teal
}

-- A point and a frame in the zone's frame.
local function L(x: number, y: number, z: number): CFrame
	return F * CFrame.new(x, y, z)
end

type PartOptions = { shape: Enum.PartType?, collide: boolean?, transparency: number?, wedge: boolean? }

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, options: PartOptions?): BasePart
	local o = options or {}
	local p = Instance.new(if o.wedge then "WedgePart" else "Part") :: BasePart
	p.Name = name
	p.Anchored = true
	if not o.wedge then
		(p :: Part).Shape = o.shape or Enum.PartType.Block
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = o.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.collide == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Parent = parent
	return p
end

-- Decoration that never gets in a player's way.
local function prop(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, options: PartOptions?): BasePart
	local o = table.clone(options or {})
	o.collide = false
	return part(parent, name, size, cf, color, material, o)
end

-- An upright cylinder standing on `base` (the centre of its bottom face).
local function pillar(parent: Instance, name: string, base: CFrame, height: number, radius: number, color: Color3, material: Enum.Material, collide: boolean?): BasePart
	local make = if collide == false then prop else part
	return make(parent, name, Vector3.new(height, radius * 2, radius * 2), base * CFrame.new(0, height / 2, 0) * UPRIGHT, color, material, { shape = Enum.PartType.Cylinder })
end

-- A thin bar from a to b.
local function bar(parent: Instance, name: string, a: Vector3, b: Vector3, thick: number, color: Color3, material: Enum.Material, collide: boolean?): BasePart
	local make = if collide then part else prop
	return make(parent, name, Vector3.new(thick, thick, (b - a).Magnitude + thick * 0.5), CFrame.lookAt((a + b) / 2, b), color, material)
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

local function sparkles(parent: BasePart, color: Color3, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkle"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.35, 0)
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(1, 2.5)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Rate = rate
	e.Parent = parent
	return e
end

local function bubbles(parent: BasePart, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	e.Size = NumberSequence.new(0.4, 0.9)
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Lifetime = NumberRange.new(4, 7)
	e.Rate = rate
	e.Speed = NumberRange.new(4, 7)
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
end

local function surfaceLabel(target: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
end

local function prompt(parent: Instance, kind: string, action: string, object: string, distance: number, hold: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = kind .. "Prompt"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = distance
	p.RequiresLineOfSight = false
	p:SetAttribute("Kind", kind)
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------------------------
-- Scenery pieces

-- A faceted, low-poly boulder: a few blocks tumbled together.
local function boulder(parent: Instance, position: Vector3, size: number, rng: Random, color: Color3?)
	for _ = 1, 3 do
		local s = Vector3.new(size * rng:NextNumber(0.65, 1), size * rng:NextNumber(0.45, 0.75), size * rng:NextNumber(0.65, 1))
		local offset = Vector3.new(rng:NextNumber(-0.25, 0.25) * size, s.Y * 0.3, rng:NextNumber(-0.25, 0.25) * size)
		part(parent, "Boulder", s, CFrame.new(position + offset) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.5, 0.5)), (color or ROCK):Lerp(Color3.fromRGB(70, 84, 110), rng:NextNumber(0, 0.45)), Enum.Material.Slate)
	end
end

local function kelp(parent: Instance, position: Vector3, rng: Random, tall: number?)
	local scale = tall or 1
	for blade = 1, 4 do
		local height = rng:NextNumber(5, 10) * scale
		local lean = CFrame.Angles(rng:NextNumber(-0.18, 0.18), (blade / 4) * math.pi * 2, rng:NextNumber(-0.18, 0.18))
		prop(parent, "Kelp", Vector3.new(0.5, height, 0.12), CFrame.new(position + Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))) * lean * CFrame.new(0, height / 2, 0), MOSS:Lerp(Color3.fromRGB(150, 210, 80), rng:NextNumber(0, 0.5)), Enum.Material.Grass)
	end
end

-- A lumpy dome of brain coral or sponge, half sunk in the sand.
local function mound(parent: Instance, position: Vector3, size: number, color: Color3)
	prop(parent, "CoralMound", Vector3.new(size, size * 0.7, size), CFrame.new(position + Vector3.new(0, size * 0.18, 0)), color, Enum.Material.Pebble, { shape = Enum.PartType.Ball })
	prop(parent, "CoralMound", Vector3.new(size * 0.55, size * 0.45, size * 0.55), CFrame.new(position + Vector3.new(size * 0.35, size * 0.12, size * 0.2)), color:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Pebble, { shape = Enum.PartType.Ball })
end

-- Branching coral: a few angled stalks with knobbly tips, like the blue staghorn in front of
-- the reference art's anchor.
local function branchCoral(parent: Instance, position: Vector3, rng: Random, color: Color3, scale: number?)
	local s = scale or 1
	for _ = 1, rng:NextInteger(5, 8) do
		local height = rng:NextNumber(2, 4.5) * s
		local tilt = CFrame.Angles(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.7, 0.7))
		local base = CFrame.new(position) * tilt
		prop(parent, "Branch", Vector3.new(height, 0.5 * s, 0.5 * s), base * CFrame.new(0, height / 2, 0) * UPRIGHT, color, Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder })
		prop(parent, "BranchTip", Vector3.new(0.75, 0.75, 0.75) * s, base * CFrame.new(0, height, 0), color:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.SmoothPlastic, { shape = Enum.PartType.Ball })
	end
end

-- A sea fan: a flat lacy plate on a short stem.
local function seaFan(parent: Instance, position: Vector3, rng: Random, color: Color3)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local base = CFrame.new(position) * yaw
	prop(parent, "FanStem", Vector3.new(0.4, 1.4, 0.4), base * CFrame.new(0, 0.7, 0), color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Wood)
	-- A cylinder's flat faces point along X, so unrotated it stands upright like a fan.
	-- Light and a little see-through: fabric-like materials render nearly black underwater.
	prop(parent, "Fan", Vector3.new(0.2, 5, 5.5), base * CFrame.new(0, 3.6, 0), color:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder, transparency = 0.25 })
end

-- Tube coral: upright tubes with dark open tops.
local function tubes(parent: Instance, position: Vector3, rng: Random, color: Color3)
	for _ = 1, rng:NextInteger(4, 7) do
		local height = rng:NextNumber(2, 6)
		local width = rng:NextNumber(0.9, 1.6)
		local base = CFrame.new(position + Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
		pillar(parent, "Tube", base, height, width / 2, color:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.3)), Enum.Material.SmoothPlastic, false)
		prop(parent, "TubeMouth", Vector3.new(0.1, width * 0.7, width * 0.7), base * CFrame.new(0, height + 0.02, 0) * UPRIGHT, Color3.fromRGB(120, 40, 40), Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder })
	end
end

local function starfish(parent: Instance, position: Vector3, rng: Random)
	local color = ({ Color3.fromRGB(235, 80, 70), Color3.fromRGB(255, 150, 60), Color3.fromRGB(160, 100, 220) })[rng:NextInteger(1, 3)]
	local base = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	for i = 0, 4 do
		prop(parent, "StarArm", Vector3.new(0.5, 0.25, 1.6), base * CFrame.Angles(0, i * math.pi * 2 / 5, 0) * CFrame.new(0, 0, -0.7), color, Enum.Material.SmoothPlastic)
	end
end

local function shell(parent: Instance, position: Vector3, rng: Random)
	local color = Color3.fromRGB(250, 220, 190):Lerp(Color3.fromRGB(255, 160, 120), rng:NextNumber(0, 1))
	prop(parent, "Seashell", Vector3.new(1.2, 0.5, 1), CFrame.new(position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), color, Enum.Material.SmoothPlastic, { shape = Enum.PartType.Ball })
end

-- A coral garden patch: a mix of everything, round a point.
local function coralPatch(parent: Instance, center: Vector3, spread: number, rng: Random, count: number)
	for i = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = math.sqrt(rng:NextNumber()) * spread
		local p = center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local color = CORALS[rng:NextInteger(1, #CORALS)]
		local pick = i % 6
		if pick == 0 then
			mound(parent, p, rng:NextNumber(3, 6), color)
		elseif pick == 1 then
			branchCoral(parent, p, rng, color, rng:NextNumber(0.8, 1.4))
		elseif pick == 2 then
			seaFan(parent, p, rng, color)
		elseif pick == 3 then
			tubes(parent, p, rng, color)
		elseif pick == 4 then
			kelp(parent, p, rng, rng:NextNumber(0.8, 1.5))
		else
			if rng:NextNumber() < 0.5 then
				starfish(parent, p, rng)
			else
				shell(parent, p, rng)
			end
		end
	end
end

-- A ruined column on `base`: plinth, drums and either a capital or a snapped top. Returns
-- the height of its top.
local function column(parent: Instance, base: CFrame, height: number, radius: number, broken: boolean, rng: Random): number
	part(parent, "Plinth", Vector3.new(radius * 2.7, 0.8, radius * 2.7), base * CFrame.new(0, 0.4, 0), STONE_DARK, Enum.Material.Limestone)
	local y = 0.8
	local shaftTop = height - (if broken then 0 else 1.6)
	while y < shaftTop - 0.05 do
		local drum = math.min(4, shaftTop - y)
		pillar(parent, "Drum", base * CFrame.new(0, y, 0), drum, radius, STONE:Lerp(STONE_DARK, rng:NextNumber(0, 0.35)), Enum.Material.Limestone)
		y += drum
	end
	if broken then
		-- A jagged snapped top.
		part(parent, "Snapped", Vector3.new(radius * 1.6, 1.2, radius * 1.2), base * CFrame.new(radius * 0.3, y + 0.3, 0) * CFrame.Angles(0.3, rng:NextNumber(0, math.pi), 0.4), STONE, Enum.Material.Limestone)
	else
		part(parent, "Capital", Vector3.new(radius * 2.4, 0.8, radius * 2.4), base * CFrame.new(0, y + 0.4, 0), STONE, Enum.Material.Limestone)
		part(parent, "Abacus", Vector3.new(radius * 2.9, 0.8, radius * 2.9), base * CFrame.new(0, y + 1.2, 0), STONE_DARK, Enum.Material.Limestone)
	end
	-- Moss and a little coral clinging on.
	prop(parent, "Moss", Vector3.new(0.3, radius * 2.1, radius * 2.1), base * CFrame.new(0, 1.2, 0) * UPRIGHT, MOSS, Enum.Material.LeafyGrass, { shape = Enum.PartType.Cylinder })
	return height
end

-- Column drums lying where they fell.
local function fallenColumn(parent: Instance, ground: Vector3, yaw: number, drums: number, radius: number, rng: Random)
	local direction = CFrame.Angles(0, yaw, 0)
	for i = 0, drums - 1 do
		local cf = CFrame.new(ground + Vector3.new(0, radius, 0)) * direction * CFrame.new(i * 4.3, 0, rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0)
		part(parent, "FallenDrum", Vector3.new(4, radius * 2, radius * 2), cf, STONE:Lerp(STONE_DARK, rng:NextNumber(0, 0.4)), Enum.Material.Limestone, { shape = Enum.PartType.Cylinder })
	end
end

-- A clay amphora, upright or tipped over.
local function amphora(parent: Instance, ground: Vector3, rng: Random, tipped: boolean)
	local clay = Color3.fromRGB(196, 116, 72):Lerp(Color3.fromRGB(160, 100, 80), rng:NextNumber(0, 1))
	local base = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if tipped then
		base = CFrame.new(ground + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(0, 0, math.rad(80)) * CFrame.new(0, -1.1, 0)
	end
	prop(parent, "AmphoraBody", Vector3.new(2.2, 2.8, 2.2), base * CFrame.new(0, 1.5, 0), clay, Enum.Material.Slate, { shape = Enum.PartType.Ball })
	prop(parent, "AmphoraNeck", Vector3.new(1.4, 0.8, 0.8), base * CFrame.new(0, 3.2, 0) * UPRIGHT, clay, Enum.Material.Slate, { shape = Enum.PartType.Cylinder })
	prop(parent, "AmphoraLip", Vector3.new(0.3, 1.2, 1.2), base * CFrame.new(0, 3.9, 0) * UPRIGHT, clay, Enum.Material.Slate, { shape = Enum.PartType.Cylinder })
	for _, side in { -1, 1 } do
		prop(parent, "AmphoraHandle", Vector3.new(0.25, 1.2, 0.25), base * CFrame.new(side * 0.75, 3.1, 0) * CFrame.Angles(0, 0, side * 0.5), clay, Enum.Material.Slate)
	end
end

-- A ship's wheel: hub, eight spokes with handles, and a rim. `cf` is its centre, facing +Z.
local function shipWheel(parent: Instance, cf: CFrame, radius: number)
	prop(parent, "WheelHub", Vector3.new(0.8, radius * 0.4, radius * 0.4), cf * ALONG_Z, WOOD_DARK, Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
	for i = 0, 7 do
		local a = i * math.pi / 4
		local out = Vector3.new(math.cos(a), math.sin(a), 0)
		bar(parent, "WheelSpoke", cf:PointToWorldSpace(Vector3.zero), cf:PointToWorldSpace(out * radius * 1.3), 0.3, WOOD, Enum.Material.Wood)
	end
	for i = 0, 15 do
		local a1, a2 = i * math.pi / 8, (i + 1) * math.pi / 8
		bar(parent, "WheelRim", cf:PointToWorldSpace(Vector3.new(math.cos(a1), math.sin(a1), 0) * radius), cf:PointToWorldSpace(Vector3.new(math.cos(a2), math.sin(a2), 0) * radius), 0.4, WOOD, Enum.Material.Wood)
	end
end

local function anchor(parent: Instance, cf: CFrame, scale: number)
	local iron = Color3.fromRGB(120, 82, 66)
	prop(parent, "AnchorShank", Vector3.new(0.9, 10, 0.9) * scale, cf * CFrame.new(0, 5 * scale, 0), iron, Enum.Material.CorrodedMetal)
	prop(parent, "AnchorStock", Vector3.new(5, 0.8, 0.8) * scale, cf * CFrame.new(0, 9 * scale, 0), iron, Enum.Material.CorrodedMetal)
	prop(parent, "AnchorRing", Vector3.new(0.4, 2, 2) * scale, cf * CFrame.new(0, 10.8 * scale, 0) * ALONG_Z, iron, Enum.Material.CorrodedMetal, { shape = Enum.PartType.Cylinder })
	for _, side in { -1, 1 } do
		prop(parent, "AnchorArm", Vector3.new(4, 0.8, 0.8) * scale, cf * CFrame.new(side * 1.5 * scale, 1.2 * scale, 0) * CFrame.Angles(0, 0, side * math.rad(35)), iron, Enum.Material.CorrodedMetal)
		prop(parent, "AnchorFluke", Vector3.new(1.4, 1.4, 0.5) * scale, cf * CFrame.new(side * 3.1 * scale, 2.6 * scale, 0) * CFrame.Angles(0, 0, side * math.rad(35)), iron, Enum.Material.CorrodedMetal)
	end
end

-- A whirlpool teleport pad, like the lagoon's: stone ring, glowing pool, marker stones.
local function teleportPad(parent: Instance, position: Vector3, kind: string, action: string)
	local glow = Color3.fromRGB(90, 220, 240)
	local m = model(parent, "TeleportPad")
	part(m, "Ring", Vector3.new(0.6, 9, 9), CFrame.new(position + Vector3.new(0, 0.3, 0)) * UPRIGHT, ROCK, Enum.Material.Slate, { shape = Enum.PartType.Cylinder })
	local pool = part(m, "Pool", Vector3.new(0.1, 7.2, 7.2), CFrame.new(position + Vector3.new(0, 0.62, 0)) * UPRIGHT, glow, Enum.Material.Neon, { shape = Enum.PartType.Cylinder, transparency = 0.25 })
	pool.CanCollide = false
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2 + math.pi / 4
		local p = position + Vector3.new(math.cos(a), 0, math.sin(a)) * 4.2
		part(m, "MarkerStone", Vector3.new(0.9, 2.6, 0.9), CFrame.new(p + Vector3.new(0, 1.3, 0)), ROCK, Enum.Material.Basalt)
		prop(m, "MarkerGlow", Vector3.new(0.7, 0.7, 0.7), CFrame.new(p + Vector3.new(0, 2.8, 0)), glow, Enum.Material.Neon, { shape = Enum.PartType.Ball })
	end
	light(pool, glow, 12, 1.5)
	prompt(pool, kind, action, "Whirlpool", 8).Name = "TeleportPrompt"
end

---------------------------------------------------------------------------------------------
-- The places

local function buildGround(root: Instance, rng: Random)
	-- Its own seabed, a hair above the lagoon's so the two never fight where they overlap.
	part(root, "RuinsSeabed", Vector3.new(400, 4, 400), CFrame.new(RuinsConfig.center + Vector3.new(10, -1.85, 0)), SAND, Enum.Material.Sand)
	-- The sand road from the lagoon to the entrance and on in to the archway.
	local fromX, toX = RuinsConfig.roadFromX, at(40, 0, 0).X
	part(root, "Road", Vector3.new(toX - fromX, 0.3, 12), CFrame.new((fromX + toX) / 2, 0.3, 0), ROAD, Enum.Material.Sand)
	for x = fromX + 8, toX - 4, 6 do
		for _, side in { -1, 1 } do
			if rng:NextNumber() < 0.7 then
				local s = rng:NextNumber(0.8, 1.6)
				prop(root, "Pebble", Vector3.new(s, s * 0.4, s * 1.2), CFrame.new(x + rng:NextNumber(-1.5, 1.5), 0.35, side * (6.3 + rng:NextNumber(0, 0.8))) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(200, 196, 186), Enum.Material.Pebble)
			end
		end
	end
	-- Glowing jellyfish lamps along the road, swapping sides.
	for i, x in { fromX + 14, fromX + 44, fromX + 74 } do
		local side = if i % 2 == 0 then -1 else 1
		local p = Vector3.new(x, 0, side * 9)
		prop(root, "LampStalk", Vector3.new(7, 0.45, 0.45), CFrame.new(p + Vector3.new(0, 3.5, 0)) * UPRIGHT, Color3.fromRGB(70, 120, 60), Enum.Material.Grass, { shape = Enum.PartType.Cylinder })
		local bell = prop(root, "LampBell", Vector3.new(2.2, 2.2, 2.2), CFrame.new(p + Vector3.new(0, 7.5, 0)), GOLD, Enum.Material.Neon, { shape = Enum.PartType.Ball, transparency = 0.15 })
		light(bell, GOLD, 16, 0.9)
	end
	-- A ragged rim of big rocks round the zone, open on the lagoon side.
	for i = 1, 40 do
		local a = (i / 40) * math.pi * 2
		if math.abs(math.atan2(math.sin(a), math.cos(a))) > math.rad(28) then -- the frame's +X is the way in
			local d = rng:NextNumber(168, 186)
			boulder(root, at(math.cos(a) * d, 0, math.sin(a) * d), rng:NextNumber(12, 24), rng)
		end
	end
end

local function buildEntrance(root: Instance, rng: Random)
	local m = model(root, "Entrance")
	-- Two great pillars either side of the road, a lintel across, and the plaque.
	column(m, L(150, 0, -13), 24, 2.6, false, rng)
	column(m, L(150, 0, 13), 24, 2.6, false, rng)
	part(m, "Lintel", Vector3.new(5, 3, 34), L(150, 25.5, 0), STONE, Enum.Material.Limestone)
	local plaque = part(m, "Plaque", Vector3.new(22, 4, 0.8), L(150, 21.5, 0) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(40, 60, 80), Enum.Material.Slate, { collide = false })
	surfaceLabel(plaque, Enum.NormalId.Front, "SUNKEN RUINS", Color3.fromRGB(255, 220, 120))
	surfaceLabel(plaque, Enum.NormalId.Back, "TO THE LAGOON", Color3.fromRGB(180, 245, 255))
	for _, z in { -6, 6 } do
		bar(m, "Chain", L(150, 23.5, z).Position, L(150, 24.5, z * 0.9).Position, 0.25, Color3.fromRGB(90, 90, 90), Enum.Material.Metal)
	end
	-- Moss and kelp round the feet of the pillars, a fallen drum outside.
	for _, z in { -13, 13 } do
		kelp(m, L(146, 0, z + (if z > 0 then 4 else -4)).Position, rng, 1.4)
		tubes(m, L(154, 0, z * 1.25).Position, rng, CORALS[rng:NextInteger(1, #CORALS)])
	end
	fallenColumn(m, L(162, 0, 22).Position, 0.6, 3, 2.2, rng)

	-- Marlo the seal, the explorer who gives the missions, on a rock beside the road.
	local seatAt = RuinsConfig.Places.explorer
	local seat = part(m, "ExplorerRock", Vector3.new(1.4, 6, 6), CFrame.new(seatAt + Vector3.new(0, 0.7, 0)) * UPRIGHT, ROCK, Enum.Material.Slate, { shape = Enum.PartType.Cylinder })
	prompt(seat, "Explorer", "Talk", "Marlo the Explorer", 12)
	local face = CFrame.lookAt(seatAt + Vector3.new(0, 1.4, 0), at(150, 1.4, 0))
	RuinsWorld.buildMarlo(m, face)
	-- His mission board, leaning on a column drum.
	local board = part(m, "MissionBoard", Vector3.new(6, 4, 0.4), face * CFrame.new(5.5, 3.2, 1.5) * CFrame.Angles(0, math.rad(-20), 0) * CFrame.Angles(math.rad(-8), 0, 0), WOOD, Enum.Material.WoodPlanks)
	surfaceLabel(board, Enum.NormalId.Front, "EXPLORER'S\nMISSIONS", Color3.fromRGB(255, 230, 160))
	pillar(m, "BoardPost", face * CFrame.new(5.5, 0, 2.2), 2.6, 1.2, STONE_DARK, Enum.Material.Limestone)

	-- The whirlpool back to the shops; you land here when you teleport to the ruins.
	teleportPad(m, RuinsConfig.Places.pad, "TeleportShops", "Go to the shops")
end

-- Marlo: a grey seal in an explorer's pith helmet with a lantern. Tagged as a shopkeeper
-- (ReefConfig.Shopkeepers.Explorer), so the client's Shopkeepers module animates him and
-- shows his greetings. `base` is his footprint, facing the players (-Z).
function RuinsWorld.buildMarlo(parent: Instance, base: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Marlo"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local rootPart = prop(m, "Root", Vector3.new(1, 1, 1), base, Color3.new(), Enum.Material.SmoothPlastic, { transparency = 1 })
	m.PrimaryPart = rootPart
	local fur = Color3.fromRGB(150, 160, 170)
	local belly = Color3.fromRGB(210, 214, 208)
	local dark = Color3.fromRGB(40, 40, 46)
	local khaki = Color3.fromRGB(214, 190, 130)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?)
		return prop(m, name, size, base * offset, color, material or Enum.Material.SmoothPlastic, { shape = shape })
	end
	local BALL = Enum.PartType.Ball
	piece("Body", Vector3.new(3.4, 4.4, 3), CFrame.new(0, 2.4, 0.4), fur, BALL)
	piece("Belly", Vector3.new(2.6, 3.4, 1.6), CFrame.new(0, 2.2, -0.5), belly, BALL)
	piece("Tail", Vector3.new(3, 1.2, 2.2), CFrame.new(0, 0.6, 1.8), fur, BALL)
	local head = piece("Head", Vector3.new(2.6, 2.4, 2.4), CFrame.new(0, 5.2, -0.2), fur, BALL)
	piece("Snout", Vector3.new(1.4, 1, 1), CFrame.new(0, 4.8, -1.3), belly, BALL)
	piece("Nose", Vector3.new(0.45, 0.35, 0.3), CFrame.new(0, 5.05, -1.8), dark, BALL)
	for _, side in { -1, 1 } do
		piece("Eye", Vector3.new(0.45, 0.45, 0.45), CFrame.new(side * 0.55, 5.6, -1.15), dark, BALL)
		piece("Shine", Vector3.new(0.15, 0.15, 0.15), CFrame.new(side * 0.5, 5.7, -1.35), Color3.new(1, 1, 1), BALL, Enum.Material.Neon)
		piece("Flipper", Vector3.new(0.5, 2, 1.1), CFrame.new(side * 1.8, 2.6, -0.4) * CFrame.Angles(0, 0, side * 0.5), fur:Lerp(dark, 0.2), BALL)
		for k = -1, 1 do
			piece("Whisker", Vector3.new(1.2, 0.06, 0.06), CFrame.new(side * 1.05, 4.75 + k * 0.12, -1.55) * CFrame.Angles(0, side * 0.15, k * 0.15), Color3.fromRGB(240, 240, 240))
		end
	end
	-- Pith helmet: a khaki dome over a wide brim, with a band.
	piece("Brim", Vector3.new(0.2, 3.6, 3.6), CFrame.new(0, 6.2, -0.1) * UPRIGHT, khaki, Enum.PartType.Cylinder, Enum.Material.Fabric)
	piece("Helmet", Vector3.new(2.4, 1.6, 2.4), CFrame.new(0, 6.55, -0.1), khaki, BALL, Enum.Material.Fabric)
	piece("Band", Vector3.new(0.3, 2.45, 2.45), CFrame.new(0, 6.35, -0.1) * UPRIGHT, Color3.fromRGB(120, 80, 50), Enum.PartType.Cylinder, Enum.Material.Fabric)
	-- A satchel strap and a lantern hanging from one flipper.
	piece("Strap", Vector3.new(0.3, 4, 0.3), CFrame.new(0, 2.8, -1) * CFrame.Angles(0, 0, 0.6), Color3.fromRGB(120, 80, 50), nil, Enum.Material.Leather)
	piece("Satchel", Vector3.new(1.2, 1, 0.6), CFrame.new(1.2, 1.4, -0.9), Color3.fromRGB(140, 96, 60), nil, Enum.Material.Leather)
	local lantern = piece("Lantern", Vector3.new(0.7, 0.9, 0.7), CFrame.new(-2.3, 1.4, -0.9), Color3.fromRGB(255, 210, 120), nil, Enum.Material.Neon)
	light(lantern, Color3.fromRGB(255, 210, 140), 12, 1.5)
	m.Parent = parent
	head.Name = "Head"
	m:SetAttribute("Shopkeeper", "Explorer")
	m:AddTag(ReefConfig.SHOPKEEPER_TAG)
	return m
end

local function buildArchway(root: Instance, rng: Random)
	local m = model(root, "Archway")
	-- Piers either side of the road, a half-ring of stones over it (the road runs along X,
	-- so the arch stands in the frame's YZ plane), and stones that fell out of it.
	local x, span, rise = 60, 12, 12
	for _, side in { -1, 1 } do
		part(m, "Pier", Vector3.new(5, rise, 5), L(x, rise / 2, side * span), STONE:Lerp(STONE_DARK, 0.2), Enum.Material.Limestone)
		kelp(m, L(x + 3, 0, side * (span + 3)).Position, rng, 1.3)
	end
	for i = 0, 12 do
		local a = math.pi * i / 12
		if i ~= 3 then -- one stone fell out
			part(m, "ArchStone", Vector3.new(5, 4, 3.4), L(x, rise + math.sin(a) * span, math.cos(a) * span) * CFrame.Angles(a - math.pi / 2, 0, 0), STONE:Lerp(STONE_DARK, rng:NextNumber(0, 0.4)), Enum.Material.Limestone)
		end
	end
	-- A flat cap stone on top, where the Archtop Chest sits.
	part(m, "CapStone", Vector3.new(6, 1, 5), L(x, rise + span + 2.5, 0), STONE, Enum.Material.Limestone)
	part(m, "FallenStone", Vector3.new(5, 4, 3.4), L(x - 6, 1.7, 9) * CFrame.Angles(0.4, 0.8, 0.2), STONE_DARK, Enum.Material.Limestone)
	branchCoral(m, L(x, rise + span + 3, 2.2).Position, rng, CORALS[2], 0.8)
end

-- The terrace: a stone block with sandy top and a cliff of rocks along its front, steps up
-- the middle of its south face.
local function buildTerrace(root: Instance, rng: Random)
	local m = model(root, "Terrace")
	local t = RuinsConfig.Terrace
	local top = RuinsConfig.TERRACE_TOP
	local w, d = t.maxX - t.minX, t.maxZ - t.minZ
	local cx, cz = (t.minX + t.maxX) / 2, (t.minZ + t.maxZ) / 2
	part(m, "TerraceRock", Vector3.new(w, top, d), L(cx, top / 2, cz), CLIFF, Enum.Material.Sandstone)
	part(m, "TerraceSand", Vector3.new(w - 2, 0.3, d - 2), L(cx, top + 0.05, cz), SAND, Enum.Material.Sand)
	-- Cliff rocks along the open sides, leaving the steps clear.
	for x = t.minX + 3, t.maxX - 3, 7 do
		if math.abs(x - t.stepsX) > t.stepsWidth / 2 + 3 then
			local s = rng:NextNumber(6, 9)
			part(m, "CliffRock", Vector3.new(s, top * rng:NextNumber(0.7, 1), s * 0.7), L(x, top * 0.4, t.maxZ + 1) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.2, 0.2)), CLIFF:Lerp(ROCK, rng:NextNumber(0.1, 0.5)), Enum.Material.Slate)
		end
	end
	for z = t.minZ + 3, t.maxZ - 3, 8 do
		for _, x in { t.minX - 1, t.maxX + 1 } do
			local s = rng:NextNumber(6, 9)
			part(m, "CliffRock", Vector3.new(s * 0.7, top * rng:NextNumber(0.7, 1), s), L(x, top * 0.4, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.2, 0.2)), CLIFF:Lerp(ROCK, rng:NextNumber(0.1, 0.5)), Enum.Material.Slate)
		end
	end
	-- The steps: one stud up each, two deep, mossy on top like the reference art's stair.
	for i = 1, top do
		local zFront = t.maxZ + 2 * (top - i + 1)
		part(m, "Step", Vector3.new(t.stepsWidth, i, 2), L(t.stepsX, i / 2, zFront - 1), STONE:Lerp(STONE_DARK, (i % 3) * 0.12), Enum.Material.Limestone)
		if i % 2 == 0 then
			prop(m, "StepMoss", Vector3.new(t.stepsWidth * rng:NextNumber(0.3, 0.7), 0.12, 1.2), L(t.stepsX + rng:NextNumber(-4, 4), i + 0.06, zFront - 1), MOSS, Enum.Material.LeafyGrass)
		end
	end
	for _, side in { -1, 1 } do
		part(m, "StepWall", Vector3.new(1.6, top + 1.5, 2 * top), L(t.stepsX + side * (t.stepsWidth / 2 + 0.8), (top + 1.5) / 2, t.maxZ + top), STONE_DARK, Enum.Material.Limestone)
	end
	-- Broken columns along the front edge, and fallen ones below.
	-- (Kept off the line of sight from the steps to the mermaid statue.)
	for _, x in { -114, -96, -47, -12 } do
		column(m, L(x, top, -45), rng:NextNumber(6, 13), 1.6, true, rng)
	end
	fallenColumn(m, L(-110, 0, -26).Position, 0.3, 3, 1.6, rng)
	fallenColumn(m, L(-30, 0, -30).Position, 2.2, 2, 1.6, rng)
	-- Coral and kelp up on the terrace and at its foot.
	coralPatch(m, L(-100, top, -60).Position, 10, rng, 14)
	coralPatch(m, L(-20, top, -95).Position, 10, rng, 12)
	coralPatch(m, L(-95, 0, -30).Position, 12, rng, 14)
	coralPatch(m, L(-35, 0, -28).Position, 12, rng, 14)
	for _ = 1, 5 do
		amphora(m, L(rng:NextNumber(-115, -90), top, rng:NextNumber(-115, -100)).Position, rng, rng:NextNumber() < 0.5)
	end
end

-- The temple on the terrace: a stepped floor, a ring of columns (some broken), part of the
-- roof beam and gable, and the walled sanctum in the middle with its altar.
local function buildTemple(root: Instance, rng: Random)
	local m = model(root, "Temple")
	local top = RuinsConfig.TERRACE_TOP
	local floor = top + 2
	part(m, "Stylobate", Vector3.new(50, 1, 36), L(-65, top + 0.5, -90), STONE_DARK, Enum.Material.Limestone)
	part(m, "Stylobate", Vector3.new(46, 1, 32), L(-65, top + 1.5, -90), STONE, Enum.Material.Limestone)
	-- Columns: front and back rows, and the sides. Heights below 16 are broken.
	local heights = { 16, 16, 9, 16, 5, 16, 16, 12, 16, 16, 3, 16 }
	local n = 0
	for _, z in { -76.5, -103.5 } do
		for x = -85, -45, 8 do
			n += 1
			local h = heights[(n - 1) % #heights + 1]
			column(m, L(x, floor, z), h, 1.7, h < 16, rng)
		end
	end
	for _, x in { -85, -45 } do
		for _, z in { -85.5, -94.5 } do
			column(m, L(x, floor, z), 16, 1.7, false, rng)
		end
	end
	-- What's left of the roof beam (over the back row and one side) and the gable at the back.
	local beamY = floor + 16 + 1.2
	part(m, "Architrave", Vector3.new(44, 1.8, 4.4), L(-65, beamY, -103.5), STONE, Enum.Material.Limestone)
	part(m, "Architrave", Vector3.new(4.4, 1.8, 31), L(-45, beamY, -90), STONE, Enum.Material.Limestone)
	part(m, "Architrave", Vector3.new(12, 1.8, 4.4), L(-81, beamY, -76.5), STONE, Enum.Material.Limestone)
	for _, side in { -1, 1 } do
		-- A wedge is tallest at its +Z end; turn each so that end meets in the middle.
		part(m, "Gable", Vector3.new(4, 6, 22), L(-65 + side * 11, beamY + 3.9, -103.5) * CFrame.Angles(0, math.rad(-90 * side), 0), STONE, Enum.Material.Limestone, { wedge = true })
	end
	-- Fallen beam pieces and drums on the floor.
	part(m, "FallenBeam", Vector3.new(14, 1.8, 4.2), L(-62, floor + 0.9, -70) * CFrame.Angles(0, 0.3, 0.05), STONE_DARK, Enum.Material.Limestone)
	fallenColumn(m, L(-58, floor, -79).Position, 1.9, 2, 1.7, rng)

	-- The sanctum: four walls with a doorway facing the steps, half its roof fallen in.
	local wallH = 10
	local sx1, sx2, sz1, sz2 = -77, -53, -101, -82
	local function wall(name: string, size: Vector3, cf: CFrame)
		part(m, name, size, cf, STONE:Lerp(STONE_DARK, 0.25), Enum.Material.Limestone)
	end
	wall("SanctumWall", Vector3.new(sx2 - sx1, wallH, 1.2), L(-65, floor + wallH / 2, sz1))
	wall("SanctumWall", Vector3.new(1.2, wallH, sz2 - sz1), L(sx1, floor + wallH / 2, (sz1 + sz2) / 2))
	wall("SanctumWall", Vector3.new(1.2, wallH, sz2 - sz1), L(sx2, floor + wallH / 2, (sz1 + sz2) / 2))
	local door = 7
	wall("SanctumWall", Vector3.new((sx2 - sx1 - door) / 2, wallH, 1.2), L(sx1 + (sx2 - sx1 - door) / 4, floor + wallH / 2, sz2))
	wall("SanctumWall", Vector3.new((sx2 - sx1 - door) / 2, wallH, 1.2), L(sx2 - (sx2 - sx1 - door) / 4, floor + wallH / 2, sz2))
	wall("Lintel", Vector3.new(door + 2, 2, 1.4), L(-65, floor + wallH - 1, sz2))
	wall("SanctumRoof", Vector3.new(sx2 - sx1 + 1, 1, 9), L(-65, floor + wallH + 0.5, sz1 + 4.5))
	part(m, "FallenRoof", Vector3.new(10, 1, 7), L(-68, floor + 1.2, -88) * CFrame.Angles(0.25, 0.4, 0.15), STONE_DARK, Enum.Material.Limestone)
	-- The altar, with glowing runes along its front, and a soft light in the gloom.
	local altar = part(m, "Altar", Vector3.new(7, 1.6, 3), L(-65, floor + 0.8, -97.5), MARBLE, Enum.Material.Marble)
	prop(m, "AltarRunes", Vector3.new(6, 0.25, 0.1), L(-65, floor + 0.9, -95.95), Color3.fromRGB(120, 230, 255), Enum.Material.Neon)
	light(altar, Color3.fromRGB(150, 220, 255), 18, 1.2)
	tubes(m, L(-74, floor, -84).Position, rng, CORALS[1])
	kelp(m, L(-55, floor, -84).Position, rng, 1.1)
end

-- The mermaid statue beside the top of the steps: a round pedestal, a great clam shell
-- behind, and a stone mermaid sitting with her harp.
local function buildStatue(root: Instance, rng: Random)
	local m = model(root, "MermaidStatue")
	local p = RuinsConfig.Places.statue
	local ground = F.Rotation + p
	part(m, "Pedestal", Vector3.new(3, 11, 11), ground * CFrame.new(0, 1.5, 0) * UPRIGHT, STONE_DARK, Enum.Material.Limestone, { shape = Enum.PartType.Cylinder })
	prop(m, "PedestalRim", Vector3.new(0.5, 11.4, 11.4), ground * CFrame.new(0, 3, 0) * UPRIGHT, STONE, Enum.Material.Limestone, { shape = Enum.PartType.Cylinder })
	-- She faces the frame's +Z, out over the steps. Everything below is drawn at K times the
	-- sizes written, scaled about the middle of the pedestal top.
	local K = 1.7
	local M = ground * CFrame.new(0, 3, 0)
	local TAIL = Color3.fromRGB(170, 214, 206) -- a greener stone, so the tail reads as a tail
	local function scaled(offset: CFrame): CFrame
		return M * (CFrame.new(offset.Position * K) * offset.Rotation)
	end
	local function stone(name: string, size: Vector3, offset: CFrame, shape: Enum.PartType?, color: Color3?)
		part(m, name, size * K, scaled(offset), color or MARBLE, Enum.Material.Marble, { shape = shape })
	end
	local BALL = Enum.PartType.Ball
	-- The shell: ribs fanning out from a hinge behind her.
	for k = 0, 8 do
		local a = math.rad(-80 + k * 20)
		stone("ShellRib", Vector3.new(1.6, 9, 0.7), CFrame.new(0, 0.5, -2.6) * CFrame.Angles(0, 0, -a) * CFrame.new(0, 4.5, 0), nil, Color3.fromRGB(232, 214, 210):Lerp(MARBLE, (k % 2) * 0.5))
	end
	stone("ShellHinge", Vector3.new(2.4, 1.6, 1.6), CFrame.new(0, 0.6, -2.6), BALL)
	-- Her tail, curling forward and round to a fluke.
	stone("Hips", Vector3.new(2.4, 1.8, 2), CFrame.new(0, 1.1, -0.6), BALL, TAIL)
	local tail = { Vector3.new(0.6, 0.8, 0.6), Vector3.new(1.3, 0.6, 1.5), Vector3.new(2, 0.5, 2.2), Vector3.new(2.5, 0.6, 2.8) }
	for i, offset in tail do
		local s = 1.8 - i * 0.3
		stone("Tail", Vector3.new(s, s * 0.8, s), CFrame.new(offset), BALL, TAIL)
	end
	stone("Fluke", Vector3.new(2.2, 0.3, 1.2), CFrame.new(2.9, 1.1, 3.4) * CFrame.Angles(0.5, 0.6, 0.4), nil, TAIL)
	-- Body, head and flowing hair.
	stone("Torso", Vector3.new(1.8, 2.8, 1.3), CFrame.new(0, 3, -0.6), BALL)
	stone("Head", Vector3.new(1.5, 1.6, 1.5), CFrame.new(0, 5, -0.5), BALL)
	stone("Hair", Vector3.new(1.7, 1.6, 1.4), CFrame.new(0, 5.2, -0.9), BALL)
	stone("HairFlow", Vector3.new(1.4, 3, 0.6), CFrame.new(0.2, 3.8, -1.4) * CFrame.Angles(0.15, 0, -0.1))
	for _, side in { -1, 1 } do
		stone("Arm", Vector3.new(0.5, 2.2, 0.5), CFrame.new(side * 1.1, 3.2, -0.1) * CFrame.Angles(-0.6, 0, side * 0.35))
	end
	-- The harp, held on her left.
	local harpColor = GOLD:Lerp(MARBLE, 0.6)
	local function h(x: number, y: number, z: number): Vector3
		return scaled(CFrame.new(-1.6 + x, 3.6 + y, 0.8 + z)).Position
	end
	bar(m, "HarpArm", h(0, -1.4, 0), h(0, 1.4, 0.2), 0.3 * K, harpColor, Enum.Material.Marble)
	bar(m, "HarpArm", h(0, -1.4, 0), h(-1.2, 1.2, 0), 0.3 * K, harpColor, Enum.Material.Marble)
	bar(m, "HarpTop", h(-1.2, 1.2, 0), h(0, 1.4, 0.2), 0.25 * K, harpColor, Enum.Material.Marble)
	for k = 1, 3 do
		bar(m, "HarpString", h(-0.3 * k, -1.1 + k * 0.1, 0), h(-0.3 * k, 1.2, 0.05), 0.08, Color3.fromRGB(240, 240, 230), Enum.Material.Marble)
	end
	-- An urn tipped over at her side, and a ring of coral round the pedestal (not on it).
	amphora(m, (ground * CFrame.new(7.5, 0, 3)).Position, rng, true)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + 0.3
		if math.sin(a) < 0.2 then -- not in front of her (+Z), where it would hide her
			coralPatch(m, (ground * CFrame.new(math.cos(a) * 9, 0, math.sin(a) * 9)).Position, 2.5, rng, 3)
		end
	end
end

-- The tallest column, standing alone near the terrace's west end; the Old Spyglass is on top.
local function buildTallColumn(root: Instance, rng: Random)
	local m = model(root, "TallColumn")
	local p = RuinsConfig.Places.tallColumn
	local base = F.Rotation + p
	-- Plinth (0.8) + drums + capital (1.6) + a flat top block (0.2): its top is at p.Y + 26.6.
	column(m, base, 26.4, 2, false, rng)
	part(m, "Top", Vector3.new(5, 0.2, 5), base * CFrame.new(0, 26.5, 0), STONE, Enum.Material.Limestone)
	kelp(m, (base * CFrame.new(3, 0, 2)).Position, rng, 2)
end

-- The pirate ship: a hollow hull you can swim into through two holes and two deck hatches,
-- a sterncastle with the wheel, three masts (one snapped), cannons, and a rock under the bow.
local function buildShip(root: Instance, rng: Random)
	local m = model(root, "PirateShip")
	local s = RuinsConfig.Ship
	local S = s.frame
	local len, wid, h = s.length, s.width, s.height
	local half = len / 2
	local function sp(x: number, y: number, z: number): CFrame
		return S * CFrame.new(x, y, z)
	end
	local plank = function(i: number): Color3
		return WOOD:Lerp(WOOD_DARK, (i % 3) * 0.2)
	end

	part(m, "Floor", Vector3.new(len, 1, wid - 1), sp(0, 0.5, 0), WOOD_DARK, Enum.Material.WoodPlanks)
	-- Sides, solid except for the holes (x, width, bottom, top), in planked bands.
	local gaps = {
		[1] = { { x = -5, width = 8, bottom = 2, top = 10 } },
		[-1] = { { x = 12, width = 9, bottom = 2, top = 11 } },
	}
	for _, side in { 1, -1 } do
		local z = side * (wid / 2 - 0.5)
		local function wall(fromX: number, toX: number, bottom: number, top: number)
			if toX - fromX > 0.05 and top - bottom > 0.05 then
				part(m, "Hull", Vector3.new(toX - fromX, top - bottom, 1), sp((fromX + toX) / 2, (bottom + top) / 2, z), plank(math.floor(bottom)), Enum.Material.WoodPlanks)
			end
		end
		local x = -half
		for _, gap in gaps[side] do
			local left, right = gap.x - gap.width / 2, gap.x + gap.width / 2
			wall(x, left, 0, h)
			wall(left, right, 0, gap.bottom)
			wall(left, right, gap.top, h)
			-- Splintered plank ends round the hole.
			for k = 1, 3 do
				prop(m, "Splinter", Vector3.new(0.4, rng:NextNumber(1.5, 3), 0.3), sp(left + rng:NextNumber(0, gap.width), gap.top - 0.5, z) * CFrame.Angles(0, 0, rng:NextNumber(-0.6, 0.6)), WOOD_DARK, Enum.Material.Wood)
			end
			x = right
		end
		wall(x, half, 0, h)
		-- A dark wale strip and cannons poking out of their ports.
		prop(m, "Wale", Vector3.new(len, 0.8, 0.2), sp(0, h - 3, z + side * 0.6), WOOD_DARK, Enum.Material.Wood)
		for _, cx in { -20, 0, 20 } do
			local hole = gaps[side][1]
			if math.abs(cx - hole.x) > hole.width / 2 + 2 then
				prop(m, "Cannon", Vector3.new(4, 1.1, 1.1), sp(cx, 9, z + side * 1.6) * ALONG_Z, Color3.fromRGB(40, 40, 44), Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
				prop(m, "GunPort", Vector3.new(2, 2, 0.15), sp(cx, 9, z + side * 0.58), Color3.fromRGB(30, 24, 20), Enum.Material.Wood)
			end
		end
		-- Weed and barnacles.
		for _ = 1, 6 do
			prop(m, "Weed", Vector3.new(rng:NextNumber(3, 7), rng:NextNumber(1.5, 3), 0.15), sp(rng:NextNumber(-half + 4, half - 4), rng:NextNumber(2, 8), z + side * 0.62), MOSS, Enum.Material.Grass)
		end
	end
	part(m, "Stern", Vector3.new(1, h, wid - 2), sp(-half + 0.5, h / 2, 0), WOOD, Enum.Material.WoodPlanks)
	local bowSize = wid / math.sqrt(2)
	part(m, "Bow", Vector3.new(bowSize, h, bowSize), sp(half, h / 2, 0) * CFrame.Angles(0, math.rad(45), 0), WOOD, Enum.Material.WoodPlanks)
	bar(m, "Bowsprit", sp(half + 5, h - 1, 0).Position, sp(half + 22, h + 7, 0).Position, 0.9, WOOD_DARK, Enum.Material.Wood)

	-- The deck, open at two hatches; a rail round it.
	local hatches = { { x = -10, width = 7 }, { x = 18, width = 7 } }
	local x = -half
	for _, hatch in hatches do
		local left = hatch.x - hatch.width / 2
		part(m, "Deck", Vector3.new(left - x, 1, wid), sp((x + left) / 2, h - 0.5, 0), WOOD, Enum.Material.WoodPlanks)
		x = hatch.x + hatch.width / 2
	end
	part(m, "Deck", Vector3.new(half - x, 1, wid), sp((x + half) / 2, h - 0.5, 0), WOOD, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		prop(m, "Rail", Vector3.new(len - 4, 0.4, 0.4), sp(2, h + 1.6, side * (wid / 2 - 0.3)), WOOD_DARK, Enum.Material.Wood)
		for px = -half + 16, half - 4, 6 do
			prop(m, "RailPost", Vector3.new(0.4, 1.6, 0.4), sp(px, h + 0.8, side * (wid / 2 - 0.3)), WOOD_DARK, Enum.Material.Wood)
		end
	end

	-- The sterncastle, with windows, a rail and the ship's wheel.
	part(m, "Sterncastle", Vector3.new(14, 5, wid), sp(-half + 7, h + 2.5, 0), WOOD, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		for k = 0, 2 do
			prop(m, "CabinWindow", Vector3.new(1.6, 1.4, 0.15), sp(-half + 3 + k * 4, h + 2.6, side * (wid / 2 + 0.05)), Color3.fromRGB(255, 200, 120), Enum.Material.Neon, { transparency = 0.3 })
		end
	end
	prop(m, "SternWindows", Vector3.new(0.15, 1.6, wid - 6), sp(-half - 0.05, h + 2.6, 0), Color3.fromRGB(40, 52, 64), Enum.Material.Glass)
	prop(m, "WheelPost", Vector3.new(0.6, 2.4, 0.6), sp(-half + 11, h + 6.2, 0), WOOD_DARK, Enum.Material.Wood)
	shipWheel(m, sp(-half + 11, h + 7.6, 0) * CFrame.Angles(0, math.rad(90), 0), 1.6)

	-- Masts: the fore mast whole with a torn sail, the main snapped (its top lies on the
	-- deck), the mizzen short on the sterncastle.
	local sail = Color3.fromRGB(226, 214, 180)
	pillar(m, "ForeMast", sp(22, h, 0), 30, 0.7, WOOD_DARK, Enum.Material.Wood)
	bar(m, "Yard", sp(22, h + 22, -9).Position, sp(22, h + 22, 9).Position, 0.5, WOOD_DARK, Enum.Material.Wood)
	bar(m, "Yard", sp(22, h + 12, -10).Position, sp(22, h + 12, 10).Position, 0.5, WOOD_DARK, Enum.Material.Wood)
	prop(m, "Sail", Vector3.new(0.2, 9, 7), sp(22.4, h + 17, -5), sail, Enum.Material.Fabric)
	prop(m, "Sail", Vector3.new(0.2, 6, 6), sp(22.4, h + 18.5, 5), sail, Enum.Material.Fabric)
	prop(m, "SailTatter", Vector3.new(0.2, 3, 3), sp(22.4, h + 13.5, 6) * CFrame.Angles(0.5, 0, 0), sail, Enum.Material.Fabric)
	prop(m, "CrowsNest", Vector3.new(1.4, 4, 4), sp(22, h + 26, 0) * UPRIGHT, WOOD, Enum.Material.WoodPlanks, { shape = Enum.PartType.Cylinder })
	prop(m, "Flag", Vector3.new(0.1, 2.2, 3.4), sp(22, h + 29, 1.8), Color3.fromRGB(26, 26, 30), Enum.Material.Fabric)
	pillar(m, "MainMast", sp(2, h, 0), 13, 0.9, WOOD_DARK, Enum.Material.Wood)
	prop(m, "Snapped", Vector3.new(1.6, 1.2, 1.2), sp(2.3, h + 13.3, 0) * CFrame.Angles(0.4, 0, 0.5), WOOD, Enum.Material.Wood)
	prop(m, "FallenMast", Vector3.new(24, 1.6, 1.6), sp(8, h + 1.4, 3) * CFrame.Angles(0, math.rad(25), math.rad(-6)), WOOD_DARK, Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
	pillar(m, "MizzenMast", sp(-half + 5, h + 5, 0), 14, 0.55, WOOD_DARK, Enum.Material.Wood)
	prop(m, "Sail", Vector3.new(0.2, 5, 6), sp(-half + 5.4, h + 13, 0) * CFrame.Angles(0.1, 0, 0), sail, Enum.Material.Fabric)

	-- The hold: crates, barrels and a lantern, plus what the chest and the compass sit among.
	for i = 1, 5 do
		local c = rng:NextNumber(2.2, 3.2)
		part(m, "Crate", Vector3.new(c, c, c), sp(rng:NextNumber(-28, 28), 1 + c / 2, rng:NextNumber(-5.5, 5.5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.2, 0.2)), Color3.fromRGB(150, 110, 76), Enum.Material.WoodPlanks)
		if i <= 3 then
			pillar(m, "Barrel", sp(rng:NextNumber(-28, 28), 1, rng:NextNumber(-6, 6)), 2.8, 1.1, WOOD, Enum.Material.Wood)
		end
	end
	local lantern = prop(m, "HoldLantern", Vector3.new(0.8, 1.2, 0.8), sp(-8, h - 2.5, 0), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
	light(lantern, Color3.fromRGB(255, 200, 140), 24, 1.4)
	local lantern2 = prop(m, "HoldLantern", Vector3.new(0.8, 1.2, 0.8), sp(16, h - 2.5, 0), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
	light(lantern2, Color3.fromRGB(255, 200, 140), 24, 1.4)

	-- The rock the bow rests on.
	local under = sp(half - 6, 0, 0).Position
	boulder(m, Vector3.new(under.X, 0, under.Z), 14, rng)
	boulder(m, Vector3.new(under.X, 0, under.Z) + F.LookVector * 6, 9, rng)
	-- Coral already growing round the wreck, and kelp the sea dragon hides in.
	coralPatch(m, sp(-10, 0, 16).Position * Vector3.new(1, 0, 1), 12, rng, 18)
	coralPatch(m, sp(10, 0, -16).Position * Vector3.new(1, 0, 1), 12, rng, 14)
	for _ = 1, 8 do
		local p = sp(rng:NextNumber(-half, half), 0, (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(12, 24)).Position
		kelp(m, Vector3.new(p.X, 0, p.Z), rng, rng:NextNumber(1.3, 2.2))
	end
end

-- The cave: a hollow hill with one tunnel in, dark but for crystals and glowing mushrooms.
local function buildCave(root: Instance, rng: Random)
	local m = model(root, "Cave")
	local c = RuinsConfig.Cave
	local center = RuinsConfig.Places.cave
	local C = F.Rotation + center -- the frame's +X is the tunnel, towards the entrance
	local wallH = c.height + 2
	local gap = math.asin((c.tunnelWidth / 2 + 0.5) / c.radius)
	local segments = 22
	-- The ring wall, open where the tunnel comes in.
	for i = 0, segments - 1 do
		local a = (i + 0.5) / segments * math.pi * 2
		local wrapped = math.atan2(math.sin(a), math.cos(a))
		if math.abs(wrapped) > gap + 0.05 then
			local r = c.radius + 2.5
			local width = 2 * math.pi * r / segments + 1.5
			part(m, "CaveWall", Vector3.new(5, wallH, width), C * CFrame.Angles(0, -a, 0) * CFrame.new(r, wallH / 2, 0), ROCK:Lerp(Color3.fromRGB(60, 66, 80), rng:NextNumber(0, 0.5)), Enum.Material.Slate)
		end
	end
	part(m, "CaveFloor", Vector3.new(0.2, c.radius * 2 + 2, c.radius * 2 + 2), C * CFrame.new(0, 0.2, 0) * UPRIGHT, Color3.fromRGB(80, 86, 98), Enum.Material.Slate, { shape = Enum.PartType.Cylinder })
	part(m, "CaveRoof", Vector3.new(4, c.radius * 2 + 12, c.radius * 2 + 12), C * CFrame.new(0, c.height + 2, 0) * UPRIGHT, ROCK, Enum.Material.Slate, { shape = Enum.PartType.Cylinder })
	-- The tunnel.
	local tunnelX = c.radius + c.tunnelLength / 2
	for _, side in { -1, 1 } do
		part(m, "TunnelWall", Vector3.new(c.tunnelLength + 4, c.tunnelHeight + 2, 3), C * CFrame.new(tunnelX, (c.tunnelHeight + 2) / 2, side * (c.tunnelWidth / 2 + 1.5)), ROCK, Enum.Material.Slate)
	end
	part(m, "TunnelRoof", Vector3.new(c.tunnelLength + 4, 3, c.tunnelWidth + 6), C * CFrame.new(tunnelX, c.tunnelHeight + 1.5, 0), ROCK, Enum.Material.Slate)
	-- The hill heaped over it all, kept off the tunnel mouth.
	for i = 1, 34 do
		local a = rng:NextNumber(0, math.pi * 2)
		local wrapped = math.atan2(math.sin(a), math.cos(a))
		local d = rng:NextNumber(c.radius + 6, c.radius + 16)
		if math.abs(wrapped) > 0.75 then
			local p = (C * CFrame.new(math.cos(a) * d, 0, math.sin(a) * d)).Position
			boulder(m, p, rng:NextNumber(10, 18) * (1 - (d - c.radius) / 30), rng)
		end
		if i <= 12 then
			local ta = rng:NextNumber(0, math.pi * 2)
			local td = rng:NextNumber(0, c.radius)
			boulder(m, (C * CFrame.new(math.cos(ta) * td, c.height + 3, math.sin(ta) * td)).Position, rng:NextNumber(8, 14), rng)
		end
	end
	-- Rocks framing the mouth, kelp outside it.
	for _, side in { -1, 1 } do
		boulder(m, (C * CFrame.new(c.radius + c.tunnelLength + 2, 0, side * (c.tunnelWidth / 2 + 5))).Position, 10, rng)
		kelp(m, (C * CFrame.new(c.radius + c.tunnelLength + 6, 0, side * (c.tunnelWidth / 2 + 2))).Position, rng, 1.5)
	end
	-- Crystals on the walls and floor, and glowing mushrooms.
	local crystalColors = { Color3.fromRGB(170, 110, 255), Color3.fromRGB(90, 220, 255), Color3.fromRGB(140, 255, 220) }
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2 + 0.3
		if math.abs(math.atan2(math.sin(a), math.cos(a))) > gap + 0.2 then
			local color = crystalColors[i % 3 + 1]
			local base = C * CFrame.Angles(0, -a, 0) * CFrame.new(c.radius - 1.2, 0.5, 0)
			for k = 1, 3 do
				local hgt = rng:NextNumber(2, 5)
				local shard = prop(m, "Crystal", Vector3.new(0.9, hgt, 0.9), base * CFrame.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-1.2, 1.2)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 1), rng:NextNumber(-0.4, 0.4)) * CFrame.new(0, hgt / 2, 0), color, Enum.Material.Neon, { transparency = 0.15 })
				if k == 1 then
					light(shard, color, 14, 1)
				end
			end
		end
	end
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(5, c.radius - 3)
		local base = C * CFrame.new(math.cos(a) * d, 0.5, math.sin(a) * d)
		prop(m, "MushroomStem", Vector3.new(1.2, 0.35, 0.35), base * CFrame.new(0, 0.6, 0) * UPRIGHT, Color3.fromRGB(220, 230, 240), Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder })
		prop(m, "MushroomCap", Vector3.new(1.4, 0.6, 1.4), base * CFrame.new(0, 1.3, 0), Color3.fromRGB(110, 255, 200), Enum.Material.Neon, { shape = Enum.PartType.Ball })
	end
	-- A rock shelf at the back for the Crystal Trident.
	part(m, "TridentShelf", Vector3.new(4, 1, 4), (F.Rotation + RuinsConfig.Relics.list[5].at) * CFrame.new(0, -0.5, 0), ROCK, Enum.Material.Slate)
end

-- The coral garden: the treasure trove from the reference art (a huge open chest spilling
-- gold), a giant anchor, a ship's wheel half sunk in the sand, and coral everywhere.
local function buildGarden(root: Instance, rng: Random)
	local m = model(root, "CoralGarden")
	local troveAt = L(-92, 0, 20) * CFrame.Angles(0, math.rad(-30), 0)
	local red = Color3.fromRGB(150, 50, 44)
	part(m, "TroveBox", Vector3.new(9, 5, 6), troveAt * CFrame.new(0, 2.5, 0), red, Enum.Material.WoodPlanks)
	part(m, "TroveLid", Vector3.new(9.2, 1.4, 6.2), troveAt * CFrame.new(0, 7, -4) * CFrame.Angles(math.rad(-70), 0, 0), red:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.WoodPlanks)
	for _, bx in { -4.3, 0, 4.3 } do
		prop(m, "TroveBand", Vector3.new(0.6, 5.2, 6.3), troveAt * CFrame.new(bx, 2.6, 0), GOLD, Enum.Material.Foil)
	end
	local coins = prop(m, "TroveGold", Vector3.new(8.4, 2.6, 5.4), troveAt * CFrame.new(0, 5, 0), GOLD, Enum.Material.Foil, { shape = Enum.PartType.Ball })
	light(coins, GOLD, 20, 1.6)
	sparkles(coins, GOLD, 6)
	-- Coins and gems spilled over the sand in front.
	for _ = 1, 28 do
		local p = troveAt * CFrame.new(rng:NextNumber(-6, 6), 0.15, rng:NextNumber(3, 9))
		prop(m, "Coin", Vector3.new(0.12, 0.8, 0.8), p * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), math.rad(90)), GOLD, Enum.Material.Foil, { shape = Enum.PartType.Cylinder })
	end
	for _, color in { Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 70, 110), Color3.fromRGB(90, 255, 140) } do
		prop(m, "Gem", Vector3.new(0.8, 0.8, 0.8), troveAt * CFrame.new(rng:NextNumber(-4, 4), 0.5, rng:NextNumber(3, 7)) * CFrame.Angles(0.6, 0.6, 0), color, Enum.Material.Neon)
	end
	-- A pearl necklace hanging over the front.
	for k = 0, 8 do
		prop(m, "Pearl", Vector3.new(0.45, 0.45, 0.45), troveAt * CFrame.new(-3 + k * 0.75, 4 - math.sin(k / 8 * math.pi) * 1.6, 3.1), Color3.fromRGB(250, 246, 236), Enum.Material.SmoothPlastic, { shape = Enum.PartType.Ball })
	end

	-- The giant anchor, leaning; the ship's wheel half sunk where the Ship's Bell lies.
	anchor(m, L(-60, -0.5, 42) * CFrame.Angles(0, 0.6, math.rad(28)), 1.4)
	shipWheel(m, L(-44, 2.2, 10) * CFrame.Angles(math.rad(-65), 0.4, 0), 3)
	-- Coral everywhere, the biggest of it grown from the seeds you can plant.
	coralPatch(m, L(-75, 0, 25).Position, 34, rng, 60)
	coralPatch(m, L(-110, 0, 60).Position, 18, rng, 24)
	for _, spot in { L(-80, 0, 0), L(-60, 0, 22), L(-118, 0, -6), L(-88, 0, 48) } do
		local shopSeeds = { "kelp", "brain", "fan", "anemone", "clam", "star" }
		local coral = CoralVisuals.build(shopSeeds[rng:NextInteger(1, #shopSeeds)], "None", spot * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		coral.Name = "DecorCoral"
		coral:ScaleTo(rng:NextNumber(1.8, 2.6))
		for _, d in coral:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		coral.Parent = m
	end
	for _ = 1, 3 do
		amphora(m, L(rng:NextNumber(-115, -50), 0, rng:NextNumber(-10, 50)).Position, rng, rng:NextNumber() < 0.6)
	end
end

-- The Wreck Basin: open sand where the liner lands, ringed with rocks and debris, with a few
-- bubble vents. Kept clear in the middle.
local function buildBasin(root: Instance, rng: Random)
	local m = model(root, "WreckBasin")
	local b = RuinsConfig.Places.basin
	for i = 1, 22 do
		local a = (i / 22) * math.pi * 2
		local p = b + F:VectorToWorldSpace(Vector3.new(math.cos(a) * 78, 0, math.sin(a) * 50))
		if RuinsConfig.inRuins(p) and (p - at(60, 0, 0)).Magnitude > 30 then
			boulder(m, p, rng:NextNumber(4, 8), rng)
			if i % 3 == 0 then
				local vent = part(m, "BubbleVent", Vector3.new(3, 1, 3), CFrame.new(p + F:VectorToWorldSpace(Vector3.new(0, 0, -6)) + Vector3.new(0, 0.5, 0)), ROCK, Enum.Material.Basalt)
				bubbles(vent, 6)
			end
		end
	end
	-- Old debris from wrecks before: crates, a barrel, a broken mast.
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = b + F:VectorToWorldSpace(Vector3.new(math.cos(a) * rng:NextNumber(66, 74), 0, math.sin(a) * rng:NextNumber(40, 46)))
		part(m, "Crate", Vector3.new(3, 3, 3), CFrame.new(p + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0.3, rng:NextNumber(0, math.pi), 0.2), Color3.fromRGB(150, 110, 76), Enum.Material.WoodPlanks)
	end
	prop(m, "OldMast", Vector3.new(26, 1.4, 1.4), L(-55, 0.7, 100) * CFrame.Angles(0, 0.4, 0), WOOD_DARK, Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
	coralPatch(m, L(-50, 0, 128).Position, 12, rng, 16)
	coralPatch(m, L(70, 0, 120).Position, 14, rng, 16)
end

-- Coral, kelp, rocks and ruin fragments scattered over the rest of the zone.
local function buildScatter(root: Instance, rng: Random)
	local m = model(root, "Scatter")
	local function clear(p: Vector3): boolean
		local o = F:PointToObjectSpace(p)
		local t = RuinsConfig.Terrace
		local onRoad = math.abs(o.Z) < 10 and o.X > 30
		local onTerrace = o.X > t.minX - 6 and o.X < t.maxX + 6 and o.Z > t.minZ - 6 and o.Z < t.maxZ + 24
		local inBasin = ((o.X - 10) / 72) ^ 2 + ((o.Z - 85) / 44) ^ 2 < 1
		local nearShip = (p - RuinsConfig.Ship.frame.Position).Magnitude < 44
		local nearCave = (p - RuinsConfig.Places.cave).Magnitude < 40
		return not (onRoad or onTerrace or inBasin or nearShip or nearCave)
	end
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = math.sqrt(rng:NextNumber()) * 160
		local p = at(math.cos(a) * d, 0, math.sin(a) * d)
		if clear(p) then
			coralPatch(m, p, rng:NextNumber(5, 9), rng, rng:NextInteger(5, 9))
			if rng:NextNumber() < 0.3 then
				fallenColumn(m, p + Vector3.new(4, 0, 4), rng:NextNumber(0, math.pi), rng:NextInteger(1, 3), 1.6, rng)
			elseif rng:NextNumber() < 0.3 then
				boulder(m, p + Vector3.new(-4, 0, 3), rng:NextNumber(4, 7), rng)
			end
		end
	end
	-- A few light shafts falling into the ruins.
	for _ = 1, 8 do
		prop(m, "LightShaft", Vector3.new(120, rng:NextNumber(5, 11), rng:NextNumber(5, 11)), CFrame.new(at(rng:NextNumber(-140, 140), 50, rng:NextNumber(-140, 140))) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(90) + rng:NextNumber(-0.25, 0.25)), Color3.fromRGB(190, 235, 255), Enum.Material.Neon, { shape = Enum.PartType.Cylinder, transparency = 0.94 })
	end
end

---------------------------------------------------------------------------------------------
-- Interactive spots

local function tagSpot(m: Model, kind: string, id: string)
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Id", id)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:AddTag(RuinsConfig.SPOT_TAG)
end

local function buildChest(parent: Instance, spot: { id: string, name: string, at: Vector3 }, rng: Random)
	local m = model(parent, "RuinsChest_" .. spot.id)
	local base = CFrame.new(spot.at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local wood = Color3.fromRGB(125, 82, 45)
	local box = part(m, "Box", Vector3.new(3.2, 1.8, 2.2), base * CFrame.new(0, 0.9, 0), wood, Enum.Material.Wood)
	box.CanQuery = false
	part(m, "Lid", Vector3.new(3.3, 0.8, 2.3), base * CFrame.new(0, 2.2, 0), wood:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Wood).CanQuery = false
	for _, bx in { -1.1, 1.1 } do
		prop(m, "Band", Vector3.new(0.25, 2.7, 2.35), base * CFrame.new(bx, 1.35, 0), GOLD, Enum.Material.Foil)
	end
	prop(m, "Lock", Vector3.new(0.5, 0.6, 0.15), base * CFrame.new(0, 1.8, -1.18), GOLD, Enum.Material.Foil)
	light(box, GOLD, 10, 1.4)
	sparkles(box, GOLD, 4)
	m.PrimaryPart = box
	prompt(box, "RuinsChest", "Open", spot.name, 10, 0.6):SetAttribute("Id", spot.id)
	tagSpot(m, "Chest", spot.id)
end

-- Each relic's look, built round `cf` (where it rests).
local relicBuilders: { [string]: (Model, CFrame) -> () } = {
	compass = function(m, cf)
		prop(m, "Case", Vector3.new(0.3, 1.8, 1.8), cf * CFrame.new(0, 0.15, 0) * UPRIGHT, GOLD, Enum.Material.Foil, { shape = Enum.PartType.Cylinder })
		prop(m, "Face", Vector3.new(0.05, 1.5, 1.5), cf * CFrame.new(0, 0.32, 0) * UPRIGHT, Color3.fromRGB(245, 235, 210), Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder })
		prop(m, "Needle", Vector3.new(0.15, 0.06, 1.2), cf * CFrame.new(0, 0.36, 0) * CFrame.Angles(0, 0.6, 0), Color3.fromRGB(220, 40, 40), Enum.Material.Neon)
	end,
	crown = function(m, cf)
		prop(m, "Band", Vector3.new(0.5, 1.6, 1.6), cf * CFrame.new(0, 0.25, 0) * UPRIGHT, GOLD, Enum.Material.Foil, { shape = Enum.PartType.Cylinder })
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			prop(m, "Point", Vector3.new(0.25, 0.7, 0.25), cf * CFrame.new(math.cos(a) * 0.75, 0.75, math.sin(a) * 0.75), GOLD, Enum.Material.Foil)
			prop(m, "Pearl", Vector3.new(0.35, 0.35, 0.35), cf * CFrame.new(math.cos(a) * 0.75, 1.15, math.sin(a) * 0.75), Color3.fromRGB(250, 246, 236), Enum.Material.SmoothPlastic, { shape = Enum.PartType.Ball })
		end
	end,
	tablet = function(m, cf)
		prop(m, "Slab", Vector3.new(1.8, 2.4, 0.4), cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(math.rad(-12), 0, 0), STONE_DARK, Enum.Material.Slate)
		for k = 1, 3 do
			prop(m, "Rune", Vector3.new(1.2, 0.15, 0.05), cf * CFrame.new(0, 0.6 + k * 0.5, 0) * CFrame.Angles(math.rad(-12), 0, 0) * CFrame.new(0, 0, -0.22), Color3.fromRGB(120, 230, 255), Enum.Material.Neon)
		end
	end,
	bell = function(m, cf)
		prop(m, "Bell", Vector3.new(1.8, 2, 1.8), cf * CFrame.new(0, 0.7, 0) * CFrame.Angles(0.5, 0, 0.2), Color3.fromRGB(196, 140, 70), Enum.Material.Metal, { shape = Enum.PartType.Ball })
		prop(m, "Rim", Vector3.new(0.3, 2.2, 2.2), cf * CFrame.new(0, 0.2, 0.3) * CFrame.Angles(0.5, 0, 0.2) * UPRIGHT, Color3.fromRGB(176, 120, 56), Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
	end,
	trident = function(m, cf)
		prop(m, "Shaft", Vector3.new(0.3, 5, 0.3), cf * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, 0.12), Color3.fromRGB(150, 230, 255), Enum.Material.Neon, { transparency = 0.1 })
		for _, x in { -0.6, 0, 0.6 } do
			prop(m, "Prong", Vector3.new(0.2, 1.4, 0.2), cf * CFrame.Angles(0, 0, 0.12) * CFrame.new(x, 5.4 + (if x == 0 then 0.2 else 0), 0), Color3.fromRGB(190, 150, 255), Enum.Material.Neon)
		end
		prop(m, "Crossbar", Vector3.new(1.5, 0.2, 0.2), cf * CFrame.Angles(0, 0, 0.12) * CFrame.new(0, 4.8, 0), Color3.fromRGB(190, 150, 255), Enum.Material.Neon)
	end,
	spyglass = function(m, cf)
		local brass = Color3.fromRGB(214, 170, 80)
		for k, r in { 0.35, 0.3, 0.25 } do
			prop(m, "Tube", Vector3.new(1.2, r * 2, r * 2), cf * CFrame.new(-1.2 + k * 1.1, 0.4, 0), if k == 1 then Color3.fromRGB(90, 60, 40) else brass, if k == 1 then Enum.Material.Leather else Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
		end
	end,
}

local function buildRelic(parent: Instance, relic: { id: string, name: string, at: Vector3 })
	local m = model(parent, "Relic_" .. relic.id)
	local cf = F.Rotation + relic.at
	relicBuilders[relic.id](m, cf)
	local holder = prop(m, "Glow", Vector3.new(1, 1, 1), cf * CFrame.new(0, 1, 0), GOLD, Enum.Material.SmoothPlastic, { transparency = 1 })
	light(holder, Color3.fromRGB(255, 230, 150), 10, 1.4)
	sparkles(holder, Color3.fromRGB(255, 240, 180), 5)
	m.PrimaryPart = holder
	prompt(holder, "RuinsRelic", "Pick up", relic.name, 10, 0.4):SetAttribute("Id", relic.id)
	tagSpot(m, "Relic", relic.id)
end

local function buildHiddenCoral(parent: Instance, spot: { id: string, seed: string, at: Vector3 }, rng: Random)
	local m = model(parent, "HiddenCoral_" .. spot.id)
	local coral = CoralVisuals.build(spot.seed, "None", CFrame.new(spot.at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	coral:ScaleTo(1.4)
	for _, d in coral:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	coral.Parent = m
	local seed = ReefConfig.Seeds[spot.seed]
	local color = if seed then seed.color else GOLD
	local ring = prop(m, "GlowRing", Vector3.new(0.1, 6, 6), CFrame.new(spot.at + Vector3.new(0, 0.35, 0)) * UPRIGHT, color, Enum.Material.Neon, { shape = Enum.PartType.Cylinder, transparency = 0.5 })
	local holder = prop(m, "Holder", Vector3.new(1, 1, 1), CFrame.new(spot.at + Vector3.new(0, 2.5, 0)), color, Enum.Material.SmoothPlastic, { transparency = 1 })
	sparkles(holder, color, 4)
	m.PrimaryPart = ring
	prompt(holder, "RuinsCoral", "Take a cutting", if seed then seed.name else "Hidden Coral", 10, 0.8):SetAttribute("Id", spot.id)
	tagSpot(m, "Coral", spot.id)
end

function RuinsWorld.build()
	local root = Instance.new("Folder")
	root.Name = "SunkenRuins"
	root.Parent = Workspace
	local rng = Random.new(1715) -- the same ruins every time

	buildGround(root, rng)
	buildEntrance(root, rng)
	buildArchway(root, rng)
	buildTerrace(root, rng)
	buildTemple(root, rng)
	buildStatue(root, rng)
	buildTallColumn(root, rng)
	buildShip(root, rng)
	buildCave(root, rng)
	buildGarden(root, rng)
	buildBasin(root, rng)
	buildScatter(root, rng)

	local spots = Instance.new("Folder")
	spots.Name = "Spots"
	spots.Parent = root
	for _, spot in RuinsConfig.Chests.spots do
		buildChest(spots, spot, rng)
	end
	for _, relic in RuinsConfig.Relics.list do
		buildRelic(spots, relic)
	end
	for _, spot in RuinsConfig.HiddenCoral do
		buildHiddenCoral(spots, spot, rng)
	end
	-- Landmarks reach every client even before the buildings stream in.
	root:SetAttribute("Entrance", RuinsConfig.Places.entrance)
end

return RuinsWorld
