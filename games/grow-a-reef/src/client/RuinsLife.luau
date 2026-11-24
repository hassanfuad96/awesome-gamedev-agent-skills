--!nonstrict
-- The Sunken Ruins' rare creatures: a Coelacanth, an Anglerfish, a Leafy Sea Dragon and the
-- Giant Squid. Client-only and cosmetic, like SeaLife, but each one swims the path in
-- RuinsConfig.creaturePosition for the server time, so it is where the server checks
-- sightings (and where every other player sees it). Each is built from Parts that swing round
-- pivots for tails, fins and tentacles, then swapped for its mesh creature (Creatures) once the
-- templates have loaded; CreatureAnimator swims the mesh. Nothing moves while the camera is far
-- from the ruins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local RuinsConfig = require(ReplicatedStorage.Shared.RuinsConfig)

local RuinsLife = {}

type Joint = { pivot: CFrame, offset: CFrame, swing: Vector3?, speed: number, phase: number }
-- `mesh` replaces the parts once it has loaded, and is moved whole.
type Creature = { id: string, model: Model, parts: { BasePart }, joints: { Joint }, shown: boolean, mesh: Model? }
type Options = { shape: Enum.PartType?, material: Enum.Material?, transparency: number?, pivot: CFrame?, swing: Vector3?, speed: number?, phase: number? }

local AWAKE_DISTANCE = RuinsConfig.radius + 250 -- camera distance from the ruins' centre
-- Each creature's mesh (a CreatureMeshes id) and how hard it swims. A `level` one only turns
-- left and right (the upright squid would tip onto its back as it rises).
local MESHES: { [string]: { id: string, pace: number, level: boolean? } } = {
	coelacanth = { id = "coelacanth", pace = 0.4 },
	angler = { id = "anglerfish", pace = 0.6 },
	seadragon = { id = "seadragon", pace = 0.2 },
	squid = { id = "giantSquid", pace = -0.4, level = true },
}
local BALL = Enum.PartType.Ball
local creatures: { Creature } = {}
local folder: Folder

local function newCreature(id: string): Creature
	local model = Instance.new("Model")
	model.Name = id
	model.Parent = folder
	local creature = { id = id, model = model, parts = {}, joints = {}, shown = true }
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

-- Every creature faces -Z (its direction of travel).

local function coelacanth()
	local c = newCreature("coelacanth")
	local body, spots = Color3.fromRGB(56, 78, 120), Color3.fromRGB(220, 230, 240)
	local tail = CFrame.new(0, 0, 3)
	add(c, Vector3.new(2.2, 2.6, 7.5), body, CFrame.identity, { shape = BALL })
	add(c, Vector3.new(1.6, 1.8, 2.2), body:Lerp(Color3.new(0, 0, 0), 0.2), CFrame.new(0, 0, -3.4), { shape = BALL })
	for _, side in { -1, 1 } do
		add(c, Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(230, 220, 120), CFrame.new(side * 0.72, 0.35, -3.9), { shape = BALL, material = Enum.Material.Neon })
		-- Lobed, limb-like fins: the fossil fish's trademark.
		for k, z in { -1.2, 1.4 } do
			add(c, Vector3.new(0.5, 0.5, 1.6), body, CFrame.new(side * 1.2, -0.9, z) * CFrame.Angles(0.4, side * 0.5, 0), { shape = BALL, pivot = CFrame.new(side * 1, -0.8, z - 0.5), swing = Vector3.new(0.4, 0, 0), speed = 3, phase = k + (side > 0 and 1.5 or 0) })
		end
	end
	for _ = 1, 10 do
		local x = (math.random() - 0.5) * 1.6
		add(c, Vector3.new(0.35, 0.35, 0.35), spots, CFrame.new(x, (math.random() - 0.3) * 1.6, (math.random() - 0.5) * 5), { shape = BALL })
	end
	add(c, Vector3.new(0.3, 1.6, 1.6), body, CFrame.new(0, 1.4, 0.5), { shape = BALL })
	-- The three-lobed tail.
	add(c, Vector3.new(0.3, 2.4, 2.2), body, tail * CFrame.new(0, 0, 1.4), { pivot = tail, swing = Vector3.new(0, 0.5, 0), speed = 2.5 })
	add(c, Vector3.new(0.3, 0.9, 1.2), body:Lerp(Color3.new(1, 1, 1), 0.2), tail * CFrame.new(0, 0, 2.8), { pivot = tail, swing = Vector3.new(0, 0.6, 0), speed = 2.5, phase = 0.3 })
end

local function angler()
	local c = newCreature("angler")
	local skin = Color3.fromRGB(70, 52, 48)
	add(c, Vector3.new(3, 2.6, 3.2), skin, CFrame.identity, { shape = BALL })
	add(c, Vector3.new(2.6, 0.8, 1.4), Color3.fromRGB(30, 18, 20), CFrame.new(0, -0.5, -1.3), { shape = BALL })
	for i = -2, 2 do
		add(c, Vector3.new(0.18, 0.5, 0.18), Color3.fromRGB(240, 240, 230), CFrame.new(i * 0.42, -0.25, -1.75) * CFrame.Angles(0, 0, math.rad(180)), { material = Enum.Material.Neon })
	end
	for _, side in { -1, 1 } do
		add(c, Vector3.new(0.45, 0.45, 0.45), Color3.fromRGB(240, 240, 200), CFrame.new(side * 0.8, 0.55, -1.3), { shape = BALL })
		add(c, Vector3.new(0.2, 1, 1.2), skin, CFrame.new(side * 1.5, -0.3, 0.4), { pivot = CFrame.new(side * 1.4, -0.3, 0), swing = Vector3.new(0, 0, 0.5), speed = 5, phase = side })
	end
	add(c, Vector3.new(0.2, 1.4, 1.6), skin, CFrame.new(0, 0, 2.2), { pivot = CFrame.new(0, 0, 1.4), swing = Vector3.new(0, 0.6, 0), speed = 4 })
	-- The lure: a stalk curving up and forward, with a glowing bulb that sways.
	local stalk = CFrame.new(0, 1.2, -0.6)
	add(c, Vector3.new(0.15, 0.15, 2.2), skin, stalk * CFrame.new(0, 0.6, -0.8) * CFrame.Angles(math.rad(35), 0, 0), { pivot = stalk, swing = Vector3.new(0.25, 0.2, 0), speed = 1.5 })
	local bulb = add(c, Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(160, 255, 230), stalk * CFrame.new(0, 1.2, -1.9), { shape = BALL, material = Enum.Material.Neon, pivot = stalk, swing = Vector3.new(0.25, 0.2, 0), speed = 1.5 })
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 255, 220)
	glow.Range = 14
	glow.Brightness = 2
	glow.Parent = bulb
end

local function seadragon()
	local c = newCreature("seadragon")
	local body, leaf = Color3.fromRGB(220, 190, 80), Color3.fromRGB(150, 200, 70)
	for i = 0, 6 do
		local z = -2 + i * 0.75
		local s = 1 - i * 0.1
		add(c, Vector3.new(0.6 * s, 0.75 * s, 0.9), body:Lerp(leaf, i / 10), CFrame.new(0, 0, z), { shape = BALL, pivot = CFrame.new(0, 0, -1), swing = Vector3.new(0, 0.06 * i, 0), speed = 1.4, phase = -i * 0.3 })
		if i % 2 == 0 then
			for _, side in { -1, 1 } do
				add(c, Vector3.new(0.1, 1, 0.6), leaf, CFrame.new(side * 0.45, 0.3, z) * CFrame.Angles(0, 0, side * 0.6), { material = Enum.Material.Grass, pivot = CFrame.new(side * 0.3, 0.1, z), swing = Vector3.new(0, 0, 0.3), speed = 2, phase = i })
			end
		end
	end
	add(c, Vector3.new(0.5, 0.55, 0.8), body, CFrame.new(0, 0.2, -2.7), { shape = BALL })
	add(c, Vector3.new(0.18, 0.18, 1.2), body, CFrame.new(0, 0.1, -3.6))
	add(c, Vector3.new(0.12, 1.4, 0.8), leaf, CFrame.new(0, 0.9, -2.5) * CFrame.Angles(-0.4, 0, 0), { material = Enum.Material.Grass })
	add(c, Vector3.new(0.15, 0.15, 1.6), body, CFrame.new(0, -0.4, 3.3) * CFrame.Angles(0.6, 0, 0), { pivot = CFrame.new(0, 0, 2.6), swing = Vector3.new(0.3, 0, 0), speed = 1.2 })
end

local function squid()
	local c = newCreature("squid")
	local red, pale = Color3.fromRGB(196, 64, 54), Color3.fromRGB(240, 150, 130)
	-- The mantle leads (squid swim mantle first); arms trail behind.
	add(c, Vector3.new(7, 7, 18), red, CFrame.new(0, 0, -4), { shape = BALL })
	add(c, Vector3.new(0.6, 8, 5), red:Lerp(pale, 0.2), CFrame.new(0, 0, -11.5), { shape = BALL })
	add(c, Vector3.new(8, 0.6, 5), red:Lerp(pale, 0.2), CFrame.new(0, 0, -11.5), { shape = BALL, pivot = CFrame.new(0, 0, -11), swing = Vector3.new(0, 0, 0.25), speed = 1.5 })
	add(c, Vector3.new(6, 6, 5), pale, CFrame.new(0, 0, 5.5), { shape = BALL })
	for _, side in { -1, 1 } do
		add(c, Vector3.new(2.6, 2.6, 2.6), Color3.fromRGB(245, 240, 220), CFrame.new(side * 2.6, 0.6, 5.2), { shape = BALL })
		add(c, Vector3.new(1.3, 1.3, 1.3), Color3.fromRGB(20, 24, 40), CFrame.new(side * 3.6, 0.6, 5.2), { shape = BALL })
	end
	-- Eight arms and two long tentacles, each a chain that waves with a delay down its length.
	for arm = 0, 9 do
		local a = arm / 10 * math.pi * 2
		local long = arm == 2 or arm == 7
		local base = CFrame.new(math.cos(a) * 2.2, math.sin(a) * 2.2, 7.5)
		local segments = if long then 9 else 6
		for k = 0, segments - 1 do
			local size = (if long then 1 else 1.3) * (1 - k / (segments + 2))
			add(c, Vector3.new(size, size, 2.4), if k % 2 == 0 then red else pale, base * CFrame.new(0, 0, k * 2.2 + 1.2), {
				shape = BALL,
				pivot = base,
				swing = Vector3.new(0.08 + k * 0.025, 0.08 + k * 0.025, 0),
				speed = 1.6,
				phase = arm + k * 0.35,
			})
		end
	end
end

-- Swaps a creature's Parts for its mesh, if that has loaded.
local function useMesh(creature: Creature)
	local spec = MESHES[creature.id]
	local mesh = spec and Creatures.clone(spec.id)
	if not mesh then
		return
	end
	for _, part in creature.parts do
		part:Destroy()
	end
	table.clear(creature.parts)
	table.clear(creature.joints)
	mesh:SetAttribute("Pace", spec.pace)
	for _, part in mesh:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = false
		end
	end
	-- The anglerfish keeps its glowing lure.
	local lure = mesh:FindFirstChild("Lure")
	if lure and lure:IsA("BasePart") then
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(150, 255, 220)
		glow.Range = 14
		glow.Brightness = 2
		glow.Parent = lure
	end
	mesh.Parent = creature.model
	creature.mesh = mesh
end

-- Positions every creature for the server time; hides the squid between its visits.
local function step(t: number)
	for _, creature in creatures do
		local p = RuinsConfig.creaturePosition(creature.id, t)
		if not p then
			if creature.shown then
				creature.shown = false
				creature.model.Parent = nil
			end
			continue
		end
		if not creature.shown then
			creature.shown = true
			creature.model.Parent = folder
		end
		local ahead = RuinsConfig.creaturePosition(creature.id, t + 0.25) or p
		local root = if (ahead - p).Magnitude > 0.01 then CFrame.lookAt(p, ahead) else CFrame.new(p)
		if creature.mesh then
			local spec = MESHES[creature.id]
			local flat = root.LookVector * Vector3.new(1, 0, 1)
			if spec.level then
				creature.mesh:PivotTo(if flat.Magnitude > 0.01 then CFrame.lookAt(p, p + flat) else CFrame.new(p))
			else
				creature.mesh:PivotTo(root)
			end
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
end

function RuinsLife.start()
	folder = Instance.new("Folder")
	folder.Name = "RuinsLife"
	folder.Parent = Workspace
	coelacanth()
	angler()
	seadragon()
	squid()
	Creatures.onReady(function()
		for _, creature in creatures do
			useMesh(creature)
		end
	end)
	local awake = true
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local near = camera ~= nil and (camera.CFrame.Position - RuinsConfig.center).Magnitude < AWAKE_DISTANCE
		if near ~= awake then
			awake = near
			folder.Parent = if near then Workspace else nil
		end
		if near then
			step(Workspace:GetServerTimeNow())
		end
	end)
end

return RuinsLife
