--!nonstrict
-- The Aquarium's display tanks, filled on this client with what this player has discovered
-- (data.index, data.ruins.sighted, data.abyss.sighted). The server builds the empty tanks
-- (Hub), tagged AquariumTank with a Kind attribute:
--   fish       every fish species you've caught, swimming about
--   coral      a small specimen of every coral species you've harvested
--   creatures  a board of the rare creatures you've spotted in the Ruins and the Abyss
-- Purely cosmetic and local: other players see their own discoveries in the same tanks.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local CoralVisuals = require(ReplicatedStorage.Shared.CoralVisuals)
local RuinsConfig = require(ReplicatedStorage.Shared.RuinsConfig)
local AbyssConfig = require(ReplicatedStorage.Shared.AbyssConfig)
local Ui = require(script.Parent.Ui)

local AquariumDisplay = {}

type Swimmer = { model: Model, tank: BasePart, phase: number, speed: number, lane: number }

local folder: Folder
local swimmers: { Swimmer } = {}
local lastKey: string? = nil -- what the tanks were last built for; nil = never built
local data: any = nil

local function fishModel(kind: ReefConfig.FishDef): Model
	local model = Instance.new("Model")
	model.Name = kind.id
	local body = Instance.new("Part")
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = false
	body.Size = Vector3.new(0.5, 0.65, 1.2)
	body.Color = kind.color
	body.Material = Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	body.Parent = model
	local tail = Instance.new("WedgePart")
	tail.Anchored = true
	tail.CanCollide = false
	tail.CanQuery = false
	tail.CanTouch = false
	tail.Size = Vector3.new(0.1, 0.6, 0.45)
	tail.Color = kind.color:Lerp(Color3.new(0, 0, 0), 0.25)
	tail.CFrame = CFrame.new(0, 0, 0.75) * CFrame.Angles(0, math.pi, 0)
	tail.Parent = model
	model.PrimaryPart = body
	return model
end

-- Splits a list over the tanks of one kind, in their Slot order.
local function share<T>(items: { T }, tanks: { BasePart }): { [BasePart]: { T } }
	local result = {}
	for _, tank in tanks do
		result[tank] = {}
	end
	for i, item in items do
		if #tanks > 0 then
			table.insert(result[tanks[(i - 1) % #tanks + 1]], item)
		end
	end
	return result
end

local function creaturesBoard(tank: BasePart, lines: { string })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CreatureBoard"
	gui.Face = Enum.NormalId.Front -- each tank's -Z side faces the middle of the hall
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Adornee = tank
	gui.Parent = folder
	local label = Ui.label({
		Text = table.concat(lines, "\n"),
		Font = Ui.TitleFont,
		MaxTextSize = 30,
		TextWrapped = true,
		TextStrokeTransparency = 0.4,
		Parent = gui,
	})
	label.TextColor3 = Color3.fromRGB(220, 250, 255)
end

local function rebuild()
	folder:ClearAllChildren()
	table.clear(swimmers)
	if not data then
		return
	end
	local byKind: { [string]: { BasePart } } = { fish = {}, coral = {}, creatures = {} }
	for _, tank in CollectionService:GetTagged("AquariumTank") do
		local kind = tank:GetAttribute("Kind")
		if byKind[kind] and tank:IsA("BasePart") then
			table.insert(byKind[kind], tank)
		end
	end
	for _, list in byKind do
		table.sort(list, function(a, b)
			return (a:GetAttribute("Slot") or 0) < (b:GetAttribute("Slot") or 0)
		end)
	end

	-- Fish you've caught.
	local caught = {}
	for _, kind in ReefConfig.Fish.kinds do
		if data.index and data.index.fish and data.index.fish[kind.id] then
			table.insert(caught, kind)
		end
	end
	for tank, kinds in share(caught, byKind.fish) do
		for lane, kind in kinds do
			local model = fishModel(kind)
			model.Parent = folder
			table.insert(swimmers, { model = model, tank = tank, phase = lane * 1.7, speed = 0.5 + (lane % 3) * 0.15, lane = lane })
		end
	end

	-- Coral species you've harvested: a small specimen of each on the tank's floor.
	local species, seen = {}, {}
	for key in data.index and data.index.coral or {} do
		local seedId = ReefConfig.splitInventoryKey(key)
		if seedId and ReefConfig.Seeds[seedId] and not seen[seedId] then
			seen[seedId] = true
			table.insert(species, seedId)
		end
	end
	table.sort(species, function(a, b)
		return (table.find(ReefConfig.SEED_ORDER, a) or 99) < (table.find(ReefConfig.SEED_ORDER, b) or 99)
	end)
	for tank, seedIds in share(species, byKind.coral) do
		for i, seedId in seedIds do
			local across = (i - 1) % 4
			local back = (i - 1) // 4
			local at = tank.CFrame * CFrame.new(-3.3 + across * 2.2, -tank.Size.Y / 2 + 0.2, -1 + back * 2)
			local coral = CoralVisuals.build(seedId, "None", CFrame.new(at.Position))
			coral:ScaleTo(0.32)
			for _, d in coral:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanQuery = false
					d.CanCollide = false
				end
			end
			coral.Parent = folder
		end
	end

	-- Rare creatures you've spotted.
	local lines = { "RARE CREATURES" }
	local function add(list: { { id: string, name: string } }?, sighted: { [string]: boolean }?)
		for _, creature in list or {} do
			table.insert(lines, if sighted and sighted[creature.id] then `✓ {creature.name}` else "? ? ?")
		end
	end
	add(RuinsConfig.Creatures and RuinsConfig.Creatures.list, data.ruins and data.ruins.sighted)
	add(AbyssConfig.Creatures and AbyssConfig.Creatures.list, data.abyss and data.abyss.sighted)
	for _, tank in byKind.creatures do
		creaturesBoard(tank, lines)
	end
end

function AquariumDisplay.setData(newData: any)
	data = newData
	-- Rebuild only when what's been discovered changes.
	local parts = {}
	for key in newData.index and newData.index.coral or {} do
		table.insert(parts, key)
	end
	for key in newData.index and newData.index.fish or {} do
		table.insert(parts, key)
	end
	for _, zone in { newData.ruins, newData.abyss } do
		for key in zone and zone.sighted or {} do
			table.insert(parts, key)
		end
	end
	table.sort(parts)
	local key = table.concat(parts, ",")
	if key ~= lastKey and folder then
		lastKey = key
		rebuild()
	end
end

function AquariumDisplay.start()
	folder = Instance.new("Folder")
	folder.Name = "AquariumDisplay"
	folder.Parent = Workspace
	-- The tanks may stream in after the data arrives.
	CollectionService:GetInstanceAddedSignal("AquariumTank"):Connect(function()
		lastKey = nil
		if data then
			AquariumDisplay.setData(data)
		end
	end)
	if data then
		lastKey = nil
		AquariumDisplay.setData(data)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 20 or #swimmers == 0 then
			return
		end
		elapsed = 0
		local camera = Workspace.CurrentCamera
		local t = os.clock()
		for _, fish in swimmers do
			local tank = fish.tank
			if camera and (tank.Position - camera.CFrame.Position).Magnitude < 90 then
				local half = tank.Size * 0.5 - Vector3.new(0.8, 0.8, 0.6)
				local a = t * fish.speed + fish.phase
				local local_ = Vector3.new(math.sin(a) * half.X, math.sin(a * 1.7 + fish.lane) * half.Y * 0.7, math.cos(a * 0.6 + fish.lane) * half.Z * 0.6)
				local ahead = Vector3.new(math.sin(a + 0.1) * half.X, local_.Y, math.cos((a + 0.1) * 0.6 + fish.lane) * half.Z * 0.6)
				local at = tank.CFrame:PointToWorldSpace(local_)
				fish.model:PivotTo(CFrame.lookAt(at, tank.CFrame:PointToWorldSpace(ahead)))
			end
		end
	end)
end

return AquariumDisplay
