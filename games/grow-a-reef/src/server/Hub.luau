--!nonstrict
-- The central hub's four buildings (positions in ReefConfig.Lagoon), from the concept art's
-- glass-domed undersea base, each joined to the plaza by a glass tube corridor:
--   Research Laboratory (north-west, the biggest): a geodesic glass dome over a research
--     tower, labs and coral garden beds, with a glowing coral on top. Its counter (Lab)
--     researches species, unlocks planters, upgrades coral growth and shows reef health.
--   Aquarium / Collection Center (north-east): a smaller dome of display tanks that each
--     player sees filled with what they've discovered (AquariumDisplay), the Reef Index and
--     the Pet Hatchery.
--   Coral Market (south-east): seeds (Captain Coralie), selling (Pinch), decorations and
--     fences, and a case of rare species, under a glass canopy.
--   Equipment Station (south-west): diving gear, the Oxygen Tank and Swim Fins (Old Shellby).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local CoralVisuals = require(ReplicatedStorage.Shared.CoralVisuals)
local WorldKit = require(script.Parent.WorldKit)
local ShopkeeperVisuals = require(script.Parent.ShopkeeperVisuals)

export type HubParts = {
	labStand: BasePart, -- the Lab counter (prompt Kind "Lab")
	shopStand: BasePart, -- the Market's seed counter
	sellStand: BasePart, -- the Market's sell counter
	marketDecorStand: BasePart, -- the Market's decorations and fences counter
	suppliesStand: BasePart, -- the Equipment Station counter
	hatcheryStand: BasePart, -- the Aquarium's Pet Hatchery counter
}

local Hub = {}

local LAGOON = ReefConfig.Lagoon
local CENTER = LAGOON.center
local C = WorldKit.Colors
local part, prop, disc, bar = WorldKit.part, WorldKit.prop, WorldKit.disc, WorldKit.bar
local seaGrass, surfaceLabel, prompt = WorldKit.seaGrass, WorldKit.surfaceLabel, WorldKit.prompt
local UPRIGHT = WorldKit.UPRIGHT
local GLOW = C.GLOW
local FRAME = Color3.fromRGB(196, 214, 224) -- the domes' metal frames
local GLASS = Color3.fromRGB(175, 230, 250)
local WARM = Color3.fromRGB(255, 214, 150) -- the lit interior, like the concept art
local FACE_PLAYERS = CFrame.Angles(0, math.pi, 0)

-- A building's frame on the seabed, with -Z pointing at the plaza (its door).
local function doorFrame(position: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(CENTER.X, position.Y, CENTER.Z))
end

-- A geodesic glass dome: a dark base ringed with light, a floor, the glass, and a metal frame
-- of latitude rings and meridian ribs (the door side left open low down). Returns the floor
-- height.
local function geodome(model: Model, frame: CFrame, radius: number, ribs: number): number
	local function at(x: number, y: number, z: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local base = 1.4
	disc(model, "DomeBase", radius + 1, base, at(0, base / 2, 0), C.METAL_DARK, Enum.Material.Metal)
	disc(model, "DomeBaseGlow", radius + 1.15, 0.35, at(0, base - 0.3, 0), GLOW, Enum.Material.Neon)
	disc(model, "DomeFloor", radius, 0.2, at(0, base + 0.1, 0), Color3.fromRGB(196, 214, 210), Enum.Material.SmoothPlastic)
	prop({ Name = "DomeGlass", Shape = Enum.PartType.Ball, Size = Vector3.new(radius * 2, radius * 2, radius * 2), Position = at(0, base, 0), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.78, Reflectance = 0.08, CastShadow = false, Parent = model })
	local function point(azimuth: number, latitude: number): Vector3
		local flat = math.cos(latitude) * (radius + 0.1)
		return at(math.sin(azimuth) * flat, base + math.sin(latitude) * (radius + 0.1), -math.cos(azimuth) * flat)
	end
	-- Latitude rings.
	for _, degrees in { 14, 30, 46, 62, 76 } do
		local latitude = math.rad(degrees)
		local ringRadius = math.cos(latitude) * radius
		local count = math.max(8, math.round(math.pi * 2 * ringRadius / 7))
		for k = 0, count - 1 do
			local a, b = (k / count) * math.pi * 2, ((k + 1) / count) * math.pi * 2
			-- Leave the doorway clear on the lowest ring.
			if not (degrees == 14 and (math.abs(math.sin(a / 2)) < 0.12)) then
				bar(model, "DomeRing", point(a, latitude), point(b, latitude), 0.4, FRAME, Enum.Material.Metal)
			end
		end
	end
	-- Meridian ribs, from the base (or above the door) up to the top ring.
	for k = 0, ribs - 1 do
		local azimuth = (k / ribs) * math.pi * 2
		local nearDoor = math.abs(math.sin(azimuth / 2)) < 0.12
		local first = if nearDoor then 3 else 0
		for step = first, 7 do
			local l0, l1 = math.rad(step * 10.5), math.rad((step + 1) * 10.5)
			bar(model, "DomeRib", point(azimuth, l0), point(azimuth, l1), 0.45, FRAME, Enum.Material.Metal)
		end
	end
	disc(model, "DomeCap", math.cos(math.rad(84)) * radius + 1.2, 0.8, at(0, base + radius - 0.6, 0), FRAME, Enum.Material.Metal)
	return base + 0.2
end

-- A walk-through glass tube corridor from a to b: a floor, a glass tube over it, metal hoops
-- and a glowing strip along the top.
local function tube(parent: Instance, a: Vector3, b: Vector3, rng: Random)
	local model = Instance.new("Model")
	model.Name = "GlassCorridor"
	model.Parent = parent
	WorldKit.path(model, a, b, 8, rng)
	local length = ((b - a) * Vector3.new(1, 0, 1)).Magnitude
	local look = CFrame.lookAt(Vector3.new((a.X + b.X) / 2, 3, (a.Z + b.Z) / 2), Vector3.new(b.X, 3, b.Z))
	prop({ Name = "CorridorGlass", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, 12, 12), CFrame = look * CFrame.Angles(0, math.rad(90), 0), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.82, CastShadow = false, Parent = model })
	prop({ Name = "CorridorGlow", Size = Vector3.new(0.4, 0.3, length), CFrame = look * CFrame.new(0, 6.05, 0), Color = GLOW, Material = Enum.Material.Neon, Parent = model })
	for d = -length / 2 + 3, length / 2 - 3, 8 do
		local hoop = look * CFrame.new(0, 0, d)
		local previous
		for k = 0, 8 do
			local angle = math.pi * k / 8
			local point = (hoop * CFrame.new(math.cos(angle) * 6.2, math.sin(angle) * 6.2, 0)).Position
			if previous then
				bar(model, "CorridorHoop", previous, point, 0.5, FRAME, Enum.Material.Metal)
			end
			previous = point
		end
	end
end

-- A counter with a sign over it, like a market stand, under a dome. `frame` faces its +Z
-- (customers' side) towards the players. Returns the counter, with a prompt on it.
local function counter(parent: Instance, name: string, frame: CFrame, color: Color3, title: string, kind: string, action: string): BasePart
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local top = part({ Name = "Counter", Size = Vector3.new(12, 3.6, 4.4), CFrame = frame * CFrame.new(0, 1.8, 0), Color = Color3.fromRGB(226, 234, 238), Material = Enum.Material.SmoothPlastic, Parent = model })
	prop({ Name = "CounterGlow", Size = Vector3.new(12.1, 0.3, 4.5), CFrame = frame * CFrame.new(0, 3.5, 0), Color = color, Material = Enum.Material.Neon, Parent = model })
	for _, x in { -5.5, 5.5 } do
		part({ Name = "SignPost", Size = Vector3.new(0.6, 9, 0.6), CFrame = frame * CFrame.new(x, 4.5, -2), Color = FRAME, Material = Enum.Material.Metal, Parent = model })
	end
	local sign = part({ Name = "Sign", Size = Vector3.new(12, 2.6, 0.4), CFrame = frame * CFrame.new(0, 9.6, -2), Color = color, CanCollide = false, Parent = model })
	surfaceLabel(sign, Enum.NormalId.Back, title, Color3.new(1, 1, 1))
	prompt(top, kind, action, title, 12).Name = "StandPrompt"
	model.PrimaryPart = top
	return top
end

-- A building's name over its door, facing the plaza.
local function doorSign(parent: Instance, frame: CFrame, z: number, height: number, text: string, color: Color3)
	local sign = part({ Name = "BuildingSign", Size = Vector3.new(#text * 1.15 + 4, 3, 0.5), CFrame = frame * CFrame.new(0, height, z), Color = Color3.fromRGB(26, 62, 92), CanCollide = false, Parent = parent })
	surfaceLabel(sign, Enum.NormalId.Front, text, color)
end

-- The glowing coral on top of the Lab: a trunk forking three times into neon branches.
local function coralEmblem(parent: Instance, base: Vector3, rng: Random)
	local colors = { Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 170, 90), Color3.fromRGB(120, 240, 230) }
	local function branch(from: CFrame, length: number, thick: number, depth: number)
		local tip = from * CFrame.new(0, length, 0)
		bar(parent, "EmblemBranch", from.Position, tip.Position, thick, colors[depth % 3 + 1], Enum.Material.Neon)
		if depth == 0 then
			prop({ Name = "EmblemTip", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Position = tip.Position, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = parent })
			return
		end
		for k = 1, 3 do
			local spin = (k / 3) * math.pi * 2 + depth
			branch(tip * CFrame.Angles(0, spin, 0) * CFrame.Angles(0.55 + rng:NextNumber(-0.1, 0.1), 0, 0), length * 0.7, thick * 0.7, depth - 1)
		end
	end
	disc(parent, "EmblemBase", 3, 1, base + Vector3.new(0, 0.5, 0), FRAME, Enum.Material.Metal)
	branch(CFrame.new(base + Vector3.new(0, 1, 0)), 6, 1.4, 3)
	local glow = prop({ Name = "EmblemLight", Size = Vector3.new(1, 1, 1), Position = base + Vector3.new(0, 8, 0), Transparency = 1, Parent = parent })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 190)
	light.Range = 40
	light.Brightness = 2
	light.Parent = glow
end

local function buildLab(root: Instance, rng: Random): BasePart
	local model = Instance.new("Model")
	model.Name = "ResearchLaboratory"
	model.Parent = root
	local R = LAGOON.labRadius
	local frame = doorFrame(LAGOON.research)
	local floor = geodome(model, frame, R, 20)
	local function at(x: number, y: number, z: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end

	-- The research tower in the middle: stacked white drums with glowing windows, a spire.
	local y = floor
	for tier, size in { { 8, 9 }, { 6, 8 }, { 4.2, 6 } } do
		local radius, height = size[1], size[2]
		disc(model, "Tower", radius, height, at(0, y + height / 2, 6), Color3.fromRGB(236, 240, 242), Enum.Material.SmoothPlastic)
		disc(model, "TowerWindows", radius + 0.05, 1.2, at(0, y + height * 0.6, 6), WARM, Enum.Material.Neon)
		y += height
		if tier == 3 then
			bar(model, "Spire", at(0, y, 6), at(0, y + 6, 6), 0.6, FRAME, Enum.Material.Metal)
			prop({ Name = "SpireTip", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Position = at(0, y + 6.4, 6), Color = GLOW, Material = Enum.Material.Neon, Parent = model })
		end
	end
	local warm = prop({ Name = "LabLight", Size = Vector3.new(1, 1, 1), Position = at(0, 14, 0), Transparency = 1, Parent = model })
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 45
	light.Brightness = 1.4
	light.Parent = warm

	-- Little lab buildings round the tower, and garden beds of glowing coral between them.
	for k, azimuth in { 60, 120, 240, 300 } do
		local a = math.rad(azimuth)
		local pos = at(math.sin(a) * 22, floor, -math.cos(a) * 22 + 2)
		local face = CFrame.lookAt(pos, at(0, floor, 6))
		part({ Name = "LabPod", Size = Vector3.new(8, 7 + k % 2 * 3, 7), CFrame = face * CFrame.new(0, (7 + k % 2 * 3) / 2, 0), Color = Color3.fromRGB(232, 236, 238), Material = Enum.Material.SmoothPlastic, Parent = model })
		prop({ Name = "LabPodWindows", Size = Vector3.new(6, 1.2, 7.1), CFrame = face * CFrame.new(0, 4.5, 0), Color = WARM, Material = Enum.Material.Neon, Parent = model })
	end
	for _, azimuth in { 30, 90, 150, 210, 270, 330 } do
		local a = math.rad(azimuth)
		local bed = at(math.sin(a) * 28, floor, -math.cos(a) * 28)
		disc(model, "GardenBed", 4, 1.2, bed + Vector3.new(0, 0.6, 0), C.METAL_DARK, Enum.Material.Metal)
		disc(model, "GardenSoil", 3.6, 1.3, bed + Vector3.new(0, 0.65, 0), C.REEF_SAND, Enum.Material.Sand)
		WorldKit.bigCoral(model, bed + Vector3.new(0, 1.3, 0), rng, 1.3)
		seaGrass(model, bed + Vector3.new(1.5, 1.3, 1), rng, 1.2)
	end

	-- The counter, just inside the door, with a reef-health hologram behind it.
	local deskFrame = frame * CFrame.new(0, floor, -(R - 11)) * FACE_PLAYERS
	local desk = counter(model, "LabCounter", deskFrame, Color3.fromRGB(80, 170, 200), "Research Lab", "Lab", "Research")
	prop({ Name = "HealthHologram", Size = Vector3.new(10, 6, 0.2), CFrame = deskFrame * CFrame.new(0, 7.5, -4.5), Color = GLOW, Material = Enum.Material.Neon, Transparency = 0.7, Parent = model })
	for k = 1, 4 do
		prop({ Name = "HologramBar", Size = Vector3.new(1.2, 1 + k * 0.9, 0.25), CFrame = deskFrame * CFrame.new(-3.6 + k * 1.6, 5 + (1 + k * 0.9) / 2, -4.4), Color = Color3.fromRGB(150, 255, 190), Material = Enum.Material.Neon, Transparency = 0.25, Parent = model })
	end

	-- The door: a short glowing archway, and the glowing coral on top of the dome.
	for i = 0, 8 do
		local a = math.pi * i / 8
		part({ Name = "DoorArch", Size = Vector3.new(1.4, 2.2, 3), CFrame = frame * CFrame.new(math.cos(a) * 5, floor + 4.5 + math.sin(a) * 5, -R) * CFrame.Angles(0, 0, a), Color = FRAME, Material = Enum.Material.Metal, Parent = model })
	end
	for _, x in { -5, 5 } do
		part({ Name = "DoorPost", Size = Vector3.new(1.4, 4.5, 3), CFrame = frame * CFrame.new(x, floor + 2.25, -R), Color = FRAME, Material = Enum.Material.Metal, Parent = model })
	end
	doorSign(model, frame, -R - 1.2, floor + 13.5, "RESEARCH LABORATORY", Color3.fromRGB(180, 245, 255))
	coralEmblem(model, at(0, 1.4 + R - 0.2, 0), rng)

	-- A robot arm and a parked submarine outside, as in the concept art.
	local arm = frame * CFrame.new(R + 4, 0, -6)
	disc(model, "ArmBase", 2.2, 1.6, (arm * CFrame.new(0, 0.8, 0)).Position, C.METAL_DARK, Enum.Material.Metal)
	local elbow = (arm * CFrame.new(0, 9, -3)).Position
	local hand = (arm * CFrame.new(0, 6, -9)).Position
	bar(model, "ArmUpper", (arm * CFrame.new(0, 1.6, 0)).Position, elbow, 1.2, FRAME, Enum.Material.Metal)
	bar(model, "ArmLower", elbow, hand, 0.9, FRAME, Enum.Material.Metal)
	prop({ Name = "ArmJoint", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Position = elbow, Color = Color3.fromRGB(255, 196, 64), Material = Enum.Material.Metal, Parent = model })
	for _, side in { -1, 1 } do
		bar(model, "ArmClaw", hand, hand + (arm.RightVector * side * 0.9) + Vector3.new(0, -1.6, 0) - arm.LookVector * 0.6, 0.35, FRAME, Enum.Material.Metal)
	end
	return desk
end

local function buildAquarium(root: Instance, rng: Random): BasePart
	local model = Instance.new("Model")
	model.Name = "Aquarium"
	model.Parent = root
	local R = 25
	local frame = doorFrame(LAGOON.aquarium)
	local floor = geodome(model, frame, R, 14)
	local function at(x: number, y: number, z: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end

	-- Display tanks round the back of the hall, facing the middle. Each player sees them
	-- filled with their own discoveries (AquariumDisplay, on the client).
	local tanks = { { 115, "fish" }, { 155, "coral" }, { 180, "creatures" }, { 205, "coral" }, { 245, "fish" } }
	for slot, info in tanks do
		local a = math.rad(info[1])
		local pos = at(math.sin(a) * 17, floor, -math.cos(a) * 17)
		local face = CFrame.lookAt(pos, at(0, floor, 0))
		part({ Name = "TankBase", Size = Vector3.new(10, 1.4, 5), CFrame = face * CFrame.new(0, 0.7, 0), Color = C.METAL_DARK, Material = Enum.Material.Metal, Parent = model })
		local water = prop({ Name = "TankWater", Size = Vector3.new(9.6, 8, 4.6), CFrame = face * CFrame.new(0, 5.4, 0), Color = Color3.fromRGB(110, 200, 235), Material = Enum.Material.Glass, Transparency = 0.7, CastShadow = false, Parent = model })
		water:SetAttribute("Kind", info[2])
		water:SetAttribute("Slot", slot)
		water:AddTag("AquariumTank")
		part({ Name = "TankLid", Size = Vector3.new(10, 0.6, 5), CFrame = face * CFrame.new(0, 9.7, 0), Color = FRAME, Material = Enum.Material.Metal, Parent = model })
		prop({ Name = "TankLight", Size = Vector3.new(9, 0.2, 4.2), CFrame = face * CFrame.new(0, 9.3, 0), Color = Color3.fromRGB(200, 245, 255), Material = Enum.Material.Neon, Parent = model })
		for _, x in { -4.9, 4.9 } do
			part({ Name = "TankFrame", Size = Vector3.new(0.4, 8.6, 5), CFrame = face * CFrame.new(x, 5.4, 0), Color = FRAME, Material = Enum.Material.Metal, Parent = model })
		end
	end

	-- The Reef Index: a hologram globe in the middle of the hall.
	local pedestal = part({ Name = "IndexPedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2.8, 2.8), CFrame = CFrame.new(at(0, floor + 1.5, 2)) * UPRIGHT, Color = FRAME, Material = Enum.Material.Metal, Parent = model })
	local globe = prop({ Name = "IndexGlobe", Shape = Enum.PartType.Ball, Size = Vector3.new(3.6, 3.6, 3.6), Position = at(0, floor + 5, 2), Color = GLOW, Material = Enum.Material.Neon, Transparency = 0.45, CastShadow = false, Parent = model })
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 26
	light.Brightness = 1.1
	light.Parent = globe
	prompt(pedestal, "Index", "Open Reef Index", "Aquarium", 10)

	-- The Pet Hatchery: a counter by the door with three glowing incubators behind it.
	local hatchFrame = frame * CFrame.new(-10, floor, -(R - 9)) * CFrame.Angles(0, math.rad(200), 0)
	local hatchery = counter(model, "PetHatchery", hatchFrame, Color3.fromRGB(170, 110, 230), "Pet Hatchery", "Hatchery", "Hatch eggs")
	for k, color in { Color3.fromRGB(255, 170, 210), Color3.fromRGB(255, 215, 110), Color3.fromRGB(120, 230, 210) } do
		local pos = (hatchFrame * CFrame.new((k - 2) * 3.6, 0, -4)).Position
		disc(model, "IncubatorBase", 1.5, 0.6, pos + Vector3.new(0, 0.3, 0), C.METAL_DARK, Enum.Material.Metal)
		local glass = disc(model, "IncubatorGlass", 1.3, 3, pos + Vector3.new(0, 2.1, 0), Color3.fromRGB(220, 240, 255), Enum.Material.Glass)
		glass.Transparency = 0.6
		glass.CanCollide = false
		prop({ Name = "Egg", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), Position = pos + Vector3.new(0, 1.8, 0), Color = color, Material = Enum.Material.Neon, Transparency = 0.1, Parent = model })
	end
	doorSign(model, frame, -R - 1.2, floor + 11, "AQUARIUM", Color3.fromRGB(180, 245, 255))
	return hatchery
end

local function buildMarket(root: Instance, rng: Random): (BasePart, BasePart, BasePart)
	local model = Instance.new("Model")
	model.Name = "CoralMarket"
	model.Parent = root
	local R = 25
	local frame = doorFrame(LAGOON.coralShop)
	local floor = geodome(model, frame, R, 12)
	local function stallFrame(azimuth: number, distance: number): CFrame
		local a = math.rad(azimuth)
		local pos = frame:PointToWorldSpace(Vector3.new(math.sin(a) * distance, floor, -math.cos(a) * distance))
		local toward = frame:PointToWorldSpace(Vector3.new(0, floor, -6))
		return WorldKit.facing(pos, toward)
	end
	local seeds = counter(model, "SeedCounter", stallFrame(140, 13), Color3.fromRGB(70, 170, 110), "Seeds", "SeedShop", "Browse seeds")
	local sell = counter(model, "SellCounter", stallFrame(180, 13), Color3.fromRGB(220, 140, 60), "Sell Coral", "Sell", "Sell all coral")
	local decor = counter(model, "DecorCounter", stallFrame(220, 13), Color3.fromRGB(150, 100, 220), "Decor & Fences", "Supplies", "Browse decorations")
	local decorPrompt = decor:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	decorPrompt:SetAttribute("Mode", "market")
	local seedPrompt = seeds:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	seedPrompt.ObjectText = "Coral Market"
	ShopkeeperVisuals.build("SeedShop", seeds.CFrame * CFrame.new(0, -seeds.Size.Y / 2, -seeds.Size.Z / 2 - 1.1) * FACE_PLAYERS).Parent = model
	ShopkeeperVisuals.build("Sell", sell.CFrame * CFrame.new(4.2, sell.Size.Y / 2, 0) * FACE_PLAYERS).Parent = model

	-- The rare species case: special coral under glass on a plinth in the middle.
	local case = frame:PointToWorldSpace(Vector3.new(0, floor, 2))
	disc(model, "RareCasePlinth", 4.4, 1.6, case + Vector3.new(0, 0.8, 0), C.METAL_DARK, Enum.Material.Metal)
	for k, seedId in { "star", "clam", "anemone" } do
		local a = k * math.pi * 2 / 3
		local coral = CoralVisuals.build(seedId, "None", CFrame.new(case + Vector3.new(math.cos(a) * 2, 1.6, math.sin(a) * 2)))
		coral:ScaleTo(0.7)
		for _, d in coral:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		coral.Parent = model
	end
	local glass = disc(model, "RareCaseGlass", 4.2, 6, case + Vector3.new(0, 4.6, 0), Color3.fromRGB(220, 240, 255), Enum.Material.Glass)
	glass.Transparency = 0.7
	glass.CanCollide = false
	local label = part({ Name = "RareLabel", Size = Vector3.new(7, 1.4, 0.3), CFrame = CFrame.lookAt(case + Vector3.new(0, 8.6, 0), Vector3.new(CENTER.X, 8.6, CENTER.Z)), Color = Color3.fromRGB(26, 62, 92), CanCollide = false, Parent = model })
	surfaceLabel(label, Enum.NormalId.Front, "RARE SPECIES", Color3.fromRGB(255, 220, 120))
	doorSign(model, frame, -R - 1.2, floor + 11, "CORAL MARKET", Color3.fromRGB(255, 220, 120))
	for _, side in { -1, 1 } do
		WorldKit.tableCoral(model, frame:PointToWorldSpace(Vector3.new(side * (R + 4), 0, -4)), rng)
		WorldKit.tubeCoral(model, frame:PointToWorldSpace(Vector3.new(side * (R + 3), 0, 6)), rng)
	end
	return seeds, sell, decor
end

local function buildEquipment(root: Instance, rng: Random): BasePart
	local model = Instance.new("Model")
	model.Name = "EquipmentStation"
	model.Parent = root
	local R = 22
	local frame = doorFrame(LAGOON.upgrade)
	local floor = geodome(model, frame, R, 12)
	local deskFrame = frame * CFrame.new(0, floor, 2) * FACE_PLAYERS
	local desk = counter(model, "EquipmentCounter", deskFrame, Color3.fromRGB(46, 150, 170), "Equipment", "Supplies", "Upgrade gear")
	local deskPrompt = desk:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	deskPrompt:SetAttribute("Mode", "equipment")
	deskPrompt.ObjectText = "Equipment Station"
	ShopkeeperVisuals.build("Supplies", desk.CFrame * CFrame.new(-4, desk.Size.Y / 2, 0) * FACE_PLAYERS).Parent = model

	-- Racks of diving gear along the back: suits with brass helmets, oxygen tanks and fins.
	local brass = Color3.fromRGB(214, 170, 80)
	for k = -2, 2 do
		local spot = deskFrame * CFrame.new(k * 3.6, 0, -8)
		if k % 2 == 0 then
			part({ Name = "DiveSuit", Size = Vector3.new(2, 4.2, 1.2), CFrame = spot * CFrame.new(0, 2.6, 0), Color = Color3.fromRGB(190, 160, 96), Material = Enum.Material.Fabric, Parent = model })
			part({ Name = "DiveHelmet", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = spot * CFrame.new(0, 5.8, 0), Color = brass, Material = Enum.Material.Metal, Parent = model })
		else
			for _, x in { -0.6, 0.6 } do
				part({ Name = "OxygenTank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.4, 1.1, 1.1), CFrame = spot * CFrame.new(x, 2.4, 0) * UPRIGHT, Color = Color3.fromRGB(255, 196, 64), Material = Enum.Material.Metal, Parent = model })
			end
			part({ Name = "Fin", Size = Vector3.new(1.4, 0.2, 2.4), CFrame = spot * CFrame.new(0, 5.2, 0) * CFrame.Angles(math.rad(70), 0, 0), Color = Color3.fromRGB(60, 120, 220), Material = Enum.Material.SmoothPlastic, Parent = model })
		end
	end
	doorSign(model, frame, -R - 1.2, floor + 10, "EQUIPMENT STATION", Color3.fromRGB(180, 245, 255))
	WorldKit.boulder(model, frame:PointToWorldSpace(Vector3.new(R + 5, 0, 4)), 6, rng)
	return desk
end

function Hub.build(root: Instance, paths: Instance, rng: Random): HubParts
	local labStand = buildLab(root, rng)
	local hatcheryStand = buildAquarium(root, rng)
	local shopStand, sellStand, marketDecorStand = buildMarket(root, rng)
	local suppliesStand = buildEquipment(root, rng)
	-- A glass corridor from the plaza's edge to each building's door.
	local corridors = Instance.new("Model")
	corridors.Name = "GlassCorridors"
	corridors.Parent = paths
	for _, building in { { LAGOON.research, LAGOON.labRadius }, { LAGOON.aquarium, 25 }, { LAGOON.coralShop, 25 }, { LAGOON.upgrade, 22 } } do
		local position, radius = building[1], building[2]
		local direction = ((position - CENTER) * Vector3.new(1, 0, 1)).Unit
		tube(corridors, CENTER + direction * (LAGOON.plazaRadius + 1), position - direction * (radius + 1.5), rng)
	end
	return {
		labStand = labStand,
		shopStand = shopStand,
		sellStand = sellStand,
		marketDecorStand = marketDecorStand,
		suppliesStand = suppliesStand,
		hatcheryStand = hatcheryStand,
	}
end

return Hub
