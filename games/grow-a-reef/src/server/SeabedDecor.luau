--!nonstrict
-- Seabed decoration around the play area: kelp forests towards the edges, big coral
-- clusters, starfish and sea urchins. Static and decorative, built once by World. None of
-- it collides or takes clicks, so it never gets between a player and their reef.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local CoralVisuals = require(ReplicatedStorage.Shared.CoralVisuals)

local SeabedDecor = {}

-- Where decoration may go, inside the roaming area of ReefConfig.SeaLife.
local AREA = ReefConfig.SeaLife.area
local KELP = Color3.fromRGB(80, 120, 50)
local STARFISH_COLORS = { Color3.fromRGB(235, 95, 60), Color3.fromRGB(250, 165, 45), Color3.fromRGB(205, 75, 140) }
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X

local function piece(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
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
	p.Parent = parent
	return p
end

-- A random clear point on the seabed, or nil after a few tries. accept narrows the choice.
local function spot(rng: Random, isClear: (number, number) -> boolean, accept: ((number, number) -> boolean)?): Vector3?
	for _ = 1, 40 do
		local x = rng:NextNumber(AREA.minX, AREA.maxX)
		local z = rng:NextNumber(AREA.minZ, AREA.maxZ)
		if isClear(x, z) and (not accept or accept(x, z)) then
			return Vector3.new(x, 0, z)
		end
	end
	return nil
end

-- One kelp strand: leaning stalk segments, a leaf on every other joint, a float on top.
local function kelpStrand(parent: Instance, base: Vector3, height: number, rng: Random)
	local segments = 4
	local length = height / segments
	local color = KELP:Lerp(Color3.fromRGB(150, 120, 50), rng:NextNumber(0, 0.5))
	local cf = CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	for i = 1, segments do
		cf *= CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
		piece(parent, "KelpStalk", Vector3.new(length + 0.2, 0.45, 0.45), cf * CFrame.new(0, length / 2, 0) * UPRIGHT, color, Enum.Material.Grass, Enum.PartType.Cylinder)
		if i % 2 == 0 then
			local leaf = cf * CFrame.new(0, length * 0.8, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0.6)
			piece(parent, "KelpLeaf", Vector3.new(0.15, length * 0.7, 1.8), leaf * CFrame.new(0, 0, 0.9), color, Enum.Material.Grass)
		end
		cf *= CFrame.new(0, length, 0)
	end
	piece(parent, "KelpFloat", Vector3.new(0.9, 0.9, 0.9), cf, Color3.fromRGB(200, 170, 70), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

local function starfish(parent: Instance, position: Vector3, rng: Random)
	local color = STARFISH_COLORS[rng:NextInteger(1, #STARFISH_COLORS)]
	local cf = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	piece(parent, "Starfish", Vector3.new(1.1, 0.35, 1.1), cf, color, Enum.Material.Pebble, Enum.PartType.Ball)
	for arm = 1, 5 do
		local angle = (arm / 5) * math.pi * 2
		piece(parent, "StarfishArm", Vector3.new(0.45, 0.25, 1.5), cf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -0.9), color, Enum.Material.Pebble)
	end
end

local function urchin(parent: Instance, position: Vector3, rng: Random)
	local size = rng:NextNumber(1.2, 2)
	local center = position + Vector3.new(0, size * 0.4, 0)
	local color = Color3.fromRGB(70, 35, 80):Lerp(Color3.fromRGB(20, 20, 30), rng:NextNumber(0, 0.6))
	piece(parent, "Urchin", Vector3.new(size, size * 0.8, size), CFrame.new(center), color, Enum.Material.Slate, Enum.PartType.Ball)
	for _ = 1, 7 do
		-- Each spike runs straight through the middle, so it pokes out on both sides.
		local direction = CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi))
		piece(parent, "UrchinSpike", Vector3.new(size * 1.9, 0.08, 0.08), CFrame.new(center) * direction, color, Enum.Material.Slate, Enum.PartType.Cylinder)
	end
end

function SeabedDecor.build(root: Instance, rng: Random, isClear: (number, number) -> boolean)
	local folder = Instance.new("Folder")
	folder.Name = "SeabedDecor"
	folder.Parent = root

	-- Kelp forests stand towards the edges, where they frame the view without hiding reefs.
	local function nearEdge(x: number, z: number): boolean
		return math.abs(x) > 165 or z < -75 or z > 110
	end
	for _ = 1, 7 do
		local center = spot(rng, isClear, nearEdge)
		if center then
			for _ = 1, rng:NextInteger(6, 9) do
				local offset = Vector3.new(rng:NextNumber(-9, 9), 0, rng:NextNumber(-9, 9))
				kelpStrand(folder, center + offset, rng:NextNumber(16, 34), rng)
			end
		end
	end

	-- Coral clusters reuse the planted coral models, grown well past full size.
	for _ = 1, 9 do
		local center = spot(rng, isClear)
		if center then
			for _ = 1, rng:NextInteger(3, 5) do
				local seedId = ReefConfig.SEED_ORDER[rng:NextInteger(1, #ReefConfig.SEED_ORDER)]
				local at = center + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
				local coral = CoralVisuals.build(seedId, "None", CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				coral.Name = "DecorCoral"
				coral:ScaleTo(rng:NextNumber(1.4, 2.4))
				coral.Parent = folder
			end
		end
	end

	for _ = 1, 16 do
		local at = spot(rng, isClear)
		if at then
			starfish(folder, at, rng)
		end
	end
	for _ = 1, 12 do
		local at = spot(rng, isClear)
		if at then
			urchin(folder, at, rng)
		end
	end
end

return SeabedDecor
