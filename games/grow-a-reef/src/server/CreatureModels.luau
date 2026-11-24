--!nonstrict
-- Builds the mesh creatures (CreatureMeshes) into templates in ReplicatedStorage.CreatureModels,
-- which Creatures.clone copies for the catchable fish (Fish), the pets (PetVisuals) and the
-- Reef Index and aquarium. MeshPart.MeshId can't be set from a script, so each piece is made
-- with AssetService:CreateMeshPartAsync. A creature whose meshes fail to load is skipped (the
-- game keeps its old Part-built look for it). The folder's "Ready" attribute turns true once
-- every creature has been tried.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureMeshes = require(ReplicatedStorage.Shared.CreatureMeshes)
local Creatures = require(ReplicatedStorage.Shared.Creatures)

local CreatureModels = {}

local function meshPart(piece: CreatureMeshes.Piece): MeshPart
	local part = AssetService:CreateMeshPartAsync(Content.fromUri(piece.mesh), {
		CollisionFidelity = Enum.CollisionFidelity.Box, -- clicks only; nothing collides with them
	})
	part.Name = piece.name
	part.TextureID = piece.texture
	part.Size = piece.size
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part:SetAttribute("Role", piece.role)
	if piece.side then
		part:SetAttribute("Side", piece.side)
	end
	return part
end

local function build(def: CreatureMeshes.CreatureDef): Model
	local model = Instance.new("Model")
	model.Name = def.id
	model:SetAttribute("Style", def.style)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	for _, piece in def.pieces do
		local part = meshPart(piece)
		local offset = CFrame.new(piece.at)
		part.CFrame = offset
		local weld = Instance.new("Weld")
		weld.Name = piece.name
		weld.Part0 = root
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = root
		part.Parent = model
	end

	-- Built at the generated size; scale it to its game size along its measuring axis.
	local size = model:GetExtentsSize()
	local axis = def.measure or (if def.style == "upright" then "y" else "z")
	local built = if axis == "x" then size.X elseif axis == "y" then size.Y else size.Z
	if built > 0 then
		model:ScaleTo(def.length / built)
	end
	CollectionService:AddTag(model, Creatures.TAG)
	return model
end

function CreatureModels.start()
	local folder = Instance.new("Folder")
	folder.Name = Creatures.FOLDER
	folder.Parent = ReplicatedStorage
	-- Every creature loads at once; "Ready" once the last one has finished (or failed).
	local left = 0
	for _ in CreatureMeshes do
		left += 1
	end
	for id, def in CreatureMeshes do
		task.spawn(function()
			local ok, result = pcall(build, def)
			if ok then
				result.Parent = folder
			else
				warn(`Creature {id} couldn't load its meshes: {result}`)
			end
			left -= 1
			if left == 0 then
				folder:SetAttribute("Ready", true)
			end
		end)
	end
end

return CreatureModels
