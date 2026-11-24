--!nonstrict
-- Shopkeeper models made from plain Parts, like the coral and fish. Each model is tagged
-- ReefConfig.SHOPKEEPER_TAG and its Shopkeeper attribute names its ReefConfig.Shopkeepers
-- entry; the client's Shopkeepers module animates it and shows its greetings.
-- The base CFrame is the centre of the model's footprint, facing the players (-Z local).
-- The animal keepers with a mesh model (MESH_KEEPERS: Pinch, Otto and Lumi) swap their
-- Part-built body for it once the mesh templates are ready (ShopkeeperVisuals.start).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local Creatures = require(ReplicatedStorage.Shared.Creatures)

local ShopkeeperVisuals = {}

local BRASS = Color3.fromRGB(196, 146, 62)
local SUIT = Color3.fromRGB(190, 160, 96)
local DARK = Color3.fromRGB(56, 46, 40)
local SHELL = Color3.fromRGB(226, 96, 62)

local function piece(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.Parent = model
	return p
end

-- Roblox cylinders run along X: these turn them upright or to face forward.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local FORWARD = CFrame.Angles(0, math.rad(90), 0)

-- Every builder must make a part named "Head"; speech bubbles hang above it.
local builders: { [string]: (Model, CFrame) -> () } = {
	-- A deep-sea diver in a brass helmet, standing on a crate behind the counter.
	SeedShop = function(model, base)
		piece(model, "Crate", Vector3.new(3, 1, 2.2), base * CFrame.new(0, 0.5, 0), Color3.fromRGB(150, 110, 80), Enum.Material.Wood)
		for _, side in { -1, 1 } do
			piece(model, "Leg", Vector3.new(1, 2.4, 1), base * CFrame.new(side * 0.6, 2.2, 0), SUIT, Enum.Material.Fabric)
			piece(model, "Arm", Vector3.new(0.9, 2.4, 0.9), base * CFrame.new(side * 1.75, 4.7, 0), SUIT, Enum.Material.Fabric)
			piece(model, "Glove", Vector3.new(1, 0.7, 1), base * CFrame.new(side * 1.75, 3.2, 0), DARK, Enum.Material.SmoothPlastic)
			piece(model, "Eye", Vector3.new(0.28, 0.28, 0.28), base * CFrame.new(side * 0.3, 7.75, -1.42), DARK, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
		piece(model, "Torso", Vector3.new(2.6, 2.6, 1.5), base * CFrame.new(0, 4.7, 0), SUIT, Enum.Material.Fabric)
		piece(model, "Belt", Vector3.new(2.7, 0.4, 1.6), base * CFrame.new(0, 3.6, 0), DARK, Enum.Material.Leather)
		piece(model, "Collar", Vector3.new(0.6, 2.8, 2.8), base * CFrame.new(0, 6.2, 0) * UPRIGHT, BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
		local head = piece(model, "Head", Vector3.new(3, 3, 3), base * CFrame.new(0, 7.6, 0), BRASS, Enum.Material.Metal, Enum.PartType.Ball)
		-- A warm helmet lamp: the stall roof otherwise leaves the diver in deep shadow.
		local lamp = Instance.new("PointLight")
		lamp.Name = "HelmetLamp"
		lamp.Color = Color3.fromRGB(255, 214, 150)
		lamp.Range = 10
		lamp.Brightness = 2
		lamp.Parent = head
		piece(model, "Face", Vector3.new(0.1, 1.4, 1.4), base * CFrame.new(0, 7.6, -1.35) * FORWARD, Color3.fromRGB(234, 184, 146), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		piece(model, "Smile", Vector3.new(0.5, 0.1, 0.05), base * CFrame.new(0, 7.3, -1.42), DARK, Enum.Material.SmoothPlastic)
		local glass = piece(model, "Faceplate", Vector3.new(0.12, 1.7, 1.7), base * CFrame.new(0, 7.6, -1.5) * FORWARD, Color3.fromRGB(190, 230, 255), Enum.Material.Glass, Enum.PartType.Cylinder)
		glass.Transparency = 0.55
		piece(model, "Valve", Vector3.new(0.5, 0.7, 0.7), base * CFrame.new(0, 9.3, 0) * UPRIGHT, BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
	end,

	-- A crab sitting on the counter top.
	Sell = function(model, base)
		piece(model, "Head", Vector3.new(3, 1.3, 2.4), base * CFrame.new(0, 0.75, 0), SHELL, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for _, side in { -1, 1 } do
			piece(model, "EyeStalk", Vector3.new(0.7, 0.22, 0.22), base * CFrame.new(side * 0.5, 1.6, -0.6) * UPRIGHT, SHELL, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			piece(model, "Eye", Vector3.new(0.5, 0.5, 0.5), base * CFrame.new(side * 0.5, 2, -0.6), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			piece(model, "Pupil", Vector3.new(0.22, 0.22, 0.22), base * CFrame.new(side * 0.5, 2.05, -0.83), DARK, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			piece(model, "ClawArm", Vector3.new(0.35, 0.35, 1.1), base * CFrame.new(side * 1.3, 0.7, -1.2) * CFrame.Angles(0, side * math.rad(25), 0), SHELL, Enum.Material.SmoothPlastic)
			piece(model, "Claw", Vector3.new(1, 0.8, 1.1), base * CFrame.new(side * 1.65, 0.8, -1.85), SHELL:Lerp(DARK, 0.15), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			for _, z in { -0.3, 0.3, 0.9 } do
				-- Angled down and out so the tips rest on the counter.
				piece(model, "Leg", Vector3.new(1.4, 0.22, 0.22), base * CFrame.new(side * 1.85, 0.35, z) * CFrame.Angles(0, 0, -side * math.rad(32)), SHELL, Enum.Material.SmoothPlastic)
			end
		end
	end,

	-- An old sea turtle with spectacles, resting on the counter.
	Supplies = function(model, base)
		local skin = Color3.fromRGB(120, 170, 110)
		local shell = Color3.fromRGB(110, 86, 52)
		piece(model, "Shell", Vector3.new(3.2, 1.7, 3.6), base * CFrame.new(0, 1, 0.3), shell, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for i, at in { Vector3.new(0, 1.75, 0.3), Vector3.new(-0.8, 1.55, -0.4), Vector3.new(0.8, 1.55, -0.4), Vector3.new(-0.8, 1.55, 1), Vector3.new(0.8, 1.55, 1) } do
			piece(model, "Plate", Vector3.new(0.9, 0.3, 0.9), base * CFrame.new(at) * CFrame.Angles(0, math.rad(45), 0), shell:Lerp(Color3.fromRGB(200, 170, 110), 0.3 + i * 0.04), Enum.Material.SmoothPlastic)
		end
		piece(model, "Belly", Vector3.new(2.8, 0.5, 3.2), base * CFrame.new(0, 0.35, 0.3), Color3.fromRGB(226, 206, 150), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(model, "Neck", Vector3.new(0.8, 0.8, 1.2), base * CFrame.new(0, 1.2, -1.6), skin, Enum.Material.SmoothPlastic)
		piece(model, "Head", Vector3.new(1.4, 1.2, 1.5), base * CFrame.new(0, 1.6, -2.3), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for _, side in { -1, 1 } do
			piece(model, "Eye", Vector3.new(0.3, 0.3, 0.3), base * CFrame.new(side * 0.35, 1.8, -2.95), DARK, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			piece(model, "Lens", Vector3.new(0.06, 0.5, 0.5), base * CFrame.new(side * 0.35, 1.8, -3.05) * FORWARD, BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
			piece(model, "Flipper", Vector3.new(1.6, 0.25, 0.8), base * CFrame.new(side * 1.8, 0.4, -0.7) * CFrame.Angles(0, side * math.rad(-30), 0), skin, Enum.Material.SmoothPlastic)
			piece(model, "BackFlipper", Vector3.new(1, 0.25, 0.6), base * CFrame.new(side * 1.3, 0.35, 1.9) * CFrame.Angles(0, side * math.rad(35), 0), skin, Enum.Material.SmoothPlastic)
		end
		piece(model, "Bridge", Vector3.new(0.3, 0.08, 0.08), base * CFrame.new(0, 1.8, -3.05), BRASS, Enum.Material.Metal)
		piece(model, "Smile", Vector3.new(0.5, 0.08, 0.05), base * CFrame.new(0, 1.35, -3), DARK, Enum.Material.SmoothPlastic)
	end,

	-- Inky, the tutorial guide: a purple octopus with big eyes and a teal scarf, sitting on
	-- a rock with eight tentacles curling out over it.
	Guide = function(model, base)
		local skin = Color3.fromRGB(156, 96, 210)
		local belly = Color3.fromRGB(205, 160, 240)
		piece(model, "Head", Vector3.new(3.4, 3.4, 3.4), base * CFrame.new(0, 3.3, 0), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(model, "Mantle", Vector3.new(2.6, 2.6, 2.6), base * CFrame.new(0, 4.6, 0.7), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for _, side in { -1, 1 } do
			piece(model, "Eye", Vector3.new(1.2, 1.2, 1.2), base * CFrame.new(side * 0.72, 3.6, -1.25), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			piece(model, "Pupil", Vector3.new(0.55, 0.55, 0.55), base * CFrame.new(side * 0.7, 3.6, -1.8), DARK, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			piece(model, "Shine", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(side * 0.6, 3.75, -2.05), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
			piece(model, "Cheek", Vector3.new(0.5, 0.5, 0.5), base * CFrame.new(side * 1.25, 2.95, -1.25), Color3.fromRGB(255, 150, 190), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
		piece(model, "Smile", Vector3.new(0.7, 0.12, 0.1), base * CFrame.new(0, 2.75, -1.62), DARK, Enum.Material.SmoothPlastic)
		piece(model, "Scarf", Vector3.new(0.7, 3.3, 3.3), base * CFrame.new(0, 1.85, 0) * UPRIGHT, Color3.fromRGB(60, 200, 190), Enum.Material.Fabric, Enum.PartType.Cylinder)
		piece(model, "ScarfTail", Vector3.new(0.8, 1.4, 0.25), base * CFrame.new(0.9, 1.3, -1.5) * CFrame.Angles(0, 0, math.rad(-15)), Color3.fromRGB(60, 200, 190), Enum.Material.Fabric)
		-- Eight tentacles: a chain of shrinking balls running out and curling up at the tip.
		for arm = 0, 7 do
			local angle = (arm + 0.5) / 8 * math.pi * 2
			local out = Vector3.new(math.sin(angle), 0, -math.cos(angle))
			for k = 0, 4 do
				local reach = 1.1 + k * 0.55
				local lift = 1.35 - k * 0.22 + (if k == 4 then 0.45 else 0)
				local size = 0.95 - k * 0.13
				local position = out * reach + Vector3.new(0, lift, 0)
				piece(model, "Tentacle", Vector3.new(size, size, size), base * CFrame.new(position), if k == 4 then belly else skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			end
		end
	end,

	-- Otto, the Kelp Forest ranger: a sea otter sitting up on his rock in a ranger's hat,
	-- holding a sea urchin, with a pale face and whiskers.
	Otto = function(model, base)
		local fur = Color3.fromRGB(128, 90, 62)
		local face = Color3.fromRGB(222, 196, 158)
		local hat = Color3.fromRGB(70, 120, 60)
		piece(model, "Body", Vector3.new(2.6, 3.4, 2.2), base * CFrame.new(0, 1.9, 0), fur, Enum.Material.Fabric)
		piece(model, "Belly", Vector3.new(2, 2.4, 0.3), base * CFrame.new(0, 1.9, -1.05), face:Lerp(fur, 0.3), Enum.Material.Fabric)
		piece(model, "Head", Vector3.new(2.3, 2.3, 2.3), base * CFrame.new(0, 4.4, 0), fur, Enum.Material.Fabric, Enum.PartType.Ball)
		piece(model, "Muzzle", Vector3.new(1.5, 1.5, 1.5), base * CFrame.new(0, 4.1, -0.85), face, Enum.Material.Fabric, Enum.PartType.Ball)
		piece(model, "Nose", Vector3.new(0.45, 0.45, 0.45), base * CFrame.new(0, 4.35, -1.55), DARK, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(model, "HatBrim", Vector3.new(0.2, 3.2, 3.2), base * CFrame.new(0, 5.3, 0) * UPRIGHT, hat, Enum.Material.Fabric, Enum.PartType.Cylinder)
		piece(model, "HatTop", Vector3.new(1, 1.9, 1.9), base * CFrame.new(0, 5.8, 0) * UPRIGHT, hat:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Fabric, Enum.PartType.Cylinder)
		piece(model, "HatBand", Vector3.new(0.3, 1.95, 1.95), base * CFrame.new(0, 5.45, 0) * UPRIGHT, Color3.fromRGB(214, 170, 80), Enum.Material.Fabric, Enum.PartType.Cylinder)
		for _, side in { -1, 1 } do
			piece(model, "Eye", Vector3.new(0.35, 0.35, 0.35), base * CFrame.new(side * 0.5, 4.75, -0.95), DARK, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			piece(model, "Ear", Vector3.new(0.5, 0.5, 0.5), base * CFrame.new(side * 0.95, 5.15, 0.1), fur, Enum.Material.Fabric, Enum.PartType.Ball)
			piece(model, "Arm", Vector3.new(0.7, 1.6, 0.7), base * CFrame.new(side * 0.75, 2.6, -1.2) * CFrame.Angles(math.rad(-60), 0, side * 0.3), fur, Enum.Material.Fabric)
			piece(model, "Foot", Vector3.new(0.9, 0.5, 1.4), base * CFrame.new(side * 0.8, 0.3, -0.8), fur:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Fabric)
			for k = -1, 1 do
				piece(model, "Whisker", Vector3.new(1.1, 0.05, 0.05), base * CFrame.new(side * 1.05, 4.05 + k * 0.15, -1.35) * CFrame.Angles(0, side * 0.25, k * 0.12 * side), face, Enum.Material.SmoothPlastic)
			end
		end
		piece(model, "Tail", Vector3.new(0.8, 0.5, 2.4), base * CFrame.new(0, 0.3, 1.6), fur, Enum.Material.Fabric)
		-- A sea urchin held up in both paws.
		piece(model, "Urchin", Vector3.new(0.9, 0.9, 0.9), base * CFrame.new(0, 3.3, -1.75), Color3.fromRGB(110, 50, 130), Enum.Material.Slate, Enum.PartType.Ball)
	end,
}

function ShopkeeperVisuals.build(kind: string, base: CFrame): Model
	-- The human crew (ReefConfig.Crew) replaced these animal keepers: they're R15 NPCs that
	-- the Crew module spawns and walks about, so here's just an empty placeholder.
	if ReefConfig.Crew[kind] then
		local placeholder = Instance.new("Model")
		placeholder.Name = kind .. "CrewPost"
		return placeholder
	end
	local def = ReefConfig.Shopkeepers[kind]
	local build = builders[kind]
	assert(def and build, `no shopkeeper for stand kind {kind}`)

	local model = Instance.new("Model")
	model.Name = def.name
	-- Stream the whole shopkeeper in at once, so the client never animates half of one.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

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

	build(model, base)
	model:SetAttribute("Shopkeeper", kind)
	model:AddTag(ReefConfig.SHOPKEEPER_TAG)
	return model
end

-- Shopkeepers (by their Shopkeeper attribute) drawn with a mesh creature: its id, its size
-- (Creatures.clone), and `float` = how high its centre sits over the model's base (nil: it
-- stands on the base). `glow` lights the named piece (Lumi's lure).
local MESH_KEEPERS: { [string]: { creature: string, length: number, float: number?, glow: string? } } = {
	Sell = { creature = "crab", length = 4.2 },
	Otto = { creature = "otter", length = 5.6 },
	Abyss = { creature = "lanternfish", length = 4.6, float = 2.2, glow = "Lure" },
}

-- Swaps a Part-built shopkeeper's body for its mesh creature. Keeps the model, its Root and
-- tags, adds an invisible "Head" box over the creature for speech bubbles, and re-tags it so
-- every client's Shopkeepers module picks up the new Head.
local function upgrade(model: Model)
	local spec = MESH_KEEPERS[model:GetAttribute("Shopkeeper") or ""]
	local root = model.PrimaryPart
	local creature = spec and root and Creatures.clone(spec.creature, spec.length)
	if not creature or model:FindFirstChild("Creature") then
		return
	end
	local size = creature:GetExtentsSize()
	local base = (root :: BasePart).CFrame
	local centre = base * CFrame.new(0, spec.float or size.Y / 2, 0)
	creature.Name = "Creature"
	creature:SetAttribute("Pace", 0.5) -- resting at the counter (CreatureAnimator)
	creature:PivotTo(centre)
	for _, d in creature:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	if spec.glow then
		local bulb = creature:FindFirstChild(spec.glow) :: MeshPart?
		if bulb then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(150, 255, 230)
			light.Range = 18
			light.Brightness = 2
			light.Parent = bulb
		end
	end

	-- Untag first and give clients a moment to let go of the old Head before it goes.
	model:RemoveTag(ReefConfig.SHOPKEEPER_TAG)
	task.wait(0.5)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			child:Destroy()
		end
	end
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(size.X * 0.8, size.Y * 0.5, size.Z * 0.8)
	head.CFrame = centre * CFrame.new(0, size.Y * 0.25, 0)
	head.Transparency = 1
	head.Anchored = true
	head.CanCollide = false
	head.CanQuery = false
	head.CanTouch = false
	head.Parent = model
	creature.Parent = model
	model:AddTag(ReefConfig.SHOPKEEPER_TAG)
end

-- Once the mesh templates are built, every animal keeper in the world that has one swaps to it.
function ShopkeeperVisuals.start()
	Creatures.onReady(function()
		for _, model in CollectionService:GetTagged(ReefConfig.SHOPKEEPER_TAG) do
			if model:IsA("Model") and model:IsDescendantOf(Workspace) then
				task.spawn(function()
					local ok, problem = pcall(upgrade, model)
					if not ok then
						warn(`Shopkeeper {model.Name} kept its old look: {problem}`)
						model:AddTag(ReefConfig.SHOPKEEPER_TAG)
					end
				end)
			end
		end
	end)
end

return ShopkeeperVisuals
