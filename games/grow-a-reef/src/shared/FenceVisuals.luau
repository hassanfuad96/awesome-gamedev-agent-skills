--!nonstrict
-- Builds a reef's fence out of plain Parts: posts round a circle, rails of planks between
-- them, and a gap at the front (-Z) to walk in. Styles come from ReefConfig.Fences. Shared
-- so a fence shop could later preview a style on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)

local FenceVisuals = {}

local ROPE = Color3.fromRGB(176, 150, 104)
local BARNACLE = Color3.fromRGB(206, 200, 184)

local function piece(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	-- Only posts and the invisible walls are solid. Solid rails would be a ladder: Roblox
	-- characters climb any stack of evenly spaced bars. Clicks and chest landings pass
	-- through all of it to the reef.
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

-- A fence of style fenceId round `center` (a point on the ground) at `radius`. rng makes each
-- reef's fence a little different, and the same every time the server starts.
function FenceVisuals.build(fenceId: string, center: Vector3, radius: number, rng: Random): Model
	local style = ReefConfig.FenceById[fenceId] or ReefConfig.FenceById[ReefConfig.DEFAULT_FENCE]
	local material = Enum.Material[style.material]
	local model = Instance.new("Model")
	model.Name = "Fence"
	model:SetAttribute("FenceId", style.id)

	-- Posts run from one side of the gate all the way round to the other.
	local gateHalf = math.asin(math.min(1, ReefConfig.FENCE_GATE_WIDTH / 2 / radius))
	local start = -math.pi / 2 + gateHalf
	local sweep = math.pi * 2 - gateHalf * 2
	local sections = math.max(3, math.round(sweep * radius / style.postSpacing))
	local posts = {}
	for i = 0, sections do
		local angle = start + sweep * i / sections
		posts[i] = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
	end

	for i = 0, sections do
		local gatePost = i == 0 or i == sections
		local height = style.height + (if gatePost then 1.5 else rng:NextNumber(-0.3, 0.4))
		local thick = if gatePost then 1 else 0.7
		local base = CFrame.lookAt(posts[i], Vector3.new(center.X, posts[i].Y, center.Z))
		local lean = CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05))
		local post = piece(model, "Post", Vector3.new(thick, height, thick), base * lean * CFrame.new(0, height / 2 - 0.3, 0), style.postColor, material)
		post.CanCollide = true
		if style.rope and (gatePost or rng:NextNumber() < 0.25) then
			local ring = thick + 0.25
			local at = base * CFrame.new(0, style.height * 0.62, 0) * CFrame.Angles(0, 0, math.rad(90))
			piece(model, "Rope", Vector3.new(0.35, ring, ring), at, ROPE, Enum.Material.Fabric, Enum.PartType.Cylinder)
		end
		if style.barnacles and rng:NextNumber() < 0.3 then
			for _ = 1, rng:NextInteger(2, 4) do
				local s = rng:NextNumber(0.25, 0.45)
				local side = if rng:NextNumber() < 0.5 then -1 else 1
				local at = base * CFrame.new(side * thick / 2, rng:NextNumber(0.1, 1.4), rng:NextNumber(-0.3, 0.3))
				piece(model, "Barnacle", Vector3.new(s, s * 0.7, s), at, BARNACLE, Enum.Material.Slate, Enum.PartType.Ball)
			end
		end
	end

	-- Rails: salvaged planks on the outside of the posts, each a little crooked. Now and then
	-- one has snapped and hangs down from the post it is still nailed to.
	for i = 1, sections do
		local a, b = posts[i - 1], posts[i]
		local outward = ((a + b) / 2 - center).Unit * 0.5
		local span = (b - a).Magnitude
		-- A smooth invisible wall stops walkers without being climbable. Players can still
		-- jump the fence, which is easy in the sea's low gravity.
		local wallHeight = style.height + 0.5
		local wallAt = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, wallHeight / 2, 0)
		local wall = piece(model, "Wall", Vector3.new(1, wallHeight, span), wallAt, style.postColor, Enum.Material.SmoothPlastic)
		wall.Transparency = 1
		wall.CastShadow = false
		wall.CanCollide = true
		for rail = 1, style.rails do
			local up = Vector3.new(0, style.height * rail / (style.rails + 1) + rng:NextNumber(-0.12, 0.12), 0)
			local from, to = a + outward + up, b + outward + up
			local color = style.plankColors[rng:NextInteger(1, #style.plankColors)]
			local tall = rng:NextNumber(0.7, 0.95)
			if rng:NextNumber() < style.brokenChance then
				local length = span * rng:NextNumber(0.35, 0.6)
				local droop = CFrame.Angles(-rng:NextNumber(0.35, 0.7), 0, 0)
				local cf = CFrame.lookAt(from, to) * droop * CFrame.new(0, 0, -length / 2)
				piece(model, "BrokenPlank", Vector3.new(0.25, tall, length), cf, color, material)
			else
				local crooked = CFrame.Angles(rng:NextNumber(-0.04, 0.04), 0, rng:NextNumber(-0.05, 0.05))
				local cf = CFrame.lookAt((from + to) / 2, to) * crooked
				piece(model, "Plank", Vector3.new(0.25, tall, span + 0.6), cf, color, material)
			end
		end
	end

	return model
end

return FenceVisuals
