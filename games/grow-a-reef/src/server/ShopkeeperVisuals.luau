--!nonstrict
-- Shopkeeper models made from plain Parts, like the coral and fish. Each model is tagged
-- ReefConfig.SHOPKEEPER_TAG and its Shopkeeper attribute names its ReefConfig.Shopkeepers
-- entry; the client's Shopkeepers module animates it and shows its greetings.
-- The base CFrame is the centre of the model's footprint, facing the players (-Z local).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)

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
}

function ShopkeeperVisuals.build(kind: string, base: CFrame): Model
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

return ShopkeeperVisuals
