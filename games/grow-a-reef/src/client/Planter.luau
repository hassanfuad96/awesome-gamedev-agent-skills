--!nonstrict
-- Free placement. With a seed selected, a ghost ring follows the mouse over your reef bed:
-- green where the coral fits, red where it doesn't (same rules as the server, from
-- ReefConfig.plantProblem). Clicking or tapping a bed sends only the point (PlantAt); the
-- server checks everything again and says why when it refuses.
-- Placing a decoration (startPlacing, from the Upgrade Station window) works the same way over
-- your whole reef inside the fence, with ReefConfig.decorProblem and PlaceDecor.

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
local placing: string? = nil -- decoration item being placed
local decorStorage: { [string]: number } = {}
local placingChanged: ((string?) -> ())? = nil

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

-- Coral, decorations and fish are queryable, so a ray that reaches a bed passed over open
-- bed. Decorations also go on the mound round the bed ("Base").
local function groundUnder(origin: Vector3, direction: Vector3, mound: boolean): (BasePart?, Vector3?)
	rayParams.FilterDescendantsInstances = { ghost, player.Character }
	local result = Workspace:Raycast(origin, direction * 500, rayParams)
	local hit = result and result.Instance
	if hit and (hit.Name == "Bed" or (mound and hit.Name == "Base")) and hit.Parent and hit.Parent:GetAttribute("PlotIndex") then
		return hit :: BasePart, result.Position
	end
	return nil, nil
end

local function bedUnder(origin: Vector3, direction: Vector3): (BasePart?, Vector3?)
	return groundUnder(origin, direction, false)
end

-- Positions on a reef are offsets in its frame (ReefConfig.plotFrame), as the server saves.
local function plantsOn(plot: Instance, frame: CFrame): { { x: number, z: number } }
	local result = {}
	for _, coral in CollectionService:GetTagged(ReefConfig.CORAL_TAG) do
		if coral.Parent == plot then
			local x, z = ReefConfig.plotOffset(frame, coral:GetPivot().Position)
			table.insert(result, { x = x, z = z })
		end
	end
	return result
end

local function decorOn(plot: Instance, frame: CFrame): { ReefConfig.PlacedDecor }
	local result = {}
	for _, decor in CollectionService:GetTagged(ReefConfig.DECOR_TAG) do
		local item = decor:GetAttribute("DecorItem")
		if decor.Parent == plot and type(item) == "string" then
			local x, z = ReefConfig.plotOffset(frame, decor:GetPivot().Position)
			table.insert(result, { item = item, x = x, z = z })
		end
	end
	return result
end

-- The plot's frame: its centre on the seabed, turned so the gate is at local -Z.
local function plotFrame(plot: Instance): CFrame?
	local frame = plot:GetAttribute("PlotFrame")
	return if typeof(frame) == "CFrame" then frame else nil
end

local function showGhost(visible: boolean)
	ring.Transparency = if visible then 0.45 else 1
	sprout.Transparency = if visible then 0.3 else 1
end

local function updateGhost()
	-- Touch players have no hover, so they just tap; the server explains any refusal.
	local lastInput = UserInputService:GetLastInputType()
	if not (selected or placing) or lastInput == Enum.UserInputType.Touch or not UserInputService.MouseEnabled then
		showGhost(false)
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = Workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
	local ground, point = groundUnder(ray.Origin, ray.Direction, placing ~= nil)
	local plot = ground and ground.Parent
	local frame = plot and plotFrame(plot)
	if not ground or not frame or plot:GetAttribute("OwnerUserId") ~= player.UserId then
		showGhost(false)
		return
	end
	local x, z = ReefConfig.plotOffset(frame, point)
	local fits, size, tint
	if placing then
		local item = ReefConfig.DecorById[placing]
		fits = ReefConfig.decorProblem(placing, x, z, plantsOn(plot, frame), decorOn(plot, frame)) == nil
		size = item.footprint * 2
		tint = Ui.Colors.accent
	else
		fits = ReefConfig.plantProblem(x, z, unlocked, plantsOn(plot, frame), decorOn(plot, frame)) == nil
		size = ReefConfig.PLANT_SPACING
		local seed = ReefConfig.Seeds[selected]
		tint = seed and seed.color
	end
	local color = if fits then Ui.Colors.good else Ui.Colors.bad
	local base = Vector3.new(point.X, point.Y + 0.08, point.Z)
	ring.Size = Vector3.new(0.15, size, size)
	ring.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = color
	sprout.CFrame = CFrame.new(base + Vector3.new(0, 0.8, 0))
	sprout.Color = if fits and tint then tint else color
	showGhost(true)
end

function Planter.setData(data: any)
	selected = data.selected
	unlocked = data.unlocked
	decorStorage = data.decorStorage or {}
	if placing and (decorStorage[placing] or 0) <= 0 then
		Planter.stopPlacing() -- placed the last one
	end
end

-- Placing decorations: onChange(itemId or nil) tells the HUD what is being placed.
function Planter.onPlacingChanged(callback: (string?) -> ())
	placingChanged = callback
end

function Planter.startPlacing(itemId: string)
	placing = itemId
	if placingChanged then
		placingChanged(itemId)
	end
end

function Planter.stopPlacing()
	placing = nil
	if placingChanged then
		placingChanged(nil)
	end
end

function Planter.placingItem(): string?
	return placing
end

function Planter.placingLeft(): number
	return if placing then decorStorage[placing] or 0 else 0
end

function Planter.start()
	ghost.Parent = Workspace.CurrentCamera -- local only, and never part of the shared world
	RunService.RenderStepped:Connect(updateGhost)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not (selected or placing) then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local ray = Workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
		if placing then
			local ground, point = groundUnder(ray.Origin, ray.Direction, true)
			if ground and point then
				Remotes.PlaceDecor:FireServer(placing, point)
			end
			return
		end
		local _, point = bedUnder(ray.Origin, ray.Direction)
		if point then
			Remotes.PlantAt:FireServer(point)
		end
	end)
end

return Planter
