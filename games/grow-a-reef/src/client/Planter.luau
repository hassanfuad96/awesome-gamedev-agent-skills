--!nonstrict
-- Free placement. With a seed selected, a ghost ring follows the mouse over your reef bed:
-- green where the coral fits, red where it doesn't (same rules as the server, from
-- ReefConfig.plantProblem). Clicking or tapping a bed sends only the point (PlantAt); the
-- server checks everything again and says why when it refuses.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Planter = {}

local player = Players.LocalPlayer
local selected: string? = nil
local unlocked = ReefConfig.STARTING_SLOTS

local ghost = Instance.new("Model")
ghost.Name = "PlantPreview"

local function ghostPart(name: string, shape: Enum.PartType, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Transparency = 1
	p.Parent = ghost
	return p
end

-- The ring is the coral's footprint: two rings may touch but not overlap.
local ring = ghostPart("Ring", Enum.PartType.Cylinder, Vector3.new(0.15, ReefConfig.PLANT_SPACING, ReefConfig.PLANT_SPACING))
local sprout = ghostPart("Sprout", Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2))

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Coral and fish are queryable, so a ray that reaches a bed passed over open bed.
local function bedUnder(origin: Vector3, direction: Vector3): (BasePart?, Vector3?)
	rayParams.FilterDescendantsInstances = { ghost, player.Character }
	local result = Workspace:Raycast(origin, direction * 500, rayParams)
	local hit = result and result.Instance
	if hit and hit.Name == "Bed" and hit.Parent and hit.Parent:GetAttribute("PlotIndex") then
		return hit :: BasePart, result.Position
	end
	return nil, nil
end

local function plantsOn(plot: Instance, center: Vector3): { { x: number, z: number } }
	local result = {}
	for _, coral in CollectionService:GetTagged(ReefConfig.CORAL_TAG) do
		if coral.Parent == plot then
			local position = coral:GetPivot().Position
			table.insert(result, { x = position.X - center.X, z = position.Z - center.Z })
		end
	end
	return result
end

local function showGhost(visible: boolean)
	ring.Transparency = if visible then 0.45 else 1
	sprout.Transparency = if visible then 0.3 else 1
end

local function updateGhost()
	-- Touch players have no hover, so they just tap; the server explains any refusal.
	local lastInput = UserInputService:GetLastInputType()
	if not selected or lastInput == Enum.UserInputType.Touch or not UserInputService.MouseEnabled then
		showGhost(false)
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = Workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
	local bed, point = bedUnder(ray.Origin, ray.Direction)
	if not bed or bed.Parent:GetAttribute("OwnerUserId") ~= player.UserId then
		showGhost(false)
		return
	end
	local center = bed.Position
	local x, z = point.X - center.X, point.Z - center.Z
	local fits = ReefConfig.plantProblem(x, z, unlocked, plantsOn(bed.Parent, center)) == nil
	local color = if fits then Ui.Colors.good else Ui.Colors.bad
	local base = Vector3.new(point.X, center.Y + bed.Size.X / 2 + 0.08, point.Z)
	ring.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = color
	local seed = ReefConfig.Seeds[selected]
	sprout.CFrame = CFrame.new(base + Vector3.new(0, 0.8, 0))
	sprout.Color = if fits and seed then seed.color else color
	showGhost(true)
end

function Planter.setData(data: any)
	selected = data.selected
	unlocked = data.unlocked
end

function Planter.start()
	ghost.Parent = Workspace.CurrentCamera -- local only, and never part of the shared world
	RunService.RenderStepped:Connect(updateGhost)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not selected then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local ray = Workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
		local _, point = bedUnder(ray.Origin, ray.Direction)
		if point then
			Remotes.PlantAt:FireServer(point)
		end
	end)
end

return Planter
