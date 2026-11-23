--!nonstrict
-- Builds a reef's fence out of plain Parts round a circle, with a gap at the front (-Z) to
-- walk in. Each style (ReefConfig.Fences) has a kind that decides its shape:
--   planks   posts with rails of salvaged planks (Shipwreck Wood)
--   hedge    kelp stalks topped with leafy bushes, joined by a low hedge (Kelp Hedge)
--   wall     round stone pillars with rows of stacked stones between them (Coral Stone Wall)
--   ribs     giant whale ribs arching over the reef, with a rope between them (Whale Bone)
--   crystal  clusters of glowing crystal shards, joined by a glowing bar (Glow Crystal)
-- Every style also gets a smooth invisible wall per section, so it stops walkers without
-- being climbable. Shared so a shop could preview a style on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)

local FenceVisuals = {}

local ROPE = Color3.fromRGB(176, 150, 104)
local BARNACLE = Color3.fromRGB(206, 200, 184)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder (along X) upright

local function piece(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	-- Only posts of plank fences and the invisible walls are solid. Solid rails would be a
	-- ladder: Roblox characters climb any stack of evenly spaced bars. Clicks and chest
	-- landings pass through all of it to the reef.
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A cylinder from a to b.
local function segment(model: Model, name: string, a: Vector3, b: Vector3, thick: number, color: Color3, material: Enum.Material): Part
	local direction = b - a
	local up = if math.abs(direction.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local cf = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.rad(90), 0)
	return piece(model, name, Vector3.new(direction.Magnitude, thick, thick), cf, color, material, Enum.PartType.Cylinder)
end

local function barnacles(model: Model, base: CFrame, thick: number, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local s = rng:NextNumber(0.25, 0.45)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local at = base * CFrame.new(side * thick / 2, rng:NextNumber(0.1, 1.4), rng:NextNumber(-0.3, 0.3))
		piece(model, "Barnacle", Vector3.new(s, s * 0.7, s), at, BARNACLE, Enum.Material.Slate, Enum.PartType.Ball)
	end
end

local function pick(list: { Color3 }, rng: Random): Color3
	return list[rng:NextInteger(1, #list)]
end

type Style = ReefConfig.FenceDef
-- base: on the ground at the post, facing the reef's centre. gate: one of the two gate posts.
type PostBuilder = (model: Model, style: Style, material: Enum.Material, base: CFrame, gate: boolean, rng: Random) -> ()
-- a, b: the two posts on the ground; outward: half a stud away from the centre.
type RailBuilder = (model: Model, style: Style, material: Enum.Material, a: Vector3, b: Vector3, outward: Vector3, rng: Random) -> ()

local posts: { [string]: PostBuilder } = {}
local rails: { [string]: RailBuilder } = {}

-- Shipwreck Wood: posts with rope lashings and barnacles.
posts.planks = function(model, style, material, base, gate, rng)
	local height = style.height + (if gate then 1.5 else rng:NextNumber(-0.3, 0.4))
	local thick = if gate then 1 else 0.7
	local lean = CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05))
	local post = piece(model, "Post", Vector3.new(thick, height, thick), base * lean * CFrame.new(0, height / 2 - 0.3, 0), style.postColor, material)
	post.CanCollide = true
	if style.rope and (gate or rng:NextNumber() < 0.25) then
		local ring = thick + 0.25
		piece(model, "Rope", Vector3.new(0.35, ring, ring), base * CFrame.new(0, style.height * 0.62, 0) * UPRIGHT, ROPE, Enum.Material.Fabric, Enum.PartType.Cylinder)
	end
	if style.barnacles and rng:NextNumber() < 0.3 then
		barnacles(model, base, thick, rng)
	end
end

-- Salvaged planks on the outside of the posts, each a little crooked. Now and then one has
-- snapped and hangs down from the post it is still nailed to.
rails.planks = function(model, style, material, a, b, outward, rng)
	local span = (b - a).Magnitude
	for rail = 1, style.rails do
		local up = Vector3.new(0, style.height * rail / (style.rails + 1) + rng:NextNumber(-0.12, 0.12), 0)
		local from, to = a + outward + up, b + outward + up
		local color = pick(style.plankColors, rng)
		local tall = rng:NextNumber(0.7, 0.95)
		if rng:NextNumber() < style.brokenChance then
			local length = span * rng:NextNumber(0.35, 0.6)
			local droop = CFrame.Angles(-rng:NextNumber(0.35, 0.7), 0, 0)
			piece(model, "BrokenPlank", Vector3.new(0.25, tall, length), CFrame.lookAt(from, to) * droop * CFrame.new(0, 0, -length / 2), color, material)
		else
			local crooked = CFrame.Angles(rng:NextNumber(-0.04, 0.04), 0, rng:NextNumber(-0.05, 0.05))
			piece(model, "Plank", Vector3.new(0.25, tall, span + 0.6), CFrame.lookAt((from + to) / 2, to) * crooked, color, material)
		end
	end
end

-- Kelp Hedge: a swaying kelp stalk topped with two or three leafy bushes.
posts.hedge = function(model, style, material, base, gate, rng)
	local height = style.height + (if gate then 1.5 else rng:NextNumber(-0.2, 0.6))
	piece(model, "Stalk", Vector3.new(0.5, height, 0.5), base * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)) * CFrame.new(0, height / 2, 0), style.postColor, Enum.Material.Grass)
	for i = 1, (if gate then 3 else rng:NextInteger(2, 3)) do
		local s = rng:NextNumber(1.6, 2.4)
		local at = base * CFrame.new(rng:NextNumber(-0.5, 0.5), height - 0.6 * (i - 1) + rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.4, 0.4))
		piece(model, "Leaves", Vector3.new(s, s * 0.85, s), at, pick(style.plankColors, rng), material, Enum.PartType.Ball)
	end
end

-- A low hedge between the stalks, lumpy on top.
rails.hedge = function(model, style, material, a, b, outward, rng)
	local span = (b - a).Magnitude
	local high = style.height * 0.55
	local mid = (a + b) / 2 + outward * 0.4
	piece(model, "Hedge", Vector3.new(1.6, high, span + 0.4), CFrame.lookAt(mid, b + outward * 0.4) * CFrame.new(0, high / 2, 0), pick(style.plankColors, rng), material)
	for i = 1, style.rails do
		local t = i / (style.rails + 1)
		local s = rng:NextNumber(1.4, 2)
		local at = a:Lerp(b, t) + outward * 0.4 + Vector3.new(0, high + rng:NextNumber(-0.1, 0.3), 0)
		piece(model, "Leaves", Vector3.new(s, s * 0.7, s), CFrame.new(at), pick(style.plankColors, rng), material, Enum.PartType.Ball)
	end
end

-- Coral Stone Wall: a round stone pillar with a cap.
posts.wall = function(model, style, material, base, gate, rng)
	local height = style.height + (if gate then 1.5 else 0.6)
	local width = if gate then 2.2 else 1.8
	piece(model, "Pillar", Vector3.new(height, width, width), base * CFrame.new(0, height / 2, 0) * UPRIGHT, style.postColor, material, Enum.PartType.Cylinder)
	piece(model, "Cap", Vector3.new(width + 0.3, 0.8, width + 0.3), base * CFrame.new(0, height + 0.2, 0), style.postColor:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Slate, Enum.PartType.Ball)
	if style.barnacles and rng:NextNumber() < 0.35 then
		barnacles(model, base, width, rng)
	end
end

-- Rows of stones of different lengths, each row offset like brickwork.
rails.wall = function(model, style, material, a, b, outward, rng)
	local span = (b - a).Magnitude
	local rowHeight = style.height / style.rails
	local look = CFrame.lookAt(a, b)
	for row = 1, style.rails do
		local along = if row % 2 == 0 then -0.8 else 0
		while along < span do
			local finish = along + rng:NextNumber(2.6, 3.8)
			local from, to = math.max(along, 0), math.min(finish, span)
			local length = to - from
			if length > 0.4 then
				local at = look * CFrame.new(rng:NextNumber(-0.08, 0.08), rowHeight * (row - 0.5), -(from + length / 2))
				piece(model, "Stone", Vector3.new(1.3, rowHeight * 0.92, length - 0.12), at, pick(style.plankColors, rng), material)
			end
			along = finish
		end
	end
end

-- Whale Bone: a rib rising from the sand and curving in over the reef.
posts.ribs = function(model, style, material, base, gate, rng)
	local height = style.height + (if gate then 1.5 else rng:NextNumber(-0.6, 0.6))
	local inward = base.LookVector
	local up = Vector3.yAxis
	local root = base.Position
	local points = {
		root,
		root + up * height * 0.55 - inward * 0.3,
		root + up * height * 0.9 + inward * 1.2,
		root + up * height + inward * 3,
	}
	local thickness = { 1.1, 0.9, 0.7 }
	for i = 1, 3 do
		segment(model, "Rib", points[i], points[i + 1], thickness[i], style.postColor, material)
	end
	piece(model, "RibTip", Vector3.new(0.8, 0.8, 0.8), CFrame.new(points[4]), style.postColor, material, Enum.PartType.Ball)
	piece(model, "Knuckle", Vector3.new(1.6, 1, 1.6), base * CFrame.new(0, 0.3, 0), style.postColor:Lerp(Color3.new(0.6, 0.55, 0.45), 0.25), material, Enum.PartType.Ball)
	if style.barnacles and rng:NextNumber() < 0.3 then
		barnacles(model, base, 1.1, rng)
	end
end

-- A sagging rope between the ribs.
rails.ribs = function(model, style, material, a, b, outward, rng)
	local y = Vector3.new(0, style.height * 0.35, 0)
	local sag = Vector3.new(0, -0.5, 0)
	local mid = (a + b) / 2 + y + sag
	local color = pick(style.plankColors, rng)
	segment(model, "Rope", a + y, mid, 0.3, color, Enum.Material.Fabric)
	segment(model, "Rope", mid, b + y, 0.3, color, Enum.Material.Fabric)
end

-- Glow Crystal: a cluster of glowing shards, with a light on every few.
posts.crystal = function(model, style, material, base, gate, rng)
	local shards = if gate then 4 else rng:NextInteger(2, 3)
	local first: Part? = nil
	for i = 1, shards do
		local height = (style.height + (if gate then 1.5 else 0)) * (if i == 1 then 1 else rng:NextNumber(0.45, 0.75))
		local width = rng:NextNumber(0.6, 1)
		local tilt = if i == 1 then CFrame.identity else CFrame.Angles(rng:NextNumber(-0.45, 0.45), rng:NextNumber(0, math.pi), rng:NextNumber(-0.45, 0.45))
		local at = base * CFrame.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5)) * tilt * CFrame.Angles(0, math.rad(45), 0) * CFrame.new(0, height / 2, 0)
		local shard = piece(model, "Shard", Vector3.new(width, height, width), at, pick(style.plankColors, rng), material)
		shard.Transparency = 0.15
		first = first or shard
		local tip = piece(model, "ShardTip", Vector3.new(width * 0.72, width * 0.72, width * 0.72), at * CFrame.new(0, height / 2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), shard.Color, Enum.Material.Neon)
		tip.Transparency = 0.2
	end
	if style.glow and first and (gate or rng:NextNumber() < 0.3) then
		local light = Instance.new("PointLight")
		light.Color = style.glow
		light.Range = 10
		light.Brightness = 1.2
		light.Parent = first
	end
end

-- A thin glowing bar between the clusters.
rails.crystal = function(model, style, material, a, b, outward, rng)
	local y = Vector3.new(0, style.height * 0.4, 0)
	local bar = segment(model, "GlowBar", a + y, b + y, 0.25, style.glow or pick(style.plankColors, rng), Enum.Material.Neon)
	bar.Transparency = 0.35
end

-- A fence of style fenceId round `center` (a point on the ground) at `radius`. rng makes each
-- reef's fence a little different, and the same every time it is built.
function FenceVisuals.build(fenceId: string, center: Vector3, radius: number, rng: Random): Model
	local style = ReefConfig.FenceById[fenceId] or ReefConfig.FenceById[ReefConfig.DEFAULT_FENCE]
	local material = Enum.Material[style.material]
	local buildPost = posts[style.kind] or posts.planks
	local buildRail = rails[style.kind] or rails.planks
	local model = Instance.new("Model")
	model.Name = "Fence"
	model:SetAttribute("FenceId", style.id)

	-- Posts run from one side of the gate all the way round to the other.
	local gateHalf = math.asin(math.min(1, ReefConfig.FENCE_GATE_WIDTH / 2 / radius))
	local start = -math.pi / 2 + gateHalf
	local sweep = math.pi * 2 - gateHalf * 2
	local sections = math.max(3, math.round(sweep * radius / style.postSpacing))
	local points = {}
	for i = 0, sections do
		local angle = start + sweep * i / sections
		points[i] = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
	end

	for i = 0, sections do
		local base = CFrame.lookAt(points[i], Vector3.new(center.X, points[i].Y, center.Z))
		buildPost(model, style, material, base, i == 0 or i == sections, rng)
	end

	for i = 1, sections do
		local a, b = points[i - 1], points[i]
		local outward = ((a + b) / 2 - center).Unit * 0.5
		-- A smooth invisible wall stops walkers without being climbable. Players can still
		-- jump the fence, which is easy in the sea's low gravity.
		local wallHeight = style.height + 0.5
		local wallAt = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, wallHeight / 2, 0)
		local wall = piece(model, "Wall", Vector3.new(1, wallHeight, (b - a).Magnitude), wallAt, style.postColor, Enum.Material.SmoothPlastic)
		wall.Transparency = 1
		wall.CastShadow = false
		wall.CanCollide = true
		buildRail(model, style, material, a, b, outward, rng)
	end

	return model
end

return FenceVisuals
