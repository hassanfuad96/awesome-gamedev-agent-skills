--!nonstrict
-- Models for the Shipwreck event, built from plain Parts: the sunken liner (a hollow hull you
-- can swim into through holes in its sides and hatches in its deck) and the orcas (the orca
-- mesh creature once it has loaded, else Parts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)

local ShipwreckVisuals = {}

local SHIP = ReefConfig.Shipwreck
local HULL = Color3.fromRGB(34, 36, 42)
local HULL_RED = Color3.fromRGB(130, 40, 32)
local WHITE = Color3.fromRGB(226, 226, 218)
local FUNNEL = Color3.fromRGB(196, 150, 78)
local WEED = Color3.fromRGB(78, 112, 62)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X

local function piece(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- One side of the hull (z = side * half width), solid except for the holes in `gaps`. Holes
-- run from y = 5 up to their top, so the red stripe below them stays whole.
local function hullSide(model: Model, side: number, gaps: { { x: number, width: number, top: number } })
	local half = SHIP.length / 2
	local z = side * (SHIP.width / 2 - 0.5)
	local function wall(fromX: number, toX: number, bottom: number, top: number)
		if toX - fromX > 0.05 and top - bottom > 0.05 then
			piece(model, "Hull", Vector3.new(toX - fromX, top - bottom, 1), CFrame.new((fromX + toX) / 2, (bottom + top) / 2, z), HULL)
		end
	end
	local x = -half
	for _, gap in gaps do
		local left, right = gap.x - gap.width / 2, gap.x + gap.width / 2
		wall(x, left, 0, SHIP.height)
		wall(left, right, 0, 5) -- below the hole
		wall(left, right, gap.top, SHIP.height) -- above it
		x = right
	end
	wall(x, half, 0, SHIP.height)
	-- Painted bands on the outside: red below the old waterline, white along the top.
	piece(model, "RedBand", Vector3.new(SHIP.length, 4.6, 0.1), CFrame.new(0, 2.5, z + side * 0.55), HULL_RED, Enum.Material.SmoothPlastic)
	piece(model, "WhiteBand", Vector3.new(SHIP.length, 0.8, 0.1), CFrame.new(0, SHIP.height - 1, z + side * 0.55), WHITE, Enum.Material.SmoothPlastic)
end

-- The wreck at the origin, keel at y = 0, bow towards +X. Pivot it into place.
function ShipwreckVisuals.buildShip(): Model
	local model = Instance.new("Model")
	model.Name = "Shipwreck"
	local keel = piece(model, "Keel", Vector3.new(1, 1, 1), CFrame.identity, HULL)
	keel.Transparency = 1
	keel.CanCollide = false
	model.PrimaryPart = keel

	local half = SHIP.length / 2
	local inner = SHIP.width - 2
	local rng = Random.new(1912) -- the same wreck every time

	-- The hollow hull: floor, two holed sides, a stern wall and a pointed bow.
	piece(model, "Floor", Vector3.new(SHIP.length, 1, SHIP.width), CFrame.new(0, 0.5, 0), HULL)
	hullSide(model, 1, { { x = -36, width = 10, top = 14 }, { x = 22, width = 16, top = 15 } }) -- the big gash
	hullSide(model, -1, { { x = -8, width = 10, top = 14 }, { x = 40, width = 8, top = 13 } })
	piece(model, "Stern", Vector3.new(1, SHIP.height, inner), CFrame.new(-half + 0.5, SHIP.height / 2, 0), HULL)
	piece(model, "BowWall", Vector3.new(1, SHIP.height, inner), CFrame.new(half - 0.5, SHIP.height / 2, 0), HULL)
	local bowSize = SHIP.width / math.sqrt(2)
	piece(model, "Bow", Vector3.new(bowSize, SHIP.height, bowSize), CFrame.new(half, SHIP.height / 2, 0) * CFrame.Angles(0, math.rad(45), 0), HULL)

	-- Deck, open at two hatches fore and aft.
	local hatches = { { x = -48, width = 9 }, { x = 46, width = 9 } }
	local x = -half
	for _, hatch in hatches do
		local left = hatch.x - hatch.width / 2
		piece(model, "Deck", Vector3.new(left - x, 1, SHIP.width), CFrame.new((x + left) / 2, SHIP.height - 0.5, 0), Color3.fromRGB(120, 98, 74), Enum.Material.WoodPlanks)
		x = hatch.x + hatch.width / 2
	end
	piece(model, "Deck", Vector3.new(half - x, 1, SHIP.width), CFrame.new((x + half) / 2, SHIP.height - 0.5, 0), Color3.fromRGB(120, 98, 74), Enum.Material.WoodPlanks)

	-- Superstructure, with a dark strip of windows along each side.
	local top = SHIP.height
	piece(model, "Superstructure", Vector3.new(62, 6, SHIP.width - 6), CFrame.new(-2, top + 3, 0), WHITE, Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		piece(model, "Windows", Vector3.new(58, 1.2, 0.2), CFrame.new(-2, top + 4, side * ((SHIP.width - 6) / 2 + 0.1)), Color3.fromRGB(40, 52, 64), Enum.Material.Glass)
	end

	-- Four funnels; the last has snapped off and lies across the deck.
	for i, fx in { -24, -9, 6, 21 } do
		local base = CFrame.new(fx, top + 6, 0)
		if i == 4 then
			-- Lying across the top of the superstructure.
			base = CFrame.new(fx + 3, top + 8.5, -6) * CFrame.Angles(math.rad(85), 0, 0)
		end
		piece(model, "Funnel", Vector3.new(12, 5, 5), base * CFrame.new(0, 6, 0) * UPRIGHT, FUNNEL, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		piece(model, "FunnelTop", Vector3.new(2.5, 5.2, 5.2), base * CFrame.new(0, 11, 0) * UPRIGHT, Color3.fromRGB(20, 20, 22), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	-- Masts fore and aft, leaning where they bent on the way down.
	piece(model, "Mast", Vector3.new(0.8, 24, 0.8), CFrame.new(50, top + 12, 0) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(90, 70, 52), Enum.Material.Wood)
	piece(model, "Mast", Vector3.new(0.8, 20, 0.8), CFrame.new(-52, top + 10, 0) * CFrame.Angles(math.rad(8), 0, math.rad(6)), Color3.fromRGB(90, 70, 52), Enum.Material.Wood)

	-- The name on both sides of the bow.
	for _, side in { -1, 1 } do
		local plate = piece(model, "NamePlate", Vector3.new(16, 2.4, 0.1), CFrame.new(half - 14, top - 3.5, side * (SHIP.width / 2 + 0.06)), HULL, Enum.Material.SmoothPlastic)
		plate.Transparency = 1
		plate.CanCollide = false
		local gui = Instance.new("SurfaceGui")
		gui.Face = if side > 0 then Enum.NormalId.Back else Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = plate
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Garamond
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(235, 220, 170)
		label.Text = "S.S. CORALIA"
		label.Parent = gui
	end

	-- Inside: dim lanterns so hiders can see, and crates that tumbled loose.
	for _, lx in { -36, -6, 26 } do
		local lantern = piece(model, "Lantern", Vector3.new(1, 1.4, 1), CFrame.new(lx, SHIP.height - 3, 0), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
		lantern.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Range = 22
		light.Brightness = 1.4
		light.Parent = lantern
	end
	for i = 1, 6 do
		local s = rng:NextNumber(2.5, 4)
		piece(model, "Crate", Vector3.new(s, s, s), CFrame.new(rng:NextNumber(-half + 6, half - 8), 1 + s / 2, rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)), Color3.fromRGB(130, 100, 70), Enum.Material.WoodPlanks)
	end
	-- Weed growing on the hull.
	for _ = 1, 14 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local w = rng:NextNumber(3, 8)
		local patch = piece(model, "Weed", Vector3.new(w, rng:NextNumber(1.5, 4), 0.15), CFrame.new(rng:NextNumber(-half + 4, half - 4), rng:NextNumber(5.5, 16), side * (SHIP.width / 2 + 0.12)), WEED, Enum.Material.Grass)
		patch.CanCollide = false
		patch.CanQuery = false
	end
	return model
end

-- A burst of sand where the wreck hits the seabed.
function ShipwreckVisuals.sandBurst(parent: Instance, at: Vector3)
	local p = piece(parent, "SandBurst", Vector3.new(SHIP.length, 1, SHIP.width), CFrame.new(at), Color3.new(), Enum.Material.SmoothPlastic)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	local sand = Instance.new("ParticleEmitter")
	sand.Texture = "rbxasset://textures/particles/smoke_main.dds"
	sand.Color = ColorSequence.new(Color3.fromRGB(214, 196, 150))
	sand.Size = NumberSequence.new(4, 12)
	sand.Transparency = NumberSequence.new(0.3, 1)
	sand.Lifetime = NumberRange.new(2, 3.5)
	sand.Speed = NumberRange.new(10, 22)
	sand.SpreadAngle = Vector2.new(70, 70)
	sand.Drag = 2
	sand.Rate = 0
	sand.Parent = p
	sand:Emit(80)
	task.delay(4, function()
		p:Destroy()
	end)
end

export type Orca = { model: Model, root: BasePart, mover: AlignPosition, turner: AlignOrientation }

-- The orca built from Parts, for when its mesh hasn't loaded.
local function partOrca(at: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Orca"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 2, 2)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = at
	root.Parent = model
	model.PrimaryPart = root

	local black = Color3.fromRGB(18, 20, 26)
	local function add(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, wedge: boolean?)
		local p = Instance.new(if wedge then "WedgePart" else "Part")
		p.Name = name
		p.Size = size
		p.CFrame = at * offset
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		if not wedge then
			p.Shape = shape or Enum.PartType.Block
		end
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	add("Body", Vector3.new(7, 6, 18), CFrame.identity, black, Enum.PartType.Ball)
	add("Belly", Vector3.new(5.4, 4, 15), CFrame.new(0, -1.5, -0.6), Color3.fromRGB(238, 238, 232), Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		add("EyePatch", Vector3.new(1.4, 1.1, 2.8), CFrame.new(side * 2.9, 1, -5.4), Color3.fromRGB(238, 238, 232), Enum.PartType.Ball)
		add("Flipper", Vector3.new(4, 0.4, 2.6), CFrame.new(side * 4, -2, -2.5) * CFrame.Angles(0, side * 0.4, side * -0.35), black)
	end
	add("Dorsal", Vector3.new(0.6, 6, 4), CFrame.new(0, 5.5, 1.2), black, nil, true)
	add("Fluke", Vector3.new(8, 0.5, 3), CFrame.new(0, 0, 10), black)
	return model, root
end

-- The orca mesh, with its Root made a little heavier so the movers have something to push.
local function meshOrca(at: CFrame): (Model?, BasePart?)
	local model = Creatures.clone("orca")
	if not model then
		return nil, nil
	end
	model.Name = "Orca"
	model:SetAttribute("Pace", 1.4)
	local root = model.PrimaryPart
	root.Size = Vector3.new(2, 2, 2)
	root.Anchored = false
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = false
		end
	end
	model:PivotTo(at)
	return model, root
end

-- An orca facing -Z. It is unanchored and moved by its AlignPosition/AlignOrientation, so
-- clients see it glide smoothly; the server owns its physics.
function ShipwreckVisuals.buildOrca(at: CFrame): Orca
	local model, root = meshOrca(at)
	if not (model and root) then
		model, root = partOrca(at)
	end

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local mover = Instance.new("AlignPosition")
	mover.Mode = Enum.PositionAlignmentMode.OneAttachment
	mover.Attachment0 = attachment
	mover.Position = at.Position
	mover.MaxForce = 1e7
	mover.MaxVelocity = ReefConfig.Shipwreck.orcaSpeed
	mover.Responsiveness = 40
	mover.Parent = root
	local turner = Instance.new("AlignOrientation")
	turner.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turner.Attachment0 = attachment
	turner.CFrame = at.Rotation
	turner.MaxTorque = 1e7
	turner.Responsiveness = 12
	turner.Parent = root
	return { model = model, root = root, mover = mover, turner = turner }
end

return ShipwreckVisuals
