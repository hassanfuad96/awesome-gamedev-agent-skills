--!nonstrict
-- The Abyss on the client: the dark-blue water and the life in it. Cosmetic and local to this
-- client, like SeaLife.
--   darkness    blended in by AbyssConfig.darkness at the camera (a little on the shelf,
--               deepest on the pit floor): a ColorCorrection and Bloom of this client's own,
--               a dark water ceiling over the zone, and darker haze and ambient light. Sea
--               events tween those Lighting values on the server, so this blends from the
--               last value the server sent towards the dark one, and puts it back on leaving.
--   jellyfish   glowing jellyfish pulsing and drifting round the pit
--   creatures   the Ghost Shark, Vampire Squid, Gulper Eel and Dumbo Octopus, each on the
--               path AbyssConfig.creaturePosition gives for the server time, so they are
--               where the server checks sightings
-- Nothing moves while the camera is far from the Abyss.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AbyssConfig = require(ReplicatedStorage.Shared.AbyssConfig)

local AbyssLife = {}

type Joint = { pivot: CFrame, offset: CFrame, swing: Vector3?, speed: number, phase: number }
type Creature = { id: string, model: Model, parts: { BasePart }, joints: { Joint }, path: (number) -> Vector3 }
type Options = { shape: Enum.PartType?, material: Enum.Material?, transparency: number?, pivot: CFrame?, swing: Vector3?, speed: number?, phase: number? }

local LOOK = AbyssConfig.Look
local AWAKE_DISTANCE = 450 -- camera distance from the Abyss's centre
local BALL = Enum.PartType.Ball
local creatures: { Creature } = {}
local folder: Folder

local function newCreature(id: string, path: (number) -> Vector3): Creature
	local model = Instance.new("Model")
	model.Name = id
	model.Parent = folder
	local creature = { id = id, model = model, parts = {}, joints = {}, path = path }
	table.insert(creatures, creature)
	return creature
end

local function add(creature: Creature, size: Vector3, color: Color3, offset: CFrame, o: Options?): Part
	local options = o or {}
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Shape = options.shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = options.material or Enum.Material.SmoothPlastic
	p.Transparency = options.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = creature.model
	table.insert(creature.parts, p)
	table.insert(creature.joints, { pivot = options.pivot or CFrame.identity, offset = offset, swing = options.swing, speed = options.speed or 0, phase = options.phase or 0 })
	return p
end

local function glowLight(part: BasePart, color: Color3, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1.6
	l.Parent = part
end

local function shared(id: string): (number) -> Vector3
	return function(t)
		return AbyssConfig.creaturePosition(id, t) :: Vector3
	end
end

-- Every creature faces -Z (its direction of travel).

local function ghostShark()
	local c = newCreature("ghostshark", shared("ghostshark"))
	local skin, pale = Color3.fromRGB(110, 130, 170), Color3.fromRGB(200, 215, 240)
	add(c, Vector3.new(3.4, 3.6, 14), skin, CFrame.identity, { shape = BALL })
	add(c, Vector3.new(2.6, 2.4, 5), pale, CFrame.new(0, -0.6, -4.5), { shape = BALL })
	add(c, Vector3.new(1, 1, 3), skin, CFrame.new(0, -0.3, -7.4), { shape = BALL }) -- the long snout
	for _, side in { -1, 1 } do
		add(c, Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(255, 80, 120), CFrame.new(side * 1.2, 0.6, -5.4), { shape = BALL, material = Enum.Material.Neon })
		-- Big wing-like pectoral fins that flap slowly.
		add(c, Vector3.new(6, 0.3, 3.4), skin, CFrame.new(side * 4, -0.6, -1.5) * CFrame.Angles(0, side * 0.3, 0), { pivot = CFrame.new(side * 1.6, -0.6, -1.5), swing = Vector3.new(0, 0, 0.35), speed = 1.6, phase = if side > 0 then 0 else math.pi })
	end
	add(c, Vector3.new(0.4, 3.4, 2.4), skin, CFrame.new(0, 2.6, -1.4) * CFrame.Angles(-0.3, 0, 0))
	-- A long whip tail with a glowing line down it.
	local tail = CFrame.new(0, 0, 6.5)
	for k = 0, 4 do
		add(c, Vector3.new(0.8 - k * 0.12, 0.8 - k * 0.12, 3), skin, tail * CFrame.new(0, 0, k * 2.6), { pivot = tail, swing = Vector3.new(0, 0.12 + k * 0.05, 0), speed = 2, phase = -k * 0.5 })
	end
	add(c, Vector3.new(0.2, 0.2, 13), Color3.fromRGB(150, 200, 255), CFrame.new(0, 1.3, 0), { material = Enum.Material.Neon })
end

local function vampireSquid()
	local c = newCreature("vampiresquid", shared("vampiresquid"))
	local red = Color3.fromRGB(150, 30, 60)
	add(c, Vector3.new(2.8, 2.8, 4), red, CFrame.identity, { shape = BALL })
	for _, side in { -1, 1 } do
		add(c, Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(80, 200, 255), CFrame.new(side * 0.9, 0.5, -1.4), { shape = BALL, material = Enum.Material.Neon })
		add(c, Vector3.new(1.4, 0.2, 1.2), red, CFrame.new(side * 1.6, 0.6, 0.8), { pivot = CFrame.new(side * 1.2, 0.6, 0.8), swing = Vector3.new(0, 0, 0.6), speed = 3, phase = if side > 0 then 0 else math.pi })
	end
	-- The cloak of webbed arms, pulsing open and shut, with glowing tips.
	for arm = 0, 7 do
		local a = arm / 8 * math.pi * 2
		local base = CFrame.new(0, 0, 1.6) * CFrame.Angles(0, 0, a)
		add(c, Vector3.new(0.5, 2.6, 0.5), red:Lerp(Color3.new(0, 0, 0), 0.3), base * CFrame.new(0, 1.3, 0.8) * CFrame.Angles(0.7, 0, 0), { pivot = base, swing = Vector3.new(0.4, 0, 0), speed = 2, phase = 0 })
		add(c, Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(120, 220, 255), base * CFrame.new(0, 2.4, 1.6), { shape = BALL, material = Enum.Material.Neon, pivot = base, swing = Vector3.new(0.4, 0, 0), speed = 2, phase = 0 })
	end
end

local function gulperEel()
	local c = newCreature("gulper", shared("gulper"))
	local skin = Color3.fromRGB(30, 30, 46)
	-- The huge pelican mouth, opening and closing.
	local jaw = CFrame.new(0, 0, -1)
	add(c, Vector3.new(3.6, 0.4, 5), skin, jaw * CFrame.new(0, 1, -2.4), { pivot = jaw, swing = Vector3.new(0.25, 0, 0), speed = 1.2 })
	add(c, Vector3.new(3.6, 2, 5), Color3.fromRGB(60, 40, 60), jaw * CFrame.new(0, -0.4, -2.4), { shape = BALL, transparency = 0.2, pivot = jaw, swing = Vector3.new(-0.25, 0, 0), speed = 1.2 })
	add(c, Vector3.new(1.4, 1.4, 2), skin, CFrame.identity, { shape = BALL })
	add(c, Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(240, 240, 255), CFrame.new(0.5, 0.5, -0.8), { shape = BALL, material = Enum.Material.Neon })
	-- A long whipping body ending in a glowing pink tip.
	for k = 1, 10 do
		add(c, Vector3.new(0.9 - k * 0.06, 0.9 - k * 0.06, 2), skin, CFrame.new(0, 0, k * 1.8), { pivot = CFrame.new(0, 0, 0.5), swing = Vector3.new(0, 0.04 * k, 0), speed = 3, phase = -k * 0.45 })
	end
	local tip = add(c, Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(255, 90, 200), CFrame.new(0, 0, 19.5), { shape = BALL, material = Enum.Material.Neon, pivot = CFrame.new(0, 0, 0.5), swing = Vector3.new(0, 0.42, 0), speed = 3, phase = -4.7 })
	glowLight(tip, Color3.fromRGB(255, 90, 200), 10)
end

local function dumboOctopus()
	local c = newCreature("dumbo", shared("dumbo"))
	local skin = Color3.fromRGB(255, 160, 190)
	add(c, Vector3.new(3, 3.4, 3), skin, CFrame.identity, { shape = BALL })
	for _, side in { -1, 1 } do
		-- The "ears": round fins that flap.
		add(c, Vector3.new(2, 0.3, 1.6), skin:Lerp(Color3.new(1, 1, 1), 0.2), CFrame.new(side * 2.1, 1, 0), { shape = BALL, pivot = CFrame.new(side * 1.3, 1, 0), swing = Vector3.new(0, 0, 0.7), speed = 3, phase = if side > 0 then 0 else math.pi })
		add(c, Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(30, 20, 40), CFrame.new(side * 0.7, 0.4, -1.3), { shape = BALL })
	end
	-- A skirt of webbed arms underneath.
	for arm = 0, 7 do
		local a = arm / 8 * math.pi * 2
		add(c, Vector3.new(0.5, 2, 0.5), skin:Lerp(Color3.new(0, 0, 0), 0.15), CFrame.new(math.cos(a) * 1, -2, math.sin(a) * 1) * CFrame.Angles(math.sin(a) * 0.4, 0, -math.cos(a) * 0.4), { pivot = CFrame.new(0, -1.2, 0), swing = Vector3.new(0.2, 0, 0.2), speed = 2, phase = arm })
	end
end

-- A glowing jellyfish drifting on its own slow loop, its bell pulsing.
local function jellyfish(index: number, lit: boolean)
	local rng = Random.new(index * 97)
	local P = AbyssConfig.Pit
	local home = Vector3.new(rng:NextNumber(P.minX + 20, P.maxX - 20), AbyssConfig.FLOOR + rng:NextNumber(8, 34), rng:NextNumber(P.minZ + 30, P.maxZ - 20))
	-- Half of them gather round the jellyfish garden.
	if index % 2 == 0 then
		local g = AbyssConfig.Places.jellies
		home = g + Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(6, 26), rng:NextNumber(-25, 25))
	end
	local rx, rz, speed, phase = rng:NextNumber(4, 14), rng:NextNumber(4, 14), rng:NextNumber(0.8, 1.6), rng:NextNumber(0, math.pi * 2)
	local c = newCreature("Jellyfish", function(t)
		local a = t * speed / math.max(rx, rz) + phase
		return home + Vector3.new(math.sin(a) * rx, math.sin(t * 0.5 + phase) * 3, math.cos(a) * rz)
	end)
	local colors = { Color3.fromRGB(120, 220, 255), Color3.fromRGB(200, 130, 255), Color3.fromRGB(255, 140, 220), Color3.fromRGB(130, 255, 210) }
	local color = colors[index % #colors + 1]
	local s = rng:NextNumber(0.8, 1.6)
	local bell = add(c, Vector3.new(3, 2.2, 3) * s, color, CFrame.new(0, 0, 0), { shape = BALL, material = Enum.Material.ForceField, swing = Vector3.new(0, 0, 0), speed = 0 })
	add(c, Vector3.new(1.6, 1.1, 1.6) * s, color, CFrame.new(0, -0.1, 0), { shape = BALL, material = Enum.Material.Neon, transparency = 0.3 })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local top = CFrame.new(math.cos(a) * 0.8 * s, -0.6 * s, math.sin(a) * 0.8 * s)
		add(c, Vector3.new(0.12, 4 * s, 0.12), color, top * CFrame.new(0, -2 * s, 0), { material = Enum.Material.Neon, transparency = 0.35, pivot = top, swing = Vector3.new(0.25, 0, 0.25), speed = 1.4, phase = k })
	end
	if lit then
		glowLight(bell, color, 14)
	end
	c.model:SetAttribute("Jelly", true)
end

-- Jellyfish don't face their travel; they stay upright and pulse.
local function place(creature: Creature, t: number)
	local p = creature.path(t)
	if not p then
		return
	end
	local root
	if creature.model:GetAttribute("Jelly") then
		root = CFrame.new(p)
	else
		local ahead = creature.path(t + 0.25)
		root = if ahead and (ahead - p).Magnitude > 0.01 then CFrame.lookAt(p, ahead) else CFrame.new(p)
	end
	for i, part in creature.parts do
		local joint = creature.joints[i]
		local cf = root * joint.offset
		if joint.swing then
			local wave = math.sin(t * joint.speed + joint.phase)
			local swing = joint.swing * wave
			cf = root * joint.pivot * CFrame.Angles(swing.X, swing.Y, swing.Z) * joint.pivot:Inverse() * joint.offset
		end
		part.CFrame = cf
	end
end

local tint: ColorCorrectionEffect
local bloom: BloomEffect
local ceiling: Part
local current = 0 -- the darkness applied now, eased towards the target

-- Lighting properties blended towards a dark value. `base` is the server's value: it follows
-- every change except the ones this module wrote itself.
type Overlay = { instance: Instance, property: string, dark: any, base: any, written: any }
local overlays: { Overlay } = {}

-- Whether a value read back is the one we wrote. Lighting stores 32-bit floats, so what we
-- read back is never exactly what we wrote; without a tolerance, our own write would look
-- like the server's and the darkness would compound every frame.
local function same(a: any, b: any): boolean
	if a == nil or b == nil then
		return false
	end
	if type(a) == "number" then
		return math.abs(a - b) < 1e-3
	end
	return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
end

local function overlay(instance: Instance?, property: string, dark: any)
	if not instance then
		return
	end
	local o: Overlay = { instance = instance, property = property, dark = dark, base = (instance :: any)[property], written = nil }
	instance:GetPropertyChangedSignal(property):Connect(function()
		local value = (instance :: any)[property]
		if not same(value, o.written) then
			o.base = value
		end
	end)
	table.insert(overlays, o)
end

local function blend(a: any, b: any, t: number): any
	return if type(a) == "number" then a + (b - a) * t else a:Lerp(b, t)
end

local function applyDarkness(amount: number)
	for _, o in overlays do
		local value = if amount <= 0.001 then o.base else blend(o.base, o.dark, amount)
		o.written = value;
		(o.instance :: any)[o.property] = value
	end
	ceiling.Transparency = 1 - 0.9 * amount
	tint.TintColor = Color3.new(1, 1, 1):Lerp(LOOK.tint, amount)
	tint.Brightness = LOOK.brightness * amount
	tint.Contrast = LOOK.contrast * amount
	tint.Saturation = LOOK.saturation * amount
	tint.Enabled = amount > 0.001
	bloom.Intensity = LOOK.bloomIntensity * amount
	bloom.Threshold = 2 - (2 - LOOK.bloomThreshold) * amount
	bloom.Size = LOOK.bloomSize
	bloom.Enabled = amount > 0.001
end

function AbyssLife.start()
	folder = Instance.new("Folder")
	folder.Name = "AbyssLife"
	folder.Parent = Workspace
	ghostShark()
	vampireSquid()
	gulperEel()
	dumboOctopus()
	for i = 1, LOOK.jellyfish do
		jellyfish(i, i % 3 == 0)
	end

	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "AbyssDarkness"
	tint.Parent = Lighting
	bloom = Instance.new("BloomEffect")
	bloom.Name = "AbyssGlow"
	bloom.Parent = Lighting
	-- Dark water overhead: past the lagoon's water surface, the sky would show here.
	ceiling = Instance.new("Part")
	ceiling.Name = "AbyssCeiling"
	ceiling.Anchored = true
	ceiling.CanCollide = false
	ceiling.CanQuery = false
	ceiling.CanTouch = false
	ceiling.CastShadow = false
	ceiling.Size = Vector3.new(1200, 2, 1200)
	-- Under the lagoon's glowing water surface (y = 110), which reaches this far and would
	-- show through; above the highest anyone can swim (ReefConfig.Swim.maxHeight).
	ceiling.Position = AbyssConfig.center + Vector3.new(0, 100, 0)
	ceiling.Color = LOOK.ceiling
	ceiling.Material = Enum.Material.SmoothPlastic -- not Neon: it would glow and bloom
	ceiling.Transparency = 1
	ceiling.Parent = Workspace
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	overlay(atmosphere, "Color", LOOK.atmosphereColor)
	overlay(atmosphere, "Decay", LOOK.atmosphereDecay)
	overlay(atmosphere, "Density", LOOK.atmosphereDensity)
	overlay(Lighting, "Ambient", LOOK.ambient)
	overlay(Lighting, "OutdoorAmbient", LOOK.outdoorAmbient)
	overlay(Lighting, "Brightness", LOOK.brightnessLighting)
	applyDarkness(0)

	local awake = true
	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local at = camera.CFrame.Position
		local target = AbyssConfig.darkness(at)
		local before = current
		if math.abs(target - current) > 0.001 then
			current += (target - current) * math.min(1, dt * 2.5)
		else
			current = target
		end
		-- Keep applying while dark, so a sea event's lighting change is blended too.
		if current > 0.001 or before > 0.001 then
			applyDarkness(current)
		end
		local near = (at - AbyssConfig.center).Magnitude < AWAKE_DISTANCE
		if near ~= awake then
			awake = near
			folder.Parent = if near then Workspace else nil
		end
		if near then
			local t = Workspace:GetServerTimeNow()
			for _, creature in creatures do
				place(creature, t)
			end
		end
	end)
end

return AbyssLife
