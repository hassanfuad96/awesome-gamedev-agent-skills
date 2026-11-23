--!nonstrict
-- Treasure Storm, one of the sea events: chests sink from the surface onto the plaza and the
-- reefs. Anyone can open one (first come, first served) for shells or rare seeds; the server
-- picks the reward and checks the opener is beside the chest. Unopened chests wash away.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local RateLimit = require(script.Parent.RateLimit)

local TreasureStorm = {}

local SETTINGS = ReefConfig.Events.treasure
local OPEN_DISTANCE = 14 -- studs; a little more than the prompt's reach
local WOOD = Color3.fromRGB(125, 82, 45)
local GOLD = Color3.fromRGB(255, 200, 70)

local rng = Random.new()
local folder: Folder
local landingParams = RaycastParams.new()
local open = 0 -- chests on the seabed right now

-- Where chests may land: mostly over the Main Reef (its road, the reefs and the gardens
-- between the ridges), sometimes in the lagoon round the plaza. Never inside a building.
local LAGOON = ReefConfig.Lagoon
local ZONE = ReefConfig.MainReef
local BUILDINGS = {
	{ LAGOON.research, LAGOON.labRadius + 6 },
	{ LAGOON.aquarium, 31 },
	{ LAGOON.upgrade, 28 },
	{ LAGOON.coralShop, 31 },
	{ LAGOON.oceanGate, 28 },
	{ ZONE.grandRock, 40 },
}

local function clearOfBuildings(x: number, z: number): boolean
	for _, building in BUILDINGS do
		local center, radius = building[1], building[2]
		if (x - center.X) ^ 2 + (z - center.Z) ^ 2 < radius * radius then
			return false
		end
	end
	return true
end

local function landingPoint(): Vector3?
	local x, z
	for _ = 1, 10 do
		if rng:NextNumber() < 0.75 then
			x = rng:NextNumber(ZONE.roadTo + 40, ZONE.roadFrom - 40)
			z = rng:NextNumber(-ZONE.ridgeZ + 25, ZONE.ridgeZ - 25)
		else
			-- Uniform over the lagoon's disc: the square root spreads points out to the rim.
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = math.sqrt(rng:NextNumber()) * (LAGOON.rimRadius - 15)
			x, z = LAGOON.center.X + math.cos(angle) * distance, LAGOON.center.Z + math.sin(angle) * distance
		end
		if clearOfBuildings(x, z) then
			break
		end
	end
	local hit = Workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -100, 0), landingParams)
	return hit and hit.Position
end

local function giveReward(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if rng:NextNumber() < SETTINGS.seedChance then
		local seedId = EconomyMath.pickWeighted(SETTINGS.seeds, rng:NextNumber())
		local entry
		for _, candidate in SETTINGS.seeds do
			if candidate.id == seedId then
				entry = candidate
			end
		end
		local seed = ReefConfig.Seeds[seedId]
		local owned = profile.data.seeds[seedId] or 0
		local count = if entry and seed then math.min(entry.count, ReefConfig.MAX_SEEDS_PER_TYPE - owned) else 0
		if count > 0 then
			profile.data.seeds[seedId] = owned + count
			Plots.notify(player, `Treasure! {count} {seed.name} seed{if count > 1 then "s" else ""}!`, "rare")
			PlayerData.sync(player)
			return
		end
	end
	local shells = rng:NextInteger(SETTINGS.shells.min, SETTINGS.shells.max)
	PlayerData.addShells(player, shells)
	Plots.notify(player, `Treasure! +{EconomyMath.formatNumber(shells)} shells`, "good")
	PlayerData.sync(player)
end

local function buildChest(at: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "TreasureChest"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = at * offset
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false -- never in the way of planting clicks
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	-- The box is anchored and tweened; the rest is welded to it and follows.
	local box = piece("Box", Vector3.new(3, 1.6, 2), CFrame.identity, WOOD, Enum.Material.Wood)
	box.Anchored = true
	local others = {
		piece("Lid", Vector3.new(3.1, 0.7, 2.1), CFrame.new(0, 1.15, 0), WOOD:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Wood),
		piece("Band", Vector3.new(0.25, 2.4, 2.15), CFrame.new(-1.05, 0.35, 0), GOLD, Enum.Material.Foil),
		piece("Band", Vector3.new(0.25, 2.4, 2.15), CFrame.new(1.05, 0.35, 0), GOLD, Enum.Material.Foil),
		piece("Lock", Vector3.new(0.5, 0.55, 0.15), CFrame.new(0, 0.8, -1.08), GOLD, Enum.Material.Foil),
	}
	for _, p in others do
		p.Anchored = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = box
		weld.Part1 = p
		weld.Parent = p
	end
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Range = 10
	glow.Brightness = 1.5
	glow.Parent = box
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(GOLD)
	sparkle.Rate = 5
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.Size = NumberSequence.new(0.3, 0)
	sparkle.LightEmission = 1
	sparkle.Parent = box
	model.PrimaryPart = box
	return model, box
end

-- Drops one chest, unless the seabed already holds the most allowed. Events calls this
-- every SETTINGS.every seconds while a storm lasts.
function TreasureStorm.dropChest()
	if open >= SETTINGS.maxChests then
		return
	end
	local ground = landingPoint()
	if not ground then
		return
	end
	open += 1
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local rest = CFrame.new(ground + Vector3.new(0, 0.8, 0)) * yaw
	local model, box = buildChest(CFrame.new(ground.X, 70, ground.Z) * yaw)
	model.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Treasure Chest"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- until it lands
	prompt.Parent = box

	local gone = false
	local function remove()
		if gone then
			return
		end
		gone = true
		open -= 1
		model:Destroy()
	end

	prompt.Triggered:Connect(function(player)
		if gone or not RateLimit.consume(player) then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - box.Position).Magnitude > OPEN_DISTANCE then
			return
		end
		prompt.Enabled = false
		giveReward(player)
		remove()
	end)

	local fall = TweenService:Create(box, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = rest })
	fall.Completed:Connect(function()
		if not gone then
			prompt.Enabled = true
		end
	end)
	fall:Play()
	task.delay(SETTINGS.lifetime, remove)
end

function TreasureStorm.start()
	folder = Instance.new("Folder")
	folder.Name = "TreasureChests"
	folder.Parent = Workspace
	-- Land on the seabed or a reef mound, not on stands, signs or other chests.
	landingParams.FilterType = Enum.RaycastFilterType.Include
	local reef = Workspace:WaitForChild("Reef")
	landingParams.FilterDescendantsInstances = { reef:WaitForChild("Seabed"), reef:WaitForChild("Plots") }
end

return TreasureStorm
