--!nonstrict
-- Teleporting between the shops, your reef and the Sunken Ruins: the HUD's Shop, Home and
-- Ruins buttons (the Teleport remote, which carries only "shops", "home", "ruins" or "abyss";
-- the Journal's Go to Abyss button sends "abyss", allowed once the Abyss is unlocked) and the
-- whirlpool pads' prompts. The server picks where you land. Both ends get a burst of bubbles
-- everyone can see.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local RuinsConfig = require(ReplicatedStorage.Shared.RuinsConfig)
local AbyssConfig = require(ReplicatedStorage.Shared.AbyssConfig)
local KelpConfig = require(ReplicatedStorage.Shared.KelpConfig)
local Abyss = require(script.Parent.Abyss)
local World = require(script.Parent.World)
local Plots = require(script.Parent.Plots)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Teleport = {}

local SETTINGS = ReefConfig.Teleport
local GLOW = Color3.fromRGB(120, 230, 255)
local RING_TWEEN = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local lastTeleport: { [Player]: number } = {}
local shopsArrival: CFrame
-- The whirlpool at the Sunken Ruins entrance, facing into the ruins.
local ruinsArrival = CFrame.lookAt(RuinsConfig.Places.pad + Vector3.new(0, 3, 0), RuinsConfig.at(0, 3, 14))
-- Just inside the Kelp Forest's entrance, facing up the trail.
local kelpArrival = CFrame.lookAt(KelpConfig.entrance + Vector3.new(0, 3, -10), KelpConfig.Trail[2] + Vector3.new(0, 3, 0))
-- The whirlpool on the Abyss floor, facing the Crystal Spire. Only for players who unlocked it.
local abyssArrival = CFrame.lookAt(AbyssConfig.Places.pad + Vector3.new(0, 3, 0), AbyssConfig.Places.spire + Vector3.new(0, 3, 0))

-- A whirlpool where someone leaves or lands: a glowing ring spreading out over the seabed
-- and a burst of swirling bubbles.
local function whirlpool(ground: Vector3)
	local ring = Instance.new("Part")
	ring.Name = "TeleportRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = GLOW
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))

	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(GLOW, Color3.new(1, 1, 1))
	bubbles.LightEmission = 0.7
	bubbles.Size = NumberSequence.new(0.6, 1.4)
	bubbles.Transparency = NumberSequence.new(0, 1)
	bubbles.Lifetime = NumberRange.new(0.8, 1.4)
	bubbles.Speed = NumberRange.new(8, 14)
	bubbles.RotSpeed = NumberRange.new(-200, 200)
	bubbles.SpreadAngle = Vector2.new(30, 30)
	bubbles.EmissionDirection = Enum.NormalId.Right -- up, since the cylinder lies on its side
	bubbles.Rate = 0
	bubbles.Parent = ring

	ring.Parent = Workspace
	bubbles:Emit(60)
	TweenService:Create(ring, RING_TWEEN, { Size = Vector3.new(0.2, 14, 14), Transparency = 1 }):Play()
	Debris:AddItem(ring, 1.6)
end

local function teleport(player: Player, destination: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if destination == "abyss" and not Abyss.isUnlocked(player) then
		Plots.notify(player, Abyss.lockedText(player), "bad")
		return
	end
	local target = if destination == "home" then Plots.homeFor(player) elseif destination == "shops" then shopsArrival elseif destination == "ruins" then ruinsArrival elseif destination == "abyss" then abyssArrival elseif destination == "kelp" then kelpArrival else nil
	if not target then
		return
	end
	local waited = os.clock() - (lastTeleport[player] or -math.huge)
	if waited < SETTINGS.cooldown then
		Plots.notify(player, `The whirlpool is still spinning up ({math.ceil(SETTINGS.cooldown - waited)}s).`)
		return
	end
	lastTeleport[player] = os.clock()
	whirlpool(root.Position - Vector3.new(0, 3, 0))
	character:PivotTo(target)
	whirlpool(target.Position - Vector3.new(0, 3, 0))
	Remotes.Teleported:FireClient(player)
end

function Teleport.start(worldParts: World.WorldParts)
	local pad = worldParts.shopsPad.Position
	-- Land on the pad beside the Coral Market, facing its counters.
	local shop = (worldParts.shopStand.Position + worldParts.sellStand.Position) / 2
	shopsArrival = CFrame.lookAt(pad + Vector3.new(0, 3, 0), Vector3.new(shop.X, pad.Y + 3, shop.Z))

	Remotes.Teleport.OnServerEvent:Connect(function(player, destination)
		if RateLimit.consume(player) and (destination == "home" or destination == "shops" or destination == "ruins" or destination == "abyss") then
			teleport(player, destination)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local kind = prompt:GetAttribute("Kind")
		if kind == "TeleportHome" then
			teleport(player, "home")
		elseif kind == "TeleportRuins" then
			teleport(player, "ruins")
		elseif kind == "TeleportShops" then
			teleport(player, "shops")
		elseif kind == "TeleportKelp" then
			teleport(player, "kelp") -- the whirlpool at the north edge of the plaza
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)
end

return Teleport
