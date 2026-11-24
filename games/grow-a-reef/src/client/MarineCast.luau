--!nonstrict
-- Marine life from the character roster (1-npc-character.png) that the sea didn't have yet: a
-- friendly cartoon shark and a pod of three dolphins. Client-only and cosmetic, like SeaLife.
-- Each runs a small steering AI:
--   patrol    follow a wide loop over the lagoon and the Main Reef (dolphins porpoise up and
--             down as they go, the pod in formation behind the leader)
--   curious   now and then, if this player is close, come over and circle them for a while,
--             then head back to the loop
-- Movement is steered (eased velocity towards a goal), so turns are smooth; tails and fins
-- swing as they swim. Nothing updates while the camera is far away.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MarineCast = {}

type Joint = { pivot: CFrame, offset: CFrame, swing: Vector3?, speed: number, phase: number }
type Body = { model: Model, parts: { BasePart }, joints: { Joint } }
type Swimmer = {
	body: Body,
	position: Vector3,
	velocity: Vector3,
	speed: number, -- cruising speed, studs per second
	loop: (number) -> Vector3, -- the patrol path for time t
	offset: Vector3, -- formation offset behind the leader (dolphins)
	leader: Swimmer?,
	curiousUntil: number,
	nextCurious: number,
	circleSign: number,
}

local BALL = Enum.PartType.Ball
local UPDATE_DISTANCE = 420
local rng = Random.new()
local folder: Folder
local swimmers: { Swimmer } = {}
local player = Players.LocalPlayer

local function newBody(name: string): Body
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = folder
	return { model = model, parts = {}, joints = {} }
end

type Options = { shape: Enum.PartType?, material: Enum.Material?, wedge: boolean?, pivot: CFrame?, swing: Vector3?, speed: number?, phase: number? }
local function add(body: Body, size: Vector3, color: Color3, offset: CFrame, o: Options?): BasePart
	local options = o or {}
	local p = Instance.new(if options.wedge then "WedgePart" else "Part") :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	if not options.wedge then
		(p :: Part).Shape = options.shape or Enum.PartType.Block
	end
	p.Size = size
	p.Color = color
	p.Material = options.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = body.model
	table.insert(body.parts, p)
	table.insert(body.joints, { pivot = options.pivot or CFrame.identity, offset = offset, swing = options.swing, speed = options.speed or 0, phase = options.phase or 0 })
	return p
end

-- A chunky, friendly cartoon shark (faces -Z): blue-grey top, white belly, a big grin.
local function sharkBody(): Body
	local b = newBody("Shark")
	local top, belly = Color3.fromRGB(80, 130, 190), Color3.fromRGB(235, 240, 245)
	local tail = CFrame.new(0, 0.2, 5)
	add(b, Vector3.new(4.4, 4, 12), top, CFrame.identity, { shape = BALL })
	add(b, Vector3.new(3.8, 2.6, 10), belly, CFrame.new(0, -0.9, -0.4), { shape = BALL })
	add(b, Vector3.new(3.4, 3, 3.6), top, CFrame.new(0, 0.1, -4.6), { shape = BALL }) -- snout
	for _, side in { -1, 1 } do
		add(b, Vector3.new(0.9, 0.9, 0.9), Color3.new(1, 1, 1), CFrame.new(side * 1.35, 0.9, -4.6), { shape = BALL })
		add(b, Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(20, 24, 36), CFrame.new(side * 1.45, 0.95, -4.95), { shape = BALL })
		add(b, Vector3.new(3.4, 0.4, 1.8), top, CFrame.new(side * 2.6, -1, -0.8) * CFrame.Angles(0, side * 0.35, side * -0.35), { pivot = CFrame.new(side * 1.6, -1, -0.8), swing = Vector3.new(0, 0, 0.25), speed = 2.2, phase = if side > 0 then 0 else math.pi })
	end
	-- The grin, with a row of little teeth.
	add(b, Vector3.new(2.2, 0.45, 0.4), Color3.fromRGB(60, 30, 40), CFrame.new(0, -0.6, -6.1))
	for i = -2, 2 do
		add(b, Vector3.new(0.3, 0.3, 0.3), Color3.new(1, 1, 1), CFrame.new(i * 0.4, -0.45, -6.25) * CFrame.Angles(0, 0, math.rad(45)))
	end
	add(b, Vector3.new(0.5, 3, 3.4), top, CFrame.new(0, 3, 0.4), { wedge = true }) -- dorsal fin
	add(b, Vector3.new(2.2, 2.2, 3.2), top, tail * CFrame.new(0, 0, 0.8), { shape = BALL, pivot = tail, swing = Vector3.new(0, 0.35, 0), speed = 3 })
	add(b, Vector3.new(0.4, 2.8, 2), top, tail * CFrame.new(0, 1.3, 2.4) * CFrame.Angles(-0.6, 0, 0), { pivot = tail, swing = Vector3.new(0, 0.45, 0), speed = 3, phase = 0.3 })
	add(b, Vector3.new(0.4, 2.2, 1.6), top, tail * CFrame.new(0, -1, 2.2) * CFrame.Angles(0.6, 0, 0), { pivot = tail, swing = Vector3.new(0, 0.45, 0), speed = 3, phase = 0.3 })
	return b
end

-- A friendly dolphin (faces -Z): lavender-blue with a pale belly and a long beak.
local function dolphinBody(tint: Color3): Body
	local b = newBody("Dolphin")
	local belly = Color3.fromRGB(235, 238, 250)
	local tail = CFrame.new(0, 0.3, 3.4)
	add(b, Vector3.new(2.6, 2.6, 8), tint, CFrame.identity, { shape = BALL })
	add(b, Vector3.new(2.2, 1.6, 6.6), belly, CFrame.new(0, -0.6, -0.4), { shape = BALL })
	add(b, Vector3.new(2.3, 2.2, 2.6), tint, CFrame.new(0, 0.35, -3.2), { shape = BALL }) -- melon
	add(b, Vector3.new(0.9, 0.7, 2), belly, CFrame.new(0, -0.15, -4.6), { shape = BALL }) -- beak
	for _, side in { -1, 1 } do
		add(b, Vector3.new(0.6, 0.6, 0.6), Color3.new(1, 1, 1), CFrame.new(side * 0.95, 0.45, -3.6), { shape = BALL })
		add(b, Vector3.new(0.34, 0.34, 0.34), Color3.fromRGB(20, 24, 36), CFrame.new(side * 1.05, 0.5, -3.8), { shape = BALL })
		add(b, Vector3.new(2, 0.3, 1.1), tint, CFrame.new(side * 1.6, -0.8, -0.8) * CFrame.Angles(0, side * 0.4, side * -0.4), { pivot = CFrame.new(side * 1, -0.8, -0.8), swing = Vector3.new(0, 0, 0.3), speed = 2.5, phase = if side > 0 then 0 else math.pi })
	end
	add(b, Vector3.new(0.35, 1.8, 1.8), tint, CFrame.new(0, 1.8, 0.3), { wedge = true })
	-- Dolphins beat their tails up and down, not side to side.
	add(b, Vector3.new(1.4, 1.2, 2.6), tint, tail * CFrame.new(0, 0, 0.6), { shape = BALL, pivot = tail, swing = Vector3.new(0.35, 0, 0), speed = 3.4 })
	add(b, Vector3.new(3.2, 0.3, 1.2), tint, tail * CFrame.new(0, 0, 2.2), { pivot = tail, swing = Vector3.new(0.45, 0, 0), speed = 3.4, phase = 0.3 })
	return b
end

local function newSwimmer(body: Body, speed: number, loop: (number) -> Vector3): Swimmer
	local start = loop(0)
	local swimmer = {
		body = body,
		position = start,
		velocity = Vector3.new(0, 0, -speed),
		speed = speed,
		loop = loop,
		offset = Vector3.zero,
		leader = nil,
		curiousUntil = 0,
		nextCurious = os.clock() + rng:NextNumber(15, 40),
		circleSign = if rng:NextNumber() < 0.5 then -1 else 1,
	}
	table.insert(swimmers, swimmer)
	return swimmer
end

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Where this swimmer wants to be right now.
local function goalOf(s: Swimmer, t: number, now: number): Vector3
	local root = myRoot()
	-- Curious: circle the player while it lasts.
	if root and now < s.curiousUntil then
		local a = t * 0.9 * s.circleSign
		local r = if s.leader then 9 else 12
		return root.Position + Vector3.new(math.cos(a) * r, 4 + math.sin(t * 1.3) * 2, math.sin(a) * r) + s.offset * 0.4
	end
	if s.leader then
		-- In formation behind the leader, turned with it.
		local l = s.leader
		local forward = if l.velocity.Magnitude > 0.1 then l.velocity.Unit else Vector3.zAxis
		local frame = CFrame.lookAt(Vector3.zero, forward)
		return l.position + frame:VectorToWorldSpace(s.offset) + Vector3.new(0, math.sin(t * 2.2 + s.offset.X) * 1.5, 0)
	end
	return s.loop(t)
end

local function step(s: Swimmer, t: number, now: number, dt: number)
	local root = myRoot()
	-- Decide to come and look at the player now and then (the leader decides for the pod).
	if not s.leader and root and now >= s.nextCurious then
		s.nextCurious = now + rng:NextNumber(30, 60)
		if (root.Position - s.position).Magnitude < 90 then
			s.curiousUntil = now + rng:NextNumber(6, 10)
		end
	end
	if s.leader then
		s.curiousUntil = s.leader.curiousUntil
	end
	local goal = goalOf(s, t, now)
	local toGoal = goal - s.position
	local maxSpeed = s.speed * (if now < s.curiousUntil then 1.2 else 1)
	local desired = if toGoal.Magnitude > 0.5 then toGoal.Unit * math.min(maxSpeed, toGoal.Magnitude * 1.5) else Vector3.zero
	-- Ease the velocity towards the desired one: smooth turns instead of snapping.
	s.velocity = s.velocity:Lerp(desired, math.min(1, dt * 1.6))
	s.position += s.velocity * dt
	local forward = if s.velocity.Magnitude > 0.3 then s.velocity.Unit else (if toGoal.Magnitude > 0.1 then toGoal.Unit else Vector3.zAxis)
	local rootFrame = CFrame.lookAt(s.position, s.position + forward)
	local body = s.body
	for i, part in body.parts do
		local joint = body.joints[i]
		local cf = rootFrame * joint.offset
		if joint.swing then
			local swing = joint.swing * math.sin(t * joint.speed + joint.phase)
			cf = rootFrame * joint.pivot * CFrame.Angles(swing.X, swing.Y, swing.Z) * joint.pivot:Inverse() * joint.offset
		end
		part.CFrame = cf
	end
end

-- A wide loop round a centre, rising and falling a little.
local function loop(center: Vector3, rx: number, rz: number, rise: number, speed: number, phase: number, porpoise: number?): (number) -> Vector3
	return function(t)
		local a = t * speed / math.max(rx, rz) + phase
		local p = center + Vector3.new(math.sin(a) * rx, math.sin(a * 2) * rise, math.cos(a) * rz)
		if porpoise then
			p += Vector3.new(0, math.abs(math.sin(t * 1.1)) * porpoise, 0)
		end
		return p
	end
end

function MarineCast.start()
	folder = Instance.new("Folder")
	folder.Name = "MarineCast"
	folder.Parent = Workspace
	-- The shark patrols high over the lagoon and the start of the Main Reef.
	newSwimmer(sharkBody(), 14, loop(Vector3.new(-120, 42, 0), 230, 160, 6, 14, 0))
	-- The dolphin pod loops the other way, lower, porpoising as they go.
	local leader = newSwimmer(dolphinBody(Color3.fromRGB(150, 170, 235)), 16, loop(Vector3.new(-60, 26, 20), 170, 130, 4, -16, 2, 7))
	for i, offset in { Vector3.new(-6, -1, 7), Vector3.new(6, 1, 9) } do
		local follower = newSwimmer(dolphinBody(Color3.fromRGB(150, 170, 235):Lerp(Color3.fromRGB(190, 160, 240), i * 0.3)), 18, leader.loop)
		follower.leader = leader
		follower.offset = offset
		follower.position = leader.position + offset
	end

	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local now = os.clock()
		local t = Workspace:GetServerTimeNow()
		for _, s in swimmers do
			local near = camera ~= nil and (camera.CFrame.Position - s.position).Magnitude < UPDATE_DISTANCE
			-- Far away: just keep the position moving along (cheaply), no part updates.
			if near then
				step(s, t, now, math.min(dt, 0.1))
			else
				s.position = goalOf(s, t, now)
			end
		end
	end)
end

return MarineCast
