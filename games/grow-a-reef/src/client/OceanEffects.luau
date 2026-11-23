--!nonstrict
-- Underwater feel close to the player: specks of "marine snow" drifting around the camera,
-- and bubbles rising from every diver's head. Client-only and cosmetic.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OceanEffects = {}

local SPECK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function marineSnow()
	-- An invisible box that follows the camera and fills itself with slow, sinking specks.
	local box = Instance.new("Part")
	box.Name = "MarineSnow"
	box.Anchored = true
	box.CanCollide = false
	box.CanTouch = false
	box.CanQuery = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = Vector3.new(90, 40, 90)
	box.Parent = Workspace.CurrentCamera

	local snow = Instance.new("ParticleEmitter")
	snow.Texture = SPECK_TEXTURE
	snow.Shape = Enum.ParticleEmitterShape.Box
	snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	snow.Rate = 45
	snow.Lifetime = NumberRange.new(6, 10)
	snow.Speed = NumberRange.new(0.2, 0.8)
	snow.SpreadAngle = Vector2.new(180, 180)
	snow.Acceleration = Vector3.new(0, -0.15, 0)
	snow.Size = NumberSequence.new(0.18)
	snow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(0.8, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	snow.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	snow.LightEmission = 0.4
	snow.Parent = box

	RunService.RenderStepped:Connect(function()
		box.CFrame = CFrame.new(Workspace.CurrentCamera.CFrame.Position)
	end)
end

local function addBubbles(character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head or head:FindFirstChild("DiverBubbles") then
		return
	end
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "DiverBubbles"
	bubbles.Texture = SPECK_TEXTURE
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Rate = 1.5
	bubbles.Lifetime = NumberRange.new(2.5, 3.5)
	bubbles.Speed = NumberRange.new(3, 5)
	bubbles.SpreadAngle = Vector2.new(12, 12)
	bubbles.Acceleration = Vector3.new(0, 2, 0)
	bubbles.Size = NumberSequence.new(0.2, 0.45)
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.Color = ColorSequence.new(Color3.fromRGB(225, 245, 255))
	bubbles.Parent = head
end

function OceanEffects.start()
	marineSnow()
	local function watch(player: Player)
		player.CharacterAdded:Connect(addBubbles)
		if player.Character then
			task.spawn(addBubbles, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return OceanEffects
