--!nonstrict
-- Pet models for the followers (PetFollowers) and the Pets panel. Pets with a mesh model
-- (Creatures: all three, the seahorse, pufferfish and octopus) use it once the server has built the templates;
-- the others, and every pet before then, are made from plain Parts.
-- Each model's pivot is its centre and it faces -Z. Golden pets are gold foil and sparkle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local Creatures = require(ReplicatedStorage.Shared.Creatures)

local PetVisuals = {}

local GOLD = Color3.fromRGB(255, 200, 60)
local DARK = Color3.fromRGB(25, 25, 30)
local FORWARD = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder (along X) to face -Z
local MESH_LENGTH = { seahorse = 2.6, pufferfish = 2, octopus = 2.2 } -- pets with a mesh model, at this size

local function piece(model: Model, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Shape = shape or Enum.PartType.Ball
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function eyes(model: Model, x: number, y: number, z: number, size: number)
	for side = -1, 1, 2 do
		piece(model, Vector3.one * size, CFrame.new(side * x, y, z), Color3.new(1, 1, 1))
		piece(model, Vector3.one * size * 0.5, CFrame.new(side * x, y, z - size * 0.35), DARK)
	end
end

local builders: { [string]: (Model, Color3) -> () } = {
	seahorse = function(model, color)
		piece(model, Vector3.new(0.8, 0.8, 0.9), CFrame.new(0, 1, -0.1), color)
		piece(model, Vector3.new(0.6, 0.25, 0.25), CFrame.new(0, 0.95, -0.7) * FORWARD, color, Enum.PartType.Cylinder)
		piece(model, Vector3.new(0.9, 1.2, 0.8), CFrame.new(0, 0.1, 0.15), color)
		piece(model, Vector3.new(0.7, 0.9, 0.6), CFrame.new(0, -0.6, 0.15), color)
		-- The tail curls forward under the body.
		piece(model, Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, -1.1, 0.35), color)
		piece(model, Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, -1.35, 0.1), color)
		piece(model, Vector3.new(0.28, 0.28, 0.28), CFrame.new(0, -1.25, -0.15), color)
		piece(model, Vector3.new(0.08, 0.6, 0.4), CFrame.new(0, 0.2, 0.55), color:Lerp(Color3.new(1, 1, 1), 0.3), Enum.PartType.Block)
		eyes(model, 0.36, 1.1, -0.25, 0.22)
	end,
	octopus = function(model, color)
		piece(model, Vector3.new(1.6, 1.5, 1.6), CFrame.new(0, 0.5, 0), color)
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			-- Each arm leaves the head's underside and curls outwards and down.
			local arm = CFrame.new(math.cos(angle) * 0.5, -0.15, math.sin(angle) * 0.5)
				* CFrame.Angles(0, -angle, 0)
				* CFrame.Angles(0, 0, math.rad(-55))
				* CFrame.new(0.55, 0, 0)
			piece(model, Vector3.new(1.2, 0.28, 0.28), arm, color:Lerp(Color3.new(0, 0, 0), 0.1), Enum.PartType.Cylinder)
		end
		eyes(model, 0.35, 0.6, -0.68, 0.4)
	end,
	pufferfish = function(model, color)
		piece(model, Vector3.new(1.6, 1.5, 1.6), CFrame.identity, color)
		local spike = color:Lerp(Color3.fromRGB(120, 80, 30), 0.4)
		for i = 1, 12 do
			-- Spikes spread over the body using the golden angle.
			local y = 1 - (i - 0.5) / 12 * 2
			local r = math.sqrt(1 - y * y)
			local a = i * 2.39996
			local outward = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
			piece(model, Vector3.new(0.5, 0.1, 0.1), CFrame.lookAt(outward * 0.8, outward * 2) * FORWARD, spike, Enum.PartType.Cylinder)
		end
		piece(model, Vector3.new(0.1, 0.7, 0.6), CFrame.new(0, 0, 0.95), color:Lerp(Color3.new(1, 1, 1), 0.2), Enum.PartType.Block)
		eyes(model, 0.38, 0.25, -0.7, 0.35)
	end,
}

function PetVisuals.build(species: string, golden: boolean): Model
	local def = ReefConfig.Pets.species[species]
	local creature = MESH_LENGTH[species] and Creatures.clone(species, MESH_LENGTH[species])
	if creature then
		creature.Name = if def then def.name else species
		creature:SetAttribute("Pace", 0.8) -- keeping pace beside you (CreatureAnimator)
		if golden then
			Creatures.gild(creature, GOLD)
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = GOLD
			sparkles.Parent = creature.PrimaryPart
		end
		return creature
	end
	local model = Instance.new("Model")
	model.Name = if def then def.name else species
	local root = piece(model, Vector3.one, CFrame.identity, Color3.new(1, 1, 1), Enum.PartType.Block)
	root.Name = "Root"
	root.Transparency = 1
	model.PrimaryPart = root

	local build = builders[species]
	if build and def then
		build(model, if golden then GOLD else def.color)
	end
	if golden then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and p ~= root and p.Color ~= DARK and p.Color ~= Color3.new(1, 1, 1) then
				p.Material = Enum.Material.Foil
			end
		end
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = GOLD
		sparkles.Parent = root
	end
	return model
end

return PetVisuals
