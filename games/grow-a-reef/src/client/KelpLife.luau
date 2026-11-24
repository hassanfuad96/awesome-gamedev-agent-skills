--!nonstrict
-- The Kelp Forest, alive on this client only (layout in KelpConfig):
--   swaying kelp    every giant kelp near the camera sways gently from its holdfast
--   green water     inside the forest the water takes a sunlit green tint and a soft glow,
--                   through our own KelpTint/KelpBloom effects (Lighting's own settings and
--                   the sea events' lighting are left alone)
--   sea turtles     three turtles swimming slow loops round the habitats and the forest
--   fish schools    dark silhouettes drifting between the kelp, like the concept art
--   hatchlings      guiding a hatchling sends a baby turtle paddling up and away
-- The turtles and fish are Part models until the mesh creatures load (Creatures.onReady),
-- then they swap to the sea turtle mesh and dark Kelp Bass silhouettes.
-- Purely cosmetic; the server decides everything (Kelp).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local KelpConfig = require(ReplicatedStorage.Shared.KelpConfig)
local Ui = require(script.Parent.Ui)

local KelpLife = {}

local SWAY_DISTANCE = 170 -- studs from the camera within which kelp sways
local SWIM_DISTANCE = 260
local STEP = 1 / 20 -- seconds between animation updates
local GREEN = Color3.fromRGB(175, 240, 170) -- the forest's sunlit green water
local FADE = TweenInfo.new(1.6, Enum.EasingStyle.Sine)

type Kelp = { model: Model, home: CFrame, phase: number, swing: number }
-- `mesh` is the mesh creature that replaces the Part model once loaded: its id, length,
-- swimming Pace and, for the school fish, the silhouette colour.
type MeshSpec = { id: string, length: number, pace: number, shade: Color3? }
type Swimmer = { model: Model, path: (number) -> CFrame, mesh: MeshSpec? }

local kelps: { [Model]: Kelp } = {}
local swimmers: { Swimmer } = {}
local folder: Folder
local state: any = nil -- the player's data.kelp
local inside = false
local tint: ColorCorrectionEffect
local bloom: BloomEffect
local rng = Random.new()

local function piece(model: Model, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = offset
	p.Parent = model
	return p
end

local function newModel(name: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	local root = piece(model, Vector3.new(0.4, 0.4, 0.4), CFrame.identity, Color3.new(), nil)
	root.Transparency = 1
	model.PrimaryPart = root
	return model, root
end

-- A sea turtle built round the origin, facing -Z. `scale` makes hatchlings.
local function turtleModel(scale: number): Model
	local model = newModel("KelpTurtle")
	local shell = Color3.fromRGB(122, 112, 62)
	local skin = Color3.fromRGB(120, 160, 118)
	piece(model, Vector3.new(3.2, 1.2, 4) * scale, CFrame.identity, shell)
	piece(model, Vector3.new(3, 3, 3) * scale, CFrame.new(0, 0.2 * scale, 0), shell:Lerp(Color3.new(1, 1, 1), 0.12), Enum.PartType.Ball)
	piece(model, Vector3.new(1.2, 1.2, 1.2) * scale, CFrame.new(0, 0.1, -2.5 * scale), skin, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		piece(model, Vector3.new(2.6, 0.2, 1) * scale, CFrame.new(side * 2.1 * scale, -0.1, -0.8 * scale) * CFrame.Angles(0, side * 0.45, 0), skin)
		piece(model, Vector3.new(1.2, 0.2, 0.7) * scale, CFrame.new(side * 1.3 * scale, -0.1, 1.8 * scale) * CFrame.Angles(0, -side * 0.6, 0), skin)
	end
	return model
end

-- A dark fish silhouette, and its colour.
local function fishModel(): (Model, Color3)
	local model = newModel("KelpSchoolFish")
	local color = Color3.fromRGB(28, 40, 52):Lerp(Color3.fromRGB(50, 70, 70), rng:NextNumber(0, 1))
	local body = piece(model, Vector3.new(0.8, 1, 2.2), CFrame.identity, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	piece(model, Vector3.new(0.15, 0.9, 0.8), CFrame.new(0, 0, 1.4), color)
	return model, color
end

-- A loop round `center` (radii rx, rz), bobbing gently, one lap every `lap` seconds.
local function loop(center: Vector3, rx: number, rz: number, height: number, lap: number, phase: number): (number) -> CFrame
	return function(t: number): CFrame
		local a = (t / lap) * math.pi * 2 + phase
		local at = center + Vector3.new(math.cos(a) * rx, height + math.sin(t * 0.7 + phase) * 1.5, math.sin(a) * rz)
		local ahead = center + Vector3.new(math.cos(a + 0.05) * rx, height, math.sin(a + 0.05) * rz)
		return CFrame.lookAt(at, Vector3.new(ahead.X, at.Y, ahead.Z))
	end
end

local function addKelp(instance: Instance)
	if not instance:IsA("Model") or kelps[instance] then
		return
	end
	task.spawn(function()
		-- Streaming can deliver the tag before the parts.
		if not instance.PrimaryPart then
			instance:GetPropertyChangedSignal("PrimaryPart"):Wait()
		end
		local height = instance:GetAttribute("Height") or 50
		kelps[instance] = {
			model = instance,
			home = instance:GetPivot(),
			phase = rng:NextNumber(0, math.pi * 2),
			-- Tall kelp sways a little less at the base, so its top moves about as far.
			swing = math.clamp(2.2 / height, 0.025, 0.07),
		}
	end)
end

local function meshModel(spec: MeshSpec): Model?
	local model = Creatures.clone(spec.id, spec.length)
	if not model then
		return nil
	end
	model:SetAttribute("Pace", spec.pace)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = false
			part.CastShadow = false
		end
	end
	if spec.shade then
		Creatures.silhouette(model, spec.shade)
	end
	return model
end

local function hatchling(at: Vector3)
	local baby = meshModel({ id = "seaTurtle", length = 1.6, pace = 2 }) or turtleModel(0.3)
	local start = CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	baby:PivotTo(start)
	baby.Parent = folder
	local value = Instance.new("CFrameValue")
	value.Value = start
	value.Changed:Connect(function(cf)
		baby:PivotTo(cf)
	end)
	local away = start * CFrame.new(0, 0, -26) + Vector3.new(0, 22, 0)
	TweenService:Create(value, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Value = away }):Play()
	task.delay(5.2, function()
		baby:Destroy()
		value:Destroy()
	end)
end

function KelpLife.setData(data: any)
	state = data and data.kelp
end

function KelpLife.start()
	folder = Instance.new("Folder")
	folder.Name = "KelpLife"
	folder.Parent = Workspace

	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "KelpTint"
	tint.TintColor = Color3.new(1, 1, 1)
	tint.Parent = Lighting
	bloom = Instance.new("BloomEffect")
	bloom.Name = "KelpBloom"
	bloom.Intensity = 0
	bloom.Size = 40
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	-- Turtles: one round each habitat and one cruising the whole forest.
	for i, habitat in KelpConfig.Habitats do
		local turtle = turtleModel(1)
		turtle.Parent = folder
		table.insert(swimmers, {
			model = turtle,
			path = loop(habitat.at, habitat.radius + 10, habitat.radius + 6, 9 + i * 3, 70, i),
			mesh = { id = "seaTurtle", length = 5.5, pace = -0.3 },
		})
	end
	local cruiser = turtleModel(1.3)
	cruiser.Parent = folder
	table.insert(swimmers, { model = cruiser, path = loop(KelpConfig.center, 120, 150, 30, 160, 0), mesh = { id = "seaTurtle", length = 7, pace = -0.4 } })
	-- Schools of dark fish weaving through the kelp.
	for s = 1, 4 do
		local angle = s * 1.6
		local center = KelpConfig.center + Vector3.new(math.cos(angle) * 80, 0, math.sin(angle) * 80)
		local height = 14 + s * 7
		for f = 1, 7 do
			local fish, shade = fishModel()
			fish.Parent = folder
			local offset = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-2.5, 2.5), rng:NextNumber(-4, 4))
			local path = loop(center, 45 + s * 6, 38 + s * 5, height, 45 + s * 8, s)
			table.insert(swimmers, {
				model = fish,
				path = function(t)
					return path(t + f * 0.12) + offset
				end,
				mesh = { id = "kelpBass", length = 2.4, pace = 1, shade = shade },
			})
		end
	end

	Creatures.onReady(function()
		for _, swimmer in swimmers do
			local mesh = swimmer.mesh and meshModel(swimmer.mesh)
			if mesh then
				mesh:PivotTo(swimmer.model:GetPivot())
				mesh.Parent = folder
				swimmer.model:Destroy()
				swimmer.model = mesh
			end
		end
	end)

	for _, instance in CollectionService:GetTagged(KelpConfig.KELP_TAG) do
		addKelp(instance)
	end
	CollectionService:GetInstanceAddedSignal(KelpConfig.KELP_TAG):Connect(addKelp)
	CollectionService:GetInstanceRemovedSignal(KelpConfig.KELP_TAG):Connect(function(instance)
		kelps[instance :: Model] = nil
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, by)
		if by ~= Players.LocalPlayer or prompt:GetAttribute("Kind") ~= "TurtleNest" then
			return
		end
		-- Only when the server will say yes: this nest isn't resting for us.
		local id = prompt:GetAttribute("NestId")
		if state and KelpConfig.nestWait(state, id, Workspace:GetServerTimeNow()) <= 0 and prompt.Parent:IsA("BasePart") then
			hatchling((prompt.Parent :: BasePart).Position + Vector3.new(0, 1.3, 0))
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < STEP then
			return
		end
		elapsed = 0
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local t = os.clock()

		-- Green water while the camera is in the forest.
		local nowInside = KelpConfig.inForest(eye)
		if nowInside ~= inside then
			inside = nowInside
			TweenService:Create(tint, FADE, { TintColor = if inside then GREEN else Color3.new(1, 1, 1), Saturation = if inside then 0.25 else 0, Contrast = if inside then 0.08 else 0 }):Play()
			TweenService:Create(bloom, FADE, { Intensity = if inside then 0.35 else 0 }):Play()
		end

		local still = Ui.reducedMotion()
		if not still then
			for _, kelp in kelps do
				if (kelp.home.Position - eye).Magnitude < SWAY_DISTANCE and kelp.model.Parent then
					local sway = CFrame.Angles(math.sin(t * 0.55 + kelp.phase) * kelp.swing, 0, math.cos(t * 0.45 + kelp.phase * 1.3) * kelp.swing)
					kelp.model:PivotTo(kelp.home * sway)
				end
			end
		end
		for _, swimmer in swimmers do
			local cf = swimmer.path(t)
			if (cf.Position - eye).Magnitude < SWIM_DISTANCE then
				swimmer.model:PivotTo(cf)
			end
		end
	end)
end

return KelpLife
