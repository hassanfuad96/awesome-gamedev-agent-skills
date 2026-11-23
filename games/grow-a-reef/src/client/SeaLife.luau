--!nonstrict
-- Ambient sea life: schools of reef fish, sea turtles, jellyfish, a manta ray and crabs,
-- plus the giant whale of the Whale Pass sea event.
-- Purely cosmetic, so each client builds and moves its own (nothing replicates, and the
-- motion stays smooth). Every part has CanQuery off, so clicks and the planting ray pass
-- straight through to the reef and the catchable fish.
--
-- A creature is a set of Parts placed relative to a root CFrame that its path gives for
-- the current time. A part can swing around a pivot (tails, flippers, wings, tentacles).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)

local SeaLife = {}

type Joint = { pivot: CFrame, offset: CFrame, swing: Vector3?, speed: number, phase: number }
type Creature = { model: Model, parts: { BasePart }, joints: { Joint }, path: (number) -> CFrame }
type PartOptions = {
	shape: Enum.PartType?,
	material: Enum.Material?,
	transparency: number?,
	pivot: CFrame?, -- where the part swings from, relative to the root
	swing: Vector3?, -- swing amplitude in radians around X, Y and Z
	speed: number?,
	phase: number?,
	shadow: boolean?, -- only the biggest creatures cast one
}

local SETTINGS = ReefConfig.SeaLife
local AREA = SETTINGS.area
-- The middle of the roaming area, which turtles and mantas circle.
local MIDDLE_Z = (AREA.minZ + AREA.maxZ) / 2
local UPDATE_DISTANCE = 320 -- creatures further from the camera than this wait (it's all haze)

local rng = Random.new()
local creatures: { Creature } = {}
local folder: Folder

local function newCreature(name: string, path: (number) -> CFrame): Creature
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = folder
	local creature = { model = model, parts = {}, joints = {}, path = path }
	table.insert(creatures, creature)
	return creature
end

local function add(creature: Creature, size: Vector3, color: Color3, offset: CFrame, options: PartOptions?): Part
	local o = options or {}
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = o.shadow == true
	p.Shape = o.shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = creature.model
	table.insert(creature.parts, p)
	table.insert(creature.joints, {
		pivot = o.pivot or CFrame.identity,
		offset = offset,
		swing = o.swing,
		speed = o.speed or 0,
		phase = o.phase or 0,
	})
	return p
end

-- Faces along the direction of travel (-Z forward), looking a moment ahead on the path.
local function along(path: (number) -> Vector3): (number) -> CFrame
	return function(t)
		return CFrame.lookAt(path(t), path(t + 0.15))
	end
end

local function randomPoint(height: NumberRange): Vector3
	return Vector3.new(
		rng:NextNumber(AREA.minX, AREA.maxX),
		rng:NextNumber(height.Min, height.Max),
		rng:NextNumber(AREA.minZ, AREA.maxZ)
	)
end

-- A wide, gently rising and falling loop around a centre point.
local function loop(center: Vector3, radiusX: number, radiusZ: number, rise: number, speed: number): (number) -> Vector3
	local turnRate = speed / math.max(radiusX, radiusZ)
	local phase = rng:NextNumber(0, math.pi * 2)
	local direction = if rng:NextNumber() < 0.5 then 1 else -1
	return function(t)
		local a = (t * turnRate + phase) * direction
		return center + Vector3.new(math.sin(a) * radiusX, math.sin(a * 2) * rise, math.cos(a) * radiusZ)
	end
end

local SPECIES = {
	{ body = Color3.fromRGB(255, 122, 30), tail = Color3.fromRGB(255, 122, 30), band = Color3.fromRGB(250, 250, 250), size = 0.8 }, -- clownfish
	{ body = Color3.fromRGB(40, 90, 230), tail = Color3.fromRGB(250, 210, 40), size = 1 }, -- blue tang
	{ body = Color3.fromRGB(250, 215, 40), tail = Color3.fromRGB(250, 215, 40), size = 0.9, tall = 1.3 }, -- yellow tang
	{ body = Color3.fromRGB(235, 235, 245), tail = Color3.fromRGB(235, 235, 245), band = Color3.fromRGB(45, 45, 65), size = 1.3, tall = 1.6 }, -- angelfish
	{ body = Color3.fromRGB(175, 195, 215), tail = Color3.fromRGB(175, 195, 215), size = 0.6, material = Enum.Material.Metal }, -- sardine
	{ body = Color3.fromRGB(240, 110, 170), tail = Color3.fromRGB(120, 80, 220), size = 0.9 }, -- wrasse
}

local function addFish(species, path: (number) -> CFrame)
	local fish = newCreature("Fish", path)
	local s = species.size
	local tall = species.tall or 1
	add(fish, Vector3.new(0.6, 0.8 * tall, 1.7) * s, species.body, CFrame.identity, { shape = Enum.PartType.Ball, material = species.material })
	if species.band then
		add(fish, Vector3.new(0.64, 0.82 * tall, 0.28) * s, species.band, CFrame.new(0, 0, -0.15 * s), { shape = Enum.PartType.Ball })
	end
	add(fish, Vector3.new(0.08, 0.8 * tall, 0.7) * s, species.tail, CFrame.new(0, 0, 0.35 * s), {
		pivot = CFrame.new(0, 0, 0.75 * s),
		swing = Vector3.new(0, 0.5, 0),
		speed = 9,
		phase = rng:NextNumber(0, math.pi * 2),
	})
	for side = -1, 1, 2 do
		add(fish, Vector3.new(0.16, 0.16, 0.16) * s, Color3.new(0.05, 0.05, 0.05), CFrame.new(side * 0.26 * s, 0.12 * s, -0.55 * s), { shape = Enum.PartType.Ball })
	end
end

local function addSchool()
	local species = SPECIES[rng:NextInteger(1, #SPECIES)]
	local center = randomPoint(NumberRange.new(14, 30))
	local school = loop(center, rng:NextNumber(40, 90), rng:NextNumber(30, 70), rng:NextNumber(2, 5), rng:NextNumber(6, 10))
	for _ = 1, SETTINGS.fishPerSchool do
		local offset = Vector3.new(rng:NextNumber(-3.5, 3.5), rng:NextNumber(-2, 2), rng:NextNumber(-3.5, 3.5))
		local wobble = rng:NextNumber(0, math.pi * 2)
		addFish(species, along(function(t)
			return school(t) + offset + Vector3.new(math.sin(t * 1.7 + wobble) * 0.5, math.sin(t * 2.3 + wobble) * 0.4, math.cos(t * 1.5 + wobble) * 0.5)
		end))
	end
end

local function addTurtle()
	local center = Vector3.new(0, rng:NextNumber(24, 34), MIDDLE_Z)
	local turtle = newCreature("SeaTurtle", along(loop(center, rng:NextNumber(200, 320), rng:NextNumber(80, 130), 3, 5)))
	local shell = Color3.fromRGB(95, 115, 60)
	local skin = Color3.fromRGB(130, 150, 95)
	add(turtle, Vector3.new(4.8, 1.7, 6), shell, CFrame.identity, { shape = Enum.PartType.Ball, material = Enum.Material.Slate })
	add(turtle, Vector3.new(4.4, 1.1, 5.6), Color3.fromRGB(215, 200, 150), CFrame.new(0, -0.35, 0), { shape = Enum.PartType.Ball })
	add(turtle, Vector3.new(1.3, 1.1, 1.8), skin, CFrame.new(0, 0.1, -3.6), { shape = Enum.PartType.Ball })
	for side = -1, 1, 2 do
		add(turtle, Vector3.new(0.25, 0.25, 0.25), Color3.new(0.05, 0.05, 0.05), CFrame.new(side * 0.42, 0.35, -4.2), { shape = Enum.PartType.Ball })
		add(turtle, Vector3.new(3.4, 0.25, 1.1), skin, CFrame.new(side * 1.7, 0, 0), {
			pivot = CFrame.new(side * 2, -0.1, -1.6) * CFrame.Angles(0, side * 0.35, 0),
			swing = Vector3.new(0, 0, side * 0.55),
			speed = 1.6,
		})
		add(turtle, Vector3.new(1.6, 0.2, 0.9), skin, CFrame.new(side * 0.8, 0, 0), {
			pivot = CFrame.new(side * 1.6, -0.2, 2.4),
			swing = Vector3.new(0, 0, side * 0.3),
			speed = 1.6,
			phase = math.pi,
		})
	end
end

local JELLY_COLORS = {
	Color3.fromRGB(255, 140, 200),
	Color3.fromRGB(170, 140, 255),
	Color3.fromRGB(120, 210, 255),
	Color3.fromRGB(255, 200, 120),
}

local function addJellyfish()
	local home = randomPoint(NumberRange.new(10, 28))
	local drift = rng:NextNumber(0, math.pi * 2)
	local jelly = newCreature("Jellyfish", function(t)
		local position = home + Vector3.new(math.sin(t * 0.05 + drift) * 14, math.sin(t * 0.3 + drift) * 3, math.cos(t * 0.04 + drift) * 14)
		return CFrame.new(position) * CFrame.Angles(math.sin(t * 0.5 + drift) * 0.12, t * 0.1, math.cos(t * 0.4 + drift) * 0.12)
	end)
	local color = JELLY_COLORS[rng:NextInteger(1, #JELLY_COLORS)]
	add(jelly, Vector3.new(2.6, 1.8, 2.6), color, CFrame.identity, { shape = Enum.PartType.Ball, material = Enum.Material.Glass, transparency = 0.35 })
	local core = add(jelly, Vector3.new(1.2, 0.8, 1.2), color:Lerp(Color3.new(1, 1, 1), 0.4), CFrame.new(0, -0.1, 0), {
		shape = Enum.PartType.Ball,
		material = Enum.Material.Neon,
		transparency = 0.2,
	})
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 7
	glow.Brightness = 1
	glow.Parent = core
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		add(jelly, Vector3.new(0.12, 3.6, 0.12), color, CFrame.new(0, -1.8, 0), {
			transparency = 0.3,
			pivot = CFrame.new(math.cos(angle) * 0.7, -0.6, math.sin(angle) * 0.7),
			swing = Vector3.new(math.sin(angle), 0, -math.cos(angle)) * 0.3,
			speed = 2,
			phase = i,
		})
	end
end

local function addManta()
	local center = Vector3.new(0, rng:NextNumber(38, 46), MIDDLE_Z)
	local manta = newCreature("MantaRay", along(loop(center, 300, 140, 4, 9)))
	local back = Color3.fromRGB(40, 55, 80)
	add(manta, Vector3.new(3.6, 0.9, 5), back, CFrame.identity, { shape = Enum.PartType.Ball })
	add(manta, Vector3.new(3.2, 0.6, 4.6), Color3.fromRGB(225, 230, 235), CFrame.new(0, -0.2, 0), { shape = Enum.PartType.Ball })
	add(manta, Vector3.new(0.15, 0.15, 7), back, CFrame.new(0, 0, 5.8))
	for side = -1, 1, 2 do
		add(manta, Vector3.new(6.5, 0.3, 3.6), back, CFrame.new(side * 3.1, 0, 0.4) * CFrame.Angles(0, -side * 0.35, 0), {
			pivot = CFrame.new(side * 1.5, 0, 0.2),
			swing = Vector3.new(0, 0, side * 0.45),
			speed = 1.1,
		})
		add(manta, Vector3.new(0.4, 0.4, 1.4), back, CFrame.new(side * 1.1, 0, -2.9))
	end
end

-- The Whale Pass whale crosses the whole map overhead during the event. Its path runs on
-- server time, so every player sees it in the same place.
local WHALE_FROM = Vector3.new(AREA.minX - 40, 55, ReefConfig.PLOT_ROW_Z)
local WHALE_TO = Vector3.new(AREA.maxX + 40, 55, ReefConfig.PLOT_ROW_Z)

local function addWhale(startedAt: number, endsAt: number): Creature
	local serverOffset = Workspace:GetServerTimeNow() - os.clock()
	local whale = newCreature("Whale", along(function(t)
		local progress = (t + serverOffset - startedAt) / (endsAt - startedAt)
		return WHALE_FROM:Lerp(WHALE_TO, progress) + Vector3.new(0, math.sin(progress * math.pi * 3) * 3, 0)
	end))
	local skin = Color3.fromRGB(70, 92, 125)
	add(whale, Vector3.new(14, 12, 42), skin, CFrame.identity, { shape = Enum.PartType.Ball, shadow = true })
	add(whale, Vector3.new(12, 8, 38), Color3.fromRGB(200, 210, 220), CFrame.new(0, -2.6, -1), { shape = Enum.PartType.Ball })
	add(whale, Vector3.new(0.8, 2.5, 4), skin, CFrame.new(0, 6, 8) * CFrame.Angles(-0.4, 0, 0))
	for side = -1, 1, 2 do
		add(whale, Vector3.new(1.2, 1.2, 1.2), Color3.new(0.05, 0.05, 0.05), CFrame.new(side * 6.3, 0.5, -13), { shape = Enum.PartType.Ball })
		add(whale, Vector3.new(12, 0.8, 4.5), skin, CFrame.new(side * 6, 0, 0), {
			pivot = CFrame.new(side * 6, -3, -7) * CFrame.Angles(0, -side * 0.4, -side * 0.3),
			swing = Vector3.new(0, 0, side * 0.25),
			speed = 0.7,
			shadow = true,
		})
	end
	-- The tail stock and flukes beat up and down together from the same pivot.
	local tailPivot = CFrame.new(0, 0.5, 16)
	local beat = Vector3.new(0.3, 0, 0)
	add(whale, Vector3.new(6, 5, 18), skin, CFrame.new(0, 0, 8), { shape = Enum.PartType.Ball, pivot = tailPivot, swing = beat, speed = 0.9, shadow = true })
	add(whale, Vector3.new(22, 0.8, 6), skin, CFrame.new(0, 0, 17), { pivot = tailPivot, swing = beat, speed = 0.9, shadow = true })
	return whale
end

local function removeCreature(creature: Creature)
	local index = table.find(creatures, creature)
	if index then
		table.remove(creatures, index)
	end
	creature.model:Destroy()
end

local CRAB_COLORS = { Color3.fromRGB(220, 80, 50), Color3.fromRGB(240, 130, 40), Color3.fromRGB(180, 60, 90) }

local function addCrab()
	-- Anywhere on open seabed, not buried in the row of reef mounds.
	local clear = ReefConfig.bedRadius(ReefConfig.MAX_SLOTS) + 10
	local home
	repeat
		home = Vector3.new(rng:NextNumber(AREA.minX, AREA.maxX), 0, rng:NextNumber(AREA.minZ, AREA.maxZ))
	until math.abs(home.Z - ReefConfig.PLOT_ROW_Z) > clear
	local facing = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local phase = rng:NextNumber(0, math.pi * 2)
	-- Crabs scuttle sideways, back and forth along their own right-hand axis.
	local crab = newCreature("Crab", function(t)
		return CFrame.new(home + facing.RightVector * math.sin(t * 0.4 + phase) * 5) * facing
	end)
	local color = CRAB_COLORS[rng:NextInteger(1, #CRAB_COLORS)]
	add(crab, Vector3.new(2.1, 0.9, 1.7), color, CFrame.new(0, 0.55, 0), { shape = Enum.PartType.Ball })
	for side = -1, 1, 2 do
		add(crab, Vector3.new(0.35, 0.35, 0.35), Color3.new(1, 1, 1), CFrame.new(side * 0.35, 1.25, -0.45), { shape = Enum.PartType.Ball })
		add(crab, Vector3.new(0.7, 0.55, 0.75), color, CFrame.new(side * 1.15, 0.55, -1.3), { shape = Enum.PartType.Ball })
		for leg = 1, 3 do
			add(crab, Vector3.new(1, 0.15, 0.15), color, CFrame.new(side * 0.45, -0.2, 0) * CFrame.Angles(0, 0, -side * 0.6), {
				pivot = CFrame.new(side * 0.9, 0.5, (leg - 2) * 0.45),
				swing = Vector3.new(0.35, 0, 0),
				speed = 9,
				phase = leg + (if side > 0 then math.pi else 0),
			})
		end
	end
end

function SeaLife.start()
	folder = Instance.new("Folder")
	folder.Name = "SeaLife" -- built on this client only; nothing here replicates
	folder.Parent = Workspace

	for _ = 1, SETTINGS.fishSchools do
		addSchool()
	end
	for _ = 1, SETTINGS.turtles do
		addTurtle()
	end
	for _ = 1, SETTINGS.jellyfish do
		addJellyfish()
	end
	for _ = 1, SETTINGS.mantas do
		addManta()
	end
	for _ = 1, SETTINGS.crabs do
		addCrab()
	end

	local moving: { BasePart } = {}
	local targets: { CFrame } = {}
	local function update(everything: boolean)
		local t = os.clock()
		local camera = Workspace.CurrentCamera.CFrame.Position
		table.clear(moving)
		table.clear(targets)
		for _, creature in creatures do
			local root = creature.path(t)
			if everything or (root.Position - camera).Magnitude <= UPDATE_DISTANCE then
				for i, p in creature.parts do
					local joint = creature.joints[i]
					local cf = root * joint.pivot
					if joint.swing then
						local s = math.sin(t * joint.speed + joint.phase)
						cf *= CFrame.Angles(joint.swing.X * s, joint.swing.Y * s, joint.swing.Z * s)
					end
					table.insert(moving, p)
					table.insert(targets, cf * joint.offset)
				end
			end
		end
		Workspace:BulkMoveTo(moving, targets, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- The whale exists only while a Whale Pass runs (Events sets these attributes).
	local whale: Creature? = nil
	local function onEvent()
		local startedAt = Workspace:GetAttribute("EventStartedAt")
		local endsAt = Workspace:GetAttribute("EventEndsAt")
		local passing = Workspace:GetAttribute("EventId") == "Whale" and type(startedAt) == "number" and type(endsAt) == "number"
		if passing and not whale then
			whale = addWhale(startedAt, endsAt)
			update(true)
		elseif not passing and whale then
			removeCreature(whale)
			whale = nil
		end
	end
	Workspace:GetAttributeChangedSignal("EventId"):Connect(onEvent)
	Workspace:GetAttributeChangedSignal("EventEndsAt"):Connect(onEvent)

	-- Place everything once, so far-off creatures don't wait at the origin until approached.
	update(true)
	onEvent()
	RunService.Heartbeat:Connect(function()
		update(false)
	end)
end

return SeaLife
