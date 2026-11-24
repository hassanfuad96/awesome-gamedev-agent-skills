--!nonstrict
-- The mesh creatures (CreatureMeshes) as ready-to-use models. The server builds one template
-- of each into ReplicatedStorage.CreatureModels at startup (CreatureModels); anything, on the
-- server or a client, then takes a copy with Creatures.clone, which returns nil until the
-- template exists (or if its meshes failed to load), so callers keep their old Part-built
-- look as a fallback.
--
-- A creature model: an invisible anchored "Root" part (the PrimaryPart, at the centre,
-- facing -Z) with every mesh piece welded to it (classic Welds, so moving the root moves the
-- whole creature). Each piece has its Role/Side attributes, and the model is tagged
-- "Creature" with its Style, so Creatures.animate (run on clients by CreatureAnimator) can
-- swim it by changing the welds' C0 locally.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureMeshes = require(script.Parent.CreatureMeshes)

local Creatures = {}

Creatures.FOLDER = "CreatureModels"
Creatures.TAG = "Creature"

local folder: Folder? = nil

local function templates(): Folder?
	if not folder or not folder.Parent then
		folder = ReplicatedStorage:FindFirstChild(Creatures.FOLDER) :: Folder?
	end
	return folder
end

-- A copy of creature `id`, `length` studs long (default: as built), or nil if there's no
-- template (yet). Its pivot is its centre, facing -Z.
function Creatures.clone(id: string, length: number?): Model?
	local where = templates()
	local template = where and where:FindFirstChild(id)
	if not template then
		return nil
	end
	local model = template:Clone() :: Model
	local def = CreatureMeshes[id]
	if length and def and length ~= def.length then
		-- ScaleTo is absolute, and the template is already scaled to def.length.
		model:ScaleTo(model:GetScale() * length / def.length)
	end
	return model
end

function Creatures.has(id: string): boolean
	local where = templates()
	return where ~= nil and where:FindFirstChild(id) ~= nil
end

-- Calls `callback` once the server has finished building the templates (straight away if
-- it already has). For callers that built a fallback before the meshes were ready.
function Creatures.onReady(callback: () -> ())
	task.spawn(function()
		local where = ReplicatedStorage:WaitForChild(Creatures.FOLDER) :: Folder
		while not where:GetAttribute("Ready") do
			where:GetAttributeChangedSignal("Ready"):Wait()
		end
		callback()
	end)
end

-- Gold foil all over, for golden pets (the texture is dropped so the colour shows).
function Creatures.gild(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			d.TextureID = ""
			d.Color = color
			d.Material = Enum.Material.Foil
		end
	end
end

-- One flat colour and no texture, for silhouettes of undiscovered species.
function Creatures.silhouette(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			d.TextureID = ""
			d.Color = color
			d.Material = Enum.Material.SmoothPlastic
		end
	end
end

-- Swimming ------------------------------------------------------------------------------

type Joint = { weld: Weld, base: CFrame, hinge: Vector3, role: string, side: number }
type Rig = { joints: { Joint }, style: string, head: Vector3, phase: number }

local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any

-- Reads the model's welds as they are now (after any scaling) and works out where each
-- piece hinges: a tail at its front edge, a side fin at its inner edge.
local function rig(model: Model): Rig?
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local joints = {}
	local front = 0
	for _, weld in root:GetChildren() do
		if weld:IsA("Weld") and weld.Part1 then
			local piece = weld.Part1
			local role = piece:GetAttribute("Role") or "body"
			local side = piece:GetAttribute("Side") or 0
			local base = weld.C0
			local half = piece.Size / 2
			local hinge = base.Position
			if role == "tail" or role == "fluke" then
				hinge -= Vector3.new(0, 0, half.Z)
			elseif role == "fin" then
				hinge -= Vector3.new(side * half.X, 0, 0)
			elseif role == "flutter" then
				hinge -= Vector3.new(0, 0, half.Z)
			elseif role == "dangle" then
				hinge += Vector3.new(0, half.Y, 0)
			end
			front = math.min(front, base.Position.Z - half.Z)
			table.insert(joints, { weld = weld, base = base, hinge = hinge, role = role, side = side })
		end
	end
	return {
		joints = joints,
		style = model:GetAttribute("Style") or "fish",
		-- Fish sway about a point a little behind the snout.
		head = Vector3.new(0, 0, front * 0.6),
		phase = math.random() * math.pi * 2,
	}
end

local function about(point: Vector3, rotation: CFrame): CFrame
	return CFrame.new(point) * rotation * CFrame.new(-point)
end

-- Poses creature `model` for time `t` (seconds). `pace` 1 is an easy cruise; higher swims
-- harder (pets and fish going somewhere), lower is resting, and below 0 is the slow, heavy
-- beat of something huge (the Whale Pass whale, the Giant Octopus).
function Creatures.animate(model: Model, t: number, pace: number?)
	local r = rigs[model]
	if not r then
		r = rig(model)
		if not r then
			return
		end
		rigs[model] = r
	end
	local p = pace or 1
	local s = t * (4 + 3 * p) + r.phase
	local whole: CFrame
	if r.style == "upright" then
		whole = CFrame.Angles(math.sin(s * 0.35) * 0.06, 0, math.sin(s * 0.5) * 0.08)
	elseif r.style == "whale" then
		-- Whales swim with an up-and-down roll, not a side-to-side wiggle.
		whole = about(r.head, CFrame.Angles(math.sin(s) * math.rad(3 + p), 0, 0))
	else
		whole = about(r.head, CFrame.Angles(0, math.sin(s) * math.rad(6 + 3 * p), 0))
	end
	for _, joint in r.joints do
		local extra = CFrame.identity
		if joint.role == "tail" then
			extra = about(joint.hinge, CFrame.Angles(0, math.sin(s - 0.9) * math.rad(14 + 8 * p), 0))
		elseif joint.role == "fluke" then
			extra = about(joint.hinge, CFrame.Angles(math.sin(s - 0.9) * math.rad(16 + 6 * p), 0, 0))
		elseif joint.role == "fin" then
			local flap = math.sin(s * 1.4 + joint.side) * math.rad(28)
			extra = about(joint.hinge, CFrame.Angles(0, joint.side * flap * 0.6, joint.side * flap))
		elseif joint.role == "flutter" then
			extra = about(joint.hinge, CFrame.Angles(0, math.sin(t * 22 + r.phase) * math.rad(25), 0))
		elseif joint.role == "dangle" then
			-- Each one a little out of step with the others, so tentacles ripple.
			local lag = joint.hinge.X * 1.3 + joint.hinge.Z * 0.9
			extra = about(joint.hinge, CFrame.Angles(math.sin(s * 0.45 + lag) * math.rad(9), 0, math.cos(s * 0.4 + lag) * math.rad(7)))
		end
		joint.weld.C0 = whole * extra * joint.base
	end
end

-- Puts a creature back to its built pose (and forgets its rig, e.g. after rescaling).
function Creatures.rest(model: Model)
	local r = rigs[model]
	if r then
		for _, joint in r.joints do
			joint.weld.C0 = joint.base
		end
		rigs[model] = nil
	end
end

function Creatures.isCreature(instance: Instance): boolean
	return CollectionService:HasTag(instance, Creatures.TAG)
end

return Creatures
