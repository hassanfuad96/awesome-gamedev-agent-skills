--!nonstrict
-- Shells and pearls lying around the Main Reef (ReefConfig.Collectibles). A few of each are
-- out at once, on spots MainReef chose: shells on open seabed, pearls in the caves, the
-- grotto, on the bridges and on top of the Grand Reef Rock. Swim into one to pick it up;
-- the server checks you're really there, pays you, and puts a new one somewhere else after a
-- while. First come, first served.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local World = require(script.Parent.World)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Quests = require(script.Parent.Quests)

local Collectibles = {}

local SETTINGS = ReefConfig.Collectibles
local SHELL_COLORS = { Color3.fromRGB(255, 196, 170), Color3.fromRGB(250, 230, 190), Color3.fromRGB(255, 160, 180) }
local rng = Random.new()
local folder: Folder
local busy: { [Vector3]: boolean } = {} -- spots with something on them now

local function piece(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = model
	return p
end

-- A scallop shell: ribs fanned out from a hinge, lying tilted on the sand.
local function shellModel(at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "ShellPickup"
	local color = SHELL_COLORS[rng:NextInteger(1, #SHELL_COLORS)]
	local base = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(math.rad(-25), 0, 0)
	for i = -3, 3 do
		local rib = base * CFrame.Angles(0, math.rad(i * 15), 0) * CFrame.new(0, 0, -0.9)
		piece(model, "Rib", Vector3.new(0.5, 0.18, 1.9), rib, color:Lerp(Color3.new(1, 1, 1), (i % 2) * 0.2), Enum.Material.SmoothPlastic)
	end
	piece(model, "Hinge", Vector3.new(0.9, 0.3, 0.5), base, color:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.SmoothPlastic)
	return model
end

-- An open clam with a glowing pearl in it.
local function pearlModel(at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "PearlPickup"
	local base = CFrame.new(at - Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local shell = Color3.fromRGB(150, 120, 180)
	piece(model, "ClamBottom", Vector3.new(2.6, 0.5, 2.2), base, shell, Enum.Material.Marble)
	piece(model, "ClamTop", Vector3.new(2.6, 0.5, 2.2), base * CFrame.new(0, 1, -1) * CFrame.Angles(math.rad(-50), 0, 0), shell, Enum.Material.Marble)
	local pearl = piece(model, "Pearl", Vector3.new(1, 1, 1), base * CFrame.new(0, 0.75, 0.1), Color3.fromRGB(255, 250, 240), Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(230, 220, 255)
	light.Range = 10
	light.Brightness = 1.4
	light.Parent = pearl
	return model
end

-- Glints that make a pickup easy to spot from a distance.
local function sparkle(model: Model, at: Vector3, color: Color3): BasePart
	local zone = piece(model, "PickupZone", Vector3.new(6, 6, 6), CFrame.new(at + Vector3.new(0, 1, 0)), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	zone.Transparency = 1
	zone.CanTouch = true
	local glints = Instance.new("ParticleEmitter")
	glints.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glints.Color = ColorSequence.new(color)
	glints.LightEmission = 1
	glints.Size = NumberSequence.new(0.4, 0)
	glints.Lifetime = NumberRange.new(0.8, 1.4)
	glints.Rate = 4
	glints.Speed = NumberRange.new(1, 2)
	glints.SpreadAngle = Vector2.new(180, 180)
	glints.Parent = zone
	return zone
end

local spawnOne: (kind: string, spots: { Vector3 }) -> ()

local function respawnLater(kind: string, spots: { Vector3 })
	local delay = SETTINGS[kind].respawn
	task.delay(rng:NextNumber(delay[1], delay[2]), spawnOne, kind, spots)
end

spawnOne = function(kind: string, spots: { Vector3 })
	local free = {}
	for _, spot in spots do
		if not busy[spot] then
			table.insert(free, spot)
		end
	end
	if #free == 0 then
		respawnLater(kind, spots)
		return
	end
	local spot = free[rng:NextInteger(1, #free)]
	busy[spot] = true
	local isPearl = kind == "pearls"
	local model = if isPearl then pearlModel(spot) else shellModel(spot)
	local zone = sparkle(model, spot, if isPearl then Color3.fromRGB(240, 230, 255) else Color3.fromRGB(255, 230, 160))
	model.Parent = folder

	local taken = false
	zone.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if taken or not player or not root then
			return
		end
		-- The server's own check: the player really is beside it.
		if (root.Position - spot).Magnitude > SETTINGS.reach + 3 then
			return
		end
		local profile = PlayerData.get(player)
		if not profile then
			return
		end
		taken = true
		if isPearl then
			profile.data.pearls += 1
			Plots.notify(player, `Found a pearl! You have {profile.data.pearls}. Pearls unlock planters at the Research Laboratory.`, "rare")
		else
			local amount = rng:NextInteger(SETTINGS.shells.min, SETTINGS.shells.max)
			PlayerData.addShells(player, amount)
			Quests.progress(player, "earn", amount)
			Plots.notify(player, `Picked up a shell: +{EconomyMath.formatNumber(amount)} shells`, "good")
		end
		PlayerData.sync(player)
		-- A quick pop as it's picked up.
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child.Name ~= "PickupZone" then
				TweenService:Create(child, TweenInfo.new(0.3), { Transparency = 1, Size = child.Size * 1.4 }):Play()
			end
		end
		task.delay(0.35, model.Destroy, model)
		busy[spot] = nil
		respawnLater(kind, spots)
	end)
end

function Collectibles.start(worldParts: World.WorldParts)
	folder = Instance.new("Folder")
	folder.Name = "Collectibles"
	folder.Parent = workspace:FindFirstChild("Reef") or workspace
	local spots = worldParts.collectibleSpots
	for _ = 1, math.min(SETTINGS.shells.count, #spots.shells) do
		spawnOne("shells", spots.shells)
	end
	for _ = 1, math.min(SETTINGS.pearls.count, #spots.pearls) do
		spawnOne("pearls", spots.pearls)
	end
end

return Collectibles
